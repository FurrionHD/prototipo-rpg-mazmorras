# VER EL REVENTON DE LA ANDANADA (10/11, revision del daño de hechizos): las 4 bolas cayendo sobre 3 cuerpos pegados
# (a 35 px), DOS LANZAMIENTOS (semillas distintas: la nube sale distinta cada vez). Saca fotos. CON VENTANA.
# (MagiaAire.REVENTON_VIEJO = true pinta el de antes: anillo y bocanada, para comparar.)
#   VER_SALIDA=/ruta/pref godot --path . res://tools/ver_andanada.tscn
extends Node2D

const CUERPOS := [Vector2(0, 0), Vector2(0, -35), Vector2(0, 35)]
const FOTOS := [0.2, 0.32, 0.45, 0.7, 1.0, 1.4, 1.9, 2.5]


class CuerposRef extends Node2D:
	func _draw() -> void:
		for p in CUERPOS:
			draw_rect(Rect2(p - Vector2(11, 8), Vector2(22, 16)), Color(0.35, 0.55, 0.35))


func _ready() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.13, 0.12, 0.14)
	fondo.position = Vector2(-400, -300)
	fondo.size = Vector2(800, 600)
	fondo.z_index = -100
	add_child(fondo)
	var c := CuerposRef.new()
	c.z_index = 50
	add_child(c)
	var cam := Camera2D.new()
	cam.zoom = Vector2(3.5, 3.5)
	add_child(cam)
	cam.make_current()
	_correr()


func _correr() -> void:
	var salida: String = OS.get_environment("VER_SALIDA")
	for r in [45, 46]:
		MagiaAire.REVENTON_VIEJO = false
		var f := CombatFormas.circulo(Vector2.ZERO, 65.0)
		f.puntos = [Vector2(2, -1), Vector2(-3, -34), Vector2(3, 36), Vector2(-1, 2)]
		var e := MagiaAire.area(self, f, MagiaAire.Modo.ANDANADA, 7 + r * 13, 0.0)
		var t0: int = Time.get_ticks_msec()
		for k in FOTOS.size():
			while (Time.get_ticks_msec() - t0) / 1000.0 < FOTOS[k]:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s_r%d_%d.png" % [salida, int(r), k])
		if is_instance_valid(e):
			e.queue_free()
		await get_tree().create_timer(0.8).timeout
	MagiaAire.REVENTON_VIEJO = false
	print("[ver] FIN")
	get_tree().quit(0)
