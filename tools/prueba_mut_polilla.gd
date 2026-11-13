# LA POLILLA Y SUS MUTANTES (12/11, memoria polilla-mutante), sin ventana:
#   1) las fichas: el pavon con Voluntad y Nube/Aleteo magicos; la Polilla de luto (dibujo D, mas fuerte); los spawns
#   2) el arbol: Vigilia dorada (del pavon), Mortaja alada (de la de luto) y la Polilla insomne (de las dos, compartida)
#   3) los kits: numeros, magicos y elementos ESCRITOS; el basico de la Insomne magico sin elemento
#   4) los sprites: la carpeta D para la de luto, las tres mutantes con sus animaciones y las DOS evoluciones de la Insomne
#   5) la PASIVA QUE SE VE: Ojos en vela como buff permanente que no se gasta, no se disipa y no sale de la pelea; su
#      texto sale del dato; su rotulo al entrarle magia
#   6) el set CONCENTRACION: el texto, las cargas por frase (tope), fallar las quita, no sale de la pelea
#   7) en una pelea de verdad: las tres mutantes con sus pasivas (Insomnio atrae, resiste magia, reflejo)
#   godot --headless --path . res://tools/prueba_mut_polilla.tscn
extends Node

const PAVON := "res://scenes/actors/enemy/polilla.tres"
const LUTO := "res://scenes/actors/enemy/polilla_luto.tres"
const CombatReacciones = preload("res://scripts/ui/combat_reacciones.gd")
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
	print("1) LAS FICHAS")
	var pav: EnemyData = load(PAVON)
	var luto: EnemyData = load(LUTO)
	_ver([pav.resistencia, pav.fuerza, pav.destreza, pav.agilidad, pav.magia, pav.voluntad] == [22, 24, 30, 42, 28, 24],
		"pavon: 22/24/30/42/28/24 (con Voluntad)")
	var nube: AbilityData = _ab("polilla_nube")
	var aleteo: AbilityData = _ab("polilla_aleteo")
	_ver(nube.es_magico and aleteo.es_magico and is_equal_approx(nube.dano_mult, 0.42) and is_equal_approx(aleteo.dano_mult, 0.73),
		"Nube 0,42 y Aleteo 0,73, magicos")
	_ver(luto.enemy_name == "Polilla de luto" and luto.sprite_variante == &"luto" and is_equal_approx(luto.base_hp, 66.0)
		and is_equal_approx(luto.base_attack, pav.base_attack * 1.1), "Polilla de luto: dibujo D, vida 66, ataque +10 %")
	_ver(luto.habilidades.map(func(a): return a.nombre) == pav.habilidades.map(func(a): return a.nombre),
		"la de luto, con el mismo kit que el pavon")
	var simas: SpawnTable = load("res://resources/spawns/simas.tres")
	var pisos: Dictionary = {}
	for en in simas.entradas:
		pisos[en.enemy_data.enemy_name] = [en.piso_min, en.piso_max]
	_ver(pisos.get("Polilla de esporas", []) == [9, 11] and pisos.get("Polilla de luto", []) == [11, 12],
		"spawns: pavon 9-11, de luto 11-12 (%s)" % str(pisos))
	_ver(Game.rutas_enemigos().has(LUTO) if Game.has_method("rutas_enemigos") else true, "la de luto, en la lista de enemigos")

	print("2) EL ARBOL")
	var vig: MutacionData = pav.mutacion_de(&"vigilia")
	var mor: MutacionData = luto.mutacion_de(&"mortaja")
	var ins_p: MutacionData = pav.mutacion_de(&"insomne")
	var ins_l: MutacionData = luto.mutacion_de(&"insomne")
	_ver(vig != null and vig.grado == 1 and vig.nombre == "Vigilia dorada", "pavon -> Vigilia dorada (1a)")
	_ver(mor != null and mor.grado == 1 and mor.nombre == "Mortaja alada", "de luto -> Mortaja alada (1a)")
	_ver(pav.mutacion_de(&"mortaja") == null and luto.mutacion_de(&"vigilia") == null, "cada una, solo la suya de 1a")
	_ver(ins_p != null and ins_p == ins_l and ins_p.grado == 2 and ins_p.nombre == "Polilla insomne",
		"la Polilla insomne (2a), el MISMO recurso en las dos fichas")
	var de_vig: Dictionary = pav.siguiente_mutacion(true, &"vigilia")
	var de_mor: Dictionary = luto.siguiente_mutacion(true, &"mortaja")
	_ver(de_vig.get("id") == &"insomne" and de_mor.get("id") == &"insomne", "comiendo: de la Vigilia y de la Mortaja, a la Insomne")
	_ver(int(vig.pesos["magia"]) == 50 and int(mor.pesos["agilidad"]) == 44 and int(ins_p.pesos["voluntad"]) == 42,
		"stats de los mutantes (Vigilia M50, Mortaja A44, Insomne V42)")
	for m in [vig, mor, ins_p]:
		var suma: int = 0
		for k in m.pesos:
			suma += int(m.pesos[k])
		_ver(suma == 170 and int(m.pesos["agilidad"]) >= 40, "%s: suma 170 y muy agil (A%d)" % [m.nombre, int(m.pesos["agilidad"])])

	print("3) LOS KITS")
	_ver(vig.elemento == Elementos.Elemento.LUZ and mor.elemento == Elementos.Elemento.OSCURIDAD,
		"basicos: Vigilia de Luz, Mortaja de Oscuridad")
	_ver(ins_p.basico_propio != null and ins_p.basico_propio.es_magico
		and ins_p.basico_propio.elemento_golpe == Elementos.Elemento.NINGUNO, "basico de la Insomne: MAGICO y sin elemento")
	var esperado := {
		"polilla_polvo_dorado": [0.45, Elementos.Elemento.LUZ, StatusEffects.Id.VULNERABLE, 0.6],
		"polilla_destello_escamas": [0.75, Elementos.Elemento.LUZ, StatusEffects.Id.CEGUERA, 0.6],
		"polilla_lluvia_escamas": [0.90, Elementos.Elemento.LUZ, -1, 0.0],
		"polilla_nube_ceniza": [0.45, Elementos.Elemento.OSCURIDAD, StatusEffects.Id.CEGUERA, 0.5],
		"polilla_aleteo_sombrio": [0.70, Elementos.Elemento.OSCURIDAD, StatusEffects.Id.MIEDO, 0.35],
		"polilla_ojo_que_se_abre": [2.00, Elementos.Elemento.LUZ, StatusEffects.Id.CEGUERA, 0.6],
		"polilla_parpado_negro": [0.80, Elementos.Elemento.OSCURIDAD, StatusEffects.Id.MIEDO, 0.4],
	}
	for k in esperado:
		var ab: AbilityData = _ab(k)
		var e: Array = esperado[k]
		var est_ok: bool = int(e[2]) < 0 or (ab.efectos.size() == 1 and ab.efectos[0].estado == int(e[2])
			and is_equal_approx(ab.efectos[0].prob, float(e[3])))
		_ver(ab.es_magico and is_equal_approx(ab.dano_mult, float(e[0])) and ab.elemento_golpe == int(e[1]) and est_ok,
			"%s: %.2f magico de %s" % [ab.nombre, float(e[0]), Elementos.nombre(int(e[1]))])
	var lluvia: AbilityData = _ab("polilla_lluvia_escamas")
	_ver(lluvia.forma_apunte == CombatFormas.Apunte.LIBRE and is_equal_approx(lluvia.forma_radio, 40.0)
		and is_equal_approx(lluvia.forma_rango, 120.0), "Lluvia de escamas: circulo de 40 donde apunta, hasta 120")
	var ojo: AbilityData = _ab("polilla_ojo_que_se_abre")
	_ver(ojo.carga_turnos == 1 and ojo.forma_apunte == CombatFormas.Apunte.ALREDEDOR and is_equal_approx(ojo.forma_radio, 70.0)
		and ojo.fx_anim_carga == &"ojo_carga" and ojo.fx_anim == &"ojo", "Ojo que se abre: carga 1 turno, circulo de 70, sus anims")
	var amo: AbilityData = _ab("polilla_amortajarse")
	_ver(amo.dano_mult == 0.0 and amo.efectos.size() == 1 and amo.efectos[0].estado == StatusEffects.Id.EN_SOMBRAS
		and not amo.efectos[0].en_objetivo and amo.efectos[0].turns == 2 and amo.cooldown == 4, "Amortajarse: En las sombras 2t, cd 4")
	_ver(is_equal_approx(ins_p.resiste_magia, 0.5) and is_equal_approx(ins_p.reflejo_magia, 0.25)
		and is_equal_approx(ins_p.atrae_radio, 60.0) and is_equal_approx(ins_p.atrae_px, 15.0),
		"Insomne: resiste magia 0,5, Mirada que devuelve 0,25, Insomnio 60/15")

	print("4) LOS SPRITES")
	var f_pav: SpriteFrames = SpritesEnemigo.frames_de(pav, 0.5)
	var f_luto: SpriteFrames = SpritesEnemigo.frames_de(luto, 0.5)
	_ver(f_pav != null and f_luto != null and SpritesEnemigo.clave_de(pav, 0.5) != SpritesEnemigo.clave_de(luto, 0.5),
		"pavon y de luto: claves distintas (%s / %s)" % [SpritesEnemigo.clave_de(pav, 0.5), SpritesEnemigo.clave_de(luto, 0.5)])
	if f_pav != null and f_luto != null:
		var a: Texture2D = f_pav.get_frame_texture(&"idle_0", 0)
		var b: Texture2D = f_luto.get_frame_texture(&"idle_0", 0)
		var atlas_a = a.get("atlas") if a != null else null
		var atlas_b = b.get("atlas") if b != null else null
		_ver(atlas_a != null and atlas_b != null and atlas_a != atlas_b and atlas_b.resource_path.contains("luto"),
			"la de luto se ve con OTRO dibujo (su atlas: %s)" % (atlas_b.resource_path if atlas_b != null else "?"))
	for par in [[pav, &"vigilia", ["evolucion_0", "aletear_0", "nube_0"]], [luto, &"mortaja", ["evolucion_0", "nube_0"]],
			[pav, &"insomne", ["ojo_carga_0", "ojo_0", "evolucion_vigilia_0", "evolucion_mortaja_0"]],
			[luto, &"insomne", ["evolucion_mortaja_0"]]]:
		var ed: EnemyData = par[0]
		_ver(SpritesEnemigo.mutante_propio(ed, par[1]), "%s/%s: sprite de mutante propio" % [ed.enemy_name, par[1]])
		var sf: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, par[1])
		var faltan: Array = (par[2] as Array).filter(func(an): return sf == null or not sf.has_animation(StringName(an)))
		_ver(faltan.is_empty(), "%s/%s: tiene %s%s" % [ed.enemy_name, par[1], par[2], "" if faltan.is_empty() else " (faltan %s)" % faltan])
		if sf != null and sf.has_animation(&"evolucion_vigilia_0"):
			_ver(sf.get_frame_count(&"evolucion_vigilia_0") == 20 and sf.get_frame_count(&"evolucion_mortaja_0") == 20,
				"las dos evoluciones de la Insomne, 20 fotogramas")

	print("5) LA PASIVA QUE SE VE")
	var c_ins: Combatant = pav.crear_combatant(0.5, true, false, &"insomne")
	var c_vig: Combatant = pav.crear_combatant(0.5, true, false, &"vigilia")
	_ver(c_ins.has_status(StatusEffects.Id.OJOS_INSOMNES), "la Insomne nace con Ojos en vela puesto")
	_ver(not c_vig.has_status(StatusEffects.Id.OJOS_INSOMNES), "la Vigilia, no")
	_ver(is_equal_approx(c_ins.resiste_magia, 0.5) and is_equal_approx(c_ins.reflejo_magia, 0.25), "y con sus campos")
	_ver(not StatusEffects.se_puede_disipar(StatusEffects.Id.OJOS_INSOMNES) and StatusEffects.se_puede_disipar(StatusEffects.Id.FORTALEZA),
		"Ojos en vela NO se puede disipar (la Fortaleza si)")
	for _k in 6:
		c_ins.tick_statuses()
	_ver(c_ins.has_status(StatusEffects.Id.OJOS_INSOMNES), "seis turnos despues sigue ahi (no se gasta)")
	var inst = null
	for e in c_ins.statuses:
		if e.id() == StatusEffects.Id.OJOS_INSOMNES:
			inst = e
	var txt: String = inst.resumen() if inst != null else ""
	print("     ficha: %s" % txt.replace("\n", " | "))
	_ver(txt.contains("pasiva (no se puede disipar)") and txt.contains("Recibe un 50 % menos de todo el daño mágico."),
		"su ficha dice que es pasiva y el 50 % (del dato)")
	_ver(inst != null and inst.duracion_texto() == "∞", "en el chip, ∞")
	_ver(StatusEffects.estados_que_salen(c_ins.statuses).filter(func(d): return int(d.get("id", -1)) == StatusEffects.Id.OJOS_INSOMNES).is_empty(),
		"no sale de la pelea")
	var peso: float = float(CombatReacciones.Reaccion.PASIVA) / 10.0 + float(StatusEffects.Id.OJOS_INSOMNES) / 1000.0
	_ver(CombatReacciones.texto_rotulo(peso) == "OJOS EN VELA", "su rotulo: '%s'" % CombatReacciones.texto_rotulo(peso))
	_ver(CombatReacciones.texto_rotulo(float(CombatReacciones.Reaccion.ROMPE) / 10.0) == "¡FRACTURA!", "(las reacciones siguen igual)")

	print("6) EL SET CONCENTRACION")
	var set_c: RunaSetData = null
	for s in Runas.sets():
		if (s as RunaSetData).id == &"polilla":
			set_c = s
	_ver(set_c != null and set_c.nombre == "Concentración" and set_c.tipo == RunaSetData.Tipo.ARMA, "el set existe y es de arma")
	if set_c != null:
		var t_set: String = Runas.efecto_txt(set_c)
		print("     texto: %s" % t_set)
		_ver(t_set.contains("aumenta en un 4 %") and t_set.contains("5 acumulaciones") and t_set.contains("pierde todas"),
			"su texto, con los numeros del set")
		_ver(set_c.runa != null and set_c.runa.id == &"runa_polilla" and pav.drop_runa == set_c.runa and luto.drop_runa == set_c.runa,
			"la runa de polilla, la sueltan las dos")
	_ver(CeldaObjeto.GLIFO_SET.has(&"polilla") and CeldaObjeto.tonos_glifo(&"polilla", Color.RED)["#"] == Color8(236, 62, 52),
		"el glifo del Ojo insomne con sus tonos")

	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_mut_polilla", Game.PISO_ARENA):
		_ver(false, "arranca la sala")
		return
	sala.poner(PAVON, Vector2(150, 0), {"mutacion": "vigilia"})
	sala.poner(LUTO, Vector2(0, 170), {"mutacion": "mortaja"})
	sala.poner(PAVON, Vector2(150, 170), {"mutacion": "insomne"})
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
	_ver(por_mut.has(&"vigilia") and por_mut.has(&"mortaja") and por_mut.has(&"insomne"), "en la pelea: las tres (%s)" % str(por_mut.keys()))
	if not (por_mut.has(&"vigilia") and por_mut.has(&"mortaja") and por_mut.has(&"insomne")):
		return
	var ins: Combatant = por_mut[&"insomne"]
	_ver(ins.nombre.contains("insomne") or ins.nombre.contains("Insomne"), "se llama Polilla insomne (%s)" % ins.nombre)
	_ver(por_mut[&"vigilia"].elemento_ataque == Elementos.Elemento.LUZ and por_mut[&"mortaja"].elemento_ataque == Elementos.Elemento.OSCURIDAD,
		"Vigilia pega de Luz, Mortaja de Oscuridad")
	_ver(ins.has_status(StatusEffects.Id.OJOS_INSOMNES), "la Insomne lleva Ojos en vela en la pelea")
	var yo: Combatant = combat._aliados[0]
	yo.max_hp = 100000.0
	yo.current_hp = 100000.0

	print("7) INSOMNIO (la luz que atrae)")
	var pc: Vector2 = t.pies_de(ins)
	_poner(t, yo, pc + Vector2(-50, 0))
	for otro in combat._aliados.slice(1):
		_poner(t, otro, pc + Vector2(-400, 200))
	var antes: float = t.pies_de(yo).distance_to(pc)
	combat.enemigos._luz_que_atrae(ins)
	await _esperar(40)
	_ver(t.pies_de(yo).distance_to(pc) < antes - 5.0, "a 50 px le acerca (%.1f -> %.1f)" % [antes, t.pies_de(yo).distance_to(pc)])

	print("8) EL ROTULO AL ENTRARLE MAGIA")
	var n_ev: int = combat._fx.ultima_tanda() if combat._fx != null else 0
	combat.reacciones.pasiva_magia(yo, ins)
	combat.reacciones.pasiva_magia(yo, ins)   # el mismo fotograma: una sola vez
	_ver(ins.get_meta(&"pasiva_rotulo_f", -1) == Engine.get_process_frames(), "sale el rotulo de su pasiva")

	print("9) CONCENTRACION EN LA PELEA")
	yo.runa_concentracion_por = 0.04
	yo.runa_concentracion_max = 5
	var m0: float = yo.status_spell_dmg_mult()
	for _k in 7:
		combat.magia.concentrar(yo)
	var cargas: int = 0
	for e in yo.statuses:
		if e.id() == StatusEffects.Id.CONCENTRACION:
			cargas = e.stacks
	_ver(cargas == 5, "siete frases bien: 5 cargas, el tope (%d)" % cargas)
	_ver(is_equal_approx(yo.status_spell_dmg_mult(), m0 * 1.20), "daño magico +20 %% (x%.3f)" % yo.status_spell_dmg_mult())
	yo.tick_statuses()
	yo.tick_statuses()
	_ver(yo.has_status(StatusEffects.Id.CONCENTRACION), "dos turnos despues siguen (de hechizo en hechizo)")
	_ver(StatusEffects.estados_que_salen(yo.statuses).filter(func(d): return int(d.get("id", -1)) == StatusEffects.Id.CONCENTRACION).is_empty(),
		"no salen de la pelea")
	combat.magia.desconcentrar(yo)
	_ver(not yo.has_status(StatusEffects.Id.CONCENTRACION) and is_equal_approx(yo.status_spell_dmg_mult(), m0),
		"fallar una frase las quita todas")
	_ver(_log(combat).contains("pierde la Concentración"), "y lo dice el registro")
	var otro_pj: Combatant = combat._aliados[1] if combat._aliados.size() > 1 else null
	if otro_pj != null:
		combat.magia.concentrar(otro_pj)
		_ver(not otro_pj.has_status(StatusEffects.Id.CONCENTRACION), "sin el set, nada")

	print("10) LOS EFECTOS EN PIXEL")
	var datos: Dictionary = (load("res://scripts/fx/efectos_pixel_datos.gd").HOJAS as Dictionary).get("polilla", {})
	var faltan: Array = []
	for h in ["roce_polvo", "roce_oro", "roce_ceniza", "roce_rojo", "polvo_polvo", "polvo_oro", "polvo_ceniza", "polvo_rojo",
			"velo", "miedo", "aleteo_polvo", "cono_oro", "cono_ceniza", "cono_negro", "ojo_carga", "ojo", "anillo60_polvo",
			"anillo60_oro", "anillo60_ceniza", "anillo70_rojo", "lluvia", "amortajarse", "insomnio", "mirada", "mirada_bola",
			"mirada_llega"]:
		if not datos.has(h):
			faltan.append(h)
	_ver(faltan.is_empty(), "las %d hojas de la polilla estan horneadas%s" % [datos.size(), "" if faltan.is_empty() else " (faltan %s)" % faltan])
	var arena: Node = t._arena()
	var f_c := CombatFormas.Forma.new()
	f_c.centro = t.pies_de(ins)
	f_c.radio = 60.0
	for par_s in [[SueloRoto.Tipo.SIMA_ANILLO, "Nube"], [SueloRoto.Tipo.POLILLA_ORO, "Polvo dorado"],
			[SueloRoto.Tipo.POLILLA_CENIZA, "Nube de ceniza"], [SueloRoto.Tipo.POLILLA_ROJO, "Ojo que se abre"],
			[SueloRoto.Tipo.POLILLA_LLUVIA, "Lluvia de escamas"]]:
		var n_s: Node2D = SueloRoto.lanzar(arena, f_c, int(par_s[0]), 7)
		_ver(n_s is EfectoPixel, "el suelo de %s, en pixel" % par_s[1])
	_ver(_ab("polilla_polvo_dorado").suelo_roto == SueloRoto.Tipo.POLILLA_ORO and _ab("polilla_nube_ceniza").suelo_roto == SueloRoto.Tipo.POLILLA_CENIZA
		and _ab("polilla_ojo_que_se_abre").suelo_roto == SueloRoto.Tipo.POLILLA_ROJO and _ab("polilla_lluvia_escamas").suelo_roto == SueloRoto.Tipo.POLILLA_LLUVIA
		and _ab("polilla_nube").suelo_roto == SueloRoto.Tipo.SIMA_ANILLO, "cada nube con el suelo de su color")
	_ver([t.color_polilla(por_mut[&"vigilia"]), t.color_polilla(por_mut[&"mortaja"]), t.color_polilla(ins)] == ["oro", "ceniza", "rojo"],
		"los colores: oro, ceniza y rojo")
	var cuenta := func() -> int: return arena.find_children("*", "EfectoPixel", true, false).size()
	var antes_e: int = cuenta.call()
	t._polilla_pixel(arena, CombatFX.Estilo.SIMA_ALA, por_mut[&"vigilia"], yo, 0.0, 1.0)
	t._polilla_pixel(arena, CombatFX.Estilo.SIMA_POLVO, por_mut[&"mortaja"], yo, 0.0, 1.0)
	t._polilla_pixel(arena, CombatFX.Estilo.SIMA_ATRAE, ins, yo, 0.0, 1.0)
	_ver(cuenta.call() >= antes_e + 3, "el roce, el polvo y el Insomnio salen en pixel (%d -> %d)" % [antes_e, cuenta.call()])
	antes_e = cuenta.call()
	for par_g in [[por_mut[&"vigilia"], "aletear"], [por_mut[&"mortaja"], "amortajarse"], [ins, "ojo"]]:
		t._pixel.al_gesto(par_g[0], t.cuerpo_de(par_g[0]), par_g[1], 0.6)
	_ver(cuenta.call() >= antes_e + 3, "y los gestos: el cono, el humo de Amortajarse y el Ojo (%d -> %d)" % [antes_e, cuenta.call()])
	var sf_m: SpriteFrames = SpritesEnemigo.frames_de(luto, 0.5, true, &"mortaja")
	_ver(sf_m != null and sf_m.has_animation(&"amortajarse_0") and _ab("polilla_amortajarse").fx_anim == &"amortajarse",
		"Amortajarse con su propio gesto (y la Nube de ceniza sin su humo)")
	await _foto_efectos(t, por_mut, ins, yo)


