# ============================================================
#  status_effects.gd  (KAN-58)
#  Catalogo DATA-DRIVEN de estados alterados + la clase Instance (un estado
#  ACTIVO sobre un combatiente). El MOTOR vive en Combatant (apply/tick/agregadores);
#  aqui estan las DEFINICIONES (que hace cada estado) y sus magnitudes.
#
#  Un estado ACTIVO (Instance) lleva DATOS PROPIOS POR APLICACION:
#   - magnitude: daño por turno BASE (DoT, nivel 1). Lo calcula QUIEN lo aplica:
#       * Veneno  -> base FIJO; cada STACK DUPLICA el daño (dot = base x 2^(stacks-1)),
#                    asi subir de stack = "tier siguiente". Un solo veneno para todo;
#                    las habilidades/enemigos capan hasta que stack pueden subirlo (stack_cap).
#       * Sangrado-> ESCALA con el ATAQUE del aplicador (aplicador fuerte = sangra mas).
#         Lo aplican solo ciertas HABILIDADES con armas cortantes (KAN-57/Fase 3).
#       * Quemadura-> por ahora un valor por defecto (lo afinaran los hechizos).
#     Ambos bandos pueden usar cualquiera; la diferencia es la MECANICA, no quien lo usa.
#   - turns: duracion propia (distintos ataques/bichos pueden traer duraciones distintas).
#   - stack_mode: como apila el estado al re-aplicarse:
#       * "none"        -> una sola instancia; re-aplicar RESETEA duracion y sube al
#                          mas fuerte (magnitud=max). Ej: buffs/debuffs, Quemadura.
#       * "merge"       -> una sola instancia con CUENTA de stacks (MISMA duracion para
#                          todos); el efecto escala con los stacks: dot x2 por stack
#                          (Veneno, via dot_stack_mult) o -X%/stack (Pegajoso/Lento).
#       * "independent" -> cada aplicacion es un STACK con su PROPIA duracion (varias
#                          instancias); las heridas viejas expiran solas. Ej: Sangrado.
#                          Una habilidad puede pasar refresh_all=true para reiniciar la
#                          duracion de TODOS los stacks a la vez.
#
#  Otros efectos del catalogo: mult de atk/def/spd (buffs/debuffs), is_stun (pierde
#  turno) y stun_prob_mult (RAYO: x1.5 a la prob. de aturdir que recibe, estilo MH).
#
#  MAGNITUDES/DURACIONES = PROVISIONALES (afinar con Excel). Ver [[ajuste-curvas-holistico]].
# ============================================================

extends RefCounted
class_name StatusEffects

enum Id { VENENO, SANGRADO, QUEMADURA, LENTO, DEBIL, VULNERABLE, FORTALEZA, ATURDIDO, RAYO, PEGAJOSO }

# Veneno: base de daño (nivel 1) + tope global de stacks. Cada stack DUPLICA el daño
# (base x 2^(stacks-1)); las habilidades/enemigos capan a que stack llegan. PROVISIONAL.
const VENENO_BASE_DMG := 3.0
const VENENO_TURNS := 4
const VENENO_MAX_STACKS := 5

# Sangrado: APILABLE. Cada stack = fraccion BAJA del ATAQUE del aplicador (no 1:1);
# machacar con armas cortantes sube el daño total (dot = magnitud x stacks). PROVISIONAL.
const SANGRADO_FRACCION_ATK := 0.15
const SANGRADO_TURNS := 3
const SANGRADO_MAX_STACKS := 5

static func sangrado_magnitude(applier_atk: float) -> float:
	return applier_atk * SANGRADO_FRACCION_ATK

