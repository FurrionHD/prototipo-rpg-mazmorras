# ============================================================
#  arana_aire.gd  (class_name AranaAire)
#  LOS EFECTOS DE LAS ARAÑAS MUTANTES (03/11/2026, arana-mutante). Sin rayas: los rayos son cintas rellenas (grueso en
#  medio y afilado en las puntas) y las chispas, cometas. Cada una en SU paleta: la Tormentosa en azul y cian (NO el
#  amarillo del rayo de siempre, lo pidio el jefe) y la Tejedora en naranja de ascuas.
#    RAYOS     el climax y la Descarga: rayos a todos lados que saltan por el suelo, con destellos donde caen.
#    FOGONAZO  el climax y la Explosion: el fogonazo, un aro de fuego por el suelo y chispas que suben y caen.
#    CARGA     (se queda) lo cargada que esta: chispazos o ascuas alrededor del cuerpo, mas cuantas mas cargas, y los
#              puntos del contador encima.
# ============================================================
extends Node2D
class_name AranaAire

enum Modo { RAYOS, FOGONAZO, CARGA }

const Z_ENCIMA := Game.Z_ENCIMA_PERSONAJES + 80

const AZUL := Color(0.10, 0.26, 0.72)
const CIAN := Color(0.36, 0.80, 0.92)
const BLANCO := Color(0.92, 0.98, 1.0)
const NARANJA := Color(1.0, 0.42, 0.08)
const ASCUA := Color(1.0, 0.72, 0.28)
const CARBON := Color(0.15, 0.13, 0.14)

const T_RAYOS := 0.75
const T_FOGONAZO := 0.8
const T_CAMBIO := 0.07     # cada cuanto se redibujan los rayos: un rayo no se mueve, salta

# Los fotogramas de la evolucion donde llega el climax, a sus 10 por segundo (ver arana_mutantes_sdf.py).
const CLIMAX_TEJEDORA := 0.95
const CLIMAX_TORMENTOSA := 1.5

var modo: int = Modo.RAYOS
var nivel: int = 0
var tope: int = 4
var fuego: bool = false
var _t: float = 0.0
var _dur: float = 0.0
var _r: float = 60.0
var _rng := RandomNumberGenerator.new()
var _rayos: Array = []
var _chispas: Array = []
var _cambio: float = 0.0
var _caja: Rect2 = Rect2()
var _secando: float = -1.0


# ------------------------------------------------------------
#  CREARLOS
# ------------------------------------------------------------
static func rayos(padre: Node, c: Vector2, r: float, semilla: int) -> AranaAire:
	var e := _nuevo(Modo.RAYOS, semilla)
	e._dur = T_RAYOS
	e._r = r
	e.position = c
	e._montar(padre)
	return e


static func fogonazo(padre: Node, c: Vector2, r: float, semilla: int) -> AranaAire:
	var e := _nuevo(Modo.FOGONAZO, semilla)
	e._dur = T_FOGONAZO
	e._r = r
	e.position = c
	e._preparar_chispas()
	e._montar(padre)
	return e


# Lo que se queda pegado al cuerpo: lo sigue con seguir() y se va con secar().
static func pegado(padre: Node, caja: Rect2, fuego_: bool, semilla: int) -> AranaAire:
	var e := _nuevo(Modo.CARGA, semilla)
	e.fuego = fuego_
	e._caja = caja
	e._montar(padre)
	return e


# EL CLIMAX DE LA EVOLUCION (su peticion, 03/11): lo llama gesto_transformacion, asi que sale igual en el mapa y en el
# espejo. Se reconoce a cada una por lo que trae su hoja.
static func climax(nodo: Node2D, spr: AnimatedSprite2D) -> void:
	if not spr.sprite_frames.has_animation(&"descarga_0") and not spr.sprite_frames.has_animation(&"explosion_0"):
		return
	var es_rayo: bool = spr.sprite_frames.has_animation(&"descarga_0")
	var t := nodo.create_tween()
	t.tween_interval(CLIMAX_TORMENTOSA if es_rayo else CLIMAX_TEJEDORA)
	t.tween_callback(func() -> void:
		if not is_instance_valid(nodo):
			return
		if es_rayo:
			AranaAire.rayos(nodo, Vector2(0, -22), 85.0, randi())
		else:
			AranaAire.fogonazo(nodo, Vector2(0, -16), 60.0, randi()))


static func _nuevo(m: int, semilla: int) -> AranaAire:
	var e := AranaAire.new()
	e.modo = m
	e._rng.seed = semilla
	return e


