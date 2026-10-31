# ============================================================
#  rey_rata_aire.gd  (class_name ReyRataAire)
#  LOS EFECTOS DE LOS MUTANTES DEL REY RATA en el mapa (31/10/2026: el Rey de las cloacas y el Rey del desguace; ver la
#  memoria rey-rata-mutante). Lo que eligio el jefe:
#    AGUJERO   la LLAMADA: el suelo se raja junto al rey, revienta en un boquete del que salen sus ratas y se cierra.
#              Tres versiones para que elija (Version): GRIETA (las grietas y el boquete de los BROTES de la mazmorra,
#              wall_crack_fx tal cual, sobre el suelo), REJILLA (una tapa de cloaca que salta y se vuelve a cerrar) y
#              CHARCO (agua de cloaca que se abre y se seca).
#    CAMPANAZO el TAPAZO al tocar: un aro de metal que se abre desde la tapa como una onda de sonido, con chispas
#              naranjas. (Las estrellitas del aturdido ya las pone el estado: CombatFX, familia "control".)
#    CHATARRA  y del mismo golpe saltan tornillos, remaches y trocitos de oxido hacia donde empuja, caen al suelo, se
#              quedan un momento y se van.
#    CHISPAS   el FRENTE BLINDADO: le has pegado por delante y la chatarra se lo ha comido; chispas naranjas que saltan
#              de la tapa hacia quien pega y un brillo de metal en el borde.
#    FURIA     la FURIA DE REY (nivel 1-3, una por rata suya muerta): le brillan los ojos en rojo y le sale vaho por el
#              hocico, mas cuanto mas nivel. Sigue al sprite mientras dura.
#  NADA DE LINEAS (efectos-sin-lineas): todo relleno. Coordenadas de MUNDO.
# ============================================================
extends Node2D
class_name ReyRataAire

enum Modo { AGUJERO, CAMPANAZO, CHATARRA, CHISPAS, FURIA }
enum Version { GRIETA, REJILLA, CHARCO }

const Z_ENCIMA := Game.Z_ENCIMA_PERSONAJES + 80
const _CRACK := preload("res://scripts/world/wall_crack_fx.gd")

const HIERRO := Color(0.46, 0.47, 0.50)
const HIERRO_CLARO := Color(0.78, 0.80, 0.84)
const HIERRO_HONDO := Color(0.22, 0.23, 0.26)
const OXIDO := Color(0.55, 0.30, 0.13)
const OXIDO_CLARO := Color(0.75, 0.48, 0.24)
const CHISPA := Color(1.0, 0.62, 0.18)
const CHISPA_CLARA := Color(1.0, 0.92, 0.62)
const HUECO := Color(0.03, 0.03, 0.05)
const AGUA := Color(0.22, 0.25, 0.14)           # agua de cloaca: verde sucio, mas clara que el suelo para que se lea
const AGUA_CLARA := Color(0.52, 0.58, 0.34)
const AGUA_BORDE := Color(0.36, 0.30, 0.18)     # el cerco de lodo
const OJO_ROJO := Color(1.0, 0.16, 0.10)
const VAHO := Color(0.86, 0.84, 0.82)

# EL AGUJERO: se raja, se abre, se queda abierto mientras salen y se cierra (s).
const T_RAJA := 0.35
const T_ABRE := 0.2
const T_ABIERTO := 0.75
const T_CIERRA := 0.55
const LADO_AGUJERO := 16.0     # la celda del boquete (con 24 las grietas se comian media sala: miden 1,7 celdas)
const R_AGUJERO := 11.0        # el de la rejilla y el charco
const T_CAMPANA := 0.38
const T_CHATARRA := 1.3        # vuelo + lo que se queda en el suelo
const T_CHISPAS := 0.32
const T_VAHO := 0.9            # lo que tarda cada bocanada en irse

