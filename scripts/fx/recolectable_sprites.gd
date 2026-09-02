# ============================================================
#  recolectable_sprites.gd  (class_name RecolectableSprites)
#  Los sprites de lo que se RECOLECTA en la mazmorra: vetas, arboles, matas, sal, carbon y huerto.
#  Tercer generador por codigo del proyecto, detras de los bichos (SpritesEnemigo) y del terreno
#  (TerrenoSprites), y usa el mismo motor que el primero: SpriteLienzo.
#
# ------------------------------------------------------------
#  VARIOS MODELOS POR FAMILIA
# ------------------------------------------------------------
#  Una veta no puede ser SIEMPRE el mismo pedrusco: con un solo dibujo, una sala con tres vetas se
#  lee como tres copias pegadas y canta mas que el ColorRect que habia antes. Cada familia trae
#  MODELOS siluetas distintas (un afloramiento, un racimo de cristales, un pedrusco vetado...) y el
#  modelo se elige por la CELDA, asi que es estable: la misma veta se ve igual cada vez que
#  reconstruyes el piso, y en multijugador el invitado ve la misma que el host.
#
# ------------------------------------------------------------
#  DOS IMAGENES POR MODELO: CUERPO Y TINTE
# ------------------------------------------------------------
#  El problema de tintar: si se pinta el sprite entero con material_data.color, el cobre tiñe
#  tambien la roca que lo rodea y todas las vetas acaban siendo un manchurron del color del metal.
#  Y si no se tiñe nada, el cobre y el hierro son el mismo dibujo.
#
#  Asi que cada modelo se hornea DOS veces desde la MISMA plantilla, cambiando solo la paleta:
#    CUERPO -> la roca / el tronco / las hojas. Neutro, no se tiñe nunca.
#    TINTE  -> solo las vetas de mineral (o el fruto), en blanco, para que el juego lo module con
#              material_data.color y salga cobre, hierro o sal sin redibujar nada.
#  En el mapa son dos Sprite2D, uno encima del otro. Es la misma idea que la plantilla de tonos de
#  SpriteLienzo -- separar la geometria (cara) del color (barata) -- llevada al disco.
# ============================================================

extends RefCounted
class_name RecolectableSprites

const CARPETA := "res://assets/sprites/recolectables/"

# Cuantas siluetas distintas tiene cada familia.
const MODELOS := 4

# FORMAS: el SUB-TIER del material entra en el DIBUJO, no solo en el tinte. 0 bruto, 1 veteado,
# 2 profundo (ver MaterialData.forma_recolectable). Hoy la roca con mineral -- veta y carbon -- y
# la madera la usan; el resto de familias van con la forma 0 y punto (pendiente 3a tanda).
const FORMAS := 3

static func formas_de(familia: String) -> int:
	if familia == "carbon":
		return FORMAS
	if familia == "madera":
		# La madera cruza DOS ejes: especie por TIER (pino/roble/cipres) x sub-tier por forma. Ver
		# _madera() y resource_node._crear_sprite(), que es quien combina tier+forma en un indice.
		return FORMAS * 3
	if familia == "planta" or familia == "veta":
		# Ni planta ni veta cruzan especie+sub-tier con una formula comun (cada una de las 9 ya
		# tiene nombre propio: hierba palida, cobre profundo, hierro negro...). El indice se
		# calcula IGUAL que en madera (tier-1)*3+subtier -- ver resource_node._crear_sprite --
		# pero cada valor dibuja una silueta propia (_planta()/_veta()), no una especie
		# compartida entre sub-tiers. "carbon" sigue con las 3 formas genericas de siempre: sus
		# 10 materiales no se reparten limpio en 3 tiers x 3 sub-tiers.
		return FORMAS * 3
	return 1

# --- Tonos de la plantilla ---
# El 0 es el VACIO de SpriteLienzo. Los tonos de MINERAL son los unicos que van al TINTE.
enum {
	VACIO = 0,
	BORDE,
	ROCA_OSC, ROCA, ROCA_CLARA,
	TRONCO_OSC, TRONCO, TRONCO_CLARO,
	HOJA_OSC, HOJA, HOJA_CLARA,
	MINERAL, MINERAL_BRILLO,
}

# Paleta del CUERPO: el mineral va transparente (lo pone la otra imagen).
const PAL_CUERPO := [
	Color(0, 0, 0, 0),                # VACIO
	Color(0.03, 0.03, 0.05),          # BORDE
	Color(0.16, 0.15, 0.19),          # ROCA_OSC
	Color(0.27, 0.26, 0.32),          # ROCA
	Color(0.38, 0.36, 0.44),          # ROCA_CLARA
	Color(0.16, 0.11, 0.07),          # TRONCO_OSC
	Color(0.26, 0.18, 0.11),          # TRONCO
	Color(0.36, 0.26, 0.16),          # TRONCO_CLARO
	Color(0.08, 0.19, 0.10),          # HOJA_OSC
	Color(0.13, 0.30, 0.15),          # HOJA
	Color(0.20, 0.42, 0.21),          # HOJA_CLARA
	Color(0, 0, 0, 0),                # MINERAL
	Color(0, 0, 0, 0),                # MINERAL_BRILLO
]

# Paleta del TINTE: solo el mineral, y en claro para que el modulate del juego lo lleve al color
# del material sin ensuciarlo (modular un gris oscuro da un color apagado siempre).
const PAL_TINTE := [
	Color(0, 0, 0, 0), Color(0, 0, 0, 0),
	Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0),
	Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0),
	Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0),
	Color(0.78, 0.78, 0.78),          # MINERAL
	Color(1.00, 1.00, 1.00),          # MINERAL_BRILLO
]


# ============================================================
#  LAS FAMILIAS
# ============================================================
# El lienzo es POR FAMILIA porque un arbol y una mata de sal no miden lo mismo ni de lejos. El
# ORIGEN es donde se apoya el sprite en el mundo: se dibuja con el pie en la celda, no centrado,
# porque estas cosas se plantan EN el suelo y si se centran flotan.
const FAMILIAS := {
	"veta":    {"w": 34, "h": 30},
	"carbon":  {"w": 34, "h": 30},
	"sal":     {"w": 28, "h": 24},
	# Un arbol tiene que ser MAS ALTO QUE EL JUGADOR (que mide una celda, 32 px). A 46x56 se
	# quedaba por debajo de su cabeza y no se leia como arbol, sino como un arbusto raro.
	"madera":  {"w": 68, "h": 104},
	"planta":  {"w": 30, "h": 28},
	"huerto":  {"w": 32, "h": 26},
}


static func lienzo(familia: String) -> Vector2i:
	var d: Dictionary = FAMILIAS.get(familia, FAMILIAS["veta"])
	return Vector2i(int(d["w"]), int(d["h"]))


# ============================================================
#  RUIDO (el mismo truco que TerrenoSprites, sin periodicidad: aqui no hay que casar bordes)
# ============================================================
static func _rnd(x: int, y: int, s: int) -> float:
	var n: int = x * 374761393 + y * 668265263 + s * 1013904223
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xFFFF) / 65535.0


# ============================================================
#  TRAZO: la herramienta para dibujar cosas que SALEN de otras
# ============================================================
# Una cadena de circulos que se van afilando a lo largo de una direccion, con la direccion
# girando poco a poco ('curva'). Sustituye a "una elipse girada puesta ahi al lado", que era como
# estaban las ramas del arbol seco y se veia el fallo enseguida: la elipse tiene su centro
# DESPLAZADO del tronco, asi que la rama nacia en el aire y quedaba flotando al lado del arbol.
#
# Con un trazo eso no puede pasar: se empieza DENTRO de la pieza de la que sale, asi que la union
# esta siempre cubierta. Y como el radio decae, la rama acaba en punta sin que haya que dibujar
# la punta a mano.
static func _trazo(p: PackedByteArray, w: int, h: int, desde: Vector2, ang: float, largo: float,
		r0: float, r1: float, tono: int, curva: float = 0.0) -> void:
	var pos: Vector2 = desde
	var a: float = ang
	var pasos: int = maxi(2, int(largo))
	for i in pasos + 1:
		var t: float = float(i) / float(pasos)
		var r: float = lerpf(r0, r1, t)
		SpriteLienzo.elipse(p, w, h, pos.x, pos.y, r, r, tono)
		pos += Vector2(cos(a), sin(a)) * (largo / float(pasos))
		a += curva


# ============================================================
#  MODELOS
# ============================================================
# Cada uno rellena la plantilla. Coordenadas en celdas del lienzo, con el pie abajo del todo.

