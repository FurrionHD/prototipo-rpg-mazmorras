# ============================================================
#  dev_modelo_3d.gd  --  HERRAMIENTA, no parte del juego.
#
#  Renderiza el modelo 3D de REFERENCIA (tools/modelos/, ver CREDITOS.txt) desde la camara del juego
#  en las 8 direcciones, al lado de nuestro muñeco, y MIDE donde caen los ojos y la boca.
#
#  Por que existe: los rasgos de la cara se colocaban a ojo y cada arreglo en una direccion rompia
#  otra (ver CaraSprites.SITIOS). Un modelo girando de verdad dice que se ve y que se tapa.
#
#  LA CAMARA ES LA DEL JUEGO, no una parecida: ortografica e inclinada CAMARA_GRADOS, que es
#  exactamente pantalla_y = y·cos45 − z·sin45 (PoseJugador.proyectar). Alto 60 u (ALTO_MUNDO), un
#  pixel = UNIDADES_POR_CELDA, lienzo de PoseJugador.celdas() y pies en PoseJugador.origen(). Asi un
#  pixel del render a 84 es un pixel de nuestro sprite.
#
#  EL MODELO NO TRAE CARA (ni UV, ni esqueleto): los ojos y la boca son elipsoides pegados a la
#  superficie de la cabeza con un rayo. Su sitio sale de las mismas proporciones que CaraSprites
#  (en radios de cabeza), asi que lo que se mide es solo lo que hace la GEOMETRIA al girar.
#
#  Salida en tools/salida/modelo3d/:
#    modelo3d_8dirs.png   render grande / render a 84 px / nuestro muñeco en guardia
#    modelo3d_cara.png    la cabeza de cerca: render grande / a 84 px / nuestro muñeco con cruces
#                         donde el modelo pone ojos (rojo = ojo izq. del personaje, verde = der.) y
#                         boca (azul)
#    modelo3d_armas.png   pequeña / espada / mandoble / espada + escudo, a 84 px
#    modelo3d_cara.json   por direccion: centro de cada rasgo relativo al centro de la cabeza (en
#                         pixeles de sprite), ancho y alto visibles y que fraccion queda tapada
#
#  Necesita VENTANA (en --headless no se dibuja): herramientas/ver_modelo_3d.bat
# ============================================================
extends Node

const SALIDA := "res://tools/salida/modelo3d/"
const DIR_NOMBRES := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
const FONDO := Color(0.11, 0.12, 0.15)
# El render grande: HI veces el de juego.
const HI := 8
# Hacia donde mira el modelo en crudo, en radianes sobre la vertical. 0 = hacia +Z (la camara).
const YAW_MODELO := 0.0
# Proporciones de la cara en radios de cabeza, las de CaraSprites / altura-en-pantalla-no-es-la-z.
const OJO_BAJA := 0.18
const OJO_LADO := 0.34
const BOCA_BAJA := 0.42
# Recorte de la cabeza en la hoja de la cara, en pixeles de sprite.
const CABEZA_LADO := 36
# Armas: [nombre, largo en u de mundo, factor de ancho]. La pequeña es la misma espada corta y ancha.
const ARMAS := [["pequena", 17.0, 1.4], ["espada", 30.0, 1.0], ["mandoble", 45.0, 1.15]]
const ESCUDO_ALTO := 28.0
const TOPE_S := 60.0

var _lado: int
var _origen: Vector2
var _svp: SubViewport
var _svp_hi: SubViewport
var _cam: Camera3D
var _cam_hi: Camera3D
var _personaje: Node3D
var _cuerpo: MeshInstance3D
var _marcas: Dictionary = {}          # "ojo_izq" / "ojo_der" / "boca" -> MeshInstance3D
var _armas_nodos: Dictionary = {}     # nombre -> Node3D
var _escudo: Node3D
var _centro_cabeza := Vector3.ZERO
var _mat_cuerpo: StandardMaterial3D
var _mat_marca: StandardMaterial3D
var _svp2d: SubViewport
var _muneco: MunecoJugador


