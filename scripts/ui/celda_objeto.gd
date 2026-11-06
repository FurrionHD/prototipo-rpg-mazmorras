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

const RetratoPieza = preload("res://scripts/ui/retrato_pieza.gd")
const HudEstilo = preload("res://scripts/ui/hud_estilo.gd")

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
var marca: String = ""          # va en la banda: "PUESTA", el nombre de quien lo lleva...
# EL NIVEL DE MEJORA que se pinta arriba a la derecha. -1 = que lo averigue la celda (lo normal);
# 0 = no pintar ninguno, para una pantalla que no quiera enseñarlo.
var plus: int = -1
# APAGADA PERO PULSABLE: se pinta con el velo de 'disabled' y sigue respondiendo. Para lo que se puede
# mirar pero no hacer (una receta de los talleres sin material: x0).
var tenue := false
var _hover := false
# EL RETRATO DE LA PIEZA (el dibujo del muñeco, ver retrato_pieza.gd), para el equipo que lo tiene.
# Es un nodo hijo y no un draw_texture de aqui: lleva el shader de la paleta, y en la celda ese
# shader se comeria tambien el fondo. Lo que no tiene dibujo (materiales, pociones) sigue con su
# icono de IconoItem.
var _retrato: TextureRect = null
# EL SELLO DE LAS RUNAS, en su propia capa ENCIMA del retrato (31/10, el jefe: "el dibujo del equipo sale por encima
# del buff"). Pintado en el _draw de la celda quedaba debajo del retrato, que es un hijo y se pinta despues.
var _sello: Control = null
var _sello_medidas := Vector3.ZERO   # (w, h, y_banda) del ultimo _draw
# Lo que mide el hueco del retrato, en fraccion del lado. Un pelo mas que el icono (LADO_ICONO): el
# retrato se recorta a la silueta de la pieza, sin el aire que lleva el cubo alrededor.
const LADO_RETRATO := 0.56
const SpritesObjeto = preload("res://scripts/ui/sprites_objeto.gd")
var _caja_icono: float = LADO_RETRATO   # lo que ocupa lo que haya en _retrato (retrato o dibujo)
# SOLO SE PINTA LO QUE SE VE. Una rejilla con el baul lleno son ~600 celdas y cada una es un fondo en
# degradado, sus marcas y sus textos: pintarlas todas al abrir la pestaña costaba casi medio segundo
# (medido), aunque a la vez solo se ven unas cuarenta. Las de fuera se quedan PENDIENTES y se pintan
# al entrar con el scroll.
var _scroll: ScrollContainer = null
var _pendiente: bool = false
static var _vacio: StyleBoxEmpty = null
var _tiene_retrato: bool = false   # si _retrato lleva algo que enseñar (su 'visible' se apaga fuera de vista)


# 'pie' vacio = la banda va sin texto (una pieza unica: un arma, una mochila). La banda se dibuja
# igual, porque es lo que le da el suelo a la celda y sin ella la rejilla se descuadra.
func configurar(objeto: Resource, pie: String = "", etiqueta: String = "", nivel: int = -1) -> void:
	item = objeto
	texto_pie = pie
	marca = etiqueta
	plus = nivel
	_caja_icono = LADO_RETRATO
	# El equipo con dibujo del muñeco, su retrato; si no, el dibujo del objeto YA HECHO IMAGEN (ver
	# SpritesObjeto.textura_item). Los dos en el mismo TextureRect: pintarlo aqui rectangulo a
	# rectangulo costaba medio segundo con el baul lleno.
	if not RetratoPieza.poner(_retrato, item, RetratoPieza.ESC_CELDA) and item != null:
		var t: Dictionary = SpritesObjeto.textura_item(item)
		if not t.is_empty():
			_retrato.texture = t["tex"]
			_retrato.material = null
			_retrato.visible = true
			_caja_icono = LADO_ICONO * IconoItem.ENCAJE_DIBUJO * float(t["caja"])
	_tiene_retrato = _retrato.visible
	queue_redraw()


# El +N que toca pintar. Se deriva del propio objeto salvo que se haya pasado uno a mano: asi una
# pantalla nueva lo enseña sin tener que acordarse de pedirlo, que es como se quedaron las
# armaduras sin el suyo cuando el +N vivia en el texto del pie.
func _plus() -> int:
	if plus >= 0:
		return plus
	return Game.mejoras_actuales(item) if item != null else 0


