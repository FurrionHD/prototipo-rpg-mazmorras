# AL HUIR, EL QUE HUYE PASA A IR EN CABEZA (12/10, lo pidio el jefe: "al huir que se convierta en lider
# automaticamente el que huye, para que se queden en la posicion desde la que sales"). Sin red, en la arena: se abre
# una pelea tactica, huye un COMPAÑERO (no el lider) y al cerrarse la pelea:
#   1) va en cabeza el que huyo;
#   2) el cuerpo que mueves esta donde estaba el (no donde estaba el lider de antes);
#   3) si huye el lider, sigue siendo el lider.
#   godot --headless --path . res://tools/prueba_huida_lider.tscn
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


func _pantalla() -> Node:
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					return h
	return null


# Abre una pelea contra un slime y hace huir a 'quien' (indice en Game.party). Devuelve donde estaba su cuerpo.
func _huir_con(quien: int) -> Vector2:
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime.tres", jug.global_position + Vector2(90, 0), {})
	await _esperar(25)
	var bichos: Array = get_tree().get_nodes_in_group("enemy")
	if bichos.is_empty() or not Game.start_combat([bichos[0]], false):
		print("MAL: no se abre la pelea")
		return Vector2.INF
	await _esperar(10)
	var combat: Node = _pantalla()
	combat.set_process(false)
	var pj: PersonajeData = Game.party[quien]
	var c: Combatant = Game.combatant_de_pj(pj)
	var cuerpo: Node2D = combat.turno_mapa.cuerpo_de(c) if combat.turno_mapa.has_method("cuerpo_de") else null
	var donde: Vector2 = cuerpo.global_position if cuerpo != null else Vector2.INF
	for e in combat._enemies:
		e.abilities.agilidad = 1   # que nadie le pille: aqui se mira lo de despues, no el dado
	combat._player = c
	var intentos := 0
	while combat._state != combat.State.FINISHED and intentos < 20:
		combat._state = combat.State.WAITING_PLAYER
		combat._accion_huir()
		intentos += 1
	combat._on_continue_pressed()
	await _esperar(10)
	return donde


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(5)
	Game.entrar_arena_de_pruebas()
	await _esperar(15)
	if Game.party.size() < 2:
		print("MAL: hace falta un grupo de dos o mas")
		get_tree().quit(1)
		return
	Game.cambiar_lider(0)
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	jug.refrescar_lider()
	await _esperar(3)

	print("1) huye un compañero")
	var donde: Vector2 = await _huir_con(1)
	_ver(Game.lider_idx == 1, "va en cabeza el que huyo (%s)" % Game.lider().nombre)
	print("2) desde su sitio")
	if donde != Vector2.INF:
		_ver(jug.global_position.distance_to(donde) < 24.0,
			"el cuerpo que mueves esta donde estaba el (%.0f px)" % jug.global_position.distance_to(donde))
	else:
		print("  (no encuentro su cuerpo en el mapa: me salto la posicion)")

	print("3) huye el lider")
	await _esperar(30)
	await _huir_con(1)
	_ver(Game.lider_idx == 1, "sigue en cabeza el mismo")

	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
