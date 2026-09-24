# ============================================================
#  estoque_aire.gd
#  LOS EFECTOS DEL ESTOQUE en el mapa (24/09/2026). El estoque no corta: PINCHA. Todo es de PUNTA, una
#  aguja de luz larga y fina que entra recta, y lo que cambia de una habilidad a otra es como entra y que
#  deja. Sale golpe a golpe sobre el cuerpo que lo recibe (CombatFX.dibujo_en_mapa ->
#  CombatTactico._on_dibujo_mapa), en todas las maquinas, como la daga.
#    PUNZADA     la estocada de siempre: entra, el aire se abre detras de la punta y sale (el basico, el
#                del Paso ligero y el contraataque de En guardia)
#    PENETRANTE  la que ATRAVIESA: la aguja cruza el cuerpo entero, sale por detras y revienta en un
#                abanico de aire, con un tunel de luz a lo largo
#    FINTA       antes de cada estocada, el AMAGO: una aguja fantasma por otro lado que se retira
#    NERVIO      la Punzada al nervio: aguja finisima y un chispazo amarillo que recorre el cuerpo
#    DANZA       la de la Danza de acero: la aguja con dos ecos detras (va de paso, muy rapido)
#    RASTRO      el PASO y el AVANCE: polvo al arrancar y al frenar, y rafagas de aire siguiendo al
#                cuerpo. Lo lanza CombatTactico al empezar el desliz.
#  Coordenadas de MUNDO; todo sale de una semilla. NADA DE LINEAS (efectos-sin-lineas).
# ============================================================
extends Node2D
class_name EstoqueAire

enum Modo { PUNZADA, PENETRANTE, FINTA, NERVIO, DANZA, RASTRO, GUARDIA, ESQUIVA }
#    GUARDIA     al ponerte En guardia: un destello recorre la hoja de la mano a la punta, el aire se
#                cierra sobre tus pies y se levanta polvo a los lados (te plantas en la postura)
#    ESQUIVA     CUALQUIERA que esquiva (de los tuyos o enemigo): el cuerpo se aparta de lado y vuelve y
#                deja su eco donde estaba. En guardia, ademas, la hoja destella parando el golpe (el
#                contraataque viene despues, aparte)

const T_ENTRA := 0.055        # lo que tarda la aguja en llegar (acaba en el golpe)
const T_AMAGO := 0.09         # el amago de la Finta: sale y se retira antes de la de verdad
const T_ASOMA := 0.05         # lo que tarda la punta en salir por detras (Penetrante)
const T_APAGA := 0.13
const T_CHISPA := 0.22        # lo que dura el chispazo del nervio
const T_POLVO := 0.45
const LARGO_AGUJA := 40.0     # la hoja del estoque es larga
const ALTO_TORSO := 14.0
# LA DANZA: el frente que corre por la linea, a esta velocidad (px por segundo de verdad). El cuerpo
# avanza a la misma y cada estocada cae cuando el frente llega a su enemigo (SueloRoto.Tipo.DANZA).
const V_DANZA := 260.0

const BLANCO := BarridoAire.BLANCO
const ACERO := Color(0.80, 0.84, 0.90)
const AIRE := Color(0.86, 0.90, 0.96)
const NERVIO := Color(1.0, 0.93, 0.5)
const POLVO := Color(0.55, 0.51, 0.45)
const Z_ENCIMA := Game.Z_PERSONAJES + 80

var modo: int = Modo.PUNZADA
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _suelo: Node2D = null
# El golpe.
var _desde: Vector2 = Vector2.ZERO
var _caja: Rect2 = Rect2()
var _fallo: bool = false
var _crit: bool = false
var _n: int = 0
var _c: Vector2 = Vector2.ZERO
var _dir: Vector2 = Vector2.RIGHT
var _amago: Vector2 = Vector2.RIGHT   # por donde entra el amago (Finta)
var _abanico: Array = []              # el aire que se abre (angulo, largo, ancho)
var _chispa: Array = []               # el camino del chispazo (Nervio)
# El rastro.
var _de: Vector2 = Vector2.ZERO
var _a: Vector2 = Vector2.ZERO
var _dur: float = 0.2
var _rafagas: Array = []
# La postura y la esquiva.
var _muneco: CanvasItem = null   # Node2D en el juego; la figura (ColorRect) en las hojas
var _mano_fija: Vector2 = Vector2.INF
var _base_muneco: Vector2 = Vector2.ZERO
var _parada: bool = true
var _lado: float = 11.0
const T_BRILLA_HOJA := 0.12   # lo que tarda el destello en recorrer la hoja
const T_ESQ_SALE := 0.07      # la esquiva: sale de lado...
const T_ESQ_QUIETO := 0.1     # ...se queda...
const T_ESQ_VUELVE := 0.16    # ...y vuelve a su sitio
const LADO_ESQUIVA := 11.0
const LARGO_HOJA := 28.0


