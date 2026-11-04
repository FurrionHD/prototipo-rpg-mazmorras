# LOS MUTANTES DEL REY RATA (31/10): Rey rata -> REY DE LAS CLOACAS -> REY DEL DESGUACE. El arbol, sus stats (las seis,
# suma 170, el rey estrena Voluntad), sus ataques (el desguace suma el Tapazo), sus pasivas y sus sprites (con la rata
# acorazada que llama el desguace).
# Y EN LA PELEA (su sala): la LLAMADA (las ratas salen de una grieta, acorazadas si las arma, con su tope), el ESCUDO DE
# CARNE, la FURIA DE REY (cargas, daño y sus ojos rojos), A MI ESPALDA (recula detras de una rata y le cede el turno), el
# FRENTE BLINDADO (por delante, no por la espalda) y el TAPAZO (empuja y aturde).
# Sin ventana:
#   godot --headless --path . res://tools/prueba_mut_rey_rata.tscn
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
	var ed: EnemyData = load("res://scenes/actors/enemy/rey_rata.tres")

	print("1) EL ARBOL")
	var c0: Combatant = ed.crear_combatant(0.5, false)
	var cc: Combatant = ed.crear_combatant(0.5, true, false, &"cloacas")
	var cd: Combatant = ed.crear_combatant(0.5, true, false, &"desguace")
	_ver(cc.nombre == "Rey de las cloacas" and cd.nombre == "Rey del desguace", "nombres (%s / %s)" % [cc.nombre, cd.nombre])
	_ver(ed.siguiente_mutacion(false, &"")["id"] == &"cloacas", "del rey sale el de las cloacas")
	_ver(ed.siguiente_mutacion(true, &"cloacas")["id"] == &"desguace", "y de el, el del desguace")

	print("2) LAS STATS (las seis, suma 170)")
	_ver(ed.voluntad == 20 and ed.fuerza + ed.resistencia + ed.destreza + ed.agilidad + ed.magia + ed.voluntad == 170,
		"el rey: 32/26/36/42/14/20 (estrena Voluntad)")
	for id in [&"cloacas", &"desguace"]:
		var p: Dictionary = ed.mutacion_de(id).pesos
		var suma: int = 0
		for k in p:
			suma += int(p[k])
		_ver(suma == 170 and p.size() == 6, "%s: reparto de las seis, suma %d" % [id, suma])
	_ver(cd.hab("resistencia") > cc.hab("resistencia") and cd.hab("agilidad") < cc.hab("agilidad"),
		"el desguace, mas duro y mas lento que el de las cloacas")

	print("3) LOS ATAQUES")
	print("    cloacas  %s" % [_nombres(cc)])
	print("    desguace %s" % [_nombres(cd)])
	_ver(_nombres(cc) == ["Dentellada real", "Chillido", "A la yugular"], "el de las cloacas: los de siempre")
	_ver(_nombres(cd) == ["Dentellada real", "Chillido", "A la yugular", "Tapazo"], "el del desguace: + Tapazo")
	var chi: AbilityData = cc.habilidades[1]
	_ver(chi.llama_camada, "el Chillido es el que llama a la camada")
	_ver(c0.llamada_max == 0, "(el rey normal no llama a nadie)")

	print("4) LAS PASIVAS")
	_ver(cc.llamada_min == 1 and cc.llamada_max == 2 and cc.llamada_tope == 4, "llamada: 1-2 ratas, tope 4")
	_ver(is_equal_approx(cc.escudo_carne_prob, 0.35) and is_equal_approx(cc.escudo_carne_frac, 0.5), "escudo de carne: 35 %, la mitad")
	_ver(is_equal_approx(cc.furia_por_muerte, 0.1) and cc.furia_max == 3 and cc.furia_turnos == 3, "furia: +10 %, hasta 3, 3 turnos")
	_ver(is_equal_approx(cc.espalda_vida, 0.3) and is_equal_approx(cc.espalda_prob, 0.5), "a mi espalda: <30 %, 50 %")
	_ver(cc.frente_blindado == 0.0 and not cc.camada_acorazada, "(el de las cloacas sin chatarra)")
	_ver(is_equal_approx(cd.frente_blindado, 0.4) and is_equal_approx(cd.frente_angulo, 120.0) and cd.camada_acorazada,
		"desguace: frente blindado 40 % en 120 grados y camada acorazada")

	print("5) LOS SPRITES")
	var sf0: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, false, &"")
	_ver(sf0 != null and sf0.has_animation(&"comer_0"), "el rey normal ya come")
	var anims := {&"cloacas": ["evolucion_0", "comer_3", "chillido_2", "yugular_1"],
		&"desguace": ["evolucion_0", "tapazo_2", "dentellada_4"]}
	for id in anims:
		var sf: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, id)
		var ok: bool = sf != null and SpritesEnemigo.mutante_propio(ed, id)
		for a in anims[id]:
			ok = ok and sf.has_animation(StringName(a))
		_ver(ok, "%s: su hoja propia %s" % [id, anims[id]])
	var acz: EnemyData = load("res://resources/enemigos_invocados/rata_chatarra.tres")
	var sfa: SpriteFrames = SpritesEnemigo.frames_de(acz, 0.5)
	_ver(sfa != null and sfa.has_animation(&"walk_1") and sfa == SpritesEnemigo.frames_de(acz, 0.9),
		"la rata acorazada: su hoja (dedal y placa), sin tinte de piso")

	await _pelea()
	print("FIN: %s" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)


