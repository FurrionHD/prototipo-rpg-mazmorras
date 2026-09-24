# ============================================================
#  daga_aire.gd
#  LOS EFECTOS DE LA DAGA en el mapa (24/09/2026). Cerrados con el usuario: la daga no rompe el suelo ni
#  barre huellas enteras, CORTA SOBRE CADA UNO. Por eso casi todo sale golpe a golpe sobre el cuerpo que
#  lo recibe (CombatFX.dibujo_en_mapa -> CombatTactico._on_dibujo_mapa), en todas las maquinas: el espejo
#  recibe los mismos golpes, asi que no cuesta red.
#    TAJO      una media luna corta y fina sobre el cuerpo (el basico y las puñaladas de Desaparecer)
#    RAFAGA    lo mismo en pequeño, cada una con su angulo y dos ecos detras: la lluvia de tajos
#    PUNALADA  una AGUJA de luz que entra recta y ASOMA POR DETRAS del cuerpo
#    PONZONA   el Filo emponzoñado: la mano del arma brilla en verde y gotea al suelo
#    HUMO      la bomba de Desaparecer: fogonazo y una nube de bolas de humo en su circulo. Va por el
#              camino del suelo (SueloRoto.Tipo.HUMO: ficha, red y el instante del golpe), y sus puñaladas
#              llegan cuando la nube ya esta hecha (retraso).
#    SOMBRA    el salto del Oportunista: te deshaces en sombra, un rastro de cometas oscuras y te formas
#              detras del enemigo. Lo lanza CombatTactico al hacer el salto.
#  La SANGRE va aparte (SangreMapa, al encajar). Coordenadas de MUNDO; todo sale de una semilla.
#  NADA DE LINEAS (efectos-sin-lineas): filo duro que se difumina, cometas, destellos en estrella.
# ============================================================
extends Node2D
class_name DagaAire

enum Modo { TAJO, RAFAGA, PUNALADA, PONZONA, HUMO, SOMBRA }

const T_TAJO := 0.05          # lo que tarda la media luna de punta a punta (acaba en el golpe)
const T_APAGA := 0.14         # y lo que tarda en irse
const T_ENTRA := 0.07         # lo que tarda la aguja en llegar
const T_ASOMA := 0.06         # y la punta en salir por detras
const T_HUMO_ABRE := 0.25     # lo que tarda la nube en cubrir el circulo: las puñaladas van despues
const T_HUMO_DURA := 1.3
const T_HUMO_VA := 0.6
const T_SOMBRA := 0.22
const T_PONZONA := 1.0
const GRAVEDAD := 420.0
const ALTO_TORSO := 14.0      # a que altura de los pies va el cuerpo (la mancha de sombra)

const BLANCO := BarridoAire.BLANCO
const ACERO := Color(0.80, 0.84, 0.90)
const HUMO := Color(0.34, 0.34, 0.37)
const HUMO_CLARO := Color(0.62, 0.62, 0.66)
const FOGONAZO := Color(1.0, 0.9, 0.7)
const SOMBRA := Color(0.07, 0.04, 0.11)
const VIOLETA := Color(0.40, 0.24, 0.58)
const VENENO := Color(0.42, 0.9, 0.3)
const VENENO_OSC := Color(0.14, 0.45, 0.1)
const Z_ENCIMA := Game.Z_PERSONAJES + 80
const Z_HUMO := Game.Z_PERSONAJES + 60

var modo: int = Modo.TAJO
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _suelo: Node2D = null     # lo que va bajo los cuerpos (la sombra del humo, los charcos)
# El golpe.
var _desde: Vector2 = Vector2.ZERO
var _caja: Rect2 = Rect2()
var _fallo: bool = false
var _crit: bool = false
var _n: int = 0
var _c: Vector2 = Vector2.ZERO      # donde cae (el centro del cuerpo)
var _o: Vector2 = Vector2.ZERO      # el centro del arco de la media luna
var _r: float = 12.0
var _a_ini: float = 0.0
var _a_fin: float = 1.0
var _grueso: float = 5.0
var _dir: Vector2 = Vector2.RIGHT
# El humo.
var _centro: Vector2 = Vector2.ZERO
var _radio: float = 45.0
var _bolas: Array = []
# La sombra.
var _hasta: Vector2 = Vector2.ZERO
var _volutas: Array = []
var _rastro: Array = []
# La ponzoña.
var _muneco: Node2D = null
var _punto_fijo: Vector2 = Vector2.INF   # sin muñeco (las hojas de prueba): la mano aqui
var _gotas: Array = []


