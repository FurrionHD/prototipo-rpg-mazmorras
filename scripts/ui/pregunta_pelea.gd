# ============================================================
#  pregunta_pelea.gd  (CanvasLayer creada por codigo desde Game._preguntar_entrar)
#  "¿QUIERES ENTRAR EN LA PELEA?" al chocar con la linea de la pelea de otro jugador (multi, 11/10).
#
#  Con Si entra por donde esta (Game.entrar_en_pelea_ajena). Con No no pasa nada: la linea le sigue
#  frenando, y si se despega y vuelve a chocar se le pregunta otra vez (ver ArenaCombate._mirar_desde_fuera).
#  Es la misma tarjeta que la oferta de la piedra de retorno (retorno_menu.gd): una frase y dos botones,
#  sin velo, y mientras esta delante el jugador no anda (Game.abrir_menu).
# ============================================================

extends CanvasLayer

const AMBAR := Color(0.95, 0.72, 0.36)

var _quien: String = ""
var _anfitrion: int = 0
var _caja: PanelContainer = null


func preparar(quien: String, anfitrion: int) -> void:
	_quien = quien
	_anfitrion = anfitrion


func _ready() -> void:
	layer = 94   # como la oferta de la piedra: encima de los menus, debajo del combate
	process_mode = Node.PROCESS_MODE_ALWAYS
	var raiz := Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)

	_caja = PanelContainer.new()
	_caja.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_caja.offset_left = -260
	_caja.offset_right = 260
	_caja.offset_top = 96
	_caja.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.border_color = Color(0, 0, 0, 0.9)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_caja.add_theme_stylebox_override("panel", sb)
	raiz.add_child(_caja)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_caja.add_child(vb)

	var frase := Label.new()
	frase.text = "%s está peleando. ¿Quieres entrar en la pelea?" % _quien
	frase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	frase.add_theme_color_override("font_color", AMBAR)
	frase.add_theme_font_size_override("font_size", 15)
	frase.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	frase.add_theme_constant_override("outline_size", 3)
	vb.add_child(frase)

	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 8)
	vb.add_child(fila)
	fila.add_child(_boton("Sí, entrar", _si))
	fila.add_child(_boton("No", _no))
	Game.abrir_menu(self)


func _boton(txt: String, al_pulsar: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(96, MenuScaffold.ALTO_BOTON)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(al_pulsar)
	return b


# La pelea se ha acabado (o me ha caido otra encima) con la pregunta delante: ya no hay nada que contestar.
func _process(_delta: float) -> void:
	if not Game.hay_zona_ajena(_anfitrion) or Game._active_layer != null:
		_cerrar()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		_no()
		get_viewport().set_input_as_handled()


func _si() -> void:
	_cerrar()
	Game.entrar_en_pelea_ajena(_anfitrion)


func _no() -> void:
	_cerrar()


func _cerrar() -> void:
	if is_queued_for_deletion():
		return
	Game.cerrar_menu(self)
	queue_free()
