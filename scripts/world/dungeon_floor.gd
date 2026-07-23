# ============================================================
#  dungeon_floor.gd
#  Nodo raiz del PISO de la mazmorra. Hace dos trabajos:
#
#  1) LEVANTA EL PISO: lo traza con DungeonGenerator (semilla derivada de la profundidad:
#     el mismo piso da siempre el mismo mapa, y al bajar sale otro), construye la
#     geometria fusionando celdas en tramos, y coloca jugador, puerta y escalera.
#
#  2) HACE DE SPAWNER DEL PISO: crea una SpawnZone por sala y por pasillo (las paredes de
#     cada zona paren monstruos) y lleva la contabilidad GLOBAL: cuantos bichos vivos
#     aguanta el piso, a quien se recicla cuando esta lleno, y a quien se le congela la IA
#     por estar lejisimos.
#
#  El piso NO toca la dificultad: el escalado por profundidad ya lo llevan
#  Game.enemy_floor_stat_factor y Game.enemy_ability_sum_band. Aqui solo se decide la
#  FORMA del piso y QUE bicho nace y DONDE.
# ============================================================

extends Node2D
class_name DungeonFloor

# --- Tamaño del piso (en CELDAS de 32 px) ---
# 100x60 = 3200x1920 px. La sala unica de antes eran 440x260: esto es ~54 veces mas.
@export var ancho_celdas: int = 100
@export var alto_celdas: int = 60
@export var max_salas: int = 14
@export var sala_min: Vector2i = Vector2i(8, 6)
@export var sala_max: Vector2i = Vector2i(18, 12)
# Pasillo de 3 celdas (96 px) = cabeis tu y un bicho, y puedes esquivarlo. A 1 celda el
# pasillo mide justo lo que tu, y solo se avanza rozando la pared.
@export var ancho_pasillo: int = 3

# Semilla del piso 1. Los siguientes la derivan de esta (ver _semilla_del_piso).
@export var semilla_base: int = 20260712

# --- QUE pare la mazmorra: la tabla del piso (familias -> variantes) ---
@export var spawn_table: SpawnTable

# --- QUE SE RECOLECTA en el piso ---
# Las PLANTAS crecen en los PASILLOS (las pisas de camino a cualquier sitio: es el botin
# del transito). Las VETAS estan en las SALAS LEJANAS, y nunca en la de entrada ni en la de
# la escalera de bajar: picar tiene que costarte meterte en la mazmorra, no ser un peaje que
# pagas de paso. Los .tres van como valor por defecto para no tener que tocar la escena.
@export var tabla_vetas: MaterialTable = preload("res://resources/world/vetas.tres")
@export var tabla_plantas: MaterialTable = preload("res://resources/world/plantas.tres")
# Las ENREDADERAS (madera) trepan por la pared del PASILLO: se reparten como las plantas, y
# _ocupada ya impide que nazcan las dos en la misma celda.
@export var tabla_maderas: MaterialTable = preload("res://resources/world/maderas.tres")
# Cuantas celdas de pasillo por planta, y cuantas plantas aguanta un pasillo.
@export var celdas_por_planta: int = 18
@export var max_plantas_pasillo: int = 3
# Vetas por sala elegida (se tira entre estos dos).
@export var vetas_min_sala: int = 1
@export var vetas_max_sala: int = 2
# TOPE por piso. Es lo que de verdad manda: los numeros de arriba son la forma del reparto
# (donde caen), esto es CUANTAS hay. En el PISO 1. Ver escalar_con_el_piso().
# Densidad subida a 8 (era 5): con el respawn por tiempo ya no es farmeo infinito (picar uno no
# hace aparecer otro; el que picas tarda RESPAWN_SEGUNDOS de juego en volver), asi que puede
# haber mas nodos a la vista sin romper la economia.
@export var max_vetas_piso: int = 8
@export var max_plantas_piso: int = 8
@export var max_madera_piso: int = 8

# Cada cuanto se mira si a algun nodo picado le toca ya reaparecer. No hace falta afinar mas:
# el respawn son minutos, y barrer el diccionario de agotados cada frame seria tirar CPU.
const RESPAWN_CHECK_CADA := 2.0
var _t_respawn: float = RESPAWN_CHECK_CADA

# --- RITMO de los partos (segundos). Franja ANCHA y LENTA a proposito: ver spawn_zone.gd ---
@export var intervalo_min: float = 25.0
@export var intervalo_max: float = 70.0

# --- Topes de poblacion ---
# Vivos que aguanta el piso ENTERO EN EL PISO 1. Toda la mazmorra pare a la vez, asi que sin
# este tope el mapa se llenaria hasta reventar el rendimiento. NO se usa a pelo: se escala
# con la profundidad (ver max_vivos()), porque los pisos van a ir creciendo al bajar.
@export var max_vivos_piso: int = 20
# Vivos por zona: se derivan del AREA (celdas / esto), acotados por los maximos de abajo.
# OJO al contar: los pasillos que desembocan en una sala tienen SUS bichos, y desde dentro
# de la sala parecen suyos. Una sala a tope (3) con dos bocas de pasillo (1 cada una) ya se
# ve como 5 bichos encima. Por eso los topes son bajos: lo que cuenta es lo que VES junto.
@export var celdas_por_bicho: int = 40
@export var max_vivos_sala: int = 3
@export var max_vivos_pasillo: int = 1
# El aforo por zona TAMBIEN se escala con la profundidad (AFORO_ZONA_GROWTH, su propia rampa): si
# solo creciera el numero de bichos del piso, un piso hondo seria el mismo mapa con mas salas de
# tres, y lo que se quiere es que ABAJO TE ENCUENTRES CORROS MAS GORDOS. Con topes duros, eso si:
#   - la sala se queda en 5 = MAX_COMBATIENTES (Enemy). Mas de cinco no caben en una pelea, asi
#     que el sexto solo serviria para mirar; el sitio para crecer es el numero de salas, no el
#     tamaño del corro. OJO: el aforo es cuantos DEAMBULAN, no cuantos te saltan: eso lo modula la
#     tendencia de manada (escala con tu grupo), asi que un jugador solo no se come 5 por tener sitio.
#   - el pasillo, en 2: un pasillo es un sitio de paso, y peleas a cinco en un tubo de tres
#     celdas de ancho son sitiadas sin escapatoria.
const TOPE_SALA := 5
const TOPE_PASILLO := 2

# Que fraccion del aforo de cada zona ya esta poblada AL ENTRAR al piso. Una mazmorra
# tiene bichos deambulando cuando llegas; los partos son el goteo que viene despues. A 0
# entrarias a un piso vacio y en silencio durante el primer intervalo entero. Ni vacia ni
# a reventar: la mazmorra se nota habitada, y aun queda hueco para que las paredes paran.
@export_range(0.0, 1.0) var poblacion_inicial: float = 0.6

# La sala DONDE APARECES nace LIMPIA: nada de abrir la puerta y encontrarte tres esperandote.
# Sus paredes siguen pariendo con el tiempo, asi que no es un refugio eterno: es un respiro para
# orientarte y decidir por donde sales. OJO: es la sala en la que aterrizas DE VERDAD, que no
# siempre es la boca del piso (por el atajo o subiendo apareces en el fondo); ver _zona_aterrizaje.
@export var entrada_despejada: bool = true

# --- Distancias (px) ---
# Mas lejos de esto, a un enemigo se le apaga la IA (no lo ves: no hace falta simularlo).
@export var dist_congelar: float = 1400.0
# Al tope global, se RECICLA (despawnea) al vivo mas lejano para que la sala donde estas
# pueda seguir pariendo. Solo si esta MAS lejos que esto: nunca se borra algo que puedas ver.
@export var dist_reciclar: float = 2000.0

# --- Colores placeholder (el pase visual va al final) ---
@export var color_suelo: Color = Color(0.16, 0.15, 0.19)
@export var color_roca: Color = Color(0.06, 0.06, 0.08)
@export var color_muro: Color = Color(0.34, 0.32, 0.40)

# La puerta de vuelta al pueblo (ya montada en la escena). Va por NodePath y no por grupo:
# el grupo lo añade door.gd en su _ready, que puede correr DESPUES que el nuestro.
@export var puerta_pueblo: NodePath

