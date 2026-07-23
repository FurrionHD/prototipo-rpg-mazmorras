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

# MULTIJUGADOR (hito 5.3): distancia minima MUCHO mayor alrededor de quien esta PELEANDO. En multi
# el mundo no se para, asi que las paredes siguen pariendo mientras alguien esta en combate — y eso
# se quiere (la mazmorra sigue viva). Lo que no se quiere es plantarle un bicho en las narices a
# alguien metido en una pantalla donde no puede ni verlo venir. Asi que los partos se ALEJAN de el,
# no se paran. Si aun asi le nace uno cerca, se une a su pelea (ver dungeon_floor).
const DIST_MIN_PELEANDO := 260.0

# --- Separacion minima entre bichos al nacer (px) ---
# 48 = celda y media. Ya no se empujan entre ellos (no colisionan), pero nacer amontonados
# se ve como un pegote unico y no como varios enemigos.
var separacion_min: float = 48.0

# A que distancia del jugador un GOTEO normal cuenta como "cerca" (a la vista): si sale mas cerca
# que esto y el piso esta lleno, fuerza el reciclado del mas lejano para nacer igual (como el
# brote). Mismo orden que el RADIO_ACTIVO de enemy_links. Tunable.
const RECICLA_CERCA := 700.0

# --- BROTE MASIVO ---
# De vez en cuando una pared no pare uno, sino un TRAMO GORDO de golpe: revienta un cacho de muro y
# salen varios EMBISTIENDO. El disparador de verdad es el medidor de alboroto (Game); esto es la
# pizca de azar que queda encima, para que ir siempre en sigilo no te haga inmune.
var brotes_activos: bool = true
var prob_brote: float = 0.01    # ~1 de cada 100 partos (brote espontaneo; el gordo lo trae el alboroto)

# Tamaño del brote = tu grupo + 1, con tope MAX_COMBATIENTES (lo que cabe en una pelea): vas solo,
# salen 2; con tres, salen 4. Siempre te superan por uno, nunca es una masacre imposible.
func brote_tamano() -> int:
	return mini(Enemy.MAX_COMBATIENTES, Game.party.size() + 1)

# Enemigos vivos que ha parido ESTA zona. Sin tipar el elemento: los enemigos exponen
# metodos propios (esta_muerto) que un Array[Node] no dejaria llamar.
var _vivos: Array = []
var _espera: float = 0.0

# Parto en curso (la pared ya esta avisando). El FX tambien va sin tipar (ver 'piso').
var _fx = null
var _fx_t: float = 0.0
# Los puntos de suelo donde van a caer los bichos (uno por celda del tramo). En un parto normal es
# uno solo; en un brote, varios (el tramo de pared que ha reventado).
var _fx_suelos: Array = []
# ¿El parto en curso es un BROTE? Si lo es, los bichos salen EMBISTIENDO, no a merodear.
var _fx_brote: bool = false
# ¿Este parto FUERZA el reciclado del mas lejano si el piso esta lleno? True en los brotes
# (siempre) y en el goteo normal que sale CERCA del jugador (para que nazca en tus narices).
var _fx_forzar: bool = false

const _FX_SCRIPT := preload("res://scripts/world/wall_birth_fx.gd")
const Enemy := preload("res://scripts/actors/enemy/enemy.gd")


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
	# Ocupacion REAL de la sala (los que pario ella MAS los que se le han mudado por manada), no
	# solo _vivos: si no, una sala llena de migrantes seguia pariendo por encima de su aforo.
	if piso.enemigos_en_zona(zona_idx) >= max_vivos:
		return            # la zona esta llena: calla hasta que mates a alguno
	var sitio: Dictionary = _elegir_celda()
	if sitio.is_empty():
		return            # todas las celdas estan pegadas al jugador: esperamos

	# CERCA del jugador (a la vista): si el piso esta lleno se recicla al mas lejano para que nazca
	# en tus narices, igual que un brote. LEJOS (no lo ves): reciclado normal, con su liston.
	var cerca: bool = _cerca_del_jugador(sitio)
	if not piso.hay_sitio(true, cerca):
		return            # el piso entero esta al tope y no habia a quien reciclar

	var brote: bool = brotes_activos and randf() < prob_brote
	var cantidad: int = brote_tamano() if brote else 1
	engendrar(sitio, cantidad, brote, cerca)


