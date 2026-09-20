# ============================================================
#  dev_menu_inicio.gd  --  HERRAMIENTA, no parte del juego.
#
#  Abre el MENU DEL TITULO de verdad (scripts/ui/main_menu.gd) y saca dos capturas: la lista de
#  ranuras con la columna de botones, y los AJUSTES abiertos desde ahi (volumenes + modo de
#  pantalla), que es lo que no se podia mirar sin cargar una partida.
#
#  NO TOCA TU PARTIDA: solo pinta el menu; no carga ni guarda ninguna ranura.
#
#  Con ventana (headless no dibuja UI).
#    godot --path . res://tools/visores/dev_menu_inicio.tscn
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"

var _menu: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1280, 720))

	_menu = preload("res://scripts/ui/main_menu.gd").new()
	add_child(_menu)
	await get_tree().process_frame
	await _captura("titulo")

	_menu._abrir_ajustes()
	await get_tree().process_frame
	await _captura("ajustes_sonido")
	print("[titulo] modo de pantalla que enseña el panel: %s" % Ventana.nombre_modo(Ventana.modo))

	# El otro apartado, que es el que hay que mirar: que no encoja el panel ni salte el Volver.
	_menu._ajustes._ir_a("graficos")
	await get_tree().process_frame
	await _captura("ajustes_graficos")

	_menu._cerrar_ajustes()
	await get_tree().process_frame
	print("[titulo] cerrado: la capa de ajustes queda oculta -> %s" % str(not _menu._ajustes_capa.visible))

	await _medir_sin_bordes()
	get_tree().quit()


# SIN BORDES tiene que tapar la PANTALLA ENTERA, barra de tareas incluida: si sale un alto menor que
# el de la pantalla, se esta usando el rectangulo "usable" (el escritorio sin la barra) y la barra de
# Windows se queda encima del juego. Deja el modo como estaba (aplicar() lo guarda en ajustes.cfg).
#
# Y se devuelve el FICHERO de ajustes tal cual estaba, no solo el modo en memoria: aplicar() escribe
# en user://ajustes.cfg, que es el de la maquina de quien ejecute esto. Una herramienta no puede
# dejarle el juego arrancando en pantalla completa por haber medido.
func _medir_sin_bordes() -> void:
	var habia: bool = FileAccess.file_exists(Ventana.RUTA_AJUSTES)
	var copia: PackedByteArray = FileAccess.get_file_as_bytes(Ventana.RUTA_AJUSTES) if habia \
		else PackedByteArray()
	var antes: int = Ventana.modo
	Ventana.aplicar(Ventana.Modo.SIN_BORDES)
	await get_tree().process_frame
	await get_tree().process_frame
	var p: int = DisplayServer.window_get_current_screen()
	var pantalla: Vector2i = DisplayServer.screen_get_size(p)
	var util: Vector2i = DisplayServer.screen_get_usable_rect(p).size
	var ventana: Vector2i = DisplayServer.window_get_size()
	print("[titulo] sin bordes: ventana %s  ·  pantalla %s  ·  usable (sin barra) %s" % [
		str(ventana), str(pantalla), str(util)])
	print("[titulo] ¿tapa la barra de tareas? -> %s" % str(ventana == pantalla and pantalla != util))
	Ventana.aplicar(antes)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	if habia:
		var f := FileAccess.open(Ventana.RUTA_AJUSTES, FileAccess.WRITE)
		if f != null:
			f.store_buffer(copia)
			f.close()


func _captura(nombre: String) -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ruta: String = "%smenu_inicio_%s.png" % [SALIDA, nombre]
	get_viewport().get_texture().get_image().save_png(ruta)
	print("[titulo] ", ProjectSettings.globalize_path(ruta))
