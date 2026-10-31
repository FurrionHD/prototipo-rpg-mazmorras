# LOS EFECTOS DE LOS MUTANTES DEL REY RATA (31/10, ReyRataAire), en una hoja para el jefe, paso a paso sobre suelo de
# mazmorra. Filas: el AGUJERO de la Llamada en sus tres versiones (grieta de los brotes, rejilla, charco) con las ratas
# saliendo; el TAPAZO (campanazo + chatarra, y el que lo recibe sale empujado); el FRENTE BLINDADO (chispas); la FURIA a
# nivel 1, 2 y 3. Con ventana:
#   godot --path . res://tools/ver_efectos_rey_rata.tscn
# -> Desktop/ataques_mapa/enemigos/prueba_3d/mutantes/rey_rata_efectos.png
extends Node2D

const LADO := 300
const ZOOM := 3.0
const ESCALA := 1.15           # SpriteLienzo.UNIDADES_POR_CELDA: lo que mide el sprite en el mundo
const SUELO := Color(0.13, 0.12, 0.14)
const T_AGUJERO := [0.1, 0.25, 0.4, 0.55, 0.7, 0.9, 1.1, 1.35, 1.55, 1.75]
const T_GOLPE := [0.0, 0.2, 0.35, 0.45, 0.55, 0.7, 0.9, 1.2, 1.5, 1.8]
const T_CHISPAS := [0.0, 0.04, 0.08, 0.12, 0.16, 0.2, 0.24, 0.28, 0.32, 0.36]
const T_FURIA := [0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 1.05, 1.2, 1.35]

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


func _sprite(ed: EnemyData, mut: StringName, anim: String, pos: Vector2) -> AnimatedSprite2D:
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = SpritesEnemigo.frames_de(ed, 0.5, mut != &"", mut)
	spr.animation = StringName(anim) if spr.sprite_frames.has_animation(anim) else &"idle_0"
	spr.frame = 0
	spr.pause()
	spr.scale = Vector2.ONE * ESCALA
	spr.position = pos
	add_child(spr)
	return spr


# El fotograma de 'spr' a 't' segundos de su animacion (sin pasarse del ultimo).
func _a_tiempo(spr: AnimatedSprite2D, t: float) -> void:
	var n: int = spr.sprite_frames.get_frame_count(spr.animation)
	var fps: float = spr.sprite_frames.get_animation_speed(spr.animation)
	spr.frame = clampi(int(t * fps), 0, n - 1) if not spr.sprite_frames.get_animation_loop(spr.animation) else int(t * fps) % n


func _hacer() -> void:
	var rata: EnemyData = load("res://scenes/actors/enemy/rata.tres")
	var rey: EnemyData = load("res://scenes/actors/enemy/rey_rata.tres")
	_hoja = Image.create(LADO * T_AGUJERO.size(), LADO * 8, false, Image.FORMAT_RGBA8)
	BarridoAire.ritmo = 1.0

	# EL AGUJERO, sus tres versiones: el Rey de las cloacas chilla a un lado y salen dos ratas del boquete.
	var nombres := ["grieta (brotes)", "rejilla", "charco"]
	for v in 3:
		var reyes := _sprite(rey, &"cloacas", "chillido_2", Vector2(-34, -6))
		var centro := Vector2(14, 4)
		var aj := ReyRataAire.agujero(self, centro, v, 11 + v)
		aj.set_process(false)
		var r1 := _sprite(rata, &"", "walk_1", centro)
		var r2 := _sprite(rata, &"", "walk_3", centro)
		for col in T_AGUJERO.size():
			var t: float = float(T_AGUJERO[col])
			aj.avanzar_a(t)
			_a_tiempo(reyes, t)
			var sal: float = clampf((t - ReyRataAire.t_abierto()) / 0.5, 0.0, 1.0)
			for par in [[r1, Vector2(16, 12)], [r2, Vector2(18, -14)]]:
				var r: AnimatedSprite2D = par[0]
				r.visible = t >= ReyRataAire.t_abierto() - 0.02
				r.position = centro + (par[1] as Vector2) * sal
				r.modulate.a = clampf(sal * 3.0, 0.0, 1.0)
				_a_tiempo(r, t)
			await _viñeta(col, "agujero: %s  %.2f s" % [nombres[v], t])
		for n in [reyes, aj, r1, r2]:
			n.queue_free()
		_fila += 1

	# EL TAPAZO: el Rey del desguace mirando al E descarga la tapa; a quien recibe (una rata de muñeco) le salen el
	# campanazo y la chatarra al tocar (a la mitad de su animacion) y se le empuja 40 px.
	var des := _sprite(rey, &"desguace", "tapazo_2", Vector2(-26, 0))
	var muneco := _sprite(rata, &"", "idle_6", Vector2(10, 2))
	var toca: float = 0.5 * 9.0 / 14.0
	var camp: ReyRataAire = null
	var chat: ReyRataAire = null
	for col in T_GOLPE.size():
		var t: float = float(T_GOLPE[col])
		_a_tiempo(des, t)
		if t >= toca:
			if camp == null:
				camp = ReyRataAire.golpe(self, ReyRataAire.Modo.CAMPANAZO, Vector2(8, -2), Vector2.RIGHT, 12.0, 3)
				chat = ReyRataAire.golpe(self, ReyRataAire.Modo.CHATARRA, Vector2(8, 4), Vector2.RIGHT, 12.0, 4)
				camp.set_process(false)
				chat.set_process(false)
			camp.avanzar_a(t - toca)
			chat.avanzar_a(t - toca)
			camp.visible = t - toca < camp.duracion()
			muneco.position.x = 10.0 + 40.0 * clampf((t - toca) / 0.22, 0.0, 1.0)
		await _viñeta(col, "tapazo  %.2f s" % t)
	for n in [des, muneco, camp, chat]:
		n.queue_free()
	_fila += 1

	# EL FRENTE BLINDADO: le pegan por delante (desde el E) y la tapa lo para.
	var des2 := _sprite(rey, &"desguace", "idle_2", Vector2(0, 0))
	var ch := ReyRataAire.golpe(self, ReyRataAire.Modo.CHISPAS, Vector2(6, -4), Vector2.RIGHT, 14.0, 5)
	ch.set_process(false)
	for col in T_CHISPAS.size():
		var t: float = float(T_CHISPAS[col])
		ch.avanzar_a(t)
		ch.visible = t < ch.duracion()
		await _viñeta(col, "frente blindado  %.2f s" % t)
	des2.queue_free()
	ch.queue_free()
	_fila += 1

	# LA FURIA a nivel 1, 2 y 3: el Rey de las cloacas mirando al SE.
	for lvl in [1, 2, 3]:
		var cl := _sprite(rey, &"cloacas", "idle_1", Vector2.ZERO)
		var fu := ReyRataAire.furia(self, cl, lvl, Vector2(0.7, 0.7), 6)
		fu.set_process(false)
		for col in T_FURIA.size():
			var t: float = float(T_FURIA[col])
			_a_tiempo(cl, t)
			fu.avanzar_a(t)
			await _viñeta(col, "furia nivel %d  %.2f s" % [lvl, t])
		cl.queue_free()
		fu.queue_free()
		_fila += 1

	var carpeta: String = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP) + "/ataques_mapa/enemigos/prueba_3d/mutantes"
	DirAccess.make_dir_recursive_absolute(carpeta)
	var ruta: String = carpeta + "/rey_rata_efectos.png"
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
