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
# Los PECES del charco (ver _elegir_estanque). Misma clase de tabla que las otras tres, pero no se
# reparte por celdas: el estanque entero hace su tirada por cada pez que nada dentro.
@export var tabla_peces: MaterialTable = preload("res://resources/world/peces.tres")
# La DESPENSA de la mazmorra: la SAL se pica en las salas (es roca, va con las vetas) y los
# SILVESTRES se cortan en los pasillos (van con las plantas). Tienen tabla y cupo PROPIOS a
# proposito: si compartieran los de la forja, cada cebolla seria un mineral que no sale.
@export var tabla_sal: MaterialTable = preload("res://resources/world/sal.tres")
@export var tabla_silvestres: MaterialTable = preload("res://resources/world/silvestres.tres")
# El CARBON: tabla y cupo propios por lo mismo que la despensa. Es roca (se pica con el pico y va
# con el minijuego de mineria), pero si saliera de la tabla de vetas cada carbon seria un mineral
# de forjar que no sale -- y desde que la mazmorra esta a oscuras el carbon no es un extra: es con
# lo que se ve.
@export var tabla_carbon: MaterialTable = preload("res://resources/world/carbon.tres")
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
# La DESPENSA va con CUPO FIJO (se tira entre el minimo y el maximo) y NO pasa por
# escalar_con_el_piso: un cupo de 1-2 escalado con el area se pone en seis en un piso grande, y lo
# que se quiere es justo lo contrario —que la comida sea contada y haya que bajar a por ella—.
# Con el respawn lento (10 min), un piso da como mucho estas piezas por vuelta.
@export var sal_min_piso: int = 1
@export var sal_max_piso: int = 2
@export var silvestres_min_piso: int = 2
@export var silvestres_max_piso: int = 3
# El carbon va igual: contado. Dos por piso como mucho, con el respawn lento de la despensa. Es
# lo que obliga a bajar con el deposito hecho en vez de vivir del carbon que encuentres.
@export var carbon_min_piso: int = 1
@export var carbon_max_piso: int = 2

# Cada cuanto se mira si a algun nodo picado le toca ya reaparecer. No hace falta afinar mas:
# el respawn son minutos, y barrer el diccionario de agotados cada frame seria tirar CPU.
const RESPAWN_CHECK_CADA := 2.0
var _t_respawn: float = RESPAWN_CHECK_CADA
var _t_boss: float = RESPAWN_CHECK_CADA   # el mismo latido, para el respawn del jefe
# EL JEFE ESTA NACIENDO: su aviso tiembla en el suelo y todavia no hay bicho. Hace falta porque
# _repoblar_boss late cada 2 s y el aviso dura 2.6: sin esto arrancaria un segundo temblor -y un
# segundo jefe- en mitad del primero, ya que la comprobacion de "¿hay uno de pie?" mira el grupo
# "enemy" y ahi aun no hay nadie.
var _boss_naciendo: bool = false

# --- RITMO de los partos (segundos). Franja ANCHA y LENTA a proposito: ver spawn_zone.gd ---
# DOBLADOS (eran 25-70): con el aforo de la sala, los pasillos que desembocan en ella y los partos
# encima, la mazmorra abrumaba -- entre pelear, extraer el cristal y moverte no habia hueco para
# respirar. Es el ritmo del PISO 1: baja con la profundidad (ver _factor_spawn_piso).
@export var intervalo_min: float = 50.0
@export var intervalo_max: float = 140.0

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


# ------------------------------------------------------------
#  ANCHO DE LOS PASILLOS POR PROFUNDIDAD
#  Cada PASILLO_CADA_PISOS pisos, los pasillos ganan una celda de ancho: 3 en los pisos 1-6, 4 del 7
#  al 12, 5 del 13 al 18, y asi. La razon no es estetica sino de SITIO: cuanto mas hondo, mas
#  grandes son los bichos (y mas caben por zona, ver AFORO_ZONA_GROWTH), y un pasillo de 3 celdas
#  con un coloso dentro no deja ni pasar ni rodearlo. Los enemigos grandes ya tienen su colision a
#  medida (ver Enemy._aplicar_colision), asi que el que se queda corto es el hueco.
#
#  Crece a ESCALONES y no de forma continua a proposito: un pasillo mide celdas enteras, y asi el
#  cambio se nota como "aqui abajo los tuneles son otra cosa" en vez de diluirse piso a piso.
#
#  Y los escalones SE VAN ESPACIANDO, como los pasos del area (ver _paso_area): el primero cuesta 6
#  pisos y cada uno siguiente un 60% mas que el anterior. Si fuera cada 6 pisos fijos, el ancho
#  crecería sin freno y en la profundidad los pasillos acabarian midiendo mas que las salas -- que
#  es justo el mapa que no queremos, uno donde no se distingue un tunel de una habitacion. Asi el
#  ensanche se nota pronto (donde hace falta) y se va calmando solo:
#
#      pasillo 3 -> pisos 1-6      pasillo 5 -> pisos 16-30
#      pasillo 4 -> pisos 7-15     pasillo 6 -> pisos 31-55     pasillo 7 -> del 56 en adelante
const PASILLO_PRIMER_ESCALON := 6.0    # pisos hasta el primer ensanche
const PASILLO_ESCALON_CRECE := 1.6     # cada ensanche cuesta un 60% mas de pisos que el anterior
const PASILLO_ANCHO_MAX := 7
# Cuanto mas ancha que un pasillo tiene que ser, como minimo, una sala. Si no, en cuanto el pasillo
# alcanza el lado corto de la sala mas pequeña el mapa deja de leerse como "salas unidas por
# pasillos" y se convierte en una cueva sin forma: las salas dejan de distinguirse de los tuneles.
const SALA_MARGEN_SOBRE_PASILLO := 2

# El ancho de pasillo de ESTE piso. El @export `ancho_pasillo` es el del piso 1.
func _ancho_pasillo_piso() -> int:
	var piso: int = maxi(1, _piso_construido)
	var w: int = ancho_pasillo
	var coste: float = PASILLO_PRIMER_ESCALON   # lo que cuesta el PROXIMO ensanche
	var acumulado: float = coste                # primer piso en el que ya toca
	while w < PASILLO_ANCHO_MAX and float(piso) > acumulado:
		w += 1
		coste *= PASILLO_ESCALON_CRECE
		acumulado += coste
	return w


# El tamaño minimo de sala de este piso: el del @export, pero nunca tan estrecho como para que una
# sala no se distinga de un pasillo (ver SALA_MARGEN_SOBRE_PASILLO). Solo muerde en los pisos hondos.
func _sala_min_piso(ancho_pas: int) -> Vector2i:
	var suelo: int = ancho_pas + SALA_MARGEN_SOBRE_PASILLO
	return Vector2i(maxi(sala_min.x, suelo), maxi(sala_min.y, suelo))

# Vivos que aguanta ESTE piso (el @export es el del piso 1).
func max_vivos() -> int:
	return escalar_con_el_piso(max_vivos_piso)


# ------------------------------------------------------------
#  RITMO DE LOS PARTOS POR PROFUNDIDAD
#  Cuanto mas hondo, mas seguido pare la pared: es la tercera pata de "abajo aprieta mas", junto al
#  numero de bichos (que sigue al area) y al tamaño del corro (AFORO_ZONA_GROWTH).
#
#  Va con paso DECRECIENTE, la misma construccion que AREA_STEP_* y por el mismo motivo: un 3%
#  compuesto a pelo son x2.36 al piso 30 y x10 al piso 80, o sea paredes escupiendo bichos cada seis
#  segundos. Con el paso decayendo hacia un suelo, el ritmo siempre gana algo al bajar pero no se
#  desmadra nunca: x1.14 al piso 6, x1.27 al 13, x1.45 al 30. Al piso 30 sigue pariendo MAS DESPACIO
#  que lo que paria el piso 1 antes de doblar los intervalos.
#  PROVISIONAL -> Excel, como el resto de las curvas.
# ------------------------------------------------------------
const SPAWN_STEP_MAX := 0.03    # el primer piso que bajas pare un 3% mas seguido
const SPAWN_STEP_MIN := 0.005   # suelo: nunca deja de acelerar, pero cada vez menos
const SPAWN_STEP_DECAY := 0.90  # cuanto se acerca el paso al suelo cada piso (mas alto = decae mas lento)

func _paso_spawn(n: int) -> float:
	return SPAWN_STEP_MIN + (SPAWN_STEP_MAX - SPAWN_STEP_MIN) * pow(SPAWN_STEP_DECAY, float(n - 1))

# Cuantas veces MAS RAPIDO pare este piso que el piso 1. Los intervalos se DIVIDEN por esto.
func _factor_spawn_piso() -> float:
	var factor: float = 1.0
	for i in range(1, maxi(1, _piso_construido)):   # un paso por cada piso bajado desde el 1
		factor *= 1.0 + _paso_spawn(i)
	return factor


var gen: DungeonGenerator = null

var _enemy_scene: PackedScene = preload("res://scenes/actors/enemy/enemy.tscn")
var _zone_script: GDScript = preload("res://scripts/world/spawn_zone.gd")
var _stairs_script: GDScript = preload("res://scripts/world/stairs.gd")
var _exit_script: GDScript = preload("res://scripts/world/dungeon_exit.gd")
# El aviso de la pared. Aqui hace falta para pintar los brotes REPLICADOS (ver pintar_aviso_pared);
# los propios los monta SpawnZone con su propia copia del script.
var _fx_pared_script: GDScript = preload("res://scripts/world/wall_birth_fx.gd")
var _pickup_script: GDScript = preload("res://scripts/items/drop_pickup.gd")
var _reco_script: GDScript = preload("res://scripts/world/resource_node.gd")
var _fishing_script: GDScript = preload("res://scripts/world/fishing_spot.gd")

# --- BOSS del piso (si lo hay) ---
# Donde van la bajada y la salida al pueblo, y si ya estan puestas. En un piso con boss SIN
# matar no se colocan: el piso es un callejon hasta que cae.
var _salida_pos: Vector2 = Vector2.INF
var _salidas_puestas: bool = false
# Zona (sala) que ocupa el boss: no pare bichos. Nadie le hace de escolta.
var _sala_boss: int = -1
# Donde se planta el jefe de este piso (INF = este piso no tiene). Se guarda porque tambien se usa
# EN CALIENTE: si su reloj cumple mientras estas dentro, renace ahi mismo (ver _repoblar_boss).
var _boss_pos: Vector2 = Vector2.INF
# Cuanto se aleja el jefe de su sitio al MERODEAR. Se guarda junto a la posicion porque los dos
# caminos que lo paren lo necesitan: el parto inicial y el respawn por reloj (_repoblar_boss), que
# ya no tiene la sala a mano. 0 = jefe clavado, que es justo lo que habia y lo que se arregla.
var _boss_radio: float = 0.0
# Zona en la que ATERRIZA el jugador al construirse el piso. La fija _colocar_actores (que es
# quien decide donde apareces) y la lee _crear_zonas para no poblarla. NO se puede dar por hecho
# que sea la boca: por el atajo, o subiendo, apareces en el FONDO.
var _zona_aterrizaje: int = -1
# SALAS SEGURAS: las de las PUERTAS del piso (la boca -puerta al pueblo o escalera de subir- y el
# fondo -bajada y, en los pisos de jefe, la salida al pueblo-). No se les crea zona de spawn, asi
# que ni entran en la poblacion inicial, ni sus paredes paren, ni las eligen los brotes, ni nadie
# migra a ellas (todo eso pasa por _zonas; ver _crear_zonas). Es el mismo mecanismo que la sala
# del boss.
#
# Lo que NO son es invulnerabilidad: el bicho que ya te esta PERSIGUIENDO entra detras de ti. Huir
# a la escalera sigue siendo huir. Es la diferencia con _zona_aterrizaje, que solo se salta la
# poblacion inicial (esa sala sigue pariendo mientras la cruzas).
var _zonas_seguras: Array[int] = []

# ZONA DEL ESTANQUE: la sala que lleva el charco de pescar. -1 = este piso no tiene (solo pasa si
# el trazado se queda sin salas candidatas).
#
# ES ZONA SEGURA, como las de las puertas: no se le crea zona, asi que no pare, no brota y no
# recibe migraciones. Antes solo pariía mas despacio (x2.5), y en la practica no bastaba: sacar un
# pez lleva su rato, y con dos personas pescando la sala acababa llena igual. Pescar sigue teniendo
# riesgo -el bicho que YA te persigue entra detras de ti- pero deja de ser una tirada de dados.
# Ver _zonas_seguras y celda_en_estanque().
var _zona_estanque: int = -1
var _celda_estanque: Vector2i = Vector2i.MAX
# Tamaño del charco EN CELDAS. Fijo a proposito (no escala con el piso): el minijuego se juega
# contra el charco, y un charco de tamaño variable cambiaria el tiempo que tardan los peces en
# cruzarlo de un piso a otro sin que nadie lo haya decidido.
const ESTANQUE_CELDAS := Vector2i(5, 4)

