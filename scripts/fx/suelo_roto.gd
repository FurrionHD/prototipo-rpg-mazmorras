# ============================================================
#  suelo_roto.gd
#  EL SUELO QUE SE ROMPE bajo los golpes de area del martillo en el mapa (combate tactico). Lo pidio
#  el usuario el 23/09/2026, con un dibujo y una viñeta de manga de referencia:
#    GRIETAS      el Temblor: clavas el martillo a tus pies y salen grietas en circulo.
#    FRAGMENTOS   el Golpe sismico (en circulo, donde golpeas) y la Onda expansiva (en cono, hacia
#                 delante): mas que grietas, el suelo se parte en losas, como la viñeta.
#  Las dos cosas SALEN desde el centro hacia fuera (T_SALIR), se quedan un momento y se desvanecen
#  (T_APAGAR). EL DAÑO VA CON EL FRENTE: a cada uno le llega cuando la rotura le alcanza, y ese
#  instante lo dice retraso(), que es la misma cuenta con la que se dibuja el frente. Si se toca una,
#  se toca la otra sola.
#
#  Es suelo: coordenadas de MUNDO, sin achatar (como las huellas) y con z absoluto BAJO, por debajo de
#  los cuerpos. Todo sale de una SEMILLA, asi que en todas las maquinas la rotura es la misma.
# ============================================================
extends Node2D
class_name SueloRoto

#    ESTALLIDO    el Martillo de guerra (23/09): un golpe tan bestia que revienta el suelo como un GEISER
#                 DE POLVO, con piedras que saltan, y deja un crater con grietas que se escapan hacia fuera.
#    ESTELA       el Rompecorazas: no rompe el suelo, es la estela dentada del arma al balancearla. Vive
#                 en EstelaGolpe; va por aqui para compartir el camino (ficha, red, instante del golpe).
#    CORTE        el Tajo del verdugo (24/09): una cuchilla de aire que corre por la linea. Vive en CorteAire.
enum Tipo { GRIETAS, FRAGMENTOS, ESTALLIDO, ESTELA, CORTE }

const T_SALIR := 1.0      # lo que tarda el frente en llegar al borde
const T_SALIR_ESTALLIDO := 0.4   # el estallido es un golpe seco: sus grietas corren mucho mas
const T_QUIETO := 0.15    # lo que se queda entera antes de empezar a irse
const T_APAGAR := 1.0     # y lo que tarda en desvanecerse
const Z_SUELO := 2        # como AreaCuracion: sobre el suelo, bajo los cuerpos

# LA PERSPECTIVA (cerrado con el usuario, 23/09): el SUELO se pinta tal cual -- los circulos son
# circulos, igual que las huellas --, pero lo que se LEVANTA de el (las losas, las piedras que saltan)
# es altura, y la altura con la camara a 45 grados se ve a sin(45) = 0,707 (PlazaSprites.K).
const K_ALTO := 0.7071
const OSCURO := Color(0.03, 0.03, 0.05)
const LABIO := Color(0.78, 0.76, 0.72)

var tipo: int = Tipo.GRIETAS
var forma: CombatFormas.Forma = null
var nucleo: float = 0.0
var _t: float = 0.0
var _origen: Vector2 = Vector2.ZERO
var _radio: float = 1.0
var _a0: float = 0.0
var _a1: float = TAU
var _cono: bool = false
var _linea: bool = false
var _rng := RandomNumberGenerator.new()
var _ts: float = T_SALIR   # lo que tarda ESTE en abrirse (t_salir_de su tipo)

# Lo generado una vez. Grietas: [{pts, w}]. Fragmentos: radios, rayos y losas.
var _grietas: Array = []
var _crater: PackedVector2Array = PackedVector2Array()
var _rayos: Array = []        # por rayo: PackedVector2Array (su linea quebrada, del centro al borde)
var _anillos: Array = []      # por anillo: {r, pts: PackedVector2Array por los rayos}
var _losas: Array = []        # {poly, d, alza, piedras: [{v, t0}]}


# Lo pone en el suelo. 'padre' = algo en coordenadas de mundo (la arena).
# 'espera' = segundos hasta que el martillo toca el suelo (hasta entonces no se pinta nada).
static func lanzar(padre: Node, f: CombatFormas.Forma, t: int, semilla: int,
		n_nucleo: float = 0.0, espera: float = 0.0) -> Node2D:
	if padre == null or f == null:
		return null
	if t == Tipo.ESTELA:
		return EstelaGolpe.lanzar(padre, f, semilla, espera)
	if t == Tipo.CORTE:
		return CorteAire.lanzar(padre, f, semilla, espera)
	var s := SueloRoto.new()
	s.tipo = t
	s.forma = f
	s.nucleo = n_nucleo
	s._rng.seed = semilla
	s._t = -maxf(espera, 0.0)
	s.z_as_relative = false
	s.z_index = Z_SUELO
	s.process_mode = Node.PROCESS_MODE_ALWAYS   # la pelea tactica pausa el arbol
	padre.add_child(s)
	return s


