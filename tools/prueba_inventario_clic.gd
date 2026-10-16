# PRUEBA: el ATAJO DEL CLIC del inventario (optimizacion 1D, 16/10/2026) y las claves de orden precalculadas.
#  1) Pulsar una celda repinta SOLO la ficha (sin recalcular la pestaña): la ficha tiene que salir IGUAL que por el
#     camino largo (_rebuild entero), en cada pestaña y en varias celdas, y la celda marcada ha de ser la pulsada.
#  2) _ordenar con las claves calculadas una vez da el MISMO orden que comparar calculandolas dentro del comparador
#     (lo de antes), para cada criterio de la pestaña de materiales y en los dos sentidos.
# Con la partida grande (tools/huellas/mundo_ref.tres: 702 montones de materiales en el baul).
extends Node

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
	var menu = load("res://scripts/ui/inventory_menu.gd").new()
	get_tree().root.add_child.call_deferred(menu)
	await _frames(3)
	menu._set_open(true)
	await _frames(3)

	# 1) EL ATAJO: misma ficha que el camino largo.
	for t in menu.TABS.size():
		menu._on_tab(t)
		var n: int = menu._stacks.size()
		var scroll: ScrollContainer = MenuScaffold._scroll_de(menu._lista)
		for k in 300:   # la rejilla se crea por tandas AL BAJAR (MenuScaffold._rejilla_perezosa): bajar hasta la ultima celda
			if _celdas(menu._lista) >= n:
				break
			scroll.scroll_vertical = 1000000
			await _frames(1)
		if n < 2:
			print("[clic] pestaña %s: %d celdas, sin nada que pulsar" % [menu.TABS[t], n])
			continue
		for i in [n - 1, n / 2, 1, 0]:
			menu._pick(i)
			var corto: String = _texto(menu._content)
			var marcada: bool = _marcada(menu._lista, i)
			menu._preview_pintado = Callable()   # sin ficha recordada: _pick va por el _rebuild entero
			menu._pick(i)
			var largo: String = _texto(menu._content)
			_ok(corto == largo and corto != "", "%s celda %d/%d: la ficha del atajo es la del camino largo" % [menu.TABS[t], i, n])
			_ok(marcada and menu._sel == i, "%s celda %d: marcada la pulsada" % [menu.TABS[t], i])
			await _frames(1)

	# 2) EL ORDEN: el de antes (claves dentro del comparador) contra el de ahora.
	menu._on_tab(menu.TABS.find("Materiales"))
	await _frames(1)
	var base: Array = menu._stacks_sin_filtrar
	_ok(base.size() > 100, "materiales para ordenar: %d montones" % base.size())
	var o: Dictionary = menu._orden_actual()
	var campo0: String = o["campo"]
	var desc0: bool = o["desc"]
	var campos: Array = [""]
	for c in menu._criterios_orden():
		if not campos.has(String(c["campo"])):
			campos.append(String(c["campo"]))
	for campo in campos:
		for desc in [true, false]:
			o["campo"] = campo
			o["desc"] = desc
			var ahora: Array = menu._ordenar(base)
			var antes: Array = _orden_viejo(menu, base, campo, desc)
			if campo == "":
				_ok(ahora == antes, "predeterminado: mismo orden exacto")
				break   # el predeterminado no tiene sentido
			# sort_custom no es estable: en los empates el orden puede variar, asi que se compara la CLAVE de cada puesto.
			var iguales: bool = ahora.size() == antes.size()
			for k in mini(ahora.size(), antes.size()):
				if _clave(menu, ahora[k], campo) != _clave(menu, antes[k], campo):
					iguales = false
					break
			_ok(iguales, "orden por '%s' %s: mismas claves puesto a puesto" % [campo, "desc" if desc else "asc"])
	o["campo"] = campo0
	o["desc"] = desc0

	print("[clic] RESULTADO: ", "FIN: TODO BIEN" if fallos == 0 else "FALLAN %d" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)


func _clave(menu, s: Dictionary, campo: String):
	return menu._nombre_orden(s) if campo == "nombre" else menu._valor_orden(s, campo)


# El orden de ANTES de la optimizacion, copiado tal cual: las claves se calculan dentro del comparador.
func _orden_viejo(menu, stacks: Array, campo: String, desc: bool) -> Array:
	if campo == "":
		var primero: Dictionary = {}
		for i in stacks.size():
			var k: String = menu._grupo_orden(stacks[i]["modelo"], i)
			if not primero.has(k):
				primero[k] = i
		var idx: Array = range(stacks.size())
		idx.sort_custom(func(a, b):
			var ga: int = primero[menu._grupo_orden(stacks[a]["modelo"], a)]
			var gb: int = primero[menu._grupo_orden(stacks[b]["modelo"], b)]
			if ga != gb:
				return ga < gb
			var ra: float = menu._rango_estado(stacks[a]["modelo"])
			var rb: float = menu._rango_estado(stacks[b]["modelo"])
			if ra != rb:
				return ra > rb
			return a < b)
		var out: Array = []
		for i in idx:
			out.append(stacks[i])
		return out
	var out2: Array = stacks.duplicate()
	out2.sort_custom(func(a, b):
		var va = _clave(menu, a, campo)
		var vb = _clave(menu, b, campo)
		return (va > vb) if desc else (va < vb))
	return out2


# Todo el texto que se ve en una zona (Labels y Buttons, en orden de arbol).
func _texto(n: Node) -> String:
	var out: String = ""
	for h in n.get_children():
		if MenuScaffold.muriendo(h):
			continue
		if h is Label:
			out += (h as Label).text + "|"
		elif h is Button:
			out += (h as Button).text + "|"
		elif h is RichTextLabel:
			out += (h as RichTextLabel).text + "|"
		out += _texto(h)
	return out


func _marcada(lista: Node, i: int) -> bool:
	for h in lista.get_children():
		if h is GridContainer and not MenuScaffold.muriendo(h):
			var c: Node = h.get_child(i) if i < h.get_child_count() else null
			return c is BaseButton and (c as BaseButton).button_pressed
	return false


func _celdas(lista: Node) -> int:
	for h in lista.get_children():
		if h is GridContainer and not MenuScaffold.muriendo(h):
			return h.get_child_count()
	return 0
