# ============================================================
#  apoyo_aire.gd
#  LOS EFECTOS DE LAS DE APOYO de la espada larga y el escudo en el mapa (25/09/2026). Las que no pegan tambien se
#  ven al activarlas (receta del arma). Mismas piezas que los que le gustan: anillos y bandas RELLENAS que se
#  difuminan, destellos en estrella, cometas, brillos y la chapa del escudo (EscudoAire). NADA DE LINEAS.
#  En el SUELO (huella redonda alrededor de ti, por SueloRoto: la ficha dice cual):
#    VOTO      Voto de guardia: un golpe seco a tus pies y un anillo azul acero que se abre hasta el borde y se
#              queda un momento, con motas que suben (los de dentro ya se ponen en defensa: su postura).
#    VOZ       Voz de mando: tres ondas doradas hasta el borde y un destello a la altura de la cabeza.
#    PROVOCA   Provocacion: tu chapa se estampa delante de ti y salen dos ondas ROJAS gordas.
#    AMPARO    Cobertura: un anillo azul hasta el borde y un velo que se queda un momento.
#  SOBRE UN CUERPO (CombatTactico._on_dibujo_mapa, por el adorno de la habilidad):
#    PRESTEZA  Voz de mando, en cada uno de los tuyos que la recibe: cometas doradas que le suben por los pies.
#    AMPARO_C  Cobertura, en cada uno: una chapa pequeña de luz delante de el.
#    ESCOLTA   tres cometas doradas de ti al compañero y un anillo que le late a los pies.
#    MURO      una chapa GRANDE plantada junto al protegido, del lado de su enemigo mas cercano.
#    CARNE     Guardia de carne: dos pulsos rojos (lo que dura se ve en el muñeco: CombatTactico._estados_visibles).
#    RODELA    Postura de rodela: la chapa alzada hacia el enemigo mas cercano, con un destello que la recorre.
#  Coordenadas de MUNDO; los circulos del suelo van SIN achatar (como las huellas).
# ============================================================
extends Node2D
class_name ApoyoAire

enum Modo { VOTO, VOZ, PROVOCA, AMPARO, PRESTEZA, AMPARO_C, ESCOLTA, MURO, CARNE, RODELA }

const K := 0.7071
const BLANCO := BarridoAire.BLANCO
const AIRE := BarridoAire.AIRE
const CHAPA := EscudoAire.CHAPA
const GUARDIA := Color(0.62, 0.78, 1.0)
const ORO := Color(1.0, 0.82, 0.4)
const ORO_CLARO := Color(1.0, 0.95, 0.75)
const ROJO := Color(0.95, 0.25, 0.2)
const ROJO_CLARO := Color(1.0, 0.6, 0.5)
const POLVO := SueloRoto.POLVO
const Z_ENCIMA := Game.Z_PERSONAJES + 80
const ALTO_TORSO := 14.0
const ALTO_CABEZA := 26.0

var modo: int = Modo.VOTO
var forma: CombatFormas.Forma = null
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _c: Vector2 = Vector2.ZERO        # el centro: de la huella, o el pecho del cuerpo
var _r: float = 60.0                  # el radio de la huella
var _pies: Vector2 = Vector2.ZERO
var _desde: Vector2 = Vector2.ZERO    # el pecho de quien lo lanza
var _dir: Vector2 = Vector2.RIGHT
var _lat: Vector2 = Vector2.RIGHT
var _motas: Array = []
var _delante: Node2D = null
var _suelo: Node2D = null


# EN EL SUELO: la huella entera ('f', redonda y centrada en ti). 'espera' = hasta que sale.
static func area(padre: Node, f: CombatFormas.Forma, m: int, semilla: int, espera: float) -> ApoyoAire:
	if padre == null or f == null:
		return null
	var e := ApoyoAire.new()
	e.modo = m
	e.forma = f
	e._rng.seed = semilla
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	e._t = -espera * e._ritmo
	e._c = f.centro
	e._pies = f.centro
	e._r = maxf(f.radio, 10.0)
	e._dir = f.dir.normalized() if f.dir.length_squared() > 0.0001 else Vector2.RIGHT
	e.z_as_relative = false
	e.z_index = SueloRoto.Z_SUELO
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._preparar()
	return e


