# PRUEBA: LO QUE ESTA DENTRO DE LA ARENA, PELEA (combate tactico, en la arena de verdad, sin ventana).
# Un enemigo abre la pelea; otro esta DENTRO del rectangulo pero lejos de el (fuera de sus vecinos), asi
# que el arranque no lo mete. Tiene que entrar solo como refuerzo, con su ficha mudada sobre su cuerpo.
#   godot --headless --path . res://tools/prueba_arena_recoge.tscn
extends Node

var sala = null   # su sala: tools/prueba_sala_propia.gd

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
	# EN SU SALA (etapa 4, 26/10): la prueba es la sala y la pelea se abre por donde la abre ella.
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_arena_recoge", Game.PISO_ARENA):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	sala.poner("res://scenes/actors/enemy/slime.tres", Vector2(60, 0), {})
	await _esperar(3)
	sala.poner("res://scenes/actors/enemy/rata.tres", Vector2(-150, 40), {})
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
	# (08/10) LA ZONA ES DE 11x9 (352x288 px, centrada en quien abre): el de lejos tiene que caber DENTRO y quedar FUERA del
	# radio de refuerzo (160). Se colocan a mano y quietos hasta que empieza: andando por su cuenta se acercaban.
	cerca.set_physics_process(false)
	lejos.set_physics_process(false)
	cerca.global_position = jug.global_position + Vector2(60, 0)
	lejos.global_position = cerca.global_position + Vector2(-165, -45)
	await get_tree().physics_frame
	print("vecinos de quien abre: %d" % cerca.vecinos().size())
	_afirmar(not cerca.vecinos().has(lejos), "el de lejos NO es vecino del que abre (el caso de la captura)")
	# La pelea la abre el de cerca, como si le hubiera alcanzado: el y SUS vecinos.
	cerca.set_physics_process(true)
	lejos.set_physics_process(true)
	await sala.pelear_con_vecinos(cerca, true)   # como cerca._start_combat(true), por donde lo hace la sala
	await _esperar(10)
	var combat: Node = null
	for n in get_tree().root.get_children() + sala.capas():
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
	# (12/10) SIN TOPE EN EL MAPA: seis mas DENTRO de la zona (ocho en total, el tope de antes era cinco). Entran todos;
	# ninguno se queda en la cola de pie dentro de la arena sin poder recibir golpes.
	var dentro: Array = []
	var c0: Vector2 = Vector2(arena.rect.get_center())
	for i in 6:
		var p: Vector2 = c0 + Vector2(-70 + 28 * i, 50 if i % 2 == 0 else -50)
		if arena.contiene(p):
			dentro.append(p)
			sala.poner_en("res://scenes/actors/enemy/slime.tres", p, {})
	var t1: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 4000:
		await get_tree().process_frame
	var en_zona: int = 0
	var fuera_de_pelea: int = 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if arena.contiene((e as Node2D).global_position):
			en_zona += 1
			if not Game.esta_en_combate(e):
				fuera_de_pelea += 1
	_afirmar(dentro.size() == 6, "los seis nuevos caen dentro de la zona (%d)" % dentro.size())
	_afirmar(combat._enemies.size() >= 8, "la pelea tiene mas de cinco: %d" % combat._enemies.size())
	_afirmar(Game._cola_combate.is_empty(), "nadie se queda en la cola (%d)" % Game._cola_combate.size())
	_afirmar(fuera_de_pelea == 0, "todo lo que esta dentro de la zona pelea (%d de %d fuera)" % [fuera_de_pelea, en_zona])
	print("[arena-recoge] RESULTADO: %s (%d fallos)" % ["TODO BIEN" if _fallos == 0 else "HAY FALLOS", _fallos])
	get_tree().quit(1 if _fallos > 0 else 0)
