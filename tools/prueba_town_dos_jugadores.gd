# PRUEBA DE DOS JUGADORES con trabajadores de pelea (ver tools/LEEME_red.md): este proceso es el HOST y lanza
# al jugador B (tools/prueba_town_dos_cliente.tscn) como otro Godot sin ventana. El nombre lleva "town" para
# pasar la guarda _en_el_pueblo de Net.hostear. El guion cuelga de root: entrar a la mazmorra libera la escena.
extends Node


func _ready() -> void:
	var r := Node.new()
	r.set_script(load("res://tools/prueba_town_dos_jugadores_guion.gd"))
	r.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(r)
