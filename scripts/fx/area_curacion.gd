# ============================================================
#  area_curacion.gd
#  EL AREA DE UNA CURA DE GRUPO en el mapa (decision del usuario, 21/09/2026):
#   - CIRCULO: mientras recitas, un circulo verde en el suelo alrededor del que lanza con cruces que
#     nacen del suelo, suben y se difuminan. Es la referencia de hasta donde llega: quien este dentro
#     al soltarla se cura. Lo ven todos los jugadores (Net.jugadores.anunciar_fx_cura).
#   - ONDA: al soltarla, un anillo que sale del que lanza hacia fuera. A cada uno le cura cuando le
#     alcanza (ver player._curar_en_area, que usa T_ONDA para el retraso de cada uno).
#
#  Va colgado del cuerpo del que lanza (le sigue) y pinta con z absoluto BAJO: esto esta en el suelo,
#  y los personajes tienen que verse por encima.
# ============================================================
extends Node2D
class_name AreaCuracion

const T_ONDA := 0.55          # lo que tarda la onda en llegar al borde
const T_APAGAR := 0.35
const CRUCES := 16
const Z_SUELO := 2            # por encima del suelo del piso, por debajo de los cuerpos (Game.Z_PERSONAJES)

var _radio: float = SpellData.RADIO_CURA_AREA
var _onda: bool = false
var _t: float = 0.0
var _apagando: float = -1.0   # >= 0 = el circulo se esta yendo


# El circulo de mientras recitas. Se quita con apagar().
static func circulo(cuerpo: Node2D) -> AreaCuracion:
	return _nuevo(cuerpo, false)


# La onda de soltarla: se va sola al llegar al borde.
static func onda(cuerpo: Node2D) -> AreaCuracion:
	return _nuevo(cuerpo, true)


static func _nuevo(cuerpo: Node2D, es_onda: bool) -> AreaCuracion:
	if cuerpo == null or not is_instance_valid(cuerpo):
		return null
	var a := AreaCuracion.new()
	a._onda = es_onda
	a.z_as_relative = false
	a.z_index = Z_SUELO
	cuerpo.add_child(a)
	return a


func apagar() -> void:
	if _apagando < 0.0:
		_apagando = 0.0


func _process(delta: float) -> void:
	_t += delta
	if _apagando >= 0.0:
		_apagando += delta
		if _apagando >= T_APAGAR:
			queue_free()
	if _onda and _t >= T_ONDA + 0.25:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var verde := EspiralCura.VERDE
	if _onda:
		# El anillo sale de los pies y se abre hasta el borde; al llegar se desvanece.
		var u: float = clampf(_t / T_ONDA, 0.0, 1.0)
		var fin: float = clampf((_t - T_ONDA) / 0.25, 0.0, 1.0)
		var r: float = _radio * (1.0 - pow(1.0 - u, 2.0))
		var a: float = (1.0 - fin) * 0.9
		draw_circle(Vector2.ZERO, r, Color(verde.r, verde.g, verde.b, 0.10 * a))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(verde.r, verde.g, verde.b, 0.35 * a), 12.0)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(0.85, 1.0, 0.88, a), 3.0)
		return
	# EL CIRCULO: aparece en un momento y late despacio, para que se lea como "algo esta pasando" y no
	# como una marca pintada en el suelo.
	var sale: float = clampf(_t / 0.3, 0.0, 1.0)
	var vida: float = sale * (1.0 - clampf(_apagando / T_APAGAR, 0.0, 1.0) if _apagando >= 0.0 else sale)
	var late: float = 0.5 + 0.5 * sin(_t * 3.0)
	draw_circle(Vector2.ZERO, _radio, Color(verde.r, verde.g, verde.b, (0.07 + 0.03 * late) * vida))
	draw_arc(Vector2.ZERO, _radio, 0.0, TAU, 128, Color(verde.r, verde.g, verde.b, 0.65 * vida), 3.0)
	# LAS CRUCES: cada una nace en un punto del circulo, sube y se apaga, y vuelve a nacer en otro sitio.
	for i in CRUCES:
		var ciclo: float = 1.6 + 0.6 * _h(i, 1.0)
		var fase: float = fmod(_t + _h(i, 2.0) * ciclo, ciclo) / ciclo
		var vuelta: float = floor((_t + _h(i, 2.0) * ciclo) / ciclo)
		var ang: float = TAU * _h(i, 3.0 + vuelta)
		var dist: float = _radio * sqrt(_h(i, 4.0 + vuelta)) * 0.95
		var p := Vector2(cos(ang), sin(ang)) * dist + Vector2(0.0, -26.0 * fase)
		var a2: float = sin(fase * PI) * vida
		var t: float = 3.0 + 2.0 * _h(i, 5.0)
		var col := Color(verde.r, verde.g, verde.b, 0.9 * a2)
		draw_line(p - Vector2(t, 0), p + Vector2(t, 0), col, 2.0)
		draw_line(p - Vector2(0, t), p + Vector2(0, t), col, 2.0)


# Un "aleatorio" fijo por cruz y por vuelta: cada cruz renace en otro sitio, pero sin sortear cada frame.
func _h(i: int, k: float) -> float:
	return fmod(absf(sin(float(i) * 12.9898 + k * 78.233) * 43758.5453), 1.0)
