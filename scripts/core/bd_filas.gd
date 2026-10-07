# ============================================================
#  bd_filas.gd
#  UNA PARTIDA <-> FILAS DE LA BASE DE DATOS. Es lo que sustituye al .tres: el mismo SaveData de
#  siempre, partido en filas para que guardar escriba SOLO las que han cambiado.
#
#  Tres tablas:
#    - campos    (clave -> valor): cada campo de primer nivel del SaveData. Los diccionarios grandes
#                 de la mazmorra (ver PARTIDOS) van una fila por piso: "memoria_pisos/6".
#    - objetos   (id -> valor): cada Resource INCRUSTADO (tu espada +2, un personaje, un jugador)
#                 en SU fila. Quien lo usa guarda {"§o": id}: el arma equipada y la del baul siguen
#                 siendo el MISMO objeto, como en el .tres.
#    - contables (lista|cosa -> cantidad): las listas que son SOLO MaterialItem / Cristal van
#                 contadas, una fila por material+calidad+talla (su idea: no 18.000 bloques).
#
#  Los valores van con var_to_str (el formato de Godot: guarda tal cual Vector2, Color, int/float y
#  claves de cualquier tipo). Lo que no es dato de Godot se marca con un diccionario de una clave:
#    {"§r": "res://..."}  referencia a un .tres del proyecto
#    {"§o": "o12"}        objeto incrustado (fila de `objetos`)
#    {"§c": "lista"}      lista contada (filas de `contables` con ese prefijo)
#  Es GENERICO: recorre los campos guardados de cada clase (como Godot con el .tres), asi que un
#  @export nuevo entra solo, sin tocar esto. La prueba: tools/prueba_bd_ida_vuelta (huella identica).
# ============================================================
class_name BDFilas
extends RefCounted

const R := "§r"
const O := "§o"
const C := "§c"

# Diccionarios de primer nivel que van una fila por clave (por piso), no enteros.
const PARTIDOS := ["memoria_pisos", "mazmorra_persistente", "mapa_snapshot", "mapa_trabajo", "vistas_baseline"]

const _NO_SON_DATOS := {
	"script": true, "resource_path": true, "resource_name": true,
	"resource_local_to_scene": true, "resource_scene_unique_id": true,
}

# Campos guardados por clase (cache: get_property_list es caro y se pide miles de veces).
static var _campos_de: Dictionary = {}
static var _clases: Dictionary = {}   # class_name -> ruta del script


## Los ids de los objetos entre un guardado y el siguiente: el mismo objeto vivo = la misma fila.
class Ids:
	var por_instancia: Dictionary = {}   # instance_id -> id
	var siguiente: int = 1
	# El texto de cada material/cristal contado, por instancia: son VALORES (nadie los cambia tras
	# crearlos), asi que se calcula UNA vez y no en cada guardado (20.000 en su mundo).
	var contable: Dictionary = {}   # instance_id -> texto

	func nuevo() -> String:
		var id := "o%d" % siguiente
		siguiente += 1
		return id


## SaveData -> {"campos": {clave: txt}, "objetos": {id: txt}, "contables": {clave: cantidad}}, de golpe.
## (Para guardar sin tiron durante la partida: Volcado, que hace lo mismo a trocitos.)
static func a_filas(s: SaveData, ids: Ids) -> Dictionary:
	var v := Volcado.new(s, ids)
	while not v.paso(1 << 40):
		pass
	return v.out


