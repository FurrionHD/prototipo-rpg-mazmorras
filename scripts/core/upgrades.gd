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
#   - Categorias DISTINTAS por tipo, con GATING por clase de armadura. Durabilidad
#     (mantenimiento) y Resistencia a estados ya estan ACTIVAS. La Durabilidad no da un
#     stat de combate: sube el MAXIMO de durabilidad del item (ver Game.max_durabilidad).
# ============================================================

extends RefCounted
class_name Upgrades

enum Rareza { COMUN, POCO_COMUN, RARO, EPICO, LEGENDARIO, MITICO, OBRA_MAESTRA }

# COMUN = 1.00 (regresion exacta: rareza comun + 0 mejoras = como antes). La obra maestra a
# 1.55 se NOTA: antes iba a 1.15 (un +15% de risa) y ademas solo tocaba el raw/DEF. Ahora la
# rareza multiplica TODAS las stats de combate (crit, evasion, aturdir, bloqueo, el bonus de
# rapidez) y ademas hace que cada mejora rinda mas (sube los topes). Lo unico que NO toca es el
# motion_value del arma (su equilibrio) ni la reduccion/velocidad de tipo de la armadura.
const RAREZA_MULT := [1.00, 1.08, 1.16, 1.25, 1.35, 1.45, 1.55]
const RAREZA_SLOTS := [3, 4, 5, 6, 8, 10, 12]
const RAREZA_NOMBRE := ["Comun", "Poco comun", "Raro", "Epico", "Legendario", "Mitico", "Obra maestra"]

# Lo que sube el numero PRIMARIO (raw del arma / DEF de la armadura) por CADA mejora. Es un
# PORCENTAJE de la base del PROPIO objeto, no un flat.
#
# Antes era un +0.3 plano, y ahi habia un bug de escala gordo: el ataque de un arma es 3.0
# (asi que +0.3 = +10%, razonable) pero la defensa de un peto de cuero es 0.5x0.5 = 0.25 (asi
# que +0.3 = +120%: dos mejoras TRIPLICABAN la pieza). Y ademas la misma mejora valia cuatro
# veces menos en placas (base 1.1) que en cuero. Con un %, cada pieza sube en SU escala y las
# dos ramas quedan coherentes. En las armas el resultado es identico al de antes: 0.3 sobre
# 3.0 ya era justo el 10%.
const UPGRADE_PCT := 0.10   # +10% de la base por CADA mejora
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
const RESISTENCIA := "resistencia"    # -prob. de estados alterados (KAN-58, activa)
# Generica (arma y armadura):
const DURABILIDAD := "durabilidad"    # ACTIVA: sube el maximo de durabilidad (mantenimiento)

# Nombres legibles para la UI.
const CAT_NOMBRE := {
	"agudeza": "Agudeza", "precision": "Precision", "peso": "Peso", "rapidez": "Rapidez",
	"potencia": "Potencia", "eficiencia": "Eficiencia", "celeridad": "Celeridad", "regeneracion": "Regeneracion",
	"dureza": "Dureza", "evasion": "Evasion", "resist_crit": "Resist. criticos",
	"resistencia": "Resistencia (estados)", "durabilidad": "Durabilidad",
}

