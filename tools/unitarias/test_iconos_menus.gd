extends "res://tools/unitarias/caso.gd"
# Cubre: res://scripts/ui/iconos.gd
# LOS ICONOS DE LOS MENUS EN PIXEL (05/11, "todo tiene que ir con pixel art"): cada funcion de Iconos tiene su dibujo en
# assets/ui/iconos y lo pinta agrandado solo por enteros.


func test_cada_icono_tiene_su_dibujo() -> void:
	var faltan: Array = []
	for m in (load("res://scripts/ui/iconos.gd") as Script).get_script_method_list():
		var nombre: String = String(m["name"])
		if nombre.begins_with("_") or nombre == "textura_pixel":
			continue
		if Iconos.textura_pixel(nombre) == null:
			faltan.append(nombre)
	igual(faltan, [], "iconos sin dibujo pixel (tools/iconos_estados_pixel.py --hornear)")


func test_se_agranda_por_enteros() -> void:
	igual(Iconos.textura_pixel("persona", 1).get_width(), 12, "a x1, 12 px")
	igual(Iconos.textura_pixel("persona", 3).get_width(), 36, "a x3, 36 px")


func test_la_peleteria_usa_las_armaduras_de_su_material() -> void:
	var filtros: Array = load("res://scripts/ui/herreria/herreria_forjar.gd").FILTROS_PELETERIA
	var iconos: Array = filtros.map(func(f): return String(f["icono"]))
	cierto(iconos.has("coraza_cuero") and iconos.has("coraza_tela"), "cuero y tela con su dibujo: %s" % [iconos])
