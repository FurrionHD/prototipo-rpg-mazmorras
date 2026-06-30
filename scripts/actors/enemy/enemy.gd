# ============================================================
#  enemy.gd
#  Enemigo en la EXPLORACION (top-down) con SIGILO:
#   - DEAMBULA por una zona aleatoria alrededor de su sitio.
#   - VISION EN CONO hacia donde mira (su direccion de movimiento). Dibuja
#     el cono y una linea indicadora.
#   - OIDO: te detecta segun tu ruido (tu velocidad). Correr = ruidoso,
#     sigilo = silencioso.
#   - Si te ve/oye, te PERSIGUE (iniciativa del enemigo en combate).
#   - Si le tocas sin que te detecte (por la espalda) -> TU iniciativa.
#  Se engancha a un CharacterBody2D (la escena enemy.tscn).
# ============================================================

extends CharacterBody2D

@export var data: EnemyData

# --- Deambular ---
@export var wander_radius: float = 90.0       # cuanto se aleja de su sitio
@export var wander_pause_min: float = 0.4     # pausa minima al llegar a un punto
@export var wander_pause_max: float = 1.2     # pausa maxima

# --- Vision (cono frontal) ---
@export var vision_range: float = 130.0       # alcance del cono
@export var vision_half_angle_deg: float = 50.0  # medio angulo del cono

# --- Oido ---
@export var hearing_factor: float = 0.55      # radio de oido = tu_velocidad * esto
@export var hearing_max: float = 130.0        # radio de oido maximo

# --- Persecucion / combate ---
@export var lose_range: float = 220.0         # si te alejas mas, te pierde

# Ataque del enemigo: distancia "optima" desde la que ataca y aviso previo.
@export var attack_range: float = 44.0
@export var attack_windup: float = 0.15       # segundos de aviso antes de atacar

signal combat_started(enemy_data: EnemyData, enemy_initiated: bool)

enum State { WANDER, CHASE, RETURN }
var _state: State = State.WANDER

var _home: Vector2 = Vector2.ZERO
var _facing: Vector2 = Vector2.RIGHT  # hacia donde mira (su cono)
var _player: Node2D = null

var _wander_target: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0
var _stuck_time: float = 0.0   # cuanto lleva atascado contra una pared
var _windup_timer: float = -1.0  # -1 = no esta preparando ataque
var _winding: bool = false       # true mientras hace el aviso de ataque
var _combat_triggered: bool = false
var current_move_speed: float = 40.0

var _dead: bool = false       # true cuando es un cadaver (combate ganado)
var extracted: bool = false   # true cuando ya le has sacado el cristal

# Indicadores visuales (creados por codigo).
var _facing_line: Line2D = null
var _vision_cone: Polygon2D = null

@onready var _color_rect: ColorRect = $ColorRect


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("enemy")  # para que el jugador lo encuentre al atacar
	_home = global_position
	_player = get_tree().get_first_node_in_group("player")

	if data != null:
		_color_rect.color = data.color
		current_move_speed = randf_range(data.move_speed_min, data.move_speed_max)

	_crear_indicadores()
	_pick_wander_target()


func _physics_process(delta: float) -> void:
	if _combat_triggered or data == null:
		return

	# Aseguramos referencia al jugador.
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	# Si no estamos ya persiguiendo, miramos si lo vemos u oimos.
	if _state != State.CHASE:
		_try_detect()

	match _state:
		State.WANDER: _wander(delta)
		State.CHASE: _chase(delta)
		State.RETURN: _return()

	move_and_slide()

	# La direccion de mirada = hacia donde nos movemos (si nos movemos).
	if velocity.length() > 1.0:
		_facing = velocity.normalized()
	_actualizar_indicadores()

	# Anti-atasco al deambular: si chocamos con una pared, apuntamos de vuelta
	# a nuestro sitio (nos despegamos hacia dentro). Si llevamos mucho rato
	# atascados (p. ej. nos expulso fuera en una esquina), volvemos de golpe.
	if _state == State.WANDER:
		if get_slide_collision_count() > 0:
			_stuck_time += delta
			if _stuck_time > 1.5:
				global_position = _home  # red de seguridad
				_stuck_time = 0.0
				_pick_wander_target()
			else:
				_wander_target = _home  # tira hacia casa para despegarse
		else:
			_stuck_time = 0.0



# Comprueba si VE (cono) u OYE (ruido) al jugador. Si si, pasa a perseguir.
func _try_detect() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var to_p: Vector2 = _player.global_position - global_position
	var dist: float = to_p.length()
	if dist < 0.01:
		return
	var dir: Vector2 = to_p / dist

	# Vision: dentro del alcance Y dentro del angulo del cono frontal.
	var seen: bool = dist <= vision_range \
		and absf(_facing.angle_to(dir)) <= deg_to_rad(vision_half_angle_deg)

	# Oido: radio que crece con tu velocidad (ruido). Sigilo = casi 0.
	var player_speed: float = 0.0
	if "velocity" in _player:
		player_speed = (_player.velocity as Vector2).length()
	var hear_radius: float = minf(player_speed * hearing_factor, hearing_max)
	var heard: bool = dist <= hear_radius

	if seen or heard:
		_state = State.CHASE
		_facing = dir  # se gira hacia ti


