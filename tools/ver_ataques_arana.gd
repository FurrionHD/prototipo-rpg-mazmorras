# LOS ATAQUES DE LAS ARAÑAS MUTANTES CON SUS EFECTOS (03/11), en una hoja para el jefe, paso a paso sobre suelo de mazmorra,
# con los sprites horneados y un personaje de mentira (una rata) donde cae el golpe. Una fila por ataque, con el efecto que
# saca HOY en el juego: varios son aun los de otros enemigos, y esta hoja es para decidir cuales rehacer. El reloj es el de
# verdad (los efectos andan solos): la viñeta sale a cada tiempo de T. Con ventana:
#   godot --path . res://tools/ver_ataques_arana.tscn
# -> Desktop/ataques_mapa/enemigos/prueba_3d/mutantes/arana_ataques.png
extends Node2D

const LADO := 300
const ZOOM := 1.2
const SUELO := Color(0.13, 0.12, 0.14)
const T := [0.0, 0.15, 0.3, 0.45, 0.6, 0.8, 1.0, 1.3]
const CUERPO := Vector2(-60, 20)
const VICTIMA := Vector2(55, 40)

var _rotulo: Label = null
var _hoja: Image = null
var _fila: int = 0
var _nodos: Array = []
var _ed: EnemyData = null


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


func _cuerpo(sf: SpriteFrames, anim: String, pos: Vector2, ed: EnemyData) -> AnimatedSprite2D:
	var cu := Node2D.new()
	cu.position = pos
	cu.z_as_relative = false
	cu.z_index = SueloRoto.Z_SUELO + 1
	add_child(cu)
	_nodos.append(cu)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = sf
	spr.animation = StringName(anim) if sf.has_animation(anim) else &"idle_1"
	spr.frame = 0
	spr.pause()
	spr.scale = Vector2.ONE * SpritesEnemigo.escala_de(ed)
	cu.add_child(spr)
	return spr


func _a_tiempo(spr: AnimatedSprite2D, t: float) -> void:
	var n: int = spr.sprite_frames.get_frame_count(spr.animation)
	var fps: float = spr.sprite_frames.get_animation_speed(spr.animation)
	spr.frame = clampi(int(t * fps), 0, n - 1) if not spr.sprite_frames.get_animation_loop(spr.animation) else int(t * fps) % n


func _caja(pos: Vector2) -> Rect2:
	return Rect2(pos + Vector2(-16, -30), Vector2(32, 34))


# Una fila: la araña en su animacion y, en el instante del golpe ('golpe', en segundos), lo que devuelva 'lanzar'.
func _ataque(nombre: String, mut: StringName, anim: String, golpe: float, lanzar: Callable) -> void:
	var sf: SpriteFrames = SpritesEnemigo.frames_de(_ed, 0.5, true, mut)
	var ara := _cuerpo(sf, anim, CUERPO, _ed)
	var rata_ed: EnemyData = load("res://scenes/actors/enemy/rata.tres")
	_cuerpo(SpritesEnemigo.frames_de(rata_ed, 0.5), "idle_5", VICTIMA, rata_ed)
	var lanzado: bool = false
	var reloj: float = 0.0
	for i in T.size():
		var t: float = float(T[i])
		while reloj < t:
			await get_tree().process_frame
			reloj += get_process_delta_time()
			if not lanzado and reloj >= golpe:
				lanzado = true
				var n = lanzar.call()
				if n is Node:
					_nodos.append(n)
		_a_tiempo(ara, t)
		await _viñeta(i, "%s  %.2f s" % [nombre, t])
	for n in _nodos:
		if is_instance_valid(n):
			n.queue_free()
	_nodos.clear()
	_fila += 1


func _hacer() -> void:
	_hoja = Image.create(LADO * T.size(), LADO * 8, false, Image.FORMAT_RGBA8)
	BarridoAire.ritmo = 1.0
	_ed = load("res://scenes/actors/enemy/arana.tres")
	var dir: Vector2 = (VICTIMA - CUERPO).normalized()
	var red := func() -> Node:
		return SueloRoto.lanzar(self, CombatFormas.circulo(VICTIMA, 25.0), SueloRoto.Tipo.INSECTO_TELARANA, 5)
	# LA TEJEDORA
	await _ataque("Telaraña de brasas", &"tejedora", "telarana_1", 0.35, red)
	await _ataque("Hilo al rojo", &"tejedora", "hilo_1", 0.33, func() -> Node:
		return MagiaAire.arco(self, CUERPO + Vector2(0, -10), VICTIMA + Vector2(0, -10), AranaAire.NARANJA, 5, 0.0, 1.0))
	await _ataque("Capullo de ceniza", &"tejedora", "capullo_1", 0.25, func() -> Node:
		MagiaAire.arco(self, CUERPO + Vector2(0, -10), VICTIMA + Vector2(0, -10), AranaAire.NARANJA, 5, 0.0, 1.0)
		var cap := _cuerpo(SpritesEnemigo.frames_de(load("res://resources/enemigos_invocados/capullo_ceniza.tres"), 0.5), "idle_1",
			VICTIMA, load("res://resources/enemigos_invocados/capullo_ceniza.tres"))
		return cap)
	await _ataque("Explosion de brasas", &"tejedora", "explosion_1", 0.15, func() -> Node:
		return AranaAire.fogonazo(self, CUERPO, 50.0, 5))
	# LA TORMENTOSA
	await _ataque("Red electrificada", &"tormentosa", "telarana_1", 0.35, red)
	await _ataque("Mordisco electrico", &"tormentosa", "mordisco_1", 0.3, func() -> Node:
		return InsectoAire.sobre_cuerpo(self, InsectoAire.Modo.PONZONA, CUERPO, _caja(VICTIMA), 5, 0.0, 1.0))
	await _ataque("Pisoton de trueno", &"tormentosa", "pisoton_1", 0.42, func() -> Node:
		return SueloRoto.lanzar(self, CombatFormas.circulo(CUERPO, 45.0), SueloRoto.Tipo.BESTIA_PISOTON, 5))
	await _ataque("Salto de arco", &"tormentosa", "salto_1", 0.6, func() -> Node:
		return FieraAire.sobre_cuerpo(self, FieraAire.Modo.YUGULAR, CUERPO, _caja(VICTIMA), 5, 0.0, 1.0))
	var carpeta: String = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP) + "/ataques_mapa/enemigos/prueba_3d/mutantes"
	DirAccess.make_dir_recursive_absolute(carpeta)
	var ruta: String = carpeta + "/arana_ataques.png"
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
	img.convert(Image.FORMAT_RGBA8)
	var cen: Vector2i = img.get_size() / 2
	_hoja.blit_rect(img, Rect2i(cen - Vector2i(LADO, LADO) / 2, Vector2i(LADO, LADO)), Vector2i(col * LADO, _fila * LADO))
