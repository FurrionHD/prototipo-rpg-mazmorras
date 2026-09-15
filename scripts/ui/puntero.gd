# ============================================================
#  puntero.gd  (Puntero)
#  EL PUNTERO DEL RATON del juego: una MANO SEÑALANDO con el indice (cambio del usuario, 15/09/2026: pega con
#  la mano AGARRANDO que sale al arrastrar). Mas abajo sigue la PLUMA, que fue el primero y ya no se pone:
#  una pluma pixel-art con el vano en tonos
#  pizarra, el calamo claro y contorno negro. Apunta con la punta del calamo, abajo a la izquierda, como quien
#  escribe. Se dibuja por codigo a partir de su forma (un eje en diagonal, un vano que se ensancha y se afila,
#  dientes en el borde) y se escala a pixel entero. Se pone al arrancar (Tactil._ready) salvo en movil.
#
#  Solo se decide por "mobile" y no por Tactil.activo a proposito: el editor lanza el juego con --tactil
#  para probar los mandos, y con eso el puntero no se veria nunca al probar en el PC.
# ============================================================
class_name Puntero
extends RefCounted

const LADO := 22                                   # el dibujo, en pixeles
const ESCALA := 2                                  # pixeles de pantalla por pixel del dibujo
const PUNTA := Vector2(1.5, 20.5)                  # donde acaba el calamo (el punto que apunta)
const CIMA := Vector2(20.5, 1.5)                   # la punta de arriba de la pluma
const DESNUDO := 0.16                              # tramo del eje sin barbas, desde la punta
const CURVA := -1.6                                # cuanto se arquea el eje (negativo: la cima cae hacia la derecha)

const CONTORNO := Color(0.05, 0.05, 0.07)
const OSCURO := Color(0.25, 0.27, 0.37)
const MEDIO := Color(0.38, 0.40, 0.53)
const CLARO := Color(0.52, 0.54, 0.68)
const CALAMO := Color(0.88, 0.86, 0.79)


# Ancho del vano a cada altura del eje (t de 0 en la punta a 1 arriba), a cada lado. El de arriba-izquierda es
# el ancho (el que da la cara); el otro, mucho mas estrecho, como en una pluma de verdad.
static func _ancho(t: float, lado_ancho: bool) -> float:
	if t < DESNUDO:
		return 0.0
	var u: float = (t - DESNUDO) / (1.0 - DESNUDO)
	var forma: float = sin(pow(u, 0.6) * PI)        # crece rapido y se afila despacio hacia la cima
	# LOS DIENTES: el borde va en SIERRA, cada mechon de barbas sube hacia la cima y cae de golpe al siguiente,
	# que es lo que hace que se lea como pluma y no como hoja. Mas hondos en la cara ancha.
	if lado_ancho:
		var sierra: float = fmod(u * 4.5, 1.0) * 2.4 if u > 0.1 and u < 0.9 else 0.0
		return maxf(0.0, 5.6 * forma - sierra)
	var sierra_e: float = fmod(u * 6.0 + 0.4, 1.0) * 1.1 if u > 0.15 and u < 0.85 else 0.0
	return maxf(0.0, 2.4 * forma - sierra_e)


