# LOS MUTANTES DEL CIEMPIES CARMESI (05/11): Ciempies -> BICEFALO -> NUDO CARMESI. El arbol, el reparto de las seis stats, los
# ataques y las pasivas; y EN LA PELEA (su sala): DOS MENTES (un aturdimiento duerme una cabeza, el de area las dos, cada cabeza
# con su contador), el basico en U (dos golpes al mismo; con una cabeza, uno), la Pinza que pide las dos cabezas, el Enrosque
# con la cabeza libre, el Enrosque doble del Nudo con una presa por cabeza y su apreton que crece, y el set Dos mentes.
#   godot --headless --path . res://tools/prueba_mut_ciempies.tscn
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
	var ed: EnemyData = load("res://scenes/actors/enemy/ciempies.tres")
	print("1) EL ARBOL")
	var bi: Combatant = ed.crear_combatant(0.5, true, false, &"bicefalo")
	var nu: Combatant = ed.crear_combatant(0.5, true, false, &"nudo")
	_ver(bi.nombre == "Ciempiés bicéfalo" and nu.nombre == "Nudo carmesí", "nombres")
	_ver(ed.siguiente_mutacion(false, &"")["id"] == &"bicefalo", "del ciempies sale el bicefalo")
	_ver(ed.siguiente_mutacion(true, &"bicefalo")["id"] == &"nudo", "del bicefalo, el nudo")

	print("2) LAS STATS")
	var suma_normal: int = ed.fuerza + ed.resistencia + ed.destreza + ed.agilidad + ed.magia + ed.voluntad
	_ver(ed.voluntad == 12 and ed.magia == 8, "el normal estrena Voluntad 12, Magia 8")
	for id in [&"bicefalo", &"nudo"]:
		var p: Dictionary = ed.mutacion_de(id).pesos
		var suma: int = 0
		for k in p:
			suma += int(p[k])
		_ver(suma == suma_normal and p.size() == 6, "%s: las seis, suma %d (la del normal, %d)" % [id, suma, suma_normal])
	_ver(nu.hab("resistencia") > bi.hab("resistencia") and nu.hab("agilidad") < bi.hab("agilidad"), "el nudo, mas duro y mas lento")

	print("3) LOS ATAQUES Y PASIVAS")
	_ver(_nombres(bi) == ["Oleada de patas", "Enrosque", "Pinza"], "bicefalo: %s" % [_nombres(bi)])
	_ver(_nombres(nu) == ["Oleada de patas", "Enrosque", "Pinza", "Derrumbe"], "nudo: %s" % [_nombres(nu)])
	_ver(bi.dos_mentes and nu.dos_mentes and bi.basico_propio != null and bi.cabeza_libre_mult > 0.0, "los dos: dos cabezas")
	_ver(bi.enrosque_pegados_radio == 0.0 and nu.enrosque_pegados_radio > 0.0 and nu.aprieta_por_turno > 0.0, "solo el nudo atrapa a dos y aprieta mas")
	var c0: Combatant = ed.crear_combatant(0.5, false)
	_ver(not c0.dos_mentes and c0.basico_propio == null and c0.cabeza_libre_mult == 0.0, "el normal, ninguna")
	var der: AbilityData = load("res://resources/abilities/nudo_derrumbe.tres")
	_ver(der.carga_turnos == 1 and der.forma_radio == 70.0 and der.dano_tipo_override == 1, "Derrumbe: carga, r70, contundente")
	var pinza: AbilityData = load("res://resources/abilities/ciempies_pinza.tres")
	_ver(pinza.forma_mitades and pinza.pide_dos_cabezas, "Pinza: dos mitades y pide las dos cabezas")

	print("4) DOS MENTES, sin pelea")
	bi.statuses.clear()
	bi.apply_status(StatusEffects.Id.ATURDIDO)
	_ver(not bi.aturdido() and bi.has_status(StatusEffects.Id.UNA_CABEZA) and bool(bi.cabezas_dormidas[1]) and not bool(bi.cabezas_dormidas[0]),
		"el primero duerme solo una cabeza (la libre), y sigue jugando")
	_ver(is_equal_approx(bi.decaimiento_control(StatusEffects.Id.ATURDIDO), 1.0), "la otra cabeza lleva su contador: el segundo no cuesta mas")
	bi.apply_status(StatusEffects.Id.ATURDIDO)
	_ver(bi.aturdido() and not bi.has_status(StatusEffects.Id.UNA_CABEZA), "el segundo: aturdido de verdad")
	var ev: Dictionary = bi.tick_statuses()
	_ver(ev.stunned and not bool(bi.cabezas_dormidas[0]) and not bool(bi.cabezas_dormidas[1]), "pierde el turno y se despiertan")
	_ver(is_equal_approx(bi.decaimiento_control(StatusEffects.Id.ATURDIDO), 0.5), "cada cabeza recuerda el suyo: ahora cuesta el doble")
	var ar: Combatant = ed.crear_combatant(0.5, true, false, &"bicefalo")
	ar.aturdir_en_area = true
	ar.apply_status(StatusEffects.Id.ATURDIDO)
	_ver(ar.aturdido() and not ar.aturdir_en_area, "uno de AREA pilla a las dos cabezas: aturdido a la primera")
	var so: Combatant = ed.crear_combatant(0.5, true, false, &"bicefalo")
	so.apply_status(StatusEffects.Id.ATURDIDO)
	so.tick_statuses()
	_ver(so.una_cabeza_este_turno() and not so.has_status(StatusEffects.Id.UNA_CABEZA), "una cabeza dormida: este turno le falta, y luego se despierta")
	so.tick_statuses()
	_ver(not so.una_cabeza_este_turno(), "al turno siguiente, las dos")
	var norm: Combatant = ed.crear_combatant(0.5, false)
	norm.apply_status(StatusEffects.Id.ATURDIDO)
	_ver(norm.aturdido(), "el normal se aturde de una, como siempre")

	print("5) EL SET DOS MENTES")
	var set_c: RunaSetData = load("res://resources/runas/set_ciempies.tres")
	_ver(set_c != null and set_c.efecto == &"dos_mentes" and set_c.runa != null and set_c.tipo == 1, "el set existe, de armadura, con su runa")
	_ver(ed.drop_runa != null, "el ciempies suelta su runa")
	_ver(Runas.efecto_txt(set_c).contains("4"), "su texto lleva el numero de la ficha")
	var yo_set: Combatant = ed.crear_combatant(0.5, false)
	yo_set.runa_mentes_turnos = 4
	yo_set.apply_status(StatusEffects.Id.ATURDIDO)
	_ver(not yo_set.aturdido() and yo_set.runa_mentes_espera == 4, "el primero no te para")
	_ver(yo_set.aviso_mentes == 1, "y se avisa en pantalla")
	yo_set.apply_status(StatusEffects.Id.ATURDIDO)
	_ver(yo_set.aturdido(), "el segundo, si: esta recargando")
	yo_set.statuses.clear()
	for _i in 4:
		yo_set.tick_statuses()
	yo_set.apply_status(StatusEffects.Id.ATURDIDO)
	_ver(not yo_set.aturdido(), "a los 4 turnos, otra vez")

	await _pelea()
	print("FIN: %s" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)


