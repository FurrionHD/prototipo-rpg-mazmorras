# ============================================================
#  trent_aire.gd  (class_name TrentAire)
#  LOS EFECTOS DE LOS MUTANTES DEL TRENT en el mapa (02/11/2026: el Tocon ambarino y el Espantajo; ver la memoria
#  trent-mutante). De momento, las VERSIONES que pidio ver el jefe de los dos del Espantajo (la savia negra, en el
#  lenguaje de la oscuridad del juego: formas negras rellenas, borde violeta claro, luz blanco-violeta):
#    GEISER  sale por la grieta de su espalda y cae sobre un circulo:
#            A  CHORRO y GOTAS gordas que caen con salpicadura
#            B  el chorro forma una NUBE negra encima del area que LLUEVE
#            C  el chorro se abre en BRAZOS de tinta que caen como latigos sobre el area
#    CHUPAR  le saca vida a un enraizado y se la lleva a sus pies:
#            A  HILOS violeta que reptan por el suelo y BOLITAS de luz que suben por ellos
#            B  un REMOLINO sobre la victima y MOTAS que vuelan en espiral hasta el
#            C  una RAIZ negra que asoma entre los dos y LATE: pulsos de luz que viajan hasta el
#  NADA DE LINEAS (efectos-sin-lineas): todo relleno. NADA se queda en el suelo: las manchas se apagan. Coordenadas de
#  MUNDO.
# ============================================================
extends Node2D
class_name TrentAire

enum Modo { GEISER, CHUPAR }

const Z_ENCIMA := Game.Z_ENCIMA_PERSONAJES + 80

const NEGRO := Color(0.05, 0.03, 0.07)
const SAVIA := Color(0.12, 0.07, 0.16)
const BORDE := Color(0.55, 0.42, 0.78)       # el filo claro de la savia (la pincelada)
const VIOLETA := Color(0.62, 0.40, 0.95)
const LUZ := Color(0.92, 0.86, 1.0)

const T_SALE := 0.28        # el chorro sale cuando se arquea (su 'geiser': 8 a 10, el arqueo en el 0,35)
const T_GEISER := 1.7
const T_CHUPAR := 1.3

var modo: int = Modo.GEISER
var version: int = 0
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _o: Vector2 = Vector2.ZERO        # de donde sale (la grieta de la espalda / la victima)
var _c: Vector2 = Vector2.ZERO        # el centro del area (geiser) / sus pies (chupar)
var _r: float = 45.0
var _piezas: Array = []
var _suelo: Node2D = null
var _delante: Node2D = null
var _brillo: Node2D = null


# ------------------------------------------------------------
#  CREARLOS
# ------------------------------------------------------------
# GEISER: de 'grieta' (su espalda) al circulo de centro 'centro' y radio 'r'. 'version' 0, 1, 2 = A, B, C.
static func geiser(padre: Node, grieta: Vector2, centro: Vector2, r: float, version_: int, semilla: int) -> TrentAire:
	var e := _nuevo(Modo.GEISER, version_, semilla)
	e._o = grieta
	e._c = centro
	e._r = maxf(r, 10.0)
	e._preparar()
	e._montar(padre)
	return e


# CHUPAR: de 'victima' (sus pies) a 'pies' (los del Espantajo). 'version' 0, 1, 2 = A, B, C.
static func chupar(padre: Node, victima: Vector2, pies: Vector2, version_: int, semilla: int) -> TrentAire:
	var e := _nuevo(Modo.CHUPAR, version_, semilla)
	e._o = victima
	e._c = pies
	e._preparar()
	e._montar(padre)
	return e


static func _nuevo(m: int, v: int, semilla: int) -> TrentAire:
	var e := TrentAire.new()
	e.modo = m
	e.version = clampi(v, 0, 2)
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	return e


