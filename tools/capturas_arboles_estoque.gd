# HERRAMIENTA. No forma parte del juego. CON VENTANA:
#
#   godot --path . res://tools/capturas_arboles_estoque.tscn
#
# LOS ARBOLES DE VERDAD DEL ESTOQUE (25/11, copia de capturas_arboles_daga): una captura por habilidad en la pestaña del
# arbol del MAESTRO, con un camino ya cogido y un nodo elegido (para que se vea su ficha con el antes -> despues).
# Escritorio, carpeta arboles_estoque.
extends Node

const CARPETA := "C:/Users/dasui/Desktop/arboles_estoque"
const AB := "res://resources/abilities/%s.tres"

# habilidad -> [nodos cogidos, nodo que se mira]
const CASOS := [
	["estocada_penetrante", ["sin_armadura", "corazon", "herida_se_abre"], &"estocada_doble"],
	["fintas", ["acoso", "buscar_hueco", "leer_guardia"], &"respiracion"],
	["danza_de_acero", ["cuarto_tiempo", "compas", "herida_cruz"], &"bailar_esquivando"],
	["en_guardia", ["guardia_alta", "reto", "respiro"], &"guardia_no_cae"],
	["paso_ligero", ["al_costado", "pasar_cortando", "presteza_mayor"], &"paso_guardia"],
	["punzada_al_nervio", ["nervio_brazo", "temblor", "cadena_nerviosa"], &"lena_al_caido"],
	["avance_cubierto", ["carrera_larga", "abrir_guardia", "doble_estocada"], &"llegar_cubierto"],
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA)
	var town: Node = load("res://scenes/levels/town.tscn").instantiate()
	add_child(town)
	for i in 10:
		await get_tree().process_frame
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
		Game.party.clear()
		for i in mini(4, Game.plantilla.size()):
			Game.party.append(Game.plantilla[i])
		Game.lider_idx = 0
	var pj: PersonajeData = Game.lider()
	pj.equipped_main = Game.crear_item(load("res://resources/weapons/estoque.tres"), 1, 0, {})
	pj.equipped_off = load("res://resources/shields/escudo_pequeno.tres")   # (26/11) la rodela: el Avance cubierto
	pj.habilidades_aprendidas = Game.pool_habilidades(pj).duplicate()
	pj.level = 4
	pj.piso_hondo = 40
	Game.money = 30000
	# (24/11) un dominio distinto a cada una, para ver los cuatro colores del ritmo en el piso 40 (su tramo, 975-1000):
	# naranja (debajo), amarillo (dentro), verde (el del piso 41), gris (mas arriba)
	var dominios := {"estocada_penetrante": 950, "fintas": 985, "danza_de_acero": 1010, "en_guardia": 1060}
	for c in CASOS:
		var ruta: String = AB % c[0]
		pj.dominio[ruta] = int(dominios.get(c[0], 950))
		pj.nodos_elegidos[ruta] = c[1]

	var menu: Node = get_tree().get_first_node_in_group("maestro_menu")
	menu.abrir("maestro")
	await _esperar()
	menu._on_tab(menu.TAB_ARBOL)
	var plantillas: Array = menu._plantillas()
	for i in plantillas.size():
		if String(plantillas[i].resource_path).get_file() == "estoque.tres":
			menu._pick_arma(i)
	await _esperar()
	# 0) EL BASICO, con su arbol a nivel 3: las principales con el aro de oro y el rombo donde se juntan.
	pj.basico_arbol = {}
	menu._arbol_ui.fila_sel = "basico"
	menu._arbol_ui.nodo_sel = &""
	menu._rebuild()
	await _esperar()
	get_viewport().get_texture().get_image().save_png("%s/0_basico.png" % CARPETA)
	var k: int = 1
	for c in CASOS:
		menu._arbol_ui.fila_sel = AB % c[0]
		menu._arbol_ui.nodo_sel = c[2]
		menu._rebuild()
		await _esperar()
		# la lista de filas, bajada hasta abajo: la fila abierta (la ultima de las que se miran) a la vista
		for sc in menu.find_children("*", "ScrollContainer", true, false):
			(sc as ScrollContainer).scroll_vertical = 0 if (k <= 2) else 100000   # las dos primeras ya caben
		await _esperar()
		get_viewport().get_texture().get_image().save_png("%s/%d_%s.png" % [CARPETA, k, c[0]])
		k += 1
	print("[capturas] en ", CARPETA)
	get_tree().quit()


func _esperar() -> void:
	for k in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
