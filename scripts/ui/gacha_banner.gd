# ============================================================
#  gacha_banner.gd  --  EL CARTEL de la Meditacion.
#
#  La pantalla principal del gacha, con el molde del banner de ARMAS (no el de personaje): el
#  PREMIO en grande, no quien tira. En el de personaje manda la ilustracion del muñeco; aqui manda
#  el objeto, que es lo que se viene a buscar.
#
#  EL REPARTO, medido de la referencia:
#    - Arriba a la izquierda, la cinta y el NOMBRE del banner.
#    - Debajo, el texto del garantizado.
#    - Abajo a la izquierda, un ABANICO de tomos pequeños: los de la banda del garantizado, o sea
#      lo que te llevas cada tantas tiradas. Son los "secundarios destacados".
#    - En el centro-derecha, EL TOMO GORDO: el mas raro que puede caer. Con su nombre y sus
#      estrellas al lado, no debajo -- al lado es donde caben sin apretar la carta.
#    - Fuera del lienzo: "Ver detalles" abajo a la izquierda y los dos botones de tirar abajo a la
#      derecha, que es donde estan en todos.
#
#  NADA DE ESTO ESTA ESCRITO A MANO. El destacado es el de mas rareza DEL POOL y los del abanico son
#  los de la banda del garantizado: el dia que entre un grimorio mitico nuevo, el cartel cambia solo.
#  Un cartel con el nombre del premio a pelo es de las cosas que se quedan mintiendo un año.
#
#  Se dibuja POR CODIGO, como el resto del arte del juego: no hay ilustracion que poner, asi que el
#  tomo es una carta pintada a mano alzada con el color de su rareza (ver dibujar_tomo).
# ============================================================

extends Control

const Iconos = preload("res://scripts/ui/iconos.gd")

const AMBAR := Color(0.95, 0.72, 0.36)
const GRIS := Color(0.6, 0.63, 0.7)

# EL NOMBRE DEL BANNER. PLACEHOLDER: el tono de los textos lo decide el, no yo. Puesto aqui solo
# para que la pantalla no salga con un hueco.
const BANNER_NOMBRE := "El círculo de la tormenta"

# La medida del lienzo y de la carta grande, sobre las unidades logicas de 1280x720 (project.godot).
const LIENZO_MARGEN_X := 24.0
# 206 y no 184: los retratos van de 104 a 198 (ver maestro_menu._caja_arriba_med), y con el lienzo
# mas arriba el cartel les mordia los pies.
const LIENZO_ARRIBA := 206.0
const LIENZO_ABAJO := 636.0
const CARTA_ANCHO := 300.0
const CARTA_ALTO := 360.0
# El abanico: tres cartas pequeñas, la del medio recta y las otras dos abiertas hacia fuera.
const MINI_ANCHO := 92.0
const MINI_ALTO := 124.0
const MINI_GIRO := 0.20      # radianes que se abre cada una de las laterales

var _pj: PersonajeData = null
var _pool: Array = []
var _lienzo: PanelContainer = null


# Monta el cartel dentro de 'padre'. Los tres Callable son los botones: no los conoce el cartel,
# los pone quien lo usa (asi esto no depende del menu del maestro para nada).
func montar(padre: Control) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# POR ENCIMA DE LOS MUÑECOS. Los retratos llevan dentro un MunecoJugador con z ABSOLUTO de hasta
	# 2048 (ver muneco_jugador.gd), y con z absoluto se dibujan encima de cualquier Control de z 0
	# este donde este en el arbol. Sin esto, una cara se colaba sobre el cartel.
	z_index = 2500
	padre.add_child(self)


# Repinta con quien medita y con el pool de hoy. Se llama en cada _rebuild: el cartel no guarda
# estado propio, para que no pueda quedarse enseñando el destacado de otra partida.
func refrescar(pj: PersonajeData, pool: Array) -> void:
	_pj = pj
	_pool = pool
	for h in get_children():
		remove_child(h)
		h.queue_free()
	_montar_lienzo()


