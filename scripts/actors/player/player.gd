# ============================================================
#  player.gd
#  Movimiento del jugador en la exploracion (top-down), con TRES velocidades:
#    - Ctrl  : sigilo (despacio y silencioso)
#    - normal: andar
#    - Shift : correr (rapido y ruidoso) -> gasta AGUANTE
#  El aguante maximo depende de Resistencia y Agilidad (stats del jugador,
#  guardadas en el autoload Game). Se vacia al correr y se recupera al parar.
# ============================================================

extends CharacterBody2D

# Velocidad base (andar) y multiplicadores de los otros modos.
@export var walk_speed: float = 120.0
@export var sneak_multiplier: float = 0.45  # sigilo: ~54 px/s
@export var run_multiplier: float = 1.7     # correr: ~204 px/s

# --- Aguante (stamina) ---
@export var base_stamina: float = 100.0
@export var stamina_per_resistencia: float = 0.15  # extra por Resistencia
@export var stamina_per_agilidad: float = 0.05     # extra por Agilidad
@export var run_drain: float = 35.0       # aguante/seg al correr
# Recuperacion: base + extra FIJO por nivel (NO escala con stats, a proposito,
# para no desequilibrar: si subiera con Resistencia/Agilidad daria doble ventaja).
@export var stamina_regen: float = 20.0            # aguante/seg a nivel 1
@export var stamina_regen_per_level: float = 2.0   # +/seg por cada nivel extra
var _regen_actual: float = 20.0  # se calcula en _ready segun el nivel

var max_stamina: float = 100.0
var current_stamina: float = 100.0

# Cuando el aguante llega a 0 entras en "agotado": no puedes correr y vas a
# velocidad de sigilo hasta recuperar esta fraccion del aguante (la mitad).
@export var exhausted_recover_ratio: float = 0.5
var _exhausted: bool = false

# Modo de movimiento actual (lo usa el enemigo para el "ruido"):
# 0 = sigilo, 1 = andar, 2 = correr.
var movement_mode: int = 1

# Direccion a la que "mira" el jugador (ultimo movimiento), para atacar.
var _facing: Vector2 = Vector2.DOWN
var _attack_was_pressed: bool = false

# Ataque cuerpo a cuerpo para INICIAR combate (corto alcance hacia delante).
@export var attack_range: float = 44.0
@export var attack_half_angle_deg: float = 70.0

# Interaccion (F) con cadaveres para extraer el cristal.
@export var interact_range: float = 40.0
var _interact_was: bool = false

# Barra de aguante (se crea por codigo, ver _crear_barra_aguante).
var _stamina_bar: ProgressBar = null

# Excelia (subida de habilidades por uso): distancia recorrida para Fuerza
# (cargando en sobrecarga) y Agilidad (corriendo cerca de un enemigo).
var _last_pos: Vector2 = Vector2.ZERO
var _dist_overload: float = 0.0
var _dist_run: float = 0.0
const _DIST_TICK := 64.0        # px recorridos por cada "tick" de ganancia
const _AGILIDAD_RANGE := 220.0  # correr solo cuenta con un enemigo a este rango


func _ready() -> void:
	_stamina_bar = _crear_barra_aguante()
	add_child(preload("res://scripts/ui/hud.gd").new())  # HUD de inventario
	_last_pos = global_position

	# Aguante maximo segun las stats del jugador (Resistencia y Agilidad).
	max_stamina = base_stamina \
		+ Game.player_resistencia * stamina_per_resistencia \
		+ Game.player_agilidad * stamina_per_agilidad
	current_stamina = max_stamina
	_stamina_bar.max_value = max_stamina
	_stamina_bar.value = current_stamina

	# Recuperacion segun el nivel (fija, no depende de stats).
	_regen_actual = stamina_regen + stamina_regen_per_level * (Game.player_level - 1)


