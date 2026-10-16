# PRUEBA: el panel de debug se monta PEREZOSO (optimizacion 1D, 16/10/2026): al entrar en escena no construye nada
# (eran ~190 ms en cada cambio de escena) y al abrirlo por primera vez se construye entero, una sola vez.
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
	var p = load("res://scripts/ui/debug_panel.gd").new()
	var t0: int = Time.get_ticks_usec()
	add_child.call_deferred(p)
	await _frames(2)
	print("[debug] montar: %.2f ms" % (float(Time.get_ticks_usec() - t0) / 1000.0))
	_ok(p._panel != null and p._panel.get_child_count() == 0, "al montarse el panel esta vacio")
	_ok(not p._panel.visible and not Game.debug_panel_open, "y cerrado")
	p._toggle()
	await _frames(1)
	_ok(p._panel.visible and Game.debug_panel_open, "al abrirlo se ve")
	_ok(p._panel.get_child_count() == 1, "y se ha construido")
	_ok(p._floor_edit != null and p._floor_edit.text == str(Game.current_floor), "con los datos de Game (piso %s)" % p._floor_edit.text)
	var hijo: Node = p._panel.get_child(0)
	p._toggle()
	await _frames(1)
	_ok(not p._panel.visible and not Game.debug_panel_open, "al cerrarlo se esconde")
	p._toggle()
	await _frames(1)
	_ok(p._panel.get_child_count() == 1 and p._panel.get_child(0) == hijo, "al reabrirlo NO se construye otra vez")
	p._toggle()
	print("[debug] RESULTADO: ", "FIN: TODO BIEN" if fallos == 0 else "FALLAN %d" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