func _montar(padre: Node) -> void:
	z_as_relative = false
	z_index = SueloRoto.Z_SUELO
	process_mode = Node.PROCESS_MODE_ALWAYS   # la pelea tactica pausa el arbol
	padre.add_child(self)
	_suelo = _capa(SueloRoto.Z_SUELO, false)
	_delante = _capa(Z_ENCIMA, false)
	_brillo = _capa(Z_ENCIMA + 1, true)


func _capa(z: int, aditiva: bool) -> Node2D:
	var c := Node2D.new()
	c.z_as_relative = false
	c.z_index = z
	if aditiva:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		c.material = mat
	c.draw.connect(_pintar.bind(c))
	add_child(c)
	return c


# Un punto al azar dentro del circulo del area (en el suelo: achatado como todo lo del suelo).
func _en_area() -> Vector2:
	var a: float = _rng.randf() * TAU
	var d: float = sqrt(_rng.randf()) * _r
	return _c + Vector2(cos(a), sin(a) * 0.6) * d


func _preparar() -> void:
	match modo:
		Modo.GEISER:
			var n: int = [14, 26, 5][version]
			for i in n:
				var t0: float
				match version:
					0: t0 = 0.62 + 0.4 * float(i) / float(n) + _rng.randf_range(-0.04, 0.04)
					1: t0 = 0.78 + 0.5 * float(i) / float(n) + _rng.randf_range(-0.05, 0.05)
					_: t0 = 0.62 + 0.07 * float(i)
				_piezas.append({"en": _en_area(), "t0": t0, "tam": _rng.randf_range(0.8, 1.25),
					"fase": _rng.randf_range(0.0, TAU), "lado": -1.0 if i % 2 else 1.0})
		Modo.CHUPAR:
			var n2: int = [3, 10, 5][version]
			for i in n2:
				_piezas.append({"t0": _rng.randf_range(0.0, 0.25) + 0.12 * float(i) * (1.0 if version != 0 else 0.0),
					"fase": _rng.randf_range(0.0, TAU), "curva": _rng.randf_range(-1.0, 1.0), "k": i})


func duracion() -> float:
	return T_GEISER if modo == Modo.GEISER else T_CHUPAR


func _process(delta: float) -> void:
	avanzar_a(_t + delta * _ritmo)
	if _t >= duracion():
		queue_free()


func avanzar_a(t: float) -> void:
	_t = t
	if _suelo != null:
		_suelo.queue_redraw()
		_delante.queue_redraw()
		_brillo.queue_redraw()


func _pintar(capa: Node2D) -> void:
	if _t < 0.0:
		return
	if modo == Modo.GEISER:
		_geiser(capa)
	else:
		_chupar(capa)


# ------------------------------------------------------------
#  PIEZAS
# ------------------------------------------------------------
# UNA CINTA rellena por 'pts' con un ancho por punto (los hilos, la raiz, los brazos, el chorro).
static func _cinta(ci: CanvasItem, pts: PackedVector2Array, anchos: PackedFloat32Array, col: Color) -> void:
	if pts.size() < 2 or col.a <= 0.01:
		return
	var izq := PackedVector2Array()
	var der := PackedVector2Array()
	for i in pts.size():
		var d: Vector2 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)])
		if d.length_squared() < 0.0001:
			d = Vector2.RIGHT
		var n: Vector2 = d.normalized().orthogonal() * anchos[i] * 0.5
		izq.append(pts[i] + n)
		der.append(pts[i] - n)
	der.reverse()
	izq.append_array(der)
	Poligono.relleno(ci, izq, col)


# UNA GOTA que cae: lagrima con la punta hacia arriba, negra, con el filo claro a un lado.
static func _gota(ci: CanvasItem, c: Vector2, tam: float, estira: float, alfa: float) -> void:
	if alfa <= 0.01 or tam <= 0.2:
		return
	var pts := PackedVector2Array()
	for k in 12:
		var a: float = TAU * float(k) / 12.0
		var y: float = sin(a)
		var x: float = cos(a) * (1.0 - maxf(-y, 0.0) * 0.75)
		pts.append(c + Vector2(x * tam, y * tam * (1.0 if y > 0.0 else estira)))
	Poligono.relleno(ci, pts, Color(SAVIA, alfa))
	ci.draw_circle(c + Vector2(-tam * 0.35, tam * 0.1), tam * 0.35, Color(BORDE, 0.8 * alfa))


