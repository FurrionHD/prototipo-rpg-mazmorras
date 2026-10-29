extends "res://tools/unitarias/caso.gd"
# Cubre: res://scripts/net/ids_red.gd res://scripts/net/net_peleas.gd res://scripts/net/net_suelo.gd res://scripts/net/net_hogar.gd
# LOS IDS DE LA RED (29/10, PROTOCOLO 55): cada .tres tiene su numero de 16 bits, el mismo en dos arranques del mismo
# build (la tabla sale ordenada), ida y vuelta exacta, y lo que el juego reparte por sus listas (materiales,
# consumibles, enemigos) esta en la tabla. Lo que no esta da 0 y un error: no viaja a ciegas.

const NetPeleas = preload("res://scripts/net/net_peleas.gd")


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


func test_en_la_frontera_cada_ruta_va_como_numero_y_vuelve() -> void:
	var d := {"t": "mat", "ruta": "res://resources/materials/baba_slime.tres", "calidad": 2,
		"dentro": [{"ruta": "res://resources/materials/runa_slime.tres"}, {"ruta": "user://no_esta.tres"}]}
	var red: Dictionary = IdsRed.a_red(d)
	cierto(red["ruta"] is int, "la ruta va como numero")
	cierto(red["dentro"][0]["ruta"] is int, "tambien anidada")
	igual(red["dentro"][1]["ruta"], "user://no_esta.tres", "la que no esta en la tabla se queda en texto")
	igual(IdsRed.de_red(red), d, "y al llegar sale lo mismo")
	igual(d["ruta"], "res://resources/materials/baba_slime.tres", "el original no se toca")
	igual(IdsRed.de_red(d), d, "lo que ya trae rutas (una llamada local) no cambia")


func test_el_baul_de_referencia_por_la_frontera() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if not cierto(ref is SaveData, "esta la partida de referencia"):
		return
	Game.importar_partida(ref)
	var msg: Array = Net.hogar._almacen_dicts()
	var red: Array = IdsRed.a_red(msg)
	igual(IdsRed.de_red(red), msg, "ida y vuelta del baul entero")
	var antes: int = var_to_bytes(msg).size()
	var ahora: int = var_to_bytes(red).size()
	var antes_z: int = (Net.zip(msg)[1] as PackedByteArray).size()
	var ahora_z: int = (Net.zip(red)[1] as PackedByteArray).size()
	print("    [medida] baul por red: %d KB -> %d KB; comprimido %d KB -> %d KB" % [antes / 1024, ahora / 1024,
		antes_z / 1024, ahora_z / 1024])
	cierto(ahora < antes and ahora_z <= antes_z, "pesa menos")


func test_una_accion_de_combate_viaja_con_ids() -> void:
	var accion := {"tipo": "cargar", "ruta": "res://resources/materials/baba_slime.tres",
		"hab": "res://resources/materials/runa_slime.tres", "obj": 2, "seq": 7}
	var red: Dictionary = NetPeleas.accion_a_red(accion)
	cierto(red["ruta"] is int and red["hab"] is int, "ruta y hab como numeros")
	igual(NetPeleas.accion_de_red(red), accion, "y vuelve igual")
	var sin_hab := {"tipo": "atacar", "obj": 1}
	igual(NetPeleas.accion_de_red(NetPeleas.accion_a_red(sin_hab)), sin_hab, "una sin rutas, intacta")
