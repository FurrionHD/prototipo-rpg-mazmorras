# LA CHUPASIMAS Y SUS MUTANTES EN UNA PELEA DE VERDAD (18/11, memoria chupasimas-mutante), sin ventana:
#   1) las hojas de sus efectos estan horneadas (tools/sprites_sdf/chupasimas_efectos_horno.py)
#   2) en la pelea, las cuatro: la normal, el Coagulo, la Vidriada y la Madre
#   3) la VENTOSA: de dientes la de la normal y el Adherirse de la Madre; azul y con gotas de mana la de quien bebe
#   4) la CHUPADA: gotas de sangre, de mana o de las dos; con la Costra de sangre, ademas se le cuaja
#   5) la COSTRA SE VE: la hoja con costra espera a que se cuaje; al romperse, las postillas; con agua, chorrea
#   6) el RAYO DE MANA: un solo haz aunque pille a varios, con el grosor de la carga (que viaja en el peso del golpe)
#   CHUPASIMAS_CAPTURA=<ruta sin .png> (con ventana): la lamina de los efectos en el juego, para enseñarsela al jefe.
#   godot --headless --path . res://tools/prueba_mut_chupasimas_pelea.tscn
extends Node

const RUTA := "res://scenes/actors/enemy/chupasimas.tres"
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
	OS.set_environment("PRUEBA_SIN_MUTANTES", "1")   # la normal, normal (las otras se piden por su nombre)
	await _correr()
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _poner(tm, c: Combatant, p: Vector2) -> void:
	var cu: Node2D = tm.cuerpo_de(c)
	cu.global_position += p - tm.pies_de(c)
	tm._pos[c] = cu.global_position


# Los efectos en pixel que hay ahora en la arena con esa hoja.
func _hojas(arena: Node, hoja: String) -> int:
	return arena.find_children("*", "EfectoPixel", true, false).filter(
		func(e): return is_instance_valid(e) and not e.is_queued_for_deletion() and String(e.get_meta("hoja", "")) == hoja).size()


func _limpiar(arena: Node) -> void:
	for n in arena.find_children("*", "EfectoPixel", true, false) + arena.find_children("*", "RayoPixel", true, false):
		n.free()


func _ev(estilo: int, anim: StringName = &"", peso: float = 1.0, elem: int = 0) -> Dictionary:
	return {"estilo": estilo, "anim": anim, "peso": peso, "elem": elem, "semilla": 7, "pos_tanda": 0, "evadido": false}


