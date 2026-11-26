# PRUEBA (26/11): EL ESTOQUE CON RODELA, en una pelea tactica de verdad en su sala. Todos los tuyos con estoque y escudo
# pequeño, tres enemigos en fila delante de quien tenga el turno (cada seccion los vuelve a colocar):
#   AVANCE CUBIERTO   corre hasta el primero, rodelazo + estocada, en guardia; Rodelazo que aturde, Abrirle la guardia
#                     (la estocada critica), Peso de la carrera, Arrollar (el rodelazo a toda la linea), Reto, Escudo que
#                     devuelve, Llegar cubierto (la guardia aguanta tu turno siguiente), Estocada doble
#   EN GUARDIA        con rodela: la postura Y el escudo arriba
#   godot --headless --path . res://tools/prueba_avance_cubierto.tscn
extends Node

const Mejoras = preload("res://scripts/core/mejoras.gd")
const AVANCE := "res://resources/abilities/avance_cubierto.tres"

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


func _montar(ids: Array) -> AbilityData:
	var base: AbilityData = load(AVANCE)
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
	if not await sala.arrancar("ver_avance_cubierto" if OS.get_environment("AVANCE_VER") != "" else "prueba_avance_cubierto", Game.PISO_ARENA):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	# todos con estoque y rodela (la guardia de la rodela mira lo que lleva cada uno)
	for pj in [Game.lider()] + Game.companeros():
		pj.equipped_main = load("res://resources/weapons/estoque.tres")
		pj.equipped_off = load("res://resources/shields/escudo_pequeno.tres")
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
	# AVANCE_VER=1 (con ventana): sin comprobar nada, lo lanza unas veces para VERLO y apunta cuando llega cada cosa.
	if OS.get_environment("AVANCE_VER") != "":
		await _ver_en_vivo()
		get_tree().quit(0)
		return
	await _avance()
	await _guardia_rodela()
	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)


