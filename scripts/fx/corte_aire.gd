# ============================================================
#  corte_aire.gd
#  EL TAJO DEL VERDUGO en el mapa (24/09/2026). Sus referencias: dos viñetas de manhwa con un tajo
#  enorme que sale del arma y AVANZA como una rafaga de aire afilada, levantando piedras y dejando el
#  suelo rajado. Aqui:
#    - la CUCHILLA: una media luna de aire DE PIE sobre el suelo, cruzada a la linea, que corre de tus
#      pies a la punta. Su ancho es el de la huella en cada punto, asi que se va afilando con ella;
#    - su ESTELA: copias que se quedan atras apagandose y rayas de velocidad;
#    - a los lados, POLVO y PIEDRAS que salta a su paso;
#    - en el suelo, detras, la RAJA del tajo, que se queda un poco y se apaga.
#  EL DAÑO VA CON LA CUCHILLA: retraso() dice cuando llega a cada punto, con la misma cuenta con la que
#  se dibuja (via SueloRoto.retraso, tipo CORTE).
#
#  El suelo (la raja, el polvo bajo) va a z de suelo; lo que esta en el aire (la cuchilla, las piedras,
#  las rayas) en su propio nodo por ENCIMA de los cuerpos. Todo sale de una semilla: igual en todas las
#  maquinas.
# ============================================================
extends Node2D
class_name CorteAire

const T_VIAJE := 0.38        # lo que tarda la cuchilla en llegar a la punta
const T_QUIETO := 0.2        # la raja entera antes de irse
const T_APAGAR := 0.7
const K_ALTO := SueloRoto.K_ALTO
const ALTO := 1.5           # alto del tajo, en veces el ancho de la huella en ese punto
const ECHADA := 0.55         # lo que se echa hacia atras la punta, en veces su alto
const BASE := 0.6            # lo ancho que es abajo, en veces su alto
const GRUESO := 0.07         # medio grosor abajo, en veces su alto (de canto es lo que se ve)
const BLANCO := Color(0.97, 0.98, 1.0)
const AIRE := Color(0.72, 0.80, 0.92)
const POLVO := SueloRoto.POLVO
const PIEDRA := SueloRoto.PIEDRA
const OSCURO := SueloRoto.OSCURO
const LABIO := SueloRoto.LABIO

var forma: CombatFormas.Forma = null
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _dir: Vector2 = Vector2.RIGHT
var _nor: Vector2 = Vector2.DOWN
var _largo: float = 1.0
var _aire: Node2D = null
var _raja: PackedVector2Array = PackedVector2Array()   # la raja del medio, del pie a la punta
var _rajitas: Array = []      # grietas cortas que salen de la raja: {pts, s}
var _rayas: Array = []        # rayas de velocidad: {u (de lado a lado), largo, atras}
var _polvo: Array = []        # bocanadas a los lados: {s, lado, r, sale}
var _piedras: Array = []      # {s, lado, v: Vector2 (fuera, arriba), tam, rot, vrot}


static func lanzar(padre: Node, f: CombatFormas.Forma, semilla: int, espera: float) -> CorteAire:
	if padre == null or f == null:
		return null
	var c := CorteAire.new()
	c.forma = f
	c._rng.seed = semilla
	c._t = -maxf(espera, 0.0)
	c.z_as_relative = false
	c.z_index = SueloRoto.Z_SUELO
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(c)
	return c


# Cuando llega la cuchilla a 'd' px de tus pies. Corre a velocidad fija: es aire lanzado, no una grieta
# que frena.
static func retraso_px(d: float, largo: float) -> float:
	return T_VIAJE * clampf(d / maxf(largo, 1.0), 0.0, 1.0)


func duracion() -> float:
	return T_VIAJE + T_QUIETO + T_APAGAR


