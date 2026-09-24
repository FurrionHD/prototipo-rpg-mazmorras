# ============================================================
#  barrido_aire.gd
#  TRES EFECTOS DEL MANDOBLE en el mapa (24/09/2026), los que no rompen el suelo sino que cortan o
#  empujan el aire. Van por el mismo camino que el suelo roto (ficha -> SueloRoto.lanzar, red, instante
#  del golpe), cada uno con su tipo:
#    GIRO    el Molinete: DOS vueltas enteras con la espada extendida delante. La estela es un anillo a
#            la altura de la cintura que sigue a la punta; cada vuelta acaba en su golpe.
#    SIEGA   el Segar: brazo extendido y barrido bajo, a la derecha y de vuelta a la izquierda, dentro
#            de su cono. Un barrido por golpe; salta tierra al paso.
#    GRITO   el Grito de guerra: una onda de aire que se abre en el cono y empuja polvo; el golpe (y el
#            miedo) le llega a cada uno cuando la onda le alcanza.
#  Coordenadas de MUNDO. Lo que va en el aire se parte en dos nodos: lo que queda DETRAS del que golpea
#  (mas arriba en pantalla) por debajo de los cuerpos y lo de delante por encima, para que la estela le
#  rodee de verdad. Todo sale de una semilla: igual en todas las maquinas.
# ============================================================
extends Node2D
class_name BarridoAire

enum Modo { GIRO, SIEGA, GRITO }

const T_ENTRE := 0.2         # entre golpe y golpe de la misma accion (CombatFX.T_ENCADENADO)
const T_APAGAR := 0.25
const T_BARRIDO := 0.14      # lo que dura un barrido del Segar
const T_ONDA := 0.45         # lo que tarda la onda del Grito en llegar a su borde
const ALTO_GIRO := 9.0       # la estela del Molinete, a la altura de la cintura (px de pantalla)
const ALTO_SIEGA := 3.0      # la del Segar, a ras de piernas
const COLA_GIRO := deg_to_rad(230.0)
const BLANCO := Color(0.97, 0.98, 1.0)
const AIRE := Color(0.74, 0.82, 0.94)
const POLVO := SueloRoto.POLVO
const TIERRA := Color(0.45, 0.40, 0.33)

# EL RITMO DE LA PELEA (CombatFX.escala_tiempo): el reloj de este efecto va en tiempo de ANIMACION, el
# mismo en el que caen sus golpes (T_ENTRE entre uno y otro). Lo pone CombatFX antes de lanzarlo.
static var ritmo: float = 1.0

var modo: int = Modo.GIRO
var _ritmo: float = 1.0
var forma: CombatFormas.Forma = null
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _atras: Node2D = null
var _delante: Node2D = null
var _centro: Vector2 = Vector2.ZERO
var _dir: Vector2 = Vector2.RIGHT
var _polvo: Array = []
var _motas: Array = []
var _rayas: Array = []
var _chispas_datos: Array = []   # {t0 (cuando sale), vel, abre}


# 'espera' = segundos hasta el PRIMER golpe.
static func lanzar(padre: Node, f: CombatFormas.Forma, m: int, semilla: int, espera: float) -> BarridoAire:
	if padre == null or f == null:
		return null
	var b := BarridoAire.new()
	b.modo = m
	b.forma = f
	b._rng.seed = semilla
	# El Molinete da la vuelta ANTES de su golpe y el Segar barre antes del suyo: arrancan antes.
	var antes: float = T_ENTRE if m == Modo.GIRO else (T_BARRIDO if m == Modo.SIEGA else 0.0)
	b._ritmo = maxf(ritmo, 0.05)
	b._t = antes - espera * b._ritmo
	b.z_as_relative = false
	b.z_index = SueloRoto.Z_SUELO
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(b)
	return b


# Cuando le llega el golpe a 'd' px de quien lo lanza. Solo el Grito tarda: los dos barridos pegan en
# el instante de su golpe (la estela ya va delante).
static func retraso_px(m: int, d: float, radio: float) -> float:
	if m != Modo.GRITO:
		return 0.0
	return T_ONDA * clampf(d / maxf(radio, 1.0), 0.0, 1.0)


