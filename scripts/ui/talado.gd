# ============================================================
#  talado.gd
#  Minijuego de TALADO (enredadera -> hacha -> AGILIDAD). Los otros dos van de PUNTERIA:
#  en el cristal persigues un marcador, en la veta cargas y sueltas. Aqui va de COMPAS.
#
#  El tronco es un punto FIJO en el centro de la banda. Lo que se mueve es la VENTANA, que
#  da vueltas: entra por la izquierda, cruza el tronco y sale por la derecha. Cada vuelta es
#  un TIEMPO del compas, y en cada tiempo tienes que dar UN hachazo:
#    - ESPACIO con la ventana ENCIMA del tronco -> hachazo limpio (+1) y el ritmo ACELERA.
#    - ESPACIO fuera (te adelantas o te retrasas) -> pierdes el compas: +1 astilla.
#    - Dejar pasar la ventana SIN pulsar -> tambien pierdes el compas: +1 astilla.
#  Y cada astilla ENCOGE la ventana: fallar no solo te penaliza, te deja el siguiente tiempo
#  mas dificil. Es una bola de nieve, y de ahi sale la tension.
#
#  A las 3 astillas el tronco se raja y no sacas nada. Un solo hachazo por tiempo: machacar
#  espacio no sirve de nada (el primer toque resuelve el tiempo, acierte o falle).
#
#  La AGILIDAD ensancha la ventana y frena el compas. Se crea por codigo (sin .tscn).
# ============================================================

extends Control

signal talado_finished(item: MaterialItem)

enum { RUNNING, FINISHED }

# Donde esta el tronco en la banda. Fijo y en el centro: el reto es el ritmo, no adivinar
# donde hay que pegar.
const TRONCO := 0.5
# Astillas a las que el tronco se raja del todo.
const ASTILLAS_ROTO := 3
# Lo que ACELERA el compas por cada hachazo limpio (le coges el ritmo y vas a mas).
const TEMPO_SUBE := 1.08
# Lo que ENCOGE la ventana por cada astilla (pierdes el pulso y te cuesta recuperarlo).
const VENTANA_ENCOGE := 0.78
# Suelo de la ventana: por muy mal que lo hagas, nunca es literalmente imposible acertar.
const VENTANA_MIN := 0.03

var _material: MaterialData = null
var _hachazos: int = 4      # hachazos limpios que hacen falta para tumbarlo
var _ancho: float = 0.20    # ancho de la ventana (fraccion de la banda)
var _vel: float = 0.7       # vueltas por segundo

var _pos: float = 0.0       # borde IZQUIERDO de la ventana
var _progreso: int = 0
var _astillas: int = 0
var _tiempo_resuelto: bool = false   # ¿ya has dado (o fallado) el hachazo de esta vuelta?
var _ultimo: String = ""
var _state: int = RUNNING
var _result: MaterialItem = null
var _press_was: bool = false


func setup(material: MaterialData, hachazos: int, ancho: float, vel: float) -> void:
	_material = material
	_hachazos = maxi(1, hachazos)
	_ancho = ancho
	_vel = vel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_nueva_vuelta()


func _process(delta: float) -> void:
	var pressed: bool = Input.is_key_pressed(KEY_SPACE)
	var edge: bool = pressed and not _press_was
	_press_was = pressed

	if _state == FINISHED:
		if edge:
			talado_finished.emit(_result)
			queue_free()
		return

	_pos += _vel * delta

	# La ventana ha REBASADO el tronco y no has pulsado: has perdido el tiempo.
	if not _tiempo_resuelto and _pos > TRONCO:
		_fallar("Se te va el compás: el hacha muerde en falso")

	# Ha salido por la derecha: empieza la siguiente vuelta.
	if _pos >= 1.0:
		_nueva_vuelta()

	if edge and not _tiempo_resuelto:
		_hachazo()

	queue_redraw()


