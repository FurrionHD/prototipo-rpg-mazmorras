# ============================================================
#  distancia_aire.gd
#  LOS DISPAROS DEL ARCO Y LA BALLESTA en el mapa (02/10/2026). Hecho sobre la PUÑALADA de la daga (la aguja
#  que entra y asoma), que es lo mas parecido que ya tenia su visto bueno:
#    FLECHA       vuela del pecho del que tira al cuerpo del que recibe, con su cometa detras; al llegar, un
#                 destello en estrella y SE QUEDA CLAVADA en el cuerpo toda la pelea (la cola hacia el que tiro,
#                 vibrando un momento). Si la esquivan, pasa de largo y se clava en el suelo detras.
#    VIROTE       lo mismo, mas corto, mas gordo y mas rapido, y al entrar suelta astillas hacia delante.
#    VIROTE_PASA  el virote que ATRAVIESA (la ballesta, dos en linea): entra, asoma por la espalda y sigue; el
#                 siguiente virote que llegue en seguida sale de ahi (el que se clava en el segundo).
#  LAS HABILIDADES (02/10) son combinaciones de unos pocos comportamientos (ver es_virote, gordo, pasa, onda, pies):
#    FLECHA_GORDA  el Disparo cargado: mas grande, estela larga y una ONDA de aire al entrar.
#    FLECHA_PASA   el Disparo perforante: atraviesa a cada uno y sigue al siguiente (como el virote que pasa).
#    LLUVIA        cae del cielo en diagonal sobre cada uno, y otras se clavan en el suelo alrededor.
#    FLECHA_PIES   la Flecha clavadora: va a los PIES y lo clava al suelo, con grietas en la tierra.
#    VIROTE_GORDO  el Virote pesado: gordo, atraviesa a todos y suelta una onda en cada uno.
#    PERNO         el Perno de impacto: romo, revienta con onda y NO se clava: cae al suelo.
#    VIROTE_PIES   el Virote de clavo: a los pies, clavado al suelo y con sangre.
#    RECARGA       la Recarga rapida, sobre uno mismo: chispas de mecanismo en las manos.
#    TENSA         el Disparo cargado al EMPEZAR a cargar, sobre uno mismo: el aire se aprieta hacia el.
#  Lo pinta CombatTactico._on_dibujo_mapa golpe a golpe, en todas las maquinas (los mismos golpes: no cuesta
#  red). Lo clavado cuelga del CUERPO (lo sigue) y se quita al acabar la pelea (quitar_clavadas).
#  NADA DE LINEAS (efectos-sin-lineas): siluetas rellenas, cometas y destellos. Las grietas del suelo si son trazo.
# ============================================================
extends Node2D
class_name DistanciaAire

enum Modo { FLECHA, VIROTE, VIROTE_PASA, FLECHA_GORDA, FLECHA_PASA, LLUVIA, FLECHA_PIES, VIROTE_GORDO, PERNO,
	VIROTE_PIES, RECARGA, TENSA }

const VEL_FLECHA := 900.0       # px/s: lo que tarda en cruzar sale de aqui, con el vuelo de la pelea de tope
const VEL_VIROTE := 1200.0
const T_MIN_VUELO := 0.05
const T_APAGA := 0.16           # lo que tarda en irse el destello
const T_ONDA := 0.3             # lo que tarda la onda de aire en abrirse y apagarse
const T_SOBRE_SI := 0.7         # lo que duran los de sobre uno mismo
const T_VIBRA := 0.35           # lo que vibra la flecha recien clavada
const ALTO_TORSO := 14.0
const DESDE_CIELO := Vector2(-28.0, -170.0)   # de donde cae la lluvia, respecto a donde entra
const GRUPO_CLAVADAS := &"flechas_clavadas"
const GRUPO_VUELO := &"disparos_en_vuelo"

