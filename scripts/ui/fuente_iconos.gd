# ============================================================
#  fuente_iconos.gd  (autoload "FuenteIconos", el PRIMERO: antes de que exista ningun texto)
#  LA FUENTE DE ICONOS (05/11, el jefe: "todo tiene que ir con pixel art"). Una fuente de mapa de bits hecha con los
#  dibujos de assets/ui/estados, puesta POR DELANTE de la letra del juego: cada emoji o simbolo de la tabla
#  (fuente_iconos_tabla.gd, la genera tools/iconos_estados_pixel.py --hornear) se pinta con su dibujo pixel en
#  CUALQUIER texto -- registro, avisos, botones, fichas, menus -- sin tocar los sitios que lo escriben. Lo que no esta en
#  la tabla (las letras) cae a la letra de siempre.
#
#  Los datos no cambian: un estado sigue llevando su emoji (lo usan la red, el guardado y CombatFX); solo cambia como se
#  VE. Un icono nuevo: dibujarlo en el script, ponerlo en su tabla EMOJI y --hornear.
# ============================================================
extends Node

const TABLA_SCRIPT := preload("res://scripts/ui/fuente_iconos_tabla.gd")
const CARPETA := "res://assets/ui/estados/"
const LETRA := "res://assets/fonts/mazmorra_jersey.ttf"
const LADO := 12        # los dibujos son de 12 x 12
const TAM := 12         # tamaño de letra al que el dibujo sale 1:1 (a mas letra, se escala)
const ASCENSO := 10     # cuanto del dibujo queda por encima de la linea de escritura
const AIRE := 1         # pixel de separacion detras de cada icono

# Lo que acompaña a un emoji y no se ve: el selector de variante (el "️" de 🛡️) y la union de emojis (😮). Sin glifo
# propio, el texto le pediria ese trozo a la fuente del sistema y el emoji de colores volveria a salir.
const INVISIBLES := [0xFE0F, 0xFE0E, 0x200D]

var fuente: FontFile = null


func _init() -> void:
	instalar()


func instalar() -> void:
	# La letra que usan de verdad los controles es la del TEMA por defecto (no la de reserva de ThemeDB, que solo sale si
	# el tema no trae ninguna): esa es la que va detras de los iconos.
	var tema: Theme = ThemeDB.get_default_theme()
	var base: Font = tema.default_font if tema != null and tema.default_font != null else ThemeDB.fallback_font
	if base == null or fuente != null:
		return
	# (06/11, rework visual a pixel) LA LETRA DEL JUEGO: "Mazmorra Jersey" (Jersey 10, OFL, escalada para salir nitida a
	# 16 y 32 px: ver assets/fonts/LEEME.txt). Sin suavizado de subpixel ni hinting, que emborronan el pixel; con el
	# suavizado en gris, que a los tamaños que no son 16 o 32 es lo que evita trazos de un pixel que bailan. La de antes
	# se queda DETRAS, de reserva, para los pocos signos que Jersey no tiene (el ∞).
	if ResourceLoader.exists(LETRA):
		var px := load(LETRA) as FontFile
		if px != null:
			px.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
			px.hinting = TextServer.HINTING_NONE
			px.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			px.generate_mipmaps = false
			px.fallbacks = [base]
			if base is FontFile:   # la de reserva tampoco tira de las del sistema (los emojis de colores, ver abajo)
				(base as FontFile).allow_system_fallback = false
			base = px
	var f := FontFile.new()
	f.fixed_size = TAM
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY   # pixel nitido: x1, x2... nunca a medias
	var tam := Vector2i(TAM, 0)
	f.set_cache_ascent(0, TAM, ASCENSO)
	f.set_cache_descent(0, TAM, LADO - ASCENSO)
	var tabla: Dictionary = TABLA_SCRIPT.TABLA
	var imagenes: Dictionary = {}   # clave -> indice de textura (dos emojis con el mismo dibujo comparten)
	for emoji in tabla:
		var cp: int = String(emoji).unicode_at(0)
		var clave: String = tabla[emoji]
		if not imagenes.has(clave):
			var tex: Texture2D = load(CARPETA + clave + ".png") if ResourceLoader.exists(CARPETA + clave + ".png") else null
			if tex == null:
				continue
			var img: Image = tex.get_image()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			imagenes[clave] = imagenes.size()
			f.set_texture_image(0, tam, imagenes[clave], img)
		var idx: int = imagenes[clave]
		f.set_glyph_texture_idx(0, tam, cp, idx)
		f.set_glyph_uv_rect(0, tam, cp, Rect2(0, 0, LADO, LADO))
		f.set_glyph_size(0, tam, cp, Vector2(LADO, LADO))
		f.set_glyph_offset(0, tam, cp, Vector2(0, -ASCENSO))
		f.set_glyph_advance(0, TAM, cp, Vector2(LADO + AIRE, 0))
	for cp in INVISIBLES:
		f.set_glyph_texture_idx(0, tam, cp, -1)
		f.set_glyph_size(0, tam, cp, Vector2.ZERO)
		f.set_glyph_advance(0, TAM, cp, Vector2.ZERO)
	f.fallbacks = [base]
	# SIN LAS FUENTES DEL SISTEMA: con ellas a mano, el motor le da los emojis "de colores" (🎉 😮 🔥) a la fuente de
	# emojis de Windows aunque la nuestra los tenga. Ademas era lo que hacia que un emoji saliera distinto en cada aparato
	# (ver scripts/ui/iconos.gd): sin ella, lo que no tenga dibujo ni letra sale como hueco, igual en todos.
	f.allow_system_fallback = false
	if base is FontFile:
		(base as FontFile).allow_system_fallback = false
	fuente = f
	ThemeDB.fallback_font = f
	if tema != null:
		tema.default_font = f


# El dibujo de un emoji (o null): para quien lo quiera como imagen suelta (el icono de un boton, un TextureRect).
func textura(emoji: String) -> Texture2D:
	var clave = TABLA_SCRIPT.TABLA.get(emoji.left(1), null)
	if clave == null:
		return null
	var ruta: String = CARPETA + String(clave) + ".png"
	return load(ruta) if ResourceLoader.exists(ruta) else null