# SOBRE UN CUERPO: 'desde' = el pecho de quien lo lanza; 'caja' = el que lo recibe; 'hacia' = a donde mira lo que
# se planta (Muro, Rodela: hacia el enemigo mas cercano).
static func cuerpo(padre: Node, m: int, desde: Vector2, caja: Rect2, semilla: int, espera: float, ritmo: float,
		hacia: Vector2 = Vector2.ZERO) -> ApoyoAire:
	if padre == null:
		return null
	var e := ApoyoAire.new()
	e.modo = m
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	e._t = -maxf(espera, 0.0)
	e._desde = desde
	e._c = caja.get_center() if caja.has_area() else desde
	e._pies = Vector2(e._c.x, caja.end.y) if caja.has_area() else e._c + Vector2(0.0, ALTO_TORSO)
	if hacia.length_squared() > 0.0001:
		e._dir = hacia.normalized()
	elif e._c.distance_squared_to(desde) > 1.0:
		e._dir = (e._c - desde).normalized()
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._preparar()
	return e


func duracion() -> float:
	match modo:
		Modo.VOTO: return 1.05
		Modo.VOZ: return 0.6
		Modo.PROVOCA: return 0.6
		Modo.AMPARO: return 0.8
		Modo.ESCOLTA: return 0.75
		Modo.MURO: return 0.9
		Modo.RODELA: return 0.7
	return 0.55


func _preparar() -> void:
	_lat = Vector2(-_dir.y, _dir.x * K)
	if _lat.length_squared() < 0.001:
		_lat = Vector2.RIGHT
	match modo:
		Modo.VOTO:
			for i in 14:
				var a: float = TAU * (float(i) + _rng.randf_range(0.0, 0.8)) / 14.0
				_motas.append({"a": a, "t0": 0.2 + _rng.randf_range(0.0, 0.25), "v": _rng.randf_range(22.0, 40.0),
					"tam": _rng.randf_range(1.2, 2.0)})
		Modo.PRESTEZA:
			for i in 5:
				_motas.append({"x": _rng.randf_range(-7.0, 7.0), "t0": _rng.randf_range(0.0, 0.14),
					"v": _rng.randf_range(80.0, 120.0)})
		Modo.ESCOLTA:
			for i in 3:
				_motas.append({"t0": 0.045 * float(i), "curva": _rng.randf_range(6.0, 14.0) * (1.0 if i % 2 == 0 else -1.0)})
	# Lo del SUELO de un cuerpo (anillos a los pies, polvo) va por debajo de los cuerpos.
	_suelo = Node2D.new()
	_suelo.z_as_relative = false
	_suelo.z_index = SueloRoto.Z_SUELO
	add_child(_suelo)
	_suelo.draw.connect(_dibujar_suelo)
	if forma != null:
		# Lo del AIRE de un area (chapa, destellos) va por encima.
		_delante = Node2D.new()
		_delante.z_as_relative = false
		_delante.z_index = Z_ENCIMA
		add_child(_delante)
		_delante.draw.connect(_dibujar_aire_area)


func _process(delta: float) -> void:
	_t += delta * _ritmo
	if _t >= duracion():
		queue_free()
		return
	queue_redraw()
	_suelo.queue_redraw()
	if _delante != null:
		_delante.queue_redraw()


# ------------------------------------------------------------
#  PIEZAS
# ------------------------------------------------------------
# UN ANILLO RELLENO en el suelo (sin achatar): el filo por fuera, a nada hacia dentro. No una raya.
static func _anillo(ci: CanvasItem, c: Vector2, r: float, grueso: float, filo: Color, dentro: Color) -> void:
	if filo.a <= 0.005 or r <= 0.5:
		return
	var n: int = clampi(int(r * 0.6), 24, 72)
	var tr := Color(dentro, 0.0)
	for i in n:
		var u0 := Vector2(cos(TAU * float(i) / n), sin(TAU * float(i) / n))
		var u1 := Vector2(cos(TAU * float(i + 1) / n), sin(TAU * float(i + 1) / n))
		var a0: Vector2 = c + u0 * r
		var a1: Vector2 = c + u1 * r
		var m0: Vector2 = c + u0 * maxf(r - grueso * 0.3, 0.0)
		var m1: Vector2 = c + u1 * maxf(r - grueso * 0.3, 0.0)
		var d0: Vector2 = c + u0 * maxf(r - grueso, 0.0)
		var d1: Vector2 = c + u1 * maxf(r - grueso, 0.0)
		var cd := Color(dentro, dentro.a)
		ci.draw_primitive(PackedVector2Array([a0, a1, m1]), PackedColorArray([filo, filo, cd]), PackedVector2Array())
		ci.draw_primitive(PackedVector2Array([a0, m1, m0]), PackedColorArray([filo, cd, cd]), PackedVector2Array())
		ci.draw_primitive(PackedVector2Array([m0, m1, d1]), PackedColorArray([cd, cd, tr]), PackedVector2Array())
		ci.draw_primitive(PackedVector2Array([m0, d1, d0]), PackedColorArray([cd, tr, tr]), PackedVector2Array())


