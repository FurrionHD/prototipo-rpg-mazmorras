# ============================================================
#  game.gd  (AUTOLOAD: se llama "Game" y esta disponible en todo el juego)
#  - Guarda las stats del JUGADOR (persisten entre combates, incluida la vida).
#  - Abre la pantalla de combate ENCIMA de la mazmorra (overlay) y pausa el
#    resto del juego mientras dura. Al terminar, reanuda y, si ganaste,
#    elimina al enemigo de la mazmorra.
# ============================================================

extends Node

# --- Stats del jugador (de momento fijas aqui; luego vendran de su .tres) ---
var player_level: int = 1
# Habilidades VISIBLES (las que usa el combate/capacidad). Empiezan a 0 y solo
# se actualizan al "volver al hogar" (tecla U -> actualizar_estado()).
var player_fuerza: int = 0
var player_resistencia: int = 0
var player_destreza: int = 0
var player_agilidad: int = 0
var player_magia: int = 0
var player_base_hp: float = 50.0
var player_base_attack: float = 5.0
var player_base_defense: float = 5.0
# Defensa MAGICA base del jugador (espejo de la fisica). Hoy no la usa nadie porque los
# enemigos aun no lanzan hechizos, pero el dia que lo hagan no queremos que el jugador este
# desnudo ante la magia como lo estaban ellos. Ver StatsMath.resolve_spell.
var player_base_magic: float = 5.0
var player_base_speed: float = 5.0
# Vida actual (persiste entre combates). -1 = aun no inicializada (= llena).
var player_current_hp: float = -1.0
# Mana actual (persiste entre combates, como la vida). -1 = lleno. Se rellena en
# el altar (descansar) y regenera muy poco por turno en combate (KAN-56).
var player_current_mp: float = -1.0

# --- Subida de habilidades (Excelia estilo DanMachi) ---
# Valor INTERNO (float) que sube con el uso. Lo visible (player_*) solo se
# sincroniza al "actualizar estado" (hogar). Rendimientos decrecientes segun
# el interno; dificultad relativa (enemigo/accion facil = sube poco).
var ability_internal: Dictionary = {
	"fuerza": 0.0, "resistencia": 0.0, "destreza": 0.0, "agilidad": 0.0, "magia": 0.0}
# Rendimientos decrecientes RELATIVOS AL TOPE: subes bien casi todo el camino
# y frena cerca de 999, pero con un SUELO para que nunca sea imposible.
# factor = max(FLOOR, (1 - interno/999)^POWER).
const ABILITY_CAP := 999.0
const DIMINISH_POWER := 0.8        # <1 = curva mas suave (aguanta mas arriba)
const DIMINISH_FLOOR := 0.15       # suelo: cerca de 999 sigues subiendo (lento, no 0)
const RETO_MAX := 8.0              # tope de dificultad relativa (enemigo muy superior = mas ganancia)
# Tope de reto SOLO para las stats FISICAS (Fuerza/Resistencia/Agilidad): mas
# bajo que el de Destreza (8) para que no se disparen contra enemigos superiores.
const RETO_MAX_FISICO := 5.0
# Suelo de PODER del jugador (solo lo usa reto() -> stats fisicas). A nivel 0 tu
# poder real es ~0; este suelo evita que CUALQUIER bicho te parezca amenaza
# maxima al arrancar (con 40, el slime por defecto de 125 da reto ~3, graduado).
# OJO: el minijuego de Destreza usa OTRO piso (EXTRACTION_DESTREZA_FLOOR), aparte.
const PODER_JUGADOR_SUELO := 40.0
# Ganancias base por fuente (ajustables).
const GAIN_FUERZA_ATAQUE := 0.15
const GAIN_FUERZA_PESO := 0.0    # DESACTIVADA por ahora (rediseñar sin romper escalado)
const GAIN_AGILIDAD_CORRER := 0.12
const GAIN_RESISTENCIA_GOLPE := 0.23
# DESTREZA: ya NO se entrena en un solo sitio. La extraccion del cristal la comparte ahora
# con la herboristeria, asi que el total (2.0) se reparte entre las dos y ninguna sube sola
# la curva entera. La planta pesa un pelin mas POR PIEZA porque es mas escasa y menos
# perdonable (una sola pasada por tallo); el cristal cae de cada bicho que matas.
const GAIN_DESTREZA_MINIJUEGO := 0.9  # extraccion del cristal (era 2.2, cuando era la unica fuente)
const GAIN_DESTREZA_PLANTA := 1.1     # herboristeria (hoz)
# FUERZA: la mineria es la primera fuente de Fuerza que no es pegarse con algo.
const GAIN_FUERZA_MINERIA := 0.9
# Fuentes de COMBATE para las stats que se farmean mal (bases altas: son eventos
# raros, no ocurren cada turno como el ataque):
const GAIN_AGILIDAD_ESQUIVAR := 0.6   # esquivar un golpe entrena Agilidad (adios correr en circulos)
const GAIN_AGILIDAD_CRITICO := 0.3    # clavar un critico entrena Agilidad (encontrar el hueco)
const GAIN_RESISTENCIA_BLOQUEO := 0.3 # bloquear con Defender entrena Resistencia extra (KAN-81); moderado para no sobre-premiar el escudo
# Magia (KAN-56): entrena SOLO al LANZAR el hechizo (no por frase, para que sea
# predecible). Formula dedicada = GAIN_MAGIA_CAST × mana_factor × reto(enemigo),
# con tope de reto FISICO (5) y rendimientos decrecientes por la Magia interna.
# mana_factor = coste_mana / MAGIA_COSTE_REF -> hechizos caros entrenan mas (ya
# reflejan mas daño/potencia). Contra un slime: Chispa ~1.5, Bola ~3, Tormenta ~5.
const GAIN_MAGIA_CAST := 0.4
const MAGIA_COSTE_REF := 4.0   # coste de referencia (Chispa) para el factor de mana
# --- Dificultad de la extraccion ---
# Exigencia del enemigo = suma_habilidades x FACTOR. Dificultad relativa =
# exigencia / (tu Destreza + SUELO). ~1 = a la par; >1 mas dificil. La
# dificultad hace la zona mas pequeña Y el marcador mas rapido.
const EXTRACTION_REQ_FACTOR := 0.25
const EXTRACTION_BASE_ZONE := 0.16      # tamaño de zona a dificultad 1
const EXTRACTION_DESTREZA_FLOOR := 20.0 # skill base minimo (bajo: el novato SI sufre)
const EXTRACTION_BASE_MARKER := 0.55    # velocidad del marcador a dificultad 1
# TECHO de la velocidad del marcador (recorridos de la barra por segundo).
#
# Es el minijuego mas VIEJO y el unico que no tenia tope: la dificultad lo aceleraba, el piso
# lo aceleraba, y ademas CADA ACIERTO lo acelera otra vez (speed_step). Con la barra midiendo
# ~1150 px, a 0.8 ya iban ~920 px/s, y tras un par de aciertos se ponia en el doble: a esas
# velocidades el marcador salta decenas de pixeles por frame y se ve BORROSO por muchos FPS
# que haya (a 144 estables seguia sin verse nitido). Lo dificil tiene que ser acertar en una
# zona ESTRECHA, no perseguir con la vista algo que ya no se puede seguir.
const EXTRACTION_MARKER_MAX := 1.1
# Pivote para la GANANCIA de Destreza: solo aprendes de verdad si la extraccion
# fue dura PARA TI. Por debajo de este reto la ganancia cae en picado (curva ^2);
# por encima se mantiene. Sube el pivote para castigar mas las extracciones
# faciles (experto sacando de bichos flojos ~0); bajalo para lo contrario.
const EXTRACTION_DESTREZA_PIVOTE := 1.5
# Por ENCIMA del pivote la Destreza SIGUE subiendo con el reto (extraccion
# durisima = novato vs bicho superior = mucha mas Destreza), pero COMPRIMIDA por
# esta pendiente para no dispararse, y con un tope PROPIO mas alto que el global
# RETO_MAX (una extraccion brutal enseña mucho mas que una "solo dificil").
const EXTRACTION_DESTREZA_SLOPE := 0.65
const EXTRACTION_DESTREZA_RETO_MAX := 8.0

# --- RECOLECCION: dificultad de los dos minijuegos ---
# Misma idea que la extraccion (dificultad RELATIVA: lo que exige el material contra la
# stat que lo trabaja), pero cada actividad mira SU stat: la veta pide FUERZA, la planta
# pide DESTREZA. La profundidad endurece el material (roca mas apretada, tallos mas secos).
const RECOLECCION_PISO_FACTOR := 1.08   # exigencia x1.08 por piso

# MINERIA (pico, Fuerza). La Fuerza ensancha la franja optima Y la baja: un brazo fuerte
# rompe la veta sin tener que cargar el pico hasta arriba.
const MINERIA_FUERZA_FLOOR := 20.0      # suelo de skill (el novato SI sufre)
const MINERIA_BASE_VENTANA := 0.22      # ancho de la franja optima a dificultad 1
const MINERIA_BASE_CARGA := 1.0         # velocidad de la barra de carga a dificultad 1
# TECHO de la barra de carga: por encima de esto la barra deja de ser un reto y pasa a ser un
# borron (ver EXTRACTION_MARKER_MAX, que es donde se noto el problema).
const MINERIA_CARGA_MAX := 2.2
const MINERIA_GOLPES_BASE := 3.0        # golpes necesarios a dificultad 1
const MINERIA_PIVOTE := 1.5             # por debajo de este reto, la Fuerza casi no sube
const MINERIA_SLOPE := 0.65
const MINERIA_RETO_MAX := 5.0           # tope FISICO (como el resto de la Fuerza)

# HERBORISTERIA (hoz, Destreza). El nucleo del corte limpio es FINO: aqui no se machaca,
# se acierta. La Destreza lo ensancha y frena la pasada.
const HERB_DESTREZA_FLOOR := 20.0
const HERB_BASE_NUCLEO := 0.06          # semiancho del corte limpio a dificultad 1
const HERB_BORDE_MULT := 2.2            # el borde (corte sucio) es este multiplo del nucleo
const HERB_BASE_VEL := 0.7              # pasadas/seg a dificultad 1
# TECHO de la pasada (mismo motivo que MINERIA_CARGA_MAX): lo que hace dificil un tallo es que
# el NUCLEO sea fino, no que el marcador sea imposible de seguir con la vista.
const HERB_VEL_MAX := 1.6
const HERB_PIVOTE := 1.5
const HERB_SLOPE := 0.65
const HERB_RETO_MAX := 8.0              # mismo tope que la extraccion: las dos son Destreza

# Dificultad del ultimo minijuego de extraccion (para la ganancia de Destreza).
var _last_extraction_zone: float = 0.13
var _last_extraction_hits: int = 3

# NOTA: las stats base de los enemigos ya NO son globales. Cada EnemyData declara las
# SUYAS (base_hp/base_attack/base_defense/base_speed), porque un goblin y un minotauro no
# son variantes del mismo bicho. El baremo del enemigo comun son los valores por defecto
# de EnemyData (28/3/3/4). El factor de piso (enemy_floor_stat_factor) las escala encima.

var _combat_scene: PackedScene = preload("res://scenes/ui/combat.tscn")
var _extraction_script: GDScript = preload("res://scripts/ui/extraction.gd")
var _mining_script: GDScript = preload("res://scripts/ui/mining.gd")
var _harvest_script: GDScript = preload("res://scripts/ui/harvest.gd")
var _drop_pickup_script: GDScript = preload("res://scripts/items/drop_pickup.gd")
var _active_enemy: Node = null     # enemigo del combate en curso
var _active_layer: CanvasLayer = null  # capa donde vive la pantalla actual


# ¿Hay una pantalla modal por encima del mapa (combate o extraccion)? Lo consulta el menu de
# PAUSA: ahi no se guarda. Guardar a mitad de un combate seria guardar un estado que luego no
# se puede reconstruir (media pelea, un bicho a medio matar).
func hay_pantalla_abierta() -> bool:
	return _active_layer != null and is_instance_valid(_active_layer)

# Profundidad actual de la mazmorra (para escalar dificultad). Aun sin pisos: 1.
var current_floor: int = 1

# MEMORIA DE LA MAZMORRA: piso -> {"enemigos": [...], "suelo": [...]}. Guarda lo que dejaste
# en cada piso (bichos vivos, cadaveres sin extraer y cosas por el suelo) para que al volver
# este todo donde estaba: una mazmorra es un SITIO, no un decorado que se rehace a tu espalda.
# La FORMA del piso no se guarda: sale sola de la semilla (ver DungeonFloor).
# Dura lo que dura la EXPEDICION: al entrar desde el pueblo se olvida (ver door.gd), o los
# pisos se irian vaciando para siempre y no se podria volver a farmear.
var memoria_pisos: Dictionary = {}


func olvidar_mazmorra() -> void:
	memoria_pisos.clear()


# ============================================================
#  GUARDAR / CARGAR PARTIDA  (el fichero lo escribe Perfil; aqui se arma el SaveData)
# ============================================================

# Semilla del MUNDO de esta partida: de ella salen todos los mapas (ver DungeonFloor).
# Cada partida nueva estrena la suya, asi que dos ranuras tienen mazmorras distintas.
var semilla_mundo: int = 0

# Al CARGAR una partida hecha dentro de la mazmorra: donde hay que plantar al jugador. El
# DungeonFloor lo lee al construir el piso en vez de mandarte a la entrada.
var pos_cargada: Vector2 = Vector2.INF


# Empieza una partida DE CERO (menu -> Nueva partida). Mundo nuevo y personaje a estrenar.
func nueva_partida() -> void:
	randomize()
	semilla_mundo = randi()
	if semilla_mundo == 0:
		semilla_mundo = 1   # 0 = "sin semilla"; nunca puede ser el valor bueno

	player_level = 1
	ability_internal = {"fuerza": 0.0, "resistencia": 0.0, "destreza": 0.0, "agilidad": 0.0, "magia": 0.0}
	actualizar_estado()
	player_current_hp = -1.0
	player_current_mp = -1.0
	money = 0

	crystals.clear()
	materiales.clear()
	almacen_materiales.clear()
	owned_weapons.clear()
	owned_armor.clear()
	consumables.clear()
	equipped_spells.clear()
	item_meta.clear()

	equipped_main = null
	equipped_off = null
	equipped_casco = null
	equipped_pecho = null
	equipped_manos = null
	equipped_pantalones = null
	equipped_botas = null

	tool_hit_reduction = 0
	tool_destreza_bonus = 0
	# Bajas a la mazmorra con un pico y una hoz de serie: recolectar no es una habilidad
	# que haya que desbloquear, es lo que hace cualquiera que entre ahi a buscarse la vida.
	equipped_pico = PICO_BASICO as ToolData
	equipped_hoz = HOZ_BASICA as ToolData

	current_floor = 1
	pos_cargada = Vector2.INF
	olvidar_mazmorra()
	print("[partida] mundo nuevo. Semilla: ", semilla_mundo)


