# ============================================================
#  shop_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  Menu de la TIENDA. Lo abre el tendero del pueblo (shop.gd -> abrir()); no tiene tecla propia.
#
#  REHECHO el 16/09/2026 con la cara del inventario (referencia Honkai Star Rail). Las quejas del
#  playtest: era fea, habia cosas que no se podian vender y vender no era visual (botones de texto,
#  sin buscador ni filtros). Ahora: rejilla de celdas a la izquierda, ficha a la derecha, pestañas con
#  icono, buscador, orden y filtros por modal, y una CESTA para vender o comprar varias cosas de una.
#
#  Cuatro pestañas:
#   1) VENDER     - tienda/tienda_vender.gd: Botin · Equipo · Consumibles · Hogar (baul + cofre).
#   2) COMPRAR    - tienda/tienda_comprar.gd: Armas · Armaduras · Mochilas · Consumibles · Comida,
#                   con el mostrador T2 (el que abre el Rey Slime) como selector T1/T2.
#   3) RECOMPRAR  - lo que le has vendido al tendero (hasta 7), al mismo precio. Solo si hay algo.
#   4) PACK       - una vez por partida: un arma gratis + pociones. Desaparece al reclamarlo.
#
#  Este archivo es el ARMAZON: montaje, pestañas, barra de abajo, bandeja de la cesta, la ficha comun
#  de un objeto y las dos pestañas pequeñas. Toda la MATH vive en Game.
# ============================================================

extends CanvasLayer

const TiendaVender = preload("res://scripts/ui/tienda/tienda_vender.gd")
const TiendaComprar = preload("res://scripts/ui/tienda/tienda_comprar.gd")
const TiendaOrden = preload("res://scripts/ui/tienda/tienda_orden.gd")

const TABS := ["Vender", "Comprar", "Recomprar", "Pack inicial"]
const TAB_ICONOS := ["moneda", "bolsa", "flecha_arriba", "pergamino"]
const TAB_VENDER := 0
const TAB_COMPRAR := 1
const TAB_RECOMPRAR := 2
const TAB_PACK := 3

# Las mismas medidas que el inventario: 96 de celda y la ficha a 360.
const LADO_CELDA := 96.0
const ANCHO_FICHA := 360.0
const ANCHO_REJILLA_MIN := 420.0

const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const ROJO := Color(0.9, 0.5, 0.5)
const GRIS := Color(0.6, 0.63, 0.7)

const WEAPON_TIPO_LABELS := ["Puños", "Daga", "Espada corta", "Espada larga", "Mandoble",
	"Estoque", "Hacha grande", "Maza pequeña", "Martillo grande", "Bastón"]
const ARMOR_SLOT_LABELS := ["Casco", "Pecho", "Manos", "Pantalones", "Botas"]

var _root: Control = null
var _header: VBoxContainer = null
var _lista: VBoxContainer = null
var _content: VBoxContainer = null
var _dinero_lbl: Label = null
var _contador_lbl: Label = null
var _aviso_lbl: Label = null
var _titulo_seccion: Label = null
var _tab_buttons: Array = []
var barra_sub: HBoxContainer = null   # subpestañas (las rellena cada seccion)
var _buscador: LineEdit = null
var _fila_buscador: HBoxContainer = null
var _bandeja: PanelContainer = null
var _barra_pie: HBoxContainer = null
var _modal_capa: Control = null
var _modal_cuerpo: VBoxContainer = null

var vender = null     # TiendaVender
var comprar = null    # TiendaComprar
var orden = TiendaOrden.new()

var _tab: int = TAB_VENDER
var sel: int = 0
var stacks: Array = []       # lo pintado en la rejilla, en el mismo orden que las celdas
var cant: int = 1            # la cantidad del − n + de la ficha (de ESTE monton, no del menu)
var _aviso: String = ""
var _aviso_ok: bool = true


