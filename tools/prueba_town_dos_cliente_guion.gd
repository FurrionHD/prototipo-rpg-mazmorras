# PRUEBA DE DOS JUGADORES, guion del JUGADOR B. Obedece las fases que escribe el host (ver
# prueba_town_dos_jugadores_guion.gd) y apunta lo que ve con el prefijo [B]: el host lo lee de su registro.
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
	# Uno de MIS personajes de casa con foto: el host la tiene que recibir (_subir_fotos).
	(Game.plantilla[5] as PersonajeData).set_imagen(foto_de_prueba(Color(0.2, 0.4, 0.9)))
	# Un reloj "mal puesto": el host tiene que corregirlo al entrar (CicloDia, Net._set_hora_pueblo). Los
	# dos procesos van en el mismo PC, asi que tras la correccion la diferencia es casi cero.
	CicloDia.desfase = 777.0
	await _esperar(0.5)
	var err := Net.unirse(args[i + 1], args[i + 3], int(args[i + 2]))
	_ok(err == OK, "me conecto a la sala")
	var t := 0.0
	while Net._num_humanos < 2 and t < 30.0:
		await _esperar(0.5)
		t += 0.5
	_ok(Net._num_humanos == 2, "el host me admite (%.1f s)" % t)
	# La hora va al final del alta, detras de los paquetes gordos (baul, cofre...): puede tardar segundos.
	var th := 0.0
	while absf(CicloDia.desfase - 777.0) < 0.01 and th < 20.0:
		await _esperar(0.5)
		th += 0.5
	_ok(absf(CicloDia.desfase) < 2.0, "el host me pone su hora del pueblo (desfase %.2f s, tras %.1f s)"
		% [CicloDia.desfase, th])

	# FASE 0: LA CARA Y LA FOTO de un personaje de casa del host, como las pinta Encargos.
	# Los dos procesos corren en el MISMO PC (misma identidad) y cargan la MISMA partida de referencia
	# (mismos uid): el de casa del host se reconoce por su uid, el de la plantilla[1].
	# Mi hogar se publica al cambiar el equipo; aqui no ha cambiado nada, asi que se fuerza.
	Net.hogar.marcar_hogar_sucio()
	var uid_host: String = String((Game.plantilla[1] as PersonajeData).uid)
	var visto := 0
	var tf := 0.0
	while visto == 0 and tf < 15.0:
		for f in Net.hogar.roster_hogar():
			var fila := f as Dictionary
			if String(fila.get("uid", "")) != uid_host or int(fila.get("imagen_huella", 0)) == 0:
				continue
			var pj: PersonajeData = Net.hogar.pj_de_fila(fila)
			if pj != null and not pj.aspecto.is_empty() and not pj.imagen.is_empty():
				visto = 1
		if visto == 0:
			await _esperar(0.5)
			tf += 0.5
	_ok(visto == 1, "veo la cara y la foto de un personaje de casa del host")
	print("[B] dato foto_del_host=%d" % visto)

	# FASE 1: bajo al piso 1.
	await esperar_fase(1, 60.0)
	Net.pisos.solicitar_entrar(1)
	await _esperar(8.0)
	_ok(Net.pisos.mi_piso() == 1, "estoy en el piso 1")

	# FASE 2: DOS PELEAS A LA VEZ. El host ya esta peleando; yo me voy a por otro enemigo lejos de el.
	await esperar_fase(2, 90.0)
	var excelia_antes := excelia_grupo()
	await pelear_con(enemigo_libre(Net.posicion_de_peer(1)))
	_ok(Net.peleas.espejando() and not Game.combate_activo(),
		"mi pelea la ejecuta otro y yo la espejo (anfitrion=%d)" % Net.peleas._pelea_anfitrion)
	print("[B] dato anfitrion_fase2=%d" % Net.peleas._pelea_anfitrion)
	_ok(await pelear_hasta_el_final(60.0), "mi pelea termina")
	_ok(excelia_grupo() > excelia_antes, "me llega la excelia de mi pelea (%.2f -> %.2f)" % [excelia_antes, excelia_grupo()])
	print("[B] dato fase2_fin")

	# FASE 3: ME UNO A LA PELEA DEL HOST (me pasa el id de un enemigo de su pelea y quien la ejecuta) y HUYO.
	var fase: Array = await esperar_fase(3, 120.0)
	var id_enemigo: int = int(fase[1]) if fase.size() > 1 else 0
	var su_anfitrion: int = int(fase[2]) if fase.size() > 2 else 0
	await pelear_con(enemigo_libre(Vector2.INF, id_enemigo))
	_ok(Net.peleas.espejando() and Net.peleas._pelea_anfitrion == su_anfitrion,
		"me uno a la pelea del host (anfitrion=%d, el suyo=%d)" % [Net.peleas._pelea_anfitrion, su_anfitrion])
	# EL REGISTRO ENTERO al unirme a mitad: la primera frase de la pelea (la de la iniciativa) se escribio
	# antes de que yo llegara, asi que solo la tengo si el espejo ha pedido el registro por el hueco.
	var reg: Array = []
	t = 0.0
	while t < 5.0:
		var pr: Node = pantalla()
		reg = pr.get("_log_lines") if pr != null else []
		if not reg.is_empty() and String(reg[0]).contains("iniciativa"):
			break
		await _esperar(0.25)
		t += 0.25
	_ok(not reg.is_empty() and String(reg[0]).contains("iniciativa"),
		"al unirme veo el registro desde el principio (%d frases; la primera: '%s')" % [reg.size(),
			String(reg[0]) if not reg.is_empty() else ""])
	var agilidad_antes := agilidad_grupo()
	t = 0.0
	while Net.peleas.espejando() and t < 40.0:
		if pulsar(5):   # Huir
			print("[B] [dev] pulso Huir (%.1f s)" % t)
		var p: Node = pantalla()
		if p != null and p.acabada():
			print("[B] [dev] la pelea ha acabado antes de poder huir")
			break
		await _esperar(0.25)
		t += 0.25
	t = 0.0
	while (Game.hay_pelea_en_pantalla() or Net.peleas._desgaste_pendiente) and t < 10.0:
		await _esperar(0.25)
		t += 0.25
	_ok(not Net.peleas.espejando() and not Game.hay_pelea_en_pantalla(), "huyo y salgo de la pelea del host")
	_ok(agilidad_grupo() > agilidad_antes, "huir me entrena la Agilidad (%.3f -> %.3f)" % [agilidad_antes, agilidad_grupo()])
	print("[B] dato fase3_fin")

	# FASE 4: LA ARENA. No soy su dueño (la lleva un trabajador), y aun asi todo lo que pulso funciona.
	await esperar_fase(4, 180.0)
	var excelia_arena := excelia_grupo()
	Game.entrar_arena_de_pruebas()
	var ta := 0.0
	while Net._mi_lugar != "piso:%d" % Game.PISO_ARENA and ta < 20.0:
		await _esperar(0.5)
		ta += 0.5
	_ok(Net._mi_lugar == "piso:%d" % Game.PISO_ARENA and not Net._soy_dueno,
		"entro en la arena y NO soy su dueño")
	await _esperar(3.0)
	var yo: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var slime := "res://scenes/actors/enemy/slime.tres"
	Net.pisos.pedir_spawn_arena(slime, yo.global_position + Vector2(0, 110), {"modo": 1, "hp": 5.0})
	var mio: Node2D = null
	ta = 0.0
	while mio == null and ta < 10.0:
		mio = enemigo_libre()
		await _esperar(0.25)
		ta += 0.25
	_ok(mio != null and int(Game.muneco_de(mio).get("modo", 0)) == 1,
		"pongo un enemigo con el spawner sin ser el dueño, y me llega con su muñeco")
	await pelear_con(mio)
	_ok(Net.peleas.espejando(), "la pelea de la arena la ejecuta otro (anfitrion=%d)" % Net.peleas._pelea_anfitrion)
	_ok(await pelear_hasta_el_final(60.0), "la pelea contra el muñeco termina")
	var excelia_dentro := excelia_grupo()
	print("[B] [dev] excelia en la arena: %.3f -> %.3f" % [excelia_arena, excelia_dentro])
	Net.pisos.pedir_spawn_arena(slime, yo.global_position + Vector2(90, 110), {"modo": 0, "hp": 5.0})
	await _esperar(2.0)
	Net.pisos.pedir_limpiar_arena()
	ta = 0.0
	while enemigo_libre() != null and ta < 10.0:
		await _esperar(0.25)
		ta += 0.25
	_ok(enemigo_libre() == null, "Limpiar desde mi maquina vacia la arena")
	var salida: Node = get_tree().get_first_node_in_group("salida_pueblo")
	if salida != null:
		salida.interact_with_player()
	ta = 0.0
	while Net._mi_lugar != "pueblo" and ta < 15.0:
		await _esperar(0.5)
		ta += 0.5
	await _esperar(1.0)
	_ok(Net._mi_lugar == "pueblo" and not Game.es_arena(), "salgo de la arena al pueblo")
	_ok(absf(excelia_grupo() - excelia_arena) < 0.0001,
		"lo de la arena no sale de ella (excelia %.3f, al entrar %.3f)" % [excelia_grupo(), excelia_arena])
	print("[B] dato arena_fin")

	await esperar_fase(9, 120.0)
	print("[B] RESULTADO: ", "TODO PASA" if fallos.is_empty() else "FALLAN %d" % fallos.size())
	Net.desconectar()
	await _esperar(1.0)
	get_tree().quit()
