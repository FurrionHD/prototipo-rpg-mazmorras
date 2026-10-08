# ============================================================
#  slime_burbuja.gd  (class_name SlimeBurbuja)
#  LAS BURBUJAS FLOTANTES del slime pestilente (06/10, idea del jefe: "lanza entre 2/4 burbujas aleatoriamente sin cargar
#  ni nada a posiciones aleatorias alrededor de el... se quedan flotando en el sitio; si la atraviesas explota y te hace
#  daño, si no explota aleatoriamente entre 1 y 3 turnos").
#  Una burbuja de su gel, translucida, con gas verde removiendose dentro y su brillo, flotando a media altura sobre su
#  sombra. Sale volando de sus pies hasta su sitio (en arco, creciendo). Cuanto menos le queda, MAS TIEMBLA (se ve venir
#  que va a reventar). secar() = REVIENTA: destello, gotas de gel hacia fuera y una bocanada de gas que se abre.
#  La pinta CombatTactico._charco_visible (charco_estilo 6) y la columna de ver_ataques_dirs.
# ============================================================
extends Node2D
class_name SlimeBurbuja

const T_VUELO := 0.4
const T_REVIENTA := 0.55
const ALTO := 14.0            # a que altura flota (px sobre el suelo)

var queda: float = 1.0        # lo que le queda (1 = recien soltada); con poco, tiembla
var _t: float = 0.0
var _secando: float = -1.0
var _col: Color = Color(0.29, 0.78, 0.33)
var _desde: Vector2 = Vector2.ZERO
var _en: Vector2 = Vector2.ZERO
var _r: float = 22.0
var _fase: float = 0.0
var _remolinos: Array = []    # {a, d, r, vel}: el gas de dentro
var _gotas: Array = []        # {dir, vel, r}: las del reventon
var _rng := RandomNumberGenerator.new()
var _suelo: Node2D = null
var _delante: Node2D = null


# 'f' = su circulo (centro = donde flota, radio = su tamaño); f.origen = de donde sale volando (los pies del slime).
static func crear(padre: Node, f, col: Color, semilla: int) -> SlimeBurbuja:
	if padre == null or f == null:
		return null
	var b := SlimeBurbuja.new()
	b._rng.seed = hash(semilla)
	b._col = col
	b._en = f.centro
	b._desde = f.origen if f.origen != Vector2.ZERO else f.centro
	b._r = maxf(f.radio, 6.0)
	b._fase = b._rng.randf_range(0.0, TAU)
	for i in 4:
		b._remolinos.append({"a": b._rng.randf_range(0.0, TAU), "d": b._rng.randf_range(0.15, 0.5),
			"r": b._rng.randf_range(0.22, 0.38), "vel": b._rng.randf_range(0.6, 1.4) * (1.0 if i % 2 == 0 else -1.0)})
	for i in 12:
		b._gotas.append({"dir": Vector2.RIGHT.rotated(TAU * float(i) / 12.0 + b._rng.randf_range(-0.2, 0.2)),
			"vel": b._rng.randf_range(0.8, 1.3), "r": b._rng.randf_range(1.2, 2.4)})
	b.z_as_relative = false
	b.z_index = SimaAire.Z_ENCIMA
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(b)
	b._suelo = b._capa(SueloRoto.Z_SUELO)
	b._delante = b._capa(SimaAire.Z_ENCIMA)
	return b


func _capa(z: int) -> Node2D:
	var c := Node2D.new()
	c.z_as_relative = false
	c.z_index = z
	c.draw.connect(_pintar.bind(c))
	add_child(c)
	return c


func _process(delta: float) -> void:
	_t += delta
	if _secando >= 0.0 and _t - _secando > T_REVIENTA:
		queue_free()
		return
	_suelo.queue_redraw()
	_delante.queue_redraw()


func secar() -> void:
	if _secando < 0.0:
		_secando = maxf(_t, T_VUELO)


# Donde esta ahora (su centro en el aire) y lo grande que es.
func _sitio() -> Array:
	var u: float = clampf(_t / T_VUELO, 0.0, 1.0)
	var suave: float = 1.0 - (1.0 - u) * (1.0 - u)
	var suelo: Vector2 = _desde.lerp(_en, suave)
	# En arco, saliendo de su cuerpo y bajando a su altura de flotar.
	var alto: float = lerpf(10.0, ALTO, suave) + sin(PI * u) * 22.0
	var flota: float = sin(_t * 2.2 + _fase) * 1.5 if u >= 1.0 else 0.0
	var r: float = _r * lerpf(0.3, 1.0, suave)
	# El TEMBLOR de cuando le queda poco: se deforma y vibra.
	var tiembla: float = clampf((0.5 - queda) * 2.0, 0.0, 1.0) if u >= 1.0 else 0.0
	return [suelo, suelo - Vector2(0.0, alto + flota), r, tiembla]


