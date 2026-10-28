extends "res://tools/unitarias/caso.gd"
# La libreta del mapa por la red (scripts/net/net_mapa.gd, fase 3): el suelo va como mapa de bits.

const NM := preload("res://scripts/net/net_mapa.gd")


func _snap(celdas: Array) -> Dictionary:
	return {"ancho": 120, "alto": 80, "suelo": celdas, "vivos": [{"cell": Vector2i(3, 4), "color": Color.RED, "tipo": 1}],
		"escaleras": [{"cell": Vector2i(10, 10), "sube": true}], "salidas": [Vector2i(5, 5)],
		"estanques": [], "agotados": {Vector2i(7, 7): {"t": 12.5}}}


func _conjunto(a: Array) -> Dictionary:
	var d: Dictionary = {}
	for c in a:
		d[Vector2i(c)] = true
	return d


func test_ida_y_vuelta_las_mismas_celdas_y_campos() -> void:
	var celdas: Array = []
	for y in range(10, 60):
		for x in range(5, 110, 3):
			celdas.append(Vector2i(x, y))
	celdas.append(Vector2i(0, 0))
	celdas.append(Vector2i(119, 79))
	var snap := _snap(celdas)
	var red: Dictionary = NM.mapa_a_red({4: snap})
	cierto(not (red[4] as Dictionary).has("suelo") and (red[4] as Dictionary).has("suelo_bits"), "por la red, en bits")
	var vuelta: Dictionary = NM.mapa_de_red(red)[4]
	igual(_conjunto(vuelta["suelo"]), _conjunto(celdas), "las mismas celdas (las esquinas tambien)")
	igual((vuelta["suelo"] as Array).size(), celdas.size(), "ni una de mas")
	for k in ["ancho", "alto", "vivos", "escaleras", "salidas", "estanques", "agotados"]:
		igual(hash(vuelta[k]), hash(snap[k]), "'%s' viaja tal cual" % k)
	cierto(not vuelta.has("suelo_bits"), "y sin el campo de la red")
	cierto(snap.has("suelo") and not snap.has("suelo_bits"), "el original no se toca")


func test_pesa_mucho_menos() -> void:
	var celdas: Array = []
	for y in 80:
		for x in 60:
			celdas.append(Vector2i(x, y))
	var antes: int = var_to_bytes({1: _snap(celdas)}).size()
	var ahora: int = var_to_bytes(NM.mapa_a_red({1: _snap(celdas)})).size()
	cierto(ahora * 10 < antes, "menos de una decima (%d B frente a %d)" % [ahora, antes])


func test_celda_fuera_del_piso_va_como_siempre() -> void:
	var snap := _snap([Vector2i(1, 1), Vector2i(500, 2)])
	var red: Dictionary = NM.snap_a_red(snap)
	cierto(red.has("suelo") and not red.has("suelo_bits"), "con una celda fuera, la lista de siempre")
	igual(NM.snap_de_red(red).size(), snap.size(), "y vuelve igual")


func test_sin_suelo_o_sin_medidas_no_rompe() -> void:
	var sin: Dictionary = {"ancho": 0, "alto": 0}
	igual(NM.snap_a_red(sin), sin, "sin medidas, tal cual")
	igual(NM.mapa_de_red({}).size(), 0, "libreta vacia")
	var vacio := _snap([])
	igual((NM.snap_de_red(NM.snap_a_red(vacio))["suelo"] as Array).size(), 0, "sin celdas, sin celdas")