func _ready() -> void:
	var tope := get_tree().create_timer(TOPE_S)
	tope.timeout.connect(_por_tope)
	_lado = PoseJugador.celdas()
	_origen = PoseJugador.origen()
	_montar_mundo()
	_montar_modelo()
	_montar_muneco()
	DirAccess.make_dir_recursive_absolute(SALIDA)
	await _hoja_8dirs()
	await _hoja_cara()
	await _hoja_armas()
	get_tree().quit()


func _por_tope() -> void:
	push_error("[modelo 3d] tope de %d s: algo se ha quedado esperando" % int(TOPE_S))
	get_tree().quit(1)


# ------------------------------------------------------------
#  MUNDO 3D: dos viewports (84 y 84*HI) mirando el mismo mundo
# ------------------------------------------------------------
func _montar_mundo() -> void:
	_svp = _viewport(_lado)
	_svp.own_world_3d = true
	_svp_hi = _viewport(_lado * HI)
	add_child(_svp)
	add_child(_svp_hi)
	_svp_hi.world_3d = _svp.find_world_3d()
	_cam = _camara()
	_svp.add_child(_cam)
	_cam_hi = _camara()
	_svp_hi.add_child(_cam_hi)

	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	luz.light_energy = 0.9
	_svp.add_child(luz)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.6)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	_svp.add_child(we)


func _viewport(lado: int) -> SubViewport:
	var v := SubViewport.new()
	v.size = Vector2i(lado, lado)
	v.transparent_bg = true
	v.msaa_3d = Viewport.MSAA_DISABLED
	v.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return v


# El centro del lienzo tiene que caer donde cae en el sprite: los pies (origen del mundo) van en
# PoseJugador.origen(), asi que la camara apunta al punto que queda (centro - origen) por encima.
func _camara() -> Camera3D:
	var c := Camera3D.new()
	c.projection = Camera3D.PROJECTION_ORTHOGONAL
	c.size = _lado * SpriteLienzo.UNIDADES_POR_CELDA
	c.near = 1.0
	c.far = 2000.0
	var sube_px: float = _origen.y - _lado * 0.5
	var ang: float = deg_to_rad(SpriteLienzo.CAMARA_GRADOS)
	var h: float = sube_px * SpriteLienzo.UNIDADES_POR_CELDA / cos(ang)
	var objetivo := Vector3(0.0, h, 0.0)
	c.rotation = Vector3(-ang, 0.0, 0.0)
	c.position = objetivo + Vector3(0.0, sin(ang), cos(ang)) * 500.0
	return c


