# ============================================================
#  baba_suelo.gd  (class_name BabaSuelo)
#  LA BABA QUE SE QUEDA EN EL SUELO de las mutaciones del slime (06/10, su diagnostico: "los charcos y las puas son
#  feos: tendria que ser un charco UNICO y que sea god"). Antes era el charco de la savia repetido en fila; ahora es UNA
#  mancha de gel del color de su slime:
#    - el RASTRO del Placaje: una sola mancha alargada por lo que recorrio (forma LINEA);
#    - el CHARCO del Reventon: una mancha redonda con salpicones (forma CIRCULO).
#  Borde irregular y vivo (lobulos, algun dedo de salpicadura), gotas sueltas alrededor, el gel translucido con sus
#  zonas mas claras, brillos alargados y alguna burbuja lenta. Con 'pinchos', puas de cristal como las del slime clavadas
#  de pie (y alguna caida). Se encoge y se apaga al secarse (queda), y se va con secar(), como el de la savia.
#  Lo pinta CombatTactico._charco_visible (y la columna de ver_ataques_dirs).
# ============================================================
extends Node2D
class_name BabaSuelo

const T_ENTRA := 0.18
const T_SECA := 0.6
const CRISTAL := Color(0.55, 0.95, 1.0)
const CRISTAL_OSCURO := Color(0.16, 0.42, 0.55)

var queda: float = 1.0                 # lo que le queda (1 = recien echado); se encoge y se apaga con ello
var _t: float = 0.0
var _secando: float = -1.0
var _col: Color = Color(0.85, 0.2, 0.2)
var _linea: bool = false
var _a: Vector2 = Vector2.ZERO         # LINEA: de donde a donde; CIRCULO: el centro en _a
var _b: Vector2 = Vector2.ZERO
var _w: float = 10.0                   # media anchura (LINEA) o radio (CIRCULO)
var _borde: PackedVector2Array = PackedVector2Array()   # el contorno, ya irregular (relativo al centro)
var _normales: PackedVector2Array = PackedVector2Array()   # hacia fuera en cada punto del contorno (para su orla)
var _centro: Vector2 = Vector2.ZERO
var _gotas: Array = []                 # {p, r}: las sueltas alrededor
var _claros: Array = []                # {p, r}: donde el gel se acumula (mas claro)
var _brillos: Array = []               # {p, l, a}: los reflejos alargados
var _burbujas: Array = []              # {p, r, per, fase}
var _pinchos: Array = []               # {p, l, w, a, caido}
var _rng := RandomNumberGenerator.new()
var _suelo: Node2D = null
var _encima: Node2D = null


# 'f' = la forma (LINEA o CIRCULO) en coordenadas del padre.
static func crear(padre: Node, f: CombatFormas.Forma, col: Color, pinchos: bool, semilla: int) -> BabaSuelo:
	if padre == null or f == null:
		return null
	var b := BabaSuelo.new()
	b._rng.seed = hash(semilla)
	b._col = col
	b.z_as_relative = false
	b.z_index = SueloRoto.Z_SUELO
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(b)
	if f.tipo == CombatFormas.Tipo.LINEA:
		b._linea = true
		b._a = f.origen
		b._b = f.origen + f.dir.normalized() * maxf(f.largo, 4.0)
		b._w = maxf(f.ancho * 0.5, 5.0)
	else:
		b._a = f.centro
		b._b = f.centro
		b._w = maxf(f.radio, 6.0)
	b._centro = (b._a + b._b) * 0.5
	b._formar(pinchos)
	b._suelo = b._capa(SueloRoto.Z_SUELO)
	b._encima = b._capa(SueloRoto.Z_SUELO + 1)
	return b


func _capa(z: int) -> Node2D:
	var c := Node2D.new()
	c.z_as_relative = false
	c.z_index = z
	c.draw.connect(_pintar.bind(c))
	add_child(c)
	return c


