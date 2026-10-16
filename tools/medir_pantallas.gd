# ============================================================
#  MEDIR LAS PANTALLAS (plan de optimizacion, fase 1D): cuanto cuesta ABRIR cada menu, cambiar de pestaña y
#  pulsar una celda, con la partida grande (tools/huellas/mundo_ref.tres). Abre los menus de verdad como los
#  visores (tools/visores/dev_*.gd) y cronometra cada llamada.
#  Va CON VENTANA a proposito: sin ella los retratos no se hornean y siguen con el muneco vivo (otra cuenta).
#    godot --path . res://tools/medir_pantallas.tscn > salida.txt
#    godot --path . res://tools/medir_pantallas.tscn -- --solo inventario > salida.txt
# OJO: la salida a un FICHERO, nunca por una tuberia (ver medir_fotograma.gd).
# No es una prueba (no esta en la bateria): es una herramienta de medida.
# ============================================================
extends Node

const VECES := 5   # cada accion se repite y se da la MEJOR y la mediana (el PC baila)

var _solo: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = a.find("--solo")
	if i >= 0 and i + 1 < a.size():
		_solo = a[i + 1]
	call_deferred("_correr")


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.asegurar_uids()
	_falso_jugador()
	# EL PUEBLO DE MENTIRA: el equipo solo se cambia en el pueblo (Game.en_pueblo mira la escena actual).
	if get_tree().current_scene != null:
		get_tree().current_scene.scene_file_path = "res://scenes/town.tscn"
	for k in 10:
		await get_tree().process_frame
	print("[PANTALLAS] party=%d plantilla=%d  bolsa=%d  baul=%d  cofre_equipo=%d" % [Game.party.size(),
		Game.plantilla.size(), Game.bolsa.total(), Game.baul.total(), Game.cofre_equipo.size()])
	for p in ["inventario", "tienda", "hogar", "taller", "personaje", "maestro"]:
		if _solo != "" and _solo != p:
			continue
		print("[PANTALLAS] ===== %s" % p)
		await call("_p_" + p)
		Game.cerrar_menus_abiertos()
		Game._active_layer = null
		for k in 3:
			await get_tree().process_frame
	get_tree().quit(0)


# Cronometra 'f' VECES (con un fotograma entre medias para que se libere lo vaciado) y saca la mejor y la mediana.
func _medir(que: String, f: Callable) -> void:
	var tiempos: Array = []
	for k in VECES:
		var t0: int = Time.get_ticks_usec()
		f.call()
		tiempos.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		await get_tree().process_frame
		await get_tree().process_frame
	tiempos.sort()
	print("[PANTALLAS]   %-44s mejor %7.2f ms   mediana %7.2f ms" % [que, tiempos[0],
		tiempos[tiempos.size() / 2]])


func _p_inventario() -> void:
	var inv: CanvasLayer = preload("res://scripts/ui/inventory_menu.gd").new()
	add_child(inv)
	await _medir("abrir", func(): inv._set_open(false); inv._set_open(true))
	for i in inv.TABS.size():
		await _medir("pestaña %s" % inv.TABS[i], func(): inv._on_tab(i))
		var n: int = inv._stacks.size()
		if n > 1:
			await _medir("   clic (de %d celdas)" % n, func(): inv._pick(n / 2 if inv._sel != n / 2 else 1))
	# DESGLOSE de la pestaña de Materiales: calcular la lista contra pintar la rejilla.
	inv._on_tab(inv.TABS.find("Materiales"))
	var c: Array = [[], [], [], []]   # una CAJA: las lambdas capturan por valor y una variable suelta no sale
	await _medir("   materiales: montones()", func(): c[0] = Game.baul.montones())
	await _medir("   materiales: _agrupar", func(): c[1] = inv._agrupar(c[0]))
	await _medir("   materiales: _aplicar", func(): c[2] = inv._aplicar(c[1]))
	await _medir("   materiales: _piezas_stacks", func(): c[3] = inv._piezas_stacks(c[2]))
	print("[PANTALLAS]      (%d montones, %d agrupados, %d piezas)" % [c[0].size(), c[1].size(), c[3].size()])
	await _medir("   materiales: rejilla_objetos", func():
		MenuScaffold.vaciar(inv._lista)
		MenuScaffold.rejilla_objetos(inv._lista, c[3], 0, inv._pick, inv._columnas(), inv.LADO_CELDA))
	inv._set_open(false)
	inv.queue_free()


