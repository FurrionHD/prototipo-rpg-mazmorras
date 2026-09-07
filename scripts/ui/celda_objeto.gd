# ============================================================
#  celda_objeto.gd
#  LA CELDA DE UN OBJETO en la cuadricula del inventario. Es la pieza que mas se repite en el juego
#  -- caben 40 en pantalla -- asi que se dibuja entera a mano en un solo _draw(): un boton con
#  cinco nodos hijos dentro, multiplicado por 40, son 200 Controls que el motor tiene que colocar
#  cada vez que se reconstruye el menu.
#
#  LAS CUATRO CAPAS, de abajo arriba:
#
#     +----------------+   1. FONDO en degradado diagonal, del color del PELDAÑO del objeto. El
#     |\               |      fondo ES el indicador de calidad: no hay marco de color, porque un
#     | \      ///     |      borde fino de 1 px no se ve en una rejilla llena y el area si.
#     |     [icono]    |   2. LA MUESCA de la esquina superior izquierda. No decora: es lo que
#     |                |      hace que la celda se lea como una FICHA y no como un cuadrado, y de
#     |  * * *         |      un vistazo distingue esta rejilla de cualquier otra del juego.
#     +----------------+   3. LAS MARCAS de peldaño, apoyadas en el borde de la banda.
#     |      x12       |   4. LA BANDA oscura del pie con la cantidad, y bajo ella una linea del
#     +================+      color del peldaño que cierra la celda.
#
#  EL COLOR SALE DOS VECES Y NO SON EL MISMO (ver IconoItem, que es quien los da):
#    - el ICONO va del color del propio objeto (el marron del cobre)
#    - el FONDO y las MARCAS van del color de su peldaño (el gris de ser el escalon bajo del tier)
#  Por eso un lingote de cobre sale marron sobre gris y uno de acero marron sobre azul: cambia lo
#  que dice "esto es bueno" sin cambiar lo que dice "esto es metal".
#
#  LAS MARCAS NO SON CINCO ESTRELLAS FIJAS. Nuestras escalas no miden lo mismo: la rareza del
#  equipo tiene 8 peldaños y el rango de un material 5. Se dibujan "N de TECHO" con el techo de SU
#  eje, asi que un material lleno son 5 marcas y un arma llena son 8, y las apagadas dicen cuanto
#  queda por encima. Contarlas contra un techo ajeno no responderia a nada: un nucleo de boss y una
#  espada pristina no compiten por nada.
#
#  Es un Button de verdad (no un Control con gui_input) para no perder el foco de teclado, el
#  tooltip ni el toggle: todo eso ya funciona y volver a escribirlo seria peor. Lo unico que se le
#  quita es el estilo, que se sustituye por este dibujo.
# ============================================================

extends Button
class_name CeldaObjeto

# --- proporciones, todas relativas al lado de la celda ---
const MUESCA := 0.24        # lo que se come el chaflan de la esquina superior izquierda
const REDONDEO := 0.07      # chaflan pequeño de las otras tres esquinas
const ALTO_BANDA := 0.21    # la franja oscura del pie, donde va la cantidad
const LADO_ICONO := 0.52    # el cubo/frasco dentro de la celda
const ALTO_LINEA := 0.035   # la linea de color que cierra por abajo
const MARCA := 0.075        # lado de una marca de peldaño
# Cuanto se mete hacia DENTRO la franja del tier, en proporcion a la muesca. El triangulo del
# chaflan a secas son ~10 px en una celda de 96: se ve que hay color, pero no CUAL. Con la franja
# hay superficie para distinguir el tono, y sigue sin llegar al icono (que empieza en 0.24).
const BANDA_TIER := 0.62

var item: Resource = null
var texto_pie: String = ""      # lo que va en la banda: "x12", "Casco", "Nv. 3"...
var marca: String = ""          # etiqueta de esquina: "PUESTA", el nombre de quien lo lleva...
# EL NIVEL DE MEJORA que se pinta arriba a la derecha. -1 = que lo averigue la celda (lo normal);
# 0 = no pintar ninguno, para una pantalla que no quiera enseñarlo.
var plus: int = -1
var _hover := false


