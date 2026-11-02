# LAS VERSIONES DE LOS EFECTOS DEL ESPANTAJO (02/11, TrentAire), en una hoja para el jefe, paso a paso sobre suelo de
# mazmorra: tres del GEISER (gotas, nube, brazos de tinta) y tres de CHUPAR (hilos, espiral, raiz). El Espantajo, de sus
# hojas SIN hornear (tools/salida/sdf/trent_sdf_espantajo, recortadas a mano: aun no esta en el juego); la victima de
# Chupar, una rata. Con ventana:
#   godot --path . res://tools/ver_efectos_trent.tscn
# -> Desktop/ataques_mapa/enemigos/prueba_3d/mutantes/trent_efectos.png
extends Node2D

const LADO := 340
const ZOOM := 1.15
const ESCALA := 1.15           # SpriteLienzo.UNIDADES_POR_CELDA
const SUELO := Color(0.13, 0.12, 0.14)
const T := [0.0, 0.3, 0.45, 0.6, 0.75, 0.9, 1.05, 1.2, 1.4, 1.6]
const HOJAS := "res://tools/salida/sdf/trent_sdf_espantajo/"
const LIENZO := Vector2(340, 400)
const DIR := 1                 # la fila de las hojas: mirando abajo a la derecha (hacia el area)

var _rotulo: Label = null
var _hoja: Image = null
var _fila: int = 0
var _esp: Sprite2D = null


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


# El Espantajo en el fotograma de 't' de su hoja 'anim' (del png, sin el motor de sprites).
func _poner(anim: String, fps: float, marcos: int, loop: bool, t: float) -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(HOJAS + anim + ".png"))
	var k: int = int(t * fps)
	k = k % marcos if loop else clampi(k, 0, marcos - 1)
	_esp.texture = ImageTexture.create_from_image(img)
	_esp.region_enabled = true
	_esp.region_rect = Rect2(Vector2(k * LIENZO.x, DIR * LIENZO.y), LIENZO)


func _hacer() -> void:
	_hoja = Image.create(LADO * T.size(), LADO * 6, false, Image.FORMAT_RGBA8)
	BarridoAire.ritmo = 1.0
	_esp = Sprite2D.new()
	_esp.centered = false
	_esp.offset = -Vector2(LIENZO.x * 0.5, LIENZO.y * 2.10 / 3.80)
	_esp.scale = Vector2.ONE * ESCALA
	_esp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_esp.position = Vector2(-70, 40)
	add_child(_esp)
	var grieta: Vector2 = _esp.position + Vector2(-10, -125)   # la grieta de la espalda, bajo la copa
	var centro := Vector2(55, 55)

	for v in 3:
		var g: TrentAire = TrentAire.geiser(self, grieta, centro, 45.0, v, 31 + v)
		g.set_process(false)
		for i in T.size():
			var t: float = float(T[i])
			_poner("geiser", 10.0, 8, false, t)
			g.avanzar_a(t)
			await _viñeta(i, "geiser %s  %.2f s" % [["A gotas", "B nube", "C brazos"][v], t])
		g.queue_free()
		_fila += 1

	var ed: EnemyData = load("res://scenes/actors/enemy/rata.tres")
	var rata := AnimatedSprite2D.new()
	rata.sprite_frames = SpritesEnemigo.frames_de(ed, 0.5, true)
	rata.animation = &"idle_5" if rata.sprite_frames.has_animation("idle_5") else &"idle_0"
	rata.scale = Vector2.ONE * ESCALA
	rata.position = centro
	add_child(rata)
	for v in 3:
		var c: TrentAire = TrentAire.chupar(self, centro + Vector2(0, 6), _esp.position + Vector2(0, 4), v, 41 + v)
		c.set_process(false)
		for i in T.size():
			var t: float = float(T[i]) * 0.8
			_poner("idle", 3.0, 8, true, t)
			c.avanzar_a(t)
			await _viñeta(i, "chupar %s  %.2f s" % [["A hilos", "B espiral", "C raiz"][v], t])
		c.queue_free()
		_fila += 1

	var carpeta: String = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP) + "/ataques_mapa/enemigos/prueba_3d/mutantes"
	DirAccess.make_dir_recursive_absolute(carpeta)
	var ruta: String = carpeta + "/trent_efectos.png"
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
