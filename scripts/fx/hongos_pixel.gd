# ============================================================
#  hongos_pixel.gd  (class_name HongosPixel)
#  LAS SETAS DE UN FLORECIDO (09/11/2026, miconido-mutante, parte C de la infeccion): el enemigo que cae Infectado y se
#  levanta con hongos lleva setas naranjas y tallos con la punta de luz brotandole DEL CUERPO. Las setas son las de la
#  lamina aprobada (tools/sprites_sdf/hongos_florecido_pixel.py, mismos dibujos y paleta).
#
#  10/11 (el jefe: "una puta mierda, no parece que le aparezcan por el cuerpo real"): antes se plantaban en una linea
#  por el borde de arriba de la CAJA y flotaban. Ahora van CLAVADAS EN LA SILUETA DEL FOTOGRAMA QUE SE VE: cada
#  fotograma de cada hoja trae sus anclas medidas offline (AnclasHongos, tools/anclas_hongos.py), asi que las setas
#  suben, bajan y giran con el cuerpo en cada pose. Lo que eligio ademas: SETAS POR MAS SITIOS (arriba, los lados y el
#  frente) y ESPORAS FLOTANDO (pixeles que suben despacio desde los sombreros y se apagan poco a poco).
#  10/11, VERSION E (la eligio de una lamina de cinco: "esta es peak"), para que se METAN en el sprite y no parezcan
#  pegatinas: (B) MANCHA PODRIDA alrededor de cada pie, solo sobre el cuerpo (mancha_florecido.gdshader con el mismo
#  fotograma); (C) setas AL TONO DEL MUERTO (mas apagadas; la punta de luz cian intacta); (D) las de los LADOS por DETRAS
#  del cuerpo y hacia fuera (z por debajo de los cuerpos).
#  10/11, tras verlo en tus personajes ("manchones encima de la armadura; no son pixel art igual que el personaje, chocan"):
#  la mancha MULTIPLICA los colores del cuerpo en dos escalones exactos (no un marron transparente encima), y las setas
#  ya NO pasan por CapaPixel (que las volvia a pixelar en otra rejilla y salian borrosas): se pintan directas con el
#  MISMO tamaño de pixel que el sprite y en SU rejilla (los pies salen de sus pixeles). Las esporas, en esa rejilla.
#  Si la hoja no esta medida (un bicho sin hornear), se vuelve a lo de antes: por arriba de su caja.
#  Las pone y las sigue TacticoHongos.
# ============================================================
extends Node2D
class_name HongosPixel

const PAL := {
	"o": Color8(46, 22, 10), "d": Color8(140, 60, 16), "m": Color8(196, 98, 26), "l": Color8(236, 150, 60),
	"b": Color8(255, 226, 180), "s": Color8(214, 200, 176), "p": Color8(150, 136, 116), "a": Color8(90, 220, 190),
	"w": Color8(210, 255, 240),
}
# Cada una con su PIE abajo en el centro (la ultima fila es donde se clava). Las de la lamina.
const SETAS := {
	"pequena": ["..ooo..", ".olmlo.", "oolbmoo", "..oso..", "..oso.."],
	"mediana": ["...ooooo...", "..olllmmo..", ".olblllmmo.", "ooooooooooo", "....oso....", "....oso....", "....ops...."],
	"doble": ["..ooo......", ".olmlo.ooo.", "oolbmoolmlo", "..osooolbmo", "..oso..oso.", "..oso..oso."],
	"tallo": ["aw.", "ow.", "od.", "om.", "om.", "od."],
	"tallo_largo": [".aw", ".ow", ".om", "om.", "od.", "om.", "od."],
}
const HUNDIDA := 2.0   # celdas que se mete en el cuerpo: que salga DE el (la lamina: borde de arriba + 2)
# ESPORAS: cada cuanto sale una (s), cuanto viven (s), a que velocidad suben (celdas/s) y sus colores.
const ESPORA_CADA := Vector2(0.22, 0.45)
const ESPORA_VIDA := Vector2(1.6, 2.6)
const ESPORA_SUBE := Vector2(5.0, 9.0)
const ESPORA_COL := [Color8(255, 226, 180), Color8(210, 255, 240), Color8(236, 150, 60)]

