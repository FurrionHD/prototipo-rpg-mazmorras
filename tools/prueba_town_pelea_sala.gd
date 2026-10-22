# PRUEBA de una pelea en la sala: ver tools/prueba_town_pelea_sala_guion.gd. El guion cuelga de root: entrar a la
# mazmorra libera esta escena.
extends Node


func _ready() -> void:
	var r := Node.new()
	r.set_script(load("res://tools/prueba_town_pelea_sala_guion.gd"))
	r.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(r)
