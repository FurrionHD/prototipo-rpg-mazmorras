# DOS PELEAS A LA VEZ, guion del JUGADOR B (ver prueba_town_dos_peleas_guion.gd). Acaba CAYENDOSE a mitad de una
# pelea (fase 6): se cierra sin desconectar.
extends "res://tools/prueba_town_dos_comun.gd"


func _ready() -> void:
	prefijo = "[B] "
	await _esperar(0.5)
	if (await entrar_en_la_sala()).is_empty():
		print("[B] RESULTADO: FALLAN %d" % maxi(1, fallos.size()))
		get_tree().quit(1)
		return

	# FASE 1: bajo al 1.
	await esperar_fase_peleando(1, 120.0)
	Net.pisos.solicitar_entrar(1)
	_ok(await _hasta(func(): return Net._mi_lugar == "piso:1" and get_tree().get_first_node_in_group("dungeon_floor") != null, 40.0),
		"bajo al piso 1")
	# FASE 2: A ha cogido uno; yo el mas lejos de el, a la vez.
	await _mi_pelea(2)

	# FASE 3: entro en la pelea de A pegandole a su enemigo.
	var d: Array = await esperar_fase_peleando(3, 180.0)
	while d.size() < 2 and int(d[0]) == 3:
		await _esperar(0.25)
		d = leer_fase()
	var suya: Node2D = enemigo_libre(Vector2.INF, int(d[1])) if d.size() > 1 else null
	var jugador: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	_ok(suya != null and jugador != null, "veo el enemigo de la pelea de A")
	if suya != null and jugador != null:
		jugador.recolocar(suya.global_position + Vector2(-40, 0))
		await _esperar(0.3)
		var t0: int = Time.get_ticks_msec()
		suya.atacado_por_jugador(0.6)
		_ok(await _hasta(func(): return Game.hay_pelea_en_pantalla(), 15.0), "entro en la pelea de A")
		var t: float = float(Time.get_ticks_msec() - t0) / 1000.0
		# (La zona de A puede meterme antes si me pilla dentro: entonces no hay golpe que esperar.)
		_ok(t <= 1.0, "RESERVAR AL PULSAR: entro como mucho al tocar mi golpe de 0,6 s (a los %.2f s)" % t)
		print("[B] dato pelea_unida=%d" % Net.peleas._pelea_sigo)
		_ok(await pelear_hasta_el_final(90.0), "ganamos la pelea")

	# FASE 4: bajo al 2.
	await esperar_fase_peleando(4, 180.0)
	Net.pisos.solicitar_piso(2, true)
	_ok(await _hasta(func(): return Net._mi_lugar == "piso:2" and get_tree().get_first_node_in_group("dungeon_floor") != null, 40.0),
		"bajo al piso 2")
	await _hasta(func(): return enemigo_libre() != null, 15.0)
	# FASE 5: peleo en el 2 mientras a A le embisten en el 1.
	await _mi_pelea(5)

	# FASE 6: empiezo otra y ME CAIGO a mitad (sin desconectar: se corta).
	await esperar_fase_peleando(6, 180.0)
	await acabar_pelea_suelta()
	var presa: Node2D = enemigo_libre()
	_ok(presa != null, "hay un enemigo libre para mi (fase 6)")
	if presa != null:
		await pelear_con(presa)
		_ok(Game.hay_pelea_en_pantalla() and Net.peleas.espejando(), "tengo mi pelea (fase 6)")
	await _esperar(1.5)
	print("[B] RESULTADO: ", "TODO PASA" if fallos.is_empty() else "FALLAN %d" % fallos.size())
	get_tree().quit(0 if fallos.is_empty() else 1)


func _mi_pelea(fase: int) -> void:
	var datos: Array = await esperar_fase_peleando(fase, 180.0)
	await acabar_pelea_suelta()
	var suya: Node2D = enemigo_libre(Vector2.INF, int(datos[1])) if datos.size() > 1 else null
	var lejos: Vector2 = suya.global_position if suya != null else Vector2.INF
	var presa: Node2D = enemigo_libre(lejos)
	_ok(presa != null, "hay un enemigo libre para mi (fase %d)" % fase)
	if presa == null:
		return
	await pelear_con(presa)
	_ok(Game.hay_pelea_en_pantalla() and Net.peleas.espejando(), "tengo mi pelea en ESPEJO (fase %d)" % fase)
	_ok(await pelear_hasta_el_final(90.0), "gano mi pelea (fase %d)" % fase)


func _hasta(cond: Callable, tope: float) -> bool:
	var t := 0.0
	while not cond.call() and t < tope:
		await _esperar(0.25)
		t += 0.25
	return cond.call()
