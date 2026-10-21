# PRUEBA DE LOS PISOS DE LA SALA: el JUGADOR. Lo lanza tools/prueba_sala_pisos.gd como proceso aparte:
#   -- cliente_pisos <puerto> <contraseña> <identidad> <registro de la sala>
# El guion cuelga de root porque entrar al pueblo libera esta escena.
extends Node


func _ready() -> void:
	var r := Node.new()
	r.set_script(load("res://tools/prueba_sala_pisos_guion.gd"))
	r.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(r)
