# ============================================================
#  insecto_aire.gd
#  LOS EFECTOS DE LOS INSECTOIDES en el mapa (29/09/2026): araña, escarabajo, ciempies y segadora, uno a uno y con
#  su visto bueno (ver la memoria insectoides-tactico). Aparte de BestiaAire para no engordarlo mas; usa sus piezas
#  estaticas (_tira, _poligono, _bola). Empieza por la ARAÑA:
#  SOBRE UN CUERPO (CombatTactico._on_dibujo_mapa, CombatFX.Estilo.INSECTO_*):
#    QUELICEROS  el basico: dos colmillos curvos (ganchos de quitina con la punta clara) que se clavan de golpe y se
#                retiran. A escala de la araña y orientados segun de donde viene el golpe, cada uno con su variacion.
#    PONZONA     el Mordisco ponzoñoso: los mismos colmillos, un pelin mas grandes, con la punta mojada de veneno.
#    VENENO      (lo pone CombatTactico._on_impacto, SOLO SI ENTRA) gotitas verdes que saltan de donde muerde y una
#                mancha verde que se apaga.
#    HEBRAS      a los que pilla la Telaraña al caer: unas hebras pegadas del suelo a sus piernas, un momento.
#  POR EL SUELO (SueloRoto.Tipo.INSECTO_*, ver Suelo):
#    TELARANA    el ovillo de seda que sale de la araña, vuela en parabola abriendose y revienta en hebras al caer
#                (la red que se queda la pinta RED, aparte).
#  SE QUEDA:
#    RED         la telaraña tendida en el suelo los turnos de la araña: radios y espiral, rocio; cada turno mas rota
#                y deshilachada, y encoge (como el charco de savia, CombatTactico._charco_visible).
#  LAS HEBRAS NO SON LINEAS (lo aprobo el usuario, 29/09): cada una es un hilo relleno que se afila, mas grueso junto a
#  los nudos, con un halo suave detras. Coordenadas de MUNDO.
# ============================================================
extends Node2D
class_name InsectoAire

enum Modo { TELARANA, QUELICEROS, PONZONA, VENENO, HEBRAS, RED }
# Los del suelo, en el orden de SueloRoto.Tipo.INSECTO_*: no reordenar (el Modo si se puede).
enum Suelo { TELARANA }
const _MODO_DE_SUELO := [Modo.TELARANA]

const K := 0.7071
const Z_ENCIMA := Game.Z_PERSONAJES + 80
const T_CLAVADO := 0.2            # lo que se quedan los colmillos clavados antes de salir
const T_IRSE := 0.16
const T_TELA_CAE := 0.4           # lo que vuela el ovillo hasta el suelo
const T_SECA := 0.5               # lo que tarda en irse la red al secarse
const T_VENENO := 0.8
const T_HEBRAS := 1.4
const QUITINA := Color(0.12, 0.08, 0.17)
const QUITINA_MEDIA := Color(0.3, 0.22, 0.42)
const QUITINA_CLARA := Color(0.6, 0.5, 0.78)
const PUNTA := Color(0.95, 0.9, 0.82)
const SEDA := Color(0.95, 0.95, 0.99)
const SEDA_SOMBRA := Color(0.22, 0.2, 0.28)
const VENENO := Color(0.46, 0.84, 0.22)
const VENENO_OSCURO := Color(0.12, 0.34, 0.08)
const VENENO_CLARO := Color(0.82, 1.0, 0.56)

var modo: int = Modo.QUELICEROS
var forma: CombatFormas.Forma = null
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _hasta: Vector2 = Vector2.ZERO
var _eje: Vector2 = Vector2.RIGHT     # hacia donde muerde (de quien muerde a quien recibe), ya variado
var _lado: Vector2 = Vector2.DOWN     # a lo ancho de la boca: los dos colmillos, uno a cada lado
var _tam: float = 8.0
var _viaje: float = 0.14
var _ancho: float = 14.0
var _largo: float = 26.0
var _o: Vector2 = Vector2.ZERO
var _r: float = 25.0
var _dir: Vector2 = Vector2.RIGHT
var _lejos: float = 60.0              # TELARANA: lo lejos que esta la araña (f.ancho, ver CombatTactico.desde_quien_lanza)
var queda: float = 1.0                # RED: lo que le queda (1 = recien tendida); se rompe y encoge con ello
var _secando: float = -1.0            # RED: desde cuando se esta yendo (-1 = sigue)
var _piezas: Array = []               # gotas (VENENO), hebras (HEBRAS), pelusas (TELARANA)
var _radios: Array = []               # RED: {a, lob, vida}
var _anillos: Array = []              # RED: {f, vidas: [..]} (un tramo por hueco entre radios)
var _rocio: Array = []                # RED: {i, j, fase}
var _suelo: Node2D = null
var _delante: Node2D = null
var _brillo: Node2D = null


