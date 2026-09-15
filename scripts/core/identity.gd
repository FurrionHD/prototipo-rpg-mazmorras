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


# ============================================================
#  LAS IDENTIDADES QUE SE MULTIPLICABAN (15/09/2026)
#  En un mundo aparecieron TRES jugadores "dasui" distintos, cada uno con una copia de los personajes.
#  La causa: al abrir un mundo, el host lanza VARIOS trabajadores de pelea a la vez, y cada uno es el
#  juego entero arrancando -- con este autoload dentro. Antes esto REESCRIBIA identidad.cfg en cada
#  arranque aunque no hubiera cambiado nada, asi que dos procesos se pisaban: uno truncaba el fichero
#  para escribirlo y el otro lo leia a medias, lo daba por corrupto y ESTRENABA identidad (con el
#  nombre de Windows, porque el nombre tambien se habia perdido). La siguiente vez que abrias el juego
#  eras otra persona, y tus personajes se quedaban aparcados como "de otro jugador".
#
#  Las tres vallas, y hacen falta las tres:
#   1. Un TRABAJADOR no escribe nunca: no es nadie, solo simula pisos.
#   2. Solo se escribe si algo ha cambiado (el arranque normal ya no toca el fichero), y se escribe a
#      un TEMPORAL que luego se renombra: nadie puede leer medio fichero.
#   3. Si leerlo falla, se REINTENTA un rato antes de rendirse, y un fichero ilegible NO se pisa: se
#      aparta a un lado para poder recuperar el id a mano (ver poner_id).
# ============================================================
const REINTENTOS_LECTURA := 20
const ESPERA_REINTENTO_MS := 25

func _cargar() -> void:
	var solo_leer: bool = OS.get_cmdline_user_args().has("trabajador")
	var cfg := ConfigFile.new()
	var err: int = cfg.load(RUTA)
	var intentos: int = 0
	# "No existe" con el TEMPORAL presente tambien es "lo estan escribiendo": en Windows, renombrar
	# encima deja un instante sin fichero, y leer justo ahi estrenaria identidad igual que antes.
	while err != OK and intentos < REINTENTOS_LECTURA \
			and (err != ERR_FILE_NOT_FOUND or FileAccess.file_exists(RUTA + ".tmp")):
		# Casi siempre es otro proceso escribiendolo en este mismo instante: en unos milisegundos esta.
		OS.delay_msec(ESPERA_REINTENTO_MS)
		cfg = ConfigFile.new()
		err = cfg.load(RUTA)
		intentos += 1
	if err == OK:
		id = String(cfg.get_value(SECCION, "id", ""))
		nombre = String(cfg.get_value(SECCION, "nombre", ""))
		direccion_preferida = String(cfg.get_value(SECCION, "direccion", ""))
	elif err != ERR_FILE_NOT_FOUND:
		# De verdad ilegible. Se avisa fuerte porque no es inocuo -- los personajes que tengas en
		# mundos compartidos quedan a nombre del id viejo -- y se APARTA en vez de pisarlo.
		push_warning("[identidad] no se pudo leer %s (error %d): se estrena identidad" % [RUTA, err])
		if not solo_leer:
			var apartado: String = "%s.ilegible_%d" % [RUTA, int(Time.get_unix_time_from_system())]
			DirAccess.rename_absolute(ProjectSettings.globalize_path(RUTA),
				ProjectSettings.globalize_path(apartado))

	var cambiado := false
	if id.strip_edges() == "":
		id = _nuevo_id()
		recien_creada = true
		cambiado = true
	if nombre.strip_edges() == "":
		nombre = _nombre_por_defecto()
		cambiado = true
	if cambiado and not solo_leer:
		_guardar()
	print("[identidad] ", nombre, " (", id, ")", "  [NUEVA]" if recien_creada else "",
		"  [solo lectura]" if solo_leer else "")


func _guardar() -> void:
	if OS.get_cmdline_user_args().has("trabajador"):
		return
	var cfg := ConfigFile.new()
	cfg.set_value(SECCION, "id", id)
	cfg.set_value(SECCION, "nombre", nombre)
	cfg.set_value(SECCION, "direccion", direccion_preferida)
	# A un temporal y luego se renombra encima: el renombrado es atomico, asi que quien lea en ese
	# momento ve el fichero viejo entero o el nuevo entero, nunca uno a medias.
	var tmp: String = RUTA + ".tmp"
	var err: int = cfg.save(tmp)
	if err != OK:
		push_warning("[identidad] no se pudo guardar %s (error %d)" % [tmp, err])
		return
	err = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(RUTA))
	if err != OK:
		push_warning("[identidad] no se pudo colocar %s (error %d)" % [RUTA, err])


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
