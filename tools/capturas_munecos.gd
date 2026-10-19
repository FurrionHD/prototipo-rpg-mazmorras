# ============================================================
#  CAPTURA + INVENTARIO DE LOS MUÑECOS (con ventana; optimizacion 1E, 19/10/2026). Las hojas del jugador son
#  PEREZOSAS (cada animacion se monta al pedirla): si algun sitio pusiera una animacion sin pedirla, esa capa se
#  quedaria INVISIBLE. Esto lista, en el pueblo (a una hora fija) y en una pelea del piso 8, cada muñeco con cada
#  capa: visible o no, su animacion y sus fotogramas. Pasado antes y despues de un cambio, las listas se comparan
#  con diff. Y guarda capturas en tools/salida/munecos_*.png para mirarlas.
#    godot --path . res://tools/capturas_munecos.tscn > salida.txt
# ============================================================
extends Node


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _correr() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute("res://tools/salida/")
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 4016831469
	CicloDia.hora_forzada = CicloDia.CICLO * 0.45   # de dia: guardias en su puesto y vendedores en el mercadillo
	Game.current_floor = 0
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar_jugador()
	await _frames(60)
	var jugador: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	_inventario("pueblo")
	await _captura("pueblo_jugador")
	# Al mercadillo (delante del primer puesto) y a dos guardias.
	for v in get_tree().current_scene.get_children():
		if v is VendedorMercadillo:
			jugador.global_position = (v as Node2D).global_position + Vector2(0, 110)
			break
	await _frames(20)
	await _captura("pueblo_mercadillo")
	var i: int = 0
	for g in get_tree().get_nodes_in_group("munecos_jugador"):
		var dueno: Node = (g as Node).get_parent()
		if dueno is GuardiaPueblo and (dueno as Node2D).visible:
			jugador.global_position = (dueno as Node2D).global_position + Vector2(0, 90)
			await _frames(15)
			await _captura("pueblo_guardia_%d" % i)
			i += 1
			if i >= 2:
				break
	# UNA PELEA en el piso 8.
	Game.current_floor = 8
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")
	await _esperar_jugador()
	await _frames(60)
	jugador = get_tree().get_first_node_in_group("player") as Node2D
	var presa: Node = null
	var mejor: float = INF
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.has_method("esta_muerto") and not e.esta_muerto():
			var d: float = (e as Node2D).global_position.distance_to(jugador.global_position)
			if d < mejor:
				mejor = d
				presa = e
	_inventario("piso8")
	if presa != null:
		Game.start_combat([presa], false)
		await _frames(90)
		_inventario("pelea")
		await _captura("pelea")
	get_tree().quit(0)


func _esperar_jugador() -> void:
	for k in 900:
		await get_tree().process_frame
		if get_tree().get_first_node_in_group("player") != null and not get_tree().paused:
			return


func _frames(n: int) -> void:
	for k in n:
		await get_tree().process_frame


# Cada muñeco: de quien es, su animacion, y cada capa (clave, visible, animacion, fotogramas). Ordenado, para diff.
func _inventario(donde: String) -> void:
	var filas: Array = []
	for m in get_tree().get_nodes_in_group("munecos_jugador"):
		var mu := m as MunecoJugador
		if mu == null or not mu.is_inside_tree():
			continue
		var dueno: String = String(mu.get_parent().name) if mu.get_parent() != null else "?"
		var capas: Array = []
		for c in mu._capas:
			var s: AnimatedSprite2D = c["nodo"]
			capas.append("%s:%s:%s:%d" % [c["clave"], "V" if s.visible else "-", s.animation,
				s.sprite_frames.get_frame_count(s.animation) if s.sprite_frames != null and s.sprite_frames.has_animation(s.animation) else -1])
		filas.append("%s anim=%s | %s" % [dueno, mu._anim, " ".join(capas)])
	filas.sort()
	print("[MUNECOS] ===== %s: %d munecos" % [donde, filas.size()])
	for f in filas:
		print("[MUNECOS] %s" % f)


func _captura(nombre: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tools/salida/munecos_%s.png" % nombre)