# --- VETA: 9 minerales con silueta propia, uno cada uno -- NO una formula de sub-tier compartida
# (a diferencia de _carbon): 'forma' 0-8 sale de (tier-1)*3+subtier (ver resource_node._crear_sprite),
# pero aqui cada valor va a su propia funcion, con un criterio propio de que es ese mineral:
#   cobre  (nativo, blando)  -> nodulos redondeados: bruto = un par asomando apenas, veteado = una
#                               veta fina ramificada, profundo = un racimo apretado de nodulos.
#   hierro (duro, anguloso)  -> bloques de bordes rectos: bruto = afloramiento anguloso con una
#                               raya, veteado = UNA veta recta y gruesa (linea unica, dura), profundo
#                               = esquirlas afiladas apiladas, el mineral solo de filo en el borde.
#   acero  (refinado)        -> formas planas/cristalinas: bruto = losa ancha y plana con una
#                               costura fina, veteado = VARIAS franjas onduladas paralelas (el
#                               pliegue de verdad), profundo = cumulo de cristales facetados.
# El mineral sigue yendo en MINERAL (transparente en CUERPO, tinte real en TINTE); la roca en
# ROCA/ROCA_OSC/ROCA_CLARA, con el mismo lavado tinte_cuerpo() que el resto -- no hace falta que
# cada mineral tiña su propio gris, eso ya lo hace la capa de sprite. El brillo metalico (shader)
# sigue enganchado a la FAMILIA "veta" en resource_node, no a la forma: no se toca aqui.
static func _veta(p: PackedByteArray, w: int, h: int, forma: int, modelo: int, sem: int) -> void:
	var cx: float = float(w) * 0.5
	var pie: float = float(h) - 2.0
	match forma:
		0:
			_cobre(p, w, h, modelo, cx, pie)
		1:
			_cobre_veteado(p, w, h, modelo, cx, pie)
		2:
			_cobre_profundo(p, w, h, modelo, cx, pie)
		3:
			_hierro(p, w, h, modelo, cx, pie)
		4:
			_hierro_templado(p, w, h, modelo, cx, pie)
		5:
			_hierro_negro(p, w, h, modelo, cx, pie)
		6:
			_acero(p, w, h, modelo, cx, pie)
		7:
			_acero_plegado(p, w, h, modelo, cx, pie)
		_:
			_acero_espejo(p, w, h, modelo, cx, pie)
	_acabado_roca(p, w, h, sem, forma % 3 == 2)


# T1 bruto: afloramiento bajo y redondeado, con un par de nodulos de cobre asomando apenas en la
# superficie -- poco mineral, como manda el bruto. Los 4 modelos cambian CUANTOS nodulos hay y como
# se reparten (no solo 2 vs 3 en el mismo sitio): tiene que notarse sin mirar el color.
static func _cobre(p: PackedByteArray, w: int, h: int, modelo: int, cx: float, pie: float) -> void:
	SpriteLienzo.elipse(p, w, h, cx, pie - 3.0, 13.0, 5.0, ROCA)
	SpriteLienzo.elipse(p, w, h, cx - 4.0, pie - 6.0, 4.0, 3.5, ROCA)
	SpriteLienzo.elipse(p, w, h, cx + 5.0, pie - 5.0, 3.5, 3.0, ROCA)
	# cada modelo: lista de (offset_x, offset_y) de sus nodulos -- 2 juntos, 3 en fila, 2 apartados
	# arriba/abajo, 4 repartidos por toda la costra.
	var nodulos: Array = [
		[Vector2(-1.5, -5.0), Vector2(2.0, -5.5)],
		[Vector2(-5.0, -4.5), Vector2(0.0, -6.0), Vector2(5.0, -4.5)],
		[Vector2(-6.0, -3.5), Vector2(6.0, -7.5)],
		[Vector2(-7.0, -4.0), Vector2(-2.0, -7.0), Vector2(3.0, -4.5), Vector2(7.0, -6.5)],
	][modelo]
	for off in nodulos:
		SpriteLienzo.elipse(p, w, h, cx + off.x, pie + off.y, 1.4, 1.3, MINERAL)


# T1 veteado: una veta fina que nace de un punto y se ramifica en 1-2 brazos -- franja de mineral
# sobre el fondo de roca, nunca la mitad de la superficie. Cada modelo trae su PROPIO numero de
# brazos y sus PROPIOS angulos (no la misma horquilla girada 6 grados).
static func _cobre_veteado(p: PackedByteArray, w: int, h: int, modelo: int, cx: float,
		pie: float) -> void:
	SpriteLienzo.elipse(p, w, h, cx, pie - 7.0, 10.0, 8.5, ROCA)
	var raiz := Vector2(cx - 1.0, pie - 5.0)
	var brazos: Array = [
		[-100.0, -50.0],
		[-140.0, -90.0, -35.0],
		[-160.0, -100.0, -60.0, -15.0],
		[-115.0, -65.0],
	][modelo]
	for a in brazos:
		_trazo(p, w, h, raiz, deg_to_rad(a), 9.0, 1.4, 0.3, MINERAL, deg_to_rad(1.0))


# T1 profundo: matriz oscura con un racimo apretado de nodulos redondos -- silueta de "racimo", no
# de cristal ni de bloque (eso es cosa del hierro y el acero). Girar un anillo simetrico no basta
# (8 puntos girados 15 grados se leen igual): cada modelo cambia CUANTOS nodulos hay y que tan
# apretado o disperso esta el racimo.
static func _cobre_profundo(p: PackedByteArray, w: int, h: int, modelo: int, cx: float,
		pie: float) -> void:
	SpriteLienzo.elipse(p, w, h, cx, pie - 7.0, 10.5, 8.0, ROCA_OSC)
	var n: int = [5, 8, 6, 9][modelo]
	var radio: float = [2.4, 4.2, 3.0, 3.6][modelo]
	var tam: float = [2.3, 1.6, 2.0, 1.5][modelo]
	for i in n:
		var a: float = float(i) * (360.0 / float(n))
		var r: float = radio + float(i % 2) * 0.6
		var pos := Vector2(cx, pie - 7.5) + Vector2(cos(deg_to_rad(a)), sin(deg_to_rad(a))) * r
		SpriteLienzo.elipse(p, w, h, pos.x, pos.y, tam, tam * 0.95, MINERAL)
	SpriteLienzo.elipse(p, w, h, cx, pie - 7.5, tam * 0.9, tam * 0.85, MINERAL)


# T2 bruto: afloramiento de bordes RECTOS (varias elipses desplazadas formando facetas, no una
# elipse redonda) con una sola raya de mineral en una cara. Cada modelo reparte los bloques en un
# sitio distinto Y cambia el angulo de la raya a lo grande, no en pasos de 4 grados.
static func _hierro(p: PackedByteArray, w: int, h: int, modelo: int, cx: float, pie: float) -> void:
	SpriteLienzo.elipse(p, w, h, cx, pie - 5.0, 9.0, 6.0, ROCA)
	var bloques: Array = [
		[Vector2(-7.0, -3.5), Vector2(7.0, -4.0)],
		[Vector2(-8.0, -2.0), Vector2(6.0, -5.0), Vector2(0.0, -9.0)],
		[Vector2(-6.0, -6.0), Vector2(8.0, -3.0)],
		[Vector2(-8.0, -4.0), Vector2(8.0, -4.5), Vector2(-2.0, -9.5), Vector2(3.0, -8.0)],
	][modelo]
	for off in bloques:
		SpriteLienzo.elipse(p, w, h, cx + off.x, pie + off.y, 4.3, 3.8, ROCA)
	var ang_raya: float = [-25.0, -70.0, 10.0, -110.0][modelo]
	_trazo(p, w, h, Vector2(cx - 6.0, pie - 6.0), deg_to_rad(ang_raya), 10.0, 1.2, 0.4, MINERAL)


# T2 veteado: UNA veta recta y gruesa, dura -- contraste con la rama del cobre, no se dobla. Cada
# modelo la pone en una direccion bien distinta (casi vertical, diagonal marcada, casi horizontal),
# no la misma linea girada 5 grados.
static func _hierro_templado(p: PackedByteArray, w: int, h: int, modelo: int, cx: float,
		pie: float) -> void:
	SpriteLienzo.elipse(p, w, h, cx, pie - 9.0, 7.5, 10.5, ROCA)
	SpriteLienzo.elipse(p, w, h, cx, pie - 3.0, 9.5, 4.0, ROCA)
	var ang: float = [-90.0, -55.0, -125.0, -35.0][modelo]
	var largo: float = [19.0, 16.0, 16.0, 14.0][modelo]
	var inicio: Vector2 = [Vector2(0.0, -3.0), Vector2(-7.0, -1.0), Vector2(6.0, -1.0),
		Vector2(-8.0, -3.0)][modelo]
	_trazo(p, w, h, Vector2(cx + inicio.x, pie + inicio.y), deg_to_rad(ang), largo, 2.4, 1.6,
		MINERAL)


