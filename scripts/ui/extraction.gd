# ============================================================
#  extraction.gd
#  Minijuego de EXTRACCION del cristal (Fase 5). Barra horizontal con una
#  ZONA verde en posicion ALEATORIA; un marcador la recorre y pulsas ESPACIO
#  cuando esta dentro. Pulsas un TOTAL fijo de veces (N); cada pulsacion es
#  acierto o fallo, y cada ACIERTO acelera un poco el marcador.
#  La calidad sale de la PROPORCION de fallos (asi vale para 2, 3, 4, 5...):
#    0 fallos = INTACTO, <=1/3 = NORMAL, <=2/3 = DAÑADO, mas = ROTO.
#  Se crea por codigo (sin .tscn). Devuelve el Cristal por la señal.
# ============================================================

extends Control

signal extraction_finished(cristal: Cristal)

enum { RUNNING, FINISHED }

var _categoria: int = 1
var _presses: int = 3          # pulsaciones TOTALES (aciertes o falles)
var _zone_ratio: float = 0.13  # ancho de la zona (fraccion de la barra)
var _marker_speed: float = 0.8 # recorrido por segundo (0..1)
var _speed_step: float = 0.3   # cuanto acelera por cada acierto

var _done: int = 0
var _misses: int = 0
var _marker: float = 0.0
var _marker_dir: float = 1.0
var _zone_start: float = 0.0
var _state: int = RUNNING
var _result: Cristal = null
var _press_was: bool = false


func setup(categoria: int, presses: int, zone_ratio: float,
		marker_speed: float, speed_step: float) -> void:
	_categoria = categoria
	_presses = presses
	_zone_ratio = zone_ratio
	_marker_speed = marker_speed
	_speed_step = speed_step


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_randomize_zone()


func _process(delta: float) -> void:
	var pressed: bool = Input.is_key_pressed(KEY_SPACE)
	var edge: bool = pressed and not _press_was
	_press_was = pressed

	if _state == FINISHED:
		if edge:
			extraction_finished.emit(_result)
			queue_free()
		return

	_marker += _marker_dir * _marker_speed * delta
	if _marker >= 1.0:
		_marker = 1.0
		_marker_dir = -1.0
	elif _marker <= 0.0:
		_marker = 0.0
		_marker_dir = 1.0

	if edge:
		_attempt()

	queue_redraw()


func _attempt() -> void:
	_done += 1
	if _marker >= _zone_start and _marker <= _zone_start + _zone_ratio:
		_marker_speed += _speed_step  # acierto: acelera el marcador
	else:
		_misses += 1
	_randomize_zone()
	if _done >= _presses:
		_finish()


func _finish() -> void:
	_state = FINISHED
	var c := Cristal.new()
	c.categoria = _categoria
	var ratio: float = float(_misses) / float(_presses)
	if _misses == 0:
		c.calidad = Cristal.Calidad.INTACTO
	elif ratio <= 1.0 / 3.0:
		c.calidad = Cristal.Calidad.NORMAL
	elif ratio <= 2.0 / 3.0:
		c.calidad = Cristal.Calidad.DANADO
	else:
		c.calidad = Cristal.Calidad.ROTO
	_result = c
	queue_redraw()


func _randomize_zone() -> void:
	_zone_start = randf() * (1.0 - _zone_ratio)


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(0, 0, w, h), Color(0.08, 0.08, 0.1, 1.0))

	var bar_w: float = w * 0.6
	var bar_h: float = 36.0
	var bar_x: float = (w - bar_w) / 2.0
	var bar_y: float = h * 0.5

	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.25, 0.25, 0.28))
	draw_rect(Rect2(bar_x + _zone_start * bar_w, bar_y, _zone_ratio * bar_w, bar_h),
		Color(0.2, 0.8, 0.2))
	var mx: float = bar_x + _marker * bar_w
	draw_rect(Rect2(mx - 2.0, bar_y - 8.0, 4.0, bar_h + 16.0), Color.WHITE)

	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(bar_x, bar_y - 64.0),
		"Extraccion de cristal (categoria %d)" % _categoria,
		HORIZONTAL_ALIGNMENT_CENTER, bar_w, 22)
	if _state == RUNNING:
		draw_string(font, Vector2(bar_x, bar_y - 30.0),
			"Pulsacion %d/%d   Fallos: %d   -  pulsa ESPACIO" % [_done + 1, _presses, _misses],
			HORIZONTAL_ALIGNMENT_CENTER, bar_w, 18)
	else:
		var txt: String = "Cristal ROTO: lo has perdido" if _result.se_pierde() \
			else "¡Cristal %s!" % _result.calidad_texto()
		draw_string(font, Vector2(bar_x, bar_y - 30.0),
			txt + "   -  ESPACIO para continuar",
			HORIZONTAL_ALIGNMENT_CENTER, bar_w, 18)