# ------------------------------------------------------------
#  EN EL SUELO
# ------------------------------------------------------------
static func area(padre: Node, f: CombatFormas.Forma, s: int, semilla: int, espera: float) -> Node2D:
	if padre == null or f == null or s < 0 or s >= _MODO_DE_SUELO.size():
		return null
	var e := InsectoAire.new()
	e.modo = int(_MODO_DE_SUELO[s])
	e.forma = f
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	e._t = -espera * e._ritmo
	e.z_as_relative = false
	e.z_index = SueloRoto.Z_SUELO
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._o = f.centro
	e._r = maxf(f.radio, 8.0)
	e._dir = f.dir.normalized() if f.dir.length_squared() > 0.0001 else Vector2.RIGHT
	e._lejos = f.ancho if f.ancho > 8.0 else 60.0
	# Las pelusas de seda que saltan al reventar el ovillo.
	for i in 10:
		e._piezas.append({"a": TAU * (float(i) + e._rng.randf_range(0.0, 0.8)) / 10.0,
			"v": e._rng.randf_range(0.35, 0.8) * e._r, "sube": e._rng.randf_range(4.0, 10.0),
			"tam": e._rng.randf_range(1.0, 1.8)})
	e._delante = e._capa(Z_ENCIMA, false)
	return e


static func retraso(_s: int, f: CombatFormas.Forma, _p: Vector2) -> float:
	return T_TELA_CAE if f != null else 0.0


static func t_salir(_s: int) -> float:
	return T_TELA_CAE


# ------------------------------------------------------------
#  SOBRE UN CUERPO
# ------------------------------------------------------------
# 'desde' = de donde viene (quien muerde), 'caja' = el cuerpo que lo recibe, 'espera' = lo que falta para el golpe
# (los colmillos se clavan justo en el), 'boca' = el ancho del dibujo de quien muerde (van a SU escala).
static func sobre_cuerpo(padre: Node, m: int, desde: Vector2, caja: Rect2, semilla: int, espera: float,
		ritmo: float, boca: float = -1.0) -> InsectoAire:
	if padre == null:
		return null
	var e := InsectoAire.new()
	e.modo = m
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	e._ancho = maxf(caja.size.x, 8.0)
	e._largo = maxf(caja.size.y, 10.0)
	e._hasta = caja.get_center() + Vector2(e._rng.randf_range(-0.18, 0.18) * caja.size.x,
		e._rng.randf_range(-0.2, 0.1) * caja.size.y)
	var eje: Vector2 = (e._hasta - desde).normalized() if e._hasta.distance_squared_to(desde) > 1.0 else Vector2.RIGHT
	match m:
		Modo.QUELICEROS, Modo.PONZONA:
			e._viaje = clampf(espera, 0.08, 0.2)
			e._t = -e._viaje
			# Cada mordisco con su variacion: la boca un poco girada sobre la linea del golpe.
			e._eje = eje.rotated(e._rng.randf_range(-0.28, 0.28))
			e._lado = e._eje.orthogonal()
			var de_quien: float = boca if boca > 0.0 else e._ancho
			e._tam = maxf(de_quien * 0.28, 4.0) * (1.12 if m == Modo.PONZONA else 1.0)
		Modo.VENENO:
			e._t = -maxf(espera, 0.0)
			e._eje = eje
			e._tam = maxf(e._ancho * 0.35, 4.0)
			# Las gotas salen hacia el lado contrario de quien muerde, abiertas en abanico.
			for i in 8:
				e._piezas.append({"d": eje.rotated(e._rng.randf_range(-1.3, 1.3)), "v": e._rng.randf_range(10.0, 20.0),
					"sube": e._rng.randf_range(5.0, 11.0), "tam": e._rng.randf_range(0.9, 1.6)})
		Modo.HEBRAS:
			e._t = -maxf(espera, 0.0)
			e._hasta = Vector2(caja.get_center().x, caja.end.y)   # los pies
			for i in 4:
				var lado: float = -1.0 if i % 2 == 0 else 1.0
				e._piezas.append({"x": lado * e._rng.randf_range(0.55, 1.1), "y": e._rng.randf_range(-0.6, 0.8),
					"h": e._rng.randf_range(0.14, 0.32), "px": lado * e._rng.randf_range(0.05, 0.3),
					"t0": float(i) * 0.03})
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._delante = e._capa(Z_ENCIMA, false)
	e._brillo = e._capa(Z_ENCIMA + 1, true)
	return e


