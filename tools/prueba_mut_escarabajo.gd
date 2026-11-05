# LOS MUTANTES DEL ESCARABAJO DE HIERRO (04/11): Escarabajo -> IMAN / SAETA -> IMAN ERRANTE. El arbol, el reparto, los ataques
# (magicos el Pulso y el Picado magnetico) y las pasivas; y EN LA PELEA (su sala): en el aire no se le elige y un area lo
# baja y le corta el Picado, el Pulso arrastra e Imanta, la Adherencia te deja a media marcha, las Limaduras suben y la
# Embestida las gasta, Orbita, la Coraza no le deja mover, y el set Campo magnetico.
#   godot --headless --path . res://tools/prueba_mut_escarabajo.tscn
extends Node

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
	var ed: EnemyData = load("res://scenes/actors/enemy/escarabajo.tres")
	print("1) EL ARBOL")
	var im: Combatant = ed.crear_combatant(0.5, true, false, &"iman")
	var sa: Combatant = ed.crear_combatant(0.5, true, false, &"saeta")
	var er: Combatant = ed.crear_combatant(0.5, true, false, &"errante")
	_ver(im.nombre == "Escarabajo imán" and sa.nombre == "Escarabajo saeta" and er.nombre == "Imán errante", "nombres")
	var primeras: Array = []
	for _i in 60:
		primeras.append(ed.siguiente_mutacion(false, &"")["id"])
	_ver(primeras.has(&"iman") and primeras.has(&"saeta"), "del escarabajo sale iman o saeta")
	_ver(ed.siguiente_mutacion(true, &"iman")["id"] == &"errante" and ed.siguiente_mutacion(true, &"saeta")["id"] == &"errante",
		"de los dos se llega al errante")

	print("2) LAS STATS")
	for id in [&"iman", &"saeta", &"errante"]:
		var p: Dictionary = ed.mutacion_de(id).pesos
		var suma: int = 0
		for k in p:
			suma += int(p[k])
		_ver(suma == 150 and p.size() == 6, "%s: las seis, suma %d" % [id, suma])
	_ver(sa.hab("agilidad") > im.hab("agilidad") * 2.0, "el saeta, mucho mas agil (es el cambio que tiene que destacar)")

	print("3) LOS ATAQUES")
	_ver(_nombres(im) == ["Pulso magnético", "Embestida imantada", "Coraza imantada"], "iman: %s" % [_nombres(im)])
	_ver(_nombres(sa) == ["Picado", "Pasada en vuelo", "Élitros cerrados"], "saeta: %s" % [_nombres(sa)])
	_ver(_nombres(er) == ["Pulso magnético", "Picado", "Pasada en vuelo", "Picado magnético"], "errante: %s" % [_nombres(er)])
	for c in [im, sa, er]:
		for a in c.habilidades:
			_ver(a.es_magico == (a.nombre == "Pulso magnético" or a.nombre == "Picado magnético"), "%s: magico o fisico" % a.nombre)

	print("4) LAS PASIVAS")
	_ver(im.adherencia_radio == 60.0 and im.limaduras_tope == 5 and im.pega_y_se_va == 0.0, "iman: adherencia y limaduras")
	_ver(sa.pega_y_se_va == 60.0 and sa.adherencia_radio == 0.0, "saeta: pega y se va")
	_ver(er.orbita and er.adherencia_radio == 60.0 and er.pega_y_se_va == 60.0 and er.limaduras_tope == 0, "errante: orbita, adherencia, sin limaduras")
	var c0: Combatant = ed.crear_combatant(0.5, false)
	_ver(c0.adherencia_radio == 0.0 and not c0.orbita and c0.carga_tope == 0, "el normal, ninguna")

	await _pelea()
	print("FIN: %s" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)


