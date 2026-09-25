# ============================================================
#  baston_aire.gd
#  LOS EFECTOS DEL BASTON Y LA VARITA en el mapa (26/09/2026). El arma del mago: lo que pega es un PALO (mate,
#  de madera, nada de filo ni de hierro) y lo demas es ARCANO (violeta), aire o luz. Copia las piezas de los que le
#  gustan: el barrido de la maza (MazaAire._barrido) sin brillo de metal, los anillos rellenos de ApoyoAire, las
#  cometas y los destellos en estrella de BarridoAire. NADA DE LINEAS.
#  EN EL SUELO (por SueloRoto: la ficha dice cual; BASTON_* en el orden de este Modo):
#    BARRE     Bastonazo: el palo barre el cono a la altura de la cintura y detras sale la racha de polvo que
#              los aparta (el empujon: CombatTactico.pedir_tiron con la ficha en negativo).
#    SELLO     Sello arcano: un signo que se TRAZA en el suelo (el anillo dando la vuelta y las runas) y se
#              CIERRA de golpe hacia el centro. El cierre es el golpe: a todos a la vez, nada en cada cuerpo.
#    VIENTO    Viento limpio: rachas de aire que salen de ti y recorren el cono.
#  SOBRE UN CUERPO (CombatTactico._on_dibujo_mapa, golpe a golpe):
#    GOLPE        el basico: el palo entra de lado y de arriba, mate, y la mancha roma del golpe (pequeña: es un palo).
#    BASTONAZO_C  el Bastonazo en cada uno: el porrazo y el polvo del empujon hacia atras.
#    VIENTO_C     Viento limpio en cada uno de los tuyos: el aire le da una vuelta y se lleva motas oscuras.
#    FOCO         Foco arcano (sobre ti): signos que se juntan en la punta del baston (o la varita) y un destello.
#    VELO         Velo umbrio (sobre ti): la sombra CAE de arriba y te tapa; luego te quedas medio transparente
#                 (eso lo pone el Sigilo: CombatTactico._sigilo_visible).
#    PURIFICAR    (varita) sobre uno de los tuyos: una columna de luz y lo que llevaba encima sube y se evapora.
#    CHISPA       (varita) de tu mano a la suya: gotas de mana que viajan en arco y le laten al llegar.
#    EGIDA        (varita) un hexagono pequeño de luz delante de el, hacia su enemigo mas cercano.
#  Coordenadas de MUNDO; el suelo SIN achatar (como las huellas); la altura a K. Todo sale de una semilla.
# ============================================================
extends Node2D
class_name BastonAire

# Los del suelo (BARRE..VIENTO) van en el orden de SueloRoto.Tipo.BASTON_*: no reordenar.
enum Modo { BARRE, SELLO, VIENTO,
	GOLPE, BASTONAZO_C, VIENTO_C, FOCO, VELO, PURIFICAR, CHISPA, EGIDA }

const K := 0.7071
const BLANCO := BarridoAire.BLANCO
const MADERA := Color(0.55, 0.40, 0.27)
const MADERA_CLARA := Color(0.86, 0.74, 0.56)
const ARCANO := Color(0.66, 0.46, 1.0)
const ARCANO_CLARO := Color(0.90, 0.84, 1.0)
const VIENTO := Color(0.66, 0.94, 0.90)
const VIENTO_CLARO := Color(0.92, 1.0, 0.98)
const SOMBRA := Color(0.10, 0.07, 0.16)
const SOMBRA_BORDE := Color(0.32, 0.22, 0.46)
const MANA := Color(0.42, 0.68, 1.0)
const MANA_CLARO := Color(0.82, 0.92, 1.0)
const LUZ := Color(1.0, 0.96, 0.78)
const POLVO := SueloRoto.POLVO
const Z_ENCIMA := Game.Z_PERSONAJES + 80
const ALTO_TORSO := 14.0
const ALTO_CABEZA := 26.0
const GRAVEDAD := 380.0

const T_SWING := 0.07         # lo que tarda el palo en llegar (acaba EN el golpe)
const T_BARRE := 0.17         # el barrido del Bastonazo de punta a punta (un poco mas lento que la maza: es largo)
const T_CLAVADO := 0.06
const T_APAGA_SECO := 0.1
const COLA := deg_to_rad(70.0)
const ALTO_BARRIDO := 9.0     # el Bastonazo, a la altura de la cintura
const T_TRAZO := 0.32         # lo que tarda el Sello en trazarse entero
const T_CIERRA := 0.44        # y cuando se cierra (el golpe: a todos a la vez)
const V_VIENTO := 320.0       # px/s de las rachas del Viento limpio (el frente: cuando le llega a cada uno)
const T_CAE_VELO := 0.28
const T_CHISPA := 0.34        # lo que tarda una gota de tu mano a la suya

var modo: int = Modo.GOLPE
var forma: CombatFormas.Forma = null
var escala: float = 1.0
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
# Sobre un cuerpo.
var _caja: Rect2 = Rect2()
var _fallo: bool = false
var _crit: bool = false
var _n: int = 0
var _c: Vector2 = Vector2.ZERO
var _imp: Vector2 = Vector2.ZERO
var _pies: Vector2 = Vector2.ZERO
var _desde: Vector2 = Vector2.ZERO
var _hacia: Vector2 = Vector2.ZERO
var _dir: Vector2 = Vector2.RIGHT
var _lat: Vector2 = Vector2.RIGHT
var _lado: float = 1.0
var _swing: Array = []
var _mancha: PackedVector2Array = PackedVector2Array()
var _motas: Array = []
# El suelo.
var _centro: Vector2 = Vector2.ZERO
var _r: float = 30.0
var _runas: Array = []
var _rachas: Array = []
var _atras: Node2D = null
var _delante: Node2D = null
var _suelo: Node2D = null


# ------------------------------------------------------------
#  EN EL SUELO
# ------------------------------------------------------------
static func area(padre: Node, f: CombatFormas.Forma, m: int, semilla: int, espera: float) -> BastonAire:
	if padre == null or f == null:
		return null
	var e := BastonAire.new()
	e.modo = m
	e.forma = f
	e._rng.seed = semilla
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	e._t = -espera * e._ritmo
	e.z_as_relative = false
	e.z_index = SueloRoto.Z_SUELO
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._preparar_area()
	return e


