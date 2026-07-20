# ============================================================
#  enemy_data.gd
#  RECURSO (Resource) con los DATOS de un tipo de enemigo: identidad,
#  habilidades de combate (DanMachi), stats base y datos de exploracion.
#  Se guarda como archivo .tres. Sabe crear su propio Combatant para la
#  pantalla de combate.
# ============================================================

extends Resource
class_name EnemyData

# FAMILIA del bicho: la usan las pasivas "slayer" (mas daño a su familia, menos daño de ella). Es
# una etiqueta APARTE de es_slime (que solo la lee el sequito del Rey). NINGUNA = sin familia (no le
# afecta ningun slayer). BESTIA/HUMANOIDE existen pero aun no tienen slayer (reservadas a futuro).
# Nuevos valores van SIEMPRE al final (los .tres guardan el enum como numero).
enum Familia { NINGUNA, SLIME, ROEDOR, INSECTO, PIEDRA, BESTIA, HUMANOIDE }
@export var familia: Familia = Familia.NINGUNA

# --- Identidad ---
@export var enemy_name: String = "Slime"
@export var color: Color = Color(1.0, 0.2, 0.2)  # color del placeholder
# TAMAÑO en el mapa (fuera de combate): multiplica el cuerpo y su colision. 1.0 = normal
# (32x32). Los ELITES (slimes elementales) van mas grandes para que se les vea venir.
@export var escala_visual: float = 1.0
# FAMILIA slime: marca a toda la estirpe (normal, elementales, profundo, abisal y el propio Rey).
# Lo usa la mecanica de sequito del Rey Slime: cada slime VIVO que le acompañe en combate le da
# reduccion de daño. Aqui es solo la etiqueta; la reduccion la configuran los campos de abajo.
@export var es_slime: bool = false

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
# Magia: no es que el slime CASTEE (no tiene hechizos), es que la Magia es tambien su DEFENSA
# MAGICA. Con peso 0 todos los bichos recibian los hechizos a raw limpio y la magia no podia
# perder nunca. Peso bajo (un slime es tonto), pero que exista y escale con el piso.
@export_range(0, 999) var magia: int = 15

# --- Sub-tramo de la franja del piso que ocupa ESTE arquetipo (0..1) ---
# La suma de habilidades cae en lerp(franja_del_piso, franja_low..franja_high). El
# slime ocupa la parte BAJA (mas flojo); goblins (futuro) la parte alta. Asi en el
# mismo piso conviven enemigos mas y menos fuertes cubriendo toda la franja.
@export_range(0.0, 1.0) var franja_low: float = 0.0
@export_range(0.0, 1.0) var franja_high: float = 0.6


# Color REAL con el que se pinta este bicho: su color base aclarado segun su 't' (los mas
# fuertes de su franja salen mas claros). Lo usan el cuerpo del mapa (enemy.gd) y la UI de
# combate (marcador de la barra de accion), asi el bicho de la barra ES el de la mazmorra.
func color_visual(t: float) -> Color:
	return color.lerp(Color.WHITE, t * 0.45)

# --- Combate: STATS BASE PROPIAS de este enemigo (absolutas, no multiplicadores) ---
# Cada bicho declara las suyas: un minotauro pone 120/9/12/3 y se entiende de un vistazo.
# Los valores por defecto son el baremo del enemigo comun (el slime normal).
# La PROFUNDIDAD las escala encima (ver crear_combatant): vida/ataque x factor_piso,
# defensa x raiz(factor_piso) (mas suave) y la velocidad NO escala (ATB justo).
# OJO: esto es solo la BASE. Encima suman las 5 habilidades del bicho (la Resistencia
# aporta vida y defensa, la Agilidad velocidad...), repartidas por sus PESOS de abajo.
@export var base_hp: float = 28.0
@export var base_attack: float = 3.0
@export var base_defense: float = 3.0
# DEFENSA MAGICA base (espejo de base_defense, pero contra hechizos). Un bicho sin esto recibe
# la magia a raw limpio: los hechizos no los mitigaba NADIE. Un elemental / algo antimagico
# pondria aqui un valor alto; un saco de carne, bajo.
@export var base_magic: float = 3.0
@export var base_speed: float = 4.0

# --- Exploracion (mazmorra): velocidad de MERODEO (franja; cada bicho tira la suya) ---
# Va lenta a proposito: un bicho patrullando no tiene prisa, y asi puedes esquivarlo.
@export var move_speed_min: float = 30.0
@export var move_speed_max: float = 55.0