# LA SALPICADURA al tocar el suelo: una corona de gotitas que saltan y una mancha violeta que se apaga.
func _salpica(capa: Node2D, p: Vector2, u: float, tam: float) -> void:
	if u < 0.0 or u > 1.0:
		return
	if capa == _suelo:
		MagiaMayor._disco(capa, p, (4.0 + 6.0 * u) * tam, Color(SAVIA, 0.55 * (1.0 - u)), Color(VIOLETA, 0.0), 0.5)
	elif capa == _delante:
		for j in 5:
			var a: float = PI + PI * (float(j) + 0.5) / 5.0
			var q: Vector2 = p + Vector2(cos(a) * 9.0 * u * tam, -10.0 * tam * sin(PI * u) + sin(a) * 2.0)
			capa.draw_circle(q, 1.1 * tam * (1.0 - u * 0.5), Color(SAVIA, 1.0 - u))
	elif capa == _brillo:
		capa.draw_circle(p, 5.0 * tam * (1.0 - u), Color(VIOLETA, 0.35 * (1.0 - u)))


# ------------------------------------------------------------
#  EL GEISER
# ------------------------------------------------------------
const ALTO_CHORRO := 120.0

# EL CHORRO: sale de la grieta y sube (0..1 = 'sube'); despues la cola se despega y sube detras ('suelta' 0..1).
func _chorro(capa: Node2D, sube: float, suelta: float, ancho: float) -> Vector2:
	var arriba: Vector2 = _o + Vector2(0.0, -ALTO_CHORRO * sube)
	if sube <= 0.0 or suelta >= 1.0:
		return arriba
	var cola: Vector2 = _o.lerp(arriba, suelta)
	var pts := PackedVector2Array()
	var an := PackedFloat32Array()
	for i in 9:
		var u: float = float(i) / 8.0
		var p: Vector2 = cola.lerp(arriba, u) + Vector2(sin(u * 7.0 + _t * 20.0) * 1.6, 0.0)
		pts.append(p)
		an.append(ancho * (0.7 + 0.5 * u))
	if capa == _delante:
		_cinta(capa, pts, an, Color(SAVIA, 1.0))
		# el filo claro (la pincelada) a un lado
		var filo := PackedVector2Array()
		for p in pts:
			filo.append(p + Vector2(-ancho * 0.28, 0.0))
		var anf := PackedFloat32Array()
		for a in an:
			anf.append(a * 0.22)
		_cinta(capa, filo, anf, Color(BORDE, 0.85))
		capa.draw_circle(arriba, ancho * 0.75, Color(SAVIA, 1.0))
	elif capa == _brillo:
		capa.draw_circle(_o, ancho * 1.6 * (1.0 - suelta), Color(VIOLETA, 0.5 * (1.0 - suelta)))
	return arriba


func _geiser(capa: Node2D) -> void:
	var sube: float = clampf((_t - T_SALE) / 0.25, 0.0, 1.0)
	var suelta: float = clampf((_t - T_SALE - 0.22) / 0.25, 0.0, 1.0)
	# LA SOMBRA del area: se oscurece mientras sube (avisa de donde va a caer) y se apaga al final.
	if capa == _suelo:
		var aviso: float = clampf((_t - T_SALE) / 0.4, 0.0, 1.0) * (1.0 - clampf((_t - 1.35) / 0.3, 0.0, 1.0))
		MagiaMayor._disco(capa, _c, _r, Color(NEGRO, 0.22 * aviso), Color(NEGRO, 0.05 * aviso), 0.6)
	match version:
		0: _geiser_gotas(capa, sube, suelta)
		1: _geiser_nube(capa, sube, suelta)
		_: _geiser_brazos(capa, sube, suelta)


