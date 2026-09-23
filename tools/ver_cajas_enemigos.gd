# MIRAR LA HITBOX DE TODOS LOS ENEMIGOS en el combate del mapa: los pone en rejilla en la arena de
# pruebas, quietos, y pinta encima de cada uno la caja por la que se le golpea (la de su DIBUJO, la
# misma cuenta que turno_mapa.bulto_de) y el punto de sus PIES (turno_mapa.pies_de). Hay que verlo:
# que la caja abrace el cuerpo que se ve, sin sombra ni aire, en los grandes y en los pequeños.
#
# CON VENTANA, a proposito.
#   CAJAS_SALIDA=/ruta/cajas godot --path . res://tools/ver_cajas_enemigos.tscn
extends Node

const COLUMNAS := 7
const PASO := Vector2(150, 150)
const Figuras = preload("res://scripts/ui/combat_figuras_mapa.gd")
const Tactico = preload("res://scripts/ui/combat_tactico.gd")
var _salida: String = ""


class Capa extends Node2D:
	var enemigos: Array = []
	var figuras = null

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		for e in enemigos:
			if not is_instance_valid(e):
				continue
			var r: Rect2 = Tactico.rect_dibujo(e)
			if not r.has_area():
				r = Cuerpos.caja_de(e)
			draw_rect(r, Color(0.2, 0.55, 1.0), false, 1.5)
			var pies: Vector2 = Vector2(r.get_center().x, r.end.y - r.size.y * Tactico.PIES_SOBRE_EL_BORDE)
			draw_circle(pies, 2.5, Color(1, 0.9, 0.2))
			draw_arc(pies, r.size.x * Tactico.PISA, 0, TAU, 24, Color(1, 0.9, 0.2, 0.7), 1.0)


func _ready() -> void:
	_salida = OS.get_environment("CAJAS_SALIDA")
	if _salida == "":
		_salida = "user://cajas_enemigos"
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
	var nombres: Array = []
	for f in DirAccess.get_files_at("res://scenes/actors/enemy/"):
		if f.ends_with(".tres"):
			nombres.append(f.get_basename())
	nombres.sort()
	# Lejos del jugador para que ninguno le embista: la rejilla empieza un buen trozo a su derecha.
	var origen: Vector2 = jug.global_position + Vector2(-PASO.x * 3, -PASO.y * 2)
	for n in nombres:
		Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/%s.tres" % n, jug.global_position + Vector2(0, 600), {})
		await _esperar(2)
	await _esperar(20)
	var enemigos: Array = get_tree().get_nodes_in_group("enemy")
	# Quietos (sin IA) y en su casilla, ordenados por nombre para poder leerlos.
	enemigos.sort_custom(func(a, b): return String(a.data.enemy_name) < String(b.data.enemy_name))
	for i in enemigos.size():
		var e: Node2D = enemigos[i]
		e.process_mode = Node.PROCESS_MODE_DISABLED
		e.global_position = origen + Vector2(float(i % COLUMNAS) * PASO.x, float(i / COLUMNAS) * PASO.y)
		for h in e.get_children():
			if h is AnimatedSprite2D:
				(h as Node).process_mode = Node.PROCESS_MODE_ALWAYS
	jug.global_position = origen + Vector2(PASO.x * 3, PASO.y * 4.2)
	var cam: Camera2D = jug.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.top_level = true
		cam.global_position = origen + Vector2(PASO.x * 3, PASO.y * 1.6)
		cam.zoom = Vector2(1.05, 1.05)
		cam.position_smoothing_enabled = false
	var capa := Capa.new()
	capa.enemigos = enemigos
	capa.figuras = Figuras.new(null)
	capa.z_as_relative = false
	capa.z_index = 4000
	get_tree().current_scene.add_child(capa) if get_tree().current_scene != null else add_child(capa)
	await _esperar(20)
	# Fuera la interfaz (si se ha abierto alguna pelea, taparia la rejilla).
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			(n as CanvasLayer).visible = false
	for n in get_tree().get_nodes_in_group("hud"):
		if n is CanvasItem:
			(n as CanvasItem).visible = false
	for n in get_tree().current_scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	await _esperar(3)
	for i in enemigos.size():
		print("%d. %s" % [i + 1, enemigos[i].data.enemy_name])
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_viewport().get_texture().get_image()
	img.save_png(_salida + ".png")
	print("[foto] ", _salida + ".png")
	get_tree().quit(0)
