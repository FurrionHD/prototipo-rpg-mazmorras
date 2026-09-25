# ============================================================
#  espada_aire.gd
#  LOS EFECTOS DE LA ESPADA CORTA en el mapa (25/09/2026). Corta como la daga pero con CUERPO: la media
#  luna es mas grande y mas gruesa, y cada habilidad deja su marca sobre el cuerpo que la recibe. Sale golpe
#  a golpe (CombatFX.dibujo_en_mapa -> CombatTactico._on_dibujo_mapa), en todas las maquinas, como la daga
#  y el estoque: el espejo recibe los mismos golpes, asi que no cuesta red.
#    TAJO          la media luna de siempre (el basico)
#    QUEBRANTADOR  un tajo ANCHO y horizontal que revienta la guardia: una placa de luz delante del cuerpo
#                  que salta en pedazos
#    DOBLE         los dos cortes en diagonal se QUEDAN puestos y forman una cruz; al cerrarse, destella
#    RITMO         Cambio de ritmo: tajo corto y tres marcas del compas; la tercera llega antes y se rompe
#    SENALAR       Señalar el hueco: los dos cortes EN EL MISMO SITIO y una diana que se queda puesta
#    TENDONES      Corte de tendones: tajo BAJO y plano, a las piernas, con polvo a los pies
#  La SANGRE va aparte (SangreMapa, al encajar). Coordenadas de MUNDO; todo sale de una semilla.
#  NADA DE LINEAS (efectos-sin-lineas): filo duro que se difumina, cometas, destellos en estrella.
# ============================================================
extends Node2D
class_name EspadaAire

enum Modo { TAJO, QUEBRANTADOR, DOBLE, RITMO, SENALAR, TENDONES }

const T_TAJO := 0.06          # lo que tarda la media luna de punta a punta (acaba en el golpe)
const T_APAGA := 0.16         # y lo que tarda en irse
const T_QUEDA := 0.22         # lo que se quedan quietos los cortes de la cruz antes de irse
const T_PEDAZOS := 0.4        # lo que vuelan los pedazos de la guardia
const T_DIANA := 0.9          # lo que se queda la diana puesta
const T_COMPAS := 0.07        # entre marca y marca del compas
const T_POLVO := 0.45
const GRAVEDAD := 380.0
const ALTO_TORSO := 14.0

const BLANCO := BarridoAire.BLANCO
const ACERO := Color(0.80, 0.84, 0.90)
const GUARDIA := Color(0.72, 0.84, 1.0)
const DIANA := Color(1.0, 0.36, 0.26)
const DIANA_CLARA := Color(1.0, 0.82, 0.55)
const POLVO := Color(0.55, 0.51, 0.45)
const Z_ENCIMA := Game.Z_PERSONAJES + 80

var modo: int = Modo.TAJO
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _suelo: Node2D = null
var _desde: Vector2 = Vector2.ZERO
var _caja: Rect2 = Rect2()
var _fallo: bool = false
var _crit: bool = false
var _n: int = 0
var _c: Vector2 = Vector2.ZERO      # donde cae
var _o: Vector2 = Vector2.ZERO      # el centro del arco de la media luna
var _r: float = 16.0
var _a_ini: float = 0.0
var _a_fin: float = 1.0
var _grueso: float = 9.0
var _dir: Vector2 = Vector2.RIGHT
var _pies: Vector2 = Vector2.ZERO
var _pedazos: Array = []
var _marcas: Array = []


# UN GOLPE sobre un cuerpo, como DagaAire.golpe. 'n' = el numero de golpe de la accion.
static func golpe(padre: Node, m: int, desde: Vector2, caja: Rect2, fallo: bool, crit: bool, n: int,
		semilla: int, espera: float, ritmo: float) -> EspadaAire:
	if padre == null:
		return null
	var e := EspadaAire.new()
	e.modo = m
	e._rng.seed = semilla
	e._ritmo = maxf(ritmo, 0.05)
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS   # la pelea tactica pausa el arbol
	padre.add_child(e)
	e._desde = desde
	e._caja = caja
	e._fallo = fallo
	e._crit = crit
	e._n = n
	e._t = -maxf(espera, 0.0)
	e._preparar()
	return e


func duracion() -> float:
	match modo:
		Modo.QUEBRANTADOR: return T_PEDAZOS + 0.1
		Modo.DOBLE: return T_QUEDA + T_APAGA + 0.1
		Modo.SENALAR: return (T_DIANA if _n == 1 else T_APAGA) + 0.15
		Modo.TENDONES: return T_POLVO + 0.1
	return T_APAGA + 0.1


