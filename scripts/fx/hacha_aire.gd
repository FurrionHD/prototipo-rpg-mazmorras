# ============================================================
#  hacha_aire.gd
#  LOS EFECTOS DEL HACHA GRANDE en el mapa (24/09/2026). Van por el mismo camino que el suelo roto y los
#  barridos del mandoble (ficha -> SueloRoto.lanzar, red, instante del golpe). Su idea, cerrada con el
#  usuario: el mandoble ATRAVIESA y el hacha MUERDE. La media luna del hacha es GORDA de cabeza y de cola
#  corta, barre y SE PARA EN SECO: se queda clavada un instante y se apaga de golpe. Acero con el borde de
#  dentro teñido de rojo oscuro, y lo que corta el hacha en el suelo es una RAJA, no losas.
#    HACHAZO     el Hachazo brutal: una sola media luna enorme de lado a lado, lenta al arrancar y
#                rapidisima al final; se clava con un destello y deja un tajo curvo en el suelo con polvo.
#                A cada uno le llega cuando el filo pasa por el (retraso por ANGULO).
#    CARNICERIA  tres medias lunas sucias (dcha, izda, dcha), cada una torcida a su manera, y tres tajos
#                cruzados en el suelo.
#    DESGARRO    un tajo corto hacia delante que al final se curva hacia ti como un GANCHO (el tiron y el
#                surco del arrastre van aparte: CombatTactico.pedir_tiron y SangreMapa.surco).
#    HENDEDURA   el hacha cae en vertical y el suelo se RAJA por la linea: dos labios que se separan y un
#                tope seco al final, con polvo y piedras.
#    MIRADA      la Sed de sangre: sin tajo. Tus ojos brillan en rojo, una presion roja sale en el cono y a
#                ti te late un pulso rojo dos veces.
#  La SANGRE de cada golpe (las gotas) no va aqui: sale en el instante en que el golpe entra, sobre el
#  cuerpo que lo encaja (SangreMapa.salpicar). Coordenadas de MUNDO; todo sale de una semilla.
#  NADA DE LINEAS (efectos-sin-lineas): filo duro que se difumina, cometas, destellos en estrella.
# ============================================================
extends Node2D
class_name HachaAire

enum Modo { HACHAZO, CARNICERIA, DESGARRO, HENDEDURA, MIRADA }

const T_ENTRE := BarridoAire.T_ENTRE   # entre golpe y golpe de la misma accion
const T_BRUTAL := 0.17       # lo que tarda el Hachazo brutal de punta a punta
const T_CLAVADO := 0.09      # lo que se queda clavado al final, entero
const T_APAGA_SECO := 0.1    # y lo que tarda en irse: DE GOLPE, no se deshace despacio
const T_CARNE := 0.09        # cada barrido de la Carniceria
const T_GANCHO := 0.12       # el tajo del Desgarro
const T_CAE := 0.07          # la caida de la Hendedura
const T_RAJA := 0.14         # y lo que tarda la raja en llegar a su tope
const T_MIRADA := 0.4        # lo que tarda la presion de la mirada en llegar a su borde
const T_SUELO := 0.55        # lo que se quedan las marcas del suelo antes de irse
const T_SUELO_APAGAR := 0.5
const COLA := deg_to_rad(95.0)   # la cola de la media luna: corta, es un hacha
const ALTO_BRUTAL := 7.0
const ALTO_OJOS := 38.0      # a que altura van los ojos del que mira (px de pantalla sobre los pies)

const BLANCO := BarridoAire.BLANCO
const ACERO := Color(0.80, 0.84, 0.90)
const SANGRE := Color(0.55, 0.05, 0.07)
const SANGRE_VIVA := Color(0.88, 0.1, 0.12)
const POLVO := SueloRoto.POLVO
const TIERRA := BarridoAire.TIERRA
const OSCURO := SueloRoto.OSCURO
const LABIO := SueloRoto.LABIO

var modo: int = Modo.HACHAZO
var forma: CombatFormas.Forma = null
var _ritmo: float = 1.0
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _atras: Node2D = null
var _delante: Node2D = null
var _centro: Vector2 = Vector2.ZERO
var _dir: Vector2 = Vector2.RIGHT
var _polvo: Array = []
var _barridos: Array = []   # Carniceria: {alto, r, giro, abre, tajo_a, tajo_b}
var _raja: PackedVector2Array = PackedVector2Array()
var _piedras: Array = []


