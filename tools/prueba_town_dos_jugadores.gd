# PRUEBA DE DOS JUGADORES por la sala (ver tools/LEEME_red.md): este proceso es el jugador A. Lanza la
# sala de una ranura de prueba, entra en ella y lanza al jugador B (tools/prueba_town_dos_cliente.tscn) como otro
# Godot sin ventana, que entra por la misma sala. El guion cuelga de root: entrar al pueblo libera la escena.
#   godot --headless --path . res://tools/prueba_town_dos_jugadores.tscn -- nube_local
extends Node


func _ready() -> void:
	var r := Node.new()
	r.set_script(load("res://tools/prueba_town_dos_jugadores_guion.gd"))
	r.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(r)
