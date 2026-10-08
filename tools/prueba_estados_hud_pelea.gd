# LOS ESTADOS BAJO LA BARRA, EN PELEA (08/10, playtest: "durante el combate no se ven los efectos; no se si me han
# quemado, envenenado o sangrado"). Abre una pelea tactica en la mazmorra, le pone Quemadura, Veneno y Sangrado al lider
# y mira que la caja de estados de SU fila del HUD de arriba tenga esos chips. Al acabar, vuelve a los de fuera.
#   godot --headless --path . res://tools/prueba_estados_hud_pelea.tscn
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


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _caja_del_lider(jug: Node) -> HBoxContainer:
	for fila in jug._barras:
		if fila["pj"] == Game.lider():
			return fila["estados"]
	return null


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	Game.current_floor = 1
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")
	await _esperar(30)
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	var gen: DungeonGenerator = piso.gen
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var enemigos: Array = get_tree().get_nodes_in_group("enemy")
	var e: Node2D = enemigos[0]
	for otro in enemigos:
		if otro != e:
			(otro as Node2D).global_position = Vector2(-99999, -99999)
	var sala := Rect2i()
	for z in gen.zonas:
		if String(z["tipo"]) == "sala" and (z["rect"] as Rect2i).get_area() > sala.get_area():
			sala = z["rect"]
	var px: Vector2 = gen.centro_px(sala.position + sala.size / 2)
	jug.global_position = px
	e.global_position = px + Vector2(40, 0)
	await _esperar(3)
	e._start_combat(true)
	await _esperar(10)
	var combat: Node = null
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	_ver(combat != null and combat.tactico, "la pelea se abre en tactico")
	if combat == null:
		get_tree().quit(1)
		return
	var c: Combatant = Game.combatant_de_pj(Game.lider())
	_ver(c != null, "el lider tiene combatiente")
	c.apply_status(StatusEffects.Id.QUEMADURA, 3, 5.0)
	c.apply_status(StatusEffects.Id.VENENO, 3, 5.0)
	c.apply_status(StatusEffects.Id.SANGRADO, 3, 5.0)
	combat._update_hp()
	jug.refrescar_barras()
	await _esperar(2)
	var caja: HBoxContainer = _caja_del_lider(jug)
	_ver(caja != null, "el lider tiene fila en el HUD")
	var vivos: Array = []
	for h in caja.get_children():
		if not h.is_queued_for_deletion():
			vivos.append(h)
	var textos: Array = []
	for h in vivos:
		textos.append("%s (%s)" % [h.text, String(h.tooltip_text).get_slice("\n", 0)])
	print("     chips: %s" % [textos])
	_ver(vivos.size() >= 3, "bajo su barra salen los tres estados (%d chips)" % vivos.size())

	for k in combat._enemies:
		k.current_hp = 0.0
	combat._player_won = true
	combat._state = combat.State.FINISHED
	combat._on_continue_pressed()
	await _esperar(20)
	_ver(not jug._chips_de_pelea.is_valid(), "al acabar la pelea el HUD suelta los chips de la pelea")
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(0 if _mal == 0 else 1)
