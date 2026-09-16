# ============================================================
#  pueblo_plano.gd  (class_name PuebloPlano)
#  EL PLANO DEL PUEBLO, como DATOS. Aqui no se dibuja ni se crea ningun nodo: se dice que hay en cada
#  casilla (calle, hierba, muralla, agua, madera) y donde esta cada casa con su puerta.
#
#  Existe como archivo aparte por la misma leccion que el registro de sprites (SpritesEnemigo): la
#  escena del pueblo (town.gd) y el visor (tools/visores/dev_pueblo.gd) leen de AQUI. Si cada uno
#  tuviera su copia del plano, el visor enseñaria un pueblo que no es el del juego.
#
#  Decidido con el usuario el 16/09/2026 (ver la memoria pueblo-visual-plan):
#    - plano en CRUZ, calles de baldosa, plaza en el centro con la escalera de caracol a la mazmorra;
#    - el HOGAR arriba: casa -> camino de piedra -> claro con el altar (una columna) -> calle, con
#      jardin y verjas, y casas de relleno a los lados;
#    - al sur el agua, con el PESCADOR sobre una plataforma de madera a la que se llega por un muelle;
#    - al norte, este y oeste, murallas con portones cerrados.
#
#  Las coordenadas van en CASILLAS (32 px, la misma rejilla que la mazmorra).
# ============================================================

extends RefCounted
class_name PuebloPlano

const CELDA := 32

const ANCHO := 50
const ALTO := 54

# Lo que puede haber en una casilla. El SUELO que se pinta y si se puede pisar salen de aqui.
enum Suelo { HIERBA, CALLE, MURALLA, AGUA, MADERA }

# Donde empieza el agua (fila). Por encima, tierra firme; por debajo, lago hasta el borde del mapa.
const ORILLA := 40

# ------------------------------------------------------------
#  CALLES (baldosa de piedra). Rectangulos que se pisan.
# ------------------------------------------------------------
const CALLES := [
	Rect2i(2, 24, 46, 3),     # la calle mayor, de porton a porton (oeste-este)
	Rect2i(2, 15, 46, 2),     # la calle alta, delante del hogar y de las casas de relleno
	Rect2i(2, 33, 46, 2),     # la calle baja
	Rect2i(23, 17, 3, 7),     # de la calle alta a la plaza
	Rect2i(23, 27, 3, 13),    # de la plaza a la orilla (y al muelle)
	Rect2i(2, 39, 46, 1),     # el paseo de la orilla, donde dan las casas de abajo
	Rect2i(20, 21, 9, 9),     # LA PLAZA
	Rect2i(24, 7, 1, 1),      # el camino de piedra del hogar (casa -> claro), estrecho
	Rect2i(23, 13, 3, 2),     # la ENTRADA al hogar (claro -> calle), de 3 como la calle de la plaza
	Rect2i(22, 8, 5, 5),      # el claro del altar
]

const PLAZA := Rect2i(20, 21, 9, 9)

# La ESCALERA DE CARACOL que baja a la mazmorra, en el centro de la plaza. Solida: la F se pulsa
# desde su boca, en el lado sur.
const ESCALERA := Rect2i(23, 24, 3, 3)

# ------------------------------------------------------------
#  EL RECINTO DEL HOGAR: jardin con verjas. La verja va por el borde del rectangulo, con UN hueco
#  abajo por donde sale el camino.
# ------------------------------------------------------------
const JARDIN := Rect2i(19, 2, 11, 13)
# La entrada de la verja: 3 de ancho, alineada con la calle que sube de la plaza (lo pidio el usuario).
const JARDIN_HUECO := Rect2i(23, 14, 3, 1)
const ALTAR := Vector2i(24, 10)

# ------------------------------------------------------------
#  EL MUELLE Y LA PLATAFORMA DEL PESCADOR (madera sobre el agua).
# ------------------------------------------------------------
const MUELLE := Rect2i(23, ORILLA, 3, 4)
const PLATAFORMA := Rect2i(21, 44, 7, 7)

