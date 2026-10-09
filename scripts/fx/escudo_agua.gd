# ============================================================
#  escudo_agua.gd  (class_name EscudoAgua)
#  EL ESCUDO DE AGUA DEL SET MAREA, VISIBLE (09/10/2026, su peticion: "como se ve visualmente el escudo de agua";
#  eligio "burbuja + barra"). Una BURBUJA de agua alrededor del cuerpo de quien lo lleva, con el agua del arrecife
#  (ProfundoAire: azul de mar, espuma blanca), toda rellena y con degradado, sin una sola raya:
#    - el agua honda va POR DETRAS del cuerpo y la membrana clara, el brillo y las burbujitas que suben, POR DELANTE;
#    - cuanto menos le queda, mas fina y transparente (y tiembla mas);
#    - cuando le pegan: una onda de espuma donde pega y la burbuja se sacude;
#    - cuando para un Lento o una Congelacion: destella entera (blanca) un momento;
#    - cuando se rompe: revienta en gotas que salen volando y caen, y una salpicadura en el suelo.
#  NO recibe avisos: MIRA el combatiente cada fotograma (lo que le queda, su maximo y los estados que ha parado). Asi vale
#  igual en quien lleva la pelea y en el ESPEJO, donde esos numeros llegan en la instantanea (combat_espejo, campo 11).
#  Lo monta y lo quita la pelea tactica (CombatTactico.pintar_escudos_agua), como hijo del cuerpo: le sigue solo.
# ============================================================
extends Node2D
class_name EscudoAgua

const K := 0.7071
const AGUA := Color(0.18, 0.55, 0.78)
const AGUA_CLARA := Color(0.5, 0.85, 1.0)
const AGUA_HONDA := Color(0.07, 0.28, 0.48)
const ESPUMA := Color(0.92, 0.98, 1.0)
const HOLGURA := Vector2(8.0, 7.0)   # lo que la burbuja sobresale del dibujo del cuerpo, por cada lado
const LADOS := 48
const T_ONDA := 0.4
const T_SACUDIDA := 0.45
const T_DESTELLO := 0.45
const T_REVIENTA := 0.7
const GOTAS := 16
const BURBUJITAS := 6

var _c: Combatant
var _caja: Rect2              # el dibujo del cuerpo, en coordenadas del cuerpo (el padre)
var _detras: Node2D
var _delante: Node2D
var _t: float = 0.0
var _visto: float = -1.0      # lo que tenia en el fotograma anterior
var _paradas: int = 0
var _ondas: Array = []        # {t, a}
var _sacudida: float = 0.0
var _destello: float = 0.0
var _rota: float = -1.0       # >= 0: reventando (segundos)
var _gotas: Array = []
var _burbujitas: Array = []
var _rng := RandomNumberGenerator.new()


# La pone (o la deja si ya esta) en 'cuerpo' para 'c'. 'caja' = el dibujo del cuerpo en coordenadas del MUNDO.
static func poner(cuerpo: Node2D, c: Combatant, caja: Rect2) -> EscudoAgua:
	var ya: EscudoAgua = de(cuerpo)
	if ya != null:
		ya._c = c
		return ya
	var e := EscudoAgua.new()
	e.name = "EscudoAgua"
	e._c = c
	e._caja = Rect2(caja.position - cuerpo.global_position, caja.size)
	e._rng.seed = hash(c.nombre)
	e._paradas = c.runa_agua_paradas
	cuerpo.add_child(e)
	return e


static func de(cuerpo: Node2D) -> EscudoAgua:
	return cuerpo.get_node_or_null("EscudoAgua") as EscudoAgua if is_instance_valid(cuerpo) else null


