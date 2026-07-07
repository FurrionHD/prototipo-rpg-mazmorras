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
# ATAQUE (nuevo modelo, estilo MH): la Fuerza NO se SUMA, MULTIPLICA el raw
# (base + arma). factor_fuerza = 1 + Fuerza / FUERZA_DIV. Asi crecer en Fuerza
# se nota de verdad y ademas escala con el arma. FUERZA_DIV = cada cuanta Fuerza
# equivale a +100% de daño (250 -> a 250 de Fuerza pegas el DOBLE; a 999, ×5).
# Se aplica IGUAL a jugador y enemigos (usan la misma Combatant.atk()).
const FUERZA_DIV := 250.0

# MAGIA: igual que la Fuerza, la Magia MULTIPLICA el raw del hechizo (dano_base).
# magia_factor = 1 + Magia / MAGIA_DIV. A 250 de Magia un hechizo pega el DOBLE.
const MAGIA_DIV := 250.0

# MANA: maximo = BASE_MP + Magia × MP_FROM_MAGIA. Numeros PROVISIONALES -> Excel.
const BASE_MP := 20.0
const MP_FROM_MAGIA := 0.033   # magia 999 -> +33 (max = 20 + 33 = 53)
# Regen de mana POR TURNO de combate. Escala con la Magia (magos mas potentes
# reponen algo mas rapido), pero conservador para NO permitir spamear. El anti-spam
# real llegara con los NIVELES de hechizo (mismo hechizo, version cara). PROVISIONAL.
const MP_REGEN_BASE := 0.1
const MP_REGEN_PER_MAGIA := 0.0002   # magia 999 -> ~0.3/turno

# Resto de stats: siguen el modelo "base + habilidad × coef" (coef crece con el
# nivel). Numeros bajos a proposito: 999 no debe dar 999 de golpe.
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

# Variacion aleatoria del daño por golpe (estilo Terraria): cada golpe hace
# ±este % alrededor del valor base, para que no se sienta robotico.
const DAMAGE_VARIANCE := 0.12   # ±12%
# ------------------------------------------------------------


# Calcula el coeficiente de una habilidad para un nivel dado.
static func _coef(base: float, growth: float, level: int) -> float:
	return base + growth * float(level - 1)


# ATAQUE: la Fuerza MULTIPLICA el raw (base + arma). Este es solo el factor;
# la multiplicacion por (base + arma) y por el motion_value se hace en Combatant.atk().
static func fuerza_factor(fuerza: float) -> float:
	return 1.0 + fuerza / FUERZA_DIV

# MAGIA: multiplica el dano_base del hechizo (paralelo a fuerza_factor). El
# magic_amp del arma (bastones/varitas, KAN-95) se aplica aparte en resolve_spell.
static func magia_factor(magia: float) -> float:
	return 1.0 + magia / MAGIA_DIV

# Mana maximo segun la Magia (+ una base). FLOAT: asi las subidas pequeñas de Magia
# (y otras mejoras) se NOTAN en el maximo (se muestra con decimales).
static func max_mp_value(ab: Abilities, _level: int, base_mp: float = BASE_MP) -> float:
	return base_mp + ab.magia * MP_FROM_MAGIA

# Mana que se regenera por turno de combate (escala con la Magia).
static func mp_regen(magia: float) -> float:
	return MP_REGEN_BASE + magia * MP_REGEN_PER_MAGIA

# stat efectiva = base + habilidad × coef(nivel)
static func defense_value(ab: Abilities, level: int, base_defense: float) -> float:
	return base_defense + ab.resistencia * _coef(DEF_COEF_BASE, DEF_COEF_GROWTH, level)

static func magic_value(ab: Abilities, level: int, base_magic: float) -> float:
	return base_magic + ab.magia * _coef(MAG_COEF_BASE, MAG_COEF_GROWTH, level)

static func speed_value(ab: Abilities, level: int, base_speed: float) -> float:
	return base_speed + ab.agilidad * _coef(SPD_COEF_BASE, SPD_COEF_GROWTH, level)