# ------------------------------------------------------------
#  DENSIDAD POR PISO
#  Si los topes fueran numeros fijos, un piso el doble de grande tendria la MITAD de densidad: la
#  mazmorra se iria vaciando cuanto mas hondo, que es lo contrario de lo que tiene que pasar. Asi
#  que TODO lo que se reparte por el piso (bichos, vetas, plantas) se declara para el PISO 1 y se
#  escala con el AREA REAL del piso (ver escalar_con_el_piso -> _factor_area_piso).
#
#  OJO, que esto se torcio una vez: antes se escalaba con una constante propia del 10% compuesto,
#  escrita cuando el plan era que el mapa TAMBIEN creciera un 10% por piso. Luego el area se
#  implemento con pasos DECRECIENTES (7% -> 1.5%) y las dos curvas se separaron: los bichos crecian
#  mucho mas rapido que el sitio donde meterlos y sobre el piso 18-20 el piso quedaba saturado (todas
#  las salas al tope). Atandolo al area, la densidad es constante POR CONSTRUCCION y da igual como
#  se toque la curva del mapa mañana.
# ------------------------------------------------------------

# El MAPA crece con la profundidad, pero SIN TOPE y con el aumento DECRECIENTE: cada piso hondo
# crece un poco más, cada vez menos, sin pararse nunca. El % de crecimiento de un piso arranca en
# AREA_STEP_MAX (~7%) y decae hacia AREA_STEP_MIN (un suelo que NUNCA se cruza), así que el mapa
# siempre gana algo aunque bajes mil pisos. El AREA acumulada es el producto de esos pasos; cada
# lado se escala por su raiz, y el nº de salas por el area entera (si no, un mapa mayor con las
# mismas salas queda vacio de pasillos). PROVISIONAL -> Excel.
const AREA_STEP_MAX := 0.07    # crecimiento del primer piso que se baja (~7%)
const AREA_STEP_MIN := 0.015   # suelo: nunca se crece MENOS que esto por piso (nunca se para)
const AREA_STEP_DECAY := 0.88  # cuanto se acerca el paso al suelo cada piso (0..1: mas alto = decae mas lento)

# CUANTOS hay de algo repartido por el piso (bichos, vetas, plantas), a partir de su numero del
# PISO 1. Sigue al AREA del piso, asi que la densidad no cambia por bajar: un piso el doble de
# grande trae el doble de cosas, ni mas ni menos.
func escalar_con_el_piso(base: int) -> int:
	return maxi(1, roundi(float(base) * _factor_area_piso()))


# Rampa del AFORO POR ZONA (cuantos caben en UNA sala/pasillo). Va aparte de escalar_con_el_piso a
# proposito: aquella reparte CANTIDAD por el mapa y por eso sigue al area; esta engorda el CORRO de
# una sala, que es otra promesa de diseño ("abajo te encuentras corros mas gordos") y que ya tiene
# freno propio en TOPE_SALA / TOPE_PASILLO. Por eso puede subir rapido sin desmadrarse.
const AFORO_ZONA_GROWTH := 1.10
func _aforo_zona(base: int) -> int:
	return maxi(1, roundi(float(base) * pow(AFORO_ZONA_GROWTH, float(maxi(1, _piso_construido) - 1))))

# El % de crecimiento del piso `n` (n = pisos bajados desde el 1, empezando en 1): arranca en
# AREA_STEP_MAX y decae exponencialmente hacia AREA_STEP_MIN, sin bajar de él.
func _paso_area(n: int) -> float:
	return AREA_STEP_MIN + (AREA_STEP_MAX - AREA_STEP_MIN) * pow(AREA_STEP_DECAY, float(n - 1))

# Factor de AREA acumulado de este piso (producto de los pasos de cada piso bajado), y el LINEAL.
func _factor_area_piso() -> float:
	var factor: float = 1.0
	for i in range(1, maxi(1, _piso_construido)):   # un paso por cada piso bajado desde el 1
		factor *= 1.0 + _paso_area(i)
	return factor

func _factor_lineal_piso() -> float:
	return sqrt(_factor_area_piso())

# Vivos que aguanta ESTE piso (el @export es el del piso 1).
func max_vivos() -> int:
	return escalar_con_el_piso(max_vivos_piso)


var gen: DungeonGenerator = null

var _enemy_scene: PackedScene = preload("res://scenes/actors/enemy/enemy.tscn")
var _zone_script: GDScript = preload("res://scripts/world/spawn_zone.gd")
var _stairs_script: GDScript = preload("res://scripts/world/stairs.gd")
var _exit_script: GDScript = preload("res://scripts/world/dungeon_exit.gd")
var _pickup_script: GDScript = preload("res://scripts/items/drop_pickup.gd")
var _reco_script: GDScript = preload("res://scripts/world/resource_node.gd")

# --- BOSS del piso (si lo hay) ---
# Donde van la bajada y la salida al pueblo, y si ya estan puestas. En un piso con boss SIN
# matar no se colocan: el piso es un callejon hasta que cae.
var _salida_pos: Vector2 = Vector2.INF
var _salidas_puestas: bool = false
# Zona (sala) que ocupa el boss: no pare bichos. Nadie le hace de escolta.
var _sala_boss: int = -1
# Zona en la que ATERRIZA el jugador al construirse el piso. La fija _colocar_actores (que es
# quien decide donde apareces) y la lee _crear_zonas para no poblarla. NO se puede dar por hecho
# que sea la boca: por el atajo, o subiendo, apareces en el FONDO.
var _zona_aterrizaje: int = -1

var _geo: Node2D = null      # toda la geometria del piso (se tira entera al regenerar)
var _zonas: Node2D = null    # todas las SpawnZone
var _t_barrido: float = 0.0  # acumulador del barrido de congelado

# CELDAS ya recolectadas de este piso (celda -> true). Lo unico que hace falta recordar de
# la recoleccion: DONDE estaba cada veta y de que era ya lo decide la semilla, asi que basta
# con saber cuales YA NO estan. Se vuelca a Game.memoria_pisos y vuelve de ahi.
var _agotados: Dictionary = {}

# QUE profundidad esta construida ahora mismo. NO se puede usar Game.current_floor para
# guardar el estado al salir: cuando el piso se regenera, current_floor YA vale el piso
# NUEVO (lo sube Game._cambiar_piso antes de llamarnos), y guardariamos los bichos del piso
# viejo bajo el numero del nuevo -> te los encontrarias esperandote abajo.
var _piso_construido: int = 0

const BARRIDO_CADA := 0.5


func _ready() -> void:
	add_to_group("dungeon_floor")  # asi Game.bajar_piso nos encuentra
	z_index = -1                   # el piso se dibuja por detras del jugador y de los bichos

	# SIN PARTIDA no hay mazmorra que construir. Pasa al ejecutar ESTA escena a pelo desde el
	# editor (F6 / "ejecutar escena actual" con main.tscn abierta): te saltas el menu, no se crea
	# ni se carga nada, y acababas dentro de una mazmorra sin personaje y con el mundo sin semilla.
	# El juego de verdad (F5) arranca en main_menu y nunca pasa por aqui sin partida.
	if not Game.hay_partida():
		push_warning("[mazmorra] no hay partida cargada: al menu principal")
		call_deferred("_al_menu_principal")   # diferido: no se cambia de escena desde un _ready
		return

	_construir()


func _al_menu_principal() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


# Vuelve a trazar el piso ENTERO (lo llama Game.bajar_piso). Sin recargar la escena: el
# jugador, su HUD y sus menus siguen vivos. Lo del piso viejo (bichos, cadaveres y lo que
# hubiera por el suelo) se queda atras: bajas con lo que llevas encima.
func regenerar(por_la_bajada: bool = false) -> void:
	_limpiar()
	_construir(por_la_bajada)
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("bloquear_interaccion"):
		player.bloquear_interaccion()  # bajar es pulsar F: que no dispare nada al aterrizar


func _limpiar() -> void:
	_guardar_estado()   # ANTES de tirar nada: el piso que dejas se queda como lo dejas
	for grupo in ["enemy", "corpse", "pickup", "recolectable"]:
		for n in get_tree().get_nodes_in_group(grupo):
			if not is_instance_valid(n):
				continue
			# SACARLOS DEL GRUPO YA, no solo liberarlos: queue_free() no borra al instante
			# (lo hace al final del frame), asi que los bichos del piso viejo seguian
			# contando como vivos cuando el piso nuevo se poblaba -> el tope global se daba
			# por lleno y el piso 2 nacia VACIO.
			n.remove_from_group(grupo)
			n.queue_free()
	if _geo != null:
		_geo.queue_free()
		_geo = null
	if _zonas != null:
		_zonas.queue_free()
		_zonas = null


