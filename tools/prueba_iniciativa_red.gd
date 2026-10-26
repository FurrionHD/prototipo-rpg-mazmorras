# QUIEN EMPIEZA LA PELEA EN MULTI (12/10, playtest 11/10: "considera que es el enemigo el que me entra en combate en
# vez de yo, que he sido el primero en hacer el golpe"). En multi el piso lo simula un trabajador, que no tiene
# jugador local: los jugadores son remote_player. El bicho que alcanza a uno de ellos le EMPUJA la pelea, y hasta
# ahora siempre con emboscada (iniciativa del enemigo), aunque ese jugador ya le estuviera soltando el espadazo.
# Sin red: un remote_player de verdad delante de un enemigo de verdad, y se mira lo que contesta el enemigo:
#   1) parado y sin golpear: NO es un contra (el golpe del bicho es emboscada);
#   2) golpeando HACIA el bicho: SI es un contra (la pelea la empieza el jugador);
#   3) golpeando hacia el otro lado: no;
#   4) golpeando pero lejos: no;
#   5) mientras golpea, su muñeco mira a donde pega (el facing que manda su dueño), no a donde anduvo.
#   godot --headless --path . res://tools/prueba_iniciativa_red.tscn
extends Node

var mi_sala = null   # su sala: tools/prueba_sala_propia.gd

var _mal: int = 0
const _REMOTO := preload("res://scripts/actors/player/remote_player.gd")


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


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	# EN SU SALA (etapa 4, 26/10): la prueba es la sala, con el piso montado como lo monta ella.
	mi_sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(mi_sala)
	if not await mi_sala.arrancar("prueba_iniciativa_red", 1, 424242, false):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	await _esperar(30)
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	var gen: DungeonGenerator = piso.gen
	var sala := Rect2i()
	for z in gen.zonas:
		if String(z["tipo"]) == "sala" and (z["rect"] as Rect2i).get_area() > sala.get_area():
			sala = z["rect"]
	var centro: Vector2 = gen.centro_px(sala.position + sala.size / 2)
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	jug.global_position = centro + Vector2(0, 600)   # el jugador local, lejos: aqui no pinta nada
	var enemigos: Array = get_tree().get_nodes_in_group("enemy")
	if enemigos.is_empty():
		print("MAL: no hay ningun enemigo en el piso")
		get_tree().quit(1)
		return
	var bicho: Node2D = enemigos[0]
	for e in enemigos:
		if e != bicho:
			(e as Node2D).global_position = Vector2(-9999, -9999)
	bicho.set_physics_process(false)   # quieto: se mira lo que contesta, no lo que haria
	bicho.global_position = centro

	var av: Node2D = _REMOTO.new()
	piso.get_parent().add_child(av)
	av.set_meta("peer_id", 77)
	await _esperar(2)
	# A su izquierda, pegado: 20 px de hueco entre las cajas.
	var caja_b: Rect2 = Cuerpos.caja_de(bicho)
	var caja_a: Rect2 = av.caja_cuerpo()
	av.global_position = Vector2(caja_b.position.x - 20.0 - caja_a.end.x, centro.y - caja_a.get_center().y)
	av.ir_a(av.global_position)
	await _esperar(2)
	print("hueco entre los dos: %.1f px" % Cuerpos.hueco(av, bicho))

	print("1) parado y sin golpear")
	av.fijar_mirada_red(Vector2.RIGHT)
	_ver(not bicho._es_contra(av), "no es un contra: el golpe del bicho seria emboscada")

	print("2) soltando un espadazo HACIA el bicho")
	av._golpe_t = 0.5
	_ver(bicho._es_contra(av), "es un contra: la pelea la empieza el jugador")

	print("3) soltando el espadazo hacia el otro lado")
	av.fijar_mirada_red(Vector2.LEFT)
	_ver(not bicho._es_contra(av), "de espaldas: no")

	print("4) golpeando hacia el, pero lejos")
	av.fijar_mirada_red(Vector2.RIGHT)
	av.global_position += Vector2(-120, 0)
	av.ir_a(av.global_position)
	_ver(not bicho._es_contra(av), "a 140 px: no")

	print("5) su muñeco mira a donde pega")
	av.global_position += Vector2(120, 0)
	av.ir_a(av.global_position + Vector2(0, -40))   # se desliza un poco hacia arriba (lo ultimo que anduvo)
	av.fijar_mirada_red(Vector2.RIGHT)
	av._golpe_t = 0.5
	await _esperar(3)
	_ver(av._facing.is_equal_approx(Vector2.RIGHT), "golpeando: mira a la derecha (%s)" % str(av._facing))

	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
