# ============================================================
#  dev_personaje.gd  --  HERRAMIENTA, no parte del juego.
#
#  Abre el menu de PERSONAJE de verdad (scripts/ui/character_menu.gd) con un grupo de cuatro, el
#  baul lleno y el lider equipado, y saca una captura de CADA seccion. Es la unica forma de juzgar
#  la pantalla: hay que ver si el muñeco cabe, si la ficha de la derecha se lee, si las dos filas
#  de pestañas caen una debajo de la otra y si los atributos cambian al ponerse un baston.
#
#  El grupo, el baul y todo lo demas los pone PartidaDePrueba (tools/visores/partida_de_prueba.gd),
#  que es la misma partida que mira el visor del maestro.
#
#  Va CON VENTANA (nada de --headless): un Control no se coloca ni se dibuja sin superficie de
#  render, y en headless la captura sale en negro.
#
#  Y con process_mode = ALWAYS: el menu PAUSA el arbol al abrirse (Game.fijar_modal), asi que sin
#  esto el propio visor se congela en el primer await y no llega a capturar nada.
#
#  Doble clic en herramientas/ver_personaje.bat, o:
#    godot --path . res://tools/visores/dev_personaje.tscn
#  Guarda tools/salida/personaje_<n>_<seccion>.png y se cierra solo.
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
# La partida que se mira. Por preload y no por class_name: ver partida_de_prueba.gd.
const PartidaDePrueba = preload("res://tools/visores/partida_de_prueba.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1280, 720))
	PartidaDePrueba.llenar()
	_falso_jugador()
	# EL PUEBLO DE MENTIRA. Game.en_pueblo() mira si la escena actual es town.tscn, y el equipo SOLO
	# se cambia alli. Sin esto el boton de Equipar sale apagado en todas las capturas y la mitad de
	# las secciones de Armas y Armadura -- justo la que hace algo -- no se puede juzgar.
	if get_tree().current_scene != null:
		get_tree().current_scene.scene_file_path = "res://scenes/town.tscn"

	var men: CanvasLayer = preload("res://scripts/ui/character_menu.gd").new()
	add_child(men)
	men._set_open(true)

	DirAccess.make_dir_recursive_absolute(SALIDA)

	# 1) DETALLES, con arma NORMAL: la rama fisica de los atributos.
	men._on_seccion(men.SEC_FICHA)
	await _captura("0_detalles_atributos")
	men._pagina_a(1)
	await _captura("0_detalles_habilidades")
	men._pagina_a(0)
	# La lupa, que es donde sale TODO lo que la pagina de fuera esconde.
	men._abrir_modal_atributos()
	await _captura("0_detalles_lupa")
	men._cerrar_modal()

	# 2) ARMA: las dos manos, y la rejilla del baul al pulsar Cambiar.
	men._on_seccion(men.SEC_ARMAS)
	await _captura("1_arma_principal")
	men._pick(1)
	await _captura("1_arma_secundaria")
	men._pick(0)
	men._abrir_cambio()
	await _captura("1_arma_cambiar")
	# EQUIPAR DE VERDAD, que es lo unico que comprueba que el boton hace algo: se elige otra arma del
	# baul, se pulsa Equipar y se captura la seccion YA con el arma nueva puesta. Si la ficha de la
	# derecha no cambia, el camino esta roto.
	men._pick_cand(3)
	await _captura("1_arma_candidato")
	men._equipar()
	await _captura("1_arma_equipada")

	# 3) HABILIDADES, con y sin la subpestaña de magias. El personaje 0 lleva hechizos y el 3 no: es lo
	# unico que enseña que la fila desaparece cuando no hay nada que elegir.
	men._on_seccion(men.SEC_HABILIDADES)
	await _captura("2_kit_habilidades")
	# PONER una del pool y QUITAR una de las ranuras: es lo unico que comprueba que los botones
	# hacen algo. Si tras pulsar la rejilla de arriba no cambia, el camino esta roto.
	men._pick(Game.MAX_HABILIDADES)   # la primera del pool
	await _captura("2_habilidad_pool")
	if men._kit.size() > Game.MAX_HABILIDADES:
		var h = men._kit[Game.MAX_HABILIDADES]["item"]
		men._alternar_kit(h, false, false)
		await _captura("2_habilidad_puesta")
	men._on_sub(1)
	await _captura("2_kit_magias")
	# LA CABEZA LLENA: el personaje 0 se sabe mas magias de las que caben (ver _hechizos), asi que
	# esta es la pantalla donde se ve el bloque de "se las sabe pero no las lleva" y el aviso de que
	# hay que quitar una antes. Es el caso que motivo todo el cambio.
	men._pick(Game.MAX_HECHIZOS)
	await _captura("2_magia_sin_ranura")
	men._pick(0)
	men._alternar_kit(men._kit[0]["item"], true, true)
	await _captura("2_magia_quitada")

	# ARRASTRAR: los tres casos que hacen algo. Se llama a _soltar_kit directamente porque el gesto
	# lo lleva el motor y en una captura no hay raton que lo haga; lo que se comprueba aqui es la
	# LOGICA (donde acaba cada cosa), que es lo unico que se puede romper solo.
	#   1) del monton de abajo a una ranura CONCRETA -- no al primer hueco libre.
	var suelta = men._kit[Game.MAX_HECHIZOS]["item"]
	men._soltar_kit(suelta, 0, false, 5, true)
	await _captura("2_arrastre_magia_a_ranura")
	#   2) una ranura sobre OTRA: se cruzan.
	men._soltar_kit(men._kit[0]["item"], 0, true, 2, true)
	await _captura("2_arrastre_magia_cruzada")
	#   3) sacarla de su ranura al monton: se quita.
	men._soltar_kit(men._kit[2]["item"], 2, true, 0, false)
	await _captura("2_arrastre_magia_fuera")
	_comprobar_arrastre_tactil(men)
	await _comprobar_huecos_magias(men)

	# 4) ARMADURA: los cinco slots y la rejilla de cambio de uno de ellos.
	men._on_seccion(men.SEC_ARMADURA)
	await _captura("3_armadura")
	men._pick(1)   # pecho, que es el slot con mas piezas en el baul
	men._abrir_cambio()
	await _captura("3_armadura_cambiar")
	men._cancelar_cambio()

	# 5) DESARROLLO: con las dos clases (subpestañas) y sin ninguna (el hueco vacio, que es justo lo
	# que hay que comprobar que se explica solo).
	men._on_seccion(men.SEC_DESARROLLO)
	await _captura("4_desarrollo")
	men._on_sub(1)
	await _captura("4_pasivas")

	# EL PERSONAJE 3 (pelado: sin hechizos, sin desarrollos, sin pasivas y con las manos vacias).
	# Es la mitad de las ramas de esta pantalla, y es la que no se ve nunca en una partida madura.
	men._pick_persona(3)
	men._on_seccion(men.SEC_FICHA)
	await _captura("5_pelado_detalles")
	men._on_seccion(men.SEC_HABILIDADES)
	await _captura("5_pelado_kit")
	men._on_seccion(men.SEC_DESARROLLO)
	await _captura("5_pelado_desarrollo")
	men._on_seccion(men.SEC_ARMAS)
	await _captura("5_pelado_arma")

	# EL MAGO: el personaje 1 lleva baston, asi que sus atributos principales son los MAGICOS
	# (ataque magico, vel. recitado, criticos magicos). Es la bifurcacion que se pidio, y con el
	# lider solo no se ve.
	men._pick_persona(1)
	men._on_seccion(men.SEC_FICHA)
	await _captura("6_mago_atributos")
	men._abrir_modal_atributos()
	await _captura("6_mago_lupa")
	men._cerrar_modal()
	# Y SUS MAGIAS, que es donde se ve el hechizo que PRESTA el baston (el Pulso menor): se puede
	# lanzar sin haberlo aprendido y desaparece al soltar el arma. Con el lider no sale, porque va
	# con espada. La logica la prueba dev_magia_arma; esto es para MIRAR que se pinta como una mas.
	men._on_seccion(men.SEC_HABILIDADES)
	men._on_sub(1)
	await _captura("6_mago_magias")

	# EL MAGO RECIEN HECHO: el personaje 3 va pelado (sin una sola magia aprendida). Con el baston en
	# la mano tiene que poder lanzar el Pulso menor igual -- es lo que hace que un mago sea jugable
	# desde el minuto uno, ahora que los grimorios no se compran. Y aqui SI sale la nota de "lo trae
	# el arma de serie", que con Sedaki no se ve porque el se lo sabe de verdad.
	men._pick_persona(3)
	Game.equipar_arma(load("res://resources/weapons/baston.tres"), men._pj())
	men._on_seccion(men.SEC_HABILIDADES)
	men._on_sub(1)
	await _captura("7_mago_novato_magias")

	get_tree().quit()


# UN JUGADOR DE MENTIRA en el grupo "player", solo con lo que la ficha le pregunta.
#
# Hace falta porque la ENERGIA MAXIMA no vive en el Combatant: crear_player_combatant la deja a cero
# y se la inyecta start_combat leyendo el aguante del mapa (ver game.gd). La ficha la pide por la
# misma via, `player.aguante_de_grupo(pj)`, y aqui no hay jugador ninguno -- asi que sin esto la
# fila salia "0" en la captura y no habia forma de saber si el arreglo funcionaba.
func _falso_jugador() -> void:
	# El script se monta ENTERO y se compila ANTES de colgarselo al nodo: un GDScript recien creado
	# no tiene clase todavia, asi que `set_script` primero y `get_script().source_code` despues deja
	# el script en Nil y no se aplica nada.
	var sc := GDScript.new()
	sc.source_code = """
extends Node
func aguante_de_grupo(pj) -> Vector2:
	# Lo mismo que hace el jugador de verdad, en pequeño: el aguante sale de la Resistencia.
	var tope := 60.0 + float(pj.resistencia) * 0.12
	return Vector2(tope, tope)
func refrescar_grupo() -> void:
	pass
"""
	sc.reload()
	var n := Node.new()
	n.name = "JugadorDePrueba"
	n.set_script(sc)
	n.add_to_group("player")
	add_child(n)


# ¿SE PUEDE ARRASTRAR CON EL DEDO? No se puede comprobar mirando una captura, asi que se comprueba
# aqui: en movil el gesto se lo lleva ArrastreScroll (corre en _input, antes que la GUI) salvo que
# la celda lo pida para si con META_ARRASTRE_PROPIO. Esto verifica las dos mitades:
#   1) las celdas CON algo llevan la marca, y las ranuras vacias NO (ahi el dedo debe seguir
#      deslizando la lista, como en el resto del menu);
#   2) preguntando por el centro de una celda llena, ArrastreScroll cede el gesto de verdad.
#
# Si esto se rompe, en escritorio no se nota NADA -- el raton no pasa por ArrastreScroll -- y el
# fallo solo sale con un movil en la mano. De ahi que sea una comprobacion y no una captura.
func _comprobar_arrastre_tactil(men: Node) -> void:
	var celdas: Array = []
	_recoger(men, celdas)
	if celdas.is_empty():
		printerr("[arrastre] NO hay ninguna CeldaKit en pantalla: la comprobacion no vale.")
		return
	var con_marca: int = 0
	var vacias_marcadas: int = 0
	for c in celdas:
		var marcada: bool = c.has_meta(ArrastreScroll.META_ARRASTRE_PROPIO)
		if c.item != null and marcada:
			con_marca += 1
		elif c.item == null and marcada:
			vacias_marcadas += 1
	var llenas: int = 0
	for c in celdas:
		if c.item != null:
			llenas += 1
	if con_marca != llenas or vacias_marcadas > 0:
		printerr("[arrastre] MAL: %d/%d celdas llenas marcadas y %d vacias marcadas (deberian ser 0)."
			% [con_marca, llenas, vacias_marcadas])
		return
	# Y la otra mitad: que ArrastreScroll ceda de verdad al preguntarle por ese punto.
	var una: Control = null
	for c in celdas:
		if c.item != null:
			una = c
			break
	var centro: Vector2 = una.get_global_rect().get_center()
	if not ArrastreScroll._pide_su_gesto(men._root, centro):
		printerr("[arrastre] MAL: ArrastreScroll NO cede el gesto sobre una celda llena.")
		return
	# LA TERCERA PATA: el drag&drop de Godot (los _get_drag_data / _drop_data de Control) se mueve con
	# eventos de RATON. En un movil solo llegan si el motor convierte el toque, y eso lo decide este
	# ajuste. Viene puesto de serie, asi que no esta escrito en project.godot -- pero si alguien lo
	# apaga algun dia, arrastrar dejaria de funcionar en el movil SIN UN SOLO ERROR por consola.
	if not bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true)):
		printerr("[arrastre] MAL: 'emulate_mouse_from_touch' esta APAGADO: en movil no se podra "
			+ "arrastrar nada (el drag de Control necesita eventos de raton).")
		return
	print("[arrastre] OK: %d celdas arrastrables con el dedo, el scroll les cede el gesto y la "
		% llenas + "emulacion de raton desde toque esta puesta.")


