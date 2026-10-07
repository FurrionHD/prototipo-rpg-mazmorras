# ============================================================
#  partida_bd.gd
#  UNA PARTIDA EN SU BASE DE DATOS: un fichero SQLite por partida (user://bd/<clave>.sqlite), con
#  las filas de BDFilas. Cada partida es SU base de datos: lo de una nunca toca a otra.
#
#  Escribir compara con lo ultimo escrito y solo toca las filas que han cambiado (y borra las que
#  ya no estan), todo en UNA transaccion: o entra el guardado entero o no entra nada. Modo WAL con
#  synchronous=NORMAL: lo escrito sobrevive a que se cierre el juego de golpe (alt+F4, se cuelga);
#  lo unico que se puede perder es el ultimo guardado si se va la LUZ del PC.
#
#  `rev` cuenta los guardados que han cambiado algo: es lo que usara la nube para saber que copia
#  es mas nueva (en vez de comparar fechas).
#
#  LA NUBE (fase 2): con `rastrear` a true (los mundos compartidos), cada fila que cambia se apunta en
#  `sin_subir` en la MISMA transaccion, asi que lo que falta por subir sobrevive a un cierre de golpe.
#  `rev_nube` (en bd_meta) es el rev de la nube del que parte esta copia: -1 = nunca subida (la proxima
#  subida es entera). Ver Mundos (abrir / autoguardar) y servidor/nube (sync, bajar_bd).
# ============================================================
class_name PartidaBD
extends RefCounted

const CARPETA := "user://bd"
const ESQUEMA := 1
const TABLAS := ["campos", "objetos", "contables"]
const _COLUMNA := {"campos": "valor", "objetos": "valor", "contables": "cantidad"}
const _CLAVE := {"campos": "clave", "objetos": "id", "contables": "clave"}

var ruta: String = ""
var rev: int = 0
# Apuntar en sin_subir cada fila que cambia (los mundos compartidos: lo que hay que subir a la nube).
var rastrear: bool = false
var _db: SQLite = null
# Lo ultimo escrito (o leido), por tabla: {clave: valor}. Contra esto se calcula la diferencia.
var _ultimas: Dictionary = {}


static func ruta_de(clave: String) -> String:
	return "%s/%s.sqlite" % [CARPETA, clave]


static func existe(clave_o_ruta: String) -> bool:
	var r: String = clave_o_ruta if clave_o_ruta.ends_with(".sqlite") else ruta_de(clave_o_ruta)
	return FileAccess.file_exists(r)


## Borra el fichero de una partida (y los suyos de WAL). Para "borrar ranura".
static func borrar(clave_o_ruta: String) -> void:
	var r: String = clave_o_ruta if clave_o_ruta.ends_with(".sqlite") else ruta_de(clave_o_ruta)
	for extra in ["", "-wal", "-shm"]:
		if FileAccess.file_exists(r + extra):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(r + extra))


# Lo que pinta una lista de partidas, y nada mas (leer estos campos sueltos en vez de montar la partida
# entera: en su mundo, 240 ms por ranura).
const CAMPOS_CABECERA := ["version", "version_mundo", "nombre", "color", "metalico", "imagen",
	"color_alpha", "player_aspecto", "fecha", "cab_nivel", "cab_piso", "cab_dinero", "cab_lugar",
	"en_mazmorra", "current_floor"]


## Lo mismo que SaveIO.inspeccionar_ruta, pero de una BD ya abierta: {"estado", "version",
## "version_mundo", "datos"}. Con solo_cabecera, "datos" solo trae CAMPOS_CABECERA. `ids` se queda con
## los objetos leidos (para que el primer guardado reconozca los mismos y no reescriba nada).
static func inspeccionar(bd: PartidaBD, ids: BDFilas.Ids, solo_cabecera := false) -> Dictionary:
	var cab: Dictionary = bd.leer_campos(["version", "version_mundo"])
	var info := {"estado": SaveIO.OK, "version": int(cab.get("version", 0)),
		"version_mundo": int(cab.get("version_mundo", 0)), "datos": null}
	if not cab.has("version"):
		info["estado"] = SaveIO.ILEGIBLE
	elif info["version"] < SaveData.VERSION_ACTUAL:
		info["estado"] = SaveIO.MAS_VIEJA
	elif info["version"] > SaveData.VERSION_ACTUAL or info["version_mundo"] > SaveData.VERSION_MUNDO:
		info["estado"] = SaveIO.MAS_NUEVA
	if info["estado"] == SaveIO.OK and solo_cabecera:
		var cab_s := SaveData.new()
		var campos: Dictionary = bd.leer_campos(CAMPOS_CABECERA)
		for n in campos:
			if n in cab_s:
				BDFilas._poner(cab_s, n, campos[n])
		info["datos"] = cab_s
	elif info["estado"] == SaveIO.OK:
		info["datos"] = BDFilas.de_filas(bd.leer(), ids)
	return info


