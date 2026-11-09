# LOS FLORECIDOS DESDE COMO LO VE EL JUGADOR (09/11, memoria miconido-mutante, punto 1). En el juego siempre se juega
# contra la sala (Mundos._lanzar_sala), asi que lo que ve el jugador es SIEMPRE un espejo; prueba_mut_miconido solo mira
# el lado de quien lleva la pelea. Este proceso es el jugador: abre su sala, entra como cliente y mira SU pantalla.
# Guion en prueba_mut_miconido_espejo_guion.gd (cuelga de root: entrar al pueblo libera esta escena).
#
#   godot --headless --path . res://tools/prueba_mut_miconido_espejo.tscn -- nube_local
extends Node


func _ready() -> void:
	var r := Node.new()
	r.set_script(load("res://tools/prueba_mut_miconido_espejo_guion.gd"))
	r.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(r)
