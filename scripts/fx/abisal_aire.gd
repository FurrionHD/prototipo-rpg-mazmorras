# ============================================================
#  abisal_aire.gd  (class_name AbisalAire)
#  LOS EFECTOS DE LOS MUTANTES DEL SLIME ABISAL en el mapa (06/10/2026: el slime de cielo nocturno y el de mil ojos).
#  Las ESTRELLAS y los RAYOS son LUZ (blanco azulado, con destellos de cuatro puntas); la oscuridad (el Eclipse y el
#  Agujero negro) va con el lenguaje de la Voragine y la reutiliza tal cual (MagiaMayor, ver SueloRoto.lanzar).
#  POR EL SUELO (SueloRoto.Tipo.ABISAL_*):
#    LLUVIA     Lluvia de estrellas: en cada punto del circulo (puntos_lluvia) primero se enciende su marca en el suelo
#               y crece; una ESTRELLA FUGAZ baja del cielo en diagonal con su cola y cae ahi, una tras otra: destello de
#               cuatro puntas, anillo de luz que se abre por el suelo y motas que suben.
#    RAYO       un rayo de la Constelacion: de una estrella a la siguiente. Se TRAZA de un extremo al otro (fino), se
#               ENCIENDE (nucleo blanco y halo azul) y se apaga; en cada punta un destello.
#    MIRADA     un rayo de la Mirada estelar: igual pero gordo, con los bordes cian y magenta (los iris de sus ojos).
#    PARPADEO   el Parpadeo cegador: un FOGONAZO de luz en abanico que sale de el por el cono, con rayos y motas.
#  SOBRE EL SUELO, quieta mientras dure la pelea:
#    EstrellaSuelo (estrella()) la estrella que deja al moverse: una estrella pequeña de cuatro puntas flotando un pelo
#               sobre el suelo, que titila, con su resplandor en el suelo. secar() = se apaga en un destello.
#  Coordenadas de MUNDO; el suelo sin achatar; lo que va en el aire, a su altura por K. Todo sale de la forma y la semilla.
# ============================================================
extends Node2D
class_name AbisalAire

enum Modo { LLUVIA, RAYO, MIRADA, PARPADEO, ESTRELLA }

const K := 0.7071
const Z_ENCIMA := Game.Z_PERSONAJES + 80

const BLANCO := Color(1.0, 1.0, 1.0)
const LUZ := Color(0.86, 0.92, 1.0)
const AZUL := Color(0.45, 0.62, 1.0)
const AZUL_HONDO := Color(0.22, 0.28, 0.75)
const CIAN := Color(0.35, 0.95, 1.0)
const MAGENTA := Color(1.0, 0.38, 0.95)

# LA LLUVIA
const FUGACES := 4
const T_MARCA := 0.25          # la marca del suelo se enciende antes de que caiga
const T_ENTRE := 0.16          # entre estrella y estrella
const T_CAE := 0.32            # lo que tarda cada una en bajar
const T_IMPACTO := 0.45        # y lo que dura su destello y su anillo
const R_IMPACTO := 18.0
const CAIDA := Vector2(-70.0, -150.0)   # de donde viene (respecto a donde cae, en el aire)

# LOS RAYOS
const T_TRAZA := 0.14
const T_RAYO := 0.35
const T_APAGA_RAYO := 0.3
const ALTO_RAYO := 9.0          # a que altura van (de pecho a pecho)

# EL PARPADEO
const T_FOGONAZO := 0.22
const T_APAGA_FOGONAZO := 0.4

# LA ESTRELLA DEL SUELO
const ALTO_ESTRELLA := 6.0
const T_APARECE := 0.25
const T_SE_APAGA := 0.35

var modo: int = Modo.LLUVIA
var forma: CombatFormas.Forma = null
var n_fugaces: int = FUGACES
var queda: float = 1.0          # (la estrella del suelo: lo lee _charco_visible; no la cambia)
var _t: float = 0.0
var _ritmo: float = 1.0
var _secando: float = -1.0
var _rng := RandomNumberGenerator.new()
var _puntos: Array = []
var _motas: Array = []
var _fase: float = 0.0
var _suelo: Node2D = null
var _delante: Node2D = null


