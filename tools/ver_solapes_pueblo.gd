# ============================================================
#  ver_solapes_pueblo.gd  --  HERRAMIENTA, no parte del juego (C2 del playtest 11/10).
#
#  LOS SOLAPES DEL PUEBLO, para que el usuario los vea ANTES de tocar nada: monta el pueblo de verdad y, con
#  un ejemplar de cada adorno (luces, carteles, adornos de las casas, muebles de la plaza y del mercadillo,
#  la fuente, el altar, la verja y una casa), arrima el jugador CON LA FISICA (move_and_collide: hasta donde
#  de verdad le deja llegar) por detras, por delante y por un lado, y pone uno delante y otro detras a la vez.
#  Cada caso, un recorte en tools/salida/solapes/ y una linea en indice.txt; la hoja la monta
#  tools/hoja_solapes_pueblo.py. CON VENTANA (se abre un momento y se cierra sola):
#    godot --path . res://tools/ver_solapes_pueblo.tscn
# ============================================================
extends Node

const SALIDA := "res://tools/salida/solapes/"
const PUEBLO := "res://scenes/levels/town.tscn"
const PartidaDePrueba = preload("res://tools/visores/partida_de_prueba.gd")
const MARCO := 30.0   # lo que se ve alrededor de la pieza

var _pueblo: Node2D = null
var _jug: CharacterBody2D = null
var _comp: Node2D = null
var _sobran: Array = []   # los demas del grupo: fuera de la foto en cada captura
var _cam: Camera2D = null
var _pies: Vector2 = Vector2.ZERO   # del origen del jugador al centro de su caja de pies
var _indice: PackedStringArray = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(SALIDA)
	PartidaDePrueba.llenar()
	CicloDia.hora_forzada = CicloDia.T_DIA + CicloDia.DIA * 0.5   # a mediodia: de noche no se ve nada
	get_tree().current_scene.scene_file_path = PUEBLO
	_pueblo = (load(PUEBLO) as PackedScene).instantiate() as Node2D
	add_child(_pueblo)
	_jug = _pueblo.get_node("Player") as CharacterBody2D
	for _i in 10:
		await get_tree().physics_frame
	_pies = (_jug.get_node("CollisionShape2D") as Node2D).position
	_jug.set_physics_process(false)
	# La FILA DEL GRUPO (PartyTrail) lleva a los compañeros detras del jugador: quieta, o el que pongo delante vuelve andando.
	for t in _todas_de_clase(get_tree().root, "party_trail.gd"):
		(t as Node).set_physics_process(false)
	for n in get_tree().get_nodes_in_group("aliado"):
		if n == _jug or not (n is Node2D):
			continue
		(n as Node).set_physics_process(false)
		if _comp == null:
			_comp = n
		else:
			_sobran.append(n)
	_cam = _jug.get_node("Camera2D") as Camera2D
	_cam.position_smoothing_enabled = false
	_cam.limit_left = -100000
	_cam.limit_top = -100000
	_cam.limit_right = 100000
	_cam.limit_bottom = 100000

	var n := 0
	for p in _lista():
		n += 1
		await _casos(n, p)
	var f := FileAccess.open(SALIDA + "indice.txt", FileAccess.WRITE)
	f.store_string("\n".join(_indice))
	f.close()
	print("[solapes] %d recortes en %s" % [_indice.size(), ProjectSettings.globalize_path(SALIDA)])
	CicloDia.hora_forzada = -1.0
	get_tree().quit()