func _ready() -> void:
	layer = 91
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para: hay que seguir respondiendo
	add_to_group("shop_menu")
	vender = TiendaVender.new(self)
	comprar = TiendaComprar.new(self)

	# El MISMO montaje que el inventario (ver inventory_menu._ready, que explica cada paso): barra arriba
	# sin lateral, pestañas-icono centradas en la pantalla, rejilla que manda y ficha de ancho fijo.
	var m: Dictionary = MenuScaffold.construir(self, "TIENDA", "", _cerrar, true, false)
	_root = m["root"]
	_header = m["header"]
	_lista = m["lista"]
	_content = m["content"]
	_dinero_lbl = m["dinero"]
	# La linea de aviso SI se queda (el inventario la esconde): aqui cada venta y cada compra dicen lo
	# que has cobrado o pagado, y ese es su sitio fijo.
	_aviso_lbl = m["aviso"]

	var scroll: ScrollContainer = m["lista_scroll"]
	scroll.custom_minimum_size = Vector2(ANCHO_REJILLA_MIN, 0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_horizontal = Control.SIZE_FILL
	_content.custom_minimum_size = Vector2(ANCHO_FICHA, 0)
	(_content.get_parent() as ScrollContainer).size_flags_horizontal = Control.SIZE_FILL
	(_content.get_parent() as ScrollContainer).custom_minimum_size = Vector2(ANCHO_FICHA, 0)
	scroll.resized.connect(_on_lista_redimensionada)

	# LA COLUMNA IZQUIERDA: subpestañas, buscador, rejilla, bandeja de la cesta y barra de orden. Todo
	# lo que manda sobre la REJILLA va en su columna, fuera del scroll para que no se vaya al bajar.
	var split: BoxContainer = scroll.get_parent()
	split.remove_child(scroll)
	var col_izq := VBoxContainer.new()
	col_izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_izq.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_izq.add_theme_constant_override("separation", 6)
	split.add_child(col_izq)
	split.move_child(col_izq, 0)
	barra_sub = HBoxContainer.new()
	barra_sub.alignment = BoxContainer.ALIGNMENT_CENTER
	barra_sub.add_theme_constant_override("separation", 14)
	col_izq.add_child(barra_sub)

	# EL BUSCADOR, encima de la rejilla que filtra. Filtra al escribir (no hace falta Enter) y NO rehace
	# la ficha ni se pierde el foco: vive fuera de la zona que se vacia en cada pasada.
	_fila_buscador = HBoxContainer.new()
	col_izq.add_child(_fila_buscador)
	_buscador = LineEdit.new()
	_buscador.placeholder_text = "Buscar por nombre…"
	_buscador.clear_button_enabled = true
	_buscador.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buscador.custom_minimum_size = Vector2(0, 36)
	_buscador.text_changed.connect(_on_buscar)
	_fila_buscador.add_child(_buscador)

	col_izq.add_child(scroll)

	_bandeja = PanelContainer.new()
	var caja := StyleBoxFlat.new()
	caja.bg_color = Color(0.07, 0.08, 0.11, 0.95)
	caja.border_color = Color(AMBAR, 0.55)
	caja.set_border_width_all(1)
	caja.set_corner_radius_all(8)
	caja.set_content_margin_all(8)
	_bandeja.add_theme_stylebox_override("panel", caja)
	_bandeja.visible = false
	col_izq.add_child(_bandeja)

	_barra_pie = HBoxContainer.new()
	_barra_pie.add_theme_constant_override("separation", 10)
	col_izq.add_child(_barra_pie)

	var barra_tabs: HBoxContainer = m["side"]
	barra_tabs.add_theme_constant_override("separation", 14)
	for i in TABS.size():
		var b: Button = MenuScaffold.pestana_icono(TAB_ICONOS[i], TABS[i])
		b.pressed.connect(_on_tab.bind(i))
		barra_tabs.add_child(b)
		_tab_buttons.append(b)

	var barra: BoxContainer = barra_tabs.get_parent()
	(barra.get_child(0) as Control).visible = false
	var titulo := VBoxContainer.new()
	titulo.add_theme_constant_override("separation", 0)
	var chico := Label.new()
	chico.text = "Tienda"
	chico.add_theme_font_size_override("font_size", 11)
	chico.add_theme_color_override("font_color", MenuScaffold.GRIS)
	titulo.add_child(chico)
	_titulo_seccion = Label.new()
	_titulo_seccion.add_theme_font_size_override("font_size", 20)
	_titulo_seccion.add_theme_color_override("font_color", AMBAR)
	titulo.add_child(_titulo_seccion)
	barra.add_child(titulo)
	barra.move_child(titulo, 1)

	barra.remove_child(barra_tabs)
	var centrador := CenterContainer.new()
	centrador.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	centrador.offset_top = 16.0
	centrador.offset_bottom = 16.0 + MenuScaffold.LADO_ICONO
	centrador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(centrador)
	centrador.add_child(barra_tabs)

	_contador_lbl = Label.new()
	_contador_lbl.add_theme_font_size_override("font_size", 15)
	_contador_lbl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.90))
	_dinero_lbl.get_parent().remove_child(_dinero_lbl)
	_dinero_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_dinero_lbl.custom_minimum_size = Vector2.ZERO
	_dinero_lbl.add_theme_font_size_override("font_size", 15)
	for l in [_contador_lbl, _dinero_lbl]:
		barra.add_child(l)
		barra.move_child(l, barra.get_child_count() - 2)

	# MULTI: el cofre del hogar lo cambia el host (y lo que vendes de el se cobra cuando llega).
	if Net.has_signal("hogar_cambiado"):
		Net.hogar_cambiado.connect(func():
			if _root.visible and _tab == TAB_VENDER:
				_rebuild())
	if Net.has_signal("venta_cofre"):
		Net.venta_cofre.connect(func(txt: String):
			decir(txt)
			if _root.visible:
				_rebuild())