func exportar_partida() -> SaveData:
	var d := SaveData.new()

	# El piso en el que estas AHORA aun no esta en memoria_pisos (un piso solo se vuelca al
	# ABANDONARLO). Si no le pidieramos el volcado, guardarias vacio el piso que estas pisando.
	#
	# EXCEPCION: si acabas de MORIR, el nodo de la mazmorra sigue existiendo (aun no ha dado
	# tiempo a cambiar de escena) pero tu ya no estas ahi: te rescatan al pueblo. Sin esta
	# salvedad, la partida se guardaria como "dentro de la mazmorra" y ademas volveria a
	# volcar el piso a la memoria que la muerte acaba de borrar -> cargarias muerto, abajo.
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	var en_mazmorra: bool = piso != null and not _muriendo
	if en_mazmorra and piso.has_method("volcar_a_memoria"):
		piso.volcar_a_memoria()

	var player := get_tree().get_first_node_in_group("player")

	d.semilla_mundo = semilla_mundo
	d.ability_internal = ability_internal.duplicate()
	d.player_level = player_level
	d.player_current_hp = player_hp()
	d.player_current_mp = player_current_mp
	d.stamina = float(player.current_stamina) if player != null and "current_stamina" in player else -1.0
	d.money = money

	d.crystals = crystals.duplicate()
	d.materiales = materiales.duplicate()
	d.almacen_materiales = almacen_materiales.duplicate()
	d.owned_weapons = owned_weapons.duplicate()
	d.owned_armor = owned_armor.duplicate()

	d.equipped_main = equipped_main
	d.equipped_off = equipped_off
	d.equipped_casco = equipped_casco
	d.equipped_pecho = equipped_pecho
	d.equipped_manos = equipped_manos
	d.equipped_pantalones = equipped_pantalones
	d.equipped_botas = equipped_botas
	d.equip_meta = equip_meta.duplicate(true)

	# item_meta va indexado por el PROPIO objeto: se desmonta en dos arrays paralelos y se
	# rearma al cargar (no me fio de que un Resource sobreviva como CLAVE de diccionario).
	d.meta_items = []
	d.meta_datos = []
	for item in item_meta:
		d.meta_items.append(item)
		d.meta_datos.append((item_meta[item] as Dictionary).duplicate(true))

	# Consumibles: la clave es el .tres de la pocion, o sea un fichero -> basta su ruta.
	d.consumibles = {}
	for c in consumables:
		if c != null and c.resource_path != "":
			d.consumibles[c.resource_path] = int(consumables[c])

	d.equipped_spells = equipped_spells.duplicate()
	d.tool_hit_reduction = tool_hit_reduction
	d.tool_destreza_bonus = tool_destreza_bonus
	# El pico y la hoz son .tres del proyecto (no instancias con identidad propia, como las
	# armas): basta con guardar su ruta, igual que las pociones.
	d.pico = pico().resource_path
	d.hoz = hoz().resource_path

	d.en_mazmorra = en_mazmorra
	d.current_floor = current_floor
	if player is Node2D:
		d.pos_jugador = (player as Node2D).global_position
	d.memoria_pisos = memoria_pisos.duplicate(true)

	# Cabecera (lo que se ve en la lista de ranuras).
	d.fecha = Time.get_datetime_string_from_system(false, true)
	d.cab_nivel = player_level
	d.cab_piso = current_floor
	d.cab_dinero = money
	d.cab_lugar = ("Mazmorra · piso %d" % current_floor) if en_mazmorra else "Pueblo"
	return d


func importar_partida(d: SaveData) -> void:
	semilla_mundo = d.semilla_mundo

	ability_internal = d.ability_internal.duplicate()
	player_level = d.player_level
	actualizar_estado()   # las stats VISIBLES se derivan de las internas, no se guardan aparte
	player_current_hp = d.player_current_hp
	player_current_mp = d.player_current_mp
	money = d.money

	crystals.assign(d.crystals)
	materiales.assign(d.materiales)
	almacen_materiales.assign(d.almacen_materiales)
	owned_weapons.assign(d.owned_weapons)
	owned_armor.assign(d.owned_armor)

	equipped_main = d.equipped_main
	equipped_off = d.equipped_off
	equipped_casco = d.equipped_casco
	equipped_pecho = d.equipped_pecho
	equipped_manos = d.equipped_manos
	equipped_pantalones = d.equipped_pantalones
	equipped_botas = d.equipped_botas
	equip_meta = d.equip_meta.duplicate(true)

	# Rearmamos item_meta con los MISMOS objetos que hay en el baul/equipo: Godot ha
	# conservado la identidad, asi que la espada equipada y la del baul siguen siendo una.
	item_meta.clear()
	for i in range(mini(d.meta_items.size(), d.meta_datos.size())):
		item_meta[d.meta_items[i]] = (d.meta_datos[i] as Dictionary).duplicate(true)

	consumables.clear()
	for ruta in d.consumibles:
		var c: Resource = load(ruta)
		if c != null:
			consumables[c] = int(d.consumibles[ruta])

	equipped_spells.assign(d.equipped_spells)
	tool_hit_reduction = d.tool_hit_reduction
	tool_destreza_bonus = d.tool_destreza_bonus
	equipped_pico = _cargar_tool(d.pico, PICO_BASICO)
	equipped_hoz = _cargar_tool(d.hoz, HOZ_BASICA)

	current_floor = d.current_floor
	memoria_pisos = d.memoria_pisos.duplicate(true)
	pos_cargada = d.pos_jugador if d.en_mazmorra else Vector2.INF

	# Curas a medias y estados de la sesion anterior: fuera.
	player_heal_left = 0.0
	player_mana_heal_left = 0.0
	inventory_open = false
	debug_panel_open = false
	_stamina_cargada = d.stamina


# Carga una herramienta por su ruta. Si la partida es vieja o el .tres ya no existe, se
# cae a la basica: quedarse SIN pico por un fichero que se movio bloquearia la mineria.
func _cargar_tool(ruta: String, respaldo: Resource) -> ToolData:
	if ruta != "":
		var t: Resource = load(ruta)
		if t is ToolData:
			return t as ToolData
	return respaldo as ToolData


# Aguante con el que hay que arrancar al jugador tras cargar (-1 = al maximo). Lo lee el
# jugador en su _ready: el nodo aun no existe cuando se importa la partida.
var _stamina_cargada: float = -1.0

func stamina_cargada() -> float:
	var s: float = _stamina_cargada
	_stamina_cargada = -1.0   # de un solo uso: al recargar la escena vuelve a su maximo normal
	return s


# --- MUERTE ---
# Que fraccion de la BOLSA se queda en la mazmorra al caer. Alto a proposito: es lo que hace
# que "¿subo a vender o bajo un piso mas?" sea una decision y no un tramite.
const MUERTE_PERDIDA := 0.8

# Aviso pendiente de enseñar al aparecer en el pueblo (el jugador acaba de pulsar
# "Continuar" para salir del combate: nada que se pinte en esa pantalla lo va a leer).
var mensaje_muerte: String = ""

# True mientras se resuelve la muerte: le dice a exportar_partida que, aunque el nodo de la
# mazmorra siga vivo, tu ya no estas en ella (te despiertas en el pueblo).
var _muriendo: bool = false


# Has caido en la mazmorra: pierdes el 80% de lo que llevabas encima, despiertas en el pueblo
# curado y la expedicion se acaba (la mazmorra se repuebla). El DINERO, el EQUIPO y lo que ya
# tuvieras guardado en el Hogar no se tocan: el castigo es el botin de ESTA bajada.
func morir_jugador() -> void:
	_muriendo = true
	var perdidos_c: int = _perder_de(crystals)
	var perdidos_d: int = _perder_de(materiales)

	# Despiertas entero: ya has pagado con el botin, no hace falta ademas un paseo al altar.
	player_current_hp = -1   # -1 = "a tope" (se rellena al vuelo)
	player_current_mp = -1
	player_heal_left = 0.0
	player_mana_heal_left = 0.0

	# Expedicion nueva: vuelves al piso 1 y la mazmorra se olvida de lo que dejaste.
	current_floor = 1
	olvidar_mazmorra()

	mensaje_muerte = "Has caído en la mazmorra. Te rescatan, pero el botín se queda abajo: pierdes %d cristal%s y %d material%s." % [
		perdidos_c, "" if perdidos_c == 1 else "es",
		perdidos_d, "" if perdidos_d == 1 else "es"]
	print("[muerte] ", mensaje_muerte, " | te quedan ", crystals.size(), " cristales y ",
		materiales.size(), " materiales")

	# La muerte se GUARDA SOLA: no vale morir y recargar la partida de hace un rato. Si se
	# pudiera deshacer, el castigo por caer seria decorativo y la decision de "¿subo a vender
	# o bajo un piso mas?" dejaria de tener peso.
	Perfil.guardar_actual()
	_muriendo = false

	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")


# Descarta el 80% de una lista de la bolsa: la CANTIDAD es fija (round(n * 0.8), asi es
# predecible y se puede contar), pero CUALES se pierden es al azar. Devuelve cuantos cayeron.
func _perder_de(lista: Array) -> int:
	var n: int = lista.size()
	if n == 0:
		return 0
	var perder: int = mini(n, int(round(float(n) * MUERTE_PERDIDA)))
	for _i in range(perder):
		lista.remove_at(randi() % lista.size())
	return perder

# --- Escalado del ENEMIGO por PROFUNDIDAD (piso) ---
# NIVEL 1 = pisos 1..13. Dos ejes distintos:
#  - STAT BASE (hp/ataque): GEOMETRICO y SIN techo. Es lo que obliga a subir el RAW
#    del arma (tier) y la DEF de la armadura (tier). Reescalado suave: 1.10^12 ~= 3.19
#    = 1.18^7, o sea el piso 13 tiene la dureza base que antes tenia el piso 8.
#  - HABILIDADES: NO por multiplicador plano, sino por FRANJA de SUMA por piso (ver
#    enemy_ability_sum_band); cada arquetipo ocupa un sub-tramo y reparte por sus pesos.
const FLOOR_STAT_GROWTH := 1.10     # +10%/piso a hp/ataque base (piso13 ~= piso8 de antes)

func enemy_floor_stat_factor() -> float:
	return pow(FLOOR_STAT_GROWTH, float(current_floor - 1))

# Franja [min, max] de la SUMA de habilidades del enemigo segun el piso. Cada
# arquetipo ocupa un sub-tramo (franja_low/high en EnemyData) y reparte esa suma por
# sus pesos. Constantes PROVISIONALES (ejemplos del usuario): piso1 [80,200],
# piso2 [175,450] ... piso13 [2100,3200]. Afinar con Excel.
#
# OJO al ×1.12: al dar peso de MAGIA a los enemigos (defensa magica), la suma se reparte
# ahora entre 5 stats y no 4, asi que las fisicas se habrian encogido ~11% de rebote (los
# pesos del slime pasan de sumar 125 a 140). Subimos la franja en esa misma proporcion
# (140/125 = 1.12) para que las 4 fisicas queden EXACTAMENTE como estaban y la Magia se
# añada ENCIMA, en vez de robarles presupuesto. El techo de 999 no se mueve: la stat alta
# del slime al piso 13 sigue saliendo igual (40/140 × 1.12 = 40/125).
const SUM_MAX_F1 := 224.0    # techo de la franja en el piso 1   (era 200)
const SUM_MIN_STEP := 196.0  # cuanto sube el suelo por piso     (era 175)
const SUM_MAX_STEP := 280.0  # cuanto sube el techo por piso     (era 250)
# Suelo MINIMO de la SUMA de habilidades: en el piso 1 el suelo teorico seria 0 y
# los enemigos salian casi vacios (slime ocupa el sub-tramo bajo). Forzamos >=90.
# Solo muerde en el piso 1: del piso 2 en adelante el suelo ya es >=196.
const SUM_MIN_FLOOR := 90.0

func enemy_ability_sum_band(floor: int) -> Vector2:
	var f: float = float(maxi(1, floor) - 1)
	var low: float = maxf(SUM_MIN_STEP * f, SUM_MIN_FLOOR)
	return Vector2(low, SUM_MAX_F1 + SUM_MAX_STEP * f)


# Bajar un piso (lo llama la escalera). El mapa se REGENERA EN SITIO: nada de recargar
# la escena. Recargarla reinstanciaba al jugador en la sala de entrada -justo al lado de
# la puerta del pueblo- con la F aun pulsada, y te escupia al pueblo de rebote.
# Regenerar sin tocar el arbol conserva al jugador, su HUD y sus menus.
# Tu vida, tu bolsa y tus stats siguen donde estaban: bajar no cura ni descansa.
func bajar_piso() -> void:
	# Bajas: apareces en la ENTRADA del piso nuevo (su boca) y te toca cruzarlo entero.
	_cambiar_piso(current_floor + 1, false)


# Subir (escalera de la sala de entrada, solo del piso 2 en adelante). En el piso 1 no hay
# escalera de subir: ahi esta la PUERTA al pueblo.
func subir_piso() -> void:
	if current_floor <= 1:
		return
	# Subes: apareces JUNTO A LA ESCALERA POR LA QUE BAJASTE, en el fondo del piso de
	# arriba, no en su entrada. Si no, subir un piso seria un atajo gratis a la salida.
	_cambiar_piso(current_floor - 1, true)


# Ignora la tecla de actuar (ESPACIO/F) hasta que el jugador la suelte. Se llama al VOLVER
# al mapa desde una pantalla que se cierra con esa misma tecla (combate, extraccion).
func _bloquear_interaccion_jugador() -> void:
	var p: Node = get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("bloquear_interaccion"):
		p.bloquear_interaccion()


func _cambiar_piso(nuevo: int, por_la_bajada: bool) -> void:
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	if piso == null or not piso.has_method("regenerar"):
		push_warning("[mazmorra] no hay piso que regenerar (¿escalera fuera de la mazmorra?)")
		return
	current_floor = maxi(1, nuevo)
	var band: Vector2 = enemy_ability_sum_band(current_floor)
	print("[mazmorra] piso ", current_floor,
		" | stat base x", snappedf(enemy_floor_stat_factor(), 0.01),
		" | franja de habilidades ", roundi(band.x), "-", roundi(band.y))
	piso.regenerar(por_la_bajada)

# True mientras el panel de inventario esta abierto: el jugador no se mueve ni
# interactua (pero el enemigo sigue y puede emboscarte).
var inventory_open: bool = false

# --- BOLSA: lo que llevas ENCIMA de la expedicion. Es lo unico que PESA (peso_actual).
# Los cristales solo salen de la bolsa vendiendolos en la tienda; los materiales se pueden
# guardar en el HOGAR (ver guardar_materiales_en_hogar).
var crystals: Array[Cristal] = []
# MATERIALES: lo que sueltan los bichos (baba, nucleo) y lo que recolectas (mineral, planta).
# Todos son MaterialItem = plantilla (MaterialData) + calidad. Las dos FAMILIAS (corriente /
# nucleo) conviven en la misma bolsa: quien las separa es el que las usa (pociones vs forja).
var materiales: Array[MaterialItem] = []