# ------------------------------------------------------------
#  EL MODELO: normalizado a 60 u, pies en el origen, mirando a +Z
# ------------------------------------------------------------
func _montar_modelo() -> void:
	_personaje = Node3D.new()
	_svp.add_child(_personaje)

	var raiz_chibi: Node = load("res://tools/modelos/chibi_base_mesh.glb").instantiate()
	var malla: Mesh = _primera_malla(raiz_chibi).mesh
	raiz_chibi.free()
	# Del glb: la malla es Z-up y el nodo padre la pone Y-up.
	var crudo := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	crudo = Basis(Vector3.UP, YAW_MODELO) * crudo
	var arr: Array = malla.surface_get_arrays(0)
	var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var vs := PackedVector3Array()
	vs.resize(pos.size())
	var y0 := INF
	var y1 := -INF
	for i in pos.size():
		vs[i] = crudo * pos[i]
		y0 = minf(y0, vs[i].y)
		y1 = maxf(y1, vs[i].y)
	var esc: float = PoseJugador.ALTO_MUNDO / (y1 - y0)
	# Centrado por los PIES, no por la caja: la cabeza del chibi puede ir adelantada.
	var pies := Vector3.ZERO
	var n_pies := 0
	for v in vs:
		if v.y < y0 + (y1 - y0) * 0.08:
			pies += v
			n_pies += 1
	pies /= maxf(1.0, n_pies)
	var t := Transform3D(crudo.scaled(Vector3.ONE * esc), Vector3(-pies.x, -y0, -pies.z) * esc)
	for i in vs.size():
		vs[i] = Vector3(vs[i].x - pies.x, vs[i].y - y0, vs[i].z - pies.z) * esc

	_mat_cuerpo = StandardMaterial3D.new()
	_mat_cuerpo.albedo_color = Color(0.86, 0.78, 0.72)
	_mat_cuerpo.roughness = 1.0
	_mat_cuerpo.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cuerpo = MeshInstance3D.new()
	_cuerpo.mesh = malla
	_cuerpo.transform = t
	_cuerpo.material_override = _mat_cuerpo
	_personaje.add_child(_cuerpo)

	var cab: Dictionary = _medir_cabeza(vs)
	_centro_cabeza = cab["centro"]
	print("[modelo 3d] escala %.3f · cuello a %.1f u · cabeza centro %s radios %s" % [
		esc, cab["cuello"], str(cab["centro"]), str(cab["radios"])])

	var tris: PackedVector3Array = _triangulos(arr, t)
	_mat_marca = StandardMaterial3D.new()
	_mat_marca.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_marca.albedo_color = Color(0.07, 0.05, 0.05)
	var c: Vector3 = cab["centro"]
	var r: Vector3 = cab["radios"]
	var y_ojo: float = c.y - OJO_BAJA * r.y
	_marca("ojo_izq", tris, Vector2(c.x + OJO_LADO * r.x, y_ojo), Vector3(0.10 * r.x, 0.15 * r.y, 0.06 * r.z))
	_marca("ojo_der", tris, Vector2(c.x - OJO_LADO * r.x, y_ojo), Vector3(0.10 * r.x, 0.15 * r.y, 0.06 * r.z))
	_marca("boca", tris, Vector2(c.x, c.y - BOCA_BAJA * r.y), Vector3(0.16 * r.x, 0.05 * r.y, 0.05 * r.z))

	# Las manos: el vertice mas abierto a la altura de los brazos (A-pose, brazos caidos).
	var mano_der: Vector3 = _mano(vs, -1.0)
	var mano_izq: Vector3 = _mano(vs, 1.0)
	print("[modelo 3d] manos: der %s · izq %s" % [str(mano_der), str(mano_izq)])
	var raiz_espada: Node = load("res://tools/modelos/low_poly_sword.glb").instantiate()
	var espada_malla: Mesh = _primera_malla(raiz_espada).mesh
	raiz_espada.free()
	for a in ARMAS:
		var nodo: Node3D = _espada(espada_malla, float(a[1]), float(a[2]))
		nodo.position = mano_der
		nodo.visible = false
		_personaje.add_child(nodo)
		_armas_nodos[String(a[0])] = nodo
	_escudo = _montar_escudo(mano_izq)
	_escudo.visible = false
	_personaje.add_child(_escudo)