func abrir() -> void:
	# No abrir sobre un combate/extraccion ni con el panel DEBUG abierto.
	if Game._active_layer != null or Game.debug_panel_open:
		return
	_tab = TAB_VENDER
	sel = 0
	cant = -1
	_aviso = ""
	_root.visible = true
	Game.abrir_menu(self)   # para el mundo entero mientras el menu esta abierto
	_rebuild()


func _cerrar() -> void:
	_cerrar_modal()
	vender.al_cerrar()
	comprar.al_cerrar()
	_root.visible = false
	Game.cerrar_menu(self)


# ESC: primero el modal que haya encima, y solo despues la tienda. En _input y consumido, para que la
# pausa (que escucha en _unhandled_input) no se abra por detras.
func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if (event as InputEventKey).keycode != KEY_ESCAPE:
		return
	if _modal_capa != null:
		_cerrar_modal()
	else:
		_cerrar()
	get_viewport().set_input_as_handled()


func _on_tab(i: int) -> void:
	_tab = i
	sel = 0
	cant = -1
	_aviso = ""
	_rebuild()


# Lo llaman las secciones al cambiar de subpestaña.
func cambiar_pantalla() -> void:
	sel = 0
	cant = -1
	_aviso = ""
	_rebuild()


func decir(txt: String, ok: bool = true) -> void:
	_aviso = txt
	_aviso_ok = ok


# ============================================================
#  RECONSTRUIR
# ============================================================

var _reconstruyendo := false
var _solo_seleccion := false

func _rebuild() -> void:
	if _reconstruyendo:
		return
	_reconstruyendo = true
	_rebuild_real()
	_reconstruyendo = false


# Para las secciones (un nombre sin guion bajo que se pueda llamar desde fuera).
func rebuild() -> void:
	_rebuild()


func _rebuild_real() -> void:
	_dinero_lbl.text = "%d monedas" % Game.money
	contador("")
	MenuScaffold.subpestanas(barra_sub, [], [], -1, Callable())
	for zona in ([_header, _content] if _solo_seleccion else [_header, _lista, _content]):
		MenuScaffold.vaciar(zona)
	# Pestañas que solo existen cuando tienen algo dentro: recompra y pack inicial.
	var visible_tab := {TAB_RECOMPRAR: not Game.recompra.is_empty(), TAB_PACK: not Game.pack_inicial_reclamado}
	if not bool(visible_tab.get(_tab, true)):
		_tab = TAB_VENDER
	for i in _tab_buttons.size():
		var b := _tab_buttons[i] as Button
		b.visible = bool(visible_tab.get(i, true))
		b.button_pressed = (i == _tab)
	_titulo_seccion.text = TABS[_tab]
	var seccion = _seccion()
	_fila_buscador.visible = seccion != null
	if seccion != null and _buscador.text != orden.texto(seccion.clave()):
		_buscador.text = orden.texto(seccion.clave())   # asignar texto no dispara text_changed
	match _tab:
		TAB_VENDER: vender.build()
		TAB_COMPRAR: comprar.build()
		TAB_RECOMPRAR: _build_recomprar()
		TAB_PACK: _build_pack()
	_pintar_bandeja()
	_pintar_barra_pie()
	MenuScaffold.decir(_aviso_lbl, _aviso, _aviso_ok)


# La seccion con rejilla filtrable de la pestaña actual (null en Recomprar y Pack).
func _seccion():
	match _tab:
		TAB_VENDER: return vender
		TAB_COMPRAR: return comprar
	return null


func contador(txt: String, alerta: bool = false) -> void:
	_contador_lbl.text = txt
	_contador_lbl.visible = txt != ""
	_contador_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.52, 0.52) if alerta else Color(0.78, 0.82, 0.90))


func titulo_seccion(txt: String) -> void:
	_titulo_seccion.text = txt


func _on_buscar(t: String) -> void:
	var seccion = _seccion()
	if seccion == null:
		return
	orden.poner_texto(seccion.clave(), t)
	sel = 0
	cant = -1
	_rebuild()


