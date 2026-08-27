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
# METALICO y COLOR_ALPHA son SOLO DE LA IMAGEN DE LA CARA. Nacieron cuando el cuerpo era un
# ColorRect de 32x32 y tiñendolo se pintaba al personaje entero; desde que hay capas, cada pieza
# lleva su propio color y su propio acabado dentro de `aspecto`, y estos dos se quedan con lo unico
# que no es una capa horneada: el PNG que te pones de cara.
@export var metalico: float = 0.0
@export var imagen: PackedByteArray = PackedByteArray()
@export var color_alpha: float = 1.0

# --- EL ASPECTO: que lleva puesto y de que color, PIEZA A PIEZA ---
# Formato: {"pelo": {"modelo": String, "color": Color, "metal": float}, "torso": {...}, ...}
# 'modelo' vacio = esa pieza no se lleva (calvo, torso desnudo). Las claves son las de PIEZAS y las
# resuelve JugadorSprites.capas_de para montar la pila de sprites.
#
# VA COMO UN SOLO CAMPO Y NO COMO DIEZ VARIABLES SUELTAS. El aspecto viaja por seis sitios (el save,
# ficha_a_dict de los mundos compartidos, tres RPC del saludo y nueva_partida) y hasta hoy lo hacia
# de una variable en una variable: cada pieza nueva eran seis firmas que tocar y seis oportunidades
# de dejarse una punta -- que es exactamente como se pierden cosas SOLO en multijugador.
#
# UN DICT VACIO ES LO NORMAL, NO UN FALLO: es lo que traen todas las partidas anteriores a esto. Por
# eso nadie lo lee a pelo y todo el mundo pasa por 'pieza()', que rellena lo que falte.
@export var aspecto: Dictionary = {}

# Las piezas que hay hoy, EN ORDEN DE APILADO (de abajo arriba). El arma y la armadura equipada
# entraran por su propio camino: no se eligen, se llevan puestas.
const PIEZAS := ["piernas", "torso", "pelo", "cara"]

# Con que nace un personaje a estrenar. El color de la ropa es EL SUYO -- es lo que hace que el
# color que eliges al crear la partida por fin se vea, ahora que la piel no se tiñe.
static func aspecto_nuevo(col: Color = Color(0.45, 0.72, 1.0)) -> Dictionary:
	return {
		"piernas": {"modelo": "pantalon", "color": col.darkened(0.35), "metal": 0.0},
		"torso": {"modelo": "camisa", "color": col, "metal": 0.0},
		"pelo": {"modelo": "corto", "color": Color(0.24, 0.15, 0.10), "metal": 0.0},
		# La cara no se tiñe (los ojos van en su color), pero lleva la misma forma que las demas para
		# que nadie tenga que saber cual es la excepcion.
		"cara": {"modelo": "chibi", "color": Color(1, 1, 1), "metal": 0.0},
	}


# UNA pieza del aspecto, siempre valida. Es la unica puerta de entrada: una partida vieja tiene el
# dict vacio y un personaje traido por red puede llegar a medias, asi que aqui se rellena lo que
# falte en vez de repartir 'get' con defaults por todo el proyecto.
func pieza(clave: String) -> Dictionary:
	var d: Dictionary = aspecto.get(clave, {})
	var base: Dictionary = aspecto_nuevo(color).get(clave, {})
	return {
		"modelo": String(d.get("modelo", base.get("modelo", ""))),
		"color": Color(d.get("color", base.get("color", color))),
		"metal": clampf(float(d.get("metal", base.get("metal", 0.0))), 0.0, 1.0),
	}


# Cambia una pieza sin pisar las demas. Lo usan el creador y la pantalla de aspecto del hogar.
func poner_pieza(clave: String, modelo: String, col: Color, metal: float = 0.0) -> void:
	if aspecto.is_empty():
		aspecto = aspecto_nuevo(color)
	aspecto[clave] = {"modelo": modelo, "color": col, "metal": clampf(metal, 0.0, 1.0)}


# ============================================================
#  EL ASPECTO COMPLETO: como viaja de una pantalla a otra
# ============================================================
# TODO lo que se ve de una persona en un solo dict: los cuatro campos de la cara y las piezas.
#
# Existe para que la pantalla de creacion, 'Game.nueva_partida', la taberna y la red hablen el MISMO
# idioma. Antes esto eran cuatro argumentos sueltos repetidos en siete firmas, y cada pieza nueva
# eran siete sitios que tocar -- que es como se pierde una punta y algo se ve solo en multijugador.
func aspecto_completo() -> Dictionary:
	var pz := {}
	for k in PIEZAS:
		pz[k] = pieza(k)
	return {"color": color, "metalico": metalico, "imagen": imagen,
		"color_alpha": color_alpha, "piezas": pz}


