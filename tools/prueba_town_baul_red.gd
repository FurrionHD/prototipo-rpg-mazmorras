# Ver tools/prueba_town_baul_red_guion.gd. El guion cuelga de root: entrar al pueblo libera esta escena.
extends Node


func _ready() -> void:
	var r := Node.new()
	r.set_script(load("res://tools/prueba_town_baul_red_guion.gd"))
	r.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(r)
