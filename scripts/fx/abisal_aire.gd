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
#    ECLIPSE    el Eclipse (06/10, SUYO: "no reutilices nuestras magias"): sobre su cabeza se enciende una estrella y una
#               LUNA NEGRA se le pone delante hasta dejar solo un anillo de luz; a la vez SU NOCHE se derrama por el suelo
#               desde sus pies (cielo oscuro con estrellas que se van apagando y un borde de medias lunas negras con su
#               pincelada clara rota, el lenguaje de la oscuridad). Aguanta y se le recoge dentro.
#    AGUJERO    el Agujero negro (06/10, suyo): una bolita de noche sale de el y cae en el sitio; alli se abre un REMOLINO
#               de cielo nocturno (brazos curvos azul noche con el filo claro) que se TRAGA las estrellas en espiral hacia
#               un centro negro con un anillo de luz; tira dos veces y se cierra en un punto con un destello.
#  SOBRE EL SUELO, quieta mientras dure la pelea:
#    EstrellaSuelo (estrella()) la estrella que deja al moverse: una estrella pequeña de cuatro puntas flotando un pelo
#               sobre el suelo, que titila, con su resplandor en el suelo. secar() = se apaga en un destello.
#  Coordenadas de MUNDO; el suelo sin achatar; lo que va en el aire, a su altura por K. Todo sale de la forma y la semilla.
# ============================================================
extends Node2D
class_name AbisalAire

enum Modo { LLUVIA, RAYO, MIRADA, PARPADEO, ECLIPSE, AGUJERO, ESTRELLA }

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

# EL ECLIPSE
const T_ENCIENDE := 0.22         # la estrella sobre su cabeza
const T_TAPA := 0.3              # la luna negra se le pone delante (a la vez se derrama la noche)
const T_VIVE_NOCHE := 0.7
const T_RECOGE := 0.45
const ALTO_ECLIPSE := 64.0     # (sobre su cabeza: el slime grande mide ~45)
const NOCHE := Color(0.05, 0.06, 0.16)
const NOCHE_CLARA := Color(0.16, 0.2, 0.42)
const PINCEL := Color(0.78, 0.82, 0.95)

# EL AGUJERO NEGRO
const V_BOLITA := 320.0
const T_ABRE := 0.3
const T_TIRON := 0.28
const TIRONES_AGUJERO := 2
const T_CIERRA_AGUJERO := 0.35
const BRAZOS := 5

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
		Modo.ECLIPSE:
			return T_ENCIENDE + T_TAPA * clampf(p.distance_to(f.centro) / maxf(f.radio, 1.0), 0.0, 1.0)
		Modo.AGUJERO:
			return t_vuela(f) + T_ABRE
	return 0.0


# Lo que tarda la bolita del Agujero negro en llegar (su 'ancho' = lo lejos que esta quien la lanza).
static func t_vuela(f: CombatFormas.Forma) -> float:
	return maxf(f.ancho - 6.0, 0.0) / V_BOLITA


static func t_salir(m: int) -> float:
	match m:
		Modo.LLUVIA: return T_MARCA + T_CAE
		Modo.RAYO, Modo.MIRADA: return T_TRAZA
		Modo.PARPADEO: return T_FOGONAZO
		Modo.ECLIPSE: return T_ENCIENDE + T_TAPA
		Modo.AGUJERO: return T_ABRE
	return 0.2


