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


# Suma de las habilidades base (sin poder).
func suma_habilidades_base() -> int:
	return fuerza + resistencia + destreza + agilidad + magia


# Suma de las habilidades YA escaladas por el poder y CAPADAS a 999 c/u
# (poder de combate REAL, maximo 4995). Se usa para dificultad/reto/loot,
# asi coincide con lo que de verdad tiene el enemigo en combate.
func suma_habilidades(power: float) -> int:
	return clampi(int(round(fuerza * power)), 0, 999) \
		+ clampi(int(round(resistencia * power)), 0, 999) \
		+ clampi(int(round(destreza * power)), 0, 999) \
		+ clampi(int(round(agilidad * power)), 0, 999) \
		+ clampi(int(round(magia * power)), 0, 999)


# Crea las Abilities, escaladas por el "poder" de ESTE bicho (1.0 = base).
func crear_abilities(power: float = 1.0) -> Abilities:
	var a := Abilities.new()
	# DEBUG: si el panel forzo un valor plano, ignora las stats del .tres y el poder
	# (presets 200 / 500 / 999). -1 = comportamiento normal.
	if Game.debug_enemy_stat_override >= 0:
		var v: int = clampi(Game.debug_enemy_stat_override, 0, 999)
		a.fuerza = v
		a.resistencia = v
		a.destreza = v
		a.agilidad = v
		a.magia = v
		return a
	# La PROFUNDIDAD (piso) escala las habilidades ademas del poder del bicho. Sigue
	# capado a 999 por stat (el escalado "sin techo" lo llevan las stats BASE, no las
	# habilidades). A piso 1 el factor es 1.0 (identico a hoy).
	var p: float = power * Game.enemy_floor_ability_factor()
	a.fuerza = clampi(int(round(fuerza * p)), 0, 999)
	a.resistencia = clampi(int(round(resistencia * p)), 0, 999)
	a.destreza = clampi(int(round(destreza * p)), 0, 999)
	a.agilidad = clampi(int(round(agilidad * p)), 0, 999)
	a.magia = clampi(int(round(magia * p)), 0, 999)
	return a


# Crea el Combatant. La BASE es comun (Game.enemy_base_*) ajustada por el
# multiplicador de arquetipo; las HABILIDADES van escaladas por el poder.
# La PROFUNDIDAD (piso) escala las stats BASE de vida/ataque SIN techo: es lo que
# obliga a mejorar el RAW del arma (tier) y la DEF de la armadura (tier), porque tu
# Fuerza satura en 999. La defensa base escala mas suave (raiz) y la velocidad NO
# (mantiene el ATB justo). A piso 1 el factor es 1.0 (identico a hoy).
func crear_combatant(power: float = 1.0) -> Combatant:
	var fstat: float = Game.enemy_floor_stat_factor()
	return Combatant.new(enemy_name, level, crear_abilities(power),
		Game.enemy_base_hp * base_hp_mult * fstat,
		Game.enemy_base_attack * base_attack_mult * fstat,
		Game.enemy_base_defense * base_defense_mult * sqrt(fstat),
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