const BLANCO := BarridoAire.BLANCO
const ACERO := Color(0.80, 0.84, 0.90)
const ACERO_OSC := Color(0.42, 0.45, 0.52)
const MADERA := Color(0.56, 0.38, 0.22)
const MADERA_CLARA := Color(0.74, 0.55, 0.34)
const PLUMA := Color(0.86, 0.30, 0.24)       # plumas rojas: se distinguen de la punta de acero de un vistazo
const PLUMA_OSC := Color(0.55, 0.16, 0.14)
const ASTILLA := Color(0.86, 0.72, 0.50)
const TIERRA := Color(0.20, 0.15, 0.10)
const DORADO := Color(1.0, 0.86, 0.5)
# LA NORMAL (la infinita) es TODA DE MADERA y rancia (02/10, lo pidio el jefe): punta de palo tostado, astil
# gris-pardo y plumas apagadas. Las de material, con la punta de SU metal y plumas rojas.
const MADERA_RANCIA := Color(0.42, 0.33, 0.24)
const MADERA_RANCIA_CLARA := Color(0.55, 0.45, 0.34)
const PUNTA_RANCIA := Color(0.33, 0.25, 0.18)
const PLUMA_RANCIA := Color(0.52, 0.48, 0.40)
const PLUMA_RANCIA_OSC := Color(0.36, 0.33, 0.28)

# DE QUE ES LA PUNTA viaja dentro de la SEMILLA del golpe (bits 26-29), que si viaja por red con cada disparo:
# 0 = madera (la normal), 1..9 = el metal en el orden de Game._MUNICION. Asi todas las pantallas pintan la misma.
const BITS_PUNTA := 26

static func semilla_con_punta(semilla: int, md: MunicionData) -> int:
	var idx: int = 0
	if md != null:
		var lista: Array = Game.municiones()
		var pos: int = lista.find(md)
		idx = (pos % 9) + 1 if pos >= 0 else 0
	return (semilla & ((1 << BITS_PUNTA) - 1)) | (idx << BITS_PUNTA) | 1

static func punta_de_semilla(semilla: int) -> int:
	return (semilla >> BITS_PUNTA) & 0xF

# El color de la punta de un indice (0 = madera rancia).
static func color_punta(idx: int) -> Color:
	if idx <= 0:
		return PUNTA_RANCIA
	var lista: Array = Game.municiones()
	return (lista[idx - 1] as MaterialData).color if idx - 1 < lista.size() else ACERO
const Z_ENCIMA := Game.Z_PERSONAJES + 80

# --- LOS COMPORTAMIENTOS de cada modo ---
static func es_virote(m: int) -> bool:
	return m in [Modo.VIROTE, Modo.VIROTE_PASA, Modo.VIROTE_GORDO, Modo.PERNO, Modo.VIROTE_PIES]
static func gordo(m: int) -> bool:
	return m in [Modo.FLECHA_GORDA, Modo.VIROTE_GORDO]
static func pasa(m: int) -> bool:
	return m in [Modo.VIROTE_PASA, Modo.FLECHA_PASA, Modo.VIROTE_GORDO]
static func onda(m: int) -> bool:
	return m in [Modo.FLECHA_GORDA, Modo.VIROTE_GORDO, Modo.PERNO]
static func pies(m: int) -> bool:
	return m in [Modo.FLECHA_PIES, Modo.VIROTE_PIES]
static func sobre_si(m: int) -> bool:
	return m in [Modo.RECARGA, Modo.TENSA]

# Medidas del proyectil de cada modo: largo total, largo de la punta, grueso del astil, largo de las plumas, cuanto
# se queda fuera al clavarse. Los gordos, un 40% mas.
static func medidas(m: int) -> Dictionary:
	var d: Dictionary = {"largo": 16.0, "punta": 5.5, "grueso": 2.8, "pluma": 4.5, "fuera": 11.0} if es_virote(m) \
		else {"largo": 24.0, "punta": 5.0, "grueso": 1.6, "pluma": 7.0, "fuera": 16.0}
	if gordo(m):
		for k in d:
			d[k] = float(d[k]) * 1.4
	return d

