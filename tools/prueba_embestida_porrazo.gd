# EL GOLPE CUENTA EN EL PORRAZO (08/10, playtest: "cuando un enemigo me golpea fuera de combate tarda mucho en detectar
# que me ha golpeado; si me llega a hacer contacto no hace falta que termine la animacion"). Un slime embiste al jugador
# quieto: la pelea tiene que abrirse en el fotograma del contacto (CONTACTO_EMBESTIDA del gesto), no al acabarlo. Y si el
# jugador se aparta antes del porrazo, no entra.
#   godot --headless --path . res://tools/prueba_embestida_porrazo.tscn
extends Node

var mi_sala = null   # su sala: tools/prueba_sala_propia.gd
var _av: Node2D = null   # el cuerpo del humano al que embisten

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


# EN SU SALA (etapa 4, 26/10): el piso lo monta la sala una vez, y el que embiste es el CUERPO DE UN HUMANO (un avatar):
# en la sala los enemigos no abren pelea contra el nodo 'player', se la empujan a su dueño.
func _montar() -> Array:
	if mi_sala == null:
		mi_sala = preload("res://tools/prueba_sala_propia.gd").new()
		add_child(mi_sala)
		if not await mi_sala.arrancar("prueba_embestida_porrazo", 1, 424242, false):
			print("MAL: no arranca la sala")
			get_tree().quit(1)
			return []
		await _esperar(30)
	var piso: Node = mi_sala.piso.primero(&"dungeon_floor")
	var gen: DungeonGenerator = piso.gen
	for e in get_tree().get_nodes_in_group("enemy"):
		e.global_position = Vector2(-5000, -5000)
		e.set_physics_process(false)
	for a in get_tree().get_nodes_in_group("aliado"):
		a.global_position = Vector2(-8000, -8000)
		a.set_physics_process(false)
	# Una celda de sala con sitio a la derecha.
	var sitio := Vector2i(-1, -1)
	for z in gen.zonas:
		if String(z["tipo"]) == "sala" and (z["rect"] as Rect2i).size.x >= 8:
			sitio = (z["rect"] as Rect2i).get_center()
			break
	var C: float = float(DungeonGenerator.CELDA)
	var pe: Vector2 = (Vector2(sitio) + Vector2(0.5, 0.5)) * C
	# EL CUERPO, ANTES QUE EL ENEMIGO. El piso duerme (sin fisica) a los enemigos lejos de todos los jugadores
	# (dungeon_floor._congelar_lejanos, cada poco): creado con el cuerpo aun donde lo dejo el caso anterior (+400), si
	# el barrido caia en medio el enemigo se quedaba dormido medio segundo y la embestida salia tarde. Pasaba a ratos,
	# con el ordenador cargado (la bateria a 4 a la vez).
	if _av == null:
		_av = mi_sala.avatar(pe + Vector2(40, 0))
	mi_sala.mover_avatar(_av, pe + Vector2(40, 0))
	var data: EnemyData = load("res://scenes/actors/enemy/slime.tres")
	var en = piso.crear_enemigo(data, pe, 30.0, 0.5, 0, false)
	await _esperar(3)
	en.global_position = pe
	mi_sala.mover_avatar(_av, pe + Vector2(40, 0))
	# Y despierto: si un barrido lo pillo antes de colocarlo, el siguiente (con el cuerpo ya al lado) lo enciende.
	for _i in 120:
		if en.is_physics_processing():
			break
		await get_tree().physics_frame
	await get_tree().physics_frame
	return [en, _av]


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242

	print("1) se aparta antes del porrazo: no entra")
	var par: Array = await _montar()
	var en = par[0]
	var jug: Node2D = par[1]
	en._lanzar_embestida(jug)
	var dur: float = en._embiste_dur
	await get_tree().physics_frame
	mi_sala.mover_avatar(jug, jug.global_position + Vector2(400, 0))
	var t: float = 0.0
	while t < dur + 0.3 and not en._combat_triggered:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_ver(not en._combat_triggered, "apartarse a tiempo esquiva")


	print("2) quieto delante: la pelea en el porrazo")
	par = await _montar()
	en = par[0]
	jug = par[1]
	en._lanzar_embestida(jug)
	dur = en._embiste_dur
	t = 0.0
	while t < dur + 0.5 and not en._combat_triggered:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_ver(en._combat_triggered, "la embestida abre la pelea")
	print("     gesto %.2f s, pelea a los %.2f s (porrazo al %.0f %% = %.2f s)" % [dur, t,
			en.CONTACTO_EMBESTIDA * 100.0, dur * en.CONTACTO_EMBESTIDA])
	_ver(t <= dur * en.CONTACTO_EMBESTIDA + 0.05, "se abre en el porrazo, no al acabar el gesto")
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(0 if _mal == 0 else 1)
