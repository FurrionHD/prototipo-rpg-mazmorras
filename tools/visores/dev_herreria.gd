# ============================================================
#  dev_herreria.gd  --  HERRAMIENTA, no parte del juego.
#
#  Abre la HERRERIA y la CARPINTERIA de verdad (scripts/ui/forge_menu.gd, rehechas el 16/09/2026 con
#  la cara del inventario) con el Hogar lleno y recorre las once pestañas, comprobando lo que el
#  rework promete:
#    - cada pestaña pinta su rejilla y la celda es LO QUE SALE;
#    - fundir, forjar y hacer una herramienta cobran y dan lo anunciado;
#    - la experiencia de Herreria va AL ARTESANO elegido (y ya no hay Metalurgia);
#    - la armadura de cuero NO sale en la herreria (se cose en la peleteria);
#    - mejorar, deshacer y reparar funcionan sobre el equipo;
#    - con el baul vacio nada se cuelga.
#
#  DOS MODOS: --headless solo comprueba; con ventana (herramientas/ver_herreria.bat) saca ademas
#  capturas en tools/salida/herreria_*.png. Devuelve codigo != 0 si algo falla.
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
const PartidaDePrueba = preload("res://tools/visores/partida_de_prueba.gd")
const ForgeMenu = preload("res://scripts/ui/forge_menu.gd")

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
	# Uno con Herreria y otro con Carpinteria, para ver la marca del retrato.
	for pj in Game.party:
		(pj as PersonajeData).desarrollos_rango.erase("herreria")
		(pj as PersonajeData).desarrollos_rango.erase("carpinteria")
	(Game.party[1] as PersonajeData).desarrollos_rango["herreria"] = 2
	(Game.party[2] as PersonajeData).desarrollos_rango["carpinteria"] = 1
	# Algo de desgaste, para que Reparar tenga que hacer.
	for pj in Game.party:
		for k in 40:
			Game.desgastar_arma("main", pj)
			Game.desgastar_armadura(pj)

	await _herreria()
	await _carpinteria()

	if _fallos == 0:
		print("\nOK: las %d comprobaciones pasan." % _hechas)
	else:
		printerr("\nFALLAN %d de %d comprobaciones." % [_fallos, _hechas])
	get_tree().quit(1 if _fallos > 0 else 0)


