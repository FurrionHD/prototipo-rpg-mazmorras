# LA PANTALLA DE CARGA DEL PISO (08/10, playtest: "la primera vez que me metia en el piso 6 daba un lagazo; que haya una
# pantalla de carga que cargue primero el piso entero y luego ya me deje moverme"). Sin ventana Cargando no hace nada,
# asi que aqui se fuerza (forzar_sin_ventana). Entra al piso 6 como la puerta, y baja al 7 por la escalera: en los dos
# la capa tiene que estar puesta con el juego PARADO mientras se monta, y quitarse sola soltando el juego. Y 3) la lista
# del grupo que comparten los enemigos no trae a nadie ya liberado.
#   godot --headless --path . res://tools/prueba_carga_piso.tscn
extends Node

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


# Espera a que la capa se vaya, mirando que mientras esta el juego siga parado. Devuelve los fotogramas que estuvo.
func _mientras_tapa(tope: int) -> int:
	var n: int = 0
	var siempre_parado: bool = true
	while Cargando.visible_ahora() and n < tope:
		if not get_tree().paused:
			siempre_parado = false
		await get_tree().process_frame
		n += 1
	_ver(siempre_parado, "mientras se ve la pantalla, el juego esta PARADO")
	return n


func _correr() -> void:
	Cargando.forzar_sin_ventana = true
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 4016831469

	print("1) entrar al piso 6")
	Game.current_floor = 6
	await Cargando.cubrir_piso("Piso 6")
	_ver(Cargando.visible_ahora() and get_tree().paused, "antes de cargar ya esta puesta y el juego parado")
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")
	var n: int = await _mientras_tapa(2000)
	_ver(not Cargando.visible_ahora(), "se quita sola (%d fotogramas)" % n)
	_ver(not get_tree().paused, "y suelta el juego")
	_ver(get_tree().get_first_node_in_group("dungeon_floor") != null, "el piso esta montado")

	print("2) bajar al piso 7 por la escalera")
	Game.bajar_piso()
	await get_tree().process_frame
	_ver(Cargando.visible_ahora() and get_tree().paused, "al bajar se pone y para el juego")
	n = await _mientras_tapa(2000)
	_ver(not Cargando.visible_ahora() and not get_tree().paused, "y se quita sola (%d fotogramas)" % n)
	_ver(Game.current_floor == 7, "estamos en el piso 7")

	print("3) la lista del grupo que comparten los enemigos, con alguien recien liberado")
	# Los enemigos comparten la lista del grupo por fotograma de fisica. Al cambiar de escena con el juego andando, los
	# del piso nuevo nacian en el MISMO fotograma y se encontraban el grupo del piso viejo ya liberado (SCRIPT ERROR en
	# enemy._aliado_mas_cercano, visto 19/10 con tools/medir_tirones). Depende de cuantos fotogramas de fisica caen entre
	# medias, asi que aqui se provoca a mano: uno del grupo entra en la lista y se libera en ese mismo fotograma.
	# El lanzador da la prueba por MALA si sale un SCRIPT ERROR.
	var bicho: Node = null
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.has_method("_aliados"):
			bicho = e
	_ver(bicho != null, "hay un enemigo")
	if bicho != null:
		var falso := Node2D.new()
		falso.add_to_group("aliado")
		get_tree().current_scene.add_child(falso)
		await get_tree().physics_frame
		_ver(bicho._aliados().has(falso), "el falso entra en la lista compartida")
		falso.free()
		var lista: Array = bicho._aliados()
		_ver(lista.all(func(n): return is_instance_valid(n)), "en el mismo fotograma, la lista ya no lo trae")
		bicho._aliado_mas_cercano()
		bicho._excluir_del_rayo()

	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(0 if _mal == 0 else 1)
