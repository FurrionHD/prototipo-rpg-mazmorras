# ============================================================
#  game.gd  (AUTOLOAD: se llama "Game" y esta disponible en todo el juego)
#  - Guarda las stats del JUGADOR (persisten entre combates, incluida la vida).
#  - Abre la pantalla de combate ENCIMA de la mazmorra (overlay) y pausa el
#    resto del juego mientras dura. Al terminar, reanuda y, si ganaste,
#    elimina al enemigo de la mazmorra.
# ============================================================

extends Node

# --- Stats del jugador (de momento fijas aqui; luego vendran de su .tres) ---
var player_level: int = 1
# Habilidades VISIBLES (las que usa el combate/capacidad). Empiezan a 0 y solo
# se actualizan al "volver al hogar" (tecla U -> actualizar_estado()).
var player_fuerza: int = 0
var player_resistencia: int = 0
var player_destreza: int = 0
var player_agilidad: int = 0
var player_magia: int = 0
var player_base_hp: float = 50.0
var player_base_attack: float = 5.0
var player_base_defense: float = 5.0
var player_base_speed: float = 5.0
# Vida actual (persiste entre combates). -1 = aun no inicializada (= llena).
var player_current_hp: int = -1

# --- Subida de habilidades (Excelia estilo DanMachi) ---
# Valor INTERNO (float) que sube con el uso. Lo visible (player_*) solo se
# sincroniza al "actualizar estado" (hogar). Rendimientos decrecientes segun
# el interno; dificultad relativa (enemigo/accion facil = sube poco).
var ability_internal: Dictionary = {
	"fuerza": 0.0, "resistencia": 0.0, "destreza": 0.0, "agilidad": 0.0, "magia": 0.0}
const DIMINISH_K := 0.06           # mas alto = sube mas lento al ir teniendo mas
const RETO_MAX := 3.0              # tope de dificultad relativa
const PODER_JUGADOR_SUELO := 10.0  # suelo para no dividir por 0 a nivel 0
# Ganancias base por fuente (ajustables).
const GAIN_FUERZA_ATAQUE := 0.25
const GAIN_FUERZA_PESO := 0.4
const GAIN_AGILIDAD_CORRER := 0.4
const GAIN_RESISTENCIA_GOLPE := 0.3
const GAIN_DESTREZA_MINIJUEGO := 1.0

# Dificultad del ultimo minijuego de extraccion (para la ganancia de Destreza).
var _last_extraction_zone: float = 0.13
var _last_extraction_hits: int = 3

# Base de combate COMUN para los enemigos (los diferencia sus HABILIDADES).
# Cada EnemyData la ajusta con multiplicadores de arquetipo (por defecto 1.0).
var enemy_base_hp: float = 28.0
var enemy_base_attack: float = 3.0
var enemy_base_defense: float = 3.0
var enemy_base_speed: float = 4.0

var _combat_scene: PackedScene = preload("res://scenes/ui/combat.tscn")
var _extraction_script: GDScript = preload("res://scripts/ui/extraction.gd")
var _drop_pickup_script: GDScript = preload("res://scripts/items/drop_pickup.gd")
var _active_enemy: Node = null     # enemigo del combate en curso
var _active_layer: CanvasLayer = null  # capa donde vive la pantalla actual

# Profundidad actual de la mazmorra (para escalar dificultad). Aun sin pisos: 1.
var current_floor: int = 1

# Cristales y drops obtenidos (inventario temporal hasta la Fase 6).
var crystals: Array[Cristal] = []
var drops: Array[MonsterDrop] = []

# PRUEBAS: fuerza el drop al 100%. Poner en false para usar drop_chance real.
var dev_force_drop: bool = false

# PRUEBAS: cuantos cristales meter en el inventario al arrancar (0 = ninguno).
var dev_start_crystals: int = 0


