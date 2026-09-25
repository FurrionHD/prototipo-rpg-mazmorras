# ============================================================
#  escudo_aire.gd
#  LOS EFECTOS DEL ESCUDO en el mapa (25/09/2026, con la espada larga). Mismas piezas que los que le gustan
#  (EspadaAire, HachaAire, BarridoAire): bandas rellenas que se difuminan, destellos en estrella, cometas y
#  polvo. NADA DE LINEAS (efectos-sin-lineas). Coordenadas de MUNDO; todo sale de una semilla.
#    ONDA       el Golpe de escudo (SueloRoto.Tipo.ESCUDO_ONDA): UN escudazo -- la CHAPA que se estampa delante de
#               ti, una sola vez -- y una ONDA DE CHOQUE en media luna que sale hacia delante y cruza la huella.
#               A cada uno le llega cuando la onda le pasa. (La v1 ponia una chapa sobre cada enemigo: "estoy dando
#               un escudazo, no 3 o 4", 25/09.)
#    ESCUDAZO   lo que se ve sobre CADA cuerpo que lo encaja: el impacto (destello pequeño, esquirlas a los lados,
#               el aire que sale por detras y polvo a los pies). Con 'chapa' ademas la chapa DELANTE DE QUIEN PEGA:
#               el escudazo suelto (segundo golpe de la Guardia rota, contraataque de la rodela), que no tiene onda.
#    EMBESTIDA  el choque al llegar de la carga (el rastro del cuerpo lo pone el desliz, EstoqueAire.rastro): la
#               chapa pegada al enemigo (quien pega aun va de camino cuando esto se pide) y todo mas gordo.
# ============================================================
extends Node2D
class_name EscudoAire

enum Modo { ESCUDAZO, ONDA, EMBESTIDA }

const T_LLEGA := 0.06        # lo que tarda la chapa en estamparse (sale de antes del golpe)
const T_CHAPA := 0.22        # lo que se queda la chapa despues del golpe, apagandose
const T_ONDA := 0.2          # el aire que sale por detras del cuerpo
const T_CHOQUE := 0.16       # lo que tarda la onda de choque en llegar al borde de la huella
const T_ONDA_APAGA := 0.12   # y en irse al llegar
const T_POLVO := 0.45
const ALTO_TORSO := 14.0
const ALTO_ONDA := 9.0       # la onda va por el aire, a media altura
const K := 0.7071            # el suelo a 45 grados

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
var _con_chapa: bool = false
var _fuerza: float = 1.0              # la Embestida: todo mas gordo
var _c: Vector2 = Vector2.ZERO        # el pecho del que lo encaja
var _toque: Vector2 = Vector2.ZERO    # donde se ve el golpe en el cuerpo: su cara que mira a quien pega
var _chapa_en: Vector2 = Vector2.ZERO # donde se estampa la chapa: delante de quien pega
var _pies: Vector2 = Vector2.ZERO
var _dir: Vector2 = Vector2.RIGHT     # de quien pega al que lo encaja
var _lat: Vector2 = Vector2.RIGHT     # lo ancho de la chapa: de lado respecto al golpe, con la perspectiva
var _giro: float = 0.0
var _esquirlas: Array = []
var _suelo: Node2D = null
# La onda.
var forma: CombatFormas.Forma = null
var _origen: Vector2 = Vector2.ZERO
var _atras: Node2D = null
var _delante: Node2D = null
var _polvo: Array = []


# ------------------------------------------------------------
#  LA ONDA DE CHOQUE (Golpe de escudo, por SueloRoto)
# ------------------------------------------------------------
# 'espera' = segundos hasta el golpe (la chapa se estampa en el golpe y la onda sale de ahi).
static func onda(padre: Node, f: CombatFormas.Forma, semilla: int, espera: float) -> EscudoAire:
	if padre == null or f == null:
		return null
	var e := EscudoAire.new()
	e.modo = Modo.ONDA
	e.forma = f
	e._rng.seed = semilla
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	e._t = -espera * e._ritmo
	e.z_as_relative = false
	e.z_index = SueloRoto.Z_SUELO
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	return e


# De donde sale: los pies de quien pega en el cono; en el punto (el escudo pequeño), un palmo antes de el.
static func origen_onda(f: CombatFormas.Forma) -> Vector2:
	if f.tipo == CombatFormas.Tipo.CONO:
		return f.origen
	return f.centro - f.dir.normalized() * 12.0


# Hasta donde llega y lo abierta que va.
static func _radio_onda(f: CombatFormas.Forma) -> float:
	return f.radio if f.tipo == CombatFormas.Tipo.CONO else f.radio + 12.0