# 'pie' vacio = la banda va sin texto (una pieza unica: un arma, una mochila). La banda se dibuja
# igual, porque es lo que le da el suelo a la celda y sin ella la rejilla se descuadra.
func configurar(objeto: Resource, pie: String = "", etiqueta: String = "", nivel: int = -1) -> void:
	item = objeto
	texto_pie = pie
	marca = etiqueta
	plus = nivel
	queue_redraw()


# El +N que toca pintar. Se deriva del propio objeto salvo que se haya pasado uno a mano: asi una
# pantalla nueva lo enseña sin tener que acordarse de pedirlo, que es como se quedaron las
# armaduras sin el suyo cuando el +N vivia en el texto del pie.
func _plus() -> int:
	if plus >= 0:
		return plus
	return Game.mejoras_actuales(item) if item != null else 0


func _ready() -> void:
	toggle_mode = true
	# El estilo del tema se quita entero: lo pinta _draw(). Hay que poner los CINCO estados o Godot
	# rellena los que falten con su gris y la celda cambia de aspecto al pasar el raton por encima.
	for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(estado, StyleBoxEmpty.new())
	mouse_entered.connect(func():
		_hover = true
		queue_redraw())
	mouse_exited.connect(func():
		_hover = false
		queue_redraw())
	# Un Button no se redibuja solo al marcarse/desmarcarse, y la celda cambia bastante (el borde
	# blanco): sin esto, seleccionar otra dejaba las dos encendidas hasta el siguiente rebuild.
	toggled.connect(func(_on): queue_redraw())
	resized.connect(queue_redraw)


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 1.0 or h <= 1.0:
		return   # el contenedor aun no ha colocado la celda; ya volvera por resized
	var col: Color = IconoItem.color_escala(item) if item != null else Color(0.5, 0.5, 0.55)
	var borde: PackedVector2Array = _contorno(w, h)

	# 1. FONDO EN DEGRADADO. draw_polygon interpola el color entre vertices, asi que basta con darle
	# a cada esquina el suyo: el degradado sale gratis y sigue la forma con muesca, sin tener que
	# recortar una textura. Va de oscuro abajo-izquierda a vivo arriba-derecha, que es de donde
	# viene la luz en el resto del juego.
	# El recorrido del degradado va de MUY oscuro a casi el color puro. La primera version iba de
	# darkened(0.72) a darkened(0.25) y toda la rejilla salia parda: con el color apagado en las dos
	# puntas, el degradado no tiene de donde sacar luz y las ocho rarezas se acercaban entre si.
	var oscuro: Color = col.darkened(0.68)
	var claro: Color = col.lerp(Color(1, 1, 1), 0.06).darkened(0.06)
	var colores := PackedColorArray()
	for p in borde:
		# t = lo avanzado en la diagonal ↙→↗, 0..1. Es lo que hace que el degradado sea DIAGONAL y no
		# vertical: mezcla las dos coordenadas en vez de mirar solo la y.
		var t: float = clampf((p.x / w + (1.0 - p.y / h)) * 0.5, 0.0, 1.0)
		colores.append(oscuro.lerp(claro, t))
	draw_polygon(borde, colores)

	# 1b. LA MUESCA, DEL COLOR DEL TIER. El hueco que deja el chaflan estaba a oscuras y no decia
	# nada: cinco piezas de armadura seguidas se veian iguales y habia que pulsarlas una a una para
	# saber de que tier eran. Ahora ese triangulo es la respuesta, y no le quita sitio a nada porque
	# ya estaba vacio.
	#
	# El fondo sigue diciendo la RAREZA y la muesca el TIER: dos ejes distintos en dos sitios
	# distintos. Ver IconoItem.color_tier para por que el color da vueltas en vez de ser una lista.
	_muesca_tier(w, h)

	# 2. LA BANDA DEL PIE y su linea de color. Van dentro del contorno, asi que se recortan solas
	# contra el chaflan de las esquinas de abajo -- por eso se dibujan como poligono y no como rect.
	var y_banda: float = h * (1.0 - ALTO_BANDA)
	draw_polygon(_recortar_bajo(borde, y_banda, w, h), PackedColorArray([Color(0.04, 0.05, 0.07, 0.88)]))
	var y_linea: float = h * (1.0 - ALTO_LINEA)
	draw_polygon(_recortar_bajo(borde, y_linea, w, h), PackedColorArray([col]))

	# 3. EL ICONO, centrado en el hueco que queda POR ENCIMA de la banda (no en la celda entera: con
	# la banda debajo, centrarlo en el total lo deja visiblemente bajo). Con 'encajar' para que un
	# frasco y un cubo ocupen lo mismo -- ver IconoItem.ENCAJE.
	IconoItem.pintar(self, Vector2(w * 0.5, y_banda * 0.5), minf(w, h) * LADO_ICONO, item, true)

	# 4. LAS MARCAS DE PELDAÑO, apoyadas justo encima de la banda.
	if item != null:
		_marcas(w, y_banda, col)

	# 5. EL +N, arriba a la DERECHA y con el color de su nivel (ver IconoItem.color_mejora). La
	# esquina de la izquierda es del tier, asi que esta es la unica libre arriba -- y arriba es donde
	# tiene que estar: es lo que distingue dos piezas iguales, y en el pie se perdia entre el resto.
	var n_plus: int = _plus()
	var y_plus: float = 0.0   # hasta donde baja la muesca (0 = no hay), para no pisarla con la marca
	if n_plus > 0:
		y_plus = _muesca_plus(w, h, n_plus)

	# LA MARCA DE ESQUINA ("PUESTA", quien lo lleva). Va arriba a la DERECHA porque la izquierda se la
	# come la muesca, y sobre su propia pastilla oscura: encima del degradado a pelo, la misma
	# palabra se leia bien en las celdas oscuras y desaparecia en las claras.
	#
	# CON +N NO CABEN LAS DOS en la misma esquina, asi que la marca se va a la banda de abajo,
	# pegada a la derecha. Lo decide la celda y no cada menu: si tuviera que saberlo quien pinta,
	# bastaria con que una pantalla se olvidara para tener dos textos encima del mismo sitio.
	var marca_en_banda: bool = (marca != "" and n_plus > 0)
	if marca != "" and not marca_en_banda:
		var f2: Font = get_theme_font(&"font")
		var t2: int = maxi(8, int(h * 0.10))
		var an: float = f2.get_string_size(marca, HORIZONTAL_ALIGNMENT_LEFT, -1, t2).x
		var alto: float = float(t2) + 6.0
		var caja := Rect2(Vector2(w - an - 12.0, maxf(4.0, y_plus + 3.0)), Vector2(an + 8.0, alto))
		draw_rect(caja, Color(0.03, 0.04, 0.06, 0.82))
		draw_string(f2, Vector2(caja.position.x + 4.0, caja.position.y + float(t2) + 1.0),
			marca, HORIZONTAL_ALIGNMENT_LEFT, -1, t2, Color(0.96, 0.88, 0.62))

	# LA BANDA: el pie centrado y, si la marca ha bajado aqui, el nombre pegado a la derecha. El pie
	# se centra en el HUECO QUE QUEDA, no en la celda, o los dos textos se montan uno encima del otro
	# en cuanto el nombre es largo.
	var fuente: Font = get_theme_font(&"font")
	var centro_banda: float = y_banda + (h - y_banda - h * ALTO_LINEA) * 0.5
	var libre: float = w
	if marca_en_banda:
		var t3: int = maxi(8, int(h * 0.115))
		# EL NOMBRE, RECORTADO a poco mas de la mitad de la celda: hay compañeros con nombres largos
		# ("Agirato ochinan") y sin tope se comian la banda entera y empujaban al pie fuera. El ancho
		# va en el parametro de draw_string que RECORTA de verdad (el quinto), no en el octavo, que
		# son las banderas de justificado y deja el texto pasarse igual.
		var tope3: float = w * 0.56
		var an3: float = minf(fuente.get_string_size(marca, HORIZONTAL_ALIGNMENT_LEFT, -1, t3).x, tope3)
		draw_string(fuente, Vector2(w - an3 - 5.0, centro_banda + float(t3) * 0.36), marca,
			HORIZONTAL_ALIGNMENT_LEFT, an3, t3, Color(0.96, 0.88, 0.62))
		libre = w - an3 - 8.0
	# LA CANTIDAD (o el slot), centrada en lo que quede. La Y es la LINEA BASE del texto, no su borde
	# de arriba: para centrarlo de verdad hay que bajar desde el centro de la banda por el ascendente
	# de la fuente, o el numero se queda pegado al borde de abajo (que es donde estaba).
	if texto_pie != "":
		var tam: int = maxi(9, int(h * 0.145))
		var hueco: float = maxf(libre - 6.0, 0.0)
		var an_pie: float = fuente.get_string_size(texto_pie, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		# O CABE ENTERO O NO SE PINTA. Recortado no dice nada y encima engaña: "Principal" se quedaba
		# en "Prin", que parece el nombre de otra cosa. Lo que se cae es siempre el pie y nunca el
		# nombre de quien lo lleva, que es el dato que no se puede deducir mirando la celda.
		if an_pie <= hueco:
			draw_string(fuente, Vector2(3.0, centro_banda + float(tam) * 0.36), texto_pie,
				HORIZONTAL_ALIGNMENT_CENTER, hueco, tam, Color(0.94, 0.95, 0.97))

	# EL ESTADO, siempre por encima de todo. Seleccionada = borde blanco grueso, que es lo unico que
	# se lee de un vistazo en una rejilla donde TODAS las celdas tienen color.
	if button_pressed:
		draw_polyline(_cerrar(borde), Color(1, 1, 1, 0.95), maxf(2.0, w * 0.028))
	elif _hover or has_focus():
		draw_polyline(_cerrar(borde), Color(1, 1, 1, 0.45), maxf(1.5, w * 0.016))
	if disabled:
		draw_polygon(borde, PackedColorArray([Color(0.04, 0.05, 0.07, 0.55)]))


# LA MUESCA PINTADA: el triangulo de la esquina superior izquierda, del color del tier y con el
# NUMERO escrito dentro (ver IconoItem.color_tier).
#
# Se dibuja DENTRO del hueco del chaflan y no encima del borde: el contorno ya deja ese triangulo
# libre, asi que basta con rellenarlo y la silueta de la celda no cambia.
func _muesca_tier(w: float, h: float) -> void:
	var tier: int = IconoItem.tier_de(item) if item != null else 0
	if tier <= 0:
		return   # lo que no tiene tier (un cristal) deja la muesca a oscuras, como siempre
	var m: float = minf(w, h) * MUESCA
	var col: Color = IconoItem.color_tier(tier)
	# EL TRIANGULO DEL CHAFLAN SOLO NO BASTA: en una celda de 96 son unos 10 px de color y a simple
	# vista no se distingue un tono de otro -- medido en captura. Se le añade una FRANJA hacia dentro
	# (el trapecio de debajo), que multiplica la superficie sin tocar la silueta de la celda: la
	# muesca sigue siendo la misma, lo que cambia es que ahora esta pintada.
	var f: float = m * BANDA_TIER
	draw_colored_polygon(PackedVector2Array([
		Vector2.ZERO, Vector2(m + f, 0.0), Vector2(0.0, m + f)]), col)
	# Una linea mas clara en el canto de dentro: separa la franja del degradado del fondo, que en las
	# rarezas claras tiran al mismo sitio y se comian el borde.
	draw_line(Vector2(m + f, 0.0), Vector2(0.0, m + f), col.lightened(0.35), 2.0, true)

	# EL NUMERO DEL TIER, escrito en la franja. El color agrupa de un vistazo (cuatro T2 seguidos se
	# ven de golpe) y el numero lo remata sin dejar dudas, que era la pega del color solo: hay que
	# aprenderselo. Van los dos porque responden a preguntas distintas.
	#
	# SIN LA "T": el numero esta dentro de la muesca del tier, asi que la letra no añade nada y a este
	# tamaño le roba la mitad del sitio al digito.
	#
	# Y ya no hay puntos de vuelta: los puso el diseño de color para separar un T2 de un T8, y con el
	# numero escrito eso lo dice el propio numero. Dos formas de contar lo mismo es una de mas.
	var fuente: Font = get_theme_font(&"font")
	var tam: int = maxi(int(minf(w, h) * 0.17), 8)
	var txt: String = str(tier)
	var an: float = fuente.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	# En el CENTROIDE del triangulo (L/3, L/3), que es donde mas ancho tiene: pegado a la esquina se
	# sale por el chaflan y pegado a la diagonal se come el borde.
	var c3: float = (m + f) / 3.0
	# Contraste sobre el propio color: oscuro si la franja es clara, claro si es oscura.
	var tinta: Color = Color(0.05, 0.05, 0.08, 0.95) if col.get_luminance() > 0.5 \
		else Color(1, 1, 1, 0.95)
	draw_string(fuente, Vector2(c3 - an * 0.5, c3 + float(tam) * 0.38), txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tam, tinta)


# LA MUESCA DEL +N: el triangulo de la esquina de arriba a la DERECHA, del color de su nivel y con
# el numero dentro. Devuelve por donde acaba (la Y de su punta de abajo), que es lo que necesita la
# marca de esquina para no metersele encima.
#
# Es la MISMA figura que la muesca del tier, en espejo, y eso no es un capricho: la celda tiene su
# lenguaje (chaflan de color con el numero dentro) y una pastilla rectangular ahi arriba se leia
# como una etiqueta pegada de otra pantalla. Dos datos del mismo tipo -- un numero corto que
# clasifica -- tienen que pintarse igual y en esquinas opuestas.
#
# El color agrupa de un vistazo (los tres +5 de la rejilla se ven de golpe) y el numero lo remata
# sin que haya que aprenderse la escala. Ver IconoItem.color_mejora.
func _muesca_plus(w: float, h: float, n: int) -> float:
	var col: Color = IconoItem.color_mejora(n)
	var lado: float = minf(w, h) * (MUESCA + MUESCA * BANDA_TIER)   # lo mismo que mide la del tier
	# El vertice de la derecha NO llega a la esquina: ahi el contorno lleva su chaflan pequeño (ver
	# _contorno), y pintar hasta el pico se saldria del fondo por dos puntas.
	var r: float = minf(w, h) * REDONDEO
	draw_colored_polygon(PackedVector2Array([
		Vector2(w - lado, 0.0), Vector2(w - r, 0.0), Vector2(w, r), Vector2(w, lado)]), col)
	# La misma linea clara del canto que en el tier: sobre las rarezas claras el color de la muesca y
	# el del fondo tiran al mismo sitio y el borde se perdia.
	draw_line(Vector2(w - lado, 0.0), Vector2(w, lado), col.lightened(0.35), 2.0, true)

	# EL NUMERO, dentro del triangulo y pegado a su lado ancho. El "+" va delante porque es lo que lo
	# distingue del tier de enfrente: sin el, dos numeros sueltos en las dos esquinas se leen como si
	# midieran lo mismo.
	var fuente: Font = get_theme_font(&"font")
	var txt: String = "+%d" % n
	# Los de DOS CIFRAS ("+12") en un cuerpo menor: el triangulo se estrecha hacia abajo y a tamaño
	# completo la punta del "+" se salia por la diagonal, encima del fondo.
	var tam: int = maxi(int(minf(w, h) * (0.155 if txt.length() <= 2 else 0.128)), 8)
	var an: float = fuente.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	# ALTO en el triangulo, que es donde tiene ancho: a la altura 'y' el hueco mide (lado - y), asi
	# que bajar el numero es quedarse sin sitio. Y centrado en ESE hueco, no en el lado entero.
	var cy: float = lado * 0.26
	var cx: float = w - (lado - cy) * 0.5
	var tinta: Color = Color(0.05, 0.05, 0.08, 0.95) if col.get_luminance() > 0.5 \
		else Color(1, 1, 1, 0.95)
	draw_string(fuente, Vector2(cx - an * 0.5, cy + float(tam) * 0.38), txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tam, tinta)
	return lado


# El contorno de la celda: rectangulo con la esquina superior izquierda MUY achaflanada (la muesca,
# que es la marca de la casa) y las otras tres apenas matadas. Va en sentido horario desde el final
# de la muesca.
func _contorno(w: float, h: float) -> PackedVector2Array:
	var m: float = minf(w, h) * MUESCA
	var r: float = minf(w, h) * REDONDEO
	return PackedVector2Array([
		Vector2(m, 0.0), Vector2(w - r, 0.0), Vector2(w, r),        # arriba y esquina der.
		Vector2(w, h - r), Vector2(w - r, h),                        # abajo derecha
		Vector2(r, h), Vector2(0.0, h - r),                          # abajo izquierda
		Vector2(0.0, m),                                             # sube hasta la muesca
	])


func _cerrar(p: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(p)
	out.append(p[0])
	return out


# El trozo del contorno que queda POR DEBAJO de 'y'. Es lo que hace que la banda del pie y la linea
# de color respeten los chaflanes de las esquinas de abajo en vez de sobresalir por ellos.
#
# Vale porque el contorno es CONVEXO y la unica esquina rara (la muesca) esta arriba: una recta
# horizontal lo corta en exactamente dos puntos, asi que basta con quedarse los vertices de abajo y
# añadir los dos cortes. Con una forma concava esto no serviria.
func _recortar_bajo(borde: PackedVector2Array, y: float, w: float, h: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n: int = borde.size()
	for i in n:
		var a: Vector2 = borde[i]
		var b: Vector2 = borde[(i + 1) % n]
		if a.y >= y:
			out.append(a)
		# Cruza la linea entre a y b: se mete el punto de corte, en el orden en que va el recorrido.
		if (a.y < y) != (b.y < y) and not is_equal_approx(a.y, b.y):
			var t: float = (y - a.y) / (b.y - a.y)
			out.append(a.lerp(b, t))
	if out.size() < 3:
		return PackedVector2Array([Vector2(0.0, y), Vector2(w, y), Vector2(w, h), Vector2(0.0, h)])
	return out


# LAS MARCAS: 'escalon + 1' encendidas del color del peldaño y el resto apagadas, hasta el techo de
# SU escala. Son rombos y no estrellas porque a 7 px una estrella es una mancha, y porque el rombo
# es la forma que ya usan los adornos de apoyo del combate.
#
# El ancho se reparte entre las que haya, asi que las 8 de un arma pristina caben igual que las 5 de
# un material: la fila mide siempre lo mismo y la rejilla no baila.
func _marcas(w: float, y_banda: float, col: Color) -> void:
	var techo: int = IconoItem.techo(item)
	if techo <= 0:
		return
	var total: int = techo + 1
	var lleno: int = IconoItem.escalon(item) + 1
	# El lado sale de repartir el ancho disponible entre las marcas que haya, con un tope: asi las 5
	# de un material salen GRANDES y las 8 de un arma se aprietan sin salirse, en vez de tener todas
	# el mismo tamaño diminuto calculado para el peor caso.
	var paso: float = minf(w * MARCA * 1.5, (w * 0.80) / float(total))
	var lado: float = paso * 0.86
	var x0: float = (w - paso * float(total)) * 0.5 + paso * 0.5
	# JUSTO ENCIMA del borde de la banda, no a caballo sobre el. A caballo quedaban mas vistosas,
	# pero la mitad de abajo caia dentro de la banda y CHOCABA CON LA CANTIDAD: "x250" salia con tres
	# rombos encima de las cifras. El contorno oscuro de cada marca ya hace el trabajo de despegarlas
	# del fondo, que era el otro motivo para montarlas.
	var y: float = y_banda - lado * 0.62
	for i in total:
		var lleno_i: bool = i < lleno
		var cx: float = x0 + paso * float(i)
		var pts := PackedVector2Array([
			Vector2(cx, y - lado * 0.5), Vector2(cx + lado * 0.44, y),
			Vector2(cx, y + lado * 0.5), Vector2(cx - lado * 0.44, y),
		])
		# Contorno oscuro debajo (el mismo rombo un pelin mas grande): es lo que hace que la marca se
		# vea igual de bien sobre el fondo de color que sobre la banda negra.
		var g := PackedVector2Array()
		for p in pts:
			g.append(Vector2(cx, y) + (p - Vector2(cx, y)) * 1.35)
		draw_colored_polygon(g, Color(0.03, 0.04, 0.06, 0.85))
		draw_colored_polygon(pts, col.lightened(0.25) if lleno_i else Color(1, 1, 1, 0.20))
