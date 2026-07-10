# ============================================================
#  inventory_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  INVENTARIO a pantalla completa (tecla I), con pestañas verticales:
#    1) BOLSA       - lo que llevas de la expedicion (cristales + drops). Es lo que
#                     PESA. Seleccionas un stack y puedes SOLTARLO al suelo (modal de
#                     cantidad si hay mas de 1); lo soltado se recoge de nuevo con F.
#    2) CONSUMIBLES - pociones: seleccionas una y le das a "Usar".
#    3) MATERIALES  - drops ya guardados en el HOGAR (no pesan). Solo consulta.
#    4) ARMAS       - armas/escudos/varitas de tu baul. Solo consulta (equipar: menu C).
#    5) ARMADURAS   - piezas de armadura de tu baul. Solo consulta.
#
#  NO pausa el juego (a diferencia del menu de personaje): congela al jugador via
#  Game.inventory_open, pero los enemigos siguen y pueden emboscarte. UI por codigo.
# ============================================================

extends CanvasLayer

const TABS := ["Bolsa", "Consumibles", "Materiales", "Armas", "Armaduras"]
const WEAPON_TIPO_LABELS := ["Puños", "Daga", "Espada corta", "Espada larga", "Mandoble",
	"Estoque", "Hacha grande", "Maza pequeña", "Martillo grande", "Bastón"]
const ARMOR_TIPO_LABELS := ["Cuero", "Hierro", "Hierro completo", "Placas"]
const ARMOR_SLOT_LABELS := ["Casco", "Pecho", "Manos", "Pantalones", "Botas"]

var _root: Control = null
var _content: VBoxContainer = null
var _tab_buttons: Array = []
var _modal: Control = null          # modal de cantidad (null = cerrado)
var _modal_spin: SpinBox = null     # selector de cantidad del modal
var _pending_modelo: Resource = null # stack que se va a soltar (espera al modal)

var _tab: int = 0
var _sel: int = 0                   # indice seleccionado en la cuadricula de la pestaña
var _stacks: Array = []             # stacks visibles de la pestaña actual


func _ready() -> void:
	layer = 91   # encima del HUD, debajo del menu de personaje (92) y del combate (100)

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

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

	# Pestañas verticales a la izquierda.
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(190, 0)
	side.add_theme_constant_override("separation", 6)
	hb.add_child(side)

	var titulo := Label.new()
	titulo.text = "INVENTARIO"
	titulo.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36))
	titulo.add_theme_font_size_override("font_size", 18)
	side.add_child(titulo)
	side.add_child(HSeparator.new())

	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 34)
		b.pressed.connect(_on_tab.bind(i))
		side.add_child(b)
		_tab_buttons.append(b)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)
	var cerrar := Button.new()
	cerrar.text = "✕ Cerrar  (I)"
	cerrar.custom_minimum_size = Vector2(0, 34)
	cerrar.pressed.connect(_cerrar)
	side.add_child(cerrar)

	# Contenido a la derecha.
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
	if code == KEY_I:
		_toggle()
	elif code == KEY_ESCAPE and _root.visible:
		if _modal != null:
			_cerrar_modal()
		else:
			_cerrar()


func _toggle() -> void:
	if not _root.visible:
		# No abrir sobre un combate/extraccion ni con el panel DEBUG abierto.
		# (Con el menu de personaje abierto el arbol esta en pausa: este _input ni corre.)
		if Game._active_layer != null or Game.debug_panel_open:
			return
		_set_open(true)
	else:
		_set_open(false)


func _cerrar() -> void:
	_set_open(false)


func _set_open(open: bool) -> void:
	_root.visible = open
	Game.inventory_open = open   # congela al jugador (los enemigos siguen)
	if not open:
		_cerrar_modal()
		return
	_tab = 0
	_sel = 0
	_rebuild()


func _on_tab(i: int) -> void:
	_tab = i
	_sel = 0
	_rebuild()


func _rebuild() -> void:
	for c in _content.get_children():
		c.queue_free()
	for i in _tab_buttons.size():
		(_tab_buttons[i] as Button).button_pressed = (i == _tab)
	match _tab:
		0: _build_bolsa()
		1: _build_consumibles()
		2: _build_materiales()
		3: _build_armas()
		4: _build_armaduras()


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
	k.custom_minimum_size = Vector2(150, 0)
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


