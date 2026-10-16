# PRUEBA: el ATAJO DEL CLIC del maestro (optimizacion 1D, 16/10/2026) y las plantillas / libros recordados.
#  1) En Tecnicas, pulsar una tecnica marca su fila y repinta solo la ficha: la ficha ha de salir IGUAL que con el
#     repintado entero, en todas las armas y todas sus tecnicas, y la fila marcada ha de ser la pulsada.
#  2) Las plantillas recordadas son las mismas que cargar el catalogo de nuevo.
#  3) Meditacion y Biblioteca se pintan (usan los libros recordados) y la biblioteca cuenta los mismos libros.
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
	var men = load("res://scripts/ui/maestro_menu.gd").new()
	get_tree().root.add_child.call_deferred(men)
	await _frames(3)
	men.abrir()
	await _frames(2)

	# 1) EL ATAJO, arma por arma.
	var armas: int = men._plantillas().size()
	_ok(armas > 3, "armas con tecnicas: %d" % armas)
	var probadas: int = 0
	for a in armas:
		men._pick_arma(a)
		await _frames(1)
		var n: int = men._tecnicas().size()
		for i in range(n - 1, -1, -1):
			men._pick(i)
			var corto: String = _texto(men._content)
			var marcada: bool = _marcada(men._lista, i, n)
			men._rebuild()
			var largo: String = _texto(men._content)
			if corto != largo or corto == "" or not marcada or men._sel != i:
				_ok(false, "arma %d tecnica %d: atajo '%s' / largo '%s' / marcada %s" % [a, i, corto.left(60),
					largo.left(60), marcada])
			probadas += 1
	_ok(probadas > 10, "%d tecnicas pulsadas: la ficha del atajo es la del repintado entero" % probadas)

	# 2) Las plantillas recordadas = el catalogo cargado de nuevo.
	var frescas: Array = []
	for ruta in CatalogoEquipo.ARMAS + CatalogoEquipo.SECUNDARIAS:
		var it: Resource = load(ruta)
		if it != null and not it.habilidades.is_empty():
			frescas.append(it)
	_ok(frescas == men._plantillas(), "plantillas recordadas = catalogo (%d)" % frescas.size())

	# 3) Las otras dos pestañas, dos veces (la segunda con los libros ya recordados).
	for vuelta in 2:
		men._on_tab(men.TAB_MEDITACION)
		await _frames(1)
		men._on_tab(men.TAB_BIBLIOTECA)
		await _frames(1)
		var txt: String = _texto(men._lista)
		_ok(txt.contains("Llevas") and txt.contains("de %d" % Libros.todos().size()),
			"biblioteca pintada (vuelta %d)" % (vuelta + 1))

	print("[maestro] RESULTADO: ", "FIN: TODO BIEN" if fallos == 0 else "FALLAN %d" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)


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


func _marcada(lista: Node, i: int, n: int) -> bool:
	for h in lista.get_children():
		if h is GridContainer and not MenuScaffold.muriendo(h):
			if h.get_child_count() != n:
				return false
			for k in n:
				if (h.get_child(k) as BaseButton).button_pressed != (k == i):
					return false
			return true
	return false
