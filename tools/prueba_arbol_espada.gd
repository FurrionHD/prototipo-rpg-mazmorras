# PRUEBA (26/11): LAS MECANICAS NUEVAS DE LOS ARBOLES DE LA ESPADA CORTA, en una pelea tactica de verdad en su sala:
#   Arrodillar, Presteza del Cambio de ritmo, Aprovechar el hueco, A por el, Caza, y los GANCHOS (26/11): Furia de filo,
#   Remate en cruz, Ojo de duelista, Orden de ataque, Sin poder curarse, Presa facil.
#   godot --headless --path . res://tools/prueba_arbol_espada.tscn
extends Node

const Mejoras = preload("res://scripts/core/mejoras.gd")
const HAB := "res://resources/abilities/%s.tres"

var sala
var combat: Node = null
var t = null
var es: Array = []
var lado := Vector2.LEFT
var centro := Vector2.ZERO
var _mal := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _esperar_a(cond: Callable, tope_s: float) -> bool:
	var t0: int = Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > tope_s * 1000.0:
			return false
		await get_tree().process_frame
	return true


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _montar(hab: String, ids: Array) -> AbilityData:
	var base: AbilityData = load(HAB % hab)
	return Mejoras.montar_sin_nombre(base, (base.arbol as Array).filter(func(n): return ids.has(String(n.id)))) as AbilityData


func _turno() -> Combatant:
	await _esperar_a(func() -> bool: return combat._fx == null or not combat._fx.ocupado(), 10.0)
	await _esperar_a(func() -> bool: return t._deslices.is_empty(), 5.0)
	if not await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 30.0):
		print("MAL: no llego un turno de los tuyos")
		return null
	var yo: Combatant = combat._player
	yo.max_energy = 1000.0
	yo.current_energy = 1000.0
	yo.salir_de_guardia()
	yo.statuses.clear()
	return yo


# 'yo' en el centro y los tres enemigos en fila hacia 'lado', a 'seps' px de hueco del cuerpo de 'yo'.
func _colocar(yo: Combatant, seps: Array) -> void:
	t._colocar(yo, t.cuerpo_de(yo), centro - Vector2(0, PoseJugador.PIES_BAJO_NODO))
	for i in 3:
		var e: Combatant = es[i]
		var pe: Vector2 = centro + lado * (t.radio_pisa(yo) + t.radio_pisa(e) + float(seps[i]))
		t._colocar(e, t.cuerpo_de(e), pe - (t.pies_de(e) - t.pos_de(e)))
		if not e.is_alive():
			continue   # (el que tumbo Caza: rellenarle la vida lo "resucitaria" fuera del orden de turnos)
		e.statuses.clear()
		e.current_hp = e.max_hp
		e.en_guardia = false
	await _esperar(3)


func _lanzar(ab: AbilityData, punto: Vector2) -> void:
	combat._state = combat.State.WAITING_PLAYER
	t.anotar_apunte([punto.x, punto.y])
	combat.habilidades._usar_habilidad(ab, true)


func _correr() -> void:
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_arbol_espada", Game.PISO_ARENA):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	# todos con estoque y rodela (la guardia de la rodela mira lo que lleva cada uno)
	for pj in [Game.lider()] + Game.companeros():
		pj.equipped_main = load("res://resources/weapons/espada_corta.tres")
		pj.equipped_off = null
	for i in 3:
		sala.poner("res://scenes/actors/enemy/guardian_rango.tres", Vector2(-220 - 40 * i, 70), {})
	await _esperar(25)
	if not (await sala.pelear(get_tree().get_nodes_in_group("enemy"), false) != null):
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	await _esperar(5)
	for n in get_tree().root.get_children() + sala.capas():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	if combat == null or not combat.tactico or combat._enemies.size() < 3:
		print("MAL: la pelea no es tactica o no estan los tres")
		get_tree().quit(1)
		return
	t = combat.turno_mapa
	es = combat._enemies.slice(0, 3)
	for c in combat._aliados + es:
		c.max_hp = 9999999.0
		c.current_hp = 9999999.0
	centro = t._arena().rect.get_center()
	lado = Vector2.LEFT if t._en_arena(centro + Vector2(-200, 0)) else Vector2.RIGHT
	for i in combat._aliados.size():
		var o: Combatant = combat._aliados[i]
		t._colocar(o, t.cuerpo_de(o), centro - lado * 160.0 + Vector2(0, -60 + 50 * i) - Vector2(0, PoseJugador.PIES_BAJO_NODO))
	await _quebrantador()
	await _tendones()
	await _ritmo()
	await _senalar()
	await _doble()   # (al final: el Remate en cruz tumba a uno)
	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)


