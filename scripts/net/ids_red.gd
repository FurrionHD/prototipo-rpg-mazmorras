# ============================================================
#  ids_red.gd  (class_name IdsRed)
#  LOS IDS DE LA RED: cada .tres del juego tiene un NUMERO de 16 bits, y por la red viaja ese numero en vez de su ruta
#  ("res://resources/materials/baba_slime.tres", ~45 bytes, en cada drop, cada delta del baul, cada accion de combate...).
#
#  SOLO RED (decision del jefe, 29/10/2026): los guardados siguen con rutas, que aguantan que se añadan o se quiten .tres
#  entre versiones. Aqui no hace falta: la tabla se construye al arrancar ORDENANDO las rutas, asi que dos maquinas con
#  el MISMO build tienen los mismos numeros. Y para que dos builds distintos no se entiendan mal sin enterarse, el SELLO
#  de la tabla va en el saludo (Net._saludar) y si no cuadra se rechaza como una version distinta.
#
#  EN LA FRONTERA DE LA RED (a_red / de_red): los dicts del juego llevan "ruta" (texto) y asi se GUARDAN (el suelo y las
#  fotos de los pisos de la sala van al disco); solo al mandarlos se cambia cada "ruta" por su numero, y al recibirlos se
#  deshace. Asi lo que se guarda no depende nunca de la tabla.
#
#  Se lista con ResourceLoader.list_directory, que en el .exe tambien enumera el .pck con los nombres de antes de
#  exportar (ver Game._rutas_de). Una ruta que no este en la tabla da 0 y un error: lo que viaja tiene que estar.
# ============================================================
class_name IdsRed
extends RefCounted

# De donde salen los recursos que viajan: el contenido del juego (resources/) y los datos de los enemigos (scenes/).
const RAICES := ["res://resources", "res://scenes"]
const TOPE := 65535   # caben en 16 bits (el 0 es "nada")

static var _rutas: PackedStringArray = PackedStringArray()
static var _id_de: Dictionary = {}
static var _sello: int = 0


static func _montar() -> void:
	if not _rutas.is_empty():
		return
	var todas: Array = []
	for raiz in RAICES:
		_listar(raiz, todas)
	todas.sort()
	_rutas = PackedStringArray(todas)
	_id_de.clear()
	for i in _rutas.size():
		_id_de[_rutas[i]] = i + 1
	_sello = hash("\n".join(_rutas))
	if _rutas.size() >= TOPE:
		push_error("[ids] %d recursos: no caben en 16 bits" % _rutas.size())


static func _listar(carpeta: String, out: Array) -> void:
	for f in ResourceLoader.list_directory(carpeta):
		if f.ends_with("/"):
			_listar(carpeta + "/" + f.trim_suffix("/"), out)
		elif f.ends_with(".tres") or f.ends_with(".res"):
			out.append(carpeta + "/" + f)


# El numero de un recurso (o de su ruta). 0 = nada (null o ruta vacia). Si no esta en la tabla, 0 y un error.
static func de(r) -> int:
	_montar()
	var ruta: String = (r as Resource).resource_path if r is Resource else String(r) if r != null else ""
	if ruta.is_empty():
		return 0
	var id: int = int(_id_de.get(ruta, 0))
	if id == 0:
		push_error("[ids] %s no esta en la tabla de la red (IdsRed.RAICES)" % ruta)
	return id


# La ruta de un numero ("" si no es ninguno).
static func ruta(id: int) -> String:
	_montar()
	return _rutas[id - 1] if id >= 1 and id <= _rutas.size() else ""


# El recurso de un numero (null si no es ninguno). load() cachea: es la misma instancia que en el resto del juego.
static func cargar(id: int) -> Resource:
	var r: String = ruta(id)
	return load(r) if not r.is_empty() else null


# El sello de la tabla: el mismo en dos maquinas solo si tienen exactamente los mismos recursos.
static func sello() -> int:
	_montar()
	return _sello


# LO QUE SE MANDA: una copia de 'v' con cada "ruta" de texto cambiada por su numero, en dicts y arrays anidados. Una
# ruta que no este en la tabla (un recurso hecho en runtime) se queda en texto: el otro lado la entiende igual.
static func a_red(v):
	_montar()
	if v is Dictionary:
		var out: Dictionary = {}
		for k in v:
			var x = v[k]
			if k is String and k == CLAVE and x is String:
				var id: int = int(_id_de.get(x, 0))
				out[k] = id if id != 0 else x
			else:
				out[k] = a_red(x)
		return out
	if v is Array:
		var out_a: Array = []
		out_a.resize((v as Array).size())
		for i in (v as Array).size():
			out_a[i] = a_red(v[i])
		return out_a
	return v


# LO QUE LLEGA: lo contrario. Un "ruta" que ya es texto se queda (las llamadas locales no pasan por a_red).
static func de_red(v):
	if v is Dictionary:
		var out: Dictionary = {}
		for k in v:
			var x = v[k]
			if k is String and k == CLAVE and x is int:
				out[k] = ruta(x)
			else:
				out[k] = de_red(x)
		return out
	if v is Array:
		var out_a: Array = []
		out_a.resize((v as Array).size())
		for i in (v as Array).size():
			out_a[i] = de_red(v[i])
		return out_a
	return v


const CLAVE := "ruta"


# Una LISTA de rutas ("" = hueco) en numeros (0 = hueco), y al reves. Lo que ya venga en el otro formato se respeta.
static func lista_a_red(lista) -> Array:
	return (lista as Array).map(func(x): return de(x) if x is String else x)


static func lista_de_red(lista) -> Array:
	return (lista as Array).map(func(x): return ruta(int(x)) if x is int else x)


# Un DICT con rutas de CLAVE ({ruta: cuantas}) con numeros de clave, y al reves.
static func claves_a_red(d) -> Dictionary:
	var out: Dictionary = {}
	for k in (d as Dictionary):
		out[de(k) if k is String else k] = d[k]
	return out


static func claves_de_red(d) -> Dictionary:
	var out: Dictionary = {}
	for k in (d as Dictionary):
		out[ruta(int(k)) if k is int else k] = d[k]
	return out


static func cuantos() -> int:
	_montar()
	return _rutas.size()
