# ============================================================
#  sonido.gd  (autoload "Sonido")
#  El unico sitio que reproduce efectos de sonido.
#
#  QUE SUENA. Se busca primero el fichero de LA HABILIDAD y, si no existe, el de su ESTILO. Asi el
#  bramido del minotauro suena distinto del chillido de la rata aunque compartan dibujo, y con solo
#  tener el generico de la familia ya no hay nada mudo. Los nombres: sfx_<clave>.wav, donde la clave
#  de una habilidad es el nombre de su .tres (minotauro_bramido) y la de un estilo es el nombre del
#  enum en minusculas (chillido). Ver audio/sfx/LEEME.md.
#
#  Y CADA CLAVE PUEDE TENER VARIAS VERSIONES: sfx_X_v1.wav, _v2, _v3... Se sortea una en cada
#  disparo. Es lo que hace que el Grito de guerra no suene calcado las tres veces que lo lanzas en
#  una pelea. Una sola version se llama sfx_X.wav a secas, sin sufijo.
#
#  POR QUE UNA PISCINA DE VOCES y no un solo reproductor: el Frenesi de la rata son SEIS impactos en
#  dos segundos. Con un AudioStreamPlayer unico, cada mordisco cortaria al anterior y la racha se
#  oiria como un solo golpe.
#
#  QUIEN LLAMA: CombatFX._process, en el mismo frame en que da de alta el dibujo, para que el sonido
#  y el efecto caigan juntos. Nadie mas -- si algun dia hace falta sonido fuera del combate, que
#  entre por aqui igual.
# ============================================================

extends Node

# CUANTAS VOCES a la vez. Doce cubre de sobra el caso peor conocido (una tormenta de 32 impactos
# topa en unas pocas tandas, y de una tanda de area suena UNA sola: ver 'sin_dibujo' en CombatFX).
const VOCES := 12

const CARPETA := "res://audio/sfx/"

# Hasta que version se busca. Se para en el primer hueco, asi que esto es solo el tope de la
# busqueda: seis es el maximo que hay hoy (los caparazones) y sobra sitio.
const TOPE_VERSIONES := 9

# LOS VOLUMENES QUE SE PUEDEN TOCAR. La clave es la que se guarda en disco y la que pide la UI; el
# valor, el bus del AudioServer. "general" es el Master, o sea que baja TODO de golpe -- los otros
# dos cuelgan de el y se multiplican con el, que es justo lo que espera cualquiera.
#
# MUSICA todavia no la usa nadie (no hay musica), y esta a proposito: el dia que la haya, el mando
# ya existe y viene con el volumen que el jugador dejo puesto.
#
# LOS BUSES VIVEN EN default_bus_layout.tres, en la raiz, y NO hay ni una linea en project.godot que
# lo diga: esa ruta es la que Godot busca por defecto, asi que al importar BORRA el ajuste por
# redundante. Si algun dia el fichero se mueve o se renombra, los buses desaparecen sin avisar y
# esto se queda mudo -- get_bus_index devolveria -1 para SFX y MUSICA.
const BUSES := {"general": "Master", "efectos": "SFX", "musica": "MUSICA"}

# Los ajustes son de la MAQUINA, no de la partida: se quedan igual cambies de ranura o de mundo, y
# por eso no viajan en el save. Mismo sitio y mismo formato que user://identidad.cfg.
const RUTA_AJUSTES := "user://ajustes.cfg"
const SECCION_VOL := "volumen"

# LAS HABILIDADES QUE TIENEN SONIDO PROPIO. Todo lo que no este aqui suena por su estilo, que es lo
# normal: una rata muerde igual le salga la tecnica o no.
#
# ESTE ORDEN VIAJA POR RED. El indice (+1) es lo que se mete en los bits 20-31 del paquete de
# impactos (ver combat.gd._apuntar_impacto_red), asi que las claves nuevas se añaden AL FINAL y
# nunca se reordena ni se quita ninguna sin subir Net.PROTOCOLO.
const CLAVES := [
	"aberracion_alarido", "aberracion_mirada", "bestia_carga", "coloso_pisoton",
	"gargola_mirada", "gargola_picado", "golem_machaca", "minotauro_bramido",
	"minotauro_cornada", "minotauro_pisoton", "rey_slime_aplastamiento",
	"trent_ramazo", "trent_savia_corrosiva",
]

