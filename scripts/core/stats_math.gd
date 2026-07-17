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

# MAGIA: la Magia MULTIPLICA el raw del hechizo (dano_base), pero con RENDIMIENTOS DECRECIENTES:
# sube rapido al principio y se aplana. Antes era lineal (1 + Magia/250), o sea ×5.0 a Magia 999,
# y a stat maxeada el mago se disparaba (mataba jefes en 3 hechizos con Magia ~900). Ahora el techo
# es ×MAGIA_FACTOR_MAX (×3.5 a 999) y el maxeo se aplana SIN tocar el mid-game: a Magia 250 sigue
# pegando el DOBLE (×2.0), el punto de referencia de siempre. La Fuerza sigue lineal a proposito:
# el guerrero mete su progresion en el arma (tier), el mago la reparte entre la stat y el arma.
const MAGIA_CAP := 999.0         # tope de la stat (como el resto)
const MAGIA_FACTOR_MAX := 3.5    # factor de daño a Magia = cap
# Exponente de la curva (<1 = decreciente). Calibrado para que a Magia 250 el factor sea 2.0:
# ln((2.0-1)/(3.5-1)) / ln(250/999) = 0.661. Si tocas MAGIA_FACTOR_MAX, recalcula este para
# mantener el ancla del ×2 a 250 (o mueve el ancla a proposito).
const MAGIA_FACTOR_EXP := 0.661

# Multiplicador GLOBAL del daño de todos los hechizos (rebalance de magia: los hechizos pegaban
# muy poco, "una decima parte de la vida" y encima con dos turnos de casteo). Centralizado en
# resolve_spell para no tocar cada .tres; el backfire NO lo usa (escala con dano_base directo).
# PROVISIONAL: ×2 se noto excesivo en pruebas -> ×1.5. Revisar en pisos altos (ajuste-curvas-holistico).
const SPELL_DAMAGE_MULT := 1.5

# MANA: maximo = BASE_MP + Magia × MP_FROM_MAGIA. Numeros PROVISIONALES -> Excel.
const BASE_MP := 20.0
const MP_FROM_MAGIA := 0.033   # magia 999 -> +33 (max = 20 + 33 = 53)
# REGEN DE MANÁ: ya NO hay goteo por "estar ahi" (ni por turno de combate ni parado en el
# mapa: eso era esperar, no jugar). El maná se recupera JUGANDO — pegando y matando — y el
# goteo por turno lo pone SOLO el ARMA MAGICA (Combatant.mp_regen_turno): sin baston ni varita
# no regeneras por turno, punto.
#
# TODO ESTO VA EN NUMEROS PLANOS, NO EN % DEL MAXIMO, y el motivo es el que ordena el sistema:
# un hechizo cuesta un numero FIJO (Brasa 6, Tormenta 14). Lo que compite contra un coste fijo
# tiene que medirse contra el, no contra tu deposito. Un 4% del maximo por golpe parecia mas
# "elegante", pero crecia con la Magia mientras los hechizos seguian costando 6: con Magia 0 un
# golpe pagaba el 13% de una Brasa y con Magia 900 el 33%, o sea que el maná se aflojaba solo
# segun subias de nivel hasta dejar de importar. En plano, un golpe paga siempre lo mismo.
#
# MP_BASE es el pellizco "de pelear", sin arma magica de por medio. Se usa en DOS sitios: lo que
# devuelve un golpe que acierta, y la base de lo que suelta un enemigo al morir (ver mp_por_kill).
const MP_BASE := 0.2
# MANÁ POR ENEMIGO MATADO: mult(n) × (MP_BASE + el regen por turno de tu arma magica), por CADA
# bicho. Antes era un 25% del maximo POR COMBATE, y ahi habia dos problemas: el sabor mentia
# (matar a 4 daba lo mismo que matar a 1, cuando lo que se disuelve en ti es el NUCLEO de cada
# bicho) y sobre todo salias LLENO de cualquier pelea, asi que el maná no limitaba nada.
#
# El multiplicador POR BICHO baja cuanto mas grande es el corro: 1 bicho ×2.0, 2 ×1.75, 3 ×1.5,
# 4 (o mas) ×1.25. Asi el corro sigue dando mas maná EN TOTAL (premia la magia de area), pero un
# duelo 1v1 no te deja tirado: si gastaste un hechizo por un solo enemigo, ese nucleo te cunde el
# doble y no malgastas el maná del casteo. Se bajo de la tanda original (3.0/2.5/2.0/1.5) porque
# con la extraccion no es raro pillar un baston epico/legendario pronto, y su regen alto multiplica
# esto: con la curva vieja un baston asi salia LLENO de casi cualquier pelea.
const MP_KILL_MULT_BASE := 2.25  # el mult por bicho es MP_KILL_MULT_BASE - STEP×n_enemigos...
const MP_KILL_MULT_STEP := 0.25  # ...bajando esto por cada bicho del corro...
const MP_KILL_MULT_MIN := 1.25   # ...con suelo aqui (un corro de 4+ ya no baja mas)

