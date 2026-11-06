# ============================================================
#  medidor_faena.gd  (class_name MedidorFaena)
#  EL ESTILO DE LOS MEDIDORES DE LAS FAENAS (picar, talar, segar, extraer). Cada minijuego pinta su
#  propia mecanica, pero el marco, el carril, las marcas y los textos salen de aqui: son cuatro
#  medidores que se ven uno detras de otro y tienen que parecer de la misma familia.
#
#  Van AL LADO DEL PERSONAJE, sobre el mapa (ver faena.gd): por eso son pequeños y translucidos -- el
#  que manda es el muñeco dando golpes, el medidor solo dice cuando soltar. Bordes duros y sin
#  redondear, como el resto del pixel-art del juego.
# ============================================================

extends RefCounted
class_name MedidorFaena

# EL CARRIL ES LARGO A PROPOSITO (300 px). La dificultad EN TIEMPO no depende de lo que mida -- el
# marcador recorre la barra entera en los mismos segundos y la zona es la misma FRACCION --, pero lo
# que se VE si: cuando todo era una pantalla, la barra media ~770 px y una zona del 5% (reto muy alto)
# eran 38 px; con un carril de 176 se quedaba en 9 y en un movil no se veia (lo aviso el jefe). Con 300
# son 15, y en tactil el medidor entero va ademas un 30% mas grande (ver ESCALA_TACTIL).
const ANCHO := 124.0
const ALTO := 420.0
const CARRIL := Rect2(47.0, 34.0, 30.0, 300.0)
# Donde van las filas de marcas (progreso, fallos, extra) y la linea de estado, bajo el carril.
const Y_MARCAS := 346.0
const Y_MARCAS_2 := 360.0
const Y_MARCAS_3 := 373.0
const Y_ESTADO := 404.0
const ESCALA_TACTIL := 1.3

const FONDO := Color(0.05, 0.06, 0.08, 0.80)
const BORDE := Color(0.62, 0.55, 0.42, 0.95)
const BORDE_LUZ := Color(1.0, 0.92, 0.72, 0.18)
const COLOR_CARRIL := Color(0.14, 0.13, 0.13, 0.95)
const TEXTO := Color(0.93, 0.90, 0.84)
const TEXTO_SUAVE := Color(0.70, 0.68, 0.64)
const AMBAR := Color(0.95, 0.70, 0.22)
const ROJO := Color(0.86, 0.30, 0.22)
const AZUL := Color(0.42, 0.76, 0.96)


# (06/11, rework visual a pixel) LAS PIEZAS EN PIXEL, las del HUD (CajaPixel): marco de hierro con remaches, carril
# HUNDIDO (sombra arriba e izquierda, luz abajo y derecha), zonas con su franja de luz y de sombra, un marcador con
# contorno y puntas, y las marcas como gemas. Todo a pixeles de P, sin lineas finas ni medios pixeles.
const P := 2.0
const CajaPixel = preload("res://scripts/ui/caja_pixel.gd")
const CONTORNO := Color(0.04, 0.04, 0.05)
static var _caja: StyleBox = null


# El marco: el panel de hierro del HUD, con el fondo algo translucido (va encima del mapa, al lado del muñeco).
static func panel(ci: CanvasItem, r: Rect2) -> void:
	if _caja == null:
		_caja = CajaPixel.new()
		_caja.fondo = FONDO
	_caja.draw(ci.get_canvas_item(), Rect2(r.position.round(), r.size.round()))


# El carril vacio por donde corre la mecanica: un canal hundido en el hierro.
static func carril(ci: CanvasItem, r: Rect2, fondo: Color = COLOR_CARRIL) -> void:
	r = Rect2(r.position.round(), r.size.round())
	var f := r.grow(P)
	ci.draw_rect(Rect2(f.position + Vector2(P, 0), Vector2(f.size.x - 2.0 * P, f.size.y)), CONTORNO)
	ci.draw_rect(Rect2(f.position + Vector2(0, P), Vector2(f.size.x, f.size.y - 2.0 * P)), CONTORNO)
	ci.draw_rect(r, fondo)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, P)), fondo.darkened(0.45))
	ci.draw_rect(Rect2(r.position, Vector2(P, r.size.y)), fondo.darkened(0.45))
	ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - P), Vector2(r.size.x, P)), fondo.lightened(0.10))
	ci.draw_rect(Rect2(r.position + Vector2(r.size.x - P, 0), Vector2(P, r.size.y)), fondo.lightened(0.10))


