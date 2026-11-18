# ============================================================
#  hud_estilo.gd  (06/11, rework del HUD: se prueban DOS estilos y el jefe elige)
#  El aspecto del HUD en UN SOLO SITIO: los colores de vida, energia y mana, los paneles (registro, ficha del
#  apuntado), los botones de las acciones y las barras. Dos estilos:
#   - PIXEL ("pixel de mazmorra"): marcos de hierro con remaches dibujados a pixeles (caja_pixel.gd).
#   - MODERNO (al estilo de Honkai: Star Rail): paneles finos con una linea de color, botones redondos y las
#     acciones EN ANILLO alrededor de un Atacar grande (anillo_acciones.gd), a mano del pulgar en el movil.
#  Y los RETRATOS en la fila del grupo, que se prueban con y sin.
#
#  ELEGIDO EL 06/11: PIXEL CON RETRATOS (es lo que sale sin tocar nada). El moderno se queda por si va a Ajustes, y
#  para sacar capturas se cambia con variables de entorno (HUD_ESTILO=moderno, HUD_RETRATOS=0).
#  Sin class_name a proposito (un class_name nuevo pide reimportar en el editor): se carga con preload.
# ============================================================
extends RefCounted

const CajaPixel = preload("res://scripts/ui/caja_pixel.gd")

enum Estilo { PIXEL, MODERNO }

static var estilo: int = Estilo.MODERNO if OS.get_environment("HUD_ESTILO") == "moderno" else Estilo.PIXEL
static var retratos: bool = OS.get_environment("HUD_RETRATOS") != "0"

# LOS COLORES DE LAS BARRAS, menos chillones (06/11: "al ser opaco los colores son demasiado fuertes"). Van por
# self_modulate sobre un relleno gris, asi que esto es el tinte, no el color final.
const VIDA := Color(0.80, 0.36, 0.38)
const ENERGIA := Color(0.46, 0.72, 0.50)
const MANA := Color(0.44, 0.60, 0.90)
const SIN_FUELLE := Color(0.82, 0.48, 0.40)   # la energia de quien se ha quedado sin fuelle

# El acento del estilo moderno (la linea de los paneles, el borde del boton activo).
const ACENTO := Color(0.52, 0.68, 0.95)


static func es_pixel() -> bool:
	return estilo == Estilo.PIXEL


# ------------------------------------------------------------
#  PANELES (el registro, la ficha del apuntado)
# ------------------------------------------------------------
static func caja_panel() -> StyleBox:
	if es_pixel():
		var c = CajaPixel.new()
		return c
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.065, 0.085, 0.94)
	sb.border_width_top = 2
	sb.border_color = Color(ACENTO, 0.85)
	sb.set_corner_radius_all(3)
	for lado in ["left", "right", "top", "bottom"]:
		sb.set("content_margin_" + lado, 9.0)
	return sb


# El marco del RETRATO de la fila del grupo: el del estilo, con el fondo algo mas claro para que la cara no se pierda.
static func caja_retrato() -> StyleBox:
	if es_pixel():
		var c = CajaPixel.new()
		c.grueso = 1
		c.con_remaches = false
		c.fondo = Color(0.16, 0.16, 0.19)
		c.content_margin_left = 4.0
		c.content_margin_right = 4.0
		c.content_margin_top = 4.0
		c.content_margin_bottom = 4.0
		return c
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.14, 0.95)
	sb.border_color = Color(ACENTO, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(25)
	for lado in ["left", "right", "top", "bottom"]:
		sb.set("content_margin_" + lado, 4.0)
	return sb


# ------------------------------------------------------------
#  BARRAS (fondo y relleno). El color lo pone self_modulate.
# ------------------------------------------------------------
static func caja_barra_fondo() -> StyleBox:
	if es_pixel():
		var c = CajaPixel.new()
		c.grueso = 0
		c.con_remaches = false
		c.fondo = Color(0.20, 0.20, 0.22)
		return c
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.20, 0.23, 1.0)
	sb.set_corner_radius_all(2)
	return sb

