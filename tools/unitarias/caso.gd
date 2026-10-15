extends RefCounted
# ============================================================
#  BASE DE LAS PRUEBAS UNITARIAS (tools/unitarias/test_*.gd)
# ============================================================
# Cada archivo test_<tema>.gd hace `extends "res://tools/unitarias/caso.gd"` y trae funciones `test_<algo>()`.
# Las pasa TODAS seguidas tools/unitarias/correr.gd en UN solo Godot, sin cargar partida ni escena: tienen que
# tardar milisegundos. Solo logica pura (cuentas, tablas, conversiones); lo que cruza piezas (fisica, red,
# guardado real, una pelea entera) sigue en las pruebas de integracion (tools/prueba_*.tscn).
#
# Comprobaciones (cada fallo se apunta con el nombre del test y NO corta el resto del test):
#   cierto(cond, "que deberia pasar")
#   igual(obtenido, esperado, "que es")
#   cerca(obtenido, esperado, tolerancia, "que es")     # floats
#   entre(x, minimo, maximo, "que es")                    # ambos incluidos

var fallos: Array[String] = []
var comprobaciones: int = 0
var _test: String = ""


func _empezar(nombre_test: String) -> void:
	_test = nombre_test


func _fallo(msg: String) -> void:
	fallos.append("%s: %s" % [_test, msg])


func cierto(cond: bool, msg: String = "") -> bool:
	comprobaciones += 1
	if not cond:
		_fallo(msg if msg != "" else "no se cumple")
	return cond


func igual(obtenido, esperado, msg: String = "") -> bool:
	comprobaciones += 1
	var ok: bool = typeof(obtenido) == typeof(esperado) and obtenido == esperado
	# int contra float con el mismo valor cuenta como igual (3 == 3.0)
	if not ok and (obtenido is int or obtenido is float) and (esperado is int or esperado is float):
		ok = float(obtenido) == float(esperado)
	if not ok:
		_fallo("%s -> sale %s, se esperaba %s" % [msg, str(obtenido), str(esperado)])
	return ok


func cerca(obtenido: float, esperado: float, tolerancia: float = 0.0001, msg: String = "") -> bool:
	comprobaciones += 1
	if absf(obtenido - esperado) > tolerancia:
		_fallo("%s -> sale %s, se esperaba %s (±%s)" % [msg, str(obtenido), str(esperado), str(tolerancia)])
		return false
	return true


func entre(x: float, minimo: float, maximo: float, msg: String = "") -> bool:
	comprobaciones += 1
	if x < minimo or x > maximo:
		_fallo("%s -> sale %s, fuera de [%s, %s]" % [msg, str(x), str(minimo), str(maximo)])
		return false
	return true
