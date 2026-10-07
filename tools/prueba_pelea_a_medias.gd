# BD FASE 6: CERRAR EL JUEGO A MEDIA PELEA (un jugador) Y SEGUIRLA AL CARGAR. Dos procesos, en este orden:
#   PELEA_FASE=1 godot --headless --path . res://tools/prueba_pelea_a_medias.tscn
#       partida nueva en la RANURA 97, al piso 1, empieza una pelea, le deja al enemigo y a tu personaje
#       unos numeros concretos, guarda y se MATA (como un alt+F4).
#   PELEA_FASE=2 godot --headless --path . res://tools/prueba_pelea_a_medias.tscn
#       carga la ranura 97 como el menu (al piso) y mira que la pelea sigue con esos numeros. Despues la borra.
extends Node

const SLOT := 97
const HP_ENEMIGO := 7.25
const HP_MIO := 41.5
const ENERGIA_MIA := 33.0
var _fallos := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Perfil.nube_activa = false
	call_deferred("_correr")


func _afirmar(ok: bool, que: String) -> void:
	print(("[PASA] " if ok else "[FALLA] ") + que)
	if not ok:
		_fallos += 1


func _esperar_a(cond: Callable, tope_s: float) -> bool:
	var t0: int = Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > tope_s * 1000.0:
			return false
		await get_tree().process_frame
	return true


func _pantalla() -> Node:
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					return h
	return null


func _correr() -> void:
	reparent(get_tree().root)
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco   # cambiar de escena se lleva a este, no a la prueba
	if OS.get_environment("PELEA_FASE") == "2":
		await _fase2()
	else:
		await _fase1()


func _fase1() -> void:
	PartidaBD.borrar(Perfil.ruta_bd(SLOT))
	Game.nueva_partida("Pelea", {})
	Perfil.guardar(SLOT)
	Game.current_floor = 1
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")
	# (Las lambdas COPIAN las variables: lo que buscan se vuelve a coger fuera.)
	await _esperar_a(func() -> bool:
		return get_tree().get_first_node_in_group("player") != null and not get_tree().get_nodes_in_group("enemy").is_empty(), 20.0)
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	await get_tree().create_timer(1.0).timeout
	var e: Node2D = null
	for n in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(n) and not n.has_meta("es_espejo"):
			e = n
			break
	if e == null:
		print("MAL: no hay enemigos en el piso")
		get_tree().quit(1)
		return
	e.global_position = jug.global_position + Vector2(70, 0)
	await get_tree().process_frame
	if not Game.start_combat([e], false):
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	await _esperar_a(func() -> bool:
		return _pantalla() != null and not _pantalla()._enemies.is_empty(), 10.0)
	var combat: Node = _pantalla()
	await get_tree().create_timer(1.0).timeout
	combat._enemies[0].current_hp = HP_ENEMIGO
	combat._aliados[0].current_hp = HP_MIO
	combat._aliados[0].current_energy = ENERGIA_MIA
	_afirmar(Perfil.guardar(SLOT), "guardado a media pelea")
	var d: SaveData = PartidaBD.inspeccionar_ruta(Perfil.ruta_bd(SLOT))["datos"]
	_afirmar(d != null and not d.pelea_a_medias.is_empty(), "la partida lleva la pelea")
	print("Muerte a lo bruto.")
	OS.kill(OS.get_process_id())


func _fase2() -> void:
	_afirmar(Perfil.cargar(SLOT), "cargada la ranura %d" % SLOT)
	var datos: SaveData = Perfil.cabecera_ligera(SLOT)
	_afirmar(datos != null and datos.en_mazmorra, "se guardo dentro de la mazmorra")
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")
	var hay: bool = await _esperar_a(func() -> bool:
		return _pantalla() != null and not _pantalla()._enemies.is_empty() and not _pantalla()._aliados.is_empty(), 20.0)
	var combat: Node = _pantalla()
	_afirmar(hay, "al cargar, la pelea sigue")
	if hay:
		_afirmar(absf(combat._enemies[0].current_hp - HP_ENEMIGO) < 0.01,
			"el enemigo con su vida (%.2f)" % combat._enemies[0].current_hp)
		_afirmar(absf(combat._aliados[0].current_hp - HP_MIO) < 0.01, "mi personaje con su vida (%.2f)" % combat._aliados[0].current_hp)
		_afirmar(combat._aliados[0].current_energy <= ENERGIA_MIA + 0.01 and combat._aliados[0].current_energy >= ENERGIA_MIA - 20.0,
			"y su energia (%.2f)" % combat._aliados[0].current_energy)
	Perfil._cerrar_bd()
	Perfil.ranura_actual = 0
	PartidaBD.borrar(Perfil.ruta_bd(SLOT))
	print("FIN: TODO BIEN" if _fallos == 0 else "FIN: %d MAL" % _fallos)
	get_tree().quit(0 if _fallos == 0 else 1)