# LA CHAPA del escudo (la de EscudoAire): ovalo relleno en el plano del escudo, con el umbo.
static func _chapa(ci: CanvasItem, c: Vector2, lat: Vector2, escala: float, alfa: float, col: Color = CHAPA) -> void:
	if alfa <= 0.01:
		return
	# Nunca de canto del todo: de lado (al E/O) la chapa se quedaba en una raya vertical. Se abre un poco hacia
	# lo horizontal, como si el escudo girara hacia la camara.
	var w: Vector2 = lat.normalized()
	w = (w + Vector2(0.55 if w.x >= 0.0 else -0.55, 0.0)).normalized()
	var ancho: Vector2 = w * maxf(lat.length(), 0.8) * 11.0 * escala
	var alto: Vector2 = Vector2(0.0, -13.0 * escala)
	var cc := Color(BLANCO, alfa)
	var cm := Color(col, alfa * 0.85)
	var cb := Color(col, 0.0)
	var n: int = 20
	for i in n:
		var a0: float = TAU * float(i) / float(n)
		var a1: float = TAU * float(i + 1) / float(n)
		var e0: Vector2 = ancho * cos(a0) + alto * sin(a0)
		var e1: Vector2 = ancho * cos(a1) + alto * sin(a1)
		ci.draw_primitive(PackedVector2Array([c, c + e0 * 0.75, c + e1 * 0.75]), PackedColorArray([cc, cm, cm]),
			PackedVector2Array())
		ci.draw_primitive(PackedVector2Array([c + e0 * 0.75, c + e0, c + e1]), PackedColorArray([cm, cb, cb]),
			PackedVector2Array())
		ci.draw_primitive(PackedVector2Array([c + e0 * 0.75, c + e1, c + e1 * 0.75]), PackedColorArray([cm, cb, cm]),
			PackedVector2Array())
	BarridoAire.brillo(ci, c, 4.5 * escala, Color(BLANCO, alfa))


static func _sale(t: float, dur: float) -> float:
	var k: float = clampf(t / dur, 0.0, 1.0)
	return 1.0 - (1.0 - k) * (1.0 - k)


