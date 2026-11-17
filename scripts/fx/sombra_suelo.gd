# ============================================================
#  LA SOMBRA DEL SUELO (16/11/2026, memoria sombras-fuera-del-sprite)
#  La sombra ya NO va horneada en el dibujo (subia y bajaba con el que flota, se veia a traves de los translucidos y
#  pisaba los charcos): la pinta el juego, debajo de cada enemigo y de cada personaje.
#
#  PIXEL ART CON TONOS FIJOS, sin degradado (su encargo): tres escalones, centro oscuro, medio y borde claro, cada uno de
#  un tono fijo (negro con un alfa fijo, como la transparencia de verdad: escalones, no trama). Se pinta en la MISMA
#  rejilla que el sprite (sus pixeles son del tamaño de los del dibujo).
#
#  La mancha de CONTACTO siempre, justo debajo; y por cada luz que le llega (LucesSombra: el sol y las antorchas del
#  pueblo; los farolillos y las flores de la mazmorra), la misma mancha ESTIRADA hacia el lado contrario. Las pinta todas
#  un shader (shaders/sombra_suelo.gdshader) para que al cruzarse se queden con el tono mas oscuro, sin sumarse.
#
#  Va a una z ABSOLUTA justo por debajo de todos los personajes (Game.Z_PERSONAJES - 1): por encima del suelo y de los
#  charcos, por debajo de cualquier cuerpo (la de uno no tapa los pies del de al lado).
# ============================================================
class_name SombraSuelo
extends Node2D

# Los tres tonos (alfa sobre negro) y sus cortes viven en shaders/sombra_suelo.gdshader.
const SHADER: Shader = preload("res://shaders/sombra_suelo.gdshader")
const MAX_LUCES := 8                 # los que admite el shader (las mas fuertes, si hubiera mas)
# El que flota la tiene algo mas pequeña (esta mas lejos del suelo).
const ESCALA_VUELA := 0.75
# Aplastada por la camara a 45 grados: alto = ancho x esto.
const APLASTADO := 0.42
# Cada cuanto se miran las luces (s). Las sombras no tienen que seguir a la luz al fotograma.
const CADA := 0.1
# Lo alto que es el cuerpo, en radios de su mancha: con esto se mide lo larga que sale su sombra.
const ALTO_EN_RADIOS := 3.0

var _rx: float = 0.0
var _ry: float = 0.0
var _mat: ShaderMaterial = null
var _luces := PackedVector4Array()   # las que se pintan ahora (ver LucesSombra)
var _t: float = 0.0
var _en_menu: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	_poner_uniformes()
	# En un MENU (el muñeco del personaje, del hogar, un visor) cada cosa va con sus z propias en su capa de interfaz: ahi
	# la sombra va por debajo de todo lo suyo, relativa a quien la lleva, y no hay luces (solo la de contacto).
	if get_canvas_layer_node() != null:
		_en_menu = true
		z_as_relative = true
		z_index = -100
		set_process(false)
		return
	z_as_relative = false
	z_index = Game.Z_PERSONAJES - 1
	# Que no miren todas las sombras las luces en el mismo fotograma. SIN randf(): gastaria un numero del azar global y
	# cambiaria lo que sale despues en la pelea (lo pillo prueba_huella_combate, 17/11).
	_t = float(get_instance_id() % 97) / 97.0 * CADA


# El tamaño, en pixeles de la rejilla del dibujo (radio en x; el alto sale de APLASTADO).
func medir(radio_x: float, vuela: bool = false) -> void:
	_rx = maxf(round(radio_x * (ESCALA_VUELA if vuela else 1.0)), 2.0)
	_ry = maxf(round(_rx * APLASTADO), 1.0)
	_poner_uniformes()


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or not is_visible_in_tree():
		return
	_t = CADA
	var nuevas: PackedVector4Array = _luces_locales()
	if nuevas != _luces:
		_luces = nuevas
		_poner_uniformes()


# Las luces que le llegan (LucesSombra, en el mundo) pasadas a SU rejilla: la direccion y el largo, en pixeles del dibujo.
func _luces_locales() -> PackedVector4Array:
	var out := PackedVector4Array()
	var esc: float = maxf(absf(global_transform.get_scale().x), 0.001)
	var alto_mundo: float = _rx * ALTO_EN_RADIOS * esc
	for l in LucesSombra.en(self, global_position, alto_mundo):
		if out.size() >= MAX_LUCES:
			break
		var d: Vector2 = l["dir"]
		# Redondeado (la direccion a 1/32 de vuelta y el largo al pixel): asi una sombra quieta no se repinta por decimales.
		var ang: float = snappedf(d.angle(), TAU / 32.0)
		out.append(Vector4(cos(ang), sin(ang), round(float(l["largo"]) / esc), float(l["nivel"])))
	return out


