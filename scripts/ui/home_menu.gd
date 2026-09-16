# ============================================================
#  home_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  Menu del HOGAR. Es el ARMAZON: la barra de arriba con las secciones, el aviso, abrir/cerrar y el
#  ciclo de repintado. Cada seccion vive en su archivo, en scripts/ui/hogar/:
#    - EQUIPO    (hogar_equipo.gd)    quien va contigo y en que orden.
#    - ENCARGOS  (hogar_encargos.gd)  mandar a los de casa a recolectar por reloj real.
#    - COFRE     (hogar_almacen.gd)   todo lo que se deja en casa: materiales, equipo, armas, armaduras, consumibles y hucha.
#
#  EL REPARTO es el del inventario: "Hogar" pequeño sobre el nombre de la seccion a la izquierda, las
#  secciones como ICONOS centrados en la pantalla, las monedas y la ✕ a la derecha. Debajo, una fila
#  de SUBPESTAÑAS que cada seccion llena si la necesita (vacia no se ve).
# ============================================================

extends CanvasLayer

const TABS := ["Equipo", "Encargos", "Cofre"]
const TAB_ICONOS := ["persona", "pergamino", "cofre"]

const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const GRIS := Color(0.6, 0.63, 0.7)

var _root: Control = null
var _header: VBoxContainer = null
var _content: VBoxContainer = null
var _lista: VBoxContainer = null
# La COLUMNA de la lista, para poder esconderla en las secciones que no la usan: si se queda ahi
# vacia, se lleva 330 px de ancho y el contenido de al lado se apretuja contra el borde.
var _lista_scroll: ScrollContainer = null
var _aviso_lbl: Label = null
var _tab_buttons: Array = []
var _titulo_seccion: Label = null
var _dinero_lbl: Label = null
# La fila de SUBPESTAÑAS, fuera de las zonas que se vacian: la llena la seccion con
# MenuScaffold.subpestanas (que ya se vacia sola) y sin nada no ocupa sitio.
var barra_sub: HBoxContainer = null
# La TERCERA fila (la subcategoria del almacen: mochila/herramientas/farolillo, tipo de arma...).
var barra_sub2: HBoxContainer = null
# El CONTADOR de la barra de arriba (el peso de la bolsa, como en el inventario). Lo pone la seccion.
var _contador_lbl: Label = null
# El reparto de la columna de la lista y la ficha tal como lo deja construir(), para devolverlo al
# salir del almacen (que lo invierte: rejilla ancha y ficha fija, como el inventario).
var _split_normal: Dictionary = {}
var _aviso: String = ""
var _aviso_ok: bool = true
var _tab: int = 0

# Las SECCIONES, cada una en su archivo (scripts/ui/hogar/). Pintan en las zonas de aqui arriba.
const HogarEquipo = preload("res://scripts/ui/hogar/hogar_equipo.gd")
const HogarEncargos = preload("res://scripts/ui/hogar/hogar_encargos.gd")
const HogarAlmacen = preload("res://scripts/ui/hogar/hogar_almacen.gd")
var equipo = null
var encargos = null
var almacen = null


func _ready() -> void:
	equipo = HogarEquipo.new(self)
	encargos = HogarEncargos.new(self)
	almacen = HogarAlmacen.new(self)
	layer = 91
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para: hay que seguir respondiendo
	add_to_group("home_menu")

	# con_dinero = true y con_lateral = false: la barra de arriba, como el inventario.
	var m: Dictionary = MenuScaffold.construir(self, "HOGAR", "", _cerrar, true, false)
	_root = m["root"]
	_header = m["header"]
	_content = m["content"]
	_lista = m["lista"]
	_lista_scroll = m["lista_scroll"]
	_aviso_lbl = m["aviso"]
	_dinero_lbl = m["dinero"]
	_montar_barra(m["side"])
	if Net.has_signal("hogar_cambiado"):
		Net.hogar_cambiado.connect(_on_hogar_cambiado)


