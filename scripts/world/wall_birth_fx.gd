# ============================================================
#  wall_birth_fx.gd
#  El AVISO de la pared: antes de parir, la celda de roca late y tiembla. Es la unica
#  advertencia que tienes -por eso existe: un bicho que aparece de la nada, sin aviso,
#  es una emboscada barata; con aviso, decides si te quedas o te largas.
#  Cuanto mas gordo es el parto (un brote), mas fuerte tiembla y mas se avisa.
#  Aspecto placeholder por codigo; el arte va al final.
# ============================================================

extends Node2D

var _rect: ColorRect = null
var _dur: float = 1.2      # cuanto dura el aviso
var _t: float = 0.0        # tiempo transcurrido
var _amp: float = 2.5      # amplitud del temblor (px)
var _origen: Vector2 = Vector2.ZERO
var _color: Color = Color(0.85, 0.35, 0.30)


# lado = tamaño de la celda; dur = aviso; amp = temblor. El brote sube dur y amp.
func iniciar(lado: float, dur: float, amp: float, color: Color) -> void:
	_dur = maxf(0.05, dur)
	_amp = amp
	_color = color
	_origen = position

	_rect = ColorRect.new()
	_rect.offset_left = -lado * 0.5
	_rect.offset_top = -lado * 0.5
	_rect.offset_right = lado * 0.5
	_rect.offset_bottom = lado * 0.5
	_rect.color = _color
	add_child(_rect)


func _process(delta: float) -> void:
	if _rect == null:
		return
	_t += delta
	var p: float = clampf(_t / _dur, 0.0, 1.0)

	# Late cada vez mas rapido segun se acerca el parto (de ~2 a ~9 latidos/s).
	var freq: float = lerpf(2.0, 9.0, p)
	var latido: float = 0.5 + 0.5 * sin(_t * freq * TAU)
	_rect.color = Color(_color.r, _color.g, _color.b, lerpf(0.15, 0.9, latido * p))

	# Y tiembla mas fuerte al final.
	var amp: float = _amp * p
	position = _origen + Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
