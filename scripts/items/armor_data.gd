# ============================================================
#  armor_data.gd
#  RECURSO (Resource) con los DATOS de una PIEZA de ARMADURA. Se guarda como .tres.
#
#  Modelo ESPEJO de las armas (estilo Monster Hunter): igual que un arma tiene un
#  RAW comun (ataque_base) x su MOTION_VALUE que la diferencia, una armadura tiene
#  una DEFENSA_BASE comun x su MOTION_DEF que la diferencia por CATEGORIA. Y, como
#  las armas, cada categoria modula la VELOCIDAD (sin armadura vas mas rapido; las
#  placas te frenan). NO hay peso: la ventaja/penalizacion de moverse es directa.
#
#  Escalon de categorias (mas defensa = mas lento):
#     (sin pieza)      -> +vel (bonus por ir ligero), 0 DEF, 0 reduccion
#     CUERO (ligera)   -> +vel un poco, DEF baja
#     HIERRO (media)   -> vel BASE (x1), DEF media
#     HIERRO_COMPLETO  -> -vel, DEF alta
#     PLACAS (maxima)  -> -vel (lo mas lento), DEF maxima
#
#  Cada pieza aporta TRES cosas (ver Game.armor_mods()):
#   1) DEF plana ADITIVA (defensa_base x motion_def x tier): suma a la DEF del
#      jugador y pasa por la mitigacion K/(K+DEF). SIN techo (escala con el tier).
#   2) % de REDUCCION de dano: NO se suma, se PROMEDIA por cobertura de slot. Acotado.
#   3) VELOCIDAD (velocidad_mult): se combina por cobertura y afecta al ATB de
#      combate Y al movimiento por la mazmorra.
#  El "loadout" de armadura son 5 slots en Game (casco/pecho/manos/pantalones/botas).
# ============================================================

extends Resource
class_name ArmorData

# TELA va AL FINAL a proposito (08/10/2026): el tipo se guarda como entero en los .tres y en las
# partidas, y meterla delante cambiaria lo que es cada pieza que ya existe.
enum Tipo { CUERO, HIERRO, HIERRO_COMPLETO, PLACAS, TELA }
enum Slot { CASCO, PECHO, MANOS, PANTALONES, BOTAS }

@export var nombre: String = "Armadura"
@export var tipo: Tipo = Tipo.HIERRO
@export var slot: Slot = Slot.PECHO
@export var tier: int = 1

# --- Defensa (modelo MH traducido a armadura) ---
# defensa_base = "raw" comun de la armadura. El tier lo MULTIPLICA (mejorar la pieza),
# SIN techo: en pisos altos los enemigos tienen sumas de stats enormes y una DEF
# capada se volveria inutil; K/(K+DEF) sigue teniendo sentido con DEF de cientos.
@export var defensa_base: float = 0.5
# motion_def = el "motion value" traducido a armadura: diferencia la CATEGORIA.
# cuero 0.5, hierro 1.0, hierro completo 1.6, placas 2.2. DEF = defensa_base x motion_def.
@export var motion_def: float = 1.0

# --- DEFENSA MAGICA (08/10/2026, fase 2 del plan de mecanicas): AL REVES que la fisica ---
# Lo que la categoria pierde en fisica lo gana en magica: la suma fisica + magica es 3,2 en todas
# (decision del usuario). Elegir armadura es elegir contra que te proteges.
#            motion_def  motion_mdef   reduccion  reduccion_magica
#   TELA        0,6         2,6          0,04         0,11
#   CUERO       1,0         2,2          0,05         0,09
#   HIERRO      1,4         1,8          0,075        0,075
#   H.COMPLETO  1,8         1,4          0,09         0,05
#   PLACAS      2,2         1,0          0,11         0,04
# -1 = "lo de su categoria" (MOTION_MDEF_TIPO / REDUCCION_MAGICA_TIPO): asi las 20 piezas de antes
# no hay que tocarlas y la tabla vive en UN sitio. Una pieza con un valor propio lo pone a mano.
@export var motion_mdef: float = -1.0
@export var reduccion_magica: float = -1.0

const MOTION_MDEF_TIPO := [2.2, 1.8, 1.4, 1.0, 2.6]          # indices = Tipo
const REDUCCION_MAGICA_TIPO := [0.09, 0.075, 0.05, 0.04, 0.11]

func mdef_motion() -> float:
	if motion_mdef >= 0.0:
		return motion_mdef
	return float(MOTION_MDEF_TIPO[clampi(int(tipo), 0, MOTION_MDEF_TIPO.size() - 1)])

func reduccion_magia() -> float:
	if reduccion_magica >= 0.0:
		return reduccion_magica
	return float(REDUCCION_MAGICA_TIPO[clampi(int(tipo), 0, REDUCCION_MAGICA_TIPO.size() - 1)])

# LIGERAS: las que mejoran Evasion (tela, cuero y hierro); las pesadas van por Resist. criticos.
# Antes se miraba "tipo <= 1" y la TELA (indice 4) habria caido en las pesadas.
static func es_ligera(t: int) -> bool:
	return t == Tipo.CUERO or t == Tipo.HIERRO or t == Tipo.TELA

# --- Durabilidad por CATEGORIA ---
# Cuanto mas pesada, mas aguanta: multiplica el maximo de durabilidad (ver Game.max_durabilidad).
# Sigue la misma escalera que motion_def (15/09/2026): cuero 1.0, hierro 1.4, hierro completo 1.8,
# placas 2.2. Solo cambia el maximo; lo guardado es la fraccion, asi que las piezas viejas conservan
# su % y a partir de ahi duran mas.
@export var durabilidad_mult: float = 1.0

# --- Reduccion porcentual (se PROMEDIA por cobertura, NO se suma) ---
# % de dano que quita ESTA pieza. cuero 0.05, hierro 0.075, hierro completo 0.09,
# placas 0.11. El techo global esta en StatsMath (ARMOR_REDUCTION_MAX).
@export var reduccion: float = 0.075

# --- Velocidad (como las armas: >1 acelera, <1 frena) ---
# cuero 1.04, hierro 1.00 (base), hierro completo 0.93, placas 0.88. Se combina por
# cobertura en Game.armor_mods() y afecta al ATB de combate y al movimiento en mapa.
@export var velocidad_mult: float = 1.0

# PRECIO base (ver WeaponData.valor_base). La tienda las vende (mostradores T1 y T2, siempre a
# rareza comun) y tambien te compra las que traigas del baul.
@export var valor_base: int = 300
