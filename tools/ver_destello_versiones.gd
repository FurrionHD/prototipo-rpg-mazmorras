# LAMINA DEL DESTELLO EN CIRCULO (10/11): las versiones de los haces de FocoAire (0 plano, 1 nucleo, 2 motas, 3 abanico
# vivo, 4 todo + halo), una tras otra en la misma Campana palida, sobre el suelo de la mazmorra. Saca fotos. CON VENTANA.
#   VER_SALIDA=/ruta/pref godot --path . res://tools/ver_destello_versiones.tscn
extends Node2D

const TACTICO := preload("res://scripts/ui/combat_tactico.gd")
const FOCO := preload("res://scripts/fx/foco_aire.gd")
const VERSIONES := [0, 1, 2, 3, 4]
const PASO := 190.0
const FOTOS := [0.05, 0.12, 0.2, 0.3, 0.45, 0.6, 0.8]


func _ready() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.09, 0.11, 0.14)
	fondo.position = Vector2(-1500, -1000)
	fondo.size = Vector2(3000, 2000)
	fondo.z_as_relative = false
	fondo.z_index = -500
	add_child(fondo)
	var cam := Camera2D.new()
	cam.zoom = Vector2(3, 3)
	cam.position = Vector2(0, -40)
	add_child(cam)
	cam.make_current()
	_correr()


func _cuerpo(x: float) -> Node2D:
	var ed: EnemyData = load("res://scenes/actors/enemy/miconido.tres")
	var nodo := Node2D.new()
	nodo.z_index = Game.Z_PERSONAJES
	nodo.z_as_relative = false
	nodo.position = Vector2(x, 0)
	add_child(nodo)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = SpritesEnemigo.frames_de(ed, 0.5, true, &"campana")
	spr.scale = Vector2.ONE * SpritesEnemigo.escala_de(ed)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.name = "_sprite"
	nodo.add_child(spr)
	spr.play(&"idle_1")
	return nodo


func _correr() -> void:
	var salida: String = OS.get_environment("VER_SALIDA")
	var nodo: Node2D = _cuerpo(0.0)
	var spr: AnimatedSprite2D = nodo.get_node("_sprite")
	for _i in 10:
		await get_tree().process_frame
	var ed: EnemyData = load("res://scenes/actors/enemy/miconido.tres")
	# la camara entre la campana y el borde de abajo del circulo
	var r0: Rect2 = TACTICO.rect_dibujo(nodo)
	(get_viewport().get_camera_2d() as Camera2D).global_position = Vector2(r0.get_center().x, r0.end.y)
	var ab: AbilityData = load("res://resources/abilities/miconido_destello.tres")
	for v in VERSIONES:
		spr.play(&"destello_1")
		var r: Rect2 = TACTICO.rect_dibujo(nodo)
		var pies := Vector2(r.get_center().x, r.position.y + r.size.y * ed.centro_suelo_real())
		var n = FOCO.lanzar(self, CombatFormas.circulo(pies, ab.forma_radio), 0.0)
		n.version = v
		var t0: int = Time.get_ticks_msec()
		for k in FOTOS.size():
			while (Time.get_ticks_msec() - t0) / 1000.0 < FOTOS[k]:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s_v%d_%d.png" % [salida, v, k])
		await get_tree().create_timer(1.0).timeout
		spr.play(&"idle_1")
	print("[ver] FIN")
	get_tree().quit(0)
