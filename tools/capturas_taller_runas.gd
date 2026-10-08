# HERRAMIENTA. No forma parte del juego. CON VENTANA (las capturas necesitan pintar):
#
#   godot --path . res://tools/capturas_taller_runas.tscn
#
# Capturas del TALLER DE RUNAS (08/10/2026) para que el usuario vea el menu: una pieza sin set (eligiendo set), una con
# set y sub-stats, y la pestaña de armas. Las deja en el Escritorio, carpeta taller_runas.
extends Node

const CARPETA := "C:/Users/dasui/Desktop/taller_runas"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA)
	var town: Node = load("res://scenes/levels/town.tscn").instantiate()
	add_child(town)
	for i in 10:
		await get_tree().process_frame
	var menu: Node = get_tree().get_first_node_in_group("runas_menu")
	# Material de sobra de los sets de slime y fuego, y piezas para enseñar.
	for id in [&"slime", &"fuego"]:
		var s: RunaSetData = Runas.set_por_id(id)
		for k in 3:
			Game.almacen_materiales.append(MaterialItem.crear(s.material, MaterialItem.Calidad.NORMAL))
			Game.almacen_materiales.append(MaterialItem.crear(s.nucleo, MaterialItem.Calidad.NORMAL))
		for k in 5:
			Game.almacen_materiales.append(MaterialItem.crear(s.runa, MaterialItem.Calidad.NORMAL))
	var peto_libre: Resource = Game.crear_item(load("res://resources/armor/cuero_pecho.tres"), 1, 2, {})
	var peto_set: Resource = Game.crear_item(load("res://resources/armor/hierro_pecho.tres"), 2, 3, {})
	Game.meta_de(peto_set)["runas"] = {"set": "slime", "subs": [{"s": "vida_pct", "v": 0.062},
		{"s": "res_fuego", "v": 0.041}, {"s": "vida_pct", "v": 0.038}]}
	var espada: Resource = Game.crear_item(load("res://resources/weapons/espada_larga.tres"), 1, 1, {})
	menu.abrir()
	menu._on_tab(menu.TAB_ARMADURAS)
	await _foto(menu, peto_libre, "1_armadura_sin_set")
	await _foto(menu, peto_set, "2_armadura_con_set")
	menu._abrir_filtros()
	await _foto(menu, peto_set, "5_filtros", false)
	menu._cerrar_modal()
	menu._on_tab(menu.TAB_ARMAS)
	await _foto(menu, espada, "3_arma_sin_set")
	menu._on_set(1)
	await _foto(menu, espada, "4_arma_otro_set", false)
	menu._cerrar()
	print("[capturas] en ", CARPETA)
	get_tree().quit()


func _foto(menu: Node, item: Resource, nombre: String, elegir: bool = true) -> void:
	if elegir:
		var i: int = menu.stacks.find(item)
		if i >= 0:
			menu._pick(i)
	for k in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [CARPETA, nombre])
