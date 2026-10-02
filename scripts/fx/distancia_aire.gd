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
#  Lo pinta CombatTactico._on_dibujo_mapa golpe a golpe, en todas las maquinas (los mismos golpes: no cuesta
#  red). Lo clavado cuelga del CUERPO (lo sigue) y se quita al acabar la pelea (quitar_clavadas).
#  NADA DE LINEAS (efectos-sin-lineas): siluetas rellenas, cometas y destellos.
# ============================================================
extends Node2D
class_name DistanciaAire

enum Modo { FLECHA, VIROTE, VIROTE_PASA }

const VEL_FLECHA := 900.0       # px/s: lo que tarda en cruzar sale de aqui, con el vuelo de la pelea de tope
const VEL_VIROTE := 1200.0
const T_MIN_VUELO := 0.05
const T_APAGA := 0.16           # lo que tarda en irse el destello
const T_VIBRA := 0.35           # lo que vibra la flecha recien clavada
const T_SIGUE := 0.35           # cuanto tiempo vale la salida de un virote que atraviesa para el siguiente
const ALTO_TORSO := 14.0
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

# Medidas de cada proyectil: largo total, largo de la punta, grueso del astil, largo de las plumas, cuanto se
# queda fuera al clavarse.
const MEDIDAS := {
	Modo.FLECHA: {"largo": 24.0, "punta": 5.0, "grueso": 1.6, "pluma": 7.0, "fuera": 16.0},
	Modo.VIROTE: {"largo": 16.0, "punta": 5.5, "grueso": 2.8, "pluma": 4.5, "fuera": 11.0},
	Modo.VIROTE_PASA: {"largo": 16.0, "punta": 5.5, "grueso": 2.8, "pluma": 4.5, "fuera": 11.0},
}

# La salida del ultimo virote que atraveso: el siguiente que se dispare en seguida sale de ahi.
static var _salida_pasa: Vector2 = Vector2.INF
static var _salida_ms: int = 0

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
	# El virote que llega justo detras de uno que atraveso sale de la espalda del primero, no otra vez del arma.
	d._desde = desde
	if m != Modo.VIROTE_PASA and _salida_pasa != Vector2.INF and Time.get_ticks_msec() - _salida_ms <= int(T_SIGUE * 1000.0):
		d._desde = _salida_pasa
		_salida_pasa = Vector2.INF
	d._preparar(espera)
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
	# Entra a la altura del PECHO, un poco al azar (cada flecha en su sitio, que se lean varias clavadas).
	_punto = c + Vector2(_rng.randf_range(-0.22, 0.22) * _caja.size.x, _rng.randf_range(-0.25, 0.05) * alto)
	_dir = (_punto - _desde).normalized() if _punto.distance_squared_to(_desde) > 0.01 else Vector2.RIGHT
	# DE ESPALDAS (el que tira esta por encima en pantalla): la cola queda detras del cuerpo. Entra por la parte de
	# ARRIBA para que asome por encima del hombro y se lea clavada.
	if _dir.y > 0.15:
		_punto.y = _caja.position.y + alto * _rng.randf_range(0.18, 0.3) if _caja.has_area() else _punto.y
		_dir = (_punto - _desde).normalized()
	if _fallo:
		# Pasa rozando por un lado y se clava en el SUELO un poco por detras (a la altura de los pies).
		var lado: float = 1.0 if _rng.randf() < 0.5 else -1.0
		var pies: Vector2 = Vector2(c.x, _caja.end.y) if _caja.has_area() else c
		_punto = pies + _dir.orthogonal() * lado * (_caja.size.x * 0.75 + 7.0) + _dir * 28.0
		_dir = (_punto - _desde).normalized()
	var vel: float = VEL_VIROTE if modo != Modo.FLECHA else VEL_FLECHA
	_vuelo = clampf(_desde.distance_to(_punto) / vel, T_MIN_VUELO, maxf(espera, T_MIN_VUELO))
	_t = -_vuelo
	if modo != Modo.FLECHA:
		for i in 6:
			var a: float = _rng.randf_range(-0.7, 0.7)
			_astillas.append({"v": _dir.rotated(a) * _rng.randf_range(40.0, 95.0), "l": _rng.randf_range(3.0, 6.0)})


func duracion() -> float:
	return T_APAGA + 0.25 + (0.12 if modo == Modo.VIROTE_PASA else 0.0)


func _process(delta: float) -> void:
	_t += delta * _ritmo
	# AL LLEGAR: se clava (en el cuerpo o en el suelo). El que atraviesa no: apunta por donde sale.
	if _t >= 0.0 and not _clavada_hecha:
		_clavada_hecha = true
		if modo == Modo.VIROTE_PASA and not _fallo:
			_salida_pasa = _punto + _dir * _hasta_el_borde(_dir)
			_salida_ms = Time.get_ticks_msec()
		else:
			_clavar()
	if _t >= duracion():
		queue_free()
		return
	queue_redraw()