# --- BAUL DEL HOGAR: materiales ya guardados en casa. No pesan.
var almacen_materiales: Array[MaterialItem] = []

# --- BAUL DE EQUIPO: lo que POSEES (aunque no lo lleves puesto). De momento se llena
# desde el panel de debug; en el futuro, comprando/crafteando. El menu de personaje solo
# deja equipar lo que este aqui. owned_weapons mezcla WeaponData / ShieldData / WandData.
var owned_weapons: Array[Resource] = []
var owned_armor: Array[ArmorData] = []

# OBJETOS consumibles (pociones): ConsumableData -> cantidad. Por ahora se consiguen
# desde el panel de debug (KAN-57). Curan por el tiempo (ver ConsumableData).
var consumables: Dictionary = {}
# Lista para el panel de debug (añadir pociones al inventario).
var _dev_consumables: Array[String] = [
	"res://resources/consumables/pocion_menor.tres",
	"res://resources/consumables/pocion_menor_1.tres",
	"res://resources/consumables/pocion_menor_2.tres",
	"res://resources/consumables/pocion_mana_menor.tres",
	"res://resources/consumables/pocion_mana_menor_1.tres",
	"res://resources/consumables/pocion_mana_menor_2.tres",
]
# DEV: materiales que piden las recetas de la boticaria (para sembrar el baul en pruebas).
var _dev_craft_materials: Array[String] = [
	"res://resources/materials/baba_slime.tres",
	"res://resources/materials/baba_venenosa.tres",
	"res://resources/materials/baba_fuego.tres",
	"res://resources/materials/hierba_palida.tres",
]
# CURA FUERA DE COMBATE (heal-over-time por tiempo real). player.gd la tiquea cada
# frame con tick_heal(). player_heal_left = vida que queda por curar; _rate = vida/seg.
var player_heal_left: float = 0.0
var player_heal_rate: float = 0.0
# Igual pero para el MANÁ (pociones de maná fuera de combate). Se suma a la regen pasiva.
var player_mana_heal_left: float = 0.0
var player_mana_heal_rate: float = 0.0

# Dinero (obtenido por vender cristales en la tienda).
var money: int = 0

# PRUEBAS: fuerza el drop al 100%. Poner en false para usar drop_chance real.
var dev_force_drop: bool = false

# PRUEBAS: peso inicial como % de la capacidad al arrancar (0 = nada).
var dev_start_weight_ratio: float = 0.0

# PRUEBAS: arrancar con este valor en TODAS las habilidades (interno+visible).
# 0 = empezar a 0 (normal). Util para revisar el escalado de la subida.
var dev_start_abilities: int = 0

# --- PANEL DE DEBUG (herramienta de desarrollo, ver scripts/ui/debug_panel.gd) ---
# Override de las habilidades del ENEMIGO, POR STAT: { "fuerza": 500, "magia": 0, ... }.
# Vacio = Base (el reparto normal por pesos y piso). Una stat que NO este en el diccionario
# se queda en su valor natural, asi se puede aislar UNA sola (p.ej. subir solo la Magia para
# ver cuanto frena de verdad la defensa magica) sin deformar el resto del bicho.
var debug_enemy_override: Dictionary = {}
# MODO PRUEBA (muñeco): 0 = off, 1 = Saco (mucha vida, no pega, sin esquiva -> mide tu DPS),
# 2 = Pegador (aguanta y te pega -> mide la mitigacion de tu armadura). Ambos: velocidad
# estandar (cadencia regular) y el jugador es invulnerable (tests largos sin morir).
var debug_dummy_mode: int = 0
var debug_dummy_hp: float = 500.0
# True mientras el panel de debug esta abierto: congela al jugador (para poder
# escribir en los campos sin que WASD lo muevan). Lo consulta player.gd.
var debug_panel_open: bool = false

# La ayuda (F1) se abre SOLA la primera vez que arrancas el juego, para que un tester que
# no ha visto nunca esto sepa que teclas tiene. Solo la primera: vive aqui (en el autoload)
# y no en el panel porque el panel lo crea el jugador y se reconstruye en CADA escena; si
# no, la ayuda se te volveria a abrir cada vez que cruzas una puerta.
var ayuda_mostrada: bool = false


func _ready() -> void:
	# Contador de FPS / frame time (F3). Vive AQUI y no en el HUD porque el HUD lo crea el
	# jugador y desaparece en los menus, y porque tiene que verse por encima del combate y de
	# los minijuegos, que es justo donde hay que medir.
	add_child(preload("res://scripts/ui/fps_overlay.gd").new())

	# El baul NO arranca con nada: empiezas a manos vacias. Los puños no son un objeto que
	# poseas (no se compran, ni se forjan, ni se mejoran), son la AUSENCIA de arma.
	equip_meta["main"] = _meta_por_defecto()

	# TEMPORAL: arrancar con las habilidades a un valor para revisar el escalado.
	if dev_start_abilities > 0:
		for k in ability_internal:
			ability_internal[k] = float(dev_start_abilities)
		actualizar_estado()  # sincroniza lo visible con lo interno

	# TEMPORAL: relleno de cristales hasta ~X% de la capacidad para probar peso.
	if dev_start_weight_ratio > 0.0:
		var objetivo: float = dev_start_weight_ratio * capacidad_carga()
		while peso_actual() < objetivo and crystals.size() < 200:
			var c := Cristal.new()
			c.categoria = randi_range(1, 3)
			c.calidad = Cristal.Calidad.INTACTO
			crystals.append(c)

# Bonus del CUCHILLO de extraccion (el cristal del cadaver). Placeholder hasta tener
# sistema de equipo: la herramienta rellenara estos valores. OJO: esto es la extraccion,
# NO la recoleccion: el pico y la hoz son otra cosa y van en sus propios slots (abajo).
var tool_hit_reduction: int = 0    # reduce pulsaciones necesarias
var tool_destreza_bonus: int = 0   # Destreza extra para la extraccion

# --- HERRAMIENTAS DE RECOLECCION: pico (vetas) y hoz (plantas) ---
# Slots APARTE: no ocupan mano, no pesan y no entran en el combate. Una herramienta mejor
# no sube tu stat, solo hace el minijuego menos hostil (ver ToolData). Se arranca con las
# basicas; la tienda vendera mejores.
const PICO_BASICO := preload("res://resources/tools/pico_basico.tres")
const HOZ_BASICA := preload("res://resources/tools/hoz_basica.tres")

var equipped_pico: ToolData = null
var equipped_hoz: ToolData = null

func pico() -> ToolData:
	return equipped_pico if equipped_pico != null else (PICO_BASICO as ToolData)

func hoz() -> ToolData:
	return equipped_hoz if equipped_hoz != null else (HOZ_BASICA as ToolData)

# --- Equipamiento: loadout de DOS manos (arma principal + secundaria) ---
# La secundaria puede ser otra WeaponData (dual-wield), un ShieldData o null.
# Un arma a dos manos (dos_manos) obliga a secundaria = null.
# AMBAS manos admiten null: null en la principal = MANOS VACIAS (peleas a puños).
#
# Los PUÑOS no son un arma: son la LINEA BASE de pelear sin nada. Sus numeros (motion value,
# aturdir, contundente) viven en un .tres para no hardcodearlos, pero el objeto NO se posee,
# ni se forja, ni se mejora, ni sale en el baul. Solo lo usa arma_main() como respaldo.
const PUNOS_BASE := preload("res://resources/weapons/punos.tres")

var equipped_main: WeaponData = null   # null = manos vacias (puños)
var equipped_off: Resource = null   # WeaponData | ShieldData | null


# El arma con la que peleas DE VERDAD: la equipada, o los puños si no llevas nada. Punto
# unico por el que pasa todo el combate, para que "sin arma" no sea un caso especial en
# cada formula. Ojo: para saber si llevas algo EQUIPADO, mira equipped_main, no esto.
func arma_main() -> WeaponData:
	return equipped_main if equipped_main != null else (PUNOS_BASE as WeaponData)
# Dual-wield: llevar arma en la secundaria acelera el ataque (mas turnos). La
# velocidad final tiene DOS componentes (ver loadout_mods):
#  1) Un bonus fijo por llevar dos armas, DECRECIENTE segun lo rapida que ya sea
#     la principal (a la daga, ya en el tope de 1 mano, se le da menos empujon
#     extra que a un arma lenta) para no desbordar frente a las armas a 2 manos.
#  2) Un extra que suma la PROPIA velocidad de la secundaria por encima de la
#     linea base (ONE_HAND_VEL_MIN): una daga de secundaria aporta velocidad de
#     verdad; una maza (vel base, ONE_HAND_VEL_MIN) no aporta nada extra, ni
#     tampoco resta - solo dejar de restar/promediar ya evita que te frene.
const DUAL_BONUS_SLOW := 0.30      # bonus (1) cuando la principal = ONE_HAND_VEL_MIN
const DUAL_BONUS_FAST := 0.10      # bonus (1) cuando la principal = ONE_HAND_VEL_MAX
const ONE_HAND_VEL_MIN := 1.0      # velocidad_mult del arma a 1 mano mas lenta (maza/espada larga)
const ONE_HAND_VEL_MAX := 1.35     # velocidad_mult del arma a 1 mano mas rapida (daga)
const OFF_HAND_SPEED_WEIGHT := 0.5 # cuanto de la velocidad "extra" de la secundaria se suma (2)
# Bloqueo base al Defender (sin secundaria); la secundaria/escudo suma encima.
const DEFEND_BLOCK_BASE := 0.30

# --- TIER de equipo: multiplicador del RAW (sin duplicar .tres) ---
# Mejorar la MISMA arma/armadura = subir su tier. GEOMETRICO: tier^(t-1). Solo
# escala NUMEROS (raw del arma, DEF de la armadura), SIN techo; NO toca la
# reduccion % (acotada por tipo) ni la identidad (motion_value/velocidad). Deja
# listo el enganche para la tienda/crafteo futuros. Provisional; se afina con Excel.
const TIER_GROWTH := 2.2   # t1 x1, t2 x2.2, t3 x4.84

func tier_mult(tier: int) -> float:
	return pow(TIER_GROWTH, float(maxi(tier, 1) - 1))

# --- Armadura: loadout de 5 piezas (ArmorData o null en cada slot) ---
# Cada pieza aporta DEF plana (aditiva) + % de reduccion (se PROMEDIA) + peso.
# Ver armor_mods(). Interfaz por codigo/DEV keys de momento (tecla J cicla sets).
var equipped_casco: ArmorData = null
var equipped_pecho: ArmorData = null
var equipped_manos: ArmorData = null
var equipped_pantalones: ArmorData = null
var equipped_botas: ArmorData = null

# --- Estado POR ITEM equipado: tier + rareza + mejoras (no van en el .tres
# compartido). keyed por slot: "main","off","casco","pecho","manos","pantalones",
# "botas". mejoras = {categoria: nº}. Ver upgrades.gd. ---
var equip_meta: Dictionary = {
	"main": {"tier": 1, "rareza": Upgrades.Rareza.COMUN, "mejoras": {}},
	"off": {"tier": 1, "rareza": Upgrades.Rareza.COMUN, "mejoras": {}},
	"casco": {"tier": 1, "rareza": Upgrades.Rareza.COMUN, "mejoras": {}},
	"pecho": {"tier": 1, "rareza": Upgrades.Rareza.COMUN, "mejoras": {}},
	"manos": {"tier": 1, "rareza": Upgrades.Rareza.COMUN, "mejoras": {}},
	"pantalones": {"tier": 1, "rareza": Upgrades.Rareza.COMUN, "mejoras": {}},
	"botas": {"tier": 1, "rareza": Upgrades.Rareza.COMUN, "mejoras": {}},
}

# --- Estado POR OBJETO POSEIDO (baul): el mismo dict que acaba en equip_meta al
# equiparlo, POR REFERENCIA. Asi mejorar el item equipado mejora el item del baul,
# y desequiparlo no pierde sus mejoras. keyed por instancia de Resource. ---
var item_meta: Dictionary = {}

# Meta de un item, creandola por defecto (T1/Comun/sin mejoras) la primera vez.
func meta_de(item: Resource) -> Dictionary:
	if item == null:
		return _meta_por_defecto()
	if not item_meta.has(item):
		item_meta[item] = _meta_por_defecto()
	return item_meta[item]

func _meta_por_defecto() -> Dictionary:
	return {"tier": 1, "rareza": Upgrades.Rareza.COMUN, "mejoras": {}}


func _meta(slot: String) -> Dictionary:
	return equip_meta[slot]
func equip_tier(slot: String) -> int:
	return int(equip_meta[slot]["tier"])
func equip_rareza(slot: String) -> int:
	return int(equip_meta[slot]["rareza"])
func equip_mejoras(slot: String) -> Dictionary:
	return equip_meta[slot]["mejoras"]

# --- Setters (los usa el panel de debug / futura tienda) ---
func set_equip_tier(slot: String, t: int) -> void:
	equip_meta[slot]["tier"] = maxi(1, t)
func set_equip_rareza(slot: String, r: int) -> void:
	equip_meta[slot]["rareza"] = clampi(r, 0, Upgrades.RAREZA_SLOTS.size() - 1)
	_recortar_mejoras(slot)  # la nueva rareza puede admitir menos mejoras
# Suma delta (+/-) a una categoria de mejora, respetando el maximo de la rareza.
func add_mejora(slot: String, cat: String, delta: int) -> void:
	var mj: Dictionary = equip_meta[slot]["mejoras"]
	var actual: int = int(mj.get(cat, 0))
	var nuevo: int = maxi(0, actual + delta)
	if delta > 0 and Upgrades.total_mejoras(mj) >= Upgrades.rareza_slots(equip_rareza(slot)):
		return  # sin slots libres
	if nuevo == 0:
		mj.erase(cat)
	else:
		mj[cat] = nuevo
# Recorta el total de mejoras al maximo de la rareza (quita de las ultimas categorias).
func _recortar_mejoras(slot: String) -> void:
	var mj: Dictionary = equip_meta[slot]["mejoras"]
	var maxm: int = Upgrades.rareza_slots(equip_rareza(slot))
	while Upgrades.total_mejoras(mj) > maxm:
		var claves: Array = mj.keys()
		var k: String = claves[claves.size() - 1]
		mj[k] = int(mj[k]) - 1
		if int(mj[k]) <= 0:
			mj.erase(k)
# Cobertura de cada slot para la MEDIA PONDERADA de la reduccion (suma 1.0). El
# pecho cubre lo mas; manos/botas lo menos. Un slot VACIO aporta 0 -> baja la media
# (premia el set completo pero permite mezclar/ir sin armadura).
const COBERTURA_CASCO := 0.20
const COBERTURA_PECHO := 0.35
const COBERTURA_MANOS := 0.125
const COBERTURA_PANTALONES := 0.20
const COBERTURA_BOTAS := 0.125

