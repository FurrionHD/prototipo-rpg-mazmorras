# ============================================================
#  rey_aire.gd  (class_name ReyAire)
#  LOS EFECTOS DE LOS MUTANTES DEL REY SLIME en el mapa (07/10/2026: el Rey tirano y el Rey destronado). SUYOS, no las
#  magias nuestras: el CRISTAL de su corona (cian, con el blanco del reflejo, como en su sprite) y el GEL de su cuerpo.
#  Todo relleno y con degradado (sin una sola raya: ver BarridoAire.cometa / brillo / destello).
#  POR EL SUELO (SueloRoto.Tipo.REY_*):
#    ESQUIRLAS  Esquirlas de la corona: trozos de cristal que salen de lo alto (su corona) en abanico, girando con su
#               estela; al caer estallan en un destello y motas de cristal.
#  LO QUE SE QUEDA (piezas: CombatTactico.poner_piezas, charco_estilo 9 y 10; 'queda' / secar como los charcos):
#    CLAVADA    Una esquirla que se queda clavada de punta: vuela en arco desde su corona (f.origen) y se clava; brilla a
#               ratos. Al pisarla (o al secarse) se parte en motas.
#    PEDAZO     Un pedazo de su gel: cae, rebota y se queda temblando, del color de su slime. Al pisarlo se aplasta; si se
#               le vuelve a juntar (volver_a), se desliza hasta el y se encoge.
#  SOBRE EL CUERPO (CombatFX.Estilo.REY_*, ver sobre_cuerpo):
#    DECRETO    Sobre la cabeza del señalado se forma una CORONITA de cristal (las motas se juntan), late y se deshace en
#               motas que caen sobre el.
#    TRIBUTO    El cristal del subdito caido sube de su cuerpo y vuela en arco hasta el rey; al llegar, un destello.
#  Coordenadas de MUNDO; el suelo sin achatar; lo que va en el aire, a su altura por K. Todo sale de la forma y la semilla.
# ============================================================
extends Node2D
class_name ReyAire

enum Modo { ESQUIRLAS, CLAVADA, PEDAZO, DECRETO, TRIBUTO }

const K := 0.7071
const Z_ENCIMA := Game.Z_PERSONAJES + 80

const BLANCO := Color(1.0, 1.0, 1.0)
const CRISTAL := Color(0.45, 0.88, 1.0)
const CRISTAL_CLARO := Color(0.80, 1.0, 1.0)
const CRISTAL_HONDO := Color(0.22, 0.55, 0.72)

# LAS ESQUIRLAS
const T_VUELO := 0.2
const T_ROTO := 0.3
const TROZOS := 7
const ALTO_CORONA := 34.0       # de donde salen: lo alto de su cuerpo (su corona), sobre el frente
# LA CLAVADA
const T_ESPERA_CLAVA := 0.5     # (sale con el respingo de su animacion: CombatFX.IMPACTO_ANIM_MAPA 'esquirlas')
const T_CLAVA := 0.26
# EL PEDAZO
const T_ESPERA_PEDAZO := 0.25
const T_CAE_PEDAZO := 0.22
const T_VUELVE := 0.4
# EL DECRETO
const T_FORMA := 0.3
const T_LUCE := 0.6
const T_DESHACE := 0.35
# EL TRIBUTO
const T_SUBE := 0.18
const T_ARCO := 0.42
const T_LLEGA := 0.3

var modo: int = Modo.ESQUIRLAS
var forma: CombatFormas.Forma = null
var queda: float = 1.0          # (las piezas: lo pone _charco_visible)
var color: Color = Color(0.35, 0.7, 0.95)
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _fase: float = 0.0
var _trozos: Array = []
var _motas: Array = []
var _suelo: Node2D = null
var _delante: Node2D = null
var _secando: float = -1.0
var _vuelve_a: Vector2 = Vector2.INF
var _vuelve_t: float = -1.0
# (los de sobre el cuerpo)
var _desde: Vector2 = Vector2.ZERO
var _hasta: Vector2 = Vector2.ZERO
var _caja: Rect2 = Rect2()