# CUANDO LE LLEGA a 'p' (en mundo) la rotura de 'f', en segundos desde que golpeas. Es la inversa del
# frente que se dibuja (ver _frente): el mismo numero manda el dibujo y el daño.
static func retraso(f: CombatFormas.Forma, p: Vector2, t: int = Tipo.GRIETAS) -> float:
	if f == null or f.radio <= 0.0 or t == Tipo.ESTELA:
		return 0.0   # la estela no se propaga: pega en el instante del golpe
	if t == Tipo.CORTE:
		return CorteAire.retraso_px(p.distance_to(origen_de(f)), f.radio)
	var u: float = clampf(p.distance_to(origen_de(f)) / f.radio, 0.0, 1.0)
	# frente = 1 - (1 - s)^2  ->  s = 1 - sqrt(1 - u)
	return t_salir_de(t) * (1.0 - sqrt(1.0 - u))


# Lo que tarda el frente de cada tipo en llegar a su borde.
static func t_salir_de(t: int) -> float:
	if t == Tipo.CORTE:
		return CorteAire.T_VIAJE
	return T_SALIR_ESTALLIDO if t == Tipo.ESTALLIDO else T_SALIR


# De donde sale la rotura: el centro del circulo, o los pies del que golpea en el cono y la linea.
static func origen_de(f: CombatFormas.Forma) -> Vector2:
	return f.origen if f.tipo in [CombatFormas.Tipo.CONO, CombatFormas.Tipo.LINEA] else f.centro


# CUANDO LE LLEGA a un CUERPO (su caja en mundo): por su punto mas cercano al origen, que es por donde
# le alcanza la rotura (la misma regla que el golpe: le da a quien le toca el cuerpo).
static func retraso_caja(f: CombatFormas.Forma, r: Rect2, t: int = Tipo.GRIETAS) -> float:
	if f == null:
		return 0.0
	var o: Vector2 = origen_de(f)
	return retraso(f, Vector2(clampf(o.x, r.position.x, r.end.x), clampf(o.y, r.position.y, r.end.y)), t)


# Lo que se ha abierto a los 't' segundos, en fraccion del radio. Arranca rapido y frena al llegar.
func _frente(t: float) -> float:
	var s: float = clampf(t / _ts, 0.0, 1.0)
	return 1.0 - pow(1.0 - s, 2.0)


func duracion() -> float:
	return _ts + T_QUIETO + T_APAGAR


func _ready() -> void:
	_cono = forma.tipo == CombatFormas.Tipo.CONO
	_linea = forma.tipo == CombatFormas.Tipo.LINEA
	_origen = origen_de(forma)
	_radio = maxf(forma.radio, 8.0)
	if _cono:
		var mitad: float = deg_to_rad(forma.apertura * 0.5)
		_a0 = forma.dir.angle() - mitad
		_a1 = forma.dir.angle() + mitad
	_ts = t_salir_de(tipo)
	match tipo:
		Tipo.GRIETAS: _generar_grietas()
		Tipo.ESTALLIDO: _generar_estallido()
		_:
			if _linea:
				_generar_fragmentos_linea()
			else:
				_generar_fragmentos()


func _process(delta: float) -> void:
	_t += delta
	if _t >= duracion():
		queue_free()
		return
	queue_redraw()


func _alfa() -> float:
	return 1.0 - clampf((_t - _ts - T_QUIETO) / T_APAGAR, 0.0, 1.0)


# ------------------------------------------------------------
#  GRIETAS (el Temblor)
# ------------------------------------------------------------
# Como la referencia que paso el usuario (23/09): un HUNDIMIENTO redondo con el BORDE grueso y
# dentado, por dentro una RED de grietas que parte el suelo en trozos, y por fuera grietas finas que
# se escapan del borde y se afilan hasta la nada.
const BORDE_TEMBLOR := 0.7   # el borde del hundimiento, en fraccion del radio
var _borde: PackedVector2Array = PackedVector2Array()
var _borde_w: PackedFloat32Array = PackedFloat32Array()
var _r_borde: float = 0.0