static func area(padre: Node, f: CombatFormas.Forma, m: int, semilla: int, espera: float, n: int = 0) -> AbisalAire:
	if padre == null or f == null:
		return null
	var e := AbisalAire.new()
	e.modo = m
	e.forma = f
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	e._t = -espera * e._ritmo
	if m == Modo.LLUVIA:
		e.n_fugaces = n if n > 0 else (f.tramos if f.tramos > 0 else FUGACES)
		e._puntos = puntos_lluvia(f, e.n_fugaces)
	e._preparar()
	e._montar(padre)
	return e


# LA ESTRELLA QUE DEJA AL MOVERSE (charco_estilo 8, ver CombatTactico.poner_estrella): 'f' = su circulito.
static func estrella(padre: Node, f, semilla: int) -> AbisalAire:
	if padre == null or f == null:
		return null
	var e := AbisalAire.new()
	e.modo = Modo.ESTRELLA
	e.forma = f
	e._rng.seed = hash(semilla)
	e._preparar()
	e._montar(padre)
	return e


func _montar(padre: Node) -> void:
	z_as_relative = false
	z_index = SueloRoto.Z_SUELO
	process_mode = Node.PROCESS_MODE_ALWAYS   # la pelea tactica pausa el arbol
	padre.add_child(self)
	_suelo = _capa(SueloRoto.Z_SUELO)
	_delante = _capa(Z_ENCIMA)


func _capa(z: int) -> Node2D:
	var c := Node2D.new()
	c.z_as_relative = false
	c.z_index = z
	c.draw.connect(_pintar.bind(c))
	add_child(c)
	return c


func _preparar() -> void:
	_fase = _rng.randf_range(0.0, TAU)
	for i in 14:
		_motas.append({"a": _rng.randf_range(0.0, TAU), "d": _rng.randf_range(0.2, 1.0),
			"v": _rng.randf_range(0.6, 1.4), "r": _rng.randf_range(0.7, 1.5)})


# DONDE CAE CADA ESTRELLA dentro del circulo. Sale SOLO de la forma (su centro, su radio y cuantas: f.tramos), asi que
# el combate (a quien le pega) y el dibujo (donde se ve caer) dan lo mismo en todas las maquinas.
static func puntos_lluvia(f: CombatFormas.Forma, n: int = 0) -> Array:
	var out: Array = []
	if f == null:
		return out
	if n <= 0:
		n = f.tramos if f.tramos > 0 else FUGACES
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(roundi(f.centro.x * 16.0), roundi(f.centro.y * 16.0), n))
	var r: float = maxf(f.radio - R_IMPACTO * 0.4, 4.0)
	var intentos: int = 0
	while out.size() < n and intentos < 80:
		intentos += 1
		var a: float = rng.randf_range(0.0, TAU)
		var d: float = r * sqrt(rng.randf())
		var p: Vector2 = f.centro + Vector2(cos(a), sin(a)) * d
		var lejos: bool = true
		for q in out:
			if (q as Vector2).distance_to(p) < R_IMPACTO * 1.1:
				lejos = false
				break
		if lejos or intentos > 60:
			out.append(p)
	return out


# CUANDO LE LLEGA a 'p' (en segundos desde que se lanza).
static func retraso(m: int, f: CombatFormas.Forma, p: Vector2) -> float:
	if f == null:
		return 0.0
	match m:
		Modo.LLUVIA:
			# La estrella que le cae mas cerca.
			var pts: Array = puntos_lluvia(f)
			var mejor: int = 0
			for i in pts.size():
				if (pts[i] as Vector2).distance_to(p) < (pts[mejor] as Vector2).distance_to(p):
					mejor = i
			return T_MARCA + T_ENTRE * float(mejor) + T_CAE
		Modo.RAYO, Modo.MIRADA:
			var u: float = clampf((p - f.origen).dot(f.dir) / maxf(f.largo, 1.0), 0.0, 1.0)
			return T_TRAZA * u
		Modo.PARPADEO:
			return T_FOGONAZO * clampf(p.distance_to(f.origen) / maxf(f.radio, 1.0), 0.0, 1.0)
	return 0.0


static func t_salir(m: int) -> float:
	match m:
		Modo.LLUVIA: return T_MARCA + T_CAE
		Modo.RAYO, Modo.MIRADA: return T_TRAZA
		Modo.PARPADEO: return T_FOGONAZO
	return 0.2