func _process(delta: float) -> void:
	_t += delta * _ritmo
	if _t >= duracion():
		queue_free()
		return
	queue_redraw()
	if _suelo != null:
		_suelo.queue_redraw()


# ------------------------------------------------------------
#  PREPARAR
# ------------------------------------------------------------
func _preparar() -> void:
	_c = _caja.get_center() if _caja.has_area() else _desde
	var alto: float = _caja.size.y if _caja.has_area() else 24.0
	_pies = Vector2(_c.x, _caja.end.y) if _caja.has_area() else _c + Vector2(0.0, ALTO_TORSO)
	_dir = (_c - _desde).normalized() if _c.distance_squared_to(_desde) > 0.01 else Vector2.RIGHT
	_r = clampf(alto * 0.8, 13.0, 24.0)
	# El eje del tajo (el angulo de la cuerda) y lo que abre el arco, por habilidad.
	var eje: float
	var abre: float = 55.0
	match modo:
		Modo.QUEBRANTADOR:
			eje = _rng.randf_range(-0.12, 0.12)       # horizontal y ancho
			_r *= 1.25
			abre = 68.0
		Modo.DOBLE:
			eje = (-0.8 if _n % 2 == 0 else 0.8) + _rng.randf_range(-0.08, 0.08)   # la cruz
		Modo.RITMO:
			eje = float([-0.5, 0.5, 1.2][_n % 3]) + _rng.randf_range(-0.2, 0.2)
			_r *= 0.8
			abre = 48.0
		Modo.SENALAR:
			# EL MISMO SITIO en los dos cortes: el angulo sale de donde esta el cuerpo, no de la semilla.
			eje = fposmod(_caja.position.x * 0.37 + _caja.position.y * 0.61, 1.6) - 0.8
		Modo.TENDONES:
			eje = _rng.randf_range(-0.1, 0.1)         # plano, a ras de las piernas
			_c = Vector2(_c.x, (_caja.end.y - alto * 0.14) if _caja.has_area() else _c.y + 8.0)
			_r *= 1.05
			abre = 62.0
		_:
			var angs: Array = [-0.7, 0.7, 1.4, -0.35, 0.35]
			eje = float(angs[(_n + _rng.randi_range(0, 4)) % angs.size()]) + _rng.randf_range(-0.2, 0.2)
	if _fallo:
		var lado: float = 1.0 if _rng.randf() < 0.5 else -1.0
		_c += Vector2(lado * (_caja.size.x * 0.7 + 5.0), 0.0)
	var medio: float = eje + PI * 0.5
	_o = _c - Vector2(cos(medio), sin(medio)) * _r
	var sentido: float = 1.0 if _rng.randf() < 0.5 else -1.0
	_a_ini = medio - sentido * deg_to_rad(abre)
	_a_fin = medio + sentido * deg_to_rad(abre)
	_grueso = _r * (0.45 if modo == Modo.TENDONES else 0.62)
	if modo == Modo.QUEBRANTADOR and not _fallo:
		# Los PEDAZOS de la guardia: salen de la placa hacia atras y a los lados, y caen.
		var placa: Vector2 = _placa()
		var lado_p: Vector2 = _dir.orthogonal()
		for i in 8:
			var u: float = (float(i) / 7.0) * 2.0 - 1.0
			_pedazos.append({"p": placa + lado_p * u * _r * 0.9,
				"v": (_dir * _rng.randf_range(40.0, 95.0) + lado_p * u * _rng.randf_range(30.0, 70.0)
					+ Vector2(0.0, -_rng.randf_range(30.0, 80.0))),
				"tam": _rng.randf_range(2.2, 4.0), "giro": _rng.randf() * TAU, "gira": _rng.randf_range(-14.0, 14.0)})
	if modo == Modo.RITMO:
		# Las tres marcas del compas, a un lado y por encima del cuerpo, en fila.
		var lado_m: Vector2 = _dir.orthogonal() * (1.0 if _rng.randf() < 0.5 else -1.0)
		for i in 3:
			_marcas.append(_c + Vector2(0.0, -_r * 0.9) + lado_m * (float(i) - 1.0) * 8.0)
	if modo == Modo.TENDONES:
		_suelo = Node2D.new()
		_suelo.z_as_relative = false
		_suelo.z_index = SueloRoto.Z_SUELO
		add_child(_suelo)
		_suelo.draw.connect(_dibujar_polvo)


# Donde va la placa de la guardia: delante del cuerpo, del lado del que pega.
func _placa() -> Vector2:
	var h: float = (_caja.size.x * 0.5) if _caja.has_area() else 8.0
	return _caja.get_center() - _dir * (h + 2.0) if _caja.has_area() else _c - _dir * 8.0