# Lo contrario. Lo que no venga se queda como esta: asi una pantalla puede tocar solo el pelo sin
# tener que reenviar la foto entera.
func aplicar_aspecto(d: Dictionary) -> void:
	if d.has("color"):
		color = d["color"]
	if d.has("metalico"):
		metalico = clampf(float(d["metalico"]), 0.0, 1.0)
	if d.has("color_alpha"):
		color_alpha = clampf(float(d["color_alpha"]), 0.0, 1.0)
	if d.has("imagen"):
		set_imagen(d["imagen"])
	var pz: Dictionary = d.get("piezas", {})
	if pz.is_empty():
		return
	if aspecto.is_empty():
		aspecto = aspecto_nuevo(color)
	for k in pz:
		if not PIEZAS.has(k):
			continue
		var p: Dictionary = pz[k]
		poner_pieza(String(k), String(p.get("modelo", "")),
			Color(p.get("color", color)), float(p.get("metal", 0.0)))
# ROL con el que salio de la taberna ("guerrero" | "tanque" | "mago"). No cambia nada mecanico:
# decide el kit inicial y el texto de la ficha. El jugador no tiene rol ("").
@export var rol: String = ""
# ¿Es EL personaje que creaste al empezar la partida? Solo uno lo lleva POR DUEÑO.
#
# YA NO ES INTOCABLE: se le puede dejar en casa como a cualquiera, y el cupo de sesion protege al que
# llevas EN CABEZA, no a este (si solo te cabe uno, ese uno lo eliges tu). Lo que sigue significando
# es "a quien se recurre cuando no queda nadie": si mandas a TODO el mundo al hogar, es el que baja
# solo al cerrar el menu (ver Game.lider()).
#
# Su flag viaja en el save por SaveData.player_es_original cuando este va en cabeza, y dentro de este
# @export cuando no. Game._sanear_originales() garantiza que solo haya uno por dueño.
@export var es_original: bool = false
# DE QUIEN ES este personaje, en un MUNDO COMPARTIDO: la identidad de la persona que lo creo
# (Identidad.id), no su nombre ni su peer_id. Vacio = partida de un jugador, o sea "del que juegue
# aqui" (es el caso de TODAS las partidas que ya existen, y por eso el default es "").
# El dueño se guarda tambien aqui, y no solo en la clave de SaveData.jugadores, porque el mundo lo
# puede abrir cualquiera: al preguntar "¿este personaje es mio?" no hay que recorrer el diccionario,
# y si alguna vez se descuadrara se puede recomponer desde los propios personajes.
# es_original sigue significando lo mismo, pero pasa a ser UNO POR DUEÑO: el personaje con el que
# ESA persona empezo en este mundo.
@export var dueno: String = ""
# IDENTIFICADOR ESTABLE de esta persona. Nace con ella y no cambia nunca: ni al renombrarla, ni al
# reordenar el equipo, ni al viajar por la red.
#
# Hace falta porque hay cosas que apuntan a un personaje y le SOBREVIVEN a la vuelta por red: un
# ENCARGO se manda hoy y se recoge dentro de ocho horas, y cuando vuelve hay que darle la excelia a
# quien la sudo. Apuntar por indice del array no vale: jd_de_dict RECONSTRUYE personajes/equipo en
# cada sincronizacion (cada 60 s) y _aplicar_cupo reordena party, asi que el indice 2 de ahora es
# otra persona dentro de un rato y las stats se las llevaria un tercero.
#
# Vacio en los saves viejos: lo rellena Game.asegurar_uids() al importar.
@export var uid: String = ""

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

# IMBUICION puesta (Filos y Mantos). Vacio = ninguna. Vive AQUI y no en el Combatant porque dura
# ENTRE combates: te echas el manto, sales de la pelea y sigues llevandolo puesto hasta que gastes
# sus cargas. Como las colas de pocion, NO es @export: aguanta la sesion pero no el guardado --
# volver a cargar la partida es empezar limpio.
# Formato: {"elem": int, "pct": float, "usos": int, "cuerpo": bool, "estado": int, "prob": float,
#           "intensidad": float}. Lo escribe Game.guardar_imbue_en_ficha y lo lee
# Game.crear_player_combatant, que se lo pasa tal cual a Combatant.aplicar_imbue.
var imbue: Dictionary = {}