func duracion() -> float:
	match modo:
		Modo.GIRO: return 2.0 * T_ENTRE + T_APAGAR + 0.3
		Modo.SIEGA: return T_BARRIDO + T_ENTRE + T_APAGAR + 0.3
	return T_ONDA + 0.16 + 0.5


func _ready() -> void:
	_centro = forma.origen if modo != Modo.GIRO else forma.centro
	_dir = forma.dir.normalized() if forma.dir.length_squared() > 0.0001 else Vector2.RIGHT
	_atras = _capa(Game.Z_PERSONAJES - 1)
	_delante = _capa(Game.Z_PERSONAJES + 80)
	if modo != Modo.GRITO:
		var hasta: float = 2.0 * T_ENTRE if modo == Modo.GIRO else T_ENTRE + T_BARRIDO
		for i in 22:
			var t0: float = _rng.randf_range(0.0, hasta)
			# En el Segar solo mientras barre (no en la pausa entre los dos barridos).
			if modo == Modo.SIEGA and t0 > T_BARRIDO and t0 < T_ENTRE:
				t0 -= T_BARRIDO * 0.5
			_chispas_datos.append({"t0": t0, "vel": _rng.randf_range(90.0, 170.0), "abre": _rng.randf_range(0.1, 0.7)})
	match modo:
		Modo.GIRO:
			# Al acabar cada vuelta, un anillo de polvo que se abre a ras de suelo.
			for k in 2:
				for i in 10:
					var a: float = TAU * (float(i) + _rng.randf_range(-0.3, 0.3)) / 10.0
					_polvo.append({"t0": T_ENTRE * float(k + 1), "a": a, "r": _rng.randf_range(3.0, 5.5),
						"sale": _rng.randf_range(6.0, 14.0)})
		Modo.SIEGA:
			# Tierra que salta al paso de cada barrido.
			for k in 2:
				for i in 9:
					var u: float = (float(i) + _rng.randf_range(0.0, 1.0)) / 9.0
					_motas.append({"k": k, "u": u, "r": forma.radio * _rng.randf_range(0.55, 0.95),
						"v": Vector2(_rng.randf_range(15.0, 35.0), _rng.randf_range(35.0, 70.0)),
						"tam": _rng.randf_range(1.2, 2.4)})
		Modo.GRITO:
			for i in 16:
				_rayas.append({"a": _rng.randf_range(-0.5, 0.5), "largo": _rng.randf_range(10.0, 22.0),
					"retraso": _rng.randf_range(0.0, 0.12)})
			for i in 14:
				_polvo.append({"a": _rng.randf_range(-0.5, 0.5), "d": _rng.randf_range(0.2, 0.95) * forma.radio,
					"r": _rng.randf_range(3.0, 6.0), "sale": _rng.randf_range(8.0, 18.0)})


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


# ------------------------------------------------------------
#  EL SUELO: polvo y tierra
# ------------------------------------------------------------
func _draw() -> void:
	if _t < 0.0:
		return
	match modo:
		Modo.GIRO:
			for p in _polvo:
				var tp: float = _t - float(p["t0"])
				if tp < 0.0 or tp > 0.45:
					continue
				var k: float = tp / 0.45
				var a: float = float(p["a"])
				var c: Vector2 = _centro + Vector2(cos(a), sin(a)) * (forma.radio * 0.9 + float(p["sale"]) * sqrt(k))
				draw_circle(c, float(p["r"]) * (1.0 + k), Color(POLVO, 0.35 * (1.0 - k)))
		Modo.GRITO:
			for p in _polvo:
				var tp2: float = _t - retraso_px(modo, float(p["d"]), forma.radio)
				if tp2 < 0.0 or tp2 > 0.6:
					continue
				var k2: float = tp2 / 0.6
				var ang: float = _dir.angle() + float(p["a"]) * deg_to_rad(forma.apertura)
				var c2: Vector2 = _centro + Vector2(cos(ang), sin(ang)) * (float(p["d"]) + float(p["sale"]) * sqrt(k2))
				draw_circle(c2, float(p["r"]) * (1.0 + 0.8 * k2), Color(POLVO, 0.32 * (1.0 - k2)))


