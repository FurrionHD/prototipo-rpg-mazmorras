# ============================================================
#  constructo_aire.gd
#  LOS EFECTOS DE LOS CONSTRUCTOS en el mapa (30/09/2026, paso 2, uno a uno y con su visto bueno; ver la memoria
#  constructos-tactico). Empieza por el GOLEM DE ARCILLA:
#  SOBRE UN CUERPO (CombatTactico._on_dibujo_mapa, CombatFX.Estilo.CONSTRUCTO_*):
#    APLASTON    el puñetazo (el gesto lo hace su sprite, 'embestida'): sobre quien lo recibe, una media luna gorda de
#                barro del lado por el que entra el puño, TERRONES de arcilla (bolas con su borde, como su sprite) que
#                saltan hacia atras de la victima y caen, y un poco de polvo seco. En la Machaca, mas gordo ('peso').
#    PEGOTES     si el golpe le deja LENTO: pegotes de barro en los pies un momento (CombatTactico._on_impacto).
#  SOBRE EL GOLEM (CombatTactico._tick_barro, mirando su estado; tambien en el espejo):
#    COCERSE     el fuego lo cuece (o se Endurece): un resplandor de brasa que le sube de los pies a la cabeza y vaho.
#    VAPOR       el agua le cae estando cocido: una nube de vapor al apagarse.
#    DURO        mientras esta cocido/endurecido: algun hilo de vaho de vez en cuando (el tono terracota lo pone el
#                shader tinte_constructo sobre su sprite: el modulate lo reescribe el aviso del golpe cada fotograma).
#    BLANDO      mientras esta mojado: gotas de barro que le caen y un charquito bajo los pies (y el tono de barro
#                mojado en el shader).
#  NADA DE LINEAS (efectos-sin-lineas): medias lunas llenas, bolas con borde, cometas gordas. Coordenadas de MUNDO.
# ============================================================
extends Node2D
class_name ConstructoAire

enum Modo { APLASTON, PEGOTES, COCERSE, VAPOR, DURO, BLANDO }

const K := 0.7071
const Z_ENCIMA := Game.Z_PERSONAJES + 80
const ARCILLA := Color(0.6, 0.45, 0.3)
const T_APLASTON := 0.55
const T_PEGOTES := 0.9
const T_COCERSE := 0.8
const T_VAPOR := 0.9
const T_SECA := 0.5
const BRASA := Color(1.0, 0.55, 0.18)
const VAHO := Color(0.86, 0.84, 0.82)
const POLVO := Color(0.66, 0.57, 0.46)

var modo: int = Modo.APLASTON
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _hasta: Vector2 = Vector2.ZERO
var _pies: Vector2 = Vector2.ZERO
var _eje: Vector2 = Vector2.RIGHT
var _ancho: float = 14.0
var _largo: float = 26.0
var _peso: float = 1.0
var _incl: float = 0.0
var _piezas: Array = []
var _secando: float = -1.0
var _borde: Color = Color(0.2, 0.14, 0.09)
var _barro: Color = ARCILLA
var _claro: Color = Color(0.8, 0.66, 0.48)
var _suelo: Node2D = null
var _delante: Node2D = null
var _brillo: Node2D = null


