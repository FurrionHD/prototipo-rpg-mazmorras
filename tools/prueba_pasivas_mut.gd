# LAS PASIVAS DE LAS MUTACIONES DEL SLIME (06/10): ESPINAS (al pegarle cuerpo a cuerpo, 50 % de su ataque a los que le
# rodean; aqui con la probabilidad forzada) y DIVIDIRSE al morir (salen dos slimes normales; su cadaver se queda). Sin ventana:
#   godot --headless --path . res://tools/prueba_pasivas_mut.tscn
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
	_ver(e.espinas and e.se_divide and is_equal_approx(e.espinas_prob, 0.3) and is_equal_approx(e.espinas_dano, 0.5),
		"el brotado punzante trae espinas (30 %, 50 %) y se divide")
	print("1) espinas: le pegas cuerpo a cuerpo")
	var cu_e: Node2D = tm.cuerpo_de(e)
	var cu_a: Node2D = tm.cuerpo_de(al)
	cu_a.global_position = cu_e.global_position + Vector2(-34, 0)
	tm._pos[al] = cu_a.global_position
	e.espinas_prob = 1.0
	var hp0: float = al.current_hp
	combat._pasiva_al_golpearle(e, al)
	var quito: float = hp0 - al.current_hp
	print("    hueco %.1f px, le quita %.1f (50 %% de su ataque = %.1f)" % [tm.hueco_entre(al, e), quito, e.atk() * 0.5])
	_ver(absf(quito - e.atk() * 0.5) < 0.6, "las puas le hacen el 50 % de su ataque")
	print("2) de lejos no (magia o arco)")
	cu_a.global_position = cu_e.global_position + Vector2(-200, 0)
	tm._pos[al] = cu_a.global_position
	var hp1: float = al.current_hp
	combat._pasiva_al_golpearle(e, al)
	_ver(is_equal_approx(hp1, al.current_hp), "a distancia no le saltan")
	print("3) se divide al morir")
	var antes: int = 0
	for x in combat._enemies:
		if x.is_alive():
			antes += 1
	e.current_hp = 0.0
	combat._morir_enemigo(e)
	await _esperar(10)
	var vivos: Array = []
	for x in combat._enemies:
		if x.is_alive():
			vivos.append(x.nombre)
	print("    vivos: %s" % [vivos])
	_ver(vivos.size() == antes - 1 + 2, "salen dos (%d vivos)" % vivos.size())
	_ver(vivos.count("Slime") == 2, "y son slimes NORMALES")
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
