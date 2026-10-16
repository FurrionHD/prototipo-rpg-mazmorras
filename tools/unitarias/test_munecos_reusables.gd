extends "res://tools/unitarias/caso.gd"
# Cubre: res://scripts/ui/munecos_reusables.gd
# LOS MUNECOS GRANDES REUTILIZADOS (fase 1D, 16/10): al rehacer una pantalla (MenuScaffold.vaciar + montar de nuevo)
# sale el MISMO muneco, sin la marca "muriendo" que vaciar le pone a todo lo de dentro, y sin el atenuado del uso
# anterior. Si el boton viejo ya se borro del todo, uno nuevo.


func _pj() -> PersonajeData:
	Game.nueva_partida("Prueba")
	return Game.lider()


func test_el_mismo_muneco_tras_vaciar() -> void:
	var pj := _pj()
	var zona := Control.new()
	var boton := Control.new()
	zona.add_child(boton)
	var mu := MunecosReusables.dar("prueba|1", pj)
	mu.modulate = Color(0.5, 0.5, 0.5)
	boton.add_child(mu)
	MenuScaffold.vaciar(zona)   # queue_free del boton, con su muneco dentro, marcado "muriendo"
	cierto(MenuScaffold.muriendo(mu), "vaciar marca el muneco")
	var otra := MunecosReusables.dar("prueba|1", pj)
	cierto(otra == mu, "es el mismo muneco")
	cierto(otra.get_parent() == null, "sin padre: listo para el boton nuevo")
	cierto(not MenuScaffold.muriendo(otra), "ya no esta marcado muriendo")
	igual(otra.modulate, Color.WHITE, "sin el atenuado de antes")
	otra.free()
	zona.free()


func test_si_el_boton_ya_se_borro_uno_nuevo() -> void:
	var pj := _pj()
	var boton := Control.new()
	var mu := MunecosReusables.dar("prueba|2", pj)
	var id_viejo: int = mu.get_instance_id()
	boton.add_child(mu)
	boton.free()   # se lleva el muneco
	var nuevo := MunecosReusables.dar("prueba|2", pj)
	cierto(is_instance_valid(nuevo), "hay muneco")
	cierto(nuevo.get_instance_id() != id_viejo, "y es otro")
	nuevo.free()


func test_claves_distintas_munecos_distintos() -> void:
	var pj := _pj()
	var a := MunecosReusables.dar("prueba|a", pj)
	var b := MunecosReusables.dar("prueba|b", pj)
	cierto(a != b, "uno por sitio")
	MunecosReusables.soltar("prueba|a")
	MunecosReusables.soltar("prueba|b")