func _quebrantador() -> void:
	print("--- TAJO QUEBRANTADOR")
	# APROVECHAR EL HUECO: energia por cada uno al que le entra el Vulnerable.
	var yo: Combatant = await _turno()
	await _colocar(yo, [8.0, 14.0, 20.0])
	# (contra la misma SIN el nodo: el resto de lo que se recupera al usarla es igual en las dos)
	var ganada: Array = []
	var vulns: Array = []
	for con_nodo in [false, true]:
		if con_nodo:   # el MISMO personaje (cada uno recupera distinto al pegar), con los enemigos como estaban
			await _esperar_a(func() -> bool: return combat._fx == null or not combat._fx.ocupado(), 10.0)
			await _colocar(yo, [8.0, 14.0, 20.0])
			combat._player = yo
		# (las dos CON el nodo, que trae tambien su parte de daño, y la energia que se recupera al pegar va con el daño:
		# en la primera, su efecto apagado)
		var ab: AbilityData = _montar("tajo_quebrantador", ["barrido_ancho", "abrir_a_todos", "aprovechar_hueco"])
		if not con_nodo:
			ab.energia_por_estado = 0.0
		ab.infalible = true
		ab.efectos_prob_mult = 10.0
		ab.cooldown = 0
		yo.current_energy = 300.0
		var coste: float = yo.coste_hab(ab, 1)
		_lanzar(ab, t.pies_de(es[1]))
		vulns.append(es.filter(func(e): return e.has_status(StatusEffects.Id.VULNERABLE)).size())
		ganada.append(yo.current_energy - (300.0 - coste))
	var de_mas: float = float(ganada[1]) - float(ganada[0])
	print("    Vulnerables %d, energia de mas con el nodo %.1f (5 %% de %.0f por cada uno)" % [vulns[1], de_mas, yo.max_energy])
	_ver(int(vulns[1]) > 0 and absf(de_mas - 0.05 * yo.max_energy * int(vulns[1])) < 1.0, "Aprovechar el hueco: 5 %% de energia por Vulnerable")


