# ============================================================
#  status_chip.gd
#  EL CHIP de un estado alterado: un recuadro DEL COLOR DEL ESTADO con su icono y lo que le queda
#  ("☠12·4t", o "🛡·19:32" si es un plato de cocina), con la ficha completa en el tooltip.
#
#  Existe para que un estado se pinte IGUAL en los dos sitios donde sale, que hasta ahora eran dos
#  cosas distintas: en el combate un boton de texto plano y por el mapa una sola linea de texto
#  recortada debajo de las barras. Un veneno tiene que verse igual esté donde esté.
#
#  Lo que pinta se lo dan HECHO: StatusEffects.chip_de_grupo devuelve [etiqueta, tooltip, icono,
#  color] y este archivo no sabe nada de estados, solo de como se dibuja un chip. El "color" del
#  catalogo llevaba puesto desde el principio y no lo usaba ninguna UI.
#
#  Es un BOTON y no un contenedor a proposito: asi se auto-dimensiona al texto, admite el tooltip
#  multilinea (TooltipButton) y puede llevar accion de clic, que en el combate hace falta porque
#  tocar un chip de un enemigo tambien lo SELECCIONA.
#
#  Todo por codigo y sin imagenes, como el resto de la UI (pase visual al final).
# ============================================================

extends RefCounted
class_name StatusChip
const HudEstilo = preload("res://scripts/ui/hud_estilo.gd")

const FUENTE := 12


# Un chip listo para meter en un contenedor.
#   etiqueta: lo que se VE. Normalmente el icono a secas: lo demas (magnitud, cuanto le queda, que
#             hace) esta en el tooltip, que es donde se mira cuando de verdad quieres el detalle.
#             Escrito en el chip ocupaba el triple y obligaba a dos filas de estados por tarjeta.
#   color:    el del estado en el catalogo. Tiñe el fondo y el texto.
#   tooltip:  la ficha completa ("" = sin tooltip).
#   clic:     opcional; sin ella el chip no roba clics a lo que tenga debajo.
#   parpadea: le queda UN turno. Como el chip ya no dice cuanto le queda, esto es lo que avisa de
#             que se acaba -- y se ve por el rabillo del ojo, que es mas de lo que conseguia un
#             "1t" escrito en letra de 12.
static func crear(etiqueta: String, color: Color, tooltip: String,
		clic: Callable = Callable(), parpadea: bool = false) -> Button:
	var b: Button = preload("res://scripts/ui/tooltip_button.gd").new()
	b.text = etiqueta
	b.tooltip_text = tooltip
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", FUENTE)
	if parpadea:
		# El Tween cuelga del propio boton, asi que se va con el. Los chips se recrean a cada
		# refresco de la tarjeta y con ellos el parpadeo, que por eso es rapido: si fuera lento no
		# llegaria a completar un ciclo entre refresco y refresco.
		var tw: Tween = b.create_tween().set_loops()
		tw.tween_property(b, "modulate:a", 0.25, 0.35)
		tw.tween_property(b, "modulate:a", 1.0, 0.35)
	# Texto SUBIDO de brillo y fondo BAJADO, los dos del mismo color: el chip se identifica por su
	# color de un vistazo y el texto sigue leyendose. Con el color a pelo en los dos, un veneno verde
	# claro sobre verde claro no se lee.
	b.add_theme_color_override("font_color", color.lightened(0.45))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _fondo(color, 0.30))
	b.add_theme_stylebox_override("hover", _fondo(color, 0.50))
	b.add_theme_stylebox_override("pressed", _fondo(color, 0.55))
	b.add_theme_stylebox_override("focus", _fondo(color, 0.30))
	if clic.is_valid():
		b.pressed.connect(clic)
	else:
		b.mouse_filter = Control.MOUSE_FILTER_PASS   # deja pasar el clic, pero conserva el tooltip
	return b