# EN EL _init Y NO EN EL _ready, Y NO ES UN DETALLE: BaseButton.set_pressed() SE SALE SIN HACER NADA
# si el boton todavia no es de tipo toggle. Quien pinta una rejilla construye la celda, le pone
# 'button_pressed = (i == sel)' y la mete en el arbol; con el toggle_mode puesto en _ready -- que
# corre AL ENTRAR, o sea DESPUES -- esa marca se tiraba a la basura en silencio y NINGUNA celda salia
# marcada nunca. El borde de seleccionada llevaba escrito desde el principio y no se veia por esto.
func _init() -> void:
	toggle_mode = true
	_retrato = RetratoPieza.nodo()
	add_child(_retrato)
	_sello = Control.new()
	_sello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sello.draw.connect(_pintar_sello)
	add_child(_sello)
	# El estilo del tema se quita entero: lo pinta _draw(). Hay que poner los CINCO estados o Godot
	# rellena los que falten con su gris y la celda cambia de aspecto al pasar el raton por encima.
	# UNO para todas las celdas, no cinco por celda: con el baul lleno eran casi tres mil objetos
	# identicos creados para nada al abrir la pestaña.
	# AQUI, FUERA DEL ARBOL, y no en _ready: dentro, cada override avisa de un cambio de tema y recoloca la celda;
	# eran ~0,11 ms por celda (40 celdas: 4,3 ms de cada cambio de pestaña). Fuera no cuesta nada (medido 16/10).
	if _vacio == null:
		_vacio = StyleBoxEmpty.new()
	for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(estado, _vacio)


func _ready() -> void:
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
	# EL SCROLL que la contiene, si hay: al desplazarse, las celdas que se habian quedado sin pintar
	# por estar fuera de la vista se pintan al entrar (ver _draw).
	var p: Node = get_parent()
	while p != null and not (p is ScrollContainer):
		p = p.get_parent()
	if p != null:
		_scroll = p as ScrollContainer
		_enganchar_scroll(_scroll)


# UNA SOLA CONEXION POR SCROLL, no dos por celda: con el baul lleno eran 1.400 conexiones y cada paso de rueda
# avisaba a 700 celdas para que casi todas dijeran "no es conmigo". Ahora la celda que se salta el dibujo por estar
# fuera de la vista se APUNTA en la lista del scroll (ver _draw), y al moverse o cambiar de tamaño el scroll se
# avisa solo a las apuntadas; la que siga fuera se vuelve a apuntar al intentar pintarse.
const META_PENDIENTES := "celdas_pendientes"
var _apuntada: bool = false

static func _enganchar_scroll(sc: ScrollContainer) -> void:
	if sc.has_meta(META_PENDIENTES):
		return
	sc.set_meta(META_PENDIENTES, [])
	sc.get_v_scroll_bar().value_changed.connect(func(_v): _despertar(sc))
	sc.resized.connect(func(): _despertar(sc))


static func _despertar(sc: ScrollContainer) -> void:
	if not is_instance_valid(sc):
		return
	var lista: Array = sc.get_meta(META_PENDIENTES, [])
	if lista.is_empty():
		return
	sc.set_meta(META_PENDIENTES, [])
	for c in lista:
		if is_instance_valid(c):
			(c as CeldaObjeto)._apuntada = false
			if (c as CeldaObjeto)._pendiente:
				(c as CeldaObjeto).queue_redraw()


func _apuntarse() -> void:
	if _apuntada or _scroll == null or not is_instance_valid(_scroll):
		return
	_apuntada = true
	var lista: Array = _scroll.get_meta(META_PENDIENTES, [])
	# Cambiar de pestaña muchas veces sin mover el scroll la llenaria de celdas ya liberadas: se limpia de vez en cuando.
	if lista.size() > 2048:
		lista = lista.filter(func(c): return is_instance_valid(c))
		_scroll.set_meta(META_PENDIENTES, lista)
	lista.append(self)


# Saltarse el ahorro de abajo. Lo ponen las celdas SUELTAS (las de dentro de una ficha, ver
# MenuScaffold.celda_suelta), que son cuatro y no cuatrocientas.
#
# Hace falta porque el ahorro se apoya en que a la celda le vuelva a llegar un aviso: si el primer
# _draw la pilla antes de que su contenedor la haya colocado, se marca _pendiente y espera a que el
# scroll se mueva o cambie de tamaño. Una celda de rejilla siempre acaba cambiando de tamaño y se
# repinta; una suelta nace con su tamaño fijo, no cambia nunca mas y se quedaba EN BLANCO para
# siempre (visto en la peleteria: el hueco reservado y nada dentro).
var siempre_visible: bool = false

