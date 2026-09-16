# ============================================================
#  luz_pueblo.gd  (class_name LuzPueblo)
#  EL DIA Y LA NOCHE DEL PUEBLO: pinta la hora de CicloDia con shaders/noche_pueblo.gdshader.
#
#  Es la misma forma que la niebla de la mazmorra (scripts/world/niebla.gd): una CanvasLayer 3, entre
#  el mundo (0) y el HUD (5), con un ColorRect a pantalla completa. Pero aqui no hay Vision ni rayos:
#  en el pueblo no hay nada que esconder, solo un color y unos corros de luz.
#
#  Cuelga de town.gd, asi que solo existe en el pueblo.
#
#  TRES COSAS:
#    - FOCOS (`poner_foco`): corros donde el tinte de la noche vuelve al color de esa luz. Cada fotograma
#      se mandan al shader SOLO los que caen cerca de la camara.
#    - RESPLANDOR: el shader MULTIPLICA, asi que como mucho devuelve el color de dia; no puede hacer que
#      algo brille. Por eso cada foco puede llevar ademas un halo ADITIVO flojo, en la CanvasLayer 4 (por
#      encima del tinte, por debajo del HUD) y siguiendo a la camara.
#    - ENCENDIBLES (`poner_encendible`): nodos que aparecen al anochecer (el vidrio de las ventanas).
# ============================================================
extends Node2D
class_name LuzPueblo

# Lo que admite el shader (focos[48]).
const MAX_FOCOS := 48

var _capa: CanvasLayer = null
var _lienzo: ColorRect = null
var _mat: ShaderMaterial = null
var _capa_halo: CanvasLayer = null

# [{pos, radio, color, fuerza, retraso, siempre, halo: Sprite2D o null, halo_a, fase}]
var _focos: Array = []
# [[CanvasItem, retraso]]
var _encendibles: Array = []

var _pos := PackedVector4Array()
var _col := PackedVector4Array()
var _t: float = 0.0

static var _tex_halo: ImageTexture = null


func _ready() -> void:
	add_to_group("luz_pueblo")
	# Los menus paran el arbol (Game.abrir_menu) y la pesca se juega en pausa: la luz tiene que
	# seguir a la camara igual. Solo pinta, asi que no hay nada que "cobrar" por correr en pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capa = CanvasLayer.new()
	_capa.layer = 3
	add_child(_capa)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/noche_pueblo.gdshader")
	_lienzo = ColorRect.new()
	_lienzo.material = _mat
	_lienzo.color = Color(1, 1, 1, 1)
	_lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lienzo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_capa.add_child(_lienzo)
	_capa_halo = CanvasLayer.new()
	_capa_halo.layer = 4
	_capa_halo.follow_viewport_enabled = true
	add_child(_capa_halo)
	_pos.resize(MAX_FOCOS)
	_col.resize(MAX_FOCOS)


# 'pos' y 'radio' en px de mundo. 'color' = a que color devuelve la luz (blanco = como de dia).
# 'retraso' 0..1 = cuanto tarda en encenderse dentro del atardecer. 'siempre' = no depende de la hora
# (el altar). 'halo' = alfa del resplandor aditivo (0 = sin halo); su radio es el del foco por
# 'halo_radio'.
func poner_foco(pos: Vector2, radio: float, color: Color, fuerza: float = 1.0,
		retraso: float = 0.0, siempre: bool = false, halo: float = 0.0, halo_radio: float = 0.6) -> void:
	var f := {"pos": pos, "radio": radio, "color": color, "fuerza": fuerza,
		"retraso": retraso, "siempre": siempre, "halo": null, "halo_a": halo,
		"fase": fposmod(pos.x * 0.137 + pos.y * 0.071, TAU)}
	if halo > 0.0:
		var s := Sprite2D.new()
		s.texture = _textura_halo()
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = m
		s.position = pos
		# La textura mide 64 px de diametro.
		s.scale = Vector2.ONE * (radio * halo_radio * 2.0 / 64.0)
		s.modulate = Color(color.r, color.g, color.b, 0.0)
		s.visible = false
		_capa_halo.add_child(s)
		f["halo"] = s
	_focos.append(f)


