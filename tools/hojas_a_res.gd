# ============================================================
#  PASAR LAS HOJAS HORNEADAS A .res (optimizacion 1E, 19/10/2026): por cada .json de hoja (con "anims" y su .png al
#  lado) bajo assets/sprites, escribe su DescripcionHoja en un .res con el mismo nombre. Es lo que lee el juego (ver
#  SpriteLienzo.descripcion): el json eran ~9 ms por hoja solo de leer.
#  CUANDO PASARLA: despues de tools/compactar_hojas.py, que reescribe los json (el horno ya escribe su .res, pero el
#  compactado lo deja viejo). tools/prueba_hojas_res avisa si alguno no esta al dia.
#    godot --headless --path . res://tools/hojas_a_res.tscn [-- --rehacer]
# ============================================================
extends Node

const RAIZ := "res://assets/sprites/"
# --rehacer: escribirlas todas aunque esten al dia (p. ej. al cambiar el formato).
var _rehacer: bool = OS.get_cmdline_user_args().has("--rehacer")


func _ready() -> void:
	var hechos: int = 0
	var iguales: int = 0
	for js in hojas(RAIZ):
		var texto: String = FileAccess.get_file_as_string(js)
		var res: String = js.get_basename() + ".res"
		if ResourceLoader.exists(res):
			var viejo: DescripcionHoja = ResourceLoader.load(res, "", ResourceLoader.CACHE_MODE_IGNORE) as DescripcionHoja
			if viejo != null and viejo.firma == texto.hash() and not _rehacer:
				iguales += 1
				continue
		var d = JSON.parse_string(texto)
		if ResourceSaver.save(DescripcionHoja.desde_json(d, texto.hash()), res, ResourceSaver.FLAG_COMPRESS) != OK:
			print("[hojas_a_res] NO SE PUDO ESCRIBIR %s" % res)
			continue
		hechos += 1
	print("[hojas_a_res] %d escritas, %d ya estaban al dia" % [hechos, iguales])
	get_tree().quit()


# Los .json de hoja horneada (con "anims" y su .png) bajo 'carpeta', recursivo.
static func hojas(carpeta: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(carpeta)
	if d == null:
		return out
	for sub in d.get_directories():
		out.append_array(hojas(carpeta + sub + "/"))
	for f in d.get_files():
		if not f.ends_with(".json"):
			continue
		var js: String = carpeta + f
		if not FileAccess.file_exists(js.get_basename() + ".png"):
			continue
		if not FileAccess.get_file_as_string(js).contains("\"anims\""):
			continue
		out.append(js)
	return out