# CUANDO LE LLEGA a 'p' el golpe, en segundos desde que se lanza (la misma cuenta que el dibujo).
static func retraso(m: int, f: CombatFormas.Forma, p: Vector2) -> float:
	if f == null:
		return 0.0
	match m:
		Modo.BARRE:
			var o: Vector2 = SueloRoto.origen_de(f)
			var mitad: float = deg_to_rad(f.apertura * 0.5)
			if mitad <= 0.001 or p.distance_squared_to(o) < 0.01:
				return 0.0
			var fr: float = clampf(angle_difference(f.dir.angle() - mitad, (p - o).angle()) / (2.0 * mitad), 0.0, 1.0)
			return T_BARRE * sqrt(fr)
		Modo.SELLO:
			return T_CIERRA
		Modo.VIENTO:
			return p.distance_to(SueloRoto.origen_de(f)) / V_VIENTO
	return 0.0


static func t_salir(m: int) -> float:
	match m:
		Modo.BARRE: return T_BARRE
		Modo.SELLO: return T_CIERRA
		Modo.VIENTO: return 0.45
	return 0.2


func _preparar_area() -> void:
	_centro = forma.centro if forma.tipo == CombatFormas.Tipo.CIRCULO else forma.origen
	_r = maxf(forma.radio, 8.0)
	_dir = forma.dir.normalized() if forma.dir.length_squared() > 0.0001 else Vector2.RIGHT
	_lat = Vector2(-_dir.y, _dir.x).normalized()
	match modo:
		Modo.SELLO:
			# El signo: el anillo empieza en un punto al azar y gira hacia un lado al azar (no siempre igual).
			var a0: float = _rng.randf_range(0.0, TAU)
			var sentido: float = 1.0 if _rng.randf() < 0.5 else -1.0
			_runas.append({"a0": a0, "s": sentido})
			for i in 6:
				var a: float = a0 + sentido * TAU * (float(i) + 0.5) / 6.0
				_runas.append({"a": a, "u": (float(i) + 0.5) / 6.0, "giro": _rng.randf_range(0.0, PI)})
		Modo.VIENTO:
			var mitad: float = deg_to_rad(forma.apertura * 0.5)
			for i in 13:
				var u: float = (float(i) + _rng.randf_range(0.2, 0.8)) / 13.0
				_rachas.append({"a": _dir.angle() + lerpf(-mitad, mitad, u) * 0.85, "t0": _rng.randf_range(0.0, 0.12),
					"curva": _rng.randf_range(-0.35, 0.35), "alto": _rng.randf_range(2.0, 16.0),
					"ancho": _rng.randf_range(4.0, 6.5)})
		Modo.BARRE:
			for i in 12:
				var u2: float = (float(i) + _rng.randf_range(0.0, 1.0)) / 12.0
				_motas.append({"u": u2, "r": _r * _rng.randf_range(0.55, 1.0), "v": _rng.randf_range(35.0, 70.0),
					"tam": _rng.randf_range(4.0, 7.0)})
	_atras = _capa(Game.Z_PERSONAJES - 1)
	_delante = _capa(Z_ENCIMA)


func _capa(z: int) -> Node2D:
	var n := Node2D.new()
	n.z_as_relative = false
	n.z_index = z
	add_child(n)
	n.draw.connect(_dibujar_capa.bind(n))
	return n


# ------------------------------------------------------------
#  SOBRE UN CUERPO
# ------------------------------------------------------------
# 'desde' = el pecho de quien pega (o de quien lo lanza); 'caja' = el que lo recibe. 'hacia' = a donde mira la
# Egida (su enemigo mas cercano). 'esc' = el tamaño (el Foco de la varita, mas pequeño).
static func golpe(padre: Node, m: int, desde: Vector2, caja: Rect2, fallo: bool, crit: bool, n: int,
		semilla: int, espera: float, ritmo: float, hacia: Vector2 = Vector2.ZERO, esc: float = 1.0) -> BastonAire:
	if padre == null:
		return null
	var e := BastonAire.new()
	e.modo = m
	e.escala = esc
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	e._t = -maxf(espera, 0.0)
	e._caja = caja
	e._fallo = fallo
	e._crit = crit
	e._n = n
	e._desde = desde
	e._hacia = hacia
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS   # la pelea tactica pausa el arbol
	padre.add_child(e)
	e._preparar_golpe()
	return e


