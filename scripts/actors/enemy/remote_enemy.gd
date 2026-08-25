# ============================================================
#  remote_enemy.gd
#  EL CUERPO de un enemigo del HOST visto en MI mundo (multijugador, hito 5.1).
#
#  Gemelo de remote_player.gd pero para bichos: en multi los enemigos los SIMULA el host
#  (IA, spawns, aforo) y aqui solo se PINTAN. Deliberadamente LIGERO: un ColorRect con el
#  color y el tamaño que el host calculo (data.color_visual / escala_visual), sin IA, sin
#  colision, sin vision, sin combate. NO entra en el grupo "enemy" ni "corpse": es un
#  fantasma visual que se mueve donde diga la red.
#
#  La posicion llega por RPC (Net._tick_enemigos) a ritmo de red; entre paquete y paquete se
#  INTERPOLA hacia el ultimo objetivo, igual que remote_player.
#
#  5.1 = SOLO ver los mismos bichos en las mismas posiciones. El combate replicado (barras,
#  turnos, muerte, extraccion) son sub-fases posteriores (ver docs/MULTIJUGADOR.md).
# ============================================================

extends Node2D

const SUAVIZADO := 14.0   # rapidez del lerp hacia el objetivo (igual que remote_player)
const SALTO := 200.0      # salto grande = teletransporte, no cruzar el mapa deslizandose

var _objetivo := Vector2.INF   # ultimo destino recibido; INF = aun no ha llegado ninguno
var _cuerpo: ColorRect = null
var muerto := false            # ya es cadaver (lo dice quien simula el piso)

# --- Lo que lo hace PELEABLE y EXTRAIBLE (hito 5.3) -------------------------------------------
# Con solo un ColorRect no se podia ni pulsar F encima: player._mas_cercano_en_grupo busca por
# grupo, y Game.start_extraction aborta sin 'data'. Ahora el alta de red trae la RUTA del .tres y
# la 't', que es TODO lo que hace falta para reconstruir sus stats (load() cachea, asi que sale la
# misma instancia de EnemyData que en la maquina que lo simula).
var data: EnemyData = null
var current_t: float = 0.5
var extracted: bool = false    # lo mira player._mas_cercano_en_grupo para no ofrecerlo dos veces
var radio_extra: float = 0.0   # los elites son mas gordos: se descuenta al medir la distancia
# Vida arrastrada y bandera de jefe: Game.start_combat las lee con "in", asi que un espejo con
# estos campos se puede pasar TAL CUAL a start_combat como si fuera un enemigo real.
var hp_restante: float = -1.0
var es_boss: bool = false

# --- DIRECCION (hito 5.4) ---------------------------------------------------------------------
# Mismos numeros y colores que enemy.gd: lo que ve el que simula el piso y lo que ve el que solo
# lo espeja tiene que ser LO MISMO, o uno de los dos juega a ciegas. Por eso el cono de vision se
# dejo de pintar EN LOS DOS SITIOS a la vez (ver enemy._crear_indicadores): aqui solo queda la
# linea de hacia donde mira.
const COLOR_LINEA := Color(1.0, 1.0, 0.0)
const COLOR_LINEA_AVISO := Color(1.0, 0.3, 0.1)

var _linea: Line2D = null
var _mira: float = 0.0            # ultimo angulo recibido
var _avisando: bool = false       # esta telegrafiando el golpe

# --- SPRITE (el mismo que ve quien simula el piso) --------------------------------------------
# Este espejo naciO siendo un ColorRect a proposito, cuando TODOS los bichos lo eran. En cuanto los
# enemigos pasaron a dibujarse por codigo eso dejo de valer: el anfitrion veia slimes, ratas,
# jabalies y trents, y el invitado cuadrados de colores. Mismo bicho, dos juegos distintos.
#
# No hace falta mandar nada nuevo por el cable: el alta ya trae la RUTA del .tres y la 't' (ver
# Net._datos_enemigo), que es exactamente lo que necesita el generador para sacar el MISMO sprite,
# pixel por pixel, en las dos maquinas.
var _sprite: AnimatedSprite2D = null
var _anim_actual: String = ""
var _mov: bool = false            # se esta moviendo (se deduce de los paquetes de posicion)
const _AVISO_TINTE := Color(1.0, 0.45, 0.30)     # el mismo que enemy.gd
# --- EL CONTRATO DEL GRUPO "enemy" -----------------------------------------------------------
# Todo esto se llama igual que en enemy.gd A PROPOSITO. Al entrar en el grupo "enemy" hay que
# cumplir su contrato ENTERO, porque varios sistemas recorren el grupo y leen estos campos a pelo:
#   _combat_triggered -> enemy_links, el culling y vecinos() del piso
#   zona_idx          -> dungeon_floor.enemigos_en_zona (aforo por sala)
#   es_boss           -> el reciclador, para no borrar al jefe
#   esta_muerto()     -> vecinos() y las manadas
# Si falta alguno, el juego revienta con "Invalid access to property" en cuanto alguien lo mire.
var _combat_triggered: bool = false    # se la reservo el dueño y la estoy peleando yo
var zona_idx: int = -1                 # no soy de ninguna sala: la ocupacion la lleva el dueño
# Rastro del elemento (null si no es elemental). Espejo de enemy._fx_elem.
var _fx_elem: CPUParticles2D = null