# Una ZONA dentro del carril (la franja buena, la ventana...): su color, luz arriba, sombra abajo y una raya oscura que
# la separa del carril por arriba y por abajo.
static func zona(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var y0: float = roundf(r.position.y / P) * P
	var y1: float = roundf(r.end.y / P) * P
	r = Rect2(roundf(r.position.x), y0, roundf(r.size.x), y1 - y0)
	if r.size.y <= 0.0:
		return
	ci.draw_rect(r, col)
	if r.size.y >= 4.0 * P:
		ci.draw_rect(Rect2(r.position + Vector2(0, P), Vector2(r.size.x, P)), col.lightened(0.35))
		ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 2.0 * P), Vector2(r.size.x, P)), col.darkened(0.30))
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, P)), col.darkened(0.55))
	ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - P), Vector2(r.size.x, P)), col.darkened(0.55))


# EL MARCADOR que corre (o la raya fija): una barra que sobresale del carril, con contorno y las PUNTAS hacia dentro,
# para que se lea en movimiento sobre cualquier color.
static func marcador(ci: CanvasItem, cr: Rect2, y: float, col: Color = Color.WHITE) -> void:
	y = roundf(y / P) * P
	var x0: float = roundf(cr.position.x) - 4.0 * P
	var w: float = roundf(cr.size.x) + 8.0 * P
	ci.draw_rect(Rect2(x0, y - 2.0 * P, w, 4.0 * P), CONTORNO)
	ci.draw_rect(Rect2(x0 - P, y - P, P, 2.0 * P), CONTORNO)
	ci.draw_rect(Rect2(x0 + w, y - P, P, 2.0 * P), CONTORNO)
	ci.draw_rect(Rect2(x0 + P, y - P, w - 2.0 * P, 2.0 * P), col)
	ci.draw_rect(Rect2(x0 + P, y - P, w - 2.0 * P, P), col.lightened(0.5))
	# las puntas: un pixel mas alto en cada extremo, hacia fuera
	ci.draw_rect(Rect2(x0, y - P, P, 2.0 * P), col.darkened(0.15))
	ci.draw_rect(Rect2(x0 + w - P, y - P, P, 2.0 * P), col.darkened(0.15))


# Texto centrado en un ancho, con contorno para que se lea sobre cualquier suelo. Si no cabe, se
# encoge hasta 9 px en vez de salirse del marco (hay minerales con nombre largo).
static func texto(ci: CanvasItem, y: float, x: float, ancho: float, txt: String, tam: int = 12,
		color: Color = TEXTO) -> void:
	var font: Font = ThemeDB.fallback_font
	var t: int = tam
	# Sin pisar el marco de hierro (CajaPixel, ~12 px por lado): se mide contra el hueco de DENTRO.
	var cabe: float = ancho - 16.0
	while t > 9 and font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, t).x > cabe:
		t -= 1
	var pos := Vector2(x, y).round()
	ci.draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, ancho, t, 3, Color(0, 0, 0, 0.9))
	ci.draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, ancho, t, color)


# Una fila de marcas centrada: 'llenos' de 'total' encendidas, como GEMAS de pixel (contorno con las esquinas cortadas,
# luz arriba a la izquierda, sombra abajo); las apagadas, un hueco hundido. Para los golpes, las grietas, los fallos...
static func marcas(ci: CanvasItem, centro_x: float, y: float, total: int, llenos: int,
		lleno: Color, lado: float = 8.0) -> void:
	if total <= 0:
		return
	lado = maxf(roundf(lado / P) * P, 2.0 * P)
	var hueco: float = P * 2.0
	var ancho_fila: float = float(total) * lado + float(total - 1) * hueco
	var x0: float = roundf((centro_x - ancho_fila * 0.5) / P) * P
	y = roundf(y)
	for i in total:
		var r := Rect2(x0 + float(i) * (lado + hueco), y, lado, lado)
		var f := r.grow(P)
		ci.draw_rect(Rect2(f.position + Vector2(P, 0), Vector2(f.size.x - 2.0 * P, f.size.y)), CONTORNO)
		ci.draw_rect(Rect2(f.position + Vector2(0, P), Vector2(f.size.x, f.size.y - 2.0 * P)), CONTORNO)
		if i < llenos:
			ci.draw_rect(r, lleno)
			ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - P), Vector2(r.size.x, P)), lleno.darkened(0.35))
			ci.draw_rect(Rect2(r.position, Vector2(P, P)), lleno.lightened(0.6))
			if lado >= 3.0 * P:
				ci.draw_rect(Rect2(r.position + Vector2(P, 0), Vector2(P, P)), lleno.lightened(0.3))
				ci.draw_rect(Rect2(r.position + Vector2(0, P), Vector2(P, P)), lleno.lightened(0.3))
		else:
			ci.draw_rect(r, Color(0.16, 0.15, 0.15))
			ci.draw_rect(Rect2(r.position, Vector2(r.size.x, P)), Color(0.09, 0.09, 0.10))