# ¿Se ve ahora mismo dentro de su scroll? Sin scroll, siempre.
func _a_la_vista() -> bool:
	if siempre_visible:
		return true
	if _scroll == null or not is_instance_valid(_scroll):
		return true
	return _scroll.get_global_rect().grow(size.y).intersects(get_global_rect())


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 1.0 or h <= 1.0:
		return   # el contenedor aun no ha colocado la celda; ya volvera por resized
	if not _a_la_vista():
		_pendiente = true
		_retrato.visible = false   # su dibujo tampoco: se enseña cuando la celda se pinte
		_apuntarse()   # el scroll la avisara al moverse (ver _enganchar_scroll)
		return
	_pendiente = false
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
	if HudEstilo.es_pixel():
		_fondo_franjas(borde, w, h, oscuro, claro)
	else:
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
	# Con retrato (el equipo con dibujo), el retrato; si no, el icono de siempre.
	if _tiene_retrato:
		_retrato.visible = true
		RetratoPieza.encajar(_retrato, Vector2(w * 0.5, y_banda * 0.5), minf(w, h) * _caja_icono)
		# EL RETRATO VA ENCIMA DE TODO lo que pinta este _draw (es un hijo, y los hijos se pintan
		# despues del padre), asi que el velo de apagada no lo tapa: se le oscurece a el directamente.
		_retrato.modulate = Color(0.42, 0.43, 0.46) if disabled or tenue else Color.WHITE
	else:
		IconoItem.pintar(self, Vector2(w * 0.5, y_banda * 0.5), minf(w, h) * LADO_ICONO, item, true)

	# 4. LAS MARCAS DE PELDAÑO, apoyadas justo encima de la banda.
	if item != null:
		_marcas(w, y_banda, col)

	# 5. EL +N, arriba a la DERECHA y con el color de su nivel (ver IconoItem.color_mejora). La
	# esquina de la izquierda es del tier, asi que esta es la unica libre arriba -- y arriba es donde
	# tiene que estar: es lo que distingue dos piezas iguales, y en el pie se perdia entre el resto.
	var n_plus: int = _plus()
	if n_plus > 0:
		_muesca_plus(w, h, n_plus)
	# 5b. LAS RUNAS (08/10/2026): de que set es y cuantas sub-stats lleva, en todas las rejillas. En su capa, ENCIMA del
	# retrato (_pintar_sello), y apagada como el retrato si la celda lo esta.
	_sello_medidas = Vector3(w, h, y_banda)
	_sello.size = size
	_sello.modulate = Color(0.42, 0.43, 0.46) if disabled or tenue else Color.WHITE
	_sello.queue_redraw()

	# LA MARCA ("PUESTA", el nombre de quien lo lleva) VA SIEMPRE EN LA BANDA DE ABAJO. Antes iba
	# arriba a la derecha en una pastilla, y solo bajaba aqui cuando el +N ocupaba esa esquina: la
	# misma rejilla tenia nombres en dos sitios, arriba tapaban el dibujo del arma y abajo salian
	# cortados a media celda ("Agirato oc"). Playtest del 15/09: "o uno u otro, no los dos".
	var fuente: Font = get_theme_font(&"font")
	var centro_banda: float = y_banda + (h - y_banda - h * ALTO_LINEA) * 0.5
	var libre: float = w
	var carrusel: bool = false
	if marca != "":
		# Con pie, el nombre se queda con poco mas de la mitad (a la derecha) y el pie con el resto;
		# sin pie, la banda entera. Si no cabe, primero se achica la letra hasta un minimo legible, y si
		# ni asi, CARRUSEL (el mismo de las rejillas, ver MenuScaffold.texto_deslizante): cortado no
		# se lee, y el nombre de quien lo lleva es el dato que no se puede deducir mirando la celda.
		var tope3: float = (w * 0.56) if texto_pie != "" else (w - 10.0)
		var t3: int = maxi(8, int(h * 0.115))
		var t_min: int = maxi(8, int(h * 0.09))
		var an3: float = fuente.get_string_size(marca, HORIZONTAL_ALIGNMENT_LEFT, -1, t3).x
		while an3 > tope3 and t3 > t_min:
			t3 -= 1
			an3 = fuente.get_string_size(marca, HORIZONTAL_ALIGNMENT_LEFT, -1, t3).x
		if an3 <= tope3:
			var x3: float = (w - an3 - 5.0) if texto_pie != "" else (w - an3) * 0.5
			draw_string(fuente, Vector2(x3, centro_banda + float(t3) * 0.36), marca,
				HORIZONTAL_ALIGNMENT_LEFT, -1, t3, Color(0.96, 0.88, 0.62))
			libre = w - an3 - 8.0
		else:
			carrusel = true
			libre = 0.0   # el carrusel ocupa la banda entera: el pie no cabe con el
		# Rodando va a su tamaño NORMAL: achicarlo solo servia para que cupiera quieto, y a letra minima
		# el carrusel no se leia (visto en captura).
		_poner_carrusel_marca(carrusel, y_banda, h, maxi(8, int(h * 0.115)))
	else:
		_poner_carrusel_marca(false, y_banda, h, 0)
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

	# EL ESTADO, siempre por encima de todo. Seleccionada = marco AMBAR, el mismo color con el que se
	# marca el retrato elegido: un solo idioma para "esto es lo que estas mirando" en todo el menu.
	#
	# VA EN DOS TRAZOS Y NO EN UNO. Aqui el fondo de la celda es de un color distinto en cada rareza,
	# asi que un trazo suelto -- de cualquier color -- se pierde contra alguna: el blanco desaparecia
	# sobre el dorado del legendario y el ambar se confunde con el. El de fuera es casi negro y hace
	# de sombra contra el fondo sea cual sea; el de dentro es el ambar, que ya solo tiene que
	# destacar contra ese negro. Asi el marco se lee igual sobre las ocho.
	#
	# Y SIGUE LA SILUETA QUE SE VE, no la del contorno: con tier, el triangulo de la muesca rellena el
	# chaflan y la esquina queda en angulo recto. Siguiendo la diagonal del chaflan, el marco pasaba
	# justo por encima del numero del tier y lo tapaba.
	var marco: PackedVector2Array = _contorno_marco(w, h)
	if HudEstilo.es_pixel() and (button_pressed or _hover or has_focus()):
		# En pixel, el marco va EXACTO por dentro de la silueta (Geometry2D.offset_polygon, no _encoger, que es
		# aproximado y lo dejaba torcido): un canto negro de P y el ambar de 2P por dentro; al pasar por encima, blanco.
		# Y los NUMEROS de las muescas se repintan encima: el marco no los tapa.
		# (06/11, el jefe: "tiene que ser el marco amarillo FUERA del recuadro, rodeando, no dentro") POR FUERA: el ambar de
		# 2P pegado a la silueta, en el hueco entre celdas (6 px en las rejillas), sin tapar nada de la celda.
		if button_pressed:
			_anillo_px(marco, -P, P * 2.0, Color(0.95, 0.72, 0.36, 1.0))
		else:
			_anillo_px(marco, -P * 0.5, P, Color(1, 1, 1, 0.45))
		_numero_tier(w, h)
		if _plus() > 0:
			_numero_plus(w, h, _plus())
	elif button_pressed:
		var g: float = maxf(2.5, w * 0.034)
		draw_polyline(_cerrar(marco), Color(0.03, 0.04, 0.06, 0.92), g * 1.9)
		draw_polyline(_cerrar(_encoger(marco, w, h, g * 0.55)), Color(0.95, 0.72, 0.36, 1.0), g)
	elif _hover or has_focus():
		draw_polyline(_cerrar(marco), Color(1, 1, 1, 0.45), maxf(1.5, w * 0.016))
	if disabled or tenue:
		draw_polygon(borde, PackedColorArray([Color(0.04, 0.05, 0.07, 0.55)]))