func _pintar(capa: Node2D) -> void:
	var s: Array = _sitio()
	var suelo: Vector2 = s[0]
	var c: Vector2 = s[1]
	var r: float = s[2]
	var tiembla: float = s[3]
	if _secando >= 0.0:
		_reventar(capa, c, r, suelo)
		return
	if capa == _suelo:
		# SU SOMBRA en el suelo (lo unico que dice a que altura flota).
		BestiaAire._bola(capa, suelo, r * 0.75, Color(0.0, 0.0, 0.0, 0.22))
		return
	var vib := Vector2(sin(_t * 41.0), cos(_t * 37.0)) * 1.2 * tiembla
	c += vib
	# Se estira y encoge un poco (gel blando); temblando, mas.
	var ondea: float = 1.0 + sin(_t * 3.1 + _fase) * (0.04 + 0.08 * tiembla)
	var rx: float = r * ondea
	var ry: float = r / ondea
	var osc: Color = _col.darkened(0.45)
	var cla: Color = _col.lightened(0.45)
	# EL BORDE de gel, mas espeso (opaco) y el cuerpo translucido.
	_elipse(capa, c, rx + 1.2, ry + 1.2, Color(osc, 0.9))
	_elipse(capa, c, rx, ry, Color(_col.lightened(0.15), 0.55))
	_elipse(capa, c + Vector2(0.0, ry * 0.12), rx * 0.86, ry * 0.8, Color(cla, 0.30))
	# EL GAS de dentro, removiendose.
	for g in _remolinos:
		var a: float = float(g["a"]) + _t * float(g["vel"])
		var p: Vector2 = c + Vector2(cos(a), sin(a) * 0.8) * r * float(g["d"])
		BestiaAire._bola(capa, p, r * float(g["r"]), Color(_col.darkened(0.15), 0.40))
		BestiaAire._bola(capa, p - Vector2(0.6, 0.8), r * float(g["r"]) * 0.5, Color(cla, 0.35))
	# EL BRILLO: una media luna clara arriba a la izquierda y un punto.
	_elipse(capa, c + Vector2(-rx * 0.38, -ry * 0.42), rx * 0.28, ry * 0.16, Color(1.0, 1.0, 0.95, 0.75))
	capa.draw_circle(c + Vector2(rx * 0.32, -ry * 0.5), maxf(r * 0.07, 1.0), Color(1.0, 1.0, 1.0, 0.85))
	# Y el reflejo de abajo, mas tenue.
	_elipse(capa, c + Vector2(rx * 0.2, ry * 0.55), rx * 0.3, ry * 0.08, Color(cla, 0.45))


# REVIENTA: un destello, las gotas de gel hacia fuera (caen) y una bocanada de gas que se abre y se va.
func _reventar(capa: Node2D, c: Vector2, r: float, suelo: Vector2) -> void:
	var k: float = clampf((_t - _secando) / T_REVIENTA, 0.0, 1.0)
	if capa == _suelo:
		# Las gotas que caen al suelo, alrededor.
		for g in _gotas:
			var p: Vector2 = suelo + (g["dir"] as Vector2) * r * (0.6 + 0.9 * k) * float(g["vel"]) * Vector2(1.0, 0.6)
			BestiaAire._bola(capa, p, float(g["r"]) * (0.6 + 0.4 * k), Color(_col.darkened(0.2), 0.7 * (1.0 - k)))
		return
	if k < 0.18:
		BestiaAire._bola(capa, c, r * (1.0 + 0.5 * k / 0.18), Color(1.0, 1.0, 0.9, 0.6 * (1.0 - k / 0.18)))
	# El gas que se abre.
	for i in 7:
		var a: float = TAU * float(i) / 7.0 + _fase
		var p: Vector2 = c + Vector2(cos(a), sin(a) * 0.7) * r * (0.3 + 0.9 * k) - Vector2(0.0, 6.0 * k)
		var rr: float = r * (0.35 + 0.25 * k)
		BestiaAire._bola(capa, p, rr, Color(_col.darkened(0.1), 0.55 * (1.0 - k)))
		BestiaAire._bola(capa, p - Vector2(1.0, 1.4), rr * 0.5, Color(_col.lightened(0.4), 0.45 * (1.0 - k)))
	# Las gotas por el aire, saliendo y cayendo.
	for g in _gotas:
		var d: Vector2 = (g["dir"] as Vector2) * r * (0.9 + 1.4 * k) * float(g["vel"])
		var p2: Vector2 = c + d + Vector2(0.0, 30.0 * k * k)
		capa.draw_circle(p2, float(g["r"]), Color(_col.lightened(0.1), 0.9 * (1.0 - k)))


static func _elipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	if rx <= 0.3 or col.a <= 0.01:
		return
	var n: int = 24
	var pv := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		pv.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	Poligono.relleno(ci, pv, col)