const MANCHA_SHADER := preload("res://shaders/mancha_florecido.gdshader")

static var _tex: Dictionary = {}

var _caja: Rect2 = Rect2()
var _spr: AnimatedSprite2D = null   # el dibujo del cuerpo (su sprite, o la capa "cuerpo" de tu muñeco)
var _ref: Node2D = null             # en cuyo espacio se dibuja (la arena, mi padre)
var _plantadas: Array = []   # [{tex, ranura, u, pie: Vector2 (o null), celda}]
var _esporas: Array = []     # [{p, v, t, vida, col}]
var _prox_espora: float = 0.0
var _rng := RandomNumberGenerator.new()
var _detras: Node2D = null     # las setas de los lados: por detras del cuerpo (z bajo los cuerpos)
var _medido: bool = false   # alguna vez se clavaron con anclas: desde entonces no se vuelve a la caja
var _rejilla: Vector2 = Vector2.ZERO   # una esquina de pixel del sprite (las esporas se cuadran a su rejilla)
var _mancha: Sprite2D = null   # la mancha podrida: el mismo fotograma que el cuerpo, encima, con su shader


static func poner(padre: Node, caja: Rect2, semilla: int, spr: AnimatedSprite2D = null) -> HongosPixel:
	if padre == null:
		return null
	var h := HongosPixel.new()
	h._rng.seed = semilla
	h._spr = spr
	h._ref = padre as Node2D
	h.z_as_relative = false
	h.z_index = Game.Z_ENCIMA_PERSONAJES
	h.process_mode = Node.PROCESS_MODE_ALWAYS
	# PIXEL EXACTO (10/11): sin esto las setas se escalaban con filtro suave y salian borrosas al lado del sprite
	h.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var det := Node2D.new()
	det.z_as_relative = false
	det.z_index = Game.Z_PERSONAJES - 1
	det.draw.connect(h._dibujar_detras)
	h.add_child(det)
	h._detras = det
	padre.add_child(h)
	h.seguir(caja)
	return h


static func textura(nombre: String) -> Texture2D:
	if _tex.has(nombre):
		return _tex[nombre]
	var izq: bool = nombre.ends_with("_izq")
	var filas: Array = SETAS[nombre.trim_suffix("_izq")]
	var w: int = 0
	for f in filas:
		w = maxi(w, (f as String).length())
	var im := Image.create(w, filas.size(), false, Image.FORMAT_RGBA8)
	for y in filas.size():
		var f: String = filas[y]
		for x in f.length():
			if PAL.has(f[x]):
				im.set_pixel(w - 1 - x if izq else x, y, _al_tono(f[x]))
	var t := ImageTexture.create_from_image(im)
	_tex[nombre] = t
	return t


# (C) AL TONO DEL MUERTO: menos color y mas oscuro, como el cuerpo apagado; la luz cian de las puntas, tal cual.
static func _al_tono(ch: String) -> Color:
	var c: Color = PAL[ch]
	if ch == "a" or ch == "w":
		return c
	var g: float = (c.r + c.g + c.b) / 3.0
	return Color((c.r * 0.7 + g * 0.3) * 0.8, (c.g * 0.7 + g * 0.3) * 0.8, (c.b * 0.7 + g * 0.3) * 0.8)


func seguir(caja: Rect2, spr: AnimatedSprite2D = null) -> void:
	_caja = caja
	if spr != null and spr != _spr:
		_quitar_mancha()
		_spr = spr
	if _plantadas.is_empty() and caja.has_area():
		_plantar()


