# ============================================================
#  jabali_aire.gd  (class_name JabaliAire)
#  LOS EFECTOS DE LOS MUTANTES DEL JABALI en el mapa (31/10/2026: el Colmillo de cristal y el Jabali ancestral; ver la
#  memoria jabali-mutante). El surco de esquirlas de la Cornada de cristal es el de la Embestida de cristal de la rata
#  (RataAire.SURCO_CRISTAL, SueloRoto.Tipo.RATA_SURCO_CRISTAL). Lo suyo, lo que eligio el jefe:
#    ESTALLIDO  al acabar la Cornada de cristal se le PARTEN los colmillos: una lluvia de esquirlas cian que sale de su
#               morro, cae alrededor de la cabeza, rebota un poco y se apaga.
#    ESPORAS    el Jabali ancestral, al recibir un golpe cuerpo a cuerpo: sus setas sueltan una BOCANADA de polvo
#               ocre-verdoso que se abre en circulo y se posa despacio, con MOTITAS claras que suben y flotan.
#    REFLEJO    las drusas del morro del ancestral le devuelven la magia que le entra por delante: un DESTELLO cian en
#               el morro y una BOLA de luz cian que vuela de vuelta hasta quien lanzo el hechizo.
#    QUEMA      le queman el musgo de la chepa: una LLAMARADA que le recorre el lomo de la cabeza a la grupa, HUMO
#               negro que sube un rato y CENIZA y brasas que caen por los flancos.
#  NADA DE LINEAS (efectos-sin-lineas): todo relleno. Coordenadas de MUNDO.
# ============================================================
extends Node2D
class_name JabaliAire

enum Modo { ESTALLIDO, ESPORAS, REFLEJO, QUEMA }

const Z_ENCIMA := Game.Z_ENCIMA_PERSONAJES + 80

const CRISTAL := Color(0.45, 0.88, 1.0)
const CRISTAL_CLARO := Color(0.85, 1.0, 1.0)
const CRISTAL_HONDO := Color(0.22, 0.55, 0.72)
const POLVO := Color(0.62, 0.58, 0.30)
const POLVO_VERDE := Color(0.44, 0.52, 0.24)
const MOTA := Color(0.92, 0.94, 0.78)
const LLAMA := Color(1.0, 0.55, 0.15)
const LLAMA_CLARA := Color(1.0, 0.88, 0.45)
const HUMO := Color(0.12, 0.11, 0.11)
const CENIZA := Color(0.35, 0.33, 0.31)
const BRASA := Color(1.0, 0.42, 0.12)

const T_ESTALLIDO := 1.0
const T_ESPORAS := 1.6
const T_DESTELLO := 0.18
const T_VUELO := 0.32       # lo que tarda la bola del reflejo en llegar
const T_QUEMA := 2.2
const T_LLAMARADA := 0.6    # lo que tarda la llamarada en recorrer el lomo

var modo: int = Modo.ESTALLIDO
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _c: Vector2 = Vector2.ZERO        # el morro (estallido, destello) / el centro (esporas) / la cruz (quema)
var _hasta: Vector2 = Vector2.ZERO    # a donde vuela la bola del reflejo
var _dir: Vector2 = Vector2.RIGHT     # hacia donde mira
var _r: float = 40.0
var _largo: float = 30.0              # (la quema) lo largo del lomo
var _piezas: Array = []
var _suelo: Node2D = null
var _delante: Node2D = null
var _brillo: Node2D = null


# ------------------------------------------------------------
#  CREARLOS
# ------------------------------------------------------------
# ESTALLIDO: 'morro' = donde estan los colmillos, 'dir' = hacia donde mira, 'suelo_y' = la Y de sus pies (donde caen).
static func estallido(padre: Node, morro: Vector2, dir: Vector2, suelo_y: float, semilla: int) -> JabaliAire:
	var e := _nuevo(Modo.ESTALLIDO, semilla)
	e._c = morro
	e._dir = _norm(dir)
	e._largo = maxf(suelo_y - morro.y, 4.0)
	e._preparar()
	e._montar(padre)
	return e


# ESPORAS: en 'centro' (sus pies), con radio 'r' (el de la nube que envenena).
static func esporas(padre: Node, centro: Vector2, r: float, semilla: int, espera: float = 0.0) -> JabaliAire:
	var e := _nuevo(Modo.ESPORAS, semilla)
	e._c = centro
	e._r = maxf(r, 10.0)
	e._t = -maxf(espera, 0.0) * e._ritmo
	e._preparar()
	e._montar(padre)
	return e