var modo: int = Modo.CAMPANAZO
var version: int = Version.GRIETA
var nivel: int = 1
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _c: Vector2 = Vector2.ZERO        # donde toca / el centro del agujero
var _dir: Vector2 = Vector2.RIGHT     # hacia donde empuja / hacia donde mira el rey / hacia quien pega
var _r: float = 12.0
var _piezas: Array = []
var _suelo: Node2D = null
var _delante: Node2D = null
var _brillo: Node2D = null
var _grietas: Node2D = null
var _roto: bool = false
var _sigue: Node2D = null             # (la furia) el sprite al que va pegada
var _bocanada: float = 0.0


# ------------------------------------------------------------
#  CREARLOS
# ------------------------------------------------------------
# EL AGUJERO de la Llamada en 'centro'. Dura agujero_dur(); las ratas salen en cuanto se abre (t_abierto()).
static func agujero(padre: Node, centro: Vector2, v: int, semilla: int) -> ReyRataAire:
	var e := _nuevo(padre, Modo.AGUJERO, semilla)
	e.version = v
	e._c = centro
	e._preparar()
	e._montar(padre)
	return e


# Lo de sobre un cuerpo: el CAMPANAZO y las CHISPAS ('c' = donde toca, 'dir' = hacia donde empuja / hacia quien pega,
# 'r' = el tamaño del cuerpo) y la CHATARRA que salta del golpe.
static func golpe(padre: Node, m: int, c: Vector2, dir: Vector2, r: float, semilla: int, espera: float = 0.0) -> ReyRataAire:
	var e := _nuevo(padre, m, semilla)
	e._c = c
	e._dir = dir.normalized() if dir.length_squared() > 0.0001 else Vector2.RIGHT
	e._r = maxf(r, 6.0)
	e._t = -maxf(espera, 0.0) * e._ritmo
	e._preparar()
	e._montar(padre)
	return e


# LA FURIA sobre 'spr' (el sprite del rey): nivel 1-3, 'dir' = hacia donde mira. Se queda hasta que la quiten
# (parar()) o se cambie con poner_nivel().
static func furia(padre: Node, spr: Node2D, lvl: int, dir: Vector2, semilla: int) -> ReyRataAire:
	var e := _nuevo(padre, Modo.FURIA, semilla)
	e._sigue = spr
	e.nivel = clampi(lvl, 1, 3)
	e._dir = dir.normalized() if dir.length_squared() > 0.0001 else Vector2.DOWN
	e._r = 12.0
	e._montar(padre)
	return e


static func _nuevo(_padre: Node, m: int, semilla: int) -> ReyRataAire:
	var e := ReyRataAire.new()
	e.modo = m
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	return e


static func agujero_dur() -> float:
	return T_RAJA + T_ABRE + T_ABIERTO + T_CIERRA


static func t_abierto() -> float:
	return T_RAJA + T_ABRE


func poner_nivel(lvl: int, dir: Vector2) -> void:
	nivel = clampi(lvl, 1, 3)
	if dir.length_squared() > 0.0001:
		_dir = dir.normalized()


func parar() -> void:
	queue_free()


func _montar(padre: Node) -> void:
	z_as_relative = false
	z_index = SueloRoto.Z_SUELO
	process_mode = Node.PROCESS_MODE_ALWAYS   # la pelea tactica pausa el arbol
	padre.add_child(self)
	_suelo = _capa(SueloRoto.Z_SUELO, false)
	_delante = _capa(Z_ENCIMA, false)
	_brillo = _capa(Z_ENCIMA + 1, true)
	if modo == Modo.AGUJERO and version == Version.GRIETA:
		# LAS DE LOS BROTES, tal cual: un foco en el centro, sin zona (todo el suelo vale) y el boquete en su celda.
		_grietas = Node2D.new()
		_grietas.set_script(_CRACK)
		_grietas.z_as_relative = false
		_grietas.z_index = SueloRoto.Z_SUELO
		add_child(_grietas)
		_grietas.preparar([_c], [], LADO_AGUJERO, _rng.seed % 100003)
		_grietas.avance(0.0)
	avanzar_a(_t)