func _ready() -> void:
	z_as_relative = false
	z_index = 0   # a la altura del jugador y los bichos reales (ver companion.gd)
	# Marca para que el piso NO me meta en su foto y para que la IA de los bichos DE VERDAD me
	# ignore (no soy compañero suyo, soy el dibujo de otra maquina). Estoy en los grupos
	# enemy/corpse solo para que se me pueda atacar y extraer.
	set_meta("es_espejo", true)

	_cuerpo = ColorRect.new()
	_cuerpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cuerpo)
	_redimensionar(32.0)

	_sprite = AnimatedSprite2D.new()
	_sprite.visible = false
	# El sprite generado va a 1 celda = 1 pixel y lo AMPLIA este nodo: sin filtro NEAREST el
	# escalado lo interpola y el pixel-art sale borroso.
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)

	# Linea de direccion (hacia donde mira), delante del cuerpo.
	_linea = Line2D.new()
	_linea.add_point(Vector2.ZERO)
	_linea.add_point(Vector2(26.0, 0.0))
	_linea.width = 3.0
	_linea.default_color = COLOR_LINEA
	add_child(_linea)


# Aspecto que ya calculo quien simula el piso: color base+tinte por 't' y lado del cuerpo (los
# elites son mas grandes). Asi se ve IGUAL en las dos maquinas sin tirar otra 't'.
#
# El ELEMENTO llega como id (no como color) y el rastro se monta aqui con la misma paleta que el
# host: ver enemy.aspecto_red. Sin esto el invitado no veia arder al slime de fuego.
func configurar(color: Color, lado: float, elem: int = Elementos.Elemento.NINGUNO,
		einten: float = 1.0) -> void:
	if _cuerpo != null:
		_cuerpo.color = color
		_redimensionar(lado)
	radio_extra = maxf(0.0, (lado - 32.0) * 0.5)
	_pintar_elemento(elem, einten, lado)


# Mismo rastro que el bicho real (ver enemy._crear_fx_elemental), con el alto atado al lado del
# cuerpo para que un elite grande no lleve particulas de enano.
func _pintar_elemento(elem: int, einten: float, lado: float) -> void:
	if _fx_elem != null:
		_fx_elem.queue_free()
		_fx_elem = null
	if not Elementos.tiene_color(elem):
		return
	_fx_elem = Particulas.ascendentes(self, Elementos.color(elem),
		clampf(einten, 0.0, 1.0), maxf(8.0, lado))


# Los datos con los que se puede pelear/extraer. 'ruta' es el .tres del EnemyData.
#
# 'vision' y 'medio_angulo' ya no se usan (eran para dibujar el cono, que se quito): se dejan en la
# firma porque el alta que manda el dueño los sigue trayendo (ver Net._datos_enemigo) y quitarlos de
# aqui obligaria a tocar el mensaje — y dos maquinas con builds distintas dejarian de entenderse.
func aplicar_datos(ruta: String, t: float, ya_muerto: bool, _vision: float = 130.0,
		_medio_angulo: float = 50.0) -> void:
	if not ruta.is_empty():
		data = load(ruta) as EnemyData
	current_t = t
	_montar_sprite()
	if ya_muerto:
		marcar_cadaver()
	else:
		add_to_group("enemy")


# El sprite, con la MISMA receta que enemy.gd: quien dibuja a quien lo decide SpritesEnemigo (el
# arte de verdad manda; si no, el generador de su familia o de su sprite_gen; si no hay ninguno, se
# queda el ColorRect de siempre). Y como el color y la 't' son los del host, sale identico.
func _montar_sprite() -> void:
	if data == null or _sprite == null:
		return
	var frames: SpriteFrames = SpritesEnemigo.frames_de(data, current_t)
	if frames == null:
		return
	_cuerpo.visible = false
	_sprite.visible = true
	_sprite.sprite_frames = frames
	# La textura generada NO es 1 pixel = 1 unidad de mundo: cada generador dice cuanto escalarla.
	# Y NO se vuelve a estirar con escala_visual: los generadores ya dibujan al bicho grande con mas
	# celdas, que es lo que mantiene el pixel del mismo tamaño para todos.
	var esc: float = SpritesEnemigo.escala_de(data)
	if SpritesEnemigo.hay_que_estirar(data):
		esc *= maxf(0.1, data.escala_visual)
	_sprite.scale = Vector2.ONE * esc
	# La linea amarilla es el apaño de los CUADRADOS: quien tiene cara no la necesita, y ademas mide
	# 26 unidades fijas (un mastil en una rata, invisible dentro del Rey Slime). El aviso del golpe,
	# que es lo OTRO que contaba la linea, pasa al tinte -- igual que en enemy.gd.
	if _linea != null:
		_linea.visible = false
	_actualizar_animacion()


