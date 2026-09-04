# ============================================================
#  iconos.gd
#  Los iconos de la botonera tactil, DIBUJADOS con primitivas.
#
#  Y no con emoji a proposito: el proyecto no lleva ninguna fuente con emoji, asi que un 🎒 sale
#  segun lo que tenga el aparato debajo. En Windows puede verse y en el movil salir un cuadrado, y
#  eso no se descubre hasta tener el APK en la mano. Dibujados se ven igual en los dos sitios.
#
#  Todas las funciones pintan dentro de una CAJA CUADRADA que se les pasa (pos + lado), en las
#  coordenadas locales del CanvasItem que llama. Asi el mismo icono sirve a cualquier tamaño y el
#  boton no tiene que saber como esta hecho por dentro.
#
#  Cuando llegue el arte de verdad (ver la nota de la UI placeholder), esto se cambia por texturas
#  y los botones no se enteran: solo se les cambia la llamada de _draw.
# ============================================================

class_name Iconos


# --- PERSONA (menu de personaje): cabeza y hombros ---
static func persona(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	var g: float = lado * 0.09   # grosor comun del trazo
	var cx: float = pos.x + lado * 0.5
	# La cabeza, un pelin por encima del centro para dejar sitio a los hombros.
	var r_cabeza: float = lado * 0.17
	c.draw_arc(Vector2(cx, pos.y + lado * 0.30), r_cabeza, 0.0, TAU, 24, col, g, true)
	# Los hombros: medio arco abierto hacia abajo, que es lo que lee como "torso" sin dibujarlo.
	c.draw_arc(Vector2(cx, pos.y + lado * 0.92), lado * 0.30, PI, TAU, 24, col, g, true)


# --- MOCHILA (bolsa/inventario): cuerpo, solapa y tirantes ---
static func mochila(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	var g: float = lado * 0.08
	# Los tirantes van PRIMERO para que el cuerpo los tape por delante, como en una mochila de verdad.
	c.draw_arc(Vector2(pos.x + lado * 0.36, pos.y + lado * 0.30), lado * 0.12, PI, TAU, 16, col, g, true)
	c.draw_arc(Vector2(pos.x + lado * 0.64, pos.y + lado * 0.30), lado * 0.12, PI, TAU, 16, col, g, true)
	# El cuerpo.
	var cuerpo := Rect2(pos.x + lado * 0.20, pos.y + lado * 0.30, lado * 0.60, lado * 0.55)
	c.draw_rect(cuerpo, col, false, g)
	# La solapa: una raya cruzada a un tercio, y el cierre debajo.
	c.draw_line(Vector2(cuerpo.position.x, pos.y + lado * 0.52),
		Vector2(cuerpo.end.x, pos.y + lado * 0.52), col, g * 0.8, true)
	c.draw_rect(Rect2(pos.x + lado * 0.43, pos.y + lado * 0.56, lado * 0.14, lado * 0.10), col, true)


# --- PERGAMINO (mapa): la hoja, los dos rollos y las lineas de texto ---
static func pergamino(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	var g: float = lado * 0.08
	var izq: float = pos.x + lado * 0.20
	var der: float = pos.x + lado * 0.80
	var arriba: float = pos.y + lado * 0.26
	var abajo: float = pos.y + lado * 0.74
	# Los cantos de la hoja.
	c.draw_line(Vector2(izq, arriba), Vector2(izq, abajo), col, g * 0.7, true)
	c.draw_line(Vector2(der, arriba), Vector2(der, abajo), col, g * 0.7, true)
	# Los dos rollos, arriba y abajo, como capsulas tumbadas.
	_capsula(c, Vector2(izq, arriba), Vector2(der, arriba), lado * 0.09, col, g)
	_capsula(c, Vector2(izq, abajo), Vector2(der, abajo), lado * 0.09, col, g)
	# Tres rayas de "escrito", la de en medio mas corta para que no parezca una rejilla.
	var x0: float = izq + lado * 0.08
	for i in 3:
		var largo: float = (der - izq) - lado * 0.16
		if i == 1:
			largo *= 0.62
		var y: float = pos.y + lado * (0.42 + 0.10 * float(i))
		c.draw_line(Vector2(x0, y), Vector2(x0 + largo, y), col, g * 0.55, true)


# --- ENGRANAJE (pausa/opciones): corona de dientes y agujero ---
static func engranaje(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	var g: float = lado * 0.08
	var centro := Vector2(pos.x + lado * 0.5, pos.y + lado * 0.5)
	var r: float = lado * 0.26
	c.draw_arc(centro, r, 0.0, TAU, 32, col, g, true)
	# Ocho dientes: un palo corto saliendo del borde, uno cada 45 grados.
	for i in 8:
		var ang: float = TAU * float(i) / 8.0
		var dir := Vector2(cos(ang), sin(ang))
		c.draw_line(centro + dir * (r + g * 0.2), centro + dir * (r + lado * 0.15), col, g, true)
	# El agujero del centro, que es lo que lo separa de "una rueda dentada cualquiera".
	c.draw_arc(centro, lado * 0.09, 0.0, TAU, 16, col, g * 0.8, true)


# --- MANO (interactuar): palma y cuatro dedos ---
static func mano(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	var g: float = lado * 0.09
	# La palma.
	var palma := Rect2(pos.x + lado * 0.28, pos.y + lado * 0.46, lado * 0.44, lado * 0.34)
	c.draw_rect(palma, col, false, g)
	# Los cuatro dedos, de distinta altura para que se lea como una mano y no como un peine.
	var altos := [0.20, 0.14, 0.16, 0.24]
	for i in 4:
		var x: float = pos.x + lado * (0.33 + 0.11 * float(i))
		var y: float = pos.y + lado * float(altos[i])
		c.draw_line(Vector2(x, y), Vector2(x, palma.position.y), col, g * 0.85, true)


# --- ESPADA (atacar): hoja, guarda y empuñadura, en diagonal ---
static func espada(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	var g: float = lado * 0.10
	var punta := pos + Vector2(lado * 0.80, lado * 0.16)
	var pomo := pos + Vector2(lado * 0.24, lado * 0.80)
	c.draw_line(punta, pomo, col, g, true)
	# La guarda, cruzada a la empuñadura y cerca del pomo.
	var guarda := pos + Vector2(lado * 0.36, lado * 0.66)
	var perp := Vector2(-1, -1).normalized() * (lado * 0.15)
	c.draw_line(guarda - perp, guarda + perp, col, g * 0.85, true)


# --- POCION (curacion): frasco con cuello y tapon ---
static func pocion(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	var g: float = lado * 0.09
	c.draw_rect(Rect2(pos.x + lado * 0.40, pos.y + lado * 0.14, lado * 0.20, lado * 0.10), col, true)
	# El cuello.
	c.draw_line(pos + Vector2(lado * 0.43, lado * 0.24), pos + Vector2(lado * 0.43, lado * 0.40),
		col, g * 0.8, true)
	c.draw_line(pos + Vector2(lado * 0.57, lado * 0.24), pos + Vector2(lado * 0.57, lado * 0.40),
		col, g * 0.8, true)
	# El cuerpo, redondo.
	c.draw_arc(pos + Vector2(lado * 0.5, lado * 0.60), lado * 0.22, 0.0, TAU, 28, col, g, true)
	# Y el liquido dentro, que es lo que lo distingue de un tarro vacio.
	c.draw_arc(pos + Vector2(lado * 0.5, lado * 0.66), lado * 0.11, 0.0, TAU, 20, col, g * 0.8, true)


# ============================================================
#  LAS PESTAÑAS DEL INVENTARIO
#  Van con icono y sin texto, como en los menus de referencia, asi que el dibujo tiene que decir
#  la seccion el solo. Los seis se eligieron para que no se parezcan entre si EN SILUETA: a este
#  tamaño el ojo separa un bulto redondo de uno anguloso mucho antes que dos objetos distintos.
#  El nombre de la seccion sale ademas escrito arriba a la izquierda, que es el otro medio camino.
# ============================================================

# --- BOLSA (lo que llevas de expedicion): zurron con su cordon ---
# Se distingue de la MOCHILA en que no tiene tirantes: la mochila es la pieza de equipo que sube la
# carga y la bolsa es el contenido, y con el mismo dibujo las dos pestañas se confundian.
static func bolsa(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	var g: float = lado * 0.09
	var cx: float = pos.x + lado * 0.5
	var r: float = lado * 0.28
	var cy: float = pos.y + lado * 0.58
	# LA PANZA: media circunferencia de ABAJO. Ojo con los angulos, que es donde se cayo la primera
	# version: en Godot 2D el 0 es hacia la derecha y el angulo crece HACIA ABAJO (la Y va al reves
	# que en matematicas), asi que el semicirculo de abajo es 0 -> PI. Con PI -> 2PI sale el de
	# arriba y el saco queda del reves, como una herradura.
	c.draw_arc(Vector2(cx, cy), r, 0.0, PI, 28, col, g, true)
	# Los costados, del final de la panza hasta la boca. Se estrechan un poco: es lo que lo hace
	# saco y no cubo.
	c.draw_line(Vector2(cx - r, cy), pos + Vector2(lado * 0.28, lado * 0.34), col, g, true)
	c.draw_line(Vector2(cx + r, cy), pos + Vector2(lado * 0.72, lado * 0.34), col, g, true)
	# La boca, fruncida por el cordon.
	c.draw_line(pos + Vector2(lado * 0.28, lado * 0.34), pos + Vector2(lado * 0.72, lado * 0.34),
		col, g, true)
	c.draw_line(pos + Vector2(lado * 0.38, lado * 0.20), pos + Vector2(lado * 0.62, lado * 0.20),
		col, g * 0.8, true)
	c.draw_line(pos + Vector2(lado * 0.38, lado * 0.20), pos + Vector2(lado * 0.30, lado * 0.34),
		col, g * 0.7, true)
	c.draw_line(pos + Vector2(lado * 0.62, lado * 0.20), pos + Vector2(lado * 0.70, lado * 0.34),
		col, g * 0.7, true)


# --- MATERIALES: un pedrusco con su veta ---
static func mineral(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	var g: float = lado * 0.09
	# Silueta angulosa, que es lo que la separa de la pocion y de la bolsa (las dos redondas).
	var p := PackedVector2Array([
		pos + Vector2(lado * 0.50, lado * 0.16), pos + Vector2(lado * 0.82, lado * 0.42),
		pos + Vector2(lado * 0.70, lado * 0.82), pos + Vector2(lado * 0.30, lado * 0.82),
		pos + Vector2(lado * 0.18, lado * 0.42),
	])
	var cerrado := PackedVector2Array(p)
	cerrado.append(p[0])
	c.draw_polyline(cerrado, col, g, true)
	# La veta de dentro: dos trazos desde el vertice de arriba, que es lo que lo hace mineral y no
	# un pentagono suelto.
	c.draw_line(p[0], pos + Vector2(lado * 0.38, lado * 0.55), col, g * 0.8, true)
	c.draw_line(pos + Vector2(lado * 0.38, lado * 0.55), pos + Vector2(lado * 0.60, lado * 0.80),
		col, g * 0.8, true)


# --- ARMADURAS: coraza (peto con hombreras) ---
static func coraza(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	var g: float = lado * 0.09
	var cx: float = pos.x + lado * 0.5
	# El peto: ancho de hombros arriba y en punta abajo, como un escudo pero con el cuello marcado.
	var p := PackedVector2Array([
		pos + Vector2(lado * 0.20, lado * 0.26), pos + Vector2(lado * 0.40, lado * 0.20),
		Vector2(cx, lado * 0.30 + pos.y), pos + Vector2(lado * 0.60, lado * 0.20),
		pos + Vector2(lado * 0.80, lado * 0.26), pos + Vector2(lado * 0.74, lado * 0.66),
		Vector2(cx, lado * 0.86 + pos.y), pos + Vector2(lado * 0.26, lado * 0.66),
	])
	var cerrado := PackedVector2Array(p)
	cerrado.append(p[0])
	c.draw_polyline(cerrado, col, g, true)
	# La linea del esternon: sin ella el peto se lee como un escudo a secas.
	c.draw_line(Vector2(cx, pos.y + lado * 0.36), Vector2(cx, pos.y + lado * 0.70), col, g * 0.7, true)


# --- HERRAMIENTAS: un pico ---
static func pico(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	var g: float = lado * 0.09
	# El mango, en diagonal.
	c.draw_line(pos + Vector2(lado * 0.68, lado * 0.20), pos + Vector2(lado * 0.34, lado * 0.84),
		col, g, true)
	# La cabeza: un arco ancho cruzado al mango, que es lo que lo separa de la espada (recta con
	# guarda) a este tamaño.
	c.draw_arc(pos + Vector2(lado * 0.52, lado * 0.44), lado * 0.34, PI * 1.15, PI * 1.95, 20,
		col, g, true)


# --- FAROLILLO: la caja de la luz con su asa ---
# PRIMERA VERSION: SE LEIA COMO UN CANDADO. Un asa en arco sobre una caja con un CIRCULO en medio
# es exactamente el dibujo de un candado, y a 34 px nadie lo iba a leer de otra forma.
#
# Las tres cosas que lo arreglan, y son las tres a la vez:
#   - el cuerpo es MAS ALTO QUE ANCHO (un candado es al reves);
#   - el techo y la base SOBRESALEN por los lados, que es lo que hace "farol" y no "caja";
#   - la llama es una GOTA con punta arriba, no un circulo. El circulo era el ojo del candado.
static func farol(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	var g: float = lado * 0.085
	var cx: float = pos.x + lado * 0.5
	# El asa, pequeña y por encima del techo.
	c.draw_arc(Vector2(cx, pos.y + lado * 0.16), lado * 0.11, PI, TAU, 16, col, g * 0.8, true)
	# Techo y base, MAS ANCHOS que el cuerpo (vuelan por los lados).
	c.draw_line(pos + Vector2(lado * 0.20, lado * 0.24), pos + Vector2(lado * 0.80, lado * 0.24),
		col, g * 1.2, true)
	c.draw_line(pos + Vector2(lado * 0.20, lado * 0.86), pos + Vector2(lado * 0.80, lado * 0.86),
		col, g * 1.2, true)
	# Los costados del vidrio, estrechos y altos.
	c.draw_line(pos + Vector2(lado * 0.32, lado * 0.24), pos + Vector2(lado * 0.32, lado * 0.86),
		col, g, true)
	c.draw_line(pos + Vector2(lado * 0.68, lado * 0.24), pos + Vector2(lado * 0.68, lado * 0.86),
		col, g, true)
	# LA LLAMA: gota con la punta hacia arriba. Es lo unico que dice que dentro hay fuego.
	var base: float = pos.y + lado * 0.68
	c.draw_arc(Vector2(cx, base), lado * 0.10, 0.0, PI, 14, col, g * 0.85, true)
	c.draw_line(Vector2(cx - lado * 0.10, base), pos + Vector2(lado * 0.5, lado * 0.42),
		col, g * 0.85, true)
	c.draw_line(Vector2(cx + lado * 0.10, base), pos + Vector2(lado * 0.5, lado * 0.42),
		col, g * 0.85, true)


# --- CORRER: dos chevrones hacia delante ---
static func correr(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	var g: float = lado * 0.12
	for i in 2:
		var x: float = pos.x + lado * (0.30 + 0.26 * float(i))
		c.draw_line(Vector2(x, pos.y + lado * 0.26), Vector2(x + lado * 0.20, pos.y + lado * 0.50),
			col, g, true)
		c.draw_line(Vector2(x + lado * 0.20, pos.y + lado * 0.50), Vector2(x, pos.y + lado * 0.74),
			col, g, true)


# --- SIGILO: una pisada, que es lo que se lee como "ir sin ruido" ---
static func sigilo(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	# La planta.
	c.draw_arc(pos + Vector2(lado * 0.5, lado * 0.62), lado * 0.19, 0.0, TAU, 24, col, lado * 0.09, true)
	# Los dedos, tres puntos por encima.
	for i in 3:
		var x: float = pos.x + lado * (0.36 + 0.14 * float(i))
		c.draw_circle(Vector2(x, pos.y + lado * (0.32 + 0.04 * absf(float(i) - 1.0))),
			lado * 0.055, col)


# --- INFO: el circulito con la i ---
static func info(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	var g: float = lado * 0.09
	var centro := pos + Vector2(lado * 0.5, lado * 0.5)
	c.draw_arc(centro, lado * 0.34, 0.0, TAU, 32, col, g, true)
	c.draw_circle(centro + Vector2(0, -lado * 0.16), lado * 0.055, col)
	c.draw_line(centro + Vector2(0, -lado * 0.03), centro + Vector2(0, lado * 0.18), col, g, true)


# --- CONSOLA (el panel de debug): la ventana con el prompt ">_" ---
static func consola(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	var g: float = lado * 0.075
	var m: float = lado * 0.14
	# El marco de la ventana.
	c.draw_rect(Rect2(pos + Vector2(m, m), Vector2(lado - m * 2.0, lado - m * 2.0)), col, false, g)
	# El prompt: el angulo ">" y su guion, como en una terminal.
	var x: float = pos.x + lado * 0.31
	var y: float = pos.y + lado * 0.42
	c.draw_line(Vector2(x, y), Vector2(x + lado * 0.13, y + lado * 0.11), col, g, true)
	c.draw_line(Vector2(x + lado * 0.13, y + lado * 0.11), Vector2(x, y + lado * 0.22), col, g, true)
	c.draw_line(Vector2(x + lado * 0.20, y + lado * 0.24), Vector2(x + lado * 0.38, y + lado * 0.24),
		col, g, true)


# --- EQUIS (cerrar): dos aspas ---
static func equis(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	var g: float = lado * 0.12
	var m: float = lado * 0.24   # cuanto se mete el aspa desde el borde de la caja
	c.draw_line(pos + Vector2(m, m), pos + Vector2(lado - m, lado - m), col, g, true)
	c.draw_line(pos + Vector2(lado - m, m), pos + Vector2(m, lado - m), col, g, true)


# Una capsula (rectangulo con las puntas redondeadas) entre dos puntos: la forma de los rollos del
# pergamino. draw_line con round=true ya la da hecha, asi que es una linea gorda y ya.
static func _capsula(c: CanvasItem, a: Vector2, b: Vector2, grosor: float, col: Color, borde: float) -> void:
	c.draw_line(a, b, col, grosor * 2.0, true)
	# El canto, un pelin mas oscuro, para que el rollo no se lea como una barra plana.
	c.draw_line(a, b, Color(col.r * 0.45, col.g * 0.45, col.b * 0.45, col.a), borde * 0.5, true)


# ============================================================
#  LOS FILTROS DEL INVENTARIO
#  La fila de subpestañas de Armas y Armaduras. Aqui la silueta tiene que decir el TIPO ella sola,
#  asi que todas se dibujan sobre el mismo eje diagonal (empuñadura abajo-izquierda, punta
#  arriba-derecha) y lo unico que cambia es lo que hay que mirar: el LARGO de la hoja, su ANCHO y la
#  cabeza. Puestas en fila se comparan entre si, que es justo lo que se hace al filtrar.
# ============================================================

# --- TODO (el primero de cada fila de filtros): cuatro celdas, o sea "la rejilla entera" ---
static func todo(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	var g: float = lado * 0.09
	var l: float = lado * 0.26
	var h: float = lado * 0.06
	for celda in [Vector2(0.20, 0.20), Vector2(0.54, 0.20), Vector2(0.20, 0.54), Vector2(0.54, 0.54)]:
		c.draw_rect(Rect2(pos + Vector2(lado * celda.x, lado * celda.y), Vector2(l, l)), col, false, g)
		# Un puntito dentro: sin el, cuatro cuadrados vacios se leen como una ventana.
		c.draw_rect(Rect2(pos + Vector2(lado * celda.x + l * 0.5 - h * 0.5,
			lado * celda.y + l * 0.5 - h * 0.5), Vector2(h, h)), col, true)


# ============================================================
#  PIEZAS DE ARMADURA
# ============================================================

# --- CASCO: yelmo con visera ---
static func casco(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	var g: float = lado * 0.09
	var cx: float = pos.x + lado * 0.5
	# La boveda.
	c.draw_arc(Vector2(cx, pos.y + lado * 0.52), lado * 0.28, PI, TAU, 24, col, g, true)
	# Los carrilleras, bajando por los lados.
	c.draw_line(pos + Vector2(lado * 0.22, lado * 0.52), pos + Vector2(lado * 0.26, lado * 0.78),
		col, g, true)
	c.draw_line(pos + Vector2(lado * 0.78, lado * 0.52), pos + Vector2(lado * 0.74, lado * 0.78),
		col, g, true)
	c.draw_line(pos + Vector2(lado * 0.26, lado * 0.78), pos + Vector2(lado * 0.74, lado * 0.78),
		col, g, true)
	# La ranura de los ojos, que es lo que lo hace yelmo y no gorro.
	c.draw_line(pos + Vector2(lado * 0.30, lado * 0.60), pos + Vector2(lado * 0.70, lado * 0.60),
		col, g * 0.8, true)


# --- MANOS: guantelete ---
# --- PANTALONES: dos perneras ---
static func pantalon(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	var g: float = lado * 0.09
	# La cintura.
	c.draw_line(pos + Vector2(lado * 0.26, lado * 0.22), pos + Vector2(lado * 0.74, lado * 0.22),
		col, g, true)
	# Las dos perneras, separandose hacia abajo desde la entrepierna.
	for lado_x in [-1.0, 1.0]:
		var x0: float = 0.5 + lado_x * 0.24
		var x1: float = 0.5 + lado_x * 0.28
		c.draw_line(pos + Vector2(lado * x0, lado * 0.22), pos + Vector2(lado * x1, lado * 0.82),
			col, g, true)
		c.draw_line(pos + Vector2(lado * (0.5 + lado_x * 0.06), lado * 0.52),
			pos + Vector2(lado * (0.5 + lado_x * 0.10), lado * 0.82), col, g, true)
		c.draw_line(pos + Vector2(lado * x1, lado * 0.82),
			pos + Vector2(lado * (0.5 + lado_x * 0.10), lado * 0.82), col, g, true)
	# La entrepierna, que es lo que junta las dos perneras y lo hace pantalon y no dos palos.
	c.draw_line(pos + Vector2(lado * 0.44, lado * 0.52), pos + Vector2(lado * 0.56, lado * 0.52),
		col, g * 0.7, true)


# --- BOTAS: bota de perfil ---
static func botas(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	var g: float = lado * 0.09
	# La caña y el pie, de una sola tirada: es la L lo que la hace bota.
	var p := PackedVector2Array([
		pos + Vector2(lado * 0.34, lado * 0.20), pos + Vector2(lado * 0.62, lado * 0.20),
		pos + Vector2(lado * 0.62, lado * 0.58), pos + Vector2(lado * 0.84, lado * 0.66),
		pos + Vector2(lado * 0.84, lado * 0.80), pos + Vector2(lado * 0.34, lado * 0.80),
	])
	var cerrado := PackedVector2Array(p)
	cerrado.append(p[0])
	c.draw_polyline(cerrado, col, g, true)
	# La suela, mas gruesa.
	c.draw_line(pos + Vector2(lado * 0.32, lado * 0.80), pos + Vector2(lado * 0.86, lado * 0.80),
		col, g * 1.3, true)


# ============================================================
#  TIPOS DE ARMA
#  Todas comparten el eje: mango en (0.24, 0.82) y punta hacia (0.80, 0.16). Lo que cambia es lo
#  que hay que comparar de un vistazo -- largo, grosor y cabeza --, y por eso comparten helper.
# ============================================================

const _MANGO := Vector2(0.24, 0.82)
const _PUNTA := Vector2(0.80, 0.16)

# Una hoja recta desde el mango: 'largo' 0..1 de lo que recorre el eje, 'grosor' relativo, y la
# guarda cruzada a 'guarda' del recorrido (0 = sin guarda).
static func _hoja(c: CanvasItem, pos: Vector2, lado: float, col: Color,
		largo: float, grosor: float, guarda: float, ancho_guarda: float) -> void:
	var a: Vector2 = pos + _MANGO * lado
	var b: Vector2 = pos + (_MANGO + (_PUNTA - _MANGO) * largo) * lado
	c.draw_line(a, b, col, lado * grosor, true)
	if guarda > 0.0:
		var gpos: Vector2 = pos + (_MANGO + (_PUNTA - _MANGO) * guarda) * lado
		var perp := Vector2(-1, -1).normalized() * (lado * ancho_guarda)
		c.draw_line(gpos - perp, gpos + perp, col, lado * 0.075, true)


static func daga(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	_hoja(c, pos, lado, col, 0.55, 0.075, 0.24, 0.11)


static func espada_corta(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	_hoja(c, pos, lado, col, 0.78, 0.085, 0.22, 0.14)


static func espada_larga(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	_hoja(c, pos, lado, col, 1.0, 0.09, 0.20, 0.16)


static func mandoble(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	# Hoja ANCHA y guarda mas arriba (empuñadura larga: se coge con las dos manos).
	_hoja(c, pos, lado, col, 1.0, 0.15, 0.30, 0.20)


static func estoque(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	# Hoja finisima y una cazoleta redonda en vez de guarda recta: es TODA la diferencia con la
	# espada, asi que el aro tiene que verse.
	_hoja(c, pos, lado, col, 1.0, 0.045, 0.0, 0.0)
	var gpos: Vector2 = pos + (_MANGO + (_PUNTA - _MANGO) * 0.20) * lado
	c.draw_arc(gpos, lado * 0.11, 0.0, TAU, 20, col, lado * 0.07, true)


static func hacha(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	var g: float = lado * 0.085
	_hoja(c, pos, lado, col, 1.0, 0.08, 0.0, 0.0)
	# La cabeza: una media luna colgada del extremo, hacia fuera del eje.
	var cabeza: Vector2 = pos + (_MANGO + (_PUNTA - _MANGO) * 0.78) * lado
	c.draw_arc(cabeza + Vector2(-lado * 0.10, -lado * 0.02), lado * 0.20,
		PI * 1.55, PI * 2.55, 20, col, g * 1.6, true)


static func maza(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	# Mango CORTO y una bola: pequeña, que es lo que la separa del martillo.
	_hoja(c, pos, lado, col, 0.60, 0.08, 0.0, 0.0)
	var cabeza: Vector2 = pos + (_MANGO + (_PUNTA - _MANGO) * 0.62) * lado
	c.draw_arc(cabeza, lado * 0.13, 0.0, TAU, 20, col, lado * 0.085, true)


static func martillo(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	# Mango LARGO y una cabeza cuadrada y grande.
	_hoja(c, pos, lado, col, 0.86, 0.09, 0.0, 0.0)
	var cabeza: Vector2 = pos + (_MANGO + (_PUNTA - _MANGO) * 0.86) * lado
	var perp := Vector2(-1, -1).normalized() * (lado * 0.19)
	c.draw_line(cabeza - perp, cabeza + perp, col, lado * 0.20, true)


static func baston(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	# Vara larga y fina con una piedra en la punta: el arma del mago.
	_hoja(c, pos, lado, col, 0.92, 0.065, 0.0, 0.0)
	var punta: Vector2 = pos + _PUNTA * lado
	c.draw_arc(punta, lado * 0.13, 0.0, TAU, 20, col, lado * 0.075, true)


# LOS TRES ESCUDOS. El juego los separa por TAMAÑO (ShieldData.Tamano), y es lo unico que los
# separa: mismo dibujo, tres escalas. Cualquier otra diferencia inventada mentiria sobre el dato.
# Van los tres juntos al final de la fila de filtros, que es lo que se pidio.
static func _escudo(c: CanvasItem, pos: Vector2, lado: float, col: Color, escala: float) -> void:
	var g: float = lado * 0.09 * (0.75 + escala * 0.35)
	var centro: Vector2 = pos + Vector2(lado * 0.5, lado * 0.53)
	# Escudo de gota: recto arriba y en punta abajo. Los puntos van en coordenadas RELATIVAS al
	# centro y luego se escalan, que es lo que deja hacer las tres tallas con un solo perfil.
	var perfil := PackedVector2Array([
		Vector2(-0.28, -0.31), Vector2(0.28, -0.31), Vector2(0.24, 0.09),
		Vector2(0.0, 0.31), Vector2(-0.24, 0.09),
	])
	var p := PackedVector2Array()
	for v in perfil:
		p.append(centro + v * lado * escala)
	p.append(p[0])
	c.draw_polyline(p, col, g, true)


static func escudo_peq(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	_escudo(c, pos, lado, col, 0.72)


static func escudo_med(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	_escudo(c, pos, lado, col, 1.0)


static func escudo_gra(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	_escudo(c, pos, lado, col, 1.28)


static func varita(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	# Vara CORTA con destellos: lo mismo que el baston pero pequeño y con chispas, que es la
	# diferencia que hay que ver en una fila donde los dos son "arma de mago".
	_hoja(c, pos, lado, col, 0.58, 0.07, 0.0, 0.0)
	var punta: Vector2 = pos + (_MANGO + (_PUNTA - _MANGO) * 0.62) * lado
	var g: float = lado * 0.06
	for ang in [0.0, PI * 0.5, PI, PI * 1.5]:
		var d := Vector2(cos(ang), sin(ang)) * (lado * 0.15)
		c.draw_line(punta + d * 0.42, punta + d, col, g, true)


# --- TRAZOS (el kit de habilidades): un nodo central y tres colgando ---
# Es la forma del arbol de la pantalla de referencia reducida a lo minimo que se lee a 34 px: el
# centro relleno (la habilidad que llevas) y tres ramas huecas saliendo de el. Con mas nodos, a este
# tamaño, se convierte en una mancha.
static func trazos(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	var g: float = lado * 0.075
	var centro: Vector2 = pos + Vector2(lado * 0.5, lado * 0.5)
	var r_centro: float = lado * 0.13
	var r_hoja: float = lado * 0.085
	# Los tres brazos: arriba, abajo-izquierda y abajo-derecha (un trebol, no una cruz: asi no se
	# confunde con el engranaje ni con una diana).
	for ang in [-PI * 0.5, PI * 0.17, PI * 0.83]:
		var d := Vector2(cos(ang), sin(ang))
		var nodo: Vector2 = centro + d * (lado * 0.32)
		# La rama arranca FUERA del circulo central y se para antes del nodo: una linea que entra en
		# los dos circulos los emborrona y deja de leerse cuantos nodos hay.
		c.draw_line(centro + d * (r_centro + g * 0.4), nodo - d * (r_hoja + g * 0.4), col, g * 0.7, true)
		c.draw_arc(nodo, r_hoja, 0.0, TAU, 16, col, g * 0.8, true)
	c.draw_circle(centro, r_centro, col)


# --- EIDOLON (desarrollos y pasivas): la flor de petalos de la pantalla de referencia ---
# Seis petalos en corona, uno relleno. El relleno no es adorno: dice que esto es algo que se
# CONSIGUE de uno en uno, que es justo lo que son los desarrollos y las pasivas.
static func eidolon(c: CanvasItem, pos: Vector2, lado: float, col: Color) -> void:
	var g: float = lado * 0.07
	var centro: Vector2 = pos + Vector2(lado * 0.5, lado * 0.5)
	var r: float = lado * 0.30    # a que distancia del centro va el corazon de cada petalo
	var rp: float = lado * 0.135  # el petalo
	for i in 6:
		# Se empieza arriba (-PI/2) para que el petalo relleno quede en el pico, que es donde el ojo
		# entra al icono.
		var ang: float = -PI * 0.5 + TAU * float(i) / 6.0
		var p: Vector2 = centro + Vector2(cos(ang), sin(ang)) * r
		if i == 0:
			c.draw_circle(p, rp, col)
		else:
			c.draw_arc(p, rp, 0.0, TAU, 18, col, g, true)
