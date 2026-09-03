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
# La musica va POR DEBAJO de los golpes y del ambiente, no compitiendo con ellos. Los ficheros ya
# vienen igualados a -16 LUFS y los del ambiente a -22, o sea que la musica parte 6 dB por encima:
# esto es lo que lo compensa. Estaba en -6 y el charco no se oia al lado de ella.
const DB_FONDO := -11.0
const DB_REMATE := -3.0          # el remate si manda: es el unico momento en que la musica habla

var _fondo: Array[AudioStreamPlayer] = []
var _cual: int = 0               # cual de los dos reproductores lleva el fondo ahora mismo
var _remate: AudioStreamPlayer = null

# LA PILA. Cada entrada es {contexto, pista, pos}: al apilar algo encima se apunta POR DONDE IBA la
# de debajo, y al desapilar se retoma justo ahi. Sin el 'pos', salir de cada pelea reiniciaba la
# musica de mazmorra y no se llegaba a oir ninguna entera: siempre los mismos veinte segundos.
var _pila: Array[Dictionary] = []
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
		_arrancar(contexto(), false)


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

func contexto() -> String:
	return String(_pila[-1]["contexto"]) if not _pila.is_empty() else ""


# EL CONTEXTO DE FONDO, el que manda mientras no pase nada. Cambiar de pueblo a mazmorra es esto:
# no se apila, se sustituye la base entera (y con ella todo lo que hubiera encima).
func poner(nombre: String) -> void:
	if _pila.size() == 1 and contexto() == nombre:
		return
	_pila = [{"contexto": nombre, "pista": null, "pos": 0.0}]
	_arrancar(nombre, true)


# ALGO SE PONE POR ENCIMA sin borrar lo de debajo: una pelea, un jefe. Al desapilar vuelve lo otro
# POR DONDE IBA, que es lo que se apunta aqui antes de cambiar.
func apilar(nombre: String) -> void:
	if contexto() == nombre:
		return
	_marcar_donde_va()
	_pila.append({"contexto": nombre, "pista": null, "pos": 0.0})
	_arrancar(nombre, true)


# SE ACABO lo que estaba encima. Vuelve el de debajo, retomando su pista donde se quedo.
#
# Y SE CORTA EL REMATE: al salir del combate, la fanfarria de victoria se acaba ahi. Ya ha sonado
# mientras leias el resultado, que es para lo que estaba.
func desapilar() -> void:
	_remate.stop()
	if _pila.size() <= 1:
		return
	_pila.pop_back()
	var e: Dictionary = _pila[-1]
	var pista: AudioStream = e.get("pista")
	if pista == null:
		_arrancar(String(e["contexto"]), true)
		return
	_cual = 1 - _cual
	_cruce = CRUCE
	_fondo[_cual].stream = pista
	_fondo[_cual].play(float(e.get("pos", 0.0)))


# CAMBIA lo que hay ARRIBA sin tocar lo de debajo: la pelea normal se convierte en pelea de jefe
# porque el jefe ha entrado de refuerzo a mitad. No vale apilar (dejaria "combate" debajo y al
# desapilar volveria la pelea en vez de la mazmorra) ni poner (borraria la mazmorra de la base).
#
# Si la pila esta vacia (no estabas en nada apilado), no hay cima que cambiar: no se inventa una.
func cambiar_cima(nombre: String) -> void:
	if _pila.size() <= 1 or contexto() == nombre:
		return
	_pila[-1] = {"contexto": nombre, "pista": null, "pos": 0.0}
	_arrancar(nombre, true)


func callar() -> void:
	_pila.clear()
	_remate.stop()
	for p in _fondo:
		p.stop()
	_cruce = 0.0


# Apunta en la entrada de arriba de la pila que pista suena y por que segundo va.
func _marcar_donde_va() -> void:
	if _pila.is_empty() or not _fondo[_cual].playing:
		return
	_pila[-1]["pista"] = _fondo[_cual].stream
	_pila[-1]["pos"] = _fondo[_cual].get_playback_position()


# UN REMATE: victoria, derrota, bajar un piso. Suena ENCIMA del fondo y se va solo. No entra en la
# pila porque no sustituye a nada -- la musica de mazmorra sigue sonando por debajo.
func remate(nombre: String) -> void:
	var pista: AudioStream = _siguiente_pista(nombre)
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
