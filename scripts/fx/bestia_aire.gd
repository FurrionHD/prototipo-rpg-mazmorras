# ============================================================
#  bestia_aire.gd
#  LOS EFECTOS DE LAS BESTIAS DE LOS PISOS BAJOS en el mapa (28/09/2026): rata, rey rata, jabali y trent, uno a
#  uno y con su visto bueno (ver la memoria enemigos-bajos-tactico). Empieza por la RATA:
#  SOBRE UN CUERPO (CombatTactico._on_dibujo_mapa, CombatFX.Estilo.BESTIA_*):
#    MORDISCO        el basico: dos MANDIBULAS en media luna, con sus colmillos, que se cierran de golpe sobre el
#                    cuerpo; un destello al cerrar y un tiron hacia quien muerde. Orientadas segun de donde viene
#                    el golpe, y cada una con su variacion.
#    MORDISCO_SANGRA el Mordisco sangrante: lo mismo (la sangre la pone CombatTactico._on_impacto, solo si entra).
#    FRENESI         el Frenesi de dentelladas: mandibulas mas pequeñas y rapidas, cada una desde un angulo
#                    cualquiera: un remolino de mordiscos.
#  POR EL SUELO (SueloRoto.Tipo.BESTIA_*, en el orden de Modo):
#    POLVO           el aterrizaje del Frenesi: un anillo de polvo que se abre desde donde cae y unas piedrecitas.
#  NADA DE LINEAS: siluetas llenas con filo duro y un halo difuminado detras (ver efectos-sin-lineas).
#  Coordenadas de MUNDO.
# ============================================================
extends Node2D
class_name BestiaAire

# Los del suelo van en el orden de SueloRoto.Tipo.BESTIA_*: no reordenar.
enum Modo { POLVO, MORDISCO, MORDISCO_SANGRA, FRENESI }

const K := 0.7071
const Z_ENCIMA := Game.Z_PERSONAJES + 80
const T_POLVO := 0.28             # lo que tarda el anillo de polvo en llegar al borde
const T_CERRADO := 0.22           # lo que se quedan las mandibulas cerradas antes de irse
const T_IRSE := 0.18

const HUESO := Color(0.96, 0.93, 0.84)
const HUESO_SOMBRA := Color(0.62, 0.55, 0.46)
const BOCA := Color(0.16, 0.04, 0.05)
const POLVO := Color(0.55, 0.47, 0.38)
const POLVO_CLARO := Color(0.78, 0.71, 0.6)

var modo: int = Modo.MORDISCO
var forma: CombatFormas.Forma = null
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _desde: Vector2 = Vector2.ZERO
var _hasta: Vector2 = Vector2.ZERO
var _ancho: float = 16.0
var _viaje: float = 0.12
var _eje: Vector2 = Vector2.RIGHT     # hacia donde muerde (de quien muerde a quien recibe): el tiron va al reves
var _boca: Vector2 = Vector2.UP       # hacia donde queda la mandibula de ARRIBA (la de abajo, al contrario)
var _tam: float = 10.0
var _o: Vector2 = Vector2.ZERO
var _r: float = 25.0
var _puffs: Array = []
var _piedras: Array = []
var _delante: Node2D = null
var _brillo: Node2D = null
var _suelo: Node2D = null


# ------------------------------------------------------------
#  EN EL SUELO
# ------------------------------------------------------------
static func area(padre: Node, f: CombatFormas.Forma, m: int, semilla: int, espera: float) -> Node2D:
	if padre == null or f == null:
		return null
	var e := BestiaAire.new()
	e.modo = m
	e.forma = f
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	e._t = -espera * e._ritmo
	e.z_as_relative = false
	e.z_index = SueloRoto.Z_SUELO
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._o = SueloRoto.origen_de(f)
	e._r = maxf(f.radio, 8.0)
	for i in 16:
		var a: float = TAU * (float(i) + e._rng.randf_range(0.0, 0.8)) / 16.0
		e._puffs.append({"a": a, "u": e._rng.randf_range(0.7, 1.05), "tam": e._rng.randf_range(0.18, 0.3),
			"sube": e._rng.randf_range(4.0, 10.0), "sem": e._rng.randf_range(0.0, 9.0)})
	for i in 7:
		var a2: float = e._rng.randf_range(0.0, TAU)
		e._piedras.append({"a": a2, "v": e._rng.randf_range(40.0, 75.0), "sube": e._rng.randf_range(14.0, 26.0),
			"tam": e._rng.randf_range(1.2, 2.0)})
	e._suelo = e._capa(SueloRoto.Z_SUELO, false)
	e._delante = e._capa(Z_ENCIMA, false)
	return e


static func retraso(m: int, f: CombatFormas.Forma, p: Vector2) -> float:
	if f == null:
		return 0.0
	match m:
		Modo.POLVO:
			return clampf(p.distance_to(SueloRoto.origen_de(f)) / maxf(f.radio, 1.0), 0.0, 1.0) * T_POLVO
	return 0.0


static func t_salir(m: int) -> float:
	match m:
		Modo.POLVO: return T_POLVO
	return 0.2


