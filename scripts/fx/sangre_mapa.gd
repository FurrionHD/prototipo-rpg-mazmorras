# ============================================================
#  sangre_mapa.gd
#  LA SANGRE DEL HACHA en el mapa (24/09/2026). El hacha es el arma que hace sangrar, y eso se ve en cada
#  golpe que ENTRA (los esquivados no): gotas que salen despedidas del cuerpo en la direccion del tajo,
#  como cometas pequeñas, caen y dejan unas manchitas en el suelo que se van. Y el SURCO del Desgarro:
#  el rastro que deja en el suelo el que sale arrastrado hacia ti.
#  Lo lanza CombatTactico al encajar cada golpe (CombatFX.impacto_visto), en todas las maquinas: el
#  espejo recibe los mismos golpes, asi que no cuesta red. Coordenadas de MUNDO.
# ============================================================
extends Node2D
class_name SangreMapa

const GRAVEDAD := 260.0
const T_VIVE := 1.6
const T_MANCHA := 0.7          # lo que se queda entera una mancha antes de irse
const T_MANCHA_APAGAR := 0.6
const T_SURCO := 0.5           # lo que sigue al cuerpo arrastrado
const COLOR := Color(0.55, 0.03, 0.05)
const OSCURA := Color(0.32, 0.02, 0.03)

var _t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _gotas: Array = []         # {p (suelo), v, z, vz, tam, caida (t de aterrizar o -1)}
var _suelo: Node2D = null
# El surco: a quien sigue y por donde ha pasado.
var _cuerpo: Node2D = null
var _pies_off: Vector2 = Vector2.ZERO
var _rastro: PackedVector2Array = PackedVector2Array()


# Gotas desde 'desde' (lo alto del cuerpo, en pantalla) hacia 'dir'. 'pies' = el suelo bajo el cuerpo:
# de ahi sale a que altura empiezan. 'fuerza' ~1 (mas con el Brutal o un critico).
static func salpicar(padre: Node, desde: Vector2, pies: Vector2, dir: Vector2, fuerza: float, semilla: int) -> void:
	if padre == null:
		return
	var s := SangreMapa.new()
	s._rng.seed = semilla
	s._montar(padre)
	var d: Vector2 = dir.normalized() if dir.length_squared() > 0.0001 else Vector2.RIGHT
	var h0: float = maxf(pies.y - desde.y, 0.0) / SueloRoto.K_ALTO
	for i in int(round(6.0 + 7.0 * fuerza)):
		var v: Vector2 = d.rotated(s._rng.randf_range(-0.55, 0.55)) * s._rng.randf_range(35.0, 105.0) * sqrt(fuerza)
		s._gotas.append({"p": Vector2(desde.x, pies.y) + Vector2(s._rng.randf_range(-3.0, 3.0), s._rng.randf_range(-2.0, 2.0)),
			"v": v, "z": h0 + s._rng.randf_range(-3.0, 3.0), "vz": s._rng.randf_range(15.0, 60.0),
			"tam": s._rng.randf_range(1.1, 2.3), "caida": -1.0})


# El surco del que sale arrastrado: sigue a 'cuerpo' un rato y deja dos marcas por donde pasa.
static func surco(padre: Node, cuerpo: Node2D, pies_off: Vector2) -> void:
	if padre == null or not is_instance_valid(cuerpo):
		return
	var s := SangreMapa.new()
	s._montar(padre)
	s._cuerpo = cuerpo
	s._pies_off = pies_off
	s._rastro.append(cuerpo.global_position + pies_off)


func _montar(padre: Node) -> void:
	z_as_relative = false
	z_index = Game.Z_PERSONAJES + 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(self)
	_suelo = Node2D.new()
	_suelo.z_as_relative = false
	_suelo.z_index = SueloRoto.Z_SUELO
	add_child(_suelo)
	_suelo.draw.connect(_dibujar_suelo)


