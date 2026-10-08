# HERRAMIENTA. No forma parte del juego. CON VENTANA:
#
#   godot --path . res://tools/lamina_runas_celdas.tscn
#
# LAS RUNAS EN LAS CELDAS (08/10/2026, version B elegida por el usuario): una pieza de cada set con 0 a 4 sub-stats y
# una sin runas, en celdas de verdad a dos tamaños (el grande del Taller y uno pequeño). Escritorio/taller_runas.
extends Control

const SALIDA := "C:/Users/dasui/Desktop/taller_runas/celdas_runas.png"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fondo := ColorRect.new()
	fondo.color = Color(0.05, 0.06, 0.08)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var piezas: Array = []
	var defs := [["slime", "res://resources/armor/hierro_pecho.tres", 3, 4, 0],
		["profundo", "res://resources/armor/cuero_casco.tres", 2, 2, 1],
		["rey", "res://resources/armor/placas_pecho.tres", 3, 6, 4],
		["fuego", "res://resources/weapons/espada_larga.tres", 1, 1, 2],
		["venenoso", "res://resources/weapons/daga.tres", 3, 7, 3],
		["abisal", "res://resources/wands/varita.tres", 2, 5, 4],
		["", "res://resources/weapons/daga.tres", 2, 3, 0]]
	for d in defs:
		var it: Resource = Game.crear_item(load(d[1]), int(d[2]), int(d[3]), {}, false)
		if String(d[0]) != "":
			var subs: Array = []
			for k in int(d[4]):
				subs.append({"s": "crit", "v": 0.04})
			Game.meta_de(it)["runas"] = {"set": String(d[0]), "subs": subs}
		piezas.append({"item": it, "pie": "", "activo": true, "marca": "", "tooltip": ""})
	var vb := VBoxContainer.new()
	vb.position = Vector2(30, 20)
	vb.add_theme_constant_override("separation", 14)
	add_child(vb)
	for lado in [140.0, 96.0]:
		var fila := VBoxContainer.new()
		fila.custom_minimum_size = Vector2(1200, lado + 10.0)
		vb.add_child(fila)
		MenuScaffold.rejilla_objetos(fila, piezas, -1, func(_i): pass, 7, lado)
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().get_region(Rect2i(0, 0, 1280, 330)).save_png(SALIDA)
	print("[lamina] ", SALIDA)
	get_tree().quit()
