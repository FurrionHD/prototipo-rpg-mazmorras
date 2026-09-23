# MIRAR EL TURNO DEL COMBATE TACTICO (fase 4). Entra en la arena, abre una pelea contra dos bichos,
# y en tu primer turno anda hacia arriba; luego espera a que un bicho se acerque. Saca capturas de
# cada momento y mide lo que no se puede ver en una foto: que la CAMARA no se mueva cuando anda el
# jugador (cuelga de el), cuanto ha andado cada uno y si se ha salido de su circulo.
#
# CON VENTANA, a proposito: el circulo en el suelo y las poses de andar hay que verlos.
#   TURNO_SALIDA=/ruta/turno godot --path . res://tools/ver_turno_tactico.tscn
extends Node

const BICHOS := [
	["rata", Vector2(150, -20)],
	["slime", Vector2(170, 50)],
]
var _salida: String = ""


func _ready() -> void:
	_salida = OS.get_environment("TURNO_SALIDA")
	if _salida == "":
		_salida = "user://turno_tactico"
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


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_viewport().get_texture().get_image()
	var ruta: String = "%s_%s.png" % [_salida, nombre]
	img.save_png(ruta)
	print("[foto] ", ruta)


func _correr() -> void:
	print("=== TURNO TACTICO: A OJO ===")
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(5)
	Game.entrar_arena_de_pruebas()
	await _esperar(15)

	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if jug == null:
		print("MAL: no hay jugador")
		get_tree().quit(1)
		return
	for b in BICHOS:
		Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/%s.tres" % b[0],
			jug.global_position + (b[1] as Vector2), {})
		await _esperar(3)
	await _esperar(20)
	var enemigos: Array = get_tree().get_nodes_in_group("enemy")
	if not Game.start_combat(enemigos, false):
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
	if combat == null or not combat.tactico:
		print("MAL: la pelea no es tactica")
		get_tree().quit(1)
		return
	var cam: Camera2D = jug.get_node_or_null("Camera2D") as Camera2D
	var t = combat.turno_mapa

	# --- TU TURNO ---
	var ok: bool = await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 20.0)
	if not ok:
		print("MAL: no llego un turno en el que se pueda andar (fase=%d, estado=%d)" % [t._fase, combat._state])
		await _foto("sin_turno")
		get_tree().quit(1)
		return
	var cuerpo: Node2D = t._cuerpo
	var inicio: Vector2 = cuerpo.global_position
	var cam_antes: Vector2 = cam.get_screen_center_position() if cam != null else Vector2.ZERO
	print("turno de %s | radio %.1f px | empieza en %s" % [t._quien.nombre, t._radio, str(inicio.round())])
	await _foto("1_turno")
	Input.action_press("move_up")
	await _esperar(20)
	await _foto("2_andando")
	# POR TIEMPO, no por fotogramas: con ventana esto va a ~150 fps y 70 fotogramas son medio segundo,
	# que a paso de turno no llega ni a la mitad del circulo.
	var t0: int = Time.get_ticks_msec()
	await _esperar_a(func() -> bool: return Time.get_ticks_msec() - t0 > 2000, 3.0)
	Input.action_release("move_up")
	await _esperar(5)
	await _foto("3_en_el_borde_del_circulo")
	var cam_despues: Vector2 = cam.get_screen_center_position() if cam != null else Vector2.ZERO
	print("anduvo %.1f px de %.1f | camara se movio %.2f px (tiene que ser 0)" % [
		cuerpo.global_position.distance_to(inicio), t._radio, cam_despues.distance_to(cam_antes)])

	# Defender cierra el turno sin pegar a nadie.
	combat._on_action(combat.Action.DEFEND)

	# --- SU TURNO ---
	ok = await _esperar_a(func() -> bool: return t._fase == t.Fase.ACERCANDO, 20.0)
	if ok:
		var su: Node2D = t._cuerpo
		var desde: Vector2 = su.global_position
		var su_radio: float = t._radio
		await _esperar(12)
		await _foto("4_bicho_acercandose")
		await _esperar_a(func() -> bool: return t._fase != t.Fase.ACERCANDO, 5.0)
		print("el bicho anduvo %.1f px de %.1f" % [su.global_position.distance_to(desde), su_radio])
		await _esperar(10)
		await _foto("5_bicho_actua")
	else:
		print("AVISO: ningun bicho tuvo que acercarse en 20 s")
	print("=== FIN ===")
	get_tree().quit(0)