func _p_tienda() -> void:
	var men: CanvasLayer = preload("res://scripts/ui/shop_menu.gd").new()
	add_child(men)
	Game.pack_inicial_reclamado = true
	await _medir("abrir", func(): Game.cerrar_menus_abiertos(); Game._active_layer = null; men.abrir())
	for i in 3:
		await _medir("pestaña %s" % men.TABS[i], func(): men._on_tab(i))
		var n: int = men.stacks.size()
		if n > 1:
			await _medir("   clic (de %d celdas)" % n, func(): men._pick(n / 2 if men.sel != n / 2 else 1))
	men.queue_free()


func _p_hogar() -> void:
	var men: CanvasLayer = preload("res://scripts/ui/home_menu.gd").new()
	add_child(men)
	await _medir("abrir", func(): Game.cerrar_menus_abiertos(); Game._active_layer = null; men.abrir())
	for i in men.TABS.size():
		await _medir("pestaña %s" % men.TABS[i], func(): men._on_tab(i))
	var alm = men.get("almacen")
	if alm != null:
		for c in alm.CATEGORIAS.size():
			await _medir("cofre categoria %d" % c, func(): alm._cat = -1; alm._on_cat(c))
			if c == alm.CAT_HUCHA:
				continue   # sin rejilla
			for lado in [alm.LADO_ENCIMA, alm.LADO_CASA]:
				var n: int = (alm._stacks[lado] as Array).size()
				if n > 1:
					await _medir("   clic lado %d (de %d celdas)" % [lado, n],
						func(): alm._pick(n / 2 if alm._sel != n / 2 else 1, lado))
	men.queue_free()


func _p_taller() -> void:
	var men: CanvasLayer = preload("res://scripts/ui/craft_menu.gd").new()
	add_child(men)
	await _medir("abrir boticaria", func(): Game.cerrar_menus_abiertos(); Game._active_layer = null; men.abrir())
	for t in 2:   # la boticaria tiene dos (menores y medianas)
		await _medir("tier %d" % (t + 1), func():
			men.tier = t + 1
			men.sel = 0
			men.recetas.cambio_de_receta()
			men.rebuild())
		var n: int = men.stacks.size()
		if n > 1:
			await _medir("   clic (de %d celdas)" % n, func(): men._pick(n / 2 if men.sel != n / 2 else 1))
	# DESGLOSE del clic.
	await _medir("   boticaria: pintar_artesanos", func():
		men.pintar_artesanos(men.oficio(), "pocion", "Tiene Mezcla"))
	await _medir("   boticaria: _cuantas_salen x todas", func():
		Game.abrir_recuento_hogar()
		for r in men.stacks:
			men.recetas._cuantas_salen(r)
		Game.cerrar_recuento_hogar())
	await _medir("   boticaria: _cuantas_salen SIN recuento", func():
		for r in men.stacks:
			men.recetas._cuantas_salen(r))
	await _medir("   boticaria: _ficha", func():
		Game.abrir_recuento_hogar()
		MenuScaffold.vaciar(men._content)
		men.recetas._ficha(men._content)
		Game.cerrar_recuento_hogar())
	var R = men.recetas
	var r: RecipeData = men.stacks[men.sel]
	var vb: VBoxContainer = men._content
	# Cada medida VACIA antes su zona: sin esto las 5 repeticiones se apilaban en pantalla (5 filas de "Auto"
	# iguales en la ventana, visto el 16/10; en el juego no pasa, ver prueba_taller_clic).
	var envuelto := func(f: Callable) -> Callable:
		return func():
			MenuScaffold.vaciar(men._content)
			MenuScaffold.vaciar(men._acciones)
			Game.abrir_recuento_hogar()
			f.call()
			Game.cerrar_recuento_hogar()
	await _medir("   ficha: _capar_y_publicar", envuelto.call(func(): R._capar_y_publicar(r)))
	await _medir("   ficha: banner_item", func(): MenuScaffold.vaciar(vb); MenuScaffold.banner_item(vb, r.resultado, "", "x"))
	await _medir("   ficha: resumen", func(): r.resultado.resumen(Game.player_max_hp(), Game.player_max_mp()))
	await _medir("   ficha: pociones_de_seleccion", func(): Game.pociones_de_seleccion(r, R._seleccion))
	await _medir("   ficha: _ingrediente x todos", envuelto.call(func():
		for i in r.ingredientes.size():
			if r.ingredientes[i] != null and r.ingredientes[i].material != null:
				R._ingrediente(vb, i, r.ingredientes[i].material, 4)))
	await _medir("   ficha: _doble", envuelto.call(func(): R._doble(vb, r, 1)))
	await _medir("   ficha: _pie", envuelto.call(func(): R._pie(r, 1)))
	await _medir("   ficha: _partir_lineas", func(): men._partir_lineas(men._content))
	men.queue_free()