# Maná que devuelve UN golpe de arma que acierta.
static func mp_por_golpe() -> float:
	return MP_BASE

# Multiplicador de maná POR BICHO segun cuantos habia en la pelea (decae con el tamaño del corro).
static func mp_kill_mult(enemigos: int) -> float:
	return maxf(MP_KILL_MULT_MIN, MP_KILL_MULT_BASE - MP_KILL_MULT_STEP * float(enemigos))

# Maná que sueltan los enemigos al caer. 'regen_turno' = el goteo por turno de tu arma magica
# (0 si no llevas): el baston no solo te gotea, tambien hace que los nucleos te cundan mas.
static func mp_por_kill(regen_turno: float, enemigos: int = 1) -> float:
	return mp_kill_mult(enemigos) * (MP_BASE + maxf(regen_turno, 0.0)) * float(maxi(enemigos, 0))

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
	return 1.0 + (MAGIA_FACTOR_MAX - 1.0) * pow(clampf(magia, 0.0, MAGIA_CAP) / MAGIA_CAP, MAGIA_FACTOR_EXP)

# Mana maximo segun la Magia (+ una base). FLOAT: asi las subidas pequeñas de Magia
# (y otras mejoras) se NOTAN en el maximo (se muestra con decimales).
static func max_mp_value(ab: Abilities, _level: int, base_mp: float = BASE_MP) -> float:
	return base_mp + ab.magia * MP_FROM_MAGIA

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


# ============================================================
#  FORMULAS DEL JUGADOR (MULTIPLICATIVAS) — SUBIR DE NIVEL
#  Aqui la habilidad MULTIPLICA su base, igual que la Fuerza hace con el ataque. Es lo que hace
#  que SUBIR DE NIVEL valga: al ascender se BAKEAN las bases (ver Game.subir_nivel), y como el
#  punto multiplica una base mayor, un punto de nivel 4 rinde mucho mas que uno de nivel 1. Con
#  las aditivas de arriba eso NO pasaba: +0.15 de vida por Resistencia daba igual tu base.
#
#  Los ENEMIGOS siguen usando las aditivas (por ahora): esto es solo del jugador (ver
#  Combatant.stats_multiplicativas).
#
#  DIVISORES: elegidos para que a NIVEL 1 (con la base de partida) den EXACTAMENTE los mismos
#  numeros que las aditivas -> cero rebalance al empezar. Sale de base*(stat/DIV) == stat*coef,
#  o sea DIV = base_inicial / coef. Ademas ya no usan el _coef por nivel: el crecimiento por
#  nivel lo aporta la base bakeada (si no, se contaria dos veces).
# ============================================================
const RES_HP_DIV := 333.33    # 50 (base_hp)      / 0.15  (HP_FROM_RES)
const RES_DEF_DIV := 250.0    # 5  (base_defense) / 0.02  (DEF_COEF_BASE)
const AGI_SPD_DIV := 250.0    # 5  (base_speed)   / 0.02  (SPD_COEF_BASE)
const MAG_DEF_DIV := 250.0    # 5  (base_magic)   / 0.02  (MAG_COEF_BASE)
const MAG_MP_DIV := 606.06    # 20 (BASE_MP)      / 0.033 (MP_FROM_MAGIA)

static func max_hp_jugador(ab: Abilities, base_hp: float) -> float:
	return base_hp * (1.0 + ab.resistencia / RES_HP_DIV)

static func defense_jugador(ab: Abilities, base_defense: float) -> float:
	return base_defense * (1.0 + ab.resistencia / RES_DEF_DIV)