func _ready() -> void:
	_dir = forma.dir.normalized()
	_nor = Vector2(-_dir.y, _dir.x)
	_largo = maxf(forma.largo, 8.0)
	# LA RAJA: quebrada, siempre hacia delante.
	var n: int = maxi(8, int(_largo / 5.0))
	for i in n + 1:
		var s: float = _largo * float(i) / float(n)
		var lado: float = 0.0 if i == 0 else _rng.randf_range(-1.6, 1.6)
		_raja.append(forma.origen + _dir * s + _nor * lado)
	for _k in maxi(3, int(_largo / 22.0)):
		var s2: float = _rng.randf_range(0.1, 0.9) * _largo
		var base: Vector2 = forma.origen + _dir * s2
		var sig: float = 1.0 if _rng.randf() < 0.5 else -1.0
		var ang: float = _dir.angle() + sig * _rng.randf_range(0.5, 1.1)
		var largo_g: float = forma.ancho_en(s2) * _rng.randf_range(0.2, 0.45)
		var pts := PackedVector2Array([base])
		var p: Vector2 = base
		for _j in 4:
			p += Vector2(cos(ang), sin(ang)) * largo_g * 0.25 + _nor * _rng.randf_range(-0.8, 0.8)
			pts.append(p)
		_rajitas.append({"pts": pts, "s": s2})
	for _k in 7:
		_rayas.append({"u": _rng.randf_range(-0.9, 0.9), "largo": _rng.randf_range(14.0, 34.0),
			"atras": _rng.randf_range(0.0, 16.0), "z": _rng.randf_range(0.1, 0.9)})
	for _k in maxi(6, int(_largo / 12.0)):
		_polvo.append({"s": _rng.randf_range(0.05, 1.0) * _largo, "lado": 1.0 if _rng.randf() < 0.5 else -1.0,
			"r": _rng.randf_range(3.0, 6.5), "sale": _rng.randf_range(6.0, 16.0)})
	for _k in maxi(8, int(_largo / 10.0)):
		var poly := PackedVector2Array()
		var tam: float = _rng.randf_range(1.2, 2.8)
		for q in 5:
			var aq: float = TAU * float(q) / 5.0 + _rng.randf_range(-0.3, 0.3)
			poly.append(Vector2(cos(aq), sin(aq)) * tam * _rng.randf_range(0.7, 1.2))
		_piedras.append({"s": _rng.randf_range(0.05, 1.0) * _largo, "lado": 1.0 if _rng.randf() < 0.5 else -1.0,
			"v": Vector2(_rng.randf_range(25.0, 60.0), _rng.randf_range(60.0, 120.0)), "poly": poly,
			"rot": _rng.randf_range(0.0, TAU), "vrot": _rng.randf_range(-14.0, 14.0)})
	_aire = Node2D.new()
	_aire.z_as_relative = false
	_aire.z_index = Game.Z_PERSONAJES + 80
	add_child(_aire)
	_aire.draw.connect(_dibujar_aire)


func _process(delta: float) -> void:
	_t += delta
	if _t >= duracion():
		queue_free()
		return
	queue_redraw()
	_aire.queue_redraw()


# Por donde va la cuchilla (px desde tus pies).
func _va() -> float:
	return _largo * clampf(_t / T_VIAJE, 0.0, 1.0)


func _alfa_suelo() -> float:
	return 1.0 - clampf((_t - T_VIAJE - T_QUIETO) / T_APAGAR, 0.0, 1.0)


