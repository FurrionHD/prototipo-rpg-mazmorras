# ============================================================
#  debug_panel.gd  (CanvasLayer creada por codigo desde el jugador)
#  Panel de DEBUG clicable, disponible en CUALQUIER sala. Herramientas:
#   - STATS: escribir las 5 habilidades y aplicarlas.
#   - ENEMIGO: presets Base/200/500/Cheto + selector de PISO.
#   - ARMADURA por pieza: tipo + tier + rareza.
#   - ARMAS: principal/secundaria + tier + rareza.
#   - MEJORAS: elegir slot y repartir mejoras por categoria (segun rareza).
#  Todo por codigo (UI placeholder). Mientras esta abierto congela al jugador.
# ============================================================

extends CanvasLayer

const ARMOR_PREFIX := ["", "cuero", "hierro", "hierro_completo", "placas"]  # idx dropdown -> material
const ARMOR_LABELS := ["Nada", "Cuero", "Hierro", "Hierro compl.", "Placas"]
const ARMOR_SLOTS := ["casco", "pecho", "manos", "pantalones", "botas"]
const ENEMY_PRESETS := [["Base", -1], ["200", 200], ["500", 500], ["Cheto", 999]]
# Slots para el selector de MEJORAS: [etiqueta, clave].
const MEJ_SLOTS := [["Principal", "main"], ["Secundaria", "off"], ["Casco", "casco"],
	["Pecho", "pecho"], ["Manos", "manos"], ["Pantalones", "pantalones"], ["Botas", "botas"]]

var _panel: PanelContainer = null
var _open: bool = false

var _stat_edits: Dictionary = {}
var _enemy_buttons: Array = []
var _floor_edit: LineEdit = null
var _armor_opts: Dictionary = {}         # slot -> OptionButton (tipo)
var _armor_tier_opts: Dictionary = {}    # slot -> OptionButton (tier)
var _armor_rareza_opts: Dictionary = {}  # slot -> OptionButton (rareza)
var _main_opt: OptionButton = null
var _main_tier_opt: OptionButton = null
var _main_rareza_opt: OptionButton = null
var _off_opt: OptionButton = null
var _off_tier_opt: OptionButton = null
var _off_rareza_opt: OptionButton = null
# HECHIZOS (KAN-56)
var _spell_checks: Dictionary = {}       # path .tres -> CheckBox
# MEJORAS
var _mej_slot_opt: OptionButton = null
var _mej_info: Label = null
var _mej_rows: VBoxContainer = null


# OptionButton de tier (T1..T3). El callback recibe el TIER (1..3).
func _make_tier_opt(cb: Callable) -> OptionButton:
	var opt := OptionButton.new()
	for t in [1, 2, 3]:
		opt.add_item("T%d" % t, t)
	opt.item_selected.connect(func(idx): cb.call(idx + 1))
	return opt

# OptionButton de rareza (0..6) para un slot dado.
func _make_rareza_opt(slot: String) -> OptionButton:
	var opt := OptionButton.new()
	for i in Upgrades.RAREZA_NOMBRE.size():
		opt.add_item(Upgrades.RAREZA_NOMBRE[i], i)
	opt.item_selected.connect(func(idx):
		Game.set_equip_rareza(slot, idx)
		_rebuild_mejoras())
	return opt


func _ready() -> void:
	layer = 6

	var toggle := Button.new()
	toggle.text = "DEBUG"
	toggle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	toggle.offset_left = 8
	toggle.offset_top = -34
	toggle.offset_bottom = -8
	toggle.pressed.connect(_toggle)
	add_child(toggle)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_panel.offset_left = 8
	_panel.offset_bottom = -40
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.grow_horizontal = Control.GROW_DIRECTION_END
	_panel.visible = false
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)

	# Scroll para que no se salga por arriba con tantas secciones.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(380, 560)
	margin.add_child(scroll)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vb)

	_build_stats(vb)
	_sep(vb)
	_build_enemy(vb)
	_sep(vb)
	_build_armor(vb)
	_sep(vb)
	_build_weapons(vb)
	_sep(vb)
	_build_spells(vb)
	_sep(vb)
	_build_mejoras(vb)


# --- Secciones -----------------------------------------------

