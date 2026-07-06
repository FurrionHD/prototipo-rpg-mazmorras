# ============================================================
#  upgrades.gd
#  RAREZAS + MEJORAS del equipo (armas y armaduras). Centraliza (como StatsMath)
#  los enums, tablas y la MATH de las mejoras. Es estatico: game.gd le pasa el
#  tier_mult ya calculado para no depender del autoload.
#
#  Modelo (cerrado con el usuario):
#   - RAREZA: (1) % pasivo sobre la base (comun x1.00 ... obra maestra x1.15) y
#     (2) nº de MEJORAS que admite el item (comun 3 ... obra maestra 12).
#   - Cada MEJORA sube el numero base (raw de arma / DEF de armadura) un +0.3 FIJO
#     (x tier), elijas la categoria que elijas. ENCIMA, la categoria da un extra
#     DECRECIENTE (dim_sum). En un arma, por tanto, CADA mejora sube el daño raw.
#   - Categorias DISTINTAS por tipo, con GATING por clase de armadura. Las que
#     dependen de sistemas que aun no existen quedan RESERVADAS (efecto 0):
#     Durabilidad (mantenimiento) y Resistencia a estados.
# ============================================================

extends RefCounted
class_name Upgrades

enum Rareza { COMUN, POCO_COMUN, RARO, EPICO, LEGENDARIO, MITICO, OBRA_MAESTRA }

# COMUN = 1.00 (regresion exacta: rareza comun + 0 mejoras = como antes).
const RAREZA_MULT := [1.00, 1.02, 1.04, 1.06, 1.09, 1.12, 1.15]
const RAREZA_SLOTS := [3, 4, 5, 6, 8, 10, 12]
const RAREZA_NOMBRE := ["Comun", "Poco comun", "Raro", "Epico", "Legendario", "Mitico", "Obra maestra"]

const UPGRADE_FLAT := 0.3   # +primary (raw/DEF) por CADA mejora (x tier)
const DECAY := 0.8          # rendimientos decrecientes de las categorias

# --- Claves de categoria (en el dict de mejoras {categoria: nº}) ---
# Armas:
const AGUDEZA := "agudeza"
const PRECISION := "precision"
const PESO := "peso"
const RAPIDEZ := "rapidez"
# Armas MAGICAS (baston/varita, KAN-95):
const POTENCIA := "potencia"            # +daño magico directo (magic_amp), como Agudeza
const EFICIENCIA := "eficiencia"        # -% coste de maná
const CELERIDAD := "celeridad"          # +velocidad de casteo
const REGENERACION := "regeneracion"    # +% sobre el regen de maná del arma
# Armaduras:
const DUREZA := "dureza"
const EVASION := "evasion"
const RESIST_CRIT := "resist_crit"
const RESISTENCIA := "resistencia"    # RESERVADA (estados alterados)
# Generica (arma y armadura):
const DURABILIDAD := "durabilidad"    # RESERVADA (mantenimiento)

# Nombres legibles para la UI.
const CAT_NOMBRE := {
	"agudeza": "Agudeza", "precision": "Precision", "peso": "Peso", "rapidez": "Rapidez",
	"potencia": "Potencia", "eficiencia": "Eficiencia", "celeridad": "Celeridad", "regeneracion": "Regeneracion",
	"dureza": "Dureza", "evasion": "Evasion", "resist_crit": "Resist. criticos",
	"resistencia": "Resistencia (reservada)", "durabilidad": "Durabilidad (reservada)",
}

