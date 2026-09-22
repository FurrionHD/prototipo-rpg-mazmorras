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
#  EL PUEBLO CRECIO el 22/09/2026 (lo pidio el usuario, para meter mas casas y luego aldeanos): todo lo
#  de antes se corrio 12 casillas al este y 13 al sur, y quedo en el centro. Las casas del norte van
#  pegadas a la muralla, con el hueco justo para su tejado (con mas, quedaba un prado vacio). Alrededor, un BARRIO NORTE
#  (calle norte, cuartel de los guardias, casas y el porton de la arena, al que se llega por dos caminos
#  a los lados del hogar) y dos barrios nuevos al este y al oeste. El jardin del hogar se cerro por
#  arriba con verja: antes daba a la muralla y a la arena se entraba por encima de la casa.
#
#  Las coordenadas van en CASILLAS (32 px, la misma rejilla que la mazmorra).
# ============================================================

extends RefCounted
class_name PuebloPlano

const CELDA := 32

const ANCHO := 74
const ALTO := 67

# Lo que puede haber en una casilla. El SUELO que se pinta y si se puede pisar salen de aqui.
enum Suelo { HIERBA, CALLE, MURALLA, AGUA, MADERA }

# Donde empieza el agua (fila). Por encima, tierra firme; por debajo, lago hasta el borde del mapa.
const ORILLA := 53

# ------------------------------------------------------------
#  LOS DOS PRADOS DEL NORTE, a los lados del jardin del hogar (pedido del usuario el 22/09/2026): al
#  oeste la PLAZA DE LA FUENTE (bancos, arbolitos, parterres) y al este el MERCADILLO. Los dos van
#  enlosados y dan a la calle norte.
# ------------------------------------------------------------
const PARQUE := Rect2i(8, 12, 17, 9)
# 3x2: a 45 grados el pilon redondo se ve como una elipse de 88 x 62 (ver PlazaSprites).
const FUENTE := Rect2i(15, 15, 3, 2)
# Su caja de choque (px desde la esquina de su huella): la planta del pilon.
const CAJA_FUENTE := Rect2(6, 4, 84, 58)
# Una sola fila de puestos (filas 14-15) con su pasillo delante: lo enlosado acaba ahi.
const MERCADO := Rect2i(47, 12, 21, 6)

# ------------------------------------------------------------
#  CALLES (baldosa de piedra). Rectangulos que se pisan.
# ------------------------------------------------------------
const CALLES := [
	PARQUE,
	MERCADO,
	Rect2i(2, 37, 70, 3),     # la calle mayor, de porton a porton (oeste-este)
	Rect2i(2, 28, 70, 2),     # la calle alta, delante del hogar y de las casas de relleno
	Rect2i(2, 46, 70, 2),     # la calle baja
	Rect2i(2, 10, 70, 2),     # la calle norte, la del cuartel
	Rect2i(35, 30, 3, 7),     # de la calle alta a la plaza
	Rect2i(35, 40, 3, 13),    # de la plaza a la orilla (y al muelle)
	Rect2i(2, 52, 70, 1),     # el paseo de la orilla, donde dan las casas de abajo
	Rect2i(32, 34, 9, 9),     # LA PLAZA
	Rect2i(36, 21, 1, 1),     # el camino de piedra del hogar (casa -> claro), estrecho
	Rect2i(35, 27, 3, 1),     # la ENTRADA al hogar (claro -> calle), de 3 como la calle de la plaza
	Rect2i(34, 22, 5, 5),     # el claro del altar
	Rect2i(35, 2, 3, 8),      # del porton de la arena a la calle norte
	Rect2i(29, 12, 2, 16),    # los dos caminos a los LADOS DEL HOGAR, de la calle alta a la norte
	Rect2i(42, 12, 2, 16),
]

const PLAZA := Rect2i(32, 34, 9, 9)

# La ESCALERA DE CARACOL que baja a la mazmorra, en el centro de la plaza. Solida: la F se pulsa
# desde su boca, en el lado sur.
const ESCALERA := Rect2i(35, 37, 3, 3)

# ------------------------------------------------------------
#  EL RECINTO DEL HOGAR: jardin con verjas. La verja va por el borde del rectangulo, con UN hueco
#  abajo por donde sale el camino.
# ------------------------------------------------------------
# Cerrado por los CUATRO lados desde que el pueblo crecio (antes la fila de arriba era la muralla). La
# verja de arriba va dos filas por encima de la casa: el tejado sube dos casillas sobre su huella y, mas
# pegada, quedaria debajo del dibujo.
const JARDIN := Rect2i(31, 13, 11, 15)
# La entrada de la verja: 3 de ancho, alineada con la calle que sube de la plaza (lo pidio el usuario).
const JARDIN_HUECO := Rect2i(35, 27, 3, 1)
const ALTAR := Vector2i(36, 24)