# PRUEBAS: cambiar loadout en caliente (K = arma principal, L = mano secundaria).
# Es tambien el catalogo de la FORJA del panel de debug. Los PUÑOS no estan y no deben
# estar: no son un arma que se cree ni se mejore (para ir a puños, DESEQUIPA la principal).
var _dev_weapons: Array[String] = [
	"res://resources/weapons/daga.tres",
	"res://resources/weapons/estoque.tres",
	"res://resources/weapons/espada_corta.tres",
	"res://resources/weapons/espada_larga.tres",
	"res://resources/weapons/maza_peq.tres",
	"res://resources/weapons/mandobles.tres",
	"res://resources/weapons/hacha_grande.tres",
	"res://resources/weapons/martillo_grande.tres",
	"res://resources/weapons/baston.tres",
]
var _dev_offs: Array = [
	null,
	"res://resources/weapons/daga.tres",
	"res://resources/weapons/estoque.tres",
	"res://resources/weapons/espada_corta.tres",
	"res://resources/weapons/maza_peq.tres",
	"res://resources/shields/escudo_pequeno.tres",
	"res://resources/shields/escudo_normal.tres",
	"res://resources/shields/escudo_grande.tres",
	"res://resources/wands/varita.tres",
]
var _dev_main_idx: int = -1   # -1 = manos vacias (como arranca el jugador)
var _dev_off_idx: int = 0

# --- HECHIZOS equipados (KAN-56) ---
# Array[SpellData]. VACIO por defecto: no todos los personajes tienen magia. Se
# equipan desde el panel de debug (la obtencion aleatoria se vera mas adelante).
var equipped_spells: Array = []
# Lista para el panel de debug (equipar/quitar). Rutas de los .tres de hechizos.
var _dev_spells: Array[String] = [
	"res://resources/spells/chispa.tres",
	"res://resources/spells/bola_fuego.tres",
	"res://resources/spells/chorro_agua.tres",
	"res://resources/spells/filo_torrente.tres",
	"res://resources/spells/manto_marea.tres",
	"res://resources/spells/filo_ardiente.tres",
	"res://resources/spells/manto_brasas.tres",
	"res://resources/spells/filo_fulgurante.tres",
	"res://resources/spells/manto_centellas.tres",
	"res://resources/spells/tormenta.tres",
	"res://resources/spells/fortaleza.tres",
	"res://resources/spells/debilidad.tres",
]

func tiene_hechizos() -> bool:
	return equipped_spells.size() > 0

# Mana maximo del jugador segun su Magia (para el HUD; en combate lo lleva el Combatant).
func player_max_mp() -> float:
	var a := Abilities.new()
	a.magia = player_magia
	return StatsMath.max_mp_value(a, player_level)

# Vida MAXIMA del jugador con sus stats actuales (para la barra de HP fuera de combate
# y el tope de la cura). Mismo calculo que crear_player_combatant.
func player_max_hp() -> float:
	var a := Abilities.new()
	a.fuerza = player_fuerza
	a.resistencia = player_resistencia
	a.destreza = player_destreza
	a.agilidad = player_agilidad
	a.magia = player_magia
	return StatsMath.max_hp_value(a, player_level, player_base_hp)

# Vida ACTUAL concreta (player_current_hp puede ser -1 = "llena"). La usan las barras.
func player_hp() -> float:
	return player_current_hp if player_current_hp >= 0.0 else player_max_hp()

# True si la escena actual es el PUEBLO (donde se puede cambiar de equipo). Lo consulta
# el menu de personaje para habilitar/bloquear los cambios de armas/armadura.
func en_pueblo() -> bool:
	var s: Node = get_tree().current_scene
	return s != null and s.scene_file_path.ends_with("town.tscn")

# --- OBJETOS / pociones ---
func add_consumable(c: ConsumableData, n: int = 1) -> void:
	if c == null:
		return
	consumables[c] = int(consumables.get(c, 0)) + n

# Total de pociones en el inventario (para el contador del HUD).
func consumibles_total() -> int:
	var t: int = 0
	for c in consumables:
		t += int(consumables[c])
	return t

# Quita 1 unidad de una poción (true si habia). Limpia la clave al llegar a 0.
func gastar_consumible(c: ConsumableData) -> bool:
	var n: int = int(consumables.get(c, 0))
	if n <= 0:
		return false
	n -= 1
	if n <= 0:
		consumables.erase(c)
	else:
		consumables[c] = n
	return true

# BEBER una poción FUERA de combate: arranca la cura/maná-por-tiempo (heal-over-time). No
# hace nada si su efecto no sirve (vida llena en una de vida, maná lleno en una de maná).
# Devuelve true si bebiste.
func beber_pocion_fuera(c: ConsumableData) -> bool:
	if c == null:
		return false
	var maxhp: float = player_max_hp()
	var maxmp: float = player_max_mp()
	if player_current_hp < 0.0:
		player_current_hp = maxhp   # concreta la vida "llena"
	if player_current_mp < 0.0:
		player_current_mp = maxmp   # concreta el maná "lleno"
	# ¿Sirve de algo? (cura y no estas a tope de vida, o da maná y no estas a tope de maná)
	var util_hp: bool = c.cura_hp() and (player_current_hp < maxhp - 0.01 or player_heal_left > 0.0)
	var util_mp: bool = c.da_mana() and (player_current_mp < maxmp - 0.01 or player_mana_heal_left > 0.0)
	if not util_hp and not util_mp:
		print("[objeto] No hace falta: no bebes la ", c.nombre)
		return false
	if not gastar_consumible(c):
		return false
	var partes: Array = []
	if c.cura_hp():
		var total: float = c.cura_efectiva(maxhp)
		player_heal_left += total
		player_heal_rate = maxf(player_heal_rate, c.cura_por_segundo(maxhp))
		partes.append("+%.0f vida" % total)
	if c.da_mana():
		var total_mp: float = c.mana_efectivo(maxmp)
		player_mana_heal_left += total_mp
		player_mana_heal_rate = maxf(player_mana_heal_rate, c.mana_por_segundo(maxmp))
		partes.append("+%.0f maná" % total_mp)
	print("[objeto] Bebes %s: %s en el tiempo" % [c.nombre, ", ".join(partes)])
	return true

# RECUPERACIÓN ÓPTIMA (fuera de combate): bebe automaticamente lo que menos desperdicie —
# la poción de VIDA de menor efecto que sirva (si te falta vida) y/o la de MANÁ de menor
# efecto (si te falta maná). Presiona otra vez para seguir rellenando. Devuelve true si bebio.
func beber_optima() -> bool:
	var bebio: bool = false
	var pv: ConsumableData = _pocion_menor_util(true)
	if pv != null and beber_pocion_fuera(pv):
		bebio = true
	var pm: ConsumableData = _pocion_menor_util(false)
	if pm != null and beber_pocion_fuera(pm):
		bebio = true
	if not bebio:
		print("[objeto] Recuperación óptima: nada que recuperar o sin pociones útiles.")
	return bebio

# La poción de VIDA (es_vida=true) o de MANÁ (false) de MENOR efecto que tengas en stock
# (menos desperdicio); null si no tienes de ese tipo.
func _pocion_menor_util(es_vida: bool) -> ConsumableData:
	var mejor: ConsumableData = null
	var mejor_val: float = INF
	for c in consumables.keys():
		if int(consumables[c]) <= 0:
			continue
		if es_vida and not c.cura_hp():
			continue
		if not es_vida and not c.da_mana():
			continue
		var val: float = c.cura_efectiva(player_max_hp()) if es_vida else c.mana_efectivo(player_max_mp())
		if val < mejor_val:
			mejor_val = val
			mejor = c
	return mejor

# Ritmo (vida/seg) al que se cura por el mapa la Regeneración ARRASTRADA de un combate
# (no cae de golpe, coherente con el HoT de las pociones). PROVISIONAL.
const CARRY_HEAL_RATE := 6.0

# Arrastra a la cura FUERA de combate la Regeneración que quedaba pendiente al terminar el
# combate (la llama combat.gd si el jugador sobrevive). Asi una poción a medias no se pierde.
func arrastrar_regen(total: float) -> void:
	if total <= 0.0:
		return
	player_heal_left += total
	player_heal_rate = maxf(player_heal_rate, CARRY_HEAL_RATE)
	print("[objeto] Arrastras %.1f de cura pendiente al salir del combate (%.1f/s)" % [
		total, CARRY_HEAL_RATE])

# Igual que arrastrar_regen pero para el MANÁ pendiente de una poción de maná (KAN-56/57).
func arrastrar_regen_mana(total: float) -> void:
	if total <= 0.0:
		return
	player_mana_heal_left += total
	player_mana_heal_rate = maxf(player_mana_heal_rate, CARRY_HEAL_RATE)
	print("[objeto] Arrastras %.1f de maná pendiente al salir del combate (%.1f/s)" % [
		total, CARRY_HEAL_RATE])

# Maná que recuperarías en UN TURNO de combate con tu loadout actual (base por Magia +
# bonus de arma mágica, igual que combat.gd). Lo usa la regen pasiva fuera de combate.
func mana_regen_por_turno() -> float:
	var bonus: float = float(loadout_mods().get("mp_regen_bonus", 0.0))
	return StatsMath.mp_regen(float(player_magia)) + bonus

# Regen PASIVA de maná FUERA de combate: rellena "lo de un turno" pero POR SEGUNDO (lento;
# un pool grande tarda mas). Si quieres ir rapido, bebes una poción. player_current_mp = -1
# significa "lleno", asi que no toca nada. En COMBATE la regen es por turno (combat.gd).
func tick_mana_regen(delta: float) -> void:
	var maxmp: float = player_max_mp()
	if maxmp <= 0.0 or player_current_mp < 0.0 or player_current_mp >= maxmp:
		return
	player_current_mp = minf(maxmp, player_current_mp + mana_regen_por_turno() * delta)

# Tiquea la cura fuera de combate (la llama player.gd cada frame). Sube player_current_hp
# sin pasarse del maximo, gastando player_heal_left.
func tick_heal(delta: float) -> void:
	if player_heal_left <= 0.0:
		return
	var maxhp: float = player_max_hp()
	if player_current_hp < 0.0:
		player_current_hp = maxhp
	var sube: float = minf(player_heal_rate * delta, player_heal_left)
	sube = minf(sube, maxhp - player_current_hp)   # no pasar del maximo
	player_current_hp = minf(maxhp, player_current_hp + sube)
	player_heal_left -= maxf(0.0, sube)
	if player_current_hp >= maxhp - 0.01 or player_heal_left <= 0.01:
		player_heal_left = 0.0
		player_heal_rate = 0.0

# Tiquea el MANÁ de poción fuera de combate (la llama player.gd). Sube player_current_mp
# gastando player_mana_heal_left. Va ADEMAS de la regen pasiva (tick_mana_regen).
func tick_mana_pocion(delta: float) -> void:
	if player_mana_heal_left <= 0.0:
		return
	var maxmp: float = player_max_mp()
	if player_current_mp < 0.0:
		player_current_mp = maxmp
	var sube: float = minf(player_mana_heal_rate * delta, player_mana_heal_left)
	sube = minf(sube, maxmp - player_current_mp)
	player_current_mp = minf(maxmp, player_current_mp + sube)
	player_mana_heal_left -= maxf(0.0, sube)
	if player_current_mp >= maxmp - 0.01 or player_mana_heal_left <= 0.01:
		player_mana_heal_left = 0.0
		player_mana_heal_rate = 0.0

func equipar_hechizo(spell: SpellData) -> void:
	if spell != null and not equipped_spells.has(spell):
		equipped_spells.append(spell)

func quitar_hechizo(spell: SpellData) -> void:
	equipped_spells.erase(spell)

# --- Peso / capacidad de carga ---
# De serie llevas un ZURRON pequeño (base_capacity). La Fuerza sube la
# capacidad. En el futuro: mochila y companero de apoyo sumaran aqui.
var base_capacity: float = 25.0        # zurron de serie
var extra_capacity: float = 0.0        # placeholder mochila/companero (futuro)
# La Fuerza MULTIPLICA la capacidad del contenedor (zurron+mochila) hasta un
# maximo (a Fuerza 999 = +50%). Asi no puedes llevar de todo con un zurron.
var fuerza_capacity_bonus_max: float = 0.5  # +50% a Fuerza maxima
# Sobrecarga GRADUAL: por encima del umbral, la penalizacion de velocidad crece
# con la pendiente hasta un maximo. Ej: 80% -> 0%, 90% -> ~33%, 100% -> ~66%.
var overload_threshold: float = 0.8    # % a partir del cual empiezas a ir lento
var overload_slope: float = 3.3        # cuanto crece la penalizacion por encima
var overload_max_penalty: float = 0.8  # penalizacion maxima (0.8 = -80% velocidad)

# Velocidad al ir SIN una pieza de armadura (slot vacio): ir ligero da un pelin de
# ventaja de velocidad, sin flipar. Se pondera por cobertura de slot (ir del todo
# desnudo = este valor). Ver armor_mods().
const SIN_ARMADURA_VEL_MULT := 1.08


# Crea el Combatant del jugador con sus stats actuales (manteniendo la vida).
func crear_player_combatant() -> Combatant:
	var a := Abilities.new()
	a.fuerza = player_fuerza
	a.resistencia = player_resistencia
	a.destreza = player_destreza
	a.agilidad = player_agilidad
	a.magia = player_magia
	var c := Combatant.new("Heroe", player_level, a,
		player_base_hp, player_base_attack, player_base_defense, player_base_speed)
	c.base_magic = player_base_magic
	if player_current_hp < 0.0:
		player_current_hp = float(c.max_hp)  # primera vez: vida llena
	c.current_hp = clampf(player_current_hp, 0.0, float(c.max_hp))

	# Mana y hechizos (KAN-56). El mana persiste como la vida (-1 = lleno).
	if player_current_mp < 0.0:
		player_current_mp = float(c.max_mp)
	c.current_mp = clampf(player_current_mp, 0.0, float(c.max_mp))
	c.spells = equipped_spells

	_aplicar_loadout(c)
	return c


