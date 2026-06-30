# ============================================================
#  enemy_data.gd
#  RECURSO (Resource) con los DATOS de un tipo de enemigo: identidad,
#  habilidades de combate (DanMachi), stats base y datos de exploracion.
#  Se guarda como archivo .tres. Sabe crear su propio Combatant para la
#  pantalla de combate.
# ============================================================

extends Resource
class_name EnemyData

# --- Identidad ---
@export var enemy_name: String = "Slime"
@export var color: Color = Color(1.0, 0.2, 0.2)  # color del placeholder

# --- Combate: nivel + habilidades DanMachi (0-999) ---
@export var level: int = 1
@export_range(0, 999) var fuerza: int = 80
@export_range(0, 999) var resistencia: int = 70
@export_range(0, 999) var destreza: int = 30
@export_range(0, 999) var agilidad: int = 60
@export_range(0, 999) var magia: int = 0

# --- Combate: stats base (lo que tiene "de serie", sin habilidades) ---
@export var base_hp: float = 40.0
@export var base_attack: float = 4.0
@export var base_defense: float = 5.0
@export var base_speed: float = 4.0

# --- Exploracion (mazmorra): velocidad de patrulla/persecucion (franja) ---
@export var move_speed_min: float = 30.0
@export var move_speed_max: float = 55.0

# --- Loot: franja de valor del cristal que suelta (Fase 5) ---
@export var crystal_value_min: int = 5
@export var crystal_value_max: int = 15


# Crea un objeto Abilities a partir de los campos de habilidades.
func crear_abilities() -> Abilities:
	var a := Abilities.new()
	a.fuerza = fuerza
	a.resistencia = resistencia
	a.destreza = destreza
	a.agilidad = agilidad
	a.magia = magia
	return a


# Crea el Combatant (lo que usa la pantalla de combate) de este enemigo.
func crear_combatant() -> Combatant:
	return Combatant.new(enemy_name, level, crear_abilities(),
		base_hp, base_attack, base_defense, base_speed)