func _header(vb: VBoxContainer, txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	vb.add_child(l)

func _sep(vb: VBoxContainer) -> void:
	vb.add_child(HSeparator.new())


func _build_stats(vb: VBoxContainer) -> void:
	_header(vb, "STATS (escribe y Aplicar)")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	vb.add_child(row)
	var keys := [["F", "fuerza"], ["R", "resistencia"], ["D", "destreza"],
		["A", "agilidad"], ["M", "magia"]]
	for k in keys:
		var lbl := Label.new()
		lbl.text = k[0]
		row.add_child(lbl)
		var e := LineEdit.new()
		e.custom_minimum_size = Vector2(48, 0)
		e.alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.text_submitted.connect(func(_t): _apply_stats())
		row.add_child(e)
		_stat_edits[k[1]] = e
	var apply := Button.new()
	apply.text = "Aplicar"
	apply.pressed.connect(_apply_stats)
	row.add_child(apply)


func _build_enemy(vb: VBoxContainer) -> void:
	_header(vb, "Fuerza del ENEMIGO")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	vb.add_child(row)
	for preset in ENEMY_PRESETS:
		var b := Button.new()
		b.text = preset[0]
		b.toggle_mode = true
		b.pressed.connect(_set_enemy.bind(preset[1]))
		row.add_child(b)
		_enemy_buttons.append([b, preset[1]])
	var frow := HBoxContainer.new()
	frow.add_theme_constant_override("separation", 4)
	vb.add_child(frow)
	var flbl := Label.new()
	flbl.text = "Piso"
	frow.add_child(flbl)
	_floor_edit = LineEdit.new()
	_floor_edit.custom_minimum_size = Vector2(48, 0)
	_floor_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floor_edit.text_submitted.connect(func(_t): _apply_floor())
	frow.add_child(_floor_edit)
	var fapply := Button.new()
	fapply.text = "Aplicar"
	fapply.pressed.connect(_apply_floor)
	frow.add_child(fapply)


func _build_armor(vb: VBoxContainer) -> void:
	_header(vb, "ARMADURA (tipo / tier / rareza)")
	var nombres := {"casco": "Casco", "pecho": "Pecho", "manos": "Manos",
		"pantalones": "Pantalon", "botas": "Botas"}
	for slot in ARMOR_SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		vb.add_child(row)
		var lbl := Label.new()
		lbl.text = nombres[slot]
		lbl.custom_minimum_size = Vector2(72, 0)
		row.add_child(lbl)
		var opt := OptionButton.new()
		for i in ARMOR_LABELS.size():
			opt.add_item(ARMOR_LABELS[i], i)
		opt.item_selected.connect(_set_armor.bind(slot))
		row.add_child(opt)
		_armor_opts[slot] = opt
		var topt := _make_tier_opt(_set_armor_tier.bind(slot))
		row.add_child(topt)
		_armor_tier_opts[slot] = topt
		var ropt := _make_rareza_opt(slot)
		row.add_child(ropt)
		_armor_rareza_opts[slot] = ropt


func _build_weapons(vb: VBoxContainer) -> void:
	_header(vb, "ARMAS (arma / tier / rareza)")
	# Principal
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	vb.add_child(row1)
	var l1 := Label.new()
	l1.text = "Principal"
	l1.custom_minimum_size = Vector2(72, 0)
	row1.add_child(l1)
	_main_opt = OptionButton.new()
	for i in Game._dev_weapons.size():
		var w: WeaponData = load(Game._dev_weapons[i])
		_main_opt.add_item(w.nombre, i)
	_main_opt.item_selected.connect(_set_main)
	row1.add_child(_main_opt)
	_main_tier_opt = _make_tier_opt(func(t): Game.set_equip_tier("main", t))
	row1.add_child(_main_tier_opt)
	_main_rareza_opt = _make_rareza_opt("main")
	row1.add_child(_main_rareza_opt)
	# Secundaria
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	vb.add_child(row2)
	var l2 := Label.new()
	l2.text = "Secundaria"
	l2.custom_minimum_size = Vector2(72, 0)
	row2.add_child(l2)
	_off_opt = OptionButton.new()
	for i in Game._dev_offs.size():
		_off_opt.add_item(_off_label(Game._dev_offs[i]), i)
	_off_opt.item_selected.connect(_set_off)
	row2.add_child(_off_opt)
	_off_tier_opt = _make_tier_opt(func(t): Game.set_equip_tier("off", t))
	row2.add_child(_off_tier_opt)
	_off_rareza_opt = _make_rareza_opt("off")
	row2.add_child(_off_rareza_opt)


# HECHIZOS (KAN-56): equipar/quitar hechizos (multi-seleccion con checkboxes). El
# jugador empieza SIN hechizos; aqui se le equipan para probar.
func _build_spells(vb: VBoxContainer) -> void:
	_header(vb, "HECHIZOS (equipar/quitar)")
	for i in Game._dev_spells.size():
		var spell: SpellData = load(Game._dev_spells[i])
		var cb := CheckBox.new()
		cb.text = "%s  (%d MP · %d frase%s)" % [
			spell.nombre, spell.coste_mana, spell.longitud(),
			"" if spell.longitud() == 1 else "s"]
		cb.toggled.connect(_set_spell.bind(spell))
		_spell_checks[Game._dev_spells[i]] = cb
		vb.add_child(cb)


func _set_spell(pressed: bool, spell: SpellData) -> void:
	if pressed:
		Game.equipar_hechizo(spell)
	else:
		Game.quitar_hechizo(spell)


func _build_mejoras(vb: VBoxContainer) -> void:
	_header(vb, "MEJORAS")
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	vb.add_child(top)
	_mej_slot_opt = OptionButton.new()
	for i in MEJ_SLOTS.size():
		_mej_slot_opt.add_item(MEJ_SLOTS[i][0], i)
	_mej_slot_opt.item_selected.connect(func(_i): _rebuild_mejoras())
	top.add_child(_mej_slot_opt)
	_mej_info = Label.new()
	top.add_child(_mej_info)
	_mej_rows = VBoxContainer.new()
	_mej_rows.add_theme_constant_override("separation", 3)
	vb.add_child(_mej_rows)


func _off_label(path) -> String:
	if path == null:
		return "Nada"
	var res: Resource = load(path)
	if res is WeaponData:
		return (res as WeaponData).nombre + " (dual)"
	if res is WandData:
		return (res as WandData).nombre + " (varita)"
	if res is ShieldData:
		return (res as ShieldData).nombre
	return "?"


# --- MEJORAS: reconstruir las filas de categoria del slot elegido ---

func _current_mej_slot() -> String:
	return MEJ_SLOTS[_mej_slot_opt.selected][1]

func _slot_item(slot: String):
	if slot == "main":
		return Game.equipped_main
	if slot == "off":
		return Game.equipped_off
	return Game.get("equipped_" + slot)

func _slot_categories(slot: String) -> Array:
	var item = _slot_item(slot)
	if item is WeaponData:
		return Upgrades.weapon_categories(item)
	if item is WandData:
		return Upgrades.wand_categories()   # varita: mejoras magicas
	if item is ArmorData:
		return Upgrades.armor_categories(item)
	return []   # escudo / vacio: sin mejoras

func _rebuild_mejoras() -> void:
	if _mej_rows == null:
		return
	for c in _mej_rows.get_children():
		c.queue_free()
	var slot := _current_mej_slot()
	var cats := _slot_categories(slot)
	var mj: Dictionary = Game.equip_mejoras(slot)
	var maxm: int = Upgrades.rareza_slots(Game.equip_rareza(slot))
	_mej_info.text = "  usadas %d / %d" % [Upgrades.total_mejoras(mj), maxm]
	if cats.is_empty():
		var l := Label.new()
		l.text = "(sin mejoras para este item)"
		_mej_rows.add_child(l)
		return
	for cat in cats:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_mej_rows.add_child(row)
		var name_l := Label.new()
		name_l.text = Upgrades.cat_nombre(cat)
		name_l.custom_minimum_size = Vector2(150, 0)
		row.add_child(name_l)
		var minus := Button.new()
		minus.text = "-"
		minus.pressed.connect(func(): Game.add_mejora(slot, cat, -1); _rebuild_mejoras())
		row.add_child(minus)
		var cnt := Label.new()
		cnt.text = str(int(mj.get(cat, 0)))
		cnt.custom_minimum_size = Vector2(24, 0)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(cnt)
		var plus := Button.new()
		plus.text = "+"
		plus.pressed.connect(func(): Game.add_mejora(slot, cat, 1); _rebuild_mejoras())
		row.add_child(plus)


# --- Acciones -------------------------------------------------

func _toggle() -> void:
	_open = not _open
	_panel.visible = _open
	Game.debug_panel_open = _open
	if _open:
		_sync_from_game()


func _apply_stats() -> void:
	Game.debug_set_abilities(
		_stat_edits["fuerza"].text.to_int(),
		_stat_edits["resistencia"].text.to_int(),
		_stat_edits["destreza"].text.to_int(),
		_stat_edits["agilidad"].text.to_int(),
		_stat_edits["magia"].text.to_int())
	_sync_stats()


func _set_enemy(valor: int) -> void:
	Game.debug_enemy_stat_override = valor
	_sync_enemy()


func _apply_floor() -> void:
	Game.current_floor = maxi(1, _floor_edit.text.to_int())
	_floor_edit.text = str(Game.current_floor)


func _set_armor(idx: int, slot: String) -> void:
	if idx <= 0:
		Game.set("equipped_" + slot, null)
	else:
		var path := "res://resources/armor/%s_%s.tres" % [ARMOR_PREFIX[idx], slot]
		Game.set("equipped_" + slot, load(path))
	_rebuild_mejoras()  # cambiar de pieza cambia las categorias validas


func _set_armor_tier(tier: int, slot: String) -> void:
	Game.set_equip_tier(slot, tier)


func _set_main(idx: int) -> void:
	Game.equipar_arma(load(Game._dev_weapons[idx]))
	_sync_weapons()
	_rebuild_mejoras()


func _set_off(idx: int) -> void:
	var path = Game._dev_offs[idx]
	var item: Resource = null if path == null else load(path)
	if not Game.equipar_secundaria(item):
		_sync_weapons()
	_rebuild_mejoras()


# --- Sincronizar con el estado real de Game ----

func _sync_from_game() -> void:
	_sync_stats()
	_sync_enemy()
	_sync_armor()
	_sync_weapons()
	_sync_spells()
	_floor_edit.text = str(Game.current_floor)
	_rebuild_mejoras()

func _sync_spells() -> void:
	for path in _spell_checks:
		var spell: SpellData = load(path)
		(_spell_checks[path] as CheckBox).set_pressed_no_signal(Game.equipped_spells.has(spell))

func _sync_stats() -> void:
	_stat_edits["fuerza"].text = str(Game.player_fuerza)
	_stat_edits["resistencia"].text = str(Game.player_resistencia)
	_stat_edits["destreza"].text = str(Game.player_destreza)
	_stat_edits["agilidad"].text = str(Game.player_agilidad)
	_stat_edits["magia"].text = str(Game.player_magia)

func _sync_enemy() -> void:
	for pair in _enemy_buttons:
		(pair[0] as Button).button_pressed = (pair[1] == Game.debug_enemy_stat_override)

func _sync_armor() -> void:
	for slot in ARMOR_SLOTS:
		var pieza = Game.get("equipped_" + slot)
		var idx := 0
		if pieza is ArmorData:
			idx = (pieza as ArmorData).tipo + 1
		(_armor_opts[slot] as OptionButton).select(idx)
		(_armor_tier_opts[slot] as OptionButton).select(clampi(Game.equip_tier(slot) - 1, 0, 2))
		(_armor_rareza_opts[slot] as OptionButton).select(Game.equip_rareza(slot))

func _sync_weapons() -> void:
	for i in Game._dev_weapons.size():
		if load(Game._dev_weapons[i]) == Game.equipped_main:
			_main_opt.select(i)
			break
	_main_tier_opt.select(clampi(Game.equip_tier("main") - 1, 0, 2))
	_off_tier_opt.select(clampi(Game.equip_tier("off") - 1, 0, 2))
	_main_rareza_opt.select(Game.equip_rareza("main"))
	_off_rareza_opt.select(Game.equip_rareza("off"))
	var off_idx := 0
	for i in Game._dev_offs.size():
		var p = Game._dev_offs[i]
		if p == null:
			if Game.equipped_off == null:
				off_idx = i
				break
		elif load(p) == Game.equipped_off:
			off_idx = i
			break
	_off_opt.select(off_idx)
