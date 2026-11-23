# HERRAMIENTA. No forma parte del juego. CON VENTANA:
#
#   godot --path . res://tools/capturas_arboles.tscn
#
# LOS ARBOLES DE HABILIDADES Y MAGIAS (22/11, memoria rangos-magias-y-habilidades): capturas de la pestaña del arbol
# en el MAESTRO (la Ráfaga de la daga) y en la TORRE DEL MAGO (el Venablo), con los arboles de ejemplo, y el dibujo
# provisional de la torre. Escritorio, carpeta arboles.
extends Node

const CARPETA := "C:/Users/dasui/Desktop/arboles"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA)
	var town: Node = load("res://scenes/levels/town.tscn").instantiate()
	add_child(town)
	for i in 10:
		await get_tree().process_frame
	# UN GRUPO DE VERDAD (el de la partida de referencia), para que salga la fila de retratos como en el juego.
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
		Game.party.clear()
		for i in mini(4, Game.plantilla.size()):
			Game.party.append(Game.plantilla[i])
		Game.lider_idx = 0
	var pj: PersonajeData = Game.lider()
	pj.equipped_main = Game.crear_item(load("res://resources/weapons/daga.tres"), 1, 0, {})
	pj.habilidades_aprendidas = Game.pool_habilidades(pj).duplicate()
	pj.level = 2
	Game.money = 6000
	var rafaga: String = "res://resources/abilities/rafaga.tres"
	var venablo: String = "res://resources/spells/venablo_de_tormenta.tres"
	pj.dominio[rafaga] = 820
	pj.nodos_elegidos[rafaga] = ["filo", "tajos", "torbellino"]
	pj.dominio[venablo] = 340
	pj.nodos_elegidos[venablo] = ["punta"]
	if not pj.hechizos_aprendidos.has(load(venablo)):
		pj.hechizos_aprendidos.append(load(venablo))

	var menu: Node = get_tree().get_first_node_in_group("maestro_menu")
	# 1) EL MAESTRO: el arbol de la Ráfaga, mirando "Torbellino" (que ya puede coger).
	menu.abrir("maestro")
	await _esperar()
	menu._on_tab(menu.TAB_ARBOL)
	var plantillas: Array = menu._plantillas()
	for i in plantillas.size():
		if String(plantillas[i].resource_path).get_file() == "daga.tres":
			menu._pick_arma(i)
	await _esperar()
	# 0) TODO PLEGADO: el basico elegido y las habilidades con su icono y su contador. (23/11) LA FICHA DEL BASICO: la
	# linea con 3 pasos (nivel 1 entero) y su primer punto sin poner; y luego con el punto en Sangrado y un paso mas.
	# (el arbol: las dos principales y luego las dos secundarias por nivel; los pisos 4 y 8, en la ficha)
	pj.piso_hondo = 16
	pj.basico_arbol = {str(WeaponData.Tipo.DAGA): {"pasos": 2, "fac": {}, "elec": []}}
	menu._arbol_ui.fila_sel = "basico"
	menu._arbol_ui.nodo_sel = &"c0_sangrado"
	menu._rebuild()
	await _esperar()
	get_viewport().get_texture().get_image().save_png("%s/0_maestro_plegado.png" % CARPETA)
	pj.basico_arbol = {str(WeaponData.Tipo.DAGA): {"pasos": 3, "fac": {"sangrado": 1}, "elec": ["sangrado"]}}
	menu._arbol_ui.nodo_sel = &""
	menu._rebuild()
	await _esperar()
	get_viewport().get_texture().get_image().save_png("%s/0b_basico_con_sangrado.png" % CARPETA)
	pj.level = 3
	pj.piso_hondo = 25
	pj.basico_arbol = {str(WeaponData.Tipo.DAGA): {"pasos": 6, "fac": {"sangrado": 1, "ensanamiento": 1}, "elec": ["sangrado", "ensanamiento"]}}
	menu._arbol_ui.nodo_sel = &"c2_abrir_herida"
	menu._rebuild()
	await _esperar()
	get_viewport().get_texture().get_image().save_png("%s/0c_basico_nivel_3.png" % CARPETA)
	pj.level = 2
	menu._arbol_ui.fila_sel = rafaga
	menu._arbol_ui.nodo_sel = &"remolino"
	menu._rebuild()
	await _esperar()
	get_viewport().get_texture().get_image().save_png("%s/1_maestro_arbol_rafaga.png" % CARPETA)
	# 2) El mismo, mirando el nodo donde se juntan las dos ramas (pide nivel 3).
	menu._arbol_ui.nodo_sel = &"danza"
	menu._rebuild()
	await _esperar()
	get_viewport().get_texture().get_image().save_png("%s/2_maestro_arbol_se_juntan.png" % CARPETA)
	menu._cerrar()
	await _esperar()

	# 3) LA TORRE DEL MAGO: el arbol del Venablo, mirando "Carga de tormenta" (la otra rama de Largo alcance).
	menu.abrir("mago")
	await _esperar()
	menu._on_tab(menu.TAB_ARBOL_MAGIA)
	menu._arbol_ui.fila_sel = venablo
	menu._arbol_ui.nodo_sel = &"carga"
	menu._rebuild()
	await _esperar()
	get_viewport().get_texture().get_image().save_png("%s/3_mago_arbol_venablo.png" % CARPETA)
	menu._cerrar()

	# 4) LA TORRE: sus tres paletas, a x3 y una al lado de la otra, para que elija el jefe.
	var t: Vector2i = CasaSprites.tam("mago")
	var hoja := Image.create(t.x * 3 + 40, t.y + 20, false, Image.FORMAT_RGBA8)
	hoja.fill(Color(0.32, 0.42, 0.24))   # el verde del suelo del pueblo, para verla como en el juego
	var i_p: int = 0
	for pal in ["A", "B", "C"]:
		var img: Image = CasaSprites.TorreSprites.generar(t.x, t.y, pal)
		hoja.blend_rect(img, Rect2i(Vector2i.ZERO, t), Vector2i(10 + i_p * (t.x + 10), 10))
		i_p += 1
	hoja.resize(hoja.get_width() * 3, hoja.get_height() * 3, Image.INTERPOLATE_NEAREST)
	hoja.save_png("%s/4_torre_mago_versiones_A_B_C.png" % CARPETA)
	print("[capturas] en ", CARPETA)
	get_tree().quit()


func _esperar() -> void:
	for k in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
