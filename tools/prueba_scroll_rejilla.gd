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
				Game.materiales.append(MaterialItem.crear(d, cal))
	var menu = load("res://scripts/ui/inventory_menu.gd").new()
	get_tree().root.add_child.call_deferred(menu)
	await _frames(3)
	menu._set_open(true)
	await _frames(60)   # que se creen todas las tandas de celdas
	var scroll: ScrollContainer = null
	var p: Node = menu._lista.get_parent()
	while p != null and not (p is ScrollContainer):
		p = p.get_parent()
	scroll = p
	var grid: GridContainer = null
	for h in menu._lista.get_children():
		if h is GridContainer:
			grid = h
	_ok(grid != null and grid.get_child_count() > 60, "rejilla llena (%d celdas)" % (grid.get_child_count() if grid else 0))
	scroll.scroll_vertical = 1000000
	await _frames(5)
	var abajo: int = scroll.scroll_vertical
	_ok(abajo > 200, "el scroll baja (%d px)" % abajo)
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
