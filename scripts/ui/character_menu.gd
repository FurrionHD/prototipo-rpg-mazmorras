# ============================================================
#  character_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  Menu de PERSONAJE a PANTALLA COMPLETA (estilo Genshin/Honkai), tecla C.
#  Barra de pestañas VERTICAL a la izquierda + contenido a la derecha:
#    1) PERSONAJE - stats de combate calculadas; el boton ⇄ alterna con las 5
#                   habilidades DanMachi.
#    2) ARMAS     - arma principal/secundaria equipadas y sus stats. Boton
#                   "Cambiar" -> CUADRICULA de armas + panel de stats a la derecha
#                   + "Equipar". Solo en el pueblo.
#    3) ARMADURA  - 5 slots; entras en uno, ves stats/mejoras y "Cambiar" abre la
#                   misma cuadricula con los materiales. Solo en el pueblo.
#  Al entrar en "Cambiar", viene preseleccionado lo equipado (siempre hay stats).
#  Pausa el juego mientras esta abierto. UI por codigo (placeholder).
# ============================================================

extends CanvasLayer

const ARMOR_SLOTS := ["casco", "pecho", "manos", "pantalones", "botas"]
const ARMOR_SLOT_LABELS := {
	"casco": "Casco", "pecho": "Pecho", "manos": "Manos",
	"pantalones": "Pantalones", "botas": "Botas"}
const WEAPON_TIPO_LABELS := ["Puños", "Daga", "Espada corta", "Espada larga", "Mandoble",
	"Estoque", "Hacha grande", "Maza pequeña", "Martillo grande", "Bastón"]

var _root: Control = null
var _content: VBoxContainer = null        # cuerpo (derecha) que se reconstruye
var _tab_buttons: Array = []              # botones de pestaña (izquierda)

var _tab: int = 0                         # 0 personaje, 1 armas, 2 armadura
var _char_page: int = 0                   # 0 stats, 1 habilidades
var _arma_change: String = ""             # "" | "main" | "off"
var _arma_cand: int = 0                   # indice del candidato en el catalogo
var _armor_slot_sel: String = ""          # "" lista | slot en detalle
var _armor_change: bool = false           # true = eligiendo material del slot
var _armor_cand: int = 0                  # indice de material candidato


func _ready() -> void:
	layer = 92
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

	# Fondo opaco a pantalla completa.
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.06, 0.08, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(bg)

	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 16
	hb.offset_top = 16
	hb.offset_right = -16
	hb.offset_bottom = -16
	hb.add_theme_constant_override("separation", 18)
	_root.add_child(hb)

	# --- Barra de pestañas VERTICAL a la izquierda ---
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(190, 0)
	side.add_theme_constant_override("separation", 6)
	hb.add_child(side)

	var titulo := Label.new()
	titulo.text = "PERSONAJE"
	titulo.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36))
	titulo.add_theme_font_size_override("font_size", 18)
	side.add_child(titulo)
	side.add_child(HSeparator.new())

	var nombres := ["Personaje", "Armas", "Armadura"]
	for i in nombres.size():
		var b := Button.new()
		b.text = nombres[i]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 34)
		b.pressed.connect(_on_tab.bind(i))
		side.add_child(b)
		_tab_buttons.append(b)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)
	var cerrar := Button.new()
	cerrar.text = "✕ Cerrar  (C)"
	cerrar.custom_minimum_size = Vector2(0, 34)
	cerrar.pressed.connect(_cerrar)
	side.add_child(cerrar)

	# --- Contenido (derecha) ---
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 8)
	hb.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 4)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)


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
		_arma_change = ""
		_armor_slot_sel = ""
		_armor_change = false
		_rebuild()


