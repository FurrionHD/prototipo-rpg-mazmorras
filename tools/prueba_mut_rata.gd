# LOS MUTANTES DE LA RATA (30/10): Rata -> RATA SOMBRIA / RATA DRUSA -> RATA DE CUARZO AHUMADO. El arbol, sus stats
# (tablas de los slimes con su reparto de las seis), sus ataques (los de siempre MEJORADOS y los nuevos), sus pasivas
# (resiste magia y fragil a contundentes; sigilo y salto al esquivar) y sus sprites (con la evolucion de dos padres).
# Y EN LA PELEA (su sala): el SIGILO DE VERDAD (entra al empezar su turno, no se le ve ni se le elige, las areas le dan,
# sale con un golpe), el primer Mordisco sombrio inesquivable desde las sombras, la TRAICION a la espalda (+25 %) y el
# SALTO al esquivar cuerpo a cuerpo.
# Sin ventana:
#   godot --headless --path . res://tools/prueba_mut_rata.tscn
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
	var ed: EnemyData = load("res://scenes/actors/enemy/rata.tres")

	print("1) EL ARBOL")
	var c0: Combatant = ed.crear_combatant(0.5, false)
	var cs: Combatant = ed.crear_combatant(0.5, true, false, &"sombria")
	var cd: Combatant = ed.crear_combatant(0.5, true, false, &"drusa")
	var cq: Combatant = ed.crear_combatant(0.5, true, false, &"cuarzo")
	print("    %s / %s / %s" % [cs.nombre, cd.nombre, cq.nombre])
	_ver(cs.nombre == "Rata sombría" and cd.nombre == "Rata drusa" and cq.nombre == "Rata de cuarzo ahumado", "nombres")
	var primeras: Array = []
	for _i in 60:
		primeras.append(ed.siguiente_mutacion(false, &"")["id"])
	_ver(primeras.has(&"sombria") and primeras.has(&"drusa"), "de la rata sale sombria o drusa")
	_ver(ed.siguiente_mutacion(true, &"sombria")["id"] == &"cuarzo" and ed.siguiente_mutacion(true, &"drusa")["id"] == &"cuarzo",
		"de las dos se llega a la de cuarzo")
	# (la vida tambien sale de su reparto, asi que no da el x2,6 / x3,6 justo: cada una en su banda)
	var v1: float = cs.max_hp / c0.max_hp
	var v1d: float = cd.max_hp / c0.max_hp
	var v2: float = cq.max_hp / c0.max_hp
	_ver(v1 > 2.2 and v1 < 3.0 and v1d > 2.2 and v1d < 3.0 and v2 > 3.0 and v2 < 4.0,
		"vida: tabla de los slimes con su reparto (sombria x%.2f, drusa x%.2f, cuarzo x%.2f)" % [v1, v1d, v2])

	print("2) LAS STATS (las seis, suma 150)")
	_ver(ed.voluntad == 18 and ed.fuerza + ed.resistencia + ed.destreza + ed.agilidad + ed.magia + ed.voluntad == 150,
		"la rata: 26/18/36/40/12/18 (estrena Voluntad)")
	for id in [&"sombria", &"drusa", &"cuarzo"]:
		var p: Dictionary = ed.mutacion_de(id).pesos
		var suma: int = 0
		for k in p:
			suma += int(p[k])
		_ver(suma == 150 and p.size() == 6, "%s: reparto de las seis, suma %d" % [id, suma])
	_ver(cd.hab("voluntad") > cs.hab("voluntad") * 2.0, "la drusa con mucha mas Voluntad que la sombria")
	_ver(cs.hab("agilidad") > cd.hab("agilidad"), "la sombria mas agil")

	print("3) LOS ATAQUES")
	print("    sombria %s" % [_nombres(cs)])
	print("    drusa   %s" % [_nombres(cd)])
	print("    cuarzo  %s" % [_nombres(cq)])
	_ver(_nombres(cs) == ["Mordisco sombrío", "Frenesí en la sombra", "Mordisco a traición"], "la sombria: sus mejorados + Traicion")
	_ver(_nombres(cd) == ["Mordisco de cristal", "Frenesí de esquirlas", "Embestida de cristal"], "la drusa: sus mejorados + Embestida")
	_ver(_nombres(cq).size() == 5 and _nombres(cq).has("Destello") and _nombres(cq).has("Mordisco sombrío")
		and _nombres(cq).has("Frenesí de esquirlas"), "la de cuarzo: lo mejor de las dos + Destello")
	for c in [cs, cd, cq]:
		for a in c.habilidades:
			_ver(a.es_magico == (a.nombre == "Destello"), "%s: magico solo el Destello" % a.nombre)

	print("4) LAS PASIVAS")
	_ver(is_equal_approx(cd.resiste_magia, 0.6) and is_equal_approx(cd.fragil_contundente, 1.3), "drusa: magia x0,6, contundente x1,3")
	_ver(is_equal_approx(cs.sigilo_prob, 0.5) and is_equal_approx(cs.salto_esquiva, 40.0), "sombria: sigilo 50 %, salto 40 px")
	_ver(is_equal_approx(cq.resiste_magia, 0.6) and is_equal_approx(cq.sigilo_prob, 0.5), "cuarzo: las dos")
	_ver(is_equal_approx(c0.resiste_magia, 1.0) and c0.sigilo_prob == 0.0, "la rata normal, ninguna")
	# El daño magico que le entra a la drusa: x0,6 (misma semilla).
	var mago := Combatant.new("Mago", 1, Abilities.new(), 100.0, 3.0, 3.0, 10.0)
	var sp: SpellData = load("res://resources/spells/descarga.tres") if ResourceLoader.exists("res://resources/spells/descarga.tres") else null
	if sp != null:
		cd.resiste_magia = 1.0
		seed(3)
		var d1: float = float(StatsMath.resolve_spell(mago, cd, sp)["damage"])
		cd.resiste_magia = 0.6
		seed(3)
		var d2: float = float(StatsMath.resolve_spell(mago, cd, sp)["damage"])
		_ver(absf(d2 / d1 - 0.6) < 0.01, "un hechizo a la drusa: %.1f -> %.1f (x0,6)" % [d1, d2])
	else:
		_ver(false, "no encuentro el hechizo de prueba")

	print("5) LOS SPRITES")
	var sf0: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, false, &"")
	_ver(sf0 != null and sf0.has_animation(&"comer_0"), "la rata normal ya come")
	var anims := {&"sombria": ["evolucion_0", "comer_3", "salto_rata_2"], &"drusa": ["evolucion_0", "embestida_1"],
		&"cuarzo": ["evolucion_0", "evolucion_drusa_0", "destello_4", "embestida_1"]}
	for id in anims:
		var sf: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, id)
		var ok: bool = sf != null and SpritesEnemigo.mutante_propio(ed, id)
		for a in anims[id]:
			ok = ok and sf.has_animation(StringName(a))
		_ver(ok, "%s: su hoja propia %s" % [id, anims[id]])
	var sfs: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, &"sombria")
	var sfs2: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.9, true, &"sombria")
	_ver(sfs == sfs2, "sin tinte de piso (la misma hoja en cualquier piso)")

	await _pelea()
	print("FIN: %s" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)