func _construir(por_la_bajada: bool = false) -> void:
	_piso_construido = Game.current_floor
	# Estado del boss: se recalcula en cada piso (las salidas se colocan mas abajo, y la sala
	# del boss se decide al colocarlo).
	_salida_pos = Vector2.INF
	_salidas_puestas = false
	_sala_boss = -1
	_zona_aterrizaje = -1
	gen = DungeonGenerator.new()
	# El tamaño del @export es el del piso 1; abajo el mapa crece (ver AREA_GROWTH).
	var fl: float = _factor_lineal_piso()
	var w: int = roundi(float(ancho_celdas) * fl)
	var h: int = roundi(float(alto_celdas) * fl)
	var salas: int = roundi(float(max_salas) * _factor_area_piso())
	if _piso_construido > 1:
		print("[mazmorra] piso %d: %dx%d celdas · %d salas (x%.2f area)" % [
			_piso_construido, w, h, salas, _factor_area_piso()])
	gen.generar(w, h, _semilla_del_piso(),
		salas, sala_min, sala_max, ancho_pasillo)

	# Lo que ya picaste en este piso, con el SELLO de tiempo de cuando lo picaste (para el
	# respawn). Vive en mazmorra_persistente, que sobrevive a volver al pueblo: por eso picar un
	# nodo y salir/entrar ya no lo resetea. { celda: tiempo_mazmorra en que se pico }.
	_agotados = (Game.persistente_piso(_piso_construido)["agotados"] as Dictionary).duplicate()
	# MULTIJUGADOR: los sellos de MI save no pintan nada en el mundo del host. Se arranca en
	# limpio; lo agotado en ESTA expedicion lo trae Net (celda_agotada_sesion) al construir.
	if Net.activo:
		_agotados = {}

	_construir_geometria()
	_colocar_actores(por_la_bajada)
	_crear_zonas()
	# DIFERIDO, por lo mismo que poblar() (ver _crear_zonas): al construir el piso desde
	# _ready, el nodo padre (Main) aun esta montando sus hijos y Godot RECHAZA cualquier
	# add_child. Las vetas y las plantas se creaban, se contaban en el log... y no entraban
	# en la escena: un piso entero sin un solo mineral a la vista.
	call_deferred("_colocar_recolectables")

	print("[mazmorra] piso ", Game.current_floor, " | semilla ", gen.semilla,
		" | ", gen.salas.size(), " salas, ", gen.zonas.size(), " zonas",
		" | ", gen.ancho, "x", gen.alto, " celdas")
	if spawn_table != null:
		print("[mazmorra] paren las paredes: ", spawn_table.resumen(Game.current_floor))
	else:
		push_warning("[mazmorra] el piso no tiene tabla de spawns: no va a parir nada")


# Cada piso, su mapa. La base es la SEMILLA DEL MUNDO de ESTA PARTIDA: cada jugador (y cada
# ranura de guardado) tiene SU mazmorra, y le dura. El numero primo evita que pisos
# consecutivos salgan parecidos. Si no hubiera partida cargada, el @export hace de reserva.
func _semilla_del_piso() -> int:
	var base: int = Game.semilla_mundo if Game.semilla_mundo != 0 else semilla_base
	# MULTIJUGADOR: se juega en el MUNDO DEL HOST. El cliente usa la semilla que le llego en el
	# handshake (Net.semilla_host) y genera la MISMA mazmorra sin replicar geometria; su propia
	# semilla (la de SU save) no se toca. En el host semilla_host vale 0: usa la suya.
	if Net.activo and Net.semilla_host != 0:
		base = Net.semilla_host
	return base + Game.current_floor * 7919


# ------------------------------------------------------------
#  GEOMETRIA
#  Ni un nodo por celda: las celdas contiguas se fusionan en tramos horizontales (Rect2i)
#  y cada tramo es UN ColorRect. La colision entera vive en un solo StaticBody2D con una
#  forma por tramo de muro.
# ------------------------------------------------------------
func _construir_geometria() -> void:
	var celda: float = float(DungeonGenerator.CELDA)

	_geo = Node2D.new()
	_geo.name = "Geo"
	add_child(_geo)

	# Fondo: la roca maciza (lo que hay detras de las paredes).
	var fondo := ColorRect.new()
	fondo.color = color_roca
	fondo.size = gen.tam_px()
	_geo.add_child(fondo)

	# Suelo pisable.
	for r in gen.suelos_fusionados():
		var cr := ColorRect.new()
		cr.color = color_suelo
		cr.position = Vector2(r.position) * celda
		cr.size = Vector2(r.size) * celda
		_geo.add_child(cr)

	# Muros: color + colision. Solo la roca que TOCA suelo (al resto no llegas nunca).
	var cuerpo := StaticBody2D.new()
	cuerpo.name = "Muros"
	_geo.add_child(cuerpo)
	for r in gen.muros_fusionados():
		var cr := ColorRect.new()
		cr.color = color_muro
		cr.position = Vector2(r.position) * celda
		cr.size = Vector2(r.size) * celda
		cuerpo.add_child(cr)

		var forma := RectangleShape2D.new()
		forma.size = Vector2(r.size) * celda
		var col := CollisionShape2D.new()
		col.shape = forma
		col.position = (Vector2(r.position) + Vector2(r.size) * 0.5) * celda
		cuerpo.add_child(col)


# ------------------------------------------------------------
#  ACTORES: jugador, puerta al pueblo y escalera de bajada.
#  El jugador y la puerta ya existen en la escena: aqui solo se los MUEVE a la sala de
#  entrada, que cambia con cada piso.
# ------------------------------------------------------------
func _colocar_actores(por_la_bajada: bool = false) -> void:
	if gen.salas.is_empty():
		push_warning("[mazmorra] el generador no saco ninguna sala")
		return

	var entrada: Rect2i = gen.salas[0]
	var centro: Vector2 = gen.centro_px(entrada.get_center())
	var lejana: Rect2i = _sala_mas_lejana(entrada)
	var fondo: Vector2 = gen.centro_px(lejana.get_center()) if lejana.size != Vector2i.ZERO else centro

	# DONDE APARECES:
	#  - Si CARGAS una partida hecha dentro de la mazmorra: en el sitio EXACTO donde guardaste.
	#  - Si vienes de abajo (has SUBIDO): por la escalera del fondo, no en la boca del piso.
	#    Subir no puede ser un atajo a la salida: hay que rehacer el camino.
	#  - Si entras por el ATAJO a un piso de boss: por SU puerta al pueblo, que esta en el fondo.
	#    Ese es el premio del jefe; dejarte en la boca te obligaria a cruzar el piso otra vez.
	#  - Si no: en la boca del piso.
	# El recado del atajo se consume SIEMPRE (aunque mande pos_cargada): es de un solo uso y no
	# puede quedarse encendido para el siguiente piso que se construya.
	var por_atajo: bool = Game.entrada_por_atajo
	Game.entrada_por_atajo = false
	var destino: Vector2 = fondo if (por_la_bajada or por_atajo) else centro
	if Game.pos_cargada != Vector2.INF:
		destino = Game.pos_cargada
		Game.pos_cargada = Vector2.INF   # de un solo uso: solo al cargar la partida

	# La zona en la que caes, sea cual sea el camino por el que has llegado (boca, fondo o el sitio
	# exacto de una partida cargada): _crear_zonas la lee para NO poblarla. Se saca del destino YA
	# resuelto y no de gen.salas[0], que solo acertaba cuando entrabas por la boca.
	_zona_aterrizaje = gen.zona_en(Vector2i((destino / float(DungeonGenerator.CELDA)).floor()))

	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("recolocar"):
		player.recolocar(destino)  # recolocar, no mover a pelo: no regala excelia de distancia

	# Que hay en la BOCA del piso, 2 celdas por encima de ti:
	#  - piso 1: la PUERTA al pueblo (el pueblo esta en la entrada de la mazmorra, no en
	#    cada piso: si te sigue hacia abajo, del piso 5 sales al pueblo de un paso).
	#  - piso 2+: una escalera de SUBIR al piso anterior. La puerta se aparta y se esconde.
	var boca: Vector2 = centro + Vector2(0.0, -2.0 * float(DungeonGenerator.CELDA))
	var puerta := get_node_or_null(puerta_pueblo)
	if puerta is Node2D:
		var en_superficie: bool = Game.current_floor <= 1
		(puerta as Node2D).visible = en_superficie
		# Fuera del alcance del jugador (la interaccion va por distancia): si solo la
		# ocultamos, seguiria siendo pulsable con F desde la sala de entrada.
		(puerta as Node2D).global_position = boca if en_superficie else Vector2(-1e6, -1e6)

	if Game.current_floor > 1:
		var subir = _stairs_script.new()
		subir.sube = true
		subir.position = boca
		_geo.add_child(subir)

	# El BOSS del piso (si lo hay) guarda la sala central. Se coloca ANTES que la escalera,
	# porque mientras siga sin caer la primera vez no hay escalera que colocar.
	_colocar_boss()

	# La escalera de BAJAR, en la sala mas LEJANA a la entrada: descender obliga a cruzar la
	# mazmorra, que es justo donde el sistema de spawns se tiene que sostener. Va 2 celdas
	# por encima del centro (igual que la boca) para no aterrizar ENCIMA de ella al subir.
	#
	# EXCEPCION: en un piso con boss SIN MATAR no hay bajada ni salida. Es un callejon: o lo
	# matas, o te vuelves por donde has venido.
	_salida_pos = fondo + Vector2(0.0, -2.0 * float(DungeonGenerator.CELDA))
	if lejana.size != Vector2i.ZERO and not Game.piso_bloqueado(Game.current_floor):
		abrir_salidas()


