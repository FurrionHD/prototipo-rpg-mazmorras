# ============================================================
#  remote_player.gd
#  EL CUERPO de OTRO jugador humano en mi mundo (multijugador, hito 1; cuerpo real en el 5.4).
#
#  Nacio como un fantasma visual (un ColorRect que se movia donde dijera la red). Desde el hito
#  5.4 es un CUERPO DE VERDAD, calcado de companion.gd: CharacterBody2D en la capa 4 ("aliados")
#  con mascara 1 (solo roca), y entra en el grupo "aliado". Eso es lo que permite que los bichos
#  LO PERSIGAN y lo alcancen: antes solo iban a por quien simula el piso, asi que tu compañero era
#  literalmente intocable y un enemigo no podia empezar una pelea con el.
#
#  Sigue SIN camara, SIN HUD y SIN input (lo mueve la red, no el teclado), y sigue fuera del grupo
#  "player" a proposito: medio codigo hace get_first_node_in_group("player") dando por hecho que
#  solo hay uno, el MIO.
#
#  La posicion llega por RPC (Net._recibir_estado) a un ritmo de red: entre paquete y paquete se
#  INTERPOLA hacia el ultimo objetivo para que no se vea a tirones.
# ============================================================

extends CharacterBody2D

const LADO := 32.0        # el ColorRect de respaldo, igual que en companion.gd
const SUAVIZADO := 14.0   # rapidez del lerp hacia el objetivo (mas alto = mas pegado, mas jitter)
# Si el objetivo esta lejisimos (primer paquete, o teletransporte del otro), no cruzar el mapa
# deslizandose: aparecer alli directamente. Mismo espiritu que el RESCATE del companion.
const SALTO := 200.0

# Lo que dura un espadazo. Los MISMOS numeros que player.DUR_GOLPE/DUR_GOLPE_2M -- van duplicados
# porque player.gd no tiene class_name y no se puede referenciar la constante de verdad (misma
# situacion que enemy.EMBESTIDA_IMPACTO). Si se toca uno, tocar los tres.
const DUR_GOLPE := 8.0 / 12.0
const DUR_GOLPE_2M := 8.0 / 10.0
# Y en que punto del gesto contacta el arma, que es cuando suena. Duplicados de player.gd por el
# mismo motivo que los de arriba: si se tocan alli, tocarlos aqui.
const CONTACTO_GOLPE := 0.55
const CONTACTO_GOLPE_2M := 0.60

