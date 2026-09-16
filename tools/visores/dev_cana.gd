# ============================================================
#  dev_cana.gd  --  HERRAMIENTA, no parte del juego.
#
#  LA CAÑA DEL JUGADOR (CanaPesca) en las 8 direcciones, con el sedal echado, y al lado las tres cañas
#  del muelle (PuebloSprites.cana_*) para compararlas. Saca tools/salida/cana_jugador.png y se cierra.
#  Con ventana:  godot --path . res://tools/visores/dev_cana.tscn
# ============================================================
extends Node2D

const SALIDA := "res://tools/salida/"
const PartidaDePrueba = preload("res://tools/visores/partida_de_prueba.gd")
const AGUA := Color(0.22, 0.42, 0.55)
const HIERBA := Color(0.31, 0.47, 0.21)
const MADERA := Color(0.45, 0.32, 0.20)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(SALIDA)
	PartidaDePrueba.llenar()
	RenderingServer.set_default_clear_color(AGUA)

	var cam := Camera2D.new()
	cam.zoom = Vector2(2.4, 2.4)
	cam.position = Vector2(260, 130)
	add_child(cam)
	cam.make_current()

	var pj: PersonajeData = Game.lider()
	# Las 8 direcciones: 0=S 1=SE 2=E 3=NE 4=N 5=NO 6=O 7=SO. Cada uno de pie en su cuadro de hierba,
	# con el corcho a 60 px hacia donde mira.
	for d in 8:
		var col: int = d % 4
		var fila: int = d / 4
		var pos := Vector2(50 + col * 110, 60 + fila * 140)
		var cesped := ColorRect.new()
		cesped.color = HIERBA
		cesped.size = Vector2(44, 40)
		cesped.position = pos - Vector2(22, 26)
		cesped.z_index = -5
		add_child(cesped)
		var dir := Vector2.from_angle(float(d) * TAU / 8.0 + PI * 0.5)
		var muneco := MunecoJugador.new()
		muneco.position = pos
		add_child(muneco)
		muneco.z_as_relative = false
		muneco.z_index = Game.Z_PERSONAJES
		muneco.montar(pj)
		muneco.tenir(pj.color, pj.metalico)
		muneco.fijar(PoseJugador.animacion(dir, 1, false), 0)
		var mano: Vector2 = pos + muneco.punto_mano(CanaPesca.mano_izquierda(dir))
		for parte in [CanaPesca.Parte.SEDAL, CanaPesca.Parte.VARA]:
			var c := CanaPesca.new()
			c.parte = parte
			c.base = mano
			c.dir = dir
			c.corcho = pos + dir * 60.0
			add_child(c)
			c.actualizar()
		var l := Label.new()
		l.text = ["S", "SE", "E", "NE", "N", "NO", "O", "SO"][SpriteLienzo.dir8(dir)]
		l.add_theme_font_size_override("font_size", 8)
		l.position = pos + Vector2(-40, -50)
		l.z_index = 4000
		add_child(l)

	# Las del muelle, en su tablero de madera.
	for i in PuebloSprites.CANA_LADOS.size():
		var lado: String = PuebloSprites.CANA_LADOS[i]
		var tablon := ColorRect.new()
		tablon.color = MADERA
		tablon.size = Vector2(32, 32)
		tablon.position = Vector2(480, 20 + i * 90) - Vector2(16, 16)
		tablon.z_index = -5
		add_child(tablon)
		var s := Sprite2D.new()
		s.texture = PuebloSprites.textura("cana_" + lado)
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = Vector2(480, 20 + i * 90) - Vector2(PuebloSprites.CANA_TAM) * 0.5
		add_child(s)

	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SALIDA + "cana_jugador.png")
	print("[cana] captura guardada")
	get_tree().quit()