# EL CARRUSEL DEL NOMBRE, solo en la celda cuyo nombre no cabe ni con la letra achicada. Es un nodo
# (Label con tween) y no un draw_string porque tiene que moverse y recortarse; por eso se crea SOLO
# cuando hace falta: una rejilla llena son cientos de celdas y casi ninguna lo necesita.
# Se decide en _draw, pero los nodos no se tocan ahi dentro: se monta y se quita en diferido.
var _marca_caja: Control = null
var _marca_texto: String = ""      # con que marca se monto (una celda reutilizada puede cambiarla)
var _marca_pendiente: bool = false

func _poner_carrusel_marca(quiero: bool, _y_banda: float, _h: float, tam: int) -> void:
	if not quiero:
		if _marca_caja != null:
			_quitar_carrusel_marca.call_deferred()
		return
	if _marca_caja != null and _marca_texto == marca:
		_marca_caja.modulate = Color(0.42, 0.43, 0.46) if disabled else Color.WHITE
		return
	if not _marca_pendiente:
		_marca_pendiente = true
		_montar_carrusel_marca.call_deferred(tam)


func _quitar_carrusel_marca() -> void:
	if is_instance_valid(_marca_caja):
		_marca_caja.queue_free()
	_marca_caja = null
	_marca_texto = ""


func _montar_carrusel_marca(tam: int) -> void:
	_marca_pendiente = false
	_quitar_carrusel_marca()
	if marca == "":
		return
	var caja := Control.new()
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Encima de la banda, entre su borde de arriba y la linea de color, con un respiro a los lados. Por
	# anclas: si la celda cambia de tamaño se recoloca sola.
	caja.anchor_left = 0.0
	caja.anchor_right = 1.0
	caja.anchor_top = 1.0 - ALTO_BANDA
	caja.anchor_bottom = 1.0 - ALTO_LINEA
	caja.offset_left = 3.0
	caja.offset_right = -3.0
	# El tamaño de letra por TEMA y no por override: el Label lo crea texto_deslizante por dentro y
	# un override en la caja no le llegaria; un tema si se hereda.
	var tema := Theme.new()
	tema.default_font_size = tam
	caja.theme = tema
	add_child(caja)
	MenuScaffold.texto_deslizante(caja, marca, Color(0.96, 0.88, 0.62))
	_marca_caja = caja
	_marca_texto = marca
	_marca_caja.modulate = Color(0.42, 0.43, 0.46) if disabled else Color.WHITE


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
	draw_colored_polygon(_px(PackedVector2Array([
		Vector2.ZERO, Vector2(m + f, 0.0), Vector2(0.0, m + f)]), Vector2.ZERO), col)
	# Una linea mas clara en el canto de dentro: separa la franja del degradado del fondo, que en las
	# rarezas claras tiran al mismo sitio y se comian el borde.
	if HudEstilo.es_pixel():
		_linea_px(Vector2(m + f, 0.0), Vector2(0.0, m + f), Vector2.ZERO, col.lightened(0.35))
	else:
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
	_numero_tier(w, h)


