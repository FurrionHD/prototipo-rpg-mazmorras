# PRUEBA (sin ventana): los ajustes de MAQUINA conviven en el mismo fichero.
#
# user://ajustes.cfg lo escriben dos autoloads: Sonido (los volumenes) y Ventana (el modo de
# pantalla). Los dos tienen que LEER antes de escribir; si uno guarda un ConfigFile recien hecho, le
# borra la seccion al otro y el jugador se encuentra el volumen (o la pantalla) reseteado al volver.
#
# Se hace copia del fichero de verdad al empezar y se devuelve tal cual al terminar: esto no puede
# llevarse por delante los ajustes de quien lo ejecute.
extends Node

var _malos: int = 0
var _copia: PackedByteArray = PackedByteArray()
var _habia: bool = false


func _ok(texto: String, cond: bool) -> void:
	print(("  ok   " if cond else "  MAL  ") + texto)
	if not cond:
		_malos += 1


func _ready() -> void:
	print("=== AJUSTES DE MAQUINA (volumen + pantalla) ===")
	_habia = FileAccess.file_exists(Ventana.RUTA_AJUSTES)
	if _habia:
		_copia = FileAccess.get_file_as_bytes(Ventana.RUTA_AJUSTES)

	# 1) Guardar la pantalla no se lleva los volumenes.
	Sonido.fijar_volumen("musica", 0.42)
	Sonido.guardar_ajustes()
	Ventana.aplicar(Ventana.Modo.SIN_BORDES)
	var cfg := ConfigFile.new()
	cfg.load(Ventana.RUTA_AJUSTES)
	_ok("tras guardar la pantalla, el volumen sigue en el fichero",
		is_equal_approx(float(cfg.get_value(Sonido.SECCION_VOL, "musica", -1.0)), 0.42))
	_ok("y la pantalla tambien", int(cfg.get_value(Ventana.SECCION, "modo", -1)) == Ventana.Modo.SIN_BORDES)

	# 2) Y al reves: mover un volumen no se lleva la pantalla.
	Sonido.fijar_volumen("musica", 0.77)
	Sonido.guardar_ajustes()
	var cfg2 := ConfigFile.new()
	cfg2.load(Ventana.RUTA_AJUSTES)
	_ok("tras guardar el volumen, la pantalla sigue en el fichero",
		int(cfg2.get_value(Ventana.SECCION, "modo", -1)) == Ventana.Modo.SIN_BORDES)
	_ok("con el volumen nuevo",
		is_equal_approx(float(cfg2.get_value(Sonido.SECCION_VOL, "musica", -1.0)), 0.77))

	# 3) Un modo fuera de rango (fichero a mano, version vieja) no rompe nada.
	Ventana.aplicar(99)
	_ok("un modo imposible se recorta al ultimo valido", Ventana.modo == Ventana.MODOS.size() - 1)

	_restaurar()
	print("FIN, %d fallos" % _malos)
	get_tree().quit(_malos)


func _restaurar() -> void:
	if _habia:
		var f := FileAccess.open(Ventana.RUTA_AJUSTES, FileAccess.WRITE)
		if f != null:
			f.store_buffer(_copia)
			f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Ventana.RUTA_AJUSTES))