var _geo: Node2D = null      # toda la geometria del piso (se tira entera al regenerar)
var _zonas: Node2D = null    # todas las SpawnZone
var _t_barrido: float = 0.0  # acumulador del barrido de congelado

# CELDAS ya recolectadas de este piso (celda -> true). Lo unico que hace falta recordar de
# la recoleccion: DONDE estaba cada veta y de que era ya lo decide la semilla, asi que basta
# con saber cuales YA NO estan. Se vuelca a Game.memoria_pisos y vuelve de ahi.
var _agotados: Dictionary = {}

# NONCE del brote VIVO de cada sitio (celda -> int). 0 (o ausente) = lo que puso la epoca al
# construir el piso; cualquier otro = lo que salio en su ultimo respawn.
#
# Hermano de _agotados y con sus mismas reglas de escritura: copia local + mazmorra_persistente en
# solitario, y en multi NO se toca mi save (el mundo es del host, sus nonces viven en Net).
# Es lo que hace que el sub-tier con el que rebrota una veta SOBREVIVA a reconstruir el piso.
var _nonces: Dictionary = {}

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
	_boss_pos = Vector2.INF
	# Un aviso a medias del piso anterior no puede dejar el candado puesto: su await comprueba el
	# piso y se va sin plantar nada, pero sin esto _repoblar_boss se quedaria mudo aqui para siempre.
	_boss_naciendo = false
	# EL REGISTRO DE OBRAS ES DE ESTE PISO. Sin vaciarlo, el piso nuevo hereda las celdas que estaban
	# rotas en el anterior -- mismas coordenadas, otro mapa -- y esas paredes no vuelven a parir nunca
	# ni pueden temblar. Los avisos viejos ya se han ido con la geometria.
	_celdas_rotas.clear()
	# El cartel cuelga del PADRE del piso (ver _refrescar_cartel_boss), asi que no se lo lleva el
	# desmontaje: hay que tirarlo a mano o el del piso 6 seguiria plantado en el 7.
	if _boss_cartel != null and is_instance_valid(_boss_cartel):
		_boss_cartel.queue_free()
	_boss_cartel = null
	_zona_aterrizaje = -1
	_zonas_seguras.clear()
	_zona_estanque = -1
	_celda_estanque = Vector2i.MAX
	gen = DungeonGenerator.new()
	# El tamaño del @export es el del piso 1; abajo el mapa crece (ver AREA_GROWTH).
	var fl: float = _factor_lineal_piso()
	var w: int = roundi(float(ancho_celdas) * fl)
	var h: int = roundi(float(alto_celdas) * fl)
	var salas: int = roundi(float(max_salas) * _factor_area_piso())
	if _piso_construido > 1:
		print("[mazmorra] piso %d: %dx%d celdas · %d salas (x%.2f area) · pasillos de %d" % [
			_piso_construido, w, h, salas, _factor_area_piso(), _ancho_pasillo_piso()])
	# Los pasillos se ensanchan con la profundidad (ver _ancho_pasillo_piso) y la sala minima sube
	# con ellos para que una sala nunca se confunda con un tunel.
	var ancho_pas: int = _ancho_pasillo_piso()
	gen.generar(w, h, _semilla_del_piso(),
		salas, _sala_min_piso(ancho_pas), sala_max, ancho_pas)
	# Las columnas de piedra van AQUI, pegadas al generador y antes que todo lo demas: convierten
	# celdas en roca, y la geometria, la colision, la vision y las zonas de spawn se construyen
	# despues leyendo esa rejilla. Puestas mas tarde, cada uno de esos sistemas tendria que
	# enterarse por su cuenta.
	_sembrar_formaciones()

	# Lo que ya picaste en este piso, con el SELLO de tiempo de cuando lo picaste (para el
	# respawn). Vive en mazmorra_persistente, que sobrevive a volver al pueblo: por eso picar un
	# nodo y salir/entrar ya no lo resetea. { celda: reloj de pared en que se pico }.
	_agotados = (Game.persistente_piso(_piso_construido)["agotados"] as Dictionary).duplicate()
	# Y con que nonce nacio lo que hay en cada sitio, que va en el mismo sitio y por lo mismo: sin
	# esto, la veta que rebroto de estaño profundo volvia a ser cobre en cuanto rehacias la escena.
	_nonces = (Game.persistente_piso(_piso_construido)["nonces"] as Dictionary).duplicate()
	# MULTIJUGADOR: los sellos de MI save no pintan nada en el mundo del host. Se arranca en
	# limpio; lo agotado en ESTA expedicion lo trae Net (celda_agotada_sesion) al construir, y los
	# nonces igual (nonce_celda_sesion).
	if Net.activo:
		_agotados = {}
		_nonces = {}

	_construir_geometria()
	_colocar_actores(por_la_bajada)
	# ANTES de _crear_zonas y DESPUES de _colocar_actores, y no es casualidad: necesita saber ya cual
	# es la sala del jefe (la decide _colocar_boss, dentro de _colocar_actores) para no ponerle un
	# charco al minotauro, y _crear_zonas necesita saber ya cual es la del estanque para frenarle el
	# ritmo de partos.
	_elegir_estanque()
	# DESPUES del estanque a proposito: el riachuelo tiene que saber donde esta el lago para poder
	# desembocar en el (ver Decorado._trazar_agua).
	_decorar()
	_apagar_la_luz()
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
#
#  LO QUE SE VE va en TileMapLayer (uno por capa de TerrenoSprites); LO QUE CHOCA sigue siendo el
#  mismo StaticBody2D de siempre, con una forma por TRAMO FUSIONADO. Son dos cosas distintas y se
#  separan a proposito:
#    - la colision quiere POCAS formas gordas (por eso los tramos fusionados de gen.muros_fusionados)
#    - el dibujo quiere variedad POR CELDA (si no, una pared larga es la misma baldosa clonada y se
#      ve la cuadricula)
#  Fusionar el dibujo era justo lo que impedia darle variedad, y un TileMapLayer ya batchea el
#  dibujado por dentro, asi que no se pierde nada por pintar celda a celda.
#
#  Antes esto eran ColorRect de un color plano. La colision NO ha cambiado ni una linea.
# ------------------------------------------------------------

# Los TileMapLayer por capa (ver TerrenoSprites.CAPAS_ORDEN). Cuelgan de _geo, asi que se los
# lleva por delante el queue_free de _limpiar como todo lo demas.
var _tm: Dictionary = {}

# Lo que hay pintado de cada capa de adorno: { celda: true }. Hace falta guardarlo porque la
# MASCARA de una celda se calcula mirando a sus vecinas de la MISMA capa.
var _celdas_musgo: Dictionary = {}
# Los musgos que han florecido: los unicos que dan luz (ver Decorado._sembrar_flores).
var _celdas_flor: Dictionary = {}
# Las columnas de piedra de este piso (ver _sembrar_formaciones). Ya son roca en el generador; esta
# lista existe para poder pintarlas distinto de una pared y para las pruebas.
var _celdas_formacion: Array[Vector2i] = []
# Las mismas, como diccionario, para preguntarlo rapido dentro del bucle que pinta el piso entero.
var _es_formacion: Dictionary = {}
# Quien decide, celda a celda, que estilo le toca en un piso donde cambia el tramo (transicion.gd).
var _trans := Transicion.new()
# Si en este piso hay roca de estilo CUEVA (su borde ondula y no llena la celda).
var _estilo_cueva: bool = false
var _celdas_agua: Dictionary = {}
var _celdas_sumidero: Dictionary = {}


func _construir_geometria() -> void:
	var celda: float = float(DungeonGenerator.CELDA)

	_geo = Node2D.new()
	_geo.name = "Geo"
	add_child(_geo)

	# Fondo: la roca maciza (lo que hay detras de las paredes). Sigue siendo un ColorRect: no se
	# ve NUNCA (solo se dibujan los muros que tocan suelo) y ademas con la oscuridad menos.
	var fondo := ColorRect.new()
	fondo.color = color_roca
	fondo.size = gen.tam_px()
	_geo.add_child(fondo)

	_tm.clear()
	_celdas_musgo.clear()
	_celdas_agua.clear()
	_celdas_sumidero.clear()
	# En un piso DE CORTE conviven dos estilos, asi que el TileSet lleva una fuente por tramo y cada
	# celda se pinta con la suya (ver Transicion). En un piso normal solo hay una y esto es lo de
	# siempre.
	_trans.preparar(_piso_construido, gen, _semilla_del_piso())
	# En un piso de corte hay dos estilos; basta con saber si ALGUNO es de cueva para pintar suelo
	# bajo los muros (a los de piedra picada les sobra, pero no les estorba).
	_estilo_cueva = false
	for t in TerrenoSprites.tramos_de(_piso_construido):
		if TerrenoSprites.estilo_de(t) == "cueva":
			_estilo_cueva = true
	var ts: TileSet = TerrenoSprites.tileset_de_tramos(
		TerrenoSprites.tramos_de(_piso_construido))
	for capa in TerrenoSprites.CAPAS_ORDEN:
		var tml := TileMapLayer.new()
		tml.name = "TM_" + capa
		tml.tile_set = ts
		# POR NODO, que el proyecto no lo pone globalmente (misma nota que en enemy.gd).
		tml.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_geo.add_child(tml)
		_tm[capa] = tml

	# --- Suelo y muro, celda a celda ---
	var sem: int = _semilla_del_piso()
	var suelo: TileMapLayer = _tm["suelo"]
	var muro: TileMapLayer = _tm["muro"]
	for y in gen.alto:
		for x in gen.ancho:
			var c := Vector2i(x, y)
			var fte: int = _trans.fuente(c)
			if _es_formacion.has(c):
				# COLUMNA de la cueva: es roca en el generador (choca y tapa la luz), pero se dibuja
				# como SUELO + una estalagmita encima, no como un trozo de pared. Pintada de muro
				# salia un azulejo plano y claro que parecia un fallo grafico: una celda de pared con
				# los cuatro lados expuestos no tiene forma de piedra suelta.
				suelo.set_cell(c, fte, TerrenoSprites.celda_para("suelo", c, 0, sem))
				_tm["columna"].set_cell(c, fte, TerrenoSprites.celda_para("columna", c, 0, sem))
			elif gen.es_suelo(c):
				suelo.set_cell(c, fte, TerrenoSprites.celda_para("suelo", c, 0, sem))
			elif Decorado.muro_visible(gen, c):
				# EN LA CUEVA, SUELO TAMBIEN DEBAJO DEL MURO. Su roca no llena la celda: el borde
				# ondula y deja pixeles transparentes (ver TerrenoSprites._pintar_muro_cueva), asi
				# que sin esto por esos huecos se veria el fondo negro y la pared saldria con el
				# canto comido. En la mazmorra picada de arriba la roca llena su celda y esto no
				# hace falta.
				if _estilo_cueva:
					suelo.set_cell(c, fte, TerrenoSprites.celda_para("suelo", c, 0, sem))
				# La MASCARA (por que lados esta expuesto) sale de la MISMA regla que usa el
				# musgo para trepar, y por eso vive en Decorado: si aqui y alli no contaran la
				# roca igual, el verde treparia por muros que no existen.
				var m: int = TerrenoSprites.mascara(c, func(v: Vector2i) -> bool:
					return Decorado.es_roca(gen, v))
				# CON `fte`, no con 0. Estuvo con el 0 fijo y el resultado era que en el piso 7 el
				# suelo era de cueva y las paredes seguian siendo las de la mazmorra de arriba: lo
				# canto el usuario jugando, "es entera la pared de color de los pisos otros".
				muro.set_cell(c, fte, TerrenoSprites.celda_para("muro", c, m, sem))

	# --- Colision: EXACTAMENTE lo de antes ---
	var cuerpo := StaticBody2D.new()
	cuerpo.name = "Muros"
	_geo.add_child(cuerpo)
	for r in gen.muros_fusionados():
		var forma := RectangleShape2D.new()
		forma.size = Vector2(r.size) * celda
		var col := CollisionShape2D.new()
		col.shape = forma
		col.position = (Vector2(r.position) + Vector2(r.size) * 0.5) * celda
		# UNA ESTALAGMITA NO OCUPA SU CELDA ENTERA. Es una piedra en medio del suelo, no un trozo de
		# pared: si su caja fuera la celda completa, chocarias con aire a media celda de distancia
		# de ella -- se ve enseguida en cuanto la rodeas. Asi que a las formaciones (que salen del
		# fusionado como rectangulos de 1x1, porque nacen aisladas) se les da una caja a la medida
		# de lo que se dibuja: mas estrecha que alta y apoyada en el pie, que es donde esta la roca.
		#
		# La LUZ sigue tapandola entera, y es correcto: la sombra va por celdas (ver Vision) y una
		# piedra de este tamaño tapa lo que hay detras.
		if r.size == Vector2i.ONE and _es_formacion.has(r.position):
			forma.size = Vector2(FORMACION_CAJA) 
			col.position = (Vector2(r.position) + Vector2(0.5, 1.0)) * celda 				- Vector2(0.0, FORMACION_CAJA.y * 0.5 + FORMACION_PIE)
		cuerpo.add_child(col)



