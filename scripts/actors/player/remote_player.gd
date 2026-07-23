# ============================================================
#  remote_player.gd
#  EL CUERPO de OTRO jugador humano en mi mundo (multijugador, hito 1).
#
#  Deliberadamente LIGERO: un ColorRect con su color/brillo (mismo shader que el resto del
#  grupo, ver Game.material_aspecto) y su nombre encima. SIN camara, SIN HUD, SIN input y SIN
#  colision: en el hito 1 es un fantasma visual que se mueve donde diga la red. Tampoco entra
#  en el grupo "player" (medio codigo hace get_first_node_in_group("player") asumiendo que solo
#  hay uno: el MIO) ni en "aliado" (los bichos no deben perseguirlo... todavia).
#
#  La posicion llega por RPC (Net._recibir_estado) a un ritmo de red: entre paquete y paquete
#  se INTERPOLA hacia el ultimo objetivo para que no se vea a tirones.
# ============================================================

extends Node2D

const LADO := 32.0        # mismo cuerpo de 32x32 que player.tscn / companion.gd
const SUAVIZADO := 14.0   # rapidez del lerp hacia el objetivo (mas alto = mas pegado, mas jitter)
# Si el objetivo esta lejisimos (primer paquete, o teletransporte del otro), no cruzar el mapa
# deslizandose: aparecer alli directamente. Mismo espiritu que el RESCATE del companion.
const SALTO := 200.0

var _objetivo := Vector2.INF   # ultimo destino recibido; INF = aun no ha llegado ninguno
var _cuerpo: ColorRect = null
var _nombre: Label = null


func _ready() -> void:
	z_as_relative = false
	z_index = 0   # a la altura del jugador y los bichos (ver companion.gd para el porque)

	_cuerpo = ColorRect.new()
	_cuerpo.offset_left = -LADO * 0.5
	_cuerpo.offset_top = -LADO * 0.5
	_cuerpo.offset_right = LADO * 0.5
	_cuerpo.offset_bottom = LADO * 0.5
	_cuerpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cuerpo)

	_nombre = Label.new()
	_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nombre.add_theme_font_size_override("font_size", 11)
	_nombre.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_nombre.add_theme_constant_override("outline_size", 3)
	_nombre.position = Vector2(-60, -LADO * 0.5 - 20)
	_nombre.size = Vector2(120, 16)
	add_child(_nombre)


# Su cara: color plano + brillo metalico por el shader comun. (Su imagen PNG propia queda para
# un hito posterior; con color y nombre ya os distinguis.)
func aplicar_aspecto(color: Color, metal: float, nombre: String) -> void:
	if _cuerpo != null:
		_cuerpo.color = color
		_cuerpo.material = Game.material_aspecto(metal, null, 1.0)
	if _nombre != null:
		_nombre.text = nombre


# Nuevo destino recibido de la red (lo llama Net al llegar cada paquete de posicion).
func ir_a(pos: Vector2) -> void:
	if _objetivo == Vector2.INF or global_position.distance_to(pos) > SALTO:
		global_position = pos   # primer paquete o salto grande: aparecer alli, sin deslizarse
	_objetivo = pos


func _physics_process(delta: float) -> void:
	if _objetivo == Vector2.INF:
		return
	# Lerp exponencial clasico hacia el ultimo objetivo: tapa el hueco entre paquetes.
	global_position = global_position.lerp(_objetivo, 1.0 - exp(-SUAVIZADO * delta))
