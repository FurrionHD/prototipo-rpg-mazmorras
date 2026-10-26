# LAS BARRAS DEL OTRO GRUPO NO PISAN EL REGISTRO (B5, playtest 11/10). En una pelea tactica, se le da a la fila un
# jugador de fuera (o los de BARRAS_JUGADORES=A,B) con cuatro personajes cada uno (como si llegaran por red) y se mira que su borde derecho, en
# pantalla, quede a la izquierda de la columna del registro y los botones; al acabar la pelea vuelve a su escala.
# Con ventana y BARRAS_SALIDA=/ruta/base saca una captura.
#   godot --headless --path . res://tools/prueba_barras_registro.tscn -- nube_local
# El HUD lo pone la maquina del JUGADOR: desde la etapa 4 (26/10) la prueba es el jugador, con su sala, en espejo.
extends Node

var j = null   # el jugador con su sala: tools/prueba_con_jugador.gd

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
	# EL JUGADOR CON SU SALA (etapa 4, 26/10): esto lo hace la maquina que pinta, la del jugador (tools/prueba_con_jugador.gd).
	j = preload("res://tools/prueba_con_jugador.gd").new()
	add_child(j)
	if not await j.arrancar("prueba_barras_registro", 71):
		print("MAL: no arranca la sala o no entro")
		await j.cerrar()
		get_tree().quit(1)
		return
	var nodo: Node2D = await j.poner("res://scenes/actors/enemy/guardian_rango.tres", Vector2(-220, 70), {"modo": 1, "hp": 5.0})
	var combat: Node = await j.pelear(nodo) if nodo != null else null
	if combat == null or not combat.tactico:
		print("MAL: la pelea no se abre o no es tactica")
		await j.cerrar()
		get_tree().quit(1)
		return
	var t = combat.turno_mapa
	if not await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 20.0):
		print("MAL: no llego un turno de los tuyos")
		await j.cerrar()
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
	await j.cerrar()
	get_tree().quit(0 if _mal == 0 else 1)
