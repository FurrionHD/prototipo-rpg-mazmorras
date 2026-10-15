# Cubre: res://scripts/world/niebla.gd
# LA NIEBLA CON EL JUGADOR QUIETO (auditoria 13/10, fallo encontrado leyendo el codigo): la niebla se salta la
# pasada si nadie se mueve (es lo caro), y con ella se saltaba tambien el "quien esta a la luz". Un enemigo que
# entraba de la oscuridad a tu farolillo mientras estabas parado seguia INVISIBLE hasta que dabas un paso; y uno que
# se iba a lo oscuro seguia viendose.
# La prueba: piso 1 de la partida de referencia, jugador quieto, un enemigo (sin IA, para que no se mueva solo)
# lejos en lo oscuro y luego al lado del jugador. Tiene que aparecer y desaparecer sin que el jugador se mueva.
#   godot --headless --path . res://tools/prueba_niebla_quieto.tscn
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


func _esperar(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 4016831469
	Game.current_floor = 1
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")
	# Hasta que el piso este montado, con jugador y niebla
	var piso: Node = null
	var niebla: Node = null
	var jugador: Node2D = null
	for i in 600:
		await get_tree().process_frame
		piso = get_tree().get_first_node_in_group("dungeon_floor")
		jugador = get_tree().get_first_node_in_group("player") as Node2D
		niebla = piso.get_node_or_null("Niebla") if piso != null else null
		if piso != null and niebla != null and jugador != null and not get_tree().paused:
			break
	if niebla == null or jugador == null:
		_ver(false, "el piso se monta con niebla y jugador")
		_fin()
		return
	await _esperar(30)

	# Un enemigo, quieto (sin IA ni fisica) para que lo mueva solo la prueba.
	var bicho: Node2D = null
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e is Node2D:
			bicho = e
			break
	if bicho == null:
		_ver(false, "hay algun enemigo en el piso")
		_fin()
		return
	bicho.process_mode = Node.PROCESS_MODE_DISABLED
	jugador.set_physics_process(false)   # el jugador no se mueve ni un pixel
	var yo: Vector2 = jugador.global_position

	# 1) Lejos (dentro de la ventana que se calcula, pero fuera del farolillo)
	var lejos: Vector2 = yo + Vector2(260, 0)
	bicho.global_position = lejos
	await _esperar(20)   # varias pasadas de la niebla (va a 15 por segundo)
	var luz_lejos: bool = niebla._le_llega_luz(bicho)
	_ver(not luz_lejos, "a 260 px no le llega la luz (si le llega, la prueba no mira nada)")
	_ver(not bicho.visible, "lejos y a oscuras: no se ve")

	# 2) Al lado del jugador, que sigue QUIETO
	bicho.global_position = yo + Vector2(40, 0)
	await _esperar(20)
	_ver(niebla._le_llega_luz(bicho), "al lado del jugador le llega la luz")
	_ver(bicho.visible, "entra en la luz con el jugador QUIETO: se ve")

	# 3) Y se vuelve a ir a lo oscuro
	bicho.global_position = lejos
	await _esperar(20)
	_ver(not bicho.visible, "se va a lo oscuro con el jugador quieto: deja de verse")
	_ver(jugador.global_position.distance_to(yo) < 0.5, "el jugador no se ha movido en toda la prueba")
	_fin()


func _fin() -> void:
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(0 if _mal == 0 else 1)
