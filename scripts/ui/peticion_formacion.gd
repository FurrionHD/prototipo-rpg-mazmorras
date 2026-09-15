# ============================================================
#  peticion_formacion.gd  (CanvasLayer creada por codigo desde el jugador)
#  El AVISO de "tu compañero quiere cambiar el orden del equipo", con Aceptar y Rechazar.
#
#  NO es un modal ni pausa nada: te puede llegar en mitad de la mazmorra, asi que es un panel arriba
#  en el centro que no tapa el juego ni roba las teclas. Si llegan varias, se enseñan de una en una.
#  Contesta por Net.formacion.responder; si no se contesta, el host la da por rechazada al rato.
# ============================================================
extends CanvasLayer

var _cola: Array = []   # [{id, texto}]
var _panel: PanelContainer = null
var _texto: Label = null
var _actual: int = -1


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("peticion_formacion")
	Net.formacion.peticion_recibida.connect(_on_peticion)

	var ancla := CenterContainer.new()
	ancla.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	ancla.offset_top = 90
	ancla.offset_bottom = 230
	ancla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ancla)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(460, 0)
	_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.15, 0.97)
	sb.border_color = Color(0.45, 0.72, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", sb)
	ancla.add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_panel.add_child(vb)
	var titulo := Label.new()
	titulo.text = "Cambio de orden del equipo"
	titulo.add_theme_font_size_override("font_size", 15)
	titulo.add_theme_color_override("font_color", Color(0.45, 0.72, 0.95))
	vb.add_child(titulo)
	_texto = Label.new()
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.add_theme_font_size_override("font_size", 13)
	vb.add_child(_texto)
	var acc := HBoxContainer.new()
	acc.alignment = BoxContainer.ALIGNMENT_END
	acc.add_theme_constant_override("separation", 10)
	vb.add_child(acc)
	var no: Button = MenuScaffold.pastilla(acc, "Rechazar", _contestar.bind(false), false)
	no.focus_mode = Control.FOCUS_NONE
	var si: Button = MenuScaffold.pastilla(acc, "Aceptar", _contestar.bind(true))
	si.focus_mode = Control.FOCUS_NONE


func _on_peticion(id: int, _de_nombre: String, texto: String) -> void:
	_cola.append({"id": id, "texto": texto})
	if _actual < 0:
		_siguiente()


func _siguiente() -> void:
	if _cola.is_empty():
		_actual = -1
		_panel.visible = false
		return
	var p: Dictionary = _cola.pop_front()
	_actual = int(p["id"])
	_texto.text = str(p["texto"])
	_panel.visible = true


func _contestar(ok: bool) -> void:
	if _actual >= 0:
		Net.formacion.responder(_actual, ok)
	_siguiente()
