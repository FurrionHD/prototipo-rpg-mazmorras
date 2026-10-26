# EL JUGADOR NO SE MONTA EN LOS ENEMIGOS (13/10, lo destapo prueba_zona_ajena). El jugador estaba en el modo de
# movimiento de los juegos de plataformas: un enemigo pegado por DEBAJO contaba como suelo y, al teletransportarse,
# le pasaba su velocidad (~10.000 px/s) y lo estampaba contra la pared. Mira, en un piso de verdad y sin teclas:
#   1) el jugador va FLOTANDO, como enemigos y compañeros;
#   2) con un enemigo pegado justo debajo y luego mandado lejos, el jugador no se mueve.
#   godot --headless --path . res://tools/prueba_jugador_no_monta.tscn -- nube_local
extends Node

var j = null   # el jugador con su sala: tools/prueba_con_jugador.gd

var _mal: int = 0


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _fisica(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame
	await get_tree().process_frame


func _correr() -> void:
	# EL JUGADOR CON SU SALA (etapa 4, 26/10): como se mueve tu cuerpo es cosa de tu maquina, con los enemigos como te
	# los manda la sala (tools/prueba_con_jugador.gd).
	j = preload("res://tools/prueba_con_jugador.gd").new()
	add_child(j)
	if not await j.arrancar("prueba_jugador_no_monta", 75, 1):
		print("MAL: no arranca la sala o no entro")
		await j.cerrar()
		get_tree().quit(1)
		return
	for _i in 30:
		await get_tree().process_frame
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	var gen: DungeonGenerator = piso.gen
	var sala := Rect2i()
	for z in gen.zonas:
		if String(z["tipo"]) == "sala" and (z["rect"] as Rect2i).get_area() > sala.get_area():
			sala = z["rect"]
	var jug: CharacterBody2D = get_tree().get_first_node_in_group("player") as CharacterBody2D
	var enemigos: Array = get_tree().get_nodes_in_group("enemy")
	for e in enemigos:
		(e as Node2D).global_position = Vector2(-9999, -9999)
		(e as Node).set_physics_process(false)   # quietos: los colocamos a mano
	var centro: Vector2 = gen.centro_px(sala.position + sala.size / 2)
	jug.global_position = centro
	await _fisica(3)

	print("1) modo de movimiento")
	_ver(jug.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING, "el jugador va flotando (%d)" % jug.motion_mode)

	print("2) un enemigo pegado debajo que se teletransporta")
	_ver(not enemigos.is_empty(), "hay enemigos en el piso (%d)" % enemigos.size())
	if not enemigos.is_empty():
		var e1: Node2D = enemigos[0]
		# Pegado por debajo a varias distancias (rozando, un pelin metido...): en alguna queda "apoyado" en el.
		var peor: float = 0.0
		for dy in [18.0, 19.0, 20.0, 21.0, 22.0]:
			jug.global_position = centro
			e1.global_position = Vector2(-9999, -9999)
			await _fisica(2)
			e1.global_position = centro + Vector2(0, dy)
			await _fisica(3)
			var tras_tocar: Vector2 = jug.global_position
			e1.global_position = Vector2(-9999, -9999)
			await _fisica(4)
			var d: float = jug.global_position.distance_to(tras_tocar)
			print("    a %d px: me muevo %.1f px al irse" % [int(dy), d])
			peor = maxf(peor, d)
		_ver(peor < 4.0, "se va lejos y yo me quedo (lo peor: %.1f px)" % peor)

	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	await j.cerrar()
	get_tree().quit(1 if _mal > 0 else 0)
