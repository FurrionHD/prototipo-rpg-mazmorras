# ============================================================
#  rueda_cristales.gd  (CanvasLayer creada por codigo desde el jugador)
#  LA RUEDITA PARA SOLTAR CRISTALES (tecla G, playtest 08/10): "añadir algun atajo para soltar cristales, seria
#  comodo para mutar enemigos". Se abre con la G, enseña tus cristales en corro agrupados por categoria y calidad,
#  y cada clic suelta UNO delante de ti (a donde miras: es para cebar a un enemigo, no para tirarlo a tus pies);
#  mayus+clic suelta cinco. Se cierra con G, Esc, clic derecho o al quedarte sin cristales.
#
#  Para el mundo como cualquier menu (Game.abrir_menu): mientras eliges no te embisten. Lo soltado pasa por
#  Game.soltar_item, asi que en multi va por el suelo del host como siempre.
# ============================================================

extends CanvasLayer

const RADIO := 150.0        # del corro, en unidades logicas de 1280
const LADO_ICONO := 60.0
const RADIO_HUECO := 40.0   # el circulito de cada grupo
const CENTRO_MUERTO := 60.0 # con el raton aqui en medio no hay nada elegido
const DE_GOLPE := 5         # mayus+clic

var _root: Control
var _grupos: Array = []     # [{modelo: Cristal, n: int}], ordenados por categoria y calidad
var _sel: int = -1


func _ready() -> void:
	layer = 60
	add_to_group("rueda_cristales")
	process_mode = Node.PROCESS_MODE_ALWAYS   # abierta, el arbol esta en pausa (jugando solo)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	_root.draw.connect(_pintar)
	_root.gui_input.connect(_gui_input)
	add_child(_root)


func abierta() -> bool:
	return _root.visible


# En _unhandled_input (no _unhandled_key_input) para que el boton tactil, que llega como accion, tambien la abra.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"soltar") or event.is_echo():
		return
	if Game.escribiendo():
		return
	alternar()
	get_viewport().set_input_as_handled()


func alternar() -> void:
	if _root.visible:
		_cerrar()
	else:
		_abrir()


func _input(event: InputEvent) -> void:
	if _root.visible and event.is_action_pressed(&"ui_cancel"):
		_cerrar()
		get_viewport().set_input_as_handled()


func _abrir() -> void:
	# Ni encima de una pelea o una extraccion, ni del panel de dev, ni de otro menu (en multi nada pausa).
	if Game._active_layer != null or Game.debug_panel_open or Game.hay_modal():
		return
	_rehacer_grupos()
	if _grupos.is_empty():
		Net._toast("No llevas cristales.")
		return
	_root.visible = true
	_sel = -1
	Game.abrir_menu(self)
	_root.queue_redraw()


func _cerrar() -> void:
	if not _root.visible:
		return
	_root.visible = false
	Game.cerrar_menu(self)


func _rehacer_grupos() -> void:
	var por_clave: Dictionary = {}
	for c in Game.crystals:
		var k := Vector2i(c.categoria, int(c.calidad))
		if not por_clave.has(k):
			por_clave[k] = {"modelo": c, "n": 0}
		por_clave[k]["n"] += 1
	var claves: Array = por_clave.keys()
	# Categoria de menor a mayor; dentro, de la mejor calidad a la peor (INTACTO es el 0).
	claves.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	_grupos.clear()
	for k in claves:
		_grupos.append(por_clave[k])


func _centro() -> Vector2:
	return _root.size * 0.5


func _pos_hueco(i: int) -> Vector2:
	var ang: float = -PI * 0.5 + TAU * float(i) / float(maxi(1, _grupos.size()))
	return _centro() + Vector2.from_angle(ang) * RADIO


func _hueco_bajo(p: Vector2) -> int:
	var d: Vector2 = p - _centro()
	if d.length() < CENTRO_MUERTO or _grupos.is_empty():
		return -1
	# El sector mas cercano por angulo: no hace falta atinar al circulito.
	var ang: float = fposmod(d.angle() + PI * 0.5, TAU)
	var paso: float = TAU / float(_grupos.size())
	return int(round(ang / paso)) % _grupos.size()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var s: int = _hueco_bajo((event as InputEventMouseMotion).position)
		if s != _sel:
			_sel = s
			_root.queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_cerrar()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			var s2: int = _hueco_bajo(mb.position)
			if s2 < 0:
				_cerrar()   # clic en medio o fuera del corro: como Esc
			else:
				_soltar(s2, DE_GOLPE if mb.shift_pressed else 1)
		_root.accept_event()


func _soltar(i: int, n: int) -> void:
	var g: Dictionary = _grupos[i]
	var hechos: int = Game.soltar_item(g["modelo"], mini(n, int(g["n"])), true)
	if hechos > 0:
		Net._toast("Sueltas %s%s" % [Game._nombre_item(g["modelo"]), "" if hechos == 1 else " x%d" % hechos])
	_rehacer_grupos()
	if _grupos.is_empty():
		_cerrar()
		return
	_sel = _hueco_bajo(_root.get_local_mouse_position())
	_root.queue_redraw()


func _pintar() -> void:
	var c := _centro()
	_root.draw_rect(Rect2(Vector2.ZERO, _root.size), Color(0, 0, 0, 0.35))
	_root.draw_circle(c, RADIO + RADIO_HUECO + 14.0, Color(MenuScaffold.FONDO, 0.82))
	_root.draw_arc(c, RADIO + RADIO_HUECO + 14.0, 0.0, TAU, 96, Color(MenuScaffold.AMBAR, 0.35), 2.0)
	var f: Font = ThemeDB.fallback_font
	for i in _grupos.size():
		var g: Dictionary = _grupos[i]
		var p := _pos_hueco(i)
		var elegido: bool = i == _sel
		_root.draw_circle(p, RADIO_HUECO, Color(1, 1, 1, 0.16) if elegido else Color(1, 1, 1, 0.06))
		if elegido:
			_root.draw_arc(p, RADIO_HUECO, 0.0, TAU, 48, MenuScaffold.AMBAR, 2.0)
		IconoItem.pintar(_root, p - Vector2(0, 4), LADO_ICONO, g["modelo"], true)
		var txt := "Cat %d · x%d" % [int(g["modelo"].categoria), int(g["n"])]
		var tam := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		var tp := p + Vector2(-tam.x * 0.5, RADIO_HUECO - 4)
		_root.draw_string_outline(f, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.85))
		_root.draw_string(f, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	# En medio: lo elegido, o la ayuda.
	var l1: String = "Soltar cristal"
	var l2: String = "clic: 1   ·   mayús+clic: %d" % DE_GOLPE
	if _sel >= 0:
		l1 = Game._nombre_item(_grupos[_sel]["modelo"])
	for k in 2:
		var t: String = [l1, l2][k]
		var ts: int = [16, 12][k]
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, ts)
		var pp := c + Vector2(-w.x * 0.5, -4.0 + 20.0 * k)
		_root.draw_string(f, pp, t, HORIZONTAL_ALIGNMENT_LEFT, -1, ts,
			MenuScaffold.AMBAR if k == 0 else MenuScaffold.GRIS)
