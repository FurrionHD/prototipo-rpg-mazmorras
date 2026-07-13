extends Node2D

# PELETERO del pueblo: presionar F abre su menu (tannery_menu.gd). Cortar el cuero crudo que
# sueltan los bichos y dejarlo en cuero curtido, que es lo unico que admite la forja.
# Cuando haya MOCHILAS (capacidad de carga), se confeccionan aqui: es su sitio natural.

func _ready() -> void:
	add_to_group("interactable")


func interact_with_player() -> void:
	var menu: Node = get_tree().get_first_node_in_group("tannery_menu")
	if menu != null and menu.has_method("abrir"):
		menu.abrir()