# Vida maxima = base + Resistencia × HP_FROM_RES. FLOAT (se muestra con decimales,
# para que las subidas pequeñas de Resistencia se noten en el maximo).
static func max_hp_value(ab: Abilities, _level: int, base_hp: float) -> float:
	return base_hp + ab.resistencia * HP_FROM_RES


# Daño = ataque mitigado por la defensa (rendimientos decrecientes).
#   daño = ataque × K / (K + defensa)
# Devuelve FLOAT (con decimales) para NO perder precision: asi mejoras pequeñas
# (4.31 -> 4.65) se notan en vez de redondearse ambas a "4". Minimo 0.1.
static func damage(attack: float, defense: float) -> float:
	return maxf(0.1, attack * MITIGATION_K / (MITIGATION_K + defense))


# ============================================================
#  CRITICOS Y EVASION (KAN-52 / KAN-53)
#  Se calculan como un CONTEST entre dos habilidades, o sea un RATIO:
#     frac  = propia / (propia + rival)             -> 0.5 en igualdad
#     chance = parity + (frac - 0.5) × 2 × spread   (capado suelo/techo)
#  Al ser un ratio (adimensional) se AUTO-EQUILIBRA al subir de nivel: contra
#  enemigos igual de escalados la probabilidad no cambia; solo sacas ventaja
#  contra los que se quedan atras. Por eso NO necesita coeficiente por nivel.
#  Reparto de stats: Destreza = precision (crit), Agilidad = esquiva.
#
#  SUELO (CONTEST_BASE): frac = propia/(propia+rival) se SATURA cuando una stat
#  es ~0 (0 vs 14 se trata igual que 0 vs 999). Sumamos una base a AMBAS stats:
#     frac = (propia+BASE) / (propia+BASE + rival+BASE)
#  Asi al principio (stats bajas) todo queda cerca de la paridad (mas margen), y
#  al subir de nivel (stats de cientos) la base es despreciable -> contest real.
# ------------------------------------------------------------
const CONTEST_BASE := 40.0  # suelo comun a ambas stats (suaviza el arranque)

const CRIT_PARITY := 0.10   # prob. de critico con Destreza = Agilidad rival
const CRIT_SPREAD := 0.35   # cuanto sube/baja por ventaja de habilidad
const CRIT_MIN := 0.02
const CRIT_MAX := 0.40      # tope: un enemigo bestial nunca te critea mas de esto
const CRIT_MULT := 1.5      # multiplicador de daño critico (fijo por ahora; TODO KAN-52: escalar con Destreza)

const EVADE_PARITY := 0.05
const EVADE_SPREAD := 0.30
const EVADE_MIN := 0.03     # siempre queda algo de esquiva (nunca casi 0)
const EVADE_MAX := 0.35     # tope: nunca te esquivan mas de esto (peleable)

# Defender: el daño recibido se multiplica por (1 - defend_block) del defensor,
# donde defend_block viene del loadout (base 0.3 + escudo/arma secundaria).
# Capamos la reduccion entre estos limites (nunca 0 daño, nunca casi todo).
const DEFEND_TAKEN_MIN := 0.2   # como maximo bloquea el 80%
const DEFEND_TAKEN_MAX := 0.9   # como minimo bloquea el 10%

# Armadura: reduccion PORCENTUAL SIEMPRE activa (aparte de la DEF plana, que va por
# la mitigacion K/(K+DEF)). Se aplica a TODO golpe recibido, criticos incluidos.
# Tope para que ni con set pesado de tier alto te vuelvas invulnerable (la DEF
# plana NO tiene techo; el % SI). Ver Game.armor_mods() (media ponderada por slot).
const ARMOR_REDUCTION_MAX := 0.20

# Aturdir/retrasar con armas CONTUNDENTES (KAN-58 adelanto): la probabilidad =
# aturdir_base × factor_relativo(media(Fuerza,Destreza) del atacante vs Fuerza
# del defensor). Capada. Enemigo facil -> aturdes mas; fuerte -> casi nada.
const ATURDIR_MAX := 0.6