func _pelea() -> void:
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_mut_rey_rata", Game.PISO_ARENA):
		_ver(false, "arranca la sala")
		return
	sala.poner("res://scenes/actors/enemy/rey_rata.tres", Vector2(90, 0), {})
	sala.poner("res://scenes/actors/enemy/rata.tres", Vector2(110, 90), {})
	await _esperar(25)
	var nodos: Array = get_tree().get_nodes_in_group("enemy")
	for n in nodos:
		if n.get("data") != null and (n.data as EnemyData).sprite_variante == &"rey":
			n.aplicar_mutacion(&"desguace", 0.0)
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
	var rey: Combatant = null
	var rata: Combatant = null
	for e in combat._enemies:
		if e.mutacion == &"desguace":
			rey = e
		elif e.familia == 2:
			rata = e
	_ver(rey != null and rata != null, "en la pelea, el Rey del desguace y una rata")
	if rey == null or rata == null:
		return
	var al: Array = combat._aliados_vivos()
	var yo: Combatant = al[0]
	for a in al:
		(a as Combatant).current_hp = (a as Combatant).max_hp
		(a as Combatant).invulnerable = false
	var ps: Vector2 = tm.pies_de(yo)
	_poner(tm, rey, ps + Vector2(90, 0))
	_poner(tm, rata, ps + Vector2(90, 120))

	print("6) LA LLAMADA")
	var antes: int = combat._enemies.size()
	seed(5)
	en._llamada(rey)
	var nuevas: Array = []
	for e in combat._enemies:
		if e != rey and e != rata and e.is_alive():
			nuevas.append(e)
	_ver(nuevas.size() >= 1 and nuevas.size() <= 2, "salen 1-2 ratas (%d)" % nuevas.size())
	var suelta: Combatant = RATA_DE(combat).crear_combatant(0.2, false, false, &"", combat.altas._piso())
	var ok_acz: bool = true
	for n in nuevas:
		ok_acz = ok_acz and n.nombre == "Rata acorazada" and absf(n.max_hp / suelta.max_hp - 1.5) < 0.01 \
			and is_equal_approx(n.mov_mult, 0.75) and is_equal_approx(n.velocidad_mult, 0.75)
	_ver(ok_acz, "acorazadas: rata acorazada, x1,5 de vida, un 25 % mas lentas (barra y mapa)")
	var de_grieta: int = 0
	for d in tm._deslices:
		if nuevas.has(d["c"]) and bool(d.get("cria", false)) and int(d["golpes"]) == 2:
			de_grieta += 1
	_ver(de_grieta == nuevas.size(), "cada una espera en la grieta para saltar (%d)" % de_grieta)
	await _esperar(4)
	if not nuevas.is_empty():
		tm._salir_de_grieta(nuevas[0], 9)
		if nuevas.size() > 1:
			tm._salir_de_grieta(nuevas[1], 9)
	var grietas: int = 0
	for n in tm._arena().get_children():
		if n.has_meta("grieta"):
			grietas += 1
	_ver(grietas == 1, "se abre UNA grieta junto al rey aunque salgan dos (%d)" % grietas)
	var hoyo_lejos: float = 0.0
	for n in tm._arena().get_children():
		if n.has_meta("grieta"):
			hoyo_lejos = (n as Node2D).position.distance_to(tm.pies_de(rey))
	_ver(hoyo_lejos < 45.0, "junto a el (%.0f px de sus pies)" % hoyo_lejos)
	var salto: bool = false
	for _i in 120:
		tm.tick(0.016)
		for n in nuevas:
			var cu: Node2D = tm.cuerpo_de(n)
			if cu != null and cu.visible:
				salto = true
		if salto:
			break
		await get_tree().process_frame
	_ver(salto, "y saltan fuera, a la vista")
	for _k in 6:
		en._llamada(rey)
	var suyas: int = 0
	for e in combat._enemies:
		if e != rey and e.is_alive() and e.familia == rey.familia:
			suyas += 1
	_ver(suyas <= 4, "nunca mas de 4 suyas vivas (%d)" % suyas)
	await _esperar(60)
	# (se quedan las dos primeras; las demas, fuera)
	for e in combat._enemies:
		if e != rey and e != rata and e.is_alive() and not nuevas.has(e):
			e.current_hp = 0.0
			combat._morir_enemigo(e)
	await _esperar(10)

	print("7) EL ESCUDO DE CARNE")
	_poner(tm, rata, tm.pies_de(rey) + Vector2(0, 30))
	for n in nuevas:
		_poner(tm, n, tm.pies_de(rey) + Vector2(0, 160))
	var prob: float = rey.escudo_carne_prob
	rey.escudo_carne_prob = 1.0
	var hp_r: float = rata.current_hp
	var queda: float = combat.escudo_carne(rey, 10.0, yo, CombatFX.Estilo.MELEE)
	_ver(is_equal_approx(queda, 5.0) and is_equal_approx(hp_r - rata.current_hp, 5.0),
		"una rata pegada se lleva la mitad (rey %.1f, rata -%.1f)" % [queda, hp_r - rata.current_hp])
	_poner(tm, rata, tm.pies_de(rey) + Vector2(0, 160))
	_ver(is_equal_approx(combat.escudo_carne(rey, 10.0, yo, CombatFX.Estilo.MELEE), 10.0), "(lejos no le cubre)")
	rey.escudo_carne_prob = 0.0
	_poner(tm, rata, tm.pies_de(rey) + Vector2(0, 30))
	_ver(is_equal_approx(combat.escudo_carne(rey, 10.0, yo, CombatFX.Estilo.MELEE), 10.0), "(y sin la suerte, tampoco)")
	rey.escudo_carne_prob = prob

	print("8) LA FURIA DE REY")
	var muerta: Combatant = RATA_DE(combat).crear_combatant(0.2, false, false, &"", combat.altas._piso())
	muerta.familia = rey.familia
	_ver(rey.has_status(StatusEffects.Id.FURIA_REY), "(ya se enfurecio al caer las ratas de mas)")
	rey.statuses.clear()
	var atk0: float = rey.status_atk_mult()
	combat._furia_rey(muerta)
	var f1 = rey.get_status(StatusEffects.Id.FURIA_REY)
	_ver(f1 != null and f1.stacks == 1 and f1.turns == 3, "cae una rata: una carga, 3 turnos")
	_ver(absf(rey.status_atk_mult() / atk0 - 1.1) < 0.001, "pega un 10 %% mas (x%.2f)" % (rey.status_atk_mult() / atk0))
	for _k in 4:
		combat._furia_rey(muerta)
	var f3 = rey.get_status(StatusEffects.Id.FURIA_REY)
	_ver(f3 != null and f3.stacks == 3, "hasta 3 cargas (%d)" % (f3.stacks if f3 != null else 0))
	_ver(absf(rey.status_atk_mult() / atk0 - 1.3) < 0.001, "+30 %% (x%.2f)" % (rey.status_atk_mult() / atk0))
	tm._furias_visibles(false)
	var furia_fx: ReyRataAire = tm._furias.get(tm.cuerpo_de(rey))
	_ver(furia_fx != null and furia_fx.nivel == 3, "se le ve: ojos rojos y vaho, a nivel 3")
	var rey_muerto: Combatant = ed_rey().crear_combatant(0.5, true, false, &"cloacas")
	var n_st: int = rata.statuses.size()
	combat._furia_rey(rey_muerto)
	_ver(rata.statuses.size() == n_st, "(si cae otro rey, las ratas no se enfurecen)")
	rey.statuses.clear()
	tm._furias_visibles(false)
	_ver(tm._furias.is_empty(), "y se le va con el estado")

	print("9) A MI ESPALDA")
	_poner(tm, rey, ps + Vector2(90, 0))
	_poner(tm, rata, ps + Vector2(60, 0))
	await _esperar(2)
	rey.current_hp = rey.max_hp * 0.5
	_ver(en.rata_para_recular(rey) == null, "(con media vida, no se esconde)")
	rey.current_hp = rey.max_hp * 0.2
	var esp: float = rey.espalda_prob
	rey.espalda_prob = 1.0
	_ver(tm._recular(rey), "con poca vida, se esconde")
	var hasta: Vector2 = tm.pos_de(rey)
	for d in tm._deslices:
		if d["c"] == rey and int(d["modo"]) == tm.Desliz.YA:
			hasta = d["hasta"]
	var pies_hasta: Vector2 = hasta + tm._bajo_de(rey)
	_ver(pies_hasta.distance_to(ps) > tm.pies_de(rata).distance_to(ps), "recula detras de la rata (mas lejos de ti)")
	combat._gauge[rata] = 0.0
	_ver(en._a_mi_espalda(rey) and is_equal_approx(combat._gauge[rata], combat.UMBRAL), "y le cede el turno: la rata actua ya")
	_ver(tm.cede_de(rey) == null, "(solo ese turno)")
	rey.espalda_prob = esp
	rey.current_hp = rey.max_hp
	await _esperar(40)

	print("10) EL FRENTE BLINDADO")
	rata.current_hp = 0.0
	combat._morir_enemigo(rata)
	for n in nuevas:
		if n.is_alive():
			n.current_hp = 0.0
			combat._morir_enemigo(n)
	_poner(tm, rey, ps + Vector2(30, 0))
	var cu_rey: Node2D = tm.cuerpo_de(rey)
	cu_rey.set("_facing", Vector2.LEFT)   # mirandote
	_ver(is_equal_approx(combat._mult_pasivas(yo, rey), 0.6), "de frente, la chatarra se come el 40 %% (x%.2f)"
		% combat._mult_pasivas(yo, rey))
	cu_rey.set("_facing", Vector2.RIGHT)   # de espaldas
	_ver(is_equal_approx(combat._mult_pasivas(yo, rey), 1.0), "por la espalda, entero")
	cu_rey.set("_facing", Vector2(0.0, 1.0))   # de lado (90 grados): fuera de su cono de 120
	_ver(is_equal_approx(combat._mult_pasivas(yo, rey), 1.0), "por el costado, entero (su cono es de 120 grados)")
	cu_rey.set("_facing", Vector2.LEFT)
	var n_ch: int = 0
	tm._chispas_si_para({"bv": combat._bloque_de(rey), "ba": combat._bloque_de(yo), "dmg": 5.0,
		"elem": Elementos.Elemento.NINGUNO})
	for n in tm._arena().get_children():
		if n.get_meta("golpe_rey", -1) == ReyRataAire.Modo.CHISPAS:
			n_ch += 1
	_ver(n_ch == 1, "y saltan chispas de la tapa")
	var ev_n := {"bv": combat._bloque_de(rey), "ba": combat._bloque_de(yo), "dmg": 5.0, "elem": Elementos.Elemento.NINGUNO}
	_ver(tm.color_numero(ev_n) == tm.GRIS_BLINDADO, "y su numero sale en gris")
	cu_rey.set("_facing", Vector2.RIGHT)
	_ver(tm.color_numero(ev_n).a == 0.0, "(por la espalda, del color de siempre)")
	cu_rey.set("_facing", Vector2.LEFT)

	print("11) EL TAPAZO")
	_poner(tm, rey, ps + Vector2(26, 0))
	cu_rey.set("_facing", Vector2.LEFT)
	await _esperar(2)
	var hp_y: float = yo.current_hp
	yo.evasion_bonus = -5.0
	var res0: float = yo.status_resist
	yo.status_resist = 0.0   # (el de la prueba resiste estados: que entre seguro)
	rey.eficacia = 99.0
	en._enemy_use_ability(rey, _segura("rey_rata_tapazo"), yo)
	yo.evasion_bonus = 0.0
	yo.status_resist = res0
	_ver(yo.current_hp < hp_y, "pega (%.1f -> %.1f)" % [hp_y, yo.current_hp])
	_ver(yo.aturdido(), "y aturde (con el 50 % seguro)")
	var empuja: bool = false
	for tr in tm._tirones:
		if tr["c"] == yo and tr["de"] == rey and is_equal_approx(float(tr["px"]), -40.0):
			empuja = true
	_ver(empuja, "y te manda 40 px para atras")


func RATA_DE(combat) -> EnemyData:
	return combat.enemigos.RATA_CAMADA


func ed_rey() -> EnemyData:
	return load("res://scenes/actors/enemy/rey_rata.tres")


# Una habilidad suya con los efectos SEGUROS (para mirar que entran).
func _segura(nombre: String) -> AbilityData:
	var ab: AbilityData = _ab(nombre).duplicate(true)
	for a in ab.efectos:
		a.prob = 1.0
	return ab


func _ab(nombre: String) -> AbilityData:
	return load("res://resources/abilities/%s.tres" % nombre) as AbilityData