func duracion() -> float:
	match modo:
		Modo.LLUVIA: return T_MARCA + T_ENTRE * float(maxi(n_fugaces - 1, 0)) + T_CAE + T_IMPACTO + 0.2
		Modo.RAYO, Modo.MIRADA: return T_TRAZA + T_RAYO + T_APAGA_RAYO
		Modo.PARPADEO: return T_FOGONAZO + T_APAGA_FOGONAZO
	return INF


func secar() -> void:
	if _secando < 0.0:
		_secando = _t


func _process(delta: float) -> void:
	_t += delta * (_ritmo if modo != Modo.ESTRELLA else 1.0)
	if _t >= duracion() or (_secando >= 0.0 and _t - _secando > T_SE_APAGA):
		queue_free()
		return
	_suelo.queue_redraw()
	_delante.queue_redraw()


func _pintar(capa: Node2D) -> void:
	if _t < 0.0:
		return
	match modo:
		Modo.LLUVIA: _lluvia(capa)
		Modo.RAYO: _rayo(capa, false)
		Modo.MIRADA: _rayo(capa, true)
		Modo.PARPADEO: _parpadeo(capa)
		Modo.ESTRELLA: _estrella(capa)


# ------------------------------------------------------------
#  LA LLUVIA DE ESTRELLAS
# ------------------------------------------------------------
func _lluvia(capa: Node2D) -> void:
	for i in _puntos.size():
		var p: Vector2 = _puntos[i]
		var t_cae: float = T_MARCA + T_ENTRE * float(i)
		var u_marca: float = clampf(_t / (t_cae + T_CAE), 0.0, 1.0)
		var tras: float = _t - (t_cae + T_CAE)   # desde que toco el suelo
		if capa == _suelo:
			# LA MARCA en el suelo: un circulo de luz que se enciende y se aprieta hasta que cae (se ve venir).
			if tras < 0.0:
				MagiaAire._anillo(capa, p, R_IMPACTO * lerpf(1.3, 0.75, u_marca), 1.6, Color(LUZ, 0.25 + 0.5 * u_marca))
				BarridoAire.brillo(capa, p, R_IMPACTO * 0.8 * u_marca, Color(AZUL, 0.25 * u_marca))
			elif tras < T_IMPACTO:
				var k: float = tras / T_IMPACTO
				# EL ANILLO de luz que se abre por el suelo y el resplandor que se apaga.
				BarridoAire.brillo(capa, p, R_IMPACTO * (1.2 + 0.6 * k), Color(LUZ, 0.55 * (1.0 - k)))
				MagiaAire._anillo(capa, p, R_IMPACTO * (0.4 + 1.1 * k), 2.6 * (1.0 - k) + 0.6, Color(BLANCO, 0.9 * (1.0 - k)))
			continue
		# EN EL AIRE: la estrella que baja con su cola, y al tocar el destello y las motas.
		if tras < 0.0 and _t >= t_cae:
			var u: float = clampf((_t - t_cae) / T_CAE, 0.0, 1.0)
			var cae: float = u * u
			var cabeza: Vector2 = p + CAIDA * (1.0 - cae) * Vector2(1.0, K)
			var cola: Vector2 = p + CAIDA * (1.0 - maxf(cae - 0.35, 0.0)) * Vector2(1.0, K)
			_cola(capa, cola, cabeza, 3.2)
			BarridoAire.destello(capa, cabeza, 7.0, Color(LUZ, 1.0), _t * 3.0)
		elif tras >= 0.0 and tras < T_IMPACTO:
			var k2: float = tras / T_IMPACTO
			BarridoAire.destello(capa, p - Vector2(0.0, 3.0), lerpf(16.0, 6.0, k2), Color(BLANCO, 1.0 - k2), 0.3)
			for j in 6:
				var m: Dictionary = _motas[(i * 3 + j) % _motas.size()]
				var a: float = float(m["a"])
				var q: Vector2 = p + Vector2(cos(a), sin(a) * 0.6) * R_IMPACTO * float(m["d"]) * (0.5 + k2) \
					- Vector2(0.0, 18.0 * k2 * float(m["v"]))
				capa.draw_circle(q, float(m["r"]), Color(LUZ, 0.9 * (1.0 - k2)))


