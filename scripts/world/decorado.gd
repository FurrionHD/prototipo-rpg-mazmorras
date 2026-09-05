# ============================================================
#  decorado.gd  (class_name Decorado)
#  QUE celdas del piso llevan musgo, agua o sumidero. Datos puros, ni un nodo: gemelo de
#  DungeonGenerator, que decide donde hay roca y donde suelo.
#
#  POR QUE ESTA SEPARADO DE dungeon_floor. Dos razones, y la segunda es la que importa:
#    1. dungeon_floor ya tiene 1800 lineas y esto no necesita nada del arbol de escena.
#    2. Se puede PROBAR SIN PARTIDA. La herramienta tools/ver_terreno.gd genera un piso de verdad
#       con DungeonGenerator, le pasa esto y saca un PNG para mirarlo, todo headless. Si la
#       decision de donde va el musgo viviera dentro del nodo, la unica forma de verla seria
#       arrancar el juego, entrar a una partida y bajar a la mazmorra.
#
#  TODO SALE DE LA SEMILLA DEL PISO, nunca de un randf() suelto. En multijugador el invitado
#  genera su mazmorra con la semilla del host, asi que ve el mismo musgo y el mismo riachuelo sin
#  que viaje un solo byte por la red.
# ============================================================

extends RefCounted
class_name Decorado

# { celda: true }. Se consultan tal cual para calcular la mascara de cada baldosa (una celda mira
# a sus vecinas de la MISMA capa para saber por donde tiene borde).
var musgo: Dictionary = {}
var agua: Dictionary = {}
var sumidero: Dictionary = {}
# EL LAGO. DISJUNTO de `agua`: son dos capas distintas porque el riachuelo CORRE y el lago esta en
# calma (ver TerrenoSprites._pintar_agua), y como se mueve una baldosa es cosa del TileSet, no del
# dibujo. La junta entre los dos no se ve igualmente, pero por otro motivo: la MASCARA de cada capa
# se calcula contra la UNION de las dos, asi que en la celda donde se tocan ninguna pone bit y
# ninguna dibuja orilla ni espuma. Ver DungeonFloor._pintar_capa.
#
# Y ademas responde otra pregunta: `agua` es "¿que baldosa pinto?", `lago` es "¿donde se pesca?",
# que es lo que necesitan la colision del charco, el lanzamiento y el nado de los peces.
var lago: Dictionary = {}
# Las celdas del lago que no tocan tierra por ninguno de sus cuatro lados: el CORAZON. De ahi sale
# la capa "hondo" (el velo de profundidad) y ahi nacen los peces, que es donde caben seguro.
var lago_hondo: Dictionary = {}
# Los musgos que han FLORECIDO: los unicos que dan luz. Es un subconjunto pequeño de `musgo`, no
# otra capa aparte (ver _sembrar_flores).
var flor: Dictionary = {}

var _gen: DungeonGenerator = null
var _estanque: Vector2i = Vector2i.MAX
var _estanque_tam: Vector2i = Vector2i.ZERO
# El lago engordado 3 celdas, para el barrido de manantiales de _trazar_agua (ver _en_estanque).
var _lago_d3: Dictionary = {}


func generar(gen: DungeonGenerator, celda_estanque: Vector2i, tam_estanque: Vector2i,
		sem: int, con_flores: bool = false) -> void:
	_gen = gen
	_estanque = celda_estanque
	_estanque_tam = tam_estanque
	musgo.clear()
	agua.clear()
	sumidero.clear()
	flor.clear()
	lago.clear()
	lago_hondo.clear()
	# EL LAGO ANTES QUE EL RIACHUELO, y por la misma razon por la que el agua va antes que el musgo:
	# el riachuelo tiene que saber a que celdas puede desembocar, y ahora esas celdas son las de
	# verdad y no un rectangulo teorico.
	_trazar_lago(sem)
	# EL AGUA DESPUES: el musgo mira donde ha quedado el reguero para criar en sus orillas.
	_trazar_agua(sem)
	_sembrar_musgo(sem)
	if con_flores:
		_sembrar_flores(sem)


