# EL GOLPE CUENTA EN EL PORRAZO (08/10, playtest: "cuando un enemigo me golpea fuera de combate tarda mucho en detectar
# que me ha golpeado; si me llega a hacer contacto no hace falta que termine la animacion"). Un slime embiste al jugador
# quieto: la pelea tiene que abrirse en el fotograma del contacto (CONTACTO_EMBESTIDA del gesto), no al acabarlo. Y si el
# jugador se aparta antes del porrazo, no entra.
#   godot --headless --path . res://tools/prueba_embestida_porrazo.tscn
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


func _montar() -> Array:
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")
	await _esperar(30)
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	var gen: DungeonGenerator = piso.gen
	for e in get_tree().get_nodes_in_group("enemy"):
		e.global_position = Vector2(-5000, -5000)
		e.set_physics_process(false)
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	for a in get_tree().get_nodes_in_group("aliado"):
		if a != jug:
			a.global_position = Vector2(-8000, -8000)
			a.set_physics_process(false)
	# Una celda de sala con sitio a la derecha.
	var sitio := Vector2i(-1, -1)
	for z in gen.zonas:
		if String(z["tipo"]) == "sala" and (z["rect"] as Rect2i).size.x >= 8:
			sitio = (z["rect"] as Rect2i).get_center()
			break
	var C: float = float(DungeonGenerator.CELDA)
	var pe: Vector2 = (Vector2(sitio) + Vector2(0.5, 0.5)) * C
	var data: EnemyData = load("res://scenes/actors/enemy/slime.tres")
	var en = piso.crear_enemigo(data, pe, 30.0, 0.5, 0, false)
	await _esperar(3)
	en.global_position = pe
	jug.set_physics_process(false)   # quieto: sin teclas en headless, y que no le empuje nada
	jug.global_position = pe + Vector2(40, 0)
	await get_tree().physics_frame
	return [en, jug]


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	Game.current_floor = 1

	print("1) se aparta antes del porrazo: no entra")
	var par: Array = await _montar()
	var en = par[0]
	var jug: Node2D = par[1]
	en._lanzar_embestida(jug)
	var dur: float = en._embiste_dur
	await get_tree().physics_frame
	jug.global_position += Vector2(400, 0)
	var t: float = 0.0
	while t < dur + 0.3 and not en._combat_triggered:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_ver(not en._combat_triggered, "apartarse a tiempo esquiva")


	print("2) quieto delante: la pelea en el porrazo")
	par = await _montar()
	en = par[0]
	jug = par[1]
	en._lanzar_embestida(jug)
	dur = en._embiste_dur
	t = 0.0
	while t < dur + 0.5 and not en._combat_triggered:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_ver(en._combat_triggered, "la embestida abre la pelea")
	print("     gesto %.2f s, pelea a los %.2f s (porrazo al %.0f %% = %.2f s)" % [dur, t,
			en.CONTACTO_EMBESTIDA * 100.0, dur * en.CONTACTO_EMBESTIDA])
	_ver(t <= dur * en.CONTACTO_EMBESTIDA + 0.05, "se abre en el porrazo, no al acabar el gesto")
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(0 if _mal == 0 else 1)