func _generar_grietas() -> void:
	_r_borde = _radio * BORDE_TEMBLOR
	# 1) EL BORDE: un anillo quebrado, de grosor irregular.
	var n_b: int = 72
	for i in n_b + 1:
		var a: float = TAU * float(i % n_b) / float(n_b)
		var rr: float = _r_borde * (1.0 + 0.045 * sin(a * 5.0 + 1.3) + _rng.randf_range(-0.03, 0.03))
		_borde.append(_origen + Vector2(cos(a), sin(a)) * rr)
		_borde_w.append(_rng.randf_range(2.2, 4.2))
	_borde[n_b] = _borde[0]
	# 2) LAS DE DENTRO: grietas que van del centro al borde, muy torcidas...
	var n: int = 13
	var radiales: Array = []
	for i in n:
		var ang: float = TAU * (float(i) + _rng.randf_range(-0.35, 0.35)) / float(n)
		var r0: float = _rng.randf_range(2.0, _r_borde * 0.18)
		var pts: PackedVector2Array = _quebrada(ang, r0, _r_borde, 3.5, 0.55)
		radiales.append(pts)
		_grietas.append({"pts": pts, "w0": 1.9, "w1": 1.3})
	# ...y PUENTES entre cada una y la de al lado, a alturas sueltas: son los que cierran los trozos.
	for i in n:
		var p1: PackedVector2Array = radiales[i]
		var p2: PackedVector2Array = radiales[(i + 1) % n]
		for _k in _rng.randi_range(2, 3):
			var u: float = _rng.randf_range(0.2, 0.9)
			var a_pt: Vector2 = p1[clampi(int(u * p1.size()), 0, p1.size() - 1)]
			var b_pt: Vector2 = p2[clampi(int(_rng.randf_range(u - 0.15, u + 0.15) * p2.size()), 0, p2.size() - 1)]
			_grietas.append({"pts": _zigzag(a_pt, b_pt, 3.0, 1.6), "w0": 1.2, "w1": 1.0})
	# 3) LAS DE FUERA: salen del borde, finas y cada vez mas finas; alguna se parte en dos.
	for i in 26:
		var ang2: float = TAU * (float(i) + _rng.randf_range(-0.4, 0.4)) / 26.0
		var largo: float = _r_borde + (_radio - _r_borde) * _rng.randf_range(0.45, 1.0)
		var pts2: PackedVector2Array = _quebrada(ang2, _r_borde * 0.98, largo, 3.0, 0.6)
		_grietas.append({"pts": pts2, "w0": 2.2, "w1": 0.4})
		if _rng.randf() < 0.4 and pts2.size() > 4:
			var base: Vector2 = pts2[pts2.size() / 2]
			var ang_r: float = (base - _origen).angle() + _rng.randf_range(0.4, 0.7) * (1.0 if _rng.randf() < 0.5 else -1.0)
			var fin: Vector2 = base + Vector2(cos(ang_r), sin(ang_r)) * _rng.randf_range(6.0, 12.0)
			_grietas.append({"pts": _zigzag(base, fin, 2.5, 1.2), "w0": 1.0, "w1": 0.3})
	_crater = _mancha(_origen, 3.5, 7)


# Una grieta de 'a' a 'b' que no va recta: se sale a los lados a trozos de 'paso'.
func _zigzag(a: Vector2, b: Vector2, paso: float, temblor: float) -> PackedVector2Array:
	var out := PackedVector2Array([a])
	var n: int = maxi(2, int(a.distance_to(b) / paso))
	var normal: Vector2 = (b - a).orthogonal().normalized()
	for i in range(1, n):
		out.append(a.lerp(b, float(i) / float(n)) + normal * _rng.randf_range(-temblor, temblor))
	out.append(b)
	return out