# ============================================================
#  LA REJILLA
# ============================================================

func _columnas() -> int:
	var ancho: float = _lista.size.x
	if ancho <= 1.0:
		ancho = ANCHO_REJILLA_MIN
	return maxi(2, int(floorf((ancho + 6.0) / (LADO_CELDA + 6.0))))


var _cols_pintadas: int = 0

func _on_lista_redimensionada() -> void:
	if _root.visible and _columnas() != _cols_pintadas:
		_rebuild()


# Pinta la rejilla y la ficha del elegido. 'vacio' = lo que se dice cuando no hay nada.
func grid_detail(piezas: Array, preview: Callable, vacio: String = "(nada por aquí)") -> void:
	if piezas.is_empty():
		MenuScaffold.nota(_lista, vacio)
		return
	sel = clampi(sel, 0, piezas.size() - 1)
	if not (_solo_seleccion and MenuScaffold.marcar_en_rejilla(_lista, sel)):
		MenuScaffold.vaciar(_lista)
		_cols_pintadas = _columnas()
		MenuScaffold.rejilla_objetos(_lista, piezas, sel, _pick, _cols_pintadas, LADO_CELDA)
	preview.call(_content)


func _pick(i: int) -> void:
	sel = i
	cant = -1   # -1 = que la ficha elija (lo que haya en la cesta, o 1)
	_solo_seleccion = true
	_rebuild()
	_solo_seleccion = false


# Una celda de la rejilla (ver MenuScaffold.rejilla_objetos).
static func pieza(modelo: Resource, pie: String, tooltip: String, marca: String = "") -> Dictionary:
	return {"item": modelo, "pie": pie, "tooltip": tooltip, "marca": marca, "activo": true}


# ============================================================
#  LA BARRA DE ABAJO: orden, filtros y lo que ponga la seccion
# ============================================================

func _pintar_barra_pie() -> void:
	MenuScaffold.vaciar(_barra_pie)
	var seccion = _seccion()
	if seccion == null:
		return
	var clave: String = seccion.clave()
	if not seccion.grupos().is_empty():
		var embudo: Button = MenuScaffold.pastilla(_barra_pie, "Filtros", _abrir_modal_filtros, false)
		if orden.hay_filtro(clave):
			MenuScaffold.estilo_chip(embudo, true)
			embudo.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_PASTILLA)
	if seccion.criterios().size() > 1:
		MenuScaffold.pastilla(_barra_pie, orden.rotulo_orden(clave, seccion.criterios(),
			seccion.por_defecto()), _abrir_modal_orden, false)
	var hueco := Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_barra_pie.add_child(hueco)
	seccion.pie_extra(_barra_pie)


func _abrir_modal_orden() -> void:
	var seccion = _seccion()
	_cerrar_modal()
	var m: Dictionary = MenuScaffold.modal(_root, "Orden")
	_modal_capa = m["capa"]
	var crit: Array = seccion.criterios()
	var o: Dictionary = orden.orden_de(seccion.clave(), seccion.por_defecto())
	var marcadas: Array = []
	for i in crit.size():
		if String(crit[i]["campo"]) == String(o["campo"]):
			marcadas.append(i)
	MenuScaffold.chips(m["cuerpo"], "", crit, marcadas, func(i: int):
		orden.pulsar_criterio(seccion.clave(), String(crit[i]["campo"]), seccion.por_defecto())
		_cerrar_modal()
		sel = 0
		_rebuild(), 3)
	MenuScaffold.nota(m["cuerpo"], "Vuelve a pulsar el mismo criterio para invertirlo.")
	MenuScaffold.pastilla(m["acciones"], "Cerrar", _cerrar_modal, false)


func _abrir_modal_filtros() -> void:
	_cerrar_modal()
	var m: Dictionary = MenuScaffold.modal(_root, "Filtros")
	_modal_capa = m["capa"]
	_modal_cuerpo = m["cuerpo"]
	_refrescar_modal_filtros()
	MenuScaffold.pastilla(m["acciones"], "Quitar todo", func():
		orden.limpiar(_seccion().clave())
		sel = 0
		_refrescar_modal_filtros()
		_rebuild(), false)
	MenuScaffold.pastilla(m["acciones"], "Listo", _cerrar_modal)