func _correr() -> void:
	print("1) LAS HOJAS")
	var datos: Dictionary = (load("res://scripts/fx/efectos_pixel_datos.gd").HOJAS as Dictionary).get("chupasimas", {})
	var faltan: Array = []
	for h in ["ventosa_dientes", "ventosa_mana", "gota_sangre", "gota_mana", "gota_entra_sangre", "gota_entra_mana",
			"cuaja_coagulo", "cuaja_madre", "chorrea_coagulo", "chorrea_madre", "postillas_coagulo", "postillas_madre",
			"rayo_boca_0", "rayo_boca_1", "rayo_boca_2", "chispa_mana"]:
		if not datos.has(h):
			faltan.append(h)
	_ver(faltan.is_empty(), "las %d hojas de la chupasimas%s" % [datos.size(), "" if faltan.is_empty() else " (faltan %s)" % faltan])
	_ver(is_equal_approx(AbilityData.carga_de_peso(roundf(AbilityData.peso_rayo(3.0, 12.5) * 64.0) / 64.0), 0.24)
		or absf(AbilityData.carga_de_peso(roundf(AbilityData.peso_rayo(3.0, 12.5) * 64.0) / 64.0) - 0.24) < 1.0 / 64.0,
		"la carga del rayo viaja en el peso del golpe (3 de 12,5 -> %.3f)" % AbilityData.carga_de_peso(AbilityData.peso_rayo(3.0, 12.5)))
	_ver(is_equal_approx(AbilityData.carga_de_peso(1.0), 0.8) and is_equal_approx(AbilityData.peso_rayo(99.0, 12.5), 1.2),
		"lleno, peso 1,2; un peso de siempre (1) no pasa por rayo")

	print("2) LA PELEA")
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_mut_chupasimas_pelea", Game.PISO_ARENA):
		_ver(false, "arranca la sala")
		return
	sala.poner(RUTA, Vector2(120, -60))
	sala.poner(RUTA, Vector2(150, 0), {"mutacion": "coagulo"})
	sala.poner(RUTA, Vector2(0, 150), {"mutacion": "vidriada"})
	sala.poner(RUTA, Vector2(150, 150), {"mutacion": "madre"})
	await _esperar(20)
	if (await sala.pelear(get_tree().get_nodes_in_group("enemy"), false)) == null:
		_ver(false, "se abre la pelea")
		return
	await _esperar(5)
	var combat: Node = null
	for n in get_tree().root.get_children() + sala.capas():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	if combat == null:
		_ver(false, "encuentro la pantalla de combate")
		return
	var t = combat.turno_mapa
	var por_mut: Dictionary = {}
	for e in combat._enemies:
		por_mut[e.mutacion] = e
	_ver(por_mut.has(&"") and por_mut.has(&"coagulo") and por_mut.has(&"vidriada") and por_mut.has(&"madre"),
		"en la pelea: las cuatro (%s)" % str(por_mut.keys()))
	if not (por_mut.has(&"") and por_mut.has(&"coagulo") and por_mut.has(&"vidriada") and por_mut.has(&"madre")):
		return
	var nor: Combatant = por_mut[&""]
	var coa: Combatant = por_mut[&"coagulo"]
	var vid: Combatant = por_mut[&"vidriada"]
	var mad: Combatant = por_mut[&"madre"]
	var yo: Combatant = combat._aliados[0]
	var arena: Node = t._arena()
	for c in [nor, coa, vid, mad]:
		_ver(t._de_las_chupasimas(t.cuerpo_de(c)), "%s se reconoce como chupasimas" % c.nombre)
	_ver(not t._de_las_chupasimas(t.cuerpo_de(yo)), "y yo no")
	var p0: Vector2 = t.pies_de(yo)
	_poner(t, nor, p0 + Vector2(20, 0))
	_poner(t, vid, p0 + Vector2(-20, 0))
	_poner(t, coa, p0 + Vector2(0, 20))
	_poner(t, mad, p0 + Vector2(0, -20))
	await _esperar(5)

	print("3) LA VENTOSA")
	_limpiar(arena)
	t._chupasimas_pixel(arena, _ev(CombatFX.Estilo.SIMA_VENTOSA, &"embestida"), CombatFX.Estilo.SIMA_VENTOSA, nor, yo, 0.2, 1.0)
	_ver(_hojas(arena, "ventosa_dientes") == 1 and _hojas(arena, "gota_entra_mana") == 0, "la normal: de dientes y sin gotas")
	_limpiar(arena)
	t._chupasimas_pixel(arena, _ev(CombatFX.Estilo.SIMA_VENTOSA, &"sorbo"), CombatFX.Estilo.SIMA_VENTOSA, vid, yo, 0.2, 1.0)
	_ver(_hojas(arena, "ventosa_mana") == 1 and _hojas(arena, "gota_entra_mana") == 4,
		"la Vidriada (Sorbo): azul y cuatro gotas de mana (%d)" % _hojas(arena, "gota_entra_mana"))
	_limpiar(arena)
	t._chupasimas_pixel(arena, _ev(CombatFX.Estilo.SIMA_VENTOSA, &"adherirse"), CombatFX.Estilo.SIMA_VENTOSA, mad, yo, 0.2, 1.0)
	_ver(_hojas(arena, "ventosa_dientes") == 1 and _hojas(arena, "gota_entra_mana") == 0, "la Madre al pegarse (fisico): de dientes")
	_limpiar(arena)
	t._chupasimas_pixel(arena, _ev(CombatFX.Estilo.SIMA_VENTOSA, &"embestida"), CombatFX.Estilo.SIMA_VENTOSA, mad, yo, 0.2, 1.0)
	_ver(_hojas(arena, "ventosa_mana") == 1 and _hojas(arena, "gota_entra_mana") == 4, "la Madre, su basico magico: azul y bebe")

	print("4) LA CHUPADA")
	_limpiar(arena)
	t._chupasimas_pixel(arena, _ev(CombatFX.Estilo.SIMA_CHUPADA, &"drenaje"), CombatFX.Estilo.SIMA_CHUPADA, nor, yo, 0.2, 1.0)
	_ver(_hojas(arena, "gota_entra_sangre") == 6 and _hojas(arena, "cuaja_coagulo") == 0, "la normal: seis gotas de sangre, sin costra")
	_limpiar(arena)
	t._chupasimas_pixel(arena, _ev(CombatFX.Estilo.SIMA_CHUPADA, &"drenaje"), CombatFX.Estilo.SIMA_CHUPADA, vid, yo, 0.2, 1.0)
	_ver(_hojas(arena, "gota_entra_mana") == 6 and _hojas(arena, "gota_entra_sangre") == 0, "la Vidriada: de mana")
	_limpiar(arena)
	var cu_c: Node2D = t.cuerpo_de(coa)
	if cu_c.has_meta(&"cuaja_hasta"):
		cu_c.remove_meta(&"cuaja_hasta")
	t._chupasimas_pixel(arena, _ev(CombatFX.Estilo.SIMA_CHUPADA, &"drenaje"), CombatFX.Estilo.SIMA_CHUPADA, coa, yo, 0.2, 1.0)
	t._chupasimas_pixel(arena, _ev(CombatFX.Estilo.SIMA_CHUPADA, &"drenaje"), CombatFX.Estilo.SIMA_CHUPADA, coa, yo, 0.2, 1.0)
	_ver(_hojas(arena, "cuaja_coagulo") == 1 and int(cu_c.get_meta(&"cuaja_hasta", 0)) > Time.get_ticks_msec(),
		"el Coagulo: se le cuaja la costra (una vez aunque chupe a dos) y apunta cuando acaba")
	_limpiar(arena)
	t._chupasimas_pixel(arena, _ev(CombatFX.Estilo.SIMA_CHUPADA, &"drenaje"), CombatFX.Estilo.SIMA_CHUPADA, mad, yo, 0.2, 1.0)
	_ver(_hojas(arena, "gota_entra_sangre") == 6 and _hojas(arena, "gota_entra_mana") == 6 and _hojas(arena, "cuaja_madre") == 1,
		"la Madre: sangre y mana, y la costra se le cuaja")

	print("5) LA COSTRA SE VE")
	_limpiar(arena)
	var ed: EnemyData = load(RUTA)
	var sf_con: SpriteFrames = SpritesEnemigo.frames_variante(ed, &"coagulo", &"costra")
	var spr: AnimatedSprite2D = cu_c.get("_sprite")
	cu_c.set_meta(&"cuaja_hasta", Time.get_ticks_msec() + 700)
	coa.costra = 30.0
	coa.vis_costra = 30.0
	t._tick_costra()
	_ver(spr.sprite_frames != sf_con, "recien chupado, aun sin la hoja de la costra (espera a que se cuaje)")
	await get_tree().create_timer(0.9, true).timeout
	t._tick_costra()
	_ver(spr.sprite_frames == sf_con, "cuajada: ya con la costra puesta")
	# el agua la hace chorrear; el fuego no
	t._chupasimas_recibe(arena, _ev(0, &"", 1.0, Elementos.Elemento.FUEGO), coa, 0.1, 1.0)
	_ver(_hojas(arena, "chorrea_coagulo") == 0, "un golpe de fuego no la hace chorrear")
	t._chupasimas_recibe(arena, _ev(0, &"", 1.0, Elementos.Elemento.AGUA), coa, 0.1, 1.0)
	_ver(_hojas(arena, "chorrea_coagulo") == 1, "uno de agua, si")
	t._chupasimas_recibe(arena, _ev(0, &"", 1.0, Elementos.Elemento.AGUA), vid, 0.1, 1.0)
	_ver(_hojas(arena, "chorrea_coagulo") == 1 and _hojas(arena, "chorrea_madre") == 0, "a la Vidriada (sin costra), nada")
	coa.costra = 0.0
	coa.vis_costra = 0.0
	t._tick_costra()
	_ver(_hojas(arena, "postillas_coagulo") == 1 and spr.sprite_frames != sf_con, "rota: saltan las postillas y vuelve a la de sin costra")
	t._chupasimas_recibe(arena, _ev(0, &"", 1.0, Elementos.Elemento.AGUA), coa, 0.1, 1.0)
	_ver(_hojas(arena, "chorrea_coagulo") == 1, "sin costra, el agua ya no chorrea")

	print("6) EL RAYO DE MANA")
	_limpiar(arena)
	_poner(t, vid, p0 + Vector2(-60, 0))
	await _esperar(3)
	var rayos := func() -> Array: return arena.find_children("*", "RayoPixel", true, false)
	t._chupasimas_pixel(arena, _ev(CombatFX.Estilo.ABERRACION_RAYO, &"rayo", AbilityData.peso_rayo(1.9, 12.5)),
		CombatFX.Estilo.ABERRACION_RAYO, vid, yo, 0.3, 1.0)
	t._chupasimas_pixel(arena, _ev(CombatFX.Estilo.ABERRACION_RAYO, &"rayo", AbilityData.peso_rayo(1.9, 12.5)),
		CombatFX.Estilo.ABERRACION_RAYO, vid, combat._aliados[1] if combat._aliados.size() > 1 else yo, 0.3, 1.0)
	var r1: Array = rayos.call()
	_ver(r1.size() == 1, "un solo haz aunque pille a dos (%d)" % r1.size())
	var fino: float = float(r1[0].get("_grueso")) if r1.size() > 0 else 0.0
	_ver(_hojas(arena, "rayo_boca_0") == 1 and _hojas(arena, "chispa_mana") == 0, "con poca carga: poco mana en la boca y sin chispas")
	await _esperar(2)
	_limpiar(arena)
	t._chupasimas_pixel(arena, _ev(CombatFX.Estilo.ABERRACION_RAYO, &"rayo", AbilityData.peso_rayo(12.5, 12.5)),
		CombatFX.Estilo.ABERRACION_RAYO, vid, yo, 0.3, 1.0)
	var r2: Array = rayos.call()
	var gordo: float = float(r2[0].get("_grueso")) if r2.size() > 0 else 0.0
	_ver(gordo > fino * 2.5 and is_equal_approx(gordo, 4.8), "lleno, el haz mucho mas gordo (%.2f -> %.2f celdas)" % [fino, gordo])
	_ver(_hojas(arena, "rayo_boca_2") == 1 and _hojas(arena, "chispa_mana") >= 3, "y con chispas (%d)" % _hojas(arena, "chispa_mana"))
	var b: Vector2 = r2[0].get("_b") if r2.size() > 0 else Vector2.ZERO
	var largo: float = (b - t.pies_de(vid)).length()
	_ver(absf(largo - 110.0) < 12.0, "llega al final de su linea (%.0f de 110)" % largo)
	_limpiar(arena)

	print("7) EL SET BOCA DE LAS SIMAS EN LA PELEA")
	yo.runa_boca_vida = 0.05
	yo.runa_boca_mana = 0.15
	yo.runa_boca_tope_vida = 8.0
	yo.runa_boca_tope_mana = 3.0
	yo.boca_vida_turno = 0.0
	yo.boca_mana_turno = 0.0
	yo.current_hp = yo.max_hp * 0.5
	yo.current_mp = 0.0
	var hp0: float = yo.current_hp
	combat.boca_simas_golpe(yo, 40.0)
	_ver(is_equal_approx(yo.current_hp, hp0 + 2.0), "un golpe fisico de 40 le cura 2 (%.1f -> %.1f)" % [hp0, yo.current_hp])
	var mp0: float = yo.current_mp
	combat.magia.boca_simas_hechizo(yo, 10.0)
	_ver(is_equal_approx(yo.current_mp, mp0 + 1.5), "un hechizo de 10 le devuelve 1,5 de maná")
	var reg: String = "