# La bajada al piso siguiente y, si el piso tiene BOSS, una salida al pueblo a su lado. Se
# llama al construir un piso ya abierto, y en caliente cuando cae el boss (enemy.gd:morir).
func abrir_salidas() -> void:
	if _salidas_puestas or _salida_pos == Vector2.INF:
		return
	_salidas_puestas = true

	var bajar = _stairs_script.new()
	bajar.position = _salida_pos
	_geo.add_child(bajar)

	# Salida al PUEBLO junto a la bajada: el premio del boss es no tener que desandar el
	# camino. Van separadas 3 celdas porque el jugador solo puede interactuar con el
	# interactable MAS CERCANO (player._try_interact): pegadas, una taparia a la otra.
	if not Game.BOSSES.has(Game.current_floor):
		return
	var puerta = _exit_script.new()
	puerta.position = _salida_pos + Vector2(3.0 * float(DungeonGenerator.CELDA), 0.0)
	_geo.add_child(puerta)


# ------------------------------------------------------------
#  BOSS: guarda la sala central y bloquea la bajada hasta que cae (la primera vez).
# ------------------------------------------------------------
func _colocar_boss() -> void:
	# MULTIJUGADOR (hito 5.2): el boss lo coloca el DUEÑO del piso, que es quien lo simula; el que
	# solo espeja no lo coloca (lo ve por Net).
	if not Net.simulo_mi_piso():
		return
	var data: EnemyData = Game.boss_del_piso(Game.current_floor)
	if data == null:
		return
	# Si el piso se RESTAURA de memoria, el boss ya vendra con los demas enemigos: no duplicar.
	if Game.memoria_pisos.has(_piso_construido):
		return
	var sala: Rect2i = _sala_central()
	if sala.size == Vector2i.ZERO:
		return
	# La ZONA se marca AQUI MISMO (sincrono): _crear_zonas la lee justo despues para NO poblar la
	# sala del boss. Diferir esto le pondria escolta al jefe.
	_sala_boss = gen.zona_en(sala.get_center())   # su zona NO parira bichos (ver _crear_zonas)
	# El BICHO, en cambio, DIFERIDO, por lo mismo que poblar()/_colocar_recolectables:
	# crear_enemigo cuelga al enemigo de Main (get_parent()), y si el piso se construye desde
	# _ready (entrar por el ATAJO, o cargar una partida en este piso) Main aun esta montando sus
	# hijos y Godot RECHAZA el add_child: el boss se creaba y no entraba en la escena. Bajando por
	# la escalera nunca se noto, porque regenerar() corre con todo montado.
	call_deferred("_parir_boss", data, gen.centro_px(sala.get_center()), _piso_construido)


# El parto del boss, ya con el arbol montado. Lleva el piso al que pertenece: si entre el diferido y
# esta llamada el piso ha cambiado, este jefe ya no es de aqui y no se planta.
func _parir_boss(data: EnemyData, pos: Vector2, piso: int) -> void:
	if piso != _piso_construido:
		return
	var e = crear_enemigo(data, pos, 0.0, 1.0)  # t = 1.0: el techo
	if e != null:
		e.es_boss = true


# La sala mas CENTRADA del mapa. El boss no se esconde en un rincon: se planta en medio y hay
# que pasar por encima de el.
func _sala_central() -> Rect2i:
	var mejor := Rect2i()
	var best_d: float = INF
	var centro_mapa := Vector2(float(gen.ancho), float(gen.alto)) * 0.5
	for s in gen.salas:
		var d: float = centro_mapa.distance_to(Vector2(s.get_center()))
		if d < best_d:
			best_d = d
			mejor = s
	return mejor


# ------------------------------------------------------------
#  RECOLECTABLES: vetas (pico/Fuerza) y plantas (hoz/Destreza).
#  DETERMINISTAS: el mismo piso pone siempre las mismas vetas, del mismo material y en la
#  misma celda. Por eso la memoria del piso solo tiene que recordar cuales YA PICASTE
#  (_agotados) y no la lista entera: lo demas se rehace igual desde la semilla.
# ------------------------------------------------------------
func _colocar_recolectables() -> void:
	if gen == null or gen.salas.is_empty():
		return
	# RNG propio, sembrado aparte del generador: asi tocar la colocacion de las vetas no
	# cambia el TRAZADO del piso (que ya esta hecho y no se toca).
	var rng := RandomNumberGenerator.new()
	rng.seed = _semilla_del_piso() + 1013
	# El piso se rehace: ni las celdas ocupadas ni los sitios del piso viejo valen.
	_ocupada.clear()
	_sitios.clear()

	var plantas: int = _colocar_en_pasillos(rng, tabla_plantas, max_plantas_piso, 1)
	var maderas: int = _colocar_en_pasillos(rng, tabla_maderas, max_madera_piso, 2)
	var vetas: int = _colocar_vetas(rng)
	print("[mazmorra] recolectables: ", vetas, " vetas, ", plantas, " plantas y ",
		maderas, " enredaderas (", _agotados.size(), " ya recolectadas)")
	if tabla_vetas != null:
		print("[mazmorra] vetas del piso: ", tabla_vetas.resumen(Game.current_floor))
	if tabla_plantas != null:
		print("[mazmorra] plantas del piso: ", tabla_plantas.resumen(Game.current_floor))
	if tabla_maderas != null:
		print("[mazmorra] maderas del piso: ", tabla_maderas.resumen(Game.current_floor))


# PLANTAS y ENREDADERAS: en los PASILLOS. Es el botin del transito: los pisas yendo a
# cualquier parte. El TOPE del piso manda sobre el reparto: se van llenando pasillos hasta
# agotarlo. Las dos cosas se reparten igual (y _ocupada impide que caigan en la misma celda),
# asi que comparten funcion: lo unico que cambia es la tabla, el tope y el tipo de nodo.
#
# OJO: lo que cuenta contra el tope son los SITIOS (los huecos que el piso tiene), no los
# nodos que acaban naciendo. Si contara solo los nacidos, cada planta que ya recolectaste
# liberaria su cupo y brotaria OTRA en el siguiente hueco: volver a un piso lo repoblaria de
# plantas nuevas y recolectar no serviria de nada.
func _colocar_en_pasillos(rng: RandomNumberGenerator, tabla: MaterialTable,
		tope_base: int, tipo: int) -> int:
	if tabla == null:
		return 0
	var tope: int = escalar_con_el_piso(tope_base)
	var sitios: int = 0
	var puestas: int = 0
	for i in range(gen.zonas.size()):
		if sitios >= tope:
			break
		var z: Dictionary = gen.zonas[i]
		if z["tipo"] != "pasillo":
			continue
		var celdas: Array = z["celdas"]
		var n: int = clampi(celdas.size() / maxi(1, celdas_por_planta), 0, max_plantas_pasillo)
		n = mini(n, tope - sitios)
		for _k in range(n):
			var c: Vector2i = _celda_junto_a_pared(celdas, rng)
			if c == Vector2i.MAX:
				break
			sitios += 1
			if _crear_recolectable(tipo, c):
				puestas += 1
	return puestas


