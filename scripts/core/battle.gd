# ============================================================
#  battle.gd
#  MOTOR de combate por turnos (etapa A: automatico, para validar la
#  matematica por consola). El orden de turnos es tipo "ATB": cada
#  combatiente acumula una barra a un ritmo = su VELOCIDAD; cuando la
#  barra llega al umbral, actua. Asi, si uno es el doble de rapido,
#  actua el doble de veces (puede atacar 2 veces antes que el otro).
# ============================================================

extends RefCounted
class_name Battle

const UMBRAL := 100.0  # cuanto hay que acumular para poder actuar (llegar al final de la "linea")

# Ventaja de quien inicia el combate: NO es un turno gratis, solo un empujon
# (medio camino) para que pegue primero. Asi un +2 de velocidad no dobla turno;
# el doble turno solo pasa si eres MUCHO mas rapido (casi el doble).
const INICIATIVA_VENTAJA := 50.0


# Simula la batalla entera y devuelve al ganador. Imprime el desarrollo.
# "iniciativa_de": combatiente que empieza con la barra llena (entro primero).
static func simulate(a: Combatant, b: Combatant, iniciativa_de: Combatant = null) -> Combatant:
	print("\n===== COMBATE: ", a.nombre, " vs ", b.nombre, " =====")
	_print_stats(a)
	_print_stats(b)

	# La iniciativa: quien inicio el combate empieza con la barra llena.
	var gauge := {a: 0.0, b: 0.0}
	if iniciativa_de != null and gauge.has(iniciativa_de):
		gauge[iniciativa_de] = INICIATIVA_VENTAJA
		print("-> ", iniciativa_de.nombre, " tiene la INICIATIVA (pega primero)")

	var seguridad := 0  # tope para evitar bucles infinitos
	while a.is_alive() and b.is_alive() and seguridad < 10000:
		seguridad += 1

		# Cada uno acumula segun su velocidad.
		gauge[a] += a.spd()
		gauge[b] += b.spd()

		# El que tenga la barra mas llena actua primero (y puede repetir si
		# le sobra para otro turno: ahi esta el "actuar 2 veces").
		var orden: Array = [a, b] if gauge[a] >= gauge[b] else [b, a]
		for quien in orden:
			var rival: Combatant = b if quien == a else a
			while gauge[quien] >= UMBRAL and a.is_alive() and b.is_alive():
				gauge[quien] -= UMBRAL
				_attack(quien, rival)

	var ganador: Combatant = a if a.is_alive() else b
	print("===== GANA: ", ganador.nombre, " =====\n")
	return ganador


static func _attack(attacker: Combatant, defender: Combatant) -> void:
	var dmg := StatsMath.damage(attacker.atk(), defender.def_value())
	defender.take_damage(dmg)
	print("  ", attacker.nombre, " ataca a ", defender.nombre, " -> ", dmg,
		" daño  (", defender.nombre, ": ", defender.current_hp, "/", defender.max_hp, " HP)")


static func _print_stats(c: Combatant) -> void:
	print("  ", c.nombre, " (Nv.", c.level, ")  HP:", c.max_hp,
		"  ATK:", roundi(c.atk()), "  DEF:", roundi(c.def_value()),
		"  SPD:", roundi(c.spd()), "  [", c.abilities.resumen(), "]")
