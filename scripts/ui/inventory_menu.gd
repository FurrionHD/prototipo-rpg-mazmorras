# ============================================================
#  inventory_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  INVENTARIO a pantalla completa (tecla I), con pestañas verticales:
#    1) BOLSA       - lo que llevas de la expedicion (cristales + materiales). Es lo que
#                     PESA. Seleccionas un stack y puedes SOLTARLO al suelo (modal de
#                     cantidad si hay mas de 1); lo soltado se recoge de nuevo con F.
#    2) CONSUMIBLES - pociones: seleccionas una y le das a "Usar".
#    3) MATERIALES  - los ya guardados en el HOGAR (no pesan). Solo consulta.
#    4) ARMAS       - armas/escudos/varitas de tu baul. Solo consulta (equipar: menu C).
#    5) ARMADURAS   - piezas de armadura de tu baul. Solo consulta.
#
#  PAUSA el juego mientras esta abierto (Game.abrir_menu / cerrar_menu), como el menu de
#  personaje: antes solo se congelaba al jugador y los bichos seguian a lo suyo, asi que abrir la
#  bolsa era invitar a que te emboscaran. UI por codigo.
# ============================================================

extends CanvasLayer

const TABS := ["Bolsa", "Mochila", "Consumibles", "Materiales", "Armas", "Armaduras"]
const WEAPON_TIPO_LABELS := ["Puños", "Daga", "Espada corta", "Espada larga", "Mandoble",
	"Estoque", "Hacha grande", "Maza pequeña", "Martillo grande", "Bastón"]
const ARMOR_TIPO_LABELS := ["Cuero", "Hierro", "Hierro completo", "Placas"]
const ARMOR_SLOT_LABELS := ["Casco", "Pecho", "Manos", "Pantalones", "Botas"]

var _root: Control = null
var _header: VBoxContainer = null   # cabecera FIJA (titulo de la pestaña, peso, avisos)
var _lista: VBoxContainer = null    # cuadricula de stacks, con su propio scroll
var _content: VBoxContainer = null  # ficha del item elegido, con el suyo
var _dinero_lbl: Label = null       # monedas, arriba a la derecha
var _tab_buttons: Array = []
var _modal: Control = null          # modal de cantidad (null = cerrado)
var _modal_spin: SpinBox = null     # selector de cantidad del modal
var _pending_modelo: Resource = null # stack que se va a soltar (espera al modal)

var _tab: int = 0
var _sel: int = 0                   # indice seleccionado en la cuadricula de la pestaña
var _stacks: Array = []             # stacks visibles de la pestaña actual


func _ready() -> void:
	layer = 91   # encima del HUD, debajo del menu de personaje (92) y del combate (100)
	process_mode = Node.PROCESS_MODE_ALWAYS   # abrirlo para el arbol: hay que seguir respondiendo

	var m: Dictionary = MenuScaffold.construir(self, "INVENTARIO", "", _cerrar, true)
	_root = m["root"]
	_header = m["header"]
	_lista = m["lista"]
	_content = m["content"]
	_dinero_lbl = m["dinero"]

	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 34)
		b.pressed.connect(_on_tab.bind(i))
		(m["side"] as VBoxContainer).add_child(b)
		_tab_buttons.append(b)


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
	if open:
		Game.abrir_menu()    # para el mundo entero: nada de que te embosquen con la bolsa abierta
	else:
		Game.cerrar_menu()
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
	_dinero_lbl.text = "%d monedas" % Game.money
	for zona in [_header, _lista, _content]:
		for c in zona.get_children():
			c.queue_free()
	for i in _tab_buttons.size():
		(_tab_buttons[i] as Button).button_pressed = (i == _tab)
	match _tab:
		0: _build_bolsa()
		1: _build_mochila()
		2: _build_consumibles()
		3: _build_materiales()
		4: _build_armas()
		5: _build_armaduras()


# ============================================================
#  Helpers de UI
# ============================================================

func _title(vb: VBoxContainer, txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36))
	l.add_theme_font_size_override("font_size", 16)
	vb.add_child(l)

