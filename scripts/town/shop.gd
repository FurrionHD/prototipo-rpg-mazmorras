extends Node2D

# TIENDA del pueblo: presionar F abre el menu (shop_menu.gd), igual que la Boticaria.
# Vender, recomprar, comprar y el pack inicial viven ahi; la math, en Game.

func _ready() -> void:
	add_to_group("interactable")


func interact_with_player() -> void:
	var menu: Node = get_tree().get_first_node_in_group("shop_menu")
	if menu != null and menu.has_method("abrir"):
		menu.abrir()
