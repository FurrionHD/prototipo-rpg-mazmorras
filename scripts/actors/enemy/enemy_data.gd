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

# --- Combate: nivel + PESOS de distribucion de habilidades ---
# Estos ya NO son valores absolutos: son los PESOS con los que se reparte la SUMA de
# habilidades (que sale de la franja del piso, ver Game.enemy_ability_sum_band y
# EnemyData.crear_abilities). Solo importa su PROPORCION. El slime (40/35/20/30/0)
# tira de Fuerza/Resistencia; un goblin pondria peso alto en Agilidad/Destreza.
@export var level: int = 1
@export_range(0, 999) var fuerza: int = 40
@export_range(0, 999) var resistencia: int = 35
@export_range(0, 999) var destreza: int = 20
@export_range(0, 999) var agilidad: int = 30
@export_range(0, 999) var magia: int = 0

# --- Sub-tramo de la franja del piso que ocupa ESTE arquetipo (0..1) ---
# La suma de habilidades cae en lerp(franja_del_piso, franja_low..franja_high). El
# slime ocupa la parte BAJA (mas flojo); goblins (futuro) la parte alta. Asi en el
# mismo piso conviven enemigos mas y menos fuertes cubriendo toda la franja.
@export_range(0.0, 1.0) var franja_low: float = 0.0
@export_range(0.0, 1.0) var franja_high: float = 0.6

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

# --- ESTADOS ALTERADOS que aplica AL GOLPEAR (KAN-58 Fase 3) ---
# Lista de StatusApplication (cada una con su prob). Un enemigo puede aplicar VARIOS:
# p.ej. el slime venenoso mete Pegajoso Y Veneno. Ver status_application.gd.
@export var al_golpear: Array = []


# Suma total de los PESOS (para normalizar la distribucion).
func peso_total() -> float:
	return float(fuerza + resistencia + destreza + agilidad + magia)


# Sub-franja [min, max] de la SUMA de habilidades para ESTE arquetipo en el piso
# actual = tramo [franja_low, franja_high] de la franja global del piso.
func sum_band() -> Vector2:
	var band: Vector2 = Game.enemy_ability_sum_band(Game.current_floor)
	return Vector2(lerpf(band.x, band.y, franja_low), lerpf(band.x, band.y, franja_high))


# Suma OBJETIVO de habilidades para un 't' (0..1 = posicion dentro de la sub-franja).
func _target_sum(t: float) -> float:
	var sub: Vector2 = sum_band()
	return lerpf(sub.x, sub.y, clampf(t, 0.0, 1.0))


# Crea las Abilities: reparte la suma objetivo (segun 't' y el piso) por los PESOS,
# capando cada stat a 999. El override de debug (200/500/999) manda por encima.
func crear_abilities(t: float = 0.5) -> Abilities:
	var a := Abilities.new()
	if Game.debug_enemy_stat_override >= 0:
		var v: int = clampi(Game.debug_enemy_stat_override, 0, 999)
		a.fuerza = v
		a.resistencia = v
		a.destreza = v
		a.agilidad = v
		a.magia = v
		return a
	var wt: float = peso_total()
	if wt <= 0.0:
		return a  # sin pesos -> todo 0
	var target: float = _target_sum(t)
	a.fuerza = clampi(int(round(target * float(fuerza) / wt)), 0, 999)
	a.resistencia = clampi(int(round(target * float(resistencia) / wt)), 0, 999)
	a.destreza = clampi(int(round(target * float(destreza) / wt)), 0, 999)
	a.agilidad = clampi(int(round(target * float(agilidad) / wt)), 0, 999)
	a.magia = clampi(int(round(target * float(magia) / wt)), 0, 999)
	return a


# Suma REAL de las habilidades (ya distribuidas y capadas). Se usa para la dificultad
# de la extraccion / reto. Deterministica dado 't'.
func suma_habilidades(t: float) -> int:
	var a := crear_abilities(t)
	return a.fuerza + a.resistencia + a.destreza + a.agilidad + a.magia


# Crea el Combatant. Las HABILIDADES salen de la franja del piso (via 't'); la BASE
# (hp/ataque) la escala la PROFUNDIDAD sin techo (obliga a mejorar el equipo). La
# defensa base escala mas suave (raiz) y la velocidad NO (ATB justo).
func crear_combatant(t: float = 0.5) -> Combatant:
	var fstat: float = Game.enemy_floor_stat_factor()
	var c := Combatant.new(enemy_name, level, crear_abilities(t),
		Game.enemy_base_hp * base_hp_mult * fstat,
		Game.enemy_base_attack * base_attack_mult * fstat,
		Game.enemy_base_defense * base_defense_mult * sqrt(fstat),
		Game.enemy_base_speed * base_speed_mult)
	# Estados que aplica al golpear (pegajoso/veneno, KAN-58 Fase 3).
	c.on_hit = al_golpear
	return c


# Tira la CATEGORIA del cristal PONDERADA por "t" (0..1 = poder del bicho).
# Metodo "sube de categoria con probabilidad t": t bajo -> categorias bajas;
# t alto -> categorias altas (y las altas salen menos = ponderado natural).
func roll_crystal_category(t: float) -> int:
	var cat := crystal_category_min
	for _i in range(crystal_category_max - crystal_category_min):
		if randf() < t:
			cat += 1
	return cat