# VETAS: en las salas MAS LEJANAS, y NUNCA en la de entrada ni en la de la escalera de
# bajar. Picar tiene que costarte meterte en la mazmorra; si la veta estuviera en la boca
# del piso, farmear mineral seria entrar, picar y salir, sin cruzarte con nada.
func _colocar_vetas(rng: RandomNumberGenerator) -> int:
	if tabla_vetas == null:
		return 0
	var entrada: Rect2i = gen.salas[0]
	var escalera: Rect2i = _sala_mas_lejana(entrada)
	var origen: Vector2 = Vector2(entrada.get_center())

	var candidatas: Array[Rect2i] = []
	for s in gen.salas:
		if s == entrada or s == escalera:
			continue
		candidatas.append(s)
	if candidatas.is_empty():
		return 0
	# De las que quedan, solo la MITAD MAS LEJANA lleva veta. Y se empieza por la MAS lejana:
	# si el tope del piso se agota antes de recorrerlas todas, las que se quedan sin veta son
	# las de mas cerca de la entrada, que es justo como tiene que ser.
	candidatas.sort_custom(func(a: Rect2i, b: Rect2i):
		return origen.distance_to(Vector2(a.get_center())) > origen.distance_to(Vector2(b.get_center())))
	var cuantas: int = maxi(1, candidatas.size() / 2)

	# Igual que con las plantas: lo que se cuenta contra el tope son los SITIOS, no las vetas
	# que nacen. Si no, una veta ya picada dejaria su hueco libre para otra mas alla.
	var tope: int = escalar_con_el_piso(max_vetas_piso)
	var sitios: int = 0
	var puestas: int = 0
	for i in range(cuantas):
		if sitios >= tope:
			break
		var idx: int = gen.zona_en(candidatas[i].get_center())
		if idx < 0:
			continue
		var celdas: Array = gen.zonas[idx]["celdas"]
		var n: int = mini(rng.randi_range(vetas_min_sala, vetas_max_sala), tope - sitios)
		for _k in range(n):
			var c: Vector2i = _celda_junto_a_pared(celdas, rng)
			if c == Vector2i.MAX:
				break
			sitios += 1
			if _crear_recolectable(0, c):
				puestas += 1
	return puestas


# Instancia un recolectable (tipo 0 = veta, 1 = planta, 2 = madera). Devuelve false si esa celda
# esta agotada y AUN NO le toca reaparecer (respawn por tiempo), o si la tabla no tiene nada
# para esta profundidad.
func _crear_recolectable(tipo: int, celda: Vector2i) -> bool:
	# El SITIO queda apuntado nazca o no el nodo: es lo que permite que una celda picada vuelva a
	# brotar EN VIVO mas tarde (_repoblar_agotados). Se guarda la TABLA, no el material ya elegido,
	# porque el material se vuelve a tirar en cada respawn (ver _material_del_sitio).
	_sitios[celda] = {"tipo": tipo}
	# MULTIJUGADOR: lo agotado en ESTA expedicion no vuelve a nacer al reconstruir el piso
	# (p. ej. al bajar y volver a subir): el sello de sesion vive en Net, no en mi save.
	if Net.activo and Net.celda_agotada_sesion(celda):
		return false
	# ¿Agotada? Reaparece cuando han pasado RESPAWN_SEGUNDOS de JUEGO desde que la picaste. Si ya
	# le toca, se limpia el sello y nace como nueva; si no, no nace todavia.
	if _agotados.has(celda):
		if Game.tiempo_mazmorra - float(_agotados[celda]) < Game.RESPAWN_SEGUNDOS:
			return false
		_olvidar_agotado(celda)
	var m: MaterialData = _material_del_sitio(celda)
	if m == null:
		return false
	_instanciar_nodo(tipo, celda, m, false)
	return true


# QUE material sale en esta celda, AHORA. Se tira cada vez, no se guarda.
#
# Antes el material era DETERMINISTA (salia de la semilla del piso), asi que una veta que te toco
# de cobre veteado lo seria para siempre, en todas las bajadas. Con los sub-tiers eso convierte la
# mezcla del piso en una loteria de una sola tirada: si tu piso 4 salio con mal reparto, te lo
# comes toda la partida. Ahora cada vez que un nodo nace o REAPARECE se vuelve a tirar contra la
# tabla del piso, asi que la proporcion de §rampa se cumple a la larga en cada celda.
#
# Lo que sigue saliendo de la semilla es DONDE hay sitios de recoleccion (la forma del piso), que
# es lo que de verdad tiene que ser reproducible.
func _material_del_sitio(celda: Vector2i) -> MaterialData:
	var tabla: MaterialTable = _tabla_de_tipo(int((_sitios.get(celda, {}) as Dictionary).get("tipo", -1)))
	if tabla == null:
		return null
	return tabla.elegir(Game.current_floor)   # sin rng = tirada de verdad


func _tabla_de_tipo(tipo: int) -> MaterialTable:
	match tipo:
		0: return tabla_vetas
		1: return tabla_plantas
		2: return tabla_maderas
	return null


# Planta el nodo en el mundo. Separado de _crear_recolectable porque lo llaman DOS sitios: la
# generacion del piso y el respawn en vivo. 'brotando' = aparece con un fundido (si naciera de
# golpe delante del jugador cantaria mucho); al generar el piso no hace falta.
func _instanciar_nodo(tipo: int, celda: Vector2i, m: MaterialData, brotando: bool) -> void:
	var nodo = _reco_script.new()   # sin tipar: asi GDScript deja escribirle lo suyo
	nodo.tipo = tipo
	nodo.material_data = m
	nodo.celda = celda
	nodo.brotando = brotando
	# Cuelgan del PADRE del piso (junto al jugador), no del piso: si no, heredan su z_index
	# de -1 y se dibujan por debajo del suelo.
	var mundo: Node = get_parent()
	if mundo == null:
		mundo = self
	mundo.add_child(nodo)
	nodo.global_position = gen.centro_px(celda)


# Borra el sello de una celda agotada, en la copia local Y en la persistente (que sobrevive a
# volver al pueblo). Siempre van juntas: separarlas es como se dejan sellos huerfanos.
func _olvidar_agotado(celda: Vector2i) -> void:
	_agotados.erase(celda)
	# MULTIJUGADOR: como en marcar_agotado, la persistente de MI save no se toca en sesion.
	if Net.activo:
		return
	(Game.persistente_piso(_piso_construido)["agotados"] as Dictionary).erase(celda)


# RESPAWN EN VIVO. Antes un nodo picado solo volvia al RECONSTRUIR el piso (cambiar de piso o
# salir al pueblo): plantado en el mismo sitio podias esperar media hora y no brotaba nada. Ahora
# se repasan los sellos cada RESPAWN_CHECK_CADA segundos y el que ha cumplido su tiempo brota
# donde estaba, con el material RE-TIRADO (ver _material_del_sitio): la veta que picaste no tiene
# por que volver siendo lo mismo.
func _repoblar_agotados(delta: float) -> void:
	# MULTIJUGADOR: sin respawn en vivo. Depende de tiempo_mazmorra, un reloj LOCAL que diverge
	# entre maquinas: la veta reviviria en una y en la otra no. Lo agotado en sesion no vuelve.
	if Net.activo:
		return
	_t_respawn -= delta
	if _t_respawn > 0.0:
		return
	_t_respawn = RESPAWN_CHECK_CADA
	if _agotados.is_empty() or gen == null:
		return
	# Sobre una copia de las claves: _olvidar_agotado toca el diccionario que estamos recorriendo.
	for celda in _agotados.keys():
		if Game.tiempo_mazmorra - float(_agotados[celda]) < Game.RESPAWN_SEGUNDOS:
			continue
		_olvidar_agotado(celda)
		var sitio: Dictionary = _sitios.get(celda, {})
		if sitio.is_empty():
			continue   # sello de una partida vieja, sin sitio apuntado: se limpia y ya brotara al regenerar
		var m: MaterialData = _material_del_sitio(celda)
		if m == null:
			continue   # la tabla no tiene nada para esta profundidad: la celda se queda vacia
		_instanciar_nodo(int(sitio["tipo"]), celda, m, true)


# Una celda de la zona que TOQUE pared (las vetas salen de la roca, y una planta en mitad
# del paso se ve peor que una arrimada al muro). Vector2i.MAX = no hay ninguna libre.
func _celda_junto_a_pared(celdas: Array, rng: RandomNumberGenerator) -> Vector2i:
	if celdas.is_empty():
		return Vector2i.MAX
	# Se tantea desde un punto al azar y se avanza en circulo: barato y sin repetir celda.
	var n: int = celdas.size()
	var ini: int = rng.randi_range(0, n - 1)
	for k in range(n):
		var c: Vector2i = celdas[(ini + k) % n]
		if _ocupada.has(c):
			continue
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if gen.es_solido(c + d):
				_ocupada[c] = true
				return c
	return Vector2i.MAX


# Celdas que ya tienen algo puesto (para no apilar dos vetas en el mismo sitio). NO se libera al
# picar: la celda sigue siendo "de" ese nodo, que es lo que hace que el respawn la devuelva ahi.
var _ocupada: Dictionary = {}

# SITIOS de recoleccion del piso: { celda: {"tipo": int, "material": MaterialData} }. Se llena al
# generar, con TODOS los huecos planificados (haya nodo vivo o no). Es la memoria que necesita el
# respawn en vivo para saber que brota en cada celda sin regenerar el piso. Es de RUNTIME: se
# rehace sola al construir el piso, asi que no va al save.
var _sitios: Dictionary = {}


