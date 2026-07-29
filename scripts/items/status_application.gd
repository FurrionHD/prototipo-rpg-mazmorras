# ============================================================
#  status_application.gd  (KAN-58 Fase 3)
#  UNA aplicacion de estado alterado. La usan:
#   - EnemyData.al_golpear  (estados que aplica el enemigo AL GOLPEAR)
#   - SpellData.efectos     (estados que aplica un hechizo AL LANZAR)
#  Una fuente puede llevar VARIAS (p.ej. slime venenoso = Pegajoso + Veneno;
#  Tormenta = Rayo + Aturdido).
# ============================================================

extends Resource
class_name StatusApplication

# Id de StatusEffects.Id (-1 = ninguno). El mapa vive en StatusEffects.Id y NO se copia aqui:
# una lista a mano se queda desactualizada en cuanto se añade un estado (esta lo estuvo).
@export var estado: int = -1
# Probabilidad de aplicarlo. Enemigos (al golpear): prob DIRECTA. Hechizos: es la
# prob BASE por frase (la final = base × longitud del hechizo -> mas largo, mas fiable).
@export var prob: float = 1.0
# true = al RIVAL (DoT/debuff, puede resistir); false = a UNO MISMO (buff, siempre).
@export var en_objetivo: bool = true
# Solo con en_objetivo = false: el buff cae sobre TODO EL GRUPO vivo en vez de sobre quien lo
# lanza. Es lo que hace posible el grito del tanque ("Fortaleza a todos") sin un campo a medida
# por habilidad. Ignorado si en_objetivo = true (un debuff de area ya se reparte por su area_modo).
@export var a_todo_el_grupo: bool = false
# Duracion en turnos (-1 = la del catalogo).
@export var turns: int = -1
# Magnitud del DoT (quemadura...). -1 = la del catalogo (dot_default).
@export var magnitud: float = -1.0
# Tope de stack por aplicacion (veneno tier: cap 1 = tier 1). -1 = sin tope propio.
@export var cap: int = -1
# true = SOLO se tira si el golpe fue CRITICO (premio al crit: p.ej. la Punalada de la
# daga mete un 2o sangrado si critea). Ignorado por enemigos/hechizos (no hay crit ahi).
@export var solo_crit: bool = false
# NIVEL para estados de STAT (Vulnerable/Debil/Lento): multiplicador propio que sustituye
# al del catalogo. 0.0 = usar el del catalogo. Ej: 0.70 = -30% (Vulnerable del hacha),
# 0.80 = -20% (catalogo). Solo aplica a estados que modifican un stat; ignorado en DoT/stun.
@export var mult: float = 0.0
# Nº de STACKS que aplica esta tirada (Pegajoso/Sangrado y demas independientes/merge).
# 1 = un stack (lo normal). Ej: una habilidad de slime que mete "2 stacks de Pegajoso" de
# golpe usa stacks = 2. Para estados que no apilan (Lento/Vulnerable) es indiferente.
@export var stacks: int = 1
# ELEMENTO que debe traer el GOLPE para que este efecto se tire (Elementos.Elemento).
# -1 = se tira en TODOS los golpes. Solo tiene sentido en hechizos MULTI-GOLPE con reparto
# de elementos: es lo que ata cada estado a su elemento sin campos a medida (la Tormenta
# MOJA con sus golpes de Agua y ELECTRIZA/aturde con los de Rayo).
@export var elemento_req: int = -1