# T2 profundo: esquirlas afiladas apiladas -- el mineral solo como filo brillante en el BORDE de
# cada esquirla, no nodulos redondos (eso es el cobre). El numero de esquirlas y sus angulos
# cambian de un modelo a otro, no solo un desplazamiento de 4 grados sobre la misma corona de 3.
static func _hierro_negro(p: PackedByteArray, w: int, h: int, modelo: int, cx: float,
		pie: float) -> void:
	SpriteLienzo.elipse(p, w, h, cx, pie - 3.0, 9.0, 4.0, ROCA_OSC)
	var angs: Array = [
		[-100.0, -90.0, -80.0],
		[-125.0, -95.0, -60.0, -25.0],
		[-100.0, -80.0],
		[-150.0, -115.0, -90.0, -65.0, -30.0],
	][modelo]
	var n: int = angs.size()
	for i in n:
		var f: float = float(i) - float(n - 1) * 0.5
		var ang: float = angs[i]
		var largo: float = 12.0 + absf(f) * 2.0
		var base := Vector2(cx + f * 2.6, pie - 3.0)
		_trazo(p, w, h, base, deg_to_rad(ang), largo, 2.0, 0.3, ROCA_OSC)
		_trazo(p, w, h, base + Vector2(cos(deg_to_rad(ang + 90.0)), sin(deg_to_rad(ang + 90.0))) * 0.8,
			deg_to_rad(ang), largo * 0.75, 0.7, 0.2, MINERAL)


# T3 bruto: losa ancha y plana con una costura fina de mineral cruzandola en diagonal -- distinta
# del pedrusco redondo del cobre y del bloque anguloso del hierro. Cada modelo INCLINA la losa
# entera (no solo su ancho) y cruza la costura en una direccion bien distinta.
static func _acero(p: PackedByteArray, w: int, h: int, modelo: int, cx: float, pie: float) -> void:
	var ang_losa: float = [0.0, 16.0, -12.0, 8.0][modelo]
	var ancho: float = [14.0, 11.5, 15.0, 12.5][modelo]
	var rad_losa: float = deg_to_rad(ang_losa)
	SpriteLienzo.elipse(p, w, h, cx, pie - 4.0, ancho, 4.8, ROCA, rad_losa)
	# La costura va SIEMPRE relativa al eje de la propia losa (angulo de la losa + un sesgo fijo),
	# nunca en un angulo absoluto: si no, al inclinar la losa la costura se sale de su cuerpo y
	# queda como una raya suelta en el aire (le paso a un angulo casi vertical con la losa plana).
	var sesgo: float = [-16.0, -22.0, 18.0, -20.0][modelo]
	var ang_costura: float = ang_losa + sesgo
	var largo: float = ancho * 1.35
	var inicio: Vector2 = Vector2(cx, pie - 4.0) + Vector2(cos(deg_to_rad(ang_losa + 180.0)),
		sin(deg_to_rad(ang_losa + 180.0))) * (ancho * 0.7)
	_trazo(p, w, h, inicio, deg_to_rad(ang_costura), largo, 1.4, 0.6, MINERAL)


# T3 veteado: el pliegue de verdad -- VARIAS franjas onduladas paralelas, no una sola veta como
# hierro ni ramificada como cobre. Cada modelo gira el paquete de capas un angulo bien distinto y
# cambia cuantas hay: girar 10 grados una onda simetrica no basta, hay que verlo de perfil o de
# canto para que se note.
static func _acero_plegado(p: PackedByteArray, w: int, h: int, modelo: int, cx: float,
		pie: float) -> void:
	var ang: float = [0.0, 35.0, -25.0, 60.0][modelo]
	var capas: int = [3, 5, 4, 3][modelo]
	var amp: float = [1.0, 1.8, 1.3, 2.2][modelo]
	var rad: float = deg_to_rad(ang)
	SpriteLienzo.elipse(p, w, h, cx, pie - 6.0, 12.0, 7.0, ROCA, rad)
	for c in capas:
		var offset: float = (float(c) - float(capas - 1) * 0.5) * (11.0 / float(capas))
		for i in 12:
			var lx: float = -10.0 + float(i) * 1.8
			var ly: float = offset + sin(float(i) * 0.6 + float(c) * 1.3) * amp
			var wx: float = cx + lx * cos(rad) - ly * sin(rad)
			var wy: float = pie - 6.0 + lx * sin(rad) + ly * cos(rad)
			SpriteLienzo.elipse(p, w, h, wx, wy, 1.0, 0.7, MINERAL)


# T3 profundo: cumulo de cristales facetados -- una aguja central y dos menores sobre matriz
# oscura, silueta puntiaguda y simetrica (distinta del bloque de esquirlas del hierro y del racimo
# del cobre). Cada modelo cambia la altura de la aguja principal Y el abanico de las menores a lo
# grande, no en pasos de 3 grados.
#
# LA SILUETA NO CAMBIO AL PASAR EL MATERIAL DE PAVONADO A ESPEJO, y no tenia por que: el color entra
# aparte, por tinte (ver tinte_cuerpo), asi que aqui solo se dibuja la FORMA. Un racimo de agujas
# facetadas es justo lo que pide un acero que ahora sale casi blanco -- lo que se movio fue el color
# del .tres, no esto.
static func _acero_espejo(p: PackedByteArray, w: int, h: int, modelo: int, cx: float,
		pie: float) -> void:
	SpriteLienzo.elipse(p, w, h, cx, pie - 3.0, 8.5, 3.5, ROCA_OSC)
	var alto: float = [17.0, 22.0, 14.0, 19.0][modelo]
	var abanico: Array = [
		[-115.0, -65.0], [-130.0, -50.0], [-105.0, -80.0], [-140.0, -95.0],
	][modelo]
	_trazo(p, w, h, Vector2(cx, pie - 2.0), deg_to_rad(-90.0), alto, 2.8, 0.4, MINERAL)
	for a in abanico:
		_trazo(p, w, h, Vector2(cx, pie - 2.0), deg_to_rad(a), 10.0, 1.8, 0.3, MINERAL)


# --- CARBON: roca con mineral incrustado -- las 10 variantes de carbon NO se reparten limpio en
# 3 tiers x 3 sub-tiers (ver RecolectableSprites.FAMILIAS y material_data), asi que se quedan con
# el reparto de siempre: 3 formas GENERICAS compartidas por todo el que caiga en ellas.
# DOS ejes, y los dos cambian la SILUETA (no solo el color):
#   forma  (0..2) -> el SUB-TIER. Cada forma tiene su PROPIO juego de cuatro siluetas, no es la
#                    misma roca con otra textura:
#     0 bruto    -> afloramientos pobres y bajos, el mineral apenas asoma en motas.
#     1 veteado  -> la roca CRUZADA de vetas de mineral: hendida, ramificada, bandeada, partida.
#     2 profundo -> CRISTALIZACION: geoda abierta, estallido de agujas, drusa, aguja mayor. Matriz
#                   casi negra, mucho brillo.
#   modelo (0..3) -> cual de las cuatro de esa forma. Lo elige el hash de la celda.
static func _carbon(p: PackedByteArray, w: int, h: int, forma: int, modelo: int, sem: int) -> void:
	var cx: float = float(w) * 0.5
	var pie: float = float(h) - 2.0

	match forma:
		1:
			_carbon_veteado(p, w, h, modelo, sem, cx, pie)
		2:
			_carbon_profundo(p, w, h, modelo, sem, cx, pie)
		_:
			_carbon_bruto(p, w, h, modelo, sem, cx, pie)

	_acabado_roca(p, w, h, sem, forma == 2)


# Brillo del mineral (mas denso en "profundo") y sombreado de la mitad baja de la roca. Compartido
# entre _carbon() (por forma==2) y _veta() (por forma%3==2) para no mantener esta cuenta dos veces.
static func _acabado_roca(p: PackedByteArray, w: int, h: int, sem: int, mas_brillo: bool) -> void:
	var umbral_brillo: float = 0.58 if mas_brillo else 0.72
	for y in h:
		for x in w:
			var i: int = y * w + x
			if p[i] == MINERAL and _rnd(x, y, sem + 7) > umbral_brillo:
				p[i] = MINERAL_BRILLO
	for y in range(int(h / 2), h):
		for x in w:
			var i: int = y * w + x
			if p[i] == ROCA and _rnd(x, y, sem + 3) > 0.55:
				p[i] = ROCA_OSC


