# PRUEBA: EL COMBATE TACTICO EN LA MAZMORRA (03/10/2026). Piso 1 de verdad, sin ventana: se lleva al
# jugador a un PASILLO, se le pone un enemigo al lado y se abre la pelea. Tiene que salir tactica, con la
# arena RELLENA (la forma del sitio, la misma superficie que en la arena de pruebas) y con todos dentro.
# Luego lo mismo en medio de una SALA.
#   godot --headless --path . res://tools/prueba_tactico_mazmorra.tscn
extends Node

var _fallos: int = 0


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _afirmar(ok: bool, que: String) -> void:
	_fallos += 0 if ok else 1
	print("[PASA] " if ok else "[FALLA] ", que)


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	Game.current_floor = 1
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")
	await _esperar(30)
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	if piso == null or piso.get("gen") == null:
		print("MAL: no hay piso")
		get_tree().quit(1)
		return
	var gen: DungeonGenerator = piso.gen
	# UN PASILLO: la celda de pasillo con mas pasillo alrededor (lejos de las bocas de las salas).
	var mejor := Vector2i(-1, -1)
	var mejor_n: int = -1
	for y in gen.alto:
		for x in gen.ancho:
			var c := Vector2i(x, y)
			var z: int = gen.zona_en(c)
			if not gen.es_suelo(c) or z < 0 or String(gen.zonas[z]["tipo"]) == "sala":
				continue
			var n: int = 0
			for dy in range(-6, 7):
				for dx in range(-6, 7):
					var v := c + Vector2i(dx, dy)
					var zv: int = gen.zona_en(v)
					if gen.es_suelo(v) and zv >= 0 and String(gen.zonas[zv]["tipo"]) != "sala":
						n += 1
			if n > mejor_n:
				mejor_n = n
				mejor = c
	_afirmar(mejor.x >= 0, "hay un pasillo en el piso (%s)" % str(mejor))
	await _pelea_en(gen, gen.centro_px(mejor), true, "PASILLO")
	# Y UNA SALA: la mas grande, en su centro.
	var sala := Rect2i()
	for z in gen.zonas:
		if String(z["tipo"]) == "sala" and (z["rect"] as Rect2i).get_area() > sala.get_area():
			sala = z["rect"]
	await _pelea_en(gen, gen.centro_px(sala.position + sala.size / 2), false, "SALA %s" % str(sala.size))
	# Y UNA PELEA JUGADA ENTERA en el pasillo: lo que se gana (Fuerza pegando, Resistencia encajando) y el
	# desgaste del arma se QUEDAN al salir (en la arena de pruebas no se podia ver: alli todo se deshace).
	await _pelea_jugada(gen, gen.centro_px(mejor))
	print("[tactico-mazmorra] RESULTADO: %s (%d fallos)" % ["TODO BIEN" if _fallos == 0 else "HAY FALLOS", _fallos])
	get_tree().quit(1 if _fallos > 0 else 0)


func _pelea_en(gen: DungeonGenerator, px: Vector2, pasillo: bool, que: String) -> void:
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var enemigos: Array = get_tree().get_nodes_in_group("enemy")
	if jug == null or enemigos.is_empty():
		_afirmar(false, "%s: hay jugador y enemigos" % que)
		return
	# Que no se cuele nadie mas: los demas, lejos.
	var e: Node2D = enemigos[0]
	for otro in enemigos:
		if otro != e and is_instance_valid(otro):
			(otro as Node2D).global_position = Vector2(-99999, -99999)
	jug.global_position = px
	# El enemigo al lado, por donde haya suelo.
	var sitio: Vector2 = px
	for d in [Vector2(40, 0), Vector2(-40, 0), Vector2(0, 40), Vector2(0, -40)]:
		if gen.es_suelo(ArenaCalculo.celda_de_px(px + d)):
			sitio = px + d
			break
	e.global_position = sitio
	await _esperar(3)
	e._start_combat(true)
	await _esperar(10)
	var combat: Node = null
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	_afirmar(combat != null and combat.tactico, "%s: la pelea se abre en TACTICO" % que)
	if combat == null or not combat.tactico:
		return
	var arena: ArenaCombate = combat.turno_mapa._arena()
	_afirmar(arena != null, "%s: hay arena montada" % que)
	if arena == null:
		return
	var n_celdas: int = 0
	for y in range(arena.rect_celdas.position.y, arena.rect_celdas.end.y):
		for x in range(arena.rect_celdas.position.x, arena.rect_celdas.end.x):
			if ArenaCalculo.en_forma(arena.rect_celdas, arena.mascara, Vector2i(x, y)):
				n_celdas += 1
	print("%s: arena %s, %d celdas, mascara %s, %d tramos de borde" % [que, str(arena.rect_celdas), n_celdas,
		"SI" if not arena.mascara.is_empty() else "no (rectangulo)", arena.tramos.size()])
	if pasillo:
		_afirmar(not arena.mascara.is_empty(), "%s: la arena coge la forma del pasillo (relleno)" % que)
	_afirmar(arena.contiene(jug.global_position), "%s: el jugador esta dentro" % que)
	_afirmar(arena.contiene(e.global_position), "%s: el enemigo esta dentro" % que)
	_afirmar(combat.arena_mascara == arena.mascara, "%s: la forma que viaja al espejo es la montada" % que)
	var roster: Dictionary = combat.roster_para_espejo()
	_afirmar(roster.has("arena") and (arena.mascara.is_empty() or roster.has("arena_m")),
		"%s: el roster lleva la arena%s" % [que, " y su forma" if not arena.mascara.is_empty() else ""])
	# Cerrar la pelea a la fuerza: ganada, y Continuar.
	for c in combat._enemies:
		c.current_hp = 0.0
	combat._player_won = true
	combat._state = combat.State.FINISHED
	combat._on_continue_pressed()
	await _esperar(20)
	_afirmar(not is_instance_valid(Game.get("_arena_nodo")), "%s: al acabar la arena se quita" % que)