## SACAR LAS FILAS A TROCITOS: unos ms por fotograma, para que guardar no dé tirón.
## La FOTO es el SaveData recien exportado (exportar_partida copia las listas: lo que esta en cada
## sitio queda fijo); los campos de cada objeto se leen al llegarles, como mucho unas decimas
## despues (un valor un pelin mas nuevo, nunca un objeto perdido ni repetido).
class Volcado:
	const TROZO_LISTA := 128
	const TROZO_CONTAR := 1000
	var out := {"campos": {}, "objetos": {}, "contables": {}}
	var ctx: Dictionary
	var _s: SaveData
	# Tareas: ["campo", nombre] | ["sub", nombre, clave] (un piso de un PARTIDO) | ["obj", Resource, id]
	# | ["cont", ruta, Array, desde] (lista contada) | ["arr", nombre, Array, desde, partes] (lista grande)
	var _cola: Array = []
	var _i: int = 0

	func _init(s: SaveData, ids: Ids) -> void:
		_s = s
		ctx = {"ids": ids, "out": out, "vistos": {}, "por_clave": {}, "contables": {}, "cola": _cola}
		for n in BDFilas._campos(s):
			_cola.append(["campo", n])

	## Avanza hasta gastar `presupuesto_us` microsegundos. true = terminado.
	func paso(presupuesto_us: int) -> bool:
		var fin: int = Time.get_ticks_usec() + presupuesto_us
		while _i < _cola.size():
			var t: Array = _cola[_i]
			_i += 1
			match t[0]:
				"campo":
					_campo(t[1])
				"obj":
					out["objetos"][t[2]] = var_to_str(BDFilas._cosa(t[1], ctx, t[2]))
				"sub":
					var clave: String = "%s/%s" % [t[1], var_to_str(t[2])]
					out["campos"][clave] = var_to_str(BDFilas._a_valor(_s.get(t[1])[t[2]], clave, ctx))
				"cont":
					if not BDFilas._contar(t[1], t[2], t[3], TROZO_CONTAR, ctx):
						_cola.append(["cont", t[1], t[2], t[3] + TROZO_CONTAR])
				"arr":
					var l: Array = t[2]
					var hasta: int = mini(l.size(), t[3] + TROZO_LISTA)
					for i in range(t[3], hasta):
						t[4].append(var_to_str(BDFilas._a_valor(l[i], t[1], ctx)))
					if hasta < l.size():
						_cola.append(["arr", t[1], l, hasta, t[4]])
					else:
						out["campos"][t[1]] = "[" + ", ".join(t[4]) + "]"
			if Time.get_ticks_usec() >= fin:
				return false
		_terminar()
		return true

	func _campo(n: String) -> void:
		var v = _s.get(n)
		if n in BDFilas.PARTIDOS and v is Dictionary:
			out["campos"][n] = var_to_str({"§partido": true})
			for k in v:
				_cola.append(["sub", n, k])
			return
		if v is Array and v.size() > TROZO_LISTA and not BDFilas._parece_contable(v):
			_cola.append(["arr", n, v, 0, PackedStringArray()])
			return
		out["campos"][n] = var_to_str(BDFilas._a_valor(v, n, ctx))

	# Ids de objetos que ya no salen: se olvidan (su fila la borra quien escribe, por diferencia).
	func _terminar() -> void:
		var ids: Ids = ctx["ids"]
		var vivos: Dictionary = ctx["vistos"]
		for iid in ids.por_instancia.keys():
			if not vivos.has(iid):
				ids.por_instancia.erase(iid)
		ids.contable = ctx["contables"]


