# ============================================================
#  debug_panel.gd  (CanvasLayer creada por codigo desde el jugador)
#  Panel de DEBUG clicable, disponible en CUALQUIER sala. Herramientas:
#   - STATS: escribir las 5 habilidades y aplicarlas.
#   - ENEMIGO: presets Base/200/500/Cheto + selector de PISO.
#   - FORJA: crear un objeto (que + cual + tier + rareza + mejoras) y meterlo
#     en el baul. Equipar se hace desde el menu de personaje [C].
#   - MEJORAS: mejorar el objeto YA EQUIPADO en un slot (segun su rareza).
#  Todo por codigo (UI placeholder). Mientras esta abierto congela al jugador.
# ============================================================

extends CanvasLayer

const ARMOR_PREFIX := ["cuero", "hierro", "hierro_completo", "placas"]  # idx -> material
const ARMOR_LABELS := ["Cuero", "Hierro", "Hierro compl.", "Placas"]
# FORJA: que se puede crear. [etiqueta, clave]. Las claves de armadura son el slot.
const FORJA_CATS := [["Arma", "arma"], ["Escudo", "escudo"], ["Varita", "varita"],
	["Casco", "casco"], ["Pecho", "pecho"], ["Manos", "manos"],
	["Pantalon", "pantalones"], ["Botas", "botas"]]
const FORJA_SHIELDS := ["res://resources/shields/escudo_pequeno.tres",
	"res://resources/shields/escudo_normal.tres",
	"res://resources/shields/escudo_grande.tres"]
const FORJA_WANDS := ["res://resources/wands/varita.tres"]
const ENEMY_PRESETS := [["Base", -1], ["200", 200], ["500", 500], ["Cheto", 999]]
# Slots para el selector de MEJORAS: [etiqueta, clave].
const MEJ_SLOTS := [["Principal", "main"], ["Secundaria", "off"], ["Casco", "casco"],
	["Pecho", "pecho"], ["Manos", "manos"], ["Pantalones", "pantalones"], ["Botas", "botas"]]

var _panel: PanelContainer = null
var _open: bool = false

var _stat_edits: Dictionary = {}
var _enemy_buttons: Array = []
var _dummy_buttons: Array = []   # [boton, modo] del modo prueba (Off/Saco/Pegador)
var _dummy_hp_edit: LineEdit = null
var _floor_edit: LineEdit = null
# FORJA
var _forja_cat_opt: OptionButton = null
var _forja_item_opt: OptionButton = null
var _forja_tier: int = 1
var _forja_rareza: int = Upgrades.Rareza.COMUN
var _forja_mejoras: Dictionary = {}      # categoria -> nº de mejoras
var _forja_rows: VBoxContainer = null
var _forja_nombre: Label = null
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

# OptionButton de rareza (0..6). El callback recibe la rareza (0..6).
func _make_rareza_opt(cb: Callable) -> OptionButton:
	var opt := OptionButton.new()
	for i in Upgrades.RAREZA_NOMBRE.size():
		opt.add_item(Upgrades.RAREZA_NOMBRE[i], i)
	opt.item_selected.connect(func(idx): cb.call(idx))
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
	_build_forja(vb)
	_sep(vb)
	_build_spells(vb)
	_sep(vb)
	_build_mejoras(vb)
	_sep(vb)
	_build_objetos(vb)


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

	# MODO PRUEBA: muñeco de DPS (Saco) / pegador de armadura, con HP configurable.
	_header(vb, "Prueba (muñeco)")
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 4)
	vb.add_child(drow)
	for dpreset in [["Off", 0], ["Saco DPS", 1], ["Pegador", 2]]:
		var db := Button.new()
		db.text = dpreset[0]
		db.toggle_mode = true
		db.pressed.connect(_set_dummy.bind(dpreset[1]))
		drow.add_child(db)
		_dummy_buttons.append([db, dpreset[1]])
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 4)
	vb.add_child(hrow)
	var hlbl := Label.new()
	hlbl.text = "HP"
	hrow.add_child(hlbl)
	_dummy_hp_edit = LineEdit.new()
	_dummy_hp_edit.custom_minimum_size = Vector2(60, 0)
	_dummy_hp_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dummy_hp_edit.text_submitted.connect(func(_t): _apply_dummy_hp())
	hrow.add_child(_dummy_hp_edit)
	var hap := Button.new()
	hap.text = "Aplicar"
	hap.pressed.connect(_apply_dummy_hp)
	hrow.add_child(hap)


