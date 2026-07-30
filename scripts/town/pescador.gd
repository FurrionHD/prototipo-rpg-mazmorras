extends Node2D

# PESCADOR del pueblo: presionar F abre su menu (fishing_book_menu.gd), con el LIBRO y los CEBOS.
# El libro es una ficha por especie con su silueta, su rareza, cuantas has sacado y tu ejemplar
# mayor y menor; el mostrador vende cebo (lo unico que vende: la caña la forja el herrero).
#
# Que el libro sea un NPC y no una pestaña del inventario es a proposito: no es una lista de lo que
# LLEVAS (eso se vende y se cocina), es la cuenta de lo que has hecho. Ver Game.registro_pesca.

func _ready() -> void:
	add_to_group("interactable")


func interact_with_player() -> void:
	var menu: Node = get_tree().get_first_node_in_group("fishing_book_menu")
	if menu != null and menu.has_method("abrir"):
		menu.abrir()
