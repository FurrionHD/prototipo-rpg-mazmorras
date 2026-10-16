# PRUEBA: el clic de los talleres (optimizacion 1D, 16/10/2026) y las recetas recordadas de Game.
#  1) En la boticaria y la cocina, pulsar cada receta pinta la MISMA ficha que el repintado entero, y la fila de
#     artesanos (que en el clic ya no se rehace) sigue viva y con la misma gente.
#  2) Cambiar de artesano SI repinta su fila (el atajo es solo para el clic de celda).
#  3) Las recetas recordadas son las mismas que cargarlas de nuevo.
extends Node

const CraftMenu = preload("res://scripts/ui/craft_menu.gd")
var fallos := 0

func _ok(c: bool, t: String) -> void:
	print(("[PASA] " if c else "[FALLA] ") + t)
	if not c:
		fallos += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	_ok(ref is SaveData, "cargada la partida de referencia")
	if ref is SaveData:
		Game.importar_partida(ref)
	for cocina in [false, true]:
		await _taller(cocina)

	# 3) Recetas recordadas = cargadas de nuevo.
	var frescas: Array = []
	for ruta in Game._RECIPE_PATHS_MENORES + Game._RECIPE_PATHS_MEDIANAS:
		frescas.append(ResourceLoader.load(ruta))
	_ok(frescas == Game.recetas_boticaria(), "recetas de la boticaria recordadas = cargadas (%d)" % frescas.size())
	var a: Array = Game.recetas_boticaria()
	a.clear()
	_ok(not Game.recetas_boticaria().is_empty(), "vaciar la lista devuelta no toca las recordadas")

	print("[taller] RESULTADO: ", "FIN: TODO BIEN" if fallos == 0 else "FALLAN %d" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)


func _taller(cocina: bool) -> void:
	var nombre: String = "cocina" if cocina else "boticaria"
	var men = CraftMenu.new()
	if cocina:
		men.modo = men.Modo.COCINA
	get_tree().root.add_child.call_deferred(men)   # la raiz esta ocupada en el primer _ready
	await _frames(2)
	Game.cerrar_menus_abiertos()
	Game._active_layer = null
	men.abrir()
	await _frames(2)
	var probadas: int = 0
	for tier in [1, 2]:
		men.tier = tier
		men.sel = 0
		men.recetas.cambio_de_receta()
		men.rebuild()
		await _frames(1)
		var n: int = men.stacks.size()
		var retratos_antes: Array = _vivos(men._fila_artesano)
		for i in range(n - 1, -1, -1):
			men._pick(i)
			var corto: String = _texto(men._content) + "#" + _texto(men._acciones)
			var retratos: Array = _vivos(men._fila_artesano)
			# UN SOLO PIE: la fila de Auto / Limpiar no se puede apilar al pulsar celdas.
			var autos: int = _texto(men._acciones).count("Auto ▲")
			if autos != 1:
				_ok(false, "%s T%d receta %d: %d filas de 'Auto' en el pie" % [nombre, tier, i, autos])
			men.rebuild()
			var largo: String = _texto(men._content) + "#" + _texto(men._acciones)
			if corto != largo or corto.length() < 5:
				_ok(false, "%s T%d receta %d: la ficha del clic no es la del repintado" % [nombre, tier, i])
			if retratos.size() != retratos_antes.size() or retratos.is_empty() and Game.party.size() > 1:
				_ok(false, "%s T%d receta %d: fila de artesanos %d (antes %d)" % [nombre, tier, i, retratos.size(),
					retratos_antes.size()])
			retratos_antes = _vivos(men._fila_artesano)
			probadas += 1
	_ok(probadas > 5, "%s: %d recetas pulsadas, la ficha es la del repintado entero" % [nombre, probadas])

	# 2) Cambiar de artesano repinta la fila (aunque se haga desde un clic de celda despues).
	var gente: Array = men._gente()
	if gente.size() > 1:
		var antes: Array = _vivos(men._fila_artesano)
		var otro: int = 1 if gente.find(Game.artesano(men.oficio())) != 1 else 0
		men._on_artesano(otro)
		var despues: Array = _vivos(men._fila_artesano)
		_ok(despues.size() == antes.size() and despues != antes, "%s: cambiar de artesano repinta su fila" % nombre)
		men._pick(0)
		_ok(_vivos(men._fila_artesano) == despues, "%s: el clic siguiente deja la fila nueva" % nombre)
	Game.cerrar_menus_abiertos()
	men.queue_free()
	await _frames(2)


func _vivos(n: Node) -> Array:
	var out: Array = []
	for h in n.get_children():
		if not MenuScaffold.muriendo(h):
			out.append(h)
	return out


func _texto(n: Node) -> String:
	var out: String = ""
	for h in n.get_children():
		if MenuScaffold.muriendo(h):
			continue
		if h is Label:
			out += (h as Label).text + "|"
		elif h is Button:
			out += (h as Button).text + "|"
		elif h is LineEdit:
			out += (h as LineEdit).text + "|"
		out += _texto(h)
	return out
