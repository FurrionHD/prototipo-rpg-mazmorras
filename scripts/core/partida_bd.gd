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
				tocadas += 1
		for k in antes:
			if not ahora.has(k):
				ok = ok and _db.query_with_bindings("DELETE FROM %s WHERE %s = ?;" % [t, _CLAVE[t]], [k])
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


func _meta(clave: String, por_defecto: String) -> String:
	_db.query_with_bindings("SELECT valor FROM bd_meta WHERE clave = ?;", [clave])
	if _db.query_result.is_empty():
		return por_defecto
	return String(_db.query_result[0]["valor"])
