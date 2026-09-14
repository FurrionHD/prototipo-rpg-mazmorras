# ENEMIGO FALSO para la huella: lo minimo que Game.start_combat lee de un enemigo del mapa (su ficha,
# su tirada, sus heridas y estados), sin mazmorra ni IA. Para montar peleas por el camino de Game.
extends Node

var data: EnemyData = null
var current_t: float = 0.5
var hp_restante: float = -1.0
var estados_restantes: Array = []
var es_boss: bool = false
var mutante: bool = false