func _refrescar_modal_filtros() -> void:
	if _modal_cuerpo == null or not is_instance_valid(_modal_cuerpo):
		return
	var seccion = _seccion()
	if seccion == null:
		return
	MenuScaffold.vaciar(_modal_cuerpo)
	var clave: String = seccion.clave()
	var f: Dictionary = orden.filtros_de(clave)
	for g in seccion.grupos():
		var grupo: String = String(g["clave"])
		var marcados: Array = f.get(grupo, [])
		var opciones: Array = []
		var marcadas: Array = []
		var vals: Array = g["opciones"]
		for i in vals.size():
			var valor: int = int(vals[i]["valor"])
			opciones.append({"nombre": String(vals[i]["nombre"]), "cuantos": orden.cuantos_con(grupo, valor)})
			if marcados.has(valor):
				marcadas.append(i)
		MenuScaffold.chips(_modal_cuerpo, String(g["titulo"]), opciones, marcadas, func(idx: int):
			orden.alternar(clave, grupo, int(vals[idx]["valor"]))
			sel = 0
			_refrescar_modal_filtros()
			_rebuild(), 4)


func _cerrar_modal() -> void:
	if _modal_capa != null and is_instance_valid(_modal_capa):
		_modal_capa.queue_free()
	_modal_capa = null
	_modal_cuerpo = null


# Un modal suelto para las secciones (confirmar la cesta). Devuelve lo de MenuScaffold.modal.
func abrir_modal(titulo: String, ancho: float = 520.0) -> Dictionary:
	_cerrar_modal()
	var m: Dictionary = MenuScaffold.modal(_root, titulo, ancho)
	_modal_capa = m["capa"]
	return m


func cerrar_modal() -> void:
	_cerrar_modal()


# ============================================================
#  LA BANDEJA DE LA CESTA (debajo de la rejilla)
#  Una fila que se desliza con lo apuntado ("Cebolla ×6 ✕": tocarlo lo quita), el total y los dos
#  botones. Solo aparece con algo dentro.
# ============================================================

func _pintar_bandeja() -> void:
	MenuScaffold.vaciar(_bandeja)
	var seccion = _seccion()
	if seccion == null or seccion.cesta.vacia():
		_bandeja.visible = false
		return
	seccion.cesta.sanear(seccion.disponible)
	if seccion.cesta.vacia():
		_bandeja.visible = false
		return
	_bandeja.visible = true
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_bandeja.add_child(vb)

	var desliza := ScrollContainer.new()
	desliza.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	desliza.custom_minimum_size = Vector2(0, 38)
	vb.add_child(desliza)
	if Tactil.activo:
		ArrastreScroll.enganchar(desliza)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	desliza.add_child(fila)
	for e in seccion.cesta.entradas:
		var s: Dictionary = e["stack"]
		var chip := Button.new()
		var n: int = int(e["n"])
		chip.text = "%s%s  ✕" % [seccion.nombre_corto(s), (" ×%d" % n) if n > 1 or int(s.get("cantidad", 1)) > 1 else ""]
		chip.tooltip_text = "Quitar de la cesta"
		MenuScaffold.estilo_chip(chip, false)
		var clave: String = String(e["clave"])
		chip.pressed.connect(func():
			seccion.cesta.quitar(clave)
			_rebuild())
		fila.add_child(chip)

	var abajo := HBoxContainer.new()
	abajo.add_theme_constant_override("separation", 10)
	vb.add_child(abajo)
	var total := Label.new()
	var cosas: int = seccion.cesta.entradas.size()
	total.text = "Cesta: %d %s · %d monedas" % [cosas, "cosa" if cosas == 1 else "cosas",
		seccion.cesta.total(seccion.precio_unidad)]
	total.add_theme_color_override("font_color", AMBAR)
	total.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	abajo.add_child(total)
	MenuScaffold.pastilla(abajo, "Vaciar", func():
		seccion.cesta.vaciar()
		_rebuild(), false)
	MenuScaffold.pastilla(abajo, seccion.rotulo_cesta(), seccion.confirmar_cesta)


# ============================================================
#  LA FICHA COMUN DE UN OBJETO (titulo, banner y sus filas)
#  Vale para lo que se vende (tu objeto, con su meta de verdad) y para lo que se compra (una copia de
#  escaparate con su tier, ver vitrina()): la ficha no distingue, y por eso lo que ves al comprar es lo
#  mismo que veras en el inventario.
# ============================================================