# ¿LAS MAGIAS SE QUEDAN DONDE LAS SUELTAS? Esto no se ve en una captura: en la pantalla salen seis
# ranuras numeradas, y que la magia aparezca "en la 2" no dice nada si el guardado la tiene en otro
# sitio. Se mira el DATO (Game.hechizos_con_huecos), que es lo que luego lee el combate.
#
# Era el fallo: equipped_spells era una lista COMPACTA, asi que soltar en la ranura 4 con las tres
# de delante vacias caia en un append() y la magia salia en la 1.
func _comprobar_huecos_magias(men: Node) -> void:
	var pj: PersonajeData = men._pj()
	var fallos: Array[String] = []

	# 1) DEL MONTON A UNA RANURA CONCRETA, con las de delante vacias.
	for s in Game.hechizos_con_huecos(pj):
		if s != null:
			Game.quitar_hechizo(s, pj)
	var pool: Array = Game.hechizos_sabidos(pj)
	if pool.size() < 2:
		printerr("[magias] El personaje no se sabe ni dos magias: la comprobacion no vale.")
		return
	men._rebuild()
	men._soltar_kit(pool[0], 0, false, 3, true)
	var set1: Array = Game.hechizos_con_huecos(pj)
	if set1[3] != pool[0] or set1[0] != null:
		fallos.append("soltada en la ranura 4 con las tres de delante vacias -> acabo en la %d"
			% (set1.find(pool[0]) + 1))

	# 2) RANURA -> RANURA: se cruzan y no se pierde ninguna.
	men._soltar_kit(pool[1], 0, false, 1, true)   # la segunda, en la ranura 2
	men._soltar_kit(pool[1], 1, true, 3, true)    # y encima de la primera: se cambian
	var set2: Array = Game.hechizos_con_huecos(pj)
	if set2[3] != pool[1] or set2[1] != pool[0]:
		fallos.append("cruzar dos ranuras no las intercambia (quedo %s)" % [_nombres(set2)])

	# 3) EQUIPAR con el boton entra en el PRIMER hueco libre, que ahora es el 1.
	if pool.size() > 2:
		Game.equipar_hechizo(pool[2], pj)
		if Game.hechizos_con_huecos(pj)[0] != pool[2]:
			fallos.append("equipar_hechizo no usa el primer hueco libre")

	# 4) SOLTAR EN EL VACIO: quita la magia y DEJA EL HUECO en su sitio. Se simula el gesto entero
	#    (empieza el arrastre, nadie lo recoge, llega el DRAG_END), que es lo unico que prueba el
	#    camino de verdad -- llamar a _soltar_kit a pelo no pasaria por CeldaKit.
	var antes: Array = Game.hechizos_con_huecos(pj)
	CeldaKit.en_vuelo = {"marca": CeldaKit.MARCA, "item": antes[3], "indice": 3, "es_ranura": true}
	CeldaKit.recogido = false
	men._notification(Node.NOTIFICATION_DRAG_END)
	var set4: Array = Game.hechizos_con_huecos(pj)
	if set4[3] != null:
		fallos.append("soltar fuera no quita la magia de la ranura 4")
	elif set4[1] != antes[1]:
		fallos.append("soltar fuera movio a las demas de ranura")
	elif not Game.hechizos_sabidos(pj).has(antes[3]):
		fallos.append("soltar fuera la OLVIDA en vez de solo quitarla")

	# 4b) EL GESTO DE VERDAD. Lo de arriba llama a _notification a mano, asi que prueba la logica
	#     pero NO que el motor avise. Aqui se arrastra con force_drag y se suelta un click en un
	#     sitio sin celdas: si Godot no le entregase NOTIFICATION_DRAG_END a la CanvasLayer del menu
	#     (que es lo unico que no se puede saber leyendo el codigo), soltar fuera no haria nada.
	Game.colocar_hechizo(pool[0], 2, pj)
	men._rebuild()
	await _soltar_en_el_vacio(men)
	if Game.hechizos_con_huecos(pj)[2] != null:
		fallos.append("con el gesto REAL (force_drag + soltar en el vacio) la magia no se quita: "
			+ "el motor no esta entregando el DRAG_END al menu")

	# 5) Y devolverla a su propia celda (el arrastre que uno cancela) NO la quita.
	Game.colocar_hechizo(antes[3], 3, pj)
	CeldaKit.en_vuelo = {"marca": CeldaKit.MARCA, "item": antes[3], "indice": 3, "es_ranura": true}
	CeldaKit.recogido = true   # lo que hace la propia celda al aceptarse a si misma
	men._notification(Node.NOTIFICATION_DRAG_END)
	if Game.hechizos_con_huecos(pj)[3] != antes[3]:
		fallos.append("cancelar el arrastre soltandola en su sitio la quita")

	men._rebuild()
	await _captura("2_magias_huecos")
	if fallos.is_empty():
		print("[magias] OK: las seis ranuras guardan la posicion (soltar, cruzar, equipar y tirar).")
	else:
		for f in fallos:
			printerr("[magias] MAL: %s" % f)


