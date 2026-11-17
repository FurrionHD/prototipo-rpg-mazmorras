# ============================================================
#  LAMINA DE LAS SOMBRAS EN EL JUEGO (17/11/2026, memoria sombras-fuera-del-sprite). CON VENTANA.
#  Fotos de verdad, con zoom, de la sombra del suelo: en el PUEBLO por la mañana, al mediodia, por la tarde y de noche
#  junto a las antorchas; y en la MAZMORRA (el farolillo del jugador y unos enemigos juntados a su alrededor, quietos).
#    LAMINA_SALIDA=C:/Users/dasui/Desktop/sombras/juego godot --path . res://tools/lamina_sombras_juego.tscn
# ============================================================
extends Node

const ZOOM := 3.0
# Los tonos (alfa del centro, el medio y el borde): a = los de ahora, b = media, c = fuerte.
const VARIANTES: Array = [Vector3(0.34, 0.24, 0.14), Vector3(0.55, 0.40, 0.25), Vector3(0.70, 0.52, 0.34)]
var _salida: String = ""


func _ready() -> void:
	_salida = OS.get_environment("LAMINA_SALIDA")
	if _salida == "":
		_salida = "user://lamina_sombras"
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _correr() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(_salida.get_base_dir())
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 4016831469
	# EL PUEBLO a cuatro horas.
	CicloDia.hora_forzada = CicloDia.T_DIA + 200.0
	Game.current_floor = 0
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar_jugador()
	await _frames(60)
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var u_dia: Array = [["1_manana", 0.2], ["2_mediodia", 0.5], ["3_tarde", 0.8]]
	for h in u_dia:
		CicloDia.hora_forzada = float(h[1]) * CicloDia.T_NOCHE
		await _frames(20)
		await _foto("pueblo_" + String(h[0]), jug)
	# De noche: entre dos focos de luz (dos sombras) y junto a uno solo.
	CicloDia.hora_forzada = CicloDia.T_NOCHE + 300.0
	var luz: Node = get_tree().get_first_node_in_group(&"luz_pueblo")
	if luz != null:
		var focos: Array = luz.focos()
		print("[lamina] focos del pueblo: %d" % focos.size())
		var par: Array = _dos_focos_cerca(focos)
		if not par.is_empty():
			var a: Vector2 = par[0]["pos"]
			var b: Vector2 = par[1]["pos"]
			jug.global_position = (a + b) * 0.5 + Vector2(0, 20)
			await _frames(30)
			await _foto("pueblo_4_noche_dos_luces", jug)
		if not focos.is_empty():
			var f0: Vector2 = focos[0]["pos"]
			jug.global_position = f0 + Vector2(30, 30)
			await _frames(30)
			await _foto("pueblo_5_noche_antorcha", jug)
	CicloDia.hora_forzada = -1.0
	# LA MAZMORRA.
	# Por la SALA PROPIA de las pruebas (jugar va siempre por la sala: el piso vive en su SubViewport, que no se pinta;
	# para la foto se enciende). Los enemigos los pone ella, a su alrededor, y se congelan.
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = hueco
	await _frames(5)
	var sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("lamina_sombras", 8, 424242, false):
		print("[lamina] no arranca la sala")
		get_tree().quit(1)
		return
	var vp: SubViewport = sala.piso.get_parent() as SubViewport
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	jug = sala.jugador
	# Los del piso (la sala solo pone a mano en la arena): uno de cada, los que vuelan primero, juntados alrededor.
	var vistos := {}
	var elegidos: Array = []
	var todos: Array = sala.enemigos()
	todos.sort_custom(func(x, y): return int(x.data.vuela) > int(y.data.vuela))
	for e in todos:
		if elegidos.size() < 4 and not vistos.has(e.data.enemy_name):
			vistos[e.data.enemy_name] = true
			elegidos.append(e)
	var huecos: Array = [Vector2(-60, -15), Vector2(60, -15), Vector2(-55, 45), Vector2(55, 45)]
	for i in elegidos.size():
		(elegidos[i] as Node2D).global_position = jug.global_position + huecos[i]
	await _frames(20)
	for e in todos:
		(e as Node).process_mode = Node.PROCESS_MODE_DISABLED
	for i in elegidos.size():
		(elegidos[i] as Node2D).global_position = jug.global_position + huecos[i]
	await _frames(5)
	print("[lamina] niebla en el piso: %s" % str(sala.piso.primero(&"niebla") != null))
	print("[lamina] mazmorra: %s" % ", ".join(elegidos.map(func(e): return String(e.data.enemy_name))))
	await _foto("mazmorra", jug, vp)
	# (depuracion) Lo que hay pintado alrededor de cada enemigo elegido.
	if OS.get_environment("LAMINA_DEPURA") == "1":
		var xf: Transform2D = vp.get_canvas_transform()
		for e in elegidos:
			print("[cerca] == %s en pantalla %s" % [e.data.enemy_name, str(xf * (e as Node2D).global_position)])
			for n in vp.find_children("*", "Node2D", true, false):
				var n2 := n as Node2D
				if n2.is_visible_in_tree() and n2.global_position.distance_to((e as Node2D).global_position) < 45.0 and not e.is_ancestor_of(n2) and n2 != e:
					print("[cerca]    %s %s %s pantalla %s" % [n2.name, n2.get_class(), n2.get_script().resource_path.get_file() if n2.get_script() else "", str(xf * n2.global_position)])
	await _frames(20)
	get_tree().quit(0)


func _dos_focos_cerca(focos: Array) -> Array:
	var mejor: float = INF
	var par: Array = []
	for i in focos.size():
		for j in range(i + 1, focos.size()):
			var d: float = (focos[i]["pos"] as Vector2).distance_to(focos[j]["pos"])
			var alcance: float = minf(float(focos[i]["radio"]), float(focos[j]["radio"]))
			if d > 40.0 and d < alcance * 1.6 and d < mejor:
				mejor = d
				par = [focos[i], focos[j]]
	return par


func _esperar_jugador() -> void:
	for k in 900:
		await get_tree().process_frame
		if get_tree().get_first_node_in_group("player") != null and not get_tree().paused:
			return


func _frames(n: int) -> void:
	for k in n:
		await get_tree().process_frame


# Con zoom sobre el jugador (su camara) y sin interfaz.
func _foto(nombre: String, jug: Node2D, vp: Viewport = null) -> void:
	if vp == null:
		vp = get_viewport()
	var cam: Camera2D = vp.get_camera_2d()
	if cam != null:
		cam.zoom = Vector2(ZOOM, ZOOM)
		cam.position_smoothing_enabled = false
		cam.global_position = jug.global_position
		cam.reset_smoothing()
	# Sin interfaz: fuera todas las capas menos las de la luz del pueblo y la niebla (la noche y el farolillo).
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var dueno: Node = n.get_parent()
		if dueno is LuzPueblo or (dueno != null and dueno.is_in_group(&"niebla")):
			continue
		(n as CanvasLayer).visible = false
	await _frames(8)
	await RenderingServer.frame_post_draw
	# Una foto por cada fuerza de los tonos (17/11: "no se ve una mierda, hay que hacerla mas destacable").
	for k in VARIANTES.size():
		for s in vp.find_children("*", "SombraSuelo", true, false):
			((s as CanvasItem).material as ShaderMaterial).set_shader_parameter("tonos", VARIANTES[k])
		await _frames(3)
		await RenderingServer.frame_post_draw
		var ruta: String = "%s_%s_%s.png" % [_salida, nombre, "abc"[k]]
		vp.get_texture().get_image().save_png(ruta)
		print("[foto] %s" % ruta)