# Cuadricula (izquierda) + panel de detalle (derecha). `labels` es la lista de textos de
# los botones; `preview` rellena el panel derecho con el elemento `_sel`.
func _grid_detail(labels: Array, preview: Callable) -> void:
	if labels.is_empty():
		_note(_content, "(vacío)")
		return
	_sel = clampi(_sel, 0, labels.size() - 1)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(hb)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for i in labels.size():
		var b := Button.new()
		b.text = str(labels[i])
		b.toggle_mode = true
		b.button_pressed = (i == _sel)
		b.clip_text = true
		b.custom_minimum_size = Vector2(130, 48)
		b.pressed.connect(_pick.bind(i))
		grid.add_child(b)
	hb.add_child(grid)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(right)
	preview.call(right)


func _pick(i: int) -> void:
	_sel = i
	_rebuild()


# ============================================================
#  Stacks (agrupacion de items iguales)
# ============================================================

# Agrupa una lista de Cristal/MonsterDrop en stacks {modelo, cantidad}.
func _agrupar(items: Array) -> Array:
	var claves: Array = []
	var mapa: Dictionary = {}
	for it in items:
		var k: String = _clave_item(it)
		if not mapa.has(k):
			mapa[k] = {"modelo": it, "cantidad": 0}
			claves.append(k)
		mapa[k]["cantidad"] += 1
	var res: Array = []
	for k in claves:
		res.append(mapa[k])
	return res


func _clave_item(it: Resource) -> String:
	if it is Cristal:
		var c := it as Cristal
		return "c|%d|%d" % [c.categoria, int(c.calidad)]
	if it is MonsterDrop:
		var d := it as MonsterDrop
		return "d|%s|%d" % [d.nombre, int(d.calidad)]
	return "?"


func _nombre_item(it: Resource) -> String:
	if it is Cristal:
		var c := it as Cristal
		return "Cristal Cat %d\n(%s)" % [c.categoria, c.calidad_texto()]
	if it is MonsterDrop:
		var d := it as MonsterDrop
		return "%s\n(%s)" % [d.nombre, d.calidad_texto()]
	return "?"


func _labels_stacks(stacks: Array) -> Array:
	var labels: Array = []
	for s in stacks:
		labels.append("%s  x%d" % [_nombre_item(s["modelo"]), int(s["cantidad"])])
	return labels


# ============================================================
#  Pestaña BOLSA
# ============================================================

func _build_bolsa() -> void:
	_title(_content, "BOLSA  (expedición)")
	var peso: float = Game.peso_actual()
	var cap: float = Game.capacidad_carga()
	var cab := Label.new()
	cab.text = "Peso: %d / %d%s" % [roundi(peso), roundi(cap),
		"    ¡SOBRECARGADO!" if Game.esta_sobrecargado() else ""]
	cab.add_theme_color_override("font_color",
		Color(1.0, 0.5, 0.5) if Game.esta_sobrecargado() else Color(0.85, 0.88, 0.92))
	_content.add_child(cab)
	_note(_content, "Lo que llevas encima. Los cristales solo salen vendiéndolos en la tienda; los materiales puedes guardarlos en el Hogar.")
	_content.add_child(HSeparator.new())

	var items: Array = []
	for c in Game.crystals:
		items.append(c)
	for d in Game.drops:
		items.append(d)
	_stacks = _agrupar(items)
	_grid_detail(_labels_stacks(_stacks), _preview_bolsa)


func _preview_bolsa(vb: VBoxContainer) -> void:
	var s: Dictionary = _stacks[_sel]
	var modelo: Resource = s["modelo"]
	var n: int = int(s["cantidad"])
	_title(vb, _nombre_item(modelo).replace("\n", " "))
	_row(vb, "Cantidad", str(n))
	if modelo is Cristal:
		var c := modelo as Cristal
		_row(vb, "Categoría", str(c.categoria))
		_row(vb, "Calidad", c.calidad_texto())
		_row(vb, "Valor estimado", "%d  (total %d)" % [c.valor_estimado(), c.valor_estimado() * n])
		_row(vb, "Peso", "%.1f  (total %.1f)" % [c.peso(), c.peso() * n])
	elif modelo is MonsterDrop:
		var d := modelo as MonsterDrop
		_row(vb, "Calidad", d.calidad_texto())
		_row(vb, "Valor estimado", "%d  (total %d)" % [d.valor_estimado(), d.valor_estimado() * n])
		_row(vb, "Peso", "%.1f  (total %.1f)" % [d.peso(), d.peso() * n])

	vb.add_child(HSeparator.new())
	var soltar := Button.new()
	soltar.text = "Soltar al suelo"
	soltar.pressed.connect(_on_soltar)
	vb.add_child(soltar)
	_note(vb, "Lo que sueltes queda en el suelo a tus pies; puedes recogerlo otra vez con [F].")


