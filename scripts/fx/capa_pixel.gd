# ============================================================
#  capa_pixel.gd  (class_name CapaPixel)
#  LOS EFECTOS DE ANTES, EN PIXEL ART (04/11/2026, memoria efectos-pixel-personajes). El jefe: "se tienen que parecer a
#  las de antes pero pixel art". Asi que NO se redibujan: los mismos nodos de efecto (MagiaAire, MagiaMayor...) se pintan
#  tal cual, pero en un lienzo de 1 CELDA = 2x2 subpixeles (la rejilla de los sprites) que sigue a la camara;
#  pixelar.gdshader se queda con lo mas fuerte de cada celda, cierra la paleta (tono en escalones) y lo transparente a
#  medias va a trama Bayer de 2 celdas o fuera. Mismo dibujo, mismo color, mismo ritmo: solo cambia la rejilla.
#
#  COMO: CapaPixel.meter(efecto) MUDA el efecto a un MUNDO APARTE (el de los lienzos), colgado de un HUECO que copia
#  cada fotograma la posicion de su padre de verdad: el efecto sigue en el mismo sitio y con las mismas coordenadas,
#  pero la pantalla normal ya no lo pinta. Dos lienzos comparten ese mundo: el del SUELO (bajo los cuerpos) y el del
#  AIRE (encima); cada nodo del efecto va a uno u otro por su z (visibility_layer + canvas_cull_mask). Los huecos no
#  pintan nada, asi que pueden estar en los dos.
#  Si en ese visor no hay camara (o no se puede montar), el efecto se queda donde estaba y se ve como siempre.
# ============================================================
extends Node2D
class_name CapaPixel

const CELDA: float = SpriteLienzo.UNIDADES_POR_CELDA
const BIT_SUELO := 1 << 18
const BIT_AIRE := 1 << 19
const SHADER := preload("res://scripts/fx/pixelar.gdshader")
# El lienzo se pinta al DOBLE y cada celda se queda con lo mas fuerte de sus 4 subpixeles: un rayo de menos de una
# celda de grueso sale como linea continua de 1 celda, no en puntos sueltos (pixelar.gdshader).
const SUB := 2

static var _por_vista: Dictionary = {}   # id del visor -> CapaPixel

var _hojas: Array = []        # [{vp, spr, mat}]
var _raiz: Node2D             # la raiz del mundo aparte
var _huecos: Dictionary = {}  # id del padre de verdad -> {padre, hueco}


# Muda 'efecto' (recien añadido a su padre) a los lienzos de pixel de su visor.
# EL TINTE DE VIENTO (05/11, el set Filo de aire): mientras CombatTactico pinta un golpe de viento de los tuyos, lo que se
# meta aqui sale tenido (el MISMO golpe del arma, hecho de viento). Blanco = sin tinte.
const TINTE_VIENTO := Color(0.62, 1.0, 0.8, 0.8)
static var tinte: Color = Color.WHITE

static func meter(efecto: Node) -> void:
	if tinte != Color.WHITE and efecto is CanvasItem and is_instance_valid(efecto):
		(efecto as CanvasItem).modulate *= tinte
	if efecto == null or not is_instance_valid(efecto) or not efecto.is_inside_tree() or efecto.has_meta(&"pixel"):
		return
	var padre: Node = efecto.get_parent()
	if not (padre is Node2D):
		return
	var capa: CapaPixel = de_vista(efecto.get_viewport())
	if capa == null:
		return
	if not capa.is_inside_tree() or capa._raiz == null:
		# recien creada (se añade en diferido, por si la escena aun se esta montando): al fotograma siguiente
		CapaPixel.meter.call_deferred(efecto)
		return
	var hueco: Node2D = capa._hueco_de(padre as Node2D)
	efecto.set_meta(&"pixel", true)
	efecto.reparent(hueco, false)
	_marcar(efecto)
	if not efecto.child_entered_tree.is_connected(_al_entrar):
		efecto.child_entered_tree.connect(_al_entrar)


