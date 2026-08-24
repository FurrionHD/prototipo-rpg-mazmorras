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

var _gen: DungeonGenerator = null
var _estanque: Vector2i = Vector2i.MAX
var _estanque_tam: Vector2i = Vector2i.ZERO


func generar(gen: DungeonGenerator, celda_estanque: Vector2i, tam_estanque: Vector2i,
		sem: int) -> void:
	_gen = gen
	_estanque = celda_estanque
	_estanque_tam = tam_estanque
	musgo.clear()
	agua.clear()
	sumidero.clear()
	# EL AGUA PRIMERO: el musgo mira donde ha quedado el reguero para criar en sus orillas.
	_trazar_agua(sem)
	_sembrar_musgo(sem)


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


func _en_estanque(c: Vector2i, margen: int) -> bool:
	if _estanque == Vector2i.MAX:
		return false
	var mitad := Vector2i(_estanque_tam.x / 2, _estanque_tam.y / 2)
	var r := Rect2i(_estanque - mitad, _estanque_tam).grow(margen)
	return r.has_point(c)


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