static func quitar(cuerpo: Node2D) -> void:
	var e: EscudoAgua = de(cuerpo)
	if e != null:
		e.queue_free()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # la pelea tactica pausa el arbol
	_detras = _capa(-10)
	_delante = _capa(30)
	for i in GOTAS:
		_gotas.append({"a": TAU * (float(i) + _rng.randf_range(-0.3, 0.3)) / float(GOTAS),
			"v": _rng.randf_range(0.7, 1.25), "h": _rng.randf_range(0.6, 1.2), "r": _rng.randf_range(2.6, 4.2)})
	for i in BURBUJITAS:
		_burbujitas.append({"x": _rng.randf_range(-0.6, 0.6), "p": _rng.randf_range(1.6, 2.8),
			"d": _rng.randf_range(0.0, 3.0), "r": _rng.randf_range(1.1, 2.0)})


func _capa(z: int) -> Node2D:
	var n := Node2D.new()
	n.z_index = z
	n.draw.connect(_pintar.bind(n))
	add_child(n)
	return n


func _process(delta: float) -> void:
	_t += delta
	if _c == null:
		queue_free()
		return
	var v: float = _c.runa_escudo_agua
	if _rota >= 0.0:
		_rota += delta
		if _rota >= T_REVIENTA:
			queue_free()
			return
	elif _visto > 0.0 and v <= 0.0:
		_rota = 0.0   # se acaba de romper
	elif _visto >= 0.0 and v < _visto - 0.01:
		# Le han pegado: una onda donde pega (por arriba y a los lados, que es donde se ve) y la sacudida.
		_ondas.append({"t": 0.0, "a": _rng.randf_range(PI * 1.05, PI * 1.95)})
		_sacudida = 1.0
	if _c.runa_agua_paradas > _paradas:
		_paradas = _c.runa_agua_paradas
		_destello = 1.0
	_visto = v
	for o in _ondas:
		o["t"] = float(o["t"]) + delta
	_ondas = _ondas.filter(func(o): return float(o["t"]) < T_ONDA)
	_sacudida = maxf(_sacudida - delta / T_SACUDIDA, 0.0)
	_destello = maxf(_destello - delta / T_DESTELLO, 0.0)
	visible = v > 0.0 or _rota >= 0.0
	_detras.queue_redraw()
	_delante.queue_redraw()


# Lo que le queda (0..1).
func _frac() -> float:
	return clampf(_c.runa_escudo_agua / maxf(_c.runa_escudo_max, 0.001), 0.0, 1.0) if _c != null else 0.0


func _centro() -> Vector2:
	return _caja.get_center()


func _radios() -> Vector2:
	return _caja.size * 0.5 + HOLGURA


# El borde de la burbuja en el angulo 'a', con su temblor (mas cuanto menos le queda y al sacudirse).
func _borde(a: float, escala: float = 1.0) -> Vector2:
	var tiembla: float = 0.025 + 0.04 * (1.0 - _frac()) + 0.07 * _sacudida * sin(_t * 38.0)
	var r: float = 1.0 + tiembla * (sin(3.0 * a + _t * 2.1) * 0.6 + sin(5.0 * a - _t * 3.3) * 0.4)
	var R: Vector2 = _radios() * escala * r
	return _centro() + Vector2(cos(a) * R.x, sin(a) * R.y)