# --- Steps de cada categoria (extra DECRECIENTE por punto) ---
const AGUDEZA_STEP := 0.05        # +raw, en % de la base del arma (decreciente)
const PRECISION_CRIT_STEP := 0.02 # +prob. critico
const PRECISION_HIT_STEP := 0.02  # +acierto (baja evasion rival)
const PESO_STEP := 0.03           # +aturdir/stun (solo contundentes)
const RAPIDEZ_STEP := 0.03        # +velocidad arma
const RAPIDEZ_CAP := 0.08         # tope del bonus de rapidez
const DUREZA_STEP := 0.05         # +DEF, en % de la base de la pieza (decreciente)
const EVASION_STEP := 0.02        # +esquiva (ligeras/medias)
const EVASION_CAP := 0.20         # tope del bonus de esquiva de armadura
const RESIST_CRIT_STEP := 0.02    # -crit rival (pesadas)
const RESIST_CRIT_CAP := 0.25     # tope de resistencia a criticos
const RESISTENCIA_STEP := 0.03    # -prob. de que te apliquen un estado alterado (KAN-58)
const RESISTENCIA_CAP := 0.50     # tope de resistencia a estados (por armadura, sumando piezas)
# Armas MAGICAS (KAN-95). Todos PROVISIONALES -> Excel.
const MAGIC_AMP_FLAT := 0.02      # +magic_amp por CADA mejora (primario del arma magica)
const POTENCIA_STEP := 0.05       # +magic_amp de la categoria Potencia (extra, decreciente)
const POTENCIA_CAP := 0.25        # tope del bonus de Potencia
# TIER de las armas magicas: escala el magic_amp de forma MUCHO mas suave que el melee
# (subir de tier en magia no debe valer tanto como en fisico). Curva = tmult^POWER con
# un exponente bajo: t1 ×1.00, t2 ×1.12, t3 ×1.25. PROVISIONAL -> Excel.
const MAGIC_TIER_POWER := 0.14
const EFICIENCIA_STEP := 0.05     # -% coste de maná (dim_sum asintota a 0.25 -> hay que invertir MUCHO)
const EFICIENCIA_CAP := 0.25
const CELERIDAD_STEP := 0.03      # +velocidad de casteo
const CELERIDAD_CAP := 0.10
const REGENERACION_STEP := 0.08   # +% sobre el regen de maná del arma
const REGENERACION_CAP := 0.40


# La rareza de COMBATE apenas mueve los numeros (x1.00 a x1.15): un arma legendaria lo es por
# sus huecos de mejora, no por su base. Pero la MOCHILA no tiene mejoras, asi que su rareza es
# lo UNICO que la diferencia -> necesita su propia tabla, y una que se note: de comun a obra
# maestra hay un +50% de carga (no el +15% de risa del combate).
const RAREZA_CAPACIDAD := [1.00, 1.07, 1.15, 1.23, 1.32, 1.41, 1.50]

static func rareza_mult_capacidad(r: int) -> float:
	return RAREZA_CAPACIDAD[clampi(r, 0, RAREZA_CAPACIDAD.size() - 1)]


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

# El TOPE de una mejora sube con la rareza: si no, una obra maestra muy mejorada choca contra
# el mismo techo que una comun y toda su ventaja se evapora justo donde mas inviertes.
static func cap_rareza(cap: float, rareza: int) -> float:
	return cap * rareza_mult(rareza)

# Mejora un valor con la rareza SIEMPRE hacia lo bueno. Para casi todo (raw, evasion, aturdir)
# "bueno" es mas grande, asi que se multiplica. Pero el CRITICO de las contundentes es negativo
# a proposito (una maza no critica): multiplicar ×rareza lo hundiria mas, y una maza obra
# maestra saldria PEOR de critico que una comun. Con esto, lo positivo sube y lo negativo se
# SUAVIZA hacia cero: la obra maestra nunca es peor en nada.
static func mejor_con_rareza(val: float, rmult: float) -> float:
	return val * rmult if val >= 0.0 else val / rmult

static func _count(mejoras: Dictionary, cat: String) -> int:
	return int(mejoras.get(cat, 0))

static func total_mejoras(mejoras: Dictionary) -> int:
	var n := 0
	for k in mejoras:
		n += int(mejoras[k])
	return n

# Mejoras que cuentan para el +10% universal de raw/DEF: TODAS menos Durabilidad. La Durabilidad
# es mantenimiento (sube el maximo de aguante, no el daño/defensa), asi que no debe buffear los
# numeros de combate por la puerta de atras. Sigue ocupando hueco y contando para venta/reparacion.
static func mejoras_combate(mejoras: Dictionary) -> int:
	return total_mejoras(mejoras) - _count(mejoras, DURABILIDAD)


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
	cats.append(DURABILIDAD)  # sube el maximo de durabilidad
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
	cats.append(RESISTENCIA)   # resist. estados (activa, KAN-58)
	cats.append(DURABILIDAD)   # sube el maximo de durabilidad
	return cats