# ============================================================
#  CONSULTAS DEL MAPA
# ============================================================

# Fuera del mapa cuenta como ROCA. Si contara como suelo, todo el borde del piso se dibujaria con
# su cara vista mirando al vacio.
static func es_roca(gen: DungeonGenerator, c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= gen.ancho or c.y >= gen.alto:
		return true
	return gen.es_solido(c)


# Solo se pinta (y solo cria musgo) la roca que TOCA suelo en alguna de las 8 direcciones: al
# relleno de dentro no llegas nunca y son miles de celdas. Es la misma regla que
# gen.muros_fusionados usa para la COLISION, y tiene que seguir siendo la misma o habria muros
# que se ven y no chocan.
static func muro_visible(gen: DungeonGenerator, c: Vector2i) -> bool:
	if not gen.es_solido(c):
		return false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			if gen.es_suelo(c + Vector2i(dx, dy)):
				return true
	return false


func _pega_a_roca(c: Vector2i) -> bool:
	return es_roca(_gen, c + Vector2i(1, 0)) or es_roca(_gen, c + Vector2i(-1, 0)) \
		or es_roca(_gen, c + Vector2i(0, 1)) or es_roca(_gen, c + Vector2i(0, -1))


# ¿Esta celda es lago, o esta a `margen` celdas de serlo? Ya NO es un Rect2i: el lago tiene forma,
# asi que la unica respuesta valida es la de sus celdas de verdad.
#
# Va por diccionarios DILATADOS precalculados y no dilatando en la consulta porque _trazar_agua la
# llama UNA VEZ POR CELDA DEL MAPA en su barrido de manantiales: con un margen de 3 eso serian 49
# lookups por celda de un mapa entero.
func _en_estanque(c: Vector2i, margen: int) -> bool:
	if lago.is_empty():
		return false
	if margen <= 0:
		return lago.has(c)
	if margen <= 3:
		return _lago_d3.has(c)
	return _dilatar(lago, margen).has(c)


# El lago engordado `margen` celdas en las 8 direcciones. Es la forma de preguntar "¿esto esta
# cerca del agua?" sin medir distancias: se engorda una vez y luego se consulta.
static func _dilatar(celdas: Dictionary, margen: int) -> Dictionary:
	var d: Dictionary = {}
	for c in celdas:
		for dy in range(-margen, margen + 1):
			for dx in range(-margen, margen + 1):
				d[c + Vector2i(dx, dy)] = true
	return d


# ============================================================
#  RUIDO A ESCALA DE MAPA
# ============================================================
# Valor suave 0..1 por CELDA, para manchas que abarcan varias celdas. Mismo truco que el ruido de
# TerrenoSprites pero a escala de mapa en vez de a escala de pixel.
static func _h01(x: int, y: int, sem: int) -> float:
	return float(hash(Vector3i(x, y, sem)) & 0xFFFF) / 65535.0


static func mancha(c: Vector2i, sem: int, escala: int) -> float:
	var fx: float = float(c.x) / float(escala)
	var fy: float = float(c.y) / float(escala)
	var x0: int = int(floor(fx))
	var y0: int = int(floor(fy))
	var tx: float = fx - float(x0)
	var ty: float = fy - float(y0)
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	return lerpf(
		lerpf(_h01(x0, y0, sem), _h01(x0 + 1, y0, sem), tx),
		lerpf(_h01(x0, y0 + 1, sem), _h01(x0 + 1, y0 + 1, sem), tx), ty)


# ============================================================
#  MUSGO: HAY SALAS MAS HUMEDAS QUE OTRAS
# ============================================================
# El musgo no se reparte parejo por el piso: cada ZONA (sala o pasillo) tiene su humedad, asi que
# te encuentras salas tomadas por el verde y otras secas. Es lo que hace que la mazmorra se lea
# como una cueva y no como un plano con textura encima.
const HUMEDAD_MIN := 0.55     # por debajo de esto la zona esta seca del todo
const RIBERA := 2             # celdas a cada lado del agua que cuentan como orilla
const RIBERA_HUMEDAD := 0.82  # lo humeda que es una orilla (0.82 -> cria, pero a manchas)

func _sembrar_musgo(sem: int) -> void:
	var humedad := PackedFloat32Array()
	humedad.resize(_gen.zonas.size())
	for z in _gen.zonas.size():
		humedad[z] = _h01(z, 0, sem + 4211)

	var en_suelo: Dictionary = {}
	for y in _gen.alto:
		for x in _gen.ancho:
			var c := Vector2i(x, y)
			if not _gen.es_suelo(c):
				continue
			# La RIBERA sube la humedad, pero NO la pone al maximo. Cuando la ribera era un "si"
			# absoluto, un pasillo estrecho con el riachuelo por el medio salia forrado de verde
			# de pared a pared: el musgo dejaba de ser una mancha y era el color del suelo.
			# Ahora la orilla es solo una zona MUY humeda, y sigue pasando por el mismo filtro de
			# manchas que todo lo demas.
			var h: float = RIBERA_HUMEDAD if _cerca_de_agua(c, RIBERA) else 0.0
			if h <= 0.0:
				var z: int = _gen.zona_en(c)
				if z < 0 or z >= humedad.size():
					continue
				h = humedad[z]
			if h < HUMEDAD_MIN:
				continue
			# Ni en la zona mas humeda es una alfombra: el musgo va a manchas.
			if mancha(c, sem + 77, 5) > h:
				continue
			en_suelo[c] = true

	# El musgo TREPA: la roca que toca suelo enmohecido se enmohece tambien. Sin esto el verde se
	# corta en seco justo en la linea de la pared y canta el recorte.
	for c in en_suelo:
		musgo[c] = true
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var v: Vector2i = c + Vector2i(dx, dy)
				if muro_visible(_gen, v) and mancha(v, sem + 91, 4) > 0.35:
					musgo[v] = true


func _cerca_de_agua(c: Vector2i, radio: int) -> bool:
	if agua.is_empty():
		return false
	for dy in range(-radio, radio + 1):
		for dx in range(-radio, radio + 1):
			if agua.has(c + Vector2i(dx, dy)):
				return true
	return false


# ============================================================
#  EL LAGO: UN CHARCO CON FORMA, NO UN RECTANGULO
# ============================================================
# Antes el charco era un rectangulo de 5x4 celdas, y se veia como lo que era. La forma sale de
# sumarle RUIDO A UNA ELIPSE: la elipse manda el contorno general (redondeado, centrado, sin
# esquinas) y el ruido de escala 3 -- el mismo `mancha()` que reparte el musgo -- le muerde lobulos
# y calas de dos o tres celdas, que es el tamaño al que una orilla se lee como orilla.
#
# EL AREA SE CONSERVA, y no es un detalle de estilo. `ESTANQUE_CELDAS` esta fijo a proposito: el
# minijuego de pesca se juega CONTRA el charco, y un charco de tamaño variable cambiaria el tiempo
# que tardan los peces en cruzarlo. Asi que el umbral del ruido no es un numero elegido a mano
# (que daria un lago distinto de tamaño con cada semilla, a veces el doble): se BUSCA POR
# BISECCION hasta que el area cae en la diana. La forma varia, el tamaño no.
#
# ES UNA FUNCION PURA Y ESTATICA (`forma_lago`) para que la herramienta tools/ver_terreno.gd pueda
# dibujar dieciseis lagos de dieciseis semillas sin montar una mazmorra. Y para que dibuje LOS
# MISMOS: un visor que calcula la forma por su cuenta no verifica nada.
const LAGO_HOLGURA := 1        # celdas que el lago puede salirse de la caja del estanque
const LAGO_RUIDO := 0.95       # cuanto muerde el ruido a la elipse. Mas alto = mas roto
const LAGO_ESCALA := 3         # celdas por lobulo del ruido
const LAGO_TOLERANCIA := 2     # celdas de mas o de menos que se aceptan sobre la diana

# `es_suelo` es un Callable y no un DungeonGenerator por lo mismo que TerrenoSprites.mascara toma
# un `soy`: asi el visor le pasa su mapa de juguete y esta funcion no depende de la mazmorra.
static func forma_lago(centro: Vector2i, tam: Vector2i, sem: int, es_suelo: Callable) -> Dictionary:
	if centro == Vector2i.MAX or tam == Vector2i.ZERO:
		return {}
	var mitad := Vector2i(tam.x / 2, tam.y / 2)
	var caja := Rect2i(centro - mitad, tam).grow(LAGO_HOLGURA)
	var diana: int = tam.x * tam.y
	# LOS SEMIEJES SON LOS DEL ESTANQUE, NO LOS DE LA CAJA, y esto costo una vuelta: con los de la
	# caja (que trae holgura) la elipse tenia area de sobra para la diana, asi que la biseccion
	# subia el umbral hasta cortar muy ADENTRO -- y adentro el gradiente de la elipse es fuerte, o
	# sea que el ruido no llegaba a moverlo. Salian dieciseis rectangulos redondeados.
	# Con la elipse del tamaño de la diana el corte cae cerca de su borde, donde la elipse es casi
	# plana y el ruido MANDA. La holgura deja de ser parte de la forma y pasa a ser lo que es: el
	# sitio por el que el lago puede desbordarse.
	var rx: float = float(tam.x) * 0.5
	var ry: float = float(tam.y) * 0.5
	var cx: float = float(centro.x)
	var cy: float = float(centro.y)

	# --- El campo: elipse + ruido. Se calcula UNA vez; la biseccion solo mueve el umbral ---
	var campo: Dictionary = {}
	for y in range(caja.position.y, caja.end.y):
		for x in range(caja.position.x, caja.end.x):
			var c := Vector2i(x, y)
			if not es_suelo.call(c):
				continue      # el lago no se mete en la roca
			var dx: float = (float(x) - cx) / rx
			var dy: float = (float(y) - cy) / ry
			var elipse: float = 1.0 - (dx * dx + dy * dy)
			campo[c] = elipse + (mancha(c, sem + 3301, LAGO_ESCALA) - 0.5) * LAGO_RUIDO

	# --- BISECCION sobre el umbral hasta clavar el area ---
	# Umbral ALTO = lago pequeño, asi que el area baja cuando el umbral sube: la biseccion va al
	# reves de lo habitual y por eso el `if` compara como compara.
	var bajo: float = -1.5
	var alto: float = 1.5
	var mejor: Dictionary = {}
	for _i in 14:
		var u: float = (bajo + alto) * 0.5
		var conjunto: Dictionary = _sanear_lago(campo, u, centro, caja, es_suelo)
		mejor = conjunto
		var area: int = conjunto.size()
		if absi(area - diana) <= LAGO_TOLERANCIA:
			break
		if area > diana:
			bajo = u      # sobra agua: hay que subir el umbral
		else:
			alto = u
	return mejor


# El conjunto de celdas por encima del umbral, ya CONEXO y ya limpio. Va dentro de la biseccion (y
# no despues) a proposito: el saneado quita y pone celdas, asi que el area que hay que medir es la
# de DESPUES de sanear. Saneando fuera del bucle, la biseccion clavaria un area que luego cambia.
static func _sanear_lago(campo: Dictionary, umbral: float, centro: Vector2i, caja: Rect2i,
		es_suelo: Callable) -> Dictionary:
	var crudo: Dictionary = {}
	for c in campo:
		if float(campo[c]) > umbral:
			crudo[c] = true
	# El centro SIEMPRE es agua: es donde se planta el charco, y ademas garantiza que el BFS de
	# abajo tenga de donde salir aunque el umbral se haya ido de las manos.
	if es_suelo.call(centro):
		crudo[centro] = true

	# --- CONEXO: solo la componente que toca el centro. Un lago en dos trozos son dos charcos ---
	var lag: Dictionary = {}
	var cola: Array[Vector2i] = [centro]
	lag[centro] = true
	var cabeza: int = 0
	while cabeza < cola.size():
		var c: Vector2i = cola[cabeza]
		cabeza += 1
		for l in _LADOS:
			var v: Vector2i = c + l
			if lag.has(v) or not crudo.has(v):
				continue
			lag[v] = true
			cola.append(v)

	# --- SANEADO hasta punto fijo. Dos reglas, y las dos son de LEGIBILIDAD, no de correccion ---
	#   1. Fuera los PELLIZCOS: una celda de agua con una sola vecina de agua es un dedo de 32 px
	#      que no se lee como lago, se lee como un fallo de tile.
	#   2. Dentro los AGUJEROS: una celda seca rodeada por LOS CUATRO lados es una isla de una celda
	#      en medio del charco. Ademas de imposible, es donde se atasca un pez al nadar.
	#      Con el umbral en TRES vecinas en vez de cuatro, esta regla se comia todas las CALAS: una
	#      entrada de tierra de una celda tiene tres lados mojados por definicion, asi que se
	#      rellenaba, y el lago volvia a salir redondeado. Justo lo que hay que conservar.
	for _pasada in 4:
		var cambio: bool = false
		for c in lag.keys():
			if _vecinas(lag, c) <= 1 and c != centro:
				lag.erase(c)
				cambio = true
		for c in lag.keys():
			for l in _LADOS:
				var v: Vector2i = c + l
				if lag.has(v) or not caja.has_point(v) or not es_suelo.call(v):
					continue
				if _vecinas(lag, v) == 4:
					lag[v] = true
					cambio = true
		if not cambio:
			break
	return lag


static func _vecinas(celdas: Dictionary, c: Vector2i) -> int:
	var n: int = 0
	for l in _LADOS:
		if celdas.has(c + l):
			n += 1
	return n


# El CORAZON del lago: las celdas con las cuatro vecinas mojadas. Es donde el agua es honda (de ahi
# sale la capa "hondo") y donde un pez cabe seguro sin asomar el morro por la orilla.
static func nucleo_lago(lag: Dictionary) -> Dictionary:
	var n: Dictionary = {}
	for c in lag:
		if _vecinas(lag, c) == 4:
			n[c] = true
	return n


func _trazar_lago(sem: int) -> void:
	if _estanque == Vector2i.MAX:
		return
	lago = forma_lago(_estanque, _estanque_tam, sem,
		func(c: Vector2i) -> bool: return _gen.es_suelo(c))
	if lago.is_empty():
		return
	lago_hondo = nucleo_lago(lago)
	# Un lago tan fino que no tiene corazon: se le da el centro, que es donde se planta el charco.
	# Sin esto, _nacer_pez se quedaria sin sitios de donde elegir.
	if lago_hondo.is_empty():
		lago_hondo[_estanque] = true
	_lago_d3 = _dilatar(lago, 3)


# ============================================================
#  AGUA: EL RIACHUELO NUNCA TERMINA EN SECO
# ============================================================
# Regla de diseño, no un detalle: un reguero que sale de una pared y se corta a media sala se ve
# roto. Siempre tiene los DOS extremos resueltos:
#     NACE  en una pared (una celda de suelo pegada a la roca: se lee como que mana de ahi)
#     MUERE en el lago, metiendose en OTRA pared, o por un SUMIDERO.
#
# El trazado es un camino MINIMO por celdas pisables, asi que el reguero rodea la roca en vez de
# atravesarla. Y como el destino es siempre uno de los tres finales validos, la regla se cumple
# POR CONSTRUCCION: no hay que comprobarla despues ni hay caso en que se incumpla.
const PROB_CON_LAGO := 0.70
const PROB_SIN_LAGO := 0.35
const LARGO_MIN := 10         # celdas: mas corto que esto no se lee como riachuelo

const _LADOS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

func _trazar_agua(sem: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sem, "agua"])
	var hay_lago: bool = _estanque != Vector2i.MAX
	if rng.randf() > (PROB_CON_LAGO if hay_lago else PROB_SIN_LAGO):
		return

	# --- Manantiales candidatos: suelo pegado a la roca ---
	var brotes: Array[Vector2i] = []
	for y in _gen.alto:
		for x in _gen.ancho:
			var c := Vector2i(x, y)
			if not _gen.es_suelo(c) or not _pega_a_roca(c):
				continue
			if hay_lago and _en_estanque(c, 3):
				continue      # que no nazca dentro del propio charco
			brotes.append(c)
	if brotes.is_empty():
		return
	var origen: Vector2i = brotes[rng.randi_range(0, brotes.size() - 1)]

	# --- Camino minimo por suelo desde el manantial ---
	var padre: Dictionary = {origen: origen}
	var dist: Dictionary = {origen: 0}
	var cola: Array[Vector2i] = [origen]
	var cabeza: int = 0
	var destino: Vector2i = Vector2i.MAX
	var lejano: Vector2i = origen
	while cabeza < cola.size():
		var c: Vector2i = cola[cabeza]
		cabeza += 1
		var d: int = int(dist[c])
		if d > int(dist[lejano]):
			lejano = c
		if hay_lago and _en_estanque(c, 0):
			destino = c       # llegar al lago cierra el recorrido
			break
		for l in _LADOS:
			var v: Vector2i = c + l
			if padre.has(v) or not _gen.es_suelo(v):
				continue
			padre[v] = c
			dist[v] = d + 1
			cola.append(v)

	# --- Sin lago: o se mete por otra pared, o se cuela por un sumidero ---
	var por_sumidero: bool = false
	if destino == Vector2i.MAX:
		if int(dist.get(lejano, 0)) < LARGO_MIN:
			return            # no da para un riachuelo que se lea: mejor ninguno
		destino = lejano
		# 'lejano' es el punto mas alejado del manantial, o sea un fondo de saco: casi siempre
		# esta pegado a roca, y eso YA es un final valido (el agua se mete por la pared). Cuando
		# no lo esta, se le pone el sumidero, que es la tercera salida.
		por_sumidero = not _pega_a_roca(destino)

	# --- Reconstruir el cauce ---
	var c2: Vector2i = destino
	var guarda: int = 0
	while guarda < 8192:
		guarda += 1
		agua[c2] = true
		if c2 == origen:
			break
		c2 = padre[c2]
	if por_sumidero:
		sumidero[destino] = true


