# HERRAMIENTA. No forma parte del juego. CON VENTANA (es dibujo).
#
#   RUEDA_SALIDA=/ruta/rueda godot --path . res://tools/prueba_rueda_cristales.tscn
#
# LA RUEDITA DE SOLTAR CRISTALES (tecla G, playtest 08/10). Mira que
#   - agrupa los cristales de la bolsa por categoria y calidad,
#   - un clic suelta UNO delante de quien suelta (a donde mira), mayus+clic cinco,
#   - el nombre de lo que hay en el suelo es el del cristal (antes "Resource(...)::nombre"),
#   - se cierra sola al quedarte sin cristales.
# Y saca una captura de la ruedita abierta.
extends Node2D

var _mal := 0


func _ok(cond: bool, que: String) -> void:
	if cond:
		print("  ok   ", que)
	else:
		_mal += 1
		print("  MAL: ", que)


func _cristal(cat: int, cal: int) -> Cristal:
	var c := Cristal.new()
	c.categoria = cat
	c.calidad = cal
	return c


func _ready() -> void:
	call_deferred("_correr")


func _correr() -> void:
	var yo := CharacterBody2D.new()
	yo.add_to_group("player")
	yo.position = Vector2(400, 300)
	add_child(yo)
	Game.cristales.vaciar()
	for i in 7:
		Game.cristales.anadir(_cristal(1, Cristal.Calidad.NORMAL))
	Game.cristales.anadir(_cristal(1, Cristal.Calidad.INTACTO))
	Game.cristales.anadir(_cristal(2, Cristal.Calidad.NORMAL))
	Game.cristales.anadir(_cristal(3, Cristal.Calidad.DANADO))
	var r = load("res://scripts/ui/rueda_cristales.gd").new()
	add_child(r)
	await get_tree().process_frame
	r.alternar()
	_ok(r.abierta(), "se abre con cristales en la bolsa")
	_ok(r._grupos.size() == 4, "4 grupos (cat1 intacto, cat1 normal, cat2, cat3): %d" % r._grupos.size())
	_ok(r._grupos[0]["n"] == 1 and r._grupos[1]["n"] == 7, "orden por categoria y calidad, y cuantos")
	r._sel = 1
	r._root.queue_redraw()
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var salida: String = OS.get_environment("RUEDA_SALIDA")
	get_viewport().get_texture().get_image().save_png((salida if salida != "" else "user://rueda") + ".png")
	r._soltar(1, 1)
	_ok(Game.cristales.total() == 9, "un clic suelta uno")
	var suelo: Array = get_tree().get_nodes_in_group("pickup")
	_ok(suelo.size() == 1, "hay uno en el suelo")
	if suelo.size() == 1:
		var p: Node2D = suelo[0]
		_ok(p.global_position.y > yo.global_position.y + 20.0, "cae DELANTE (mira abajo): %s" % p.global_position)
		var txt: String = load("res://scripts/actors/player/player.gd").texto_interaccion(p)
		_ok(txt == "Recoger Cristal Cat 1 (Normal)", "el cartel dice: '%s'" % txt)
	r._soltar(r._grupos.find_custom(func(g): return g["n"] == 6), 5)
	_ok(Game.cristales.total() == 4, "mayus+clic suelta cinco")
	while r.abierta():
		r._soltar(0, 5)
	_ok(Game.cristales.esta_vacio() and not Game.hay_modal(), "sin cristales se cierra y suelta el menu")
	print("")
	print("FIN: TODO BIEN" if _mal == 0 else "FIN: %d MAL" % _mal)
	get_tree().quit(1 if _mal > 0 else 0)