# ------------------------------------------------------------
#  ADORNO: MUSGO Y AGUA
#
#  QUE celdas llevan cada cosa lo decide Decorado, que son datos puros y se puede mirar sin
#  arrancar una partida (ver tools/ver_terreno.gd). Aqui solo se PINTA lo que aquel decide.
#
#  Va APARTE de _construir_geometria y DESPUES de _elegir_estanque, y no es capricho de orden: el
#  riachuelo tiene que saber donde esta el lago para poder desembocar en el, y el estanque se
#  elige mas tarde (necesita saber antes cual es la sala del jefe).
# ------------------------------------------------------------
# ------------------------------------------------------------
#  LA OSCURIDAD
#
#  El nodo de niebla NO cuelga de _geo: _geo se tira entero en cada regenerar() y la niebla tiene
#  que sobrevivir al cambio de piso (si no, cada bajada crearia otra capa encima de la anterior).
#  Se crea una sola vez y en cada piso se le pasa la rejilla nueva.
# ------------------------------------------------------------
var _niebla: Node2D = null

func _apagar_la_luz() -> void:
	if _niebla == null or not is_instance_valid(_niebla):
		_niebla = (load("res://scripts/world/niebla.gd") as Script).new()
		_niebla.name = "Niebla"
		add_child(_niebla)
	_niebla.preparar(gen)
	# LAS FLORES, aqui y no en _decorar: alli la niebla puede no existir todavia (se crea en esta
	# funcion, que corre justo despues). Van despues de preparar() porque el precalculo de su luz
	# necesita la rejilla de roca ya cargada.
	_niebla.poner_flores(_celdas_flor)


func _decorar() -> void:
	var sem: int = _semilla_del_piso()
	var d := Decorado.new()
	# Las FLORES que alumbran son cosa de la cueva: en la mazmorra picada de arriba no hay.
	d.generar(gen, _celda_estanque, ESTANQUE_CELDAS, sem, _estilo_cueva)
	_celdas_musgo = d.musgo
	_celdas_agua = d.agua
	_celdas_sumidero = d.sumidero
	_celdas_flor = d.flor
	_pintar_capa("agua", _celdas_agua, sem)
	_pintar_capa("sumidero", _celdas_sumidero, sem)
	_pintar_capa("musgo", _celdas_musgo, sem)
	# La flor va DESPUES del musgo: crece en el.
	_pintar_capa("flor", _celdas_flor, sem)



# Vuelca un conjunto de celdas en su TileMapLayer, calculando la mascara de cada una contra las
# OTRAS DE SU MISMA CAPA (que es lo que hace que la mancha tenga orilla y el riachuelo, cauce).
func _pintar_capa(capa: String, celdas: Dictionary, sem: int) -> void:
	var tml: TileMapLayer = _tm.get(capa, null)
	if tml == null or celdas.is_empty():
		return
	var soy := func(v: Vector2i) -> bool: return celdas.has(v)
	for c in celdas:
		var m: int = TerrenoSprites.mascara(c, soy)
		# Con la fuente de SU celda: en un piso de corte, el musgo y el agua que caen dentro de la
		# burbuja de entrada tienen que salir del tramo viejo, o se veria musgo de cueva creciendo
		# en una pared de mazmorra de piedra.
		tml.set_cell(c, _trans.fuente(c), TerrenoSprites.celda_para(capa, c, m, sem))



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

	# SALAS SEGURAS: la de la BOCA y la del FONDO. Con esas dos quedan cubiertas las tres puertas del
	# piso, sin tener que ir puerta por puerta: la salida al pueblo se planta 3 celdas al lado de la
	# bajada (ver abrir_salidas), y en el piso 1 la puerta al pueblo esta en la propia boca.
	# Se marcan aunque este piso no tenga bajada todavia (jefe sin matar): la sala del fondo es la
	# misma, y si la matas se abre ahi.
	_marcar_seguras([entrada.get_center(), lejana.get_center() if lejana.size != Vector2i.ZERO else entrada.get_center()])

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
	# EL PISO QUE SE ESTA CONSTRUYENDO, no Game.current_floor. Era el unico sitio de todo el bloque
	# del jefe que preguntaba por current_floor (los demas -las lineas de abajo, _repoblar_boss y la
	# restauracion de memoria- ya usan _piso_construido), y los dos pueden ir desacompasados: una
	# transicion de escalera, una construccion diferida desde _ready, o el piso de otro jugador en
	# multi. Cuando divergen se planta el jefe EQUIVOCADO, o ninguno -- y como piso_bloqueado() cierra
	# la bajada y la salida hasta que cae, el piso se queda en callejon sin salida.
	var data: EnemyData = Game.boss_del_piso(_piso_construido)
	if data == null:
		return
	var sala: Rect2i = _sala_central()
	if sala.size == Vector2i.ZERO:
		return
	# La ZONA se marca AQUI MISMO (sincrono): _crear_zonas la lee justo despues para NO poblar la
	# sala del boss. Diferir esto le pondria escolta al jefe.
	#
	# Y se marca ANTES de los dos "return" de abajo a proposito: la sala del jefe es suya SIEMPRE,
	# tambien cuando el piso se restaura de memoria o cuando el jefe esta muerto esperando su reloj.
	# Antes esto colgaba del caso "piso nuevo", asi que un piso ya pisado le llenaba la sala de
	# escolta; con la mazmorra persistente eso pasaria casi siempre.
	_sala_boss = gen.zona_en(sala.get_center())   # su zona NO parira bichos (ver _crear_zonas)
	_boss_pos = gen.centro_px(sala.get_center())  # donde renace si su reloj cumple (ver _repoblar_boss)
	_boss_radio = _radio_merodeo_boss(sala)

	# Si el piso se RESTAURA de memoria, el boss ya vendra con los demas enemigos: no duplicar.
	if Game.memoria_pisos.has(_piso_construido):
		return
	# Y si esta MUERTO y su reloj no ha cumplido, no se planta: la mazmorra ya no se olvida al pasar
	# por el pueblo, asi que el jefe vuelve por tiempo (ver Game.BOSS_RESPAWN).
	if not Game.boss_disponible(_piso_construido):
		print("[mazmorra] el jefe del piso ", _piso_construido, " sigue muerto: aun le queda reloj")
		return
	# Y se le abre hueco en el aforo, igual que en el respawn por reloj (ver _hacer_sitio_al_jefe).
	_hacer_sitio_al_jefe()
	# El BICHO, en cambio, DIFERIDO, por lo mismo que poblar()/_colocar_recolectables:
	# crear_enemigo cuelga al enemigo de Main (get_parent()), y si el piso se construye desde
	# _ready (entrar por el ATAJO, o cargar una partida en este piso) Main aun esta montando sus
	# hijos y Godot RECHAZA el add_child: el boss se creaba y no entraba en la escena. Bajando por
	# la escalera nunca se noto, porque regenerar() corre con todo montado.
	call_deferred("_parir_boss", data, gen.centro_px(sala.get_center()), _piso_construido)


# ============================================================
#  FORMACIONES DE CUEVA
#  Columnas de piedra sueltas en medio de las salas, a partir del tramo de cueva. Son ROCA DE
#  VERDAD: chocas con ellas y TAPAN LA LUZ, asi que detras de una columna no se ve y puede haber
#  algo esperando. Por eso se marcan en el generador y no como un adorno pintado encima: asi la
#  colision, la vision, la IA y el aforo se enteran solos, sin que ninguno tenga que saber que
#  existen las formaciones.
#
#  LA REGLA QUE NO SE PUEDE ROMPER: una columna NUNCA puede cerrar un paso. Una piedra en un
#  pasillo o en la boca de una sala te deja sin poder bajar, y encima por sorteo. No se confia en
#  que "casi nunca" pase: se comprueba.
# ============================================================
# Pocas: una o dos por sala, que es lo que rompe la sala vacia sin estorbar de verdad.
const FORMACION_MIN := 1
const FORMACION_MAX := 2
# Celdas libres que se dejan hasta el borde de la sala. Una columna pegada a la pared estrangula la
# boca del pasillo igual que una puesta dentro de el.
const FORMACION_MARGEN := 2
# Separacion minima entre dos formaciones: dos juntas hacen un tapon aunque cada una por separado
# se pueda rodear.
const FORMACION_SEPARACION := 5
# Hueco central que se respeta en las salas donde CABE UN CHARCO, porque el estanque se elige mas
# tarde -- cuando estas piedras ya estan puestas -- y siempre va al centro de su sala. En las salas
# pequeñas no se respeta nada: ahi no puede caer un charco (ver _elegir_estanque, que exige el
# tamaño del charco mas cuatro), y reservarles el centro las dejaba sin un solo sitio valido.
# Ese era el motivo de que salieran 2 columnas por PISO en vez de 1-2 por SALA.
const FORMACION_CENTRO_LIBRE := Vector2i(8, 7)
# La CAJA con la que se choca contra una estalagmita, en px, y cuanto se levanta del borde de
# abajo de su celda. Sale de lo que dibuja TerrenoSprites._pintar_columna: si no coinciden, chocas
# con aire. Es un pelin mas estrecha que el dibujo a proposito -- entre rozar una piedra que se ve
# y quedarse trabado en uno que no, es mejor lo primero.
# MEDIDO contra los pixeles que de verdad dibuja TerrenoSprites._pintar_columna, no a ojo: sus
# variantes ocupan x 9..23 (13-15 px de ancho) y llegan hasta y=28. La primera version tenia 20 px
# de ancho, o sea TRES PIXELES DE AIRE A CADA LADO con los que se chocaba -- en una pared larga eso
# no se nota, pero en una piedra suelta que rodeas de cerca es lo que hacia que pareciera rota.
#
# Va un pelin MAS ESTRECHA que el dibujo mas estrecho, a proposito: entre rozar visualmente una
# piedra y quedarse trabado en aire, siempre lo primero.
const FORMACION_CAJA := Vector2(13.0, 20.0)
const FORMACION_PIE := 3.0


func _sembrar_formaciones() -> void:
	# LO PRIMERO, VACIAR: esto se llama en cada piso, y los dos "return" de abajo son lo normal en
	# los pisos de arriba. Sin limpiar aqui, subir del 7 al 6 se traia las columnas del 7 puestas y
	# se pintarian estalagmitas en celdas que ahi son suelo llano.
	_celdas_formacion.clear()
	_es_formacion.clear()
	if gen == null or gen.salas.is_empty():
		return
	if not TerrenoSprites.hay_formaciones(_piso_construido):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _semilla_del_piso() + 5501   # de la SEMILLA: host e invitado ven las mismas piedras

	# Las tres salas con papel propio se quedan limpias: la boca (donde apareces), la del fondo
	# (escalera y salida) y la del jefe.
	var entrada: Rect2i = gen.salas[0]
	var fondo: Rect2i = _sala_mas_lejana(entrada)
	var central: Rect2i = _sala_central()

	var referencia: Vector2i = entrada.get_center()
	var antes: int = gen.alcanzables(referencia)
	var puestas: Array[Vector2i] = []
	for sala in gen.salas:
		if sala == entrada or sala == fondo or sala == central:
			continue
		var cuantas: int = rng.randi_range(FORMACION_MIN, FORMACION_MAX)
		for _i in range(cuantas):
			var c: Vector2i = _sitio_para_formacion(sala, puestas, rng)
			if c == Vector2i.MAX:
				continue
			gen.poner_roca(c)
			# LA COMPROBACION: si al ponerla se puede llegar andando a menos sitios que antes, esa
			# piedra tapaba el unico paso. Se retira y no se discute.
			if gen.alcanzables(referencia) != antes - 1:
				gen.solido[c.y * gen.ancho + c.x] = 0
				gen.zona_de[c.y * gen.ancho + c.x] = gen.zona_en(sala.get_center())
				(gen.zonas[gen.zona_en(sala.get_center())]["celdas"] as Array).append(c)
				continue
			antes -= 1        # esa celda ya no es suelo: el recuento baja con ella
			puestas.append(c)
	_celdas_formacion = puestas
	_es_formacion.clear()
	for c in puestas:
		_es_formacion[c] = true
	if not puestas.is_empty():
		print("[mazmorra] piso %d: %d formaciones de piedra" % [_piso_construido, puestas.size()])