func _ready() -> void:
	# TEMPORAL: relleno de cristales para probar el peso/sobrecarga.
	for _i in dev_start_crystals:
		var c := Cristal.new()
		c.categoria = randi_range(3, 5)
		c.calidad = Cristal.Calidad.INTACTO
		crystals.append(c)

# Bonus de HERRAMIENTAS de recoleccion (cuchillos...). Placeholder hasta tener
# sistema de equipo: las herramientas rellenaran estos valores.
var tool_hit_reduction: int = 0    # reduce pulsaciones necesarias
var tool_destreza_bonus: int = 0   # Destreza extra para la extraccion

# --- Peso / capacidad de carga ---
# De serie llevas un ZURRON pequeño (base_capacity). La Fuerza sube la
# capacidad. En el futuro: mochila y companero de apoyo sumaran aqui.
var base_capacity: float = 25.0        # zurron de serie
var extra_capacity: float = 0.0        # placeholder mochila/companero (futuro)
# La Fuerza MULTIPLICA la capacidad del contenedor (zurron+mochila) hasta un
# maximo (a Fuerza 999 = +50%). Asi no puedes llevar de todo con un zurron.
var fuerza_capacity_bonus_max: float = 0.5  # +50% a Fuerza maxima
# Sobrecarga GRADUAL: por encima del umbral, la penalizacion de velocidad crece
# con la pendiente hasta un maximo. Ej: 80% -> 0%, 90% -> ~33%, 100% -> ~66%.
var overload_threshold: float = 0.8    # % a partir del cual empiezas a ir lento
var overload_slope: float = 3.3        # cuanto crece la penalizacion por encima
var overload_max_penalty: float = 0.8  # penalizacion maxima (0.8 = -80% velocidad)


# Crea el Combatant del jugador con sus stats actuales (manteniendo la vida).
func crear_player_combatant() -> Combatant:
	var a := Abilities.new()
	a.fuerza = player_fuerza
	a.resistencia = player_resistencia
	a.destreza = player_destreza
	a.agilidad = player_agilidad
	a.magia = player_magia
	var c := Combatant.new("Heroe", player_level, a,
		player_base_hp, player_base_attack, player_base_defense, player_base_speed)
	if player_current_hp < 0:
		player_current_hp = c.max_hp  # primera vez: vida llena
	c.current_hp = clampi(player_current_hp, 0, c.max_hp)
	return c


# --- Peso / capacidad ---
func capacidad_carga() -> float:
	var contenedor: float = base_capacity + extra_capacity
	var mult: float = 1.0 + clampf(player_fuerza / 999.0, 0.0, 1.0) * fuerza_capacity_bonus_max
	return contenedor * mult

func peso_actual() -> float:
	var w: float = 0.0
	for c in crystals:
		w += c.peso()
	for d in drops:
		w += d.peso()
	return w

func ratio_carga() -> float:
	var cap: float = capacidad_carga()
	return 0.0 if cap <= 0.0 else peso_actual() / cap

func esta_sobrecargado() -> bool:
	return ratio_carga() >= overload_threshold

# Multiplicador de velocidad por sobrecarga (1.0 = normal). Baja GRADUALMENTE
# cuanto mas te pasas del umbral, hasta un suelo (1 - overload_max_penalty).
func overload_speed_factor() -> float:
	var over: float = ratio_carga() - overload_threshold
	if over <= 0.0:
		return 1.0
	var penalty: float = clampf(over * overload_slope, 0.0, overload_max_penalty)
	return 1.0 - penalty


# --- Subida de habilidades ---

# Suma una ganancia al INTERNO de una habilidad, con rendimientos decrecientes.
func ganar(abil: String, reto_val: float, base: float) -> void:
	if not ability_internal.has(abil):
		return
	var interno: float = ability_internal[abil]
	var gain: float = base * clampf(reto_val, 0.0, RETO_MAX) / (1.0 + interno * DIMINISH_K)
	ability_internal[abil] = interno + gain