func _pintar(capa: Node2D) -> void:
	if _c == null:
		return
	if _rota >= 0.0:
		_reventar(capa)
		return
	var f: float = _frac()
	var k: float = 0.4 + 0.6 * f    # cuanto menos le queda, mas transparente
	var blanco: float = _destello
	if capa == _detras:
		# EL AGUA HONDA por detras del cuerpo: casi transparente en el centro y mas densa hacia el borde.
		var c0: Vector2 = _centro()
		var col_c := Color(AGUA.lerp(ESPUMA, blanco * 0.6), (0.08 + 0.25 * blanco) * k)
		var col_b := Color(AGUA_HONDA.lerp(ESPUMA, blanco * 0.5), (0.30 + 0.3 * blanco) * k)
		for i in LADOS:
			var a0: float = TAU * float(i) / float(LADOS)
			var a1: float = TAU * float(i + 1) / float(LADOS)
			capa.draw_primitive(PackedVector2Array([c0, _borde(a0), _borde(a1)]),
				PackedColorArray([col_c, col_b, col_b]), PackedVector2Array())
		return
	# LA MEMBRANA por delante: una banda clara pegada al borde, que se difumina hacia dentro y hacia fuera (sin raya).
	# Mas gruesa con el escudo lleno; abajo algo mas densa (el agua pesa).
	var grosor: float = lerpf(0.06, 0.14, f)
	for i in LADOS:
		var a0: float = TAU * float(i) / float(LADOS)
		var a1: float = TAU * float(i + 1) / float(LADOS)
		var abajo: float = 0.5 + 0.5 * sin((a0 + a1) * 0.5)
		var col_m := Color(AGUA_CLARA.lerp(ESPUMA, blanco), (0.45 + 0.2 * abajo + 0.4 * blanco) * k)
		var col_0 := Color(col_m, 0.0)
		var i0: Vector2 = _borde(a0, 1.0 - grosor)
		var i1: Vector2 = _borde(a1, 1.0 - grosor)
		var m0: Vector2 = _borde(a0, 1.0 - grosor * 0.25)
		var m1: Vector2 = _borde(a1, 1.0 - grosor * 0.25)
		var o0: Vector2 = _borde(a0, 1.0 + grosor * 0.2)
		var o1: Vector2 = _borde(a1, 1.0 + grosor * 0.2)
		capa.draw_primitive(PackedVector2Array([i0, m0, m1]), PackedColorArray([col_0, col_m, col_m]), PackedVector2Array())
		capa.draw_primitive(PackedVector2Array([i0, m1, i1]), PackedColorArray([col_0, col_m, col_0]), PackedVector2Array())
		capa.draw_primitive(PackedVector2Array([m0, o0, o1]), PackedColorArray([col_m, col_0, col_0]), PackedVector2Array())
		capa.draw_primitive(PackedVector2Array([m0, o1, m1]), PackedColorArray([col_m, col_0, col_m]), PackedVector2Array())
	# EL BRILLO de arriba a la izquierda (la luz en el agua) y uno chiquito abajo a la derecha.
	var R: Vector2 = _radios()
	var c: Vector2 = _centro()
	BarridoAire.brillo(capa, c + Vector2(-R.x * 0.42, -R.y * 0.58), R.x * 0.3, Color(ESPUMA, 0.45 * k))
	BarridoAire.brillo(capa, c + Vector2(-R.x * 0.46, -R.y * 0.62), R.x * 0.11, Color(ESPUMA, 0.9 * k))
	BarridoAire.brillo(capa, c + Vector2(R.x * 0.5, R.y * 0.55), R.x * 0.1, Color(ESPUMA, 0.4 * k))
	# LAS BURBUJITAS que suben por dentro.
	for b in _burbujitas:
		var u: float = fmod(_t + float(b["d"]), float(b["p"])) / float(b["p"])
		var p := Vector2(c.x + float(b["x"]) * R.x * (0.9 - 0.3 * u) + sin(_t * 3.0 + float(b["d"])) * 1.5,
			lerpf(c.y + R.y * 0.7, c.y - R.y * 0.75, u))
		var vive: float = sin(PI * u)
		BarridoAire.brillo(capa, p, float(b["r"]) * 1.8, Color(AGUA_CLARA, 0.35 * vive * k))
		BarridoAire.brillo(capa, p, float(b["r"]), Color(ESPUMA, 0.85 * vive * k))
	# LAS ONDAS donde le han pegado: espuma que se abre desde el punto y se apaga.
	for o in _ondas:
		var u2: float = float(o["t"]) / T_ONDA
		var p2: Vector2 = _borde(float(o["a"]))
		var r2: float = lerpf(3.0, 16.0, 1.0 - (1.0 - u2) * (1.0 - u2))
		ProfundoAire._anillo_relleno(capa, p2, r2 * 0.4, r2 * 0.8, r2, Color(ESPUMA, 0.0), Color(ESPUMA, 0.9 * (1.0 - u2)),
			Color(AGUA_CLARA, 0.0), 20)
		BarridoAire.brillo(capa, p2, 6.0 * (1.0 - u2), Color(ESPUMA, 1.0 - u2))
	# EL DESTELLO al parar un estado: una estrella de espuma arriba.
	if blanco > 0.0:
		BarridoAire.destello(capa, c + Vector2(0.0, -R.y * 0.85), 14.0 * blanco + 4.0, Color(ESPUMA, blanco), _t)