# A: el chorro sube y se va; las GOTAS gordas caen sobre el area con su salpicadura.
func _geiser_gotas(capa: Node2D, sube: float, suelta: float) -> void:
	_chorro(capa, sube, suelta, 7.0)
	for p in _piezas:
		var u: float = (_t - float(p["t0"])) / 0.28
		var tam: float = float(p["tam"])
		var en: Vector2 = p["en"]
		if u >= 0.0 and u < 1.0 and capa == _delante:
			_gota(capa, en + Vector2(0.0, -150.0 * (1.0 - u * u)), 3.2 * tam, 1.4 + u, 1.0)
		elif u >= 1.0:
			_salpica(capa, en, (_t - float(p["t0"]) - 0.28) / 0.35, tam)


# B: el chorro sube y en lo alto forma una NUBE de savia sobre el area que llueve y se deshace.
func _geiser_nube(capa: Node2D, sube: float, suelta: float) -> void:
	var arriba: Vector2 = _chorro(capa, sube, suelta, 6.0)
	var cielo: Vector2 = _c + Vector2(0.0, -ALTO_CHORRO * 0.85)
	var forma: float = clampf((_t - T_SALE - 0.2) / 0.3, 0.0, 1.0)
	var deshace: float = clampf((_t - 1.3) / 0.35, 0.0, 1.0)
	if forma > 0.0 and deshace < 1.0 and capa != _suelo:
		var centro: Vector2 = arriba.lerp(cielo, forma)
		for j in 7:
			var a: float = TAU * float(j) / 7.0 + 0.3
			var q: Vector2 = centro + Vector2(cos(a) * _r * 0.6, sin(a) * 6.0) * forma
			var rr: float = (9.0 + 3.0 * sin(float(j) * 2.1 + _t * 3.0)) * forma * (1.0 - deshace * 0.6)
			if capa == _delante:
				MagiaMayor._disco(capa, q, rr, Color(SAVIA, 1.0 - deshace), Color(NEGRO, 0.9 * (1.0 - deshace)))
				capa.draw_circle(q + Vector2(-rr * 0.3, -rr * 0.35), rr * 0.35, Color(BORDE, 0.5 * (1.0 - deshace)))
			else:
				capa.draw_circle(q + Vector2(0, rr * 0.5), rr * 0.6, Color(VIOLETA, 0.12 * (1.0 - deshace)))
	for p in _piezas:
		var u: float = (_t - float(p["t0"])) / 0.22
		var en: Vector2 = p["en"]
		var desde: Vector2 = Vector2(en.x, cielo.y + 8.0)
		if u >= 0.0 and u < 1.0 and capa == _delante:
			_gota(capa, desde.lerp(en, u * u), 1.6 * float(p["tam"]), 2.4, 1.0)
		elif u >= 1.0:
			_salpica(capa, en, (_t - float(p["t0"]) - 0.22) / 0.3, 0.6 * float(p["tam"]))


# C: el chorro se abre arriba en BRAZOS de tinta que se curvan y caen como latigos, cada uno sobre un punto del area.
func _geiser_brazos(capa: Node2D, sube: float, suelta: float) -> void:
	var arriba: Vector2 = _chorro(capa, sube, 0.0 if _t < 1.2 else clampf((_t - 1.2) / 0.3, 0.0, 1.0), 8.0)
	for p in _piezas:
		var t0: float = float(p["t0"])
		var u: float = clampf((_t - t0) / 0.25, 0.0, 1.0)
		var vuelve: float = clampf((_t - t0 - 0.45) / 0.3, 0.0, 1.0)
		var en: Vector2 = p["en"]
		if _t < t0 - 0.1:
			continue
		if capa == _delante and vuelve < 1.0:
			# el brazo: de lo alto del chorro, arqueado hacia fuera, hasta el punto; crece a lo largo y se recoge
			var ctrl: Vector2 = arriba.lerp(en, 0.5) + Vector2(float(p["lado"]) * 40.0, -50.0)
			var hasta: float = u * (1.0 - vuelve)
			var pts := PackedVector2Array()
			var an := PackedFloat32Array()
			for i in 12:
				var s: float = float(i) / 11.0 * hasta
				var q: Vector2 = arriba.lerp(ctrl, s).lerp(ctrl.lerp(en, s), s)
				pts.append(q)
				an.append(lerpf(6.0, 2.0, s) * (1.0 - vuelve * 0.5))
			_cinta(capa, pts, an, Color(SAVIA, 1.0))
		if u >= 1.0:
			_salpica(capa, en, (_t - t0 - 0.25) / 0.4, 1.4)


