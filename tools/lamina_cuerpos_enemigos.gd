# LAMINA PARA MARCAR A MANO EL CUERPO DE CADA ENEMIGO (09/10, el jefe: "sacame una lamina con todos los enemigos de
# frente y te marco su hitbox"). Todos MIRANDO AL SUR, quietos, sin cajas ni circulos encima, sobre una CUADRICULA de
# una casilla (16 px de mundo) y con su nombre; por paginas de 3 x 2, a buen tamaño. Al final saca por consola la
# ALTURA que se ve de cada uno y la del personaje, para comparar (el minotauro: 2,5 veces la del personaje). Con TU
# PERSONAJE al lado de cada uno, los pies a la misma altura (lo pidio el jefe: "por si tengo que corregir algo").
#
# CON VENTANA.
#   LAMINA_SALIDA=C:/Users/dasui/Desktop/ataques_mapa/cuerpos/pagina godot --path . res://tools/lamina_cuerpos_enemigos.tscn
extends Node

const COLUMNAS := 3
const FILAS := 2
const PASO := Vector2(270, 215)
const ZOOM := 1.5
const CASILLA := 16.0
const Tactico = preload("res://scripts/ui/combat_tactico.gd")
var _salida: String = ""


class Capa extends Node2D:
	var enemigos: Array = []
	var zona: Rect2

	func _draw() -> void:
		var x0: float = floorf(zona.position.x / 16.0) * 16.0
		var y0: float = floorf(zona.position.y / 16.0) * 16.0
		var x: float = x0
		while x <= zona.end.x:
			draw_line(Vector2(x, zona.position.y), Vector2(x, zona.end.y), Color(1, 1, 1, 0.10), 1.0)
			x += 16.0
		var y: float = y0
		while y <= zona.end.y:
			draw_line(Vector2(zona.position.x, y), Vector2(zona.end.x, y), Color(1, 1, 1, 0.10), 1.0)
			y += 16.0
		var f: Font = ThemeDB.fallback_font
		for e in enemigos:
			if not is_instance_valid(e):
				continue
			var t: String = String(e.data.enemy_name)
			var r: Rect2 = Tactico.rect_dibujo(e)
			var bajo: float = r.end.y + 12.0 if r.has_area() else e.global_position.y + 30.0
			var p: Vector2 = Vector2(e.global_position.x - f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x * 0.5, bajo)
			draw_string_outline(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.9))
			draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.85, 0.4))


func _v(p: Vector2) -> Array:
	return [snappedf(p.x, 0.1), snappedf(p.y, 0.1)]


func _congelar_todos() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		(e as Node).process_mode = Node.PROCESS_MODE_DISABLED


# Tu personaje, mirando al sur, a la izquierda del enemigo y con los PIES a la altura de los suyos.
func _personaje_al_lado(e: Node2D) -> void:
	var r: Rect2 = Tactico.rect_dibujo(e)
	if not r.has_area():
		r = Rect2(e.global_position - Vector2(16, 16), Vector2(32, 32))
	var pies_y: float = r.position.y + r.size.y * Tactico.centro_suelo_de(e)
	var n := Node2D.new()
	n.global_position = Vector2(r.position.x - 26.0, pies_y - PoseJugador.PIES_BAJO_NODO)
	get_tree().current_scene.add_child(n)
	e.set_meta("pj_al_lado", n)
	var m := MunecoJugador.new()
	n.add_child(m)
	m.montar(Game.lider())
	m.tenir(Game.player_color, Game.player_metalico)
	m.poner_cara(Game.textura_cuerpo())
	m.animar(PoseJugador.animacion(Vector2.DOWN, 0, false))


