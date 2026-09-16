# ============================================================
#  dev_escaleras_hoja.gd  --  HERRAMIENTA, no parte del juego.
#
#  HOJA DE LAS ESCALERAS (EscaleraSprites) sobre el SUELO DE VERDAD de cada tramo (roca 1-6, cueva 7-12),
#  ampliada x4, con las viejas al lado para comparar. Imagen pura: sirve con --headless.
#  Saca tools/salida/escaleras_hoja.png y se cierra.
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
const ZOOM := 4


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA)
	var tramos := ["roca", "cueva"]
	var nuevas := ["baja", "sube", "caracol"]
	var celda := Vector2i(120, 170)
	var hoja := Image.create(celda.x * 5, celda.y * tramos.size(), false, Image.FORMAT_RGBA8)
	for fi in tramos.size():
		var atlas: Image = TerrenoSprites.generar(tramos[fi])
		var suelo: Image = _baldosa(atlas)
		var fila := Image.create(celda.x * 5, celda.y, false, Image.FORMAT_RGBA8)
		for y in celda.y:
			for x in celda.x * 5:
				fila.set_pixel(x, y, suelo.get_pixel(x % suelo.get_width(), y % suelo.get_height()))
		# Las viejas, para comparar.
		var col: int = 0
		for vieja in ["escalera_baja", "escalera_sube"]:
			var im: Image = PropSprites.generar(vieja)
			fila.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(col * celda.x + 36, celda.y - 60))
			col += 1
		for n in nuevas:
			var im2: Image = EscaleraSprites.generar(n)
			fila.blend_rect(im2, Rect2i(Vector2i.ZERO, im2.get_size()),
				Vector2i(col * celda.x + (celda.x - im2.get_width()) / 2, celda.y - im2.get_height() - 8))
			col += 1
		hoja.blit_rect(fila, Rect2i(Vector2i.ZERO, fila.get_size()), Vector2i(0, fi * celda.y))
	# Las NUEVAS de cerca, una hoja por tramo (x4): a x2 no se juzga nada.
	for fi in tramos.size():
		var cerca: Image = hoja.get_region(Rect2i(celda.x * 2, fi * celda.y, celda.x * 3, celda.y))
		cerca.resize(cerca.get_width() * ZOOM, cerca.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
		cerca.save_png("%sescaleras_cerca_%s.png" % [SALIDA, tramos[fi]])
	hoja.resize(hoja.get_width() * ZOOM / 2, hoja.get_height() * ZOOM / 2, Image.INTERPOLATE_NEAREST)
	hoja.save_png(SALIDA + "escaleras_hoja.png")
	print("[hoja] guardada ", hoja.get_size())
	get_tree().quit()


# Una baldosa de suelo lisa (sin bordes de muro) del atlas del tramo, repetida 2x2 con variantes.
func _baldosa(atlas: Image) -> Image:
	var l: int = TerrenoSprites.LADO
	var out := Image.create(l * 2, l * 2, false, Image.FORMAT_RGBA8)
	for k in 4:
		var c: Vector2i = TerrenoSprites.celda_de("suelo", TerrenoSprites.indice("suelo", 0, k))
		out.blit_rect(atlas, Rect2i(c * l, Vector2i(l, l)), Vector2i((k % 2) * l, (k / 2) * l))
	return out