# El NUMERO del tier en su muesca. Aparte para poder repintarlo ENCIMA del marco de seleccionada (en pixel).
func _numero_tier(w: float, h: float) -> void:
	var tier: int = IconoItem.tier_de(item) if item != null else 0
	if tier <= 0:
		return
	var m: float = minf(w, h) * MUESCA
	var f: float = m * BANDA_TIER
	var col: Color = IconoItem.color_tier(tier)
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


# ------------------------------------------------------------
#  LAS RUNAS EN LA CELDA (08/10/2026, lo pidio el usuario: "algun indicativo de que tiene el set y cuantas sub-stats
#  tiene, en los iconos de todos lados"; eligio la version B de tres). En el lado derecho a media altura (lo unico
#  libre: arriba el tier y el +N, abajo la escalera y la banda): un SELLO del color de la runa de su set con el SIMBOLO
#  del set, y debajo 4 PUNTITOS, encendidos los de las sub-stats que tiene. Sin set, nada.
# ------------------------------------------------------------
# El simbolo de cada set, 7 x 7 (se pinta en claro sobre el sello del color de su runa).
const GLIFO_SET := {
	# (05/11, el jefe: "no hacer unicolor como antes, me ha molado"; "a tu criterio, me molan todos") TODOS A 9 x 9 Y
	# A TRES TONOS (tools/glifos_varios_tonos.py; elegidos la A de cada uno salvo la estrella, la B): '#' blanco, '+' el
	# tono claro del set (su runa aclarada) y '=' su acento (GLIFO_ACENTO).
	&"slime": ["....+....", "...+++...", "..++#++..", ".++#+++=.", ".+#++++=.",
		"++++++++=", "+++++++==", ".+++++==.", "..=====.."],   # Gota (Masa) (A)
	&"profundo": [".........", ".###.....", "#+++#...#", "+===+###+", ".........",
		".###.....", "#+++#...#", "+===+###+", "........."],   # Olas (Marea) (A)
	&"rey": [".........", "#...#...#", "#+..#..+#", "#++###++#", "#+++++++#",
		"++=+=+=++", "+++++++++", "#########", "........."],   # Corona (Corona) (A)
	&"fuego": ["....=....", "...==....", "...=+=...", "..=++=.=.", "..=+#+==.",
		".=+##++=.", "=+####+=.", "=+####+=.", ".=++++==."],   # Llama (Ignición) (A)
	&"venenoso": [".#######.", "#########", "#==###==#", "#==###==#", "####+####",
		".#######.", ".#+#+#+#.", "..+.+.+..", "........."],   # Calavera (Miasma) (A)
	&"abisal": ["....#....", "...#+#...", "..#+++#..", ".#++=++#.", "#++===++#",
		".#++=++#.", "..#+++#..", "...#+#...", "....#...."],   # Estrella (Cielo) (B)
	&"rata": [".#######.", "#=#=#=#=#", "#=#=#=#=#", "#=#=#=#=#", "#=#=#=#=#",
		"#=#=#=#=#", "#=#=#=#=#", "#=#=#=#=#", ".#######."],   # Rejilla (Alcantarilla) (A)
	&"rey_rata": [".........", "#.#.#.#.#", "#########", "#+=+=+=+#", "#########",
		".#.#.#.#.", ".#.#.#.#.", "..#...#..", "........."],   # Colmillos (Sangre real) (A)
	&"jabali": ["....#....", ".#..#..#.", "..#+#+#..", "#..+#+..#", ".#++#++#.",
		"..+=#=+..", "...=#=...", "....=....", "....=...."],   # Helecho (Musgo viejo) (A)
	&"ciempies": ["#.#...#.#", ".#.....#.", "##=...=##", "#+#...#+#", "#+#...#+#",
		"#+#...#+#", ".#+#.#+#.", "..#+#+#..", "...###..."],   # Dos cabezas (Dos mentes) (A)
	&"escarabajo": [".#######.", "#+++++++#", "#+#####+#", "#+#...#+#", "#+#...#+#",
		"#+#...#+#", "#+#...#+#", "===...===", "===...==="],   # Imán (Campo magnético) (A)
	&"trent": ["...###...", "..#+++#..", ".#+#+++#.", "#++=+=++#", "#+++=+++#",
		"#++=+=++#", ".#+++++#.", "..#+++#..", "...###..."],   # Ámbar (Ámbar) (A)
	&"arana": ["....###..", "...##+...", "..##+....", ".#####=..", "...=##=..",
		"...##=...", "..##=....", ".##=.....", ".#......."],   # Rayo (Hilo conductor) (A)
	# (05/11, eligio el jefe de tools/glifos_guadana.py: "esta el peak") la guadaña del set Filo de aire, la I HOJA GRUESA.
	# 9 x 9 y A TRES TONOS: '#' el filo (blanco), '+' la hoja (clara), '=' el mango (madera). Pidio rehacer los demas asi.
	&"segadora": ["...+++++=", ".++++++=.", "++####.=.", "##....=..", "#.....=..", "......=..", ".....=...", ".....=...",
		"....=...."],
}
# El ACENTO de cada set ('='); sin entrada, su runa oscurecida. El tono claro ('+') es su runa aclarada.
const GLIFO_ACENTO := {
	&"rey": Color(0.85, 0.2, 0.25),
	&"fuego": Color(0.75, 0.15, 0.08),
	&"venenoso": Color(0.5, 1.0, 0.25),
	&"abisal": Color(0.6, 0.85, 1.0),
	&"rata": Color(0.15, 0.12, 0.18),
	&"rey_rata": Color(0.9, 0.15, 0.15),
	&"jabali": Color(0.45, 0.32, 0.18),
	&"ciempies": Color(0.25, 0.9, 0.85),
	&"escarabajo": Color(0.85, 0.87, 0.92),
	&"trent": Color(0.35, 0.2, 0.08),
	&"arana": Color(0.95, 0.9, 0.4),
}
# Los TONOS propios de la guadaña (la hoja y el mango de madera); los demas salen de su runa (tonos_glifo).
const GLIFO_TONOS := {"+": Color(0.70, 0.77, 0.75), "=": Color(0.59, 0.46, 0.33)}