func _montar_lienzo() -> void:
	_lienzo = PanelContainer.new()
	_lienzo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lienzo.offset_left = LIENZO_MARGEN_X
	_lienzo.offset_right = -LIENZO_MARGEN_X
	_lienzo.offset_top = LIENZO_ARRIBA
	_lienzo.offset_bottom = -(720.0 - LIENZO_ABAJO)
	_lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caja := StyleBoxFlat.new()
	caja.bg_color = Color(0.07, 0.08, 0.13, 1.0)
	caja.border_color = Color(1, 1, 1, 0.10)
	caja.set_border_width_all(1)
	caja.set_corner_radius_all(10)
	_lienzo.add_theme_stylebox_override("panel", caja)
	add_child(_lienzo)

	# EL FONDO DEL CARTEL, detrás de todo: un resplandor del color del destacado. Es lo que hace que
	# el cartel de un mitico y el de un raro no se vean iguales sin leer nada.
	var fondo := Control.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lienzo.add_child(fondo)
	var col_dest: Color = _color_destacado()
	fondo.draw.connect(_dibujar_fondo.bind(fondo, col_dest))

	_montar_texto(fondo)
	_montar_abanico(fondo)
	_montar_destacado(fondo)


# --- EL RESPLANDOR DEL FONDO ---
# Circulos concentricos muy tenues centrados donde va la carta. Es barato (no hay textura ni shader)
# y basta para que el centro-derecha "pese" mas que el resto, que es lo que hace el degradado de la
# referencia.
func _dibujar_fondo(c: Control, col: Color) -> void:
	var centro := Vector2(c.size.x * 0.68, c.size.y * 0.5)
	for i in range(10, 0, -1):
		var t: float = float(i) / 10.0
		c.draw_circle(centro, 90.0 + t * 250.0, Color(col.r, col.g, col.b, 0.030 * (1.0 - t) + 0.004))


# --- LA COLUMNA DE TEXTO: cinta, nombre del banner y el garantizado ---
func _montar_texto(padre: Control) -> void:
	var col := VBoxContainer.new()
	col.position = Vector2(22, 18)
	col.custom_minimum_size = Vector2(360, 0)
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(col)

	# LA CINTA. Un Label con fondo propio, como la etiqueta azul de la referencia.
	var cinta := Label.new()
	cinta.text = "  MEDITACIÓN  "
	cinta.add_theme_font_size_override("font_size", 11)
	cinta.add_theme_color_override("font_color", Color(0.06, 0.07, 0.10))
	var sb := StyleBoxFlat.new()
	sb.bg_color = AMBAR
	sb.set_corner_radius_all(4)
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	cinta.add_theme_stylebox_override("normal", sb)
	cinta.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(cinta)

	var titulo := Label.new()
	titulo.text = BANNER_NOMBRE
	titulo.add_theme_font_size_override("font_size", 28)
	titulo.add_theme_color_override("font_color", Color(0.93, 0.94, 0.98))
	col.add_child(titulo)

	var hueco := Control.new()
	hueco.custom_minimum_size = Vector2(0, 10)
	col.add_child(hueco)

	# EL GARANTIZADO, derivado de las constantes. Escribir "50" y "200" aqui es la forma clasica de
	# que el cartel siga prometiendo lo de antes cuando se muevan los escalones.
	_linea(col, "Cada %d meditaciones, un grimorio épico o mejor."
		% Game.GACHA_PITY_EPICO, GRIS, 13)
	_linea(col, "Cada %d, uno legendario o mejor."
		% Game.GACHA_PITY_LEGENDARIO, GRIS, 13)
	_linea(col, "Se cuentan tiradas: la suerte no retrasa el garantizado.", Color(0.45, 0.48, 0.56), 11)