static func caja_barra_relleno() -> StyleBox:
	if es_pixel():
		var c = CajaPixel.new()
		c.forma = CajaPixel.Forma.RELLENO
		return c
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.82, 0.82, 0.82, 1.0)
	sb.set_corner_radius_all(2)
	return sb

# Le pone a una barra las dos cajas del estilo y su color.
static func vestir_barra(b: ProgressBar, color: Color) -> void:
	b.add_theme_stylebox_override("background", caja_barra_fondo())
	b.add_theme_stylebox_override("fill", caja_barra_relleno())
	b.self_modulate = color


# ------------------------------------------------------------
#  BOTONES (el tema del panel de acciones: lo heredan tambien los submenus)
# ------------------------------------------------------------
static var _tema: Theme = null

static func tema_botones() -> Theme:
	if _tema != null:
		return _tema
	_tema = Theme.new()
	if es_pixel():
		var n = CajaPixel.new()
		n.fondo = Color(0.11, 0.11, 0.13)
		_tema.set_stylebox("normal", "Button", n)
		_tema.set_stylebox("hover", "Button", n.con({"hierro": Color(0.36, 0.37, 0.41), "brillo": Color(0.55, 0.55, 0.58),
			"remache": Color(0.86, 0.72, 0.38), "fondo": Color(0.15, 0.15, 0.17)}))
		# Pulsado: la luz se da la vuelta (hundido) y el fondo baja.
		_tema.set_stylebox("pressed", "Button", n.con({"brillo": Color(0.16, 0.16, 0.19), "sombra": Color(0.42, 0.43, 0.47),
			"remache": Color(0.86, 0.72, 0.38), "fondo": Color(0.07, 0.07, 0.08)}))
		_tema.set_stylebox("disabled", "Button", n.con({"hierro": Color(0.15, 0.15, 0.17), "brillo": Color(0.19, 0.19, 0.21),
			"sombra": Color(0.11, 0.11, 0.12), "remache": Color(0.24, 0.23, 0.22), "fondo": Color(0.07, 0.07, 0.08)}))
		_tema.set_stylebox("focus", "Button", StyleBoxEmpty.new())
		_tema.set_color("font_color", "Button", Color(0.90, 0.87, 0.80))
		_tema.set_color("font_hover_color", "Button", Color(1.0, 0.93, 0.75))
		_tema.set_color("font_pressed_color", "Button", Color(0.86, 0.80, 0.66))
		_tema.set_color("font_disabled_color", "Button", Color(0.36, 0.36, 0.38))
	else:
		_tema.set_stylebox("normal", "Button", _redondo(Color(0.07, 0.08, 0.10, 0.92), Color(1, 1, 1, 0.22)))
		_tema.set_stylebox("hover", "Button", _redondo(Color(0.10, 0.12, 0.16, 0.95), Color(ACENTO, 0.9)))
		_tema.set_stylebox("pressed", "Button", _redondo(Color(ACENTO.darkened(0.55), 0.95), Color(ACENTO, 1.0)))
		_tema.set_stylebox("disabled", "Button", _redondo(Color(0.05, 0.05, 0.06, 0.80), Color(1, 1, 1, 0.07)))
		_tema.set_stylebox("focus", "Button", StyleBoxEmpty.new())
		_tema.set_color("font_color", "Button", Color(0.92, 0.94, 0.98))
		_tema.set_color("font_disabled_color", "Button", Color(0.38, 0.40, 0.45))
	_tema.set_constant("icon_max_width", "Button", 24)
	return _tema

