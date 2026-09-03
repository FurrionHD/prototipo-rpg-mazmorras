# ============================================================
#  niebla.gd
#  El nodo que APAGA LA MAZMORRA. Junta las tres piezas:
#    1. recoge los farolillos que hay en el piso (el tuyo, los de tu grupo, los de los demas),
#    2. le pide a Vision la mascara de lo que se ve,
#    3. la pinta con shaders/oscuridad.gdshader y apaga los nodos que caen fuera.
#
#  Cuelga de DungeonFloor, asi que solo existe en la mazmorra: el pueblo y los minijuegos siguen
#  con la luz dada.
#
# ------------------------------------------------------------
#  POR QUE HAY QUE APAGAR NODOS Y NO BASTA LA CAPA NEGRA
# ------------------------------------------------------------
#  La capa negra tapa el TERRENO, pero los Label de nombre de los jugadores remotos, el "[F]" de
#  las vetas y las particulas de los destellos son nodos del mundo con su propio dibujado, y
#  varios van en CanvasLayer por encima. Sin apagarlos, en una sala a oscuras seguirias viendo
#  flotar los nombres y los destellos de todo el piso: sabrias donde esta cada cosa sin verla.
#
# ------------------------------------------------------------
#  MULTIJUGADOR: NADA NUEVO POR LA RED
# ------------------------------------------------------------
#  La mascara es de CLIENTE y cada uno calcula la suya: ya recibe las posiciones de todos los del
#  piso (la relevancia va por 'lugar', ver net.gd). Lo unico que hace falta saber de los demas es
#  el RADIO de su farolillo, y eso viaja por el canal lento de grupo, no en el tick de posiciones.
#
#  OJO con la tentacion de "no calcular la niebla en multi para no desincronizar": no hay nada que
#  sincronizar. Que cada uno vea una cosa distinta es EL PUNTO.
# ============================================================

extends Node2D

# Cada cuanto se recalcula. A 15 Hz el corro de luz sigue al jugador sin que se note el escalon
# (entre recalculos la capa no se mueve, pero el difuminado del shader lo disimula) y cuesta la
# decima parte que hacerlo por frame.
const CADA := 1.0 / 15.0

# Grupos cuyos nodos se apagan si no les llega luz. El propio jugador y sus compañeros NO estan:
# van pegados a ti y llevan tu farolillo encima.
const GRUPOS_A_APAGAR := ["enemy", "corpse", "pickup", "recolectable", "escalera",
	"salida_pueblo", "aliado"]

var vision := Vision.new()

var _capa: CanvasLayer = null
var _lienzo: ColorRect = null
var _mat: ShaderMaterial = null
var _tex: ImageTexture = null
var _tex_tinte: ImageTexture = null
var _t: float = 0.0
var _piso: Node2D = null

# Lo de la pasada anterior, para saltarse la siguiente si nada se ha movido (ver _process).
var _ojo_previo := Vector2(INF, INF)
var _focos_previos: Array = []

# Cuanto se puede mover algo sin que la mascara cambie: media subcelda. Por debajo de esto el
# calculo daria exactamente lo mismo, porque la mascara no tiene mas resolucion que la subcelda.
const HOLGURA := float(DungeonGenerator.CELDA) / float(Vision.SUB) * 0.5


# ¿Ha cambiado algo desde la ultima pasada? Cambia si te has movido, si un compañero se ha movido,
# si ha entrado o salido alguien del grupo, o si el radio del farolillo ha variado (se acaba el
# carbon, lo enciendes, bajas de piso).
func _algo_se_movio(ojo: Vector2, focos: Array) -> bool:
	if _focos_previos.size() != focos.size():
		return true
	if _ojo_previo.distance_squared_to(ojo) > HOLGURA * HOLGURA:
		return true
	for i in focos.size():
		var a: Dictionary = focos[i]
		var b: Dictionary = _focos_previos[i]
		if not is_equal_approx(float(a["radio"]), float(b["radio"])):
			return true
		if (a["pos"] as Vector2).distance_squared_to(b["pos"] as Vector2) > HOLGURA * HOLGURA:
			return true
	return false


func _ready() -> void:
	_piso = get_parent() as Node2D
	# La capa 3 no es un numero al azar: el mundo va en la 0 y el HUD en la 5 (ver hud.gd), asi
	# que la niebla tiene que caer justo en medio. Por encima del HUD taparia la vida y el mapa.
	_capa = CanvasLayer.new()
	_capa.layer = 3
	add_child(_capa)

	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/oscuridad.gdshader")

	_lienzo = ColorRect.new()
	_lienzo.material = _mat
	_lienzo.color = Color(1, 1, 1, 1)
	_lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lienzo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_capa.add_child(_lienzo)


