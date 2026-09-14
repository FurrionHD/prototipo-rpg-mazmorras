extends Node

const PUERTO := 24599
var fallos: Array = []


func _ok(cond: bool, texto: String) -> void:
	print(("[PASA] " if cond else "[FALLA] ") + texto)
	if not cond:
		fallos.append(texto)


func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


func _espejos_vivos() -> int:
	var n := 0
	for id in Net.enemigos._enem_nodos:
		if is_instance_valid(Net.enemigos._enem_nodos[id]):
			n += 1
	return n


func _trabajador_libre() -> int:
	for w in Net._trab._estado:
		if int(Net._trab._estado[w]) == 0:
			return w
	return 0


func _ready() -> void:
	print("[dev] datos de usuario: ", OS.get_user_data_dir())
	Game.semilla_mundo = 424242
	await _esperar(0.5)
	var err := Net.hostear("abc", PUERTO)
	_ok(err == OK, "sala abierta")

	# 1) El de reserva arranca y se presenta.
	var t := 0.0
	while _trabajador_libre() == 0 and t < 40.0:
		await _esperar(0.5)
		t += 0.5
	var w := _trabajador_libre()
	_ok(w != 0, "un trabajador se presenta en %.1f s" % t)
	if w == 0:
		_fin()
		return
	_ok(not Net._avatares.has(w), "el trabajador no tiene avatar en el host")
	_ok(Net._num_humanos == 1, "el trabajador no cuenta como humano (humanos=%d)" % Net._num_humanos)

	# 2) Entro al piso 1: el dueño tiene que ser el trabajador y yo espejo.
	Net.pisos.solicitar_entrar(1)
	await _esperar(10.0)
	_ok(int(Net._dueno_piso.get(1, 0)) == w, "el piso 1 lo simula el trabajador (dueño=%s)" % str(Net._dueno_piso.get(1, 0)))
	_ok(not Net._soy_dueno, "el host entra de espejo")
	var espejos := _espejos_vivos()
	_ok(espejos > 0, "el host ve los enemigos del trabajador (%d espejos)" % espejos)
	print("[dev] nodos en grupo enemy: ", get_tree().get_nodes_in_group("enemy").size())

	# 3) Subo al pueblo: el piso se congela y el trabajador vuelve a la reserva.
	Net.pisos.viajar_al_pueblo()
	await _esperar(4.0)
	var foto: Dictionary = Net._fotos_piso.get(1, {})
	var n_foto := (foto.get("enemigos", []) as Array).size()
	_ok(Net._fotos_piso.has(1) and n_foto > 0, "piso 1 congelado con %d enemigos" % n_foto)
	# Habia otro esperando: este sobra y se cierra (si no, volveria a la reserva).
	_ok(int(Net._trab._estado.get(w, 0)) == 0, "el trabajador suelta el piso (reserva o cerrado)")
	_ok(Net._trab._libres() == Net._trab.RESERVA, "queda exactamente la reserva (%d)" % Net._trab._libres())
	_ok(not Net._dueno_piso.has(1), "el piso 1 ya no tiene dueño")

	# 4) Vuelvo a bajar: lo recoge un trabajador con la foto y veo los mismos enemigos.
	Net.pisos.solicitar_entrar(1)
	await _esperar(10.0)
	var dueno2: int = int(Net._dueno_piso.get(1, 0))
	_ok(Net.es_trabajador(dueno2), "al volver, el piso lo simula un trabajador otra vez")
	var espejos2 := _espejos_vivos()
	_ok(espejos2 == n_foto, "vuelven los mismos enemigos (%d de %d)" % [espejos2, n_foto])

	# 5) Me planto al lado de un enemigo: el trabajador tiene que perseguirme y mandarme la pelea a MI.
	var jugador: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var presa = null
	for id in Net.enemigos._enem_nodos:
		var n = Net.enemigos._enem_nodos[id]
		if is_instance_valid(n) and not n.esta_muerto():
			presa = n
			break
	if jugador != null and presa != null:
		jugador.recolocar((presa as Node2D).global_position + Vector2(40, 0))
		t = 0.0
		while not Game.hay_pelea_en_pantalla() and t < 12.0:
			await _esperar(0.25)
			t += 0.25
		# Que me vea depende de su cono y de que yo haga ruido (quieto y de espaldas no me ve, igual que en
		# solitario): esto se apunta, no se exige.
		print("[dev] ¿me ha visto y embestido solo?: ", Game.hay_pelea_en_pantalla(), " (%.1f s)" % t)
		if not Game.hay_pelea_en_pantalla() and is_instance_valid(presa):
			# Le ataco yo: la pelea se le PIDE al dueño (el trabajador), que reserva y me la devuelve.
			presa.atacado_por_jugador(0.3)
			t = 0.0
			while not Game.hay_pelea_en_pantalla() and t < 5.0:
				await _esperar(0.25)
				t += 0.25
		_ok(Game.hay_pelea_en_pantalla(), "la pelea contra un enemigo del trabajador se abre en mi PC (%.1f s)" % t)
		_ok(Game.combate_activo(), "los enemigos de la pelea los llevo yo")
	else:
		_ok(false, "no hay jugador o enemigo para la prueba de la pelea")

	_fin()


func _fin() -> void:
	var pids: Array = Net._trab._pids.duplicate()
	Net.desconectar()
	await _esperar(3.0)
	var vivos := pids.filter(func(p): return OS.is_process_running(p))
	_ok(vivos.is_empty(), "los trabajadores se cierran con la sala (%d vivos)" % vivos.size())
	print("[dev] RESULTADO: ", "TODO PASA" if fallos.is_empty() else "FALLAN %d" % fallos.size())
	get_tree().quit()