# ------------------------------------------------------------
#  EL AIRE (cada capa pinta lo suyo: detras o delante del que golpea)
# ------------------------------------------------------------
func _dibujar_capa(capa: Node2D) -> void:
	if _t < 0.0:
		return
	match modo:
		Modo.GIRO: _giro(capa)
		Modo.SIEGA: _siega(capa)
		Modo.GRITO: _grito(capa)


func _es_mia(capa: Node2D, p: Vector2, alto: float) -> bool:
	var detras: bool = p.y < _centro.y - alto
	return detras == (capa == _atras)


# Un punto de un arco alrededor del centro, a 'alto' px de pantalla sobre el suelo.
func _en_arco(a: float, r: float, alto: float) -> Vector2:
	return _centro + Vector2(cos(a), sin(a)) * r + Vector2(0.0, -alto)


# UN TAJO EN MEDIA LUNA sobre un arco, de 'a_cola' a 'a_cabeza' (el estilo que le gusto en el Verdugo,
# 24/09): el FILO (el borde de fuera, a 'r_filo') DURO y blanco, y hacia dentro y hacia la cola se
# DIFUMINA hasta nada, sin raya. Grueso cerca de la cabeza y afilado en las dos puntas. 'alfa' lo apaga.
func _tajo(capa: Node2D, a_cola: float, a_cabeza: float, r_filo: float, grueso: float, alto: float,
		alfa: float) -> void:
	if alfa <= 0.0 or absf(a_cabeza - a_cola) < 0.01:
		return
	var n: int = maxi(8, int(absf(a_cabeza - a_cola) / 0.08))
	# De fuera (0, el filo) hacia dentro (1): cuanto se ve en cada franja.
	var fr: Array = [0.0, 0.12, 0.4, 1.0]
	var al: Array = [1.0, 0.85, 0.3, 0.0]
	for i in n:
		var s0: float = float(i) / float(n)
		var s1: float = float(i + 1) / float(n)
		var a0: float = lerpf(a_cola, a_cabeza, s0)
		var a1: float = lerpf(a_cola, a_cabeza, s1)
		if not _es_mia(capa, _en_arco((a0 + a1) * 0.5, r_filo, alto), alto):
			continue
		# Grueso cerca de la cabeza (max hacia el 73%) y a cero en la cola y en la punta.
		var g0: float = grueso * sin(PI * pow(s0, 2.2))
		var g1: float = grueso * sin(PI * pow(s1, 2.2))
		var l0: float = alfa * (0.2 + 0.8 * s0)
		var l1: float = alfa * (0.2 + 0.8 * s1)
		for k in fr.size() - 1:
			var p00: Vector2 = _en_arco(a0, r_filo - g0 * float(fr[k]), alto)
			var p10: Vector2 = _en_arco(a1, r_filo - g1 * float(fr[k]), alto)
			var p01: Vector2 = _en_arco(a0, r_filo - g0 * float(fr[k + 1]), alto)
			var p11: Vector2 = _en_arco(a1, r_filo - g1 * float(fr[k + 1]), alto)
			var c00 := Color(AIRE.lerp(BLANCO, 1.0 - float(fr[k])), l0 * float(al[k]))
			var c10 := Color(AIRE.lerp(BLANCO, 1.0 - float(fr[k])), l1 * float(al[k]))
			var c01 := Color(AIRE, l0 * float(al[k + 1]))
			var c11 := Color(AIRE, l1 * float(al[k + 1]))
			capa.draw_primitive(PackedVector2Array([p00, p10, p11]), PackedColorArray([c00, c10, c11]), PackedVector2Array())
			capa.draw_primitive(PackedVector2Array([p00, p11, p01]), PackedColorArray([c00, c11, c01]), PackedVector2Array())


