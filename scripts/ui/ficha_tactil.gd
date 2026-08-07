# ============================================================
#  ficha_tactil.gd  (CanvasLayer, solo con los dedos)
#  MANTENER PULSADO para leer la ficha de lo que sea.
#
#  El problema: todas las descripciones del juego —lo que hace una habilidad, que te esta haciendo
#  un estado en combate, por que no puedes comprar algo— viven en `tooltip_text`, el tooltip NATIVO
#  de Godot. Y ese solo aparece cuando el RATON pasa por encima. Con el dedo no existe "pasar por
#  encima": pulsas o no pulsas. Asi que en el movil esas fichas eran sencillamente ILEGIBLES, no
#  habia ninguna forma de verlas.
#
#  La solucion, y por que asi: se escucha el dedo y, si lleva ~0,4 s quieto encima de algo que tenga
#  tooltip_text, se saca un panel con ese texto. Se hace UNA vez aqui y vale para los veinte menus y
#  para el combate, porque el texto ya esta puesto en todos: cero cambios pantalla por pantalla.
#
#  El control de debajo se busca A MANO recorriendo el arbol, y no con el control "bajo el raton"
#  que ofrece Godot: con los dedos ese dato va y viene segun la emulacion de raton, y aqui hace
#  falta que sea exacto.
#
#  Los menus tambien pueden llamar a `abrir()` directamente: es lo que hacen los botones ⓘ, para que
#  la ficha se pinte en un solo sitio y no en dos que se separen.
# ============================================================

extends CanvasLayer

# Lo que hay que aguantar para que sea "mantener pulsado" y no un toque. 0,4 s es lo que usan los
# moviles para su propio menu contextual: mas corto salta sin querer al pulsar botones, mas largo
# parece que no responde.
const ESPERA := 0.4
# Si el dedo se mueve mas que esto, ya no es mantener pulsado: es un arrastre (de los de
# arrastre_scroll.gd) y no hay que robarselo.
const MOVIMIENTO_MAX := 14.0

const ANCHO_PANEL := 460.0

var _panel: PanelContainer = null
var _texto: Label = null
var _titulo: Label = null

var _dedo: int = -1
var _origen: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _contando: bool = false
var _tragar: bool = false   # ya hemos abierto ficha: comerse lo que queda del gesto


func _ready() -> void:
	layer = 96   # por encima de todos los menus (92-95), por debajo del combate (100)
	process_mode = Node.PROCESS_MODE_ALWAYS   # los menus pausan el arbol y aqui hay que responder
	add_to_group("ficha_tactil")
	_construir()


func _construir() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.10, 0.97)
	sb.border_color = Color(0.87, 0.57, 0.26, 0.75)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(col)

	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size", 16)
	_titulo.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36))
	_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_titulo)

	_texto = Label.new()
	_texto.add_theme_font_size_override("font_size", 14)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.custom_minimum_size = Vector2(ANCHO_PANEL, 0)
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_texto)


# Enseña una ficha. La llaman el mantener pulsado y los botones ⓘ de los menus.
func abrir(texto: String, titulo: String = "", cerca_de: Vector2 = Vector2.INF) -> void:
	if texto.strip_edges() == "":
		return
	_titulo.text = titulo
	_titulo.visible = titulo != ""
	_texto.text = texto
	_panel.visible = true
	_panel.reset_size()
	await get_tree().process_frame   # hasta que no se mide, el tamaño del panel no es el bueno
	if not is_instance_valid(_panel):
		return
	_colocar(cerca_de)


func cerrar() -> void:
	if _panel != null:
		_panel.visible = false


func abierta() -> bool:
	return _panel != null and _panel.visible


# La pone cerca del dedo pero SIN salirse de la pantalla ni taparse con el propio dedo (por eso se
# sube un poco). Sin punto de referencia, al centro.
func _colocar(cerca_de: Vector2) -> void:
	var lienzo: Vector2 = get_viewport().get_visible_rect().size
	var tam: Vector2 = _panel.size
	var p: Vector2
	if cerca_de == Vector2.INF:
		p = (lienzo - tam) * 0.5
	else:
		p = cerca_de + Vector2(-tam.x * 0.5, -tam.y - 24.0)
	p.x = clampf(p.x, 12.0 + Tactil.borde.x, lienzo.x - tam.x - 12.0 - Tactil.borde.x)
	p.y = clampf(p.y, 12.0 + Tactil.borde.y, lienzo.y - tam.y - 12.0 - Tactil.borde.y)
	_panel.position = p


func _process(delta: float) -> void:
	if not _contando:
		return
	_t += delta
	if _t < ESPERA:
		return
	_contando = false
	var c: Control = _control_con_ficha(_origen)
	if c == null:
		return
	_tragar = true   # esto ya no es un toque: que no se dispare el boton de debajo
	abrir(c.tooltip_text, _nombre_de(c), _origen)


func _input(event: InputEvent) -> void:
	var pulsar: bool = false
	var soltar: bool = false
	var pos: Vector2 = Vector2.ZERO

	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		pos = t.position
		pulsar = t.pressed
		soltar = not t.pressed and (t.index == _dedo or _dedo == -2)
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.button_index != MOUSE_BUTTON_LEFT:
			return
		pos = m.position
		pulsar = m.pressed
		soltar = not m.pressed
	elif event is InputEventScreenDrag:
		_vigilar_movimiento((event as InputEventScreenDrag).position)
		return
	elif event is InputEventMouseMotion:
		_vigilar_movimiento((event as InputEventMouseMotion).position)
		return
	else:
		return

	if pulsar:
		# Con la ficha abierta, el siguiente toque la CIERRA y no hace nada mas: es la forma de
		# salir sin tener que buscar una ✕ diminuta.
		if abierta():
			cerrar()
			_tragar = true
			get_viewport().set_input_as_handled()
			return
		_dedo = (event as InputEventScreenTouch).index if event is InputEventScreenTouch else -2
		_origen = pos
		_t = 0.0
		_contando = true
		_tragar = false
	elif soltar:
		_contando = false
		_dedo = -1
		if _tragar:
			# El soltar de un gesto que ya abrio ficha se lo come esto: si no, el boton de debajo
			# se dispararia al levantar el dedo y habrias equipado la habilidad que solo querias leer.
			_tragar = false
			get_viewport().set_input_as_handled()


func _vigilar_movimiento(pos: Vector2) -> void:
	if _contando and pos.distance_to(_origen) > MOVIMIENTO_MAX:
		_contando = false   # se ha convertido en un arrastre: no es cosa nuestra


# El Control MAS PROFUNDO bajo el punto que tenga ficha que enseñar. Se recorre del ultimo hijo al
# primero porque ese es el orden de pintado: el ultimo es el que se ve por encima.
func _control_con_ficha(punto: Vector2) -> Control:
	var raiz: Node = get_tree().get_root()
	return _buscar(raiz, punto)


func _buscar(n: Node, punto: Vector2) -> Control:
	for i in range(n.get_child_count() - 1, -1, -1):
		var h: Node = n.get_child(i)
		if h is CanvasItem and not (h as CanvasItem).visible:
			continue
		var dentro: Control = _buscar(h, punto)
		if dentro != null:
			return dentro
	if n is Control:
		var c := n as Control
		if c.visible and c.tooltip_text != "" and c.get_global_rect().has_point(punto):
			return c
	return null


# Un titulo para la ficha, si se puede sacar de lo pulsado. Un Button trae su texto; lo demas, nada.
func _nombre_de(c: Control) -> String:
	if c is Button:
		return (c as Button).text.strip_edges()
	return ""
