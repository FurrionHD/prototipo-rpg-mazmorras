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
# Bases que crecen al SUBIR DE NIVEL (bakeo de Magia y Destreza, que no escalaban con la base):
# player_base_mp = maná base (arranca en StatsMath.BASE_MP 20); player_base_magia_factor = factor
# de daño mágico congelado (1.0 neutro); player_base_crit = crítico plano acumulado (Destreza).
var player_base_mp: float = 20.0
var player_base_magia_factor: float = 1.0
var player_base_crit: float = 0.0
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
# SUBIR DE NIVEL (estilo DanMachi): al subir NO se borra ability_internal (el total acumulado se
# queda OCULTO de fondo y sigue alimentando recoleccion/reto). Lo que se resetea es el VISIBLE:
# ability_base_nivel guarda el valor de ability_internal en el ultimo subir-de-nivel, y el rango
# VISIBLE de este nivel = ability_internal - ability_base_nivel (vuelve a I al subir). El poder de
# combate se conserva porque el efecto de tus basicas se BAKEA en las stats base (ver subir_nivel).
var ability_base_nivel: Dictionary = {
	"fuerza": 0.0, "resistencia": 0.0, "destreza": 0.0, "agilidad": 0.0, "magia": 0.0}
# Rendimientos decrecientes RELATIVOS AL TOPE: subes bien casi todo el camino
# y frena cerca de 999, pero con un SUELO para que nunca sea imposible.
# factor = max(FLOOR, (1 - interno/999)^POWER).
const ABILITY_CAP := 999.0
const DIMINISH_POWER := 0.8        # <1 = curva mas suave (aguanta mas arriba)
const DIMINISH_FLOOR := 0.15       # suelo: cerca de 999 sigues subiendo (lento, no 0)

# --- SUBIR DE NIVEL ---
const NIVEL_SPIKE := 0.10          # +10% al bakear las stats en la base (para que el salto se note)
const RANGO_C_MIN := 600           # rango C (Abilities.rank_letter: 600-699 = C). Umbral para poder subir.
const CRIT_BAKE_MAX := 0.08        # crítico plano que aporta al subir una Destreza MAXIMA (999). PROVISIONAL.
# Estado de la subida de nivel (persistidos, ver save_data):
# Cada NIVEL tiene su propio "guardián del rango": vencerlo desbloquea SU nivel. guardianes_vencidos
# = { nivel_objetivo: true }. Para subir a N hace falta haber vencido al guardián de N (+ rango).
var guardianes_vencidos: Dictionary = {}
var desarrollos_elegidos: Array = []         # ids de habilidades de desarrollo elegidas (una por nivel)
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
# AGILIDAD: el talado. Talar NO va de fuerza bruta (si fuese Fuerza, entre la mina y la madera
# la Fuerza se dispararia y las demas se quedarian atras): va de COMPAS, o sea de Agilidad. Y
# de paso le da a la Agilidad una fuente fuera del combate, que le faltaba.
const GAIN_AGILIDAD_TALA := 1.0
# Fuentes de COMBATE para las stats que se farmean mal (bases altas: son eventos
# raros, no ocurren cada turno como el ataque):
const GAIN_AGILIDAD_ESQUIVAR := 0.6   # esquivar un golpe entrena Agilidad (adios correr en circulos)
const GAIN_AGILIDAD_CRITICO := 0.3    # clavar un critico entrena Agilidad (encontrar el hueco)
# TOPE del factor de PESO (motion_value) que escala esa ganancia. Al darle critico propio a las
# pesadas (hacha 0.05, mandoble 0.025) critean ~25% mas que antes, y sin tope la Agilidad que
# entrenan se disparaba. El tope les recorta ~20-25% por golpe y NO toca a las ligeras (MV < 1.2).
const GAIN_AGILIDAD_CRIT_MV_MAX := 1.2
const GAIN_RESISTENCIA_BLOQUEO := 0.3 # bloquear con Defender entrena Resistencia extra (KAN-81); moderado para no sobre-premiar el escudo
# Magia (KAN-56): entrena SOLO al LANZAR el hechizo (no por frase, para que sea
# predecible). Formula dedicada = GAIN_MAGIA_CAST × mana_factor × reto(enemigo),
# con tope de reto FISICO (5) y rendimientos decrecientes por la Magia interna.
# mana_factor = coste_mana / MAGIA_COSTE_REF -> hechizos caros entrenan mas (ya
# reflejan mas daño/potencia). Contra un slime: Chispa ~1.5, Bola ~3, Tormenta ~5.
const GAIN_MAGIA_CAST := 0.4
const MAGIA_COSTE_REF := 4.0   # coste de referencia (Chispa) para el factor de mana
# --- Dificultad de la extraccion ---
# La exigencia sale del TIER (categoria) del cristal, NO del enemigo ni del piso: un cristal de
# tier alto es dificil de sacar lo consigas donde lo consigas. Dificultad relativa =
# exigencia_del_tier / (tu Destreza x PESO + SUELO). ~1 = a la par (comodo, sacas intacto); >1
# mas dificil (zona mas pequeña + mas pulsaciones + marcador mas rapido).
#
# EXTRACTION_REQ_POR_TIER[tier] = exigencia de ese tier. Curva elegida por el usuario: suave abajo
# (t1-t3) y subiendo parejo hasta el techo t6 = 420 de Destreza. La Destreza a la que cada tier
# queda "al punto" (dificultad 1.0) es (req - SUELO) / PESO: t1~10, t2~60, t3~120, t4~220, t5~320,
# t6~420. Indice 0 = reserva. PROVISIONAL.
const EXTRACTION_REQ_POR_TIER: Array = [35.0, 35.0, 60.0, 90.0, 140.0, 190.0, 240.0]
const EXTRACTION_BASE_ZONE := 0.16      # tamaño de zona a dificultad 1
const EXTRACTION_DESTREZA_FLOOR := 30.0 # suelo de skill (subido de 20 al aplicar RECOLECCION_STAT_PESO: mantiene la dificultad del novato)
const EXTRACTION_BASE_MARKER := 0.75    # velocidad del marcador a dificultad 1
# TECHO de la velocidad del marcador (recorridos de la barra por segundo).
#
# Es el minijuego mas VIEJO y el unico que no tenia tope: la dificultad lo aceleraba, el piso
# lo aceleraba, y ademas CADA ACIERTO lo acelera otra vez (speed_step). Con la barra midiendo
# ~1150 px, a 0.8 ya iban ~920 px/s, y tras un par de aciertos se ponia en el doble: a esas
# velocidades el marcador salta decenas de pixeles por frame y se ve BORROSO por muchos FPS
# que haya (a 144 estables seguia sin verse nitido). Lo dificil tiene que ser acertar en una
# zona ESTRECHA, no perseguir con la vista algo que ya no se puede seguir.
const EXTRACTION_MARKER_MAX := 1.3

# SUELO del reto A EFECTOS DE VELOCIDAD, comun a los tres minijuegos. La dificultad relativa
# tambien ensancha o estrecha la ventana, y ahi si tiene sentido que baje de 1 (si eres muy
# superior al material, aciertas mas facil). Pero dejarla bajar por debajo de 1 en la VELOCIDAD
# era un error: hacia que el marcador de un veterano fuese al 60-70% de su velocidad base, o
# sea que cuanto mejor eras, mas LENTO y mas aburrido se volvia el minijuego. Justo al reves de
# lo que tiene que pasar. Con el suelo a 1.0, la velocidad base es el MINIMO: lo que la pericia
# te regala es la ventana, no el tedio.
const RECOLECCION_VEL_RETO_MIN := 1.0
const RECOLECCION_VEL_RETO_MAX := 2.5
# PESO de la stat en la DIFICULTAD de la recoleccion (los 4 minijuegos: dificultad =
# exigencia / (stat × PESO + suelo)). Antes la stat entraba 1:1 y la recoleccion se volvia
# trivial en cuanto subias un poco -> "se facilita demasiado rapido". Con un peso < 1, mejorar
# la stat sigue ayudando pero MUCHO mas despacio (tardas en notarlo). Los suelos se subieron a
# la par (20 -> 30) para que el NOVATO conserve su dificultad de arranque; lo que cambia es la
# PENDIENTE de mejora, no el punto de partida. PROVISIONAL (afinar con pruebas/Excel).
const RECOLECCION_STAT_PESO := 0.5
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
const RECOLECCION_PISO_FACTOR := 1.10   # exigencia x1.10 por piso

# MINERIA (pico, Fuerza). La Fuerza ensancha la franja optima Y la baja: un brazo fuerte
# rompe la veta sin tener que cargar el pico hasta arriba.
const MINERIA_FUERZA_FLOOR := 30.0      # suelo de skill (subido de 20 al aplicar RECOLECCION_STAT_PESO)
const MINERIA_BASE_VENTANA := 0.22      # ancho de la franja optima a dificultad 1
const MINERIA_BASE_CARGA := 1.0         # velocidad de la barra de carga a dificultad 1
const MINERIA_CARGA_MIN := 0.8          # suelo duro: por debajo de esto cargar es esperar
# TECHO de la barra de carga: por encima de esto la barra deja de ser un reto y pasa a ser un
# borron (ver EXTRACTION_MARKER_MAX, que es donde se noto el problema).
const MINERIA_CARGA_MAX := 2.2
const MINERIA_GOLPES_BASE := 3.0        # golpes necesarios a dificultad 1
const MINERIA_PIVOTE := 1.5             # por debajo de este reto, la Fuerza casi no sube
const MINERIA_SLOPE := 0.65
const MINERIA_RETO_MAX := 5.0           # tope FISICO (como el resto de la Fuerza)

# HERBORISTERIA (hoz, Destreza). El nucleo del corte limpio es FINO: aqui no se machaca,
# se acierta. La Destreza lo ensancha y frena la pasada.
const HERB_DESTREZA_FLOOR := 30.0       # suelo de skill (subido de 20 al aplicar RECOLECCION_STAT_PESO)
const HERB_BASE_NUCLEO := 0.06          # semiancho del corte limpio a dificultad 1
const HERB_BORDE_MULT := 2.2            # el borde (corte sucio) es este multiplo del nucleo
const HERB_BASE_VEL := 0.9              # pasadas/seg a dificultad 1
# TECHO de la pasada (mismo motivo que MINERIA_CARGA_MAX): lo que hace dificil un tallo es que
# el NUCLEO sea fino, no que el marcador sea imposible de seguir con la vista. Bajado de 1.6:
# con Destreza insuficiente para un material de tier alto la pasada se disparaba y, al ser UNA
# pasada por tallo sin repesca, era literalmente inacertable. Ahora se compensa con mas cortes
# (ver start_herboristeria): el reto se mantiene, pero cada pasada se puede seguir. PROVISIONAL.
const HERB_VEL_MAX := 1.1
const HERB_PIVOTE := 1.5
const HERB_SLOPE := 0.65
const HERB_RETO_MAX := 8.0              # mismo tope que la extraccion: las dos son Destreza

# TALADO (hacha, Agilidad). Aqui no hay punteria: hay COMPAS. La Agilidad ensancha la ventana
# del hachazo y frena el tempo; el resto lo pones tu no perdiendo el ritmo (ver talado.gd).
const TALA_AGILIDAD_FLOOR := 30.0       # suelo de skill (subido de 20 al aplicar RECOLECCION_STAT_PESO)
const TALA_BASE_VENTANA := 0.20         # ancho de la ventana a dificultad 1
const TALA_BASE_TEMPO := 0.55           # vueltas/seg a dificultad 1
# TECHO del tempo: por el mismo motivo que en los otros dos (una ventana que cruza la banda
# tres veces por segundo no es dificil, es ilegible). Y ojo, que los aciertos ACELERAN encima.
const TALA_TEMPO_MAX := 1.2
const TALA_HACHAZOS_BASE := 4.0         # hachazos limpios necesarios a dificultad 1
const TALA_PIVOTE := 1.5
const TALA_SLOPE := 0.65
const TALA_RETO_MAX := 5.0              # tope FISICO (la Agilidad es fisica, como la Fuerza)

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
var _talado_script: GDScript = preload("res://scripts/ui/talado.gd")
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

# ESTADO PERSISTENTE de la mazmorra (piso -> {agotados, zonas_vistas}). A diferencia de
# memoria_pisos, esto SOBREVIVE a volver al pueblo: es lo que hace que picar un nodo no se
# resetee al salir y reentrar (era un farmeo hacker: entrabas, picabas, salias, todo nuevo).
#   - agotados: { celda: tiempo_mazmorra en que se pico }. El nodo reaparece cuando pasa su
#     RESPAWN (ver dungeon_floor). Antes era { celda: true } y se borraba con la expedicion.
#   - zonas_vistas: { zona_idx: true }. La niebla del mapa (tecla M).
# Va SEPARADO de memoria_pisos A PROPOSITO: la bandera 'recordado' del piso es
# memoria_pisos.has(piso), y si dejara aqui la entrada del piso, dejaria de POBLARSE de bichos.
var mazmorra_persistente: Dictionary = {}

# Reloj de EXPEDICION: solo corre mientras juegas (el arbol se pausa en combate, asi que no
# cuenta el tiempo de los turnos). Lo tiquea DungeonFloor. No se puede trampear cerrando el
# juego (se congela) ni tocando el reloj del PC (no mira la hora real). Persiste en el save.
var tiempo_mazmorra: float = 0.0

# COOLDOWNS de habilidades que VIAJAN entre combates (KAN-57 rebalance): un nuke usado en una
# pelea sigue en cooldown en la siguiente, no se resetea al empezar cada combate. { AbilityData:
# turnos_restantes }. Baja 1 por cada combate que EMPIEZAS (ademas de por turno dentro). Se pone
# a cero en partida nueva; es estado de runtime, no va al save (los CD son cortos y efimeros).
var ability_cooldowns_persist: Dictionary = {}
var _active_player_c = null   # el Combatant del jugador en el combate en curso (para leer sus CD al salir)


func olvidar_mazmorra() -> void:
	memoria_pisos.clear()
	# mazmorra_persistente NO se toca: los nodos agotados y las zonas vistas duran mas que una
	# expedicion (esa es justo la gracia). El reloj tampoco se reinicia.


# El estado persistente del piso (agotados + zonas_vistas), creandolo vacio si no existe.
func persistente_piso(piso: int) -> Dictionary:
	if not mazmorra_persistente.has(piso):
		mazmorra_persistente[piso] = {"agotados": {}, "zonas_vistas": {}}
	return mazmorra_persistente[piso]


# MAPA = una LIBRETA (piso -> snapshot congelado) que se pone al dia al ABANDONAR un piso (bajar,
# subir o salir al pueblo). Es a proposito: nada de GPS en vivo. La libreta es AUTONOMA: hornea la
# geometria (las celdas de suelo exploradas), asi el mapa se puede mirar EN EL PUEBLO o de OTRO
# piso, sin el piso vivo delante. Solo aparecen en la libreta los pisos REALMENTE explorados.
#   { "ancho", "alto", "suelo":[cell...], "vivos":[{cell,color}...], "agotados":{cell:tiempo} }
# zonas_vistas SIGUE acumulandose en vivo por debajo (la niebla en vivo); aqui se hornea al salir.
var mapa_snapshot: Dictionary = {}

# BASELINE del mapa al EMPEZAR la expedicion (para revertir al MORIR): lo cartografiado durante una
# expedicion que acaba en muerte se PIERDE. Ver iniciar_expedicion_mapa() y morir_jugador().
var _mapa_baseline: Dictionary = {}
var _vistas_baseline: Dictionary = {}

# Copia la geometria + estado explorado del piso vivo a la libreta. La llaman las salidas del piso
# (al bajar/subir en _cambiar_piso, y las salidas al pueblo door.gd/dungeon_exit.gd) ANTES de
# irse: en ese momento el DungeonFloor aun esta vivo y current_floor es el piso que abandonas.
func capturar_mapa() -> void:
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	if piso == null or piso.gen == null:
		return
	var gen = piso.gen
	var persist: Dictionary = persistente_piso(current_floor)
	var vistas: Dictionary = persist["zonas_vistas"]
	if vistas.is_empty():
		return   # nada explorado en este piso: no se cartografia (no aparece en el selector de pisos)
	# SUELO: todas las celdas de las zonas EXPLORADAS. Se hornea la geometria en la libreta (antes se
	# leia del piso vivo al dibujar; asi el mapa funciona tambien en el pueblo o mirando otro piso).
	var suelo: Array = []
	for i in range(gen.zonas.size()):
		if not vistas.has(i):
			continue
		for c in (gen.zonas[i]["celdas"] as Array):
			suelo.append(c)
	# SOLO los nodos de las zonas que has EXPLORADO. Si no, el mapa marca vetas y plantas en
	# salas por las que no has pasado (te chiva materiales que no has descubierto).
	var vivos: Array = []
	for nodo in get_tree().get_nodes_in_group("recolectable"):
		if not is_instance_valid(nodo) or nodo.material_data == null:
			continue
		if not vistas.has(gen.zona_en(nodo.celda)):
			continue
		vivos.append({"cell": nodo.celda, "color": nodo.material_data.color})
	mapa_snapshot[current_floor] = {
		"ancho": gen.ancho, "alto": gen.alto,
		"suelo": suelo,
		"vivos": vivos,
		"agotados": (persist["agotados"] as Dictionary).duplicate(),
	}
	print("[mapa] libreta al dia: piso ", current_floor, " (", vivos.size(), " nodos, ",
		suelo.size(), " celdas)")