# Un sitio valido para una columna dentro de esta sala, o Vector2i.MAX si no lo hay.
func _sitio_para_formacion(sala: Rect2i, puestas: Array[Vector2i],
		rng: RandomNumberGenerator) -> Vector2i:
	var centro: Vector2i = sala.get_center()
	for _intento in range(24):
		var c := Vector2i(
			rng.randi_range(sala.position.x + FORMACION_MARGEN,
				sala.position.x + sala.size.x - FORMACION_MARGEN - 1),
			rng.randi_range(sala.position.y + FORMACION_MARGEN,
				sala.position.y + sala.size.y - FORMACION_MARGEN - 1))
		# El centro libre, SOLO en las salas donde cabria un charco (ver FORMACION_CENTRO_LIBRE).
		if sala.size.x >= ESTANQUE_CELDAS.x + 4 and sala.size.y >= ESTANQUE_CELDAS.y + 4:
			if absi(c.x - centro.x) <= FORMACION_CENTRO_LIBRE.x / 2 \
					and absi(c.y - centro.y) <= FORMACION_CENTRO_LIBRE.y / 2:
				continue
		# AISLADA: sus ocho vecinas tienen que ser suelo. Asi es una piedra en medio de la sala y no
		# un bulto pegado a la pared, que es lo que estrecharia un paso sin parecerlo.
		var libre: bool = true
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if gen.es_solido(c + Vector2i(dx, dy)):
					libre = false
					break
			if not libre:
				break
		if not libre:
			continue
		var lejos: bool = true
		for p in puestas:
			if absi(p.x - c.x) < FORMACION_SEPARACION and absi(p.y - c.y) < FORMACION_SEPARACION:
				lejos = false
				break
		if lejos:
			return c
	return Vector2i.MAX


# Cuanto merodea el jefe dentro de su sala. MISMO criterio que las zonas normales (medio lado corto,
# ver _crear_zonas) porque el problema es el mismo: que no se salga de lo suyo. Lo unico distinto es
# el techo, mas alto: una zona corriente comparte sala con mas corros y el jefe tiene la suya
# entera para el, asi que capandolo a lo mismo se quedaria dando vueltas en un pañuelo en el centro.
#
# Nace en el CENTRO de la sala (no pegado a una pared como la morralla), asi que un circulo a su
# alrededor cae dentro de la sala y no hace falta darle la lista de celdas pisables.
# Lo que ocupa medio jefe. Es una estimacion a ojo y generosa a proposito: el tamaño de verdad sale
# del sprite (SpritesEnemigo.tam_cuerpo) y aqui todavia no hay bicho -- el radio se decide al colocar
# la sala, antes de parirlo. Pasarse un poco solo le quita unos pixeles de paseo; quedarse corto lo
# encajona contra la pared, que es lo que se venia a arreglar.
const BOSS_BULTO := 52.0

func _radio_merodeo_boss(sala: Rect2i) -> float:
	var lado: float = float(mini(sala.size.x, sala.size.y)) * float(DungeonGenerator.CELDA)
	# LA MITAD DEL LADO CORTO ES DEMASIADO para un bicho del tamaño del jefe: el radio se mide desde
	# el CENTRO del bicho, asi que con medio lado su borde acaba METIDO EN LA PARED -- deambulaba
	# hacia abajo y se quedaba sin sitio para moverse, encajonado contra el muro.
	#
	# Se le descuenta su propio cuerpo (BOSS_BULTO, una estimacion generosa del radio de un jefe:
	# escala 2,8 sobre una celda de 32 son unos 45 px de medio cuerpo, y se redondea hacia arriba para
	# que le quede holgura). El suelo de 64 px se respeta igual: una sala minima le deja poco, pero
	# clavarlo en el sitio es peor.
	return clampf(lado * 0.5 - BOSS_BULTO, 64.0, 220.0)


# El parto del boss, ya con el arbol montado. Lleva el piso al que pertenece: si entre el diferido y
# esta llamada el piso ha cambiado, este jefe ya no es de aqui y no se planta.
func _parir_boss(data: EnemyData, pos: Vector2, piso: int) -> void:
	if piso != _piso_construido:
		return
	# t = 1.0 (el techo de su franja) y la mutacion A DADOS como cualquier otro (-1): un jefe TAMBIEN
	# puede salir mutante, solo que con multiplicadores mucho mas suaves -- los suyos los elige
	# EnemyData.mult_mutante por la bandera de jefe, que ya va puesta desde crear_enemigo.
	# El RADIO es lo que le deja merodear por su sala. Estaba a 0, y por eso el Rey Slime se quedaba
	# clavado en el centro y solo se movia para perseguirte: sin radio no hay a donde deambular.
	var e = crear_enemigo(data, pos, _boss_radio, 1.0, -1, true)
	# Sale TREPANDO hacia fuera: _mandarlo_al_hueco decide por donde hay sitio y devuelve el hogar, y
	# _emerger lo lleva del centro del agujero hasta el borde mientras se estira.
	var hogar: Vector2 = _mandarlo_al_hueco(e, pos)
	_emerger(e, pos, hogar)


# HACIA DONDE TIENE SITIO. El jefe nace en el centro de su sala y de ahi merodea a ciegas: si la
# sala es alargada o tiene un recodo, se metia por el lado corto y se quedaba encajonado contra el
# muro, sin espacio ni para moverse -- que es como se le vio salir "para abajo" en una prueba.
#
# Se le busca el sitio con MAS HUECO ALREDEDOR y se le pone ahi el hogar de merodeo. No se le mueve:
# sale por el agujero, que es donde tiene que salir, y a partir de ahi deambula hacia lo despejado en
# vez de hacia la primera pared que pille.
const BOSS_SONDAS := 12          # direcciones que se prueban
const BOSS_ALCANCE_SONDA := 6    # hasta cuantas celdas se mira en cada una

func _mandarlo_al_hueco(e: Node2D, centro: Vector2) -> Vector2:
	if e == null or not is_instance_valid(e) or gen == null:
		return centro
	var lado: float = float(DungeonGenerator.CELDA)
	# FUERA DEL BOQUETE. El jefe sale por el agujero, pero no puede QUEDARSE dentro: se le veia
	# merodeando encima del negro, como flotando sobre el vacio por el que acababa de salir. Su sitio
	# es el suelo de alrededor, asi que el corro que ha reventado se descarta entero -- ni para el
	# hogar ni para los puntos por los que deambula.
	var cel_centro: Vector2i = celda_de_px(centro)
	var boquete: Dictionary = {}
	for dy in range(-BOSS_AVISO_RADIO, BOSS_AVISO_RADIO + 1):
		for dx in range(-BOSS_AVISO_RADIO, BOSS_AVISO_RADIO + 1):
			boquete[cel_centro + Vector2i(dx, dy)] = true

	var mejor := centro
	var mejor_libre: int = -1
	var puntos: Array = []
	for i in BOSS_SONDAS:
		var ang: float = TAU * float(i) / float(BOSS_SONDAS)
		var dir := Vector2(cos(ang), sin(ang))
		# Cuanto se puede avanzar por ahi sin salirse del suelo. Se para en la primera celda que no
		# sea pisable: lo que se busca es hueco de verdad, no un pasillo con un recodo.
		var libre: int = 0
		for paso in range(1, BOSS_ALCANCE_SONDA + 1):
			var p: Vector2 = centro + dir * float(paso) * lado
			if not _pisable_px(p):
				break
			libre = paso
			if not boquete.has(celda_de_px(p)):
				puntos.append(p)
		# Solo vale la direccion que llega MAS ALLA del boquete: si no sale de el, por ahi no hay
		# adonde ir. El hogar se pone pasado el borde y a medio camino de lo que quede -- en la punta
		# se pegaria al muro del otro lado y volveriamos a lo mismo por el lado contrario.
		if libre > BOSS_AVISO_RADIO and libre > mejor_libre:
			mejor_libre = libre
			var fuera: float = float(BOSS_AVISO_RADIO + 1)
			mejor = centro + dir * ((fuera + (float(libre) - fuera) * 0.5) * lado)
	if puntos.is_empty():
		puntos.append(centro)
	if e.has_method("asignar_zona"):
		e.call("asignar_zona", puntos, mejor)
	return mejor


# ¿Se puede pisar ese punto? Se le pregunta a la CAPA DEL SUELO, que es lo que se ve: si ahi hay
# baldosa de suelo, se anda.
func _pisable_px(p: Vector2) -> bool:
	var suelo: TileMapLayer = _tm.get("suelo", null)
	if suelo == null:
		return true
	return suelo.get_cell_source_id(celda_de_px(p)) >= 0


# EL JEFE SALE DEL AGUJERO, no aparece plantado encima de el. Se abre el boquete, y del boquete sale
# el bicho: sin esto el agujero quedaba de adorno y el jefe se materializaba a su lado, que era como
# contar la historia y ensenar el final por separado.
#
# El truco es el de siempre en pixel art para lo que emerge: se ESTIRA DESDE LOS PIES. El sprite
# arranca aplastado contra el suelo (casi sin alto) y crece hasta el suyo, asi que la silueta va
# asomando de abajo arriba como si trepara. No hace falta recortarlo contra el borde del hueco --
# que obligaria a una mascara y a meterse en el orden de dibujo del piso -- porque el ojo lee el
# estiramiento como salir.
#
# Y sale OSCURO: viene de dentro del agujero, donde no da la luz, y va cogiendo su color segun
# asoma. Es lo que hace que no parezca que se ha escalado un dibujo.
const EMERGER_DUR := 0.75
const EMERGER_APLASTADO := 0.12   # el alto con el que arranca, en fraccion del suyo