# Una linea quebrada que sale de _origen en 'ang', de r0 a r0+largo, a pasos de 'paso' con temblor.
func _quebrada(ang: float, r0: float, largo: float, paso: float, temblor: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var dir: float = ang
	var r: float = r0
	var p: Vector2 = _origen + Vector2(cos(ang), sin(ang)) * r0
	pts.append(p)
	while r < largo:
		# Se tuerce, pero siempre vuelve hacia su rumbo: una grieta no da la vuelta.
		dir = lerpf(dir, ang, 0.35) + _rng.randf_range(-temblor, temblor)
		p += Vector2(cos(dir), sin(dir)) * paso
		r = p.distance_to(_origen)
		pts.append(p)
	return pts


func _mancha(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		out.append(c + Vector2(cos(a), sin(a)) * r * _rng.randf_range(0.7, 1.15))
	return out


func _dibujar_grietas(front: float, a: float) -> void:
	var llega: float = front * _radio
	# El HUNDIMIENTO: el suelo de dentro del borde algo mas oscuro, en cuanto el frente pasa el borde.
	if llega >= _r_borde:
		draw_colored_polygon(_borde, Color(OSCURO, 0.22 * a))
	if _crater.size() >= 3:
		draw_colored_polygon(_crater, Color(OSCURO, 0.85 * a))
	for g in _grietas:
		var pts: PackedVector2Array = _recortar(g["pts"], front)
		if pts.size() < 2:
			continue
		_trazo(pts, float(g["w0"]), float(g["w1"]), a, g["pts"].size())
	# EL BORDE, grueso y dentado: sale entero cuando le llega el frente.
	if llega >= _r_borde:
		for i in _borde.size() - 1:
			var w: float = _borde_w[i]
			draw_line(_borde[i] + Vector2(0.6, 1.2), _borde[i + 1] + Vector2(0.6, 1.2), Color(LABIO, 0.4 * a), w * 0.5)
		for i in _borde.size() - 1:
			draw_line(_borde[i], _borde[i + 1], Color(OSCURO, 0.95 * a), _borde_w[i])
			draw_circle(_borde[i], _borde_w[i] * 0.5, Color(OSCURO, 0.95 * a))


# Una grieta que se AFILA: de w0 en su arranque a w1 en su punta (contando sobre la linea ENTERA,
# 'n_total' puntos, para que al ir saliendo no cambie de grosor). El labio claro debajo y el negro
# encima: una raja en la piedra, no una raya pintada.
func _trazo(pts: PackedVector2Array, w0: float, w1: float, a: float, n_total: int) -> void:
	for i in pts.size() - 1:
		var w: float = lerpf(w0, w1, float(i) / float(maxi(1, n_total - 1)))
		draw_line(pts[i] + Vector2(0.6, 1.0), pts[i + 1] + Vector2(0.6, 1.0), Color(LABIO, 0.35 * a), maxf(0.6, w * 0.5))
	for i in pts.size() - 1:
		var w2: float = lerpf(w0, w1, float(i) / float(maxi(1, n_total - 1)))
		draw_line(pts[i], pts[i + 1], Color(OSCURO, 0.95 * a), w2)


# ------------------------------------------------------------
#  FRAGMENTOS (Golpe sismico y Onda expansiva)
# ------------------------------------------------------------
func _generar_fragmentos() -> void:
	var n_rayos: int = 15 if not _cono else 7
	var n_anillos: int = 5
	var angs: Array = []
	for i in n_rayos + (1 if _cono else 0):
		var u: float = float(i) / float(n_rayos)
		var jit: float = 0.0 if (_cono and (i == 0 or i == n_rayos)) else _rng.randf_range(-0.28, 0.28) / float(n_rayos)
		angs.append(lerpf(_a0, _a1, u) + jit * (_a1 - _a0))
	# Los anillos se aprietan cerca del centro (losas pequeñas donde pega, grandes lejos).
	var r_ini: float = maxf(nucleo * 0.55, _radio * 0.08)
	var radios: Array = [r_ini]
	for k in range(1, n_anillos + 1):
		radios.append(lerpf(r_ini, _radio, pow(float(k) / float(n_anillos), 0.85)))
	# Cada vertice (anillo k, rayo j), con su temblor: asi los anillos no son circulos perfectos.
	var v: Array = []
	for k in radios.size():
		var fila: Array = []
		for j in angs.size():
			var rr: float = float(radios[k]) * (1.0 if k == 0 else _rng.randf_range(0.9, 1.08))
			if k == radios.size() - 1:
				rr = minf(rr, _radio)
			fila.append(_origen + Vector2(cos(angs[j]), sin(angs[j])) * rr)
		v.append(fila)
	var n_ang: int = angs.size()
	var cerrar: bool = not _cono
	# Los rayos: del anillo 0 al borde, pasando por sus vertices.
	for j in n_ang:
		var linea := PackedVector2Array()
		for k in radios.size():
			linea.append(v[k][j])
		_rayos.append(linea)
	# Los anillos, quebrados entre rayo y rayo.
	for k in range(1, radios.size() - (0 if _cono else 1)):
		var pts := PackedVector2Array()
		var tope: int = n_ang + (1 if cerrar else 0)
		for jj in tope:
			var j: int = jj % n_ang
			pts.append(v[k][j])
			if jj < tope - 1:
				var sig: Vector2 = v[k][(j + 1) % n_ang]
				var medio: Vector2 = (v[k][j] + sig) * 0.5
				medio += (medio - _origen).normalized() * _rng.randf_range(-2.5, 2.5)
				pts.append(medio)
		_anillos.append({"r": float(radios[k]), "pts": pts})
	# Las losas: cada hueco entre dos rayos y dos anillos. Unas cuantas se LEVANTAN (la viñeta).
	var n_huecos: int = n_ang - (1 if _cono else 0)
	for k in radios.size() - 1:
		for j in n_huecos:
			var j2: int = (j + 1) % n_ang
			var poly := PackedVector2Array([v[k][j], v[k][j2], v[k + 1][j2], v[k + 1][j]])
			var c: Vector2 = (poly[0] + poly[1] + poly[2] + poly[3]) * 0.25
			var alza: float = 0.0
			# Cerca del golpe se levantan mas; lejos, pocas.
			if _rng.randf() < lerpf(0.55, 0.2, float(k) / float(radios.size() - 1)):
				alza = _rng.randf_range(2.0, 4.5)
			var piedras: Array = []
			for _p in _rng.randi_range(0, 2 if k < 2 else 1):
				piedras.append({"v": Vector2(_rng.randf_range(-18, 18), _rng.randf_range(-40, -22)),
					"o": c + Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-3, 3)),
					"tam": _rng.randf_range(1.5, 2.8)})
			_losas.append({"poly": poly, "c": c, "d": c.distance_to(_origen), "alza": alza,
				"piedras": piedras, "encoge": _rng.randf_range(0.8, 0.9)})
	_crater = _mancha(_origen, maxf(r_ini * 0.9, 5.0), 11)