func _preparar_golpe() -> void:
	_c = _caja.get_center() if _caja.has_area() else _desde
	var alto: float = _caja.size.y if _caja.has_area() else 24.0
	var ancho: float = _caja.size.x if _caja.has_area() else 12.0
	_pies = Vector2(_c.x, _caja.end.y) if _caja.has_area() else _c + Vector2(0.0, ALTO_TORSO)
	_dir = (_c - _desde).normalized() if _c.distance_squared_to(_desde) > 0.01 else Vector2.RIGHT
	# EL LADO con la perspectiva de la camara (la regla de los golpes: segun de donde viene, nunca fijo).
	_lat = Vector2(-_dir.y, _dir.x * K) + Vector2(_dir.x, _dir.y * K) * 0.35
	_lat = _lat.normalized() if _lat.length_squared() > 0.001 else Vector2.RIGHT
	_lado = 1.0 if _rng.randf() < 0.5 else -1.0
	if _n % 2 == 1:
		_lado = -_lado
	var cara: Vector2 = _c - _dir * ancho * 0.25
	match modo:
		Modo.GOLPE, Modo.BASTONAZO_C:
			_imp = cara + Vector2(0.0, -alto * _rng.randf_range(0.0, 0.2))
			var sube: float = _rng.randf_range(12.0, 22.0)
			_swing = [_imp + _lat * _lado * 17.0 + Vector2(0.0, -sube) - _dir * 6.0,
				_imp + _lat * _lado * 13.0 + Vector2(0.0, -sube * 0.2), _imp]
			if _fallo:
				var pasa: Vector2 = ((_swing[2] as Vector2) - (_swing[1] as Vector2)).normalized() * (ancho * 0.6 + 6.0)
				_swing[2] = (_swing[2] as Vector2) + pasa
			var g: float = _rng.randf_range(0.0, TAU)
			for i in 11:
				var ang: float = g + TAU * float(i) / 11.0
				var largo: float = 0.8 + 0.2 * sin(g * 1.7 + float(i) * 2.9)
				_mancha.append(Vector2(cos(ang), sin(ang)) * largo)
				var med: float = ang + PI / 11.0
				_mancha.append(Vector2(cos(med), sin(med)) * largo * 0.72)
		Modo.VIENTO_C:
			# Lo que se lleva el aire: motas oscuras que salen del cuerpo hacia donde sopla.
			for i in 6:
				_motas.append({"p": _c + Vector2(_rng.randf_range(-ancho * 0.4, ancho * 0.4), _rng.randf_range(-alto * 0.35, alto * 0.35)),
					"v": (_dir + _lat * _rng.randf_range(-0.6, 0.6)).normalized() * _rng.randf_range(45.0, 80.0)
						+ Vector2(0.0, -_rng.randf_range(10.0, 30.0)),
					"t0": 0.06 + _rng.randf_range(0.0, 0.15), "tam": _rng.randf_range(1.6, 2.6)})
		Modo.FOCO:
			for i in 7:
				_motas.append({"a": TAU * float(i) / 7.0 + _rng.randf_range(-0.3, 0.3), "r": _rng.randf_range(18.0, 26.0) * escala,
					"t0": _rng.randf_range(0.0, 0.12), "giro": _rng.randf_range(0.0, PI)})
		Modo.VELO:
			for i in 8:
				_motas.append({"x": _rng.randf_range(-12.0, 12.0), "t0": T_CAE_VELO + _rng.randf_range(-0.05, 0.12),
					"v": Vector2(_rng.randf_range(-18.0, 18.0), -_rng.randf_range(8.0, 20.0)), "r": _rng.randf_range(5.0, 8.0)})
		Modo.PURIFICAR:
			for i in 9:
				_motas.append({"p": _c + Vector2(_rng.randf_range(-ancho * 0.45, ancho * 0.45), _rng.randf_range(-alto * 0.3, alto * 0.4)),
					"t0": 0.08 + _rng.randf_range(0.0, 0.3), "v": _rng.randf_range(35.0, 60.0), "tam": _rng.randf_range(1.6, 2.6)})
		Modo.CHISPA:
			for i in 7:
				_motas.append({"t0": float(i) * 0.05 + _rng.randf_range(0.0, 0.02), "arco": _rng.randf_range(10.0, 18.0),
					"lado": _rng.randf_range(-4.0, 4.0)})
	# Lo del SUELO de un cuerpo (polvo, anillos a los pies) va por debajo de los cuerpos.
	if modo in [Modo.BASTONAZO_C, Modo.FOCO, Modo.VELO, Modo.PURIFICAR, Modo.VIENTO_C]:
		_suelo = Node2D.new()
		_suelo.z_as_relative = false
		_suelo.z_index = SueloRoto.Z_SUELO
		add_child(_suelo)
		_suelo.draw.connect(_dibujar_suelo_cuerpo)


func duracion() -> float:
	match modo:
		Modo.BARRE: return T_BARRE + 0.7
		Modo.SELLO: return T_CIERRA + 0.6
		Modo.VIENTO: return 0.95
		Modo.VIENTO_C: return 0.7
		Modo.FOCO: return 0.75
		Modo.VELO: return T_CAE_VELO + 0.7
		Modo.PURIFICAR: return 0.9
		Modo.CHISPA: return T_CHISPA + 0.3 + 0.55
		Modo.EGIDA: return 0.9
	return 0.5


func _process(delta: float) -> void:
	_t += delta * _ritmo
	if _t >= duracion():
		queue_free()
		return
	queue_redraw()
	for n in [_atras, _delante, _suelo]:
		if n != null:
			(n as Node2D).queue_redraw()


# ------------------------------------------------------------
#  PIEZAS
# ------------------------------------------------------------
static func _sale(t: float, dur: float) -> float:
	var k: float = clampf(t / dur, 0.0, 1.0)
	return 1.0 - (1.0 - k) * (1.0 - k)


func _en_swing(s: float) -> Vector2:
	var a: Vector2 = _swing[0]
	var b: Vector2 = _swing[1]
	var c: Vector2 = _swing[2]
	return a.lerp(b, s).lerp(b.lerp(c, s), s)


# LA ESTELA DEL PALO (la de la maza, MATE): banda rellena por la curva, gorda en la punta y a nada hacia la cola;
# madera clara en el eje y madera hacia los bordes. Sin el blanco del metal: un palo no brilla.
func _estela(ci: CanvasItem, s_cola: float, s_cabeza: float, grueso: float, alfa: float) -> void:
	if alfa <= 0.0 or s_cabeza - s_cola < 0.01:
		return
	var n: int = 10
	for i in n:
		var u0: float = float(i) / float(n)
		var u1: float = float(i + 1) / float(n)
		var p0: Vector2 = _en_swing(lerpf(s_cola, s_cabeza, u0))
		var p1: Vector2 = _en_swing(lerpf(s_cola, s_cabeza, u1))
		var d: Vector2 = (p1 - p0).normalized().orthogonal() if p1.distance_squared_to(p0) > 0.0001 else _lat
		var w0: float = grueso * pow(u0, 1.3)
		var w1: float = grueso * pow(u1, 1.3)
		var c0 := Color(MADERA_CLARA, alfa * u0)
		var c1 := Color(MADERA_CLARA, alfa * u1)
		var h0 := Color(MADERA, alfa * 0.6 * u0)
		var h1 := Color(MADERA, alfa * 0.6 * u1)
		var tr := Color(MADERA, 0.0)
		for lado in [1.0, -1.0]:
			ci.draw_primitive(PackedVector2Array([p0, p1, p1 + d * w1 * 0.45 * lado]), PackedColorArray([c0, c1, h1]), PackedVector2Array())
			ci.draw_primitive(PackedVector2Array([p0, p1 + d * w1 * 0.45 * lado, p0 + d * w0 * 0.45 * lado]),
				PackedColorArray([c0, h1, h0]), PackedVector2Array())
			ci.draw_primitive(PackedVector2Array([p0 + d * w0 * 0.45 * lado, p1 + d * w1 * 0.45 * lado, p1 + d * w1 * lado]),
				PackedColorArray([h0, h1, tr]), PackedVector2Array())
			ci.draw_primitive(PackedVector2Array([p0 + d * w0 * 0.45 * lado, p1 + d * w1 * lado, p0 + d * w0 * lado]),
				PackedColorArray([h0, tr, tr]), PackedVector2Array())


