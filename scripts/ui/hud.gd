# ============================================================
#  hud.gd  (CanvasLayer creada por codigo desde el jugador)
#  HUD de exploracion:
#   - Contador SIEMPRE visible (arriba-izquierda): cristales y drops.
#   - Panel de INVENTARIO que se abre/cierra con la tecla I: lista de
#     cristales y drops (categoria/calidad) y el valor total estimado.
#  Lee los datos del autoload Game (Game.crystals / Game.drops).
# ============================================================

extends CanvasLayer

var _counts: Label = null
var _panel: ColorRect = null
var _list: Label = null
var _panel_open: bool = false
var _toggle_was: bool = false


func _ready() -> void:
	layer = 5  # por encima de la mazmorra, por debajo del combate (100)

	# Un HUD recien creado SIEMPRE arranca con el inventario cerrado. Reiniciamos
	# el flag global por si veniamos de una escena con el inventario abierto (p.ej.
	# pulsar R para recargar teniendolo abierto): si no, el jugador nuevo se
	# quedaria congelado creyendo que el inventario sigue abierto.
	Game.inventory_open = false

	# Contador siempre visible (debajo de la barra de aguante).
	_counts = Label.new()
	_counts.position = Vector2(12, 34)
	add_child(_counts)

	# Panel de inventario (oculto por defecto), a pantalla completa oscura.
	_panel = ColorRect.new()
	_panel.color = Color(0.05, 0.05, 0.08, 0.95)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	add_child(_panel)

	# ScrollContainer con margenes: permite scrollear cuando la lista es larga.
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 40
	scroll.offset_top = 40
	scroll.offset_right = -40
	scroll.offset_bottom = -40
	_panel.add_child(scroll)

	_list = Label.new()
	scroll.add_child(_list)


func _process(_delta: float) -> void:
	# Actualiza el contador (con dinero, MANA, peso de LOOT y velocidad de armadura).
	# El mana SIEMPRE visible (-1 = lleno), con 2 decimales para ver el regen fino.
	var max_mp: float = Game.player_max_mp()
	var cur_mp: float = Game.player_current_mp if Game.player_current_mp >= 0.0 else max_mp
	_counts.text = "Piso: %d   Dinero: %d   Mana: %.2f/%.2f   Cristales: %d   Drops: %d   Peso: %d/%d   Vel arm: x%.2f   [I] Inventario" % [
		Game.current_floor, Game.money, cur_mp, max_mp, Game.crystals.size(), Game.drops.size(),
		roundi(Game.peso_actual()), roundi(Game.capacidad_carga()),
		Game.armor_speed_mult()]
	# Tinta rojizo solo si vas SOBRECARGADO de loot (la armadura es un tradeoff, no un mal).
	if Game.esta_sobrecargado():
		_counts.text += "   (SOBRECARGADO)"
		_counts.modulate = Color(1.0, 0.5, 0.5)
	else:
		_counts.modulate = Color.WHITE

	# Alterna el panel con la tecla I.
	var t: bool = Input.is_key_pressed(KEY_I)
	if t and not _toggle_was:
		_panel_open = not _panel_open
		_panel.visible = _panel_open
		Game.inventory_open = _panel_open  # bloquea/desbloquea al jugador
	_toggle_was = t

	# Refresca la lista en vivo mientras esta abierto.
	if _panel_open:
		_refrescar_lista()


func _refrescar_lista() -> void:
	var s: String = "INVENTARIO   ( [I] para cerrar )\n\n"

	# --- HABILIDADES arriba (siempre visibles, aunque el inventario este lleno) ---
	var ai: Dictionary = Game.ability_internal
	s += "HABILIDADES (visible / interno):\n"
	s += "  Fuerza: %d / %.1f     Resistencia: %d / %.1f     Destreza: %d / %.1f\n" % [
		Game.player_fuerza, ai["fuerza"], Game.player_resistencia, ai["resistencia"],
		Game.player_destreza, ai["destreza"]]
	s += "  Agilidad: %d / %.1f    Magia: %d / %.1f\n" % [
		Game.player_agilidad, ai["agilidad"], Game.player_magia, ai["magia"]]
	# Mana (KAN-56): -1 = lleno. Con 2 decimales (regen fino y mejoras pequeñas).
	var max_mp: float = Game.player_max_mp()
	var cur_mp: float = Game.player_current_mp if Game.player_current_mp >= 0.0 else max_mp
	s += "  Mana: %.2f / %.2f    Hechizos equipados: %d\n" % [
		cur_mp, max_mp, Game.equipped_spells.size()]
	s += "  [U] actualizar estado   [H] curar 100%   [R] respawn\n\n"

	# --- Dinero, peso / valor ---
	var total: int = 0
	for c in Game.crystals:
		total += c.valor_estimado()
	for d in Game.drops:
		total += d.valor_estimado()
	s += "DINERO: %d\n" % Game.money
	s += "PESO LOOT: %d / %d" % [roundi(Game.peso_actual()), roundi(Game.capacidad_carga())]
	if Game.esta_sobrecargado():
		s += "  (SOBRECARGADO: vas mas lento)"
	# Velocidad de la armadura (combate y mapa): >1 acelera, <1 frena.
	var avel: float = Game.armor_speed_mult()
	s += "\nVELOCIDAD ARMADURA: x%.2f" % avel
	if avel > 1.0:
		s += "  (+%d%% por ir ligero)" % roundi((avel - 1.0) * 100.0)
	elif avel < 1.0:
		s += "  (-%d%% por armadura pesada)" % roundi((1.0 - avel) * 100.0)
	s += "\nVALOR TOTAL ESTIMADO: %d\n\n" % total

	# --- Cristales AGRUPADOS (categoria + calidad) ---
	s += "CRISTALES (%d):\n" % Game.crystals.size()
	if Game.crystals.is_empty():
		s += "  (vacio)\n"
	else:
		var grupos: Dictionary = {}
		for c in Game.crystals:
			var k: String = "%d|%s" % [c.categoria, c.calidad_texto()]
			grupos[k] = grupos.get(k, 0) + 1
		for k in grupos:
			var p: PackedStringArray = k.split("|")
			s += "  Cat %s (%s)  x%d\n" % [p[0], p[1], grupos[k]]

	# --- Drops AGRUPADOS ---
	s += "\nDROPS (%d):\n" % Game.drops.size()
	if Game.drops.is_empty():
		s += "  (vacio)\n"
	else:
		var gd: Dictionary = {}
		for d in Game.drops:
			var k: String = "%s|%s" % [d.nombre, d.calidad_texto()]
			gd[k] = gd.get(k, 0) + 1
		for k in gd:
			var p: PackedStringArray = k.split("|")
			s += "  %s (%s)  x%d\n" % [p[0], p[1], gd[k]]

	_list.text = s
