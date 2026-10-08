# HERRAMIENTA. No forma parte del juego.
#
#   godot --headless --path . res://tools/tabla_ataques_magicos.tscn
#
# (HORNEADA el 08/10/2026: pesos y % ya estan en las fichas, asi que HOY ya sale lo nuevo y el ajuste ~x1.)
# LA TABLA DE ANTES Y DESPUES de la fase 3 (08/10/2026): cuanto pega cada slime (y cada mutacion) por piso contra un
# personaje SIN ENTRENAR (Resistencia y Voluntad a 0) con armadura completa de TELA, CUERO y PLACAS del tier del piso.
#   HOY   = sus habilidades magicas como eran (fisicas: su Fuerza contra tu defensa fisica).
#   NUEVO = con los pesos de PROPUESTA (solo en memoria; las fichas no se tocan) y por magia contra tu defensa magica.
# Numeros = el golpe medio al 100 % (sin variacion ni critico): el dano_mult de cada habilidad los escala igual.
# Ademas: el BASICO (fisico) antes y despues, por si se le quita Fuerza, y lo que les entran TUS hechizos (Voluntad).
extends Node

const T := 0.5   # en medio de su franja

# [ficha, mutacion, pisos]
const FORMAS := [
	["slime_fuego", &"", [2, 4, 6]], ["slime_fuego", &"ceniza", [2, 4, 6]], ["slime_fuego", &"obsidiana", [4, 6]],
	["slime_veneno", &"miasma", [1, 3, 6]], ["slime_veneno", &"pestilente", [3, 6]],
	["slime_profundo", &"escarcha", [7, 9]],
	["slime_abisal", &"", [5, 6]], ["slime_abisal", &"cielo", [5, 6]], ["slime_abisal", &"ojos", [6]],
	["rey_slime", &"", [6]],
]

# LA PROPUESTA: pesos por forma (solo las claves que cambian). La Magia sale de la Fuerza (dentro de la suma).
const PROPUESTA := {
	"slime_fuego": {"fuerza": 20, "magia": 35, "voluntad": 15},
	"slime_fuego/ceniza": {"fuerza": 30, "magia": 25, "voluntad": 15},
	"slime_fuego/obsidiana": {"fuerza": 45, "magia": 10, "voluntad": 10},
	"slime_veneno/miasma": {"fuerza": 35, "magia": 20, "voluntad": 15},
	"slime_veneno/pestilente": {"fuerza": 30, "magia": 25, "voluntad": 15},
	"slime_profundo/escarcha": {"fuerza": 22, "magia": 38, "voluntad": 18},
	"slime_abisal": {"fuerza": 35, "magia": 25, "voluntad": 30},
	"slime_abisal/cielo": {"fuerza": 15, "magia": 45, "voluntad": 30},
	"slime_abisal/ojos": {"fuerza": 10, "magia": 50, "voluntad": 35},
	"rey_slime": {"voluntad": 30},
}

const ARMADURAS := ["tela", "cuero", "hierro", "hierro_completo", "placas"]
const SLOTS := {"casco": "casco", "pecho": "pecho", "manos": "manos", "pantalones": "pantalones", "botas": "botas"}


func _ready() -> void:
	for f in FORMAS:
		_forma(String(f[0]), f[1], f[2])
	get_tree().quit()


# Un personaje sin entrenar con la armadura completa de 'tipo' del 'tier'.
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


