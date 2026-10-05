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
			# La zona de la pelea de verdad (el que pegas y sus refuerzos, que ya no cruzan muros): en su sala y no en la otra.
			var forma: Dictionary = Game._forma_de_arena(v)
			var r: Rect2i = forma["rect"]
			_ver(ArenaCalculo.en_forma(r, forma["mascara"], par[0]), "la zona cubre al que pegas (rect %s)" % r)
			_ver(not ArenaCalculo.en_forma(r, forma["mascara"], par[1]), "la zona NO se va a la otra sala")
			hecho = true
			break
		if hecho:
			break
	_ver(hecho, "encontre dos salas pegadas para probar")

	# LA CAPTURA DEL PLAYTEST: el enemigo en la BOCA de una sala y el grupo en FILA por el pasillo. La zona tenia que
	# ser la sala Y el trozo de pasillo con los tuyos; era solo la sala y se quedaban fuera (sin andar y con Huir).
	print("boca de sala con el grupo en el pasillo")
	var piso2: Node = get_tree().get_first_node_in_group("dungeon_floor")
	var gen2: DungeonGenerator = piso2.gen
	var boca: Array = []
	for y in gen2.alto:
		if not boca.is_empty():
			break
		for x in gen2.ancho:
			var c := Vector2i(x, y)
			if _sala(gen2, c) < 0:
				continue
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var ok: bool = true
				for k in range(1, 6):
					var v: Vector2i = c + d * k
					if not gen2.es_suelo(v) or _sala(gen2, v) >= 0:
						ok = false
						break
				if ok:
					boca = [c, d]
					break
			if not boca.is_empty():
				break
	_ver(not boca.is_empty(), "encontre una boca de sala con pasillo")
	if not boca.is_empty():
		var C2: float = float(DungeonGenerator.CELDA)
		var cel: Vector2i = boca[0]
		var dd: Vector2i = boca[1]
		for e in get_tree().get_nodes_in_group("enemy"):
			e.global_position = Vector2(-5000, -5000)
			e.set_physics_process(false)
		var data2: EnemyData = load("res://scenes/actors/enemy/slime_veneno.tres")
		var pe: Vector2 = (Vector2(cel) + Vector2(0.5, 0.5)) * C2
		var en = piso2.crear_enemigo(data2, pe, 30.0, 0.5, 0, false)
		await _esperar(2)
		en.global_position = pe
		en.set_physics_process(false)
		var aliados: Array = get_tree().get_nodes_in_group("aliado")
		var celdas_grupo: Array = []
		for i in aliados.size():
			var cg: Vector2i = cel + dd * (1 + i)
			(aliados[i] as Node2D).global_position = (Vector2(cg) + Vector2(0.5, 0.5)) * C2
			celdas_grupo.append(cg)
		await _esperar(1)
		var f3: Dictionary = Game._forma_de_arena([en])
		var r3: Rect2i = f3["rect"]
		_ver(ArenaCalculo.en_forma(r3, f3["mascara"], cel), "la zona coge al enemigo (rect %s)" % r3)
		for i in celdas_grupo.size():
			_ver(ArenaCalculo.en_forma(r3, f3["mascara"], celdas_grupo[i]), "y al %do del grupo, en el pasillo %s" % [i + 1, celdas_grupo[i]])
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