# HUIR (KAN-55): probabilidad de escapar = CONTEST de Agilidad propia vs la del
# rival (mismo modelo que esquiva/crit). 50% en igualdad; la ventaja de Agilidad
# sube/baja hasta los topes. Al ser un ratio se auto-equilibra al escalar de nivel.
const FLEE_PARITY := 0.5
const FLEE_SPREAD := 0.45
const FLEE_MIN := 0.10
const FLEE_MAX := 0.95
# ------------------------------------------------------------


static func _contest(own: float, rival: float, parity: float, spread: float,
		lo: float, hi: float) -> float:
	# Base comun a ambas stats: evita la saturacion cuando una es ~0 y da margen
	# al arranque (se vuelve despreciable con stats altas -> contest real).
	var o := own + CONTEST_BASE
	var r := rival + CONTEST_BASE
	var frac := o / (o + r)
	return clampf(parity + (frac - 0.5) * 2.0 * spread, lo, hi)

# Factor RELATIVO 0..2: 1.0 en igualdad, >1 si superas al rival, <1 si te supera.
# Sirve para escalar efectos por dificultad (p.ej. el aturdir). Mismo suelo.
static func _ratio_factor(own: float, rival: float) -> float:
	var o := own + CONTEST_BASE
	var r := rival + CONTEST_BASE
	return clampf((o / (o + r)) / 0.5, 0.0, 2.0)

# Prob. de que el ATACANTE haga critico: su Destreza vs Agilidad del defensor.
static func crit_chance(attacker_destreza: float, defender_agilidad: float) -> float:
	return _contest(attacker_destreza, defender_agilidad,
		CRIT_PARITY, CRIT_SPREAD, CRIT_MIN, CRIT_MAX)

# Prob. de que el DEFENSOR esquive: su Agilidad vs Destreza del atacante.
static func evade_chance(defender_agilidad: float, attacker_destreza: float) -> float:
	return _contest(defender_agilidad, attacker_destreza,
		EVADE_PARITY, EVADE_SPREAD, EVADE_MIN, EVADE_MAX)


# Prob. de HUIR (KAN-55): tu Agilidad vs la Agilidad del enemigo.
static func flee_chance(own_agilidad: float, rival_agilidad: float) -> float:
	return _contest(own_agilidad, rival_agilidad,
		FLEE_PARITY, FLEE_SPREAD, FLEE_MIN, FLEE_MAX)


