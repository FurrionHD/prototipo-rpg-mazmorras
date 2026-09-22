# ============================================================
#  mercadillo_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  COMPRAR EN UN PUESTO DEL MERCADILLO. Lo abre el vendedor (VendedorMercadillo, F delante del puesto).
#
#  Pedido del usuario el 22/09/2026: mas sencillo que la tienda, porque cada puesto vende dos o cinco
#  cosas. NO es pantalla completa: un panel a la DERECHA, y la camara se desliza para dejarte a ti y al
#  vendedor en la mitad IZQUIERDA; al cerrar vuelve al centro, suave, sin tirones. Solo COMPRAR: sin
#  pestañas, sin vender, sin cesta, sin filtros. Con la MISMA cara que la tienda: las celdas cuadradas de
#  96 (MenuScaffold.rejilla_objetos) y la ficha del producto, la cantidad − n + y el boton.
#
#  Lo que vende cada puesto y cuando esta abierto: VendedoresPlan. El precio y el cobro, los de la tienda
#  (Game.precio_mostrador / Game.comprar_lote).
# ============================================================
extends CanvasLayer

const AMBAR := Color(0.95, 0.72, 0.36)
const LADO_CELDA := 96.0
const ANCHO_PANEL := 560.0
const MARGEN := 40.0             # del panel al borde derecho de la pantalla
# LA CAMARA: cuanto tarda en deslizarse, y hacia donde. Con el panel ocupando la derecha, el hueco libre
# es lo de su izquierda: la camara se mueve lo justo para que el centro de ese hueco quede donde estas tu.
const DESLIZ := 0.45

var _root: Control = null
var _panel: PanelContainer = null
var _titulo: Label = null
var _dinero: Label = null
var _lista: VBoxContainer = null
var _ficha: VBoxContainer = null
var _acciones: VBoxContainer = null
var _aviso: Label = null

var _vendedor: int = -1
var _genero: Array = []
var _sel: int = 0
var _cant: int = 1
var _tween: Tween = null


func _ready() -> void:
	layer = 91
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para mientras esta abierto
	add_to_group("mercadillo_menu")
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	# LO DE LA IZQUIERDA SE VE (tu y el vendedor), sin velo. Pulsar ahi cierra, como tocar fuera de un modal.
	var fuera := Control.new()
	fuera.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fuera.mouse_filter = Control.MOUSE_FILTER_STOP
	fuera.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			cerrar())
	_root.add_child(fuera)

	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -ANCHO_PANEL - MARGEN
	_panel.offset_right = -MARGEN
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	# La misma caja que los modales de la tienda (MenuScaffold.modal).
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.15, 0.99)
	sb.border_color = Color(1, 1, 1, 0.16)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	# Cabecera: "Mercadillo" pequeño, el nombre del puesto, tu dinero y la X.
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 10)
	col.add_child(cab)
	var titulos := VBoxContainer.new()
	titulos.add_theme_constant_override("separation", 0)
	titulos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(titulos)
	var chico := Label.new()
	chico.text = "Mercadillo"
	chico.add_theme_font_size_override("font_size", 11)
	chico.add_theme_color_override("font_color", MenuScaffold.GRIS)
	titulos.add_child(chico)
	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size", 20)
	_titulo.add_theme_color_override("font_color", AMBAR)
	titulos.add_child(_titulo)
	_dinero = Label.new()
	_dinero.add_theme_font_size_override("font_size", 15)
	_dinero.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cab.add_child(_dinero)
	MenuScaffold.pastilla(cab, "✕", cerrar, false).tooltip_text = "Cerrar [Esc]"
	col.add_child(HSeparator.new())

	_lista = VBoxContainer.new()
	col.add_child(_lista)
	_ficha = VBoxContainer.new()
	_ficha.add_theme_constant_override("separation", 4)
	col.add_child(_ficha)
	_aviso = Label.new()
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aviso.add_theme_font_size_override("font_size", 13)
	col.add_child(_aviso)
	_acciones = VBoxContainer.new()
	_acciones.add_theme_constant_override("separation", 4)
	col.add_child(_acciones)


# ============================================================
#  ABRIR Y CERRAR
# ============================================================
func abrir(vendedor: int) -> void:
	if Game._active_layer != null or Game.debug_panel_open:
		return
	if not VendedoresPlan.vende(vendedor, CicloDia.segundo()):
		return
	_vendedor = vendedor
	_genero = VendedoresPlan.genero(vendedor)
	_titulo.text = String(VendedoresPlan.VENDEDORES[vendedor]["nombre"])
	_sel = 0
	_cant = 1
	_aviso.text = ""
	# La rejilla, de cero: la que haya es la del ultimo puesto (marcar_en_rejilla la reutilizaria).
	MenuScaffold.vaciar(_lista)
	_root.visible = true
	Game.abrir_menu(self)
	_pintar()
	_deslizar_camara(true)