func _linea(vb: BoxContainer, txt: String, col: Color, tam: int) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(340, 0)
	vb.add_child(l)


# --- EL ABANICO: los de la banda del garantizado ---
# En la referencia son las cartas que te llevas cada diez tiradas. Aqui son los EPICOS, que es lo
# que asegura el escalon de 50.
func _montar_abanico(padre: Control) -> void:
	var epicos: Array = _de_rareza(Upgrades.Rareza.EPICO, false)
	if epicos.is_empty():
		return
	var titulo := Label.new()
	titulo.text = "TAMBIÉN DESTACAN"
	titulo.position = Vector2(22, 250)
	titulo.add_theme_font_size_override("font_size", 11)
	titulo.add_theme_color_override("font_color", AMBAR)
	padre.add_child(titulo)

	# TRES COMO MUCHO: es un adorno que dice "de esta banda hay varios", no un catalogo. La lista
	# entera esta en el modal de detalles, que es donde se va a mirar.
	var cuantos: int = mini(3, epicos.size())
	var centro := Vector2(120, 350)
	for i in cuantos:
		var s: SpellData = epicos[i]
		var mini_c := Control.new()
		mini_c.custom_minimum_size = Vector2(MINI_ANCHO, MINI_ALTO)
		mini_c.size = Vector2(MINI_ANCHO, MINI_ALTO)
		mini_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# El pivote en el centro para que el giro las abra en abanico y no las mande de paseo.
		mini_c.pivot_offset = Vector2(MINI_ANCHO, MINI_ALTO) * 0.5
		var desvio: float = float(i) - float(cuantos - 1) * 0.5
		mini_c.position = centro + Vector2(desvio * 58.0, absf(desvio) * 10.0) \
			- Vector2(MINI_ANCHO, MINI_ALTO) * 0.5
		mini_c.rotation = desvio * MINI_GIRO
		padre.add_child(mini_c)
		mini_c.draw.connect(dibujar_tomo.bind(mini_c, Upgrades.rareza_color(int(s.rareza)), false, FAM_GRIMORIO))


# --- EL DESTACADO: la carta gorda y su nombre ---
func _montar_destacado(padre: Control) -> void:
	var s: SpellData = _mejor_del_pool()
	if s == null:
		return
	var col: Color = Upgrades.rareza_color(int(s.rareza))

	# LA CARTA, centro-derecha. Se colocan por ANCLA y no por posicion fija: el lienzo se estira con
	# la ventana (ver MenuScaffold y las unidades logicas), y con una x escrita a pelo la carta se
	# despegaba del resplandor del fondo en cuanto la ventana cambiaba de proporcion.
	var carta := Control.new()
	carta.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	carta.custom_minimum_size = Vector2(CARTA_ANCHO, CARTA_ALTO)
	carta.size = Vector2(CARTA_ANCHO, CARTA_ALTO)
	carta.offset_left = -CARTA_ANCHO - 90.0
	carta.offset_right = -90.0
	carta.offset_top = -CARTA_ALTO * 0.5
	carta.offset_bottom = CARTA_ALTO * 0.5
	carta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(carta)
	carta.draw.connect(dibujar_tomo.bind(carta, col, true, FAM_GRIMORIO))

	# EL NOMBRE Y LAS ESTRELLAS, A LA IZQUIERDA de la carta y no debajo: debajo hay que estrechar la
	# carta para que quepan las dos cosas, y la carta es lo que se ha venido a ver.
	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	caja.offset_left = -CARTA_ANCHO - 400.0
	caja.offset_right = -CARTA_ANCHO - 110.0
	caja.offset_top = -40.0
	caja.offset_bottom = 40.0
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 4)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(caja)

	var nom := Label.new()
	nom.text = s.nombre
	nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	nom.add_theme_font_size_override("font_size", 24)
	nom.add_theme_color_override("font_color", col)
	nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(nom)

	# LAS ESTRELLAS sobre una banda oscura, como en la referencia. Cuentan desde 1 (comun = una),
	# asi que el mitico saca seis.
	var estrellas := Label.new()
	estrellas.text = "★".repeat(int(s.rareza) + 1)
	estrellas.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	estrellas.add_theme_font_size_override("font_size", 15)
	estrellas.add_theme_color_override("font_color", col)
	var banda := StyleBoxFlat.new()
	banda.bg_color = Color(0.04, 0.04, 0.06, 0.75)
	banda.set_corner_radius_all(4)
	banda.content_margin_left = 10
	banda.content_margin_right = 10
	banda.content_margin_top = 3
	banda.content_margin_bottom = 3
	estrellas.add_theme_stylebox_override("normal", banda)
	caja.add_child(estrellas)

	var pie := Label.new()
	pie.text = _nombre_rareza(int(s.rareza)) + "  ·  lo más raro que puede caer"
	pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pie.add_theme_font_size_override("font_size", 11)
	pie.add_theme_color_override("font_color", GRIS)
	caja.add_child(pie)