# LOSAS EN LINEA (el Tajo devastador, 24/09: "como la onda expansiva pero en linea"). La misma rotura que
# la Onda, pero en una franja: una raja por el medio que va de tus pies al fondo, cortes de lado a lado a
# trechos, y entre ellos las losas, que se levantan como en la viñeta. Todo se guarda en las mismas listas
# que los fragmentos (rayos = rajas a lo largo, anillos = cortes de lado a lado con su distancia), asi
# que se pinta con _dibujar_fragmentos tal cual y el frente avanza a lo largo igual que en el cono.
func _generar_fragmentos_linea() -> void:
	var dir: Vector2 = forma.dir
	var nor: Vector2 = Vector2(-dir.y, dir.x)
	var n: int = maxi(4, int(_radio / 15.0))
	var ts: Array = []
	for k in n + 1:
		var u: float = float(k) / float(n)
		var jit: float = 0.0 if (k == 0 or k == n) else _rng.randf_range(-0.3, 0.3) / float(n)
		ts.append(lerpf(3.0, _radio, u + jit))
	# Por estacion: borde izquierdo, la raja del medio (que se tuerce) y el borde derecho.
	var filas: Array = []
	for k in ts.size():
		var t: float = ts[k]
		var h: float = maxf(forma.ancho_en(t), 2.0) * 0.5
		var c: Vector2 = _origen + dir * t + nor * _rng.randf_range(-0.18, 0.18) * h
		filas.append([_origen + dir * t - nor * h * _rng.randf_range(0.92, 1.08), c,
			_origen + dir * t + nor * h * _rng.randf_range(0.92, 1.08)])
	# Las rajas a lo largo: la del medio, gruesa y quebrada; los bordes, mas finos.
	for lado in 3:
		var linea := PackedVector2Array()
		for k in filas.size():
			var p: Vector2 = filas[k][lado]
			linea.append(p)
			if lado == 1 and k < filas.size() - 1:
				var sig: Vector2 = filas[k + 1][1]
				linea.append((p + sig) * 0.5 + nor * _rng.randf_range(-2.5, 2.5))
		_rayos.append(linea)
	# Los cortes de lado a lado, quebrados, a su distancia de tus pies.
	for k in range(1, filas.size() - 1):
		var f: Array = filas[k]
		var pts := PackedVector2Array([f[0], (f[0] + f[1]) * 0.5 + dir * _rng.randf_range(-2.0, 2.0), f[1],
			(f[1] + f[2]) * 0.5 + dir * _rng.randf_range(-2.0, 2.0), f[2]])
		_anillos.append({"r": float(ts[k]), "pts": pts})
	# Las losas: a cada lado de la raja, entre corte y corte. Cerca de ti se levantan mas.
	for k in filas.size() - 1:
		for lado in 2:
			var poly := PackedVector2Array([filas[k][lado], filas[k][lado + 1], filas[k + 1][lado + 1],
				filas[k + 1][lado]])
			var cc: Vector2 = (poly[0] + poly[1] + poly[2] + poly[3]) * 0.25
			var alza: float = 0.0
			if _rng.randf() < lerpf(0.6, 0.3, float(k) / float(filas.size() - 1)):
				alza = _rng.randf_range(2.0, 4.5)
			var piedras: Array = []
			for _p in _rng.randi_range(0, 2):
				piedras.append({"v": Vector2(_rng.randf_range(-18, 18), _rng.randf_range(-40, -22)),
					"o": cc + Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-3, 3)),
					"tam": _rng.randf_range(1.5, 2.8)})
			_losas.append({"poly": poly, "c": cc, "d": cc.distance_to(_origen), "alza": alza,
				"piedras": piedras, "encoge": _rng.randf_range(0.8, 0.9)})
	# Donde entra el filo: una muesca a tus pies, no un crater.
	_crater = _mancha(_origen + dir * 5.0, maxf(forma.ancho * 0.15, 3.0), 9)


