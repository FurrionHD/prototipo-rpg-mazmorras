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

# Id de StatusEffects.Id (-1 = ninguno). Mapa:
#   0 VENENO · 1 SANGRADO · 2 QUEMADURA · 3 LENTO · 4 DEBIL · 5 VULNERABLE ·
#   6 FORTALEZA · 7 ATURDIDO · 8 RAYO · 9 PEGAJOSO
@export var estado: int = -1
# Probabilidad de aplicarlo. Enemigos (al golpear): prob DIRECTA. Hechizos: es la
# prob BASE por frase (la final = base × longitud del hechizo -> mas largo, mas fiable).
@export var prob: float = 1.0
# true = al RIVAL (DoT/debuff, puede resistir); false = a UNO MISMO (buff, siempre).
@export var en_objetivo: bool = true
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