# ------------------------------------------------------------
#  EL SUELO
# ------------------------------------------------------------
func _dibujar_suelo() -> void:
	if _t < 0.0:
		return
	match modo:
		Modo.VOTO:
			# El anillo se abre hasta el borde y se queda, apagandose.
			var k: float = _sale(_t, 0.2)
			var alfa: float = 1.0 - clampf((_t - 0.6) / 0.4, 0.0, 1.0)
			_anillo(_suelo, _c, _r * k, lerpf(18.0, 9.0, k), Color(BLANCO, 0.95 * alfa), Color(GUARDIA, 0.5 * alfa))
			# El golpe a tus pies: polvo que sale.
			if _t < 0.4:
				var kp: float = _t / 0.4
				BarridoAire.brillo(_suelo, _c, 8.0 + 14.0 * kp, Color(POLVO, 0.5 * (1.0 - kp)))
		Modo.VOZ:
			for i in 3:
				var tk: float = _t - 0.07 * float(i)
				if tk < 0.0 or tk > 0.34:
					continue
				var k2: float = _sale(tk, 0.34)
				_anillo(_suelo, _c, _r * k2, lerpf(22.0, 9.0, k2), Color(ORO_CLARO, 0.9 * (1.0 - k2)),
					Color(ORO, 0.45 * (1.0 - k2)))
		Modo.PROVOCA:
			for i in 2:
				var tk2: float = _t - 0.09 * float(i)
				if tk2 < 0.0 or tk2 > 0.28:
					continue
				var k3: float = _sale(tk2, 0.28)
				_anillo(_suelo, _c, _r * k3, lerpf(30.0, 12.0, k3), Color(ROJO_CLARO, 0.95 * (1.0 - k3)),
					Color(ROJO, 0.6 * (1.0 - k3)))
		Modo.AMPARO:
			var k4: float = _sale(_t, 0.18)
			var alfa4: float = 1.0 - clampf((_t - 0.4) / 0.35, 0.0, 1.0)
			BarridoAire.brillo(_suelo, _c, _r * k4, Color(GUARDIA, 0.16 * alfa4))
			_anillo(_suelo, _c, _r * k4, lerpf(16.0, 9.0, k4), Color(BLANCO, 0.9 * alfa4), Color(GUARDIA, 0.45 * alfa4))
		Modo.PRESTEZA:
			var k5: float = _sale(_t, 0.25)
			_anillo(_suelo, _pies, 4.0 + 10.0 * k5, 4.0, Color(ORO_CLARO, 0.8 * (1.0 - k5)), Color(ORO, 0.3 * (1.0 - k5)))
		Modo.ESCOLTA:
			# El anillo del compañero, dos latidos cuando le llegan las cometas.
			for i in 2:
				var tk3: float = _t - 0.2 - 0.18 * float(i)
				if tk3 < 0.0 or tk3 > 0.3:
					continue
				var k6: float = _sale(tk3, 0.3)
				_anillo(_suelo, _pies, 8.0 + 14.0 * k6, 7.0, Color(ORO_CLARO, 0.95 * (1.0 - k6)), Color(ORO, 0.5 * (1.0 - k6)))
		Modo.MURO:
			# Donde se planta: polvo a los dos lados de la base.
			if _t < 0.45:
				var kp2: float = _t / 0.45
				var base: Vector2 = _pies + Vector2(_dir.x, _dir.y * K) * 22.0
				for s in [-1.0, 1.0]:
					BarridoAire.brillo(_suelo, base + _lat.normalized() * s * (6.0 + 10.0 * kp2), 6.0 + 6.0 * kp2,
						Color(POLVO, 0.55 * (1.0 - kp2)))
		Modo.CARNE:
			var k7: float = _sale(_t, 0.35)
			_anillo(_suelo, _pies, 6.0 + 18.0 * k7, 5.0, Color(ROJO_CLARO, 0.85 * (1.0 - k7)), Color(ROJO, 0.4 * (1.0 - k7)))


# ------------------------------------------------------------
#  EL AIRE DE UN AREA
# ------------------------------------------------------------
func _dibujar_aire_area() -> void:
	match modo:
		Modo.VOTO:
			if _t >= 0.0:
				var pulso: float = exp(-_t / 0.05)
				BarridoAire.destello(_delante, _c + Vector2(0.0, -4.0), 6.0 + 8.0 * pulso, Color(BLANCO, pulso), 0.0)
			# Las motas que suben del anillo.
			for m in _motas:
				var tp: float = _t - float(m["t0"])
				if tp < 0.0 or tp > 0.45:
					continue
				var a: float = float(m["a"])
				var p: Vector2 = _c + Vector2(cos(a), sin(a)) * _r + Vector2(0.0, -float(m["v"]) * tp)
				var tam: float = float(m["tam"])
				_delante.draw_rect(Rect2(p - Vector2(tam, tam) * 0.5, Vector2(tam, tam)),
					Color(GUARDIA.lerp(BLANCO, 0.5), 0.9 * (1.0 - tp / 0.45)))
		Modo.VOZ:
			if _t >= -0.02:
				var pulso2: float = exp(-maxf(_t, 0.0) / 0.07)
				BarridoAire.destello(_delante, _c + Vector2(0.0, -ALTO_CABEZA), 9.0 + 10.0 * pulso2,
					Color(ORO_CLARO, pulso2), 0.4)
		Modo.PROVOCA:
			# La chapa que se estampa delante de ti (el golpe al escudo) y el pulso rojo en el pecho.
			var llega: float = clampf((_t + 0.06) / 0.06, 0.0, 1.0)
			var va: float = clampf((_t - 0.12) / 0.2, 0.0, 1.0)
			var en: Vector2 = _c + _dir * 9.0 + Vector2(0.0, -ALTO_TORSO) - _dir * 8.0 * (1.0 - llega * llega)
			_chapa(_delante, en, _lat, 1.05, 0.95 * llega * (1.0 - va))
			if _t >= 0.0:
				var pulso3: float = exp(-_t / 0.05)
				BarridoAire.destello(_delante, en, 7.0 + 7.0 * pulso3, Color(BLANCO, pulso3), 0.3)
				BarridoAire.brillo(_delante, _c + Vector2(0.0, -ALTO_TORSO), 12.0 + 14.0 * _sale(_t, 0.3),
					Color(ROJO, 0.45 * (1.0 - _sale(_t, 0.3))))


