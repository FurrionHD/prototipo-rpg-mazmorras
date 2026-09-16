# ============================================================
#  dev_taller.gd  --  HERRAMIENTA, no parte del juego.
#
#  Abre la BOTICARIA y la COCINA de verdad (scripts/ui/craft_menu.gd, rehecho el 16/09/2026 con la
#  cara del inventario) con el Hogar lleno y las recorre, comprobando lo que el rework promete:
#    - que la rejilla son las recetas del tier y la celda enseña LO QUE SALE;
#    - que el filtro Vida / Maná / Antídotos filtra (y que la cocina no lo lleva);
#    - que la cantidad arranca en 1 y el Auto no pide mas de lo que hay;
#    - que fabricar cobra y da lo anunciado, y que una mejora gasta la poción base;
#    - que la excelia del oficio va AL ARTESANO ELEGIDO, y que cada taller recuerda el suyo.
#
#  DOS MODOS, como dev_peleteria: --headless solo comprueba; con ventana (herramientas/ver_taller.bat)
#  saca ademas capturas en tools/salida/taller_*.png. Devuelve codigo != 0 si algo falla.
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
const PartidaDePrueba = preload("res://tools/visores/partida_de_prueba.gd")
const CraftMenu = preload("res://scripts/ui/craft_menu.gd")

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
	# Uno del grupo con Mezcla y otro con Cocina, para que la marca del retrato salga en la captura.
	(Game.party[2] as PersonajeData).desarrollos_rango["mezcla"] = 1
	(Game.party[1] as PersonajeData).desarrollos_rango["cocina"] = 1
	for pj in Game.party:
		if pj != Game.party[2]:
			(pj as PersonajeData).desarrollos_rango.erase("mezcla")
		if pj != Game.party[1]:
			(pj as PersonajeData).desarrollos_rango.erase("cocina")

	await _boticaria()
	await _cocina()

	if _fallos == 0:
		print("\nOK: las %d comprobaciones pasan." % _hechas)
	else:
		printerr("\nFALLAN %d de %d comprobaciones." % [_fallos, _hechas])
	get_tree().quit(1 if _fallos > 0 else 0)