## inspeccionar() de una BD por su ruta (la abre y la cierra).
static func inspeccionar_ruta(r: String, solo_cabecera := false) -> Dictionary:
	if not existe(r):
		return {"estado": SaveIO.VACIA, "version": 0, "version_mundo": 0, "datos": null}
	var bd := PartidaBD.new()
	if not bd.abrir(r):
		return {"estado": SaveIO.ILEGIBLE, "version": 0, "version_mundo": 0, "datos": null}
	var info: Dictionary = inspeccionar(bd, BDFilas.Ids.new(), solo_cabecera)
	bd.cerrar()
	return info


func abrir(r: String) -> bool:
	cerrar()
	DirAccess.make_dir_recursive_absolute(r.get_base_dir())
	ruta = r
	_db = SQLite.new()
	_db.path = r
	_db.verbosity_level = SQLite.QUIET
	if not _db.open_db():
		push_warning("[bd] no se pudo abrir %s: %s" % [r, _db.error_message])
		_db = null
		return false
	_db.query("PRAGMA journal_mode=WAL;")
	_db.query("PRAGMA synchronous=NORMAL;")
	_db.query("CREATE TABLE IF NOT EXISTS bd_meta (clave TEXT PRIMARY KEY, valor TEXT);")
	_db.query("CREATE TABLE IF NOT EXISTS campos (clave TEXT PRIMARY KEY, valor TEXT);")
	_db.query("CREATE TABLE IF NOT EXISTS objetos (id TEXT PRIMARY KEY, valor TEXT);")
	_db.query("CREATE TABLE IF NOT EXISTS contables (clave TEXT PRIMARY KEY, cantidad INTEGER);")
	_db.query("INSERT OR IGNORE INTO bd_meta VALUES ('esquema', '%d');" % ESQUEMA)
	_db.query("INSERT OR IGNORE INTO bd_meta VALUES ('rev', '0');")
	_db.query("CREATE TABLE IF NOT EXISTS sin_subir (tabla TEXT, clave TEXT, marca INTEGER, PRIMARY KEY (tabla, clave));")
	rev = int(_meta("rev", "0"))
	_ultimas = {}
	return true


func cerrar() -> void:
	if _db != null:
		_db.close_db()
	_db = null
	_ultimas = {}


func abierta() -> bool:
	return _db != null


## Escribe unos CAMPOS sueltos (ya en forma de fila: clave -> texto), sin montar la partida entera: lo
## que cambia muy a menudo y pesa poco (las posiciones de los jugadores de un mundo, cada pocos segundos).
## Solo los que han cambiado; con rastrear quedan apuntados para la nube. Devuelve las filas tocadas.
func escribir_campos(campos: Dictionary) -> int:
	if _db == null:
		return -1
	if _ultimas.is_empty():
		leer()
	var antes: Dictionary = _ultimas.get("campos", {})
	var cambian: Array = []
	for k in campos:
		if antes.get(k) != campos[k]:
			cambian.append(k)
	if cambian.is_empty():
		return 0
	if not _db.query("BEGIN IMMEDIATE;"):
		return -1
	var ok: bool = true
	for k in cambian:
		ok = ok and _db.query_with_bindings("INSERT OR REPLACE INTO campos VALUES (?, ?);", [k, campos[k]])
		ok = ok and _apuntar("campos", k)
	ok = ok and _db.query_with_bindings("UPDATE bd_meta SET valor = ? WHERE clave = 'rev';", [str(rev + 1)])
	if not ok or not _db.query("COMMIT;"):
		_db.query("ROLLBACK;")
		return -1
	rev += 1
	for k in cambian:
		antes[k] = campos[k]
	_ultimas["campos"] = antes
	return cambian.size()


