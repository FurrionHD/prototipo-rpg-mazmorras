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

const N_GOTERONES := 3
const MAX_CAPAS := 2       # baba y agua a la vez; una tercera ya seria ruido
const RADIO_ESQ := 5.0     # el redondeo del marco de la tarjeta (ver _sb_bloque en combat.gd)
# DONDE va el corte de la Herida profunda, en fracciones de la tarjeta. A la derecha y algo alto,
# lejos del nombre y de las barras. Lo comparte CombatFX para nacer ahi las gotas de sangre.
const POS_RAJA := Vector2(0.8, 0.42)
const VEDIJAS := 3
const ALTO_VEDIJA := 26.0

# CAPAS INDEPENDIENTES, porque se pueden dar todas a la vez:
#   COLGAJOS  lo que te chorrea encima, colgando del borde de arriba. Admite VARIOS a la vez
#             (baba y agua), y cada uno cuelga de sitios distintos para que no se solapen.
var capas: Array[Color] = []
var color_niebla: Color = Color.TRANSPARENT
var niebla: float = 0.0
#   DIANA   te han señalado: un circulo en el centro que late. Siempre en el mismo sitio y siempre
#           igual, porque es un MARCADOR -- tiene que poder encontrarse sin buscarlo.
var color_diana: Color = Color.TRANSPARENT
var diana: float = 0.0
#   RAJA    un corte abierto, a la derecha de la tarjeta. De el gotea sangre (las gotas son
#           particulas aparte, ver POS_RAJA: nacen justo en el corte).
var color_raja: Color = Color.TRANSPARENT
var raja: float = 0.0

var _t := 0.0
var _semilla := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Nada de esta capa sale de la tarjeta: es lo que la CUBRE, no algo que emana de ella. Las
	# particulas van en otra capa aparte (fx_capa) y esas si desbordan, que es lo suyo para una
	# llama o una cruz que sube.
	clip_contents = true
	# OBLIGATORIO: en solitario el arbol del juego esta pausado durante el combate.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_semilla = randf() * TAU


# Los colores de TODO lo que te chorrea encima ahora mismo (baba, agua, o las dos). Lista vacia =
# nada que pintar, y entonces esto deja de repintarse: una pelea sin nadie pringado no gasta ni un
# frame aqui.
func pintar_capas(cols: Array) -> void:
	capas.clear()
	for c in cols:
		if capas.size() < MAX_CAPAS:
			capas.append(c)
	queue_redraw()


# El VELO que te tapa (Sigilo). Va aparte de la baba porque las dos pueden estar a la vez.
func pintar_niebla(col: Color, fuerza: float) -> void:
	color_niebla = col
	niebla = clampf(fuerza, 0.0, 1.0)
	queue_redraw()


# LA DIANA del marcado. Es un marcador, no un adorno: va SIEMPRE en el centro y SIEMPRE igual.
func pintar_diana(col: Color, fuerza: float) -> void:
	color_diana = col
	diana = clampf(fuerza, 0.0, 1.0)
	queue_redraw()