# ------------------------------------------------------------
#  CHUPAR
# ------------------------------------------------------------
func _chupar(capa: Node2D) -> void:
	match version:
		0: _chupar_hilos(capa)
		1: _chupar_espiral(capa)
		_: _chupar_raiz(capa)


# El camino por el suelo de la victima a sus pies, ondulado ('curva' de -1 a 1 lo tuerce a un lado).
func _camino(u: float, curva: float, onda: float) -> Vector2:
	var d: Vector2 = _c - _o
	var n: Vector2 = d.orthogonal().normalized() * Vector2(1.0, 0.6)
	return _o.lerp(_c, u) + n * (sin(PI * u) * curva * 14.0 + sin(u * 9.0 + onda) * 2.0)


# A: HILOS violeta que reptan de la victima a sus pies y BOLITAS de luz que suben por ellos.
func _chupar_hilos(capa: Node2D) -> void:
	var crece: float = clampf(_t / 0.35, 0.0, 1.0)
	var apaga: float = clampf((_t - 1.0) / 0.3, 0.0, 1.0)
	for p in _piezas:
		var curva: float = float(p["curva"])
		var fase: float = float(p["fase"])
		if capa == _suelo:
			var pts := PackedVector2Array()
			var an := PackedFloat32Array()
			for i in 16:
				var u: float = float(i) / 15.0 * crece
				pts.append(_camino(u, curva, fase + _t * 4.0))
				an.append(1.8)
			_cinta(capa, pts, an, Color(SAVIA, 0.9 * (1.0 - apaga)))
		elif capa == _brillo:
			var pts2 := PackedVector2Array()
			var an2 := PackedFloat32Array()
			for i in 16:
				var u2: float = float(i) / 15.0 * crece
				pts2.append(_camino(u2, curva, fase + _t * 4.0))
				an2.append(0.8)
			_cinta(capa, pts2, an2, Color(VIOLETA, 0.6 * (1.0 - apaga)))
			for j in 2:
				var ub: float = (_t - 0.3 - float(j) * 0.25 - float(p["k"]) * 0.08) / 0.5
				if ub < 0.0 or ub > 1.0:
					continue
				var q: Vector2 = _camino(ub, curva, fase + _t * 4.0)
				capa.draw_circle(q, 2.6, Color(VIOLETA, 0.5))
				capa.draw_circle(q, 1.3, Color(LUZ, 0.9))
	if capa == _brillo:
		var llega: float = clampf((_t - 0.75) / 0.4, 0.0, 1.0) * (1.0 - apaga)
		capa.draw_circle(_c, 8.0 * llega, Color(VIOLETA, 0.3 * llega))


