# ============================================================
#  save_data.gd
#  UNA PARTIDA GUARDADA. Es un Resource a proposito, no un JSON: asi lo serializa GODOT,
#  y eso resuelve gratis el problema gordo de este juego.
#
#  El estado esta lleno de Resources de dos clases distintas:
#    - Los .tres del proyecto (una AbilityData, un EnemyData): Godot los guarda como una
#      REFERENCIA a su ruta. Ocupan nada y al cargar apuntan al mismo fichero.
#    - Los duplicados de RUNTIME (tu espada +2, que sale de crear_item() -> base.duplicate();
#      un Cristal que acabas de extraer): Godot los INCRUSTA enteros en el fichero.
#  Y, lo mas importante: mantiene la IDENTIDAD COMPARTIDA. Tu arma equipada y esa misma arma
#  en el baul son EL MISMO objeto; al cargar lo siguen siendo. Un serializador JSON a mano
#  tendria que reimplementar todo eso, y habria que retocarlo cada vez que se le añada un
#  campo a WeaponData.
#
#  OJO con los diccionarios indexados por Resource (item_meta, consumables): no me fio de que
#  sobrevivan a la ida y vuelta como CLAVES, asi que se guardan "desmontados" en arrays
#  paralelos y Game los rearma al cargar (ver Game.exportar_partida / importar_partida).
# ============================================================

extends Resource
class_name SaveData

# Si algun dia cambia la estructura, esto evita cargar a medias una partida vieja y dejar el
# juego en un estado imposible: se avisa y se ignora la ranura.
# v2: los materiales dejan de ser el MonsterDrop pobre (un String y una calidad) y pasan a
# ser MaterialItem (plantilla + calidad, con familia y tipo). Una partida v1 lleva dentro
# objetos de una clase que ya no existe: no se puede convertir, se ignora la ranura.
const VERSION_ACTUAL := 2
@export var version: int = VERSION_ACTUAL

# --- Cabecera: lo que se pinta en la lista de ranuras SIN tener que adivinar nada ---
# El nombre y el color los ELIGE el jugador al crear la partida (ver main_menu.gd). El color
# tiñe su cuerpo por el mapa (el ColorRect de player.tscn). Son de la PARTIDA, no del perfil:
# cada ranura es un personaje distinto. Un @export nuevo con default NO invalida las partidas
# viejas (Godot rellena el default), asi que esto no toca VERSION_ACTUAL.
@export var nombre: String = "Aventurero"
@export var color: Color = Color(1, 1, 1)
# Acabado METALICO del cuerpo (0 = mate, 1 = pulido). Lo pinta shaders/metal.gdshader.
@export var metalico: float = 0.0
@export var fecha: String = ""          # "12/07/2026 20:31"
@export var cab_nivel: int = 1
@export var cab_piso: int = 1
@export var cab_dinero: int = 0
@export var cab_lugar: String = "Pueblo"

# --- El MUNDO de esta partida ---
# La semilla vive AQUI y no en el perfil: cada partida estrena mazmorra, asi que dos ranuras
# distintas tienen mapas distintos.
@export var semilla_mundo: int = 0

# --- Personaje ---
# ability_internal es la FUENTE DE VERDAD de las stats (las player_* se derivan de ella con
# Game.actualizar_estado()). Guardar solo las visibles perderia el progreso a medio cocer.
@export var ability_internal: Dictionary = {}
@export var player_level: int = 1
@export var player_current_hp: float = -1.0
@export var player_current_mp: float = -1.0
@export var stamina: float = -1.0
@export var money: int = 0
# MEZCLA (調合): parametro oculto que sube al craftear pociones (futura habilidad de
# desarrollo estilo DanMachi que mejorara la calidad al crear objetos). Ver Game.mezcla_exp.
@export var mezcla_exp: float = 0.0
# METALURGIA / HERRERIA: los otros dos contadores ocultos, que suben fundiendo y forjando en
# el herrero. Como la Mezcla: hoy solo se acumulan; seran lo que desbloquee la habilidad de
# desarrollo al subir de nivel. Ver Game.metalurgia_exp / herreria_exp.
@export var metalurgia_exp: float = 0.0
@export var peleteria_exp: float = 0.0
@export var herreria_exp: float = 0.0
# PACK INICIAL de la tienda (arma gratis + pociones): una sola vez por partida. Un @export
# nuevo con valor por defecto NO invalida las partidas viejas (Godot rellena el default), asi
# que esto no toca VERSION_ACTUAL: una partida de antes de la tienda arranca sin reclamar.
@export var pack_inicial: bool = false
# BOSSES ya derrotados ({piso: true}). Es un HITO de la partida, no del piso: memoria_pisos se
# borra en cada expedicion, pero lo que abre un boss (bajada, salida y atajo) no se pierde.
@export var bosses_derrotados: Dictionary = {}