# UN EJEMPLAR DE CADA: [rotulo, clave de la pieza, huella en casillas].
func _lista() -> Array:
	var out: Array = []
	var vistos := {}
	out.append(["poste de antorcha", "poste_antorcha", Rect2i(PuebloPlano.POSTES[0], Vector2i.ONE)])
	out.append(["brasero", "brasero", Rect2i(PuebloPlano.BRASEROS[0], Vector2i.ONE)])
	out.append(["cartel indicador", "cartel_indicador", Rect2i(PuebloPlano.CARTELES[3]["casilla"], Vector2i.ONE)])
	for a in PuebloPlano.adornos():
		if vistos.has(a[0]):
			continue
		vistos[a[0]] = true
		out.append([String(a[0]) + " (casa)", String(a[0]), Rect2i(a[1], Vector2i.ONE)])
	vistos.clear()
	for m in PuebloPlano.MUEBLES:
		if vistos.has(m[0]):
			continue
		vistos[m[0]] = true
		out.append([String(m[0]) + (" (mercado)" if String(m[0]) in ["cajas", "sacos", "barriles"] else ""), String(m[0]), m[1]])
	out.append(["fuente", "fuente", PuebloPlano.FUENTE])
	out.append(["columna del altar", "altar_columna", Rect2i(PuebloPlano.ALTAR, Vector2i.ONE)])
	out.append(["verja (abajo)", "verja", Rect2i(Vector2i(PuebloPlano.JARDIN.position.x + 2, PuebloPlano.JARDIN.end.y - 1), Vector2i.ONE)])
	out.append(["escalera de la plaza", "escalera_caracol", PuebloPlano.ESCALERA])
	for casa in PuebloPlano.CASAS:
		if String(casa["clave"]) == "taberna":
			out.append(["casa (taberna) y su cartel", "casa_", casa["rect"]])
	return out


func _casos(n: int, item: Array) -> void:
	var rotulo: String = item[0]
	var huella: Rect2i = item[2]
	var pieza: PiezaPueblo = _buscar_pieza(String(item[1]), huella)
	if pieza == null:
		print("[solapes] MAL: no encuentro la pieza %s en %s" % [item[1], huella])
		return
	var caja: Rect2 = _caja(huella, String(item[1]).begins_with("casa_"))
	var tam: Vector2 = Vector2(pieza.get("_tam"))
	var dibujo := Rect2(pieza.global_position, tam)
	var vista: Rect2 = dibujo.merge(caja).grow(MARCO)
	vista = vista.grow_individual(0, 40.0, 0, 0)   # sitio para la cabeza del de detras
	var cx: float = caja.get_center().x
	# Hasta donde le deja llegar la fisica, empezando lejos.
	var detras: Vector2 = _arrimar(Vector2(cx, caja.position.y - 44.0), Vector2(0, 88))
	var delante: Vector2 = _arrimar(Vector2(cx, caja.end.y + 44.0), Vector2(0, -88))
	var lado: Vector2 = _arrimar(Vector2(caja.end.x + 44.0, caja.get_center().y), Vector2(-88, 0))
	var fuera := Vector2(-5000, -5000)
	var casos := [
		["por detras", detras, fuera],
		["por delante", delante, fuera],
		["de lado", lado, fuera],
		["uno detras y otro delante", detras, delante],
	]
	for k in casos.size():
		var c: Array = casos[k]
		if c[1] == Vector2.INF or (c[2] != fuera and c[2] == Vector2.INF):
			_indice.append("%s\t%s\t-" % [rotulo, c[0]])
			continue
		_jug.global_position = c[1]
		if _comp != null:
			# Escondido cuando no sale: si se le manda lejos, la fila del grupo lo vuelve a traer al lado.
			# Y FUERA DEL GRUPO: escondido seguiria contando para las piezas como "alguien detras" (PiezaPueblo._personajes).
			_comp.visible = c[2] != fuera
			if _comp.visible:
				_comp.add_to_group("aliado")
			else:
				_comp.remove_from_group("aliado")
			_comp.global_position = c[2]
		var archivo: String = "%02d_%d.png" % [n, k]
		await _captura(vista, archivo)
		_indice.append("%s\t%s\t%s" % [rotulo, c[0], archivo])
		print("[solapes] %s / %s: pies y=%.0f | base de la pieza y=%.0f, corte arriba/abajo y=%.0f, caja y=%.0f..%.0f | z pieza=%d, z muñeco=%d" % [
			rotulo, c[0], c[1].y + _pies.y, pieza.base_y(), pieza.global_position.y + tam.y - float(pieza.get("_pie")),
			caja.position.y, caja.end.y, pieza.z_index, _z_muneco(_jug)])


