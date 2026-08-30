# ============================================================
#  musica.gd  (autoload "Musica")
#  La musica de fondo. El unico sitio que la pone y la quita.
#
#  QUE PROBLEMA RESUELVE. La musica no es "una pista por pantalla": es una PILA. Estas en la
#  mazmorra, te sale una pelea, y al acabarla la musica de mazmorra tiene que volver DONDE ESTABA,
#  no empezar de cero cada vez que matas una rata. Por eso `apilar`/`desapilar` en vez de un
#  `poner` a secas: el contexto de debajo se recuerda entero.
#
#  DOS REPRODUCTORES para el fondo, no uno: cambiar de contexto CRUZA (uno baja mientras el otro
#  sube) y con un solo reproductor el corte seria a hachazo. Un tercero aparte para los REMATES
#  -- la fanfarria de victoria, el golpe de bajar un piso -- que suenan ENCIMA sin tocar el fondo.
#
#  LAS PISTAS SE BUSCAN POR NUMERO: res://audio/musica/<contexto>/1.ogg, 2.ogg... hasta el primer
#  hueco. Anadir musica es soltar el fichero con el numero siguiente; aqui no se toca nada. Cada
#  contexto se BARAJA y se recorre entero antes de repetir, que es lo que hace que con seis pistas
#  de mazmorra no te salga dos veces la misma seguidas.
#
#  PROCESS_MODE_ALWAYS: los menus paran el arbol entero (ver game.abrir_menu). Sin esto la musica
#  se corta en seco al abrir la ficha.
#
#  ES 100% LOCAL. No viaja nada por red: cada maquina decide su musica de su propio estado, asi que
#  no hay ni un `if Net.activo` aqui dentro ni hace falta subir Net.PROTOCOLO.
# ============================================================

extends Node

# El contexto de FONDO acaba de cambiar (por haber cambiado de pantalla). Lo escucha Ambiente para
# poner su bucle: asi el mapa de "que escena es que sitio" vive en UN solo archivo. Hay veinte
# `change_scene_to_file` repartidos por el codigo y engancharlos uno a uno era garantia de olvidarse
# de alguno -- y un olvido de estos no da error: se queda la musica del pueblo sonando en la
# mazmorra.
signal contexto_cambiado(contexto: String)

const CARPETA := "res://audio/musica/"

# QUE SUENA EN CADA PANTALLA. La clave es el fichero de escena.
const POR_ESCENA := {
	"res://scenes/ui/main_menu.tscn": "menu",
	"res://scenes/ui/multi_menu.tscn": "menu",
	"res://scenes/levels/town.tscn": "pueblo",
	"res://scenes/levels/main.tscn": "mazmorra",
}
const TOPE_PISTAS := 32          # tope de la busqueda por numero; se para en el primer hueco

const CRUCE := 1.5               # segundos que tarda un contexto en dar paso al siguiente
const DB_FONDO := -6.0           # la musica va POR DEBAJO de los golpes, no compitiendo con ellos
const DB_REMATE := -3.0          # el remate si manda: es el unico momento en que la musica habla

var _fondo: Array[AudioStreamPlayer] = []
var _cual: int = 0               # cual de los dos reproductores lleva el fondo ahora mismo
var _remate: AudioStreamPlayer = null

var _pila: Array[String] = []    # contextos apilados; el ultimo es el que suena
var _listas: Dictionary = {}     # contexto -> Array[AudioStream], ya barajado
var _siguiente: Dictionary = {}  # contexto -> por que pista va
var _mudos: Dictionary = {}      # avisos ya dados
var _escena: String = ""         # la ultima escena vista, para notar el cambio

# Cruce en curso: cuanto queda y con que volumen arranco cada lado.
var _cruce: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "MUSICA"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.volume_db = -80.0
		add_child(p)
		_fondo.append(p)
	_remate = AudioStreamPlayer.new()
	_remate.bus = "MUSICA"
	_remate.process_mode = Node.PROCESS_MODE_ALWAYS
	_remate.volume_db = DB_REMATE
	add_child(_remate)


# Soltar las pistas al cerrar. Sin esto, Godot avisa al salir de que quedan recursos en uso: los
# streams cargados siguen colgando de la cache cuando el motor ya esta desmontando.
func _exit_tree() -> void:
	callar()
	_remate.stop()
	_remate.stream = null
	for p in _fondo:
		p.stream = null
	_listas.clear()


func _process(delta: float) -> void:
	_mirar_escena()
	if _cruce > 0.0:
		_cruce = maxf(0.0, _cruce - delta)
		var k: float = 1.0 - (_cruce / CRUCE)
		_fondo[_cual].volume_db = lerpf(-80.0, DB_FONDO, k)
		_fondo[1 - _cual].volume_db = lerpf(DB_FONDO, -80.0, k)
		if _cruce <= 0.0:
			_fondo[1 - _cual].stop()
	# LA PISTA SE ACABO: la siguiente de la lista, sin cruce (son del mismo contexto y encadenan).
	elif not _pila.is_empty() and not _fondo[_cual].playing:
		_arrancar(_pila[-1], false)


