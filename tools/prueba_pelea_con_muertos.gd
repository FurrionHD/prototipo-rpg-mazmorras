# NINGUNA PELEA CONTRA UN CADAVER (09/10, el 13 del playtest 08/10: en el log del hermano salia "INICIO vs Slime venenoso
# HP 0.00/101.86"; era su ESPEJO entrando en una pelea ya empezada, pero ninguna puerta de entrada miraba si el bicho
# estaba muerto). Sin ventana:
#   godot --headless --path . res://tools/prueba_pelea_con_muertos.tscn
extends Node

var sala = null   # su sala: tools/prueba_sala_propia.gd

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


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _correr() -> void:
	# EN SU SALA (etapa 4, 26/10): la prueba es la sala y la pelea se abre por donde la abre ella.
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_pelea_con_muertos", Game.PISO_ARENA):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	for k in 3:
		sala.poner("res://scenes/actors/enemy/slime_veneno.tres", Vector2(70, -40 + 40 * k), {})
	await _esperar(25)
	var bichos: Array = get_tree().get_nodes_in_group("enemy")
	_ver(bichos.size() >= 3, "hay tres venenosos (%d)" % bichos.size())
	var muerto = bichos[0]
	var vivo = bichos[1]
	var otro_muerto = bichos[2]
	muerto.morir()
	otro_muerto.morir()
	print("1) una pelea solo contra un cadaver no se abre")
	_ver(not (await sala.pelear([muerto], false) != null), "start_combat([muerto]) = no")
	await _esperar(5)
	_ver(not Game.combate_activo(), "no hay pelea")
	print("2) con un vivo y un cadaver: solo entra el vivo")
	_ver((await sala.pelear([muerto, vivo], false) != null), "se abre contra el vivo")
	await _esperar(8)
	var combat: Node = null
	for n in get_tree().root.get_children() + sala.capas():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	_ver(combat != null and combat._enemies.size() == 1 and combat._enemies[0].is_alive(),
		"un solo enemigo, vivo (%d)" % (combat._enemies.size() if combat != null else -1))
	print("3) un cadaver no se une a la pelea empezada")
	_ver(not Game.unir_enemigo_al_combate(otro_muerto), "unir_enemigo_al_combate(cadaver) = no")
	_ver(combat._enemies.size() == 1, "sigue habiendo uno")
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