# Al EMPEZAR una expedicion desde el pueblo: guarda un baseline de la cartografia COMMITEADA (lo
# que sobrevive) para poder revertir si mueres. Lo que cartografies a partir de aqui se pierde al
# morir. La llaman door.gd (entrar) y floor_select_menu (saltar por un atajo).
func iniciar_expedicion_mapa() -> void:
	_mapa_baseline = mapa_snapshot.duplicate(true)
	_vistas_baseline = {}
	for p in mazmorra_persistente:
		_vistas_baseline[p] = (mazmorra_persistente[p]["zonas_vistas"] as Dictionary).duplicate()


# Revierte la cartografia al baseline de inicio de expedicion (al MORIR): lo explorado esta
# expedicion se pierde. NO toca 'agotados' (el anti-farmeo de nodos dura mas que la expedicion).
func revertir_mapa_expedicion() -> void:
	mapa_snapshot = _mapa_baseline.duplicate(true)
	for p in mazmorra_persistente:
		var vb: Dictionary = _vistas_baseline.get(p, {})
		mazmorra_persistente[p]["zonas_vistas"] = (vb as Dictionary).duplicate()


# ============================================================
#  GUARDAR / CARGAR PARTIDA  (el fichero lo escribe Perfil; aqui se arma el SaveData)
# ============================================================

# Semilla del MUNDO de esta partida: de ella salen todos los mapas (ver DungeonFloor).
# Cada partida nueva estrena la suya, asi que dos ranuras tienen mazmorras distintas.
var semilla_mundo: int = 0

# Al CARGAR una partida hecha dentro de la mazmorra: donde hay que plantar al jugador. El
# DungeonFloor lo lee al construir el piso en vez de mandarte a la entrada.
var pos_cargada: Vector2 = Vector2.INF


# --- IDENTIDAD del personaje (la elige el jugador al crear la partida, ver main_menu.gd) ---
# Van en el SaveData: cada ranura es un personaje distinto, no una preferencia del perfil.
const NOMBRE_POR_DEFECTO := "Aventurero"
var player_nombre: String = NOMBRE_POR_DEFECTO
var player_color: Color = Color(1, 1, 1)   # tiñe su cuerpo por el mapa (player.tscn)
var player_metalico: float = 0.0           # acabado metalico del cuerpo (shaders/metal.gdshader)

const SHADER_METAL: Shader = preload("res://shaders/metal.gdshader")

# Material del CUERPO del personaje con el acabado que toque. Lo usan el jugador del mapa
# (player.gd) y la muestra de la pantalla de creacion (main_menu.gd), asi que lo que ves al
# elegir es exactamente lo que luego te llevas. El COLOR no va aqui: lo pone el nodo.
# metalico <= 0 -> null (mate: sin shader, como antes de que existiera esto).
func material_cuerpo(metalico: float = -1.0) -> ShaderMaterial:
	var m: float = player_metalico if metalico < 0.0 else metalico
	if m <= 0.0:
		return null
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_METAL
	mat.set_shader_parameter("metal", clampf(m, 0.0, 1.0))
	return mat


# Empieza una partida DE CERO (menu -> Nueva partida). Mundo nuevo y personaje a estrenar,
# con el nombre, el color y el acabado que haya elegido en la pantalla de creacion.
func nueva_partida(nombre_: String = NOMBRE_POR_DEFECTO, color_: Color = Color(1, 1, 1),
		metalico_: float = 0.0) -> void:
	randomize()
	semilla_mundo = randi()
	if semilla_mundo == 0:
		semilla_mundo = 1   # 0 = "sin semilla"; nunca puede ser el valor bueno

	player_nombre = nombre_.strip_edges()
	if player_nombre == "":
		player_nombre = NOMBRE_POR_DEFECTO   # sin nombre te llamas Aventurero, no ""
	player_color = color_
	player_metalico = clampf(metalico_, 0.0, 1.0)

	player_level = 1
	ability_internal = {"fuerza": 0.0, "resistencia": 0.0, "destreza": 0.0, "agilidad": 0.0, "magia": 0.0}
	# Estado de subida de nivel a cero (por si venias de otra partida en la misma sesion).
	ability_base_nivel = {"fuerza": 0.0, "resistencia": 0.0, "destreza": 0.0, "agilidad": 0.0, "magia": 0.0}
	player_base_hp = 50.0
	player_base_attack = 5.0
	player_base_defense = 5.0
	player_base_magic = 5.0
	player_base_speed = 5.0
	player_base_mp = 20.0
	player_base_magia_factor = 1.0
	player_base_crit = 0.0
	desarrollos_elegidos.clear()
	guardianes_vencidos = {}
	habilidad_metalurgia = false
	habilidad_peleteria = false
	habilidad_herreria = false
	habilidad_mezcla = false
	actualizar_estado()
	player_current_hp = -1.0
	player_current_mp = -1.0
	money = 0
	mezcla_exp = 0.0
	metalurgia_exp = 0.0
	peleteria_exp = 0.0
	herreria_exp = 0.0
	esquivas_exp = 0.0
	hechizos_exp = 0.0
	recitado_exp = 0.0
	dano_recibido_exp = 0.0
	pack_inicial_reclamado = false
	bosses_derrotados.clear()
	recompra.clear()

	crystals.clear()
	materiales.clear()
	almacen_materiales.clear()
	owned_weapons.clear()
	owned_armor.clear()
	owned_mochilas.clear()
	equipped_mochila = null
	extra_capacity = 0.0
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
	# Bajas a la mazmorra con un pico, una hoz y un hacha de serie: recolectar no es una
	# habilidad que haya que desbloquear, es lo que hace cualquiera que entre ahi a buscarse
	# la vida.
	equipped_pico = PICO_BASICO as ToolData
	equipped_hoz = HOZ_BASICA as ToolData
	equipped_hacha = HACHA_BASICA as ToolData
	# Empiezas sin conocer NINGUN metal: el herrero solo te enseñara los que te traigas.
	materiales_vistos.clear()

	current_floor = 1
	pos_cargada = Vector2.INF
	olvidar_mazmorra()
	# Partida nueva SI reinicia lo persistente y el reloj (olvidar_mazmorra no los toca porque
	# tienen que durar entre expediciones; una partida nueva es otra cosa).
	mazmorra_persistente.clear()
	mapa_snapshot.clear()
	tiempo_mazmorra = 0.0
	ability_cooldowns_persist.clear()
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
	d.nombre = player_nombre     # identidad: la eligio al crear la partida
	d.color = player_color
	d.metalico = player_metalico
	d.ability_internal = ability_internal.duplicate()
	d.player_level = player_level
	d.ability_base_nivel = ability_base_nivel.duplicate()
	d.player_base_hp = player_base_hp
	d.player_base_attack = player_base_attack
	d.player_base_defense = player_base_defense
	d.player_base_magic = player_base_magic
	d.player_base_speed = player_base_speed
	d.player_base_mp = player_base_mp
	d.player_base_magia_factor = player_base_magia_factor
	d.player_base_crit = player_base_crit
	d.desarrollos_elegidos = desarrollos_elegidos.duplicate()
	d.guardianes_vencidos = guardianes_vencidos.duplicate()
	d.player_current_hp = player_hp()
	d.player_current_mp = player_current_mp
	d.stamina = float(player.current_stamina) if player != null and "current_stamina" in player else -1.0
	d.money = money
	d.mezcla_exp = mezcla_exp
	d.metalurgia_exp = metalurgia_exp
	d.peleteria_exp = peleteria_exp
	d.herreria_exp = herreria_exp
	d.esquivas_exp = esquivas_exp
	d.hechizos_exp = hechizos_exp
	d.recitado_exp = recitado_exp
	d.dano_recibido_exp = dano_recibido_exp
	d.pack_inicial = pack_inicial_reclamado
	d.bosses_derrotados = bosses_derrotados.duplicate()

	d.crystals = crystals.duplicate()
	d.materiales = materiales.duplicate()
	d.almacen_materiales = almacen_materiales.duplicate()
	d.owned_weapons = owned_weapons.duplicate()
	d.owned_armor = owned_armor.duplicate()
	d.owned_mochilas = owned_mochilas.duplicate()
	d.equipped_mochila = equipped_mochila

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
	d.hacha = hacha().resource_path
	d.materiales_vistos = materiales_vistos.duplicate()

	d.en_mazmorra = en_mazmorra
	d.current_floor = current_floor
	if player is Node2D:
		d.pos_jugador = (player as Node2D).global_position
	d.memoria_pisos = memoria_pisos.duplicate(true)
	d.mazmorra_persistente = mazmorra_persistente.duplicate(true)
	d.mapa_snapshot = mapa_snapshot.duplicate(true)
	d.tiempo_mazmorra = tiempo_mazmorra

	# Cabecera (lo que se ve en la lista de ranuras).
	d.fecha = Time.get_datetime_string_from_system(false, true)
	d.cab_nivel = player_level
	d.cab_piso = current_floor
	d.cab_dinero = money
	d.cab_lugar = ("Mazmorra · piso %d" % current_floor) if en_mazmorra else "Pueblo"
	return d


func importar_partida(d: SaveData) -> void:
	semilla_mundo = d.semilla_mundo
	player_nombre = d.nombre if d.nombre.strip_edges() != "" else NOMBRE_POR_DEFECTO
	player_color = d.color
	player_metalico = d.metalico

	ability_internal = d.ability_internal.duplicate()
	player_level = d.player_level
	ability_base_nivel = d.ability_base_nivel.duplicate() if d.ability_base_nivel else {
		"fuerza": 0.0, "resistencia": 0.0, "destreza": 0.0, "agilidad": 0.0, "magia": 0.0}
	player_base_hp = d.player_base_hp
	player_base_attack = d.player_base_attack
	player_base_defense = d.player_base_defense
	player_base_magic = d.player_base_magic
	player_base_speed = d.player_base_speed
	player_base_mp = d.player_base_mp
	player_base_magia_factor = d.player_base_magia_factor
	player_base_crit = d.player_base_crit
	desarrollos_elegidos = d.desarrollos_elegidos.duplicate()
	guardianes_vencidos = d.guardianes_vencidos.duplicate()
	# Re-encender los interruptores de OFICIO segun los desarrollos elegidos (no se guardan aparte).
	for _id in desarrollos_elegidos:
		match str(_id):
			"metalurgia": habilidad_metalurgia = true
			"peleteria": habilidad_peleteria = true
			"herreria": habilidad_herreria = true
			"mezcla": habilidad_mezcla = true
	actualizar_estado()   # las stats VISIBLES se derivan de las internas, no se guardan aparte
	player_current_hp = d.player_current_hp
	player_current_mp = d.player_current_mp
	money = d.money
	mezcla_exp = d.mezcla_exp
	metalurgia_exp = d.metalurgia_exp
	peleteria_exp = d.peleteria_exp
	herreria_exp = d.herreria_exp
	esquivas_exp = d.esquivas_exp
	hechizos_exp = d.hechizos_exp
	recitado_exp = d.recitado_exp
	dano_recibido_exp = d.dano_recibido_exp
	pack_inicial_reclamado = d.pack_inicial
	bosses_derrotados = d.bosses_derrotados.duplicate()
	# El historial de recompra es de SESION: cargar partida no te devuelve el mostrador del
	# tendero tal y como lo dejaste hace tres dias.
	recompra.clear()

	crystals.assign(d.crystals)
	materiales.assign(d.materiales)
	almacen_materiales.assign(d.almacen_materiales)
	owned_weapons.assign(d.owned_weapons)
	owned_armor.assign(d.owned_armor)
	owned_mochilas.assign(d.owned_mochilas)

	equipped_main = d.equipped_main
	equipped_off = d.equipped_off
	equipped_casco = d.equipped_casco
	equipped_pecho = d.equipped_pecho
	equipped_manos = d.equipped_manos
	equipped_pantalones = d.equipped_pantalones
	equipped_botas = d.equipped_botas
	equip_meta = d.equip_meta.duplicate(true)
	equipped_mochila = d.equipped_mochila as BackpackData
	# extra_capacity se REDERIVA de la mochila (mas abajo, cuando item_meta ya este rearmada:
	# la capacidad depende del tier/rareza, que viven ahi).

	# Rearmamos item_meta con los MISMOS objetos que hay en el baul/equipo: Godot ha
	# conservado la identidad, asi que la espada equipada y la del baul siguen siendo una.
	item_meta.clear()
	for i in range(mini(d.meta_items.size(), d.meta_datos.size())):
		item_meta[d.meta_items[i]] = (d.meta_datos[i] as Dictionary).duplicate(true)

	# Ya con la meta rearmada: la capacidad de la mochila sale de su tier y su rareza.
	extra_capacity = capacidad_mochila()

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
	# Las partidas de antes de la madera no tienen hacha guardada: _cargar_tool cae al respaldo.
	equipped_hacha = _cargar_tool(d.hacha, HACHA_BASICA)

	# Lo descubierto. Las partidas de antes de esto lo traen vacio, asi que se reconstruye de lo
	# que tengas encima o en el baul: si no, un veterano con el baul lleno de hierro abriria la
	# forja y no veria ni el hierro.
	materiales_vistos = d.materiales_vistos.duplicate()
	for lista in [materiales, almacen_materiales]:
		for it in lista:
			if it != null:
				descubrir((it as MaterialItem).data)

	current_floor = d.current_floor
	memoria_pisos = d.memoria_pisos.duplicate(true)
	mazmorra_persistente = d.mazmorra_persistente.duplicate(true)
	mapa_snapshot = d.mapa_snapshot.duplicate(true)
	tiempo_mazmorra = d.tiempo_mazmorra
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
	# Y PIERDES lo que cartografiaste esta expedicion: el mapa vuelve al baseline de cuando entraste.
	revertir_mapa_expedicion()

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
# ============================================================
#  BOSSES: los hitos de la mazmorra
#  Un boss guarda una sala (la central de su piso) y BLOQUEA la bajada. Matarlo la primera vez
#  es un HITO PERMANENTE de la partida: a partir de ahi ese piso tiene bajada, tiene salida al
#  pueblo, y se puede saltar a el desde la entrada de la mazmorra.
#
#  El boss SIGUE apareciendo despues (por su botin, que es el mejor del juego), pero ya no
#  bloquea nada: lo que se gana no se pierde. Por eso esto NO vive en memoria_pisos (que se
#  borra en cada expedicion) sino en la PARTIDA.
# ============================================================

# {piso: EnemyData} — que boss guarda cada piso. El unico por ahora: el Rey Slime, en el 5.
const BOSSES := {5: "res://scenes/actors/enemy/rey_slime.tres"}

# {piso: true} de los bosses YA derrotados alguna vez en esta partida. Se guarda en SaveData.
var bosses_derrotados: Dictionary = {}

func boss_del_piso(piso: int) -> EnemyData:
	if not BOSSES.has(piso):
		return null
	return load(BOSSES[piso]) as EnemyData

func boss_derrotado(piso: int) -> bool:
	return bool(bosses_derrotados.get(piso, false))

# El piso esta CERRADO si tiene boss y no lo has matado nunca: sin bajada y sin salida.
func piso_bloqueado(piso: int) -> bool:
	return BOSSES.has(piso) and not boss_derrotado(piso)

# Lo llama el enemigo al morir (enemy.gd) si era el boss de su piso.
func marcar_boss_derrotado(piso: int) -> void:
	if boss_derrotado(piso):
		return
	bosses_derrotados[piso] = true
	print("[mazmorra] ¡Boss del piso %d derrotado! Se abren la bajada y la salida al pueblo." % piso)

