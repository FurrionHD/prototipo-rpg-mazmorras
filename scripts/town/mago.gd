extends Node2D

# LA TORRE DEL MAGO del pueblo (22/11, memoria rangos-magias-y-habilidades): presionar F abre el mismo menu que el
# maestro (maestro_menu.gd) en su modo MAGO: la Meditacion (el gacha), la Biblioteca y el arbol de las magias.

func _ready() -> void:
	add_to_group("interactable")


# Lo que dice el boton flotante del HUD al tenerlo a mano (ver player.texto_interaccion).
func texto_interaccion() -> String:
	return "Hablar con el mago"


func interact_with_player() -> void:
	var menu: Node = get_tree().get_first_node_in_group("maestro_menu")
	if menu != null and menu.has_method("abrir"):
		menu.abrir("mago")
