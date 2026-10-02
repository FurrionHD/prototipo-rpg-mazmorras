# PRUEBA: CARGAR NO ACABA EL TURNO (03/10). Con arco y flechas en la bolsa, en la arena y sin ventana:
#   - cargar deja el turno abierto (mismo personaje, esperando su accion) y carga 10;
#   - despues: ni magia, ni objetos, ni habilidades (Cargar ya hecha); el circulo de andar NO se reinicia;
#   - al pasar el turno acaba y el siguiente vuelve a tener todo.
#   godot --headless --path . res://tools/prueba_cargar_turno.tscn
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
	if not ok:
		_fallos += 1
		print("[FALLA] ", que)
	else:
		print("[PASA] ", que)


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


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	Game.equipar_arma(load("res://resources/weapons/arco.tres") as WeaponData)
	var flecha: MaterialData = load("res://resources/materials/flecha_acero.tres")
	for _i in 20:
		Game.materiales.append(MaterialItem.crear(flecha))
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(5)
	Game.entrar_arena_de_pruebas()
	await _esperar(15)
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime.tres", jug.global_position + Vector2(120, 0), {})
	await _esperar(20)
	if not Game.start_combat(get_tree().get_nodes_in_group("enemy"), false):
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	await _esperar(5)
	var combat: Node = null
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	var t = combat.turno_mapa
	if not await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 20.0):
		print("MAL: no llego un turno para andar")
		get_tree().quit(1)
		return
	var quien: Combatant = combat._player
	var inicio: Vector2 = t._inicio
	_afirmar(combat._accion_disponible(combat.Action.HABILIDAD) and combat._accion_disponible(combat.Action.OBJETO),
		"antes de cargar: Habilidades y Objetos abiertos")
	var md: MunicionData = flecha as MunicionData
	combat.habilidades._cargar(Game.HAB_CARGAR, md)
	await _esperar(3)
	print("cargadas: %d | estado %d | quien %s" % [quien.municion_quedan(), combat._state, combat._player.nombre])
	_afirmar(quien.municion_quedan() == Game.HAB_CARGAR.cargar_municion, "carga %d" % Game.HAB_CARGAR.cargar_municion)
	_afirmar(combat._state == combat.State.WAITING_PLAYER and combat._player == quien, "el turno sigue abierto")
	_afirmar(combat._actions_box.visible, "vuelve la barra de acciones")
	_afirmar(not combat._accion_disponible(combat.Action.MAGIC) and not combat._accion_disponible(combat.Action.OBJETO),
		"tras cargar: ni magia ni objetos")
	_afirmar(not combat._accion_disponible(combat.Action.HABILIDAD), "tras cargar: Habilidades cerrado (no queda otra preparacion)")
	_afirmar(combat._accion_disponible(combat.Action.FLEE), "tras cargar: Pasar sigue")
	_afirmar(t._fase == t.Fase.MOVIENDO and t._inicio == inicio, "el circulo de andar no se reinicia")
	combat._on_action(combat.Action.FLEE)
	_afirmar(await _esperar_a(func() -> bool: return combat._player != quien or combat._state != combat.State.WAITING_PLAYER, 10.0),
		"al pasar, el turno acaba")
	var llega: bool = await _esperar_a(func() -> bool: return combat._state == combat.State.WAITING_PLAYER, 30.0)
	print("turno siguiente: estado %d jugador %s | llega %s | preps %s | hab %s | %s" % [combat._state, combat._player.nombre if combat._player else "-", llega, combat._preps_turno, combat._accion_disponible(combat.Action.HABILIDAD), combat._motivo_bloqueo(combat.Action.HABILIDAD)])
	_afirmar(llega and combat._preps_turno.is_empty() and combat._accion_disponible(combat.Action.HABILIDAD),
		"el turno siguiente (el de otro del grupo) vuelve a tener todo")
	print("[cargar-turno] RESULTADO: %s (%d fallos)" % ["TODO BIEN" if _fallos == 0 else "HAY FALLOS", _fallos])
	get_tree().quit(1 if _fallos > 0 else 0)