# Aplica al Combatant los modificadores del LOADOUT actual (armas + armadura):
# habilidades de combate, manos, bloqueo/evasion, velocidad, defensa de armadura y
# magia del equipo. Se usa al CREAR el combatiente y tambien para REAPLICAR el loadout
# en caliente cuando cambias de arma DURANTE el combate (dev, teclas K/L). No toca
# vida/mana/energia ni las stats base, solo lo que depende del equipo.
func _aplicar_loadout(c: Combatant) -> void:
	# Habilidades del loadout (KAN-57): las de la mano principal + las de la
	# secundaria/escudo (sin duplicar; en dual de la misma arma aparece una vez).
	var abils: Array = []
	var tiene_escudo: bool = equipped_off is ShieldData
	# Mano secundaria LIBRE = vacia o con varita (WandData no pesa ni estorba el movimiento).
	var off_libre: bool = equipped_off == null or equipped_off is WandData
	for it in [equipped_main, equipped_off]:
		if (it is WeaponData or it is ShieldData or it is WandData) and not it.habilidades.is_empty():
			for ab in it.habilidades:
				if ab == null or abils.has(ab):
					continue
				# Tecnicas de arma+escudo: solo si llevas escudo (ej: Guardia rota).
				if ab.requiere_escudo and not tiene_escudo:
					continue
				# Tecnicas de una mano libre: solo con la otra mano vacia o con varita
				# (ej: el estoque, "En guardia" / contraataque de duelo).
				if ab.requiere_off_libre and not off_libre:
					continue
				abils.append(ab)
	c.abilities_combate = abils
	# Mapa habilidad -> indices de MANO (arma) que la aportan. El dual de una habilidad
	# SOLO se activa si AMBAS armas la traen (daga+daga), no daga+estoque: cada arma tiene
	# SUS habilidades. Mano 0 = principal, 1 = secundaria (solo si es arma). Las de
	# escudo/varita no cuelgan de una mano -> mano principal (0). Ver Combatant/_usar_habilidad.
	var ability_hands: Dictionary = {}
	for ab in abils:
		var idxs: Array = []
		if equipped_main is WeaponData and (equipped_main as WeaponData).habilidades.has(ab):
			idxs.append(0)
		if equipped_off is WeaponData and (equipped_off as WeaponData).habilidades.has(ab):
			idxs.append(1)
		if idxs.is_empty():
			idxs.append(0)
		ability_hands[ab] = idxs
	c.ability_hands = ability_hands

	# Aplicar los modificadores del loadout. Las MANOS (1 o 2) se alternan por
	# golpe en combate; set_hands activa la primera. El resto son del loadout entero.
	var m := loadout_mods()
	c.set_hands(m["hands"])
	c.defend_block = m["defend_block"]
	c.evasion_penal = m["evasion_penal"]

	# Armadura: DEF plana aditiva + % de reduccion (media ponderada, acotada) +
	# velocidad + esquiva (Evasion) + resist. criticos (ResistCrit).
	var am := armor_mods()
	c.extra_defense = am["def_bonus"]
	c.armor_reduction = am["reduction"]
	c.velocidad_mult = float(m["velocidad_mult"]) * float(am["velocidad_mult"])
	c.crit_resist = float(am["crit_resist"])
	c.status_resist = float(am["resist_estados"])  # resist. a estados (mejora Resistencia, KAN-58)
	# La esquiva de armadura BAJA el evasion_penal (negativo = bonus de esquiva).
	c.evasion_penal = float(m["evasion_penal"]) - float(am["evasion_bonus"])
	# Magia del equipo (KAN-95): amplificador, regen extra, eficiencia y velocidad de
	# casteo (la armadura frena también el casteo, como el ataque).
	c.magic_amp = float(m["magic_amp"])
	c.mp_regen_bonus = float(m["mp_regen_bonus"])
	c.mana_reduccion = float(m["mana_reduccion"])
	c.cast_velocidad_mult = float(m["cast_velocidad_mult"]) * float(am["velocidad_mult"])


# Combina la mano principal + la secundaria en los modificadores finales de
# combate. La secundaria aporta VELOCIDAD (dual) o BLOQUEO/penalizacion (escudo).
func loadout_mods() -> Dictionary:
	var main: WeaponData = arma_main()   # sin arma equipada -> los puños
	# Mods COMPARTIDOS (del loadout entero) + lista de MANOS (armas que alternan).
	var m := {
		"velocidad_mult": main.velocidad_mult,
		"defend_block": DEFEND_BLOCK_BASE,
		# El arma principal define lo escurridizo que eres (daga = +esquiva). Un
		# evasion_penal NEGATIVO = bonus de esquiva (los escudos suman penal, encima).
		"evasion_penal": -main.evasion_bonus,
		"hands": [_hand_from(main, "main")],   # mano principal siempre
	}
	if main.dos_manos:
		# Arma grande a dos manos: sin secundaria, pero bloquea decente por su tamaño.
		m["defend_block"] += main.bloqueo
	elif equipped_off is ShieldData:
		var sh: ShieldData = equipped_off
		m["velocidad_mult"] *= sh.velocidad_mult   # el escudo te frena algo
		m["defend_block"] += sh.bloqueo            # pero bloquea mucho
		m["evasion_penal"] += sh.evasion_penal
	elif equipped_off is WeaponData:
		var off: WeaponData = equipped_off
		# Base: la velocidad de la PRINCIPAL con el bonus fijo de dual (decreciente
		# si la principal ya es rapida) + lo que aporte de mas la SECUNDARIA sobre
		# la linea base (una maza de secundaria no resta ni suma; una daga si suma).
		var frac := clampf((main.velocidad_mult - ONE_HAND_VEL_MIN) / (ONE_HAND_VEL_MAX - ONE_HAND_VEL_MIN), 0.0, 1.0)
		var dual_bonus := lerpf(DUAL_BONUS_SLOW, DUAL_BONUS_FAST, frac)
		var off_extra := maxf(0.0, off.velocidad_mult - ONE_HAND_VEL_MIN) * OFF_HAND_SPEED_WEIGHT
		m["velocidad_mult"] = main.velocidad_mult * (1.0 + dual_bonus) + off_extra
		m["defend_block"] += off.bloqueo            # bloqueo mediocre con arma
		# Dual: la secundaria es la 2ª mano -> se alterna con la principal golpe a
		# golpe. Cada arma conserva su MV/crit/aturdir propios (no se promedian).
		(m["hands"] as Array).append(_hand_from(off, "off"))
	# else: mano secundaria vacia -> una sola mano (la principal).
	# RAPIDEZ (mejora del arma principal): multiplica la velocidad final (capada).
	var main_wm := Upgrades.weapon_mods(main, tier_mult(equip_tier("main")),
		equip_rareza("main"), equip_mejoras("main"))
	m["velocidad_mult"] = float(m["velocidad_mult"]) * float(main_wm["vel_mult"])

	# --- MAGIA (KAN-95): magic_amp, regen de maná, eficiencia y velocidad de CASTEO ---
	# El baston (main.es_magica) y/o la varita (off = WandData) aportan estos mods.
	# La varita no añade mano de ataque (bloqueo/evasion ~0) -> se ignora en lo fisico.
	var magic_amp := 1.0
	var mp_regen_bonus := 0.0
	var mana_reduccion := 0.0
	var cast_vel_add := 0.0
	# Recitar un encantamiento no se hace con el arma: por defecto va a velocidad NORMAL (1.0).
	# Solo las armas MAGICAS (baston / varita) la tocan, y con su campo PROPIO cast_vel_mult:
	# lo rapido que RECITAS con un arma no tiene por que ser lo rapido que la BLANDES.
	var cast_base := 1.0
	if main.es_magica:
		cast_base = main.cast_vel_mult
		var mm := Upgrades.magic_mods(main.magic_amp, tier_mult(equip_tier("main")), equip_rareza("main"), equip_mejoras("main"))
		magic_amp *= float(mm["magic_amp"])
		mp_regen_bonus += main.mp_regen_bonus * float(mm["regen_mult"])
		mana_reduccion += float(mm["mana_reduccion"])
		cast_vel_add += float(mm["cast_vel_add"])
	if equipped_off is WandData:
		var wand: WandData = equipped_off
		var mo := Upgrades.magic_mods(wand.magic_amp, tier_mult(equip_tier("off")), equip_rareza("off"), equip_mejoras("off"))
		magic_amp *= float(mo["magic_amp"])
		mp_regen_bonus += wand.mp_regen_bonus * float(mo["regen_mult"])
		mana_reduccion += float(mo["mana_reduccion"])
		cast_vel_add += float(mo["cast_vel_add"])
		cast_base = wand.cast_vel_mult   # al castear, la barra usa la velocidad de la varita
	m["magic_amp"] = magic_amp
	m["mp_regen_bonus"] = mp_regen_bonus
	m["mana_reduccion"] = minf(0.25, mana_reduccion)
	m["cast_velocidad_mult"] = cast_base * (1.0 + cast_vel_add)
	return m


# Extrae los datos POR MANO de un arma (lo que cambia golpe a golpe en dual). El
# raw/crit/acierto/aturdir salen de Upgrades (tier × rareza × mejoras de ESE slot).
func _hand_from(w: WeaponData, slot: String) -> Dictionary:
	var wm := Upgrades.weapon_mods(w, tier_mult(equip_tier(slot)),
		equip_rareza(slot), equip_mejoras(slot))
	return {
		"nombre": w.nombre,
		"motion_value": w.motion_value,
		"ataque_arma": wm["raw"],
		"crit_bonus": w.crit_bonus + float(wm["crit_add"]),
		"precision": wm["precision"],
		"dano_tipo": int(w.dano_tipo),
		"aturdir_base": w.aturdir_base + float(wm["aturdir_add"]),
	}


# True si ESTE loadout (con 'main' de principal) admite 'item' en la secundaria.
# Escudo o vacio: siempre (si la principal no es a 2 manos). Arma: debe permitir
# dual y, si la principal solo admite off-hand ligera (espada larga), ser ligera.
# Ademas, no puedes llevar en las dos manos el MISMO objeto: para ir a dual
# necesitas dos armas distintas en el baul.
# 'main' puede ser null (MANOS VACIAS): entonces solo se admite escudo, varita o nada. Un
# arma en la secundaria con la principal vacia seria un descuido, no una jugada: si quieres
# esa espada, va en la PRINCIPAL.
func _secundaria_valida(main: WeaponData, item: Resource) -> bool:
	if main == null:
		return item == null or item is ShieldData or item is WandData
	if main.dos_manos:
		return false
	if item != null and item == main:
		return false   # la misma arma fisica no puede ocupar las dos manos
	if item is WandData:
		# La varita (soporte) va con armas LIGERAS (daga / espada corta / maza peq / estoque)
		# Y con la ESPADA LARGA (que si no solo admite escudo): buena combinacion de soporte.
		return int(main.tipo) in [WeaponData.Tipo.DAGA, WeaponData.Tipo.ESPADA_CORTA,
			WeaponData.Tipo.MAZA_PEQ, WeaponData.Tipo.ESPADA_LARGA, WeaponData.Tipo.ESTOQUE]
	if item is WeaponData:
		var w: WeaponData = item
		if not w.puede_dual:
			return false
		if main.off_hand_solo_escudo:
			return false   # este main (espada larga) no admite NINGUN arma en off
	return true   # ShieldData o null

# Equipa un arma en la mano principal; null = DESEQUIPAR (manos vacias, peleas a puños).
# Revalida la secundaria: si la nueva principal no la admite (2 manos, solo-ligera, o manos
# vacias con un arma en la off), la quita.
func equipar_arma(w: WeaponData) -> void:
	equipped_main = w
	equip_meta["main"] = meta_de(w)   # null -> meta por defecto: el puño no se mejora
	if not _secundaria_valida(w, equipped_off):
		equipped_off = null
		equip_meta["off"] = _meta_por_defecto()

# Equipa la mano secundaria (arma dual o escudo); null = vacia.
func equipar_secundaria(item: Resource) -> bool:
	if not _secundaria_valida(equipped_main, item):
		return false
	equipped_off = item
	equip_meta["off"] = meta_de(item)
	return true

# Equipa una pieza de armadura en su slot ("casco", "pecho", ...); null = vacio.
func equipar_armadura(slot: String, pieza: ArmorData) -> void:
	set("equipped_" + slot, pieza)
	equip_meta[slot] = meta_de(pieza)


# Recorre los 5 slots de armadura y combina:
#  - def_bonus: DEF plana SUMADA (defensa_base × motion_def × tier). SIN techo.
#  - reduction: % de reduccion como MEDIA PONDERADA por cobertura (slot vacio = 0),
#    acotada por StatsMath.ARMOR_REDUCTION_MAX.
#  - velocidad_mult: velocidad combinada por cobertura (como las armas). Un slot
#    VACIO aporta el bonus de "sin armadura" (ir ligero); set completo de una
#    categoria = su velocidad; mezclar interpola. Afecta a combate Y mapa.
func armor_mods() -> Dictionary:
	var def_bonus := 0.0
	var reduction := 0.0
	var vel_delta := 0.0     # suma ponderada de (velocidad_mult - 1)
	var evasion := 0.0       # esquiva de armadura (mejora Evasion, ligeras/medias)
	var crit_resist := 0.0   # resist. criticos (mejora ResistCrit, pesadas)
	var resist_estados := 0.0  # resist. a estados alterados (mejora Resistencia, KAN-58)
	var slots := [
		[equipped_casco, COBERTURA_CASCO, "casco"],
		[equipped_pecho, COBERTURA_PECHO, "pecho"],
		[equipped_manos, COBERTURA_MANOS, "manos"],
		[equipped_pantalones, COBERTURA_PANTALONES, "pantalones"],
		[equipped_botas, COBERTURA_BOTAS, "botas"],
	]
	for s in slots:
		var pieza: ArmorData = s[0]
		var cob: float = float(s[1])
		if pieza == null:
			# Slot vacio: bonus de ir ligero (ponderado por cobertura).
			vel_delta += cob * (SIN_ARMADURA_VEL_MULT - 1.0)
			continue
		var slot: String = s[2]
		var pm := Upgrades.armor_piece_mods(pieza, tier_mult(equip_tier(slot)),
			equip_rareza(slot), equip_mejoras(slot))
		def_bonus += float(pm["def"])                        # DEF (tier×rareza×mejoras), sin techo
		reduction += cob * float(pm["reduccion"])            # media ponderada (cobertura suma 1.0)
		vel_delta += cob * (float(pm["vel_mult"]) - 1.0)     # velocidad ponderada
		evasion += float(pm["evasion"])
		crit_resist += float(pm["crit_resist"])
		resist_estados += float(pm["resist_estados"])
	reduction = clampf(reduction, 0.0, StatsMath.ARMOR_REDUCTION_MAX)
	evasion = clampf(evasion, 0.0, Upgrades.EVASION_CAP)
	crit_resist = clampf(crit_resist, 0.0, Upgrades.RESIST_CRIT_CAP)
	resist_estados = clampf(resist_estados, 0.0, Upgrades.RESISTENCIA_CAP)
	return {"def_bonus": def_bonus, "reduction": reduction, "velocidad_mult": 1.0 + vel_delta,
		"evasion_bonus": evasion, "crit_resist": crit_resist, "resist_estados": resist_estados}


# Multiplicador de velocidad de la armadura (para el movimiento en mapa; en combate
# ya va dentro de Combatant.velocidad_mult). 1.0 = neutro.
func armor_speed_mult() -> float:
	return float(armor_mods()["velocidad_mult"])


