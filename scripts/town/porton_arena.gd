# ============================================================
#  porton_arena.gd  (el porton NORTE del pueblo, ver PuebloPlano.PORTON_ARENA)
#  Lleva a la ARENA DE PRUEBAS: una sala grande con el spawner de enemigos y de materiales, compartida en
#  multi (la lleva un trabajador). Nada de lo que pase alli sale de alli (ver Game.entrar_en_arena).
# ============================================================
extends Node2D


func _ready() -> void:
	add_to_group("interactable")


func texto_interaccion() -> String:
	return "Entrar en la arena de pruebas"


func interact_with_player() -> void:
	Game.entrar_arena_de_pruebas()
