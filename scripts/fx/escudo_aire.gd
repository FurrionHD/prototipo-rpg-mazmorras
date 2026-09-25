# ============================================================
#  escudo_aire.gd
#  LOS EFECTOS DEL ESCUDO en el mapa (25/09/2026, con la espada larga). Mismas piezas que los que le gustan
#  (EspadaAire, HachaAire, BarridoAire): bandas rellenas que se difuminan, destellos en estrella, cometas y
#  polvo. NADA DE LINEAS (efectos-sin-lineas). Coordenadas de MUNDO; todo sale de una semilla.
#    ESCUDAZO   un golpe de escudo sobre un cuerpo (el Golpe de escudo, el segundo de la Guardia rota, el
#               contraataque de la Postura de rodela): la CHAPA que se estampa de plano -- un fantasma del
#               escudo, de canto segun de donde venga el golpe --, un destello seco, una onda de aire en media
#               luna que sale por detras del cuerpo, esquirlas y polvo a los pies.
# ============================================================
extends Node2D
class_name EscudoAire

enum Modo { ESCUDAZO }

const T_LLEGA := 0.06        # lo que tarda la chapa en estamparse (sale de antes del golpe)
const T_CHAPA := 0.22        # lo que se queda la chapa despues del golpe, apagandose
const T_ONDA := 0.2          # la onda de aire que sale por detras
const T_POLVO := 0.45
const ALTO_TORSO := 14.0

const BLANCO := BarridoAire.BLANCO
const AIRE := BarridoAire.AIRE
const ACERO := Color(0.80, 0.84, 0.90)
const CHAPA := Color(0.62, 0.68, 0.78)
const POLVO := SueloRoto.POLVO
const Z_ENCIMA := Game.Z_PERSONAJES + 80

var modo: int = Modo.ESCUDAZO
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _caja: Rect2 = Rect2()
var _fallo: bool = false
var _crit: bool = false
var _n: int = 0
var _c: Vector2 = Vector2.ZERO        # el pecho del que lo encaja
var _toque: Vector2 = Vector2.ZERO    # donde se estampa la chapa: la cara del cuerpo que mira a quien pega
var _pies: Vector2 = Vector2.ZERO
var _dir: Vector2 = Vector2.RIGHT     # de quien pega al que lo encaja
var _lat: Vector2 = Vector2.RIGHT     # lo ancho de la chapa: de lado respecto al golpe, con la perspectiva
var _giro: float = 0.0
var _esquirlas: Array = []
var _suelo: Node2D = null


# UN ESCUDAZO sobre un cuerpo (como EspadaAire.golpe): 'desde' = el pecho del que pega; 'espera' = hasta el golpe.
static func golpe(padre: Node, m: int, desde: Vector2, caja: Rect2, fallo: bool, crit: bool, n: int,
		semilla: int, espera: float, ritmo: float) -> EscudoAire:
	if padre == null:
		return null
	var e := EscudoAire.new()
	e.modo = m
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS   # la pelea tactica pausa el arbol
	padre.add_child(e)
	e._caja = caja
	e._fallo = fallo
	e._crit = crit
	e._n = n
	e._t = -maxf(espera, 0.0)
	e._c = caja.get_center() if caja.has_area() else desde
	e._pies = Vector2(e._c.x, caja.end.y) if caja.has_area() else e._c + Vector2(0.0, ALTO_TORSO)
	e._dir = (e._c - desde).normalized() if e._c.distance_squared_to(desde) > 0.01 else Vector2.RIGHT
	e._preparar()
	return e


func duracion() -> float:
	return maxf(T_POLVO, T_CHAPA + T_ONDA) + 0.1


