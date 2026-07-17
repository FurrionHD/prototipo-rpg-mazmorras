# ============================================================
#  shield_data.gd
#  RECURSO (Resource) con los DATOS de un ESCUDO. Se guarda como .tres.
#  Va en la mano SECUNDARIA: aporta MUCHO bloqueo al Defender (mas que
#  cualquier arma), pero penaliza algo la velocidad de combate y la esquiva.
#  Un escudo grande protege mas pero pesa/estorba mas.
#  Ver Game.loadout_mods(), que lo combina con la mano principal.
#
#  QUE ESCALA Y QUE NO (lo que arregla el "todos los escudos son iguales"):
#   - La DEFENSA es lo que crece con tier, rareza y mejoras. Es el numero del escudo.
#   - El BLOQUEO (la % de reduccion) es del TAMAÑO: un escudo grande T1 reduce lo mismo que uno
#     grande T3, y uno pristino lo mismo que uno comun. Solo lo sube el Refuerzo, y de forma
#     DECRECIENTE (sin tope: la propia curva asintota en +0.25). Se hace asi porque el bloqueo
#     tiene un techo duro (StatsMath.DEFEND_TAKEN_MIN: max. 80% entre base y escudo): si lo
#     multiplicaran el tier o la rareza, un escudo bueno lo saturaria y volverian a no notarse.
#   - La velocidad y la penalizacion de esquiva son del TAMAÑO y NO escalan: lo que estorba un
#     escudo grande es que es grande, no que este mal hecho.
#  Ver Upgrades.shield_mods(), que es donde vive esa math.
# ============================================================

extends Resource
class_name ShieldData

enum Tamano { PEQUENO, NORMAL, GRANDE }  # GRANDE = escudos de tanque

@export var nombre: String = "Escudo pequeño"
@export var tamano: Tamano = Tamano.PEQUENO

# DEFENSA que aporta, pero SOLO el turno que eliges Defender (no es armadura: es un escudo, solo
# para lo que paras con el). Va por la mitigacion normal K/(K+DEF), asi que no tiene techo y se
# puede escalar con tier/rareza/mejoras sin romper nada. Es LO QUE distingue a un escudo bueno.
@export var defensa_base: float = 2.0
# % que reduce al Defender. Es la marca del TAMAÑO y no la toca ni el tier ni la rareza; el
# Refuerzo suma encima (decreciente, +0.25 como mucho). Sin tope propio: ver Upgrades.shield_mods.
@export var bloqueo: float = 0.10
@export var resist_estados_base: float = 0.05  # aguantar detras del escudo tambien tapa del veneno
@export var velocidad_mult: float = 0.95  # penaliza algo la velocidad de combate (<1). NO escala
@export var evasion_penal: float = 0.03   # baja la esquiva (grande penaliza mas). NO escala

# --- HABILIDADES (KAN-57): las que aporta ESTE escudo (golpe de escudo...) ---
@export var habilidades: Array = []

# PRECIO base de la tienda (ver WeaponData.valor_base).
@export var valor_base: int = 400
