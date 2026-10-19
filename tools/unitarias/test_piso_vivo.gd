extends "res://tools/unitarias/caso.gd"
# PisoVivo (scripts/world/piso_vivo.gd, fase 2): con UN piso vivo todo es lo de antes (los grupos del arbol entero);
# con DOS, cada uno ve solo lo que cuelga de el.

const G := &"prueba_piso_vivo_grupo"


func _raiz() -> Node:
	return arbol


func _piso_con(n_cosas: int) -> PisoVivo:
	var p := PisoVivo.new()
	_raiz().add_child(p)
	for i in n_cosas:
		var c := Node2D.new()
		c.add_to_group(G)
		p.add_child(c)
	return p


func _soltar(nodos: Array) -> void:
	for n in nodos:
		if is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.free()


func test_un_piso_es_lo_de_siempre() -> void:
	var p := _piso_con(2)
	# Algo del grupo que NO cuelga del piso (como la capa de combate): con un solo piso sigue saliendo, igual que antes.
	var suelto := Node2D.new()
	suelto.add_to_group(G)
	_raiz().add_child(suelto)
	igual(PisoVivo.unico(), p, "con un piso, unico() es ese piso")
	cierto(not PisoVivo.hay_varios(), "no hay varios")
	igual(p.nodos(G).size(), 3, "con un piso el grupo es el del arbol entero (tambien lo suelto)")
	igual(PisoVivo.de(suelto), p, "lo que no cuelga de un piso se queda con el unico")
	igual(PisoVivo.de(p.get_child(0)), p, "lo de dentro sube hasta su piso")
	cierto(p.primero(G) != null, "primero() encuentra algo")
	_soltar([suelto, p])
	cierto(PisoVivo.unico() == null, "sin pisos, unico() es null")


func test_dos_pisos_no_se_mezclan() -> void:
	var a := _piso_con(2)
	var b := _piso_con(3)
	cierto(PisoVivo.hay_varios(), "hay varios")
	cierto(PisoVivo.unico() == null, "con dos no hay unico")
	igual(a.nodos(G).size(), 2, "el piso A ve sus 2")
	igual(b.nodos(G).size(), 3, "el piso B ve sus 3")
	igual(a.lista_fisica(G).size(), 2, "la lista por fotograma de A, sus 2")
	igual(b.lista_fisica(G).size(), 3, "la de B, sus 3 (no la de A del mismo fotograma)")
	igual(PisoVivo.de(b.get_child(1)), b, "un nodo de B es de B")
	cierto(a.is_ancestor_of(a.primero(G)), "primero() de A es de A")
	var suelto := Node2D.new()
	_raiz().add_child(suelto)
	cierto(PisoVivo.de(suelto) == null, "con dos pisos, lo suelto no es de ninguno")
	_soltar([suelto, a, b])


func test_lista_fisica_filtro_y_clave() -> void:
	var p := _piso_con(3)
	p.get_child(0).set_meta("es_espejo", true)
	var sin_espejos := func(n: Node) -> bool: return not n.has_meta("es_espejo")
	igual(p.lista_fisica(G, sin_espejos, &"sin_espejos").size(), 2, "con filtro salen 2")
	igual(p.lista_fisica(G).size(), 3, "sin filtro (otra clave) salen las 3 en el mismo fotograma")
	igual(p.lista_fisica(G, sin_espejos, &"sin_espejos").size(), 2, "y la filtrada sigue en 2")
	_soltar([p])


func test_numero() -> void:
	var p := _piso_con(0)
	igual(p.numero, Game.current_floor, "sin fijar, el numero es Game.current_floor")
	p.numero_fijo = 7
	igual(p.numero, 7, "fijado, el suyo")
	_soltar([p])


func test_por_lugar_con_dos_pisos() -> void:
	var a := _piso_con(1)
	a.lugar_fijo = "piso:3"
	a.dueno_fijo = 1
	var b := _piso_con(1)
	b.lugar_fijo = "piso:5"
	b.dueno_fijo = 0
	igual(PisoVivo.del_lugar("piso:5"), b, "del_lugar encuentra el suyo")
	cierto(PisoVivo.lleva("piso:3") and PisoVivo.lleva("piso:5"), "llevo los dos")
	cierto(not PisoVivo.lleva("piso:9"), "uno que no tengo, no")
	cierto(PisoVivo.dueno_de("piso:3") and not PisoVivo.dueno_de("piso:5"), "dueño de A, no de B")
	cierto(PisoVivo.espejo_de("piso:5") and not PisoVivo.espejo_de("piso:3"), "espejo de B, no de A")
	cierto(PisoVivo.dueno_del_nodo(a.get_child(0)) and not PisoVivo.dueno_del_nodo(b.get_child(0)), "por nodo")
	cierto(PisoVivo.dueno_de_alguno(), "dueño de alguno")
	igual(PisoVivo.raiz_del_lugar("piso:3", arbol.get_tree()), a, "lo que llega para piso:3 se cuelga en A")
	_soltar([a, b])


func test_por_lugar_con_un_piso_es_net() -> void:
	var p := _piso_con(0)
	var antes: String = Net._mi_lugar
	Net._mi_lugar = "piso:4"
	cierto(PisoVivo.lleva("piso:4") and not PisoVivo.lleva("piso:2"), "con un piso, lleva = Net._mi_lugar")
	igual(PisoVivo.dueno_de("piso:4"), Net._soy_dueno, "y dueno_de = Net._soy_dueno")
	igual(PisoVivo.raiz_del_lugar("piso:4", arbol.get_tree()), arbol.get_tree().current_scene, "y la raiz, current_scene")
	Net._mi_lugar = antes
	_soltar([p])