# El tajo con sus ECOS: dos medias lunas mas finas y cortas por dentro, como las rayas de un tajo de
# manga, y el destello de la punta.
func _tajo_con_ecos(capa: Node2D, a_cola: float, a_cabeza: float, r: float, alto: float, alfa: float) -> void:
	_tajo(capa, a_cola, a_cabeza, r * 0.97, r * 0.45, alto, alfa)
	_tajo(capa, lerpf(a_cola, a_cabeza, 0.35), a_cabeza, r * 0.7, r * 0.16, alto, alfa * 0.5)
	_tajo(capa, lerpf(a_cola, a_cabeza, 0.55), a_cabeza, r * 0.5, r * 0.1, alto, alfa * 0.35)
	var p: Vector2 = _en_arco(a_cabeza, r * 0.97, alto)
	if _es_mia(capa, p, alto):
		# El destello de la punta: siempre uno pequeño, y GRANDE en el instante de cada golpe.
		var pulso: float = 0.0
		for th in _t_golpes():
			pulso = maxf(pulso, exp(-absf(_t - float(th)) / 0.035))
		destello(capa, p, 6.0 + 16.0 * pulso, Color(BLANCO, alfa * (0.7 + 0.3 * pulso)), _t * 3.0)


# Los instantes de los golpes, en el reloj de este efecto.
func _t_golpes() -> Array:
	match modo:
		Modo.GIRO: return [T_ENTRE, 2.0 * T_ENTRE]
		Modo.SIEGA: return [T_BARRIDO, T_ENTRE + T_BARRIDO]
	return [0.0]


# LAS CHISPAS que suelta la punta al pasar: salen hacia delante y hacia fuera y se apagan enseguida.
# 'cabeza_en' = Callable(t) -> angulo de la punta en ese instante; 'sentido' = +1/-1 hacia donde gira.
func _chispas(capa: Node2D, r: float, alto: float, cabeza_en: Callable, sentido: float) -> void:
	for ch in _chispas_datos:
		var t0: float = float(ch["t0"])
		var tp: float = _t - t0
		if tp < 0.0 or tp > 0.2:
			continue
		var a: float = float(cabeza_en.call(t0))
		var tang: Vector2 = Vector2(-sin(a), cos(a)) * sentido
		var fuera: Vector2 = Vector2(cos(a), sin(a))
		var v: Vector2 = (tang + fuera * float(ch["abre"])).normalized() * float(ch["vel"])
		var p0: Vector2 = _en_arco(a, r * 0.97, alto) + v * tp
		if not _es_mia(capa, p0, alto):
			continue
		var k: float = tp / 0.2
		cometa(capa, p0 - v.normalized() * 6.0, p0, 1.6, Color(BLANCO, 0.9 * (1.0 - k)))


# El MOLINETE: dos vueltas en el sentido de las agujas, empezando hacia donde miras.
func _giro(capa: Node2D) -> void:
	var w: float = TAU / T_ENTRE
	var fin: float = 2.0 * T_ENTRE
	var cabeza: float = _dir.angle() + w * minf(_t, fin)
	var apaga: float = clampf((_t - fin) / T_APAGAR, 0.0, 1.0)
	var cola_len: float = COLA_GIRO * (1.0 - apaga)
	var r: float = forma.radio
	if cola_len > 0.01:
		_tajo_con_ecos(capa, cabeza - minf(cola_len, w * _t), cabeza, r, ALTO_GIRO, 0.95 * (1.0 - apaga))
	var a_ini: float = _dir.angle()
	_chispas(capa, r, ALTO_GIRO, func(t: float) -> float: return a_ini + w * minf(t, fin), 1.0)