# Catalogo. Cada entrada trae solo los campos que usa (el resto = neutro por defecto,
# ver los get(...) del motor). 'turns' = duracion base por defecto; 'dot' = es DoT;
# 'dot_default' = magnitud por defecto si el aplicador no pasa una (util para dev).
static var _defs: Dictionary = {
	Id.VENENO: {
		"id": Id.VENENO, "nombre": "Veneno", "icono": "☠", "color": Color(0.45, 0.85, 0.2),
		"dot": true, "turns": VENENO_TURNS, "dot_default": VENENO_BASE_DMG,
		"stack_mode": "merge", "max_stacks": VENENO_MAX_STACKS, "dot_stack_mult": 2.0,
	},
	Id.SANGRADO: {
		"id": Id.SANGRADO, "nombre": "Sangrado", "icono": "🩸", "color": Color(0.85, 0.15, 0.15),
		"dot": true, "turns": SANGRADO_TURNS,   # magnitud/stack = escala con el aplicador
		"stack_mode": "independent", "max_stacks": SANGRADO_MAX_STACKS,
	},
	Id.QUEMADURA: {
		"id": Id.QUEMADURA, "nombre": "Quemadura", "icono": "🔥", "color": Color(1.0, 0.5, 0.1),
		"dot": true, "turns": 2, "dot_default": 6.0,   # lo afinaran los hechizos (Fase 3)
	},
	Id.LENTO: {   # Ralentizacion FIJA (hechizo/habilidad): NO apila, un -25% plano.
		"id": Id.LENTO, "nombre": "Lento", "icono": "🐌", "color": Color(0.3, 0.6, 0.9),
		"turns": 3, "spd_mult": 0.75,
	},
	Id.PEGAJOSO: {   # Slimes: hasta 4 stacks INDEPENDIENTES, -5% vel/stack (cada uno su duracion)
		"id": Id.PEGAJOSO, "nombre": "Pegajoso", "icono": "🕸", "color": Color(0.4, 0.8, 0.4),
		"stack_mode": "independent", "max_stacks": 4, "turns": 3,
		"spd_mult": 0.95,   # cada stack (instancia) multiplica x0.95 -> 4 stacks ~ -18.5%
	},
	Id.DEBIL: {   # debuff de ataque
		"id": Id.DEBIL, "nombre": "Debil", "icono": "💢", "color": Color(0.7, 0.4, 0.9),
		"turns": 3, "atk_mult": 0.80,
	},
	Id.VULNERABLE: {   # debuff de defensa (recibe mas daño)
		"id": Id.VULNERABLE, "nombre": "Vulnerable", "icono": "🔻", "color": Color(0.9, 0.3, 0.5),
		"turns": 3, "def_mult": 0.80,
	},
	Id.FORTALEZA: {   # buff de ataque
		"id": Id.FORTALEZA, "nombre": "Fortaleza", "icono": "💪", "color": Color(0.95, 0.8, 0.2),
		"turns": 3, "atk_mult": 1.25,
	},
	Id.ATURDIDO: {   # pierde el turno; lo aplica el aturdir CRITICO de contundentes (Fase 2)
		"id": Id.ATURDIDO, "nombre": "Aturdido", "icono": "💫", "color": Color(1.0, 0.9, 0.3),
		"turns": 1, "is_stun": true,
	},
	Id.RAYO: {   # debuff estilo MH: x1.5 a la prob. de aturdir que recibe
		"id": Id.RAYO, "nombre": "Rayo", "icono": "⚡", "color": Color(0.6, 0.8, 1.0),
		"turns": 3, "stun_prob_mult": 1.5,
	},
}


# Definicion (Dictionary) de un estado por su Id.
static func def(id: int) -> Dictionary:
	return _defs.get(id, {})


# Lista de todos los Ids del catalogo.
static func all_ids() -> Array:
	return _defs.keys()


# ------------------------------------------------------------
#  Instance: un estado ACTIVO sobre un combatiente (magnitud + turnos + stacks).
# ------------------------------------------------------------
class Instance extends RefCounted:
	var d: Dictionary          # definicion (referencia al catalogo)
	var turns: int = 0
	var stacks: int = 1
	var magnitude: float = 0.0  # daño por turno (DoT); la fija QUIEN lo aplica

	func _init(def_: Dictionary, turns_: int, stacks_: int = 1) -> void:
		d = def_
		turns = turns_
		stacks = stacks_

	func id() -> int:
		return int(d.get("id", -1))

	# Daño por turno de este estado (0 si no es DoT). Los stacks escalan el daño segun
	# dot_stack_mult: por defecto 1.0 (cada instancia = magnitud; Sangrado suma varias
	# instancias). Veneno usa 2.0 -> base x 2^(stacks-1) (cada stack "sube de tier").
	func dot_damage() -> float:
		var mult: float = float(d.get("dot_stack_mult", 1.0))
		return magnitude * pow(mult, float(maxi(stacks, 1) - 1))

	# Multiplicadores de stat (1.0 = neutro). Apilado LINEAL por stacks.
	func atk_mult() -> float: return _stat_mult("atk_mult")
	func def_mult() -> float: return _stat_mult("def_mult")
	func spd_mult() -> float: return _stat_mult("spd_mult")

	func _stat_mult(clave: String) -> float:
		var m: float = float(d.get(clave, 1.0))
		return 1.0 + (m - 1.0) * float(stacks)

	func is_stun() -> bool:
		return bool(d.get("is_stun", false))

	# Multiplicador de la prob. de aturdir que RECIBE el objetivo (RAYO). 1.0 = neutro.
	func stun_prob_mult() -> float:
		return float(d.get("stun_prob_mult", 1.0))

	# Texto corto para la UI. DoT: muestra el daño/turno REAL (ya escalado por stacks).
	# Ej "☠12·4t" (veneno x3), "☠x3(12)·4t", "🩸5·3t", "🐌x3·3t", "💫·1t".
	func etiqueta() -> String:
		var ic: String = str(d.get("icono", "?"))
		if magnitude > 0.0:   # DoT
			var dmg: int = roundi(dot_damage())
			if stacks > 1:
				return "%sx%d(%d)·%dt" % [ic, stacks, dmg, turns]
			return "%s%d·%dt" % [ic, dmg, turns]
		if stacks > 1:        # apilable sin DoT (Lento)
			return "%sx%d·%dt" % [ic, stacks, turns]
		return "%s·%dt" % [ic, turns]
