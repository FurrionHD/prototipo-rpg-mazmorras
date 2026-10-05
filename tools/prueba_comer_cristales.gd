# COMER CRISTALES (05/10): los enemigos se comen los cristales del suelo y mutan por acumulacion. Sin ventana:
#   godot --headless --path . res://tools/prueba_comer_cristales.tscn
# En la arena de pruebas, con el jugador fuera del grupo "aliado" para que nadie le salte encima. Acaba con
# BIEN/MAL por comprobacion.
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
		await get_tree().physics_frame
	return true


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _cristal(cat: int, cal: int) -> Cristal:
	var c := Cristal.new()
	c.categoria = cat
	c.calidad = cal
	return c


func _cristales_en_suelo() -> Array:
	var out: Array = []
	for p in get_tree().get_nodes_in_group("pickup"):
		if is_instance_valid(p) and not p.is_queued_for_deletion() and p.item is Cristal:
			out.append(p)
	return out


func _slime(jug: Node2D, desp: Vector2) -> Node2D:
	var antes: Array = get_tree().get_nodes_in_group("enemy").duplicate()
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime.tres", jug.global_position + desp, {})
	await _esperar(10)
	for e in get_tree().get_nodes_in_group("enemy"):
		if not antes.has(e):
			e.mutante = false   # que el 1% de nacer mutante no estropee la prueba
			return e
	return null


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
	if jug == null:
		print("MAL: no hay jugador")
		get_tree().quit(1)
		return
	for a in get_tree().get_nodes_in_group("aliado"):
		a.remove_from_group("aliado")   # invisibles para los enemigos

	print("1) cuentas")
	var sd: EnemyData = load("res://scenes/actors/enemy/slime.tres")
	var maxn: int = sd.categoria_maxima_natural()
	_ver(is_equal_approx(ComerCristales.peso_bocado(_cristal(maxn, Cristal.Calidad.NORMAL), sd), 1.0), "uno normal suma 1")
	_ver(is_equal_approx(ComerCristales.peso_bocado(_cristal(maxn, Cristal.Calidad.DANADO), sd), 0.5), "uno dañado suma 0,5")
	_ver(is_equal_approx(ComerCristales.peso_bocado(_cristal(maxn + 1, Cristal.Calidad.NORMAL), sd), 2.0), "uno de mas categoria suma 2")
	_ver(is_equal_approx(ComerCristales.prob_mutar(1.0), 0.10) and is_equal_approx(ComerCristales.prob_mutar(3.0), 0.45)
		and is_equal_approx(ComerCristales.prob_mutar(5.0), 1.0) and is_equal_approx(ComerCristales.prob_mutar(1.5), 0.175),
		"tabla 10/25/45/70/100 (1,5 -> 17,5%)")

	print("2) ve un cristal y se lo come")
	var e: Node2D = await _slime(jug, Vector2(0, 160))
	if e == null:
		print("MAL: no sale el slime")
		get_tree().quit(1)
		return
	e._facing = Vector2.RIGHT
	Game.soltar_en_suelo(_cristal(1, Cristal.Calidad.NORMAL), e.global_position + Vector2(40, 0))  # dentro del olfato: lo nota mire donde mire
	await _esperar(2)
	_ver(_cristales_en_suelo().size() == 1, "el cristal esta en el suelo")
	_ver(await _esperar_a(func() -> bool: return e._state == e.State.COMER, 2.0), "va a por el (estado COMER)")
	_ver(await _esperar_a(func() -> bool: return e.comer.carga > 0.0, 6.0), "se lo come (carga %.1f)" % e.comer.carga)
	_ver(_cristales_en_suelo().is_empty(), "ya no esta en el suelo")
	_ver(await _esperar_a(func() -> bool: return e._state != e.State.COMER, 3.0), "acaba y vuelve a lo suyo")

	print("3) CEBO: le distrae aunque te persiga")
	jug.global_position = e.global_position + Vector2(-150, 0)
	e._objetivo = jug
	e._state = e.State.CHASE
	e._facing = Vector2.LEFT
	await _esperar(3)
	Game.soltar_en_suelo(_cristal(1, Cristal.Calidad.NORMAL), e.global_position + Vector2(-50, 0))
	_ver(await _esperar_a(func() -> bool: return e._state == e.State.COMER, 2.0), "deja de perseguir y va al cristal")
	await _esperar_a(func() -> bool: return _cristales_en_suelo().is_empty(), 6.0)
	jug.global_position = e.global_position + Vector2(-1500, -1500)

	print("4) a la carga de 5 muta seguro, y conserva la proporcion de vida")
	# Uno nuevo: el del paso 2 puede haber sacado el 10% y haber mutado al primer bocado.
	e = await _slime(jug, Vector2(-120, 160))
	var hp_max: float = float(sd.crear_combatant(e.current_t, false, false).max_hp)
	e.hp_restante = hp_max * 0.5
	e.comer.carga = 4.9
	e._facing = Vector2.RIGHT
	# LO QUE SE VE: la escala por el alto del fotograma (con sprite de mutante propio, el que crece es el dibujo).
	var alto_visto := func() -> float:
		var tx: Texture2D = e._sprite.sprite_frames.get_frame_texture(e._sprite.animation, 0)
		return e._sprite.scale.y * (tx.get_height() if tx != null else 1.0)
	var esc0: float = alto_visto.call()
	Game.soltar_en_suelo(_cristal(1, Cristal.Calidad.NORMAL), e.global_position + Vector2(40, 0))
	_ver(await _esperar_a(func() -> bool: return e.mutante, 8.0), "muta")
	var hp_mut: float = float(sd.crear_combatant(e.current_t, true, false).max_hp)
	_ver(absf(e.hp_restante - hp_mut * 0.5) < 1.0, "vida a la mitad de la de mutante (%.1f de %.1f)" % [e.hp_restante, hp_mut])
	await _esperar_a(func() -> bool: return e._state != e.State.COMER, 4.0)
	var esc1: float = alto_visto.call()
	_ver(esc1 > esc0 * 1.1, "acaba mas grande (%.1f -> %.1f de alto)" % [esc0, esc1])
	_ver(e.radio_extra > 0.0, "colision de mutante")

	print("5) el cadaver podrido deja su cristal DAÑADO")
	var c: Node2D = await _slime(jug, Vector2(220, 160))
	c.morir()
	c.sello_pudre = Game.tiempo_mazmorra - 1.0
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	_ver(piso != null, "hay piso")
	var antes: int = _cristales_en_suelo().size()
	if piso != null:
		# Que nadie se lo coma antes de mirarlo.
		for x in get_tree().get_nodes_in_group("enemy"):
			x.set_physics_process(false)
		piso._pudrir_cadaveres()
		await _esperar(3)
		var nuevos: Array = _cristales_en_suelo()
		_ver(nuevos.size() == antes + 1, "sale un cristal")
		if nuevos.size() > 0:
			var cri: Cristal = nuevos[-1].item
			_ver(cri.calidad == Cristal.Calidad.DANADO, "dañado (categoria %d)" % cri.categoria)

		print("6) la carga va con la memoria del piso")
		# La arena no es un piso numerado y no se guarda: se le pone uno de mentira para mirar la foto.
		if piso._piso_construido <= 0:
			piso._piso_construido = 999
		piso.volcar_a_memoria()
		var mem: Dictionary = Game.memoria_pisos.get(piso._piso_construido, {})
		var hay: bool = false
		for d in (mem.get("enemigos", []) as Array):
			if bool(d.get("mut", false)) and float(d.get("carga", 0.0)) >= 5.0:
				hay = true
		_ver(hay, "el mutante se guarda con su carga")

	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
