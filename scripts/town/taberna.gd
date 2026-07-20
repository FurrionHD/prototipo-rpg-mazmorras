extends Node2D

# TABERNA del pueblo: presionar F abre el menu de contratacion (tavern_menu.gd). Es donde se
# ficha gente para el grupo; quien BAJA contigo se decide en el Hogar.

func _ready() -> void:
	add_to_group("interactable")


func interact_with_player() -> void:
	var menu: Node = get_tree().get_first_node_in_group("tavern_menu")
	if menu != null and menu.has_method("abrir"):
		menu.abrir()
