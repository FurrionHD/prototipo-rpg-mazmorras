extends "res://tools/unitarias/caso.gd"
# Cubre: res://scripts/actors/enemy/enemy_data.gd
# Cubre: res://scripts/core/stats_math.gd
# ENEMIGOS CON NIVEL (reglas nuevas, StatsMath.nivel_enemigos; 19/11). El bakeo de nivel paso del simulador
# (_bakear_enemigo, solo a los que abrian la pelea) a EnemyData.crear_combatant, para que lo cojan TAMBIEN las crias,
# invocados y refuerzos de mitad de pelea. Aqui: que da lo MISMO que el bakeo viejo del simulador (copiado tal cual), que
# de serie no cambia nada, y que la costra de ambar sale ya de la vida bakeada (antes, de la de sin bakear).

const SLIME := "res://scenes/actors/enemy/slime.tres"
const TRENT := "res://scenes/actors/enemy/trent.tres"


# El de tools/simulador_peleas.gd hasta el 19/11, tal cual.
func _bakeo_viejo(e: Combatant, ed: EnemyData, t: float, nivel: int, vel_factor: float) -> void:
	var vel0: float = e.base_speed
	for _n in nivel - 1:
		var ab: Abilities = ed.crear_abilities(t, e.mutacion, 12)
		e.base_hp = StatsMath.max_hp_jugador(ab, e.base_hp) * 1.1
		e.base_attack = e.base_attack * StatsMath.fuerza_factor(float(ab.fuerza)) * 1.1
		e.base_defense = StatsMath.defense_jugador(ab, e.base_defense) * 1.1
		e.base_speed = StatsMath.speed_jugador(ab, e.base_speed) * 1.1
		e.base_magic = StatsMath.magic_jugador(ab, e.base_magic) * 1.1
	if vel_factor > 0.0:
		e.base_speed = vel0 * vel_factor
	e.max_hp = StatsMath.max_hp_jugador(e.abilities, e.base_hp)
	e.current_hp = e.max_hp


func _con(reglas: bool, nivel: int, vel: float, f: Callable):
	var r0: bool = StatsMath.reglas_nuevas
	var n0: int = StatsMath.nivel_enemigos
	var v0: float = StatsMath.vel_enemigos_factor
	StatsMath.reglas_nuevas = reglas
	StatsMath.nivel_enemigos = nivel
	StatsMath.vel_enemigos_factor = vel
	var out = f.call()
	StatsMath.reglas_nuevas = r0
	StatsMath.nivel_enemigos = n0
	StatsMath.vel_enemigos_factor = v0
	return out


func _stats(c: Combatant) -> Array:
	return [c.max_hp, c.base_attack, c.base_defense, c.base_speed, c.base_magic]


func test_da_lo_mismo_que_el_bakeo_del_simulador() -> void:
	var ed: EnemyData = load(SLIME)
	for caso in [[0.2, 2, 0.0, 6], [0.8, 2, 1.7, 12], [0.5, 3, 0.0, 1], [0.9, 3, 2.3, 9]]:
		var t: float = caso[0]
		var nivel: int = caso[1]
		var vel: float = caso[2]
		var piso: int = caso[3]
		var viejo: Array = _con(true, 1, 0.0, func():
			var c: Combatant = ed.crear_combatant(t, false, false, &"", piso)
			_bakeo_viejo(c, ed, t, nivel, vel)
			return _stats(c))
		var nuevo: Array = _con(true, nivel, vel, func(): return _stats(ed.crear_combatant(t, false, false, &"", piso)))
		for i in viejo.size():
			cerca(nuevo[i], viejo[i], 0.001, "stat %d del slime t=%.1f nivel %d piso %d" % [i, t, nivel, piso])


func test_de_serie_no_cambia_nada() -> void:
	var ed: EnemyData = load(SLIME)
	var apagado: Array = _con(false, 3, 2.0, func(): return _stats(ed.crear_combatant(0.5, false, false, &"", 6)))
	var nivel1: Array = _con(false, 1, 0.0, func(): return _stats(ed.crear_combatant(0.5, false, false, &"", 6)))
	igual(apagado, nivel1, "con las reglas de hoy el nivel no toca nada")
	var nuevas1: Array = _con(true, 1, 0.0, func(): return _stats(ed.crear_combatant(0.5, false, false, &"", 6)))
	var nuevas3: Array = _con(true, 3, 0.0, func(): return _stats(ed.crear_combatant(0.5, false, false, &"", 6)))
	cierto(nuevas3[0] > nuevas1[0] * 2.0, "con nivel 3 el slime tiene bastante mas vida (%.0f vs %.0f)" % [nuevas3[0], nuevas1[0]])


func test_la_costra_sale_de_la_vida_bakeada() -> void:
	var ed: EnemyData = load(TRENT)
	var c: Combatant = _con(true, 2, 0.0, func(): return ed.crear_combatant(0.5, true, false, &"ambarino", 6))
	cierto(c.costra_max > 0.0, "el ambarino trae costra")
	cerca(c.costra_max, c.max_hp * 0.2, 0.01, "costra = 20 % de su vida YA bakeada")