# ------------------------------------------------------------
#  EL TEMA DE TODOS LOS MENUS (06/11: "quiero ponerle esos estilos a todos los menus"). Lo devuelve
#  MenuScaffold.tema(), que es el que Game le pone a cada pantalla al nacer. Marco FINO (un pixel de hierro, sin
#  remaches) en botones y campos, para que las listas no crezcan; el GRUESO con remaches, en los paneles.
# ------------------------------------------------------------
static func tema_menus() -> Theme:
	var t := Theme.new()
	var n = CajaPixel.new()
	n.grueso = 1
	n.con_remaches = false
	n.fondo = Color(0.12, 0.12, 0.14)
	var hover = n.con({"hierro": Color(0.38, 0.38, 0.42), "brillo": Color(0.56, 0.55, 0.56), "fondo": Color(0.16, 0.16, 0.18)})
	var pulsado = n.con({"brillo": Color(0.16, 0.16, 0.19), "sombra": Color(0.42, 0.43, 0.47), "fondo": Color(0.08, 0.08, 0.09)})
	var apagado = n.con({"hierro": Color(0.15, 0.15, 0.17), "brillo": Color(0.19, 0.19, 0.21), "sombra": Color(0.11, 0.11, 0.12),
		"fondo": Color(0.07, 0.07, 0.08)})
	for tipo in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", tipo, n)
		t.set_stylebox("hover", tipo, hover)
		t.set_stylebox("pressed", tipo, pulsado)
		t.set_stylebox("hover_pressed", tipo, pulsado)
		t.set_stylebox("disabled", tipo, apagado)
		t.set_stylebox("focus", tipo, StyleBoxEmpty.new())
		t.set_color("font_disabled_color", tipo, Color(0.38, 0.38, 0.40))
	var panel = CajaPixel.new()
	panel.fondo = Color(0.07, 0.07, 0.09)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PopupMenu", panel)
	t.set_stylebox("panel", "TooltipPanel", panel.con({"con_remaches": false, "grueso": 1}))
	var campo = n.con({"fondo": Color(0.06, 0.06, 0.07)})
	t.set_stylebox("normal", "LineEdit", campo)
	t.set_stylebox("focus", "LineEdit", campo.con({"hierro": Color(0.45, 0.42, 0.34), "brillo": Color(0.62, 0.56, 0.40)}))
	t.set_stylebox("read_only", "LineEdit", apagado)
	t.set_stylebox("background", "ProgressBar", caja_barra_fondo())
	t.set_stylebox("fill", "ProgressBar", caja_barra_relleno())
	# LAS LISTAS CON SCROLL, con 4 px de aire por dentro: el marco ambar de la celda elegida va POR FUERA de la celda
	# (celda_objeto.gd) y en la primera fila o columna el scroll, que recorta lo que se sale de el, se lo comia.
	var aire := StyleBoxEmpty.new()
	aire.set_content_margin_all(4)
	t.set_stylebox("panel", "ScrollContainer", aire)
	_tema_deslizadores(t)
	return t


# (18/11) LOS DESLIZADORES Y LAS BARRAS DE SCROLL EN PIXEL: los de Godot salian con la bola y la barra redondas («tenemos
# que hacer estilo propio para estas cosas porque son redondas»). Todo cuadrado, sin suavizado, con el hierro de los
# botones: el carril hundido, lo recorrido en hierro claro y un TIRADOR de bloque con su brillo y su sombra.
const PX_HIERRO := Color(0.30, 0.30, 0.34)
const PX_BRILLO := Color(0.56, 0.55, 0.56)
const PX_SOMBRA := Color(0.14, 0.14, 0.16)
const PX_HUNDIDO := Color(0.05, 0.05, 0.06)

