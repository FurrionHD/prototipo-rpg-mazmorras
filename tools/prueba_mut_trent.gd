# LOS MUTANTES DEL TRENT (02/11): Trent -> TOCON AMBARINO -> ESPANTAJO, unidos por la savia. El arbol, sus stats (las
# seis, suma 135, el trent estrena Voluntad), sus ataques (la Resina en vez de la Savia corrosiva; el Espantajo, la Savia
# negra y el Geiser) y sus sprites (cada uno con su cuerpo; la variante del Tocon sin costra; el trent normal ya come).
# Y EN LA PELEA (su sala, 02/11 pasos 3-4): la COSTRA DE AMBAR del Tocon (se come los golpes antes que la vida, no la
# toca el veneno, suelta un bicho al romperse sin pasar de dos, vuelve entera a los tres turnos suyos, se ve sin ambar
# mientras esta rota y viaja al espejo).
# Sin ventana:
#   godot --headless --path . res://tools/prueba_mut_trent.tscn
extends Node

var sala = null   # su sala: tools/prueba_sala_propia.gd
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


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _nombres(c: Combatant) -> Array:
	return c.habilidades.map(func(a): return a.nombre)


func _tiene(ab: AbilityData, estado: int, prob: float, stacks: int = 1) -> bool:
	for a in ab.efectos:
		if a.estado == estado and is_equal_approx(a.prob, prob) and a.stacks == stacks:
			return true
	return false


