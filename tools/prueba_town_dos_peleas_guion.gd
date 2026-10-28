# DOS PELEAS A LA VEZ EN LA SALA (fase 2, etapa 3, pasos 3-4). Ya no hay trabajadores de pelea: la sala monta cada pelea
# colgada del piso de sus enemigos y los dos jugadores la ven en espejo. Guion de A (el proceso de la prueba); el de B
# en prueba_town_dos_peleas_b_guion.gd. Lo de la sala, en sus lineas "[S] dato".
#   1) A y B en el piso 1, cada uno pelea con un enemigo distinto, a la vez: la sala lleva DOS peleas en el piso 1.
#      Las dos acaban, la sala se queda sin peleas y sin reservas.
#   2) B entra en la pelea de A pegandole a uno de sus enemigos: UNA pelea, el mismo id para los dos. RESERVAR AL PULSAR
#      (paso 5): A abre la suya con un espadazo de 0,6 s y B entra con otro: a los dos se les abre la pantalla AL TOCAR
#      el golpe (no antes, y casi nada despues: los viajes van durante el espadazo).
#   3) B baja al 2. A mi me EMBISTE un enemigo sin que yo ataque (el empuje en la sala, que rebotaba) mientras B pelea
#      en el 2: una pelea en cada piso.
#   4) B se cae a mitad de su pelea: su pelea sigue sola (cortesia) mientras yo peleo la mia, y al final la sala se
#      queda sin peleas y sin reservas.
# Cubre: net_peleas.gd (_abre_en_la_sala, _pe_de_peer, _pedir_unirme por id, empujar_pelea, marcar_caido por pelea,
# _cierre_de, cerrar_pelea en la sala, ids en el espejo), pelea_viva.gd, game.gd (pantalla y cierre en la sala).
# Se lanza con:  <godot> --headless --path . res://tools/prueba_town_dos_peleas.tscn -- nube_local
extends "res://tools/prueba_town_sala_comun.gd"


func _ready() -> void:
	slot = 81
	puerto = 24617
	registro_b = "user://logs/prueba_town_dos_peleas_b.log"
	if not await empezar("prueba_town_dos_peleas_b"):
		await _fin()
		return
	await _guion()
	await _fin()


func _hasta(cond: Callable, tope: float) -> bool:
	var t := 0.0
	while not cond.call() and t < tope:
		await _esperar(0.25)
		t += 0.25
	return cond.call()


func _sala_limpia(que: String) -> void:
	# Mientras espero me puede saltar otro bicho del grupo, y esa pelea no se cierra si no la juego (23/10, bateria
	# entera: la sala se quedaba con 2). La acabo y sigo esperando.
	var t := 0.0
	while dato_sala("peleas") != "0" and t < 120.0:
		await acabar_pelea_suelta()
		await _esperar(0.25)
		t += 0.25
	_ok(dato_sala("peleas") == "0", "la sala cierra %s (%s)" % [que, dato_sala("peleas")])
	_ok(await hasta_sala("reservas", func(v): return v == "0", 10.0), "y no le quedan reservas (%s)" % dato_sala("reservas"))


func _en_espejo_de_la_sala(que: String) -> void:
	_ok(Game.hay_pelea_en_pantalla() and Net.peleas.espejando(), "tengo mi pelea en ESPEJO (%s)" % que)
	_ok(Net.peleas._pelea_id == 0 and Net.peleas.ejecutor_de(Net.peleas._pelea_sigo) == 1,
		"la ejecuta la sala (pelea %d)" % Net.peleas._pelea_sigo)


# 1) Elijo un enemigo, se lo digo a B (para que coja otro lejos de el), y peleamos a la vez.
func _a_la_vez(fase: int, lugares: String) -> void:
	await acabar_pelea_suelta()
	var presa: Node2D = enemigo_libre()
	_ok(presa != null, "hay un enemigo libre para mi (fase %d)" % fase)
	if presa == null:
		return
	escribir_fase(fase, [int(presa.get_meta("net_id"))])
	await pelear_con(presa)
	_en_espejo_de_la_sala("fase %d" % fase)
	_ok(await hasta_sala("peleas", func(v): return v == "2", 20.0),
		"la sala lleva DOS peleas a la vez (%s)" % dato_sala("peleas"))
	_ok(dato_sala("peleas_lugares") == lugares, "en %s (%s)" % [lugares, dato_sala("peleas_lugares")])
	_ok(await pelear_hasta_el_final(90.0), "gano mi pelea (fase %d)" % fase)
	await _sala_limpia("las dos")


# Le pego con un espadazo de 'golpe' segundos y mido cuanto tarda en abrirse mi pantalla.
func _al_pulsar(presa: Node2D, golpe: float) -> float:
	var jugador: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	jugador.recolocar(presa.global_position + Vector2(40, 0))
	var t0: int = Time.get_ticks_msec()
	presa.atacado_por_jugador(golpe)
	await _hasta(func(): return Game.hay_pelea_en_pantalla(), 10.0)
	return float(Time.get_ticks_msec() - t0) / 1000.0


