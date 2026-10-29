# PRUEBA DE DOS JUGADORES, guion del JUGADOR B. Obedece las fases que escribe A (ver
# prueba_town_dos_jugadores_guion.gd) y apunta lo que ve con el prefijo [B]: A lo lee de su registro.
extends "res://tools/prueba_town_dos_comun.gd"


func _ready() -> void:
	prefijo = "[B] "
	# Un reloj "mal puesto": la sala tiene que corregirlo al entrar (CicloDia, Net._set_hora_pueblo). Los
	# procesos van en el mismo PC, asi que tras la correccion la diferencia es casi cero.
	CicloDia.desfase = 777.0
	await _esperar(0.5)
	var f0: Array = await entrar_en_la_sala()
	if f0.size() < 3:
		print("[B] RESULTADO: FALLAN %d" % maxi(1, fallos.size()))
		get_tree().quit(1)
		return
	var peer_a: int = int(f0[1])   # A ya no es el anfitrion (el peer 1 es la sala)
	var t := 0.0
	while Net._num_humanos < 2 and t < 30.0:
		await _esperar(0.5)
		t += 0.5
	_ok(Net._num_humanos == 2, "estamos los dos (%.1f s)" % t)
	# Uno de MIS personajes de casa (el que no va en el equipo) con foto: A la tiene que poder pedir (Net.fotos).
	var mio_de_casa: Array = Game.plantilla.filter(func(pj): return not Game.party.has(pj))
	if not mio_de_casa.is_empty():
		(mio_de_casa[0] as PersonajeData).set_imagen(foto_de_prueba(Color(0.2, 0.4, 0.9)))
	# La hora va al final del alta, detras de los paquetes gordos (baul, cofre...): puede tardar segundos.
	var th := 0.0
	while absf(CicloDia.desfase - 777.0) < 0.01 and th < 20.0:
		await _esperar(0.5)
		th += 0.5
	_ok(absf(CicloDia.desfase) < 2.0, "la sala me pone su hora del pueblo (desfase %.2f s, tras %.1f s)"
		% [CicloDia.desfase, th])

	# FASE 0: LA CARA Y LA FOTO de un personaje de casa de A, como las pinta Encargos (A me dice su uid).
	# Mi hogar se publica al cambiar el equipo; aqui no ha cambiado nada, asi que se fuerza.
	Net.hogar.marcar_hogar_sucio()
	var uid_host: String = String(f0[2])
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
	_ok(visto == 1, "veo la cara y la foto de un personaje de casa de A")
	print("[B] dato foto_del_host=%d" % visto)
	# LA CARA DEL CUERPO: la de A me llego al presentarnos; la mia la mando ya dentro (_rel_aspecto -> _set_aspecto).
	Game.lider().set_imagen(foto_de_prueba(Color(0.9, 0.9, 0.2)))
	Net.pisos.anunciar_aspecto()
	var cara_a: bool = await veo_cara_de(peer_a, 15.0)
	_ok(cara_a, "veo la foto de A en el muñeco de su cuerpo")
	print("[B] dato cara_del_host=%d" % int(cara_a))

	# FASE 1: bajo al piso 1.
	await esperar_fase(1, 60.0)
	Net.pisos.solicitar_entrar(1)
	await _esperar(8.0)
	_ok(Net.pisos.mi_piso() == 1, "estoy en el piso 1")

	# FASE 2: DOS PELEAS A LA VEZ. A ya esta peleando; yo me voy a por otro enemigo lejos de el.
	await esperar_fase(2, 90.0)
	await acabar_pelea_suelta()
	var excelia_antes := excelia_grupo()
	await pelear_con(enemigo_libre(Net.posicion_de_peer(peer_a)))
	_ok(Net.peleas.espejando() and not Game.combate_activo(),
		"mi pelea la ejecuta otro y yo la espejo (anfitrion=%d)" % Net.peleas._pelea_anfitrion)
	print("[B] dato anfitrion_fase2=%d" % Net.peleas._pelea_sigo)   # el ID de mi pelea (etapa 3)
	# EN PELEA NO SE VIAJA (23/10): pido la escalera como si la hubiera pisado justo cuando me pillo la pelea. La
	# sala no me la da: sigo en el piso 1 (antes viajaba y la pelea vieja se colaba en la siguiente).
	Net.pisos.solicitar_piso(2, false)
	await _esperar(2.0)
	_ok(Net.pisos.mi_piso() == 1 and Game.current_floor == 1, "en mitad de mi pelea la sala no me deja bajar")
	_ok(await pelear_hasta_el_final(120.0), "mi pelea termina")   # (28/10) 60 no daba con un slime brotado y carga
	_ok(excelia_grupo() > excelia_antes, "me llega la excelia de mi pelea (%.2f -> %.2f)" % [excelia_antes, excelia_grupo()])
	print("[B] dato fase2_fin")

	# FASE 3: ME UNO A LA PELEA DE A (me pasa el id de un enemigo de su pelea y quien la ejecuta) y HUYO.
	var fase: Array = await esperar_fase(3, 120.0)
	var id_enemigo: int = int(fase[1]) if fase.size() > 1 else 0
	var su_anfitrion: int = int(fase[2]) if fase.size() > 2 else 0
	await acabar_pelea_suelta()
	await pelear_con(enemigo_libre(Vector2.INF, id_enemigo))
	_ok(Net.peleas.espejando() and Net.peleas._pelea_sigo == su_anfitrion,
		"me uno a la pelea de A (pelea %d, la suya %d)" % [Net.peleas._pelea_sigo, su_anfitrion])
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
		if huir():
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
	_ok(not Net.peleas.espejando() and not Game.hay_pelea_en_pantalla(), "huyo y salgo de la pelea de A")
	_ok(agilidad_grupo() > agilidad_antes, "huir me entrena la Agilidad (%.3f -> %.3f)" % [agilidad_antes, agilidad_grupo()])
	print("[B] dato fase3_fin")

	# FASE 4: LA ARENA. No soy su dueño (la lleva la sala), y aun asi todo lo que pulso funciona.
	await esperar_fase(4, 180.0)
	await acabar_pelea_suelta()
	var excelia_arena := excelia_grupo()
	Game.entrar_arena_de_pruebas()
	var ta := 0.0
	while Net._mi_lugar != "piso:%d" % Game.PISO_ARENA and ta < 20.0:
		# Si un bicho me pilla justo al pedirla, la sala no me da el viaje (en pelea no se viaja): la acabo y la vuelvo a
		# pedir. Lo ganado en esa pelea es de verdad (la foto de la arena se saca al llegar): se cuenta desde ahi.
		if Game.hay_pelea_en_pantalla():
			await pelear_hasta_el_final(60.0)
			excelia_arena = excelia_grupo()
			Game.entrar_arena_de_pruebas()
		await _esperar(0.5)
		ta += 0.5
	_ok(Net._mi_lugar == "piso:%d" % Game.PISO_ARENA and not PisoVivo.dueno_de(Net._mi_lugar),
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
	# QUIEN EJECUTA la pelea de la arena: la sala, y yo la veo en espejo (desde el 27/09
	# tambien con el combate tactico: el espejo se pinta en el mapa).
	_ok(Net.peleas.espejando(),
		"la pelea de la arena la ejecuta otro (anfitrion=%d)" % Net.peleas._pelea_anfitrion)
	_ok(not Game.TACTICO_EN_ARENA or (pantalla() != null and bool(pantalla().tactico)),
		"y la veo EN EL MAPA")
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