# Mete mineral en las celdas de roca que cumplen 'umbral' de ruido. Con 'solo_veta' true respeta el
# mineral ya puesto (las vetas dibujadas a mano) y solo salpica; con false rellena a saco.
static func _motear(p: PackedByteArray, w: int, h: int, sem: int, umbral: float) -> void:
	for y in h:
		for x in w:
			var i: int = y * w + x
			if (p[i] == ROCA or p[i] == ROCA_OSC or p[i] == ROCA_CLARA) and _rnd(x, y, sem) > umbral:
				p[i] = MINERAL


# --- BRUTO: cuatro afloramientos pobres. El mineral apenas se ve ---
static func _carbon_bruto(p: PackedByteArray, w: int, h: int, modelo: int, sem: int,
		cx: float, pie: float) -> void:
	match modelo:
		0:
			# Costra baja y ancha, dos bultitos encima.
			SpriteLienzo.elipse(p, w, h, cx, pie - 3.0, 13.0, 5.0, ROCA)
			SpriteLienzo.elipse(p, w, h, cx - 4.0, pie - 6.0, 4.0, 3.5, ROCA)
			SpriteLienzo.elipse(p, w, h, cx + 5.0, pie - 5.0, 3.5, 3.0, ROCA)
		1:
			# Pepitas: trozos pequeños separados sobre una base minima.
			SpriteLienzo.elipse(p, w, h, cx, pie - 2.5, 10.0, 3.0, ROCA)
			for i in 3:
				var lx: float = cx + (float(i) - 1.0) * 6.0
				SpriteLienzo.elipse(p, w, h, lx, pie - 5.0 - float(i % 2) * 2.0, 3.6, 3.4, ROCA)
		2:
			# Pedrusco redondo con una lente de mineral en el centro.
			SpriteLienzo.elipse(p, w, h, cx, pie - 7.0, 9.5, 8.0, ROCA)
			SpriteLienzo.elipse(p, w, h, cx, pie - 7.0, 5.0, 1.8, MINERAL)
		3:
			# Losa plana con un filon fino cruzandola en diagonal.
			SpriteLienzo.elipse(p, w, h, cx, pie - 4.0, 12.0, 5.5, ROCA)
			_trazo(p, w, h, Vector2(cx - 9.0, pie - 1.0), deg_to_rad(-35.0), 16.0, 1.3, 0.7, MINERAL)
	_motear(p, w, h, sem, 0.9)


# --- VETEADO: la roca cruzada de vetas de mineral, cada modelo a su manera ---
static func _carbon_veteado(p: PackedByteArray, w: int, h: int, modelo: int, sem: int,
		cx: float, pie: float) -> void:
	match modelo:
		0:
			# Bloque hendido: alto, partido por una veta gruesa en diagonal.
			SpriteLienzo.elipse(p, w, h, cx, pie - 9.0, 7.5, 10.5, ROCA)
			_trazo(p, w, h, Vector2(cx - 7.0, pie - 3.0), deg_to_rad(-58.0), 17.0, 2.4, 1.4, MINERAL)
		1:
			# Red de vetas: pedrusco con el mineral ramificado desde un punto.
			SpriteLienzo.elipse(p, w, h, cx, pie - 7.0, 10.0, 8.5, ROCA)
			var raiz := Vector2(cx - 1.0, pie - 5.0)
			for a in [-115.0, -70.0, -20.0, -160.0]:
				_trazo(p, w, h, raiz, deg_to_rad(a), 9.0, 1.9, 0.5, MINERAL, deg_to_rad(1.2))
		2:
			# Losa vetada: "veteado" es una raya de un color DISTINTO cruzando un fondo -- la
			# roca manda, el mineral son franjas FINAS que la cruzan, no la mitad de la
			# superficie. (Antes eran dos tonos a partes iguales y se leia como un bloque solido
			# del color del metal, sin fondo de piedra: al reves de lo que significa la palabra.)
			SpriteLienzo.elipse(p, w, h, cx, pie - 6.0, 12.0, 7.5, ROCA)
			for y in h:
				for x in w:
					var i: int = y * w + x
					if p[i] != ROCA:
						continue
					if fmod(float(y), 4.0) < 1.3:
						p[i] = MINERAL
		3:
			# Dos mitades cosidas por una veta central vertical brillante.
			SpriteLienzo.elipse(p, w, h, cx - 6.0, pie - 7.0, 6.5, 8.5, ROCA)
			SpriteLienzo.elipse(p, w, h, cx + 6.0, pie - 6.0, 6.5, 8.0, ROCA)
			_trazo(p, w, h, Vector2(cx, pie - 1.0), deg_to_rad(-90.0), 15.0, 2.2, 1.0, MINERAL)
	_motear(p, w, h, sem, 0.82)


# --- PROFUNDO: cristalizacion. Matriz oscura, cristales grandes, mucho brillo ---
static func _carbon_profundo(p: PackedByteArray, w: int, h: int, modelo: int, sem: int,
		cx: float, pie: float) -> void:
	match modelo:
		0:
			# Geoda abierta: cascara oscura con la cavidad llena de mineral.
			SpriteLienzo.elipse(p, w, h, cx, pie - 8.0, 10.0, 9.0, ROCA_OSC)
			SpriteLienzo.elipse(p, w, h, cx + 1.0, pie - 8.0, 6.5, 6.0, MINERAL)
			SpriteLienzo.elipse(p, w, h, cx - 4.0, pie - 12.0, 3.0, 3.0, ROCA_OSC)   # el labio roto
		1:
			# Estallido: base baja y un abanico de agujas largas.
			SpriteLienzo.elipse(p, w, h, cx, pie - 3.0, 9.0, 4.0, ROCA_OSC)
			for i in 5:
				var f: float = float(i) - 2.0
				_trazo(p, w, h, Vector2(cx + f * 2.2, pie - 3.0), deg_to_rad(-90.0 + f * 20.0),
					10.0 + absf(f) * 1.5, 2.4, 0.4, MINERAL)
		2:
			# Drusa: masa compacta cubierta de cristalitos cortos por toda la cara de arriba.
			SpriteLienzo.elipse(p, w, h, cx, pie - 6.0, 10.5, 7.5, ROCA_OSC)
			for i in 9:
				var lx: float = cx - 8.0 + float(i) * 2.0
				_trazo(p, w, h, Vector2(lx, pie - 8.0), deg_to_rad(-90.0 + float(i - 4) * 8.0),
					4.5, 1.6, 0.4, MINERAL)
		3:
			# Aguja mayor: un gran cristal central facetado y dos menores, sobre peana oscura.
			SpriteLienzo.elipse(p, w, h, cx, pie - 3.0, 8.0, 3.5, ROCA_OSC)
			_trazo(p, w, h, Vector2(cx, pie - 2.0), deg_to_rad(-90.0), 18.0, 3.0, 0.5, MINERAL)
			_trazo(p, w, h, Vector2(cx - 5.0, pie - 2.0), deg_to_rad(-108.0), 10.0, 2.0, 0.4, MINERAL)
			_trazo(p, w, h, Vector2(cx + 5.0, pie - 2.0), deg_to_rad(-72.0), 11.0, 2.0, 0.4, MINERAL)
	# Matriz casi negra: la roca que quede pasa a oscura, y el mineral se salpica denso.
	for y in h:
		for x in w:
			var i: int = y * w + x
			if p[i] == ROCA or p[i] == ROCA_CLARA:
				p[i] = ROCA_OSC
	_motear(p, w, h, sem, 0.8)


# --- SAL: costra cristalina, terrones sueltos ---
static func _sal(p: PackedByteArray, w: int, h: int, modelo: int, sem: int) -> void:
	var cx: float = float(w) * 0.5
	var pie: float = float(h) - 2.0
	# Costra de sal: un monton bajo y ancho del que asoman terrones angulosos. Antes eran cuatro
	# ovalos sueltos del mismo tamaño y se leia como un charco de motas, no como una veta.
	SpriteLienzo.elipse(p, w, h, cx, pie - 3.0, 10.0, 4.0, ROCA_OSC)
	var n: int = 4 + modelo
	for i in n:
		var f: float = (float(i) - float(n - 1) * 0.5)
		var lx: float = cx + f * 3.4
		var alto: float = 4.5 + absf(sin(float(i) * 2.1 + float(modelo))) * 4.5
		_trazo(p, w, h, Vector2(lx, pie - 3.0), deg_to_rad(-90.0 + f * 13.0), alto,
			2.9, 1.1, MINERAL)
	for y in h:
		for x in w:
			var i: int = y * w + x
			if p[i] == MINERAL and _rnd(x, y, sem) > 0.55:
				p[i] = MINERAL_BRILLO


