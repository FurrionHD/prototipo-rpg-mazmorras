# DOS PELEAS A LA VEZ EN LA SALA (fase 2, etapa 3, paso 3). Ya no hay trabajadores de pelea: la sala monta cada pelea
# colgada del piso de sus enemigos y los dos jugadores la ven en espejo. Guion de A (el proceso de la prueba); el de B
# en prueba_town_dos_peleas_b_guion.gd. Lo de la sala, en sus lineas "[S] dato".
#   1) A y B en el piso 1, cada uno pelea con un enemigo distinto, a la vez: la sala lleva DOS peleas en el piso 1.
#      Las dos acaban, la sala se queda sin peleas y sin reservas.
#   2) B baja al 2 y otra vez a la vez: una pelea en el 1 y otra en el 2.
# Cubre: net_peleas.gd (_abre_en_la_sala, _pe_de_peer, _cierre_de, cerrar_pelea en la sala, ids de pelea en el espejo),
# pelea_viva.gd, game.gd (_montar_pantalla_combate y _on_combat_finished en la sala).
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


# Una ronda: elijo un enemigo, se lo digo a B (para que coja otro lejos de el), y peleamos a la vez.
func _ronda(fase: int, lugares: String) -> void:
	var presa: Node2D = enemigo_libre()
	_ok(presa != null, "hay un enemigo libre para mi (ronda %d)" % fase)
	if presa == null:
		return
	escribir_fase(fase, [int(presa.get_meta("net_id"))])
	await pelear_con(presa)
	_ok(Game.hay_pelea_en_pantalla() and Net.peleas.espejando(), "tengo mi pelea en ESPEJO (ronda %d)" % fase)
	_ok(Net.peleas._pelea_id == 0 and Net.peleas.ejecutor_de(Net.peleas._pelea_sigo) == 1,
		"la ejecuta la sala (pelea %d)" % Net.peleas._pelea_sigo)
	_ok(await hasta_sala("peleas", func(v): return v == "2", 20.0),
		"la sala lleva DOS peleas a la vez (%s)" % dato_sala("peleas"))
	_ok(dato_sala("peleas_lugares") == lugares, "en %s (%s)" % [lugares, dato_sala("peleas_lugares")])
	_ok(await pelear_hasta_el_final(90.0), "gano mi pelea (ronda %d)" % fase)
	_ok(await hasta_sala("peleas", func(v): return v == "0", 60.0), "la sala cierra las dos (%s)" % dato_sala("peleas"))
	_ok(await hasta_sala("reservas", func(v): return v == "0", 10.0), "y no le quedan reservas (%s)" % dato_sala("reservas"))


func _guion() -> void:
	# --- 1) Los dos en el piso 1 ---
	Net.pisos.solicitar_entrar(1)
	_ok(await _hasta(func(): return Net._mi_lugar == "piso:1" and get_tree().get_first_node_in_group("dungeon_floor") != null, 40.0),
		"bajo al piso 1")
	escribir_fase(1)
	_ok(await hasta_sala("piso_" + IDENT_B, func(v): return v == "1", 60.0), "B llega al piso 1")
	await _hasta(func(): return enemigo_libre() != null, 15.0)
	await _esperar(2.0)
	await _ronda(2, "piso:1,piso:1")

	# --- 2) B baja al 2: una pelea en cada piso ---
	escribir_fase(3)
	_ok(await hasta_sala("piso_" + IDENT_B, func(v): return v == "2", 60.0), "B llega al piso 2")
	await _esperar(2.0)
	await _ronda(4, "piso:1,piso:2")

	Net.pisos.viajar_al_pueblo()
	await _hasta(func(): return Net._mi_lugar == "pueblo", 20.0)
