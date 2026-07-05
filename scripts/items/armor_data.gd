# ============================================================
#  armor_data.gd
#  RECURSO (Resource) con los DATOS de una PIEZA de ARMADURA. Se guarda como .tres.
#
#  Modelo ESPEJO de las armas (estilo Monster Hunter): igual que un arma tiene un
#  RAW comun (ataque_base, mismo por tier) x su MOTION_VALUE que la diferencia, una
#  armadura tiene una DEFENSA_BASE comun (misma por tier) x su MOTION_DEF que la
#  diferencia por TIPO. Asi el lenguaje es el mismo:
#     arma:     dano = (raw comun) x motion_value    -> MV x velocidad ~ cte
#     armadura: DEF  = (def comun) x motion_def       -> proteccion x movilidad ~ cte
#  Ligera protege poco pero pesa poco (agil); pesada protege mucho pero pesa mucho
#  (te frena). El equilibrio sale del PESO (equip-load estilo Souls, ver Game).
#
#  Cada pieza aporta DOS cosas:
#   1) DEF plana ADITIVA (defensa_base x motion_def): se suma a la DEF del jugador
#      y pasa por la mitigacion K/(K+DEF). NO lleva techo (escala con el tier).
#   2) % de REDUCCION de dano: NO se suma entre piezas, se PROMEDIA ponderando por
#      la cobertura de cada slot (ver Game.armor_mods()). Acotado por un techo.
#  El "loadout" de armadura son 5 slots en Game (casco/pecho/manos/pantalones/botas).
# ============================================================

extends Resource
class_name ArmorData

enum Tipo { LIGERA, MEDIA, PESADA }
enum Slot { CASCO, PECHO, MANOS, PANTALONES, BOTAS }

@export var nombre: String = "Armadura"
@export var tipo: Tipo = Tipo.MEDIA
@export var slot: Slot = Slot.PECHO
@export var tier: int = 1

# --- Defensa (modelo MH traducido a armadura) ---
# defensa_base = "raw" comun de la armadura: MISMO para todas las piezas del mismo
# tier (espejo de weapon_data.ataque_base). Escala con el tier (tier1 = 0.5). SIN
# techo: en pisos altos los enemigos tienen sumas de stats enormes y una DEF capada
# se volveria inutil; K/(K+DEF) sigue teniendo sentido con DEF de cientos.
@export var defensa_base: float = 0.5
# motion_def = el "motion value" traducido a armadura: diferencia el TIPO.
# ligera 0.5, media 1.0, pesada 2.0. DEF de la pieza = defensa_base x motion_def.
@export var motion_def: float = 1.0

# --- Reduccion porcentual (se PROMEDIA por cobertura, NO se suma) ---
# % de dano que quita ESTA pieza (banda por tipo, sube poco por tier):
# ligera 0.05, media 0.075, pesada 0.10. El techo global esta en StatsMath
# (ARMOR_REDUCTION_MAX). Ver Game.armor_mods() para el promedio ponderado.
@export var reduccion: float = 0.075

# --- Peso para el equip-load (estilo Souls) ---
# ligera < media < pesada. Suma al peso de EQUIPO (separado del peso de loot);
# penaliza la velocidad de mapa (y, solo la armadura, el ritmo ATB de combate).
@export var peso: float = 2.5
