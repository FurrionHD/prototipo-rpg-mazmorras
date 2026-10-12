# LAS BARRAS DEL OTRO GRUPO NO PISAN EL REGISTRO (B5, playtest 11/10). En una pelea tactica, se le da a la fila un
# jugador de fuera (o los de BARRAS_JUGADORES=A,B) con cuatro personajes cada uno (como si llegaran por red) y se mira que su borde derecho, en
# pantalla, quede a la izquierda de la columna del registro y los botones; al acabar la pelea vuelve a su escala.
# Con ventana y BARRAS_SALIDA=/ruta/base saca una captura.
#   godot --headless --path . res://tools/prueba_barras_registro.tscn
extends Node

var _mal: int = 0


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _esperar_a(cond: Callable, tope_s: float) -> bool:
	var t0: int = Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > tope_s * 1000.0:
			return false
		await get_tree().process_frame
	return true


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(5)
	Game.entrar_arena_de_pruebas()
	await _esperar(15)
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/guardian_rango.tres", jug.global_position + Vector2(-220, 70), {})
	await _esperar(25)
	if not Game.start_combat(get_tree().get_nodes_in_group("enemy"), false):
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	var combat: Node = null
	await _esperar(5)
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	if combat == null or not combat.tactico:
		print("MAL: la pelea no es tactica")
		get_tree().quit(1)
		return
	var t = combat.turno_mapa
	if not await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 20.0):
		print("MAL: no llego un turno de los tuyos")
		get_tree().quit(1)
		return
	await _esperar(3)
	var yo: Node = get_tree().get_first_node_in_group("player")
	var otros: BarrasOtros = yo._barras_otros
	var escala_sola: float = yo.escala_fila()
	var grupos: Array = []
	var jugadores: Array = OS.get_environment("BARRAS_JUGADORES").split(",", false)
	if jugadores.is_empty():
		jugadores = ["Arian"]
	for j in jugadores:
		var filas: Array = []
		for k in 4:
			filas.append(["%s_%d" % [j, k], "Personaje %d" % k, Color(0.4, 0.7, 1.0), 150.0, 200.0, 150.0, 181.0, 20.0, 20.0, k == 0])
		grupos.append([j, filas])
	otros._rehacer(grupos)
	for g in grupos:
		for fi in g[1]:
			var col: Dictionary = otros._cols[String(fi[0])]
			(col["nombre"] as Label).text = String(fi[1])
			otros._poner(col["hp"], col["hp_lbl"], fi[3], fi[4], "%.0f/%.0f")
			otros._poner(col["en"], col["en_lbl"], fi[5], fi[6], "%.0f/%.0f")
			otros._poner(col["mp"], col["mp_lbl"], fi[7], fi[8], "%.1f/%.1f")
	await _esperar(3)
	var vp_w: float = get_viewport().get_visible_rect().size.x
	var col_izq: float = vp_w - (Game._combat_montaje_script.ANCHO_COL_DER + Game._combat_script.MARGEN_UI + Tactil.borde.x)
	var f: float = yo.escala_fila()
	var borde: float = (otros.position.x + otros.ancho()) * f
	_ver(is_equal_approx(otros.position.x, yo.x_otros()), "las del otro grupo, pegadas a las tuyas")
	print("     escala %.2f (sin los otros %.2f); las barras acaban en %.0f, el registro empieza en %.0f" % [f, escala_sola, borde, col_izq])
	_ver(borde <= col_izq, "las barras del otro grupo no se meten debajo del registro")
	var borde_solo: float = (yo.x_columna(Game.party.size()) + 8.0) * escala_sola
	_ver(borde_solo <= col_izq + 0.5 and escala_sola > f, "sin los otros, tu fila cabe (acaba en %.0f) y se encoge menos" % borde_solo)
	_ver(is_equal_approx(yo._barras_layer.scale.x, f), "la capa de barras lleva esa escala")
	var salida: String = OS.get_environment("BARRAS_SALIDA")
	if salida != "" and DisplayServer.get_name() != "headless":
		await _esperar(20)
		var img: Image = get_tree().root.get_viewport().get_texture().get_image()
		img.save_png(salida + ".png")
		print("     captura: %s.png" % salida)
	Game.call("_desmontar_arena_tactica")
	await _esperar(3)
	var f_fuera: float = yo.escala_fila()
	print("     fuera de la pelea: escala %.2f" % f_fuera)
	_ver(f_fuera >= f, "fuera de la pelea no se encoge mas que dentro")
	print("FIN: TODO BIEN" if _mal == 0 else "FIN: %d MAL" % _mal)
	get_tree().quit(0 if _mal == 0 else 1)
