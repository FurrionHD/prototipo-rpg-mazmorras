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
@export var stamina_per_resistencia: float = 0.075  # extra por Resistencia (bajado: la energia ya la gastan habilidades)
@export var stamina_per_agilidad: float = 0.025     # extra por Agilidad
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

# Ataque cuerpo a cuerpo para INICIAR combate (corto alcance hacia delante).
@export var attack_range: float = 44.0
@export var attack_half_angle_deg: float = 70.0

# Interaccion (F) con cadaveres para extraer el cristal.
@export var interact_range: float = 40.0
var _interact_was: bool = false

# Barras de estado (se crean por codigo, ver _crear_barra_aguante): aguante + vida + mana.
var _stamina_bar: ProgressBar = null
var _hp_bar: ProgressBar = null
var _mp_bar: ProgressBar = null
# Numeros superpuestos DENTRO de cada barra (energia/vida/mana).
var _stamina_lbl: Label = null
var _hp_lbl: Label = null
var _mp_lbl: Label = null
var _drink_was: bool = false   # antirebote de la tecla Q (beber pocion)

# Excelia (subida de habilidades por uso): distancia recorrida para Fuerza
# (cargando en sobrecarga) y Agilidad (corriendo cerca de un enemigo).
var _last_pos: Vector2 = Vector2.ZERO
var _dist_overload: float = 0.0
var _dist_run: float = 0.0
const _DIST_TICK := 110.0       # px recorridos por cada "tick" de ganancia
const _AGILIDAD_RANGE := 220.0  # correr solo cuenta con un enemigo a este rango


func _ready() -> void:
	_stamina_bar = _crear_barra_aguante()
	add_child(preload("res://scripts/ui/hud.gd").new())  # HUD (barras, peso, piso, ayudas)
	add_child(preload("res://scripts/ui/inventory_menu.gd").new())  # inventario (I)
	add_child(preload("res://scripts/ui/character_menu.gd").new())  # menu de personaje (C)
	add_child(preload("res://scripts/ui/debug_panel.gd").new())  # panel de debug (cualquier sala)
	add_child(preload("res://scripts/ui/spawner.gd").new())      # spawner de enemigos (dev/test)
	add_child(preload("res://scripts/ui/keys_help.gd").new())    # ayuda de teclas en pantalla (F1)
	_last_pos = global_position

	# Si llegamos a esta escena con F/Q ya pulsadas (p. ej. justo despues de viajar
	# por una puerta), las marcamos como "ya pulsadas" para NO dispararlas de nuevo
	# hasta que el jugador las suelte y las vuelva a pulsar. Esto evita el rebote
	# entre escenas al mantener F pulsada.
	_interact_was = Input.is_key_pressed(KEY_F)
	_drink_was = Input.is_key_pressed(KEY_Q)

	# Aguante maximo segun las stats del jugador (Resistencia y Agilidad).
	max_stamina = _calc_max_aguante()
	current_stamina = max_stamina
	_stamina_bar.max_value = max_stamina
	_stamina_bar.value = current_stamina

	# Recuperacion segun el nivel (fija, no depende de stats).
	_regen_actual = stamina_regen + stamina_regen_per_level * (Game.player_level - 1)