# B: un REMOLINO oscuro sobre la victima (cuñas que giran y se cierran) y MOTAS que salen en espiral y vuelan a el.
func _chupar_espiral(capa: Node2D) -> void:
	var abre: float = clampf(_t / 0.25, 0.0, 1.0) * (1.0 - clampf((_t - 1.0) / 0.3, 0.0, 1.0))
	var sobre: Vector2 = _o + Vector2(0.0, -14.0)
	if capa == _delante and abre > 0.0:
		for j in 5:
			var a: float = TAU * float(j) / 5.0 + _t * 7.0
			MagiaMayor._cuna(capa, sobre, a, 2.0, 13.0 * abre, 0.6, Color(SAVIA, 0.85 * abre), 0.6)
	for p in _piezas:
		var u: float = (_t - float(p["t0"])) / 0.7
		if u < 0.0 or u > 1.0:
			continue
		var giro: float = float(p["fase"]) + u * 9.0
		var rr: float = 12.0 * (1.0 - u)
		var hacia: Vector2 = sobre.lerp(_c + Vector2(0.0, -30.0), u * u)
		var q: Vector2 = hacia + Vector2(cos(giro), sin(giro) * 0.5) * rr - Vector2(0.0, 18.0 * sin(PI * u))
		if capa == _brillo:
			capa.draw_circle(q, 2.4, Color(VIOLETA, 0.45 * (1.0 - u * 0.4)))
			capa.draw_circle(q, 1.1, Color(LUZ, 0.9))


# C: una RAIZ negra que asoma del suelo entre los dos (ondulada, gorda, con el filo violeta) y LATE: bultos de luz que
# viajan por ella hasta sus pies. En la victima, tres garfios de raiz que la agarran.
func _chupar_raiz(capa: Node2D) -> void:
	var asoma: float = clampf(_t / 0.3, 0.0, 1.0)
	var hunde: float = clampf((_t - 1.0) / 0.3, 0.0, 1.0)
	var grosor: float = 4.0 * asoma * (1.0 - hunde)
	var pts := PackedVector2Array()
	var an := PackedFloat32Array()
	for i in 20:
		var u: float = float(i) / 19.0
		pts.append(_camino(u, 0.6, 1.0) - Vector2(0.0, 2.0 * sin(PI * u) * asoma))
		var late: float = 0.0
		for p in _piezas:
			var ul: float = (_t - 0.25 - float(p["k"]) * 0.14) / 0.45
			late += 2.2 * exp(-pow((u - ul) / 0.06, 2.0))
		an.append(grosor * (0.8 + 0.3 * sin(u * 11.0)) + late * (1.0 - hunde))
	if capa == _delante:
		_cinta(capa, pts, an, Color(SAVIA, 1.0))
		var filo := PackedVector2Array()
		var anf := PackedFloat32Array()
		for i in pts.size():
			filo.append(pts[i] + Vector2(0.0, -an[i] * 0.3))
			anf.append(an[i] * 0.25)
		_cinta(capa, filo, anf, Color(BORDE, 0.8))
		for j in 3:
			var a: float = -PI * 0.5 + (float(j) - 1.0) * 0.9
			var b: Vector2 = _o + Vector2(cos(a) * 3.0, 2.0)
			var garfio := PackedVector2Array([b, b + Vector2(cos(a) * 7.0, sin(a) * 9.0) * asoma * (1.0 - hunde),
				b + Vector2(cos(a) * 9.0 + 2.0, sin(a) * 6.0) * asoma * (1.0 - hunde)])
			var ang := PackedFloat32Array([2.4 * (1.0 - hunde), 1.4, 0.4])
			_cinta(capa, garfio, ang, Color(SAVIA, 1.0))
	elif capa == _brillo:
		for p in _piezas:
			var ul2: float = (_t - 0.25 - float(p["k"]) * 0.14) / 0.45
			if ul2 < 0.0 or ul2 > 1.0:
				continue
			var q: Vector2 = _camino(ul2, 0.6, 1.0) - Vector2(0.0, 2.0 * sin(PI * ul2))
			capa.draw_circle(q, 3.2, Color(VIOLETA, 0.5))
			capa.draw_circle(q, 1.4, Color(LUZ, 0.9))
			if ul2 > 0.9:
				capa.draw_circle(_c, 9.0 * (ul2 - 0.9) * 10.0, Color(VIOLETA, 0.25))