static func area(padre: Node, f: CombatFormas.Forma, m: int, semilla: int, espera: float) -> ReyAire:
	if padre == null or f == null:
		return null
	var e := ReyAire.new()
	e.modo = m
	e.forma = f
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	e._t = -espera * e._ritmo
	e._preparar()
	e._montar(padre)
	return e


# LAS PIEZAS QUE SE QUEDAN (las crea CombatTactico._charco_visible): la esquirla clavada y el pedazo de gel.
static func pieza(padre: Node, f, m: int, col: Color, semilla: int) -> ReyAire:
	if padre == null or f == null:
		return null
	var e := ReyAire.new()
	e.modo = m
	e.forma = f
	e.color = col
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	e._t = -(T_ESPERA_CLAVA if m == Modo.CLAVADA else T_ESPERA_PEDAZO) * e._ritmo
	e._preparar()
	e._montar(padre)
	return e


# LOS DE SOBRE EL CUERPO (CombatFX.dibujo_en_mapa -> CombatTactico._on_dibujo_mapa). DECRETO: 'caja' = el señalado.
# TRIBUTO: 'desde' = el cuerpo del subdito caido, 'caja' = el rey.
static func sobre_cuerpo(padre: Node, m: int, desde: Rect2, caja: Rect2, semilla: int, espera: float,
		ritmo: float) -> ReyAire:
	if padre == null:
		return null
	var e := ReyAire.new()
	e.modo = m
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	e._caja = caja
	e._hasta = caja.get_center() if caja.has_area() else Vector2.ZERO
	e._desde = desde.get_center() if desde.has_area() else e._hasta + Vector2(-40.0, 0.0)
	e._t = -maxf(espera, 0.0) * e._ritmo
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
	for i in TROZOS:
		_trozos.append({"u": _rng.randf_range(-0.5, 0.5), "d": _rng.randf_range(0.55, 1.0),
			"giro": _rng.randf_range(5.0, 10.0), "tam": _rng.randf_range(6.5, 9.0), "sale": _rng.randf_range(0.0, 0.07)})
	for i in 14:
		_motas.append({"a": _rng.randf_range(0.0, TAU), "v": _rng.randf_range(0.6, 1.3), "r": _rng.randf_range(0.8, 1.5),
			"h": _rng.randf_range(0.5, 1.2), "d": _rng.randf_range(0.0, 0.25)})


# CUANDO LE LLEGA a 'p' (en segundos desde que se lanza). El mismo numero manda el dibujo y el golpe.
static func retraso(m: int, f: CombatFormas.Forma, p: Vector2) -> float:
	if f == null:
		return 0.0
	if m == Modo.ESQUIRLAS:
		return T_VUELO * clampf(p.distance_to(f.origen) / maxf(f.radio, 1.0), 0.0, 1.0)
	return 0.0


static func t_salir(m: int) -> float:
	return T_VUELO if m == Modo.ESQUIRLAS else 0.2


func duracion() -> float:
	match modo:
		Modo.ESQUIRLAS: return T_VUELO + 0.08 + T_ROTO
		Modo.DECRETO: return T_FORMA + T_LUCE + T_DESHACE
		Modo.TRIBUTO: return T_SUBE + T_ARCO + T_LLEGA
	return INF   # las piezas: hasta que se sequen


# LAS PIEZAS: se acaban (aplastadas al pisarlas, o al secarse).
func secar() -> void:
	if _secando < 0.0:
		_secando = 0.0


# EL PEDAZO que se le vuelve a juntar: se desliza hasta sus pies y se encoge.
func volver_a(p: Vector2) -> void:
	_vuelve_a = p
	_vuelve_t = 0.0


func _process(delta: float) -> void:
	_t += delta * _ritmo
	if _secando >= 0.0:
		_secando += delta * _ritmo
		if _secando >= 0.35:
			queue_free()
			return
	if _vuelve_t >= 0.0:
		_vuelve_t += delta * _ritmo
		if _vuelve_t >= T_VUELVE:
			queue_free()
			return
	if _t >= duracion():
		queue_free()
		return
	_suelo.queue_redraw()
	_delante.queue_redraw()