# EL CONTORNO: el de una capsula (linea) o un circulo, empujado hacia fuera y hacia dentro por un ruido suave, con
# unos pocos LOBULOS gordos y algun DEDO de salpicadura. Todo relativo al centro, para encogerlo al secarse.
func _formar(pinchos: bool) -> void:
	var fases: Array = []
	for i in 4:
		fases.append(_rng.randf_range(0.0, TAU))
	var dedos: Array = []
	for i in _rng.randi_range(2, 4):
		dedos.append({"u": _rng.randf(), "ancho": _rng.randf_range(0.025, 0.05), "largo": _rng.randf_range(0.3, 0.6)})
	var lobulos: Array = []
	for i in _rng.randi_range(3, 5):
		lobulos.append({"u": _rng.randf(), "ancho": _rng.randf_range(0.06, 0.12), "alto": _rng.randf_range(0.12, 0.25)})
	var dir: Vector2 = (_b - _a).normalized() if _linea and _a.distance_to(_b) > 0.1 else Vector2.RIGHT
	var nor: Vector2 = dir.orthogonal()
	var largo: float = _a.distance_to(_b) if _linea else 0.0
	var perim: float = 2.0 * largo + TAU * _w
	var n: int = clampi(roundi(perim / 3.0), 32, 160)
	for i in n:
		var u: float = float(i) / float(n)
		var s: float = u * perim
		var base: Vector2
		var normal: Vector2
		if s < largo:                                   # el lado derecho, de A a B
			base = _a + dir * s + nor * _w
			normal = nor
		elif s < largo + PI * _w:                       # la punta de B
			var ang: float = nor.angle() + (s - largo) / _w
			normal = Vector2(cos(ang), sin(ang))
			base = _b + normal * _w
		elif s < 2.0 * largo + PI * _w:                 # el lado izquierdo, de B a A
			base = _b - dir * (s - largo - PI * _w) - nor * _w
			normal = -nor
		else:                                           # la punta de A
			var ang2: float = (-nor).angle() + (s - 2.0 * largo - PI * _w) / _w
			normal = Vector2(cos(ang2), sin(ang2))
			base = _a + normal * _w
		var ruido: float = 0.10 * sin(u * TAU * 3.0 + fases[0]) + 0.07 * sin(u * TAU * 7.0 + fases[1]) \
			+ 0.04 * sin(u * TAU * 13.0 + fases[2])
		for lb in lobulos:
			var dl: float = absf(_frac_dist(u, float(lb["u"])))
			ruido += float(lb["alto"]) * exp(-pow(dl / float(lb["ancho"]), 2.0))
		for dd in dedos:
			var dd2: float = absf(_frac_dist(u, float(dd["u"])))
			ruido += float(dd["largo"]) * exp(-pow(dd2 / float(dd["ancho"]), 2.0))
		_borde.append(base + normal * _w * ruido - _centro)
		_normales.append(normal)
	# LAS GOTAS SUELTAS de alrededor (salpicadas al echarla).
	for i in _rng.randi_range(5, 9) + int(largo / 20.0):
		var k: int = _rng.randi_range(0, _borde.size() - 1)
		var hacia: Vector2 = _normales[k]
		_gotas.append({"p": _borde[k] + hacia * _rng.randf_range(3.0, 9.0), "r": _rng.randf_range(1.2, 2.6)})
	# DONDE SE ACUMULA (mas claro) y LOS REFLEJOS: dentro, hacia arriba (la luz viene de arriba a la izquierda).
	var area: float = PI * _w * _w + 2.0 * _w * largo
	for i in clampi(roundi(area / 140.0), 2, 9):
		_claros.append({"p": _punto_dentro(0.55), "r": _w * _rng.randf_range(0.35, 0.6)})
	for i in clampi(roundi(area / 260.0), 1, 6):
		var pb: Vector2 = _punto_dentro(0.5) + Vector2(-_w * 0.15, -_w * 0.25)
		_brillos.append({"p": pb, "l": _rng.randf_range(4.0, 9.0), "a": _rng.randf_range(-0.6, -0.2)})
	for i in clampi(roundi(area / 220.0), 1, 5):
		_burbujas.append({"p": _punto_dentro(0.6), "r": _rng.randf_range(1.3, 2.4), "per": _rng.randf_range(1.6, 3.0),
			"fase": _rng.randf()})
	# LOS PINCHOS, repartidos sin amontonarse (un intento por hueco) y alguno caido de lado.
	if pinchos:
		var quiere: int = clampi(roundi(area / 110.0), 3, 16)
		var sep: float = clampf(sqrt(area / float(quiere)) * 0.8, 6.0, 18.0)
		var intentos: int = 0
		while _pinchos.size() < quiere and intentos < quiere * 30:
			intentos += 1
			var p: Vector2 = _punto_dentro(0.78)
			var libre: bool = true
			for q in _pinchos:
				if (q["p"] as Vector2).distance_to(p) < sep:
					libre = false
					break
			if libre:
				_pinchos.append({"p": p, "l": _rng.randf_range(9.0, 14.0), "w": _rng.randf_range(4.0, 5.2),
					"a": _rng.randf_range(-0.45, 0.45), "caido": _rng.randf() < 0.18})
		_pinchos.sort_custom(func(x, y): return (x["p"] as Vector2).y < (y["p"] as Vector2).y)


