# MIRAR EL SUELO QUE SE ROMPE (SueloRoto): Temblor (grietas), Golpe sismico y Onda expansiva
# (fragmentos), cada uno en cinco momentos, en una hoja. CON VENTANA: es dibujo y hay que verlo.
#   SUELO_SALIDA=/ruta/hoja.png godot --path . res://tools/ver_suelo_roto.tscn
extends Node2D

const ZOOM := 2.3
const LADO := 470          # px de pantalla de cada viñeta
const TIEMPOS := [0.18, 0.45, 0.95, 1.55, 2.0]

var _cam: Camera2D
var _fondo_centro: Vector2 = Vector2.ZERO


func _ready() -> void:
	_cam = Camera2D.new()
	_cam.zoom = Vector2(ZOOM, ZOOM)
	add_child(_cam)
	_cam.make_current()
	call_deferred("_correr")


func _draw() -> void:
	# Un suelo de losetas oscuro, como el de la mazmorra.
	var r: int = 360
	for x in range(-r, r, 16):
		for y in range(-r, r, 16):
			var v: float = 0.17 + 0.015 * float((x / 16 + y / 16) % 2)
			draw_rect(Rect2(x, y, 16, 16), Color(v, v + 0.02, v + 0.035))
			draw_rect(Rect2(x, y, 16, 16), Color(0.11, 0.12, 0.14), false, 1.0)


func _figura(p: Vector2, col: Color) -> void:
	var fig := ColorRect.new()
	fig.color = col
	fig.size = Vector2(14, 26)
	fig.position = p - Vector2(7, 26)
	fig.z_index = 1024
	fig.z_as_relative = false
	add_child(fig)


func _correr() -> void:
	var salida: String = OS.get_environment("SUELO_SALIDA")
	if salida == "":
		salida = "user://suelo_roto.png"
	var yo: Vector2 = Vector2(-40, 10)
	_figura(yo, Color(0.35, 0.6, 1.0))
	for p in [Vector2(20, -20), Vector2(55, 30), Vector2(-90, -40), Vector2(10, 70)]:
		_figura(p, Color(0.8, 0.35, 0.35))
	# [nombre, tipo, forma, nucleo, a donde mira la camara, momentos]
	var todos: Array = [
		["temblor", SueloRoto.Tipo.GRIETAS, CombatFormas.circulo(yo, 90.0), 0.0, yo, TIEMPOS],
		["sismico", SueloRoto.Tipo.FRAGMENTOS, CombatFormas.circulo(yo + Vector2(40, 0), 65.0), 17.0, yo + Vector2(40, 0), TIEMPOS],
		["onda", SueloRoto.Tipo.FRAGMENTOS, CombatFormas.cono(yo, Vector2(1, -0.15), 120.0, 60.0), 0.0, yo + Vector2(55, -8), TIEMPOS],
		["devastador", SueloRoto.Tipo.FRAGMENTOS, CombatFormas.linea(yo, Vector2(1, -0.15), 120.0, 28.0), 0.0, yo + Vector2(58, -9), TIEMPOS],
		["guerra", SueloRoto.Tipo.ESTALLIDO, CombatFormas.circulo(Vector2(20, -20), 45.0), 18.0, Vector2(20, -40), [0.04, 0.1, 0.25, 0.55, 0.95]],
		["estela_e", SueloRoto.Tipo.ESTELA, CombatFormas.cono(yo, Vector2(1, -0.4), 30.0, 0.0), 0.0, yo + Vector2(10, -15), [0.07, 0.14, 0.2, 0.25, 0.4]],
		["estela_s", SueloRoto.Tipo.ESTELA, CombatFormas.cono(yo, Vector2(0.2, 1), 30.0, 0.0), 0.0, yo + Vector2(0, -5), [0.07, 0.14, 0.2, 0.25, 0.4]],
	]
	# SUELO_CASOS=guerra,estela_e  -> solo esas filas.
	var pedidos: String = OS.get_environment("SUELO_CASOS")
	var casos: Array = todos.filter(func(c): return pedidos == "" or String(c[0]) in pedidos.split(","))
	var hoja := Image.create(LADO * TIEMPOS.size(), LADO * casos.size(), false, Image.FORMAT_RGBA8)
	for fila in casos.size():
		var c: Array = casos[fila]
		var s: Node2D = SueloRoto.lanzar(self, c[2], c[1], 1234 + fila, c[3])
		s.set_process(false)
		_cam.global_position = c[4]
		for col in (c[5] as Array).size():
			s._t = c[5][col]
			if s.get("_geiser") != null:
				s._geiser.queue_redraw()
			s.queue_redraw()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img: Image = get_viewport().get_texture().get_image()
			var cen: Vector2i = img.get_size() / 2
			hoja.blit_rect(img, Rect2i(cen - Vector2i(LADO, LADO) / 2, Vector2i(LADO, LADO)),
				Vector2i(col * LADO, fila * LADO))
		s.queue_free()
		await get_tree().process_frame
	hoja.save_png(salida)
	print("[hoja] ", salida)
	get_tree().quit(0)