func _pintar(capa: Node2D) -> void:
	if _t < 0.0:
		return
	match modo:
		Modo.ESQUIRLAS: _esquirlas(capa)
		Modo.CLAVADA: _clavada(capa)
		Modo.PEDAZO: _pedazo(capa)
		Modo.DECRETO: _decreto(capa)
		Modo.TRIBUTO: _tributo(capa)


# ------------------------------------------------------------
#  PIEZAS
# ------------------------------------------------------------
# UNA ESQUIRLA DE CRISTAL: un rombo alargado y afilado, la cara de la luz clara (casi blanca) y la otra cian hondo.
static func _esquirla(ci: CanvasItem, c: Vector2, tam: float, giro: float, alfa: float) -> void:
	var d := Vector2(cos(giro), sin(giro))
	var n: Vector2 = d.orthogonal() * tam * 0.38
	var a: Vector2 = c + d * tam
	var b: Vector2 = c - d * tam * 0.7
	ci.draw_primitive(PackedVector2Array([a, c + n, b]), PackedColorArray([Color(BLANCO, alfa), Color(CRISTAL_CLARO, alfa),
		Color(CRISTAL, alfa)]), PackedVector2Array())
	ci.draw_primitive(PackedVector2Array([a, b, c - n]), PackedColorArray([Color(CRISTAL, alfa), Color(CRISTAL_HONDO, alfa),
		Color(CRISTAL_HONDO, alfa)]), PackedVector2Array())


# ------------------------------------------------------------
#  LAS ESQUIRLAS DE LA CORONA
# ------------------------------------------------------------
func _esquirlas(capa: Node2D) -> void:
	var o: Vector2 = forma.origen
	var R: float = forma.radio
	var ap: float = deg_to_rad(forma.apertura)
	for tr in _trozos:
		var a: float = forma.dir.angle() + float(tr["u"]) * ap
		var dd := Vector2(cos(a), sin(a))
		var lejos: float = R * float(tr["d"])
		var t0: float = float(tr["sale"])
		if _t < t0:
			continue
		var u: float = clampf((_t - t0) / T_VUELO, 0.0, 1.0)
		var cae: Vector2 = o + dd * lejos
		if u < 1.0:
			if capa != _delante:
				continue
			# EN EL AIRE: de lo alto (su corona) bajando en arco hasta el suelo, girando, con su estela.
			var alto := func(x: float) -> float: return (ALTO_CORONA * (1.0 - x) + sin(PI * x) * 8.0) * K
			var p: Vector2 = o + dd * lejos * u - Vector2(0.0, alto.call(u))
			var u0: float = maxf(u - 0.2, 0.0)
			var p0: Vector2 = o + dd * lejos * u0 - Vector2(0.0, alto.call(u0))
			BarridoAire.cometa(capa, p0, p, 5.0, Color(CRISTAL, 0.6))
			_esquirla(capa, p, float(tr["tam"]), _fase + _t * float(tr["giro"]), 1.0)
			continue
		var k: float = clampf((_t - t0 - T_VUELO) / T_ROTO, 0.0, 1.0)
		if k >= 1.0:
			continue
		if capa == _suelo:
			BarridoAire.brillo(capa, cae, 10.0 * (1.0 - k), Color(CRISTAL, 0.45 * (1.0 - k)))
			continue
		# AL CAER: un destello y la esquirla partida en motas que saltan.
		if k < 0.4:
			BarridoAire.destello(capa, cae - Vector2(0.0, 2.0), 12.0 * (1.0 - k / 0.4), Color(CRISTAL_CLARO, 1.0 - k / 0.4), a)
		for j in 3:
			var gd: Dictionary = _motas[(j * 5 + int(float(tr["giro"]) * 3.0)) % _motas.size()]
			var aj: float = float(gd["a"])
			var q: Vector2 = cae + Vector2(cos(aj), sin(aj) * 0.6) * 12.0 * k - Vector2(0.0, sin(PI * k) * 9.0 * K)
			_esquirla(capa, q, float(tr["tam"]) * 0.45 * (1.0 - k * 0.5), aj + _t * 7.0, 1.0 - k)


