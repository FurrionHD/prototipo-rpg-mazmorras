# ============================================================
#  dev_arbol.gd  --  HERRAMIENTA, no parte del juego.
#
#  "Los arboles de la mazmorra tienen que tapar al que pasa por detras": carga el piso 1 y el 7, busca un
#  arbol (resource_node de madera) y planta al jugador DETRAS, DELANTE y AL LADO (como en la faena de
#  talar). Capturas tools/salida/arbol_p<piso>_<donde>.png y se cierra.
#  Con ventana:  godot --path . res://tools/visores/dev_arbol.tscn
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
const MAIN := "res://scenes/levels/main.tscn"
const PartidaDePrueba = preload("res://tools/visores/partida_de_prueba.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(SALIDA)
	Perfil.ranura_actual = 0
	Mundos.abierto = ""
	PartidaDePrueba.llenar()
	Game.semilla_mundo = 12345   # sin partida la mazmorra se va al menu (ver dev_escaleras)
	for piso in [1, 7]:
		await _piso(piso)
	get_tree().quit()


func _piso(piso: int) -> void:
	Game.current_floor = piso
	get_tree().current_scene.scene_file_path = MAIN
	var mundo: Node = (load(MAIN) as PackedScene).instantiate()
	add_child(mundo)
	for k in 8:
		await get_tree().process_frame
	for e in get_tree().get_nodes_in_group("enemy"):
		(e as Node).queue_free()
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	var cam := jugador.get_node("Camera2D") as Camera2D
	cam.zoom = Vector2(3.0, 3.0)
	cam.position_smoothing_enabled = false
	var arbol: Node2D = null
	for n in get_tree().get_nodes_in_group("recolectable"):
		if n.has_method("es_madera") and n.es_madera():
			arbol = n
			break
	if arbol == null:
		print("[arbol] piso %d: sin arboles" % piso)
	else:
		var sitios := {"detras": Vector2(6, -40), "delante": Vector2(6, 26), "lado": Vector2(30, 0)}
		for donde in sitios:
			jugador.global_position = arbol.global_position + sitios[donde]
			for k in 12:
				await get_tree().process_frame
				for c in get_tree().get_nodes_in_group("aliado"):
					if c != jugador:
						(c as Node2D).visible = false
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%sarbol_p%d_%s.png" % [SALIDA, piso, donde])
			print("[arbol] piso %d %s: z del arbol %d" % [piso, donde, arbol.z_index])
	get_tree().paused = false
	mundo.queue_free()
	for k in 3:
		await get_tree().process_frame
