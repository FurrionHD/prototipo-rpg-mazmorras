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
# LORE del enemigo, para la pestaña "Historia" de la ficha de detalle en combate. Vacio = la
# ficha muestra "Sin historia todavia." Es SABOR: nunca cifras (ver la regla de no hardcodear
# numeros en los textos). Terminologia propia del juego, sin referencias externas.
@export_multiline var historia: String = ""
@export var color: Color = Color(1.0, 0.2, 0.2)  # color del placeholder
# TAMAÑO en el mapa (fuera de combate): multiplica el cuerpo y su colision. 1.0 = normal
# (32x32). Los ELITES (slimes elementales) van mas grandes para que se les vea venir.
@export var escala_visual: float = 1.0
# SPRITE ANIMADO real (arte de verdad, aun por hacer para casi todos los bichos). Si esta vacio,
# enemy.gd cae al ColorRect de siempre -- salvo los slimes, que mientras tanto usan un sprite
# GENERADO por codigo (ver SlimeSprites.generar()). En cuanto este campo se rellene con arte de
# verdad, gana el a lo generado sin tocar enemy.gd.
@export var sprite_frames: SpriteFrames = null
# CORONA en vez de orejas en el sprite generado (solo aplica si es_slime y no hay sprite_frames de
# verdad): el Rey Slime la lleva hecha de su propio gel (ver SlimeSprites._corona_para). false = las
# dos orejitas de un slime normal.
@export var corona_slime: bool = false
# VARIANTE del sprite generado, para los bichos que tienen una version "especial" del mismo dibujo
# (hoy: &"rey" en el Rey Rata, que lleva la cola anudada y una oreja rasgada). Es una etiqueta
# generica a proposito: el generador de cada familia decide que hace con ella, asi no hace falta un
# booleano nuevo en esta ficha por cada bicho que estrene un adorno.
@export var sprite_variante: StringName = &""
# QUE GENERADOR le dibuja, cuando no basta con su familia. Vacio = se despacha por familia, que es lo
# normal y lo que hacen slimes y roedores (ver SpritesEnemigo.GENERADORES).
#
# Hace falta porque la familia es una etiqueta de JUEGO, no de dibujo, y hay familias con bichos que
# no se parecen en nada: BESTIA son el Jabali y el Acechador de las simas, y NINGUNA son el Trent y
# la Aberracion. Despachando solo por familia, el Acechador saldria con forma de jabali.
@export var sprite_gen: StringName = &""
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

# --- Sub-tramo de la franja del piso que ocupa ESTE arquetipo ---
# La suma de habilidades cae en lerp(franja_del_piso, franja_low..franja_high). El
# slime ocupa la parte BAJA (mas flojo); goblins (futuro) la parte alta. Asi en el
# mismo piso conviven enemigos mas y menos fuertes cubriendo toda la franja.
#
# EL TOPE PASA DE 1.0 porque los JEFES pueden salirse de la franja del piso por arriba: son la
# excepcion del piso, no un bicho mas. Hasta el 19/08/2026 los dos (Rey Slime y Guardian de rango)
# tenian franja_low = franja_high = 1.0, o sea CERO variacion -- eran los unicos del juego que
# salian siempre identicos, cuando hasta el mini-jefe Rey Rata baila entre 0.2 y 0.7. Ahora van a
# 0.85-1.05: casi siempre rondan lo de antes y de vez en cuando sale uno que da miedo.
#
# El rango del @export tiene que dar de si para eso: con (0.0, 1.0) el inspector recortaba el 1.05
# a 1.0 en cuanto alguien abriera la ficha, y la variacion se perdia sin que nadie tocara nada.
@export_range(0.0, 1.2) var franja_low: float = 0.0
@export_range(0.0, 1.2) var franja_high: float = 0.6

# EN MEDIO DE LA FILA, SIEMPRE. Los JEFES no hacen cola con su propio séquito: el Rey Slime invoca
# lanzando bolas a los lados y luego se desplazaba él, porque los invocados entran en el primer
# hueco libre y la fila se recolocaba. Con esto su tarjeta se lleva al centro pase lo que pase con
# el array (ver combat.gd._ordenar_fila_enemigos).
#
# Es SOLO colocacion: el array no se toca, porque los codigos de red son sus indices. Lo que sí se
# ajusta es la adyacencia de la fila enemiga, que pasa a ir por el orden de PANTALLA -- si no, lo
# que ves al lado y a lo que salpica tu hechizo dejarian de ser lo mismo.
@export var centrado_en_fila: bool = false