# --- EL DIBUJO DE UN TOMO ---
# Una carta con el tomo dentro. 'gordo' es la del destacado: lleva halo, doble marco y el canto de
# las hojas mas marcado. Las pequeñas del abanico van con lo justo, que a 92 px el detalle se
# convierte en suciedad.
# 'familia' dice QUE CLASE de libro es, y va aparte del color a proposito:
#   FAM_CURIOSIDAD (0) -> sin marca
#   FAM_SABIDURIA  (1) -> una chispa
#   FAM_GRIMORIO   (2) -> el rombo del emblema
# EL COLOR Y LAS ESTRELLAS DICEN LA RAREZA; LA MARCA DICE LA FAMILIA. Cuando las dos cosas iban por
# el color, un tomo de sabiduria (teal, vistoso) parecia mejor premio que un GRIMORIO comun (gris),
# y es al reves: cualquier grimorio vale mas que un tocho. Separandolas, el rombo dice "esto enseña
# un hechizo" aunque su gris sea el mas apagado de la escala.
const FAM_CURIOSIDAD := 0
const FAM_SABIDURIA := 1
const FAM_GRIMORIO := 2

func dibujar_tomo(c: Control, col: Color, gordo: bool, familia: int = FAM_CURIOSIDAD) -> void:
	var w: float = c.size.x
	var h: float = c.size.y
	var r := Rect2(Vector2.ZERO, Vector2(w, h))

	# EL HALO, solo en la gorda: unas capas de color muy flojas por fuera del marco. Es lo que hace
	# que la carta parezca encendida en vez de pegada sobre el fondo.
	if gordo:
		for i in range(6, 0, -1):
			var t: float = float(i) / 6.0
			var m: float = t * 22.0
			c.draw_rect(Rect2(Vector2(-m, -m), Vector2(w + m * 2.0, h + m * 2.0)),
				Color(col.r, col.g, col.b, 0.05 * (1.0 - t)), true)

	# EL CUERPO de la carta: oscuro, con un tinte del color de la rareza para que se note de lejos.
	c.draw_rect(r, Color(col.r * 0.16 + 0.05, col.g * 0.16 + 0.05, col.b * 0.16 + 0.07, 1.0), true)
	# LAS BANDAS: un degradado a base de franjas horizontales, de arriba (mas claro) a abajo. Sin
	# textura ni shader. VEINTICUATRO y no doce: con doce se veian los escalones como rayas, que en
	# una carta de 360 px de alto son bandas de 30 px y cantan.
	var franjas: int = 24
	for i in franjas:
		var t2: float = float(i) / float(franjas)
		c.draw_rect(Rect2(Vector2(0, h * t2), Vector2(w, h / float(franjas) + 1.0)),
			Color(col.r, col.g, col.b, 0.13 * (1.0 - t2)), true)
	# EL MARCO.
	c.draw_rect(r, Color(col.r, col.g, col.b, 0.85), false, 2.0 if gordo else 1.0)
	if gordo:
		var m2: float = 8.0
		c.draw_rect(Rect2(Vector2(m2, m2), Vector2(w - m2 * 2.0, h - m2 * 2.0)),
			Color(1, 1, 1, 0.12), false, 1.0)

	# EL TOMO, centrado.
	#
	# DOS DIBUJOS DISTINTOS, y no el mismo escalado:
	#   - GORDO: portada propia (ver _dibujar_portada). Iconos.libro es un icono de 24 px, y ampliado
	#     a 200 se lee como un icono gigante -- cuatro rayas planas -- en vez de como la portada de un
	#     grimorio. A tamaño de cartel hace falta detalle que a 24 px seria suciedad.
	#   - PEQUEÑO: Iconos.libro tal cual, que para eso esta pensado. Meterle nervios y cantoneras a
	#     una carta de 92 px la convierte en una mancha (es lo que ya avisa el comentario de Iconos).
	if gordo:
		var pw: float = w * 0.60
		var ph: float = h * 0.68
		_dibujar_portada(c, Rect2(Vector2((w - pw) * 0.5, (h - ph) * 0.5), Vector2(pw, ph)), col)
		return

	# EL LADO NO ES EL TAMAÑO DEL LIBRO: Iconos.libro recibe la caja CUADRADA que lo contiene y
	# dibuja dentro con sus margenes -- ocupa el 52% del lado a lo ancho y el 60% a lo alto. Pasarle
	# min(w,h)*0.62 dejaba un librito del 32% del ancho perdido en una carta enorme, que es
	# exactamente como salio la primera captura. Asi que la cuenta va AL REVES: se parte de cuanto se
	# quiere que ocupe el dibujo y se despeja el lado.
	const OCUPA_ANCHO := 0.52     # lo que mide el libro dentro de la caja, a lo ancho
	const OCUPA_ALTO := 0.60      # y a lo alto
	var lado: float = minf(w * 0.62 / OCUPA_ANCHO, h * 0.56 / OCUPA_ALTO)
	var pos := Vector2((w - lado) * 0.5, (h - lado) * 0.5)
	Iconos.libro(c, pos, lado, Color(col.r, col.g, col.b, 0.95))

	# LA MARCA DE LA FAMILIA, sobre la tapa. Sin ella los tres tipos de libro eran el mismo dibujo y
	# solo se distinguian leyendo el nombre.
	var marca := Color(col.r, col.g, col.b, 0.95)
	var cen := Vector2(w * 0.53, pos.y + lado * 0.42)
	if familia == FAM_GRIMORIO:
		# EL ROMBO, el mismo emblema que lleva la portada del destacado: es lo que dice "esto enseña
		# un hechizo", y por eso lo llevan TODOS los grimorios, hasta el mas comun.
		var rad: float = lado * 0.10
		var rombo := PackedVector2Array([
			cen + Vector2(0, -rad), cen + Vector2(rad * 0.72, 0),
			cen + Vector2(0, rad), cen + Vector2(-rad * 0.72, 0)])
		c.draw_colored_polygon(rombo, Color(col.r, col.g, col.b, 0.35))
		c.draw_polyline(rombo + PackedVector2Array([rombo[0]]), marca, maxf(1.0, lado * 0.012), true)
	elif familia == FAM_SABIDURIA:
		_dibujar_chispa(c, cen, lado * 0.09, marca)


