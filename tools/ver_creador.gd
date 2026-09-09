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
#    herramientas/ver_creador.bat
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"


func _ready() -> void:
	# Una partida de mentira para que Game.lider() exista y el creador tenga con que arrancar.
	Game.nueva_partida("Prueba", {"color": Color(0.35, 0.62, 0.95)})
	# 'herramientas/ver_creador.bat mundo' abre el MODO SIMPLE (el de bautizar un mundo compartido): sin fases,
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

	# EL MAGO: sombrero picudo y barba larga blanca sobre pelo blanco. Es la unica foto donde se ven
	# las dos piezas nuevas PUESTAS Y EN COLOR -- en la hoja de contacto salen todas en gris (los
	# atlas se hornean en gris y se tiñen en el juego), asi que ahi no se puede juzgar si la barba se
	# distingue del pelo ni si el ala tapa la cara.
	#
	# Y ademas es el MAESTRO de la Meditación, que es para quien se han hecho.
	var pj: PersonajeData = Game.lider()
	pj.poner_pieza("pelo", "largo", Color(0.86, 0.86, 0.90))
	pj.poner_pieza("barba", "larga", Color(0.93, 0.93, 0.95))
	pj.poner_pieza("gorro", "mago", Color(0.32, 0.24, 0.52))
	pj.poner_pieza("torso", "tunica", Color(0.28, 0.22, 0.46))
	_repintar_muneco(c)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ruta_m: String = SALIDA + "creador_9_mago.png"
	get_viewport().get_texture().get_image().save_png(ruta_m)
	print("[creador] ", ProjectSettings.globalize_path(ruta_m))

	_probar_guardado()
	get_tree().quit()


# ¿SOBREVIVEN LAS PIEZAS A GUARDAR Y CARGAR? Lo que se elige en esta pantalla no sirve de nada si al
# cargar la partida vuelve el traje de serie.
#
# Va aqui y no en un banco aparte porque es el visor del CREADOR: lo que se prueba es justo lo que
# esta pantalla produce. Y hace falta que sea permanente porque el fallo que caza es MUDO -- el juego
# arranca igual, el personaje se ve bien mientras juegas, y solo al volver a cargar aparece con otro
# pelo.
#
# EL LIDER ES EL CASO DELICADO: los compañeros viajan enteros dentro de SaveData.plantilla (son
# Resources y Godot los incrusta), pero el lider va DESMONTADO en campos planos, asi que cada cosa
# suya hay que escribirla a mano en las dos puntas. De hecho su aspecto NO se guardaba: se descubrio
# con esta misma comprobacion al meter la barba, y el pelo llevaba perdiendose desde siempre.
func _probar_guardado() -> void:
	var pj: PersonajeData = Game.lider()
	var quiero := {"pelo": "largo", "barba": "larga", "gorro": "mago"}
	for k in quiero:
		pj.poner_pieza(k, String(quiero[k]), Color(0.9, 0.9, 0.9))
	var d: SaveData = Game.exportar_partida()
	# Se ensucia a proposito ANTES de cargar: si importar_partida no escribiera el aspecto, la prueba
	# pasaria igual leyendo lo que ya habia en memoria.
	pj.aspecto = {}
	Game.importar_partida(d)
	var l2: PersonajeData = Game.lider()
	var malas: Array = []
	for k in quiero:
		if l2.pieza(k)["modelo"] != String(quiero[k]):
			malas.append("%s (esperaba %s y sale '%s')" % [k, quiero[k], l2.pieza(k)["modelo"]])
	if malas.is_empty():
		print("[creador] OK: el aspecto del líder sobrevive a guardar y cargar.")
	else:
		printerr("[creador] MAL: el aspecto del líder NO se guarda -> %s" % ", ".join(malas))


# Vuelve a montar el muñeco de la izquierda con el aspecto que tenga ahora el lider. Se busca el
# MunecoJugador por el arbol y no por una ruta fija, por lo mismo que las pestañas: la pantalla se
# monta por codigo y una ruta a mano se queda desfasada en cuanto se mueve un contenedor.
func _repintar_muneco(raiz: Node) -> void:
	var pj: PersonajeData = Game.lider()
	for n in _todos(raiz):
		if n.has_method("montar") and n.has_method("tenir"):
			n.montar(pj)
			n.tenir(pj.color, pj.metalico)
			return
	printerr("[creador] no encuentro el muñeco: la foto del mago no vale.")


func _todos(n: Node) -> Array:
	var out: Array = [n]
	for h in n.get_children():
		out.append_array(_todos(h))
	return out


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