# 'espera' = segundos hasta el PRIMER golpe.
static func lanzar(padre: Node, f: CombatFormas.Forma, m: int, semilla: int, espera: float) -> HachaAire:
	if padre == null or f == null:
		return null
	var h := HachaAire.new()
	h.modo = m
	h.forma = f
	h._rng.seed = semilla
	h._ritmo = maxf(BarridoAire.ritmo, 0.05)
	h._t = _antes(m) - espera * h._ritmo
	h.z_as_relative = false
	h.z_index = SueloRoto.Z_SUELO
	h.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(h)
	return h


# Lo que arranca ANTES de su golpe: los barridos de la Carniceria y el gancho pegan al acabar su tajo, y
# la Hendedura cae antes de rajar. El Hachazo empieza EN el golpe y le llega a cada uno al pasar.
static func _antes(m: int) -> float:
	match m:
		Modo.CARNICERIA: return T_CARNE
		Modo.DESGARRO: return T_GANCHO
		Modo.HENDEDURA: return T_CAE
	return 0.0


# CUANDO LE LLEGA a 'p' el golpe, en segundos desde el golpe. Es la misma cuenta con la que se dibuja.
static func retraso(m: int, f: CombatFormas.Forma, p: Vector2) -> float:
	var o: Vector2 = SueloRoto.origen_de(f)
	match m:
		Modo.HACHAZO:
			# La cabeza va a lerp(izq, der, s^2): le llega cuando s = sqrt(fraccion de su angulo).
			var mitad: float = deg_to_rad(f.apertura * 0.5)
			var fr: float = 0.0
			if mitad > 0.001 and p.distance_squared_to(o) > 0.01:
				fr = clampf(angle_difference(f.dir.angle() - mitad, (p - o).angle()) / (2.0 * mitad), 0.0, 1.0)
			return T_BRUTAL * sqrt(fr)
		Modo.HENDEDURA:
			return T_RAJA * clampf((p - o).dot(f.dir) / maxf(f.radio, 1.0), 0.0, 1.0)
		Modo.MIRADA:
			return T_MIRADA * clampf(p.distance_to(o) / maxf(f.radio, 1.0), 0.0, 1.0)
	return 0.0


# Lo que tarda en llegar a su ultimo rincon.
static func t_salir(m: int) -> float:
	match m:
		Modo.HACHAZO: return T_BRUTAL
		Modo.HENDEDURA: return T_RAJA
		Modo.MIRADA: return T_MIRADA
		Modo.CARNICERIA: return 2.0 * T_ENTRE
	return T_GANCHO


func duracion() -> float:
	match modo:
		Modo.HACHAZO: return T_BRUTAL + T_SUELO + T_SUELO_APAGAR + 0.2
		Modo.CARNICERIA: return T_CARNE + 2.0 * T_ENTRE + T_SUELO + T_SUELO_APAGAR + 0.2
		Modo.DESGARRO: return T_GANCHO + 0.4
		Modo.HENDEDURA: return T_CAE + T_RAJA + T_SUELO + T_SUELO_APAGAR + 0.1
	return T_MIRADA + 0.6


func _ready() -> void:
	_centro = forma.origen
	_dir = forma.dir.normalized() if forma.dir.length_squared() > 0.0001 else Vector2.RIGHT
	_atras = _capa(Game.Z_PERSONAJES - 1)
	_delante = _capa(Game.Z_PERSONAJES + 80)
	var mitad: float = deg_to_rad(forma.apertura * 0.5)
	match modo:
		Modo.HACHAZO:
			# Polvo que se levanta a lo largo del arco, cuando pasa el filo.
			for i in 11:
				var u: float = (float(i) + _rng.randf_range(0.0, 1.0)) / 11.0
				_polvo.append({"u": u, "t0": T_BRUTAL * sqrt(u), "r": forma.radio * _rng.randf_range(0.7, 0.95),
					"tam": _rng.randf_range(3.0, 5.5), "sale": _rng.randf_range(4.0, 10.0)})
		Modo.CARNICERIA:
			# Cada barrido a su manera: mas alto o mas bajo, mas corto, torcido. Y su tajo en el suelo,
			# de un lado del cono al otro con un angulo distinto: los tres se cruzan.
			for k in 3:
				var a_a: float = _dir.angle() + mitad * _rng.randf_range(-0.9, -0.2) * (1.0 if k % 2 == 0 else -1.0)
				var a_b: float = _dir.angle() + mitad * _rng.randf_range(0.2, 0.9) * (1.0 if k % 2 == 0 else -1.0)
				_barridos.append({"alto": [4.0, 11.0, 6.5][k] + _rng.randf_range(-1.5, 1.5),
					"r": forma.radio * _rng.randf_range(0.78, 0.97), "giro": _rng.randf_range(-0.16, 0.16),
					"abre": _rng.randf_range(0.8, 1.0),
					"tajo_a": _centro + Vector2(cos(a_a), sin(a_a)) * forma.radio * _rng.randf_range(0.45, 0.6),
					"tajo_b": _centro + Vector2(cos(a_b), sin(a_b)) * forma.radio * _rng.randf_range(0.7, 0.85)})
		Modo.HENDEDURA:
			# La raja: una linea quebrada de donde cae el hacha hasta el final de la huella.
			var ini: Vector2 = _centro + _dir * forma.radio * 0.18
			var fin: Vector2 = _centro + _dir * forma.radio * 0.98
			var nor: Vector2 = _dir.orthogonal()
			var n: int = 16
			for i in n + 1:
				var s: float = float(i) / float(n)
				var lado: float = 0.0 if i == 0 or i == n else _rng.randf_range(-1.0, 1.0) * forma.ancho * 0.1
				_raja.append(ini.lerp(fin, s) + nor * lado)
			for i in 4:
				_piedras.append({"v": Vector2(_rng.randf_range(-25.0, 25.0), _rng.randf_range(-25.0, 25.0)) + _dir * 20.0,
					"vz": _rng.randf_range(40.0, 70.0), "tam": _rng.randf_range(1.4, 2.4)})


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
	_atras.queue_redraw()
	_delante.queue_redraw()