func poner_encendible(nodo: CanvasItem, retraso: float = 0.0) -> void:
	nodo.modulate.a = 0.0
	nodo.visible = false
	_encendibles.append([nodo, retraso])


func _process(delta: float) -> void:
	_t += delta
	var s: float = CicloDia.segundo()
	var de_dia: bool = CicloDia.es_pleno_dia(s)
	for e in _encendibles:
		var n: CanvasItem = e[0]
		if not is_instance_valid(n):
			continue
		var k: float = 0.0 if de_dia else CicloDia.luces(float(e[1]), s)
		n.visible = k > 0.0
		n.modulate.a = k
	if de_dia:
		_lienzo.visible = false
		_capa_halo.visible = false
		return
	_lienzo.visible = true
	_capa_halo.visible = true
	var t: Color = CicloDia.tinte(s)
	_mat.set_shader_parameter("tinte", Vector3(t.r, t.g, t.b))
	var cam: Camera2D = get_viewport().get_camera_2d()
	var vista := Rect2()
	if cam != null:
		_mat.set_shader_parameter("cam_centro", cam.get_screen_center_position())
		_mat.set_shader_parameter("cam_zoom", cam.zoom)
		var tam: Vector2 = get_viewport_rect().size / cam.zoom
		vista = Rect2(cam.get_screen_center_position() - tam * 0.5, tam)
	_mat.set_shader_parameter("pantalla", get_viewport_rect().size)
	_mandar_focos(s, vista)


func _mandar_focos(s: float, vista: Rect2) -> void:
	var noche: float = CicloDia.noche(s)
	var n: int = 0
	for f in _focos:
		var p: Vector2 = f["pos"]
		var r: float = float(f["radio"])
		# El altar alumbra siempre, pero de dia no se nota: su fuerza sigue a lo oscuro que este.
		var k: float = noche if bool(f["siempre"]) else CicloDia.luces(float(f["retraso"]), s)
		k *= float(f["fuerza"])
		var halo: Sprite2D = f["halo"]
		var en_vista: bool = vista.size.x <= 0.0 or vista.grow(r).has_point(p)
		if halo != null:
			halo.visible = en_vista and k > 0.01
			if halo.visible:
				# El resplandor late despacio, cada uno a su ritmo.
				var ph: float = float(f["fase"])
				var latido: float = 1.0 + 0.10 * sin(_t * 2.3 + ph) + 0.05 * sin(_t * 3.7 + ph * 2.0)
				halo.modulate.a = float(f["halo_a"]) * k * noche * latido
		if not en_vista or k <= 0.01 or n >= MAX_FOCOS:
			continue
		var c: Color = f["color"]
		_pos[n] = Vector4(p.x, p.y, r, k)
		_col[n] = Vector4(c.r, c.g, c.b, 1.0)
		n += 1
	_mat.set_shader_parameter("n_focos", n)
	if n > 0:
		_mat.set_shader_parameter("focos", _pos)
		_mat.set_shader_parameter("colores", _col)


# Un circulo en escalones de alfa (pixel-art, como el halo del altar), de 64 px: se escala por foco.
static func _textura_halo() -> ImageTexture:
	if _tex_halo != null:
		return _tex_halo
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var r: float = Vector2(float(x) + 0.5 - 32.0, float(y) + 0.5 - 32.0).length() / 32.0
			var a: float = 0.0
			if r < 0.30:
				a = 1.0
			elif r < 0.55:
				a = 0.6
			elif r < 0.80:
				a = 0.32
			elif r < 1.0:
				a = 0.12
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_tex_halo = ImageTexture.create_from_image(img)
	return _tex_halo
