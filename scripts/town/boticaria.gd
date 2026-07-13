extends Node2D

# Boticaria: presionar F para abrir el menu de crafteo de pociones. A diferencia de la
# Tienda y el Hogar (que actuan al instante), aqui hace falta ELEGIR receta, asi que abre
# un menu por codigo (craft_menu.gd, creado por el jugador). Los materiales que consume
# salen del baul del Hogar (no de la bolsa): craftear es cosa de pueblo.

func _ready() -> void:
	add_to_group("interactable")


func interact_with_player() -> void:
	var menu: Node = get_tree().get_first_node_in_group("craft_menu")
	if menu != null and menu.has_method("abrir"):
		menu.abrir()
	else:
		push_warning("[boticaria] no encuentro el menu de crafteo")
