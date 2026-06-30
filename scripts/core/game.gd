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
var player_fuerza: int = 120
var player_resistencia: int = 90
var player_destreza: int = 60
var player_agilidad: int = 110
var player_magia: int = 20
var player_base_hp: float = 50.0
var player_base_attack: float = 5.0
var player_base_defense: float = 5.0
var player_base_speed: float = 5.0
# Vida actual (persiste entre combates). -1 = aun no inicializada (= llena).
var player_current_hp: int = -1

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
var dev_force_drop: bool = true

# Bonus de HERRAMIENTAS de recoleccion (cuchillos...). Placeholder hasta tener
# sistema de equipo: las herramientas rellenaran estos valores.
var tool_hit_reduction: int = 0    # reduce pulsaciones necesarias
var tool_destreza_bonus: int = 0   # Destreza extra para la extraccion


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


# Abre el combate contra un enemigo de la mazmorra.
func start_combat(enemy_node: Node, enemy_data: EnemyData, enemy_initiated: bool) -> void:
	if _active_enemy != null or enemy_data == null:
		return  # ya hay un combate o faltan datos

	_active_enemy = enemy_node
	var player_c := crear_player_combatant()
	var enemy_c := enemy_data.crear_combatant()

	var combat := _combat_scene.instantiate()
	# PROCESS_MODE_ALWAYS = el combate sigue funcionando aunque el arbol este en pausa.
	combat.process_mode = Node.PROCESS_MODE_ALWAYS
	combat.setup(player_c, enemy_c, enemy_initiated)
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

	var categoria: int = data.roll_crystal_category()
	var eff_destreza: int = player_destreza + tool_destreza_bonus

	# Pulsaciones: base del enemigo, menos lo que ayuden las herramientas.
	var required_hits: int = clampi(data.extraction_hits - tool_hit_reduction, 2, 9)
	# Zona: escala con tu Destreza respecto a la "esperada" del enemigo (con topes).
	var req: int = maxi(1, data.extraction_req_destreza)
	var zone_ratio: float = clampf(0.13 * float(eff_destreza) / float(req), 0.05, 0.35)
	# Marcador mas rapido cuanto mas profundo el piso, y acelera por acierto.
	var marker_speed: float = 0.8 + float(current_floor - 1) * 0.08
	var speed_step: float = 0.3

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
