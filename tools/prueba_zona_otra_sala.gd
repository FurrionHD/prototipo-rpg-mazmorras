# EL BUG DE LA ZONA EN LA SALA DE AL LADO (05/10, playtest: "pego a un enemigo que esta arriba y se me abre en la sala de
# abajo, y mis personajes se teletransportan"). Busca dos SALAS separadas por un muro fino, pone un enemigo a cada lado
# (a menos de RADIO_REFUERZO) y al jugador pegado al de una: la pelea tiene que abrirse en SU sala y sin el de la otra.
#   godot --headless --path . res://tools/prueba_zona_otra_sala.tscn
extends Node

var _mal: int = 0


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _sala(gen: DungeonGenerator, c: Vector2i) -> int:
	var z: int = gen.zona_en(c)
	if z < 0 or String(gen.zonas[z]["tipo"]) != "sala":
		return -1
	return z


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	var hecho: bool = false
	for semilla in [424242, 1234, 98765, 55555, 777]:
		Game.semilla_mundo = semilla
		for piso_n in [1, 2, 3, 4]:
			Game.current_floor = piso_n
			get_tree().change_scene_to_file("res://scenes/levels/main.tscn")
			await _esperar(30)
			var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
			if piso == null or piso.get("gen") == null:
				continue
			var gen: DungeonGenerator = piso.gen
			# Dos celdas de SALAS distintas, en vertical, con roca entre medias y a menos de 4 celdas.
			var par: Array = []
			for y in gen.alto:
				if not par.is_empty():
					break
				for x in gen.ancho:
					var a := Vector2i(x, y)
					var za: int = _sala(gen, a)
					if za < 0:
						continue
					for k in range(2, 5):
						var b := a + Vector2i(0, k)
						var zb: int = _sala(gen, b)
						if zb >= 0 and zb != za and not gen.es_suelo(a + Vector2i(0, 1)):
							par = [a, b]
							break
					if not par.is_empty():
						break
			if par.is_empty():
				continue
			print("semilla %d piso %d: salas en %s y %s" % [semilla, piso_n, par[0], par[1]])
			var C: float = float(DungeonGenerator.CELDA)
			var pa: Vector2 = (Vector2(par[0]) + Vector2(0.5, 0.5)) * C
			var pb: Vector2 = (Vector2(par[1]) + Vector2(0.5, 0.5)) * C
			for e in get_tree().get_nodes_in_group("enemy"):
				e.global_position = Vector2(-5000, -5000)   # que no estorben
				e.set_physics_process(false)
			var data: EnemyData = load("res://scenes/actors/enemy/slime.tres")
			var ea = piso.crear_enemigo(data, pa, 30.0, 0.5, 0, false)
			var eb = piso.crear_enemigo(data, pb, 30.0, 0.5, 0, false)
			await _esperar(3)
			ea.global_position = pa
			eb.global_position = pb
			ea.set_physics_process(false)
			eb.set_physics_process(false)
			var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
			jug.global_position = pa + Vector2(C * 0.5, 0)
			_ver(ea.global_position.distance_to(eb.global_position) <= ea.RADIO_REFUERZO, "estan a menos del radio de refuerzo (%.0f px)" % ea.global_position.distance_to(eb.global_position))
			var v: Array = ea.vecinos()
			_ver(not v.has(eb), "el de la otra sala NO entra de refuerzo")
			# Aunque entrara (por lo que sea), la zona se queda en la sala del que pegas.
			# Y aunque entraran DOS de la otra sala (el punto medio caeria en la suya), la zona sigue donde pegas.
			var eb2 = piso.crear_enemigo(data, pb + Vector2(C, 0), 30.0, 0.5, 0, false)
			await _esperar(2)
			eb2.global_position = pb + Vector2(C, 0)
			eb2.set_physics_process(false)
			var forma: Dictionary = Game._forma_de_arena([ea, eb, eb2])
			var r: Rect2i = forma["rect"]
			_ver(ArenaCalculo.en_forma(r, forma["mascara"], par[0]), "la zona cubre al que pegas (rect %s)" % r)
			_ver(not ArenaCalculo.en_forma(r, forma["mascara"], par[1]), "la zona NO se va a la otra sala")
			var forma2: Dictionary = Game._forma_de_arena(v)
			_ver((forma2["rect"] as Rect2i).has_point(par[0]), "con sus refuerzos de verdad, tambien en su sala")
			hecho = true
			break
		if hecho:
			break
	_ver(hecho, "encontre dos salas pegadas para probar")
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
