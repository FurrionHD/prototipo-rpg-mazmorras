# ============================================================
#  cara_sprites.gd  (class_name CaraSprites)
#  LOS OJOS. La boca va aparte (BocaSprites): se eligen por separado (lo pidio el usuario).
#
#  Es una capa normal, con su atlas y su sitio en el catalogo (JugadorSprites.CATALOGO["cara"]): hereda
#  las animaciones, el giro por direccion y el horneado. SOLO SE MONTA SI NO LLEVAS FOTO (con imagen
#  propia, tu imagen ES tu cara, ver JugadorSprites.capas_de).
#
#  SE DIBUJAN COMO SELLOS DE PIXELES, NO COMO ELIPSES (17/09/2026). Un ojo de frente mide unos 4x3
#  pixeles, y una elipse a ese tamaño sale como una mancha: el motor decide que pixeles caen dentro y
#  la forma no se controla. Con las referencias de pixel art que paso el usuario (ojos pequeños con
#  pestaña, iris y brillo) la unica forma de llegar ahi es poner cada pixel: se calcula DONDE cae el
#  ojo en este fotograma (la proyeccion de siempre, asi gira con la cabeza) y alli se estampa un dibujo
#  fijo. Ver sello().
#
#  EL IRIS VA EN SU PROPIA CAPA. La capa se tiñe multiplicando por un solo color (capa_jugador.gdshader),
#  asi que teñirla entera pondria de color tambien la pestaña y el brillo. Los modelos con iris llevan
#  "iris": true en el catalogo y se hornean DOS veces: la normal (pestaña, blanco, brillo: sin teñir) y
#  la "_iris" (solo el iris, en gris, teñida con el color de ojos que elijas).
#
#  Y TRES COSAS QUE SIGUEN VALIENDO DE ANTES:
#   1. SIN CONTORNO: CapaJugador.plantilla convierte en T_BORDE todo pixel que toque el vacio, y en un
#      ojo de uno o dos pixeles de grueso eso es el ojo entero. Los sellos lo saltan ("sin_contorno").
#   2. DE PERFIL SE DIBUJA UN SOLO OJO: los dos girando, el de la otra mitad cae sobre la mejilla.
#   3. DE ESPALDAS NO SE DIBUJA NADA (direcciones 3, 4 y 5: la nuca).
# ============================================================

extends RefCounted
class_name CaraSprites

const PIEZA := "cara"
const SUFIJO_IRIS := "_iris"

enum Tono {
	VACIO = 0, SOMBRA_SUELO = 1, BORDE = 2,
	LINEA,      # la pestaña, el parpado, la pupila de los ojos sin color: casi negro
	BLANCO,     # el blanco del ojo
	BRILLO,     # el punto de luz
	IRIS,       # gris medio: con el tinte sale EXACTAMENTE el color elegido (base 0,62 del shader)
	PUPILA,     # gris oscuro: el mismo color, mas oscuro
	BOCA,       # la raya de la boca (la usa BocaSprites, que comparte paleta)
	BOCA_DENTRO,
	LENGUA,
}

const R := PoseJugador.CABEZA_R

# DONDE CAEN LOS RASGOS en la cabeza, en fracciones de su radio. MEDIDO, no a ojo: bajo el pelo quedan
# unas pocas filas de cara, y los ojos van en medio de esa franja.
const OJO_ALTO := -0.18          # respecto al centro de la cabeza
const OJO_SEPARACION := 0.34
# Cuanto se adelantan sobre el eje del cuerpo. Dentro del fondo de la cabeza (0,90) o flotan.
const OJO_FONDO := 0.58
const BOCA_ALTO := -0.42
# Cuanto se va la boca hacia el morro de perfil.
const BOCA_PERFIL := 0.30


# ============================================================
#  LOS DIBUJOS
# ============================================================
# Cada ojo es una lista de filas de arriba abajo, dibujado para el ojo que cae a la DERECHA de la cara
# en pantalla (mirando al sur); el otro es su espejo. Letras:
#   L linea (oscuro) · W blanco · H brillo · I iris · P pupila · . nada
# El centro del dibujo cae en el sitio del ojo.
#
# NO TODOS FEMENINOS (lo pidio el usuario): solo "anime" lleva pestañas; el resto son neutros.
const OJOS := {
	# Los tres de siempre, redibujados (sus claves se quedan para no romper partidas guardadas).
	"puntos": ["LL", "LL"],
	"chibi": ["HL", "LL", "LL"],
	"linea": ["LLL"],
	# Los nuevos.
	"serios": ["LLL", ".L."],
	"cansados": ["LLL", "LPL"],
	"felices": [".L.", "L.L"],
	"enfadados": ["L..", ".LL", ".LL"],
	"grandes": [".LL.", "LHIL", ".PP."],
	"anime": ["LLLL", "WHIW", ".IP."],
}

const LETRAS := {
	"L": Tono.LINEA, "W": Tono.BLANCO, "H": Tono.BRILLO, "I": Tono.IRIS, "P": Tono.PUPILA,
	"B": Tono.BOCA, "D": Tono.BOCA_DENTRO, "T": Tono.LENGUA,
}
# Los tonos que van en la capa teñida (la "_iris"). Todo lo demas va en la capa sin teñir.
const TONOS_IRIS := [Tono.IRIS, Tono.PUPILA]