# Pisos a los que se puede SALTAR desde la entrada de la mazmorra: el 1 siempre, y cada piso
# cuyo boss hayas matado (ese es el premio del boss: no volver a caminar lo ya caminado).
func pisos_desbloqueados() -> Array:
	var out: Array = [1]
	for piso in BOSSES:
		if boss_derrotado(piso) and not out.has(piso):
			out.append(piso)
	out.sort()
	return out


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
	# Cartografia el piso que ABANDONAS antes de cambiar de piso: current_floor y el gen vivo aun
	# son los viejos aqui. Sin esto, la libreta solo se actualizaba al volver al pueblo (piso 1) y
	# el mapa salia "sin cartografiar" del piso 2 en adelante.
	capturar_mapa()
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
# Mochilas poseidas (van aparte: no son equipo de combate, tienen su propio slot).
var owned_mochilas: Array[BackpackData] = []

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
# DEV: TODOS los materiales, para sembrar el baul en pruebas. No solo los de pociones (babas
# y hierbas): tambien nucleos, cuero y mineral, para poder probar luego las mejoras y el
# crafteo de armas/armaduras.
var _dev_materiales: Array[String] = [
	# Babas (pociones)
	"res://resources/materials/baba_slime.tres",
	"res://resources/materials/baba_venenosa.tres",
	"res://resources/materials/baba_fuego.tres",
	# Hierbas (pociones)
	"res://resources/materials/hierba_palida.tres",
	"res://resources/materials/raiz_amarga.tres",
	# Minerales
	"res://resources/materials/cobre.tres",
	"res://resources/materials/hierro.tres",
	"res://resources/materials/acero.tres",
	# Cuero
	"res://resources/materials/cuero_simple.tres",
	# Nucleos de ARMA (slime +3 / venenoso +5 / fuego +7)
	"res://resources/materials/nucleo_slime.tres",
	"res://resources/materials/nucleo_venenoso.tres",
	"res://resources/materials/nucleo_fuego.tres",
	# Nucleos de ARMADURA (rata +3 / rey rata +5 / jabali +7): la misma escalera, en la otra rama
	"res://resources/materials/nucleo_rata.tres",
	"res://resources/materials/nucleo_rey_rata.tres",
	"res://resources/materials/nucleo_jabali.tres",
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

# MEZCLA (調合): parametro OCULTO que sube cada vez que CRAFTEAS pociones (no al comprarlas).
# Semilla de una futura habilidad de desarrollo estilo DanMachi: "Mezcla" mejora la calidad
# al crear objetos. De momento solo se acumula y se guarda; el efecto se ajustara despues.
var mezcla_exp: float = 0.0
const MEZCLA_EXP_POR_POCION := 1.0   # PROVISIONAL: cuanto sube por poción fabricada

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

# --- HERRAMIENTAS DE RECOLECCION: pico (vetas), hoz (plantas) y hacha (madera) ---
# Slots APARTE: no ocupan mano, no pesan y no entran en el combate. Una herramienta mejor
# no sube tu stat, solo hace el minijuego menos hostil (ver ToolData). Se arranca con las
# basicas; la tienda vendera mejores.
const PICO_BASICO := preload("res://resources/tools/pico_basico.tres")
const HOZ_BASICA := preload("res://resources/tools/hoz_basica.tres")
const HACHA_BASICA := preload("res://resources/tools/hacha_basica.tres")

var equipped_pico: ToolData = null
var equipped_hoz: ToolData = null
var equipped_hacha: ToolData = null

func pico() -> ToolData:
	return equipped_pico if equipped_pico != null else (PICO_BASICO as ToolData)

func hoz() -> ToolData:
	return equipped_hoz if equipped_hoz != null else (HOZ_BASICA as ToolData)

func hacha() -> ToolData:
	return equipped_hacha if equipped_hacha != null else (HACHA_BASICA as ToolData)

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
	"main": {"tier": 1, "rareza": Upgrades.Rareza.COMUN, "mejoras": {}, "durabilidad": 1.0},
	"off": {"tier": 1, "rareza": Upgrades.Rareza.COMUN, "mejoras": {}, "durabilidad": 1.0},
	"casco": {"tier": 1, "rareza": Upgrades.Rareza.COMUN, "mejoras": {}, "durabilidad": 1.0},
	"pecho": {"tier": 1, "rareza": Upgrades.Rareza.COMUN, "mejoras": {}, "durabilidad": 1.0},
	"manos": {"tier": 1, "rareza": Upgrades.Rareza.COMUN, "mejoras": {}, "durabilidad": 1.0},
	"pantalones": {"tier": 1, "rareza": Upgrades.Rareza.COMUN, "mejoras": {}, "durabilidad": 1.0},
	"botas": {"tier": 1, "rareza": Upgrades.Rareza.COMUN, "mejoras": {}, "durabilidad": 1.0},
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
	return {"tier": 1, "rareza": Upgrades.Rareza.COMUN, "mejoras": {}, "durabilidad": 1.0}


func _meta(slot: String) -> Dictionary:
	return equip_meta[slot]
func equip_tier(slot: String) -> int:
	return int(equip_meta[slot]["tier"])
func equip_rareza(slot: String) -> int:
	return int(equip_meta[slot]["rareza"])
func equip_mejoras(slot: String) -> Dictionary:
	return equip_meta[slot]["mejoras"]

# ============================================================
#  DURABILIDAD / MANTENIMIENTO
#  El equipo se gasta al usarlo (arma por golpe dado, armadura por golpe recibido), penaliza
#  en combate segun lo gastado (con TOPE) y se ROMPE al llegar a 0 (penalizacion en acantilado).
#  Se repara pagando en el Herrero. La durabilidad vive en la meta por instancia (fraccion
#  0..1, 1.0 = llena), asi persiste sola y la comparten el item equipado y su copia del baul.
#  Guardamos FRACCION (no puntos): la mejora de Durabilidad sube el MAXIMO y hace que cada
#  golpe reste MENOS fraccion (dura mas), sin que reparar por % cueste mas por tener mas maximo.
# ============================================================
# El MAXIMO se monta TODO por PORCENTAJES sobre una base pequeña (ver max_durabilidad):
#   base × (tier) × (mejoras de Durabilidad) × (rareza)
# Por porcentajes A PROPOSITO: con bonos FLAT, un +30 se notaba cada vez menos segun crecia la
# base (sobre 100 es +30%, sobre una t2 de 140 ya solo +21%). Multiplicando, una mejora de
# Durabilidad rinde SIEMPRE lo mismo (+30%) la metas en una t1 comun o en una t3 obra maestra.
const DURABILIDAD_BASE := 10.0         # puntos de aguante de un item T1 COMUN sin mejoras
const DURABILIDAD_TIER_PCT := 0.40     # +40% de aguante por cada tier por encima de T1
const DURABILIDAD_MEJORA_PCT := 0.30   # +30% de aguante por cada mejora de Durabilidad
# Desgaste en PUNTOS (se convierte a fraccion dividiendo por el maximo, asi mas maximo = dura
# mas). A escala de la base de 10: un arma T1 comun aguanta 10/0.04 = 250 golpes (~2-3 expediciones).
const DESGASTE_ARMA := 0.04            # puntos que pierde el arma por golpe DADO
const DESGASTE_ARMOR := 0.08           # puntos que pierde CADA pieza por golpe RECIBIDO
const PENAL_MAX := 0.25                # tope de penalizacion mientras esta gastada (no rota)
const PENAL_ROTO := 0.75               # penalizacion al estar ROTA (acantilado): rinde el 25%
# Precio de reparar = coste_full × (% roto). coste_full sube SUAVE con tier y nº de mejoras
# (casi lineal, NO exponencial). Reparar por fraccion hace que mas maximo NO encarezca.
const REPARA_BASE := 15.0
const REPARA_K_TIER := 0.5
const REPARA_K_MEJ := 0.12

# Maximo de durabilidad (en puntos) de un slot equipado (arma o pieza de armadura, mismo modelo).
# TODO multiplicativo: el TIER, las mejoras de Durabilidad y la RAREZA son porcentajes sobre la
# base, asi cada uno rinde lo mismo en proporcion sin importar lo alto que este ya el maximo.
# Mas maximo = dura mas y cada golpe resta menos fraccion; NO encarece reparar (el precio es por
# % roto), asi que tier/rareza ademas abaratan el mantenimiento (reparas menos veces).
func max_durabilidad(slot: String) -> float:
	var tier: int = maxi(equip_tier(slot), 1)
	var n: int = int((equip_mejoras(slot) as Dictionary).get(Upgrades.DURABILIDAD, 0))
	return DURABILIDAD_BASE \
		* (1.0 + float(tier - 1) * DURABILIDAD_TIER_PCT) \
		* (1.0 + float(n) * DURABILIDAD_MEJORA_PCT) \
		* Upgrades.rareza_mult(equip_rareza(slot))

# Fraccion de durabilidad de un slot (1.0 llena, 0.0 rota). Retrocompat: sin la clave = llena.
func durabilidad_slot(slot: String) -> float:
	return clampf(float((equip_meta[slot] as Dictionary).get("durabilidad", 1.0)), 0.0, 1.0)

# Multiplicador de rendimiento por desgaste (daño del arma / proteccion de la pieza).
# Gastada: rampa lineal con TOPE PENAL_MAX. Rota (frac<=0): acantilado a 1-PENAL_ROTO.
func durabilidad_mult(frac: float) -> float:
	if frac <= 0.0:
		return 1.0 - PENAL_ROTO
	return 1.0 - PENAL_MAX * (1.0 - clampf(frac, 0.0, 1.0))

# Resta desgaste a un slot (arma/pieza), en fraccion = puntos/max. No baja de 0 (roto).
func _desgastar_slot(slot: String, puntos: float) -> void:
	if not equip_meta.has(slot):
		return
	var maxd: float = max_durabilidad(slot)
	if maxd <= 0.0:
		return
	var frac: float = durabilidad_slot(slot) - puntos / maxd
	equip_meta[slot]["durabilidad"] = clampf(frac, 0.0, 1.0)

# Desgasta el ARMA de la mano indicada ("main"/"off") por un golpe dado. Los puños (sin arma)
# no se gastan (no hay pieza equipada de verdad).
func desgastar_arma(slot: String) -> void:
	if slot == "main" and equipped_main == null:
		return
	if slot == "off" and not (equipped_off is WeaponData):
		return
	_desgastar_slot(slot, DESGASTE_ARMA)

# Desgasta TODAS las piezas de armadura equipadas por un golpe recibido (un poco cada una).
func desgastar_armadura() -> void:
	for slot in ["casco", "pecho", "manos", "pantalones", "botas"]:
		if _pieza_equipada(slot) != null:
			_desgastar_slot(slot, DESGASTE_ARMOR)

func _pieza_equipada(slot: String) -> ArmorData:
	match slot:
		"casco": return equipped_casco
		"pecho": return equipped_pecho
		"manos": return equipped_manos
		"pantalones": return equipped_pantalones
		"botas": return equipped_botas
	return null

# Precio de reparar un slot al 100%: coste_full × fraccion rota (0 si esta llena).
func precio_reparar(slot: String) -> int:
	var frac: float = durabilidad_slot(slot)
	if frac >= 1.0:
		return 0
	var tier: int = equip_tier(slot)
	var n: int = Upgrades.total_mejoras(equip_mejoras(slot))
	var coste_full: float = REPARA_BASE * (1.0 + float(tier) * REPARA_K_TIER) * (1.0 + float(n) * REPARA_K_MEJ)
	return maxi(1, int(round(coste_full * (1.0 - frac))))

# Repara un slot al 100% cobrando su precio. false si ya esta lleno o no puedes pagar.
func reparar_slot(slot: String) -> bool:
	var precio: int = precio_reparar(slot)
	if precio <= 0:
		return false
	if not gastar(precio):
		return false
	equip_meta[slot]["durabilidad"] = 1.0
	return true

# Slots reparables (equipados y dañados). El puño (main vacio) no cuenta.
func _slots_reparables() -> Array:
	var out: Array = []
	for slot in ["main", "off", "casco", "pecho", "manos", "pantalones", "botas"]:
		if _slot_es_equipo(slot) and precio_reparar(slot) > 0:
			out.append(slot)
	return out

# True si el slot tiene una pieza reparable equipada (arma/armadura de verdad, no puños/escudo/varita).
func _slot_es_equipo(slot: String) -> bool:
	match slot:
		"main": return equipped_main != null
		"off": return equipped_off is WeaponData
		_: return _pieza_equipada(slot) != null

# Coste total de reparar todo el equipo dañado.
func precio_reparar_todo() -> int:
	var total: int = 0
	for slot in _slots_reparables():
		total += precio_reparar(slot)
	return total

# Repara TODO el equipo dañado si puedes pagar la suma. Devuelve lo gastado (0 si no llega/nada).
func reparar_todo() -> int:
	var total: int = precio_reparar_todo()
	if total <= 0 or not gastar(total):
		return 0
	for slot in _slots_reparables():
		equip_meta[slot]["durabilidad"] = 1.0
	return total

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
	"res://resources/spells/descarga.tres",
	"res://resources/spells/brasa.tres",
	"res://resources/spells/rocio.tres",
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
	return StatsMath.max_mp_value(a, player_level, player_base_mp)

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

# USAR un consumible del inventario (lo que hace el boton "Usar"): una poción se BEBE, un
# grimorio se ESTUDIA. Punto unico para que la UI no tenga que saber cual es cual.
func usar_consumible(c: ConsumableData) -> bool:
	if c == null:
		return false
	if c.es_grimorio():
		return aprender_de_grimorio(c)
	return beber_pocion_fuera(c)

# Estudia un grimorio: aprendes su hechizo y el libro se gasta. Si ya te lo sabias o tienes
# la cabeza llena (MAX_HECHIZOS), NO se gasta: un libro caro no se quema por un clic tonto.
func aprender_de_grimorio(c: ConsumableData) -> bool:
	if c == null or not c.es_grimorio():
		return false
	if equipped_spells.has(c.spell):
		print("[grimorio] Ya te sabes %s: no abres el libro." % c.spell.nombre)
		return false
	if hechizos_llenos():
		print("[grimorio] No te caben mas de %d hechizos: olvida uno antes." % MAX_HECHIZOS)
		return false
	if not gastar_consumible(c):
		return false
	equipar_hechizo(c.spell)
	print("[grimorio] Estudias %s y aprendes %s (%d/%d hechizos)." % [
		c.nombre, c.spell.nombre, equipped_spells.size(), MAX_HECHIZOS])
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

# Turnos en los que se reparte, al ENTRAR en combate, la cura de poción que quedaba pendiente
# fuera de combate (player_heal_left). Simétrico al arrastre de salida: una poción bebida en el
# mapa sigue curando dentro (como Regeneración) en vez de perderse al pausarse el goteo. PROVISIONAL.
const POCION_ARRASTRE_TURNOS := 3

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

# NO hay regen PASIVA de maná por el mapa (antes: "lo de un turno" por segundo). Se quito a
# proposito: el jugador se plantaba quieto mirando la barra, y eso no es una decision, es una
# espera. El maná se recupera JUGANDO — pegando y ganando combates (ver combat.gd) —, bebiendo
# pociones de maná (tick_mana_pocion) o descansando en el altar del pueblo.

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
# gastando player_mana_heal_left. Es la UNICA via de recuperar maná fuera de combate (ya no
# hay regen pasiva), junto al altar del pueblo.
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

# Cuantos hechizos caben en la cabeza a la vez. Aprender no es gratis: al llegar al tope hay
# que OLVIDAR uno para meter otro (el objeto que devuelve un hechizo a su libro vendra luego,
# caro o dificil de fabricar a proposito: cambiar de repertorio tiene que doler).
const MAX_HECHIZOS := 7

func hechizos_llenos() -> bool:
	return equipped_spells.size() >= MAX_HECHIZOS

# Aprende un hechizo. false si ya lo sabias o si tienes la cabeza llena (MAX_HECHIZOS).
func equipar_hechizo(spell: SpellData) -> bool:
	if spell == null or equipped_spells.has(spell) or hechizos_llenos():
		return false
	equipped_spells.append(spell)
	return true

func quitar_hechizo(spell: SpellData) -> void:
	equipped_spells.erase(spell)

# --- Peso / capacidad de carga ---
# De serie llevas un ZURRON pequeño (base_capacity). La Fuerza sube la capacidad.
var base_capacity: float = 25.0        # zurron de serie
# Lo que suma la MOCHILA (y, algun dia, un compañero de apoyo). Ya NO es un placeholder: lo
# rellena la mochila equipada (ver capacidad_mochila).
var extra_capacity: float = 0.0

# --- MOCHILA (slot propio; no es equipo de combate) ---
# La UNICA cosa que sube la capacidad de carga. La basica suma +15 sobre los 25 del zurron;
# el TIER y la RAREZA la escalan. No se mejora con nucleos: los nucleos son para matar y
# aguantar, no para llevar mas trastos.
var equipped_mochila: BackpackData = null

# Cuanto suma ESTA mochila, con su tier y su rareza. El TIER es el eje gordo (bajar a por metal
# mejor tiene que notarse), y el salto se ACELERA: sobre la basica de +15, un T2 da +25 y un T3
# +40. Es una tabla y no una formula a proposito: los saltos son una decision de diseño (15/25/40),
# no el resultado de una curva que haya que adivinar. Nada de tier_mult del combate, que es
# geometrico y dispararia la carga.
const MOCHILA_CAPACIDAD_TIER := [15.0, 25.0, 40.0]

# Factor del tier respecto a la mochila base: sale de la tabla de arriba, nunca a mano.
func mochila_tier_factor(tier: int) -> float:
	var t: int = clampi(tier, 1, MOCHILA_CAPACIDAD_TIER.size())
	return float(MOCHILA_CAPACIDAD_TIER[t - 1]) / float(MOCHILA_CAPACIDAD_TIER[0])

func capacidad_mochila(m: BackpackData = null) -> float:
	var mo: BackpackData = m if m != null else equipped_mochila
	if mo == null:
		return 0.0
	var meta: Dictionary = meta_de(mo)
	return mo.capacidad * mochila_tier_factor(int(meta["tier"])) \
		* Upgrades.rareza_mult_capacidad(int(meta["rareza"]))

func equipar_mochila(m: BackpackData) -> void:
	equipped_mochila = m
	extra_capacity = capacidad_mochila()

# Lo que llevarias CON esta mochila puesta (para comparar en el menu antes de equiparla). No es
# una suma a pelo: la Fuerza multiplica el contenedor entero, mochila incluida.
func capacidad_con_mochila(m: BackpackData) -> float:
	var contenedor: float = base_capacity + capacidad_mochila(m)
	var mult: float = 1.0 + clampf(player_fuerza / 999.0, 0.0, 1.0) * fuerza_capacity_bonus_max
	return contenedor * mult
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
	var c := Combatant.new(player_nombre, player_level, a,
		player_base_hp, player_base_attack, player_base_defense, player_base_speed)
	c.base_magic = player_base_magic
	# Bakeos de nivel: crítico plano (Destreza), factor de daño mágico y maná base (Magia).
	c.crit_flat = player_base_crit
	c.magia_base_factor = player_base_magia_factor
	c.max_mp = StatsMath.max_mp_value(a, player_level, player_base_mp)
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

	# PERKS de combate (habilidades de desarrollo). Van los ULTIMOS, encima de lo que dan el equipo
	# y la armadura: son tuyos, no del loadout, asi que no dependen de lo que lleves puesto. Se leen
	# en vivo de desarrollos_elegidos (no hay interruptor que guardar).
	if desarrollos_elegidos.has("reflejos"):
		c.evasion_penal -= REFLEJOS_EVASION   # la esquiva va como PENAL: negativo = esquivas mas
	if desarrollos_elegidos.has("erudito"):
		c.magic_amp *= 1.0 + ERUDITO_MAGIA
	if desarrollos_elegidos.has("encantamiento_rapido"):
		c.cast_velocidad_mult *= 1.0 + ENCANT_RAPIDO


# Combina la mano principal + la secundaria en los modificadores finales de
# combate. La secundaria aporta VELOCIDAD (dual) o BLOQUEO/penalizacion (escudo).
func loadout_mods() -> Dictionary:
	var main: WeaponData = arma_main()   # sin arma equipada -> los puños
	# Mods del arma principal ya RESUELTOS (base × rareza + mejoras): de aqui salen la evasion y
	# el bloqueo escalados por rareza, en vez de los campos crudos del .tres. Antes la rareza no
	# tocaba la esquiva ni el bloqueo (una daga obra maestra esquivaba igual que una comun).
	var main_wm := Upgrades.weapon_mods(main, tier_mult(equip_tier("main")),
		equip_rareza("main"), equip_mejoras("main"))
	# Mods COMPARTIDOS (del loadout entero) + lista de MANOS (armas que alternan).
	var m := {
		"velocidad_mult": main.velocidad_mult,
		"defend_block": DEFEND_BLOCK_BASE,
		# El arma principal define lo escurridizo que eres (daga = +esquiva). Un
		# evasion_penal NEGATIVO = bonus de esquiva (los escudos suman penal, encima).
		"evasion_penal": -float(main_wm["evasion"]),
		"hands": [_hand_from(main, "main")],   # mano principal siempre
	}
	if main.dos_manos:
		# Arma grande a dos manos: sin secundaria, pero bloquea decente por su tamaño.
		m["defend_block"] += float(main_wm["bloqueo"])
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
		# El bloqueo de la secundaria tambien escala con SU rareza (mods de su slot).
		var off_wm := Upgrades.weapon_mods(off, tier_mult(equip_tier("off")),
			equip_rareza("off"), equip_mejoras("off"))
		m["defend_block"] += float(off_wm["bloqueo"])   # bloqueo mediocre con arma
		# Dual: la secundaria es la 2ª mano -> se alterna con la principal golpe a
		# golpe. Cada arma conserva su MV/crit/aturdir propios (no se promedian).
		(m["hands"] as Array).append(_hand_from(off, "off"))
	# else: mano secundaria vacia -> una sola mano (la principal).
	# RAPIDEZ (mejora del arma principal): multiplica la velocidad final (capada).
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


# Extrae los datos POR MANO de un arma (lo que cambia golpe a golpe en dual). Todo sale ya
# RESUELTO de Upgrades.weapon_mods (base × rareza + mejoras × tier del slot): el crit y el
# aturdir ya llevan dentro el campo base del arma, no se le suman aparte (antes se cogian en
# crudo del .tres y la rareza no los tocaba -> obra maestra daba el mismo critico que comun).
func _hand_from(w: WeaponData, slot: String) -> Dictionary:
	var wm := Upgrades.weapon_mods(w, tier_mult(equip_tier(slot)),
		equip_rareza(slot), equip_mejoras(slot))
	# DURABILIDAD: un arma gastada pega menos (con tope), y rota se va a los suelos. Solo toca
	# el raw (su daño); no altera motion_value/crit/identidad. Los puños (main null) no se gastan.
	var dur_mult: float = durabilidad_mult(durabilidad_slot(slot)) if w != null else 1.0
	return {
		"nombre": w.nombre,
		"slot": slot,   # para saber que arma desgastar al golpear (main/off)
		"motion_value": w.motion_value,
		"ataque_arma": float(wm["raw"]) * dur_mult,
		"crit_bonus": float(wm["crit"]),
		"crit_dmg": float(wm["crit_dmg"]),
		"precision": wm["precision"],
		"dano_tipo": int(w.dano_tipo),
		"aturdir_base": float(wm["aturdir"]),
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
	var rareza_max := 0        # la mejor rareza entre las piezas: escala los topes agregados
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
		rareza_max = maxi(rareza_max, equip_rareza(slot))
		var pm := Upgrades.armor_piece_mods(pieza, tier_mult(equip_tier(slot)),
			equip_rareza(slot), equip_mejoras(slot))
		# DURABILIDAD: una pieza gastada protege menos (con tope), y rota se va a los suelos.
		# Solo toca lo defensivo (DEF y reduccion), no la esquiva/velocidad/identidad.
		var dur_mult: float = durabilidad_mult(durabilidad_slot(slot))
		def_bonus += float(pm["def"]) * dur_mult             # DEF (tier×rareza×mejoras), sin techo
		reduction += cob * float(pm["reduccion"]) * dur_mult # media ponderada (cobertura suma 1.0)
		vel_delta += cob * (float(pm["vel_mult"]) - 1.0)     # velocidad ponderada
		evasion += float(pm["evasion"])
		crit_resist += float(pm["crit_resist"])
		resist_estados += float(pm["resist_estados"])
	# Los topes agregados suben con la MEJOR rareza equipada (la reduccion NO: es de tipo, y su
	# techo es de balance, no de calidad).
	reduction = clampf(reduction, 0.0, StatsMath.ARMOR_REDUCTION_MAX)
	evasion = clampf(evasion, 0.0, Upgrades.cap_rareza(Upgrades.EVASION_CAP, rareza_max))
	crit_resist = clampf(crit_resist, 0.0, Upgrades.cap_rareza(Upgrades.RESIST_CRIT_CAP, rareza_max))
	resist_estados = clampf(resist_estados, 0.0, Upgrades.cap_rareza(Upgrades.RESISTENCIA_CAP, rareza_max))
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
	elif copia is BackpackData:
		if not owned_mochilas.has(copia):
			owned_mochilas.append(copia as BackpackData)
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
#  TIENDA: dinero, venta (bolsa/hogar/equipo), recompra, compra y PACK INICIAL
#  Toda la math vive aqui; shop_menu.gd solo pinta.
# ============================================================

func puede_pagar(precio: int) -> bool:
	return money >= precio

func ingresar(n: int) -> void:
	money += maxi(0, n)

# Cobra `precio` (false y no cobra nada si no llegas).
func gastar(precio: int) -> bool:
	if precio < 0 or not puede_pagar(precio):
		return false
	money -= precio
	return true

# Precio de COMPRA de una plantilla (arma/escudo/varita/armadura/poción/grimorio). Es el
# precio a T1/Comun, que es lo unico que el tendero vende: lo bueno sale de la forja.
func precio_compra(base: Resource) -> int:
	if base == null:
		return 0
	return maxi(0, int(base.get("valor_base")))

# Lo que el tendero PAGA por tu equipo usado: una fraccion del precio de tienda. Ese mismo
# importe es el que costara RECOMPRARLO (no hay margen: el tendero te lo guarda, no te lo
# revende con recargo).
const REVENTA_EQUIPO := 0.4

func precio_venta_equipo(item: Resource) -> int:
	if item == null:
		return 0
	# El tier y las mejoras suben el valor: no es lo mismo una daga recien comprada que una
	# daga T3 +4. La rareza no toca aqui (solo abre huecos de mejora, ya contados en `n`).
	var m: Dictionary = meta_de(item)
	var mult: float = tier_mult(int(m["tier"])) * (1.0 + 0.25 * float(Upgrades.total_mejoras(m["mejoras"])))
	return maxi(1, int(round(precio_compra(item) * mult * REVENTA_EQUIPO)))

# Precio de venta de un item de bolsa/hogar (cristal o material). Es su valor_estimado tal
# cual: lo que el inventario ya te enseña es lo que te pagan, sin sorpresas.
func precio_venta_item(item: Resource) -> int:
	if item == null:
		return 0
	return maxi(0, int(item.call("valor_estimado")))


# --- VENDER cristales/materiales ---
# Vende `cantidad` unidades equivalentes a `modelo`, sacandolas de la BOLSA o del baul del
# HOGAR (desde_hogar). Devuelve lo cobrado.
func vender_item(modelo: Resource, cantidad: int, desde_hogar: bool = false) -> int:
	if modelo == null or cantidad <= 0:
		return 0
	var total: int = 0
	var vendidos: int = 0
	while vendidos < cantidad:
		var item: Resource = _sacar_del_hogar(modelo) if desde_hogar else _sacar_de_bolsa(modelo)
		if item == null:
			break
		total += precio_venta_item(item)
		vendidos += 1
	if vendidos > 0:
		ingresar(total)
		print("[tienda] Vendes %d x %s por %d. Dinero: %d" % [
			vendidos, _nombre_item(modelo), total, money])
	return total

# Saca del baul del hogar UNA unidad equivalente al modelo (gemelo de _sacar_de_bolsa).
func _sacar_del_hogar(modelo: Resource) -> Resource:
	if not (modelo is MaterialItem):
		return null
	var mm := modelo as MaterialItem
	for i in almacen_materiales.size():
		var m := almacen_materiales[i]
		if m.data == mm.data and m.calidad == mm.calidad:
			almacen_materiales.remove_at(i)
			return m
	return null

# Lo que te pagan por una poción/grimorio: la misma fraccion que por el equipo. No van al
# mostrador de recompra (son apilables y el tendero los vende de serie: si te arrepientes,
# vuelves a comprarlos en la pestaña Tienda).
func precio_venta_consumible(c: ConsumableData) -> int:
	if c == null:
		return 0
	return maxi(1, int(round(precio_compra(c) * REVENTA_EQUIPO)))

# Vende n unidades de una poción/grimorio del inventario. Devuelve lo cobrado.
func vender_consumible(c: ConsumableData, n: int) -> int:
	if c == null or n <= 0:
		return 0
	var vendidos: int = 0
	while vendidos < n and gastar_consumible(c):
		vendidos += 1
	if vendidos <= 0:
		return 0
	var total: int = precio_venta_consumible(c) * vendidos
	ingresar(total)
	print("[tienda] Vendes %d x %s por %d. Dinero: %d" % [vendidos, c.nombre, total, money])
	return total


# Vacia la bolsa de cristales de un clic (lo que hacia la tienda vieja).
func vender_todos_cristales() -> int:
	if crystals.is_empty():
		return 0
	var total: int = 0
	for c in crystals:
		total += precio_venta_item(c)
	var n: int = crystals.size()
	crystals.clear()
	ingresar(total)
	print("[tienda] Vendes %d cristales por %d. Dinero: %d" % [n, total, money])
	return total


# --- VENDER equipo, con derecho a RECOMPRA ---
# Historial de lo que le has vendido al tendero: {item, precio}, el mas reciente al final.
# Es de SESION (no se guarda): el tendero no te guarda el trasto entre partidas. Al pasarse
# de RECOMPRA_MAX, lo mas viejo se pierde de verdad.
const RECOMPRA_MAX := 7
var recompra: Array = []

func vender_equipo(item: Resource) -> int:
	if item == null:
		return 0
	if item == equipped_main or item == equipped_off:
		print("[tienda] No vendes lo que llevas puesto: desequipalo antes.")
		return 0
	for slot in ARMOR_SLOT_ORDEN:
		if get("equipped_" + slot) == item:
			print("[tienda] No vendes lo que llevas puesto: desequipalo antes.")
			return 0
	var precio: int = precio_venta_equipo(item)
	if item is ArmorData:
		owned_armor.erase(item)
	else:
		owned_weapons.erase(item)
	recompra.append({"item": item, "precio": precio})
	while recompra.size() > RECOMPRA_MAX:
		recompra.pop_front()
	ingresar(precio)
	print("[tienda] Vendes %s por %d. Dinero: %d" % [item_display_name(item), precio, money])
	return precio

# Recompra la entrada `idx` del historial por lo mismo que te pagaron. El objeto vuelve TAL
# CUAL (misma instancia, misma item_meta): sigue siendo tu espada +3, no una copia nueva.
func recomprar(idx: int) -> bool:
	if idx < 0 or idx >= recompra.size():
		return false
	var e: Dictionary = recompra[idx]
	if not gastar(int(e["precio"])):
		return false
	var item: Resource = e["item"]
	if item is ArmorData:
		add_owned_armor(item as ArmorData)
	else:
		add_owned_weapon(item)
	recompra.remove_at(idx)
	print("[tienda] Recompras %s por %d. Dinero: %d" % [
		item_display_name(item), int(e["precio"]), money])
	return true


# --- COMPRAR ---
# Compra una pieza de equipo: sale del taller a T1/Comun/sin mejoras, con identidad propia.
func comprar_equipo(base: Resource) -> Resource:
	var precio: int = precio_compra(base)
	if not gastar(precio):
		return null
	var item: Resource = crear_item(base, 1, Upgrades.Rareza.COMUN, {})
	print("[tienda] Compras %s por %d. Dinero: %d" % [item_display_name(item), precio, money])
	return item

func comprar_consumible(base: ConsumableData, n: int = 1) -> bool:
	if base == null or n <= 0:
		return false
	var precio: int = precio_compra(base) * n
	if not gastar(precio):
		return false
	add_consumable(base, n)
	print("[tienda] Compras %d x %s por %d. Dinero: %d" % [n, base.nombre, precio, money])
	return true


# --- PACK INICIAL ---
# Regalo de bienvenida, UNA vez por partida: un arma a elegir (ni bastón ni varita: la magia
# te la pagas tu) y tres pociones menores. Es la red de seguridad de que nadie baje a la
# mazmorra a puños; a partir de ahi, la tienda cobra.
var pack_inicial_reclamado: bool = false

const PACK_ARMAS: Array[String] = [
	"res://resources/weapons/daga.tres",
	"res://resources/weapons/estoque.tres",
	"res://resources/weapons/espada_corta.tres",
	"res://resources/weapons/espada_larga.tres",
	"res://resources/weapons/maza_peq.tres",
	"res://resources/weapons/mandobles.tres",
	"res://resources/weapons/hacha_grande.tres",
	"res://resources/weapons/martillo_grande.tres",
]
const PACK_POCION := "res://resources/consumables/pocion_menor.tres"
const PACK_POCIONES_N := 3

func reclamar_pack_inicial(base_arma: Resource) -> bool:
	if pack_inicial_reclamado or base_arma == null:
		return false
	var arma: Resource = crear_item(base_arma, 1, Upgrades.Rareza.COMUN, {})
	var pocion: Resource = load(PACK_POCION)
	if pocion != null:
		add_consumable(pocion as ConsumableData, PACK_POCIONES_N)
	pack_inicial_reclamado = true
	print("[tienda] Reclamas el pack inicial: %s + %d pociones menores." % [
		item_display_name(arma), PACK_POCIONES_N])
	return true


# ============================================================
#  OFICIOS: REFINAR (herrero: fundir/batir · peletero: curtir), FORJAR y MEJORAR
#  La math vive en forge.gd; aqui solo el estado (que hay en el baul, que se consume).
#  Igual que la boticaria: todo sale del HOGAR, no de la bolsa.
#
#  La cadena:
#    mineral --fundir--> LINGOTE --batir--> CHAPA        (herrero)
#    cuero   --curtir--> CUERO CURTIDO                   (peletero)
#    ARMA     = lingote + cuero curtido
#    ARMADURA = chapa   + cuero curtido  (un paso mas: por eso es mas trabajo)
# ============================================================

# Las TRES habilidades de oficio, hermanas de la Mezcla de la boticaria. HOY NO EXISTEN COMO
# HABILIDAD: lo unico que hay es el CONTADOR OCULTO, que sube solo con el oficio y que sera lo
# que desbloquee la habilidad al subir de nivel. Hasta entonces los efectos estan ESCRITOS
# pero APAGADOS (ver habilidad_*): asi el dia que se desbloqueen, el que lleve mil lingotes
# fundidos ya se los ha ganado.
#   - Metalurgia: al refinar metal, tira por subir UN escalon la calidad (y con oficio de
#     sobra, un intacto puede salir PURO, que es una calidad que no se recolecta).
#   - Peleteria: lo mismo, con la piel.
#   - Herreria: al forjar, empuja la tirada de rareza a tu favor.
var metalurgia_exp: float = 0.0
var peleteria_exp: float = 0.0
var herreria_exp: float = 0.0

# Los contadores ocultos de los perks de COMBATE. Misma idea que los de oficio: suben SOLOS
# haciendo lo suyo, y son lo que decide si el perk te sale al subir de nivel (ver DESARROLLOS y
# _req_cumplido). A diferencia de los de oficio, estos no encienden ningun interruptor: el perk
# se consulta en vivo desde desarrollos_elegidos. El CAZADOR no tiene contador (solo sale en el
# primer ascenso). No se enseñan en ninguna UI: solo en el panel de debug.
var esquivas_exp: float = 0.0        # Reflejos: cada ataque que esquivas
var hechizos_exp: float = 0.0        # Erudito: cada hechizo que lanzas
var recitado_exp: float = 0.0        # Encantamiento rapido: cada frase de recitado acertada
var dano_recibido_exp: float = 0.0   # Autorregeneracion: el daño que encajas (acumula el daño)

# Lo que sube cada contador por cada cosa que haces. Los tres primeros van por VECES (1 por
# esquiva/hechizo/frase); el de la autorregeneracion va por DAÑO, asi que su umbral esta en otra
# escala. PROVISIONAL -> Excel. Combat.gd llama a estos, no toca los campos a pelo.
const ESQUIVA_POR_ESQUIVAR := 1.0
const HECHIZO_POR_LANZAR := 1.0
const RECITADO_POR_FRASE := 1.0

func contar_esquiva() -> void:
	esquivas_exp += ESQUIVA_POR_ESQUIVAR

func contar_hechizo() -> void:
	hechizos_exp += HECHIZO_POR_LANZAR

func contar_frase_recitada() -> void:
	recitado_exp += RECITADO_POR_FRASE

func contar_dano_recibido(dmg: float) -> void:
	dano_recibido_exp += maxf(0.0, dmg)
# Interruptores (los pondra a true el sistema de habilidades de desarrollo cuando exista).
# Con esto en false, el oficio solo ACUMULA.
var habilidad_metalurgia: bool = false
var habilidad_peleteria: bool = false
var habilidad_herreria: bool = false
var habilidad_mezcla: bool = false   # Mezcla (boticaria): sube la prob. de doble poción. Ver mezcla_activa().

# Exp EFECTIVA: 0 mientras la habilidad no este desbloqueada (el progreso sigue guardandose).
func metalurgia_activa() -> float:
	return metalurgia_exp if habilidad_metalurgia else 0.0

func peleteria_activa() -> float:
	return peleteria_exp if habilidad_peleteria else 0.0

func herreria_activa() -> float:
	return herreria_exp if habilidad_herreria else 0.0

func mezcla_activa() -> float:
	return mezcla_exp if habilidad_mezcla else 0.0

# Cada metal, su cadena: el TIER se conserva de la veta a la hebilla.
#   mineral -> lingote -> chapa (armaduras) / hebillas (mochilas)
const _FORJA_METALES: Array = [
	["res://resources/materials/cobre.tres",
		"res://resources/materials/lingote_cobre.tres",
		"res://resources/materials/chapa_cobre.tres",
		"res://resources/materials/hebillas_cobre.tres"],        # T1
	["res://resources/materials/hierro.tres",
		"res://resources/materials/lingote_hierro.tres",
		"res://resources/materials/chapa_hierro.tres",
		"res://resources/materials/hebillas_hierro.tres"],       # T2
	["res://resources/materials/acero.tres",
		"res://resources/materials/lingote_acero.tres",
		"res://resources/materials/chapa_acero.tres",
		"res://resources/materials/hebillas_acero.tres"],     # T3
]
const _CUERO_CRUDO := "res://resources/materials/cuero_simple.tres"
const _CUERO_CURTIDO := "res://resources/materials/cuero_curtido.tres"
const _CORREA := "res://resources/materials/correa_cuero.tres"
# Las MADERAS, por tier. Son el MANGO del arma, y van indexadas igual que _FORJA_METALES: el
# mango tiene que estar a la altura del metal (ver Forge.madera_vale_para).
const _MADERAS: Array = [
	"res://resources/materials/madera_comun.tres",   # T1
	"res://resources/materials/madera_dura.tres",    # T2
	"res://resources/materials/madera_negra.tres",   # T3
]

# {mineral, lingote, chapa, hebillas} de cada metal (para los menus del herrero).
func metales_forja() -> Array:
	var out: Array = []
	for t in _FORJA_METALES:
		var mineral: Resource = load(t[0])
		var lingote: Resource = load(t[1])
		var chapa: Resource = load(t[2])
		var hebillas: Resource = load(t[3])
		if mineral != null and lingote != null and chapa != null and hebillas != null:
			out.append({"mineral": mineral, "lingote": lingote, "chapa": chapa, "hebillas": hebillas})
	return out

func hebillas_forja() -> Array:
	var out: Array = []
	for m in metales_forja():
		out.append(m["hebillas"])
	return out

# La CORREA: el otro ingrediente de la mochila, y lo que hace el peletero con el cuero curtido.
func correa() -> MaterialData:
	return load(_CORREA) as MaterialData

func lingotes_forja() -> Array:
	var out: Array = []
	for m in metales_forja():
		out.append(m["lingote"])
	return out

func chapas_forja() -> Array:
	var out: Array = []
	for m in metales_forja():
		out.append(m["chapa"])
	return out

func cuero_crudo() -> MaterialData:
	return load(_CUERO_CRUDO) as MaterialData

# El cuero que pide la FORJA es el curtido: el crudo se queda en el peletero.
func cuero_forja() -> MaterialData:
	return load(_CUERO_CURTIDO) as MaterialData

# --- LO QUE YA HAS VISTO (id -> true) ---
# El menu del herrero listaba los tres metales desde el minuto uno. Eso es abrumador y ademas
# te enseña cosas que no puedes hacer: te pasas la partida mirando una fila de acero que no vas
# a tocar hasta el piso 11. Un metal solo aparece en la forja cuando te has traido algo de el.
#
# Se apunta el ID, no el item: gastarte el ultimo lingote no te des-enseña que el hierro existe.
var materiales_vistos: Dictionary = {}

func descubrir(mat: MaterialData) -> void:
	if mat != null:
		materiales_vistos[String(mat.id)] = true

func material_visto(mat: MaterialData) -> bool:
	return mat != null and materiales_vistos.has(String(mat.id))


# Los metales que el herrero te va a ENSEÑAR. El TIER 1 (cobre) SIEMPRE se enseña, lo hayas
# visto o no: es donde el jugador aprende a forjar, y pedirle que pique primero para descubrir
# ni el crafteo base es pura friccion. El T2/T3 si se descubren (ya sabes como va la forja;
# ahora aprende el material nuevo). Un metal entra si es T1 o si has traido alguna de sus cuatro
# formas (mineral, lingote, chapa o hebillas). Los menus tiran de esta, no de metales_forja().
func metales_forja_conocidos() -> Array:
	var out: Array = []
	for fila in metales_forja():
		var conocido: bool = int((fila["mineral"] as MaterialData).tier) == 1
		if not conocido:
			for clave in ["mineral", "lingote", "chapa", "hebillas"]:
				if material_visto(fila[clave] as MaterialData):
					conocido = true
					break
		if conocido:
			out.append(fila)
	return out

# Las tres formas, ya filtradas por lo que conoces. Son las que pinta el menu del herrero (la
# math sigue usando las listas COMPLETAS: buscar el lingote de un tier no depende de si lo has
# visto). OJO: los indices de la UI van contra ESTAS, asi que metal_de_forja tira de aqui.
func lingotes_conocidos() -> Array:
	var out: Array = []
	for m in metales_forja_conocidos():
		out.append(m["lingote"])
	return out

func chapas_conocidas() -> Array:
	var out: Array = []
	for m in metales_forja_conocidos():
		out.append(m["chapa"])
	return out

func hebillas_conocidas() -> Array:
	var out: Array = []
	for m in metales_forja_conocidos():
		out.append(m["hebillas"])
	return out


func maderas_forja() -> Array:
	var out: Array = []
	for ruta in _MADERAS:
		var m: Resource = load(ruta)
		if m != null:
			out.append(m)
	return out

func madera_de_tier(tier: int) -> MaterialData:
	for m in maderas_forja():
		if int((m as MaterialData).tier) == tier:
			return m as MaterialData
	return null


# Los INGREDIENTES de forjar `base` con `metal`: una lista [{material, uds}]. Es la fuente unica
# de la que tiran forja_valida / score_forja / forjar y la UI, asi que 2 o 3 materiales se tratan
# igual (no hay casos especiales repartidos). Siempre METAL; luego, segun la pieza:
#   - MADERA del mango (armas), del MISMO tier que el metal (una espada de acero no lleva el palo
#     que se cae de la pared del piso 1).
#   - CUERO: en la armadura es ESTRUCTURAL y va del tier del metal (por eso hoy la armadura T2/T3
#     esta bloqueada: no hay cuero que no sea el de rata). En un arma/escudo es RECUBRIMIENTO
#     (mango, correas): cuero base, SIN tier, porque forrar un agarre lo hace cualquier piel.
# Un material null en la lista = no forjable (lo frenan la UI y forja_valida).
func ingredientes_forja(base: Resource, metal: MaterialData) -> Array:
	var c: Dictionary = Forge.coste(base)
	var out: Array = [{"material": metal, "uds": int(c["metal"])}]
	if int(c["madera"]) > 0:
		out.append({"material": madera_de_tier(Forge.tier_de_metal(metal)), "uds": int(c["madera"])})
	if int(c["cuero"]) > 0:
		var cue: MaterialData
		if base is ArmorData:
			cue = cuero_forja() if Forge.cuero_vale_para(cuero_forja(), metal) else null
		else:
			cue = cuero_forja()   # recubrimiento del mango / correas: cuero base
		out.append({"material": cue, "uds": int(c["cuero"])})
	return out


# La FIBRA que acompaña al metal en esta pieza: MADERA si es un arma (el mango) y CUERO si es
# una armadura. Y tiene que ser de la ALTURA del metal: una espada de acero no lleva el palo que
# se cae de la pared del primer piso.
#
# Devuelve null cuando no existe fibra a esa altura, y eso NO es un error: es el freno. Hoy el
# unico cuero que hay es el de rata (T1), asi que una armadura de hierro o de acero devuelve null
# y no se puede forjar. Es a proposito (ver Forge.cuero_vale_para). Las armas si suben, porque la
# madera si tiene los tres tiers.
func fibra_de_forja(base: Resource, metal: MaterialData) -> MaterialData:
	if base == null or metal == null:
		return null
	var tier: int = Forge.tier_de_metal(metal)
	if base is ArmorData:
		var cuero: MaterialData = cuero_forja()
		return cuero if Forge.cuero_vale_para(cuero, metal) else null
	var maderas: Array = maderas_forja()
	for m in maderas:
		if (m as MaterialData).tier == tier:
			return m as MaterialData
	return null


# --- REFINAR (una sola operacion para fundir, batir y curtir) ---
# Cuantas piezas refinadas puedes sacar de ESTA calidad (hacen falta `por_uno` items de la
# MISMA calidad: juntar tres dañados NO da un normal).
func refinados_posibles(origen: MaterialData, cal: int, por_uno: int) -> int:
	return items_calidad_en_hogar(origen, cal) / maxi(1, por_uno)

# Refina `veces` piezas: consume `por_uno` items de `origen` (todos de la calidad `cal`) y
# devuelve `destino` de esa MISMA calidad... salvo que la habilidad del oficio tire a tu favor
# y la suba un escalon (y con oficio de sobra, un intacto puede salir PURO). El oficio ademas
# tira por RECUPERAR una de las piezas gastadas (desperdicias menos cuanto mejor sabes).
# `oficio` dice cual de los contadores sube ("metalurgia" o "peleteria"). Devuelve cuantas refino.
func refinar(origen: MaterialData, destino: MaterialData, cal: int, veces: int, por_uno: int, oficio: String) -> int:
	if origen == null or destino == null or veces <= 0:
		return 0
	var n: int = mini(veces, refinados_posibles(origen, cal, por_uno))
	if n <= 0:
		return 0
	var exp_oficio: float = peleteria_activa() if oficio == "peleteria" else metalurgia_activa()
	var prob: float = Forge.prob_subir_calidad(exp_oficio)
	# El oficio tambien DESPERDICIA menos: tira por devolverte una de las piezas que se comio el
	# refinado, en su misma calidad (ver Forge.prob_devolver_material).
	var prob_dev: float = Forge.prob_devolver_material(exp_oficio)
	var subidos: int = 0
	var devueltos: int = 0
	for _k in range(n):
		_consumir_items_calidad(origen, cal, por_uno)
		var cal_final: int = cal
		if randf() < prob:
			cal_final = MaterialItem.subir_calidad(cal)
			if cal_final != cal:
				subidos += 1
		almacen_materiales.append(MaterialItem.crear(destino, cal_final))
		descubrir(destino)
		if randf() < prob_dev:
			almacen_materiales.append(MaterialItem.crear(origen, cal))
			devueltos += 1
		if oficio == "peleteria":
			peleteria_exp += Forge.OFICIO_POR_REFINADO
		else:
			metalurgia_exp += Forge.OFICIO_POR_REFINADO
	print("[oficio] %d x %s -> %d x %s  (%d salieron mejor de lo que entraron; %d x %s recuperados)" % [
		n * por_uno, origen.nombre, n, destino.nombre, subidos, devueltos, origen.nombre])
	return n

# Atajos para los tres refinados (cada uno sabe su coste y su oficio).
func fundir(mineral: MaterialData, cal: int, veces: int) -> int:
	return refinar(mineral, lingote_de(mineral), cal, veces, Forge.MINERAL_POR_LINGOTE, "metalurgia")

func batir_chapa(lingote: MaterialData, cal: int, veces: int) -> int:
	return refinar(lingote, chapa_de(lingote), cal, veces, Forge.LINGOTE_POR_CHAPA, "metalurgia")

func curtir(cal: int, veces: int) -> int:
	return refinar(cuero_crudo(), cuero_forja(), cal, veces, Forge.CUERO_POR_CURTIDO, "peleteria")

# Las dos piezas de la MOCHILA: el metal las hace el herrero, la piel el peletero.
func hacer_hebillas(lingote: MaterialData, cal: int, veces: int) -> int:
	return refinar(lingote, hebillas_de(lingote), cal, veces, Forge.LINGOTE_POR_HEBILLAS, "metalurgia")

func hacer_correa(cal: int, veces: int) -> int:
	return refinar(cuero_forja(), correa(), cal, veces, Forge.CUERO_POR_CORREA, "peleteria")

func hebillas_de(lingote: MaterialData) -> MaterialData:
	return _mismo_metal(lingote, 1, 3)

# El lingote que sale de este mineral, y la chapa que sale de este lingote (mismo metal, mismo
# tier: el metal no cambia al refinarlo, solo la forma).
func lingote_de(mineral: MaterialData) -> MaterialData:
	return _mismo_metal(mineral, 0, 1)

func chapa_de(lingote: MaterialData) -> MaterialData:
	return _mismo_metal(lingote, 1, 2)

# Busca `mat` en la columna `col` de la cadena de metales y devuelve la de la columna `destino`.
func _mismo_metal(mat: MaterialData, col: int, destino: int) -> MaterialData:
	if mat == null:
		return null
	for t in _FORJA_METALES:
		var m: Resource = load(t[col])
		if m != null and (m as MaterialData).id == mat.id:
			return load(t[destino]) as MaterialData
	return null

# Quita n items de un material Y calidad concretos del hogar.
func _consumir_items_calidad(mat: MaterialData, cal: int, n: int) -> void:
	var restan: int = n
	var i: int = almacen_materiales.size() - 1
	while i >= 0 and restan > 0:
		var it: MaterialItem = almacen_materiales[i]
		if it != null and it.data != null and it.data.id == mat.id and int(it.calidad) == int(cal):
			almacen_materiales.remove_at(i)
			restan -= 1
		i -= 1

# Todos los NUCLEOS que tienes en el hogar y sirven para mejorar esta pieza (arma o armadura).
func nucleos_para(item: Resource) -> Array:
	var vistos: Array = []
	for it in almacen_materiales:
		if it == null or it.data == null:
			continue
		if not Forge.nucleo_vale(it.data, item):
			continue
		if not vistos.has(it.data):
			vistos.append(it.data)
	return vistos


# TODOS los nucleos que existen. nucleos_para() solo mira los que TIENES, y para FUNDIR hace
# falta la escalera entera: hay que saber que nucleo se comio cada mejora aunque ya no te quede
# ninguno de ese tipo.
const _NUCLEOS: Array = [
	"res://resources/materials/nucleo_slime.tres",
	"res://resources/materials/nucleo_rata.tres",
	"res://resources/materials/nucleo_venenoso.tres",
	"res://resources/materials/nucleo_rey_rata.tres",
	"res://resources/materials/nucleo_fuego.tres",
	"res://resources/materials/nucleo_jabali.tres",
	"res://resources/materials/nucleo_rey_slime.tres",
]

# La escalera de nucleos de ESTA pieza (arma o armadura), ordenada por la banda que cubre cada
# uno. Es lo que le pasa el fundido a Forge para reconstruir lo que costo subirla.
func escalera_nucleos(item: Resource) -> Array:
	var out: Array = []
	for ruta in _NUCLEOS:
		var n: MaterialData = load(ruta) as MaterialData
		if n != null and Forge.nucleo_vale(n, item):
			out.append(n)
	out.sort_custom(func(a: MaterialData, b: MaterialData): return a.mejora_min < b.mejora_min)
	return out


# --- FORJAR ---
# Unidades que aporta una seleccion {calidad: cantidad}: dice si LLEGAS al coste.
func uds_seleccion(dict: Dictionary) -> int:
	return _uds_de_seleccion(dict)

# Score de calidad MEDIO de lo que metes (ponderado por unidades). Es lo que tira la rareza:
# 0 = todo dañado, 0.5 = normal, 1 = intacto, 1.5 = lingote PURO. Al forjar SI se mezclan
# calidades (a diferencia de fundir): meter un puro entre normales sube la media.
func score_seleccion(dicts: Array) -> float:
	var suma: float = 0.0
	var uds: float = 0.0
	for d in dicts:
		for cal in d:
			var u: float = float(_uds_calidad(int(cal)) * int(d[cal]))
			suma += _score_calidad(int(cal)) * u
			uds += u
	return 0.0 if uds <= 0.0 else suma / uds

# El score con el que se va a tirar DE VERDAD: la calidad media de lo que se GASTA (de todos los
# ingredientes) + lo que aporta tu Herreria + lo que aporta el METAL (el acero ya viene medio
# hecho). La UI pinta ESTE, no el otro: lo que ves es lo que se tira. `selecciones` va en paralelo
# a ingredientes_forja(base, metal).
func score_forja(base: Resource, metal: MaterialData, selecciones: Array) -> float:
	return Forge.score_final(score_material_forja(base, metal, selecciones),
		Forge.bonus_herreria(herreria_activa()), Forge.bonus_metal(metal))


# El score SOLO del material que se va a gastar (sin oficio ni metal), 0..1.5. Lo pinta el menu:
# hay que sacarlo de aqui y no restandoselo al score final, porque score_final ya no es una suma
# (el metal se capa en el techo del recolectado).
func score_material_forja(base: Resource, metal: MaterialData, selecciones: Array) -> float:
	var ings: Array = ingredientes_forja(base, metal)
	var recortadas: Array = []
	for i in mini(ings.size(), selecciones.size()):
		recortadas.append(recortar_seleccion(selecciones[i], int(ings[i]["uds"])))
	return score_seleccion(recortadas)


# Lo que se va a GASTAR de verdad de una seleccion que cubre `necesita` unidades. Si te pasas,
# el sobrante NO se quema: se devuelve al baul. Lo que se descarta es lo PEOR que hayas metido
# (mientras el resto siga cubriendo el coste), asi que pasarse nunca te perjudica: te quedas el
# material bueno Y forjas con la mejor media de calidad posible.
func recortar_seleccion(sel: Dictionary, necesita: int) -> Dictionary:
	var out: Dictionary = sel.duplicate()
	var uds: int = _uds_de_seleccion(out)
	# De peor a mejor: dañado, normal, intacto, puro.
	for cal in [MaterialItem.Calidad.DANADO, MaterialItem.Calidad.NORMAL,
			MaterialItem.Calidad.INTACTO, MaterialItem.Calidad.PURO]:
		var n: int = int(out.get(cal, 0))
		var u: int = _uds_calidad(int(cal))
		while n > 0 and uds - u >= necesita:
			n -= 1
			uds -= u
		if n <= 0:
			out.erase(cal)
		else:
			out[cal] = n
	return out


# El METAL que pide esta pieza: la CHAPA si es armadura, el LINGOTE si es arma. La UI le pide
# a Game el material concreto en vez de decidirlo ella.
func metal_de_forja(base: Resource, idx: int) -> MaterialData:
	# CONOCIDOS: el indice viene de los botones del menu, y el menu solo pinta los que conoces.
	var lista: Array = chapas_conocidas() if bool(Forge.coste(base)["usa_chapa"]) else lingotes_conocidos()
	if lista.is_empty():
		return null
	return lista[clampi(idx, 0, lista.size() - 1)]


# ¿Cubren estas selecciones el coste de forjar `base`? (y no piden mas de lo que hay en el baul)
# Si algun ingrediente no existe a la altura del metal (material null), esta pieza no se forja:
# es lo que frena la armadura T2/T3 (no hay cuero que no sea el de rata). Ver ingredientes_forja.
func forja_valida(base: Resource, metal: MaterialData, selecciones: Array) -> bool:
	if base == null or metal == null:
		return false
	var ings: Array = ingredientes_forja(base, metal)
	if selecciones.size() != ings.size():
		return false
	for i in ings.size():
		var mat: MaterialData = ings[i]["material"]
		if mat == null:
			return false
		if not _sel_disponible(mat, selecciones[i]):
			return false
		if uds_seleccion(selecciones[i]) < int(ings[i]["uds"]):
			return false
	return true

# ¿Tienes en el baul lo que dice la seleccion? (la UI ya lo acota, pero la math no se fia)
func _sel_disponible(mat: MaterialData, dict: Dictionary) -> bool:
	for cal in dict:
		if int(dict[cal]) > items_calidad_en_hogar(mat, int(cal)):
			return false
	return true


# FORJA una pieza: el METAL (lingote si es arma, chapa si es armadura) fija el tier, y la
# calidad media de lo que metes (mas tu Herreria) tira la rareza. Solo se gasta lo NECESARIO:
# si te pasas de unidades, el sobrante se queda en el baul (ver recortar_seleccion). Devuelve
# el item nuevo, ya en el baul; null si la seleccion no llega.
func forjar(base: Resource, metal: MaterialData, selecciones: Array) -> Resource:
	if not forja_valida(base, metal, selecciones):
		return null
	var ings: Array = ingredientes_forja(base, metal)
	var tier: int = Forge.tier_de_metal(metal)
	var rareza: int = Forge.tirar_rareza(score_forja(base, metal, selecciones))
	# La HERRERIA hace dos cosas: empuja la rareza (ya va dentro de score_forja) y tira por
	# devolverte material de cada ingrediente.
	var prob_dev: float = Forge.prob_devolver_forja(herreria_activa())
	var nombres: PackedStringArray = []
	var devueltos: int = 0
	for i in ings.size():
		var mat: MaterialData = ings[i]["material"]
		var uds: int = int(ings[i]["uds"])
		var gasto: Dictionary = recortar_seleccion(selecciones[i], uds)
		_consumir_seleccion_material(mat, gasto)
		# Aprovechamiento: lo que sobra del ultimo trozo puede volver al baul (ver Forge).
		_tirar_devolucion(mat, gasto, uds)
		# Y encima, la Herreria puede rescatar una pieza entera de lo que se ha gastado. Se
		# devuelve la PEOR de las calidades que metiste: el recorte ya te guardo las buenas.
		var peor: int = _peor_calidad_de(gasto)
		if peor >= 0 and randf() < prob_dev:
			almacen_materiales.append(MaterialItem.crear(mat, peor))
			devueltos += 1
		nombres.append(mat.nombre)
	var item: Resource = crear_item(base, tier, rareza, {})
	herreria_exp += Forge.HERRERIA_POR_PIEZA
	print("[herrero] Forjas %s con %s -> T%d %s.  (%d pieza(s) recuperadas)  Herreria %s" % [
		str(base.get("nombre")), ", ".join(nombres), tier,
		Upgrades.rareza_nombre(rareza), devueltos, snappedf(herreria_exp, 0.1)])
	return item


# La PEOR calidad de una seleccion {calidad: cantidad}, o -1 si esta vacia. Mismo orden que usa
# recortar_seleccion (dañado < normal < intacto < puro): el enum no vale para comparar.
func _peor_calidad_de(dict: Dictionary) -> int:
	for cal in [MaterialItem.Calidad.DANADO, MaterialItem.Calidad.NORMAL,
			MaterialItem.Calidad.INTACTO, MaterialItem.Calidad.PURO]:
		if int(dict.get(cal, 0)) > 0:
			return int(cal)
	return -1


# Tira por devolver al baul UNA pieza del material, segun las unidades que hayan SOBRADO del
# gasto (un lingote intacto vale 3 uds; si la pieza pedia 4, gastas 2 lingotes = 6 y sobran 2).
# Devuelve la PEOR calidad de las que gastaste: el recorte ya te guardo las buenas.
# Lo que SOBRA del recorte (unidades gastadas de mas, por meter piezas indivisibles) vuelve al
# baul como material DAÑADO, sin tirada: 1 unidad sobrante = 1 dañado. Antes era una PROBABILIDAD
# de recuperar una pieza; ahora es deterministico y no se desperdicia nada. El dañado (1 ud) es la
# "chatarra" del recorte: te lo devuelven, pero como material de descarte, no de primera.
func _tirar_devolucion(mat: MaterialData, gasto: Dictionary, necesita: int) -> void:
	var sobra: int = _uds_de_seleccion(gasto) - necesita
	if mat == null or sobra <= 0:
		return
	for _k in range(sobra):
		almacen_materiales.append(MaterialItem.crear(mat, MaterialItem.Calidad.DANADO))
	print("[recorte] Sobran %d uds de %s: vuelven como %d dañado(s)" % [sobra, mat.nombre, sobra])


# --- FABRICAR una MOCHILA (peletero) ---
# Misma idea que la forja, pero con las piezas de la mochila: las HEBILLAS ponen el metal (y con
# el, el TIER) y las CORREAS + el CUERO CURTIDO ponen la tela. La RAREZA se tira con la calidad
# media de todo lo que metes (mas la Peleteria, cuando exista): es lo unico que diferencia una
# mochila de otra, asi que aqui la tirada importa mas que en ningun sitio.
const MOCHILA_BASE := "res://resources/backpacks/mochila_basica.tres"
# Coste, en unidades (mismas que el resto del crafteo: puro 4 / intacto 3 / normal 2 / dañado 1).
const MOCHILA_COSTE := {"hebillas": 3, "correa": 3, "cuero": 6}

func mochila_base() -> BackpackData:
	return load(MOCHILA_BASE) as BackpackData

func score_mochila(hebillas: MaterialData, sel_heb: Dictionary, sel_cor: Dictionary, sel_cue: Dictionary) -> float:
	return Forge.score_final(score_seleccion([sel_heb, sel_cor, sel_cue]),
		Forge.bonus_herreria(peleteria_activa()), Forge.bonus_metal(hebillas))

func mochila_valida(hebillas: MaterialData, sel_heb: Dictionary, sel_cor: Dictionary, sel_cue: Dictionary) -> bool:
	if hebillas == null:
		return false
	if not _sel_disponible(hebillas, sel_heb) or not _sel_disponible(correa(), sel_cor) \
			or not _sel_disponible(cuero_forja(), sel_cue):
		return false
	return uds_seleccion(sel_heb) >= int(MOCHILA_COSTE["hebillas"]) \
		and uds_seleccion(sel_cor) >= int(MOCHILA_COSTE["correa"]) \
		and uds_seleccion(sel_cue) >= int(MOCHILA_COSTE["cuero"])

func fabricar_mochila(hebillas: MaterialData, sel_heb: Dictionary, sel_cor: Dictionary, sel_cue: Dictionary) -> Resource:
	if not mochila_valida(hebillas, sel_heb, sel_cor, sel_cue):
		return null
	var g_heb: Dictionary = recortar_seleccion(sel_heb, int(MOCHILA_COSTE["hebillas"]))
	var g_cor: Dictionary = recortar_seleccion(sel_cor, int(MOCHILA_COSTE["correa"]))
	var g_cue: Dictionary = recortar_seleccion(sel_cue, int(MOCHILA_COSTE["cuero"]))
	var tier: int = Forge.tier_de_metal(hebillas)
	var rareza: int = Forge.tirar_rareza(score_mochila(hebillas, sel_heb, sel_cor, sel_cue))
	_consumir_seleccion_material(hebillas, g_heb)
	_consumir_seleccion_material(correa(), g_cor)
	_consumir_seleccion_material(cuero_forja(), g_cue)
	_tirar_devolucion(hebillas, g_heb, int(MOCHILA_COSTE["hebillas"]))
	_tirar_devolucion(correa(), g_cor, int(MOCHILA_COSTE["correa"]))
	_tirar_devolucion(cuero_forja(), g_cue, int(MOCHILA_COSTE["cuero"]))
	var m: Resource = crear_item(mochila_base(), tier, rareza, {})
	peleteria_exp += Forge.HERRERIA_POR_PIEZA
	print("[peletero] Coses una mochila con %s -> T%d %s (+%.0f de carga).  Peleteria %s" % [
		hebillas.nombre, tier, Upgrades.rareza_nombre(rareza),
		capacidad_mochila(m as BackpackData), snappedf(peleteria_exp, 0.1)])
	return m


# --- MEJORAR una pieza con NUCLEOS ---
# Tope de mejoras de la pieza: lo MENOR entre lo que admite su rareza (huecos) y hasta donde
# deja llegar el nucleo que uses. Un nucleo de slime no te sube una legendaria mas alla de +3
# por muchos huecos que tenga: para eso hay que bajar a por bichos mas hondos.
func tope_mejoras(item: Resource, nucleo: MaterialData) -> int:
	if item == null:
		return 0
	var por_rareza: int = Upgrades.rareza_slots(int(meta_de(item)["rareza"]))
	if nucleo == null:
		return por_rareza
	return mini(por_rareza, maxi(0, nucleo.mejora_max))

func mejoras_actuales(item: Resource) -> int:
	return Upgrades.total_mejoras(meta_de(item)["mejoras"])

# Nucleos (items, no unidades) que hay en el hogar de ese tipo.
func nucleos_en_hogar(nucleo: MaterialData) -> int:
	var n: int = 0
	for it in almacen_materiales:
		if it != null and it.data != null and nucleo != null and it.data.id == nucleo.id:
			n += 1
	return n

# El MATERIAL que pide mejorar esta pieza: el mismo con el que se forjo y del MISMO tier, o sea
# {metal (lingote/chapa), fibra (madera/cuero)}. Cualquiera de los dos puede venir null si a ese
# tier no existe (la fibra de una armadura T2, hoy), y entonces la pieza no se puede mejorar.
func materiales_mejora(item: Resource) -> Dictionary:
	if item == null:
		return {"metal": null, "fibra": null}
	var tier: int = int(meta_de(item)["tier"])
	var metales: Array = chapas_forja() if item is ArmorData else lingotes_forja()
	var metal: MaterialData = null
	for m in metales:
		if (m as MaterialData).tier == tier:
			metal = m as MaterialData
			break
	return {"metal": metal, "fibra": fibra_de_forja(item, metal)}


func puede_mejorar(item: Resource, nucleo: MaterialData) -> bool:
	if item == null or not Forge.nucleo_vale(nucleo, item):
		return false
	if mejoras_actuales(item) >= tope_mejoras(item, nucleo):
		return false
	if nucleos_en_hogar(nucleo) < Forge.nucleos_para_mejora(mejoras_actuales(item), nucleo):
		return false
	# Y el material de refuerzo (ver materiales_mejora).
	var mats: Dictionary = materiales_mejora(item)
	var c: Dictionary = Forge.material_para_mejora(mejoras_actuales(item))
	if mats["metal"] == null or mats["fibra"] == null:
		return false
	return unidades_material_en_hogar(mats["metal"]) >= int(c["metal"]) \
		and unidades_material_en_hogar(mats["fibra"]) >= int(c["fibra"])

# Mete UNA mejora de la categoria `cat` en la pieza, gastando nucleos Y material. La meta va POR
# OBJETO (item_meta), y equip_meta apunta al MISMO dict: mejorar el arma que llevas puesta la
# mejora de verdad, sin tener que desequiparla.
func mejorar_item(item: Resource, cat: String, nucleo: MaterialData) -> bool:
	if not puede_mejorar(item, nucleo):
		return false
	var nivel: int = mejoras_actuales(item)
	var cuesta: int = Forge.nucleos_para_mejora(nivel, nucleo)
	var mats: Dictionary = materiales_mejora(item)
	var c: Dictionary = Forge.material_para_mejora(nivel)
	_consumir_nucleos(nucleo, cuesta)
	_consumir_unidades(mats["metal"], int(c["metal"]))
	_consumir_unidades(mats["fibra"], int(c["fibra"]))
	var mj: Dictionary = meta_de(item)["mejoras"]
	mj[cat] = int(mj.get(cat, 0)) + 1
	print("[herrero] Mejoras %s con %d x %s + %d uds de %s + %d uds de %s -> %s +%d" % [
		str(item.get("nombre")), cuesta, nucleo.nombre,
		int(c["metal"]), (mats["metal"] as MaterialData).nombre,
		int(c["fibra"]), (mats["fibra"] as MaterialData).nombre,
		Upgrades.cat_nombre(cat), int(mj[cat])])
	return true

# ============================================================
#  FUNDIR EQUIPO: deshacer una pieza y recuperar la mitad del material
#  Hasta ahora la unica salida para el equipo que no querias era venderlo. Fundirlo le da una
#  segunda vida al material, nucleos incluidos si la habias mejorado. La math vive en Forge.
# ============================================================

# ¿La llevas puesta? No se funde lo que tienes encima: primero lo dejas.
func item_equipado(item: Resource) -> bool:
	if item == null:
		return false
	for eq in [equipped_main, equipped_off, equipped_casco, equipped_pecho,
			equipped_manos, equipped_pantalones, equipped_botas, equipped_mochila]:
		if eq == item:
			return true
	return false


func puede_fundir(item: Resource) -> bool:
	if item == null or item_equipado(item):
		return false
	return owned_weapons.has(item) or owned_armor.has(item)


# Lo que SACARIAS de fundirla, sin fundirla (la UI pinta esto antes de que le des al boton).
# {"materiales": [{material, uds}...], "nucleos": {mat: n}}. Los materiales son los mismos con los
# que se forja (metal del tier, madera del tier, cuero base), cada uno a la mitad.
func fundir_devuelve(item: Resource) -> Dictionary:
	var mejoras: int = mejoras_actuales(item)
	var f: Dictionary = Forge.fundir_material(item, mejoras)
	var tier: int = int(meta_de(item)["tier"])
	var metal_mat: MaterialData = materiales_mejora(item)["metal"]   # el metal de SU tier
	var materiales: Array = []
	if int(f["metal"]) > 0 and metal_mat != null:
		materiales.append({"material": metal_mat, "uds": int(f["metal"])})
	if int(f["madera"]) > 0:
		var mad: MaterialData = madera_de_tier(tier)
		if mad != null:
			materiales.append({"material": mad, "uds": int(f["madera"])})
	if int(f["cuero"]) > 0:
		materiales.append({"material": cuero_forja(), "uds": int(f["cuero"])})
	return {
		"materiales": materiales,
		"nucleos": Forge.fundir_nucleos(escalera_nucleos(item), mejoras),
	}


# Funde la pieza: se va del baul y el material vuelve al hogar. Devuelve false si no se podia.
func fundir_item(item: Resource) -> bool:
	if not puede_fundir(item):
		return false
	var d: Dictionary = fundir_devuelve(item)
	# El nombre, ANTES de borrar la meta: item_display_name la lee para el tier y la rareza, y
	# sin ella la pieza que acabas de deshacer sale en el log como una comun T1 cualquiera.
	var nombre: String = item_display_name(item)

	# Cada array esta TIPADO (owned_armor es Array[ArmorData]), asi que pasarle un arma a erase()
	# no es un no-op: revienta con un error de TypedArray. Se borra del que le toca.
	if item is ArmorData:
		owned_armor.erase(item)
	else:
		owned_weapons.erase(item)
	item_meta.erase(item)

	var partes: PackedStringArray = []
	for m in (d["materiales"] as Array):
		_devolver_unidades(m["material"], int(m["uds"]))
		partes.append("%d uds de %s" % [int(m["uds"]), (m["material"] as MaterialData).nombre])
	var nucleos: Dictionary = d["nucleos"]
	for n in nucleos:
		for _k in range(int(nucleos[n])):
			almacen_materiales.append(MaterialItem.crear(n, MaterialItem.Calidad.NORMAL))

	print("[herrero] Fundes %s -> %s, %d núcleo(s)" % [
		nombre, ", ".join(partes) if partes.size() > 0 else "nada", _total_nucleos(nucleos)])
	return true


func _total_nucleos(nucleos: Dictionary) -> int:
	var n: int = 0
	for k in nucleos:
		n += int(nucleos[k])
	return n


# Mete `uds` unidades de un material en el baul, en el MENOR numero de piezas posible: piezas
# normales (2 uds) y, si sobra una unidad suelta, una dañada. No se devuelven intactas: lo que
# sale de una pieza fundida es chatarra reaprovechable, no material de primera.
func _devolver_unidades(mat: MaterialData, uds: int) -> void:
	if mat == null or uds <= 0:
		return
	var normales: int = uds / 2
	for _k in range(normales):
		almacen_materiales.append(MaterialItem.crear(mat, MaterialItem.Calidad.NORMAL))
	if uds % 2 == 1:
		almacen_materiales.append(MaterialItem.crear(mat, MaterialItem.Calidad.DANADO))
	descubrir(mat)


# Quita n nucleos del hogar, los PEORES primero (dañado antes que intacto): un nucleo es un
# permiso, no un ingrediente de calidad, asi que no tiene sentido quemar los buenos.
func _consumir_nucleos(nucleo: MaterialData, n: int) -> void:
	var orden: Array = [MaterialItem.Calidad.DANADO, MaterialItem.Calidad.NORMAL, MaterialItem.Calidad.INTACTO]
	var restan: int = n
	for cal in orden:
		var i: int = almacen_materiales.size() - 1
		while i >= 0 and restan > 0:
			var it: MaterialItem = almacen_materiales[i]
			if it != null and it.data != null and it.data.id == nucleo.id and int(it.calidad) == int(cal):
				almacen_materiales.remove_at(i)
				restan -= 1
			i -= 1


# Quita `uds` UNIDADES de un material del hogar, gastando lo PEOR primero. Es lo que usa la
# MEJORA, y por eso no hay selector de calidades como en la forja: ahi la calidad decide la
# rareza y tienes que poder elegir, pero la rareza de una pieza ya forjada no se toca, asi que
# meter material bueno a reforzarla no te daria nada. Se gasta la morralla y punto.
func _consumir_unidades(mat: MaterialData, uds: int) -> void:
	if mat == null or uds <= 0:
		return
	var orden: Array = [MaterialItem.Calidad.DANADO, MaterialItem.Calidad.NORMAL,
		MaterialItem.Calidad.INTACTO, MaterialItem.Calidad.PURO]
	var restan: int = uds
	for cal in orden:
		var i: int = almacen_materiales.size() - 1
		while i >= 0 and restan > 0:
			var it: MaterialItem = almacen_materiales[i]
			if it != null and it.data != null and it.data.id == mat.id and int(it.calidad) == int(cal):
				almacen_materiales.remove_at(i)
				restan -= it.unidades_crafteo()
			i -= 1


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


# Unidades que aporta un item segun su calidad (puro 4 / intacto 3 / normal 2 / dañado 1).
# Es la MISMA tabla que MaterialItem.unidades_crafteo(), y tiene que seguir siendolo: aqui se
# olvidaba el PURO y devolvia 0, asi que un lingote puro (el que saca la Metalurgia alta, el
# mejor material del juego) contaba como NADA al forjar. El premio del oficio no valia nada.
func _uds_calidad(cal: int) -> int:
	match cal:
		MaterialItem.Calidad.PURO: return 4
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


# Lo que se va a gastar DE VERDAD de cada ingrediente (array paralelo a receta.ingredientes).
# Es la seleccion recortada a lo justo para las n pociones que salen: el resto se queda en el
# baul. Lo usa el crafteo y lo pinta el menu, para que lo que ves sea lo que se gasta.
func gasto_crafteo(receta: RecipeData, seleccion: Array) -> Array:
	var out: Array = []
	var n: int = pociones_de_seleccion(receta, seleccion)
	for i in receta.ingredientes.size():
		var ing = receta.ingredientes[i]
		if ing == null or ing.material == null or i >= seleccion.size():
			out.append({})
			continue
		out.append(recortar_seleccion(seleccion[i], n * ing.unidades))
	return out


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
	# MEZCLA (habilidad de desarrollo de la boticaria): suma un bonus por su rango a la prob. de
	# doble poción (misma curva exp->bonus que la Herrería). Sin la habilidad, mezcla_activa() = 0.
	return clampf(MAX_PROB_DOBLE * (suma_score / suma_uds) + Forge.bonus_herreria(mezcla_activa()), 0.0, 1.0)


# La poción del SIGUIENTE escalon de la cadena de esta receta (lo que puede regalarte la Mezcla),
# o null si ya es la tope. NO hace falta ningun dato nuevo en los .tres: la cadena ya esta escrita
# en las propias recetas de MEJORA (la que consume esta poción como 'pocion_base' es, por
# definicion, la que da el escalon de arriba). Ver RecipeData.es_mejora().
func pocion_siguiente(receta: RecipeData) -> ConsumableData:
	if receta == null or receta.resultado == null:
		return null
	for r in recetas_boticaria():
		var rec: RecipeData = r as RecipeData
		if rec != null and rec.pocion_base == receta.resultado:
			return rec.resultado
	return null


# Puntuacion de calidad 0..1 para el bonus de doble (intacto 1, normal 0.5, dañado 0).
func _score_calidad(cal: int) -> float:
	match cal:
		MaterialItem.Calidad.INTACTO: return 1.0
		MaterialItem.Calidad.NORMAL: return 0.5
		_: return 0.0


# Fabrica CUANTAS pociones cubra la seleccion (pociones_de_seleccion) y, si es mejora, gasta una
# poción base por cada una; el bonus de doble se tira POR SEPARADO en cada poción (cada una
# puede salir doble). Devuelve true si fabricó algo.
#
# Solo se gasta lo NECESARIO: si metes de mas, el sobrante se queda en el baul, y lo que sobra
# del ultimo trozo puede volver (mismo trato que en la forja; ver crafting.gd).
# Devuelve el TOTAL de pociones fabricadas (contando los dobles); 0 = no se pudo. Antes devolvia
# bool; el menu lo usa con un 'if' y en GDScript if 0 = falso, if N>0 = verdadero, asi que sigue
# valiendo, pero ahora la botanica puede decir CUANTAS salieron (como la forja dice que forja).
func craftear_con(receta: RecipeData, seleccion: Array) -> int:
	var n: int = pociones_de_seleccion(receta, seleccion)
	if n < 1:
		return 0
	# Lo que se gasta DE VERDAD, por ingrediente. La prob. de doble se calcula con esto y no con
	# lo elegido: un dañado que ni se llega a usar no tiene por que bajarte la media.
	var gasto: Array = gasto_crafteo(receta, seleccion)
	var prob: float = prob_doble_desde_seleccion(receta, gasto)
	# MEZCLA: cada poción tira TAMBIEN por salir del escalon de arriba. Sin la habilidad,
	# mezcla_activa() = 0 -> prob 0, y el tally se queda todo en receta.resultado (como antes).
	var prob_subir: float = Forge.prob_subir_pocion(mezcla_activa())
	var mejor: ConsumableData = pocion_siguiente(receta)
	# Que sale de la tanda: {ConsumableData: cuantas}. Ya no es un solo add_consumable, porque
	# una misma tanda puede escupir dos pociones DISTINTAS (la normal y la que subio de escalon).
	var salida: Dictionary = {}
	var total: int = 0
	var subidas: int = 0
	for _k in range(n):
		if receta.es_mejora():
			gastar_consumible(receta.pocion_base)
		# El doble se tira por UNIDAD fabricada; la subida, por cada poción que sale de ella.
		var cuantas: int = 2 if randf() < prob else 1
		for _p in range(cuantas):
			var sale: ConsumableData = receta.resultado
			if mejor != null and randf() < prob_subir:
				sale = mejor
				subidas += 1
			salida[sale] = int(salida.get(sale, 0)) + 1
			total += 1
	for i in receta.ingredientes.size():
		var ing = receta.ingredientes[i]
		if ing == null or ing.material == null:
			continue
		_consumir_seleccion_material(ing.material, gasto[i])
		_tirar_devolucion(ing.material, gasto[i], n * ing.unidades)
	for cons in salida:
		add_consumable(cons as ConsumableData, int(salida[cons]))
	# MEZCLA: crear pociones (no comprarlas) alimenta el parametro oculto. Cuenta por poción
	# fabricada (incluidas las que salen dobles): mezclar mas = mas experiencia de Mezcla.
	mezcla_exp += MEZCLA_EXP_POR_POCION * float(total)
	var detalle: PackedStringArray = []
	for cons in salida:
		detalle.append("%d x %s" % [int(salida[cons]), (cons as ConsumableData).nombre])
	print("[boticaria] Fabricas ", n, " poción(es) -> ", ", ".join(detalle),
		"  (prob. doble ", roundi(prob * 100.0), "% por poción; subir de escalón ",
		roundi(prob_subir * 100.0), "% -> ", subidas, " subida(s))  ·  Mezcla ", snappedf(mezcla_exp, 0.1))
	return total


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
	var gain: float = base * clampf(reto_val, 0.0, max_reto) * factor * desarrollo_gain_mult(abil)
	ability_internal[abil] = interno + gain

# Poder del jugador (suma de visibles) con un suelo para no dividir por 0.
func poder_jugador_eff() -> float:
	# Usa el TOTAL acumulado (oculto), no el visible de este nivel: asi al subir de nivel un enemigo
	# de piso bajo sigue dando reto ~0 (tu poder real no baja), sin exploit de farmear piso 1.
	var suma: float = float(stat_total("fuerza") + stat_total("resistencia") + stat_total("destreza")
		+ stat_total("agilidad") + stat_total("magia"))
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

# "Actualizar estado" (altar / tu dios): aplica lo INTERNO a lo VISIBLE. El VISIBLE es el progreso
# de ESTE nivel = interno - base_nivel (tras subir de nivel arranca en 0/rango I aunque el total
# oculto siga alto). Recoleccion y reto NO usan esto: usan el total (ver stat_total()).
func actualizar_estado() -> void:
	player_fuerza = _visible_nivel("fuerza")
	player_resistencia = _visible_nivel("resistencia")
	player_destreza = _visible_nivel("destreza")
	player_agilidad = _visible_nivel("agilidad")
	player_magia = _visible_nivel("magia")
	print("=== ESTADO ACTUALIZADO (Nv ", player_level, ") ===  F:", player_fuerza,
		" R:", player_resistencia, " D:", player_destreza, " A:", player_agilidad, " M:", player_magia)

# Progreso VISIBLE de este nivel para una habilidad (interno - base del nivel, minimo 0).
func _visible_nivel(s: String) -> int:
	return maxi(0, floori(float(ability_internal[s]) - float(ability_base_nivel[s])))

# TOTAL acumulado (oculto) de una habilidad. Es lo que usan recoleccion y reto: no se resetea al
# subir de nivel, asi la recoleccion sigue facil y un enemigo de piso bajo da reto ~0 (no exploit).
func stat_total(s: String) -> int:
	return floori(float(ability_internal[s]))


# ============================================================
#  SUBIR DE NIVEL (estilo DanMachi)
#  Al subir: se BAKEA el efecto derivado de tus basicas visibles en las stats base (×1.10) y el
#  VISIBLE se resetea a 0 (rango I) SIN borrar el total oculto. Asi el poder de combate se conserva
#  (base grande) y ademas cada punto nuevo pega mas (multiplica sobre esa base). Recoleccion/reto
#  usan el total oculto (stat_total), asi no se rompen.
# ============================================================

# ¿Puedes subir de nivel? Haber vencido al enemigo disparador Y tener rango C (600) en alguna
# habilidad (por el TOTAL). El orden no importa: si lo venciste antes de tener el rango, cuenta.
func puede_subir_nivel() -> bool:
	if not guardianes_vencidos.get(player_level + 1, false):
		return false   # aún no has vencido al guardián de tu SIGUIENTE nivel
	for s in ["fuerza", "resistencia", "destreza", "agilidad", "magia"]:
		if stat_total(s) >= RANGO_C_MIN:
			return true
	return false

# Sube de nivel: consolida, bakea las stats derivadas en la base (×1.10), resetea el visible,
# sube el nivel y aplica la habilidad de desarrollo elegida. desarrollo_id es OBLIGATORIO.
func subir_nivel(desarrollo_id: String) -> bool:
	if not puede_subir_nivel():
		return false
	actualizar_estado()   # consolida lo pendiente en el visible antes de bakear
	# Abilities con las basicas VISIBLES actuales, para derivar las stats intrinsecas.
	var a := Abilities.new()
	a.fuerza = player_fuerza
	a.resistencia = player_resistencia
	a.destreza = player_destreza
	a.agilidad = player_agilidad
	a.magia = player_magia
	# BAKEAR ×(1+NIVEL_SPIKE): el efecto de tus basicas se congela en la base del nivel nuevo.
	var spike: float = 1.0 + NIVEL_SPIKE
	player_base_attack = player_base_attack * StatsMath.fuerza_factor(float(a.fuerza)) * spike
	player_base_hp = StatsMath.max_hp_value(a, player_level, player_base_hp) * spike
	player_base_defense = StatsMath.defense_value(a, player_level, player_base_defense) * spike
	player_base_speed = StatsMath.speed_value(a, player_level, player_base_speed) * spike
	player_base_magic = StatsMath.magic_value(a, player_level, player_base_magic) * spike
	# MAGIA (daño de hechizo + maná) y DESTREZA (crítico) no tenían campo base: se bakean aparte.
	# El factor de daño mágico congela el magia_factor de esta Magia (tu Magia nueva multiplica
	# encima). El maná base sube. El crítico plano suma una parte de tu Destreza (contest, sin base).
	player_base_magia_factor = player_base_magia_factor * StatsMath.magia_factor(float(a.magia)) * spike
	player_base_mp = StatsMath.max_mp_value(a, player_level, player_base_mp) * spike
	player_base_crit += (float(a.destreza) / 999.0) * CRIT_BAKE_MAX * spike
	# Resetear el VISIBLE sin borrar el total oculto: la marca del nivel sube al total actual.
	for s in ["fuerza", "resistencia", "destreza", "agilidad", "magia"]:
		ability_base_nivel[s] = ability_internal[s]
	player_fuerza = 0; player_resistencia = 0; player_destreza = 0; player_agilidad = 0; player_magia = 0
	player_level += 1
	aplicar_desarrollo(desarrollo_id)
	player_current_hp = -1.0; player_current_mp = -1.0   # despiertas a tope tras el ascenso
	print("[nivel] ¡Subes a nivel ", player_level, "! Base -> atk %.1f def %.1f hp %.1f spd %.1f mag %.1f" % [
		player_base_attack, player_base_defense, player_base_hp, player_base_speed, player_base_magic])
	Perfil.guardar_actual()
	return true


# --- HABILIDADES DE DESARROLLO (eliges 1 al subir de nivel) ---
# Catalogo: 4 OFICIOS (encienden los interruptores ya sembrados: mejoran lo que crafteas) + 5
# perks de COMBATE, cada uno con un efecto DISTINTO (antes eran tres veces el mismo +30%).
#
# Ninguno sale "porque si": cada uno tiene un REQUISITO (`req`) y hay que habertelo ganado
# HACIENDO lo suyo. El progreso vive en un contador OCULTO (mezcla_exp, esquivas_exp...) que sube
# solo y que no se enseña en ninguna UI: el que lleve mil lingotes fundidos ya se ha ganado la
# Metalurgia sin saberlo, y el dia que suba de nivel le aparecera. Ver _req_cumplido.
#   "exp"            -> el contador `contador` tiene que llegar a `umbral`.
#   "primer_ascenso" -> solo en la PRIMERA subida (nivel 1 -> 2), y nunca mas.
#
# UMBRALES: PROVISIONALES -> Excel. Los de oficio van en "veces" (cada refinado/forja/poción suma
# 1.0; ver Forge.OFICIO_POR_REFINADO / HERRERIA_POR_PIEZA / MEZCLA_EXP_POR_POCION). Los de combate
# tambien, salvo autorregeneracion, que va en DAÑO ENCAJADO y por eso su numero es tan grande.
const DESARROLLOS: Array = [
	{"id": "metalurgia", "nombre": "Metalurgia", "tipo": "oficio",
		"desc": "Al refinar metal, tira por subir un escalón la calidad.",
		"req": "exp", "contador": "metalurgia_exp", "umbral": 20.0},
	{"id": "peleteria", "nombre": "Peletería", "tipo": "oficio",
		"desc": "Al curtir piel, tira por subir un escalón la calidad.",
		"req": "exp", "contador": "peleteria_exp", "umbral": 20.0},
	{"id": "herreria", "nombre": "Herrería", "tipo": "oficio",
		"desc": "Al forjar, empuja la tirada de rareza a tu favor.",
		"req": "exp", "contador": "herreria_exp", "umbral": 5.0},
	{"id": "mezcla", "nombre": "Mezcla", "tipo": "oficio",
		"desc": "Al fabricar pociones, tira por doblarlas y por subirlas de escalón.",
		"req": "exp", "contador": "mezcla_exp", "umbral": 20.0},
	# El CAZADOR es el raro: no se entrena, solo se te concede en el PRIMER ascenso. Si eliges
	# otra cosa (o aplazas y subes mas tarde), lo pierdes para siempre.
	{"id": "cazador", "nombre": "Cazador", "tipo": "combate",
		"desc": "Todo lo que entrenas cunde un poco más.",
		"req": "primer_ascenso"},
	{"id": "reflejos", "nombre": "Reflejos", "tipo": "combate",
		"desc": "Esquivas mejor en combate.",
		"req": "exp", "contador": "esquivas_exp", "umbral": 30.0},
	{"id": "erudito", "nombre": "Erudito", "tipo": "combate",
		"desc": "Tus hechizos pegan más fuerte.",
		"req": "exp", "contador": "hechizos_exp", "umbral": 30.0},
	{"id": "encantamiento_rapido", "nombre": "Encantamiento rápido", "tipo": "combate",
		"desc": "Recitas los conjuros más rápido.",
		"req": "exp", "contador": "recitado_exp", "umbral": 40.0},
	{"id": "autorregeneracion", "nombre": "Autorregeneración", "tipo": "combate",
		"desc": "Recuperas algo de vida al principio de cada turno.",
		"req": "exp", "contador": "dano_recibido_exp", "umbral": 500.0},
]

# CAZADOR: +% a TODA la excelia que ganas (no a una stat suelta). Es el unico perk que toca el
# entreno, y por eso es flojo en numero pero se aplica a todo. Los otros tres se aplican en
# _aplicar_loadout: hacen cosas DISTINTAS en vez de ser el mismo +% con tres nombres.
const CAZADOR_GAIN_BONUS := 0.05
const REFLEJOS_EVASION := 0.05    # Reflejos: +esquiva (baja el evasion_penal)
const ERUDITO_MAGIA := 0.10       # Erudito: +% al amplificador de daño magico
const ENCANT_RAPIDO := 0.15       # Encantamiento rapido: +% de velocidad de casteo

# Ficha del catalogo por id ({} si no existe).
func desarrollo_por_id(id: String) -> Dictionary:
	for d in DESARROLLOS:
		if d["id"] == id:
			return d
	return {}

# Los que AUN puedes elegir: ni repetidos ni sin ganartelos (ver _req_cumplido).
func desarrollos_disponibles() -> Array:
	var out: Array = []
	for d in DESARROLLOS:
		if not desarrollos_elegidos.has(d["id"]) and _req_cumplido(d):
			out.append(d)
	return out

# ¿Te has ganado este desarrollo? Es lo que decide si te APARECE al subir de nivel. El chequeo va
# aqui y no en el catalogo porque los `const Array` de GDScript no admiten lambdas: la ficha se
# queda declarativa ({"req": ..., "contador": ..., "umbral": ...}) y el match vive en un sitio.
func _req_cumplido(d: Dictionary) -> bool:
	match str(d.get("req", "")):
		"exp":
			# El contador se lee por NOMBRE (son propiedades del autoload): asi añadir un
			# desarrollo nuevo es una linea en el catalogo y nada mas.
			return float(get(str(d.get("contador", "")))) >= float(d.get("umbral", 0.0))
		"primer_ascenso":
			return player_level == 1
		_:
			return true   # sin requisito escrito -> siempre disponible

# Lo que te FALTA para ganarte un desarrollo: {"contador", "umbral", "valor", "cumplido"}. Solo lo
# usa el panel de DEBUG: en el juego estos numeros no se enseñan nunca (son ocultos a proposito).
func desarrollo_progreso(d: Dictionary) -> Dictionary:
	var req: String = str(d.get("req", ""))
	if req != "exp":
		return {"contador": req, "umbral": 0.0, "valor": 0.0, "cumplido": _req_cumplido(d)}
	var cont: String = str(d.get("contador", ""))
	return {
		"contador": cont,
		"umbral": float(d.get("umbral", 0.0)),
		"valor": float(get(cont)),
		"cumplido": _req_cumplido(d),
	}

# Aplica la habilidad de desarrollo elegida. Los oficios encienden su interruptor; los perks de
# combate se consultan en vivo (ver desarrollo_gain_mult) via desarrollos_elegidos.
func aplicar_desarrollo(id: String) -> void:
	if id == "" or desarrollos_elegidos.has(id):
		return
	desarrollos_elegidos.append(id)
	match id:
		"metalurgia": habilidad_metalurgia = true
		"peleteria": habilidad_peleteria = true
		"herreria": habilidad_herreria = true
		"mezcla": habilidad_mezcla = true
	print("[desarrollo] Adquieres: ", desarrollo_por_id(id).get("nombre", id))

# Multiplicador de ganancia de excelia por los perks de combate elegidos (1.0 si ninguno aplica).
# Hoy solo el CAZADOR toca el entreno, y toca el de TODAS las habilidades por igual: el `abil` se
# queda por si algun perk futuro vuelve a mirar la stat concreta.
func desarrollo_gain_mult(_abil: String) -> float:
	if desarrollos_elegidos.has("cazador"):
		return 1.0 + CAZADOR_GAIN_BONUS
	return 1.0


# DEBUG: fija a mano las 5 habilidades VISIBLES (las de este nivel) y cura al 100% para el
# proximo combate. Lo usa el editor de stats del panel de debug.
#
# Ojo con el modelo: lo que se guarda es el INTERNO (el total acumulado), y lo visible se deriva
# restandole ability_base_nivel. Asi que para que se vea `f` hay que escribir base_nivel + f, NO
# `f` a pelo: eso solo funcionaba en el nivel 1 (base_nivel = 0). Del nivel 2 en adelante metia
# un interno POR DEBAJO de la base del nivel, y _visible_nivel lo cortaba a 0 (de ahi que las
# stats "volvieran a cero"); encima se cargaba el total acumulado, que es lo que alimenta la
# recoleccion y el reto.
func debug_set_abilities(f: int, r: int, d: int, a: int, m: int) -> void:
	_debug_set_visible("fuerza", f)
	_debug_set_visible("resistencia", r)
	_debug_set_visible("destreza", d)
	_debug_set_visible("agilidad", a)
	_debug_set_visible("magia", m)
	actualizar_estado()          # sincroniza lo visible con lo interno
	player_current_hp = -1.0     # vida llena en el proximo combate
	player_current_mp = -1.0     # mana lleno en el proximo combate

# Deja el VISIBLE de `s` en `valor` moviendo el interno. El interno resultante puede pasar de
# ABILITY_CAP si ya llevas mucha base acumulada: es una herramienta de debug y manda lo que pides
# ver; ganar() lo aguanta (su factor tiene suelo, DIMINISH_FLOOR).
func _debug_set_visible(s: String, valor: int) -> void:
	if not ability_internal.has(s):
		return
	ability_internal[s] = float(ability_base_nivel[s]) + float(clampi(valor, 0, 999))


# Teclas de DESARROLLO (temporales): U actualizar estado, H cura, R respawn.
#
# OJO, va en _unhandled_key_input Y NO EN _input A PROPOSITO: _input corre ANTES que la GUI,
# asi que estas teclas se comian lo que escribias en cualquier campo de texto (el nombre de la
# creacion de personaje: la R recargaba la escena, la T te mandaba al sandbox...). Un control
# con el foco (LineEdit) CONSUME las teclas, y lo "unhandled" solo recibe las que nadie ha
# consumido: asi se escribe tranquilo y las teclas de dev siguen funcionando por el mapa.
# No lo devuelvas a _input.
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# En el MENU todavia no hay partida: aqui una T (sandbox) o una R (recargar) no llevan a
	# ningun sitio bueno, porque no hay personaje que meter en el mundo.
	var esc: Node = get_tree().current_scene
	if esc != null and esc.scene_file_path.ends_with("main_menu.tscn"):
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
		KEY_N:
			# Salta el reloj 10 min de juego: para probar el respawn de recursos sin esperar.
			tiempo_mazmorra += 600.0
			print("[dev] +10 min de reloj de mazmorra (total %.0fs). Recarga el piso (R) para ver el respawn." % tiempo_mazmorra)


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

	# CURA DE POCIÓN pendiente del MAPA: si bebiste una poción fuera de combate y aún te quedaba
	# cura por gotear (player_heal_left) al entrar, NO se pierde con la pausa del árbol: se
	# convierte en Regeneración dentro del combate (repartida en turnos) y se consume el pendiente.
	# Simétrico a arrastrar_regen (que lleva la regen de combate de vuelta al mapa).
	if player_heal_left > 0.0:
		player_c.apply_status(StatusEffects.Id.REGENERACION, POCION_ARRASTRE_TURNOS,
			player_heal_left / float(POCION_ARRASTRE_TURNOS))
		player_heal_left = 0.0
		player_heal_rate = 0.0
	if player_mana_heal_left > 0.0:
		player_c.apply_status(StatusEffects.Id.REGEN_MANA, POCION_ARRASTRE_TURNOS,
			player_mana_heal_left / float(POCION_ARRASTRE_TURNOS))
		player_mana_heal_left = 0.0
		player_mana_heal_rate = 0.0

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

	# COOLDOWNS que viajan entre combates: bajan 1 por ENTRAR a este combate (ademas de por turno
	# dentro), y se cargan en el combatiente para que un nuke usado en la pelea anterior siga
	# cociendo. Sin esto, el Combatant nace con los CD a cero cada combate y podias repetir el
	# mazazo en cada pelea.
	var cd_carry: Dictionary = {}
	for ab in ability_cooldowns_persist:
		var left: int = int(ability_cooldowns_persist[ab]) - 1
		if left > 0:
			cd_carry[ab] = left
	ability_cooldowns_persist = cd_carry
	player_c.ability_cooldowns = cd_carry.duplicate()
	_active_player_c = player_c

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
	# Destreza TOTAL (acumulada, oculta): recolectar no se endurece al subir de nivel (el visible cae a 0).
	var eff_destreza: int = stat_total("destreza") + tool_destreza_bonus

	# Exigencia por TIER del cristal (no por enemigo ni por piso): un t4 cuesta lo mismo lo saques
	# donde lo saques. Tabla EXTRACTION_REQ_POR_TIER indexada por categoria (reserva al ultimo).
	var tier_idx: int = clampi(categoria, 1, EXTRACTION_REQ_POR_TIER.size() - 1)
	var req: float = maxf(1.0, float(EXTRACTION_REQ_POR_TIER[tier_idx]))

	# Dificultad RELATIVA: exigencia del tier / tu DESTREZA (solo Destreza, con peso y suelo).
	# ~1 = a la par; >1 mas dificil. Subir Destreza sigue facilitando los tiers altos.
	var difficulty: float = req / (float(eff_destreza) * RECOLECCION_STAT_PESO + EXTRACTION_DESTREZA_FLOOR)
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
	# Marcador: mas rapido cuanto mas DIFICIL (ahora la dificultad la pone el TIER, no el piso),
	# con TECHO y con SUELO (ver RECOLECCION_VEL_RETO_MIN: ser bueno no puede frenar el marcador).
	var marker_speed: float = EXTRACTION_BASE_MARKER \
		* clampf(difficulty, RECOLECCION_VEL_RETO_MIN, RECOLECCION_VEL_RETO_MAX)
	marker_speed = minf(marker_speed, EXTRACTION_MARKER_MAX)
	var speed_step: float = 0.15
	print("[reco] extraccion tier %d (req %.0f) · Destreza %d -> reto %.2f  (zona %.3f, marcador %.2f, pulsaciones %d)" % [
		categoria, req, player_destreza, difficulty, zone_ratio, marker_speed, required_hits])

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
	var d: float = _exigencia_material(m) / (float(stat_total("fuerza")) * RECOLECCION_STAT_PESO + MINERIA_FUERZA_FLOOR)

	# La Fuerza ensancha la franja optima Y la baja (no necesitas cargar tanto el pico).
	var ancho: float = clampf(MINERIA_BASE_VENTANA / d, 0.06, 0.45) + p.ventana_bonus
	ancho = clampf(ancho, 0.06, 0.60)
	var ini: float = clampf(0.45 * d, 0.15, 1.0 - ancho - 0.05)
	var carga: float = MINERIA_BASE_CARGA \
		* clampf(d, RECOLECCION_VEL_RETO_MIN, RECOLECCION_VEL_RETO_MAX) \
		+ 0.06 * float(current_floor - 1) - p.control
	# El techo se aplica AL FINAL, con el piso y el pico ya dentro: si se aplicara antes, la
	# profundidad volveria a colarse por encima de el.
	carga = clampf(carga, MINERIA_CARGA_MIN, MINERIA_CARGA_MAX)
	var golpes: int = clampi(roundi(MINERIA_GOLPES_BASE * d), 2, 8) - p.golpes_menos
	golpes = maxi(2, golpes)

	_last_reco_reto = d
	print("[reco] mineria %s · piso %d · Fuerza %d · exigencia %.0f -> reto %.2f  (franja %.3f, carga %.2f, golpes %d)" % [
		m.nombre, current_floor, player_fuerza, _exigencia_material(m), d, ancho, carga, golpes])
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
		descubrir(item.data)
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

	var d: float = _exigencia_material(m) / (float(stat_total("destreza")) * RECOLECCION_STAT_PESO + HERB_DESTREZA_FLOOR)

	var nucleo: float = clampf(HERB_BASE_NUCLEO / d, 0.015, 0.14) + h.filo
	var borde: float = nucleo * HERB_BORDE_MULT
	# El techo (HERB_VEL_MAX) estaba declarado pero NO se aplicaba: la pasada podia dispararse
	# con el piso y volverse imposible de seguir con la vista, que es justo lo que el techo
	# existia para evitar. Ahora se aplica, y con el suelo comun al otro lado.
	var vel: float = HERB_BASE_VEL \
		* clampf(d, RECOLECCION_VEL_RETO_MIN, RECOLECCION_VEL_RETO_MAX) \
		+ 0.05 * float(current_floor - 1)
	vel = minf(vel, HERB_VEL_MAX)
	# Mas cortes (tope 8, antes 5) para compensar el techo de velocidad mas bajo (HERB_VEL_MAX):
	# un material exigente pide mas tallos seguibles en vez de una sola pasada imposible.
	var cortes: int = clampi(2 + floori(d), 2, 8) - h.cortes_menos
	cortes = maxi(2, cortes)

	_last_reco_reto = d
	print("[reco] herboristeria %s · piso %d · Destreza %d · exigencia %.0f -> reto %.2f  (nucleo %.3f, vel %.2f, cortes %d)" % [
		m.nombre, current_floor, player_destreza, _exigencia_material(m), d, nucleo, vel, cortes])
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
		descubrir(item.data)
		print("Recoges ", item.nombre(), " (", item.calidad_texto(), "). Materiales: ", materiales.size())
	else:
		print("La planta queda hecha jirones: no sirve.")
	ganar("destreza", curva_reto(_last_reco_reto, HERB_PIVOTE, HERB_SLOPE, HERB_RETO_MAX),
		GAIN_DESTREZA_PLANTA)


# --- TALADO ---
func start_talado(nodo) -> void:
	if _active_layer != null or nodo == null or nodo.material_data == null:
		return
	var m: MaterialData = nodo.material_data
	var a: ToolData = hacha()

	var d: float = _exigencia_material(m) / (float(stat_total("agilidad")) * RECOLECCION_STAT_PESO + TALA_AGILIDAD_FLOOR)

	# La Agilidad ensancha la ventana del hachazo y frena el tempo. El hacha ayuda encima.
	var ancho: float = clampf(TALA_BASE_VENTANA / d, 0.05, 0.40) + a.compas
	ancho = clampf(ancho, 0.05, 0.50)
	var tempo: float = TALA_BASE_TEMPO \
		* clampf(d, RECOLECCION_VEL_RETO_MIN, RECOLECCION_VEL_RETO_MAX) \
		+ 0.05 * float(current_floor - 1)
	tempo = minf(tempo, TALA_TEMPO_MAX)
	var hachazos: int = clampi(roundi(TALA_HACHAZOS_BASE * d), 3, 9) - a.hachazos_menos
	hachazos = maxi(3, hachazos)

	_last_reco_reto = d
	print("[reco] talado %s · piso %d · Agilidad %d · exigencia %.0f -> reto %.2f  (ventana %.3f, tempo %.2f, hachazos %d)" % [
		m.nombre, current_floor, player_agilidad, _exigencia_material(m), d, ancho, tempo, hachazos])
	var ex: Control = _talado_script.new()
	ex.process_mode = Node.PROCESS_MODE_ALWAYS
	ex.setup(m, hachazos, ancho, tempo)
	ex.talado_finished.connect(_on_talado_finished.bind(nodo))
	_abrir_pantalla(ex)


func _on_talado_finished(item: MaterialItem, nodo) -> void:
	_cerrar_recoleccion(nodo)
	if item == null:
		return
	if not item.se_pierde():
		materiales.append(item)
		descubrir(item.data)
		print("Sacas ", item.nombre(), " (", item.calidad_texto(), "). Materiales: ", materiales.size())
	else:
		print("El tronco se raja en astillas: no sacas nada.")
	# Como en la mineria: la Agilidad se entrena aunque la pieza salga rota. Lo que pierdes al
	# hacerlo mal es el botin, no el aprendizaje.
	ganar("agilidad", curva_reto(_last_reco_reto, TALA_PIVOTE, TALA_SLOPE, TALA_RETO_MAX),
		GAIN_AGILIDAD_TALA, RETO_MAX_FISICO)


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
				var stat: float = float(stat_total("fuerza") if es_veta else stat_total("destreza"))
				var suelo: float = MINERIA_FUERZA_FLOOR if es_veta else HERB_DESTREZA_FLOOR
				var d: float = _exigencia_material(m) / (stat * RECOLECCION_STAT_PESO + suelo)
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

	# Los COOLDOWNS que queden al terminar viajan al siguiente combate (ver start_combat).
	if _active_player_c != null:
		ability_cooldowns_persist = (_active_player_c.ability_cooldowns as Dictionary).duplicate()
		_active_player_c = null

	# Si ganaste, el enemigo NO desaparece: queda como cadaver para poder
	# extraerle el cristal (minijuego, Fase 5).
	if player_won and is_instance_valid(_active_enemy):
		# ¿Era un "guardián del rango"? Vencerlo desbloquea SU nivel objetivo (persistente).
		if "data" in _active_enemy and _active_enemy.data != null and _active_enemy.data.nivel_que_otorga > 0:
			var nv: int = _active_enemy.data.nivel_que_otorga
			guardianes_vencidos[nv] = true
			print("[nivel] Vencido el guardián del nivel ", nv, ": podrás ascender si tienes rango C.")
		if _active_enemy.has_method("morir"):
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
