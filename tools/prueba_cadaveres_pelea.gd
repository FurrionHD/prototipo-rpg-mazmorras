# LOS CADAVERES DESAPARECEN EN LA PELEA (09/10, el 15 del playtest 08/10: "en combate a veces los cadaveres no
# desaparecen visualmente"). Un slime cae y un refuerzo estrena SU hueco en el mismo momento (como la cola): el cuerpo
# viejo tiene que desvanecerse igual, NO volver a verse aunque se le remate (Game lo mata al relevarlo, y en las demas
# maquinas llega su muerte por red) y reaparecer como cadaver al acabar la pelea. Sin ventana:
#   godot --headless --path . res://tools/prueba_cadaveres_pelea.tscn
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


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _alfa_tras(n: Node2D, ms: int) -> float:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await get_tree().process_frame
	return n.modulate.a if is_instance_valid(n) else -1.0


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
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime.tres", jug.global_position + Vector2(90, 0), {})
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime.tres", jug.global_position + Vector2(90, 40), {})
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime.tres", jug.global_position + Vector2(120, 20), {})
	await _esperar(25)
	var nodos: Array = get_tree().get_nodes_in_group("enemy")
	_ver(nodos.size() >= 3, "tres slimes (%d)" % nodos.size())
	var a: Node2D = nodos[0]
	var otro: Node2D = nodos[1]
	var refuerzo: Node2D = nodos[2]
	_ver(Game.start_combat([a, otro], false), "se abre la pelea contra dos")
	await _esperar(8)
	var combat: Node = null
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	combat.set_process(false)
	var ea: Combatant = combat._enemies[0]
	print("1) cae el primero y un refuerzo estrena su hueco en el acto")
	ea.current_hp = 0.0
	combat._morir_enemigo(ea)
	_ver(Game.unir_enemigo_al_combate(refuerzo, 0), "el refuerzo entra en su hueco")
	_ver(combat._enemies[0] != ea and combat._enemies[0].is_alive(), "el hueco 0 es ya del refuerzo")
	_ver(a.has_meta("muerto_en_pelea"), "el cuerpo viejo empieza a morirse en el mapa")
	var al1: float = await _alfa_tras(a, 2500)
	print("    alfa del cuerpo viejo a los 2,5 s: %.2f" % al1)
	_ver(al1 < 0.05, "y se desvanece (no se queda de pie)")
	print("2) su muerte llega otra vez (como por red): sigue oculto")
	a.morir()
	var al2: float = await _alfa_tras(a, 300)
	_ver(al2 < 0.05, "sigue oculto en plena pelea (alfa %.2f)" % al2)
	print("3) acaba la pelea: vuelve a verse para recogerlo")
	for e in combat._enemies:
		e.current_hp = 0.0
	combat._tras_accion_jugador_varios(combat._enemies.duplicate())
	await _esperar(20)
	if is_instance_valid(combat):
		combat._on_continue_pressed()
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000 and (Game.combate_activo() or Game.hay_pelea_en_pantalla()):
		await get_tree().process_frame
	await _esperar(5)
	_ver(not Game.combate_activo(), "la pelea se cierra")
	_ver(is_instance_valid(a) and a.esta_muerto() and a.modulate.a > 0.99 and not a.has_meta("muerto_en_pelea"),
		"el cadaver relevado vuelve a verse (alfa %.2f)" % (a.modulate.a if is_instance_valid(a) else -1.0))
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