# ============================================================
#  LOS ICONOS EN PIXEL ART (05/11, el jefe: los emojis "estan graciosos pero no es para un juego serio como el nuestro").
#  Dibujos de 12 x 12 en assets/ui/estados, hechos por tools/iconos_estados_pixel.py. El emoji NO desaparece de los
#  datos: el registro, la red y CombatFX lo siguen usando; aqui solo se cambia lo que se VE.
# ============================================================
const CARPETA_ICONOS := "res://assets/ui/estados/"
const CHIP_NEUTRO := Color(0.78, 0.80, 0.86)

# Los chips que NO salen del catalogo (no traen clave): se reconocen por como empieza su etiqueta. El orden importa:
# los prefijos largos antes que los cortos ("🛡→" antes que "🛡", "🔮×" antes que "🔮").
const PREFIJOS := [
	["⚡!", "carga_lista"], ["⏳", "cargando"], ["🔮×", "foco"], ["🔮", "recitando"], ["🎯", "provocando"],
	["💢", "provocado"], ["🛡→", "cubriendo"], ["🛡←", "cubierto"], ["🛡", "defendiendo"], ["🤺", "en_guardia"],
	["😮", "sin_fuelle"], ["✚", "pocion_vida"], ["🔷", "pocion_mana"],
]

static var _texturas: Dictionary = {}


static func textura(clave: String) -> Texture2D:
	if clave == "":
		return null
	if not _texturas.has(clave):
		var ruta: String = CARPETA_ICONOS + clave + ".png"
		_texturas[clave] = load(ruta) if ResourceLoader.exists(ruta) else null
	return _texturas[clave]


# [clave, emoji que tapa el icono] de un chip: la que trae (los del catalogo, en par[5]) o la de su prefijo.
static func clave_de(par: Array) -> Array:
	if par.size() > 5 and String(par[5]) != "":
		return [String(par[5]), String(par[2]) if par.size() > 2 else ""]
	var etq: String = String(par[0]) if not par.is_empty() else ""
	for p in PREFIJOS:
		if etq.begins_with(String(p[0])):
			return [String(p[1]), String(p[0])]
	return ["", ""]


# EL CHIP A PARTIR DE SUS DATOS, el mismo en todas partes (la pelea, el HUD de arriba, la ficha del objetivo):
#   par = [etiqueta, tooltip, icono, color, ultimo turno, clave] (los de mecanica traen solo los dos primeros).
# Con dibujo: el icono pixel y, detras, lo que la etiqueta dice ademas del emoji ("3t", "2/3"); los del catalogo, como
# antes, solo el icono (lo demas esta en su ficha). Sin dibujo (un espejo con una version vieja), el texto de siempre.
static func de_par(par: Array, clic: Callable = Callable()) -> Button:
	var col: Color = (par[3] as Color) if par.size() > 3 and par[3] is Color else CHIP_NEUTRO
	var tip: String = String(par[1]) if par.size() > 1 else ""
	var ultimo: bool = par.size() > 4 and bool(par[4])
	var con_icono: bool = par.size() > 2 and String(par[2]) != ""
	var txt: String = String(par[2]) if con_icono else (String(par[0]) if not par.is_empty() else "")
	var cl: Array = clave_de(par)
	var tex: Texture2D = textura(String(cl[0]))
	if tex == null:
		return crear(txt, col, tip, clic, ultimo)
	var resto: String = ""
	if not con_icono and String(par[0]).begins_with(String(cl[1])):
		resto = String(par[0]).substr(String(cl[1]).length()).strip_edges()
	var b: Button = crear(resto, col, tip, clic, ultimo)
	b.icon = tex
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.add_theme_constant_override("h_separation", 2)
	# Para su ficha (TooltipButton): el mismo dibujo en la cabecera, en vez del emoji con el que empieza el texto.
	b.set_meta(&"icono_px", tex)
	b.set_meta(&"emoji_px", String(cl[1]))
	return b


static func _fondo(color: Color, alpha: float) -> StyleBox:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r * 0.55, color.g * 0.55, color.b * 0.55, alpha)
	sb.border_color = Color(color.r, color.g, color.b, alpha + 0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 5.0
	sb.content_margin_right = 5.0
	sb.content_margin_top = 1.0
	sb.content_margin_bottom = 1.0
	return HudEstilo.a_pixel(sb)
