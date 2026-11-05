# ============================================================
#  sacar_jugador_png.gd  --  HERRAMIENTA (04/11/2026, memoria efectos-pixel-personajes).
#  Saca al personaje del juego, con todas sus capas, a 1 PIXEL = 1 CELDA y con fondo transparente, para que las
#  laminas de efectos en pixel art (tools/sprites_sdf/*_efectos_pixel.py) pinten encima del cuerpo de verdad.
#  Una tira por animacion: filas = direcciones S, SE, E, NE, N; columnas = fotogramas. Y un .json con el lienzo y
#  donde caen los pies.  CON VENTANA.
#    godot --path . res://tools/sacar_jugador_png.tscn -- <animacion> <arma[+mano izq]> [salida]
#    p. ej.  ... -- lanzar varita     (la floritura de la varita: el gesto de lanzar un hechizo)
# ============================================================
extends "res://tools/ver_jugador_juego.gd"

const LIENZO := 64          # celdas por lado de cada fotograma
const PIES_Y := 48          # fila de los pies en el lienzo
const DIRS := [0, 1, 2, 3, 4]


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var anim: String = args[0] if args.size() > 0 else "lanzar"
	var arma: String = args[1] if args.size() > 1 else "varita"
	var salida: String = args[2] if args.size() > 2 else ProjectSettings.globalize_path("res://tools/salida/jugador_png")
	var p: Node2D = get_tree().get_first_node_in_group("player")
	if p == null:
		push_error("[sacar jugador] no hay Player")
		get_tree().quit(1)
		return
	Game.set_imagen_cuerpo(PackedByteArray())
	var pj: PersonajeData = Game.lider()
	var pc: Dictionary = pj.pieza("cara")
	pj.poner_pieza("cara", "chibi", pc["color"], pc["metal"])
	_equipar_para_ver(arma)
	p._pintar_cuerpo()
	p.set_physics_process(false)
	var m = p._muneco
	# A 1 pixel = 1 celda, con el cuerpo en el centro de la ventana y el fondo transparente.
	get_viewport().transparent_bg = true
	for n in get_tree().root.find_children("*", "CanvasItem", true, false):
		if n is CanvasItem and not (n as Node).is_ancestor_of(m) and n != m and not m.is_ancestor_of(n) and n != p:
			(n as CanvasItem).visible = false
	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE / SpriteLienzo.UNIDADES_POR_CELDA
	p.add_child(cam)
	cam.make_current()
	await RenderingServer.frame_post_draw
	var real: String = String(m._con_su_guardia("%s_0" % anim)).rsplit("_", true, 1)[0]
	var cols: int = maxi(1, int(PoseJugador._anim(real).get("marcos", 8)))
	var out := Image.create(cols * LIENZO, DIRS.size() * LIENZO, false, Image.FORMAT_RGBA8)
	var pies_en_pantalla: Vector2 = Vector2.ZERO
	for i in DIRS.size():
		for f in cols:
			var nom: String = "%s_%d" % [anim, int(DIRS[i])]
			m.animar(nom)
			m.fijar(nom, f)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img: Image = get_viewport().get_texture().get_image()
			# Los pies del jugador en pantalla: su nodo + lo que bajan los pies (PoseJugador.PIES_BAJO_NODO).
			var xf: Transform2D = get_viewport().get_canvas_transform()
			pies_en_pantalla = xf * (p.global_position + Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
			var org := Vector2i(roundi(pies_en_pantalla.x) - LIENZO / 2, roundi(pies_en_pantalla.y) - PIES_Y)
			out.blit_rect(img, Rect2i(org, Vector2i(LIENZO, LIENZO)), Vector2i(f * LIENZO, i * LIENZO))
	DirAccess.make_dir_recursive_absolute(salida)
	out.save_png("%s/%s_%s.png" % [salida, anim, arma.replace("+", "_")])
	var fh := FileAccess.open("%s/%s_%s.json" % [salida, anim, arma.replace("+", "_")], FileAccess.WRITE)
	fh.store_string(JSON.stringify({"lienzo": [LIENZO, LIENZO], "pies": [LIENZO / 2, PIES_Y], "marcos": cols,
		"dirs": ["S", "SE", "E", "NE", "N"], "anim": real}))
	fh.close()
	print("[sacar jugador] ", salida, "/", anim, " marcos=", cols, " real=", real)
	get_tree().quit()