# Un punto de la cuchilla puesta a 's' px: 'u' de abajo (-1, en el suelo) a arriba (1, la punta) y 'z' de
# atras (0) al FILO (1). Es un TAJO VERTICAL en el plano del corte (el que contiene hacia donde va), como
# sus referencias: de lado se ve entero y al norte o al sur de canto, casi una linea. Y con SU forma (su
# dibujo, 24/09): como una aleta, ANCHA ABAJO y AFILADA ARRIBA, con la punta echada hacia atras; el filo
# de delante combado y el de atras hundido.
func _en_cuchilla(s: float, u: float, z: float, lado: float = 0.0) -> Vector2:
	var alto: float = maxf(forma.ancho_en(s), 6.0) * ALTO
	var v: float = clampf((u + 1.0) * 0.5, 0.0, 1.0)
	var delante: float = -alto * ECHADA * v * v                                  # el filo: sube y se va hacia atras
	var detras: float = -alto * (BASE * pow(1.0 - v, 1.4) + ECHADA * v)          # el lomo: hundido
	# 'lado' (-1..1): el GROSOR del corte, que solo se ve de canto (al norte o al sur): ancho abajo y
	# nada en la punta, como el resto.
	var grueso: float = alto * GRUESO * pow(1.0 - v, 0.8) * z
	return forma.origen + _dir * (s + lerpf(detras, delante, z)) + _nor * lado * grueso 		+ Vector2(0.0, -alto * v * K_ALTO)


# ------------------------------------------------------------
#  EL SUELO: la raja y el polvo bajo
# ------------------------------------------------------------
func _draw() -> void:
	if _t < 0.0:
		return
	var a: float = _alfa_suelo()
	var va: float = _va()
	# La raja, hasta donde ha pasado la cuchilla; mas gruesa cerca de ti.
	for i in _raja.size() - 1:
		var s: float = (_raja[i] - forma.origen).dot(_dir)
		if s > va:
			break
		var w: float = lerpf(3.2, 1.0, s / _largo)
		draw_line(_raja[i] + Vector2(0.6, 1.2), _raja[i + 1] + Vector2(0.6, 1.2), Color(LABIO, 0.4 * a), w * 0.6)
		draw_line(_raja[i], _raja[i + 1], Color(OSCURO, 0.95 * a), w)
	for g in _rajitas:
		if float(g["s"]) > va:
			continue
		var pts: PackedVector2Array = g["pts"]
		draw_polyline(pts, Color(OSCURO, 0.85 * a), 1.2)
	# El polvo que levanta al pasar: sale hacia fuera y se abre.
	for p in _polvo:
		var tp: float = _t - retraso_px(float(p["s"]), _largo)
		if tp < 0.0 or tp > 0.9:
			continue
		var k: float = tp / 0.9
		var h: float = forma.ancho_en(float(p["s"])) * 0.5
		var c: Vector2 = forma.origen + _dir * float(p["s"]) \
			+ _nor * float(p["lado"]) * (h + float(p["sale"]) * (1.0 - pow(1.0 - k, 2.0)))
		draw_circle(c, float(p["r"]) * (1.0 + 1.2 * k), Color(POLVO, 0.38 * (1.0 - k)))


# ------------------------------------------------------------
#  EL AIRE: la cuchilla, su estela, las rayas y las piedras
# ------------------------------------------------------------
func _dibujar_aire() -> void:
	if _t < 0.0:
		return
	var va: float = _va()
	# La cuchilla vive mientras viaja y se deshace un momento al llegar a la punta.
	var llega: float = clampf((_t - T_VIAJE) / 0.12, 0.0, 1.0)
	var a_c: float = 1.0 - llega
	if a_c > 0.0:
		# LA ESTELA: la misma cuchilla, atras y cada vez mas tenue.
		for k in range(4, 0, -1):
			var sk: float = va - float(k) * 7.0
			if sk < 0.0:
				continue
			_cuchilla(sk, Color(AIRE, 0.22 * a_c * (1.0 - float(k) / 5.0)), 1.0 - 0.1 * float(k))
		# Las rayas de velocidad, detras.
		for r in _rayas:
			var s0: float = va - float(r["atras"])
			var s1: float = s0 - float(r["largo"])
			if s0 <= 0.0:
				continue
			var p0: Vector2 = _en_cuchilla(s0, float(r["u"]), float(r["z"]))
			var p1: Vector2 = p0 - _dir * (s0 - maxf(s1, 0.0))
			BarridoAire.cometa(_aire, p1, p0, 1.6, Color(BLANCO, 0.35 * a_c * (1.0 - 0.7 * absf(_dir.y))))
		_cuchilla(va, Color(BLANCO, 0.95 * a_c), 1.0)
	# Las piedras que salta a su paso: hacia fuera y hacia arriba, girando, y caen.
	for pz in _piedras:
		var tp: float = _t - retraso_px(float(pz["s"]), _largo)
		if tp < 0.0:
			continue
		var v: Vector2 = pz["v"]
		var z: float = v.y * tp - SueloRoto.GRAVEDAD_PIEDRAS * tp * tp
		if z < 0.0:
			continue
		var h: float = forma.ancho_en(float(pz["s"])) * 0.5
		var suelo: Vector2 = forma.origen + _dir * (float(pz["s"]) + v.x * 0.3 * tp) \
			+ _nor * float(pz["lado"]) * (h * 0.6 + v.x * tp)
		var c: Vector2 = suelo + Vector2(0.0, -z * K_ALTO)
		var rot: float = float(pz["rot"]) + float(pz["vrot"]) * tp
		var cara := PackedVector2Array()
		for q in pz["poly"]:
			cara.append(c + (q as Vector2).rotated(rot))
		_aire.draw_colored_polygon(cara, PIEDRA)