# UN ROMBO relleno (una runa, una mota arcana): el centro claro y las puntas a nada.
static func _rombo(ci: CanvasItem, c: Vector2, r: float, giro: float, centro: Color, borde: Color) -> void:
	if centro.a <= 0.005 or r <= 0.2:
		return
	var tr := Color(borde, 0.0)
	for i in 4:
		var a0: float = giro + TAU * float(i) / 4.0
		var a1: float = giro + TAU * float(i + 1) / 4.0
		var largo0: float = r * (1.0 if i % 2 == 0 else 0.55)
		var largo1: float = r * (1.0 if (i + 1) % 2 == 0 else 0.55)
		var p0: Vector2 = c + Vector2(cos(a0), sin(a0) * K) * largo0
		var p1: Vector2 = c + Vector2(cos(a1), sin(a1) * K) * largo1
		ci.draw_primitive(PackedVector2Array([c, p0, p1]), PackedColorArray([centro, tr, tr]), PackedVector2Array())
		ci.draw_primitive(PackedVector2Array([c, c.lerp(p0, 0.55), c.lerp(p1, 0.55)]),
			PackedColorArray([centro, borde, borde]), PackedVector2Array())


# ------------------------------------------------------------
#  DIBUJO SOBRE UN CUERPO
# ------------------------------------------------------------
func _draw() -> void:
	if forma != null:
		_dibujar_suelo_area()
		return
	match modo:
		Modo.GOLPE, Modo.BASTONAZO_C:
			_dibujar_porrazo()
		Modo.VIENTO_C:
			_dibujar_viento_cuerpo()
		Modo.FOCO:
			_dibujar_foco()
		Modo.VELO:
			_dibujar_velo()
		Modo.PURIFICAR:
			_dibujar_purificar()
		Modo.CHISPA:
			_dibujar_chispa()
		Modo.EGIDA:
			_dibujar_egida()


func _dibujar_porrazo() -> void:
	var fuerte: bool = modo == Modo.BASTONAZO_C
	var grueso: float = 7.0 if fuerte else 5.0
	# 1) EL PALO QUE LLEGA: acaba en el golpe y se apaga enseguida.
	var s: float = clampf((_t + T_SWING) / T_SWING, 0.0, 1.0)
	if s > 0.0:
		var apaga: float = clampf(_t / 0.1, 0.0, 1.0)
		_estela(self, maxf(0.0, s - 0.75), s * s * (3.0 - 2.0 * s), grueso, (0.45 if _fallo else 0.9) * (1.0 - apaga))
	if _t < 0.0 or _fallo:
		return
	var esc: float = (1.0 if fuerte else 0.75) * (1.3 if _crit else 1.0)
	# 2) EL DESTELLO del golpe, crema (no el blanco del acero) y corto.
	var pulso: float = exp(-_t / 0.045)
	BarridoAire.destello(self, _imp, (6.0 + 7.0 * pulso) * esc, Color(MADERA_CLARA.lerp(BLANCO, 0.5), pulso), _dir.angle() + 0.4 * _lado)
	# 3) LA MANCHA ROMA, que se abre y se apaga.
	var km: float = _sale(_t, 0.05)
	var am: float = 1.0 - clampf(_t / 0.18, 0.0, 1.0)
	if am > 0.0:
		var r_m: float = 6.0 * esc * (0.6 + 0.4 * km)
		var poly := PackedVector2Array()
		for q in _mancha:
			poly.append(_imp + q * r_m)
		draw_colored_polygon(poly, Color(MADERA_CLARA, 0.45 * am))
		BarridoAire.brillo(self, _imp, r_m * 0.5, Color(MADERA_CLARA.lerp(BLANCO, 0.6), 0.8 * am))
	# 4) LA ONDA por detras (hacia donde empuja): en el Bastonazo, dos.
	for k in (2 if fuerte else 1):
		var tk: float = _t - 0.05 * float(k)
		if tk < 0.0 or tk > 0.2:
			continue
		var ko: float = _sale(tk, 0.2)
		var ang: float = _dir.angle()
		MazaAire._arco(self, _imp + _dir * 3.0 * float(k), (4.0 + 12.0 * ko) * esc, lerpf(5.0, 2.5, ko) * esc, ang - 1.4, ang + 1.4,
			Color(MADERA_CLARA.lerp(BLANCO, 0.5), 0.75 * (1.0 - ko)), Color(POLVO, 0.3 * (1.0 - ko)))


func _dibujar_viento_cuerpo() -> void:
	if _t < 0.0:
		return
	# El aire le da UNA VUELTA a la altura del pecho, subiendo: dos cometas que giran en elipse (con perspectiva).
	var kv: float = clampf(_t / 0.45, 0.0, 1.0)
	if kv < 1.0:
		for j in 2:
			var ang: float = _dir.angle() + PI * float(j) + TAU * 1.1 * _sale(_t, 0.45)
			var alto: float = lerpf(4.0, -ALTO_TORSO * 0.9, kv)
			var p: Vector2 = _pies + Vector2(cos(ang) * 11.0, sin(ang) * 11.0 * K + alto - ALTO_TORSO * 0.3)
			var p_ant: Vector2 = _pies + Vector2(cos(ang - 0.7) * 11.0, sin(ang - 0.7) * 11.0 * K + alto + 3.0 - ALTO_TORSO * 0.3)
			BarridoAire.cometa(self, p_ant, p, 3.0, Color(VIENTO_CLARO, 0.9 * (1.0 - kv)))
	# Y se lleva la porqueria: motas oscuras que salen volando hacia donde sopla y se deshacen.
	for m in _motas:
		var tp: float = _t - float(m["t0"])
		if tp < 0.0 or tp > 0.45:
			continue
		var p2: Vector2 = (m["p"] as Vector2) + (m["v"] as Vector2) * tp
		var col: Color = SOMBRA.lerp(VIENTO, _sale(tp, 0.45))
		BarridoAire.cometa(self, p2 - (m["v"] as Vector2).normalized() * 5.0, p2, float(m["tam"]), Color(col, 0.9 * (1.0 - tp / 0.45)))