func _physics_process(delta: float) -> void:
	# Con el inventario abierto: no te mueves ni interactuas (F/ataque). El
	# enemigo sigue su IA aparte, asi que puede emboscarte igualmente. Pero el
	# TIEMPO pasa, asi que el aguante se sigue recuperando.
	Game.tick_heal(delta)         # cura de pociones (fuera de combate) corre siempre que pasa el tiempo
	Game.tick_mana_regen(delta)   # regen pasiva de mana por el mapa (KAN-56/57)
	Game.tick_mana_pocion(delta)  # maná de pociones de maná (fuera de combate)
	_actualizar_max_aguante()     # el maximo escala con Resistencia/Agilidad (refresca si cambian las stats)
	if Game.inventory_open or Game.debug_panel_open:
		velocity = Vector2.ZERO
		current_stamina = minf(max_stamina, current_stamina + _regen_actual * delta)
		if _exhausted and current_stamina >= max_stamina * exhausted_recover_ratio:
			_exhausted = false
		_actualizar_barra_aguante()
		_refrescar_barras_vida()
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

	_actualizar_barra_aguante()
	_refrescar_barras_vida()

	# Sobrecarga (loot): cuanto mas peso en la mochila, mas lento (gradual).
	speed *= Game.overload_speed_factor()
	# Armadura: la categoria modula la velocidad de movimiento (placas te frenan,
	# ir ligero/sin armadura te acelera un pelin). Igual que en el ATB de combate.
	speed *= Game.armor_speed_mult()

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
			Game.ganar("fuerza", clampf(over * 5.0, 0.0, Game.RETO_MAX_FISICO), Game.GAIN_FUERZA_PESO,
				Game.RETO_MAX_FISICO)

	# Agilidad: CORRER cerca de un enemigo (correr sin enemigos no sirve).
	if moved > 0.0 and movement_mode == 2:
		var enemigo: Node = _enemigo_cercano_agilidad()
		if enemigo != null:
			_dist_run += moved
			while _dist_run >= _DIST_TICK:
				_dist_run -= _DIST_TICK
				Game.ganar("agilidad", Game.reto(_poder_enemigo_nodo(enemigo)), Game.GAIN_AGILIDAD_CORRER,
					Game.RETO_MAX_FISICO)

	# F lo hace TODO (mas intuitivo): atacar al enemigo que tengas enfrente, hablar con un
	# NPC, extraer el cristal de un cadaver o recoger un item. Ver _try_interact().
	var inter: bool = Input.is_key_pressed(KEY_F)
	if inter and not _interact_was:
		_try_interact()
	_interact_was = inter

	# Beber una pocion (Q): cura por el tiempo fuera de combate.
	var drink: bool = Input.is_key_pressed(KEY_Q)
	if drink and not _drink_was:
		_beber_pocion()
	_drink_was = drink


# Aguante maximo segun las stats ACTUALES (Resistencia y Agilidad).
func _calc_max_aguante() -> float:
	return base_stamina \
		+ Game.player_resistencia * stamina_per_resistencia \
		+ Game.player_agilidad * stamina_per_agilidad

# Recalcula el aguante maximo por si las stats cambiaron (panel DEBUG, tecla U, subida en
# el hogar...). Si la barra estaba llena, la mantiene llena; si no, respeta lo que quede.
func _actualizar_max_aguante() -> void:
	var nuevo: float = _calc_max_aguante()
	if is_equal_approx(nuevo, max_stamina):
		return
	var estaba_llena: bool = current_stamina >= max_stamina - 0.01
	max_stamina = nuevo
	current_stamina = max_stamina if estaba_llena else minf(current_stamina, max_stamina)
	_stamina_bar.max_value = max_stamina


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


# Poder de un enemigo (suma de habilidades segun su 't') para el "reto".
func _poder_enemigo_nodo(e: Node) -> float:
	if e == null or not is_instance_valid(e) or e.data == null:
		return 0.0
	var t: float = 0.5
	if "current_t" in e:
		t = e.current_t
	return float(e.data.suma_habilidades(t))


# Busca un enemigo VIVO justo enfrente y muy cerca; si lo hay, inicia el combate
# con NUESTRA iniciativa. Devuelve true si ataco (lo usa _try_interact para saber
# si ya ha consumido la pulsacion de F).
func _try_attack() -> bool:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var to_e: Vector2 = e.global_position - global_position
		var dist: float = to_e.length()
		if dist <= attack_range and dist > 0.01:
			if absf(_facing.angle_to(to_e / dist)) <= deg_to_rad(attack_half_angle_deg):
				if e.has_method("atacado_por_jugador"):
					e.atacado_por_jugador()
					return true
	return false


# TODO va con F (una sola tecla, mas intuitivo). Por orden:
#   0) ATACAR a un enemigo vivo que tengas ENFRENTE -> inicia el combate.
#   1) NPC interactuable (altar, tienda, puerta, hogar).
#   2) EXTRAER el cristal de un cadaver.
#   3) RECOGER un item del suelo.
# El ataque va primero porque exige MIRAR al bicho (cono frontal), asi que es una
# accion deliberada: no se dispara por accidente mientras looteas de espaldas.
func _try_interact() -> void:
	# 0) Enemigo vivo enfrente -> a por el.
	if _try_attack():
		return

	# 1) NPCs interactuables (altar, tienda, puerta, etc).
	var interactable: Node = _mas_cercano_en_grupo("interactable", false)
	if interactable != null and interactable.has_method("interact_with_player"):
		interactable.interact_with_player()
		return

	# 1) Cadaver para extraer.
	var corpse: Node = _mas_cercano_en_grupo("corpse", true)
	if corpse != null:
		Game.start_extraction(corpse)
		return

	# 2) Item del suelo para recoger (drop del monstruo o cristal soltado del inventario).
	var pickup: Node = _mas_cercano_en_grupo("pickup", false)
	if pickup != null and pickup.has_method("recoger"):
		var item: Resource = pickup.recoger()
		if item is MonsterDrop:
			var d := item as MonsterDrop
			Game.drops.append(d)
			print("Recoges: ", d.nombre, " (", d.calidad_texto(), "). Total drops: ", Game.drops.size())
		elif item is Cristal:
			var c := item as Cristal
			Game.crystals.append(c)
			print("Recoges: Cristal Cat ", c.categoria, " (", c.calidad_texto(),
				"). Total cristales: ", Game.crystals.size())


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
		# Los cuerpos GRANDES (elites) te empujan mas lejos de su centro con su propia
		# colision, asi que descontamos lo que sobresalen: la distancia se mide contra el
		# BORDE del bicho, no su centro. Tamaño normal -> radio_extra 0 (nada cambia).
		var extra: float = float(n.radio_extra) if "radio_extra" in n else 0.0
		var d: float = maxf(0.0, global_position.distance_to(n.global_position) - extra)
		if d <= interact_range and d < best:
			best = d
			nearest = n
	return nearest


