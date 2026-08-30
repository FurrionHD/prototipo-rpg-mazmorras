# ============================================================
#  ambiente.gd  (autoload "Ambiente")
#  El ruido del sitio donde estas. Tres capas, y hacen falta las tres:
#
#    1. EL FONDO. Un bucle largo, siempre puesto: la mazmorra o el pueblo. Es lo que hace que el
#       silencio no sea silencio de verdad.
#    2. LOS GOLPES SUELTOS. Cada 12-30 segundos cae uno: una gota, un hueso, un chillido lejos.
#       El fondo solo no basta -- una capa constante se vuelve invisible a los dos minutos, y estos
#       son los que hacen levantar la cabeza.
#    3. LOS POSICIONALES. Pegados a una cosa del mundo (el charco, el farolillo) con `pegar`: se
#       oyen al acercarte y se van al alejarte, sin que nadie tenga que encenderlos ni apagarlos.
#
#  QUE SE OYE DEPENDE DEL PISO. Los crujidos de madera son de donde hay trents y el burbujeo de
#  donde hay slimes: soltar el burbujeo en un piso de piedra seca no ambienta, despista.
#
#  NO SE SINCRONIZA POR RED, y a proposito: son adornos que no significan nada: nadie decide nada
#  por oir una gota. Lo que SI tiene que sonar igual en las dos pantallas son los golpes de la
#  pelea, y de eso se encarga la semilla que viaja en el paquete de impactos (ver Sonido.golpe).
#
#  Todo por el bus SFX: quien baja los efectos baja tambien el ambiente, que es lo que espera
#  cualquiera. La MUSICA va por su bus y por su autoload (ver musica.gd).
# ============================================================

extends Node

const CARPETA := "res://audio/ambiente/"
const TOPE_VERSIONES := 9

const CRUCE := 2.0               # segundos de cambio de un fondo a otro
# De fondo es de fondo, pero los ficheros ya vienen igualados a -22 LUFS (6 dB por debajo de la
# musica), asi que no hace falta bajarlo tanto aqui: se sumaban las dos cosas y no se oia.
const DB_FONDO := -6.0
const DB_GOLPE := -4.0           # los sueltos, mas presentes: son los que hacen levantar la cabeza

const ESPERA_MIN := 12.0         # segundos entre golpes sueltos
const ESPERA_MAX := 30.0

const VOCES := 3                 # de sobra: no caen dos a la vez casi nunca

# Los bucles pegados al mundo van a un grupo para poder pausarlos todos de golpe al entrar en
# combate. Los crea `pegar` y viven colgados del nodo al que se pegaron, no de aqui.
const GRUPO_POSICIONAL := &"ambiente_posicional"

# QUE SUELTOS valen en cada sitio. La mazmorra los tiene casi todos; el pueblo, los que pegan a
# cielo abierto. Los que dependen del piso se anaden aparte (ver _sueltos_de).
const SUELTOS := {
	"mazmorra": ["gota", "piedrecillas", "crujido_roca", "metal_lejano", "viento", "hueso"],
	"pueblo": ["viento", "metal_lejano"],
}

# Los que solo pegan a cierta profundidad. El chillido y el aleteo quieren un piso con bicho que
# chille o vuele; la respiracion es de piso hondo, donde ya asusta de por si.
const SUELTOS_PISO := {
	"chillido": 2,
	"aleteo": 4,
	"crujido_madera": 4,     # trents
	"burbujeo": 1,           # slimes, que estan desde el principio
	"respiracion": 9,
}

var _fondo: Array[AudioStreamPlayer] = []
var _cual: int = 0
var _voces: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}      # clave -> Array[AudioStream]
var _mudos: Dictionary = {}

var _contexto: String = ""
var _cruce: float = 0.0
var _espera: float = 0.0
var _pausado: bool = false


func _ready() -> void:
	# Los menus paran el arbol entero (ver game.abrir_menu). Sin esto, abrir la ficha corta el
	# ambiente en seco y al cerrarla vuelve de golpe.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.volume_db = -80.0
		add_child(p)
		_fondo.append(p)
	for i in VOCES:
		var v := AudioStreamPlayer.new()
		v.bus = "SFX"
		v.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(v)
		_voces.append(v)
	_espera = randf_range(ESPERA_MIN, ESPERA_MAX)
	# QUIEN SABE EN QUE PANTALLA ESTAMOS ES MUSICA, que vigila la escena actual. Aqui solo se
	# escucha: asi la tabla de "que escena es que sitio" esta en UN sitio y no en dos que se
	# separan el dia que se anada una pantalla.
	Musica.contexto_cambiado.connect(poner)


# Soltar los bucles al cerrar, o Godot avisa de recursos en uso al salir. Ver Musica._exit_tree.
func _exit_tree() -> void:
	callar()
	for p in _fondo:
		p.stream = null
	for v in _voces:
		v.stop()
		v.stream = null
	# Y los posicionales, que no cuelgan de aqui sino del charco y del jugador.
	if get_tree() != null:
		for p in get_tree().get_nodes_in_group(GRUPO_POSICIONAL):
			if p is AudioStreamPlayer2D:
				(p as AudioStreamPlayer2D).stop()
				(p as AudioStreamPlayer2D).stream = null
	_cache.clear()


func _process(delta: float) -> void:
	if _cruce > 0.0:
		_cruce = maxf(0.0, _cruce - delta)
		var k: float = 1.0 - (_cruce / CRUCE)
		_fondo[_cual].volume_db = lerpf(-80.0, DB_FONDO, k)
		_fondo[1 - _cual].volume_db = lerpf(DB_FONDO, -80.0, k)
		if _cruce <= 0.0:
			_fondo[1 - _cual].stop()
	if _contexto == "" or _pausado:
		return
	_espera -= delta
	if _espera <= 0.0:
		_espera = randf_range(ESPERA_MIN, ESPERA_MAX)
		_suelto()


