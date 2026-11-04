# ============================================================
#  capa_pixel.gd  (class_name CapaPixel)
#  LOS EFECTOS DE ANTES, EN PIXEL ART (04/11/2026, memoria efectos-pixel-personajes). El jefe: "se tienen que parecer a
#  las de antes pero pixel art". Asi que NO se redibujan: los mismos nodos de efecto (MagiaAire, MagiaMayor, SueloRoto...)
#  se pintan tal cual, pero en vez de en la pantalla, en un lienzo de 1 CELDA = 1 PIXEL (la rejilla de los sprites) que
#  sigue a la camara; pixelar.gdshader cierra la paleta (tono en escalones) y lo transparente a medias va a trama Bayer
#  de 2 celdas o fuera. Mismo dibujo, mismo color, mismo ritmo: solo cambia la rejilla.
#  Dos lienzos: lo del SUELO (bajo los cuerpos) y lo del AIRE (encima). Cada efecto se apunta con CapaPixel.meter(nodo):
#  el y todos sus hijos (tambien los que salgan despues) pasan a la capa de visibilidad del lienzo que les toca por su z.
# ============================================================
extends Node2D
class_name CapaPixel

const CELDA: float = SpriteLienzo.UNIDADES_POR_CELDA
const BIT_SUELO := 1 << 18
const BIT_AIRE := 1 << 19
const SHADER := preload("res://scripts/fx/pixelar.gdshader")

var _hojas: Array = []   # [{vp, spr, bit}]


static func meter(n: Node) -> void:
	if n == null:
		return
	# Godot solo pinta un nodo en un visor si EL Y TODOS SUS PADRES comparten capa con el: los padres se quedan en la
	# suya y ademas en las de los lienzos (lo que pinten ellos mismos tambien saldria pixelado: que no pinten nada).
	var p: Node = n.get_parent()
	while p != null:
		if p is CanvasItem:
			(p as CanvasItem).visibility_layer |= BIT_SUELO | BIT_AIRE
		p = p.get_parent()
	_marcar(n)
	if not n.child_entered_tree.is_connected(_al_entrar):
		n.child_entered_tree.connect(_al_entrar)


static func _al_entrar(hijo: Node) -> void:
	meter(hijo)


static func _z_real(ci: CanvasItem) -> int:
	var z: int = 0
	var n: Node = ci
	while n != null and n is CanvasItem:
		z += (n as CanvasItem).z_index
		if not (n as CanvasItem).z_as_relative:
			break
		n = n.get_parent()
	return z


# Cada nodo, en la capa que le toca por su z Y en las de sus hijos (si no, el hijo no se pinta: ver meter). Las raices
# de los efectos son contenedores que no pintan, asi que estar en las dos no duplica nada.
static func _marcar(n: Node) -> int:
	var bits: int = 0
	for h in n.get_children():
		bits |= _marcar(h)
		if not h.child_entered_tree.is_connected(_al_entrar):
			h.child_entered_tree.connect(_al_entrar)
	if n is CanvasItem:
		var ci := n as CanvasItem
		bits |= BIT_SUELO if _z_real(ci) < Game.Z_PERSONAJES else BIT_AIRE
		ci.visibility_layer = bits
	return bits


func _ready() -> void:
	process_priority = 1000    # despues de que la camara se mueva
	var vista := get_viewport()
	vista.canvas_cull_mask = vista.canvas_cull_mask & ~(BIT_SUELO | BIT_AIRE)
	_hojas.append(_hoja(BIT_SUELO, SueloRoto.Z_SUELO + 2))
	_hojas.append(_hoja(BIT_AIRE, Game.Z_ENCIMA_PERSONAJES + 79))


func _hoja(bit: int, z: int) -> Dictionary:
	var vp := SubViewport.new()
	vp.world_2d = get_viewport().world_2d
	vp.canvas_cull_mask = bit
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(8, 8)
	add_child(vp)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var spr := Sprite2D.new()
	spr.texture = vp.get_texture()
	spr.centered = false
	spr.top_level = true
	spr.scale = Vector2(CELDA, CELDA)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.z_as_relative = false
	spr.z_index = z
	spr.material = mat
	add_child(spr)
	return {"vp": vp, "spr": spr, "mat": mat}


func _process(_delta: float) -> void:
	_seguir()


# El lienzo cubre lo que se ve, empezando en una celda del mundo (los pixeles no reptan al moverse la camara).
func _seguir() -> void:
	var vista := get_viewport()
	var inv: Transform2D = vista.get_canvas_transform().affine_inverse()
	var tam: Vector2 = vista.get_visible_rect().size
	var a: Vector2 = inv * Vector2.ZERO
	var b: Vector2 = inv * tam
	var c0: Vector2 = (Vector2(minf(a.x, b.x), minf(a.y, b.y)) / CELDA).floor() - Vector2.ONE
	var lado := Vector2i(ceili(absf(b.x - a.x) / CELDA) + 3, ceili(absf(b.y - a.y) / CELDA) + 3)
	for h in _hojas:
		var vp: SubViewport = h["vp"]
		if vp.size != lado:
			vp.size = lado
		vp.canvas_transform = Transform2D(0.0, Vector2(1.0 / CELDA, 1.0 / CELDA), 0.0, -c0)
		(h["spr"] as Sprite2D).global_position = c0 * CELDA
		(h["mat"] as ShaderMaterial).set_shader_parameter("celda0", c0)
