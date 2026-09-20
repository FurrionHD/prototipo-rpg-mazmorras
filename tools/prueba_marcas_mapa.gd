# PRUEBA (sin ventana): las MARCAS del mapa se borran cuando dejan de valer, y solo ellas.
#
# Dos cosas invalidan una marca sin invalidar el piso: que cambie la COLOCACION de los sitios de
# recoleccion (build nuevo, ver SaveData.RECOLECTABLES_ACTUAL) y que se cierre la mazmorra (epoca
# nueva: el mismo sitio pasa a dar otro material). En los dos casos el suelo explorado, las
# escaleras, las salidas y los charcos se quedan: eso no lo mueve ninguna de las dos.
#
# Y en multijugador, al fundir dos libretas del mismo piso manda la lectura NUEVA, no la primera.
extends Node

var _malos: int = 0


func _ok(texto: String, cond: bool) -> void:
	print(("  ok   " if cond else "  MAL  ") + texto)
	if not cond:
		_malos += 1


func _piso_de_pruebas() -> Dictionary:
	return {
		"ancho": 40, "alto": 30,
		"suelo": [Vector2i(1, 1), Vector2i(2, 1)],
		"vivos": [{"cell": Vector2i(5, 5), "color": Color.RED, "tipo": 0}],
		"agotados": {Vector2i(9, 9): {"t": 123.0, "color": Color.BLUE, "tipo": 1}},
		"escaleras": [{"cell": Vector2i(3, 3), "sube": true}],
		"salidas": [Vector2i(0, 0)],
		"estanques": [{"cell": Vector2i(7, 7), "ancho": 4, "alto": 3}],
	}


func _sigue_entera(s: Dictionary) -> bool:
	return int(s["ancho"]) == 40 and (s["suelo"] as Array).size() == 2 \
		and (s["escaleras"] as Array).size() == 1 and (s["salidas"] as Array).size() == 1 \
		and (s["estanques"] as Array).size() == 1


func _sin_marcas(s: Dictionary) -> bool:
	return (s["vivos"] as Array).is_empty() and (s["agotados"] as Dictionary).is_empty()


func _ready() -> void:
	print("=== LAS MARCAS VIEJAS DEL MAPA ===")

	# 1) COLOCACION NUEVA: el save trae el sello viejo y la libreta pierde las marcas al cargar.
	Game.mapa_snapshot = {3: _piso_de_pruebas()}
	Game.mapa_trabajo = {3: _piso_de_pruebas()}
	Game.mazmorra_persistente = {3: {"agotados": {Vector2i(9, 9): 123.0}, "nonces": {Vector2i(9, 9): 2},
		"zonas_vistas": {0: true}}}
	var d := SaveData.new()
	d.recolectables = 0   # partida de antes de que la colocacion cambiara
	Game._olvidar_marcas_de_otra_colocacion(d)
	_ok("con la colocacion nueva, fuera las marcas del mapa", _sin_marcas(Game.mapa_snapshot[3]))
	_ok("y las del snapshot de trabajo tambien", _sin_marcas(Game.mapa_trabajo[3]))
	_ok("pero la exploracion se queda entera", _sigue_entera(Game.mapa_snapshot[3]))
	_ok("y los sellos de agotado y los nonces, a cero",
		(Game.mazmorra_persistente[3]["agotados"] as Dictionary).is_empty()
		and (Game.mazmorra_persistente[3]["nonces"] as Dictionary).is_empty())
	_ok("las zonas vistas NO se tocan", (Game.mazmorra_persistente[3]["zonas_vistas"] as Dictionary).size() == 1)

	# 2) MISMO SELLO: no se toca nada.
	Game.mapa_snapshot = {3: _piso_de_pruebas()}
	var d2 := SaveData.new()
	d2.recolectables = SaveData.RECOLECTABLES_ACTUAL
	Game._olvidar_marcas_de_otra_colocacion(d2)
	_ok("con el sello al dia, la libreta se queda como estaba", not _sin_marcas(Game.mapa_snapshot[3]))

	# 3) CERRAR LA MAZMORRA (epoca nueva): el material de cada sitio se rebaraja, asi que el color y
	#    el tipo congelados ya mienten.
	Game.mapa_snapshot = {3: _piso_de_pruebas()}
	Game.mapa_trabajo = {}
	var epoca_antes: int = Game.epoca_actual()
	Game.olvidar_mazmorra()
	_ok("cerrar la mazmorra rebaraja la epoca", Game.epoca_actual() != epoca_antes)
	_ok("y con ella se van las marcas del plano", _sin_marcas(Game.mapa_snapshot[3]))
	_ok("sin llevarse lo explorado", _sigue_entera(Game.mapa_snapshot[3]))

	# 4) MULTI: al fundir dos lecturas de la misma celda manda la NUEVA.
	var NetMapa = load("res://scripts/net/net_mapa.gd")
	var nm = NetMapa.new()
	var base: Dictionary = {"vivos": [{"cell": Vector2i(5, 5), "color": Color.RED, "tipo": 0}]}
	var nuevo: Dictionary = {"vivos": [{"cell": Vector2i(5, 5), "color": Color.GREEN, "tipo": 3},
		{"cell": Vector2i(6, 6), "color": Color.BLUE, "tipo": 1}]}
	nm._unir_por_celda(base, nuevo, "vivos")
	var lista: Array = base["vivos"]
	_ok("la union no repite celdas", lista.size() == 2)
	_ok("y en la celda repetida gana la lectura nueva",
		int((lista[0] as Dictionary)["tipo"]) == 3)
	nm.free()

	print("FIN, %d fallos" % _malos)
	get_tree().quit(_malos)