# --- MADERA: arboles. DOS ejes reales, no uno:
#   especie (forma / 3) -> el TIER: 0 pino, 1 roble, 2 cipres. Cada especie es su propia forma de
#                          arbol, reconocible de lejos (cono en pisos / masa redonda ancha /
#                          columna estrecha), y NO cambia con el sub-tier.
#   subtier (forma % 3)  -> 0 bruto, 1 veteado, 2 profundo, IGUAL que en la veta: cada uno cambia
#                          de verdad la estructura (mas pisos, ramas nudosas, corteza marcada),
#                          no solo el tinte.
#   modelo  (0..3)        -> la variacion dentro de esa combinacion (inclinacion, grosor, hueco).
static func _madera(p: PackedByteArray, w: int, h: int, forma: int, modelo: int, sem: int) -> void:
	var cx: float = float(w) * 0.5
	var pie: float = float(h) - 2.0
	# TODAS las medidas van en proporcion al lienzo. Estaban puestas a pelo para un lienzo de 56
	# de alto, asi que agrandar el arbol obligaba a repasar cuarenta numeros a mano; con esto,
	# cambiar la talla en FAMILIAS reescala el dibujo entero y ya.
	var k: float = float(h) / 56.0
	var especie: int = forma / 3
	var subtier: int = forma % 3
	match especie:
		0:
			_pino(p, w, h, subtier, modelo, cx, pie, k)
		1:
			_roble(p, w, h, subtier, modelo, cx, pie, k)
		_:
			_cipres(p, w, h, subtier, modelo, cx, pie, k, sem)
	# Volumen: el lado izquierdo (de donde viene la luz) se aclara, el derecho se apaga.
	for y in h:
		for x in w:
			var i: int = y * w + x
			var t: int = p[i]
			var claro: bool = float(x) < cx - 2.0 and _rnd(x, y, sem) > 0.45
			var osc: bool = float(x) > cx + 3.0 and _rnd(x, y, sem + 5) > 0.5
			if t == HOJA:
				p[i] = HOJA_CLARA if claro else (HOJA_OSC if osc else HOJA)
			elif t == TRONCO:
				p[i] = TRONCO_CLARO if claro else (TRONCO_OSC if osc else TRONCO)


# --- PINO (T1): tronco recto, copa en PISOS TRIANGULARES que se estrechan hacia arriba ---
# 0 bruto: joven y delgado, dos pisos. 1 veteado: maduro, corteza estriada, tres pisos completos.
# 2 profundo: viejo, tronco grueso y agrietado, un piso caido -> copa asimetrica, muy alto.
static func _pino(p: PackedByteArray, w: int, h: int, subtier: int, modelo: int,
		cx: float, pie: float, k: float) -> void:
	var lean: float = [0.0, 4.0, -3.0, 2.0][modelo] * k
	var ancho_mod: float = [1.0, 0.85, 1.15, 0.95][modelo]
	var tx: float = cx + lean
	var pisos: int = [2, 3, 4][subtier]
	# El tronco tiene su ALTURA PROPIA y la copa arranca DENTRO de el (nunca lo tapa entero): un
	# pino real enseña tronco desnudo por debajo de las primeras ramas.
	var alto_tronco: float = [8.0, 10.0, 12.0][subtier] * k
	var grosor: float = [1.8, 2.4, 3.2][subtier] * k
	var tono_tronco: int = TRONCO if subtier < 2 else TRONCO_OSC
	var ang: float = deg_to_rad(-90.0) + lean * 0.02
	_trazo(p, w, h, Vector2(tx, pie), ang, alto_tronco, grosor, grosor * 0.6, tono_tronco)
	var base: float = pie - alto_tronco + 2.0 * k   # se cose 2k dentro del tronco, no empieza en el aire
	# El viejo pierde ANCHO (nunca alto NI el piso entero) en uno de los pisos, segun el modelo:
	# asimetria sin que nada se despegue. Encoger tambien el RY fue lo que dejaba flotando el piso
	# reducido -- el alto es lo unico que lo mantiene pegado al de encima y al de debajo, asi que
	# se deja intacto siempre; solo el ancho y un empujon lateral pequeño cambian.
	var reducido: int = (modelo % pisos) if subtier == 2 else -1
	# rx/ry se estrechan bastante de piso a piso (y los pisos van poco separados EN VERTICAL) para
	# que se lea como un CONO escalonado, no como una sola copa redonda ancha -- eso es lo que
	# distingue al pino del roble.
	for i in pisos:
		var f: float = float(i)
		var es_reducido: bool = i == reducido
		var rx: float = (11.0 - f * 1.8) * k * ancho_mod * (0.6 if es_reducido else 1.0)
		var ry: float = (6.5 - f * 0.9) * k * ancho_mod
		if rx <= 1.0 or ry <= 1.0:
			continue
		var cy: float = base - f * 7.5 * k
		var ox: float = lean * 0.06 * f + (1.3 * k if es_reducido else 0.0)
		SpriteLienzo.elipse(p, w, h, tx + ox, cy, rx, ry, HOJA)
	if subtier == 1:
		# corteza estriada: una veta clara vertical, solo en el tronco desnudo.
		_trazo(p, w, h, Vector2(tx - grosor * 0.3, pie - k), ang, alto_tronco * 0.8, 0.7 * k,
			0.3 * k, TRONCO_CLARO)
	elif subtier == 2:
		# tronco agrietado: veta oscura marcada, mas ancha.
		_trazo(p, w, h, Vector2(tx + grosor * 0.25, pie - k), ang, alto_tronco * 0.8, 0.9 * k,
			0.3 * k, TRONCO_OSC)


# --- ROBLE (T2): tronco grueso, copa ANCHA Y REDONDEADA, ramas gruesas asomando ---
# 0 bruto: joven, tronco fino, copa pequeña. 1 veteado: maduro, tronco con vetas, copa amplia de
# tres masas. 2 profundo: añoso, tronco nudoso, ramas retorcidas asomando entre las hojas.
static func _roble(p: PackedByteArray, w: int, h: int, subtier: int, modelo: int,
		cx: float, pie: float, k: float) -> void:
	var lean: float = [0.0, -3.0, 2.5, -1.5][modelo] * k
	var ancho_mod: float = [1.0, 1.1, 0.9, 1.05][modelo]
	var tx: float = cx + lean
	var alto: float = [11.0, 14.0, 16.0][subtier] * k
	var grosor: float = [2.6, 3.6, 4.6][subtier] * k
	var tono_tronco: int = TRONCO if subtier < 2 else TRONCO_OSC
	_trazo(p, w, h, Vector2(tx, pie), deg_to_rad(-90.0), alto, grosor, grosor * 0.7, tono_tronco)
	var copa_y: float = pie - alto - 4.0 * k
	var copa_r: float = [8.5, 11.0, 12.0][subtier] * k * ancho_mod
	SpriteLienzo.elipse(p, w, h, tx, copa_y, copa_r, copa_r * 0.8, HOJA)
	if subtier >= 1:
		# copa de tres masas: dos lobulos laterales, mas notorios cuanto mas maduro.
		SpriteLienzo.elipse(p, w, h, tx - copa_r * 0.65, copa_y + 2.0 * k, copa_r * 0.55,
			copa_r * 0.45, HOJA)
		SpriteLienzo.elipse(p, w, h, tx + copa_r * 0.65, copa_y + 1.0 * k, copa_r * 0.55,
			copa_r * 0.45, HOJA)
	if subtier == 1:
		_trazo(p, w, h, Vector2(tx - grosor * 0.3, pie - k), deg_to_rad(-90.0), alto * 0.85,
			0.7 * k, 0.3 * k, TRONCO_CLARO)
	elif subtier == 2:
		# ramas nudosas que se cosen al tronco y asoman por encima de las hojas.
		_trazo(p, w, h, Vector2(tx - grosor * 0.3, pie - alto * 0.55), deg_to_rad(-150.0),
			8.0 * k, 1.7 * k, 0.5 * k, TRONCO_OSC, deg_to_rad(-1.0) / k)
		_trazo(p, w, h, Vector2(tx + grosor * 0.3, pie - alto * 0.65), deg_to_rad(-30.0),
			8.0 * k, 1.7 * k, 0.5 * k, TRONCO_OSC, deg_to_rad(1.0) / k)