# UN GOLPE sobre un cuerpo, como DagaAire.golpe.
static func golpe(padre: Node, m: int, desde: Vector2, caja: Rect2, fallo: bool, crit: bool, n: int,
		semilla: int, espera: float, ritmo: float) -> EstoqueAire:
	var e := _nuevo(padre, m, semilla, ritmo)
	if e == null:
		return null
	e._desde = desde
	e._caja = caja
	e._fallo = fallo
	e._crit = crit
	e._n = n
	e._t = -maxf(espera, 0.0)
	e._preparar_golpe()
	return e


# EL RASTRO de un paso o un avance: de 'de' a 'a' (los PIES), en 'dur' segundos de verdad.
static func rastro(padre: Node, de: Vector2, a: Vector2, dur: float, semilla: int) -> EstoqueAire:
	var e := _nuevo(padre, Modo.RASTRO, semilla, 1.0)
	if e == null:
		return null
	e._de = de
	e._a = a
	e._dur = maxf(dur, 0.05)
	e._suelo = Node2D.new()
	e._suelo.z_as_relative = false
	e._suelo.z_index = SueloRoto.Z_SUELO
	e.add_child(e._suelo)
	e._suelo.draw.connect(e._dibujar_polvo)
	var lado: Vector2 = (a - de).normalized().orthogonal() if a.distance_squared_to(de) > 0.01 else Vector2.UP
	for i in 6:
		e._rafagas.append({"off": lado * e._rng.randf_range(-7.0, 7.0) + Vector2(0.0, -e._rng.randf_range(4.0, 24.0)),
			"t0": e._rng.randf_range(0.0, 0.35), "largo": e._rng.randf_range(0.25, 0.5),
			"ancho": e._rng.randf_range(1.6, 2.8)})
	return e


# EN GUARDIA (al activarla) y LA ESQUIVA en guardia, sobre el que la hace. 'muneco' = su MunecoJugador
# (sin el, las hojas de prueba: la mano en 'mano_fija'); 'pies' = sus pies; 'hacia' = hacia donde mira la
# hoja (en la esquiva: de donde viene el golpe). La esquiva MUEVE el muñeco de lado y lo devuelve.
# LA ESQUIVA VALE PARA TODOS (lo pidio el: "el esquive es para todos en general"): quien esquiva un golpe
# se aparta de lado y vuelve, sea de los tuyos (se mueve su MunecoJugador) o un enemigo (su sprite). Solo
# En guardia lleva ademas la PARADA (el destello de la hoja): 'parada'. 'caja' = lo que se ve del cuerpo,
# para el tamaño del eco.
static func postura(padre: Node, m: int, muneco: CanvasItem, pies: Vector2, hacia: Vector2, semilla: int,
		espera: float, ritmo: float, mano_fija: Vector2 = Vector2.INF, parada: bool = true,
		caja: Rect2 = Rect2()) -> EstoqueAire:
	var e := _nuevo(padre, m, semilla, ritmo)
	if e == null:
		return null
	e._muneco = muneco
	e._parada = parada
	e._caja = caja
	# Lo que se aparta: un palmo, o media anchura si el cuerpo es grande.
	e._lado = maxf(LADO_ESQUIVA, caja.size.x * 0.4) if caja.has_area() else LADO_ESQUIVA
	e._mano_fija = mano_fija
	e._de = pies
	e._dir = hacia.normalized() if hacia.length_squared() > 0.01 else Vector2.RIGHT
	e._t = -maxf(espera, 0.0)
	e._suelo = Node2D.new()
	e._suelo.z_as_relative = false
	e._suelo.z_index = SueloRoto.Z_SUELO
	e.add_child(e._suelo)
	e._suelo.draw.connect(e._dibujar_suelo_postura)
	# De lado respecto al golpe, hacia el lado que toque (se alterna con la semilla).
	e._a = e._dir.orthogonal() * (1.0 if e._rng.randf() < 0.5 else -1.0)
	# EL SITIO DE VERDAD del muñeco, compartido entre esquivas que se pisan (dos golpes seguidos): la
	# segunda no puede tomar como sitio el de la primera, ya apartado.
	if m == Modo.ESQUIVA and is_instance_valid(muneco):
		if not muneco.has_meta(&"esq_base"):
			muneco.set_meta(&"esq_base", muneco.position)
		muneco.set_meta(&"esq_n", int(muneco.get_meta(&"esq_n", 0)) + 1)
		e._base_muneco = muneco.get_meta(&"esq_base")
	return e