# Lo que queda clavado: un nodo hijo del CUERPO (le sigue al andar) o del suelo, con el dibujo de la cola.
func _clavar() -> void:
	var med: Dictionary = MEDIDAS[modo]
	var cl := Clavada.new()
	cl.modo = modo
	cl.dir = _dir
	cl.fuera = float(med["fuera"]) * (0.75 if _fallo else 1.0)
	cl.semilla = _rng.randi()
	cl.punta_col = _punta_col
	cl.rancia = _rancia
	cl.en_suelo = _fallo or _cuerpo == null or not is_instance_valid(_cuerpo)
	cl.add_to_group(GRUPO_CLAVADAS)
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	if not cl.en_suelo:
		# Viene de DELANTE (el que tira esta mas abajo en pantalla): la cola queda por delante del cuerpo; si viene
		# de detras, por detras.
		cl.z_index = -1 if _dir.y > 0.15 else 1
		_cuerpo.add_child(cl)
		cl.global_position = _punto
	else:
		cl.z_as_relative = false
		cl.z_index = SueloRoto.Z_SUELO + 2
		get_parent().add_child(cl)
		cl.global_position = _punto


func _draw() -> void:
	var med: Dictionary = MEDIDAS[modo]
	var largo: float = float(med["largo"])
	# EN VUELO: la silueta entera, con su cometa detras.
	if _t < 0.0:
		var s: float = clampf(1.0 + _t / _vuelo, 0.0, 1.0)
		var punta: Vector2 = _desde.lerp(_punto, s)
		var cola: Vector2 = punta - _dir * largo
		BarridoAire.cometa(self, cola - _dir * largo * 1.4 * s, cola, float(med["grueso"]) * 1.6,
			Color(BLANCO, 0.45 * minf(s * 4.0, 1.0)))
		proyectil(self, punta, _dir, modo, 1.0, _punta_col, -1.0, _rancia)
		return
	var va: float = clampf(_t / T_APAGA, 0.0, 1.0)
	# EL QUE ATRAVIESA no se sigue pintando: el siguiente virote sale de su espalda y es el que se ve seguir.
	if _fallo:
		return
	# EL IMPACTO: el destello en estrella (mas grande si es critico) y las astillas del virote.
	var pulso: float = exp(-_t / 0.04)
	var rd: float = (15.0 if _crit else 9.0) * (0.35 + 0.9 * pulso) * (1.2 if modo != Modo.FLECHA else 1.0)
	BarridoAire.destello(self, _punto, rd, Color(BLANCO, (1.0 - va) * (0.35 + 0.65 * pulso)), _dir.angle())
	for a in _astillas:
		var p0: Vector2 = _punto + (a["v"] as Vector2) * _t * 0.6
		var p1: Vector2 = _punto + (a["v"] as Vector2) * _t
		BarridoAire.cometa(self, p0 - (a["v"] as Vector2).normalized() * float(a["l"]), p1, 1.6,
			Color(ASTILLA, 1.0 - va))


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
# La silueta con la PUNTA en 'punta', mirando hacia 'dir'. 'mostrar' = que parte se ve desde la cola (1 = entera;
# clavada se ve solo lo de fuera, ver Clavada). 'alfa' la apaga entera.
static func proyectil(ci: CanvasItem, punta: Vector2, dir: Vector2, m: int, alfa: float, punta_col: Color,
		solo_fuera: float = -1.0, rancia: bool = false) -> void:
	if alfa <= 0.0:
		return
	var med: Dictionary = MEDIDAS[m]
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
	var abre: float = g * (1.5 if m == Modo.FLECHA else 1.15) + 0.9
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
	# LA PUNTA: un rombo de metal con su filo de luz. La de madera, una punta de palo sin mas (sin rombo).
	var base: Vector2 = punta - dir * lp
	if rancia:
		ci.draw_colored_polygon(PackedVector2Array([base + n * g * 0.5, punta, base - n * g * 0.5]),
			Color(PUNTA_RANCIA, alfa))
		return
	var ancho_p: float = g * (1.5 if m == Modo.FLECHA else 1.25)
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
		var med: Dictionary = MEDIDAS[modo]
		var largo: float = float(med["largo"])
		# La punta queda DENTRO: se pinta la silueta con la punta metida 'largo - fuera'.
		var punta: Vector2 = d * (largo - fuera)
		DistanciaAire.proyectil(self, punta, d, modo, 1.0, punta_col, fuera, rancia)
		# Una sombrita bajo lo que se clava en el suelo, para que se lea plantada.
		if en_suelo:
			var c: Vector2 = -d * fuera * 0.5
			draw_colored_polygon(PackedVector2Array([Vector2(-3, 0), c + Vector2(0, 1), Vector2(3, 0.5)]),
				Color(0, 0, 0, 0.25))