var _objetivo := Vector2.INF   # ultimo destino recibido; INF = aun no ha llegado ninguno
# LA POSE que llega por red (ver aplicar_pose). _golpe_seq = -1 hasta el primer paquete: asi el
# estreno del cuerpo no se confunde con un golpe.
var _modo: int = 1
var _desenvainado: bool = false
var _golpe_t: float = 0.0
var _golpe_variante: int = 0
var _golpe_seq: int = -1
# Lo que falta para que SU arma contacte, o -1 si no hay golpe en curso. Es el reloj del sonido,
# calcado del de player.gd.
var _golpe_sfx_t: float = -1.0
# QUE GESTO hace cada una de sus manos, para que su espadazo suene igual aqui que en su pantalla.
# Se guardan al recibir su ASPECTO, que es por donde llega su equipo: el paquete de pose son unos
# pocos bits y ahi no cabe un arma.
#
# EL RESPALDO ES MELEE Y NO PUNOS_GOLPE aunque a mano limpia se DIBUJE el puñetazo: es lo que
# devuelve player._estilo_del_golpe cuando no hay arma, y estas dos ramas tienen que dar la misma
# clave o el mismo golpe sonaria distinto en cada pantalla, que es justo lo que se viene a arreglar.
var _fx_main: int = CombatFX.Estilo.MELEE
var _fx_off: int = CombatFX.Estilo.MELEE
var _cuerpo: ColorRect = null
var _nombre: Label = null
# Su cuerpo dibujado (ver muneco_jugador.gd) y hacia donde mira, deducido de su movimiento.
var _muneco: MunecoJugador = null
var _facing: Vector2 = Vector2.DOWN
# Rastro de SU imbuicion (null = no lleva ninguna). Ver aplicar_imbue.
var _fx_imbue: CPUParticles2D = null
# Su bocadillo mientras canta un hechizo en el mapa (null = no esta cantando). Ver cantar().
const _GLOBO := preload("res://scripts/ui/globo_casteo.gd")
var _globo: Node2D = null


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 4   # capa "aliados", igual que el companion
	collision_mask = 1    # solo el mundo (paredes)
	z_as_relative = false
	z_index = 0   # a la altura del jugador y los bichos (ver companion.gd para el porque)
	# EL GRUPO QUE IMPORTA: es la lista de objetivos que mira el enemigo (ver enemy._aliados).
	add_to_group("aliado")

	# El cuerpo del jugador local comparte capa con la roca: se le excluye para atravesarlo.
	var yo: Node = get_tree().get_first_node_in_group("player")
	if yo is CollisionObject2D:
		add_collision_exception_with(yo)

	_cuerpo = ColorRect.new()
	_cuerpo.offset_left = -LADO * 0.5
	_cuerpo.offset_top = -LADO * 0.5
	_cuerpo.offset_right = LADO * 0.5
	_cuerpo.offset_bottom = LADO * 0.5
	_cuerpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cuerpo)

	# La misma HUELLA DE LOS PIES que el jugador y el compañero (ver PoseJugador.HUELLA y la nota de
	# companion.gd): sale de un solo sitio para que los tres pasen exactamente por donde pasan los
	# otros dos.
	var col := CollisionShape2D.new()
	var forma := RectangleShape2D.new()
	forma.size = PoseJugador.HUELLA
	col.shape = forma
	col.position = Vector2(0.0, PoseJugador.HUELLA_Y)
	add_child(col)

	_nombre = Label.new()
	_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nombre.add_theme_font_size_override("font_size", 11)
	_nombre.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_nombre.add_theme_constant_override("outline_size", 3)
	# Por encima de la CABEZA, no del ColorRect de respaldo: el cuerpo dibujado sube mucho mas que
	# los 32 px de antes (ver PoseJugador.ALTO_MUNDO) y la etiqueta le quedaba tapada por el pecho.
	_nombre.position = Vector2(-60, -PoseJugador.ALTO_MUNDO + PoseJugador.PIES_BAJO_NODO - 18)
	_nombre.size = Vector2(120, 16)
	add_child(_nombre)


# Su cara: color plano + brillo metalico + SU IMAGEN, con el mismo shader que usa el cuerpo del
# jugador local (Game.material_aspecto), asi que se le ve igual que se ve a si mismo. El PNG llega
# ya recortado a 128x128 en el handshake y se convierte a textura aqui.
func aplicar_aspecto(color: Color, metal: float, nombre: String,
		imagen: PackedByteArray = PackedByteArray(), alpha: float = 1.0,
		piezas: Dictionary = {}, equipo: Dictionary = {}) -> void:
	if _muneco == null:
		_muneco = MunecoJugador.new()
		add_child(_muneco)
	# UN PersonajeData DE USAR Y TIRAR, montado con lo que ha llegado por la red. De el no tenemos su
	# ficha (ni falta: mandarla entera reenviaria su PNG de 128x128 cada vez que cambia de arma),
	# pero el muñeco necesita una para saber que pelo y que ropa lleva. Sin esto se montaba con null
	# y el compañero se veia DESNUDO Y CALVO en la pantalla del otro, que es la version de "lo que no
	# escribes en las dos puntas se pierde solo en multijugador".
	#
	# Y 'equipo' es la otra mitad de lo mismo: JugadorSprites saca las capas de armadura y de arma de
	# los campos equipped_* de la ficha (ver _capas_armadura/_capas_arma), que en un PersonajeData
	# recien estrenado son todos null. Por eso al otro jugador se le veia siempre sin peto, sin arma
	# y sin escudo por la mazmorra, llevara lo que llevara. Ver Game.pj_de_dict.
	var pj: PersonajeData = Game.pj_de_dict({"equipo": equipo})
	pj.color = Color(color.r, color.g, color.b, 1.0)
	pj.aspecto = PersonajeData.aspecto_nuevo(pj.color)
	if not piezas.is_empty():
		pj.aplicar_aspecto({"piezas": piezas})
	# Su arma, para el sonido de sus golpes. Sale del mismo PersonajeData que acaba de montarse el
	# muñeco, o sea del equipo que ya viajaba: no hace falta mensaje nuevo.
	_fx_main = _fx_de_arma(pj.equipped_main)
	_fx_off = _fx_de_arma(pj.equipped_off)
	_muneco.montar(pj)
	if _muneco.hay_dibujo():
		_muneco.tenir(Color(color.r, color.g, color.b, 1.0), metal)
		# Su cara sale de los MISMOS bytes que ya llegan en el handshake, convertidos a textura por
		# el camino de siempre. No hace falta ningun mensaje nuevo: la imagen ya viajaba, lo que
		# faltaba era donde pegarla.
		_muneco.poner_cara(Game.textura_de_png(imagen))
		if _cuerpo != null:
			_cuerpo.visible = false
	elif _cuerpo != null:
		_cuerpo.visible = true
		# OPACO: el shader multiplica por COLOR.a, asi que un color con alpha < 1 (translucido)
		# atenuaria el cuerpo entero. El color va SIEMPRE opaco; la opacidad SOBRE la imagen la
		# lleva 'alpha' (color_alpha del shader), no el alpha del Color.
		_cuerpo.color = Color(color.r, color.g, color.b, 1.0)
		# 'alpha' es el color_alpha real del compañero (viaja en el handshake): sin el, el color
		# tapaba del todo su cara — se fijaba a 1.0.
		_cuerpo.material = Game.material_aspecto(metal, Game.textura_de_png(imagen), alpha)
	if _nombre != null:
		_nombre.text = nombre