# ------------------------------------------------------------
#  DIBUJAR
# ------------------------------------------------------------
func _draw() -> void:
	var quieto: float = T_QUEDA if modo == Modo.DOBLE else 0.0
	_dibujar_tajo(quieto)
	match modo:
		Modo.QUEBRANTADOR: _dibujar_guardia()
		Modo.DOBLE: _dibujar_cruz()
		Modo.RITMO: _dibujar_compas()
		Modo.SENALAR: _dibujar_diana()


# LA MEDIA LUNA, que crece de punta a punta hasta el golpe y se va desde la cola. 'quieto' = lo que se
# queda entera despues del golpe antes de empezar a irse (la cruz del Doble tajo).
func _dibujar_tajo(quieto: float) -> void:
	if _t < -T_TAJO:
		return
	var p: float = clampf((_t + T_TAJO) / T_TAJO, 0.0, 1.0)
	p = 1.0 - (1.0 - p) * (1.0 - p)
	var cabeza: float = lerpf(_a_ini, _a_fin, p)
	var tv: float = _t - quieto
	var va: float = clampf(tv / T_APAGA, 0.0, 1.0) if tv > 0.0 else 0.0
	var cola: float = lerpf(_a_ini, _a_fin, va * 0.85)
	var alfa: float = (0.4 if _fallo else 1.0) * (1.0 - va)
	if alfa <= 0.0:
		return
	# UN ECO detras, un poco mas pequeño: el peso de la hoja.
	var o_e: Vector2 = _c - (_c - _o) * 0.86 - _dir * 3.0
	_media_luna(o_e, _r * 0.86, cola, lerpf(_a_ini, cabeza, 0.85), _grueso * 0.8, alfa * 0.3)
	_media_luna(_o, _r, cola, cabeza, _grueso, alfa)
	if not _fallo:
		var pulso: float = exp(-absf(_t) / 0.04)
		var rd: float = (11.0 if _crit else 6.0) * (0.3 + 0.9 * pulso)
		BarridoAire.destello(self, _c, rd, Color(BLANCO, (1.0 - va) * (0.35 + 0.65 * pulso)), 0.3 + float(_n))


# Copia de DagaAire._media_luna: el FILO de fuera blanco y duro, que se difumina hacia dentro por el acero.
func _media_luna(o: Vector2, r: float, a_cola: float, a_cab: float, grueso: float, alfa: float) -> void:
	if alfa <= 0.0 or absf(a_cab - a_cola) < 0.02:
		return
	var n: int = 14
	var fr: Array = [0.0, 0.15, 0.55, 1.0]
	var cols: Array = [BLANCO, BLANCO, ACERO, ACERO]
	var al: Array = [1.0, 0.9, 0.45, 0.0]
	for i in n:
		var s0: float = float(i) / float(n)
		var s1: float = float(i + 1) / float(n)
		var a0: float = lerpf(a_cola, a_cab, s0)
		var a1: float = lerpf(a_cola, a_cab, s1)
		var w0: float = grueso * pow(sin(PI * s0), 0.7)
		var w1: float = grueso * pow(sin(PI * s1), 0.7)
		var l0: float = alfa * (0.35 + 0.65 * s0)
		var l1: float = alfa * (0.35 + 0.65 * s1)
		var u0 := Vector2(cos(a0), sin(a0))
		var u1 := Vector2(cos(a1), sin(a1))
		for k in fr.size() - 1:
			var p00: Vector2 = o + u0 * (r - w0 * float(fr[k]))
			var p10: Vector2 = o + u1 * (r - w1 * float(fr[k]))
			var p01: Vector2 = o + u0 * (r - w0 * float(fr[k + 1]))
			var p11: Vector2 = o + u1 * (r - w1 * float(fr[k + 1]))
			var c00 := Color(cols[k], l0 * float(al[k]))
			var c10 := Color(cols[k], l1 * float(al[k]))
			var c01 := Color(cols[k + 1], l0 * float(al[k + 1]))
			var c11 := Color(cols[k + 1], l1 * float(al[k + 1]))
			draw_primitive(PackedVector2Array([p00, p10, p11]), PackedColorArray([c00, c10, c11]), PackedVector2Array())
			draw_primitive(PackedVector2Array([p00, p11, p01]), PackedColorArray([c00, c11, c01]), PackedVector2Array())


