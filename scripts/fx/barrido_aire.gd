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

var modo: int = Modo.GIRO
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
	b._t = antes - espera
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
	_t += delta
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


# Una banda de arco de 'a_cola' a 'a_cabeza', de r0 a r1, que se enciende hacia la cabeza.
func _arco(capa: Node2D, a_cola: float, a_cabeza: float, r0: float, r1: float, alto: float, alfa: float) -> void:
	var n: int = maxi(6, int(absf(a_cabeza - a_cola) / 0.12))
	for i in n:
		var s0: float = float(i) / float(n)
		var s1: float = float(i + 1) / float(n)
		var a0: float = lerpf(a_cola, a_cabeza, s0)
		var a1: float = lerpf(a_cola, a_cabeza, s1)
		var medio: Vector2 = _en_arco((a0 + a1) * 0.5, r1, alto)
		if not _es_mia(capa, medio, alto):
			continue
		var c0: Color = Color(AIRE.lerp(BLANCO, s0), alfa * s0 * s0)
		var c1: Color = Color(AIRE.lerp(BLANCO, s1), alfa * s1 * s1)
		var fuera0: Vector2 = _en_arco(a0, r1, alto)
		var fuera1: Vector2 = _en_arco(a1, r1, alto)
		var dentro0: Vector2 = _en_arco(a0, lerpf(r0, r1, 0.5 * (1.0 - s0)), alto)
		var dentro1: Vector2 = _en_arco(a1, lerpf(r0, r1, 0.5 * (1.0 - s1)), alto)
		var transp0 := Color(c0, 0.0)
		var transp1 := Color(c1, 0.0)
		capa.draw_primitive(PackedVector2Array([fuera0, fuera1, dentro1]),
			PackedColorArray([c0, c1, transp1]), PackedVector2Array())
		capa.draw_primitive(PackedVector2Array([fuera0, dentro1, dentro0]),
			PackedColorArray([c0, transp1, transp0]), PackedVector2Array())
		capa.draw_line(fuera0, fuera1, Color(BLANCO, alfa * s1 * 0.9), 1.8)


# El MOLINETE: dos vueltas en el sentido de las agujas, empezando hacia donde miras.
func _giro(capa: Node2D) -> void:
	var w: float = TAU / T_ENTRE
	var fin: float = 2.0 * T_ENTRE
	var cabeza: float = _dir.angle() + w * minf(_t, fin)
	var apaga: float = clampf((_t - fin) / T_APAGAR, 0.0, 1.0)
	var cola_len: float = COLA_GIRO * (1.0 - apaga)
	if cola_len <= 0.01:
		return
	var r: float = forma.radio
	_arco(capa, cabeza - minf(cola_len, w * _t), cabeza, r * 0.3, r * 0.95, ALTO_GIRO, 0.9 * (1.0 - apaga))
	# La punta de la espada: un destello donde va la cabeza.
	if apaga < 0.5:
		var p: Vector2 = _en_arco(cabeza, r * 0.95, ALTO_GIRO)
		if _es_mia(capa, p, ALTO_GIRO):
			capa.draw_line(_en_arco(cabeza, r * 0.35, ALTO_GIRO), p, Color(BLANCO, 0.9 * (1.0 - apaga * 2.0)), 2.0)
			capa.draw_circle(p, 2.2, Color(BLANCO, 0.9 * (1.0 - apaga * 2.0)))


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
		_arco(capa, cola, cabeza, r * 0.35, r * 0.95, ALTO_SIEGA, 0.9 * (1.0 - apaga))
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
			capa.draw_line(f0, f1, Color(BLANCO, alfa * borde1), 1.5)
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
		capa.draw_line(p0, p1, Color(BLANCO, 0.45 * (1.0 - prog2)), 1.1)