## Todas las filas, para BDFilas.de_filas. Tambien deja apuntado lo leido (para las diferencias).
func leer() -> Dictionary:
	var f: Dictionary = {}
	for t in TABLAS:
		f[t] = {}
		_db.query("SELECT %s AS k, %s AS v FROM %s;" % [_CLAVE[t], _COLUMNA[t], t])
		for fila in _db.query_result:
			f[t][String(fila["k"])] = int(fila["v"]) if t == "contables" else String(fila["v"])
	_ultimas = f.duplicate(true)
	return f


## Solo unos campos sueltos (la cabecera para la lista de partidas, sin montar la partida entera).
func leer_campos(claves: Array) -> Dictionary:
	var out: Dictionary = {}
	for c in claves:
		_db.query_with_bindings("SELECT valor FROM campos WHERE clave = ?;", [c])
		if not _db.query_result.is_empty():
			out[c] = str_to_var(String(_db.query_result[0]["valor"]))
	return out


## Escribe SOLO lo que ha cambiado desde lo ultimo escrito o leido. Devuelve cuantas filas ha tocado
## (0 = nada que hacer), o -1 si ha fallado (y entonces no ha entrado NADA: es una transaccion).
func escribir(f: Dictionary) -> int:
	if _db == null:
		return -1
	if _ultimas.is_empty():
		leer()   # primera vez: la diferencia es contra lo que ya hay en el fichero
	var tocadas: int = 0
	if not _db.query("BEGIN IMMEDIATE;"):
		push_warning("[bd] no se pudo empezar el guardado: %s" % _db.error_message)
		return -1
	var ok: bool = true
	for t in TABLAS:
		var antes: Dictionary = _ultimas.get(t, {})
		var ahora: Dictionary = f.get(t, {})
		for k in ahora:
			if antes.get(k) != ahora[k]:
				ok = ok and _db.query_with_bindings("INSERT OR REPLACE INTO %s VALUES (?, ?);" % t, [k, ahora[k]])
				ok = ok and _apuntar(t, k)
				tocadas += 1
		for k in antes:
			if not ahora.has(k):
				ok = ok and _db.query_with_bindings("DELETE FROM %s WHERE %s = ?;" % [t, _CLAVE[t]], [k])
				ok = ok and _apuntar(t, k)
				tocadas += 1
	if tocadas > 0:
		ok = ok and _db.query_with_bindings("UPDATE bd_meta SET valor = ? WHERE clave = 'rev';", [str(rev + 1)])
	if not ok:
		push_warning("[bd] el guardado ha fallado, no se escribe nada: %s" % _db.error_message)
		_db.query("ROLLBACK;")
		return -1
	if not _db.query("COMMIT;"):
		push_warning("[bd] no se pudo cerrar el guardado: %s" % _db.error_message)
		_db.query("ROLLBACK;")
		return -1
	if tocadas > 0:
		rev += 1
	for t in TABLAS:
		_ultimas[t] = f.get(t, {}).duplicate()
	return tocadas


# Con rastrear: esta fila hay que subirla. La marca es el rev de ESTE guardado: al acabar una subida
# solo se quitan las marcas que ya iban en ella (lo que cambie mientras sube se queda apuntado).
func _apuntar(t: String, k: String) -> bool:
	if not rastrear:
		return true
	return _db.query_with_bindings("INSERT OR REPLACE INTO sin_subir VALUES (?, ?, ?);", [t, k, rev + 1])


# ============================================================
#  LA NUBE
# ------------------------------------------------------------
## El rev de la nube del que parte esta copia (-1 = nunca se ha subido: la proxima subida va entera).
func rev_nube() -> int:
	return int(_meta("rev_nube", "-1"))


## ¿Queda algo por subir?
func hay_pendientes() -> bool:
	if rev_nube() < 0:
		return true
	_db.query("SELECT COUNT(*) AS n FROM sin_subir;")
	return int(_db.query_result[0]["n"]) > 0