func _pelea() -> void:
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_mut_ciempies", Game.PISO_ARENA):
		_ver(false, "arranca la sala")
		return
	sala.poner("res://scenes/actors/enemy/ciempies.tres", Vector2(90, 0), {})
	sala.poner("res://scenes/actors/enemy/ciempies.tres", Vector2(110, 90), {})
	await _esperar(25)
	var nodos: Array = get_tree().get_nodes_in_group("enemy")
	nodos[0].aplicar_mutacion(&"bicefalo", 0.0)
	nodos[1].aplicar_mutacion(&"nudo", 0.0)
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
	var bi: Combatant = null
	var nu: Combatant = null
	for e in combat._enemies:
		match e.mutacion:
			&"bicefalo": bi = e
			&"nudo": nu = e
	_ver(bi != null and nu != null, "en la pelea, los dos")
	if bi == null or nu == null:
		return
	var al: Array = combat._aliados_vivos()
	print("     aliados: %d" % al.size())
	var yo: Combatant = al[0]
	for a in al:
		a.current_hp = a.max_hp
		a.invulnerable = false
	var ps: Vector2 = tm.pies_de(yo)

	print("6) EL ENROSQUE DEL BICEFALO")
	_poner(tm, bi, ps + Vector2(30, 0))
	_poner(tm, nu, ps + Vector2(0, 300))
	_ver(tm.empezar_enrosque(bi, yo), "se enrosca")
	_ver(tm.presas_de(bi) == [yo] and tm.enrosque_de(bi) == yo and yo.enroscado() and bi.enroscado(), "una presa, y los dos Enroscados")
	bi.apply_status(StatusEffects.Id.ATURDIDO)
	tm._tick_enroscados()
	_ver(tm.enrosque_de(bi) == yo, "aturdir la cabeza LIBRE no suelta a la presa")
	_ver(bi.aviso_mentes == 2, "se avisa: una cabeza")
	tm._tick_avisos_mentes()
	_ver(bi.aviso_mentes == 0, "y el aviso se recoge")
	bi.apply_status(StatusEffects.Id.ATURDIDO)
	tm._tick_enroscados()
	_ver(tm.enrosque_de(bi) == null and not yo.enroscado() and not bi.enroscado(), "aturdir tambien la que aprieta, si")
	bi.statuses.clear()
	bi.tick_statuses()
	bi.tick_statuses()

	print("7) LA CABEZA LIBRE")
	if al.size() >= 2:
		var otro: Combatant = al[1]
		# (06/11) TODOS lejos, no solo 'otro', antes de nada: los demas aliados quedaban donde cayeran y, si uno caia cerca de la presa,
		# la cabeza libre lo tenia a tiro (fallaba 1 de cada pocas).
		for i in range(2, al.size()):
			_poner(tm, al[i], ps + Vector2(0, -200 - 60 * i))
		_poner(tm, otro, ps + Vector2(-40, 0))
		tm.empezar_enrosque(bi, yo)
		_ver(tm.a_tiro_de_la_libre(bi) == otro, "tiene a otro a tiro")
		var hp_o: float = otro.current_hp
		var hp_y: float = yo.current_hp
		for _k in 25:
			en._enemy_apretar_turno(bi)
			if otro.current_hp < hp_o:
				break
		_ver(yo.current_hp < hp_y, "aprieta a su presa")
		_ver(otro.current_hp < hp_o, "y la otra cabeza muerde al de al lado")
		var hp_o2: float = otro.current_hp
		bi.cabezas_este_turno = [false, true]
		for _k in 10:
			en._morder_con_la_libre(bi)
		_ver(is_equal_approx(otro.current_hp, hp_o2), "con esa cabeza dormida, no muerde")
		bi.cabezas_este_turno = [false, false]
		tm.soltar_enrosque(bi, "")
		_poner(tm, otro, ps + Vector2(0, -200))
		_ver(tm.empezar_enrosque(bi, yo) and tm.a_tiro_de_la_libre(bi) == null, "sin nadie a tiro, no hace nada")
		tm.soltar_enrosque(bi, "")

		print("8) EL NUDO: DOS PRESAS")
		_poner(tm, bi, ps + Vector2(0, 400))
		_poner(tm, nu, ps + Vector2(30, 0))
		_poner(tm, otro, ps + Vector2(-25, 0))
		_ver(tm.empezar_enrosque(nu, yo), "se enrosca")
		_ver(tm.presas_de(nu).size() == 2 and otro.enroscado() and yo.enroscado(), "atrapa a los dos que estan pegados")
		nu.apply_status(StatusEffects.Id.ATURDIDO)
		tm._tick_enroscados()
		_ver(tm.presas_de(nu) == [yo] and not otro.enroscado() and nu.enroscado(), "aturdir una cabeza suelta solo a SU presa")
		nu.statuses.clear()
		nu.apply_status(StatusEffects.Id.ENROSCADO)
		nu.cabezas_dormidas = [false, false]
		tm.soltar_enrosque(nu, "")
		_poner(tm, otro, ps + Vector2(-120, 0))
		tm.empezar_enrosque(nu, yo)
		_ver(tm.presas_de(nu) == [yo], "con el otro lejos, una sola")
		_ver(is_equal_approx(tm.mult_apreton(nu), 1.0), "el primer apreton, normal")
		for k in 8:
			tm.contar_apreton(nu)
		_ver(is_equal_approx(tm.mult_apreton(nu), 1.6), "aprieta mas con los turnos, hasta +60 %% (x%.2f)" % tm.mult_apreton(nu))
		_ver(is_equal_approx(tm.mult_apreton(bi), 1.0), "(el bicefalo no)")
		tm.soltar_enrosque(nu, "")
	else:
		print("     (solo un aliado: sin cabeza libre ni dos presas)")
		_ver(false, "hacen falta dos aliados para probar el resto")

	print("9) LA PINZA Y EL BASICO")
	var pinza: AbilityData = load("res://resources/abilities/ciempies_pinza.tres")
	bi.cabezas_este_turno = [false, false]
	_ver(bi.habilidades.has(pinza) or bi.habilidades.any(func(a): return a.nombre == "Pinza"), "lleva la Pinza")
	bi.cabezas_este_turno = [true, false]
	_ver(bi.una_cabeza_este_turno(), "con una dormida no la podra usar")
	bi.cabezas_este_turno = [false, false]
	_poner(tm, nu, ps + Vector2(0, 400))
	_poner(tm, bi, ps + Vector2(20, 0))
	var u: AbilityData = bi.basico_propio
	_ver(u != null and u.num_golpes(1) == 2, "el basico en U son dos golpes")
	_ver(bi.basico_una_cabeza != null and bi.basico_una_cabeza.num_golpes(1) == 1, "con una cabeza, uno")

	print("10) LOS SPRITES HORNEADOS")
	var sf_b: SpriteFrames = (tm.cuerpo_de(bi).get("_sprite") as AnimatedSprite2D).sprite_frames
	for base in ["idle", "walk", "basico_u", "pinza", "oleada", "enrosque", "libre_idle", "libre_muerde", "encaje", "muerte", "comer", "evolucion",
			"enroscarse_detras", "enroscado_delante", "apreton_detras", "desenroscarse_delante"]:
		_ver(sf_b.has_animation(StringName("%s_0" % base)), "bicefalo: %s" % base)
	_ver(not sf_b.has_animation(&"derrumbe_0"), "el bicefalo no se derrumba")
	var sf_n: SpriteFrames = (tm.cuerpo_de(nu).get("_sprite") as AnimatedSprite2D).sprite_frames
	for base in ["derrumbe_carga", "derrumbe", "enroscado_b_detras", "enroscado_b_delante", "evolucion"]:
		_ver(sf_n.has_animation(StringName("%s_0" % base)), "nudo: %s" % base)
	_ver(ResourceLoader.exists("res://assets/sprites/enemigos/ciempies3d_ciempies_sdf_nudo.png"), "el nudo sale del horno, no dibujado al vuelo")

	print("10b) LOS EFECTOS EN PIXEL ART")
	var arena_fx: Node = tm._arena()
	for nombre in ["tijera", "gancho_a", "gancho_b", "patitas", "apreton", "apreton_a", "apreton_b", "pinza", "derrumbe_carga", "derrumbe"]:
		var ef: EfectoPixel = EfectoPixel.lanzar(arena_fx, "ciempies", nombre, tm.pies_de(yo), 2)
		_ver(ef != null and ef.num_capas() >= 1, "la hoja %s carga" % nombre)
		if ef != null:
			ef.queue_free()
	await _esperar(2)
	var caja_fx := Rect2(tm.pies_de(yo) - Vector2(10, 30), Vector2(20, 30))
	var f_n = InsectoAire.sobre_cuerpo(arena_fx, InsectoAire.Modo.FORCIPULAS, tm.pies_de(yo) + Vector2(30, 0), caja_fx, 1, 0.1, 1.0, -1.0, 1.0, 0.0)
	_ver(f_n is EfectoPixel, "el basico del normal va en pixel")
	var f_p = InsectoAire.sobre_cuerpo(arena_fx, InsectoAire.Modo.PATITAS, tm.pies_de(yo) + Vector2(30, 0), caja_fx, 1, 0.1, 1.0, -1.0, 1.0, 0.0)
	_ver(f_p is EfectoPixel, "la Oleada tambien")
	var f_a = InsectoAire.sobre_cuerpo(arena_fx, InsectoAire.Modo.APRETON, tm.pies_de(yo) + Vector2(30, 0), caja_fx, 1, 0.1, 1.0, -1.0, 1.0, -1.0)
	_ver(f_a is EfectoPixel, "y el apreton")
	for n_fx in [f_n, f_p, f_a]:
		if is_instance_valid(n_fx):
			(n_fx as Node).queue_free()
	await _esperar(1)
	var contar_fx := func() -> int:
		return arena_fx.get_children().filter(func(n): return n is EfectoPixel).size()
	var antes_fx: int = contar_fx.call()
	tm.gesto_bicho_en_mapa(bi, &"pinza", 0.4)
	await _esperar(1)
	_ver(contar_fx.call() > antes_fx, "la Pinza saca su barrido")
	antes_fx = contar_fx.call()
	tm.gesto_bicho_en_mapa(nu, &"derrumbe", 0.4)
	await _esperar(1)
	_ver(contar_fx.call() > antes_fx, "el Derrumbe saca sus grietas")
	var nd: AbilityData = load("res://resources/abilities/ciempies_pinza.tres")
	_ver(nd.fx_estilo_mapa == 150, "a cada uno, el gancho de la cabeza de su mitad")

	print("11) COMO SE VE EL ENROSQUE")
	if al.size() >= 2:
		var otro: Combatant = al[1]
		_poner(tm, nu, ps + Vector2(30, 0))
		_poner(tm, otro, ps + Vector2(-25, 0))
		tm.empezar_enrosque(nu, yo)
		tm._tick_vis_enrosque()
		var v = tm._vis_enrosque.get(nu)
		_ver(v != null and (v["piezas"] as Array).size() == 2, "una helice por presa")
		if v != null:
			var sufijos: Array = (v["piezas"] as Array).map(func(p): return p["suf"])
			_ver(sufijos.has("") and sufijos.has("_b"), "cada una con su cabeza (%s)" % [sufijos])
			_ver(not is_instance_valid(v["libre"]), "con dos presas, no queda nada libre")
			_ver(not (v["sp"] as CanvasItem).visible, "su cuerpo de siempre se esconde")
		tm.soltar_enrosque(nu, "")
		tm._tick_vis_enrosque()
		_ver(tm._vis_enrosque.has(nu) and bool(tm._vis_enrosque[nu]["piezas"][0]["sale"]), "al soltar se desenrosca")
		tm._quitar_vis_enrosque(nu)
		_poner(tm, nu, ps + Vector2(0, 400))
		_poner(tm, bi, ps + Vector2(30, 0))
		tm.empezar_enrosque(bi, yo)
		tm._tick_vis_enrosque()
		var vb = tm._vis_enrosque.get(bi)
		_ver(vb != null and is_instance_valid(vb["libre"]), "el bicefalo: la helice y la parte libre con la otra cabeza")
		if vb != null:
			tm.morder_vis_libre(bi, otro)
			_ver(String((vb["libre"] as AnimatedSprite2D).animation).begins_with("libre_muerde"), "la parte libre muerde")
		tm.soltar_enrosque(bi, "")
		tm._quitar_vis_enrosque(bi)
