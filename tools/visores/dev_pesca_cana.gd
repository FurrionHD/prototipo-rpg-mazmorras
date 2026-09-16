# ============================================================
#  dev_pesca_cana.gd  --  HERRAMIENTA, no parte del juego.
#
#  LA CAÑA EN LA PESCA DE VERDAD: el pueblo con su jugador, un charco (fishing_spot.gd) en la orilla, y el
#  ciclo real: apuntar, lanzar, sedal en el aire y corcho en el agua. Tres apuntados (izquierda, centro,
#  derecha) para ver que el personaje se gira. Capturas tools/salida/pesca_cana_*.png y se cierra.
#  Con ventana:  godot --path . res://tools/visores/dev_pesca_cana.tscn
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
const PUEBLO := "res://scenes/levels/town.tscn"
const PartidaDePrueba = preload("res://tools/visores/partida_de_prueba.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(SALIDA)
	PartidaDePrueba.llenar()
	Game.equipped_cana = Game.herramienta_base(ToolData.Tipo.CANA)
	get_tree().current_scene.scene_file_path = PUEBLO
	var pueblo := (load(PUEBLO) as PackedScene).instantiate() as Node2D
	add_child(pueblo)
	var jugador := pueblo.get_node("Player") as Node2D
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Los compañeros fuera de cuadro.
	for n in get_tree().get_nodes_in_group("aliado"):
		if n != jugador:
			(n as Node2D).global_position = Vector2(-5000, -5000)

	var charco: Node2D = preload("res://scripts/world/fishing_spot.gd").new()
	charco.celda = Vector2i(10, 42)
	charco.tam_celdas = Vector2i(8, 4)
	charco.tabla = preload("res://resources/world/peces.tres")
	charco.position = Vector2(10 * 32 + 16, 42 * 32)
	pueblo.add_child(charco)
	jugador.global_position = Vector2(10 * 32 + 16, 39 * 32 + 8)
	var cam := jugador.get_node("Camera2D") as Camera2D
	cam.zoom = Vector2(3.5, 3.5)
	cam.position_smoothing_enabled = false
	await get_tree().process_frame

	for lado in [-0.5, 0.0, 0.5]:
		charco.empezar_apuntado()
		charco._ang = charco._ang_base + lado
		for k in 4:
			await get_tree().process_frame
		await _captura("apunta_%s" % str(lado))
		charco._fuerza = 0.6
		charco._lanzar()
		for k in 6:
			await get_tree().process_frame
		await _captura("vuelo_%s" % str(lado))
		await get_tree().create_timer(1.2).timeout
		await _captura("agua_%s" % str(lado))
		charco._soltar()
		await get_tree().process_frame
	await _captura("guardada")
	get_tree().quit()


func _captura(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%spesca_cana_%s.png" % [SALIDA, nombre])
