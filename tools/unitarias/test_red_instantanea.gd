extends "res://tools/unitarias/caso.gd"
# La instantanea de la pelea por la red (scripts/net/net_peleas.gd, fase 3): las filas sin cambios van como null.

const NPE := preload("res://scripts/net/net_peleas.gd")


func _snap(hp_aliado: float, rev: int = 3) -> Dictionary:
	return {"a": [[hp_aliado, 10.0, 50.0, [["Veneno", "Pierde vida cada turno"]], 200.0], [80.0, 0.0, 30.0, [], 100.0]],
		"e": [[45.0, 0.0, 0.0, [], 60.0]], "turno": 0, "rev": rev, "fin": false}


func test_la_primera_va_entera_y_luego_solo_lo_cambiado() -> void:
	var enviadas: Dictionary = {}
	var s1 := _snap(150.0)
	var primera: Dictionary = NPE.solo_filas_nuevas(s1, enviadas, 7)
	igual(hash(primera), hash(s1), "la primera, entera")
	var segunda: Dictionary = NPE.solo_filas_nuevas(_snap(140.0), enviadas, 7)
	cierto((segunda["a"] as Array)[0] != null, "el aliado que ha perdido vida va")
	cierto((segunda["a"] as Array)[1] == null, "el que no ha cambiado, no")
	cierto((segunda["e"] as Array)[0] == null, "el enemigo tampoco")
	igual(int(segunda["turno"]), 0, "lo demas de la instantanea va igual")


func test_cada_peer_lleva_su_cuenta() -> void:
	var enviadas: Dictionary = {}
	NPE.solo_filas_nuevas(_snap(150.0), enviadas, 7)
	var otro: Dictionary = NPE.solo_filas_nuevas(_snap(150.0), enviadas, 9)
	cierto((otro["a"] as Array)[1] != null, "uno que no tenia nada lo recibe entero")


func test_entera_si_cambia_la_revision_o_las_filas() -> void:
	var enviadas: Dictionary = {}
	NPE.solo_filas_nuevas(_snap(150.0), enviadas, 7)
	var rev: Dictionary = NPE.solo_filas_nuevas(_snap(150.0, 4), enviadas, 7)
	cierto((rev["a"] as Array)[1] != null, "con otra revision, entera")
	var mas := _snap(150.0, 4)
	(mas["e"] as Array).append([30.0, 0.0, 0.0, [], 30.0])
	var otra: Dictionary = NPE.solo_filas_nuevas(mas, enviadas, 7)
	cierto((otra["e"] as Array)[0] != null, "con un enemigo mas, entera")


func test_al_recibir_el_roster_se_olvida() -> void:
	var pe := PeleaViva.new()
	NPE.solo_filas_nuevas(_snap(150.0), pe.filas_enviadas, 7)
	NPE.olvidar_filas(pe, 7)
	var tras: Dictionary = NPE.solo_filas_nuevas(_snap(150.0), pe.filas_enviadas, 7)
	cierto((tras["a"] as Array)[1] != null, "tras el roster, la siguiente va entera")
	pe.free()