# ------------------------------------------------------------
#  SOBRE UN CUERPO
# ------------------------------------------------------------
# 'desde' = el centro de quien pega, 'caja' = el que lo recibe, 'color' = el de su ficha (su arcilla), 'peso' = 1 el
# puñetazo, mas en la Machaca.
static func sobre_cuerpo(padre: Node, m: int, desde: Vector2, caja: Rect2, pies: Vector2, color: Color, semilla: int,
		espera: float, ritmo: float, peso: float = 1.0) -> ConstructoAire:
	if padre == null:
		return null
	var e := ConstructoAire.new()
	e.modo = m
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	e._ancho = maxf(caja.size.x, 8.0)
	e._largo = maxf(caja.size.y, 10.0)
	e._pies = pies
	e._peso = peso
	e._tonos(color)
	e._hasta = caja.get_center() + Vector2(e._rng.randf_range(-0.12, 0.12) * caja.size.x,
		e._rng.randf_range(-0.15, 0.05) * caja.size.y)
	e._eje = (e._hasta - desde).normalized() if e._hasta.distance_squared_to(desde) > 1.0 else Vector2.RIGHT
	e._incl = e._rng.randf_range(-0.25, 0.25)
	e._t = -maxf(espera, 0.0)
	match m:
		Modo.APLASTON:
			# Los terrones: salen hacia atras de la victima (hacia donde le empuja el puño), en abanico, y caen al suelo.
			for i in int(round(8.0 * peso)):
				e._piezas.append({"d": e._eje.rotated(e._rng.randf_range(-1.0, 1.0)), "v": e._rng.randf_range(12.0, 26.0) * peso,
					"sube": e._rng.randf_range(8.0, 18.0), "tam": e._rng.randf_range(2.0, 3.4) * sqrt(peso),
					"t0": e._rng.randf_range(0.0, 0.05)})
		Modo.PEGOTES:
			for i in 5:
				e._piezas.append({"x": e._rng.randf_range(-0.45, 0.45), "y": e._rng.randf_range(-0.12, 0.04),
					"tam": e._rng.randf_range(1.8, 3.0)})
		Modo.COCERSE, Modo.VAPOR:
			for i in (7 if m == Modo.COCERSE else 11):
				e._piezas.append({"x": e._rng.randf_range(-0.4, 0.4), "t0": e._rng.randf_range(0.0, 0.35),
					"sube": e._rng.randf_range(18.0, 34.0), "tam": e._rng.randf_range(0.8, 1.3)})
	e._suelo = e._capa(SueloRoto.Z_SUELO + 2, false)
	e._delante = e._capa(Z_ENCIMA, false)
	e._brillo = e._capa(Z_ENCIMA + 1, true)
	padre.add_child(e)
	return e


# LO QUE SE QUEDA mientras dure su estado (DURO o BLANDO): sigue a su cuerpo (seguir) y se va (secar).
static func estado(padre: Node, m: int, caja: Rect2, pies: Vector2, color: Color, semilla: int) -> ConstructoAire:
	var e: ConstructoAire = sobre_cuerpo(padre, m, caja.get_center(), caja, pies, color, semilla, 0.0, 1.0)
	if e != null:
		e._hasta = caja.get_center()
	return e


func seguir(caja: Rect2, pies: Vector2) -> void:
	_ancho = maxf(caja.size.x, 8.0)
	_largo = maxf(caja.size.y, 10.0)
	_hasta = caja.get_center()
	_pies = pies


func secar() -> void:
	if _secando < 0.0:
		_secando = _t


func _tonos(color: Color) -> void:
	_barro = color.lerp(ARCILLA, 0.4)
	_borde = _barro.darkened(0.65)
	_claro = _barro.lightened(0.35)


func duracion() -> float:
	match modo:
		Modo.APLASTON: return T_APLASTON
		Modo.PEGOTES: return T_PEGOTES
		Modo.COCERSE: return T_COCERSE
		Modo.VAPOR: return T_VAPOR
	return INF   # los que se quedan: hasta que se secan


func _capa(z: int, aditiva: bool) -> Node2D:
	var n := Node2D.new()
	n.z_as_relative = false
	n.z_index = z
	if aditiva:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		n.material = mat
	add_child(n)
	n.draw.connect(_dibujar_capa.bind(n))
	return n


func _process(delta: float) -> void:
	_t += delta * _ritmo
	if _t >= duracion() or (_secando >= 0.0 and _t - _secando >= T_SECA):
		queue_free()
		return
	for n in [_suelo, _delante, _brillo]:
		if n != null:
			(n as Node2D).queue_redraw()


func _dibujar_capa(capa: Node2D) -> void:
	match modo:
		Modo.APLASTON: _aplaston(capa)
		Modo.PEGOTES: _pegotes(capa)
		Modo.COCERSE: _cocerse(capa)
		Modo.VAPOR: _vapor(capa)
		Modo.DURO: _duro(capa)
		Modo.BLANDO: _blando(capa)


# Lo que queda al irse (los que se quedan se secan poco a poco).
func _queda() -> float:
	return 1.0 if _secando < 0.0 else 1.0 - clampf((_t - _secando) / T_SECA, 0.0, 1.0)


# UN TERRON: bola de arcilla con su borde oscuro, su relleno y un brillo arriba a la izquierda (como su sprite).
func _terron(ci: CanvasItem, p: Vector2, r: float, alfa: float) -> void:
	if r <= 0.4 or alfa <= 0.01:
		return
	ci.draw_circle(p, r + 0.8, Color(_borde, alfa))
	ci.draw_circle(p, r, Color(_barro, alfa))
	ci.draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.4, Color(_claro, alfa))


