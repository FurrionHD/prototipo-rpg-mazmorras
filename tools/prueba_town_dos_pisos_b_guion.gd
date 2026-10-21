# DOS PISOS A LA VEZ, guion del JUGADOR B (ver prueba_town_dos_pisos_guion.gd). Apunta lo que ve con "[B] dato" y A lo
# lee de su registro.
extends "res://tools/prueba_town_dos_comun.gd"


func _ready() -> void:
	prefijo = "[B] "
	await _esperar(0.5)
	if (await entrar_en_la_sala()).is_empty():
		print("[B] RESULTADO: FALLAN %d" % maxi(1, fallos.size()))
		get_tree().quit(1)
		return

	# FASE 1: bajo al 1 y sigo al 2 por la escalera.
	await esperar_fase(1, 120.0)
	Net.pisos.solicitar_entrar(1)
	_ok(await _hasta(func(): return Net._mi_lugar == "piso:1" and get_tree().get_first_node_in_group("dungeon_floor") != null, 40.0),
		"bajo al piso 1")
	await _esperar(1.0)
	Net.pisos.solicitar_piso(2, true)
	_ok(await _hasta(func(): return Net._mi_lugar == "piso:2" and get_tree().get_first_node_in_group("dungeon_floor") != null, 40.0),
		"bajo al piso 2")
	await _hasta(func(): return not _mis_ids().is_empty(), 15.0)
	await _esperar(2.0)
	print("[B] dato ids=%s" % ",".join(_mis_ids().map(func(x): return str(x))))

	# FASE 2: mi jaleo (hasta que A pase a la fase 3).
	await esperar_fase(2, 120.0)
	while int(leer_fase()[0]) == 2:
		Game.sumar_alboroto(40.0)
		await _esperar(0.5)

	# FASE 3: subo al pueblo.
	Net.pisos.viajar_al_pueblo()
	_ok(await _hasta(func(): return Net._mi_lugar == "pueblo", 20.0), "subo al pueblo")
	await esperar_fase(9, 120.0)
	print("[B] RESULTADO: ", "TODO PASA" if fallos.is_empty() else "FALLAN %d" % fallos.size())
	Net.desconectar()
	await _esperar(1.0)
	get_tree().quit(0 if fallos.is_empty() else 1)


func _hasta(cond: Callable, tope: float) -> bool:
	var t := 0.0
	while not cond.call() and t < tope:
		await _esperar(0.25)
		t += 0.25
	return cond.call()


func _mis_ids() -> Array:
	var out: Array = []
	for nid in Net.enemigos._enem_nodos:
		if is_instance_valid(Net.enemigos._enem_nodos[nid]):
			out.append(int(nid))
	return out
