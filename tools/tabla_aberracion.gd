# HERRAMIENTA. No forma parte del juego.
#
#   godot --headless --path . res://tools/tabla_aberracion.tscn
#
# EL CALIBRADO DE LA ABERRACION Y SUS MUTANTES (13/11/2026, memoria aberracion-mutante). Copia de tabla_polilla.gd: un
# personaje SIN ENTRENAR con armadura completa de tier 2, y el golpe medio al 100 % (sin variacion ni critico).
#   1) LA BASE: HOY (R40 F55 D25 A25 M25, sin Voluntad: usa la Magia) contra NUEVA (con su Voluntad, total 170). Su kit no
#      cambia de fisico/magico: solo cuanto se mueve su basico.
#   2) LOS MUTANTES (aun no existen en la ficha): sus stats sobre la misma ficha, y lo que pega su golpe magico y su
#      basico frente al basico de la base de HOY, para elegir sus dano_mult. Y cuanto les entran tus hechizos.
extends Node

const T := 0.5
const PISOS := [8, 10, 12]

# R/F/D/A/M/V aprobadas el 13/11 ("mitad y mitad").
const STATS := {
	"base (nueva)": [38, 50, 22, 24, 18, 18],
	"Masa galvanica": [36, 36, 16, 22, 32, 28],
	"Ojo de la tormenta": [28, 10, 12, 26, 50, 44],
}
const CLAVES := ["resistencia", "fuerza", "destreza", "agilidad", "magia", "voluntad"]
const ARMADURAS := ["tela", "cuero", "hierro", "placas"]
const SLOTS := ["casco", "pecho", "manos", "pantalones", "botas"]


func _ready() -> void:
	var ed: EnemyData = load("res://scenes/actors/enemy/aberracion.tres")
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
		var nuevo: Combatant = por_forma["base (nueva)"]
		var fac: float = _fisico(hoy, hierro) / _magico(nuevo, hierro)
		facs.append(fac)
		fila += " si su kit fuera magico x%.2f | basico %+d%% |" % [fac,
			roundi((_fisico(nuevo, hierro) / _fisico(hoy, hierro) - 1.0) * 100.0)]
		for a in ARMADURAS:
			var r := _referencia(a, tier)
			fila += " %s %.1f->%.1f |" % [a, _fisico(hoy, r), _magico(nuevo, r) * fac]
		print(fila)
		# Los mutantes: su golpe magico y su basico, contra el basico de HOY (contra hierro).
		var base: float = _fisico(hoy, hierro)
		for nombre in STATS:
			if nombre == "base (nueva)":
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
		print("SI PASARA A MAGICO %s dano_mult %.2f -> %.2f" % [ab.resource_path.get_file().get_basename(), ab.dano_mult,
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
