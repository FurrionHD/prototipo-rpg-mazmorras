# ============================================================
#  fps_overlay.gd
#  Contador de FPS y de FRAME TIME. Lo crea Game (autoload), asi que existe en TODAS las
#  escenas y se pinta por ENCIMA de todo (capa 200: sobre el combate y los minijuegos, que
#  van en la 100). Se apaga y enciende con F3.
#
#  El numero que importa NO es el de FPS, es el FRAME TIME: 16.6 ms = 60 fps clavados,
#  33 ms = 30. Y sobre todo el PEOR frame del ultimo segundo: un juego que va "a 60 de media"
#  con picos de 40 ms se ve a tirones, y el contador de FPS medio no lo enseña jamas.
#
#  PROCESS_MODE_ALWAYS: tiene que seguir contando con el arbol en PAUSA, que es justo cuando
#  esta abierto un minijuego (que es donde se veia el problema).
# ============================================================

extends CanvasLayer

var _lbl: Label = null
var _caja: PanelContainer = null
# Lo que dice F3. La visibilidad REAL ademas se apaga sola con un menu abierto (_menu_abierto),
# asi que hace falta recordar aparte si el jugador lo quiere encendido.
var _encendido: bool = false

# Muestras del ultimo segundo (ms por frame).
var _muestras: PackedFloat32Array = PackedFloat32Array()
var _acum: float = 0.0

const VENTANA := 1.0   # cada cuanto se refresca el texto (segundos)


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Apagado de serie: es una herramienta de medir, no parte del juego. Se enciende con F3
	# (la tecla la recuerda la linea de ayudas del HUD).
	visible = false

	# Debajo del "Piso: N" Y del contador de monedas del HUD (que estan en 10 y 32): antes se
	# solapaba con el dinero. Dentro de un panel negro semitransparente, para que se lea
	# tambien sobre una pared clara.
	_caja = PanelContainer.new()
	_caja.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_caja.offset_left = -270
	_caja.offset_right = -12
	_caja.offset_top = 58
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	_caja.add_theme_stylebox_override("panel", sb)
	_caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caja)

	_lbl = Label.new()
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl.add_theme_font_size_override("font_size", 13)
	_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caja.add_child(_lbl)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_F3:
		_encendido = not _encendido
		visible = _encendido


# Con un MENU abierto el contador estorba y no mide nada util (el juego esta parado). En
# COMBATE y en los MINIJUEGOS, en cambio, se queda: son justo los sitios donde hay que medir.
func _menu_abierto() -> bool:
	if Game._active_layer != null:
		return false   # combate / minijuego: aqui SI queremos verlo
	return Game.inventory_open or Game.debug_panel_open or get_tree().paused


func _process(delta: float) -> void:
	if not _encendido:
		return
	visible = not _menu_abierto()
	if not visible:
		return
	_muestras.append(delta * 1000.0)
	_acum += delta
	if _acum < VENTANA:
		return

	var peor: float = 0.0
	var media: float = 0.0
	for ms in _muestras:
		media += ms
		peor = maxf(peor, ms)
	media /= float(maxi(1, _muestras.size()))

	# El texto dice las tres cosas que hacen falta para diagnosticar: a cuanto va, cuanto
	# tarda un frame de media, y cuanto tardo el PEOR. Si media ~16.6 y peor ~40, el problema
	# son los picos; si la media ya es 33, es que el juego entero va a 30.
	_lbl.text = "%d FPS   ·   %.1f ms (peor %.1f)   [F3]" % [
		Engine.get_frames_per_second(), media, peor]
	# Verde si va fino, amarillo si titubea, rojo si va a media velocidad.
	var col: Color = Color(0.6, 1.0, 0.6)
	if media > 28.0:
		col = Color(1.0, 0.45, 0.4)
	elif peor > 25.0:
		col = Color(1.0, 0.9, 0.4)
	_lbl.add_theme_color_override("font_color", col)

	_muestras.clear()
	_acum = 0.0
