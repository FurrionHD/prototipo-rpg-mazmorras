# LOS REBOTES DE LA DESCARGA EN EL MAPA (12/10, playtest 11/10: "descarga no hace los rebotes en el enemigo; creo
# que has hecho que los rebotes tengan que ser si o si a otros enemigos"). Su descripcion dice que a veces se ensaña
# con el mismo. Sin red, en la arena, pelea tactica:
#   1) con UN solo enemigo, los rebotes le caen a el (1 + rebotes golpes);
#   2) con dos pegados, la cadena salta al otro (los dos reciben);
#   3) con el otro lejos (fuera de forma_cadena), los rebotes vuelven al primero, no al lejano.
#   godot --headless --path . res://tools/prueba_rebotes_descarga.tscn
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


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _pantalla() -> Node:
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					return h
	return null


# Lanza la Descarga contra 'obj' tal cual la resuelve la pelea en el mapa. Devuelve los tocados (con repeticiones).
func _lanzar(combat: Node, spell: SpellData, obj: Combatant) -> Array:
	combat._player = combat._aliados[0]
	combat._casteos[combat._player] = {"punto": combat.turno_mapa.pies_de(obj), "spell": spell, "idx": 0}
	for e in combat._enemies:
		e.current_hp = 99999.0   # que no caiga nadie: aqui se cuentan los saltos
		e.max_hp = 99999.0
	return combat.magia._resolver_hechizo(spell, obj)


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(5)
	Game.entrar_arena_de_pruebas()
	await _esperar(15)
	var spell: SpellData = load("res://resources/spells/descarga.tres")
	var n_reb: int = spell.rebotes_n()
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime.tres", jug.global_position + Vector2(90, 0), {})
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime.tres", jug.global_position + Vector2(900, 0), {})
	await _esperar(25)
	var bichos: Array = get_tree().get_nodes_in_group("enemy")
	bichos.sort_custom(func(a, b): return a.global_position.distance_to(jug.global_position) < b.global_position.distance_to(jug.global_position))
	if bichos.size() < 2 or not Game.start_combat([bichos[0]], false):
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	var otro_nodo: Node2D = bichos[1]
	await _esperar(10)
	var combat: Node = _pantalla()
	combat.set_process(false)
	var e1: Combatant = combat._enemies[0]

	print("1) un solo enemigo (%d rebotes)" % n_reb)
	var t1: Array = _lanzar(combat, spell, e1)
	_ver(t1.size() == 1 + n_reb and t1.all(func(x): return x == e1),
		"le caen el rayo y los %d rebotes (%d golpes)" % [n_reb, t1.size()])

	print("2) dos pegados")
	var c1: Node2D = combat.turno_mapa.cuerpo_de(e1)
	otro_nodo.global_position = c1.global_position + Vector2(0, 30)
	Game.unir_enemigo_al_combate(otro_nodo)
	await _esperar(5)
	var e2: Combatant = combat._enemies[combat._enemies.size() - 1]
	var c2: Node2D = combat.turno_mapa.cuerpo_de(e2)
	_ver(e2 != e1 and c2 != null, "el segundo esta en la pelea y tiene cuerpo")
	if c2 != null:
		c2.global_position = c1.global_position + Vector2(0, 30)
		combat.turno_mapa._pos[e2] = c2.global_position
	var t2: Array = _lanzar(combat, spell, e1)
	_ver(t2.has(e2), "la cadena salta al de al lado (%d de %d golpes en el)" % [t2.count(e2), t2.size()])
	_ver(t2.size() == 1 + n_reb, "y no se pierde ningun rebote (%d)" % t2.size())

	print("3) el otro lejos")
	if c2 != null and c1 != null:
		c2.global_position = c1.global_position + Vector2(0, 400)
		combat.turno_mapa._pos[e2] = c2.global_position
	var t3: Array = _lanzar(combat, spell, e1)
	_ver(not t3.has(e2), "al lejano no le llega")
	_ver(t3.size() == 1 + n_reb, "los rebotes vuelven al primero (%d golpes)" % t3.size())

	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
