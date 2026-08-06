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