# UN GOLPE sobre un cuerpo. 'desde' = de donde viene (la mano del que pega), 'caja' = el cuerpo que lo
# recibe tal como se ve, 'n' = el numero de golpe de la accion (cada uno con su angulo), 'espera' = lo
# que falta para el golpe en tiempo de la pelea (su vuelo), 'ritmo' = CombatFX.escala_tiempo.
static func golpe(padre: Node, m: int, desde: Vector2, caja: Rect2, fallo: bool, crit: bool, n: int,
		semilla: int, espera: float, ritmo: float) -> DagaAire:
	var d := _nuevo(padre, m, semilla, ritmo, Z_ENCIMA)
	if d == null:
		return null
	d._desde = desde
	d._caja = caja
	d._fallo = fallo
	d._crit = crit
	d._n = n
	d._t = -maxf(espera, 0.0)
	d._preparar_golpe()
	return d


# LA BOMBA DE HUMO, por el camino del suelo (SueloRoto.lanzar). 'espera' en segundos, como HachaAire.
static func humo(padre: Node, f: CombatFormas.Forma, semilla: int, espera: float) -> DagaAire:
	var d := _nuevo(padre, Modo.HUMO, semilla, BarridoAire.ritmo, Z_HUMO)
	if d == null or f == null:
		return d
	d._centro = f.centro
	d._radio = maxf(f.radio, 10.0)
	d._t = -espera * d._ritmo
	d._suelo = d._capa(SueloRoto.Z_SUELO)
	for i in 26:
		var u: float = sqrt(d._rng.randf()) * 0.9
		var a: float = d._rng.randf() * TAU
		var p: Vector2 = d._centro + Vector2(cos(a), sin(a)) * d._radio * u
		d._bolas.append({"p": p, "tam": d._rng.randf_range(13.0, 21.0), "t0": u * T_HUMO_ABRE * 0.8
			+ d._rng.randf_range(0.0, 0.05), "fase": d._rng.randf() * TAU, "sube": d._rng.randf_range(2.0, 7.0)})
	return d


# EL SALTO DEL OPORTUNISTA: de 'de' a 'a' (los PIES de donde estaba y de donde aparece).
static func sombra(padre: Node, de: Vector2, a: Vector2, semilla: int, ritmo: float) -> DagaAire:
	var d := _nuevo(padre, Modo.SOMBRA, semilla, ritmo, Z_ENCIMA)
	if d == null:
		return null
	d._centro = de + Vector2(0.0, -ALTO_TORSO)
	d._hasta = a + Vector2(0.0, -ALTO_TORSO)
	for i in 6:
		d._volutas.append({"v": Vector2(d._rng.randf_range(-12.0, 12.0), d._rng.randf_range(-22.0, -8.0)),
			"tam": d._rng.randf_range(2.0, 3.6)})
	var lado: Vector2 = (d._hasta - d._centro).normalized().orthogonal()
	for i in 5:
		d._rastro.append({"off": lado * d._rng.randf_range(-6.0, 6.0), "t0": 0.02 + 0.015 * float(i),
			"ancho": d._rng.randf_range(2.0, 3.4)})
	return d


# EL FILO EMPONZOÑADO, sobre la mano del arma de 'muneco' (MunecoJugador).
static func ponzona(padre: Node, muneco: Node2D, semilla: int, espera: float, ritmo: float,
		punto_fijo: Vector2 = Vector2.INF) -> DagaAire:
	var d := _nuevo(padre, Modo.PONZONA, semilla, ritmo, Z_ENCIMA)
	if d == null:
		return null
	d._muneco = muneco
	d._punto_fijo = punto_fijo
	d._t = -maxf(espera, 0.0)
	d._suelo = d._capa(SueloRoto.Z_SUELO)
	for i in 4:
		d._gotas.append({"t0": 0.12 + 0.2 * float(i) + d._rng.randf_range(0.0, 0.05), "p": Vector2.INF,
			"suelo": 0.0, "dx": d._rng.randf_range(-6.0, 6.0), "tam": d._rng.randf_range(2.6, 3.6)})
	return d


