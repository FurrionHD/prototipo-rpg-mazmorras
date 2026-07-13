extends Node2D

# HERRERO del pueblo: presionar F abre el menu de forja (forge_menu.gd). Forjar piezas
# nuevas y mejorarlas con nucleos; la math vive en Game/Forge.

func _ready() -> void:
	add_to_group("interactable")


func interact_with_player() -> void:
	var menu: Node = get_tree().get_first_node_in_group("forge_menu")
	if menu != null and menu.has_method("abrir"):
		menu.abrir()
