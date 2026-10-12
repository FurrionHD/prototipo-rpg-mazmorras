# LOS ALCANCES DE TODOS EN EL SUELO (B4, playtest 11/10). Abre una pelea en la arena contra el minotauro y una rata y
# mira que la arena lleve un anillo por cada uno que se ve, a sus pies, con el radio que mira llega() y marcado el del
# turno y el apuntado. Sin ventana solo comprueba; con ventana y ALCANCES_SALIDA=/ruta/base saca una captura.
#   godot --headless --path . res://tools/prueba_alcances.tscn
#   ALCANCES_SALIDA=C:/tmp/alcances godot --path . res://tools/prueba_alcances.tscn
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


func _esperar_a(cond: Callable, tope_s: float) -> bool:
	var t0: int = Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > tope_s * 1000.0:
			return false
		await get_tree().process_frame
	return true


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


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
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/guardian_rango.tres", jug.global_position + Vector2(-220, 70), {})
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/rata.tres", jug.global_position + Vector2(200, -40), {})
	await _esperar(25)
	if not Game.start_combat(get_tree().get_nodes_in_group("enemy"), false):
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	var combat: Node = null
	await _esperar(5)
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	if combat == null or not combat.tactico:
		print("MAL: la pelea no es tactica")
		get_tree().quit(1)
		return
	var t = combat.turno_mapa
	if not await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 20.0):
		print("MAL: no llego un turno de los tuyos")
		get_tree().quit(1)
		return
	await _esperar(3)
	var arena: ArenaCombate = t._arena()
	_ver(arena != null, "hay arena")
	if arena == null:
		get_tree().quit(1)
		return
	var vivos: Array = (combat._aliados + combat._enemies).filter(func(c): return c.is_alive() and t.cuerpo_de(c) != null \
		and t.cuerpo_de(c).is_visible_in_tree())
	print("     %d anillos para %d que se ven" % [arena.alcances.size(), vivos.size()])
	_ver(arena.alcances.size() == vivos.size() and vivos.size() >= 3, "un anillo por cada uno")
	var objetivo: Combatant = combat._objetivo()
	for c in vivos:
		var al: Array = []
		for a in arena.alcances:
			if Vector2(a[0]).distance_to(t.pies_de(c)) < 0.5:
				al = a
		var r_ok: float = t.alcance_de(c) + t._resta_al_hueco(c)
		_ver(not al.is_empty() and absf(float(al[1]) - r_ok) < 0.01 and bool(al[2]) == combat._enemies.has(c),
			"%s: a sus pies, radio %.0f, bando %s" % [c.nombre, r_ok, "enemigo" if combat._enemies.has(c) else "tuyo"])
		if not al.is_empty():
			_ver(bool(al[3]) == (c == t._quien or c == objetivo), "%s: %s" % [c.nombre, "marcado" if bool(al[3]) else "suave"])
	var salida: String = OS.get_environment("ALCANCES_SALIDA")
	if salida != "" and DisplayServer.get_name() != "headless":
		await _esperar(20)
		var img: Image = get_tree().root.get_viewport().get_texture().get_image()
		img.save_png(salida + ".png")
		print("     captura: %s.png" % salida)
	print("FIN: TODO BIEN" if _mal == 0 else "FIN: %d MAL" % _mal)
	get_tree().quit(0 if _mal == 0 else 1)
