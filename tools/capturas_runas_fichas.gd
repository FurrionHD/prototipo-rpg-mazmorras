# HERRAMIENTA. No forma parte del juego. CON VENTANA (las capturas necesitan pintar):
#
#   godot --path . res://tools/capturas_runas_fichas.tscn
#
# Capturas de las RUNAS en las fichas (08/10/2026): el menu de personaje en Armas (dos dagas con Miasma: 2/2 en verde),
# Armadura (una pieza de slime: 1/5 en gris), la Ficha (resumen de sets) y el modal de Información de la pieza.
# En el Escritorio, carpeta taller_runas.
extends Node

const CARPETA := "C:/Users/dasui/Desktop/taller_runas"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA)
	var town: Node = load("res://scenes/levels/town.tscn").instantiate()
	add_child(town)
	for i in 10:
		await get_tree().process_frame
	var pj: PersonajeData = Game.lider()
	var d1: Resource = Game.crear_item(load("res://resources/weapons/daga.tres"), 3, 7, {})
	var d2: Resource = Game.crear_item(load("res://resources/weapons/daga.tres"), 3, 7, {})
	Game.meta_de(d1)["runas"] = {"set": "venenoso", "subs": [{"s": "crit", "v": 0.036}, {"s": "penetracion", "v": 0.084},
		{"s": "dano_jefes", "v": 0.197}, {"s": "crit_dmg", "v": 0.179}]}
	Game.meta_de(d2)["runas"] = {"set": "venenoso", "subs": [{"s": "ataque_pct", "v": 0.07}]}
	var peto: Resource = Game.crear_item(load("res://resources/armor/hierro_pecho.tres"), 2, 3, {})
	Game.meta_de(peto)["runas"] = {"set": "slime", "subs": [{"s": "vida_pct", "v": 0.062}, {"s": "res_fuego", "v": 0.041}]}
	pj.equipped_main = d1
	pj.equipped_off = d2
	pj.equipped_pecho = peto
	var menu: Node = get_tree().get_first_node_in_group("menu_personaje")
	menu._toggle()
	await _esperar()
	menu._on_seccion(menu.SEC_ARMAS)
	await _foto("6_personaje_armas")
	menu._abrir_ficha_completa(d1)
	await _foto("7_personaje_info_arma")
	menu._cerrar_modal()
	menu._on_seccion(menu.SEC_ARMADURA)
	menu._pick(1)
	await _foto("8_personaje_armadura")
	menu._on_seccion(menu.SEC_FICHA)
	await _foto("9_personaje_ficha")
	print("[capturas] en ", CARPETA)
	get_tree().quit()


func _esperar() -> void:
	for k in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _foto(nombre: String) -> void:
	await _esperar()
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [CARPETA, nombre])
