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

const LADO := 32.0        # mismo cuerpo de 32x32 que player.tscn / companion.gd
const SUAVIZADO := 14.0   # rapidez del lerp hacia el objetivo (mas alto = mas pegado, mas jitter)
# Si el objetivo esta lejisimos (primer paquete, o teletransporte del otro), no cruzar el mapa
# deslizandose: aparecer alli directamente. Mismo espiritu que el RESCATE del companion.
const SALTO := 200.0

var _objetivo := Vector2.INF   # ultimo destino recibido; INF = aun no ha llegado ninguno
var _cuerpo: ColorRect = null
var _nombre: Label = null


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

	var col := CollisionShape2D.new()
	var forma := RectangleShape2D.new()
	forma.size = Vector2(LADO, LADO)
	col.shape = forma
	add_child(col)

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