# LA RED QUE SE QUEDA (la Telaraña): no se va sola; se va cuando CombatTactico la seca (secar()). 'espera' = lo que
# falta para que caiga el ovillo que la tiende.
static func red(padre: Node, f: CombatFormas.Forma, semilla: int, espera: float) -> InsectoAire:
	if padre == null or f == null:
		return null
	var e := InsectoAire.new()
	e.modo = Modo.RED
	e.forma = f
	e._rng.seed = hash(semilla)
	e._t = -maxf(espera, 0.0)
	e.z_as_relative = false
	e.z_index = SueloRoto.Z_SUELO
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._o = f.centro
	e._r = maxf(f.radio, 6.0)
	# Los RADIOS, cada uno con su largo; y LOS ANILLOS de la espiral, un tramo por hueco. Cada pieza con su 'vida': al
	# secarse se van rompiendo las de vida mas alta primero.
	var n: int = 10
	var a0: float = e._rng.randf_range(0.0, TAU)
	for i in n:
		e._radios.append({"a": a0 + TAU * (float(i) + e._rng.randf_range(-0.2, 0.2)) / float(n),
			"lob": e._rng.randf_range(0.88, 1.04), "vida": e._rng.randf_range(0.0, 0.9)})
	# Se rompe POR SECTORES (una red rasgada, no tramos sueltos al azar): la vida de cada tramo tira de la de su radio.
	for fr in [0.22, 0.38, 0.53, 0.67, 0.8, 0.92]:
		var vidas: Array = []
		for i in n:
			vidas.append(0.55 * float(e._radios[i]["vida"]) + 0.35 * e._rng.randf() + 0.1 * fr)
		e._anillos.append({"f": fr, "vidas": vidas})
	for k in 6:
		e._rocio.append({"i": e._rng.randi_range(0, n - 1), "j": e._rng.randi_range(1, e._anillos.size() - 1),
			"fase": e._rng.randf_range(0.0, TAU)})
	e._suelo = e._capa(SueloRoto.Z_SUELO, false)
	return e


# La red se seca: se va en T_SECA y fuera.
func secar() -> void:
	if _secando < 0.0:
		_secando = maxf(_t, 0.0)


func duracion() -> float:
	match modo:
		Modo.TELARANA: return T_TELA_CAE + 0.45
		Modo.VENENO: return T_VENENO
		Modo.HEBRAS: return T_HEBRAS
		Modo.RED: return INF if _secando < 0.0 else _secando + T_SECA
	return T_CLAVADO + T_IRSE


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
		Modo.TELARANA: _telarana(capa)
		Modo.QUELICEROS, Modo.PONZONA: _queliceros(capa)
		Modo.VENENO: _veneno(capa)
		Modo.HEBRAS: _hebras(capa)
		Modo.RED: _red(capa)


