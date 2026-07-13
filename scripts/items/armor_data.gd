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

enum Tipo { CUERO, HIERRO, HIERRO_COMPLETO, PLACAS }
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

# --- Reduccion porcentual (se PROMEDIA por cobertura, NO se suma) ---
# % de dano que quita ESTA pieza. cuero 0.05, hierro 0.075, hierro completo 0.09,
# placas 0.11. El techo global esta en StatsMath (ARMOR_REDUCTION_MAX).
@export var reduccion: float = 0.075

# --- Velocidad (como las armas: >1 acelera, <1 frena) ---
# cuero 1.04, hierro 1.00 (base), hierro completo 0.93, placas 0.88. Se combina por
# cobertura en Game.armor_mods() y afecta al ATB de combate y al movimiento en mapa.
@export var velocidad_mult: float = 1.0

# PRECIO base (ver WeaponData.valor_base). La tienda NO vende armaduras todavia, pero SI te
# compra las que traigas: por eso necesitan precio.
@export var valor_base: int = 300