func _hachazo() -> void:
	if _pos <= TRONCO and _pos + _ancho >= TRONCO:
		_tiempo_resuelto = true
		_progreso += 1
		_ultimo = "¡Hachazo limpio!"
		_vel *= TEMPO_SUBE   # le has cogido el ritmo: el compas se acelera
		if _progreso >= _hachazos:
			_terminar()
	else:
		_fallar("Golpe a destiempo: astillas la madera")


func _fallar(txt: String) -> void:
	_tiempo_resuelto = true
	_astillas += 1
	_ultimo = txt
	# Cada astilla te encoge la ventana: el siguiente tiempo es mas dificil que el anterior.
	_ancho = maxf(VENTANA_MIN, _ancho * VENTANA_ENCOGE)
	if _astillas >= ASTILLAS_ROTO:
		_terminar()


func _nueva_vuelta() -> void:
	# Entra por la izquierda del todo (fuera de la banda): asi la ves venir y puedes anticipar
	# el golpe, que es de lo que va esto.
	_pos = -_ancho
	_tiempo_resuelto = false


func _terminar() -> void:
	_state = FINISHED
	var item := MaterialItem.new()
	item.data = _material
	if _astillas >= ASTILLAS_ROTO:
		item.calidad = MaterialItem.Calidad.ROTO
	elif _astillas == 0:
		item.calidad = MaterialItem.Calidad.INTACTO
	elif _astillas == 1:
		item.calidad = MaterialItem.Calidad.NORMAL
	else:
		item.calidad = MaterialItem.Calidad.DANADO
	_result = item
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(0, 0, w, h), Color(0.09, 0.08, 0.06, 1.0))

	var font: Font = ThemeDB.fallback_font
	var nombre: String = _material.nombre if _material != null else "Madera"

	var bar_w: float = w * 0.6
	var bar_h: float = 40.0
	var bar_x: float = (w - bar_w) / 2.0
	var bar_y: float = h * 0.5

	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.19, 0.16, 0.13))

	if _state == RUNNING:
		# La VENTANA: lo unico que se mueve. Se dibuja recortada a la banda.
		var vx: float = bar_x + maxf(_pos, 0.0) * bar_w
		var vfin: float = bar_x + minf(_pos + _ancho, 1.0) * bar_w
		if vfin > vx:
			draw_rect(Rect2(vx, bar_y, vfin - vx, bar_h), Color(0.85, 0.62, 0.25, 0.85))

	# El TRONCO: fijo, en el centro. Se dibuja SIEMPRE (es la referencia).
	var tx: float = bar_x + TRONCO * bar_w
	draw_rect(Rect2(tx - 3.0, bar_y - 12.0, 6.0, bar_h + 24.0), Color(0.95, 0.95, 0.9))

	draw_string(font, Vector2(bar_x, bar_y - 76.0), "Talando: %s" % nombre,
		HORIZONTAL_ALIGNMENT_CENTER, bar_w, 22)
	if _state == RUNNING:
		draw_string(font, Vector2(bar_x, bar_y - 50.0),
			"ESPACIO cuando la franja pase por el tronco  ·  un hachazo por pasada",
			HORIZONTAL_ALIGNMENT_CENTER, bar_w, 16)
		draw_string(font, Vector2(bar_x, bar_y + bar_h + 30.0),
			"Hachazos: %d/%d   ·   Astillas: %d/%d   ·   %s" % [
				_progreso, _hachazos, _astillas, ASTILLAS_ROTO, _ultimo],
			HORIZONTAL_ALIGNMENT_CENTER, bar_w, 16)
	else:
		var txt: String = "El tronco se raja: no sacas nada" if _result.se_pierde() \
			else "Sacas %s (%s)" % [nombre, _result.calidad_texto()]
		draw_string(font, Vector2(bar_x, bar_y + bar_h + 30.0),
			txt + "   ·   ESPACIO para continuar", HORIZONTAL_ALIGNMENT_CENTER, bar_w, 16)