func ficha_objeto(vb: VBoxContainer, m: Resource, cantidad: int = 0) -> void:
	var pie: String = ("× %d" % cantidad) if cantidad > 1 else ""
	if m is Cristal:
		var c := m as Cristal
		MenuScaffold.titulo(vb, "Cristal Cat %d (%s)" % [c.categoria, c.calidad_texto()], 16, AMBAR)
		MenuScaffold.banner_item(vb, c, pie, "Cristal")
		row(vb, "Categoría", str(c.categoria))
		row(vb, "Calidad", c.calidad_texto())
		row(vb, "Peso", "%.1f" % c.peso())
	elif m is MaterialItem:
		var mi := m as MaterialItem
		if mi.data != null:
			MenuScaffold.titulo_item(vb, "%s (%s)" % [mi.nombre_mostrado(), mi.calidad_texto()],
				mi.data.color_rango(), mi.data.rango_intensidad())
		MenuScaffold.banner_item(vb, mi, pie, "Combustible" if _es_combustible(mi) else "Material")
		if mi.data != null:
			row(vb, "Material", mi.data.resumen())
		row(vb, "Calidad", mi.calidad_texto())
		row(vb, "Peso", "%.1f" % mi.peso())
		if mi.data != null and mi.data.descripcion != "":
			note(vb, mi.data.descripcion)
	elif m is MaterialData:
		var md := m as MaterialData
		MenuScaffold.titulo_item(vb, md.nombre, md.color_rango(), md.rango_intensidad())
		MenuScaffold.banner_item(vb, md, pie, "Ingrediente de cocina")
		row(vb, "Tipo", md.tipo_texto())
		row(vb, "Peso", "%.1f por unidad" % md.peso_base)
		# Cuantas llevas ENCIMA: lo que decide si hace falta comprar mas antes de bajar es la bolsa.
		var llevas: int = 0
		for x in Game.materiales:
			if x != null and x.data == md:
				llevas += 1
		row(vb, "Llevas", "%d en la bolsa" % llevas)
	elif m is ConsumableData:
		var cd := m as ConsumableData
		MenuScaffold.titulo(vb, cd.nombre, 16, AMBAR)
		MenuScaffold.banner_item(vb, cd, pie, _clase_consumible(cd))
		if cd.es_grimorio():
			row(vb, "Enseña", cd.spell.nombre)
		elif cd.es_plato():
			note(vb, cd.resumen_plato())
		elif cd.es_cebo():
			row(vb, "Atracción", cd.resumen(0.0, 0.0))
		elif not cd.es_tocho():
			row(vb, "Efecto", cd.resumen(Game.player_max_hp(), Game.player_max_mp()))
		row(vb, "Tienes", "%d en la bolsa" % int(Game.consumables.get(cd, 0)))
		if cd.descripcion != "":
			note(vb, cd.descripcion)
	elif m is WeaponData or m is ShieldData or m is WandData or m is ArmorData \
			or m is BackpackData or m is ToolData:
		_ficha_equipo(vb, m)


func _ficha_equipo(vb: VBoxContainer, m: Resource) -> void:
	var meta: Dictionary = Game.meta_de(m)
	var tier: int = int(meta["tier"])
	var rareza: int = int(meta["rareza"])
	var dueno: PersonajeData = Game.quien_lleva(m)
	MenuScaffold.titulo_item(vb, Game.item_display_name(m) + ("   [lo lleva %s]" % dueno.nombre if dueno != null else ""),
		Game.color_rareza_de(m), Game.intensidad_rareza_de(m))
	if m is WeaponData:
		var w := m as WeaponData
		MenuScaffold.banner_item(vb, w, "", WEAPON_TIPO_LABELS[clampi(int(w.tipo), 0, WEAPON_TIPO_LABELS.size() - 1)])
		for fila in MenuScaffold.filas_arma(w, tier, rareza, meta["mejoras"], null, Game.durabilidad_item(w)):
			row(vb, fila[0], fila[1])
	elif m is ShieldData:
		MenuScaffold.banner_item(vb, m, "", "Escudo")
		for fila in MenuScaffold.filas_escudo(m as ShieldData, tier, rareza, meta["mejoras"]):
			row(vb, fila[0], fila[1])
	elif m is WandData:
		var wd := m as WandData
		MenuScaffold.banner_item(vb, wd, "", "Varita")
		var mg: Dictionary = Upgrades.magic_mods(wd.magic_amp, Game.tier_mult(tier), rareza, meta["mejoras"])
		row(vb, "Amplif. magia", "×%.2f" % float(mg["magic_amp"]))
		row(vb, "Vel. casteo", "×%.2f" % (wd.cast_vel_mult + float(mg["cast_vel_add"])))
		for fila in MenuScaffold.filas_critico_magico(mg, wd.crit_bonus):
			row(vb, fila[0], fila[1])
	elif m is ArmorData:
		var a := m as ArmorData
		MenuScaffold.banner_item(vb, a, "", ARMOR_SLOT_LABELS[clampi(int(a.slot), 0, 4)])
		for fila in MenuScaffold.filas_armadura(a, tier, rareza, meta["mejoras"], Game.durabilidad_item(a)):
			row(vb, fila[0], fila[1])
	elif m is BackpackData:
		MenuScaffold.banner_item(vb, m, "", "Mochila del equipo")
		row(vb, "Capacidad", "+%.0f de carga" % Game.capacidad_mochila(m as BackpackData))
		row(vb, "Carga ahora", "%d" % roundi(Game.capacidad_carga()))
	elif m is ToolData:
		var t := m as ToolData
		MenuScaffold.banner_item(vb, t, "", t.tipo_texto())
		for fila in MenuScaffold.filas_herramienta(t):
			row(vb, fila[0], fila[1])
	# La durabilidad solo dice algo de una pieza USADA; en el mostrador todo sale nuevo.
	if not _es_vitrina(m):
		row(vb, "Durabilidad", Game.durabilidad_txt_item(m), Game.durabilidad_color(m))
	var desc: Variant = m.get("descripcion")
	if desc != null and str(desc) != "":
		note(vb, str(desc))