# Arranca un parto en una celda concreta. Publico para poder forzarlo (brote de prueba
# desde una tecla de dev).
# Un parto NORMAL abre una celda y pare uno. Un BROTE abre un TRAMO GORDO de pared (varias celdas
# contiguas) y pare uno por celda, todos EMBISTIENDO: ese es el momento de "esto se ha torcido".
func engendrar(sitio: Dictionary, cantidad: int, brote: bool = false, forzar_reciclado: bool = false) -> void:
	if _fx != null or piso == null:
		return
	var lado: float = float(DungeonGenerator.CELDA)
	# Las celdas que se abren: una sola, o un tramo de pared del tamaño del brote.
	var celdas: Array = [sitio]
	if brote and cantidad > 1:
		celdas = _tramo_de_pared(sitio, cantidad)
	# Los centros (en mundo) de cada celda de ROCA, para el aviso; y de cada celda de SUELO, para
	# donde caen los bichos.
	var paredes_px: Array = []
	_fx_suelos = []
	for c in celdas:
		paredes_px.append(piso.gen.centro_px(c["pared"]))
		_fx_suelos.append(piso.gen.centro_px(c["suelo"]))

	_fx = _FX_SCRIPT.new()   # el script extiende Node2D: sale ya siendo un Node2D
	_fx.position = paredes_px[0]
	add_child(_fx)
	# El brote avisa mas y tiembla mas: es la unica pista de que viene algo gordo.
	var dur: float = aviso_dur * (2.2 if brote else 1.0)
	var amp: float = aviso_amp * (3.0 if brote else 1.0)
	var col: Color = Color(1.0, 0.35, 0.15) if brote else Color(0.85, 0.35, 0.30)
	_fx.iniciar_tramo(lado, dur, amp, col, paredes_px)

	_fx_t = dur
	_fx_brote = brote
	# El brote fuerza siempre; el goteo, solo si sale cerca del jugador.
	_fx_forzar = brote or forzar_reciclado


# El TRAMO de pared que revienta un brote: a partir de una celda de parto, se extiende por las
# celdas de parto CONTIGUAS (pegadas de lado) hasta juntar 'n'. Es un cacho conexo de muro, no
# celdas sueltas por la sala. Si la pared no da para tanto (una esquina), se para donde pueda: el
# brote sale igual, solo que mas apretado.
func _tramo_de_pared(inicio: Dictionary, n: int) -> Array:
	var por_pared: Dictionary = {}   # Vector2i de roca -> su parto {pared, suelo}
	for p in partos:
		por_pared[p["pared"]] = p
	var out: Array = [inicio]
	var usados: Dictionary = {inicio["pared"]: true}
	var frontera: Array = [inicio["pared"]]
	while out.size() < n and not frontera.is_empty():
		var actual: Vector2i = frontera.pop_front()
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var vec: Vector2i = actual + d
			if por_pared.has(vec) and not usados.has(vec):
				usados[vec] = true
				out.append(por_pared[vec])
				frontera.append(vec)
				if out.size() >= n:
					break
	return out