## Lo que hay que subir: {"filas": [[tabla, clave, valor|null], ...], "completa": bool, "marca": int}.
## completa = esta copia nunca se ha subido: van TODAS las filas y la nube sustituye lo que tenga.
## La marca se le devuelve a marcar_subido cuando la nube lo haya aceptado.
func pendientes() -> Dictionary:
	var filas: Array = []
	var completa: bool = rev_nube() < 0
	for t in TABLAS:
		if completa:
			_db.query("SELECT %s AS k, %s AS v FROM %s;" % [_CLAVE[t], _COLUMNA[t], t])
		else:
			_db.query_with_bindings(("SELECT s.clave AS k, x.%s AS v FROM sin_subir s LEFT JOIN %s x "
				+ "ON x.%s = s.clave WHERE s.tabla = ?;") % [_COLUMNA[t], t, _CLAVE[t]], [t])
		for f in _db.query_result:
			filas.append([t, String(f["k"]), f["v"]])
	return {"filas": filas, "completa": completa, "marca": rev}


## La nube ha aceptado lo de pendientes(): fuera esas marcas y esta copia ya parte de `rev_n`.
func marcar_subido(marca: int, rev_n: int) -> bool:
	if not _db.query("BEGIN IMMEDIATE;"):
		return false
	var ok: bool = _db.query_with_bindings("DELETE FROM sin_subir WHERE marca <= ?;", [marca])
	ok = ok and _poner_meta("rev_nube", str(rev_n))
	if not ok or not _db.query("COMMIT;"):
		_db.query("ROLLBACK;")
		return false
	return true


## Lo bajado de la nube, encima de esta copia (completa = sustituye todo). Deja la copia en `rev_n` y sin
## nada pendiente. Una transaccion: o entra todo o nada.
func aplicar(filas: Array, completa: bool, rev_n: int) -> bool:
	if _db == null or not _db.query("BEGIN IMMEDIATE;"):
		return false
	var ok: bool = true
	if completa:
		for t in TABLAS:
			ok = ok and _db.query("DELETE FROM %s;" % t)
	for f in filas:
		var t: String = String(f[0])
		if not _CLAVE.has(t):
			continue
		if f[2] == null:
			ok = ok and _db.query_with_bindings("DELETE FROM %s WHERE %s = ?;" % [t, _CLAVE[t]], [String(f[1])])
		else:
			# Por JSON los numeros llegan como float: las cantidades son enteras.
			var v = int(f[2]) if t == "contables" else String(f[2])
			ok = ok and _db.query_with_bindings("INSERT OR REPLACE INTO %s VALUES (?, ?);" % t, [String(f[1]), v])
	ok = ok and _db.query("DELETE FROM sin_subir;")
	ok = ok and _poner_meta("rev_nube", str(rev_n))
	if not ok or not _db.query("COMMIT;"):
		push_warning("[bd] no se pudo aplicar lo bajado de la nube: %s" % _db.error_message)
		_db.query("ROLLBACK;")
		return false
	_ultimas = {}   # lo de memoria ya no es lo del fichero: la proxima diferencia, contra el fichero
	return true


## Para empezar de cero con la nube: todo pendiente (la proxima subida va entera).
func olvidar_nube() -> void:
	_db.query("DELETE FROM sin_subir;")
	_poner_meta("rev_nube", "-1")


## Un dato suelto de la BD (bd_meta): el codigo de nube de la partida, si quedo un conflicto...
func meta_leer(clave: String, por_defecto := "") -> String:
	return _meta(clave, por_defecto)


func meta_poner(clave: String, valor: String) -> bool:
	return _poner_meta(clave, valor)


## Cuantas filas quedan apuntadas sin subir (sin contar "nunca subida": eso es rev_nube() < 0).
func contar_sin_subir() -> int:
	_db.query("SELECT COUNT(*) AS n FROM sin_subir;")
	return int(_db.query_result[0]["n"])


func _poner_meta(clave: String, valor: String) -> bool:
	return _db.query_with_bindings("INSERT OR REPLACE INTO bd_meta VALUES (?, ?);", [clave, valor])


func _meta(clave: String, por_defecto: String) -> String:
	_db.query_with_bindings("SELECT valor FROM bd_meta WHERE clave = ?;", [clave])
	if _db.query_result.is_empty():
		return por_defecto
	return String(_db.query_result[0]["valor"])