func _tendones() -> void:
	print("--- CORTE DE TENDONES")
	# ARRODILLAR: al que ya iba Lento, atras en la barra; al que no, nada. TAJO A LAS PIERNAS: al Lento, Cojera.
	var yo: Combatant = await _turno()
	await _colocar(yo, [8.0, 14.0, 20.0])
	es[0].apply_status(StatusEffects.Id.LENTO, 3)
	var ab: AbilityData = _montar("corte_de_tendones", ["barrido_bajo", "asegurar_corte", "arrodillar"])
	ab.infalible = true
	var barra0: Array = es.map(func(e): return float(combat._gauge.get(e, 0.0)))
	_lanzar(ab, t.pies_de(es[1]))
	var barra1: Array = es.map(func(e): return float(combat._gauge.get(e, 0.0)))
	print("    barras antes %s, despues %s" % [str(barra0), str(barra1)])
	_ver(float(barra1[0]) > float(barra0[0]) + 1.0, "Arrodillar: el que iba Lento, atras en la barra")
	_ver(absf(float(barra1[1]) - float(barra0[1])) < 1.0, "y el que no, igual")
	# PRESA FACIL: los que deja Lentos dan critico a todos contra los Lentos, +5 por cada uno (hasta +20).
	yo = await _turno()
	await _colocar(yo, [8.0, 14.0, 20.0])
	var pf: AbilityData = _montar("corte_de_tendones", ["brazo_largo_t", "al_que_cojea", "presa_facil"])
	pf.infalible = true
	pf.efectos_prob_mult = 10.0
	_lanzar(pf, t.pies_de(es[1]))
	var lentos: int = es.filter(func(e): return e.has_status(StatusEffects.Id.LENTO)).size()
	var otro: Combatant = combat._aliados[(combat._aliados.find(yo) + 1) % combat._aliados.size()]
	var extra: float = StatsMath.critico_espada(otro, es[0])
	print("    Lentos %d, critico de mas de un compañero contra uno de ellos: %.2f" % [lentos, extra])
	_ver(lentos > 0 and absf(extra - minf(0.20, 0.05 * lentos)) < 0.001, "Presa facil: +5 de critico por cada Lento, para todos")
	# SIN PODER CURARSE: con la Herida profunda del nodo, curarle le hace daño (la mitad).
	yo = await _turno()
	await _colocar(yo, [8.0, 14.0, 20.0])
	var sc: AbilityData = _montar("corte_de_tendones", ["barrido_bajo", "sin_curarse"])
	sc.infalible = true
	sc.efectos_prob_mult = 10.0
	_lanzar(sc, t.pies_de(es[1]))
	var herido: Combatant = null
	for e in es:
		if e.has_status(StatusEffects.Id.HERIDA_PROFUNDA):
			herido = e
	if herido == null:
		_ver(false, "Sin poder curarse: no entro la Herida profunda")
	else:
		var hp_h: float = herido.current_hp
		herido.heal(1000.0)
		print("    curarle 1000: %.0f -> %.0f" % [hp_h, herido.current_hp])
		_ver(absf((hp_h - herido.current_hp) - 500.0) < 1.0, "Sin poder curarse: la cura le hace la mitad de daño")


func _doble() -> void:
	print("--- DOBLE TAJO")
	# FURIA DE FILO: una carga por cada enemigo de mas al que le entra.
	var yo: Combatant = await _turno()
	await _colocar(yo, [8.0, 14.0, 20.0])
	var fu: AbilityData = _montar("doble_tajo", ["mas_tajos", "abanico_d", "furia_filo"])
	fu.infalible = true
	_lanzar(fu, t.pies_de(es[1]))
	var furia = yo.get_status(StatusEffects.Id.FURIA_FILO)
	var golpeados: int = es.filter(func(e): return e.is_alive() and e.current_hp < e.max_hp).size()
	print("    golpeados %d, cargas de Furia %d" % [golpeados, furia.stacks if furia != null else 0])
	_ver(furia != null and int(furia.stacks) == golpeados - 1, "Furia de filo: una carga por enemigo de mas")
	# REMATE EN CRUZ: el ultimo tajo tumba al de delante y sale otro al mas cercano.
	yo = await _turno()
	await _colocar(yo, [300.0, 8.0, 20.0])
	# el tercero, A UN LADO (fuera del cono estrecho de abajo) pero a tiro del Doble tajo
	t._colocar(es[2], t.cuerpo_de(es[2]), t.pos_de(es[2]) + lado.orthogonal() * 40.0)
	await _esperar(2)
	es[1].current_hp = 1.0
	var rc_ab: AbilityData = _montar("doble_tajo", ["tercer_tajo", "remate_combo"])
	rc_ab.infalible = true
	rc_ab.golpes_min = 1
	rc_ab.golpes_max = 1
	rc_ab.golpes_si_uno = 0
	rc_ab.forma_apertura = 20.0   # (que el cono solo pille al de delante)
	var hp2: float = es[2].current_hp
	t.anotar_apunte([t.pies_de(es[1]).x, t.pies_de(es[1]).y])
	print("    pilla a %d" % t.reparto_habilidad(rc_ab, yo).size())
	_lanzar(rc_ab, t.pies_de(es[1]))
	_ver(not es[1].is_alive() and es[2].current_hp < hp2, "Remate en cruz: tumba al primero y le da al mas cercano")


