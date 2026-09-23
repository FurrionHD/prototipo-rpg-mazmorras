# MIRAR EL SUELO QUE SE ROMPE EN UNA PELEA DE VERDAD (arena de pruebas): lanza una habilidad del
# martillo hacia tres enemigos y saca fotos mientras la rotura sale, con el instante en que le llega el
# golpe a cada uno. CON VENTANA.
#   SUELO_HAB=temblor SUELO_SALIDA=/ruta/pref godot --path . res://tools/ver_suelo_pelea.tscn
extends Node

const BICHOS := [
	["rata", Vector2(55, -15)],
	["slime", Vector2(80, 35)],
	["slime", Vector2(40, 60)],
]
const FOTOS := [0.15, 0.45, 0.8, 1.2, 1.7, 2.4]
var _salida: String = ""


func _ready() -> void:
	_salida = OS.get_environment("SUELO_SALIDA")
	if _salida == "":
		_salida = "user://suelo_pelea"
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
	var nom: String = OS.get_environment("SUELO_HAB")
	if nom == "":
		nom = "temblor"
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
	var t = combat.turno_mapa
	var ok: bool = await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 20.0)
	if not ok:
		print("MAL: no llego un turno en el que se pueda andar")
		get_tree().quit(1)
		return
	var media := Vector2.ZERO
	for e in enemigos:
		media += (e as Node2D).global_position
	media /= float(enemigos.size())
	var ab: AbilityData = load("res://resources/abilities/%s.tres" % nom)
	combat._player.current_energy = combat._player.max_energy
	t.apunte = media
	t._hay_apunte = true
	print("%s: pilla a %d" % [nom, t.reparto_habilidad(ab, t._quien).size()])
	combat.habilidades._usar_habilidad(ab)
	var t0: int = Time.get_ticks_msec()
	await _esperar(1)
	for ev in combat._fx._cola:
		print("  golpe: t=%.2f retraso_suelo=%.2f dmg=%.1f" % [float(ev["t"]), float(ev.get("retraso_suelo", -1.0)), float(ev["dmg"])])
	for i in FOTOS.size():
		var falta: float = FOTOS[i] - float(Time.get_ticks_msec() - t0) / 1000.0
		if falta > 0.0:
			await get_tree().create_timer(falta, true, false, true).timeout
		await _foto("%s_%d" % [nom, i])
	print("=== FIN ===")
	get_tree().quit(0)
