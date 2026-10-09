# MIRAR COMO SE VEN LOS OBJETOS TIRADOS EN EL SUELO (playtest 08/10: "los items en el suelo salen raro"). Pone un
# DropPickup de verdad por cada cosa que sueltan los enemigos (y cristales de varias categorias) sobre un suelo
# oscuro, con el zoom del juego (1,8) y otra tira de cerca (x5). CON VENTANA.
#   OBJ_SALIDA=/ruta/hoja.png godot --path . res://tools/ver_suelo_objetos.tscn
extends Node2D

const DROP := preload("res://scripts/items/drop_pickup.gd")
const PASO := 34.0

var _cam: Camera2D


func _draw() -> void:
	for x in range(-400, 400, 16):
		for y in range(-200, 200, 16):
			var v: float = 0.17 + 0.015 * float(abs(x / 16 + y / 16) % 2)
			draw_rect(Rect2(x, y, 16, 16), Color(v, v + 0.02, v + 0.035))


func _items() -> Array:
	var out: Array = []
	var vistos: Dictionary = {}
	var dir := DirAccess.open("res://scenes/actors/enemy")
	for f in dir.get_files():
		f = f.trim_suffix(".remap")
		if not f.ends_with(".tres"):
			continue
		var ed = load("res://scenes/actors/enemy/" + f)
		for campo in ["drop_material", "drop_extra", "drop_runa"]:
			var d = ed.get(campo)
			if d is MaterialData and not vistos.has(d.id):
				vistos[d.id] = true
				out.append(MaterialItem.crear(d))
	for cat in [1, 2, 3, 5]:
		var c := Cristal.new()
		c.categoria = cat
		out.append(c)
	return out


func _ready() -> void:
	_cam = Camera2D.new()
	add_child(_cam)
	_cam.make_current()
	var items := _items()
	var por_fila: int = 12
	for i in items.size():
		var p := DROP.new()
		p.setup(items[i])
		p.position = Vector2(-por_fila * PASO * 0.5 + (i % por_fila) * PASO, -60 + (i / por_fila) * PASO)
		add_child(p)
		print(i, ": ", Game.item_display_name(items[i]))
	call_deferred("_correr")


func _correr() -> void:
	var salida: String = OS.get_environment("OBJ_SALIDA")
	if salida == "":
		salida = "user://suelo_objetos"
	for z in [1.8, 5.0]:
		_cam.zoom = Vector2(z, z)
		_cam.position = Vector2(-150, -40) if z > 2.0 else Vector2.ZERO
		await get_tree().create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_z%d.png" % [salida, int(z)])
	get_tree().quit()
