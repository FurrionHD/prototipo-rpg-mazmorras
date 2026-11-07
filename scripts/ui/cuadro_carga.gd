# ============================================================
#  cuadro_carga.gd
#  LA MOCHILA del HUD, a la derecha de las columnas del grupo: un deposito que se LLENA de abajo
#  arriba segun lo cargado que vas, con el agua meciendose.
#
#  Antes era un ColorRect plano que solo cambiaba de color: decia "vas cargado" pero no CUANTO, y
#  habia que traducir el color a un numero en la cabeza. Un nivel se lee de un vistazo y sin pensar,
#  que es justo lo que tiene que hacer algo que miras de reojo mientras andas.
#
#  EN PIXEL (07/11, playtest del .exe: "esto no tiene pixel art"): era un poligono con lineas suavizadas. Ahora se pinta
#  en una rejilla de LADO x LADO (16: a 64 px de HUD, cada pixel del dibujo son 4 de pantalla, como las siluetas de
#  equipo de al lado) y se amplia sin suavizar. El agua sube por columnas enteras, con la cresta un tono mas clara y el
#  costado derecho un tono mas oscuro; y se mece A SALTOS (PASOS_SEG), como cualquier animacion de pixel.
#
#  El color lo pone Game.color_carga (blanco vacio -> amarillo -> naranja al empezar a ir lento ->
#  rojo lleno -> rojo oscuro a tope), asi que los escalones son los MISMOS del balance de sobrepeso.
# ============================================================

extends Control
class_name CuadroCarga

const LADO := 16
const PASOS_SEG := 8.0       # fotogramas por segundo del vaiven
# La superficie son DOS ondas con velocidades y largos distintos sumadas: con una sola se ve el patron repetirse. Largas y
# de un pixel como mucho: mas cortas o mas altas, cada columna redondea a su aire y la superficie sale dentada (hierba).
const ONDA1_LARGO := 11.0    # pixeles del dibujo de cresta a cresta
const ONDA1_VEL := 1.7       # rad/s
const ONDA2_LARGO := 6.0
const ONDA2_VEL := -2.6
const FONDO := Color(0.10, 0.11, 0.14, 0.85)
const MARCO := Color(0.75, 0.78, 0.85, 0.9)

# Lo que se pinta. Lo refresca el HUD cada frame (ver hud._process), que es quien sabe de Game.
var ratio: float = 0.0

var _img: Image = null
var _tex: ImageTexture = null
var _firma: String = ""


func _ready() -> void:
	# La mochila no se pulsa: es un indicador. Y con el raton encima, el numero exacto.
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(_delta: float) -> void:
	# Solo se repinta cuando cambia el fotograma (8 por segundo) o el nivel: barato.
	var paso: int = int(float(Time.get_ticks_msec()) / 1000.0 * PASOS_SEG)
	var firma: String = "%d|%.3f" % [paso, ratio]
	if firma == _firma:
		return
	_firma = firma
	_img = imagen(ratio, Game.color_carga(ratio), float(paso) / PASOS_SEG, _img)
	if _tex == null:
		_tex = ImageTexture.create_from_image(_img)
	else:
		_tex.update(_img)
	queue_redraw()


func _draw() -> void:
	if _tex != null:
		draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)


# EL DIBUJO, LADO x LADO. Estatico para poder sacarlo en una lamina sin juego (tools/lamina_cuadros_hud.gd).
# 'col' es el color del agua; 't' el tiempo YA ESCALONADO.
static func imagen(r: float, col: Color, t: float, img: Image = null) -> Image:
	if img == null:
		img = Image.create(LADO, LADO, false, Image.FORMAT_RGBA8)
	img.fill(FONDO)
	var dentro: int = LADO - 2                        # lo que cabe entre el marco
	var lleno: float = clampf(r, 0.0, 1.0)
	if lleno > 0.001:
		var base: float = float(dentro) * lleno       # filas de agua (sin ola)
		# Un vaso a rebosar no chapotea y uno casi vacio no tiene nada que mecer.
		var amortigua: float = clampf(minf(base, float(dentro) - base) / 2.0, 0.0, 1.0)
		var cresta: Color = col.lerp(Color.WHITE, 0.35)
		var sombra: Color = col.darkened(0.22)
		for x in dentro:
			var ola: float = sin(float(x) / ONDA1_LARGO * TAU + t * ONDA1_VEL) * 0.55 \
				+ sin(float(x) / ONDA2_LARGO * TAU + t * ONDA2_VEL) * 0.35
			var h: int = clampi(roundi(base + ola * amortigua), 1 if lleno > 0.0 else 0, dentro)
			for k in h:
				var y: int = LADO - 2 - k              # de abajo arriba
				var c: Color = col
				if k == h - 1 and h < dentro:
					c = cresta
				elif x >= dentro - 2 or k == 0:
					c = sombra                         # el costado derecho y el fondo: volumen
				img.set_pixel(x + 1, y, c)
	# El marco va AL FINAL, encima del agua, para que el vaso se vea entero.
	for i in LADO:
		img.set_pixel(i, 0, MARCO)
		img.set_pixel(i, LADO - 1, MARCO)
		img.set_pixel(0, i, MARCO)
		img.set_pixel(LADO - 1, i, MARCO)
	return img
