extends Node2D

# MAESTRO DE HABILIDADES del pueblo: presionar F abre maestro_menu.gd. Ahi se APRENDEN las
# habilidades de arma (las que no vienen de fabrica cuestan dinero) y se elige cuales de ellas
# lleva puestas cada personaje, con el tope de Game.MAX_HABILIDADES.

func _ready() -> void:
	add_to_group("interactable")


func interact_with_player() -> void:
	var menu: Node = get_tree().get_first_node_in_group("maestro_menu")
	if menu != null and menu.has_method("abrir"):
		menu.abrir()
