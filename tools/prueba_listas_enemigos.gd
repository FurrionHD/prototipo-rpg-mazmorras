# LAS LISTAS QUE COMPARTEN LOS ENEMIGOS, CON ALGUIEN RECIEN LIBERADO (19/10, era el 3 de prueba_carga_piso). Los enemigos
# comparten la lista del grupo "aliado" y la de los enemigos por fotograma de fisica (optimizacion 1E). Al cambiar de
# escena con el juego andando, los del piso nuevo nacian en el MISMO fotograma y se encontraban el grupo del piso viejo ya
# liberado (SCRIPT ERROR en enemy._aliado_mas_cercano, visto con tools/medir_tirones). Aqui se provoca a mano: uno entra en
# la lista y se libera en ese mismo fotograma. El lanzador da la prueba por MALA si sale un SCRIPT ERROR.
# Los enemigos de verdad los lleva la sala: la prueba es la sala (tools/prueba_sala_propia.gd), con el piso 1 montado.
#   godot --headless --path . res://tools/prueba_listas_enemigos.tscn
extends Node

var mi_sala = null   # su sala: tools/prueba_sala_propia.gd
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


func _correr() -> void:
	mi_sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(mi_sala)
	if not await mi_sala.arrancar("prueba_listas_enemigos", 1):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	for _i in 30:
		await get_tree().physics_frame
	var bicho: Node = null
	for e in mi_sala.piso.nodos(&"enemy"):
		if is_instance_valid(e) and e.has_method("_aliados"):
			bicho = e
	_ver(bicho != null, "hay un enemigo")
	if bicho != null:
		var falso := Node2D.new()
		falso.add_to_group("aliado")
		mi_sala.piso.add_child(falso)
		await get_tree().physics_frame
		_ver(bicho._aliados().has(falso), "el falso entra en la lista compartida")
		falso.free()
		var lista: Array = bicho._aliados()
		_ver(lista.all(func(n): return is_instance_valid(n)), "en el mismo fotograma, la lista ya no lo trae")
		bicho._aliado_mas_cercano()
		bicho._excluir_del_rayo()
		# Y LA DE LOS ENEMIGOS (optimizacion 1E, 19/10): uno pegado al bicho entra en la lista compartida, se libera en
		# ese mismo fotograma y la separacion y la manada no petan (el lanzador da MAL con un SCRIPT ERROR).
		var otro: Node2D = null
		for e in mi_sala.piso.nodos(&"enemy"):
			if e != bicho and is_instance_valid(e) and e.has_method("_aliados"):
				otro = e
		_ver(otro != null, "hay otro enemigo")
		if otro != null:
			await get_tree().physics_frame
			otro.global_position = (bicho as Node2D).global_position + Vector2(4, 0)
			_ver(bicho._enemigos().has(otro), "el otro enemigo esta en la lista compartida de enemigos")
			otro.free()
			bicho._separacion()
			bicho._companeros_de_manada()
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(0 if _mal == 0 else 1)