func _ready() -> void:
	_salida = OS.get_environment("LAMINA_SALIDA")
	if _salida == "":
		_salida = "user://lamina_cuerpos"
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
	# Que ninguno se ponga a pelear mientras se hace la foto: el jugador lejos y cada uno CONGELADO al nacer.
	var lejos: Vector2 = jug.global_position + Vector2(0, 900)
	for n in nombres:
		Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/%s.tres" % n, lejos, {})
		await _esperar(1)
		_congelar_todos()
	for _i in 20:
		await _esperar(1)
		_congelar_todos()
	var enemigos: Array = get_tree().get_nodes_in_group("enemy")
	enemigos.sort_custom(func(a, b): return String(a.data.enemy_name) < String(b.data.enemy_name))
	var origen: Vector2 = jug.global_position + Vector2(2000, 0)
	var por_pag: int = COLUMNAS * FILAS
	for i in enemigos.size():
		var e: Node2D = enemigos[i]
		var pag: int = i / por_pag
		var k: int = i % por_pag
		e.process_mode = Node.PROCESS_MODE_DISABLED
		e.global_position = origen + Vector2(pag * PASO.x * (COLUMNAS + 1) + float(k % COLUMNAS) * PASO.x,
			float(k / COLUMNAS) * PASO.y)
		# De FRENTE (al sur), en su primer marco de quieto.
		e.set("_facing", Vector2.DOWN)
		e.set("_anim_actual", "")
		if e.has_method("_actualizar_animacion"):
			e._actualizar_animacion(Vector2.ZERO)
		var spr = e.get("_sprite")
		if spr is AnimatedSprite2D:
			(spr as AnimatedSprite2D).stop()
			(spr as AnimatedSprite2D).frame = 0
		for h in e.get_children():
			if h is Line2D:
				(h as Line2D).visible = false
		_personaje_al_lado(e)
	jug.global_position = origen + Vector2(-600, 0)
	jug.visible = false
	var cam: Camera2D = jug.get_node_or_null("Camera2D") as Camera2D
	cam.top_level = true
	cam.offset = Vector2.ZERO
	cam.drag_horizontal_enabled = false
	cam.drag_vertical_enabled = false
	cam.zoom = Vector2(ZOOM, ZOOM)
	cam.position_smoothing_enabled = false
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			(n as CanvasLayer).visible = false
	for n in get_tree().get_nodes_in_group("hud"):
		if n is CanvasItem:
			(n as CanvasItem).visible = false
	for n in get_tree().current_scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var paginas: int = ceili(float(enemigos.size()) / float(por_pag))
	for pag in paginas:
		var esq: Vector2 = origen + Vector2(pag * PASO.x * (COLUMNAS + 1), 0)
		var centro: Vector2 = esq + Vector2(PASO.x * (COLUMNAS - 1) * 0.5, PASO.y * (FILAS - 1) * 0.5 - 40)
		cam.global_position = centro
		var capa := Capa.new()
		capa.enemigos = enemigos.slice(pag * por_pag, mini((pag + 1) * por_pag, enemigos.size()))
		capa.zona = Rect2(centro - Vector2(700, 400), Vector2(1400, 800))
		capa.z_as_relative = false
		capa.z_index = -1
		get_tree().current_scene.add_child(capa)
		await _esperar(4)
		await RenderingServer.frame_post_draw
		get_tree().root.get_viewport().get_texture().get_image().save_png("%s_%d.png" % [_salida, pag + 1])
		# DONDE CAE CADA UNO EN LA IMAGEN (para pasar las marcas del jefe a medidas del juego): el nodo del enemigo, su
		# dibujo y el nodo del personaje de al lado, en pixeles de la foto.
		var xf: Transform2D = get_tree().root.get_viewport().get_canvas_transform()
		var datos: Array = []
		for e in capa.enemigos:
			var r: Rect2 = Tactico.rect_dibujo(e)
			datos.append({"res": String(e.data.resource_path), "nombre": String(e.data.enemy_name),
				"escala": e.data.escala_visual, "nodo": _v(xf * e.global_position),
				"dibujo": [_v(xf * r.position), _v(xf * r.end)], "pj": _v(xf * (e.get_meta("pj_al_lado") as Node2D).global_position),
				"zoom": cam.zoom.x})
		var fa := FileAccess.open("%s_%d.json" % [_salida, pag + 1], FileAccess.WRITE)
		fa.store_string(JSON.stringify(datos, "  "))
		fa.close()
		print("[foto] %s_%d.png" % [_salida, pag + 1])
		capa.queue_free()
	# EL PERSONAJE AL LADO DEL MINOTAURO, en una foto aparte y sin cuadricula, para medir los dos en pixeles.
	for e in enemigos:
		if String(e.data.enemy_name) == "Minotauro":
			jug.visible = true
			jug.global_position = e.global_position + Vector2(-70, 0)
			jug.set("_facing", Vector2.DOWN)
			cam.global_position = e.global_position + Vector2(-35, -40)
			for o in enemigos:
				if o != e:
					o.visible = false
			await _esperar(6)
			await RenderingServer.frame_post_draw
			get_tree().root.get_viewport().get_texture().get_image().save_png("%s_comparar.png" % _salida)
			print("[foto] %s_comparar.png" % _salida)
	# LAS ALTURAS QUE SE VEN (en px de mundo), para comparar con el personaje.
	var rj: Rect2 = Tactico.rect_dibujo(jug)
	print("[alto] personaje (lo que se ve): %.1f x %.1f; caja del cuerpo %.1f" % [rj.size.x, rj.size.y, PoseJugador.CAJA_CUERPO.size.y])
	for e in enemigos:
		var r: Rect2 = Tactico.rect_dibujo(e)
		print("[alto] %s: %.1f x %.1f (escala_visual %.2f)" % [e.data.enemy_name, r.size.x, r.size.y, e.data.escala_visual])
	get_tree().quit(0)