# Una media luna de aire puesta a 's': el filo de delante (el suelo combado) y el lomo por detras, con
# el nucleo blanco pegado al filo. 'esc' la encoge (la estela).
func _cuchilla(s: float, col: Color, esc: float) -> void:
	# SIN RAYA en el filo (lo pidio: "que sea un corte, no una linea delante"): el borde de delante es DURO
	# porque ahi la lamina es blanca y opaca, y hacia atras se DIFUMINA hasta nada.
	var n_alto: int = 10
	var zs: Array = [0.0, 0.35, 0.6, 0.8, 0.93, 1.0]
	var filas: Array = []
	for z in zs:
		var fila := PackedVector2Array()
		for i in n_alto + 1:
			fila.append(_en_cuchilla(s, lerpf(-1.0, 1.0, float(i) / float(n_alto)) * esc, z))
		filas.append(fila)
	for k in filas.size() - 1:
		var za: float = float(zs[k + 1])
		var zb: float = float(zs[k])
		_banda(filas[k + 1], filas[k], _color_lamina(za, col), _color_lamina(zb, col))
	# LA CARA DE DELANTE, con su grosor: de lado se funde con el filo; de canto (norte, sur) es lo que se
	# ve, una cuña blanca ancha abajo y afilada arriba, con un halo que se difumina.
	for par in [[1.0, 2.2, 0.3], [1.0, 1.0, 1.0]]:
		var izq := PackedVector2Array()
		var der := PackedVector2Array()
		for i in n_alto + 1:
			var u: float = lerpf(-1.0, 1.0, float(i) / float(n_alto)) * esc
			izq.append(_en_cuchilla(s, u, float(par[0]), -float(par[1])))
			der.append(_en_cuchilla(s, u, float(par[0]), float(par[1])))
		_banda(izq, der, Color(BLANCO, col.a * float(par[2])))


# El color de la lamina de atras (0) al filo (1): transparente y azulado atras, blanco y opaco delante.
func _color_lamina(z: float, col: Color) -> Color:
	return Color(AIRE.lerp(BLANCO, z), col.a * pow(z, 1.8))


# Rellena la banda entre dos lineas del mismo largo, a triangulos (nunca falla aunque se cruce), con el
# color 'ca' en la primera y 'cb' en la segunda.
func _banda(a: PackedVector2Array, b: PackedVector2Array, ca: Color, cb: Color = Color(0, 0, 0, -1)) -> void:
	if cb.a < 0.0:
		cb = ca
	for i in a.size() - 1:
		_aire.draw_primitive(PackedVector2Array([a[i], a[i + 1], b[i + 1]]),
			PackedColorArray([ca, ca, cb]), PackedVector2Array())
		_aire.draw_primitive(PackedVector2Array([a[i], b[i + 1], b[i]]),
			PackedColorArray([ca, cb, cb]), PackedVector2Array())
