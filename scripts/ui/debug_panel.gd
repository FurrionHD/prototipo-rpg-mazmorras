# ============================================================
#  debug_panel.gd  (CanvasLayer creada por codigo desde el jugador)
#  Panel de DEBUG clicable con el raton, disponible en CUALQUIER sala (el
#  jugador lo crea igual que el HUD, en pueblo y mazmorra). Herramientas:
#   - Editor de STATS: escribir las 5 habilidades y aplicarlas.
#   - Fuerza del ENEMIGO: presets Base / 200 / 500 / Cheto (999).
#   - ARMADURA por pieza: dropdown Nada/Ligera/Media/Pesada por slot.
#   - ARMAS: dropdown de principal y secundaria.
#  Todo por codigo (UI placeholder, como el resto del proyecto). Se apoya en
#  Game (loadout, stats, override de enemigo). Mientras esta abierto congela al
#  jugador (Game.debug_panel_open) para poder teclear sin moverse.
# ============================================================

extends CanvasLayer

const ARMOR_PREFIX := ["", "cuero", "hierro", "hierro_completo", "placas"]  # idx dropdown -> material
const ARMOR_LABELS := ["Nada", "Cuero", "Hierro", "Hierro compl.", "Placas"]
const ARMOR_SLOTS := ["casco", "pecho", "manos", "pantalones", "botas"]
const ENEMY_PRESETS := [["Base", -1], ["200", 200], ["500", 500], ["Cheto", 999]]

var _panel: PanelContainer = null
var _open: bool = false

var _stat_edits: Dictionary = {}     # "fuerza"/... -> LineEdit
var _enemy_buttons: Array = []       # [ [Button, valor], ... ]
var _floor_edit: LineEdit = null     # selector de piso (profundidad)
var _armor_opts: Dictionary = {}     # slot -> OptionButton (tipo)
var _armor_tier_opts: Dictionary = {}  # slot -> OptionButton (tier)
var _main_opt: OptionButton = null
var _main_tier_opt: OptionButton = null
var _off_opt: OptionButton = null
var _off_tier_opt: OptionButton = null


# Crea un OptionButton de tier (T1..T3). El callback recibe el TIER (1..3).
func _make_tier_opt(cb: Callable) -> OptionButton:
	var opt := OptionButton.new()
	for t in [1, 2, 3]:
		opt.add_item("T%d" % t, t)
	opt.item_selected.connect(func(idx): cb.call(idx + 1))  # idx 0->tier 1
	return opt


func _ready() -> void:
	layer = 6  # sobre el HUD (5), bajo el combate (100)

	# --- Boton flotante para abrir/cerrar (siempre visible, abajo-izquierda) ---
	var toggle := Button.new()
	toggle.text = "DEBUG"
	toggle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	toggle.offset_left = 8
	toggle.offset_top = -34
	toggle.offset_bottom = -8
	toggle.pressed.connect(_toggle)
	add_child(toggle)

	# --- Panel con todas las secciones (oculto por defecto) ---
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_panel.offset_left = 8
	_panel.offset_bottom = -40    # justo encima del boton
	# Crece hacia ARRIBA y a la DERECHA desde la esquina inferior-izquierda.
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

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	margin.add_child(vb)

	_build_stats(vb)
	_sep(vb)
	_build_enemy(vb)
	_sep(vb)
	_build_armor(vb)
	_sep(vb)
	_build_weapons(vb)


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
	# Selector de PISO (profundidad): escala vida/ataque base y habilidades del enemigo.
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
	_header(vb, "ARMADURA por pieza")
	var nombres := {"casco": "Casco", "pecho": "Pecho", "manos": "Manos",
		"pantalones": "Pantalon", "botas": "Botas"}
	for slot in ARMOR_SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		vb.add_child(row)
		var lbl := Label.new()
		lbl.text = nombres[slot]
		lbl.custom_minimum_size = Vector2(80, 0)
		row.add_child(lbl)
		var opt := OptionButton.new()
		for i in ARMOR_LABELS.size():
			opt.add_item(ARMOR_LABELS[i], i)
		opt.item_selected.connect(_set_armor.bind(slot))
		row.add_child(opt)
		_armor_opts[slot] = opt
		# Tier al lado (T1..T3): multiplica la DEF de esta pieza.
		var topt := _make_tier_opt(_set_armor_tier.bind(slot))
		row.add_child(topt)
		_armor_tier_opts[slot] = topt