# El padre DE VERDAD de un efecto ya metido (no su hueco): para lo que el efecto deja en el mundo (la flecha clavada, la
# sangre del mapa), que tiene que quedarse en el mundo normal.
static func padre_real(n: Node) -> Node:
	var p: Node = n.get_parent() if n != null else null
	if p != null and p.has_meta(&"padre_real"):
		var r = p.get_meta(&"padre_real")
		if r != null and is_instance_valid(r):
			return r
	return p


# El hijo 'nombre' de 'padre', este donde este (si se metio en el pixel, vive en su hueco).
static func hijo_de(padre: Node, nombre: String) -> Node:
	if padre == null or not is_instance_valid(padre):
		return null
	var n: Node = padre.get_node_or_null(NodePath(nombre))
	if n != null or not padre.is_inside_tree():
		return n
	var capa = _por_vista.get(padre.get_viewport().get_instance_id())
	if capa != null and is_instance_valid(capa):
		var h = (capa as CapaPixel)._huecos.get(padre.get_instance_id())
		if h != null and is_instance_valid(h["hueco"]):
			return (h["hueco"] as Node).get_node_or_null(NodePath(nombre))
	return null


# Los efectos que se le metieron a 'padre' (ya no cuelgan de el, sino de su hueco): para quien los busque (las pruebas).
static func efectos_de(padre: Node, clase: String) -> Array:
	if padre == null:
		return []
	var out: Array = padre.find_children("*", clase, true, false)
	if not padre.is_inside_tree():
		return out
	var capa = _por_vista.get(padre.get_viewport().get_instance_id())
	if capa != null and is_instance_valid(capa):
		var h = (capa as CapaPixel)._huecos.get(padre.get_instance_id())
		if h != null and is_instance_valid(h["hueco"]):
			out.append_array((h["hueco"] as Node).find_children("*", clase, true, false))
	return out


# La capa de un visor (la monta la primera vez, colgada de la escena de ese visor).
static func de_vista(vista: Viewport) -> CapaPixel:
	if vista == null:
		return null
	var id: int = vista.get_instance_id()
	var c = _por_vista.get(id)
	if c != null and is_instance_valid(c) and not (c as Node).is_queued_for_deletion():
		return c
	var donde: Node = vista
	var tree := vista.get_tree()
	if tree != null and vista == tree.root and tree.current_scene != null:
		donde = tree.current_scene
	var capa := CapaPixel.new()
	capa.name = "CapaPixel"
	# en diferido: si la escena se esta montando (un _ready), añadirle un hijo ahora daria error
	donde.add_child.call_deferred(capa)
	_por_vista[id] = capa
	return capa


# Si un nodo ya metido cambia de z (la vara de la caña pasa de detras a delante del cuerpo), su lienzo se decide otra vez.
static func remarcar(n: Node) -> void:
	if n != null and n.has_meta(&"pixel"):
		var bits: int = _marcar(n)
		var p: Node = n.get_parent()
		while p is CanvasItem:
			(p as CanvasItem).visibility_layer |= bits
			p = p.get_parent()


static func _al_entrar(hijo: Node) -> void:
	var bits: int = _marcar(hijo)
	# y sus padres tienen que estar tambien en su lienzo (la raiz de un efecto de suelo con una capa de aire nueva)
	var p: Node = hijo.get_parent()
	while p is CanvasItem:
		(p as CanvasItem).visibility_layer |= bits
		p = p.get_parent()
	if not hijo.child_entered_tree.is_connected(_al_entrar):
		hijo.child_entered_tree.connect(_al_entrar)


static func _z_real(ci: CanvasItem) -> int:
	var z: int = 0
	var n: Node = ci
	while n != null and n is CanvasItem:
		z += (n as CanvasItem).z_index
		if not (n as CanvasItem).z_as_relative:
			break
		n = n.get_parent()
	return z