# ------------------------------------------------------------
#  MURALLAS Y PORTONES. La muralla es la casilla entera; el porton es un trozo de ella que se
#  dibujara distinto (cerrado, sin paso: los guardias vendran con la gente del pueblo).
# ------------------------------------------------------------
const MURALLAS := [
	Rect2i(0, 0, ANCHO, 2),          # norte
	Rect2i(0, 0, 2, ORILLA),         # oeste
	Rect2i(ANCHO - 2, 0, 2, ORILLA), # este
]

const PORTONES := [
	{"lado": "norte", "rect": Rect2i(23, 0, 3, 2)},
	{"lado": "oeste", "rect": Rect2i(0, 24, 2, 3)},
	{"lado": "este", "rect": Rect2i(ANCHO - 2, 24, 2, 3)},
]

# ------------------------------------------------------------
#  LAS CASAS
#  'rect'   = la HUELLA en casillas (lo que choca). El dibujo sobresale hacia arriba (tejado).
#  'puerta' = la casilla de delante de la puerta, al sur de la fachada. Ahi va el nodo con el script
#             del oficio, que es el mismo de siempre (grupo "interactable").
#  'script' = vacio en las casas de relleno: no abren nada todavia.
#
#  Tamaños por importancia (decision del usuario): hogar, taberna y tienda 5x4; los talleres 4x3;
#  maestro y pescador 3x3; relleno 3x3.
#
#  TODAS PEGADAS A SU CALLE (lo pidio el usuario mirando el juego): entre la fachada y la calle queda
#  UNA casilla, la de la puerta, y esa casilla va enlosada (ver es_camino) para que la puerta conecte
#  con la calle.
# ------------------------------------------------------------
const CASAS := [
	{"clave": "hogar", "nombre": "HOGAR", "rect": Rect2i(22, 3, 5, 4), "script": "res://scripts/town/hogar.gd"},
	{"clave": "boticaria", "nombre": "BOTICARIA", "rect": Rect2i(5, 20, 4, 3), "script": "res://scripts/town/boticaria.gd"},
	{"clave": "maestro", "nombre": "MAESTRO", "rect": Rect2i(13, 20, 3, 3), "script": "res://scripts/town/maestro.gd"},
	{"clave": "tienda", "nombre": "TIENDA", "rect": Rect2i(31, 19, 5, 4), "script": "res://scripts/town/shop.gd"},
	{"clave": "herreria", "nombre": "HERRERÍA", "rect": Rect2i(40, 20, 4, 3), "script": "res://scripts/town/herrero.gd"},
	{"clave": "cocina", "nombre": "COCINA", "rect": Rect2i(5, 29, 4, 3), "script": "res://scripts/town/cocinero.gd"},
	{"clave": "taberna", "nombre": "TABERNA", "rect": Rect2i(31, 28, 5, 4), "script": "res://scripts/town/taberna.gd"},
	{"clave": "carpinteria", "nombre": "CARPINTERÍA", "rect": Rect2i(40, 29, 4, 3), "script": "res://scripts/town/carpintero.gd"},
	{"clave": "peleteria", "nombre": "PELETERÍA", "rect": Rect2i(40, 35, 4, 3), "script": "res://scripts/town/peletero.gd"},
	{"clave": "pescador", "nombre": "PESCADOR", "rect": Rect2i(23, 46, 3, 3), "script": "res://scripts/town/pescador.gd"},
	# Relleno: a los lados del hogar, una fila por lado pegada a la calle alta.
	{"clave": "vacia", "rect": Rect2i(3, 11, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(8, 11, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(13, 11, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(33, 11, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(38, 11, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(43, 11, 3, 3)},
	# Relleno: los barrios del sur.
	{"clave": "vacia", "rect": Rect2i(13, 29, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(5, 35, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(13, 35, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(31, 35, 3, 3)},
]


# La casilla de delante de la puerta: centrada bajo la fachada (en las de ancho par, la de la
# derecha del centro).
static func puerta_de(casa: Dictionary) -> Vector2i:
	var r: Rect2i = casa["rect"]
	return Vector2i(r.position.x + r.size.x / 2, r.end.y)


static func dentro(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < ANCHO and c.y < ALTO


static func tam_px() -> Vector2:
	return Vector2(ANCHO, ALTO) * CELDA


static func centro_px(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * CELDA


# Donde aparece el jugador al llegar al pueblo: en la plaza, delante de la boca de la escalera.
static func aparicion_px() -> Vector2:
	return centro_px(Vector2i(ESCALERA.position.x + 1, ESCALERA.end.y + 1))


# El SUELO de cada casilla, calculado una vez. Lo que va despues pisa a lo de antes: el agua se come
# la hierba, el muelle se come el agua, la muralla va por encima de todo.
static var _suelos: PackedByteArray = PackedByteArray()

static func suelo(c: Vector2i) -> int:
	if not dentro(c):
		return Suelo.AGUA if c.y >= ORILLA else Suelo.MURALLA
	if _suelos.is_empty():
		_suelos.resize(ANCHO * ALTO)
		for y in ALTO:
			for x in ANCHO:
				_suelos[y * ANCHO + x] = _calcular_suelo(Vector2i(x, y))
	return _suelos[c.y * ANCHO + c.x]


static func _calcular_suelo(c: Vector2i) -> int:
	if MUELLE.has_point(c) or PLATAFORMA.has_point(c):
		return Suelo.MADERA
	if c.y >= ORILLA:
		return Suelo.AGUA
	for r in MURALLAS:
		if (r as Rect2i).has_point(c):
			return Suelo.MURALLA
	if _en_calle(c) or es_camino(c):
		return Suelo.CALLE
	return Suelo.HIERBA


static func _en_calle(c: Vector2i) -> bool:
	for r in CALLES:
		if (r as Rect2i).has_point(c):
			return true
	return false


# EL CAMINO DE CADA PUERTA: las casillas de piedra desde la puerta hacia abajo hasta dar con una calle.
# Hoy es una sola (todas las casas estan pegadas a su calle), pero si alguna se separa, el camino se
# alarga solo y la puerta no se queda en mitad de la hierba.
const CAMINO_MAX := 4

static func es_camino(c: Vector2i) -> bool:
	for casa in CASAS:
		var p: Vector2i = puerta_de(casa)
		if c.x != p.x or c.y < p.y or c.y >= p.y + CAMINO_MAX:
			continue
		var hay_calle: bool = false
		for k in range(p.y, c.y + 1):
			if k > p.y and _en_calle(Vector2i(c.x, k)):
				hay_calle = true
		if not hay_calle and not _en_calle(c):
			return true
	return false


# Las casillas de VERJA: el borde del jardin menos el hueco del camino. La fila de arriba no lleva,
# que ahi ya esta la muralla.
static func es_verja(c: Vector2i) -> bool:
	if not JARDIN.has_point(c) or JARDIN_HUECO.has_point(c):
		return false
	if c.y == JARDIN.position.y:
		return false
	return c.x == JARDIN.position.x or c.x == JARDIN.end.x - 1 or c.y == JARDIN.end.y - 1


# ¿Choca esta casilla? Muralla, agua (menos la madera), verjas, casas, escalera y el pie del altar.
static func solida(c: Vector2i) -> bool:
	var s: int = suelo(c)
	if s == Suelo.MURALLA or s == Suelo.AGUA:
		return true
	if es_verja(c) or c == ALTAR or ESCALERA.has_point(c):
		return true
	for casa in CASAS:
		if (casa["rect"] as Rect2i).has_point(c):
			return true
	return false


# Rectangulos de choque FUNDIDOS (tiras horizontales unidas hacia abajo), como hace la mazmorra con
# sus muros: un par de centenares de cajas en vez de mil y pico.
static func solidos_fusionados() -> Array[Rect2i]:
	var usado := {}
	var out: Array[Rect2i] = []
	for y in ALTO:
		var x: int = 0
		while x < ANCHO:
			var c := Vector2i(x, y)
			if not solida(c) or usado.has(c):
				x += 1
				continue
			var w: int = 0
			while x + w < ANCHO and solida(Vector2i(x + w, y)) and not usado.has(Vector2i(x + w, y)):
				w += 1
			var h: int = 1
			var sigue: bool = true
			while sigue and y + h < ALTO:
				for i in w:
					var d := Vector2i(x + i, y + h)
					if not solida(d) or usado.has(d):
						sigue = false
						break
				if sigue:
					h += 1
			for j in h:
				for i in w:
					usado[Vector2i(x + i, y + j)] = true
			out.append(Rect2i(x, y, w, h))
			x += w
	return out
