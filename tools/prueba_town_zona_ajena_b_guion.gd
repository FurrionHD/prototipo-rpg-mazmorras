# LA PELEA DE OTRO VISTA DESDE FUERA, guion del JUGADOR B (ver prueba_town_zona_ajena_guion.gd). Apunta lo que ve con
# "[B] dato clave=valor" y el host lo lee de su registro.
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

	await esperar_fase(1, 90.0)
	await _esperar(2.0)
	Game.entrar_arena_de_pruebas()
	t = 0.0
	while Net._mi_lugar != "piso:%d" % Game.PISO_ARENA and t < 30.0:
		await _esperar(0.5)
		t += 0.5
	_ok(Net._mi_lugar == "piso:%d" % Game.PISO_ARENA, "entro en la arena")

	# FASE 2: me pongo LEJOS de donde va a pegar el host, en linea recta por el suelo (para luego andar hacia el).
	var fase: Array = await esperar_fase(2, 120.0)
	var golpe := Vector2(float(fase[1]), float(fase[2])) if fase.size() > 2 else Vector2.ZERO
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	var yo: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var sitio := Vector2.INF
	var tecla := ""
	for par in [[Vector2.LEFT, "move_right"], [Vector2.RIGHT, "move_left"], [Vector2.UP, "move_down"], [Vector2.DOWN, "move_up"]]:
		var q: Vector2 = golpe + (par[0] as Vector2) * 460.0
		if piso != null and piso.gen.es_suelo(ArenaCalculo.celda_de_px(q)) and ArenaCalculo.linea_por_suelo(piso.gen, q, golpe):
			sitio = q
			tecla = par[1]
			break
	_ok(sitio != Vector2.INF, "encuentro un sitio lejos y a la vista")
	if sitio == Vector2.INF:
		await esperar_fase(9, 120.0)
		_acabar()
		return
	yo.recolocar(sitio)
	await _esperar(1.0)
	print("[B] dato colocado=1")

	# FASE 3: el host ha abierto su pelea. Yo, lejos: ni quieto ni dentro, pero veo su zona.
	var quieto := false
	t = 0.0
	while int(leer_fase()[0]) < 3 and t < 60.0:
		quieto = quieto or Game.entrando_en_pelea()
		await _esperar(0.05)
		t += 0.05
	t = 0.0
	while Game._zonas_ajenas.is_empty() and t < 10.0:
		quieto = quieto or Game.entrando_en_pelea()
		await _esperar(0.1)
		t += 0.1
	print("[B] dato quieto_lejos=%d" % (1 if quieto else 0))
	var anfitrion: int = int(Game._zonas_ajenas.keys()[0]) if not Game._zonas_ajenas.is_empty() else 0
	var nodo = Game._zonas_ajenas.get(anfitrion, {}).get("nodo")
	print("[B] dato ve_zona=%d" % (1 if nodo != null and is_instance_valid(nodo) and nodo.visible else 0))
	print("[B] [dev] zona de %d; yo en %s" % [anfitrion, str(yo.global_position.round())])

	# Ando hacia el golpe: la linea tiene que frenarme y preguntarme.
	var pregunta := false
	var nunca_dentro := true
	Input.action_press(tecla)
	t = 0.0
	while t < 15.0:
		if nodo != null and is_instance_valid(nodo) and (nodo as ArenaCombate).contiene(yo.global_position):
			nunca_dentro = false
		if Game._pregunta_pelea != null and is_instance_valid(Game._pregunta_pelea):
			pregunta = true
			break
		await _esperar(0.05)
		t += 0.05
	Input.action_release(tecla)
	print("[B] [dev] tras andar %.1f s: en %s, al borde %.1f px" % [t, str(yo.global_position.round()),
		(nodo as ArenaCombate).distancia_al_borde(yo.global_position) if nodo != null and is_instance_valid(nodo) else 0.0])
	print("[B] dato frenado=%d" % (1 if nunca_dentro and pregunta else 0))
	print("[B] dato pregunta=%d" % (1 if pregunta else 0))
	if pregunta:
		Game._pregunta_pelea._si()
	t = 0.0
	while not Net.peleas.espejando() and t < 20.0:
		await _esperar(0.25)
		t += 0.25
	print("[B] dato espejo=%d" % (1 if Net.peleas.espejando() and pantalla() != null else 0))
	_ok(Net.peleas.espejando(), "con el Si entro en la pelea del host (%.1f s)" % t)
	# Mis turnos, para que la pelea no se pare en el mio mientras el host acaba.
	while int(leer_fase()[0]) < 9:
		pulsar(3)
		await _esperar(0.25)
	_acabar()


func _acabar() -> void:
	print("[B] RESULTADO: ", "TODO PASA" if fallos.is_empty() else "FALLAN %d" % fallos.size())
	Net.desconectar()
	await _esperar(1.0)
	get_tree().quit()