# Que material y de que tipo brota en esa celda, o {} si ahi no hay sitio de recoleccion. Lo usa
# Game.capturar_mapa para que el plano sepa dibujar una celda AGOTADA cuando le venza el respawn:
# sin esto, el mapa se queda sin saber de que color pintarla y la celda desaparece del plano.
func sitio_de(celda: Vector2i) -> Dictionary:
	return _sitios.get(celda, {})


# Un material REPRESENTATIVO de lo que brota en esa celda, para pintar en el mapa una celda
# AGOTADA (que aun no tiene nodo vivo del que sacar el color). null si ahi no hay sitio. Se tira
# de la tabla como en un respawn: el color puede variar entre capturas, pero para una marca del
# plano da igual, y evita que capturar_mapa pete leyendo un "material" que el sitio no guarda
# (el sitio solo apunta el tipo, porque el material se re-tira en cada brote; ver _sitios).
func material_de_sitio(celda: Vector2i) -> MaterialData:
	if not _sitios.has(celda):
		return null
	return _material_del_sitio(celda)


# Lo llama Game al terminar un minijuego de recoleccion: esa celda queda explotada, con el
# SELLO del tiempo actual. A partir de ahi cuenta RESPAWN_SEGUNDOS para reaparecer. Se guarda en
# mazmorra_persistente (sobrevive a volver al pueblo) Y en la copia local del piso vivo.
func marcar_agotado(celda: Vector2i) -> void:
	_agotados[celda] = Game.tiempo_mazmorra
	# MULTIJUGADOR: NO se escribe en mazmorra_persistente (que va al SAVE). Estas jugando en el
	# mundo del HOST: agotar una veta aqui no debe dejar sellos en el mundo PROPIO de tu save.
	if Net.activo:
		return
	(Game.persistente_piso(_piso_construido)["agotados"] as Dictionary)[celda] = Game.tiempo_mazmorra


func _sala_mas_lejana(desde: Rect2i) -> Rect2i:
	var mejor := Rect2i()
	var best_d: float = -1.0
	var origen: Vector2 = Vector2(desde.get_center())
	for s in gen.salas:
		if s == desde:
			continue
		var d: float = origen.distance_to(Vector2(s.get_center()))
		if d > best_d:
			best_d = d
			mejor = s
	return mejor


# ------------------------------------------------------------
#  ZONAS: una por sala y una por pasillo. Cada una conoce SUS paredes y pare por ellas.
# ------------------------------------------------------------
func _crear_zonas() -> void:
	_zonas = Node2D.new()
	_zonas.name = "Zonas"
	add_child(_zonas)
	# DIFERIDO, por lo mismo que poblar() y los recolectables: la capa cuelga del PADRE, y el
	# padre esta aun montando sus hijos mientras corre este _ready -> Godot rechaza el add_child
	# sin rechistar y la capa se queda fuera de la escena (lineas que nunca se pintan).
	call_deferred("_crear_capa_vinculos")

	# ¿Este piso ya lo habias pisado en esta expedicion? Entonces NO se puebla: se RESTAURA
	# tal y como lo dejaste (mismos bichos, mismos sitios, mismos cadaveres).
	var recordado: bool = Game.memoria_pisos.has(_piso_construido)

	# Zona de la sala donde apareces: se crea igual (sus paredes paren), pero no se puebla. Sale de
	# _colocar_actores, que corre justo antes y es quien sabe donde has caido.
	var zona_entrada: int = _zona_aterrizaje if entrada_despejada else -1

	for i in range(gen.zonas.size()):
		var z: Dictionary = gen.zonas[i]
		var celdas: Array = z["celdas"]
		var partos: Array = gen.celdas_de_parto(i)
		if celdas.is_empty() or partos.is_empty():
			continue  # una zona sin paredes propias no puede parir nada

		# La sala del BOSS no pare NADA: el rey slime pelea solo, sin escolta que se te eche
		# encima mientras lo tienes a media vida.
		if i == _sala_boss:
			continue

		var es_sala: bool = z["tipo"] == "sala"
		var zona = _zone_script.new()
		zona.piso = self
		zona.zona_idx = i
		zona.tipo = z["tipo"]
		zona.partos = partos
		zona.intervalo_min = intervalo_min
		zona.intervalo_max = intervalo_max
		# Aforo por AREA: una sala grande sostiene mas bichos que un pasillo. Y el TECHO de ese
		# aforo crece con la profundidad (AFORO_ZONA_GROWTH, su propia rampa): abajo las salas
		# aguantan corros mas gordos, hasta el tope duro (TOPE_SALA = lo que cabe en una pelea).
		var tope: int = maxi(1, celdas.size() / celdas_por_bicho)
		var techo_base: int = max_vivos_sala if es_sala else max_vivos_pasillo
		var techo_duro: int = TOPE_SALA if es_sala else TOPE_PASILLO
		var techo: int = mini(techo_duro, _aforo_zona(techo_base))
		zona.max_vivos = mini(tope, techo)
		# Que deambulen por SU zona y no se vayan a la de al lado.
		var rect: Rect2i = z["rect"]
		var lado: float = float(mini(rect.size.x, rect.size.y)) * float(DungeonGenerator.CELDA)
		zona.wander_radius = clampf(lado * 0.5, 48.0, 160.0)
		# Por donde MERODEAN sus bichos: las celdas pisables de la zona. Antes deambulaban
		# en un circulo alrededor del sitio donde nacian y, como nacen PEGADOS A LA PARED,
		# medio circulo era roca: chocaban y se quedaban clavados contra el muro.
		var pts: Array = []
		for c in celdas:
			pts.append(gen.centro_px(c))
		zona.puntos = pts
		zona.hogar = _centro_pisable(pts)
		_zonas.add_child(zona)

	# MULTIJUGADOR (hito 5.2): el DUEÑO del piso puebla/restaura como en solitario (y replica sus
	# bichos por Net). Quien solo lo espeja no puebla NADA en local (recrearia bichos rancios de
	# expediciones viejas de ESTA maquina). En sesion, la memoria que se restaura la siembra Net
	# con la FOTO del piso (ver Net._viaje_ok), asi que 'recordado' ya sale bien.
	# hay_sitio() ya corta, pero saltarselo ahorra el trabajo entero.
	var simulo_bichos: bool = Net.simulo_mi_piso()
	if not recordado and simulo_bichos:
		_poblar_el_piso(zona_entrada)

	# DIFERIDO igual que poblar: durante _ready el nodo padre aun se esta montando y Godot
	# rechaza los add_child (los bichos no llegarian a entrar en la escena).
	if recordado and simulo_bichos:
		call_deferred("_restaurar_estado")
	call_deferred("_log_poblacion", recordado)


# POBLACION INICIAL: la fraccion del TOPE DEL PISO que ya esta deambulando cuando llegas.
#
# Antes se aplicaba zona a zona (60% del aforo de CADA zona), y la suma de los aforos se
# pasaba MUY por encima del tope global: el piso nacia lleno a reventar (28/28) y las
# paredes no tenian nada que parir. El goteo de partos, que es EL sistema, no se llegaba a
# ver nunca. Ahora el cupo se calcula sobre el tope del piso y se REPARTE entre las zonas en
# proporcion a su aforo, asi que entrar deja sitio libre a proposito.
#
# La sala de ENTRADA no entra en el reparto: nace limpia (ver entrada_despejada).
func _poblar_el_piso(zona_entrada: int) -> void:
	var cupo: int = int(round(float(max_vivos()) * poblacion_inicial))
	if cupo <= 0 or _zonas == null:
		return

	var pobladas: Array = []
	var aforo_total: int = 0
	for hijo in _zonas.get_children():
		if hijo.zona_idx == zona_entrada:
			continue
		pobladas.append(hijo)
		aforo_total += hijo.max_vivos
	if aforo_total <= 0:
		return

	# Reparto proporcional al aforo. El redondeo se hace ACUMULANDO (y no zona a zona) para
	# que los restos no se pierdan: si no, con muchas zonas pequeñas el cupo se quedaba corto.
	var ratio: float = minf(1.0, float(cupo) / float(aforo_total))
	var acumulado: float = 0.0
	var puestos: int = 0
	for zona in pobladas:
		if puestos >= cupo:
			break
		acumulado += float(zona.max_vivos) * ratio
		var n: int = mini(int(round(acumulado)) - puestos, cupo - puestos)
		n = clampi(n, 0, zona.max_vivos)
		if n <= 0:
			continue
		puestos += n
		# DIFERIDO: al construir el piso desde _ready, el nodo padre (Main) aun esta montando
		# sus hijos y Godot rechaza cualquier add_child -> los bichos no llegaban a entrar en
		# la escena. Poblar un frame despues, con el arbol ya montado, los mete sin drama.
		zona.call_deferred("poblar", n)


