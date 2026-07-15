extends Node2D

# Altar: presionar F abre el MENU del altar (altar_menu.gd): consolidar estado (con antes→después),
# curar, reiniciar cooldowns y, si procede, SUBIR DE NIVEL.

func _ready() -> void:
	add_to_group("interactable")


func interact_with_player() -> void:
	var menu: Node = get_tree().get_first_node_in_group("altar_menu")
	if menu != null and menu.has_method("abrir"):
		menu.abrir()
	else:
		# Reserva: si por lo que sea no hay menu, comportamiento antiguo (consolidar + curar).
		Game.actualizar_estado()
		Game.player_current_hp = -1
		Game.player_current_mp = -1
		Game.ability_cooldowns_persist.clear()
