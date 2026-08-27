# ============================================================
#  ver_creador.gd  --  HERRAMIENTA, no parte del juego.
#
#  Abre la pantalla de creacion de personaje SOLA y saca una captura de cada fase. Existe porque el
#  creador es la pieza con mas interfaz de todo el proyecto y para llegar a el en el juego hay que
#  pasar por el menu principal: sin esto, la unica forma de saber si monta bien es que lo abra el
#  jugador.
#
#  NECESITA VENTANA: con --headless no se dibuja nada y las capturas salen en negro (misma nota que
#  ver_jugador_juego.gd).
#
#    ver_creador.bat
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"


func _ready() -> void:
	# Una partida de mentira para que Game.lider() exista y el creador tenga con que arrancar.
	Game.nueva_partida("Prueba", {"color": Color(0.35, 0.62, 0.95)})
	# 'ver_creador.bat mundo' abre el MODO SIMPLE (el de bautizar un mundo compartido): sin fases,
	# sin muñeco. Esta aqui porque es el camino que nadie mira y el que se rompe al tocar el otro.
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var simple: bool = args.size() > 0 and args[0] == "mundo"
	var previo: Dictionary = {"color": Color(0.35, 0.62, 0.95)}
	if simple:
		previo["personaje"] = false
		previo["etiqueta_nombre"] = "Nombre del mundo"
	var c := CreadorPersonaje.abrir(self,
		"NUEVO MUNDO" if simple else "NUEVO PERSONAJE", "Banco de pruebas del creador",
		"Empezar", previo,
		func(nombre: String, asp: Dictionary): print("[creador] acepta %s -> %s" % [nombre, asp]))
	await get_tree().process_frame
	await get_tree().process_frame

	# Las pestañas de fase son los Button con toggle_mode del primer HBox de la columna derecha. Se
	# buscan por el arbol y no por una ruta a mano: la pantalla se monta por codigo y una ruta fija se
	# quedaria desfasada al mover un contenedor.
	var pest: Array = _pestanas(c)
	print("[creador] %d fases: %s" % [pest.size(),
		str(pest.map(func(b: Button) -> String: return b.text))])
	DirAccess.make_dir_recursive_absolute(SALIDA)
	# El modo simple no tiene pestañas: se captura la pantalla entera y ya.
	if pest.is_empty():
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var unica: String = SALIDA + "creador_simple.png"
		get_viewport().get_texture().get_image().save_png(unica)
		print("[creador] ", ProjectSettings.globalize_path(unica))
		get_tree().quit()
		return
	for i in pest.size():
		(pest[i] as Button).pressed.emit()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		var ruta: String = "%screador_%d_%s.png" % [SALIDA, i,
			String(pest[i].text).to_lower().replace(" ", "_")]
		img.save_png(ruta)
		print("[creador] ", ProjectSettings.globalize_path(ruta))
	get_tree().quit()


func _pestanas(raiz: Node) -> Array:
	var fila: HBoxContainer = null
	var pila: Array[Node] = [raiz]
	while not pila.is_empty():
		var n: Node = pila.pop_front()
		if n is HBoxContainer:
			var todos_botones: bool = n.get_child_count() > 1
			for h in n.get_children():
				if not (h is Button) or not (h as Button).toggle_mode:
					todos_botones = false
			if todos_botones:
				fila = n
				break
		for h in n.get_children():
			pila.append(h)
	if fila == null:
		return []
	return Array(fila.get_children())