# El SEGAR: primero de izquierda a derecha (hacia TU derecha) y luego de vuelta.
func _siega(capa: Node2D) -> void:
	var mitad: float = deg_to_rad(forma.apertura * 0.5)
	var izq: float = _dir.angle() - mitad
	var der: float = _dir.angle() + mitad
	var r: float = forma.radio
	for k in 2:
		var t0: float = float(k) * T_ENTRE
		var tk: float = _t - t0
		if tk < 0.0:
			continue
		var avance: float = clampf(tk / T_BARRIDO, 0.0, 1.0)
		avance = 1.0 - pow(1.0 - avance, 2.0)
		var apaga: float = clampf((tk - T_BARRIDO) / T_APAGAR, 0.0, 1.0)
		if apaga >= 1.0:
			continue
		var desde: float = izq if k == 0 else der
		var hasta: float = der if k == 0 else izq
		var cabeza: float = lerpf(desde, hasta, avance)
		var cola: float = lerpf(desde, cabeza, apaga)
		_tajo_con_ecos(capa, cola, cabeza, r, ALTO_SIEGA, 0.95 * (1.0 - apaga))
	# Las chispas de la punta, en cada barrido (hacia la derecha el primero, de vuelta el segundo).
	_chispas(capa, r, ALTO_SIEGA, func(t: float) -> float:
		var k3: int = 0 if t < T_ENTRE else 1
		var av: float = clampf((t - float(k3) * T_ENTRE) / T_BARRIDO, 0.0, 1.0)
		av = 1.0 - pow(1.0 - av, 2.0)
		return lerpf(izq, der, av) if k3 == 0 else lerpf(der, izq, av), 1.0)
	# La tierra que salta a su paso.
	for m in _motas:
		var k2: int = int(m["k"])
		var cuando: float = float(k2) * T_ENTRE + T_BARRIDO * float(m["u"] if k2 == 0 else 1.0 - float(m["u"]))
		var tp: float = _t - cuando
		if tp < 0.0 or tp > 0.4:
			continue
		var ang: float = lerpf(izq, der, float(m["u"]))
		var v: Vector2 = m["v"]
		var z: float = v.y * tp - SueloRoto.GRAVEDAD_PIEDRAS * tp * tp
		if z < 0.0:
			continue
		var sale: Vector2 = Vector2(cos(ang), sin(ang))
		var p2: Vector2 = _centro + sale * (float(m["r"]) + v.x * tp) + Vector2(0.0, -z * SueloRoto.K_ALTO)
		if not _es_mia(capa, p2, 0.0):
			continue
		var tam: float = float(m["tam"])
		capa.draw_rect(Rect2(p2 - Vector2(tam, tam) * 0.5, Vector2(tam, tam)), TIERRA)


# El GRITO: tres frentes de aire que se abren en el cono, y rayas que salen con ellos.
func _grito(capa: Node2D) -> void:
	if capa != _delante:
		return
	var mitad: float = deg_to_rad(forma.apertura * 0.5)
	var a0: float = _dir.angle() - mitad
	var a1: float = _dir.angle() + mitad
	for k in 3:
		var tk: float = _t - float(k) * 0.08
		if tk < 0.0:
			continue
		var prog: float = clampf(tk / T_ONDA, 0.0, 1.0)
		var rf: float = forma.radio * prog
		var apaga: float = clampf((tk - T_ONDA) / 0.2, 0.0, 1.0)
		var alfa: float = (0.55 - 0.15 * float(k)) * (1.0 - 0.5 * prog) * (1.0 - apaga)
		if alfa <= 0.0 or rf < 4.0:
			continue
		var grueso: float = lerpf(5.0, 14.0, prog)
		var n: int = 24
		for i in n:
			var s0: float = float(i) / float(n)
			var s1: float = float(i + 1) / float(n)
			# Los bordes del abanico, mas flojos: la onda se apaga hacia los lados.
			var borde0: float = sin(s0 * PI)
			var borde1: float = sin(s1 * PI)
			var ang0: float = lerpf(a0, a1, s0)
			var ang1: float = lerpf(a0, a1, s1)
			var f0: Vector2 = _en_arco(ang0, rf, 4.0)
			var f1: Vector2 = _en_arco(ang1, rf, 4.0)
			var d0: Vector2 = _en_arco(ang0, maxf(rf - grueso, 0.0), 4.0)
			var d1: Vector2 = _en_arco(ang1, maxf(rf - grueso, 0.0), 4.0)
			var c0 := Color(BLANCO, alfa * borde0)
			var c1 := Color(BLANCO, alfa * borde1)
			capa.draw_primitive(PackedVector2Array([f0, f1, d1]),
				PackedColorArray([c0, c1, Color(AIRE, 0.0)]), PackedVector2Array())
			capa.draw_primitive(PackedVector2Array([f0, d1, d0]),
				PackedColorArray([c0, Color(AIRE, 0.0), Color(AIRE, 0.0)]), PackedVector2Array())
	# Las rayas de velocidad, saliendo con el primer frente.
	for ry in _rayas:
		var tr: float = _t - float(ry["retraso"])
		var prog2: float = clampf(tr / T_ONDA, 0.0, 1.0)
		if tr < 0.0 or prog2 >= 1.0:
			continue
		var ang2: float = _dir.angle() + float(ry["a"]) * deg_to_rad(forma.apertura)
		var rr: float = forma.radio * prog2
		var p0: Vector2 = _en_arco(ang2, maxf(rr - float(ry["largo"]), 0.0), 4.0)
		var p1: Vector2 = _en_arco(ang2, rr, 4.0)
		cometa(capa, p0, p1, 1.8, Color(BLANCO, 0.45 * (1.0 - prog2)))


