# LA ABERRACION Y SUS MUTANTES (13/11, memoria aberracion-mutante), sin ventana:
#   1) la ficha: la base con Voluntad (sigue sumando 170) y su kit fisico de siempre
#   2) el arbol: Masa galvanica (1a) --come mas--> Ojo de la tormenta (2a); stats que suman 170
#   3) los kits: numeros, magicos y elementos ESCRITOS, sus estados; el basico del Ojo, magico de Rayo
#   4) lo que trae cada una al crearse: conductora y Carne que se cierra (Masa); vuela, inmune al Aturdido, sin
#      regeneracion y Tentaculos que cuelgan (Ojo)
#   5) en una pelea de verdad: los Tentaculos que cuelgan (al pegado si, al lejano no, con su linea en el registro), la
#      pasiva conductora, el Aturdido que no le entra y la carga de El ojo se abre cortada con Miedo y moviendola
#   8) el set JAULA DE FARADAY: 2p Ataque magico (el nombre nuevo del atributo), su texto, la runa y el glifo; en la pelea,
#      el escudo al lanzar (200 % del coste base, se queda el mayor), para golpes y no el daño con el tiempo, y sin lo
#      propio de la Marea (ni para el Lento ni moja al romperse)
#   godot --headless --path . res://tools/prueba_mut_aberracion.tscn
extends Node

const ABERRACION := "res://scenes/actors/enemy/aberracion.tres"
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


func _log(combat: Node) -> String:
	return "\n".join(combat.log_entero().map(func(l): return str(l)))


func _poner(tm, c: Combatant, p: Vector2) -> void:
	var cu: Node2D = tm.cuerpo_de(c)
	cu.global_position += p - tm.pies_de(c)
	tm._pos[c] = cu.global_position


func _ab(nombre: String) -> AbilityData:
	return load("res://resources/abilities/%s.tres" % nombre)