func _forma(ficha: String, mut: StringName, pisos: Array) -> void:
	var ed: EnemyData = load("res://scenes/actors/enemy/%s.tres" % ficha)
	var clave: String = ficha if mut == &"" else "%s/%s" % [ficha, mut]
	var m: MutacionData = ed.mutacion_de(mut)
	var es_jefe: bool = ficha == "rey_slime"
	var hoy_p: Dictionary = ed.pesos_de(mut)
	var nuevos: Dictionary = PROPUESTA.get(clave, {})
	print("")
	print("### %s%s" % [ed.enemy_name, (" -> " + m.nombre) if m != null else ""])
	print("pesos F/R/D/A/M + Vol: HOY %s  ->  NUEVO %s" % [_pesos_txt(hoy_p), _pesos_txt(_mezcla(hoy_p, nuevos))])
	var facs: Array = []
	var facs_burbuja: Array = []
	for piso in pisos:
		Game.current_floor = int(piso)
		var tier: int = 1 if int(piso) <= 6 else 2
		var e_hoy: Combatant = ed.crear_combatant(T, m != null, es_jefe, mut)
		var guard: Dictionary = {}
		if m != null:
			guard = m.pesos.duplicate()
			m.pesos = nuevos.duplicate()
		else:
			for k in nuevos:
				guard[k] = ed.get(k)
				ed.set(k, nuevos[k])
		var e_new: Combatant = ed.crear_combatant(T, m != null, es_jefe, mut)
		if m != null:
			m.pesos = guard
		else:
			for k in guard:
				ed.set(k, guard[k])
		# EL AJUSTE (lo eligio el usuario): contra HIERRO, el centro de la escalera, el golpe magico pega como hoy.
		var hierro := _referencia("hierro", tier)
		var fac: float = _fisico(e_hoy, hierro) / _magico(e_new, hierro)
		var fac_burbuja: float = e_hoy.atk() / _magico(e_new, hierro)   # hoy la burbuja no se mitigaba
		facs.append(fac)
		facs_burbuja.append(fac_burbuja)
		var fila := "piso %d (T%d) F%d M%d->F%d M%d V%d->V%d | x%.2f |" % [piso, tier, e_hoy.abilities.fuerza,
			e_hoy.abilities.magia, e_new.abilities.fuerza, e_new.abilities.magia, e_hoy.abilities.voluntad,
			e_new.abilities.voluntad, fac]
		for a in ARMADURAS:
			var r := _referencia(a, tier)
			var antes: float = _fisico(e_hoy, r)
			var luego: float = _magico(e_new, r) * fac
			fila += " %s %.1f->%.1f (%+d%%) |" % [a, antes, luego, roundi((luego / antes - 1.0) * 100.0)]
		fila += " basico %+d%%" % roundi((_fisico(e_new, hierro) / _fisico(e_hoy, hierro) - 1.0) * 100.0)
		# Tus hechizos contra el: K/(K+su defensa magica), nuevo contra hoy.
		var k: float = StatsMath.MITIGATION_K
		var hech: float = (k / (k + e_new.mdef_value())) / (k / (k + e_hoy.mdef_value()))
		fila += " | tus hechizos %+d%%" % roundi((hech - 1.0) * 100.0)
		print(fila)
	# El nuevo % de cada habilidad magica de esta forma: la media de sus pisos.
	var f_med: float = _media(facs)
	var habs: Array = m.habilidades if m != null and not m.habilidades.is_empty() else ed.habilidades
	for ab in habs:
		if ab == null or not ab.es_magico:
			continue
		var id: String = ab.resource_path.get_file().get_basename()
		if ab.burbuja_dano > 0.0 and ab.burbujas_max > 0:
			print("  AJUSTE %s burbuja_dano %.2f -> %.2f" % [id, ab.burbuja_dano, ab.burbuja_dano * _media(facs_burbuja)])
		if ab.dano_mult > 0.0:
			print("  AJUSTE %s dano_mult %.2f -> %.2f" % [id, ab.dano_mult, ab.dano_mult * f_med])


func _media(a: Array) -> float:
	var s: float = 0.0
	for x in a:
		s += float(x)
	return s / maxf(1.0, float(a.size()))


func _mezcla(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	for k in b:
		out[k] = b[k]
	return out


func _pesos_txt(p: Dictionary) -> String:
	return "%d/%d/%d/%d/%d V%d" % [p["fuerza"], p["resistencia"], p["destreza"], p["agilidad"], p["magia"],
		p["voluntad"]]
