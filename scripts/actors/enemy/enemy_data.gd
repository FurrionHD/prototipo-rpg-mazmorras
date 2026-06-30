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

# --- Loot: CATEGORIA del cristal que se le puede extraer (Fase 5) ---
# El cristal sale en una categoria aleatoria dentro de esta franja (mayor
# categoria = mas valioso). La CALIDAD (intacto/dañado/roto) la decide el
# minijuego de extraccion. El slime, p.ej., da categoria 3-5.
@export var crystal_category_min: int = 3
@export var crystal_category_max: int = 5


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


# Tira una categoria de cristal al azar dentro de la franja del enemigo.
func roll_crystal_category() -> int:
	return randi_range(crystal_category_min, crystal_category_max)