# ------------------------------------------------------------
#  SOBRE UN CUERPO
# ------------------------------------------------------------
func _draw() -> void:
	if _t < 0.0 or forma != null:
		return
	match modo:
		Modo.PRESTEZA:
			for m in _motas:
				var tp: float = _t - float(m["t0"])
				if tp < 0.0 or tp > 0.3:
					continue
				var p: Vector2 = _pies + Vector2(float(m["x"]), -float(m["v"]) * tp)
				BarridoAire.cometa(self, p + Vector2(0.0, 9.0), p, 2.0, Color(ORO_CLARO, 0.95 * (1.0 - tp / 0.3)))
		Modo.AMPARO_C:
			var llega: float = _sale(_t, 0.1)
			var va: float = clampf((_t - 0.3) / 0.2, 0.0, 1.0)
			_chapa(self, _c + Vector2(_dir.x, _dir.y * K) * 9.0, _lat, 0.7, 0.8 * llega * (1.0 - va), GUARDIA)
		Modo.ESCOLTA:
			# Las cometas van de ti al compañero, cada una por su curva.
			var nor: Vector2 = (_c - _desde).orthogonal().normalized() if _c.distance_squared_to(_desde) > 1.0 else Vector2.UP
			for m in _motas:
				var u: float = clampf((_t - float(m["t0"])) / 0.2, 0.0, 1.0)
				if u <= 0.0 or u >= 1.0:
					continue
				var p: Vector2 = _desde.lerp(_c, u) + nor * sin(PI * u) * float(m["curva"])
				var u0: float = maxf(u - 0.3, 0.0)
				var p0: Vector2 = _desde.lerp(_c, u0) + nor * sin(PI * u0) * float(m["curva"])
				BarridoAire.brillo(self, p, 7.0, Color(ORO, 0.45))
				BarridoAire.cometa(self, p0, p, 4.0, Color(ORO_CLARO, 0.95))
			var tl: float = _t - 0.2
			if tl >= 0.0:
				var pulso: float = exp(-tl / 0.05)
				BarridoAire.destello(self, _c, 7.0 + 9.0 * pulso, Color(ORO_CLARO, pulso), 0.2)
				BarridoAire.brillo(self, _c, 12.0, Color(ORO, 0.4 * exp(-tl / 0.15)))
		Modo.MURO:
			# La chapa GRANDE cae y se planta, aguanta y se va.
			var cae: float = _sale(_t, 0.08)
			var va2: float = clampf((_t - 0.55) / 0.3, 0.0, 1.0)
			var base: Vector2 = _pies + Vector2(_dir.x, _dir.y * K) * 22.0
			var en: Vector2 = base + Vector2(0.0, -20.0 - 10.0 * (1.0 - cae))
			_chapa(self, en, _lat, 1.6, 0.9 * cae * (1.0 - va2), GUARDIA)
			var pulso2: float = exp(-maxf(_t - 0.08, 0.0) / 0.05)
			if _t >= 0.08:
				BarridoAire.destello(self, base + Vector2(0.0, -4.0), 6.0 + 9.0 * pulso2, Color(BLANCO, pulso2), 0.0)
		Modo.CARNE:
			for i in 2:
				var tk: float = _t - 0.2 * float(i)
				if tk < 0.0 or tk > 0.3:
					continue
				var k: float = _sale(tk, 0.3)
				BarridoAire.brillo(self, _c, 14.0 + 16.0 * k, Color(ROJO, 0.5 * (1.0 - k)))
		Modo.RODELA:
			# La chapa alzada hacia el enemigo, y un destello que la recorre de lado a lado.
			var llega2: float = _sale(_t, 0.08)
			var va3: float = clampf((_t - 0.4) / 0.25, 0.0, 1.0)
			var en2: Vector2 = _c + Vector2(_dir.x, _dir.y * K) * 9.0 + Vector2(0.0, -2.0)
			_chapa(self, en2, _lat, 0.85, 0.9 * llega2 * (1.0 - va3))
			var ks: float = clampf((_t - 0.06) / 0.2, 0.0, 1.0)
			if ks > 0.0 and ks < 1.0:
				var p2: Vector2 = en2 + _lat.normalized() * _lat.length() * 9.0 * lerpf(-1.0, 1.0, ks) + Vector2(0.0, -4.0)
				BarridoAire.destello(self, p2, 7.0, Color(BLANCO, sin(PI * ks)), 0.3)
