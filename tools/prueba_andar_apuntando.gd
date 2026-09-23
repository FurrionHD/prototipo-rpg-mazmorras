# PRUEBA: ANDAR MIENTRAS APUNTAS (combate tactico). En la arena de verdad y sin ventana:
#   - apuntando y andando, el muñeco lleva la animacion de ANDAR y su reloj AVANZA (no se reinicia
#     cada fotograma, que era el personaje tieso);
#   - andando, el clic NO suelta la habilidad;
#   - al pararse, mira hacia el raton (el punto apuntado) y ya se puede soltar.
#   godot --headless --path . res://tools/prueba_andar_apuntando.tscn
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
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(5)
	Game.entrar_arena_de_pruebas()
	await _esperar(15)
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime.tres", jug.global_position + Vector2(120, 0), {})
	await _esperar(20)
	var enemigos: Array = get_tree().get_nodes_in_group("enemy")
	if not Game.start_combat(enemigos, false):
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
	var ab: AbilityData = load("res://resources/abilities/temblor.tres")
	combat._player.current_energy = combat._player.max_energy
	t.apuntar(ab)
	await _esperar(2)
	var muneco = t._cuerpo.get("_muneco")
	# ANDANDO hacia abajo (el raton se queda donde este).
	Input.action_press("move_down")
	await _esperar(6)
	var anim_1: String = muneco._anim
	var reloj_1: float = muneco._reloj
	await _esperar(12)
	var anim_2: String = muneco._anim
	var reloj_2: float = muneco._reloj
	print("andando: %s %.3f -> %s %.3f" % [anim_1, reloj_1, anim_2, reloj_2])
	_afirmar(anim_1 == anim_2 and reloj_2 > reloj_1 + 0.05 and t._andando,
		"apuntando y andando, la animacion de andar corre (no se reinicia)")
	t._confirmar_apunte()
	await _esperar(2)
	_afirmar(t.esta_apuntando() and combat._state == combat.State.WAITING_PLAYER,
		"andando, el clic no suelta la habilidad")
	Input.action_release("move_down")
	await _esperar(4)
	var al_raton: Vector2 = t._raton_en_mundo() - t._cuerpo.global_position
	var mira: Vector2 = t._cuerpo.get("_facing")
	print("parado: %s | mira %s | raton %s" % [muneco._anim, str(mira), str(al_raton.normalized())])
	_afirmar(not t._andando and mira.dot(al_raton.normalized()) > 0.99, "al pararse mira hacia el raton")
	t._confirmar_apunte()
	await _esperar(3)
	_afirmar(not t.esta_apuntando(), "quieto, el clic la suelta")
	print("[andar-apuntando] RESULTADO: %s (%d fallos)" % ["TODO BIEN" if _fallos == 0 else "HAY FALLOS", _fallos])
	get_tree().quit(1 if _fallos > 0 else 0)