# Poder del jugador (suma de visibles) con un suelo para no dividir por 0.
func poder_jugador_eff() -> float:
	var suma: float = float(player_fuerza + player_resistencia + player_destreza
		+ player_agilidad + player_magia)
	return maxf(suma, PODER_JUGADOR_SUELO)

# Dificultad relativa: enemigo/accion facil respecto a ti = poco.
func reto(poder_enemigo: float) -> float:
	return clampf(poder_enemigo / poder_jugador_eff(), 0.0, RETO_MAX)

# "Actualizar estado" (hogar / tu dios): aplica lo INTERNO a lo VISIBLE.
func actualizar_estado() -> void:
	player_fuerza = floori(ability_internal["fuerza"])
	player_resistencia = floori(ability_internal["resistencia"])
	player_destreza = floori(ability_internal["destreza"])
	player_agilidad = floori(ability_internal["agilidad"])
	player_magia = floori(ability_internal["magia"])
	print("=== ESTADO ACTUALIZADO ===  F:", player_fuerza, " R:", player_resistencia,
		" D:", player_destreza, " A:", player_agilidad, " M:", player_magia)


# Teclas de DESARROLLO (temporales): U actualizar estado, H cura, R respawn.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_U:
			actualizar_estado()
		KEY_H:
			player_current_hp = -1  # se rellena a tope en el proximo combate
			print("[dev] Vida al 100%")
		KEY_R:
			print("[dev] Respawn: recargando la mazmorra")
			get_tree().reload_current_scene()


# Abre el combate contra un enemigo de la mazmorra.
func start_combat(enemy_node: Node, enemy_data: EnemyData, enemy_initiated: bool) -> void:
	if _active_enemy != null or enemy_data == null:
		return  # ya hay un combate o faltan datos

	_active_enemy = enemy_node
	var player_c := crear_player_combatant()
	var power: float = 1.0
	if "current_power" in enemy_node:
		power = enemy_node.current_power
	var enemy_c := enemy_data.crear_combatant(power)

	# ¿El jugador entra agotado? (sus 2 primeras acciones seran mas lentas)
	var player_exhausted := false
	var pnode := get_tree().get_first_node_in_group("player")
	if pnode != null and pnode.has_method("is_exhausted"):
		player_exhausted = pnode.is_exhausted()

	var combat := _combat_scene.instantiate()
	# PROCESS_MODE_ALWAYS = el combate sigue funcionando aunque el arbol este en pausa.
	combat.process_mode = Node.PROCESS_MODE_ALWAYS
	combat.setup(player_c, enemy_c, enemy_initiated, player_exhausted, overload_speed_factor())
	combat.combat_finished.connect(_on_combat_finished)

	# Lo metemos en una CanvasLayer: asi NO le afecta la camara 2D de la
	# mazmorra (si no, la pantalla de combate sale descentrada).
	var layer := CanvasLayer.new()
	layer.layer = 100  # por encima de todo
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(layer)
	layer.add_child(combat)
	_active_layer = layer

	get_tree().paused = true  # congela la mazmorra mientras luchas


# Abre el minijuego de extraccion sobre el cuerpo de un enemigo.
func start_extraction(corpse: Node) -> void:
	if _active_layer != null or corpse == null:
		return
	var data: EnemyData = corpse.data
	if data == null:
		return

	# Categoria ponderada por el poder del bicho (t).
	var t: float = 0.5
	if corpse.has_method("poder_normalizado"):
		t = corpse.poder_normalizado()
	var categoria: int = data.roll_crystal_category(t)
	var eff_destreza: int = player_destreza + tool_destreza_bonus

	# Pulsaciones: base del enemigo, menos lo que ayuden las herramientas.
	var required_hits: int = clampi(data.extraction_hits - tool_hit_reduction, 2, 9)
	# Zona: escala con tu Destreza respecto a la "esperada" del enemigo (con topes).
	var req: int = maxi(1, data.extraction_req_destreza)
	var zone_ratio: float = clampf(0.13 * float(eff_destreza) / float(req), 0.05, 0.35)
	# Guardamos la dificultad para la ganancia de Destreza al terminar.
	_last_extraction_zone = zone_ratio
	_last_extraction_hits = required_hits
	# Marcador mas rapido cuanto mas profundo el piso, y acelera por acierto.
	var marker_speed: float = 0.8 + float(current_floor - 1) * 0.08
	var speed_step: float = 0.15

	var ex: Control = _extraction_script.new()
	ex.process_mode = Node.PROCESS_MODE_ALWAYS
	ex.setup(categoria, required_hits, zone_ratio, marker_speed, speed_step)
	ex.extraction_finished.connect(_on_extraction_finished.bind(corpse))

	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(layer)
	layer.add_child(ex)
	_active_layer = layer
	get_tree().paused = true