# ------------------------------------------------------------
#  LOS QUELICEROS
# ------------------------------------------------------------
# Dos colmillos, uno a cada lado de la linea del mordisco, que llegan ABIERTOS desde el lado de la araña y se clavan
# cerrandose hacia dentro justo en el golpe (destello pequeño). Se quedan un momento y salen hacia atras apagandose.
func _queliceros(capa: Node2D) -> void:
	var abre: float
	var clava: float
	var alfa: float
	if _t < 0.0:
		var u: float = clampf(1.0 + _t / _viaje, 0.0, 1.0)
		abre = 1.0 - u * u
		clava = u * u
		alfa = clampf(u * 3.0, 0.0, 1.0)
	else:
		var kr: float = smoothstep(T_CLAVADO, T_CLAVADO + T_IRSE, _t)
		abre = 0.25 * kr
		clava = 1.0 - 0.7 * kr
		alfa = 1.0 - kr
		# EL REBOTE al clavarse: empuja un pelin mas y vuelve.
		if _t < 0.08:
			clava += 0.12 * sin(_t / 0.08 * PI)
	if capa == _brillo:
		if _t >= 0.0 and _t < 0.12:
			BarridoAire.destello(capa, _hasta, _tam * 0.75, Color(0.92, 0.86, 1.0, 0.8 * (1.0 - _t / 0.12)), _eje.angle())
		return
	if capa != _delante or alfa <= 0.01:
		return
	# EL DE ATRAS PRIMERO (el de arriba en pantalla), para que el de delante lo tape.
	var lados: Array = [-1.0, 1.0]
	if (_lado * -1.0).y > _lado.y:
		lados = [1.0, -1.0]
	for s in lados:
		var base: Vector2 = _hasta - _eje * _tam * (1.3 - 0.35 * clava) + _lado * s * _tam * (0.42 + 0.3 * abre)
		var punta: Vector2 = _hasta + _eje * _tam * lerpf(-0.45, 0.12, clava) + _lado * s * _tam * (0.05 + 0.5 * abre)
		# Se comba hacia FUERA y vuelve a entrar en la punta: un gancho, no un cuerno recto.
		var ctrl: Vector2 = base + _eje * _tam * 0.8 + _lado * s * _tam * (0.38 + 0.2 * abre)
		_gancho(capa, base, ctrl, punta, _tam * 0.22, alfa, modo == Modo.PONZONA)
	# LO QUE DEJAN al salir: los dos agujeritos.
	if _t >= 0.0:
		for s2 in [-1.0, 1.0]:
			var p: Vector2 = _hasta + _eje * _tam * 0.1 + _lado * s2 * _tam * 0.06
			BestiaAire._bola(capa, p, maxf(1.2, _tam * 0.14), Color(VENENO_OSCURO if modo == Modo.PONZONA else QUITINA,
				0.85 * alfa))


# UN COLMILLO de 'base' a 'punta' por la curva de 'ctrl' (bezier): gordo en la base y afilado en la punta, con su filo
# oscuro detras, una veta clara por un lado y la punta de hueso. Con 'mojado', una gota de veneno colgando de ella.
func _gancho(ci: CanvasItem, base: Vector2, ctrl: Vector2, punta: Vector2, g: float, alfa: float, mojado: bool) -> void:
	if alfa <= 0.01 or base.distance_to(punta) < 1.0:
		return
	var izq := PackedVector2Array()
	var der := PackedVector2Array()
	var bi := PackedVector2Array()
	var bd := PackedVector2Array()
	var vi := PackedVector2Array()
	var vd := PackedVector2Array()
	var pasos: int = 10
	for i in pasos + 1:
		var s: float = float(i) / float(pasos)
		var p: Vector2 = base.lerp(ctrl, s).lerp(ctrl.lerp(punta, s), s)
		var tg: Vector2 = (ctrl - base) * (1.0 - s) + (punta - ctrl) * s
		var n: Vector2 = tg.normalized().orthogonal() if tg.length_squared() > 0.0001 else Vector2.RIGHT
		var w: float = g * pow(1.0 - s, 0.85) + 0.3
		izq.append(p - n * w)
		der.append(p + n * w)
		bi.append(p - n * (w + 0.8))
		bd.append(p + n * (w + 0.8))
		vi.append(p - n * w * 0.05)
		vd.append(p + n * w * 0.5)
	BestiaAire._tira(ci, bi, bd, Color(QUITINA, alfa))
	BestiaAire._tira(ci, izq, der, Color(QUITINA_MEDIA, alfa))
	BestiaAire._tira(ci, vi.slice(0, 8), vd.slice(0, 8), Color(QUITINA_CLARA, 0.8 * alfa))
	# LA PUNTA de hueso: el ultimo tramo, mas claro.
	BestiaAire._tira(ci, izq.slice(7), der.slice(7), Color(VENENO_CLARO if mojado else PUNTA, alfa))
	if mojado:
		var gota: Vector2 = punta + Vector2(0.0, 1.2 + 0.6 * sin(_t * 30.0))
		ci.draw_circle(gota, maxf(1.0, g * 0.5) + 0.5, Color(VENENO_OSCURO, alfa))
		ci.draw_circle(gota, maxf(1.0, g * 0.5), Color(VENENO, alfa))