func _boticaria() -> void:
	var men: CanvasLayer = CraftMenu.new()
	add_child(men)
	men.abrir()
	var R = men.recetas

	print("=== BOTICARIA: la rejilla son las recetas ===")
	await _ir(men, 1)
	_ok("no está vacía", not men.stacks.is_empty())
	_ok("son las recetas de las menores",
		men.stacks.size() == Game.recetas_boticaria_tier(1).size())
	_ok("la celda enseña la poción que sale (el primero es un ConsumableData)",
		men._lista.get_child(0).get_child(0).item is ConsumableData)
	_ok("van en orden de cadena: vida delante",
		R._tipo_de((men.stacks[0] as RecipeData).resultado) == R.TIPO_VIDA)
	_ok("la pestaña de medianas sale solo si están desbloqueadas",
		(men._tab_buttons[1] as Button).visible == Game.medianas_desbloqueadas())
	_ok("arranca en una receta con material", R._hay_material_para(men.stacks[men.sel]))
	_ok("la cantidad arranca en 1", R._cantidad == 1)
	await _captura(men, "pociones")

	print("\n=== BOTICARIA: el filtro ===")
	for f in [1, 2]:
		R._on_filtro(f)
		await get_tree().process_frame
		var ajenas: bool = men.stacks.any(func(r): return R._tipo_de((r as RecipeData).resultado) != f - 1)
		_ok("el filtro %s deja solo las suyas" % R.FILTROS[f], not men.stacks.is_empty() and not ajenas)
	_ok("las menores no tienen antídotos: su filtro no sale", men.barra_sub.get_child_count() == 3)
	R._on_filtro(0)
	await get_tree().process_frame
	_ok("Todo las devuelve todas", men.stacks.size() == Game.recetas_boticaria_tier(1).size())

	print("\n=== BOTICARIA: fabricar ===")
	# La lambda en UNA linea: partida, el parser corta en el salto y headless se cuelga sin decir por que.
	var i_base: int = _indice(men.stacks, func(r): return not (r as RecipeData).es_mejora() and R._tipo_de((r as RecipeData).resultado) == R.TIPO_VIDA)
	_ok("está la poción de vida base", i_base >= 0)
	if i_base >= 0:
		men._pick(i_base)
		await get_tree().process_frame
		var r: RecipeData = men.stacks[men.sel]
		R._cantidad = 2
		R._on_auto(true)
		await get_tree().process_frame
		var hornadas: int = Game.pociones_de_seleccion(r, R._seleccion)
		_ok("el Auto ▲ llena para 2", hornadas == 2)
		var ing: MaterialData = r.ingredientes[0].material
		_ok("y no pide más de lo que hay",
			Game.uds_seleccion(R._seleccion[0]) <= Game.disponible_unidades_material_en_hogar(ing))
		await _captura(men, "pociones_auto")
		var antes: int = int(Game.consumables.get(r.resultado, 0))
		var antes_mat: int = Game.disponible_unidades_material_en_hogar(ing)
		await R._on_fabricar()
		var gano: int = int(Game.consumables.get(r.resultado, 0)) - antes
		_ok("fabricar da 2 pociones (o 3-4 si sale doble): %d" % gano, gano >= 2 and gano <= 4)
		_ok("y cobra el material", Game.disponible_unidades_material_en_hogar(ing) < antes_mat)
		_ok("y suelta la selección", not R._seleccion.any(func(d): return not (d as Dictionary).is_empty()))
		# Cambiar de receta devuelve la cantidad a 1.
		men._pick(i_base + 1)
		await get_tree().process_frame
		_ok("otra receta: la cantidad vuelve a 1", R._cantidad == 1)
		var mejora: RecipeData = men.stacks[men.sel]
		if mejora.es_mejora() and int(Game.consumables.get(mejora.pocion_base, 0)) > 0:
			var base_antes: int = int(Game.consumables.get(mejora.pocion_base, 0))
			R._cantidad = 1
			R._on_auto(true)
			await get_tree().process_frame
			await _captura(men, "pociones_mejora")
			await R._on_fabricar()
			_ok("una mejora gasta la poción base",
				int(Game.consumables.get(mejora.pocion_base, 0)) == base_antes - 1)

	print("\n=== BOTICARIA: medianas ===")
	if Game.medianas_desbloqueadas():
		await _ir(men, 2)
		_ok("las medianas son las suyas", men.stacks.size() == Game.recetas_boticaria_tier(2).size())
		await _captura(men, "pociones_medianas")
		R._on_filtro(3)
		await get_tree().process_frame
		_ok("en las medianas sale el filtro de antídotos", men.barra_sub.get_child_count() == 4)
		var no_antidoto: bool = men.stacks.any(func(r): return not (r as RecipeData).resultado.es_brebaje_de_estado())
		_ok("y deja solo antídotos", not men.stacks.is_empty() and not no_antidoto)
		await _captura(men, "pociones_antidotos")
		R._on_filtro(0)

	print("\n=== BOTICARIA: QUIÉN TRABAJA ===")
	await _ir(men, 1)
	var gente: Array = men._gente()
	_ok("la fila lleva a toda la plantilla", gente.size() == Game.plantilla.size())
	_ok("empieza por el líder", Game.artesano("mezcla") == Game.lider())
	var otro: PersonajeData = Game.party[2]
	men._on_artesano(gente.find(otro))
	await get_tree().process_frame
	_ok("elegir a otro lo pone al mando", Game.artesano("mezcla") == otro)
	_ok("y NO cambia quien cocina", Game.artesano("cocina") == Game.lider())
	_ok("ni quien curte", Game.artesano("peleteria") == Game.lider())
	_ok("su Mezcla es la del taller", Game.mezcla_activa() > 0.0)
	var antes_otro: float = otro.mezcla_exp
	var antes_lider: float = Game.lider().mezcla_exp
	men.sel = 0
	R.cambio_de_receta()
	men.rebuild()
	R._on_auto(true)
	await R._on_fabricar()
	_ok("fabricar le suma la Mezcla A ÉL", otro.mezcla_exp > antes_otro)
	_ok("y no al líder", is_equal_approx(Game.lider().mezcla_exp, antes_lider))
	await _captura(men, "pociones_artesano")
	men._on_artesano(gente.find(Game.lider()))
	await get_tree().process_frame
	_ok("volver al líder lo deja como estaba", Game.artesano("mezcla") == Game.lider())
	men._cerrar()


