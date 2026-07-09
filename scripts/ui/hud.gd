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
var _floor_lbl: Label = null    # "Piso: N" en la esquina superior derecha
var _peso_box: ColorRect = null # cuadrado (placeholder de bolsa) a la derecha de las barras
var _peso_lbl: Label = null     # numero de peso encima del cuadrado
var _panel: ColorRect = null
var _list: Label = null
var _objetos_box: VBoxContainer = null   # botones para BEBER pociones (elegir cual)
var _panel_open: bool = false
var _toggle_was: bool = false


func _ready() -> void:
	layer = 5  # por encima de la mazmorra, por debajo del combate (100)

	# Un HUD recien creado SIEMPRE arranca con el inventario cerrado. Reiniciamos
	# el flag global por si veniamos de una escena con el inventario abierto (p.ej.
	# pulsar R para recargar teniendolo abierto): si no, el jugador nuevo se
	# quedaria congelado creyendo que el inventario sigue abierto.
	Game.inventory_open = false

	# Ayudas de tecla, debajo de las barras de aguante/vida/mana del jugador.
	_counts = Label.new()
	_counts.position = Vector2(12, 66)
	add_child(_counts)

	# "Piso: N" en la esquina superior derecha.
	_floor_lbl = Label.new()
	_floor_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_floor_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_floor_lbl.offset_left = -160
	_floor_lbl.offset_right = -12
	_floor_lbl.offset_top = 10
	add_child(_floor_lbl)

	# Cuadrado de PESO (placeholder de una futura bolsa/mochila) a la derecha de las
	# barras, con el numero encima. Cambia de color segun te vas cargando.
	_peso_box = ColorRect.new()
	_peso_box.position = Vector2(200, 16)
	_peso_box.size = Vector2(44, 44)
	add_child(_peso_box)

	_peso_lbl = Label.new()
	_peso_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_peso_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_peso_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_peso_lbl.add_theme_font_size_override("font_size", 11)
	_peso_lbl.add_theme_color_override("font_color", Color.WHITE)
	_peso_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_peso_lbl.add_theme_constant_override("outline_size", 4)
	_peso_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_peso_box.add_child(_peso_lbl)

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

	# Dentro del scroll: BOTONES de objetos (elegir poción) arriba + la lista de texto debajo.
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vb)

	_objetos_box = VBoxContainer.new()
	_objetos_box.add_theme_constant_override("separation", 3)
	vb.add_child(_objetos_box)

	_list = Label.new()
	vb.add_child(_list)


func _process(_delta: float) -> void:
	# Ayudas de tecla (el resto de datos viven en las barras / cuadrado de peso / inventario).
	_counts.text = "[I] Inv   [Q] Óptima"

	# Piso arriba a la derecha.
	_floor_lbl.text = "Piso: %d" % Game.current_floor

	# Cuadrado de PESO: numero encima y color por ratio de carga.
	# Blanco/gris cuando vas ligero -> amarillo al acercarte al limite -> rojo sobrecargado.
	_peso_lbl.text = "%d/%d" % [roundi(Game.peso_actual()), roundi(Game.capacidad_carga())]
	var ratio: float = Game.ratio_carga()
	var col: Color
	if Game.esta_sobrecargado():
		col = Color(0.85, 0.15, 0.15)  # rojo pleno
	else:
		# 0..overload_threshold -> gris a amarillo.
		var t: float = clampf(ratio / maxf(0.01, Game.overload_threshold), 0.0, 1.0)
		col = Color(0.35, 0.35, 0.38).lerp(Color(0.9, 0.8, 0.1), t)
	_peso_box.color = col

	# Alterna el panel con la tecla I.
	var t: bool = Input.is_key_pressed(KEY_I)
	if t and not _toggle_was:
		_panel_open = not _panel_open
		_panel.visible = _panel_open
		Game.inventory_open = _panel_open  # bloquea/desbloquea al jugador
		if _panel_open:
			_build_objeto_buttons()   # botones de pociones (elegir) al abrir
	_toggle_was = t

	# Refresca la lista en vivo mientras esta abierto.
	if _panel_open:
		_refrescar_lista()


# Construye los botones para ELEGIR que poción beber (fuera de combate) + el de recuperación
# óptima (auto). Se reconstruye al abrir el panel y tras cada trago (cambian las cantidades).
func _build_objeto_buttons() -> void:
	if _objetos_box == null:
		return
	for c in _objetos_box.get_children():
		c.queue_free()
	var maxhp: float = Game.player_max_hp()
	var maxmp: float = Game.player_max_mp()
	# Botón de recuperación óptima (auto: bebe lo que menos desperdicie).
	var opt := Button.new()
	opt.text = "🧪 Recuperación óptima (auto)   [Q]"
	opt.pressed.connect(func(): Game.beber_optima(); _build_objeto_buttons())
	_objetos_box.add_child(opt)
	# Un botón por poción para ELEGIR cuál beber.
	if Game.consumibles_total() <= 0:
		var l := Label.new()
		l.text = "  (sin pociones)"
		_objetos_box.add_child(l)
	else:
		for cons in Game.consumables.keys():
			var n: int = int(Game.consumables[cons])
			if n <= 0:
				continue
			var b := Button.new()
			b.text = "Beber %s  x%d  (%s)" % [cons.nombre, n, cons.resumen(maxhp, maxmp)]
			b.pressed.connect(func(): Game.beber_pocion_fuera(cons); _build_objeto_buttons())
			_objetos_box.add_child(b)


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

	# (Los OBJETOS/pociones se muestran arriba como BOTONES para elegir cuál beber.)

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
