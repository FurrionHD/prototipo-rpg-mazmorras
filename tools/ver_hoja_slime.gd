# HERRAMIENTA: hoja de una animacion de slime en 8 direcciones (filas N..S), generada al vuelo desde
# SlimeSprites (NO lo horneado, para ver cambios sin rehornear). Uso: -- <enemigo> <anim>[,<anim>...] <carpeta>
extends Node

const ZOOM := 4
const HUECO := 6
const FONDO := Color(0.11, 0.12, 0.15)
const FILAS := [4, 3, 5, 2, 6, 1, 7, 0]     # N NE NW E W SE SW S
const NOMBRES := {0: "S", 1: "SE", 2: "E", 3: "NE", 4: "N", 5: "NW", 6: "W", 7: "SW"}


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var enemigo: String = args[0]
	var anims: PackedStringArray = args[1].split(",")
	var salida: String = args[2]
	DirAccess.make_dir_recursive_absolute(salida)
	var ed: EnemyData = load("res://scenes/actors/enemy/%s.tres" % enemigo)
	# El generador de SU familia (29/09: tambien la rata y el rey rata), siempre al vuelo.
	var sf: SpriteFrames = SpritesEnemigo._generador(ed).generar_de(ed, 0.0)
	for anim in anims:
		# LAS DE DOS MITADES (el Enrosque del ciempies, 29/09): detras, la presa, delante; como en el juego.
		var img: Image = _hoja_con_presa(sf, anim, SpritesEnemigo.escala_de(ed)) if sf.has_animation("%s_detras_0" % anim) else _hoja(sf, anim)
		var ruta: String = salida.path_join("%s_%s.png" % [enemigo, anim])
		img.save_png(ruta)
		print("[hoja] ", ruta)
	get_tree().quit()


# Una fila: por fotograma, la mitad de detras, la PRESA (una figura azul del tamaño de un personaje, 22x38 px de mundo
# de los pies a la cabeza: PoseJugador.CAJA_CUERPO, con los pies en el
# origen del dibujo = el centro del lienzo) y la mitad de delante encima.
func _hoja_con_presa(sf: SpriteFrames, anim: String, escala: float) -> Image:
	var det := "%s_detras_0" % anim
	var dl := "%s_delante_0" % anim
	var n: int = sf.get_frame_count(det)
	var wh: Vector2i = _lienzo_de(sf.get_frame_texture(det, 0))
	var fig := Vector2i(int(round(22.0 / escala)), int(round(38.0 / escala)))
	var caja := Rect2i(wh / 2 - Vector2i(fig.x, fig.y + 2), Vector2i(fig.x * 2, fig.y + 4))
	for nom in [det, dl]:
		for i in sf.get_frame_count(nom):
			var a0: AtlasTexture = sf.get_frame_texture(nom, i)
			caja = caja.merge(Rect2i(Vector2i(a0.margin.position), Vector2i(a0.region.size)))
	caja = caja.grow(2).intersection(Rect2i(Vector2i.ZERO, wh))
	var cw: int = caja.size.x * ZOOM
	var ch: int = caja.size.y * ZOOM
	var out := Image.create((cw + HUECO) * n + HUECO, ch + HUECO * 2, false, Image.FORMAT_RGBA8)
	out.fill(FONDO)
	for i in n:
		var lienzo := Image.create(wh.x, wh.y, false, Image.FORMAT_RGBA8)
		lienzo.fill(Color(0, 0, 0, 0))
		_pegar(lienzo, sf.get_frame_texture(det, i))
		lienzo.fill_rect(Rect2i(Vector2i(wh.x / 2 - fig.x / 2, wh.y / 2 - fig.y), fig), Color(0.35, 0.6, 1.0))
		_pegar(lienzo, sf.get_frame_texture(dl, mini(i, sf.get_frame_count(dl) - 1)))
		var amp: Image = lienzo.get_region(caja)
		amp.resize(cw, ch, Image.INTERPOLATE_NEAREST)
		out.blend_rect(amp, Rect2i(0, 0, cw, ch), Vector2i(HUECO + i * (cw + HUECO), HUECO))
	return out


func _pegar(lienzo: Image, at: AtlasTexture) -> void:
	var src: Image = at.atlas.get_image()
	src.convert(Image.FORMAT_RGBA8)
	var trozo: Image = src.get_region(Rect2i(at.region))
	lienzo.blend_rect(trozo, Rect2i(Vector2i.ZERO, trozo.get_size()), Vector2i(at.margin.position))


func _lienzo_de(at: AtlasTexture) -> Vector2i:
	return Vector2i(int(at.region.size.x + at.margin.size.x), int(at.region.size.y + at.margin.size.y))


func _hoja(sf: SpriteFrames, anim: String) -> Image:
	var n: int = sf.get_frame_count("%s_0" % anim)
	var wh: Vector2i = _lienzo_de(sf.get_frame_texture("%s_0" % anim, 0))
	var caja := Rect2i()
	var primero := true
	for d in FILAS:
		var nom := "%s_%d" % [anim, d]
		if not sf.has_animation(nom):
			continue
		for i in sf.get_frame_count(nom):
			var a0: AtlasTexture = sf.get_frame_texture(nom, i)
			var r0 := Rect2i(Vector2i(a0.margin.position), Vector2i(a0.region.size))
			caja = r0 if primero else caja.merge(r0)
			primero = false
	caja = caja.grow(2).intersection(Rect2i(Vector2i.ZERO, wh))
	var cw: int = caja.size.x * ZOOM
	var ch: int = caja.size.y * ZOOM
	var out := Image.create((cw + HUECO) * n + HUECO, (ch + HUECO) * FILAS.size() + HUECO, false, Image.FORMAT_RGBA8)
	out.fill(FONDO)
	for fila in FILAS.size():
		var nom := "%s_%d" % [anim, FILAS[fila]]
		if not sf.has_animation(nom):
			continue
		for i in sf.get_frame_count(nom):
			var at: AtlasTexture = sf.get_frame_texture(nom, i)
			var lienzo := Image.create(wh.x, wh.y, false, Image.FORMAT_RGBA8)
			lienzo.fill(Color(0, 0, 0, 0))
			var src: Image = at.atlas.get_image()
			src.convert(Image.FORMAT_RGBA8)
			lienzo.blit_rect(src, Rect2i(at.region), Vector2i(at.margin.position))
			var amp: Image = lienzo.get_region(caja)
			amp.resize(cw, ch, Image.INTERPOLATE_NEAREST)
			out.blend_rect(amp, Rect2i(0, 0, cw, ch), Vector2i(HUECO + i * (cw + HUECO), HUECO + fila * (ch + HUECO)))
	return out
