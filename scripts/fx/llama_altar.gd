# ============================================================
#  llama_altar.gd  (class_name LlamaAltar)
#  EL FUEGO DEL ALTAR: una llama GRANDE y BLANCA que se mueve como fuego de verdad (lo pidio el usuario).
#
#  UNA SOLA LLAMA ANIMADA, NO PARTICULAS. La primera version eran treinta lenguas aditivas y el usuario
#  lo vio al momento: "no parece una llama, se ve que son muchas y se mueve demasiado rapido", y ademas
#  nacian por debajo del borde del cuenco y tapaban el dibujo. Una llama de pixel-art es UNA silueta
#  que cambia poco de un fotograma a otro: la base quieta en el cuenco y la punta meciendose.
#
#  Se dibuja por codigo (8 fotogramas en bucle, a 7 fps): gota con la base redonda, blanca por dentro,
#  azul muy palido hacia el borde y un contorno azul. El vaiven sale de un seno que da la vuelta entera
#  en el ciclo, asi que el ultimo fotograma casa con el primero. Encima, unas pocas chispas lentas y un
#  resplandor que late despacio.
#
#  El nodo se coloca en la BOCA del cuenco: la base de la llama queda justo ahi, nada por debajo.
# ============================================================
extends Node2D
class_name LlamaAltar

const ANCHO := 22
const ALTO := 34
const FOTOGRAMAS := 8
const FPS := 7.0

static var _frames: SpriteFrames = null
static var _tex_chispa: ImageTexture = null
static var _tex_halo: ImageTexture = null

var _halo: Sprite2D = null
var _t: float = 0.0


static func crear() -> LlamaAltar:
	var l := LlamaAltar.new()
	l.name = "Llama"
	return l


func _ready() -> void:
	var aditivo := CanvasItemMaterial.new()
	aditivo.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_halo = Sprite2D.new()
	_halo.texture = _textura_halo()
	_halo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_halo.material = aditivo
	_halo.position = Vector2(0, -12)
	_halo.modulate = Color(0.75, 0.82, 1.0, 0.22)
	add_child(_halo)

	var llama := AnimatedSprite2D.new()
	llama.name = "Fuego"
	llama.sprite_frames = _fotogramas()
	llama.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	llama.centered = false
	# La base de la llama (la ultima fila opaca) cae en la boca del cuenco.
	llama.position = Vector2(-ANCHO / 2, -ALTO + 2)
	llama.play("arde")
	add_child(llama)

	var chispas := CPUParticles2D.new()
	chispas.name = "Chispas"
	chispas.texture = _textura_chispa()
	chispas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	chispas.material = aditivo
	chispas.amount = 3
	chispas.lifetime = 2.2
	chispas.preprocess = 2.2
	chispas.randomness = 0.7
	chispas.local_coords = false
	chispas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	chispas.emission_rect_extents = Vector2(3.0, 2.0)
	chispas.direction = Vector2(0, -1)
	chispas.spread = 25.0
	chispas.initial_velocity_min = 6.0
	chispas.initial_velocity_max = 11.0
	chispas.gravity = Vector2(1.5, -2.0)
	var rampa := Gradient.new()
	rampa.set_color(0, Color(1, 1, 1, 0.9))
	rampa.set_color(1, Color(0.7, 0.8, 1.0, 0))
	chispas.color_ramp = rampa
	chispas.position = Vector2(0, -ALTO + 6)
	add_child(chispas)


func _process(delta: float) -> void:
	_t += delta
	_halo.modulate.a = 0.20 + 0.04 * sin(_t * 2.6) + 0.02 * sin(_t * 4.1 + 1.7)


# ============================================================
#  LOS FOTOGRAMAS
# ============================================================
static func _fotogramas() -> SpriteFrames:
	if _frames != null:
		return _frames
	var sf := SpriteFrames.new()
	sf.add_animation("arde")
	sf.set_animation_loop("arde", true)
	sf.set_animation_speed("arde", FPS)
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for k in FOTOGRAMAS:
		sf.add_frame("arde", ImageTexture.create_from_image(_fotograma(k)))
	_frames = sf
	return _frames