# Arrastra la celda de la ranura 3 y suelta el boton donde no hay ninguna celda. Es el gesto
# entero, con el motor en medio: force_drag arranca el arrastre igual que lo haria un dedo, y el
# click soltado hace que el viewport busque quien lo recoge, no encuentre a nadie y avise del final.
func _soltar_en_el_vacio(men: Node) -> void:
	var celdas: Array = []
	_recoger(men, celdas)
	var origen: CeldaKit = null
	for c in celdas:
		if c.es_ranura and c.indice == 2 and c.item != null:
			origen = c
			break
	if origen == null:
		printerr("[magias] No hay celda en la ranura 3: no se puede probar el gesto real.")
		return
	# El paquete es el mismo que devuelve _get_drag_data (force_drag no pasa por ahi).
	var paquete: Dictionary = {"marca": CeldaKit.MARCA, "item": origen.item,
		"indice": origen.indice, "es_ranura": true}
	CeldaKit.en_vuelo = paquete
	CeldaKit.recogido = false
	origen.force_drag(paquete, Label.new())
	await get_tree().process_frame
	# Un punto SIN celdas: el hueco entre el titulo de la ficha y el borde derecho.
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = men._content.get_global_rect().get_center()
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame


func _nombres(set: Array) -> String:
	var out: Array[String] = []
	for s in set:
		out.append(str(s.get("nombre")) if s != null else "-")
	return ", ".join(out)


func _recoger(n: Node, fuera: Array) -> void:
	for h in n.get_children():
		if h is CeldaKit:
			fuera.append(h)
		_recoger(h, fuera)


func _captura(nombre: String) -> void:
	# DOS frames: el primero coloca los contenedores (hasta entonces las celdas miden 0 y la rejilla
	# aun no sabe cuantas columnas caben) y el segundo ya dibuja lo colocado.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ruta: String = "%spersonaje_%s.png" % [SALIDA, nombre]
	get_viewport().get_texture().get_image().save_png(ruta)
	print("[personaje] ", ProjectSettings.globalize_path(ruta))