func _capa(z: int, aditiva: bool) -> Node2D:
	var c := Node2D.new()
	c.z_as_relative = false
	c.z_index = z
	if aditiva:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		c.material = mat
	c.draw.connect(_pintar.bind(c))
	add_child(c)
	return c


func _preparar() -> void:
	match modo:
		Modo.AGUJERO:
			# (la rejilla) los barrotes; (el charco) las gotas que salpican al salir
			for i in 8:
				_piezas.append({"a": TAU * (float(i) + _rng.randf_range(0.0, 0.6)) / 8.0, "v": _rng.randf_range(10.0, 18.0),
					"sube": _rng.randf_range(6.0, 12.0), "tam": _rng.randf_range(1.0, 1.8)})
		Modo.CAMPANAZO, Modo.CHISPAS:
			var n: int = 9 if modo == Modo.CAMPANAZO else 7
			var abre: float = PI if modo == Modo.CAMPANAZO else 1.1
			for i in n:
				_piezas.append({"a": _dir.angle() + _rng.randf_range(-abre, abre) * 0.5, "v": _rng.randf_range(30.0, 60.0),
					"sube": _rng.randf_range(4.0, 12.0), "tam": _rng.randf_range(1.0, 1.7), "vida": _rng.randf_range(0.6, 1.0)})
		Modo.CHATARRA:
			# 0 = tornillo, 1 = remache, 2 = oxido
			for i in 7:
				_piezas.append({"tipo": i % 3, "a": _dir.angle() + _rng.randf_range(-0.9, 0.9), "d": _rng.randf_range(10.0, 26.0),
					"sube": _rng.randf_range(8.0, 16.0), "giro": _rng.randf_range(-12.0, 12.0), "g0": _rng.randf_range(0.0, TAU),
					"t0": _rng.randf_range(0.0, 0.06), "vuelo": _rng.randf_range(0.28, 0.4)})


func duracion() -> float:
	match modo:
		Modo.AGUJERO: return agujero_dur()
		Modo.CAMPANAZO: return T_CAMPANA
		Modo.CHATARRA: return T_CHATARRA
		Modo.CHISPAS: return T_CHISPAS
	return INF   # la furia se queda hasta que la paran


func _process(delta: float) -> void:
	avanzar_a(_t + delta * _ritmo)
	if _t >= duracion():
		queue_free()


# Lo pone TODO en el momento 't' (lo usa _process y las hojas, que van fotograma a fotograma).
func avanzar_a(t: float) -> void:
	_t = t
	if modo == Modo.FURIA and _sigue != null and is_instance_valid(_sigue):
		_c = _sigue.global_position
	if _grietas != null:
		_mover_grietas()
	if _suelo != null:
		_suelo.queue_redraw()
		_delante.queue_redraw()
		_brillo.queue_redraw()


# LAS GRIETAS DE LOS BROTES con los tiempos del agujero: se rajan, revienta el boquete y se abre (como la pared:
# wall_birth_fx), se queda abierto y al final las grietas se curan y el hueco se cierra de fuera hacia dentro.
func _mover_grietas() -> void:
	if _t < 0.0:
		return
	if _t < T_RAJA:
		_grietas.avance(_t / T_RAJA)
		return
	if not _roto:
		_roto = true
		_grietas.avance(1.0)
		var cel := Vector2i(int(floor(_c.x / LADO_AGUJERO)), int(floor(_c.y / LADO_AGUJERO)))
		_grietas.romper([cel], [true], _rng.seed % 100003)
		_grietas.cerrar(0.0)
	var t2: float = _t - T_RAJA
	if t2 < T_ABRE:
		_grietas.cerrar(sqrt(t2 / T_ABRE))
	elif t2 < T_ABRE + T_ABIERTO:
		_grietas.cerrar(1.0)
	else:
		var p: float = clampf((t2 - T_ABRE - T_ABIERTO) / T_CIERRA, 0.0, 1.0)
		_grietas.avance(1.0 - p)
		_grietas.cerrar(1.0 - p * p)


