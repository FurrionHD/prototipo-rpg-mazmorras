# ============================================================
#  combatant.gd
#  Representa a UN combatiente dentro de una batalla (jugador o enemigo).
#  Junta: nombre, nivel, habilidades (Abilities) y stats base, y a partir
#  de ahi calcula sus valores reales (ataque, defensa, velocidad, vida).
#  No es un nodo: es un objeto ligero que usa el motor de combate.
# ============================================================

extends RefCounted
class_name Combatant

var nombre: String = ""
var level: int = 1
var abilities: Abilities = null

# Stats BASE del combatiente (lo que tiene "de serie", sin habilidades).
var base_hp: float = 0.0
var base_attack: float = 0.0
var base_defense: float = 0.0
var base_speed: float = 0.0

# Vida actual / maxima (se calculan al crear).
var max_hp: int = 0
var current_hp: int = 0


func _init(nombre_: String, level_: int, abilities_: Abilities,
		base_hp_: float, base_attack_: float, base_defense_: float, base_speed_: float) -> void:
	nombre = nombre_
	level = level_
	abilities = abilities_
	base_hp = base_hp_
	base_attack = base_attack_
	base_defense = base_defense_
	base_speed = base_speed_

	max_hp = StatsMath.max_hp_value(abilities, level, base_hp)
	current_hp = max_hp


# Valores reales de combate (calculados con las formulas de StatsMath).
func atk() -> float: return StatsMath.attack_value(abilities, level, base_attack)
func def_value() -> float: return StatsMath.defense_value(abilities, level, base_defense)
func spd() -> float: return StatsMath.speed_value(abilities, level, base_speed)

func is_alive() -> bool:
	return current_hp > 0

func take_damage(amount: int) -> void:
	current_hp = maxi(0, current_hp - amount)