func _pelea_jugada(gen: DungeonGenerator, px: Vector2) -> void:
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var e: Node2D = null
	for n in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(n) and not n.esta_muerto():
			if e == null:
				e = n
			else:
				(n as Node2D).global_position = Vector2(-99999, -99999)
	if e == null:
		_afirmar(false, "JUGADA: queda un enemigo vivo")
		return
	jug.global_position = px
	for d in [Vector2(28, 0), Vector2(-28, 0), Vector2(0, 28), Vector2(0, -28)]:
		if gen.es_suelo(ArenaCalculo.celda_de_px(px + d)):
			e.global_position = px + d
			break
	await _esperar(3)
	var lider: PersonajeData = Game.lider()
	var antes: Dictionary = (lider.ability_internal as Dictionary).duplicate()
	var dur_antes: float = Game.durabilidad_slot("main", lider)
	var grupo_antes: Dictionary = {}
	for pj in Game.companeros():
		grupo_antes[pj] = (pj.ability_internal as Dictionary).duplicate()
	e._start_combat(true)
	await _esperar(10)
	var combat: Node = null
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	_afirmar(combat != null and combat.tactico, "JUGADA: la pelea es tactica")
	if combat == null:
		return
	var tm = combat.turno_mapa
	# LAS LINEAS entre enemigos no salen con el tactico.
	var capa_v: Node = get_tree().root.find_child("Vinculos", true, false)
	_afirmar(capa_v != null and not (capa_v as CanvasItem).visible, "JUGADA: la capa de lineas entre enemigos esta apagada")
	var links_vistos: int = 0
	for n in get_tree().root.find_children("*", "Line2D", true, false):
		if (n as CanvasItem).is_visible_in_tree() and String(n.get_parent().get_script().resource_path if n.get_parent().get_script() else "").ends_with("enemy_links.gd"):
			links_vistos += 1
	_afirmar(links_vistos == 0, "JUGADA: ninguna linea de vinculo pintada (%d)" % links_vistos)
	# UN COMPAÑERO CAE: su cuerpo se tumba en el mapa (no se queda de pie).
	var caido: Combatant = null
	for al in combat._aliados:
		if al != combat._aliados[0]:
			caido = al
			break
	var cuerpo_caido: Node2D = tm.cuerpo_de(caido) if caido != null else null
	if caido != null and cuerpo_caido != null:
		caido.current_hp = 0.0
		combat.altas._caer_aliado(caido)
		await _esperar(40)
		var m = cuerpo_caido.get("_muneco")
		var anim: String = (m as MunecoJugador).anim_actual() if m is MunecoJugador else "?"
		_afirmar(cuerpo_caido.has_meta(tm.MARCA_CAIDO) and anim.begins_with("muerte"),
			"JUGADA: el compañero que cae se tumba en el mapa (anim %s)" % anim)
	var t0: int = Time.get_ticks_msec()
	var turnos: int = 0
	var visto_desvanecido: bool = false
	while is_instance_valid(combat) and not combat.acabada() and Time.get_ticks_msec() - t0 < 180000:
		await _esperar(2)
		if is_instance_valid(e) and e.has_meta("muerto_en_pelea"):
			visto_desvanecido = true
		if int(combat._state) != 1 or tm._fase != tm.Fase.MOVIENDO or not is_instance_valid(tm._cuerpo):
			continue
		var atacar: BaseButton = combat._action_buttons.get(combat.Action.ATTACK)
		if atacar != null and not atacar.disabled:
			atacar.pressed.emit()
			turnos += 1
			continue
		var obj = combat._objetivo()
		var co: Node2D = tm.cuerpo_de(obj) if obj != null else null
		var desde: Vector2 = tm._cuerpo.global_position
		if co != null:
			var dd: Vector2 = co.global_position - desde
			var teclas: Array = []
			if absf(dd.x) > 6.0:
				teclas.append("move_right" if dd.x > 0.0 else "move_left")
			if absf(dd.y) > 6.0:
				teclas.append("move_down" if dd.y > 0.0 else "move_up")
			for k in teclas:
				Input.action_press(k)
			await _esperar(15)
			for k in teclas:
				Input.action_release(k)
		if tm._fase == tm.Fase.MOVIENDO and is_instance_valid(tm._cuerpo) 				and tm._cuerpo.global_position.distance_to(desde) < 2.0 				and (atacar == null or atacar.disabled):
			var def: BaseButton = combat._action_buttons.get(combat.Action.DEFEND)
			var pasar: BaseButton = combat._action_buttons.get(combat.Action.FLEE)
			if def != null and not def.disabled:
				def.pressed.emit()
				turnos += 1
			elif pasar != null and not pasar.disabled and pasar.text == "Pasar":
				pasar.pressed.emit()
				turnos += 1
	_afirmar(is_instance_valid(combat) and combat.acabada(), "JUGADA: la pelea acaba (%d turnos mios, %.0f s)"
		% [turnos, float(Time.get_ticks_msec() - t0) / 1000.0])
	# El ultimo golpe acaba la pelea a la vez: se le da un momento a su muerte en el mapa antes de mirar.
	var t_m: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_m < 4000 and is_instance_valid(e) and not e.has_meta("muerto_en_pelea"):
		await _esperar(1)
	print("JUGADA: la muerte del ultimo sale a los %d ms de acabar" % (Time.get_ticks_msec() - t_m))
	if is_instance_valid(e) and e.has_meta("muerto_en_pelea"):
		visto_desvanecido = true
	if is_instance_valid(combat):
		_afirmar(bool(combat._player_won), "JUGADA: la ganamos")
		combat._on_continue_pressed()
	await _esperar(30)
	_afirmar(not is_instance_valid(Game.get("_arena_nodo")), "JUGADA: se cierra y vuelvo al mapa")
	# EL CADAVER: durante la pelea se desvanece y al acabar vuelve a verse para recogerlo.
	_afirmar(visto_desvanecido, "JUGADA: el enemigo muerto se marca para desvanecerse durante la pelea")
	_afirmar(is_instance_valid(e) and e.esta_muerto() and e.modulate.a > 0.99 and not e.has_meta("muerto_en_pelea"),
		"JUGADA: al acabar vuelve como cadaver, visible (alfa %.2f)" % (e.modulate.a if is_instance_valid(e) else -1.0))
	if cuerpo_caido != null:
		_afirmar(not cuerpo_caido.has_meta(tm.MARCA_CAIDO), "JUGADA: el compañero caido se levanta al acabar")
	var despues: Dictionary = Game.lider().ability_internal
	var linea: Array = []
	for k in despues:
		linea.append("%s %.3f->%.3f" % [k, float(antes.get(k, 0.0)), float(despues[k])])
	print("JUGADA: stats del lider: ", ", ".join(linea))
	_afirmar(float(despues.get("fuerza", 0.0)) > float(antes.get("fuerza", 0.0))
		or float(despues.get("destreza", 0.0)) > float(antes.get("destreza", 0.0)),
		"JUGADA: el lider gana Fuerza/Destreza pegando, y se le queda")
	var dur: float = Game.durabilidad_slot("main", Game.lider())
	_afirmar(Game.lider().equipped_main == null or dur < dur_antes, "JUGADA: el arma se gasta (%.4f -> %.4f)" % [dur_antes, dur])
	# Los compañeros entrenan LO SUYO.
	for pj in Game.companeros():
		var a0: Dictionary = grupo_antes.get(pj, {})
		var cambios: Array = []
		for k in pj.ability_internal:
			var d: float = float(pj.ability_internal[k]) - float(a0.get(k, 0.0))
			if absf(d) > 0.0001:
				cambios.append("%s +%.3f" % [k, d])
		print("JUGADA: %s gana: %s" % [pj.nombre, ", ".join(cambios) if not cambios.is_empty() else "nada"])
