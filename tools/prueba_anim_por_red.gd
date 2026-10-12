# LA ANIMACION DE LA HABILIDAD VIAJA (12/10, playtest del 11/10: en los otros PCs el Minotauro no hacia la cornada y
# se deslizaba de pie). Con una pelea de verdad en la arena:
#   1) el bloque MARCA_ANIM de combat_espejo ida y vuelta (vacio, corto, una cadena larga y uno que no cabe);
#   2) el anfitrion lo apunta delante del golpe y SOLO cuando cambia (la embestida que pega a dos lo manda una vez);
#   3) el espejo lo lee y su cola de efectos pide 'mino_cornada' con el gesto de la habilidad.
#   godot --headless --path . res://tools/prueba_anim_por_red.tscn
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
	print("1) ida y vuelta del bloque")
	var E = load("res://scripts/ui/combat_espejo.gd")
	for nombre in [&"", &"mino_cornada", &"hinchado>aplaston>deshincharse", StringName("x".repeat(70))]:
		for g in [AbilityData.Gesto.AUTO, AbilityData.Gesto.ATRAVESAR]:
			var d: PackedInt32Array = E._bloques_anim(103, nombre, g)
			var r: Array = E._leer_anim(d, 0)
			var esperado: StringName = nombre if String(nombre).length() <= E.MAX_BYTES_ANIM else &""
			_ver(int(r[0]) == 103 and r[1] == esperado and int(r[2]) == g and int(r[3]) == d.size() and d.size() % 5 == 0,
				"'%s' gesto %d (%d enteros)" % [String(r[1]).left(20), g, d.size()])
	# Cortado a medias: no revienta, ocupa hasta el final y sale vacio.
	var dc: PackedInt32Array = E._bloques_anim(100, &"mino_cornada", 0).slice(0, 7)
	var rc: Array = E._leer_anim(dc, 0)
	_ver(rc[1] == &"" and int(rc[3]) == 7, "un paquete cortado no se lee de mas")

	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(5)
	Game.entrar_arena_de_pruebas()
	await _esperar(15)
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/guardian_rango.tres", jug.global_position + Vector2(-220, 70), {})
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
	if combat == null or combat._enemies.is_empty() or combat._aliados.size() < 2:
		print("MAL: hace falta la pelea con dos de los tuyos y el minotauro")
		get_tree().quit(1)
		return
	for c in combat._aliados + combat._enemies:
		c.max_hp = 99999.0
		c.current_hp = 99999.0
	var e: Combatant = combat._enemies[0]
	var esp = combat.espejo

	print("2) el anfitrion lo apunta delante del golpe, una vez")
	var red_antes: bool = Net.activo
	Net.activo = true
	esp._impactos_red = PackedInt32Array()
	esp._ult_anim_red.clear()
	esp._apuntar_impacto_red(e, combat._aliados[0], 5.0, false, false, -1, 0, 1.0, false, "", 7, 0,
		AbilityData.Gesto.ATRAVESAR, &"mino_cornada")
	esp._apuntar_impacto_red(e, combat._aliados[1], 5.0, false, false, -1, 0, 1.0, false, "", 9, 0,
		AbilityData.Gesto.ATRAVESAR, &"mino_cornada")
	esp._apuntar_impacto_red(e, combat._aliados[0], 3.0, false, false, -1, 0, 1.0, false, "", 11, 0)
	var datos: PackedInt32Array = esp._impactos_red
	esp._impactos_red = PackedInt32Array()
	esp._ult_anim_red.clear()
	Net.activo = red_antes
	var marcas: int = 0
	for j in range(0, datos.size(), 5):
		if datos[j] == E.MARCA_ANIM and datos[j + 1] == 100:
			marcas += 1
	# Cabeceras (el bloque del nombre lleva bytes detras de la marca, no el 100): la cornada y la vuelta a vacio.
	_ver(marcas == 2, "la cornada viaja una vez para los dos golpes y luego vuelve a vacio (%d cabeceras)" % marcas)

	print("3) el espejo la lee y la pide")
	await _esperar_a(func() -> bool: return not combat._fx.ocupada(), 10.0)
	combat._fx._cola.clear()
	combat._espejo = true
	esp._aplicar_impactos_ya(datos)
	var cola: Array = combat._fx._cola.duplicate()
	combat._espejo = false
	var anims: Array = cola.map(func(ev): return String(ev.get("anim", "")))
	var gestos: Array = cola.map(func(ev): return int(ev.get("gesto", -9)))
	print("     cola: %s / gestos %s" % [str(anims), str(gestos)])
	_ver(cola.size() == 3, "llegan los tres golpes")
	if cola.size() == 3:
		_ver(anims[0] == "mino_cornada" and anims[1] == "mino_cornada", "los dos de la embestida piden la cornada")
		_ver(gestos[0] == AbilityData.Gesto.ATRAVESAR and gestos[1] == AbilityData.Gesto.ATRAVESAR, "con el gesto de la habilidad")
		_ver(anims[2] != "mino_cornada" and gestos[2] == AbilityData.Gesto.AUTO, "el golpe de despues vuelve a lo de siempre")

	print("FIN: TODO BIEN" if _mal == 0 else "FIN: %d MAL" % _mal)
	get_tree().quit(0 if _mal == 0 else 1)
