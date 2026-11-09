# ============================================================
#  hongos_pixel.gd  (class_name HongosPixel)
#  LAS SETAS DE UN FLORECIDO (09/11/2026, miconido-mutante, parte C de la infeccion): el enemigo que cae Infectado y se
#  levanta con hongos lleva setas naranjas y tallos con la punta de luz brotandole por ARRIBA del cuerpo. Las setas son
#  las de la lamina aprobada (tools/sprites_sdf/hongos_florecido_pixel.py, mismos dibujos y paleta), en la rejilla de
#  los sprites (1 celda = SpriteLienzo.UNIDADES_POR_CELDA).
#  En la lamina se plantaban sobre la silueta medida; aqui, sobre el borde de arriba de su caja visual (la de su cuerpo,
#  marcada a mano en cada ficha), repartidas por el medio del ancho. Las pone y las sigue TacticoHongos.
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
const HUNDIDA := 2.0   # celdas que se mete en el cuerpo: que salga DE el

static var _tex: Dictionary = {}

var _caja: Rect2 = Rect2()
var _plantadas: Array = []   # [{tex, u}] u = fraccion del ancho
var _rng := RandomNumberGenerator.new()


static func poner(padre: Node, caja: Rect2, semilla: int) -> HongosPixel:
	if padre == null:
		return null
	var h := HongosPixel.new()
	h._rng.seed = semilla
	h.z_as_relative = false
	h.z_index = Game.Z_ENCIMA_PERSONAJES
	h.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(h)
	CapaPixel.meter(h)
	h.seguir(caja)
	return h


static func textura(nombre: String) -> Texture2D:
	if _tex.has(nombre):
		return _tex[nombre]
	var filas: Array = SETAS[nombre]
	var w: int = 0
	for f in filas:
		w = maxi(w, (f as String).length())
	var im := Image.create(w, filas.size(), false, Image.FORMAT_RGBA8)
	for y in filas.size():
		var f: String = filas[y]
		for x in f.length():
			if PAL.has(f[x]):
				im.set_pixel(x, y, PAL[f[x]])
	var t := ImageTexture.create_from_image(im)
	_tex[nombre] = t
	return t


func seguir(caja: Rect2) -> void:
	if caja.is_equal_approx(_caja):
		return
	var era_vacia: bool = _plantadas.is_empty()
	_caja = caja
	if era_vacia:
		_plantar()
	queue_redraw()


# Cuantas y cuales, segun lo ancho que sea (en celdas), como en la lamina.
func _plantar() -> void:
	var celda: float = SpriteLienzo.UNIDADES_POR_CELDA
	var ancho: float = _caja.size.x / celda
	var n: int = 4 if ancho < 40.0 else (5 if ancho < 70.0 else 6)
	var tipos: Array = ["tallo", "pequena", "mediana", "tallo_largo", "doble", "pequena"] if ancho >= 40.0 \
		else ["tallo", "pequena", "tallo_largo", "pequena"]
	for i in range(tipos.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp = tipos[i]
		tipos[i] = tipos[j]
		tipos[j] = tmp
	for k in n:
		var u: float = 0.1 + 0.8 * (float(k) + 0.5) / float(n) + _rng.randf_range(-0.04, 0.04)
		_plantadas.append({"tex": textura(tipos[k % tipos.size()]), "u": u})


func _draw() -> void:
	var celda: float = SpriteLienzo.UNIDADES_POR_CELDA
	for p in _plantadas:
		var tex: Texture2D = p["tex"]
		var tam := Vector2(tex.get_width(), tex.get_height()) * celda
		var pie := Vector2(_caja.position.x + _caja.size.x * float(p["u"]), _caja.position.y + HUNDIDA * celda)
		draw_texture_rect(tex, Rect2(pie - Vector2(tam.x * 0.5, tam.y), tam), false)


func secar() -> void:
	queue_free()