func _dibujar_fragmentos(front: float, a: float) -> void:
	var llega: float = front * _radio
	# 1) Las losas LEVANTADAS: su sombra y su cara de arriba, un poco subidas y separadas de las vecinas.
	for l in _losas:
		var d: float = float(l["d"])
		if d > llega or float(l["alza"]) <= 0.0:
			continue
		# Salta al llegarle el frente (con un pelin de rebote) y luego se queda.
		var t_l: float = _t - retraso_px(d)
		var salto: float = clampf(t_l / 0.12, 0.0, 1.0)
		var h: float = float(l["alza"]) * (salto + 0.35 * sin(clampf(t_l / 0.25, 0.0, 1.0) * PI)) * K_ALTO
		var c: Vector2 = l["c"]
		var poly: PackedVector2Array = l["poly"]
		var cara := PackedVector2Array()
		for p in poly:
			cara.append(c + (p - c) * float(l["encoge"]))
		draw_colored_polygon(_desplazar(cara, Vector2(0, 1.5)), Color(OSCURO, 0.7 * a))
		var arriba: PackedVector2Array = _desplazar(cara, Vector2(0, -h))
		draw_colored_polygon(arriba, Color(1, 1, 1, 0.10 * a))
		var borde := arriba.duplicate()
		borde.append(arriba[0])
		draw_polyline(borde, Color(LABIO, 0.35 * a), 1.0)
	# 2) Las rajas: rayos hasta el frente y los anillos que ya ha pasado.
	for r in _rayos:
		var pts: PackedVector2Array = _recortar(r, llega / _radio)
		if pts.size() >= 2:
			draw_polyline(_desplazar(pts, Vector2(0.8, 1.2)), Color(LABIO, 0.4 * a), 1.2)
			draw_polyline(pts, Color(OSCURO, 0.95 * a), 2.2)
	for an in _anillos:
		if float(an["r"]) > llega:
			continue
		var pts2: PackedVector2Array = an["pts"]
		draw_polyline(_desplazar(pts2, Vector2(0.8, 1.2)), Color(LABIO, 0.35 * a), 1.0)
		draw_polyline(pts2, Color(OSCURO, 0.9 * a), 1.8)
	# 3) El agujero del golpe.
	if _crater.size() >= 3:
		draw_colored_polygon(_crater, Color(OSCURO, 0.9 * a))
	# 4) Las piedrecitas que saltan de cada losa al llegarle el frente.
	for l in _losas:
		var d2: float = float(l["d"])
		if d2 > llega:
			continue
		var tp: float = _t - retraso_px(d2)
		if tp > 0.45:
			continue
		for pd in l["piedras"]:
			var o: Vector2 = pd["o"]
			var vel: Vector2 = pd["v"]
			# Lo que salta es ALTURA: en x anda por el suelo tal cual, en y se ve a K_ALTO.
			var p: Vector2 = o + Vector2(vel.x * tp, (vel.y * tp + 160.0 * tp * tp) * K_ALTO)
			var tam: float = float(pd["tam"])
			draw_rect(Rect2(p - Vector2(tam, tam) * 0.5, Vector2(tam, tam)),
				Color(LABIO, 0.9 * (1.0 - tp / 0.45)))


# ------------------------------------------------------------
#  ESTALLIDO (el Martillo de guerra)
# ------------------------------------------------------------
# DOS PIEZAS. En el SUELO, un crater de borde dentado y grietas finas que se escapan hacia fuera (las
# del Temblor, sin hundimiento). Y ENCIMA, el GEISER DE POLVO (lo pidio asi el usuario: "como si
# explotase un geiser", pero de POLVO de la explosion, no de agua, y lo que cae son PIEDRAS del suelo
# reventado, no gotas): chorros de polvo que salen disparados hacia arriba y se abren en nubes que se
# disipan, una nube baja que se extiende por el suelo, y piedras que salen despedidas girando y caen.
# Todo eso es ALTURA (va a K_ALTO) y se pinta en su propio nodo por ENCIMA de los cuerpos: lo que sale
# disparado desde debajo de un enemigo no puede quedar tapado por el.
const T_GEISER_SUBE := 0.14    # lo que tarda en salir disparado
const T_GEISER := 1.3          # lo que dura entero
const ALTO_GEISER := 78.0      # en unidades de mundo (en pantalla, x K_ALTO)
const GRAVEDAD_PIEDRAS := 300.0
const POLVO := Color(0.66, 0.62, 0.56)
const PIEDRA := Color(0.36, 0.34, 0.33)
const PIEDRA_LUZ := Color(0.58, 0.55, 0.52)

var _geiser: Node2D = null
var _hebras: Array = []    # chorros de polvo: {x0, ang, largo, w, curva}  (ang: desviacion de la vertical)
var _nubes: Array = []     # bocanadas: {hebra, s (0..1 a lo largo), r, t0}
var _pie: Array = []       # la nube baja del suelo: {ang, dist, r}
var _piedras: Array = []   # {p0: Vector2 (x, z), v: Vector2 (vx, vz), poly local, rot, vrot, t0}


