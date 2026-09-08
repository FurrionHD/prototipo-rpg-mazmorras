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
#
#  LA PERSONALIDAD DE CADA TAMAÑO (lo que arregla el "los tres son el mismo escudo"):
#   - PEQUEÑO (rodela)  = DUELISTA:            "yo devuelvo los golpes". aggro bajo + riposte.
#   - NORMAL  (heater)  = GUARDIAN:            "yo te pongo fuerte y te limpio". apoya sin comerselo.
#   - GRANDE  (torre)   = DEFENSOR DEFINITIVO: "yo recibo tus golpes". aggro alto + cover real.
#  Se separan por el VERBO, no por el numero: el reparto de stats de arriba NO se toca. Parte va
#  en campos de aqui (aggro_mult, contra_*) y parte en la lista de `habilidades`, que ahora es
#  DISTINTA en cada tamaño (nucleo comun + 2 propias).
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
# Aguantar detras del escudo tambien tapa del veneno. Sube de 0.05 a 0.12: el escudero es el que
# se come los golpes (aggro x2, x4 provocando) y era justo el que mas estados acumulaba. Ahora que
# RESISTENCIA_CAP es 1.0 no hay riesgo de que armadura + escudo den inmunidad por acumulacion.
@export var resist_estados_base: float = 0.12
@export var velocidad_mult: float = 0.95  # penaliza algo la velocidad de combate (<1). NO escala
@export var evasion_penal: float = 0.03   # baja la esquiva (grande penaliza mas). NO escala

# --- PERSONALIDAD DEL TAMAÑO ---
# Los tres escudos eran el MISMO escudo con otros numeros: mismas habilidades, mismo aggro, y solo
# cambiaba la magnitud. Con todo igualado el grande es siempre el correcto y los otros dos son
# escalones de una escalera, no opciones. Estos campos son lo que cada tamaño HACE y los otros no.
# Van CRUDOS (sin tier ni rareza), como velocidad_mult y evasion_penal: son del tamaño, y un
# escudo pristino no atrae mas golpes por ser pristino.

# CUANTO ATRAE LOS GOLPES, sobre el x2 de base por llevar escudo (Combatant.AGGRO_ESCUDO).
# 0.6 / 1.0 / 1.6 -> aggro efectivo 1.2 / 2.0 / 3.2. Sin esto el pequeño era "el grande peor":
# se comia los mismos golpes y paraba menos. Ahora la rodela te deja escurrirte.
@export var aggro_mult: float = 1.0
# RIPOSTE AL BLOQUEAR: probabilidad de devolver el golpe que paras, y con que fraccion del daño.
# Por PROBABILIDAD a proposito: contraatacar en CADA bloqueo es roto. Solo salta con la guardia
# arriba (igual que la autorregeneracion), asi que hay que gastar el turno en Defender o traerlo
# de gorra con el Golpe de escudo, que ya deja bloqueo_turnos = 1.
# Es la identidad del PEQUEÑO: el duelista que devuelve los golpes.
@export var contra_prob: float = 0.0
@export var contra_mult: float = 0.0

# --- HABILIDADES (KAN-57): las que aporta ESTE escudo (golpe de escudo...) ---
@export var habilidades: Array = []

# PRECIO base de la tienda (ver WeaponData.valor_base).
@export var valor_base: int = 400