# ------------------------------------------------------------
#  LA ESQUIRLA CLAVADA (se queda)
# ------------------------------------------------------------
func _clavada(capa: Node2D) -> void:
	var c: Vector2 = forma.centro
	var o: Vector2 = forma.origen if forma.origen != Vector2.ZERO else c + Vector2(-40.0, 0.0)
	var u: float = clampf(_t / T_CLAVA, 0.0, 1.0)
	var vive: float = clampf(queda * 1.5, 0.35, 1.0)
	if u < 1.0:
		if capa != _delante:
			return
		# VOLANDO desde su corona hasta su sitio, girando.
		var alto := func(x: float) -> float: return (ALTO_CORONA * (1.0 - x) + sin(PI * x) * 12.0) * K
		var p: Vector2 = o.lerp(c, u) - Vector2(0.0, alto.call(u))
		var p0: Vector2 = o.lerp(c, maxf(u - 0.2, 0.0)) - Vector2(0.0, alto.call(maxf(u - 0.2, 0.0)))
		BarridoAire.cometa(capa, p0, p, 3.0, Color(CRISTAL, 0.5))
		_esquirla(capa, p, 8.0, _fase + _t * 9.0, 1.0)
		return
	var tras: float = _t - T_CLAVA
	# AL ROMPERSE (pisada o seca): se parte en motas y se apaga.
	var rompe: float = clampf(_secando / 0.35, 0.0, 1.0) if _secando >= 0.0 else 0.0
	if capa == _suelo:
		# Su sombra y la grieta de luz donde se ha clavado.
		BarridoAire.brillo(capa, c + Vector2(1.5, 1.0), 7.0, Color(0.0, 0.0, 0.0, 0.25 * (1.0 - rompe)))
		BarridoAire.brillo(capa, c, 9.0 * (1.0 - rompe * 0.5), Color(CRISTAL, (0.18 + 0.1 * sin(_t * 3.0 + _fase)) * vive
			* (1.0 - rompe)))
		return
	if rompe > 0.0:
		for j in 4:
			var gd: Dictionary = _motas[j]
			var aj: float = float(gd["a"])
			var q: Vector2 = c + Vector2(cos(aj), sin(aj) * 0.6) * 10.0 * rompe - Vector2(0.0, (4.0 + sin(PI * rompe) * 8.0) * K)
			_esquirla(capa, q, 2.6 * (1.0 - rompe * 0.5), aj + _t * 8.0, 1.0 - rompe)
		if rompe < 0.4:
			BarridoAire.destello(capa, c - Vector2(0.0, 4.0), 10.0 * (1.0 - rompe / 0.4), Color(CRISTAL_CLARO, 1.0 - rompe / 0.4), _fase)
		return
	# CLAVADA: dos esquirlas de punta (una grande y otra pequeña, ladeadas), con un respingo al clavarse.
	var vibra: float = sin(tras * 40.0) * 0.12 * maxf(0.0, 1.0 - tras / 0.25)
	var inclina: float = -PI * 0.5 + 0.35 * sin(_fase) + vibra
	_esquirla(capa, c - Vector2(0.0, 6.0 * K), 8.5, inclina, vive)
	_esquirla(capa, c + Vector2(5.5, -2.2 * K), 5.0, -PI * 0.5 - 0.5 * cos(_fase) + vibra, vive)
	# EL BRILLO que le recorre a ratos (para que se vea en el suelo).
	var ciclo: float = fposmod(_t * 0.6 + _fase, 1.0)
	if ciclo < 0.12:
		BarridoAire.destello(capa, c - Vector2(0.0, 7.0 * K), 6.0 * (1.0 - ciclo / 0.12), Color(BLANCO, 0.9 * vive), _fase)