# CUANDO LE LLEGA a 'p': el frente va a r = R * (1 - (1 - k)^2), asi que le llega en k = 1 - sqrt(1 - u).
static func retraso(f: CombatFormas.Forma, p: Vector2) -> float:
	var u: float = clampf(p.distance_to(origen_onda(f)) / maxf(_radio_onda(f), 1.0), 0.0, 1.0)
	return T_CHOQUE * (1.0 - sqrt(1.0 - u))


# ------------------------------------------------------------
#  EL ESCUDAZO SOBRE UN CUERPO
# ------------------------------------------------------------
# 'desde' = el pecho del que pega; 'espera' = hasta el golpe. 'chapa' = pinta tambien la chapa delante de quien
# pega (el escudazo suelto, sin onda).
static func golpe(padre: Node, m: int, desde: Vector2, caja: Rect2, fallo: bool, crit: bool, n: int,
		semilla: int, espera: float, ritmo: float, chapa: bool = false) -> EscudoAire:
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
	e._con_chapa = chapa
	e._t = -maxf(espera, 0.0)
	e._c = caja.get_center() if caja.has_area() else desde
	e._pies = Vector2(e._c.x, caja.end.y) if caja.has_area() else e._c + Vector2(0.0, ALTO_TORSO)
	e._dir = (e._c - desde).normalized() if e._c.distance_squared_to(desde) > 0.01 else Vector2.RIGHT
	e._chapa_en = desde + Vector2(e._dir.x, e._dir.y * K) * 9.0
	e._preparar()
	if m == Modo.EMBESTIDA:
		# Quien embiste aun va de camino: la chapa, pegada a la cara del que lo encaja.
		e._fuerza = 1.35
		e._con_chapa = true
		e._chapa_en = e._toque - Vector2(e._dir.x, e._dir.y * K) * 5.0
	return e


func duracion() -> float:
	if modo == Modo.ONDA:
		return T_CHOQUE + T_ONDA_APAGA + T_POLVO + 0.1
	return maxf(T_POLVO, T_CHAPA + T_ONDA) + 0.1


