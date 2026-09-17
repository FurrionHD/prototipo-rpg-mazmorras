extends Node2D

# CARPINTERO del pueblo: presionar F abre su menu (forge_menu.gd en modo "carpintero").
# Asierra la madera en tablones y forja las armas magicas (bastones y varitas). Una sola
# habilidad, Carpinteria, cubre las dos cosas. La math vive en Game/Forge.

func _ready() -> void:
	add_to_group("interactable")


# Lo que dice el boton flotante del HUD al tenerlo a mano (ver player.texto_interaccion).
func texto_interaccion() -> String:
	return "Entrar en la carpintería"


func interact_with_player() -> void:
	var menu: Node = get_tree().get_first_node_in_group("carpinteria_menu")
	if menu != null and menu.has_method("abrir"):
		menu.abrir()