func _montar(padre: Node) -> void:
	z_as_relative = false
	z_index = Z_ENCIMA
	padre.add_child(self)


func seguir(caja: Rect2) -> void:
	_caja = caja


func poner_nivel(n: int, t: int) -> void:
	nivel = n
	tope = t


func secar() -> void:
	queue_free()


# ------------------------------------------------------------
#  EL TIEMPO
# ------------------------------------------------------------
func _process(delta: float) -> void:
	_t += delta
	if modo != Modo.CARGA and _t >= _dur:
		queue_free()
		return
	if modo != Modo.FOGONAZO:
		_cambio -= delta
		if _cambio <= 0.0:
			_cambio = T_CAMBIO
			_rehacer_rayos()
	queue_redraw()


# UN RAYO: cinta quebrada desde 'a', que se tuerce a los lados y acaba en punta. Las ramas salen a mitad.
func _rayo(a: Vector2, dir: Vector2, largo: float, grueso: float, ramas: int) -> void:
	var pts := PackedVector2Array()
	var n: int = maxi(4, int(largo / 13.0))
	var lado: Vector2 = dir.orthogonal()
	var p: Vector2 = a
	pts.append(p)
	for i in n:
		p += dir * (largo / n) + lado * _rng.randf_range(-0.55, 0.55) * (largo / n)
		pts.append(p)
	_rayos.append({"pts": pts, "g": grueso})
	for j in ramas:
		var k: int = _rng.randi_range(1, pts.size() - 2)
		_rayo(pts[k], dir.rotated(_rng.randf_range(-1.0, 1.0)), largo * _rng.randf_range(0.3, 0.5), grueso * 0.55, 0)


func _rehacer_rayos() -> void:
	_rayos.clear()
	if modo == Modo.RAYOS:
		var n: int = 9
		for i in n:
			# A todos lados, y a ras de suelo aplastados: la camara mira a 45 grados.
			var a: float = TAU * (float(i) + _rng.randf_range(-0.3, 0.3)) / n
			var dir := Vector2(cos(a), sin(a) * 0.62).normalized()
			_rayo(dir * 6.0, dir, _r * _rng.randf_range(0.65, 1.15), _rng.randf_range(2.4, 3.6), 2)
	elif modo == Modo.CARGA and not fuego and nivel > 0 and _secando < 0.0:
		# Chispazos alrededor del cuerpo, mas cuantas mas cargas. No todos los fotogramas: si no, es un zumbido.
		var c: Vector2 = _caja.get_center()
		var r: float = maxf(_caja.size.x, _caja.size.y) * 0.5
		for i in nivel:
			if _rng.randf() < 0.55:
				var a2: float = _rng.randf() * TAU
				var o: Vector2 = c + Vector2(cos(a2), sin(a2)) * r * _rng.randf_range(0.4, 0.9)
				_rayo(o, Vector2(cos(a2), sin(a2)).rotated(_rng.randf_range(-0.8, 0.8)), r * _rng.randf_range(0.5, 0.9), 1.5, 0)


func _preparar_chispas() -> void:
	for i in 34:
		var a: float = _rng.randf() * TAU
		_chispas.append({"d": Vector2(cos(a), sin(a) * 0.62) * _rng.randf_range(35.0, 150.0), "up": _rng.randf_range(30.0, 150.0),
			"t": _rng.randf_range(0.4, 1.0), "g": _rng.randf_range(1.4, 2.8)})


# Para las hojas de efectos: se coloca en el instante 't' sin esperar al reloj.
func avanzar_a(t: float) -> void:
	_t = t
	if modo != Modo.FOGONAZO:
		_rehacer_rayos()
	queue_redraw()


# ------------------------------------------------------------
#  EL DIBUJO
# ------------------------------------------------------------
func _draw() -> void:
	match modo:
		Modo.RAYOS:
			_pinta_rayos(1.0 - _t / _dur)
		Modo.FOGONAZO:
			_pinta_fogonazo()
		Modo.CARGA:
			_pinta_carga()


