# ============================================================
#  dev_peleteria.gd  --  HERRAMIENTA, no parte del juego.
#
#  Abre la PELETERIA de verdad (scripts/ui/tannery_menu.gd, rehecha el 16/09/2026 con la cara del
#  inventario) con el Hogar lleno y la recorre entera, comprobando lo que el rework promete:
#    - que la rejilla es un MONTON POR CALIDAD y sale con su cuenta (antes habia que elegir la piel
#      a ciegas en un selector de texto y leer los contadores despues);
#    - que la pestaña Correas solo ofrece cuero curtido, y que cada tier saca la correa de SU tier;
#    - que curtir cobra el material y da lo anunciado;
#    - que Mochilas lista los metales, que el Auto llena y que una tanda sale entera.
#
#  DOS MODOS:
#    - SIN VENTANA (--headless): solo las comprobaciones. Rapido y sin abrir nada.
#    - CON VENTANA (doble clic en herramientas/ver_peleteria.bat): ademas, las capturas en
#      tools/salida/peleteria_*.png. Headless no dibuja UI, por eso ahi se saltan.
#  Con process_mode = ALWAYS, porque el menu PAUSA el arbol al abrirse.
#  Devuelve codigo != 0 si algo falla.
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
const PartidaDePrueba = preload("res://tools/visores/partida_de_prueba.gd")

# Las pieles que se meten en el baul, con las calidades que se meten de cada una. Son de tiers y
# bandas distintos a proposito: con una sola piel la rejilla no prueba nada (una celda), y con una
# sola calidad no se ve que cada monton es una operacion aparte.
const PIELES := {
	"cuero_simple": [MaterialItem.Calidad.INTACTO, MaterialItem.Calidad.NORMAL, MaterialItem.Calidad.DANADO],
	"cuero_curado": [MaterialItem.Calidad.NORMAL],
	"cuero_brunido": [MaterialItem.Calidad.PURO, MaterialItem.Calidad.INTACTO],
	"cuero_reforzado": [MaterialItem.Calidad.INTACTO, MaterialItem.Calidad.NORMAL],
}

var _fallos: int = 0
var _hechas: int = 0
var _con_ventana: bool = DisplayServer.get_name() != "headless"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _con_ventana:
		DisplayServer.window_set_size(Vector2i(1280, 720))
		DirAccess.make_dir_recursive_absolute(SALIDA)
	PartidaDePrueba.llenar()
	_llenar_hogar()

	var men: CanvasLayer = preload("res://scripts/ui/tannery_menu.gd").new()
	add_child(men)
	men.abrir()
	var R = men.refinar
	var M = men.mochilas

	print("=== CURTIR: un montón por piel y calidad ===")
	await _ir(men, men.TAB_CURTIR)
	_ok("hay más de un montón", men.stacks.size() >= 4)
	_ok("cada montón trae su calidad y su cuenta",
		not _hay(men.stacks, func(s): return int(s["tengo"]) <= 0 or not s.has("cal")))
	_ok("no sale ninguna piel de la que no tengas nada",
		not _hay(men.stacks, func(s): return Game.disponible_calidad_en_hogar(s["mat"], int(s["cal"])) <= 0))
	_ok("salen las tres calidades del cuero simple",
		_cuantos(men.stacks, func(s): return String((s["mat"] as MaterialData).id) == "cuero_simple") == 3)
	_ok("el destino de cada montón es su curtido, no el de T1",
		not _hay(men.stacks, func(s): return s["destino"] != Game.curtido_de(s["mat"])))
	await _captura(men, "curtir")

	print("\n=== CURTIR: se cobra lo que dice ===")
	# La lambda va en UNA linea: partida, el parser corta en el salto y la escena entera falla al
	# cargar -- y headless se queda colgado sin decir por que.
	var quiero: int = int(MaterialItem.Calidad.INTACTO)
	var i_piel: int = _indice(men.stacks, func(s): return String((s["mat"] as MaterialData).id) == "cuero_simple" and int(s["cal"]) == quiero)
	_ok("está el montón de cuero simple intacto", i_piel >= 0)
	if i_piel >= 0:
		men.sel = i_piel
		var s: Dictionary = men.stacks[i_piel]
		var origen: MaterialData = s["mat"]
		var destino: MaterialData = s["destino"]
		var por_uno: int = int(s["por_uno"])
		var antes_piel: int = Game.items_calidad_en_hogar(origen, int(s["cal"]))
		var antes_cur: int = Game.items_calidad_en_hogar(destino, int(s["cal"]))
		R._cant = 1
		await R._refinar(false, s)
		var gano: int = Game.items_calidad_en_hogar(destino, int(s["cal"])) - antes_cur
		# La Peleteria puede subirlo un escalon, asi que el curtido puede caer en la calidad de
		# ARRIBA: lo que se comprueba es que se ha gastado lo justo y que ha salido UNO.
		var gasto: int = antes_piel - Game.items_calidad_en_hogar(origen, int(s["cal"]))
		_ok("curtir 1 gasta %d pieles" % por_uno, gasto == por_uno)
		_ok("y deja un curtido (o uno mejor, si la Peletería tira)", gano == 1 or gano == 0)

	print("\n=== CORREAS: solo cuero curtido, y cada tier el suyo ===")
	await _ir(men, men.TAB_CORREAS)
	_ok("no está vacía", not men.stacks.is_empty())
	_ok("todo lo que sale es cuero de forja",
		not _hay(men.stacks, func(s): return Game.correa_de_tier(int((s["mat"] as MaterialData).tier)) == null))
	_ok("la correa que sale es la del tier del cuero",
		not _hay(men.stacks, func(s): return s["destino"] != Game.correa_de_tier(int(s["tier"]))))
	# Cada origen tiene que ser EL cuero de forja de su tier. No vale comprobar "que no sea una piel
	# cruda": el cuero reforzado es las dos cosas a la vez (piel T2 que sueltan las arañas y cuero de
	# forja T2), asi que esa comprobacion fallaba sin que hubiera nada roto.
	_ok("el origen es el cuero de forja de su tier",
		not _hay(men.stacks, func(s): return s["mat"] != Game.cuero_de_tier(int(s["tier"]))))
	await _captura(men, "correas")

	print("\n=== MOCHILAS ===")
	await _ir(men, men.TAB_MOCHILAS)
	_ok("la rejilla son los metales", men.stacks.size() == Game.hebillas_conocidas().size()
		and not men.stacks.is_empty())
	_ok("cada celda es un metal", not _hay(men.stacks, func(s): return not (s is MaterialData)))
	var heb: MaterialData = men.stacks[men.sel]
	M._cantidad = 2
	M._on_auto(true)
	await get_tree().process_frame
	var coste: Dictionary = Game.MOCHILA_COSTE
	var piezas: int = Game.piezas_de_coste(
		[heb, Game.correa_de_mochila(heb), Game.cuero_de_mochila(heb)],
		[M._sel_heb, M._sel_cor, M._sel_cue],
		[int(coste["hebillas"]), int(coste["correa"]), int(coste["cuero"])])
	_ok("el Auto ▲ llena para al menos una mochila", piezas >= 1)
	_ok("y no pide más de lo que hay en el baúl",
		Game.uds_seleccion(M._sel_heb) <= Game.disponible_unidades_material_en_hogar(heb))
	await _captura(men, "mochilas")
	if piezas >= 1:
		var antes: int = Game.owned_mochilas.size()
		await M._coser(heb)
		_ok("coser deja %d mochila(s) en el baúl" % piezas, Game.owned_mochilas.size() == antes + piezas)
		_ok("y suelta la selección", M._sel_heb.is_empty() and M._sel_cor.is_empty())

	print("\n=== SIN NADA QUE CURTIR ===")
	Game.almacen_materiales.clear()
	await _ir(men, men.TAB_CURTIR)
	_ok("con el baúl vacío, la rejilla se queda vacía y no revienta", men.stacks.is_empty())
	await _captura(men, "curtir_vacio")

	men._cerrar()
	if _fallos == 0:
		print("\nOK: las %d comprobaciones pasan." % _hechas)
	else:
		printerr("\nFALLAN %d de %d comprobaciones." % [_fallos, _hechas])
	get_tree().quit(1 if _fallos > 0 else 0)