# La barra de arriba, con la misma receta que inventory_menu._ready (ver sus notas): el titulo en dos
# lineas, las secciones sacadas a un CenterContainer a todo lo ancho (centradas en la PANTALLA y no en
# el hueco que dejan sus vecinos) y las monedas metidas en la barra junto a la ✕.
func _montar_barra(barra_tabs: HBoxContainer) -> void:
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
	chico.text = "Hogar"
	chico.add_theme_font_size_override("font_size", 11)
	chico.add_theme_color_override("font_color", GRIS)
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

	# LAS SUBPESTAÑAS, centradas a todo lo ancho justo encima del aviso y la cabecera.
	var cab: Control = _header.get_parent()
	barra_sub = HBoxContainer.new()
	barra_sub.alignment = BoxContainer.ALIGNMENT_CENTER
	barra_sub.add_theme_constant_override("separation", 14)
	cab.add_child(barra_sub)
	cab.move_child(barra_sub, 0)
	barra_sub2 = HBoxContainer.new()
	barra_sub2.alignment = BoxContainer.ALIGNMENT_CENTER
	barra_sub2.add_theme_constant_override("separation", 14)
	cab.add_child(barra_sub2)
	cab.move_child(barra_sub2, 1)

	var det: ScrollContainer = _content.get_parent() as ScrollContainer
	_split_normal = {
		"lista_flags": _lista_scroll.size_flags_horizontal,
		"lista_min": _lista_scroll.custom_minimum_size,
		"det_flags": det.size_flags_horizontal,
		"det_min": det.custom_minimum_size,
		"content_flags": _content.size_flags_horizontal,
		"content_min": _content.custom_minimum_size,
	}


# El reparto del ALMACEN (rejilla ancha a la izquierda, ficha de ancho fijo a la derecha, igual que el
# inventario) o el de siempre (lista y detalle). Lo pide cada seccion al pintarse.
const ANCHO_FICHA := 360.0
func modo_rejilla(on: bool) -> void:
	var det: ScrollContainer = _content.get_parent() as ScrollContainer
	# El cofre apaga el scroll de la lista para meter dentro sus dos columnas (cada una con el suyo): se
	# devuelve aqui, que es por donde pasan todas las secciones al repintarse.
	_lista_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_lista.size_flags_vertical = Control.SIZE_FILL
	if on:
		_lista_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_lista_scroll.custom_minimum_size = Vector2(420, 0)
		det.size_flags_horizontal = Control.SIZE_FILL
		det.custom_minimum_size = Vector2(ANCHO_FICHA + 16.0, 0)
		_content.size_flags_horizontal = Control.SIZE_FILL
		_content.custom_minimum_size = Vector2(ANCHO_FICHA, 0)
	else:
		_lista_scroll.size_flags_horizontal = _split_normal["lista_flags"]
		_lista_scroll.custom_minimum_size = _split_normal["lista_min"]
		det.size_flags_horizontal = _split_normal["det_flags"]
		det.custom_minimum_size = _split_normal["det_min"]
		_content.size_flags_horizontal = _split_normal["content_flags"]
		_content.custom_minimum_size = _split_normal["content_min"]


# El contador de arriba, rojo si 'alerta'.
func contador(txt: String, alerta: bool = false) -> void:
	_contador_lbl.text = txt
	_contador_lbl.add_theme_color_override("font_color",
		Color(0.95, 0.45, 0.4) if alerta else Color(0.78, 0.82, 0.90))


# El OTRO jugador cambio el estado compartido: si tengo el hogar abierto, me re-dibujo.
func _on_hogar_cambiado() -> void:
	if _root != null and _root.visible:
		_rebuild()


func abrir() -> void:
	if Game._active_layer != null or Game.debug_panel_open:
		return
	_tab = 0
	_aviso = ""
	_root.visible = true
	Game.abrir_menu(self)
	_rebuild()


func _cerrar() -> void:
	# Si has mandado a TODOS a casa, alguien tiene que llevar el cuerpo: baja tu original.
	# Va aqui porque _cerrar es el embudo de los TRES caminos de cierre -- la tecla Esc (_input de
	# abajo), el boton del scaffold, y el cierre a la fuerza cuando te embiste un bicho
	# (Game.cerrar_menus_abiertos). Game.lider() ya rellena con el original el solo; esto solo lo
	# adelanta para que sea determinista y para poder avisar.
	if Game.party.is_empty():
		var solo: PersonajeData = Game.lider()
		var p: Node = get_tree().get_first_node_in_group("player")
		if p != null and p.has_method("refrescar_lider"):
			p.refrescar_lider()
		var hud: Node = get_tree().get_first_node_in_group("hud")
		if hud != null and hud.has_method("mostrar_toast"):
			hud.mostrar_toast("No dejaste a nadie en el equipo: %s baja contigo." % solo.nombre)
	if almacen.has_method("al_cerrar"):
		almacen.al_cerrar()
	_root.visible = false
	Game.cerrar_menu(self)


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			# De dentro a fuera: primero el modal que haya encima, luego el editor de equipo, luego el hogar.
			if almacen.cerrar_modal():
				pass
			elif equipo.editor.abierto:
				equipo.editor.cancelar()
			else:
				_cerrar()
			get_viewport().set_input_as_handled()