# Lo que se va apagando del suelo pasados 't' segundos desde que se marco.
static func _alfa_suelo(t: float) -> float:
	if t < 0.0:
		return 0.0
	return 1.0 - clampf((t - T_SUELO) / T_SUELO_APAGAR, 0.0, 1.0)


# ------------------------------------------------------------
#  EL SUELO: tajos, raja, polvo
# ------------------------------------------------------------
func _draw() -> void:
	if _t < 0.0:
		return
	match modo:
		Modo.HACHAZO:
			var mitad: float = deg_to_rad(forma.apertura * 0.5)
			var izq: float = _dir.angle() - mitad
			var s: float = clampf(_t / T_BRUTAL, 0.0, 1.0)
			var hasta: float = lerpf(izq, izq + 2.0 * mitad, s * s)
			_tajo_arco(izq, hasta, forma.radio * 0.82, 2.2, _alfa_suelo(_t - T_BRUTAL))
			for p in _polvo:
				var tp: float = _t - float(p["t0"])
				if tp < 0.0 or tp > 0.5:
					continue
				var k: float = tp / 0.5
				var a: float = lerpf(izq, izq + 2.0 * mitad, float(p["u"]))
				var c: Vector2 = _centro + Vector2(cos(a), sin(a)) * (float(p["r"]) + float(p["sale"]) * sqrt(k))
				BarridoAire.brillo(self, c, float(p["tam"]) * (1.0 + k), Color(POLVO, 0.4 * (1.0 - k)))
		Modo.CARNICERIA:
			for k in 3:
				var tk: float = _t - (float(k) * T_ENTRE + T_CARNE)
				if tk < 0.0:
					continue
				var b: Dictionary = _barridos[k]
				_tajo_recto(b["tajo_a"], b["tajo_b"], 1.7, _alfa_suelo(tk))
		Modo.HENDEDURA:
			_dibujar_raja()


# UN TAJO EN EL SUELO por un arco: oscuro en el centro, con el labio claro por fuera, afilado en las dos
# puntas. Relleno, sin raya.
func _tajo_arco(a0: float, a1: float, r: float, ancho: float, alfa: float) -> void:
	if alfa <= 0.0 or absf(a1 - a0) < 0.02:
		return
	var n: int = maxi(6, int(absf(a1 - a0) / 0.07))
	var pts := PackedVector2Array()
	for i in n + 1:
		var a: float = lerpf(a0, a1, float(i) / float(n))
		pts.append(_centro + Vector2(cos(a), sin(a)) * r)
	_gasa(pts, ancho, alfa)


func _tajo_recto(a: Vector2, b: Vector2, ancho: float, alfa: float) -> void:
	if alfa <= 0.0:
		return
	var pts := PackedVector2Array()
	for i in 9:
		pts.append(a.lerp(b, float(i) / 8.0))
	_gasa(pts, ancho, alfa)