# Su IMBUICION: el mismo rastro que se pinta a si mismo (ver player._pintar_imbue). Va por un canal
# APARTE del aspecto y no dentro de el: el aspecto lleva el PNG del personaje y solo cambia cuando
# te tocas la cara, mientras que la imbuicion se gasta en cada combate. Meterla ahi habria reenviado
# la imagen entera cada vez que a alguien se le acaban las cargas.
#
# Solo viaja el ID del elemento: el color lo saca cada maquina de Elementos.COLOR, asi que la paleta
# no se puede desincronizar.
func aplicar_imbue(elem: int) -> void:
	if not Elementos.tiene_color(elem):
		if _fx_imbue != null:
			_fx_imbue.queue_free()
			_fx_imbue = null
		return
	if _fx_imbue == null:
		# Con el ALTO del cuerpo dibujado, no con el del ColorRect: el rastro tiene que subir por el
		# personaje entero, y con 32 le llegaba por la cintura.
		_fx_imbue = Particulas.ascendentes(self, Elementos.color(elem), 1.0,
			PoseJugador.ALTO_MUNDO)
	else:
		Particulas.repintar(_fx_imbue, Elementos.color(elem))


# LO QUE ALUMBRA SU FAROLILLO, en celdas. Se guarda a pelo (no dibuja nada por si mismo): quien lo
# lee es niebla._focos(), que lo mete en la lista de focos con SU radio en vez de con el mio.
#
# El -1 de partida significa "todavia no me ha dicho nada": niebla usa entonces el suelo duro de
# vision, no el radio del jugador local. Es el lado seguro del error -- un compañero recien conectado
# se ve alumbrando poco durante un instante, que es mejor que verle alumbrando lo que no alumbra.
var radio_luz: float = -1.0

func aplicar_luz(radio: float) -> void:
	radio_luz = radio


# ESTA CANTANDO un hechizo en el mapa: le sale el mismo bocadillo que a ti (ver globo_casteo.gd).
# Texto vacio = ha dejado de cantar. Es puro adorno, pero de los que importan: ver a tu compañero
# recitando es lo que te dice que no le atropelles la pelea... o que corras a cubrirle.
func cantar(texto: String, color: Color) -> void:
	if texto.is_empty():
		if is_instance_valid(_globo):
			_globo.queue_free()
			_globo = null
		return
	if not is_instance_valid(_globo):
		_globo = _GLOBO.new()
		add_child(_globo)
	_globo.mostrar(texto, color)


