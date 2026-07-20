extends Node2D

# Hogar: presionar F abre el menu de casa (home_menu.gd), con dos cosas:
#   - EQUIPO:  quien de tu plantilla baja hoy a la mazmorra y en que orden.
#   - ALMACEN: guardar en el baul de casa los materiales que traigas en la bolsa (lo que antes
#     hacia esta tecla a secas). Los CRISTALES no se guardan: hay que venderlos en la tienda.
# Lo guardado se consulta en la pestaña "Materiales" del inventario (tecla I).

func _ready() -> void:
	add_to_group("interactable")


func interact_with_player() -> void:
	var menu: Node = get_tree().get_first_node_in_group("home_menu")
	if menu != null and menu.has_method("abrir"):
		menu.abrir()
		return
	# Sin menu (no deberia pasar): al menos que guardar materiales siga funcionando.
	var n: int = Game.guardar_materiales_en_hogar()
	print("[Hogar] Guardaste %d materiales." % n)
