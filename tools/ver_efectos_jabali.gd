# LOS EFECTOS DE LOS MUTANTES DEL JABALI (31/10, JabaliAire), en una hoja para el jefe, paso a paso sobre suelo de
# mazmorra. Filas: la CORNADA DE CRISTAL del Colmillo (el surco de esquirlas por su linea y, al acabar, el ESTALLIDO de
# los colmillos y su variante rota); las ESPORAS del ancestral; el REFLEJO de sus drusas hasta un mago; y la QUEMA de su
# musgo (y su variante pelada). Con ventana:
#   godot --path . res://tools/ver_efectos_jabali.tscn
# -> Desktop/ataques_mapa/enemigos/prueba_3d/mutantes/jabali_efectos.png
extends Node2D

const LADO := 300
const ZOOM := 3.0
const ESCALA := 1.15           # SpriteLienzo.UNIDADES_POR_CELDA
const SUELO := Color(0.13, 0.12, 0.14)
const T := [0.0, 0.25, 0.45, 0.6, 0.75, 0.9, 1.1, 1.35, 1.6, 1.9]

var _rotulo: Label = null
var _hoja: Image = null
var _fila: int = 0


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


func _sprite(sf: SpriteFrames, anim: String, pos: Vector2) -> AnimatedSprite2D:
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = sf
	spr.animation = StringName(anim) if sf.has_animation(anim) else &"idle_0"
	spr.frame = 0
	spr.pause()
	spr.scale = Vector2.ONE * ESCALA
	spr.position = pos
	add_child(spr)
	return spr


func _a_tiempo(spr: AnimatedSprite2D, t: float) -> void:
	var n: int = spr.sprite_frames.get_frame_count(spr.animation)
	var fps: float = spr.sprite_frames.get_animation_speed(spr.animation)
	spr.frame = clampi(int(t * fps), 0, n - 1) if not spr.sprite_frames.get_animation_loop(spr.animation) else int(t * fps) % n


func _hacer() -> void:
	var ed: EnemyData = load("res://scenes/actors/enemy/jabali.tres")
	_hoja = Image.create(LADO * T.size(), LADO * 4, false, Image.FORMAT_RGBA8)
	BarridoAire.ritmo = 1.0
	var sf_col: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, &"colmillo")
	var sf_col_r: SpriteFrames = SpritesEnemigo.frames_variante(ed, &"colmillo", &"rotos")
	# (el ancestral sin hornear: lleva la animacion 'quemandose' nueva)
	var sf_anc: SpriteFrames = Jabali3DSprites.generar_mutante_de(ed, 0.5, &"ancestral")
	var sf_anc_p: SpriteFrames = SpritesEnemigo.frames_variante(ed, &"ancestral", &"pelado")

	# LA CORNADA DE CRISTAL (mirando al E): el surco por su linea de 50 px; al acabar la animacion, el estallido y la rota.
	var col := _sprite(sf_col, "cornada_2", Vector2(-30, 0))
	var f := CombatFormas.linea(Vector2(-14, 4), Vector2.RIGHT, 50.0, 14.0)
	var surco: RataAire = RataAire.area(self, f, RataAire.Modo.SURCO_CRISTAL, 21, 0.0)
	surco.set_process(false)
	var fin_cornada: float = 8.0 / 11.0
	var est: JabaliAire = null
	for i in T.size():
		var t: float = float(T[i])
		_a_tiempo(col, t)
		surco.set("_t", t)
		for c in surco.get_children():
			(c as Node2D).queue_redraw()
		if t >= fin_cornada:
			if est == null:
				col.sprite_frames = sf_col_r
				col.animation = &"idle_2"
				est = JabaliAire.estallido(self, Vector2(6, -2), Vector2.RIGHT, 8.0, 5)
				est.set_process(false)
			est.avanzar_a(t - fin_cornada)
		await _viñeta(i, "cornada de cristal  %.2f s" % t)
	for n in [col, surco, est]:
		n.queue_free()
	_fila += 1

	# LAS ESPORAS (el ancestral recibe un golpe cuerpo a cuerpo).
	var anc := _sprite(sf_anc, "encaje_1", Vector2.ZERO)
	var esp: JabaliAire = JabaliAire.esporas(self, Vector2(0, 6), 40.0, 7)
	esp.set_process(false)
	for i in T.size():
		var t: float = float(T[i])
		_a_tiempo(anc, t)
		esp.avanzar_a(t)
		await _viñeta(i, "esporas  %.2f s" % t)
	esp.queue_free()
	_fila += 1

	# EL REFLEJO: un hechizo le entra por delante y la bola vuelve al mago (a la derecha).
	anc.animation = &"idle_2"
	anc.position = Vector2(-30, 0)
	var ref: JabaliAire = JabaliAire.reflejo(self, Vector2(6, -8), Vector2(42, -4), 9)
	ref.set_process(false)
	for i in T.size():
		var t: float = float(T[i]) * 0.4
		ref.avanzar_a(t)
		await _viñeta(i, "reflejo de las drusas  %.2f s" % t)
	ref.queue_free()
	_fila += 1

	# LA QUEMA del musgo: su animacion 'quemandose' (el musgo arde de la cabeza a la grupa) con las llamas encima del
	# frente; al acabar, pelado.
	anc.position = Vector2.ZERO
	anc.animation = &"quemandose_2"
	var qu: JabaliAire = JabaliAire.quema(self, Vector2(-2, -25), Vector2.RIGHT, 40.0, 11)
	qu.set_process(false)
	var tq := [0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 1.05, 1.25, 1.6]
	for i in tq.size():
		var t: float = float(tq[i])
		if t < JabaliAire.T_LLAMARADA:
			_a_tiempo(anc, t)
		elif anc.sprite_frames != sf_anc_p:
			anc.sprite_frames = sf_anc_p
			anc.animation = &"idle_2"
		qu.avanzar_a(t)
		await _viñeta(i, "quema del musgo  %.2f s" % t)
	qu.queue_free()
	anc.queue_free()

	var carpeta: String = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP) + "/ataques_mapa/enemigos/prueba_3d/mutantes"
	DirAccess.make_dir_recursive_absolute(carpeta)
	var ruta: String = carpeta + "/jabali_efectos.png"
	_hoja.save_png(ruta)
	print("[hoja] ", ruta)
	get_tree().quit(0)


func _viñeta(col: int, texto: String) -> void:
	var tam: Vector2 = get_viewport().get_visible_rect().size
	_rotulo.text = texto
	_rotulo.position = tam * 0.5 - Vector2(LADO, LADO) * 0.5 + Vector2(6, 4)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var cen: Vector2i = img.get_size() / 2
	_hoja.blit_rect(img, Rect2i(cen - Vector2i(LADO, LADO) / 2, Vector2i(LADO, LADO)), Vector2i(col * LADO, _fila * LADO))