# LA POSE que viene pegada al paquete de posicion (ver Net.empaquetar_pose): como anda, si lleva el
# arma fuera y si esta soltando un espadazo. Hasta esto, remote_player pintaba "modo andar" a pelo y
# nada mas: al otro jugador se le veia cruzar la mazmorra sin desenvainar y sin dar un solo golpe,
# aunque estuviera aporreando a un bicho delante de tus narices.
#
# El GOLPE se detecta por el contador, no por un flag: un flag "estoy golpeando" en un canal que
# pierde paquetes se queda encendido o apagado de mas. El contador solo dice "ha empezado otro", y
# el reloj de aqui es el que decide cuanto dura -- el mismo numero que usa el jugador local.
func aplicar_pose(pose: int) -> void:
	_modo = pose & Net.POSE_MODO
	_desenvainado = (pose & Net.POSE_DESENV) != 0
	var variante: int = (pose >> 3) & 0b11
	var seq: int = (pose >> 5) & 0xFF
	_aplicar_faena(Net.faena_de_pose(pose), Net.volteo_de_pose(pose), Net.tier_de_pose(pose))
	if seq != _golpe_seq and _faena > 0:
		# EN FAENA el contador de golpe es el del pico, no el de un espadazo: se ve la descarga.
		if _golpe_seq >= 0:
			_faena_golpe_remoto(Net.golpe_de_pose(pose))
		_golpe_seq = seq
		return
	if seq != _golpe_seq:
		# Un golpe nuevo. El primer paquete que llega tras crear el cuerpo NO cuenta como golpe: sin
		# esto, cualquiera que se acabara de conectar arrancaba dando un espadazo al aire.
		if _golpe_seq >= 0:
			_golpe_variante = variante
			_golpe_t = DUR_GOLPE_2M if variante == 2 else DUR_GOLPE
			# NO suena aqui: aqui el brazo apenas se esta echando hacia atras. Se apunta cuando
			# tiene que sonar, igual que hace el jugador consigo mismo.
			_golpe_sfx_t = _golpe_t * (CONTACTO_GOLPE_2M if variante == 2 else CONTACTO_GOLPE)
		_golpe_seq = seq


# SU ESPADAZO, OIDO DESDE AQUI. Hasta esto, en el mapa cada uno solo oia sus propios golpes y los
# de los bichos que simula: el compañero podia estar aporreando algo a tu lado en silencio.
#
# NO HACE FALTA MENSAJE NUEVO: el contador de golpe ya viajaba (es lo que anima el muñeco) y el
# arma llega con el aspecto. Lo unico que faltaba era sonarlo.
#
# SE OYE SEGUN LO LEJOS QUE ESTE, y esto no es un adorno: sin ello oirias igual de fuerte a alguien
# que esta al otro lado del piso, y el sonido dejaria de decirte donde mirar. Con el zoom de 1.8 de
# la camara la pantalla abarca unos 711x400 px de mundo, o sea 408 de media diagonal: por eso a
# partir de OYE_NADA no suena nada -- justo cuando ya no cabe en tu pantalla.
#
# El peso es el MISMO mando que usa el area en combate (ver Sonido._db): 1.0 es un golpe de lleno y
# 0.2 el mas flojo que existe. Reutilizarlo, y no inventar otro volumen, es lo que hace que un
# espadazo lejano suene como un adyacente y no como otra cosa.
const OYE_LLENO := 200.0   # px: hasta aqui suena como si fuera tuyo
const OYE_NADA := 420.0    # px: a partir de aqui, silencio (ya no cabe en la pantalla)

func _sonar_golpe(variante: int) -> void:
	var yo: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if yo == null:
		return
	var d: float = global_position.distance_to(yo.global_position)
	if d >= OYE_NADA:
		return
	var peso: float = 1.0
	if d > OYE_LLENO:
		peso = lerpf(1.0, 0.2, (d - OYE_LLENO) / (OYE_NADA - OYE_LLENO))
	Sonido.golpe("", _fx_off if variante == 1 else _fx_main, peso)


# El gesto que hace un arma suya, con el MISMO respaldo que player._estilo_del_golpe (ver _fx_main).
func _fx_de_arma(arma) -> int:
	if not (arma is WeaponData):
		return CombatFX.Estilo.MELEE
	return int(CombatFX.FX_ARMA.get(int(arma.tipo), CombatFX.Estilo.MELEE))


# Nuevo destino recibido de la red (lo llama Net al llegar cada paquete de posicion).
func ir_a(pos: Vector2) -> void:
	if _objetivo == Vector2.INF or global_position.distance_to(pos) > SALTO:
		global_position = pos   # primer paquete o salto grande: aparecer alli, sin deslizarse
		velocity = Vector2.ZERO # un teletransporte no es correr: que no lo "oigan" a kilometros
	_objetivo = pos


