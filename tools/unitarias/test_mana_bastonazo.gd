extends "res://tools/unitarias/caso.gd"
# Cubre: res://scripts/core/game.gd
# Cubre: res://scripts/items/weapon_data.gd
# Cubre: res://scripts/items/wand_data.gd
# Cubre: res://scripts/items/ability_data.gd
# Cubre: res://resources/weapons/baston.tres
# Cubre: res://resources/wands/varita.tres
# Cubre: res://resources/abilities/bastonazo.tres
# EL MANA DEL MAGO AL PEGAR (23/11, el jefe; memoria rangos-magias-y-habilidades): el basico con BASTON devuelve el 4 %
# del mana maximo al acertar, con VARITA (pegas con el arma principal) 2/3 de eso, y la habilidad BASTONAZO el 8 % (la
# pagas con energia). En las FICHAS, y leido de la ficha BASE: un baston ya forjado (una copia guardada en la partida)
# coge el numero nuevo igual.


func test_las_fichas() -> void:
	cerca(float(load("res://resources/weapons/baston.tres").mana_golpe_pct), 0.04, 0.0001, "baston: 4 %")
	cerca(float(load("res://resources/wands/varita.tres").mana_golpe_pct), 0.0267, 0.0001, "varita: 2/3 del baston")
	cerca(float(load("res://resources/abilities/bastonazo.tres").mana_gain_pct), 0.08, 0.0001, "Bastonazo: 8 %")


func test_una_copia_vieja_lee_la_ficha_base() -> void:
	var item: Resource = Game.crear_item(load("res://resources/weapons/baston.tres"), 1, 0, {})
	item.mana_golpe_pct = 0.0   # como un baston forjado antes de que existiera el campo
	cerca(Game.mana_golpe_pct_de(item), 0.04, 0.0001, "la copia guardada coge el 4 % de la ficha")


func test_el_loadout_lo_suma() -> void:
	var p := PersonajeData.new()
	p.equipped_main = Game.crear_item(load("res://resources/weapons/baston.tres"), 1, 0, {})
	cerca(float(Game.loadout_mods(p)["mana_golpe_pct"]), 0.04, 0.0001, "con baston, 4 %")
	var c: Combatant = Game.crear_player_combatant(p)
	cerca(c.mana_golpe_pct, 0.04, 0.0001, "y lo lleva a la pelea")
	var q := PersonajeData.new()
	q.equipped_main = Game.crear_item(load("res://resources/weapons/daga.tres"), 1, 0, {})
	cerca(float(Game.loadout_mods(q)["mana_golpe_pct"]), 0.0, 0.0001, "con una daga sola, nada")
	q.equipped_off = load("res://resources/wands/varita.tres")
	cerca(float(Game.loadout_mods(q)["mana_golpe_pct"]), 0.0267, 0.0001, "daga + varita, los 2/3")
