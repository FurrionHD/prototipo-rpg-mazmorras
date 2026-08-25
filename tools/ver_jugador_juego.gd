# ============================================================
#  ver_jugador_juego.gd  --  HERRAMIENTA, no parte del juego.
#
#  Saca una hoja del personaje TAL CUAL SE VE EN LA PARTIDA: montado por MunecoJugador, teñido con
#  su color y pasado por capa_jugador.gdshader. Es el hermano de ver_jugador.bat, que enseña el
#  horneado en gris.
#
#  Y NO SOBRA, aunque parezca lo mismo. Los fallos que ha encontrado esta y no la otra:
#    * el tinte multiplicando OSCURECIA el personaje entero (0,48 x 0,45 = 0,21),
#    * el contorno se comia los miembros: en gris pasaba por una linea de dibujo, teñido no,
#    * el antebrazo en tono piel salia como un brochazo claro cruzando el pecho.
#  Todos son de COLOR, y en una hoja gris no existen. La regla que sale de ahi: lo que se juzga en
#  gris es la silueta y el movimiento; lo que se juzga teñido es si se entiende.
#
#  Necesita VENTANA (con --headless no se dibuja nada), asi que va por ver_jugador_juego.bat.
#
#    ver_jugador_juego.bat [animacion] [direcciones]
#    ver_jugador_juego.bat walk 8        las ocho, un fotograma cada una
#    ver_jugador_juego.bat walk 1,2,3    esas tres, con todos sus fotogramas
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
const ZOOM := 5
const LADO := 56
const FONDO := Color(0.11, 0.12, 0.15)
# El color con el que se tiñe. Uno CUALQUIERA menos el blanco: en blanco el tinte no multiplica nada
# y la hoja seria la gris otra vez, que es justo la que no queremos duplicar.
const TINTE := Color(0.85, 0.25, 0.22)


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var anim: String = args[0] if args.size() > 0 else "walk"
	var dirs: Array = []
	if args.size() > 1 and args[1].contains(","):
		for s in args[1].split(","):
			dirs.append(clampi(int(s), 0, 7))
	else:
		for d in 8:
			dirs.append(d)

	var p: Node2D = get_tree().get_first_node_in_group("player")
	if p == null:
		push_error("[ver jugador juego] no hay Player en la escena")
		get_tree().quit(1)
		return
	Game.player_color = TINTE
	p._pintar_cuerpo()
	# EL JUGADOR REIMPONE SU ANIMACION EN CADA FRAME DE FISICA (ver player._actualizar_animacion), asi
	# que sin pararlo esto captura ocho veces el idle y parece que las direcciones no cambian. Costo
	# una hoja entera de fotos identicas antes de caer.
	p.set_physics_process(false)
	var m = p._muneco
	if m == null or not m.hay_dibujo():
		push_error("[ver jugador juego] el muneco no se ha montado (¿falta hornear?)")
		get_tree().quit(1)
		return

	# Una fila por direccion pedida, una columna por fotograma. Con las ocho direcciones se enseña
	# solo un fotograma de cada (la hoja seria de 64 casillas y no cabe nada).
	var una_sola: bool = dirs.size() >= 8
	var cols: int = 1 if una_sola else 8
	var filas: int = dirs.size() if not una_sola else 1
	var ancho: int = (dirs.size() if una_sola else cols) * LADO
	var out := Image.create(ancho, maxi(1, filas) * LADO, false, Image.FORMAT_RGBA8)
	out.fill(FONDO)
	for i in dirs.size():
		for f in cols:
			var nom: String = "%s_%d" % [anim, int(dirs[i])]
			m.animar(nom)
			m.fijar(nom, f if not una_sola else 2)
			# DOS frames de espera y no uno: el primero aplica el cambio de fotograma y el segundo es
			# el que de verdad lo dibuja. Con uno solo, cada captura salia con la pose ANTERIOR.
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img: Image = get_viewport().get_texture().get_image()
			var cx: int = img.get_width() / 2
			var cy: int = img.get_height() / 2
			var trozo: Image = img.get_region(Rect2i(cx - LADO / 2, cy - LADO / 2 - 8, LADO, LADO))
			var en := Vector2i(i * LADO, 0) if una_sola else Vector2i(f * LADO, i * LADO)
			out.blit_rect(trozo, Rect2i(0, 0, LADO, LADO), en)
	out.resize(out.get_width() * ZOOM, out.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(SALIDA)
	var ruta: String = "%sjuego_jugador_%s.png" % [SALIDA, anim]
	out.save_png(ruta)
	print("[ver jugador juego] %s · direcciones %s" % [anim, str(dirs)])
	print("[ver jugador juego] ", ProjectSettings.globalize_path(ruta))
	get_tree().quit()