func _dibujar_foco() -> void:
	if _t < 0.0:
		return
	# LA PUNTA: en alto, por delante del pecho (el baston levantado; la varita, mas baja y cerca).
	var punta: Vector2 = _c + Vector2(0.0, -ALTO_CABEZA * (0.55 if escala >= 1.0 else 0.2) - 4.0)
	var t_junta: float = 0.32
	for m in _motas:
		var tp: float = _t - float(m["t0"])
		if tp < 0.0 or tp > t_junta:
			continue
		var u: float = _sale(tp, t_junta)
		var a: float = float(m["a"]) + 2.2 * u
		var r: float = float(m["r"]) * (1.0 - u)
		var p: Vector2 = punta + Vector2(cos(a), sin(a) * K) * r
		_rombo(self, p, 4.8 * escala * (1.0 - 0.3 * u), float(m["giro"]) + 4.0 * u, Color(ARCANO_CLARO, 0.95), Color(ARCANO, 0.6))
		var p_ant: Vector2 = punta + Vector2(cos(a - 0.5), sin(a - 0.5) * K) * minf(r + 5.0, float(m["r"]))
		BarridoAire.cometa(self, p_ant, p, 3.2 * escala, Color(ARCANO, 0.8 * (1.0 - u * 0.5)))
	# Al juntarse: el destello en la punta y el brillo que se queda un momento.
	var tk: float = _t - t_junta
	if tk >= 0.0:
		var pulso: float = exp(-tk / 0.07)
		BarridoAire.brillo(self, punta, (10.0 + 6.0 * _sale(tk, 0.3)) * escala, Color(ARCANO, 0.5 * (1.0 - _sale(tk, 0.4))))
		BarridoAire.destello(self, punta, (7.0 + 12.0 * pulso) * escala, Color(ARCANO_CLARO, pulso), 0.25)


func _dibujar_velo() -> void:
	if _t < 0.0:
		return
	# EL MANTO DE SOMBRA CAE de encima de la cabeza hasta los pies y se deshace (el cuerpo ya queda medio transparente).
	var k: float = _sale(_t, T_CAE_VELO)
	var va: float = clampf((_t - T_CAE_VELO) / 0.35, 0.0, 1.0)
	if va >= 1.0:
		return
	var arriba: float = _pies.y - ALTO_CABEZA - 10.0
	var borde_y: float = lerpf(arriba, _pies.y + 2.0, k)
	var media: float = 13.0
	var n: int = 10
	for i in n:
		var u0: float = float(i) / float(n)
		var u1: float = float(i + 1) / float(n)
		var x0: float = lerpf(-media, media, u0)
		var x1: float = lerpf(-media, media, u1)
		# La tela: mas ancha abajo, con el borde ondulado que cae.
		var y0: float = borde_y + 2.5 * sin(u0 * 9.0 + _t * 14.0)
		var y1: float = borde_y + 2.5 * sin(u1 * 9.0 + _t * 14.0)
		var top0 := Vector2(_pies.x + x0 * 0.55, arriba)
		var top1 := Vector2(_pies.x + x1 * 0.55, arriba)
		var bot0 := Vector2(_pies.x + x0, y0)
		var bot1 := Vector2(_pies.x + x1, y1)
		# Mas opaca en el centro y a nada en los lados; el borde de abajo un poco mas claro (la sombra que cae).
		var lado0: float = 1.0 - pow(absf(u0 * 2.0 - 1.0), 2.0)
		var lado1: float = 1.0 - pow(absf(u1 * 2.0 - 1.0), 2.0)
		var alfa: float = 0.8 * (1.0 - va)
		var ct0 := Color(SOMBRA, 0.0)
		var ct1 := Color(SOMBRA, 0.0)
		var cb0 := Color(SOMBRA_BORDE, alfa * lado0)
		var cb1 := Color(SOMBRA_BORDE, alfa * lado1)
		var cm0 := Color(SOMBRA, alfa * lado0)
		var cm1 := Color(SOMBRA, alfa * lado1)
		var mid0: Vector2 = top0.lerp(bot0, 0.6)
		var mid1: Vector2 = top1.lerp(bot1, 0.6)
		draw_primitive(PackedVector2Array([top0, top1, mid1]), PackedColorArray([ct0, ct1, cm1]), PackedVector2Array())
		draw_primitive(PackedVector2Array([top0, mid1, mid0]), PackedColorArray([ct0, cm1, cm0]), PackedVector2Array())
		draw_primitive(PackedVector2Array([mid0, mid1, bot1]), PackedColorArray([cm0, cm1, cb1]), PackedVector2Array())
		draw_primitive(PackedVector2Array([mid0, bot1, bot0]), PackedColorArray([cm0, cb1, cb0]), PackedVector2Array())


func _dibujar_purificar() -> void:
	if _t < 0.0:
		return
	# LA COLUMNA DE LUZ: una banda vertical rellena, clara en el eje y a nada a los lados y arriba; se queda y se va.
	var kc: float = _sale(_t, 0.12)
	var va: float = clampf((_t - 0.5) / 0.35, 0.0, 1.0)
	var alfa: float = kc * (1.0 - va)
	if alfa > 0.0:
		var ancho: float = 11.0 * (0.4 + 0.6 * kc)
		var arriba: float = _pies.y - ALTO_CABEZA - 26.0
		var n: int = 6
		for i in n:
			var y0: float = lerpf(_pies.y + 2.0, arriba, float(i) / float(n))
			var y1: float = lerpf(_pies.y + 2.0, arriba, float(i + 1) / float(n))
			var a0: float = alfa * (1.0 - float(i) / float(n))
			var a1: float = alfa * (1.0 - float(i + 1) / float(n))
			for lado in [1.0, -1.0]:
				var e0 := Vector2(_pies.x + ancho * lado, y0)
				var e1 := Vector2(_pies.x + ancho * lado, y1)
				var c0 := Vector2(_pies.x, y0)
				var c1 := Vector2(_pies.x, y1)
				draw_primitive(PackedVector2Array([c0, c1, e1]), PackedColorArray([Color(LUZ, 0.55 * a0), Color(LUZ, 0.55 * a1), Color(LUZ, 0.0)]), PackedVector2Array())
				draw_primitive(PackedVector2Array([c0, e1, e0]), PackedColorArray([Color(LUZ, 0.55 * a0), Color(LUZ, 0.0), Color(LUZ, 0.0)]), PackedVector2Array())
	var pulso: float = exp(-_t / 0.06)
	BarridoAire.destello(self, _c + Vector2(0.0, -ALTO_TORSO * 0.3), 6.0 + 10.0 * pulso, Color(LUZ, pulso), 0.0)
	# Lo que llevaba encima: motas oscuras que suben, se aclaran y se evaporan.
	for m in _motas:
		var tp: float = _t - float(m["t0"])
		if tp < 0.0 or tp > 0.45:
			continue
		var u: float = tp / 0.45
		var p: Vector2 = (m["p"] as Vector2) + Vector2(0.0, -float(m["v"]) * tp)
		BarridoAire.cometa(self, p + Vector2(0.0, 6.0), p, float(m["tam"]), Color(SOMBRA.lerp(LUZ, u), 0.9 * (1.0 - u)))