func _preparar() -> void:
	# LO ANCHO DE LA CHAPA: la perpendicular al golpe en el suelo, achatada como el suelo a 45 grados (la misma
	# cuenta que la pincelada de EspadaAire), asi que de frente se ve ancha y de lado se ve de canto.
	_lat = Vector2(-_dir.y, _dir.x * K)
	if _lat.length_squared() < 0.001:
		_lat = Vector2.RIGHT
	_giro = _rng.randf_range(-0.25, 0.25)   # cada escudazo entra un pelo ladeado a su manera
	var medio: float = (_caja.size.x * 0.5) if _caja.has_area() else 7.0
	_toque = _c - Vector2(_dir.x, _dir.y * K) * (medio + 1.0)
	if _fallo:
		_toque += _lat.normalized() * (medio + 6.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
	for i in 5:
		# Rebotan hacia los LADOS (no todas al mismo sitio) y un poco hacia quien pega.
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


func _ready() -> void:
	if modo != Modo.ONDA:
		return
	_origen = origen_onda(forma)
	_dir = forma.dir.normalized() if forma.dir.length_squared() > 0.0001 else Vector2.RIGHT
	_lat = Vector2(-_dir.y, _dir.x * K)
	if _lat.length_squared() < 0.001:
		_lat = Vector2.RIGHT
	_giro = _rng.randf_range(-0.2, 0.2)
	_chapa_en = _origen + _dir * 9.0 + Vector2(0.0, -ALTO_TORSO)
	_atras = _capa(Game.Z_PERSONAJES - 1)
	_delante = _capa(Game.Z_PERSONAJES + 80)
	for i in 12:
		_polvo.append({"u": (float(i) + _rng.randf_range(0.0, 1.0)) / 12.0, "sale": _rng.randf_range(4.0, 10.0),
			"tam": _rng.randf_range(4.0, 7.0)})


func _capa(z: int) -> Node2D:
	var n := Node2D.new()
	n.z_as_relative = false
	n.z_index = z
	add_child(n)
	n.draw.connect(_dibujar_capa.bind(n))
	return n


func _process(delta: float) -> void:
	_t += delta * _ritmo
	if _t >= duracion():
		queue_free()
		return
	queue_redraw()
	if _suelo != null:
		_suelo.queue_redraw()
	if _atras != null:
		_atras.queue_redraw()
		_delante.queue_redraw()


func _draw() -> void:
	if modo == Modo.ONDA:
		_dibujar_polvo_onda()
		return
	if _con_chapa:
		_dibujar_chapa(_chapa_en, _lat, _fuerza)
	if _t < 0.0 or _fallo:
		return
	# El aire por detras del cuerpo solo en el escudazo SUELTO: en el Golpe de escudo ya esta la onda, y un arco
	# por cada enemigo ensuciaba la suya.
	if _con_chapa:
		_dibujar_aire()
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


# LA CHAPA: un ovalo relleno en el plano del escudo (ancho de lado, alto de pie), claro en medio con el umbo y a
# nada en el borde. Llega de un palmo mas atras y se estampa en el golpe; luego se apaga. 'ci' = donde se pinta.
func _dibujar_chapa(en: Vector2, lat: Vector2, escala: float, ci: CanvasItem = null) -> void:
	if ci == null:
		ci = self
	if _t < -T_LLEGA:
		return
	var llega: float = clampf((_t + T_LLEGA) / T_LLEGA, 0.0, 1.0)
	var apaga: float = clampf(_t / T_CHAPA, 0.0, 1.0) if _t > 0.0 else 0.0
	var alfa: float = (0.45 if _fallo else 0.95) * llega * (1.0 - apaga * apaga)
	if alfa <= 0.01:
		return
	var atras: Vector2 = -Vector2(_dir.x, _dir.y * K) * 10.0 * (1.0 - llega * llega)
	var c: Vector2 = en + atras
	var ancho: Vector2 = lat.normalized() * lat.length() * (11.0 + 3.0 * apaga) * escala
	var alto: Vector2 = Vector2(sin(_giro), -cos(_giro)) * (13.0 + 2.0 * apaga) * escala
	var centro_col := Color(BLANCO, alfa)
	var medio_col := Color(CHAPA, alfa * 0.85)
	var borde := Color(CHAPA, 0.0)
	var n: int = 20
	for i in n:
		var a0: float = TAU * float(i) / float(n)
		var a1: float = TAU * float(i + 1) / float(n)
		var e0: Vector2 = ancho * cos(a0) + alto * sin(a0)
		var e1: Vector2 = ancho * cos(a1) + alto * sin(a1)
		ci.draw_primitive(PackedVector2Array([c, c + e0 * 0.75, c + e1 * 0.75]),
			PackedColorArray([centro_col, medio_col, medio_col]), PackedVector2Array())
		ci.draw_primitive(PackedVector2Array([c + e0 * 0.75, c + e0, c + e1]),
			PackedColorArray([medio_col, borde, borde]), PackedVector2Array())
		ci.draw_primitive(PackedVector2Array([c + e0 * 0.75, c + e1, c + e1 * 0.75]),
			PackedColorArray([medio_col, borde, medio_col]), PackedVector2Array())
	# EL UMBO: un brillo en medio, que es lo que hace que se lea "escudo" y no "mancha".
	BarridoAire.brillo(ci, c, 4.5 * escala, Color(BLANCO, alfa))
	# Y en el golpe, el destello seco del choque.
	if _t >= 0.0:
		var pulso: float = exp(-_t / 0.04)
		if pulso > 0.04:
			BarridoAire.destello(ci, c + Vector2(_dir.x, _dir.y * K) * 4.0, 7.0 + 6.0 * pulso, Color(BLANCO, pulso),
				_giro + 0.3)


# EL AIRE que sale por DETRAS del cuerpo que lo encaja: una media luna rellena que se abre, del filo claro a nada.
func _dibujar_aire() -> void:
	var k: float = clampf(_t / T_ONDA, 0.0, 1.0)
	if k >= 1.0:
		return
	var r: float = lerpf(8.0, (30.0 if not _crit else 38.0) * _fuerza, 1.0 - pow(1.0 - k, 2.0))
	var grueso: float = lerpf(9.0, 3.0, k) * _fuerza
	var alfa: float = 0.95 * (1.0 - k)
	var base: float = _dir.angle()
	var mitad: float = deg_to_rad(70.0)
	var n: int = 14
	for i in n:
		var s0: float = float(i) / float(n)
		var s1: float = float(i + 1) / float(n)
		var a0: float = base - mitad + 2.0 * mitad * s0
		var a1: float = base - mitad + 2.0 * mitad * s1
		var u0 := Vector2(cos(a0), sin(a0) * K)
		var u1 := Vector2(cos(a1), sin(a1) * K)
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
	var atras: Vector2 = Vector2(_dir.x, _dir.y * K)
	for j in 3:
		var lado: float = float(j - 1)
		var q: Vector2 = _pies + atras * (3.0 + 10.0 * k) * _fuerza + _lat.normalized() * lado * (4.0 + 5.0 * k) \
			+ Vector2(0.0, -1.5 * float(j % 2) * k)
		BarridoAire.brillo(_suelo, q, (4.0 + 5.0 * k) * _fuerza, Color(POLVO, 0.5 * (1.0 - k)))


# ------------------------------------------------------------
#  LA ONDA: la chapa delante de ti y la media luna de aire que sale hacia delante
# ------------------------------------------------------------
func _mitad_onda() -> float:
	var ap: float = forma.apertura if forma.tipo == CombatFormas.Tipo.CONO else 50.0
	return deg_to_rad(clampf(ap * 0.5 + 8.0, 25.0, 75.0))


func _en_arco(a: float, r: float, alto: float) -> Vector2:
	return _origen + Vector2(cos(a), sin(a)) * r + Vector2(0.0, -alto)


func _es_mia(capa: Node2D, p: Vector2, alto: float) -> bool:
	return (p.y < _origen.y - alto) == (capa == _atras)


func _dibujar_capa(capa: Node2D) -> void:
	# La chapa, delante de ti. Mirando hacia arriba (de espaldas a la camara) queda DETRAS de tu cuerpo.
	if capa == (_atras if _dir.y < -0.2 else _delante):
		_dibujar_chapa(_chapa_en, _lat, 1.1, capa)
	if _t < 0.0:
		return
	var k: float = clampf(_t / T_CHOQUE, 0.0, 1.0)
	var apaga: float = clampf((_t - T_CHOQUE) / T_ONDA_APAGA, 0.0, 1.0)
	if apaga >= 1.0:
		return
	var R: float = _radio_onda(forma)
	var r: float = lerpf(8.0, R, 1.0 - pow(1.0 - k, 2.0))
	# Gorda al salir y afinandose al llegar; se abre un pelo al irse.
	var grueso: float = lerpf(12.0, 4.0, k) * (1.0 + 0.3 * apaga)
	var alfa: float = 0.95 * (1.0 - apaga)
	var mitad: float = _mitad_onda()
	var base: float = _dir.angle()
	var n: int = maxi(10, int(2.0 * mitad / 0.08))
	for i in n:
		var s0: float = float(i) / float(n)
		var s1: float = float(i + 1) / float(n)
		var a0: float = base - mitad + 2.0 * mitad * s0
		var a1: float = base - mitad + 2.0 * mitad * s1
		var am: float = (a0 + a1) * 0.5
		if not _es_mia(capa, _en_arco(am, r, ALTO_ONDA), ALTO_ONDA):
			continue
		# Mas fuerte en el centro (hacia donde golpeas) y a nada en las puntas.
		var l0: float = alfa * pow(sin(PI * s0), 0.7)
		var l1: float = alfa * pow(sin(PI * s1), 0.7)
		# De fuera hacia dentro: el frente blanco y duro, aire claro, y nada (se difumina hacia ti).
		var fr: Array = [0.0, 0.18, 1.0]
		var cols: Array = [BLANCO, AIRE, AIRE]
		var al: Array = [1.0, 0.6, 0.0]
		for kk in fr.size() - 1:
			var p00: Vector2 = _en_arco(a0, r - grueso * float(fr[kk]), ALTO_ONDA)
			var p10: Vector2 = _en_arco(a1, r - grueso * float(fr[kk]), ALTO_ONDA)
			var p01: Vector2 = _en_arco(a0, r - grueso * float(fr[kk + 1]), ALTO_ONDA)
			var p11: Vector2 = _en_arco(a1, r - grueso * float(fr[kk + 1]), ALTO_ONDA)
			var c00 := Color(cols[kk], l0 * float(al[kk]))
			var c10 := Color(cols[kk], l1 * float(al[kk]))
			var c01 := Color(cols[kk + 1], l0 * float(al[kk + 1]))
			var c11 := Color(cols[kk + 1], l1 * float(al[kk + 1]))
			capa.draw_primitive(PackedVector2Array([p00, p10, p11]), PackedColorArray([c00, c10, c11]), PackedVector2Array())
			capa.draw_primitive(PackedVector2Array([p00, p11, p01]), PackedColorArray([c00, c11, c01]), PackedVector2Array())


# EL POLVO que levanta la onda a su paso por el suelo: nubecillas que se quedan detras del frente y se van.
func _dibujar_polvo_onda() -> void:
	if _t < 0.0:
		return
	var R: float = _radio_onda(forma)
	var mitad: float = _mitad_onda()
	var base: float = _dir.angle()
	for p in _polvo:
		var u: float = float(p["u"])
		var cuando: float = T_CHOQUE * 0.35   # la onda ya ha salido de ti
		var tp: float = _t - cuando
		if tp < 0.0 or tp > T_POLVO:
			continue
		var k: float = tp / T_POLVO
		var a: float = base - mitad * 0.85 + 2.0 * mitad * 0.85 * u
		var r: float = R * (0.35 + 0.5 * absf(sin(u * 7.3))) + float(p["sale"]) * sqrt(k)
		var q: Vector2 = _origen + Vector2(cos(a), sin(a)) * r
		BarridoAire.brillo(self, q, float(p["tam"]) * (1.0 + k), Color(POLVO, 0.35 * (1.0 - k)))
