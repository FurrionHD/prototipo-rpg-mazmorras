# PRUEBA DE LA SALA CON DOS JUGADORES: el JUGADOR (A o B). Lo lanza tools/prueba_sala_dos_jugadores.gd
# como proceso aparte:  -- cliente_sala <puerto> <contraseña> <identidad> <rol A|B>
# El guion cuelga de root porque entrar al pueblo libera esta escena. Escribe lo que ve con [A]/[B] y
# acaba con "[A] TODO BIEN" o "[A] n FALLOS"; el que lo lanza lo lee de su registro.
extends Node


func _ready() -> void:
	var r := Node.new()
	r.set_script(load("res://tools/prueba_sala_cliente_guion.gd"))
	r.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(r)