func _pinta_rayos(a: float) -> void:
	var u: float = _t / _dur if _dur > 0.0 else 0.0
	if modo == Modo.RAYOS:
		var f: float = clampf(1.0 - u * 2.2, 0.0, 1.0)
		if f > 0.0:
			BarridoAire.destello(self, Vector2.ZERO, _r * 0.55 * (0.7 + f * 0.5), Color(CIAN, f), _t * 2.0)
	for ry in _rayos:
		var pts: PackedVector2Array = ry["pts"]
		var g: float = float(ry["g"])
		var anchos := PackedFloat32Array()
		var ultimo: float = float(pts.size() - 1)
		for i in pts.size():
			anchos.append(g * sin(PI * clampf((float(i) + 0.4) / (ultimo + 0.4), 0.0, 1.0)) + 0.3)
		TrentAire._cinta(self, pts, anchos, Color(AZUL, a * 0.95))
		var finos := PackedFloat32Array()
		for w in anchos:
			finos.append(w * 0.5)
		TrentAire._cinta(self, pts, finos, Color(CIAN, a))
		if g > 1.8:
			BarridoAire.destello(self, pts[pts.size() - 1], 5.0 + g, Color(BLANCO, a), 0.0)


func _pinta_fogonazo() -> void:
	var u: float = _t / _dur
	var f: float = clampf(1.0 - u * 3.0, 0.0, 1.0)
	if f > 0.0:
		BarridoAire.destello(self, Vector2.ZERO, _r * (0.9 + (1.0 - f) * 0.6), Color(ASCUA, f), 0.3)
		BarridoAire.destello(self, Vector2.ZERO, _r * 0.5, Color(1, 0.95, 0.8, f), 0.0)
	# El aro de fuego por el suelo: una banda rellena que se abre y se apaga.
	var r: float = _r * (0.4 + u * 1.0)
	var aro: float = clampf(1.0 - u * 1.6, 0.0, 1.0)
	if aro > 0.0:
		var pol := PackedVector2Array()
		var cols := PackedColorArray()
		for i in 25:
			var a: float = TAU * i / 24.0
			var d := Vector2(cos(a), sin(a) * 0.62)
			pol.append(d * r)
			pol.append(d * r * 0.72)
			cols.append(Color(NARANJA, aro))
			cols.append(Color(NARANJA, 0.0))
		for i in range(0, pol.size() - 2, 2):
			draw_primitive(PackedVector2Array([pol[i], pol[i + 1], pol[i + 2]]), PackedColorArray([cols[i], cols[i + 1], cols[i + 2]]), PackedVector2Array())
			draw_primitive(PackedVector2Array([pol[i + 1], pol[i + 3], pol[i + 2]]), PackedColorArray([cols[i + 1], cols[i + 3], cols[i + 2]]), PackedVector2Array())
	for c in _chispas:
		var k: float = _t / float(c["t"])
		if k >= 1.0:
			continue
		# suben y caen (parabola); la cometa, de donde estaba hace un momento a donde esta.
		var p: Vector2 = _chispa(c, k)
		var q: Vector2 = _chispa(c, maxf(k - 0.08, 0.0))
		BarridoAire.cometa(self, q, p, float(c["g"]), Color(ASCUA if k < 0.5 else NARANJA, 1.0 - k * k))


func _chispa(c: Dictionary, k: float) -> Vector2:
	var d: Vector2 = c["d"]
	return d * (1.0 - pow(1.0 - k, 2.0)) + Vector2(0, -float(c["up"]) * (4.0 * k * (1.0 - k)) * 0.5)


func _pinta_carga() -> void:
	if fuego:
		# Ascuas que suben del cuerpo, mas cuantas mas cargas.
		var c: Vector2 = _caja.get_center()
		var ancho: float = _caja.size.x * 0.4
		for i in nivel * 4:
			var fase: float = fmod(_t * 0.7 + float(i) * 0.37, 1.0)
			var x: float = sin(float(i) * 12.9898) * ancho + sin(_t * 2.0 + float(i)) * 3.0
			var p: Vector2 = c + Vector2(x, -fase * 34.0)
			BarridoAire.cometa(self, p + Vector2(0, 4), p, 1.8, Color(ASCUA, sin(fase * PI)))
	else:
		_pinta_rayos(0.95)
	# EL CONTADOR: un punto por carga, encima del cuerpo, encendidos los que lleva.
	var col: Color = NARANJA if fuego else CIAN
	var y: float = _caja.position.y - 7.0
	var x0: float = _caja.get_center().x - (float(tope) - 1.0) * 4.0
	for i in tope:
		var p2 := Vector2(x0 + float(i) * 8.0, y)
		draw_circle(p2, 3.1, Color(0, 0, 0, 0.65))
		draw_circle(p2, 2.3, col if i < nivel else Color(CARBON, 0.9))