# --- Steps de cada categoria (extra DECRECIENTE por punto) ---
const AGUDEZA_STEP := 0.15        # +raw (x tier)
const PRECISION_CRIT_STEP := 0.02 # +prob. critico
const PRECISION_HIT_STEP := 0.02  # +acierto (baja evasion rival)
const PESO_STEP := 0.03           # +aturdir/stun (solo contundentes)
const RAPIDEZ_STEP := 0.03        # +velocidad arma
const RAPIDEZ_CAP := 0.08         # tope del bonus de rapidez
const DUREZA_STEP := 0.15         # +DEF (x tier)
const EVASION_STEP := 0.02        # +esquiva (ligeras/medias)
const EVASION_CAP := 0.20         # tope del bonus de esquiva de armadura
const RESIST_CRIT_STEP := 0.02    # -crit rival (pesadas)
const RESIST_CRIT_CAP := 0.25     # tope de resistencia a criticos
# Armas MAGICAS (KAN-95). Todos PROVISIONALES -> Excel.
const MAGIC_AMP_FLAT := 0.02      # +magic_amp por CADA mejora (primario del arma magica)
const POTENCIA_STEP := 0.05       # +magic_amp de la categoria Potencia (extra, decreciente)
const POTENCIA_CAP := 0.25        # tope del bonus de Potencia
const EFICIENCIA_STEP := 0.05     # -% coste de maná (dim_sum asintota a 0.25 -> hay que invertir MUCHO)
const EFICIENCIA_CAP := 0.25
const CELERIDAD_STEP := 0.03      # +velocidad de casteo
const CELERIDAD_CAP := 0.10
const REGENERACION_STEP := 0.08   # +% sobre el regen de maná del arma
const REGENERACION_CAP := 0.40


static func rareza_mult(r: int) -> float:
	return RAREZA_MULT[clampi(r, 0, RAREZA_MULT.size() - 1)]

static func rareza_slots(r: int) -> int:
	return RAREZA_SLOTS[clampi(r, 0, RAREZA_SLOTS.size() - 1)]

static func rareza_nombre(r: int) -> String:
	return RAREZA_NOMBRE[clampi(r, 0, RAREZA_NOMBRE.size() - 1)]

static func cat_nombre(cat: String) -> String:
	return CAT_NOMBRE.get(cat, cat)

# Suma DECRECIENTE de k puntos: step·(1-decay^k)/(1-decay).
static func dim_sum(step: float, k: int) -> float:
	if k <= 0:
		return 0.0
	return step * (1.0 - pow(DECAY, float(k))) / (1.0 - DECAY)

static func _count(mejoras: Dictionary, cat: String) -> int:
	return int(mejoras.get(cat, 0))

static func total_mejoras(mejoras: Dictionary) -> int:
	var n := 0
	for k in mejoras:
		n += int(mejoras[k])
	return n


# Categorias VALIDAS de un arma (para el gating y la UI). Peso solo si contundente.
# Las armas MAGICAS (baston) usan las categorias magicas, NO las fisicas.
static func weapon_categories(w: WeaponData) -> Array:
	if w != null and w.es_magica:
		# El baston (arma magica que SI ataca): magicas + Agudeza (raw melee) +
		# Peso si es contundente (aturde con el golpe). La varita no ataca (ver wand).
		var mcats: Array = magic_categories()
		mcats.append(AGUDEZA)
		if int(w.dano_tipo) == 1:  # CONTUNDENTE
			mcats.append(PESO)
		mcats.append(DURABILIDAD)
		return mcats
	var cats: Array = [AGUDEZA, PRECISION]
	if w != null and int(w.dano_tipo) == 1:  # CONTUNDENTE
		cats.append(PESO)
	cats.append(RAPIDEZ)
	cats.append(DURABILIDAD)  # reservada
	return cats

# Categorias magicas base (potencia + gestion de maná). El baston añade encima
# Agudeza/Peso; la varita se queda solo con estas (no ataca).
static func magic_categories() -> Array:
	return [POTENCIA, EFICIENCIA, CELERIDAD, REGENERACION]

# Categorias VALIDAS de una varita (magicas + durabilidad reservada).
static func wand_categories() -> Array:
	return magic_categories() + [DURABILIDAD]

# Categorias VALIDAS de una pieza de armadura (GATING por clase):
#  ligera(CUERO=0)/media(HIERRO=1) -> Evasion; pesada(HIERRO_COMPLETO=2/PLACAS=3) -> ResistCrit.
static func armor_categories(a: ArmorData) -> Array:
	var cats: Array = [DUREZA]
	if a != null:
		if int(a.tipo) <= 1:
			cats.append(EVASION)
		else:
			cats.append(RESIST_CRIT)
	cats.append(RESISTENCIA)   # reservada
	cats.append(DURABILIDAD)   # reservada
	return cats


