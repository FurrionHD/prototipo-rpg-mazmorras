extends Node2D

# Altar/Hogar: presionar F para actualizar estado + curar 100%

func _ready() -> void:
	add_to_group("interactable")


func interact_with_player() -> void:
	Game.actualizar_estado()
	Game.player_current_hp = -1  # se rellena a tope en el siguiente combate
	print("[Altar] Estado actualizado y vida curada al 100%")
