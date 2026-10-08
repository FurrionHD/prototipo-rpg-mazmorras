extends Node2D

# EL TALLER DE RUNAS del pueblo (08/10/2026): presionar F abre su menu (runas_menu.gd). Activa los sets de los mutantes
# en tus piezas y les pone, cambia y re-tira sub-stats con sus runas. La math vive en Runas.

func _ready() -> void:
	add_to_group("interactable")


# Lo que dice el boton flotante del HUD al tenerlo a mano (ver player.texto_interaccion).
func texto_interaccion() -> String:
	return "Entrar en el taller de runas"


func interact_with_player() -> void:
	var menu: Node = get_tree().get_first_node_in_group("runas_menu")
	if menu != null and menu.has_method("abrir"):
		menu.abrir()