# Se acabo el aviso: la pared se abre y salen los bichos, uno por celda del tramo.
func _abrir_pared() -> void:
	if _fx != null:
		_fx.queue_free()
		_fx = null

	var nacidos: int = 0
	for suelo in _fx_suelos:
		# El brote se SALTA el aforo de la sala (max_vivos): es un evento, no el goteo normal. El
		# tope del PISO si se respeta (lo mira _nacer via piso.hay_sitio), que es el que cuida el
		# rendimiento. Un parto normal si obedece el aforo. Ademas, en un brote se fuerza el
		# reciclado (forzar = _fx_forzar): si el piso esta lleno, borra al mas lejano para que el
		# brote entre COMPLETO -o el goteo cercano nazca- en vez de quedarse sin sitio.
		var e = _nacer(suelo, true, _fx_brote, _fx_forzar)
		if e == null:
			break            # tope del piso: no cabe ninguno mas
		nacidos += 1
		# En un brote NO se merodea: se sale directo a por el grupo.
		if _fx_brote and e.has_method("nacer_embistiendo"):
			e.nacer_embistiendo()

	var etiqueta: String = "BROTE" if _fx_brote else "parto"
	print("[", etiqueta, "] zona ", zona_idx, " (", tipo, ") -> ", nacidos,
		" | vivos en la zona ", _vivos.size(), "/", max_vivos)
	_fx_brote = false
	_fx_forzar = false


# Crea UN bicho en 'pos' y lo suelta a merodear POR SU ZONA (no en un circulo alrededor
# del sitio donde nacio, que es lo que los dejaba pegados a la pared que los pario).
# Devuelve null si no cabe (tope de la zona, tope del piso o tabla vacia).
func _nacer(pos: Vector2, reciclar: bool = true, saltar_aforo: bool = false, forzar: bool = false):
	if piso == null or not piso.hay_sitio(reciclar, forzar):
		return null
	if not saltar_aforo and _vivos.size() >= max_vivos:
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


# ¿El parto de 'sitio' sale CERCA del jugador (a la vista)? Mide la celda de SUELO donde caeria el
# bicho contra la posicion del jugador. Sin jugador en escena (pruebas) se considera que NO.
func _cerca_del_jugador(sitio: Dictionary) -> bool:
	if piso == null or sitio.is_empty():
		return false
	var jugador := get_tree().get_first_node_in_group("player")
	if not (jugador is Node2D):
		return false
	var suelo: Vector2 = piso.gen.centro_px(sitio["suelo"])
	return suelo.distance_to((jugador as Node2D).global_position) <= RECICLA_CERCA


# TODOS los jugadores de este piso (el mio y los remotos en multi), con la distancia minima que
# hay que respetarle a cada uno: la de siempre, o DIST_MIN_PELEANDO si esta en combate.
func _puestos_a_respetar() -> Array:
	var out: Array = []
	var jugador := get_tree().get_first_node_in_group("player")
	if jugador is Node2D:
		var d: float = DIST_MIN_PELEANDO if Game.combate_activo() else dist_min_jugador
		out.append([(jugador as Node2D).global_position, d])
	for r in Net.jugadores_remotos_aqui():
		out.append([r["pos"], DIST_MIN_PELEANDO if r["peleando"] else dist_min_jugador])
	return out


# ¿'punto' respeta el espacio de todos los jugadores?
func _libre_de_jugadores(punto: Vector2, puestos: Array) -> bool:
	for p in puestos:
		if punto.distance_to(p[0]) < float(p[1]):
			return false
	return true


# Una celda de parto al azar, descartando las que tengan un jugador encima (y dando MUCHO mas aire
# a quien este peleando). Devuelve {} si no queda ninguna valida: te libras de este parto.
func _elegir_celda() -> Dictionary:
	var puestos: Array = _puestos_a_respetar()
	var validas: Array = []
	for p in partos:
		if _libre_de_jugadores(piso.gen.centro_px(p["suelo"]), puestos):
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
	var puestos: Array = _puestos_a_respetar()

	var validos: Array = []
	for p in puntos:
		if not _libre_de_jugadores(p, puestos):
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


# Provoca un BROTE en una celda de parto CONCRETA (la elige el piso: la que te pilla a la vista).
# Lo llama el piso, tanto desde la tecla de dev como desde el medidor de alboroto. El tamaño es el
# de siempre (tu grupo + 1). Devuelve false si ya hay un parto en curso en esta zona.
func brotar_en(sitio: Dictionary) -> bool:
	if _fx != null or sitio.is_empty():
		return false
	engendrar(sitio, brote_tamano(), true)
	return true