func _herreria() -> void:
	var men: CanvasLayer = ForgeMenu.new()
	add_child(men)
	men.abrir()

	print("=== HERRERÍA: las pestañas ===")
	_ok("ya no hay Metalurgia en el altar", Game.desarrollo_por_id("metalurgia").is_empty())
	for i in men.TABS_HERRERO.size():
		await _ir(men, i)
		var id: String = men.tab_id()
		_ok("%s pinta algo" % id, not men.stacks.is_empty())
		await _captura(men, "%d_%s" % [i, id])

	print("\n=== FUNDIR ===")
	await _ir(men, 0)
	var R = men.refinar
	_ok("la celda enseña el lingote, no el mineral",
		not men.stacks.any(func(s): return (s["sale"] as MaterialItem).data != Game.lingote_de(s["mat"])))
	var i_util: int = _indice(men.stacks, func(s): return int(s["tengo"]) >= int(s["por_uno"]))
	_ok("hay un montón que da para fundir", i_util >= 0)
	var herrero: PersonajeData = Game.party[1]
	men._on_artesano(men._gente().find(herrero))
	await get_tree().process_frame
	_ok("elegir artesano en la herrería", Game.artesano("herreria") == herrero)
	if i_util >= 0:
		men.sel = i_util
		var s: Dictionary = men.stacks[i_util]
		var antes_orig: int = Game.items_calidad_en_hogar(s["mat"], int(s["cal"]))
		var antes_exp: float = herrero.herreria_exp
		var antes_lider: float = Game.lider().herreria_exp
		_ok("la cantidad arranca en 1", R._cant == 1)
		await R.refinar(R.Que.FUNDIR, s)
		# El oficio puede DEVOLVER uno de los que gasta (Forge.prob_devolver_material): uno menos tambien vale.
		var gastados: int = antes_orig - Game.items_calidad_en_hogar(s["mat"], int(s["cal"]))
		_ok("fundir 1 gasta %d minerales (o uno menos si el oficio devuelve uno): %d" % [int(s["por_uno"]), gastados],
			gastados == int(s["por_uno"]) or gastados == int(s["por_uno"]) - 1)
		_ok("y la Herrería va al artesano", herrero.herreria_exp > antes_exp)
		_ok("y no al líder", is_equal_approx(Game.lider().herreria_exp, antes_lider))

		# LOS PUNTOS SON DEL ARTESANO, no del líder. Quien tiene el desarrollo cobra por el TIER de lo
		# que trabaja; quien no lo tiene, 1 por acción sea lo que sea. Se miraba el desarrollo del que
		# iba en cabeza, así que el herrero con Herrería cobraba como un aprendiz (y al revés).
		Game.lider().desarrollos_rango.erase("herreria")
		herrero.desarrollos_rango.erase("herreria")
		_ok("sin el oficio, una acción de T3 da 1 punto", is_equal_approx(Game._puntos_oficio("herreria", 3), 1.0))
		herrero.desarrollos_rango["herreria"] = 1
		_ok("con el oficio DEL ARTESANO, esa misma acción da el punto del tier",
			is_equal_approx(Game._puntos_oficio("herreria", 3), Game.tier_puntos(3)))

		# Y SUBIR DE NIVEL EL LÍDER NO LE BORRA EL CONTADOR AL ARTESANO. El reset de los desarrollos
		# no elegidos escribía por las propiedades de Game, que en los oficios caen en el artesano:
		# ascender el líder le vaciaba al herrero todo lo que llevaba fundido.
		var guardado: float = herrero.herreria_exp
		Game._reset_contadores_no_elegidos(Game.lider())
		_ok("el líder asciende y el herrero conserva lo suyo",
			is_equal_approx(herrero.herreria_exp, guardado))

	print("\n=== FORJAR ===")
	var i_forjar: int = _tab(men, "forjar")
	await _ir(men, i_forjar)
	var F = men.forjar
	_ok("Armas: ninguna mágica", not men.stacks.any(func(b): return Game._es_arma_magica(b)))
	var celda0 = men._lista.get_child(0).get_child(0)
	_ok("la celda es la pieza con SU tier", int(Game.meta_de(celda0.item)["tier"]) == F._tier)
	var hay_cuero: bool = false
	for f in F.FILTROS_HERRERIA.size():
		F._on_filtro(f)
		await get_tree().process_frame
		if men.stacks.any(func(b): return Game.es_armadura_cuero(b)):
			hay_cuero = true
		if f == 2:
			await _captura(men, "forjar_armaduras")
	_ok("la armadura de cuero no sale en la herrería", not hay_cuero)
	F._on_filtro(0)
	await get_tree().process_frame
	men._pick(2)
	await get_tree().process_frame
	_ok("la cantidad arranca en 1", F._cantidad == 1)
	var base: Resource = men.stacks[men.sel]
	var metal: MaterialData = F._metal(base)
	F._on_auto(base, metal, true)
	await get_tree().process_frame
	var piezas: int = Game.piezas_de_seleccion_forja(base, metal, F._sel)
	_ok("el Auto ▲ llena para una pieza", piezas >= 1)
	await _captura(men, "forjar_auto")
	if piezas >= 1:
		var antes_w: int = Game.owned_weapons.size()
		await F._forjar(base, metal)
		_ok("forjar deja la pieza en el baúl", Game.owned_weapons.size() == antes_w + piezas)

	print("\n=== HERRAMIENTAS ===")
	await _ir(men, _tab(men, "herramientas"))
	var H = men.herramientas
	_ok("seis herramientas", men.stacks.size() == H.TIPOS.size())
	var lingote: MaterialData = H._lingote()
	H._on_auto(int(H.TIPOS[0]), lingote, true)
	await get_tree().process_frame
	await _captura(men, "herramientas_auto")
	var antes_t: int = Game.owned_tools.size()
	await H._forjar(int(H.TIPOS[0]), lingote)
	_ok("forjar un pico lo deja en el inventario", Game.owned_tools.size() > antes_t)

	print("\n=== MEJORAR / DESHACER / REPARAR ===")
	await _ir(men, _tab(men, "mejorar"))
	_ok("mejorar lista equipo", not men.stacks.is_empty())
	_ok("dos filas de filtros por ranura", men.barra_sub.get_child_count() > 0 and men.barra_sub2.get_child_count() > 0)
	await _ir(men, _tab(men, "deshacer"))
	_ok("deshacer no lista nada equipado", not men.stacks.any(func(it): return Game.item_equipado(it)))
	var n_antes: int = Game.owned_weapons.size() + Game.owned_armor.size() + Game.owned_mochilas.size() + Game.owned_tools.size()
	var pieza_d: Resource = men.stacks[0]
	if Game.puede_fundir(pieza_d):
		await men.deshacer._deshacer(pieza_d)
		var n_despues: int = Game.owned_weapons.size() + Game.owned_armor.size() + Game.owned_mochilas.size() + Game.owned_tools.size()
		_ok("deshacer quita la pieza", n_despues == n_antes - 1)
	await _ir(men, _tab(men, "reparar"))
	_ok("reparar lista lo que lleva el primero", not men.stacks.is_empty())
	_ok("la fila de retratos dice DE QUIÉN", men._fila_artesano_rotulo.text == "DE QUIÉN")
	await _captura(men, "reparar")

	print("\n=== SIN NADA ===")
	var guardado: Array = Game.almacen_materiales.duplicate()
	Game.almacen_materiales.clear()
	for i in men.TABS_HERRERO.size():
		await _ir(men, i)
	_ok("con el baúl vacío las ocho pestañas pintan sin colgarse", true)
	await _ir(men, i_forjar)
	await _captura(men, "forjar_vacio")
	Game.almacen_materiales.assign(guardado)
	men._on_artesano(men._gente().find(Game.lider()))
	men._cerrar()


