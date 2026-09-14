# Vuelca los nombres de metodos, propiedades y señales de Control (y sus padres) a tools/miembros_control.txt.
# Lo usa trocear_pantalla.py: lo que un script de pantalla llama "suelto" y es de Control hay que llamarlo
# sobre la pantalla cuando se muda a un tema. godot --headless --path . -s tools/volcar_miembros_control.gd
extends SceneTree

func _init() -> void:
	var nombres := {}
	for m in ClassDB.class_get_method_list("Control"):
		nombres[m["name"]] = true
	for p in ClassDB.class_get_property_list("Control"):
		nombres[p["name"]] = true
	for s in ClassDB.class_get_signal_list("Control"):
		nombres[s["name"]] = true
	var f := FileAccess.open("res://tools/miembros_control.txt", FileAccess.WRITE)
	var lista := nombres.keys()
	lista.sort()
	f.store_string("\n".join(lista) + "\n")
	print("miembros de Control: ", lista.size())
	quit()