# CUANTO SE OYE segun el peso del golpe (la fraccion que se lleva ese objetivo: 1.0 el principal,
# 0.5 un adyacente). El rango es corto a proposito -- un adyacente suena mas flojo, no lejano.
const DB_FLOJO := -8.0     # peso 0.2
const DB_LLENO := 0.0      # peso 1.0
const DB_GORDO := 2.0      # peso 1.5
const DB_CRITICO := 2.0

# LA CAPA DEL ELEMENTO suena ENCIMA del golpe, no en su lugar: el mandoble sigue sonando a mandoble
# y el fuego se le monta. Por eso va mas floja -- si compitiera de tu a tu con el golpe, todas las
# armas imbuidas sonarian igual.
const DB_ELEMENTO := -6.0

# Como se llama el fichero de cada elemento; la clave es Elements.Elemento. NINGUNO (0) no esta a
# proposito. Un elemento sin fichero se queda sin capa y ya: el golpe suena igual.
#
# NO HAY VENENO aqui porque el veneno NO es un elemento, es un estado (ver elements.gd). Existe un
# audio/sfx/sfx_elem_veneno.wav sin usar, esperando a que alguna vez lo sea.
const ELEMENTOS := {
	Elementos.Elemento.FUEGO: "fuego",
	Elementos.Elemento.AGUA: "agua",
	Elementos.Elemento.RAYO: "rayo",
}

# La misma muestra seis veces seguidas suena a metralleta. Un pelin de tono cada vez y la racha se
# oye como seis mordiscos distintos.
const TONO_MIN := 0.94
const TONO_MAX := 1.06
const TONO_CRITICO := 0.95   # el critico, un punto mas grave: pesa mas

# Dos disparos del MISMO fichero mas juntos que esto son un error de conteo, no dos golpes. Es el
# seguro por si alguna area se cuela sin marcar; el reparto bueno lo hace _marcar_efectos_de_grupo.
const MS_ANTISOLAPE := 50

var _voces: Array[AudioStreamPlayer] = []
var _desde: Array[int] = []            # ms en que arranco cada voz, para robar la mas antigua
var _cache: Dictionary = {}            # clave -> Array[AudioStream] (vacio si no hay fichero)
var _ultimo: Dictionary = {}           # clave resuelta -> ms del ultimo disparo
var _mudos: Dictionary = {}            # avisos ya dados, para no repetirlos cada frame

# Cuantos golpes se han llegado a REPRODUCIR (los mudos y los que corta el antisolape no cuentan).
# Es para depurar: mirandolo se sabe si una racha de seis sono seis veces o una.
var disparos: int = 0


# Cuanto suena cada cosa, de 0.0 (mudo) a 1.0 (a tope). Se lee con volumen() y se toca con
# fijar_volumen(); esto es solo el respaldo en memoria de lo que hay en disco.
var _vol: Dictionary = {}


func _ready() -> void:
	_cargar_ajustes()
	for i in VOCES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		# Los menus paran el arbol entero (ver game.abrir_menu). Una voz pausable se cortaria a
		# media dentellada al abrir la ficha.
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_voces.append(p)
		_desde.append(0)


