# BD FASE 5: SE CAE UN JUGADOR A MEDIA PELEA. En la arena y sin ventana, con un aliado "de otro jugador"
# (dueño falso) al que se le corta la conexion:
#   - no sale de la pelea: queda en cortesia;
#   - en su turno, con energia, DEFIENDE (gasta la energia de defender); sin energia, PASA; la pelea no se para;
#   - si vuelve, recupera a sus personajes (vuelven a ser suyos y a pedirsele el turno);
#   - si no vuelve a tiempo, sus personajes salen y lo vivido se apunta en su ficha del mundo.
#   godot --headless --path . res://tools/prueba_caida_en_pelea.tscn
extends Node

const PEER := 777
const NUEVO := 778
const IDENT := "dddddddddddddddddddddddd"
var _fallos: int = 0


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	Perfil.nube_activa = false
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _afirmar(ok: bool, que: String) -> void:
	if not ok:
		_fallos += 1
		print("[FALLA] ", que)
	else:
		print("[PASA] ", que)


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


# Avanza la pelea (pasando los turnos de los demas) hasta que 'cond' se cumpla o pasen 'tope_s' segundos.
func _jugar_hasta(combat: Node, cond: Callable, tope_s: float) -> bool:
	var t0: int = Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > tope_s * 1000.0:
			return false
		if combat._state == combat.State.WAITING_PLAYER and combat._esperando_a == 0 \
				and int(combat._dueno_aliado.get(combat._player, 0)) == 0:
			combat._accion_esperar()
		await get_tree().process_frame
	return true


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
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime.tres", jug.global_position + Vector2(160, 0), {})
	await _esperar(20)
	if not Game.start_combat(get_tree().get_nodes_in_group("enemy"), false):
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	await _esperar(5)
	var combat: Node = null
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	if combat == null or combat._aliados.size() < 2:
		print("MAL: hace falta una pelea con dos aliados (hay %d)" % (0 if combat == null else combat._aliados.size()))
		get_tree().quit(1)
		return
	# El SEGUNDO aliado pasa a ser de "otro jugador" (peer 777), con su ficha en el mundo.
	var c2: Combatant = combat._aliados[1]
	var pj2: PersonajeData = null
	for pj in Game.party:
		if Game.combatant_de_pj(pj) == c2:
			pj2 = pj
	combat.marcar_dueno(c2, PEER)
	Net.peleas._pelea_id = 99
	Net.peleas._dobles[PEER] = [pj2]
	Net.peleas._pelea_participantes = [PEER]
	var jd := JugadorData.new()
	jd.id = IDENT
	var copia: PersonajeData = pj2.duplicate(true)
	copia.uid = pj2.uid
	jd.personajes = [copia]
	Game.jugadores_mundo[IDENT] = jd

	print("--- se le cae la conexion")
	_afirmar(Net.peleas.marcar_caido(PEER, IDENT), "queda en cortesia (no sale de la pelea)")
	_afirmar(not combat._huidos.has(c2), "sus personajes siguen en la pelea")

	c2.current_energy = c2.max_energy
	var antes: float = c2.current_energy
	combat._defendiendo.erase(c2)
	_afirmar(await _jugar_hasta(combat, func() -> bool: return combat._defendiendo.has(c2), 60.0),
		"con energia, en su turno DEFIENDE solo")
	_afirmar(c2.current_energy < antes, "y gasta la energia de defender (%.0f -> %.0f)" % [antes, c2.current_energy])

	c2.current_energy = 0.0
	combat._defendiendo.erase(c2)
	_afirmar(await _jugar_hasta(combat, func() -> bool: return c2.current_energy > 0.0, 60.0),
		"sin energia, en su turno PASA (recupera aliento)")
	# (La marca de defensa no sirve aqui: en el mapa el efecto del Defender anterior la vuelve a poner un
	# instante despues. Lo que delata a un Defender es que cuesta energia: pasar solo suma.)
	var regen: float = (c2.energia_regen if c2.energia_regen > 0.0 else combat.ATTACK_ENERGY_REGEN) * combat.PASAR_ENERGIA_FRAC
	_afirmar(absf(c2.current_energy - minf(c2.max_energy, regen)) < 0.01,
		"y no gasta en defender: energia %.1f (pasar suma %.1f)" % [c2.current_energy, regen])
	_afirmar(await _jugar_hasta(combat, func() -> bool: return combat._state == combat.State.ADVANCING, 10.0),
		"la pelea sigue corriendo")

	print("--- vuelve")
	Net.peleas._vuelve(PEER, NUEVO)
	_afirmar(not Net.peleas.esta_caido(PEER) and Net.peleas._dobles.has(NUEVO), "sus personajes vuelven a ser suyos")
	_afirmar(int(combat._dueno_aliado.get(c2, 0)) == NUEVO, "y se le pediran a su conexion nueva")
	_afirmar(Net.peleas.esta_en_mi_pelea(NUEVO), "vuelve a estar en la pelea")

	print("--- se vuelve a caer y no vuelve")
	_afirmar(Net.peleas.marcar_caido(NUEVO, IDENT), "cortesia otra vez")
	var hp_antes: float = copia.current_hp if "current_hp" in copia else -1.0
	c2.current_hp = maxf(1.0, c2.current_hp * 0.5)
	Net.peleas._caidos[NUEVO]["t"] = Time.get_ticks_msec() - int((Net.peleas.CORTESIA + 1.0) * 1000.0)
	await _esperar(3)
	_afirmar(not Net.peleas.esta_caido(NUEVO) and not Net.peleas._dobles.has(NUEVO), "pasado el rato, fuera de la cortesia")
	_afirmar(combat._huidos.has(c2) or not combat._aliados.has(c2), "sus personajes dejan la pelea")
	print("  vida en su ficha del mundo: %.1f -> %.1f" % [hp_antes, copia.current_hp if "current_hp" in copia else -1.0])
	_afirmar("current_hp" in copia and absf(copia.current_hp - c2.current_hp) < 0.01, "lo vivido se apunta en su ficha del mundo")

	Net.peleas._pelea_id = 0
	Net.peleas._dobles.clear()
	Net.peleas._pelea_participantes.clear()
	Game.jugadores_mundo.erase(IDENT)
	print("FIN: TODO BIEN" if _fallos == 0 else "FIN: %d MAL" % _fallos)
	get_tree().quit(0 if _fallos == 0 else 1)