# ============================================================
#  LAS FLORES QUE ALUMBRAN
# ============================================================
# NO brilla el musgo: brillan unas FLORES que le salen a algunos musgos. La diferencia no es de
# sabor -- si brillara el musgo entero, una sala forrada de verde seria de dia y el farolillo
# sobraria; asi lo que alumbra son unos pocos puntos concretos y el farol sigue siendo el que te
# deja ver.
#
# Se eligen por REJILLA y no celda a celda con un dado: por cada bloque de LUZ_REJILLA celdas sale
# como mucho una flor, la del ruido mas alto del bloque. Eso hace dos cosas que un dado suelto no
# hace: acota cuantas hay (no puede salir una sala llena por mala suerte) y garantiza que nunca
# haya dos pegadas, o sea que sus halos no se suman.
const LUZ_REJILLA := 6      # una flor como mucho cada 6x6 celdas
const LUZ_PROB := 0.5       # y no en todos los bloques

func _sembrar_flores(sem: int) -> void:
	# El mejor candidato de cada bloque: { bloque -> [celda, cuanto puntua] }.
	var mejor: Dictionary = {}
	for c in musgo:
		var b := Vector2i(int(c.x) / LUZ_REJILLA, int(c.y) / LUZ_REJILLA)
		var v: float = _h01(int(c.x), int(c.y), sem + 1302)
		if not mejor.has(b) or v > float(mejor[b][1]):
			mejor[b] = [c, v]
	for b in mejor:
		# Y ni siquiera todos los bloques con musgo florecen.
		if _h01(int(b.x), int(b.y), sem + 1301) >= LUZ_PROB:
			continue
		flor[mejor[b][0]] = true
