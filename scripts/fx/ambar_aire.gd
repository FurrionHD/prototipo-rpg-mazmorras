# ============================================================
#  ambar_aire.gd  (class_name AmbarAire)
#  LOS EFECTOS DE LOS BICHOS DEL AMBAR en el mapa (03/11/2026: los que suelta la costra del Tocon ambarino; ver la
#  memoria trent-mutante). La garrapata se engancha con el dibujo del Chupasimas (como la diseño el jefe); lo suyo:
#    BOLA      la Bola de caca del pelotero: rueda por su linea dando vueltas (con sus pajitas), deja un reguero que se
#              apaga y al final se deshace en pegotes.
#    PRINGUE   (se queda) el Pringado: pegotes marrones pegados al cuerpo, que gotean, con dos moscas dando vueltas.
#    PICOR     (se queda) el Picor del mosquito: ronchas rojas en el cuerpo que laten.
#    REVIENTA  la garrapata hinchada al morir: revienta en un circulo de salpicaduras rojo-ambar y gotas de veneno.
#  NADA DE LINEAS (efectos-sin-lineas): todo relleno. Coordenadas de MUNDO.
# ============================================================
extends Node2D
class_name AmbarAire

enum Modo { BOLA, PRINGUE, PICOR, REVIENTA }

const Z_ENCIMA := Game.Z_ENCIMA_PERSONAJES + 80

const CACA := Color(0.36, 0.24, 0.12)
const CACA_OSCURA := Color(0.18, 0.11, 0.05)
const CACA_CLARA := Color(0.55, 0.40, 0.22)
const PAJA := Color(0.85, 0.74, 0.40)
const MOSCA := Color(0.08, 0.08, 0.06)
const RONCHA := Color(0.85, 0.25, 0.22)
const RONCHA_CLARA := Color(1.0, 0.62, 0.55)
const SANGRE := Color(0.55, 0.12, 0.08)
const VENENO := Color(0.45, 0.75, 0.25)

const T_RUEDA := 0.6        # lo que tarda la bola en recorrer su linea
const T_DESHACE := 0.5
const T_SECA := 0.5
const T_REVIENTA := 0.9

var modo: int = Modo.BOLA
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _o: Vector2 = Vector2.ZERO        # la bola: de donde sale / el reventon: el centro
var _dir: Vector2 = Vector2.RIGHT
var _largo: float = 100.0
var _r: float = 30.0
var _caja: Rect2 = Rect2()
var _secando: float = -1.0
var _piezas: Array = []
var _suelo: Node2D = null
var _delante: Node2D = null
var _brillo: Node2D = null


# ------------------------------------------------------------
#  CREARLOS
# ------------------------------------------------------------
# LA BOLA, por la huella de la linea (SueloRoto.Tipo.AMBAR_BOLA). 'espera' = hasta la patada de su animacion.
static func bola(padre: Node, f: CombatFormas.Forma, semilla: int, espera: float) -> AmbarAire:
	if padre == null or f == null:
		return null
	var e := _nuevo(Modo.BOLA, semilla)
	e._dir = f.dir.normalized() if f.dir.length_squared() > 0.0001 else Vector2.RIGHT
	e._o = SueloRoto.origen_de(f)
	e._largo = maxf(f.largo, 10.0)
	e._r = maxf(f.ancho * 0.5, 5.0)
	e._t = -espera * e._ritmo
	e._preparar()
	e._montar(padre)
	return e


# Cuando le llega la bola a 'p' (segundos desde la patada).
static func retraso_bola(f: CombatFormas.Forma, p: Vector2) -> float:
	if f == null:
		return 0.0
	return clampf((p - f.origen).dot(f.dir.normalized()) / maxf(f.largo, 1.0), 0.0, 1.0) * T_RUEDA


# LO QUE SE QUEDA PEGADO (PRINGUE, PICOR): sobre 'caja' (su cuerpo), la sigue con seguir() y se va con secar().
static func pegado(padre: Node, m: int, caja: Rect2, semilla: int) -> AmbarAire:
	if padre == null:
		return null
	var e := _nuevo(m, semilla)
	e._caja = caja
	e._preparar()
	e._montar(padre)
	return e