func _avance() -> void:
	print("--- AVANCE CUBIERTO")
	for c in combat._aliados:
		var pj: PersonajeData = Game.pj_de_combatant(c)
		print("    %s: nivel %d, atk %.1f, atk_escudo %.1f (def %.1f + escudo %.1f), arma %s" % [c.nombre, c.level, c.atk(),
			c.atk_escudo(), c.def_value(), c.defend_defense, pj.equipped_main.nombre if pj != null and pj.equipped_main != null else "?"])
	print("    enemigo: def %.1f" % es[0].def_value())
	# DE SERIE: corre hasta el primero, le entran los dos golpes (rodelazo y estocada) y al de detras nada; en guardia.
	var yo: Combatant = await _turno()
	await _colocar(yo, [60.0, 95.0, 130.0])
	var sitio: Vector2 = t.pies_de(yo)
	var ab: AbilityData = _montar([])
	ab.infalible = true
	ab.efectos_prob_de = {7: 10.0}   # (el aturdido, al techo del 95 %)
	var hp0: Array = es.map(func(e): return e.current_hp)
	_lanzar(ab, t.pies_de(es[2]))
	await _esperar_a(func() -> bool: return t._deslices.is_empty(), 10.0)
	var corrio: float = (t.pies_de(yo) - sitio).dot(lado)
	print("    corre %.0f px (el primero estaba a %.0f); carrera %.2f" % [corrio, (t.pies_de(es[0]) - sitio).dot(lado),
		combat.habilidades._carrera_hab])
	_ver(corrio > 30.0, "corre hacia el primero")
	_ver(es[0].current_hp < float(hp0[0]) and is_equal_approx(es[1].current_hp, float(hp0[1])),
		"le pega al primero y al de detras no")
	_ver(combat.habilidades._abiertos_escudo.has(es[0]), "el rodelazo le entra (golpe de escudo)")
	_ver(bool(combat._defendiendo.get(yo, false)), "y quedas en guardia")
	# (la prob de un estado tiene techo del 95 %: si no entra, otra vez, hasta tres)
	var aturdio: bool = es[0].get_status(StatusEffects.Id.ATURDIDO) != null
	for _r in 2:
		if aturdio:
			break
		var yo_r: Combatant = await _turno()
		await _colocar(yo_r, [60.0, 95.0, 130.0])
		_lanzar(ab, t.pies_de(es[2]))
		aturdio = es[0].get_status(StatusEffects.Id.ATURDIDO) != null
	_ver(aturdio, "Rodelazo: aturde")
	_ver(combat.habilidades._carrera_hab > 0.2, "Peso de la carrera: mide lo que corres")

	# ABRIRLE LA GUARDIA: sin critico propio (-5), la estocada critica igual si el rodelazo entro. Se cuenta con la
	# energia por critico (Respiracion de las Fintas): uno = solo la estocada.
	yo = await _turno()
	await _colocar(yo, [40.0, 95.0, 130.0])
	var ag: AbilityData = _montar(["carrera_larga", "abrir_guardia"])
	ag.infalible = true
	ag.crit_extra = -5.0
	ag.energia_por_critico = 0.1
	yo.current_energy = 500.0
	var coste: float = yo.coste_hab(ag, 1)
	_lanzar(ag, t.pies_de(es[2]))
	print("    criticos: %d" % combat.habilidades.criticos_ultima)
	_ver(combat.habilidades.criticos_ultima == 1, "Abrirle la guardia: la estocada critica (y el rodelazo no)")
	yo = await _turno()
	await _colocar(yo, [40.0, 95.0, 130.0])
	var sin: AbilityData = _montar(["carrera_larga"])
	sin.infalible = true
	sin.crit_extra = -5.0
	sin.energia_por_critico = 0.1
	yo.current_energy = 500.0
	coste = yo.coste_hab(sin, 1)
	_lanzar(sin, t.pies_de(es[2]))
	_ver(combat.habilidades.criticos_ultima == 0, "y sin el nodo, ningun critico")

	# ARROLLAR: el rodelazo a los tres de la linea; la estocada, al primero. RETO: el que se lleva golpe, a por ti.
	yo = await _turno()
	await _colocar(yo, [40.0, 75.0, 110.0])
	var ar: AbilityData = _montar(["rodelazo_aturde", "arrollar"])
	ar.infalible = true
	ar.crit_extra = -5.0
	ar.escudo_abre_critico = true   # cada estocada critica: un critico = la estocada a uno solo
	hp0 = es.map(func(e): return e.current_hp)
	_lanzar(ar, t.pies_de(es[2]))
	var pegados: int = range(3).filter(func(i): return es[i].current_hp < float(hp0[i])).size()
	print("    Arrollar pega a %d" % pegados)
	_ver(pegados == 3, "Arrollar: el rodelazo a todos los de la linea")
	print("    criticos: %d" % combat.habilidades.criticos_ultima)
	_ver(combat.habilidades.criticos_ultima == 1, "y la estocada solo al primero")

	yo = await _turno()
	await _colocar(yo, [40.0, 95.0, 130.0])
	var re: AbilityData = _montar(["rodelazo_aturde", "retar", "escudo_devuelve", "llegar_cubierto"])
	re.infalible = true
	_lanzar(re, t.pies_de(es[2]))
	_ver(yo.provocar_turnos == 2 and yo.provocados.has(es[0]) and not yo.provocados.has(es[1]),
		"Reto: el que chocas va a por ti 2 turnos (y los demas no)")
	cerca_bien(yo.escudo_contra_extra, 0.35, "Escudo que devuelve: +35 % hasta tu turno")
	_ver(yo.guardia_turnos_quedan == 1, "Llegar cubierto: un turno de guardia de mas")
	var yo_antes: Combatant = yo
	# su siguiente turno: sigue en guardia (y lo de devolver se acaba). Los demas de los tuyos, que defiendan y pasen.
	var llego: bool = false
	var empezados: Array = []
	combat.turno_empieza.connect(func(c): if c == yo_antes: empezados.append(c.aturdido()))
	for _k in 16:
		await _esperar_a(func() -> bool: return combat._fx == null or not combat._fx.ocupado(), 10.0)
		await _esperar_a(func() -> bool: return t._deslices.is_empty(), 5.0)
		if not await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 30.0):
			break
		print("    turno de %s; %s en guardia: %s (quedan %d); turnos suyos empezados (aturdido?): %s" % [combat._player.nombre,
			yo_antes.nombre, str(combat._defendiendo.get(yo_antes, false)), yo_antes.guardia_turnos_quedan, str(empezados)])
		if combat._player == yo_antes:
			llego = true
			break
		combat._state = combat.State.WAITING_PLAYER
		combat._accion_defender()
	if llego and empezados.size() > 1:
		# un aturdido le comio un turno: ese turno ya gasto el de guardia de mas (es lo que tiene que pasar)
		_ver(true, "Llegar cubierto: un aturdido le comio el turno de mas (no se mira la guardia)")
		_ver(is_zero_approx(yo_antes.escudo_contra_extra), "y Escudo que devuelve ya se acabo")
	elif llego:
		_ver(bool(combat._defendiendo.get(yo_antes, false)), "Llegar cubierto: en tu turno siguiente sigues en guardia")
		_ver(is_zero_approx(yo_antes.escudo_contra_extra), "y Escudo que devuelve ya se acabo")
	elif empezados.has(true):
		_ver(true, "Llegar cubierto: un aturdido le comio el turno de mas (no se mira la guardia)")
	else:
		_ver(false, "Llegar cubierto: no volvio su turno")

	# ESTOCADA DOBLE: tres golpes (rodelazo y dos estocadas).
	yo = await _turno()
	await _colocar(yo, [40.0, 95.0, 130.0])
	var dob: AbilityData = _montar(["carrera_larga", "peso_carrera", "doble_estocada"])
	dob.infalible = true
	dob.crit_extra = -5.0
	dob.escudo_abre_critico = true   # cada estocada critica: dos criticos = dos estocadas
	dob.energia_por_critico = 0.1
	yo.current_energy = 500.0
	coste = yo.coste_hab(dob, 1)
	_lanzar(dob, t.pies_de(es[2]))
	print("    criticos: %d" % combat.habilidades.criticos_ultima)
	_ver(combat.habilidades.criticos_ultima == 2, "Estocada doble: dos estocadas tras el rodelazo")


