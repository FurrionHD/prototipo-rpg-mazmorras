# PRUEBA de los trabajadores de piso: host + trabajadores reales en headless (ver tools/LEEME_red.md). El nombre lleva "town" para pasar la
# guarda _en_el_pueblo de Net.hostear. El guion cuelga de root: entrar a la mazmorra libera esta escena.
extends Node

const PUERTO := 24599


func _ready() -> void:
	var r := Node.new()
	r.set_script(load("res://tools/prueba_town_trabajadores_guion.gd"))
	r.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(r)
