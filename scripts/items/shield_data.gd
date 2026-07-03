# ============================================================
#  shield_data.gd
#  RECURSO (Resource) con los DATOS de un ESCUDO. Se guarda como .tres.
#  Va en la mano SECUNDARIA: aporta MUCHO bloqueo al Defender (mas que
#  cualquier arma), pero penaliza algo la velocidad de combate y la esquiva.
#  Un escudo grande protege mas pero pesa/estorba mas.
#  Ver Game.loadout_mods(), que lo combina con la mano principal.
# ============================================================

extends Resource
class_name ShieldData

enum Tamano { PEQUENO, NORMAL, GRANDE }  # GRANDE = escudos de tanque

@export var nombre: String = "Escudo pequeño"
@export var tamano: Tamano = Tamano.PEQUENO

@export var bloqueo: float = 0.25         # aporte GRANDE al Defender (mas que un arma)
@export var velocidad_mult: float = 0.95  # penaliza algo la velocidad de combate (<1)
@export var evasion_penal: float = 0.03   # baja la esquiva (grande penaliza mas)