func _p_personaje() -> void:
	var men: CanvasLayer = preload("res://scripts/ui/character_menu.gd").new()
	add_child(men)
	await _medir("abrir", func(): men._set_open(false); men._set_open(true))
	for s in [men.SEC_FICHA, men.SEC_ARMAS, men.SEC_ARMADURA, men.SEC_HABILIDADES, men.SEC_DESARROLLO]:
		await _medir("seccion %d" % s, func(): men._sec = -1; men._on_seccion(s))
		await _medir("   clic ranura", func(): men._pick(1 if men._sel != 1 else 0))
	men._on_seccion(men.SEC_ARMAS)
	men._pick(0)
	if men.has_method("_cambiar") or "_cambiando" in men:
		men._cambiando = true
		men._rebuild()
		var n: int = men._catalogo().size()
		print("[PANTALLAS]   (cambiar arma: %d candidatos)" % n)
		if n > 1:
			await _medir("   clic candidato", func(): men._pick_cand(n / 2 if men._cand != n / 2 else 1))
		men._cambiando = false
	await _medir("cambiar de persona", func(): men._pick_persona(1 if men._pj_sel != 1 else 0))
	men._set_open(false)
	men.queue_free()


func _p_maestro() -> void:
	var men: CanvasLayer = preload("res://scripts/ui/maestro_menu.gd").new()
	add_child(men)
	await _medir("abrir", func(): Game.cerrar_menus_abiertos(); Game._active_layer = null; men.abrir())
	for i in men.TABS.size():
		await _medir("pestaña %s" % men.TABS[i], func(): men._tab = -1; men._on_tab(i))
		await _medir("   clic", func(): men._pick(1 if men._sel != 1 else 0))
	await _medir("cambiar de persona", func(): men._pick_persona(1 if men._pj_sel != 1 else 0))
	# DESGLOSE de Tecnicas.
	men._on_tab(men.TAB_TECNICAS)
	var pj: PersonajeData = men._pj()
	await _medir("   tecnicas: retratos", func():
		MenuScaffold.retratos(men._fila_retratos, men._gente(), men._pj_sel, Game.party.size(), men._pick_persona))
	await _medir("   tecnicas: _pintar_armas", func(): men._pintar_armas(pj))
	await _medir("   tecnicas: _pintar_tecnicas", func(): MenuScaffold.vaciar(men._lista); men._pintar_tecnicas(pj, men._arma()))
	await _medir("   tecnicas: _pintar_ficha", func(): MenuScaffold.vaciar(men._content); men._pintar_ficha(pj))
	men.queue_free()


func _falso_jugador() -> void:
	var sc := GDScript.new()
	sc.source_code = """
extends Node
func aguante_de_grupo(pj) -> Vector2:
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