# La marca de un tajo sobre 'pts': el labio (claro y difuminado hacia fuera) y el corte oscuro encima.
func _gasa(pts: PackedVector2Array, ancho: float, alfa: float) -> void:
	var n: int = pts.size() - 1
	for capa_i in 2:
		var w_k: float = 2.2 if capa_i == 0 else 1.0
		for i in n:
			var s0: float = float(i) / float(n)
			var s1: float = float(i + 1) / float(n)
			var d: Vector2 = (pts[i + 1] - pts[i]).normalized().orthogonal()
			var w0: float = ancho * w_k * pow(sin(PI * s0), 0.6)
			var w1: float = ancho * w_k * pow(sin(PI * s1), 0.6)
			if capa_i == 0:
				# El labio: claro junto al corte y a nada por fuera.
				var cl := Color(LABIO, 0.45 * alfa)
				var tr := Color(LABIO, 0.0)
				for lado in [1.0, -1.0]:
					var q0: Vector2 = pts[i] + d * w0 * 0.4 * lado
					var q1: Vector2 = pts[i + 1] + d * w1 * 0.4 * lado
					var e0: Vector2 = pts[i] + d * w0 * lado
					var e1: Vector2 = pts[i + 1] + d * w1 * lado
					draw_primitive(PackedVector2Array([q0, q1, e1]), PackedColorArray([cl, cl, tr]), PackedVector2Array())
					draw_primitive(PackedVector2Array([q0, e1, e0]), PackedColorArray([cl, tr, tr]), PackedVector2Array())
			else:
				var co := Color(OSCURO, 0.85 * alfa)
				draw_primitive(PackedVector2Array([pts[i] + d * w0 * 0.45, pts[i + 1] + d * w1 * 0.45,
					pts[i + 1] - d * w1 * 0.45]), PackedColorArray([co, co, co]), PackedVector2Array())
				draw_primitive(PackedVector2Array([pts[i] + d * w0 * 0.45, pts[i + 1] - d * w1 * 0.45,
					pts[i] - d * w0 * 0.45]), PackedColorArray([co, co, co]), PackedVector2Array())


# LA RAJA de la Hendedura: el frente corre a velocidad fija y se PARA en seco; cada trozo se abre (los dos
# labios se separan) un poco despues de que pase el frente. Al llegar, polvo y piedras en el tope.
func _dibujar_raja() -> void:
	var tr: float = _t - T_CAE
	if tr < 0.0:
		return
	var alfa: float = _alfa_suelo(tr - T_RAJA)
	if alfa <= 0.0:
		return
	var frente: float = clampf(tr / T_RAJA, 0.0, 1.0)
	var n: int = _raja.size() - 1
	var w_max: float = maxf(forma.ancho, 8.0) * 0.4
	for i in n:
		var s0: float = float(i) / float(n)
		var s1: float = float(i + 1) / float(n)
		if s0 >= frente:
			break
		var p0: Vector2 = _raja[i]
		var p1: Vector2 = _raja[i + 1] if s1 <= frente else _raja[i].lerp(_raja[i + 1], (frente - s0) / (s1 - s0))
		# Cuanto se ha abierto este trozo: le llega el frente en s*T_RAJA y tarda 0,12 en abrirse.
		var abre0: float = clampf((tr - s0 * T_RAJA) / 0.12, 0.0, 1.0)
		var abre1: float = clampf((tr - s1 * T_RAJA) / 0.12, 0.0, 1.0)
		var w0: float = w_max * (1.0 - 0.55 * s0) * (0.25 + 0.75 * abre0)
		var w1: float = w_max * (1.0 - 0.55 * s1) * (0.25 + 0.75 * abre1)
		var d: Vector2 = (p1 - p0).normalized().orthogonal() if p1.distance_squared_to(p0) > 0.001 else _dir.orthogonal()
		# Los dos LABIOS (claros, difuminados hacia fuera) y el hueco oscuro entre ellos.
		var cl := Color(LABIO, 0.55 * alfa)
		var trc := Color(LABIO, 0.0)
		for lado in [1.0, -1.0]:
			draw_primitive(PackedVector2Array([p0 + d * w0 * 0.5 * lado, p1 + d * w1 * 0.5 * lado, p1 + d * (w1 * 0.5 + 2.2) * lado]),
				PackedColorArray([cl, cl, trc]), PackedVector2Array())
			draw_primitive(PackedVector2Array([p0 + d * w0 * 0.5 * lado, p1 + d * (w1 * 0.5 + 2.2) * lado, p0 + d * (w0 * 0.5 + 2.2) * lado]),
				PackedColorArray([cl, trc, trc]), PackedVector2Array())
		var co := Color(OSCURO, 0.9 * alfa)
		draw_primitive(PackedVector2Array([p0 + d * w0 * 0.5, p1 + d * w1 * 0.5, p1 - d * w1 * 0.5]),
			PackedColorArray([co, co, co]), PackedVector2Array())
		draw_primitive(PackedVector2Array([p0 + d * w0 * 0.5, p1 - d * w1 * 0.5, p0 - d * w0 * 0.5]),
			PackedColorArray([co, co, co]), PackedVector2Array())
	# Donde cae el hacha, un golpe de polvo.
	var tc: float = tr
	if tc < 0.45:
		var k: float = tc / 0.45
		BarridoAire.brillo(self, _raja[0], 6.0 + 8.0 * k, Color(POLVO, 0.45 * (1.0 - k)))
	# El TOPE: al llegar el frente, polvo que sale hacia delante.
	var tt: float = tr - T_RAJA
	if tt >= 0.0 and tt < 0.5:
		var k2: float = tt / 0.5
		BarridoAire.brillo(self, _raja[n] + _dir * 5.0 * sqrt(k2), 5.0 + 7.0 * k2, Color(POLVO, 0.5 * (1.0 - k2)))