# ============================================================
#  EL FONDO
# ============================================================

func poner(contexto: String) -> void:
	if contexto == _contexto:
		return
	_contexto = contexto
	# SIN AVISO: que un sitio no tenga ambiente es NORMAL, no un fallo. Los menus no lo tienen (ahi
	# solo hay musica) y avisar por ellos llenaba la consola de un "mudo" que no hay que arreglar.
	var s: AudioStream = _una_version("bucle_" + contexto, false)
	if s == null:
		callar()
		return
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	if _fondo[_cual].playing:
		_cual = 1 - _cual
		_cruce = CRUCE
	else:
		_fondo[_cual].volume_db = DB_FONDO
	_fondo[_cual].stream = s
	_fondo[_cual].play()


func callar() -> void:
	_contexto = ""
	for p in _fondo:
		p.stop()
	_cruce = 0.0


# EL COMBATE TAPA EL AMBIENTE. Mientras peleas no estas oyendo la mazmorra: estas dentro de la
# pelea, con su musica y sus golpes. El goteo y el crujido de fondo ahi sobran.
#
# Y ES POR MAQUINA, no por partida: si tu compañero sigue fuera, EL si oye la mazmorra. Por eso se
# mira si hay pantalla de combate AQUI y no se manda nada por red.
#
# Se PAUSA, no se apaga: los bucles posicionales (el charco, tu farolillo) y la pista de fondo
# retoman donde estaban al salir, en vez de dar un salto.
func pausar(si: bool) -> void:
	if _pausado == si:
		return
	_pausado = si
	for p in _fondo:
		p.stream_paused = si
	for v in _voces:
		v.stream_paused = si
	for p2 in get_tree().get_nodes_in_group(GRUPO_POSICIONAL):
		if p2 is AudioStreamPlayer2D:
			(p2 as AudioStreamPlayer2D).stream_paused = si


# ============================================================
#  LOS GOLPES SUELTOS
# ============================================================

func _suelto() -> void:
	var lista: Array = _sueltos_de(_contexto)
	if lista.is_empty():
		return
	var s: AudioStream = _una_version("amb_" + String(lista[randi() % lista.size()]))
	if s == null:
		return
	var libre: AudioStreamPlayer = _voces[0]
	for v in _voces:
		if not v.playing:
			libre = v
			break
	libre.stream = s
	# Un poco de tono y un poco de volumen cada vez: la misma gota veinte veces seguidas canta.
	libre.pitch_scale = randf_range(0.9, 1.1)
	libre.volume_db = DB_GOLPE + randf_range(-4.0, 0.0)
	libre.play()


func _sueltos_de(contexto: String) -> Array:
	var lista: Array = (SUELTOS[contexto] as Array).duplicate() if SUELTOS.has(contexto) else []
	if contexto == "mazmorra":
		var piso: int = Game.current_floor if Game != null else 1
		for clave in SUELTOS_PISO:
			if piso >= int(SUELTOS_PISO[clave]):
				lista.append(clave)
	return lista


# ============================================================
#  LOS POSICIONALES
# ============================================================

# Cuelga un bucle de 'nodo' y lo devuelve. Quien lo pide no tiene que apagarlo: al morir el nodo
# se va con el. 'distancia' es a cuantos pixeles deja de oirse.
func pegar(nodo: Node2D, clave: String, db: float = -14.0, distancia: float = 220.0) -> AudioStreamPlayer2D:
	if nodo == null:
		return null
	var s: AudioStream = _una_version("bucle_" + clave)
	if s == null:
		return null
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	var p := AudioStreamPlayer2D.new()
	p.bus = "SFX"
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.stream = s
	p.volume_db = db
	p.max_distance = distancia
	p.add_to_group(GRUPO_POSICIONAL)
	p.stream_paused = _pausado   # nacido en combate (el charco de un piso al que entras peleando)
	# Cada uno arranca por un sitio distinto del bucle: si no, dos antorchas en la misma sala
	# chisporrotean a la vez y se oye el eco de un solo fuego, no dos.
	nodo.add_child(p)
	p.play(randf() * maxf(0.1, s.get_length()))
	return p


# ============================================================
#  LOS FICHEROS
# ============================================================

func _una_version(clave: String, avisar: bool = true) -> AudioStream:
	var v: Array = _streams(clave, avisar)
	return v[randi() % v.size()] if not v.is_empty() else null


# Igual que Sonido._streams: se prueban nombres en vez de listar la carpeta, porque DirAccess sobre
# res:// no es de fiar dentro del .pck exportado. El nombre pelado y luego _v1.._vN.
func _streams(clave: String, avisar: bool = true) -> Array:
	if _cache.has(clave):
		return _cache[clave]
	var res: Array = []
	for ext in ["ogg", "wav"]:
		var pelado: String = CARPETA + clave + "." + ext
		if ResourceLoader.exists(pelado):
			res.append(load(pelado))
		for i in range(1, TOPE_VERSIONES + 1):
			var ruta: String = CARPETA + "%s_v%d.%s" % [clave, i, ext]
			if not ResourceLoader.exists(ruta):
				break
			res.append(load(ruta))
		if not res.is_empty():
			break
	_cache[clave] = res
	if res.is_empty() and avisar and OS.is_debug_build() and not _mudos.has(clave):
		_mudos[clave] = true
		print("[Ambiente] mudo: no hay %s%s" % [CARPETA, clave])
	return res