func _generar_estallido() -> void:
	var r_cr: float = maxf(nucleo * 0.8, 7.0)
	_crater = _mancha(_origen, r_cr, 12)
	# Las grietas que se escapan del crater hacia fuera, finas y afilandose; alguna se parte.
	for i in 16:
		var ang: float = TAU * (float(i) + _rng.randf_range(-0.4, 0.4)) / 16.0
		var largo: float = r_cr + (_radio - r_cr) * _rng.randf_range(0.5, 1.0)
		var pts: PackedVector2Array = _quebrada(ang, r_cr * 0.9, largo, 3.0, 0.6)
		_grietas.append({"pts": pts, "w0": 2.6, "w1": 0.4})
		if _rng.randf() < 0.45 and pts.size() > 4:
			var base: Vector2 = pts[pts.size() / 2]
			var ang_r: float = (base - _origen).angle() + _rng.randf_range(0.4, 0.8) * (1.0 if _rng.randf() < 0.5 else -1.0)
			var fin: Vector2 = base + Vector2(cos(ang_r), sin(ang_r)) * _rng.randf_range(6.0, 13.0)
			_grietas.append({"pts": _zigzag(base, fin, 2.5, 1.2), "w0": 1.1, "w1": 0.3})
	# LOS CHORROS DE POLVO: casi verticales, los del medio los mas altos.
	for i in 11:
		var u: float = (float(i) + 0.5) / 11.0 * 2.0 - 1.0      # -1..1, de un lado al otro
		_hebras.append({"x0": u * r_cr * 0.7 + _rng.randf_range(-1.5, 1.5),
			"ang": u * deg_to_rad(22.0) + _rng.randf_range(-0.08, 0.08),
			"largo": ALTO_GEISER * lerpf(1.0, 0.45, absf(u)) * _rng.randf_range(0.8, 1.05),
			"w": _rng.randf_range(3.0, 5.5), "curva": _rng.randf_range(-6.0, 6.0)})
	# Las BOCANADAS: nubecitas a lo largo de cada chorro, mas gordas arriba (donde se abre).
	for j in _hebras.size():
		for _k in 4:
			var s: float = _rng.randf_range(0.35, 1.0)
			_nubes.append({"hebra": j, "s": s, "r": lerpf(3.0, 8.0, s) * _rng.randf_range(0.8, 1.2),
				"t0": T_GEISER_SUBE * s})
	# LA NUBE BAJA: bocanadas a ras de suelo que se abren hacia fuera desde el crater.
	for j in 12:
		_pie.append({"ang": TAU * (float(j) + _rng.randf_range(-0.3, 0.3)) / 12.0,
			"dist": _rng.randf_range(0.6, 1.0) * _radio * 0.55, "r": _rng.randf_range(4.0, 8.0)})
	# LAS PIEDRAS: salen del crater hacia arriba y hacia fuera, girando, y caen.
	for j in 14:
		var ang_p: float = _rng.randf_range(0.0, TAU)
		var poly := PackedVector2Array()
		var n_lados: int = _rng.randi_range(4, 6)
		var tam: float = _rng.randf_range(1.4, 3.2)
		for q in n_lados:
			var aq: float = TAU * float(q) / float(n_lados) + _rng.randf_range(-0.3, 0.3)
			poly.append(Vector2(cos(aq), sin(aq)) * tam * _rng.randf_range(0.7, 1.2))
		var sale: float = _rng.randf_range(20.0, 70.0)
		_piedras.append({"p0": Vector2(cos(ang_p) * r_cr * 0.5, 2.0),
			"v": Vector2(cos(ang_p) * sale, _rng.randf_range(90.0, 170.0)),
			"poly": poly, "rot": _rng.randf_range(0.0, TAU), "vrot": _rng.randf_range(-12.0, 12.0),
			"t0": _rng.randf_range(0.0, 0.06)})
	_geiser = Node2D.new()
	_geiser.z_as_relative = false
	_geiser.z_index = Game.Z_PERSONAJES + 80
	add_child(_geiser)
	_geiser.draw.connect(_dibujar_geiser)


func _dibujar_estallido(front: float, a: float) -> void:
	if _crater.size() >= 3:
		draw_colored_polygon(_crater, Color(OSCURO, 0.9 * a))
		var borde := _crater.duplicate()
		borde.append(_crater[0])
		draw_polyline(_desplazar(borde, Vector2(0.6, 1.2)), Color(LABIO, 0.4 * a), 1.2)
		draw_polyline(borde, Color(OSCURO, a), 2.6)
	for g in _grietas:
		var pts: PackedVector2Array = _recortar(g["pts"], front)
		if pts.size() >= 2:
			_trazo(pts, float(g["w0"]), float(g["w1"]), a, g["pts"].size())
	if _geiser != null:
		_geiser.queue_redraw()


# Un punto del geiser (x a lo ancho, z de altura) en el mundo: la altura sube en pantalla a K_ALTO.
func _alz(x: float, z: float) -> Vector2:
	return _origen + Vector2(x, -z * K_ALTO)


# Donde cae el punto 's' (0 pie, 1 punta) de un chorro de 'largo'.
func _en_hebra(h: Dictionary, largo: float, s: float) -> Vector2:
	var z: float = largo * s
	return _alz(float(h["x0"]) + sin(float(h["ang"])) * z + float(h["curva"]) * sin(s * PI) * s, z)


