# ============================================================
#  cara_sprites.gd  (class_name CaraSprites)
#  LOS RASGOS: los ojos y la boca, dibujados como todo lo demas.
#
#  Antes esto era un CIRCULO LISO de color carne pegado encima de la cabeza (ver la nota vieja de
#  MunecoJugador.poner_cara). Cumplia lo minimo -- que la cabeza no fuera una bola de pelo -- pero no
#  se leia como una cara: se leia como una pegatina, porque un disco con un reborde difuminado no es
#  pixel art. Un personaje de este estilo tiene DOS OJOS, y eso hay que dibujarlo.
#
#  ES UNA CAPA NORMAL, con su atlas y su sitio en el catalogo, asi que hereda todo lo que ya funciona:
#  las 41 animaciones, el giro por direccion, el horneado y la hoja de contactos comparativa
#  (herramientas/ver_jugador_juego.bat cara). No hay ningun camino especial para la cara.
#
#  SOLO SE MONTA SI NO LLEVAS FOTO. Con imagen propia, tu imagen ES tu cara y estos rasgos
#  asomarian por debajo (ver JugadorSprites.capas_de).
#
#  TRES COSAS QUE NO SON OBVIAS:
#
#  1. EL CONTORNO SE FUNDE CON EL OJO A PROPOSITO. 'CapaJugador.plantilla' rodea de T_BORDE toda
#     silueta, y aqui la silueta son dos ojos de tres pixeles: con un borde oscuro alrededor de cada
#     uno, los ojos se convierten en dos manchones. Por eso en 'colores' el tono del borde es EL
#     MISMO que el del ojo -- el contorno sigue estando, pero no se ve como un anillo.
#
#  2. DE PERFIL SE DIBUJA UN SOLO OJO. Dibujando los dos y dejando que gire, el ojo de la otra mitad
#     de la cara acaba proyectado sobre la mejilla de esta y quedan dos ojos en un perfil.
#
#  3. DE ESPALDAS NO SE DIBUJA NADA. Es una nuca. Ademas cae solo: 'pintar' no mete ninguna pieza y
#     CapaJugador ya admite fotogramas vacios.
# ============================================================

extends RefCounted
class_name CaraSprites

const PIEZA := "cara"

enum Tono {
	VACIO = 0, SOMBRA_SUELO = 1, BORDE = 2,
	OJO,        # el iris y el contorno, que son el mismo tono (ver la cabecera)
	BOCA,
	BRILLO,     # el punto de luz del ojo: lo que separa un ojo de un agujero
}

const R := PoseJugador.CABEZA_R

# DONDE CAEN LOS RASGOS en la cabeza, en fracciones de su radio.
#
# LOS OJOS VAN BAJOS. En una cara real están a media altura; en este estilo van claramente por debajo
# del centro, y es lo que hace que la cabeza se lea como cabezona y no como un adulto en miniatura.
# Es la misma decision que ya se tomo con la proporcion del cuerpo, y esta medida en las mismas
# referencias.
# MEDIDO, no a ojo: el pelo tapa la cabeza hasta unas tres celdas por debajo de su centro, y la
# barbilla acaba diez mas abajo. Los ojos van en medio de esa franja -- que es la unica cara que se
# ve -- y no en el centro de la cabeza, que queda debajo del pelo.
const OJO_ALTO := -0.18          # respecto al centro de la cabeza
const OJO_SEPARACION := 0.34
# CUANTO SE ADELANTAN sobre el eje del cuerpo. Tiene que quedar DENTRO del fondo de la cabeza (0,90
# del radio) o los ojos asoman por delante de la silueta y se ven flotando junto a la cara.
const OJO_FONDO := 0.58
const BOCA_ALTO := -0.42
# CUANTO SE VA LA BOCA HACIA EL MORRO DE PERFIL. Antes de perfil no se dibujaba boca ninguna, y el
# resultado era un personaje con ojos y sin cara en cuatro de las ocho direcciones. Puesta en el eje
# cae sobre la mejilla, asi que se corre hacia el lado al que mira.
const BOCA_PERFIL := 0.30

# NARIZ Y CEJAS: PROBADAS Y DESCARTADAS, y queda escrito para que no se vuelvan a intentar a ciegas.
# La cara util son unas seis celdas de alto entre el pelo y la barbilla, y ahi un cuarto rasgo no
# cabe: la ceja se pega al ojo y los dos se leen como un manchon -- en "Tranquilos", donde el ojo ya
# es una raya, lo que salia era un ANTIFAZ. Si algun dia se reintenta, hace falta primero mas cara,
# no rasgos mas finos.