# ------------------------------------------------------------
#  EL AIRE (cada capa pinta lo suyo: detras o delante del que golpea)
# ------------------------------------------------------------
func _dibujar_capa(capa: Node2D) -> void:
	if _t < 0.0:
		return
	match modo:
		Modo.HACHAZO: _hachazo(capa)
		Modo.CARNICERIA: _carniceria(capa)
		Modo.DESGARRO: _desgarro(capa)
		Modo.HENDEDURA: _hendedura(capa)
		Modo.MIRADA: _mirada(capa)


func _es_mia(capa: Node2D, p: Vector2, alto: float) -> bool:
	var detras: bool = p.y < _centro.y - alto
	return detras == (capa == _atras)


func _en_arco(a: float, r: float, alto: float) -> Vector2:
	return _centro + Vector2(cos(a), sin(a)) * r + Vector2(0.0, -alto)


# LA MEDIA LUNA DEL HACHA, de 'a_cola' a 'a_cabeza'. La diferencia con la del mandoble (BarridoAire._tajo)
# es toda la idea: aqui la CABEZA es la parte gorda y se corta en seco (no se afila), y hacia la cola se
# adelgaza. De fuera hacia dentro: el filo blanco y duro, acero, un velo rojo oscuro y nada.
func _mordisco(capa: Node2D, a_cola: float, a_cabeza: float, r: float, grueso: float, alto: float,
		alfa: float) -> void:
	if alfa <= 0.0 or absf(a_cabeza - a_cola) < 0.01:
		return
	var n: int = maxi(8, int(absf(a_cabeza - a_cola) / 0.06))
	var fr: Array = [0.0, 0.1, 0.38, 0.72, 1.0]
	var cols: Array = [BLANCO, ACERO, SANGRE, SANGRE, SANGRE]
	var al: Array = [1.0, 0.95, 0.75, 0.4, 0.0]
	for i in n:
		var s0: float = float(i) / float(n)
		var s1: float = float(i + 1) / float(n)
		var a0: float = lerpf(a_cola, a_cabeza, s0)
		var a1: float = lerpf(a_cola, a_cabeza, s1)
		if not _es_mia(capa, _en_arco((a0 + a1) * 0.5, r, alto), alto):
			continue
		# Fina en la cola y gorda hasta la misma cabeza: ahi se corta.
		var g0: float = grueso * (0.12 + 0.88 * pow(s0, 1.4))
		var g1: float = grueso * (0.12 + 0.88 * pow(s1, 1.4))
		var l0: float = alfa * (0.3 + 0.7 * s0)
		var l1: float = alfa * (0.3 + 0.7 * s1)
		for k in fr.size() - 1:
			var p00: Vector2 = _en_arco(a0, r - g0 * float(fr[k]), alto)
			var p10: Vector2 = _en_arco(a1, r - g1 * float(fr[k]), alto)
			var p01: Vector2 = _en_arco(a0, r - g0 * float(fr[k + 1]), alto)
			var p11: Vector2 = _en_arco(a1, r - g1 * float(fr[k + 1]), alto)
			var c00 := Color(cols[k], l0 * float(al[k]))
			var c10 := Color(cols[k], l1 * float(al[k]))
			var c01 := Color(cols[k + 1], l0 * float(al[k + 1]))
			var c11 := Color(cols[k + 1], l1 * float(al[k + 1]))
			capa.draw_primitive(PackedVector2Array([p00, p10, p11]), PackedColorArray([c00, c10, c11]), PackedVector2Array())
			capa.draw_primitive(PackedVector2Array([p00, p11, p01]), PackedColorArray([c00, c11, c01]), PackedVector2Array())