## Filas -> SaveData nuevo (y los ids de sus objetos apuntados en `ids`, para que el guardado
## siguiente reconozca los mismos objetos y no reescriba nada).
static func de_filas(f: Dictionary, ids: Ids) -> SaveData:
	var objs: Dictionary = {}   # id -> Resource (vacio aun)
	var crudos: Dictionary = {}
	for id in f["objetos"]:
		var d = str_to_var(f["objetos"][id])
		crudos[id] = d
		objs[id] = _instanciar(String(d.get("_clase", "")))
	var listas: Dictionary = {}   # lista -> Array de objetos contados
	for clave in f["contables"]:
		var corte: int = String(clave).find("|")
		var lista: String = String(clave).substr(0, corte)
		var d = str_to_var(String(clave).substr(corte + 1))
		var n: int = int(f["contables"][clave])
		if not listas.has(lista):
			listas[lista] = []
		for i in n:
			if not (d is Dictionary and d.has("_clase")):
				listas[lista].append(_de_valor(d, objs, listas))   # lo que no era material (ver _contar)
				continue
			var it: Resource = _instanciar(String(d.get("_clase", "")))
			_rellenar(it, d, objs, listas)
			listas[lista].append(it)
	for id in objs:
		_rellenar(objs[id], crudos[id], objs, listas)
		if String(id).begins_with("o"):
			ids.siguiente = maxi(ids.siguiente, int(String(id).substr(1)) + 1)
		ids.por_instancia[objs[id].get_instance_id()] = id
	var s := SaveData.new()
	var campos: Dictionary = f["campos"]
	for n in _campos(s):
		if not campos.has(n):
			continue
		var v = str_to_var(campos[n])
		if v is Dictionary and v.has("§partido"):
			var d: Dictionary = {}
			var pref: String = n + "/"
			for clave in campos:
				if String(clave).begins_with(pref):
					d[str_to_var(String(clave).substr(pref.length()))] = _de_valor(str_to_var(campos[clave]), objs, listas)
			_poner(s, n, d)
		else:
			_poner(s, n, _de_valor(v, objs, listas))
	return s


# ------------------------------------------------------------  ida

static func _a_valor(v, ruta: String, ctx: Dictionary):
	if v is Resource:
		return _ref(v, ctx)
	if v is Dictionary:
		var d: Dictionary = {}
		for k in v:
			d[k] = _a_valor(v[k], ruta, ctx)
		return d
	if v is Array:
		if _parece_contable(v):
			ctx["cola"].append(["cont", ruta, v, 0])
			return {C: ruta}
		var l: Array = []
		for e in v:
			l.append(_a_valor(e, ruta, ctx))
		return l
	return v


# Cuenta `cuantos` de una lista contada desde `desde`. true = ya no queda nada de esa lista.
static func _contar(ruta: String, v: Array, desde: int, cuantos: int, ctx: Dictionary) -> bool:
	var ids: Ids = ctx["ids"]
	var cuenta: Dictionary = ctx["out"]["contables"]
	var nuevos: Dictionary = ctx["contables"]
	var hasta: int = mini(v.size(), desde + cuantos)
	for i in range(desde, hasta):
		var it = v[i]
		var txt: String
		if it is MaterialItem or it is Cristal:
			var iid: int = it.get_instance_id()
			txt = ids.contable.get(iid, "")
			if txt == "":
				txt = var_to_str(_cosa(it, ctx))
			nuevos[iid] = txt
		else:
			# Algo que no es un material en una lista de materiales: no se pierde, va tal cual
			# (un objeto, su fila; un valor, el valor) y se cuenta como uno mas.
			txt = var_to_str(_a_valor(it, ruta, ctx))
		var clave: String = ruta + "|" + txt
		cuenta[clave] = int(cuenta.get(clave, 0)) + 1
	return hasta >= v.size()


# Un Resource dentro de un valor: referencia al proyecto, o su fila de objeto.
static func _ref(r: Resource, ctx: Dictionary):
	var rp: String = r.resource_path
	if rp.begins_with("res://") and not rp.contains("::"):
		return {R: rp}
	var iid: int = r.get_instance_id()
	var ids: Ids = ctx["ids"]
	if ctx["vistos"].has(iid):
		return {O: ids.por_instancia[iid]}
	var id: String = ids.por_instancia.get(iid, "")
	if id == "":
		# El JugadorData de MI jugador se rehace en cada exportar: por su identidad, no por
		# instancia, o cada guardado lo escribiria como objeto nuevo.
		if r is JugadorData and String(r.id) != "" and not ctx["por_clave"].has("jd:" + String(r.id)):
			id = "jd:" + String(r.id)
		else:
			id = ids.nuevo()
	ctx["por_clave"][id] = true
	ids.por_instancia[iid] = id
	ctx["vistos"][iid] = true
	ctx["cola"].append(["obj", r, id])   # sus campos, cuando le toque (Volcado)
	return {O: id}


