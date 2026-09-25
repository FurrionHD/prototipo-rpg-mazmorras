# ============================================================
#  espada_aire.gd
#  LOS EFECTOS DE LA ESPADA CORTA en el mapa (25/09/2026, SEGUNDA VERSION). La primera eran medias lunas
#  sueltas sobre cada cuerpo, todas con la misma forma mirases desde donde mirases ("lamentables, no
#  mantienen perspectiva"). Esta copia lo que ya le gusto:
#    - LOS CONOS son UN barrido que cruza a todos (como el hacha y el Segar), en el aire alrededor de
#      quien pega y con la perspectiva del suelo. A cada uno le llega su golpe cuando el barrido le pasa.
#      Van por el camino del suelo (ficha 'suelo_roto', SueloRoto.lanzar, red, instante del golpe):
#        QUIEBRA   el Tajo quebrantador: un barrido ANCHO a la cintura, de lado a lado
#        CRUZ      el Doble tajo: ida BAJANDO y vuelta SUBIENDO, que se cruzan en X delante de ti
#        TENDON    el Corte de tendones: un barrido a RAS DEL SUELO que levanta tierra
#    - LO DE CADA CUERPO es la PINCELADA del basico del mandoble (BarridoAire.TAJO: "nivel dios"), en
#      diagonal hacia el lado al que golpeas y cruzando la de antes en cada golpe. Sale golpe a golpe
#      (CombatFX.dibujo_en_mapa -> CombatTactico._on_dibujo_mapa):
#        TAJO      la pincelada (el basico; los golpes de mas con dos espadas)
#        QUEBRANTADOR  en el golpe del barrido, la guardia que salta en pedazos; en los de mas, pincelada
#        DOBLE     nada en el cuerpo (lo pinta el barrido); a partir del tercer golpe, pincelada
#        RITMO     Cambio de ritmo: la pincelada TUMBADA, en la direccion en la que pasas
#        SENALAR   Señalar el hueco: dos pinceladas EXACTAS una encima de otra y la diana roja
#        TENDONES  en el golpe del barrido, polvo a los pies; en los de mas, pincelada baja
#  LA ESPADA LARGA (25/09) vive aqui tambien, copiando lo mismo:
#        DESARMA   el barrido del Tajo desarmante: a la altura del BRAZO, mas fino, y le llega a cada uno al pasar
#        PESADO    el Tajo pesado: la hoja CAE en vertical y el suelo se abre por la linea (la Hendedura del
#                  hacha, que le gusto, pero de acero: raja RECTA y limpia con un filo de luz azul que se apaga)
#        DESARME   (cuerpo) el tajo al brazo: pincelada corta y alta, choque de acero con chispas y un
#                  destello que sale despedido (el arma que suelta)
#        PESADO_C  (cuerpo) la pincelada casi vertical, mas larga y mas gorda
#  El basico de la espada larga es la pincelada de siempre (TAJO); la Guardia rota, el barrido QUIEBRA con
#  la guardia en pedazos (QUEBRANTADOR); la Estocada marcial, la de EstoqueAire.
#  Coordenadas de MUNDO; todo sale de una semilla. NADA DE LINEAS (efectos-sin-lineas).
# ============================================================
extends Node2D
class_name EspadaAire

# Los barridos (QUIEBRA..PESADO) van en el orden de SueloRoto.Tipo.ESPADA_*: no reordenar.
enum Modo { TAJO, QUEBRANTADOR, DOBLE, RITMO, SENALAR, TENDONES, QUIEBRA, CRUZ, TENDON, DESARMA, PESADO,
	DESARME, PESADO_C }

const T_BARRE := 0.15         # lo que tarda un barrido de punta a punta (lento al salir, rapidisimo al final)
const T_CLAVADO := 0.08       # lo que se queda entero al acabar (como el hachazo)
const T_APAGA_SECO := 0.1     # y se va DE GOLPE
const T_SUELO := 0.5          # lo que se queda la marca del suelo
const T_SUELO_APAGAR := 0.45
const COLA := deg_to_rad(110.0)   # la cola de la media luna (el hacha 95: esta es mas larga y fina)
const ACERO := Color(0.80, 0.84, 0.90)
const ACERO_AZUL := Color(0.45, 0.58, 0.82)
const OSCURO := SueloRoto.OSCURO
const LABIO := SueloRoto.LABIO
const T_ENTRE := BarridoAire.T_ENTRE   # entre los dos barridos del Doble tajo (CombatFX.T_ENCADENADO)
const T_APAGA := 0.22
const T_SALE := 0.05          # lo que tarda la pincelada en abrirse
const T_PEDAZOS := 0.4
const T_DIANA := 0.9
const T_POLVO := 0.45
const ALTO_TORSO := 14.0
const ALTO_CINTURA := 9.0     # el Quebrantador
const ALTO_SUELO := 2.0       # los Tendones
const GRAVEDAD := 380.0
const ALTO_BRAZO := 12.0      # el Tajo desarmante
const T_CAE := 0.07           # la caida del Tajo pesado (la de la Hendedura)
const T_RAJA := 0.12          # y lo que tarda el suelo en abrirse hasta el final (algo mas rapida: es acero)
const T_FILO := 0.22          # lo que tarda en apagarse el filo de luz de la raja
const T_CHOQUE := 0.35        # las chispas del choque de acero (Desarmante)

const BLANCO := BarridoAire.BLANCO
const AIRE := BarridoAire.AIRE
const GUARDIA := Color(0.72, 0.84, 1.0)
const DIANA := Color(1.0, 0.36, 0.26)
const DIANA_CLARA := Color(1.0, 0.82, 0.55)
const POLVO := SueloRoto.POLVO
const TIERRA := Color(0.45, 0.40, 0.33)
const Z_ENCIMA := Game.Z_PERSONAJES + 80

