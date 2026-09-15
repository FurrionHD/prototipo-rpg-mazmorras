# ============================================================
#  tienda_cesta.gd  --  LA CESTA de la tienda: lo apuntado para vender (o comprar) de una vez.
#
#  Lo pidio el usuario con una condicion: NUNCA "toco un objeto y se lleva el monton entero". Cada cosa
#  entra con la cantidad que TU pones en la ficha, y ponerla otra vez la reemplaza (no la suma: si
#  apuntaste 6 y ahora pones 4, quieres 4).
#
#  Aqui solo vive la LISTA. Pintarla (la bandeja) es del armazon y cobrarla, de cada seccion, que es
#  quien sabe de donde sale cada cosa. Una entrada guarda el MONTON tal como estaba al apuntarlo; lo
#  que haya de verdad al cobrar lo vuelve a mirar la seccion (ver sanear).
# ============================================================
extends RefCounted

var entradas: Array = []   # [{clave, stack, n}], en el orden en que se apuntaron


func vacia() -> bool:
	return entradas.is_empty()


func _indice(clave: String) -> int:
	for i in entradas.size():
		if String(entradas[i]["clave"]) == clave:
			return i
	return -1


func cantidad_de(clave: String) -> int:
	var i: int = _indice(clave)
	return 0 if i < 0 else int(entradas[i]["n"])


# Apunta (o cambia) la cantidad de un monton. n <= 0 lo quita.
func poner(stack: Dictionary, n: int) -> void:
	var clave: String = String(stack["clave"])
	var i: int = _indice(clave)
	if n <= 0:
		if i >= 0:
			entradas.remove_at(i)
		return
	if i >= 0:
		entradas[i]["n"] = n
		entradas[i]["stack"] = stack
	else:
		entradas.append({"clave": clave, "stack": stack, "n": n})


func quitar(clave: String) -> void:
	poner({"clave": clave}, 0)


func vaciar() -> void:
	entradas.clear()


func total(precio_unidad: Callable) -> int:
	var t: int = 0
	for e in entradas:
		t += int(precio_unidad.call(e["stack"])) * int(e["n"])
	return t


# Lo apuntado ya no puede ser mas de lo que hay: si vendiste parte del monton por la ficha, o se lo
# llevo un compañero del cofre, la entrada baja a lo que queda (y desaparece si no queda nada).
# 'disponible' = Callable(stack) -> int.
func sanear(disponible: Callable) -> void:
	for i in range(entradas.size() - 1, -1, -1):
		var hay: int = int(disponible.call(entradas[i]["stack"]))
		if hay <= 0:
			entradas.remove_at(i)
		elif int(entradas[i]["n"]) > hay:
			entradas[i]["n"] = hay
