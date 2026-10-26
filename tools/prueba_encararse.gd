# SE GIRAN HACIA A QUIEN PEGAN (12/10, playtest 11/10: "el mino pego el basico a quien te he marcado y no se ha girado
# primero a mirarlo; los personajes igual, deben quedar mirando hacia donde han pegado"). Sin red, pelea tactica en la
# arena:
#   1) un enemigo mirando a la DERECHA pega a uno que tiene a su IZQUIERDA: al acabar mira a la izquierda;
#   2) uno de los tuyos mirando al SUR pega al enemigo que tiene al NORTE: mira al norte;
#   3) encarar_hacia sin direccion no toca nada.
#   godot --headless --path . res://tools/prueba_encararse.tscn
extends Node

var sala = null   # su sala: tools/prueba_sala_propia.gd

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
	while Time.get_ticks_msec() - t0 < int(s * 1000.0):
		await get_tree().process_frame


func _pantalla() -> Node:
	for n in get_tree().root.get_children() + sala.capas():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					return h
	return null


func _correr() -> void:
	# EN SU SALA (etapa 4, 26/10): la prueba es la sala y la pelea se abre por donde la abre ella.
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_encararse", Game.PISO_ARENA):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	sala.poner("res://scenes/actors/enemy/rata.tres", Vector2(90, 0), {})
	await _esperar(25)
	var bichos: Array = get_tree().get_nodes_in_group("enemy")
	if bichos.is_empty() or not (await sala.pelear([bichos[0]], false) != null):
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	await _esperar(10)
	var combat: Node = _pantalla()
	combat.set_process(false)
	var tm = combat.turno_mapa
	var e: Combatant = combat._enemies[0]
	var al: Combatant = combat._aliados[0]
	var cu_e: Node2D = tm.cuerpo_de(e)
	var cu_a: Node2D = tm.cuerpo_de(al)
	# Los demas, lejos: que la victima sea 'al'.
	for o in combat._aliados:
		if o != al and tm.cuerpo_de(o) != null:
			tm.cuerpo_de(o).global_position = cu_e.global_position + Vector2(0, 600)
			tm._pos[o] = tm.cuerpo_de(o).global_position

	print("1) el enemigo pega a uno a su izquierda")
	cu_a.global_position = cu_e.global_position + Vector2(-34, 0)
	tm._pos[al] = cu_a.global_position
	tm._animar(cu_e, Vector2.RIGHT, false)
	e.habilidades = []   # solo el basico: aqui se mira hacia donde pega, no que habilidad elige
	combat._player = e
	combat._state = combat.State.ADVANCING
	var n_log: int = combat._log_lines.size()
	combat.enemigos._enemy_turn(e)
	combat.set_process(true)
	await _segundos(3.0)
	combat.set_process(false)
	# A QUIEN HA PEGADO DE VERDAD (13/10): los otros, apartados, a veces quedan a tiro y se lo lleva uno de ellos; antes
	# esto exigia "a la izquierda" y pasaba de casualidad (el giro salia de las tarjetas). Lo dice el registro (tambien
	# si lo esquiva).
	var nuevas: String = " ".join(combat._log_lines.slice(n_log).map(func(l): return str(l)))
	for o in combat._aliados:
		nuevas = nuevas.replace("Turno de %s" % o.nombre, "")
	var victima: Combatant = al
	for o in combat._aliados:
		if nuevas.contains(o.nombre):
			victima = o
	var hacia: Vector2 = (tm.cuerpo_de(victima).global_position - cu_e.global_position).normalized()
	var m_e: Vector2 = tm._mirada_de(cu_e)
	_ver(m_e.dot(hacia) > 0.5, "mira hacia %s, a quien pego (mira %s, esta hacia %s)" % [victima.nombre,
		str(m_e.snapped(Vector2(0.01, 0.01))), str(hacia.snapped(Vector2(0.01, 0.01)))])

	print("1b) la direccion del gesto sale de los CUERPOS del mapa, no de las tarjetas (13/10)")
	# En el espejo es lo unico que gira al bicho antes de pegar: las crias del playtest 11/10 pegaban hacia el otro lado.
	var ev := {"ba": combat._bloque_de(e), "bv": combat._bloque_de(al)}
	for lado in [-1.0, 1.0]:
		cu_a.global_position = cu_e.global_position + Vector2(40.0 * lado, 0)
		tm._pos[al] = cu_a.global_position
		var d_e: Vector2 = combat._fx._direccion_golpe(ev, null, null)
		_ver(signf(d_e.x) == lado and absf(d_e.x) > 0.6, "con su victima a la %s, el gesto sale hacia alli (%s)" % [
			"izquierda" if lado < 0.0 else "derecha", str(d_e.snapped(Vector2(0.01, 0.01)))])

	print("2) uno de los tuyos pega al enemigo que tiene al norte")
	cu_a.global_position = cu_e.global_position + Vector2(0, 34)
	tm._pos[al] = cu_a.global_position
	tm._animar(cu_a, Vector2.DOWN, false)
	var b_a: Dictionary = combat._bloque_de(al)
	combat._fx._dir_gesto[b_a] = cu_e.global_position - cu_a.global_position
	combat.figuras._on_gesto_iniciado(b_a, 0, 0.5)
	var m_a: Vector2 = tm._mirada_de(cu_a)
	_ver(m_a.y < -0.3, "mira al norte, donde pega (%s)" % str(m_a.snapped(Vector2(0.01, 0.01))))

	print("3) sin direccion no se toca")
	var antes: Vector2 = tm._mirada_de(cu_a)
	tm.encarar_hacia(al, Vector2.ZERO)
	_ver(tm._mirada_de(cu_a).is_equal_approx(antes), "sigue mirando igual")

	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
