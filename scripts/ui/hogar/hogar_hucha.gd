# ============================================================
#  hogar_hucha.gd  --  la HUCHA del almacen del hogar (ver hogar_almacen.gd, que la llama).
#  Dinero guardado en casa. En solitario es tuyo y se guarda con la partida; en multi es COMUN (del
#  host): deposita uno y puede cogerlo el otro. Tu dinero de bolsillo sigue siendo tuyo.
# ============================================================
extends RefCounted

const AMBAR := Color(0.95, 0.72, 0.36)
const GRIS := Color(0.6, 0.63, 0.7)
const RAPIDAS := [100, 1000, 10000]   # botones de cantidad rapida

var hogar = null   # el armazon (home_menu.gd). Sin tipo: con CanvasLayer no se ven sus variables
var _input: String = ""   # la cantidad escrita (se conserva entre re-dibujos)


func _init(pantalla) -> void:
	hogar = pantalla


func pintar() -> void:
	# Sin rejilla: la columna de la lista se esconde y la hucha se queda con todo el ancho, centrada.
	hogar._lista_scroll.visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(460, 0)
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hogar._content.add_child(col)

	var saldos := HBoxContainer.new()
	saldos.add_theme_constant_override("separation", 40)
	saldos.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(saldos)
	_saldo(saldos, "En la hucha", Net.hogar.bote_visible(), AMBAR)
	_saldo(saldos, "En tu bolsillo", Game.money, Color(0.94, 0.95, 0.98))

	var le := LineEdit.new()
	le.text = _input
	le.placeholder_text = "Cantidad"
	le.alignment = HORIZONTAL_ALIGNMENT_CENTER
	le.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)
	le.add_theme_font_size_override("font_size", 20)
	le.text_changed.connect(func(t: String): _input = t)
	col.add_child(le)

	# Cantidades RAPIDAS: sumar de golpe sin teclear, que en el movil cuesta.
	var rap := HBoxContainer.new()
	rap.alignment = BoxContainer.ALIGNMENT_CENTER
	rap.add_theme_constant_override("separation", 8)
	col.add_child(rap)
	for n in RAPIDAS:
		var b := Button.new()
		b.text = "+%d" % n
		MenuScaffold.estilo_chip(b, false)
		b.custom_minimum_size = Vector2(90, 32)
		b.pressed.connect(func():
			_input = str(_cantidad() + int(n))
			hogar._rebuild())
		rap.add_child(b)

	var acc := HBoxContainer.new()
	acc.alignment = BoxContainer.ALIGNMENT_CENTER
	acc.add_theme_constant_override("separation", 12)
	col.add_child(acc)
	var dep: Button = MenuScaffold.pastilla(acc, "Guardar en la hucha", _depositar)
	dep.custom_minimum_size = Vector2(210, MenuScaffold.ALTO_BOTON)
	var ret: Button = MenuScaffold.pastilla(acc, "Sacar de la hucha", _retirar, false)
	ret.custom_minimum_size = Vector2(210, MenuScaffold.ALTO_BOTON)

	MenuScaffold.nota(col, "En compañía la hucha es de todos: lo que guardes lo puede sacar tu compañero."
		if Net.activo else "Se guarda con tu partida.")


func _saldo(padre: Control, que: String, cuanto: int, color: Color) -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	padre.add_child(vb)
	var t := Label.new()
	t.text = que
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 12)
	t.add_theme_color_override("font_color", GRIS)
	vb.add_child(t)
	var n := Label.new()
	n.text = "%d" % cuanto
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_theme_font_size_override("font_size", 30)
	n.add_theme_color_override("font_color", color)
	vb.add_child(n)


func _cantidad() -> int:
	var t: String = _input.strip_edges()
	return int(t) if t.is_valid_int() else 0


func _depositar() -> void:
	var n: int = _cantidad()
	if n <= 0:
		_decir("Escribe una cantidad.", false)
	elif Net.hogar.depositar_bote(n):
		_input = ""
		_decir("Guardas %d monedas en la hucha." % n, true)
	else:
		_decir("No llevas tanto encima.", false)


func _retirar() -> void:
	var n: int = _cantidad()
	if n <= 0:
		_decir("Escribe una cantidad.", false)
		return
	Net.hogar.retirar_bote(n)   # el host valida que hay tanto (si no, avisa por toast)
	_input = ""
	_decir("Sacas %d monedas de la hucha." % n, true)


func _decir(txt: String, ok: bool) -> void:
	hogar._aviso = txt
	hogar._aviso_ok = ok
	hogar._rebuild()
