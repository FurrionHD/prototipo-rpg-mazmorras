# ============================================================
#  wall_birth_fx.gd
#  El AVISO de la pared: antes de parir, la celda de roca late y tiembla. Es la unica
#  advertencia que tienes -por eso existe: un bicho que aparece de la nada, sin aviso,
#  es una emboscada barata; con aviso, decides si te quedas o te largas.
#  Cuanto mas gordo es el parto (un brote), mas fuerte tiembla y mas se avisa.
#  Aspecto placeholder por codigo; el arte va al final.
# ============================================================

extends Node2D

var _rects: Array[ColorRect] = []
var _dur: float = 1.2      # cuanto dura el aviso
var _t: float = 0.0        # tiempo transcurrido
var _amp: float = 2.5      # amplitud del temblor (px)
var _origen: Vector2 = Vector2.ZERO
var _color: Color = Color(0.85, 0.35, 0.30)


# UN parto normal: una sola celda. lado = tamaño de celda; dur = aviso; amp = temblor.
func iniciar(lado: float, dur: float, amp: float, color: Color) -> void:
	iniciar_tramo(lado, dur, amp, color, [position])


# UN BROTE: un TRAMO de pared (varias celdas) que late y tiembla EN BLOQUE. 'paredes' son los
# centros (en mundo) de cada celda de roca que se va a abrir. Todas comparten _t y _origen, asi que
# laten y tiemblan a la vez: se lee como que ese cacho de muro entero se va a caer, no como varios
# avisos sueltos. El nodo se coloca en la primera y las demas se pintan como hijos a su offset.
func iniciar_tramo(lado: float, dur: float, amp: float, color: Color, paredes: Array) -> void:
	_dur = maxf(0.05, dur)
	_amp = amp
	_color = color
	_origen = position
	for centro in paredes:
		var r := ColorRect.new()
		var local: Vector2 = (centro as Vector2) - position   # a coordenadas del nodo
		r.offset_left = local.x - lado * 0.5
		r.offset_top = local.y - lado * 0.5
		r.offset_right = local.x + lado * 0.5
		r.offset_bottom = local.y + lado * 0.5
		r.color = _color
		add_child(r)
		_rects.append(r)


func _process(delta: float) -> void:
	if _rects.is_empty():
		return
	_t += delta
	var p: float = clampf(_t / _dur, 0.0, 1.0)

	# Late cada vez mas rapido segun se acerca el parto (de ~2 a ~9 latidos/s).
	var freq: float = lerpf(2.0, 9.0, p)
	var latido: float = 0.5 + 0.5 * sin(_t * freq * TAU)
	var col := Color(_color.r, _color.g, _color.b, lerpf(0.15, 0.9, latido * p))
	for r in _rects:
		r.color = col

	# Y tiembla mas fuerte al final (todo el tramo a una).
	var amp: float = _amp * p
	position = _origen + Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