".join(combat.log_entero().map(func(l): return str(l)))
	_ver(reg.contains("La Boca de las simas le devuelve") and reg.contains("de vida a") and reg.contains("de maná a"),
		"y lo dice el registro")
	combat.boca_simas_golpe(nor, 40.0)
	_ver(true, "a un enemigo no le hace nada (sin error)")
	await _foto_efectos(t, nor, coa, vid, mad, yo, combat)


# LA LAMINA DE LOS EFECTOS EN EL JUEGO (CHUPASIMAS_CAPTURA=<ruta sin .png>, con ventana): cada efecto disparado en la pelea de
# verdad, una fila por efecto y cinco momentos, sin los paneles encima. Para enseñarselos al jefe.
func _foto_efectos(t, nor: Combatant, coa: Combatant, vid: Combatant, mad: Combatant, yo: Combatant, combat: Node) -> void:
	var salida: String = OS.get_environment("CHUPASIMAS_CAPTURA")
	if salida == "" or DisplayServer.get_name() == "headless":
		return
	var arena: Node = t._arena()
	var c0: Vector2 = t.pies_de(yo)
	_poner(t, nor, c0 + Vector2(26, -4))
	_poner(t, coa, c0 + Vector2(-60, -10))
	_poner(t, vid, c0 + Vector2(-26, 4))
	_poner(t, mad, c0 + Vector2(60, -10))
	for otro in combat._aliados.slice(1):
		_poner(t, otro, c0 + Vector2(-400, 300))
	var vp: Viewport = arena.get_viewport()
	if vp is SubViewport:
		(vp as SubViewport).size = Vector2i(1280, 720)
		(vp as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := Camera2D.new()
	cam.zoom = Vector2(5.0, 5.0)
	cam.process_mode = Node.PROCESS_MODE_ALWAYS
	arena.add_child(cam)
	cam.global_position = c0 + Vector2(0, -10)
	cam.make_current()
	var capas: Array = []
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if (n as CanvasLayer).visible and not n.is_ancestor_of(arena):
			capas.append(n)
			(n as CanvasLayer).visible = false
	await _esperar(30)
	var ev := func(estilo: int, anim: StringName, peso: float = 1.0) -> Dictionary: return _ev(estilo, anim, peso)
	var V := CombatFX.Estilo.SIMA_VENTOSA
	var C := CombatFX.Estilo.SIMA_CHUPADA
	var R := CombatFX.Estilo.ABERRACION_RAYO
	var escenas: Array = [
		["normal: ventosa", func(): t._chupasimas_pixel(arena, ev.call(V, &"embestida"), V, nor, yo, 0.1, 1.0)],
		["normal: Drenaje", func(): t._chupasimas_pixel(arena, ev.call(C, &"drenaje"), C, nor, yo, 0.1, 1.0)],
		["Coagulo: Drenaje y se cuaja", func():
			_poner(t, coa, c0 + Vector2(-26, 4))
			coa.costra = 0.0
			coa.vis_costra = 0.0
			t._tick_costra()
			t._chupasimas_pixel(arena, ev.call(C, &"drenaje"), C, coa, yo, 0.1, 1.0)
			coa.costra = 30.0
			coa.vis_costra = 30.0],
		["Coagulo: le pega agua", func(): t._chupasimas_recibe(arena, _ev(0, &"", 1.0, Elementos.Elemento.AGUA), coa, 0.05, 1.0)],
		["Coagulo: le rompen la costra", func():
			coa.costra = 0.0
			coa.vis_costra = 0.0],
		["Vidriada: Sorbo", func():
			_poner(t, coa, c0 + Vector2(-60, -10))
			t._chupasimas_pixel(arena, ev.call(V, &"sorbo"), V, vid, yo, 0.1, 1.0)],
		["Vidriada: Drenaje de mana", func(): t._chupasimas_pixel(arena, ev.call(C, &"drenaje"), C, vid, yo, 0.1, 1.0)],
		["Vidriada: Rayo con poca carga", func():
			_poner(t, vid, c0 + Vector2(-50, 4))
			t._chupasimas_pixel(arena, ev.call(R, &"rayo", AbilityData.peso_rayo(2.0, 12.5)), R, vid, yo, 0.15, 1.0)],
		["Vidriada: Rayo LLENO", func(): t._chupasimas_pixel(arena, ev.call(R, &"rayo", AbilityData.peso_rayo(12.5, 12.5)), R, vid, yo, 0.15, 1.0)],
		["Madre: Drenaje (sangre y mana)", func():
			_poner(t, vid, c0 + Vector2(-26, 4))
			_poner(t, mad, c0 + Vector2(30, -6))
			t._chupasimas_pixel(arena, ev.call(C, &"drenaje"), C, mad, yo, 0.1, 1.0)
			mad.costra = 30.0
			mad.vis_costra = 30.0],
		["Madre: le rompen la costra", func():
			mad.costra = 0.0
			mad.vis_costra = 0.0],
	]
	await RenderingServer.frame_post_draw
	var tam: Vector2i = vp.get_texture().get_image().get_size()
	var rec := Rect2i(tam / 2 - Vector2i(560, 300), Vector2i(1120, 600))
	var momentos := [6, 12, 20, 30, 44]
	var hoja := Image.create(rec.size.x * momentos.size(), rec.size.y * escenas.size(), false, Image.FORMAT_RGBA8)
	for j in escenas.size():
		print("     foto: %s" % escenas[j][0])
		await _esperar(70)
		(escenas[j][1] as Callable).call()
		var hecho: int = 0
		for k in momentos.size():
			await _esperar(int(momentos[k]) - hecho)
			hecho = int(momentos[k])
			await RenderingServer.frame_post_draw
			var img: Image = vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			hoja.blit_rect(img, rec, Vector2i(k * rec.size.x, j * rec.size.y))
	for n in capas:
		(n as CanvasLayer).visible = true
	hoja.save_png(salida + ".png")
	print("     captura: %s.png" % salida)