func _dibujar_chispa() -> void:
	if _t < 0.0:
		return
	# GOTAS DE MANA en arco, de tu mano a su pecho (sin hilo: cometas que van una detras de otra).
	var a: Vector2 = _desde
	var b: Vector2 = _c + Vector2(0.0, -ALTO_TORSO * 0.2)
	for m in _motas:
		var tp: float = _t - float(m["t0"])
		if tp < 0.0 or tp > T_CHISPA:
			continue
		var u: float = tp / T_CHISPA
		var p: Vector2 = _en_arco_chispa(a, b, u, float(m["arco"]), float(m["lado"]))
		var p_ant: Vector2 = _en_arco_chispa(a, b, maxf(u - 0.12, 0.0), float(m["arco"]), float(m["lado"]))
		BarridoAire.cometa(self, p_ant, p, 2.6, Color(MANA_CLARO, 0.95))
		BarridoAire.brillo(self, p, 4.0, Color(MANA, 0.45))
	# En tu mano, el brillo mientras salen; en la suya, un latido por cada gota que llega.
	var sale: float = 1.0 - clampf((_t - 0.35) / 0.2, 0.0, 1.0)
	BarridoAire.brillo(self, a, 6.0, Color(MANA, 0.5 * sale))
	var t_llega: float = _t - T_CHISPA
	if t_llega >= 0.0:
		var late: float = exp(-fmod(t_llega, 0.05) / 0.04) * (1.0 - clampf((t_llega - 0.3) / 0.4, 0.0, 1.0))
		BarridoAire.brillo(self, b, 10.0, Color(MANA, 0.45 * (1.0 - _sale(t_llega, 0.7))))
		BarridoAire.destello(self, b, 5.0 + 6.0 * late, Color(MANA_CLARO, late), 0.3)


static func _en_arco_chispa(a: Vector2, b: Vector2, u: float, arco: float, lado: float) -> Vector2:
	var p: Vector2 = a.lerp(b, u)
	return p + Vector2(0.0, -arco * 4.0 * u * (1.0 - u)) + (b - a).normalized().orthogonal() * lado * sin(PI * u)


func _dibujar_egida() -> void:
	if _t < 0.0:
		return
	# EL HEXAGONO DE LUZ, de pie delante de el, hacia su enemigo mas cercano. De canto se estrecha (perspectiva):
	# su ancho en pantalla es lo que tiene de lado la direccion a la que mira.
	var hacia: Vector2 = _hacia.normalized() if _hacia.length_squared() > 0.01 else _dir
	var frente: Vector2 = Vector2(hacia.x, hacia.y * K)
	var centro: Vector2 = _c + frente * 9.0 + Vector2(0.0, -2.0)
	var ancho: float = maxf(absf(hacia.y), 0.3)   # de frente (N/S) se ve entero; de lado (E/O), de canto
	var k: float = _sale(_t, 0.14)
	var va: float = clampf((_t - 0.55) / 0.3, 0.0, 1.0)
	var alfa: float = k * (1.0 - va)
	if alfa <= 0.0:
		return
	var r: float = 10.0 * (0.5 + 0.5 * k)
	var pts: Array = []
	for i in 6:
		var a: float = PI / 6.0 + TAU * float(i) / 6.0
		pts.append(centro + Vector2(cos(a) * r * ancho, sin(a) * r))
	# El borde claro y el centro casi transparente (la luz esta en el filo).
	var dentro := Color(LUZ, 0.12 * alfa)
	var filo := Color(LUZ.lerp(BLANCO, 0.5), 0.9 * alfa)
	var medio := Color(LUZ, 0.35 * alfa)
	for i in 6:
		var p0: Vector2 = pts[i]
		var p1: Vector2 = pts[(i + 1) % 6]
		var m0: Vector2 = centro.lerp(p0, 0.72)
		var m1: Vector2 = centro.lerp(p1, 0.72)
		draw_primitive(PackedVector2Array([centro, m0, m1]), PackedColorArray([dentro, medio, medio]), PackedVector2Array())
		draw_primitive(PackedVector2Array([m0, p0, p1]), PackedColorArray([medio, filo, filo]), PackedVector2Array())
		draw_primitive(PackedVector2Array([m0, p1, m1]), PackedColorArray([medio, filo, medio]), PackedVector2Array())
	var pulso: float = exp(-_t / 0.06)
	BarridoAire.destello(self, pts[0], 5.0 + 8.0 * pulso, Color(BLANCO, pulso), 0.5)