static func _fotograma(k: int) -> Image:
	var img := Image.create(ANCHO, ALTO, false, Image.FORMAT_RGBA8)
	var fase: float = float(k) / float(FOTOGRAMAS) * TAU
	var cx: float = float(ANCHO) * 0.5
	var blanco := Color(1.0, 1.0, 1.0)
	var palido := Color(0.86, 0.92, 1.0)
	var borde := Color(0.62, 0.76, 1.0)
	var contorno := Color(0.36, 0.52, 0.92)
	# La altura de la punta respira un poco (sin cambiar la base).
	var alto_llama: float = float(ALTO - 2) * (0.90 + 0.06 * sin(fase) + 0.03 * sin(fase * 2.0 + 1.0))
	var base_y: float = float(ALTO - 2)
	var mascara := PackedByteArray()
	mascara.resize(ANCHO * ALTO)
	var nucleo := PackedFloat32Array()
	nucleo.resize(ANCHO * ALTO)
	for y in ALTO:
		# t: 0 en la punta, 1 en la base.
		var t: float = (float(y) + 0.5 - (base_y - alto_llama)) / alto_llama
		if t < 0.0 or t > 1.0:
			continue
		# Silueta de gota: se abre desde la punta y se cierra redonda abajo.
		var semi: float
		if t < 0.72:
			semi = 8.5 * pow(t / 0.72, 0.8)
		else:
			var u: float = (t - 0.72) / 0.28
			semi = 8.5 * sqrt(maxf(0.0, 1.0 - u * u * 0.85))
		# El vaiven: la punta se mece mucho, la base casi nada.
		var meneo: float = (sin(fase + t * 3.0) * 2.2 + sin(fase * 2.0 + t * 5.0 + 0.7) * 0.8) * pow(1.0 - t, 1.6)
		# BORDE IRREGULAR: cada fila entra o sale un pixel segun el fotograma. Sin esto la silueta era
		# una gota lisa y simetrica, "de agua" y no de fuego.
		var ruido: float = (PuebloSprites._rnd(y, k, 707) - 0.5) * 2.0 * (1.0 - t * 0.7)
		# LA SEGUNDA LENGUA: una punta estrecha que asoma a un lado de la principal, sube y se retira.
		var lado: float = 1.0 if posmod(k, 4) < 2 else -1.0
		var lengua_c: float = cx + lado * (4.0 + sin(fase) * 1.0) + meneo * 1.3
		var lengua_t0: float = 0.18 + 0.12 * (0.5 + 0.5 * sin(fase * 2.0 + 0.4))
		var lengua_semi: float = 0.0
		if t > lengua_t0 and t < 0.62:
			lengua_semi = 2.4 * sin((t - lengua_t0) / (0.62 - lengua_t0) * PI)
		for x in ANCHO:
			var dx: float = float(x) + 0.5 - cx - meneo
			var lim: float = maxf(0.0, semi + ruido)
			var en_lengua: bool = absf(float(x) + 0.5 - lengua_c) <= lengua_semi
			if absf(dx) > lim and not en_lengua:
				continue
			mascara[y * ANCHO + x] = 1
			# Cuanto de "centro" es este pixel (1 en el eje, 0 en el borde), mas hacia la base. El
			# corazon blanco sube y baja un poco con el fotograma.
			var sube: float = 1.35 + 0.35 * sin(fase + 1.3)
			nucleo[y * ANCHO + x] = 0.0 if absf(dx) > lim else (1.0 - absf(dx) / maxf(lim, 0.5)) * clampf(t * sube, 0.0, 1.0)
	for y in ALTO:
		for x in ANCHO:
			var i: int = y * ANCHO + x
			if mascara[i] == 0:
				continue
			var es_borde: bool = x == 0 or x == ANCHO - 1 or y == 0 or y == ALTO - 1 \
				or mascara[i - 1] == 0 or mascara[i + 1] == 0 or mascara[i - ANCHO] == 0 or mascara[i + ANCHO] == 0
			var n: float = nucleo[i]
			var c: Color
			if es_borde:
				c = contorno
			elif n > 0.62:
				c = blanco
			elif n > 0.30:
				c = palido
			else:
				c = borde
			img.set_pixel(x, y, c)
	return img


static func _textura_chispa() -> ImageTexture:
	if _tex_chispa != null:
		return _tex_chispa
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	_tex_chispa = ImageTexture.create_from_image(img)
	return _tex_chispa


static func _textura_halo() -> ImageTexture:
	if _tex_halo != null:
		return _tex_halo
	# Un circulo de 44 px en tres escalones de alfa (pixel-art, sin degradado continuo).
	var img := Image.create(44, 44, false, Image.FORMAT_RGBA8)
	for y in 44:
		for x in 44:
			var r: float = Vector2(float(x) + 0.5 - 22.0, float(y) + 0.5 - 22.0).length()
			var a: float = 0.0
			if r < 9.0:
				a = 1.0
			elif r < 15.0:
				a = 0.55
			elif r < 22.0:
				a = 0.22
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_tex_halo = ImageTexture.create_from_image(img)
	return _tex_halo
