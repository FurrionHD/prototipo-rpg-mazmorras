# EL ESCUDO DE AGUA DEL SET MAREA, VISIBLE (09/10): la burbuja (EscudoAgua) se monta en el cuerpo, se sacude al
# pegarle, destella al parar un Lento, revienta al romperse y se va; el tramo azul en la barra de arriba; y el campo 11
# de la instantanea (lo que le llega al espejo). Sin ventana:
#   godot --headless --path . res://tools/prueba_escudo_agua.tscn
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
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime.tres", jug.global_position + Vector2(120, 0), {})
	await _esperar(25)
	var nodo = get_tree().get_nodes_in_group("enemy")[0]
	_ver(Game.start_combat([nodo], false), "se abre la pelea")
	await _esperar(8)
	var combat: Node = null
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	combat.set_process(false)
	var tm = combat.turno_mapa
	var al: Combatant = combat._aliados[0]
	al.runa_escudo_max = 40.0
	al.runa_escudo_agua = 40.0
	tm.pintar_escudos_agua()
	var cu: Node2D = tm.cuerpo_de(al)
	var b: EscudoAgua = EscudoAgua.de(cu)
	_ver(b != null, "la burbuja esta en su cuerpo")
	if b == null:
		print("FIN: HAY FALLOS (%d MAL)" % _mal)
		get_tree().quit(1)
		return
	await _esperar(3)
	_ver(b.visible, "y se ve")
	print("1) le pegan 15")
	var hp0: float = al.current_hp
	al.take_damage(15.0)
	await _esperar(2)
	_ver(is_equal_approx(al.current_hp, hp0) and is_equal_approx(al.runa_escudo_agua, 25.0), "el escudo se come el golpe (queda 25)")
	_ver(b._ondas.size() == 1 and b._sacudida > 0.5, "una onda donde pega y se sacude")
	print("2) le meten Lento")
	al.apply_status(StatusEffects.Id.LENTO)
	await _esperar(2)
	_ver(not al.has_status(StatusEffects.Id.LENTO) and al.runa_agua_paradas == 1, "el agua para el Lento")
	_ver(b._destello > 0.5, "y la burbuja destella")
	print("3) la barra de arriba")
	tm.refrescar_barras_grupo()
	var tramo: TramoEscudo = null
	for t in get_tree().root.find_children("TramoEscudo", "", true, false):
		tramo = t as TramoEscudo
	_ver(tramo != null and is_equal_approx(tramo._escudo, 25.0), "tramo azul de 25 en la barra de vida")
	print("4) el espejo: campo 11 de la instantanea")
	var vals: Array = combat.espejo._valores(combat._aliados, true)
	var f11: Array = vals[0][11] if (vals[0] as Array).size() > 11 else []
	_ver(f11.size() == 3 and is_equal_approx(float(f11[0]), 25.0) and is_equal_approx(float(f11[1]), 40.0)
		and int(f11[2]) == 1, "lleva [25, 40, 1]")
	var copia := Combatant.new("Copia", 1, Abilities.new(), 100.0, 3.0, 3.0, 3.0)
	combat.espejo._volcar([copia], [vals[0]])
	_ver(is_equal_approx(copia.runa_escudo_agua, 25.0) and is_equal_approx(copia.runa_escudo_max, 40.0)
		and copia.runa_agua_paradas == 1, "y el espejo lo vuelca en su maniqui")
	print("5) se rompe")
	al.take_damage(30.0)
	await _esperar(2)
	_ver(al.runa_escudo_agua <= 0.0 and is_equal_approx(al.current_hp, hp0 - 5.0), "se come 25 de 30 y entran 5")
	_ver(b._rota >= 0.0, "la burbuja revienta")
	var t0: int = Time.get_ticks_msec()
	while is_instance_valid(b) and Time.get_ticks_msec() - t0 < 2000:
		await get_tree().process_frame
	_ver(not is_instance_valid(b), "y se va")
	tm.refrescar_barras_grupo()
	_ver(tramo == null or not is_instance_valid(tramo) or tramo._escudo <= 0.0, "el tramo de la barra desaparece")
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