# Hacia donde mira y si esta avisando el golpe. Llega en cada tick de posiciones.
func aplicar_estado_visual(ang: float, avisando: bool) -> void:
	_mira = ang
	_avisando = avisando
	if muerto:
		return
	if _sprite != null and _sprite.visible:
		_sprite.modulate = _AVISO_TINTE if avisando else Color.WHITE
		_actualizar_animacion()
		return
	if _linea != null:
		_linea.rotation = ang
		_linea.default_color = COLOR_LINEA_AVISO if avisando else COLOR_LINEA


# La animacion que toca. La REGLA la decide SpritesEnemigo, la misma que usa el bicho de verdad:
# dos copias divergen y entonces cada jugador ve al mismo bicho haciendo cosas distintas.
#
# 'embistiendo' se toma del aviso: el espejo no conoce los estados de la IA del host, pero el aviso
# del golpe SI viaja, y es justo el momento en que el bicho se lanza.
func _actualizar_animacion() -> void:
	if _sprite == null or not _sprite.visible:
		return
	var nombre: String = SpritesEnemigo.animacion(Vector2.RIGHT.rotated(_mira), _avisando, _mov)
	if nombre != _anim_actual:
		_anim_actual = nombre
		_sprite.play(nombre)


# Lo mismo que enemy.poder_normalizado(): donde cae dentro de su franja. Lo pide la extraccion
# para decidir la categoria del cristal.
func poder_normalizado() -> float:
	return clampf(current_t, 0.0, 1.0)


func esta_muerto() -> bool:
	return muerto


# Me quito de en medio. Salgo de los grupos AL INSTANTE y no en el queue_free, que no surte efecto
# hasta el final del frame: si no, un enemigo de verdad recien creado (p. ej. al heredar el piso)
# me encontraria todavia en el grupo "enemy" y me preguntaria cosas de su IA que yo no tengo.
func retirar() -> void:
	remove_from_group("enemy")
	remove_from_group("corpse")
	queue_free()


# --- PELEAR CONTRA UN ESPEJO (hito 5.3) -------------------------------------------------------
# Yo no simulo este piso, asi que el bicho de verdad esta en otra maquina. Al atacarlo se le PIDE
# la pelea a su dueño, que reserva el grupo entero (nadie mas puede cogerlo) y me contesta. La
# pelea se juega AQUI, contra estos espejos, y al acabar se le devuelve el resultado para que la
# aplique sobre los bichos reales. Mismo espiritu que el candado de las vetas.
# Devuelve si la pulsacion ha SERVIDO de algo (ver enemy.atacado_por_jugador y player._try_attack):
# antes no devolvia nada, asi que el jugador daba el espacio por gastado aunque aqui se saliera de
# vacio — y con la salida de vacio de abajo eso era justo lo que pasaba al ir a ayudar al compañero.
func atacado_por_jugador() -> bool:
	if muerto or not has_meta("net_id"):
		return false
	# YA lo esta peleando alguien. Esto era un callejon sin salida: el bicho de verdad si tenia la via
	# para ECHAR UNA MANO (enemy.gd) y el espejo se la habia quedado sin ella, asi que si el piso lo
	# simulaba tu compañero no habia forma de entrar en su pelea pegandole a un bicho.
	if _combat_triggered:
		Net.unirme_a_la_pelea_de(get_meta("net_id"))
		return true
	Net.solicitar_pelea(get_meta("net_id"))
	return true


# Lo llama Net cuando el dueño concede la pelea: a partir de aqui soy un combatiente.
func entrar_en_pelea() -> void:
	_combat_triggered = true


# Me reservaron para una pelea donde al final NO cabia. Se le devuelve al dueño para que lo suelte:
# si no, se quedaria reservado y congelado para siempre (el bug de las estatuas, por red).
func salir_de_pelea() -> void:
	_combat_triggered = false
	if has_meta("net_id"):
		Net.resultado_bicho(get_meta("net_id"), false, -1.0)


# Ya le han sacado el cristal: se desvanece aqui. El cuerpo DE VERDAD lo desvanece su dueño
# (Net.notificar_extraido), y su baja acabara despawnando este espejo de todas formas.
func desvanecer() -> void:
	remove_from_group("corpse")
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.6)
	t.tween_callback(queue_free)