# --- LAS FLORES QUE ALUMBRAN ---
# Radio corto y luz FLOJA: junto a una flor se distingue lo que hay -- un bicho, una veta, el
# suelo -- pero no con el detalle del farolillo, que es lo que pidio el usuario ("no solo teñir,
# tambien iluminar un poco"). Y con esta intensidad el halo sigue por encima de LUZ_MINIMA hasta
# casi el borde, o sea que los bichos que caigan dentro SE ENCIENDEN: si no, la flor teñiria el
# suelo y lo que importa seguiria invisible, que es justo lo contrario de lo que se busca.
# Medido con Vision.luz_en, que es como se calibra esto y no a ojo: a 0 celdas da 0,45 (el 45% de
# lo que da el farolillo), a 1 celda 0,30 y a 2 celdas 0,15 -- todo por encima del 0,06 con el que
# la niebla enciende a los bichos, o sea que lo que caiga dentro del halo SE VE. A 3 celdas, cero.
# Con radio 2,2 el halo util era de una sola celda y se quedaba corto.
const FLOR_RADIO := 3.0
const FLOR_INTENSIDAD := 0.45

func poner_flores(celdas: Dictionary) -> void:
	vision.poner_flores(celdas, FLOR_RADIO, FLOR_INTENSIDAD)


# Lo llama DungeonFloor cada vez que rehace el piso: la rejilla de roca es otra.
func preparar(gen: DungeonGenerator) -> void:
	vision.preparar(gen)
	_tex = null
	_tex_tinte = null
	_mat.set_shader_parameter("mapa_origen", Vector2.ZERO)
	_mat.set_shader_parameter("mapa_tam", gen.tam_px())
	_t = CADA      # que la primera pasada salga ya, sin un frame en negro


func _process(delta: float) -> void:
	# El carbon se quema AQUI, en un _process normal y sin process_mode = ALWAYS. Los menus paran
	# el arbol a proposito (ver Game.abrir_menu), asi que con ALWAYS revisar el inventario o
	# pararte en la forja te iria quemando el carbon: cobrarte luz por no estar jugando.
	Game.gastar_llama(delta)

	_t += delta
	if _t < CADA:
		# La CAMARA si se refresca cada frame: si no, la niebla se arrastra por detras del
		# jugador y se ve el desfase en cuanto te mueves rapido.
		_refrescar_camara()
		return
	_t = 0.0
	var jugador: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if jugador == null:
		return
	var focos: Array = _focos(jugador)
	var vista: Rect2 = _vista()
	# SI NADA SE HA MOVIDO, NO SE RECALCULA. La pasada es lo caro de todo esto (ver Vision.calcular:
	# el coste sube con el CUBO del radio del farolillo), y buena parte del tiempo de juego se pasa
	# quieto: mirando el inventario no, que el arbol esta parado, pero si hablando con un oficio,
	# pescando, picando una veta, leyendo un cartel o simplemente parado pensando. Ahi la mascara
	# anterior sigue siendo exacta, asi que recalcularla es tirar el trabajo.
	#
	# Se compara con la holgura de MEDIA SUBCELDA: por debajo de eso la mascara saldria idéntica
	# (su resolucion es la subcelda), asi que no hay nada que ganar.
	if not _algo_se_movio(jugador.global_position, focos):
		_refrescar_camara()
		return
	_ojo_previo = jugador.global_position
	_focos_previos = focos.duplicate(true)
	vision.calcular(focos, jugador.global_position, vista)
	_tex = vision.volcar(_tex)
	_mat.set_shader_parameter("mascara", _tex)
	_tex_tinte = vision.volcar_tinte(_tex_tinte)
	_mat.set_shader_parameter("tinte", _tex_tinte)
	_refrescar_camara()
	_apagar_lo_que_no_se_ve(vista)


# Lo que se esta viendo, con un margen generoso. El margen no es un adorno: entre pasada y pasada
# la camara se mueve, y sin holgura el borde de la pantalla se calcularia DESPUES de que ya se
# vea, con lo que asomaria una franja negra al correr.
const MARGEN := 8 * DungeonGenerator.CELDA

func _vista() -> Rect2:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return Rect2()
	var tam: Vector2 = get_viewport_rect().size / cam.zoom
	var r := Rect2(cam.get_screen_center_position() - tam * 0.5, tam)
	return r.grow(MARGEN)


func _refrescar_camara() -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	_mat.set_shader_parameter("cam_centro", cam.get_screen_center_position())
	_mat.set_shader_parameter("cam_zoom", cam.zoom)
	_mat.set_shader_parameter("pantalla", get_viewport_rect().size)


# ------------------------------------------------------------
#  QUIEN LLEVA FAROLILLO
# ------------------------------------------------------------
# De momento TODOS los aliados alumbran lo mismo. Cuando entre el farolillo de verdad (con su
# tier, su rareza y su carbon) lo unico que cambia aqui es de donde sale 'radio': el tuyo de tu
# equipo, y el de los demas de lo que anuncien por la red.
func _focos(jugador: Node2D) -> Array:
	var r: float = radio_actual()
	var out: Array = [{"pos": jugador.global_position, "radio": r}]
	# Los compañeros de tu grupo van pegados a ti, pero su luz cuenta: en una esquina, el que va
	# detras te alumbra el trozo que tu ya has dejado atras.
	for a in get_tree().get_nodes_in_group("aliado"):
		var n := a as Node2D
		if n != null and is_instance_valid(n):
			out.append({"pos": n.global_position, "radio": r})
	return out


