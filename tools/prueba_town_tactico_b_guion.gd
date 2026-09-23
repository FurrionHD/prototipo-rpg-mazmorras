# PRUEBA DEL COMBATE EN EL MAPA CON DOS JUGADORES, guion del JUGADOR B. Obedece las fases del host
# (prueba_town_tactico_guion.gd) y apunta lo que ve con "[B] dato clave=valor": el host lo lee de su
# registro.
extends "res://tools/prueba_town_dos_comun.gd"


func _ready() -> void:
	prefijo = "[B] "
	var args := OS.get_cmdline_user_args()
	var i := args.find("cliente")
	if i < 0 or args.size() < i + 4:
		print("[B] faltan argumentos: cliente <ip> <puerto> <codigo>")
		get_tree().quit(1)
		return
	cargar_grupo([2, 3])
	await _esperar(0.5)
	_ok(Net.unirse(args[i + 1], args[i + 3], int(args[i + 2])) == OK, "me conecto a la sala")
	var t := 0.0
	while Net._num_humanos < 2 and t < 30.0:
		await _esperar(0.5)
		t += 0.5

	# FASE 1: a la arena.
	await esperar_fase(1, 90.0)
	await _esperar(2.0)
	Game.entrar_arena_de_pruebas()
	t = 0.0
	while Net._mi_lugar != "piso:%d" % Game.PISO_ARENA and t < 30.0:
		await _esperar(0.5)
		t += 0.5
	_ok(Net._mi_lugar == "piso:%d" % Game.PISO_ARENA, "entro en la arena")

	# FASE 2: me uno a la pelea del host, por el bicho que me dice.
	var fase: Array = await esperar_fase(2, 120.0)
	var id_bicho: int = int(fase[1]) if fase.size() > 1 else 0
	var bicho: Node2D = enemigo_libre(Vector2.INF, id_bicho)
	await _esperar(1.0)
	await pelear_con(bicho)
	var p: Node = pantalla()
	_ok(Net.peleas.espejando() and p != null, "me uno a la pelea del host")
	var tactico: bool = p != null and bool(p.tactico)
	_ok(tactico and Game.pelea_tactica_en_curso(), "la veo EN EL MAPA, con su arena montada")
	print("[B] dato espejo_tactico=%d" % (1 if tactico else 0))
	if not tactico:
		await esperar_fase(9, 120.0)
		_acabar()
		return

	# FASE 2-3: jugar mis turnos (andar y Defender) y mirar como se mueven los demas.
	var host: Node2D = Game.cuerpo_de_red(1, 0)
	var host_desde: Vector2 = host.global_position if host != null else Vector2.ZERO
	# TODOS los bichos de la pelea, no solo por el que entre: el que anda en su turno puede ser otro.
	var bichos_desde: Dictionary = {}
	for e in p._enemies:
		var cb: Node2D = p.turno_mapa.cuerpo_de(e)
		if cb != null:
			bichos_desde[cb] = cb.global_position
	var host_max := 0.0
	var bicho_max := 0.0
	var radio_visto := 0.0
	var tm = p.turno_mapa
	var sentido := ["move_right", "move_down", "move_left"]
	var vuelta := 0
	var t0: int = Time.get_ticks_msec()
	while int(leer_fase()[0]) < 3 and (Time.get_ticks_msec() - t0) < 150000:
		if is_instance_valid(host):
			host_max = maxf(host_max, host.global_position.distance_to(host_desde))
		for cb in bichos_desde:
			if is_instance_valid(cb):
				bicho_max = maxf(bicho_max, (cb as Node2D).global_position.distance_to(bichos_desde[cb]))
		if is_instance_valid(p) and int(p._state) == 1 and tm._fase == tm.Fase.MOVIENDO and not caja_abierta(p):
			radio_visto = maxf(radio_visto, tm._radio)
			var cuerpo: Node2D = tm._cuerpo
			var antes: Vector2 = cuerpo.global_position
			var tecla: String = sentido[vuelta % sentido.size()]
			vuelta += 1
			Input.action_press(tecla)
			await _esperar(0.8)
			Input.action_release(tecla)
			var ahora: Vector2 = cuerpo.global_position
			print("[B] [dev] mi turno (%s): ando %.1f px, radio %.1f" % [tm._quien.nombre, ahora.distance_to(antes), tm._radio])
			# ANTES de contestar: lo que sale con la accion es esta posicion.
			print("[B] dato b_pos_x_%s=%d" % [tm._quien.nombre, int(round(ahora.x))])
			print("[B] dato b_pos_y_%s=%d" % [tm._quien.nombre, int(round(ahora.y))])
			pulsar(3)
		await _esperar(0.05)
	print("[B] [dev] el host se movio %.1f px y el bicho %.1f px en mi pantalla" % [host_max, bicho_max])
	print("[B] dato host_se_movio=%d" % int(host_max))
	print("[B] dato bicho_se_movio=%d" % int(bicho_max))
	print("[B] dato b_radio=%d" % int(radio_visto))
	await esperar_fase(9, 120.0)
	_acabar()


func _acabar() -> void:
	print("[B] RESULTADO: ", "TODO PASA" if fallos.is_empty() else "FALLAN %d" % fallos.size())
	Net.desconectar()
	await _esperar(1.0)
	get_tree().quit()