# Distancia con vuelta entre dos fracciones del contorno (0..1).
static func _frac_dist(a: float, b: float) -> float:
	var d: float = fposmod(a - b + 0.5, 1.0) - 0.5
	return d


# Un punto al azar dentro de la forma, sin pasar de 'margen' de su anchura.
func _punto_dentro(margen: float) -> Vector2:
	var u: float = _rng.randf()
	var en_linea: Vector2 = _a.lerp(_b, u) - _centro
	var r: float = _w * margen * sqrt(_rng.randf())
	var ang: float = _rng.randf_range(0.0, TAU)
	return en_linea + Vector2(cos(ang), sin(ang)) * r


func _process(delta: float) -> void:
	_t += delta
	if _secando >= 0.0 and _t - _secando > T_SECA:
		queue_free()
		return
	_suelo.queue_redraw()
	_encima.queue_redraw()


func secar() -> void:
	if _secando < 0.0:
		_secando = _t


func _pintar(capa: Node2D) -> void:
	var entra: float = clampf(_t / T_ENTRA, 0.0, 1.0)
	var sale: float = 1.0 if _secando < 0.0 else 1.0 - clampf((_t - _secando) / T_SECA, 0.0, 1.0)
	var alfa: float = entra * sale
	if alfa <= 0.0:
		return
	# Al echarse se ABRE desde el centro; al secarse se ENCOGE.
	var esc: float = lerpf(0.5, 1.0, 1.0 - pow(1.0 - entra, 2.0)) * lerpf(0.65, 1.0, clampf(queda, 0.0, 1.0))
	var c: Vector2 = _centro
	if capa == _suelo:
		var pts := PackedVector2Array()
		var pts_borde := PackedVector2Array()
		for i in _borde.size():
			pts.append(c + _borde[i] * esc)
			pts_borde.append(c + _borde[i] * esc + _normales[i] * 1.6)
		var oscuro: Color = _col.darkened(0.55)
		var cuerpo: Color = _col
		var claro: Color = _col.lightened(0.35)
		capa.draw_colored_polygon(pts_borde, Color(oscuro, 0.85 * alfa))
		capa.draw_colored_polygon(pts, Color(cuerpo.darkened(0.12), 0.72 * alfa))
		for g in _gotas:
			var pg: Vector2 = c + (g["p"] as Vector2) * esc
			capa.draw_circle(pg, float(g["r"]) * esc + 0.8, Color(oscuro, 0.85 * alfa))
			capa.draw_circle(pg, float(g["r"]) * esc, Color(cuerpo, 0.8 * alfa))
		# (difuminados: cuatro circulos de mas grande a mas pequeño, cada uno muy flojo; de uno solo se veian discos)
		for cl in _claros:
			for k in 4:
				var rk: float = float(cl["r"]) * esc * (1.0 - 0.22 * float(k))
				capa.draw_circle(c + (cl["p"] as Vector2) * esc, rk, Color(claro, 0.055 * alfa))
		return
	# ENCIMA: los reflejos, las burbujas y los pinchos.
	for br in _brillos:
		var pb: Vector2 = c + (br["p"] as Vector2) * esc
		var d := Vector2(cos(float(br["a"])), sin(float(br["a"])))
		var brillo: float = 0.55 + 0.25 * sin(_t * 2.0 + pb.x * 0.1)
		capa.draw_line(pb - d * float(br["l"]) * 0.5, pb + d * float(br["l"]) * 0.5, Color(1, 1, 1, brillo * alfa), 1.6)
	for bu in _burbujas:
		var ciclo: float = fposmod(_t / float(bu["per"]) + float(bu["fase"]), 1.0)
		var pb2: Vector2 = c + (bu["p"] as Vector2) * esc
		if ciclo < 0.85:
			var rb: float = float(bu["r"]) * (ciclo / 0.85)
			capa.draw_arc(pb2, rb, 0.0, TAU, 12, Color(_col.lightened(0.5), 0.7 * alfa), 1.0)
			capa.draw_circle(pb2 + Vector2(-rb * 0.35, -rb * 0.35), maxf(rb * 0.25, 0.4), Color(1, 1, 1, 0.7 * alfa))
	for pu in _pinchos:
		_pincho(capa, c + (pu["p"] as Vector2) * esc, pu, alfa, lerpf(0.55, 1.0, clampf(queda, 0.0, 1.0)))