# Una columna de cipres: una fila de elipses apiladas y decrecientes que se leen como una silueta
# continua. 'deriva' es cuanto se corre la columna de base a punta (0 = recta).
static func _columna_cipres(p: PackedByteArray, w: int, h: int, tx0: float, pie: float,
		alto: float, ancho: float, deriva: float, k: float) -> void:
	var pasos: int = 8
	for i in pasos:
		var f: float = float(i) / float(pasos - 1)
		var ry: float = (alto / float(pasos)) * 0.8
		var rx: float = ancho * (1.0 - f * 0.4)
		var cy: float = pie - 2.0 * k - f * alto
		SpriteLienzo.elipse(p, w, h, tx0 + deriva * f, cy, rx, ry, HOJA_OSC)


# --- CIPRES (T3): columna alta y ESTRECHA, muy vertical -- la tercera silueta ---
# Los 4 MODELOS no son solo inclinacion (con una sola columna casi no se nota a este tamaño): son
# cuatro portes de cipres de verdad -- recto, gemelo, ancho compacto, y esbelto al viento.
# El SUB-TIER, ademas de crecer, deja su propia marca (madera_negra / calcinada / latente):
#   0 bruto    -> columna lisa, sin marcas.
#   1 veteado  -> textura quemada (motas oscuras salpicadas) + un par de ramas rotas asomando.
#   2 profundo -> bultos a lo largo del tronco, como si algo siguiera creciendo por dentro.
static func _cipres(p: PackedByteArray, w: int, h: int, subtier: int, modelo: int,
		cx: float, pie: float, k: float, sem: int) -> void:
	var alto: float = [26.0, 29.0, 32.0][subtier] * k
	var ancho: float = [3.0, 3.5, 4.0][subtier] * k
	match modelo:
		0:
			# Recto, el porte de libro.
			_columna_cipres(p, w, h, cx, pie, alto, ancho, 0.0, k)
		1:
			# Gemelo: dos columnas mas finas naciendo juntas de la misma base.
			_columna_cipres(p, w, h, cx - ancho * 0.55, pie, alto * 0.9, ancho * 0.7, -3.0 * k, k)
			_columna_cipres(p, w, h, cx + ancho * 0.55, pie, alto, ancho * 0.75, 2.0 * k, k)
		2:
			# Ancho y compacto: dos columnas casi fundidas en una sola (mucho mas juntas que el
			# gemelo), mas bajo que el resto. Antes llevaba una elipse suelta al lado a modo de
			# rama y se quedaba flotando en el aire sin tocar el cuerpo -- fuera.
			_columna_cipres(p, w, h, cx - ancho * 0.3, pie, alto * 0.75, ancho * 0.95, 1.0 * k, k)
			_columna_cipres(p, w, h, cx + ancho * 0.3, pie, alto * 0.8, ancho * 1.0, -1.0 * k, k)
		_:
			# Esbelto y muy inclinado, como si lo hubiera torcido el viento.
			_columna_cipres(p, w, h, cx, pie, alto * 1.15, ancho * 0.7, 8.0 * k, k)

	match subtier:
		1:
			# Calcinada: motas oscuras salpicadas por toda la copa (textura de quemado)...
			for y in h:
				for x in w:
					var i: int = y * w + x
					if p[i] == HOJA_OSC and _rnd(x, y, sem) > 0.72:
						p[i] = TRONCO_OSC
			# ...y un par de ramas rotas, cosidas al eje central, a distinta altura y lado.
			for i in 2:
				var hy: float = pie - alto * (0.3 + float(i) * 0.32)
				var lado: float = -1.0 if i == 0 else 1.0
				_trazo(p, w, h, Vector2(cx + lado * ancho * 0.2, hy), deg_to_rad(lado * 60.0),
					4.5 * k, 1.1 * k, 0.2 * k, TRONCO_OSC)
		2:
			# Latente: bultos a lo largo del eje, alternando de lado, como brotes que no deberian
			# estar ahi. Nacen SOBRE la columna (no al lado), asi que nunca quedan flotando.
			for i in 3:
				var by: float = pie - alto * (0.22 + float(i) * 0.24)
				var lado: float = -1.0 if i % 2 == 0 else 1.0
				SpriteLienzo.elipse(p, w, h, cx + lado * ancho * 0.75, by, ancho * 0.5, ancho * 0.5,
					HOJA)

	# tronco apenas visible en la base: un cipres es casi todo copa.
	_trazo(p, w, h, Vector2(cx, pie), deg_to_rad(-90.0), 3.0 * k, 1.1 * k, 0.7 * k, TRONCO_OSC)


# --- PLANTA: 9 especies con nombre propio, una silueta cada una -- NO una formula de sub-tier
# compartida entre ellas (a diferencia de _madera): 'forma' 0-8 sale de (tier-1)*3+subtier (ver
# resource_node._crear_sprite), pero aqui cada valor va a su propia funcion. El fruto/flor/espora
# de cada una va en MINERAL para que el juego la tiña con el color real del .tres; el resto en HOJA/
# HOJA_CLARA/HOJA_OSC, que reciben el mismo lavado suave (tinte_cuerpo) que la roca y el tronco --
# no hace falta que cada especie tiña su propio verde, eso ya lo hace la capa de sprite.
static func _planta(p: PackedByteArray, w: int, h: int, forma: int, modelo: int, sem: int) -> void:
	var cx: float = float(w) * 0.5
	var pie: float = float(h) - 2.0
	match forma:
		0:
			_hierba_palida(p, w, h, modelo, cx, pie)
		1:
			_raiz_amarga(p, w, h, modelo, cx, pie)
		2:
			_sanguinaria(p, w, h, modelo, cx, pie)
		3:
			_moho_simas(p, w, h, modelo, sem, cx, pie)
		4:
			_raiz_umbria(p, w, h, modelo, cx, pie)
		5:
			_liquen_abisal(p, w, h, modelo, sem, cx, pie)
		6:
			_musgo_ciego(p, w, h, modelo, cx, pie)
		7:
			_zarza_retorcida(p, w, h, modelo, cx, pie)
		_:
			_flor_de_sima(p, w, h, modelo, cx, pie)
	for y in h:
		for x in w:
			var i: int = y * w + x
			if p[i] == HOJA and _rnd(x, y, sem) > 0.6:
				p[i] = HOJA_CLARA if x < int(cx) else HOJA_OSC


# T1 bruto: mata sencilla de tres a seis briznas finas, sin flor ni fruto vistoso -- la mas humilde
# de las nueve, apenas un brote palido.
static func _hierba_palida(p: PackedByteArray, w: int, h: int, modelo: int, cx: float,
		pie: float) -> void:
	var n: int = 3 + modelo
	for i in n:
		var f: float = float(i) - float(n - 1) * 0.5
		var alto: float = 8.0 + absf(sin(float(i) * 1.7 + float(modelo))) * 3.0
		_trazo(p, w, h, Vector2(cx + f * 1.5, pie), deg_to_rad(-90.0 + f * 9.0), alto, 1.2, 0.3,
			HOJA)
	SpriteLienzo.elipse(p, w, h, cx, pie - 8.5, 1.4, 1.4, MINERAL)


# T1 veteado: una raiz retorcida asoma DEL SUELO (no bajo tierra) con una fibra clara corriendo por
# dentro -- el veteado de esta familia es esa fibra, no una franja partida a medias.
static func _raiz_amarga(p: PackedByteArray, w: int, h: int, modelo: int, cx: float,
		pie: float) -> void:
	# Tonos CLAROS para la raiz (HOJA, no HOJA_OSC): es lo que asoma DEL SUELO al aire, el elemento
	# principal del dibujo -- si va en el tono mas oscuro de la paleta se pierde contra el fondo.
	var lado: float = -1.0 if modelo % 2 == 0 else 1.0
	var curva: float = deg_to_rad(12.0 + float(modelo) * 3.0) * lado
	_trazo(p, w, h, Vector2(cx, pie), deg_to_rad(-90.0), 3.0, 2.6, 2.1, HOJA)
	_trazo(p, w, h, Vector2(cx, pie - 2.0), deg_to_rad(-90.0 + 35.0 * lado), 10.0, 2.1, 0.7,
		HOJA, curva)
	# la fibra clara que corre por dentro de la raiz -- el veteado de esta especie.
	_trazo(p, w, h, Vector2(cx, pie - 2.5), deg_to_rad(-90.0 + 35.0 * lado), 7.5, 0.7, 0.2,
		HOJA_CLARA, curva)
	for i in 2:
		var l: float = -1.0 if i == 0 else 1.0
		_trazo(p, w, h, Vector2(cx + l * 1.0, pie - 3.5), deg_to_rad(-90.0 + l * 14.0), 9.0, 1.5,
			0.4, HOJA)
	SpriteLienzo.elipse(p, w, h, cx - lado * 0.5, pie - 11.5, 1.5, 1.5, MINERAL)