# Multiplicador de velocidad al PERSEGUIRTE. Merodear y perseguir NO son lo mismo: un
# bicho que te ha visto se lanza. Referencia: el jugador anda a 120 px/s y corre a ~204.
# El slime (30-55 merodeando) persigue a 66-121: el mas rapido te pisa los talones si
# andas, pero corriendo SIEMPRE te escapas. Un bicho agil pondria aqui mas.
@export var chase_speed_mult: float = 2.2

# --- Loot: CATEGORIA del cristal que se le puede extraer (Fase 5) ---
# El cristal sale en una categoria aleatoria dentro de esta franja (mayor
# categoria = mas valioso). La CALIDAD (intacto/dañado/roto) la decide el
# minijuego de extraccion. El slime, p.ej., da categoria 3-5.
@export var crystal_category_min: int = 1
@export var crystal_category_max: int = 3
# PESOS explicitos por categoria, empezando en crystal_category_min (indice 0 = min, 1 = min+1...).
# Si esta vacio se usa la binomial de siempre (crystal_category_min/max ponderado por 't'). Si
# tiene valores, define la distribucion EXACTA de tiers de este bicho (no hace falta que sumen 1).
# Ej. slime normal min=1 weights=(0.8,0.2) -> 80% t1, 20% t2 (nunca t3).
@export var crystal_category_weights: PackedFloat32Array = PackedFloat32Array()

# --- Extraccion (minijuego, Fase 5) ---
# Pulsaciones base necesarias (slime 3; enemigos avanzados 4-5).
@export var extraction_hits: int = 3
# Destreza "esperada" para este enemigo: el tamaño de la zona escala con
# tu_Destreza / esta. Debiles = bajo (la Destreza luce pronto); dificiles =
# alto (necesitas mas Destreza para que la zona sea comoda).
@export var extraction_req_destreza: int = 60

# --- LO QUE SUELTA EL MONSTRUO (aparte del cristal) ---
# Dos tiradas INDEPENDIENTES, una por familia de material (ver MaterialData):
#   - drop_material: el material CORRIENTE del bicho (su baba, su cuero). Va a POCIONES.
#   - nucleo: el NUCLEO. Raro de verdad, y es lo que MEJORA EL EQUIPO.
# Un bicho puede dejar los dos, uno o ninguno. Si un campo esta vacio, ese bicho no lo suelta.
#
# El material corriente NO es un premio raro: es lo que sale de descuartizar un bicho, y las
# pociones se comen muchisimo. Que caiga 3 de cada 10 es lo que hace que la boticaria tenga
# sentido. El NUCLEO si es raro (1 de cada 10): es lo que sube el equipo, y ahi la escasez
# ES el sistema de progresion.
#
# El nucleo estaba al 5%, y con el coste de mejora acumulado que habia, subir un arma al +7
# pedia 13 nucleos de un bicho que sale 1 de cada 50: una cuenta que no terminaba nunca. El
# coste ya se arreglo (Forge.nucleos_para_mejora), y esto es la otra mitad del arreglo.
@export var drop_material: MaterialData = null
@export var drop_chance: float = 0.30   # 3 de cada 10 (en pruebas se fuerza 100%)
# CANTIDAD de drop_material que suelta (una tirada uniforme entre min y max) cuando la tirada de
# drop_chance pasa. Los bichos normales sueltan 1; un jefe puede soltar varias piezas (el
# minotauro deja 2-3 de cuero). Ambos a 1 = comportamiento de siempre.
@export var drop_cantidad_min: int = 1
@export var drop_cantidad_max: int = 1
@export var nucleo: MaterialData = null
@export var nucleo_chance: float = 0.10   # 1 de cada 10

# --- DROP por PROFUNDIDAD ---
# Un bicho soltaba lo mismo en su primer piso que en el ultimo, asi que bajar a por SU material
# no compensaba: farmeabas ratas en el piso 1, donde no te matan, y nunca tenias motivo para
# hundirte. Ahora el drop arranca NERFEADO en el piso donde el bicho debuta y sube hasta el 100%
# en 'drop_piso_pleno'. El pleno va a proposito 1-2 pisos POR DEBAJO del techo de spawn: asi
# queda un tramo en el que ya rinde entero y todavia aparece, en vez de llegar al maximo justo
# cuando deja de salir.
# Los JEFES se libran solos: con debut == pleno el factor sale 1.0 sin ningun caso especial.
@export var drop_piso_debut: int = 1   # primer piso donde aparece
@export var drop_piso_pleno: int = 1   # desde aqui el drop es el 100%