# Un barrido de 'desde' a 'hasta' que empieza en 't0', tarda 'dur' (lento al arrancar, rapidisimo al
# final: s^2), se queda clavado 'clavado' y se apaga de golpe en 'apaga'. Con el destello al clavarse.
func _barrido(capa: Node2D, t0: float, dur: float, desde: float, hasta: float, r: float, grueso: float,
		alto: float, clavado: float, apaga_t: float, destello_r: float) -> void:
	var tk: float = _t - t0
	if tk < 0.0:
		return
	var s: float = clampf(tk / dur, 0.0, 1.0)
	var cabeza: float = lerpf(desde, hasta, s * s)
	var tc: float = tk - dur
	var apaga: float = clampf((tc - clavado) / apaga_t, 0.0, 1.0)
	if apaga >= 1.0:
		return
	# Clavado, la cola se recoge hacia la cabeza: se queda el mordisco gordo.
	var recoge: float = clampf(tc / maxf(clavado, 0.01), 0.0, 1.0) if tc > 0.0 else 0.0
	var largo_cola: float = COLA * (1.0 - 0.55 * recoge)
	var sentido: float = signf(hasta - desde)
	var cola: float = cabeza - sentido * minf(largo_cola, absf(cabeza - desde))
	_mordisco(capa, cola, cabeza, r, grueso, alto, 0.95 * (1.0 - apaga))
	var p: Vector2 = _en_arco(cabeza, r, alto)
	if _es_mia(capa, p, alto):
		var pulso: float = exp(-absf(tc) / 0.04)
		BarridoAire.destello(capa, p, destello_r * (0.3 + 0.9 * pulso), Color(BLANCO, (1.0 - apaga) * (0.5 + 0.5 * pulso)), _t * 2.0)


func _hachazo(capa: Node2D) -> void:
	var mitad: float = deg_to_rad(forma.apertura * 0.5)
	var izq: float = _dir.angle() - mitad
	_barrido(capa, 0.0, T_BRUTAL, izq, izq + 2.0 * mitad, forma.radio * 0.95, forma.radio * 0.58,
		ALTO_BRUTAL, T_CLAVADO, T_APAGA_SECO, 22.0)


func _carniceria(capa: Node2D) -> void:
	var mitad: float = deg_to_rad(forma.apertura * 0.5)
	for k in 3:
		var b: Dictionary = _barridos[k]
		var m: float = mitad * float(b["abre"])
		var eje: float = _dir.angle() + float(b["giro"])
		var desde: float = eje - m if k % 2 == 0 else eje + m
		var hasta: float = eje + m if k % 2 == 0 else eje - m
		_barrido(capa, float(k) * T_ENTRE, T_CARNE, desde, hasta, float(b["r"]), forma.radio * 0.4,
			float(b["alto"]), 0.04, 0.08, 12.0)


# EL GANCHO del Desgarro: recto hacia delante y, al final, la punta se curva de vuelta hacia ti.
func _camino_gancho(s: float) -> Vector2:
	var r: float = forma.radio
	var nor: Vector2 = _dir.orthogonal()
	if s <= 0.7:
		var u: float = s / 0.7
		return _centro + _dir * lerpf(r * 0.3, r * 0.92, u) + nor * sin(PI * u) * r * 0.1
	var th: float = PI * (s - 0.7) / 0.3
	var rh: float = r * 0.2
	var hc: Vector2 = _centro + _dir * r * 0.92 - nor * rh
	return hc + (nor * cos(th) + _dir * sin(th)) * rh