func _primera_malla(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for h in n.get_children():
		var m: MeshInstance3D = _primera_malla(h)
		if m != null:
			return m
	return null


# El cuello es el corte mas estrecho entre el tronco y la cabeza; la cabeza, todo lo de encima.
func _medir_cabeza(vs: PackedVector3Array) -> Dictionary:
	var alto: float = PoseJugador.ALTO_MUNDO
	var mejor_y: float = alto * 0.5
	var mejor_ancho := INF
	var y: float = alto * 0.35
	while y < alto * 0.70:
		var x0 := INF
		var x1 := -INF
		for v in vs:
			if absf(v.y - y) < alto * 0.012:
				x0 = minf(x0, v.x)
				x1 = maxf(x1, v.x)
		if x1 > x0 and x1 - x0 < mejor_ancho:
			mejor_ancho = x1 - x0
			mejor_y = y
		y += alto * 0.005
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for v in vs:
		if v.y > mejor_y:
			lo = lo.min(v)
			hi = hi.max(v)
	return {"cuello": mejor_y, "centro": (lo + hi) * 0.5, "radios": (hi - lo) * 0.5}


func _mano(vs: PackedVector3Array, lado: float) -> Vector3:
	var alto: float = PoseJugador.ALTO_MUNDO
	var extremo := -INF
	for v in vs:
		if v.y > alto * 0.10 and v.y < alto * 0.45:
			extremo = maxf(extremo, v.x * lado)
	var suma := Vector3.ZERO
	var n := 0
	for v in vs:
		if v.y > alto * 0.10 and v.y < alto * 0.45 and v.x * lado > extremo - alto * 0.05:
			suma += v
			n += 1
	return suma / maxf(1.0, n)


func _triangulos(arr: Array, t: Transform3D) -> PackedVector3Array:
	var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var out := PackedVector3Array()
	var idx = arr[Mesh.ARRAY_INDEX]
	if idx != null and (idx as PackedInt32Array).size() > 0:
		for i in idx:
			out.append(t * pos[i])
	else:
		for p in pos:
			out.append(t * p)
	return out


# Pega un elipsoide a la superficie: rayo desde delante (+Z) en (x, y) y el primer triangulo que toca.
func _marca(nombre: String, tris: PackedVector3Array, xy: Vector2, radios: Vector3) -> void:
	var desde := Vector3(xy.x, xy.y, 500.0)
	var hacia := Vector3(0, 0, -1)
	var mejor := -INF
	var normal := Vector3(0, 0, 1)
	var punto := Vector3(xy.x, xy.y, 0.0)
	for i in range(0, tris.size() - 2, 3):
		var hit = Geometry3D.ray_intersects_triangle(desde, hacia, tris[i], tris[i + 1], tris[i + 2])
		if hit != null and (hit as Vector3).z > mejor:
			mejor = (hit as Vector3).z
			punto = hit
			normal = (tris[i + 1] - tris[i]).cross(tris[i + 2] - tris[i]).normalized()
			if normal.z < 0.0:
				normal = -normal
	if mejor == -INF:
		push_error("[modelo 3d] el rayo de '%s' no toca la cabeza" % nombre)
	var eje_x: Vector3 = Vector3.UP.cross(normal).normalized()
	var eje_y: Vector3 = normal.cross(eje_x).normalized()
	var m := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 1.0
	esfera.height = 2.0
	m.mesh = esfera
	m.transform = Transform3D(Basis(eje_x * radios.x, eje_y * radios.y, normal * radios.z),
		punto + normal * radios.z * 0.3)
	m.material_override = _mat_marca
	_personaje.add_child(m)
	_marcas[nombre] = m
	print("[modelo 3d] %s en %s normal %s" % [nombre, str(punto), str(normal)])


# La espada con el PUÑO en el origen y la hoja hacia delante y arriba (guardia), filo en vertical.
# En la malla cruda la hoja va por z (pomo −8,2 · puño −4 · punta 25) y el nodo Cube la escala
# 1,6955 en x y 0,4575 en y/z: el ancho real es x3,7 el grosor.
func _espada(malla: Mesh, largo: float, ancho: float) -> Node3D:
	var s: float = largo / 33.26
	var interior := MeshInstance3D.new()
	interior.mesh = malla
	var b := Basis(Vector3(1, 0, 0) * s * 3.706 * ancho, Vector3(0, 0, -1) * s * ancho, Vector3(0, 1, 0) * s)
	interior.transform = Transform3D(b, -(b * Vector3(0, 0, -4.0)))
	var pivote := Node3D.new()
	pivote.basis = Basis(Vector3.RIGHT, deg_to_rad(60.0)) * Basis(Vector3.UP, deg_to_rad(90.0))
	pivote.add_child(interior)
	return pivote


# El escudo en el antebrazo izquierdo, cara hacia fuera (+X). Malla cruda: plancha y 0..15,6 de alto,
# cara delantera a z=0 mirando a −z, asa detras.
func _montar_escudo(mano: Vector3) -> Node3D:
	var raiz: Node = load("res://tools/modelos/minecraft_shield.glb").instantiate()
	var nodo := Node3D.new()
	var s: float = ESCUDO_ALTO / 15.56
	var b := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)).scaled(Vector3.ONE * s)
	var cuelga := [raiz]
	while not cuelga.is_empty():
		var n: Node = cuelga.pop_back()
		if n is MeshInstance3D:
			var m := MeshInstance3D.new()
			m.mesh = (n as MeshInstance3D).mesh
			m.transform = Transform3D(b, -(b * Vector3(0, 7.78, 0.7)))
			nodo.add_child(m)
		cuelga.append_array(n.get_children())
	raiz.free()
	nodo.position = mano + Vector3(3.0, 4.0, 0.0)
	return nodo


