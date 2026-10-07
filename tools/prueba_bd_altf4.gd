# BD FASE 1: un ALT+F4 ya no se lleva la partida (el guardado continuo de Perfil).
# Son DOS procesos, en este orden:
#   ALTF4_FASE=1 godot --headless --path . res://tools/prueba_bd_altf4.tscn
#       partida nueva en la RANURA 97, al pueblo, cambia el dinero, espera a que pase el guardado
#       continuo y se MATA a si mismo (sin cerrar nada: como un alt+F4 o un cuelgue).
#   ALTF4_FASE=2 godot --headless --path . res://tools/prueba_bd_altf4.tscn
#       abre la ranura 97 y mira que el dinero cambiado esta. Despues la borra.
# Las ranuras de verdad no se tocan.
extends Node

const SLOT := 97
const DINERO := 424242
const PUEBLO := "res://scenes/levels/town.tscn"


func _ready() -> void:
	call_deferred("_correr")


func _correr() -> void:
	if OS.get_environment("ALTF4_FASE") == "2":
		_fase_2()
	else:
		_fase_1()


func _fase_1() -> void:
	Perfil.borrar(SLOT)
	Game.nueva_partida("Prueba altf4", {})
	Perfil.ranura_actual = SLOT
	Perfil.guardar(SLOT)
	var arbol := get_tree()
	# El pueblo se monta AL LADO y pasa a ser la escena actual: con change_scene esta prueba (que es
	# la escena) se borraria a media funcion y no llegaria a cambiar el dinero.
	var pueblo: Node = load(PUEBLO).instantiate()
	arbol.root.add_child(pueblo)
	arbol.current_scene = pueblo
	await arbol.create_timer(1.0).timeout
	Game.money = DINERO
	var rev: int = Perfil._bd.rev
	print("Dinero puesto a %d (rev %d); esperando al guardado continuo..." % [DINERO, rev])
	# Por reloj, no por fotogramas (sin ventana van muy deprisa): el guardado arranca cada 2 s.
	var limite: int = Time.get_ticks_msec() + 8000
	while Perfil._bd.rev == rev and Time.get_ticks_msec() < limite:
		await arbol.create_timer(0.25).timeout
	print("rev %d -> %d. Muerte a lo bruto." % [rev, Perfil._bd.rev])
	OS.kill(OS.get_process_id())


func _fase_2() -> void:
	var info: Dictionary = Perfil.inspeccionar(SLOT)
	var datos: SaveData = info.get("datos")
	var fallos: int = 0
	if datos == null:
		fallos += 1
		print("MAL: la ranura %d no se puede leer" % SLOT)
	elif datos.money != DINERO:
		fallos += 1
		print("MAL: el dinero es %d, el cambio se ha perdido con el alt+F4" % datos.money)
	else:
		print("El dinero cambiado sigue ahi: %d" % datos.money)
	Perfil.borrar(SLOT)
	print("FIN: %s" % ("TODO BIEN" if fallos == 0 else "%d MAL" % fallos))
	get_tree().quit(1 if fallos > 0 else 0)
