# DOS PELEAS A LA VEZ, guion del JUGADOR B (ver prueba_town_dos_peleas_guion.gd).
extends "res://tools/prueba_town_dos_comun.gd"


func _ready() -> void:
	prefijo = "[B] "
	await _esperar(0.5)
	if (await entrar_en_la_sala()).is_empty():
		print("[B] RESULTADO: FALLAN %d" % maxi(1, fallos.size()))
		get_tree().quit(1)
		return

	# FASE 1: bajo al 1.
	await esperar_fase(1, 120.0)
	Net.pisos.solicitar_entrar(1)
	_ok(await _hasta(func(): return Net._mi_lugar == "piso:1" and get_tree().get_first_node_in_group("dungeon_floor") != null, 40.0),
		"bajo al piso 1")
	# FASE 2: A ha cogido uno; yo el mas lejos de el, a la vez.
	await _ronda(2)

	# FASE 3: bajo al 2.
	await esperar_fase(3, 180.0)
	Net.pisos.solicitar_piso(2, true)
	_ok(await _hasta(func(): return Net._mi_lugar == "piso:2" and get_tree().get_first_node_in_group("dungeon_floor") != null, 40.0),
		"bajo al piso 2")
	await _hasta(func(): return enemigo_libre() != null, 15.0)
	# FASE 4: otra vez a la vez, cada uno en su piso.
	await _ronda(4)

	Net.pisos.viajar_al_pueblo()
	_ok(await _hasta(func(): return Net._mi_lugar == "pueblo", 20.0), "subo al pueblo")
	await esperar_fase(9, 180.0)
	print("[B] RESULTADO: ", "TODO PASA" if fallos.is_empty() else "FALLAN %d" % fallos.size())
	Net.desconectar()
	await _esperar(1.0)
	get_tree().quit(0 if fallos.is_empty() else 1)


func _ronda(fase: int) -> void:
	var datos: Array = await esperar_fase(fase, 180.0)
	var suya: Node2D = enemigo_libre(Vector2.INF, int(datos[1])) if datos.size() > 1 else null
	var lejos: Vector2 = suya.global_position if suya != null else Vector2.INF
	var presa: Node2D = enemigo_libre(lejos)
	_ok(presa != null, "hay un enemigo libre para mi (ronda %d)" % fase)
	if presa == null:
		return
	await pelear_con(presa)
	_ok(Game.hay_pelea_en_pantalla() and Net.peleas.espejando(), "tengo mi pelea en ESPEJO (ronda %d)" % fase)
	_ok(await pelear_hasta_el_final(90.0), "gano mi pelea (ronda %d)" % fase)


func _hasta(cond: Callable, tope: float) -> bool:
	var t := 0.0
	while not cond.call() and t < tope:
		await _esperar(0.25)
		t += 0.25
	return cond.call()