# LA GUARDIA QUE SE ROMPE: una placa de luz curva delante del cuerpo que aparece justo antes del golpe y,
# al llegar el tajo, salta en pedazos (cuñas de luz que giran y caen).
func _dibujar_guardia() -> void:
	if _fallo:
		return
	var placa: Vector2 = _placa()
	if _t < 0.0 and _t >= -T_TAJO * 1.5:
		var k: float = 1.0 + _t / (T_TAJO * 1.5)
		# La placa: una media luna de luz azulada de cara al que pega.
		var ang: float = (-_dir).angle()
		var o: Vector2 = placa + _dir * _r * 0.9
		var cuerda: float = deg_to_rad(42.0)
		_media_luna_color(o, _r * 0.9, ang - cuerda, ang + cuerda, 5.0, 0.75 * k, GUARDIA)
		BarridoAire.brillo(self, placa, _r * 0.8, Color(GUARDIA, 0.25 * k))
		return
	if _t < 0.0:
		return
	# El REVENTON y los pedazos.
	var kf: float = clampf(_t / 0.12, 0.0, 1.0)
	BarridoAire.brillo(self, placa, _r * (0.6 + 0.8 * kf), Color(GUARDIA, 0.5 * (1.0 - kf)))
	for pz in _pedazos:
		var q: Vector2 = (pz["p"] as Vector2) + (pz["v"] as Vector2) * _t + Vector2(0.0, 0.5 * GRAVEDAD * _t * _t)
		var a: float = float(pz["giro"]) + float(pz["gira"]) * _t
		var s: float = float(pz["tam"])
		var alfa: float = clampf(1.0 - _t / T_PEDAZOS, 0.0, 1.0)
		var d := Vector2(cos(a), sin(a))
		var n: Vector2 = d.orthogonal() * s * 0.45
		draw_primitive(PackedVector2Array([q - d * s, q + n, q + d * s * 0.8, q - n]),
			PackedColorArray([Color(GUARDIA, alfa * 0.5), Color(BLANCO, alfa), Color(GUARDIA, alfa * 0.8),
				Color(BLANCO, alfa)]), PackedVector2Array())


# Una media luna de un solo color (la placa de la guardia).
func _media_luna_color(o: Vector2, r: float, a0: float, a1: float, grueso: float, alfa: float, col: Color) -> void:
	var n: int = 10
	for i in n:
		var s0: float = float(i) / float(n)
		var s1: float = float(i + 1) / float(n)
		var u0 := Vector2(cos(lerpf(a0, a1, s0)), sin(lerpf(a0, a1, s0)))
		var u1 := Vector2(cos(lerpf(a0, a1, s1)), sin(lerpf(a0, a1, s1)))
		var w0: float = grueso * pow(sin(PI * s0), 0.6)
		var w1: float = grueso * pow(sin(PI * s1), 0.6)
		var fuera := Color(BLANCO, alfa)
		var dentro := Color(col, 0.0)
		draw_primitive(PackedVector2Array([o + u0 * r, o + u1 * r, o + u1 * (r - w1)]),
			PackedColorArray([fuera, fuera, dentro]), PackedVector2Array())
		draw_primitive(PackedVector2Array([o + u0 * r, o + u1 * (r - w1), o + u0 * (r - w0)]),
			PackedColorArray([fuera, dentro, dentro]), PackedVector2Array())


# LA CRUZ se cierra con el segundo corte: destello grande en el cruce.
func _dibujar_cruz() -> void:
	if _fallo or _n % 2 == 0 or _t < 0.0:
		return
	var k: float = clampf(_t / (T_QUEDA * 0.8), 0.0, 1.0)
	var pulso: float = sin(PI * k)
	BarridoAire.destello(self, _c, (20.0 if _crit else 15.0) * (0.4 + 0.6 * pulso), Color(BLANCO, pulso), PI * 0.25)
	BarridoAire.brillo(self, _c, _r * 1.1, Color(ACERO, 0.3 * pulso))


# EL COMPAS QUE SE ROMPE: dos marcas que llegan a su tiempo y la tercera que llega ANTES (con el golpe) y
# revienta en chispas.
func _dibujar_compas() -> void:
	if _fallo or _marcas.is_empty():
		return
	for i in 3:
		var t0: float = -T_COMPAS * float(2 - i) - (0.0 if i == 2 else T_COMPAS * 0.6)
		var tm: float = _t - t0
		if tm < 0.0:
			continue
		var q: Vector2 = _marcas[i]
		if i < 2:
			var va: float = clampf((tm - 0.12) / 0.12, 0.0, 1.0)
			var s: float = 3.0 * minf(tm / 0.03, 1.0)
			_rombo(q, s, Color(BLANCO, 0.9 * (1.0 - va)))
		else:
			var kr: float = clampf(tm / 0.18, 0.0, 1.0)
			if kr >= 1.0:
				continue
			BarridoAire.destello(self, q, 7.0 * (1.0 - kr * 0.5), Color(BLANCO, 1.0 - kr), 0.4)
			for j in 4:
				var a: float = TAU * float(j) / 4.0 + 0.4
				var d := Vector2(cos(a), sin(a))
				BarridoAire.cometa(self, q + d * 10.0 * kr * 0.4, q + d * (2.0 + 10.0 * kr), 1.8,
					Color(BLANCO, 0.9 * (1.0 - kr)))


