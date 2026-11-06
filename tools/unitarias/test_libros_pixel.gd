extends "res://tools/unitarias/caso.gd"
# ============================================================
#  LOS LIBROS EN PIXEL (06/11, scripts/ui/libros_pixel.gd)
#  Cada libro del juego (todo consumible con tomo_id) tiene SU dibujo de 32 x 32, el icono de la rejilla y el
#  del suelo salen de el, y cada grimorio se encuentra desde su magia (las cartas del gacha llegan con la magia).
#  Si se añade un libro sin pasarlo por tools/libros_pixel.py --hornear, salta aqui.
# ============================================================

const LibrosPixel = preload("res://scripts/ui/libros_pixel.gd")
const SpritesObjeto = preload("res://scripts/ui/sprites_objeto.gd")


func _libros() -> Array:
	var out: Array = []
	for r in Game.rutas_consumibles():
		var c := load(r) as ConsumableData
		if c != null and c.en_biblioteca():
			out.append(c)
	return out


func test_cada_libro_tiene_su_dibujo() -> void:
	var libros: Array = _libros()
	cierto(libros.size() >= 59, "hay %d libros y deberian ser 59 o mas" % libros.size())
	for c in libros:
		var img: Image = LibrosPixel.imagen(c.tomo_id)
		if not cierto(img != null, "%s (%s) no tiene PNG en %s" % [c.nombre, c.tomo_id, LibrosPixel.CARPETA]):
			continue
		igual(img.get_size(), Vector2i(32, 32), "tamaño del libro %s" % c.tomo_id)


func test_el_grimorio_sale_de_su_magia() -> void:
	for c in _libros():
		if (c as ConsumableData).es_grimorio():
			igual(LibrosPixel.id_de_magia(c.spell), c.tomo_id, "tomo de la magia de %s" % c.nombre)
	igual(LibrosPixel.id_de_magia(null), &"", "sin magia, sin libro")


func test_el_icono_de_la_rejilla_es_el_libro() -> void:
	for c in _libros():
		var t: Dictionary = SpritesObjeto.textura_item(c)
		if not cierto(t.has("tex"), "%s sin icono de rejilla" % c.tomo_id):
			continue
		igual((t["tex"] as Texture2D).resource_path, LibrosPixel.ruta(c.tomo_id),
			"el icono de %s es su PNG de libro" % c.tomo_id)


func test_libro_desconocido_no_pinta() -> void:
	cierto(not LibrosPixel.tiene(&"no_existe_este_libro"), "un id inventado no tiene dibujo")
	cierto(not LibrosPixel.tiene(&""), "el id vacio no tiene dibujo")