static func _nuevo(padre: Node, m: int, semilla: int, ritmo: float) -> EstoqueAire:
	if padre == null:
		return null
	var e := EstoqueAire.new()
	e.modo = m
	e._rng.seed = semilla
	e._ritmo = maxf(ritmo, 0.05)
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS   # la pelea tactica pausa el arbol
	padre.add_child(e)
	return e


func duracion() -> float:
	match modo:
		Modo.PENETRANTE: return T_ASOMA + 0.35
		Modo.NERVIO: return T_CHISPA + 0.1
		Modo.RASTRO: return _dur + T_POLVO + 0.1
		Modo.GUARDIA: return T_BRILLA_HOJA + T_POLVO + 0.1
		Modo.ESQUIVA: return T_ESQ_SALE + T_ESQ_QUIETO + T_ESQ_VUELVE + 0.15
	return T_APAGA + 0.1


func _process(delta: float) -> void:
	_t += delta * _ritmo
	if _t >= duracion():
		_devolver_muneco()
		queue_free()
		return
	if modo == Modo.ESQUIVA and is_instance_valid(_muneco):
		_muneco.position = _base_muneco + _a * _lado * _cuanto_fuera(_t)
	queue_redraw()
	if _suelo != null:
		_suelo.queue_redraw()


func _exit_tree() -> void:
	_devolver_muneco()


# El muñeco, a su sitio (la esquiva no mueve al personaje en la pelea: solo su dibujo, y vuelve).
func _devolver_muneco() -> void:
	if modo != Modo.ESQUIVA or not is_instance_valid(_muneco):
		return
	_muneco.position = _base_muneco
	var n: int = int(_muneco.get_meta(&"esq_n", 1)) - 1
	if n <= 0:
		_muneco.remove_meta(&"esq_base")
		_muneco.remove_meta(&"esq_n")
	else:
		_muneco.set_meta(&"esq_n", n)
	_muneco = null   # una sola vez (lo llaman el final y _exit_tree)


# Lo apartado que esta el cuerpo en la esquiva (0 = en su sitio, 1 = del todo a un lado).
func _cuanto_fuera(t: float) -> float:
	if t <= 0.0:
		return 0.0
	if t < T_ESQ_SALE:
		var u: float = t / T_ESQ_SALE
		return 1.0 - (1.0 - u) * (1.0 - u)
	t -= T_ESQ_SALE
	if t < T_ESQ_QUIETO:
		return 1.0
	t -= T_ESQ_QUIETO
	var v: float = clampf(t / T_ESQ_VUELVE, 0.0, 1.0)
	return 1.0 - v * v * (3.0 - 2.0 * v)


# La mano del arma en mundo (sin muñeco, la fija de las hojas).
func _mano() -> Vector2:
	if not is_instance_valid(_muneco):
		return _mano_fija if _mano_fija != Vector2.INF else _de + Vector2(6.0, -ALTO_TORSO)
	var m = _muneco.call("punto_mano") if _muneco.has_method("punto_mano") else Vector2.INF
	if not (m is Vector2) or m == Vector2.INF:
		return _muneco.global_position + Vector2(6.0, -ALTO_TORSO)
	return _muneco.global_position + m


