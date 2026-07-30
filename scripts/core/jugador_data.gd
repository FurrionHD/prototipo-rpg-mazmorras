# ============================================================
#  jugador_data.gd  (class_name JugadorData)
#  TODO LO DE UNA PERSONA dentro de un mundo compartido: sus personajes y lo que es suyo y de nadie
#  mas (su dinero, su bolsa, sus oficios, donde se quedo). Un mundo guarda un JugadorData por cada
#  humano que ha jugado en el, indexado por su IDENTIDAD (Identidad.id) -- ver SaveData.jugadores.
#
#  ES UN RESOURCE Y NO UN DICCIONARIO, y esto es importante: el baul del mundo es COMPARTIDO, y el
#  arma que lleva puesta un personaje tiene que ser LA MISMA INSTANCIA que la del baul. Godot
#  conserva esa identidad dentro de un .tres (es el argumento entero de la cabecera de save_data.gd);
#  un diccionario serializado a mano la perderia y aparecerian armas duplicadas.
#
#  ⚠️ OJO A UNA DIFERENCIA CON SaveData: aqui las listas de personajes SI INCLUYEN al que va en
#  cabeza. En SaveData el lider vive desmontado en los campos planos (nombre, ability_internal,
#  equipped_main...) porque ahi solo hay UN humano; aqui hay varios y ninguno puede depender de esos
#  campos, asi que cada JugadorData es AUTONOMO: se entiende solo, sin mirar el resto del save.
# ============================================================

extends Resource
class_name JugadorData

# Quien es. El id es la llave (Identidad.id): un numero aleatorio de su maquina, NO su nombre (que
# cambia cuando quiere) ni su peer_id (que se reasigna en cada conexion).
@export var id: String = ""
@export var nombre_visible: String = ""

# --- SUS PERSONAJES (lider incluido, ver la nota de la cabecera) ---
# plantilla = todos los que ha contratado; equipo = los que bajan hoy, EN ORDEN; lider_pos = en que
# hueco del equipo va la cabeza.
@export var personajes: Array = []
@export var equipo: Array = []
@export var lider_pos: int = 0

# --- LO QUE ES SUYO Y DE NADIE MAS ---
# El dinero es PERSONAL a proposito (para compartir esta el bote del hogar), y la bolsa tambien: el
# peso que carga cada uno es su problema.
@export var dinero: int = 0
@export var crystals: Array = []
@export var materiales: Array = []
@export var consumibles: Dictionary = {}      # ruta del .tres de la pocion -> cuantas
@export var cebo: String = ""                 # el cebo puesto en el anzuelo ("" = a pelo)
@export var owned_mochilas: Array = []
@export var equipped_mochila: Resource = null
# HERRAMIENTAS. Van aqui por lo mismo que la mochila: son del jugador, no del mundo. Antes vivian
# solo en los campos planos del SaveData, y en un mundo compartido eso significaba que las
# herramientas del ULTIMO que guardaba pasaban a ser las de todos. Con las tres basicas identicas
# no se notaba; con un pico T3 de por medio, si.
@export var owned_tools: Array = []
@export var equipped_pico: Resource = null
@export var equipped_hoz: Resource = null
@export var equipped_hacha: Resource = null
@export var equipped_cana: Resource = null
# El LIBRO DEL PESCADOR: id del pez -> {capturas, cm_min, cm_max}. Es del jugador por el mismo
# motivo que las herramientas: el record de la lubina de 61 cm lo sacaste TU, no el mundo.
@export var registro_pesca: Dictionary = {}

# Los OFICIOS son suyos porque son lo que DESBLOQUEA sus desarrollos (que ya son por personaje, ver
# PersonajeData.desarrollos_rango): si fueran comunes, uno le regalaria habilidades al otro sin que
# el otro hubiera forjado nada.
@export var mezcla_exp: float = 0.0
@export var metalurgia_exp: float = 0.0
@export var peleteria_exp: float = 0.0
@export var herreria_exp: float = 0.0
# Lo que ha visto: decide que le enseña el herrero A EL. Es conocimiento suyo.
@export var materiales_vistos: Dictionary = {}
@export var pack_inicial: bool = false

# --- DONDE SE QUEDO ---
# Cada uno guarda SU sitio: si tu compañero le da a "Guardar y salir" en el piso 7, vuelve al piso 7.
# ⚠️ Un sitio dentro de la mazmorra solo vale mientras viva la expedicion a la que pertenece: si la
# mazmorra se cerro y se regenero entre medias, ese piso es de otro mapa y hay que devolverlo al
# pueblo DICIENDOLO (lo resuelve quien lo carga, no este recurso).
@export var en_mazmorra: bool = false
@export var current_floor: int = 1
@export var pos: Vector2 = Vector2.ZERO

@export var fecha_visto: String = ""


func resumen() -> String:
	var n: String = nombre_visible if nombre_visible != "" else "?"
	var pj: String = ""
	if not equipo.is_empty():
		var l = equipo[clampi(lider_pos, 0, equipo.size() - 1)]
		if l is PersonajeData:
			pj = "%s Nv.%d" % [(l as PersonajeData).nombre, (l as PersonajeData).level]
	return "%s (%s · %d monedas)" % [n, pj, dinero]
