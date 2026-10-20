# PRUEBA DEL COMBATE EN EL MAPA CON DOS JUGADORES: este proceso es el jugador A; abre la sala de una ranura de prueba,
# entra y lanza al jugador B (tools/prueba_town_tactico_b.tscn) como otro Godot sin ventana, por la misma sala. Guion en
# prueba_town_tactico_guion.gd. El guion cuelga de root: entrar al pueblo libera esta escena.
#
#   godot --headless --path . res://tools/prueba_town_tactico.tscn -- nube_local
extends Node


func _ready() -> void:
	var r := Node.new()
	r.set_script(load("res://tools/prueba_town_tactico_guion.gd"))
	r.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(r)
