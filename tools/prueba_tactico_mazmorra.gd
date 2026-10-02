# PRUEBA: EL COMBATE TACTICO EN LA MAZMORRA (03/10/2026). Piso 1 de verdad, sin ventana: se lleva al
# jugador a un PASILLO, se le pone un enemigo al lado y se abre la pelea. Tiene que salir tactica, con la
# arena RELLENA (la forma del sitio, la misma superficie que en la arena de pruebas) y con todos dentro.
# Luego lo mismo en medio de una SALA.
#   godot --headless --path . res://tools/prueba_tactico_mazmorra.tscn
extends Node

var _fallos: int = 0


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _afirmar(ok: bool, que: String) -> void:
	_fallos += 0 if ok else 1
	print("[PASA] " if ok else "[FALLA] ", que)


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	Game.current_floor = 1
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")
	await _esperar(30)
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	if piso == null or piso.get("gen") == null:
		print("MAL: no hay piso")
		get_tree().quit(1)
		return
	var gen: DungeonGenerator = piso.gen
	# UN PASILLO: la celda de pasillo con mas pasillo alrededor (lejos de las bocas de las salas).
	var mejor := Vector2i(-1, -1)
	var mejor_n: int = -1
	for y in gen.alto:
		for x in gen.ancho:
			var c := Vector2i(x, y)
			var z: int = gen.zona_en(c)
			if not gen.es_suelo(c) or z < 0 or String(gen.zonas[z]["tipo"]) == "sala":
				continue
			var n: int = 0
			for dy in range(-6, 7):
				for dx in range(-6, 7):
					var v := c + Vector2i(dx, dy)
					var zv: int = gen.zona_en(v)
					if gen.es_suelo(v) and zv >= 0 and String(gen.zonas[zv]["tipo"]) != "sala":
						n += 1
			if n > mejor_n:
				mejor_n = n
				mejor = c
	_afirmar(mejor.x >= 0, "hay un pasillo en el piso (%s)" % str(mejor))
	await _pelea_en(gen, gen.centro_px(mejor), true, "PASILLO")
	# Y UNA SALA: la mas grande, en su centro.
	var sala := Rect2i()
	for z in gen.zonas:
		if String(z["tipo"]) == "sala" and (z["rect"] as Rect2i).get_area() > sala.get_area():
			sala = z["rect"]
	await _pelea_en(gen, gen.centro_px(sala.position + sala.size / 2), false, "SALA %s" % str(sala.size))
	print("[tactico-mazmorra] RESULTADO: %s (%d fallos)" % ["TODO BIEN" if _fallos == 0 else "HAY FALLOS", _fallos])
	get_tree().quit(1 if _fallos > 0 else 0)


func _pelea_en(gen: DungeonGenerator, px: Vector2, pasillo: bool, que: String) -> void:
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var enemigos: Array = get_tree().get_nodes_in_group("enemy")
	if jug == null or enemigos.is_empty():
		_afirmar(false, "%s: hay jugador y enemigos" % que)
		return
	# Que no se cuele nadie mas: los demas, lejos.
	var e: Node2D = enemigos[0]
	for otro in enemigos:
		if otro != e and is_instance_valid(otro):
			(otro as Node2D).global_position = Vector2(-99999, -99999)
	jug.global_position = px
	# El enemigo al lado, por donde haya suelo.
	var sitio: Vector2 = px
	for d in [Vector2(40, 0), Vector2(-40, 0), Vector2(0, 40), Vector2(0, -40)]:
		if gen.es_suelo(ArenaCalculo.celda_de_px(px + d)):
			sitio = px + d
			break
	e.global_position = sitio
	await _esperar(3)
	e._start_combat(true)
	await _esperar(10)
	var combat: Node = null
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	_afirmar(combat != null and combat.tactico, "%s: la pelea se abre en TACTICO" % que)
	if combat == null or not combat.tactico:
		return
	var arena: ArenaCombate = combat.turno_mapa._arena()
	_afirmar(arena != null, "%s: hay arena montada" % que)
	if arena == null:
		return
	var n_celdas: int = 0
	for y in range(arena.rect_celdas.position.y, arena.rect_celdas.end.y):
		for x in range(arena.rect_celdas.position.x, arena.rect_celdas.end.x):
			if ArenaCalculo.en_forma(arena.rect_celdas, arena.mascara, Vector2i(x, y)):
				n_celdas += 1
	print("%s: arena %s, %d celdas, mascara %s, %d tramos de borde" % [que, str(arena.rect_celdas), n_celdas,
		"SI" if not arena.mascara.is_empty() else "no (rectangulo)", arena.tramos.size()])
	if pasillo:
		_afirmar(not arena.mascara.is_empty(), "%s: la arena coge la forma del pasillo (relleno)" % que)
	_afirmar(arena.contiene(jug.global_position), "%s: el jugador esta dentro" % que)
	_afirmar(arena.contiene(e.global_position), "%s: el enemigo esta dentro" % que)
	_afirmar(combat.arena_mascara == arena.mascara, "%s: la forma que viaja al espejo es la montada" % que)
	var roster: Dictionary = combat.roster_para_espejo()
	_afirmar(roster.has("arena") and (arena.mascara.is_empty() or roster.has("arena_m")),
		"%s: el roster lleva la arena%s" % [que, " y su forma" if not arena.mascara.is_empty() else ""])
	# Cerrar la pelea a la fuerza: ganada, y Continuar.
	for c in combat._enemies:
		c.current_hp = 0.0
	combat._player_won = true
	combat._state = combat.State.FINISHED
	combat._on_continue_pressed()
	await _esperar(20)
	_afirmar(not is_instance_valid(Game.get("_arena_nodo")), "%s: al acabar la arena se quita" % que)
