# HERRAMIENTA. No forma parte del juego.
#
#   godot --headless --path . res://tools/tabla_chupasimas.tscn
#
# EL CALIBRADO DE LA CHUPASIMAS Y SUS MUTANTES (16/11/2026, memoria chupasimas-mutante). Copia de tabla_aberracion.gd: un
# personaje SIN ENTRENAR con armadura completa de tier 2, y el golpe medio al 100 % (sin variacion ni critico).
#   1) LA BASE: HOY (R35 F35 D30 A25 M15, sin Voluntad) contra NUEVA (con su Voluntad, misma suma 155).
#   2) LOS MUTANTES: su golpe magico y su basico frente al basico de la base de HOY, vida y cuanto les entran tus hechizos.
#   3) EL RAYO de la Vidriada / Madre segun el mana que lleven bebido (dano_mult = RAYO_BASE + RAYO_POR_MANA x mana).
extends Node

const T := 0.5
const PISOS := [8, 10, 12]

# R/F/D/A/M/V PROPUESTA 16/11 (suma 155, la de la base).
const STATS := {
	"base (nueva)": [32, 34, 28, 23, 12, 26],   # (16/11, elegida)
	"Coagulo": [46, 34, 24, 15, 10, 26],
	"Vidriada": [24, 14, 20, 34, 40, 23],
	"Madre": [38, 22, 18, 18, 34, 25],
}
const RAYO_BASE := 0.5
const RAYO_POR_MANA := 0.12   # (16/11: "rayo mas fuerte"; antes 0,08)
const RAYO_TOPE := 2.0
const CLAVES := ["resistencia", "fuerza", "destreza", "agilidad", "magia", "voluntad"]
const ARMADURAS := ["tela", "cuero", "hierro", "placas"]
const SLOTS := ["casco", "pecho", "manos", "pantalones", "botas"]


func _ready() -> void:
	var ed: EnemyData = load("res://scenes/actors/enemy/chupasimas.tres")
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
	# EL RAYO, contra hierro en el piso 10, segun el mana bebido.
	Game.current_floor = 10
	var hierro10 := _referencia("hierro", 2)
	for k in CLAVES.size():
		ed.set(CLAVES[k], STATS["Vidriada"][k])
	var vid: Combatant = ed.crear_combatant(T, false)
	for k in CLAVES.size():
		ed.set(CLAVES[k], STATS["Madre"][k])
	var madre: Combatant = ed.crear_combatant(T, false)
	for k in guard:
		ed.set(k, guard[k])
	Game.current_floor = 10
	var hoy10: Combatant = ed.crear_combatant(T, false)
	var b10: float = _fisico(hoy10, hierro10)
	print("RAYO (piso 10, contra hierro; basico de la base de hoy = %.1f):" % b10)
	for mana in [0, 3, 6, 10, 15, 20]:
		var m: float = minf(RAYO_BASE + RAYO_POR_MANA * float(mana), RAYO_TOPE)
		print("    %2d de mana bebido: x%.2f -> Vidriada %.1f (x%.2f del basico) | Madre %.1f" % [mana, m,
			_magico(vid, hierro10) * m, _magico(vid, hierro10) * m / b10, _magico(madre, hierro10) * m])
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