func _log_poblacion(recordado: bool) -> void:
	print("[mazmorra] ", "RESTAURADO (ya lo habias pisado): " if recordado else "poblacion inicial: ",
		_vivos_en_el_piso(), " bichos vivos (tope ", max_vivos(), ")",
		", ", get_tree().get_nodes_in_group("corpse").size(), " cadaveres")


# El "hogar" de una zona: el punto PISABLE mas cercano a su centro. Se usa el mas cercano
# y no el centro a secas porque un pasillo en L tiene el centro geometrico dentro de la
# roca, y ahi mandariamos a los bichos a empotrarse.
func _centro_pisable(pts: Array) -> Vector2:
	if pts.is_empty():
		return Vector2.ZERO
	var media := Vector2.ZERO
	for p in pts:
		media += p
	media /= float(pts.size())

	var mejor: Vector2 = pts[0]
	var best: float = INF
	for p in pts:
		var d: float = p.distance_squared_to(media)
		if d < best:
			best = d
			mejor = p
	return mejor


# ------------------------------------------------------------
#  MEMORIA DEL PISO: lo dejas como lo dejas, y al volver sigue igual.
#  Solo se guardan las COSAS (bichos, cadaveres, loot del suelo). La FORMA del piso no hace
#  falta: se rehace identica desde la semilla, asi que esto no crece con el tamaño del mapa.
# ------------------------------------------------------------
# Vuelca el piso ACTUAL a la memoria sin abandonarlo. Lo llama el guardado de partida: un
# piso solo se volcaba al salir de el, asi que guardar estando dentro dejaba el piso que
# estas pisando VACIO en el fichero.
func volcar_a_memoria() -> void:
	_guardar_estado()


# MULTIJUGADOR (hito 5.2): heredo la simulacion de ESTE piso, estando ya de pie en el (el dueño se
# fue por una escalera). Los cuerpos espejados ya los ha quitado Net; aqui nacen los bichos DE
# VERDAD en las mismas posiciones y con las mismas stats, reusando la restauracion de siempre.
func adoptar_foto(mem: Dictionary) -> void:
	if _piso_construido <= 0:
		return
	Game.memoria_pisos[_piso_construido] = mem
	_restaurar_estado()


func _guardar_estado() -> void:
	if _piso_construido <= 0 or gen == null:
		return

	var enemigos: Array = []
	# Vivos y CADAVERES. Los cadaveres tambien: llevan tu cristal dentro y perderlos por subir
	# un piso es justo lo que escuece. (Los ya extraidos no estan: se desvanecen al extraerlos.)
	for grupo in ["enemy", "corpse"]:
		for e in get_tree().get_nodes_in_group(grupo):
			if not is_instance_valid(e) or e.data == null:
				continue
			# MULTIJUGADOR: los cuerpos ESPEJADOS (remote_enemy) tambien estan en estos grupos para
			# poder pelearlos y extraerlos, pero NO son mios: meterlos en la foto del piso seria
			# duplicar los bichos de quien lo simula. La foto la saca solo el dueño, con los suyos.
			if e.has_meta("es_espejo"):
				continue
			enemigos.append({
				"data": e.data,
				"pos": e.global_position,
				# La 't' es lo que fija sus stats dentro de la franja del piso: sin guardarla,
				# el mismo slime reaparece con otras stats (mas flojo o mas bestia).
				"t": e.current_t,
				"zona": e.zona_idx,
				"muerto": grupo == "corpse",
			})

	var suelo: Array = []
	for p in get_tree().get_nodes_in_group("pickup"):
		if is_instance_valid(p) and p.item != null:
			suelo.append({"item": p.item, "pos": p.global_position})

	# Los recolectables agotados YA NO van aqui: viven en Game.mazmorra_persistente (con su sello
	# de tiempo para el respawn), que marcar_agotado escribe en el momento de picar y que
	# sobrevive a la expedicion. memoria_pisos solo guarda lo de scope de expedicion: bichos y
	# cosas del suelo. Ninguno de los dos guarda la FORMA del piso: sale de la semilla.
	Game.memoria_pisos[_piso_construido] = {"enemigos": enemigos, "suelo": suelo}
	print("[mazmorra] guardado el piso ", _piso_construido, ": ", enemigos.size(),
		" bichos (vivos+cadaveres), ", suelo.size(), " cosas por el suelo")


func _restaurar_estado() -> void:
	var mem: Dictionary = Game.memoria_pisos.get(_piso_construido, {})
	if mem.is_empty():
		return

	var data_boss: EnemyData = Game.boss_del_piso(_piso_construido)
	for d in (mem.get("enemigos", []) as Array):
		var zona = _zona(int(d["zona"]))
		var radio: float = zona.wander_radius if zona != null else 90.0
		var e = crear_enemigo(d["data"], d["pos"], radio, float(d["t"]))
		if e == null:
			continue
		e.zona_idx = int(d["zona"])
		# Que el boss siga siendo el boss al volver al piso: si no, se lo llevaria el reciclador
		# y su muerte no abriria nada.
		e.es_boss = data_boss != null and d["data"] == data_boss
		if bool(d["muerto"]):
			e.morir()   # vuelve a ser un cadaver: gris, sin IA y con su cristal dentro
		elif zona != null:
			zona.adoptar(e)   # la zona lo cuenta como suyo, o parira por encima de su aforo

	for d in (mem.get("suelo", []) as Array):
		var pickup: Node2D = _pickup_script.new()
		pickup.setup(d["item"])
		var mundo: Node = get_parent()
		if mundo == null:
			mundo = self
		mundo.add_child(pickup)
		pickup.global_position = d["pos"]


func _zona(idx: int):
	if _zonas == null or idx < 0:
		return null
	for hijo in _zonas.get_children():
		var z = hijo
		if z.zona_idx == idx:
			return z
	return null


# ------------------------------------------------------------
#  SPAWNER DEL PISO (lo llaman las zonas)
# ------------------------------------------------------------

# Que bicho toca parir, segun la tabla del piso y la profundidad.
func elegir_enemigo() -> EnemyData:
	if spawn_table == null:
		return null
	return spawn_table.elegir(Game.current_floor)


# ¿Cabe un bicho mas en el piso? Si estamos al tope, se intenta hacer sitio reciclando al
# vivo mas LEJANO. Sin esto, "toda la mazmorra pare siempre" acaba con el piso lleno de
# bichos dormidos en la otra punta y la sala donde estas TU esteril.
# Al POBLAR el piso al entrar se llama con reciclar=false: si no, las ultimas zonas en
# poblarse se pondrian a borrar los bichos de las primeras para hacerse sitio.
func hay_sitio(reciclar: bool = true, forzar: bool = false) -> bool:
	# MULTIJUGADOR (hito 5.2): este es el embudo por el que pasan la poblacion inicial, el goteo y
	# los brotes (SpawnZone._nacer pregunta aqui antes de crear nada). Solo crea bichos el DUEÑO
	# del piso; el que solo lo espeja no crea ninguno en local (los ve por Net).
	if not Net.simulo_mi_piso():
		return false
	if _vivos_en_el_piso() < max_vivos():
		return true
	return reciclar and _reciclar_lejano(forzar)


func _vivos_en_el_piso() -> int:
	return get_tree().get_nodes_in_group("enemy").size()


# Cuantos bichos VIVOS estan asignados AHORA a una zona (por su zona_idx), contando tanto los
# que pario ella como los que se le han MUDADO (manadas). Es la ocupacion REAL de la sala: la
# lista _vivos de la SpawnZone solo ve lo que ella misma pario, no los migrantes, asi que una
# sala podia rebosar de bichos mudados sin que su aforo se enterara. Esta es la cuenta buena.
func enemigos_en_zona(idx: int) -> int:
	var n: int = 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and int(e.zona_idx) == idx:
			n += 1
	return n


# El aforo (max_vivos) de la SpawnZone de esa zona, o 0 si no hay zona con ese idx (pasillo sin
# paredes, sala del boss...). Lo usa la manada para no mudarse a una sala ya llena.
func aforo_de_zona(idx: int) -> int:
	if _zonas == null:
		return 0
	for hijo in _zonas.get_children():
		if hijo.zona_idx == idx:
			return int(hijo.max_vivos)
	return 0


