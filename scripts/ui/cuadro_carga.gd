# ============================================================
#  cuadro_carga.gd
#  LA MOCHILA del HUD, a la derecha de las columnas del grupo: un deposito que se LLENA de abajo
#  arriba segun lo cargado que vas, con el agua meciendose.
#
#  Antes era un ColorRect plano que solo cambiaba de color: decia "vas cargado" pero no CUANTO, y
#  habia que traducir el color a un numero en la cabeza. Un nivel se lee de un vistazo y sin pensar,
#  que es justo lo que tiene que hacer algo que miras de reojo mientras andas.
#
#  El color lo pone Game.color_carga (blanco vacio -> amarillo -> naranja al empezar a ir lento ->
#  rojo lleno -> rojo oscuro a tope), asi que los escalones son los MISMOS del balance de sobrepeso.
# ============================================================

extends Control
class_name CuadroCarga

# La superficie no es una onda, son DOS con velocidades y longitudes distintas sumadas. Con una sola
# se ve el patron repetirse y canta que es un seno; con dos, el ojo no le pilla el ritmo y lee agua.
const ONDA1_ALTO := 2.2      # px de sube y baja
const ONDA1_LARGO := 26.0    # px de una cresta a la otra
const ONDA1_VEL := 1.7       # rad/s
const ONDA2_ALTO := 1.4
const ONDA2_LARGO := 15.0
const ONDA2_VEL := -2.6      # al reves: por eso las dos no viajan juntas
# Cada cuantos px se parte la superficie para dibujarla. Mas fino no se nota y son mas puntos.
const PASO := 3.0

# Lo que se pinta. Lo refresca el HUD cada frame (ver hud._process), que es quien sabe de Game.
var ratio: float = 0.0


func _ready() -> void:
	# La mochila no se pulsa: es un indicador. Y con el raton encima, el numero exacto.
	mouse_filter = Control.MOUSE_FILTER_PASS


func _process(_delta: float) -> void:
	queue_redraw()   # el agua se mueve sola: un Control pequeño repintandose, barato


func _draw() -> void:
	var ancho: float = size.x
	var alto: float = size.y
	# EL VASO: fondo oscuro y borde, para que el nivel se lea contra algo aunque el agua vaya blanca
	# sobre una pared clara.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.11, 0.14, 0.85), true)

	# El NIVEL llega al borde al 100%. Por encima ya no sube (no hay mas vaso): lo que sigue
	# contando de ahi en adelante es el COLOR, que se va a rojo oscuro.
	var lleno: float = clampf(ratio, 0.0, 1.0)
	var col: Color = Game.color_carga(ratio)
	if lleno > 0.001:
		var y_base: float = alto * (1.0 - lleno)
		var t: float = float(Time.get_ticks_msec()) / 1000.0
		# El agua, como un poligono: la superficie ondulada por arriba y el fondo del vaso por abajo.
		var puntos: PackedVector2Array = PackedVector2Array()
		var x: float = 0.0
		while x < ancho:
			puntos.append(Vector2(x, _superficie(x, y_base, t, alto)))
			x += PASO
		puntos.append(Vector2(ancho, _superficie(ancho, y_base, t, alto)))
		puntos.append(Vector2(ancho, alto))
		puntos.append(Vector2(0.0, alto))
		draw_colored_polygon(puntos, col)
		# La CRESTA, un pelin mas clara: es lo que remata el efecto de superficie de agua.
		var brillo: Color = col.lerp(Color.WHITE, 0.35)
		brillo.a = 0.9
		var prev: Vector2 = puntos[0]
		for i in range(1, puntos.size() - 3):
			draw_line(prev, puntos[i], brillo, 1.5, true)
			prev = puntos[i]

	# El borde va AL FINAL, encima del agua, para que el vaso se vea entero.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.75, 0.78, 0.85, 0.9), false, 1.0)


# La altura de la superficie en esa x. Las dos ondas se aplanan segun el vaso se llena o se vacia
# del todo: un vaso a rebosar no chapotea, y uno vacio no tiene nada que mecer.
func _superficie(x: float, y_base: float, t: float, alto: float) -> float:
	var margen: float = minf(y_base, alto - y_base)   # cuanto sitio hay para mecerse
	var amortigua: float = clampf(margen / 4.0, 0.0, 1.0)
	var y: float = y_base
	y += sin(x / ONDA1_LARGO * TAU + t * ONDA1_VEL) * ONDA1_ALTO * amortigua
	y += sin(x / ONDA2_LARGO * TAU + t * ONDA2_VEL) * ONDA2_ALTO * amortigua
	return clampf(y, 0.0, alto)