# LA CADENA de lo que ATRAVIESA: en la pelea, los golpes de un disparo que pasa por varios salen A LA VEZ (la misma
# tanda), y sin esto se veia un proyectil por enemigo, todos saliendo del arma. El que viene detras de uno que
# atraviesa (mismo tirador, mismo instante) sale de donde entro el anterior y espera a que llegue: UNO solo que va
# pasando de cuerpo en cuerpo.
const CADENA_MS := 60
static var _cadena_activa: bool = false
static var _cadena_desde: Vector2 = Vector2.ZERO   # el pecho del que tira (el 'desde' original)
static var _cadena_punto: Vector2 = Vector2.ZERO   # donde entro el ultimo de la cadena
static var _cadena_t: float = 0.0                  # cuanto tarda en llegar ahi desde que sale
static var _cadena_ms: int = 0
# El ULTIMO de la cadena: si al llegar sigue siendo el ultimo (nadie vino detras), el que atraviesa se clava en el suelo
# detras del ultimo cuerpo en vez de desaparecer.
static var _cadena_ultimo: WeakRef = null

var modo: int = Modo.FLECHA
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _desde: Vector2 = Vector2.ZERO
var _punto: Vector2 = Vector2.ZERO     # donde entra (o donde se clava en el suelo, si falla)
var _dir: Vector2 = Vector2.RIGHT
var _vuelo: float = 0.1
var _fallo: bool = false
var _crit: bool = false
var _caja: Rect2 = Rect2()
var _cuerpo: Node2D = null
var _punta_col: Color = ACERO
var _rancia: bool = false
var _astillas: Array = []
var _chispas: Array = []
var _clavada_hecha: bool = false


# UN DISPARO. 'desde' = el pecho del que tira, 'caja' = el cuerpo que lo recibe tal como se ve, 'cuerpo' = su nodo
# (para clavarse en el y seguirle), 'espera' = lo que falta para el golpe en tiempo de la pelea (su vuelo).
static func disparo(padre: Node, m: int, desde: Vector2, caja: Rect2, cuerpo: Node2D, fallo: bool, crit: bool,
		semilla: int, espera: float, ritmo: float, punta: int = 0) -> DistanciaAire:
	if padre == null:
		return null
	var d := DistanciaAire.new()
	d.modo = m
	d._rng.seed = semilla
	d._ritmo = maxf(ritmo, 0.05)
	d._caja = caja
	d._cuerpo = cuerpo
	d._fallo = fallo
	d._crit = crit
	d._punta_col = color_punta(punta)
	d._rancia = punta <= 0
	d.z_as_relative = false
	d.z_index = Z_ENCIMA
	d.process_mode = Node.PROCESS_MODE_ALWAYS   # la pelea tactica pausa el arbol
	# El que va detras de uno que ATRAVIESA sale de donde entro el anterior, y espera a que llegue (ver la cadena).
	d._desde = desde
	var ms: int = Time.get_ticks_msec()
	var encadena: bool = _cadena_activa and ms - _cadena_ms <= CADENA_MS and _cadena_desde.distance_to(desde) < 2.0 \
		and not (sobre_si(m) or pies(m) or m == Modo.LLUVIA)
	if encadena:
		d._desde = _cadena_punto
	d._preparar(espera)
	# CUANDO LLEGA: justo en el GOLPE (lo que la pelea le da de vuelo, 'espera'), no antes: la flecha vuela mas rapido
	# de lo que tarda el numero, asi que espera escondida y sale a tiempo. En la cadena, cuando llega el anterior mas
	# lo que tarda en cruzar hasta este.
	var llega: float = (_cadena_t + d._vuelo) if encadena else maxf(espera, d._vuelo)
	if not sobre_si(m):
		d._t = -llega
	if encadena or pasa(m):
		_cadena_ultimo = weakref(d)
	if pasa(m) and not fallo:
		_cadena_activa = true
		_cadena_desde = desde
		_cadena_punto = d._punto
		_cadena_t = llega
		_cadena_ms = ms
	else:
		_cadena_activa = false
	d.add_to_group(GRUPO_VUELO)
	padre.add_child(d)
	return d


# Quita todo lo clavado (al acabar la pelea).
static func quitar_clavadas(arbol: SceneTree) -> void:
	if arbol == null:
		return
	# Y lo que aun va VOLANDO: si llegara despues se clavaria en una pelea que ya no existe.
	for n in arbol.get_nodes_in_group(GRUPO_CLAVADAS) + arbol.get_nodes_in_group(GRUPO_VUELO):
		n.queue_free()