# ------------------------------------------------------------
#  EL GOLPE
# ------------------------------------------------------------
func _preparar_golpe() -> void:
	_c = _caja.get_center() if _caja.has_area() else _desde
	_dir = (_c - _desde).normalized() if _c.distance_squared_to(_desde) > 0.01 else Vector2.RIGHT
	# Cada estocada de una racha entra un pelo mas arriba o mas abajo: se leen de una en una.
	var alto: float = _caja.size.y if _caja.has_area() else 24.0
	_c += Vector2(0.0, alto * [0.0, -0.18, 0.14, -0.08][_n % 4])
	if _fallo:
		_c += _dir.orthogonal() * (_caja.size.x * 0.6 + 6.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
	# EL AMAGO de la Finta: por un lado u otro (alterna), bien abierto para que se vea que es otro.
	var lado: float = 1.0 if _n % 2 == 0 else -1.0
	_amago = _dir.rotated(lado * deg_to_rad(_rng.randf_range(30.0, 42.0)))
	# El aire que se abre detras de la punta: tres o cuatro rafagas en abanico hacia atras.
	for i in (5 if modo == Modo.PENETRANTE else 3):
		_abanico.append({"a": _rng.randf_range(-0.9, 0.9), "l": _rng.randf_range(8.0, 15.0),
			"w": _rng.randf_range(1.4, 2.4)})
	# El chispazo del nervio: un zigzag por el cuerpo que sale de donde entra la punta.
	if modo == Modo.NERVIO:
		var p: Vector2 = _c
		var h: Vector2 = _caja.size * 0.5 if _caja.has_area() else Vector2(10.0, 12.0)
		for i in 7:
			var q: Vector2 = _c + Vector2(_rng.randf_range(-h.x, h.x) * 0.8, _rng.randf_range(-h.y, h.y) * 0.8)
			_chispa.append([p, q])
			p = q


func _draw() -> void:
	if modo == Modo.RASTRO:
		_dibujar_rastro()
		return
	if modo == Modo.GUARDIA:
		_dibujar_guardia()
		return
	if modo == Modo.ESQUIVA:
		_dibujar_esquiva()
		return
	if modo == Modo.FINTA:
		_dibujar_amago()
	if _t < -T_ENTRA:
		return
	var p: float = clampf((_t + T_ENTRA) / T_ENTRA, 0.0, 1.0)
	p = p * p
	var va: float = clampf(_t / T_APAGA, 0.0, 1.0) if _t > 0.0 else 0.0
	var alfa: float = (0.35 if _fallo else 1.0) * (1.0 - va)
	var ancho: float = 2.8 if modo == Modo.NERVIO else (5.4 if modo == Modo.PENETRANTE else 4.4)
	# LA AGUJA: la punta viaja de fuera hasta el cuerpo (en el fallo, de largo por su lado).
	var ini: Vector2 = _c - _dir * (LARGO_AGUJA + 8.0)
	var fin: Vector2 = _c + (_dir * 26.0 if _fallo else Vector2.ZERO)
	var punta: Vector2 = ini.lerp(fin, p)
	# Los ECOS de la Danza: la misma aguja, detras y mas tenue.
	if modo == Modo.DANZA:
		for k in [2, 1]:
			var atras: Vector2 = -_dir * 6.0 * float(k) + _dir.orthogonal() * 2.0 * float(k) * (1.0 if _n % 2 == 0 else -1.0)
			_aguja(punta + atras - _dir * LARGO_AGUJA, punta + atras, ancho * 0.8, alfa * (0.35 if k == 1 else 0.18))
	_aguja(punta - _dir * LARGO_AGUJA * (1.0 - 0.45 * va), punta, ancho, alfa)
	if _fallo or _t < 0.0:
		return
	var pulso: float = exp(-_t / 0.035)
	# EL AIRE SE ABRE detras de la punta, en abanico hacia fuera y hacia atras.
	for f in _abanico:
		var d: Vector2 = (-_dir).rotated(float(f["a"]))
		var k: float = clampf(_t / 0.08, 0.0, 1.0)
		var base: Vector2 = _c - _dir * 3.0 + d * 3.0 * k
		BarridoAire.cometa(self, base, base + d * float(f["l"]) * (0.4 + 0.6 * k), float(f["w"]),
			Color(AIRE, 0.7 * (1.0 - va)))
	if modo == Modo.PENETRANTE:
		_dibujar_atraviesa(va)
	elif modo == Modo.NERVIO:
		_dibujar_chispa()
	var rd: float = (13.0 if _crit else 7.0) if modo == Modo.PENETRANTE else ((10.0 if _crit else 5.5))
	BarridoAire.destello(self, _c, rd * (0.3 + 0.9 * pulso), Color(BLANCO, (1.0 - va) * (0.35 + 0.65 * pulso)),
		_dir.angle() + 0.4)


# LA AGUJA: una cuña rellena, transparente en la cola y blanca en la punta (la de DagaAire, mas larga).
func _aguja(cola: Vector2, punta: Vector2, ancho: float, alfa: float) -> void:
	var d: Vector2 = punta - cola
	if alfa <= 0.0 or d.length_squared() < 0.01:
		return
	var n: Vector2 = d.normalized().orthogonal() * ancho * 0.5
	var medio: Vector2 = cola.lerp(punta, 0.78)
	var tr := Color(ACERO, 0.0)
	var ac := Color(ACERO, alfa * 0.85)
	var bl := Color(BLANCO, alfa)
	draw_primitive(PackedVector2Array([cola, medio + n, medio - n]), PackedColorArray([tr, ac, ac]), PackedVector2Array())
	draw_primitive(PackedVector2Array([medio + n, punta, medio - n]), PackedColorArray([ac, bl, ac]), PackedVector2Array())
	BarridoAire.cometa(self, cola.lerp(punta, 0.35), punta, ancho * 0.35, Color(BLANCO, alfa))


# EL AMAGO: sale por otro lado, se queda a medio camino y se retira. Acaba justo cuando arranca la buena.
func _dibujar_amago() -> void:
	var t0: float = -T_ENTRA - T_AMAGO
	if _t < t0 or _t > -T_ENTRA:
		return
	var u: float = (_t - t0) / T_AMAGO
	var ida: float = sin(PI * u)                 # sale y vuelve
	var ini: Vector2 = _c - _amago * (LARGO_AGUJA + 16.0)
	var punta: Vector2 = ini.lerp(_c - _amago * 6.0, ida)
	_aguja(punta - _amago * LARGO_AGUJA * 0.8, punta, 3.0, 0.45 * ida)


# LA PENETRANTE: la punta sale por detras del cuerpo, revienta en un abanico y deja un tunel de luz.
func _dibujar_atraviesa(va: float) -> void:
	var borde: float = _hasta_el_borde(_dir)
	var sale: Vector2 = _c + _dir * borde
	var k: float = clampf(_t / T_ASOMA, 0.0, 1.0)
	k = 1.0 - (1.0 - k) * (1.0 - k)
	var va2: float = clampf((_t - T_ASOMA) / 0.2, 0.0, 1.0)
	# El tunel: una rafaga larga por donde ha pasado la hoja, de delante a detras.
	BarridoAire.cometa(self, _c - _dir * (LARGO_AGUJA + 10.0), sale + _dir * 20.0 * k, 5.5,
		Color(AIRE, 0.45 * (1.0 - va2)))
	_aguja(sale - _dir * 6.0, sale + _dir * 20.0 * k, 3.6, 1.0 - va2)
	# El reventon al salir: rafagas en abanico hacia delante.
	if _t >= T_ASOMA * 0.5:
		var kr: float = clampf((_t - T_ASOMA * 0.5) / 0.12, 0.0, 1.0)
		for f in _abanico:
			var d: Vector2 = _dir.rotated(float(f["a"]) * 0.8)
			var base: Vector2 = sale + d * 4.0 * kr
			BarridoAire.cometa(self, base, base + d * float(f["l"]) * 1.3 * (0.3 + 0.7 * kr), float(f["w"]) * 1.2,
				Color(AIRE, 0.8 * (1.0 - kr)))
		BarridoAire.destello(self, sale, 7.0 * (1.0 - kr) + 2.0, Color(BLANCO, 0.9 * (1.0 - kr)), _dir.angle())


# EL CHISPAZO del nervio: tramos cortos que se encienden uno detras de otro y se apagan.
func _dibujar_chispa() -> void:
	for i in _chispa.size():
		var ti: float = _t - 0.018 * float(i)
		if ti < 0.0:
			continue
		var a: float = 1.0 - clampf(ti / (T_CHISPA * 0.6), 0.0, 1.0)
		if a <= 0.0:
			continue
		var seg: Array = _chispa[i]
		BarridoAire.cometa(self, seg[0], seg[1], 2.2, Color(NERVIO, 0.95 * a))
		BarridoAire.brillo(self, seg[1], 3.5, Color(NERVIO, 0.5 * a))


func _hasta_el_borde(d: Vector2) -> float:
	if not _caja.has_area():
		return 8.0
	var h: Vector2 = _caja.size * 0.5
	var tx: float = h.x / absf(d.x) if absf(d.x) > 0.001 else INF
	var ty: float = h.y / absf(d.y) if absf(d.y) > 0.001 else INF
	return minf(minf(tx, ty), 40.0)


# ------------------------------------------------------------
#  EN GUARDIA Y LA ESQUIVA
# ------------------------------------------------------------
# EL DESTELLO QUE RECORRE LA HOJA: un brillo que corre de la mano a la punta (con su estela detras) y
# revienta en estrella en la punta. La hoja va de la mano hacia donde mira.
func _dibujar_guardia() -> void:
	if _t < 0.0:
		return
	var mano: Vector2 = _mano()
	var punta: Vector2 = mano + _dir * LARGO_HOJA
	var k: float = clampf(_t / T_BRILLA_HOJA, 0.0, 1.0)
	var va: float = clampf((_t - T_BRILLA_HOJA) / 0.25, 0.0, 1.0)
	if k < 1.0:
		var cab: Vector2 = mano.lerp(punta, k * k * (3.0 - 2.0 * k))
		BarridoAire.cometa(self, mano.lerp(cab, 0.3), cab, 3.2, Color(BLANCO, 0.9))
		BarridoAire.brillo(self, cab, 5.0, Color(BLANCO, 0.55))
	var pulso: float = exp(-maxf(_t - T_BRILLA_HOJA, 0.0) / 0.06) if _t >= T_BRILLA_HOJA * 0.7 else 0.0
	if pulso > 0.01:
		BarridoAire.destello(self, punta, 11.0 * (0.4 + 0.8 * pulso), Color(BLANCO, (1.0 - va) * pulso), 0.3)


# La postura se nota en el SUELO: el aire se cierra sobre los pies y el polvo sale a los dos lados.
func _dibujar_suelo_postura() -> void:
	if _t < 0.0:
		return
	if modo == Modo.GUARDIA:
		var k: float = clampf(_t / 0.2, 0.0, 1.0)
		BarridoAire.brillo(_suelo, _de, 26.0 * (1.0 - 0.6 * k), Color(AIRE, 0.28 * (1.0 - k)))
		var lado: Vector2 = _dir.orthogonal()
		_bocanada_hacia(_de + lado * 5.0, lado, _t)
		_bocanada_hacia(_de - lado * 5.0, -lado, _t)
	elif modo == Modo.ESQUIVA:
		# El pie que empuja al salir de lado.
		_bocanada_hacia(_de, -_a, _t)
		# El eco y las rafagas, DETRAS de los cuerpos (en esta capa baja): encima tapaban al que esquiva.
		_dibujar_eco(_suelo)


func _bocanada_hacia(p: Vector2, hacia: Vector2, t: float) -> void:
	if t < 0.0 or t > T_POLVO:
		return
	var k: float = t / T_POLVO
	var s: float = 1.0 - (1.0 - k) * (1.0 - k)
	for i in 3:
		var d: Vector2 = hacia.rotated((float(i) - 1.0) * 0.5)
		var q: Vector2 = p + d * 10.0 * s + Vector2(0.0, -3.0 * s)
		BarridoAire.brillo(_suelo, q, 3.5 + 4.5 * s, Color(POLVO, 0.5 * (1.0 - k)))


# LA ESQUIVA: el eco del cuerpo donde estaba (se queda mientras el cuerpo esta fuera) y el destello de la
# parada en la hoja, girado hacia el golpe.
func _dibujar_esquiva() -> void:
	if _t < 0.0 or not _parada:
		return
	# LA PARADA: la hoja destella donde desvia el golpe, al llegar este (t = 0).
	var pulso: float = exp(-_t / 0.05)
	var cruce: Vector2 = _mano() + _dir * 10.0
	BarridoAire.destello(self, cruce, 13.0 * (0.35 + 0.8 * pulso), Color(BLANCO, pulso), _dir.angle() + 0.785)
	BarridoAire.brillo(self, cruce, 9.0 * pulso, Color(1.0, 0.95, 0.8, 0.5 * pulso))


func _dibujar_eco(ci: CanvasItem) -> void:
	if _t < 0.0:
		return
	var fuera: float = _cuanto_fuera(_t)
	var a_eco: float = 0.45 * fuera * (1.0 - clampf((_t - T_ESQ_SALE - T_ESQ_QUIETO) / T_ESQ_VUELVE, 0.0, 1.0))
	# El tamaño del que esquiva: su caja (un jefe grande deja un eco grande); sin ella, el de una persona.
	var alto: float = clampf(_caja.size.y, 14.0, 90.0) if _caja.has_area() else 26.0
	var ancho: float = clampf(_caja.size.x, 10.0, 90.0) if _caja.has_area() else 14.0
	if a_eco > 0.01:
		for k in 3:
			var h: float = alto * (0.2 + 0.32 * float(k))
			BarridoAire.brillo(ci, _de + Vector2(0.0, -h), ancho * (0.42 if k == 1 else 0.36), Color(AIRE, a_eco))
	# Rafagas del salto de lado, de donde estaba hacia donde va.
	if _t < T_ESQ_SALE + 0.1:
		var va: float = clampf((_t - T_ESQ_SALE) / 0.1, 0.0, 1.0)
		for i in 3:
			var alt := Vector2(0.0, -alto * (0.25 + 0.3 * float(i)))
			var cab: Vector2 = _de + alt + _a * _lado * fuera
			BarridoAire.cometa(ci, _de + alt - _a * 3.0, cab, 2.0, Color(AIRE, 0.6 * (1.0 - va)))


# ------------------------------------------------------------
#  EL RASTRO (paso y avance)
# ------------------------------------------------------------
# Donde va el cuerpo a los 't' segundos: parejo en el avance, y en el paso arranca rapido y frena
# (la misma cuenta que CombatTactico._tick_deslices).
func _donde(t: float) -> Vector2:
	var u: float = clampf(t / _dur, 0.0, 1.0)
	return _de.lerp(_a, u)


func _dibujar_rastro() -> void:
	if _t < 0.0:
		return
	# LOS ECOS DEL CUERPO: siluetas de aire que se quedan donde pasaste y se deshacen (el que ya no esta
	# ahi). Tres, repartidas por el camino, cada una aparece cuando el cuerpo pasa por ella.
	for k in 3:
		var u: float = 0.2 + 0.3 * float(k)
		var te: float = _t - u * _dur
		if te < 0.0:
			continue
		var a: float = 0.42 * (1.0 - clampf(te / 0.22, 0.0, 1.0)) * (0.6 + 0.2 * float(k))
		if a <= 0.0:
			continue
		var p: Vector2 = _donde(u * _dur)
		BarridoAire.brillo(self, p + Vector2(0.0, -5.0), 6.0, Color(AIRE, a))
		BarridoAire.brillo(self, p + Vector2(0.0, -13.0), 7.0, Color(AIRE, a))
		BarridoAire.brillo(self, p + Vector2(0.0, -22.0), 5.0, Color(AIRE, a * 1.1))
	# Las rafagas de aire a la altura del cuerpo, cada una siguiendolo un rato.
	for r in _rafagas:
		var t0: float = float(r["t0"]) * _dur
		var t1: float = t0 + float(r["largo"]) * _dur
		if _t < t0:
			continue
		var va: float = clampf((_t - t1) / 0.12, 0.0, 1.0)
		if va >= 1.0:
			continue
		var cab: Vector2 = _donde(minf(_t, t1)) + (r["off"] as Vector2)
		var col: Vector2 = _donde(t0) + (r["off"] as Vector2)
		BarridoAire.cometa(self, col, cab, float(r["ancho"]), Color(AIRE, 0.6 * (1.0 - va)))


# El POLVO de los pies: una bocanada al arrancar y otra al frenar, que se abren y se van.
func _dibujar_polvo() -> void:
	_bocanada(_de, _t)
	_bocanada(_a, _t - _dur)


func _bocanada(p: Vector2, t: float) -> void:
	if t < 0.0 or t > T_POLVO:
		return
	var k: float = t / T_POLVO
	var s: float = 1.0 - (1.0 - k) * (1.0 - k)
	var alfa: float = 0.5 * (1.0 - k)
	for i in 4:
		var ang: float = PI + (float(i) - 1.5) * 0.7 + (_a - _de).angle()
		var q: Vector2 = p + Vector2(cos(ang), sin(ang) * 0.6) * 9.0 * s + Vector2(0.0, -3.0 * s)
		BarridoAire.brillo(_suelo, q, 4.0 + 5.0 * s, Color(POLVO, alfa))
