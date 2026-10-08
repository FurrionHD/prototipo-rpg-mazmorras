# HERRAMIENTA. No forma parte del juego. CON VENTANA:
#
#   godot --path . res://tools/capturas_herreria_mejorar.tscn
#
# Captura de la ficha de MEJORAR de la herreria con una daga +15 con runas (08/10/2026: en dos columnas). Escritorio,
# carpeta taller_runas.
extends Node

const CARPETA := "C:/Users/dasui/Desktop/taller_runas"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA)
	var town: Node = load("res://scenes/levels/town.tscn").instantiate()
	add_child(town)
	for i in 10:
		await get_tree().process_frame
	var pj: PersonajeData = Game.lider()
	var d1: Resource = Game.crear_item(load("res://resources/weapons/daga.tres"), 1, 3, {"precision": 1})
	Game.meta_de(d1)["runas"] = {"set": "venenoso", "subs": [{"s": "crit", "v": 0.036}, {"s": "penetracion", "v": 0.084},
		{"s": "dano_jefes", "v": 0.197}, {"s": "crit_dmg", "v": 0.179}]}
	pj.equipped_main = d1
	var menu: Node = get_tree().get_first_node_in_group("forge_menu")
	menu.abrir()
	await _esperar()
	menu._on_tab(5)   # Mejorar
	await _esperar()
	menu._pick(maxi(0, menu.stacks.find(d1)))
	await _esperar()
	menu.mejorar._on_cat(3)   # Eficacia: tiene que verse cuanta tiene y lo que sube
	await _esperar()
	get_viewport().get_texture().get_image().save_png("%s/10_herreria_mejorar.png" % CARPETA)
	print("[capturas] en ", CARPETA)
	get_tree().quit()


func _esperar() -> void:
	for k in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
