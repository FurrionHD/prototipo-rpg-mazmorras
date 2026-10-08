# LOS MUTANTES DEL SLIME VENENOSO (06/10): el SLIME PESTILENTE en la pelea del mapa. ACIDO EN LA PIEL (al pegarle cuerpo a
# cuerpo, Debil; aqui con la probabilidad forzada), las NUBES (Escupitajo y Exhalar, a la vez, cada una en su hueco), las
# BURBUJAS FLOTANTES (atravesarla revienta encima; si no, revienta sola) y REVENTAR AL MORIR (deja su nube). Sin ventana:
#   godot --headless --path . res://tools/prueba_mut_veneno.tscn
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


func _burbujas(tm) -> Array:
	var r: Array = []
	for k in tm._charcos:
		if tm._charcos[k].get("burbuja", false):
			r.append(k)
	return r


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(5)
	Game.entrar_arena_de_pruebas()
	await _esperar(15)
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime_veneno.tres", jug.global_position + Vector2(70, 0), {})
	await _esperar(25)
	var nodo = get_tree().get_nodes_in_group("enemy")[0]
	# Muta de verdad, paso a paso: venenoso -> miasma -> pestilente (el sprite y el humo se cambian solos).
	nodo.mutar(0.0)
	_ver(nodo.mutacion == &"miasma", "el venenoso muta en slime de miasma")
	nodo.mutar(0.0)
	_ver(nodo.mutacion == &"pestilente", "y el miasma en slime pestilente")
	await _esperar(5)
	if not Game.start_combat([nodo], false):
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	await _esperar(8)
	var combat: Node = null
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	var tm = combat.turno_mapa
	var e: Combatant = combat._enemies[0]
	var al: Combatant = combat._aliados[0]
	print("enemigo: %s (grado %d, ataque %.1f, %d habilidades)" % [e.nombre, e.grado_mut, e.atk(), e.habilidades.size()])
	_ver(e.nombre == "Slime pestilente", "en la pelea es el slime pestilente")
	_ver(e.acido_piel and is_equal_approx(e.acido_prob, 0.3) and e.revienta_al_morir != null, "trae acido en la piel (30 %) y revienta al morir")
	_ver(e.habilidades.size() == 5, "con sus 5 ataques")
	var cu_e: Node2D = tm.cuerpo_de(e)
	var spr = cu_e.get("_sprite")
	_ver(spr != null and spr.get_node_or_null("HumoToxico") != null and spr.get_node("HumoToxico").modo == 2,
		"lleva las burbujas al azar por el cuerpo (HumoToxico modo 2)")
	_ver(spr != null and spr.sprite_frames != null and spr.sprite_frames.has_animation(&"soltar_burbujas_0"),
		"su sprite es el del pestilente (tiene soltar_burbujas)")

	print("1) acido en la piel: le pegas cuerpo a cuerpo")
	var cu_a: Node2D = tm.cuerpo_de(al)
	cu_a.global_position = cu_e.global_position + Vector2(-34, 0)
	tm._pos[al] = cu_a.global_position
	e.acido_prob = 1.0
	al.status_resist = 0.0
	combat._pasiva_al_golpearle(e, al)
	_ver(al.has_status(StatusEffects.Id.DEBIL), "le deja Debil")

	print("2) las dos nubes a la vez (Escupitajo y Exhalar)")
	var esc: AbilityData = load("res://resources/abilities/slime_escupitajo_pestilente.tres")
	var exh: AbilityData = load("res://resources/abilities/slime_exhalar_pestilente.tres")
	tm.poner_charco(e, esc, CombatFormas.circulo(cu_e.global_position + Vector2(60, 40), 12.0))
	tm.poner_charco(e, exh, CombatFormas.circulo(tm.pies_de(e), exh.forma_radio))
	var cod: int = tm._cod(e)
	_ver(tm._charcos.has("charco6_%d" % cod) and tm._charcos.has("charco7_%d" % cod), "estan las dos, cada una en su hueco")
	_ver(is_equal_approx((tm._charcos["charco6_%d" % cod]["f"]).radio, 35.0), "la del Escupitajo tiene su radio (35)")

	print("3) burbujas flotantes")
	var bur: AbilityData = load("res://resources/abilities/slime_burbujas_pestilentes.tres")
	var n: int = tm.poner_burbujas(e, bur)
	var claves: Array = _burbujas(tm)
	print("    suelta %d" % n)
	_ver(n >= 2 and n <= 4 and claves.size() == n, "suelta entre 2 y 4")
	var ok_dist: bool = true
	for k in claves:
		var d: float = (tm._charcos[k]["f"]).centro.distance_to(tm.pies_de(e))
		if d > 141.0:
			ok_dist = false
	_ver(ok_dist, "todas a 140 px o menos de el")
	# La atraviesas: te revienta encima.
	var k0: String = claves[0]
	var c0: Vector2 = (tm._charcos[k0]["f"]).centro
	var hp0: float = al.current_hp
	tm._pisar_si(al, c0 - Vector2(40, 0), c0 + Vector2(40, 0))
	print("    al atravesarla le quita %.1f (magica desde el 08/10: su Magia x burbuja_dano contra tu defensa magica)" % (hp0 - al.current_hp))
	_ver(not tm._charcos.has(k0), "atravesada, ya no esta")
	_ver((hp0 - al.current_hp) > 0.5, "y le hace daño (magico)")
	# Las demas, solas al acabarse sus turnos.
	for k in _burbujas(tm):
		tm._charcos[k]["turnos"] = 1
	tm.charcos_turno_enemigo(e)
	_ver(_burbujas(tm).is_empty(), "las que nadie toca revientan solas")

	print("4) revienta al morir")
	e.current_hp = 0.0
	combat._morir_enemigo(e)
	await _esperar(5)
	var muerte: String = "charco8_%d" % cod
	_ver(tm._charcos.has(muerte), "deja su nube en el suelo")
	if tm._charcos.has(muerte):
		_ver(is_equal_approx((tm._charcos[muerte]["f"]).radio, 45.0) and int(tm._charcos[muerte]["turnos"]) == 3,
			"de radio 45 y 3 turnos")
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