# UN PINCHO de cristal clavado en la baba (o caido de lado): como los del slime, dos puntas, la cara clara arriba, la
# de abajo en sombra, el contorno oscuro y un brillo; con la marca oscura donde atraviesa y su sombra.
func _pincho(ci: CanvasItem, base: Vector2, pu: Dictionary, alfa: float, tam: float) -> void:
	var largo: float = float(pu["l"]) * tam
	var ancho: float = float(pu["w"]) * tam
	var eje: Vector2
	if bool(pu["caido"]):
		eje = Vector2(cos(float(pu["a"]) * 3.0), sin(float(pu["a"]) * 3.0) * 0.4).normalized()
	else:
		eje = Vector2(sin(float(pu["a"])), -1.0).normalized()   # de pie, algo inclinado
	# Su SOMBRA, tumbada hacia abajo a la derecha.
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-ancho * 0.4, 0.0), base + Vector2(ancho * 0.4, 0.0),
		base + Vector2(largo * 0.5, largo * 0.25)]), Color(0, 0, 0, 0.25 * alfa))
	# Donde atraviesa la baba: un anillo oscuro.
	ci.draw_circle(base, ancho * 0.6, Color(_col.darkened(0.6), 0.6 * alfa))
	var cola: Vector2 = base - eje * largo * 0.22
	var punta: Vector2 = base + eje * largo * 0.78
	var medio: Vector2 = base + eje * largo * 0.18
	var lado: Vector2 = eje.orthogonal() * ancho * 0.5
	var izq: Vector2 = medio + lado
	var der: Vector2 = medio - lado
	if izq.x > der.x:   # la cara clara, la de la IZQUIERDA (la luz viene de arriba a la izquierda)
		var tmp: Vector2 = izq
		izq = der
		der = tmp
	var borde := PackedVector2Array([punta + eje * 1.0, izq + (izq - medio).normalized(), cola - eje * 0.8,
		der + (der - medio).normalized()])
	ci.draw_colored_polygon(borde, Color(CRISTAL_OSCURO.darkened(0.4), alfa))
	ci.draw_colored_polygon(PackedVector2Array([punta, izq, cola, medio]), Color(CRISTAL.lightened(0.2), alfa))
	ci.draw_colored_polygon(PackedVector2Array([punta, medio, cola, der]), Color(CRISTAL_OSCURO.lightened(0.25), alfa))
	ci.draw_line(punta.lerp(izq, 0.3), medio.lerp(izq, 0.45), Color(1, 1, 1, 0.9 * alfa), 1.0)