func _emerger(e: Node2D, centro: Vector2, hogar: Vector2) -> void:
	if e == null or not is_instance_valid(e):
		return
	var suyo: Vector2 = e.scale
	# QUIETO MIENTRAS SALE. El bicho MERODEA: su propio proceso le escribe la posicion cada frame, y
	# una animacion de posicion compite con el y pierde -- el jefe acababa saliendo desplazado del
	# agujero, en cualquier sitio menos en su boca. Se le congela el proceso mientras emerge y se le
	# devuelve al terminar, que ademas es lo que tiene sentido: todavia no ha salido, no puede andar.
	var proc: bool = e.is_processing()
	var fis: bool = e.is_physics_processing()
	e.set_process(false)
	e.set_physics_process(false)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(e, "scale", suyo, EMERGER_DUR).from(
		Vector2(suyo.x, suyo.y * EMERGER_APLASTADO)).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT)
	# Y SE SALE DEL AGUJERO. Antes solo se estiraba, y el jefe se quedaba merodeando ENCIMA del negro
	# -- flotando sobre el vacio por el que acababa de salir -- porque hasta su hogar hay que ANDAR y
	# eso tarda. Aqui se le lleva del centro al borde mientras trepa, que es un paso y se ve.
	#
	# La posicion SI se puede animar ahora: durante esto tiene el proceso congelado, asi que su IA no
	# esta escribiendola en paralelo (que fue lo que hizo que el primer intento saliera desplazado).
	var salida: Vector2 = centro
	if hogar != centro:
		var d: Vector2 = (hogar - centro).normalized()
		salida = centro + d * float(BOSS_AVISO_RADIO + 1) * float(DungeonGenerator.CELDA)
	t.tween_property(e, "global_position", salida, EMERGER_DUR).from(centro).set_trans(
		Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	# Del negro del hueco a su color: viene de dentro, donde no da la luz. Mas rapido que el
	# estiramiento, asi que lo ultimo que se ve es la forma asentandose.
	t.tween_property(e, "modulate", Color.WHITE, EMERGER_DUR * 0.7).from(
		Color(0.15, 0.15, 0.18))
	await t.finished
	if is_instance_valid(e):
		e.set_process(proc)
		e.set_physics_process(fis)
		e.scale = suyo
		e.modulate = Color.WHITE
		# Y UNA VEZ FUERA, EL AGUJERO TAMBIEN LE ESTORBA A EL. Los enemigos no miran la capa del
		# boquete -- si la miraran, el jefe naceria atrapado dentro del hoyo por el que tiene que
		# salir --, pero eso deja que luego se meta otra vez: se le veia deambulando por encima del
		# negro, flotando sobre el vacio, e incluso entrando de vuelta.
		#
		# Asi que se le añade AL TERMINAR de salir, que es cuando ya esta a salvo en el borde. Un hoyo
		# es un hoyo: se sale de el, y despues no se vuelve a entrar.
		e.collision_mask |= _FX_PARTO.CAPA_BOQUETE


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
#  ESTANQUE: la sala con el charco de pescar. UNO por piso.
# ------------------------------------------------------------
#  Se elige con RNG PROPIO (sembrado aparte, como los recolectables) para que cambiar esto no
#  altere el trazado del piso ni la colocacion de las vetas. Determinista: el mismo piso pone el
#  charco en la misma sala, siempre, y el invitado lo calcula igual sin que viaje por la red.
#
#  "Uno por piso, SIEMPRE" vive entero AQUI: el dia que quiera que sea probabilistico, o que solo
#  aparezca a partir del piso N, es esta funcion y nada mas.
func _elegir_estanque() -> void:
	if gen == null or gen.salas.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _semilla_del_piso() + 2027

	# Ni la boca, ni la del fondo (escalera/salida), ni la del jefe. Las tres tienen ya su papel y
	# meterles un charco encima solo estorba.
	var entrada: Rect2i = gen.salas[0]
	var escalera: Rect2i = _sala_mas_lejana(entrada)
	var candidatas: Array[Rect2i] = []
	for s in gen.salas:
		if s == entrada or s == escalera:
			continue
		if gen.zona_en(s.get_center()) == _sala_boss:
			continue
		# Que quepa el charco con un anillo de suelo alrededor: si no, se pesca desde dentro del agua.
		if s.size.x < ESTANQUE_CELDAS.x + 4 or s.size.y < ESTANQUE_CELDAS.y + 4:
			continue
		candidatas.append(s)
	if candidatas.is_empty():
		print("[mazmorra] piso ", _piso_construido, ": sin sala para el estanque")
		return

	var sala: Rect2i = candidatas[rng.randi_range(0, candidatas.size() - 1)]
	_zona_estanque = gen.zona_en(sala.get_center())
	_celda_estanque = sala.get_center()


# El charco, ya con el arbol montado (lo llama _colocar_recolectables, que va diferido por el mismo
# motivo). Marca sus celdas como ocupadas para que no le brote una veta dentro.
func _crear_estanque() -> void:
	if _zona_estanque < 0 or _celda_estanque == Vector2i.MAX or tabla_peces == null:
		return
	var mitad := Vector2i(ESTANQUE_CELDAS.x / 2, ESTANQUE_CELDAS.y / 2)
	for dx in range(ESTANQUE_CELDAS.x):
		for dy in range(ESTANQUE_CELDAS.y):
			_ocupada[_celda_estanque - mitad + Vector2i(dx, dy)] = true

	var n: Node2D = _fishing_script.new()
	n.celda = _celda_estanque
	n.tam_celdas = ESTANQUE_CELDAS
	n.tabla = tabla_peces
	n.position = gen.centro_px(_celda_estanque)
	# Cuelga del PADRE (Main) y no del piso: el piso va a z_index -1 y el agua tiene que verse por
	# encima del suelo, igual que las vetas.
	get_parent().add_child(n)
	print("[mazmorra] estanque en la zona ", _zona_estanque, " (celda ", _celda_estanque, ")")


# ¿Esta celda es agua (o su orilla inmediata)? La consulta el MERODEO de los bichos
# (Enemy._pick_wander_target) para no elegir un destino dentro del charco.
#
# El agua ya tiene colision, asi que fisicamente no entran; el problema era que SI la elegian como
# destino, se quedaban empujando contra el borde hasta que saltaba el anti-atasco y los teletransportaba
# a casa. Desde fuera parecia que el bicho se metia en el estanque. Ahora ni lo intentan.
#
# El MARGEN de 1 celda es a proposito: sin el, el destino cae justo pegado al agua y el bicho acaba
# igualmente rozandola. Y esto NO lo mira _chase(): el que te persigue entra detras de ti.
func celda_en_estanque(celda: Vector2i, margen: int = 1) -> bool:
	if _celda_estanque == Vector2i.MAX:
		return false
	var mitad := Vector2i(ESTANQUE_CELDAS.x / 2, ESTANQUE_CELDAS.y / 2)
	var esquina: Vector2i = _celda_estanque - mitad - Vector2i(margen, margen)
	var tam: Vector2i = ESTANQUE_CELDAS + Vector2i(margen, margen) * 2
	return Rect2i(esquina, tam).has_point(celda)


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

	# El charco PRIMERO: reserva sus celdas en _ocupada antes de que nadie reparta vetas.
	_crear_estanque()
	# Y el CAUCE igual: por el riachuelo corre agua, asi que ahi no crece un arbol ni asoma una
	# veta. Sin esto salian matas y troncos plantados en mitad de la corriente.
	# No gasta ni una tirada del rng, asi que no le corre el sitio a nada de lo de abajo.
	for c in _celdas_agua:
		_ocupada[c] = true
	for c in _celdas_sumidero:
		_ocupada[c] = true

	var plantas: int = _colocar_en_pasillos(rng, tabla_plantas, max_plantas_piso, 1)
	var maderas: int = _colocar_en_pasillos(rng, tabla_maderas, max_madera_piso, 2)
	var vetas: int = _colocar_vetas(rng)
	# La DESPENSA va la ULTIMA, y el orden importa por DOS razones:
	#   1) es la que sobra: si el piso se queda sin celdas junto a pared, que la que falte sea una
	#      cebolla y no el mineral;
	#   2) TODAS estas tiradas salen del MISMO rng, asi que meterla en medio le habria corrido el
	#      sitio a las vetas de las partidas que YA EXISTEN. Puesta al final, el piso de siempre
	#      sigue siendo el piso de siempre y esto solo AÑADE (comprobado celda a celda contra la
	#      version anterior en los pisos 1, 3 y 5).
	# Quien meta un recolectable nuevo, que lo ponga detras de este por lo mismo.
	var sal: int = _colocar_en_salas(rng, tabla_sal, 3,
		rng.randi_range(sal_min_piso, sal_max_piso), 1, 1)
	var silvestres: int = _colocar_en_pasillos(rng, tabla_silvestres,
		rng.randi_range(silvestres_min_piso, silvestres_max_piso), 4, false)
	# EL CARBON, EL ULTIMO DE TODOS. No es preferencia estetica: todas estas tiradas salen del
	# MISMO rng, asi que meterlo en medio le habria corrido el sitio a las vetas (y a la sal) de
	# las partidas que YA EXISTEN. Puesto al final, el piso de siempre sigue siendo el de siempre
	# y esto solo AÑADE. Quien meta un recolectable nuevo, que lo ponga detras de este.
	var carbon: int = _colocar_en_salas(rng, tabla_carbon, 5,
		rng.randi_range(carbon_min_piso, carbon_max_piso), 1, 1)
	print("[mazmorra] recolectables: ", vetas, " vetas, ", plantas, " plantas y ",
		maderas, " enredaderas (", _agotados.size(), " ya recolectadas)")
	print("[mazmorra] despensa: ", sal, " de sal y ", silvestres, " silvestres")
	print("[mazmorra] carbon: ", carbon, " vetas")
	if tabla_vetas != null:
		print("[mazmorra] vetas del piso: ", tabla_vetas.resumen(Game.current_floor))
	if tabla_plantas != null:
		print("[mazmorra] plantas del piso: ", tabla_plantas.resumen(Game.current_floor))
	if tabla_maderas != null:
		print("[mazmorra] maderas del piso: ", tabla_maderas.resumen(Game.current_floor))
	if tabla_silvestres != null:
		print("[mazmorra] silvestres del piso: ", tabla_silvestres.resumen(Game.current_floor))


# PLANTAS y ENREDADERAS: en los PASILLOS. Es el botin del transito: los pisas yendo a
# cualquier parte. El TOPE del piso manda sobre el reparto: se van llenando pasillos hasta
# agotarlo. Las dos cosas se reparten igual (y _ocupada impide que caigan en la misma celda),
# asi que comparten funcion: lo unico que cambia es la tabla, el tope y el tipo de nodo.
#
# OJO: lo que cuenta contra el tope son los SITIOS (los huecos que el piso tiene), no los
# nodos que acaban naciendo. Si contara solo los nacidos, cada planta que ya recolectaste
# liberaria su cupo y brotaria OTRA en el siguiente hueco: volver a un piso lo repoblaria de
# plantas nuevas y recolectar no serviria de nada.
#
# 'escalar' = si el tope crece con el AREA del piso. Lo de siempre (plantas y enredaderas) si: son
# densidad, y un piso el doble de grande tiene que dar el doble. La despensa NO: su tope es un cupo
# contado (2-3 silvestres y punto), y escalarlo lo convertiria en seis en un piso grande.
func _colocar_en_pasillos(rng: RandomNumberGenerator, tabla: MaterialTable,
		tope_base: int, tipo: int, escalar: bool = true) -> int:
	if tabla == null:
		return 0
	var tope: int = escalar_con_el_piso(tope_base) if escalar else tope_base
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
	return _colocar_en_salas(rng, tabla_vetas, 0, escalar_con_el_piso(max_vetas_piso),
		vetas_min_sala, vetas_max_sala)


# El reparto EN SALAS, que comparten las vetas y la sal (las dos son roca y las dos tienen que
# quedar hondas). Lo unico que cambia entre las dos es la tabla, el tipo de nodo, el tope y cuantas
# caben por sala; el criterio de QUE salas y en que orden es el mismo, y por eso vive en un sitio.
#
# El TOPE llega ya resuelto: las vetas lo escalan con el area del piso y la sal no (ver los @export
# de la despensa). Que lo decida quien llama y no esta funcion.
func _colocar_en_salas(rng: RandomNumberGenerator, tabla: MaterialTable, tipo: int,
		tope: int, min_sala: int, max_sala: int) -> int:
	if tabla == null or tope <= 0:
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
	var sitios: int = 0
	var puestas: int = 0
	for i in range(cuantas):
		if sitios >= tope:
			break
		var idx: int = gen.zona_en(candidatas[i].get_center())
		if idx < 0:
			continue
		var celdas: Array = gen.zonas[idx]["celdas"]
		var n: int = mini(rng.randi_range(min_sala, max_sala), tope - sitios)
		for _k in range(n):
			var c: Vector2i = _celda_junto_a_pared(celdas, rng)
			if c == Vector2i.MAX:
				break
			sitios += 1
			if _crear_recolectable(tipo, c):
				puestas += 1
	return puestas


# Instancia un recolectable (ver ResourceNode.Tipo: 0 veta, 1 planta, 2 madera, 3 sal, 4 huerto).
# Devuelve false si esa celda
# esta agotada y AUN NO le toca reaparecer (respawn por tiempo), o si la tabla no tiene nada
# para esta profundidad.
func _crear_recolectable(tipo: int, celda: Vector2i) -> bool:
	# El SITIO queda apuntado nazca o no el nodo: es lo que permite que una celda picada vuelva a
	# brotar EN VIVO mas tarde (_repoblar_agotados). Se guarda la TABLA, no el material ya elegido,
	# porque el material se vuelve a tirar en cada respawn (ver _material_del_sitio).
	_sitios[celda] = {"tipo": tipo}
	# MULTIJUGADOR: lo agotado en ESTA expedicion no vuelve a nacer al reconstruir el piso
	# (p. ej. al bajar y volver a subir): el sello de sesion vive en Net, no en mi save.
	if Net.activo and Net.celda_agotada_sesion(celda, _piso_construido):
		return false
	# ¿Agotada? Reaparece cuando han pasado RESPAWN_SEGUNDOS de RELOJ DE PARED desde que la picaste.
	# le toca, se limpia el sello y nace como nueva; si no, no nace todavia.
	if _agotados.has(celda):
		if Game.reloj_mundo() - float(_agotados[celda]) < Game.RESPAWN_SEGUNDOS:
			return false
		_olvidar_agotado(celda)
	var m: MaterialData = _material_del_sitio(celda, _nonce_del_sitio(celda))
	if m == null:
		return false
	_instanciar_nodo(tipo, celda, m, false)
	return true


# El nonce del brote VIVO de este sitio. En multi manda el de la sesion (el mundo es del host); en
# solitario, el de mi save. 0 = nunca ha rebrotado, sale lo que puso la epoca.
func _nonce_del_sitio(celda: Vector2i) -> int:
	if Net.activo:
		return Net.nonce_celda_sesion(celda, _piso_construido)
	return int(_nonces.get(celda, 0))


# Apunta con que nonce acaba de brotar este sitio, en la copia local Y en la persistente. Gemela de
# marcar_agotado, y con su misma regla de red: en sesion mi save no se toca.
func _apuntar_nonce(celda: Vector2i, nonce: int) -> void:
	_nonces[celda] = nonce
	if Net.activo:
		return   # en multi lo lleva Net._nonces_sesion, que es del mundo del host
	(Game.persistente_piso(_piso_construido)["nonces"] as Dictionary)[celda] = nonce


# QUE material sale en esta celda, AHORA. No se guarda: se deriva.
#
# Antes el material era DETERMINISTA POR CELDA (salia de la semilla del piso), asi que una veta que
# te toco de cobre veteado lo seria para siempre, en todas las bajadas. Con los sub-tiers eso
# convierte la mezcla del piso en una loteria de una sola tirada: si tu piso 4 salio con mal
# reparto, te lo comes toda la partida. Asi que se paso a tirar de verdad en cada nacimiento.
#
# Y ESO ROMPIO EL MULTIJUGADOR (29/07): la tirada iba al randf() GLOBAL, o sea que cada maquina
# sacaba la suya y dos jugadores veian materiales DISTINTOS en la misma veta (uno cobre normal, otro
# veteado). Peor todavia: al picarla cada uno DESCUBRIA su sub-tier, y por ahi se colaban en el
# herrero del invitado metales que en el mundo del host no habian salido nunca.
#
# La solucion se queda con las dos cosas: la tirada es de verdad (cada nacimiento vuelve a rodar)
# pero SEMBRADA, con la semilla del piso —que en multi es la del host— + la celda + un 'nonce' que
# identifica ESTE nacimiento. Al construir el piso el nonce es 0 en todas las maquinas; al revivir,
# el host manda el suyo por RPC (ver Net._revivir_celda). Mismos tres numeros = mismo material, sin
# necesidad de transportar la ruta del .tres ni de mantener una tabla sincronizada.
#
# Lo que sigue saliendo de la semilla a secas es DONDE hay sitios de recoleccion (la forma del piso).
#
# Y AUN ASI SEGUIA SIENDO ETERNO (16/08): al CONSTRUIR el piso el nonce valia 0 en todas las
# bajadas, asi que una celda daba el mismo material y el mismo sub-tier durante toda la partida —
# la "tirada de verdad" solo pasaba en los respawns en caliente. Se arregla por los dos lados:
#   - la EPOCA (Game.epoca_actual) entra en la semilla: cada expedicion nueva rebaraja el piso entero;
#   - el nonce del ultimo brote se GUARDA (ver _nonces), asi que dentro de una expedicion bajar y
#     volver a subir encuentra lo mismo, pero lo que rebrote puede traer otro sub-tier.
func _material_del_sitio(celda: Vector2i, nonce: int = 0) -> MaterialData:
	var tabla: MaterialTable = _tabla_de_tipo(int((_sitios.get(celda, {}) as Dictionary).get("tipo", -1)))
	if tabla == null:
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_semilla_del_piso(), Game.epoca_actual(), celda.x, celda.y, nonce])
	return tabla.elegir(Game.current_floor, rng)


