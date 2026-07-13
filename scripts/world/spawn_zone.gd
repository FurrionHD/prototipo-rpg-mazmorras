# ============================================================
#  spawn_zone.gd
#  Una ZONA de la mazmorra (una sala o un pasillo) que PARE monstruos por sus paredes.
#  La crea dungeon_floor a partir del trazado: la zona ya nace sabiendo cuales de sus
#  celdas de roca tocan su suelo (sus "celdas de parto").
#
#  RITMO: espera un tiempo ALEATORIO dentro de una franja y lo vuelve a tirar tras cada
#  parto -no es un metronomo- y la franja es LENTA a proposito: entre pelear, extraer el
#  cristal y moverte pasa mucho tiempo real, y una sala escupiendo bichos cada 10 s te
#  ahoga. Ademas, mientras peleas el arbol esta en pausa (Game.start_combat), asi que
#  estos relojes se congelan solos: al salir de un combate no te encuentras la sala
#  repoblada de golpe.
#
#  El parto puede pasar TENGAS TU DELANTE O NO (esa es la gracia: la mazmorra te para
#  bichos en las narices), pero nunca DENTRO de ti: las celdas pegadas al jugador se
#  descartan.
# ============================================================

extends Node2D
class_name SpawnZone

# Quien lleva la contabilidad global del piso (tope de vivos, reciclado, creacion del
# bicho). SIN TIPAR a proposito: tiparlo como Node haria que GDScript no encontrase sus
# metodos (hay_sitio, crear_enemigo...) en tiempo de compilacion.
var piso = null

var zona_idx: int = 0
var tipo: String = "sala"
var partos: Array = []          # [{pared: Vector2i, suelo: Vector2i}, ...]
var max_vivos: int = 3
var wander_radius: float = 90.0

# Por donde pueden MOVERSE los bichos de esta zona: la posicion (en mundo) de cada celda
# pisable suya, y un punto de dentro que les sirve de "hogar". Sin esto, un bicho que nace
# en la pared se queda merodeando CONTRA la pared (medio circulo de deambular era roca).
var puntos: Array = []
var hogar: Vector2 = Vector2.ZERO

# --- Ritmo (segundos entre partos). Lo fija dungeon_floor; aqui van los de referencia ---
var intervalo_min: float = 25.0
var intervalo_max: float = 70.0

# --- Aviso de la pared ---
var aviso_dur: float = 1.2
var aviso_amp: float = 2.5

# --- Distancia minima al jugador para elegir una celda de parto (px) ---
# 64 = dos celdas. Puede nacerte al lado, pero no encima.
var dist_min_jugador: float = 64.0

# --- Separacion minima entre bichos al nacer (px) ---
# 48 = celda y media. Ya no se empujan entre ellos (no colisionan), pero nacer amontonados
# se ve como un pegote unico y no como varios enemigos.
var separacion_min: float = 48.0

# --- BROTE MASIVO (KAN, futuro): APAGADO ---
# Cuando se encienda: de vez en cuando una pared no pare uno, sino varios de golpe, con
# un aviso mas largo y un temblor mas fuerte. Hoy no se activa porque aun no tiene
# proposito (y sin balancear, 10 bichos = 10 combates encadenados = masacre).
var brotes_activos: bool = false
var prob_brote: float = 0.01    # ~1 de cada 100 partos
var brote_min: int = 2
var brote_max: int = 3

# Enemigos vivos que ha parido ESTA zona. Sin tipar el elemento: los enemigos exponen
# metodos propios (esta_muerto) que un Array[Node] no dejaria llamar.
var _vivos: Array = []
var _espera: float = 0.0

# Parto en curso (la pared ya esta avisando). El FX tambien va sin tipar (ver 'piso').
var _fx = null
var _fx_t: float = 0.0
var _fx_suelo: Vector2 = Vector2.ZERO
var _fx_cantidad: int = 1

const _FX_SCRIPT := preload("res://scripts/world/wall_birth_fx.gd")


func _ready() -> void:
	_rearmar()


func _process(delta: float) -> void:
	# Con un parto en marcha, la zona solo cuenta hasta que la pared se abre.
	if _fx != null:
		_fx_t -= delta
		if _fx_t <= 0.0:
			_abrir_pared()
		return

	_purgar()
	_espera -= delta
	if _espera <= 0.0:
		_intentar_parto()
		_rearmar()


# Vuelve a tirar la espera: cada parto reinicia el reloj con un tiempo distinto.
func _rearmar() -> void:
	_espera = randf_range(intervalo_min, intervalo_max)


func vivos() -> int:
	_purgar()
	return _vivos.size()


# Mete en la zona un bicho que NO ha parido ella: uno restaurado de la memoria del piso.
# Sin esto, la zona se creeria vacia al volver y se pondria a parir por encima de su aforo.
func adoptar(e) -> void:
	if e == null:
		return
	_vivos.append(e)
	if not puntos.is_empty() and e.has_method("asignar_zona"):
		e.asignar_zona(puntos, hogar)


# Quita del registro a los que ya no son enemigos VIVOS: los muertos siguen en la escena
# como cadaveres (con tu loot dentro), pero no ocupan plaza en la zona.
func _purgar() -> void:
	var quedan: Array = []
	for e in _vivos:
		if is_instance_valid(e) and not e.esta_muerto():
			quedan.append(e)
	_vivos = quedan