func _on_tab(i: int) -> void:
	_tab = i
	_arma_change = ""
	_armor_slot_sel = ""
	_armor_change = false
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
	l.add_theme_font_size_override("font_size", 16)
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
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var t := Label.new()
	t.text = "PERSONAJE  (Nv. %d)   —   %s" % [
		Game.player_level, "Estadísticas" if _char_page == 0 else "Habilidades"]
	t.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36))
	t.add_theme_font_size_override("font_size", 16)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	# Icono de intercambio ⇄: alterna stats <-> habilidades.
	var swap := Button.new()
	swap.text = "⇄"
	swap.tooltip_text = "Cambiar vista (estadísticas / habilidades)"
	swap.custom_minimum_size = Vector2(44, 34)
	swap.pressed.connect(_flip_char_page)
	head.add_child(swap)
	_content.add_child(head)
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
	_row(_content, "Ataque total", "%.1f" % _ataque_total(c))
	_row(_content, "Velocidad", "%.1f" % c.spd())
	# Critico contra un enemigo ESPEJO (tus mismas stats): tu Destreza vs tu Agilidad.
	var crit_p: float = clampf(StatsMath.crit_chance(float(c.abilities.destreza),
		float(c.abilities.agilidad)) + _crit_bonus_promedio(c), 0.0, 1.0)
	_row(_content, "Prob. crítico", _fmt_pct(crit_p))
	_row(_content, "Daño crítico", "×%.2f (+%d%%)" % [
		StatsMath.CRIT_MULT, roundi((StatsMath.CRIT_MULT - 1.0) * 100.0)])
	_content.add_child(HSeparator.new())
	_row(_content, "Vida máx.", "%.1f" % c.max_hp)
	_row(_content, "Defensa", "%.1f" % c.def_value())
	if c.max_mp > 0.0:
		_row(_content, "Maná máx.", "%.2f" % c.max_mp)
	_note(_content, "Ataque total = raw (base + arma) × Fuerza, ANTES del motion value (cada golpe aplica su %). Prob. crítico calculada contra un enemigo con TUS mismas stats: sube con Destreza y baja con Agilidad.")


func _build_habilidades_page() -> void:
	_row(_content, "Fuerza", str(Game.player_fuerza))
	_row(_content, "Resistencia", str(Game.player_resistencia))
	_row(_content, "Destreza", str(Game.player_destreza))
	_row(_content, "Agilidad", str(Game.player_agilidad))
	_row(_content, "Magia", str(Game.player_magia))
	_note(_content, "Las 5 habilidades (0–999). Suben con el uso y se aplican en el hogar.")


# Ataque TOTAL (raw): (base + arma) × factor_fuerza × estados, SIN el motion_value
# (ese se aplica por golpe). c ya tiene activa la mano principal (0) tras crearlo.
func _ataque_total(c: Combatant) -> float:
	return (c.base_attack + c.ataque_arma) * StatsMath.fuerza_factor(float(c.abilities.fuerza)) * c.status_atk_mult()

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
	if _arma_change != "":
		_build_armas_cambiar()
		return

	_title(_content, "ARMAS")
	var pueblo: bool = Game.en_pueblo()
	if not pueblo:
		_note(_content, "Cambios de equipo solo en el pueblo. Aquí es solo consulta.")

	# --- Principal ---
	_content.add_child(HSeparator.new())
	_bloque_arma("Principal", Game.item_display_name(Game.equipped_main), pueblo, _abrir_cambio.bind("main"))
	_weapon_stats(_content, Game.equipped_main)

	# --- Secundaria ---
	_content.add_child(HSeparator.new())
	var dos_manos: bool = Game.equipped_main.dos_manos
	_bloque_arma("Secundaria", _off_nombre(Game.equipped_off), pueblo and not dos_manos,
		_abrir_cambio.bind("off"))
	if dos_manos:
		_note(_content, "El arma principal es a dos manos: no admite secundaria.")
	else:
		_off_stats(_content, Game.equipped_off)


# Cabecera de un bloque de arma: nombre + boton Cambiar (si procede).
func _bloque_arma(rol: String, nombre: String, permite_cambio: bool, on_cambiar: Callable) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var t := Label.new()
	t.text = "%s:  %s" % [rol, nombre]
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_color_override("font_color", Color(0.9, 0.95, 0.8))
	head.add_child(t)
	if permite_cambio:
		var b := Button.new()
		b.text = "Cambiar"
		b.pressed.connect(on_cambiar)
		head.add_child(b)
	_content.add_child(head)


# --- Catalogos: solo lo que TIENES en el baul (Game.owned_*) ---

# Armas validas como PRINCIPAL (solo WeaponData).
func _catalogo_main() -> Array:
	var r: Array = []
	for it in Game.owned_weapons:
		if it is WeaponData:
			r.append(it)
	return r

# Manos SECUNDARIAS posibles: "nada" (null) + todo el baul (la validez la filtra
# _secundaria_valida, que ya descarta la que llevas en la principal).
func _catalogo_off() -> Array:
	var r: Array = [null]
	for it in Game.owned_weapons:
		r.append(it)
	return r