func _on_soltar() -> void:
	var s: Dictionary = _stacks[_sel]
	var n: int = int(s["cantidad"])
	_pending_modelo = s["modelo"]
	if n <= 1:
		_confirmar_soltar(1)   # una sola unidad: sin modal
	else:
		_abrir_modal_cantidad(n)


func _confirmar_soltar(cant: int) -> void:
	if _pending_modelo != null:
		Game.soltar_item(_pending_modelo, cant)
		_pending_modelo = null
	_rebuild()


# ============================================================
#  Pestaña CONSUMIBLES
# ============================================================

func _build_consumibles() -> void:
	_title(_content, "CONSUMIBLES")
	_note(_content, "Selecciona una poción y pulsa Usar. Cura por el tiempo (no de golpe).")
	_content.add_child(HSeparator.new())

	_stacks = []
	for c in Game.consumables.keys():
		var n: int = int(Game.consumables[c])
		if n > 0:
			_stacks.append({"modelo": c, "cantidad": n})
	var labels: Array = []
	for s in _stacks:
		labels.append("%s\nx%d" % [(s["modelo"] as ConsumableData).nombre, int(s["cantidad"])])
	_grid_detail(labels, _preview_consumible)


func _preview_consumible(vb: VBoxContainer) -> void:
	var cons: ConsumableData = _stacks[_sel]["modelo"]
	var n: int = int(_stacks[_sel]["cantidad"])
	var maxhp: float = Game.player_max_hp()
	var maxmp: float = Game.player_max_mp()
	_title(vb, cons.nombre)
	_row(vb, "Cantidad", str(n))
	_row(vb, "Efecto", cons.resumen(maxhp, maxmp))
	_row(vb, "Duración", "%.0f s (fuera de combate)" % cons.segundos)
	_row(vb, "En combate", "%d turnos" % cons.turnos)
	if cons.descripcion != "":
		_note(vb, cons.descripcion)
	vb.add_child(HSeparator.new())
	var usar := Button.new()
	usar.text = "Usar"
	usar.pressed.connect(_on_usar.bind(cons))
	vb.add_child(usar)


func _on_usar(cons: ConsumableData) -> void:
	Game.beber_pocion_fuera(cons)
	_rebuild()


# ============================================================
#  Pestaña MATERIALES (baul del hogar)
# ============================================================

func _build_materiales() -> void:
	_title(_content, "MATERIALES  (guardados en el Hogar)")
	_note(_content, "Los materiales que has depositado en el Hogar del pueblo. No pesan. Los cristales no se guardan aquí: hay que venderlos en la tienda.")
	_content.add_child(HSeparator.new())
	_stacks = _agrupar(Game.almacen_materiales)
	_grid_detail(_labels_stacks(_stacks), _preview_material)


func _preview_material(vb: VBoxContainer) -> void:
	var d: MonsterDrop = _stacks[_sel]["modelo"]
	var n: int = int(_stacks[_sel]["cantidad"])
	_title(vb, d.nombre)
	_row(vb, "Cantidad", str(n))
	_row(vb, "Calidad", d.calidad_texto())
	_row(vb, "Valor estimado", "%d  (total %d)" % [d.valor_estimado(), d.valor_estimado() * n])


# ============================================================
#  Pestaña ARMAS (baul)
# ============================================================

func _build_armas() -> void:
	_title(_content, "ARMAS  (tu baúl)")
	_note(_content, "Lo que posees. Para equiparlo, abre el menú de personaje [C] en el pueblo.")
	_content.add_child(HSeparator.new())
	_stacks = []
	for w in Game.owned_weapons:
		_stacks.append({"modelo": w, "cantidad": 1})
	var labels: Array = []
	for s in _stacks:
		labels.append(_nombre_equipo(s["modelo"]))
	_grid_detail(labels, _preview_arma)


func _nombre_equipo(item: Resource) -> String:
	if item is WeaponData:
		return (item as WeaponData).nombre + Game.item_plus(item)
	if item is ShieldData:
		return (item as ShieldData).nombre + Game.item_plus(item) + "\n(escudo)"
	if item is WandData:
		return (item as WandData).nombre + Game.item_plus(item) + "\n(varita)"
	return "?"


