# PRUEBA DEL COMBATE EN EL MAPA CON DOS JUGADORES, el JUGADOR B (lo lanza tools/prueba_town_tactico.gd).
# Entra en la sala de A como en un mundo compartido. El guion cuelga de root.
extends Node


func _ready() -> void:
	var r := Node.new()
	r.set_script(load("res://tools/prueba_town_tactico_b_guion.gd"))
	r.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(r)