func _carpinteria() -> void:
	var men: CanvasLayer = ForgeMenu.new()
	men.modo = "carpintero"
	add_child(men)
	men.abrir()
	print("\n=== CARPINTERÍA ===")
	for i in men.TABS_CARPINTERO.size():
		await _ir(men, i)
		_ok("%s pinta algo" % men.tab_id(), not men.stacks.is_empty())
		await _captura(men, "carpinteria_%d_%s" % [i, men.tab_id()])
	await _ir(men, _tab(men, "forjar"))
	_ok("solo armas mágicas", not men.stacks.is_empty() and men.stacks.all(func(b): return Game._es_arma_magica(b)))
	await _ir(men, _tab(men, "tablones"))
	var carp: PersonajeData = Game.party[2]
	men._on_artesano(men._gente().find(carp))
	await get_tree().process_frame
	var R = men.refinar
	var i_util: int = _indice(men.stacks, func(s): return int(s["tengo"]) >= int(s["por_uno"]))
	if i_util >= 0:
		men.sel = i_util
		var antes: float = carp.carpinteria_exp
		await R.refinar(R.Que.TABLONES, men.stacks[i_util])
		_ok("aserrar suma Carpintería al artesano", carp.carpinteria_exp > antes)
	_ok("y el de la herrería sigue siendo otro", Game.artesano("herreria") != carp)
	men._on_artesano(men._gente().find(Game.lider()))
	men._cerrar()


# El baul con de todo: minerales, lingotes, chapas, hebillas, maderas, tablones, cuero y nucleos.
func _llenar_hogar() -> void:
	Game.almacen_materiales.clear()
	var ids: Array = ["cobre", "cobre_veteado", "hierro", "lingote_cobre", "lingote_cobre_veteado",
		"lingote_hierro", "chapa_cobre", "chapa_hierro", "hebillas_cobre", "madera_comun", "madera_dura",
		"tablon_comun", "tablon_duro", "cuero_curtido", "cuero_reforzado"]
	for id in ids:
		var md: MaterialData = load("res://resources/materials/%s.tres" % id) as MaterialData
		if md == null:
			continue
		Game.descubrir(md)
		for cal in [MaterialItem.Calidad.INTACTO, MaterialItem.Calidad.NORMAL]:
			for i in 12:
				Game.almacen_materiales.append(MaterialItem.crear(md, int(cal)))
	for n in Game.todos_los_nucleos():
		for i in 6:
			Game.almacen_materiales.append(MaterialItem.crear(n as MaterialData, MaterialItem.Calidad.NORMAL))


func _tab(men: Node, id: String) -> int:
	var tabs: Array = men._tabs()
	for i in tabs.size():
		if String(tabs[i]["id"]) == id:
			return i
	return 0


func _ir(men: Node, tab: int) -> void:
	men._tab = tab
	men.sel = 0
	men.decir("")
	men._al_cambiar_pantalla()
	men.rebuild()
	await get_tree().process_frame


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
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%sherreria_%s.png" % [SALIDA, nombre])