# EL REVENTON de la garrapata: en 'centro' (sus pies), con radio 'r' (el de lo que salpica).
static func revienta(padre: Node, centro: Vector2, r: float, semilla: int, espera: float = 0.0) -> AmbarAire:
	if padre == null:
		return null
	var e := _nuevo(Modo.REVIENTA, semilla)
	e._o = centro
	e._r = maxf(r, 10.0)
	e._t = -maxf(espera, 0.0) * e._ritmo
	e._preparar()
	e._montar(padre)
	return e


static func _nuevo(m: int, semilla: int) -> AmbarAire:
	var e := AmbarAire.new()
	e.modo = m
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	return e


func seguir(caja: Rect2) -> void:
	_caja = caja


func secar() -> void:
	if _secando < 0.0:
		_secando = maxf(_t, 0.0)


func _montar(padre: Node) -> void:
	z_as_relative = false
	z_index = SueloRoto.Z_SUELO
	process_mode = Node.PROCESS_MODE_ALWAYS   # la pelea tactica pausa el arbol
	padre.add_child(self)
	_suelo = _capa(SueloRoto.Z_SUELO, false)
	_delante = _capa(Z_ENCIMA, false)
	_brillo = _capa(Z_ENCIMA + 1, true)


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
		Modo.BOLA:
			# las pajitas de la bola (su angulo en la bola) y los pegotes en que se deshace al final
			for i in 5:
				_piezas.append({"a": TAU * float(i) / 5.0 + _rng.randf_range(-0.3, 0.3), "l": _rng.randf_range(0.5, 0.9),
					"g": _rng.randf_range(-0.6, 0.6), "va": _rng.randf_range(0.0, TAU), "v": _rng.randf_range(6.0, 14.0),
					"tam": _rng.randf_range(1.8, 3.0)})
		Modo.PRINGUE:
			# los pegotes (en fracciones de su caja) y las dos moscas
			for i in 5:
				_piezas.append({"x": _rng.randf_range(-0.35, 0.35), "y": _rng.randf_range(0.2, 0.85),
					"tam": _rng.randf_range(2.4, 4.0), "gotea": _rng.randf_range(0.0, 1.0), "per": _rng.randf_range(1.2, 2.0)})
		Modo.PICOR:
			for i in 4:
				_piezas.append({"x": _rng.randf_range(-0.32, 0.32), "y": _rng.randf_range(0.25, 0.8),
					"tam": _rng.randf_range(1.6, 2.6), "fase": _rng.randf_range(0.0, TAU)})
		Modo.REVIENTA:
			for i in 16:
				_piezas.append({"a": TAU * (float(i) + _rng.randf_range(0.0, 0.7)) / 16.0,
					"v": _rng.randf_range(0.5, 1.0) * _r, "sube": _rng.randf_range(8.0, 20.0),
					"tam": _rng.randf_range(1.4, 3.0), "veneno": i % 3 == 0})


func duracion() -> float:
	match modo:
		Modo.BOLA: return T_RUEDA + T_DESHACE + 0.4
		Modo.REVIENTA: return T_REVIENTA
	return INF if _secando < 0.0 else _secando + T_SECA


func _process(delta: float) -> void:
	avanzar_a(_t + delta * _ritmo)
	if _t >= duracion():
		queue_free()


func avanzar_a(t: float) -> void:
	_t = t
	if _suelo != null:
		_suelo.queue_redraw()
		_delante.queue_redraw()
		_brillo.queue_redraw()


func _pintar(capa: Node2D) -> void:
	if _t < 0.0:
		return
	match modo:
		Modo.BOLA: _bola(capa)
		Modo.PRINGUE: _pringue(capa)
		Modo.PICOR: _picor(capa)
		Modo.REVIENTA: _revienta(capa)


# Lo grande que va lo pegado: a la medida del cuerpo (una rata no lleva los pegotes de un minotauro).
func _escala() -> float:
	return clampf(_caja.size.x / 40.0, 0.4, 1.4)


func _queda() -> float:
	return 1.0 if _secando < 0.0 else 1.0 - clampf((_t - _secando) / T_SECA, 0.0, 1.0)