# Mueve el jugador desde 'desde' (sus PIES alli) por 'mov' hasta que choca. INF si arranca metido en algo
# (no hay sitio por ese lado: la pared de la casa detras de un barril, por ejemplo).
func _arrimar(desde_pies: Vector2, mov: Vector2) -> Vector2:
	var desde: Vector2 = desde_pies - _pies
	if _jug.test_move(Transform2D(0.0, desde), Vector2.ZERO):
		return Vector2.INF
	_jug.global_position = desde
	var col: KinematicCollision2D = _jug.move_and_collide(mov)
	if col == null:
		return Vector2.INF   # no llega a tocarla: la caja no esta donde se cree
	return _jug.global_position


func _captura(vista: Rect2, archivo: String) -> void:
	var z: float = minf(minf(1280.0 / vista.size.x, 720.0 / vista.size.y), 3.0)
	_cam.zoom = Vector2(z, z)
	_cam.offset = vista.get_center() - _jug.global_position
	_cam.reset_smoothing()
	# Fuera de la foto todo muñeco que no sea uno de los dos (compañeros de mas, guardias, aldeanos). Los
	# vendedores no: son parte del puesto.
	for m in get_tree().get_nodes_in_group(&"munecos_jugador"):
		var dueno: Node = m
		while dueno != null and not (dueno is CharacterBody2D) and not (dueno is VendedorMercadillo):
			dueno = dueno.get_parent()
		if dueno == null or dueno == _jug or dueno == _comp or dueno is VendedorMercadillo:
			continue
		if dueno is CanvasItem and (dueno as CanvasItem).visible:
			print("[solapes] escondo %s (%s)" % [dueno.name, dueno.get_groups()])
			(dueno as CanvasItem).visible = false
			dueno.remove_from_group("aliado")
	for _i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var vp: Viewport = get_viewport()
	var ct: Transform2D = vp.get_canvas_transform()
	var r := Rect2(ct * vista.position, vista.size * z)
	var im: Image = vp.get_texture().get_image()
	var ri := Rect2i(r).intersection(Rect2i(Vector2i.ZERO, im.get_size()))
	im.get_region(ri).save_png(SALIDA + archivo)


# La pieza de esa clave mas cerca de su huella (las casas: la que tenga la clave por delante, "casa_...").
func _buscar_pieza(clave: String, huella: Rect2i) -> PiezaPueblo:
	var donde: Vector2 = Vector2(huella.position) * float(PuebloPlano.CELDA)
	var mejor: PiezaPueblo = null
	var mejor_d: float = INF
	for p in _todas(_pueblo):
		var pc: String = p.clave
		var vale: bool = pc.begins_with(clave) if clave.ends_with("_") or clave == "verja" else pc == clave
		if not vale:
			continue
		var d: float = (p.global_position + Vector2(p.get("_tam")) * 0.5).distance_to(
			donde + Vector2(huella.size) * float(PuebloPlano.CELDA) * 0.5)
		if d < mejor_d:
			mejor_d = d
			mejor = p
	return mejor


func _todas(n: Node) -> Array:
	var out: Array = []
	if n is PiezaPueblo:
		out.append(n)
	for h in n.get_children():
		out.append_array(_todas(h))
	return out


# Lo que choca dentro de la huella: las cajas pequeñas cuyo centro cae en ella; la casa, entera.
func _caja(huella: Rect2i, entera: bool) -> Rect2:
	if huella == PuebloPlano.ESCALERA:
		# La caracol choca con un circulo (su pretil), que no esta en las cajas pequeñas: la huella entera.
		entera = true
	var cel: float = float(PuebloPlano.CELDA)
	var px := Rect2(Vector2(huella.position) * cel, Vector2(huella.size) * cel)
	if entera:
		return px
	var out := Rect2()
	for r in PuebloPlano.cajas_pequenas():
		if px.grow(2.0).has_point(r.get_center()):
			out = r if out.size == Vector2.ZERO else out.merge(r)
	return out if out.size != Vector2.ZERO else px


func _todas_de_clase(n: Node, clase: String) -> Array:
	var out: Array = []
	var sc: Script = n.get_script()
	if sc != null and sc.resource_path.ends_with(clase):
		out.append(n)
	for h in n.get_children():
		out.append_array(_todas_de_clase(h, clase))
	return out


func _z_muneco(n: Node) -> int:
	for h in n.get_children():
		if h.is_in_group(&"munecos_jugador"):
			return int(h.z_index)
	return -1