func _desgarro(capa: Node2D) -> void:
	var alto: float = 6.0
	var s_cab: float = clampf(_t / T_GANCHO, 0.0, 1.0)
	s_cab = 1.0 - pow(1.0 - s_cab, 1.6)
	var apaga: float = clampf((_t - T_GANCHO - 0.05) / 0.12, 0.0, 1.0)
	if apaga >= 1.0:
		return
	var s_cola: float = maxf(0.0, s_cab - 0.5 - 0.3 * clampf((_t - T_GANCHO) / 0.05, 0.0, 1.0))
	var n: int = 18
	var alfa: float = 0.95 * (1.0 - apaga)
	var grueso: float = 10.0
	# Los puntos y UNA perpendicular por punto (la media de sus dos tramos): asi los trozos comparten
	# borde y en la curva no salen rayitas entre ellos.
	var pts := PackedVector2Array()
	for i in n + 1:
		pts.append(_camino_gancho(lerpf(s_cola, s_cab, float(i) / float(n))) + Vector2(0.0, -alto))
	var nors: Array = []
	for i in n + 1:
		var a: Vector2 = pts[maxi(i - 1, 0)]
		var b: Vector2 = pts[mini(i + 1, n)]
		nors.append((b - a).normalized().orthogonal() if b.distance_squared_to(a) > 0.0001 else _dir.orthogonal())
	for i in n:
		var p0: Vector2 = pts[i]
		var p1: Vector2 = pts[i + 1]
		if not _es_mia(capa, (p0 + p1) * 0.5, alto):
			continue
		var d0: Vector2 = nors[i]
		var d1: Vector2 = nors[i + 1]
		var u0: float = float(i) / float(n)
		var u1: float = float(i + 1) / float(n)
		var w0: float = grueso * (0.15 + 0.85 * u0)
		var w1: float = grueso * (0.15 + 0.85 * u1)
		var l0: float = alfa * (0.15 + 0.85 * u0)
		var l1: float = alfa * (0.15 + 0.85 * u1)
		# Filo duro por fuera (+d), difuminado por dentro hacia el rojo.
		var bl0 := Color(BLANCO, l0)
		var bl1 := Color(BLANCO, l1)
		var ro0 := Color(SANGRE, 0.0)
		var ro1 := Color(SANGRE, 0.0)
		var ac0 := Color(ACERO, l0 * 0.7)
		var ac1 := Color(ACERO, l1 * 0.7)
		capa.draw_primitive(PackedVector2Array([p0 + d0 * w0 * 0.5, p1 + d1 * w1 * 0.5, p1]),
			PackedColorArray([bl0, bl1, ac1]), PackedVector2Array())
		capa.draw_primitive(PackedVector2Array([p0 + d0 * w0 * 0.5, p1, p0]),
			PackedColorArray([bl0, ac1, ac0]), PackedVector2Array())
		capa.draw_primitive(PackedVector2Array([p0, p1, p1 - d1 * w1 * 0.5]),
			PackedColorArray([ac0, ac1, ro1]), PackedVector2Array())
		capa.draw_primitive(PackedVector2Array([p0, p1 - d1 * w1 * 0.5, p0 - d0 * w0 * 0.5]),
			PackedColorArray([ac0, ro1, ro0]), PackedVector2Array())
	var pc: Vector2 = _camino_gancho(s_cab) + Vector2(0.0, -alto)
	if _es_mia(capa, pc, alto):
		var pulso: float = exp(-absf(_t - T_GANCHO) / 0.04)
		BarridoAire.destello(capa, pc, 5.0 + 9.0 * pulso, Color(BLANCO, alfa * (0.4 + 0.6 * pulso)), 0.3)


# LA CAIDA de la Hendedura: una media luna en VERTICAL que baja sobre donde empieza la raja.
func _hendedura(capa: Node2D) -> void:
	if capa != _delante:
		return
	var ini: Vector2 = _raja[0] if not _raja.is_empty() else _centro
	var alto_ini: float = 46.0
	var s: float = clampf(_t / T_CAE, 0.0, 1.0)
	s = s * s
	var apaga: float = clampf((_t - T_CAE - 0.03) / 0.1, 0.0, 1.0)
	if apaga >= 1.0:
		return
	var alfa: float = 0.95 * (1.0 - apaga)
	var s_cola: float = maxf(0.0, s - 0.6)
	var n: int = 12
	var lado: Vector2 = _dir * 4.0   # un pelo curvada hacia donde raja
	for i in n:
		var u0: float = lerpf(s_cola, s, float(i) / float(n))
		var u1: float = lerpf(s_cola, s, float(i + 1) / float(n))
		var p0: Vector2 = ini + Vector2(0.0, -alto_ini * (1.0 - u0)) + lado * sin(PI * u0)
		var p1: Vector2 = ini + Vector2(0.0, -alto_ini * (1.0 - u1)) + lado * sin(PI * u1)
		var k0: float = float(i) / float(n)
		var k1: float = float(i + 1) / float(n)
		var w0: float = 10.0 * (0.15 + 0.85 * k0)
		var w1: float = 10.0 * (0.15 + 0.85 * k1)
		var d: Vector2 = Vector2(1.0, 0.0)
		var c0 := Color(BLANCO, alfa * (0.2 + 0.8 * k0))
		var c1 := Color(BLANCO, alfa * (0.2 + 0.8 * k1))
		var r0 := Color(SANGRE, 0.0)
		capa.draw_primitive(PackedVector2Array([p0 + d * w0 * 0.5, p1 + d * w1 * 0.5, p1 - d * w1 * 0.5]),
			PackedColorArray([c0, c1, r0]), PackedVector2Array())
		capa.draw_primitive(PackedVector2Array([p0 + d * w0 * 0.5, p1 - d * w1 * 0.5, p0 - d * w0 * 0.5]),
			PackedColorArray([c0, r0, r0]), PackedVector2Array())
	var pulso: float = exp(-absf(_t - T_CAE) / 0.04)
	BarridoAire.destello(capa, ini, 6.0 + 14.0 * pulso, Color(BLANCO, alfa * pulso), 0.2)
	# Las piedras que salta al clavarse.
	var tp: float = _t - T_CAE - T_RAJA
	if tp > 0.0 and _raja.size() > 0:
		for p in _piedras:
			var z: float = float(p["vz"]) * tp - SueloRoto.GRAVEDAD_PIEDRAS * tp * tp
			if z < 0.0:
				continue
			var q: Vector2 = _raja[_raja.size() - 1] + (p["v"] as Vector2) * tp + Vector2(0.0, -z * SueloRoto.K_ALTO)
			var tam: float = float(p["tam"])
			capa.draw_rect(Rect2(q - Vector2(tam, tam) * 0.5, Vector2(tam, tam)), TIERRA)


