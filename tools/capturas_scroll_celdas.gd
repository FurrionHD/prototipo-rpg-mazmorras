# ============================================================
#  CAPTURA + COMPROBACION (con ventana): al bajar con el scroll, las celdas que estaban fuera de la vista SE PINTAN.
#  Desde el 16/10/2026 las celdas se apuntan en una lista del scroll en vez de engancharse dos veces cada una (ver
#  CeldaObjeto._enganchar_scroll). Sin ventana Godot no dibuja, asi que esto solo se puede ver aqui.
#    godot --path . res://tools/capturas_scroll_celdas.tscn
#  Guarda tools/salida/scroll_celdas_arriba.png y _abajo.png y dice cuantas celdas A LA VISTA siguen sin pintar.
# ============================================================
extends Node

var fallos := 0

func _ok(c: bool, t: String) -> void:
	print(("[PASA] " if c else "[FALLA] ") + t)
	if not c:
		fallos += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	var inv = load("res://scripts/ui/inventory_menu.gd").new()
	add_child(inv)
	await get_tree().process_frame
	inv._set_open(true)
	inv._on_tab(inv.TABS.find("Materiales"))
	for i in 150:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("res://tools/salida/")
	await _captura("arriba")
	var scroll: ScrollContainer = inv._lista.get_parent() as ScrollContainer
	while scroll != null and not (scroll is ScrollContainer):
		scroll = scroll.get_parent() as ScrollContainer
	for paso in 12:   # a saltos, como la rueda
		scroll.scroll_vertical += 400
		await get_tree().process_frame
	for i in 10:
		await get_tree().process_frame
	await _captura("abajo")
	var vistas: int = 0
	var sin_pintar: int = 0
	var conectadas: int = scroll.get_v_scroll_bar().value_changed.get_connections().size()
	for g in inv._lista.get_children():
		if g is GridContainer and not MenuScaffold.muriendo(g):
			for c in g.get_children():
				if c is CeldaObjeto and scroll.get_global_rect().intersects((c as Control).get_global_rect()):
					vistas += 1
					if (c as CeldaObjeto)._pendiente:
						sin_pintar += 1
	_ok(vistas > 20, "abajo del todo hay celdas a la vista: %d" % vistas)
	_ok(sin_pintar == 0, "y ninguna se queda sin pintar (%d)" % sin_pintar)
	_ok(conectadas <= 3, "el scroll tiene %d conexiones (antes, dos por celda)" % conectadas)
	print("[scroll_celdas] RESULTADO: ", "FIN: TODO BIEN" if fallos == 0 else "FALLAN %d" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)


func _captura(nombre: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tools/salida/scroll_celdas_%s.png" % nombre)