# UNA CHISPA de cuatro puntas: dos husos cruzados. Es la marca de "esto enseña algo".
func _dibujar_chispa(c: Control, cen: Vector2, rad: float, col: Color) -> void:
	var fino: float = rad * 0.32
	c.draw_colored_polygon(PackedVector2Array([
		cen + Vector2(0, -rad), cen + Vector2(fino, 0),
		cen + Vector2(0, rad), cen + Vector2(-fino, 0)]), col)
	c.draw_colored_polygon(PackedVector2Array([
		cen + Vector2(-rad, 0), cen + Vector2(0, -fino),
		cen + Vector2(rad, 0), cen + Vector2(0, fino)]), col)


# EL DORSO: lo que se ve antes de voltear. Es IGUAL PARA TODAS y a proposito no lleva ni una pista
# del color de la rareza -- si el dorso de un mitico se distinguiera, el volteo no tendria gracia
# porque ya sabrias lo que hay antes de darle la vuelta.
func dibujar_dorso(c: Control) -> void:
	var w: float = c.size.x
	var h: float = c.size.y
	var r := Rect2(Vector2.ZERO, Vector2(w, h))
	var tinta := Color(0.30, 0.32, 0.42, 1.0)

	c.draw_rect(r, Color(0.09, 0.10, 0.15, 1.0), true)
	c.draw_rect(r, tinta, false, 2.0)
	var m: float = w * 0.07
	c.draw_rect(Rect2(Vector2(m, m), Vector2(w - m * 2.0, h - m * 2.0)),
		Color(tinta.r, tinta.g, tinta.b, 0.5), false, 1.0)

	# LA VELA, que es el icono de la Meditación en la barra de secciones: el dorso dice de que baraja
	# es, no que carta es.
	var lado: float = minf(w, h) * 0.42
	Iconos.vela(c, Vector2((w - lado) * 0.5, (h - lado) * 0.5), lado,
		Color(tinta.r, tinta.g, tinta.b, 0.85))