# Game._on_combat_finished llama a esto sobre los que CAYERON. Se pinta el cadaver aqui y se le
# dice al dueño, que es quien lo mata de verdad (y quien lo difunde a los demas).
func morir() -> void:
	_combat_triggered = false
	marcar_cadaver()
	# Si HEREDE el piso a media pelea, ya no hay dueño a quien contarselo: yo soy la autoridad
	# ahora, asi que se queda como cadaver aqui y punto (sin esto se mandaria un resultado a nadie).
	if has_meta("net_id") and not Net._soy_dueno:
		Net.resultado_bicho(get_meta("net_id"), true, 0.0)


# ...y a esto sobre los SUPERVIVIENTES, con las heridas que les dejaste. El dueño se las guarda
# para la proxima pelea (vida arrastrada) y lo descongela.
#
# 'estados' se acepta y se IGNORA a proposito: los estados que se lleva un bicho del combate corren
# en la maquina de su DUEÑO, que es la que manda sobre el (igual que el respawn de las vetas). Este
# nodo es solo el espejo; tickearlos aqui tambien seria envenenarlo dos veces. La firma se mantiene
# igual que la de enemy.gd para que Game pueda llamar a los dos sin preguntar cual es cual.
func reanudar_tras_combate(hp: float = -1.0, _estados: Array = []) -> void:
	_combat_triggered = false
	hp_restante = hp
	if has_meta("net_id") and not Net._soy_dueno:
		Net.resultado_bicho(get_meta("net_id"), false, hp)


# Ha caido en la maquina que simula el piso: aqui pasa a verse como cadaver. Mismo gris apagado
# que enemy.morir(), para que los dos jugadores vean lo mismo.
func marcar_cadaver() -> void:
	if muerto:
		return
	muerto = true
	if _cuerpo != null:
		_cuerpo.color = Color(0.4, 0.4, 0.4)
	# EL SPRITE PASA A SU POSE DE CADAVER, mirando adonde estaba, exactamente igual que en
	# enemy.morir() y por la MISMA funcion (SpritesEnemigo.cadaver): si cada punta decidiera la pose
	# por su cuenta, el bicho acabaria tirado mirando a un lado en una pantalla y a otro en la otra.
	#
	# El modulate a blanco a mano, y el gris solo para quien no tenga la pose (los enemigos que
	# siguen siendo un cuadrado de color): si moria justo mientras avisaba el golpe se quedaba de
	# cadaver en naranja para siempre.
	if _sprite != null and _sprite.visible:
		var pose: String = SpritesEnemigo.cadaver(Vector2.RIGHT.rotated(_mira))
		if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(pose):
			_sprite.modulate = Color.WHITE
			_anim_actual = pose
			_sprite.play(pose)
		else:
			_sprite.modulate = Color(0.45, 0.45, 0.45)
			_sprite.pause()
	# Un cadaver ya no mira a ningun sitio: fuera la linea (igual que enemy.morir).
	if _linea != null:
		_linea.visible = false
	remove_from_group("enemy")
	add_to_group("corpse")   # ahora se le puede pulsar F para extraerle el cristal


func _redimensionar(lado: float) -> void:
	if _cuerpo == null:
		return
	var medio: float = maxf(1.0, lado) * 0.5
	_cuerpo.offset_left = -medio
	_cuerpo.offset_top = -medio
	_cuerpo.offset_right = medio
	_cuerpo.offset_bottom = medio


# Nuevo destino recibido de la red (lo llama Net al llegar cada paquete de posicion).
func ir_a(pos: Vector2) -> void:
	if _objetivo == Vector2.INF or global_position.distance_to(pos) > SALTO:
		global_position = pos   # primer paquete o salto grande: aparecer alli, sin deslizarse
	_objetivo = pos


func _physics_process(delta: float) -> void:
	if _objetivo == Vector2.INF:
		return
	var antes: Vector2 = global_position
	global_position = global_position.lerp(_objetivo, 1.0 - exp(-SUAVIZADO * delta))
	# ANDA O NO ANDA. El espejo no conoce la IA del host, asi que se deduce de lo que se mueve entre
	# frames: mientras siga persiguiendo su objetivo interpolado, esta andando. El umbral va en
	# distancia AL OBJETIVO y no en lo recorrido este frame, porque el lerp se frena al llegar y si
	# no el bicho se quedaba tieso un instante antes de pararse de verdad.
	if not muerto:
		var mov: bool = global_position.distance_to(_objetivo) > 1.5
		if mov != _mov:
			_mov = mov
			_actualizar_animacion()
	if antes == global_position:
		return