# Cuanto del drop conserva un bicho en su piso de debut. La palanca para suavizar el arranque
# (el 5% de nucleo de la rata del piso 1 sale de aqui): subirlo antes que parchear bichos sueltos.
const DROP_PISO_FACTOR_MIN := 0.5

# Multiplicador de AMBAS chances (material y nucleo) por la profundidad. Interpola igual que
# _target_sum: mismo patron, para no tener dos maneras distintas de escalar con el piso.
func drop_factor_piso(piso: int) -> float:
	if drop_piso_pleno <= drop_piso_debut:
		return 1.0
	var t: float = float(piso - drop_piso_debut) / float(drop_piso_pleno - drop_piso_debut)
	return lerpf(DROP_PISO_FACTOR_MIN, 1.0, clampf(t, 0.0, 1.0))

# --- ESTADOS ALTERADOS que aplica AL GOLPEAR (KAN-58 Fase 3) ---
# Lista de StatusApplication (cada una con su prob). Un enemigo puede aplicar VARIOS:
# p.ej. el slime venenoso mete Pegajoso Y Veneno. Ver status_application.gd.
@export var al_golpear: Array = []

# --- SISTEMA ELEMENTAL (KAN-58) ---
# elemento = afinidad propia (Elementos.Elemento): define su perfil de resist/debilidad por
# defecto (ver elements.gd). resist_elemental = override arbitrario {Elemento: mult} que gana
# a la tabla (un enemigo puede resistir algo sin ser de ese elemento). inmune_estados = ids de
# StatusEffects.Id que NO puede recibir (slime de fuego: [2] = Quemadura).
@export var elemento: int = Elementos.Elemento.NINGUNO
# FRANJA de su afinidad. 1.0 = PURO (el slime de fuego ESTA hecho de fuego: ×0.5 / ×1.5).
# Bajalo para un bicho solo "tocado" por el elemento (p.ej. 0.5 -> ×0.75 / ×1.25).
@export var elemento_intensidad: float = 1.0
@export var resist_elemental: Dictionary = {}
@export var inmune_estados: Array = []
# RASGOS de resistencia (0..1). resist_aturdir: aguante al aturdir/retraso de las contundentes
# (los de piedra apenas se inmutan con el martillo). status_resist: resistencia GENERAL a que le
# prendan estados negativos (veneno, sangrado, debuffs). 0 = normal, 1 = casi inmune.
@export_range(0.0, 1.0) var resist_aturdir: float = 0.0
@export_range(0.0, 1.0) var status_resist: float = 0.0

# --- HABILIDADES del enemigo (Array[AbilityData]) ---
# Tecnicas que puede lanzar en combate ademas del ataque basico (multi-golpe, estados,
# cargas...). Cada turno tira una tirada: con prob_habilidad usa una habilidad LISTA (fuera
# de cooldown) al azar; si no, ataca normal. Los cooldowns por habilidad + esta probabilidad
# evitan que encadene todas las tecnicas seguidas. Vacio = solo ataque basico (como antes).
@export var habilidades: Array = []
@export_range(0.0, 1.0) var prob_habilidad: float = 0.5

# --- SUBIR DE NIVEL ---
# Si es > 0, este enemigo es el "guardián del rango" de ESE nivel: vencerlo desbloquea poder subir
# a ese nivel (junto con tener rango C en alguna habilidad, ver Game.puede_subir_nivel). 0 = no lo es.
@export var nivel_que_otorga: int = 0

# --- SEQUITO (mecanica del Rey Slime, jefe del piso 6) ---
# Por cada slime VIVO que acompañe a ESTE enemigo en el combate, reduce el daño DIRECTO que
# recibe (magia y golpes; el DoT de veneno/quemadura pega limpio). Acumulativo hasta el tope.
# 0 = sin mecanica (todos los bichos salvo el Rey). El Rey pone 0.10 por slime, tope 0.30
# (3 secuaces × 10%). Se recalcula en cada golpe segun los slimes vivos en ese instante, asi
# que matar al sequito baja el escudo al momento. Ver Combatant._reduccion_sequito.
@export_range(0.0, 1.0) var sequito_reduccion_por_slime: float = 0.0
@export_range(0.0, 1.0) var sequito_reduccion_max: float = 0.0


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
# capando cada stat a 999. Encima, el panel de DEBUG puede pisar stats SUELTAS
# (Game.debug_enemy_override): las que no toque se quedan en su valor natural.
func crear_abilities(t: float = 0.5) -> Abilities:
	var a := Abilities.new()
	var wt: float = peso_total()
	if wt > 0.0:
		var target: float = _target_sum(t)
		a.fuerza = clampi(int(round(target * float(fuerza) / wt)), 0, 999)
		a.resistencia = clampi(int(round(target * float(resistencia) / wt)), 0, 999)
		a.destreza = clampi(int(round(target * float(destreza) / wt)), 0, 999)
		a.agilidad = clampi(int(round(target * float(agilidad) / wt)), 0, 999)
		a.magia = clampi(int(round(target * float(magia) / wt)), 0, 999)
	# DEBUG: pisa solo las stats que el panel haya fijado.
	for clave in Game.debug_enemy_override:
		a.set(clave, clampi(int(Game.debug_enemy_override[clave]), 0, 999))
	return a