func _physics_process(delta: float) -> void:
	# EL RUIDO Y EL IMPACTO DE LA FAENA van ANTES de la salida de abajo: mientras trabaja esta QUIETO,
	# y un avatar que no se mueve puede pasar ratos sin paquete de posicion nuevo. Puestos despues,
	# su ruido se quedaba en el pico para siempre y los bichos lo oian aunque ya hubiera parado.
	if _ruido_t > 0.0:
		_ruido_t -= delta
	if _faena_impacto_t >= 0.0:
		_faena_impacto_t -= delta
		if _faena_impacto_t < 0.0:
			_faena_impacto_remoto()
	if _objetivo == Vector2.INF or delta <= 0.0:
		return
	# Lerp exponencial clasico hacia el ultimo objetivo: tapa el hueco entre paquetes.
	var antes: Vector2 = global_position
	global_position = global_position.lerp(_objetivo, 1.0 - exp(-SUAVIZADO * delta))
	# VELOCIDAD derivada del propio movimiento. No es cosmetica: el OIDO del enemigo sale de
	# velocity.length() (ver enemy._detecta_a), asi que sin esto un jugador remoto seria
	# COMPLETAMENTE silencioso y solo lo detectarian por el cono de vision.
	velocity = (global_position - antes) / delta

	# HACIA DONDE MIRA: se deduce de por donde se mueve y NO se usa el '_facing' que ya viaja en el
	# paquete de posicion. Suena al reves, y tiene su motivo: ese facing es el de su ULTIMO
	# movimiento con teclas, asi que al soltarlas se queda apuntando a un sitio mientras el cuerpo
	# aun se desliza hacia el ultimo destino recibido. Se le veria andar de lado. Aqui se dibuja lo
	# que se ve hacer, que es lo que tiene que casar con la interpolacion.
	var andando: bool = velocity.length() > 6.0
	if andando:
		_facing = velocity.normalized()
	# EL SONIDO DE SU ESPADAZO, en el instante del contacto. Va pegado al mismo reloj que la
	# animacion -- como en el jugador local -- para que el filo y el sonido caigan en el mismo
	# fotograma tambien en esta pantalla.
	if _golpe_sfx_t >= 0.0:
		_golpe_sfx_t -= delta
		if _golpe_sfx_t < 0.0:
			_sonar_golpe(_golpe_variante)
	if _golpe_t > 0.0:
		_golpe_t -= delta
		# MIENTRAS PEGA, MIRA A DONDE PEGABA. Deducir el facing del movimiento (que es lo correcto
		# andando, ver arriba) aqui no vale: se golpea PARADO, asi que la interpolacion no da
		# direccion ninguna y el espadazo saldria siempre hacia el ultimo lado por el que se movio.
		andando = false
	if _muneco != null and _muneco.hay_dibujo():
		if _faena > 0:
			_animar_faena()
			return
		_muneco.animar(PoseJugador.animacion(_facing, _modo, andando,
			_golpe_t > 0.0, _desenvainado, _golpe_variante))


# SU FAENA, VISTA DESDE AQUI (ver Net.empaquetar_pose). Solo se ve el golpe caer, no la carga: la
# carga no viaja y no merece la pena mandarla a 10 Hz para un pico que sube un momento.
var _faena: int = 0
var _faena_volteo: bool = false
var _faena_tier: int = 1
var _faena_golpe_pendiente: bool = false
var _faena_golpe_tipo: int = 0
var _faena_impacto_t: float = -1.0
const _FAENA := preload("res://scripts/world/faena.gd")


# UN GOLPE SUYO DE FAENA, visto desde aqui. En multijugador el mundo NO se para mientras alguien pica,
# y ese golpe tiene que existir para los demas igual que para el:
#   - se VE: la descarga en su muñeco y, al llegar la herramienta, el recurso tiembla y suelta trozos;
#   - se OYE: por distancia a ti, igual que su espadazo (ver _FAENA.sonar_lejos);
#   - ALERTA: su avatar "hace ruido" (ruido_oido), y los bichos de quien simule el piso lo oyen igual
#     que oirian al propio jugador -- que en esa maquina ES este avatar;
#   - y si ESTA maquina simula el piso, suma al ALBOROTO, que antes solo contaba lo del anfitrion.
# Nada de esto necesita un mensaje nuevo: el golpe y como ha salido ya viajan en la pose.
func _faena_golpe_remoto(tipo: int) -> void:
	_faena_golpe_pendiente = true
	_faena_golpe_tipo = tipo
	var base: String = PoseJugador.FAENAS[_faena - 1]
	# El trozo que salta y el sonido, cuando LLEGA la herramienta, como en su pantalla. El reloj
	# arranca AQUI y no al animar: el golpe existe aunque su muñeco aun no se haya podido montar.
	var desde: int = int(PoseJugador.FAENA_DESCARGA.get(base, 0))
	_faena_impacto_t = float(int(PoseJugador.FAENA_IMPACTO.get(base, desde)) - desde) \
		/ maxf(1.0, PoseJugador.fps_de(base))
	var r: Dictionary = _FAENA.REACCION.get(base, {})
	if r.is_empty():
		return
	var ruidos: Array = r["ruido"]
	hacer_ruido(float(ruidos[clampi(tipo, 0, ruidos.size() - 1)]), _FAENA.RUIDO_DUR)
	if Net.simulo_mi_piso():
		Game.sumar_alboroto(float(r.get("alboroto", 0.0)))