# SE ROMPE: la burbuja se hincha y se deshace en un momento, las gotas salen volando desde su borde y caen, y en el
# suelo queda una salpicadura que se seca.
func _reventar(capa: Node2D) -> void:
	var c: Vector2 = _centro()
	var R: Vector2 = _radios()
	var pies := Vector2(c.x, _caja.end.y)
	var u: float = _rota / T_REVIENTA
	if capa == _detras:
		# La salpicadura en el suelo (achatada: el suelo va a 45 grados).
		var s: float = clampf(_rota / 0.25, 0.0, 1.0)
		var seca: float = clampf((_rota - 0.25) / (T_REVIENTA - 0.25), 0.0, 1.0)
		capa.draw_set_transform(pies, 0.0, Vector2(1.0, K * 0.6))
		BarridoAire.brillo(capa, Vector2.ZERO, R.x * (0.8 + 0.6 * s), Color(AGUA, 0.45 * (1.0 - seca)))
		BarridoAire.brillo(capa, Vector2.ZERO, R.x * (0.5 + 0.4 * s), Color(AGUA_CLARA, 0.35 * (1.0 - seca)))
		capa.draw_set_transform(Vector2.ZERO)
		return
	# La burbuja que se hincha y se deshace (los primeros 0,15 s).
	var hincha: float = clampf(_rota / 0.15, 0.0, 1.0)
	if hincha < 1.0:
		var col := Color(AGUA_CLARA, 0.55 * (1.0 - hincha))
		var col_0 := Color(col, 0.0)
		for i in LADOS:
			var a0: float = TAU * float(i) / float(LADOS)
			var a1: float = TAU * float(i + 1) / float(LADOS)
			var e: float = 1.0 + 0.25 * hincha
			capa.draw_primitive(PackedVector2Array([_borde(a0, e * 0.88), _borde(a0, e), _borde(a1, e)]),
				PackedColorArray([col_0, col, col]), PackedVector2Array())
			capa.draw_primitive(PackedVector2Array([_borde(a0, e * 0.88), _borde(a1, e), _borde(a1, e * 0.88)]),
				PackedColorArray([col_0, col, col_0]), PackedVector2Array())
		BarridoAire.destello(capa, c, R.x * 0.9 * (1.0 - hincha) + 6.0, Color(ESPUMA, 1.0 - hincha), 0.4)
	# LAS GOTAS: salen del borde hacia fuera, suben un poco y caen, cada una con su estela.
	for g in _gotas:
		var a: float = float(g["a"])
		var vida: float = clampf(u * float(g["v"]) * 1.3, 0.0, 1.0)
		if vida >= 1.0:
			continue
		var sale: Vector2 = _borde(a)
		var fuera := Vector2(cos(a) * R.x, sin(a) * R.y).normalized()
		var lejos: float = 26.0 * float(g["v"]) * vida
		var alto: float = (sin(PI * minf(vida * 1.2, 1.0)) * 14.0 * float(g["h"]) - vida * vida * 22.0) * K
		var p: Vector2 = sale + fuera * lejos - Vector2(0.0, alto)
		var vida_a: float = maxf(vida - 0.07, 0.0)
		var alto_a: float = (sin(PI * minf(vida_a * 1.2, 1.0)) * 14.0 * float(g["h"]) - vida_a * vida_a * 22.0) * K
		var p_a: Vector2 = sale + fuera * 26.0 * float(g["v"]) * vida_a - Vector2(0.0, alto_a)
		var al: float = 1.0 - vida * 0.7
		BarridoAire.cometa(capa, p_a, p, float(g["r"]), Color(AGUA_CLARA, 0.9 * al))
		BarridoAire.brillo(capa, p, float(g["r"]) * 0.6, Color(ESPUMA, al))