static func imagen(escala: int = ESCALA) -> Image:
	var img := Image.create(LADO, LADO, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var eje: Vector2 = CIMA - PUNTA
	var largo: float = eje.length()
	var dir: Vector2 = eje / largo
	var normal := Vector2(dir.y, -dir.x)              # hacia arriba-izquierda: ahi va la cara ancha
	var lleno: Dictionary = {}
	for y in LADO:
		for x in LADO:
			var p := Vector2(x + 0.5, y + 0.5) - PUNTA
			var t: float = p.dot(dir) / largo
			if t < -0.02 or t > 1.0:
				continue
			# Distancia al EJE CURVADO: el centro de la pluma se desplaza por la normal segun la altura.
			var d: float = p.dot(normal) - CURVA * sin(PI * clampf(t, 0.0, 1.0))
			var ancho_a: float = _ancho(t, true)
			var col := Color(0, 0, 0, 0)
			if absf(d) <= 0.55 and t <= 0.86:
				col = CALAMO                          # el eje (desnudo abajo, entre las barbas arriba)
			elif d > 0.0 and d <= ancho_a:
				# Cara ancha: media junto al eje, clara en el cuerpo y oscura en el filo.
				col = MEDIO if d < 1.2 else (OSCURO if d > ancho_a - 1.0 else CLARO)
				# LA SEPARACION entre mechones: una raya oscura en diagonal (hacia la cima segun se aleja del eje)
				# que sale de cada caida de la sierra. Es lo que parte el vano en barbas como en el ejemplo.
				var u_s: float = (t - DESNUDO) / (1.0 - DESNUDO) - d * 0.035
				if u_s > 0.1 and u_s < 0.9 and d > 1.0 and fmod(u_s * 4.5, 1.0) > 0.9:
					col = OSCURO
			elif d < 0.0 and -d <= _ancho(t, false):
				col = OSCURO                          # la cara estrecha va en sombra
			if col.a > 0.0:
				img.set_pixel(x, y, col)
				lleno[Vector2i(x, y)] = true
	# EL CONTORNO: todo hueco que toque (en cruz) algo pintado.
	var borde: Array = []
	for y in LADO:
		for x in LADO:
			if lleno.has(Vector2i(x, y)):
				continue
			for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if lleno.has(Vector2i(x, y) + v):
					borde.append(Vector2i(x, y))
					break
	for c in borde:
		img.set_pixel(c.x, c.y, CONTORNO)
	if escala > 1:
		img.resize(LADO * escala, LADO * escala, Image.INTERPOLATE_NEAREST)
	return img


# El punto que apunta, en pixeles de la textura escalada: la punta del calamo.
static func punto_caliente(escala: int = ESCALA) -> Vector2:
	return (PUNTA - Vector2(0.5, 0.5)) * float(escala)


static func aplicar() -> void:
	if OS.has_feature("mobile") or DisplayServer.get_name() == "headless":
		return
	var tex := ImageTexture.create_from_image(imagen_indice())
	# La misma mano tambien sobre botones y enlaces (donde Godot pasaria a la mano del sistema).
	for forma in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND]:
		Input.set_custom_mouse_cursor(tex, forma, punto_caliente_indice())
	# ARRASTRANDO (el editor de equipo, los objetos del cofre): una MANO AGARRANDO. Son las tres formas que
	# pone Godot durante un arrastre -- arrastrar, "se puede soltar aqui" y "aqui no" --, y sin esto salian
	# las de Windows. Las tres la MISMA mano a proposito: el usuario no quiere el "prohibido" al pasar por
	# un sitio donde no se suelta, solo que el puntero no cambie.
	var mano := ImageTexture.create_from_image(imagen_mano())
	for forma in [Input.CURSOR_DRAG, Input.CURSOR_CAN_DROP, Input.CURSOR_FORBIDDEN]:
		Input.set_custom_mouse_cursor(mano, forma, punto_caliente_mano())


# LA MANO AGARRANDO, en el mismo pixel-art que la pluma: puño cerrado visto de frente, con los nudillos
# arriba y el pulgar por delante. '#' contorno, 'o' piel (el mismo claro del calamo), 's' sombra.
const MANO := [
	"................",
	"....##.##.##....",
	"...#oo#oo#oo#...",
	"..##oo#oo#oo##..",
	".#oo#oooooo#oo#.",
	".#ooooooooooso#.",
	".#oosooooooooo#.",
	".#oooossoooooo#.",
	"..#ooooosssooo#.",
	"..#ooooooooos#..",
	"...#ooooooooo#..",
	"...#oooooooo#...",
	"....#ooooooo#...",
	"....#osssoos#...",
	"....#########...",
	"................",
]
const PIEL_SOMBRA := Color(0.70, 0.66, 0.58)

# LA MANO SEÑALANDO, TORCIDA (como la referencia del usuario, no recta hacia arriba): el indice sale en
# diagonal hacia arriba a la izquierda y apunta con la yema; el puño queda abajo a la derecha, con el
# pulgar asomando. Mismo contorno, piel y sombra que la de agarrar.
const MANO_INDICE := [
	".##...............",
	"#oo#..............",
	"#ooo#.............",
	".#ooo#............",
	"..#ooo#...........",
	"...#ooo#.##.##....",
	"....#ooo#oo#oo##..",
	"....#oooooooooos#.",
	"...##ooooooooooo#.",
	"..#oo#oooooooooo#.",
	"..#ooooooooooooo#.",
	"..#oooooooooooos#.",
	"...#ooooooooooos#.",
	"....#oooooooooss#.",
	".....#ooooooosss#.",
	"......##########..",
]

static func imagen_indice(escala: int = ESCALA) -> Image:
	return _imagen_de_mapa(MANO_INDICE, escala)


# Apunta con la YEMA del indice.
static func punto_caliente_indice(escala: int = ESCALA) -> Vector2:
	return Vector2(1.5, 1.5) * float(escala)


static func imagen_mano(escala: int = ESCALA) -> Image:
	return _imagen_de_mapa(MANO, escala)


# Pinta un dibujo hecho de letras ('#' contorno, 'o' piel, 's' sombra) y lo escala a pixel entero.
static func _imagen_de_mapa(mapa: Array, escala: int) -> Image:
	var alto: int = mapa.size()
	var ancho: int = String(mapa[0]).length()
	var img := Image.create(ancho, alto, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in alto:
		var fila: String = mapa[y]
		for x in ancho:
			match fila[x]:
				"#": img.set_pixel(x, y, CONTORNO)
				"o": img.set_pixel(x, y, CALAMO)
				"s": img.set_pixel(x, y, PIEL_SOMBRA)
	if escala > 1:
		img.resize(ancho * escala, alto * escala, Image.INTERPOLATE_NEAREST)
	return img


# La mano agarra por el CENTRO: lo que arrastras va cogido ahi.
static func punto_caliente_mano(escala: int = ESCALA) -> Vector2:
	return Vector2(8.0, 8.0) * float(escala)
