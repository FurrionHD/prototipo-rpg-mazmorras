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
@export_range(0, 999) var fuerza: int = 40
@export_range(0, 999) var resistencia: int = 35
@export_range(0, 999) var destreza: int = 20
@export_range(0, 999) var agilidad: int = 30
@export_range(0, 999) var magia: int = 0

# --- Combate: MULTIPLICADORES de la base COMUN (Game.enemy_base_*) ---
# Por defecto 1.0 = todos los enemigos comparten la misma base; lo que los
# diferencia son sus HABILIDADES. Sube/baja estos para arquetipos (tanque,
# cristal...) sin romper el principio.
@export var base_hp_mult: float = 1.0
@export var base_attack_mult: float = 1.0
@export var base_defense_mult: float = 1.0
@export var base_speed_mult: float = 1.0

# --- Exploracion (mazmorra): velocidad de patrulla/persecucion (franja) ---
@export var move_speed_min: float = 30.0
@export var move_speed_max: float = 55.0

# --- Loot: CATEGORIA del cristal que se le puede extraer (Fase 5) ---
# El cristal sale en una categoria aleatoria dentro de esta franja (mayor
# categoria = mas valioso). La CALIDAD (intacto/dañado/roto) la decide el
# minijuego de extraccion. El slime, p.ej., da categoria 3-5.
@export var crystal_category_min: int = 1
@export var crystal_category_max: int = 3

# --- Extraccion (minijuego, Fase 5) ---
# Pulsaciones base necesarias (slime 3; enemigos avanzados 4-5).
@export var extraction_hits: int = 3
# Destreza "esperada" para este enemigo: el tamaño de la zona escala con
# tu_Destreza / esta. Debiles = bajo (la Destreza luce pronto); dificiles =
# alto (necesitas mas Destreza para que la zona sea comoda).
@export var extraction_req_destreza: int = 60

# --- Drop raro del monstruo (material, Fase 5) ---
@export var drop_name: String = "Material de Slime"
@export var drop_chance: float = 0.02   # 2% normal (en pruebas se fuerza 100%)


# Suma de las habilidades base (sin poder). El slime = 240 ahora mismo.
func suma_habilidades_base() -> int:
	return fuerza + resistencia + destreza + agilidad + magia


# Crea las Abilities, escaladas por el "poder" de ESTE bicho (1.0 = base).
func crear_abilities(power: float = 1.0) -> Abilities:
	var a := Abilities.new()
	a.fuerza = clampi(int(round(fuerza * power)), 0, 999)
	a.resistencia = clampi(int(round(resistencia * power)), 0, 999)
	a.destreza = clampi(int(round(destreza * power)), 0, 999)
	a.agilidad = clampi(int(round(agilidad * power)), 0, 999)
	a.magia = clampi(int(round(magia * power)), 0, 999)
	return a


# Crea el Combatant. La BASE es comun (Game.enemy_base_*) ajustada por el
# multiplicador de arquetipo; las HABILIDADES van escaladas por el poder.
func crear_combatant(power: float = 1.0) -> Combatant:
	return Combatant.new(enemy_name, level, crear_abilities(power),
		Game.enemy_base_hp * base_hp_mult,
		Game.enemy_base_attack * base_attack_mult,
		Game.enemy_base_defense * base_defense_mult,
		Game.enemy_base_speed * base_speed_mult)


# Tira la CATEGORIA del cristal PONDERADA por "t" (0..1 = poder del bicho).
# Metodo "sube de categoria con probabilidad t": t bajo -> categorias bajas;
# t alto -> categorias altas (y las altas salen menos = ponderado natural).
func roll_crystal_category(t: float) -> int:
	var cat := crystal_category_min
	for _i in range(crystal_category_max - crystal_category_min):
		if randf() < t:
			cat += 1
	return cat
