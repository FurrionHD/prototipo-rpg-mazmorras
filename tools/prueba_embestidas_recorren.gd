# LAS EMBESTIDAS RECORREN SU LINEA (10/10, playtest del 09/10: "el minotauro no se desplaza con la embestida", "no da
# tiempo a ver la animacion", "se desplazara de todas formas aunque no haya nadie dentro"). Con la Cornada del Minotauro:
#   1) sin nadie en la linea: se mueve igual, hasta el final de su raya, y tarda lo que dice SueloRoto.V_EMBESTIDA;
#   2) con dos en la linea: les pega a los DOS, a cada uno cuando su frente le pasa, los aparta a un lado y acaba al final;
#   3) la de UN objetivo (la Yugular del rey rata) se para en el primero;
#   4) las que no pillan a nadie se ven igual: el Reventon salta y cae en su sitio, la Llamarada y las raices del Trent
#      lanzan su efecto por el suelo.
#   godot --headless --path . res://tools/prueba_embestidas_recorren.tscn
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
	# EN SU SALA (etapa 4, 26/10): la prueba es la sala y la pelea se abre por donde la abre ella.
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_embestidas_recorren", Game.PISO_ARENA):
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
	if combat == null or not combat.tactico:
		print("MAL: la pelea no es tactica")
		get_tree().quit(1)
		return
	var t = combat.turno_mapa
	if not await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 20.0):
		print("MAL: no llego un turno de los tuyos")
		get_tree().quit(1)
		return
	var al: Array = combat._aliados
	if al.size() < 2 or combat._enemies.is_empty():
		print("MAL: hacen falta dos de los tuyos y el minotauro")
		get_tree().quit(1)
		return
	for a in al:
		a.max_hp = 99999.0
		a.current_hp = 99999.0
	var e: Combatant = combat._enemies[0]
	e.max_hp = 99999.0
	e.current_hp = 99999.0
	var cor: AbilityData = load("res://resources/abilities/minotauro_cornada.tres")
	var ritmo: float = combat._fx.escala_tiempo if combat._fx != null else 1.0
	print("ritmo de la pelea x%.2f, V_EMBESTIDA %.0f px/s" % [ritmo, SueloRoto.V_EMBESTIDA])

	print("1) sin nadie en la linea")
	var pe: Vector2 = t.pies_de(e)
	_colocar(t, al, [pe + Vector2(-200, -160), pe + Vector2(-240, -160)])
	await _esperar(3)
	var r1: Dictionary = await _embestir(combat, t, e, cor, null, al)
	var f1 = r1["forma"]
	_ver(f1 != null, "suelta su linea")
	if f1 != null:
		var esperado: Vector2 = Vector2(r1["pies0"]) + f1.dir * f1.largo
		var llega: Vector2 = t.pies_de(e)
		print("     de %s a %s (esperado %s; largo %.0f)" % [r1["pies0"], llega, esperado, f1.largo])
		_ver(llega.distance_to(Vector2(r1["pies0"])) > f1.largo * 0.6, "se mueve aunque no pille a nadie (%.0f px)" % llega.distance_to(Vector2(r1["pies0"])))
		_ver(llega.distance_to(esperado) < 8.0, "acaba con el frente al final de su raya (a %.1f px)" % llega.distance_to(esperado))
		var t_ok: float = llega.distance_to(Vector2(r1["pies0"])) / SueloRoto.V_EMBESTIDA / ritmo
		print("     tardo %.2f s en cruzar (esperado %.2f)" % [r1["dur"], t_ok])
		_ver(absf(float(r1["dur"]) - t_ok) < 0.12, "tarda lo que dice V_EMBESTIDA")

	print("2) con dos en la linea")
	pe = t.pies_de(e)
	# Hacia la derecha, si cabe; si no, a la izquierda.
	var dir := Vector2.RIGHT if t._en_arena(t.pos_de(e) + Vector2(160, 0)) else Vector2.LEFT
	var borde: float = t._hasta_el_borde(pe, dir, t.bulto_de(e))
	_colocar(t, al, [pe + dir * (borde + 30), pe + dir * (borde + 80)])
	await _esperar(3)
	var hp0: Array = [al[0].current_hp, al[1].current_hp]
	var r2: Dictionary = await _embestir(combat, t, e, cor, al[0], al)
	var f2 = r2["forma"]
	# (se puede ESQUIVAR: cuenta el golpe que sale en la cola, entre o no; la vida solo dice si entro)
	var en_cola: Dictionary = r2["en_cola"]
	print("     vida quitada: %.0f y %.0f" % [hp0[0] - al[0].current_hp, hp0[1] - al[1].current_hp])
	_ver(int(en_cola.get(al[0], 0)) == 1 and int(en_cola.get(al[1], 0)) == 1, "les pega a los dos, una vez a cada uno (%s)" % str(en_cola.values()))
	if f2 != null and r2["t_golpe"].size() == 2:
		var t0: float = float(r2["t_golpe"][al[0]])
		var t1: float = float(r2["t_golpe"][al[1]])
		# En tiempo de animacion: 50 px a V_EMBESTIDA (lo mismo que el desliz, que va al ritmo de los efectos).
		var hueco_ok: float = 50.0 / SueloRoto.V_EMBESTIDA
		print("     en la cola: al primero %.2f, al segundo %.2f (entre medias %.2f, esperado %.2f)" % [t0, t1, t1 - t0, hueco_ok])
		_ver(absf((t1 - t0) - hueco_ok) < 0.1, "a cada uno cuando le pasa por encima")
	if f2 != null:
		var esperado2: Vector2 = Vector2(r2["pies0"]) + f2.dir * f2.largo
		print("     acaba en %s (esperado %s)" % [t.pies_de(e), esperado2])
		_ver(t.pies_de(e).distance_to(esperado2) < 30.0, "llega (casi) al final de la raya: no se para en el primero")
		print("     raya de %.0f de ancho; cajas %s" % [f2.ancho, str(al.slice(0, 2).map(func(a): return t.bulto_de(a).size))])
		for a in al:
			var lado: float = absf((t.pies_de(a) - Vector2(r2["pies0"])).dot(f2.dir.orthogonal()))
			_ver(lado > f2.ancho * 0.5 - 2.0 or not f2.toca(t.bulto_de(a)), "%s apartado a un lado (%.0f px de la raya)" % [a.nombre, lado])

	# (diagnostico) lo que pide apartar al que esta en el centro de la raya
	_colocar(t, al, [t.pies_de(e) + dir * (borde + 30), t.pies_de(e) + dir * (borde + 80)])
	await _esperar(2)
	t.ultima_forma_enemigo = t.forma_de(cor, e, t.pies_de(e) + dir * 100)
	var n_t: int = t._tirones.size()
	t.pedir_apartar(al[0], e, cor.aparta_lados, true)
	if t._tirones.size() > n_t:
		print("     apartar pide %s (raya %.0f)" % [t._tirones.back()["desplaza"], t.ultima_forma_enemigo.ancho])
		var p_a: Vector2 = t.pies_de(al[0])
		var nodo0: Vector2 = t.pos_de(al[0])
		var camino: Array = []
		for k in range(0, 61, 10):
			var q: Vector2 = nodo0 + Vector2(t._tirones.back()["desplaza"]).normalized() * k
			camino.append("%d:%s%s" % [k, "s" if t._sobre_suelo(q, t.cuerpo_de(al[0])) else "-", "a" if t._en_arena(q) else "-"])
		print("     camino (suelo/arena): %s" % " ".join(camino))
		await get_tree().create_timer(3.6).timeout
		print("     y se mueve %s" % (t.pies_de(al[0]) - p_a))
	print("3) la de un objetivo se para en el primero")
	var yug: AbilityData = load("res://resources/abilities/rey_rata_yugular.tres")
	_ver(yug.forma_solo_primero and yug.carga, "la Yugular es de un objetivo")
	var lista: Array = [{"c": al[0], "escala": 1.0}, {"c": al[1], "escala": 1.0}]
	pe = t.pies_de(e)
	_colocar(t, al, [pe + dir * (borde + 30), pe + dir * (borde + 80)])
	await _esperar(3)
	t.ultima_forma_enemigo = t.forma_de(yug, e, t.pies_de(al[0]))
	var n0: int = t._deslices.size()
	t.mover_enemigo(e, yug, lista, 1)
	var hasta: Vector2 = t._deslices.back()["hasta"] if t._deslices.size() > n0 else t.pos_de(e)
	var pies_hasta: Vector2 = hasta + t._bajo_de(e)
	print("     se para en %s (el primero en %s)" % [pies_hasta, t.pies_de(al[0])])
	_ver(pies_hasta.distance_to(t.pies_de(al[0])) < t.pies_de(al[1]).distance_to(pies_hasta), "se queda delante del primero")
	t._deslices.clear()

	# 4) LAS QUE NO PILLAN A NADIE TAMBIEN SE VEN (29/10, el jefe: "reventon aunque falle debe saltar igual y llegar a su
	#    sitio", "llamarada o las raices del trent deben salir visualmente aunque no le den a nadie"): con los tuyos lejos,
	#    cada una lanza su efecto por el suelo, y el Reventon ademas salta (un desliz por el aire) y cae en otro sitio.
	print("4) las que no pillan a nadie tambien se ven")
	await _esperar_a(func() -> bool: return t._deslices.is_empty(), 6.0)
	for nombre in ["slime_reventon", "slime_llamarada", "trent_raices_atenazantes"]:
		var hab: AbilityData = load("res://resources/abilities/%s.tres" % nombre)
		pe = t.pies_de(e)
		# Los tuyos, al otro lado de la arena: ni el salto ni el cono ni las raices les llegan.
		var lejos := Vector2.LEFT if t._en_arena(t.pos_de(e) + Vector2(-260, 0)) else Vector2.RIGHT
		var sitios: Array = []
		for i in al.size():
			sitios.append(pe + lejos * (280 + 30 * (i % 2)) + Vector2(0, -60 + 40 * i))
		_colocar(t, al, sitios)
		await _esperar(3)
		# Si le llega a alguien, por la COLA (golpes de verdad contra los tuyos) y no por la vida: un estado del caso 2 les
		# baja la vida en la espera y con el PC cargado engañaba (29/10).
		var bloques_al: Array = al.map(func(a): return combat._bloque_de(a))
		var contra_al := func() -> int:
			var n := 0
			for ev in combat._fx._cola:
				if is_same(ev["ba"], combat._bloque_de(e)) and not bool(ev.get("solo_dibujo", false)) 						and bloques_al.any(func(b): return is_same(b, ev["bv"])):
					n += 1
			return n
		var antes_al: int = contra_al.call()
		var suelos: Array = []
		var oye := func(tipo: int, _espera: float): suelos.append(tipo)
		combat._fx.suelo_lanzado.connect(oye)
		var n_d: int = t._deslices.size()
		e.ability_cooldowns.erase(hab)
		combat.enemigos._enemy_use_ability(e, hab, al[0])
		var d: Dictionary = t._deslices.back() if t._deslices.size() > n_d else {}
		var le_da: bool = contra_al.call() > antes_al
		await _esperar_a(func() -> bool: return suelos.has(hab.suelo_roto), 4.0)
		await get_tree().create_timer(1.2).timeout
		combat._fx.suelo_lanzado.disconnect(oye)
		_ver(not le_da, "%s: no le da a nadie" % hab.nombre)
		_ver(suelos.has(hab.suelo_roto), "%s: su efecto sale por el suelo igual (%s)" % [hab.nombre, str(suelos)])
		if hab.salta:
			_ver(not d.is_empty() and float(d.get("arco", 0.0)) > 0.0, "%s: salta (por el aire)" % hab.nombre)
			_ver(t.pies_de(e).distance_to(pe) > 8.0, "%s: y cae en otro sitio (%.0f px)" % [hab.nombre, t.pies_de(e).distance_to(pe)])
		await _esperar_a(func() -> bool: return t._deslices.is_empty(), 6.0)

	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)