# LA MIRADA ASESINA: los ojos, la presion roja en el cono y el pulso sobre ti.
func _mirada(capa: Node2D) -> void:
	var cuerpo: Vector2 = _centro + Vector2(0.0, -22.0)
	if capa == _atras:
		# El pulso: dos latidos rojos alrededor del cuerpo, detras de el.
		for tb in [0.0, 0.28]:
			var k: float = (_t - float(tb)) / 0.32
			if k < 0.0 or k > 1.0:
				continue
			BarridoAire.brillo(capa, cuerpo, 18.0 + 16.0 * k, Color(SANGRE_VIVA, 0.75 * (1.0 - k)))
		return
	# Los OJOS: dos puntos rojos que se encienden y se van.
	var ojos: Vector2 = _centro + Vector2(0.0, -ALTO_OJOS)
	var ko: float = clampf(_t / 0.06, 0.0, 1.0) * (1.0 - clampf((_t - 0.35) / 0.2, 0.0, 1.0))
	if ko > 0.0:
		for lado in [-2.2, 2.2]:
			BarridoAire.brillo(capa, ojos + Vector2(lado, 0.0), 3.5, Color(SANGRE_VIVA, 0.9 * ko))
			BarridoAire.brillo(capa, ojos + Vector2(lado, 0.0), 1.2, Color(1.0, 0.75, 0.7, ko))
		var destello_k: float = exp(-absf(_t - 0.06) / 0.05)
		BarridoAire.destello(capa, ojos + Vector2(2.2, 0.0), 7.0 * destello_k, Color(1.0, 0.5, 0.45, destello_k * ko), 0.4)
	# LA PRESION: dos frentes rojos y tenues que se abren en el cono, difuminados (sin borde).
	var mitad: float = deg_to_rad(forma.apertura * 0.5)
	var a0: float = _dir.angle() - mitad
	var a1: float = _dir.angle() + mitad
	for k in 2:
		var tk: float = _t - 0.08 - float(k) * 0.12
		if tk < 0.0:
			continue
		var prog: float = clampf(tk / T_MIRADA, 0.0, 1.0)
		var apaga: float = clampf((tk - T_MIRADA) / 0.2, 0.0, 1.0)
		var rf: float = lerpf(8.0, forma.radio, prog)
		var alfa: float = (0.8 - 0.2 * float(k)) * (1.0 - 0.5 * prog) * (1.0 - apaga)
		if alfa <= 0.0:
			continue
		var grueso: float = lerpf(12.0, 28.0, prog)
		var n: int = 20
		for i in n:
			var s0: float = float(i) / float(n)
			var s1: float = float(i + 1) / float(n)
			var b0: float = sin(s0 * PI)
			var b1: float = sin(s1 * PI)
			var ang0: float = lerpf(a0, a1, s0)
			var ang1: float = lerpf(a0, a1, s1)
			# Lo mas fuerte en medio de la banda y a nada por los dos lados.
			var fu0: Vector2 = _en_arco(ang0, rf, 10.0)
			var fu1: Vector2 = _en_arco(ang1, rf, 10.0)
			var me0: Vector2 = _en_arco(ang0, maxf(rf - grueso * 0.35, 0.0), 10.0)
			var me1: Vector2 = _en_arco(ang1, maxf(rf - grueso * 0.35, 0.0), 10.0)
			var de0: Vector2 = _en_arco(ang0, maxf(rf - grueso, 0.0), 10.0)
			var de1: Vector2 = _en_arco(ang1, maxf(rf - grueso, 0.0), 10.0)
			var c0 := Color(SANGRE_VIVA, alfa * b0)
			var c1 := Color(SANGRE_VIVA, alfa * b1)
			var tr := Color(SANGRE_VIVA, 0.0)
			capa.draw_primitive(PackedVector2Array([fu0, fu1, me1]), PackedColorArray([tr, tr, c1]), PackedVector2Array())
			capa.draw_primitive(PackedVector2Array([fu0, me1, me0]), PackedColorArray([tr, c1, c0]), PackedVector2Array())
			capa.draw_primitive(PackedVector2Array([me0, me1, de1]), PackedColorArray([c0, c1, tr]), PackedVector2Array())
			capa.draw_primitive(PackedVector2Array([me0, de1, de0]), PackedColorArray([c0, tr, tr]), PackedVector2Array())
