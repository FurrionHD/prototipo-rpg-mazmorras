# HERRAMIENTA. No forma parte del juego.
#
#   godot --headless --path . res://tools/tabla_imbuiciones.tscn
#
# FASE 4 (08/10/2026): cuanto cambia la PORCION IMBUIDA (Filos, unturas, mantos de arma) contra cada enemigo.
# Antes = un % del golpe YA mitigado por su defensa fisica; ahora = un % del golpe crudo contra su defensa MAGICA.
# El cociente no depende de tu ataque: (K + DEF) / (K + DEF magica), por la reduccion de armadura si la tiene.
extends Node

const PISOS := [3, 6, 9, 12]

func _ready() -> void:
	var dir := DirAccess.open("res://scenes/actors/enemy")
	var fichas: Array = []
	for f in dir.get_files():
		if f.ends_with(".tres"):
			var r = load("res://scenes/actors/enemy/" + f)
			if r is EnemyData:
				fichas.append(r)
	var k: float = StatsMath.MITIGATION_K
	for ed in fichas:
		var fila := "%-22s" % ed.enemy_name
		for p in PISOS:
			Game.current_floor = p
			var c: Combatant = ed.crear_combatant(0.5)
			var viejo: float = k / (k + c.def_value()) * (1.0 - c.armor_reduction)
			var nuevo: float = k / (k + c.mdef_value()) * (1.0 - c.armor_reduction_magica)
			fila += " | p%d DEF %5.1f MDEF %5.1f %+4d%%" % [p, c.def_value(), c.mdef_value(),
				roundi((nuevo / viejo - 1.0) * 100.0)]
		print(fila)
	get_tree().quit()