# LA PORTADA DEL TOMO DESTACADO, a tamaño de cartel. Todo por codigo, como el resto del arte.
#
# Las piezas, y por que cada una: el LOMO con sus nervios es lo que lo hace libro encuadernado y no
# caja; el CANTO de hojas asomando por la derecha da el grosor; las CANTONERAS metalicas en las
# esquinas son lo que dice "tomo caro" de un vistazo; y el EMBLEMA del centro es el sitio donde el
# ojo aterriza, que si no la portada es un rectangulo vacio.
func _dibujar_portada(c: Control, r: Rect2, col: Color) -> void:
	var w: float = r.size.x
	var h: float = r.size.y
	var o: Vector2 = r.position
	var claro := Color(col.r, col.g, col.b, 0.95)
	var medio := Color(col.r * 0.55 + 0.06, col.g * 0.55 + 0.06, col.b * 0.55 + 0.08, 1.0)
	var oscuro := Color(col.r * 0.22 + 0.04, col.g * 0.22 + 0.04, col.b * 0.22 + 0.06, 1.0)

	# EL CANTO DE LAS HOJAS: un bloque claro asomando por la derecha, con sus rayas. Va PRIMERO,
	# debajo de la tapa, que es como se apilan de verdad.
	var canto: float = w * 0.06
	c.draw_rect(Rect2(o + Vector2(w - canto * 0.4, h * 0.03),
		Vector2(canto, h * 0.94)), Color(0.86, 0.84, 0.78, 0.55), true)
	for i in 9:
		var y: float = o.y + h * (0.08 + 0.10 * float(i))
		c.draw_line(Vector2(o.x + w - canto * 0.4, y), Vector2(o.x + w + canto * 0.6, y),
			Color(0.2, 0.19, 0.17, 0.45), 1.0, true)

	# LA TAPA.
	c.draw_rect(Rect2(o, Vector2(w, h)), oscuro, true)
	c.draw_rect(Rect2(o, Vector2(w, h)), claro, false, maxf(2.0, w * 0.016))
	# El filete interior, a un pelo del borde: es el detalle que da empaque a una encuadernacion.
	var m: float = w * 0.07
	c.draw_rect(Rect2(o + Vector2(m, m), Vector2(w - m * 2.0, h - m * 2.0)),
		Color(col.r, col.g, col.b, 0.40), false, maxf(1.0, w * 0.008))

	# EL LOMO, pegado al canto izquierdo, con sus NERVIOS.
	var lomo: float = w * 0.17
	c.draw_rect(Rect2(o, Vector2(lomo, h)), medio, true)
	c.draw_line(o + Vector2(lomo, 0), o + Vector2(lomo, h), claro, maxf(1.5, w * 0.010), true)
	for i in 4:
		var ny: float = o.y + h * (0.16 + 0.22 * float(i))
		c.draw_line(Vector2(o.x, ny), Vector2(o.x + lomo, ny), claro, maxf(1.5, w * 0.012), true)

	# LAS CANTONERAS: una L en cada esquina de la tapa (menos donde pisa el lomo).
	var cl: float = w * 0.17
	var cg: float = maxf(2.0, w * 0.020)
	for esq in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var px: float = o.x + (lomo + m * 0.4 if esq.x > 0 else w - m * 0.4)
		var py: float = o.y + (m * 0.4 if esq.y > 0 else h - m * 0.4)
		c.draw_line(Vector2(px, py), Vector2(px + cl * esq.x, py), claro, cg, true)
		c.draw_line(Vector2(px, py), Vector2(px, py + cl * esq.y), claro, cg, true)

	# EL EMBLEMA: un rombo con su destello. Es donde aterriza el ojo.
	var cen := o + Vector2(w * 0.58, h * 0.5)
	var rad: float = w * 0.20
	var rombo := PackedVector2Array([
		cen + Vector2(0, -rad), cen + Vector2(rad * 0.72, 0),
		cen + Vector2(0, rad), cen + Vector2(-rad * 0.72, 0)])
	c.draw_colored_polygon(rombo, Color(col.r, col.g, col.b, 0.30))
	c.draw_polyline(rombo + PackedVector2Array([rombo[0]]), claro, maxf(1.5, w * 0.012), true)
	# Los dos brazos del destello, cortos: una cruz larga se lee como "mas" y no como brillo.
	c.draw_line(cen - Vector2(rad * 0.42, 0), cen + Vector2(rad * 0.42, 0), claro,
		maxf(1.0, w * 0.008), true)
	c.draw_line(cen - Vector2(0, rad * 0.42), cen + Vector2(0, rad * 0.42), claro,
		maxf(1.0, w * 0.008), true)