# UN GOLPE. 'clave' es la de la habilidad ("" si no tiene sonido propio) y 'estilo' el CombatFX.Estilo
# que hace de respaldo. 'peso' y 'crit' son los mismos que gobiernan el dibujo, y 'elem' el
# Elementos.Elemento con el que va imbuido (0 = ninguno).
func golpe(clave: String, estilo: int, peso: float = 1.0, crit: bool = false, elem: int = 0,
		semilla: int = 0) -> void:
	var resuelta: String = _resolver(clave, estilo)
	if resuelta == "":
		return
	var ahora: int = Time.get_ticks_msec()
	# EL ANTISOLAPE VA POR CLAVE, NO POR FICHERO. Con varias versiones por clave, dos disparos
	# pegados caerian en versiones distintas y el guardian no veria la repeticion: sonaria la
	# metralleta que esto existe para evitar.
	if ahora - int(_ultimo.get(resuelta, -99999)) < MS_ANTISOLAPE:
		return
	_ultimo[resuelta] = ahora

	# TODO LO QUE SE SORTEA SALE DE LA MISMA SEMILLA: la version y la pizca de tono. Cuando viene de
	# red es la que tiro el anfitrion, asi que el golpe suena IGUAL en todas las pantallas -- si
	# cada maquina sorteara lo suyo, el mismo mandoble seria un sonido distinto en cada una. Sin
	# red (semilla 0) se sortea aqui y da lo mismo.
	var rng := RandomNumberGenerator.new()
	if semilla != 0:
		rng.seed = semilla
	else:
		rng.randomize()
	var tono: float = rng.randf_range(TONO_MIN, TONO_MAX) * (TONO_CRITICO if crit else 1.0)
	var db: float = _db(peso) + (DB_CRITICO if crit else 0.0)
	_soltar(_una_version(resuelta, rng), db, tono, ahora)
	disparos += 1

	# LA CAPA DEL ELEMENTO, en su propia voz y a la vez. Comparte tono con el golpe para que se oigan
	# como una sola cosa y no como dos sonidos sueltos que coinciden.
	if ELEMENTOS.has(elem):
		_soltar(_una_version("elem_" + String(ELEMENTOS[elem]), rng), db + DB_ELEMENTO, tono, ahora)


func _soltar(stream: AudioStream, db: float, tono: float, ahora: int) -> void:
	if stream == null:
		return
	var v: AudioStreamPlayer = _voz_libre(ahora)
	v.stream = stream
	v.volume_db = db
	v.pitch_scale = tono
	v.play()


# UNA MUESTRA para oir como ha quedado el volumen que acabas de mover. Sin ella hay que salir del
# menu y buscarse una pelea para enterarte de si te has pasado.
#
# Suena el mordisco porque es corto, seco y esta siempre (es un generico de familia, no depende de
# que se haya elegido ninguna version). Se salta el antisolape a proposito: mover el mando dos veces
# seguidas tiene que contestar las dos.
func muestra() -> void:
	_ultimo.erase("mordisco")
	golpe("", CombatFX.Estilo.MORDISCO, 1.0, false)


# La clave que corresponde a un indice del paquete de red. 0 = ninguna (suena el generico del
# estilo). Fuera de rango tambien devuelve "": un compañero con una version mas nueva puede mandar
# un indice que aqui todavia no existe, y eso tiene que quedarse en un sonido generico, no reventar.
func clave_de(i: int) -> String:
	return String(CLAVES[i - 1]) if i > 0 and i <= CLAVES.size() else ""


# ============================================================
#  VOLUMENES (los ajustes del jugador)
# ============================================================

# Lo que tiene puesto ese mando, de 0.0 a 1.0. Una clave que no existe devuelve 1.0 en vez de 0.0:
# equivocarse de nombre tiene que sonar raro, no dejar el juego mudo sin decir nada.
func volumen(clave: String) -> float:
	return float(_vol.get(clave, 1.0))


# Mueve un mando y se oye YA. NO guarda en disco: arrastrando un slider esto se llama en cada pixel
# y serian cien escrituras por gesto. Guardar es cosa de guardar_ajustes(), al soltar.
func fijar_volumen(clave: String, v: float) -> void:
	if not BUSES.has(clave):
		return
	_vol[clave] = clampf(v, 0.0, 1.0)
	_aplicar(clave)


func guardar_ajustes() -> void:
	var cfg := ConfigFile.new()
	for clave in BUSES:
		cfg.set_value(SECCION_VOL, clave, volumen(clave))
	var err: int = cfg.save(RUTA_AJUSTES)
	if err != OK:
		push_warning("[sonido] no se pudo guardar %s (error %d)" % [RUTA_AJUSTES, err])