# ============================================================
#  FORJA: crear un objeto y meterlo en el baul
# ============================================================
#  Eliges QUE (arma / escudo / varita / pieza de armadura), CUAL dentro de esa
#  categoria, su TIER, su RAREZA (que decide cuantas mejoras admite) y repartes
#  las MEJORAS. "Crear" duplica la plantilla .tres: cada copia es un objeto
#  propio con sus stats, asi que puedes forjar dos espadas cortas y llevar una
#  en cada mano. NO se equipa: se equipa desde el menu de personaje [C].

func _build_forja(vb: VBoxContainer) -> void:
	_header(vb, "FORJA (crear objeto -> baúl)")

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	vb.add_child(row1)
	_forja_cat_opt = OptionButton.new()
	for i in FORJA_CATS.size():
		_forja_cat_opt.add_item(FORJA_CATS[i][0], i)
	_forja_cat_opt.item_selected.connect(func(_i): _on_forja_cat())
	row1.add_child(_forja_cat_opt)
	_forja_item_opt = OptionButton.new()
	_forja_item_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_forja_item_opt.item_selected.connect(func(_i): _on_forja_item())
	row1.add_child(_forja_item_opt)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	vb.add_child(row2)
	row2.add_child(_make_tier_opt(_on_forja_tier))
	row2.add_child(_make_rareza_opt(_on_forja_rareza))
	_forja_nombre = Label.new()
	_forja_nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(_forja_nombre)

	_forja_rows = VBoxContainer.new()
	_forja_rows.add_theme_constant_override("separation", 3)
	vb.add_child(_forja_rows)

	var crear := Button.new()
	crear.text = "Crear"
	crear.pressed.connect(_on_crear)
	vb.add_child(crear)

	_on_forja_cat()


# Clave de la categoria elegida ("arma", "escudo", "varita", o un slot de armadura).
func _forja_cat() -> String:
	return FORJA_CATS[maxi(0, _forja_cat_opt.selected)][1]

# Plantillas .tres disponibles en la categoria elegida.
func _forja_paths() -> Array:
	var cat := _forja_cat()
	if cat == "arma":
		return Game._dev_weapons
	if cat == "escudo":
		return FORJA_SHIELDS
	if cat == "varita":
		return FORJA_WANDS
	var res: Array = []
	for pref in ARMOR_PREFIX:
		res.append("res://resources/armor/%s_%s.tres" % [pref, cat])
	return res

func _forja_base() -> Resource:
	var paths := _forja_paths()
	if paths.is_empty():
		return null
	return load(paths[clampi(_forja_item_opt.selected, 0, paths.size() - 1)])


# Cambiar de categoria: repuebla el desplegable de items y resetea las mejoras.
func _on_forja_cat() -> void:
	_forja_item_opt.clear()
	var cat := _forja_cat()
	var paths := _forja_paths()
	var es_armadura: bool = not (cat in ["arma", "escudo", "varita"])
	for i in paths.size():
		var etiqueta: String = ARMOR_LABELS[i] if es_armadura else str(load(paths[i]).get("nombre"))
		_forja_item_opt.add_item(etiqueta, i)
	_forja_item_opt.select(0)
	_on_forja_item()

func _on_forja_item() -> void:
	_forja_mejoras.clear()   # otro item = otras categorias de mejora
	_rebuild_forja()

func _on_forja_tier(t: int) -> void:
	_forja_tier = t
	_rebuild_forja()

func _on_forja_rareza(r: int) -> void:
	_forja_rareza = clampi(r, 0, Upgrades.RAREZA_SLOTS.size() - 1)
	# La nueva rareza puede admitir MENOS mejoras: recorta el sobrante.
	while Upgrades.total_mejoras(_forja_mejoras) > Upgrades.rareza_slots(_forja_rareza):
		var k: String = _forja_mejoras.keys().back()
		_forja_mejoras[k] = int(_forja_mejoras[k]) - 1
		if int(_forja_mejoras[k]) <= 0:
			_forja_mejoras.erase(k)
	_rebuild_forja()


