# LA PROVOCACION DE VERDAD (10/10, playtest del 09/10: "funciona regulin, no le pega casi nada al tanque, ademas no tiene
# un icono de provocado"). Sin ventana, con el Minotauro en la arena:
#   1) provocado, TODO va a por el provocador (200 sorteos, y tambien los de golpe a golpe), si le alcanza;
#   2) sin provocar, se reparte como siempre; si el provocador no le alcanza o cae, tambien;
#   3) el enemigo lleva su chip de provocado (con los turnos) y el provocador el suyo.
#   godot --headless --path . res://tools/prueba_provocacion.tscn
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
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(5)
	Game.entrar_arena_de_pruebas()
	await _esperar(15)
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/guardian_rango.tres", jug.global_position + Vector2(-220, 70), {})
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
	var t = combat.turno_mapa
	if not await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 20.0):
		print("MAL: no llego un turno de los tuyos")
		get_tree().quit(1)
		return
	var al: Array = combat._aliados
	var e: Combatant = combat._enemies[0]
	# Los cuatro pegados a el (todos a tiro), el tanque el ULTIMO de la lista y sin amenaza: el que menos le tocaria.
	var pe: Vector2 = t.pies_de(e)
	var borde: float = t._hasta_el_borde(pe, Vector2.RIGHT, t.bulto_de(e))
	for i in al.size():
		var d: Vector2 = Vector2.from_angle(-0.6 + 0.4 * float(i))
		var b: float = t._hasta_el_borde(pe, d, t.bulto_de(e))
		t._colocar(al[i], t.cuerpo_de(al[i]), pe + d * (b + 8.0) - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
	await _esperar(3)
	var tanque: Combatant = al[al.size() - 1]
	e.amenaza = {}
	for c in al:
		e.amenaza[c] = 10.0
	e.amenaza[tanque] = 0.0
	t.atacante = e
	_ver(t.alcanzables(e, combat._aliados_vivos()).size() == al.size(), "los %d estan a tiro" % al.size())

	print("1) provocado")
	tanque.provocar_turnos = 3
	tanque.provocados = [e]
	var cuenta: Dictionary = _sortear(combat, 200, false)
	_ver(int(cuenta.get(tanque, 0)) == 200, "los 200 sorteos van al tanque (%s)" % _txt(cuenta))
	cuenta = _sortear(combat, 200, true)
	_ver(int(cuenta.get(tanque, 0)) == 200, "y los golpes de una racha tambien (%s)" % _txt(cuenta))
	var chips: Array = combat.efectos._chips_de(e)
	var chip_prov: Array = chips.filter(func(x): return String(x[0]).begins_with("💢"))
	_ver(chip_prov.size() == 1 and String(chip_prov[0][0]) == "💢3t", "el enemigo lleva su chip de provocado (%s)" % str(chips.map(func(x): return x[0])))
	_ver(combat.efectos._chips_de(tanque).any(func(x): return String(x[0]).begins_with("🎯")), "y el tanque el de provocar")

	print("2) sin provocar, fuera de alcance o caido")
	tanque.provocar_turnos = 0
	cuenta = _sortear(combat, 200, false)
	_ver(int(cuenta.get(tanque, 0)) < 100, "sin provocar se reparte (%s)" % _txt(cuenta))
	_ver(not combat.efectos._chips_de(e).any(func(x): return String(x[0]).begins_with("💢")), "y ya no lleva el chip")
	tanque.provocar_turnos = 3
	var otro: Combatant = Combatant.new("Otro", 1, Abilities.new(), 100.0, 10.0, 5.0, 5.0)
	tanque.provocados = [otro]
	cuenta = _sortear(combat, 200, false)
	_ver(int(cuenta.get(tanque, 0)) < 100, "si provoca a OTRO enemigo, a este no le obliga (%s)" % _txt(cuenta))
	tanque.provocados = [e]
	var hp0: float = tanque.current_hp
	tanque.current_hp = 0.0
	_ver(combat.objetivos.provocador_de(e) == null, "si el provocador cae, se acaba")
	tanque.current_hp = hp0
	tanque.provocar_turnos = 0
	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)


func _sortear(combat, n: int, atenuado: bool) -> Dictionary:
	var cuenta: Dictionary = {}
	for _k in n:
		var o: Combatant = combat.objetivos._elegir_objetivo_enemigo(atenuado)
		cuenta[o] = int(cuenta.get(o, 0)) + 1
	return cuenta


func _txt(cuenta: Dictionary) -> String:
	var out: Array = []
	for c in cuenta:
		out.append("%s %d" % [c.nombre if c != null else "nadie", cuenta[c]])
	return ", ".join(out)
