# ============================================================
#  harvest.gd
#  Minijuego de HERBORISTERIA (planta -> hoz -> DESTREZA). Ni carga ni marcador que
#  rebota: aqui hay PULSO. Cada tallo pasa UNA vez y no vuelve.
#
#  Por cada tallo, un marcador cruza la banda de un lado al otro, UNA SOLA pasada. En
#  medio hay una linea de corte con dos anillos:
#    - NUCLEO (fino)  -> CORTE LIMPIO: la pieza sale entera.
#    - BORDE          -> corte sucio: magullas la planta (+1 destrozo).
#    - Fuera, o dejar pasar el marcador sin pulsar -> TALLO DESTROZADO (+2) y la planta
#      se agita: los tallos que quedan pasan mas rapido.
#  No hay segunda oportunidad por tallo: si fallas, fallaste. Eso es lo que lo hace fino
#  y no un machaque de espacio como el del cristal.
#
#  La DESTREZA ensancha el nucleo y frena la pasada. Se crea por codigo (sin .tscn).
# ============================================================

extends Control

signal recoleccion_finished(item: MaterialItem)

enum { RUNNING, FINISHED }

var _material: MaterialData = null
var _cortes: int = 3
var _nucleo: float = 0.06   # semiancho del corte limpio (fraccion de la banda)
var _borde: float = 0.13    # semiancho del corte sucio
var _vel: float = 0.7       # pasadas por segundo

var _corte_actual: int = 0
var _destrozo: int = 0
var _marker: float = 0.0
var _linea: float = 0.5     # donde esta el corte en esta pasada
var _ultimo: String = ""
var _state: int = RUNNING
var _result: MaterialItem = null
var _press_was: bool = false

# Cuanto se acelera la planta por cada tallo que destrozas (se pone nerviosa).
const AGITACION := 1.15
# Destrozo al que la pieza ya no vale nada.
const DESTROZO_ROTO := 5


func setup(material: MaterialData, cortes: int, nucleo: float, borde: float, vel: float) -> void:
	_material = material
	_cortes = maxi(1, cortes)
	_nucleo = nucleo
	_borde = borde
	_vel = vel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_nuevo_tallo()


func _process(delta: float) -> void:
	var pressed: bool = Input.is_key_pressed(KEY_SPACE)
	var edge: bool = pressed and not _press_was
	_press_was = pressed

	if _state == FINISHED:
		if edge:
			recoleccion_finished.emit(_result)
			queue_free()
		return

	_marker += _vel * delta
	if _marker >= 1.0:
		# El marcador ha cruzado entero y no has pulsado: el tallo se pierde.
		_resolver(-1.0)
		return

	if edge:
		_resolver(_marker)

	queue_redraw()


# d = distancia del marcador a la linea de corte; d < 0 -> ni lo has intentado.
func _resolver(pos: float) -> void:
	if pos < 0.0:
		_fallo("Se te pasa el tallo: lo destrozas")
	else:
		var d: float = absf(pos - _linea)
		if d <= _nucleo:
			_ultimo = "¡Corte limpio!"
		elif d <= _borde:
			_destrozo += 1
			_ultimo = "Corte sucio: magullas la planta"
		else:
			_fallo("Tajo en falso: destrozas el tallo")

	_siguiente()


func _fallo(txt: String) -> void:
	_destrozo += 2
	_ultimo = txt
	_vel *= AGITACION   # la planta se agita: lo que queda va mas rapido


func _siguiente() -> void:
	_corte_actual += 1
	if _destrozo >= DESTROZO_ROTO or _corte_actual >= _cortes:
		_terminar()
		return
	_nuevo_tallo()


func _nuevo_tallo() -> void:
	_marker = 0.0
	# La linea nunca cae pegada al borde de la banda: siempre te da tiempo a reaccionar.
	_linea = randf_range(0.25, 0.85)


func _terminar() -> void:
	_state = FINISHED
	var item := MaterialItem.new()
	item.data = _material
	if _destrozo >= DESTROZO_ROTO:
		item.calidad = MaterialItem.Calidad.ROTO
	elif _destrozo == 0:
		item.calidad = MaterialItem.Calidad.INTACTO
	elif _destrozo <= 2:
		item.calidad = MaterialItem.Calidad.NORMAL
	else:
		item.calidad = MaterialItem.Calidad.DANADO
	_result = item
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(0, 0, w, h), Color(0.07, 0.11, 0.08, 1.0))

	var font: Font = ThemeDB.fallback_font
	var nombre: String = _material.nombre if _material != null else "Planta"

	var bar_w: float = w * 0.6
	var bar_h: float = 26.0
	var bar_x: float = (w - bar_w) / 2.0
	var bar_y: float = h * 0.5

	# Banda del tallo.
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.2, 0.26, 0.2))
	if _state == RUNNING:
		# Borde (corte sucio) y nucleo (corte limpio): dos anillos concentricos.
		draw_rect(Rect2(bar_x + (_linea - _borde) * bar_w, bar_y, 2.0 * _borde * bar_w, bar_h),
			Color(0.55, 0.75, 0.35, 0.55))
		draw_rect(Rect2(bar_x + (_linea - _nucleo) * bar_w, bar_y, 2.0 * _nucleo * bar_w, bar_h),
			Color(0.65, 1.0, 0.45))
		# La linea de corte, fina, en el centro exacto.
		draw_rect(Rect2(bar_x + _linea * bar_w - 1.0, bar_y - 6.0, 2.0, bar_h + 12.0),
			Color(1.0, 1.0, 1.0, 0.5))
		# El marcador: una hoja que baja por el tallo, de una pasada.
		var mx: float = bar_x + _marker * bar_w
		draw_rect(Rect2(mx - 2.0, bar_y - 12.0, 4.0, bar_h + 24.0), Color(0.95, 0.95, 0.8))

	draw_string(font, Vector2(bar_x, bar_y - 76.0), "Recolectando: %s" % nombre,
		HORIZONTAL_ALIGNMENT_CENTER, bar_w, 22)
	if _state == RUNNING:
		draw_string(font, Vector2(bar_x, bar_y - 50.0),
			"Tallo %d/%d   ·   ESPACIO justo en la línea (una sola pasada)" % [
				_corte_actual + 1, _cortes],
			HORIZONTAL_ALIGNMENT_CENTER, bar_w, 16)
		draw_string(font, Vector2(bar_x, bar_y + bar_h + 28.0),
			"Destrozo: %d/%d   ·   %s" % [_destrozo, DESTROZO_ROTO, _ultimo],
			HORIZONTAL_ALIGNMENT_CENTER, bar_w, 16)
	else:
		var txt: String = "La planta queda hecha jirones: no sirve" if _result.se_pierde() \
			else "Recoges %s (%s)" % [nombre, _result.calidad_texto()]
		draw_string(font, Vector2(bar_x, bar_y + bar_h + 28.0),
			txt + "   ·   ESPACIO para continuar", HORIZONTAL_ALIGNMENT_CENTER, bar_w, 16)