func _rombo(c: Vector2, s: float, col: Color) -> void:
	if col.a <= 0.0 or s <= 0.2:
		return
	var tr := Color(col, 0.0)
	draw_primitive(PackedVector2Array([c + Vector2(0, -s * 1.3), c + Vector2(s, 0), c + Vector2(0, s * 1.3)]),
		PackedColorArray([col, tr, col]), PackedVector2Array())
	draw_primitive(PackedVector2Array([c + Vector2(0, -s * 1.3), c + Vector2(-s, 0), c + Vector2(0, s * 1.3)]),
		PackedColorArray([col, tr, col]), PackedVector2Array())


# LA DIANA del segundo corte: un anillo que se cierra sobre el sitio del corte, un punto en medio y cuatro
# cuñas apuntando dentro. Se queda puesta y late, y se va sola.
func _dibujar_diana() -> void:
	if _fallo or _n != 1 or _t < 0.0:
		return
	var cierra: float = clampf(_t / 0.12, 0.0, 1.0)
	cierra = 1.0 - (1.0 - cierra) * (1.0 - cierra)
	var va: float = clampf((_t - (T_DIANA - 0.25)) / 0.25, 0.0, 1.0)
	var late: float = 0.85 + 0.15 * sin(_t * 14.0)
	var alfa: float = (1.0 - va) * minf(_t / 0.05, 1.0)
	var r: float = lerpf(_r * 1.6, _r * 0.75, cierra) * late
	_anillo(_c, r, 2.6, Color(DIANA, 0.85 * alfa))
	_anillo(_c, r * 0.45, 1.8, Color(DIANA_CLARA, 0.6 * alfa))
	BarridoAire.brillo(self, _c, 3.5, Color(DIANA_CLARA, alfa))
	for j in 4:
		var a: float = PI * 0.5 * float(j) + PI * 0.25
		var d := Vector2(cos(a), sin(a))
		BarridoAire.cometa(self, _c + d * (r + 7.0), _c + d * (r + 1.0), 2.4, Color(DIANA, 0.9 * alfa))


# Un anillo relleno, mas opaco en medio del grosor y transparente a los dos bordes (no una raya).
func _anillo(c: Vector2, r: float, grueso: float, col: Color) -> void:
	if col.a <= 0.0:
		return
	var tr := Color(col, 0.0)
	var n: int = 24
	for i in n:
		var u0 := Vector2(cos(TAU * float(i) / n), sin(TAU * float(i) / n))
		var u1 := Vector2(cos(TAU * float(i + 1) / n), sin(TAU * float(i + 1) / n))
		for par in [[r + grueso, r], [r - grueso, r]]:
			var ext: float = par[0]
			var mid: float = par[1]
			draw_primitive(PackedVector2Array([c + u0 * ext, c + u1 * ext, c + u1 * mid]),
				PackedColorArray([tr, tr, col]), PackedVector2Array())
			draw_primitive(PackedVector2Array([c + u0 * ext, c + u1 * mid, c + u0 * mid]),
				PackedColorArray([tr, col, col]), PackedVector2Array())


# EL POLVO a los pies del Corte de tendones: el cuerpo cede y levanta tierra a los dos lados.
func _dibujar_polvo() -> void:
	if _fallo or _t < 0.0:
		return
	var k: float = clampf(_t / T_POLVO, 0.0, 1.0)
	var lado: Vector2 = Vector2(_dir.y, -_dir.x) if absf(_dir.x) < 0.3 else Vector2(1.0, 0.0)
	for s in [-1.0, 1.0]:
		for j in 3:
			var q: Vector2 = _pies + lado * s * (4.0 + 14.0 * k * (0.6 + 0.3 * float(j))) \
				+ Vector2(0.0, -2.0 - 3.0 * float(j) * k)
			BarridoAire.brillo(_suelo, q, 4.0 + 5.0 * k, Color(POLVO, 0.45 * (1.0 - k)))
