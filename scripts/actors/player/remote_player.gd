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

var _objetivo := Vector2.INF   # ultimo destino recibido; INF = aun no ha llegado ninguno
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
		imagen: PackedByteArray = PackedByteArray(), alpha: float = 1.0) -> void:
	if _muneco == null:
		_muneco = MunecoJugador.new()
		add_child(_muneco)
	# SIN PersonajeData: de el solo llega el aspecto por la red, no su ficha. Por eso se monta con
	# null -- que hoy da el cuerpo desnudo -- y su equipo entrara por el canal propio de la fase de
	# red, no por aqui. La alternativa (mandar la ficha entera) reenviaria su PNG de 128x128 cada vez
	# que se cambia de arma.
	_muneco.montar(null)
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


# Nuevo destino recibido de la red (lo llama Net al llegar cada paquete de posicion).
func ir_a(pos: Vector2) -> void:
	if _objetivo == Vector2.INF or global_position.distance_to(pos) > SALTO:
		global_position = pos   # primer paquete o salto grande: aparecer alli, sin deslizarse
		velocity = Vector2.ZERO # un teletransporte no es correr: que no lo "oigan" a kilometros
	_objetivo = pos


func _physics_process(delta: float) -> void:
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
	if velocity.length() > 6.0:
		_facing = velocity.normalized()
	if _muneco != null and _muneco.hay_dibujo():
		# Modo 1 (andar) siempre: su sigilo y su carrera no viajan hoy. Es una mentira consciente y
		# pequeña -- se le vera andar mientras corre -- y esta apuntada para la fase de red, donde ya
		# hay que abrir un canal para el equipo que lleva puesto y el modo cabe de propina.
		_muneco.animar(PoseJugador.animacion(_facing, 1, velocity.length() > 6.0))


# Lo mismo que el compañero y por lo mismo: el otro humano se dibuja con el mismo cuerpo, asi que
# tiene que recibir los golpes con el mismo. Ver Companion.medio_cuerpo y la nota de los dos cuerpos
# en pose_jugador.gd.
func medio_cuerpo() -> Vector2:
	return PoseJugador.MEDIO_CUERPO