func _tabla_de_tipo(tipo: int) -> MaterialTable:
	match tipo:
		0: return tabla_vetas
		1: return tabla_plantas
		2: return tabla_maderas
		3: return tabla_sal
		4: return tabla_silvestres
		5: return tabla_carbon
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
	# MULTIJUGADOR: el barrido NO se hace aqui, porque el sello es LOCAL y diverge
	# entre maquinas (la veta reviviria en una y en la otra no). Lo lleva el HOST contra el reloj de
	# la expedicion y lo anuncia por red: Net._barrer_respawns -> Net._revivir_celda -> revivir_celda.
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
		if Game.reloj_mundo() - float(_agotados[celda]) < Game.RESPAWN_SEGUNDOS:
			continue
		# Nonce al azar: en solitario no hay nadie con quien cuadrar, y lo que se quiere es que la
		# veta que vuelve pueda traer otro sub-tier.
		revivir_celda(celda, randi())


# RESPAWN DEL JEFE, EN CALIENTE. Hermano de _repoblar_agotados y por el mismo motivo: el jefe ya no
# vuelve porque la mazmorra se olvide al pasar por el pueblo (ya no se olvida), vuelve por reloj (ver
# Game.BOSS_RESPAWN), y hay que poder verlo volver estando plantado en su sala.
#
# Quien decide si "toca" es Game.boss_disponible, que en sesion pregunta al host: aqui solo se planta.
# Se aprovecha el mismo cronometro que el respawn de vetas (_t_respawn no, que ese ya lo consume la
# otra: este lleva el suyo) y se comprueba lo minimo, que esto corre en cada frame.
func _repoblar_boss(delta: float) -> void:
	if _boss_pos == Vector2.INF or _boss_naciendo:
		# Ya viene de camino: el cartel sobra (y dejarlo puesto lo congelaria en "vuelve en 0:00"
		# durante todo el temblor del aviso).
		if _boss_cartel != null:
			_boss_cartel.visible = false
		return   # este piso no tiene jefe, o el suyo ya viene de camino (ver _anunciar_boss)
	# EL CARTEL LLEVA SU PROPIO LATIDO, mas corto. Colgado del de abajo (2 s) el contador iba a
	# saltos de dos en dos segundos, que en un reloj se ve fatal: parece que va mal, que es justo lo
	# contrario de lo que este cartel viene a demostrar. Va ademas ANTES de los guardias de abajo,
	# porque el que solo espeja el piso no planta al jefe pero tiene el mismo derecho a ver la cuenta.
	_t_cartel -= delta
	if _t_cartel <= 0.0:
		_t_cartel = CARTEL_BOSS_CADA
		_refrescar_cartel_boss()
	_t_boss -= delta
	if _t_boss > 0.0:
		return
	_t_boss = RESPAWN_CHECK_CADA
	# MULTIJUGADOR: lo planta el DUEÑO del piso, el mismo que lo coloca al construirlo. El que espeja
	# lo vera aparecer por red.
	if not Net.simulo_mi_piso() or not Game.boss_disponible(_piso_construido):
		return
	# ¿Ya hay uno de pie? Los cadaveres estan en el grupo "corpse", asi que basta con mirar "enemy".
	for n in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(n) and n.es_boss:
			return
	var data: EnemyData = Game.boss_del_piso(_piso_construido)
	if data == null:
		return
	_hacer_sitio_al_jefe()
	print("[mazmorra] el jefe del piso ", _piso_construido, " vuelve a su sala")
	_anunciar_boss(data)


# Le abre un hueco en el aforo ANTES de plantarlo. El jefe es el unico bicho que no pasa por
# hay_sitio() -- se plantaba a pelo y dejaba el piso por encima del tope (28 vivos con tope 27), y
# entonces el reciclado se ponia a despawnear cosas justo cuando llegabas a la pelea.
#
# OJO CON LA INVARIANTE: esto NO es un permiso, es una cortesia. El valor que devuelve hay_sitio se
# IGNORA y el jefe nace pase lo que pase. Un jefe que no naciera por aforo dejaria el piso tapiado
# para siempre, porque Game.piso_bloqueado() cierra la bajada y la salida hasta que caiga.
#
# Se fuerza (el segundo true) como hacen los brotes gordos: se recicla al vivo mas lejano sea cual
# sea su distancia. _reciclar_lejano ya se salta al propio boss y a los espejos, y los cadaveres
# (que llevan tu botin dentro) estan fuera del grupo "enemy", asi que no puede tocar nada de eso.
func _hacer_sitio_al_jefe() -> void:
	hay_sitio(true, true)


# ============================================================
#  EL CARTEL DE LA SALA DEL JEFE
# ============================================================
# Cuanto le falta al jefe para volver, plantado en el centro de su sala. Solo se ve estando DENTRO de
# la sala y solo mientras el jefe esta caido: no es un HUD, es un letrero que hay en un sitio.
#
# Existe porque el respawn del jefe es lo unico del juego que tarda diez minutos sin dar ninguna
# señal, y cuando fallo no habia forma de distinguir "va lento" de "esta roto" sin leer el log. Con el
# numero bajando, que el reloj corre se ve de un vistazo.
#
# Es PLACEHOLDER por codigo, como el resto de la UI: el pase visual va al final.
const BOSS_CARTEL_MARGEN := 1.35   # se ve un poco antes de entrar del todo en el radio de merodeo
# Cada cuanto se repinta. Cuatro veces por segundo: el numero solo tiene segundos, asi que basta de
# sobra para que el salto de un segundo al siguiente se vea limpio, y no se repinta un Label en cada
# frame por un texto que casi nunca cambia.
const CARTEL_BOSS_CADA := 0.25

var _boss_cartel: Label = null
var _t_cartel: float = 0.0

func _refrescar_cartel_boss() -> void:
	var falta: float = Game.boss_restante(_piso_construido)
	# -1 = el piso no tiene jefe; 0 = ya toca (y entonces esta a punto de plantarse, o ya esta de pie).
	var mostrar: bool = falta > 0.0 and _boss_pos != Vector2.INF and _jugador_en_la_sala_del_jefe()
	if not mostrar:
		if _boss_cartel != null:
			_boss_cartel.visible = false
		return
	if _boss_cartel == null:
		_boss_cartel = Label.new()
		_boss_cartel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_boss_cartel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_boss_cartel.offset_left = -90.0
		_boss_cartel.offset_right = 90.0
		_boss_cartel.offset_top = -30.0
		_boss_cartel.offset_bottom = 30.0
		# Del PADRE del piso, no del piso: el piso va con z_index -1 y un hijo suyo se pintaria por
		# debajo del suelo. Es la misma razon por la que crear_enemigo cuelga a los bichos ahi.
		var mundo: Node = get_parent()
		if mundo == null:
			mundo = self
		mundo.add_child(_boss_cartel)
	_boss_cartel.position = _boss_pos
	_boss_cartel.visible = true
	var m: int = int(falta) / 60
	var s: int = int(falta) % 60
	_boss_cartel.text = "vuelve en %d:%02d" % [m, s]


func _jugador_en_la_sala_del_jefe() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if not (player is Node2D):
		return false
	# El mismo radio con el que merodea (lo calcula _colocar_boss): su sala, ni mas ni menos.
	return (player as Node2D).global_position.distance_to(_boss_pos) <= _boss_radio * BOSS_CARTEL_MARGEN


# ============================================================
#  EL PARTO DEL JEFE, ANUNCIADO
# ============================================================
# Antes el jefe aparecia DE GOLPE en mitad de su sala: estabas dentro, parpadeabas y ya estaba ahi.
# Ahora tiembla primero, como un brote de pared, pero MAS GORDO: mas rato y mas amplitud, y sobre un
# corro de celdas en vez de un tramo de muro. Es la misma pieza que usa SpawnZone (WallBirthFx), asi
# que el lenguaje visual es el que ya conoces -- "el suelo late, viene algo".
#
# LO QUE NO HACE ES EMBESTIR. El brote llama a nacer_embistiendo() y los bichos salen disparados
# hacia ti; el jefe no. Nace y se queda merodeando su sala, como siempre: es el dueño del sitio, no
# una emboscada. (Regla del usuario, y ademas su sala es lo bastante grande como para que salir
# corriendo hacia el jugador fuese solo un susto barato.)
const BOSS_AVISO_DUR := 2.6    # el brote gordo anda por 2.6 s (1.2 x 2.2); el jefe iguala y se queda
const BOSS_AVISO_AMP := 9.0    # y tiembla mas: 3 x el brote normal (2.5 x 3.0 = 7.5)
const BOSS_AVISO_RADIO := 2    # celdas a cada lado del centro: un corro de 5x5 alrededor del jefe
const BOSS_AVISO_COLOR := Color(0.85, 0.15, 0.10)   # mas oscuro y mas rojo que el naranja del brote
const _FX_PARTO := preload("res://scripts/world/wall_birth_fx.gd")


func _anunciar_boss(data: EnemyData) -> void:
	_boss_naciendo = true
	# La inversa de centro_px: de pixeles a celda. floor() y no int(), que con coordenadas negativas
	# int() trunca hacia cero y el corro saldria corrido una celda.
	var centro := Vector2i(
		int(floor(_boss_pos.x / float(DungeonGenerator.CELDA))),
		int(floor(_boss_pos.y / float(DungeonGenerator.CELDA))))
	var celdas: Array = []
	var rejilla: Array = []
	for dy in range(-BOSS_AVISO_RADIO, BOSS_AVISO_RADIO + 1):
		for dx in range(-BOSS_AVISO_RADIO, BOSS_AVISO_RADIO + 1):
			rejilla.append(centro + Vector2i(dx, dy))
			celdas.append(gen.centro_px(centro + Vector2i(dx, dy)))
	if celdas.is_empty():
		celdas.append(_boss_pos)
		rejilla.append(centro)
	var fx: Node2D = _FX_PARTO.new()
	fx.position = celdas[0]
	add_child(fx)
	# EL JEFE NO SALE DE UNA PARED, SALE DEL SUELO de su sala: aqui lo que tiembla, se raja y revienta
	# es el suelo, y montar_aviso coge la capa que toque mirando donde hay baldosa. Se quedo sin
	# enganchar cuando el resto paso a la piedra de verdad, asi que el jefe seguia sacando el
	# rectangulo rojo de color plano mientras los brotes ya reventaban la roca.
	#
	# Su corro son veinticinco celdas, asi que la reparacion tarda casi el doble que la de un brote
	# (ver WallBirthFx.romper) y se cierra de fuera hacia dentro, por las esquinas.
	if not montar_aviso(fx, rejilla, BOSS_AVISO_DUR, BOSS_AVISO_AMP, BOSS_AVISO_COLOR):
		fx.iniciar_tramo(float(DungeonGenerator.CELDA), BOSS_AVISO_DUR, BOSS_AVISO_AMP,
			BOSS_AVISO_COLOR, celdas)
	# El que solo ESPEJA este piso no tiene nada de esto (los bichos no nacen en su maquina), asi que
	# veria al jefe aparecer de la nada. Es puro FX y viaja por el mismo canal que el brote.
	if Net.activo:
		Net.anunciar_brote(celdas, BOSS_AVISO_DUR, BOSS_AVISO_AMP, BOSS_AVISO_COLOR)
	# Y el jefe, cuando acaba el aviso. El piso viaja en la llamada por lo mismo que en _colocar_boss:
	# si entre medias te has ido a otro piso, este jefe ya no es de aqui.
	var piso: int = _piso_construido
	await get_tree().create_timer(BOSS_AVISO_DUR).timeout
	if not is_instance_valid(self):
		return
	_boss_naciendo = false
	if piso != _piso_construido:
		return
	# ROMPER, no borrar: el suelo se queda con su boquete y se cierra solo (ver WallBirthFx.romper).
	# El jefe no sale de una pared, sale del SUELO de su sala, asi que lo que se agrieta es el suelo --
	# y como su corro son veinticinco celdas, la reparacion tarda casi el doble que la de un brote.
	if is_instance_valid(fx):
		fx.romper()
	# Alguien pudo plantarlo mientras temblaba (otro jugador entrando al piso, una carga de memoria):
	# se comprueba otra vez, que dos jefes en la misma sala no los quita nadie.
	for n in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(n) and n.es_boss:
			return
	_parir_boss(data, _boss_pos, piso)


