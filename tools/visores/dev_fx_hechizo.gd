# ============================================================
#  dev_fx_hechizo.gd  --  HERRAMIENTA, no parte del juego.
#
#  Mira el DIBUJO de un hechizo sin tener que montar un combate: da de alta el efecto en una
#  CapaHechizos de verdad y saca capturas a lo largo del vuelo y del impacto.
#
#  Nace para el SHOCK TERMICO, que necesitaba dibujo propio: con el reparto por elemento salia como
#  una bola de fuego y, detras, la OLA del agua barriendo la fila -- dos conjuros seguidos en vez de
#  un impacto que primero quema y luego moja.
#
#  Saca las capturas EN VARIOS INSTANTES a proposito: una sola foto de un efecto que dura medio
#  segundo no dice si se lee. Hay que ver el vuelo, el momento del impacto y el reventon.
#
#  Va CON VENTANA: sin superficie de render no se dibuja nada.
#    godot --path . res://tools/visores/dev_fx_hechizo.tscn
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
# Los instantes que se fotografian, en segundos desde que sale. DUR es el vuelo.
const DUR := 0.55
# El reventon dura poco y se apaga enseguida: los ultimos tres van MUY juntos porque si no la
# ventana entera del impacto se cuela entre dos fotos y sale una captura en negro.
# Vuelo (0,15-0,50), el reventon de fuego con su compresion (0,58-0,70) y el vapor (0,85-1,20).
const MOMENTOS := [0.15, 0.35, 0.50, 0.58, 0.66, 0.72, 0.85, 1.00, 1.20]

var _capa: CapaHechizos = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1280, 720))

	# Un fondo oscuro como el del combate: sobre gris claro, un efecto naranja miente.
	var fondo := ColorRect.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.07, 0.08, 0.11)
	add_child(fondo)

	_capa = CapaHechizos.new()
	add_child(_capa)
	DirAccess.make_dir_recursive_absolute(SALIDA)

	# LOS DOS GOLPES DEL SHOCK TERMICO, uno debajo del otro, para verlos a la vez: el de FUEGO
	# (golpe 0) y el de AGUA (golpe 1). Son las dos mitades del mismo impacto y hay que juzgarlas
	# juntas, no una foto de cada.
	# UNA SOLA BOLA. El golpe de fuego es el que vuela; el de agua NO viaja -- nace donde cayo la
	# bola y solo hace el vapor.
	#
	# Y EL DE AGUA SE LANZA MAS TARDE, no a la vez. En combate los dos golpes van en TANDAS distintas
	# (CombatFX.tanda), asi que el vapor sale cuando la bola ya ha reventado. Lanzandolos juntos, la
	# primera captura salio con la nube de vapor abierta mientras la bola aun cruzaba la pantalla:
	# una foto que enseña algo que en el juego no pasa es peor que no tener foto.
	var origen := Vector2(180.0, 380.0)
	var blanco := Vector2(880.0, 300.0)
	_capa.alta(CombatFX.Estilo.SHOCK_TERMICO, origen, blanco,
		Color(1.0, 0.5, 0.1), 1.5, DUR, 120.0, Elementos.Elemento.FUEGO, 0)
	# La BOLA DE FUEGO de siempre, como referencia de TAMAÑO: la nueva tiene que verse claramente
	# mas gorda o no habra servido de nada.
	_capa.alta(CombatFX.Estilo.PROYECTIL, origen + Vector2(0.0, 240.0),
		blanco + Vector2(0.0, 300.0), Color(1.0, 0.5, 0.1), 1.5, DUR, 120.0,
		Elementos.Elemento.FUEGO, 0)

	# Se espera por el RELOJ DE VERDAD y no contando fotogramas a 60 por segundo: la ventana del
	# visor no va a 60 fijos, asi que con el contador las fotos salian todas antes de tiempo -- la
	# del "impacto" pillaba la bola aun a media distancia.
	var t0: int = Time.get_ticks_msec()
	var vapor_lanzado: bool = false
	for m in MOMENTOS:
		while float(Time.get_ticks_msec() - t0) / 1000.0 < float(m):
			await get_tree().process_frame
			# El vapor entra cuando el fuego ya se ha comprimido, que es su sitio en la secuencia.
			if not vapor_lanzado and float(Time.get_ticks_msec() - t0) / 1000.0 >= DUR + 0.20:
				vapor_lanzado = true
				_capa.alta(CombatFX.Estilo.SHOCK_TERMICO, blanco, blanco,
					Color(0.4, 0.7, 1.0), 1.5, DUR, 120.0, Elementos.Elemento.AGUA, 1)
		await RenderingServer.frame_post_draw
		var ruta: String = "%sfx_shock_%03d.png" % [SALIDA, int(float(m) * 100.0)]
		get_viewport().get_texture().get_image().save_png(ruta)
		print("[fx] %.2fs -> %s" % [m, ProjectSettings.globalize_path(ruta)])

	print("[fx] listo.")
	get_tree().quit(0)