func _build_weapons(vb: VBoxContainer) -> void:
	_header(vb, "ARMAS")
	# Principal
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	vb.add_child(row1)
	var l1 := Label.new()
	l1.text = "Principal"
	l1.custom_minimum_size = Vector2(80, 0)
	row1.add_child(l1)
	_main_opt = OptionButton.new()
	for i in Game._dev_weapons.size():
		var w: WeaponData = load(Game._dev_weapons[i])
		_main_opt.add_item(w.nombre, i)
	_main_opt.item_selected.connect(_set_main)
	row1.add_child(_main_opt)
	_main_tier_opt = _make_tier_opt(func(t): Game.equipped_main_tier = t)
	row1.add_child(_main_tier_opt)
	# Secundaria
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	vb.add_child(row2)
	var l2 := Label.new()
	l2.text = "Secundaria"
	l2.custom_minimum_size = Vector2(80, 0)
	row2.add_child(l2)
	_off_opt = OptionButton.new()
	for i in Game._dev_offs.size():
		_off_opt.add_item(_off_label(Game._dev_offs[i]), i)
	_off_opt.item_selected.connect(_set_off)
	row2.add_child(_off_opt)
	# Tier de la secundaria (solo aplica si es ARMA dual; con escudo se ignora).
	_off_tier_opt = _make_tier_opt(func(t): Game.equipped_off_tier = t)
	row2.add_child(_off_tier_opt)


func _off_label(path) -> String:
	if path == null:
		return "Nada"
	var res: Resource = load(path)
	if res is WeaponData:
		return (res as WeaponData).nombre + " (dual)"
	if res is ShieldData:
		return (res as ShieldData).nombre
	return "?"


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
	_sync_stats()  # reflejar los valores ya clampeados/sincronizados


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


func _set_armor_tier(tier: int, slot: String) -> void:
	Game.set("equipped_" + slot + "_tier", tier)


func _set_main(idx: int) -> void:
	Game.equipar_arma(load(Game._dev_weapons[idx]))
	# La nueva principal pudo invalidar la secundaria (2 manos / solo-escudo).
	_sync_weapons()


func _set_off(idx: int) -> void:
	var path = Game._dev_offs[idx]
	var item: Resource = null if path == null else load(path)
	if not Game.equipar_secundaria(item):
		# Combinacion invalida: revertir a lo que quedo equipado.
		_sync_weapons()


# --- Sincronizar los controles con el estado real de Game ----

func _sync_from_game() -> void:
	_sync_stats()
	_sync_enemy()
	_sync_armor()
	_sync_weapons()
	_floor_edit.text = str(Game.current_floor)

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
			idx = (pieza as ArmorData).tipo + 1  # Tipo LIGERA/MEDIA/PESADA -> 1/2/3
		(_armor_opts[slot] as OptionButton).select(idx)
		var tier: int = int(Game.get("equipped_" + slot + "_tier"))
		(_armor_tier_opts[slot] as OptionButton).select(clampi(tier - 1, 0, 2))

func _sync_weapons() -> void:
	# Principal: buscar el path equipado en la lista dev.
	for i in Game._dev_weapons.size():
		if load(Game._dev_weapons[i]) == Game.equipped_main:
			_main_opt.select(i)
			break
	_main_tier_opt.select(clampi(Game.equipped_main_tier - 1, 0, 2))
	_off_tier_opt.select(clampi(Game.equipped_off_tier - 1, 0, 2))
	# Secundaria: casar por recurso (null / arma / escudo).
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