# --- Peso / capacidad ---
func capacidad_carga() -> float:
	var contenedor: float = base_capacity + extra_capacity
	var mult: float = 1.0 + clampf(player_fuerza / 999.0, 0.0, 1.0) * fuerza_capacity_bonus_max
	return contenedor * mult

func peso_actual() -> float:
	var w: float = 0.0
	for c in crystals:
		w += c.peso()
	for m in materiales:
		w += m.peso()
	return w

func ratio_carga() -> float:
	var cap: float = capacidad_carga()
	return 0.0 if cap <= 0.0 else peso_actual() / cap

func esta_sobrecargado() -> bool:
	return ratio_carga() >= overload_threshold


# ============================================================
#  BAUL DE EQUIPO (armas/armaduras poseidas) y ALMACEN DEL HOGAR (materiales)
# ============================================================

# Añade un arma/escudo/varita al baul (sin duplicados).
func add_owned_weapon(item: Resource) -> void:
	if item != null and not owned_weapons.has(item):
		owned_weapons.append(item)

# Añade una pieza de armadura al baul (sin duplicados).
func add_owned_armor(pieza: ArmorData) -> void:
	if pieza != null and not owned_armor.has(pieza):
		owned_armor.append(pieza)


# --- FORJA: crear una INSTANCIA propia de un item, con su tier/rareza/mejoras ---
# 'base' es el .tres compartido (plantilla). Se duplica para que cada copia tenga
# su propia identidad: asi puedes tener dos espadas cortas distintas, y llevar una
# en cada mano. Devuelve la instancia creada, ya metida en el baul.
func crear_item(base: Resource, tier: int, rareza: int, mejoras: Dictionary) -> Resource:
	if base == null:
		return null
	var copia: Resource = base.duplicate()
	item_meta[copia] = {
		"tier": maxi(1, tier),
		"rareza": clampi(rareza, 0, Upgrades.RAREZA_SLOTS.size() - 1),
		"mejoras": mejoras.duplicate(),
	}
	if copia is ArmorData:
		add_owned_armor(copia as ArmorData)
	else:
		add_owned_weapon(copia)
	return copia


# Nombre para mostrar: "Espada corta +3  ·  T2 Epico". Como ahora puedes tener
# varias copias de la misma plantilla, el nombre a secas ya no las distingue.
func item_plus(item: Resource) -> String:
	if item == null:
		return ""
	var n: int = Upgrades.total_mejoras(meta_de(item)["mejoras"])
	return "" if n == 0 else " +%d" % n

func item_display_name(item: Resource) -> String:
	if item == null:
		return "(nada)"
	var m: Dictionary = meta_de(item)
	var n: int = Upgrades.total_mejoras(m["mejoras"])
	var txt: String = str(item.get("nombre"))
	if n > 0:
		txt += " +%d" % n
	return "%s  ·  T%d %s" % [txt, int(m["tier"]), Upgrades.rareza_nombre(int(m["rareza"]))]

# Piezas del baul que encajan en un slot concreto ("casco", "pecho", ...).
func owned_armor_de_slot(slot: String) -> Array:
	var idx: int = ARMOR_SLOT_ORDEN.find(slot)
	var res: Array = []
	for p in owned_armor:
		if int(p.slot) == idx:
			res.append(p)
	return res

# Orden de ArmorData.Slot (CASCO, PECHO, MANOS, PANTALONES, BOTAS).
const ARMOR_SLOT_ORDEN := ["casco", "pecho", "manos", "pantalones", "botas"]


# HOGAR: guarda en el baul los MATERIALES de la bolsa. Los CRISTALES no: esos hay que
# venderlos en la tienda si o si. Devuelve cuantos materiales guardo.
func guardar_materiales_en_hogar() -> int:
	var n: int = materiales.size()
	if n == 0:
		return 0
	for m in materiales:
		almacen_materiales.append(m)
	materiales.clear()
	print("[hogar] Guardas %d materiales. Total en casa: %d" % [n, almacen_materiales.size()])
	return n


# ============================================================
#  CRAFTEO (boticaria): pociones a partir de materiales del HOGAR
#  Los materiales salen del baul (almacen_materiales), no de la bolsa: craftear es una
#  actividad de pueblo. La CALIDAD no cambia la receta, cambia cuantos items hacen falta
#  (un intacto = 3 unidades, normal = 2, dañado = 1; ver MaterialItem.unidades_crafteo).
# ============================================================

# Unidades DISPONIBLES de un material en el baul del Hogar (suma de calidades).
func unidades_material_en_hogar(mat: MaterialData) -> int:
	if mat == null:
		return 0
	var total: int = 0
	for it in almacen_materiales:
		if it != null and it.data != null and it.data.id == mat.id:
			total += it.unidades_crafteo()
	return total


# Cuantos ITEMS de un material Y calidad concreta hay en el baul (tope del contador de la UI).
func items_calidad_en_hogar(mat: MaterialData, cal: int) -> int:
	if mat == null:
		return 0
	var n: int = 0
	for it in almacen_materiales:
		if it != null and it.data != null and it.data.id == mat.id and int(it.calidad) == int(cal):
			n += 1
	return n


# Unidades que aporta un item segun su calidad (intacto 3 / normal 2 / dañado 1).
func _uds_calidad(cal: int) -> int:
	match cal:
		MaterialItem.Calidad.INTACTO: return 3
		MaterialItem.Calidad.NORMAL: return 2
		MaterialItem.Calidad.DANADO: return 1
		_: return 0


# Unidades sumadas por una entrada de seleccion {calidad: cantidad}.
func _uds_de_seleccion(dict: Dictionary) -> int:
	var u: int = 0
	for cal in dict:
		u += int(dict[cal]) * _uds_calidad(int(cal))
	return u


# ¿Es valida ESTA seleccion para fabricar `veces` pociones? La 'seleccion' es un Array
# paralelo a receta.ingredientes; cada entrada un {calidad: cantidad} POR POCION. Vale si:
# hay `veces` pociones base (si es mejora), cada ingrediente llega a sus unidades (se permite
# pasarse) y hay stock para `veces` × lo elegido de cada calidad.
# Cuantas POCIONES completas cubre esta seleccion = min por ingrediente de (unidades
# elegidas / unidades por poción). Meter 6 uds en una receta de 3 -> 2 pociones. Acotado por
# el stock (no puedes elegir mas de lo que tienes) y, si es mejora, por las pociones base.
func pociones_de_seleccion(receta: RecipeData, seleccion: Array) -> int:
	if receta == null or receta.resultado == null:
		return 0
	if seleccion.size() < receta.ingredientes.size():
		return 0
	var n: int = 1000000
	var hubo: bool = false
	for i in receta.ingredientes.size():
		var ing = receta.ingredientes[i]
		if ing == null or ing.material == null or ing.unidades <= 0:
			continue
		hubo = true
		var dict: Dictionary = seleccion[i]
		for cal in dict:
			if int(dict[cal]) > items_calidad_en_hogar(ing.material, int(cal)):
				return 0   # pides mas de lo que tienes
		n = mini(n, _uds_de_seleccion(dict) / ing.unidades)
	if not hubo:
		return 0
	if receta.es_mejora():
		n = mini(n, int(consumables.get(receta.pocion_base, 0)))
	return maxi(0, n)


# ¿Se puede fabricar al menos UNA poción con esta seleccion?
func seleccion_valida(receta: RecipeData, seleccion: Array) -> bool:
	return pociones_de_seleccion(receta, seleccion) >= 1


# BONUS DE DOBLE: probabilidad de que la receta rinda 2 pociones en vez de 1, segun la
# calidad MEDIA (ponderada por unidades) de los materiales que ELIGES. Premia meter buen
# material: todo intacto -> MAX_PROB_DOBLE; baja con calidades peores; todo dañado -> 0%.
# No cuenta la poción base de una mejora (no es un material).
const MAX_PROB_DOBLE := 0.25   # tope: usando SOLO intactos

func prob_doble_desde_seleccion(receta: RecipeData, seleccion: Array) -> float:
	if receta == null:
		return 0.0
	var suma_score: float = 0.0
	var suma_uds: float = 0.0
	for i in mini(seleccion.size(), receta.ingredientes.size()):
		var dict: Dictionary = seleccion[i]
		for cal in dict:
			var cant: int = int(dict[cal])
			if cant <= 0:
				continue
			var u: float = float(_uds_calidad(int(cal))) * float(cant)
			suma_score += _score_calidad(int(cal)) * u
			suma_uds += u
	if suma_uds <= 0.0:
		return 0.0
	return MAX_PROB_DOBLE * (suma_score / suma_uds)


# Puntuacion de calidad 0..1 para el bonus de doble (intacto 1, normal 0.5, dañado 0).
func _score_calidad(cal: int) -> float:
	match cal:
		MaterialItem.Calidad.INTACTO: return 1.0
		MaterialItem.Calidad.NORMAL: return 0.5
		_: return 0.0


# Fabrica CUANTAS pociones cubra la seleccion (pociones_de_seleccion). Consume la seleccion
# entera y, si es mejora, una poción base por cada una; el bonus de doble se tira POR
# SEPARADO en cada poción (cada una puede salir doble). Devuelve true si fabricó algo.
func craftear_con(receta: RecipeData, seleccion: Array) -> bool:
	var n: int = pociones_de_seleccion(receta, seleccion)
	if n < 1:
		return false
	var prob: float = prob_doble_desde_seleccion(receta, seleccion)
	var total: int = 0
	for _k in range(n):
		if receta.es_mejora():
			gastar_consumible(receta.pocion_base)
		total += 2 if randf() < prob else 1
	# Consumir la seleccion entera (son los materiales de las n pociones).
	for i in receta.ingredientes.size():
		var ing = receta.ingredientes[i]
		if ing == null or ing.material == null:
			continue
		_consumir_seleccion_material(ing.material, seleccion[i])
	add_consumable(receta.resultado, total)
	print("[boticaria] Fabricas ", n, " poción(es) -> ", total, " x ", receta.resultado.nombre,
		"  (prob. doble ", roundi(prob * 100.0), "% por poción)")
	return true


# Quita del baul `cantidad` items de cada (material, calidad) de la seleccion.
func _consumir_seleccion_material(mat: MaterialData, dict: Dictionary) -> void:
	for cal in dict:
		var restan: int = int(dict[cal])
		var i: int = almacen_materiales.size() - 1
		while i >= 0 and restan > 0:
			var it: MaterialItem = almacen_materiales[i]
			if it != null and it.data != null and it.data.id == mat.id and int(it.calidad) == int(cal):
				almacen_materiales.remove_at(i)
				restan -= 1
			i -= 1


# Seleccion AUTO (peor calidad primero) que cubre las unidades de cada ingrediente. La usa el
# boton "Auto" del menu para rellenar de un clic; luego el jugador la retoca a mano.
func seleccion_auto_peor(receta: RecipeData) -> Array:
	var sel: Array = []
	if receta == null:
		return sel
	var orden: Array = [MaterialItem.Calidad.DANADO, MaterialItem.Calidad.NORMAL, MaterialItem.Calidad.INTACTO]
	for ing in receta.ingredientes:
		var dict: Dictionary = {}
		if ing != null and ing.material != null:
			var restante: int = ing.unidades
			for cal in orden:
				if restante <= 0:
					break
				var disp: int = items_calidad_en_hogar(ing.material, int(cal))
				var uds: int = _uds_calidad(int(cal))
				if disp <= 0 or uds <= 0:
					continue
				var quiero: int = int(ceil(float(restante) / float(uds)))
				var usar: int = mini(quiero, disp)
				if usar > 0:
					dict[cal] = usar
					restante -= usar * uds
		sel.append(dict)
	return sel


# Lista de todas las recetas de la boticaria (para el menu). Orden: vida y luego maná.
const _RECIPE_PATHS: Array[String] = [
	"res://resources/recipes/pocion_vida_base.tres",
	"res://resources/recipes/pocion_vida_1.tres",
	"res://resources/recipes/pocion_vida_2.tres",
	"res://resources/recipes/pocion_mana_base.tres",
	"res://resources/recipes/pocion_mana_1.tres",
	"res://resources/recipes/pocion_mana_2.tres",
]

func recetas_boticaria() -> Array:
	var out: Array = []
	for ruta in _RECIPE_PATHS:
		var r: Resource = load(ruta)
		if r != null:
			out.append(r)
	return out


# ============================================================
#  SOLTAR items de la bolsa al SUELO (se pueden recoger con F)
# ============================================================

# Suelta `cantidad` unidades EQUIVALENTES a `modelo` (mismo tipo/categoria/calidad) de la
# bolsa, dejandolas en el suelo junto al jugador. Devuelve cuantas solto.
func soltar_item(modelo: Resource, cantidad: int) -> int:
	if modelo == null or cantidad <= 0:
		return 0
	var pnode := get_tree().get_first_node_in_group("player")
	if pnode == null:
		return 0
	var parent: Node = pnode.get_parent()
	if parent == null:
		return 0

	var soltados: int = 0
	while soltados < cantidad:
		var item: Resource = _sacar_de_bolsa(modelo)
		if item == null:
			break
		var pickup: Node2D = _drop_pickup_script.new()
		pickup.setup(item)
		parent.add_child(pickup)
		# Pequeño offset aleatorio para que no queden todos apilados en el mismo pixel.
		pickup.global_position = pnode.global_position + Vector2(
			randf_range(-18.0, 18.0), randf_range(-18.0, 18.0))
		soltados += 1
	if soltados > 0:
		print("[bolsa] Sueltas %d x %s al suelo" % [soltados, _nombre_item(modelo)])
	return soltados


# Saca de la bolsa UNA unidad equivalente al modelo (y la devuelve). null si no queda.
func _sacar_de_bolsa(modelo: Resource) -> Resource:
	if modelo is Cristal:
		var m := modelo as Cristal
		for i in crystals.size():
			var c := crystals[i]
			if c.categoria == m.categoria and c.calidad == m.calidad:
				crystals.remove_at(i)
				return c
	elif modelo is MaterialItem:
		var mm := modelo as MaterialItem
		for i in materiales.size():
			var m := materiales[i]
			if m.data == mm.data and m.calidad == mm.calidad:
				materiales.remove_at(i)
				return m
	return null


# Nombre legible de un item de bolsa (para logs / UI).
func _nombre_item(item: Resource) -> String:
	if item is Cristal:
		var c := item as Cristal
		return "Cristal Cat %d (%s)" % [c.categoria, c.calidad_texto()]
	if item is MaterialItem:
		var m := item as MaterialItem
		return "%s (%s)" % [m.nombre(), m.calidad_texto()]
	return "?"

# Multiplicador de velocidad por sobrecarga (1.0 = normal). Baja GRADUALMENTE
# cuanto mas te pasas del umbral, hasta un suelo (1 - overload_max_penalty).
func overload_speed_factor() -> float:
	var over: float = ratio_carga() - overload_threshold
	if over <= 0.0:
		return 1.0
	var penalty: float = clampf(over * overload_slope, 0.0, overload_max_penalty)
	return 1.0 - penalty