func _on_extraction_finished(cristal: Cristal, corpse: Node) -> void:
	get_tree().paused = false
	if is_instance_valid(corpse):
		corpse.extracted = true  # ya no se puede volver a extraer
		if corpse.has_method("desvanecer"):
			corpse.desvanecer()  # el cuerpo se desvanece y desaparece
	if is_instance_valid(_active_layer):
		_active_layer.queue_free()
	_active_layer = null

	if cristal != null and not cristal.se_pierde():
		crystals.append(cristal)
		print("Obtienes cristal categoria ", cristal.categoria,
			" (", cristal.calidad_texto(), "). Total: ", crystals.size())
		# Destreza: subes mas cuanto mas dificil era el minijuego (zona pequeña
		# + mas pulsaciones). Facil = poco.
		var dificultad: float = clampf((0.13 / _last_extraction_zone)
			* (float(_last_extraction_hits) / 3.0), 0.0, RETO_MAX)
		ganar("destreza", dificultad, GAIN_DESTREZA_MINIJUEGO)
	else:
		print("El cristal se rompio: lo has perdido.")

	# Drop raro del monstruo (probabilidad baja; en pruebas, 100%).
	if cristal != null and is_instance_valid(corpse) and corpse.data != null:
		_tirar_drop(corpse, cristal.categoria)


# Tira (o no) el drop del monstruo. Si sale, aparece en el SUELO (para
# recogerlo con F) DESPUES de que el cuerpo se desvanezca.
func _tirar_drop(corpse: Node, categoria: int) -> void:
	var data: EnemyData = corpse.data
	var chance: float = 1.0 if dev_force_drop else data.drop_chance
	if randf() >= chance:
		return

	# Valor en una franja de 3 que se desplaza con la categoria del cristal.
	var base: int = maxi(1, categoria - 2)
	var valor: int = randi_range(base, base + 2)
	var drop := MonsterDrop.new()
	drop.nombre = data.drop_name
	drop.calidad = MonsterDrop.calidad_desde_valor(valor)

	var pos: Vector2 = corpse.global_position
	var parent: Node = corpse.get_parent()

	# Esperamos a que el cuerpo termine de desvanecerse, y entonces dejamos
	# el drop en el suelo donde estaba.
	await get_tree().create_timer(0.7).timeout
	if parent != null and is_instance_valid(parent):
		var pickup: Node2D = _drop_pickup_script.new()
		pickup.setup(drop)
		parent.add_child(pickup)
		pickup.global_position = pos
		print("El monstruo deja un drop en el suelo: ", drop.nombre,
			" (", drop.calidad_texto(), ")")


func _on_combat_finished(player_won: bool, player_hp_left: int) -> void:
	get_tree().paused = false
	player_current_hp = player_hp_left

	# Si ganaste, el enemigo NO desaparece: queda como cadaver para poder
	# extraerle el cristal (minijuego, Fase 5).
	if player_won and is_instance_valid(_active_enemy) and _active_enemy.has_method("morir"):
		_active_enemy.morir()
	_active_enemy = null

	# Quitamos la capa del combate (con la pantalla dentro).
	if is_instance_valid(_active_layer):
		_active_layer.queue_free()
	_active_layer = null
