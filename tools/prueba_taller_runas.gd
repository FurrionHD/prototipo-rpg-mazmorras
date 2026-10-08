# HERRAMIENTA. No forma parte del juego.
#
#   godot --headless --path . res://tools/prueba_taller_runas.tscn
#
# EL TALLER DE RUNAS por dentro (08/10/2026): monta el pueblo, busca la puerta del taller, abre el menu y lo recorre
# (las dos pestañas, una pieza sin set y con set, cada accion) para cazar errores de ejecucion. No mira como se ve.
extends Node

var _mal := 0


func _ok(cond: bool, que: String) -> void:
	if cond:
		print("  ok   ", que)
	else:
		_mal += 1
		print("  MAL: ", que)


func _ready() -> void:
	var town: Node = load("res://scenes/levels/town.tscn").instantiate()
	add_child(town)
	await get_tree().process_frame
	await get_tree().process_frame
	var puerta: Node = null
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.has_method("texto_interaccion") and String(n.texto_interaccion()).contains("runas"):
			puerta = n
	_ok(puerta != null, "el pueblo tiene la puerta del taller de runas")
	var menu: Node = get_tree().get_first_node_in_group("runas_menu")
	_ok(menu != null, "el menu existe (lo crea el jugador)")
	if menu == null or puerta == null:
		_fin()
		return
	# Material para todo.
	var s: RunaSetData = Runas.set_por_id(&"slime")
	for i in 3:
		Game.almacen_materiales.append(MaterialItem.crear(s.material, MaterialItem.Calidad.NORMAL))
		Game.almacen_materiales.append(MaterialItem.crear(s.nucleo, MaterialItem.Calidad.NORMAL))
	for i in 6:
		Game.almacen_materiales.append(MaterialItem.crear(s.runa, MaterialItem.Calidad.NORMAL))
	var peto: Resource = Game.crear_item(load("res://resources/armor/cuero_pecho.tres"), 1, 0, {})
	puerta.interact_with_player()
	await get_tree().process_frame
	_ok(menu._root.visible, "F en la puerta abre el taller")
	menu._on_tab(menu.TAB_ARMADURAS)
	await get_tree().process_frame
	var i: int = menu.stacks.find(peto)
	_ok(i >= 0, "el peto sale en Armaduras")
	menu._pick(i)
	await get_tree().process_frame
	await menu._hacer(func() -> String: return Runas.activar(peto, s), "ok")
	_ok(Runas.set_de(peto) == s, "activado desde el menu")
	menu._pick(menu.stacks.find(peto))
	for k in 3:
		await menu._hacer(func() -> String: return Runas.subir(peto), "ok")
	_ok(Runas.subs_de(peto).size() == 3, "tres sub-stats desde el menu")
	menu._on_sub(1)
	await menu._hacer(func() -> String: return Runas.cambiar(peto, 1), "ok")
	await menu._hacer(func() -> String: return Runas.retirar(peto, 1), "ok")
	menu._on_tab(menu.TAB_ARMAS)
	await get_tree().process_frame
	_ok(true, "la pestaña de armas se pinta")
	var filas: Array = MenuScaffold.filas_armadura(peto, 1, 0, {})
	var tiene: bool = false
	for f in filas:
		if str(f[0]) == "Set de runas":
			tiene = true
	_ok(tiene, "la ficha del peto enseña su set")
	menu._cerrar()
	_fin()


func _fin() -> void:
	print("")
	print("FIN: TODO BIEN" if _mal == 0 else "FIN: %d MAL" % _mal)
	get_tree().quit(1 if _mal > 0 else 0)
