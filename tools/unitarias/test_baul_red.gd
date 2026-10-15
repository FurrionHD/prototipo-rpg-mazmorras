extends "res://tools/unitarias/caso.gd"
# Cubre: res://scripts/net/net_hogar.gd res://scripts/net/net_suelo.gd
# EL BAUL VIAJA CONTADO (fase 1A, PROTOCOLO 40): con el baul de la partida de referencia (19.000 piezas), el mensaje
# que manda el host al entrar (_set_almacen) lleva una entrada por monton, y al recibirlo sale el mismo baul.


func test_mensaje_del_baul_contado_con_la_partida_de_referencia() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if not cierto(ref is SaveData, "esta la partida de referencia (tools/huellas/mundo_ref.tres)"):
		return
	Game.importar_partida(ref)
	var unidades: int = Game.baul.total()
	var clases: int = Game.baul.clases()
	cierto(unidades > 10000, "el baul de referencia es el grande (%d piezas)" % unidades)
	var msg: Array = Net.hogar._almacen_dicts()
	igual(msg.size(), clases, "una entrada por monton")
	var antes: Array = []
	for m in Game.baul.expandir():
		antes.append(Net.suelo._item_a_dict(m))
	var b_ahora: int = var_to_bytes(msg).size()
	var b_antes: int = var_to_bytes(antes).size()
	print("    [medida] baul por red: antes %d entradas / %d KB  ->  ahora %d entradas / %d KB" % [
		antes.size(), b_antes / 1024, msg.size(), b_ahora / 1024])
	cierto(b_ahora * 10 < b_antes, "el mensaje es al menos 10 veces mas pequeño")
	# Y al recibirlo, el mismo baul
	var copia: Array = Game.baul.a_lista()
	Net.hogar._cargar_almacen(msg)
	igual(Game.baul.total(), unidades, "al recibirlo vuelven todas las piezas")
	igual(Game.baul.clases(), clases, "en los mismos montones")
	Game.baul.vaciar()
	Game.baul.anadir_lista(copia)


func test_delta_del_taller_sobre_el_baul_contado() -> void:
	Game.nueva_partida("Prueba")
	var acero: MaterialData = load("res://resources/materials/acero.tres")
	Game.baul.anadir_de(acero, MaterialItem.Calidad.NORMAL, 10)
	var foto: Dictionary = Net.hogar._conteo_almacen()
	Game.baul.quitar_de(acero, MaterialItem.Calidad.NORMAL, 3)
	Game.baul.anadir_de(acero, MaterialItem.Calidad.INTACTO, 2)
	var delta: Dictionary = Net.hogar._delta(foto, Net.hogar._conteo_almacen())
	igual((delta["quitar"] as Array).size(), 1, "un quitar")
	igual(int(delta["quitar"][0][1]), 3, "de 3")
	igual(int(delta["poner"][0][1]), 2, "y un poner de 2")
	# El otro lado aplica el delta sobre su copia (la de antes)
	Game.baul.vaciar()
	Game.baul.anadir_de(acero, MaterialItem.Calidad.NORMAL, 10)
	igual(Net.hogar._aplicar_delta_local(delta["quitar"], delta["poner"]), 0, "no falta nada")
	igual(Game.en_hogar(acero, MaterialItem.Calidad.NORMAL), 7, "quedan 7 normales")
	igual(Game.en_hogar(acero, MaterialItem.Calidad.INTACTO), 2, "y 2 intactos")
