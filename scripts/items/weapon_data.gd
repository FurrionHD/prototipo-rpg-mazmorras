# ============================================================
#  weapon_data.gd
#  RECURSO (Resource) con los DATOS de un ARMA. Se guarda como .tres.
#
#  Modelo estilo Monster Hunter: daño del golpe = (base + ataque_base del arma)
#  × factor_fuerza × MOTION_VALUE. El ataque_base es el MISMO para todas las
#  armas del mismo tier (la Fuerza lo multiplica); lo que diferencia a las armas
#  es su MOTION VALUE (% de raw por golpe) × VELOCIDAD (cuantos turnos consigue).
#  El equilibrio sale de MOTION_VALUE × velocidad ≈ constante: la daga pega
#  poquito pero muchas veces; el mandobles pega un pepino pero lento.
#
#  Ademas modula critico, bloqueo (si va en la mano secundaria) y, si es
#  CONTUNDENTE, la probabilidad de aturdir/retrasar (menos daño, no corta).
#  El "loadout" son DOS manos (principal + secundaria); ver Game.loadout_mods().
# ============================================================

extends Resource
class_name WeaponData

enum Tipo {
	PUNOS, DAGA, ESPADA_CORTA, ESPADA_LARGA, MANDOBLE,
	HACHA_MANO, HACHA_GRANDE, MAZA_PEQ, MARTILLO_GRANDE,
}
enum DanoTipo { CORTE, CONTUNDENTE }

@export var nombre: String = "Puños"
@export var tipo: Tipo = Tipo.PUNOS

# Manejo: un arma a DOS MANOS ocupa las dos manos (sin secundaria); puede_dual
# indica que vale como mano SECUNDARIA (dual-wield).
@export var dos_manos: bool = false
@export var puede_dual: bool = true
# off_hand_solo_escudo = como PRINCIPAL, en la otra mano SOLO admite escudo (o
# nada); nunca otra arma. La espada larga: ya pega mucho de una mano, asi que su
# unica combinacion es espada + escudo (o sola). No dual.
@export var off_hand_solo_escudo: bool = false

# --- Modificadores de combate ---
# ataque_base = RAW que APORTA el arma (el "Attack" del arma en MH). Se SUMA al
# raw del jugador (base + Fuerza×coef). Por eso equipar un arma SIEMPRE sube el
# daño respecto a ir a puños. IMPORTANTE (estilo MHW): TODAS las armas del MISMO
# tier comparten el MISMO ataque_base; la diferencia entre armas la hace SOLO el
# motion_value × velocidad, NO el raw. Las de principiante = 3 (puños = 0).
@export var ataque_base: float = 0.0
# motion_value = % del RAW total que aporta CADA golpe (reparte el raw por golpe,
# estilo MH). Rapidas < 1 (poco por golpe, muchos golpes); grandes > 1 (pepino
# lento). Daño del ataque basico = (raw_jugador + ataque_base) × motion_value.
@export var motion_value: float = 0.5     # arma_factor para Excelia (KAN-82); contundentes algo menor
@export var velocidad_mult: float = 1.0   # por TAMAÑO; se aplica MULTIPLICATIVO a la velocidad
@export var crit_bonus: float = 0.0       # se SUMA a la prob. de critico (≈ "afinidad" de MH)
@export var evasion_bonus: float = 0.0    # +esquiva propia (armas agiles: daga). Se aplica de la mano principal
@export var bloqueo: float = 0.0          # aporte al Defender si va en la mano secundaria

# --- Tipo de daño / aturdir (contundentes) ---
@export var dano_tipo: DanoTipo = DanoTipo.CONTUNDENTE
@export var aturdir_base: float = 0.05    # 0 si CORTE; >0 = prob. base de aturdir/retrasar

# --- Energia (FASE B) ---
# + recupera energia con el ataque basico, − la gasta. (Aun sin usar.)
@export var energia_ataque: float = 0.0

# --- Desgaste / mantenimiento (FASE futura, sustituye al "filo" de MH) ---
# El arma se desgasta con el uso; al bajar, pega menos, y en el pueblo pagas
# mantenimiento (dinero de los cristales) para restaurarla. durabilidad_max =
# cuanto aguanta antes de necesitar repaso. El desgaste ACTUAL (que se gasta y
# se repara) se guardara aparte, por arma equipada, no en este .tres compartido.
@export var durabilidad_max: float = 100.0