# Cuantas y cuales, segun lo ancho que sea (en celdas). Arriba como la lamina; mas los lados y el frente.
func _plantar() -> void:
	var ancho: float = _caja.size.x / SpriteLienzo.UNIDADES_POR_CELDA
	var arriba: int = 3 if ancho < 40.0 else (4 if ancho < 70.0 else 5)
	var lados: Array = [6] if ancho < 40.0 else [6, 7]
	var frente: Array = [8] if ancho < 70.0 else [8, 9]
	var tipos: Array = ["tallo", "pequena", "mediana", "tallo_largo", "doble"] if ancho >= 40.0 \
		else ["tallo", "pequena", "tallo_largo"]
	for i in range(tipos.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp = tipos[i]
		tipos[i] = tipos[j]
		tipos[j] = tmp
	for k in arriba:
		# las 'arriba' de las 6 ranuras medidas, repartidas: 3 -> 1,3,5; 4 -> 0,2,3,5; 5 -> 0,1,3,4,5
		var r: int = int((float(k) + 0.5) * 6.0 / float(arriba))
		var u: float = 0.1 + 0.8 * (float(k) + 0.5) / float(arriba)
		_plantadas.append({"tex": textura(tipos[k % tipos.size()]), "ranura": r, "u": u, "pie": null})
	# por los lados y el frente, las pequeñas (que no tapen la cara del bicho)
	var chicas: Array = ["pequena", "tallo", "pequena", "tallo_largo"]
	var n: int = 0
	for r in lados + frente:
		var nom: String = chicas[(n + _rng.randi_range(0, 1)) % chicas.size()]
		var lado: int = -1 if r == 6 else (1 if r == 7 else 0)
		_plantadas.append({"tex": textura(nom + ("_izq" if lado < 0 else "")), "ranura": r, "u": -1.0, "pie": null,
			"lado": lado, "medido": lado, "nom": nom})
		n += 1


func _process(delta: float) -> void:
	_colocar()
	_mover_esporas(delta)
	queue_redraw()
	if is_instance_valid(_detras):
		_detras.queue_redraw()


# El pie de cada seta en este fotograma: el ancla medida de su ranura, pasada del pixel de la hoja al espacio de la
# arena. Sin ancla en este fotograma, se queda donde estaba.
func _colocar() -> void:
	var at: AtlasTexture = null
	var tabla: AnclasHongos = null
	if is_instance_valid(_spr) and _spr.sprite_frames != null and _spr.sprite_frames.has_animation(_spr.animation):
		at = _spr.sprite_frames.get_frame_texture(_spr.animation, _spr.frame) as AtlasTexture
		if at != null and at.atlas != null and at.atlas.has_meta(SpriteLienzo.META_HOJA_RUTA):
			tabla = AnclasHongos.de(String(at.atlas.get_meta(SpriteLienzo.META_HOJA_RUTA)))
	if tabla == null:
		# un fotograma suelto sin anclas (otra hoja un momento): se quedan donde estaban, no saltan a la caja
		if _medido:
			return
		# sin medir: por arriba de la caja, como antes (los lados y el frente no salen)
		for p in _plantadas:
			if float(p["u"]) >= 0.0:
				p["pie"] = Vector2(_caja.position.x + _caja.size.x * float(p["u"]), _caja.position.y + HUNDIDA * SpriteLienzo.UNIDADES_POR_CELDA)
				p["celda"] = SpriteLienzo.UNIDADES_POR_CELDA
		return
	_medido = true
	var reg := Vector2i(at.region.position)
	var xf: Transform2D = _a_ref() * _spr.get_global_transform()
	var celda: float = xf.get_scale().abs().x
	var en_sprite: PackedVector2Array = PackedVector2Array()   # los pies de la mancha, en el espacio del sprite
	for p in _plantadas:
		var a: Vector2i = tabla.ancla(reg, int(p["ranura"]))
		if a.x < 0:
			continue
		# el pixel en el lienzo del fotograma (recorte + margen); el pie, en su borde de abajo tras hundirse
		p["pie"] = xf * _en_sprite(at, Vector2(a.x + 0.5, a.y + HUNDIDA + 1.0))
		p["celda"] = celda
		_rejilla = xf * _en_sprite(at, Vector2(a.x, a.y))
		# un sprite espejado cambia la izquierda por la derecha: la seta del lado sigue saliendo hacia FUERA
		if int(p.get("medido", 0)) != 0:
			var lado: int = int(p["medido"]) * (-1 if _spr.flip_h else 1)
			if lado != int(p["lado"]):
				p["lado"] = lado
				p["tex"] = textura(String(p["nom"]) + ("_izq" if lado < 0 else ""))
		en_sprite.append(_en_sprite(at, Vector2(a.x + 0.5, a.y + HUNDIDA + 0.5)))
	_pintar_mancha(at, en_sprite)


# Un punto del recorte (pixeles de la hoja, desde su esquina) en el espacio del sprite (lo que el sprite llama VERTEX).
func _en_sprite(at: AtlasTexture, pt: Vector2) -> Vector2:
	var tam: Vector2 = at.region.size + at.margin.size
	var q := at.margin.position + pt
	if _spr.flip_h:
		q.x = tam.x - q.x
	q += _spr.offset
	if _spr.centered:
		q -= tam * 0.5
	return q


# (B) LA MANCHA: un Sprite2D hijo del sprite del cuerpo con su mismo fotograma (asi solo pinta donde hay cuerpo) y el
# shader. Hijo = se pinta justo encima de el y le sigue solo. En tu muñeco la ropa va en otras capas por encima de la
# piel: ahi sube por encima de ellas (z relativo alto dentro del muñeco).
func _pintar_mancha(at: AtlasTexture, pies_spr: PackedVector2Array) -> void:
	if not is_instance_valid(_spr):
		return
	if not is_instance_valid(_mancha):
		_mancha = Sprite2D.new()
		_mancha.name = "ManchaFlorecido"
		_mancha.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var mat := ShaderMaterial.new()
		mat.shader = MANCHA_SHADER
		_mancha.material = mat
		if _spr.get_parent() is MunecoJugador:
			_mancha.z_index = 40
		_spr.add_child(_mancha)
	_mancha.texture = at
	_mancha.centered = _spr.centered
	_mancha.offset = _spr.offset
	_mancha.flip_h = _spr.flip_h
	var mat: ShaderMaterial = _mancha.material
	var lista: Array = []
	for v in pies_spr:
		lista.append(v)
	while lista.size() < 10:
		lista.append(Vector2(-9999, -9999))
	mat.set_shader_parameter("pies", lista.slice(0, 10))
	mat.set_shader_parameter("n_pies", mini(pies_spr.size(), 10))


func _quitar_mancha() -> void:
	if is_instance_valid(_mancha):
		_mancha.queue_free()
	_mancha = null


func _a_ref() -> Transform2D:
	if is_instance_valid(_ref):
		return _ref.get_global_transform().affine_inverse()
	return Transform2D.IDENTITY


# ESPORAS: salen de un sombrero al azar, suben despacio meciendose y se apagan poco a poco (transicion, no salto).
func _mover_esporas(delta: float) -> void:
	_prox_espora -= delta
	if _prox_espora <= 0.0:
		_prox_espora = _rng.randf_range(ESPORA_CADA.x, ESPORA_CADA.y)
		var vale: Array = []
		for p in _plantadas:
			if p["pie"] != null:
				vale.append(p)
		if not vale.is_empty():
			var p: Dictionary = vale[_rng.randi_range(0, vale.size() - 1)]
			var tex: Texture2D = p["tex"]
			var c: float = float(p.get("celda", SpriteLienzo.UNIDADES_POR_CELDA))
			var desde: Vector2 = (p["pie"] as Vector2) + Vector2(_rng.randf_range(-0.4, 0.4) * tex.get_width() * c,
				-tex.get_height() * c)
			_esporas.append({"p": desde, "x0": desde.x, "t": 0.0, "c": c,
				"vida": _rng.randf_range(ESPORA_VIDA.x, ESPORA_VIDA.y),
				"sube": _rng.randf_range(ESPORA_SUBE.x, ESPORA_SUBE.y), "fase": _rng.randf() * TAU,
				"col": ESPORA_COL[_rng.randi_range(0, ESPORA_COL.size() - 1)]})
	for i in range(_esporas.size() - 1, -1, -1):
		var e: Dictionary = _esporas[i]
		e["t"] = float(e["t"]) + delta
		if float(e["t"]) >= float(e["vida"]):
			_esporas.remove_at(i)
			continue
		var c: float = e["c"]
		e["p"] = Vector2(float(e["x0"]) + sin(float(e["t"]) * 2.2 + float(e["fase"])) * 1.5 * c,
			(e["p"] as Vector2).y - float(e["sube"]) * c * delta)


func _draw() -> void:
	for p in _plantadas:
		if p["pie"] != null and int(p.get("lado", 0)) == 0:
			_seta(self, p)
	for e in _esporas:
		var c: float = e["c"]
		var k: float = float(e["t"]) / float(e["vida"])
		# entra en el primer 20 % y se apaga en el ultimo 40 %
		var al: float = clampf(k / 0.2, 0.0, 1.0) * clampf((1.0 - k) / 0.4, 0.0, 1.0)
		var col: Color = e["col"]
		col.a = al
		var pp: Vector2 = e["p"]
		draw_rect(Rect2(((pp - _rejilla) / c).floor() * c + _rejilla, Vector2(c, c)), col)


# (D) Las de los lados, desde el nodo de detras (bajo los cuerpos): hacia FUERA, el pie en el borde del cuerpo.
func _dibujar_detras() -> void:
	for p in _plantadas:
		if p["pie"] != null and int(p.get("lado", 0)) != 0:
			_seta(_detras, p)


func _seta(lienzo: CanvasItem, p: Dictionary) -> void:
	var tex: Texture2D = p["tex"]
	var c: float = float(p.get("celda", SpriteLienzo.UNIDADES_POR_CELDA))
	var tam := Vector2(tex.get_width(), tex.get_height()) * c
	var pie: Vector2 = p["pie"]
	var x0: float = pie.x - tam.x * 0.5
	match int(p.get("lado", 0)):
		-1:
			x0 = pie.x + 1.5 * c - tam.x   # como la lamina: de x-w+2 a x+2
		1:
			x0 = pie.x - 1.5 * c           # de x-1 a x-1+w
	lienzo.draw_texture_rect(tex, Rect2(Vector2(x0, pie.y - tam.y), tam), false)


func secar() -> void:
	_quitar_mancha()
	queue_free()


# Para las pruebas: si este fotograma tiene anclas medidas, cuantas setas hay puestas y cuantas tienen el pie DENTRO
# del recorte del fotograma que se ve (el dibujo de verdad, no la caja de la ficha), en el espacio de la arena.
func medida() -> Dictionary:
	_colocar()
	var out := {"medida": false, "pies": 0, "dentro": 0}
	if not is_instance_valid(_spr) or _spr.sprite_frames == null or not _spr.sprite_frames.has_animation(_spr.animation):
		return out
	var at: AtlasTexture = _spr.sprite_frames.get_frame_texture(_spr.animation, _spr.frame) as AtlasTexture
	if at == null or at.atlas == null or not at.atlas.has_meta(SpriteLienzo.META_HOJA_RUTA):
		return out
	out["medida"] = AnclasHongos.de(String(at.atlas.get_meta(SpriteLienzo.META_HOJA_RUTA))) != null
	var tam: Vector2 = at.region.size + at.margin.size
	var r := Rect2(at.margin.position, at.region.size)
	if _spr.flip_h:
		r.position.x = tam.x - r.end.x
	r.position += _spr.offset - (tam * 0.5 if _spr.centered else Vector2.ZERO)
	var xf: Transform2D = _a_ref() * _spr.get_global_transform()
	var caja := Rect2(xf * r.position, Vector2.ZERO).expand(xf * r.end)
	caja = caja.grow(xf.get_scale().abs().x * (HUNDIDA + 1.5))
	for p in _plantadas:
		if p["pie"] == null:
			continue
		out["pies"] = int(out["pies"]) + 1
		if caja.has_point(p["pie"]):
			out["dentro"] = int(out["dentro"]) + 1
	return out