# Un pegote: bola con su filo oscuro y su brillo.
static func _pegote(ci: CanvasItem, c: Vector2, tam: float, alfa: float) -> void:
	if alfa <= 0.01 or tam <= 0.2:
		return
	ci.draw_circle(c, tam + 0.8, Color(CACA_OSCURA, alfa))
	ci.draw_circle(c, tam, Color(CACA, alfa))
	ci.draw_circle(c + Vector2(-tam * 0.35, -tam * 0.35), tam * 0.3, Color(CACA_CLARA, 0.8 * alfa))


# ------------------------------------------------------------
#  LA BOLA
# ------------------------------------------------------------
# Rueda por su linea dando vueltas (las pajitas giran con ella) y deja un reguero en el suelo que se apaga; al final
# se deshace en pegotes que saltan un poco.
func _bola(capa: Node2D) -> void:
	var u: float = clampf(_t / T_RUEDA, 0.0, 1.0)
	var c: Vector2 = _o + _dir * _largo * u
	var rb: float = clampf(_r * 0.9, 5.0, 9.0)
	var apaga: float = 1.0 - clampf((_t - T_RUEDA - 0.2) / 0.5, 0.0, 1.0)
	if capa == _suelo:
		# el reguero, hasta donde va
		var pts := PackedVector2Array()
		var an := PackedFloat32Array()
		for i in 9:
			var s: float = float(i) / 8.0 * u
			pts.append(_o + _dir * _largo * s + Vector2(0.0, rb * 0.7))
			an.append(rb * 0.9 * (0.4 + 0.6 * s / maxf(u, 0.01)))
		TrentAire._cinta(capa, pts, an, Color(CACA_OSCURA, 0.35 * apaga))
		return
	if capa != _delante:
		return
	if _t < T_RUEDA:
		# la sombra y la bola, botando un pelin
		var bote: float = absf(sin(u * PI * 4.0)) * 2.0
		var giro: float = u * _largo / rb * signf(_dir.x if absf(_dir.x) > 0.1 else 1.0)
		var cb: Vector2 = c + Vector2(0.0, -rb - bote)
		capa.draw_circle(cb, rb + 1.0, CACA_OSCURA)
		capa.draw_circle(cb, rb, CACA)
		for p in _piezas:
			var a: float = float(p["a"]) + giro
			var d := Vector2(cos(a), sin(a))
			if d.y > 0.35:
				continue   # las de detras no se ven
			var q0: Vector2 = cb + d * rb * 0.35
			var q1: Vector2 = cb + d * rb * (0.35 + float(p["l"])) + d.orthogonal() * float(p["g"]) * 2.0
			TrentAire._cinta(capa, PackedVector2Array([q0, q1]), PackedFloat32Array([1.4, 0.5]), PAJA)
		capa.draw_circle(cb + Vector2(-rb * 0.35, -rb * 0.4), rb * 0.3, Color(CACA_CLARA, 0.8))
		return
	# SE DESHACE
	var k: float = clampf((_t - T_RUEDA) / T_DESHACE, 0.0, 1.0)
	for p in _piezas:
		var d2 := Vector2(cos(float(p["va"])), sin(float(p["va"])) * 0.6)
		var q: Vector2 = c + d2 * float(p["v"]) * k - Vector2(0.0, rb * (1.0 - k) + 10.0 * k * (1.0 - k) * 4.0)
		_pegote(capa, q, float(p["tam"]), apaga)


