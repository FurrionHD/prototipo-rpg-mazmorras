# ============================================================
#  maza_aire.gd
#  LOS EFECTOS DE LA MAZA PEQUEÑA en el mapa (25/09/2026). Arma CONTUNDENTE: nada corta, todo REVIENTA. Copia
#  las piezas de los que le gustan: el suelo del martillo (crater, grietas, piedras: SueloRoto), el barrido del
#  hacha y la espada (EspadaAire._barrido) y los anillos rellenos de ApoyoAire. NADA DE LINEAS.
#  EN EL SUELO (por SueloRoto: la ficha dice cual; el de DOS MANOS lo elige SueloRoto.con_manos):
#    DEMOLEDOR     Golpe demoledor: la maza cae en la punta, crater con grietas cortas y la RESONANCIA (anillos
#                  escalonados hasta el borde de la huella, que es el frente del daño). UN SOLO golpe al suelo que
#                  alcanza a todos: nada en cada cuerpo, como el Golpe sismico (26/09, lo pidio el).
#    DEMOLEDOR_DOS con dos mazas A LA VEZ: dos craters juntos, un anillo mas y mas gordos.
#    ROMPE         Rompepiernas: un barrido BAJO de la cabeza de la maza, de hierro y polvo, que levanta tierra.
#    ROMPE_DOS     con dos mazas: ida con una y vuelta con la otra (como el Doble tajo), las dos a ras de suelo.
#    APLASTA       Aplastamiento: el mazazo al suelo, crater pequeño y un anillo; nada en cada cuerpo (el escudazo
#                  de despues si, es de EscudoAire y solo a los de su linea).
#    ALIENTO       Grito de aliento: dos ondas CALIDAS hasta el borde y un destello en alto (la maza alzada).
#    ALIENTO_DOS   con dos mazas: las entrechocas en alto y saltan chispas.
#    MURO          Muro de aliados: un golpe al suelo a tus pies y un anillo azul que se CIERRA hacia ti.
#  SOBRE UN CUERPO (CombatTactico._on_dibujo_mapa, golpe a golpe):
#    PORRAZO       el basico: la cabeza de la maza entra de lado y de arriba (cambia de lado en cada golpe: dos
#                  mazas, una y otra), la mancha ROMA del impacto, la onda que sale por detras y esquirlas.
#    CULATAZO      con el mango, a la cabeza: un golpe recto, corto y seco, y un destello duro.
#    ROMPE_C       el Rompepiernas en cada uno: el porrazo a la rodilla, de lado, y polvo a los pies.
#    ALIENTO_C     Grito de aliento, en cada uno de los tuyos: brio calido que le sube de los pies al pecho.
#    MURO_C        Muro de aliados, en cada uno: su marca azul y la estela por el suelo hacia ti (se arrima).
#  Coordenadas de MUNDO; el suelo SIN achatar (como las huellas); la altura a K. Todo sale de una semilla.
# ============================================================
extends Node2D
class_name MazaAire

# Los del suelo (DEMOLEDOR..MURO) van en el orden de SueloRoto.Tipo.MAZA_*: no reordenar.
enum Modo { DEMOLEDOR, DEMOLEDOR_DOS, ROMPE, ROMPE_DOS, APLASTA, ALIENTO, ALIENTO_DOS, MURO,
	PORRAZO, CULATAZO, ROMPE_C, ALIENTO_C, MURO_C }

const K := 0.7071
const BLANCO := BarridoAire.BLANCO
const HIERRO := Color(0.70, 0.70, 0.74)
const HIERRO_OSCURO := Color(0.42, 0.42, 0.46)
const POLVO := SueloRoto.POLVO
const TIERRA := Color(0.45, 0.40, 0.33)
const OSCURO := SueloRoto.OSCURO
const LABIO := SueloRoto.LABIO
const GUARDIA := Color(0.62, 0.78, 1.0)
const BRIO := Color(1.0, 0.55, 0.22)
const BRIO_CLARO := Color(1.0, 0.86, 0.62)
const Z_ENCIMA := Game.Z_PERSONAJES + 80
const ALTO_TORSO := 14.0
const ALTO_CABEZA := 26.0
const GRAVEDAD := 380.0

const T_SWING := 0.06         # lo que tarda la cabeza de la maza en llegar (acaba EN el golpe)
const T_JAB := 0.04           # el culatazo: mas corto todavia
const T_ONDA_DEM := 0.2       # la resonancia del Demoledor hasta el borde (el frente del daño)
const T_ONDA_APLASTA := 0.12
const T_BARRE := EspadaAire.T_BARRE
const T_ENTRE := BarridoAire.T_ENTRE   # entre la ida y la vuelta del Rompepiernas a dos mazas
const T_CLAVADO := 0.08
const T_APAGA_SECO := 0.1
const T_SUELO := 0.5
const T_SUELO_APAGAR := 0.45
const COLA := deg_to_rad(80.0)   # la cola del barrido: mas corta y gorda que la de la espada (es una bola)
const ALTO_BARRIDO := 3.0        # el Rompepiernas, a la altura de las rodillas
const T_ONDA_APOYO := 0.35
# El paso del Muro de aliados, para que la marca vaya con el cuerpo: = ficha junta_aliados, CombatTactico.SEPARACION + 2
# y CombatTactico.T_PASO.
const MURO_PASO := 25.0
const MURO_SEPARA := 24.0
const MURO_T_PASO := 0.16