func duracion() -> float:
	match modo:
		Modo.LLUVIA: return T_MARCA + T_ENTRE * float(maxi(n_fugaces - 1, 0)) + T_CAE + T_IMPACTO + 0.2
		Modo.RAYO, Modo.MIRADA: return T_TRAZA + T_RAYO + T_APAGA_RAYO
		Modo.PARPADEO: return T_FOGONAZO + T_APAGA_FOGONAZO
		Modo.ECLIPSE: return T_ENCIENDE + T_TAPA + T_VIVE_NOCHE + T_RECOGE + 0.1
		Modo.AGUJERO: return t_vuela(forma) + T_ABRE + T_TIRON * float(TIRONES_AGUJERO) + T_CIERRA_AGUJERO + 0.2
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
		Modo.ECLIPSE: _eclipse(capa)
		Modo.AGUJERO: _agujero(capa)
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
	Poligono.relleno(capa, PackedVector2Array([a + n, b + n, b - n, a - n]), col)
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
#  EL ECLIPSE (suyo)
# ------------------------------------------------------------
func _eclipse(capa: Node2D) -> void:
	var c: Vector2 = forma.centro
	var R: float = forma.radio
	var t_noche: float = _t - T_ENCIENDE
	var abre: float = clampf(t_noche / T_TAPA, 0.0, 1.0)
	abre = 1.0 - (1.0 - abre) * (1.0 - abre)
	var t_rec: float = _t - (T_ENCIENDE + T_TAPA + T_VIVE_NOCHE)
	var recoge: float = clampf(t_rec / T_RECOGE, 0.0, 1.0)
	var r: float = R * abre * (1.0 - recoge * recoge)
	if capa == _suelo:
		if r < 1.0:
			return
		# SU NOCHE por el suelo: translucida (se ve quien esta dentro), mas oscura en el centro.
		BarridoAire.brillo(capa, c, r * 1.05, Color(NOCHE, 0.75))
		MagiaAire._anillo(capa, c, r * 0.92, r * 0.5, Color(NOCHE, 0.45))
		# Las estrellas de su cielo, que se van apagando mientras dura.
		var apaga: float = clampf(t_noche / (T_TAPA + T_VIVE_NOCHE), 0.0, 1.0)
		for i in _motas.size():
			var m: Dictionary = _motas[i]
			var q: Vector2 = c + Vector2(cos(float(m["a"])), sin(float(m["a"]))) * r * float(m["d"]) * 0.9
			var vive: float = clampf(1.0 - apaga * 1.6 + float(i) / float(_motas.size()) * 0.6, 0.0, 1.0)
			if vive > 0.05:
				BarridoAire.destello(capa, q, 3.2 * float(m["r"]) * vive, Color(LUZ, vive), float(m["a"]))
		# EL BORDE: medias lunas negras que van girando, con su pincelada clara rota en el filo.
		for k in 9:
			var a: float = TAU * float(k) / 9.0 + _t * 0.6 + _fase
			_media_luna(capa, c, a, r, 0.42, r * 0.16, Color(NOCHE, 0.95), Color(PINCEL, 0.55 * (1.0 - recoge)))
		return
	# EN EL AIRE, sobre su cabeza: la estrella que se enciende y la luna negra que la tapa.
	var o: Vector2 = c - Vector2(0.0, ALTO_ECLIPSE * K)
	var enc: float = clampf(_t / T_ENCIENDE, 0.0, 1.0)
	var vivo: float = enc * (1.0 - recoge)
	if vivo <= 0.01:
		return
	BarridoAire.brillo(capa, o, 16.0 * vivo, Color(LUZ, 0.35 * vivo))
	var tapa: float = abre if recoge <= 0.0 else 1.0 - recoge
	# El anillo de luz que queda alrededor de la luna (mas fino cuanto mas la tapa).
	MagiaAire._anillo(capa, o, 8.5, lerpf(4.0, 1.4, tapa), Color(BLANCO, vivo))
	if tapa < 0.95:
		BarridoAire.destello(capa, o, 12.0 * (1.0 - tapa) * vivo, Color(BLANCO, vivo), _fase)
	# LA LUNA NEGRA, entrando de lado hasta ponerse delante; con un destello de diamante en el borde al cerrar.
	var lado: Vector2 = Vector2(cos(_fase), sin(_fase) * 0.4).normalized() * 9.0 * (1.0 - tapa)
	capa.draw_circle(o + lado, 7.6, Color(0.01, 0.01, 0.03, vivo))
	if tapa > 0.9 and recoge <= 0.0:
		var dia: Vector2 = o + Vector2(cos(_fase + 2.0), sin(_fase + 2.0)) * 8.6
		BarridoAire.destello(capa, dia, 6.0 * clampf((t_noche - T_TAPA * 0.9) / 0.15, 0.0, 1.0), Color(BLANCO, 1.0), 0.4)


# UNA MEDIA LUNA rellena (el lenguaje de la oscuridad): un arco grueso en el borde, afilado en las puntas, con su
# pincelada clara rota en el filo de fuera.
func _media_luna(capa: Node2D, c: Vector2, a: float, r: float, largo: float, grueso: float, col: Color,
		pincel: Color) -> void:
	if r < 2.0:
		return
	var n: int = 10
	var fuera := PackedVector2Array()
	var dentro := PackedVector2Array()
	for i in n + 1:
		var u: float = float(i) / float(n)
		var ang: float = a + (u - 0.5) * largo * 2.0
		var g: float = grueso * sin(PI * u)
		fuera.append(c + Vector2(cos(ang), sin(ang)) * (r + g * 0.35))
		dentro.append(c + Vector2(cos(ang), sin(ang)) * (r - g * 0.65))
	dentro.reverse()
	var pv := fuera.duplicate()
	pv.append_array(dentro)
	Poligono.relleno(capa, pv, col)
	# La pincelada: trocitos del filo de fuera (rota: uno si, uno no).
	for i in range(1, n - 1, 2):
		capa.draw_line(fuera[i], fuera[i + 1], pincel, 1.2)