func _preparar() -> void:
	# LO ANCHO DE LA CHAPA: la perpendicular al golpe en el suelo, achatada como el suelo a 45 grados (la misma
	# cuenta que la pincelada de EspadaAire), asi que de frente se ve ancha y de lado se ve de canto.
	const K := 0.7071
	_lat = Vector2(-_dir.y, _dir.x * K)
	if _lat.length_squared() < 0.001:
		_lat = Vector2.RIGHT
	_giro = _rng.randf_range(-0.25, 0.25)   # cada escudazo entra un pelo ladeado a su manera
	var medio: float = (_caja.size.x * 0.5) if _caja.has_area() else 7.0
	_toque = _c - Vector2(_dir.x, _dir.y * K) * (medio + 1.0)
	if _fallo:
		_toque += _lat.normalized() * (medio + 6.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
	for i in 5:
		# Rebotan hacia los LADOS de la chapa (no todas al mismo sitio) y un poco hacia quien pega.
		var lado_e: float = 1.0 if i % 2 == 0 else -1.0
		var sale: Vector2 = _lat.normalized() * lado_e * _rng.randf_range(0.6, 1.0) \
			- Vector2(_dir.x, _dir.y * K) * _rng.randf_range(0.1, 0.5)
		_esquirlas.append({"v": sale.normalized() * _rng.randf_range(120.0, 170.0)
			+ Vector2(0.0, -_rng.randf_range(20.0, 60.0)), "tam": _rng.randf_range(1.4, 2.0),
			"desde": _rng.randf_range(4.0, 8.0)})
	_suelo = Node2D.new()
	_suelo.z_as_relative = false
	_suelo.z_index = SueloRoto.Z_SUELO
	add_child(_suelo)
	_suelo.draw.connect(_dibujar_polvo)


func _process(delta: float) -> void:
	_t += delta * _ritmo
	if _t >= duracion():
		queue_free()
		return
	queue_redraw()
	if _suelo != null:
		_suelo.queue_redraw()


func _draw() -> void:
	if _t < -T_LLEGA:
		return
	_dibujar_chapa()
	if _t < 0.0 or _fallo:
		return
	_dibujar_onda()
	# El destello, PEQUEÑO y seco: lo que tiene que leerse es la chapa, no la estrella.
	var pulso: float = exp(-_t / 0.04)
	if pulso > 0.04:
		BarridoAire.destello(self, _toque, (6.0 if not _crit else 9.0) + 6.0 * pulso, Color(BLANCO, pulso),
			_giro + 0.3)
	var gr: float = 380.0
	for es in _esquirlas:
		if _t > 0.28:
			break
		var v: Vector2 = es["v"]
		var q: Vector2 = _toque + v.normalized() * float(es["desde"]) + v * _t + Vector2(0.0, 0.5 * gr * _t * _t)
		var vel: Vector2 = v + Vector2(0.0, gr * _t)
		BarridoAire.cometa(self, q - vel.normalized() * 8.0, q, float(es["tam"]),
			Color(BLANCO, 0.9 * (1.0 - _t / 0.28)))


# LA CHAPA: un ovalo relleno en el plano del escudo (ancho de lado, alto de pie), claro en medio y a nada en
# el borde. Llega de un palmo hacia quien pega y se estampa en el golpe; luego se apaga.
func _dibujar_chapa() -> void:
	var llega: float = clampf((_t + T_LLEGA) / T_LLEGA, 0.0, 1.0)
	var apaga: float = clampf(_t / T_CHAPA, 0.0, 1.0) if _t > 0.0 else 0.0
	var alfa: float = (0.45 if _fallo else 0.95) * llega * (1.0 - apaga * apaga)
	if alfa <= 0.01:
		return
	var atras: Vector2 = -Vector2(_dir.x, _dir.y * 0.7071) * 10.0 * (1.0 - llega * llega)
	var c: Vector2 = _toque + atras
	# Se aplasta un poco al estamparse y crece al irse.
	var ancho: Vector2 = _lat.normalized() * _lat.length() * (11.0 + 3.0 * apaga)
	var alto: Vector2 = Vector2(sin(_giro), -cos(_giro)) * (13.0 + 2.0 * apaga)
	var centro_col := Color(BLANCO, alfa)
	var medio_col := Color(CHAPA, alfa * 0.85)
	var borde := Color(CHAPA, 0.0)
	var n: int = 20
	for i in n:
		var a0: float = TAU * float(i) / float(n)
		var a1: float = TAU * float(i + 1) / float(n)
		var e0: Vector2 = ancho * cos(a0) + alto * sin(a0)
		var e1: Vector2 = ancho * cos(a1) + alto * sin(a1)
		draw_primitive(PackedVector2Array([c, c + e0 * 0.75, c + e1 * 0.75]),
			PackedColorArray([centro_col, medio_col, medio_col]), PackedVector2Array())
		draw_primitive(PackedVector2Array([c + e0 * 0.75, c + e0, c + e1]),
			PackedColorArray([medio_col, borde, borde]), PackedVector2Array())
		draw_primitive(PackedVector2Array([c + e0 * 0.75, c + e1, c + e1 * 0.75]),
			PackedColorArray([medio_col, borde, medio_col]), PackedVector2Array())
	# EL UMBO: un brillo en medio, que es lo que hace que se lea "escudo" y no "mancha".
	BarridoAire.brillo(self, c, 4.5, Color(BLANCO, alfa))


# LA ONDA DE AIRE: una media luna rellena que sale por DETRAS del cuerpo (hacia donde va el golpe) y se
# abre, del filo claro a nada. Con la perspectiva del suelo.
func _dibujar_onda() -> void:
	var k: float = clampf(_t / T_ONDA, 0.0, 1.0)
	if k >= 1.0:
		return
	var r: float = lerpf(8.0, 30.0 if not _crit else 38.0, 1.0 - pow(1.0 - k, 2.0))
	var grueso: float = lerpf(9.0, 3.0, k)
	var alfa: float = 0.95 * (1.0 - k)
	var base: float = _dir.angle()
	var n: int = 14
	var mitad: float = deg_to_rad(70.0)
	for i in n:
		var s0: float = float(i) / float(n)
		var s1: float = float(i + 1) / float(n)
		var a0: float = base - mitad + 2.0 * mitad * s0
		var a1: float = base - mitad + 2.0 * mitad * s1
		var u0 := Vector2(cos(a0), sin(a0) * 0.7071)
		var u1 := Vector2(cos(a1), sin(a1) * 0.7071)
		var l0: float = alfa * sin(PI * s0)
		var l1: float = alfa * sin(PI * s1)
		var f0: Vector2 = _c + u0 * r
		var f1: Vector2 = _c + u1 * r
		var d0: Vector2 = _c + u0 * (r - grueso)
		var d1: Vector2 = _c + u1 * (r - grueso)
		var c0 := Color(BLANCO, l0)
		var c1 := Color(BLANCO, l1)
		var t0 := Color(AIRE, 0.0)
		draw_primitive(PackedVector2Array([f0, f1, d1]), PackedColorArray([c0, c1, t0]), PackedVector2Array())
		draw_primitive(PackedVector2Array([f0, d1, d0]), PackedColorArray([c0, t0, t0]), PackedVector2Array())


# EL POLVO a los pies: el cuerpo encaja el golpe y arrastra los pies hacia atras.
func _dibujar_polvo() -> void:
	if _fallo or _t < 0.0:
		return
	var k: float = clampf(_t / T_POLVO, 0.0, 1.0)
	if k >= 1.0:
		return
	var atras: Vector2 = Vector2(_dir.x, _dir.y * 0.7071)
	for j in 3:
		var lado: float = float(j - 1)
		var q: Vector2 = _pies + atras * (3.0 + 10.0 * k) + _lat.normalized() * lado * (4.0 + 5.0 * k) \
			+ Vector2(0.0, -1.5 * float(j % 2) * k)
		BarridoAire.brillo(_suelo, q, 4.0 + 5.0 * k, Color(POLVO, 0.5 * (1.0 - k)))
