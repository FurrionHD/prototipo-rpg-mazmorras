# LA LISTA DE ENEMIGOS DEL PANEL DERECHO (B6, playtest 11/10). Pelea en la arena contra el minotauro, una rata y un
# slime: debajo de la ficha del apuntado sale una fila por cada uno de los demas vivos, con su vida; pulsar una fila
# le apunta; y la lista no se mete debajo de la barra de acciones. Con ventana y LISTA_SALIDA=/ruta/base, captura.
#   godot --headless --path . res://tools/prueba_lista_enemigos.tscn
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
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime.tres", jug.global_position + Vector2(180, 90), {})
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
	var ficha = combat.ficha_objetivo
	var apuntado: Combatant = combat._objetivo()
	var otros: Array = combat._enemies.filter(func(e): return e.is_alive() and e != apuntado)
	print("     apuntado %s; en la lista: %s" % [apuntado.nombre, str(ficha._filas.map(func(f): return f["c"].nombre))])
	_ver(otros.size() >= 2, "hay al menos dos mas aparte del apuntado")
	_ver(ficha._filas.size() == otros.size() and ficha._lista_scroll.visible, "una fila por cada uno de los demas")
	var ok_hp: bool = true
	for f in ficha._filas:
		ok_hp = ok_hp and is_equal_approx((f["hp"] as ProgressBar).value, (f["c"] as Combatant).current_hp)
	_ver(ok_hp, "cada fila con su vida")
	var acciones: Control = combat._panel_acciones
	var fondo_lista: float = ficha._lista_scroll.global_position.y + ficha._lista_scroll.size.y
	print("     la lista acaba en %.0f; las acciones empiezan en %.0f" % [fondo_lista, acciones.global_position.y])
	_ver(not acciones.visible or fondo_lista <= acciones.global_position.y, "no se mete debajo de la barra de acciones")
	var salida: String = OS.get_environment("LISTA_SALIDA")
	if salida != "" and DisplayServer.get_name() != "headless":
		await _esperar(20)
		var img: Image = get_tree().root.get_viewport().get_texture().get_image()
		img.save_png(salida + ".png")
		print("     captura: %s.png" % salida)
	# Pulsar la primera fila = apuntarle.
	var otro: Combatant = ficha._filas[0]["c"] if not ficha._filas.is_empty() else null
	if otro != null:
		var clic := InputEventMouseButton.new()
		clic.button_index = MOUSE_BUTTON_LEFT
		clic.pressed = true
		(ficha._lista.get_child(0) as Control).gui_input.emit(clic)
		await _esperar(3)
		_ver(combat._objetivo() == otro, "pulsar su fila le apunta (%s)" % combat._objetivo().nombre)
		_ver(not ficha._filas.any(func(f): return f["c"] == otro) and ficha._filas.any(func(f): return f["c"] == apuntado),
			"y la lista pasa a tener al de antes en su lugar")
	print("FIN: TODO BIEN" if _mal == 0 else "FIN: %d MAL" % _mal)
	get_tree().quit(0 if _mal == 0 else 1)
