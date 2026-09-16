# HERRAMIENTA DE BALANCE: la personalidad de los tres escudos, en numeros. No forma parte del juego.
#
#   godot --headless --path . res://tools/dev_escudos.tscn
#
# Va como ESCENA y no con --script: Upgrades y las plantillas dependen del autoload Game, y --script
# arranca sin autoloads (la misma trampa que dev_encargos_rework.gd).
#
# Los tres escudos eran el MISMO escudo con otros numeros. Esto comprueba las tres cosas que ahora
# los separan, y las comprueba MIDIENDO lo que se ve, no leyendo el campo de al lado:
#   1) la ficha completa que sale de Upgrades.shield_mods (lo que lee el juego, no el .tres crudo);
#   2) el REPARTO REAL de golpes en un grupo de 4, sorteado 20.000 veces con la misma cuenta de
#      pesos que usa el combate -- porque "aggro_base = 3.2" no dice cuantos golpes te comes;
#   3) que cada tamaño trae habilidades que los otros no traen.
extends Node

const ESCUDOS := [
	"res://resources/shields/escudo_pequeno.tres",
	"res://resources/shields/escudo_normal.tres",
	"res://resources/shields/escudo_grande.tres",
]
const TIRADAS := 20000
const PROVOCA_PESO := 4.0   # el mismo de combat.gd


func _ready() -> void:
	print("\n=== FICHA DE CADA ESCUDO (T1 comun, sin mejoras) — lo que lee el combate ===")
	var mods: Array = []
	for r in ESCUDOS:
		var sh: ShieldData = load(r)
		var m: Dictionary = Upgrades.shield_mods(sh, Game.tier_mult(1), 0, {})
		mods.append(m)
		print("\n%s" % sh.nombre)
		print("  def al bloquear   %.2f" % float(m["def"]))
		print("  bloqueo           %.0f%%  (con el 0.30 de base: %.0f%%)" % [
			float(m["bloqueo"]) * 100.0, (0.30 + float(m["bloqueo"])) * 100.0])
		print("  velocidad         x%.2f" % float(m["vel_mult"]))
		print("  penal. esquiva    -%.1f%%" % (float(m["evasion_penal"]) * 100.0))
		print("  ATRAE GOLPES      x%.2f" % (Combatant.AGGRO_ESCUDO * float(m["aggro_mult"])))
		if float(m["contra_prob"]) > 0.0:
			print("  RIPOSTE bloqueo   %.0f%% de las veces, al %.0f%% de daño" % [
				float(m["contra_prob"]) * 100.0, float(m["contra_mult"]) * 100.0])
		else:
			print("  RIPOSTE bloqueo   no")

	print("\n\n=== REPARTO REAL DE GOLPES (grupo de 4: escudero + 3 sin escudo) ===")
	print("Sorteado %d veces con la cuenta de pesos del combate. El numero que importa no es el" % TIRADAS)
	print("aggro, es QUE PORCENTAJE DE LOS GOLPES te acabas comiendo.\n")
	print("  escudo        quieto    provocando")
	for i in ESCUDOS.size():
		var sh: ShieldData = load(ESCUDOS[i])
		var ag: float = Combatant.AGGRO_ESCUDO * float(mods[i]["aggro_mult"])
		print("  %-12s  %5.1f%%    %5.1f%%" % [
			sh.nombre.replace("Escudo ", ""), _cuota(ag) * 100.0, _cuota(ag * PROVOCA_PESO) * 100.0])
	print("\n  sin escudo    %5.1f%%       —" % (_cuota(1.0) * 100.0))

	print("\n\n=== HABILIDADES QUE TRAE CADA UNO ===")
	var por_escudo: Array = []
	for r in ESCUDOS:
		var sh: ShieldData = load(r)
		var nombres: Array = []
		for ab in sh.habilidades:
			if ab != null:
				nombres.append(ab.nombre)
		por_escudo.append(nombres)
		print("  %-16s %s" % [sh.nombre, ", ".join(nombres)])
	# Lo COMUN y lo PROPIO: si algun tamaño no tiene nada propio, sigue siendo un escalon.
	var comun: Array = por_escudo[0].duplicate()
	for lista in por_escudo:
		var q: Array = []
		for n in comun:
			if lista.has(n):
				q.append(n)
		comun = q
	print("\n  comun a los tres: %s" % ", ".join(comun))
	var mal: int = 0
	for i in ESCUDOS.size():
		var propias: Array = []
		for n in por_escudo[i]:
			if not comun.has(n):
				propias.append(n)
		var sh: ShieldData = load(ESCUDOS[i])
		print("  propias de %-14s %s" % [sh.nombre.replace("Escudo ", "") + ":",
			", ".join(propias) if not propias.is_empty() else "NINGUNA  <-- sigue siendo un escalon"])
		if propias.is_empty():
			mal += 1
	print("\nFIN, %d escudos sin personalidad propia" % mal)
	get_tree().quit(mal)


# Que fraccion de los golpes se come uno de peso 'w' en un grupo con otros tres de peso 1.
# Se SORTEA con la misma cuenta que _elegir_objetivo_enemigo en vez de despejar w/(w+3), que es lo
# que haria falta comprobar si algun dia el sorteo deja de ser proporcional al peso.
func _cuota(w: float) -> float:
	var pesos := [w, 1.0, 1.0, 1.0]
	var total: float = 0.0
	for p in pesos:
		total += p
	var mios: int = 0
	for _t in TIRADAS:
		var r: float = randf() * total
		for i in pesos.size():
			r -= pesos[i]
			if r < 0.0:
				if i == 0:
					mios += 1
				break
	return float(mios) / float(TIRADAS)
