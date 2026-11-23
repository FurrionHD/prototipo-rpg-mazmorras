# HERRAMIENTA. No forma parte del juego. CON VENTANA:
#
#   godot --path . res://tools/capturas_torre_pueblo.tscn
#
# LA TORRE DEL MAGO EN EL PUEBLO (22/11): el jugador delante de su puerta y la captura de la camara del juego, de dia y
# de noche. Escritorio, carpeta arboles.
extends Node

const CARPETA := "C:/Users/dasui/Desktop/arboles"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA)
	var town: Node = load("res://scenes/levels/town.tscn").instantiate()
	add_child(town)
	for i in 20:
		await get_tree().process_frame
	var torre: Dictionary = {}
	for c in PuebloPlano.CASAS:
		if String(c["clave"]) == "mago":
			torre = c
	var puerta: Vector2i = PuebloPlano.puerta_de(torre)
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	# Un poco a la derecha y abajo de la puerta: que se vean la torre y el maestro de al lado.
	jug.recolocar(Vector2(puerta) * PuebloPlano.CELDA + Vector2(PuebloPlano.CELDA * 0.5 + 40, PuebloPlano.CELDA * 0.5))
	var cam: Camera2D = jug.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.offset = Vector2(-60, -170)   # la camara arriba: la torre entera y el maestro al lado
	await _esperar(30)
	get_viewport().get_texture().get_image().save_png("%s/5_torre_en_el_pueblo.png" % CARPETA)
	print("[capturas] en ", CARPETA)
	get_tree().quit()


func _esperar(n: int) -> void:
	for k in n:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