func _preview_arma(vb: VBoxContainer) -> void:
	var item: Resource = _stacks[_sel]["modelo"]
	var equipada: bool = item == Game.equipped_main or item == Game.equipped_off
	if item is WeaponData:
		var w := item as WeaponData
		_title(vb, Game.item_display_name(w) + ("   [equipada]" if equipada else ""))
		_row(vb, "Tipo", WEAPON_TIPO_LABELS[clampi(int(w.tipo), 0, WEAPON_TIPO_LABELS.size() - 1)]
			+ ("  (magia)" if w.es_magica else ""))
		_row(vb, "Manejo", "Dos manos" if w.dos_manos else "Una mano")
		_row(vb, "Ataque base", "%.1f" % w.ataque_base)
		_row(vb, "Motion value", "×%.2f" % w.motion_value)
		_row(vb, "Velocidad", "×%.2f" % w.velocidad_mult)
		if w.crit_bonus != 0.0:
			_row(vb, "Crítico", "%+.0f%%" % (w.crit_bonus * 100.0))
		if w.es_magica:
			_row(vb, "Amplif. magia", "×%.2f" % w.magic_amp)
	elif item is ShieldData:
		var s := item as ShieldData
		_title(vb, Game.item_display_name(s) + ("   [equipado]" if equipada else ""))
		_row(vb, "Bloqueo", "+%.0f%%" % (s.bloqueo * 100.0))
		_row(vb, "Velocidad", "×%.2f" % s.velocidad_mult)
		_row(vb, "Penal. esquiva", "-%.0f%%" % (s.evasion_penal * 100.0))
	elif item is WandData:
		var wd := item as WandData
		_title(vb, Game.item_display_name(wd) + ("   [equipada]" if equipada else ""))
		_row(vb, "Amplif. magia", "×%.2f" % wd.magic_amp)
		_row(vb, "Regen maná", "+%.2f/turno" % wd.mp_regen_bonus)
		_row(vb, "Vel. casteo", "×%.2f" % wd.velocidad_mult)


# ============================================================
#  Pestaña ARMADURAS (baul)
# ============================================================

func _build_armaduras() -> void:
	_title(_content, "ARMADURAS  (tu baúl)")
	_note(_content, "Lo que posees. Para equiparlo, abre el menú de personaje [C] en el pueblo.")
	_content.add_child(HSeparator.new())
	_stacks = []
	for p in Game.owned_armor:
		_stacks.append({"modelo": p, "cantidad": 1})
	var labels: Array = []
	for s in _stacks:
		var a: ArmorData = s["modelo"]
		labels.append("%s%s\n(%s)" % [a.nombre, Game.item_plus(a), ARMOR_SLOT_LABELS[clampi(int(a.slot), 0, 4)]])
	_grid_detail(labels, _preview_armadura)


func _preview_armadura(vb: VBoxContainer) -> void:
	var a: ArmorData = _stacks[_sel]["modelo"]
	var equipada: bool = Game.get("equipped_" + Game.ARMOR_SLOT_ORDEN[clampi(int(a.slot), 0, 4)]) == a
	_title(vb, Game.item_display_name(a) + ("   [equipada]" if equipada else ""))
	_row(vb, "Slot", ARMOR_SLOT_LABELS[clampi(int(a.slot), 0, 4)])
	_row(vb, "Tipo", ARMOR_TIPO_LABELS[clampi(int(a.tipo), 0, 3)])
	_row(vb, "Defensa base", "%.2f" % (a.defensa_base * a.motion_def))
	_row(vb, "Reducción", "%.0f%%" % (a.reduccion * 100.0))
	_row(vb, "Velocidad", "×%.2f" % a.velocidad_mult)


# ============================================================
#  Modal de CANTIDAD (para soltar varias unidades de un stack)
# ============================================================

func _abrir_modal_cantidad(maximo: int) -> void:
	_cerrar_modal()
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_modal)

	var back := ColorRect.new()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.color = Color(0, 0, 0, 0.6)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.add_child(back)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 1.0)
	sb.border_color = Color(0.87, 0.57, 0.26, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	var l := Label.new()
	l.text = "¿Cuántas quieres soltar?  (máx. %d)" % maximo
	vb.add_child(l)

	_modal_spin = SpinBox.new()
	_modal_spin.min_value = 1
	_modal_spin.max_value = maximo
	_modal_spin.step = 1
	_modal_spin.value = 1
	vb.add_child(_modal_spin)

	var acciones := HBoxContainer.new()
	acciones.add_theme_constant_override("separation", 8)
	var ok := Button.new()
	ok.text = "Soltar"
	ok.pressed.connect(_modal_aceptar)
	acciones.add_child(ok)
	var ca := Button.new()
	ca.text = "Cancelar"
	ca.pressed.connect(_cancelar_modal)
	acciones.add_child(ca)
	vb.add_child(acciones)


func _modal_aceptar() -> void:
	var cant: int = int(_modal_spin.value) if _modal_spin != null else 1
	_cerrar_modal()
	_confirmar_soltar(cant)


func _cancelar_modal() -> void:
	_pending_modelo = null
	_cerrar_modal()


func _cerrar_modal() -> void:
	if _modal != null:
		_modal.queue_free()
		_modal = null
	_modal_spin = null
