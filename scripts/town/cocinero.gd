extends Node2D

# Cocinero: presionar F para abrir el menu de cocina. Mismo patron que la Boticaria y por la misma
# razon: hay que ELEGIR receta, asi que abre un menu por codigo. Los ingredientes salen del baul del
# Hogar (no de la bolsa), como todo el crafteo: cocinar es cosa de pueblo.
#
# El menu es craft_menu.gd en modo COCINA (lo instancia player.gd); por eso se busca por el grupo
# "cocina_menu" y no por "craft_menu", que es el de las pociones.

func _ready() -> void:
	add_to_group("interactable")


func interact_with_player() -> void:
	var menu: Node = get_tree().get_first_node_in_group("cocina_menu")
	if menu != null and menu.has_method("abrir"):
		menu.abrir()
	else:
		push_warning("[cocinero] no encuentro el menu de cocina")
