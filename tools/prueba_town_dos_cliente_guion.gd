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
	await _esperar(0.5)
	var err := Net.unirse(args[i + 1], args[i + 3], int(args[i + 2]))
	_ok(err == OK, "me conecto a la sala")
	var t := 0.0
	while Net._num_humanos < 2 and t < 30.0:
		await _esperar(0.5)
		t += 0.5
	_ok(Net._num_humanos == 2, "el host me admite (%.1f s)" % t)

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

	await esperar_fase(9, 120.0)
	print("[B] RESULTADO: ", "TODO PASA" if fallos.is_empty() else "FALLAN %d" % fallos.size())
	Net.desconectar()
	await _esperar(1.0)
	get_tree().quit()
