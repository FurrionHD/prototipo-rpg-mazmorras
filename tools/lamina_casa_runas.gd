# HERRAMIENTA. No forma parte del juego. CON VENTANA (los vidrios de noche son texturas):
#
#   godot --path . res://tools/lamina_casa_runas.tscn
#
# LA CASA DEL TALLER DE RUNAS (08/10/2026) al lado de sus vecinas reales (taberna y peleteria), de DIA y de NOCHE, a x3.
# Para su diagnostico: Escritorio/taller_runas/casa_runas_LAMINA.png
extends Node

const SALIDA := "C:/Users/dasui/Desktop/taller_runas/casa_runas_LAMINA.png"
const CASAS := ["taberna", "runas", "peleteria"]
const ESC := 3
const HUECO := 30


func _ready() -> void:
	var dia: Array = []
	var noche: Array = []
	for c in CASAS:
		var img: Image = _con_cartel(c, CasaSprites.generar(c))
		dia.append(img)
		noche.append(_de_noche(c, img))
	var ancho: int = HUECO
	var alto: int = 0
	for img in dia:
		ancho += (img as Image).get_width() + HUECO
		alto = maxi(alto, (img as Image).get_height())
	var lam := Image.create(ancho, alto * 2 + HUECO * 3, false, Image.FORMAT_RGBA8)
	lam.fill(Color(0.36, 0.44, 0.30))
	var noche_fondo := Rect2i(0, alto + HUECO * 2 - HUECO / 2, ancho, alto + HUECO * 2)
	lam.fill_rect(noche_fondo, Color(0.08, 0.10, 0.16))
	var x: int = HUECO
	for i in CASAS.size():
		var a: Image = dia[i]
		var b: Image = noche[i]
		lam.blend_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i(x, HUECO + alto - a.get_height()))
		lam.blend_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(x, HUECO * 2 + alto * 2 - b.get_height()))
		x += a.get_width() + HUECO
	lam.resize(lam.get_width() * ESC, lam.get_height() * ESC, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(SALIDA.get_base_dir())
	lam.save_png(SALIDA)
	print("[lamina] ", SALIDA)
	get_tree().quit()


# La casa con su cartel colgado (en un lienzo algo mas ancho para que quepa el brazo).
func _con_cartel(c: String, casa: Image) -> Image:
	var icono: String = String(CasaSprites.CASAS[c].get("cartel", ""))
	var margen: int = CasaSprites.CARTEL_TAM.x
	var out := Image.create(casa.get_width() + margen * 2, casa.get_height(), false, Image.FORMAT_RGBA8)
	out.blend_rect(casa, Rect2i(Vector2i.ZERO, casa.get_size()), Vector2i(margen, 0))
	if icono != "":
		var cart: Image = CasaSprites.cartel(icono, CasaSprites.cartel_a_la_izq(c))
		var p: Vector2i = CasaSprites.posicion_cartel(c) + Vector2i(margen, 0)
		out.blend_rect(cart, Rect2i(Vector2i.ZERO, cart.get_size()), p)
	return out


# De noche: todo oscurecido y azulado, y encima los vidrios encendidos de sus ventanas (y glifos).
func _de_noche(c: String, img: Image) -> Image:
	var out: Image = img.duplicate()
	for y in out.get_height():
		for x in out.get_width():
			var col: Color = out.get_pixel(x, y)
			if col.a > 0.0:
				out.set_pixel(x, y, Color(col.r * 0.32, col.g * 0.36, col.b * 0.5, col.a))
	var margen: int = CasaSprites.CARTEL_TAM.x
	var casa: Image = CasaSprites.generar(c)
	for v in CasaSprites.ventanas(c):
		var esq: Vector2i = v[0]
		var tex: ImageTexture = CasaSprites.textura_vidrio(c, esq, String(v[1]), casa)
		var vid: Image = tex.get_image()
		out.blend_rect(vid, Rect2i(Vector2i.ZERO, vid.get_size()), esq + Vector2i(margen, 0))
	return out
