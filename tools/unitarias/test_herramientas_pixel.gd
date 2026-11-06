extends "res://tools/unitarias/caso.gd"
# ============================================================
#  LAS HERRAMIENTAS EN PIXEL (06/11): pico, hoz, hacha, caña y cuchillo con su PNG de 32 x 32 en grises de indice
#  (assets/sprites/equipo/herramienta, de tools/equipo_herramientas.py --hornear), tenidos en SpritesObjeto con la
#  paleta del icono de arma por tier y mejora. El farolillo sigue con su dibujo de facetas.
# ============================================================

const SpritesObjeto = preload("res://scripts/ui/sprites_objeto.gd")


func _herramienta(tipo: int) -> ToolData:
	var td := ToolData.new()
	td.tipo = tipo
	return td


func test_cada_herramienta_tiene_png() -> void:
	for f in ["pico", "hoz", "hacha", "cana", "cuchillo"]:
		var r: String = SpritesObjeto.ruta_herramienta(f)
		if cierto(ResourceLoader.exists(r), "falta el PNG de %s" % f):
			var t := load(r) as Texture2D
			igual(Vector2i(t.get_width(), t.get_height()), Vector2i(32, 32), "tamaño de %s" % r)


func test_el_icono_sale_en_pixel_y_tenido() -> void:
	for tipo in [ToolData.Tipo.PICO, ToolData.Tipo.HOZ, ToolData.Tipo.HACHA, ToolData.Tipo.CANA, ToolData.Tipo.CUCHILLO]:
		var t: Dictionary = SpritesObjeto.textura_item(_herramienta(tipo))
		if not cierto(t.has("tex"), "la herramienta %d tiene icono" % tipo):
			continue
		var tex: Texture2D = t["tex"]
		igual(Vector2i(tex.get_width(), tex.get_height()), Vector2i(32, 32), "el icono es el de 32 px")
		cierto(tex.has_meta("pixel"), "se amplia por entero")
		# Tenido: ya no quedan grises puros (r == g == b) donde hay dibujo... salvo que el color lo sea; basta con
		# que haya MAS de un color y alguno no gris.
		var img: Image = tex.get_image()
		var color: bool = false
		for y in 32:
			for x in 32:
				var c: Color = img.get_pixel(x, y)
				if c.a > 0.5 and (absf(c.r - c.g) > 0.02 or absf(c.g - c.b) > 0.02):
					color = true
		cierto(color, "la herramienta %d sale tenida, no en grises" % tipo)


func test_el_farol_sigue_con_su_dibujo() -> void:
	var t: Dictionary = SpritesObjeto.textura_item(_herramienta(ToolData.Tipo.LAMPARA))
	if cierto(t.has("tex"), "el farolillo tiene icono"):
		cierto(not (t["tex"] as Texture2D).has_meta("pixel"), "el farolillo no es de los PNG en pixel")
