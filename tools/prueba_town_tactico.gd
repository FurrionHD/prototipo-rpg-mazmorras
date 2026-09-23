# PRUEBA DEL COMBATE EN EL MAPA CON DOS JUGADORES: este proceso es el HOST y lanza al jugador B
# (tools/prueba_town_tactico_b.tscn) como otro Godot sin ventana. Guion en prueba_town_tactico_guion.gd.
# El nombre lleva "town" para pasar la guarda _en_el_pueblo de Net.hostear. El guion cuelga de root:
# entrar en la arena libera esta escena.
#
#   godot --headless --path . res://tools/prueba_town_tactico.tscn
extends Node


func _ready() -> void:
	var r := Node.new()
	r.set_script(load("res://tools/prueba_town_tactico_guion.gd"))
	r.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(r)
