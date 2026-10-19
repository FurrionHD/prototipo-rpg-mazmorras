extends Node
# ============================================================
#  CORREDOR DE LAS PRUEBAS UNITARIAS
# ============================================================
# Pasa todos los tools/unitarias/test_*.gd en ESTE Godot, uno tras otro, y acaba con `FIN: TODO BIEN` o con
# lineas `MAL: ...` (el formato que entiende tools/pasar_pruebas.py, que la recoge sola como prueba_unitarias).
#
#   godot --headless --path . res://tools/prueba_unitarias.tscn               # todas
#   godot --headless --path . res://tools/prueba_unitarias.tscn -- stats bd   # solo los archivos con esas palabras
#   python tools/pasar_pruebas.py --unitarias                                  # lo mismo, por el lanzador
#
# Un error de script dentro de un test (null, indice fuera...) NO corta la tanda: el registro de errores de
# abajo lo apunta como fallo de ese test y se sigue con el siguiente.

const CARPETA := "res://tools/unitarias/"


class _Registro extends Logger:
	var errores: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		errores.append("%s (%s:%d en %s)" % [rationale if rationale != "" else code, file.get_file(), line, function])

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _registro := _Registro.new()


func _ready() -> void:
	OS.add_logger(_registro)
	var filtros: PackedStringArray = OS.get_cmdline_user_args()
	var t0 := Time.get_ticks_usec()
	var archivos := _archivos(filtros)
	var total_tests := 0
	var total_comp := 0
	var malos: Array[String] = []
	for ruta in archivos:
		var t_arch := Time.get_ticks_usec()
		var guion: GDScript = load(ruta)
		if guion == null or not guion.can_instantiate():
			malos.append("%s: no se puede cargar (¿error de sintaxis?)" % ruta.get_file())
			continue
		var caso = guion.new()
		caso.arbol = self
		var n := 0
		for m in guion.get_script_method_list():
			var nombre: String = m["name"]
			if not nombre.begins_with("test_"):
				continue
			n += 1
			caso._empezar(nombre)
			_registro.errores.clear()
			caso.call(nombre)
			for e in _registro.errores:
				caso._fallo("ERROR DE SCRIPT: " + e)
		total_tests += n
		total_comp += caso.comprobaciones
		for f in caso.fallos:
			malos.append("%s > %s" % [ruta.get_file().get_basename(), f])
		print("%-34s %3d tests %4d comprobaciones %6.1f ms%s" % [ruta.get_file(), n, caso.comprobaciones,
			(Time.get_ticks_usec() - t_arch) / 1000.0, "" if caso.fallos.is_empty() else "  <- %d MAL" % caso.fallos.size()])
	OS.remove_logger(_registro)
	print("\n%d archivos, %d tests, %d comprobaciones en %.1f ms" % [archivos.size(), total_tests, total_comp,
		(Time.get_ticks_usec() - t0) / 1000.0])
	for f in malos:
		print("MAL: " + f)
	if archivos.is_empty():
		print("MAL: no hay ningun test_*.gd que pasar (filtros: %s)" % str(filtros))
		get_tree().quit(1)
		return
	print("FIN: TODO BIEN" if malos.is_empty() else "FIN: %d fallos" % malos.size())
	get_tree().quit(0 if malos.is_empty() else 1)


func _archivos(filtros: PackedStringArray) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(CARPETA):
		if not (f.begins_with("test_") and f.ends_with(".gd")):
			continue
		if not filtros.is_empty():
			var vale := false
			for fi in filtros:
				if fi in f:
					vale = true
			if not vale:
				continue
		out.append(CARPETA + f)
	out.sort()
	return out
