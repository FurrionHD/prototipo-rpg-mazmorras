# ============================================================
#  identity.gd  (AUTOLOAD: se llama "Identidad")
#  QUIEN ERES TU, la persona que esta delante del teclado. No un personaje ni una partida: la
#  MAQUINA/JUGADOR. Vive en user://identidad.cfg y sobrevive a todo lo demas.
#
#  Existe por una razon concreta: en un MUNDO COMPARTIDO los personajes viven dentro del save del
#  mundo, y el mundo lo puede abrir cualquiera de los dos. Asi que cada personaje tiene que
#  recordar DE QUIEN es, y eso necesita un nombre estable para la persona. Lo que habia no servia:
#    - `multiplayer.get_unique_id()` se reasigna en CADA conexion (hoy eres el 2, mañana el 5),
#    - `Game.player_nombre` es un String que el jugador cambia cuando quiere,
#    - `Perfil.ranura_actual` es un 1-3 de tu disco que no significa nada en la otra maquina.
#
#  El ID NO SE ATA AL HARDWARE (nada de OS.get_unique_id()): cambia al reinstalar Windows o al
#  mover el juego a otro PC, y perder tu personaje por reinstalar el sistema es mucho peor que el
#  problema que resolveria. Es un numero aleatorio nuestro, y punto.
#
#  QUE PASA SI COPIAS LA CARPETA a otro PC: se va tu id contigo, o sea que las dos maquinas
#  reclaman el mismo personaje. Se acepta a proposito (es exactamente lo que pasa al copiar un
#  save, y suele ser lo que quieres: jugar tu personaje desde el portatil). Lo unico que hay que
#  cortar es el uso SIMULTANEO, y eso se corta en la sesion: dos peers con la misma identidad no
#  pueden estar conectados a la vez.
# ============================================================

extends Node

const RUTA := "user://identidad.cfg"
const SECCION := "jugador"

# Tu ID: 24 hex aleatorios. Se genera UNA VEZ y no cambia nunca mas.
var id: String = ""

# Tu nombre VISIBLE (el que ven tus compañeros en la lista de un mundo). Editable: cambiarlo NO te
# convierte en otra persona, solo te reetiqueta -- tus personajes siguen siendo tuyos porque van
# atados al id, no al nombre.
var nombre: String = ""

# La direccion que publica ESTA maquina al abrir un mundo. El juego no puede adivinar cual de las
# direcciones que tienes es la de Hamachi (IP.get_local_addresses() las devuelve todas, incluidas
# las virtuales), asi que la eliges TU una vez y desde entonces se publica sola en cada apertura.
# Vacia = se publican todas las detectadas y que el cliente pruebe en orden.
var direccion_preferida: String = ""

# ¿Se acababa de estrenar la identidad en este arranque? Lo usa el menu para avisar de que esta
# maquina no se reconoce (ver la nota de la cabecera sobre el fichero borrado).
var recien_creada := false


func _ready() -> void:
	_cargar()


func _cargar() -> void:
	var cfg := ConfigFile.new()
	var err: int = cfg.load(RUTA)
	if err == OK:
		id = String(cfg.get_value(SECCION, "id", ""))
		nombre = String(cfg.get_value(SECCION, "nombre", ""))
		direccion_preferida = String(cfg.get_value(SECCION, "direccion", ""))
	elif err != ERR_FILE_NOT_FOUND:
		# Fichero corrupto o a medio escribir: se estrena identidad. Se avisa fuerte porque no es
		# inocuo -- los personajes que tengas en mundos compartidos quedan a nombre del id viejo.
		push_warning("[identidad] no se pudo leer %s (error %d): se estrena identidad" % [RUTA, err])

	if id.strip_edges() == "":
		id = _nuevo_id()
		recien_creada = true
	if nombre.strip_edges() == "":
		nombre = _nombre_por_defecto()
	_guardar()
	print("[identidad] ", nombre, " (", id, ")", "  [NUEVA]" if recien_creada else "")


func _guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECCION, "id", id)
	cfg.set_value(SECCION, "nombre", nombre)
	cfg.set_value(SECCION, "direccion", direccion_preferida)
	var err: int = cfg.save(RUTA)
	if err != OK:
		push_warning("[identidad] no se pudo guardar %s (error %d)" % [RUTA, err])


# Cambiarte el nombre visible. Devuelve el nombre que ha quedado (vacio no se acepta).
func poner_nombre(n: String) -> String:
	var limpio := n.strip_edges()
	if limpio == "":
		return nombre
	nombre = limpio
	_guardar()
	return nombre


func poner_direccion(ip: String) -> void:
	direccion_preferida = ip.strip_edges()
	_guardar()


# PEGAR UN ID A MANO. Es el unico plan B si se pierde el identidad.cfg: sin esto, un fichero
# borrado te separa para siempre de tus personajes en los mundos de otros. Por eso el menu tiene
# que ENSEÑAR el id, no solo usarlo.
func poner_id(nuevo: String) -> bool:
	var limpio := nuevo.strip_edges().to_lower()
	if not _id_valido(limpio):
		return false
	id = limpio
	recien_creada = false
	_guardar()
	print("[identidad] id cambiado a mano: ", id)
	return true


func _id_valido(s: String) -> bool:
	if s.length() != 24:
		return false
	for c in s:
		if not ("0123456789abcdef".contains(c)):
			return false
	return true


func _nuevo_id() -> String:
	# Sin semilla fija: la identidad tiene que ser distinta en cada maquina.
	randomize()
	var s := ""
	for i in 24:
		s += "0123456789abcdef"[randi() % 16]
	return s


func _nombre_por_defecto() -> String:
	if OS.has_environment("USERNAME"):
		var u := String(OS.get_environment("USERNAME")).strip_edges()
		if u != "":
			return u
	return "Jugador"