# ------------------------------------------------------------
#  EL AGUJERO NEGRO (suyo)
# ------------------------------------------------------------
func _agujero(capa: Node2D) -> void:
	var c: Vector2 = forma.centro
	var R: float = forma.radio
	var tv: float = t_vuela(forma)
	var desde: Vector2 = c - forma.dir.normalized() * forma.ancho if forma.dir != Vector2.ZERO else c
	if _t < tv:
		# LA BOLITA de noche que sale de el (con sus brillos) y vuela en arco hasta el sitio.
		if capa == _delante:
			var u: float = clampf(_t / maxf(tv, 0.01), 0.0, 1.0)
			var p: Vector2 = desde.lerp(c, u) - Vector2(0.0, (14.0 + sin(PI * u) * 18.0) * K)
			BarridoAire.brillo(capa, p, 9.0, Color(NOCHE_CLARA, 0.6))
			capa.draw_circle(p, 4.2, NOCHE)
			BarridoAire.destello(capa, p + Vector2(1.5, -1.5), 3.5, Color(LUZ, 0.9), _t * 6.0)
		return
	var t2: float = _t - tv
	var abre: float = clampf(t2 / T_ABRE, 0.0, 1.0)
	abre = 1.0 - (1.0 - abre) * (1.0 - abre)
	var t_cierra: float = t2 - T_ABRE - T_TIRON * float(TIRONES_AGUJERO)
	var cierra: float = clampf(t_cierra / T_CIERRA_AGUJERO, 0.0, 1.0)
	# En cada tiron se aprieta un poco y vuelve.
	var tiron: float = 0.0
	if t2 > T_ABRE and t_cierra < 0.0:
		var ft: float = fmod(t2 - T_ABRE, T_TIRON) / T_TIRON
		tiron = sin(PI * ft) * 0.12
	var r: float = R * abre * (1.0 - tiron) * (1.0 - cierra * cierra)
	var giro: float = _t * 3.2 + _fase
	if capa == _suelo:
		if r < 1.0:
			return
		BarridoAire.brillo(capa, c, r * 1.1, Color(NOCHE, 0.6))
		# LOS BRAZOS del remolino: cielo de noche en espiral hacia dentro, con el filo claro.
		for k in BRAZOS:
			_brazo(capa, c, giro + TAU * float(k) / float(BRAZOS), r)
		return
	if r < 1.0:
		if cierra >= 1.0 and t_cierra < T_CIERRA_AGUJERO + 0.2:
			BarridoAire.destello(capa, c - Vector2(0.0, 4.0), 12.0, Color(BLANCO, 1.0 - (t_cierra - T_CIERRA_AGUJERO) / 0.2), 0.3)
		return
	# LAS ESTRELLAS QUE SE TRAGA: dan vueltas cada vez mas cerca del centro y se apagan al caer.
	for i in _motas.size():
		var m: Dictionary = _motas[i]
		var vida: float = fmod(float(m["d"]) + t2 * 0.7 * float(m["v"]), 1.0)
		var rr: float = r * (1.0 - vida)
		var ang: float = float(m["a"]) + giro * 1.4 + vida * 5.0
		var q: Vector2 = c + Vector2(cos(ang), sin(ang)) * rr
		BarridoAire.destello(capa, q, 3.0 * float(m["r"]) * (1.0 - vida * 0.7), Color(LUZ, 0.9 * (1.0 - vida)), ang)
	# EL CENTRO: negro, con su anillo de luz (el horizonte) que late con los tirones.
	var rc: float = maxf(r * 0.16, 3.0)
	BarridoAire.brillo(capa, c, rc * 2.6, Color(AZUL, 0.35))
	MagiaAire._anillo(capa, c, rc * 1.15, 1.6 + tiron * 8.0, Color(LUZ, 0.95))
	capa.draw_circle(c, rc, Color(0.0, 0.0, 0.02))


# UN BRAZO del remolino: una espiral que se estrecha hacia el centro, azul noche, con el filo de fuera claro (pincel).
func _brazo(capa: Node2D, c: Vector2, a0: float, r: float) -> void:
	var n: int = 14
	var fuera := PackedVector2Array()
	var dentro := PackedVector2Array()
	for i in n + 1:
		var u: float = float(i) / float(n)           # 0 = fuera, 1 = centro
		var rr: float = r * (1.0 - u * 0.86)
		var ang: float = a0 + u * 2.6
		var g: float = r * 0.2 * sin(PI * (0.15 + u * 0.85)) * (1.0 - u * 0.5)
		var d := Vector2(cos(ang), sin(ang))
		fuera.append(c + d * (rr + g * 0.5))
		dentro.append(c + d * (rr - g * 0.5))
	dentro.reverse()
	var pv := fuera.duplicate()
	pv.append_array(dentro)
	Poligono.relleno(capa, pv, Color(NOCHE_CLARA, 0.85))
	# La sombra de dentro del brazo y su pincelada clara rota.
	for i in range(0, n - 1, 2):
		capa.draw_line(fuera[i], fuera[i + 1], Color(PINCEL, 0.6), 1.3)
		capa.draw_line(dentro[i], dentro[i + 1], Color(NOCHE, 0.9), 2.0)


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
