# QUIEN ENTRA EN UNA PELEA YA EMPEZADA DESDE FUERA DE LA ZONA (05/10, playtest: "mate unos enemigos y ese salio de la
# nada; esta fuera del area y bastante lejos"). Monta una pelea tactica en una sala de un piso de verdad, provoca
# BROTES de pared y deja enemigos persiguiendote desde lejos, y mira que todos los de la pelea esten en la zona.
#   godot --headless --path . res://tools/prueba_entra_de_fuera.tscn
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


func _segundos(s: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < s * 1000.0:
		await get_tree().process_frame


func _revisar(arena: ArenaCombate, que: String) -> void:
	for n in Game._active_enemies:
		if n == null or not is_instance_valid(n):
			continue
		var p: Vector2 = (n as Node2D).global_position
		var dentro: bool = arena.contiene(p)
		var d: float = arena.distancia_al_borde(p)
		print("    %s en %s celda %s: %s (al borde %.0f px)" % [n.name, p, ArenaCalculo.celda_de_px(p),
			"DENTRO" if dentro else "FUERA", d])
		_ver(dentro or d > -40.0, "%s: %s esta en la zona" % [que, n.name])


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	Game.current_floor = 1
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")
	await _esperar(30)
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	var gen: DungeonGenerator = piso.gen
	var sala := Rect2i()
	for z in gen.zonas:
		if String(z["tipo"]) == "sala" and (z["rect"] as Rect2i).get_area() > sala.get_area():
			sala = z["rect"]
	var centro: Vector2 = gen.centro_px(sala.position + sala.size / 2)
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var enemigos: Array = get_tree().get_nodes_in_group("enemy")
	var e: Node2D = enemigos[0]
	jug.global_position = centro
	e.global_position = centro + Vector2(40, 0)
	await _esperar(3)
	e._start_combat(true)
	await _esperar(15)
	var combat: Node = null
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	if combat == null or not combat.tactico:
		print("MAL: no hay pelea tactica")
		get_tree().quit(1)
		return
	var arena: ArenaCombate = combat.turno_mapa._arena()
	print("pelea en la sala %s, arena %s; arbol en pausa: %s" % [sala, arena.rect_celdas, get_tree().paused])
	_revisar(arena, "al empezar")
	print("1) brotes de pared en plena pelea")
	for i in 4:
		Game._alboroto_enfriando = 0.0
		Game.alboroto = Game.ALBOROTO_MAX
		Game.sumar_alboroto(1.0)
		await _segundos(2.5)
		_revisar(arena, "brote %d" % (i + 1))
	print("2) los que quedan por el piso, persiguiendote desde lejos")
	for n in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(n) and not Game.esta_en_combate(n) and not n.esta_muerto():
			n._objetivo = jug
			n._state = n.State.CHASE
	await _segundos(6.0)
	_revisar(arena, "persecucion")
	print("3) uno LEJOS de la zona intenta unirse (lo que pasa en multi, con el mapa sin pausa)")
	var lejos: Node2D = null
	for n in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(n) and not Game.esta_en_combate(n) and not n.esta_muerto() 				and arena.distancia_al_borde((n as Node2D).global_position) < -100.0:
			lejos = n
			break
	_ver(lejos != null, "hay un enemigo lejos de la zona")
	if lejos != null:
		_ver(not Game.unir_enemigo_al_combate(lejos), "el de lejos NO entra (%.0f px fuera)" % -arena.distancia_al_borde(lejos.global_position))
		var borde: Vector2 = ArenaCalculo.centro_px(arena.rect_celdas)
		lejos.global_position = borde
		_ver(Game.unir_enemigo_al_combate(lejos), "el mismo, ya dentro de la zona, SI entra")
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
