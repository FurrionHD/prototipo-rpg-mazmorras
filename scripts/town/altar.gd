extends Node2D

# Altar/Hogar: presionar F para actualizar estado + curar 100%

func _ready() -> void:
	add_to_group("interactable")


func interact_with_player() -> void:
	Game.actualizar_estado()
	Game.player_current_hp = -1  # se rellena a tope en el siguiente combate
	Game.player_current_mp = -1  # y el mana (descansar recupera magia)
	# Descansar en el altar REINICIA los cooldowns que viajan entre combates: un nuke
	# usado antes de subir a casa vuelve disponible tras descansar (no arrastra CD).
	Game.ability_cooldowns_persist.clear()
	print("[Altar] Estado actualizado, vida y mana curados al 100%, cooldowns reiniciados")