# Agregados de un ARMA (por mano). tmult = tier_mult(tier) ya calculado.
#
# La RAREZA multiplica TODO lo que hace mejor a un arma, no solo el raw: cada stat sale como
# (base_del_arma + aporte_de_mejoras) × rareza. Antes el crit/evasion/aturdir/bloqueo se cogian
# en crudo del .tres y la rareza no los rozaba, asi que una daga obra maestra daba el MISMO
# critico que una comun. Lo unico que la rareza NO toca es el motion_value (el equilibrio del
# arma) ni la velocidad base por TAMAÑO (w.velocidad_mult): esos no son "calidad".
#
# 'crit'/'evasion'/'aturdir'/'bloqueo' salen ya RESUELTOS (base incluida): _hand_from y
# loadout_mods los toman de aqui en vez de leer los campos del .tres a pelo.
static func weapon_mods(w: WeaponData, tmult: float, rareza: int, mejoras: Dictionary) -> Dictionary:
	var rmult := rareza_mult(rareza)
	# Arma MAGICA (baston): la potencia magica va aparte (magic_mods). Aqui solo lo
	# FISICO del golpe: base × rareza + Agudeza (raw), y Peso (aturdir) si contundente.
	# El resto de mejoras magicas NO tocan el daño fisico.
	if w != null and w.es_magica:
		var raw_mag := w.ataque_base * rmult \
			* (1.0 + dim_sum(AGUDEZA_STEP, _count(mejoras, AGUDEZA))) * tmult
		var aturdir_mag := 0.0
		if int(w.dano_tipo) == 1:  # CONTUNDENTE
			aturdir_mag = (w.aturdir_base + dim_sum(PESO_STEP, _count(mejoras, PESO))) * rmult
		return {"raw": raw_mag, "crit": mejor_con_rareza(w.crit_bonus, rmult), "precision": 0.0,
			"aturdir": aturdir_mag, "evasion": w.evasion_bonus * rmult,
			"bloqueo": w.bloqueo * rmult, "vel_mult": 1.0}
	var n := mejoras_combate(mejoras)   # la Durabilidad no cuenta para el +10% de daño
	# +10% de la base por CADA mejora (universal) + extra de Agudeza (decreciente, tambien en %
	# de la base). Todo sobre la base × rareza, y el conjunto × tier.
	var subida := UPGRADE_PCT * float(n) + dim_sum(AGUDEZA_STEP, _count(mejoras, AGUDEZA))
	var raw := w.ataque_base * rmult * (1.0 + subida) * tmult
	var kp := _count(mejoras, PRECISION)
	var aturdir := 0.0
	if int(w.dano_tipo) == 1:  # solo contundentes
		aturdir = (w.aturdir_base + dim_sum(PESO_STEP, _count(mejoras, PESO))) * rmult
	# El bonus de rapidez y su TOPE escalan con la rareza; la velocidad base por tamaño no.
	var rapidez := minf(cap_rareza(RAPIDEZ_CAP, rareza), dim_sum(RAPIDEZ_STEP, _count(mejoras, RAPIDEZ)) * rmult)
	return {
		"raw": raw,
		"crit": mejor_con_rareza(w.crit_bonus + dim_sum(PRECISION_CRIT_STEP, kp), rmult),
		"precision": dim_sum(PRECISION_HIT_STEP, kp) * rmult,
		"aturdir": aturdir,
		"evasion": w.evasion_bonus * rmult,
		"bloqueo": w.bloqueo * rmult,
		"vel_mult": 1.0 + rapidez,
	}