func _ritmo() -> void:
	print("--- CAMBIO DE RITMO")
	var yo: Combatant = await _turno()
	await _colocar(yo, [20.0, 160.0, 200.0])
	var ab: AbilityData = _montar("cambio_de_ritmo", ["encadenar_r", "ancho_r", "esquivar_cruzar", "presteza_r"])
	_lanzar(ab, t.pies_de(yo) + lado * 120.0)
	_ver(yo.has_status(StatusEffects.Id.PRESTEZA), "Presteza: al usarla, Presteza")
	_ver(yo.descuento_hab > 0.0, "Encadenar: la siguiente, mas barata")


func _senalar() -> void:
	print("--- SEÑALAR EL HUECO")
	# OJO DE DUELISTA: quien marca, +15 de critico contra su marcado (los demas, no). ORDEN DE ATAQUE: sin sigilo ni capas.
	var yo: Combatant = await _turno()
	await _colocar(yo, [8.0, 160.0, 200.0])
	var oj: AbilityData = _montar("senalar_el_hueco", ["marca_honda", "ojo_duelista"])
	oj.efectos_prob_mult = 10.0
	oj.infalible = true
	_lanzar(oj, t.pies_de(es[0]))
	var otro_s: Combatant = combat._aliados[(combat._aliados.find(yo) + 1) % combat._aliados.size()]
	_ver(absf(StatsMath.critico_espada(yo, es[0]) - 0.15) < 0.001 and is_zero_approx(StatsMath.critico_espada(otro_s, es[0])),
		"Ojo de duelista: +15 de critico contra su marcado, solo para quien marco")
	yo = await _turno()
	await _colocar(yo, [8.0, 160.0, 200.0])
	es[0].statuses.clear()
	es[0].apply_status(StatusEffects.Id.SIGILO, 3)
	es[0].apply_status(StatusEffects.Id.ESQUIVO, 3)
	var orden: AbilityData = _montar("senalar_el_hueco", ["marca_larga", "orden_ataque"])
	orden.efectos_prob_mult = 10.0
	orden.infalible = true
	_lanzar(orden, t.pies_de(es[0]))
	_ver(es[0].has_status(StatusEffects.Id.MARCA) and not es[0].has_status(StatusEffects.Id.SIGILO),
		"Orden de ataque: el marcado pierde el sigilo")
	_ver(StatsMath.capas_validas(es[0]).is_empty() and not es[0].capas_esquiva().is_empty(),
		"y no le valen sus capas de esquiva")
	# A POR EL: marcado con el nodo, el golpe de OTRO de los tuyos le devuelve energia; CAZA: cae y la habilidad, lista.
	await _colocar(yo, [8.0, 160.0, 200.0])
	var ap: AbilityData = _montar("senalar_el_hueco", ["marca_larga", "a_por_el", "sin_fallo", "caza"])
	ap.efectos_prob_mult = 10.0
	_lanzar(ap, t.pies_de(es[0]))
	_ver(es[0].has_status(StatusEffects.Id.MARCA), "la Marca entra")
	var otro: Combatant = null
	for al in combat._aliados:
		if al != yo:
			otro = al
	if otro != null:
		otro.current_energy = 100.0
		var r := {"evaded": false, "damage": 10.0, "crit": false}
		combat._aplicar_pasivas(r, otro, es[0])
		_ver(otro.current_energy > 100.0, "A por el: el compañero que le pega recupera energia")
		yo.current_energy = 100.0
		combat._aplicar_pasivas(r, yo, es[0])
		_ver(is_equal_approx(yo.current_energy, 100.0), "y el que marco, no")
	# CAZA: con Señalar en espera, el marcado cae de un golpe (suyo) y la habilidad vuelve a estar lista.
	yo.ability_cooldowns[ap] = 5
	es[0].current_hp = 1.0
	var mata: AbilityData = _montar("doble_tajo", [])
	mata.infalible = true
	_lanzar(mata, t.pies_de(es[0]))
	await _esperar_a(func() -> bool: return combat._fx == null or not combat._fx.ocupado(), 10.0)
	await _esperar(10)
	print("    el marcado %s; espera de Señalar: %s" % ["ha caido" if not es[0].is_alive() else "sigue en pie",
		str(yo.ability_cooldowns.get(ap, 0))])
	_ver(not es[0].is_alive() and int(yo.ability_cooldowns.get(ap, 0)) == 0, "Caza: cae el marcado y Señalar, lista")