# ------------------------------------------------------------
#  EL MUELLE Y LA PLATAFORMA DEL PESCADOR (madera sobre el agua).
# ------------------------------------------------------------
const MUELLE := Rect2i(35, ORILLA, 3, 4)
const PLATAFORMA := Rect2i(33, 57, 7, 7)

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
	{"lado": "norte", "rect": Rect2i(35, 0, 3, 2)},
	{"lado": "oeste", "rect": Rect2i(0, 37, 2, 3)},
	{"lado": "este", "rect": Rect2i(ANCHO - 2, 37, 2, 3)},
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
	{"clave": "hogar", "nombre": "HOGAR", "rect": Rect2i(34, 17, 5, 4), "script": "res://scripts/town/hogar.gd"},
	{"clave": "boticaria", "nombre": "BOTICARIA", "rect": Rect2i(17, 33, 4, 3), "script": "res://scripts/town/boticaria.gd"},
	{"clave": "maestro", "nombre": "MAESTRO", "rect": Rect2i(25, 33, 3, 3), "script": "res://scripts/town/maestro.gd"},
	{"clave": "tienda", "nombre": "TIENDA", "rect": Rect2i(43, 32, 5, 4), "script": "res://scripts/town/shop.gd"},
	{"clave": "herreria", "nombre": "HERRERÍA", "rect": Rect2i(52, 33, 4, 3), "script": "res://scripts/town/herrero.gd"},
	{"clave": "cocina", "nombre": "COCINA", "rect": Rect2i(17, 42, 4, 3), "script": "res://scripts/town/cocinero.gd"},
	{"clave": "taberna", "nombre": "TABERNA", "rect": Rect2i(43, 41, 5, 4), "script": "res://scripts/town/taberna.gd"},
	{"clave": "carpinteria", "nombre": "CARPINTERÍA", "rect": Rect2i(52, 42, 4, 3), "script": "res://scripts/town/carpintero.gd"},
	{"clave": "peleteria", "nombre": "PELETERÍA", "rect": Rect2i(52, 48, 4, 3), "script": "res://scripts/town/peletero.gd"},
	{"clave": "pescador", "nombre": "PESCADOR", "rect": Rect2i(35, 59, 3, 3), "script": "res://scripts/town/pescador.gd"},
	# EL CUARTEL de los guardias: el edificio mas grande del pueblo (7 de ancho, lo pidio el usuario). No
	# se entra: los guardias desaparecen en su puerta y salen con el equipo puesto (o sin el).
	{"clave": "cuartel", "rect": Rect2i(20, 4, 7, 5)},
	# Relleno: a los lados del hogar, una fila por lado pegada a la calle alta.
	{"clave": "vacia", "rect": Rect2i(15, 24, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(20, 24, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(25, 24, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(45, 24, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(50, 24, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(55, 24, 3, 3)},
	# Relleno: los barrios del sur.
	{"clave": "vacia", "rect": Rect2i(25, 42, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(17, 48, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(25, 48, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(43, 48, 3, 3)},
	# EL BARRIO NORTE: una fila pegada a la calle norte, a los dos lados del cuartel y del camino de la arena.
	{"clave": "vacia", "rect": Rect2i(4, 6, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(9, 6, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(14, 6, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(29, 6, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(40, 6, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(45, 6, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(50, 6, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(55, 6, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(60, 6, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(65, 6, 3, 3)},
	# LOS BARRIOS DEL OESTE Y DEL ESTE: dos casas por calle y lado, pegadas a su calle como las demas.
	{"clave": "vacia", "rect": Rect2i(3, 24, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(8, 24, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(3, 33, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(8, 33, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(3, 42, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(8, 42, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(3, 48, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(8, 48, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(63, 24, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(68, 24, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(63, 33, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(68, 33, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(63, 42, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(68, 42, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(63, 48, 3, 3)},
	{"clave": "vacia", "rect": Rect2i(68, 48, 3, 3)},
]


# ------------------------------------------------------------
#  ADORNOS DE SUELO: lo que se apoya delante de cada casa, en la fila de la puerta. Cada uno ocupa una
#  casilla y CHOCA (lo pidio el usuario: "que sean fisicas y no te dejen andar por ahi"). El numero es
#  la columna respecto a la de la puerta (la de la puerta nunca: es el camino). Colocados donde los
#  marco el usuario sobre las capturas.
# ------------------------------------------------------------
const ADORNOS := {
	"herreria": [["yunque", -2]],
	"carpinteria": [["troncos", 1]],
	"cocina": [["barril", -1]],
	"tienda": [["cajas", -2], ["sacos", 2]],
	"taberna": [["barril", -1], ["barriles", 1], ["barriles", 2]],
	"peleteria": [["bastidor", -2]],
}


# ------------------------------------------------------------
#  LAS LUCES DE NOCHE (ver Antorcha, LuzPueblo). Decidido con el usuario el 16/09/2026: postes con
#  antorcha a lo largo de las calles y braseros en la plaza y en los portones.
#
#  Los POSTES van en la HIERBA del borde de cada calle horizontal, cada 6-7 casillas y alternando de
#  lado: en la calle quitarian paso. Nunca en la casilla de una puerta ni de un adorno, y nunca pegados
#  a la fachada SUR de una casa de abajo: su tejado sube dos casillas y el poste quedaria dentro del
#  dibujo.
# ------------------------------------------------------------
const POSTES := [
	# La calle mayor (filas 36 al norte y 40 al sur).
	Vector2i(7, 36), Vector2i(10, 40), Vector2i(17, 36), Vector2i(23, 40), Vector2i(30, 36), Vector2i(42, 40),
	Vector2i(50, 36), Vector2i(56, 40), Vector2i(63, 40), Vector2i(66, 36),
	# La calle alta (27 al norte, 30 al sur). En las bocas de los caminos del hogar van los carteles.
	Vector2i(7, 27), Vector2i(11, 30), Vector2i(18, 27), Vector2i(23, 30), Vector2i(39, 30), Vector2i(49, 30),
	Vector2i(58, 27), Vector2i(62, 30), Vector2i(66, 27),
	# La calle baja (45 al norte, 48 al sur).
	Vector2i(7, 45), Vector2i(15, 45), Vector2i(22, 48), Vector2i(30, 45), Vector2i(40, 48), Vector2i(50, 45),
	Vector2i(58, 48), Vector2i(66, 45),
	# La calle norte (9 al norte, 12 al sur; al sur, fuera de la plaza de la fuente y del mercadillo).
	Vector2i(7, 9), Vector2i(5, 12), Vector2i(18, 9), Vector2i(26, 12), Vector2i(33, 9), Vector2i(45, 12),
	Vector2i(48, 9), Vector2i(63, 9), Vector2i(70, 12),
	# El paseo de la orilla: a los lados del muelle.
	Vector2i(33, 51), Vector2i(39, 51),
]

# BRASEROS: cuatro alrededor de la escalera de la plaza, dos a cada lado de los portones del este y el
# oeste, y dos a los lados del porton norte, el de la arena.
const BRASEROS := [
	Vector2i(33, 35), Vector2i(39, 35), Vector2i(33, 41), Vector2i(39, 41),
	Vector2i(2, 36), Vector2i(2, 40), Vector2i(ANCHO - 3, 36), Vector2i(ANCHO - 3, 40),
	Vector2i(33, 2), Vector2i(39, 2),
]


# ------------------------------------------------------------
#  LOS CARTELES INDICADORES: un poste con tablillas en los cruces. Al leerlo (F) dice hacia donde queda
#  cada sitio importante (lo pidio el usuario al llevarse la arena al barrio norte). Chocan como un poste
#  de antorcha. 'destinos' = [texto, lado] con lado n/s/e/o: hacia donde hay que ir DESDE el cartel.
# ------------------------------------------------------------
const CARTELES := [
	# En las bocas de los dos caminos de los lados del hogar, sobre la calle alta.
	{"casilla": Vector2i(28, 27), "destinos": [["Zona de pruebas", "n"], ["Plaza de la fuente", "n"],
		["Cuartel", "n"], ["Plaza y mazmorra", "s"]]},
	{"casilla": Vector2i(44, 27), "destinos": [["Zona de pruebas", "n"], ["Mercadillo", "n"], ["Plaza y mazmorra", "s"]]},
	# En la calle norte, junto al camino de la arena.
	{"casilla": Vector2i(38, 9), "destinos": [["Zona de pruebas", "n"], ["Cuartel", "o"], ["Plaza de la fuente", "o"],
		["Mercadillo", "e"], ["Hogar y plaza", "s"]]},
	# En la plaza, junto a la calle que sube al hogar.
	{"casilla": Vector2i(38, 33), "destinos": [["Hogar", "n"], ["Zona de pruebas", "n"], ["Puerta oeste", "o"],
		["Puerta este", "e"], ["Muelle del pescador", "s"]]},
]


# ------------------------------------------------------------
#  LO QUE HAY EN LA PLAZA DE LA FUENTE Y EN EL MERCADILLO: [pieza, huella]. Todo choca con la caja de lo
#  que se ve (CAJA_MUEBLE); la fuente, que llena su huella, va aparte (FUENTE, choca entera).
#  Los puestos van en dos filas de cara al sur, con pasillo delante de cada una; detras de cada puesto
#  queda sitio para quien lo atienda (los vendedores vendran con los NPC, solo de dia).
# ------------------------------------------------------------
const MUEBLES := [
	# Bancos alrededor de la fuente, mirando hacia ella.
	["banco_s", Rect2i(13, 13, 1, 1)], ["banco_s", Rect2i(19, 13, 1, 1)],
	["banco_n", Rect2i(13, 17, 1, 1)], ["banco_n", Rect2i(19, 17, 1, 1)],
	["banco_e", Rect2i(12, 15, 1, 1)], ["banco_o", Rect2i(20, 15, 1, 1)],
	# Parterres en las esquinas de la plaza y arbolitos en la hierba de los lados.
	["parterre", Rect2i(9, 13, 1, 1)], ["parterre", Rect2i(23, 13, 1, 1)],
	["parterre", Rect2i(9, 19, 1, 1)], ["parterre", Rect2i(23, 19, 1, 1)],
	["arbolito", Rect2i(6, 14, 1, 1)], ["arbolito", Rect2i(6, 18, 1, 1)],
	["arbolito", Rect2i(26, 14, 1, 1)], ["arbolito", Rect2i(26, 18, 1, 1)],
	# El mercadillo: UNA fila de cuatro puestos, cada uno con su genero (lo pidio el usuario), y algo de
	# genero apilado entre ellos.
	["puesto_pan", Rect2i(49, 14, 3, 2)], ["puesto_verdura", Rect2i(54, 14, 3, 2)],
	["puesto_fruta", Rect2i(59, 14, 3, 2)], ["puesto_especias", Rect2i(64, 14, 3, 2)],
	["cajas", Rect2i(52, 15, 1, 1)], ["sacos", Rect2i(57, 15, 1, 1)], ["barriles", Rect2i(62, 15, 1, 1)],
]

# La caja de choque de cada mueble, en px desde la esquina de arriba a la izquierda de su huella: la
# planta de lo que se ve, como las de los adornos.
# Con la camara a 45 la planta de lo que se ve ocupa K = 0,71 de su fondo, pegada al borde sur de la
# huella (ver PlazaSprites).
const CAJA_MUEBLE := {
	"banco_s": Rect2(4, 18, 24, 8), "banco_n": Rect2(4, 18, 24, 8),
	# De lado el respaldo va al lado de la espalda: al oeste si mira al este, y al reves.
	"banco_e": Rect2(9, 12, 12, 18), "banco_o": Rect2(12, 12, 12, 18),
	"arbolito": Rect2(11, 20, 10, 8),
	"parterre": Rect2(3, 12, 26, 19),
	# El puesto entero, mostrador y hueco de detras: el jugador no se mete dentro (el vendedor si).
	"puesto_pan": Rect2(2, 22, 92, 40), "puesto_verdura": Rect2(2, 22, 92, 40), "puesto_fruta": Rect2(2, 22, 92, 40),
	"puesto_especias": Rect2(2, 22, 92, 40),
	"cajas": Rect2(5, 15, 22, 10), "sacos": Rect2(2, 15, 28, 10), "barriles": Rect2(2, 15, 28, 10),
}


static func es_mueble(c: Vector2i) -> bool:
	for m in MUEBLES:
		if (m[1] as Rect2i).has_point(c):
			return true
	return false


static func casillas_carteles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in CARTELES:
		out.append(c["casilla"])
	return out


# Todas las luces como [pieza, casilla].
static func luces() -> Array:
	var out: Array = []
	for c in POSTES:
		out.append(["poste_antorcha", c])
	for c in BRASEROS:
		out.append(["brasero", c])
	return out


# LAS CAÑAS DE PESCAR: tres, al azar, en el borde de la plataforma del pescador (nunca en la fila
# del muelle, por donde se llega). Salen de la semilla del pueblo (Game.semilla_pueblo_actual), asi que
# en multijugador caen en el mismo sitio para todos. Devuelve [casilla, lado] con lado "s", "e" u "o".
const CANAS := 3

static func canas(semilla: int) -> Array:
	var cand: Array = []
	var p: Rect2i = PLATAFORMA
	for x in range(p.position.x, p.end.x):
		cand.append([Vector2i(x, p.end.y - 1), "s"])
	for y in range(p.position.y + 1, p.end.y - 1):
		cand.append([Vector2i(p.position.x, y), "o"])
		cand.append([Vector2i(p.end.x - 1, y), "e"])
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var out: Array = []
	var intentos: int = 0
	while out.size() < CANAS and intentos < 200:
		intentos += 1
		var c: Array = cand[rng.randi_range(0, cand.size() - 1)]
		var lejos: bool = true
		for o in out:
			var dd: Vector2i = (o[0] as Vector2i) - (c[0] as Vector2i)
			if maxi(absi(dd.x), absi(dd.y)) < 2:
				lejos = false
		if lejos:
			out.append(c)
	return out


# Todos los adornos del pueblo, como [pieza, casilla].
static func adornos() -> Array:
	var out: Array = []
	for casa in CASAS:
		for a in ADORNOS.get(String(casa["clave"]), []):
			out.append([String(a[0]), puerta_de(casa) + Vector2i(int(a[1]), 0)])
	return out


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


# EL PORTON NORTE lleva a la ARENA DE PRUEBAS (lo pidio el usuario: la puerta dibujada en la muralla).
# La F se pulsa desde la casilla de delante, al final de su calle en el barrio norte, y al volver de la
# arena se aparece justo debajo.
const PORTON_ARENA := Vector2i(36, 2)

static func vuelta_de_arena_px() -> Vector2:
	return centro_px(PORTON_ARENA + Vector2i(0, 1))


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


# Las casillas de VERJA: el borde entero del jardin menos el hueco del camino.
static func es_verja(c: Vector2i) -> bool:
	if not JARDIN.has_point(c) or JARDIN_HUECO.has_point(c):
		return false
	return c.x == JARDIN.position.x or c.x == JARDIN.end.x - 1 \
		or c.y == JARDIN.position.y or c.y == JARDIN.end.y - 1


# ¿Con que se junta una verja? Con otra verja o con la MURALLA (asi cierra contra ella).
static func se_une_la_verja(c: Vector2i) -> bool:
	return es_verja(c) or suelo(c) == Suelo.MURALLA


# ¿Choca esta casilla? Muralla, agua (menos la madera), verjas, casas, escalera y el pie del altar.
static func solida(c: Vector2i) -> bool:
	if solida_entera(c):
		return true
	if es_verja(c) or c == ALTAR:
		return true
	for a in adornos():
		if a[1] == c:
			return true
	if c in POSTES or c in BRASEROS or c in casillas_carteles() or es_mueble(c) or FUENTE.has_point(c):
		return true
	return false


# Lo que choca con la CASILLA ENTERA: muralla, agua, casas y escalera, cuyo dibujo llena su huella.
# Las piezas pequeñas (adornos, altar, verjas) NO: su caja es lo que se ve (ver cajas_pequenas). Con
# la casilla entera el usuario chocaba "con el aire" media casilla antes de llegar al barril.
static func solida_entera(c: Vector2i) -> bool:
	var s: int = suelo(c)
	if s == Suelo.MURALLA or s == Suelo.AGUA:
		return true
	if ESCALERA.has_point(c):
		return true
	for casa in CASAS:
		if (casa["rect"] as Rect2i).has_point(c):
			return true
	return false


# LAS CAJAS DE LO PEQUEÑO, en px: la BASE de lo que se ve apoyado en el suelo (el choque es con los
# pies del jugador, asi que lo que cuenta es la planta del objeto, no lo alto que sea).
# Los adornos se apoyan en y = arriba de su casilla + 20 (PuebloSprites.ADORNO_SUELO en su lienzo).
const CAJA_ADORNO := {
	"yunque": Vector2(22, 10), "barril": Vector2(16, 8), "barriles": Vector2(28, 10),
	"troncos": Vector2(30, 12), "cajas": Vector2(22, 10), "sacos": Vector2(28, 10),
	"bastidor": Vector2(28, 6),
}
const ADORNO_APOYO := 20.0
const VERJA_GROSOR := 6.0

static func cajas_pequenas() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var cel: float = float(CELDA)
	for a in adornos():
		var c: Vector2i = a[1]
		var t: Vector2 = CAJA_ADORNO.get(String(a[0]), Vector2(20, 10))
		# PEGADA A LA CASA: de ancho, lo que se ve; de fondo, desde la fachada (arriba de su casilla)
		# hasta el pie del dibujo. Con solo la base quedaba un hueco entre el barril y la pared, el
		# jugador se colaba por detras y se quedaba "bugeado" entre los dos.
		var cx: float = float(c.x) * cel + cel * 0.5
		var arriba: float = float(c.y) * cel
		var abajo: float = float(c.y) * cel + ADORNO_APOYO + t.y * 0.5
		out.append(Rect2(Vector2(cx - t.x * 0.5, arriba), Vector2(t.x, abajo - arriba)))
	# Las luces: el zocalo del poste y las patas del brasero, al fondo de su casilla (donde se apoyan).
	# Los carteles se clavan igual que un poste: la misma caja.
	for c in POSTES + casillas_carteles():
		var bp := Vector2(float(c.x) * cel + cel * 0.5, float(c.y + 1) * cel - 8.0)
		out.append(Rect2(bp - Vector2(5, 4), Vector2(10, 7)))
	for c in BRASEROS:
		var bb := Vector2(float(c.x) * cel + cel * 0.5, float(c.y + 1) * cel - 8.0)
		out.append(Rect2(bb - Vector2(12, 4), Vector2(24, 8)))
	for m in MUEBLES:
		var r: Rect2i = m[1]
		var caja: Rect2 = CAJA_MUEBLE.get(String(m[0]), Rect2(4, 4, 24, 24))
		out.append(Rect2(Vector2(r.position) * cel + caja.position, caja.size))
	out.append(Rect2(Vector2(FUENTE.position) * cel + CAJA_FUENTE.position, CAJA_FUENTE.size))
	# La columna del altar: su zocalo, pegado al fondo de su casilla.
	var ab := Vector2(float(ALTAR.x) * cel + cel * 0.5, float(ALTAR.y + 1) * cel - 9.0)
	out.append(Rect2(ab - Vector2(11, 5), Vector2(22, 10)))
	# Las verjas: una raya por el centro de la casilla hacia cada lado por el que sigue la verja.
	for y in range(JARDIN.position.y, JARDIN.end.y):
		for x in range(JARDIN.position.x, JARDIN.end.x):
			var v := Vector2i(x, y)
			if not es_verja(v):
				continue
			var cen := Vector2(float(x) * cel + cel * 0.5, float(y) * cel + cel * 0.5)
			var g: float = VERJA_GROSOR
			out.append(Rect2(cen - Vector2(g, g) * 0.5, Vector2(g, g)))
			if es_verja(v + Vector2i(1, 0)):
				out.append(Rect2(cen - Vector2(0, g * 0.5), Vector2(cel * 0.5, g)))
			if es_verja(v + Vector2i(-1, 0)):
				out.append(Rect2(cen - Vector2(cel * 0.5, g * 0.5), Vector2(cel * 0.5, g)))
			if es_verja(v + Vector2i(0, 1)):
				out.append(Rect2(cen - Vector2(g * 0.5, 0), Vector2(g, cel * 0.5)))
			if se_une_la_verja(v + Vector2i(0, -1)):
				out.append(Rect2(cen - Vector2(g * 0.5, cel * 0.5), Vector2(g, cel * 0.5)))
	return out


# Rectangulos de choque FUNDIDOS (tiras horizontales unidas hacia abajo), como hace la mazmorra con
# sus muros: un par de centenares de cajas en vez de mil y pico.
static func solidos_fusionados() -> Array[Rect2i]:
	var usado := {}
	var out: Array[Rect2i] = []
	for y in ALTO:
		var x: int = 0
		while x < ANCHO:
			var c := Vector2i(x, y)
			if not solida_entera(c) or usado.has(c):
				x += 1
				continue
			var w: int = 0
			while x + w < ANCHO and solida_entera(Vector2i(x + w, y)) and not usado.has(Vector2i(x + w, y)):
				w += 1
			var h: int = 1
			var sigue: bool = true
			while sigue and y + h < ALTO:
				for i in w:
					var d := Vector2i(x + i, y + h)
					if not solida_entera(d) or usado.has(d):
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