var modo: int = Modo.PORRAZO
var forma: CombatFormas.Forma = null
var nucleo: float = 0.0
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
# Sobre un cuerpo.
var _caja: Rect2 = Rect2()
var _fallo: bool = false
var _crit: bool = false
var _n: int = 0
var _c: Vector2 = Vector2.ZERO
var _imp: Vector2 = Vector2.ZERO      # donde toca la maza
var _pies: Vector2 = Vector2.ZERO
var _desde: Vector2 = Vector2.ZERO
var _dir: Vector2 = Vector2.RIGHT     # de quien pega al cuerpo (en pantalla)
var _lat: Vector2 = Vector2.RIGHT     # el lado, con la perspectiva
var _lado: float = 1.0
var _swing: Array = []                # la curva por la que llega la cabeza: [ini, control, fin]
var _mancha: PackedVector2Array = PackedVector2Array()   # la mancha roma, en local (se escala)
var _esquirlas: Array = []
var _motas: Array = []
# El suelo.
var _centro: Vector2 = Vector2.ZERO
var _r: float = 30.0
var _craters: Array = []              # [{c, poly}]
var _grietas: Array = []              # PackedVector2Array por grieta
var _piedras: Array = []
var _tierra: Array = []
var _chispas: Array = []
var _atras: Node2D = null
var _delante: Node2D = null
var _suelo: Node2D = null


# ------------------------------------------------------------
#  EN EL SUELO
# ------------------------------------------------------------
static func area(padre: Node, f: CombatFormas.Forma, m: int, semilla: int, n_nucleo: float, espera: float) -> MazaAire:
	if padre == null or f == null:
		return null
	var e := MazaAire.new()
	e.modo = m
	e.forma = f
	e.nucleo = n_nucleo
	e._rng.seed = semilla
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	# La ida del Rompepiernas a dos mazas ACABA en su golpe (como el Doble tajo); lo demas empieza en el golpe.
	e._t = (T_BARRE if m == Modo.ROMPE_DOS else 0.0) - espera * e._ritmo
	e.z_as_relative = false
	e.z_index = SueloRoto.Z_SUELO
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._preparar_area()
	return e


# CUANDO LE LLEGA a 'p' el golpe, en segundos desde el golpe (la misma cuenta que el dibujo).
static func retraso(m: int, f: CombatFormas.Forma, p: Vector2) -> float:
	if f == null:
		return 0.0
	match m:
		Modo.DEMOLEDOR, Modo.DEMOLEDOR_DOS, Modo.APLASTA:
			var u: float = clampf(p.distance_to(f.centro) / maxf(f.radio, 1.0), 0.0, 1.0)
			return t_salir(m) * (1.0 - sqrt(1.0 - u))
		Modo.ROMPE:
			var o: Vector2 = SueloRoto.origen_de(f)
			var mitad: float = deg_to_rad(f.apertura * 0.5)
			if mitad <= 0.001 or p.distance_squared_to(o) < 0.01:
				return 0.0
			var fr: float = clampf(angle_difference(f.dir.angle() - mitad, (p - o).angle()) / (2.0 * mitad), 0.0, 1.0)
			return T_BARRE * sqrt(fr)
	return 0.0


static func t_salir(m: int) -> float:
	match m:
		Modo.DEMOLEDOR, Modo.DEMOLEDOR_DOS: return T_ONDA_DEM
		Modo.APLASTA: return T_ONDA_APLASTA
		Modo.ROMPE: return T_BARRE
		Modo.ROMPE_DOS: return 2.0 * T_ENTRE
	return 0.2