func cerca_bien(v: float, esperado: float, que: String) -> void:
	_ver(absf(v - esperado) < 0.0001, que)


func _guardia_rodela() -> void:
	print("--- EN GUARDIA CON RODELA")
	var yo: Combatant = await _turno()
	await _colocar(yo, [40.0, 95.0, 130.0])
	var pool: Array = Game.pool_habilidades(Game.pj_de_combatant(yo))
	_ver(pool.has(load("res://resources/abilities/en_guardia.tres")), "con rodela sale En guardia")
	_ver(not pool.has(load("res://resources/abilities/postura_rodela.tres")), "y la Postura de rodela no")
	combat._defendiendo.erase(yo)
	combat._state = combat.State.WAITING_PLAYER
	combat.habilidades._usar_habilidad(load("res://resources/abilities/en_guardia.tres"), true)
	_ver(yo.en_guardia, "en guardia (la del estoque)")
	_ver(bool(combat._defendiendo.get(yo, false)), "y con la rodela arriba")
	_ver(not yo.guardia_contra_escudo, "la contra al esquivar es la estocada, no el escudazo")


func _ver_en_vivo() -> void:
	var t_av: int = 0
	combat._fx.gesto_iniciado.connect(func(_b, _d, dur, anim, _m) -> void:
		print("    gesto %s a %.2f s (dura %.2f)" % [anim, (Time.get_ticks_msec() - t_av) / 1000.0, dur]))
	for k in int(OS.get_environment("AVANCE_VECES")) if OS.get_environment("AVANCE_VECES") != "" else 4:
		var yo: Combatant = await _turno()
		if yo == null:
			return
		await _colocar(yo, [70.0, 110.0, 150.0])
		await get_tree().create_timer(0.8).timeout
		t_av = Time.get_ticks_msec()
		var sitio: Vector2 = t.pies_de(yo)
		_lanzar(_montar([]), t.pies_de(es[2]))
		await _esperar_a(func() -> bool: return t._deslices.is_empty(), 5.0)
		print("  [%d] llega a los %.2f s (corrio %.0f px)" % [k, (Time.get_ticks_msec() - t_av) / 1000.0,
			t.pies_de(yo).distance_to(sitio)])
		await _esperar_a(func() -> bool: return combat._fx == null or not combat._fx.ocupado(), 10.0)
		print("  [%d] acaba todo a los %.2f s" % [k, (Time.get_ticks_msec() - t_av) / 1000.0])
		await get_tree().create_timer(1.0).timeout
