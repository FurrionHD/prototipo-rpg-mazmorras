extends "res://tools/unitarias/caso.gd"
# El estado del invitado al guardar (scripts/net/net_partida.gd, fase 3): solo las secciones que cambian, y la sala
# lo junta con lo ultimo que tenia.

const NP := preload("res://scripts/net/net_partida.gd")


func _estado() -> Dictionary:
	return {"id": "abc", "dinero": 120, "baul": [{"ruta": "res://x.tres", "n": 3}, {"ruta": "res://y.tres", "n": 1}],
		"personajes": [{"nombre": "Dasui", "nivel": 4}], "crystals": {"1": 5}}


func test_la_primera_vez_va_todo() -> void:
	var d := _estado()
	var r: Array = NP.solo_lo_cambiado(d, {})
	for k in d:
		cierto((r[0] as Dictionary).has(k), "sin nada mandado, va '%s'" % k)
	igual((r[1] as Dictionary).size(), d.size(), "y se apunta el hash de cada seccion")


func test_luego_solo_lo_que_cambia() -> void:
	var d := _estado()
	var hashes: Dictionary = NP.solo_lo_cambiado(d, {})[1]
	var d2 := _estado()
	d2["dinero"] = 150
	var envio: Dictionary = NP.solo_lo_cambiado(d2, hashes)[0]
	cierto(envio.has("dinero"), "el dinero ha cambiado: va")
	cierto(not envio.has("baul"), "el baul no: no va")
	cierto(not envio.has("personajes"), "los personajes tampoco")
	cierto(bool(envio.get("_parcial", false)), "y va marcado como parte")


func test_la_sala_lo_junta_igual_que_el_entero() -> void:
	var d := _estado()
	var hashes: Dictionary = NP.solo_lo_cambiado(d, {})[1]
	var d2 := _estado()
	d2["dinero"] = 150
	(d2["personajes"] as Array).append({"nombre": "Daniel", "nivel": 2})
	d2["gacha_historial"] = [1, 2, 3]    # una seccion nueva
	d2.erase("crystals")                  # y una que ya no esta
	var junto: Dictionary = NP.juntar_estado(d, NP.solo_lo_cambiado(d2, hashes)[0])
	igual(junto.size(), d2.size(), "las mismas secciones que el entero")
	for k in d2:
		igual(hash(junto.get(k)), hash(d2[k]), "'%s' igual que en el entero" % k)
	cierto(not junto.has("_parcial") and not junto.has("_claves"), "sin las marcas del envio")