func _preparar(espera: float) -> void:
	var c: Vector2 = _caja.get_center() if _caja.has_area() else _desde + Vector2(40, 0)
	var alto: float = _caja.size.y if _caja.has_area() else 24.0
	# SOBRE UNO MISMO: no vuela nada, empieza ya.
	if sobre_si(modo):
		_punto = c
		_vuelo = maxf(espera, T_MIN_VUELO)
		_t = -_vuelo * 0.5
		for i in 7:
			_chispas.append({"a": _rng.randf() * TAU, "r": _rng.randf_range(8.0, 15.0), "t0": _rng.randf_range(0.0, 0.3),
				"giro": _rng.randf_range(2.0, 4.0) * (1.0 if _rng.randf() < 0.5 else -1.0)})
		return
	# Entra a la altura del PECHO, un poco al azar (cada flecha en su sitio, que se lean varias clavadas).
	_punto = c + Vector2(_rng.randf_range(-0.22, 0.22) * _caja.size.x, _rng.randf_range(-0.25, 0.05) * alto)
	# A LOS PIES (clavadora, clavo): entra abajo, junto al suelo.
	if pies(modo) and _caja.has_area():
		_punto = Vector2(c.x + _rng.randf_range(-0.2, 0.2) * _caja.size.x, _caja.end.y - 2.0)
	# LA LLUVIA cae del cielo, en diagonal.
	if modo == Modo.LLUVIA:
		_desde = _punto + DESDE_CIELO.rotated(_rng.randf_range(-0.15, 0.15))
	_dir = (_punto - _desde).normalized() if _punto.distance_squared_to(_desde) > 0.01 else Vector2.RIGHT
	# DE ESPALDAS (el que tira esta por encima en pantalla): la cola queda detras del cuerpo. Entra por la parte de
	# ARRIBA para que asome por encima del hombro y se lea clavada.
	if _dir.y > 0.15 and not pies(modo) and modo != Modo.LLUVIA:
		_punto.y = _caja.position.y + alto * _rng.randf_range(0.18, 0.3) if _caja.has_area() else _punto.y
		_dir = (_punto - _desde).normalized()
	if _fallo:
		# Pasa rozando por un lado y se clava en el SUELO un poco por detras (a la altura de los pies).
		var lado: float = 1.0 if _rng.randf() < 0.5 else -1.0
		var p_pies: Vector2 = Vector2(c.x, _caja.end.y) if _caja.has_area() else c
		_punto = p_pies + _dir.orthogonal() * lado * (_caja.size.x * 0.75 + 7.0) + _dir * 28.0
		_dir = (_punto - _desde).normalized()
	var vel: float = VEL_VIROTE if es_virote(modo) else VEL_FLECHA
	_vuelo = clampf(_desde.distance_to(_punto) / vel, T_MIN_VUELO, maxf(espera, T_MIN_VUELO))
	_t = -_vuelo
	if es_virote(modo) or modo == Modo.FLECHA_GORDA:
		for i in (9 if gordo(modo) or modo == Modo.PERNO else 6):
			var a: float = _rng.randf_range(-0.7, 0.7)
			_astillas.append({"v": _dir.rotated(a) * _rng.randf_range(40.0, 95.0), "l": _rng.randf_range(3.0, 6.0)})


func duracion() -> float:
	if sobre_si(modo):
		return T_SOBRE_SI
	return T_APAGA + 0.25 + (T_ONDA if onda(modo) else 0.0)


func _process(delta: float) -> void:
	_t += delta * _ritmo
	# AL LLEGAR: se clava (en el cuerpo o en el suelo). El que atraviesa no: apunta por donde sale.
	if _t >= 0.0 and not _clavada_hecha and not sobre_si(modo):
		_clavada_hecha = true
		_al_llegar()
	if _t >= duracion():
		queue_free()
		return
	queue_redraw()