func _on_tab(i: int) -> void:
	if i == _tab:
		return
	equipo.editor.abierto = false   # cambiar de seccion descarta el borrador del editor
	if _tab == TABS.find("Cofre") and almacen.has_method("al_cerrar"):
		almacen.al_cerrar()   # suelta lo que coja al entrar (el candado del taller)
	_tab = i
	_aviso = ""
	_rebuild()


# Guardia de REENTRADA. Un _rebuild puede entrar mientras otro esta a medias (el focus_exited de un
# stepper al liberarlo, las señales de red, un _on_* que espera en un await), y entonces el de dentro
# pinta su panel y el de fuera apila el suyo debajo: el menu salia DUPLICADO. Es el mismo guardia que
# lleva el herrero desde que se cazo alli.
var _reconstruyendo := false
# Y lo que llego MIENTRAS. Salir en seco perdia la señal: un hogar_cambiado que entra a mitad de un
# rebuild (los RPC llegan con el arbol pausado y este menu es PROCESS_MODE_ALWAYS) dejaba la pestaña
# mintiendo hasta que el jugador la tocara -- justo lo que no puede pasar con el roster en vivo.
var _rebuild_pendiente := false

func _rebuild() -> void:
	if _reconstruyendo:
		_rebuild_pendiente = true
		return
	_reconstruyendo = true
	# El baul se cuenta UNA vez por repintado (ver Game.abrir_recuento_hogar).
	Game.abrir_recuento_hogar()
	_rebuild_real()
	Game.cerrar_recuento_hogar()
	_reconstruyendo = false
	if _rebuild_pendiente:
		_rebuild_pendiente = false
		_rebuild()


func _rebuild_real() -> void:
	_tab = clampi(_tab, 0, TABS.size() - 1)
	for zona in [_header, _content, _lista]:
		MenuScaffold.vaciar(zona)
	MenuScaffold.subpestanas(barra_sub, [], [], 0, Callable())
	MenuScaffold.subpestanas(barra_sub2, [], [], 0, Callable())
	contador("")
	modo_rejilla(false)
	for i in _tab_buttons.size():
		(_tab_buttons[i] as Button).button_pressed = (i == _tab)
	_titulo_seccion.text = str(TABS[_tab])
	_dinero_lbl.text = "%d monedas" % Game.money
	MenuScaffold.decir(_aviso_lbl, _aviso, _aviso_ok)
	if _lista_scroll != null:
		_lista_scroll.visible = true   # cada seccion la esconde si no la usa

	match str(TABS[_tab]):
		"Equipo": equipo._build_equipo()
		"Encargos": encargos._build_encargos()
		"Cofre": almacen._build_seccion()



# ============================================================
#  PIEZAS COMPARTIDAS por Equipo y Encargos
# ============================================================
# TARJETA de una persona: los datos en una linea y los botones en OTRA, dentro de un panelito.
#
# Antes era todo una fila sola y no cabia: con tres botones detras del nombre, el ultimo se salia de
# la pantalla y no habia forma de pulsarlo. Poniendo los botones debajo cabe cualquier combinacion
# sin depender de lo largo que sea un nombre ni de cuantos botones lleve esa fila.
func _tarjeta(padre: VBoxContainer) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _fondo_tarjeta())
	padre.add_child(panel)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 3)
	panel.add_child(caja)
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	caja.add_child(info)
	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 4)
	caja.add_child(botones)
	# `caja` es el VBox entero: quien quiera colgar mas filas debajo de los botones (las ordenes de un
	# encargo, por ejemplo) las mete ahi.
	return {"info": info, "botones": botones, "caja": caja}


func _fondo_tarjeta() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.14, 0.85)
	sb.border_color = Color(0.30, 0.33, 0.40, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb


# El cuerpo del personaje, del tamaño de un icono: mismo color y mismo material que por el mapa.
func _punto(pj: PersonajeData) -> ColorRect:
	var punto := ColorRect.new()
	punto.custom_minimum_size = Vector2(18, 18)
	punto.color = pj.color
	punto.material = Game.material_de(pj)
	return punto


# El mismo punto pero SOLO con el color, para las filas que salen del roster: de un personaje de tu
# compañero no tienes el PersonajeData (ni su imagen), solo lo que el host publica.
func _punto_color(c: Variant) -> ColorRect:
	var punto := ColorRect.new()
	punto.custom_minimum_size = Vector2(18, 18)
	punto.color = c if c is Color else Color.WHITE
	return punto