# --- DE DONDE SALE LO QUE SE ENSEÑA ---

# El hechizo MAS RARO que puede caer. Si empatan varios en la banda de arriba, el primero: son el
# mismo cartel a efectos de lo que promete.
func _mejor_del_pool() -> SpellData:
	var mejor: SpellData = null
	for s in _pool:
		if s == null:
			continue
		if mejor == null or int(s.rareza) > int(mejor.rareza):
			mejor = s
	return mejor


# Los de una rareza. Con 'exacta' en false coge los de esa banda Y LOS DE ARRIBA... salvo el
# destacado, que ya sale en grande y repetirlo en el abanico seria enseñar dos veces lo mismo.
func _de_rareza(minimo: int, exacta: bool) -> Array:
	var mejor: SpellData = _mejor_del_pool()
	var out: Array = []
	for s in _pool:
		if s == null or s == mejor:
			continue
		var r: int = int(s.rareza)
		if (r == minimo) if exacta else (r >= minimo):
			out.append(s)
	return out


func _color_destacado() -> Color:
	var s: SpellData = _mejor_del_pool()
	return Upgrades.rareza_color(int(s.rareza)) if s != null else AMBAR


func _nombre_rareza(r: int) -> String:
	var n := ["Común", "Poco común", "Raro", "Épico", "Legendario", "Mítico", "Obra maestra",
		"Prístino"]
	return n[r] if r >= 0 and r < n.size() else "?"
