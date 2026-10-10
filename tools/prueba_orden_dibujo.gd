# EL ORDEN DE DIBUJO ENEMIGO/PERSONAJES (10/10, el 5 del playtest 09/10): antes el enemigo iba ENTERO delante o detras de
# todos los personajes segun el aliado mas cercano de cada maquina. Ahora va en las bandas por altura de
# Game._ordenar_munecos, con los muñecos: el de detras (mas arriba) por debajo del enemigo, el de delante por encima. Con
# el Minotauro y el Rey Slime, uno de los tuyos detras y otro delante de cada uno. Sin ventana:
#   godot --headless --path . res://tools/prueba_orden_dibujo.tscn
extends Node

const ENEMIGOS := ["guardian_rango", "rey_slime"]
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
	for i in ENEMIGOS.size():
		Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/%s.tres" % ENEMIGOS[i],
			jug.global_position + Vector2(-260 + 520 * i, 90), {})
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
	combat.set_process(false)
	var al: Array = combat._aliados
	if al.size() < 2:
		print("MAL: hacen falta dos de los tuyos y hay %d" % al.size())
		get_tree().quit(1)
		return
	for e in combat._enemies:
		var cu_e: Node2D = t.cuerpo_de(e)
		var suelo: Vector2 = Cuerpos.caja_de(cu_e).get_center()
		var caja: Rect2 = Cuerpos.caja_de(cu_e)
		print("%s (caja %s)" % [e.nombre, caja.size])
		# Uno DETRAS (sus pies justo por encima de la caja del enemigo) y otro DELANTE (justo por debajo), los dos pegados
		# a el y un poco de lado, que es donde antes uno de los dos salia mal.
		var detras: Vector2 = Vector2(suelo.x - 10.0, caja.position.y - 4.0)
		var delante: Vector2 = Vector2(suelo.x + 10.0, caja.end.y + 4.0)
		t._colocar(al[0], t.cuerpo_de(al[0]), detras - Vector2(0, PoseJugador.PIES_BAJO_NODO))
		t._colocar(al[1], t.cuerpo_de(al[1]), delante - Vector2(0, PoseJugador.PIES_BAJO_NODO))
		await _esperar(3)
		var z_e: int = cu_e.z_index
		var z_a: int = (t.cuerpo_de(al[0]).get("_muneco") as Node2D).z_index
		var z_b: int = (t.cuerpo_de(al[1]).get("_muneco") as Node2D).z_index
		print("    z: detras %d, %s %d, delante %d" % [z_a, e.nombre, z_e, z_b])
		_ver(z_a < z_e, "el de detras se pinta por debajo del %s" % e.nombre)
		_ver(z_e < z_b, "el de delante se pinta por encima del %s" % e.nombre)
		_ver(z_e >= Game.Z_PERSONAJES and z_e < Game.Z_ENCIMA_PERSONAJES, "el %s en las bandas de los personajes" % e.nombre)
		# Y al reves: se cambian de sitio y se cambia el orden.
		t._colocar(al[0], t.cuerpo_de(al[0]), delante - Vector2(0, PoseJugador.PIES_BAJO_NODO))
		t._colocar(al[1], t.cuerpo_de(al[1]), detras - Vector2(0, PoseJugador.PIES_BAJO_NODO))
		await _esperar(3)
		z_e = cu_e.z_index
		z_a = (t.cuerpo_de(al[0]).get("_muneco") as Node2D).z_index
		z_b = (t.cuerpo_de(al[1]).get("_muneco") as Node2D).z_index
		_ver(z_b < z_e and z_e < z_a, "cambiados de sitio, cambia el orden (%d < %d < %d)" % [z_b, z_e, z_a])
	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)