# REFLEJO: de 'morro' (las drusas) a 'hasta' (quien lanzo el hechizo).
static func reflejo(padre: Node, morro: Vector2, hasta: Vector2, semilla: int, espera: float = 0.0) -> JabaliAire:
	var e := _nuevo(Modo.REFLEJO, semilla)
	e._c = morro
	e._hasta = hasta
	e._dir = _norm(hasta - morro)
	e._t = -maxf(espera, 0.0) * e._ritmo
	e._preparar()
	e._montar(padre)
	return e


# QUEMA: 'cruz' = lo alto del lomo, 'dir' = hacia donde mira (la llamarada va de la cabeza a la grupa), 'largo' = el lomo.
static func quema(padre: Node, cruz: Vector2, dir: Vector2, largo: float, semilla: int) -> JabaliAire:
	var e := _nuevo(Modo.QUEMA, semilla)
	e._c = cruz
	e._dir = _norm(dir)
	e._largo = maxf(largo, 10.0)
	e._preparar()
	e._montar(padre)
	return e


static func _nuevo(m: int, semilla: int) -> JabaliAire:
	var e := JabaliAire.new()
	e.modo = m
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	return e


static func _norm(v: Vector2) -> Vector2:
	return v.normalized() if v.length_squared() > 0.0001 else Vector2.RIGHT


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
		Modo.ESTALLIDO:
			for i in 12:
				var lado: float = 1.0 if i % 2 == 0 else -1.0
				var a: float = _dir.angle() + lado * _rng.randf_range(0.3, 1.9)
				_piezas.append({"a": a, "v": _rng.randf_range(14.0, 30.0), "sube": _rng.randf_range(8.0, 18.0),
					"tam": _rng.randf_range(2.2, 4.0), "giro": _rng.randf_range(6.0, 14.0), "g0": _rng.randf_range(0.0, TAU),
					"vuelo": _rng.randf_range(0.28, 0.42)})
		Modo.ESPORAS:
			for i in 9:
				_piezas.append({"a": TAU * (float(i) + _rng.randf_range(0.0, 0.7)) / 9.0, "d": _rng.randf_range(0.45, 1.0),
					"tam": _rng.randf_range(0.7, 1.2), "fase": _rng.randf_range(0.0, TAU)})
			for i in 14:
				_piezas.append({"mota": true, "x": _rng.randf_range(-1.0, 1.0), "y": _rng.randf_range(-0.6, 0.6),
					"sube": _rng.randf_range(10.0, 26.0), "fase": _rng.randf_range(0.0, TAU), "t0": _rng.randf_range(0.0, 0.5)})
		Modo.QUEMA:
			for i in 10:
				_piezas.append({"u": _rng.randf_range(0.0, 1.0), "lado": -1.0 if i % 2 else 1.0,
					"t0": _rng.randf_range(0.3, 1.2), "v": _rng.randf_range(6.0, 12.0), "brasa": i % 3 == 0})


func duracion() -> float:
	match modo:
		Modo.ESTALLIDO: return T_ESTALLIDO
		Modo.ESPORAS: return T_ESPORAS
		Modo.REFLEJO: return T_DESTELLO + T_VUELO + 0.2
		Modo.QUEMA: return T_QUEMA
	return 1.0


func _process(delta: float) -> void:
	avanzar_a(_t + delta * _ritmo)
	if _t >= duracion():
		queue_free()


# Lo pone en el momento 't' (lo usa _process y las hojas, que van fotograma a fotograma).
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
		Modo.ESTALLIDO: _estallido(capa)
		Modo.ESPORAS: _esporas(capa)
		Modo.REFLEJO: _reflejo(capa)
		Modo.QUEMA: _quema(capa)


# UNA ESQUIRLA de cristal: un rombo alargado, la cara de la luz clara y la otra honda.
static func _esquirla(ci: CanvasItem, c: Vector2, tam: float, giro: float, alfa: float) -> void:
	if alfa <= 0.01:
		return
	var d := Vector2(cos(giro), sin(giro))
	var n := Vector2(-d.y, d.x)
	ci.draw_colored_polygon(PackedVector2Array([c + d * tam, c + n * tam * 0.35, c - d * tam * 0.6, c - n * tam * 0.35]),
		Color(CRISTAL, alfa))
	ci.draw_colored_polygon(PackedVector2Array([c + d * tam, c + n * tam * 0.35, c]), Color(CRISTAL_CLARO, alfa))
	ci.draw_colored_polygon(PackedVector2Array([c - d * tam * 0.6, c - n * tam * 0.35, c]), Color(CRISTAL_HONDO, alfa))


