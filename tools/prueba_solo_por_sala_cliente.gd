# PRUEBA DE UN SOLO HUMANO POR LA SALA: el JUGADOR. Lo lanza tools/prueba_solo_por_sala.gd como proceso aparte:
#   -- cliente_solo <puerto> <contraseña> <identidad>
# El guion cuelga de root porque entrar al pueblo libera esta escena.
extends Node


func _ready() -> void:
	var r := Node.new()
	r.set_script(load("res://tools/prueba_solo_por_sala_guion.gd"))
	r.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(r)
