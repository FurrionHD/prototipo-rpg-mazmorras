# ============================================================
#  wand_data.gd
#  RECURSO (Resource) con los DATOS de una VARITA. Se guarda como .tres.
#  Va en la mano SECUNDARIA del mago HIBRIDO (arma ligera + varita). NO se ataca
#  con ella: solo potencia la magia (magic_amp medio), da algo de regen de maná
#  (poco) y, sobre todo, define la VELOCIDAD DE CASTEO: al lanzar hechizos la
#  barra ATB se llena a la velocidad de la varita (no la del arma principal).
#  Solo compatible con armas ligeras (daga / espada corta / maza pequeña).
#  Ver Game.loadout_mods() / _secundaria_valida().
# ============================================================

extends Resource
class_name WandData

@export var nombre: String = "Varita"

# Potencia magica (multiplica el daño de hechizos). Media (menos que el bastón).
@export var magic_amp: float = 1.4
# Regen de maná por turno que aporta (poca).
@export var mp_regen_bonus: float = 0.15
# VELOCIDAD DE CASTEO: mientras casteas, la barra ATB usa esta velocidad.
@export var velocidad_mult: float = 1.2
# La varita apenas bloquea/estorba (va casi neutra en lo defensivo).
@export var bloqueo: float = 0.0
@export var evasion_penal: float = 0.0