# EL RADIO, en celdas. Sale del farolillo equipado, de si le queda carbon y de la profundidad del
# piso (ver Lampara). Sin farolillo, apagado o sin carbon devuelve el suelo duro: ves tu corro y
# nada mas, que es la promesa de que la oscuridad no te deja ciego del todo.
func radio_actual() -> float:
	return Game.radio_lampara()


# ------------------------------------------------------------
#  APAGAR LO QUE NO SE VE
# ------------------------------------------------------------
# Un pelin de margen sobre el cero: si se apagara justo al llegar a 0.0, los bichos parpadearian
# en el borde de la niebla al moverse un pixel.
const LUZ_MINIMA := 0.06

# SEGURO: al irse la niebla (volver al pueblo, cerrar el piso) se devuelve la visibilidad a todo
# lo que quedara apagado. Sin esto, cualquier nodo que sobreviva al cambio de escena se quedaria
# invisible para siempre, y es un fallo de los que no se relacionan con su causa ni de broma.
func _exit_tree() -> void:
	for grupo in GRUPOS_A_APAGAR:
		for n in get_tree().get_nodes_in_group(grupo):
			var nodo := n as Node2D
			if nodo != null and is_instance_valid(nodo):
				nodo.visible = true


# 'vista' = el mismo rectangulo con el que se calculo la mascara. Lo de fuera de ahi no se calcula
# (ver Vision.calcular), asi que su luz es 0 por construccion y el resultado seria `visible = false`
# igual: preguntarlo es gastar una consulta por nodo para llegar a la respuesta que ya sabemos. En
# un piso poblado son cientos de nodos, quince veces por segundo, y la mayoria estan fuera de la
# pantalla. Con un Rect2 vacio no se recorta nada (lo que quieren las pruebas).
func _apagar_lo_que_no_se_ve(vista: Rect2 = Rect2()) -> void:
	var recorta: bool = vista.size.x > 0.0
	for grupo in GRUPOS_A_APAGAR:
		for n in get_tree().get_nodes_in_group(grupo):
			var nodo := n as Node2D
			if nodo == null or not is_instance_valid(nodo):
				continue
			if recorta and not vista.has_point(nodo.global_position):
				# Ojo con los GRANDES: el charco mide cinco celdas y su centro puede caer fuera de la
				# ventana con media orilla dentro. A quien sabe decir cuanto ocupa se le da su margen
				# antes de descartarlo, que es la misma cautela que ya tiene _le_llega_luz.
				if not nodo.has_method("tam_px"):
					nodo.visible = false
					continue
				var media: Vector2 = (nodo.tam_px() as Vector2) * 0.5
				if not vista.grow(maxf(media.x, media.y)).has_point(nodo.global_position):
					nodo.visible = false
					continue
			nodo.visible = _le_llega_luz(nodo)


# ¿Le llega luz a este nodo? Para casi todos es una sola muestra en su centro, que es lo correcto:
# una veta o un cadaver ocupan poco mas que un punto.
#
# PERO UN NODO GRANDE NO SE PUEDE DECIDIR POR SU CENTRO, y eso costo un fallo que no se parecia a su
# causa. El charco de pescar mide 160x128 px (cinco celdas por cuatro) y esta en este mismo grupo, y
# ademas monta un muro invisible alrededor que impide acercarse a menos de dos celdas y media de su
# centro -- con el radio minimo de luz en tres celdas, te plantabas en la orilla, con la orilla
# perfectamente iluminada, y el centro seguia a oscuras: el charco ENTERO desaparecia. Lo que se veia
# no era un charco a oscuras sino el riachuelo desembocando en la nada.
#
# Asi que a quien sabe decir cuanto ocupa se le muestrean tambien las cuatro esquinas, y basta con
# que a UNA le llegue luz. Que se encienda entero viendo solo un borde no queda mal: es una mancha
# plana y el shader la oscurece por pixel igual que al suelo, asi que el fondo se sigue viendo a
# oscuras. Lo que se arregla es que deje de existir de golpe.
func _le_llega_luz(nodo: Node2D) -> bool:
	if vision.luz_en(nodo.global_position) > LUZ_MINIMA:
		return true
	if not nodo.has_method("tam_px"):
		return false
	var media: Vector2 = (nodo.tam_px() as Vector2) * 0.5
	if media.x <= 0.0 or media.y <= 0.0:
		return false
	for e in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		if vision.luz_en(nodo.global_position + media * e) > LUZ_MINIMA:
			return true
	return false