func _al_llegar() -> void:
	# El que atraviesa no se queda: lo sigue pintando el siguiente de la cadena. Si era el ULTIMO, sale por la espalda
	# y se clava en el suelo detras.
	if pasa(modo) and not _fallo:
		if _cadena_ultimo != null and _cadena_ultimo.get_ref() == self:
			var p_pies: Vector2 = Vector2(_punto.x, _caja.end.y) if _caja.has_area() else _punto
			_clavar(p_pies + _dir * 26.0, true)
		return
	# EL PERNO es romo: no se clava, rebota y cae al suelo delante de los pies.
	if modo == Modo.PERNO and not _fallo:
		var p_pies: Vector2 = Vector2(_punto.x, _caja.end.y) if _caja.has_area() else _punto
		_clavar(p_pies - _dir * 10.0 + _dir.orthogonal() * _rng.randf_range(-6.0, 6.0), true)
		return
	_clavar(_punto, _fallo or _cuerpo == null or not is_instance_valid(_cuerpo))
	# A LOS PIES: grietas en la tierra alrededor (y sangre, el clavo).
	if pies(modo) and not _fallo:
		var gr := Grietas.new()
		gr.semilla = _rng.randi()
		gr.add_to_group(GRUPO_CLAVADAS)
		gr.z_as_relative = false
		gr.z_index = SueloRoto.Z_SUELO + 1
		get_parent().add_child(gr)
		gr.global_position = _punto
		if modo == Modo.VIROTE_PIES:
			SangreMapa.salpicar(get_parent(), _punto - Vector2(0.0, 6.0), _punto, _dir, 0.8, _rng.randi())
	# LA LLUVIA: de vez en cuando otra se clava en el suelo alrededor (el resto de la rociada; pocas, que no sea un erizo).
	if modo == Modo.LLUVIA and _rng.randf() < 0.35:
		var p_pies2: Vector2 = Vector2(_punto.x, _caja.end.y) if _caja.has_area() else _punto
		_clavar(p_pies2 + Vector2(_rng.randf_range(-22.0, 22.0), _rng.randf_range(-8.0, 10.0)), true)


# Lo que queda clavado: un nodo hijo del CUERPO (le sigue al andar) o del suelo, con el dibujo de la cola.
func _clavar(donde: Vector2, en_suelo: bool) -> void:
	var med: Dictionary = medidas(modo)
	var cl := Clavada.new()
	cl.modo = modo
	cl.dir = _dir
	cl.fuera = float(med["fuera"]) * (0.75 if en_suelo else 1.0)
	cl.semilla = _rng.randi()
	cl.punta_col = _punta_col
	cl.rancia = _rancia
	# A LOS PIES se queda clavada "al suelo" (inclinada hacia abajo) pero colgando del cuerpo: si se mueve, va con el.
	cl.en_suelo = en_suelo or pies(modo)
	cl.add_to_group(GRUPO_CLAVADAS)
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	if not en_suelo:
		# Viene de DELANTE (el que tira esta mas abajo en pantalla): la cola queda por delante del cuerpo; si viene
		# de detras, por detras. La lluvia cae desde arriba: por delante.
		cl.z_index = -1 if _dir.y > 0.15 and modo != Modo.LLUVIA and not pies(modo) else 1
		_cuerpo.add_child(cl)
		cl.global_position = donde
	else:
		cl.z_as_relative = false
		cl.z_index = SueloRoto.Z_SUELO + 2
		get_parent().add_child(cl)
		cl.global_position = donde


