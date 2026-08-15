# ============================================================
#  capa_estado.gd  (class_name CapaEstado)
#  La PELICULA que cubre la tarjeta de un combatiente cuando algo se le ha pegado encima:
#  la baba del Pegajoso, el agua del Mojado.
#
#  Existe porque con particulas sueltas no basta. Unas motas verdes que centellean sobre el
#  recuadro se leen como "algo bueno le esta pasando" (de hecho el Pegajoso parecia una curacion);
#  lo que dice "estas cubierto de algo" es que HAYA ALGO CUBRIENDOTE: una capa que se te acumula
#  abajo y unos goterones colgando del borde de arriba. Las particulas (Particulas.chorretones)
#  van encima de esto y aportan el movimiento; esto aporta el "estar cubierto".
#
#  Se dibuja a mano en vez de con una textura porque la superficie ONDULA, y una baba quieta
#  parece pintura. Es un unico _draw con dos senos, no tiene mas misterio.
# ============================================================

extends Control
class_name CapaEstado

const ALTO_POZO := 0.30    # que fraccion de la tarjeta ocupa la baba acumulada abajo
const N_GOTERONES := 3

var color: Color = Color.TRANSPARENT
var intensidad: float = 0.0   # 0 = nada que pintar

var _t := 0.0
var _semilla := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# OBLIGATORIO: en solitario el arbol del juego esta pausado durante el combate.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_semilla = randf() * TAU


# La pinta de la capa. 'intensidad' 0 la apaga (y entonces deja de repintarse: una pelea con
# nadie pringado no gasta ni un frame en esto).
func pintar(col: Color, fuerza: float) -> void:
	color = col
	intensidad = clampf(fuerza, 0.0, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	if intensidad <= 0.0:
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	if intensidad <= 0.0 or size.x <= 1.0 or size.y <= 1.0:
		return
	var col := Color(color.r, color.g, color.b, 0.42 * intensidad)
	var claro := Color(minf(1.0, color.r + 0.35), minf(1.0, color.g + 0.35),
		minf(1.0, color.b + 0.35), 0.75 * intensidad)

	# EL POZO: lo que se te ha ido acumulando abajo, con la superficie ondulando despacio.
	var techo: float = size.y * (1.0 - ALTO_POZO)
	var pts := PackedVector2Array()
	var n := 12
	for i in n + 1:
		var u: float = float(i) / float(n)
		var x: float = u * size.x
		# Dos senos de periodos distintos: uno solo se lee como una sabana, no como un liquido.
		var y: float = techo + sin(_t * 1.6 + u * 6.0 + _semilla) * 3.0 \
			+ sin(_t * 2.7 + u * 11.0) * 1.6
		pts.append(Vector2(x, y))
	pts.append(Vector2(size.x, size.y))
	pts.append(Vector2(0.0, size.y))
	draw_colored_polygon(pts, col)
	# El BRILLO de la superficie: la misma linea de arriba, mas clara. Es lo que la separa de ser
	# un rectangulo translucido y la convierte en algo mojado.
	var sup := PackedVector2Array()
	for i in n + 1:
		sup.append(pts[i])
	draw_polyline(sup, claro, 2.0, true)

	# LOS GOTERONES que cuelgan del borde de arriba, cada uno a su ritmo: es lo que dice que la
	# cosa sigue cayendo y no es una mancha pintada.
	for k in N_GOTERONES:
		var f: float = float(k + 1) / float(N_GOTERONES + 1)
		var x2: float = size.x * f
		var largo: float = size.y * 0.16 * (0.6 + 0.4 * sin(_t * 1.3 + float(k) * 2.1 + _semilla))
		var ancho: float = 3.5 + 1.5 * sin(_t * 2.0 + float(k))
		draw_line(Vector2(x2, 0.0), Vector2(x2, largo), col, ancho * 2.0, true)
		# La gota del final, a punto de soltarse.
		draw_circle(Vector2(x2, largo), ancho, col)