# Hace BROTAR otra vez la celda: levanta el sello y planta el nodo con el material RE-TIRADO.
# Sale de _repoblar_agotados porque lo llaman DOS sitios: el barrido local (solitario) y, en
# multijugador, Net._revivir_celda cuando el host decide que a ese sitio le toca volver.
#
# 'nonce' identifica ESTE nacimiento y es lo que hace que la tirada del material sea la misma en
# todas las maquinas: en solitario lo pone quien llama (un numero al azar, para que revivir vuelva a
# rodar de verdad) y en multi viene del HOST por RPC. Ver _material_del_sitio.
func revivir_celda(celda: Vector2i, nonce: int = 0) -> void:
	_olvidar_agotado(celda)
	var sitio: Dictionary = _sitios.get(celda, {})
	if sitio.is_empty():
		return   # sello de una partida vieja, sin sitio apuntado: se limpia y ya brotara al regenerar
	# Si ya hay algo plantado ahi, no se duplica (un mensaje repetido no debe dar dos vetas).
	for n in get_tree().get_nodes_in_group("recolectable"):
		if is_instance_valid(n) and n.celda == celda and not n.agotado:
			return
	var m: MaterialData = _material_del_sitio(celda, nonce)
	if m == null:
		return   # la tabla no tiene nada para esta profundidad: la celda se queda vacia
	# Se APUNTA el nonce con el que ha brotado: asi este sub-tier es el que se vera tambien cuando el
	# piso se reconstruya, en vez de volver al que puso la epoca al principio.
	_apuntar_nonce(celda, nonce)
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
	# Con el nonce del brote VIVO: sin el, esto contestaria lo que habia al principio de la epoca y
	# no lo que de verdad hay plantado ahi despues de un respawn.
	return _material_del_sitio(celda, _nonce_del_sitio(celda))


# Lo llama Game al terminar un minijuego de recoleccion: esa celda queda explotada, con el
# SELLO del tiempo actual. A partir de ahi cuenta RESPAWN_SEGUNDOS para reaparecer. Se guarda en
# mazmorra_persistente (sobrevive a volver al pueblo) Y en la copia local del piso vivo.
#
# 'retraso' es lo que tarda de MAS que un nodo normal (la despensa, el doble). Se suma al sello en
# vez de guardarse aparte para que las restas de ahi abajo no tengan que saber de tipos: ver
# Game.RESPAWN_RETRASO_DESPENSA.
func marcar_agotado(celda: Vector2i, retraso: float = 0.0) -> void:
	var sello: float = Game.reloj_mundo() + retraso
	_agotados[celda] = sello
	# MULTIJUGADOR: NO se escribe en mazmorra_persistente (que va al SAVE). Estas jugando en el
	# mundo del HOST: agotar una veta aqui no debe dejar sellos en el mundo PROPIO de tu save.
	if Net.activo:
		return
	(Game.persistente_piso(_piso_construido)["agotados"] as Dictionary)[celda] = sello


# Los nodos AGOTADOS de este piso VIVO (celda -> sello de tiempo). La libreta del mapa los lee de
# aqui y no de Game.mazmorra_persistente, porque en sesion ese diccionario es del mundo PROPIO del
# invitado (marcar_agotado no lo toca en multi): leerlo pintaba vetas de otro mundo en este mapa.
func agotados_vivos() -> Dictionary:
	return _agotados


# Apunta como SEGURAS las zonas de esas celdas (ver _zonas_seguras). Se llama una sola vez por piso,
# desde _colocar_actores, que es quien sabe donde caen la boca y el fondo.
#
# GUARDA: un piso tiene que poder parir. Si al quitar estas salas quedaran menos de dos zonas con
# paredes propias, no se marca ninguna: mas vale un bicho junto a la escalera que un piso muerto.
# El descuento del jefe se hace a mano porque _sala_boss aun no esta decidido cuando corre esto.
func _marcar_seguras(celdas: Array) -> void:
	var candidatas: Array[int] = []
	for c in celdas:
		var idx: int = gen.zona_en(c)
		if idx >= 0 and not candidatas.has(idx):
			candidatas.append(idx)

	var paridoras: int = 0
	for i in range(gen.zonas.size()):
		if candidatas.has(i):
			continue
		if (gen.zonas[i]["celdas"] as Array).is_empty() or gen.celdas_de_parto(i).is_empty():
			continue
		paridoras += 1
	if Game.BOSSES.has(_piso_construido):
		paridoras -= 1   # la sala central se la queda el jefe y tampoco pare

	if paridoras < 2:
		print("[mazmorra] piso ", _piso_construido, " demasiado pequeño para salas seguras (quedarian ",
			paridoras, " zonas paridoras): se dejan normales")
		return
	_zonas_seguras = candidatas
	print("[mazmorra] salas seguras (sin spawn): zonas ", _zonas_seguras)


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

	# El ritmo de los partos de ESTE piso: cuanto mas hondo, mas seguido pare la pared (ver
	# _factor_spawn_piso). Es el mismo para todas las zonas, asi que se calcula una vez.
	var ritmo: float = _factor_spawn_piso()

	for i in range(gen.zonas.size()):
		var z: Dictionary = gen.zonas[i]
		var celdas: Array = z["celdas"]
		var partos: Array = gen.celdas_de_parto(i)
		if celdas.is_empty() or partos.is_empty():
			continue  # una zona sin paredes propias no puede parir nada

		# La sala del BOSS no pare NADA: el rey slime pelea solo, sin escolta que se te eche
		# encima mientras lo tienes a media vida.
		#
		# Y las SALAS SEGURAS tampoco: las de las puertas del piso (boca, bajada y salida al pueblo)
		# son zona franca. Al no crearles zona se van de una vez del reparto de poblacion, de los
		# partos, de los brotes (provocar_brote recorre _zonas) y de las migraciones de manada
		# (aforo_de_zona da 0 para una zona que no existe). Ver _zonas_seguras.
		#
		# La sala del ESTANQUE entra en el mismo saco por la misma puerta: pescar es pararse quieto
		# un buen rato mirando el agua, y una pared pariendo detras -aunque fuese despacio- convertia
		# eso en una loteria. Ver el comentario de _zona_estanque.
		if i == _sala_boss or _zonas_seguras.has(i) or i == _zona_estanque:
			continue

		var es_sala: bool = z["tipo"] == "sala"
		var zona = _zone_script.new()
		zona.piso = self
		zona.zona_idx = i
		zona.tipo = z["tipo"]
		zona.partos = partos
		# Se DIVIDE porque son segundos de ESPERA: mas ritmo = menos espera entre partos.
		zona.intervalo_min = intervalo_min / ritmo
		zona.intervalo_max = intervalo_max / ritmo
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
		# El AGUA se cae de la lista: un destino dentro del charco (o pegado a el) deja al bicho
		# empujando contra la colision hasta que el anti-atasco lo manda a casa, y desde fuera parece
		# que se ha metido en el estanque. Filtrar AQUI y no en Enemy vale para los dos caminos que
		# leen esta lista (merodeo normal y unirse_a, que la copia tal cual) y no cuesta nada en vivo.
		# Si una zona fuese TODA agua nos quedariamos sin puntos, asi que hay red de seguridad.
		var pts: Array = []
		var pts_secos: Array = []
		for c in celdas:
			var px: Vector2 = gen.centro_px(c)
			pts.append(px)
			if not celda_en_estanque(c):
				pts_secos.append(px)
		zona.puntos = pts_secos if not pts_secos.is_empty() else pts
		zona.hogar = _centro_pisable(pts)
		_zonas.add_child(zona)

	# MULTIJUGADOR (hito 5.2): el DUEÑO del piso puebla/restaura como en solitario (y replica sus
	# bichos por Net). Quien solo lo espeja no puebla NADA en local (recrearia bichos rancios de
	# expediciones viejas de ESTA maquina). En sesion, la memoria que se restaura la siembra Net
	# con la FOTO del piso (ver Net._viaje_ok), asi que 'recordado' ya sale bien.
	# hay_sitio() ya corta, pero saltarselo ahorra el trabajo entero.
	# LOS SPRITES, ANTES DE QUE NAZCA NADIE. Generarlos cuesta de 0,2 a 1,2 s por tipo, y se pagaba
	# en el _ready del bicho: o sea la primera vez que una pared paria un jabali, en mitad de la
	# partida, se congelaba el juego casi un segundo -- y un BROTE de cinco podia irse a mas de uno.
	# Aqui el tiron cae donde ya se espera, montando el piso, y ademas solo la PRIMERA vez que sale
	# cada tipo en toda la sesion: el cache es estatico (ver SpritesEnemigo.precalentar).
	#
	# Va tambien cuando el piso viene RECORDADO: los bichos restaurados necesitan su sprite igual.
	_precalentar_sprites()

	var simulo_bichos: bool = Net.simulo_mi_piso()
	if not recordado and simulo_bichos:
		_poblar_el_piso(zona_entrada)

	# DIFERIDO igual que poblar: durante _ready el nodo padre aun se esta montando y Godot
	# rechaza los add_child (los bichos no llegarian a entrar en la escena).
	if recordado and simulo_bichos:
		call_deferred("_restaurar_estado")
	call_deferred("_log_poblacion", recordado)