# Categorias de mejora validas para la plantilla elegida (el escudo no admite).
func _forja_categorias(base: Resource) -> Array:
	if base is WeaponData:
		return Upgrades.weapon_categories(base as WeaponData)
	if base is WandData:
		return Upgrades.wand_categories()
	if base is ArmorData:
		return Upgrades.armor_categories(base as ArmorData)
	return []


func _add_forja_mejora(cat: String, delta: int) -> void:
	var actual: int = int(_forja_mejoras.get(cat, 0))
	if delta > 0 and Upgrades.total_mejoras(_forja_mejoras) >= Upgrades.rareza_slots(_forja_rareza):
		return  # sin slots libres para esta rareza
	var nuevo: int = maxi(0, actual + delta)
	if nuevo == 0:
		_forja_mejoras.erase(cat)
	else:
		_forja_mejoras[cat] = nuevo
	_rebuild_forja()


func _rebuild_forja() -> void:
	if _forja_rows == null:
		return
	for c in _forja_rows.get_children():
		c.queue_free()
	var base := _forja_base()
	var usadas: int = Upgrades.total_mejoras(_forja_mejoras)
	var maxm: int = Upgrades.rareza_slots(_forja_rareza)
	var nombre: String = "?" if base == null else str(base.get("nombre"))
	if usadas > 0:
		nombre += " +%d" % usadas
	_forja_nombre.text = "%s   (%d/%d mejoras)" % [nombre, usadas, maxm]

	var cats := _forja_categorias(base)
	if cats.is_empty():
		var l := Label.new()
		l.text = "(este objeto no admite mejoras)"
		_forja_rows.add_child(l)
		return
	for cat in cats:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_forja_rows.add_child(row)
		var name_l := Label.new()
		name_l.text = Upgrades.cat_nombre(cat)
		name_l.custom_minimum_size = Vector2(150, 0)
		row.add_child(name_l)
		var minus := Button.new()
		minus.text = "-"
		minus.pressed.connect(_add_forja_mejora.bind(cat, -1))
		row.add_child(minus)
		var cnt := Label.new()
		cnt.text = str(int(_forja_mejoras.get(cat, 0)))
		cnt.custom_minimum_size = Vector2(24, 0)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(cnt)
		var plus := Button.new()
		plus.text = "+"
		plus.pressed.connect(_add_forja_mejora.bind(cat, 1))
		row.add_child(plus)


func _on_crear() -> void:
	var base := _forja_base()
	if base == null:
		return
	var item: Resource = Game.crear_item(base, _forja_tier, _forja_rareza, _forja_mejoras)
	print("[dev] Forjado y añadido al baúl: ", Game.item_display_name(item))


# OBJETOS (KAN-57): botones para AÑADIR pociones al inventario (Game.consumables).
# El jugador las usa con "Objeto" en combate o con [Q] fuera de combate.
func _build_objetos(vb: VBoxContainer) -> void:
	_header(vb, "OBJETOS (añadir pociones)")
	for path in Game._dev_consumables:
		var cons: ConsumableData = load(path)
		var b := Button.new()
		b.text = "+1 %s  (%s)" % [cons.nombre, cons.resumen(Game.player_max_hp(), Game.player_max_mp())]
		b.pressed.connect(func(): Game.add_consumable(cons, 1))
		vb.add_child(b)


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


func _set_dummy(modo: int) -> void:
	Game.debug_dummy_mode = modo
	_sync_dummy()


func _apply_dummy_hp() -> void:
	var v: float = maxf(1.0, float(_dummy_hp_edit.text.to_float()))
	Game.debug_dummy_hp = v
	_dummy_hp_edit.text = str(int(v))


func _apply_floor() -> void:
	Game.current_floor = maxi(1, _floor_edit.text.to_int())
	_floor_edit.text = str(Game.current_floor)


# NOTA: la FORJA no equipa: mete el objeto en tu baul (Game.owned_*). Equipar se
# hace desde el menu de personaje [C] (en el pueblo). Las teclas dev K/L/J siguen
# equipando en caliente para probar rapido.


# --- Sincronizar con el estado real de Game ----

func _sync_from_game() -> void:
	_sync_stats()
	_sync_enemy()
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
	_sync_dummy()

func _sync_dummy() -> void:
	for pair in _dummy_buttons:
		(pair[0] as Button).button_pressed = (pair[1] == Game.debug_dummy_mode)
	if _dummy_hp_edit != null:
		_dummy_hp_edit.text = str(int(Game.debug_dummy_hp))