# COMO PEGA ESTE BICHO cuando no usa habilidad (un CombatFX.Estilo; -1 = el empujon de tarjeta de
# siempre). Las habilidades ya piden su dibujo con AbilityData.fx_estilo, pero el ataque basico no
# pasa por ninguna habilidad: sin esto una rata solo muerde cuando le sale la tecnica y el resto de
# turnos da el mismo empujon que un esqueleto. Aqui se pone COMO ATACA EL BICHO, que suele ser una
# sola cosa (la rata muerde, el acechador desgarra), y las habilidades lo afinan por encima.
@export var fx_basico: int = -1


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
# Subido del 10% al 15% tras medir la curva: con el 10% y el nerf por profundidad, subir una
# pieza de armadura de +3 a +5 pedia ~70 muertes, y el set entero ~350. El nucleo tiene que ser
# escaso (es EL sistema de progresion), pero escaso no es lo mismo que interminable.
@export var nucleo_chance: float = 0.15   # ~1 de cada 7

# --- TERCERA tirada: el drop de COCINA/CONSUMO ---
# Ni material de pociones ni nucleo de mejora: es lo que se le saca al bicho para COMER (hoy la
# carne, una POR BICHO: rata, jabali, insecto y bestia). Va en su propio slot y no en
# drop_material por dos razones:
#   - un bicho ya usa drop_material para su piel: la carne es OTRA cosa que cae A LA VEZ.
#   - es una economia aparte. La comida se gasta por TIEMPO (un plato dura 20 min), no por pieza
#     de equipo, asi que su escasez no se calibra contra la forja.
# El campo es GENERICO a proposito: el motor no sabe que esto es "carne".
@export var drop_extra: MaterialData = null
@export var drop_extra_chance: float = 0.05
@export var drop_extra_min: int = 1
@export var drop_extra_max: int = 1

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

# Cuanto del drop conserva un bicho en su piso de debut. OJO con lo que ESTA palanca hace y lo
# que no: solo mueve los pisos SUPERFICIALES de cada bicho (en su piso pleno el factor ya es 1.0,
# la toques o no). Para aflojar la economia entera hay que ir al nucleo_chance, no aqui.
# Al 0.6, el nucleo de la banda inicial queda al 9% en el piso 1: casi el 10% plano de antes, que
# es lo que se quiere. El incentivo a bajar no sale de racanear el nucleo de principiante, sale
# de QUE nucleo suelta cada bicho (la banda de mejora que cubre).
const DROP_PISO_FACTOR_MIN := 0.6

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
# RASGOS de resistencia. resist_aturdir: aguante EXTRA al control (aturdir/miedo) por encima de su
# resistencia general -- los de piedra apenas se inmutan con el martillo.
#
# status_resist y eficacia son AJUSTES SOBRE LA CURVA DEL PISO, no valores absolutos: lo que sale de
# la profundidad (Enemigos.RESIST_POR_PISO) se multiplica por esto. 1.0 = lo normal de su piso; 1.6 =
# un jefe, que aguanta y aplica bastante mejor que la morralla que lo acompaña; 0.7 = un bicho
# blando. Asi los pisos nuevos escalan solos y solo hay que tocar el .tres de los que deban salirse.
#
# Antes status_resist era un 0..1 absoluto y casi ningun .tres lo ponia: el resultado era que un Rey
# Slime resistia los estados EXACTAMENTE igual que la rata del piso 1, o sea nada, y por eso dos
# aturdimientos le borraban el kit entero.
@export_range(0.0, 1.0) var resist_aturdir: float = 0.0
@export_range(0.0, 4.0) var status_resist: float = 1.0
@export_range(0.0, 4.0) var eficacia: float = 1.0

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
# ============================================================
#  RESISTENCIA A EFECTOS / EFICACIA POR PROFUNDIDAD
# ============================================================
# Los dos ejes del sistema de estados escalan con el piso, y no es adorno: sin esto, un veneno que
# entra al 60% en el piso 1 entra al 60% en el 12, y una armadura de tier 2 a +9 volvia al jugador
# intocable por los estados de todo lo que hay abajo.
#
# CALIBRADO contra los hitos de equipo reales (los dio el usuario):
#   piso 1  -> una o dos piezas sueltas, sin mejorar   -> tu resistencia ~0.15 (solo la de la carne)
#   piso 2  -> armadura completa, alguna al +1         -> ~0.30
#   piso 6  -> completa, entre +6 y +9                 -> ~0.73  (con escudo)
#   piso 12 -> tier 2 completa, entre +6 y +9          -> ~0.90
# y tu EFICACIA, que sale del arma (rareza + nivel de mejora):
#   piso 1 ~0.00   ·   piso 6 ~0.40   ·   piso 12 ~0.56
#
# De ahi salen los dos pasos: la resistencia del bicho persigue a tu eficacia (para que meterle
# estados no se vuelva automatico segun te equipas) y su eficacia persigue a tu resistencia (para
# que sus venenos sigan doliendo abajo). En los dos casos el jugador va ligeramente por delante si
# se especializa, que es lo que tiene que premiar especializarse.
# Los dos pasos van POR DEBAJO de lo que crece el jugador, y eso es deliberado: si el bicho escalara
# al mismo ritmo que tu equipo, mejorar la armadura no se notaria NUNCA (el clasico treadmill), y con
# un primer tanteo a 0.05/0.075 salia todavia peor -- en el piso 12 el veneno te entraba MAS que en el
# 6, o sea que subir de tier te perjudicaba. Medido con la tabla de hitos:
#   veneno del bicho sobre ti:  piso 1 ~52%  ->  piso 6 ~44%  ->  piso 12 ~42%
#   tu aturdir sobre un bicho:  piso 1  25%  ->  piso 6  27%  ->  piso 12  28%
# O sea: quien mantiene su equipo al dia GANA terreno poco a poco por los dos lados, y quien baja con
# el equipo de hace tres pisos lo pierde. Nadie se vuelve inmune por el camino.
const RESIST_POR_PISO := 0.035    # piso 1 -> 0.00 ; piso 6 -> 0.18 ; piso 12 -> 0.39
const EFICACIA_POR_PISO := 0.03   # piso 1 -> 0.00 ; piso 6 -> 0.15 ; piso 12 -> 0.33