# 2) B entra en mi pelea. La mia la abro con un espadazo de 0,6 s: la pantalla, al tocar.
func _b_se_une(fase: int) -> void:
	var presa: Node2D = enemigo_libre()
	_ok(presa != null, "hay un enemigo libre para mi (fase %d)" % fase)
	if presa == null:
		return
	var t: float = await _al_pulsar(presa, 0.6)
	_ok(t >= 0.5 and t <= 1.0, "RESERVAR AL PULSAR: mi pantalla se abre al tocar el golpe de 0,6 s (a los %.2f s)" % t)
	_en_espejo_de_la_sala("fase %d" % fase)
	var mia: int = Net.peleas._pelea_sigo
	escribir_fase(fase, [int(presa.get_meta("net_id"))])
	_ok(await _hasta(func(): return int(_linea(_texto(registro_b), "[B] dato pelea_unida", "0")) != 0, 30.0),
		"B entra en una pelea")
	var la_de_b: int = int(_linea(_texto(registro_b), "[B] dato pelea_unida", "0"))
	_ok(la_de_b == mia, "B esta en MI pelea (la suya %d, la mia %d)" % [la_de_b, mia])
	_ok(dato_sala("peleas") == "1", "la sala lleva UNA pelea (%s)" % dato_sala("peleas"))
	_ok(await pelear_hasta_el_final(90.0), "ganamos la pelea (fase %d)" % fase)
	await _sala_limpia("la pelea de los dos")


# 3) Me pongo al lado de un enemigo y NO le ataco: me tiene que embestir el y abrirse la pelea.
func _me_embisten(fase: int) -> void:
	escribir_fase(fase)   # B pelea en el 2 a la vez
	await acabar_pelea_suelta()
	var presa: Node2D = enemigo_libre()
	var jugador: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	_ok(presa != null and jugador != null, "hay un enemigo libre para mi (fase %d)" % fase)
	if presa == null or jugador == null:
		return
	jugador.recolocar(presa.global_position + Vector2(30, 0))
	_ok(await _hasta(func(): return Game.hay_pelea_en_pantalla(), 20.0),
		"un enemigo me embiste y se abre la pelea SIN que yo ataque")
	if not Game.hay_pelea_en_pantalla():
		# (28/10) Paso 1 vez de 10 con carga y no se sabe si es el juego: quien era y donde.
		print("[dev] NO ME EMBISTE: %s (net_id %s) en %s, yo en %s (a %.0f px), pelea_de %s" % [
			presa.get("nombre") if presa.get("nombre") != null else presa.name, str(presa.get_meta("net_id", -1)),
			str(presa.global_position.round()), str(jugador.global_position.round()),
			presa.global_position.distance_to(jugador.global_position), str(presa.get("pelea_de"))])
		await pelear_con(presa)   # para seguir con lo demas
	else:
		_ok(Net.peleas._fichas_emboscada, "como emboscada")
	_en_espejo_de_la_sala("fase %d" % fase)
	_ok(await hasta_sala("peleas_lugares", func(v): return v == "piso:1,piso:2", 30.0),
		"una pelea en cada piso (%s)" % dato_sala("peleas_lugares"))
	_ok(await pelear_hasta_el_final(90.0), "gano mi pelea (fase %d)" % fase)
	await _sala_limpia("las dos")


# 4) B se cae a mitad de su pelea; yo peleo a la vez.
func _b_se_cae(fase: int) -> void:
	escribir_fase(fase)
	_ok(await hasta_sala("peleas_lugares", func(v): return v == "piso:2", 40.0), "B esta peleando en el 2")
	_ok(await hasta_sala("humanos", func(v): return v == "1", 40.0), "B se cae (humanos: %s)" % dato_sala("humanos"))
	_ok(await _hasta(func(): return _texto(registro_sala).contains("se ha desconectado: sus personajes siguen"), 10.0),
		"su pelea sigue sola (cortesia)")
	var presa: Node2D = enemigo_libre()
	_ok(presa != null, "hay un enemigo libre para mi (fase %d)" % fase)
	if presa != null:
		await pelear_con(presa)
		_en_espejo_de_la_sala("fase %d" % fase)
		_ok(await pelear_hasta_el_final(90.0), "gano mi pelea mientras la de B sigue sola")
	# Al pueblo, que quieto en el piso me embiste otro grupo y me abre otra pelea.
	Net.pisos.viajar_al_pueblo()
	await _hasta(func(): return Net._mi_lugar == "pueblo", 20.0)
	if dato_sala("peleas") != "0":
		_ok(dato_sala("montados").split(",").has("2"), "el 2 no se congela con la pelea de B dentro (%s)" % dato_sala("montados"))
	await _sala_limpia("tambien la de B (cortesia vencida o pelea acabada)")
	_ok(await hasta_sala("montados", func(v): return not v.split(",").has("2"), 30.0),
		"y despues el 2 se congela (montados: %s)" % dato_sala("montados"))


func _guion() -> void:
	Net.pisos.solicitar_entrar(1)
	_ok(await _hasta(func(): return Net._mi_lugar == "piso:1" and get_tree().get_first_node_in_group("dungeon_floor") != null, 40.0),
		"bajo al piso 1")
	escribir_fase(1)
	_ok(await hasta_sala("piso_" + IDENT_B, func(v): return v == "1", 60.0), "B llega al piso 1")
	await _hasta(func(): return enemigo_libre() != null, 15.0)
	await _esperar(2.0)
	await _a_la_vez(2, "piso:1,piso:1")
	await _b_se_une(3)

	escribir_fase(4)   # B baja al 2
	_ok(await hasta_sala("piso_" + IDENT_B, func(v): return v == "2", 60.0), "B llega al piso 2")
	await _esperar(2.0)
	await _me_embisten(5)
	await _b_se_cae(6)

	Net.pisos.viajar_al_pueblo()
	await _hasta(func(): return Net._mi_lugar == "pueblo", 20.0)
