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
	# La fila de tipos: en Armaduras, "Pecho" deja solo petos.
	menu._on_sub_tipo(2)
	await get_tree().process_frame
	var solo_pechos: bool = not menu.stacks.is_empty()
	for it in menu.stacks:
		if not (it is ArmorData and int((it as ArmorData).slot) == ArmorData.Slot.PECHO):
			solo_pechos = false
	_ok(solo_pechos, "el subfiltro Pecho deja solo petos (%d)" % menu.stacks.size())
	# Filtro de set: "Sin set" quita el peto encantado.
	menu._filtros[menu._tab] = {"set": [0]}
	menu.rebuild()
	await get_tree().process_frame
	_ok(not menu.stacks.has(peto), "el filtro Sin set quita el peto con Masa gelatinosa")
	menu._filtros[menu._tab] = {}
	menu._orden[menu._tab] = {"campo": "subs", "desc": true}
	menu.rebuild()
	await get_tree().process_frame
	_ok(not menu.stacks.is_empty() and menu.stacks[0] == peto, "ordenar por sub-stats lo pone el primero")
	menu._abrir_filtros()
	await get_tree().process_frame
	_ok(menu._modal_capa != null, "el modal de filtros se abre")
	menu._cerrar_modal()
	menu._abrir_orden()
	await get_tree().process_frame
	menu._cerrar_modal()
	menu._on_tab(menu.TAB_ARMAS)
	await get_tree().process_frame
	_ok(true, "la pestaña de armas se pinta")
	menu._on_sub_tipo(1)
	await get_tree().process_frame
	var solo_dagas: bool = true
	for it in menu.stacks:
		if not (it is WeaponData and int((it as WeaponData).tipo) == WeaponData.Tipo.DAGA):
			solo_dagas = false
	_ok(solo_dagas, "el subfiltro Daga deja solo dagas (%d)" % menu.stacks.size())
	# EL BLOQUE DE RUNAS de las fichas (personaje, inventario, tienda, hogar, herreria, combate).
	var vb := VBoxContainer.new()
	MenuScaffold.bloque_runas(vb, peto)
	var textos: String = ""
	for n in vb.find_children("*", "Label", true, false):
		textos += (n as Label).text + "\n"
	_ok(textos.contains("SET MASA GELATINOSA"), "la ficha del peto enseña su set")
	_ok(textos.contains("2 piezas:") and textos.contains("5 piezas:"), "y lo que hace a 2 y a 5 piezas")
	_ok(textos.contains("En el baúl"), "en el baul dice que no cuenta hasta que alguien se la pone")
	vb.free()
	# Puesta: 1/5 en GRIS (aun no da nada); con dos piezas, 2/5 y el bonus de 2 en VERDE.
	var pj: PersonajeData = Game.lider()
	var guardado: Array = [pj.equipped_pecho, pj.equipped_casco]
	pj.equipped_pecho = peto
	pj.equipped_casco = null
	var vb2 := VBoxContainer.new()
	MenuScaffold.resumen_sets(vb2, pj, RunaSetData.Tipo.ARMADURA, false)
	var l1: Label = vb2.find_children("*", "Label", true, false)[0]
	_ok(l1.text.contains("1/5") and l1.get_theme_color("font_color") == MenuScaffold.RUNA_GRIS, "puesta sola: 1/5 en gris")
	vb2.free()
	var casco: Resource = Game.crear_item(load("res://resources/armor/cuero_casco.tres"), 1, 0, {})
	Game.meta_de(casco)["runas"] = {"set": "slime", "subs": []}
	pj.equipped_casco = casco
	var vb3 := VBoxContainer.new()
	MenuScaffold.resumen_sets(vb3, pj, RunaSetData.Tipo.ARMADURA, false)
	var l2: Label = vb3.find_children("*", "Label", true, false)[0]
	_ok(l2.text.contains("2/5") and l2.get_theme_color("font_color") == MenuScaffold.RUNA_VERDE, "con dos piezas: 2/5 en verde")
	vb3.free()
	pj.equipped_pecho = guardado[0]
	pj.equipped_casco = guardado[1]
	menu._cerrar()
	_fin()


func _fin() -> void:
	print("")
	print("FIN: TODO BIEN" if _mal == 0 else "FIN: %d MAL" % _mal)
	get_tree().quit(1 if _mal > 0 else 0)
