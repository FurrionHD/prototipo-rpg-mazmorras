# EL TIRON AL APARECER UN ENEMIGO (03/11, paso 7 del trent: el atlas del Espantajo era el mas grande): de cada uno, lo
# que tarda en cargar sus hojas EN FRIO (SpritesEnemigo.frames_de, la primera vez) y el fotograma en que se pinta por
# primera vez (la subida de su atlas a la grafica). Con ventana (sin ella no se sube nada):
#   godot --path . res://tools/medir_aparecer.tscn > salida.txt
# MEDIDO 03/11: Rey Slime cargar 11,5 ms, Tocon 5,1, ESPANTAJO 14,2 (1er fotograma 1 ms), Jabali ancestral 18: el atlas del
# Espantajo (BC7, ~16 MB) NO da un tiron aparte; no hace falta partirlo.
# No es una prueba: es una herramienta de medida.
extends Node2D

const CUALES := [["rey_slime", &""], ["trent", &""], ["trent", &"ambarino"], ["trent", &"espantajo"],
	["jabali", &"ancestral"]]


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)   # sin el tope de 16 ms
	call_deferred("_medir")


func _medir() -> void:
	for _i in 30:   # que se asiente el arranque
		await get_tree().process_frame
	for c in CUALES:
		var ed: EnemyData = load("res://scenes/actors/enemy/%s.tres" % c[0])
		var t0: int = Time.get_ticks_usec()
		var sf: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, c[1] != &"", c[1])
		var carga: float = float(Time.get_ticks_usec() - t0) / 1000.0
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = sf
		spr.animation = &"idle_1" if sf.has_animation("idle_1") else sf.get_animation_names()[0]
		spr.position = Vector2(200, 200)
		var t1: int = Time.get_ticks_usec()
		add_child(spr)
		await RenderingServer.frame_post_draw
		var primero: float = float(Time.get_ticks_usec() - t1) / 1000.0
		var normal: float = 0.0
		for _k in 10:
			var t2: int = Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			normal = maxf(normal, float(Time.get_ticks_usec() - t2) / 1000.0)
		print("[aparecer] %-10s %-10s cargar %6.1f ms | 1er fotograma %5.1f ms | luego, el peor %5.1f ms" % [
			c[0], c[1], carga, primero, normal])
		spr.queue_free()
	get_tree().quit(0)