# ------------------------------------------------------------
#  LO QUE SE QUEDA
# ------------------------------------------------------------
# PRINGADO: pegotes pegados al cuerpo que gotean de vez en cuando, y dos moscas que le dan vueltas.
func _pringue(capa: Node2D) -> void:
	var queda: float = _queda()
	var sale: float = clampf(_t / 0.15, 0.0, 1.0)
	if capa != _delante:
		return
	var arriba := Vector2(_caja.get_center().x, _caja.position.y)
	for p in _piezas:
		var c: Vector2 = arriba + Vector2(float(p["x"]) * _caja.size.x, float(p["y"]) * _caja.size.y)
		_pegote(capa, c, float(p["tam"]) * sale * _escala(), queda)
		# la gota que se descuelga y cae
		var g: float = fposmod(_t / float(p["per"]) + float(p["gotea"]), 1.0)
		if g < 0.6:
			var largo: float = g / 0.6
			capa.draw_circle(c + Vector2(0.0, float(p["tam"]) + 3.0 * largo), 1.0 + 0.4 * largo, Color(CACA, queda))
	# LAS MOSCAS: dos puntitos negros con alas claras que giran sobre la cabeza
	for j in 2:
		var a: float = _t * (5.0 + float(j) * 1.7) + float(j) * PI
		var q: Vector2 = arriba + Vector2(cos(a) * _caja.size.x * 0.45, -6.0 + sin(a * 1.3) * 5.0)
		var aleteo: float = absf(sin(_t * 60.0 + float(j)))
		capa.draw_circle(q + Vector2(-1.2, -1.0), 1.1 * aleteo, Color(1, 1, 1, 0.5 * queda))
		capa.draw_circle(q + Vector2(1.2, -1.0), 1.1 * aleteo, Color(1, 1, 1, 0.5 * queda))
		capa.draw_circle(q, 1.2, Color(MOSCA, queda))


# PICOR: ronchas rojas que laten (se hinchan y deshinchan, cada una a su ritmo).
func _picor(capa: Node2D) -> void:
	var queda: float = _queda() * clampf(_t / 0.2, 0.0, 1.0)
	if capa == _suelo:
		return
	var arriba := Vector2(_caja.get_center().x, _caja.position.y)
	for p in _piezas:
		var c: Vector2 = arriba + Vector2(float(p["x"]) * _caja.size.x, float(p["y"]) * _caja.size.y)
		var late: float = 0.5 + 0.5 * sin(_t * 7.0 + float(p["fase"]))
		var tam: float = float(p["tam"]) * (0.85 + 0.3 * late) * _escala()
		if capa == _delante:
			capa.draw_circle(c, tam + 0.6, Color(SANGRE, 0.8 * queda))
			capa.draw_circle(c, tam, Color(RONCHA, queda))
			capa.draw_circle(c + Vector2(-tam * 0.3, -tam * 0.3), tam * 0.35, Color(RONCHA_CLARA, 0.9 * queda))
		else:
			capa.draw_circle(c, tam * 1.8, Color(RONCHA, 0.15 * late * queda))


# ------------------------------------------------------------
#  EL REVENTON
# ------------------------------------------------------------
# Un fogonazo rojo-ambar, las salpicaduras que salen en corona hasta el borde de su circulo (unas de sangre, otras de
# veneno verde) y la mancha en el suelo que se apaga.
func _revienta(capa: Node2D) -> void:
	var k: float = clampf(_t / 0.45, 0.0, 1.0)
	var apaga: float = 1.0 - clampf((_t - 0.45) / 0.45, 0.0, 1.0)
	if capa == _suelo:
		MagiaMayor._disco(capa, _o, _r * (0.4 + 0.6 * k), Color(SANGRE, 0.5 * apaga), Color(SANGRE, 0.0), 0.5)
		return
	if capa == _brillo:
		var f: float = clampf(1.0 - _t / 0.2, 0.0, 1.0)
		MagiaMayor._disco(capa, _o + Vector2(0.0, -4.0), 14.0 * (0.6 + 0.6 * (1.0 - f)), Color(TrentAire.AMBAR_CLARO, 0.6 * f),
			Color(TrentAire.AMBAR, 0.0))
		return
	for p in _piezas:
		var d := Vector2(cos(float(p["a"])), sin(float(p["a"])) * 0.6)
		var q: Vector2 = _o + d * float(p["v"]) * k - Vector2(0.0, float(p["sube"]) * 4.0 * k * (1.0 - k))
		var col: Color = VENENO if bool(p["veneno"]) else SANGRE
		var tam: float = float(p["tam"]) * (1.0 - 0.3 * k)
		capa.draw_circle(q, tam + 0.6, Color(col.darkened(0.4), apaga))
		capa.draw_circle(q, tam, Color(col, apaga))
