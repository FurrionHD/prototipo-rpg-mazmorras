# ============================================================
#  stats_math.gd
#  FORMULAS del combate (estilo DanMachi). Convierten las habilidades
#  (0-999) + el nivel + las stats base en valores reales de combate.
#  Todos los COEFICIENTES estan aqui arriba para balancear facil.
#  (Mas adelante podemos moverlos a un Resource de configuracion.)
# ============================================================

extends RefCounted
class_name StatsMath

# --- Coeficientes ajustables ---------------------------------
# Cada habilidad aporta (su valor × coef). El coef CRECE con el nivel:
#   coef(nivel) = base + crecimiento × (nivel - 1)
# Numeros bajos a proposito: 999 de Fuerza NO debe dar 999 de daño.
const ATK_COEF_BASE := 0.02
const ATK_COEF_GROWTH := 0.006
const DEF_COEF_BASE := 0.02
const DEF_COEF_GROWTH := 0.006
const MAG_COEF_BASE := 0.02
const MAG_COEF_GROWTH := 0.006
const SPD_COEF_BASE := 0.02
const SPD_COEF_GROWTH := 0.006

# La Resistencia tambien da Vida (ademas de Defensa). Sutil a proposito.
const HP_FROM_RES := 0.15

# "Dureza" de la mitigacion: cuanto MENOR sea, MAS se nota la defensa.
#   daño = ataque × K / (K + defensa)
# Con K=30, una defensa de 6 ya reduce ~17% del daño.
const MITIGATION_K := 30.0
# ------------------------------------------------------------


# Calcula el coeficiente de una habilidad para un nivel dado.
static func _coef(base: float, growth: float, level: int) -> float:
	return base + growth * float(level - 1)


# stat efectiva = base + habilidad × coef(nivel)
static func attack_value(ab: Abilities, level: int, base_attack: float) -> float:
	return base_attack + ab.fuerza * _coef(ATK_COEF_BASE, ATK_COEF_GROWTH, level)

static func defense_value(ab: Abilities, level: int, base_defense: float) -> float:
	return base_defense + ab.resistencia * _coef(DEF_COEF_BASE, DEF_COEF_GROWTH, level)

static func magic_value(ab: Abilities, level: int, base_magic: float) -> float:
	return base_magic + ab.magia * _coef(MAG_COEF_BASE, MAG_COEF_GROWTH, level)

static func speed_value(ab: Abilities, level: int, base_speed: float) -> float:
	return base_speed + ab.agilidad * _coef(SPD_COEF_BASE, SPD_COEF_GROWTH, level)

# Vida maxima = base + Resistencia × HP_FROM_RES
static func max_hp_value(ab: Abilities, _level: int, base_hp: float) -> int:
	return int(round(base_hp + ab.resistencia * HP_FROM_RES))


# Daño = ataque mitigado por la defensa (rendimientos decrecientes, minimo 1).
#   daño = ataque × K / (K + defensa)
static func damage(attack: float, defense: float) -> int:
	return maxi(1, int(round(attack * MITIGATION_K / (MITIGATION_K + defense))))
