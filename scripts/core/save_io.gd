# ============================================================
#  save_io.gd  (class_name SaveIO, todo estatico)
#  LEER Y ESCRIBIR una partida por RUTA, sin saber nada de ranuras ni de mundos.
#
#  Existe porque hay DOS colecciones de partidas que necesitan lo mismo: las ranuras de un jugador
#  (Perfil, user://saves) y los mundos compartidos (Mundos, user://mundos). Antes de esto, la unica
#  copia de "¿esta partida se puede abrir?" vivia dentro de Perfil.inspeccionar(), atada a
#  slot_%d.tres.
#
#  Y resuelve el desajuste con la nube: la Nube trabaja con BYTES (asi hablara el Worker) mientras
#  que Godot solo carga un .tres por RUTA (ResourceLoader no lee de un buffer). Aqui esta el unico
#  sitio donde se traduce una cosa en la otra.
# ============================================================

extends RefCounted
class_name SaveIO

# En que estado esta una partida. Solo VACIA es un hueco libre: las otras tres son una partida que
# ESTA AHI y que este build no puede abrir, y presentarlas como hueco es perder datos por un clic.
enum {
	VACIA,        # no hay fichero
	OK,           # se puede jugar
	MAS_VIEJA,    # de un build anterior: este build ya no entiende ese esquema
	MAS_NUEVA,    # de un build POSTERIOR: hay que actualizar el juego, no borrarla
	ILEGIBLE,     # el fichero esta ahi pero no sale un SaveData (corrupto, a medio escribir...)
}


# Todo lo que se sabe de una partida sin tener que adivinarlo:
#   {"estado": uno de los de arriba, "version": int, "version_mundo": int, "datos": SaveData|null}
# 'datos' solo viene si estado == OK: una partida que no entendemos no se toca ni para leerla.
static func inspeccionar_ruta(ruta: String) -> Dictionary:
	if not FileAccess.file_exists(ruta):
		return {"estado": VACIA, "version": 0, "version_mundo": 0, "datos": null}
	var d = ResourceLoader.load(ruta, "", ResourceLoader.CACHE_MODE_IGNORE)
	if d == null or not (d is SaveData):
		push_warning("[save_io] %s no se puede leer" % ruta)
		return {"estado": ILEGIBLE, "version": 0, "version_mundo": 0, "datos": null}
	var s := d as SaveData
	var info := {"estado": OK, "version": s.version, "version_mundo": s.version_mundo, "datos": s}
	if s.version < SaveData.VERSION_ACTUAL:
		# Una partida de una version vieja: mejor ignorarla entera que cargarla a medias y dejar el
		# juego en un estado imposible.
		push_warning("[save_io] %s es de una version antigua (%d): se ignora" % [ruta, s.version])
		info["estado"] = MAS_VIEJA
	elif s.version > SaveData.VERSION_ACTUAL:
		# La escribio un build MAS NUEVO. Cargarla seria perder los campos que este build no conoce
		# (Godot descarta lo que no entiende y lo reescribe sin ello).
		push_warning("[save_io] %s es de una version MAS NUEVA (%d > %d)" % [ruta, s.version, SaveData.VERSION_ACTUAL])
		info["estado"] = MAS_NUEVA
	elif s.version_mundo > SaveData.VERSION_MUNDO:
		# Mismo esquema de save, pero el MUNDO trae dentro cosas que este build no sabe guardar.
		# Abrirlo perderia a los jugadores de dentro: ver la nota de SaveData.VERSION_MUNDO.
		push_warning("[save_io] %s es un mundo de una version MAS NUEVA (%d > %d)" % [ruta, s.version_mundo, SaveData.VERSION_MUNDO])
		info["estado"] = MAS_NUEVA
	if info["estado"] != OK:
		info["datos"] = null
	return info


# Como se llama la razon por la que una partida no se puede jugar, para pintarla tal cual.
# Cadena vacia si esta bien o si no hay nada (ahi no hay nada que explicar).
static func motivo_texto(info: Dictionary) -> String:
	match int(info.get("estado", VACIA)):
		MAS_NUEVA:
			return "partida de una versión MÁS NUEVA (v%d) · actualiza el juego" % _version_mostrada(info)
		MAS_VIEJA:
			return "partida de una versión anterior (v%d) · este build ya no puede abrirla" % int(info.get("version", 0))
		ILEGIBLE:
			return "el fichero está dañado o incompleto"
		_:
			return ""


# En un mundo, lo que va por delante es su version de mundo (la del save puede ser la misma).
static func _version_mostrada(info: Dictionary) -> int:
	var vm: int = int(info.get("version_mundo", 0))
	return vm if vm > SaveData.VERSION_MUNDO else int(info.get("version", 0))


# --- BYTES <-> FICHERO (la traduccion para la nube) ---------------------------------------------

static func bytes_de_ruta(ruta: String) -> PackedByteArray:
	if not FileAccess.file_exists(ruta):
		return PackedByteArray()
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		push_warning("[save_io] no se pudo leer %s" % ruta)
		return PackedByteArray()
	var b := f.get_buffer(f.get_length())
	f.close()
	return b


static func escribir_bytes(ruta: String, bytes: PackedByteArray) -> bool:
	if bytes.is_empty():
		return false
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	if f == null:
		push_warning("[save_io] no se pudo escribir %s" % ruta)
		return false
	f.store_buffer(bytes)
	f.close()
	return true