# Los campos guardados de un objeto, ya convertidos. `ruta` = prefijo de sus listas contadas.
static func _cosa(r: Resource, ctx: Dictionary, ruta: String = "") -> Dictionary:
	var d: Dictionary = {"_clase": _clase(r)}
	for n in _campos(r):
		d[n] = _a_valor(r.get(n), "%s.%s" % [ruta, n], ctx)
	return d


# ------------------------------------------------------------  vuelta

static func _de_valor(v, objs: Dictionary, listas: Dictionary):
	if v is Dictionary:
		if v.size() == 1:
			if v.has(R):
				return load(String(v[R]))
			if v.has(O):
				return objs.get(String(v[O]))
			if v.has(C):
				return listas.get(String(v[C]), []).duplicate()
		var d: Dictionary = {}
		for k in v:
			d[k] = _de_valor(v[k], objs, listas)
		return d
	if v is Array:
		var l: Array = []
		for e in v:
			l.append(_de_valor(e, objs, listas))
		return l
	return v


static func _rellenar(r: Resource, d: Dictionary, objs: Dictionary, listas: Dictionary) -> void:
	if r == null:
		return
	for n in d:
		if n == "_clase":
			continue
		_poner(r, n, _de_valor(d[n], objs, listas))


# Poner un campo respetando los arrays/diccionarios TIPADOS (un Array suelto en un Array[X] no entra).
static func _poner(o: Object, n: String, v) -> void:
	var actual = o.get(n)
	if v is Array and actual is Array and actual.is_typed():
		var t: Array = actual.duplicate()
		t.clear()
		t.assign(v)
		o.set(n, t)
		return
	if v is Dictionary and actual is Dictionary and actual.is_typed():
		var t: Dictionary = actual.duplicate()
		t.clear()
		t.assign(v)
		o.set(n, t)
		return
	o.set(n, v)


static func _instanciar(clase: String) -> Resource:
	if _clases.is_empty():
		for c in ProjectSettings.get_global_class_list():
			_clases[String(c["class"])] = String(c["path"])
	if _clases.has(clase):
		return load(_clases[clase]).new()
	if clase.begins_with("res://"):
		return load(clase).new()
	if ClassDB.can_instantiate(clase):
		return ClassDB.instantiate(clase)
	push_error("[bd] clase desconocida al leer: %s" % clase)
	return null


# ------------------------------------------------------------  comun

static func _campos(o: Object) -> Array:
	var s = o.get_script()
	var clave = s if s != null else o.get_class()
	var l: Array
	if _campos_de.has(clave):
		l = _campos_de[clave]
	else:
		l = []
		for p in o.get_property_list():
			var n: String = p["name"]
			if int(p["usage"]) & PROPERTY_USAGE_STORAGE and not _NO_SON_DATOS.has(n) and not n.begins_with("metadata/"):
				l.append(n)
		_campos_de[clave] = l
	# Los METADATOS (set_meta) son de cada objeto, no de su clase, y Godot tambien los guarda:
	# se añaden objeto a objeto (en su mundo habia "cds", "aguante", "cuerpo_red" en los personajes).
	var metas: Array = o.get_meta_list()
	if metas.is_empty():
		return l
	var con: Array = l.duplicate()
	for m in metas:
		con.append("metadata/" + String(m))
	return con


static func _clase(o: Object) -> String:
	var s = o.get_script()
	if s is Script:
		var g: String = s.get_global_name()
		return g if g != "" else s.resource_path
	return o.get_class()


# Una lista se guarda CONTADA si empieza por un material o un cristal (lo que venga despues que no
# lo sea tambien se guarda, ver _contar: esto solo decide la forma, no se pierde nada).
static func _parece_contable(l: Array) -> bool:
	return not l.is_empty() and (l[0] is MaterialItem or l[0] is Cristal)
