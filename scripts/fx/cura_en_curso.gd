# ============================================================
#  cura_en_curso.gd
#  UNA CURA EN EL MAPA, mientras se esta curando: la espiral verde subiendo por el muñeco (EspiralCura),
#  el «+N» flotando encima y, si se le da una ficha, la VIDA SUBIENDO POCO A POCO lo que dura el efecto
#  en vez de entrar de golpe (decision del usuario, 21/09/2026).
#
#  Va colgado del CUERPO que se cura (el jugador, un compañero del sequito o el avatar de otro), asi que
#  le sigue si anda. La espiral va en DOS nodos con z absoluto: uno por debajo del muñeco y otro por
#  encima, que es lo que hace que la linea pase por detras y por delante del personaje.
#
#  Sin ficha ('pj' null) es solo el dibujo: lo que ve quien lanza sobre los cuerpos de OTRO jugador,
#  cuya vida se cura en la maquina de su dueño.
# ============================================================
extends Node2D
class_name CuraEnCurso

const DURACION := 1.4
const ALTO := 64.0      # algo mas que el muñeco (PoseJugador.ALTO_MUNDO): la espiral le pasa la cabeza
const RADIO := 17.0

var _pj: PersonajeData = null
var _por_curar: float = 0.0   # lo que le queda por subir a la ficha
var _numero: float = 0.0
var _t: float = 0.0
var _semilla: float = 0.0
var _detras: Node2D = null
var _delante: Node2D = null


# Arranca una cura sobre 'cuerpo'. 'real' = lo que sube la ficha (ya recortado por el maximo y por la
# Herida profunda); 'numero' = lo que se enseña, que es lo que cura el hechizo aunque pase del maximo.
static func lanzar(cuerpo: Node2D, pj: PersonajeData, real: float, numero: float) -> CuraEnCurso:
	if cuerpo == null or not is_instance_valid(cuerpo):
		return null
	var c := CuraEnCurso.new()
	c._pj = pj
	c._por_curar = maxf(real, 0.0)
	c._numero = numero
	c._semilla = randf() * 100.0
	cuerpo.add_child(c)
	return c


func _ready() -> void:
	_detras = _capa(Game.Z_PERSONAJES - 8, EspiralCura.Pase.DETRAS)
	_delante = _capa(Game.Z_PERSONAJES + 2600, EspiralCura.Pase.DELANTE)


func _capa(z: int, pase: int) -> Node2D:
	var n := Node2D.new()
	n.z_as_relative = false
	n.z_index = z
	add_child(n)
	n.draw.connect(func() -> void:
		var w: float = clampf(_t / DURACION, 0.0, 1.0)
		EspiralCura.pintar(n, Vector2.ZERO, ALTO, RADIO, w, _semilla, pase)
		if pase == EspiralCura.Pase.DELANTE:
			_pintar_numero(n, w))
	return n


func _process(delta: float) -> void:
	var antes: float = _t
	_t += delta
	# LA VIDA SUBE AL RITMO DE LA ESPIRAL. Si se abre una pelea a mitad, lo que faltaba entra de golpe
	# ANTES de que el combate lea la ficha... o se perderia: la pelea escribe su vida al terminar.
	if _pj != null and _por_curar > 0.0:
		var parte: float = _por_curar if (_t >= DURACION or Game.combate_activo()) \
			else _por_curar * (_t - antes) / maxf(DURACION - antes, 0.001)
		_pj.current_hp = minf(Game.player_max_hp(_pj), Game.player_hp(_pj) + parte)
		_por_curar -= parte
	if is_instance_valid(_detras):
		_detras.queue_redraw()
	if is_instance_valid(_delante):
		_delante.queue_redraw()
	if _t >= DURACION + 0.35:
		queue_free()


# EL «+N»: sube un poco y se apaga. Lo que cura el hechizo ENTERO, aunque pase del maximo.
func _pintar_numero(ci: CanvasItem, w: float) -> void:
	if _numero <= 0.0:
		return
	var u: float = clampf(_t / (DURACION + 0.35), 0.0, 1.0)
	var a: float = clampf((1.0 - u) / 0.3, 0.0, 1.0) * clampf(u / 0.06, 0.0, 1.0)
	var f: Font = ThemeDB.fallback_font
	var txt: String = "+%d" % roundi(_numero)
	var tam: int = 14
	var ancho: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var p := Vector2(-ancho * 0.5, -ALTO - 6.0 - 16.0 * u)
	ci.draw_string_outline(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 4, Color(0, 0, 0, 0.85 * a))
	ci.draw_string(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam,
		Color(EspiralCura.VERDE.r, EspiralCura.VERDE.g, EspiralCura.VERDE.b, a))
