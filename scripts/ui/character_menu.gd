# ============================================================
#  character_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  Menu de PERSONAJE estilo gacha (Genshin/Honkai), se abre/cierra con C.
#  Tres pestañas:
#    1) PERSONAJE  - stats de combate calculadas (Ataque/Velocidad/Critico/...);
#                    con flechas ◀ ▶ alterna con las 5 habilidades DanMachi.
#    2) ARMAS      - arma principal + secundaria equipadas y sus stats. En el
#                    PUEBLO se puede cambiar entre el catalogo de armas.
#    3) ARMADURA   - las 5 piezas; entrar en cada slot para ver stats/mejoras y
#                    (en el pueblo) cambiar la pieza.
#  Solo consulta fuera del pueblo (Game.en_pueblo()). Pausa el juego mientras
#  esta abierto (como la ayuda F1). UI por codigo (placeholder).
# ============================================================

extends CanvasLayer

# Catalogo de armaduras por material (mismo patron que debug_panel.gd).
const ARMOR_MATERIALS := ["", "cuero", "hierro", "hierro_completo", "placas"]
const ARMOR_MAT_LABELS := ["(sin pieza)", "Cuero", "Hierro", "Hierro compl.", "Placas"]
const ARMOR_SLOTS := ["casco", "pecho", "manos", "pantalones", "botas"]
const ARMOR_SLOT_LABELS := {
	"casco": "Casco", "pecho": "Pecho", "manos": "Manos",
	"pantalones": "Pantalones", "botas": "Botas"}
const WEAPON_TIPO_LABELS := ["Puños", "Daga", "Espada corta", "Espada larga", "Mandoble",
	"Estoque", "Hacha grande", "Maza pequeña", "Martillo grande", "Bastón"]

var _root: Control = null
var _panel: PanelContainer = null
var _content: VBoxContainer = null       # cuerpo que se reconstruye por pestaña
var _tab_buttons: Array = []             # [Button, idx]

var _tab: int = 0                        # 0 personaje, 1 armas, 2 armadura
var _char_page: int = 0                  # 0 stats, 1 habilidades
var _armor_slot_sel: String = ""         # slot abierto en detalle; "" = lista


func _ready() -> void:
	layer = 92   # por encima del HUD, por debajo del combate (100)
	process_mode = Node.PROCESS_MODE_ALWAYS  # sigue vivo con el arbol en pausa

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.6)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.97)
	sb.border_color = Color(0.87, 0.57, 0.26, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	outer.custom_minimum_size = Vector2(460, 0)
	_panel.add_child(outer)

	# Barra de pestañas + boton de cerrar.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	outer.add_child(tabs)
	var nombres := ["Personaje", "Armas", "Armadura"]
	for i in nombres.size():
		var b := Button.new()
		b.text = nombres[i]
		b.toggle_mode = true
		b.pressed.connect(_on_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	var cerrar := Button.new()
	cerrar.text = "✕ Cerrar"
	cerrar.pressed.connect(_cerrar)
	tabs.add_child(cerrar)

	outer.add_child(HSeparator.new())

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 4)
	_content.custom_minimum_size = Vector2(0, 300)
	outer.add_child(_content)

	var hint := Label.new()
	hint.text = "C / ✕ Cerrar — cerrar"
	hint.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
	hint.add_theme_font_size_override("font_size", 11)
	outer.add_child(hint)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var code: int = (event as InputEventKey).keycode
	if code == KEY_C:
		_toggle()
	elif code == KEY_ESCAPE and _root.visible:
		_cerrar()


func _toggle() -> void:
	if not _root.visible:
		# No abrir sobre un combate/extraccion o con otro modal abierto.
		if Game._active_layer != null or Game.inventory_open or Game.debug_panel_open:
			return
		_set_open(true)
	else:
		_set_open(false)


func _cerrar() -> void:
	_set_open(false)


func _set_open(open: bool) -> void:
	_root.visible = open
	get_tree().paused = open
	if open:
		_tab = 0
		_char_page = 0
		_armor_slot_sel = ""
		_rebuild()


func _on_tab(i: int) -> void:
	_tab = i
	_armor_slot_sel = ""
	_rebuild()


func _rebuild() -> void:
	for c in _content.get_children():
		c.queue_free()
	for i in _tab_buttons.size():
		(_tab_buttons[i] as Button).button_pressed = (i == _tab)
	match _tab:
		0: _build_personaje()
		1: _build_armas()
		2: _build_armadura()


# ============================================================
#  Helpers de UI
# ============================================================

func _title(vb: VBoxContainer, txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36))
	l.add_theme_font_size_override("font_size", 15)
	vb.add_child(l)