static func tonos_glifo(id: StringName, col: Color) -> Dictionary:
	if id == &"segadora":
		return GLIFO_TONOS
	return {"+": col.lightened(0.55), "=": GLIFO_ACENTO.get(id, col.darkened(0.45))}


func _pintar_sello() -> void:
	_marca_runas(_sello, _sello_medidas.x, _sello_medidas.y, _sello_medidas.z)


func _marca_runas(ci: CanvasItem, w: float, h: float, y_banda: float) -> void:
	if item == null or w <= 0.0 or not Runas.admite_runas(item):
		return
	var s: RunaSetData = Runas.set_de(item)
	if s == null:
		return
	var n: int = Runas.subs_de(item).size()
	var col: Color = s.runa.color if s.runa != null else Color(0.6, 0.6, 0.9)
	var m: float = minf(w, h)
	var r: float = m * 0.105
	var c := Vector2(w - r - m * 0.05, y_banda * 0.5)
	# El sello: sombra, disco del color de la runa (apagado para que el blanco de dentro se lea) y aro claro.
	ci.draw_circle(c + Vector2(1.5, 1.5), r, Color(0, 0, 0, 0.45))
	ci.draw_circle(c, r, col.darkened(0.35))
	ci.draw_arc(c, r, 0.0, TAU, 24, col.lightened(0.45), maxf(1.5, m * 0.018), true)
	_glifo(ci, c, r * 1.25, GLIFO_SET.get(s.id, GLIFO_SET[&"slime"]), Color(1, 1, 1, 0.95), tonos_glifo(s.id, col))
	# Los 4 puntitos bajo el sello, encendidos los que tiene (con su borde oscuro: se leen sobre cualquier rareza).
	var paso: float = r * 0.72
	var y: float = c.y + r + m * 0.05
	for i in Runas.MAX_SUBS:
		var p := Vector2(c.x + (float(i) - 1.5) * paso, y)
		ci.draw_circle(p, m * 0.028, Color(0, 0, 0, 0.65))
		ci.draw_circle(p, m * 0.020, col.lightened(0.55) if i < n else Color(1, 1, 1, 0.20))


func _glifo(ci: CanvasItem, c: Vector2, lado: float, filas: Array, tinta: Color, tonos: Dictionary = GLIFO_TONOS) -> void:
	# 7 x 7 los de un color; 9 x 9 los de varios tonos (la guadaña): el mismo lado, pixeles mas finos.
	var px: float = lado / float(maxi(7, filas.size()))
	var x0: float = c.x - lado * 0.5
	var y0: float = c.y - lado * 0.5
	for j in filas.size():
		var f: String = filas[j]
		for i in f.length():
			var ch: String = f[i]
			if ch == "#":
				ci.draw_rect(Rect2(x0 + float(i) * px, y0 + float(j) * px, px, px), tinta)
			elif tonos.has(ch):
				ci.draw_rect(Rect2(x0 + float(i) * px, y0 + float(j) * px, px, px), tonos[ch])


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
	draw_colored_polygon(_px(PackedVector2Array([
		Vector2(w - lado, 0.0), Vector2(w - r, 0.0), Vector2(w, r), Vector2(w, lado)]), Vector2(w, 0.0)), col)
	# La misma linea clara del canto que en el tier: sobre las rarezas claras el color de la muesca y
	# el del fondo tiran al mismo sitio y el borde se perdia.
	if HudEstilo.es_pixel():
		_linea_px(Vector2(w - lado, 0.0), Vector2(w, lado), Vector2(w, 0.0), col.lightened(0.35))
	else:
		draw_line(Vector2(w - lado, 0.0), Vector2(w, lado), col.lightened(0.35), 2.0, true)

	# EL NUMERO, dentro del triangulo y pegado a su lado ancho. El "+" va delante porque es lo que lo
	# distingue del tier de enfrente: sin el, dos numeros sueltos en las dos esquinas se leen como si
	# midieran lo mismo.
	_numero_plus(w, h, n)
	return lado