func _pintar(capa: Node2D) -> void:
	if _t < 0.0:
		return
	match modo:
		Modo.AGUJERO:
			if version == Version.REJILLA: _rejilla(capa)
			elif version == Version.CHARCO: _charco(capa)
		Modo.CAMPANAZO: _campanazo(capa)
		Modo.CHATARRA: _chatarra(capa)
		Modo.CHISPAS: _chispas(capa)
		Modo.FURIA: _furia(capa)


# ------------------------------------------------------------
#  PIEZAS
# ------------------------------------------------------------
# UN ARO RELLENO entre r0 y r1, del color 'col' en el filo de fuera que se apaga hacia dentro.
static func _aro(ci: CanvasItem, c: Vector2, r0: float, r1: float, col: Color, alfa: float, aplasta: float = 1.0) -> void:
	if alfa <= 0.01 or r1 <= r0 + 0.2:
		return
	# A TROZOS (un cuadrilatero por tramo): de una pieza, el contorno de fuera y el de dentro se tocan en la costura y
	# a veces no se triangula.
	r0 = maxf(r0, 0.0)
	var n: int = maxi(16, int(r1 * 1.2))
	var fuera := Color(col, alfa)
	var dentro := Color(col, 0.0)
	var cols := PackedColorArray([fuera, fuera, dentro, dentro])
	for i in n:
		var a0: float = TAU * float(i) / float(n)
		var a1: float = TAU * float(i + 1) / float(n)
		var d0 := Vector2(cos(a0), sin(a0) * aplasta)
		var d1 := Vector2(cos(a1), sin(a1) * aplasta)
		ci.draw_polygon(PackedVector2Array([c + d0 * r1, c + d1 * r1, c + d1 * r0, c + d0 * r0]), cols)


# UNA CHISPA: un rombo estirado hacia donde vuela, el centro claro.
static func _chispa(ci: CanvasItem, p: Vector2, hacia: Vector2, largo: float, alfa: float) -> void:
	if alfa <= 0.01:
		return
	var d: Vector2 = hacia.normalized() if hacia.length_squared() > 0.0001 else Vector2.RIGHT
	var n := Vector2(-d.y, d.x)
	var a: float = maxf(0.8, largo * 0.28)
	ci.draw_colored_polygon(PackedVector2Array([p + d * largo, p + n * a, p - d * largo * 0.6, p - n * a]), Color(CHISPA, alfa))
	ci.draw_colored_polygon(PackedVector2Array([p + d * largo * 0.6, p + n * a * 0.45, p - d * largo * 0.2, p - n * a * 0.45]),
		Color(CHISPA_CLARA, alfa))


# EL CAMPANAZO: el aro de metal que se abre desde donde toca (aplastado por el suelo a 45 grados) con un fogonazo en el
# centro y las chispas que saltan.
func _campanazo(capa: Node2D) -> void:
	var k: float = clampf(_t / T_CAMPANA, 0.0, 1.0)
	if capa == _delante:
		var r1: float = lerpf(_r * 0.3, _r * 1.9, 1.0 - pow(1.0 - k, 2.0))
		_aro(capa, _c, r1 - 3.0 - 2.0 * (1.0 - k), r1, HIERRO_CLARO, 0.9 * (1.0 - k), 0.7)
		_aro(capa, _c, r1 * 0.55 - 2.0, r1 * 0.55, HIERRO, 0.6 * (1.0 - k), 0.7)
		for p in _piezas:
			var tt: float = k / float(p["vida"])
			if tt >= 1.0:
				continue
			var a: float = float(p["a"])
			var v := Vector2(cos(a), sin(a))
			var pos: Vector2 = _c + v * float(p["v"]) * T_CAMPANA * tt - Vector2(0, float(p["sube"]) * sin(PI * tt))
			_chispa(capa, pos, v, 3.0 * float(p["tam"]), 1.0 - tt)
	elif capa == _brillo:
		var f: float = clampf(1.0 - k * 3.0, 0.0, 1.0)
		if f > 0.0:
			capa.draw_circle(_c, _r * 0.5 * (0.6 + k), Color(CHISPA_CLARA, 0.55 * f))
			capa.draw_circle(_c, _r * 0.25, Color(1, 1, 1, 0.7 * f))