# ------------------------------------------------------------
#  EL PEDAZO DE GEL (se queda)
# ------------------------------------------------------------
func _pedazo(capa: Node2D) -> void:
	var c: Vector2 = forma.centro
	var r: float = maxf(forma.radio, 6.0)
	var cae: float = clampf(_t / T_CAE_PEDAZO, 0.0, 1.0)
	var alfa: float = 1.0
	var tam: float = 1.0
	if _vuelve_t >= 0.0:
		# SE LE VUELVE A JUNTAR: se desliza hasta sus pies, estirandose, y se encoge.
		var k: float = clampf(_vuelve_t / T_VUELVE, 0.0, 1.0)
		c = c.lerp(_vuelve_a, k * k)
		tam = 1.0 - k * 0.7
		alfa = 1.0 - k * k
	elif _secando >= 0.0:
		# APLASTADO: se despanzurra y se va.
		var k2: float = clampf(_secando / 0.35, 0.0, 1.0)
		tam = 1.0 + k2 * 0.6
		alfa = 1.0 - k2
	# El rebote al caer y el temblor de gelatina.
	var bote: float = (1.0 - cae) * 22.0 + (sin(cae * PI) * 4.0 if cae < 1.0 else 0.0)
	var tiembla: float = sin(_t * 7.0 + _fase) * 0.08
	var rx: float = r * tam * (1.0 + tiembla) * (0.7 + 0.3 * cae)
	var ry: float = r * tam * 0.62 * (1.0 - tiembla) * (0.8 + 0.2 * cae)
	if _secando >= 0.0:
		ry *= 1.0 - clampf(_secando / 0.35, 0.0, 1.0) * 0.6
	if capa == _suelo:
		BarridoAire.brillo(capa, c + Vector2(0.0, ry * 0.4), rx * 1.2, Color(0.0, 0.0, 0.0, 0.22 * alfa * cae))
		return
	var p: Vector2 = c - Vector2(0.0, (ry * 0.55 + bote) * K)
	var oscuro: Color = color.darkened(0.35)
	var claro: Color = color.lightened(0.35)
	# La gota: un ovalo relleno con degradado (oscura abajo, clara arriba) y su brillo.
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in 20:
		var a: float = TAU * float(i) / 20.0
		var q: Vector2 = p + Vector2(cos(a) * rx, sin(a) * ry)
		pts.append(q)
		cols.append(Color(oscuro.lerp(color, clampf(0.5 - sin(a) * 0.5, 0.0, 1.0)), 0.88 * alfa))
	Poligono.colores(capa, pts, cols)
	BarridoAire.brillo(capa, p + Vector2(-rx * 0.3, -ry * 0.35), rx * 0.45, Color(claro, 0.7 * alfa))
	BarridoAire.brillo(capa, p + Vector2(-rx * 0.35, -ry * 0.45), rx * 0.18, Color(BLANCO, 0.8 * alfa))


