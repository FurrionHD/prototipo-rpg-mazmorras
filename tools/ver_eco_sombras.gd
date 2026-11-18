# EL SET ECOLOCALIZACION CONTRA LA RATA SOMBRIA, EN UNA PELEA DE VERDAD (18/11/2026, el jefe: "como se veria la rata con el
# set del chillon"). Arena de pruebas, una rata sombria; se le pone En las sombras y se sacan tres fotos de la pantalla:
#   1 a la vista   2 en las sombras sin el set (escondida, como siempre)   3 en el turno de quien lleva el set (a medias)
# CON VENTANA; se cierra sola. Las fotos -> VER_SALIDA (carpeta).
#   godot --path . res://tools/ver_eco_sombras.tscn
extends Node

const RATA := "res://scenes/actors/enemy/rata.tres"


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	await _correr()
	get_tree().quit(0)


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _foto(nombre: String) -> void:
	await _esperar(6)
	await RenderingServer.frame_post_draw
	var dir: String = OS.get_environment("VER_SALIDA")
	if dir == "":
		dir = "user://"
	(_vp if _vp != null else get_viewport()).get_texture().get_image().save_png("%s/%s.png" % [dir, nombre])
	print("[ver] foto ", nombre)


var _vp: SubViewport = null


func _correr() -> void:
	var sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("ver_eco_sombras", Game.PISO_ARENA):
		print("[ver] no arranca la sala")
		return
	sala.poner(RATA, Vector2(70, -40), {"mutacion": "sombria"})
	await _esperar(20)
	var combat: Node = await sala.pelear(get_tree().get_nodes_in_group("enemy"), false)
	if combat == null:
		print("[ver] no se abre la pelea")
		return
	await _esperar(5)
	combat = null
	for n in get_tree().root.get_children() + sala.capas():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	if combat == null:
		print("[ver] sin pantalla de combate")
		return
	# EL PISO VA EN SU PROPIO MUNDO (un SubViewport que no se pinta): se enciende, con una camara sobre la pelea.
	_vp = sala.piso.get_parent() as SubViewport
	_vp.size = Vector2i(1280, 720)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := Camera2D.new()
	cam.zoom = Vector2(3, 3)
	sala.piso.add_child(cam)
	cam.make_current()
	var rata: Combatant = null
	for e in combat._enemies:
		if e.mutacion == &"sombria":
			rata = e
	if rata == null:
		print("[ver] sin rata sombria")
		return
	var tm = combat.turno_mapa
	cam.global_position = (tm.pies_de(rata) + tm.pies_de(combat._aliados[0])) * 0.5
	rata.sigilo_prob = 0.0   # que no entre y salga sola de las sombras mientras se sacan las fotos
	for a in combat._aliados:
		a.max_hp = 100000.0
		a.current_hp = 100000.0
	# a que sea el turno de uno de los tuyos (la pelea se queda esperando tu orden)
	var t0: int = Time.get_ticks_msec()
	while combat._state != combat.State.WAITING_PLAYER and Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame
	await _esperar(30)
	rata.quitar_estado(StatusEffects.Id.EN_SOMBRAS)
	await _foto("1_a_la_vista")
	rata.apply_status(StatusEffects.Id.EN_SOMBRAS)
	for a in combat._aliados:
		a.runa_eco = false
	await _foto("2_sombras_sin_set")
	for a in combat._aliados:
		a.runa_eco = true
	await _foto("3_sombras_turno_del_portador")
	print("[ver] ve_sombras=", Combatant.ve_sombras, " elegible=", not rata.no_elegible())
