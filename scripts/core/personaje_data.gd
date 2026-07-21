# ============================================================
#  personaje_data.gd
#  UN PERSONAJE del grupo: tu y los companeros que contratas en la taberna. Todo lo que
#  distingue a una persona de otra vive AQUI, y nada mas.
#
#  Hasta ahora el juego solo sabia de UNO: sus stats y su equipo eran variables sueltas del
#  autoload Game (player_fuerza, equipped_main...). Un companero necesita TODO eso propio, asi
#  que el estado se muda a este Resource y Game se queda con un ARRAY de ellos (Game.party).
#  Las viejas Game.player_* siguen existiendo como PROPIEDADES que delegan en el que va en
#  cabeza, para que las 5000 lineas de Game y los menus que ya las usaban sigan valiendo.
#
#  Lo que NO esta aqui es lo del GRUPO, que se comparte y por tanto se queda en Game: el
#  dinero, el baul (owned_weapons/armor/mochilas), la MOCHILA equipada, los materiales, los
#  cristales, los consumibles, las herramientas de recoleccion, los contadores de OFICIO,
#  item_meta y el mapa.
#  El baul es comun a proposito: asi un companero se pone tu espada vieja sin duplicar nada.
#
#  Es un Resource porque asi lo serializa Godot dentro del SaveData, con la misma ventaja que
#  explica save_data.gd: las armas equipadas mantienen su IDENTIDAD con las del baul.
# ============================================================

extends Resource
class_name PersonajeData

# --- Identidad y aspecto (lo que se ve por el mapa; ver Game.material_cuerpo) ---
@export var nombre: String = "Aventurero"
@export var color: Color = Color(1, 1, 1)
@export var metalico: float = 0.0
@export var imagen: PackedByteArray = PackedByteArray()
@export var color_alpha: float = 1.0
# ROL con el que salio de la taberna ("guerrero" | "tanque" | "mago"). No cambia nada mecanico:
# decide el kit inicial y el texto de la ficha. El jugador no tiene rol ("").
@export var rol: String = ""

# --- Progresion (ver los comentarios largos de game.gd: interno / consolidado / base_nivel) ---
@export var level: int = 1
@export var ability_internal: Dictionary = {}
@export var ability_consolidado: Dictionary = {}
@export var ability_base_nivel: Dictionary = {}
# Habilidades VISIBLES: se derivan de ability_consolidado al descansar en el altar.
@export var fuerza: int = 0
@export var resistencia: int = 0
@export var destreza: int = 0
@export var agilidad: int = 0
@export var magia: int = 0

# --- Bases que crecen al subir de nivel ---
@export var base_hp: float = 50.0
@export var base_attack: float = 5.0
@export var base_defense: float = 5.0
@export var base_magic: float = 5.0
@export var base_speed: float = 5.0
@export var base_mp: float = 20.0
@export var base_magia_factor: float = 1.0
@export var base_crit: float = 0.0

# --- Estado vivo (persiste entre combates; -1 = lleno / sin inicializar) ---
@export var current_hp: float = -1.0
@export var current_mp: float = -1.0
@export var stamina: float = -1.0   # aguante de exploracion: cada uno lleva el suyo

# CURA DE POCIÓN pendiente FUERA de combate (heal-over-time por tiempo real). Es de la PERSONA,
# no del que va en cabeza: si le das una poción a uno y luego cambias de lider, la cura sigue
# cayendo sobre QUIEN se la bebio. Game.tick_heal/tick_mana_pocion tiquean estas colas cada frame.
# NO son @export a proposito: una poción a medias no se guarda en la partida (igual que antes).
var heal_left: float = 0.0        # vida que queda por curar
var heal_rate: float = 0.0        # vida/seg a la que cae
var mana_heal_left: float = 0.0   # lo mismo para el maná
var mana_heal_rate: float = 0.0
# TURNOS de combate que le quedarian a esa cola. Los turnos de las pociones se SUMAN (dos de 3
# turnos = 6) y se van gastando a la vez que la cura: si has goteado el 20%, quedan el 80% de los
# turnos. Es lo que hace que entrar en combate con pociones a medias no las comprima en un
# curaton: la cola entra al MISMO ritmo por turno al que iba (ver Game._arrastre_a_combate).
var heal_turnos: float = 0.0
var mana_heal_turnos: float = 0.0

# --- Perks ---
@export var guardianes_vencidos: Dictionary = {}
@export var desarrollos_rango: Dictionary = {}
@export var pasivas_rng: Dictionary = {}
# Contadores OCULTOS de los perks de COMBATE (los de OFICIO son del grupo y viven en Game).
@export var esquivas_exp: float = 0.0
@export var hechizos_exp: float = 0.0
@export var recitado_exp: float = 0.0
@export var dano_recibido_exp: float = 0.0
@export var dano_infligido_exp: float = 0.0

# --- Equipo (instancias del baul comun; la misma que esta en Game.owned_*) ---
@export var equipped_main: Resource = null    # WeaponData | null (null = punos)
@export var equipped_off: Resource = null     # WeaponData | ShieldData | WandData | null
@export var equipped_casco: Resource = null
@export var equipped_pecho: Resource = null
@export var equipped_manos: Resource = null
@export var equipped_pantalones: Resource = null
@export var equipped_botas: Resource = null
# (La MOCHILA no esta aqui: es del GRUPO, como la bolsa. Vive en Game.mochila_equipo.)
@export var equipped_spells: Array = []
# tier + rareza + mejoras + durabilidad de lo que lleva PUESTO, por slot. Los dicts son los
# MISMOS objetos que Game.item_meta[item] (por referencia): mejorar lo equipado mejora lo del baul.
@export var equip_meta: Dictionary = {}

# Cache de la textura del cuerpo (no se guarda: se reconstruye del PNG). Ver textura().
var _tex: Texture2D = null


func _init() -> void:
	# Los diccionarios se rellenan AQUI y no en el default del @export: un literal en el default
	# de un Resource se comparte entre instancias, y dos personajes acabarian con el mismo dict.
	ability_internal = _cero_abilities()
	ability_consolidado = _cero_abilities()
	ability_base_nivel = _cero_abilities()
	guardianes_vencidos = {}
	desarrollos_rango = {}
	pasivas_rng = {}
	equipped_spells = []
	equip_meta = meta_vacia()


static func _cero_abilities() -> Dictionary:
	return {"fuerza": 0.0, "resistencia": 0.0, "destreza": 0.0, "agilidad": 0.0, "magia": 0.0}


# Los 7 slots con su meta por defecto (T1 / comun / sin mejoras / entera).
static func meta_vacia() -> Dictionary:
	var d: Dictionary = {}
	for slot in ["main", "off", "casco", "pecho", "manos", "pantalones", "botas"]:
		d[slot] = {"tier": 1, "rareza": 0, "mejoras": {}, "durabilidad": 1.0}
	return d


# La textura del cuerpo, o null si no lleva imagen (o si el PNG guardado esta corrupto: mejor un
# cuerpo de color plano que una partida que no arranca). Cacheada: decodificar el PNG en cada
# frame para pintar un cuadrado de 32 px seria absurdo.
func textura() -> Texture2D:
	if imagen.is_empty():
		return null
	if _tex == null:
		var img := Image.new()
		if img.load_png_from_buffer(imagen) == OK:
			_tex = ImageTexture.create_from_image(img)
		else:
			push_warning("[personaje] la imagen de %s no se puede leer: cuerpo de color plano" % nombre)
	return _tex


func set_imagen(png: PackedByteArray) -> void:
	imagen = png
	_tex = null   # la cache ya no vale