# Deja generados los sprites de TODO lo que puede salir en este piso, jefe incluido.
#
# La lista sale de la propia tabla de spawns (aplanar ya resuelve las familias anidadas), asi que no
# hay una segunda lista que mantener: si mañana entra un bicho nuevo en la tabla, se precalienta
# solo. Lo que no tiene generador (los que aun son un ColorRect) no cuesta nada.
func _precalentar_sprites() -> void:
	var datas: Array = []
	if spawn_table != null:
		for e in spawn_table.aplanar(Game.current_floor):
			datas.append(e["data"])
	# El jefe va aparte: no esta en la tabla de partos, y es justo el mas caro de generar.
	var jefe: EnemyData = Game.boss_del_piso(Game.current_floor)
	if jefe != null:
		datas.append(jefe)
	if datas.is_empty():
		return
	var ms: int = SpritesEnemigo.precalentar(datas)
	if ms > 0:
		print("[mazmorra] sprites listos para el piso ", Game.current_floor, ": ",
			datas.size(), " tipos en ", ms, " ms")


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
				# Si era MUTANTE. Por lo mismo que la 't': sin guardarlo, el mini-jefe del que te
				# escapaste vuelve convertido en un bicho normal (o uno normal en mini-jefe) por el
				# mero hecho de subir y bajar la escalera.
				"mut": bool(e.get("mutante")),
				"muerto": grupo == "corpse",
				# Las HERIDAS que le dejaste al huir. Sin esto, subir y bajar la escalera curaba
				# del todo al bicho del que acababas de escapar a duras penas.
				"hp": float(e.hp_restante) if "hp_restante" in e else -1.0,
				# CUANDO se pudre este cuerpo (ver Enemy.CADAVER_SEGUNDOS). Sin guardarlo, subir y
				# bajar la escalera le reiniciaba los 5 minutos y los cadaveres volvian a ser eternos
				# para cualquiera que cambie de piso a menudo.
				"pudre": float(e.sello_pudre) if "sello_pudre" in e else -1.0,
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
		# zona < 0 = la foto no sabe de que sala era (la rehizo un espejo tras caerse su dueño,
		# ver Net._foto_de_mis_espejos): se le busca la mas cercana, o la sala no lo contaria en su
		# aforo y pariria bichos de mas encima de los que ya estan.
		var zona = _zona(int(d["zona"]))
		if zona == null and int(d["zona"]) < 0:
			zona = _zona_mas_cercana(d["pos"])
		var radio: float = zona.wander_radius if zona != null else 90.0
		# La mutacion vuelve IMPUESTA (1/0) y no a dados: si no, cada vuelta al piso re-sortearia
		# quien es mini-jefe. Las fotos viejas no la traen -> 0, o sea bicho normal.
		# Que el boss siga siendo el boss al volver al piso: si no, se lo llevaria el reciclador
		# y su muerte no abriria nada. Va COMO PARAMETRO (antes se asignaba despues) porque su
		# _ready lo necesita para saber cuanto agrandarlo si venia mutado.
		var era_boss: bool = data_boss != null and d["data"] == data_boss
		# El jefe no tiene zona (su sala se excluye del spawn a proposito), asi que sin esto se
		# quedaba con el radio de respaldo y volvia del piso anterior merodeando distinto.
		if era_boss and _boss_radio > 0.0:
			radio = _boss_radio
		var e = crear_enemigo(d["data"], d["pos"], radio, float(d["t"]),
			1 if bool(d.get("mut", false)) else 0, era_boss)
		if e == null:
			continue
		e.zona_idx = int(d["zona"])
		# Vuelve con las heridas que le dejaste (los saves viejos no lo traen -> -1 = intacto).
		e.hp_restante = float(d.get("hp", -1.0))
		if bool(d["muerto"]):
			# El sello va ANTES de morir(): morir() solo lo pone si venia a -1, justo para que
			# revivir un cadaver de la foto no le regale otros cinco minutos. Saves viejos -> -1, y
			# entonces morir() se lo pone ahora (empiezan a contar desde que vuelves, no se quedan).
			e.sello_pudre = float(d.get("pudre", -1.0))
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


# La zona cuyo centro cae mas cerca de 'pos' (null si no hay zonas). Solo para restaurar bichos de
# una foto que no trae zona; el resto del codigo usa el indice, que es exacto.
func _zona_mas_cercana(pos: Vector2):
	if _zonas == null:
		return null
	var mejor = null
	var mejor_d: float = INF
	for hijo in _zonas.get_children():
		var d: float = hijo.global_position.distance_squared_to(pos)
		if d < mejor_d:
			mejor_d = d
			mejor = hijo
	return mejor


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
		# Los ESPEJOS tampoco: no son mios. Borrarlos aqui haria desaparecer de mi pantalla un bicho
		# que sigue vivisimo en la maquina que simula el piso.
		if e.has_meta("es_espejo"):
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
func crear_enemigo(data: EnemyData, pos: Vector2, radio: float, t: float = -1.0, mut: int = -1,
		boss: bool = false):
	if data == null:
		return null
	var e = _enemy_scene.instantiate()
	e.data = data
	e.wander_radius = radio
	# LA BANDERA DE JEFE VA AQUI, antes de add_child, y no despues como estaba: su _ready la
	# necesita para saber cuanto agrandarlo si le ha tocado mutar (un jefe mutante se agranda menos,
	# ver EnemyData.mult_mutante). Y de paso Net.registrar_enemigo, que se llama ahi abajo, ya la
	# manda puesta en el alta.
	e.es_boss = boss
	# DE QUE PISO ES. Se lo lleva puesto porque Game.current_floor es donde esta el JUGADOR y los dos
	# se desacompasan (ver el comentario de _colocar_boss, y enemy.piso_nacido). Al jefe le importa de
	# verdad: es con este numero con el que sella su cuenta atras al morir.
	e.piso_nacido = _piso_construido
	# 't' impuesta (restaurando el piso): el bicho vuelve con las MISMAS stats que tenia.
	# Va antes de add_child porque su _ready es quien la lee.
	e.t_forzada = t
	# Lo mismo con la MUTACION (-1 = que la tire el, que es lo normal): el jefe la trae apagada y
	# un piso restaurado trae la que tenia. Va antes de add_child por lo mismo, y ademas antes de
	# Net.registrar_enemigo, que la manda ya resuelta al otro lado.
	e.mut_forzada = mut
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
	_repoblar_boss(delta)

	_t_barrido -= delta
	if _t_barrido > 0.0:
		return
	_t_barrido = BARRIDO_CADA

	_pudrir_cadaveres()

	var player := get_tree().get_first_node_in_group("player")
	if not (player is Node2D):
		return
	var pj: Vector2 = (player as Node2D).global_position

	# NIEBLA del mapa: la zona que pisas queda vista para siempre. Va con MI posicion a proposito: el
	# mapa es mi libreta, no la de mi compañero. En sesion se apunta en la libreta del mundo del HOST y
	# NO en mi save (vistas_de_piso decide donde); antes se colaba en mazmorra_persistente incluso en
	# multi, y el save del invitado se iba llenando de niebla de un mundo ajeno.
	if gen != null:
		var celda: Vector2i = Vector2i((pj / DungeonGenerator.CELDA).floor())
		var z: int = gen.zona_en(celda)
		if z >= 0:
			Game.vistas_de_piso(_piso_construido)[z] = true

	# MULTIJUGADOR (hito 5.4): el congelado se mide contra el aliado MAS CERCANO, no solo contra mi.
	# Yo simulo el piso para TODOS, asi que medir solo desde mi cuerpo dejaba dormidos a los bichos
	# que rodean a mi compañero: no lo perseguirian ni podrian saltarle encima nunca.
	var referencias: Array[Vector2] = [pj]
	for a in get_tree().get_nodes_in_group("aliado"):
		if is_instance_valid(a) and a is Node2D:
			referencias.append((a as Node2D).global_position)

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
		var pos_e: Vector2 = (e as Node2D).global_position
		var lejos: bool = true
		for r in referencias:
			if r.distance_to(pos_e) <= dist_congelar:
				lejos = false
				break
		e.set_physics_process(not lejos)


# Los cadaveres a los que se les paso el arroz se van solos (ver Enemy.CADAVER_SEGUNDOS). Va aqui y
# no en el propio bicho porque morir() le apaga el _physics_process: un cadaver no tiene bucle.
#
# MULTIJUGADOR: lo decide el DUEÑO del piso y punto. El espejo no cuenta cadaveres por su cuenta —su
# reloj de expedicion es otro y se irian en momentos distintos—; se entera porque desvanecer() acaba
# en queue_free() y el _exit_tree del bicho ya llama a Net.baja_enemigo, que difunde el despawn.
func _pudrir_cadaveres() -> void:
	if not Net.simulo_mi_piso():
		return
	for c in get_tree().get_nodes_in_group("corpse"):
		if not is_instance_valid(c) or c.has_meta("es_espejo"):
			continue
		if not ("sello_pudre" in c):
			continue
		var sello: float = float(c.sello_pudre)
		if sello < 0.0 or Game.tiempo_mazmorra < sello:
			continue
		# El BOSS no se pudre: su cuerpo es el hito que dice que el piso esta abierto, y su vuelta la
		# lleva su propio reloj (Game.BOSS_RESPAWN), no este.
		if c.get("es_boss"):
			continue
		c.desvanecer()


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


# MULTIJUGADOR: pinta el AVISO de un parto/brote que esta pariendo OTRA maquina. El que solo espeja el
# piso no tiene zonas activas (SpawnZone muere en piso.hay_sitio, que corta si no eres el dueño), asi
# que veia salir los bichos de la pared SIN el temblor de aviso: un susto gratis en vez de la decision
# de quedarse o largarse, que es justo la mecanica. Solo es FX, sin autoridad ni estado: si se pierde
# un paquete no pasa nada. Cuelga de _geo para morir con el piso, como todo lo demas de aqui.
# Lo llama Net._pintar_brote; el nacimiento de los bichos sigue viniendo replicado por su via de siempre.
# ============================================================
#  LA PIEDRA QUE TIEMBLA: registro de lo que esta en obras
# ============================================================
# Un WallBirthFx se LLEVA PRESTADAS unas celdas del TileMapLayer mientras tiemblan y las devuelve al
# terminar. Si dos partos cogieran la MISMA celda, el segundo la tomaria prestada ya vacia y el
# primero la devolveria al acabar: la pared se quedaria con un agujero permanente. Este registro es
# lo que lo impide, y por eso lo consulta quien elige donde parir (SpawnZone._elegir_celda).
var _celdas_rotas: Dictionary = {}

func celda_rota(c: Vector2i) -> bool:
	return _celdas_rotas.has(c)


# ¿Hay algo pintado en esa celda, sea muro o suelo? Lo pregunta la GRIETA para saber por donde puede
# correr: una pared que revienta se raja tambien hacia el SUELO de delante y hacia las paredes de al
# lado, asi que no se le puede atar a las celdas que estallan. Lo unico que no puede es dibujarse
# sobre el vacio, que ahi no hay nada que partir.
func celda_pintada(c: Vector2i) -> bool:
	for capa in ["muro", "suelo"]:
		var tml: TileMapLayer = _tm.get(capa, null)
		if tml != null and tml.get_cell_source_id(c) >= 0:
			return true
	return false


func soltar_celdas_rotas(celdas: Array) -> void:
	for c in celdas:
		_celdas_rotas.erase(c)


# Lo mismo al reves. Lo usa el aviso para apuntar su HALO (las celdas de al lado, que tiemblan un
# poco): tambien estan prestadas mientras dura, asi que otro parto no puede cogerlas.
func marcar_celdas_rotas(celdas: Array) -> void:
	for c in celdas:
		_celdas_rotas[c] = true


# De pixeles del mundo a celda. floor() y no int(): con coordenadas negativas int() trunca hacia
# cero y la celda sale corrida (misma nota que en _anunciar_boss).
func celda_de_px(px: Vector2) -> Vector2i:
	var lado: float = float(DungeonGenerator.CELDA)
	return Vector2i(int(floor(px.x / lado)), int(floor(px.y / lado)))


# Le presta al aviso las celdas de la capa que le toque y las apunta como "en obras". Es el embudo
# por el que pasan los TRES caminos (el brote de la zona, el parto del jefe y el aviso replicado por
# red), asi que ninguno se puede saltar el registro.
#
# Devuelve false si no ha podido, y entonces quien llama se cae al aviso de color de siempre.
func montar_aviso(fx: Node, celdas: Array, dur: float, amp: float, col: Color) -> bool:
	if celdas.is_empty():
		return false
	# LA CAPA: si esas celdas son pared, la del muro; si no (el jefe sale del suelo de su sala), la
	# del suelo. Se decide mirando donde hay baldosa de verdad, no adivinando por quien llama.
	var muro: TileMapLayer = _tm.get("muro", null)
	var suelo: TileMapLayer = _tm.get("suelo", null)
	var capa: TileMapLayer = null
	var libres: Array = []
	for c in celdas:
		var cel: Vector2i = c as Vector2i
		if _celdas_rotas.has(cel):
			continue   # ya la tiene otro parto: esa no
		var en_muro: bool = muro != null and muro.get_cell_source_id(cel) >= 0
		var la_suya: TileMapLayer = muro if en_muro else suelo
		if la_suya == null or la_suya.get_cell_source_id(cel) < 0:
			continue
		# TODAS DE LA MISMA CAPA. Un tramo a caballo entre muro y suelo tendria que prestar de dos
		# TileMapLayer a la vez y devolverlas a cada uno: manda la primera y las que no casen se
		# quedan fuera, que como mucho cuesta una celda sin temblar.
		if capa == null:
			capa = la_suya
		elif capa != la_suya:
			continue
		libres.append(cel)
	if capa == null or libres.is_empty():
		return false
	# Si lo que revienta es MURO o SUELO. El aviso lo necesita para el boquete: el suelo se ve cenital
	# y siempre lleva agujero, la pared solo si te enseña la cara (ver WallBirthFx._caras_de).
	if not fx.iniciar_capa(self, capa, libres, float(DungeonGenerator.CELDA), dur, amp, col,
			capa == muro):
		return false
	for c in libres:
		_celdas_rotas[c] = true
	return true


func pintar_aviso_pared(paredes_px: Array, dur: float, amp: float, col: Color) -> void:
	if paredes_px.is_empty() or _geo == null or not is_instance_valid(_geo):
		return
	var fx = _fx_pared_script.new()
	fx.position = paredes_px[0]
	_geo.add_child(fx)
	fx.iniciar_tramo(float(DungeonGenerator.CELDA), dur, amp, col, paredes_px)
	# El espejo no tiene reloj de parto: el aviso se borra solo cuando se cumple su duracion.
	fx.borrarse_al_acabar(dur)