var modo: int = Modo.TAJO
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
# El golpe sobre un cuerpo.
var _caja: Rect2 = Rect2()
var _fallo: bool = false
var _crit: bool = false
var _n: int = 0
var _c: Vector2 = Vector2.ZERO
var _dir: Vector2 = Vector2.RIGHT     # de donde viene el golpe (del que pega al cuerpo)
var _trazo: Vector2 = Vector2.DOWN    # hacia donde baja la pincelada
var _largo: float = 24.0
var _borde_a: PackedFloat32Array = PackedFloat32Array()
var _borde_b: PackedFloat32Array = PackedFloat32Array()
var _motas: Array = []
var _pedazos: Array = []
var _suelo: Node2D = null
var _pies: Vector2 = Vector2.ZERO
# El barrido.
var forma: CombatFormas.Forma = null
var _centro: Vector2 = Vector2.ZERO
var _atras: Node2D = null
var _delante: Node2D = null
var _chispas: Array = []
var _tierra: Array = []
var _raja: PackedVector2Array = PackedVector2Array()   # Tajo pesado
var _piedras: Array = []
var _choque: Array = []    # Desarmante: chispas del choque {v, tam}
var _suelta: Dictionary = {}   # Desarmante: el destello del arma que sale despedida


# ------------------------------------------------------------
#  LOS BARRIDOS (por SueloRoto: la ficha dice cual)
# ------------------------------------------------------------
# 'espera' = segundos hasta el golpe. El barrido del Quebrantador y el de los Tendones EMPIEZAN en el golpe
# y le llegan a cada uno al pasar (retraso); los dos del Doble tajo acaban en sus golpes, como el Segar.
static func barrido(padre: Node, f: CombatFormas.Forma, m: int, semilla: int, espera: float) -> EspadaAire:
	if padre == null or f == null:
		return null
	var e := EspadaAire.new()
	e.modo = m
	e.forma = f
	e._rng.seed = semilla
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	# El Doble tajo acaba su primer barrido EN el golpe; el Tajo pesado cae antes de abrir el suelo.
	e._t = (T_BARRE if m == Modo.CRUZ else (T_CAE if m == Modo.PESADO else 0.0)) - espera * e._ritmo
	e.z_as_relative = false
	e.z_index = SueloRoto.Z_SUELO
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	return e


# CUANDO LE LLEGA a 'p' el golpe del barrido, en segundos desde el golpe (la misma cuenta que el dibujo).
static func retraso(m: int, f: CombatFormas.Forma, p: Vector2) -> float:
	if m == Modo.CRUZ or f == null:
		return 0.0
	var o: Vector2 = SueloRoto.origen_de(f)
	if m == Modo.PESADO:
		# El suelo se abre de donde cae la hoja hacia el final de la linea, a velocidad fija.
		return T_RAJA * clampf((p - o).dot(f.dir) / maxf(f.radio, 1.0), 0.0, 1.0)
	var mitad: float = deg_to_rad(f.apertura * 0.5)
	if mitad <= 0.001 or p.distance_squared_to(o) < 0.01:
		return 0.0
	var fr: float = clampf(angle_difference(f.dir.angle() - mitad, (p - o).angle()) / (2.0 * mitad), 0.0, 1.0)
	# La cabeza va a lerp(izq, der, s^2) (como el hachazo): le llega cuando s = sqrt(fr).
	return T_BARRE * sqrt(fr)


static func t_salir(m: int) -> float:
	match m:
		Modo.CRUZ: return 2.0 * T_ENTRE
		Modo.PESADO: return T_RAJA
	return T_BARRE


# ------------------------------------------------------------
#  UN GOLPE SOBRE UN CUERPO (como DagaAire.golpe)
# ------------------------------------------------------------
static func golpe(padre: Node, m: int, desde: Vector2, caja: Rect2, fallo: bool, crit: bool, n: int,
		semilla: int, espera: float, ritmo: float) -> EspadaAire:
	if padre == null:
		return null
	var e := EspadaAire.new()
	e.modo = m
	# Pasada por hash: con semillas seguidas (golpes de una misma accion) el primer numero al azar salia casi
	# igual y todos los cortes elegian el mismo lado.
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
	e._preparar_golpe()
	return e


func duracion() -> float:
	match modo:
		Modo.QUIEBRA, Modo.TENDON, Modo.DESARMA: return T_BARRE + T_SUELO + T_SUELO_APAGAR + 0.1
		Modo.PESADO: return T_CAE + T_RAJA + T_SUELO + T_SUELO_APAGAR + 0.1
		Modo.DESARME: return maxf(T_SALE + 0.08 + T_APAGA, T_CHOQUE + 0.25) + 0.1
		Modo.CRUZ: return T_ENTRE + T_BARRE + T_CLAVADO + T_APAGA_SECO + 0.3
		Modo.QUEBRANTADOR: return T_PEDAZOS + 0.4
		Modo.SENALAR: return (T_DIANA if _n == 1 else T_SALE + T_APAGA + 0.1) + 0.15
		Modo.TENDONES: return T_POLVO + 0.4
	return T_SALE + 0.08 + T_APAGA + 0.1


func _ready() -> void:
	if forma == null:
		return
	# EL BARRIDO: capas detras y delante del que pega (la estela le rodea de verdad).
	_centro = forma.origen
	_dir = forma.dir.normalized() if forma.dir.length_squared() > 0.0001 else Vector2.RIGHT
	_atras = _capa(Game.Z_PERSONAJES - 1)
	_delante = _capa(Game.Z_PERSONAJES + 80)
	for i in 18:
		_chispas.append({"t0": _rng.randf_range(0.0, T_BARRE * (2.0 if modo == Modo.CRUZ else 1.0)
			+ (T_ENTRE - T_BARRE if modo == Modo.CRUZ else 0.0)),
			"vel": _rng.randf_range(90.0, 170.0), "abre": _rng.randf_range(0.1, 0.7)})
	if modo == Modo.PESADO:
		# LA RAJA: casi recta (el acero corta limpio; la del hacha va quebrada), de donde cae la hoja al final.
		var ini: Vector2 = _centro + _dir * forma.radio * 0.2
		var fin: Vector2 = _centro + _dir * forma.radio * 0.98
		var nor: Vector2 = _dir.orthogonal()
		for i in 13:
			var s: float = float(i) / 12.0
			var lado: float = 0.0 if i == 0 or i == 12 else _rng.randf_range(-1.0, 1.0) * forma.ancho * 0.03
			_raja.append(ini.lerp(fin, s) + nor * lado)
		for i in 5:
			_piedras.append({"v": Vector2(_rng.randf_range(-22.0, 22.0), _rng.randf_range(-22.0, 22.0)) + _dir * 18.0,
				"vz": _rng.randf_range(40.0, 75.0), "tam": _rng.randf_range(1.3, 2.3)})
	if modo == Modo.TENDON:
		for i in 14:
			var u: float = (float(i) + _rng.randf_range(0.0, 1.0)) / 14.0
			_tierra.append({"u": u, "r": forma.radio * _rng.randf_range(0.45, 0.95),
				"v": Vector2(_rng.randf_range(15.0, 35.0), _rng.randf_range(35.0, 75.0)),
				"tam": _rng.randf_range(1.2, 2.4)})


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
	if _atras != null:
		_atras.queue_redraw()
		_delante.queue_redraw()
	if _suelo != null:
		_suelo.queue_redraw()