# Cada nodo, en el lienzo que le toca por su z Y en los de sus hijos (Godot solo pinta un nodo si el y todos sus padres
# comparten capa con el visor). Las raices de los efectos son contenedores que no pintan: estar en los dos no duplica.
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
	process_mode = Node.PROCESS_MODE_ALWAYS   # la pelea tactica pausa el arbol
	process_priority = 1000                    # despues de que la camara se mueva
	var suelo := _hoja(BIT_SUELO, SueloRoto.Z_SUELO + 2, null)
	_hojas.append(suelo)
	_hojas.append(_hoja(BIT_AIRE, Game.Z_ENCIMA_PERSONAJES + 79, (suelo["vp"] as SubViewport).world_2d))
	_raiz = Node2D.new()
	_raiz.name = "Raiz"
	_raiz.visibility_layer = BIT_SUELO | BIT_AIRE
	(suelo["vp"] as SubViewport).add_child(_raiz)
	_seguir()


func _exit_tree() -> void:
	for k in _por_vista.keys():
		if _por_vista[k] == self:
			_por_vista.erase(k)


func _hoja(bit: int, z: int, mundo: World2D) -> Dictionary:
	var vp := SubViewport.new()
	if mundo != null:
		vp.world_2d = mundo
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
	spr.scale = Vector2(CELDA, CELDA) / float(SUB)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.z_as_relative = false
	spr.z_index = z
	spr.material = mat
	add_child(spr)
	return {"vp": vp, "spr": spr, "mat": mat}


# El hueco de un padre: en el mundo aparte, con la posicion de su padre de verdad.
func _hueco_de(padre: Node2D) -> Node2D:
	var id: int = padre.get_instance_id()
	var h = _huecos.get(id)
	if h != null and is_instance_valid(h["hueco"]):
		return h["hueco"]
	var hueco := Node2D.new()
	hueco.visibility_layer = BIT_SUELO | BIT_AIRE
	hueco.set_meta(&"padre_real", padre)
	# la z del padre (un cuerpo): lo que va con z RELATIVA a el (detras/delante del muñeco) sigue en su sitio
	hueco.z_as_relative = false
	hueco.z_index = _z_real(padre) if padre is CanvasItem else 0
	_raiz.add_child(hueco)
	hueco.global_transform = padre.global_transform
	_huecos[id] = {"padre": padre, "hueco": hueco}
	return hueco


func _process(_delta: float) -> void:
	_seguir()


func _seguir() -> void:
	# Los huecos, donde esten sus padres (y fuera los que ya no tienen ni padre ni efectos).
	for id in _huecos.keys():
		var h: Dictionary = _huecos[id]
		var hueco: Node2D = h["hueco"]
		var padre = h["padre"]
		if not is_instance_valid(padre) or not (padre as Node).is_inside_tree():
			if is_instance_valid(hueco):
				hueco.queue_free()
			_huecos.erase(id)
			continue
		hueco.global_transform = (padre as Node2D).global_transform
		hueco.z_index = _z_real(padre as CanvasItem)
		# y si se ve: lo que cuelga de un cuerpo escondido (sigilo, muerto) se escondia con el
		hueco.visible = (padre as CanvasItem).is_visible_in_tree()
	# El lienzo cubre lo que se ve, empezando en una celda del mundo (los pixeles no reptan al moverse la camara).
	var vista := get_viewport()
	var inv: Transform2D = vista.get_canvas_transform().affine_inverse()
	var tam: Vector2 = vista.get_visible_rect().size
	var a: Vector2 = inv * Vector2.ZERO
	var b: Vector2 = inv * tam
	var c0: Vector2 = (Vector2(minf(a.x, b.x), minf(a.y, b.y)) / CELDA).floor() - Vector2.ONE
	var lado := Vector2i(ceili(absf(b.x - a.x) / CELDA) + 3, ceili(absf(b.y - a.y) / CELDA) + 3)
	for h2 in _hojas:
		var vp: SubViewport = h2["vp"]
		if vp.size != lado * SUB:
			vp.size = lado * SUB
		vp.canvas_transform = Transform2D(0.0, Vector2.ONE * float(SUB) / CELDA, 0.0, -c0 * float(SUB))
		(h2["spr"] as Sprite2D).global_position = c0 * CELDA
		(h2["mat"] as ShaderMaterial).set_shader_parameter("celda0", c0)
