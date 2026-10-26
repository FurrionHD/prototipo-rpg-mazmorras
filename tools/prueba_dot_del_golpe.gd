# EL SANGRADO Y EL FUEGO DEL GOLPE REAL (10/10, playtest del 09/10: "aunque la armadura reduzca el daño que recibo los
# sangrados hacen daño fijo... en el minotauro mete un daño que no tiene ningun puto sentido"). Sin ventana:
#   1) la cuenta: tras encajar un golpe de 20, sangrado 15 % (3) y fuego 30 % (6); al fotograma siguiente ya no cuenta;
#   2) la Cornada del Minotauro de verdad: el sangrado que deja es el 15 % de lo que le ha quitado ESE golpe, y con mas
#      armadura (el golpe entra menos) sangra menos.
#   godot --headless --path . res://tools/prueba_dot_del_golpe.tscn
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


func _correr() -> void:
	print("1) la cuenta")
	var c := Combatant.new("Prueba", 1, Abilities.new(), 1000.0, 10.0, 10.0, 10.0)
	c.max_hp = 1000.0
	c.current_hp = 1000.0
	c.take_damage(20.0)
	_ver(is_equal_approx(c.golpe_de_ahora(), 20.0), "apunta el golpe de 20 (%.2f)" % c.golpe_de_ahora())
	var s: float = StatusEffects.magnitud_del_golpe(StatusEffects.Id.SANGRADO, c)
	var q: float = StatusEffects.magnitud_del_golpe(StatusEffects.Id.QUEMADURA, c)
	_ver(is_equal_approx(s, 20.0 * StatusEffects.SANGRADO_FRACCION_GOLPE), "sangrado %.2f por turno (15 %%)" % s)
	_ver(is_equal_approx(q, 20.0 * StatusEffects.QUEMADURA_FRACCION), "fuego %.2f por turno (30 %%)" % q)
	c.take_damage(5.0, true)
	_ver(is_equal_approx(c.golpe_de_ahora(), 20.0), "un DoT no cuenta como golpe")
	await _esperar(2)
	_ver(c.golpe_de_ahora() < 0.0, "al fotograma siguiente ya no hay golpe (una pasiva sale del ataque, como antes)")

	print("2) la Cornada de verdad")
	# EN SU SALA (etapa 4, 26/10): la prueba es la sala y la pelea se abre por donde la abre ella.
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_dot_del_golpe", Game.PISO_ARENA):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	sala.poner("res://scenes/actors/enemy/guardian_rango.tres", Vector2(-220, 70), {})
	await _esperar(25)
	if not (await sala.pelear(get_tree().get_nodes_in_group("enemy"), false) != null):
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	var combat: Node = null
	await _esperar(5)
	for n in get_tree().root.get_children() + sala.capas():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	var t = combat.turno_mapa
	if not await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 20.0):
		print("MAL: no llego un turno de los tuyos")
		get_tree().quit(1)
		return
	var al: Array = combat._aliados
	var e: Combatant = combat._enemies[0]
	e.max_hp = 99999.0
	e.current_hp = 99999.0
	e.base_attack *= 40.0   # que pegue de verdad (en la arena es de piso 1): si no, manda el suelo de 0,5
	var cor: AbilityData = load("res://resources/abilities/minotauro_cornada.tres")
	var v: Combatant = al[0]
	v.max_hp = 99999.0
	var resultados: Array = []
	# SIN CRITICOS (15/10): un critico con 60 % de armadura pegaba mas que uno normal sin ella (34.92 > 31.80) y la
	# comparacion de abajo fallaba a veces. Se fuerza aqui y se devuelve al acabar, igual que la esquiva.
	var crit_antes: float = e.crit_bonus
	var evasion_antes: float = v.evasion_bonus
	e.crit_bonus = -5.0
	for armadura in [0.0, 0.6]:
		var visto: bool = false
		for _intento in 12:
			v.current_hp = 99999.0
			v.statuses.clear()
			v.evasion_bonus = -5.0   # que no lo esquive
			v.armor_reduction = armadura
			var pe: Vector2 = t.pies_de(e)
			var borde: float = t._hasta_el_borde(pe, Vector2.RIGHT, t.bulto_de(e))
			t._colocar(v, t.cuerpo_de(v), pe + Vector2(borde + 30, 0) - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
			for k in range(1, al.size()):
				t._colocar(al[k], t.cuerpo_de(al[k]), pe + Vector2(-200 - 40 * k, -150) - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
			await _esperar(2)
			var hp0: float = v.current_hp
			combat.enemigos._enemy_use_ability(e, cor, v)
			var golpe: float = hp0 - v.current_hp
			var sang: float = -1.0
			for st in v.statuses:
				if st.id() == StatusEffects.Id.SANGRADO:
					sang = st.magnitude
			await _esperar(90)
			if golpe > 0.0 and sang > 0.0:
				print("     armadura %.0f %%: golpe %.2f -> sangrado %.2f por turno (%.0f %%)" % [armadura * 100.0, golpe, sang, sang / golpe * 100.0])
				_ver(absf(sang - golpe * StatusEffects.SANGRADO_FRACCION_GOLPE) < 0.02, "el sangrado es el 15 % del golpe real")
				resultados.append(sang)
				visto = true
				break
		_ver(visto, "la Cornada le ha hecho sangrar (armadura %.0f %%)" % (armadura * 100.0))
	e.crit_bonus = crit_antes
	v.evasion_bonus = evasion_antes
	if resultados.size() == 2:
		_ver(resultados[1] < resultados[0], "con mas armadura sangra menos (%.2f < %.2f)" % [resultados[1], resultados[0]])
	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)