# Agregados MAGICOS de un arma de mago (baston o varita), por slot. Las mejoras
# magicas NO usan tier (para no disparar el multiplicador): magic_amp sale de la
# base × rareza + un flat por mejora; el resto son porcentajes con tope.
#   base_amp = magic_amp base del item (baston 1.8 / varita 1.4).
# Factor por el que el TIER escala el magic_amp (curva suave, muy por debajo del melee).
static func magic_tier_ratio(tmult: float) -> float:
	return pow(tmult, MAGIC_TIER_POWER)

static func magic_mods(base_amp: float, tmult: float, rareza: int, mejoras: Dictionary) -> Dictionary:
	var n := mejoras_combate(mejoras)   # la Durabilidad no cuenta para el +flat de magic_amp
	# magic_amp = base×rareza + flat universal por CADA mejora + extra de Potencia (decreciente, tope).
	# El TIER lo multiplica todo por el mismo factor de daño que una melee (magic_tier_ratio).
	# Los topes de las mejoras magicas tambien suben con la rareza (como en armas/armaduras).
	var potencia := minf(cap_rareza(POTENCIA_CAP, rareza), dim_sum(POTENCIA_STEP, _count(mejoras, POTENCIA)))
	var amp := (base_amp * rareza_mult(rareza) + MAGIC_AMP_FLAT * float(n) + potencia) * magic_tier_ratio(tmult)
	return {
		"magic_amp": amp,
		"mana_reduccion": minf(cap_rareza(EFICIENCIA_CAP, rareza), dim_sum(EFICIENCIA_STEP, _count(mejoras, EFICIENCIA))),
		"cast_vel_add": minf(cap_rareza(CELERIDAD_CAP, rareza), dim_sum(CELERIDAD_STEP, _count(mejoras, CELERIDAD))),
		"regen_mult": 1.0 + minf(cap_rareza(REGENERACION_CAP, rareza), dim_sum(REGENERACION_STEP, _count(mejoras, REGENERACION))),
	}


# Agregados de una PIEZA de armadura. tmult = tier_mult(tier). La reduccion y la
# velocidad de la pieza salen de la base (el tier/rareza/mejoras solo tocan DEF,
# evasion y resist. criticos). game.gd combina las 5 piezas por cobertura.
static func armor_piece_mods(a: ArmorData, tmult: float, rareza: int, mejoras: Dictionary) -> Dictionary:
	var n := mejoras_combate(mejoras)   # la Durabilidad no cuenta para el +10% de DEF
	# Mismo modelo que el arma: la mejora sube un % de la DEF de ESTA pieza, no un flat. Asi un
	# peto de cuero (base 0.25) y una coraza de placas (base 1.1) suben lo mismo EN PROPORCION,
	# en vez de que dos mejoras tripliquen el cuero y apenas se noten en las placas.
	var rmult := rareza_mult(rareza)
	var subida := UPGRADE_PCT * float(n) + dim_sum(DUREZA_STEP, _count(mejoras, DUREZA))
	var deff := a.defensa_base * a.motion_def * rmult * (1.0 + subida) * tmult
	# La rareza tambien empuja la evasion / resist. criticos / resist. estados (como en las armas).
	# La reduccion y la velocidad de la pieza NO: son de tipo/tamaño, no de calidad.
	var evasion := 0.0
	var crit_resist := 0.0
	if int(a.tipo) <= 1:
		evasion = dim_sum(EVASION_STEP, _count(mejoras, EVASION)) * rmult
	else:
		crit_resist = dim_sum(RESIST_CRIT_STEP, _count(mejoras, RESIST_CRIT)) * rmult
	# Resistencia a ESTADOS alterados (KAN-58): disponible en TODA armadura.
	var resist_estados := dim_sum(RESISTENCIA_STEP, _count(mejoras, RESISTENCIA)) * rmult
	return {
		"def": deff,
		"reduccion": a.reduccion,
		"vel_mult": a.velocidad_mult,
		"evasion": evasion,
		"crit_resist": crit_resist,
		"resist_estados": resist_estados,
	}