static func resist_de_piso(piso: int) -> float:
	return maxf(0.0, float(piso - 1)) * RESIST_POR_PISO

static func eficacia_de_piso(piso: int) -> float:
	return maxf(0.0, float(piso - 1)) * EFICACIA_POR_PISO


# ============================================================
#  MUTANTES  (los "mini-jefes")
# ============================================================
# CUALQUIER enemigo puede nacer MUTANTE, con una probabilidad pequeña y la misma para todos. No es
# un bicho aparte con su .tres: es el mismo de siempre, mas grande y mucho mas bruto.
#
# Va asi y no como "un enemigo raro concreto por piso" porque de esta forma el juego entero tiene
# mini-jefes desde el piso 1 sin escribir un solo enemigo nuevo, y cada familia hereda los suyos
# sola: la rata mutante pelea como una rata (te sangra, es rapida) y el golem mutante como un golem.
# Encontrarte uno es un acontecimiento y una decision -- pelearlo o rodearlo -- y no otro bicho mas
# de la lista.
#
# UN JEFE DE PISO TAMBIEN PUEDE MUTAR, pero con multiplicadores MUCHO mas suaves (MUT_JEFE_*). Un
# jefe ya es el tope de su piso: aplicarle el x2.6 de vida de la morralla lo volveria imposible POR
# SORTEO -- te tocaria un muro infranqueable o no, sin que tu hubieras hecho nada distinto. Con los
# suaves sigue siendo el mismo jefe, una version dura, y ese es el punto.
const MUTANTE_PROB := 0.01        # 1 de cada 100 bichos que nacen, jefes incluidos

# Los multiplicadores, sobre lo que ese mismo bicho seria en ese mismo piso. AGUANTE muy arriba y
# daño arriba pero menos: la gracia es que sea un muro que te obliga a sostener la pelea, no que te
# reviente de un golpe (con el daño x2.6 seria el bicho lo mataria a uno del grupo antes de que te
# diera tiempo a decidir si te vas).
const MUT_HP := 2.60
const MUT_ATAQUE := 1.45
const MUT_DEFENSA := 1.60
# Resiste y mete estados como si fuera de bastante mas abajo: un mutante al que le entra todo a la
# primera no da ninguna sensacion de mini-jefe.
const MUT_ESTADOS := 1.50
# Se ve MAS GRANDE, que es el aviso honesto: hay que poder decidir si lo peleas ANTES de tocarlo.
# x1.2 sobre la escala que YA tenga ese bicho, no un tamaño fijo: asi el rey rata mutante sigue
# siendo mas grande que una rata mutante. Se estira el sprite que ya hay y no se dibuja uno nuevo:
# es la excepcion consciente a lo de cuadrar los pixeles, porque un mutante es cualquiera de los
# veinte enemigos del juego y serian veinte sprites para decir lo mismo que dice el tinte.
const MUT_ESCALA := 1.20
# Lo que suelta un mutante, sobre lo que soltaria ese mismo bicho normal.
const MUT_BOTIN := 2.0
# Lo que cuenta como RETO para la excelia. No es la media de los multiplicadores de arriba sino lo
# que cuesta tumbarlo de verdad: aguanta casi tres veces mas turnos y en cada uno pega mas y encaja
# menos. Se queda por debajo del x2 a proposito -- un mini-jefe entrena mejor que un bicho normal,
# pero farmearlos no puede ser la via rapida para saltarse la curva de un piso.
const MUT_PODER := 1.70

