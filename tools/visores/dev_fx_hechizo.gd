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
const MOMENTOS := [0.15, 0.40, 0.70, 1.00, 1.25, 1.45]

# Una fila por efecto. El color es el que le manda combat.gd en el juego (el del elemento).
const FILAS := [
	{"estilo": CombatFX.Estilo.SHOCK_TERMICO, "elem": 1, "nombre": "Shock térmico (bola)",
		"color": Color(1.0, 0.5, 0.1)},
	{"estilo": CombatFX.Estilo.LUZ_ESTALLIDO, "elem": 4, "nombre": "Estallido solar",
		"color": Color(1.0, 0.97, 0.85)},
	{"estilo": CombatFX.Estilo.SOMBRA_VORAGINE, "elem": 5, "nombre": "Vorágine de sombra",
		"color": Color(0.42, 0.24, 0.55)},
	{"estilo": CombatFX.Estilo.CURACION_LUZ_MAYOR, "elem": 4, "nombre": "Curación MAYOR",
		"color": Color(1.0, 0.97, 0.85)},
	{"estilo": CombatFX.Estilo.CURACION_LUZ, "elem": 4, "nombre": "Curación menor",
		"color": Color(1.0, 0.97, 0.85), "peso": 1.0},
]

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

	# LOS EFECTOS QUE SE MIRAN. Cada uno en su fila, todos a la vez, porque lo que hay que juzgar no
	# es solo si cada uno esta bien: es si se DISTINGUEN entre si de un vistazo. Un estallido de luz
	# que se lee igual que una explosion de fuego no sirve por bonito que sea.
	var origen := Vector2(150.0, 380.0)
	for i in FILAS.size():
		var fila: Dictionary = FILAS[i]
		var y: float = 70.0 + 108.0 * float(i)
		# CADA ESTILO CON SU PROPIO VUELO, el de CombatFX.T_VUELO, no uno comun. Dandoles a todos el
		# del Shock (0,55) el estallido de luz se pasaba su vida entera desvaneciendose y salia en
		# blanco: la foto mentia por culpa del visor, no del efecto.
		var vuelo: float = float(CombatFX.T_VUELO.get(int(fila["estilo"]), DUR))
		# El PESO decide el tamaño (de ahi sale e["r"]), y en la curacion ademas el numero de puas:
		# es lo unico que separa la mayor de la menor.
		_capa.alta(int(fila["estilo"]), origen, Vector2(860.0, y), fila["color"],
			float(fila.get("peso", 1.5)), vuelo, 120.0, int(fila["elem"]), 0)
		var et := Label.new()
		et.text = String(fila["nombre"])
		et.position = Vector2(950.0, y - 10.0)
		et.add_theme_color_override("font_color", Color(0.7, 0.74, 0.8))
		add_child(et)

	# Se espera por el RELOJ DE VERDAD y no contando fotogramas a 60 por segundo: la ventana del
	# visor no va a 60 fijos, asi que con el contador las fotos salian todas antes de tiempo -- la
	# del "impacto" pillaba la bola aun a media distancia.
	var t0: int = Time.get_ticks_msec()
	var vapor_lanzado: bool = false
	var blanco := Vector2(860.0, 90.0)
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
