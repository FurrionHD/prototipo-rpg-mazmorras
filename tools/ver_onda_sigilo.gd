# LA ONDULACION DEL SIGILO (30/10, la rata sombria en las sombras: RataAire.onda_sigilo), en una hoja para el jefe.
# Fila 1: la sombria a la vista (de referencia) y la onda paso a paso, sobre suelo oscuro de mazmorra. Fila 2: lo mismo
# con la de cuarzo ahumado. El cuerpo, escondido como en la pelea; solo se ve lo que dibuja la onda. Con ventana:
#   godot --path . res://tools/ver_onda_sigilo.tscn
# -> Desktop/ataques_mapa/enemigos/prueba_3d/mutantes/rata_onda_sigilo.png
extends Node2D

const LADO := 220
const ZOOM := 4.0
const TIEMPOS := [0.0, 0.15, 0.3, 0.45, 0.55, 0.65, 0.8, 0.95, 1.05]
const SUELO := Color(0.13, 0.12, 0.14)

var _rotulo: Label = null


func _ready() -> void:
	RenderingServer.set_default_clear_color(SUELO)
	var cam := Camera2D.new()
	cam.zoom = Vector2(ZOOM, ZOOM)
	add_child(cam)
	cam.make_current()
	var capa := CanvasLayer.new()
	add_child(capa)
	_rotulo = Label.new()
	_rotulo.add_theme_font_size_override("font_size", 12)
	capa.add_child(_rotulo)
	call_deferred("_hacer")


func _hacer() -> void:
	var ed: EnemyData = load("res://scenes/actors/enemy/rata.tres")
	var hoja := Image.create(LADO * (TIEMPOS.size() + 1), LADO * 2, false, Image.FORMAT_RGBA8)
	var fila: int = 0
	for id in [&"sombria", &"cuarzo"]:
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = SpritesEnemigo.frames_de(ed, 0.5, true, id)
		spr.animation = &"idle_1"
		spr.frame = 0
		spr.pause()
		add_child(spr)
		# A la vista, de referencia.
		spr.visible = true
		await _viñeta(hoja, 0, fila, "%s a la vista" % ed.mutacion_de(id).nombre)
		# Escondida: solo la onda.
		spr.visible = false
		BarridoAire.ritmo = 1.0
		var onda: RataAire = RataAire.onda_sigilo(self, spr, 7 + fila)
		onda.set_process(false)
		for col in TIEMPOS.size():
			onda.set("_t", float(TIEMPOS[col]))
			for c in onda.get_children():
				(c as Node2D).queue_redraw()
			await _viñeta(hoja, col + 1, fila, "en las sombras · %.2f s" % float(TIEMPOS[col]))
		onda.queue_free()
		spr.queue_free()
		fila += 1
	var carpeta: String = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP) + "/ataques_mapa/enemigos/prueba_3d/mutantes"
	DirAccess.make_dir_recursive_absolute(carpeta)
	var ruta: String = carpeta + "/rata_onda_sigilo.png"
	hoja.save_png(ruta)
	print("[hoja] ", ruta)
	get_tree().quit(0)


func _viñeta(hoja: Image, col: int, fila: int, texto: String) -> void:
	var tam: Vector2 = get_viewport().get_visible_rect().size
	_rotulo.text = texto
	_rotulo.position = tam * 0.5 - Vector2(LADO, LADO) * 0.5 + Vector2(8, 4)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var cen: Vector2i = img.get_size() / 2
	hoja.blit_rect(img, Rect2i(cen - Vector2i(LADO, LADO) / 2, Vector2i(LADO, LADO)), Vector2i(col * LADO, fila * LADO))