# El NUMERO del +N en su muesca (aparte, como el del tier, para repintarlo encima del marco).
func _numero_plus(w: float, h: float, n: int) -> void:
	var col: Color = IconoItem.color_mejora(n)
	var lado: float = minf(w, h) * (MUESCA + MUESCA * BANDA_TIER)
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


# El contorno de la celda: rectangulo con la esquina superior izquierda MUY achaflanada (la muesca,
# que es la marca de la casa) y las otras tres apenas matadas. Va en sentido horario desde el final
# de la muesca.
func _contorno(w: float, h: float) -> PackedVector2Array:
	return _px(_contorno_crudo(w, h), Vector2(w, h) * 0.5)


func _contorno_crudo(w: float, h: float) -> PackedVector2Array:
	var m: float = minf(w, h) * MUESCA
	var r: float = minf(w, h) * REDONDEO
	return PackedVector2Array([
		Vector2(m, 0.0), Vector2(w - r, 0.0), Vector2(w, r),        # arriba y esquina der.
		Vector2(w, h - r), Vector2(w - r, h),                        # abajo derecha
		Vector2(r, h), Vector2(0.0, h - r),                          # abajo izquierda
		Vector2(0.0, m),                                             # sube hasta la muesca
	])


# ------------------------------------------------------------
#  EN PIXEL (06/11, rework visual: "las celdas de objetos, pixel"): con el estilo pixel de mazmorra (HudEstilo) cada
#  lado en DIAGONAL se vuelve una ESCALERA de pixeles de P, hacia dentro de la celda (cada peldaño elige la esquina mas
#  cercana a 'centro'). Lo usan el contorno, la muesca del tier y la del +N, asi que el fondo, la banda del pie y los
#  marcos salen en pixel solos. Los colores no cambian: la rareza y el tier se leen igual.
# ------------------------------------------------------------
const P := 2.0

static func _px(poly: PackedVector2Array, centro: Vector2) -> PackedVector2Array:
	if not HudEstilo.es_pixel():
		return poly
	var out := PackedVector2Array()
	var n: int = poly.size()
	for i in n:
		_tramo(poly[i], poly[(i + 1) % n], centro, out)
	# SIN PUNTOS REPETIDOS SEGUIDOS: al ajustar a la rejilla salen, y con ellos draw_colored_polygon no triangula y no
	# pinta nada, sin avisar (las franjas del fondo no salian).
	var limpio := PackedVector2Array()
	for v in out:
		if limpio.is_empty() or not limpio[limpio.size() - 1].is_equal_approx(v):
			limpio.append(v)
	while limpio.size() > 1 and limpio[0].is_equal_approx(limpio[limpio.size() - 1]):
		limpio.remove_at(limpio.size() - 1)
	# (06/11) Y SIN PUNTOS EN LINEA: la escalera de un lado muy corto va y vuelve sobre la misma recta (un pico de grosor
	# cero) y con eso Godot tampoco triangula ("Invalid polygon data, triangulation failed", ~790 veces al abrir el
	# inventario). Un punto alineado con sus dos vecinos no cambia la forma, asi que se quita.
	var cambio := true
	while cambio and limpio.size() > 3:
		cambio = false
		for i in limpio.size():
			var a0: Vector2 = limpio[(i - 1 + limpio.size()) % limpio.size()]
			var b0: Vector2 = limpio[i]
			var c0: Vector2 = limpio[(i + 1) % limpio.size()]
			if absf((b0 - a0).cross(c0 - b0)) < 0.001:
				limpio.remove_at(i)
				cambio = true
				break
	return limpio

# Añade a 'out' el lado de 'a' a 'b' en escalera: 'a' y los peldaños, sin 'b' (que es el principio del siguiente).
static func _tramo(a: Vector2, b: Vector2, centro: Vector2, out: PackedVector2Array) -> void:
	a = a.snapped(Vector2(P, P))
	b = b.snapped(Vector2(P, P))
	out.append(a)
	if is_equal_approx(a.x, b.x) or is_equal_approx(a.y, b.y):
		return
	var pasos: int = maxi(1, roundi(maxf(absf(b.x - a.x), absf(b.y - a.y)) / P))
	var prev: Vector2 = a
	for k in range(1, pasos + 1):
		var q: Vector2 = a.lerp(b, float(k) / float(pasos)).snapped(Vector2(P, P))
		var c1 := Vector2(q.x, prev.y)
		var c2 := Vector2(prev.x, q.y)
		out.append(c1 if c1.distance_squared_to(centro) < c2.distance_squared_to(centro) else c2)
		if k < pasos:
			out.append(q)
		prev = q