# EL ESTALLIDO: las esquirlas salen del morro en arco hacia los lados, caen al suelo (a la altura de sus pies), rebotan
# un poco y se apagan; un fogonazo cian en el morro al partirse.
func _estallido(capa: Node2D) -> void:
	if capa == _brillo:
		var f: float = clampf(1.0 - _t / 0.2, 0.0, 1.0)
		if f > 0.0:
			capa.draw_circle(_c, 6.0 * (0.6 + _t * 3.0), Color(CRISTAL_CLARO, 0.6 * f))
		return
	for p in _piezas:
		var vuelo: float = float(p["vuelo"])
		var u: float = clampf(_t / vuelo, 0.0, 1.0)
		var a: float = float(p["a"])
		var horiz := Vector2(cos(a), sin(a) * 0.55) * float(p["v"]) * (1.0 - pow(1.0 - u, 2.0))
		var cae: float = _largo * u * u
		var alto: float = float(p["sube"]) * sin(PI * u)
		var bote: float = 0.0
		if u >= 1.0:
			bote = float(p["sube"]) * 0.15 * sin(PI * clampf((_t - vuelo) / 0.15, 0.0, 1.0))
		var pos: Vector2 = _c + horiz + Vector2(0.0, cae - alto - bote)
		var alfa: float = 1.0 - clampf((_t - (T_ESTALLIDO - 0.35)) / 0.35, 0.0, 1.0)
		var giro: float = float(p["g0"]) + float(p["giro"]) * minf(_t, vuelo + 0.15)
		if capa == _suelo and u >= 1.0:
			capa.draw_circle(pos + Vector2(0, 1.0), float(p["tam"]) * 0.5, Color(0, 0, 0, 0.3 * alfa))
		elif capa == _delante:
			_esquirla(capa, pos, float(p["tam"]), giro, alfa)


# LAS ESPORAS: la bocanada (bultos de polvo que se abren desde el centro hasta el radio y se posan apagandose) y las
# motitas claras que suben flotando a la deriva.
func _esporas(capa: Node2D) -> void:
	var k: float = clampf(_t / T_ESPORAS, 0.0, 1.0)
	var abre: float = 1.0 - pow(1.0 - clampf(_t / 0.45, 0.0, 1.0), 3.0)
	for p in _piezas:
		if p.has("mota"):
			if capa != _brillo:
				continue
			var tt: float = _t - float(p["t0"])
			if tt < 0.0:
				continue
			var u: float = clampf(tt / (T_ESPORAS - float(p["t0"])), 0.0, 1.0)
			var pos: Vector2 = _c + Vector2(float(p["x"]) * _r * (0.3 + 0.7 * abre) + sin(_t * 3.0 + float(p["fase"])) * 3.0,
				float(p["y"]) * _r * 0.6 - float(p["sube"]) * u)
			capa.draw_circle(pos, 1.1, Color(MOTA, 0.8 * sin(PI * u)))
			continue
		if capa != _delante and capa != _suelo:
			continue
		var a: float = float(p["a"])
		var d: float = float(p["d"]) * _r * abre
		var pos2: Vector2 = _c + Vector2(cos(a), sin(a) * 0.6) * d - Vector2(0.0, 6.0 * (1.0 - k))
		var rr: float = _r * 0.17 * float(p["tam"]) * (0.5 + 0.5 * abre)
		var alfa: float = 0.38 * (1.0 - k) * (0.6 + 0.4 * sin(float(p["fase"]) + _t * 2.0))
		if capa == _suelo:
			# lo que se posa: una mancha tenue en el suelo
			capa.draw_circle(_c + Vector2(cos(a), sin(a) * 0.6) * d, rr * 0.8, Color(POLVO_VERDE, 0.25 * abre * (1.0 - k)))
		else:
			capa.draw_circle(pos2, rr, Color(POLVO, alfa))
			capa.draw_circle(pos2 + Vector2(-rr * 0.25, -rr * 0.2), rr * 0.6, Color(POLVO_VERDE, alfa * 0.8))


