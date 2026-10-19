# ============================================================
#  antorcha.gd  (class_name Antorcha)
#  UN FUEGO DEL PUEBLO (antorcha o brasero) que se enciende al anochecer. El dibujo sale de
#  FuegoSprites; aqui va lo vivo:
#    - la llama animada, con su perfil y su arranque propios (dos vecinas no van a la par);
#    - dos o tres chispas lentas siempre, y CHISPORROTEO: cada pocos segundos (al azar) una rafaga
#      corta de chispas (lo pidio el usuario). Sin estiron de la llama: se veia raro;
#    - ENCENDER/APAGAR con la hora (CicloDia.luces): la llama crece desde la base y al apagarse
#      suelta una bocanada de humo.
#
#  El nodo se coloca en la BOCA del soporte: la base de la llama cae justo ahi.
#  La LUZ que da (el corro en el suelo y el resplandor) no va aqui: la apunta town en LuzPueblo.
# ============================================================
extends Node2D
class_name Antorcha

var perfil: int = 0
var retraso: float = 0.0
# Encendida a todas horas (la muestra de fuegos de la plaza, para elegirlos de dia).
var siempre: bool = false

var _llama: AnimatedSprite2D = null
var _chispas: CPUParticles2D = null
var _rafaga: CPUParticles2D = null
var _humo: CPUParticles2D = null
var _encendida: float = -1.0     # 0..1 lo que se ve ahora (sigue a la hora con suavidad)
var _hasta_rafaga: float = 0.0
var _rng := RandomNumberGenerator.new()
var _sonido: AudioStreamPlayer2D = null
var _volumen: float = -17.0

static var _tex_chispa: ImageTexture = null


# 'semilla' fija el arranque de la animacion y el ritmo del chisporroteo: con la celda de la antorcha,
# en multi todos la ven igual.
static func crear(p_perfil: int, p_retraso: float, semilla: int) -> Antorcha:
	var a := Antorcha.new()
	a.name = "Antorcha"
	a.perfil = p_perfil
	a.retraso = p_retraso
	a._rng.seed = semilla
	return a


func _ready() -> void:
	var p: Dictionary = FuegoSprites.PERFILES[perfil]
	var ancho: int = int(p["ancho"])
	var alto: int = int(p["alto"])
	var brasero: bool = ancho > 20

	_llama = AnimatedSprite2D.new()
	_llama.sprite_frames = FuegoSprites.fotogramas(perfil)
	_llama.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_llama.centered = false
	# La base (ultima fila) en el origen: al escalar en vertical crece desde abajo. Va en 'offset' y no en
	# 'position': la escala se aplica alrededor de la POSICION del nodo, y con el dibujo desplazado por
	# position la llama crecia desde su esquina de arriba y se quedaba flotando sobre el poste.
	_llama.position = Vector2.ZERO
	_llama.offset = Vector2(-ancho / 2, -alto + 1)
	_llama.play("arde")
	_llama.frame = _rng.randi_range(0, int(p["frames"]) - 1)
	_llama.speed_scale = _rng.randf_range(0.9, 1.1)
	add_child(_llama)

	var aditivo := CanvasItemMaterial.new()
	aditivo.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_chispas = _particulas(2 if not brasero else 4, 1.6, aditivo)
	_chispas.emission_rect_extents = Vector2(float(ancho) * 0.25, 2.0)
	_chispas.position = Vector2(0, -alto * 0.6)
	add_child(_chispas)

	_rafaga = _particulas(5 if not brasero else 8, 0.9, aditivo)
	_rafaga.one_shot = true
	_rafaga.explosiveness = 0.85
	_rafaga.emitting = false
	_rafaga.preprocess = 0.0
	_rafaga.spread = 50.0
	_rafaga.initial_velocity_min = 16.0
	_rafaga.initial_velocity_max = 30.0
	_rafaga.emission_rect_extents = Vector2(float(ancho) * 0.3, 2.0)
	_rafaga.position = Vector2(0, -alto * 0.5)
	add_child(_rafaga)

	_humo = HumoChimenea.crear(false)
	_humo.z_as_relative = true
	_humo.z_index = 0
	_humo.amount = 5
	_humo.lifetime = 2.0
	_humo.preprocess = 0.0
	_humo.one_shot = true
	_humo.explosiveness = 0.6
	_humo.emitting = false
	_humo.position = Vector2(0, -alto * 0.4)
	add_child(_humo)

	# EL SONIDO: el mismo chisporroteo que el farolillo (lo pidio el usuario), pegado al fuego. Se oye
	# al acercarte; el brasero, algo mas fuerte y de mas lejos. Apagada, en silencio.
	_volumen = -12.0 if brasero else -17.0
	# SOLO SUENA ENCENDIDA Y A TU ALCANCE (optimizacion 1E, 19/10/2026): antes sonaban TODAS siempre (de dia a -60 dB y
	# en la otra punta del pueblo): ~48 OGG decodificandose a la vez, y arrancarlos al llegar eran ~17 ms. Se oye igual:
	# arranca al acercarte, en un punto al azar del bucle como antes (ver _vigilar_sonido).
	_alcance = 260.0 if brasero else 180.0
	_sonido = Ambiente.pegar(self, "antorcha", _volumen, _alcance, false)

	_hasta_rafaga = _rng.randf_range(1.0, 8.0)
	_aplicar(1.0 if siempre else CicloDia.luces(retraso), true)