func _row(vb: VBoxContainer, etiqueta: String, valor: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = etiqueta
	k.custom_minimum_size = Vector2(170, 0)
	k.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	row.add_child(k)
	var v := Label.new()
	v.text = valor
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	vb.add_child(row)

func _note(vb: VBoxContainer, txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
	l.add_theme_font_size_override("font_size", 11)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(420, 0)
	vb.add_child(l)

func _fmt_pct(x: float) -> String:
	return "%.0f%%" % (x * 100.0)


# ============================================================
#  Pestaña PERSONAJE
# ============================================================

func _build_personaje() -> void:
	_title(_content, "PERSONAJE  (Nv. %d)" % Game.player_level)

	# Fila de flechas para alternar pagina (stats <-> habilidades).
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	var izq := Button.new()
	izq.text = "◀"
	izq.pressed.connect(_flip_char_page)
	nav.add_child(izq)
	var pg := Label.new()
	pg.text = "Estadísticas" if _char_page == 0 else "Habilidades"
	pg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pg.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	nav.add_child(pg)
	var der := Button.new()
	der.text = "▶"
	der.pressed.connect(_flip_char_page)
	nav.add_child(der)
	_content.add_child(nav)
	_content.add_child(HSeparator.new())

	if _char_page == 0:
		_build_stats_page()
	else:
		_build_habilidades_page()


func _flip_char_page() -> void:
	_char_page = 1 - _char_page
	_rebuild()


func _build_stats_page() -> void:
	# crear_player_combatant() concreta el -1 (= "lleno") de vida/maná. Como aquí solo
	# LEEMOS stats, guardamos y restauramos el sentinel para no mutar el estado persistente.
	var hp_was: float = Game.player_current_hp
	var mp_was: float = Game.player_current_mp
	var c: Combatant = Game.crear_player_combatant()
	Game.player_current_hp = hp_was
	Game.player_current_mp = mp_was
	_row(_content, "Ataque (medio)", "%.1f" % _ataque_promedio(c))
	_row(_content, "Velocidad", "%.1f" % c.spd())
	var crit_p: float = clampf(StatsMath.crit_chance(float(c.abilities.destreza),
		float(c.abilities.destreza)) + _crit_bonus_promedio(c), 0.0, 1.0)
	_row(_content, "Prob. crítico", _fmt_pct(crit_p))
	_row(_content, "Daño crítico", "×%.2f (+%d%%)" % [
		StatsMath.CRIT_MULT, roundi((StatsMath.CRIT_MULT - 1.0) * 100.0)])
	_content.add_child(HSeparator.new())
	_row(_content, "Vida máx.", "%.1f" % c.max_hp)
	_row(_content, "Defensa", "%.1f" % c.def_value())
	if c.max_mp > 0.0:
		_row(_content, "Maná máx.", "%.2f" % c.max_mp)
	_note(_content, "Valores en promedio contra un enemigo equiparado; varían según las stats del rival.")


func _build_habilidades_page() -> void:
	_row(_content, "Fuerza", str(Game.player_fuerza))
	_row(_content, "Resistencia", str(Game.player_resistencia))
	_row(_content, "Destreza", str(Game.player_destreza))
	_row(_content, "Agilidad", str(Game.player_agilidad))
	_row(_content, "Magia", str(Game.player_magia))
	_note(_content, "Las 5 habilidades DanMachi (0–999). Suben con el uso y se aplican en el hogar.")


# Media del ataque por golpe sobre las manos del loadout (dual = media de ambas).
func _ataque_promedio(c: Combatant) -> float:
	if c.hands.is_empty():
		return c.atk()
	var total: float = 0.0
	for i in c.hands.size():
		c.set_active_hand(i)
		total += c.atk()
	c.set_active_hand(0)
	return total / float(c.hands.size())

# Media del crit_bonus del arma sobre las manos (afinidad).
func _crit_bonus_promedio(c: Combatant) -> float:
	if c.hands.is_empty():
		return c.crit_bonus
	var total: float = 0.0
	for h in c.hands:
		total += float(h.get("crit_bonus", 0.0))
	return total / float(c.hands.size())


# ============================================================
#  Pestaña ARMAS
# ============================================================

func _build_armas() -> void:
	_title(_content, "ARMAS")
	var pueblo: bool = Game.en_pueblo()
	if not pueblo:
		_note(_content, "Cambios de equipo solo en el pueblo. Aquí es solo consulta.")

	# --- Principal ---
	_content.add_child(HSeparator.new())
	var head1 := HBoxContainer.new()
	head1.add_theme_constant_override("separation", 8)
	var t1 := Label.new()
	t1.text = "Principal:  %s" % Game.equipped_main.nombre
	t1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t1.add_theme_color_override("font_color", Color(0.9, 0.95, 0.8))
	head1.add_child(t1)
	if pueblo:
		var mi := Button.new(); mi.text = "◀"; mi.pressed.connect(_cycle_main.bind(-1)); head1.add_child(mi)
		var md := Button.new(); md.text = "▶"; md.pressed.connect(_cycle_main.bind(1)); head1.add_child(md)
	_content.add_child(head1)
	_weapon_stats(_content, Game.equipped_main, "main")

	# --- Secundaria ---
	_content.add_child(HSeparator.new())
	var head2 := HBoxContainer.new()
	head2.add_theme_constant_override("separation", 8)
	var t2 := Label.new()
	t2.text = "Secundaria:  %s" % _off_nombre(Game.equipped_off)
	t2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t2.add_theme_color_override("font_color", Color(0.9, 0.95, 0.8))
	head2.add_child(t2)
	if pueblo:
		var oi := Button.new(); oi.text = "◀"; oi.pressed.connect(_cycle_off.bind(-1)); head2.add_child(oi)
		var od := Button.new(); od.text = "▶"; od.pressed.connect(_cycle_off.bind(1)); head2.add_child(od)
	_content.add_child(head2)
	if Game.equipped_main.dos_manos:
		_note(_content, "El arma principal es a dos manos: no admite secundaria.")
	else:
		_off_stats(_content, Game.equipped_off)


func _weapon_stats(vb: VBoxContainer, w: WeaponData, slot: String) -> void:
	if w == null:
		return
	var tipo: String = WEAPON_TIPO_LABELS[clampi(int(w.tipo), 0, WEAPON_TIPO_LABELS.size() - 1)]
	_row(vb, "  Tipo", tipo + ("  (magia)" if w.es_magica else ""))
	_row(vb, "  Ataque base", "%.1f" % w.ataque_base)
	_row(vb, "  Motion value", "×%.2f" % w.motion_value)
	_row(vb, "  Velocidad", "×%.2f" % w.velocidad_mult)
	if w.crit_bonus != 0.0:
		_row(vb, "  Crítico", "+%s" % _fmt_pct(w.crit_bonus))
	if w.es_magica:
		_row(vb, "  Amplif. magia", "×%.2f" % w.magic_amp)
	_row(vb, "  Tier / rareza", "T%d · %s" % [Game.equip_tier(slot), Upgrades.rareza_nombre(Game.equip_rareza(slot))])
	_row(vb, "  Mejoras", "%d / %d" % [Upgrades.total_mejoras(Game.equip_mejoras(slot)),
		Upgrades.rareza_slots(Game.equip_rareza(slot))])


func _off_stats(vb: VBoxContainer, item: Resource) -> void:
	if item == null:
		_note(vb, "  (sin mano secundaria)")
		return
	if item is WeaponData:
		_weapon_stats(vb, item as WeaponData, "off")
	elif item is ShieldData:
		var s := item as ShieldData
		_row(vb, "  Bloqueo", "+%s" % _fmt_pct(s.bloqueo))
		_row(vb, "  Velocidad", "×%.2f" % s.velocidad_mult)
		_row(vb, "  Penal. esquiva", "-%s" % _fmt_pct(s.evasion_penal))
	elif item is WandData:
		var wd := item as WandData
		_row(vb, "  Amplif. magia", "×%.2f" % wd.magic_amp)
		_row(vb, "  Regen maná", "+%.2f/turno" % wd.mp_regen_bonus)
		_row(vb, "  Vel. casteo", "×%.2f" % wd.velocidad_mult)


func _off_nombre(item: Resource) -> String:
	if item == null:
		return "—"
	if item is WeaponData:
		return (item as WeaponData).nombre + " (dual)"
	if item is WandData:
		return (item as WandData).nombre + " (varita)"
	if item is ShieldData:
		return (item as ShieldData).nombre
	return "?"


func _cycle_main(delta: int) -> void:
	var list: Array = Game._dev_weapons
	var idx: int = 0
	for i in list.size():
		if load(list[i]) == Game.equipped_main:
			idx = i
			break
	idx = wrapi(idx + delta, 0, list.size())
	Game.equipar_arma(load(list[idx]))
	_rebuild()


func _cycle_off(delta: int) -> void:
	if Game.equipped_main.dos_manos:
		return
	var list: Array = Game._dev_offs
	var idx: int = _off_current_index(list)
	# Busca la SIGUIENTE secundaria valida en esa direccion (salta las incompatibles).
	for _n in range(list.size()):
		idx = wrapi(idx + delta, 0, list.size())
		var p = list[idx]
		var item: Resource = null if p == null else load(p)
		if Game.equipar_secundaria(item):
			break
	_rebuild()


func _off_current_index(list: Array) -> int:
	for i in list.size():
		var p = list[i]
		if p == null:
			if Game.equipped_off == null:
				return i
		elif load(p) == Game.equipped_off:
			return i
	return 0


# ============================================================
#  Pestaña ARMADURA
# ============================================================

func _build_armadura() -> void:
	if _armor_slot_sel == "":
		_build_armadura_lista()
	else:
		_build_armadura_detalle(_armor_slot_sel)


func _build_armadura_lista() -> void:
	_title(_content, "ARMADURA")
	if not Game.en_pueblo():
		_note(_content, "Cambios de equipo solo en el pueblo. Aquí es solo consulta.")
	_content.add_child(HSeparator.new())
	for slot in ARMOR_SLOTS:
		var pieza = Game.get("equipped_" + slot)
		var nombre: String = pieza.nombre if pieza is ArmorData else "(sin pieza)"
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var l := Label.new()
		l.text = "%s:  %s" % [ARMOR_SLOT_LABELS[slot], nombre]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var ver := Button.new()
		ver.text = "Ver ▶"
		ver.pressed.connect(_abrir_slot.bind(slot))
		row.add_child(ver)
		_content.add_child(row)


func _abrir_slot(slot: String) -> void:
	_armor_slot_sel = slot
	_rebuild()


func _build_armadura_detalle(slot: String) -> void:
	var volver := Button.new()
	volver.text = "◀ Volver"
	volver.pressed.connect(_cerrar_slot)
	_content.add_child(volver)

	var pieza = Game.get("equipped_" + slot)
	var pueblo: bool = Game.en_pueblo()

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var t := Label.new()
	t.text = "%s:  %s" % [ARMOR_SLOT_LABELS[slot], (pieza.nombre if pieza is ArmorData else "(sin pieza)")]
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_color_override("font_color", Color(0.9, 0.95, 0.8))
	head.add_child(t)
	if pueblo:
		var mi := Button.new(); mi.text = "◀"; mi.pressed.connect(_cycle_armor.bind(slot, -1)); head.add_child(mi)
		var md := Button.new(); md.text = "▶"; md.pressed.connect(_cycle_armor.bind(slot, 1)); head.add_child(md)
	_content.add_child(head)
	_content.add_child(HSeparator.new())

	if not (pieza is ArmorData):
		_note(_content, "Sin pieza en este slot.")
		return

	var a := pieza as ArmorData
	var mods: Dictionary = Upgrades.armor_piece_mods(a, Game.tier_mult(Game.equip_tier(slot)),
		Game.equip_rareza(slot), Game.equip_mejoras(slot))
	_row(_content, "  Defensa", "%.1f" % float(mods["def"]))
	_row(_content, "  Reducción", _fmt_pct(float(mods["reduccion"])))
	_row(_content, "  Velocidad", "×%.2f" % float(mods["vel_mult"]))
	if float(mods["evasion"]) > 0.0:
		_row(_content, "  Evasión", "+%s" % _fmt_pct(float(mods["evasion"])))
	if float(mods["crit_resist"]) > 0.0:
		_row(_content, "  Resist. crítico", "+%s" % _fmt_pct(float(mods["crit_resist"])))
	if float(mods["resist_estados"]) > 0.0:
		_row(_content, "  Resist. estados", "+%s" % _fmt_pct(float(mods["resist_estados"])))
	_row(_content, "  Tier / rareza", "T%d · %s" % [Game.equip_tier(slot), Upgrades.rareza_nombre(Game.equip_rareza(slot))])

	# Mejoras de la pieza (solo consulta; se editan en el panel DEBUG).
	_content.add_child(HSeparator.new())
	var mj: Dictionary = Game.equip_mejoras(slot)
	_row(_content, "  Mejoras", "%d / %d" % [Upgrades.total_mejoras(mj), Upgrades.rareza_slots(Game.equip_rareza(slot))])
	if mj.is_empty():
		_note(_content, "  (sin mejoras)")
	else:
		for cat in mj:
			_row(_content, "    · " + Upgrades.cat_nombre(cat), "x%d" % int(mj[cat]))


func _cerrar_slot() -> void:
	_armor_slot_sel = ""
	_rebuild()


# Cambia el material de la pieza de un slot recorriendo el catalogo (en el pueblo).
func _cycle_armor(slot: String, delta: int) -> void:
	var pieza = Game.get("equipped_" + slot)
	var idx: int = 0
	if pieza is ArmorData:
		# tipo 0..3 (cuero..placas) -> indice 1..4 en ARMOR_MATERIALS.
		idx = int((pieza as ArmorData).tipo) + 1
	idx = wrapi(idx + delta, 0, ARMOR_MATERIALS.size())
	if idx == 0:
		Game.set("equipped_" + slot, null)
	else:
		var path := "res://resources/armor/%s_%s.tres" % [ARMOR_MATERIALS[idx], slot]
		Game.set("equipped_" + slot, load(path))
	_rebuild()