# --- Cosas ---
@export var crystals: Array = []            # Cristal (runtime -> se incrustan)
@export var materiales: Array = []          # MaterialItem de la BOLSA (runtime)
@export var almacen_materiales: Array = []  # MaterialItem guardados en el Hogar
@export var owned_weapons: Array = []       # baul (instancias propias, con su identidad)
@export var owned_armor: Array = []
# MOCHILAS: van aparte del equipo de combate (tienen su propio slot y solo suben la carga).
@export var owned_mochilas: Array = []
@export var equipped_mochila: Resource = null

# Equipo puesto. Son referencias a objetos que TAMBIEN estan en el baul: Godot conserva que
# sean el mismo, que es justo lo que hace que mejorar el arma equipada mejore la del baul.
@export var equipped_main: Resource = null
@export var equipped_off: Resource = null
@export var equipped_casco: Resource = null
@export var equipped_pecho: Resource = null
@export var equipped_manos: Resource = null
@export var equipped_pantalones: Resource = null
@export var equipped_botas: Resource = null
@export var equip_meta: Dictionary = {}

# item_meta DESMONTADO: dos arrays en paralelo (item[i] <-> meta[i]).
@export var meta_items: Array = []
@export var meta_datos: Array = []

# Consumibles: {ruta del .tres -> cantidad}. Son ficheros del proyecto, asi que basta la ruta.
@export var consumibles: Dictionary = {}

@export var equipped_spells: Array = []     # .tres de hechizos (referencias)
@export var tool_hit_reduction: int = 0
@export var tool_destreza_bonus: int = 0

# Herramientas de recoleccion. Son .tres del proyecto (no instancias con identidad propia,
# como las armas), asi que basta su RUTA: igual que los consumibles.
@export var pico: String = ""
@export var hoz: String = ""
@export var hacha: String = ""

# Que materiales has visto alguna vez (id -> true). Es lo que decide QUE te enseña el herrero:
# un metal que no conoces no aparece en su menu. Ver Game.materiales_vistos.
@export var materiales_vistos: Dictionary = {}

# --- Donde estabas ---
@export var en_mazmorra: bool = false
@export var current_floor: int = 1
@export var pos_jugador: Vector2 = Vector2.ZERO

# --- La mazmorra tal y como la dejaste ---
# Mismo formato que Game.memoria_pisos: piso -> {"enemigos": [...], "suelo": [...]}. Incluye
# el piso en el que estas AHORA (Game se encarga de pedirle al DungeonFloor que se vuelque
# antes de guardar; si no, guardarias vacio el piso que estas pisando).
@export var memoria_pisos: Dictionary = {}

# Estado PERSISTENTE de la mazmorra (piso -> {agotados, zonas_vistas}) y el reloj de expedicion.
# A diferencia de memoria_pisos, duran mas que una expedicion: los nodos agotados (con su
# sello de tiempo para el respawn) y las zonas exploradas (niebla del mapa). Las partidas
# viejas los rellenan a vacio/0, asi que NO hace falta subir VERSION_ACTUAL.
@export var mazmorra_persistente: Dictionary = {}
@export var tiempo_mazmorra: float = 0.0


# Resumen de una linea para la lista de ranuras.
func resumen() -> String:
	return "%s  ·  Nv.%d  ·  %s  ·  %d monedas  ·  %s" % [
		nombre, cab_nivel, cab_lugar, cab_dinero, fecha]