# ------------------------------------------------------------
#  EL BARRIDO
# ------------------------------------------------------------
func _dibujar_capa(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var mitad: float = deg_to_rad(forma.apertura * 0.5)
	var izq: float = _dir.angle() - mitad
	var der: float = _dir.angle() + mitad
	var r: float = forma.radio
	match modo:
		Modo.PESADO:
			_caida(capa)
		Modo.DESARMA:
			# A la altura del BRAZO y mas fino que el del Quebrantador: busca el brazo, no el cuerpo.
			_barrido(capa, 0.0, izq, der, r * 0.95, r * 0.4, func(_a: float) -> float: return ALTO_BRAZO, 16.0)
			_chispas_barrido(capa, r * 0.95, func(t: float) -> float:
				return lerpf(izq, der, pow(clampf(t / T_BARRE, 0.0, 1.0), 2.0)),
				func(_a: float) -> float: return ALTO_BRAZO)
		Modo.QUIEBRA, Modo.TENDON:
			var alto: float = ALTO_CINTURA if modo == Modo.QUIEBRA else ALTO_SUELO
			_barrido(capa, 0.0, izq, der, r * 0.95, r * (0.55 if modo == Modo.QUIEBRA else 0.42),
				func(_a: float) -> float: return alto, 20.0 if modo == Modo.QUIEBRA else 15.0)
			_chispas_barrido(capa, r * 0.95, func(t: float) -> float:
				return lerpf(izq, der, pow(clampf(t / T_BARRE, 0.0, 1.0), 2.0)),
				func(_a: float) -> float: return alto)
			if modo == Modo.TENDON:
				_dibujar_tierra(capa, izq, der)
		Modo.CRUZ:
			# Ida BAJANDO (de la cabeza a las rodillas) y vuelta SUBIENDO: delante de ti se cruzan en X.
			for k in 2:
				var desde: float = izq if k == 0 else der
				var hasta: float = der if k == 0 else izq
				var alto_de := func(a: float) -> float:
					var u: float = clampf((a - desde) / (hasta - desde), 0.0, 1.0)
					return lerpf(18.0, 2.0, u) if k == 0 else lerpf(2.0, 18.0, u)
				_barrido(capa, float(k) * T_ENTRE, desde, hasta, r * 0.92, r * 0.42, alto_de, 16.0)


# UN BARRIDO del hachazo (HachaAire._barrido): de 'desde' a 'hasta' empezando en 't0' (s^2: lento al salir,
# rapidisimo al final), se queda CLAVADO un instante con la cola recogiendose y se apaga de golpe. Destello
# al clavarse. 'alto_de' = Callable(angulo) -> altura del filo ahi.
func _barrido(capa: Node2D, t0: float, desde: float, hasta: float, r: float, grueso: float, alto_de: Callable,
		destello_r: float) -> void:
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
	_mordisco(capa, cola, cabeza, r, grueso, alto_de, 0.95 * (1.0 - apaga))
	var h: float = float(alto_de.call(cabeza))
	var p: Vector2 = _en_arco(cabeza, r, h)
	if _es_mia(capa, p, h):
		var pulso: float = exp(-absf(tc) / 0.04)
		BarridoAire.destello(capa, p, destello_r * (0.3 + 0.9 * pulso), Color(BLANCO, (1.0 - apaga) * (0.5 + 0.5 * pulso)),
			_t * 2.0)


# LA MEDIA LUNA (copia de HachaAire._mordisco): la CABEZA gorda que se corta en seco, fina hacia la cola. De
# fuera hacia dentro: el filo blanco y duro, acero, un velo AZUL ACERO (el del hacha es rojo) y nada.
func _mordisco(capa: Node2D, a_cola: float, a_cabeza: float, r: float, grueso: float, alto_de: Callable,
		alfa: float) -> void:
	if alfa <= 0.0 or absf(a_cabeza - a_cola) < 0.01:
		return
	var n: int = maxi(8, int(absf(a_cabeza - a_cola) / 0.06))
	var fr: Array = [0.0, 0.1, 0.38, 0.72, 1.0]
	var cols: Array = [BLANCO, ACERO, ACERO_AZUL, ACERO_AZUL, ACERO_AZUL]
	var al: Array = [1.0, 0.95, 0.6, 0.28, 0.0]
	for i in n:
		var s0: float = float(i) / float(n)
		var s1: float = float(i + 1) / float(n)
		var a0: float = lerpf(a_cola, a_cabeza, s0)
		var a1: float = lerpf(a_cola, a_cabeza, s1)
		var h0: float = float(alto_de.call(a0))
		var h1: float = float(alto_de.call(a1))
		if not _es_mia(capa, _en_arco((a0 + a1) * 0.5, r, (h0 + h1) * 0.5), (h0 + h1) * 0.5):
			continue
		var g0: float = grueso * (0.1 + 0.9 * pow(s0, 1.4))
		var g1: float = grueso * (0.1 + 0.9 * pow(s1, 1.4))
		var l0: float = alfa * (0.3 + 0.7 * s0)
		var l1: float = alfa * (0.3 + 0.7 * s1)
		for k in fr.size() - 1:
			var p00: Vector2 = _en_arco(a0, r - g0 * float(fr[k]), h0)
			var p10: Vector2 = _en_arco(a1, r - g1 * float(fr[k]), h1)
			var p01: Vector2 = _en_arco(a0, r - g0 * float(fr[k + 1]), h0)
			var p11: Vector2 = _en_arco(a1, r - g1 * float(fr[k + 1]), h1)
			var c00 := Color(cols[k], l0 * float(al[k]))
			var c10 := Color(cols[k], l1 * float(al[k]))
			var c01 := Color(cols[k + 1], l0 * float(al[k + 1]))
			var c11 := Color(cols[k + 1], l1 * float(al[k + 1]))
			capa.draw_primitive(PackedVector2Array([p00, p10, p11]), PackedColorArray([c00, c10, c11]), PackedVector2Array())
			capa.draw_primitive(PackedVector2Array([p00, p11, p01]), PackedColorArray([c00, c11, c01]), PackedVector2Array())


# LA MARCA EN EL SUELO del barrido (HachaAire._tajo_arco/_gasa): oscura en el centro con el labio claro por
# fuera, afilada en las puntas. Se queda un rato y se va.
func _marca_suelo(a0: float, a1: float, r: float, ancho: float, alfa: float) -> void:
	if alfa <= 0.0 or absf(a1 - a0) < 0.02:
		return
	var n: int = maxi(6, int(absf(a1 - a0) / 0.07))
	var pts := PackedVector2Array()
	for i in n + 1:
		var a: float = lerpf(a0, a1, float(i) / float(n))
		pts.append(_centro + Vector2(cos(a), sin(a)) * r)
	for capa_i in 2:
		var w_k: float = 2.2 if capa_i == 0 else 1.0
		for i in n:
			var s0: float = float(i) / float(n)
			var s1: float = float(i + 1) / float(n)
			var d: Vector2 = (pts[i + 1] - pts[i]).normalized().orthogonal()
			var w0: float = ancho * w_k * pow(sin(PI * s0), 0.6)
			var w1: float = ancho * w_k * pow(sin(PI * s1), 0.6)
			if capa_i == 0:
				var cl := Color(LABIO, 0.45 * alfa)
				var trl := Color(LABIO, 0.0)
				for lado in [1.0, -1.0]:
					var q0: Vector2 = pts[i] + d * w0 * 0.4 * lado
					var q1: Vector2 = pts[i + 1] + d * w1 * 0.4 * lado
					var e0: Vector2 = pts[i] + d * w0 * lado
					var e1: Vector2 = pts[i + 1] + d * w1 * lado
					draw_primitive(PackedVector2Array([q0, q1, e1]), PackedColorArray([cl, cl, trl]), PackedVector2Array())
					draw_primitive(PackedVector2Array([q0, e1, e0]), PackedColorArray([cl, trl, trl]), PackedVector2Array())
			else:
				var co := Color(OSCURO, 0.85 * alfa)
				draw_primitive(PackedVector2Array([pts[i] + d * w0 * 0.45, pts[i + 1] + d * w1 * 0.45,
					pts[i + 1] - d * w1 * 0.45]), PackedColorArray([co, co, co]), PackedVector2Array())
				draw_primitive(PackedVector2Array([pts[i] + d * w0 * 0.45, pts[i + 1] - d * w1 * 0.45,
					pts[i] - d * w0 * 0.45]), PackedColorArray([co, co, co]), PackedVector2Array())


# LA CAIDA del Tajo pesado (copia de HachaAire._hendedura): una media luna en VERTICAL que baja sobre donde
# empieza la raja, mas alta que la del hacha (la hoja es larga), con el velo azul acero detras del filo.
func _caida(capa: Node2D) -> void:
	if capa != _delante or _raja.is_empty():
		return
	var ini: Vector2 = _raja[0]
	var alto_ini: float = 52.0
	var s: float = clampf(_t / T_CAE, 0.0, 1.0)
	s = s * s
	var apaga: float = clampf((_t - T_CAE - 0.04) / 0.1, 0.0, 1.0)
	if apaga >= 1.0:
		return
	var alfa: float = 0.95 * (1.0 - apaga)
	var s_cola: float = maxf(0.0, s - 0.65)
	var n: int = 12
	var curva: Vector2 = _dir * 5.0   # un pelo curvada hacia donde abre el suelo
	var ancho_d: Vector2 = Vector2(1.0, 0.0)
	for i in n:
		var u0: float = lerpf(s_cola, s, float(i) / float(n))
		var u1: float = lerpf(s_cola, s, float(i + 1) / float(n))
		var p0: Vector2 = ini + Vector2(0.0, -alto_ini * (1.0 - u0)) + curva * sin(PI * u0)
		var p1: Vector2 = ini + Vector2(0.0, -alto_ini * (1.0 - u1)) + curva * sin(PI * u1)
		var k0: float = float(i) / float(n)
		var k1: float = float(i + 1) / float(n)
		var w0: float = 12.0 * (0.15 + 0.85 * k0)
		var w1: float = 12.0 * (0.15 + 0.85 * k1)
		# El filo blanco por delante (hacia donde abre) y el velo azul acero por detras.
		var c0 := Color(BLANCO, alfa * (0.2 + 0.8 * k0))
		var c1 := Color(BLANCO, alfa * (0.2 + 0.8 * k1))
		var v0 := Color(ACERO_AZUL, alfa * 0.5 * k0)
		var v1 := Color(ACERO_AZUL, alfa * 0.5 * k1)
		var tr := Color(ACERO_AZUL, 0.0)
		capa.draw_primitive(PackedVector2Array([p0 + ancho_d * w0 * 0.5, p1 + ancho_d * w1 * 0.5, p1]),
			PackedColorArray([c0, c1, v1]), PackedVector2Array())
		capa.draw_primitive(PackedVector2Array([p0 + ancho_d * w0 * 0.5, p1, p0]),
			PackedColorArray([c0, v1, v0]), PackedVector2Array())
		capa.draw_primitive(PackedVector2Array([p0, p1, p1 - ancho_d * w1 * 0.5]),
			PackedColorArray([v0, v1, tr]), PackedVector2Array())
		capa.draw_primitive(PackedVector2Array([p0, p1 - ancho_d * w1 * 0.5, p0 - ancho_d * w0 * 0.5]),
			PackedColorArray([v0, tr, tr]), PackedVector2Array())
	var pulso: float = exp(-absf(_t - T_CAE) / 0.04)
	BarridoAire.destello(capa, ini, 7.0 + 16.0 * pulso, Color(BLANCO, alfa * pulso), 0.2)
	# Las piedras que salta el final del corte.
	var tp: float = _t - T_CAE - T_RAJA
	if tp > 0.0:
		for p in _piedras:
			var z: float = float(p["vz"]) * tp - SueloRoto.GRAVEDAD_PIEDRAS * tp * tp
			if z < 0.0:
				continue
			var q: Vector2 = _raja[_raja.size() - 1] + (p["v"] as Vector2) * tp + Vector2(0.0, -z * SueloRoto.K_ALTO)
			var tam: float = float(p["tam"])
			capa.draw_rect(Rect2(q - Vector2(tam, tam) * 0.5, Vector2(tam, tam)), TIERRA)


# LA RAJA del Tajo pesado (copia de HachaAire._dibujar_raja): el frente corre a velocidad fija y se para en
# seco; cada trozo se abre un poco despues de que pase. Encima, mientras se abre, un FILO DE LUZ azul por el
# fondo del corte que se apaga enseguida (lo que la distingue de la del hacha: es acero, no un tajo sucio).
func _dibujar_raja() -> void:
	var tr: float = _t - T_CAE
	if tr < 0.0 or _raja.size() < 2:
		return
	var alfa: float = 1.0 - clampf((tr - T_RAJA - T_SUELO) / T_SUELO_APAGAR, 0.0, 1.0)
	if alfa <= 0.0:
		return
	var frente: float = clampf(tr / T_RAJA, 0.0, 1.0)
	var n: int = _raja.size() - 1
	var w_max: float = maxf(forma.ancho, 8.0) * 0.32
	var luz: float = 1.0 - clampf((tr - T_RAJA) / T_FILO, 0.0, 1.0)
	for i in n:
		var s0: float = float(i) / float(n)
		var s1: float = float(i + 1) / float(n)
		if s0 >= frente:
			break
		var p0: Vector2 = _raja[i]
		var p1: Vector2 = _raja[i + 1] if s1 <= frente else _raja[i].lerp(_raja[i + 1], (frente - s0) / (s1 - s0))
		var abre0: float = clampf((tr - s0 * T_RAJA) / 0.1, 0.0, 1.0)
		var abre1: float = clampf((tr - s1 * T_RAJA) / 0.1, 0.0, 1.0)
		# Mas ancha en medio que en las puntas: un corte, no una zanja.
		var w0: float = w_max * (0.35 + 0.65 * sin(PI * clampf(s0 * 0.9 + 0.05, 0.0, 1.0))) * (0.25 + 0.75 * abre0)
		var w1: float = w_max * (0.35 + 0.65 * sin(PI * clampf(s1 * 0.9 + 0.05, 0.0, 1.0))) * (0.25 + 0.75 * abre1)
		var d: Vector2 = (p1 - p0).normalized().orthogonal() if p1.distance_squared_to(p0) > 0.001 else _dir.orthogonal()
		var cl := Color(LABIO, 0.5 * alfa)
		var trc := Color(LABIO, 0.0)
		for lado in [1.0, -1.0]:
			draw_primitive(PackedVector2Array([p0 + d * w0 * 0.5 * lado, p1 + d * w1 * 0.5 * lado, p1 + d * (w1 * 0.5 + 2.0) * lado]),
				PackedColorArray([cl, cl, trc]), PackedVector2Array())
			draw_primitive(PackedVector2Array([p0 + d * w0 * 0.5 * lado, p1 + d * (w1 * 0.5 + 2.0) * lado, p0 + d * (w0 * 0.5 + 2.0) * lado]),
				PackedColorArray([cl, trc, trc]), PackedVector2Array())
		var co := Color(OSCURO, 0.9 * alfa)
		draw_primitive(PackedVector2Array([p0 + d * w0 * 0.5, p1 + d * w1 * 0.5, p1 - d * w1 * 0.5]),
			PackedColorArray([co, co, co]), PackedVector2Array())
		draw_primitive(PackedVector2Array([p0 + d * w0 * 0.5, p1 - d * w1 * 0.5, p0 - d * w0 * 0.5]),
			PackedColorArray([co, co, co]), PackedVector2Array())
		# EL FILO DE LUZ por el fondo: blanco en el eje, azul hacia los labios, y se apaga.
		if luz > 0.0:
			var cb := Color(BLANCO, 0.9 * luz * alfa)
			var ca := Color(ACERO_AZUL, 0.0)
			for lado2 in [1.0, -1.0]:
				draw_primitive(PackedVector2Array([p0, p1, p1 + d * w1 * 0.45 * lado2]),
					PackedColorArray([cb, cb, ca]), PackedVector2Array())
				draw_primitive(PackedVector2Array([p0, p1 + d * w1 * 0.45 * lado2, p0 + d * w0 * 0.45 * lado2]),
					PackedColorArray([cb, ca, ca]), PackedVector2Array())
	# Donde cae la hoja, polvo; y en el tope, polvo hacia delante.
	if tr < 0.45:
		var k: float = tr / 0.45
		BarridoAire.brillo(self, _raja[0], 6.0 + 8.0 * k, Color(POLVO, 0.45 * (1.0 - k)))
	var tt: float = tr - T_RAJA
	if tt >= 0.0 and tt < 0.5:
		var k2: float = tt / 0.5
		BarridoAire.brillo(self, _raja[n] + _dir * 5.0 * sqrt(k2), 5.0 + 7.0 * k2, Color(POLVO, 0.5 * (1.0 - k2)))


# Un punto del arco alrededor de quien pega, a 'alto' px de pantalla sobre el suelo.
func _en_arco(a: float, r: float, alto: float) -> Vector2:
	return _centro + Vector2(cos(a), sin(a)) * r + Vector2(0.0, -alto)


func _es_mia(capa: Node2D, p: Vector2, alto: float) -> bool:
	return (p.y < _centro.y - alto) == (capa == _atras)


# Las chispas que suelta la punta al pasar (BarridoAire._chispas).
func _chispas_barrido(capa: Node2D, r: float, cabeza_en: Callable, alto_de: Callable) -> void:
	for ch in _chispas:
		var t0: float = float(ch["t0"])
		var tp: float = _t - t0
		if tp < 0.0 or tp > 0.2 or t0 > T_BARRE:
			continue
		var a: float = float(cabeza_en.call(t0))
		var h: float = float(alto_de.call(a))
		var tang: Vector2 = Vector2(-sin(a), cos(a))
		var v: Vector2 = (tang + Vector2(cos(a), sin(a)) * float(ch["abre"])).normalized() * float(ch["vel"])
		var p0: Vector2 = _en_arco(a, r * 0.97, h) + v * tp
		if not _es_mia(capa, p0, h):
			continue
		BarridoAire.cometa(capa, p0 - v.normalized() * 6.0, p0, 1.6, Color(BLANCO, 0.9 * (1.0 - tp / 0.2)))


# La tierra que salta al paso del barrido bajo (como la del Segar).
func _dibujar_tierra(capa: Node2D, izq: float, der: float) -> void:
	for m in _tierra:
		var u: float = float(m["u"])
		var cuando: float = T_BARRE * sqrt(u)
		var tp: float = _t - cuando
		if tp < 0.0 or tp > 0.45:
			continue
		var ang: float = lerpf(izq, der, u)
		var v: Vector2 = m["v"]
		var z: float = v.y * tp - SueloRoto.GRAVEDAD_PIEDRAS * tp * tp
		if z < 0.0:
			continue
		var p2: Vector2 = _centro + Vector2(cos(ang), sin(ang)) * (float(m["r"]) + v.x * tp) \
			+ Vector2(0.0, -z * SueloRoto.K_ALTO)
		if not _es_mia(capa, p2, 0.0):
			continue
		var tam: float = float(m["tam"])
		capa.draw_rect(Rect2(p2 - Vector2(tam, tam) * 0.5, Vector2(tam, tam)), TIERRA)


# ------------------------------------------------------------
#  LA PINCELADA (copia del basico del mandoble: BarridoAire._tajo_basico)
# ------------------------------------------------------------
func _preparar_golpe() -> void:
	var alto: float = _caja.size.y if _caja.has_area() else 24.0
	_largo = clampf(alto * 0.9, 16.0, 28.0)
	# EL ANGULO DEL CORTE, con la perspectiva de la camara (25/09: "sale siempre igual en las 5 direcciones").
	# La hoja cruza el cuerpo DE LADO respecto a quien pega: ese lado es la perpendicular al golpe en el suelo
	# (y el suelo, a 45 grados, se ve achatado en vertical: PlazaSprites.K), con un pelo de fondo hacia el
	# golpe para que de E u O no se quede en una raya vertical. A eso se le suma lo que BAJA la hoja
	# (la inclinacion del tajo), distinta en cada golpe. Asi cada direccion de ataque da su corte.
	const K := 0.7071
	var lateral: Vector2 = Vector2(-_dir.y, _dir.x * K) + Vector2(_dir.x, _dir.y * K) * 0.35
	lateral = lateral.normalized() if lateral.length_squared() > 0.001 else Vector2.RIGHT
	# De que lado entra: al azar el primero y CRUZANDO el anterior en cada golpe (dos espadas: una X).
	var lado: float = 1.0 if _rng.randf() < 0.5 else -1.0
	if _n % 2 == 1:
		lado = -lado
	# Cuanto baja: de tajo casi tumbado (15º) a casi vertical (72º), cada golpe el suyo.
	var baja: float = deg_to_rad(_rng.randf_range(15.0, 72.0))
	match modo:
		Modo.RITMO:
			baja = deg_to_rad(_rng.randf_range(8.0, 20.0))   # pasas de largo: el tajo va tumbado
			_largo *= 1.15
		Modo.SENALAR:
			# LAS DOS EN EL MISMO SITIO: lado e inclinacion salen del cuerpo, no del golpe ni de la semilla.
			var h: float = fposmod(_caja.position.x * 0.37 + _caja.position.y * 0.61, 2.0)
			lado = 1.0 if h < 1.0 else -1.0
			baja = deg_to_rad(30.0 + 25.0 * fposmod(h, 1.0))
		Modo.TENDONES:
			# La de mas (dos espadas), baja y casi plana, a las piernas.
			baja = deg_to_rad(_rng.randf_range(4.0, 12.0))
			_c = Vector2(_c.x, (_caja.end.y - alto * 0.18) if _caja.has_area() else _c.y + 8.0)
		Modo.DESARME:
			# Al BRAZO: corta, poco inclinada y alta, del lado por el que entra.
			baja = deg_to_rad(_rng.randf_range(10.0, 30.0))
			_largo *= 0.75
			_c += Vector2(0.0, -alto * 0.12) + lateral * lado * 3.0
		Modo.PESADO_C:
			# De arriba abajo con todo el peso: casi vertical, larga.
			baja = deg_to_rad(_rng.randf_range(76.0, 86.0))
			_largo = clampf(alto * 1.15, 20.0, 34.0)
	_trazo = (lateral * lado * cos(baja) + Vector2(0.0, 1.0) * sin(baja)).normalized()
	if _fallo:
		_c += Vector2((1.0 if _rng.randf() < 0.5 else -1.0) * (_caja.size.x * 0.75 + 4.0), 0.0)
	# Semilla propia de la pincelada: en el Señalar, la misma en los dos golpes (salen identicas).
	var rp := RandomNumberGenerator.new()
	rp.seed = int(_caja.position.x * 13.0 + _caja.position.y * 7.0) if modo == Modo.SENALAR else _rng.seed + 11
	for i in 25:
		_borde_a.append(rp.randf_range(0.75, 1.2))
		_borde_b.append(rp.randf_range(0.75, 1.2))
	for _k in 2:
		_borde_a[rp.randi_range(4, 20)] *= 0.45
	for _k in 4:
		_motas.append({"s": rp.randf_range(0.05, 0.95), "off": rp.randf_range(-7.0, 7.0), "tam": rp.randf_range(0.8, 1.8)})
	if modo == Modo.QUEBRANTADOR and _n == 0 and not _fallo:
		# Los PEDAZOS de la guardia: una placa delante del cuerpo que salta hacia atras y a los lados.
		var placa: Vector2 = _placa()
		var lado_p: Vector2 = _dir.orthogonal()
		for i in 5:
			var u: float = (float(i) / 4.0) * 2.0 - 1.0
			_pedazos.append({"p": placa + lado_p * u * 9.0 + Vector2(0.0, _rng.randf_range(-6.0, 6.0)),
				"v": _dir * _rng.randf_range(40.0, 95.0) + lado_p * u * _rng.randf_range(30.0, 70.0)
					+ Vector2(0.0, -_rng.randf_range(30.0, 80.0)),
				"tam": _rng.randf_range(2.2, 4.0), "giro": _rng.randf() * TAU, "gira": _rng.randf_range(-14.0, 14.0)})
	if modo == Modo.DESARME and not _fallo:
		# EL CHOQUE DE ACERO: chispas que salen del brazo hacia fuera (del lado contrario a quien pega) y el
		# arma del enemigo, un destello alargado que sale despedido girando y cae.
		for i in 9:
			var a: float = _dir.angle() + _rng.randf_range(-1.1, 1.1)
			_choque.append({"v": Vector2(cos(a), sin(a) * 0.7) * _rng.randf_range(70.0, 150.0)
				+ Vector2(0.0, -_rng.randf_range(10.0, 50.0)), "tam": _rng.randf_range(1.3, 2.2)})
		_suelta = {"v": (_dir + lateral * lado * 0.8).normalized() * _rng.randf_range(45.0, 65.0)
			+ Vector2(0.0, -_rng.randf_range(70.0, 95.0)), "giro": _rng.randf() * TAU,
			"gira": _rng.randf_range(12.0, 18.0) * lado}
	if modo == Modo.TENDONES and _n == 0:
		_suelo = Node2D.new()
		_suelo.z_as_relative = false
		_suelo.z_index = SueloRoto.Z_SUELO
		add_child(_suelo)
		_suelo.draw.connect(_dibujar_polvo)


func _placa() -> Vector2:
	var h: float = (_caja.size.x * 0.5) if _caja.has_area() else 8.0
	return _caja.get_center() - _dir * (h + 2.0)


func _con_pincelada() -> bool:
	match modo:
		Modo.QUEBRANTADOR, Modo.TENDONES: return _n >= 1
		Modo.DOBLE: return _n >= 2
	return true


func _draw() -> void:
	if forma != null:
		if modo == Modo.PESADO:
			_dibujar_raja()
			return
		# EL BARRIDO: aqui solo su marca en el suelo (lo del aire va en sus capas). El Doble tajo no la deja:
		# va por el aire, a la altura del pecho; el Desarmante, una muy fina (va alto, al brazo).
		if modo != Modo.CRUZ and _t >= 0.0:
			var mitad: float = deg_to_rad(forma.apertura * 0.5)
			var izq: float = _dir.angle() - mitad
			var hasta: float = lerpf(izq, izq + 2.0 * mitad, pow(clampf(_t / T_BARRE, 0.0, 1.0), 2.0))
			var tv: float = _t - T_BARRE
			var alfa_s: float = 1.0 - clampf((tv - T_SUELO) / T_SUELO_APAGAR, 0.0, 1.0)
			match modo:
				Modo.QUIEBRA: _marca_suelo(izq, hasta, forma.radio * 0.78, 1.6, alfa_s)
				Modo.DESARMA: _marca_suelo(izq, hasta, forma.radio * 0.8, 0.9, alfa_s * 0.6)
				_: _marca_suelo(izq, hasta, forma.radio * 0.72, 2.4, alfa_s)
		return
	if _con_pincelada():
		var grueso: float = 1.0
		if modo == Modo.SENALAR and _n == 1:
			grueso = 1.25
		elif modo == Modo.PESADO_C:
			grueso = 1.4
		_pincelada(grueso)
	match modo:
		Modo.QUEBRANTADOR: _dibujar_guardia()
		Modo.SENALAR: _dibujar_diana()
		Modo.DESARME: _dibujar_choque()


func _punto(s: float, lado: float) -> Vector2:
	var nor: Vector2 = Vector2(-_trazo.y, _trazo.x)
	return _c + _trazo * (s - 0.5) * _largo + nor * (sin(PI * s) * _largo * 0.07 + lado)


# UN CORTE SOBRE EL CUERPO: un solo trazo, afilado en las puntas y mas grueso en medio, bordes rotos y
# alguna mota. 'grueso' lo engorda (la segunda del Señalar, encima de la primera).
func _pincelada(grueso: float) -> void:
	if _t < 0.0:
		return
	var sale: float = clampf(_t / T_SALE, 0.0, 1.0)
	var apaga: float = clampf((_t - T_SALE - 0.08) / T_APAGA, 0.0, 1.0)
	var alfa: float = (0.45 if _fallo else 1.0) * (1.0 - apaga)
	if alfa <= 0.0:
		return
	var n: int = _borde_a.size() - 1
	var fino: float = 1.0 - 0.5 * apaga
	for capa_i in 2:
		var ancho_k: float = (1.7 if capa_i == 0 else 1.0) * grueso
		var col: Color = Color(AIRE, 0.25 * alfa) if capa_i == 0 else Color(BLANCO, 0.95 * alfa)
		for i in n:
			var s0: float = float(i) / float(n)
			var s1: float = float(i + 1) / float(n)
			if s1 > sale:
				break
			var w0: float = 1.5 * pow(sin(PI * s0), 1.3) * ancho_k * fino
			var w1: float = 1.5 * pow(sin(PI * s1), 1.3) * ancho_k * fino
			var a0: Vector2 = _punto(s0, w0 * _borde_a[i])
			var a1: Vector2 = _punto(s1, w1 * _borde_a[i + 1])
			var b0: Vector2 = _punto(s0, -w0 * _borde_b[i])
			var b1: Vector2 = _punto(s1, -w1 * _borde_b[i + 1])
			var cols := PackedColorArray([col, col, col])
			draw_primitive(PackedVector2Array([a0, a1, b1]), cols, PackedVector2Array())
			draw_primitive(PackedVector2Array([a0, b1, b0]), cols, PackedVector2Array())
	for m in _motas:
		if float(m["s"]) > sale:
			continue
		var p: Vector2 = _punto(float(m["s"]), float(m["off"]) * (1.0 + apaga))
		var tam: float = float(m["tam"])
		draw_rect(Rect2(p - Vector2(tam, tam) * 0.5, Vector2(tam, tam)), Color(BLANCO, 0.8 * alfa))
	if not _fallo:
		var pulso: float = exp(-_t / 0.05)
		if pulso > 0.05:
			BarridoAire.destello(self, _c, (5.0 if not _crit else 8.0) + 7.0 * pulso, Color(BLANCO, 0.85 * pulso), 0.4)


# LA GUARDIA QUE SE ROMPE (Quebrantador, en el golpe del barrido): un destello azulado delante del cuerpo y
# los pedazos, cuñas de luz que giran y caen.
func _dibujar_guardia() -> void:
	if _fallo or _pedazos.is_empty() or _t < 0.0:
		return
	var placa: Vector2 = _placa()
	var kf: float = clampf(_t / 0.12, 0.0, 1.0)
	BarridoAire.brillo(self, placa, 10.0 + 12.0 * kf, Color(GUARDIA, 0.55 * (1.0 - kf)))
	BarridoAire.destello(self, placa, 12.0 * (1.0 - kf * 0.5), Color(BLANCO, 1.0 - kf), _dir.angle())
	for pz in _pedazos:
		var q: Vector2 = (pz["p"] as Vector2) + (pz["v"] as Vector2) * _t + Vector2(0.0, 0.5 * GRAVEDAD * _t * _t)
		var a: float = float(pz["giro"]) + float(pz["gira"]) * _t
		var s: float = float(pz["tam"])
		var alfa: float = clampf(1.0 - _t / T_PEDAZOS, 0.0, 1.0)
		var d := Vector2(cos(a), sin(a))
		var nn: Vector2 = d.orthogonal() * s * 0.45
		draw_primitive(PackedVector2Array([q - d * s, q + nn, q + d * s * 0.8, q - nn]),
			PackedColorArray([Color(GUARDIA, alfa * 0.5), Color(BLANCO, alfa), Color(GUARDIA, alfa * 0.8),
				Color(BLANCO, alfa)]), PackedVector2Array())


# EL CHOQUE DE ACERO del Desarmante: un destello duro sobre el brazo, las chispas (cometas que caen) y el
# arma del enemigo que sale despedida: una cuña de luz alargada que gira, sube y cae apagandose.
func _dibujar_choque() -> void:
	if _fallo or _t < 0.0 or _choque.is_empty():
		return
	var pulso: float = exp(-_t / 0.05)
	if pulso > 0.05:
		BarridoAire.destello(self, _c, 9.0 + 9.0 * pulso, Color(BLANCO, pulso), _t * 3.0 + 0.6)
	for ch in _choque:
		if _t > T_CHOQUE:
			break
		var v: Vector2 = ch["v"]
		var q: Vector2 = _c + v * _t + Vector2(0.0, 0.5 * GRAVEDAD * _t * _t)
		var vel: Vector2 = v + Vector2(0.0, GRAVEDAD * _t)
		var k: float = 1.0 - _t / T_CHOQUE
		BarridoAire.cometa(self, q - vel.normalized() * 5.0 * float(ch["tam"]), q, float(ch["tam"]),
			Color(Color(1.0, 0.93, 0.7), 0.95 * k))
	var ts: float = _t
	if ts < 0.55 and not _suelta.is_empty():
		var q2: Vector2 = _c + (_suelta["v"] as Vector2) * ts + Vector2(0.0, 0.5 * GRAVEDAD * ts * ts)
		var a: float = float(_suelta["giro"]) + float(_suelta["gira"]) * ts
		var d := Vector2(cos(a), sin(a))
		var nn: Vector2 = d.orthogonal() * 1.6
		var alfa: float = clampf(1.0 - (ts - 0.35) / 0.2, 0.0, 1.0)
		draw_primitive(PackedVector2Array([q2 - d * 7.0, q2 + nn, q2 + d * 7.0, q2 - nn]),
			PackedColorArray([Color(ACERO, 0.2 * alfa), Color(BLANCO, alfa), Color(ACERO, 0.6 * alfa),
				Color(BLANCO, alfa)]), PackedVector2Array())
		BarridoAire.brillo(self, q2 + d * 5.0, 3.0, Color(BLANCO, 0.6 * alfa))


# LA DIANA del segundo corte (le gusto: "el efecto rojo esta guapo"): un anillo que se cierra sobre el corte,
# un punto en medio y cuatro cuñas apuntando dentro. Se queda puesta, late y se va sola.
func _dibujar_diana() -> void:
	if _fallo or _n != 1 or _t < 0.0:
		return
	var cierra: float = 1.0 - pow(1.0 - clampf(_t / 0.12, 0.0, 1.0), 2.0)
	var va: float = clampf((_t - (T_DIANA - 0.25)) / 0.25, 0.0, 1.0)
	var late: float = 0.85 + 0.15 * sin(_t * 14.0)
	var alfa: float = (1.0 - va) * minf(_t / 0.05, 1.0)
	var r: float = lerpf(_largo * 1.3, _largo * 0.6, cierra) * late
	_anillo(_c, r, 2.6, Color(DIANA, 0.85 * alfa))
	_anillo(_c, r * 0.45, 1.8, Color(DIANA_CLARA, 0.6 * alfa))
	BarridoAire.brillo(self, _c, 3.5, Color(DIANA_CLARA, alfa))
	for j in 4:
		var a: float = PI * 0.5 * float(j) + PI * 0.25
		var d := Vector2(cos(a), sin(a))
		BarridoAire.cometa(self, _c + d * (r + 7.0), _c + d * (r + 1.0), 2.4, Color(DIANA, 0.9 * alfa))


# Un anillo relleno, opaco en medio del grosor y transparente a los dos bordes (no una raya).
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


# EL POLVO a los pies (Tendones, en el golpe del barrido): el cuerpo cede y levanta tierra a los lados.
func _dibujar_polvo() -> void:
	if _fallo or _t < 0.0:
		return
	var k: float = clampf(_t / T_POLVO, 0.0, 1.0)
	for s in [-1.0, 1.0]:
		for j in 3:
			var q: Vector2 = _pies + Vector2(s * (4.0 + 14.0 * k * (0.6 + 0.3 * float(j))), -2.0 - 3.0 * float(j) * k)
			BarridoAire.brillo(_suelo, q, 5.0 + 6.0 * k, Color(POLVO, 0.6 * (1.0 - k)))