func _poner_uniformes() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("contacto", Vector2(_rx, _ry))
	_mat.set_shader_parameter("n_luces", _luces.size())
	var arr: Array = []
	for v in _luces:
		arr.append(Vector4(v.x, v.y, v.z, v.w))
	while arr.size() < MAX_LUCES:
		arr.append(Vector4.ZERO)
	_mat.set_shader_parameter("luces", arr)
	queue_redraw()


# Un rectangulo que cubre la mancha y la mas larga de sus sombras; lo pinta el shader.
func _draw() -> void:
	var r: float = _rx + 2.0
	for v in _luces:
		r = maxf(r, v.z + _rx * 1.5 + 2.0)
	draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), Color.WHITE)


# ------------------------------------------------------------
#  ENEMIGOS: cuelga del sprite (hereda su escala, la del mutante tambien, y su visibilidad y modulate: el que se
#  esconde en las sombras se lleva la suya) y se pone en su PUNTO DEL SUELO (SpriteLienzo.META_PIES de sus hojas).
#  'tam' = su cuerpo en unidades de mundo (SpritesEnemigo.tam_cuerpo); 'escala' = la de su sprite sin el mutante.
# ------------------------------------------------------------
static func poner_en_enemigo(sprite: AnimatedSprite2D, tam: Vector2, escala: float, vuela: bool) -> SombraSuelo:
	if sprite == null:
		return null
	var s: SombraSuelo = null
	for h in sprite.get_children():
		if h is SombraSuelo:
			s = h
	if s == null:
		s = SombraSuelo.new()
		s.name = "SombraSuelo"
		sprite.add_child(s)
	var ancho: float = tam.x
	if ancho <= 0.0 and sprite.sprite_frames != null:
		# Sin geometria declarada: un cuarto del lienzo (el aire de las animaciones lo hace mucho mas grande que el cuerpo).
		var t0: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, 0) if sprite.sprite_frames.has_animation(sprite.animation) else null
		ancho = float(t0.get_width()) * 0.5 * escala if t0 != null else 16.0
	s.medir(ancho * 0.5 * 0.85 / maxf(escala, 0.01), vuela)
	s.colocar(sprite)
	if not sprite.sprite_frames_changed.is_connected(s.colocar.bind(sprite)):
		sprite.sprite_frames_changed.connect(s.colocar.bind(sprite))
	return s


# La escala de su sprite SIN el x1,2 del mutante (ese lo hereda la sombra del sprite), como la pone enemy.gd.
static func escala_sin_mutante(ed: EnemyData) -> float:
	var esc: float = SpritesEnemigo.escala_de(ed)
	if SpritesEnemigo.hay_que_estirar(ed):
		esc *= maxf(0.1, ed.escala_visual)
	return esc


# Si flota: el de la ficha o el de su mutacion (el Ojo de la tormenta).
static func vuela_de(ed: EnemyData, mutante: bool, mutacion: StringName) -> bool:
	if ed == null:
		return false
	if ed.vuela:
		return true
	if mutante and mutacion != &"":
		var m: MutacionData = ed.mutacion_de(mutacion)
		return m != null and m.vuela
	return false


# A su punto del suelo (cambia si cambian sus hojas: al mutar).
func colocar(sprite: AnimatedSprite2D) -> void:
	var sf: SpriteFrames = sprite.sprite_frames
	position = sf.get_meta(SpriteLienzo.META_PIES) if sf != null and sf.has_meta(SpriteLienzo.META_PIES) else Vector2.ZERO
	position += sprite.offset


# ------------------------------------------------------------
#  EL MUÑECO DEL JUGADOR (y compañeros, guardias...): en sus pies (PoseJugador.PIES_BAJO_NODO), en la rejilla de sus
#  capas (escala_sprite). Medida sobre la que llevaba horneada el cuerpo (unos 14 x 5 celdas).
# ------------------------------------------------------------
const RADIO_JUGADOR := 7.0

static func poner_en_muneco(muneco: Node2D) -> SombraSuelo:
	for h in muneco.get_children():
		if h is SombraSuelo:
			return h
	var s := SombraSuelo.new()
	s.name = "SombraSuelo"
	s.position = Vector2(0.0, PoseJugador.PIES_BAJO_NODO)
	s.scale = Vector2.ONE * PoseJugador.escala_sprite()
	muneco.add_child(s)
	muneco.move_child(s, 0)
	s.medir(RADIO_JUGADOR)
	return s