static func _caja_px(fondo: Color, borde: Color, grueso: int, alto_min: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.border_color = borde
	sb.set_border_width_all(grueso)
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	if alto_min > 0:
		sb.content_margin_top = alto_min / 2.0
		sb.content_margin_bottom = alto_min / 2.0
	return sb


# El tirador: un bloque de 'ancho' x 'alto' con borde oscuro, brillo arriba e izquierda y sombra abajo y derecha.
static func _tirador_px(ancho: int, alto: int, cuerpo: Color) -> ImageTexture:
	var img := Image.create(ancho, alto, false, Image.FORMAT_RGBA8)
	img.fill(PX_SOMBRA.darkened(0.4))
	img.fill_rect(Rect2i(1, 1, ancho - 2, alto - 2), cuerpo)
	img.fill_rect(Rect2i(1, 1, ancho - 2, 1), cuerpo.lightened(0.35))
	img.fill_rect(Rect2i(1, 1, 1, alto - 2), cuerpo.lightened(0.35))
	img.fill_rect(Rect2i(1, alto - 2, ancho - 2, 1), cuerpo.darkened(0.35))
	img.fill_rect(Rect2i(ancho - 2, 1, 1, alto - 2), cuerpo.darkened(0.35))
	# la muesca del medio, para que se lea como algo que se agarra
	if ancho >= 8 and alto >= 8:
		var cx: int = ancho / 2 - 1
		img.fill_rect(Rect2i(cx, 4, 1, alto - 8), cuerpo.darkened(0.35))
		img.fill_rect(Rect2i(cx + 1, 4, 1, alto - 8), cuerpo.lightened(0.25))
	return ImageTexture.create_from_image(img)


static func _tema_deslizadores(t: Theme) -> void:
	var carril := _caja_px(PX_HUNDIDO, PX_SOMBRA, 1, 6)
	var recorrido := _caja_px(PX_HIERRO, PX_SOMBRA, 1, 6)
	var recorrido_luz := _caja_px(PX_BRILLO.darkened(0.25), PX_SOMBRA, 1, 6)
	for tipo in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", tipo, carril)
		t.set_stylebox("grabber_area", tipo, recorrido)
		t.set_stylebox("grabber_area_highlight", tipo, recorrido_luz)
	var h_ancho: int = 10
	var h_alto: int = 18
	t.set_icon("grabber", "HSlider", _tirador_px(h_ancho, h_alto, Color(0.52, 0.52, 0.56)))
	t.set_icon("grabber_highlight", "HSlider", _tirador_px(h_ancho, h_alto, Color(0.66, 0.64, 0.62)))
	t.set_icon("grabber_disabled", "HSlider", _tirador_px(h_ancho, h_alto, Color(0.24, 0.24, 0.27)))
	t.set_icon("grabber", "VSlider", _tirador_px(h_alto, h_ancho, Color(0.52, 0.52, 0.56)))
	t.set_icon("grabber_highlight", "VSlider", _tirador_px(h_alto, h_ancho, Color(0.66, 0.64, 0.62)))
	t.set_icon("grabber_disabled", "VSlider", _tirador_px(h_alto, h_ancho, Color(0.24, 0.24, 0.27)))
	# LAS BARRAS DE SCROLL: carril hundido y un bloque de hierro que se aclara al pasar y al agarrarlo.
	for tipo in ["VScrollBar", "HScrollBar"]:
		# (el ANCHO de la barra lo dan los margenes de su caja: sin ellos se queda en 2 px y no se ve)
		var c := _caja_px(PX_HUNDIDO, PX_SOMBRA, 1)
		c.set_content_margin_all(5)
		t.set_stylebox("scroll", tipo, c)
		t.set_stylebox("scroll_focus", tipo, c)
		for estado in [["grabber", Color(0.40, 0.40, 0.44)], ["grabber_highlight", Color(0.56, 0.55, 0.56)],
				["grabber_pressed", Color(0.66, 0.60, 0.48)]]:
			var g := _caja_px(estado[1], PX_SOMBRA.darkened(0.4), 1)
			g.set_content_margin_all(4)
			t.set_stylebox(estado[0], tipo, g)


# ------------------------------------------------------------
#  PIEZAS SUELTAS EN PIXEL (06/11): los marcos y circulos que cada pantalla se dibujaba a su manera.
# ------------------------------------------------------------
# Un MARCO FINO de pixel: de hierro, o de BRONCE si es el elegido (el ambar de "esto es lo que miras"). 'borde', si se
# da, tiñe el hierro (el color de la mejora de un +N, el rojo de un aviso).
static func marco_px(fondo: Color, elegido: bool = false, borde: Color = Color(0, 0, 0, 0)) -> StyleBox:
	var c = CajaPixel.new()
	c.grueso = 1
	c.con_remaches = false
	c.fondo = fondo
	if elegido:
		c.hierro = Color(0.62, 0.45, 0.22)
		c.brillo = Color(0.92, 0.72, 0.38)
		c.sombra = Color(0.36, 0.25, 0.12)
	elif borde.a > 0.0:
		c.hierro = borde.darkened(0.25)
		c.brillo = borde.lightened(0.15)
		c.sombra = borde.darkened(0.55)
	c._margenes()
	return c

# (06/11) CUALQUIER CAJA HECHA A MANO, EN PIXEL: las ~30 cajas que cada pantalla se montaba con su StyleBoxFlat redondeado
# (pausa, ajustes, multijugador, mercadillo, tienda, avisos, globos, tooltips...). Con el estilo pixel sale una CajaPixel
# con SU fondo y SUS margenes; 'panel' = marco de hierro con remaches (los paneles grandes); si no, el marco fino,
# teñido por su borde si lo tiene (el ambar de un elegido, el rojo de un aviso). Con el estilo de antes, la caja tal cual.
# Una caja del todo transparente (fondo y borde a 0) se deja como esta: es "aqui no hay nada" y asi tiene que seguir.
static func a_pixel(sb: StyleBoxFlat, panel: bool = false) -> StyleBox:
	if not es_pixel() or sb == null:
		return sb
	var con_borde: bool = sb.border_color.a > 0.0 and (sb.border_width_left + sb.border_width_top
		+ sb.border_width_right + sb.border_width_bottom) > 0
	if sb.bg_color.a <= 0.0 and not con_borde:
		return sb
	var c = CajaPixel.new()
	c.fondo = sb.bg_color
	if not panel:
		c.grueso = 1
		c.con_remaches = false
		if con_borde and sb.border_color.a >= 0.3:
			c.hierro = Color(sb.border_color.darkened(0.25), 1.0)
			c.brillo = Color(sb.border_color.lightened(0.15), 1.0)
			c.sombra = Color(sb.border_color.darkened(0.55), 1.0)
	c._margenes()
	for lado in ["left", "top", "right", "bottom"]:
		var m: float = sb.get("content_margin_" + lado)
		if m >= 0.0:
			c.set("content_margin_" + lado, maxf(m, float(c.get("content_margin_" + lado))))
	return c


# Un DISCO de pixel (a franjas de 'p' de alto), para los circulos que antes eran suaves.
static func disco_px(ci: CanvasItem, centro: Vector2, r: float, col: Color, p: float = 2.0) -> void:
	if r <= 0.0:
		return
	var y: float = -floorf(r / p) * p
	while y < r:
		var yc: float = y + p * 0.5
		var mitad: float = floorf(sqrt(maxf(r * r - yc * yc, 0.0)) / p) * p
		if mitad > 0.0:
			ci.draw_rect(Rect2((centro + Vector2(-mitad, y)).floor(), Vector2(mitad * 2.0, p)), col)
		y += p

# Un ARO de pixel de 'grueso' (el borde de la vitrina).
static func aro_px(ci: CanvasItem, centro: Vector2, r: float, grueso: float, col: Color, p: float = 2.0) -> void:
	var y: float = -floorf(r / p) * p
	var ri: float = r - grueso
	while y < r:
		var yc: float = y + p * 0.5
		var fuera: float = floorf(sqrt(maxf(r * r - yc * yc, 0.0)) / p) * p
		var dentro: float = floorf(sqrt(maxf(ri * ri - yc * yc, 0.0)) / p) * p if absf(yc) < ri else 0.0
		if fuera > dentro:
			ci.draw_rect(Rect2((centro + Vector2(-fuera, y)).floor(), Vector2(fuera - dentro, p)), col)
			ci.draw_rect(Rect2((centro + Vector2(dentro, y)).floor(), Vector2(fuera - dentro, p)), col)
		y += p


# Muy redondeado: en el anillo los botones son cuadrados y salen circulos; en las listas de los submenus, pildoras.
static func _redondo(fondo: Color, borde: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.border_color = borde
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(64)
	sb.anti_aliasing = true
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	return sb


# ------------------------------------------------------------
#  LOS ICONOS DE LAS ACCIONES (los de la fuente de iconos en pixel, assets/ui/estados)
# ------------------------------------------------------------
static func icono(nombre: String) -> Texture2D:
	var ruta: String = "res://assets/ui/estados/%s.png" % nombre
	return load(ruta) if ResourceLoader.exists(ruta) else null
