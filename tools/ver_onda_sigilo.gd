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
const PISO := 3   # el de las ratas

var _rotulo: Label = null


func _ready() -> void:
	RenderingServer.set_default_clear_color(SUELO)
	var cam := Camera2D.new()
	cam.zoom = Vector2(ZOOM, ZOOM)
	add_child(cam)
	cam.make_current()
	# (10/11, el jefe: "necesito verlo en un suelo de verdad") EL SUELO DE LA MAZMORRA detras, el del piso de las ratas: la
	# onda ya no pinta color, corre lo de detras; sobre liso no se veria nada.
	var ts: TileSet = TerrenoSprites.tileset_de_tramos(TerrenoSprites.tramos_de(PISO))
	var suelo := TileMapLayer.new()
	suelo.tile_set = ts
	suelo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	suelo.z_index = -100
	for y in range(-12, 12):
		for x in range(-12, 12):
			var c := Vector2i(x, y)
			suelo.set_cell(c, 0, TerrenoSprites.celda_para("suelo", c, 0, 7))
	add_child(suelo)
	var capa := CanvasLayer.new()
	add_child(capa)
	_rotulo = Label.new()
	_rotulo.add_theme_font_size_override("font_size", 12)
	capa.add_child(_rotulo)
	if OS.get_environment("VER_VIVO") == "1":
		call_deferred("_vivo")
	else:
		call_deferred("_hacer")


# (10/11) EN VIVO, para verlo moverse (en foto fija no se ve un temblor): a la izquierda la sombria a la vista, a la
# derecha escondida y ondulando cada 2,5 s (en la pelea, cada 20-30 s). Se cierra sola a los 40 s.
#   VER_VIVO=1 godot --path . res://tools/ver_onda_sigilo.tscn
func _vivo() -> void:
	var ed: EnemyData = load("res://scenes/actors/enemy/rata.tres")
	var ver := AnimatedSprite2D.new()
	ver.sprite_frames = SpritesEnemigo.frames_de(ed, 0.5, true, &"sombria")
	ver.animation = &"idle_1"
	ver.position = Vector2(-28, 0)
	ver.play()
	add_child(ver)
	var esc := AnimatedSprite2D.new()
	esc.sprite_frames = ver.sprite_frames
	esc.animation = &"idle_1"
	esc.position = Vector2(28, 0)
	esc.play()
	esc.visible = false
	add_child(esc)
	_rotulo.text = "izquierda: a la vista  ·  derecha: en las sombras (ondula cada 2,5 s; en la pelea, cada 20-30 s)"
	_rotulo.position = Vector2(12, 8)
	BarridoAire.ritmo = 1.0
	var t: float = 0.0
	var prox: float = 1.0
	while t < 40.0:
		await get_tree().process_frame
		var dt: float = get_process_delta_time()
		t += dt
		prox -= dt
		if prox <= 0.0:
			prox = 2.5
			RataAire.onda_sigilo(self, esc, randi())
	get_tree().quit(0)


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
			onda.queue_redraw()   # (10/11: la onda se dibuja ella misma; antes solo se repintaban sus hijos y salia vacia)
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