# EL FONDO EN FRANJAS (pixel): el mismo recorrido de color que el degradado, de oscuro abajo-izquierda a claro
# arriba-derecha, pero en FRANJAS planas con el borde en escalera, que es como se pinta un degradado en pixel art.
const FRANJAS := 5

func _fondo_franjas(borde: PackedVector2Array, w: float, h: float, oscuro: Color, claro: Color) -> void:
	draw_colored_polygon(borde, oscuro.lerp(claro, 0.5 / float(FRANJAS)))
	for k in range(1, FRANJAS):
		# Lo que queda por encima de la diagonal u - v = d (u = x/w, v = y/h): la mitad clara.
		var d: float = 2.0 * float(k) / float(FRANJAS) - 1.0
		var p0 := Vector2(d, 0.0)
		var l := Vector2(1.0, 1.0) * 3.0
		var nrm := Vector2(1.0, -1.0) * 3.0
		var semi := PackedVector2Array()
		for q in [p0 - l, p0 + l, p0 + l + nrm, p0 - l + nrm]:
			semi.append(Vector2(q.x * w, q.y * h))
		var col: Color = oscuro.lerp(claro, (float(k) + 0.5) / float(FRANJAS))
		for trozo in Geometry2D.intersect_polygons(borde, semi):
			var c := Vector2.ZERO
			for v in trozo:
				c += v
			var esc: PackedVector2Array = _px(trozo, c / float(maxi(trozo.size(), 1)))
			# Si la escalera de un trozo diminuto no se puede triangular, el trozo tal cual (sin escalera): un punto de
			# color mal puesto no se ve; el error en la consola, cada vez que se pinta una celda, si.
			if esc.size() < 3 or Geometry2D.triangulate_polygon(esc).is_empty():
				esc = trozo
			if esc.size() >= 3 and not Geometry2D.triangulate_polygon(esc).is_empty():
				draw_colored_polygon(esc, col)


# Un anillo de 'grueso' a 'dentro' px por dentro del contorno 'poly', sin suavizar (el marco de seleccionada en pixel).
func _anillo_px(poly: PackedVector2Array, dentro: float, grueso: float, col: Color) -> void:
	var hechos: Array = Geometry2D.offset_polygon(poly, -dentro, Geometry2D.JOIN_MITER)
	if hechos.is_empty():
		return
	draw_polyline(_cerrar(hechos[0]), col, grueso, false)


# Una linea en escalera de 'a' a 'b' (el canto claro de las muescas), hacia 'centro'.
func _linea_px(a: Vector2, b: Vector2, centro: Vector2, col: Color) -> void:
	var tramo := PackedVector2Array()
	_tramo(a, b, centro, tramo)
	tramo.append(b.snapped(Vector2(P, P)))
	draw_polyline(tramo, col, P, false)


# Por donde va el MARCO de seleccionada/hover. Sin tier es el contorno de siempre; con tier, el
# triangulo de la muesca tapa el chaflan (llega hasta la esquina, ver _muesca_tier) y lo que se ve es
# una esquina en angulo recto, asi que el marco la rodea por fuera en vez de cortar el triangulo.
func _contorno_marco(w: float, h: float) -> PackedVector2Array:
	var c: PackedVector2Array = _contorno_crudo(w, h)
	if item == null or IconoItem.tier_de(item) <= 0:
		return _px(c, Vector2(w, h) * 0.5)
	# El contorno empieza en (m, 0) y acaba en (0, m): la esquina va entre esos dos, cerrando el recorrido.
	# (06/11) Se añade ANTES de la escalera: añadida despues, la escalera del chaflan ya estaba hecha y el marco
	# cortaba la muesca en diagonal en vez de rodear la esquina.
	c.append(Vector2.ZERO)
	return _px(c, Vector2(w, h) * 0.5)


# El mismo contorno metido 'd' pixeles hacia DENTRO. Se hace tirando cada vertice hacia el centro de
# la celda, que no es el encogido exacto de un poligono (las esquinas se meten un pelin de mas) pero
# a esta escala no se distingue y no hay que calcular bisectrices para un marco de 3 px.
func _encoger(p: PackedVector2Array, w: float, h: float, d: float) -> PackedVector2Array:
	var centro := Vector2(w, h) * 0.5
	var radio: float = minf(w, h) * 0.5
	var k: float = clampf(1.0 - d / maxf(radio, 1.0), 0.0, 1.0)
	var out := PackedVector2Array()
	for v in p:
		out.append(centro + (v - centro) * k)
	return out


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
