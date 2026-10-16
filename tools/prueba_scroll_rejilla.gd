# PRUEBA: pulsar una celda de muy abajo en el inventario NO sube el scroll (bug del 14/09/2026).
# Monta el menu de verdad con la bolsa llena, baja del todo, pulsa una celda de abajo por su señal.
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
	Game.semilla_mundo = 1
	for r in Game.rutas_materiales():
		var d = load(r)
		if d is MaterialData:
			for cal in [MaterialItem.Calidad.PURO, MaterialItem.Calidad.INTACTO, MaterialItem.Calidad.NORMAL, MaterialItem.Calidad.DANADO]:
				Game.bolsa.anadir(MaterialItem.crear(d, cal))
	var menu = load("res://scripts/ui/inventory_menu.gd").new()
	get_tree().root.add_child.call_deferred(menu)
	await _frames(3)
	menu._set_open(true)
	await _frames(30)
	var scroll: ScrollContainer = MenuScaffold._scroll_de(menu._lista)
	var grid: GridContainer = null
	for h in menu._lista.get_children():
		if h is GridContainer:
			grid = h
	var total: int = menu._stacks.size()
	# REJILLA PEREZOSA (optimizacion 1D, 16/10/2026): sin bajar, solo las de arriba y un espaciador debajo.
	var hueco: Control = grid.get_meta(MenuScaffold.META_HUECO_REJILLA, null) if grid else null
	_ok(grid != null and grid.get_child_count() > 60 and grid.get_child_count() < total,
		"sin bajar se crean pocas (%d de %d)" % [grid.get_child_count() if grid else 0, total])
	_ok(hueco != null and hueco.custom_minimum_size.y > 1000, "hay espaciador con el alto de lo que falta (%d px)" % (hueco.custom_minimum_size.y if hueco else 0))
	var alto_lista: float = menu._lista.size.y
	scroll.scroll_vertical = 1000000
	await _frames(2)
	var abajo: int = scroll.scroll_vertical
	_ok(abajo > 200, "el scroll baja (%d px)" % abajo)
	var saltos := 0
	for k in 300:
		if grid.get_child_count() >= total:
			break
		await _frames(1)
		if absi(scroll.scroll_vertical - abajo) > 12:
			saltos += 1
	await _frames(3)
	_ok(grid.get_child_count() == total, "bajando se crean todas (%d de %d)" % [grid.get_child_count(), total])
	_ok(not is_instance_valid(hueco) or hueco.is_queued_for_deletion(), "el espaciador se va al acabar")
	_ok(saltos == 0 and absi(scroll.scroll_vertical - abajo) <= 12,
		"el scroll no salta mientras se crean (%d, antes %d; %d saltos)" % [scroll.scroll_vertical, abajo, saltos])
	_ok(absf(menu._lista.size.y - alto_lista) <= 12, "la lista mide lo mismo antes y despues (%d -> %d)" % [alto_lista, menu._lista.size.y])
	abajo = scroll.scroll_vertical
	var idx: int = grid.get_child_count() - 2
	(grid.get_child(idx) as BaseButton).pressed.emit()
	await _frames(20)
	_ok(scroll.scroll_vertical == abajo, "tras pulsar la celda %d el scroll sigue abajo (%d, antes %d)" % [idx, scroll.scroll_vertical, abajo])
	var grid2: GridContainer = null
	for h in menu._lista.get_children():
		if h is GridContainer and not MenuScaffold.muriendo(h):
			grid2 = h
	_ok(grid2 == grid, "la rejilla no se ha rehecho")
	_ok(menu._sel == idx, "la seleccion es la pulsada (%d)" % menu._sel)
	var marcadas := 0
	for c in grid2.get_children():
		if (c as BaseButton).button_pressed:
			marcadas += 1
	_ok(marcadas == 1 and (grid2.get_child(idx) as BaseButton).button_pressed, "una sola celda marcada, la pulsada")
	print("[scroll] RESULTADO: ", "TODO PASA" if fallos == 0 else "FALLAN %d" % fallos)
	get_tree().quit()
