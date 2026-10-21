# PRUEBA de los trabajadores de PELEA por la sala: ver tools/prueba_town_trabajadores_guion.gd. El guion cuelga de root:
# entrar a la mazmorra libera esta escena.
extends Node

const PUERTO := 24599


func _ready() -> void:
	var r := Node.new()
	r.set_script(load("res://tools/prueba_town_trabajadores_guion.gd"))
	r.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(r)