# ------------------------------------------------------------
#  EL DECRETO (sobre la cabeza del señalado)
# ------------------------------------------------------------
func _decreto(capa: Node2D) -> void:
	if capa != _delante:
		return
	var arriba: Vector2 = Vector2(_caja.get_center().x, _caja.position.y - 9.0) if _caja.has_area() else _hasta - Vector2(0.0, 30.0)
	var forma_k: float = clampf(_t / T_FORMA, 0.0, 1.0)
	var deshace: float = clampf((_t - T_FORMA - T_LUCE) / T_DESHACE, 0.0, 1.0)
	var r_aro: float = 11.0
	# LAS MOTAS QUE SE JUNTAN (formandose) y que caen sobre el (deshaciendose).
	for i in _motas.size():
		var gd: Dictionary = _motas[i]
		var a: float = float(gd["a"])
		if forma_k < 1.0:
			var lejos: float = 26.0 * float(gd["v"]) * (1.0 - forma_k)
			var q: Vector2 = arriba + Vector2(cos(a) * (r_aro + lejos), sin(a) * (r_aro + lejos) * 0.4)
			BarridoAire.destello(capa, q, 2.4 * float(gd["r"]), Color(CRISTAL_CLARO, forma_k), a)
		elif deshace > 0.0:
			var q2: Vector2 = arriba + Vector2(cos(a) * r_aro * float(gd["v"]), sin(a) * r_aro * 0.4 + deshace * 30.0 * float(gd["h"]))
			BarridoAire.destello(capa, q2, 2.2 * float(gd["r"]) * (1.0 - deshace), Color(CRISTAL_CLARO, 1.0 - deshace), a)
	if forma_k < 0.55 or deshace >= 1.0:
		return
	var vive: float = clampf((forma_k - 0.55) / 0.45, 0.0, 1.0) * (1.0 - deshace)
	var late: float = 1.0 + 0.08 * sin((_t - T_FORMA) * 10.0)
	BarridoAire.brillo(capa, arriba, 22.0 * late, Color(CRISTAL, 0.4 * vive))
	# LA CORONITA: cinco esquirlas en aro (las de detras primero, mas oscuras), de punta hacia arriba.
	var orden: Array = []
	for k in 5:
		orden.append(TAU * float(k) / 5.0 + _t * 0.8)
	orden.sort_custom(func(x, y): return sin(x) < sin(y))
	for a2 in orden:
		var base: Vector2 = arriba + Vector2(cos(a2) * r_aro * late, sin(a2) * r_aro * 0.4 * late)
		var fondo: float = 0.65 + 0.35 * (0.5 + 0.5 * sin(a2))
		_esquirla(capa, base - Vector2(0.0, 5.5), 7.5 * late, -PI * 0.5, vive * fondo)
	if _t - T_FORMA < 0.15:
		BarridoAire.destello(capa, arriba - Vector2(0.0, 3.0), 18.0 * (1.0 - (_t - T_FORMA) / 0.15), Color(BLANCO, vive), _fase)


# ------------------------------------------------------------
#  EL TRIBUTO (el cristal del subdito caido vuela hasta el rey)
# ------------------------------------------------------------
func _tributo(capa: Node2D) -> void:
	if capa != _delante:
		return
	var sube: float = clampf(_t / T_SUBE, 0.0, 1.0)
	var arco: float = clampf((_t - T_SUBE) / T_ARCO, 0.0, 1.0)
	var llega: float = clampf((_t - T_SUBE - T_ARCO) / T_LLEGA, 0.0, 1.0)
	var alto_arco: float = 30.0 + _desde.distance_to(_hasta) * 0.25
	if llega <= 0.0:
		var p: Vector2
		if arco <= 0.0:
			p = _desde - Vector2(0.0, 12.0 * sube)
		else:
			var e: float = arco * arco * (3.0 - 2.0 * arco)
			p = (_desde - Vector2(0.0, 12.0)).lerp(_hasta, e) - Vector2(0.0, sin(PI * e) * alto_arco * K)
			var e0: float = maxf(e - 0.12, 0.0)
			var p0: Vector2 = (_desde - Vector2(0.0, 12.0)).lerp(_hasta, e0) - Vector2(0.0, sin(PI * e0) * alto_arco * K)
			BarridoAire.cometa(capa, p0, p, 6.0, Color(CRISTAL, 0.65))
		BarridoAire.brillo(capa, p, 16.0, Color(CRISTAL, 0.5 * sube))
		_esquirla(capa, p, 10.0 * (0.6 + 0.4 * sube), -PI * 0.5 + _t * 6.0, sube)
		return
	# AL LLEGAR: un destello en el rey y motas que le suben.
	if llega < 0.45:
		BarridoAire.destello(capa, _hasta, lerpf(22.0, 8.0, llega / 0.45), Color(CRISTAL_CLARO, 1.0 - llega / 0.45), _fase)
		BarridoAire.brillo(capa, _hasta, maxf(_caja.size.y, 30.0) * 0.5, Color(CRISTAL, 0.35 * (1.0 - llega / 0.45)))
	for i in 6:
		var gd: Dictionary = _motas[i]
		var a: float = float(gd["a"])
		var q: Vector2 = _hasta + Vector2(cos(a) * 12.0 * float(gd["v"]), 4.0) - Vector2(0.0, (6.0 + 22.0 * llega) * float(gd["h"]))
		BarridoAire.destello(capa, q, 2.4 * float(gd["r"]), Color(CRISTAL_CLARO, 1.0 - llega), a)