# --- Contrato de capa (ver CapaJugador y el registro de JugadorSprites) ---
static func frames(modelo: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.frames(clave(modelo), pintar.bind(modelo), colores(), esc)


static func generar(modelo: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.generar(clave(modelo), pintar.bind(modelo), colores(), esc)


static func clave(modelo: String) -> String:
	return "%s_%s" % [PIEZA, modelo]


# ¿Este modelo tiene iris de color (y por tanto su segunda capa)?
static func tiene_iris(modelo: String) -> bool:
	for fila in OJOS.get(modelo, []):
		if String(fila).contains("I") or String(fila).contains("P"):
			return true
	return false


# LA PALETA, compartida con BocaSprites. El iris va en gris: lo colorea el tinte (ver la cabecera). En
# la capa sin teñir no se pinta ningun pixel de iris, asi que su gris no se ve nunca sin color.
static func colores() -> Array:
	return [
		Color(0, 0, 0, 0),           # VACIO
		Color(0, 0, 0, 0.20),        # SOMBRA_SUELO (no se usa)
		Color(0, 0, 0, 0),           # BORDE: transparente (ver el punto 1 de la cabecera)
		Color(0.13, 0.09, 0.11),     # LINEA
		Color(0.96, 0.96, 0.98),     # BLANCO
		Color(1.0, 1.0, 1.0),        # BRILLO
		Color(0.62, 0.62, 0.62),     # IRIS
		Color(0.30, 0.30, 0.30),     # PUPILA
		Color(0.40, 0.18, 0.18),     # BOCA
		Color(0.45, 0.10, 0.14),     # BOCA_DENTRO
		Color(0.90, 0.48, 0.52),     # LENGUA
	]


# ============================================================
#  EL PINTOR
# ============================================================
static func pintar(esq: Dictionary, piezas: Array, modelo: String) -> void:
	var d: int = int(esq.get("dir", 0))
	if d == 3 or d == 4 or d == 5:
		return
	var iris: bool = modelo.ends_with(SUFIJO_IRIS)
	var base: String = modelo.trim_suffix(SUFIJO_IRIS) if iris else modelo
	var dibujo: Array = OJOS.get(base, [])
	if dibujo.is_empty():
		return
	var cab: Vector3 = esq["puntos"][PoseJugador.P_CABEZA]
	var de_perfil: bool = d == 2 or d == 6
	# De perfil, el unico ojo que se ve es el del lado hacia el que mira la camara.
	var lados: Array = [1.0, -1.0]
	if de_perfil:
		lados = [1.0] if d == 6 else [-1.0]
	var centro: Vector2 = PoseJugador.proyectar(esq, cab, Vector3(R, R, R))["pos"]
	var ancho: int = String(dibujo[0]).length()
	for s in lados:
		var pos: Vector2 = PoseJugador.proyectar(esq, _ojo(cab, float(s)), Vector3(R * 0.1, R * 0.1, R * 0.1))["pos"]
		pos = hacia_dentro(pos, centro, ancho, d)
		sello(piezas, pos, dibujo, float(s) < 0.0, iris)


# METE EL SELLO DENTRO DE LA CARA. El sitio del ojo (o de la boca) de perfil cae en el mismo FILO de la
# cabeza, y centrando el dibujo ahi medio ojo se salia por fuera (visto en la hoja). De perfil se corre
# hacia el centro lo que mide medio dibujo mas un pixel; en diagonal, solo el que queda mas afuera y
# un pixel.
static func hacia_dentro(pos: Vector2, centro: Vector2, ancho: int, d: int) -> Vector2:
	var fuera: float = pos.x - centro.x
	var signo: float = 1.0 if fuera >= 0.0 else -1.0
	if d == 2 or d == 6:
		pos.x -= signo * float(ancho / 2 + 1)
	elif (d == 1 or d == 7) and absf(fuera) > 4.0:
		pos.x -= signo
	return pos


# Donde cae un ojo. 's' es +1 el de la derecha de la pantalla (mirando al sur) y -1 el otro.
static func _ojo(cab: Vector3, s: float) -> Vector3:
	return cab + Vector3(s * R * OJO_SEPARACION, R * OJO_FONDO, R * OJO_ALTO)


# ESTAMPA UN DIBUJO de pixeles centrado en 'pos' (celdas del lienzo). 'espejo' lo da la vuelta en
# horizontal. 'solo_iris': true pinta SOLO el iris y la pupila (la capa teñida); false, todo lo demas.
# 'columnas' recorta el dibujo a esas columnas (Array de indices; vacio = todas): lo usa la boca de
# perfil, que solo enseña la mitad de delante.
#
# Cada pixel es una elipse de medio pixel de radio centrada en el centro de su celda: la ruta por filas
# de SpriteLienzo.elipse la rellena exactamente a UNA celda (ni se come la vecina ni se queda en nada).
static func sello(piezas: Array, pos: Vector2, dibujo: Array, espejo: bool, solo_iris: bool,
		columnas: Array = []) -> void:
	var alto: int = dibujo.size()
	var ancho: int = String(dibujo[0]).length()
	var x0: int = int(floor(pos.x)) - ancho / 2
	var y0: int = int(floor(pos.y)) - alto / 2
	for j in alto:
		var fila: String = dibujo[j]
		for i in ancho:
			var letra: String = fila[ancho - 1 - i] if espejo else fila[i]
			if not LETRAS.has(letra):
				continue
			if not columnas.is_empty() and not columnas.has(i):
				continue
			var tono: int = int(LETRAS[letra])
			if (tono in TONOS_IRIS) != solo_iris:
				continue
			piezas.append({
				"pos": Vector2(float(x0 + i) + 0.5, float(y0 + j) + 0.5), "radio": Vector2(0.5, 0.5),
				"persp": 1.0, "tono": tono, "ang": 0.0, "gira_forma": false, "solo_sobre": [],
				"sin_contorno": true,
			})
