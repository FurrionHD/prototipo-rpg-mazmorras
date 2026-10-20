# LA PELEA DE OTRO VISTA DESDE FUERA, CON DOS JUGADORES DE VERDAD (11/10), guion de A. B se queda LEJOS (fuera de
# la zona y a mas de 320 px del golpe) y yo abro una pelea en la arena:
#   - B NO se queda quieto (esta lejos) y VE mi zona en su suelo;
#   - B anda hacia mi: la linea le FRENA, le sale la pregunta y dice que SI;
#   - B entra en mi pelea.
# El caso de "B esta dentro al empezar y entra solo" lo mira ya prueba_town_tactico (B empieza a mi lado).
# POR LA SALA (fase 2, paso 6): A y B entran como clientes en la sala de la RANURA 88 (ver prueba_town_sala_comun.gd).
#   godot --headless --path . res://tools/prueba_town_zona_ajena.tscn -- nube_local
extends "res://tools/prueba_town_sala_comun.gd"


func _ready() -> void:
	prefijo = ""
	slot = 88
	puerto = 24613
	registro_b = "user://logs/prueba_zona_ajena_b.log"
	falta_b = -1
	escribir_fase(0)
	if not await empezar("prueba_town_zona_ajena_b"):
		await _fin()
		return

	Game.entrar_arena_de_pruebas()
	escribir_fase(1)
	var t := 0.0
	while (Net._mi_lugar != "piso:%d" % Game.PISO_ARENA or piso_de_b() != Game.PISO_ARENA) and t < 40.0:
		await _esperar(0.5)
		t += 0.5
	_ok(piso_de_b() == Game.PISO_ARENA, "los dos estamos en la arena (%.1f s)" % t)
	await _esperar(3.0)
	var yo: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime.tres", yo.global_position + Vector2(0, 130), {})
	t = 0.0
	while Net.enemigos._enem_nodos.size() + Net.enemigos._enemigos.size() < 1 and t < 15.0:
		await _esperar(0.25)
		t += 0.25
	var presa: Node2D = enemigo_libre()
	_ok(presa != null, "hay un slime en la arena")
	if presa == null:
		await _fin()
		return
	# B se coloca LEJOS de donde voy a pegar (pelear_con me pone a 40 px a la derecha del slime).
	var donde: Vector2 = presa.global_position + Vector2(40, 0)
	escribir_fase(2, [int(donde.x), int(donde.y)])
	_ok(await _dato_de_b("colocado", 20.0) == 1, "B se ha colocado lejos")

	await pelear_con(presa)
	var p: Node = pantalla()
	_ok(p != null and bool(p.tactico), "abro la pelea EN EL MAPA")
	if p == null:
		await _fin()
		return
	escribir_fase(3)
	_ok(not _b_en_pelea(p), "B, lejos, NO entra solo")
	_ok(await _dato_de_b("quieto_lejos", 15.0) == 0, "B, lejos, no se queda quieto al golpe")
	_ok(await _dato_de_b("ve_zona", 5.0) == 1, "B ve mi zona en su suelo")
	_ok(await _dato_de_b("frenado", 40.0) == 1, "la linea frena a B")
	_ok(await _dato_de_b("pregunta", 5.0) == 1, "a B le sale la pregunta al chocar")
	# Mientras B decide y entra, juego mis turnos (Defender) para que la pelea no se pare en el mio.
	t = 0.0
	while not _b_en_pelea(p) and t < 40.0:
		pulsar(3)
		await _esperar(0.25)
		t += 0.25
	_ok(_b_en_pelea(p), "con el Si, B entra en mi pelea (%.1f s)" % t)
	_ok(await _dato_de_b("espejo", 20.0) == 1, "B ve la pelea desde dentro (espejo)")
	await _fin()


func _b_en_pelea(p: Node) -> bool:
	if not is_instance_valid(p):
		return false
	for fila in p.turno_mapa.roster_red.get("aliados", []):
		if int((fila as Dictionary).get("peer", 0)) == _b():
			return true
	return false
