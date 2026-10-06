# LOS CHARCOS Y RASTROS DE LAS MUTACIONES DEL SLIME (06/10): un brotado punzante deja su RASTRO de pinchos (Placaje
# espinoso) y su CHARCO de baba (Reventon pegajoso) A LA VEZ; uno de los tuyos los cruza: el rastro le hace el 50 % del
# ataque del slime y le mete Lento, una vez por turno y por charco; al turno siguiente, otra vez. Sin ventana:
#   godot --headless --path . res://tools/prueba_charcos_baba.tscn
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
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime.tres", jug.global_position + Vector2(70, 0), {})
	await _esperar(25)
	var nodo = get_tree().get_nodes_in_group("enemy")[0]
	nodo.mutante = true
	nodo.mutacion = &"brotado_punzante"
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
	print("enemigo: %s (grado %d, ataque %.1f)" % [e.nombre, e.grado_mut, e.atk()])
	_ver(e.nombre == "Slime brotado punzante", "en la pelea es el brotado punzante")
	var espinoso: AbilityData = load("res://resources/abilities/slime_placaje_espinoso.tres")
	var pegajoso: AbilityData = load("res://resources/abilities/slime_reventon_pegajoso.tres")
	# El rastro: una linea de 120 px que cruza por delante de tu personaje; el charco, lejos de su camino.
	var pie: Vector2 = tm.pies_de(al)
	var linea := CombatFormas.linea(pie + Vector2(-60, -40), Vector2.DOWN, 120.0, 16.0)
	linea.origen = pie + Vector2(30, -60)
	linea.centro = linea.origen + Vector2.DOWN * 60.0
	tm.poner_charco(e, espinoso, linea)
	tm.poner_charco(e, pegajoso, CombatFormas.circulo(pie + Vector2(-200, 0), 40.0))
	await _esperar(2)
	_ver(tm._charcos.size() == 2, "el rastro y el charco a la vez (%d)" % tm._charcos.size())
	var vis = tm._charco_vis.get("rastro_%d" % tm._cod(e))
	_ver(vis is Array and vis.size() >= 3, "el rastro se ve como una fila de charquitos (%d)" % (vis.size() if vis is Array else 0))
	print("1) cruza el rastro andando")
	var hp0: float = al.current_hp
	tm.charcos_empezar_turno(al)
	var cu: Node2D = tm.cuerpo_de(al)
	cu.global_position += Vector2(60, 0)   # anda a la derecha, cruzando la linea x = pie.x + 30
	tm.charcos_tras_andar(al)
	var quito: float = hp0 - al.current_hp
	print("    le quita %.1f (el 50 %% del ataque son %.1f)" % [quito, e.atk() * 0.5])
	_ver(absf(quito - e.atk() * 0.5) < 0.6, "el 50 % de su ataque")
	_ver(al.has_status(StatusEffects.Id.LENTO), "y le mete Lento")
	print("2) vuelve a cruzarlo en el MISMO turno: nada")
	var hp1: float = al.current_hp
	cu.global_position += Vector2(-60, 0)
	tm.charcos_tras_andar(al)
	_ver(is_equal_approx(hp1, al.current_hp), "una vez por turno")
	print("3) turno siguiente: otra vez")
	tm.charcos_empezar_turno(al)
	cu.global_position += Vector2(60, 0)
	tm.charcos_tras_andar(al)
	_ver(al.current_hp < hp1 - 1.0, "vuelve a dolerle (%.1f)" % (hp1 - al.current_hp))
	print("4) se secan a los 3 turnos del slime")
	for i in 3:
		tm.charcos_turno_enemigo(e)
	_ver(tm._charcos.is_empty(), "secos (%d)" % tm._charcos.size())
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
