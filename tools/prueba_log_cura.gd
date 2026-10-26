# EL LOG DE UNA CURA (09/10, logs del 08/10: "Agirato lanza Luz restauradora | dano:0.00 | def. magica de Rey Slime"):
# lanza la Luz restauradora en una pelea y comprueba que cura. La linea del log se mira a ojo en la salida: tiene que
# salir "[magia] ... cura con Luz restauradora: ..." y "(curacion, ...)", no "dano:0.00". Sin ventana:
#   godot --headless --path . res://tools/prueba_log_cura.tscn
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


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _correr() -> void:
	# EN SU SALA (etapa 4, 26/10): la prueba es la sala y la pelea se abre por donde la abre ella.
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_log_cura", Game.PISO_ARENA):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	sala.poner("res://scenes/actors/enemy/slime.tres", Vector2(90, 0), {})
	await _esperar(25)
	var nodo = get_tree().get_nodes_in_group("enemy")[0]
	_ver((await sala.pelear([nodo], false) != null), "se abre la pelea")
	await _esperar(8)
	var combat: Node = null
	for n in get_tree().root.get_children() + sala.capas():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	combat.set_process(false)
	var luz: SpellData = load("res://resources/spells/luz_restauradora.tres")
	var e: Combatant = combat._enemies[0]
	for al in combat._aliados:
		al.current_hp = al.max_hp * 0.5
	var antes: float = combat._player.current_hp
	combat.magia._resolver_hechizo(luz, e)
	print("    %s: %.1f -> %.1f" % [combat._player.nombre, antes, combat._player.current_hp])
	_ver(combat._player.current_hp > antes, "la Luz restauradora cura")
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