func _draw() -> void:
	if sobre_si(modo):
		_dibujar_sobre_si()
		return
	var med: Dictionary = medidas(modo)
	var largo: float = float(med["largo"])
	# ESPERANDO a que llegue el anterior de la cadena: aun no se ve.
	if _t < -_vuelo:
		return
	# EN VUELO: la silueta entera, con su cometa detras (mas larga y mas viva la del gordo).
	if _t < 0.0:
		var s: float = clampf(1.0 + _t / _vuelo, 0.0, 1.0)
		var punta: Vector2 = _desde.lerp(_punto, s)
		var cola: Vector2 = punta - _dir * largo
		var k_cola: float = 2.6 if gordo(modo) else 1.4
		BarridoAire.cometa(self, cola - _dir * largo * k_cola * s, cola, float(med["grueso"]) * (2.2 if gordo(modo) else 1.6),
			Color(DORADO if modo == Modo.FLECHA_GORDA else BLANCO, (0.7 if gordo(modo) else 0.45) * minf(s * 4.0, 1.0)))
		proyectil(self, punta, _dir, modo, 1.0, _punta_col, -1.0, _rancia)
		# EL GORDO sale con un golpe de aire en el arma (los primeros instantes del vuelo).
		if modo == Modo.FLECHA_GORDA and s < 0.3:
			_onda(_desde, s / 0.3, 0.6)
		return
	var va: float = clampf(_t / T_APAGA, 0.0, 1.0)
	if _fallo:
		return
	# EL IMPACTO: el destello en estrella (mas grande si es critico o gordo) y las astillas.
	var pulso: float = exp(-_t / 0.04)
	var rd: float = (15.0 if _crit else 9.0) * (0.35 + 0.9 * pulso) * (1.2 if es_virote(modo) else 1.0) \
		* (1.5 if onda(modo) else 1.0)
	BarridoAire.destello(self, _punto, rd, Color(BLANCO, (1.0 - va) * (0.35 + 0.65 * pulso)), _dir.angle())
	for a in _astillas:
		var p0: Vector2 = _punto + (a["v"] as Vector2) * _t * 0.6
		var p1: Vector2 = _punto + (a["v"] as Vector2) * _t
		BarridoAire.cometa(self, p0 - (a["v"] as Vector2).normalized() * float(a["l"]), p1, 1.6,
			Color(ASTILLA, 1.0 - va))
	if onda(modo):
		_onda(_punto, clampf(_t / T_ONDA, 0.0, 1.0), 1.0)


# LA ONDA DE AIRE: un anillo de cometas que salen del punto hacia fuera y se apagan (sin trazo). Achatada en el suelo.
func _onda(c: Vector2, k: float, fuerza: float) -> void:
	if k >= 1.0:
		return
	var n: int = 12
	var r0: float = 4.0 + 26.0 * fuerza * k
	var r1: float = r0 + 8.0 * fuerza * (1.0 - k * 0.5)
	for i in n:
		var a: float = TAU * float(i) / float(n) + 0.13
		var u := Vector2(cos(a), sin(a) * 0.62)
		BarridoAire.cometa(self, c + u * r0, c + u * r1, 2.2 * fuerza, Color(BLANCO, 0.75 * (1.0 - k)))


# SOBRE UNO MISMO. TENSA: el aire se aprieta hacia el pecho (cometas de fuera a dentro) y un brillo dorado que crece.
# RECARGA: chispas que giran alrededor de las manos y destellos pequeños de mecanismo.
func _dibujar_sobre_si() -> void:
	var u: float = clampf((_t + _vuelo * 0.5) / T_SOBRE_SI, 0.0, 1.0)
	var apaga: float = 1.0 - smoothstep(0.75, 1.0, u)
	if modo == Modo.TENSA:
		for ch in _chispas:
			var k: float = clampf((u - float(ch["t0"])) / 0.5, 0.0, 1.0)
			if k <= 0.0 or k >= 1.0:
				continue
			var dir_c := Vector2(cos(float(ch["a"])), sin(float(ch["a"])) * 0.7)
			var r_fuera: float = 28.0 * (1.0 - k)
			BarridoAire.cometa(self, _punto + dir_c * (r_fuera + 9.0), _punto + dir_c * r_fuera, 1.8,
				Color(DORADO, 0.8 * apaga))
		BarridoAire.destello(self, _punto, 4.0 + 9.0 * u, Color(DORADO, 0.85 * apaga), u * 2.0)
		return
	# RECARGA
	for ch in _chispas:
		var k2: float = clampf((u - float(ch["t0"])) / 0.55, 0.0, 1.0)
		if k2 <= 0.0 or k2 >= 1.0:
			continue
		var a2: float = float(ch["a"]) + float(ch["giro"]) * k2
		var p: Vector2 = _punto + Vector2(cos(a2), sin(a2) * 0.6) * float(ch["r"]) + Vector2(0.0, 3.0)
		var p_ant: Vector2 = _punto + Vector2(cos(a2 - 0.5 * signf(float(ch["giro"]))), sin(a2 - 0.5 * signf(float(ch["giro"]))) * 0.6) \
			* float(ch["r"]) + Vector2(0.0, 3.0)
		BarridoAire.cometa(self, p_ant, p, 1.6, Color(ACERO.lightened(0.3), 0.85 * (1.0 - k2)))
		if k2 > 0.4 and k2 < 0.6:
			BarridoAire.destello(self, p, 3.5, Color(BLANCO, 0.9), a2)