func _pelea() -> void:
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_mut_rata", Game.PISO_ARENA):
		_ver(false, "arranca la sala")
		return
	sala.poner("res://scenes/actors/enemy/rata.tres", Vector2(90, 0), {})
	sala.poner("res://scenes/actors/enemy/rata.tres", Vector2(110, 90), {})
	await _esperar(25)
	var nodos: Array = get_tree().get_nodes_in_group("enemy")
	nodos[0].aplicar_mutacion(&"sombria", 0.0)
	nodos[1].aplicar_mutacion(&"cuarzo", 0.0)
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
	var som: Combatant = null
	var cua: Combatant = null
	for e in combat._enemies:
		if e.mutacion == &"sombria":
			som = e
		elif e.mutacion == &"cuarzo":
			cua = e
	_ver(som != null and cua != null, "en la pelea, una sombria y una de cuarzo")
	if som == null or cua == null:
		return
	var al: Array = combat._aliados_vivos()
	var yo: Combatant = al[0]
	for a in al:
		(a as Combatant).current_hp = (a as Combatant).max_hp
		(a as Combatant).invulnerable = false

	print("6) EL SIGILO DE VERDAD")
	var ps: Vector2 = tm.pies_de(yo)
	_poner(tm, som, ps + Vector2(24, 0))
	_poner(tm, cua, ps + Vector2(0, 160))
	som.sigilo_prob = 1.0
	en._enemy_turn(som)
	await _esperar(2)
	_ver(som.en_sombras(), "al empezar su turno se funde con las sombras")
	combat._target_idx = combat._enemies.find(som)
	_ver(combat._objetivo() != som, "no queda de objetivo (se va a otro: %s)" % combat._objetivo().nombre)
	combat._target_idx = combat._enemies.find(cua)
	combat.figuras._seleccionar(combat._enemies.find(som))
	_ver(combat._enemies[combat._target_idx] == cua, "pinchar en ella no la elige")
	_ver(not tm.llega(yo, som), "pegada a ti y no la alcanzas: no se la ve")
	tm.tick(0.016)
	var cu: Node2D = tm.cuerpo_de(som)
	_ver(not cu.visible, "su cuerpo no se ve")
	var ondas: int = 0
	for _i in 300:
		tm.tick(0.016)
		for n in tm._arena().get_children():
			if n is RataAire and n.modo == RataAire.Modo.ONDA:
				ondas += 1
		if ondas > 0:
			break
		await get_tree().process_frame
	_ver(ondas > 0, "y de vez en cuando el aire ondula donde esta")
	_ver(not cu.visible, "(la niebla no la vuelve a encender)")
	# Sus huellas no se pintan: una carga suya, guardada pero oculta.
	tm.guardar_carga_enemigo(som, _ab_mapa("rata_frenesi_sombra"), yo)
	tm.tick(0.016)
	_ver(tm._arena().huellas.has(som) and tm._arena().huellas_ocultas.has(som), "su huella de carga esta, pero no se pinta")
	tm.olvidar_carga(som)

	print("7) EL MORDISCO SOMBRIO DESDE LAS SOMBRAS")
	var dentro: int = 0
	for k in 20:
		som.statuses.clear()
		som.apply_status(StatusEffects.Id.EN_SOMBRAS)
		yo.evasion_bonus = 5.0   # lo esquivaria todo...
		yo.current_hp = yo.max_hp
		var r: Dictionary = en._enemy_resolver_golpes(som, _ab_mapa("rata_mordisco_sombrio"), yo, 3, 1.0, false, false)
		if int(r["conecto"]) >= 1:
			dentro += 1
	yo.evasion_bonus = 0.0
	_ver(dentro == 20, "esquivandolo todo, el primer bocado entra siempre (%d/20)" % dentro)
	# A la vista, la esquiva (con su tope) a veces se los come todos.
	som.statuses.clear()
	var en_blanco: int = 0
	for k in 20:
		yo.evasion_bonus = 5.0
		yo.current_hp = yo.max_hp
		var r2: Dictionary = en._enemy_resolver_golpes(som, _ab_mapa("rata_mordisco_sombrio"), yo, 3, 1.0, false, false)
		if int(r2["conecto"]) == 0:
			en_blanco += 1
	yo.evasion_bonus = 0.0
	_ver(en_blanco > 0, "(a la vista, a veces los esquivas todos: %d/20)" % en_blanco)

	print("8) LAS AREAS LE DAN Y UN GOLPE LA SACA")
	som.apply_status(StatusEffects.Id.EN_SOMBRAS)
	var hp0: float = som.current_hp
	som.take_damage(3.0)
	_ver(not som.en_sombras() and som.current_hp < hp0, "un golpe de area la saca de las sombras")
	tm.tick(0.016)
	await _esperar(2)
	tm.tick(0.016)
	_ver(cu.visible, "y vuelve a verse")
	som.apply_status(StatusEffects.Id.EN_SOMBRAS)
	som.take_damage(2.0, true)
	_ver(som.en_sombras(), "(el veneno no la saca)")
	som.statuses.clear()

	print("9) LA TRAICION, A LA ESPALDA")
	_poner(tm, som, ps + Vector2(70, 0))
	await _esperar(2)
	var hp1: float = yo.current_hp
	seed(77)
	en._enemy_use_ability(som, _segura("rata_mordisco_traicion"), yo)
	_ver(tm.por_la_espalda(som, yo), "cae detras de su presa")
	var destino: Vector2 = tm.pos_de(som)
	for d in tm._deslices:
		if d["c"] == som:
			destino = d["hasta"]
	var lado: float = (destino + tm._bajo_de(som) - ps).x
	_ver(lado < 0.0, "del otro lado de donde venia (x %+.0f)" % lado)
	_ver(yo.current_hp < hp1, "y muerde (%.1f -> %.1f)" % [hp1, yo.current_hp])
	await _esperar(40)

	print("10) SE APARTA DE UN SALTO")
	som.statuses.clear()
	_poner(tm, som, ps + Vector2(24, 0))
	await _esperar(2)
	var antes: Vector2 = tm.pos_de(som)
	var res := {"evaded": true}
	combat._aplicar_pasivas(res, yo, som)
	var hay: bool = false
	for d in tm._deslices:
		if d["c"] == som and int(d["modo"]) == tm.Desliz.EMPUJON:
			hay = true
			_ver(absf((d["hasta"] as Vector2).distance_to(antes) - 40.0) < 3.0, "salta 40 px (%.1f)"
				% (d["hasta"] as Vector2).distance_to(antes))
			_ver(((d["hasta"] as Vector2) - antes).x > 0.0, "lejos de quien le pegaba")
	_ver(hay, "al esquivar un golpe cuerpo a cuerpo, se aparta")
	var n_antes: int = tm._deslices.size()
	var su_salto: float = cua.salto_esquiva
	cua.salto_esquiva = 0.0
	combat._aplicar_pasivas({"evaded": true}, yo, cua)
	cua.salto_esquiva = su_salto
	_ver(tm._deslices.size() == n_antes, "(los que no lo tienen no saltan)")
	yo.a_distancia = true
	combat._aplicar_pasivas({"evaded": true}, yo, som)
	yo.a_distancia = false
	_ver(tm._deslices.size() == n_antes, "(de una flecha no se aparta: solo cuerpo a cuerpo)")


# Una habilidad suya con los efectos SEGUROS (para mirar que entran).
func _segura(nombre: String) -> AbilityData:
	var ab: AbilityData = _ab_mapa(nombre).duplicate(true)
	for a in ab.efectos:
		a.prob = 1.0
	return ab


func _ab_mapa(nombre: String) -> AbilityData:
	return load("res://resources/abilities/%s.tres" % nombre) as AbilityData