# Piezas del baul que encajan en el slot + la opcion de ir sin pieza.
func _catalogo_armor(slot: String) -> Array:
	var r: Array = [null]
	for p in Game.owned_armor_de_slot(slot):
		r.append(p)
	return r


func _abrir_cambio(slot: String) -> void:
	_arma_change = slot
	if slot == "main":
		_arma_cand = _index_of_main()
	else:
		_arma_cand = _off_current_index(_catalogo_off())
	_rebuild()


func _build_armas_cambiar() -> void:
	var es_main: bool = _arma_change == "main"
	_title(_content, "Cambiar %s" % ("arma principal" if es_main else "mano secundaria"))
	_content.add_child(HSeparator.new())

	var catalogo: Array = _catalogo_main() if es_main else _catalogo_off()
	if catalogo.is_empty():
		_note(_content, "No tienes armas en el baúl.")
		return
	var labels: Array = []
	var disabled: Array = []
	for i in catalogo.size():
		var item: Resource = catalogo[i]
		if es_main:
			labels.append(Game.item_display_name(item))
		else:
			labels.append(_off_nombre(item))
			# Deshabilita las secundarias incompatibles con la principal actual.
			if not Game._secundaria_valida(Game.equipped_main, item):
				disabled.append(i)

	_build_cambiar_layout(labels, _arma_cand, disabled, _pick_arma,
		_preview_arma, _equipar_arma, _cancelar_arma)


func _pick_arma(i: int) -> void:
	_arma_cand = i
	_rebuild()

func _cancelar_arma() -> void:
	_arma_change = ""
	_rebuild()

func _equipar_arma() -> void:
	if _arma_change == "main":
		var cat: Array = _catalogo_main()
		if _arma_cand < cat.size():
			Game.equipar_arma(cat[_arma_cand])
	else:
		var cat_off: Array = _catalogo_off()
		if _arma_cand < cat_off.size():
			Game.equipar_secundaria(cat_off[_arma_cand])
	_arma_change = ""
	_rebuild()


# Construye el panel de stats del candidato de arma (derecha de la cuadricula).
func _preview_arma(vb: VBoxContainer) -> void:
	if _arma_change == "main":
		var cat: Array = _catalogo_main()
		if _arma_cand >= cat.size():
			return
		var w: WeaponData = cat[_arma_cand]
		_title(vb, Game.item_display_name(w))
		_weapon_stats(vb, w)
	else:
		var cat_off: Array = _catalogo_off()
		if _arma_cand >= cat_off.size():
			return
		var item: Resource = cat_off[_arma_cand]
		_title(vb, _off_nombre(item))
		_off_stats(vb, item)
		if item != null and item == Game.equipped_main:
			_note(vb, "Ya la llevas en la mano principal: necesitas otra igual para el dual.")
		elif item != null and not Game._secundaria_valida(Game.equipped_main, item):
			_note(vb, "No compatible con el arma principal actual.")


func _index_of_main() -> int:
	var cat: Array = _catalogo_main()
	for i in cat.size():
		if cat[i] == Game.equipped_main:
			return i
	return 0


func _off_current_index(list: Array) -> int:
	for i in list.size():
		if list[i] == Game.equipped_off:
			return i
	return 0


# --- Fichas de stats (reutilizadas por la vista normal y la preview) ---

# Tier/rareza/mejoras salen del PROPIO objeto (Game.meta_de), no del slot: asi el
# panel del candidato muestra sus datos aunque no lo lleves puesto.
func _weapon_stats(vb: VBoxContainer, w: WeaponData) -> void:
	if w == null:
		return
	var m: Dictionary = Game.meta_de(w)
	var tipo: String = WEAPON_TIPO_LABELS[clampi(int(w.tipo), 0, WEAPON_TIPO_LABELS.size() - 1)]
	_row(vb, "  Tipo", tipo + ("  (magia)" if w.es_magica else ""))
	_row(vb, "  Ataque base", "%.1f" % w.ataque_base)
	_row(vb, "  Motion value", "×%.2f" % w.motion_value)
	_row(vb, "  Velocidad", "×%.2f" % w.velocidad_mult)
	if w.crit_bonus != 0.0:
		_row(vb, "  Crítico", "+%s" % _fmt_pct(w.crit_bonus))
	if w.es_magica:
		_row(vb, "  Amplif. magia", "×%.2f" % w.magic_amp)
	_row(vb, "  Tier / rareza", "T%d · %s" % [int(m["tier"]), Upgrades.rareza_nombre(int(m["rareza"]))])
	_row(vb, "  Mejoras", "%d / %d" % [Upgrades.total_mejoras(m["mejoras"]),
		Upgrades.rareza_slots(int(m["rareza"]))])