# ------------------------------------------------------------
#  EL APLASTON (el puñetazo y la Machaca)
# ------------------------------------------------------------
func _aplaston(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var sale: Vector2 = _eje
	# GORDO (la 1a version, al ancho de la figura, salia una raya fina): del alto de medio cuerpo, y mas en la Machaca.
	var r: float = maxf(_largo * 0.62, 14.0) * (0.8 + 0.25 * _peso)
	if capa == _brillo:
		if _t < 0.1:
			BarridoAire.brillo(capa, _hasta - sale * r * 0.3, r * 0.9, Color(1.0, 0.9, 0.75, 0.5 * (1.0 - _t / 0.1)))
		return
	if capa == _suelo:
		# Los terrones que han caido se quedan un momento en el suelo; y el polvo seco a sus pies, hacia atras.
		for g in _piezas:
			var tg: float = _t - float(g["t0"]) - 0.32
			if tg < 0.0:
				continue
			var d: Vector2 = g["d"]
			var p: Vector2 = _pies + Vector2(d.x, d.y * K) * float(g["v"])
			_terron(capa, p, float(g["tam"]) * 0.8, 1.0 - clampf(tg / 0.2, 0.0, 1.0))
		var kp: float = clampf(_t / 0.45, 0.0, 1.0)
		for i in 3:
			var q: Vector2 = _pies + Vector2(sale.x, sale.y * K) * _ancho * (0.3 + 0.5 * kp) \
				+ Vector2(sale.y, -sale.x) * _ancho * 0.35 * (float(i) - 1.0) - Vector2(0.0, 5.0 * kp)
			BestiaAire._bola(capa, q, _ancho * (0.25 + 0.3 * kp), Color(POLVO, 0.35 * (1.0 - kp)))
		return
	# EL FRENTE DEL APLASTON: una media luna gorda de barro del lado por el que entra el puño (contorno oscuro, cuerpo
	# de su arcilla, filo claro), que se aplasta y se va.
	var kf: float = clampf(_t / 0.08, 0.0, 1.0)
	var th: float = (-sale).angle() + _incl
	var c: Vector2 = _hasta + sale * r * 0.5
	var alfa: float = 1.0 - smoothstep(0.1, 0.26, _t)
	BestiaAire._media_luna(capa, c, th - 1.05, th + 1.05, r * 1.1 * (0.85 + 0.2 * kf), r * 0.85, _borde, _borde, alfa * 0.9, true)
	BestiaAire._media_luna(capa, c, th - 0.95, th + 0.95, r * (0.85 + 0.2 * kf), r * 0.75, _claro, _barro, alfa, true)
	# LOS TERRONES: suben y caen (parabola achatada) hasta el suelo, a su alrededor.
	for g in _piezas:
		var tg2: float = _t - float(g["t0"])
		if tg2 < 0.0 or tg2 > 0.32:
			continue
		var kt: float = tg2 / 0.32
		var d2: Vector2 = g["d"]
		var p2: Vector2 = _hasta.lerp(_pies, kt) + Vector2(d2.x, d2.y * K) * float(g["v"]) * kt \
			- Vector2(0.0, float(g["sube"]) * 4.0 * kt * (1.0 - kt) * K)
		_terron(capa, p2, float(g["tam"]), 1.0)


# ------------------------------------------------------------
#  LOS PEGOTES (le ha dejado lento)
# ------------------------------------------------------------
func _pegotes(capa: Node2D) -> void:
	if _t < 0.0 or capa != _delante:
		return
	var sale: float = clampf(_t / 0.1, 0.0, 1.0)
	var alfa: float = 1.0 - smoothstep(0.6, 1.0, _t / T_PEGOTES)
	for g in _piezas:
		var p: Vector2 = _pies + Vector2(float(g["x"]) * _ancho, float(g["y"]) * _largo)
		# Resbalan un poco hacia abajo mientras se van.
		_terron(capa, p + Vector2(0.0, 1.5 * _t), float(g["tam"]) * sale, alfa)


# ------------------------------------------------------------
#  COCERSE (el fuego, o el Endurecerse)
# ------------------------------------------------------------
# Un resplandor de brasa que le sube de los pies a la cabeza (una banda llena y blanda) y el vaho caliente que sube.
func _cocerse(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var u: float = clampf(_t / (T_COCERSE * 0.6), 0.0, 1.0)
	if capa == _brillo:
		var alto: float = lerpf(_largo * 0.45, -_largo * 0.5, u)
		var c: Vector2 = _hasta + Vector2(0.0, alto)
		var a: float = sin(u * PI) * (1.0 - _t / T_COCERSE)
		BestiaAire._bola(capa, c, _ancho * 0.75, Color(BRASA, 0.7 * a))
		BarridoAire.brillo(capa, _hasta, _ancho * 0.9, Color(BRASA, 0.3 * a))
		return
	if capa == _delante:
		_vaho(capa, 0.55)


func _vaho(capa: Node2D, fuerza: float) -> void:
	for g in _piezas:
		var tg: float = _t - float(g["t0"])
		if tg < 0.0 or tg > 0.55:
			continue
		var k: float = tg / 0.55
		var p: Vector2 = Vector2(_hasta.x + float(g["x"]) * _ancho, _hasta.y - _largo * 0.35) \
			- Vector2(0.0, float(g["sube"]) * k)
		BestiaAire._bola(capa, p, _ancho * 0.22 * float(g["tam"]) * (0.6 + 0.9 * k), Color(VAHO, fuerza * (1.0 - k)))


# EL VAPOR (agua sobre la arcilla cocida): una nube blanca gorda que sube y se abre.
func _vapor(capa: Node2D) -> void:
	if _t < 0.0 or capa != _delante:
		return
	for g in _piezas:
		var tg: float = _t - float(g["t0"]) * 0.6
		if tg < 0.0 or tg > 0.7:
			continue
		var k: float = tg / 0.7
		var p: Vector2 = Vector2(_hasta.x + float(g["x"]) * _ancho * (1.0 + k), _hasta.y - _largo * 0.1) \
			- Vector2(0.0, float(g["sube"]) * 1.3 * k)
		BestiaAire._bola(capa, p, _ancho * 0.35 * float(g["tam"]) * (0.6 + 1.0 * k), Color(Color.WHITE, 0.6 * (1.0 - k * k)))


# ------------------------------------------------------------
#  LOS QUE SE QUEDAN
# ------------------------------------------------------------
# DURO: cada poco, un hilo de vaho que le sale de los hombros (la arcilla aun caliente).
func _duro(capa: Node2D) -> void:
	if capa != _delante:
		return
	var ciclo: float = 1.3
	var q: float = _queda()
	for i in 2:
		var tc: float = fmod(_t + float(i) * ciclo * 0.5, ciclo)
		if tc > 0.8:
			continue
		var k: float = tc / 0.8
		var lado: float = -1.0 if i == 0 else 1.0
		var p: Vector2 = Vector2(_hasta.x + lado * _ancho * 0.28, _hasta.y - _largo * 0.3) - Vector2(-lado * 2.0, 14.0 * k)
		BestiaAire._bola(capa, p, _ancho * 0.12 * (0.7 + 0.8 * k), Color(VAHO, 0.4 * (1.0 - k) * q))


# BLANDO: gotas de barro que le caen de los costados al suelo, y el charquito bajo los pies (un circulo en el suelo,
# no una elipse: huellas-suelo-circulos) que crece un poco al llegar cada gota.
func _blando(capa: Node2D) -> void:
	var q: float = _queda()
	var aparece: float = clampf(_t / 0.3, 0.0, 1.0)
	if capa == _suelo:
		var r: float = _ancho * (0.42 + 0.03 * sin(_t * 3.0)) * aparece
		# Oscuro (sobre el suelo de la mazmorra, un barro claro se leia como un resplandor) y con un brillo de agua.
		BestiaAire._bola(capa, _pies, r * 1.2, Color(_borde, 0.85 * q))
		BestiaAire._bola(capa, _pies, r * 0.9, Color(_barro.darkened(0.55), 0.9 * q))
		BestiaAire._bola(capa, _pies + Vector2(-r * 0.3, -r * 0.15), r * 0.25, Color(_claro, 0.35 * q))
		return
	if capa != _delante:
		return
	var ciclo: float = 0.9
	for i in 3:
		var tc: float = fmod(_t + float(i) * 0.31, ciclo)
		var k: float = tc / 0.45
		if k > 1.0:
			continue
		var lado: float = [-0.24, 0.26, -0.06][i]   # de SU cuerpo (mas afuera colgaban en el aire)
		var x: float = _hasta.x + lado * _ancho
		var y0: float = _hasta.y - _largo * [0.05, 0.15, 0.3][i]
		var p: Vector2 = Vector2(x, lerpf(y0, _pies.y - 1.0, k * k))
		_terron(capa, p, 2.6, q * (1.0 - smoothstep(0.85, 1.0, k)))
