# MIRAR EL APUNTADO DEL COMBATE TACTICO (fase 5, el martillo). Entra en la arena, abre una pelea
# contra tres enemigos y en tu primer turno apunta el GOLPE SISMICO hacia ellos (y luego el MARTILLO
# DE GUERRA): captura la huella en el suelo, el nucleo y hacia donde mira el personaje, y cuenta a
# cuantos pilla. CON VENTANA, a proposito: la huella hay que verla.
#   TURNO_SALIDA=/ruta/apuntar godot --path . res://tools/ver_apuntar_tactico.tscn
extends Node

const BICHOS := [
	["rata", Vector2(150, -20)],
	["slime", Vector2(170, 50)],
	["slime", Vector2(120, 90)],
]
var _salida: String = ""


func _ready() -> void:
	_salida = OS.get_environment("TURNO_SALIDA")
	if _salida == "":
		_salida = "user://apuntar_tactico"
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
	print("=== APUNTAR EN EL MAPA: A OJO ===")
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

	# --- TU TURNO: apuntar ---
	var ok: bool = await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 20.0)
	if not ok:
		print("MAL: no llego un turno en el que se pueda andar")
		get_tree().quit(1)
		return
	var cuerpo: Node2D = t._cuerpo
	# Hacia el centro de los enemigos.
	var media := Vector2.ZERO
	for e in enemigos:
		media += (e as Node2D).global_position
	media /= float(enemigos.size())
	for nom in ["golpe_sismico", "martillo_de_guerra", "rompecorazas", "onda_expansiva", "temblor"]:
		var ab: AbilityData = load("res://resources/abilities/%s.tres" % nom)
		t.apuntar(ab)
		t._refrescar_apunte(media)
		await _esperar(4)
		var f = t.forma_de(ab, t._quien, media)
		print("%s: centro a %.1f px del cuerpo (hueco borde-centro), radio %.0f, pilla a %d | mira %s" % [
			nom, f.centro.distance_to(Cuerpos.caja_de(cuerpo).get_center()), f.radio,
			t.reparto_habilidad(ab, t._quien).size(), str(cuerpo.get("_facing"))])
		await _foto(nom)
		t._cancelar_apunte()
		await _esperar(2)
	# Y apuntando hacia el otro lado, lejos de todos: no pilla a nadie y el personaje se gira.
	var sis: AbilityData = load("res://resources/abilities/golpe_sismico.tres")
	t.apuntar(sis)
	t._refrescar_apunte(cuerpo.global_position + (cuerpo.global_position - media))
	await _esperar(4)
	print("sismico al reves: pilla a %d | mira %s" % [t.reparto_habilidad(sis, t._quien).size(), str(cuerpo.get("_facing"))])
	await _foto("sismico_al_reves")
	print("=== FIN ===")
	get_tree().quit(0)