func _process(delta: float) -> void:
	var objetivo: float = 1.0 if siempre else CicloDia.luces(retraso)
	# Encender o apagar lleva ~0.6 s aunque la hora salte de golpe (el panel de debug).
	var k: float = move_toward(_encendida, objetivo, delta / 0.6)
	# SOLO SI CAMBIA (optimizacion 1E, 19/10/2026): de dia esta apagada fija y de noche encendida fija; ponerle la llama,
	# las chispas y el volumen en cada fotograma, a las 48 del pueblo, era trabajo para nada. Solo cambia en el fundido.
	if k != _encendida:
		_aplicar(k, false)
	# Y el sonido, cada SONIDO_CADA fotogramas (cada una en el suyo): acercarse o alejarse no va a fotograma.
	_sonido_cuenta -= 1
	if _sonido_cuenta <= 0:
		_sonido_cuenta = SONIDO_CADA
		_vigilar_sonido()
	if _encendida <= 0.0:
		return
	_hasta_rafaga -= delta
	# Solo chispas: la llama NO pega un estiron con la rafaga ("que no se haga mas grande de repente,
	# es un poco raro", dijo el usuario).
	if _hasta_rafaga <= 0.0:
		_hasta_rafaga = _rng.randf_range(3.0, 9.0)
		_rafaga.restart()


# Margen sobre el alcance: arranca un poco antes de que se le pueda oir, para no empezar de golpe ya dentro.
const MARGEN_SONIDO := 64.0
const SONIDO_CADA := 6
var _sonido_cuenta: int = randi() % SONIDO_CADA
var _alcance: float = 180.0

func _vigilar_sonido() -> void:
	if _sonido == null or not is_instance_valid(_sonido) or Ambiente._pausado:
		return
	var cerca: bool = _encendida > 0.0
	if cerca:
		var cam: Camera2D = get_viewport().get_camera_2d()
		cerca = cam == null or global_position.distance_to(cam.get_screen_center_position()) <= _alcance + MARGEN_SONIDO
	if cerca and not _sonido.playing:
		_sonido.play(_rng.randf() * maxf(0.1, _sonido.stream.get_length()))
	elif not cerca and _sonido.playing:
		_sonido.stop()


func _aplicar(k: float, inicio: bool) -> void:
	var antes: float = _encendida
	_encendida = k
	_llama.visible = k > 0.0
	_llama.scale = Vector2(1.0, k)
	_chispas.emitting = k > 0.6
	if _sonido != null and is_instance_valid(_sonido):
		_sonido.volume_db = _volumen + linear_to_db(maxf(k, 0.001))
	if not inicio and antes > 0.0 and k <= 0.0:
		_humo.restart()


func _particulas(cuantas: int, vida: float, mat: Material) -> CPUParticles2D:
	var c := CPUParticles2D.new()
	c.texture = _textura_chispa()
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	c.material = mat
	c.amount = cuantas
	c.lifetime = vida
	c.preprocess = vida
	c.randomness = 0.7
	c.local_coords = false
	c.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	c.direction = Vector2(0, -1)
	c.spread = 30.0
	c.initial_velocity_min = 8.0
	c.initial_velocity_max = 16.0
	c.gravity = Vector2(2.0, -4.0)
	var rampa := Gradient.new()
	rampa.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	rampa.set_color(1, Color(1.0, 0.45, 0.1, 0.0))
	c.color_ramp = rampa
	return c


static func _textura_chispa() -> ImageTexture:
	if _tex_chispa != null:
		return _tex_chispa
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	_tex_chispa = ImageTexture.create_from_image(img)
	return _tex_chispa