# ------------------------------------------------------------
#  NUESTRO MUÑECO, en un viewport 2D del tamaño del sprite
# ------------------------------------------------------------
func _montar_muneco() -> void:
	_svp2d = SubViewport.new()
	_svp2d.size = Vector2i(_lado, _lado)
	_svp2d.transparent_bg = true
	_svp2d.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_svp2d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_svp2d)
	# Sin foto y con ojos dibujados, que es la cara que se esta rehaciendo.
	Game.set_imagen_cuerpo(PackedByteArray())
	var pj: PersonajeData = Game.lider()
	var pc: Dictionary = pj.pieza("cara")
	pj.poner_pieza("cara", "chibi", pc["color"], pc["metal"])
	_muneco = MunecoJugador.new()
	_muneco.scale = Vector2.ONE / SpriteLienzo.UNIDADES_POR_CELDA
	# El nodo del muñeco esta PIES_BAJO_NODO por encima de los pies.
	_muneco.position = _origen - Vector2(0.0, PoseJugador.PIES_BAJO_NODO / SpriteLienzo.UNIDADES_POR_CELDA)
	_svp2d.add_child(_muneco)


func _equipar(arma: String, escudo: bool) -> void:
	var pj: PersonajeData = Game.lider()
	pj.equipped_main = load("res://resources/weapons/%s.tres" % arma) if arma != "" else null
	pj.equipped_off = load("res://resources/shields/escudo_grande.tres") if escudo else null
	_muneco.montar(pj)
	_muneco.tenir(pj.color, 0.0)


# ------------------------------------------------------------
#  CAPTURAS
# ------------------------------------------------------------
func _girar(d: int) -> void:
	var ang: float = PoseJugador.DIR_VECS[d].angle() - PoseJugador.DIR_VECS[0].angle()
	_personaje.rotation = Vector3(0.0, -ang, 0.0)


func _esperar() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw


func _sobre_fondo(img: Image) -> Image:
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	out.fill(FONDO)
	img.convert(Image.FORMAT_RGBA8)
	out.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	return out


func _ampliar(img: Image, f: int) -> Image:
	var c: Image = img.duplicate()
	c.resize(c.get_width() * f, c.get_height() * f, Image.INTERPOLATE_NEAREST)
	return c


func _mostrar_armas(arma: String, escudo: bool) -> void:
	for k in _armas_nodos:
		_armas_nodos[k].visible = k == arma
	_escudo.visible = escudo


func _hoja_8dirs() -> void:
	const Z := 4
	var celda: int = _lado * Z
	var hoja := Image.create(celda * 8, celda * 3, false, Image.FORMAT_RGBA8)
	hoja.fill(FONDO)
	_mostrar_armas("espada", false)
	_equipar("espada_corta", false)
	for d in 8:
		_girar(d)
		_muneco.fijar("guardia_%d" % d, 0)
		await _esperar()
		var hi: Image = _sobre_fondo(_svp_hi.get_texture().get_image())
		hi.resize(celda, celda, Image.INTERPOLATE_BILINEAR)
		hoja.blit_rect(hi, Rect2i(0, 0, celda, celda), Vector2i(d * celda, 0))
		var bajo: Image = _ampliar(_sobre_fondo(_svp.get_texture().get_image()), Z)
		hoja.blit_rect(bajo, Rect2i(0, 0, celda, celda), Vector2i(d * celda, celda))
		var mu: Image = _ampliar(_sobre_fondo(_svp2d.get_texture().get_image()), Z)
		hoja.blit_rect(mu, Rect2i(0, 0, celda, celda), Vector2i(d * celda, celda * 2))
	var ruta := SALIDA + "modelo3d_8dirs.png"
	hoja.save_png(ruta)
	print("[modelo 3d] ", ProjectSettings.globalize_path(ruta))