# T1 profundo: rosa de hojas anchas y lobuladas con una gota colgando de la punta -- la savia que le
# da nombre.
static func _sanguinaria(p: PackedByteArray, w: int, h: int, modelo: int, cx: float,
		pie: float) -> void:
	var giro: float = float(modelo) * 15.0
	for i in 5:
		var a: float = deg_to_rad(-90.0 + giro + float(i - 2) * 26.0)
		SpriteLienzo.elipse(p, w, h, cx + float(i - 2) * 2.6, pie - 6.0, 3.6, 6.0, HOJA, a)
	var punta: Vector2 = Vector2(cx, pie - 6.0) + Vector2(sin(deg_to_rad(giro)),
		-cos(deg_to_rad(giro))) * 5.5
	SpriteLienzo.elipse(p, w, h, punta.x, punta.y + 2.0, 1.3, 1.7, MINERAL)


# T2 bruto: costra de moho -- un racimo de bultos esponjosos pegados al suelo, sin tallo.
static func _moho_simas(p: PackedByteArray, w: int, h: int, modelo: int, sem: int, cx: float,
		pie: float) -> void:
	var n: int = 4 + modelo % 2
	for i in n:
		var f: float = float(i) - float(n - 1) * 0.5
		SpriteLienzo.elipse(p, w, h, cx + f * 3.2, pie - 2.5 - absf(f) * 0.8, 2.6 - absf(f) * 0.3,
			2.2, HOJA_OSC)
	for y in h:
		for x in w:
			var i: int = y * w + x
			if p[i] == HOJA_OSC and _rnd(x, y, sem) > 0.75:
				p[i] = MINERAL


# T2 veteado: raiz umbria, mas gruesa y oscura que la amarga, con la misma fibra clara -- aqui en
# DOS raices que se cruzan, señal de que ya lleva mas tiempo enterrada.
static func _raiz_umbria(p: PackedByteArray, w: int, h: int, modelo: int, cx: float,
		pie: float) -> void:
	# Cuerpo de la raiz en HOJA (no HOJA_OSC): mas grueso que la amarga es lo que la hace "mas
	# oscura y añosa" a este tamaño, no un tono que se funda con el fondo.
	_trazo(p, w, h, Vector2(cx, pie), deg_to_rad(-90.0), 3.0, 3.0, 2.2, HOJA)
	_trazo(p, w, h, Vector2(cx - 0.5, pie - 2.0), deg_to_rad(-125.0 - float(modelo) * 4.0), 9.0,
		2.2, 0.6, HOJA, deg_to_rad(-2.0))
	_trazo(p, w, h, Vector2(cx + 0.5, pie - 2.0), deg_to_rad(-55.0 + float(modelo) * 4.0), 10.0,
		2.2, 0.6, HOJA, deg_to_rad(2.0))
	# sombra por debajo de cada raiz, para que se lean como dos y no como un abanico plano.
	_trazo(p, w, h, Vector2(cx - 0.8, pie - 1.0), deg_to_rad(-125.0 - float(modelo) * 4.0), 7.0,
		1.0, 0.3, HOJA_OSC, deg_to_rad(-2.0))
	_trazo(p, w, h, Vector2(cx - 0.3, pie - 2.5), deg_to_rad(-125.0), 6.5, 0.7, 0.2, HOJA_CLARA)
	_trazo(p, w, h, Vector2(cx, pie - 4.0), deg_to_rad(-90.0), 6.0, 1.2, 0.4, HOJA_CLARA)


# T2 profundo: liquen abisal -- una costra plana muy baja y ancha, salpicada de esporas sueltas.
static func _liquen_abisal(p: PackedByteArray, w: int, h: int, modelo: int, sem: int, cx: float,
		pie: float) -> void:
	SpriteLienzo.elipse(p, w, h, cx, pie - 1.8, 13.0 - float(modelo) * 0.5, 2.6, HOJA_OSC)
	SpriteLienzo.elipse(p, w, h, cx - 3.0, pie - 3.0, 7.0, 2.0, HOJA)
	SpriteLienzo.elipse(p, w, h, cx + 4.0, pie - 3.2, 6.0, 1.9, HOJA)
	for y in h:
		for x in w:
			var i: int = y * w + x
			if (p[i] == HOJA or p[i] == HOJA_OSC) and _rnd(x, y, sem) > 0.82:
				p[i] = MINERAL


# T3 bruto: musgo ciego -- un monticulo blando y redondo, sin ninguna punta clara arriba (es
# "ciego", no apunta a ningun lado), con un par de brotes finos que tantean a ciegas hacia fuera.
static func _musgo_ciego(p: PackedByteArray, w: int, h: int, modelo: int, cx: float,
		pie: float) -> void:
	SpriteLienzo.elipse(p, w, h, cx, pie - 4.5, 9.0, 5.5, HOJA_OSC)
	SpriteLienzo.elipse(p, w, h, cx, pie - 6.5, 6.5, 4.0, HOJA)
	for i in 2:
		var l: float = -1.0 if i == 0 else 1.0
		var curva: float = deg_to_rad(6.0 * l) * (1.0 if modelo % 2 == 0 else -1.0)
		_trazo(p, w, h, Vector2(cx + l * 3.0, pie - 6.0), deg_to_rad(-90.0 + l * 30.0), 5.0, 0.9,
			0.3, HOJA, curva)


# T3 veteado: zarza retorcida -- ramas enmarañadas naciendo de una base comun, con espinas y la
# fibra clara corriendo por la rama principal (el mismo veteado que las raices, aqui sobre madera
# de zarza en vez de bajo tierra).
static func _zarza_retorcida(p: PackedByteArray, w: int, h: int, modelo: int, cx: float,
		pie: float) -> void:
	# Ramas en HOJA (no HOJA_OSC): son lo unico que hay en el dibujo, asi que tienen que leerse
	# solas. El OSC se deja para las puntas espinosas, un acento pequeño, no la rama entera.
	_trazo(p, w, h, Vector2(cx, pie), deg_to_rad(-90.0), 4.0, 2.4, 1.8, HOJA)
	var ramas: int = 3
	for i in ramas:
		var f: float = float(i) - float(ramas - 1) * 0.5
		var ang: float = deg_to_rad(-90.0 + f * 40.0 + float(modelo) * 5.0)
		var curva: float = deg_to_rad(8.0) * f
		_trazo(p, w, h, Vector2(cx, pie - 3.0), ang, 9.0, 1.6, 0.5, HOJA, curva)
		var punta: Vector2 = Vector2(cx, pie - 3.0) + Vector2(cos(ang), sin(ang)) * 7.0
		SpriteLienzo.elipse(p, w, h, punta.x, punta.y, 1.1, 1.1, HOJA_OSC)
	_trazo(p, w, h, Vector2(cx, pie - 3.0), deg_to_rad(-90.0), 6.0, 0.6, 0.2, HOJA_CLARA)


# T3 profundo: flor de sima -- la mas rica de las nueve. Tallo alto y una flor abierta arriba, con
# los petalos en MINERAL formando un estallido en vez del punto redondo de las demas.
static func _flor_de_sima(p: PackedByteArray, w: int, h: int, modelo: int, cx: float,
		pie: float) -> void:
	var lean: float = [0.0, -3.0, 2.0, -1.5][modelo % 4]
	var tx: float = cx + lean
	_trazo(p, w, h, Vector2(cx, pie), deg_to_rad(-90.0) + lean * 0.02, 14.0, 1.4, 0.9, HOJA)
	for i in 2:
		var l: float = -1.0 if i == 0 else 1.0
		SpriteLienzo.elipse(p, w, h, tx + l * 2.0, pie - 6.0 - float(i) * 2.0, 3.5, 1.6, HOJA,
			deg_to_rad(l * -30.0))
	var cy: float = pie - 15.0
	for i in 6:
		var a: float = deg_to_rad(float(i) * 60.0)
		SpriteLienzo.elipse(p, w, h, tx + cos(a) * 2.6, cy + sin(a) * 2.6, 2.2, 1.6, MINERAL, a)
	SpriteLienzo.elipse(p, w, h, tx, cy, 1.6, 1.6, MINERAL)


