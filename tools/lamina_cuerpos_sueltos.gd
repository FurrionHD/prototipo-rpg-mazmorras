# LA LAMINA DE CUERPOS SIN PARTIDA (03/11): la de tools/lamina_cuerpos_enemigos.gd monta la arena y pide los enemigos por
# la red, y desde la etapa 4 eso solo lo hace la sala (y en la sala cada piso se pinta en su mundo: la camara no lo ve).
# Aqui cada enemigo se pone A MANO como lo pone el juego (Enemy._aplicar_escala: su sprite con la escala del generador,
# estirado por escala_visual solo si su arte es de tamaño fijo), de frente (al sur), quieto, con tu personaje al lado y
# sobre la misma cuadricula de una casilla. Saca la misma foto y el mismo .json que la otra, asi que las marcas del jefe
# se leen igual (tools/cuerpos/sacar_cuerpos.py y aplicar_cuerpos.py). Con ventana:
#   LAMINA_SALIDA=C:/Users/dasui/Desktop/ataques_mapa/cuerpos/pagina_bichos \
#   LAMINA_ENEMIGOS=res://resources/enemigos_invocados/bicho_garrapata.tres,... godot --path . res://tools/lamina_cuerpos_sueltos.tscn
extends Node2D

const COLUMNAS := 3
const PASO := Vector2(85, 70)    # (cerca: son bichos pequeños; el zoom va en el .json)
const ZOOM := 4.0
const Tactico = preload("res://scripts/ui/combat_tactico.gd")

var _cuerpos: Array = []   # [nodo, EnemyData]


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.13, 0.12, 0.14))
	call_deferred("_hacer")


func _draw() -> void:
	var zona := Rect2(Vector2(-700, -400), Vector2(1400, 800))
	var x: float = zona.position.x
	while x <= zona.end.x:
		draw_line(Vector2(x, zona.position.y), Vector2(x, zona.end.y), Color(1, 1, 1, 0.10), 1.0)
		x += 16.0
	var y: float = zona.position.y
	while y <= zona.end.y:
		draw_line(Vector2(zona.position.x, y), Vector2(zona.end.x, y), Color(1, 1, 1, 0.10), 1.0)
		y += 16.0
	var f: Font = ThemeDB.fallback_font
	var fs: int = maxi(4, roundi(11.0 * 1.5 / ZOOM))   # (se dibuja en el mundo: con la camara cerca, letra pequeña)
	for par in _cuerpos:
		var n: Node2D = par[0]
		var t: String = String((par[1] as EnemyData).enemy_name)
		var r: Rect2 = Tactico.rect_dibujo(n)
		var bajo: float = r.end.y + float(fs) * 1.6 if r.has_area() else n.global_position.y + 30.0
		var p := Vector2(n.global_position.x - f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5, bajo)
		draw_string_outline(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 1, Color(0, 0, 0, 0.9))
		draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.85, 0.4))


func _v(p: Vector2) -> Array:
	return [snappedf(p.x, 0.1), snappedf(p.y, 0.1)]


func _hacer() -> void:
	var salida: String = OS.get_environment("LAMINA_SALIDA")
	if salida == "":
		salida = "user://lamina_cuerpos_sueltos"
	var rutas: PackedStringArray = OS.get_environment("LAMINA_ENEMIGOS").split(",", false)
	var cam := Camera2D.new()
	cam.zoom = Vector2(ZOOM, ZOOM)
	add_child(cam)
	cam.make_current()
	var filas: int = ceili(float(rutas.size()) / float(COLUMNAS))
	for i in rutas.size():
		var ed: EnemyData = load(rutas[i].strip_edges())
		var n := Node2D.new()
		n.position = Vector2((float(i % COLUMNAS) - float(COLUMNAS - 1) * 0.5) * PASO.x,
			(float(i / COLUMNAS) - float(filas - 1) * 0.5) * PASO.y + 10.0)
		add_child(n)
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = SpritesEnemigo.frames_de(ed, 0.5)
		var sur: String = SpritesEnemigo.animacion(Vector2.DOWN, false, false)   # de frente, quieto
		spr.animation = StringName(sur) if spr.sprite_frames.has_animation(sur) else spr.sprite_frames.get_animation_names()[0]
		spr.frame = 0
		spr.pause()
		var esc: float = SpritesEnemigo.escala_de(ed)
		if SpritesEnemigo.hay_que_estirar(ed):
			esc *= ed.escala_visual
		spr.scale = Vector2.ONE * esc
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		n.add_child(spr)
		_cuerpos.append([n, ed])
	await get_tree().process_frame
	# Tu personaje al lado de cada uno, con los pies a la altura de los suyos (como en la otra lamina).
	var pjs: Array = []
	for par in _cuerpos:
		var n: Node2D = par[0]
		var r: Rect2 = Tactico.rect_dibujo(n)
		var pies_y: float = r.position.y + r.size.y * 0.9 if r.has_area() else n.global_position.y
		var pj := Node2D.new()
		pj.global_position = Vector2((r.position.x if r.has_area() else n.global_position.x - 16.0) - 26.0,
			pies_y - PoseJugador.PIES_BAJO_NODO)
		add_child(pj)
		var m := MunecoJugador.new()
		pj.add_child(m)
		m.montar(Game.lider())
		m.tenir(Game.player_color, Game.player_metalico)
		m.poner_cara(Game.textura_cuerpo())
		m.animar(PoseJugador.animacion(Vector2.DOWN, 0, false))
		pjs.append(pj)
	queue_redraw()
	for _i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_1.png" % salida)
	var xf: Transform2D = get_viewport().get_canvas_transform()
	var datos: Array = []
	for i in _cuerpos.size():
		var n: Node2D = _cuerpos[i][0]
		var ed: EnemyData = _cuerpos[i][1]
		var r: Rect2 = Tactico.rect_dibujo(n)
		datos.append({"res": String(ed.resource_path), "nombre": String(ed.enemy_name), "escala": ed.escala_visual,
			"nodo": _v(xf * n.global_position), "dibujo": [_v(xf * r.position), _v(xf * r.end)],
			"pj": _v(xf * (pjs[i] as Node2D).global_position), "zoom": cam.zoom.x})
	var fa := FileAccess.open("%s_1.json" % salida, FileAccess.WRITE)
	fa.store_string(JSON.stringify(datos, "  "))
	fa.close()
	print("[foto] %s_1.png" % salida)
	get_tree().quit(0)
