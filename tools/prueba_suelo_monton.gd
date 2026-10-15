# Cubre: res://scripts/world/dungeon_floor.gd res://scripts/items/drop_pickup.gd
# EL MONTON DEL SUELO CONSERVA SU CANTIDAD (auditoria 13/10). Un pickup puede ser un monton (las flechas que se
# recuperan caen juntas: DropPickup.cantidad), pero el piso guardaba solo {item, pos}: al volver al piso o al
# cargar la partida el monton de 7 volvia como 1. La prueba vuelca el piso a la memoria, quita el monton y lo
# rehace desde la memoria, como al volver.
#   godot --headless --path . res://tools/prueba_suelo_monton.tscn
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


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 4016831469
	Game.current_floor = 1
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")
	var piso: Node = null
	for i in 600:
		await get_tree().process_frame
		piso = get_tree().get_first_node_in_group("dungeon_floor")
		if piso != null and not get_tree().paused and get_tree().get_first_node_in_group("player") != null:
			break
	if piso == null:
		_ver(false, "el piso se monta")
		_fin()
		return
	for i in 10:
		await get_tree().process_frame

	var item := MaterialItem.crear(load("res://resources/materials/acero.tres"), MaterialItem.Calidad.NORMAL)
	var monton: Node2D = (load("res://scripts/items/drop_pickup.gd") as Script).new()
	monton.setup(item, 7)
	piso.get_parent().add_child(monton)
	var donde: Vector2 = (get_tree().get_first_node_in_group("player") as Node2D).global_position + Vector2(0, 300)
	monton.global_position = donde
	await get_tree().process_frame

	piso.volcar_a_memoria()
	var mem: Dictionary = Game.memoria_pisos.get(Game.current_floor, {})
	var en_memoria: Array = (mem.get("suelo", []) as Array).filter(func(d): return d.get("item") == item)
	_ver(en_memoria.size() == 1, "el monton esta en la memoria del piso")

	# Como al volver al piso: fuera los del suelo y se rehacen desde la memoria
	for p in get_tree().get_nodes_in_group("pickup"):
		p.remove_from_group("pickup")
		p.queue_free()
	await get_tree().process_frame
	piso.adoptar_foto(mem)
	await get_tree().process_frame
	var vuelto: Node = null
	for p in get_tree().get_nodes_in_group("pickup"):
		if p.item == item:
			vuelto = p
	_ver(vuelto != null, "el monton vuelve")
	if vuelto != null:
		_ver(int(vuelto.cantidad) == 7, "y vuelve con sus 7 (sale %d)" % int(vuelto.cantidad))
		_ver((vuelto as Node2D).global_position.distance_to(donde) < 1.0, "en su sitio")
	_fin()


func _fin() -> void:
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(0 if _mal == 0 else 1)