static func _es_combustible(mi: MaterialItem) -> bool:
	return mi.data != null and int(mi.data.tipo) == MaterialData.Tipo.COMBUSTIBLE


static func _clase_consumible(c: ConsumableData) -> String:
	if c.es_grimorio():
		return "Grimorio"
	if c.es_tocho():
		return "Tomo de sabiduría" if c.es_tomo_sabio() else "Tocho"
	if c.es_plato():
		return "Plato de cocina"
	if c.es_cebo():
		return "Cebo de pesca"
	if c.da_mana() and not c.cura_hp():
		return "Poción de maná"
	if c.cura_hp():
		return "Poción de vida"
	return "Consumible"


func row(vb: VBoxContainer, etiqueta: String, valor: String, color_valor: Variant = null) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = etiqueta
	k.custom_minimum_size = Vector2(150, 0)
	k.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	k.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	r.add_child(k)
	var v := Label.new()
	v.text = valor
	if color_valor is Color:
		v.add_theme_color_override("font_color", color_valor)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_child(v)
	vb.add_child(r)


func note(vb: VBoxContainer, txt: String) -> void:
	MenuScaffold.nota(vb, txt)


# ============================================================
#  LA FILA DE LA OPERACION: cantidad, total y los dos botones
#
#  "Cantidad  −  n  +"  ·  "Total: 420 monedas"  ·  [A la cesta] [Vender]
#  El numero vale en cuanto lo escribes (ver MenuScaffold.stepper). El total se reescribe EN SITIO, sin
#  rehacer el panel, que es la trampa que avisa el propio stepper.
#  'en_cesta' = lo que ya hay apuntado de este monton: el stepper arranca ahi, y el boton de la cesta
#  pasa a "Cambiar en la cesta" (poner otra vez REEMPLAZA, no suma).
# ============================================================

func fila_accion(vb: VBoxContainer, maximo: int, precio: int, verbo: String, al_hacer: Callable,
		al_cesta: Callable, en_cesta: int, activo: bool = true) -> void:
	maximo = maxi(1, maximo)
	if cant < 1:
		cant = en_cesta if en_cesta > 0 else 1
	cant = clampi(cant, 1, maximo)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = "Cantidad"
	k.custom_minimum_size = Vector2(90, 0)
	k.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	fila.add_child(k)
	var total := Label.new()
	total.add_theme_color_override("font_color", AMBAR)
	total.add_theme_font_size_override("font_size", 18)
	total.text = "%d monedas" % (precio * cant)
	MenuScaffold.stepper(fila, cant, 1, maximo, func(n: int) -> void:
		cant = n
		total.text = "%d monedas" % (precio * n))
	vb.add_child(fila)
	var fila_total := HBoxContainer.new()
	var kt := Label.new()
	kt.text = "Total"
	kt.custom_minimum_size = Vector2(90, 0)
	kt.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	fila_total.add_child(kt)
	fila_total.add_child(total)
	vb.add_child(fila_total)

	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 8)
	botones.alignment = BoxContainer.ALIGNMENT_END
	vb.add_child(botones)
	MenuScaffold.pastilla(botones, "Cambiar en la cesta" if en_cesta > 0 else "A la cesta",
		func(): al_cesta.call(cant), false, activo)
	MenuScaffold.pastilla(botones, verbo, func(): al_hacer.call(cant), true, activo)
	if en_cesta > 0:
		var quitar := HBoxContainer.new()
		quitar.alignment = BoxContainer.ALIGNMENT_END
		vb.add_child(quitar)
		var l := Label.new()
		l.text = "En la cesta: %d" % en_cesta
		l.add_theme_color_override("font_color", AMBAR)
		quitar.add_child(l)
		MenuScaffold.pastilla(quitar, "Quitar", func(): al_cesta.call(0), false)