# Cuanto hay desde el punto de entrada hasta el borde del cuerpo siguiendo 'd' (por donde asoma).
func _hasta_el_borde(d: Vector2) -> float:
	if not _caja.has_area():
		return 8.0
	var h: Vector2 = _caja.size * 0.5
	var rel: Vector2 = _punto - _caja.get_center()
	var tx: float = (h.x - signf(d.x) * rel.x) / absf(d.x) if absf(d.x) > 0.001 else INF
	var ty: float = (h.y - signf(d.y) * rel.y) / absf(d.y) if absf(d.y) > 0.001 else INF
	return clampf(minf(tx, ty), 2.0, 40.0)


# ------------------------------------------------------------
#  EL DIBUJO DEL PROYECTIL (en vuelo y clavado): todo relleno, nada de trazos
# ------------------------------------------------------------
# La silueta con la PUNTA en 'punta', mirando hacia 'dir'. 'solo_fuera' = clavada, solo la parte de fuera (desde la
# cola). 'alfa' la apaga entera.
static func proyectil(ci: CanvasItem, punta: Vector2, dir: Vector2, m: int, alfa: float, punta_col: Color,
		solo_fuera: float = -1.0, rancia: bool = false) -> void:
	if alfa <= 0.0:
		return
	var med: Dictionary = medidas(m)
	var largo: float = float(med["largo"])
	var lp: float = float(med["punta"])
	var g: float = float(med["grueso"])
	var lpl: float = float(med["pluma"])
	var n: Vector2 = dir.orthogonal()
	var cola: Vector2 = punta - dir * largo
	# Clavada: la punta y parte del astil estan DENTRO; solo se pinta desde 'solo_fuera' antes de la cola.
	var desde_cola: float = largo if solo_fuera < 0.0 else minf(solo_fuera, largo)
	var corte: Vector2 = cola + dir * desde_cola
	# El ASTIL: una banda de madera, clara arriba y oscura abajo (la luz viene de arriba).
	var fin_astil: Vector2 = corte if solo_fuera >= 0.0 else punta - dir * lp * 0.8
	_banda(ci, cola, fin_astil, n * g * 0.5, Color(MADERA_RANCIA_CLARA if rancia else MADERA_CLARA, alfa),
		Color(MADERA_RANCIA if rancia else MADERA, alfa))
	# LAS PLUMAS: dos aletas LARGAS pegadas al astil en la cola, que bajan suaves hacia delante y se cortan en
	# diagonal por detras (como las de verdad). Nada de triangulo en punta: se leia como otra punta.
	var p_atras: Vector2 = cola + dir * 0.5
	var p_delante: Vector2 = cola + dir * (0.5 + lpl)
	var abre: float = g * (1.15 if es_virote(m) else 1.5) + 0.9
	for lado in [1.0, -1.0]:
		var nn: Vector2 = n * lado
		ci.draw_colored_polygon(PackedVector2Array([
			p_delante + nn * g * 0.45,
			p_delante - dir * lpl * 0.25 + nn * abre * 0.8,
			p_atras + dir * 0.6 + nn * abre,
			p_atras + nn * g * 0.45]), Color((PLUMA_RANCIA if rancia else PLUMA) if lado > 0.0
				else (PLUMA_RANCIA_OSC if rancia else PLUMA_OSC), alfa))
	if solo_fuera >= 0.0:
		return
	var base: Vector2 = punta - dir * lp
	# EL PERNO es ROMO: una cabeza de metal cuadrada, sin punta.
	if m == Modo.PERNO:
		var a: float = g * 1.1
		ci.draw_colored_polygon(PackedVector2Array([base + n * a, punta + n * a, punta - n * a, base - n * a]),
			Color((PUNTA_RANCIA if rancia else punta_col).darkened(0.2), alfa))
		ci.draw_colored_polygon(PackedVector2Array([base + n * a, punta + n * a, punta + n * a * 0.3, base + n * a * 0.3]),
			Color((PUNTA_RANCIA if rancia else punta_col).lightened(0.3), alfa))
		return
	# LA PUNTA: un rombo de metal con su filo de luz. La de madera, una punta de palo sin mas (sin rombo).
	if rancia:
		ci.draw_colored_polygon(PackedVector2Array([base + n * g * 0.5, punta, base - n * g * 0.5]),
			Color(PUNTA_RANCIA, alfa))
		return
	var ancho_p: float = g * (1.25 if es_virote(m) else 1.5)
	ci.draw_colored_polygon(PackedVector2Array([base - dir * 1.0, base + n * ancho_p, punta, base - n * ancho_p]),
		Color(punta_col.darkened(0.25), alfa))
	ci.draw_colored_polygon(PackedVector2Array([base + n * ancho_p * 0.2, punta, base + n * ancho_p]),
		Color(punta_col.lightened(0.35), alfa))