# ------------------------------------------------------------
#  EL VENENO QUE ENTRA
# ------------------------------------------------------------
# Donde se han clavado: una mancha verde que se abre y se apaga, gotitas que saltan hacia fuera y caen, y un hilo que
# escurre hacia abajo.
func _veneno(capa: Node2D) -> void:
	if _t < 0.0 or capa != _delante:
		return
	var apaga: float = 1.0 - smoothstep(T_VENENO * 0.5, T_VENENO, _t)
	var crece: float = clampf(_t / 0.1, 0.0, 1.0)
	BestiaAire._bola(capa, _hasta, _tam * lerpf(0.6, 1.4, crece), Color(VENENO, 0.8 * apaga))
	BestiaAire._bola(capa, _hasta, _tam * 0.6 * crece, Color(VENENO_OSCURO, 0.7 * apaga))
	BestiaAire._bola(capa, _hasta + Vector2(-_tam * 0.2, -_tam * 0.25), _tam * 0.3 * crece, Color(VENENO_CLARO, 0.6 * apaga))
	var escurre: float = clampf((_t - 0.08) / 0.5, 0.0, 1.0)
	if escurre > 0.0:
		BarridoAire.cometa(capa, _hasta, _hasta + Vector2(0.0, 2.0 + _tam * 0.9 * escurre), maxf(1.0, _tam * 0.18),
			Color(VENENO, 0.85 * apaga))
	var kv: float = clampf(_t / 0.5, 0.0, 1.0)
	if kv >= 1.0:
		return
	for g in _piezas:
		var d: Vector2 = g["d"]
		var p: Vector2 = _hasta + d * float(g["v"]) * kv - Vector2(0.0, float(g["sube"]) * 4.0 * kv * (1.0 - kv) * K) \
			+ Vector2(0.0, 6.0 * kv * kv)
		var tam: float = float(g["tam"])
		capa.draw_circle(p, tam + 0.5, Color(VENENO_OSCURO, 1.0 - kv * kv))
		capa.draw_circle(p, tam, Color(VENENO, 1.0 - kv * kv))


# ------------------------------------------------------------
#  LAS HEBRAS en las piernas de los que pilla la red al caer
# ------------------------------------------------------------
func _hebras(capa: Node2D) -> void:
	if _t < 0.0 or capa != _delante:
		return
	var apaga: float = 1.0 - smoothstep(T_HEBRAS * 0.6, T_HEBRAS, _t)
	for h in _piezas:
		var sube: float = clampf((_t - float(h["t0"])) / 0.1, 0.0, 1.0)
		if sube <= 0.0:
			continue
		var suelo: Vector2 = _hasta + Vector2(float(h["x"]) * _ancho, 2.0 + float(h["y"]) * 3.0)
		var pierna: Vector2 = _hasta + Vector2(float(h["px"]) * _ancho, -float(h["h"]) * _largo * sube)
		# Cuelga un poco: el control, por debajo de la recta.
		var ctrl: Vector2 = suelo.lerp(pierna, 0.5) + Vector2(0.0, 2.5)
		hilo(capa, suelo, ctrl, pierna, 0.7, apaga, false)
		BestiaAire._bola(capa, suelo, 1.8, Color(SEDA, 0.6 * apaga))