# ============================================================
#  LA VITRINA: copias de escaparate del catalogo
#  Los .tres del catalogo son COMPARTIDOS y no tienen tier: la celda y la ficha los leen por
#  Game.meta_de, que les crearia una meta T1 (en el mostrador T2 la muesca diria "T1") y ensuciaria
#  item_meta con recursos que no son de nadie. Se enseña una COPIA con su meta (Game.crear_item sin
#  registrar), la misma forma que tendra lo que te llevas. Las metas se borran al cerrar la tienda.
# ============================================================

var _vitrina: Dictionary = {}   # "ruta|tier" -> copia

func vitrina(base: Resource, tier: int) -> Resource:
	var k: String = "%s|%d" % [base.resource_path, tier]
	if not _vitrina.has(k):
		_vitrina[k] = Game.crear_item(base, tier, Upgrades.Rareza.COMUN, {}, false)
	return _vitrina[k]


func _es_vitrina(m: Resource) -> bool:
	return _vitrina.values().has(m)


func vaciar_vitrina() -> void:
	for copia in _vitrina.values():
		Game.item_meta.erase(copia)
	_vitrina.clear()


# ============================================================
#  Pestaña RECOMPRAR
# ============================================================

func _build_recomprar() -> void:
	contador("%d / %d" % [Game.recompra.size(), Game.RECOMPRA_MAX])
	stacks = []
	for i in Game.recompra.size():
		stacks.append({"modelo": Game.recompra[i]["item"], "idx": i, "precio": int(Game.recompra[i]["precio"])})
	var piezas: Array = []
	for s in stacks:
		piezas.append(pieza(s["modelo"], "%d" % int(s["precio"]), Game.item_display_name(s["modelo"])))
	grid_detail(piezas, _preview_recompra)


func _preview_recompra(vb: VBoxContainer) -> void:
	var s: Dictionary = stacks[sel]
	var precio: int = int(s["precio"])
	var llego: bool = Game.puede_pagar(precio)
	ficha_objeto(vb, s["modelo"])
	vb.add_child(HSeparator.new())
	row(vb, "Precio", "%d monedas" % precio, AMBAR)
	note(vb, "Vuelve tal y como estaba, con su tier y sus mejoras, por lo mismo que te pagó. Al pasarse de %d, lo más viejo se pierde." % Game.RECOMPRA_MAX)
	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_END
	vb.add_child(botones)
	MenuScaffold.pastilla(botones, "Recomprar", _on_recomprar, true, llego)
	if not llego:
		note(vb, "No te llega.")


func _on_recomprar() -> void:
	var s: Dictionary = stacks[sel]
	var nombre: String = Game.item_display_name(s["modelo"])
	if Game.recomprar(int(s["idx"])):
		decir("Recompras %s por %d monedas." % [nombre, int(s["precio"])])
	else:
		decir("No te llega para recomprar %s." % nombre, false)
	sel = 0
	_rebuild()


# ============================================================
#  Pestaña PACK INICIAL
# ============================================================

func _build_pack() -> void:
	stacks = []
	for ruta in Game.PACK_ARMAS:
		var base: Resource = load(ruta)
		if base != null:
			stacks.append({"modelo": vitrina(base, 1), "base": base})
	var piezas: Array = []
	for s in stacks:
		piezas.append(pieza(s["modelo"], "Gratis", str((s["base"] as Resource).get("nombre"))))
	grid_detail(piezas, _preview_pack)


func _preview_pack(vb: VBoxContainer) -> void:
	var s: Dictionary = stacks[sel]
	ficha_objeto(vb, s["modelo"])
	vb.add_child(HSeparator.new())
	note(vb, "Regalo de bienvenida, UNA sola vez: elige un arma y llévatela gratis, con %d pociones menores de propina. El bastón y la varita no entran: la magia te la pagas tú." % Game.PACK_POCIONES_N)
	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_END
	vb.add_child(botones)
	MenuScaffold.pastilla(botones, "Reclamar con esta arma", _on_reclamar_pack)


func _on_reclamar_pack() -> void:
	var base: Resource = stacks[sel]["base"]
	if Game.reclamar_pack_inicial(base):
		decir("Te llevas %s y %d pociones menores. Equípala en el menú de personaje [C]." % [
			str(base.get("nombre")), Game.PACK_POCIONES_N])
	else:
		decir("El pack ya estaba reclamado.", false)
	sel = 0
	_rebuild()