func _dibujar_geiser() -> void:
	if _t < 0.0 or _t > T_GEISER:
		return
	var sube: float = clampf(_t / T_GEISER_SUBE, 0.0, 1.0)
	sube = 1.0 - pow(1.0 - sube, 3.0)
	# El polvo NO cae: se abre y se disipa (crece y se apaga), y sigue subiendo un poco despacio.
	var disipa: float = clampf((_t - 0.2) / (T_GEISER - 0.2), 0.0, 1.0)
	var a: float = pow(1.0 - disipa, 1.5)
	var crece: float = 1.0 + 1.3 * disipa
	var sigue: float = 1.0 + 0.25 * disipa
	# 1) La nube baja, a ras de suelo, abriendose desde el crater.
	for pd in _pie:
		var ab: float = clampf(_t / 0.25, 0.0, 1.0)
		var d: float = float(pd["dist"]) * (1.0 - pow(1.0 - ab, 2.0)) * (1.0 + 0.4 * disipa)
		var ang: float = float(pd["ang"])
		var c: Vector2 = _origen + Vector2(cos(ang) * d, sin(ang) * d - 3.0)
		_geiser.draw_circle(c, float(pd["r"]) * crece, Color(POLVO, 0.35 * a))
	# 2) Los chorros: un trazo ancho y tenue y un nucleo mas denso, que se ensanchan al disiparse.
	for h in _hebras:
		var largo: float = float(h["largo"]) * sube * sigue
		var prev: Vector2 = Vector2.ZERO
		for k in 11:
			var s: float = float(k) / 10.0
			var p: Vector2 = _en_hebra(h, largo, s)
			if k > 0:
				var w: float = lerpf(float(h["w"]), float(h["w"]) * 0.45, s) * crece
				_geiser.draw_line(prev, p, Color(POLVO, 0.35 * a), w * 1.8)
				_geiser.draw_line(prev, p, Color(POLVO.lightened(0.15), 0.6 * a), w * 0.8)
			prev = p
	# 3) Las bocanadas: donde el chorro se abre en nube.
	for nb in _nubes:
		if _t < float(nb["t0"]):
			continue
		var h2: Dictionary = _hebras[int(nb["hebra"])]
		var c2: Vector2 = _en_hebra(h2, float(h2["largo"]) * sube * sigue, float(nb["s"]))
		var r: float = float(nb["r"]) * crece
		_geiser.draw_circle(c2, r, Color(POLVO, 0.4 * a))
		_geiser.draw_circle(c2 + Vector2(-r * 0.25, -r * 0.3), r * 0.55, Color(POLVO.lightened(0.2), 0.35 * a))
	# 4) Las piedras: vuelan girando y caen; al tocar el suelo, fuera.
	for pz in _piedras:
		var tp: float = _t - float(pz["t0"])
		if tp < 0.0:
			continue
		var p0: Vector2 = pz["p0"]
		var v: Vector2 = pz["v"]
		var z: float = p0.y + v.y * tp - GRAVEDAD_PIEDRAS * tp * tp
		if z < 0.0:
			continue
		var c3: Vector2 = _alz(p0.x + v.x * tp, z)
		var rot: float = float(pz["rot"]) + float(pz["vrot"]) * tp
		var cara := PackedVector2Array()
		for q in pz["poly"]:
			cara.append(c3 + (q as Vector2).rotated(rot))
		_geiser.draw_colored_polygon(cara, PIEDRA)
		_geiser.draw_line(cara[0], cara[1], PIEDRA_LUZ, 1.0)


# Lo mismo que retraso() pero con la distancia ya medida (px desde el origen).
func retraso_px(d: float) -> float:
	var u: float = clampf(d / _radio, 0.0, 1.0)
	return _ts * (1.0 - sqrt(1.0 - u))


# ------------------------------------------------------------
#  DIBUJO
# ------------------------------------------------------------
func _draw() -> void:
	if _t < 0.0:
		return
	var front: float = _frente(_t)
	var a: float = _alfa()
	if a <= 0.0:
		return
	# EL FRENTE: un anillo claro y fino donde esta rompiendo ahora; se lee "va llegando".
	if _t < _ts:
		var rf: float = front * _radio
		var af: float = 0.45 * (1.0 - clampf(_t / _ts, 0.0, 1.0) * 0.6)
		if _linea:
			# En la linea el frente es un corte de lado a lado que avanza.
			var q: Vector2 = _origen + forma.dir * rf
			var hh: Vector2 = Vector2(-forma.dir.y, forma.dir.x) * forma.ancho_en(rf) * 0.5
			draw_line(q - hh, q + hh, Color(LABIO, af), 2.0)
		else:
			draw_arc(_origen, rf, _a0, _a1, 64, Color(LABIO, af), 2.0)
	match tipo:
		Tipo.GRIETAS: _dibujar_grietas(front, a)
		Tipo.ESTALLIDO: _dibujar_estallido(front, a)
		_: _dibujar_fragmentos(front, a)


# La parte de la linea que ya ha alcanzado el frente (fraccion del radio), cortando el ultimo tramo.
func _recortar(pts: PackedVector2Array, front: float) -> PackedVector2Array:
	var lim: float = front * _radio
	var out := PackedVector2Array()
	for i in pts.size():
		var d: float = pts[i].distance_to(_origen)
		if d <= lim:
			out.append(pts[i])
			continue
		if i > 0:
			var d0: float = pts[i - 1].distance_to(_origen)
			if d0 < lim and d > d0:
				out.append(pts[i - 1].lerp(pts[i], (lim - d0) / (d - d0)))
		break
	return out


static func _desplazar(pts: PackedVector2Array, o: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + o)
	return out