# Suma REAL de las habilidades (ya distribuidas y capadas). Se usa para la dificultad
# de la extraccion / reto. Deterministica dado 't'.
func suma_habilidades(t: float) -> int:
	var a := crear_abilities(t)
	return a.fuerza + a.resistencia + a.destreza + a.agilidad + a.magia


# Crea el Combatant. Las HABILIDADES salen de la franja del piso (via 't'); las STATS
# BASE son las PROPIAS de este enemigo y las escala la PROFUNDIDAD sin techo (obliga a
# mejorar el equipo). La defensa escala mas suave (raiz) y la velocidad NO (ATB justo).
func crear_combatant(t: float = 0.5) -> Combatant:
	var fstat: float = Game.enemy_floor_stat_factor()
	var c := Combatant.new(enemy_name, level, crear_abilities(t),
		base_hp * fstat,
		base_attack * fstat,
		base_defense * sqrt(fstat),
		base_speed)
	# Defensa MAGICA: escala con la profundidad igual (raiz) que la fisica, para que la magia
	# no se despegue del resto a medida que bajas de piso.
	c.base_magic = base_magic * sqrt(fstat)
	# Estados que aplica al golpear (pegajoso/veneno, KAN-58 Fase 3).
	c.on_hit = al_golpear
	# Habilidades del enemigo (KAN-58): tecnicas que puede lanzar en combate.
	c.habilidades = habilidades
	c.prob_habilidad = prob_habilidad
	# Sistema elemental (KAN-58): afinidad, overrides de resistencia e inmunidad a estados.
	c.elemento = elemento
	c.elemento_intensidad = elemento_intensidad
	c.resist_elemental = resist_elemental
	c.inmune_estados = inmune_estados
	# Rasgos de resistencia (piedra = aguanta stuns; alien = aguanta debuffs).
	c.stun_resist = resist_aturdir
	c.status_resist = status_resist
	# Familia del bicho (para las pasivas slayer del jugador).
	c.familia = int(familia)
	# Sequito (Rey Slime): etiqueta de familia + config de la reduccion de daño por acompañantes.
	c.es_slime = es_slime
	c.sequito_reduccion_por_slime = sequito_reduccion_por_slime
	c.sequito_reduccion_max = sequito_reduccion_max
	# Sus GOLPES van de su elemento (el slime de fuego pega fuego). Ojo: un bicho que resista
	# fuego por un override (minotauro peludo) tiene elemento NINGUNO -> sus golpes NO son de fuego.
	c.elemento_ataque = elemento
	# Con que color se le ve: viaja en el Combatant porque la UI de combate solo recibe
	# Combatants (no el EnemyData), y necesita pintar su marcador en la barra de accion.
	c.color_visual = color_visual(t)
	return c


# Tira la CATEGORIA del cristal. Si hay PESOS explicitos (crystal_category_weights), sortea con
# ellos (distribucion fija de este bicho, empezando en crystal_category_min). Si no, cae a la
# binomial ponderada por "t": t bajo -> categorias bajas; t alto -> altas (las altas salen menos).
func roll_crystal_category(t: float) -> int:
	if not crystal_category_weights.is_empty():
		var total: float = 0.0
		for w in crystal_category_weights:
			total += maxf(0.0, w)
		if total > 0.0:
			var r: float = randf() * total
			for i in range(crystal_category_weights.size()):
				r -= maxf(0.0, crystal_category_weights[i])
				if r < 0.0:
					return crystal_category_min + i
		return crystal_category_min + crystal_category_weights.size() - 1
	var cat := crystal_category_min
	for _i in range(crystal_category_max - crystal_category_min):
		if randf() < t:
			cat += 1
	return cat