# ------------------------------------------------------------
#  SOBRE UN CUERPO
# ------------------------------------------------------------
# 'desde' = de donde viene (quien muerde), 'caja' = el cuerpo que lo recibe, 'espera' = lo que falta para el
# golpe: las mandibulas se van cerrando en ese tiempo y se juntan justo en el golpe.
static func sobre_cuerpo(padre: Node, m: int, desde: Vector2, caja: Rect2, semilla: int, espera: float,
		ritmo: float) -> BestiaAire:
	if padre == null:
		return null
	var e := BestiaAire.new()
	e.modo = m
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	e._viaje = clampf(espera, 0.08, 0.2) if m != Modo.FRENESI else clampf(espera, 0.06, 0.12)
	e._t = -e._viaje
	e._desde = desde
	e._hasta = caja.get_center() + Vector2(e._rng.randf_range(-0.15, 0.15) * caja.size.x,
		e._rng.randf_range(-0.2, 0.1) * caja.size.y)
	e._ancho = maxf(caja.size.x, 10.0)
	var eje: Vector2 = (e._hasta - desde).normalized() if e._hasta.distance_squared_to(desde) > 1.0 else Vector2.RIGHT
	e._eje = eje
	# UNA BOCA MUERDE ARRIBA Y ABAJO, venga de donde venga (lo corrigio el usuario, 28/09: de lado "su boca no esta
	# de lado"). NUNCA CON ANGULO FIJO igual: se inclina hacia el lado del que viene quien muerde, y cada mordisco
	# con su variacion; el frenesi, mas revuelto.
	var inclina: float = eje.x * 0.35 + e._rng.randf_range(-0.2, 0.2) * (2.5 if m == Modo.FRENESI else 1.0)
	e._boca = Vector2.UP.rotated(inclina)
	e._tam = maxf(e._ancho * 0.6, 10.0) * (0.7 if m == Modo.FRENESI else 1.0)
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._delante = e._capa(Z_ENCIMA, false)
	e._brillo = e._capa(Z_ENCIMA + 1, true)
	return e


func duracion() -> float:
	match modo:
		Modo.POLVO: return T_POLVO + 0.7
	return T_CERRADO + T_IRSE


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
	if _t >= duracion():
		queue_free()
		return
	for n in [_suelo, _delante, _brillo]:
		if n != null:
			(n as Node2D).queue_redraw()


func _dibujar_capa(capa: Node2D) -> void:
	match modo:
		Modo.POLVO: _polvo(capa)
		_: _mordisco(capa)


# ------------------------------------------------------------
#  EL MORDISCO
# ------------------------------------------------------------
# Dos mandibulas, una a cada lado del eje, que se cierran hacia el. Mientras viaja el golpe (t < 0) se van
# juntando, cada vez mas deprisa; en el golpe chocan (destello) y tiran un pelin hacia quien muerde; luego se van.
func _mordisco(capa: Node2D) -> void:
	var perp: Vector2 = _boca
	var cierre: float    # 0 = abiertas del todo, 1 = cerradas
	var alfa: float = 1.0
	var tiron := Vector2.ZERO
	if _t < 0.0:
		var u: float = clampf(1.0 + _t / _viaje, 0.0, 1.0)
		cierre = u * u
		alfa = clampf(u * 3.0, 0.0, 1.0)
	else:
		cierre = 1.0
		var kt: float = clampf(_t / T_CERRADO, 0.0, 1.0)
		tiron = -_eje * _tam * 0.35 * sin(PI * minf(kt * 1.6, 1.0))
		alfa = 1.0 - smoothstep(T_CERRADO, T_CERRADO + T_IRSE, _t)
	if capa == _brillo:
		if _t >= 0.0 and _t < 0.14:
			BarridoAire.destello(capa, _hasta + tiron, _tam * 0.9, Color(1.0, 0.95, 0.85, 0.85 * (1.0 - _t / 0.14)),
				_boca.angle())
		return
	if capa != _delante:
		return
	var abre: float = lerpf(_tam * 1.25, _tam * 0.2, cierre)
	for lado in [-1.0, 1.0]:
		_mandibula(capa, _hasta + tiron + perp * lado * abre, perp * -lado, alfa)


