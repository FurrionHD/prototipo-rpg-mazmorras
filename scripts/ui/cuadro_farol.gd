# ============================================================
#  cuadro_farol.gd
#  EL FAROLILLO del HUD, al lado de la mochila: un farol con SU LLAMA dentro, que se apaga segun se
#  consume el carbon que esta ardiendo.
#
#  Hermano de cuadro_carga.gd (el deposito de peso) y por el mismo motivo: la luz que te queda era un
#  numero escondido en la pestaña "Farolillo" del inventario, o sea que para saber si te ibas a
#  quedar a oscuras habia que abrir un menu y leer. Un farol que se va apagando se lee de reojo
#  mientras andas, que es cuando importa.
#
#  EN PIXEL (07/11, playtest del .exe: "esto no tiene pixel art"): era un farol de lineas suavizadas con la llama
#  vectorial de la Quemadura. Ahora es un dibujo de LADO x LADO (como la mochila, ver cuadro_carga.gd) ampliado sin
#  suavizar: asa, sombrero, cristal con sus dos montantes y base, y dentro UNA llama de pixel (cuerpo, nucleo casi
#  blanco y punta) que MENGUA con el carbon y titila a saltos. El resplandor son dos anillos escalonados, no un degradado.
# ============================================================

extends Control
class_name CuadroFarol

const LADO := 16
const PASOS_SEG := 8.0
# El color del fuego segun lo que quede del carbon en curso: de dorado vivo a un rojo mortecino. No
# es adorno -- el COLOR es lo que se lee de lejos, antes que el tamaño de la llama.
const COLOR_VIVA := Color(1.0, 0.78, 0.30)
const COLOR_MURIENDO := Color(0.85, 0.30, 0.10)
const NUCLEO := Color(1.0, 0.96, 0.70)
# Por debajo de esto el farol PARPADEA: es el aviso de que se acaba, y llega antes que quedarse a
# oscuras de golpe.
const UMBRAL_AGONIA := 0.22
# La llama, en filas del dibujo: de un cabo de mecha a casi llenar el cristal.
const ALTO_MIN := 2
const ALTO_MAX := 6

const FONDO := Color(0.10, 0.11, 0.14, 0.85)
const MARCO := Color(0.75, 0.78, 0.85, 0.9)
const METAL := Color(0.72, 0.74, 0.80)
const METAL_OSC := Color(0.45, 0.47, 0.54)
const CRISTAL := Color(0.16, 0.17, 0.21)

# Lo que se pinta, refrescado por el HUD cada frame (ver hud._process, que es quien sabe de Game).
#   llama  = fraccion del carbon EN CURSO que queda (1 recien prendido, 0 agotado)
#   hay_luz = tengo farolillo puesto y algo ardiendo. Sin esto el farol se apaga del todo.
var llama: float = 0.0
var hay_luz: bool = false

var _img: Image = null
var _tex: ImageTexture = null
var _firma: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS   # es un indicador, pero con tooltip
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(_delta: float) -> void:
	var paso: int = int(float(Time.get_ticks_msec()) / 1000.0 * PASOS_SEG)
	var firma: String = "%d|%.3f|%s" % [paso, llama, hay_luz]
	if firma == _firma:
		return
	_firma = firma
	_img = imagen(llama if hay_luz else 0.0, hay_luz, paso, _img)
	if _tex == null:
		_tex = ImageTexture.create_from_image(_img)
	else:
		_tex.update(_img)
	queue_redraw()


func _draw() -> void:
	if _tex != null:
		draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)


# EL DIBUJO, LADO x LADO. Estatico para la lamina (tools/lamina_cuadros_hud.gd). 'paso' = el fotograma (8 por segundo).
static func imagen(q: float, luz: bool, paso: int, img: Image = null) -> Image:
	if img == null:
		img = Image.create(LADO, LADO, false, Image.FORMAT_RGBA8)
	img.fill(FONDO)
	q = clampf(q, 0.0, 1.0) if luz else 0.0
	var col: Color = COLOR_MURIENDO.lerp(COLOR_VIVA, q)
	# Un azar fijo por fotograma: el titileo no se repite con un ritmo que se pille.
	var azar := RandomNumberGenerator.new()
	azar.seed = paso * 7919 + 13
	# AGONIA: la llama se queda sin fuerza uno de cada dos o tres fotogramas.
	var fuerza: float = 1.0
	if luz and q < UMBRAL_AGONIA and azar.randf() < 0.4:
		fuerza = 0.45

	# EL RESPLANDOR, dentro del cristal (x 5..10, y 4..11): dos anillos escalonados alrededor de la llama.
	var cx: float = 7.5
	var cy: float = 9.0
	for y in range(4, 12):
		for x in range(5, 11):
			var c: Color = CRISTAL
			if luz and q > 0.0:
				var d: float = Vector2(float(x) - cx, (float(y) - cy) * 0.8).length()
				var r: float = 2.0 + 2.0 * q
				if d <= r * 0.55:
					c = CRISTAL.lerp(col, 0.38 * fuerza)
				elif d <= r:
					c = CRISTAL.lerp(col, 0.18 * fuerza)
			img.set_pixel(x, y, c)

	# EL ASA (arco de pixeles), EL SOMBRERO y LA BASE: las tapas SOBRESALEN del cristal, que es lo que hace "farol".
	for p in [Vector2i(7, 1), Vector2i(8, 1), Vector2i(6, 2), Vector2i(9, 2)]:
		img.set_pixel(p.x, p.y, METAL)
	for x in range(4, 12):
		img.set_pixel(x, 3, METAL)
	for x in range(3, 13):
		img.set_pixel(x, 12, METAL)
	for x in range(4, 12):
		img.set_pixel(x, 13, METAL_OSC)
	# Los dos MONTANTES del cristal, de tapa a tapa.
	for y in range(4, 12):
		img.set_pixel(4, y, METAL_OSC)
		img.set_pixel(11, y, METAL_OSC)

	# LA LLAMA: de la mecha (fila 11) hacia arriba. Ancha abajo, afilada arriba; la punta se mece un pixel.
	if luz and q > 0.0:
		var alto: int = roundi(lerpf(float(ALTO_MIN), float(ALTO_MAX), q))
		alto = clampi(alto + azar.randi_range(-1, 0), ALTO_MIN - 1, ALTO_MAX)
		if fuerza < 1.0:
			alto = maxi(1, alto - 2)
		var vaiven: int = azar.randi_range(-1, 1)
		for k in alto:
			var y: int = 11 - k
			var u: float = float(k) / float(maxi(1, alto - 1))   # 0 abajo, 1 punta
			var x0: int = 7
			var x1: int = 8
			if u < 0.45 and alto >= 3:
				x0 = 6
				x1 = 9
			elif u > 0.7:
				x0 = 7 + (vaiven if vaiven > 0 else 0)
				x1 = x0
				if vaiven < 0:
					x0 = 7
					x1 = 7
			for x in range(x0, x1 + 1):
				var c: Color = col
				if k == alto - 1 and alto > 1:
					c = col.darkened(0.25)          # la punta, mas roja
				elif u <= 0.5 and (x == 7 or x == 8):
					c = NUCLEO.lerp(col, 0.25 * (1.0 - fuerza))   # el nucleo casi blanco
				img.set_pixel(x, y, c)

	for i in LADO:
		img.set_pixel(i, 0, MARCO)
		img.set_pixel(i, LADO - 1, MARCO)
		img.set_pixel(0, i, MARCO)
		img.set_pixel(LADO - 1, i, MARCO)
	return img