# EL REFLEJO: el destello cian en las drusas y la bola de luz que vuela hasta el lanzador (y revienta al llegar).
func _reflejo(capa: Node2D) -> void:
	if capa == _suelo:
		return
	var f: float = clampf(1.0 - _t / (T_DESTELLO * 1.5), 0.0, 1.0)
	if capa == _brillo and f > 0.0:
		capa.draw_circle(_c, 7.0 * (0.5 + _t / T_DESTELLO), Color(CRISTAL, 0.55 * f))
		capa.draw_circle(_c, 3.0, Color(CRISTAL_CLARO, 0.9 * f))
	var tv: float = _t - T_DESTELLO
	if tv < 0.0:
		return
	var u: float = clampf(tv / T_VUELO, 0.0, 1.0)
	var pos: Vector2 = _c.lerp(_hasta, u) - Vector2(0.0, 10.0 * sin(PI * u))
	if u < 1.0:
		if capa == _delante:
			# la estela: bolas cada vez mas pequeñas detras
			for j in 4:
				var uj: float = maxf(u - float(j + 1) * 0.06, 0.0)
				var pj: Vector2 = _c.lerp(_hasta, uj) - Vector2(0.0, 10.0 * sin(PI * uj))
				capa.draw_circle(pj, 3.0 - float(j) * 0.6, Color(CRISTAL, 0.5 - float(j) * 0.1))
			capa.draw_circle(pos, 3.6, Color(CRISTAL, 0.95))
		else:
			capa.draw_circle(pos, 6.0, Color(CRISTAL_CLARO, 0.45))
	else:
		# al llegar revienta en chispitas de luz que se abren (no un disco: se leia gris)
		var g: float = clampf((tv - T_VUELO) / 0.2, 0.0, 1.0)
		if capa == _delante:
			for j in 6:
				var aj: float = TAU * float(j) / 6.0 + 0.4
				_esquirla(capa, _hasta + Vector2(cos(aj), sin(aj)) * (3.0 + 7.0 * g), 2.0, aj, 1.0 - g)
		elif capa == _brillo:
			capa.draw_circle(_hasta, 3.0 + 3.0 * g, Color(CRISTAL, 0.5 * (1.0 - g)))


# LA QUEMA: la llamarada recorre el lomo (lenguas de fuego que nacen a su paso y se apagan), el humo negro que sube de
# lo quemado y la ceniza y las brasas que caen por los flancos.
func _quema(capa: Node2D) -> void:
	var cabeza: Vector2 = _c + Vector2(_dir.x, _dir.y * 0.6) * _largo * 0.5
	var grupa: Vector2 = _c - Vector2(_dir.x, _dir.y * 0.6) * _largo * 0.5
	var frente: float = clampf(_t / T_LLAMARADA, 0.0, 1.0)
	var n_l: int = 9
	for i in n_l:
		var u: float = float(i) / float(n_l - 1)
		if u > frente:
			continue
		var edad: float = _t - u * T_LLAMARADA
		var vida: float = clampf(1.0 - edad / 0.7, 0.0, 1.0)
		if vida <= 0.0:
			continue
		var base: Vector2 = cabeza.lerp(grupa, u)
		var alto: float = (5.0 + 4.0 * sin(_t * 18.0 + float(i) * 1.7)) * vida
		var ancho: float = 3.2 * vida + 1.0
		if capa == _delante:
			capa.draw_colored_polygon(PackedVector2Array([base + Vector2(-ancho, 0), base + Vector2(0, -alto * 1.6),
				base + Vector2(ancho, 0)]), Color(LLAMA, 0.9 * vida))
			capa.draw_colored_polygon(PackedVector2Array([base + Vector2(-ancho * 0.5, 0), base + Vector2(0, -alto),
				base + Vector2(ancho * 0.5, 0)]), Color(LLAMA_CLARA, 0.95 * vida))
		elif capa == _brillo:
			capa.draw_circle(base - Vector2(0, alto * 0.4), ancho * 2.0, Color(LLAMA, 0.3 * vida))
	# el humo: bocanadas que suben de lo ya quemado
	if capa == _delante:
		for j in 6:
			var tj: float = _t - 0.25 - float(j) * 0.22
			if tj < 0.0 or tj > 1.3:
				continue
			var uj: float = tj / 1.3
			var sitio: Vector2 = cabeza.lerp(grupa, fmod(float(j) * 0.37, 1.0))
			capa.draw_circle(sitio - Vector2(sin(float(j) + _t) * 3.0, 6.0 + 20.0 * uj), 2.0 + 4.0 * uj,
				Color(HUMO, 0.55 * (1.0 - uj)))
	# la ceniza y las brasas que caen por los flancos
	for p in _piezas:
		var tp: float = _t - float(p["t0"])
		if tp < 0.0 or tp > 0.9:
			continue
		var up: float = tp / 0.9
		var sale: Vector2 = cabeza.lerp(grupa, float(p["u"])) + Vector2(_dir.y, -_dir.x) * float(p["lado"]) * 5.0
		var pos: Vector2 = sale + Vector2(float(p["lado"]) * float(p["v"]) * up * 0.4, float(p["v"]) * up * 1.6)
		if bool(p["brasa"]):
			if capa == _brillo:
				capa.draw_circle(pos, 1.2, Color(BRASA, 0.9 * (1.0 - up)))
		elif capa == _delante:
			capa.draw_rect(Rect2(pos - Vector2(1, 1), Vector2(2, 2)), Color(CENIZA, 0.9 * (1.0 - up)))
