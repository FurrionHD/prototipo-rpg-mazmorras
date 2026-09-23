# PRUEBA: LO QUE ESTA DENTRO DE LA ARENA, PELEA (combate tactico, en la arena de verdad, sin ventana).
# Un enemigo abre la pelea; otro esta DENTRO del rectangulo pero lejos de el (fuera de sus vecinos), asi
# que el arranque no lo mete. Tiene que entrar solo como refuerzo, con su ficha mudada sobre su cuerpo.
#   godot --headless --path . res://tools/prueba_arena_recoge.tscn
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
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(5)
	Game.entrar_arena_de_pruebas()
	await _esperar(15)
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime.tres", jug.global_position + Vector2(60, 0), {})
	await _esperar(3)
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/rata.tres", jug.global_position + Vector2(-150, 40), {})
	await _esperar(20)
	var todos: Array = get_tree().get_nodes_in_group("enemy")
	var cerca: Node2D = null
	var lejos: Node2D = null
	for e in todos:
		if (e as Node2D).global_position.x > jug.global_position.x:
			cerca = e
		else:
			lejos = e
	if cerca == null or lejos == null:
		print("MAL: no estan los dos enemigos")
		get_tree().quit(1)
		return
	print("vecinos de quien abre: %d" % cerca.vecinos().size())
	_afirmar(not cerca.vecinos().has(lejos), "el de lejos NO es vecino del que abre (el caso de la captura)")
	# La pelea la abre el de cerca, como si le hubiera alcanzado: el y SUS vecinos.
	cerca._start_combat(true)
	await _esperar(10)
	var combat: Node = null
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	if combat == null or not combat.tactico:
		print("MAL: la pelea no es tactica")
		get_tree().quit(1)
		return
	var arena: ArenaCombate = combat.turno_mapa._arena()
	print("arena %s | el de lejos en %s" % [str(arena.rect), str(lejos.global_position)])
	_afirmar(arena.contiene(lejos.global_position), "el de lejos esta DENTRO de la arena")
	var t0: int = Time.get_ticks_msec()
	while not Game.esta_en_combate(lejos) and Time.get_ticks_msec() - t0 < 3000:
		await get_tree().process_frame
	_afirmar(Game.esta_en_combate(lejos), "el de dentro de la arena entra a la pelea")
	_afirmar(combat._enemies.size() == 2, "la pelea tiene a los dos (%d)" % combat._enemies.size())
	await _esperar(3)
	var fichas: int = combat.figuras_mapa._fichas.size()
	_afirmar(fichas == combat._bloques.size(), "su ficha se ha mudado sobre su cuerpo (%d de %d)" % [fichas, combat._bloques.size()])
	_afirmar(combat.turno_mapa._preparados.has(combat._enemies[combat._enemies.size() - 1]),
		"su cuerpo esta preparado para la pelea")
	print("[arena-recoge] RESULTADO: %s (%d fallos)" % ["TODO BIEN" if _fallos == 0 else "HAY FALLOS", _fallos])
	get_tree().quit(1 if _fallos > 0 else 0)
