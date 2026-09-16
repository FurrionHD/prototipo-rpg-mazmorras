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
#  FOCOS. Quien alumbra (antorcha, ventana, altar) se apunta con `poner_foco`. Cada fotograma se
#  mandan al shader SOLO los que caen cerca de la camara, con su intensidad de ese momento (las
#  antorchas se encienden al atardecer; el altar alumbra siempre).
# ============================================================
extends Node2D
class_name LuzPueblo

# Lo que admite el shader (focos[48]).
const MAX_FOCOS := 48

var _capa: CanvasLayer = null
var _lienzo: ColorRect = null
var _mat: ShaderMaterial = null

# [{pos: Vector2, radio: float, color: Color, fuerza: float, retraso: float, siempre: bool,
#   latido: float}]
var _focos: Array = []

var _pos := PackedVector4Array()
var _col := PackedVector4Array()


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
	_pos.resize(MAX_FOCOS)
	_col.resize(MAX_FOCOS)
	_process(0.0)


# 'radio' en px de mundo. 'color' = a que color devuelve la luz (blanco = como de dia). 'retraso'
# 0..1 = cuanto tarda en encenderse dentro del atardecer. 'siempre' = no depende de la hora (el altar).
func poner_foco(pos: Vector2, radio: float, color: Color, fuerza: float = 1.0,
		retraso: float = 0.0, siempre: bool = false) -> void:
	_focos.append({"pos": pos, "radio": radio, "color": color, "fuerza": fuerza,
		"retraso": retraso, "siempre": siempre})


func _process(_delta: float) -> void:
	var s: float = CicloDia.segundo()
	if CicloDia.es_pleno_dia(s):
		_lienzo.visible = false
		return
	_lienzo.visible = true
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
		if n >= MAX_FOCOS:
			break
		var p: Vector2 = f["pos"]
		var r: float = float(f["radio"])
		if vista.size.x > 0.0 and not vista.grow(r).has_point(p):
			continue
		# El altar alumbra siempre, pero de dia no se nota: su fuerza sigue a lo oscuro que este.
		var k: float = noche if bool(f["siempre"]) else CicloDia.luces(float(f["retraso"]), s)
		k *= float(f["fuerza"])
		if k <= 0.01:
			continue
		var c: Color = f["color"]
		_pos[n] = Vector4(p.x, p.y, r, k)
		_col[n] = Vector4(c.r, c.g, c.b, 1.0)
		n += 1
	_mat.set_shader_parameter("n_focos", n)
	if n > 0:
		_mat.set_shader_parameter("focos", _pos)
		_mat.set_shader_parameter("colores", _col)