# --- Subida de habilidades ---

# Suma una ganancia al INTERNO de una habilidad, con rendimientos decrecientes.
# max_reto = tope del reto para ESTA ganancia. Por defecto RETO_MAX (8, el de
# Destreza); las stats fisicas pasan RETO_MAX_FISICO (5) para no dispararse.
func ganar(abil: String, reto_val: float, base: float, max_reto: float = RETO_MAX) -> void:
	if not ability_internal.has(abil):
		return
	var interno: float = ability_internal[abil]
	var factor: float = maxf(DIMINISH_FLOOR,
		pow(clampf(1.0 - interno / ABILITY_CAP, 0.0, 1.0), DIMINISH_POWER))
	var gain: float = base * clampf(reto_val, 0.0, max_reto) * factor
	ability_internal[abil] = interno + gain

# Poder del jugador (suma de visibles) con un suelo para no dividir por 0.
func poder_jugador_eff() -> float:
	var suma: float = float(player_fuerza + player_resistencia + player_destreza
		+ player_agilidad + player_magia)
	return maxf(suma, PODER_JUGADOR_SUELO)

# Dificultad relativa: enemigo/accion facil respecto a ti = poco.
func reto(poder_enemigo: float) -> float:
	return clampf(poder_enemigo / poder_jugador_eff(), 0.0, RETO_MAX)


# FORMA DE LA CURVA de aprendizaje de los MINIJUEGOS (extraccion, mineria, herboristeria).
# La comparten las tres para que compararlas sea honesto: si una diera mas por la forma de
# su curva y no por su ganancia base, tunear el reparto seria imposible.
#   - reto <= pivote: curva ^2 que HUNDE lo facil (un experto sacando de una veta de piso 1
#     no aprende nada; es trabajo, no entrenamiento).
#   - reto  > pivote: SIGUE subiendo (lineal, comprimido por slope) hasta el tope. Meterte
#     con algo muy por encima de ti enseña de verdad, y no se queda capado.
func curva_reto(reto_bruto: float, pivote: float, slope: float, tope: float) -> float:
	var d: float
	if reto_bruto <= pivote:
		d = reto_bruto * reto_bruto / pivote
	else:
		d = pivote + (reto_bruto - pivote) * slope
	return clampf(d, 0.0, tope)

# "Actualizar estado" (hogar / tu dios): aplica lo INTERNO a lo VISIBLE.
func actualizar_estado() -> void:
	player_fuerza = floori(ability_internal["fuerza"])
	player_resistencia = floori(ability_internal["resistencia"])
	player_destreza = floori(ability_internal["destreza"])
	player_agilidad = floori(ability_internal["agilidad"])
	player_magia = floori(ability_internal["magia"])
	print("=== ESTADO ACTUALIZADO ===  F:", player_fuerza, " R:", player_resistencia,
		" D:", player_destreza, " A:", player_agilidad, " M:", player_magia)


# DEBUG: fija a mano las 5 habilidades (interno + visible) y cura al 100% para el
# proximo combate. Lo usa el editor de stats del panel de debug.
func debug_set_abilities(f: int, r: int, d: int, a: int, m: int) -> void:
	ability_internal["fuerza"] = float(clampi(f, 0, 999))
	ability_internal["resistencia"] = float(clampi(r, 0, 999))
	ability_internal["destreza"] = float(clampi(d, 0, 999))
	ability_internal["agilidad"] = float(clampi(a, 0, 999))
	ability_internal["magia"] = float(clampi(m, 0, 999))
	actualizar_estado()          # sincroniza lo visible con lo interno
	player_current_hp = -1.0     # vida llena en el proximo combate
	player_current_mp = -1.0     # mana lleno en el proximo combate


# Teclas de DESARROLLO (temporales): U actualizar estado, H cura, R respawn.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_U:
			actualizar_estado()
		KEY_H:
			player_current_hp = -1  # se rellena a tope en el proximo combate
			player_current_mp = -1  # y el mana
			print("[dev] Vida y mana al 100%")
		KEY_R:
			print("[dev] Respawn: recargando la mazmorra")
			get_tree().reload_current_scene()
		KEY_T:
			print("[dev] Arena de pruebas (sandbox): escenario vacio + spawner")
			get_tree().change_scene_to_file("res://scenes/levels/sandbox.tscn")
		KEY_K:
			_dev_cycle_weapon()
		KEY_L:
			_dev_cycle_off()
		KEY_J:
			_dev_cycle_armor()
		KEY_P:
			_dev_test_spawns()
		KEY_B:
			_dev_brote()


# --- PRUEBAS del sistema de spawns ---
# P: tira 200 veces la tabla del piso y cuenta que sale. Valida en un segundo que el
# venenoso cae ~1/10 y el de fuego ~1/50, sin jugarte una hora esperando partos.
func _dev_test_spawns() -> void:
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	if piso != null and piso.has_method("test_proporciones"):
		piso.test_proporciones(200)


# B: fuerza un BROTE en la zona donde estas (el sistema esta apagado en juego; esto es
# para poder verlo). Sale por la pared mas cercana que no tengas encima.
func _dev_brote() -> void:
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	if piso != null and piso.has_method("dev_brote_cercano"):
		piso.dev_brote_cercano()


# --- PRUEBAS: ciclar el loadout con el teclado ---
# El ciclo pasa por SIN ARMA (indice -1, manos vacias) antes de volver a la primera: asi se
# pueden probar los puños sin que sean un objeto del baul.
func _dev_cycle_weapon() -> void:
	_dev_main_idx += 1
	if _dev_main_idx >= _dev_weapons.size():
		_dev_main_idx = -1   # una vuelta a manos vacias
	if _dev_main_idx < 0:
		equipar_arma(null)
	else:
		var w: WeaponData = load(_dev_weapons[_dev_main_idx])
		add_owned_weapon(w)   # que aparezca tambien en el baul / menu de personaje
		equipar_arma(w)
	if equipped_off == null:   # la nueva principal pudo invalidar la secundaria
		_dev_off_idx = 0
	_dev_print_loadout()

func _dev_cycle_off() -> void:
	if arma_main().dos_manos and equipped_main != null:
		print("[dev] ", equipped_main.nombre, " es a dos manos: sin mano secundaria")
		return
	# Busca la SIGUIENTE secundaria valida para la principal actual (salta las que
	# no admite, p.ej. espada larga + otra arma pesada).
	for _i in range(_dev_offs.size()):
		_dev_off_idx = wrapi(_dev_off_idx + 1, 0, _dev_offs.size())
		var p: Variant = _dev_offs[_dev_off_idx]
		var item: Resource = null if p == null else load(p)
		if equipar_secundaria(item):
			add_owned_weapon(item)   # que aparezca tambien en el baul
			_dev_print_loadout()
			return

func _dev_print_loadout() -> void:
	var off_name: String = "—"
	if equipped_off is WeaponData:
		off_name = (equipped_off as WeaponData).nombre + " (dual)"
	elif equipped_off is ShieldData:
		off_name = (equipped_off as ShieldData).nombre
	var m := loadout_mods()
	var main_name: String = equipped_main.nombre if equipped_main != null else "— (sin arma)"
	print("[dev] Loadout: ", main_name, " + ", off_name,
		"  | vel×:", m["velocidad_mult"], " bloqueo:", m["defend_block"],
		" esq-:", m["evasion_penal"], "  (manos alternan por golpe)")
	for h in m["hands"]:
		print("        mano ", h["nombre"], ": ATK ", h["ataque_arma"], " MV ", h["motion_value"],
			" crit+ ", h["crit_bonus"], " aturdir ", h["aturdir_base"])


# --- PRUEBAS: ciclar el SET de armadura con la tecla J (ninguna/ligera/media/pesada) ---
var _dev_armor_sets: Array[String] = ["", "cuero", "hierro", "hierro_completo", "placas"]
var _dev_armor_idx: int = 0

func _dev_cycle_armor() -> void:
	_dev_armor_idx = wrapi(_dev_armor_idx + 1, 0, _dev_armor_sets.size())
	var pref: String = _dev_armor_sets[_dev_armor_idx]
	if pref == "":
		equipped_casco = null
		equipped_pecho = null
		equipped_manos = null
		equipped_pantalones = null
		equipped_botas = null
	else:
		equipped_casco = load("res://resources/armor/%s_casco.tres" % pref)
		equipped_pecho = load("res://resources/armor/%s_pecho.tres" % pref)
		equipped_manos = load("res://resources/armor/%s_manos.tres" % pref)
		equipped_pantalones = load("res://resources/armor/%s_pantalones.tres" % pref)
		equipped_botas = load("res://resources/armor/%s_botas.tres" % pref)
	_dev_print_armor()

func _dev_print_armor() -> void:
	var am := armor_mods()
	var nombre_set: String = "SIN ARMADURA" if _dev_armor_sets[_dev_armor_idx] == "" \
		else _dev_armor_sets[_dev_armor_idx]
	print("[dev] Armadura: ", nombre_set, "  | DEF+:", am["def_bonus"],
		" reduccion:", snappedf(float(am["reduction"]) * 100.0, 0.1), "%",
		"  vel armadura ×", snappedf(float(am["velocidad_mult"]), 0.01))


# Abre el combate contra un enemigo de la mazmorra.
func start_combat(enemy_node: Node, enemy_data: EnemyData, enemy_initiated: bool) -> void:
	if _active_enemy != null or enemy_data == null:
		return  # ya hay un combate o faltan datos

	_active_enemy = enemy_node
	var player_c := crear_player_combatant()
	var t: float = 0.5
	if "current_t" in enemy_node:
		t = enemy_node.current_t
	var enemy_c := enemy_data.crear_combatant(t)

	# MODO PRUEBA (dev): convierte al enemigo en muñeco de DPS o pegador de armadura.
	if debug_dummy_mode > 0:
		enemy_c.es_dummy = true
		enemy_c.max_hp = debug_dummy_hp
		enemy_c.current_hp = debug_dummy_hp
		enemy_c.dummy_speed_override = player_c.spd()   # velocidad estandar (cadencia ~1:1)
		player_c.invulnerable = true                    # no mueres durante la prueba
		if debug_dummy_mode == 1:            # Saco: DPS limpio (sin defensa ni esquiva, no pega)
			enemy_c.dummy_dmg_out_mult = 0.0
			enemy_c.abilities.resistencia = 0
			enemy_c.abilities.agilidad = 0
		# debug_dummy_mode == 2 (Pegador): conserva sus stats y te pega (mult 1.0).

	# ¿El jugador entra agotado? (sus 2 primeras acciones seran mas lentas)
	var player_exhausted := false
	var pnode := get_tree().get_first_node_in_group("player")
	if pnode != null and pnode.has_method("is_exhausted"):
		player_exhausted = pnode.is_exhausted()

	# ENERGIA de combate (KAN-57) = la stamina de exploracion con la que ENTRAS. Solo
	# el jugador la usa (habilidades/Defender gastan, basico regenera). Al salir vuelve.
	if pnode != null and "current_stamina" in pnode and "max_stamina" in pnode:
		player_c.max_energy = float(pnode.max_stamina)
		player_c.current_energy = clampf(float(pnode.current_stamina), 0.0, float(pnode.max_stamina))

	var combat := _combat_scene.instantiate()
	# PROCESS_MODE_ALWAYS = el combate sigue funcionando aunque el arbol este en pausa.
	combat.process_mode = Node.PROCESS_MODE_ALWAYS
	combat.setup(player_c, enemy_c, enemy_initiated, player_exhausted, overload_speed_factor())
	combat.combat_finished.connect(_on_combat_finished)

	# Lo metemos en una CanvasLayer: asi NO le afecta la camara 2D de la
	# mazmorra (si no, la pantalla de combate sale descentrada).
	var layer := CanvasLayer.new()
	layer.layer = 100  # por encima de todo
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(layer)
	layer.add_child(combat)
	_active_layer = layer

	get_tree().paused = true  # congela la mazmorra mientras luchas
	esconder_mundo(true)      # ...y deja de PINTARLA: la pantalla de combate la tapa entera


# Abre el minijuego de extraccion sobre el cuerpo de un enemigo.
func start_extraction(corpse: Node) -> void:
	if _active_layer != null or corpse == null:
		return
	var data: EnemyData = corpse.data
	if data == null:
		return

	# Categoria ponderada por el poder del bicho (t).
	var t: float = 0.5
	if corpse.has_method("poder_normalizado"):
		t = corpse.poder_normalizado()
	var categoria: int = data.roll_crystal_category(t)
	var eff_destreza: int = player_destreza + tool_destreza_bonus

	# Exigencia del monstruo: sale de su SUMA de habilidades (segun su 't' = poder_normalizado).
	var enemy_suma: float = float(data.suma_habilidades(t))
	var req: float = maxf(1.0, enemy_suma * EXTRACTION_REQ_FACTOR)

	# Dificultad RELATIVA: exigencia del enemigo (su fuerza total) / tu DESTREZA
	# (solo Destreza, con suelo). ~1 = a la par; >1 mas dificil.
	var difficulty: float = req / (float(eff_destreza) + EXTRACTION_DESTREZA_FLOOR)
	var zone_ratio: float = clampf(EXTRACTION_BASE_ZONE / difficulty, 0.05, 0.35)

	# Pulsaciones: base del enemigo, ajustadas por la DIFICULTAD:
	#   dificil (enemigo muy superior) -> MAS pulsaciones (~2x = +1, ~3x = +2...);
	#   facil (tu muy superior) -> MENOS. Y las herramientas restan.
	# SIEMPRE minimo 3: una extraccion nunca es un "toque y listo".
	var ajuste_hits: int = 0
	if difficulty >= 1.0:
		ajuste_hits = floori(difficulty) - 1
	else:
		ajuste_hits = -(floori(1.0 / difficulty) - 1)
	var required_hits: int = maxi(3,
		data.extraction_hits + ajuste_hits - tool_hit_reduction)
	# Guardamos la dificultad para la ganancia de Destreza al terminar.
	_last_extraction_zone = zone_ratio
	_last_extraction_hits = required_hits
	# Marcador: mas rapido cuanto mas DIFICIL (y mas profundo el piso), pero con TECHO.
	var marker_speed: float = EXTRACTION_BASE_MARKER * clampf(difficulty, 0.6, 2.5) \
		+ float(current_floor - 1) * 0.08
	marker_speed = minf(marker_speed, EXTRACTION_MARKER_MAX)
	var speed_step: float = 0.15

	var ex: Control = _extraction_script.new()
	ex.process_mode = Node.PROCESS_MODE_ALWAYS
	ex.setup(categoria, required_hits, zone_ratio, marker_speed, speed_step)
	ex.extraction_finished.connect(_on_extraction_finished.bind(corpse))

	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(layer)
	layer.add_child(ex)
	_active_layer = layer
	get_tree().paused = true
	esconder_mundo(true)


