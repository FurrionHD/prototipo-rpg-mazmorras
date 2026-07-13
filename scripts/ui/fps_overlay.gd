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

# Muestras del ultimo segundo (ms por frame).
var _muestras: PackedFloat32Array = PackedFloat32Array()
var _acum: float = 0.0

const VENTANA := 1.0   # cada cuanto se refresca el texto (segundos)


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS

	_lbl = Label.new()
	_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl.offset_left = -260
	_lbl.offset_right = -12
	_lbl.offset_top = 34      # justo debajo del "Piso: N" del HUD
	_lbl.add_theme_font_size_override("font_size", 13)
	_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_lbl.add_theme_constant_override("outline_size", 4)
	_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lbl)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_F3:
		visible = not visible


func _process(delta: float) -> void:
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