func _preparar_area() -> void:
	_centro = forma.centro if forma.tipo == CombatFormas.Tipo.CIRCULO else forma.origen
	_r = maxf(forma.radio, 8.0)
	_dir = forma.dir.normalized() if forma.dir.length_squared() > 0.0001 else Vector2.RIGHT
	_lat = Vector2(-_dir.y, _dir.x).normalized()
	match modo:
		Modo.DEMOLEDOR, Modo.DEMOLEDOR_DOS, Modo.APLASTA:
			var dos: bool = modo == Modo.DEMOLEDOR_DOS
			var r_cr: float = maxf(nucleo * 0.75, 5.0) if modo != Modo.APLASTA else 5.5
			var puntos: Array = [_centro] if not dos else [_centro + _lat * r_cr * 0.9, _centro - _lat * r_cr * 0.9]
			for pc in puntos:
				_craters.append({"c": pc, "poly": _mancha_en(pc, r_cr * (0.85 if dos else 1.0), 12)})
			# Las grietas: cortas, del crater hacia fuera (una maza no parte el suelo entero como el martillo).
			var n_g: int = 6 if modo == Modo.APLASTA else (12 if dos else 9)
			var largo_g: float = _r * (0.45 if modo == Modo.APLASTA else 0.6)
			for i in n_g:
				var ang: float = TAU * (float(i) + _rng.randf_range(-0.35, 0.35)) / float(n_g)
				var pc2: Vector2 = puntos[i % puntos.size()]
				_grietas.append(_quebrada(pc2, ang, r_cr * 0.8, r_cr + (largo_g - r_cr) * _rng.randf_range(0.5, 1.0)))
			for j in (10 if dos else 7):
				_piedras.append({"o": puntos[j % puntos.size()], "ang": _rng.randf_range(0.0, TAU),
					"v": _rng.randf_range(18.0, 45.0), "vz": _rng.randf_range(55.0, 100.0), "tam": _rng.randf_range(1.3, 2.4),
					"t0": _rng.randf_range(0.0, 0.04)})
		Modo.ROMPE, Modo.ROMPE_DOS:
			for i in 14:
				var u: float = (float(i) + _rng.randf_range(0.0, 1.0)) / 14.0
				_tierra.append({"u": u, "r": _r * _rng.randf_range(0.5, 0.95), "k": i % 2,
					"v": Vector2(_rng.randf_range(12.0, 30.0), _rng.randf_range(35.0, 70.0)), "tam": _rng.randf_range(1.2, 2.4)})
		Modo.ALIENTO_DOS:
			for i in 12:
				var a: float = -PI * 0.5 + _rng.randf_range(-1.4, 1.4)
				_chispas.append({"a": a, "v": _rng.randf_range(70.0, 140.0), "t0": _rng.randf_range(0.0, 0.05)})
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
# 'desde' = el pecho de quien pega (o de quien lo lanza, en las de apoyo); 'caja' = el que lo recibe.
static func golpe(padre: Node, m: int, desde: Vector2, caja: Rect2, fallo: bool, crit: bool, n: int,
		semilla: int, espera: float, ritmo: float) -> MazaAire:
	if padre == null:
		return null
	var e := MazaAire.new()
	e.modo = m
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	e._t = -maxf(espera, 0.0)
	e._caja = caja
	e._fallo = fallo
	e._crit = crit
	e._n = n
	e._desde = desde
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
	# EL LADO con la perspectiva de la camara (como la pincelada de la espada): la perpendicular al golpe en el suelo
	# y un pelo de fondo, para que de E u O no se quede en una raya.
	_lat = Vector2(-_dir.y, _dir.x * K) + Vector2(_dir.x, _dir.y * K) * 0.35
	_lat = _lat.normalized() if _lat.length_squared() > 0.001 else Vector2.RIGHT
	# De que lado entra: al azar el primero y DEL OTRO en cada golpe (dos mazas: una y otra).
	_lado = 1.0 if _rng.randf() < 0.5 else -1.0
	if _n % 2 == 1:
		_lado = -_lado
	var cara: Vector2 = _c - _dir * ancho * 0.25    # la cara que mira a quien pega
	match modo:
		Modo.CULATAZO:
			_imp = cara + Vector2(0.0, -alto * 0.32)
			_swing = [_imp - _dir * 16.0 + _lat * _lado * 3.0, _imp - _dir * 8.0 + _lat * _lado * 1.5, _imp]
		Modo.ROMPE_C:
			_imp = Vector2(cara.x, _caja.end.y - alto * 0.22) if _caja.has_area() else cara + Vector2(0.0, 6.0)
			# Viene BAJA y de lado, casi a ras de suelo.
			_swing = [_imp + _lat * _lado * 18.0 - _dir * 4.0, _imp + _lat * _lado * 9.0 - _dir * 6.0 + Vector2(0.0, 2.0), _imp]
		Modo.PORRAZO:
			_imp = cara + Vector2(0.0, -alto * _rng.randf_range(0.05, 0.2))
			# De lado y de arriba, cada golpe con su inclinacion.
			var sube: float = _rng.randf_range(10.0, 20.0)
			_swing = [_imp + _lat * _lado * 15.0 + Vector2(0.0, -sube) - _dir * 5.0,
				_imp + _lat * _lado * 12.0 + Vector2(0.0, -sube * 0.2), _imp]
		_:
			_imp = _c
	if _fallo and not _swing.is_empty():
		# Al fallar, la cabeza sigue de largo por delante del cuerpo.
		var pasa: Vector2 = ((_swing[2] as Vector2) - (_swing[1] as Vector2)).normalized() * (ancho * 0.6 + 6.0)
		_swing[2] = (_swing[2] as Vector2) + pasa
	# LA MANCHA ROMA (la del porrazo de la fila): muchas puas y el valle ALTO, o se lee como un shuriken.
	var n_p: int = 13
	var g: float = _rng.randf_range(0.0, TAU)
	for i in n_p:
		var ang: float = g + TAU * float(i) / float(n_p)
		var largo: float = 0.8 + 0.2 * sin(g * 1.7 + float(i) * 2.9)
		_mancha.append(Vector2(cos(ang), sin(ang)) * largo)
		var med: float = ang + PI / float(n_p)
		_mancha.append(Vector2(cos(med), sin(med)) * largo * 0.7)
	# Las esquirlas: salen por detras (hacia donde empuja el golpe) y hacia arriba, y caen.
	for i in 5:
		var sal: Vector2 = (_dir + _lat * _rng.randf_range(-0.9, 0.9)).normalized()
		_esquirlas.append({"v": sal * _rng.randf_range(40.0, 90.0) + Vector2(0.0, -_rng.randf_range(30.0, 80.0)),
			"tam": _rng.randf_range(1.2, 2.3)})
	if modo == Modo.ALIENTO_C:
		for i in 6:
			_motas.append({"x": _rng.randf_range(-7.0, 7.0), "t0": _rng.randf_range(0.0, 0.16),
				"v": _rng.randf_range(60.0, 100.0)})
	# Lo del SUELO de un cuerpo (polvo, anillos a los pies) va por debajo de los cuerpos.
	if modo in [Modo.ROMPE_C, Modo.MURO_C, Modo.ALIENTO_C]:
		_suelo = Node2D.new()
		_suelo.z_as_relative = false
		_suelo.z_index = SueloRoto.Z_SUELO
		add_child(_suelo)
		_suelo.draw.connect(_dibujar_suelo_cuerpo)


func duracion() -> float:
	match modo:
		Modo.DEMOLEDOR, Modo.DEMOLEDOR_DOS: return T_ONDA_DEM + 0.9
		Modo.APLASTA: return T_ONDA_APLASTA + 0.8
		Modo.ROMPE: return T_BARRE + T_SUELO + T_SUELO_APAGAR + 0.1
		Modo.ROMPE_DOS: return T_ENTRE + T_BARRE + T_SUELO + T_SUELO_APAGAR + 0.1
		Modo.ALIENTO, Modo.ALIENTO_DOS: return 0.7
		Modo.MURO: return 0.85
		Modo.ALIENTO_C: return 0.55
		Modo.MURO_C: return 0.7
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


