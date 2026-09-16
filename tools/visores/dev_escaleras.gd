# ============================================================
#  dev_escaleras.gd  --  HERRAMIENTA, no parte del juego.
#
#  LAS ESCALERAS DE LA MAZMORRA EN SU SUELO DE VERDAD: carga main.tscn en varios pisos (1, 2, 6, 7, 12),
#  abre las salidas (bajada y, en los pisos de jefe, la salida al pueblo) y saca una captura con el
#  jugador al lado de cada una: bajar, subir, puerta del piso 1 y salida al pueblo.
#  Capturas tools/salida/escalera_<prefijo>_p<piso>_<cual>.png y se cierra.
#  Con ventana:  godot --path . res://tools/visores/dev_escaleras.tscn -- [prefijo]
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
const MAIN := "res://scenes/levels/main.tscn"
const PartidaDePrueba = preload("res://tools/visores/partida_de_prueba.gd")
const PISOS := [1, 2, 6, 7, 12]

var _prefijo := "antes"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(SALIDA)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() >= 1:
		_prefijo = args[0]
	# Segundo argumento: la HORA del pueblo en segundos del ciclo (la luz que entra por la caracol la sigue).
	if args.size() >= 2:
		CicloDia.hora_forzada = float(args[1])
	Perfil.ranura_actual = 0
	Mundos.abierto = ""
	PartidaDePrueba.llenar()
	# SIN SEMILLA NO HAY PARTIDA y la mazmorra se va sola al menu principal (DungeonFloor._ready), llevandose
	# este visor por delante: la ventana se quedaba en el menu y no se cerraba nunca.
	Game.semilla_mundo = 12345
	# Los jefes de los pisos 6 y 12, muertos: sin eso no hay bajada ni salida al pueblo en su piso.
	for p in PISOS:
		if Game.BOSSES.has(p):
			Game.marcar_boss_derrotado(p)
	for piso in PISOS:
		await _piso(piso)
	get_tree().quit()


func _piso(piso: int) -> void:
	Game.current_floor = piso
	get_tree().current_scene.scene_file_path = MAIN
	var mundo: Node = (load(MAIN) as PackedScene).instantiate()
	add_child(mundo)
	for k in 8:
		await get_tree().process_frame
	var suelo: Node = _buscar(mundo, "abrir_salidas")
	if suelo != null:
		suelo.abrir_salidas()
	await get_tree().process_frame
	for e in get_tree().get_nodes_in_group("enemy"):
		(e as Node).queue_free()
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	var cam := jugador.get_node("Camera2D") as Camera2D
	cam.zoom = Vector2(2.4, 2.4)
	cam.position_smoothing_enabled = false
	var vistos: Array = []
	print("[escaleras] piso %d: %d escaleras, %d salidas" % [piso,
		get_tree().get_nodes_in_group("escalera").size(), get_tree().get_nodes_in_group("salida_pueblo").size()])
	for grupo in ["escalera", "salida_pueblo"]:
		for n in get_tree().get_nodes_in_group(grupo):
			var nd := n as Node2D
			# Sin mirar 'visible': la niebla esconde lo que aun no has visto (se enciende al acercarse).
			if nd == null or nd.global_position.x < -10000.0 or vistos.has(nd) or nd.is_queued_for_deletion():
				continue
			vistos.append(nd)
			var cual: String = "pueblo" if grupo == "salida_pueblo" else ("subir" if bool(nd.get("sube")) else "bajar")
			jugador.global_position = nd.global_position + Vector2(84, 34)
			for k in 20:
				await get_tree().process_frame
				# Los compañeros, fuera de cuadro: siguen al jugador y se plantan delante de la escalera.
				for c in get_tree().get_nodes_in_group("aliado"):
					if c != jugador:
						(c as Node2D).visible = false
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%sescalera_%s_p%d_%s.png" % [SALIDA, _prefijo, piso, cual])
			print("[escaleras] piso %d: %s en %s" % [piso, cual, nd.global_position])
	get_tree().paused = false
	mundo.queue_free()
	for k in 3:
		await get_tree().process_frame


func _buscar(n: Node, metodo: String) -> Node:
	if n.has_method(metodo):
		return n
	for h in n.get_children():
		var r: Node = _buscar(h, metodo)
		if r != null:
			return r
	return null