func _off_stats(vb: VBoxContainer, item: Resource) -> void:
	if item == null:
		_note(vb, "  (sin mano secundaria)")
		return
	if item is WeaponData:
		_weapon_stats(vb, item as WeaponData)
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
		return "— (sin secundaria)"
	if item is WeaponData:
		return (item as WeaponData).nombre + " (dual)"
	if item is WandData:
		return (item as WandData).nombre + " (varita)"
	if item is ShieldData:
		return (item as ShieldData).nombre
	return "?"


# ============================================================
#  Pestaña ARMADURA
# ============================================================

func _build_armadura() -> void:
	if _armor_slot_sel == "":
		_build_armadura_lista()
	elif _armor_change:
		_build_armadura_cambiar()
	else:
		_build_armadura_detalle(_armor_slot_sel)


func _build_armadura_lista() -> void:
	_title(_content, "ARMADURA")
	if not Game.en_pueblo():
		_note(_content, "Cambios de equipo solo en el pueblo. Aquí es solo consulta.")
	_content.add_child(HSeparator.new())
	for slot in ARMOR_SLOTS:
		var pieza = Game.get("equipped_" + slot)
		var nombre: String = Game.item_display_name(pieza) if pieza is ArmorData else "(sin pieza)"
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
	_armor_change = false
	_rebuild()

func _cerrar_slot() -> void:
	_armor_slot_sel = ""
	_rebuild()


func _build_armadura_detalle(slot: String) -> void:
	var volver := Button.new()
	volver.text = "◀ Volver"
	volver.pressed.connect(_cerrar_slot)
	_content.add_child(volver)

	var pieza = Game.get("equipped_" + slot)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var t := Label.new()
	t.text = "%s:  %s" % [ARMOR_SLOT_LABELS[slot], (Game.item_display_name(pieza) if pieza is ArmorData else "(sin pieza)")]
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_color_override("font_color", Color(0.9, 0.95, 0.8))
	head.add_child(t)
	if Game.en_pueblo():
		var b := Button.new()
		b.text = "Cambiar"
		b.pressed.connect(_abrir_cambio_armor.bind(slot))
		head.add_child(b)
	_content.add_child(head)
	_content.add_child(HSeparator.new())

	_armor_ficha(_content, slot)


# Ficha de stats + mejoras de la pieza equipada en un slot.
func _armor_ficha(vb: VBoxContainer, slot: String) -> void:
	var pieza = Game.get("equipped_" + slot)
	if not (pieza is ArmorData):
		_note(vb, "Sin pieza en este slot.")
		return
	var a := pieza as ArmorData
	var am: Dictionary = Game.meta_de(a)
	var mods: Dictionary = Upgrades.armor_piece_mods(a, Game.tier_mult(int(am["tier"])),
		int(am["rareza"]), am["mejoras"])
	_row(vb, "  Defensa", "%.1f" % float(mods["def"]))
	_row(vb, "  Reducción", _fmt_pct(float(mods["reduccion"])))
	_row(vb, "  Velocidad", "×%.2f" % float(mods["vel_mult"]))
	if float(mods["evasion"]) > 0.0:
		_row(vb, "  Evasión", "+%s" % _fmt_pct(float(mods["evasion"])))
	if float(mods["crit_resist"]) > 0.0:
		_row(vb, "  Resist. crítico", "+%s" % _fmt_pct(float(mods["crit_resist"])))
	if float(mods["resist_estados"]) > 0.0:
		_row(vb, "  Resist. estados", "+%s" % _fmt_pct(float(mods["resist_estados"])))
	_row(vb, "  Tier / rareza", "T%d · %s" % [Game.equip_tier(slot), Upgrades.rareza_nombre(Game.equip_rareza(slot))])
	var mj: Dictionary = Game.equip_mejoras(slot)
	_row(vb, "  Mejoras", "%d / %d" % [Upgrades.total_mejoras(mj), Upgrades.rareza_slots(Game.equip_rareza(slot))])
	if not mj.is_empty():
		for cat in mj:
			_row(vb, "    · " + Upgrades.cat_nombre(cat), "x%d" % int(mj[cat]))