# Suelta la habilidad por el camino de la pelea y espera a que acabe de cruzar. Devuelve la forma, de donde salio, lo que
# tardo en cruzar (desde que arranca el desliz) y cuando le llego el golpe a cada uno (desde ese mismo momento).
func _embestir(combat, t, e: Combatant, ab: AbilityData, preferido, al: Array) -> Dictionary:
	var pies0: Vector2 = t.pies_de(e)
	var hp: Dictionary = {}
	for a in al:
		hp[a] = a.current_hp
	var n0: int = t._deslices.size()
	var pos_antes: Array = al.map(func(a): return t.pies_de(a))
	combat.enemigos._enemy_use_ability(e, ab, preferido)
	var f = t.ultima_forma_enemigo
	for tr in t._tirones:
		print("     tiron a %s: %s" % [tr["c"].nombre, tr.get("desplaza", tr["px"])])
	var vistos_t: Dictionary = {}
	var d: Dictionary = t._deslices.back() if t._deslices.size() > n0 else {}
	var golpes: Dictionary = {}
	var t_golpe: Dictionary = {}
	var en_cola: Dictionary = {}
	var arranque: int = -1
	var fin: int = -1
	var t_ini: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_ini < 6000:
		await get_tree().process_frame
		if arranque < 0 and not d.is_empty() and float(d["t"]) >= 0.0:
			arranque = Time.get_ticks_msec()
		for a in al:
			if a.current_hp < float(hp[a]) - 0.001:
				golpes[a] = int(golpes.get(a, 0)) + 1
				hp[a] = a.current_hp
			# CUANDO SE VE EL GOLPE: su instante en la cola de efectos (tiempo de animacion), no la vida (se resta al resolver).
			if not t_golpe.has(a) and combat._fx != null:
				var n_a: int = 0
				for ev in combat._fx._cola:
					if is_same(ev["bv"], combat._bloque_de(a)) and not bool(ev.get("solo_dibujo", false)):
						t_golpe[a] = float(ev["t"])
						n_a += 1
				if n_a > 0:
					en_cola[a] = n_a
		for i in al.size():
			var mov: Vector2 = t.pies_de(al[i]) - Vector2(pos_antes[i])
			if mov.length() > 1.0 and not vistos_t.has(i):
				vistos_t[i] = true
				print("     %s empieza a moverse a los %.2f s" % [al[i].nombre, (Time.get_ticks_msec() - t_ini) / 1000.0])
		if fin < 0 and arranque >= 0 and not t._deslices.has(d):
			fin = Time.get_ticks_msec()
		if fin >= 0 and Time.get_ticks_msec() - fin > 700:
			break
	for i in al.size():
		print("     %s se ha movido %s" % [al[i].nombre, t.pies_de(al[i]) - Vector2(pos_antes[i])])
	return {"forma": f, "pies0": pies0, "dur": (fin - arranque) / 1000.0 if fin >= 0 and arranque >= 0 else -1.0,
		"golpes": golpes, "t_golpe": t_golpe, "en_cola": en_cola}


func _colocar(t, al: Array, sitios: Array) -> void:
	for i in al.size():
		var s: Vector2 = sitios[i] if i < sitios.size() else sitios[0] + Vector2(-260 - 40 * i, 90)
		t._colocar(al[i], t.cuerpo_de(al[i]), s - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
