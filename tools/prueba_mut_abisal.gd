# LOS MUTANTES DEL SLIME ABISAL (06/10): abisal -> SLIME DE CIELO NOCTURNO -> SLIME DE MIL OJOS en la pelea del mapa. Las
# ESTRELLAS que dejan al moverse (tope 6, la mas vieja se va, viajan con las huellas), TODO LO VE, y los ataques: Lluvia de
# estrellas, Constelacion, Eclipse, Agujero negro, Parpadeo cegador y Mirada estelar (que no falla y se la come quien se
# ponga delante). Sin ventana:
#   godot --headless --path . res://tools/prueba_mut_abisal.tscn
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


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _ab(nombre: String) -> AbilityData:
	return load("res://resources/abilities/%s.tres" % nombre) as AbilityData


# Pone a 'c' (de los tuyos) en 'p' (sus pies).
func _poner(tm, c: Combatant, p: Vector2) -> void:
	var cu: Node2D = tm.cuerpo_de(c)
	cu.global_position += p - tm.pies_de(c)
	tm._pos[c] = cu.global_position


# (07/10) EL DADO FIJO: ningun estado entra seguro (StatusEffects.PROB_TECHO = 95 %), asi que se fija la semilla
# antes de cada habilidad que se mira: misma tirada en cada pasada, la prueba no depende de la suerte.
func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(5)
	Game.entrar_arena_de_pruebas()
	await _esperar(15)
	var ed: EnemyData = load("res://scenes/actors/enemy/slime_abisal.tres")

	print("1) EL ARBOL")
	var c1: Combatant = ed.crear_combatant(0.5, true, false, &"cielo")
	var c2: Combatant = ed.crear_combatant(0.5, true, false, &"ojos")
	var c0: Combatant = ed.crear_combatant(0.5, false, false)
	print("    %s / %s" % [c1.nombre, c2.nombre])
	_ver(c1.nombre == "Slime de cielo nocturno" and c2.nombre == "Slime de mil ojos", "nombres")
	_ver(c1.deja_estrellas and c2.deja_estrellas and not c0.deja_estrellas, "los dos dejan estrellas (el abisal no)")
	_ver(c2.todo_lo_ve and not c1.todo_lo_ve, "el de mil ojos TODO LO VE")
	_ver(absf(c2.precision - c1.precision - 0.15) < 0.001, "y apunta un 15 %% mejor (%.2f / %.2f)" % [c2.precision, c1.precision])
	_ver(c1.habilidades.size() == 4 and c2.habilidades.size() == 5, "4 ataques el cielo, 5 el de mil ojos")
	_ver(ed.siguiente_mutacion(true, &"cielo")["id"] == &"ojos" and ed.siguiente_mutacion(false, &"")["id"] == &"cielo",
		"del abisal al cielo y del cielo a los ojos")

	print("2) LOS SPRITES")
	var sf1: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, &"cielo")
	var sf2: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, &"ojos")
	_ver(sf1 != null and sf1.has_animation(&"lluvia_0") and sf1.has_animation(&"constelar_3")
		and sf1.has_animation(&"evolucion_0"), "el cielo con sus anims (lluvia, constelar, evolucion)")
	_ver(sf2 != null and sf2.has_animation(&"mirada_0") and sf2.has_animation(&"fijar_5") and sf2.has_animation(&"cegar_2")
		and not sf2.has_animation(&"constelar_0"), "el de mil ojos con las suyas (y sin constelar)")
	_ver(SpritesEnemigo.parpados_de(ed, 0.5, true, &"ojos") != null, "el de mil ojos parpadea")
	var extra: Array = SpritesEnemigo.parpados_extra_de(ed, 0.5, true, &"ojos")
	_ver(extra.size() == 5, "y en 6 grupos, cada uno a su aire (%d hojas de mas)" % extra.size())
	_ver(SpritesEnemigo.parpados_extra_de(ed, 0.5, true, &"cielo").is_empty(), "el cielo, con un solo parpadeo")
	var sp := AnimatedSprite2D.new()
	add_child(sp)
	sp.sprite_frames = sf2
	SpritesEnemigo.poner_parpados(sp, ed, 0.5, true, &"ojos")
	_ver(sp.get_node_or_null("Parpados") != null and sp.get_node_or_null("Parpados6") != null, "6 capas de parpadeo")
	sp.queue_free()

	print("3) LA PELEA")
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime_abisal.tres", jug.global_position + Vector2(70, 0), {})
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime_abisal.tres", jug.global_position + Vector2(90, 40), {})
	await _esperar(25)
	var nodos: Array = get_tree().get_nodes_in_group("enemy")
	nodos[0].mutar(0.0)
	nodos[1].mutar(0.0)
	nodos[1].mutar(0.0)
	await _esperar(5)
	if not Game.start_combat(nodos, false):
		print("FIN: HAY FALLOS (no arranca la pelea)")
		get_tree().quit(1)
		return
	await _esperar(8)
	var combat: Node = null
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	combat.set_process(false)   # la barra la movemos a mano
	var tm = combat.turno_mapa
	var en = combat.enemigos
	var cielo: Combatant = null
	var ojos: Combatant = null
	for e in combat._enemies:
		if e.mutacion == &"cielo":
			cielo = e
		elif e.mutacion == &"ojos":
			ojos = e
	_ver(cielo != null and ojos != null, "en la pelea, un cielo nocturno y un mil ojos")
	if cielo == null or ojos == null:
		print("FIN: HAY FALLOS (%d MAL)" % _mal)
		get_tree().quit(1)
		return
	var al: Array = combat._aliados_vivos()
	for a in al:
		(a as Combatant).status_resist = 0.0
		(a as Combatant).current_hp = (a as Combatant).max_hp
	var pc: Vector2 = tm.pies_de(cielo)
	cielo.precision = 5.0   # (que no los esquiven: aqui se mira lo que hacen al entrar)
	ojos.precision = 5.0

	print("4) LAS ESTRELLAS")
	for i in 7:
		tm.poner_estrella(cielo, pc + Vector2(-60 + i * 10, -50))
	var est: Array = tm.estrellas_de(cielo)
	_ver(est.size() == 6, "tope de 6 estrellas (%d)" % est.size())
	_ver(est[0].x > pc.x - 60 + 5, "la mas vieja se ha ido")
	var hay_red: bool = false
	var hu: PackedFloat32Array = tm.estado_huellas()
	for i in range(0, hu.size(), tm.FLOATS_HUELLA):
		if int(hu[i + 1]) >= tm.CLASE_ESTRELLA:
			hay_red = true
	_ver(hay_red, "viajan con las huellas")
	var sin_estrellas: Array = tm.estrellas_de(ojos)
	# Andar deja una: se le aleja la presa y anda su turno.
	_poner(tm, al[0], pc + Vector2(-260, 0))
	for a2 in al.slice(1):
		_poner(tm, a2, pc + Vector2(-260, 30))
	var n0: int = tm.estrellas_de(cielo).size()
	for k in tm._orden_estrellas.get(cielo, []).duplicate():
		tm._quitar_estrella(cielo, int(k))
	cielo.ability_cooldowns.clear()
	for ab in cielo.habilidades:
		cielo.start_cooldown(ab)   # que solo ande y pegue normal
	cielo.prob_habilidad = 0.0
	combat._state = combat.State.ADVANCING
	tm.turno_enemigo(cielo)
	for _i in 200:
		await get_tree().process_frame
		tm.tick(1.0 / 60.0)
		if combat._state != combat.State.PAUSED or combat._pause_left != INF:
			break
	_ver(tm.estrellas_de(cielo).size() == 1, "al andar en su turno deja una estrella donde estaba (%d, antes %d)"
		% [tm.estrellas_de(cielo).size(), n0])
	_ver(sin_estrellas.is_empty(), "(el otro aun no tiene)")
	cielo.ability_cooldowns.clear()

	print("5) CONSTELACION")
	for k in tm._orden_estrellas.get(cielo, []).duplicate():
		tm._quitar_estrella(cielo, int(k))
	pc = tm.pies_de(cielo)
	tm.poner_estrella(cielo, pc + Vector2(-80, -60))
	tm.poner_estrella(cielo, pc + Vector2(-80, 60))
	_poner(tm, al[0], pc + Vector2(-80, 0))   # en medio del primer rayo
	for a2 in al.slice(1):
		_poner(tm, a2, pc + Vector2(0, -150))
	var cons: AbilityData = _ab("slime_constelacion")
	_ver(tm.constelacion_pilla(cielo, cons), "con dos estrellas, el rayo pilla al que esta en medio")
	var hp: float = al[0].current_hp
	seed(4242)
	en._enemy_use_ability(cielo, cons)
	_ver(al[0].current_hp < hp, "se lleva el rayo (%.1f -> %.1f)" % [hp, al[0].current_hp])
	_poner(tm, al[0], pc + Vector2(0, 150))
	_ver(not tm.constelacion_pilla(cielo, cons), "fuera de los rayos no le sirve")
	await _esperar(3)

	print("6) LLUVIA DE ESTRELLAS")
	var ll: AbilityData = _ab("slime_lluvia_estrellas").duplicate()
	ll.forma_radio = 14.0   # (todas caen encima: para medir los golpes)
	ll.fugaz_radio = 40.0
	_poner(tm, al[0], pc + Vector2(-70, 0))
	for a2 in al.slice(1):
		_poner(tm, a2, pc + Vector2(0, -400))   # (que apunte al que se mide)
	cielo.ability_cooldowns.clear()
	tm.guardar_carga_enemigo(cielo, ll, al[0])
	hp = al[0].current_hp
	seed(4242)
	en._enemy_use_ability(cielo, ll)
	_ver(al[0].current_hp < hp, "le caen las estrellas (%.1f -> %.1f)" % [hp, al[0].current_hp])
	var f_ll = tm.ultima_forma_enemigo
	_ver(f_ll != null and AbisalAire.puntos_lluvia(f_ll, 4).size() == 4, "4 estrellas fugaces")
	await _esperar(3)

	# (07/10) En el Eclipse y el Agujero se mira lo que hacen AL ENTRAR: nadie los esquiva (la evasion de los tuyos, a
	# tope por abajo) y el Vulnerable del Agujero, seguro (en la ficha es un 60 %). Fallaban a ratos por la suerte. Al
	# acabar se devuelve todo.
	var evasion0: Array = al.map(func(x): return (x as Combatant).evasion_bonus)
	for a_e in al:
		(a_e as Combatant).evasion_bonus = -5.0
	print("7) ECLIPSE")
	# (con otro de los tuyos: al primero ya le pudo cegar la Lluvia, y repetir el mismo estado cuesta mas)
	_poner(tm, al[1], pc + Vector2(-40, 0))
	al[1].statuses.clear()
	seed(4242)
	en._enemy_use_ability(cielo, _ab("slime_eclipse"))
	_ver(al[1].has_status(StatusEffects.Id.CEGUERA), "deja ciego al que esta cerca")
	_poner(tm, al[1], pc + Vector2(0, -400))
	await _esperar(3)

	print("8) AGUJERO NEGRO")
	var ag: AbilityData = _ab("slime_agujero_negro").duplicate(true)
	for ef in ag.efectos:
		ef.prob = 1.0
	_poner(tm, al[0], pc + Vector2(-70, 20))
	al[0].statuses.clear()
	tm.guardar_carga_enemigo(cielo, ag, al[0])
	tm._tirones.clear()
	cielo.precision = 5.0   # (que no lo esquive: aqui se mira lo que hace al entrar)
	hp = al[0].current_hp
	seed(4242)
	en._enemy_use_ability(cielo, ag)
	_ver(al[0].current_hp < hp, "pega (%.1f -> %.1f)" % [hp, al[0].current_hp])
	_ver(al[0].has_status(StatusEffects.Id.VULNERABLE), "y deja vulnerable")
	var atrae: bool = false
	for tr in tm._tirones:
		if tr.get("c") == al[0] and tr.has("hacia"):
			atrae = true
	_ver(atrae, "y lo atrae hacia el centro")
	await _esperar(3)
	for i_e in al.size():
		(al[i_e] as Combatant).evasion_bonus = float(evasion0[i_e])

	print("9) EL DE MIL OJOS: TODO LO VE")
	var po: Vector2 = tm.pies_de(ojos)
	al[0].apply_status(StatusEffects.Id.SIGILO)
	var p_ojos: float = combat.objetivos._peso_aggro(al[0], ojos)
	var p_cielo: float = combat.objetivos._peso_aggro(al[0], cielo)
	al[0].statuses.clear()
	var p_sin: float = combat.objetivos._peso_aggro(al[0], ojos)
	print("    peso con sigilo: mil ojos %.2f, cielo %.2f, sin sigilo %.2f" % [p_ojos, p_cielo, p_sin])
	_ver(is_equal_approx(p_ojos, p_sin), "el sigilo no le esconde a nadie")

	print("10) PARPADEO CEGADOR")
	_poner(tm, al[0], po + Vector2(-35, 0))
	tm._animar(tm.cuerpo_de(ojos), Vector2(-1, 0), false)
	hp = al[0].current_hp
	seed(4242)
	en._enemy_use_ability(ojos, _ab("slime_parpadeo_cegador"))
	_ver(al[0].current_hp < hp, "fogonazo al de delante (%.1f -> %.1f)" % [hp, al[0].current_hp])
	await _esperar(3)

	print("11) MIRADA ESTELAR")
	var mi: AbilityData = _ab("slime_mirada_estelar")
	for k in tm._orden_estrellas.get(ojos, []).duplicate():
		tm._quitar_estrella(ojos, int(k))
	tm.poner_estrella(ojos, po + Vector2(0, -90))
	tm.poner_estrella(ojos, po + Vector2(0, 90))
	_poner(tm, al[0], po + Vector2(-120, 0))
	for a2 in al.slice(1):
		_poner(tm, a2, po + Vector2(150, -150))
	tm.guardar_carga_enemigo(ojos, mi, al[0])
	var presa = tm._presas_carga.get(ojos)
	print("    presa: %s" % (presa.nombre if presa != null else "ninguna"))
	if presa != null and presa != al[0]:
		_poner(tm, presa, po + Vector2(-120, 0))
		_poner(tm, al[0], po + Vector2(150, 150))
	var lista: Array = tm.reparto_rayos(ojos, mi, null) if presa != null else []
	var golpes_presa: int = 0
	for o in lista:
		if o["c"] == presa:
			golpes_presa = int(o["golpes"])
	_ver(golpes_presa == 3, "un rayo de el y uno de cada estrella: 3 golpes a su presa (%d)" % golpes_presa)
	# Alguien se pone DELANTE: se come el rayo principal.
	var otro: Combatant = null
	for a3 in al:
		if a3 != presa:
			otro = a3
	if presa != null and otro != null:
		tm.guardar_carga_enemigo(ojos, mi, presa)
		tm._presas_carga[ojos] = presa
		_poner(tm, otro, po + Vector2(-60, 0))
		lista = tm.reparto_rayos(ojos, mi, null)
		var g_p: int = 0
		var g_o: int = 0
		for o in lista:
			if o["c"] == presa:
				g_p = int(o["golpes"])
			if o["c"] == otro:
				g_o = int(o["golpes"])
		_ver(g_p == 2 and g_o == 1, "el que se pone delante se come el principal (presa %d, delante %d)" % [g_p, g_o])
		# Y no falla.
		for a4 in al:
			(a4 as Combatant).evasion_bonus = 5.0
		tm.guardar_carga_enemigo(ojos, mi, presa)
		tm._presas_carga[ojos] = presa
		_poner(tm, otro, po + Vector2(150, 150))
		hp = presa.current_hp
		seed(4242)
		en._enemy_use_ability(ojos, mi)
		_ver(presa.current_hp < hp, "no falla aunque esquive mucho (%.1f -> %.1f)" % [hp, presa.current_hp])
	await _esperar(3)

	print("12) CON EL RETRASO DE LA BARRA")
	ojos.ability_cooldowns.clear()
	en._enemy_begin_retraso(ojos, mi, presa)
	_ver(ojos.retrasando and tm._presas_carga.has(ojos), "la Mirada espera media barra con su presa ya fijada")
	combat._state = combat.State.ADVANCING
	tm._turno_enemigo_de_siempre(ojos)
	_ver(ojos.charging == mi and not ojos.retrasando and ojos.charge_left == 1, "al llegar empieza a fijar (la carga)")

	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
