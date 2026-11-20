extends "res://tools/unitarias/caso.gd"
# Cubre: res://scripts/actors/enemy/enemy_data.gd
# Cubre: res://scripts/core/stats_math.gd
# Cubre: res://scenes/actors/enemy/rey_slime.tres
# Cubre: res://scenes/actors/enemy/guardian_rango.tres
# ENEMIGOS CON NIVEL (reglas nuevas, StatsMath.nivel_enemigos; 19/11). El bakeo de nivel paso del simulador
# (_bakear_enemigo, solo a los que abrian la pelea) a EnemyData.crear_combatant, para que lo cojan TAMBIEN las crias,
# invocados y refuerzos de mitad de pelea. Aqui: que da lo MISMO que el bakeo viejo del simulador (copiado tal cual), que
# de serie no cambia nada, y que la costra de ambar sale ya de la vida bakeada (antes, de la de sin bakear).

const SLIME := "res://scenes/actors/enemy/slime.tres"
const TRENT := "res://scenes/actors/enemy/trent.tres"


# El de tools/simulador_peleas.gd hasta el 19/11, pero (20/11) con el FONDO PLANO: 700 en todas las habilidades en cada nivel.
func _bakeo_viejo(e: Combatant, _ed: EnemyData, _t: float, nivel: int, vel_factor: float) -> void:
	var vel0: float = e.base_speed
	var ab := Abilities.new()
	for clave in ["fuerza", "resistencia", "destreza", "agilidad", "magia", "voluntad"]:
		ab.set(clave, 700)
	for _n in nivel - 1:
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


# EL MULTIPLICADOR DEL MUTANTE, UNA SOLA VEZ (20/11): con las reglas nuevas el mutante sale IGUAL que calcular el bicho
# "como si fuera normal" pero con SUS habilidades de mutante (y sus niveles) y multiplicar AL FINAL: vida x2,6 (x3,6 la 2a
# mutacion), defensa x1,15 (x1,25) y defensa magica x su multiplicador de ataque. Su reparto (mas Resistencia, mas rapido...)
# SI cuenta: por eso respecto al slime normal no es justo x2,6.
func test_mutante_multiplica_una_vez_sus_stats() -> void:
	var ed: EnemyData = load(SLIME)
	var t := 0.6
	var piso := 9
	for caso in [[&"brotado", EnemyData.MUT_HP, EnemyData.MUT_DEFENSA_NUEVAS, EnemyData.MUT_ATAQUE],
			[&"brotado_punzante", EnemyData.MUT2_HP, EnemyData.MUT2_DEFENSA_NUEVAS, EnemyData.MUT2_ATAQUE]]:
		for nivel in [1, 2, 3]:
			var m: Combatant = _con(true, nivel, 0.0, func(): return ed.crear_combatant(t, true, false, caso[0], piso))
			# "como si fuera normal con sus nuevas stats": el bicho sin multiplicadores, con las habilidades del mutante
			var sin: Combatant = _con(true, 1, 0.0, func(): return ed.crear_combatant(t, false, false, &"", piso))
			sin.abilities = ed.crear_abilities(t, caso[0], piso)
			sin.mutacion = caso[0]
			_bakeo_viejo(sin, ed, t, nivel, 0.0)
			var r0: bool = StatsMath.reglas_nuevas
			StatsMath.reglas_nuevas = true
			cerca(m.max_hp, sin.max_hp * caso[1], 0.01, "%s nivel %d: vida = la suya x%.2f" % [caso[0], nivel, caso[1]])
			cerca(m.def_value(), sin.def_value() * caso[2], 0.01, "%s nivel %d: defensa = la suya x%.2f" % [caso[0], nivel, caso[2]])
			cerca(m.mdef_value(), sin.mdef_value() * caso[3], 0.01, "%s nivel %d: defensa magica = la suya x%.2f" % [caso[0], nivel, caso[3]])
			StatsMath.reglas_nuevas = r0
			cierto(m.current_hp == m.max_hp, "nace con la vida llena")


# EL FONDO PLANO (20/11): la proporcion vida mutante / vida normal es LA MISMA en el nivel 1, 2 y 3, tambien en un mutante
# con un reparto muy distinto del suyo (el chillon piña, Resistencia x2; antes x5,3 -> x11,6). Y lo mismo la defensa.
func test_mutante_misma_proporcion_en_cada_tier() -> void:
	for par in [["res://scenes/actors/enemy/chillon.tres", &"pina"], [SLIME, &"brotado"]]:
		var ed: EnemyData = load(par[0])
		var prop: Array = []
		for nivel in [1, 2, 3]:
			var nm: Array = _con(true, nivel, 0.0, func():
				return [ed.crear_combatant(0.5, false, false, &"", 10), ed.crear_combatant(0.5, true, false, par[1], 10)])
			var r0: bool = StatsMath.reglas_nuevas
			StatsMath.reglas_nuevas = true
			prop.append([nm[1].max_hp / nm[0].max_hp, nm[1].def_value() / nm[0].def_value()])
			StatsMath.reglas_nuevas = r0
		for i in [1, 2]:
			cerca(prop[i][0], prop[0][0], 0.001, "%s: vida x%.2f en el nivel %d como en el 1" % [par[1], prop[i][0], i + 1])
			cerca(prop[i][1], prop[0][1], 0.001, "%s: defensa en el nivel %d como en el 1" % [par[1], i + 1])


# Con las reglas de hoy el mutante no cambia: su vida sale como siempre (aditiva, con su reparto de habilidades).
func test_mutante_con_reglas_de_hoy_como_siempre() -> void:
	var ed: EnemyData = load(SLIME)
	var m: Combatant = _con(false, 1, 0.0, func(): return ed.crear_combatant(0.6, true, false, &"brotado", 9))
	var esperado: float = StatsMath.max_hp_value(ed.crear_abilities(0.6, &"brotado", 9), m.level,
		ed.base_hp * Game.enemy_floor_stat_factor(9) * EnemyData.MUT_HP)
	cerca(m.max_hp, esperado, 0.01, "vida del mutante con las de hoy, la de siempre")
	cerca(m.base_defense, ed.base_defense * Game.enemy_floor_stat_factor(9) * EnemyData.MUT_DEFENSA, 0.01,
		"defensa base x1,6 con las de hoy")


# LA VIDA DE LOS JEFES CON LAS REGLAS NUEVAS (19/11, base_hp_reglas_nuevas en su ficha): solo con el interruptor; con las
# de hoy, la de siempre (base_hp).
func test_vida_de_jefe_solo_con_reglas_nuevas() -> void:
	for ruta in ["res://scenes/actors/enemy/rey_slime.tres", "res://scenes/actors/enemy/guardian_rango.tres"]:
		var ed: EnemyData = load(ruta)
		cierto(ed.base_hp_reglas_nuevas > 0.0, "%s trae su vida para las reglas nuevas" % ruta.get_file())
		var hoy: Combatant = _con(false, 1, 0.0, func(): return ed.crear_combatant(0.5, false, true, &"", 6))
		cerca(hoy.base_hp, ed.base_hp * Game.enemy_floor_stat_factor(6), 0.01, "con las de hoy, base_hp de siempre")
		var nuevas: Combatant = _con(true, 1, 0.0, func(): return ed.crear_combatant(0.5, false, true, &"", 6))
		cerca(nuevas.base_hp, ed.base_hp_reglas_nuevas * Game.enemy_floor_stat_factor(6), 0.01, "con las nuevas, la suya")