func cerrar() -> void:
	if not _root.visible:
		return
	_root.visible = false
	Game.cerrar_menu(self)
	_deslizar_camara(false)


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		cerrar()
		get_viewport().set_input_as_handled()


# LA CAMARA DEL JUGADOR, deslizada con su 'offset' (no se mueve el jugador: solo lo que se ve). El tween
# va colgado de este menu, que sigue vivo con el arbol en pausa. Si se cierra a mitad de la ida, la vuelta
# arranca desde donde este: sin saltos.
func _deslizar_camara(abrir_: bool) -> void:
	var jugador: Node = get_parent()
	var cam: Camera2D = jugador.get_node_or_null("Camera2D") as Camera2D if jugador != null else null
	if cam == null:
		return
	var destino := Vector2.ZERO
	if abrir_:
		# Lo que ocupa el panel, en la misma escala que el ancho de la pantalla de la interfaz.
		var ancho_ui: float = _root.get_viewport_rect().size.x
		var ocupa: float = (ANCHO_PANEL + MARGEN) / maxf(1.0, ancho_ui)
		var ancho_mundo: float = cam.get_viewport_rect().size.x / maxf(0.01, cam.zoom.x)
		destino = Vector2(ancho_mundo * ocupa * 0.5, 0.0)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(cam, "offset", destino, DESLIZ)


# ============================================================
#  PINTAR
# ============================================================
func _pintar() -> void:
	_dinero.text = "%d monedas" % Game.money
	var piezas: Array = []
	for m in _genero:
		piezas.append({"item": m, "pie": "%d" % _precio(m), "tooltip": String(m.get("nombre")),
			"marca": "", "activo": true})
	_sel = clampi(_sel, 0, maxi(0, piezas.size() - 1))
	if not MenuScaffold.marcar_en_rejilla(_lista, _sel):
		MenuScaffold.vaciar(_lista)
		MenuScaffold.rejilla_objetos(_lista, piezas, _sel, _elegir, 5, LADO_CELDA, false)
	_pintar_ficha()


func _elegir(i: int) -> void:
	if i == _sel:
		return
	_sel = i
	_cant = 1
	_aviso.text = ""
	_pintar()


func _precio(m: Resource) -> int:
	return Game.precio_mostrador(m, 1)


# La ficha del producto: la de un ingrediente en la tienda (shop_menu.ficha_objeto, rama MaterialData),
# y debajo la cantidad, el total y Comprar.
func _pintar_ficha() -> void:
	MenuScaffold.vaciar(_ficha)
	MenuScaffold.vaciar(_acciones)
	if _genero.is_empty():
		return
	var md := _genero[_sel] as MaterialData
	var precio: int = _precio(md)
	MenuScaffold.titulo_item(_ficha, md.nombre, md.color_rango(), md.rango_intensidad())
	MenuScaffold.banner_item(_ficha, md, "", "Ingrediente de cocina")
	MenuScaffold.fila(_ficha, "Tipo", md.tipo_texto())
	MenuScaffold.fila(_ficha, "Peso", "%.1f por unidad" % md.peso_base)
	var llevas: int = 0
	for x in Game.materiales:
		if x != null and x.data == md:
			llevas += 1
	MenuScaffold.fila(_ficha, "Llevas", "%d en la bolsa" % llevas)
	MenuScaffold.fila(_ficha, "Precio", "%d monedas" % precio, 170, AMBAR)

	_acciones.add_child(HSeparator.new())
	var total := Label.new()
	total.add_theme_color_override("font_color", AMBAR)
	total.add_theme_font_size_override("font_size", 18)
	total.text = "%d monedas" % (precio * _cant)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	_acciones.add_child(fila)
	var k := Label.new()
	k.text = "Cantidad"
	k.custom_minimum_size = Vector2(90, 0)
	k.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	fila.add_child(k)
	MenuScaffold.stepper(fila, _cant, 1, TOPE, func(n: int) -> void:
		_cant = n
		total.text = "%d monedas" % (precio * n))
	var hueco := Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(hueco)
	fila.add_child(total)
	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_END
	_acciones.add_child(botones)
	MenuScaffold.pastilla(botones, "Comprar", func(): _comprar(md), true, Game.puede_pagar(precio))


const TOPE := 99

func _comprar(md: MaterialData) -> void:
	var n: int = _cant
	var cobrado: int = Game.comprar_lote([{"base": md, "tier": 1, "n": n}])
	if cobrado <= 0:
		_aviso.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))
		_aviso.text = "No te llega para %d x %s." % [n, md.nombre]
	else:
		_aviso.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55))
		_aviso.text = "Compras %d x %s por %d monedas." % [n, md.nombre, cobrado] if n > 1 \
			else "Compras %s por %d monedas." % [md.nombre, cobrado]
	_cant = 1
	_pintar()