# --- Contrato de capa (ver CapaJugador y el registro de JugadorSprites) ---
static func frames(modelo: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.frames(clave(modelo), pintar.bind(modelo), colores(), esc)


static func generar(modelo: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.generar(clave(modelo), pintar.bind(modelo), colores(), esc)


static func clave(modelo: String) -> String:
	return "%s_%s" % [PIEZA, modelo]


# ESTA CAPA NO SE TIÑE (lleva "tinte": false en el catalogo): unos ojos no son del color de tu ropa.
# Lo que se hornea aqui es lo que se ve.
#
# El BORDE va del mismo color que el ojo: ver el punto 1 de la cabecera.
static func colores() -> Array:
	var ojo := Color(0.13, 0.09, 0.11)
	return [
		Color(0, 0, 0, 0),      # VACIO
		Color(0, 0, 0, 0.20),   # SOMBRA_SUELO (esta capa no la usa)
		ojo,                    # BORDE = el propio ojo
		ojo,                    # OJO
		Color(0.62, 0.28, 0.28),# BOCA
		Color(0.99, 0.99, 1.0), # BRILLO
	]


# ============================================================
#  EL PINTOR
# ============================================================
static func pintar(esq: Dictionary, piezas: Array, modelo: String) -> void:
	var d: int = int(esq.get("dir", 0))
	# 3, 4 y 5 son NE, N y NW: la nuca. Ahi no hay cara que dibujar.
	if d == 3 or d == 4 or d == 5:
		return
	var cab: Vector3 = esq["puntos"][PoseJugador.P_CABEZA]
	var de_perfil: bool = d == 2 or d == 6
	# De perfil, el unico ojo que se ve es el del lado hacia el que mira la camara (ver el punto 2).
	var lados: Array = [1.0, -1.0]
	if de_perfil:
		lados = [1.0] if d == 6 else [-1.0]

	match modelo:
		"puntos": _puntos(piezas, esq, cab, lados, de_perfil)
		"chibi": _chibi(piezas, esq, cab, lados, de_perfil)
		"linea": _linea(piezas, esq, cab, lados, de_perfil)


# EL MAS SIMPLE: dos ovalos pequeños. Lo que lo separa de los otros dos es el TAMAÑO del ojo, no que
# le falten rasgos: una cara con ojos y sin boca no es un estilo, es una cara a medio dibujar (y a
# este tamaño se lee como una linea y ya).
static func _puntos(piezas: Array, esq: Dictionary, cab: Vector3, lados: Array,
		de_perfil: bool) -> void:
	for s in lados:
		PoseJugador.poner(piezas, esq, _ojo(cab, float(s)),
			Vector3(R * 0.15, R * 0.12, R * 0.20), Tono.OJO)
	_boca(piezas, esq, cab, _boca_dx(lados, de_perfil))


# CON BRILLO Y BOCA: el ojo mas grande, con un punto de luz arriba. El brillo es lo que separa un ojo
# de un agujero -- sin el, a este tamaño, los dos ovalos se leen como dos huecos en la cara.
static func _chibi(piezas: Array, esq: Dictionary, cab: Vector3, lados: Array,
		de_perfil: bool) -> void:
	for s in lados:
		var c: Vector3 = _ojo(cab, float(s))
		PoseJugador.poner(piezas, esq, c, Vector3(R * 0.17, R * 0.13, R * 0.26), Tono.OJO)
		# El brillo, arriba y hacia el centro de la cara: la luz de este mundo viene de arriba (es la
		# misma direccion que el realce del pecho y el del pelo).
		PoseJugador.poner(piezas, esq,
			c + Vector3(-float(s) * R * 0.045, 0.0, R * 0.075),
			Vector3(R * 0.055, R * 0.05, R * 0.07), Tono.BRILLO, {"solo_sobre": [Tono.OJO]})
	_boca(piezas, esq, cab, _boca_dx(lados, de_perfil))


# LOS OJOS COMO RAYAS: la cara tranquila. Se separa de las otras dos por la FORMA y no por el tamaño
# -- a este tamaño, "un poco mas grande" no se distingue; "tumbado en vez de de pie", si.
static func _linea(piezas: Array, esq: Dictionary, cab: Vector3, lados: Array,
		de_perfil: bool) -> void:
	for s in lados:
		PoseJugador.poner(piezas, esq, _ojo(cab, float(s)),
			Vector3(R * 0.20, R * 0.14, R * 0.075), Tono.OJO)
	_boca(piezas, esq, cab, _boca_dx(lados, de_perfil))


# Donde cae un ojo. 's' es +1 el izquierdo y -1 el derecho, como en todo el cuerpo.
static func _ojo(cab: Vector3, s: float) -> Vector3:
	return cab + Vector3(s * R * OJO_SEPARACION, R * OJO_FONDO, R * OJO_ALTO)


# La boca: una raya corta. VA SIEMPRE, tambien de perfil (ver BOCA_PERFIL): de los tres modelos, dos
# se quedaban sin ella en las cuatro direcciones de perfil y el otro no la tenia nunca.
static func _boca(piezas: Array, esq: Dictionary, cab: Vector3, dx: float) -> void:
	PoseJugador.poner(piezas, esq,
		cab + Vector3(dx, R * OJO_FONDO, R * BOCA_ALTO),
		Vector3(R * 0.11, R * 0.10, R * 0.04), Tono.BOCA)


# CUANTO SE CORRE LA BOCA. De frente va en el eje; de perfil, hacia el lado al que mira la cara --
# que es el mismo lado del unico ojo que se dibuja (ver el punto 2 de la cabecera).
static func _boca_dx(lados: Array, de_perfil: bool) -> float:
	if not de_perfil:
		return 0.0
	return -float(lados[0]) * R * BOCA_PERFIL
