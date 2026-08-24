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
var _t: float = 0.0
var _piso: Node2D = null


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


# Lo llama DungeonFloor cada vez que rehace el piso: la rejilla de roca es otra.
func preparar(gen: DungeonGenerator) -> void:
	vision.preparar(gen)
	_tex = null
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
	vision.calcular(_focos(jugador), jugador.global_position, _vista())
	_tex = vision.volcar(_tex)
	_mat.set_shader_parameter("mascara", _tex)
	_refrescar_camara()
	_apagar_lo_que_no_se_ve()


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


func _apagar_lo_que_no_se_ve() -> void:
	for grupo in GRUPOS_A_APAGAR:
		for n in get_tree().get_nodes_in_group(grupo):
			var nodo := n as Node2D
			if nodo == null or not is_instance_valid(nodo):
				continue
			nodo.visible = vision.luz_en(nodo.global_position) > LUZ_MINIMA
