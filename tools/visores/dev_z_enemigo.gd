# ============================================================
#  dev_z_enemigo.gd  --  HERRAMIENTA, no parte del juego.
#
#  "Los enemigos se pintan dentro de la cara": un slime de verdad (enemy.tscn) pegado a un muñeco por
#  DETRAS y otro por DELANTE, con Game.z_frente_a_personajes. Saca tools/salida/z_enemigo.png y se cierra.
#  Con ventana:  godot --path . res://tools/visores/dev_z_enemigo.tscn
# ============================================================
extends Node2D

const SALIDA := "res://tools/salida/"
const PartidaDePrueba = preload("res://tools/visores/partida_de_prueba.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(SALIDA)
	PartidaDePrueba.llenar()
	RenderingServer.set_default_clear_color(Color(0.18, 0.18, 0.2))
	var cam := Camera2D.new()
	cam.zoom = Vector2(4, 4)
	cam.position = Vector2(80, 0)
	add_child(cam)
	cam.make_current()

	var ruta: String = ""
	for r in Game.rutas_enemigos():
		if String(r).get_file().begins_with("slime"):
			ruta = r
			break
	print("[z] enemigo: ", ruta)
	# Detras (el slime 16 px mas arriba) y delante (16 px mas abajo).
	for i in 2:
		var pos := Vector2(i * 110, 0)
		var dueno := Node2D.new()
		dueno.position = pos
		dueno.add_to_group("aliado")
		add_child(dueno)
		var m := MunecoJugador.new()
		dueno.add_child(m)
		m.z_as_relative = false
		m.z_index = Game.Z_PERSONAJES
		m.montar(Game.lider())
		m.tenir(Game.lider().color, Game.lider().metalico)
		m.fijar("idle_0", 0)
		var e: Node2D = (load("res://scenes/actors/enemy/enemy.tscn") as PackedScene).instantiate()
		e.data = load(ruta)
		add_child(e)
		e.global_position = pos + Vector2(0, -16 if i == 0 else 16)
		e.set("home_position", e.global_position)
	for k in 3:
		await get_tree().physics_frame
	for e in get_tree().get_nodes_in_group("enemy"):
		print("[z] enemigo en %s -> z %d" % [(e as Node2D).global_position, (e as Node2D).z_index])
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SALIDA + "z_enemigo.png")
	get_tree().quit()