# EL CORTE de la Herida profunda.
func pintar_raja(col: Color, fuerza: float) -> void:
	color_raja = col
	raja = clampf(fuerza, 0.0, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	if capas.is_empty() and niebla <= 0.0 and diana <= 0.0 and raja <= 0.0:
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	if niebla > 0.0:
		_dibujar_niebla()
	if diana > 0.0:
		_dibujar_diana()
	if raja > 0.0:
		_dibujar_raja()
	for k in capas.size():
		_dibujar_colgajos(capas[k], k)


# LOS COLGAJOS que cuelgan del borde de arriba, cada uno a su ritmo. Ya NO hay charco abajo: se
# comia media tarjeta y tapaba la barra de vida, y con los cuelgues ya se entiende que te chorrea.
#
# 'ranura' desplaza el juego entero un poco a la derecha, para que la baba y el agua NO caigan
# exactamente de los mismos tres puntos: si coinciden se solapan y se ve un solo colgajo de color
# raro en vez de dos cosas distintas.
func _dibujar_colgajos(col_base: Color, ranura: int) -> void:
	var col := Color(col_base.r, col_base.g, col_base.b, 0.5)
	var desfase: float = float(ranura) * 0.11
	for k in N_GOTERONES:
		var f: float = float(k + 1) / float(N_GOTERONES + 1) + desfase
		if f <= 0.04 or f >= 0.96:
			continue
		var x: float = size.x * f
		var fase: float = float(k) * 2.1 + float(ranura) * 1.7 + _semilla
		var largo: float = size.y * 0.16 * (0.6 + 0.4 * sin(_t * 1.3 + fase))
		var ancho: float = 3.5 + 1.5 * sin(_t * 2.0 + fase)
		draw_line(Vector2(x, 0.0), Vector2(x, largo), col, ancho * 2.0, true)
		# La gota del final, a punto de soltarse.
		draw_circle(Vector2(x, largo), ancho, col)


# EL VELO. Un manto que cubre la tarjeta entera mas unas vedijas que la cruzan despacio. La gracia
# es que TAPA: al que esta en sigilo cuesta mas leerlo, que es exactamente lo que dice el estado.
#
# Las vedijas son bandas anchas y muy transparentes que se solapan. No hay desenfoque de verdad
# (seria un shader y esto es un _draw), pero tres bandas translucidas cruzandose a distinta
# velocidad se leen como niebla igual.
func _dibujar_niebla() -> void:
	# El manto sigue la forma de la TARJETA (esquinas redondeadas como su marco): un rectangulo a
	# escuadra encima de una caja redondeada canta muchisimo, y ademas se derramaba por los bordes.
	var base := Color(color_niebla.r, color_niebla.g, color_niebla.b, 0.20 * niebla)
	draw_colored_polygon(_contorno(RADIO_ESQ), base)
	# Y las vedijas son bandas con las dos orillas ONDULADAS, no rectangulos: es lo mismo que hace
	# la superficie de la baba, que es justo lo que se lee bien.
	for k in VEDIJAS:
		var f: float = float(k)
		var recorrido: float = size.y + ALTO_VEDIJA
		var y: float = fmod(_t * (6.0 + f * 3.0) + f * size.y * 0.5 + _semilla * 9.0, recorrido) \
			- ALTO_VEDIJA * 0.5
		_vedija(y, ALTO_VEDIJA * (0.8 + 0.25 * f), f * 2.3 + _t * 1.1,
			Color(1.0, 1.0, 1.0, (0.085 - 0.018 * f) * niebla))


# LA DIANA: dos anillos y un punto, en el centro de la tarjeta, latiendo despacio. Va TODA en
# transparencias: es un aviso, y un aviso que tapa la vida del bicho estorba mas de lo que informa.
func _dibujar_diana() -> void:
	var c: Vector2 = size * 0.5
	# El latido: entre el 90% y el 110% de su tamaño, sin prisa.
	var pulso: float = 1.0 + 0.1 * sin(_t * 3.4)
	var r: float = minf(size.x, size.y) * 0.28 * pulso
	var col := Color(color_diana.r, color_diana.g, color_diana.b, 0.55 * diana)
	draw_arc(c, r, 0.0, TAU, 28, col, 2.0, true)
	draw_arc(c, r * 0.55, 0.0, TAU, 20, col, 2.0, true)
	draw_circle(c, r * 0.16, col)
	# Las cuatro marcas de la cruz, cortitas, que es lo que la lee como una MIRA y no como un aro.
	var cruz := Color(color_diana.r, color_diana.g, color_diana.b, 0.4 * diana)
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(c + d * r * 1.02, c + d * r * 1.4, cruz, 2.0, true)


# EL CORTE. Una lente (dos arcos que se juntan en las puntas) inclinada, oscura por dentro y con
# los labios mas claros, en un sitio FIJO de la tarjeta. Late un poco, como si no cerrara.
# Las gotas que caen de aqui no se dibujan: son particulas, y nacen en este mismo punto.
func _dibujar_raja() -> void:
	var c: Vector2 = size * POS_RAJA
	var largo: float = minf(size.x, size.y) * 0.34
	# La abertura respira: un corte que no cierra se lee mucho mejor que una raya quieta.
	var ancho: float = largo * (0.22 + 0.05 * sin(_t * 2.6))
	var eje := Vector2(0.42, -0.91).normalized()   # inclinada, no vertical: parece un tajo
	var lado := Vector2(-eje.y, eje.x)
	var pts := PackedVector2Array()
	var n := 9
	# Labio de un lado y del otro, cerrando en las dos puntas.
	for i in n + 1:
		var u: float = lerpf(-1.0, 1.0, float(i) / float(n))
		pts.append(c + eje * u * largo * 0.5 + lado * (1.0 - u * u) * ancho)
	for i in n + 1:
		var u2: float = lerpf(1.0, -1.0, float(i) / float(n))
		pts.append(c + eje * u2 * largo * 0.5 - lado * (1.0 - u2 * u2) * ancho)
	draw_colored_polygon(pts, Color(color_raja.r * 0.35, color_raja.g * 0.15,
		color_raja.b * 0.15, 0.75 * raja))
	# Los LABIOS, mas claros: es lo que la lee como una herida abierta y no como una mancha.
	draw_polyline(pts, Color(minf(1.0, color_raja.r + 0.2), color_raja.g * 0.55,
		color_raja.b * 0.55, 0.8 * raja), 1.8, true)


# Una banda de niebla con las dos orillas onduladas. Se recorta a la caja por arriba y por abajo
# para que ninguna se salga de la tarjeta.
func _vedija(y0: float, alto: float, fase: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var u: float = float(i) / float(n)
		pts.append(Vector2(u * size.x,
			clampf(y0 + sin(u * 5.0 + fase) * 3.5, 0.0, size.y)))
	for i in n + 1:
		var u2: float = 1.0 - float(i) / float(n)
		pts.append(Vector2(u2 * size.x,
			clampf(y0 + alto + sin(u2 * 4.0 - fase * 1.3) * 4.0, 0.0, size.y)))
	draw_colored_polygon(pts, col)


# El contorno de la tarjeta con las esquinas redondeadas, como poligono.
func _contorno(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rr: float = minf(r, minf(size.x, size.y) * 0.5)
	# Las cuatro esquinas, en orden, cada una con su cuarto de arco.
	var centros := [
		[Vector2(size.x - rr, size.y - rr), 0.0],
		[Vector2(rr, size.y - rr), PI * 0.5],
		[Vector2(rr, rr), PI],
		[Vector2(size.x - rr, rr), PI * 1.5],
	]
	for c in centros:
		var centro: Vector2 = c[0]
		var a0: float = c[1]
		for i in 5:
			var a: float = a0 + PI * 0.5 * (float(i) / 4.0)
			pts.append(centro + Vector2(cos(a), sin(a)) * rr)
	return pts
