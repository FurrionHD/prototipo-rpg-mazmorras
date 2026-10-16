# PRUEBA: los avisos de red del hogar (Net.hogar_cambiado / reservas_cambiadas) repintan UNA vez por fotograma
# (optimizacion 1D, 16/10/2026; ver MenuScaffold.repintar_al_final).
#  1) Cinco avisos al mismo menu en un fotograma = un repintado, al final del fotograma; dos menus = uno cada uno.
#  2) repintar_pendientes() los hace YA (es la guarda de Net.hogar.abrir_taller) y no se repiten al final.
#  3) Con la boticaria de verdad abierta: tres avisos no la repintan en el acto, y al acabar el fotograma si.
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
	await _frames(1)
	# 1) El ayudante.
	var cuenta: Array = [0, 0]
	var a := Node.new()
	var b := Node.new()
	add_child(a)
	add_child(b)
	for k in 5:
		MenuScaffold.repintar_al_final(a, func(): cuenta[0] += 1)
	MenuScaffold.repintar_al_final(b, func(): cuenta[1] += 1)
	_ok(cuenta == [0, 0], "nada se repinta en el acto")
	await _frames(1)
	_ok(cuenta == [1, 1], "al final del fotograma: uno por menu (%s)" % str(cuenta))
	await _frames(1)
	_ok(cuenta == [1, 1], "y no se repite")

	# 2) La guarda: ya, y sin repetirse al final.
	MenuScaffold.repintar_al_final(a, func(): cuenta[0] += 1)
	MenuScaffold.repintar_pendientes()
	_ok(cuenta[0] == 2, "repintar_pendientes lo hace en el acto")
	await _frames(1)
	_ok(cuenta[0] == 2, "y al final del fotograma no vuelve a repintar")
	# Un menu que se ha ido no se repinta (ni peta).
	MenuScaffold.repintar_al_final(b, func(): cuenta[1] += 1)
	b.free()
	await _frames(1)
	_ok(cuenta[1] == 1, "un menu liberado no se repinta")

	# 3) La boticaria de verdad.
	var men = CraftMenu.new()
	add_child(men)
	await _frames(1)
	men.abrir()
	await _frames(1)
	var antes: Node = _primero(men._content)
	for k in 3:
		Net.hogar_cambiado.emit()
	_ok(_primero(men._content) == antes, "tres avisos: la ficha no se rehace en el acto")
	await _frames(1)
	var despues: Node = _primero(men._content)
	_ok(despues != null and despues != antes, "al acabar el fotograma se ha repintado")
	await _frames(1)
	_ok(_primero(men._content) == despues, "una sola vez")
	men._cerrar()
	await _frames(1)
	Net.hogar_cambiado.emit()
	await _frames(1)
	_ok(_primero(men._content) == despues, "cerrada, un aviso no la repinta")

	print("[repintado] RESULTADO: ", "FIN: TODO BIEN" if fallos == 0 else "FALLAN %d" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)


func _primero(n: Node) -> Node:
	for h in n.get_children():
		if not MenuScaffold.muriendo(h):
			return h
	return null