func _cocina() -> void:
	var men: CanvasLayer = CraftMenu.new()
	men.modo = men.Modo.COCINA
	add_child(men)
	men.abrir()
	var R = men.recetas

	print("\n=== COCINA ===")
	await _ir(men, 1)
	_ok("es la cocina", men.is_in_group("cocina_menu"))
	_ok("son los platos de la cueva", men.stacks.size() == Game.recetas_cocina_tier(1).size())
	_ok("no lleva filtro de tipo", men.barra_sub.get_child_count() == 0)
	_ok("las dos pestañas se ven desde el primer día", (men._tab_buttons[1] as Button).visible)
	await _captura(men, "cocina")

	var i_hay: int = _indice(men.stacks, func(r): return R._hay_material_para(r))
	_ok("hay un plato que se puede cocinar", i_hay >= 0)
	if i_hay >= 0:
		men._pick(i_hay)
		await get_tree().process_frame
		var cocinero: PersonajeData = Game.party[1]
		men._on_artesano(men._gente().find(cocinero))
		await get_tree().process_frame
		_ok("cada taller recuerda el suyo", Game.artesano("cocina") == cocinero
			and Game.artesano("mezcla") == Game.lider())
		var r: RecipeData = men.stacks[men.sel]
		R._on_auto(true)
		await get_tree().process_frame
		await _captura(men, "cocina_auto")
		var antes: int = int(Game.consumables.get(r.resultado, 0))
		var antes_exp: float = cocinero.cocina_exp
		await R._on_fabricar()
		_ok("cocinar da platos", int(Game.consumables.get(r.resultado, 0)) > antes)
		_ok("y la Cocina va al cocinero elegido", cocinero.cocina_exp > antes_exp)
		men._on_artesano(men._gente().find(Game.lider()))

	await _ir(men, 2)
	_ok("de lo hondo son los suyos", men.stacks.size() == Game.recetas_cocina_tier(2).size())
	await _captura(men, "cocina_hondo")

	print("\n=== SIN NADA ===")
	Game.almacen_materiales.clear()
	await _ir(men, 1)
	_ok("con el baúl vacío la rejilla sigue (las recetas se ven igual) y no revienta",
		men.stacks.size() == Game.recetas_cocina_tier(1).size())
	await _captura(men, "cocina_vacio")
	men._cerrar()


# El baul lleno con los ingredientes de TODAS las recetas, en dos o tres calidades, y alguna poción
# base para poder probar las mejoras.
func _llenar_hogar() -> void:
	Game.almacen_materiales.clear()
	var vistos: Dictionary = {}
	var todas: Array = Game.recetas_boticaria() + Game.recetas_cocina()
	for r in todas:
		for ing in (r as RecipeData).ingredientes:
			if ing == null or ing.material == null or vistos.has(ing.material):
				continue
			var md: MaterialData = ing.material
			vistos[md] = true
			Game.descubrir(md)
			var cals: Array = [MaterialItem.Calidad.INTACTO, MaterialItem.Calidad.NORMAL]
			if vistos.size() % 3 == 0:
				cals.append(MaterialItem.Calidad.DANADO)
			for cal in cals:
				for i in 8:
					Game.almacen_materiales.append(MaterialItem.crear(md, int(cal)))


func _ir(men: Node, tier: int) -> void:
	men.tier = tier
	men.sel = 0
	men.decir("")
	men.recetas.cambio_de_receta()
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
	get_viewport().get_texture().get_image().save_png("%staller_%s.png" % [SALIDA, nombre])