func _correr() -> void:
	print("1) LA FICHA")
	var ab_ed: EnemyData = load(ABERRACION)
	_ver([ab_ed.resistencia, ab_ed.fuerza, ab_ed.destreza, ab_ed.agilidad, ab_ed.magia, ab_ed.voluntad] == [38, 50, 22, 24, 18, 18],
		"base: 38/50/22/24/18/18 (con Voluntad, suma 170)")
	_ver(ab_ed.habilidades.map(func(a): return a.nombre) == ["Alarido demente", "Latigazo de tentáculo", "Mirada del vacío"]
		and not _ab("aberracion_latigazo").es_magico and not _ab("aberracion_mirada").es_magico, "su kit de siempre, fisico")
	_ver(is_equal_approx(ab_ed.regen_turno, 0.08) and ab_ed.regen_corta_elem == Elementos.Elemento.LUZ, "Carne que se cierra igual")

	print("2) EL ARBOL")
	var gal: MutacionData = ab_ed.mutacion_de(&"galvanica")
	var tor: MutacionData = ab_ed.mutacion_de(&"tormenta")
	_ver(gal != null and gal.grado == 1 and gal.nombre == "Masa galvánica", "aberracion -> Masa galvanica (1a)")
	_ver(tor != null and tor.grado == 2 and tor.nombre == "Ojo de la tormenta" and tor.desde == [&"galvanica"],
		"Masa galvanica -> Ojo de la tormenta (2a)")
	if gal == null or tor == null:
		return
	_ver(ab_ed.siguiente_mutacion(true, &"galvanica").get("id") == &"tormenta", "comiendo: de la Masa al Ojo")
	for par in [[gal, [36, 36, 16, 22, 32, 28]], [tor, [28, 10, 12, 26, 50, 44]]]:
		var m: MutacionData = par[0]
		var v: Array = ["resistencia", "fuerza", "destreza", "agilidad", "magia", "voluntad"].map(func(k): return int(m.pesos[k]))
		var suma: int = 0
		for x in v:
			suma += int(x)
		_ver(v == par[1] and suma == 170, "%s: %s, suma %d" % [m.nombre, str(v), suma])

	print("3) LOS KITS")
	var esperado := {
		"aberracion_latigazo_galvanico": [1.40, [[StatusEffects.Id.RAYO, 0.4]]],
		"aberracion_descarga": [0.55, [[StatusEffects.Id.PARALISIS, 0.3]]],
		"aberracion_mirada_chispeante": [0.60, [[StatusEffects.Id.RAYO, 0.6], [StatusEffects.Id.MIEDO, 0.3]]],
		"aberracion_tormenta_basico": [1.00, []],
		"aberracion_rayo_del_ojo": [1.30, [[StatusEffects.Id.RAYO, 0.6]]],
		"aberracion_ojo_se_abre": [2.00, [[StatusEffects.Id.PARALISIS, 0.5]]],
	}
	for k in esperado:
		var ab: AbilityData = _ab(k)
		var e: Array = esperado[k]
		var est: Array = ab.efectos.map(func(s): return [s.estado, snappedf(s.prob, 0.01)])
		var quiero: Array = (e[1] as Array).map(func(p): return [p[0], snappedf(float(p[1]), 0.01)])
		_ver(ab.es_magico and is_equal_approx(ab.dano_mult, float(e[0])) and ab.elemento_golpe == Elementos.Elemento.RAYO
			and est == quiero, "%s: %.2f magico de Rayo, estados %s" % [ab.nombre, float(e[0]), str(est)])
	_ver(gal.habilidades.map(func(a): return a.resource_path.get_file().get_basename())
		== ["aberracion_latigazo_galvanico", "aberracion_descarga", "aberracion_mirada_chispeante"], "el kit de la Masa")
	_ver(tor.habilidades.map(func(a): return a.resource_path.get_file().get_basename())
		== ["aberracion_rayo_del_ojo", "aberracion_ojo_se_abre"] and tor.basico_propio == _ab("aberracion_tormenta_basico"),
		"el kit del Ojo y su basico (Chispazo)")
	var lat: AbilityData = _ab("aberracion_latigazo_galvanico")
	_ver(lat.golpes_min == 2 and lat.golpes_max == 3 and lat.forma_reparte and is_equal_approx(lat.forma_radio, 90.0),
		"Latigazo galvanico: 2-3 golpes repartidos hasta 90")
	var des: AbilityData = _ab("aberracion_descarga")
	_ver(des.forma == CombatFormas.Tipo.CIRCULO and des.forma_apunte == CombatFormas.Apunte.ALREDEDOR
		and is_equal_approx(des.forma_radio, 70.0), "Descarga: circulo de 70 alrededor")
	var mir: AbilityData = _ab("aberracion_mirada_chispeante")
	_ver(mir.forma == CombatFormas.Tipo.CONO and is_equal_approx(mir.forma_radio, 120.0) and is_equal_approx(mir.forma_apertura, 30.0),
		"Mirada chispeante: cono de 120 y 30 grados")
	var ray: AbilityData = _ab("aberracion_rayo_del_ojo")
	_ver(ray.forma == CombatFormas.Tipo.LINEA and is_equal_approx(ray.forma_radio, 130.0) and is_equal_approx(ray.forma_ancho, 30.0),
		"Rayo del ojo: linea gorda de 130 x 30")
	var ojo: AbilityData = _ab("aberracion_ojo_se_abre")
	_ver(ojo.carga_turnos == 1 and ojo.forma_apunte == CombatFormas.Apunte.ALREDEDOR and is_equal_approx(ojo.forma_radio, 70.0),
		"El ojo se abre: carga 1 turno, circulo de 70")

	print("3b) LOS SPRITES")
	_ver(SpritesEnemigo.mutante_propio(ab_ed, &"galvanica"), "la Masa galvanica tiene sprite propio")
	var sf_g: SpriteFrames = SpritesEnemigo.frames_de(ab_ed, 0.5, true, &"galvanica")
	var faltan_g: Array = ["idle_0", "walk_0", "embestida_0", "basico_0", "alarido_0", "mirada_0", "encaje_0", "muerte_0",
		"cadaver_0"].filter(func(an): return sf_g == null or not sf_g.has_animation(StringName(an)))
	_ver(faltan_g.is_empty(), "con todas sus anims%s" % ("" if faltan_g.is_empty() else " (faltan %s)" % faltan_g))
	var sf_b: SpriteFrames = SpritesEnemigo.frames_de(ab_ed, 0.5)
	if sf_g != null and sf_b != null:
		var at_g = sf_g.get_frame_texture(&"idle_0", 0).get("atlas")
		var at_b = sf_b.get_frame_texture(&"idle_0", 0).get("atlas")
		_ver(at_g != null and at_g != at_b and at_g.resource_path.contains("galvanica"),
			"y se ve con SU dibujo (%s)" % (at_g.resource_path if at_g != null else "?"))

	_ver(SpritesEnemigo.mutante_propio(ab_ed, &"tormenta"), "el Ojo de la tormenta tiene sprite propio")
	var sf_t: SpriteFrames = SpritesEnemigo.frames_de(ab_ed, 0.5, true, &"tormenta")
	var faltan_t: Array = ["idle_0", "walk_0", "basico_0", "embestida_0", "rayo_0", "ojo_carga_0", "ojo_0", "tentaculos_0",
		"encaje_0", "muerte_0", "cadaver_0", "evolucion_0"].filter(func(an): return sf_t == null or not sf_t.has_animation(StringName(an)))
	_ver(faltan_t.is_empty(), "con sus anims nuevas%s" % ("" if faltan_t.is_empty() else " (faltan %s)" % faltan_t))
	if sf_t != null:
		_ver(sf_t.get_frame_count(&"muerte_0") == 12 and sf_t.get_frame_count(&"evolucion_0") == 20 and sf_t.get_frame_count(&"rayo_0") == 10,
			"muerte 12, evolucion 20 y rayo 10 fotogramas")
	_ver(_ab("aberracion_rayo_del_ojo").fx_anim == &"rayo" and _ab("aberracion_ojo_se_abre").fx_anim_carga == &"ojo_carga"
		and _ab("aberracion_ojo_se_abre").fx_anim == &"ojo", "sus habilidades piden sus gestos (rayo, ojo_carga, ojo)")
	_ver((load("res://scripts/ui/combat_espejo.gd").ANIMS_SUELTAS as Array).has(&"tentaculos"),
		"el gesto de los tentaculos viaja por la red")

	print("4) AL CREARSE")
	var c_gal: Combatant = ab_ed.crear_combatant(0.5, true, false, &"galvanica")
	var c_tor: Combatant = ab_ed.crear_combatant(0.5, true, false, &"tormenta")
	var c_base: Combatant = ab_ed.crear_combatant(0.5, false)
	_ver(c_gal.al_ser_golpeado.size() == 1 and c_gal.al_ser_golpeado[0].estado == StatusEffects.Id.RAYO
		and is_equal_approx(c_gal.al_ser_golpeado_prob, 0.3), "Masa: pasiva conductora (Electrizado al 30 %)")
	_ver(is_equal_approx(c_gal.regen_turno, 0.08) and not c_gal.vuela and c_gal.tentaculos_hueco == 0.0,
		"Masa: con Carne que se cierra, no vuela, sin tentaculos colgando")
	_ver(c_tor.vuela and c_tor.en_el_aire() and c_tor.inmune_estados.has(StatusEffects.Id.ATURDIDO) and c_tor.regen_turno == 0.0,
		"Ojo: vuela, inmune al Aturdido y sin regeneracion")
	_ver(is_equal_approx(c_tor.tentaculos_hueco, 30.0) and is_equal_approx(c_tor.tentaculos_mult, 0.35)
		and c_tor.tentaculos_elem == Elementos.Elemento.RAYO, "Ojo: Tentaculos que cuelgan (30, 0,35, Rayo)")
	_ver(not c_base.inmune_estados.has(StatusEffects.Id.ATURDIDO) and (ab_ed.inmune_estados as Array).is_empty(),
		"la inmunidad del Ojo no se le pega a la ficha de la base")
	c_tor.apply_status(StatusEffects.Id.ATURDIDO)
	c_tor.apply_status(StatusEffects.Id.MIEDO, 2, 1.0)
	_ver(not c_tor.has_status(StatusEffects.Id.ATURDIDO), "al Ojo no le entra el Aturdido")

	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_mut_aberracion", Game.PISO_ARENA):
		_ver(false, "arranca la sala")
		return
	sala.poner(ABERRACION, Vector2(150, 0), {"mutacion": "galvanica"})
	sala.poner(ABERRACION, Vector2(150, 170), {"mutacion": "tormenta"})
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
	_ver(por_mut.has(&"galvanica") and por_mut.has(&"tormenta"), "en la pelea: las dos (%s)" % str(por_mut.keys()))
	if not (por_mut.has(&"galvanica") and por_mut.has(&"tormenta")):
		return
	var gm: Combatant = por_mut[&"galvanica"]
	var oj: Combatant = por_mut[&"tormenta"]
	_ver(oj.nombre.contains("Ojo de la tormenta") and gm.nombre.contains("Masa galvánica"), "con sus nombres (%s / %s)" % [gm.nombre, oj.nombre])
	var yo: Combatant = combat._aliados[0]
	yo.max_hp = 100000.0
	yo.current_hp = 100000.0
	var otro: Combatant = combat._aliados[1] if combat._aliados.size() > 1 else null

	print("5) TENTACULOS QUE CUELGAN")
	# Lejos de la Masa (que no se meta): el Ojo en un sitio, yo pegado a el y el otro lejos.
	var po: Vector2 = t.pies_de(oj)
	_poner(t, gm, po + Vector2(300, -200))
	_poner(t, yo, po + Vector2(-8, 4))
	if otro != null:
		otro.max_hp = 100000.0
		otro.current_hp = 100000.0
		_poner(t, otro, po + Vector2(-200, 120))
	for al in combat._aliados.slice(2):
		_poner(t, al, po + Vector2(-400, 250))
	await _esperar(3)
	print("     hueco yo-Ojo %.1f, otro-Ojo %.1f" % [t.hueco_entre(yo, oj), t.hueco_entre(otro, oj) if otro != null else -1.0])
	var vida_yo: float = yo.current_hp
	var vida_otro: float = otro.current_hp if otro != null else 0.0
	var tiradas: int = 0
	while is_equal_approx(yo.current_hp, vida_yo) and tiradas < 8:   # (la esquiva magica, si la hay, no siempre)
		combat.enemigos._tentaculos_que_cuelgan(oj)
		tiradas += 1
	_ver(yo.current_hp < vida_yo, "al pegado le azotan (%.1f de daño en %d tiradas)" % [vida_yo - yo.current_hp, tiradas])
	if otro != null:
		_ver(is_equal_approx(otro.current_hp, vida_otro), "al que esta lejos, nada")
	_ver(_log(combat).contains("Los tentáculos de") and _log(combat).contains("de daño a %s" % yo.nombre), "su linea en el registro")
	var vida_m: float = yo.current_hp
	combat.enemigos._tentaculos_que_cuelgan(gm)
	_ver(is_equal_approx(yo.current_hp, vida_m), "la Masa no los tiene")
	# El daño: magico de Rayo 0,35 del de un golpe magico suyo (aprox., sin variacion).
	var r: Dictionary = StatsMath.resolve_magico_enemigo(oj, yo, true)
	print("     un golpe magico suyo: %.1f -> tentaculos %.1f" % [float(r.get("damage", 0.0)), float(r.get("damage", 0.0)) * 0.35])

	print("6) LA PASIVA CONDUCTORA")
	_poner(t, gm, t.pies_de(yo) + Vector2(10, 0))
	await _esperar(3)
	yo.statuses = yo.statuses.filter(func(s): return s.id() != StatusEffects.Id.RAYO)
	var gm_prob: float = gm.al_ser_golpeado_prob
	gm.al_ser_golpeado_prob = 1.0
	yo.status_resist = 0.0
	# (La probabilidad del estado se divide por la resistencia a estados de quien lo recibe -su equipo y sus stats, no solo
	# status_resist-: no es segura aunque la pasiva salte siempre. Varias tiradas, como los tentaculos.)
	var tiradas_c: int = 0
	while not yo.has_status(StatusEffects.Id.RAYO) and tiradas_c < 10:
		combat._pasiva_hecha.clear()
		combat._pasiva_al_golpearle(gm, yo, 10.0)
		tiradas_c += 1
	gm.al_ser_golpeado_prob = gm_prob
	_ver(yo.has_status(StatusEffects.Id.RAYO), "pegarle de cerca: Electrizado (%d tiradas)" % tiradas_c)
	_ver(_log(combat).contains("suelta una descarga sobre"), "y lo dice el registro")

	print("7) INMUNE AL ATURDIDO: LA CARGA SE CORTA CON OTRAS COSAS")
	oj.apply_status(StatusEffects.Id.ATURDIDO)
	_ver(not oj.has_status(StatusEffects.Id.ATURDIDO), "en la pelea tampoco le entra el Aturdido")
	combat.enemigos._enemy_begin_charge(oj, ojo, yo)
	_ver(oj.charging == ojo, "empieza a cargar El ojo se abre")
	oj.status_resist = 0.0
	oj.apply_status(StatusEffects.Id.MIEDO, 2, 1.0)
	combat._cortar_por_control()
	_ver(oj.charging == null, "el Miedo se la corta")
	oj.statuses = oj.statuses.filter(func(s): return s.id() != StatusEffects.Id.MIEDO)
	combat.enemigos._enemy_begin_charge(oj, ojo, yo)
	var linea: String = combat.desplazado(oj, 40.0, yo)
	_ver(oj.charging == null and linea != "", "moverla 40 se la corta (%s)" % linea)

	print("8) EL SET JAULA DE FARADAY")
	var set_j: RunaSetData = null
	for sd in Runas.sets():
		if (sd as RunaSetData).id == &"aberracion":
			set_j = sd
	_ver(set_j != null and set_j.nombre == "Jaula de Faraday" and set_j.tipo == RunaSetData.Tipo.ARMADURA,
		"el set existe y es de armadura")
	if set_j == null:
		return
	var desc: String = Runas.descripcion_set(set_j)
	print("     texto: %s" % desc.replace("
", " | "))
	_ver(desc.contains("Ataque mágico +10 %") and desc.contains("200 %") and desc.contains("coste de maná base")
		and desc.contains("se queda con el mayor") and desc.contains("no absorbe el daño con el tiempo"), "su texto, con los numeros")
	_ver(Runas.nombre_sub("dano_magico_pct") == "Ataque mágico", "el atributo se llama Ataque magico")
	_ver(set_j.runa != null and set_j.runa.id == &"runa_aberracion" and ab_ed.drop_runa == set_j.runa, "la runa, la suelta la aberracion")
	_ver(CeldaObjeto.GLIFO_SET.has(&"aberracion") and CeldaObjeto.tonos_glifo(&"aberracion", Color.RED)["#"] == Color8(110, 235, 255),
		"el glifo de la burbuja con nervios, con sus tonos")
	var sp_8: SpellData = null
	var sp_alto: SpellData = null
	for f in DirAccess.get_files_at("res://resources/spells"):
		if not f.ends_with(".tres"):
			continue
		var sp: SpellData = load("res://resources/spells/" + f) as SpellData
		if sp == null:
			continue
		if sp_8 == null or sp.coste_mana < sp_8.coste_mana:
			sp_8 = sp
		if sp_alto == null or sp.coste_mana > sp_alto.coste_mana:
			sp_alto = sp
	yo.runa_jaula = 2.0
	yo.runa_marea = 0.0
	yo.runa_escudo_agua = 0.0
	yo.runa_escudo_max = 0.0
	var e1: float = combat.magia.jaula_faraday(yo, sp_alto)
	_ver(is_equal_approx(e1, sp_alto.coste_mana * 2.0) and is_equal_approx(yo.runa_escudo_agua, e1),
		"lanzar %s (coste %d): escudo de %.0f" % [sp_alto.nombre, sp_alto.coste_mana, e1])
	_ver(yo.escudo_es_jaula() and _log(combat).contains("se cubre con la Jaula de Faraday"), "es el de la Jaula, y lo dice el registro")
	var e2: float = combat.magia.jaula_faraday(yo, sp_8)
	_ver(e2 == 0.0 and is_equal_approx(yo.runa_escudo_agua, e1), "uno mas barato (%s) no lo cambia: se queda el mayor" % sp_8.nombre)
	var vida_j: float = yo.current_hp
	yo.take_damage(5.0, true)
	_ver(is_equal_approx(yo.runa_escudo_agua, e1) and is_equal_approx(yo.current_hp, vida_j - 5.0),
		"el daño con el tiempo pasa por debajo")
	yo.take_damage(e1 * 0.5)
	_ver(is_equal_approx(yo.runa_escudo_agua, e1 * 0.5) and is_equal_approx(yo.current_hp, vida_j - 5.0), "un golpe se lo come el escudo")
	var e3: float = combat.magia.jaula_faraday(yo, sp_8)
	_ver(is_equal_approx(e3, sp_8.coste_mana * 2.0) == (sp_8.coste_mana * 2.0 > e1 * 0.5), "ya gastado, uno nuevo mayor si lo cambia")
	yo.status_resist = 0.0
	yo.apply_status(StatusEffects.Id.LENTO, 2, 1.0)
	_ver(yo.has_status(StatusEffects.Id.LENTO), "no para el Lento (eso es de la Marea)")
	yo.take_damage(yo.runa_escudo_agua + 1.0)
	_ver(yo.runa_escudo_agua <= 0.0 and not yo.runa_agua_rota, "al romperse no moja a nadie")
	# La burbuja, violeta y con nervios.
	combat.magia.jaula_faraday(yo, sp_alto)
	t.pintar_escudos_agua()
	await _esperar(5)
	var burbuja: EscudoAgua = EscudoAgua.de(t.cuerpo_de(yo))
	_ver(burbuja != null and burbuja._jaula and burbuja._agua == EscudoAgua.JAULA, "su burbuja: la de la Jaula (violeta)")
	await _esperar(20)
	_ver(burbuja != null and not burbuja._nervios.is_empty(), "con sus nervios (%d)" % (burbuja._nervios.size() if burbuja != null else 0))

	print("9) LOS EFECTOS EN PIXEL")
	var datos: Dictionary = (load("res://scripts/fx/efectos_pixel_datos.gd").HOJAS as Dictionary).get("aberracion", {})
	var faltan_e: Array = ["latigo_golpe", "chispas", "vibra", "mirada_ojo", "cono_mirada", "cono_chispas", "alarido",
		"descarga", "aro_carga", "aro_estalla", "carne", "grietas"].filter(func(h): return not datos.has(h))
	_ver(faltan_e.is_empty(), "las %d hojas de la aberracion estan horneadas%s" % [datos.size(), "" if faltan_e.is_empty() else " (faltan %s)" % faltan_e])
	var arena: Node = t._arena()
	var f_c := CombatFormas.Forma.new()
	f_c.centro = t.pies_de(oj)
	f_c.radio = 70.0
	f_c.dir = Vector2.RIGHT
	for par_s in [[SueloRoto.Tipo.FIERA_ALARIDO, "el Alarido"], [SueloRoto.Tipo.ABERRACION_DESCARGA, "la Descarga"],
			[SueloRoto.Tipo.ABERRACION_ARO, "el estallido del aro"]]:
		_ver(SueloRoto.lanzar(arena, f_c, int(par_s[0]), 7) is EfectoPixel, "%s, en pixel" % par_s[1])
	_ver(SueloRoto.lanzar(arena, f_c, SueloRoto.Tipo.FIERA_CONO, 7) == null, "el cono de la Mirada no lo pinta el suelo (su gesto)")
	_ver(_ab("aberracion_descarga").suelo_roto == SueloRoto.Tipo.ABERRACION_DESCARGA
		and _ab("aberracion_ojo_se_abre").suelo_roto == SueloRoto.Tipo.ABERRACION_ARO
		and _ab("aberracion_tormenta_basico").fx_estilo_mapa == CombatFX.Estilo.ABERRACION_CHISPAZO
		and _ab("aberracion_rayo_del_ojo").fx_estilo_mapa == CombatFX.Estilo.ABERRACION_RAYO, "cada habilidad con su efecto")
	var cuenta := func(clase: String) -> int: return arena.find_children("*", clase, true, false).size()
	# EL LATIGAZO sale del tentaculo de su sprite (no del centro)
	var desde_t: Vector2 = Aberracion3DSprites.punta(t.cuerpo_de(gm), Vector2.INF, &"galvanica")
	_ver(desde_t != Vector2.INF and desde_t.distance_to(t.bulto_de(gm).get_center()) > 4.0,
		"el latigazo sale de su tentaculo (%s, centro %s)" % [str(desde_t), str(t.bulto_de(gm).get_center())])
	var c0: int = cuenta.call("CintaPixel")
	var e0: int = cuenta.call("EfectoPixel")
	t._aberracion_pixel(arena, CombatFX.Estilo.FIERA_TENTACULO, gm, yo, 0.1, 1.0)
	_ver(cuenta.call("CintaPixel") > c0 and cuenta.call("EfectoPixel") >= e0 + 2, "Latigazo galvanico: tentaculo, golpe y chispas")
	var r0: int = cuenta.call("RayoPixel")
	for est in [CombatFX.Estilo.ABERRACION_CHISPAZO, CombatFX.Estilo.ABERRACION_CUELGAN]:
		t._aberracion_pixel(arena, est, oj, yo, 0.1, 1.0)
	t._aberracion_pixel(arena, CombatFX.Estilo.ABERRACION_CONDUCTORA, gm, yo, 0.1, 1.0)
	_ver(cuenta.call("RayoPixel") >= r0 + 3, "Chispazo, Tentaculos y conductora: sus rayos (%d -> %d)" % [r0, cuenta.call("RayoPixel")])
	var e9: int = cuenta.call("EfectoPixel")
	t._pixel.al_gesto(oj, t.cuerpo_de(oj), "rayo", 0.8)
	_ver(cuenta.call("RayoPixel") >= r0 + 4, "el Rayo del ojo: el zigzag gordo")
	t._pixel.al_gesto(gm, t.cuerpo_de(gm), "mirada", 0.8)
	t._pixel.al_gesto(oj, t.cuerpo_de(oj), "ojo_carga", 0.8)
	_ver(cuenta.call("EfectoPixel") >= e9 + 2, "la Mirada chispeante (cono) y el aro de la carga")
	t._pixel.al_gesto(oj, t.cuerpo_de(oj), "ojo", 0.8)