# Resuelve un ataque completo: esquiva -> critico -> mitigacion/defensa -> aturdir.
# defending: true si el DEFENSOR eligio Defender este turno (mitiga y anula crit).
# Usa los mods del loadout guardados en el Combatant (crit_bonus, evasion_penal,
# defend_block, dano_tipo, aturdir_base). motion_value ya va dentro de atacante.atk().
# Devuelve { "damage": float, "evaded": bool, "crit": bool, "aturde": bool,
#            "evade_p": float, "crit_p": float, "aturde_p": float } (las _p para logs).
static func resolve_attack(attacker: Combatant, defender: Combatant,
		defending: bool = false) -> Dictionary:
	var atk_dex := float(attacker.abilities.destreza)
	var def_agi := float(defender.abilities.agilidad)

	# Probabilidades (se calculan SIEMPRE, para poder loguearlas aunque no apliquen).
	# ACIERTO del atacante (mejora Precision) baja la evasion del defensor. La esquiva
	# de armadura del defensor ya entra via su evasion_penal (negativo = bonus).
	var evade_p := clampf(evade_chance(def_agi, atk_dex) - defender.evasion_penal - attacker.precision, 0.0, EVADE_MAX)
	# RESIST. CRITICOS del defensor (armadura pesada) baja el crit del atacante.
	var crit_p := 0.0 if defending else clampf(crit_chance(atk_dex, def_agi) + attacker.crit_bonus - defender.crit_resist, 0.0, 1.0)
	# El aturdir depende de aturdir_base (ya viene promediado del loadout: en dual,
	# una maza en la secundaria aporta aunque la principal sea de corte). El debuff de
	# RAYO del defensor (KAN-58) MULTIPLICA esa probabilidad (x1.5, estilo MH), antes del cap.
	var aturde_p := 0.0
	if attacker.aturdir_base > 0.0:
		var stat := (float(attacker.abilities.fuerza) + float(attacker.abilities.destreza)) * 0.5
		aturde_p = clampf(attacker.aturdir_base * _ratio_factor(stat, float(defender.abilities.fuerza))
			* defender.stun_taken_mult(), 0.0, ATURDIR_MAX)

	# 1) Esquiva: base − penalizacion de esquiva del defensor (escudo estorba).
	if randf() < evade_p:
		return {"damage": 0.0, "evaded": true, "crit": false, "aturde": false,
			"evade_p": evade_p, "crit_p": crit_p, "aturde_p": aturde_p}

	# 2) Daño base (raw×motion_value en atk()) mitigado por la defensa. FLOAT.
	var dmg := damage(attacker.atk(), defender.def_value())
	# Variacion aleatoria por golpe (±DAMAGE_VARIANCE), estilo Terraria.
	dmg *= randf_range(1.0 - DAMAGE_VARIANCE, 1.0 + DAMAGE_VARIANCE)

	# 3) Critico (Defender lo ANULA).
	var is_crit := false
	if crit_p > 0.0 and randf() < crit_p:
		is_crit = true
		dmg *= CRIT_MULT

	# 3.5) Armadura: reduccion porcentual SIEMPRE activa (afecta tambien al critico).
	dmg *= (1.0 - clampf(defender.armor_reduction, 0.0, ARMOR_REDUCTION_MAX))

	# 4) Defensa activa: reduce el daño segun el bloqueo del loadout del defensor.
	if defending:
		dmg *= clampf(1.0 - defender.defend_block, DEFEND_TAKEN_MIN, DEFEND_TAKEN_MAX)

	# 5) Aturdir/retrasar (solo armas CONTUNDENTES).
	var aturde := aturde_p > 0.0 and randf() < aturde_p

	return {"damage": maxf(0.1, dmg), "evaded": false, "crit": is_crit, "aturde": aturde,
		"evade_p": evade_p, "crit_p": crit_p, "aturde_p": aturde_p}


# ============================================================
#  MAGIA (KAN-56): hechizos por encantamientos
#  El "acierto" del hechizo NO es RNG: depende de recitar bien las frases (test
#  en combat.gd). Aqui solo va el DAÑO. Sin esquiva ni critico en magia v1.
# ------------------------------------------------------------
# Fraccion del dano_base que te haces a TI MISMO al fallar una frase (backfire),
# escalada por lo avanzado que ibas. PROVISIONAL -> Excel.
const BACKFIRE_FRAC := 0.5


# Daño de un hechizo: dano_base × magia_factor(Magia) × magic_amp (arma), mitigado
# por la "defensa magica" del objetivo (su Magia via magic_value). ±variacion.
static func resolve_spell(attacker: Combatant, defender: Combatant, spell: SpellData) -> Dictionary:
	var magic_atk := spell.dano_base * magia_factor(float(attacker.abilities.magia)) * attacker.magic_amp
	var magic_def := magic_value(defender.abilities, defender.level, 0.0)
	var dmg := damage(magic_atk, magic_def)
	dmg *= randf_range(1.0 - DAMAGE_VARIANCE, 1.0 + DAMAGE_VARIANCE)
	return {"damage": maxf(0.1, dmg)}


# Backfire: daño que te haces al fallar una frase. Escala con dano_base (hechizos
# largos duelen mas) y con el PROGRESO (cuantas frases llevabas: casi terminar y
# fallar duele mas). Ignora defensa (es un descontrol interno).
static func backfire_damage(spell: SpellData, cast_index: int, n_frases: int) -> float:
	var progreso := float(cast_index + 1) / float(maxi(1, n_frases))
	return maxf(1.0, spell.dano_base * BACKFIRE_FRAC * progreso)