# Despawnea al enemigo vivo mas lejano al jugador. Normal: SOLO si esta lejisimos (mas de
# dist_reciclar), para no borrar algo que puedas estar viendo. FORZAR (brote masivo): borra al mas
# lejano SEA CUAL SEA su distancia, para hacer aforo si o si -> un brote entra siempre completo, y
# lo que se cae es lo que tienes mas lejos (lo menos molesto). Los CADAVERES no se tocan jamas:
# llevan tu loot dentro y morir() ya los saca del grupo "enemy", asi que ni aparecen por aqui.
func _reciclar_lejano(forzar: bool = false) -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if not (player is Node2D):
		return false
	var pj: Vector2 = (player as Node2D).global_position

	var lejano: Node = null
	# Forzando, el liston de distancia se cae: vale cualquiera (arranca en -1 para aceptar hasta el
	# de distancia 0). Sin forzar, solo los que esten mas lejos que dist_reciclar.
	var best: float = -1.0 if forzar else dist_reciclar
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not (e is Node2D):
			continue
		# Ya marcado para borrar en este mismo frame (varios _nacer seguidos de un brote): no lo
		# vuelvas a elegir o "reciclarias" al mismo una y otra vez sin liberar huecos nuevos.
		if e.is_queued_for_deletion():
			continue
		# El BOSS no se recicla NUNCA: guarda su sala hasta que lo maten. Sin esto, alejarse lo
		# suficiente lo borraria y el piso se quedaria cerrado para siempre.
		if e.get("es_boss"):
			continue
		var d: float = pj.distance_to((e as Node2D).global_position)
		if d > best:
			best = d
			lejano = e
	if lejano == null:
		return false
	lejano.queue_free()
	return true


# Capa que pinta las LINEAS entre enemigos cercanos (los que entrarian juntos al combate).
# Cuelga del PADRE del piso, igual que los propios bichos (ver crear_enemigo): el piso tiene
# z_index -1 y una capa colgada de el quedaria pintada por debajo del suelo.
func _crear_capa_vinculos() -> void:
	var mundo: Node = get_parent()
	if mundo == null:
		mundo = self
	if mundo.has_node("Vinculos"):
		return   # ya la puso un piso anterior de esta expedicion
	var capa := Node2D.new()
	capa.name = "Vinculos"
	capa.set_script(preload("res://scripts/world/enemy_links.gd"))
	mundo.add_child(capa)


# Instancia un enemigo. Mismo patron que el spawner de dev (scripts/ui/spawner.gd): el
# 'data' se asigna ANTES de add_child (su _ready lo usa) y se le recoloca DESPUES para
# re-fijar su "hogar" (si no, deambula hacia el (0,0) y cruza las paredes).
func crear_enemigo(data: EnemyData, pos: Vector2, radio: float, t: float = -1.0):
	if data == null:
		return null
	var e = _enemy_scene.instantiate()
	e.data = data
	e.wander_radius = radio
	# 't' impuesta (restaurando el piso): el bicho vuelve con las MISMAS stats que tenia.
	# Va antes de add_child porque su _ready es quien la lee.
	e.t_forzada = t
	# Cuelgan del PADRE del piso (junto al jugador) y no del piso: asi no heredan su
	# z_index de -1 y no se dibujan por debajo del suelo.
	var mundo: Node = get_parent()
	if mundo == null:
		mundo = self
	mundo.add_child(e)
	e.recolocar(pos)
	# MULTIJUGADOR (hito 5.1): el host lo registra para replicarlo a los clientes de este piso
	# (ya con su posicion puesta). En solitario / de cliente no hace nada.
	Net.registrar_enemigo(e, "piso:%d" % _piso_construido)
	return e


# Barrido: a los bichos que estan lejisimos se les apaga la IA (no los ves, no hace falta
# simularlos) y se les vuelve a encender al acercarte. Los cadaveres ya vienen con la IA
# apagada de fabrica (morir()), asi que ni los tocamos.
func _process(delta: float) -> void:
	# El reloj de expedicion (Game.tiempo_mazmorra) lo lleva Game._process: tiene que contar
	# tambien el tiempo de combate, y este _process se congela con el arbol.
	_repoblar_agotados(delta)

	_t_barrido -= delta
	if _t_barrido > 0.0:
		return
	_t_barrido = BARRIDO_CADA

	var player := get_tree().get_first_node_in_group("player")
	if not (player is Node2D):
		return
	var pj: Vector2 = (player as Node2D).global_position

	# NIEBLA del mapa: la zona que pisas queda vista para siempre (persiste en el save).
	if gen != null:
		var celda: Vector2i = Vector2i((pj / DungeonGenerator.CELDA).floor())
		var z: int = gen.zona_en(celda)
		if z >= 0:
			(Game.persistente_piso(_piso_construido)["zonas_vistas"] as Dictionary)[z] = true

	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not (e is Node2D):
			continue
		# Los ESPEJOS no se tocan: no tienen IA que apagar (su _physics_process es la interpolacion
		# que los hace moverse suaves), y apagarsela los dejaria dando tirones.
		if e.has_meta("es_espejo"):
			continue
		# A los que estan EN una pelea no se les toca la fisica: encendersela aqui les devolveria
		# la IA en mitad del combate. Hoy lo tapa el early-return de enemy._physics_process, pero
		# eso es una dependencia fragil y sin la pausa global (multi) este barrido corre siempre.
		if e.get("_combat_triggered"):
			continue
		var lejos: bool = pj.distance_to((e as Node2D).global_position) > dist_congelar
		e.set_physics_process(not lejos)


# ------------------------------------------------------------
#  DEV: comprobar las proporciones de la tabla sin jugar una hora.
# ------------------------------------------------------------
func test_proporciones(tiradas: int = 200) -> void:
	if spawn_table == null:
		return
	var cuenta: Dictionary = {}
	for _i in range(tiradas):
		var d: EnemyData = spawn_table.elegir(Game.current_floor)
		var nombre: String = d.enemy_name if d != null else "(nada)"
		cuenta[nombre] = int(cuenta.get(nombre, 0)) + 1
	print("[dev] ", tiradas, " tiradas de la tabla en el piso ", Game.current_floor, ":")
	for nombre in cuenta:
		var n: int = cuenta[nombre]
		print("   ", nombre, ": ", n, "  (", snappedf(100.0 * float(n) / float(tiradas), 0.1), "%)")
	print("[dev] esperado -> ", spawn_table.resumen(Game.current_floor))


# A que distancia del jugador puede reventar la pared de un brote. Ni encima (no naces dentro de
# el) ni tan lejos que no lo veas: un brote que no ves no es un susto, es poblacion de mas.
const BROTE_VISTA_MIN := 120.0
const BROTE_VISTA_MAX := 460.0


# Provoca un BROTE en la mejor pared a la vista del jugador. Lo usa la tecla de dev (B) y, cuando
# se llene, el medidor de alboroto.
#
# No basta con la celda mas cercana: puede ser un saliente suelto de roca que solo pare uno, y el
# brote se queda en nada. Se busca la mas cercana (dentro del rango de vista) que ademas de para un
# TRAMO GORDO -al menos el tamaño del brote-; si ninguna llega, la que mas de. Asi la pared que
# revienta siempre suelta el grupo entero, no un bicho triste.
func provocar_brote() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if not (player is Node2D) or _zonas == null:
		return false
	var pj: Vector2 = (player as Node2D).global_position

	var mejor_zona = null
	var mejor_celda: Dictionary = {}
	var mejor_score: float = -1.0
	for hijo in _zonas.get_children():
		var zona = hijo   # sin tipar: asi GDScript deja llamar a lo suyo (partos, brotar_en...)
		var objetivo: int = zona.brote_tamano()
		for p in zona.partos:
			var d: float = pj.distance_to(gen.centro_px(p["suelo"]))
			if d < BROTE_VISTA_MIN or d > BROTE_VISTA_MAX:
				continue
			# Score: prima el tramo (que quepa el brote entero) y, a igualdad, la cercania. El
			# tramo se capa al objetivo -mas celdas no dan mas bichos- y la distancia va como un
			# desempate pequeño (negativo: mas cerca, mejor).
			var tramo: int = mini(objetivo, zona._tramo_de_pared(p, objetivo).size())
			var score: float = float(tramo) * 1000.0 - d
			if score > mejor_score:
				mejor_score = score
				mejor_zona = zona
				mejor_celda = p
	if mejor_zona == null:
		print("[brote] no hay pared a la vista para reventar (acercate a un muro)")
		return false
	print("[brote] revienta la pared de la zona ", mejor_zona.zona_idx,
		" a ", roundi(pj.distance_to(gen.centro_px(mejor_celda["suelo"]))), " px")
	return mejor_zona.brotar_en(mejor_celda)


# Alias de la tecla de dev (B): mismo brote, nombre viejo por si algo lo llama.
func dev_brote_cercano() -> void:
	provocar_brote()