# Lo de los pies de un cuerpo.
func _dibujar_suelo_cuerpo() -> void:
	if _t < 0.0:
		return
	match modo:
		Modo.BASTONAZO_C:
			if _fallo:
				return
			# EL EMPUJON: polvo que se levanta por detras de los pies y se queda atras (el cuerpo se va hacia _dir).
			var k: float = clampf(_t / 0.45, 0.0, 1.0)
			var atras: Vector2 = Vector2(-_dir.x, -_dir.y * K).normalized() if _dir.length_squared() > 0.0 else Vector2.LEFT
			for j in 4:
				var q: Vector2 = _pies + atras * (2.0 + 6.0 * float(j) * k) + _lat * (float(j % 2) * 2.0 - 1.0) * 3.0 * k
				BarridoAire.brillo(_suelo, q, 4.0 + 5.0 * k, Color(POLVO, 0.6 * (1.0 - k)))
		Modo.VIENTO_C:
			var k2: float = _sale(_t, 0.3)
			BarridoAire.brillo(_suelo, _pies, 8.0 + 10.0 * k2, Color(VIENTO, 0.45 * (1.0 - k2)))
		Modo.FOCO:
			# El signo pequeño a tus pies, que gira y se apaga.
			var k3: float = _sale(_t, 0.2)
			var va3: float = clampf((_t - 0.4) / 0.3, 0.0, 1.0)
			BarridoAire.brillo(_suelo, _pies, (13.0 + 4.0 * k3) * escala, Color(ARCANO, 0.35 * k3 * (1.0 - va3)))
			for i in 4:
				var a: float = _t * 3.0 + TAU * float(i) / 4.0
				_rombo(_suelo, _pies + Vector2(cos(a), sin(a)) * (9.0 + 4.0 * k3) * escala, 3.6 * escala, a,
					Color(ARCANO_CLARO, 0.8 * k3 * (1.0 - va3)), Color(ARCANO, 0.4 * k3 * (1.0 - va3)))
		Modo.VELO:
			# La sombra que se queda a tus pies y el humo que sube de ella.
			var k4: float = _sale(_t - T_CAE_VELO * 0.6, 0.2)
			var va4: float = clampf((_t - T_CAE_VELO - 0.2) / 0.4, 0.0, 1.0)
			BarridoAire.brillo(_suelo, _pies, 14.0 * k4, Color(SOMBRA, 0.55 * k4 * (1.0 - va4)))
			for m in _motas:
				var tp: float = _t - float(m["t0"])
				if tp < 0.0 or tp > 0.5:
					continue
				var p: Vector2 = _pies + Vector2(float(m["x"]), -2.0) + (m["v"] as Vector2) * tp
				BarridoAire.brillo(_suelo, p, float(m["r"]) * (0.6 + tp), Color(SOMBRA_BORDE, 0.45 * (1.0 - tp / 0.5)))
		Modo.PURIFICAR:
			var k5: float = _sale(_t, 0.25)
			var va5: float = clampf((_t - 0.5) / 0.35, 0.0, 1.0)
			BarridoAire.brillo(_suelo, _pies, 10.0 + 8.0 * k5, Color(LUZ, 0.5 * (1.0 - va5)))


# ------------------------------------------------------------
#  DIBUJO EN EL SUELO (la huella)
# ------------------------------------------------------------
func _dibujar_suelo_area() -> void:
	if _t < 0.0:
		return
	match modo:
		Modo.SELLO:
			var a0: float = float(_runas[0]["a0"])
			var sentido: float = float(_runas[0]["s"])
			var kt: float = _sale(_t, T_TRAZO)
			# Se cierra: el anillo y las runas van al centro entre el trazo y el golpe.
			var kc: float = clampf((_t - T_TRAZO) / (T_CIERRA - T_TRAZO), 0.0, 1.0)
			kc = kc * kc
			var va: float = clampf((_t - T_CIERRA) / 0.12, 0.0, 1.0)
			if va < 1.0:
				var r_s: float = _r * lerpf(1.0, 0.12, kc)
				var a1: float = a0 + sentido * TAU * kt
				MazaAire._arco(self, _centro, r_s, lerpf(8.0, 4.0, kc), minf(a0, a1), maxf(a0, a1),
					Color(ARCANO_CLARO, 0.95 * (1.0 - va)), Color(ARCANO, 0.45 * (1.0 - va)))
				# El anillo de dentro, fino, que acompaña (el signo tiene dos vueltas).
				if kt > 0.3:
					MazaAire._arco(self, _centro, r_s * 0.62, 4.0, 0.0, TAU, Color(ARCANO_CLARO, 0.5 * (kt - 0.3) / 0.7 * (1.0 - va)),
						Color(ARCANO, 0.2 * (1.0 - va)))
				# Las RUNAS: salen cuando el anillo pasa por su sitio.
				for i in range(1, _runas.size()):
					var ru: Dictionary = _runas[i]
					if kt < float(ru["u"]):
						continue
					var ka: float = clampf((kt - float(ru["u"])) / 0.12, 0.0, 1.0)
					var a: float = float(ru["a"]) + sentido * 1.2 * kc
					var p: Vector2 = _centro + Vector2(cos(a), sin(a)) * r_s * 0.81
					_rombo(self, p, 4.2 * ka * (1.0 - 0.5 * kc), float(ru["giro"]), Color(ARCANO_CLARO, 0.95 * (1.0 - va)),
						Color(ARCANO, 0.55 * (1.0 - va)))
				BarridoAire.brillo(self, _centro, _r * lerpf(0.7, 0.3, kc), Color(ARCANO, 0.12 * kt * (1.0 - va)))
			# Al cerrarse, el signo quemado en el suelo un momento.
			var tk: float = _t - T_CIERRA
			if tk >= 0.0:
				var ks: float = _sale(tk, 0.25)
				MazaAire._arco(self, _centro, 6.0 + _r * 0.8 * ks, lerpf(10.0, 3.0, ks), 0.0, TAU,
					Color(ARCANO_CLARO, 0.8 * (1.0 - ks)), Color(ARCANO, 0.35 * (1.0 - ks)))
		Modo.BARRE:
			# Nada en el suelo salvo el polvo del empujon: el palo va por el aire (capas).
			pass
		Modo.VIENTO:
			# Un soplo claro que barre el cono al paso del frente (brillos por el suelo, sin borde).
			var frente: float = _t * V_VIENTO
			var mitad: float = deg_to_rad(forma.apertura * 0.5)
			if frente < _r + 30.0:
				for i in 5:
					var a: float = _dir.angle() + lerpf(-mitad, mitad, (float(i) + 0.5) / 5.0)
					var d: float = minf(frente, _r) * 0.9
					BarridoAire.brillo(self, _centro + Vector2(cos(a), sin(a)) * d, 18.0,
						Color(VIENTO, 0.3 * (1.0 - clampf(frente / (_r + 30.0), 0.0, 1.0))))


