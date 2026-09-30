# LAS SIMAS EN EL TACTICO (30/09): miconido y chupasimas. Sin ventana:
#   godot --headless --path . res://tools/prueba_simas_tactico.tscn
# Alcances, la Bocanada del miconido que se queda como nube, y la Sanguijuela pegada del chupasimas: se pega al
# que le entra el Adherirse, va con el a donde ande, no anda por su cuenta, le chupa en su turno y se despega por
# turnos, a golpes (25%) o aturdida. Acaba con BIEN/MAL.
extends Node

const ENEMIGOS := ["miconido", "chupasimas", "chillon"]
const ALCANCES := {"miconido": 20.0, "chupasimas": 15.0, "chillon": 15.0}
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


func _segundos(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


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
	for i in ENEMIGOS.size():
		Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/%s.tres" % ENEMIGOS[i],
			jug.global_position + Vector2(-120 + 160 * i, 60), {})
	await _esperar(25)
	if not Game.start_combat(get_tree().get_nodes_in_group("enemy"), false):
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	var combat: Node = null
	await _esperar(5)
	for n in get_tree().root.get_children():
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
	if al.size() < 2:
		print("MAL: hacen falta dos de los tuyos y hay %d" % al.size())
		get_tree().quit(1)
		return
	for a in al:
		a.max_hp = 99999.0
		a.current_hp = 99999.0
	for e in combat._enemies:
		var ed: EnemyData = t.cuerpo_de(e).get("data") if t.cuerpo_de(e) != null else null
		if ed == null:
			continue
		var clave: String = String(ed.resource_path).get_file().get_basename()
		if not ALCANCES.has(clave):
			continue
		print("--- %s (alcance %.0f) ---" % [clave, t.alcance_de(e)])
		_ver(is_equal_approx(t.alcance_de(e), float(ALCANCES[clave])), "alcance del basico %.0f" % ALCANCES[clave])
		var pe: Vector2 = t.pies_de(e)
		if clave == "miconido":
			_colocar(t, al, [pe + Vector2(t.radio_pisa(e) + 14, 0), pe + Vector2(-220, 40)])
			await _esperar(2)
			var esp: AbilityData = load("res://resources/abilities/miconido_esporas.tres")
			var rep: Array = t._reparto_en(esp, e, t.forma_de(esp, e, pe))
			_ver(rep.size() == 1 and rep[0]["c"] == al[0], "la Bocanada pilla al de al lado y no al de lejos")
			combat.enemigos._enemy_use_ability(e, esp, al[0])
			combat._fx.arrancar_cola()
			await _segundos(1.0)
			_ver(t._charcos.has(e) and roundi(t._charcos[e]["f"].apertura) == 2, "la nube se queda (estilo 2)")
			for _k in 2:
				t.charcos_turno_enemigo(e)
			_ver(not t._charcos.has(e), "la nube se va a los 2 turnos del miconido")
		if clave == "chupasimas":
			await _probar_pegada(combat, t, e, al)
		if clave == "chillon":
			await _probar_chillon(combat, t, e, al)
	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)