func _wander(delta: float) -> void:
	# En pausa: quieto, contando.
	if _wander_timer > 0.0:
		_wander_timer -= delta
		velocity = Vector2.ZERO
		return

	var to_t: Vector2 = _wander_target - global_position
	if to_t.length() <= 5.0:
		# Llegamos: pausa y nuevo destino.
		_wander_timer = randf_range(wander_pause_min, wander_pause_max)
		_pick_wander_target()
		velocity = Vector2.ZERO
		return

	velocity = to_t.normalized() * current_move_speed


func _chase(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_state = State.RETURN
		return
	var to_p: Vector2 = _player.global_position - global_position
	var dist: float = to_p.length()

	if dist > lose_range:
		_state = State.RETURN  # te perdio, vuelve a su sitio
		velocity = Vector2.ZERO
		_cancelar_aviso()
		return

	if dist > 0.01:
		_facing = to_p / dist  # mira al jugador

	if dist <= attack_range:
		# A distancia de ataque: se para y hace el AVISO antes de golpear.
		# Si el jugador esta agotado, ataca al instante (aviso = 0).
		velocity = Vector2.ZERO
		if _windup_timer < 0.0:
			_windup_timer = 0.0 if _player_exhausted() else attack_windup
		_winding = true
		_windup_timer -= delta
		if _windup_timer <= 0.0:
			_start_combat(true)  # iniciativa del enemigo
	else:
		# Aun lejos: persigue normal.
		velocity = to_p.normalized() * current_move_speed
		_cancelar_aviso()


func _cancelar_aviso() -> void:
	_windup_timer = -1.0
	_winding = false


func _player_exhausted() -> bool:
	return is_instance_valid(_player) and _player.has_method("is_exhausted") \
		and _player.is_exhausted()


# Lo llama el JUGADOR cuando te ataca de cerca: combate con su iniciativa.
func atacado_por_jugador() -> void:
	if _dead:
		return
	_start_combat(false)


# Lo llama Game al GANAR el combate: el enemigo queda como CADAVER (no se
# borra), apagado e interactuable para extraerle el cristal (minijuego).
func morir() -> void:
	_dead = true
	_winding = false
	set_physics_process(false)  # detiene la IA
	velocity = Vector2.ZERO
	_color_rect.color = Color(0.4, 0.4, 0.4)  # cuerpo gris/apagado
	if _vision_cone != null:
		_vision_cone.visible = false
	if _facing_line != null:
		_facing_line.visible = false
	remove_from_group("enemy")  # ya no es un enemigo activo
	add_to_group("corpse")      # ahora es un cadaver interactuable


func esta_muerto() -> bool:
	return _dead


func _return() -> void:
	var to_home: Vector2 = _home - global_position
	if to_home.length() <= 5.0:
		global_position = _home
		velocity = Vector2.ZERO
		_state = State.WANDER
		_pick_wander_target()
	else:
		velocity = to_home.normalized() * current_move_speed


# Elige un punto aleatorio dentro de la zona de deambular (alrededor de su sitio).
func _pick_wander_target() -> void:
	var ang: float = randf() * TAU
	var rad: float = randf_range(wander_radius * 0.3, wander_radius)
	_wander_target = _home + Vector2(cos(ang), sin(ang)) * rad


func _start_combat(enemy_initiated: bool) -> void:
	if _combat_triggered:
		return
	_combat_triggered = true
	velocity = Vector2.ZERO
	combat_started.emit(data, enemy_initiated)
	Game.start_combat(self, data, enemy_initiated)


# --- Visual: cono de vision + linea de direccion ---
func _crear_indicadores() -> void:
	# Cono (poligono translucido), por detras del enemigo.
	_vision_cone = Polygon2D.new()
	var pts: PackedVector2Array = [Vector2.ZERO]
	var half: float = deg_to_rad(vision_half_angle_deg)
	var segs: int = 14
	for i in range(segs + 1):
		var a: float = -half + (2.0 * half) * float(i) / float(segs)
		pts.append(Vector2(cos(a), sin(a)) * vision_range)
	_vision_cone.polygon = pts
	_vision_cone.color = Color(1.0, 1.0, 0.3, 0.12)
	add_child(_vision_cone)
	move_child(_vision_cone, 0)  # al fondo

	# Linea de direccion (hacia donde mira).
	_facing_line = Line2D.new()
	_facing_line.add_point(Vector2.ZERO)
	_facing_line.add_point(Vector2(26.0, 0.0))
	_facing_line.width = 3.0
	_facing_line.default_color = Color(1.0, 1.0, 0.0)
	add_child(_facing_line)


func _actualizar_indicadores() -> void:
	var ang: float = _facing.angle()
	if _vision_cone != null:
		_vision_cone.rotation = ang
	if _facing_line != null:
		_facing_line.rotation = ang
		# Rojo/naranja mientras avisa el ataque (telegrafia el golpe).
		_facing_line.default_color = Color(1.0, 0.3, 0.1) if _winding else Color(1.0, 1.0, 0.0)
	if _vision_cone != null:
		_vision_cone.color = Color(1.0, 0.25, 0.1, 0.18) if _winding else Color(1.0, 1.0, 0.3, 0.12)