# Agregados de un ARMA (por mano). tmult = tier_mult(tier) ya calculado.
static func weapon_mods(w: WeaponData, tmult: float, rareza: int, mejoras: Dictionary) -> Dictionary:
	# Arma MAGICA (baston): la potencia magica va aparte (magic_mods). Aqui solo lo
	# FISICO del golpe: base × rareza + Agudeza (raw), y Peso (aturdir) si contundente.
	# El resto de mejoras magicas NO tocan el daño fisico.
	if w != null and w.es_magica:
		var raw_mag := (w.ataque_base * rareza_mult(rareza) + dim_sum(AGUDEZA_STEP, _count(mejoras, AGUDEZA))) * tmult
		var aturdir_mag := 0.0
		if int(w.dano_tipo) == 1:  # CONTUNDENTE
			aturdir_mag = dim_sum(PESO_STEP, _count(mejoras, PESO))
		return {"raw": raw_mag, "crit_add": 0.0, "precision": 0.0,
			"aturdir_add": aturdir_mag, "vel_mult": 1.0}
	var n := total_mejoras(mejoras)
	# +0.3 por CADA mejora (universal) + extra de Agudeza (decreciente). Todo x tier.
	var raw_up := UPGRADE_FLAT * float(n) + dim_sum(AGUDEZA_STEP, _count(mejoras, AGUDEZA))
	var raw := (w.ataque_base * rareza_mult(rareza) + raw_up) * tmult
	var kp := _count(mejoras, PRECISION)
	var aturdir := 0.0
	if int(w.dano_tipo) == 1:  # solo contundentes
		aturdir = dim_sum(PESO_STEP, _count(mejoras, PESO))
	var rapidez := minf(RAPIDEZ_CAP, dim_sum(RAPIDEZ_STEP, _count(mejoras, RAPIDEZ)))
	return {
		"raw": raw,
		"crit_add": dim_sum(PRECISION_CRIT_STEP, kp),
		"precision": dim_sum(PRECISION_HIT_STEP, kp),
		"aturdir_add": aturdir,
		"vel_mult": 1.0 + rapidez,
	}

# Agregados MAGICOS de un arma de mago (baston o varita), por slot. Las mejoras
# magicas NO usan tier (para no disparar el multiplicador): magic_amp sale de la
# base × rareza + un flat por mejora; el resto son porcentajes con tope.
#   base_amp = magic_amp base del item (baston 1.8 / varita 1.4).
static func magic_mods(base_amp: float, rareza: int, mejoras: Dictionary) -> Dictionary:
	var n := total_mejoras(mejoras)
	# magic_amp = base×rareza + flat universal por CADA mejora + extra de Potencia (decreciente, tope).
	var potencia := minf(POTENCIA_CAP, dim_sum(POTENCIA_STEP, _count(mejoras, POTENCIA)))
	return {
		"magic_amp": base_amp * rareza_mult(rareza) + MAGIC_AMP_FLAT * float(n) + potencia,
		"mana_reduccion": minf(EFICIENCIA_CAP, dim_sum(EFICIENCIA_STEP, _count(mejoras, EFICIENCIA))),
		"cast_vel_add": minf(CELERIDAD_CAP, dim_sum(CELERIDAD_STEP, _count(mejoras, CELERIDAD))),
		"regen_mult": 1.0 + minf(REGENERACION_CAP, dim_sum(REGENERACION_STEP, _count(mejoras, REGENERACION))),
	}


# Agregados de una PIEZA de armadura. tmult = tier_mult(tier). La reduccion y la
# velocidad de la pieza salen de la base (el tier/rareza/mejoras solo tocan DEF,
# evasion y resist. criticos). game.gd combina las 5 piezas por cobertura.
static func armor_piece_mods(a: ArmorData, tmult: float, rareza: int, mejoras: Dictionary) -> Dictionary:
	var n := total_mejoras(mejoras)
	var def_up := UPGRADE_FLAT * float(n) + dim_sum(DUREZA_STEP, _count(mejoras, DUREZA))
	var deff := (a.defensa_base * a.motion_def * rareza_mult(rareza) + def_up) * tmult
	var evasion := 0.0
	var crit_resist := 0.0
	if int(a.tipo) <= 1:
		evasion = dim_sum(EVASION_STEP, _count(mejoras, EVASION))
	else:
		crit_resist = dim_sum(RESIST_CRIT_STEP, _count(mejoras, RESIST_CRIT))
	return {
		"def": deff,
		"reduccion": a.reduccion,
		"vel_mult": a.velocidad_mult,
		"evasion": evasion,
		"crit_resist": crit_resist,
	}
