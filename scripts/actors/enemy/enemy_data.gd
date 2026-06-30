# ============================================================
#  enemy_data.gd
#  RECURSO (Resource) con los DATOS de un tipo de enemigo.
#  No es un nodo: es un "molde de datos" que se guarda como archivo .tres.
#  Asi puedes crear muchos enemigos distintos (slime, murcielago, jefe...)
#  cambiando solo valores en el editor, sin tocar codigo.
# ============================================================

# "extends Resource" = esto es un recurso de datos reutilizable.
extends Resource

# "class_name" registra el tipo en Godot, para poder crear archivos .tres
# de tipo "EnemyData" desde el editor (clic derecho -> Nuevo Recurso).
class_name EnemyData

# --- Identidad ---
@export var enemy_name: String = "Slime"

# --- Color del placeholder (mientras no haya sprites) ---
@export var color: Color = Color(1.0, 0.2, 0.2)  # rojo por defecto

# --- Estadisticas de combate (se usaran en la Fase 4) ---
# Son FRANJAS (min-max): cada enemigo concreto tira un valor aleatorio
# dentro de la franja al aparecer (ver enemy.gd). Asi dos slimes no son
# identicos. Si quisieras un valor fijo, pon min = max.
@export var health_min: int = 18
@export var health_max: int = 25

@export var attack_min: int = 4
@export var attack_max: int = 7

# Velocidad de COMBATE (agilidad): decide el orden de los turnos en la
# Fase 4. Cuanto mayor, antes actua; si es muy superior a la del rival,
# podra actuar 2 veces antes que el. Tambien es franja (min-max).
@export var speed_min: int = 8
@export var speed_max: int = 12

# --- Movimiento en la exploracion (mazmorra) ---
# Velocidad a la que PATRULLA y PERSIGUE por la mazmorra. Tambien franja:
# un enemigo rapido te alcanza mas facil y podra iniciar el combate.
# Es independiente de la velocidad de combate (speed_min/max).
@export var move_speed_min: float = 30.0
@export var move_speed_max: float = 55.0

# --- Loot: franja de valor del cristal que suelta (Fase 5) ---
# Al morir generara un cristal con valor aleatorio entre estos dos.
@export var crystal_value_min: int = 5
@export var crystal_value_max: int = 15