# Una banda rellena de 'a' a 'b' de medio grosor 'm', con un color por cada lado (sin trazo).
static func _banda(ci: CanvasItem, a: Vector2, b: Vector2, m: Vector2, col_arriba: Color, col_abajo: Color) -> void:
	if a.distance_squared_to(b) < 0.01:
		return
	ci.draw_primitive(PackedVector2Array([a + m, b + m, b - m]),
		PackedColorArray([col_arriba, col_arriba, col_abajo]), PackedVector2Array())
	ci.draw_primitive(PackedVector2Array([a + m, b - m, a - m]),
		PackedColorArray([col_arriba, col_abajo, col_abajo]), PackedVector2Array())


# ------------------------------------------------------------
#  LO QUE SE QUEDA CLAVADO (toda la pelea)
# ------------------------------------------------------------
class Clavada extends Node2D:
	var modo: int = 0
	var dir: Vector2 = Vector2.RIGHT
	var fuera: float = 12.0
	var semilla: int = 1
	var en_suelo: bool = false
	var punta_col: Color = ACERO
	var rancia: bool = false
	var _t: float = 0.0

	func _process(delta: float) -> void:
		if _t < T_VIBRA:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		# Recien clavada VIBRA un momento (la cola se mueve de lado a lado y se para).
		var vib: float = sin(_t * 70.0) * 0.12 * maxf(0.0, 1.0 - _t / T_VIBRA)
		var d: Vector2 = dir.rotated(vib)
		# En el SUELO se queda inclinada hacia arriba (clavada en la tierra, la cola al aire).
		if en_suelo:
			d = (d * Vector2(1.0, 0.5) + Vector2(0.0, 0.85)).normalized()
		var med: Dictionary = DistanciaAire.medidas(modo)
		var largo: float = float(med["largo"])
		# La punta queda DENTRO: se pinta la silueta con la punta metida 'largo - fuera'.
		var punta: Vector2 = d * (largo - fuera)
		DistanciaAire.proyectil(self, punta, d, modo, 1.0, punta_col, fuera, rancia)
		# Una sombrita bajo lo que se clava en el suelo, para que se lea plantada.
		if en_suelo:
			var c: Vector2 = -d * fuera * 0.5
			draw_colored_polygon(PackedVector2Array([Vector2(-3, 0), c + Vector2(0, 1), Vector2(3, 0.5)]),
				Color(0, 0, 0, 0.25))


# LAS GRIETAS de la tierra alrededor del pie clavado (clavadora, clavo): son SUELO, asi que si van de trazo.
class Grietas extends Node2D:
	var semilla: int = 1

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = semilla
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -1), Vector2(-2, -3), Vector2(4, -2), Vector2(7, 1),
			Vector2(2, 3), Vector2(-5, 2)]), Color(TIERRA, 0.45))
		for i in 5:
			var a: float = TAU * float(i) / 5.0 + rng.randf_range(-0.3, 0.3)
			var p := Vector2.ZERO
			var pts := PackedVector2Array([p])
			for k in 3:
				p += Vector2(cos(a + rng.randf_range(-0.5, 0.5)), sin(a + rng.randf_range(-0.5, 0.5)) * 0.55) \
					* rng.randf_range(3.0, 5.0)
				pts.append(p)
			draw_polyline(pts, Color(TIERRA, 0.8), 1.0)