func _on_extraction_finished(cristal: Cristal, corpse: Node) -> void:
	get_tree().paused = false
	esconder_mundo(false)
	# El minijuego se juega con ESPACIO, que ahora es TAMBIEN la tecla de atacar/interactuar:
	# sin esto, la ultima pulsacion del minijuego te lanzaria contra el bicho que tengas al
	# lado nada mas volver al mapa.
	_bloquear_interaccion_jugador()
	if is_instance_valid(corpse):
		corpse.extracted = true  # ya no se puede volver a extraer
		if corpse.has_method("desvanecer"):
			corpse.desvanecer()  # el cuerpo se desvanece y desaparece
	if is_instance_valid(_active_layer):
		_active_layer.queue_free()
	_active_layer = null

	if cristal != null and not cristal.se_pierde():
		crystals.append(cristal)
		print("Obtienes cristal categoria ", cristal.categoria,
			" (", cristal.calidad_texto(), "). Total: ", crystals.size())
		# Destreza: subes mas cuanto mas dificil era el minijuego PARA TI (zona
		# pequeña + mas pulsaciones = reto alto). El reto ya es relativo a tu
		# Destreza, asi que un experto sacando de un bicho flojo tiene reto bajo.
		var reto_bruto: float = (EXTRACTION_BASE_ZONE / _last_extraction_zone) \
			* (float(_last_extraction_hits) / 3.0)
		var dificultad: float = curva_reto(reto_bruto, EXTRACTION_DESTREZA_PIVOTE,
			EXTRACTION_DESTREZA_SLOPE, EXTRACTION_DESTREZA_RETO_MAX)
		ganar("destreza", dificultad, GAIN_DESTREZA_MINIJUEGO)
	else:
		print("El cristal se rompio: lo has perdido.")

	# Lo que deja el bicho (probabilidad baja; en pruebas, 100%). La CALIDAD del material
	# la hereda de TU cristal: si lo sacaste intacto, el material sale intacto (premia el
	# minijuego, no el grindeo).
	if cristal != null and is_instance_valid(corpse) and corpse.data != null:
		_tirar_drop(corpse, _calidad_material_de_cristal(cristal.calidad))


# Tira (o no) lo que suelta el monstruo. Son DOS tiradas independientes, y esa separacion
# es justo el punto del modelo de familias:
#   - el material CORRIENTE (la baba): frecuente, va a las pociones.
#   - el NUCLEO: raro de verdad, va a mejorar el equipo.
# Un bicho puede dejar los dos, uno, o ninguno. Aparecen en el SUELO (se recogen con F)
# DESPUES de que el cuerpo se desvanezca.
func _tirar_drop(corpse: Node, calidad: MaterialItem.Calidad) -> void:
	var data: EnemyData = corpse.data
	var caidos: Array[MaterialItem] = []

	var chance: float = 1.0 if dev_force_drop else data.drop_chance
	if data.drop_material != null and randf() < chance:
		caidos.append(MaterialItem.crear(data.drop_material, calidad))

	var chance_n: float = 1.0 if dev_force_drop else data.nucleo_chance
	if data.nucleo != null and randf() < chance_n:
		caidos.append(MaterialItem.crear(data.nucleo, calidad))

	if caidos.is_empty():
		return

	var pos: Vector2 = corpse.global_position
	var parent: Node = corpse.get_parent()

	# Esperamos a que el cuerpo termine de desvanecerse, y entonces dejamos lo suyo
	# en el suelo donde estaba.
	await get_tree().create_timer(0.7).timeout
	if parent == null or not is_instance_valid(parent):
		return
	for item in caidos:
		var pickup: Node2D = _drop_pickup_script.new()
		pickup.setup(item)
		parent.add_child(pickup)
		pickup.global_position = pos + Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
		print("El monstruo deja en el suelo: ", item.nombre(), " (", item.calidad_texto(), ")")


# Calidad del material que cae, HEREDADA de la del cristal que extrajiste (mismo enum en
# Cristal y MaterialItem). Asi lo que dejas el bicho refleja como te salio el minijuego:
# cristal intacto -> material intacto. Unico matiz: un cristal ROTO (se pierde) no deja el
# material tambien roto (seria doble castigo y ademas ROTO se descarta): baja a DAÑADO, que
# el material bruto -baba, cuero- es mas resistente que el cristal fragil y sobrevive pobre.
func _calidad_material_de_cristal(cal: int) -> MaterialItem.Calidad:
	return mini(int(cal), int(MaterialItem.Calidad.DANADO))


# ============================================================
#  RECOLECCION: mineria (veta -> pico -> FUERZA) y herboristeria (planta -> hoz -> DESTREZA)
#  Los dos abren su pantalla igual que la extraccion (CanvasLayer + arbol en pausa), pero
#  el minijuego de dentro NO se parece: ver mining.gd y harvest.gd.
# ============================================================

# Cuanto exige un material A ESTA PROFUNDIDAD (la roca esta mas apretada abajo).
func _exigencia_material(m: MaterialData) -> float:
	if m == null:
		return 1.0
	return maxf(1.0, m.exigencia * pow(RECOLECCION_PISO_FACTOR, float(current_floor - 1)))


# --- MINERIA ---
# 'nodo' va SIN TIPAR (es un ResourceNode, que no tiene class_name): asi GDScript deja
# leerle lo suyo (material_data, celda) sin pelearse con el tipo estatico.
func start_mineria(nodo) -> void:
	if _active_layer != null or nodo == null or nodo.material_data == null:
		return
	var m: MaterialData = nodo.material_data
	var p: ToolData = pico()

	# Dificultad RELATIVA: lo dura que es la veta contra tu FUERZA (con suelo). ~1 = a la par.
	var d: float = _exigencia_material(m) / (float(player_fuerza) + MINERIA_FUERZA_FLOOR)

	# La Fuerza ensancha la franja optima Y la baja (no necesitas cargar tanto el pico).
	var ancho: float = clampf(MINERIA_BASE_VENTANA / d, 0.06, 0.45) + p.ventana_bonus
	ancho = clampf(ancho, 0.06, 0.60)
	var ini: float = clampf(0.45 * d, 0.15, 1.0 - ancho - 0.05)
	var carga: float = MINERIA_BASE_CARGA * clampf(d, 0.7, 2.5) \
		+ 0.06 * float(current_floor - 1) - p.control
	# El techo se aplica AL FINAL, con el piso y el pico ya dentro: si se aplicara antes, la
	# profundidad volveria a colarse por encima de el.
	carga = clampf(carga, 0.35, MINERIA_CARGA_MAX)
	var golpes: int = clampi(roundi(MINERIA_GOLPES_BASE * d), 2, 8) - p.golpes_menos
	golpes = maxi(2, golpes)

	_last_reco_reto = d
	var ex: Control = _mining_script.new()
	ex.process_mode = Node.PROCESS_MODE_ALWAYS
	ex.setup(m, golpes, ini, ancho, carga)
	ex.mineria_finished.connect(_on_mineria_finished.bind(nodo))
	_abrir_pantalla(ex)


func _on_mineria_finished(item: MaterialItem, nodo) -> void:
	_cerrar_recoleccion(nodo)
	if item == null:
		return
	if not item.se_pierde():
		materiales.append(item)
		print("Sacas ", item.nombre(), " (", item.calidad_texto(), "). Materiales: ", materiales.size())
	else:
		print("La veta se deshace en escombro: no sacas nada.")
	# La FUERZA se entrena aunque la pieza salga rota: has picado igual. Lo que pierdes al
	# hacerlo mal es el botin, no el aprendizaje.
	ganar("fuerza", curva_reto(_last_reco_reto, MINERIA_PIVOTE, MINERIA_SLOPE, MINERIA_RETO_MAX),
		GAIN_FUERZA_MINERIA, RETO_MAX_FISICO)


# --- HERBORISTERIA ---
func start_herboristeria(nodo) -> void:
	if _active_layer != null or nodo == null or nodo.material_data == null:
		return
	var m: MaterialData = nodo.material_data
	var h: ToolData = hoz()

	var d: float = _exigencia_material(m) / (float(player_destreza) + HERB_DESTREZA_FLOOR)

	var nucleo: float = clampf(HERB_BASE_NUCLEO / d, 0.015, 0.14) + h.filo
	var borde: float = nucleo * HERB_BORDE_MULT
	var vel: float = HERB_BASE_VEL * clampf(d, 0.7, 2.5) + 0.05 * float(current_floor - 1)
	var cortes: int = clampi(2 + floori(d), 2, 5) - h.cortes_menos
	cortes = maxi(2, cortes)

	_last_reco_reto = d
	var ex: Control = _harvest_script.new()
	ex.process_mode = Node.PROCESS_MODE_ALWAYS
	ex.setup(m, cortes, nucleo, borde, vel)
	ex.recoleccion_finished.connect(_on_herboristeria_finished.bind(nodo))
	_abrir_pantalla(ex)


func _on_herboristeria_finished(item: MaterialItem, nodo) -> void:
	_cerrar_recoleccion(nodo)
	if item == null:
		return
	if not item.se_pierde():
		materiales.append(item)
		print("Recoges ", item.nombre(), " (", item.calidad_texto(), "). Materiales: ", materiales.size())
	else:
		print("La planta queda hecha jirones: no sirve.")
	ganar("destreza", curva_reto(_last_reco_reto, HERB_PIVOTE, HERB_SLOPE, HERB_RETO_MAX),
		GAIN_DESTREZA_PLANTA)


# Dificultad del ultimo minijuego de recoleccion (para la ganancia de stat al terminar).
var _last_reco_reto: float = 1.0


# Monta la pantalla de un minijuego encima del mapa y congela el mundo. Lo comparten la
# mineria y la herboristeria (la extraccion lo hace a mano por su cuenta, ya estaba escrito).
func _abrir_pantalla(pantalla: Control) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(layer)
	layer.add_child(pantalla)
	_active_layer = layer
	get_tree().paused = true
	esconder_mundo(true)


# ESCONDE (o devuelve) el mapa mientras hay una pantalla modal encima.
#
# Pausar el arbol congela la LOGICA, pero no el DIBUJADO: la mazmorra entera (miles de
# ColorRect de suelo y muro, los bichos, sus conos de vision) se seguia RENDERIZANDO cada
# frame por detras de una pantalla opaca que la tapa entera. Godot no descarta lo que queda
# oculto en 2D. O sea: pagabamos el coste de pintar el piso completo para no verlo, y quien
# lo pagaba era el minijuego, que es lo unico que se mueve rapido y donde se nota.
#
# El HUD y las barras NO se van con esto: cuelgan de CanvasLayer, que no es un CanvasItem y
# no hereda la visibilidad del mundo. Y tapados por la pantalla modal quedan igual que antes.
func esconder_mundo(esconder: bool) -> void:
	var escena: Node = get_tree().current_scene
	if escena is CanvasItem:
		(escena as CanvasItem).visible = not esconder


# Cierra el minijuego y AGOTA el recolectable: la veta picada no vuelve a estar entera, ni
# ahora ni cuando vuelvas al piso (su celda queda apuntada en la memoria del piso).
func _cerrar_recoleccion(nodo) -> void:
	get_tree().paused = false
	esconder_mundo(false)
	_bloquear_interaccion_jugador()   # el minijuego se juega a ESPACIAZOS: que no ataque al salir
	if is_instance_valid(nodo):
		var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
		if piso != null and piso.has_method("marcar_agotado"):
			piso.marcar_agotado(nodo.celda)
		if nodo.has_method("agotar"):
			nodo.agotar()
	if is_instance_valid(_active_layer):
		_active_layer.queue_free()
	_active_layer = null


# ============================================================
#  DEV: la curva de las tres actividades sin tener que jugar una hora.
#  Imprime, para un piso, que dificultad tiene cada minijuego CON TUS STATS DE AHORA y
#  cuanta stat te daria. Sirve para afinar el reparto de la Destreza (cristal vs planta)
#  con datos y no a ojo: mira la curva ENTERA (piso 1, 5, 13), no un piso suelto.
# ============================================================
func dev_curva_recoleccion(pisos: Array = [1, 3, 5, 8, 13]) -> void:
	var piso_real: int = current_floor
	var vetas: MaterialTable = load("res://resources/world/vetas.tres")
	var plantas: MaterialTable = load("res://resources/world/plantas.tres")
	print("[dev] curva de recoleccion con F:", player_fuerza, " D:", player_destreza)
	for p in pisos:
		current_floor = int(p)
		var linea: String = "   piso %2d |" % int(p)
		for tabla in [vetas, plantas]:
			if tabla == null:
				continue
			for e in tabla.disponibles(int(p)):
				var m: MaterialData = (e as MaterialEntry).material
				var es_veta: bool = m.es_veta()
				var stat: float = float(player_fuerza if es_veta else player_destreza)
				var suelo: float = MINERIA_FUERZA_FLOOR if es_veta else HERB_DESTREZA_FLOOR
				var d: float = _exigencia_material(m) / (stat + suelo)
				var dif: float = curva_reto(d,
					MINERIA_PIVOTE if es_veta else HERB_PIVOTE,
					MINERIA_SLOPE if es_veta else HERB_SLOPE,
					MINERIA_RETO_MAX if es_veta else HERB_RETO_MAX)
				var base: float = GAIN_FUERZA_MINERIA if es_veta else GAIN_DESTREZA_PLANTA
				linea += "  %s d=%.2f -> %s +%.2f |" % [m.nombre, d,
					"FUE" if es_veta else "DES", dif * base]
		print(linea)
	current_floor = piso_real


func _on_combat_finished(player_won: bool, player_hp_left: float, player_mp_left: float = -1.0,
		player_energy_left: float = -1.0) -> void:
	get_tree().paused = false
	esconder_mundo(false)
	_bloquear_interaccion_jugador()  # que la tecla que cerro el combate no ataque otra vez al salir
	player_current_hp = player_hp_left
	if player_mp_left >= 0.0:
		player_current_mp = player_mp_left  # el mana gastado persiste al salir

	# La energia gastada/regenerada en combate persiste en la STAMINA de exploracion.
	if player_energy_left >= 0.0:
		var pnode := get_tree().get_first_node_in_group("player")
		if pnode != null and "current_stamina" in pnode:
			pnode.current_stamina = clampf(player_energy_left, 0.0, float(pnode.max_stamina))

	# Si ganaste, el enemigo NO desaparece: queda como cadaver para poder
	# extraerle el cristal (minijuego, Fase 5).
	if player_won and is_instance_valid(_active_enemy) and _active_enemy.has_method("morir"):
		_active_enemy.morir()
	_active_enemy = null

	# Quitamos la capa del combate (con la pantalla dentro).
	if is_instance_valid(_active_layer):
		_active_layer.queue_free()
	_active_layer = null

	# ¿MUERTO? Se mira la VIDA, no player_won: al HUIR tambien llega player_won = false
	# (combat._end(false, true)), y huir es una decision legitima que ya pagas perdiendo el
	# combate. Castigar la huida como la muerte seria un error muy facil de colar aqui.
	if player_hp_left <= 0.0:
		morir_jugador()