func _process(delta: float) -> void:
	_t += delta * maxf(BarridoAire.ritmo, 0.05)
	if _t >= T_VIVE:
		queue_free()
		return
	for g in _gotas:
		if float(g["caida"]) >= 0.0:
			continue
		g["p"] = (g["p"] as Vector2) + (g["v"] as Vector2) * delta
		g["vz"] = float(g["vz"]) - GRAVEDAD * delta
		g["z"] = float(g["z"]) + float(g["vz"]) * delta
		if float(g["z"]) <= 0.0:
			g["z"] = 0.0
			g["caida"] = _t
	if _cuerpo != null:
		if _t <= T_SURCO and is_instance_valid(_cuerpo):
			var p: Vector2 = _cuerpo.global_position + _pies_off
			if p.distance_to(_rastro[_rastro.size() - 1]) > 0.8:
				_rastro.append(p)
	queue_redraw()
	_suelo.queue_redraw()


# Las gotas en el aire: una cometa por gota, orientada con su caida.
func _draw() -> void:
	for g in _gotas:
		if float(g["caida"]) >= 0.0:
			continue
		var p: Vector2 = (g["p"] as Vector2) + Vector2(0.0, -float(g["z"]) * SueloRoto.K_ALTO)
		var vel: Vector2 = (g["v"] as Vector2) + Vector2(0.0, -float(g["vz"]) * SueloRoto.K_ALTO)
		var cola: Vector2 = p - vel.normalized() * minf(vel.length() * 0.045, 6.0)
		BarridoAire.cometa(self, cola, p, float(g["tam"]), Color(COLOR, 0.95))


# Las manchas que dejan al caer (redondas: el suelo no se achata) y el surco.
func _dibujar_suelo() -> void:
	for g in _gotas:
		var tc: float = float(g["caida"])
		if tc < 0.0:
			continue
		var k: float = _t - tc
		var alfa: float = 1.0 - clampf((k - T_MANCHA) / T_MANCHA_APAGAR, 0.0, 1.0)
		if alfa <= 0.0:
			continue
		var r: float = float(g["tam"]) * (0.8 + 0.4 * clampf(k / 0.08, 0.0, 1.0))
		_suelo.draw_circle(g["p"], r, Color(OSCURA, 0.8 * alfa))
	if _rastro.size() < 2:
		return
	var alfa_s: float = 1.0 - clampf((_t - T_SURCO - 0.3) / 0.6, 0.0, 1.0)
	if alfa_s <= 0.0:
		return
	# Dos surcos paralelos, finos, oscuros en el centro y difuminados a los lados; del principio (tenue)
	# al cuerpo (fuerte).
	var n: int = _rastro.size() - 1
	for lado in [-3.0, 3.0]:
		for i in n:
			var a: Vector2 = _rastro[i]
			var b: Vector2 = _rastro[i + 1]
			var d: Vector2 = (b - a).normalized().orthogonal() if b.distance_squared_to(a) > 0.0001 else Vector2.UP
			var l0: float = alfa_s * (0.3 + 0.7 * float(i) / float(n))
			var l1: float = alfa_s * (0.3 + 0.7 * float(i + 1) / float(n))
			var a0: Vector2 = a + d * lado
			var b0: Vector2 = b + d * lado
			var co0 := Color(SueloRoto.OSCURO, 0.6 * l0)
			var co1 := Color(SueloRoto.OSCURO, 0.6 * l1)
			var tr := Color(SueloRoto.OSCURO, 0.0)
			for m in [1.0, -1.0]:
				_suelo.draw_primitive(PackedVector2Array([a0, b0, b0 + d * 1.3 * m]), PackedColorArray([co0, co1, tr]), PackedVector2Array())
				_suelo.draw_primitive(PackedVector2Array([a0, b0 + d * 1.3 * m, a0 + d * 1.3 * m]), PackedColorArray([co0, tr, tr]), PackedVector2Array())
	# Polvo donde va el cuerpo mientras lo arrastran.
	if _t <= T_SURCO + 0.2:
		var k2: float = clampf(_t / (T_SURCO + 0.2), 0.0, 1.0)
		BarridoAire.brillo(_suelo, _rastro[n], 5.0 + 4.0 * k2, Color(SueloRoto.POLVO, 0.4 * (1.0 - k2)))
