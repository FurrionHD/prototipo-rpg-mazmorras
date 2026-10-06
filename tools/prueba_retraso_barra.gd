# EL RETRASO DE LAS HABILIDADES (06/10): al elegir una habilidad se te echa atras media barra y sale al volver a
# llegar; las de carga empiezan su carga al llegar; los conjuros, una vez al elegirlos; aturdir lo interrumpe; y el
# retraso viaja por la red con la carga. Sin ventana:
#   godot --headless --path . res://tools/prueba_retraso_barra.tscn
extends Node

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


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _pelea() -> Array:
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime.tres", jug.global_position + Vector2(70, 0), {})
	await _esperar(25)
	var nodo = get_tree().get_nodes_in_group("enemy")[0]
	if not Game.start_combat([nodo], false):
		return []
	await _esperar(8)
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					return [h, nodo]
	return []


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(5)
	Game.entrar_arena_de_pruebas()
	await _esperar(15)
	var r: Array = await _pelea()
	if r.is_empty():
		print("FIN: HAY FALLOS (no arranca la pelea)")
		get_tree().quit(1)
		return
	var combat: Node = r[0]
	var tm = combat.turno_mapa
	var en = combat.enemigos
	var e: Combatant = combat._enemies[0]
	var al: Combatant = combat._aliados[0]
	# Quietos: la prueba mueve la barra a mano.
	combat.set_process(false)
	var cu_e: Node2D = tm.cuerpo_de(e)
	var cu_a: Node2D = tm.cuerpo_de(al)
	cu_a.global_position = cu_e.global_position + Vector2(-30, 0)
	tm._pos[al] = cu_a.global_position
	_ver(combat.tactico, "pelea en el mapa")

	print("1) ENEMIGO, habilidad sin carga (Triple embate)")
	var tri: AbilityData = load("res://resources/abilities/slime_triple_embate.tres")
	combat._gauge[e] = 3.0
	en._enemy_begin_retraso(e, tri, al)
	_ver(e.retrasando and e.charging == tri, "queda esperando con la habilidad")
	_ver(is_equal_approx(float(combat._gauge[e]), 53.0), "se le echa media barra atras (3 -> 53): %.1f" % combat._gauge[e])
	_ver(not e.ability_ready(tri), "el cooldown arranca al elegirla")
	_ver(not tm.usa_huella(tri) or tm.tiene_carga(e), "su huella se queda pintada mientras espera")
	var chips: Array = combat.efectos._chips_de(e) if combat.efectos.has_method("_chips_de") else []
	print("    chips: %s" % [chips])
	var hp0: float = al.current_hp
	combat._state = combat.State.ADVANCING
	tm._turno_enemigo_de_siempre(e)
	_ver(e.charging == null and not e.retrasando, "al llegar sale y se acaba")
	_ver(not tm.tiene_carga(e), "la huella se borra al soltarla")
	print("    vida del objetivo %.1f -> %.1f" % [hp0, al.current_hp])
	await _esperar(3)

	print("2) ENEMIGO, habilidad de CARGA (Reventon)")
	var rev: AbilityData = load("res://resources/abilities/slime_reventon.tres")
	e.ability_cooldowns.clear()
	e.statuses.clear()
	en._enemy_begin_retraso(e, rev, al)
	_ver(e.retrasando and e.charge_left == 0, "primero el retraso")
	combat._state = combat.State.ADVANCING
	tm._turno_enemigo_de_siempre(e)
	_ver(e.charging == rev and not e.retrasando and e.charge_left == rev.carga_turnos,
		"al llegar EMPIEZA la carga (%d turno)" % e.charge_left)
	_ver(tm.tiene_carga(e), "con la huella que ya habia elegido")
	combat.interrumpir(e)
	await _esperar(3)

	print("3) ENEMIGO aturdido mientras espera")
	e.ability_cooldowns.clear()
	en._enemy_begin_retraso(e, tri, al)
	e.apply_status(StatusEffects.Id.ATURDIDO)
	var hp1: float = al.current_hp
	combat._state = combat.State.ADVANCING
	tm._turno_enemigo_de_siempre(e)
	_ver(e.charging == null and not e.retrasando, "aturdirlo le interrumpe la habilidad")
	_ver(is_equal_approx(hp1, al.current_hp), "y no pega")
	_ver(not tm.tiene_carga(e), "su huella se va")
	e.statuses.clear()
	await _esperar(3)

	print("4) por la RED: el retraso viaja con la carga")
	e.ability_cooldowns.clear()
	en._enemy_begin_retraso(e, tri, al)
	var vol: Dictionary = combat.espejo._volatil(e)
	var copia := Combatant.new("Copia", 1, Abilities.new(), 100.0, 10.0, 5.0, 5.0)
	combat.espejo._aplicar_volatil(copia, vol)
	_ver(copia.charging == tri and copia.retrasando, "el espejo sabe que espera (no que carga)")
	combat.interrumpir(e)
	_ver(not e.retrasando, "cortarle la carga le quita el retraso")
	await _esperar(3)

	print("5) JUGADOR, habilidad")
	var ab: AbilityData = null
	for a in al.abilities_combate:
		if a != null and not (a as AbilityData).es_preparacion() and (a as AbilityData).carga_turnos == 0 \
				and (a as AbilityData).energia_a_mana <= 0.0:
			ab = a
			break
	if ab == null:
		_ver(false, "el personaje de la prueba no lleva habilidades")
	else:
		print("    con %s" % ab.nombre)
		al.current_energy = al.max_energy
		al.ability_cooldowns.clear()
		combat._player = al
		combat._state = combat.State.WAITING_PLAYER
		combat._gauge[al] = 1.0
		tm.anotar_apunte([tm.pies_de(e).x, tm.pies_de(e).y])
		var en0: float = al.current_energy
		combat.habilidades._usar_habilidad(ab)
		_ver(al.retrasando and al.charging == ab, "queda esperando con ella")
		_ver(is_equal_approx(float(combat._gauge[al]), 51.0), "media barra atras (1 -> 51): %.1f" % combat._gauge[al])
		_ver(al.current_energy < en0, "la energia se paga al elegirla")
		_ver(combat._state != combat.State.WAITING_PLAYER, "el turno se acaba (los demas siguen)")
		combat._player = al
		combat._begin_player_turn()
		_ver(al.charging == null and not al.retrasando, "al llegar a la barra sale")
		await _esperar(3)

	print("6) JUGADOR aturdido mientras espera")
	if ab != null:
		al.current_energy = al.max_energy
		al.ability_cooldowns.clear()
		combat._player = al
		combat._state = combat.State.WAITING_PLAYER
		tm.anotar_apunte([tm.pies_de(e).x, tm.pies_de(e).y])
		combat.habilidades._usar_habilidad(ab)
		al.apply_status(StatusEffects.Id.ATURDIDO)
		var hpe: float = e.current_hp
		combat._player = al
		combat._begin_player_turn()
		_ver(al.charging == null and not al.retrasando, "se le interrumpe")
		_ver(is_equal_approx(hpe, e.current_hp), "y no pega")
		al.statuses.clear()
		await _esperar(3)

	print("7) JUGADOR, conjuro: una vez, al decir la primera frase")
	var sp: SpellData = null
	for s in al.spells:
		if s != null and not tm.usa_huella_hechizo(s):
			sp = s
			break
	if sp == null and not al.spells.is_empty():
		sp = al.spells[0]
	if sp == null:
		print("    (el personaje no lleva conjuros: se salta)")
	else:
		print("    con %s" % sp.nombre)
		al.current_mp = al.max_mp
		combat._player = al
		combat._state = combat.State.WAITING_PLAYER
		combat._gauge[al] = 0.0
		combat.magia._elegir_hechizo(sp, null, tm.pies_de(e))
		_ver(combat._casteos.has(al), "queda recitando")
		_ver(is_equal_approx(float(combat._gauge[al]), 0.0) and combat._cast_box.visible,
			"elegirlo no cuesta nada: la primera frase, ya (barra %.1f)" % combat._gauge[al])
		var f: String = sp.frases[0]
		combat.magia._responder_frase(f, f)
		_ver(is_equal_approx(float(combat._gauge[al]), -50.0), "al decir la primera, media barra atras: %.1f" % combat._gauge[al])
		if sp.longitud() > 1:
			combat._gauge[al] = 0.0
			combat._player = al
			combat._state = combat.State.WAITING_PLAYER
			var f2: String = sp.frases[1]
			combat.magia._responder_frase(f2, f2)
			_ver(is_equal_approx(float(combat._gauge[al]), 0.0), "la segunda NO se echa atras otra vez")

	print("8) LA IA: se pone fuera de tu area si desde ahi sigue pegando")
	combat._casteos.erase(al)
	al.charging = null
	if ab != null and tm.usa_huella(ab):
		for pronto in [true, false]:
			var cu_e2: Node2D = tm.cuerpo_de(e)
			cu_e2.global_position = cu_a.global_position + Vector2(24, 0)
			tm._pos[e] = cu_e2.global_position
			combat.interrumpir(e)
			e.statuses.clear()
			# Tu habilidad esperando, apuntada un poco por detras de el (hay sitio delante, pegado a ti, fuera de ella).
			al.charging = ab
			al.retrasando = true
			var punto: Vector2 = tm.pies_de(e) + Vector2(14, 0)
			tm._cargas[al] = [ab, punto]
			var f_hab = tm.forma_de(ab, al, punto)
			combat._gauge[al] = 95.0 if pronto else -400.0
			combat._state = combat.State.ADVANCING
			tm.turno_enemigo(e)
			var dest = tm._destino
			if pronto:
				var off: Vector2 = tm.pies_de(e) - cu_e2.global_position
				var ok: bool = dest != null
				if ok:
					var r_dest: Rect2 = tm.bulto_de(e)
					r_dest.position += (dest as Vector2) - cu_e2.global_position
					ok = not f_hab.toca(r_dest) and tm._hueco_desde(e, (dest as Vector2) + off, al) <= tm.alcance_de(e) * tm.ARRIMARSE
				_ver(ok, "si le va a caer, va a un sitio FUERA de tu area desde el que te sigue pegando (%s)" % [dest])
			else:
				_ver(dest == null, "si tu habilidad tarda en salir, no se molesta en moverse")
			tm._terminar()
			tm._destino = null
			tm._cargas.erase(al)
			al.charging = null
			combat._state = combat.State.ADVANCING
		# Y si NO hay sitio desde el que pegarte fuera del area (centrada en el), se queda y pega.
		al.charging = ab
		al.retrasando = true
		var ab_grande: AbilityData = ab.duplicate()
		ab_grande.forma = CombatFormas.Tipo.CIRCULO
		ab_grande.forma_radio = 120.0
		al.charging = ab_grande
		tm._cargas[al] = [ab_grande, tm.pies_de(e)]
		combat._gauge[al] = 95.0
		combat._state = combat.State.ADVANCING
		tm.turno_enemigo(e)
		_ver(tm._destino == null, "sin sitio desde el que pegar fuera del area, se queda y pega")
		tm._terminar()
		tm._cargas.erase(al)
		al.charging = null

	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