# LA COLA de una estrella fugaz: un huso que se afila hacia atras, blanco por dentro y azul por fuera.
func _cola(capa: Node2D, desde: Vector2, hasta: Vector2, ancho: float) -> void:
	var d: Vector2 = hasta - desde
	if d.length() < 1.0:
		return
	var n: Vector2 = d.normalized().orthogonal()
	for capa_i in 2:
		var w: float = ancho * (1.0 if capa_i == 0 else 0.45)
		var col: Color = Color(AZUL, 0.55) if capa_i == 0 else Color(BLANCO, 0.95)
		capa.draw_primitive(PackedVector2Array([desde, hasta + n * w, hasta - n * w]),
			PackedColorArray([Color(col, 0.0), col, col]), PackedVector2Array())


# ------------------------------------------------------------
#  LOS RAYOS (Constelacion y Mirada estelar)
# ------------------------------------------------------------
func _rayo(capa: Node2D, gordo: bool) -> void:
	var a: Vector2 = forma.origen
	var b: Vector2 = forma.origen + forma.dir * forma.largo
	var alto := Vector2(0.0, ALTO_RAYO * K)
	var traza: float = clampf(_t / T_TRAZA, 0.0, 1.0)
	var apaga: float = clampf((_t - T_TRAZA - T_RAYO) / T_APAGA_RAYO, 0.0, 1.0)
	var fin: Vector2 = a.lerp(b, traza)
	if capa == _suelo:
		# Su reflejo en el suelo: una franja de luz tenue bajo el rayo.
		_franja(capa, a, fin, (5.0 if gordo else 3.0) * (1.0 - apaga), Color(AZUL, 0.25 * (1.0 - apaga)))
		return
	var a2: Vector2 = a - alto
	var f2: Vector2 = fin - alto
	# Grueso: fino mientras se traza, se enciende entero y se adelgaza al apagarse.
	var ancho: float = (6.0 if gordo else 3.6) * (0.35 + 0.65 * traza) * (1.0 - apaga)
	if ancho < 0.2:
		return
	if gordo:
		# Los bordes de color (los iris de sus ojos): un poco desplazados a cada lado, como aberracion.
		var nn: Vector2 = forma.dir.orthogonal() * ancho * 0.45
		_franja(capa, a2 + nn, f2 + nn, ancho * 0.9, Color(CIAN, 0.55 * (1.0 - apaga)))
		_franja(capa, a2 - nn, f2 - nn, ancho * 0.9, Color(MAGENTA, 0.55 * (1.0 - apaga)))
	_franja(capa, a2, f2, ancho * 1.8, Color(AZUL, 0.45 * (1.0 - apaga)))
	_franja(capa, a2, f2, ancho, Color(LUZ, 0.9 * (1.0 - apaga)))
	_franja(capa, a2, f2, ancho * 0.4, Color(BLANCO, 1.0 - apaga))
	# Los destellos de las puntas (el de llegada, cuando llega).
	BarridoAire.destello(capa, a2, (9.0 if gordo else 7.0) * (1.0 - apaga), Color(BLANCO, 1.0 - apaga), _t * 2.0)
	if traza >= 1.0:
		BarridoAire.destello(capa, b - alto, (12.0 if gordo else 8.0) * (1.0 - apaga), Color(BLANCO, 1.0 - apaga), -_t * 2.0)
	# Unas motas que corren por el rayo.
	for m in _motas:
		var u: float = fmod(float(m["d"]) + _t * float(m["v"]) * 1.5, 1.0) * traza
		var q: Vector2 = a2.lerp(b - alto, u) + forma.dir.orthogonal() * sin(float(m["a"]) + _t * 9.0) * ancho
		capa.draw_circle(q, float(m["r"]) * 0.8, Color(BLANCO, 0.8 * (1.0 - apaga)))


# Una franja rellena de 'a' a 'b' con las puntas redondas.
func _franja(capa: Node2D, a: Vector2, b: Vector2, ancho: float, col: Color) -> void:
	if ancho <= 0.1 or col.a <= 0.01 or a.distance_to(b) < 0.5:
		return
	var n: Vector2 = (b - a).normalized().orthogonal() * ancho * 0.5
	capa.draw_colored_polygon(PackedVector2Array([a + n, b + n, b - n, a - n]), col)
	capa.draw_circle(a, ancho * 0.5, col)
	capa.draw_circle(b, ancho * 0.5, col)


