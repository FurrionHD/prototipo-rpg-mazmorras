# LOS EFECTOS DE LAS ARAÑAS MUTANTES (03/11, AranaAire), en una hoja para el jefe, paso a paso sobre suelo de mazmorra: el
# climax de cada evolucion, la Descarga y la Explosion, sus cargas de 0 a 4 y el rebote azul entre dos personajes. Con ventana:
#   godot --path . res://tools/ver_efectos_arana.tscn
# -> Desktop/ataques_mapa/enemigos/prueba_3d/mutantes/arana_efectos.png
extends Node2D

const LADO := 300
const ZOOM := 1.6
const SUELO := Color(0.13, 0.12, 0.14)
const COLS := 8
const CARPETA := "res://assets/sprites/enemigos/arana_sdf_%s/"
const DIR := 1

var _rotulo: Label = null
var _hoja: Image = null
var _fila: int = 0
var _esp: Sprite2D = null
var _lienzo := {"tejedora": Vector2(160, 150), "tormentosa": Vector2(180, 190)}
var _pies := {"tejedora": Vector2(80, 88), "tormentosa": Vector2(90, 118)}


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
	_esp = Sprite2D.new()
	_esp.centered = false
	_esp.scale = Vector2.ONE * SpriteLienzo.UNIDADES_POR_CELDA
	_esp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_esp)
	call_deferred("_hacer")


func _poner(var_: String, anim: String, k: int, hilos: int = 0) -> void:
	var ruta: String = (CARPETA % var_) + anim + ".png"
	var img := Image.load_from_file(ProjectSettings.globalize_path(ruta))
	var lz: Vector2 = _lienzo[var_]
	var r := Rect2i(Vector2i(k * int(lz.x), DIR * int(lz.y)), Vector2i(lz))
	var foto: Image = img.get_region(r)
	# Con hilos: los grupos encendidos encima, como en el juego.
	for g in hilos:
		var suf: String = "_parpado" if g == 0 else "_parpado%d" % (g + 1)
		var capa := Image.load_from_file(ProjectSettings.globalize_path((CARPETA % var_) + anim + suf + ".png"))
		foto.blend_rect(capa, r, Vector2i.ZERO)
	_esp.texture = ImageTexture.create_from_image(foto)
	_esp.offset = -(_pies[var_] as Vector2)


func _hacer() -> void:
	_hoja = Image.create(LADO * COLS, LADO * 7, false, Image.FORMAT_RGBA8)
	BarridoAire.ritmo = 1.0
	# El climax de cada evolucion, y lo que sueltan al llenarse.
	await _rayos("tormentosa", "evolucion", 15, "climax tormentosa", true)
	await _fuego("tejedora", "evolucion", 9, "climax tejedora")
	await _rayos("tormentosa", "descarga", 2, "descarga", false)
	await _fuego("tejedora", "explosion", 2, "explosion")
	await _cargas("tormentosa", "cargas tormentosa")
	await _cargas("tejedora", "cargas tejedora")
	await _rebote()
	var carpeta: String = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP) + "/ataques_mapa/enemigos/prueba_3d/mutantes"
	DirAccess.make_dir_recursive_absolute(carpeta)
	var ruta: String = carpeta + "/arana_efectos.png"
	_hoja.save_png(ruta)
	print("[efectos] ", ruta)
	get_tree().quit()


func _rayos(var_: String, anim: String, k0: int, nombre: String, largo: bool) -> void:
	var e: AranaAire = AranaAire.rayos(self, Vector2(0, -22), 85.0 if largo else 80.0, 7)
	e.set_process(false)
	for i in COLS:
		var t: float = float(i) * AranaAire.T_RAYOS / float(COLS - 1)
		_poner(var_, anim, k0 + mini(i / 3, 1), 4 if largo else 0)
		e.avanzar_a(t)
		await _viñeta(i, "%s %.2f s" % [nombre, t])
	e.queue_free()
	_fila += 1


func _fuego(var_: String, anim: String, k0: int, nombre: String) -> void:
	var e: AranaAire = AranaAire.fogonazo(self, Vector2(0, -16), 60.0, 7)
	e.set_process(false)
	for i in COLS:
		var t: float = float(i) * AranaAire.T_FOGONAZO / float(COLS - 1)
		_poner(var_, anim, k0 + mini(i / 2, 3))
		e.avanzar_a(t)
		await _viñeta(i, "%s %.2f s" % [nombre, t])
	e.queue_free()
	_fila += 1


func _cargas(var_: String, nombre: String) -> void:
	var caja := Rect2(-34, -48, 68, 62)
	var fuego: bool = var_ == "tejedora"
	var e: AranaAire = AranaAire.pegado(self, caja, fuego, 7)
	e.set_process(false)
	for i in COLS:
		var n: int = mini(i, 4) if i < 5 else (i - 4)
		_poner(var_, "idle", 0, 0 if fuego else clampi(n, 0, 4))
		e.poner_nivel(n, 4)
		e.avanzar_a(0.1 + float(i) * 0.13)
		await _viñeta(i, "%s %d/4" % [nombre, n])
	e.queue_free()
	_fila += 1


func _rebote() -> void:
	_esp.visible = false
	for i in COLS:
		var a: MagiaAire = MagiaAire.arco(self, Vector2(-65, 10), Vector2(65, -10), AranaAire.CIAN, 9, 0.0, 1.0)
		for f in 2 + i * 3:
			await get_tree().process_frame
		await _viñeta(i, "rebote azul")
		if is_instance_valid(a):
			a.queue_free()
	_fila += 1


func _viñeta(col: int, texto: String) -> void:
	var tam: Vector2 = get_viewport().get_visible_rect().size
	_rotulo.text = texto
	_rotulo.position = tam * 0.5 - Vector2(LADO, LADO) * 0.5 + Vector2(6, 4)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var cen: Vector2i = img.get_size() / 2
	_hoja.blit_rect(img, Rect2i(cen - Vector2i(LADO, LADO) / 2, Vector2i(LADO, LADO)), Vector2i(col * LADO, _fila * LADO))
