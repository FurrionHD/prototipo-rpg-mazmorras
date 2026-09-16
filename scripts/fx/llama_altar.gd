# ============================================================
#  llama_altar.gd  (class_name LlamaAltar)
#  EL FUEGO DEL ALTAR: una llama GRANDE y BLANCA que se mueve como fuego de verdad (lo pidio el usuario).
#
#  Dos emisores:
#    - LA LLAMA: muchas lenguas cortas que suben deprisa, se estrechan y se apagan. Mezcla ADITIVA:
#      donde se juntan varias se satura a blanco puro, que es lo que da el "corazon" de la llama sin
#      pintarlo. Por fuera tira a azul muy palido: un fuego blanco no es amarillo.
#    - LAS CHISPAS: pocas, lentas, que se escapan hacia arriba y parpadean.
#  Y un resplandor suave que late debajo.
#
#  Texturas de pixel-art en dos tonos con filtro nearest, como el humo de las chimeneas.
# ============================================================
extends Node2D
class_name LlamaAltar

static var _tex_lengua: ImageTexture = null
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
	_halo.position = Vector2(0, -8)
	_halo.modulate = Color(0.75, 0.82, 1.0, 0.35)
	add_child(_halo)

	var llama := CPUParticles2D.new()
	llama.name = "Lenguas"
	llama.texture = _textura_lengua()
	llama.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	llama.material = aditivo
	llama.amount = 34
	llama.lifetime = 0.75
	llama.preprocess = 1.0
	llama.randomness = 0.4
	llama.local_coords = false
	llama.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	llama.emission_rect_extents = Vector2(5.0, 1.5)
	llama.direction = Vector2(0, -1)
	llama.spread = 8.0
	llama.initial_velocity_min = 26.0
	llama.initial_velocity_max = 44.0
	llama.gravity = Vector2(0, -20)
	llama.damping_min = 8.0
	llama.damping_max = 14.0
	var escala := Curve.new()
	escala.add_point(Vector2(0.0, 1.0))
	escala.add_point(Vector2(0.45, 0.8))
	escala.add_point(Vector2(1.0, 0.15))
	llama.scale_amount_curve = escala
	llama.scale_amount_min = 0.8
	llama.scale_amount_max = 1.3
	var rampa := Gradient.new()
	rampa.set_color(0, Color(1.0, 1.0, 1.0, 0.95))
	rampa.set_color(1, Color(0.55, 0.70, 1.0, 0.0))
	rampa.add_point(0.35, Color(0.92, 0.96, 1.0, 0.85))
	rampa.add_point(0.7, Color(0.70, 0.80, 1.0, 0.45))
	llama.color_ramp = rampa
	add_child(llama)

	var chispas := CPUParticles2D.new()
	chispas.name = "Chispas"
	chispas.texture = _textura_chispa()
	chispas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	chispas.material = aditivo
	chispas.amount = 6
	chispas.lifetime = 1.6
	chispas.preprocess = 1.6
	chispas.randomness = 0.6
	chispas.local_coords = false
	chispas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	chispas.emission_rect_extents = Vector2(4.0, 2.0)
	chispas.direction = Vector2(0, -1)
	chispas.spread = 30.0
	chispas.initial_velocity_min = 14.0
	chispas.initial_velocity_max = 26.0
	chispas.gravity = Vector2(0, -6)
	var rampa2 := Gradient.new()
	rampa2.set_color(0, Color(1, 1, 1, 1))
	rampa2.set_color(1, Color(0.7, 0.8, 1.0, 0))
	chispas.color_ramp = rampa2
	chispas.position = Vector2(0, -10)
	add_child(chispas)


func _process(delta: float) -> void:
	# El resplandor late (dos senos a distinta velocidad: un latido regular se nota artificial).
	_t += delta
	var pulso: float = 0.30 + 0.06 * sin(_t * 7.3) + 0.04 * sin(_t * 12.9 + 1.7)
	_halo.modulate.a = pulso


static func _textura_lengua() -> ImageTexture:
	if _tex_lengua != null:
		return _tex_lengua
	# Una lengua de 8x12: gota alargada, blanca en el centro y gris azulado en el borde.
	var img := Image.create(8, 12, false, Image.FORMAT_RGBA8)
	for y in 12:
		for x in 8:
			var dx: float = absf(float(x) + 0.5 - 4.0)
			var t: float = float(y) / 11.0                 # 0 arriba (punta), 1 abajo
			var semi: float = 0.8 + 3.2 * sin(t * PI * 0.85)
			if dx > semi:
				continue
			var c := Color(1, 1, 1, 1) if dx < semi * 0.5 else Color(0.75, 0.80, 0.90, 0.9)
			img.set_pixel(x, y, c)
	_tex_lengua = ImageTexture.create_from_image(img)
	return _tex_lengua


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
	# Un circulo de 40 px en tres escalones de alfa (pixel-art, sin degradado continuo).
	var img := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	for y in 40:
		for x in 40:
			var r: float = Vector2(float(x) + 0.5 - 20.0, float(y) + 0.5 - 20.0).length()
			var a: float = 0.0
			if r < 8.0:
				a = 1.0
			elif r < 14.0:
				a = 0.55
			elif r < 20.0:
				a = 0.22
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_tex_halo = ImageTexture.create_from_image(img)
	return _tex_halo