# Una MANDIBULA: media luna llena (la boca, oscura, con un halo difuminado detras) y los colmillos de hueso
# apuntando hacia 'hacia' (el eje del mordisco). 'c' = el centro de su filo.
func _mandibula(ci: CanvasItem, c: Vector2, hacia: Vector2, alfa: float) -> void:
	if alfa <= 0.01:
		return
	var r: float = _tam
	var lado := Vector2(-hacia.y, hacia.x)
	var abre: float = deg_to_rad(62.0)
	# La media luna: el arco de fuera (lejos del eje) y el de dentro (el filo), mas plano.
	var fuera := PackedVector2Array()
	var dentro := PackedVector2Array()
	var n: int = 12
	# Los dos arcos con el MISMO lado en cada punto (antes uno iba al reves que el otro, la media luna salia
	# cruzada y no se pintaba): el de fuera abombado hacia atras, el del filo casi recto.
	for i in n + 1:
		var a: float = lerpf(-abre, abre, float(i) / float(n))
		var lat: Vector2 = lado * sin(a) * r * 0.55
		fuera.append(c + lat - hacia * (cos(a) * r * 0.6 + r * 0.05))
		dentro.append(c + lat - hacia * cos(a) * r * 0.12)
	# EL HALO: la misma media luna un poco mas grande y casi transparente (el difuminado del filo).
	var halo_f := PackedVector2Array()
	var halo_d := PackedVector2Array()
	for i in fuera.size():
		halo_f.append(c + (fuera[i] - c) * 1.3)
		halo_d.append(c + (dentro[i] - c) * 1.1)
	_tira(ci, halo_f, halo_d, Color(BOCA, 0.28 * alfa))
	_tira(ci, fuera, dentro, Color(BOCA, 0.9 * alfa))
	# LOS COLMILLOS, del filo hacia dentro: el del medio mas corto, los dos de las puntas (los caninos) largos.
	var dientes: int = 5
	for k in dientes:
		var u: float = (float(k) + 0.5) / float(dientes)
		var i0: int = int(u * float(n))
		var base: Vector2 = dentro[i0]
		var ancho_d: float = r * 0.13
		var largo_d: float = r * (0.42 if k == 0 or k == dientes - 1 else 0.24)
		var b1: Vector2 = base - lado * ancho_d
		var b2: Vector2 = base + lado * ancho_d
		var punta: Vector2 = base + hacia * largo_d
		_poligono(ci, PackedVector2Array([b1, b2, punta]), Color(HUESO_SOMBRA, alfa))
		_poligono(ci, PackedVector2Array([b1 + lado * ancho_d * 0.35, b2, punta]), Color(HUESO, alfa))


# La banda entre dos arcos del mismo numero de puntos, en triangulos sueltos (no hay que triangular).
static func _tira(ci: CanvasItem, a: PackedVector2Array, b: PackedVector2Array, col: Color) -> void:
	if a.size() < 2 or a.size() != b.size() or col.a <= 0.0:
		return
	var pv := PackedVector2Array()
	pv.append_array(a)
	pv.append_array(b)
	var pc := PackedColorArray()
	pc.resize(pv.size())
	pc.fill(col)
	var n: int = a.size()
	var pi := PackedInt32Array()
	for i in n - 1:
		pi.append_array([i, i + 1, n + i, i + 1, n + i + 1, n + i])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)


static func _poligono(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3 or col.a <= 0.0:
		return
	var tri: PackedInt32Array = Geometry2D.triangulate_polygon(pts)
	if tri.is_empty():
		return
	var cols := PackedColorArray()
	cols.resize(pts.size())
	cols.fill(col)
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), tri, pts, cols)


# ------------------------------------------------------------
#  EL POLVO DEL ATERRIZAJE (Frenesi)
# ------------------------------------------------------------
func _polvo(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var k: float = clampf(_t / T_POLVO, 0.0, 1.0)
	var apaga: float = 1.0 - smoothstep(T_POLVO, T_POLVO + 0.7, _t)
	if capa == _suelo:
		# La mancha oscura del golpe en el suelo, que se va.
		_bola(capa, _o, _r * 0.45 * (0.6 + 0.4 * k), Color(0.2, 0.16, 0.12, 0.35 * apaga))
		return
	if capa != _delante:
		return
	# EL ANILLO DE POLVO: bocanadas que salen del centro hacia el borde, se hinchan y se desvanecen.
	for p in _puffs:
		var u: float = float(p["u"]) * (1.0 - pow(1.0 - k, 2.0))
		var c: Vector2 = _o + Vector2(cos(float(p["a"])), sin(float(p["a"]))) * _r * u \
			+ Vector2(0.0, -float(p["sube"]) * k * K)
		var rr: float = _r * float(p["tam"]) * (0.5 + 0.9 * k)
		_bola(capa, c, rr * 1.25, Color(POLVO, 0.22 * apaga))
		_bola(capa, c + Vector2(-rr * 0.2, -rr * 0.25), rr * 0.8, Color(POLVO_CLARO, 0.35 * apaga))
	# Unas piedrecitas que saltan y caen.
	for s in _piedras:
		var kv: float = clampf(_t / 0.5, 0.0, 1.0)
		if kv >= 1.0:
			continue
		var d := Vector2(cos(float(s["a"])), sin(float(s["a"])) * K)
		var p2: Vector2 = _o + d * float(s["v"]) * 0.5 * kv - Vector2(0.0, float(s["sube"]) * 4.0 * kv * (1.0 - kv) * K)
		_bola(capa, p2, float(s["tam"]), Color(0.3, 0.25, 0.2, 1.0 - kv))


# Una bola blanda: el centro lleno y el borde que se difumina a nada.
static func _bola(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	if r <= 0.3 or col.a <= 0.01:
		return
	var n: int = 16
	var pv := PackedVector2Array([c])
	var pc := PackedColorArray([col])
	var pi := PackedInt32Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		pv.append(c + Vector2(cos(a), sin(a)) * r)
		pc.append(Color(col, 0.0))
		pi.append_array([0, 1 + i, 1 + (i + 1) % n])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)