# LA LAMINA DE LOS EFECTOS EN EL JUEGO (POLILLA_CAPTURA=<ruta sin .png>, con ventana): cada efecto disparado en la pelea de
# verdad, una fila por efecto y cinco momentos, sin los paneles encima. Para enseñarselos al jefe.
func _foto_efectos(t, por_mut: Dictionary, ins: Combatant, yo: Combatant) -> void:
	var salida: String = OS.get_environment("POLILLA_CAPTURA")
	if salida == "" or DisplayServer.get_name() == "headless":
		return
	var arena: Node = t._arena()
	var vig: Combatant = por_mut[&"vigilia"]
	var mor: Combatant = por_mut[&"mortaja"]
	# Todos juntos y a la vista: yo delante de la Insomne, la Vigilia y la Mortaja a los lados.
	var c0: Vector2 = t.pies_de(ins)
	_poner(t, yo, c0 + Vector2(-70, 50))
	_poner(t, vig, c0 + Vector2(-170, -30))
	_poner(t, mor, c0 + Vector2(110, 20))
	for otro in combat_aliados(t).slice(1):
		_poner(t, otro, c0 + Vector2(-400, 300))
	# EL MUNDO NO ESTA EN LA PANTALLA: en la sala propia el piso vive en un SubViewport (el de la sala). Se fotografia ese.
	var vp: Viewport = arena.get_viewport()
	if vp is SubViewport:
		(vp as SubViewport).size = Vector2i(1280, 720)
		(vp as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := Camera2D.new()
	cam.zoom = Vector2(2.0, 2.0)
	cam.process_mode = Node.PROCESS_MODE_ALWAYS
	arena.add_child(cam)
	cam.global_position = c0 + Vector2(-30, 0)
	cam.make_current()
	var capas: Array = []
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if (n as CanvasLayer).visible and not n.is_ancestor_of(arena):   # (la arena vive en una: esa no)
			capas.append(n)
			(n as CanvasLayer).visible = false
	await _esperar(30)
	var f_suelo := func(tipo: int, centro: Vector2, radio: float) -> void:
		var f := CombatFormas.Forma.new()
		f.centro = centro
		f.radio = radio
		SueloRoto.lanzar(arena, f, tipo, 7)
	var escenas: Array = [
		["roce de luz (Vigilia)", func(): t._polilla_pixel(arena, CombatFX.Estilo.SIMA_ALA, vig, yo, 0.0, 1.0)],
		["roce de sombra (Mortaja)", func(): t._polilla_pixel(arena, CombatFX.Estilo.SIMA_ALA, mor, yo, 0.0, 1.0)],
		["polvo en la cara + velo", func():
			t._polilla_pixel(arena, CombatFX.Estilo.SIMA_POLVO, vig, yo, 0.0, 1.0)
			EfectoPixel.lanzar(arena, "polilla", "velo", t.pies_de(yo), 0, t.cuerpo_de(yo), 0.15)],
		["Destello de escamas (cono)", func(): t._pixel.al_gesto(vig, t.cuerpo_de(vig), "aletear", 0.6)],
		["Parpado negro (cono) + miedo", func():
			t._pixel.al_gesto(ins, t.cuerpo_de(ins), "aletear", 0.6)
			EfectoPixel.lanzar(arena, "polilla", "miedo", t.pies_de(yo), 0, t.cuerpo_de(yo), 0.2)],
		["Polvo dorado (anillo)", func(): f_suelo.call(SueloRoto.Tipo.POLILLA_ORO, t.pies_de(vig), 60.0)],
		["Ojo que se abre", func():
			t._pixel.al_gesto(ins, t.cuerpo_de(ins), "ojo", 0.6)
			f_suelo.call(SueloRoto.Tipo.POLILLA_ROJO, c0, 70.0)],
		["Lluvia de escamas", func(): f_suelo.call(SueloRoto.Tipo.POLILLA_LLUVIA, t.pies_de(yo), 40.0)],
		["Amortajarse", func(): t._pixel.al_gesto(mor, t.cuerpo_de(mor), "amortajarse", 1.6)],
		["Insomnio", func(): t._polilla_pixel(arena, CombatFX.Estilo.SIMA_ATRAE, ins, yo, 0.0, 1.0)],
	]
	await RenderingServer.frame_post_draw
	var tam: Vector2i = vp.get_texture().get_image().get_size()
	var rec := Rect2i(tam / 2 - Vector2i(400, 230), Vector2i(800, 460))
	var momentos := [6, 14, 24, 36, 52]
	var hoja := Image.create(rec.size.x * momentos.size(), rec.size.y * escenas.size(), false, Image.FORMAT_RGBA8)
	for j in escenas.size():
		print("     foto: %s" % escenas[j][0])
		await _esperar(70)   # que se vaya lo de antes
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


func combat_aliados(t) -> Array:
	return t._pantalla._aliados
