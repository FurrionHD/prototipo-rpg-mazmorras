# EL REGISTRO DE LA PELEA AGRUPADO (06/11, combat_registro.gd), en la arena y sin ventana:
#   - UNA FILA POR ACCION: lo que pasa dentro de una accion (extras, segundas frases) va en su fila con "+N".
#   - Los ESTADOS del tick y los AVISOS van aparte; el aviso de ahora se va en cuanto llega otra cosa.
#   - El TEXTO PLANO no cambia (_log_lines): una frase por linea, como siempre (lo leen las huellas).
#   - FILTROS: Todo / Lo mio / Me hacen / Estados.
#   - CODIFICAR y REHACER (lo que viaja al espejo y a la pelea guardada) devuelve los mismos grupos.
#   - La FICHA del desglose: la principal arriba y el resto debajo.
#   godot --headless --path . res://tools/prueba_registro_pelea.tscn
extends Node

var sala = null
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


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _filas(combat: Node) -> PackedStringArray:
	combat.registro.repintar()   # el panel se rehace al final del fotograma: aqui, ya
	var t: String = combat._log.get_parsed_text()
	var out := PackedStringArray()
	for l in t.split("\n"):
		if l.strip_edges() != "":
			out.append(l)
	return out


func _correr() -> void:
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_registro_pelea", Game.PISO_ARENA):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	sala.poner("res://scenes/actors/enemy/slime.tres", Vector2(160, 0))
	await _esperar(20)
	if (await sala.pelear(get_tree().get_nodes_in_group("enemy"), false)) == null:
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	await _esperar(5)
	var combat: Node = null
	for n in get_tree().root.get_children() + sala.capas():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	if combat == null:
		print("MAL: no hay pantalla de pelea")
		get_tree().quit(1)
		return
	var reg = combat.registro
	var yo: Combatant = combat._aliados[0]
	var bicho: Combatant = combat._enemies[0]
	# Desde limpio, para contar filas sin lo que haya escrito el arranque.
	reg.rehacer([])
	reg._elegir_filtro(reg.Filtro.TODO)

	print("1) UNA FILA POR ACCION")
	combat._set_log("¡Turno de Yo! Elige una acción.", "a")
	_ver(_filas(combat).size() == 1, "el aviso de ahora se ve")
	reg.abrir(yo)
	combat._set_log("Yo golpea al bicho por 5.")
	_ver(_filas(combat).size() == 1 and not _filas(combat)[0].contains("Turno"), "el aviso se va al llegar la accion")
	combat._log_extra("El corte de aire le alcanza: 2.")
	combat._log_extra("Le abre un Sangrado.")
	var f: PackedStringArray = _filas(combat)
	_ver(f.size() == 1, "los extras NO hacen filas nuevas (hay %d)" % f.size())
	_ver(f[0].contains("Yo golpea al bicho por 5.") and f[0].contains("+2"), "la fila es la principal con +2: '%s'" % f[0])
	_ver(combat._log_lines.size() == 4, "pero el texto plano sigue teniendo una frase por linea (aviso + 3)")

	print("2) ESTADOS Y LA ACCION DEL ENEMIGO")
	combat._set_log("Bicho sufre Sangrado (1.00).", "s")
	reg.abrir(bicho)
	combat._set_log("Bicho te muerde por 3.")
	f = _filas(combat)
	_ver(f.size() == 3, "accion, estado y accion del enemigo: tres filas (hay %d)" % f.size())

	print("3) FILTROS")
	reg._elegir_filtro(reg.Filtro.MIO)
	f = _filas(combat)
	_ver(f.size() == 1 and f[0].contains("Yo golpea"), "Lo mio: solo mi accion")
	reg._elegir_filtro(reg.Filtro.ME_HACEN)
	f = _filas(combat)
	_ver(f.size() == 1 and f[0].contains("muerde"), "Me hacen: solo la del enemigo")
	reg._elegir_filtro(reg.Filtro.ESTADOS)
	f = _filas(combat)
	_ver(f.size() == 1 and f[0].contains("Sangrado"), "Estados: solo el tick")
	reg._elegir_filtro(reg.Filtro.TODO)
	_ver(_filas(combat).size() == 3, "Todo: las tres")

	print("4) CODIFICAR Y REHACER (espejo y pelea guardada)")
	var cod: Array = combat.log_entero()
	_ver(cod.size() == combat._log_lines.size() and String(cod[1]).contains("Yo golpea"), "codificado: mismas frases y el texto dentro")
	reg.rehacer(cod)
	f = _filas(combat)
	_ver(f.size() == 3 and f[0].contains("+2"), "rehecho: las mismas filas y grupos")
	_ver(combat._log_lines[1] == "Yo golpea al bicho por 5.", "y el texto plano vuelve limpio")
	reg.rehacer(["Una frase de una pelea guardada vieja"])
	_ver(_filas(combat).size() == 1, "una frase sin grupo sale como fila suelta")
	reg.rehacer(cod)

	print("4b) CORCHETES Y UN REGISTRO LARGO")
	reg.abrir(yo)
	combat._set_log("Yo lanza [Fuego] al bicho.")
	f = _filas(combat)
	_ver(f[f.size() - 1].contains("[Fuego]"), "los corchetes del texto salen tal cual: '%s'" % f[f.size() - 1])
	for k in 600:
		if k % 3 == 0:
			reg.abrir(yo if k % 2 else bicho)
		combat._set_log("Linea %d de una pelea muy larga." % k, "" if k % 3 == 0 else "x")
	var t0: int = Time.get_ticks_usec()
	reg.repintar()
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	print("  rehacer el panel con %d frases: %.1f ms" % [combat._log_lines.size(), ms])
	_ver(ms < 40.0, "rehacerlo con 600 frases cuesta poco (%.1f ms)" % ms)
	reg.rehacer(cod)

	print("5) LA FICHA")
	var g: String = String(reg.meta[1][0])
	reg._mostrar_ficha(g)
	await _esperar(2)
	var labels: Array = reg._ficha_vb.get_children()
	_ver(reg._ficha.visible and labels.size() == 3, "la ficha sale con las tres frases (hay %d)" % labels.size())
	_ver(labels.size() > 0 and (labels[0] as Label).text.contains("Yo golpea"), "la principal arriba")
	reg._mostrar_ficha(String(reg.meta[5][0]))
	_ver(not reg._ficha.visible, "una accion de una sola frase no tiene ficha")

	# CON VENTANA y "-- captura <ruta>": deja la foto del registro con la ficha abierta (para enseñarla).
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "captura":
		# En la sala la pelea se pinta en un SubViewport apagado y con su capa escondida: se saca a la ventana.
		var capa: Node = combat.get_parent()
		capa.reparent(get_tree().root)
		capa.visible = true
		for k in 3:
			reg.abrir(bicho if k % 2 else yo)
			combat._set_log("%s ataca por %d." % [bicho.nombre if k % 2 else yo.nombre, 4 + k])
			if k != 1:
				combat._log_extra("Un extra de la accion %d." % k)
		combat._set_log("%s sufre Veneno (0.80)." % bicho.nombre, "s")
		await _esperar(10)
		reg._mostrar_ficha(g)
		await _esperar(10)
		await RenderingServer.frame_post_draw
		get_tree().root.get_viewport().get_texture().get_image().save_png(args[1])
		print("captura en ", args[1])

	print("\nRESULTADO: %s (%d mal)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(0 if _mal == 0 else 1)
