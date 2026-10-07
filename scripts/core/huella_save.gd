# ============================================================
#  huella_save.gd
#  HUELLA CANONICA DE UNA PARTIDA: todo lo que guarda un SaveData, pasado a valores simples
#  para poder COMPARAR dos partidas campo a campo. Es la red de seguridad del paso a la base de
#  datos: una partida solo se da por migrada si su huella sale IDENTICA antes y despues.
#
#  Las reglas (lo mismo vale lo mismo aunque cambie como se guarda):
#    - Un Resource del proyecto (.tres en res://) es una REFERENCIA: vale "res:<ruta>".
#    - Un Resource incrustado (tu espada +2, un MaterialItem) vale {"_clase", y sus campos
#      guardados}, recorrido entero. Si nadie lo conoce, sale igual: nada se escapa por omision.
#    - Los bytes (las caras PNG) valen "bytes:<tamaño>:<sha256>".
#    - Las listas SOLO de MaterialItem / Cristal se ordenan: la BD los guarda contados (una fila
#      por material), y el orden de las unidades en la bolsa no es un dato.
#    - Las claves de los diccionarios van con var_to_str (1 y "1" son claves distintas).
#    - "_compartidos": los objetos incrustados que salen en MAS DE UN sitio (el arma equipada que
#      es la misma del baul). Al leerlo de vuelta tienen que seguir siendo uno solo. Menos los
#      MaterialItem/Cristal: son valores (nadie los modifica tras crearlos) y la BD los cuenta.
# ============================================================
class_name HuellaSave
extends RefCounted

# Campos de Resource que no son datos de la partida.
const _NO_SON_DATOS := {
	"script": true, "resource_path": true, "resource_name": true,
	"resource_local_to_scene": true, "resource_scene_unique_id": true,
}


## La huella de una partida (o de cualquier Resource guardado).
static func de(res: Resource) -> Dictionary:
	var vistos: Dictionary = {}   # instance_id -> primera ruta donde salio
	var compartidos: Array = []
	# La raiz se recorre SIEMPRE, aunque venga de un fichero (si no, seria solo "res:<su ruta>").
	var out: Dictionary = _de_resource(res, "", vistos, compartidos, {}, true)
	compartidos.sort()
	out["_compartidos"] = compartidos
	return out


## Las diferencias entre dos huellas, como lineas "ruta: antes -> despues" (como mucho `tope`).
static func diferencias(a, b, tope: int = 200) -> Array:
	var out: Array = []
	_comparar(a, b, "", out, tope)
	return out


# ------------------------------------------------------------

static func _valor(v, ruta: String, vistos: Dictionary, compartidos: Array, pila: Dictionary):
	if v is Resource:
		return _de_resource(v, ruta, vistos, compartidos, pila)
	if v is Dictionary:
		var d: Dictionary = {}
		for k in v:
			var ck: String = var_to_str(k)
			d[ck] = _valor(v[k], "%s{%s}" % [ruta, ck], vistos, compartidos, pila)
		return d
	if v is Array:
		var l: Array = []
		var i: int = 0
		for e in v:
			l.append(_valor(e, "%s[%d]" % [ruta, i], vistos, compartidos, pila))
			i += 1
		if _solo_contables(v):
			l.sort_custom(func(x, y): return var_to_str(x) < var_to_str(y))
		return l
	if v is PackedByteArray:
		return _bytes(v)
	if v is Object:
		return "objeto:%s" % v.get_class()
	return v


static func _de_resource(r: Resource, ruta: String, vistos: Dictionary, compartidos: Array, pila: Dictionary,
		raiz: bool = false):
	var rp: String = r.resource_path
	if not raiz and rp.begins_with("res://") and not rp.contains("::"):
		return "res:" + rp
	var iid: int = r.get_instance_id()
	if pila.has(iid):
		return "ciclo:" + String(pila[iid])
	if r is MaterialItem or r is Cristal:
		pass   # son VALORES: nadie los cambia tras crearlos (mirado 07/10), compartirlos no significa nada
	elif vistos.has(iid):
		# Mismo objeto en otro sitio: se apunta la pareja y se recorre igual (la estructura cuenta).
		compartidos.append("%s = %s" % [vistos[iid], ruta])
	else:
		vistos[iid] = ruta
	pila[iid] = ruta
	var d: Dictionary = {"_clase": _clase(r)}
	for p in r.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_STORAGE):
			continue
		var n: String = p["name"]
		if _NO_SON_DATOS.has(n):
			continue
		d[n] = _valor(r.get(n), "%s.%s" % [ruta, n], vistos, compartidos, pila)
	pila.erase(iid)
	return d


static func _clase(o: Object) -> String:
	var s = o.get_script()
	if s is Script:
		var g: String = s.get_global_name()
		if g != "":
			return g
		return s.resource_path
	return o.get_class()


static func _solo_contables(l: Array) -> bool:
	if l.is_empty():
		return false
	for e in l:
		if not (e is MaterialItem or e is Cristal):
			return false
	return true


static func _bytes(b: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	if not b.is_empty():
		ctx.update(b)
	return "bytes:%d:%s" % [b.size(), ctx.finish().hex_encode()]


static func _comparar(a, b, ruta: String, out: Array, tope: int) -> void:
	if out.size() >= tope:
		return
	if a is Dictionary and b is Dictionary:
		for k in a:
			if not b.has(k):
				out.append("%s.%s: SOBRA en la primera (%s)" % [ruta, k, _corto(a[k])])
			else:
				_comparar(a[k], b[k], "%s.%s" % [ruta, k], out, tope)
		for k in b:
			if not a.has(k):
				out.append("%s.%s: FALTA en la primera (%s)" % [ruta, k, _corto(b[k])])
		return
	if a is Array and b is Array:
		if a.size() != b.size():
			out.append("%s: %d elementos -> %d" % [ruta, a.size(), b.size()])
			return
		for i in a.size():
			_comparar(a[i], b[i], "%s[%d]" % [ruta, i], out, tope)
		return
	if typeof(a) != typeof(b) or a != b:
		out.append("%s: %s -> %s" % [ruta, _corto(a), _corto(b)])


static func _corto(v) -> String:
	var s: String = var_to_str(v)
	return s if s.length() <= 120 else s.substr(0, 117) + "..."