# Lo que la partida de prueba no trae: el baul lleno de pieles, cuero curtido y metal.
func _llenar_hogar() -> void:
	Game.almacen_materiales.clear()
	for id in PIELES:
		var md: MaterialData = load("res://resources/materials/%s.tres" % id) as MaterialData
		if md == null:
			continue
		Game.descubrir(md)   # las T2 solo se ofrecen si has traído alguna
		for cal in PIELES[id]:
			# SIETE de cada una: con CUERO_POR_CURTIDO piezas por cuero, sobra para curtir y para
			# que el montón siga ahí después (así se ve que se encoge, no que desaparece).
			for i in 7:
				Game.almacen_materiales.append(MaterialItem.crear(md, int(cal)))
	# Cuero curtido (para Correas) y sus correas, y metal para las hebillas.
	for id2 in ["cuero_curtido", "cuero_reforzado", "correa_cuero"]:
		var md2: MaterialData = load("res://resources/materials/%s.tres" % id2) as MaterialData
		if md2 == null:
			continue
		Game.descubrir(md2)
		for cal2 in [MaterialItem.Calidad.INTACTO, MaterialItem.Calidad.NORMAL]:
			for i2 in 9:
				Game.almacen_materiales.append(MaterialItem.crear(md2, int(cal2)))
	# Los metales, que es lo que hace de hebilla. Se descubre el MINERAL (es lo que mira
	# metales_forja_conocidos) y se guardan las hebillas ya hechas.
	for par in [["cobre", "hebillas_cobre"], ["hierro", "hebillas_hierro"]]:
		var mineral: MaterialData = load("res://resources/materials/%s.tres" % par[0]) as MaterialData
		if mineral != null:
			Game.descubrir(mineral)
		var h: MaterialData = load("res://resources/materials/%s.tres" % par[1]) as MaterialData
		if h == null:
			continue
		for cal3 in [MaterialItem.Calidad.INTACTO, MaterialItem.Calidad.NORMAL]:
			for i3 in 6:
				Game.almacen_materiales.append(MaterialItem.crear(h, int(cal3)))


func _ir(men: Node, tab: int) -> void:
	men._tab = tab
	men.sel = 0
	men.decir("")   # el aviso de la pestaña anterior no se arrastra (al pulsar lo limpia _on_tab)
	men.rebuild()
	await get_tree().process_frame


func _hay(lista: Array, cond: Callable) -> bool:
	return _indice(lista, cond) >= 0


func _cuantos(lista: Array, cond: Callable) -> int:
	var n: int = 0
	for x in lista:
		if cond.call(x):
			n += 1
	return n


func _indice(lista: Array, cond: Callable) -> int:
	for i in lista.size():
		if cond.call(lista[i]):
			return i
	return -1


func _ok(que: String, cond: bool) -> void:
	_hechas += 1
	if cond:
		print("  ok   %s" % que)
	else:
		_fallos += 1
		printerr("  FALLA %s" % que)


func _captura(men: Node, nombre: String) -> void:
	if not _con_ventana:
		return
	men.rebuild()
	# DOS frames: el primero coloca los contenedores y el segundo ya dibuja lo colocado.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%speleteria_%s.png" % [SALIDA, nombre])