# --- LOS MISMOS, PARA UN JEFE DE PISO ---
# Un jefe mutante existe (lo pidio el usuario: "que si que pueda salir pero que sea menos
# busteado"), y va con su propia tabla por una razon de proporciones: el jefe ya viene con la vida y
# el daño del techo de su piso, asi que el mismo x2.6 que hace interesante a una rata lo convierte
# en un muro que no se puede tumbar con el equipo con el que se supone que llegas.
#
# Los numeros los dio el usuario (vida x1.65, ataque x1.15) y el resto se escala en la misma
# proporcion respecto a la tabla normal, para que la sensacion sea la misma en menor grado.
const MUT_JEFE_HP := 1.65
const MUT_JEFE_ATAQUE := 1.15
const MUT_JEFE_DEFENSA := 1.20
const MUT_JEFE_ESTADOS := 1.20
# Se agranda menos: un jefe ya es enorme de fabrica y un x1.2 encima se le sale de la sala. Con el
# tinte, el aura y el latido se sigue viendo perfectamente que ese jefe viene torcido.
const MUT_JEFE_ESCALA := 1.10
const MUT_JEFE_BOTIN := 1.5
const MUT_JEFE_PODER := 1.35


# Los multiplicadores de la mutacion, segun sea un bicho corriente o el JEFE del piso. En un dict y
# no en seis ifs sueltos porque los usan cuatro sitios distintos (las stats, el botin, el cristal y
# la excelia) y separarlos es como se acaba con el jefe llevando el aguante del uno y el botin del
# otro.
static func mult_mutante(es_jefe: bool) -> Dictionary:
	if es_jefe:
		return {"hp": MUT_JEFE_HP, "atk": MUT_JEFE_ATAQUE, "def": MUT_JEFE_DEFENSA,
			"est": MUT_JEFE_ESTADOS, "escala": MUT_JEFE_ESCALA, "botin": MUT_JEFE_BOTIN,
			"poder": MUT_JEFE_PODER}
	return {"hp": MUT_HP, "atk": MUT_ATAQUE, "def": MUT_DEFENSA, "est": MUT_ESTADOS,
		"escala": MUT_ESCALA, "botin": MUT_BOTIN, "poder": MUT_PODER}


# Como se llama en la barra de combate y en el log. "mutante" y no "mutado/a" a proposito: es
# invariable en genero, asi que vale para la rata y para el slime sin una tabla de excepciones (y
# el dia que haya un bicho con nombre compuesto tampoco hay que tocar nada).
func nombre_mostrado(mutante: bool = false) -> String:
	return ("%s mutante" % enemy_name) if mutante else enemy_name


func crear_combatant(t: float = 0.5, mutante: bool = false, es_jefe: bool = false) -> Combatant:
	var fstat: float = Game.enemy_floor_stat_factor()
	# 'es_jefe' solo se usa para elegir la TABLA de multiplicadores (un jefe mutante va mucho mas
	# suave, ver mult_mutante). Sin mutacion no cambia nada, asi que pasarlo de mas es inofensivo.
	var mm: Dictionary = mult_mutante(es_jefe)
	var m_hp: float = float(mm["hp"]) if mutante else 1.0
	var m_atk: float = float(mm["atk"]) if mutante else 1.0
	var m_def: float = float(mm["def"]) if mutante else 1.0
	var c := Combatant.new(nombre_mostrado(mutante), level, crear_abilities(t),
		base_hp * fstat * m_hp,
		base_attack * fstat * m_atk,
		base_defense * fstat * m_def,
		base_speed)
	# Defensa MAGICA: escala con la profundidad igual (raiz) que la fisica, para que la magia
	# no se despegue del resto a medida que bajas de piso.
	c.base_magic = base_magic * sqrt(fstat) * m_atk
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
	# RESISTENCIA A EFECTOS Y EFICACIA: la curva del PISO por el ajuste de ESTE bicho. Los dos ejes
	# hacen falta y hacen cosas distintas: la resistencia decide lo que TE aguanta, la eficacia lo
	# bien que TE mete a ti sus venenos y aturdimientos.
	var m_est: float = float(mm["est"]) if mutante else 1.0
	c.status_resist = resist_de_piso(Game.current_floor) * status_resist * m_est
	c.eficacia = eficacia_de_piso(Game.current_floor) * eficacia * m_est
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
	c.centrado_en_fila = centrado_en_fila
	# De donde saldra su sprite en la pantalla de combate. Se guarda la RUTA y la 't', que juntas
	# identifican la variante exacta (ver SpritesEnemigo.clave_de): la misma que se ve en el mapa.
	c.sprite_res = resource_path
	c.sprite_t = t
	c.fx_basico = fx_basico
	c.mutante = mutante
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