# Crea las barritas de estado en pantalla (arriba a la izquierda): AGUANTE (verde),
# VIDA (roja) y MANA (azul), apiladas. Van en su propia CanvasLayer para que no las
# mueva la camara. Devuelve la de aguante (las de vida/mana quedan en _hp_bar/_mp_bar).
func _crear_barra_aguante() -> ProgressBar:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	# VIDA (roja) ARRIBA y mas GORDA: es la barra mas importante.
	# Usamos self_modulate para tintar SOLO el relleno, no el numero (hijo) superpuesto.
	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(180, 18)
	_hp_bar.position = Vector2(12, 12)
	_hp_bar.self_modulate = Color(1.0, 0.4, 0.4)
	layer.add_child(_hp_bar)
	_hp_lbl = _crear_label_barra(_hp_bar)

	# AGUANTE (verde) debajo de la vida.
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(180, 12)
	bar.position = Vector2(12, 34)
	bar.self_modulate = Color(0.4, 1.0, 0.5)
	layer.add_child(bar)
	_stamina_lbl = _crear_label_barra(bar)

	# MANA (azul) debajo del aguante.
	_mp_bar = ProgressBar.new()
	_mp_bar.show_percentage = false
	_mp_bar.custom_minimum_size = Vector2(180, 12)
	_mp_bar.position = Vector2(12, 50)
	_mp_bar.self_modulate = Color(0.4, 0.6, 1.0)
	layer.add_child(_mp_bar)
	_mp_lbl = _crear_label_barra(_mp_bar)
	return bar


# Crea un Label centrado que cubre toda la barra, para pintar el numero DENTRO.
# Con outline oscuro para leerse sobre cualquier color de relleno.
func _crear_label_barra(bar: ProgressBar) -> Label:
	var l := Label.new()
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(l)
	return l


# Actualiza la barra de aguante: valor, tinte (verde normal / rojizo agotado) y numero.
func _actualizar_barra_aguante() -> void:
	_stamina_bar.value = current_stamina
	# Pista visual: el relleno se pone rojizo mientras estas agotado.
	_stamina_bar.self_modulate = Color(1.0, 0.4, 0.4) if _exhausted else Color(0.4, 1.0, 0.5)
	if _stamina_lbl != null:
		_stamina_lbl.text = "%.0f/%.0f" % [current_stamina, max_stamina]


# Refresca las barras de VIDA y MANA con el estado persistente de Game (valen tanto
# con el inventario abierto como explorando; la vida sube con la cura de pociones).
func _refrescar_barras_vida() -> void:
	if _hp_bar != null:
		var maxhp: float = Game.player_max_hp()
		var hp: float = Game.player_hp()
		_hp_bar.max_value = maxhp
		_hp_bar.value = hp
		if _hp_lbl != null:
			_hp_lbl.text = "%.1f/%.1f" % [hp, maxhp]
	if _mp_bar != null:
		var maxmp: float = Game.player_max_mp()
		var curmp: float = Game.player_current_mp if Game.player_current_mp >= 0.0 else maxmp
		_mp_bar.max_value = maxf(1.0, maxmp)
		_mp_bar.value = curmp
		if _mp_lbl != null:
			_mp_lbl.text = "%.2f/%.2f" % [curmp, maxmp]


# Bebe la PRIMERA poción del inventario (tecla Q, fuera de combate). Arranca la
# cura-por-tiempo de Game (no hace nada si no tienes pociones o ya estas a tope).
func _beber_pocion() -> void:
	# Q = recuperación óptima (auto). Para ELEGIR una poción concreta, abre el inventario (I).
	Game.beber_optima()