func _abrir_cambio_armor(slot: String) -> void:
	_armor_slot_sel = slot
	_armor_change = true
	var pieza = Game.get("equipped_" + slot)
	_armor_cand = 0
	var cat: Array = _catalogo_armor(slot)
	for i in cat.size():
		if cat[i] == pieza:
			_armor_cand = i
			break
	_rebuild()


func _build_armadura_cambiar() -> void:
	var slot: String = _armor_slot_sel
	_title(_content, "Cambiar %s" % ARMOR_SLOT_LABELS[slot])
	_content.add_child(HSeparator.new())
	var cat: Array = _catalogo_armor(slot)
	var labels: Array = []
	for p in cat:
		labels.append("(sin pieza)" if p == null else Game.item_display_name(p))
	if cat.size() <= 1:
		_note(_content, "No tienes piezas de este slot en el baúl.")
	_build_cambiar_layout(labels, _armor_cand, [], _pick_armor,
		_preview_armor, _equipar_armor, _cancelar_armor)


func _pick_armor(i: int) -> void:
	_armor_cand = i
	_rebuild()

func _cancelar_armor() -> void:
	_armor_change = false
	_rebuild()

func _equipar_armor() -> void:
	var slot: String = _armor_slot_sel
	var cat: Array = _catalogo_armor(slot)
	if _armor_cand < cat.size():
		Game.equipar_armadura(slot, cat[_armor_cand])
	_armor_change = false
	_rebuild()


# Panel de stats de la pieza candidata (derecha de la cuadricula).
func _preview_armor(vb: VBoxContainer) -> void:
	var slot: String = _armor_slot_sel
	var cat: Array = _catalogo_armor(slot)
	if _armor_cand >= cat.size() or cat[_armor_cand] == null:
		_title(vb, "(sin pieza)")
		_note(vb, "Sin armadura en este slot: +velocidad por ir ligero, 0 defensa.")
		return
	var a: ArmorData = cat[_armor_cand]
	_title(vb, Game.item_display_name(a))
	var am: Dictionary = Game.meta_de(a)
	var mods: Dictionary = Upgrades.armor_piece_mods(a, Game.tier_mult(int(am["tier"])),
		int(am["rareza"]), am["mejoras"])
	_row(vb, "  Defensa", "%.1f" % float(mods["def"]))
	_row(vb, "  Reducción", _fmt_pct(float(mods["reduccion"])))
	_row(vb, "  Velocidad", "×%.2f" % float(mods["vel_mult"]))
	if float(mods["evasion"]) > 0.0:
		_row(vb, "  Evasión", "+%s" % _fmt_pct(float(mods["evasion"])))
	if float(mods["crit_resist"]) > 0.0:
		_row(vb, "  Resist. crítico", "+%s" % _fmt_pct(float(mods["crit_resist"])))


# ============================================================
#  Cuadricula de seleccion + panel de stats a la derecha (comun armas/armadura)
# ============================================================

func _build_cambiar_layout(labels: Array, cand: int, disabled: Array,
		on_pick: Callable, preview_builder: Callable,
		on_equipar: Callable, on_cancel: Callable) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(hb)

	# Izquierda: cuadricula de botones (uno por item).
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for i in labels.size():
		var b := Button.new()
		b.text = str(labels[i])
		b.toggle_mode = true
		b.button_pressed = (i == cand)
		b.clip_text = true
		b.custom_minimum_size = Vector2(120, 46)
		if disabled.has(i):
			b.disabled = true
		else:
			b.pressed.connect(on_pick.bind(i))
		grid.add_child(b)
	hb.add_child(grid)

	# Derecha: stats del candidato + acciones.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(right)
	preview_builder.call(right)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	var eq := Button.new()
	eq.text = "Equipar"
	eq.disabled = disabled.has(cand)
	eq.pressed.connect(on_equipar)
	actions.add_child(eq)
	var ca := Button.new()
	ca.text = "Cancelar"
	ca.pressed.connect(on_cancel)
	actions.add_child(ca)
	right.add_child(HSeparator.new())
	right.add_child(actions)
