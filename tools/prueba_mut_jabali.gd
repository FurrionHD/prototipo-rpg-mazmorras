# LOS MUTANTES DEL JABALI (31/10): Jabali -> COLMILLO DE CRISTAL -> JABALI ANCESTRAL. El arbol, sus stats (las seis, suma
# 136, el jabali estrena Voluntad), sus ataques (la Cornada de cristal en vez de la de siempre) y sus sprites (con sus
# variantes de la pelea: los colmillos rotos y el ancestral pelado).
# Y EN LA PELEA (su sala): la CORNADA DE CRISTAL que le parte los colmillos (y la de los muñones mientras le duran, con
# su estallido y su variante), las ESPORAS, las DRUSAS QUE REFLEJAN la magia de frente y la CHEPA que aguanta las areas
# hasta que el fuego se la quema (con su animacion y su variante pelada).
# Sin ventana:
#   godot --headless --path . res://tools/prueba_mut_jabali.tscn
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


func _poner(tm, c: Combatant, p: Vector2) -> void:
	var cu: Node2D = tm.cuerpo_de(c)
	cu.global_position += p - tm.pies_de(c)
	tm._pos[c] = cu.global_position


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _nombres(c: Combatant) -> Array:
	return c.habilidades.map(func(a): return a.nombre)


func _correr() -> void:
	var ed: EnemyData = load("res://scenes/actors/enemy/jabali.tres")

	print("1) EL ARBOL")
	var c0: Combatant = ed.crear_combatant(0.5, false)
	var c1: Combatant = ed.crear_combatant(0.5, true, false, &"colmillo")
	var c2: Combatant = ed.crear_combatant(0.5, true, false, &"ancestral")
	_ver(c1.nombre == "Colmillo de cristal" and c2.nombre == "Jabalí ancestral", "nombres (%s / %s)" % [c1.nombre, c2.nombre])
	_ver(ed.siguiente_mutacion(false, &"")["id"] == &"colmillo", "del jabali sale el Colmillo de cristal")
	_ver(ed.siguiente_mutacion(true, &"colmillo")["id"] == &"ancestral", "y de el, el Jabali ancestral")

	print("2) LAS STATS (las seis, suma 136)")
	_ver(ed.voluntad == 14 and ed.fuerza + ed.resistencia + ed.destreza + ed.agilidad + ed.magia + ed.voluntad == 136,
		"el jabali: 40/36/14/24/8/14 (estrena Voluntad)")
	for id in [&"colmillo", &"ancestral"]:
		var p: Dictionary = ed.mutacion_de(id).pesos
		var suma: int = 0
		for k in p:
			suma += int(p[k])
		_ver(suma == 136 and p.size() == 6, "%s: reparto de las seis, suma %d" % [id, suma])
	_ver(c2.hab("resistencia") > c1.hab("resistencia") and c2.hab("agilidad") < c1.hab("agilidad"),
		"el ancestral, mas duro y mas lento")

	print("3) LOS ATAQUES")
	print("    colmillo  %s" % [_nombres(c1)])
	print("    ancestral %s" % [_nombres(c2)])
	_ver(_nombres(c1) == ["Embestida", "Pisotón", "Cornada de cristal"], "el Colmillo: la Cornada de cristal")
	_ver(_nombres(c2) == ["Embestida", "Pisotón", "Cornada de cristal"], "el ancestral, tambien (la suya)")
	var cc: AbilityData = c1.habilidades[2]
	var ca: AbilityData = c2.habilidades[2]
	_ver(is_equal_approx(cc.dano_mult, 1.6) and int(cc.forma) == 3 and is_equal_approx(cc.forma_radio, 50.0),
		"Cornada de cristal: x1,6, linea de 50")
	_ver(is_equal_approx(ca.dano_mult, 1.9) and is_equal_approx(ca.forma_radio, 60.0), "la del ancestral: x1,9, linea de 60")
	var sang: bool = false
	for a in ca.efectos:
		if a.estado == StatusEffects.Id.SANGRADO and a.stacks == 2:
			sang = true
	_ver(sang, "la del ancestral abre 2 cargas de Sangrado")

	print("4) LOS SPRITES")
	var sf0: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, false, &"")
	_ver(sf0 != null and sf0.has_animation(&"comer_0"), "el jabali normal ya come")
	for id in [&"colmillo", &"ancestral"]:
		var sf: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, id)
		_ver(sf != null and SpritesEnemigo.mutante_propio(ed, id) and sf.has_animation(&"evolucion_1")
			and sf.has_animation(&"cornada_2") and sf.has_animation(&"comer_3"), "%s: su hoja propia (evolucion, cornada, comer)" % id)
		_ver(sf == SpritesEnemigo.frames_de(ed, 0.9, true, id), "%s: sin tinte de piso" % id)
	var variantes := {&"colmillo": [&"rotos"], &"ancestral": [&"rotos", &"pelado", &"pelado_rotos"]}
	for id in variantes:
		for vr in variantes[id]:
			var sv: SpriteFrames = SpritesEnemigo.frames_variante(ed, id, vr)
			_ver(sv != null and sv.has_animation(&"idle_0") and sv.has_animation(&"cornada_4")
				and sv != SpritesEnemigo.frames_de(ed, 0.5, true, id), "%s %s: su variante" % [id, vr])
	_ver(SpritesEnemigo.frames_variante(ed, &"colmillo", &"pelado") == null, "(el Colmillo no tiene variante pelada)")
	_ver(SpritesEnemigo.frames_de(ed, 0.5, true, &"ancestral").has_animation(&"quemandose_2")
		and SpritesEnemigo.frames_variante(ed, &"ancestral", &"rotos").has_animation(&"quemandose_2"),
		"el ancestral (y roto) se puede quemar: su animacion 'quemandose'")

	await _pelea()
	print("FIN: %s" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)