static func speed_jugador(ab: Abilities, base_speed: float) -> float:
	return base_speed * (1.0 + ab.agilidad / AGI_SPD_DIV)

static func magic_jugador(ab: Abilities, base_magic: float) -> float:
	return base_magic * (1.0 + ab.magia / MAG_DEF_DIV)

static func max_mp_jugador(ab: Abilities, base_mp: float) -> float:
	return base_mp * (1.0 + ab.magia / MAG_MP_DIV)


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
# Multiplicador BASE de daño critico. Encima se suma el crit_dmg del ATACANTE (KAN-52), que sale
# del arma: base comun × RAREZA + mejoras de Precision (ver Upgrades.CRIT_DMG_BASE). Un arma comun
# sin mejoras deja el critico en ×1.75; una obra maestra muy afinada se acerca al ×2.3. Los
# enemigos no llevan arma con rareza -> critean al ×1.5 pelado.
const CRIT_MULT := 1.5

const EVADE_PARITY := 0.05
const EVADE_SPREAD := 0.30
const EVADE_MIN := 0.03     # siempre queda algo de esquiva (nunca casi 0)
const EVADE_MAX := 0.35     # tope normal: nunca te esquivan mas de esto (peleable)
const EVADE_MAX_BUFF := 0.65  # tope ELEVADO cuando una HABILIDAD o BUFF sube tu esquiva (rompe el 0.35)

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


