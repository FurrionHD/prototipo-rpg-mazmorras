# HERRAMIENTA. No forma parte del juego.
#
#   godot --headless --path . res://tools/tabla_polilla.tscn
#
# EL CALIBRADO DE LA POLILLA Y SUS MUTANTES (12/11/2026, memoria polilla-mutante). Como tabla_ataques_magicos.gd (los
# slimes, 08/10): un personaje SIN ENTRENAR con armadura completa de su tier, y el golpe medio al 100 % (sin variacion
# ni critico; el dano_mult de cada habilidad lo escala igual).
#   1) LA BASE (pavon): HOY (Nube y Aleteo fisicos, sin Voluntad) contra NUEVO (stats nuevas, Nube y Aleteo MAGICOS).
#      El ajuste del dano_mult = fisico de hoy / magico nuevo contra HIERRO (lo que eligio el jefe con los slimes).
#   2) LOS MUTANTES (aun no existen en la ficha): sus stats sobre la misma ficha, y lo que pega su golpe magico y su
#      basico frente al basico de la base, para elegir sus dano_mult.
extends Node

const T := 0.5
const PISOS := [9, 11, 12]

# R/F/D/A/M/V aprobadas el 12/11.
const STATS := {
	"pavon (nuevo)": [22, 24, 30, 42, 28, 24],
	"Vigilia dorada": [20, 12, 18, 42, 50, 28],
	"Mortaja alada": [18, 12, 22, 44, 46, 28],
	"Polilla insomne": [16, 10, 16, 40, 46, 42],
}
const CLAVES := ["resistencia", "fuerza", "destreza", "agilidad", "magia", "voluntad"]
const ARMADURAS := ["tela", "cuero", "hierro", "placas"]
const SLOTS := ["casco", "pecho", "manos", "pantalones", "botas"]


func _ready() -> void:
	var ed: EnemyData = load("res://scenes/actors/enemy/polilla.tres")
	var guard: Dictionary = {}
	for k in CLAVES:
		guard[k] = ed.get(k)
	print("HOY: R%d F%d D%d A%d M%d V%d" % [ed.resistencia, ed.fuerza, ed.destreza, ed.agilidad, ed.magia, ed.voluntad])
	for ab in ed.habilidades:
		print("  %s: dano_mult %.2f, magico %s" % [ab.nombre, ab.dano_mult, ab.es_magico])
	var facs: Array = []
	for piso in PISOS:
		Game.current_floor = int(piso)
		var tier: int = 2
		var hoy: Combatant = ed.crear_combatant(T, false)
		var fila := "piso %d |" % piso
		var hierro := _referencia("hierro", tier)
		var por_forma: Dictionary = {}
		for nombre in STATS:
			for i in CLAVES.size():
				ed.set(CLAVES[i], STATS[nombre][i])
			por_forma[nombre] = ed.crear_combatant(T, false)
		for k in guard:
			ed.set(k, guard[k])
		var nuevo: Combatant = por_forma["pavon (nuevo)"]
		var fac: float = _fisico(hoy, hierro) / _magico(nuevo, hierro)
		facs.append(fac)
		fila += " ajuste Nube/Aleteo x%.2f | basico %+d%% |" % [fac,
			roundi((_fisico(nuevo, hierro) / _fisico(hoy, hierro) - 1.0) * 100.0)]
		for a in ARMADURAS:
			var r := _referencia(a, tier)
			fila += " %s %.1f->%.1f |" % [a, _fisico(hoy, r), _magico(nuevo, r) * fac]
		print(fila)
		# Los mutantes: su golpe magico y su basico, contra el basico de HOY (contra hierro).
		var base: float = _fisico(hoy, hierro)
		for nombre in STATS:
			if nombre == "pavon (nuevo)":
				continue
			var c: Combatant = por_forma[nombre]
			print("    %-16s magico x%.2f del basico de hoy, basico x%.2f | tus hechizos le entran %+d%% | vida %.0f" % [
				nombre, _magico(c, hierro) / base, _fisico(c, hierro) / base,
				roundi(((StatsMath.MITIGATION_K / (StatsMath.MITIGATION_K + c.mdef_value()))
					/ (StatsMath.MITIGATION_K / (StatsMath.MITIGATION_K + hoy.mdef_value())) - 1.0) * 100.0),
				c.max_hp])
	var f_med: float = 0.0
	for f in facs:
		f_med += float(f)
	f_med /= float(facs.size())
	for ab in ed.habilidades:
		print("AJUSTE %s dano_mult %.2f -> %.2f" % [ab.resource_path.get_file().get_basename(), ab.dano_mult,
			ab.dano_mult * f_med])
	get_tree().quit()


func _referencia(tipo: String, tier: int) -> Combatant:
	var c := Combatant.new("Ref", 1, Abilities.new(), 100.0, 5.0, 5.0, 5.0)
	c.stats_multiplicativas = true
	c.base_magic = 5.0
	var red: float = 0.0
	var red_m: float = 0.0
	for slot in SLOTS:
		var pieza: ArmorData = load("res://resources/armor/%s_%s.tres" % [tipo, slot])
		var pm: Dictionary = Upgrades.armor_piece_mods(pieza, Game.tier_mult(tier), 0, {}, tier)
		var cob: float = Game.cobertura_slot(slot)
		c.extra_defense += float(pm["def"])
		c.extra_magic_def += float(pm["mdef"])
		red += cob * float(pm["reduccion"])
		red_m += cob * float(pm["reduccion_magica"])
	c.armor_reduction = clampf(red, 0.0, StatsMath.ARMOR_REDUCTION_MAX)
	c.armor_reduction_magica = clampf(red_m, 0.0, StatsMath.ARMOR_REDUCTION_MAX)
	return c


func _fisico(e: Combatant, r: Combatant) -> float:
	return StatsMath.damage(e.atk(), r.def_value()) * (1.0 - r.armor_reduction)


func _magico(e: Combatant, r: Combatant) -> float:
	return StatsMath.damage(e.atk_magico(), r.mdef_value()) * (1.0 - r.armor_reduction_magica)
