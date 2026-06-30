# ============================================================
#  enemy.gd
#  Comportamiento del enemigo en la EXPLORACION (top-down).
#  - Lee sus datos de un EnemyData (color, velocidades, stats...).
#  - PATRULLA de lado a lado.
#  - Si detecta al jugador (Area2D grande), lo PERSIGUE.
#  - Al ALCANZARLO, dispara el combate. Quien va mas rapido en el choque
#    consigue la INICIATIVA (le tocara el primer turno en la Fase 4).
#  Se engancha a un CharacterBody2D (la escena enemy.tscn).
# ============================================================

extends CharacterBody2D

# Datos de este enemigo (se asigna en el Inspector arrastrando un .tres
# de tipo EnemyData).
@export var data: EnemyData

# Cuanto se aleja de su punto de inicio al patrullar (en pixeles).
@export var patrol_distance: float = 80.0

# Distancia (centro a centro) a la que se considera que ha "chocado" con el
# jugador y empieza el combate. Los cuadros miden 32, asi que ~26 = tocandose.
@export var contact_distance: float = 26.0

# Senal "ha empezado un combate". El segundo dato dice si lo inicio el
# enemigo (true) o el jugador (false). La usaremos en la Fase 4.
signal combat_started(enemy_data: EnemyData, enemy_initiated: bool)

# Nodos hijos de enemy.tscn (¡los nombres deben coincidir!).
@onready var _color_rect: ColorRect = $ColorRect
@onready var _detection_area: Area2D = $DetectionArea

# --- Estado de la patrulla ---
var _start_x: float = 0.0
var _dir: int = 1  # 1 = derecha, -1 = izquierda

# --- Persecucion ---
var _target: Node2D = null      # el jugador, cuando lo estamos persiguiendo
var _combat_triggered: bool = false  # para no disparar el combate dos veces

# --- Regreso a casa ---
var _home: Vector2 = Vector2.ZERO  # posicion original donde patrulla
var _returning: bool = false       # true mientras vuelve a su sitio

# --- Stats CONCRETAS de ESTE enemigo (tiradas al azar al aparecer) ---
var current_health: int = 0
var current_attack: int = 0
var current_speed: int = 0        # agilidad de combate (orden de turnos)
var current_move_speed: float = 0.0  # velocidad de exploracion (mazmorra)


func _ready() -> void:
	# Modo "flotante": en top-down no hay gravedad ni suelo/techo, todas las
	# direcciones son iguales. (El modo por defecto es para plataformas.)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	_start_x = global_position.x
	_home = global_position  # su sitio original, para volver tras perseguir

	if data != null:
		# Color del placeholder segun los datos.
		_color_rect.color = data.color

		# Tiramos las stats al azar dentro de sus franjas (min-max).
		current_health = randi_range(data.health_min, data.health_max)
		current_attack = randi_range(data.attack_min, data.attack_max)
		current_speed = randi_range(data.speed_min, data.speed_max)
		current_move_speed = randf_range(data.move_speed_min, data.move_speed_max)
		print(data.enemy_name, " aparece -> vida=", current_health,
			" ataque=", current_attack, " velCombate=", current_speed,
			" velMazmorra=", roundi(current_move_speed))

	# Conectamos por codigo las senales del Area2D de deteccion.
	_detection_area.body_entered.connect(_on_detection_body_entered)
	_detection_area.body_exited.connect(_on_detection_body_exited)


func _physics_process(_delta: float) -> void:
	# Si ya empezo el combate o no hay datos, no nos movemos.
	if _combat_triggered or data == null:
		return

	if _target != null:
		_chase()
	elif _returning:
		_return()
	else:
		_patrol()

	move_and_slide()

	if _target != null:
		# PERSIGUIENDO: si en este frame ha chocado con el jugador, ¡combate!
		# (los cuerpos son solidos, asi que "alcanzar" = chocar con el).
		for i in get_slide_collision_count():
			if get_slide_collision(i).get_collider() == _target:
				_start_combat()
				return
	elif not _returning:
		# PATRULLANDO: si choca con una pared, se gira HACIA EL LADO CONTRARIO
		# usando la "normal" del choque (asi no vibra pegado al muro).
		if get_slide_collision_count() > 0:
			var normal_x := get_slide_collision(0).get_normal().x
			if absf(normal_x) > 0.5:
				_dir = signi(normal_x)


# Persigue al jugador moviendose hacia el. Si lo alcanza, empieza el combate.
func _chase() -> void:
	var to_target: Vector2 = _target.global_position - global_position
	velocity = to_target.normalized() * current_move_speed

	# ¿Lo hemos alcanzado? -> combate.
	if to_target.length() <= contact_distance:
		_start_combat()


# Vuelve hacia su sitio original. Al llegar, reanuda la patrulla alli.
func _return() -> void:
	var to_home: Vector2 = _home - global_position
	if to_home.length() <= 3.0:
		# Ya esta en casa: fijamos posicion y reanudamos patrulla.
		global_position = _home
		velocity = Vector2.ZERO
		_returning = false
		_start_x = _home.x
		_dir = 1
	else:
		velocity = to_home.normalized() * current_move_speed


# Patrulla de izquierda a derecha entre dos limites (start_x ± patrol_distance).
# Usa limites DETERMINISTAS: al pasarse de un lado, fija la direccion hacia el
# otro (no alterna cada frame, asi no se queda vibrando si esta fuera de rango).
func _patrol() -> void:
	if global_position.x > _start_x + patrol_distance:
		_dir = -1
	elif global_position.x < _start_x - patrol_distance:
		_dir = 1
	velocity = Vector2(_dir * current_move_speed, 0.0)


# El jugador entra en el radio de vision -> empezamos a perseguir.
func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_target = body


# El jugador sale del radio de vision -> dejamos de perseguir (volvemos a patrullar).
func _on_detection_body_exited(body: Node2D) -> void:
	if body == _target:
		_target = null
		# En vez de patrullar donde quedo, REGRESA a su sitio original.
		_returning = true


# Inicia el combate una sola vez, calculando quien tiene la iniciativa.
func _start_combat() -> void:
	if _combat_triggered:
		return
	_combat_triggered = true
	velocity = Vector2.ZERO

	# Quien va mas rapido en el momento del choque "embiste" y entra primero.
	var enemy_speed: float = current_move_speed
	var player_speed: float = 0.0
	if _target != null and "velocity" in _target:
		player_speed = (_target.velocity as Vector2).length()
	var enemy_initiated: bool = enemy_speed > player_speed

	var quien := "EL ENEMIGO" if enemy_initiated else "EL JUGADOR"
	print("¡COMBATE contra ", data.enemy_name, "! Inicia ", quien,
		" (aqui se abrira el combate en la Fase 4)")
	combat_started.emit(data, enemy_initiated)
