# LAMINA DE LAS MARCAS DE GOLPE DE TODOS LOS ENEMIGOS (09/10, el jefe: "una carpeta nueva con las marcas de golpe de todos
# los ataques de los enemigos, una vez hechos los cambios, y te corrijo"). Por enemigo, una hoja con una casilla por
# habilidad suya (las de su ficha que tienen huella en el mapa) y una para su basico: el enemigo quieto MIRANDO AL ESTE,
# su CUERPO marcado en rojo, su centro, la raya de su alcance en azul y la HUELLA de la habilidad hacia el este en
# naranja, calculada con la MISMA cuenta que la pelea (CombatTactico.forma_enemigo). Tu personaje al lado, de escala.
#
# CON VENTANA.
#   GOLPES_SALIDA=C:/Users/dasui/Desktop/ataques_mapa/golpes_enemigos godot --path . res://tools/lamina_golpes_enemigos.tscn
extends Node

const ZOOM := 1.5
const CELDA := Vector2i(420, 330)    # lo que se recorta de pantalla por casilla
const COLUMNAS := 3
const FILAS := 2
const Tactico = preload("res://scripts/ui/combat_tactico.gd")
var _salida: String = ""


class Capa extends Node2D:
	var e: Node2D = null
	var formas: Array = []      # [Forma, Color]
	var caja: Rect2
	var centro: Vector2
	var alcance: float = 0.0
	var titulo: String = ""

	func _draw() -> void:
		if e == null:
			return
		var z: Rect2 = Rect2(e.global_position - Vector2(300, 220), Vector2(600, 440))
		var x: float = floorf(z.position.x / 16.0) * 16.0
		while x <= z.end.x:
			draw_line(Vector2(x, z.position.y), Vector2(x, z.end.y), Color(1, 1, 1, 0.08), 1.0)
			x += 16.0
		var y: float = floorf(z.position.y / 16.0) * 16.0
		while y <= z.end.y:
			draw_line(Vector2(z.position.x, y), Vector2(z.end.x, y), Color(1, 1, 1, 0.08), 1.0)
			y += 16.0
		for par in formas:
			CombatFormas.dibujar(par[0], self, par[1])
		draw_rect(caja, Color(1, 0.15, 0.15), false, 1.5)
		draw_circle(centro, 2.0, Color(0.3, 0.5, 1.0))
		if alcance > 0.0:
			var fin := centro + Vector2(alcance, 0)
			draw_line(centro, fin, Color(0.3, 0.5, 1.0, 0.7), 1.0)
			draw_line(fin + Vector2(0, -8), fin + Vector2(0, 8), Color(0.3, 0.5, 1.0), 2.0)
		# El nombre arriba a la izquierda de la casilla (la casilla se recorta centrada en e + (60, 0)).
		var ft: Font = ThemeDB.fallback_font
		var p: Vector2 = e.global_position + Vector2(60, 0) + Vector2(-130, -100)
		draw_string_outline(ft, p, titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0, 0, 0, 0.9))
		draw_string(ft, p, titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.85, 0.4))


func _ready() -> void:
	_salida = OS.get_environment("GOLPES_SALIDA")
	if _salida == "":
		_salida = "user://golpes_enemigos"
	DirAccess.make_dir_recursive_absolute(_salida)
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


func _congelar_todos() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		(e as Node).process_mode = Node.PROCESS_MODE_DISABLED


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
	var sitio: Vector2 = jug.global_position + Vector2(2000, 0)
	jug.visible = false
	var cam: Camera2D = jug.get_node_or_null("Camera2D") as Camera2D
	cam.top_level = true
	cam.offset = Vector2.ZERO
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(ZOOM, ZOOM)
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			(n as CanvasLayer).visible = false
	for n in get_tree().get_nodes_in_group("hud"):
		if n is CanvasItem:
			(n as CanvasItem).visible = false
	for n in get_tree().current_scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var muneco := Node2D.new()
	get_tree().current_scene.add_child(muneco)
	var m := MunecoJugador.new()
	muneco.add_child(m)
	m.montar(Game.lider())
	m.tenir(Game.player_color, Game.player_metalico)
	m.poner_cara(Game.textura_cuerpo())
	m.animar(PoseJugador.animacion(Vector2.RIGHT, 0, false))
	var capa := Capa.new()
	capa.z_as_relative = false
	capa.z_index = 3000
	get_tree().current_scene.add_child(capa)
	for e in enemigos:
		for o in enemigos:
			(o as Node2D).visible = o == e
		e.global_position = sitio
		e.set("_facing", Vector2.RIGHT)
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
		var ed: EnemyData = e.data
		var caja: Rect2 = Cuerpos.caja_de(e)
		var pies: Vector2 = e.global_position + (e.centro_golpe() if e.has_method("centro_golpe") else Vector2.ZERO)
		var refr: Rect2 = Tactico.ancho_de_dibujo(e) if ed.golpe_ancho_dibujo else caja
		var alcance: float = ed.alcance_real()
		muneco.global_position = Vector2(caja.position.x - 30.0, caja.end.y - PoseJugador.CAJA_CUERPO.end.y)
		cam.global_position = e.global_position + Vector2(60, 0)
		capa.e = e
		capa.caja = caja
		capa.centro = pies
		capa.alcance = alcance
		# Las casillas: el basico y cada habilidad con huella.
		var casillas: Array = [["Basico (alcance %.0f)" % alcance, null]]
		for ab in ed.habilidades:
			if ab is AbilityData and int((ab as AbilityData).forma) >= 0:
				casillas.append([String((ab as AbilityData).nombre), ab])
		var paginas: int = ceili(float(casillas.size()) / float(COLUMNAS * FILAS))
		for pg in paginas:
			var hoja := Image.create(CELDA.x * COLUMNAS, CELDA.y * FILAS, false, Image.FORMAT_RGBA8)
			hoja.fill(Color(0.18, 0.18, 0.2))
			for k in COLUMNAS * FILAS:
				var idx: int = pg * COLUMNAS * FILAS + k
				if idx >= casillas.size():
					break
				var ab = casillas[idx][1]
				capa.formas = []
				capa.titulo = "%s - %s" % [ed.enemy_name, String(casillas[idx][0])]
				if ab != null:
					var hacia: Vector2 = pies + Vector2(maxf(alcance, 40.0) + 30.0, 0)
					capa.formas = [[Tactico.forma_enemigo(ab, pies, caja, refr, alcance, hacia), Color(1.0, 0.6, 0.15)]]
				capa.queue_redraw()
				await _esperar(3)
				await RenderingServer.frame_post_draw
				var img: Image = get_tree().root.get_viewport().get_texture().get_image()
				var xf: Transform2D = get_tree().root.get_viewport().get_canvas_transform()
				var c: Vector2 = xf * (e.global_position + Vector2(60, 0))
				var rec := Rect2i(Vector2i(int(c.x) - CELDA.x / 2, int(c.y) - CELDA.y / 2), CELDA)
				rec = rec.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
				var dst := Vector2i((k % COLUMNAS) * CELDA.x, (k / COLUMNAS) * CELDA.y)
				hoja.blit_rect(img, rec, dst)
			var nombre: String = String(ed.resource_path).get_file().get_basename()
			var ruta: String = "%s/%s%s.png" % [_salida, nombre, "" if paginas == 1 else "_%d" % (pg + 1)]
			hoja.save_png(ruta)
			print("[foto] ", ruta, "  (", ed.enemy_name, ")")
	get_tree().quit(0)