static func _nuevo(padre: Node, m: int, semilla: int, ritmo: float, z: int) -> DagaAire:
	if padre == null:
		return null
	var d := DagaAire.new()
	d.modo = m
	d._rng.seed = semilla
	d._ritmo = maxf(ritmo, 0.05)
	d.z_as_relative = false
	d.z_index = z
	d.process_mode = Node.PROCESS_MODE_ALWAYS   # la pelea tactica pausa el arbol
	padre.add_child(d)
	return d


func _capa(z: int) -> Node2D:
	var n := Node2D.new()
	n.z_as_relative = false
	n.z_index = z
	add_child(n)
	n.draw.connect(_dibujar_suelo.bind(n))
	return n


func duracion() -> float:
	match modo:
		Modo.PUNALADA: return T_ASOMA + 0.2
		Modo.PONZONA: return T_PONZONA + 0.8
		Modo.HUMO: return T_HUMO_DURA + T_HUMO_VA + 0.3
		Modo.SOMBRA: return 0.06 + T_SOMBRA + 0.1
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
#  EL GOLPE
# ------------------------------------------------------------
func _preparar_golpe() -> void:
	_c = _caja.get_center() if _caja.has_area() else _desde
	var alto: float = _caja.size.y if _caja.has_area() else 24.0
	_dir = (_c - _desde).normalized() if _c.distance_squared_to(_desde) > 0.01 else Vector2.RIGHT
	if modo == Modo.PUNALADA:
		# Con dos dagas son dos estocadas: cada una un pelo desplazada, para que se lean las dos.
		_c += _dir.orthogonal() * (2.5 if _n % 2 == 0 else -2.5)
		if _fallo:
			_c += _dir.orthogonal() * (_caja.size.x * 0.6 + 6.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
		return
	# LA MEDIA LUNA: un arco de ~100 grados cuyo punto medio cae sobre el cuerpo. El angulo del tajo va
	# cambiando de golpe en golpe (cruzados, en vertical, de lado...) para que la racha se lea nerviosa.
	_r = clampf(alto * 0.62, 10.0, 19.0) * (1.15 if modo == Modo.TAJO else 1.0)
	var angs: Array = [-0.6, 0.6, 1.57, -1.05, 0.25, 2.4, -0.25]
	var eje: float = float(angs[(_n + _rng.randi_range(0, 6)) % angs.size()]) + _rng.randf_range(-0.25, 0.25)
	var medio: float = eje + PI * 0.5
	if _fallo:
		var lado: float = 1.0 if _rng.randf() < 0.5 else -1.0
		_c += Vector2(lado * (_caja.size.x * 0.7 + 4.0), 0.0)
	_o = _c - Vector2(cos(medio), sin(medio)) * _r
	var sentido: float = 1.0 if _rng.randf() < 0.5 else -1.0
	_a_ini = medio - sentido * deg_to_rad(50.0)
	_a_fin = medio + sentido * deg_to_rad(50.0)
	_grueso = _r * (0.5 if modo == Modo.RAFAGA else 0.58)


func _draw() -> void:
	match modo:
		Modo.TAJO, Modo.RAFAGA: _dibujar_tajo()
		Modo.PUNALADA: _dibujar_punalada()
		Modo.PONZONA: _dibujar_ponzona()
		Modo.HUMO: _dibujar_humo()
		Modo.SOMBRA: _dibujar_sombra()


func _dibujar_tajo() -> void:
	if _t < -T_TAJO:
		return
	var p: float = clampf((_t + T_TAJO) / T_TAJO, 0.0, 1.0)
	p = 1.0 - (1.0 - p) * (1.0 - p)
	var cabeza: float = lerpf(_a_ini, _a_fin, p)
	var va: float = clampf(_t / T_APAGA, 0.0, 1.0) if _t > 0.0 else 0.0
	var cola: float = lerpf(_a_ini, _a_fin, va * 0.85)
	var alfa: float = (0.4 if _fallo else 1.0) * (1.0 - va)
	if alfa <= 0.0:
		return
	# Los ECOS de la Rafaga: la misma media luna, mas pequeña y mas tenue, un poco por detras.
	if modo == Modo.RAFAGA:
		for k in [2, 1]:
			var kr: float = 1.0 - 0.14 * float(k)
			var o_k: Vector2 = _c - (_c - _o) * kr - _dir * 2.5 * float(k)
			_media_luna(o_k, _r * kr, cola, lerpf(_a_ini, cabeza, 1.0 - 0.18 * float(k)), _grueso * kr,
				alfa * (0.4 if k == 1 else 0.2))
	_media_luna(_o, _r, cola, cabeza, _grueso, alfa)
	if not _fallo:
		var pulso: float = exp(-absf(_t) / 0.035)
		var rd: float = (9.0 if _crit else 4.5) * (0.3 + 0.9 * pulso)
		BarridoAire.destello(self, _c, rd, Color(BLANCO, (1.0 - va) * (0.35 + 0.65 * pulso)), 0.4 + float(_n))


# LA MEDIA LUNA: el FILO de fuera blanco y duro, que se difumina hacia dentro por el acero hasta nada.
# Afilada en las dos puntas y gorda en medio; mas opaca hacia la cabeza.
func _media_luna(o: Vector2, r: float, a_cola: float, a_cab: float, grueso: float, alfa: float) -> void:
	if alfa <= 0.0 or absf(a_cab - a_cola) < 0.02:
		return
	var n: int = 12
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


# LA AGUJA: una cuña rellena, transparente en la cola y blanca en la punta.
func _aguja(cola: Vector2, punta: Vector2, ancho: float, alfa: float) -> void:
	var d: Vector2 = punta - cola
	if alfa <= 0.0 or d.length_squared() < 0.01:
		return
	var n: Vector2 = d.normalized().orthogonal() * ancho * 0.5
	var medio: Vector2 = cola.lerp(punta, 0.72)
	var tr := Color(ACERO, 0.0)
	var ac := Color(ACERO, alfa * 0.85)
	var bl := Color(BLANCO, alfa)
	draw_primitive(PackedVector2Array([cola, medio + n, medio - n]), PackedColorArray([tr, ac, ac]), PackedVector2Array())
	draw_primitive(PackedVector2Array([medio + n, punta, medio - n]), PackedColorArray([ac, bl, ac]), PackedVector2Array())
	BarridoAire.cometa(self, cola.lerp(punta, 0.3), punta, ancho * 0.35, Color(BLANCO, alfa))


# Cuanto hay desde el centro del cuerpo hasta su borde, siguiendo 'd' (por donde asoma la punta).
func _hasta_el_borde(d: Vector2) -> float:
	if not _caja.has_area():
		return 8.0
	var h: Vector2 = _caja.size * 0.5
	var tx: float = h.x / absf(d.x) if absf(d.x) > 0.001 else INF
	var ty: float = h.y / absf(d.y) if absf(d.y) > 0.001 else INF
	return minf(minf(tx, ty), 40.0)


func _dibujar_punalada() -> void:
	if _t < -T_ENTRA:
		return
	var largo: float = 26.0
	var p: float = clampf((_t + T_ENTRA) / T_ENTRA, 0.0, 1.0)
	p = p * p
	var va: float = clampf(_t / 0.12, 0.0, 1.0) if _t > 0.0 else 0.0
	var alfa: float = (0.35 if _fallo else 1.0) * (1.0 - va)
	var punta: Vector2 = (_c - _dir * 30.0).lerp(_c + (_dir * 30.0 if _fallo else Vector2.ZERO), p)
	_aguja(punta - _dir * largo * (1.0 - 0.5 * va), punta, 4.2, alfa)
	if _fallo:
		return
	# ENTRA y ASOMA por detras: la punta sale por el otro lado del cuerpo.
	if _t >= 0.0:
		var sale: Vector2 = _c + _dir * _hasta_el_borde(_dir)
		var k: float = clampf(_t / T_ASOMA, 0.0, 1.0)
		k = 1.0 - (1.0 - k) * (1.0 - k)
		var va2: float = clampf((_t - T_ASOMA) / 0.12, 0.0, 1.0)
		_aguja(sale - _dir * 4.0, sale + _dir * 13.0 * k, 3.4, 1.0 - va2)
	var pulso: float = exp(-absf(_t) / 0.035)
	BarridoAire.destello(self, _c, (11.0 if _crit else 6.5) * (0.3 + 0.9 * pulso),
		Color(BLANCO, (1.0 - va) * (0.3 + 0.7 * pulso)), _dir.angle())


# ------------------------------------------------------------
#  LA PONZOÑA
# ------------------------------------------------------------
func _mano() -> Vector2:
	if not is_instance_valid(_muneco):
		return _punto_fijo
	var m = _muneco.call("punto_mano") if _muneco.has_method("punto_mano") else Vector2.INF
	if not (m is Vector2) or m == Vector2.INF:
		return _muneco.global_position + Vector2(8.0, -14.0)
	return _muneco.global_position + m


func _dibujar_ponzona() -> void:
	if _t < 0.0:
		return
	var mano: Vector2 = _mano()
	if mano == Vector2.INF:
		return
	# La mano del arma, verde y latiendo.
	if _t < T_PONZONA:
		var k: float = _t / T_PONZONA
		var late: float = 0.75 + 0.25 * sin(_t * 18.0)
		BarridoAire.brillo(self, mano, 12.0 * late, Color(VENENO, 0.55 * (1.0 - k) * minf(_t / 0.08, 1.0)))
		BarridoAire.brillo(self, mano, 4.5, Color(0.85, 1.0, 0.75, 0.85 * (1.0 - k)))
	# Las gotas: se sueltan de la mano, caen y se quedan en el suelo.
	var suelo_y: float = (_muneco.global_position.y + PoseJugador.PIES_BAJO_NODO) if is_instance_valid(_muneco) \
		else _punto_fijo.y + ALTO_TORSO
	for g in _gotas:
		var tg: float = _t - float(g["t0"])
		if tg < 0.0:
			continue
		if g["p"] == Vector2.INF:
			g["p"] = mano + Vector2(float(g["dx"]) * 0.3, 0.0)
			g["suelo"] = suelo_y + _rng.randf_range(-2.0, 2.0)
		var p0: Vector2 = g["p"]
		var y: float = p0.y + 0.5 * GRAVEDAD * tg * tg
		if y >= float(g["suelo"]):
			continue
		var q := Vector2(p0.x, y)
		BarridoAire.cometa(self, q - Vector2(0.0, 3.0 + GRAVEDAD * tg * 0.02), q, float(g["tam"]), Color(VENENO, 0.95))


func _dibujar_suelo(capa: Node2D) -> void:
	if modo == Modo.HUMO:
		# La sombra del humo en el suelo: redonda (el suelo no se achata) y suave.
		if _t < 0.0:
			return
		var k: float = clampf(_t / T_HUMO_ABRE, 0.0, 1.0)
		var va: float = clampf((_t - T_HUMO_DURA) / T_HUMO_VA, 0.0, 1.0)
		BarridoAire.brillo(capa, _centro, _radio * (0.4 + 0.6 * k), Color(HUMO, 0.4 * k * (1.0 - va)))
		return
	# Los charcos de veneno donde caen las gotas.
	for g in _gotas:
		if g["p"] == Vector2.INF:
			continue
		var p0: Vector2 = g["p"]
		var t_cae: float = sqrt(2.0 * maxf(float(g["suelo"]) - p0.y, 0.0) / GRAVEDAD)
		var tc: float = _t - float(g["t0"]) - t_cae
		if tc < 0.0:
			continue
		var crece: float = clampf(tc / 0.15, 0.0, 1.0)
		var va: float = clampf((tc - 0.5) / 0.5, 0.0, 1.0)
		var c := Vector2(p0.x, float(g["suelo"]))
		BarridoAire.brillo(capa, c, 3.0 + 5.5 * crece, Color(VENENO_OSC, 0.85 * (1.0 - va)))
		BarridoAire.brillo(capa, c, 2.0 + 2.5 * crece, Color(VENENO, 0.7 * (1.0 - va)))


# ------------------------------------------------------------
#  EL HUMO
# ------------------------------------------------------------
func _dibujar_humo() -> void:
	if _t < 0.0:
		return
	# El FOGONAZO del frasco al reventar.
	if _t < 0.16:
		var kf: float = _t / 0.16
		BarridoAire.destello(self, _centro + Vector2(0.0, -4.0), 18.0 * (1.0 - kf * 0.6),
			Color(FOGONAZO, 1.0 - kf), 0.3)
		BarridoAire.brillo(self, _centro + Vector2(0.0, -4.0), 14.0 * (0.5 + kf), Color(FOGONAZO, 0.5 * (1.0 - kf)))
	var va_todo: float = clampf((_t - T_HUMO_DURA) / T_HUMO_VA, 0.0, 1.0)
	for b in _bolas:
		var tb: float = _t - float(b["t0"])
		if tb < 0.0:
			continue
		var k: float = clampf(tb / 0.18, 0.0, 1.0)
		k = 1.0 - (1.0 - k) * (1.0 - k)
		var tam: float = float(b["tam"]) * (0.35 + 0.65 * k) * (1.0 + 0.5 * va_todo)
		var ondula: float = sin(_t * 3.0 + float(b["fase"]))
		var p: Vector2 = (b["p"] as Vector2) + Vector2(ondula * 1.5, -6.0 - float(b["sube"]) * (k + 2.0 * va_todo))
		var alfa: float = 0.92 * k * (1.0 - va_todo)
		if alfa <= 0.0:
			continue
		BarridoAire.brillo(self, p, tam, Color(HUMO, alfa))
		BarridoAire.brillo(self, p, tam * 0.7, Color(HUMO, alfa * 0.6))
		BarridoAire.brillo(self, p + Vector2(-tam * 0.2, -tam * 0.25), tam * 0.6, Color(HUMO_CLARO, alfa * 0.7))


# ------------------------------------------------------------
#  LA SOMBRA DEL OPORTUNISTA
# ------------------------------------------------------------
func _dibujar_sombra() -> void:
	if _t < 0.0:
		return
	# Donde estaba: una mancha que se encoge y suelta volutas hacia arriba.
	var k: float = clampf(_t / T_SOMBRA, 0.0, 1.0)
	if k < 1.0:
		BarridoAire.brillo(self, _centro, 20.0 * (1.0 - k) + 2.0, Color(VIOLETA, 0.35 * (1.0 - k)))
		BarridoAire.brillo(self, _centro, 15.0 * (1.0 - k * k), Color(SOMBRA, 0.9 * (1.0 - k)))
	for v in _volutas:
		var q: Vector2 = _centro + (v["v"] as Vector2) * k
		BarridoAire.brillo(self, q, float(v["tam"]) * (1.0 - k * 0.5), Color(SOMBRA, 0.75 * (1.0 - k)))
	# El RASTRO: cometas oscuras de un sitio al otro, muy rapidas.
	for r in _rastro:
		var u: float = (_t - float(r["t0"])) / 0.09
		if u < 0.0 or u > 1.5:
			continue
		var cab: Vector2 = _centro.lerp(_hasta, clampf(u, 0.0, 1.0)) + (r["off"] as Vector2)
		var col: Vector2 = _centro.lerp(_hasta, clampf(u - 0.45, 0.0, 1.0)) + (r["off"] as Vector2)
		var a: float = 0.75 * (1.0 - clampf((u - 1.0) / 0.5, 0.0, 1.0))
		BarridoAire.cometa(self, col, cab, float(r["ancho"]), Color(SOMBRA, a))
	# Donde aparece: la mancha al reves, crece y se deshace dejando al personaje.
	var tl: float = _t - 0.06
	if tl >= 0.0 and tl < T_SOMBRA:
		var kl: float = tl / T_SOMBRA
		var s: float = sin(PI * kl)
		BarridoAire.brillo(self, _hasta, 22.0 * s + 2.0, Color(VIOLETA, 0.35 * s))
		BarridoAire.brillo(self, _hasta, 16.0 * s, Color(SOMBRA, 0.9 * s))
