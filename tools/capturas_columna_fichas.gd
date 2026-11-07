# HERRAMIENTA. No forma parte del juego. CON VENTANA (las capturas necesitan pintar):
#
#   godot --path . res://tools/capturas_columna_fichas.tscn
#
# Pase de textos 07/11: la columna de etiquetas de MenuScaffold.fila paso a 200 px (cabe "Probabilidad de crítico
# mágico"). Esto saca los menus que usan ese ancho POR DEFECTO para ver que no descuadra nada: la ficha del
# mercadillo y las dos caras de Encargos del hogar. La ficha del personaje sale en capturas_runas_fichas y la del
# combate en prueba_barras_registro (BARRAS_SALIDA). En el Escritorio, carpeta columna_fichas.
extends Node

const CARPETA := "C:/Users/dasui/Desktop/columna_fichas"
const PartidaDePrueba = preload("res://tools/visores/partida_de_prueba.gd")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA)
	var town: Node = load("res://scenes/levels/town.tscn").instantiate()
	add_child(town)
	for i in 10:
		await get_tree().process_frame
	PartidaDePrueba.llenar()

	# MERCADILLO: el primer puesto con genero, a una hora en la que este abierto.
	var merc: Node = get_tree().get_first_node_in_group("mercadillo_menu")
	if merc != null:
		var hecho: bool = false
		for v in VendedoresPlan.VENDEDORES.size():
			for paso in 96:
				var t: float = CicloDia.CICLO * float(paso) / 96.0
				if VendedoresPlan.vende(v, t):
					CicloDia.hora_forzada = t
					merc.abrir(v)
					await _foto("1_mercadillo_ficha")
					merc.cerrar()
					await _esperar()
					hecho = true
					break
			if hecho:
				break
		print("[capturas] mercadillo: ", "SI" if hecho else "ningun puesto abierto")
		CicloDia.hora_forzada = -1.0

	# HOGAR, pestaña Encargos (el nuevo, y si hay alguno en curso, su detalle).
	var hogar: Node = get_tree().get_first_node_in_group("home_menu")
	if hogar != null:
		await hogar.abrir()
		hogar._on_tab(hogar.TABS.find("Encargos"))
		await _foto("2_hogar_encargos")
		hogar._cerrar()
	print("[capturas] en ", CARPETA)
	get_tree().quit()


func _esperar() -> void:
	for k in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _foto(nombre: String) -> void:
	await _esperar()
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [CARPETA, nombre])
