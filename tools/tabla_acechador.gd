# HERRAMIENTA. No forma parte del juego.
#
#   godot --headless --path . res://tools/tabla_acechador.tscn
#
# EL CALIBRADO DEL ACECHADOR Y SUS MUTANTES (17/11/2026, memoria acechador-mutante). Copia de tabla_chupasimas.gd: un
# personaje SIN ENTRENAR con armadura completa de tier 2, y el golpe medio al 100 % (sin variacion ni critico).
#   1) LA BASE: HOY (R40 F58 D30 A45 M5, sin Voluntad) contra NUEVA (con su Voluntad, misma suma 178).
#   2) LOS MUTANTES: su golpe magico (la Media luna) y su basico frente al basico de la base de HOY.
extends Node

const T := 0.5
const PISOS := [10, 12]

# R/F/D/A/M/V PROPUESTA 17/11 (suma 178, la de la base).
const STATS := {
	"base (nueva)": [38, 56, 30, 44, 4, 6],
	"Sombra sin rostro": [30, 56, 36, 50, 2, 4],
	"Cazador lunar": [32, 42, 28, 40, 28, 8],
	"Cazador lunar B": [30, 34, 26, 38, 42, 8],
	"Cazador lunar C": [34, 48, 26, 36, 26, 8],
}
const CLAVES := ["resistencia", "fuerza", "destreza", "agilidad", "magia", "voluntad"]
const ARMADURAS := ["tela", "cuero", "hierro", "placas"]
const SLOTS := ["casco", "pecho", "manos", "pantalones", "botas"]


func _ready() -> void:
	var ed: EnemyData = load("res://scenes/actors/enemy/acechador.tres")
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
			# (17/11, el jefe: "no me estas diciendo su vida real") CON LOS MULTIPLICADORES DE MUTANTE: la Sombra es grado 1 y
			# el Cazador grado 2 (EnemyData.mult_mutante): la vida y el golpe de verdad.
			var g: int = 2 if nombre.begins_with("Cazador") else 1
			var mm: Dictionary = EnemyData.mult_mutante(false, g)
			# (19/11) LA VIDA COMO LA CUENTA EL JUEGO (EnemyData.crear_combatant): el multiplicador de mutante va solo sobre la
			# VIDA BASE del bicho y despues se suma lo de la Resistencia. Antes se multiplicaba la vida entera y salia inflada
			# (587 / 818 en vez de 490 / 656 en el piso 10).
			for i in CLAVES.size():
				ed.set(CLAVES[i], STATS[nombre][i])
			var bh: float = ed.base_hp
			ed.base_hp = bh * float(mm["hp"])
			var vida_real: float = ed.crear_combatant(T, false).max_hp
			ed.base_hp = bh
			for k in guard:
				ed.set(k, guard[k])
			print("    %-18s MUTANTE grado %d: vida %.0f (normal de hoy %.0f) | basico x%.2f y magico x%.2f del basico del normal de hoy" % [
				nombre, g, vida_real, hoy.max_hp, _fisico(c, hierro) / base * float(mm["atk"]),
				_magico(c, hierro) / base * float(mm["atk"])])
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
