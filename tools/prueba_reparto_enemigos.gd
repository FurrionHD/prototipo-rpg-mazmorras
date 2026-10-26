# LOS ENEMIGOS SE REPARTEN (11/10, lo pidio el usuario: "si entran muchos, de un brote, todos van a por ti y se quedan
# demasiado juntos; una habilidad en area termina el combate"). Una pelea tactica en un piso de verdad: UN personaje y
# cinco enemigos que llegan JUNTOS por el mismo lado (como los de un brote). Se les dan dos rondas de turnos a mano y se
# mira que:
#   - ninguno acaba encima de otro (centros a menos de SEPARADOS px);
#   - como mucho MAX_PEGADOS le pegan a la vez; los demas esperan atras;
#   - un area de AREA px centrada en cualquiera de ellos no pilla a mas de MAX_EN_AREA.
#   godot --headless --path . res://tools/prueba_reparto_enemigos.tscn
extends Node

var mi_sala = null   # su sala: tools/prueba_sala_propia.gd

const SEPARADOS := 30.0
const AREA := 60.0
const MAX_EN_AREA := 3

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


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	# UN personaje: el caso malo (todos van a por el mismo).
	var lider: PersonajeData = Game.lider()
	Game.party.clear()
	Game.party.append(lider)
	Game.lider_idx = 0
	Game.semilla_mundo = 424242
	# EN SU SALA (etapa 4, 26/10): la prueba es la sala, con el piso 1 montado como lo monta ella (mundo_ref ya cargado).
	mi_sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(mi_sala)
	if not await mi_sala.arrancar("prueba_reparto_enemigos", 1, 424242, false):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	await _esperar(30)
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	var gen: DungeonGenerator = piso.gen
	var sala := Rect2i()
	for z in gen.zonas:
		if String(z["tipo"]) == "sala" and (z["rect"] as Rect2i).get_area() > sala.get_area():
			sala = z["rect"]
	var centro: Vector2 = gen.centro_px(sala.position + sala.size / 2)
	_mirar_brotes(piso)
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var enemigos: Array = get_tree().get_nodes_in_group("enemy")
	for e in enemigos:
		(e as Node2D).global_position = Vector2(-9999, -9999)
	_ver(enemigos.size() >= 5, "hay 5 enemigos en el piso (%d)" % enemigos.size())
	if enemigos.size() < 5:
		_acabar()
		return
	# En fila, a la derecha, como entran ahora los de un brote por el borde (ArenaCombate.SEPARACION_ENTRADA).
	jug.global_position = centro
	var sep: float = ArenaCombate.SEPARACION_ENTRADA
	for i in 5:
		(enemigos[i] as Node2D).global_position = centro + Vector2(110, sep * (float(i) - 2.0))
	await _esperar(3)
	await mi_sala.pelear_con_vecinos(enemigos[2], true)   # el del medio: los cinco le quedan a mano (Enemy.vecinos)
	await _esperar(15)
	var combat: Node = null
	for n in get_tree().root.get_children() + mi_sala.capas():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	if combat == null or not combat.tactico:
		_ver(false, "hay pelea tactica")
		_acabar()
		return
	var t = combat.turno_mapa
	print("pelea: %d enemigos contra %d" % [combat._enemies.size(), combat._aliados.size()])
	_ver(combat._enemies.size() == 5, "entran los 5 a la pelea")
	# La pelea, a mano: sin ATB, cada enemigo su turno y se espera a que acabe de andar y actuar.
	combat.set_process(false)
	var yo: Combatant = combat._aliados[0]
	yo.max_hp = 99999.0
	yo.current_hp = 99999.0
	for ronda in 3:
		for e in combat._enemies:
			if not (e as Combatant).is_alive():
				continue
			combat._state = combat.State.PAUSED
			combat._pause_left = INF
			# Sin cargas a medias (cargando no anda): aqui se mira como se reparten, no sus habilidades.
			e.charging = null
			e.retrasando = false
			t._cargas.erase(e)
			t.turno_enemigo(e)
			var t0: int = Time.get_ticks_msec()
			while t._fase != t.Fase.NADA and Time.get_ticks_msec() - t0 < 5000:
				t.tick(1.0 / 60.0)
				await get_tree().process_frame
			t._terminar()
			yo.current_hp = 99999.0
		print("ronda %d:" % (ronda + 1))
		_mirar(combat, t, yo, ronda == 2)
	_acabar()


# 'colocados': ya han tenido tiempo de llegar a su sitio. A medio llegar uno puede ir aun hacia ti y pasar cerca de los
# que ya te pegan (le toco antes que al tercero); el area se mide cuando ya se han repartido.
func _mirar(combat: Node, t, yo: Combatant, colocados: bool) -> void:
	var pies: Array = []
	var pegados: int = 0
	for e in combat._enemies:
		if not (e as Combatant).is_alive():
			continue
		var p: Vector2 = t.pies_de(e)
		var pega: bool = t.hueco_entre(e, yo) <= t.alcance_de(e) * t.ARRIMARSE + 6.0
		if pega:
			pegados += 1
		print("    %s en %s, a %.0f px de ti%s" % [e.nombre, p.round(), p.distance_to(t.pies_de(yo)),
			" (te pega)" if pega else ""])
		pies.append(p)
	var cerca_min: float = INF
	for i in pies.size():
		for j in range(i + 1, pies.size()):
			cerca_min = minf(cerca_min, (pies[i] as Vector2).distance_to(pies[j]))
	var en_area_max: int = 0
	for a in pies:
		var n: int = 0
		for b in pies:
			if (a as Vector2).distance_to(b) <= AREA:
				n += 1
		en_area_max = maxi(en_area_max, n)
	_ver(cerca_min >= SEPARADOS, "ninguno encima de otro (los dos mas juntos a %.0f px)" % cerca_min)
	_ver(pegados <= t.MAX_PEGADOS, "te pegan %d a la vez (tope %d)" % [pegados, t.MAX_PEGADOS])
	if colocados:
		_ver(en_area_max <= MAX_EN_AREA, "un area de %d px pilla como mucho a %d (pilla %d)" % [int(AREA), MAX_EN_AREA, en_area_max])


# LOS BOQUETES DEL BROTE (SpawnZone._tramo_de_pared): separados entre si (dos celdas de pared en medio) y, en casi todas
# las paredes, los suficientes para el brote entero.
func _mirar_brotes(piso: Node) -> void:
	var probados: int = 0
	var enteros: int = 0
	var juntos: int = 0
	for zona in piso._zonas.get_children():
		var n: int = zona.brote_tamano()
		for p in zona.partos:
			var b: Array = zona._tramo_de_pared(p, n)
			probados += 1
			if b.size() >= n:
				enteros += 1
			for i in b.size():
				for j in range(i + 1, b.size()):
					var d: Vector2i = (b[i]["pared"] as Vector2i) - (b[j]["pared"] as Vector2i)
					if maxi(absi(d.x), absi(d.y)) < zona.BROTE_SEPARACION:
						juntos += 1
	print("brotes: %d paredes, %d con el brote entero" % [probados, enteros])
	_ver(probados > 0 and juntos == 0, "los boquetes de un brote salen separados (%d pares pegados)" % juntos)
	_ver(float(enteros) >= float(probados) * 0.8, "en casi todas las paredes cabe el brote entero (%d de %d)" % [enteros, probados])


func _acabar() -> void:
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