func _pelea() -> void:
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_mut_jabali", Game.PISO_ARENA):
		_ver(false, "arranca la sala")
		return
	sala.poner("res://scenes/actors/enemy/jabali.tres", Vector2(90, 0), {})
	await _esperar(25)
	var nodos: Array = get_tree().get_nodes_in_group("enemy")
	nodos[0].aplicar_mutacion(&"ancestral", 0.0)
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
	var jab: Combatant = null
	for e in combat._enemies:
		if e.mutacion == &"ancestral":
			jab = e
	_ver(jab != null, "en la pelea, un Jabali ancestral")
	if jab == null:
		return
	var al: Array = combat._aliados_vivos()
	var yo: Combatant = al[0]
	for a in al:
		(a as Combatant).current_hp = (a as Combatant).max_hp
		(a as Combatant).invulnerable = false
	var ps: Vector2 = tm.pies_de(yo)
	_poner(tm, jab, ps + Vector2(40, 0))
	var cu: Node2D = tm.cuerpo_de(jab)
	cu.set("_facing", Vector2.LEFT)   # mirandote
	await _esperar(2)
	var cornada: AbilityData = jab.habilidades[2]

	print("6) LA CORNADA DE CRISTAL Y LOS COLMILLOS")
	en._enemy_use_ability(jab, cornada, yo)
	_ver(jab.has_status(StatusEffects.Id.COLMILLOS_ROTOS), "al hacerla se le parten los colmillos")
	jab.ability_cooldowns.clear()
	en._enemy_use_ability(jab, cornada, yo)
	_ver(not jab.ability_ready(cornada.rota), "con ellos rotos usa la de los muñones (%s)" % cornada.rota.nombre)
	_ver(not jab.ability_ready(cornada), "(y la de cristal se enfria igual, o la volveria a elegir)")
	tm._tick_jabali()
	_ver(String(tm._jabali_var.get(cu, "")) == "rotos", "su sprite pasa a la variante rota")
	var est: int = 0
	for n in tm._arena().get_children():
		if n is JabaliAire and n.modo == JabaliAire.Modo.ESTALLIDO:
			est += 1
	_ver(est == 1, "con el estallido de cristal")
	var turnos: int = 0
	while jab.has_status(StatusEffects.Id.COLMILLOS_ROTOS) and turnos < 6:
		jab.tick_statuses()
		turnos += 1
	# (se los parte en SU turno: rotos los 2 siguientes, y al empezar el 3o ya le han crecido -> 3 pasos de turno)
	_ver(turnos == 3, "rotos 2 turnos suyos y al 3o le han crecido (%d pasos de turno)" % turnos)
	tm._tick_jabali()
	_ver(String(tm._jabali_var.get(cu, "")) == "", "y vuelve a verse entero")

	print("7) LAS ESPORAS")
	_poner(tm, jab, ps + Vector2(24, 0))
	await _esperar(2)
	var p0: float = jab.esporas_prob
	jab.esporas_prob = 1.0
	jab.eficacia = 99.0
	var res0: float = yo.status_resist
	yo.status_resist = 0.0
	yo.statuses.clear()
	# Hasta 6 nubes: ningun estado entra SEGURO (StatusEffects.PROB_TECHO = 95 %), y con una sola fallaba 1 de cada 20.
	for _i in 6:
		combat._esporas(jab, yo)
		if yo.has_status(StatusEffects.Id.VENENO):
			break
	_ver(yo.has_status(StatusEffects.Id.VENENO), "un golpe cuerpo a cuerpo: la nube le envenena")
	yo.statuses.clear()
	_poner(tm, jab, ps + Vector2(120, 0))
	await _esperar(2)
	combat._esporas(jab, yo)
	_ver(not yo.has_status(StatusEffects.Id.VENENO), "(de lejos no salta)")
	jab.esporas_prob = p0
	yo.status_resist = res0

	print("8) LAS DRUSAS QUE REFLEJAN")
	_poner(tm, jab, ps + Vector2(60, 0))
	cu.set("_facing", Vector2.LEFT)
	await _esperar(2)
	var sp: SpellData = load("res://resources/spells/descarga.tres")
	combat._player = yo
	var hp_y: float = yo.current_hp
	var r1: Dictionary = combat.magia._resolver_golpes_hechizo(sp, jab, 1.0)
	_ver(absf((hp_y - yo.current_hp) - float(r1["dano"]) * 0.25) < 0.05,
		"de frente le devuelve el 25 %% (%.2f de %.2f)" % [hp_y - yo.current_hp, float(r1["dano"])])
	cu.set("_facing", Vector2.RIGHT)
	hp_y = yo.current_hp
	combat.magia._resolver_golpes_hechizo(sp, jab, 1.0)
	_ver(is_equal_approx(hp_y, yo.current_hp), "por la espalda, nada")
	cu.set("_facing", Vector2.LEFT)

	print("9) LA CHEPA QUE AGUANTA Y EL FUEGO")
	_ver(is_equal_approx(combat.mult_chepa(jab, true), 0.6) and is_equal_approx(combat.mult_chepa(jab, false), 1.0),
		"las areas le hacen un 40 % menos (un golpe suelto, entero)")
	combat.fuego_al_musgo(jab, Elementos.Elemento.AGUA)
	_ver(not jab.has_status(StatusEffects.Id.MUSGO_QUEMADO), "(el agua no lo quema)")
	combat.fuego_al_musgo(jab, Elementos.Elemento.FUEGO)
	_ver(jab.has_status(StatusEffects.Id.MUSGO_QUEMADO), "un golpe de fuego le quema el musgo")
	_ver(is_equal_approx(combat.mult_chepa(jab, true), 1.0), "y ya le entran las areas enteras")
	tm._tick_jabali()
	var qu: int = 0
	for n in tm._arena().get_children():
		if n is JabaliAire and n.modo == JabaliAire.Modo.QUEMA:
			qu += 1
	_ver(qu == 1 and String((cu.get("_sprite") as AnimatedSprite2D).animation).begins_with("quemandose"),
		"arde: su animacion de quemarse con las llamas")
	var pelado: bool = false
	for _i in 300:
		tm._tick_jabali()
		if String(tm._jabali_var.get(cu, "")) == "pelado":
			pelado = true
			break
		await get_tree().process_frame
	_ver(pelado, "y al acabar queda pelado")
	var otro: Combatant = load("res://scenes/actors/enemy/jabali.tres").crear_combatant(0.5, true, false, &"colmillo")
	otro.apply_status(StatusEffects.Id.QUEMADURA, 2, 3.0)
	_ver(not otro.has_status(StatusEffects.Id.MUSGO_QUEMADO), "(el Colmillo no tiene musgo que quemar)")
	jab.statuses.clear()
	jab.apply_status(StatusEffects.Id.QUEMADURA, 2, 3.0)
	_ver(jab.has_status(StatusEffects.Id.MUSGO_QUEMADO), "una Quemadura tambien se lo quema")