# ¿HA CAMBIADO LA PANTALLA? Se mira en cada frame en vez de engancharse a los change_scene_to_file
# porque hay veinte repartidos por el codigo (menus, puertas, red, cargar partida) y olvidar uno no
# da error: deja la musica anterior sonando donde no toca. Comparar una cadena por frame no le
# duele a nadie.
func _mirar_escena() -> void:
	var actual: Node = get_tree().current_scene if get_tree() != null else null
	var ruta: String = actual.scene_file_path if actual != null else ""
	if ruta == _escena:
		return
	_escena = ruta
	# Una escena que no esta en la tabla (el visor, un dev_*.tscn) NO calla la musica: se deja lo
	# que hubiera, que es menos molesto que un silencio de golpe.
	if not POR_ESCENA.has(ruta):
		return
	var contexto: String = String(POR_ESCENA[ruta])
	poner(contexto)
	contexto_cambiado.emit(contexto)


# ============================================================
#  LA PILA DE CONTEXTOS
# ============================================================

# EL CONTEXTO DE FONDO, el que manda mientras no pase nada. Cambiar de pueblo a mazmorra es esto:
# no se apila, se sustituye la base entera (y con ella todo lo que hubiera encima).
func poner(contexto: String) -> void:
	if _pila.size() == 1 and _pila[0] == contexto:
		return
	_pila = [contexto]
	_arrancar(contexto, true)


# ALGO SE PONE POR ENCIMA sin borrar lo de debajo: una pelea, un jefe. Al desapilar vuelve lo otro.
func apilar(contexto: String) -> void:
	if not _pila.is_empty() and _pila[-1] == contexto:
		return
	_pila.append(contexto)
	_arrancar(contexto, true)


# SE ACABO lo que estaba encima. Vuelve el de debajo; si no queda ninguno, silencio.
func desapilar() -> void:
	if _pila.size() <= 1:
		return
	_pila.pop_back()
	_arrancar(_pila[-1], true)


func callar() -> void:
	_pila.clear()
	for p in _fondo:
		p.stop()
	_cruce = 0.0


# UN REMATE: victoria, derrota, bajar un piso. Suena ENCIMA del fondo y se va solo. No entra en la
# pila porque no sustituye a nada -- la musica de mazmorra sigue sonando por debajo.
func remate(contexto: String) -> void:
	var pista: AudioStream = _siguiente_pista(contexto)
	if pista == null:
		return
	_remate.stream = pista
	_remate.play()


# ============================================================
#  LAS PISTAS
# ============================================================

func _arrancar(contexto: String, con_cruce: bool) -> void:
	var pista: AudioStream = _siguiente_pista(contexto)
	if pista == null:
		return
	if con_cruce and _fondo[_cual].playing:
		_cual = 1 - _cual
		_cruce = CRUCE
	else:
		_fondo[_cual].volume_db = DB_FONDO
	_fondo[_cual].stream = pista
	_fondo[_cual].play()


# La siguiente de la lista barajada del contexto. Al agotarla se vuelve a barajar, asi que un
# contexto de una sola pista la repite y uno de seis las da todas antes de repetir ninguna.
func _siguiente_pista(contexto: String) -> AudioStream:
	var lista: Array = _lista(contexto)
	if lista.is_empty():
		return null
	var i: int = int(_siguiente.get(contexto, 0))
	if i >= lista.size():
		# Barajar de nuevo. Si hay mas de una, se evita que la primera de la vuelta nueva sea la
		# ultima de la anterior: seria la unica repeticion seguida posible y canta mucho.
		var ultima: AudioStream = lista[-1]
		lista.shuffle()
		if lista.size() > 1 and lista[0] == ultima:
			lista.append(lista.pop_front())
		i = 0
	_siguiente[contexto] = i + 1
	return lista[i]


func _lista(contexto: String) -> Array:
	if _listas.has(contexto):
		return _listas[contexto]
	var lista: Array = []
	for n in range(1, TOPE_PISTAS + 1):
		var ruta: String = CARPETA + contexto + "/%d.ogg" % n
		if not ResourceLoader.exists(ruta):
			break
		var s: AudioStream = load(ruta) as AudioStream
		if s != null:
			# EL BUCLE SE PONE AQUI Y NO EN EL IMPORTADOR: el .import del ogg trae loop=false por
			# defecto y hay 24 ficheros. Ademas asi el remate se puede reproducir sin bucle
			# usando el MISMO recurso -- lo controla quien lo pone, no el fichero.
			if s is AudioStreamOggVorbis:
				(s as AudioStreamOggVorbis).loop = false
			lista.append(s)
	_listas[contexto] = lista
	if lista.is_empty() and OS.is_debug_build() and not _mudos.has(contexto):
		_mudos[contexto] = true
		print("[Musica] sin pistas para '%s' (%s%s/1.ogg)" % [contexto, CARPETA, contexto])
	return lista