# LA CHATARRA: cada pieza vuela en arco hacia donde empuja, cae, rebota un poco y se queda en el suelo; luego se apaga.
func _chatarra(capa: Node2D) -> void:
	if capa == _brillo:
		return
	for p in _piezas:
		var tt: float = _t - float(p["t0"])
		if tt < 0.0:
			continue
		var vuelo: float = float(p["vuelo"])
		var u: float = clampf(tt / vuelo, 0.0, 1.0)
		var a: float = float(p["a"])
		var suelo_p: Vector2 = _c + Vector2(cos(a), sin(a)) * float(p["d"]) * (1.0 - pow(1.0 - u, 2.0))
		var alto: float = float(p["sube"]) * sin(PI * u)
		if u >= 1.0:
			# un botecito al caer
			var b: float = clampf((tt - vuelo) / 0.14, 0.0, 1.0)
			alto = float(p["sube"]) * 0.18 * sin(PI * b)
		var giro: float = float(p["g0"]) + float(p["giro"]) * minf(tt, vuelo + 0.14)
		var alfa: float = 1.0 - clampf((tt - (T_CHATARRA - 0.35)) / 0.35, 0.0, 1.0)
		if capa == _suelo and u >= 1.0:
			# su sombrita en el suelo cuando ya ha caido
			capa.draw_circle(suelo_p + Vector2(0, 0.8), 1.6, Color(0, 0, 0, 0.35 * alfa))
		if capa == _delante:
			_pieza(capa, suelo_p - Vector2(0, alto), int(p["tipo"]), giro, alfa)


func _pieza(ci: CanvasItem, p: Vector2, tipo: int, giro: float, alfa: float) -> void:
	if alfa <= 0.01:
		return
	var d := Vector2(cos(giro), sin(giro))
	var n := Vector2(-d.y, d.x)
	match tipo:
		0:   # TORNILLO: la caña y la cabeza
			ci.draw_colored_polygon(PackedVector2Array([p - d * 2.2 - n * 0.6, p + d * 1.4 - n * 0.6, p + d * 1.4 + n * 0.6,
				p - d * 2.2 + n * 0.6]), Color(HIERRO, alfa))
			ci.draw_colored_polygon(PackedVector2Array([p + d * 1.2 - n * 1.4, p + d * 2.4 - n * 1.4, p + d * 2.4 + n * 1.4,
				p + d * 1.2 + n * 1.4]), Color(HIERRO_CLARO, alfa))
		1:   # REMACHE: una cabeza redonda con su brillo
			ci.draw_circle(p, 1.6, Color(HIERRO_HONDO, alfa))
			ci.draw_circle(p - Vector2(0.4, 0.4), 0.8, Color(HIERRO_CLARO, alfa))
		_:   # OXIDO: una lasca irregular
			ci.draw_colored_polygon(PackedVector2Array([p - d * 2.0, p + n * 1.3, p + d * 1.6 - n * 0.4, p - n * 1.5]),
				Color(OXIDO, alfa))
			ci.draw_colored_polygon(PackedVector2Array([p - d * 0.8, p + n * 0.6, p + d * 0.6]), Color(OXIDO_CLARO, alfa))


# LAS CHISPAS DEL FRENTE BLINDADO: un brillo de metal en media luna por el lado de quien pega y chispas que saltan
# hacia el.
func _chispas(capa: Node2D) -> void:
	var k: float = clampf(_t / T_CHISPAS, 0.0, 1.0)
	if capa == _delante:
		BestiaAire._media_luna(capa, _c, _dir.angle() - 0.9, _dir.angle() + 0.9, _r * 0.9, 3.0, HIERRO_CLARO, HIERRO,
			0.85 * (1.0 - k), true)
		for p in _piezas:
			var tt: float = k / float(p["vida"])
			if tt >= 1.0:
				continue
			var a: float = float(p["a"])
			var v := Vector2(cos(a), sin(a))
			var pos: Vector2 = _c + _dir * _r * 0.8 + v * float(p["v"]) * T_CHISPAS * tt - Vector2(0, float(p["sube"]) * sin(PI * tt))
			_chispa(capa, pos, v, 2.6 * float(p["tam"]), 1.0 - tt)
	elif capa == _brillo:
		var f: float = clampf(1.0 - k * 2.5, 0.0, 1.0)
		if f > 0.0:
			capa.draw_circle(_c + _dir * _r * 0.85, 3.5, Color(CHISPA_CLARA, 0.7 * f))