func _physics_process(delta: float) -> void:
	# Con el inventario abierto: no te mueves ni interactuas (F/ataque). El
	# enemigo sigue su IA aparte, asi que puede emboscarte igualmente.
	if Game.inventory_open:
		velocity = Vector2.ZERO
		return

	var direction: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_up", "move_down")
	var moving: bool = direction != Vector2.ZERO
	if moving:
		_facing = direction.normalized()  # recordamos hacia donde miramos

	# Modo segun teclas (Ctrl = sigilo tiene prioridad sobre Shift = correr).
	# Si estamos AGOTADOS, no se puede correr (hasta recuperar la mitad).
	var sneaking: bool = Input.is_key_pressed(KEY_CTRL)
	var running: bool = Input.is_key_pressed(KEY_SHIFT) and not sneaking \
		and moving and not _exhausted

	var speed: float = walk_speed
	if _exhausted:
		# Agotado: te arrastras a velocidad de sigilo, corras o no.
		speed = walk_speed * sneak_multiplier
		movement_mode = 0
	elif sneaking:
		speed = walk_speed * sneak_multiplier
		movement_mode = 0
	elif running:
		speed = walk_speed * run_multiplier
		movement_mode = 2
	else:
		movement_mode = 1

	# Aguante: baja al correr, se recupera en cualquier otro caso.
	if running:
		current_stamina -= run_drain * delta
		if current_stamina <= 0.0:
			current_stamina = 0.0
			_exhausted = true  # nos quedamos sin fuelle
	else:
		current_stamina = minf(max_stamina, current_stamina + _regen_actual * delta)
		# Salimos de agotado al recuperar la mitad del aguante.
		if _exhausted and current_stamina >= max_stamina * exhausted_recover_ratio:
			_exhausted = false

	_stamina_bar.value = current_stamina
	# Pista visual: la barra se pone rojiza mientras estas agotado.
	_stamina_bar.modulate = Color(1.0, 0.4, 0.4) if _exhausted else Color.WHITE

	# Sobrecarga: cuanto mas peso, mas lento (gradual).
	speed *= Game.overload_speed_factor()

	velocity = direction * speed
	move_and_slide()

	# --- Excelia: subida de habilidades por uso (interno; se aplica en el hogar) ---
	var moved: float = global_position.distance_to(_last_pos)
	_last_pos = global_position

	# Fuerza: cargar peso EN SOBRECARGA, solo mientras te MUEVES (no pasivo).
	if moved > 0.0 and Game.esta_sobrecargado():
		_dist_overload += moved
		while _dist_overload >= _DIST_TICK:
			_dist_overload -= _DIST_TICK
			var over: float = Game.ratio_carga() - Game.overload_threshold
			Game.ganar("fuerza", clampf(over * 5.0, 0.0, Game.RETO_MAX), Game.GAIN_FUERZA_PESO)

	# Agilidad: CORRER cerca de un enemigo (correr sin enemigos no sirve).
	if moved > 0.0 and movement_mode == 2:
		var enemigo: Node = _enemigo_cercano_agilidad()
		if enemigo != null:
			_dist_run += moved
			while _dist_run >= _DIST_TICK:
				_dist_run -= _DIST_TICK
				Game.ganar("agilidad", Game.reto(_poder_enemigo_nodo(enemigo)), Game.GAIN_AGILIDAD_CORRER)

	# Ataque hacia delante para iniciar combate (sin tener que tocar al enemigo).
	var atk: bool = Input.is_key_pressed(KEY_SPACE)
	if atk and not _attack_was_pressed:
		_try_attack()
	_attack_was_pressed = atk

	# Interactuar (F) con un cadaver cercano -> minijuego de extraccion.
	var inter: bool = Input.is_key_pressed(KEY_F)
	if inter and not _interact_was:
		_try_interact()
	_interact_was = inter


# True si estamos agotados (lo consulta el enemigo para atacar al instante).
func is_exhausted() -> bool:
	return _exhausted


# Enemigo vivo mas cercano dentro del rango (para la Agilidad al correr).
func _enemigo_cercano_agilidad() -> Node:
	var best: float = INF
	var nearest: Node = null
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d <= _AGILIDAD_RANGE and d < best:
			best = d
			nearest = e
	return nearest


# Poder de un enemigo (suma de habilidades base × su poder) para el "reto".
func _poder_enemigo_nodo(e: Node) -> float:
	if e == null or not is_instance_valid(e) or e.data == null:
		return 0.0
	var p: float = 1.0
	if "current_power" in e:
		p = e.current_power
	return float(e.data.suma_habilidades_base()) * p


# Busca un enemigo justo enfrente y muy cerca; si lo hay, inicia el combate
# con NUESTRA iniciativa.
func _try_attack() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var to_e: Vector2 = e.global_position - global_position
		var dist: float = to_e.length()
		if dist <= attack_range and dist > 0.01:
			if absf(_facing.angle_to(to_e / dist)) <= deg_to_rad(attack_half_angle_deg):
				if e.has_method("atacado_por_jugador"):
					e.atacado_por_jugador()
				return


# Con F: primero intenta EXTRAER de un cadaver cercano; si no hay, RECOGE un
# drop del suelo cercano.
func _try_interact() -> void:
	# 1) Cadaver para extraer.
	var corpse: Node = _mas_cercano_en_grupo("corpse", true)
	if corpse != null:
		Game.start_extraction(corpse)
		return

	# 2) Drop del suelo para recoger.
	var pickup: Node = _mas_cercano_en_grupo("pickup", false)
	if pickup != null and pickup.has_method("recoger"):
		var drop: MonsterDrop = pickup.recoger()
		if drop != null:
			Game.drops.append(drop)
			print("Recoges: ", drop.nombre, " (", drop.calidad_texto(),
				"). Total drops: ", Game.drops.size())


# Devuelve el nodo mas cercano del grupo dentro del rango de interaccion.
# Si skip_extracted, ignora los cadaveres ya extraidos.
func _mas_cercano_en_grupo(grupo: String, skip_extracted: bool) -> Node:
	var nearest: Node = null
	var best: float = INF
	for n in get_tree().get_nodes_in_group(grupo):
		if not is_instance_valid(n):
			continue
		if skip_extracted and "extracted" in n and n.extracted:
			continue
		var d: float = global_position.distance_to(n.global_position)
		if d <= interact_range and d < best:
			best = d
			nearest = n
	return nearest


# Crea una barrita de aguante en pantalla (arriba a la izquierda).
# Va en su propia CanvasLayer para que no la mueva la camara.
func _crear_barra_aguante() -> ProgressBar:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(180, 16)
	bar.position = Vector2(12, 12)
	layer.add_child(bar)
	return bar