# ESTADOS ALTERADOS que se lleva puestos FUERA del combate (veneno, Pegajoso, Fortaleza...). Antes
# morian con el Combatant al cerrar la pantalla: escapabas envenenado y salias limpio. Ahora salen
# de la pelea contigo y siguen corriendo por el mapa a Game.SEG_POR_TURNO_FUERA segundos por turno.
# Formato: una lista de dicts de StatusEffects.dict_de_instancia. SI se guardan (a diferencia del
# imbue y de las colas de pocion, que son de sesion): un plato de cocina dura 20 minutos y cuesta
# ingredientes, asi que evaporarse al guardar y salir seria un robo. Al LIDER no le vale con esto —
# no viaja como PersonajeData sino en los campos planos del save (SaveData.player_estados).
@export var estados: Array = []
# Segundos acumulados hacia el proximo turno fuera de combate (ver Game.tick_estados).
@export var estados_reloj: float = 0.0
# Cuanto le FRENAN esos estados por el mapa (1.0 = nada), como se pintan sus chips en el HUD (texto
# plano y datos por chip) y cuanta carga extra le dan. Van CACHEADOS porque el mapa los pregunta en
# cada frame: los pone Game.refrescar_cache_estados cada vez que `estados` cambia, no al leerlos.
var estados_spd: float = 1.0
var estados_chip: String = ""
# Un elemento por chip: [etiqueta, tooltip, icono, color]. Mismo contenido que estados_chip pero sin
# aplastar a String, para poder pintar cada estado como un recuadro con su color (ver status_chip.gd).
var estados_chips: Array = []
var estados_mochila: float = 0.0
# MULTIPLICADOR DE HABILIDAD por estado (clave -> factor; vacio o 1.0 = nada). Es el "10% mas de
# Fuerza" del plato, y por el mapa hace falta en sitios que se leen constantemente (la vida maxima
# del HUD, la capacidad de carga, la dificultad de cada minijuego de recoleccion), asi que se cachea
# igual que los de arriba. Lo consumen Game.abilities_eff_de (dentro del combate) y
# Game.stat_consolidado_eff (fuera). NUNCA stat_total: el plato no toca el reto ni la excelia.
var estados_hab: Dictionary = {}
# SUERTE del plato de la fortuna: cuanto multiplica la probabilidad de drop, y que probabilidad hay
# de que la cantidad salga DOBLE. Lo lee Game._tirar_drop, que corre una vez por bicho muerto.
var estados_drop_mult: float = 1.0
var estados_drop_doble: float = 0.0

# CARGAS DE FOCO ARCANO. Van aparte de `estados` porque NO son un estado con duracion: son munición.
# No caducan con el tiempo -- solo las gasta lanzar un hechizo ofensivo (Combatant.consumir_foco),
# igual que las cargas de una imbuicion. Canalizas, sales de la pelea y siguen ahi.
var foco_cargas: int = 0


# El elemento de la imbuicion QUE SE VE, o NINGUNO. Vive aqui porque la pregunta es sobre esta
# ficha, y la hacen dos sitios distintos (el cuerpo del lider en player.gd y cada companero en
# companion.gd) que no se conocen entre si.
#
# Un imbue con 0 cargas NO cuenta: gastar la ultima es justo lo que hay que notar en pantalla.
func imbue_elemento() -> int:
	if imbue.is_empty() or int(imbue.get("usos", 0)) <= 0:
		return Elementos.Elemento.NINGUNO
	return int(imbue.get("elem", Elementos.Elemento.NINGUNO))

# --- Perks ---
@export var guardianes_vencidos: Dictionary = {}
@export var desarrollos_rango: Dictionary = {}
@export var pasivas_rng: Dictionary = {}
# Pasivas que YA te han tocado pero que aun no sabes que tienes: la tirada cae mientras juegas y se
# queda AQUI, callada y sin efecto, hasta que actualizas tu estado en el altar. Ahi se pasan a
# pasivas_rng y se te enseñan (ver Game.consolidar_pasivas). Es la misma idea que la excelia
# pendiente: lo que haces cuenta desde el minuto uno, pero no se lee hasta que alguien te lo lee.
@export var pasivas_pendientes: Dictionary = {}
# Contadores OCULTOS de los perks de COMBATE (los de OFICIO son del grupo y viven en Game).
@export var esquivas_exp: float = 0.0
@export var hechizos_exp: float = 0.0
@export var recitado_exp: float = 0.0
@export var dano_recibido_exp: float = 0.0
@export var dano_infligido_exp: float = 0.0
# El daño que has PARADO levantando la guardia (ver Game.contar_dano_bloqueado). Es el contador de
# la Autorregeneracion desde que dejo de ir por dano_recibido_exp, que premiaba justo lo contrario:
# cuanto mejor te defendias, mas despacio subia.
@export var dano_bloqueado_exp: float = 0.0

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
# --- HABILIDADES de arma: lo que SABE y lo que LLEVA PUESTO (ver Game.habilidades_equipadas) ---
# Las que le ha enseñado el maestro del pueblo (Array[AbilityData]). Las `inicial` NO estan aqui:
# esas se saben siempre, vengan con el arma que vengan. Es POR PERSONAJE: cada compañero paga
# las suyas.
@export var habilidades_aprendidas: Array = []
# Su set de MAX_HABILIDADES por TIPO DE ARMA: {int(WeaponData.Tipo) -> Array[AbilityData]}.
# La clave es el TIPO y no el arma concreta, y de ahi salen las dos reglas de golpe: cambiar de
# arma te pone el set de la nueva (clave distinta, todavia sin entrada -> se autorrellena), y la
# MISMA arma de otro tier o mejorada te conserva el tuyo (misma clave). Sin codigo de reseteo.
@export var loadout_habilidades: Dictionary = {}
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
	pasivas_pendientes = {}
	equipped_spells = []
	habilidades_aprendidas = []
	loadout_habilidades = {}
	equip_meta = meta_vacia()
	aspecto = aspecto_nuevo(color)


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