# UN HILO DE SEDA de 'a' a 'b' por la curva de 'ctrl': relleno, mas grueso junto a los nudos (las puntas) y fino en
# medio, con un halo suave detras. Con 'sombra', su sombra en el suelo (la red tendida). Publica: la usa la hoja.
static func hilo(ci: CanvasItem, a: Vector2, ctrl: Vector2, b: Vector2, g: float, alfa: float, sombra: bool) -> void:
	if alfa <= 0.01 or a.distance_squared_to(b) < 0.25:
		return
	var n: int = maxi(3, int(a.distance_to(b) / 5.0))
	var c_i := PackedVector2Array()
	var c_d := PackedVector2Array()
	var h_i := PackedVector2Array()
	var h_d := PackedVector2Array()
	var s_i := PackedVector2Array()
	var s_d := PackedVector2Array()
	for i in n + 1:
		var s: float = float(i) / float(n)
		var p: Vector2 = a.lerp(ctrl, s).lerp(ctrl.lerp(b, s), s)
		var tg: Vector2 = (ctrl - a) * (1.0 - s) + (b - ctrl) * s
		var nn: Vector2 = tg.normalized().orthogonal() if tg.length_squared() > 0.0001 else Vector2.UP
		var w: float = g * (0.55 + 0.45 * absf(2.0 * s - 1.0))
		c_i.append(p - nn * w * 0.5)
		c_d.append(p + nn * w * 0.5)
		h_i.append(p - nn * w * 1.4)
		h_d.append(p + nn * w * 1.4)
		s_i.append(p + Vector2(0.6, 1.3) - nn * w * 0.6)
		s_d.append(p + Vector2(0.6, 1.3) + nn * w * 0.6)
	if sombra:
		BestiaAire._tira(ci, s_i, s_d, Color(SEDA_SOMBRA, 0.35 * alfa))
	BestiaAire._tira(ci, h_i, h_d, Color(SEDA, 0.2 * alfa))
	BestiaAire._tira(ci, c_i, c_d, Color(SEDA, 0.95 * alfa))


# ------------------------------------------------------------
#  LA TELARAÑA POR EL AIRE
# ------------------------------------------------------------
# El ovillo sale de la araña (de su abdomen, un palmo por encima del suelo), vuela en parabola dejando un hilo detras y
# se va abriendo en hebras segun cae; al caer revienta en pelusas de seda. La red tendida es RED, otro nodo.
func _telarana(capa: Node2D) -> void:
	if _t < 0.0 or capa != _delante:
		return
	var desde: Vector2 = _o - _dir * _lejos + Vector2(0.0, -12.0)
	if _t < T_TELA_CAE:
		var k: float = _t / T_TELA_CAE
		var p: Vector2 = _vuelo(desde, k)
		var antes: Vector2 = _vuelo(desde, maxf(k - 0.35, 0.0))
		BarridoAire.cometa(capa, antes, p, 1.4, Color(SEDA, 0.55))
		var r: float = lerpf(3.6, 5.5, k)
		BestiaAire._bola(capa, p, r * 2.4, Color(SEDA, 0.25))
		capa.draw_circle(p, r + 0.6, Color(SEDA_SOMBRA, 0.6))
		capa.draw_circle(p, r, SEDA)
		# SE VA ABRIENDO: hebras que salen del ovillo en la segunda mitad del vuelo.
		var abre: float = clampf((k - 0.5) / 0.5, 0.0, 1.0)
		if abre > 0.0:
			for i in 6:
				var a: float = TAU * float(i) / 6.0 + _t * 4.0
				var fin: Vector2 = p + Vector2(cos(a), sin(a) * K) * (r + _r * 0.5 * abre)
				hilo(capa, p, p.lerp(fin, 0.5) + Vector2(0.0, 1.5), fin, 0.7, abre, false)
		return
	# AL CAER: pelusas de seda que saltan y un soplo blanco en el centro.
	var kc: float = clampf((_t - T_TELA_CAE) / 0.35, 0.0, 1.0)
	BestiaAire._bola(capa, _o, _r * 0.5 * (0.6 + kc), Color(SEDA, 0.35 * (1.0 - kc)))
	for g in _piezas:
		var d := Vector2(cos(float(g["a"])), sin(float(g["a"])))
		var p2: Vector2 = _o + d * float(g["v"]) * kc - Vector2(0.0, float(g["sube"]) * 4.0 * kc * (1.0 - kc) * K)
		BestiaAire._bola(capa, p2, float(g["tam"]) * 1.6, Color(SEDA, 0.8 * (1.0 - kc * kc)))