# --- HUERTO: la despensa. Hojas fuera, la pieza comestible asomando (va en MINERAL) ---
static func _huerto(p: PackedByteArray, w: int, h: int, modelo: int, sem: int) -> void:
	var cx: float = float(w) * 0.5
	var pie: float = float(h) - 2.0
	var n: int = 2 + modelo % 3
	for i in n:
		var lx: float = cx + (float(i) - float(n - 1) * 0.5) * 8.0
		SpriteLienzo.elipse(p, w, h, lx, pie - 4.0, 4.5, 4.5, MINERAL)
		SpriteLienzo.elipse(p, w, h, lx, pie - 9.0, 5.5, 4.0, HOJA)
		SpriteLienzo.elipse(p, w, h, lx - 3.0, pie - 11.0, 3.0, 3.5, HOJA)
		SpriteLienzo.elipse(p, w, h, lx + 3.0, pie - 11.0, 3.0, 3.5, HOJA)
	for y in h:
		for x in w:
			var i: int = y * w + x
			if p[i] == HOJA and _rnd(x, y, sem) > 0.6:
				p[i] = HOJA_CLARA


# Tinte SUAVE para el CUERPO (la roca / el tronco). El cuerpo no lleva el color del material a
# saco -- eso ya se probo (ver cabecera del archivo) y empastaba toda la roca de alrededor en un
# manchurron del color del metal. Pero dejarlo del todo neutro tiene su propio problema: en la
# forma "profundo" la roca es casi toda matriz oscura y el mineral tinido queda en un puñado de
# pixeles sueltos, asi que el hierro negro no se ve negro y dos aceros distintos se leen casi
# iguales. Este es el termino medio: un LAVADO hacia el color del material sobre el gris neutro,
# lo bastante fuerte para que la piedra en si ya cuente algo, sin dejar de leerse como piedra.
# Usado por resource_node (el juego) y dev_materiales (el visor) -- MISMA formula en los dos sitios,
# igual que modelo_de(): si cada uno tuviera la suya se desincronizarian solos.
static func tinte_cuerpo(color: Color) -> Color:
	return Color(1, 1, 1).lerp(color, 0.55)


# ============================================================
#  BRILLO METALICO: solo el MINERAL, nunca la roca
# ============================================================
#  Mismo shader que ya usa el equipo del personaje (shaders/metal.gdshader): bisel + un barrido
#  especular lento. Se pone SOLO en el Sprite2D de TINTE de la familia "veta" -- el mineral de
#  verdad, no el carbon (que es roca, no metal) ni la roca que lo rodea (que se queda mate a
#  proposito, es piedra). Una unica instancia compartida: los uniforms son los mismos para todo el
#  mundo, asi que no hace falta un ShaderMaterial por nodo.
const SHADER_METAL := preload("res://shaders/metal.gdshader")
static var _mat_metal: ShaderMaterial = null

static func material_metal() -> ShaderMaterial:
	if _mat_metal == null:
		_mat_metal = ShaderMaterial.new()
		_mat_metal.shader = SHADER_METAL
		# El bisel del shader multiplica hasta x1.3, y encima suma la banda: con MINERAL_BRILLO
		# (ya casi blanco de base, ver PAL_TINTE) y metal a full, el mineral entero se quemaba a
		# blanco. Menos intensidad y una banda mas fina, para que el brillo sea un detalle y no
		# tape el color.
		_mat_metal.set_shader_parameter("metal", 0.4)
		_mat_metal.set_shader_parameter("velocidad", 0.2)
		_mat_metal.set_shader_parameter("ancho", 0.035)
	return _mat_metal


static func _dibujar(familia: String, forma: int, modelo: int) -> PackedByteArray:
	var t: Vector2i = lienzo(familia)
	var p := PackedByteArray()
	p.resize(t.x * t.y)
	var sem: int = hash(familia) + modelo * 7919 + forma * 104729
	match familia:
		"veta":
			_veta(p, t.x, t.y, forma, modelo, sem)
		"carbon":
			_carbon(p, t.x, t.y, forma, modelo, sem)
		"sal":
			_sal(p, t.x, t.y, modelo, sem)
		"madera":
			_madera(p, t.x, t.y, forma, modelo, sem)
		"planta":
			_planta(p, t.x, t.y, forma, modelo, sem)
		"huerto":
			_huerto(p, t.x, t.y, modelo, sem)
	# El contorno se echa sobre la forma YA FUSIONADA, nunca pieza a pieza (misma regla que los
	# bichos): si no, cada elipse trae su propio circulito marcado por dentro.
	SpriteLienzo.contornear(p, Rect2i(1, 1, t.x - 2, t.y - 2), t.x, t.y, BORDE, VACIO, VACIO)
	return p


# ============================================================
#  EL ATLAS
# ============================================================
# Una hoja por familia: (FORMAS x MODELOS) columnas x 2 filas (fila 0 cuerpo, fila 1 tinte). Las
# columnas van por forma primero: [f0m0 f0m1 f0m2 f0m3  f1m0 ... ]. Rejilla regular para poder
# recortarla con AtlasTexture sin json de por medio. Las familias sin sub-tiers (todo menos
# veta/carbon) traen una sola forma, o sea MODELOS columnas como antes.
const FILA_CUERPO := 0
const FILA_TINTE := 1

static func _columna(familia: String, forma: int, modelo: int) -> int:
	return posmod(forma, formas_de(familia)) * MODELOS + posmod(modelo, MODELOS)


static func _volcar(img: Image, p: PackedByteArray, o: Vector2i, t: Vector2i, pal: Array) -> void:
	for y in t.y:
		for x in t.x:
			img.set_pixel(o.x + x, o.y + y, pal[p[y * t.x + x]])


static func generar(familia: String) -> Image:
	var t: Vector2i = lienzo(familia)
	var nf: int = formas_de(familia)
	var img := Image.create(t.x * MODELOS * nf, t.y * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for f in nf:
		for m in MODELOS:
			var p: PackedByteArray = _dibujar(familia, f, m)
			var col: int = _columna(familia, f, m)
			_volcar(img, p, Vector2i(col * t.x, FILA_CUERPO * t.y), t, PAL_CUERPO)
			_volcar(img, p, Vector2i(col * t.x, FILA_TINTE * t.y), t, PAL_TINTE)
	return img


static func hornear(familia: String) -> int:
	DirAccess.make_dir_recursive_absolute(CARPETA)
	var png: String = CARPETA + familia + ".png"
	if generar(familia).save_png(ProjectSettings.globalize_path(png)) != OK:
		return 0
	var f := FileAccess.open(png, FileAccess.READ)
	var n: int = f.get_length() if f != null else 0
	if f != null:
		f.close()
	return n


static var _cache: Dictionary = {}

static func hoja_de(familia: String) -> Texture2D:
	if _cache.has(familia):
		return _cache[familia]
	var tex: Texture2D = null
	var png: String = CARPETA + familia + ".png"
	if ResourceLoader.exists(png):
		tex = load(png) as Texture2D
	if tex == null:
		tex = ImageTexture.create_from_image(generar(familia))
	_cache[familia] = tex
	return tex


# La textura recortada de un modelo. 'forma' = el sub-tier (0 bruto / 1 veteado / 2 profundo;
# lo da MaterialData.forma_recolectable). 'tinte' = la capa que hay que modular con el color del
# material; false = el cuerpo neutro.
static func textura(familia: String, forma: int, modelo: int, tinte: bool) -> AtlasTexture:
	var t: Vector2i = lienzo(familia)
	var at := AtlasTexture.new()
	at.atlas = hoja_de(familia)
	at.region = Rect2(_columna(familia, forma, modelo) * t.x,
		(FILA_TINTE if tinte else FILA_CUERPO) * t.y, t.x, t.y)
	at.filter_clip = true      # sin esto, al ampliar se cuela el pixel del modelo vecino
	return at


# QUE modelo le toca a esta celda. Por la celda y no al azar: asi es estable entre reconstrucciones
# del piso y, en multijugador, el invitado ve el mismo que el host sin que viaje nada por la red.
static func modelo_de(celda: Vector2i, semilla: int = 0) -> int:
	return posmod(hash(Vector3i(celda.x, celda.y, semilla)), MODELOS)