func _correr() -> void:
	var ed: EnemyData = load("res://scenes/actors/enemy/trent.tres")

	print("1) EL ARBOL")
	var c1: Combatant = ed.crear_combatant(0.5, true, false, &"ambarino")
	var c2: Combatant = ed.crear_combatant(0.5, true, false, &"espantajo")
	_ver(c1.nombre == "Tocón ambarino" and c2.nombre == "Espantajo", "nombres (%s / %s)" % [c1.nombre, c2.nombre])
	_ver(ed.siguiente_mutacion(false, &"")["id"] == &"ambarino", "del trent sale el Tocon ambarino")
	_ver(ed.siguiente_mutacion(true, &"ambarino")["id"] == &"espantajo", "y de el, el Espantajo")

	print("2) LAS STATS (las seis, suma 135)")
	_ver(ed.voluntad == 12 and ed.fuerza + ed.resistencia + ed.destreza + ed.agilidad + ed.magia + ed.voluntad == 135,
		"el trent: 32/50/14/10/17/12 (estrena Voluntad)")
	for id in [&"ambarino", &"espantajo"]:
		var p: Dictionary = ed.mutacion_de(id).pesos
		var suma: int = 0
		for k in p:
			suma += int(p[k])
		_ver(suma == 135 and p.size() == 6, "%s: reparto de las seis, suma %d" % [id, suma])
	_ver(c1.hab("resistencia") > c2.hab("resistencia") and c2.hab("fuerza") > c1.hab("fuerza"),
		"el Tocon aguanta mas; el Espantajo pega mas")

	print("3) LOS ATAQUES")
	print("    ambarino  %s" % [_nombres(c1)])
	print("    espantajo %s" % [_nombres(c2)])
	_ver(_nombres(c1) == ["Resina", "Ramazo", "Raíces atenazantes"], "el Tocon: la Resina en vez de la Savia corrosiva")
	_ver(_nombres(c2) == ["Savia negra", "Ramazo", "Raíces atenazantes", "Géiser"], "el Espantajo: Savia negra y Geiser")
	var res: AbilityData = c1.habilidades[0]
	_ver(is_equal_approx(res.dano_mult, 0.9) and _tiene(res, StatusEffects.Id.RESINADO, 0.7)
		and _tiene(res, StatusEffects.Id.LENTO, 0.7) and int(res.charco_turnos) == 0,
		"Resina: x0,9, Resinado y Lento al 70 %, sin charco")
	var sav: AbilityData = c2.habilidades[0]
	_ver(_tiene(sav, StatusEffects.Id.VENENO, 0.6) and _tiene(sav, StatusEffects.Id.SAVIA_NEGRA, 1.0),
		"Savia negra: Veneno 60 % y una carga de Savia negra")
	var gei: AbilityData = c2.habilidades[3]
	_ver(gei.carga and gei.carga_turnos == 1 and gei.es_magico and is_equal_approx(gei.dano_mult, 1.87) and is_equal_approx(gei.forma_radio, 45.0)
		and _tiene(gei, StatusEffects.Id.SAVIA_NEGRA, 1.0, 2) and gei.cooldown == 4,
		"Geiser: un turno cargando, circulo r45, magico x1,87, 2 cargas de Savia negra, recarga 4")

	print("4) LOS ESTADOS")
	var sn: Dictionary = StatusEffects.def(StatusEffects.Id.SAVIA_NEGRA)
	_ver(int(sn["max_stacks"]) == 5 and is_equal_approx(float(sn["def_mult"]), 0.92), "Savia negra: -8 % de Defensa por carga, hasta 5")
	_ver(bool(StatusEffects.def(StatusEffects.Id.RESINADO).get("enraiza", false)), "Resinado: no te mueves (como el Enraizado)")

	print("5) LOS SPRITES")
	var sf0: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, false, &"")
	_ver(sf0 != null and sf0.has_animation(&"comer_0"), "el trent normal ya come")
	for id in [&"ambarino", &"espantajo"]:
		var sf: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, id)
		_ver(sf != null and SpritesEnemigo.mutante_propio(ed, id) and sf.has_animation(&"evolucion_1")
			and sf.has_animation(&"escupir_2") and sf.has_animation(&"comer_3"), "%s: su hoja propia (evolucion, escupir, comer)" % id)
		_ver(sf == SpritesEnemigo.frames_de(ed, 0.9, true, id), "%s: sin tinte de piso" % id)
	var sfe: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, &"espantajo")
	_ver(sfe.has_animation(&"geiser_carga_0") and sfe.has_animation(&"geiser_5"), "el Espantajo: su Geiser (cargando y soltando)")
	_ver(sfe.get_frame_count(&"evolucion_0") == 24, "su evolucion, de 24 (se pudre poco a poco)")
	var sv: SpriteFrames = SpritesEnemigo.frames_variante(ed, &"ambarino", &"sin_costra")
	_ver(sv != null and sv.has_animation(&"idle_0") and sv.has_animation(&"raices_4")
		and sv != SpritesEnemigo.frames_de(ed, 0.5, true, &"ambarino"), "el Tocon sin costra: su variante")

	# (04/11) LA MADERA NO SE VUELVE ROSA: el tinte del normal solo cambia lo claro que es, nunca el tono. Con el color del mas
	# fuerte (99aa8e) el azul se multiplicaba x2,2 y la corteza (132, 73, 58) salia (227, 97, 128).
	var base: Color = Trent3DSprites.BASE
	var fuerte: Color = Trent3DSprites.tinte_madera(Color("99aa8e"))
	var k: Vector3 = Vector3(fuerte.r / base.r, fuerte.g / base.g, fuerte.b / base.b)
	_ver(k.x > 1.0 and is_equal_approx(k.x, k.y) and is_equal_approx(k.y, k.z), "el fuerte: mas claro y el mismo tono (x%.2f en los tres canales)" % k.x)
	var corteza := Color8(132, 73, 58)
	var teñida := Color(corteza.r * k.x, corteza.g * k.y, corteza.b * k.z)
	_ver(teñida.r > teñida.g and teñida.g > teñida.b, "la corteza sigue siendo marron (r > g > b)")
	_ver(Trent3DSprites.tinte_madera(base).is_equal_approx(base), "el color base no cambia")

	await _pelea()
	print("FIN: %s" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)


