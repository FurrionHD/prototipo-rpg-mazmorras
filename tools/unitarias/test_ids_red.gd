extends "res://tools/unitarias/caso.gd"
# Cubre: res://scripts/net/ids_red.gd
# LOS IDS DE LA RED (29/10, PROTOCOLO 55): cada .tres tiene su numero de 16 bits, el mismo en dos arranques del mismo
# build (la tabla sale ordenada), ida y vuelta exacta, y lo que el juego reparte por sus listas (materiales,
# consumibles, enemigos) esta en la tabla. Lo que no esta da 0 y un error: no viaja a ciegas.


func test_cada_recurso_tiene_su_numero_y_vuelve() -> void:
	var n: int = IdsRed.cuantos()
	cierto(n > 500 and n < IdsRed.TOPE, "caben en 16 bits (%d)" % n)
	var malos := 0
	for id in range(1, n + 1):
		if IdsRed.de(IdsRed.ruta(id)) != id:
			malos += 1
	igual(malos, 0, "ida y vuelta de todos")
	igual(IdsRed.ruta(0), "", "el 0 es nada")
	igual(IdsRed.ruta(n + 1), "", "fuera de la tabla, nada")
	igual(IdsRed.de(null), 0, "null, 0")
	igual(IdsRed.de(""), 0, "ruta vacia, 0")


func test_un_recurso_cargado_da_el_numero_de_su_ruta() -> void:
	var baba: Resource = load("res://resources/materials/baba_slime.tres")
	var id: int = IdsRed.de(baba)
	cierto(id > 0, "la baba tiene numero (%d)" % id)
	cierto(IdsRed.cargar(id) == baba, "y cargarlo da la MISMA instancia")


func test_la_tabla_es_la_misma_en_dos_arranques() -> void:
	var sello: int = IdsRed.sello()
	var rutas: PackedStringArray = IdsRed._rutas.duplicate()
	IdsRed._rutas = PackedStringArray()   # como si arrancara otra vez
	igual(IdsRed.sello(), sello, "mismo sello")
	igual(IdsRed._rutas, rutas, "mismos numeros")


func test_lo_que_reparte_el_juego_esta_en_la_tabla() -> void:
	var faltan: Array = []
	for r in Game.rutas_materiales() + Game.rutas_consumibles() + Game.rutas_enemigos():
		if not IdsRed._id_de.has(String(r)):
			faltan.append(r)
	igual(faltan, [], "materiales, consumibles y enemigos")


func test_lo_que_no_esta_da_cero_y_avisa() -> void:
	igual(IdsRed.de("res://no/existe.tres"), 0, "0")
	aviso_esperado("no esta en la tabla")