# IMBUICION (KAN-58): prob. de que tus golpes imbuidos PRENDAN su estado (quemadura, rayo,
# mojado). Es la 'base' del hechizo escalada por un CONTEST de tu Magia contra la Resistencia
# del rival: 1.0 en igualdad (te quedas en la base), sube contra debiles y baja contra bestias.
# Asi escala con tu Magia de forma RELATIVA y nunca se infla ni se queda obsoleta.
const IMBUE_PROC_MAX := 0.60
static func imbue_proc_chance(base: float, magia: float, rival_resistencia: float) -> float:
	return clampf(base * _ratio_factor(magia, rival_resistencia), 0.0, IMBUE_PROC_MAX)


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
	# Esquiva EXTRA de HABILIDADES/BUFFS (0 = ninguna). Si hay, SUMA a la esquiva y ademas
	# ROMPE el tope normal: puedes pasar del EVADE_MAX de 0.35 hasta EVADE_MAX_BUFF (0.65).
	# Generico: hoy lo alimenta la postura del estoque, manana cualquier buff de esquiva.
	var evasion_extra := defender.evasion_bonus
	var evade_cap := EVADE_MAX_BUFF if evasion_extra > 0.0 else EVADE_MAX
	var evade_p := clampf(evade_chance(def_agi, atk_dex) - defender.evasion_penal - attacker.precision + evasion_extra, 0.0, evade_cap)
	# RESIST. CRITICOS del defensor (armadura pesada) baja el crit del atacante.
	var crit_p := 0.0 if defending else clampf(crit_chance(atk_dex, def_agi) + attacker.crit_bonus + attacker.crit_flat - defender.crit_resist, 0.0, 1.0)
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
	# Si esta DEFENDIENDO, su escudo suma su defensa aqui (defend_defense): un escudo solo protege
	# de lo que paras con el, asi que no puede ir en def_value() como la armadura.
	var def_val := defender.def_value() + (defender.defend_defense if defending else 0.0)
	var dmg := damage(attacker.atk(), def_val)
	# Variacion aleatoria por golpe (±DAMAGE_VARIANCE), estilo Terraria.
	dmg *= randf_range(1.0 - DAMAGE_VARIANCE, 1.0 + DAMAGE_VARIANCE)

	# 3) Critico (Defender lo ANULA). El multiplicador = base + el crit_dmg del arma del atacante
	# (base × rareza + Precision). Sin arma con rareza (enemigos) se queda en el CRIT_MULT pelado.
	var is_crit := false
	if crit_p > 0.0 and randf() < crit_p:
		is_crit = true
		dmg *= CRIT_MULT + attacker.crit_dmg

	# 3.5) Armadura: reduccion porcentual SIEMPRE activa (afecta tambien al critico).
	dmg *= (1.0 - clampf(defender.armor_reduction, 0.0, ARMOR_REDUCTION_MAX))

	# 4) Defensa activa: reduce el daño segun el bloqueo del loadout del defensor.
	if defending:
		dmg *= clampf(1.0 - defender.defend_block, DEFEND_TAKEN_MIN, DEFEND_TAKEN_MAX)

	# 4.5) ELEMENTOS (KAN-58). Dos cosas distintas, a proposito:
	#  a) El golpe ENTERO va del elemento del atacante (enemigos: el slime de fuego pega fuego).
	#     El jugador tiene elemento_ataque NINGUNO -> mult 1.0, no le afecta.
	#  b) La IMBUICION añade una PORCION de daño elemental encima, que SI sufre la
	#     resistencia/debilidad del objetivo. Nunca penaliza el daño base: solo el extra.
	var mult_elem := Elementos.mult_recibido(attacker.elemento_ataque, defender)
	dmg *= mult_elem
	var mult_imbue := 1.0
	var dmg_imbue := 0.0   # la PORCION elemental, aparte: para poder ENSEÑARLA en el log
	if attacker.imbue_pct > 0.0 and attacker.imbue_elemento != Elementos.Elemento.NINGUNO:
		mult_imbue = Elementos.mult_recibido(attacker.imbue_elemento, defender)
		dmg_imbue = dmg * attacker.imbue_pct * mult_imbue
		dmg += dmg_imbue

	# 5) Aturdir/retrasar (solo armas CONTUNDENTES).
	var aturde := aturde_p > 0.0 and randf() < aturde_p

	return {"damage": maxf(0.1, dmg), "evaded": false, "crit": is_crit, "aturde": aturde,
		"evade_p": evade_p, "crit_p": crit_p, "aturde_p": aturde_p,
		"mult_elem": mult_elem, "mult_imbue": mult_imbue, "dmg_imbue": dmg_imbue}


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
#
# MULTI-GOLPE: un hechizo de N golpes llama a esto N veces con dano_frac = 1/N y el
# elemento de CADA golpe (elem_override). Repartir el daño NO cambia el total mitigado
# (damage() es lineal en el ataque); lo que cambia es que cada golpe pasa por la tabla de
# tipos con su elemento y ve el estado del defensor TAL COMO ESTA en ese instante: si un
# golpe anterior lo mojo, este rayo ya cobra el ×1.5.
static func resolve_spell(attacker: Combatant, defender: Combatant, spell: SpellData,
		elem_override: int = -1, dano_frac: float = 1.0) -> Dictionary:
	var elem: int = elem_override if elem_override >= 0 else spell.elemento
	var raw := spell.dano_base * dano_frac
	var magic_atk := raw * magia_factor(float(attacker.abilities.magia)) * attacker.magic_amp * attacker.magia_base_factor * SPELL_DAMAGE_MULT
	# Defensa MAGICA del objetivo, espejo exacto de la fisica: una BASE propia del bicho +
	# lo que aporte su Magia. Antes se pasaba 0.0 a pelo, y como ademas ningun enemigo tenia
	# Magia, la defensa magica era CERO: los hechizos entraban a raw limpio mientras los
	# golpes fisicos si se mitigaban. Por eso la magia parecia rota (lo estaba).
	var magic_def := magic_jugador(defender.abilities, defender.base_magic) if defender.stats_multiplicativas \
		else magic_value(defender.abilities, defender.level, defender.base_magic)
	var dmg := damage(magic_atk, magic_def)
	dmg *= randf_range(1.0 - DAMAGE_VARIANCE, 1.0 + DAMAGE_VARIANCE)
	# Multiplicador ELEMENTAL segun la resistencia/debilidad del objetivo (KAN-58).
	var mult_elem := Elementos.mult_recibido(elem, defender)
	dmg *= mult_elem
	return {"damage": maxf(0.1, dmg), "mult_elem": mult_elem, "elemento": elem}


# Backfire: daño que te haces al fallar una frase. Escala con dano_base (hechizos
# largos duelen mas) y con el PROGRESO (cuantas frases llevabas: casi terminar y
# fallar duele mas). Ignora defensa (es un descontrol interno).
static func backfire_damage(spell: SpellData, cast_index: int, n_frases: int) -> float:
	var progreso := float(cast_index + 1) / float(maxi(1, n_frases))
	return maxf(1.0, spell.dano_base * BACKFIRE_FRAC * progreso)