# LA REJILLA: un hueco negro con la tapa de hierro encima; la tapa salta de canto hacia un lado, salen, y vuelve a caer
# y el hueco se borra.
func _rejilla(capa: Node2D) -> void:
	var abre: float = clampf((_t - T_RAJA * 0.5) / (T_ABRE + T_RAJA * 0.5), 0.0, 1.0)
	var cierra: float = clampf((_t - T_RAJA - T_ABRE - T_ABIERTO) / T_CIERRA, 0.0, 1.0)
	var aparece: float = clampf(_t / (T_RAJA * 0.5), 0.0, 1.0)
	var se_va: float = clampf((cierra - 0.6) / 0.4, 0.0, 1.0)
	var alfa: float = aparece * (1.0 - se_va)
	var fuera: float = abre * (1.0 - clampf(cierra / 0.6, 0.0, 1.0))   # lo apartada que esta la tapa
	if capa == _suelo:
		capa.draw_circle(_c, R_AGUJERO + 1.5, Color(HIERRO_HONDO, alfa))
		capa.draw_circle(_c, R_AGUJERO, Color(HUECO, alfa))
		capa.draw_circle(_c + Vector2(0, R_AGUJERO * 0.45), R_AGUJERO * 0.55, Color(0.0, 0.0, 0.0, alfa * 0.6))
	elif capa == _delante:
		var salto: float = sin(PI * clampf(abre * 1.4, 0.0, 1.0)) * 6.0 * (1.0 - fuera * 0.5)
		var pos: Vector2 = _c + Vector2(R_AGUJERO * 1.7, R_AGUJERO * 0.5) * fuera - Vector2(0, salto)
		var plano: float = lerpf(1.0, 0.45, fuera)   # de canto mientras vuela y apoyada a un lado
		_tapa(capa, pos, R_AGUJERO + 1.0, plano, alfa)


func _tapa(ci: CanvasItem, c: Vector2, r: float, plano: float, alfa: float) -> void:
	if alfa <= 0.01:
		return
	var n: int = 20
	var pts := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * plano))
	ci.draw_colored_polygon(pts, Color(HIERRO, alfa))
	# los barrotes: franjas oscuras (rellenas) entre las de hierro
	for b in range(-2, 3):
		var x: float = float(b) * r * 0.36
		var h: float = sqrt(maxf(r * r - x * x, 0.0)) * 0.85 * plano
		ci.draw_rect(Rect2(c + Vector2(x - 1.0, -h), Vector2(2.0, h * 2.0)), Color(HUECO, alfa * 0.9))
	ci.draw_circle(c - Vector2(r * 0.3, r * 0.3 * plano), r * 0.25, Color(HIERRO_CLARO, alfa * 0.5))


