# ============================================================
#  dev_panel_hechizos.gd  --  HERRAMIENTA, no parte del juego.
#
#  Abre el PANEL DE DEBUG de verdad (scripts/ui/debug_panel.gd) y pulsa sus casillas de HECHIZOS
#  como las pulsarias tu, para comprobar que marcar una lo concede y se lo pone.
#
#  Por que existe: marcar la casilla de un hechizo SIN APRENDER no hacia nada (equipar_hechizo corta
#  si no esta entre los disponibles), asi que solo se dejaban poner y quitar los que ya te sabias.
#  La logica arreglada vive en Game.conceder_y_equipar_hechizo y su prueba de mesa esta en
#  dev_grimorios; ESTE visor comprueba la otra mitad, que es que el panel la llame de verdad y que
#  la casilla acabe reflejando lo que ha pasado.
#
#  Va CON VENTANA: un CheckBox no se coloca ni responde sin superficie de render.
#
#    godot --path . res://tools/visores/dev_panel_hechizos.tscn
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
const Libros = preload("res://scripts/core/libros.gd")

var _fallos: int = 0
var _hechas: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1280, 720))
	print("=== PANEL DE DEBUG: casillas de hechizos ===")

	var panel: CanvasLayer = preload("res://scripts/ui/debug_panel.gd").new()
	add_child(panel)
	await get_tree().process_frame
	panel.call("_toggle") if panel.has_method("_toggle") else panel.set("_open", true)
	await get_tree().process_frame
	await get_tree().process_frame

	# El lider arranca PELADO: es el unico estado en el que el fallo se manifiesta. Con uno que ya
	# se sepa los hechizos, marcar la casilla "funcionaba" y no se veia nada raro.
	var pj: PersonajeData = Game.lider()
	pj.hechizos_aprendidos = []
	pj.equipped_spells = []
	_ok("el líder empieza sin ninguna magia", Game.hechizos_sabidos(pj).is_empty())

	# LA CASILLA DEL SHOCK TERMICO, que es el hechizo que no se podia activar.
	var ruta := "res://resources/spells/shock_termico.tres"
	_ok("el panel tiene casilla para el Shock térmico", panel.get("_spell_checks").has(ruta))
	var cb: CheckBox = panel.get("_spell_checks").get(ruta)
	if cb == null:
		printerr("  FALLA no hay casilla que pulsar")
		_fallos += 1
	else:
		# Se pulsa DE VERDAD (emitiendo la señal), no llamando a la funcion por dentro: lo que se
		# quiere comprobar es que el boton esta bien cableado.
		cb.button_pressed = true
		await get_tree().process_frame
		var s: SpellData = load(ruta)
		_ok("al marcarla, se aprende", Game.hechizos_sabidos(pj).has(s))
		_ok("y se la pone", Game.hechizos_con_huecos(pj).has(s))
		_ok("y la casilla se queda marcada", cb.button_pressed)

		cb.button_pressed = false
		await get_tree().process_frame
		_ok("al desmarcarla, se la quita", not Game.hechizos_con_huecos(pj).has(s))
		_ok("pero sigue sabiéndosela", Game.hechizos_sabidos(pj).has(s))

	# Y AHORA TODAS, para cazar el tope: con mas hechizos que huecos, las que sobren tienen que
	# quedarse DESMARCADAS solas -- una casilla marcada sobre un hechizo que no llevas miente.
	var marcadas: int = 0
	for ruta2 in Libros.HECHIZOS:
		var cb2: CheckBox = panel.get("_spell_checks").get(ruta2)
		if cb2 == null:
			continue
		cb2.button_pressed = true
		await get_tree().process_frame
		if cb2.button_pressed:
			marcadas += 1
	_ok("marcando las %d, quedan marcadas %d (el tope es %d)" % [
		Libros.HECHIZOS.size(), marcadas, Game.MAX_HECHIZOS], marcadas == Game.MAX_HECHIZOS)
	_ok("y lleva puestas justo esas", Game.hechizos_equipados(pj).size() == Game.MAX_HECHIZOS)

	# LA FOTO TIENE QUE ENSEÑAR LAS CASILLAS. El panel nace por arriba del todo y la seccion de
	# hechizos queda a varias pantallas de scroll: la primera captura salio con los atajos de dev y
	# ni una casilla a la vista, o sea inservible para juzgar justo lo que se acaba de arreglar.
	var alguna: CheckBox = panel.get("_spell_checks").get(Libros.HECHIZOS[0])
	if alguna != null:
		var n: Node = alguna
		while n != null and not (n is ScrollContainer):
			n = n.get_parent()
		if n is ScrollContainer:
			(n as ScrollContainer).ensure_control_visible(alguna)
			await get_tree().process_frame

	DirAccess.make_dir_recursive_absolute(SALIDA)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ruta_png := "%spanel_hechizos.png" % SALIDA
	get_viewport().get_texture().get_image().save_png(ruta_png)
	print("[panel] ", ProjectSettings.globalize_path(ruta_png))

	if _fallos == 0:
		print("\nOK: las %d comprobaciones pasan." % _hechas)
	else:
		printerr("\nFALLAN %d de %d comprobaciones." % [_fallos, _hechas])
	get_tree().quit(1 if _fallos > 0 else 0)


func _ok(que: String, cond: bool) -> void:
	_hechas += 1
	if cond:
		print("  ok   %s" % que)
	else:
		_fallos += 1
		printerr("  FALLA %s" % que)