func _pelea() -> void:
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_mut_escarabajo", Game.PISO_ARENA):
		_ver(false, "arranca la sala")
		return
	sala.poner("res://scenes/actors/enemy/escarabajo.tres", Vector2(90, 0), {})
	sala.poner("res://scenes/actors/enemy/escarabajo.tres", Vector2(110, 90), {})
	sala.poner("res://scenes/actors/enemy/escarabajo.tres", Vector2(-110, 90), {})
	await _esperar(25)
	var nodos: Array = get_tree().get_nodes_in_group("enemy")
	nodos[0].aplicar_mutacion(&"iman", 0.0)
	nodos[1].aplicar_mutacion(&"saeta", 0.0)
	nodos[2].aplicar_mutacion(&"errante", 0.0)
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
	var im: Combatant = null
	var sa: Combatant = null
	var er: Combatant = null
	for e in combat._enemies:
		match e.mutacion:
			&"iman": im = e
			&"saeta": sa = e
			&"errante": er = e
	_ver(im != null and sa != null and er != null, "en la pelea, los tres")
	if im == null or sa == null or er == null:
		return
	var al: Array = combat._aliados_vivos()
	var yo: Combatant = al[0]
	for a in al:
		a.current_hp = a.max_hp
		a.invulnerable = false
	var ps: Vector2 = tm.pies_de(yo)

	print("5) EN EL AIRE")
	var pic: AbilityData = load("res://resources/abilities/escarabajo_picado.tres")
	_poner(tm, sa, ps + Vector2(120, 0))
	en._enemy_begin_retraso(sa, pic, yo)
	_ver(sa.has_status(StatusEffects.Id.EN_VUELO) and sa.no_elegible() and not sa.en_sombras(), "sube: no se le elige, pero se le ve")
	combat._target_idx = combat._enemies.find(im)
	combat.figuras._seleccionar(combat._enemies.find(sa))
	_ver(combat._enemies[combat._target_idx] == im, "pinchar en el no lo elige")
	en.tick_escarabajo()
	_ver(sa.charging == pic and sa.has_status(StatusEffects.Id.EN_VUELO), "sigue arriba mientras carga")
	sa.take_damage(2.0)
	_ver(not sa.has_status(StatusEffects.Id.EN_VUELO) and sa.derribado, "un area lo baja")
	en.tick_escarabajo()
	_ver(sa.charging == null and not sa.derribado, "y pierde el Picado")
	sa.apply_status(StatusEffects.Id.EN_VUELO)
	en.tick_escarabajo()
	_ver(not sa.has_status(StatusEffects.Id.EN_VUELO), "sin nada cargando no se queda en el aire")

	print("6) LA ADHERENCIA")
	_poner(tm, im, ps + Vector2(40, 0))
	_poner(tm, er, ps + Vector2(0, 300))
	yo.statuses.clear()
	en.turno_junto_al_iman(yo)
	_ver(yo.has_status(StatusEffects.Id.ADHERIDO) and yo.congelado(), "a 40 px de el: Adherido, a media marcha")
	yo.statuses.clear()
	_poner(tm, im, ps + Vector2(90, 0))
	en.turno_junto_al_iman(yo)
	_ver(not yo.has_status(StatusEffects.Id.ADHERIDO), "a 90 px, nada")

	print("7) LAS LIMADURAS")
	im.statuses.clear()
	for _i in 7:
		im.take_damage(1.0)
	var lim = im.get_status(StatusEffects.Id.LIMADURAS)
	_ver(lim != null and int(lim.stacks) == 5, "se le pegan con cada golpe, tope 5 (%d)" % (int(lim.stacks) if lim != null else -1))
	var emb: AbilityData = load("res://resources/abilities/escarabajo_embestida_imantada.tres")
	var m: float = en._limaduras_mult(im, emb)
	_ver(absf(m - 1.3) < 0.001, "la Embestida pega mas por las que lleva (x%.2f)" % m)
	en.tick_escarabajo()
	_ver(not im.has_status(StatusEffects.Id.LIMADURAS), "y las gasta")
	_ver(is_equal_approx(en._limaduras_mult(sa, pic), 1.0), "(el Picado no las usa)")

	print("8) ORBITA Y CORAZA")
	yo.apply_status(StatusEffects.Id.IMANTADO)
	_ver(yo.enraizado(), "Imantado: no puede andar")
	en.tick_escarabajo()
	_ver(er.has_status(StatusEffects.Id.ORBITA), "con alguien Imantado, el errante entra en Orbita")
	yo.statuses.clear()
	en.tick_escarabajo()
	_ver(not er.has_status(StatusEffects.Id.ORBITA), "suelto, se le pasa")
	im.apply_status(StatusEffects.Id.CORAZA_IMAN)
	en.tick_escarabajo()
	_ver(im.imparable, "con la Coraza no le mueven")
	im.statuses.clear()
	en.tick_escarabajo()
	_ver(not im.imparable, "sin ella, si")

	print("9) EL SET CAMPO MAGNETICO")
	yo.statuses.clear()
	yo.runa_campo_cada = 3
	yo.runa_campo_radio = 70.0
	yo.runa_campo_barra = 0.25
	yo.runa_campo_cuenta = 0
	_poner(tm, im, tm.pies_de(yo) + Vector2(40, 0))
	combat._gauge[im] = combat.UMBRAL * 0.8
	en.campo_magnetico(yo)
	en.campo_magnetico(yo)
	_ver(is_equal_approx(float(combat._gauge[im]), combat.UMBRAL * 0.8), "los dos primeros turnos, nada")
	en.campo_magnetico(yo)
	_ver(absf(float(combat._gauge[im]) - combat.UMBRAL * 0.55) < 0.01, "al tercero le quita el 25 % de barra")
	var set_e: RunaSetData = load("res://resources/runas/set_escarabajo.tres")
	_ver(set_e != null and set_e.efecto == &"campo_magnetico" and set_e.runa != null, "el set existe y tiene su runa")
	_ver((load("res://scenes/actors/enemy/escarabajo.tres") as EnemyData).drop_runa != null, "el escarabajo suelta su runa")
	yo.runa_campo_cada = 0

	print("10) LOS SPRITES HORNEADOS")
	var sf_sa: SpriteFrames = (tm.cuerpo_de(sa).get("_sprite") as AnimatedSprite2D).sprite_frames
	for base in ["idle", "walk", "basico", "subir", "aire", "picado", "pasada", "elitros", "caer", "volteado", "recolocarse", "comer", "evolucion", "muerte", "encaje"]:
		_ver(sf_sa.has_animation(StringName("%s_0" % base)), "saeta: %s" % base)
	var sf_er: SpriteFrames = (tm.cuerpo_de(er).get("_sprite") as AnimatedSprite2D).sprite_frames
	for base in ["pulso_carga", "pulso", "subir", "aire", "picado", "pasada", "caer", "volteado", "recolocarse", "evolucion", "evolucion_saeta"]:
		_ver(sf_er.has_animation(StringName("%s_0" % base)), "errante: %s" % base)
	var sf_im: SpriteFrames = (tm.cuerpo_de(im).get("_sprite") as AnimatedSprite2D).sprite_frames
	for base in ["pulso_carga", "pulso", "embestir_carga", "embestir", "caparazon", "evolucion"]:
		_ver(sf_im.has_animation(StringName("%s_0" % base)), "iman: %s" % base)
	_ver(not sf_im.has_animation(&"volteado_0"), "el iman no vuela: no tiene volteado")
	_ver(ResourceLoader.exists("res://assets/sprites/enemigos/escarabajo3d_escarabajo_sdf_saeta.png"), "saeta sale del horno, no dibujado al vuelo")

	print("11) DERRIBADO")
	sa.statuses.clear()
	sa.charging = null
	tm._gestos_bicho.erase(tm.cuerpo_de(sa))
	sa.apply_status(StatusEffects.Id.ATURDIDO)
	tm._tick_volcadas()
	_ver(String((tm.cuerpo_de(sa).get("_sprite") as AnimatedSprite2D).animation).begins_with("caer_"), "aturdido cae (%s)" % (tm.cuerpo_de(sa).get("_sprite") as AnimatedSprite2D).animation)
	_ver(Array(tm._gestos_bicho[tm.cuerpo_de(sa)]["cola"]) == ["volteado"] and tm._gestos_bicho[tm.cuerpo_de(sa)]["sostener"], "y se queda volteado lo que le dure")
	sa.statuses.clear()
	tm._tick_volcadas()
	_ver(String((tm.cuerpo_de(sa).get("_sprite") as AnimatedSprite2D).animation).begins_with("recolocarse_"), "se le pasa y se recoloca")
	im.statuses.clear()
	im.apply_status(StatusEffects.Id.ATURDIDO)
	tm._tick_volcadas()
	_ver(not tm._volcadas.has(im), "el iman, en el suelo, no se vuelca")
	im.statuses.clear()
	tm._gestos_bicho.erase(tm.cuerpo_de(sa))
	# Bajado del aire por un area, sin aturdir: cae y se recoloca enseguida, sin quedarse 1,5 s flotando.
	tm._poses_carga.clear()
	sa.charging = pic
	sa.apply_status(StatusEffects.Id.EN_VUELO)
	tm._tick_cargas_bicho(0.0)
	_ver(String((tm.cuerpo_de(sa).get("_sprite") as AnimatedSprite2D).animation).begins_with("subir_"), "sube")
	sa.take_damage(2.0)
	en.tick_escarabajo()
	tm._tick_cargas_bicho(0.0)
	_ver(String((tm.cuerpo_de(sa).get("_sprite") as AnimatedSprite2D).animation).begins_with("subir_"), "(aun sin el aviso, sigue la pose)")
	tm._poses_carga[sa]["t"] = tm.T_CARGA_SUELTA   # lo que hace el aviso de ¡INTERRUMPIDO! (_on_impacto)
	tm._tick_cargas_bicho(0.0)
	_ver(String((tm.cuerpo_de(sa).get("_sprite") as AnimatedSprite2D).animation).begins_with("caer_"), "con el aviso, cae")
	_ver(Array(tm._gestos_bicho[tm.cuerpo_de(sa)]["cola"]) == ["recolocarse"], "y se recoloca")
	tm._gestos_bicho.erase(tm.cuerpo_de(sa))

	print("12) EL PICADO DE VERDAD")
	for a in al:
		a.statuses.clear()
		a.current_hp = a.max_hp
	# (todos en medio de la arena: con el saeta pegado al borde, el salto no tiene suelo por donde ir y se queda en el sitio)
	var medio: Vector2 = tm._dentro(tm._arena()).get_center()
	print("     saeta en la arena antes: %s" % tm._en_arena(tm.pos_de(sa)))
	for i in al.size():
		_poner(tm, al[i], medio + Vector2(-40.0 + 40.0 * i, 30.0))
	_poner(tm, sa, medio + Vector2(130, -20))
	_poner(tm, im, medio + Vector2(-130, -90))
	_poner(tm, er, medio + Vector2(-130, 90))
	sa.statuses.clear()
	en._enemy_begin_charge(sa, pic, yo)
	_ver(tm._presas_carga.has(sa), "marca a su presa al subir")
	var presa: Combatant = tm._presas_carga.get(sa)
	var nuevo: Vector2 = tm.pies_de(presa) + Vector2(-60, 40)
	_poner(tm, presa, nuevo)
	tm._deslices.clear()
	# (05/11, banco) Solo PEGA Y SE VA si acierta: que no lo esquive por azar (salia MAL una vez de cada tantas).
	var prec_antes: float = sa.precision
	sa.precision += 10.0
	en._enemy_use_ability(sa, pic, presa)
	sa.precision = prec_antes
	var hasta = null
	var retirada = null
	for d in tm._deslices:
		if d["c"] == sa:
			if hasta == null:
				hasta = d["hasta"]
			else:
				retirada = d["hasta"]
	# PEGA Y SE VA, desde donde ha caido (antes salia de donde estaba y volvia volando a su sitio).
	_ver(retirada != null and hasta != null and (retirada as Vector2).distance_to(hasta) <= 70.0,
		"tras caer se aparta un poco, desde donde ha caido (%s)" % ["-" if retirada == null or hasta == null else "%d px" % int((retirada as Vector2).distance_to(hasta))])
	_ver(hasta != null, "al soltar se mueve (no pega sin moverse)")
	print("     presa %s en %s, cae en %s" % [presa.nombre, tm.cuerpo_de(presa).global_position, hasta])
	var fu = tm.ultima_forma_enemigo
	print("     forma: centro %s; libre hacia ella: %s; desde %s" % [fu.centro if fu != null else null,
		tm._sitio_libre_hacia(sa, fu.centro) if fu != null else null, tm.pos_de(sa)])
	var pf: Vector2 = tm.pies_de(presa)
	var otros_ahi: Array = al.filter(func(o): return o != presa and tm.pies_de(o).distance_to(pf) < 30.0).map(func(o): return o.nombre)
	print("     suelo en la presa: %s, arena: %s, otros a <30 px: %s" % [tm._sobre_suelo(pf - tm._bajo_de(sa), tm.cuerpo_de(sa)), tm._en_arena(pf - tm._bajo_de(sa)), otros_ahi])
	if hasta != null:
		_ver((hasta as Vector2).distance_to(tm.cuerpo_de(presa).global_position) <= 60.0, "y cae donde esta su presa AHORA, no donde estaba (a %d px)" % int((hasta as Vector2).distance_to(tm.cuerpo_de(presa).global_position)))
	var pmag: AbilityData = load("res://resources/abilities/escarabajo_picado_magnetico.tres")
	_ver(pic.salta and pmag.salta, "los dos Picados saltan")
	_ver(pic.fx_anim_interrumpe == &"caer>recolocarse" and pmag.fx_anim_interrumpe == &"caer>recolocarse", "los dos caen al cortarlos")

	print("13) LOS EFECTOS EN PIXEL ART")
	var arena: Node = tm._arena()
	var contar := func() -> int:
		return arena.get_children().filter(func(n): return n is EfectoPixel).size()
	for nombre in ["pulso_carga", "pulso_tiron", "mag_impacto", "picado_impacto", "emb_sale", "pasada", "coraza", "elitros", "caer"]:
		var ef: EfectoPixel = EfectoPixel.lanzar(arena, "escarabajo", nombre, tm.pies_de(yo), 6)
		_ver(ef != null and ef.num_capas() >= 1, "la hoja %s carga (%d capas)" % [nombre, ef.num_capas() if ef != null else 0])
		if ef != null:
			ef.queue_free()
	await _esperar(2)
	var antes: int = contar.call()
	tm.gesto_bicho_en_mapa(im, &"caparazon", -1.0)
	await _esperar(1)
	_ver(contar.call() > antes, "la Coraza del iman saca su efecto")
	antes = contar.call()
	tm.gesto_bicho_en_mapa(sa, &"pasada", 0.4)
	await _esperar(1)
	_ver(contar.call() > antes, "la Pasada saca su estela")
	# Lo de la carga se va con la carga.
	sa.statuses.clear()
	_poner(tm, sa, ps + Vector2(150, 0))
	en._enemy_begin_charge(sa, pic, yo)
	await _esperar(3)
	_ver(tm._pixel._cargas.has(sa), "subido al Picado: su sombra persigue")
	tm.olvidar_carga(sa)
	sa.charging = null
	tm._pixel.tick()   # (la pelea esta parada en esta prueba: el tick a mano)
	_ver(not tm._pixel._cargas.has(sa), "y se va al soltar o cortarlo")
	_ver(not tm._tiene_anim_bicho(tm.cuerpo_de(im), "volteado"), "(el normal y el iman no llevan los del vuelo)")
