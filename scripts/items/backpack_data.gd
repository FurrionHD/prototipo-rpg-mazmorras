# ============================================================
#  backpack_data.gd
#  MOCHILA: lo unico que sube la CAPACIDAD DE CARGA. Un .tres por modelo.
#
#  No es equipo de combate: no ocupa mano, no pesa y no entra en el loadout. Vive en su propio
#  slot (Game.equipped_mochila) y lo unico que hace es sumar a Game.extra_capacity.
#
#  OJO con lo que NO hace: no multiplica tu capacidad, la SUMA al contenedor. La Fuerza es la
#  que multiplica el conjunto (ver Game.capacidad_carga), asi que una mochila le rinde mas a un
#  fortachon que a un alfeñique... sin que haya que escribir eso en ningun sitio.
#
#  Tier y rareza (Game.meta_de) SI la escalan: ver Game.capacidad_mochila().
# ============================================================

extends Resource
class_name BackpackData

@export var nombre: String = "Mochila"
@export_multiline var descripcion: String = ""

# Carga que SUMA al zurron de serie (Game.base_capacity = 25). La basica: +25.
# OJO: este default lo PISA el .tres (resources/backpacks/mochila_basica.tres). Si lo cambias
# aqui, cambialo tambien alli o no servira de nada. Y ademas debe cuadrar con el primer valor de
# Game.MOCHILA_CAPACIDAD_TIER, que es el que da los factores de tier.
@export var capacidad: float = 25.0

# PRECIO de tienda (ver WeaponData.valor_base).
@export var valor_base: int = 400
