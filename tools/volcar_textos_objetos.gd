extends Node
# Vuelca a la consola lo que lee el jugador de cada consumible (pase de textos 06/11): su resumen tal como sale en el
# inventario y en la tienda, y su descripcion de sabor. Sin ventana:
#   godot --headless --path . res://tools/volcar_textos_objetos.tscn
# La vida y el maná de referencia (200 / 40) son los de un personaje de nivel medio: solo cambian las cifras de las pociones.

const HP := 200.0
const MP := 40.0


func _ready() -> void:
	await get_tree().process_frame
	var dir := DirAccess.open("res://resources/consumables")
	var nombres: Array = []
	for f in dir.get_files():
		if f.ends_with(".tres"):
			nombres.append(f)
	nombres.sort()
	for f in nombres:
		var c = load("res://resources/consumables/" + f)
		if c == null or not (c is ConsumableData):
			continue
		var cons: ConsumableData = c
		print("=== %s  [%s]" % [cons.nombre, f])
		if cons.es_grimorio():
			print("  Enseña: %s" % cons.spell.nombre)
		elif cons.es_plato() or cons.es_brebaje_de_estado():
			print("  " + cons.resumen_plato().replace("\n", "\n  "))
		elif cons.es_untura():
			print("  " + cons.resumen_untura().replace("\n", "\n  "))
		elif cons.es_cebo():
			print("  Atracción: " + cons.resumen(0.0, 0.0))
		else:
			# Igual que la ficha del inventario (inventory_menu._preview_consumible).
			print("  Efecto: " + cons.resumen(HP, MP, "Dasui"))
			if cons.cura_hp() or cons.da_mana():
				print("  Se reparte en: " + cons.reparto_txt())
		if cons.descripcion != "":
			print("  Sabor: " + cons.descripcion.replace("\n", " "))
	get_tree().quit()
