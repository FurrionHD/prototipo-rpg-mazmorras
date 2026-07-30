extends Node2D

# PESCADOR del pueblo: presionar F abre su LIBRO (fishing_book_menu.gd). No compra, no vende y no
# fabrica nada: lleva el registro. Una ficha por especie con su silueta, su rareza, cuantas has
# sacado y tu ejemplar mayor y menor.
#
# Que sea un NPC y no una pestaña del inventario es a proposito: el libro no es una lista de lo que
# LLEVAS (eso se vende y se cocina), es la cuenta de lo que has hecho. Ver Game.registro_pesca.

func _ready() -> void:
	add_to_group("interactable")


func interact_with_player() -> void:
	var menu: Node = get_tree().get_first_node_in_group("fishing_book_menu")
	if menu != null and menu.has_method("abrir"):
		menu.abrir()