func _intentar_parto() -> void:
	if partos.is_empty() or piso == null:
		return
	if _vivos.size() >= max_vivos:
		return            # la zona esta llena: calla hasta que mates a alguno
	if not piso.hay_sitio():
		return            # el piso entero esta al tope y no habia a quien reciclar

	var sitio: Dictionary = _elegir_celda()
	if sitio.is_empty():
		return            # todas las celdas estan pegadas al jugador: esperamos

	var cantidad: int = 1
	var brote: bool = brotes_activos and randf() < prob_brote
	if brote:
		cantidad = randi_range(brote_min, brote_max)
	engendrar(sitio, cantidad, brote)


# Arranca un parto en una celda concreta. Publico para poder forzarlo (brote de prueba
# desde una tecla de dev).
func engendrar(sitio: Dictionary, cantidad: int, brote: bool = false) -> void:
	if _fx != null or piso == null:
		return
	var lado: float = float(DungeonGenerator.CELDA)
	_fx = _FX_SCRIPT.new()   # el script extiende Node2D: sale ya siendo un Node2D
	_fx.position = piso.gen.centro_px(sitio["pared"])
	add_child(_fx)
	# El brote avisa mas y tiembla mas: es la unica pista de que viene algo gordo.
	var dur: float = aviso_dur * (2.2 if brote else 1.0)
	var amp: float = aviso_amp * (3.0 if brote else 1.0)
	var col: Color = Color(1.0, 0.35, 0.15) if brote else Color(0.85, 0.35, 0.30)
	_fx.iniciar(lado, dur, amp, col)

	_fx_t = dur
	_fx_suelo = piso.gen.centro_px(sitio["suelo"])
	_fx_cantidad = maxi(1, cantidad)


# Se acabo el aviso: la pared se abre y salen los bichos.
func _abrir_pared() -> void:
	if _fx != null:
		_fx.queue_free()
		_fx = null

	for i in range(_fx_cantidad):
		# Con varios, se abren un poco en abanico para no nacer uno encima de otro.
		var pos: Vector2 = _fx_suelo
		if i > 0:
			var ang: float = randf() * TAU
			pos += Vector2(cos(ang), sin(ang)) * randf_range(16.0, 40.0)
		if _nacer(pos) == null:
			break

	print("[parto] zona ", zona_idx, " (", tipo, ") -> ", _fx_cantidad,
		" | vivos en la zona ", _vivos.size(), "/", max_vivos)


# Crea UN bicho en 'pos' y lo suelta a merodear POR SU ZONA (no en un circulo alrededor
# del sitio donde nacio, que es lo que los dejaba pegados a la pared que los pario).
# Devuelve null si no cabe (tope de la zona, tope del piso o tabla vacia).
func _nacer(pos: Vector2, reciclar: bool = true):
	if _vivos.size() >= max_vivos or piso == null or not piso.hay_sitio(reciclar):
		return null
	var data: EnemyData = piso.elegir_enemigo()
	if data == null:
		return null
	var e = piso.crear_enemigo(data, pos, wander_radius)
	if e == null:
		return null
	e.zona_idx = zona_idx   # para devolverlo a SU zona al restaurar el piso
	if not puntos.is_empty():
		e.asignar_zona(puntos, hogar)
	_vivos.append(e)
	return e


# Una celda de parto al azar, descartando las que tengan al jugador encima. Devuelve {}
# si no queda ninguna valida (estas plantado justo donde iba a nacer: te libras).
func _elegir_celda() -> Dictionary:
	var jugador := get_tree().get_first_node_in_group("player")
	var pj: Vector2 = (jugador as Node2D).global_position if jugador is Node2D else Vector2.INF

	var validas: Array = []
	for p in partos:
		var suelo: Vector2 = piso.gen.centro_px(p["suelo"])
		if pj == Vector2.INF or suelo.distance_to(pj) >= dist_min_jugador:
			validas.append(p)
	if validas.is_empty():
		return {}
	return validas[randi() % validas.size()]


# POBLACION INICIAL: al entrar al piso, la mazmorra ya tiene bichos deambulando. Nacen
# SIN aviso de pared y de golpe (no los has visto nacer: llevan ahi desde antes que tu).
# Los partos son el goteo que viene DESPUES, encima de esto.
func poblar(n: int) -> void:
	for _i in range(n):
		# Los de casa no salen de una pared: aparecen sueltos POR LA ZONA, como si llevaran
		# ahi un rato. Se descartan los puntos pegados al jugador (no naces encima de el).
		var pos: Vector2 = _punto_libre()
		if pos == Vector2.INF or _nacer(pos, false) == null:
			return


# Un punto pisable de la zona, lejos del jugador Y de los bichos que ya estan puestos (si
# nacen amontonados se ven como un pegote y tardan en despegarse). Vector2.INF = no hay.
func _punto_libre() -> Vector2:
	if puntos.is_empty():
		return Vector2.INF
	var jugador := get_tree().get_first_node_in_group("player")
	var pj: Vector2 = (jugador as Node2D).global_position if jugador is Node2D else Vector2.INF

	var validos: Array = []
	for p in puntos:
		if pj != Vector2.INF and p.distance_to(pj) < dist_min_jugador:
			continue
		if _ocupado(p):
			continue
		validos.append(p)
	if validos.is_empty():
		return Vector2.INF
	return validos[randi() % validos.size()]


# ¿Hay ya un bicho de esta zona pegado a ese punto?
func _ocupado(p: Vector2) -> bool:
	for e in _vivos:
		if is_instance_valid(e) and p.distance_to(e.global_position) < separacion_min:
			return true
	return false


# Fuerza un parto YA (tecla de dev). n <= 0 = brote del tamaño configurado.
func forzar_parto(n: int = 1) -> void:
	var sitio: Dictionary = _elegir_celda()
	if sitio.is_empty():
		return
	var brote: bool = n > 1
	engendrar(sitio, maxi(1, n), brote)