func _row(vb: VBoxContainer, etiqueta: String, valor: String, color_valor: Variant = null) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = etiqueta
	k.custom_minimum_size = Vector2(150, 0)
	k.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	row.add_child(k)
	var v := Label.new()
	v.text = valor
	if color_valor is Color:
		v.add_theme_color_override("font_color", color_valor)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Sin esto una linea larga (p.ej. el resumen() del material) se sale del ancho y, como
	# el scroll horizontal esta apagado, se recorta en el borde y arrastra a toda la columna.
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(v)
	vb.add_child(row)

func _note(vb: VBoxContainer, txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
	l.add_theme_font_size_override("font_size", 11)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Sin ancho MINIMO: en el panel de detalle (estrecho) empujaria la columna fuera de la
	# pantalla. Que se ajuste al hueco y parta las lineas.
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(l)


# La cuadricula va a la columna de la LISTA (con su scroll: la bolsa se llena) y la ficha al
# panel de DETALLE (con el suyo). La cabecera se queda quieta arriba.
func _grid_detail(labels: Array, preview: Callable) -> void:
	if labels.is_empty():
		_note(_content, "(vacío)")
		return
	_sel = clampi(_sel, 0, labels.size() - 1)
	MenuScaffold.cuadricula(_lista, labels, _sel, _pick)
	preview.call(_content)


func _pick(i: int) -> void:
	_sel = i
	_rebuild()


# ============================================================
#  Stacks (agrupacion de items iguales)
# ============================================================

# Agrupa una lista de Cristal/MaterialItem en stacks {modelo, cantidad}.
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
	if it is MaterialItem:
		var m := it as MaterialItem
		return "m|%s|%d" % [m.nombre(), int(m.calidad)]
	return "?"


func _nombre_item(it: Resource) -> String:
	if it is Cristal:
		var c := it as Cristal
		return "Cristal Cat %d\n(%s)" % [c.categoria, c.calidad_texto()]
	if it is MaterialItem:
		var m := it as MaterialItem
		return "%s\n(%s)" % [m.nombre(), m.calidad_texto()]
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
	_title(_header, "BOLSA  (expedición)")
	var peso: float = Game.peso_actual()
	var cap: float = Game.capacidad_carga()
	var cab := Label.new()
	cab.text = "Peso: %d / %d%s" % [roundi(peso), roundi(cap),
		"    ¡SOBRECARGADO!" if Game.esta_sobrecargado() else ""]
	cab.add_theme_color_override("font_color",
		Color(1.0, 0.5, 0.5) if Game.esta_sobrecargado() else Color(0.85, 0.88, 0.92))
	_header.add_child(cab)
	_note(_header, "Lo que llevas encima. Los cristales solo salen vendiéndolos en la tienda; los materiales puedes guardarlos en el Hogar.")
	_header.add_child(HSeparator.new())

	var items: Array = []
	for c in Game.crystals:
		items.append(c)
	for m in Game.materiales:
		items.append(m)
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
	elif modelo is MaterialItem:
		var m := modelo as MaterialItem
		if m.data != null:
			_row(vb, "Material", m.data.resumen())
		_row(vb, "Calidad", m.calidad_texto())
		_row(vb, "Valor estimado", "%d  (total %d)" % [m.valor_estimado(), m.valor_estimado() * n])
		_row(vb, "Peso", "%.1f  (total %.1f)" % [m.peso(), m.peso() * n])
		if m.data != null and m.data.descripcion != "":
			_note(vb, m.data.descripcion)

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
#  Pestaña MOCHILA
#  La mochila es del EQUIPO, no de un personaje: la bolsa que llena tambien es una sola. Por eso
#  vive aqui, al lado del peso que modifica, y no en la ficha de nadie (estaba en la pestaña
#  Armadura del menu [C], entre cinco slots que si son personales, y eso hacia pensar que cada uno
#  llevaba la suya y que el peso se contaba por cabeza).
# ============================================================

func _build_mochila() -> void:
	_title(_header, "MOCHILA  (del equipo)")
	var m: BackpackData = Game.mochila_equipo
	_note(_header, "Una sola para todo el grupo: es lo único que sube la capacidad de carga. "
		+ "Llevas puesta: %s" % (Game.item_display_name(m) if m != null else "ninguna (solo el zurrón de serie)"))
	var cab := Label.new()
	cab.text = "Peso: %d / %d" % [roundi(Game.peso_actual()), roundi(Game.capacidad_carga())]
	cab.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	_header.add_child(cab)
	if not Game.en_pueblo():
		_note(_header, "Cambios de equipo solo en el pueblo. Aquí es solo consulta.")
	_header.add_child(HSeparator.new())

	_stacks = []
	for mo in Game.owned_mochilas:
		_stacks.append({"modelo": mo, "cantidad": 1})
	var labels: Array = []
	for s in _stacks:
		var mo: BackpackData = s["modelo"]
		labels.append(Game.item_display_name(mo) + ("\n(puesta)" if mo == Game.mochila_equipo else ""))
	_grid_detail(labels, _preview_mochila)


# Ficha de una MOCHILA: lo unico que hace es subir la carga, asi que se enseña lo que SUMA y lo que
# llevarias con ella puesta (la Fuerza del grupo multiplica el conjunto, asi que el numero final no
# es una suma a pelo).
func _preview_mochila(vb: VBoxContainer) -> void:
	var m: BackpackData = _stacks[_sel]["modelo"]
	var puesta: bool = m == Game.mochila_equipo
	var meta: Dictionary = Game.meta_de(m)
	_title(vb, Game.item_display_name(m) + ("   [puesta]" if puesta else ""))
	_row(vb, "Capacidad", "+%.0f de carga" % Game.capacidad_mochila(m))
	_row(vb, "Tier / rareza", "T%d · %s" % [
		int(meta["tier"]), Upgrades.rareza_nombre(int(meta["rareza"]))])
	_row(vb, "Llevaríais", "%.0f  (ahora: %.0f)" % [
		Game.capacidad_con_mochila(m), Game.capacidad_carga()])
	if m.descripcion != "":
		_note(vb, m.descripcion)

	vb.add_child(HSeparator.new())
	var b := Button.new()
	b.text = "Quitar" if puesta else "Equipar"
	b.disabled = not Game.en_pueblo()
	b.pressed.connect(func():
		Game.equipar_mochila(null if puesta else m)
		_rebuild())
	vb.add_child(b)
	if puesta:
		_note(vb, "Al quitarla os quedáis con el zurrón de serie (25 de carga).")


# ============================================================
#  Pestaña CONSUMIBLES
# ============================================================

func _build_consumibles() -> void:
	_title(_header, "CONSUMIBLES")
	_note(_header, "Selecciona una poción y elige a quién se la das. Cura por el tiempo (no de golpe).")
	_header.add_child(HSeparator.new())

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
	_title(vb, cons.nombre)
	_row(vb, "Cantidad", str(n))

	var sabido: bool = false
	if cons.es_grimorio():
		sabido = Game.equipped_spells.has(cons.spell)
		_row(vb, "Enseña", cons.spell.nombre)
		_row(vb, "Coste", "%d de maná" % cons.spell.coste_mana)
		_row(vb, "Hechizos", "%d / %d aprendidos" % [Game.equipped_spells.size(), Game.MAX_HECHIZOS])
	else:
		_row(vb, "Efecto", cons.resumen(Game.player_max_hp(), Game.player_max_mp()))
		_row(vb, "Duración", "%.0f s (fuera de combate)" % cons.segundos)
		_row(vb, "En combate", "%d turnos" % cons.turnos)
	if cons.descripcion != "":
		_note(vb, cons.descripcion)

	vb.add_child(HSeparator.new())
	# Una poción se le puede dar a CUALQUIERA del grupo, no solo al que va en cabeza: con varios
	# en el equipo sale un boton por persona (con su vida/maná, para ver quien la necesita). Con
	# uno solo, el boton "Usar" de siempre. Grimorios y piedras: como estaban (van al lider).
	var por_persona: bool = (cons.cura_hp() or cons.da_mana()) and Game.party.size() > 1
	if por_persona:
		_note(vb, "¿A quién se la das?")
		for pj in Game.party:
			var b := Button.new()
			var partes: Array = ["%.0f/%.0f ♥" % [Game.player_hp(pj), Game.player_max_hp(pj)]]
			if cons.da_mana():
				partes.append("%.0f/%.0f 🔷" % [Game.player_mp(pj), Game.player_max_mp(pj)])
			var corona: String = "👑 " if pj == Game.lider() else ""
			b.text = "%s%s  (%s)" % [corona, pj.nombre, "  ".join(partes)]
			b.pressed.connect(_on_usar.bind(cons, pj))
			vb.add_child(b)
	else:
		var usar := Button.new()
		usar.text = "Estudiar" if cons.es_grimorio() else "Usar"
		usar.disabled = cons.es_grimorio() and (sabido or Game.hechizos_llenos())
		usar.pressed.connect(_on_usar.bind(cons))
		vb.add_child(usar)
	if cons.es_grimorio():
		if sabido:
			_note(vb, "Ya te sabes este hechizo: el libro no te dice nada nuevo.")
		elif Game.hechizos_llenos():
			_note(vb, "No te caben más de %d hechizos a la vez: tendrás que olvidar uno antes." % Game.MAX_HECHIZOS)


func _on_usar(cons: ConsumableData, pj: PersonajeData = null) -> void:
	Game.usar_consumible(cons, pj)   # poción -> se la bebe 'pj'; grimorio -> se estudia
	_rebuild()


# ============================================================
#  Pestaña MATERIALES (baul del hogar)
# ============================================================

func _build_materiales() -> void:
	_title(_header, "MATERIALES  (guardados en el Hogar)")
	_note(_header, "Los materiales que has depositado en el Hogar del pueblo. No pesan. Los cristales no se guardan aquí: hay que venderlos en la tienda.")
	_header.add_child(HSeparator.new())
	_stacks = _agrupar(Game.almacen_materiales)
	_grid_detail(_labels_stacks(_stacks), _preview_material)


func _preview_material(vb: VBoxContainer) -> void:
	var m: MaterialItem = _stacks[_sel]["modelo"]
	var n: int = int(_stacks[_sel]["cantidad"])
	_title(vb, m.nombre())
	_row(vb, "Cantidad", str(n))
	if m.data != null:
		_row(vb, "Material", m.data.resumen())
	_row(vb, "Calidad", m.calidad_texto())
	_row(vb, "Valor estimado", "%d  (total %d)" % [m.valor_estimado(), m.valor_estimado() * n])
	if m.data != null and m.data.descripcion != "":
		_note(vb, m.data.descripcion)


# ============================================================
#  Pestaña ARMAS (baul)
# ============================================================

func _build_armas() -> void:
	_title(_header, "ARMAS  (tu baúl)")
	_note(_header, "Lo que posees. Para equiparlo, abre el menú de personaje [C] en el pueblo.")
	_header.add_child(HSeparator.new())
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


# "Lo lleva Fulano", o "" si no lo lleva nadie. Con grupo, un [equipada] a secas no vale: la misma
# espada puede estar puesta en cualquiera de los tuyos, y mirando solo al lider (que es lo que se
# hacia) la de un compañero salia como si estuviera en el baul, suelta.
func _marca_dueno(item: Resource) -> String:
	var dueno: PersonajeData = Game.quien_lleva(item)
	return "" if dueno == null else "   [la lleva %s]" % dueno.nombre


func _preview_arma(vb: VBoxContainer) -> void:
	var item: Resource = _stacks[_sel]["modelo"]
	var equipada: String = _marca_dueno(item)
	if item is WeaponData:
		var w := item as WeaponData
		_title(vb, Game.item_display_name(w) + equipada)
		# Ficha COMPARTIDA (MenuScaffold.filas_arma): las mismas stats resueltas que ve la tienda
		# y el menu de personaje, con el tier/rareza/mejoras REALES de esta pieza (antes se
		# enseñaban los valores base a secas, ignorando las mejoras y sin la evasion).
		var meta: Dictionary = Game.meta_de(w)
		for fila in MenuScaffold.filas_arma(w, int(meta["tier"]), int(meta["rareza"]), meta["mejoras"]):
			_row(vb, fila[0], fila[1])
		_row(vb, "Tier / rareza", "T%d · %s" % [int(meta["tier"]), Upgrades.rareza_nombre(int(meta["rareza"]))])
		_row(vb, "Durabilidad", Game.durabilidad_txt_item(w), Game.durabilidad_color(w))
	elif item is ShieldData:
		var s := item as ShieldData
		_title(vb, Game.item_display_name(s) + equipada)
		# Ficha COMPARTIDA, igual que el arma de arriba: antes se pintaba el .tres crudo y un T3
		# pristino enseñaba (y rendia) exactamente lo mismo que uno comun.
		var meta_s: Dictionary = Game.meta_de(s)
		for fila in MenuScaffold.filas_escudo(s, int(meta_s["tier"]), int(meta_s["rareza"]), meta_s["mejoras"]):
			_row(vb, fila[0], fila[1])
		_row(vb, "Tier / rareza", "T%d · %s" % [int(meta_s["tier"]), Upgrades.rareza_nombre(int(meta_s["rareza"]))])
		_row(vb, "Durabilidad", Game.durabilidad_txt_item(s), Game.durabilidad_color(s))
	elif item is WandData:
		var wd := item as WandData
		_title(vb, Game.item_display_name(wd) + equipada)
		# Por su math (Upgrades.magic_mods) con el tier/rareza/mejoras REALES de esta varita, como
		# el baston y el resto de equipo: antes se pintaba el .tres crudo (una varita T3 pristina
		# amplificaba y regeneraba lo mismo que una comun).
		var meta_w: Dictionary = Game.meta_de(wd)
		var mg: Dictionary = Upgrades.magic_mods(wd.magic_amp, Game.tier_mult(int(meta_w["tier"])),
			int(meta_w["rareza"]), meta_w["mejoras"])
		_row(vb, "Amplif. magia", "×%.2f" % float(mg["magic_amp"]))
		_row(vb, "Regen maná", "%.2f/turno" % (wd.mp_regen_turno * float(mg["regen_mult"])))
		_row(vb, "Vel. casteo", "×%.2f" % (wd.cast_vel_mult + float(mg["cast_vel_add"])))
		if float(mg["mana_reduccion"]) > 0.0:
			_row(vb, "Coste de maná", "-%.0f%%" % (float(mg["mana_reduccion"]) * 100.0))
		_row(vb, "Tier / rareza", "T%d · %s" % [int(meta_w["tier"]), Upgrades.rareza_nombre(int(meta_w["rareza"]))])
		_row(vb, "Durabilidad", Game.durabilidad_txt_item(wd), Game.durabilidad_color(wd))


# ============================================================
#  Pestaña ARMADURAS (baul)
# ============================================================

func _build_armaduras() -> void:
	_title(_header, "ARMADURAS  (tu baúl)")
	_note(_header, "Lo que posees. Para equiparlo, abre el menú de personaje [C] en el pueblo.")
	_header.add_child(HSeparator.new())
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
	_title(vb, Game.item_display_name(a) + _marca_dueno(a))
	_row(vb, "Slot", ARMOR_SLOT_LABELS[clampi(int(a.slot), 0, 4)])
	_row(vb, "Tipo", ARMOR_TIPO_LABELS[clampi(int(a.tipo), 0, 3)])
	_row(vb, "Defensa base", "%.2f" % (a.defensa_base * a.motion_def))
	_row(vb, "Reducción", "%.0f%%" % (a.reduccion * 100.0))
	_row(vb, "Velocidad", "×%.2f" % a.velocidad_mult)
	_row(vb, "Durabilidad", Game.durabilidad_txt_item(a), Game.durabilidad_color(a))


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
