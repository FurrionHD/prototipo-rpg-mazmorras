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
	# La lista de propiedades trae tambien las CATEGORIAS y grupos del inspector ("Container Sizing",
	# "Layout", "theme_override_colors/"): no son miembros, y colarse aqui convertia un tipo como
	# 'box: Container' en '_pantalla.Container'. Solo nombres de miembro de verdad.
	var valido := RegEx.create_from_string("^[a-z_][a-z0-9_]*$")
	for n in nombres.keys():
		if valido.search(String(n)) == null:
			nombres.erase(n)
	var f := FileAccess.open("res://tools/miembros_control.txt", FileAccess.WRITE)
	var lista := nombres.keys()
	lista.sort()
	f.store_string("\n".join(lista) + "\n")
	print("miembros de Control: ", lista.size())
	quit()
