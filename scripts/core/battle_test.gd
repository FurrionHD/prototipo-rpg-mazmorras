# ============================================================
#  battle_test.gd  (TEMPORAL - solo para probar el motor de combate)
#  Crea un heroe y un slime y simula una batalla automatica en consola
#  al arrancar la escena. Sirve para validar las formulas DanMachi y el
#  orden de turnos ANTES de hacer la interfaz. Cambia los valores y vuelve
#  a darle a Play para experimentar con el balance.
# ============================================================

extends Node


func _ready() -> void:
	# --- HEROE (nivel 1) ---
	var heroe_ab := Abilities.new()
	heroe_ab.fuerza = 120
	heroe_ab.resistencia = 90
	heroe_ab.destreza = 60
	heroe_ab.agilidad = 110
	heroe_ab.magia = 20
	# Combatant(nombre, nivel, habilidades, base_hp, base_atk, base_def, base_spd)
	var heroe := Combatant.new("Heroe", 1, heroe_ab, 50, 5, 5, 5)

	# --- SLIME (nivel 1) ---
	var slime_ab := Abilities.new()
	slime_ab.fuerza = 80
	slime_ab.resistencia = 70
	slime_ab.destreza = 30
	slime_ab.agilidad = 60
	slime_ab.magia = 0
	var slime := Combatant.new("Slime", 1, slime_ab, 40, 4, 5, 4)

	# Lanzamos la batalla. El heroe tiene la iniciativa (empezo el combate).
	Battle.simulate(heroe, slime, heroe)