# ------------------------------------------------------------
#  LO DEL AIRE de la huella (capas detras y delante de los cuerpos)
# ------------------------------------------------------------
func _dibujar_capa(capa: Node2D) -> void:
	match modo:
		Modo.BARRE:
			var mitad: float = deg_to_rad(forma.apertura * 0.5)
			var izq: float = _dir.angle() - mitad
			var der: float = _dir.angle() + mitad
			# De que lado empieza: al azar por la semilla (no siempre igual).
			var desde: float = izq if (int(_rng.seed) & 2) == 0 else der
			var hasta: float = der if desde == izq else izq
			_barrido(capa, desde, hasta, _r * 0.92, _r * 0.62)
			# LA RACHA DEL EMPUJON: polvo que sale hacia fuera detras del palo, al paso.
			for m in _motas:
				var u: float = float(m["u"])
				var cuando: float = T_BARRE * sqrt(u)
				var tp: float = _t - cuando
				if tp < 0.0 or tp > 0.45:
					continue
				var ang: float = lerpf(desde, hasta, u)
				var p: Vector2 = _centro + Vector2(cos(ang), sin(ang)) * (float(m["r"]) + float(m["v"]) * tp) + Vector2(0.0, -2.0)
				if not _es_mia(capa, p + Vector2(0.0, -ALTO_BARRIDO)):
					continue
				BarridoAire.brillo(capa, p, float(m["tam"]) * (0.7 + tp), Color(POLVO, 0.5 * (1.0 - tp / 0.45)))
		Modo.VIENTO:
			if capa != _delante:
				return
			# LAS RACHAS: cometas que salen de ti y recorren el cono, curvandose un poco, a distintas alturas.
			for ra in _rachas:
				var tp: float = _t - float(ra["t0"])
				if tp < 0.0:
					continue
				var d: float = tp * V_VIENTO
				if d > _r + 20.0:
					continue
				var a: float = float(ra["a"]) + float(ra["curva"]) * (d / _r)
				var p: Vector2 = _centro + Vector2(cos(a), sin(a)) * d + Vector2(0.0, -float(ra["alto"]))
				var d0: float = maxf(d - 36.0, 0.0)
				var a_ant: float = float(ra["a"]) + float(ra["curva"]) * (d0 / _r)
				var p_ant: Vector2 = _centro + Vector2(cos(a_ant), sin(a_ant)) * d0 + Vector2(0.0, -float(ra["alto"]))
				var al: float = 0.9 * (1.0 - clampf((d - _r * 0.75) / (_r * 0.25 + 20.0), 0.0, 1.0))
				BarridoAire.cometa(capa, p_ant, p, float(ra["ancho"]), Color(VIENTO_CLARO, al))
		Modo.SELLO:
			if capa != _delante:
				return
			# EL CIERRE: el destello arcano en el centro, que es el golpe.
			var tk: float = _t - T_CIERRA
			if tk >= -0.02:
				var pulso: float = exp(-maxf(tk, 0.0) / 0.06)
				BarridoAire.destello(capa, _centro + Vector2(0.0, -4.0), 10.0 + 16.0 * pulso, Color(ARCANO_CLARO, pulso), 0.4)
				BarridoAire.brillo(capa, _centro + Vector2(0.0, -4.0), 16.0, Color(ARCANO, 0.45 * pulso))


# EL BARRIDO DEL PALO (MazaAire._barrido, en MATE): lento al salir y rapido al final, clavado un instante y fuera.
func _barrido(capa: Node2D, desde: float, hasta: float, r: float, grueso: float) -> void:
	if _t < 0.0:
		return
	var s: float = clampf(_t / T_BARRE, 0.0, 1.0)
	var cabeza: float = lerpf(desde, hasta, s * s)
	var tc: float = _t - T_BARRE
	var apaga: float = clampf((tc - T_CLAVADO) / T_APAGA_SECO, 0.0, 1.0)
	if apaga >= 1.0:
		return
	var recoge: float = clampf(tc / T_CLAVADO, 0.0, 1.0) if tc > 0.0 else 0.0
	var sentido: float = signf(hasta - desde)
	var cola: float = cabeza - sentido * minf(COLA * (1.0 - 0.55 * recoge), absf(cabeza - desde))
	var alfa: float = 1.0 * (1.0 - apaga)
	var n: int = maxi(8, int(absf(cabeza - cola) / 0.06))
	var fr: Array = [0.0, 0.15, 0.45, 0.8, 1.0]
	var cols: Array = [MADERA_CLARA, MADERA_CLARA, MADERA, POLVO, POLVO]
	var al: Array = [1.0, 0.95, 0.7, 0.35, 0.0]
	for i in n:
		var s0: float = float(i) / float(n)
		var s1: float = float(i + 1) / float(n)
		var a0: float = lerpf(cola, cabeza, s0)
		var a1: float = lerpf(cola, cabeza, s1)
		if not _es_mia(capa, _en_arco((a0 + a1) * 0.5, r)):
			continue
		var g0: float = grueso * (0.15 + 0.85 * pow(s0, 1.2))
		var g1: float = grueso * (0.15 + 0.85 * pow(s1, 1.2))
		var l0: float = alfa * (0.3 + 0.7 * s0)
		var l1: float = alfa * (0.3 + 0.7 * s1)
		for k in fr.size() - 1:
			var p00: Vector2 = _en_arco(a0, r - g0 * float(fr[k]))
			var p10: Vector2 = _en_arco(a1, r - g1 * float(fr[k]))
			var p01: Vector2 = _en_arco(a0, r - g0 * float(fr[k + 1]))
			var p11: Vector2 = _en_arco(a1, r - g1 * float(fr[k + 1]))
			var c00 := Color(cols[k], l0 * float(al[k]))
			var c10 := Color(cols[k], l1 * float(al[k]))
			var c01 := Color(cols[k + 1], l0 * float(al[k + 1]))
			var c11 := Color(cols[k + 1], l1 * float(al[k + 1]))
			capa.draw_primitive(PackedVector2Array([p00, p10, p11]), PackedColorArray([c00, c10, c11]), PackedVector2Array())
			capa.draw_primitive(PackedVector2Array([p00, p11, p01]), PackedColorArray([c00, c11, c01]), PackedVector2Array())
	var p: Vector2 = _en_arco(cabeza, r)
	if _es_mia(capa, p) and tc >= 0.0:
		var pulso: float = exp(-tc / 0.04)
		BarridoAire.destello(capa, p, 5.0 + 9.0 * pulso, Color(MADERA_CLARA.lerp(BLANCO, 0.5), (1.0 - apaga) * pulso), _t * 2.0)


func _en_arco(a: float, r: float) -> Vector2:
	return _centro + Vector2(cos(a), sin(a)) * r + Vector2(0.0, -ALTO_BARRIDO)


func _es_mia(capa: Node2D, p: Vector2) -> bool:
	return (p.y < _centro.y - ALTO_BARRIDO) == (capa == _atras)
