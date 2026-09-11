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


# El marco: fondo translucido, borde de 2 px y un filo de luz por dentro.
static func panel(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, FONDO)
	ci.draw_rect(r, BORDE, false, 2.0)
	ci.draw_rect(r.grow(-3.0), BORDE_LUZ, false, 1.0)


# El carril vacio por donde corre la mecanica, con su borde oscuro.
static func carril(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r.grow(2.0), Color(0, 0, 0, 0.85))
	ci.draw_rect(r, COLOR_CARRIL)


# Texto centrado en un ancho, con contorno para que se lea sobre cualquier suelo. Si no cabe, se
# encoge hasta 9 px en vez de salirse del marco (hay minerales con nombre largo).
static func texto(ci: CanvasItem, y: float, x: float, ancho: float, txt: String, tam: int = 12,
		color: Color = TEXTO) -> void:
	var font: Font = ThemeDB.fallback_font
	var t: int = tam
	while t > 9 and font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, t).x > ancho:
		t -= 1
	var pos := Vector2(x, y)
	ci.draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, ancho, t, 3, Color(0, 0, 0, 0.9))
	ci.draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, ancho, t, color)


# Una fila de marcas cuadradas centrada: 'llenos' de 'total' encendidas. Para los golpes que faltan,
# las grietas, los fallos...
static func marcas(ci: CanvasItem, centro_x: float, y: float, total: int, llenos: int,
		lleno: Color, lado: float = 8.0) -> void:
	if total <= 0:
		return
	var hueco: float = 3.0
	var ancho_fila: float = float(total) * lado + float(total - 1) * hueco
	var x0: float = centro_x - ancho_fila * 0.5
	for i in total:
		var r := Rect2(x0 + float(i) * (lado + hueco), y, lado, lado)
		ci.draw_rect(r.grow(1.0), Color(0, 0, 0, 0.85))
		ci.draw_rect(r, lleno if i < llenos else Color(0.22, 0.21, 0.21))
		if i < llenos:
			ci.draw_rect(Rect2(r.position, Vector2(lado, 2.0)), Color(1, 1, 1, 0.35))