func _cargar_ajustes() -> void:
	var cfg := ConfigFile.new()
	var err: int = cfg.load(RUTA_AJUSTES)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("[sonido] no se pudo leer %s (error %d): volumenes por defecto" % [RUTA_AJUSTES, err])
	for clave in BUSES:
		_vol[clave] = clampf(float(cfg.get_value(SECCION_VOL, clave, 1.0)), 0.0, 1.0)
		_aplicar(clave)


func _aplicar(clave: String) -> void:
	var i: int = AudioServer.get_bus_index(String(BUSES[clave]))
	if i < 0:
		return
	var v: float = volumen(clave)
	# El MUTE aparte del volumen: linear_to_db(0.0) es -inf, y aunque el bus lo aguanta, dejarlo
	# apagado de verdad es mas honesto que mandarle un numero infinito.
	AudioServer.set_bus_mute(i, v <= 0.0)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))


# El peso (0.2 flojo .. 1.0 lleno .. 1.5 gordo) a decibelios, en dos tramos rectos. Nada de
# linear_to_db: ese mandaria un adyacente de 0.2 a -14 dB, o sea a otra habitacion.
func _db(peso: float) -> float:
	var p: float = clampf(peso, 0.2, 1.5)
	if p <= 1.0:
		return lerpf(DB_FLOJO, DB_LLENO, (p - 0.2) / 0.8)
	return lerpf(DB_LLENO, DB_GORDO, (p - 1.0) / 0.5)


func _voz_libre(ahora: int) -> AudioStreamPlayer:
	var viejo: int = 0
	for i in _voces.size():
		if not _voces[i].playing:
			_desde[i] = ahora
			return _voces[i]
		if _desde[i] < _desde[viejo]:
			viejo = i
	# Todas ocupadas: se roba la que lleva mas tiempo sonando, que es la que menos se echa de menos.
	_desde[viejo] = ahora
	return _voces[viejo]


# La clave que de verdad va a sonar: la de la habilidad si tiene fichero propio y, si no, la de su
# estilo. Devuelve "" si no hay ni una cosa ni la otra (queda mudo).
func _resolver(clave: String, estilo: int) -> String:
	if clave != "" and not _streams(clave).is_empty():
		return clave
	var nombre: String = _nombre_estilo(estilo)
	if nombre != "" and not _streams(nombre).is_empty():
		return nombre
	return ""


func _una_version(clave: String, rng: RandomNumberGenerator) -> AudioStream:
	var v: Array = _streams(clave)
	return v[rng.randi() % v.size()] if not v.is_empty() else null


func _nombre_estilo(estilo: int) -> String:
	var claves: Array = CombatFX.Estilo.keys()
	return String(claves[estilo]).to_lower() if estilo >= 0 and estilo < claves.size() else ""


# TODAS las versiones de una clave, cargadas una vez y guardadas. Vacio = esa clave esta muda.
#
# SE BUSCA PROBANDO NOMBRES, no listando la carpeta: DirAccess sobre res:// no es de fiar dentro
# del .pck exportado, y ahi lo unico seguro es preguntar por un recurso concreto.
func _streams(clave: String) -> Array:
	if _cache.has(clave):
		return _cache[clave]
	var res: Array = []
	var pelado: String = CARPETA + "sfx_" + clave + ".wav"
	if ResourceLoader.exists(pelado):
		res.append(load(pelado))
	for i in range(1, TOPE_VERSIONES + 1):
		var ruta: String = CARPETA + "sfx_%s_v%d.wav" % [clave, i]
		if not ResourceLoader.exists(ruta):
			break
		res.append(load(ruta))
	_cache[clave] = res
	if res.is_empty() and OS.is_debug_build() and not _mudos.has(clave):
		_mudos[clave] = true
		print("[Sonido] mudo: no hay sfx_%s.wav" % clave)
	return res