# ------------------------------------------------------------
#  EL PARPADEO CEGADOR
# ------------------------------------------------------------
func _parpadeo(capa: Node2D) -> void:
	var o: Vector2 = forma.origen
	var u: float = clampf(_t / T_FOGONAZO, 0.0, 1.0)
	var apaga: float = clampf((_t - T_FOGONAZO) / T_APAGA_FOGONAZO, 0.0, 1.0)
	var r: float = forma.radio * (1.0 - (1.0 - u) * (1.0 - u))
	var ang: float = forma.dir.angle()
	var ab: float = deg_to_rad(forma.apertura) * 0.5
	if capa == _suelo:
		# EL ABANICO de luz por el suelo: claro cerca, apagandose hacia el borde.
		var pv := PackedVector2Array([o])
		var pc := PackedColorArray([Color(BLANCO, 0.7 * (1.0 - apaga))])
		var n: int = 18
		for i in n + 1:
			var a: float = ang - ab + 2.0 * ab * float(i) / float(n)
			pv.append(o + Vector2(cos(a), sin(a)) * r)
			pc.append(Color(LUZ, 0.0))
		for i in n:
			capa.draw_primitive(PackedVector2Array([pv[0], pv[i + 1], pv[i + 2]]),
				PackedColorArray([pc[0], Color(LUZ, 0.35 * (1.0 - apaga)), Color(LUZ, 0.35 * (1.0 - apaga))]),
				PackedVector2Array())
		return
	# LOS RAYOS que salen de sus ojos, en abanico, y un destello grande en el origen.
	var alto := Vector2(0.0, ALTO_RAYO * K)
	for i in 7:
		var a: float = ang - ab + 2.0 * ab * (float(i) + 0.5) / 7.0 + sin(_fase + i) * 0.05
		var largo: float = r * (0.7 + 0.3 * sin(_fase * 2.0 + i * 1.7))
		var d := Vector2(cos(a), sin(a))
		var base: float = 2.6 * (1.0 - apaga)
		capa.draw_primitive(PackedVector2Array([o - alto + d.orthogonal() * base, o - alto + d * largo,
			o - alto - d.orthogonal() * base]),
			PackedColorArray([Color(BLANCO, 0.9 * (1.0 - apaga)), Color(LUZ, 0.0), Color(BLANCO, 0.9 * (1.0 - apaga))]),
			PackedVector2Array())
	BarridoAire.destello(capa, o - alto, lerpf(10.0, 22.0, u) * (1.0 - apaga), Color(BLANCO, 1.0 - apaga), _fase)
	for m in _motas:
		var a2: float = ang + (float(m["a"]) / TAU - 0.5) * 2.0 * ab
		var q: Vector2 = o + Vector2(cos(a2), sin(a2)) * r * float(m["d"]) - Vector2(0.0, 6.0 * apaga * float(m["v"]))
		capa.draw_circle(q, float(m["r"]), Color(LUZ, 0.85 * (1.0 - apaga)))


# ------------------------------------------------------------
#  LA ESTRELLA DEL SUELO
# ------------------------------------------------------------
func _estrella(capa: Node2D) -> void:
	var p: Vector2 = forma.centro
	var sale: float = clampf(_t / T_APARECE, 0.0, 1.0)
	var se_va: float = clampf((_t - _secando) / T_SE_APAGA, 0.0, 1.0) if _secando >= 0.0 else 0.0
	var tit: float = 0.8 + 0.2 * sin(_t * 3.3 + _fase) + 0.1 * sin(_t * 7.1 + _fase * 2.0)
	var vivo: float = sale * (1.0 - se_va)
	if capa == _suelo:
		BarridoAire.brillo(capa, p, 11.0 * tit, Color(AZUL, 0.30 * vivo))
		return
	var c: Vector2 = p - Vector2(0.0, (ALTO_ESTRELLA + sin(_t * 1.7 + _fase) * 1.2) * K)
	# Al nacer, un destello grande que se recoge; al irse, otro que se abre y se apaga.
	if sale < 1.0:
		BarridoAire.destello(capa, c, 14.0 * (1.0 - sale) + 5.0, Color(BLANCO, 1.0 - sale), _fase)
	if se_va > 0.0:
		BarridoAire.destello(capa, c, 6.0 + 10.0 * se_va, Color(LUZ, 1.0 - se_va), _fase)
	BarridoAire.brillo(capa, c, 7.0 * tit * vivo, Color(LUZ, 0.45 * vivo))
	BarridoAire.destello(capa, c, 6.0 * tit * vivo, Color(BLANCO, vivo), _fase * 0.2 + sin(_t * 0.7) * 0.15)
