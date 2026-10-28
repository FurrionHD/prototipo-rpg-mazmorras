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
