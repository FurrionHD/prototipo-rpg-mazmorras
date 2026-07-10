extends Node2D

# Hogar: presionar F para GUARDAR los materiales (drops) de la bolsa en el baul de casa.
# Los CRISTALES no se guardan: hay que venderlos si o si en la tienda.
# Lo guardado se consulta en la pestaña "Materiales" del inventario (tecla I).

func _ready() -> void:
	add_to_group("interactable")


func interact_with_player() -> void:
	if Game.drops.is_empty():
		print("[Hogar] No traes materiales que guardar.")
		return
	var n: int = Game.guardar_materiales_en_hogar()
	print("[Hogar] Guardaste %d materiales. (Los cristales se venden en la tienda.)" % n)
