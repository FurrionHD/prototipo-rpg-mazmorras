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
	get_tree().quit()


func _captura(nombre: String) -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ruta: String = "%smenu_inicio_%s.png" % [SALIDA, nombre]
	get_viewport().get_texture().get_image().save_png(ruta)
	print("[titulo] ", ProjectSettings.globalize_path(ruta))
