# DOS PISOS EN UN SOLO PROGRAMA (fase 2, etapa 2): el servidor monta el piso 2 y el 5 a la vez, cada uno en su mundo, y
# cada uno lleva SUS enemigos, con la fuerza de SU piso, sin mezclarse con los del otro ni tocar Game.current_floor.
# Luego congela uno (su foto), lo vuelve a montar desde ella, y salen los mismos enemigos.
#   godot --headless --path . res://tools/prueba_servidor_dos_pisos.tscn
extends Node

const _SERVIDOR := preload("res://scripts/net/servidor_pisos.gd")

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
	for i in n:
		await get_tree().physics_frame


# Espera a que el piso este construido y con enemigos (o se acabe el plazo).
func _hasta_poblado(pv: PisoVivo, tope: int = 600) -> void:
	var n: int = 0
	while n < tope:
		var suelo: Node = pv.primero(&"dungeon_floor")
		if suelo != null and suelo.get("gen") != null and not pv.nodos(&"enemy").is_empty():
			return
		await get_tree().physics_frame
		n += 1


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 4016831469
	Game.current_floor = 1
	var srv: Node = _SERVIDOR.new()
	get_tree().root.add_child(srv)

	print("1) montar el piso 2 y el 5 a la vez")
	var a: PisoVivo = srv.montar(2, 2)
	var b: PisoVivo = srv.montar(5, 5)
	await _hasta_poblado(a)
	await _hasta_poblado(b)
	var ea: Array = a.nodos(&"enemy")
	var eb: Array = b.nodos(&"enemy")
	_ver(not ea.is_empty() and not eb.is_empty(), "los dos tienen enemigos (%d y %d)" % [ea.size(), eb.size()])
	var mezclados: int = 0
	for e in ea:
		if eb.has(e) or PisoVivo.de(e) != a:
			mezclados += 1
	for e in eb:
		if PisoVivo.de(e) != b:
			mezclados += 1
	_ver(mezclados == 0, "ninguno esta en las dos listas ni es del otro piso (%d mezclados)" % mezclados)
	_ver(a.get_viewport().world_2d != b.get_viewport().world_2d, "cada piso tiene su propio mundo de fisica")
	_ver(PisoVivo.numero_de(ea[0]) == 2 and PisoVivo.numero_de(eb[0]) == 5, "cada enemigo sabe su piso (2 y 5)")
	_ver(Game.current_floor == 1, "Game.current_floor no se ha tocado (sigue en 1: %d)" % Game.current_floor)
	_ver(srv.montar(2, 2) == a, "montar uno que ya esta devuelve el mismo")

	print("2) la fuerza sale de SU piso")
	var d = (ea[0] as Node).get("data")
	if d is EnemyData:
		var c2: Combatant = d.crear_combatant(0.5, false, false, &"", 2)
		var c5: Combatant = d.crear_combatant(0.5, false, false, &"", 5)
		_ver(c5.max_hp > c2.max_hp, "el mismo enemigo en el piso 5 tiene mas vida que en el 2 (%.0f > %.0f)" % [
			c5.max_hp, c2.max_hp])

	print("3) los dos andan a la vez un rato sin mezclarse")
	await _esperar(180)
	var fuera: int = 0
	for e in a.nodos(&"enemy"):
		if not a.is_ancestor_of(e):
			fuera += 1
	for e in b.nodos(&"enemy"):
		if not b.is_ancestor_of(e):
			fuera += 1
	_ver(fuera == 0, "tras 3 s cada enemigo sigue en su piso (%d fuera)" % fuera)
	var lista_a: Array = (ea[0] as Node).call("_enemigos") if is_instance_valid(ea[0]) else []
	var ajenos: int = 0
	for e in lista_a:
		if not a.is_ancestor_of(e):
			ajenos += 1
	_ver(ajenos == 0, "la lista de vecinos de un enemigo del 2 solo trae los del 2 (%d ajenos)" % ajenos)

	print("4) congelar el piso 2 y volver a montarlo desde su foto")
	var vivos_antes: int = a.nodos(&"enemy").size() + a.nodos(&"corpse").size()
	var foto: Dictionary = srv.desmontar(2)
	_ver(not (foto.get("enemigos", []) as Array).is_empty(), "la foto trae enemigos (%d)" % (foto.get("enemigos", []) as Array).size())
	await _esperar(2)
	_ver(srv.piso(2) == null and srv.piso(5) == b, "el 2 se ha ido y el 5 sigue")
	var a2: PisoVivo = srv.montar(2, 2, foto)
	await _hasta_poblado(a2)
	var vivos_despues: int = a2.nodos(&"enemy").size() + a2.nodos(&"corpse").size()
	_ver(vivos_despues == vivos_antes, "vuelve con los mismos (%d antes, %d despues)" % [vivos_antes, vivos_despues])
	# Y CADA UNO DONDE ESTABA (con la misma semilla saldrian otros 13 en sus sitios de nacer, no en los de la foto).
	var sin_casar: int = 0
	for fe in (foto.get("enemigos", []) as Array):
		var cerca: bool = false
		for e in a2.nodos(&"enemy") + a2.nodos(&"corpse"):
			if (e as Node2D).global_position.distance_to(fe["pos"]) < 2.0:
				cerca = true
				break
		if not cerca:
			sin_casar += 1
	_ver(sin_casar == 0, "cada uno vuelve a donde estaba en la foto (%d sin casar)" % sin_casar)

	srv.desmontar(2)
	srv.desmontar(5)
	PisoVivo.por_piso = false
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(0 if _mal == 0 else 1)