# EL RUIDO QUE HACE, para el oido de los bichos (enemy._detecta_a pregunta por esto antes que por la
# velocidad). Mismo trato que Player.hacer_ruido: se queda el mas fuerte y se desinfla solo.
var _ruido_pico: float = 0.0
var _ruido_t: float = 0.0
var _ruido_dur: float = 1.0

func hacer_ruido(cuanto: float, segundos: float) -> void:
	if cuanto <= ruido_extra_actual():
		return
	_ruido_pico = cuanto
	_ruido_dur = maxf(0.01, segundos)
	_ruido_t = _ruido_dur


func ruido_extra_actual() -> float:
	return _ruido_pico * clampf(_ruido_t / _ruido_dur, 0.0, 1.0) if _ruido_t > 0.0 else 0.0


func ruido_oido() -> float:
	return velocity.length() + ruido_extra_actual()

func _aplicar_faena(faena: int, volteo: bool, tier: int) -> void:
	if faena == _faena and volteo == _faena_volteo and tier == _faena_tier:
		return
	var nombre_faena: String = ""
	if faena > 0 and faena <= PoseJugador.FAENAS.size():
		nombre_faena = String(PoseJugador.FAENAS[faena - 1])
	_faena = faena if nombre_faena != "" else 0
	_faena_volteo = volteo
	_faena_tier = tier
	_faena_golpe_pendiente = false
	if _muneco == null:
		return
	_muneco.scale.x = -1.0 if (_faena > 0 and volteo) else 1.0
	var capa: Dictionary = {}
	if _faena > 0:
		for tn in ArmaSprites.HERRAMIENTA_ANIM:
			if String(ArmaSprites.HERRAMIENTA_ANIM[tn]) == nombre_faena:
				capa = JugadorSprites.capa_herramienta(tn, tier, 0)
	_muneco.poner_herramienta(capa)


func _faena_impacto_remoto() -> void:
	if _faena <= 0:
		return
	var base: String = PoseJugador.FAENAS[_faena - 1]
	# Volteado = esta a la DERECHA del recurso (ver faena.gd), y los trozos saltan hacia el otro lado.
	var lado: float = 1.0 if _faena_volteo else -1.0
	var obj: Node2D = _FAENA.buscar_objetivo(get_tree(), base, global_position)
	if obj != null:
		_FAENA.reaccionar(obj, base, _faena_golpe_tipo, lado)
	var yo: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if yo != null:
		_FAENA.sonar_lejos(base, _faena_golpe_tipo, global_position, yo.global_position,
			OYE_LLENO, OYE_NADA)


func _animar_faena() -> void:
	var base: String = PoseJugador.FAENAS[_faena - 1]
	var anim: String = "%s_%d" % [base, PoseJugador.ancla_de(base)]
	if _faena_golpe_pendiente:
		_faena_golpe_pendiente = false
		_muneco.animar_desde(anim, int(PoseJugador.FAENA_DESCARGA.get(base, 0)))
	elif _muneco.anim_actual() != anim or _muneco.terminada():
		# Entre golpe y golpe: las de CARGA vuelven a la guardia (el pico abajo) y las de COMPAS
		# esperan ARMADAS, que es como las ve su dueño (ver faena.gd).
		var reposo: int = 0 if PoseJugador.FAENA_CARGA.has(base) \
			else int(PoseJugador.FAENA_DESCARGA.get(base, 1)) - 1
		_muneco.fijar(anim, reposo)


# Lo mismo que el compañero y por lo mismo: el otro humano se dibuja con el mismo cuerpo, asi que
# tiene que recibir los golpes con el mismo. Ver Companion.caja_cuerpo y la nota de los dos cuerpos
# en pose_jugador.gd.
func caja_cuerpo() -> Rect2:
	return PoseJugador.CAJA_CUERPO