# EL CHARCO: una mancha de agua de cloaca que se abre, burbujea mientras salen (salpicones) y se seca encogiendo.
func _charco(capa: Node2D) -> void:
	var abre: float = clampf(_t / (T_RAJA + T_ABRE), 0.0, 1.0)
	var cierra: float = clampf((_t - T_RAJA - T_ABRE - T_ABIERTO) / T_CIERRA, 0.0, 1.0)
	var r: float = R_AGUJERO * (1.0 - pow(1.0 - abre, 2.0)) * (1.0 - cierra * 0.85)
	var alfa: float = 1.0 - clampf((cierra - 0.5) / 0.5, 0.0, 1.0)
	if capa == _suelo:
		if r > 0.5:
			var n: int = 18
			var pts := PackedVector2Array()
			for i in n:
				var a: float = TAU * float(i) / float(n)
				var w: float = 1.0 + 0.12 * sin(a * 3.0 + 1.3) + 0.08 * sin(a * 5.0)
				pts.append(_c + Vector2(cos(a), sin(a) * 0.8) * r * w)
			var cerco := PackedVector2Array()
			for q in pts:
				cerco.append(_c + (q - _c) * 1.15)
			capa.draw_colored_polygon(cerco, Color(AGUA_BORDE, 0.9 * alfa))
			capa.draw_colored_polygon(pts, Color(AGUA, 0.95 * alfa))
			capa.draw_circle(_c - Vector2(r * 0.3, r * 0.25), r * 0.35, Color(AGUA_CLARA, 0.35 * alfa))
			# las ondas: aros rellenos que se abren mientras esta abierto
			var t_ab: float = _t - T_RAJA - T_ABRE
			if t_ab > 0.0 and cierra <= 0.0:
				for j in 2:
					var k: float = fmod(t_ab * 1.6 + float(j) * 0.5, 1.0)
					_aro(capa, _c, r * k * 0.9 - 1.2, r * k * 0.9, AGUA_CLARA, 0.5 * (1.0 - k), 0.8)
	elif capa == _delante:
		# los salpicones al abrirse (cuando salen)
		var ts: float = _t - T_RAJA - T_ABRE * 0.5
		if ts > 0.0 and ts < 0.45:
			var u: float = ts / 0.45
			for p in _piezas:
				var a2: float = float(p["a"])
				var pos: Vector2 = _c + Vector2(cos(a2), sin(a2) * 0.8) * float(p["v"]) * u - Vector2(0, float(p["sube"]) * sin(PI * u))
				capa.draw_circle(pos, float(p["tam"]), Color(AGUA_CLARA, 0.9 * (1.0 - u)))


# LA FURIA: dos ojos rojos que laten (mas fuerte cuanto mas nivel) y bocanadas de vaho que salen del hocico y suben.
# La cabeza esta hacia donde mira, por delante del centro del cuerpo y un poco arriba (el sprite se ve a 45 grados).
func _furia(capa: Node2D) -> void:
	var cab: Vector2 = _c + Vector2(_dir.x, _dir.y * 0.7) * _r * 0.85 - Vector2(0, 7.0)
	var hocico: Vector2 = cab + Vector2(_dir.x, _dir.y * 0.7) * 5.0 + Vector2(0, 1.5)
	var n := Vector2(-_dir.y, _dir.x * 0.7).normalized()
	var late: float = 0.75 + 0.25 * sin(_t * (5.0 + float(nivel)))
	if capa == _brillo:
		for s in [-1.0, 1.0]:
			var ojo: Vector2 = cab + n * 2.2 * s
			capa.draw_circle(ojo, 1.4 + 0.5 * float(nivel), Color(OJO_ROJO, 0.12 * late * float(nivel)))
			capa.draw_circle(ojo, 0.9, Color(OJO_ROJO, 0.95 * late))
	elif capa == _delante:
		# una bocanada cada poco (mas seguidas con mas nivel), cada una a su tiempo
		var cada: float = 0.75 - 0.15 * float(nivel)
		var k0: int = int(floor(_t / cada))
		for k in range(k0 - 3, k0 + 1):
			if k < 0:
				continue
			var tt: float = _t - float(k) * cada
			if tt < 0.0 or tt > T_VAHO:
				continue
			var u: float = tt / T_VAHO
			var lado: float = 1.0 if k % 2 == 0 else -1.0
			for s in 2:
				var pos: Vector2 = hocico + Vector2(_dir.x, _dir.y * 0.7) * 6.0 * u + n * lado * (1.5 + 2.0 * u) * (0.5 + float(s)) \
					- Vector2(0, 7.0 * u)
				var rr: float = (1.2 + 2.6 * u) * (0.8 + 0.2 * float(nivel))
				capa.draw_circle(pos, rr, Color(VAHO, 0.5 * (1.0 - u) * (0.6 + 0.2 * float(nivel))))
