# ============================================================
#  libros_pixel.gd  (06/11, rework visual a pixel)
#  LOS LIBROS EN PIXEL ART DE VERDAD: cada grimorio con el emblema de SU magia en una tapa del color de su
#  elemento, y cada tocho con el dibujo de su tema (los de sabiduria, con una chispa de oro en la esquina).
#  Estilo A, el tomo con correa, elegido por el jefe el 06/11.
#
#  LOS DIBUJOS NO SE HACEN AQUI: salen de tools/libros_pixel.py (pixel a pixel, emblemas en
#  tools/libros_emblemas.py) como un PNG de 32 x 32 por libro en assets/sprites/libros, con el nombre de su
#  tomo_id. Para retocar uno: tocar el python y `python tools/libros_pixel.py --hornear`.
#
#  SE PINTAN POR RACHAS DE draw_rect y no como textura: el proyecto filtra en lineal, y una textura de 32 px
#  ampliada en un CanvasItem ajeno sale borrosa. En las rejillas va la textura tal cual en un TextureRect con
#  filtro NEAREST (ver SpritesObjeto.textura_item), que es lo barato.
# ============================================================

const CARPETA := "res://assets/sprites/libros/"
const N := 32

static var _img: Dictionary = {}      # tomo_id -> Image (o null si no hay dibujo)
static var _rachas: Dictionary = {}   # tomo_id -> Array de [x, y, ancho, Color]


static func ruta(id: StringName) -> String:
	return CARPETA + String(id) + ".png"


static func tiene(id: StringName) -> bool:
	return id != &"" and imagen(id) != null


# El tomo_id del grimorio que enseña 'spell' (el .tres del grimorio se llama igual que el de la magia).
static func id_de_magia(spell: Resource) -> StringName:
	if spell == null or spell.resource_path == "":
		return &""
	return StringName("grimorio_" + spell.resource_path.get_file().get_basename())


static func textura(id: StringName) -> Texture2D:
	if id == &"" or not ResourceLoader.exists(ruta(id)):
		return null
	return load(ruta(id)) as Texture2D


static func imagen(id: StringName) -> Image:
	if _img.has(id):
		return _img[id]
	var t: Texture2D = textura(id)
	var img: Image = t.get_image() if t != null else null
	if img != null and img.is_compressed():
		img.decompress()
	_img[id] = img
	return img


# Las rachas horizontales de un mismo color, fila a fila: lo que se pinta con un draw_rect cada una.
static func _rachas_de(id: StringName) -> Array:
	if _rachas.has(id):
		return _rachas[id]
	var out: Array = []
	var img: Image = imagen(id)
	if img != null:
		for y in img.get_height():
			var x: int = 0
			while x < img.get_width():
				var c: Color = img.get_pixel(x, y)
				var xs: int = x
				while x < img.get_width() and img.get_pixel(x, y) == c:
					x += 1
				if c.a > 0.0:
					out.append([xs, y, x - xs, c])
	_rachas[id] = out
	return out


# Pinta el libro 'id' CENTRADO en 'centro' dentro de un cuadrado de 'lado'. De 32 px para arriba se escala
# por un ENTERO (todos los pixeles iguales, que es lo que hace que se lea como pixel art y no como un dibujo
# estirado); por debajo, a lo que quepa. Devuelve false si ese libro no tiene dibujo.
static func pintar(ci: CanvasItem, centro: Vector2, lado: float, id: StringName,
		tinte: Color = Color.WHITE) -> bool:
	var rachas: Array = _rachas_de(id)
	if rachas.is_empty():
		return false
	var k: float = lado / float(N)
	if k >= 1.0:
		k = floorf(k)
	var org: Vector2 = (centro - Vector2(N, N) * k * 0.5).round()
	for r in rachas:
		var xa: float = round(org.x + float(r[0]) * k)
		var xb: float = round(org.x + float(r[0] + r[2]) * k)
		var ya: float = round(org.y + float(r[1]) * k)
		var yb: float = round(org.y + float(r[1] + 1) * k)
		if yb > ya and xb > xa:
			ci.draw_rect(Rect2(xa, ya, xb - xa, yb - ya), (r[3] as Color) * tinte)
	return true