const COLORES_MARCA := {"ojo_izq": Color(1, 0, 0), "ojo_der": Color(0, 1, 0), "boca": Color(0, 0, 1)}

func _hoja_cara() -> void:
	const Z := 8
	var celda: int = CABEZA_LADO * Z
	var hoja := Image.create(celda * 8, celda * 3, false, Image.FORMAT_RGBA8)
	hoja.fill(FONDO)
	_mostrar_armas("", false)
	_equipar("", false)
	var datos := {}
	for d in 8:
		_girar(d)
		_muneco.fijar("idle_%d" % d, 0)
		# 1) Normal.
		await _esperar()
		var hi: Image = _sobre_fondo(_svp_hi.get_texture().get_image())
		var bajo: Image = _sobre_fondo(_svp.get_texture().get_image())
		var mu: Image = _sobre_fondo(_svp2d.get_texture().get_image())
		var cab_hi: Vector2 = _cam_hi.unproject_position(_personaje.transform * _centro_cabeza)
		var cab: Vector2 = cab_hi / HI
		# 2) Medida: todo plano; cada rasgo de su color y el cuerpo gris tapando.
		var plano := StandardMaterial3D.new()
		plano.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		plano.albedo_color = Color(0.3, 0.3, 0.3)
		plano.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cuerpo.material_override = plano
		for k in _marcas:
			var mm := StandardMaterial3D.new()
			mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mm.albedo_color = COLORES_MARCA[k]
			_marcas[k].material_override = mm
		await _esperar()
		# Solo la zona de la cabeza: recorrer los 672x672 enteros pixel a pixel es lo lento.
		var zona := Rect2i(Vector2i(cab_hi) - Vector2i.ONE * CABEZA_LADO * HI / 2,
			Vector2i.ONE * CABEZA_LADO * HI).intersection(Rect2i(Vector2i.ZERO, Vector2i.ONE * _lado * HI))
		var con_cuerpo: Image = _svp_hi.get_texture().get_image().get_region(zona)
		_cuerpo.visible = false
		await _esperar()
		var sin_cuerpo: Image = _svp_hi.get_texture().get_image().get_region(zona)
		_cuerpo.visible = true
		_cuerpo.material_override = _mat_cuerpo
		for k in _marcas:
			_marcas[k].material_override = _mat_marca

		var esq: Dictionary = PoseJugador.esqueleto("idle", 0, d)
		var cab_nuestra: Vector2i = CaraSprites.centro_cabeza(esq)
		var fila := {"centro_cabeza_modelo": [snappedf(cab.x, 0.01), snappedf(cab.y, 0.01)],
			"centro_cabeza_muneco": [cab_nuestra.x, cab_nuestra.y]}
		var cruces: Array = []
		for k in COLORES_MARCA:
			var vis: Dictionary = _mancha(con_cuerpo, COLORES_MARCA[k])
			var tot: Dictionary = _mancha(sin_cuerpo, COLORES_MARCA[k])
			var f := {"visible": snappedf(float(vis["n"]) / maxf(1.0, float(tot["n"])), 0.01)}
			if int(vis["n"]) > 0:
				var rel: Vector2 = (vis["centro"] + Vector2(zona.position)) / HI - cab
				f["rel"] = [snappedf(rel.x, 0.01), snappedf(rel.y, 0.01)]
				f["ancho"] = snappedf(vis["tam"].x / HI, 0.01)
				f["alto"] = snappedf(vis["tam"].y / HI, 0.01)
				cruces.append([rel, COLORES_MARCA[k]])
			fila[k] = f
		datos[DIR_NOMBRES[d]] = fila

		_pegar_cabeza(hoja, hi, cab_hi, HI, Z / float(HI), d, 0, [])
		_pegar_cabeza(hoja, bajo, cab, 1, Z, d, 1, [])
		_pegar_cabeza(hoja, mu, Vector2(cab_nuestra) + Vector2(0.5, 0.5), 1, Z, d, 2, cruces)
	var ruta := SALIDA + "modelo3d_cara.png"
	hoja.save_png(ruta)
	var f := FileAccess.open(SALIDA + "modelo3d_cara.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(datos, "  "))
	f.close()
	print("[modelo 3d] ", ProjectSettings.globalize_path(ruta))
	for k in datos:
		print("[modelo 3d] %s %s" % [k, JSON.stringify(datos[k])])


# Recorta CABEZA_LADO pixeles de sprite alrededor del centro de la cabeza y los pega en su celda.
# 'escala_img' = pixeles de imagen por pixel de sprite; 'z' = ampliacion final por pixel de sprite.
func _pegar_cabeza(hoja: Image, img: Image, centro: Vector2, escala_img: int, z: float, col: int,
		fila: int, cruces: Array) -> void:
	var lado_img: int = CABEZA_LADO * escala_img
	var esq := Vector2i(int(round(centro.x - lado_img * 0.5)), int(round(centro.y - lado_img * 0.5)))
	var trozo := Image.create(lado_img, lado_img, false, Image.FORMAT_RGBA8)
	trozo.fill(FONDO)
	trozo.blit_rect(img, Rect2i(esq, Vector2i(lado_img, lado_img)), Vector2i.ZERO)
	var celda: int = CABEZA_LADO * 8
	var interp: int = Image.INTERPOLATE_NEAREST if z >= 1.0 else Image.INTERPOLATE_BILINEAR
	trozo.resize(celda, celda, interp)
	for c in cruces:
		var p: Vector2 = (centro + (c[0] as Vector2) - Vector2(esq)) * 8.0
		for i in range(-6, 7):
			for grosor in [-1, 0, 1]:
				_punto(trozo, Vector2i(int(p.x) + i, int(p.y) + grosor), c[1])
				_punto(trozo, Vector2i(int(p.x) + grosor, int(p.y) + i), c[1])
	hoja.blit_rect(trozo, Rect2i(0, 0, celda, celda), Vector2i(col * celda, fila * celda))


func _punto(img: Image, p: Vector2i, c: Color) -> void:
	if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
		img.set_pixelv(p, c)


func _mancha(img: Image, color: Color) -> Dictionary:
	var n := 0
	var suma := Vector2.ZERO
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.5 and absf(c.r - color.r) < 0.1 and absf(c.g - color.g) < 0.1 \
					and absf(c.b - color.b) < 0.1:
				n += 1
				var p := Vector2(x + 0.5, y + 0.5)
				suma += p
				lo = lo.min(p)
				hi = hi.max(p)
	if n == 0:
		return {"n": 0}
	return {"n": n, "centro": suma / n, "tam": hi - lo + Vector2.ONE}


func _hoja_armas() -> void:
	const Z := 4
	var celda: int = _lado * Z
	var casos := [["pequena", false], ["espada", false], ["mandoble", false], ["espada", true]]
	var hoja := Image.create(celda * 8, celda * casos.size(), false, Image.FORMAT_RGBA8)
	hoja.fill(FONDO)
	for i in casos.size():
		_mostrar_armas(String(casos[i][0]), bool(casos[i][1]))
		for d in 8:
			_girar(d)
			await _esperar()
			var bajo: Image = _ampliar(_sobre_fondo(_svp.get_texture().get_image()), Z)
			hoja.blit_rect(bajo, Rect2i(0, 0, celda, celda), Vector2i(d * celda, i * celda))
	var ruta := SALIDA + "modelo3d_armas.png"
	hoja.save_png(ruta)
	print("[modelo 3d] ", ProjectSettings.globalize_path(ruta))