func _pelea() -> void:
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_mut_trent", Game.PISO_ARENA):
		_ver(false, "arranca la sala")
		return
	sala.poner("res://scenes/actors/enemy/trent.tres", Vector2(90, 0), {})
	await _esperar(25)
	var nodos: Array = get_tree().get_nodes_in_group("enemy")
	nodos[0].aplicar_mutacion(&"ambarino", 0.0)
	await _esperar(5)
	if await sala.pelear(nodos, false) == null:
		_ver(false, "arranca la pelea")
		return
	await _esperar(8)
	var combat: Node = null
	for n in get_tree().root.get_children() + sala.capas():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	combat.set_process(false)
	var tm = combat.turno_mapa
	var en = combat.enemigos
	var toc: Combatant = null
	for e in combat._enemies:
		if e.mutacion == &"ambarino":
			toc = e
	_ver(toc != null, "en la pelea, un Tocon ambarino")
	if toc == null:
		return

	print("6) LA COSTRA DE AMBAR")
	_ver(toc.costra_max > 0.0 and is_equal_approx(toc.costra_max, toc.max_hp * 0.2) and is_equal_approx(toc.costra, toc.costra_max),
		"empieza entera: el 20 %% de su vida (%.1f de %.1f)" % [toc.costra, toc.max_hp])
	toc.invulnerable = false
	var hp0: float = toc.current_hp
	toc.take_damage(toc.costra_max * 0.5)
	_ver(is_equal_approx(toc.current_hp, hp0) and is_equal_approx(toc.costra, toc.costra_max * 0.5),
		"un golpe se lo come la costra, no la vida")
	toc.take_damage(5.0, true)
	_ver(is_equal_approx(toc.costra, toc.costra_max * 0.5) and toc.current_hp < hp0, "el veneno no la toca: va a la vida")
	var hp1: float = toc.current_hp
	toc.take_damage(toc.costra_max)
	_ver(toc.costra <= 0.0 and toc.costra_rota and is_equal_approx(toc.current_hp, hp1 - toc.costra_max * 0.5),
		"se rompe y lo que sobra va a la vida")
	var antes: int = combat._enemies.size()
	en.costra_rota(toc)
	var bichos: Array = combat._enemies.filter(func(c): return c.sprite_res.contains("enemigos_invocados/bicho_"))
	_ver(not toc.costra_rota and combat._enemies.size() == antes + 1 and bichos.size() == 1,
		"al romperse suelta un bicho del ambar (%s)" % [bichos.map(func(c): return c.nombre)])
	await _esperar(30)
	tm._tick_costra()   # (la pelea va con el _process apagado: el tick, a mano)
	var cu: Node2D = tm.cuerpo_de(toc)
	_ver(bool(tm._costra_var.get(cu, false)), "rota, se le ve sin ambar")
	_ver(bichos.size() == 1 and tm.cuerpo_de(bichos[0]) != null, "y el bicho tiene cuerpo en el mapa")
	# Tope de dos vivos: dos roturas mas, uno mas y ya no.
	toc.costra = 1.0
	toc.take_damage(2.0)
	en.costra_rota(toc)
	toc.costra = 1.0
	toc.take_damage(2.0)
	en.costra_rota(toc)
	bichos = combat._enemies.filter(func(c): return c.sprite_res.contains("enemigos_invocados/bicho_"))
	_ver(bichos.size() == 2, "sin pasar de dos bichos vivos (%d)" % bichos.size())
	# Vuelve ENTERA a los tres turnos suyos.
	en.costra_vuelve(toc)
	en.costra_vuelve(toc)
	_ver(toc.costra <= 0.0, "a los dos turnos aun no")
	en.costra_vuelve(toc)
	_ver(is_equal_approx(toc.costra, toc.costra_max), "al tercero vuelve entera")
	tm._tick_costra()
	_ver(not bool(tm._costra_var.get(cu, true)), "y se le vuelve a ver con su ambar")
	# EL ESPEJO: viaja en la instantanea (campo 12).
	toc.costra = toc.costra_max * 0.25
	var v: Array = combat.espejo._valores([toc])[0]
	_ver(v.size() > 12 and is_equal_approx(float(v[12][0]), toc.costra) and is_equal_approx(float(v[12][1]), toc.costra_max),
		"la costra viaja al espejo (campo 12)")

	print("7) EL ESPANTAJO: CHUPAR A LOS ENRAIZADOS Y MAS SECO MAS PEGA")
	var ed: EnemyData = load("res://scenes/actors/enemy/trent.tres")
	var esp: Combatant = ed.crear_combatant(0.5, true, false, &"espantajo")
	_ver(is_equal_approx(esp.chupa_enraizados, 0.06), "chupa el 6 % de la vida maxima")
	esp.current_hp = esp.max_hp * 0.4
	_ver(is_equal_approx(esp.mult_rabia_tramos(), 1.2) and not esp.rabia_tramos_velocidad,
		"al 40 %% de vida pega un 20 %% mas (x%.2f) y no corre mas" % esp.mult_rabia_tramos())
	esp.current_hp = esp.max_hp * 0.2
	_ver(is_equal_approx(esp.mult_rabia_tramos(), 1.3), "por debajo del 25 %, un 30 % mas")
	var yo: Combatant = combat._aliados_vivos()[0]
	yo.invulnerable = false
	yo.current_hp = yo.max_hp
	toc.chupa_enraizados = 0.06   # (el de la pelea es el Tocon: se le presta la pasiva)
	toc.current_hp = toc.max_hp * 0.5
	var vida_toc: float = toc.current_hp
	en._chupar_enraizados(toc)
	_ver(is_equal_approx(yo.current_hp, yo.max_hp), "sin enraizar no le chupa")
	yo.apply_status(StatusEffects.Id.ENRAIZADO, 2)
	en._chupar_enraizados(toc)
	var quitado: float = yo.max_hp - yo.current_hp
	_ver(is_equal_approx(quitado, yo.max_hp * 0.06), "enraizado le quita el 6 %% de su maxima (%.2f)" % quitado)
	_ver(is_equal_approx(toc.current_hp - vida_toc, quitado), "y se cura justo eso (+%.2f)" % (toc.current_hp - vida_toc))
	yo.statuses.clear()
	toc.chupa_enraizados = 0.0

	print("8) LA GARRAPATA: ENGORDA Y REVIENTA")
	var dg: EnemyData = load("res://resources/enemigos_invocados/bicho_garrapata.tres")
	var g: Combatant = dg.crear_combatant(0.5, false, false, &"", 1)
	_ver(g.hincha_tope == 3, "se hincha hasta 3")
	if combat.altas._meter_enemigo(g, true) < 0:
		_ver(false, "cabe en la pelea")
		return
	tm.lanzar_cria(g, dg, tm.pos_de(toc), tm.sitio_grieta(toc, dg))   # el cuerpo se lo da el salto
	await _esperar(60)
	_ver(tm.cuerpo_de(g) != null, "tiene cuerpo en el mapa")
	var eng: AbilityData = g.habilidades[0]
	var ps: Vector2 = tm.pies_de(yo)
	# A su lado (el salto del Tocon la deja donde caiga, a veces fuera de los 60 px del Enganche).
	var cg: Node2D = tm.cuerpo_de(g)
	cg.global_position += ps + Vector2(35, 0) - tm.pies_de(g)
	tm._pos[g] = cg.global_position
	await _esperar(3)
	for _i in 8:
		g.ability_cooldowns.clear()
		en._enemy_use_ability(g, eng, yo)
		await _esperar(3)
		if g.hinchazon > 0:
			break
	_ver(g.hinchazon >= 1, "cada chupada la hincha (%d)" % g.hinchazon)
	g.hinchazon = 3
	en._enemy_use_ability(g, eng, yo)
	_ver(g.hinchazon == 3, "sin pasar de 3")
	tm._tick_hinchazon()
	_ver(int(tm._hincha_var.get(tm.cuerpo_de(g), 0)) == 3, "y se le ve hinchada (su hoja h3)")
	var vg: Array = combat.espejo._valores([g])[0]
	_ver(int(vg[12][2]) == 3, "la hinchazon viaja al espejo")
	yo.current_hp = yo.max_hp
	tm.soltar_pegada(g, "")
	await _esperar(3)
	var cug: Node2D = tm.cuerpo_de(g)
	cug.global_position += ps + Vector2(10, 0) - tm.pies_de(g)
	tm._pos[g] = cug.global_position
	g.current_hp = 0.0
	combat._morir_enemigo(g)
	var esperado: float = g.atk() * 0.4 * 3.0
	_ver(yo.max_hp - yo.current_hp > 0.0, "muerta hinchada revienta y le da al de al lado (%.2f, esperado %.2f sin mitigar)" % [
		yo.max_hp - yo.current_hp, esperado])
	_ver(g.hinchazon == 0, "y revienta una sola vez")

	print("9) LOS EFECTOS SE VEN (paso 5): lo que se queda sobre los cuerpos, por sus estados")
	var arena: Node = tm._arena()
	if tm._trent == null:
		tm._trent = TacticoTrent.new(tm)
	var tt: TacticoTrent = tm._trent
	yo.current_hp = yo.max_hp
	yo.apply_status(StatusEffects.Id.RESINADO, 2)
	yo.apply_status(StatusEffects.Id.SAVIA_NEGRA, 3)
	yo.apply_status(StatusEffects.Id.PRINGADO, 2)
	yo.apply_status(StatusEffects.Id.PICOR, 3)
	tt.tick()
	_ver(tt._resina.has(yo) and tt._humo.has(yo) and tt._pringue.has(yo) and tt._picor.has(yo),
		"resinado, savia negra, pringado y picor: cada uno con su dibujo encima")
	tm._tick_raices()
	_ver(not tm._raices.has(yo), "el resinado no lleva las raices del enraizado (lleva su cepo)")
	yo.statuses.clear()
	tt.tick()
	_ver(not tt._resina.has(yo) and not tt._humo.has(yo), "sin los estados, se van")
	# la capa de ambar del set Ambar: al romperse, el estallido
	yo.costra_max = 10.0
	yo.costra = 10.0
	tt.tick()
	var antes_n: int = arena.get_children().filter(func(n): return n is TrentAire).size()
	yo.take_damage(20.0)
	tt.tick()
	var despues_n: int = arena.get_children().filter(func(n): return n is TrentAire).size()
	_ver(despues_n > antes_n, "la capa de ambar de los tuyos revienta en grumos al romperse")
	yo.costra_max = 0.0
	# el Geiser y la Bola por su huella
	var f := CombatFormas.circulo(tm.pies_de(yo), 45.0)
	var gs: Node = SueloRoto.lanzar(arena, f, SueloRoto.Tipo.TRENT_GEISER, 3)
	_ver(gs is TrentAire and (gs as TrentAire).modo == TrentAire.Modo.GEISER and (gs as TrentAire).version == 1,
		"el Geiser sale por su huella, con la nube (la B)")
	var fl := CombatFormas.linea(tm.pies_de(yo), Vector2.RIGHT, 100.0, 14.0)
	_ver(SueloRoto.lanzar(arena, fl, SueloRoto.Tipo.AMBAR_BOLA, 4) is AmbarAire, "la Bola de caca rueda por su huella")
	_ver(is_equal_approx(SueloRoto.retraso(fl, tm.pies_de(yo) + Vector2(50, 0), SueloRoto.Tipo.AMBAR_BOLA), AmbarAire.T_RUEDA * 0.5),
		"y le da a cada uno cuando la bola llega")