# NADA DE LINEAS en estos efectos (lo pidio el usuario, 24/09: "una linea literal es una mierda"). Lo que
# antes era una raya ahora es una COMETA rellena: ancha y opaca en la cabeza 'b', afilada y transparente
# en la cola 'a'.
static func cometa(ci: CanvasItem, a: Vector2, b: Vector2, ancho: float, col: Color) -> void:
	var d: Vector2 = b - a
	if d.length_squared() < 0.01:
		return
	var n: Vector2 = d.normalized().orthogonal() * ancho * 0.5
	var punta: Vector2 = b + d.normalized() * ancho * 0.6
	var transp := Color(col, 0.0)
	ci.draw_primitive(PackedVector2Array([a, b + n, b - n]), PackedColorArray([transp, col, col]), PackedVector2Array())
	ci.draw_primitive(PackedVector2Array([b + n, punta, b - n]), PackedColorArray([col, col, col]), PackedVector2Array())


# Un BRILLO suave: opaco en el centro y apagandose hacia fuera (no una bola con borde).
static func brillo(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var transp := Color(col, 0.0)
	var n: int = 12
	for i in n:
		var a0: float = TAU * float(i) / float(n)
		var a1: float = TAU * float(i + 1) / float(n)
		ci.draw_primitive(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * r, c + Vector2(cos(a1), sin(a1)) * r]),
			PackedColorArray([col, transp, transp]), PackedVector2Array())


# UN DESTELLO de los buenos (pedido 24/09: "se que puedes hacer destellos mejores"): estrella de cuatro
# puntas LARGAS y afiladas, cuatro cortas en diagonal, halo suave y nucleo blanco. Todo relleno, sin una
# sola raya. 'r' = largo de las puntas grandes; 'giro' lo ladea un poco.
static func destello(ci: CanvasItem, c: Vector2, r: float, col: Color, giro: float = 0.0) -> void:
	if col.a <= 0.0 or r <= 0.5:
		return
	brillo(ci, c, r * 0.75, Color(col, col.a * 0.25))
	var transp := Color(col, 0.0)
	for k in 8:
		var larga: bool = k % 2 == 0
		var ang: float = giro + PI * 0.25 * float(k)
		var largo: float = r if larga else r * 0.42
		var base: float = r * (0.13 if larga else 0.09)
		var d := Vector2(cos(ang), sin(ang))
		var n: Vector2 = d.orthogonal() * base
		ci.draw_primitive(PackedVector2Array([c + n, c + d * largo, c - n]),
			PackedColorArray([col, transp, col]), PackedVector2Array())
	brillo(ci, c, r * 0.28, Color(1, 1, 1, col.a))