func _probar_pegada(combat, t, e, al: Array) -> void:
	var adh: AbilityData = load("res://resources/abilities/chupasimas_adherirse.tres")
	var pe: Vector2 = t.pies_de(e)
	var presa = al[0]
	_colocar(t, al, [pe + Vector2(50, 0), pe + Vector2(-240, 60)])
	await _esperar(2)
	var plan: Dictionary = t.mejor_apunte(e, adh, presa)
	_ver(int(plan["n"]) >= 1, "el Adherirse llega de un salto (pilla a %d)" % int(plan["n"]))
	# Puede fallar (esquiva): se repite hasta que entre.
	for _k in 30:
		combat.enemigos._enemy_use_ability(e, adh, presa)
		combat._fx.arrancar_cola()
		await _segundos(0.6)
		if t.pegada_de(e) != null:
			break
	_ver(t.pegada_de(e) == presa, "el Adherirse entra y se queda pegada a su presa")
	if t.pegada_de(e) == null:
		return
	_ver(presa.pegado() and e.pegado(), "los dos llevan la Sanguijuela")
	_ver(t.radio_de(e) == 0.0 and t.radio_de(presa) > 0.0, "la sanguijuela no anda y la presa si")
	await _segundos(0.8)
	_ver(t.pies_de(presa).distance_to(t.pos_de(e) + t._pegadas[e]["bajo"]) < 4.0, "va a los pies de su presa")
	# La presa anda: la lleva encima.
	var lejos: Vector2 = t.pies_de(presa) + Vector2(-60, 30)
	t._colocar(presa, t.cuerpo_de(presa), lejos - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
	await _esperar(3)
	_ver((t.pos_de(e) + t._pegadas[e]["bajo"]).distance_to(lejos) < 4.0, "la presa anda y se la lleva encima")
	var sp = t.cuerpo_de(e).get("_sprite")
	_ver(t._vis_pegadas.has(t.cuerpo_de(e)) and sp is Node2D and (sp as Node2D).position.y < t._vis_pegadas[t.cuerpo_de(e)]["base"].y,
		"su dibujo va subido a la altura del pecho")
	# (Con un horneado de antes del 30/09 no la tiene, y se queda como estaba: no es un fallo.)
	var tiene: bool = sp is AnimatedSprite2D and (sp as AnimatedSprite2D).sprite_frames.has_animation(&"adherido_0")
	print("  anim ahora: %s (el horneado %s 'adherido')" % [str((sp as AnimatedSprite2D).animation), "tiene" if tiene else "NO tiene"])
	_ver(not tiene or String((sp as AnimatedSprite2D).animation).begins_with("adherido"),
		"en su pose de pegada ('adherido')")
	# Su turno: chupa a su presa.
	var hp0: float = presa.current_hp
	var hp_e0: float = e.current_hp
	e.current_hp = e.max_hp * 0.8
	t._pegadas[e]["hp"] = e.current_hp
	hp_e0 = e.current_hp
	combat.enemigos._enemy_turn(e)
	combat._fx.arrancar_cola()
	await _segundos(1.5)
	_ver(presa.current_hp < hp0, "en su turno le chupa (%.1f)" % (hp0 - presa.current_hp))
	_ver(e.current_hp > hp_e0, "y se cura con lo que chupa")
	_ver(t.pegada_de(e) == presa and int(t._pegadas[e]["turnos"]) == t.PEGADA_TURNOS - 1, "le queda un turno menos")
	# Se despega a los 3 turnos suyos.
	t.gastar_turno_pegada(e)
	t.gastar_turno_pegada(e)
	_ver(t.pegada_de(e) == null and not presa.pegado() and not e.pegado(), "a los 3 turnos se despega")
	await _segundos(0.8)
	_ver(t.pos_de(e).distance_to(t.pos_de(presa)) > 10.0, "y cae a su lado (%.0f px)" % t.pos_de(e).distance_to(t.pos_de(presa)))
	await _esperar(3)
	var sp2 = t.cuerpo_de(e).get("_sprite")
	_ver(not t._vis_pegadas.has(t.cuerpo_de(e)), "su dibujo vuelve al suelo")
	# A golpes: el 25% de su vida.
	e.current_hp = e.max_hp
	_ver(t.empezar_pegada(e, presa), "se vuelve a pegar")
	e.current_hp -= e.max_hp * 0.24
	await _esperar(3)
	_ver(t.pegada_de(e) == presa, "con el 24% de su vida no se despega")
	e.current_hp -= e.max_hp * 0.02
	await _esperar(3)
	_ver(t.pegada_de(e) == null, "con el 25% se la arrancan")
	# Aturdida.
	e.current_hp = e.max_hp
	await _segundos(0.6)
	t.empezar_pegada(e, presa)
	e.apply_status(StatusEffects.Id.ATURDIDO, 1)
	await _esperar(3)
	_ver(t.pegada_de(e) == null, "aturdida se despega")
	e.quitar_estado(StatusEffects.Id.ATURDIDO)
	# Una por presa, y no sale de la pelea.
	await _segundos(0.6)
	t.empezar_pegada(e, presa)
	var salen: Array = StatusEffects.estados_que_salen(presa.statuses)
	_ver(salen.filter(func(d): return int(d.get("id", -1)) == StatusEffects.Id.PEGADO).is_empty(),
		"la Sanguijuela no sale de la pelea")
	t.soltar_pegada(e, "")


func _probar_chillon(combat, t, e, al: Array) -> void:
	var chi: AbilityData = load("res://resources/abilities/chillon_chillido.tres")
	_ver(chi.suelo_roto == SueloRoto.Tipo.SIMA_ULTRA, "el Chillido lleva el ultrasonido (suelo %d)" % chi.suelo_roto)
	var pe: Vector2 = t.pies_de(e)
	_colocar(t, al, [pe + Vector2(t.radio_pisa(e) + 30, 0), pe + Vector2(-t.radio_pisa(e) - 30, 0)])
	await _esperar(2)
	var rep: Array = t._reparto_en(chi, e, t.forma_de(chi, e, t.pies_de(al[0])))
	_ver(rep.size() == 1 and rep[0]["c"] == al[0], "el Chillido pilla al de delante y no al de detras")
	# El Picado: baja sobre uno de lejos, muerde y vuelve.
	var pic: AbilityData = load("res://resources/abilities/chillon_picado.tres")
	_colocar(t, al, [pe + Vector2(70, 10), pe + Vector2(-240, 60)])
	await _esperar(2)
	var antes: Vector2 = t.pos_de(e)
	var hp0: float = al[0].current_hp
	var lejos_max: float = 0.0
	combat.enemigos._enemy_use_ability(e, pic, al[0])
	combat._fx.arrancar_cola()
	for _k in 120:
		await get_tree().process_frame
		lejos_max = maxf(lejos_max, t.pos_de(e).distance_to(antes))
	await _segundos(1.0)
	print("  picado: se alejo %.0f px y acabo a %.0f px de donde estaba" % [lejos_max, t.pos_de(e).distance_to(antes)])
	_ver(lejos_max > 30.0, "el Picado baja hasta su presa")
	_ver(t.pos_de(e).distance_to(antes) < 4.0, "y vuelve a donde estaba")
	_ver(al[0].current_hp < hp0, "y la muerde")


func _colocar(t, al: Array, sitios: Array) -> void:
	for i in al.size():
		var s: Vector2 = sitios[i] if i < sitios.size() else sitios[0] + Vector2(-260 - 40 * i, 90)
		t._colocar(al[i], t.cuerpo_de(al[i]), s - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
