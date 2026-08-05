# ============================================================
#  touch_pad.gd
#  La capa de dedos de los MINIJUEGOS. Se cuelga encima de mining/talado/harvest/extraction y de
#  la pesca, y hace dos cosas:
#
#   1) Traduce el dedo a la accion "recolectar". Toda la logica de los minijuegos lee esa accion
#      con Input.is_action_pressed(), asi que con esto funcionan los dos estilos SIN tocarlos:
#      los de mantener (mineria, tension de la pesca) y los de tocar en el momento justo
#      (tala, herboristeria, extraccion).
#   2) Publica DONDE esta el dedo (x_norm, 0 = borde izquierdo, 1 = derecho). Solo lo usa la
#      pesca, para apuntar la caña arrastrando en vez de con A/D.
#
#  Y monta la fila de botones de abajo a la derecha (Salir, Recoger...), que es la otra mitad del
#  problema: cuatro de los cinco minijuegos no tenian NINGUNA forma de salirse.
#
#  Sobre el doble evento: con la emulacion de raton desde el tactil encendida (la necesitamos para
#  que los menus se manejen a toques), un dedo genera el evento de pantalla Y un click de raton
#  detras. Por eso _origen: el primero que llega se queda el mando y el otro se ignora. En el PC
#  con --tactil solo llega el raton, asi que se puede probar sin aparato.
# ============================================================

extends Control

# El dedo se levanto sin haber tocado ningun boton (por si algun minijuego quiere enterarse).
signal dedo_soltado

const ALTO_FILA := 44.0
const MARGEN := 12.0

var _accion: StringName = &"recolectar"
var _zona: Control = null
var _fila: HBoxContainer = null
var _origen: String = ""      # "" | "dedo" | "raton": quien tiene el mando ahora mismo
var _dedo_idx: int = -1
var _x_norm: float = 0.5


func _init(accion: StringName = &"recolectar") -> void:
	_accion = accion


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# El pad en si no come nada: lo comen sus hijos. Asi el minijuego de debajo sigue pudiendo
	# tener sus propios controles si algun dia los tiene.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# La zona de toque, a pantalla completa. Va PRIMERA para quedar DEBAJO de los botones: Godot
	# reparte el input de la ultima hoja a la primera, asi que el boton "Salir" se lleva su toque
	# antes de que la zona lo cuente como un golpe de pico.
	_zona = Control.new()
	_zona.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_zona.mouse_filter = Control.MOUSE_FILTER_STOP
	_zona.gui_input.connect(_on_zona_input)
	add_child(_zona)

	_fila = HBoxContainer.new()
	_fila.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_fila.offset_right = -MARGEN
	_fila.offset_bottom = -MARGEN
	_fila.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_fila.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_fila.add_theme_constant_override("separation", 10)
	add_child(_fila)


func _exit_tree() -> void:
	# Si el minijuego se cierra con el dedo puesto, la accion se quedaria pulsada para siempre y
	# el jugador saldria al mapa dando golpes al aire.
	if _origen != "":
		Tactil.soltar(_accion)
		_origen = ""


# Un boton de la fila de abajo. Devuelve el Button para que quien lo pide conecte su pressed.
func anadir_boton(texto: String, color: Color = Color(0.20, 0.22, 0.28)) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(120, ALTO_FILA)
	b.focus_mode = Control.FOCUS_NONE   # que no se quede marcado despues de pulsarlo
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.corner_radius_top_left = 8
	estilo.corner_radius_top_right = 8
	estilo.corner_radius_bottom_left = 8
	estilo.corner_radius_bottom_right = 8
	b.add_theme_stylebox_override("normal", estilo)
	var pulsado := estilo.duplicate() as StyleBoxFlat
	pulsado.bg_color = color.lightened(0.25)
	b.add_theme_stylebox_override("pressed", pulsado)
	b.add_theme_stylebox_override("hover", pulsado)
	_fila.add_child(b)
	return b


# Donde esta el dedo, de 0 (izquierda) a 1 (derecha). 0.5 si no hay ninguno puesto.
func x_norm() -> float:
	return _x_norm


func hay_dedo() -> bool:
	return _origen != ""


func _on_zona_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_dedo_idx = t.index
			_tomar("dedo", t.position)
		elif t.index == _dedo_idx:
			_soltar("dedo")
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _dedo_idx and _origen == "dedo":
			_apuntar(d.position)
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.button_index != MOUSE_BUTTON_LEFT:
			return
		if m.pressed:
			_tomar("raton", m.position)
		else:
			_soltar("raton")
	elif event is InputEventMouseMotion and _origen == "raton":
		_apuntar((event as InputEventMouseMotion).position)


func _tomar(origen: String, pos: Vector2) -> void:
	if _origen != "":
		return   # ya manda otro (el click emulado que viene detras del dedo)
	_origen = origen
	_apuntar(pos)
	Tactil.pulsar(_accion)


func _soltar(origen: String) -> void:
	if _origen != origen:
		return
	_origen = ""
	_dedo_idx = -1
	Tactil.soltar(_accion)
	dedo_soltado.emit()


func _apuntar(pos: Vector2) -> void:
	if size.x > 0.0:
		_x_norm = clampf(pos.x / size.x, 0.0, 1.0)
