# PRUEBA: CARGAR NO ACABA EL TURNO (03/10). Con arco y flechas en la bolsa, en la arena y sin ventana:
#   - cargar deja el turno abierto (mismo personaje, esperando su accion) y carga 10;
#   - despues: ni magia ni objetos; Habilidades solo con Untar (que tambien sigue el turno); el circulo de andar NO
#     se reinicia; con las dos hechas, Habilidades se cierra;
#   - al pasar el turno acaba y el siguiente vuelve a tener todo;
#   - al acabar la pelea lo cargado se queda en la ficha para la siguiente.
#   godot --headless --path . res://tools/prueba_cargar_turno.tscn
extends Node

var sala = null   # su sala: tools/prueba_sala_propia.gd

var _fallos: int = 0


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
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


func _esperar_a(cond: Callable, tope_s: float) -> bool:
	var t0: int = Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > tope_s * 1000.0:
			return false
		await get_tree().process_frame
	return true


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	Game.equipar_arma(load("res://resources/weapons/arco.tres") as WeaponData)
	var flecha: MaterialData = load("res://resources/materials/flecha_acero.tres")
	for _i in 20:
		Game.bolsa.anadir(MaterialItem.crear(flecha))
	var untura: ConsumableData = load("res://resources/consumables/ponzona_ciempies.tres")
	Game.consumables[untura] = 2
	# EN SU SALA (etapa 4, 26/10): la prueba es la sala y la pelea se abre por donde la abre ella (mundo_ref ya cargado).
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_cargar_turno", Game.PISO_ARENA, 424242, false):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	sala.poner("res://scenes/actors/enemy/slime.tres", Vector2(120, 0), {})
	await _esperar(20)
	if await sala.pelear() == null:
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	await _esperar(5)
	var combat: Node = null
	for n in get_tree().root.get_children() + sala.capas():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	var t = combat.turno_mapa
	if not await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 20.0):
		print("MAL: no llego un turno para andar")
		get_tree().quit(1)
		return
	var quien: Combatant = combat._player
	var inicio: Vector2 = t._inicio
	_afirmar(combat._accion_disponible(combat.Action.HABILIDAD) and combat._accion_disponible(combat.Action.OBJETO),
		"antes de cargar: Habilidades y Objetos abiertos")
	var md: MunicionData = flecha as MunicionData
	combat.habilidades._cargar(Game.HAB_CARGAR, md)
	await _esperar(3)
	print("cargadas: %d | estado %d | quien %s" % [quien.municion_quedan(), combat._state, combat._player.nombre])
	_afirmar(quien.municion_quedan() == Game.HAB_CARGAR.cargar_municion, "carga %d" % Game.HAB_CARGAR.cargar_municion)
	_afirmar(combat._state == combat.State.WAITING_PLAYER and combat._player == quien, "el turno sigue abierto")
	_afirmar(combat._actions_box.visible, "vuelve la barra de acciones")
	_afirmar(not combat._accion_disponible(combat.Action.MAGIC) and not combat._accion_disponible(combat.Action.OBJETO),
		"tras cargar: ni magia ni objetos")
	_afirmar(combat._accion_disponible(combat.Action.HABILIDAD), "tras cargar: Habilidades abierto (queda Untar)")
	combat.habilidades._untar(Game.HAB_UNTAR, untura)
	await _esperar(3)
	print("untada: estado %d reparto %s tope %d extra %d | %s" % [quien.imbue_estado, quien.imbue_reparto, quien.imbue_tope,
		quien.imbue_extra_estado, quien.imbue_etiqueta()])
	_afirmar(int(Game.consumables.get(untura, 0)) == 1, "untar gasta un frasco")
	_afirmar(quien.imbue_estado == StatusEffects.Id.VENENO and quien.imbue_usos == 10 and quien.imbue_tope == 3
		and quien.imbue_extra_estado == StatusEffects.Id.LENTO, "la untura queda puesta (veneno T2, tope 3, + Lento, 10 ataques)")
	_afirmar(combat._state == combat.State.WAITING_PLAYER and combat._player == quien, "tras untar el turno sigue")
	_afirmar(not combat._accion_disponible(combat.Action.HABILIDAD), "tras las dos: Habilidades cerrado")
	_afirmar(combat._accion_disponible(combat.Action.FLEE), "tras las dos: Pasar sigue")
	_afirmar(combat._accion_disponible(combat.Action.FLEE), "tras cargar: Pasar sigue")
	_afirmar(t._fase == t.Fase.MOVIENDO and t._inicio == inicio, "el circulo de andar no se reinicia")
	combat._on_action(combat.Action.FLEE)
	_afirmar(await _esperar_a(func() -> bool: return combat._player != quien or combat._state != combat.State.WAITING_PLAYER, 10.0),
		"al pasar, el turno acaba")
	var llega: bool = await _esperar_a(func() -> bool: return combat._state == combat.State.WAITING_PLAYER, 30.0)
	print("turno siguiente: estado %d jugador %s | llega %s | preps %s | hab %s | %s" % [combat._state, combat._player.nombre if combat._player else "-", llega, combat._preps_turno, combat._accion_disponible(combat.Action.HABILIDAD), combat._motivo_bloqueo(combat.Action.HABILIDAD)])
	_afirmar(llega and combat._preps_turno.is_empty() and combat._accion_disponible(combat.Action.HABILIDAD),
		"el turno siguiente (el de otro del grupo) vuelve a tener todo")
	# AL ACABAR la pelea lo cargado y sin disparar se QUEDA PUESTO (03/10): en la ficha, no en la bolsa.
	var pj: PersonajeData = Game.pj_de_combatant(quien)
	var en_bolsa: int = Game.municion_en_bolsa(WeaponData.Tipo.ARCO).reduce(func(a, f): return a + int(f["n"]), 0)
	# LAS FLECHAS QUE SE RECUPERAN caen en el piso de ESTA pelea (26/10): la pelea la lleva la sala, cuyo lugar es "sala",
	# y se apuntaban alli, donde no las veia nadie. Doce clavadas en el suelo, con el dado fijo (alguna se rompe).
	var donde_flechas: Vector2 = t.pies_de(quien) + Vector2(30, 0)
	for _i in 12:
		quien.municion_disparada.append({"md": md, "cal": int(MaterialItem.Calidad.NORMAL), "en": null, "pos": donde_flechas})
	var suelo_antes: Array = Net.suelo._suelo.keys()
	seed(4242)
	combat._end(false, true)
	await _esperar(2)
	var en_su_piso: int = 0
	var en_otro: int = 0
	for id in Net.suelo._suelo:
		if not suelo_antes.has(id):
			if String(Net.suelo._suelo[id]["lugar"]) == "piso:%d" % Game.PISO_ARENA:
				en_su_piso += 1
			else:
				en_otro += 1
	_afirmar(en_su_piso >= 1 and en_otro == 0, "las flechas que aguantan caen en el piso de la pelea (%d alli, %d en otro sitio)" % [
		en_su_piso, en_otro])
	combat._on_continue_pressed()
	await _esperar(10)
	var en_bolsa_fin: int = Game.municion_en_bolsa(WeaponData.Tipo.ARCO).reduce(func(a, f): return a + int(f["n"]), 0)
	print("al acabar: cargada %s | bolsa %d -> %d" % [pj.municion_cargada, en_bolsa, en_bolsa_fin])
	_afirmar((pj.municion_cargada.get("cals", []) as Array).size() == Game.HAB_CARGAR.cargar_municion
		and en_bolsa_fin == en_bolsa, "al acabar, la municion se queda cargada (no vuelve a la bolsa)")
	print("[cargar-turno] RESULTADO: %s (%d fallos)" % ["TODO BIEN" if _fallos == 0 else "HAY FALLOS", _fallos])
	get_tree().quit(1 if _fallos > 0 else 0)