func _vuelo(desde: Vector2, k: float) -> Vector2:
	return desde.lerp(_o, k) - Vector2(0.0, 30.0 * sin(PI * k))


# ------------------------------------------------------------
#  LA RED TENDIDA
# ------------------------------------------------------------
# Radios desde el centro y la espiral en anillos, cada tramo un poco combado hacia dentro. Se tiende de golpe al caer
# (crece con un pelin de mas), tiene rocio que brilla, y segun le queda se rompe (faltan tramos, los radios rotos
# cuelgan cortos) y encoge; al secarse se apaga.
func _red(capa: Node2D) -> void:
	if _t < 0.0 or capa != _suelo or forma == null:
		return
	var entra: float = clampf(_t / 0.14, 0.0, 1.0)
	var sale: float = 1.0 if _secando < 0.0 else 1.0 - clampf((_t - _secando) / T_SECA, 0.0, 1.0)
	var alfa: float = entra * sale * lerpf(0.75, 1.0, queda)
	if alfa <= 0.01:
		return
	var sobra: float = 1.0 + 0.12 * sin(PI * entra)
	var r: float = BestiaAire.radio_charco(forma, queda) * lerpf(0.35, 1.0, entra) * sobra * lerpf(0.85, 1.0, sale)
	# Lo que sigue entero: al principio todo; a dos tercios se rasga un sector; con un tercio, mas de la mitad sigue; al
	# secarse, cada vez menos.
	var entero: float = (0.45 + 0.55 * queda) * lerpf(0.4, 1.0, sale)
	var n: int = _radios.size()
	var puntas: Array = []
	for i in n:
		var rd: Dictionary = _radios[i]
		puntas.append(Vector2(cos(float(rd["a"])), sin(float(rd["a"]))) * r * float(rd["lob"]))
	# LOS RADIOS (rotos: solo el primer trozo, colgando).
	for i in n:
		var fin: Vector2 = puntas[i]
		if float(_radios[i]["vida"]) > entero:
			fin *= 0.35
		hilo(capa, _o, _o + fin * 0.5, _o + fin, 0.75, alfa, true)
	# LA ESPIRAL: un tramo entre cada par de radios, en cada anillo.
	for an in _anillos:
		var fr: float = float(an["f"])
		for i in n:
			if float(an["vidas"][i]) > entero:
				continue
			var j: int = (i + 1) % n
			if (float(_radios[i]["vida"]) > entero or float(_radios[j]["vida"]) > entero) and fr > 0.35:
				continue   # un radio roto ya no sujeta la espiral de mas afuera
			var a: Vector2 = _o + (puntas[i] as Vector2) * fr
			var b: Vector2 = _o + (puntas[j] as Vector2) * fr
			var ctrl: Vector2 = a.lerp(b, 0.5).lerp(_o, 0.06)
			hilo(capa, a, ctrl, b, 0.6, alfa * 0.9, true)
	# EL CENTRO, mas tupido.
	BestiaAire._bola(capa, _o, maxf(2.5, r * 0.14), Color(SEDA, 0.75 * alfa))
	# EL ROCIO: gotitas en algunos nudos que brillan cada una a su ritmo.
	for d in _rocio:
		var i2: int = int(d["i"])
		var an2: Dictionary = _anillos[int(d["j"])]
		if float(an2["vidas"][i2]) > entero or float(_radios[i2]["vida"]) > entero:
			continue   # sin la hebra donde estaba, no hay gota
		var p: Vector2 = _o + (puntas[i2] as Vector2) * float(an2["f"])
		var brilla: float = 0.55 + 0.45 * sin(_t * 2.6 + float(d["fase"]))
		capa.draw_circle(p, 1.1, Color(0.75, 0.85, 0.95, alfa))
		BestiaAire._bola(capa, p, 2.6, Color(1.0, 1.0, 1.0, 0.45 * alfa * brilla))
