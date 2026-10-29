extends "res://tools/unitarias/caso.gd"
# Los mensajes gordos comprimidos (Net.zip / Net.unzip, scripts/net/net.gd, fase 3).

const NET := preload("res://scripts/net/net.gd")


func _almacen(n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append({"ruta": "res://data/materials/mineral_%d.tres" % (i % 40), "n": i * 3 + 1, "tier": 1 + i % 5,
			"rareza": i % 4, "banda": i % 3, "mejoras": {}})
	return out


func test_ida_y_vuelta_igual() -> void:
	var d: Dictionary = {"nombre": "Dasui", "baul": _almacen(50), "dinero": 109975, "pos": Vector2(3.5, -2.0),
		"bits": PackedByteArray([1, 2, 3])}
	var vuelta: Dictionary = NET.unzip_dict(NET.zip(d))
	igual(hash(vuelta), hash(d), "el diccionario vuelve igual")
	var lista: Array = _almacen(10)
	igual(hash(NET.unzip_array(NET.zip(lista))), hash(lista), "y la lista tambien")


func test_comprime_lo_gordo() -> void:
	var bag: Array = _almacen(700)
	var antes: int = var_to_bytes(bag).size()
	var ahora: int = var_to_bytes(NET.zip(bag)).size()
	cierto(ahora * 5 < antes, "un almacen de 700 montones, a menos de una quinta parte (%d B frente a %d)" % [ahora, antes])


func test_paquete_raro_no_rompe() -> void:
	igual(NET.unzip_dict([]).size(), 0, "vacio: nada")
	igual(NET.unzip_dict([10, "no son bytes"]).size(), 0, "sin bytes: nada")
	igual(NET.unzip_array([NET.ZIP_TOPE + 1, PackedByteArray([1])]).size(), 0, "por encima del tope: nada")
	var z: Array = NET.zip({"a": 1})
	z[0] = int(z[0]) + 5
	igual(NET.unzip_dict(z).size(), 0, "con el tamaño mentido: nada")
	igual(NET.unzip_dict(NET.zip([1, 2])).size(), 0, "una lista donde se esperaba diccionario: vacio")


# El aspecto (piezas + equipo) y el grupo (net_pisos.anunciar_aspecto, net_jugadores.anunciar_grupo; protocolo 60): las
# rutas del equipo viajan como ids dentro de lo comprimido y vuelven a ruta.
func test_aspecto_y_grupo_ida_y_vuelta() -> void:
	var piezas: Dictionary = {"pelo": {"id": "melena", "color": Color(0.4, 0.2, 0.1)}, "torso": {"id": "camisa", "color": Color.WHITE}}
	var equipo: Dictionary = {"arma": {"ruta": "res://resources/materials/baba_slime.tres", "tier": 2, "rareza": 1}}
	var vuelta = NET.unzip(NET.zip([piezas, equipo]))
	cierto(vuelta is Array and (vuelta as Array).size() == 2, "vuelve [piezas, equipo]")
	igual(hash(vuelta[0]), hash(piezas), "las piezas, iguales")
	igual(hash(vuelta[1]), hash(equipo), "el equipo, con su ruta")
	var grupo: Array = [{"nombre": "Ana", "huella": 123456789, "piezas": piezas, "equipo": equipo},
		{"nombre": "Luis", "huella": 0, "piezas": piezas, "equipo": {}}]
	igual(hash(NET.unzip_array(NET.zip(grupo))), hash(grupo), "el grupo entero, igual")