func _mancha_en(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		out.append(c + Vector2(cos(a), sin(a)) * r * _rng.randf_range(0.72, 1.12))
	return out


func _quebrada(o: Vector2, ang: float, r0: float, r1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var dir: float = ang
	var p: Vector2 = o + Vector2(cos(ang), sin(ang)) * r0
	pts.append(p)
	while p.distance_to(o) < r1:
		dir = lerpf(dir, ang, 0.35) + _rng.randf_range(-0.55, 0.55)
		p += Vector2(cos(dir), sin(dir)) * 3.0
		pts.append(p)
	return pts


# Una grieta que se AFILA hasta 'hasta' px del centro 'o' (lo que ya ha pasado el frente). Relleno: el labio claro
# debajo y la raja oscura encima, en triangulos (no rayas).
func _grieta(ci: CanvasItem, pts: PackedVector2Array, o: Vector2, hasta: float, alfa: float) -> void:
	var n: int = pts.size()
	for i in n - 1:
		if pts[i + 1].distance_to(o) > hasta:
			break
		var w: float = lerpf(2.2, 0.4, float(i) / float(maxi(1, n - 2)))
		var d: Vector2 = (pts[i + 1] - pts[i]).normalized().orthogonal()
		var cl := Color(LABIO, 0.35 * alfa)
		var co := Color(OSCURO, 0.95 * alfa)
		var sh := Vector2(0.6, 1.0)
		ci.draw_primitive(PackedVector2Array([pts[i] + sh + d * w * 0.5, pts[i + 1] + sh + d * w * 0.4, pts[i + 1] + sh - d * w * 0.4]),
			PackedColorArray([cl, cl, cl]), PackedVector2Array())
		ci.draw_primitive(PackedVector2Array([pts[i] + d * w * 0.5, pts[i + 1] + d * w * 0.4, pts[i + 1] - d * w * 0.4]),
			PackedColorArray([co, co, co]), PackedVector2Array())
		ci.draw_primitive(PackedVector2Array([pts[i] + d * w * 0.5, pts[i + 1] - d * w * 0.4, pts[i] - d * w * 0.5]),
			PackedColorArray([co, co, co]), PackedVector2Array())


# UN ARCO RELLENO de anillo (de 'a0' a 'a1'), el filo por fuera y a nada hacia dentro. Con a1-a0 = TAU, entero.
static func _arco(ci: CanvasItem, c: Vector2, r: float, grueso: float, a0: float, a1: float, filo: Color, dentro: Color) -> void:
	if filo.a <= 0.005 or r <= 0.5:
		return
	var n: int = clampi(int(r * 0.6 * absf(a1 - a0) / TAU), 10, 72)
	var tr := Color(dentro, 0.0)
	for i in n:
		var b0: float = lerpf(a0, a1, float(i) / float(n))
		var b1: float = lerpf(a0, a1, float(i + 1) / float(n))
		var u0 := Vector2(cos(b0), sin(b0))
		var u1 := Vector2(cos(b1), sin(b1))
		var m0: Vector2 = c + u0 * maxf(r - grueso * 0.3, 0.0)
		var m1: Vector2 = c + u1 * maxf(r - grueso * 0.3, 0.0)
		var d0: Vector2 = c + u0 * maxf(r - grueso, 0.0)
		var d1: Vector2 = c + u1 * maxf(r - grueso, 0.0)
		ci.draw_primitive(PackedVector2Array([c + u0 * r, c + u1 * r, m1]), PackedColorArray([filo, filo, dentro]), PackedVector2Array())
		ci.draw_primitive(PackedVector2Array([c + u0 * r, m1, m0]), PackedColorArray([filo, dentro, dentro]), PackedVector2Array())
		ci.draw_primitive(PackedVector2Array([m0, m1, d1]), PackedColorArray([dentro, dentro, tr]), PackedVector2Array())
		ci.draw_primitive(PackedVector2Array([m0, d1, d0]), PackedColorArray([dentro, tr, tr]), PackedVector2Array())


# Un punto de la curva de la cabeza (Bezier cuadratica).
func _en_swing(s: float) -> Vector2:
	var a: Vector2 = _swing[0]
	var b: Vector2 = _swing[1]
	var c: Vector2 = _swing[2]
	return a.lerp(b, s).lerp(b.lerp(c, s), s)


# LA ESTELA DE LA CABEZA: una banda rellena por la curva, GORDA en la cabeza y afilada y transparente hacia la
# cola; blanca en el eje y hierro hacia los bordes. Una maza es una bola: mas gruesa que la de un filo.
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
		var c0 := Color(BLANCO, alfa * u0)
		var c1 := Color(BLANCO, alfa * u1)
		var h0 := Color(HIERRO, alfa * 0.55 * u0)
		var h1 := Color(HIERRO, alfa * 0.55 * u1)
		var tr := Color(HIERRO, 0.0)
		for lado in [1.0, -1.0]:
			ci.draw_primitive(PackedVector2Array([p0, p1, p1 + d * w1 * 0.45 * lado]), PackedColorArray([c0, c1, h1]), PackedVector2Array())
			ci.draw_primitive(PackedVector2Array([p0, p1 + d * w1 * 0.45 * lado, p0 + d * w0 * 0.45 * lado]),
				PackedColorArray([c0, h1, h0]), PackedVector2Array())
			ci.draw_primitive(PackedVector2Array([p0 + d * w0 * 0.45 * lado, p1 + d * w1 * 0.45 * lado, p1 + d * w1 * lado]),
				PackedColorArray([h0, h1, tr]), PackedVector2Array())
			ci.draw_primitive(PackedVector2Array([p0 + d * w0 * 0.45 * lado, p1 + d * w1 * lado, p0 + d * w0 * lado]),
				PackedColorArray([h0, tr, tr]), PackedVector2Array())
	BarridoAire.brillo(ci, _en_swing(s_cabeza), grueso * 0.55, Color(BLANCO, alfa * 0.6))


# ------------------------------------------------------------
#  DIBUJO SOBRE UN CUERPO
# ------------------------------------------------------------
func _draw() -> void:
	if forma != null:
		_dibujar_suelo_area()
		return
	match modo:
		Modo.PORRAZO, Modo.CULATAZO, Modo.ROMPE_C:
			_dibujar_porrazo()
		Modo.ALIENTO_C:
			for m in _motas:
				var tp: float = _t - float(m["t0"])
				if tp < 0.0 or tp > 0.3:
					continue
				var p: Vector2 = _pies + Vector2(float(m["x"]), -float(m["v"]) * tp)
				BarridoAire.cometa(self, p + Vector2(0.0, 10.0), p, 3.0, Color(BRIO_CLARO, 0.95 * (1.0 - tp / 0.3)))
			var tk: float = _t - 0.18
			if tk >= 0.0:
				var pulso2: float = exp(-tk / 0.06)
				BarridoAire.brillo(self, _c, 12.0 + 6.0 * _sale(tk, 0.25), Color(BRIO, 0.45 * (1.0 - _sale(tk, 0.35))))
				BarridoAire.destello(self, _c + Vector2(0.0, -3.0), 6.0 + 7.0 * pulso2, Color(BRIO_CLARO, pulso2), 0.3)


func _dibujar_porrazo() -> void:
	var t_sw: float = T_JAB if modo == Modo.CULATAZO else T_SWING
	var grueso: float = 5.0 if modo == Modo.CULATAZO else 8.0
	# 1) LA CABEZA QUE LLEGA: acaba en el golpe y se apaga enseguida.
	var s: float = clampf((_t + t_sw) / t_sw, 0.0, 1.0)
	if s > 0.0:
		var apaga: float = clampf(_t / 0.1, 0.0, 1.0)
		_estela(self, maxf(0.0, s - 0.7), s * s * (3.0 - 2.0 * s), grueso, (0.45 if _fallo else 0.9) * (1.0 - apaga))
	if _t < 0.0 or _fallo:
		return
	var escala: float = {Modo.CULATAZO: 0.6, Modo.ROMPE_C: 0.85}.get(modo, 1.0) * (1.3 if _crit else 1.0)
	# 2) EL DESTELLO del impacto: duro y corto en el culatazo.
	var pulso: float = exp(-_t / (0.035 if modo == Modo.CULATAZO else 0.05))
	BarridoAire.destello(self, _imp, (7.0 + 8.0 * pulso) * escala, Color(BLANCO, pulso), _dir.angle() + 0.4 * _lado)
	# 3) LA MANCHA ROMA: se abre de golpe y se apaga (el fogonazo, no una chapa).
	var km: float = _sale(_t, 0.05)
	var am: float = 1.0 - clampf(_t / 0.2, 0.0, 1.0)
	if am > 0.0:
		var r_m: float = 7.0 * escala * (0.6 + 0.4 * km)
		var poly := PackedVector2Array()
		for q in _mancha:
			poly.append(_imp + q * r_m)
		draw_colored_polygon(poly, Color(HIERRO.lightened(0.3), 0.5 * am))
		BarridoAire.brillo(self, _imp, r_m * 0.5, Color(BLANCO, 0.85 * am))
	# 4) LA ONDA: sale POR DETRAS (hacia donde empuja el golpe), media luna rellena que se abre y se apaga.
	var t_o: float = 0.2 if modo != Modo.CULATAZO else 0.12
	for k in (2 if modo == Modo.CULATAZO else 1):
		var tk: float = _t - 0.05 * float(k)
		if tk < 0.0 or tk > t_o:
			continue
		var ko: float = _sale(tk, t_o)
		var ang: float = _dir.angle()
		_arco(self, _imp, (4.0 + 13.0 * ko) * escala, lerpf(6.0, 3.0, ko) * escala, ang - 1.5, ang + 1.5,
			Color(BLANCO, 0.8 * (1.0 - ko)), Color(HIERRO, 0.35 * (1.0 - ko)))
	# 5) LAS ESQUIRLAS.
	if _t < 0.4:
		for q in _esquirlas:
			var v: Vector2 = q["v"]
			var p: Vector2 = _imp + v * _t + Vector2(0.0, 0.5 * GRAVEDAD * _t * _t)
			var vel: Vector2 = v + Vector2(0.0, GRAVEDAD * _t)
			BarridoAire.cometa(self, p - vel.normalized() * 4.0, p, float(q["tam"]),
				Color(LABIO.lerp(BLANCO, 0.4), 0.9 * (1.0 - _t / 0.4)))


# Lo de los pies de un cuerpo.
func _dibujar_suelo_cuerpo() -> void:
	if _t < 0.0:
		return
	match modo:
		Modo.ROMPE_C:
			if _fallo:
				return
			# El cuerpo cede: polvo a los dos lados de los pies.
			var k: float = clampf(_t / 0.45, 0.0, 1.0)
			for s in [-1.0, 1.0]:
				for j in 3:
					var q: Vector2 = _pies + _lat * s * (4.0 + 14.0 * k * (0.6 + 0.3 * float(j))) + Vector2(0.0, -2.0 - 3.0 * float(j) * k)
					BarridoAire.brillo(_suelo, q, 5.0 + 6.0 * k, Color(POLVO, 0.6 * (1.0 - k)))
		Modo.ALIENTO_C:
			var k3: float = _sale(_t, 0.3)
			_arco(_suelo, _pies, 5.0 + 11.0 * k3, 4.0, 0.0, TAU, Color(BRIO_CLARO, 0.85 * (1.0 - k3)), Color(BRIO, 0.35 * (1.0 - k3)))
		Modo.MURO_C:
			# Su marca azul, que late, y LA ESTELA POR EL SUELO hacia ti: es el paso con el que se arrima.
			# La marca VA CON EL: da el mismo paso que el cuerpo (la cuenta de CombatTactico.pedir_juntar, al T_PASO).
			var hacia: Vector2 = _desde + Vector2(0.0, ALTO_TORSO)
			var largo: float = clampf(_pies.distance_to(hacia) - MURO_SEPARA, 0.0, MURO_PASO)
			var ya: Vector2 = _pies.move_toward(hacia, largo * _sale(_t, MURO_T_PASO))
			var km: float = _sale(_t, 0.12)
			var va: float = clampf((_t - 0.4) / 0.3, 0.0, 1.0)
			var alfa: float = km * (1.0 - va)
			_arco(_suelo, ya, 10.0 + 2.0 * sin(_t * 18.0), 5.0, 0.0, TAU, Color(BLANCO, 0.85 * alfa), Color(GUARDIA, 0.45 * alfa))
			# Y el rastro del paso por el suelo, de donde estaba a donde llega.
			var uc: float = clampf(_t / (MURO_T_PASO + 0.08), 0.0, 1.0)
			if uc < 1.0 and largo > 2.0:
				BarridoAire.cometa(_suelo, _pies.lerp(ya, maxf(uc - 0.5, 0.0) * 2.0), ya, 5.0,
					Color(GUARDIA.lerp(BLANCO, 0.4), 0.9 * km * (1.0 - uc)))


# ------------------------------------------------------------
#  DIBUJO EN EL SUELO (la huella)
# ------------------------------------------------------------
func _dibujar_suelo_area() -> void:
	if _t < 0.0:
		return
	match modo:
		Modo.DEMOLEDOR, Modo.DEMOLEDOR_DOS, Modo.APLASTA:
			var ts: float = t_salir(modo)
			var front: float = _sale(_t, ts) * _r
			var alfa: float = 1.0 - clampf((_t - ts - 0.3) / 0.45, 0.0, 1.0)
			if alfa <= 0.0:
				return
			# El suelo hundido alrededor del golpe y el crater.
			for cr in _craters:
				BarridoAire.brillo(self, cr["c"], nucleo * 1.4 + 6.0, Color(OSCURO, 0.25 * alfa))
				draw_colored_polygon(cr["poly"], Color(OSCURO, 0.9 * alfa))
			for g in _grietas:
				_grieta(self, g, _centro, front, alfa)
			# LA RESONANCIA: anillos escalonados que salen del golpe. El primero ES el frente del daño.
			var n_an: int = {Modo.DEMOLEDOR: 3, Modo.DEMOLEDOR_DOS: 4}.get(modo, 1)
			var gordo: float = 1.3 if modo == Modo.DEMOLEDOR_DOS else 1.0
			for k in n_an:
				var tk: float = _t - 0.07 * float(k)
				var dur: float = ts * (1.0 + 0.35 * float(k))
				if tk < 0.0 or tk > dur + 0.15:
					continue
				var ka: float = _sale(tk, dur)
				var va: float = clampf((tk - dur) / 0.15, 0.0, 1.0)
				var r_k: float = _r * ka * (1.0 - 0.1 * float(k))
				var a_k: float = (1.0 - 0.25 * float(k)) * (1.0 - va) * (1.0 - 0.5 * ka)
				_arco(self, _centro, r_k, lerpf(12.0, 6.0, ka) * gordo, 0.0, TAU, Color(BLANCO, 0.85 * a_k), Color(POLVO, 0.45 * a_k))
			# El polvo que levanta el golpe.
			if _t < 0.45:
				var kp: float = _t / 0.45
				for cr2 in _craters:
					BarridoAire.brillo(self, cr2["c"], 8.0 + 12.0 * kp, Color(POLVO, 0.5 * (1.0 - kp)))
		Modo.ROMPE, Modo.ROMPE_DOS:
			# El SURCO que deja la cabeza al pasar a ras de suelo.
			var mitad: float = deg_to_rad(forma.apertura * 0.5)
			var izq: float = _dir.angle() - mitad
			var der: float = _dir.angle() + mitad
			for k in (2 if modo == Modo.ROMPE_DOS else 1):
				var t0: float = float(k) * T_ENTRE
				var tk: float = _t - t0
				if tk < 0.0:
					continue
				var desde: float = izq if k == 0 else der
				var hasta: float = lerpf(desde, der if k == 0 else izq, pow(clampf(tk / T_BARRE, 0.0, 1.0), 2.0))
				var alfa_s: float = 1.0 - clampf((tk - T_BARRE - T_SUELO) / T_SUELO_APAGAR, 0.0, 1.0)
				_surco(minf(desde, hasta), maxf(desde, hasta), _r * (0.7 if k == 0 else 0.6), 2.4, alfa_s)
		Modo.ALIENTO, Modo.ALIENTO_DOS:
			for i in 2:
				var tk2: float = _t - 0.09 * float(i)
				if tk2 < 0.0 or tk2 > T_ONDA_APOYO:
					continue
				var k2: float = _sale(tk2, T_ONDA_APOYO)
				# Filo claro que aguanta hasta el borde; el naranja, fino (con mucho, sobre el suelo oscuro sale marron).
				var a2: float = 1.0 - k2 * k2
				_arco(self, _centro, _r * k2, lerpf(22.0, 10.0, k2), 0.0, TAU, Color(BRIO_CLARO, 0.95 * a2),
					Color(BRIO, 0.28 * a2))
				BarridoAire.brillo(self, _centro, _r * k2 * 0.9, Color(BRIO, 0.08 * (1.0 - k2)))
		Modo.MURO:
			# El golpe a tus pies...
			if _t < 0.4:
				var kp2: float = _t / 0.4
				BarridoAire.brillo(self, _centro, 8.0 + 14.0 * kp2, Color(POLVO, 0.55 * (1.0 - kp2)))
			# ...y el anillo que se CIERRA desde el borde hacia ti (cerrais filas), y se queda un momento.
			var kc: float = _sale(_t, 0.3)
			var va2: float = clampf((_t - 0.5) / 0.3, 0.0, 1.0)
			var r_c: float = lerpf(_r, 22.0, kc)
			_arco_dentro(_centro, r_c, lerpf(10.0, 14.0, kc), Color(BLANCO, 0.9 * (1.0 - va2)), Color(GUARDIA, 0.5 * (1.0 - va2)))


# El anillo del Muro: el filo por DENTRO (va hacia ti) y a nada hacia fuera.
func _arco_dentro(c: Vector2, r: float, grueso: float, filo: Color, fuera: Color) -> void:
	if filo.a <= 0.005:
		return
	var n: int = clampi(int(r * 0.6), 24, 72)
	var tr := Color(fuera, 0.0)
	for i in n:
		var u0 := Vector2(cos(TAU * float(i) / n), sin(TAU * float(i) / n))
		var u1 := Vector2(cos(TAU * float(i + 1) / n), sin(TAU * float(i + 1) / n))
		var m0: Vector2 = c + u0 * (r + grueso * 0.3)
		var m1: Vector2 = c + u1 * (r + grueso * 0.3)
		var e0: Vector2 = c + u0 * (r + grueso)
		var e1: Vector2 = c + u1 * (r + grueso)
		draw_primitive(PackedVector2Array([c + u0 * r, c + u1 * r, m1]), PackedColorArray([filo, filo, fuera]), PackedVector2Array())
		draw_primitive(PackedVector2Array([c + u0 * r, m1, m0]), PackedColorArray([filo, fuera, fuera]), PackedVector2Array())
		draw_primitive(PackedVector2Array([m0, m1, e1]), PackedColorArray([fuera, fuera, tr]), PackedVector2Array())
		draw_primitive(PackedVector2Array([m0, e1, e0]), PackedColorArray([fuera, tr, tr]), PackedVector2Array())


# EL SURCO en el suelo (EspadaAire._marca_suelo): oscuro en el centro con el labio claro por fuera, afilado en
# las puntas.
func _surco(a0: float, a1: float, r: float, ancho: float, alfa: float) -> void:
	if alfa <= 0.0 or absf(a1 - a0) < 0.02:
		return
	var n: int = maxi(6, int(absf(a1 - a0) / 0.07))
	var pts := PackedVector2Array()
	for i in n + 1:
		var a: float = lerpf(a0, a1, float(i) / float(n))
		pts.append(_centro + Vector2(cos(a), sin(a)) * r)
	for i in n:
		var s0: float = float(i) / float(n)
		var s1: float = float(i + 1) / float(n)
		var d: Vector2 = (pts[i + 1] - pts[i]).normalized().orthogonal()
		var w0: float = ancho * pow(sin(PI * s0), 0.6)
		var w1: float = ancho * pow(sin(PI * s1), 0.6)
		var cl := Color(LABIO, 0.45 * alfa)
		var trl := Color(LABIO, 0.0)
		for lado in [1.0, -1.0]:
			var q0: Vector2 = pts[i] + d * w0 * 0.9 * lado
			var q1: Vector2 = pts[i + 1] + d * w1 * 0.9 * lado
			var e0: Vector2 = pts[i] + d * w0 * 2.2 * lado
			var e1: Vector2 = pts[i + 1] + d * w1 * 2.2 * lado
			draw_primitive(PackedVector2Array([q0, q1, e1]), PackedColorArray([cl, cl, trl]), PackedVector2Array())
			draw_primitive(PackedVector2Array([q0, e1, e0]), PackedColorArray([cl, trl, trl]), PackedVector2Array())
		var co := Color(OSCURO, 0.85 * alfa)
		draw_primitive(PackedVector2Array([pts[i] + d * w0 * 0.45, pts[i + 1] + d * w1 * 0.45, pts[i + 1] - d * w1 * 0.45]),
			PackedColorArray([co, co, co]), PackedVector2Array())
		draw_primitive(PackedVector2Array([pts[i] + d * w0 * 0.45, pts[i + 1] - d * w1 * 0.45, pts[i] - d * w0 * 0.45]),
			PackedColorArray([co, co, co]), PackedVector2Array())


# ------------------------------------------------------------
#  LO DEL AIRE de la huella (capas detras y delante de los cuerpos)
# ------------------------------------------------------------
func _dibujar_capa(capa: Node2D) -> void:
	match modo:
		Modo.DEMOLEDOR, Modo.DEMOLEDOR_DOS, Modo.APLASTA:
			if capa != _delante:
				return
			# EL IMPACTO en cada crater (la maza que cae la cuenta el muñeco, como en el martillo).
			for i in _craters.size():
				var pc: Vector2 = _craters[i]["c"]
				if _t >= 0.0:
					var pulso: float = exp(-_t / 0.05)
					BarridoAire.destello(capa, pc + Vector2(0.0, -2.0), (10.0 if modo != Modo.APLASTA else 8.0) + 14.0 * pulso,
						Color(BLANCO, pulso), 0.3 + float(i))
			# Las piedras que saltan del crater.
			for pz in _piedras:
				var tp: float = _t - float(pz["t0"])
				if tp < 0.0:
					continue
				var z: float = float(pz["vz"]) * tp - SueloRoto.GRAVEDAD_PIEDRAS * tp * tp
				if z < 0.0:
					continue
				var a: float = float(pz["ang"])
				var q: Vector2 = (pz["o"] as Vector2) + Vector2(cos(a), sin(a)) * float(pz["v"]) * tp + Vector2(0.0, -z * K)
				var tam: float = float(pz["tam"])
				capa.draw_rect(Rect2(q - Vector2(tam, tam) * 0.5, Vector2(tam, tam)), SueloRoto.PIEDRA)
		Modo.ROMPE, Modo.ROMPE_DOS:
			var mitad: float = deg_to_rad(forma.apertura * 0.5)
			var izq: float = _dir.angle() - mitad
			var der: float = _dir.angle() + mitad
			for k in (2 if modo == Modo.ROMPE_DOS else 1):
				var desde: float = izq if k == 0 else der
				var hasta: float = der if k == 0 else izq
				_barrido(capa, float(k) * T_ENTRE, desde, hasta, _r * (0.92 if k == 0 else 0.82), _r * 0.45)
			_dibujar_tierra(capa, izq, der)
		Modo.ALIENTO, Modo.ALIENTO_DOS:
			if capa != _delante or _t < -0.02:
				return
			# En alto: la maza levantada (o las dos que se entrechocan).
			var en: Vector2 = _centro + Vector2(0.0, -ALTO_CABEZA - 8.0)
			var pulso2: float = exp(-maxf(_t, 0.0) / 0.07)
			BarridoAire.destello(capa, en, (11.0 if modo == Modo.ALIENTO_DOS else 8.0) + 10.0 * pulso2, Color(BRIO_CLARO, pulso2), 0.4)
			BarridoAire.brillo(capa, en, 14.0, Color(BRIO, 0.4 * pulso2))
			for ch in _chispas:
				var tp2: float = _t - float(ch["t0"])
				if tp2 < 0.0 or tp2 > 0.3:
					continue
				var v: Vector2 = Vector2(cos(float(ch["a"])), sin(float(ch["a"]))) * float(ch["v"])
				var p: Vector2 = en + v * tp2 + Vector2(0.0, 0.5 * GRAVEDAD * tp2 * tp2)
				var vel: Vector2 = v + Vector2(0.0, GRAVEDAD * tp2)
				BarridoAire.cometa(capa, p - vel.normalized() * 6.0, p, 1.8, Color(Color(1.0, 0.93, 0.7), 0.95 * (1.0 - tp2 / 0.3)))
		Modo.MURO:
			if capa != _delante or _t < 0.0:
				return
			var pulso3: float = exp(-_t / 0.05)
			BarridoAire.destello(capa, _centro + Vector2(0.0, -3.0), 7.0 + 9.0 * pulso3, Color(BLANCO, pulso3), 0.0)


# UN BARRIDO BAJO de la cabeza de la maza (EspadaAire._barrido): lento al salir y rapidisimo al final, clavado un
# instante y fuera. De hierro y polvo, gordo en la cabeza.
func _barrido(capa: Node2D, t0: float, desde: float, hasta: float, r: float, grueso: float) -> void:
	var tk: float = _t - t0
	if tk < 0.0:
		return
	var s: float = clampf(tk / T_BARRE, 0.0, 1.0)
	var cabeza: float = lerpf(desde, hasta, s * s)
	var tc: float = tk - T_BARRE
	var apaga: float = clampf((tc - T_CLAVADO) / T_APAGA_SECO, 0.0, 1.0)
	if apaga >= 1.0:
		return
	var recoge: float = clampf(tc / T_CLAVADO, 0.0, 1.0) if tc > 0.0 else 0.0
	var sentido: float = signf(hasta - desde)
	var cola: float = cabeza - sentido * minf(COLA * (1.0 - 0.55 * recoge), absf(cabeza - desde))
	var alfa: float = 0.95 * (1.0 - apaga)
	var n: int = maxi(8, int(absf(cabeza - cola) / 0.06))
	var fr: Array = [0.0, 0.12, 0.4, 0.75, 1.0]
	var cols: Array = [BLANCO, HIERRO, HIERRO_OSCURO, POLVO, POLVO]
	var al: Array = [1.0, 0.95, 0.6, 0.3, 0.0]
	for i in n:
		var s0: float = float(i) / float(n)
		var s1: float = float(i + 1) / float(n)
		var a0: float = lerpf(cola, cabeza, s0)
		var a1: float = lerpf(cola, cabeza, s1)
		if not _es_mia(capa, _en_arco((a0 + a1) * 0.5, r, ALTO_BARRIDO)):
			continue
		var g0: float = grueso * (0.15 + 0.85 * pow(s0, 1.2))
		var g1: float = grueso * (0.15 + 0.85 * pow(s1, 1.2))
		var l0: float = alfa * (0.3 + 0.7 * s0)
		var l1: float = alfa * (0.3 + 0.7 * s1)
		for k in fr.size() - 1:
			var p00: Vector2 = _en_arco(a0, r - g0 * float(fr[k]), ALTO_BARRIDO)
			var p10: Vector2 = _en_arco(a1, r - g1 * float(fr[k]), ALTO_BARRIDO)
			var p01: Vector2 = _en_arco(a0, r - g0 * float(fr[k + 1]), ALTO_BARRIDO)
			var p11: Vector2 = _en_arco(a1, r - g1 * float(fr[k + 1]), ALTO_BARRIDO)
			var c00 := Color(cols[k], l0 * float(al[k]))
			var c10 := Color(cols[k], l1 * float(al[k]))
			var c01 := Color(cols[k + 1], l0 * float(al[k + 1]))
			var c11 := Color(cols[k + 1], l1 * float(al[k + 1]))
			capa.draw_primitive(PackedVector2Array([p00, p10, p11]), PackedColorArray([c00, c10, c11]), PackedVector2Array())
			capa.draw_primitive(PackedVector2Array([p00, p11, p01]), PackedColorArray([c00, c11, c01]), PackedVector2Array())
	var p: Vector2 = _en_arco(cabeza, r, ALTO_BARRIDO)
	if _es_mia(capa, p):
		BarridoAire.brillo(capa, p, 6.0, Color(BLANCO, 0.8 * (1.0 - apaga)))
		if tc >= 0.0:
			var pulso: float = exp(-tc / 0.04)
			BarridoAire.destello(capa, p, 6.0 + 12.0 * pulso, Color(BLANCO, (1.0 - apaga) * pulso), _t * 2.0)


func _en_arco(a: float, r: float, alto: float) -> Vector2:
	return _centro + Vector2(cos(a), sin(a)) * r + Vector2(0.0, -alto)


func _es_mia(capa: Node2D, p: Vector2) -> bool:
	return (p.y < _centro.y - ALTO_BARRIDO) == (capa == _atras)


# La tierra que salta al paso del barrido (la del Corte de tendones).
func _dibujar_tierra(capa: Node2D, izq: float, der: float) -> void:
	for m in _tierra:
		var k: int = int(m["k"])
		if k == 1 and modo != Modo.ROMPE_DOS:
			k = 0
		var u: float = float(m["u"])
		var cuando: float = float(k) * T_ENTRE + T_BARRE * sqrt(u)
		var tp: float = _t - cuando
		if tp < 0.0 or tp > 0.45:
			continue
		var ang: float = lerpf(izq, der, u) if k == 0 else lerpf(der, izq, u)
		var v: Vector2 = m["v"]
		var z: float = v.y * tp - SueloRoto.GRAVEDAD_PIEDRAS * tp * tp
		if z < 0.0:
			continue
		var p2: Vector2 = _centro + Vector2(cos(ang), sin(ang)) * (float(m["r"]) + v.x * tp) + Vector2(0.0, -z * K)
		if not _es_mia(capa, p2 + Vector2(0.0, -ALTO_BARRIDO)):
			continue
		var tam: float = float(m["tam"])
		capa.draw_rect(Rect2(p2 - Vector2(tam, tam) * 0.5, Vector2(tam, tam)), TIERRA)
