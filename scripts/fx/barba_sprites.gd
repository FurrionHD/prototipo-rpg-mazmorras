# ============================================================
#  barba_sprites.gd  (class_name BarbaSprites)
#  LA BARBA: la mitad de abajo de la cabeza.
#
#  Hermana del pelo, y con el mismo reparto de trabajo: UN SOLO PINTOR para todos los modelos, porque
#  la masa de la mandibula es la misma en los cuatro y lo unico que cambia es cuanto baja y si lleva
#  bigote. Cuatro funciones separadas serian cuatro sitios donde arreglar la misma mandibula.
#
#  VA POR ENCIMA DE LA CARA Y DE TU FOTO (z 2050, ver JugadorSprites.Z_BARBA), al reves que el pelo.
#  El pelo va DEBAJO de la foto para enmarcarla; una barba no enmarca nada, TAPA -- cubre la
#  mandibula y la boca, y por debajo de la foto lo unico que se veria seria el borde que asoma por
#  fuera del circulo de la cara, o sea casi nada.
#
#  SE TIÑE (se hornea en gris, ver CapaJugador.grises): el color lo elige el jugador, y va APARTE del
#  color del pelo a proposito -- un viejo con el pelo blanco y la barba castaña no existe, pero el
#  maestro de la Meditacion es justo el caso de "barba mas blanca que el pelo".
# ============================================================

extends RefCounted
class_name BarbaSprites

const PIEZA := "barba"

# Los tonos, en el orden de CapaJugador.grises: contorno, sombra, base, luz.
enum Tono {
	VACIO = 0, SOMBRA_SUELO = 1, BORDE = 2,
	PELO_S,     # la parte de fondo (bajo el menton, y el lado que queda en sombra)
	PELO,       # el tono base
	PELO_L,     # el brillo, por donde da la luz
}

const R := PoseJugador.CABEZA_R

# HACIA DONDE MIRA LA BARBA. En esta proyeccion +Y es "hacia la cara" y +Z es "arriba" (ver
# PeloSprites: el flequillo va a +Y y la nuca a -Y). Asi que la barba vive en +Y y -Z, y con un solo
# par de numeros queda bien en las ocho direcciones: de frente se ve entera y de espaldas la tapa la
# propia cabeza, que es exactamente lo que pasa de verdad.
#
# ============================================================
#  DONDE VA LA BARBA: se mide EN PANTALLA, no en Z
# ============================================================
# Los rasgos viven en CaraSprites con numeros exactos, asi que la barba se coloca RESPECTO A ELLOS.
# Pero comparar la Z de la barba con la Z de los ojos NO SIRVE, y ese fue el error que costo dos
# tandas: la camara va a 45 grados y proyecta
#
#     pantalla_y = (y * cos45 - z * sin45)     ->   proporcional a  (y - z)
#
# o sea que ADELANTARSE TAMBIEN BAJA. Una pieza puede estar por debajo en Z y aun asi salir a la
# altura de la mirada si esta menos adelantada. Por eso aqui todo se piensa en BAJADA = y - z, que es
# lo unico que se corresponde con lo que se ve.
#
#   ojos -> y = 0,58 · z = -0,18  ->  BAJADA 0,76
#   boca -> y = 0,58 · z = -0,42  ->  BAJADA 1,00
#
# LAS DOS REGLAS QUE SALEN DE AHI:
#   1. El BORDE DE ARRIBA de cualquier pieza que caiga en la vertical de los ojos tiene que quedar
#      por debajo de 0,76. Ese borde es BAJADA - ry - rz, no BAJADA a secas.
#   2. Lo que no cumpla eso tiene que apartarse en X. Los ojos ocupan de 0,19 a 0,49 de ancho
#      (separacion 0,34 ± radio 0,15), asi que a partir de 0,52 ya no estorban -- que es como se
#      salvan las patillas, que por definicion suben por el lado de la cara.
#
# La primera version fallaba las dos: el bigote a BAJADA 0,82 (seis centesimas por debajo de los
# ojos, o sea un pixel) y las patillas a 0,71, o sea POR ENCIMA. Eso es lo que se veia como "la barba
# se mezcla con los ojos": no era un solape raro, es que estaba mas arriba que ellos.
const OJOS_BAJADA := 0.76

# Y LA TERCERA REGLA, que es la que costo la ultima tanda: PARA BAJAR EN PANTALLA HAY QUE
# ADELANTARSE, NO HUNDIRSE.
#
# Como la bajada es (y - z), una pieza puede ganar altura de dos maneras -- subiendo la Y o bajando
# la Z --, pero NO son equivalentes: la cabeza es una bola de radio 1, asi que hundir la Z se sale
# por abajo. Poniendo la mandibula a fondo 0,36 y bajada 1,26 salia z = -0,90, y con su propio radio
# llegaba a -1,14: FUERA DE LA CABEZA, colgando sobre el cuello. De frente colaba, y de perfil se
# veia una mancha descolgada al lado de la cara -- que es justo lo que se reporto.
#
# La cara lo hace bien: consigue su bajada con y = 0,58 y z = -0,18, o sea ADELANTANDOSE. La barba
# vive en la misma franja de fondo que ella, un poco mas abajo. El fondo de la cabeza es 0,90, asi
# que 0,55 + un radio de 0,22 = 0,77 sigue dentro.
const DELANTE := 0.55

# BAJADA de la masa de la mandibula: 1,15 deja su borde de arriba (1,15 - 0,22 - 0,18 = 0,75) justo
# al filo de los ojos, y su z en -0,60, bien dentro de la cabeza.
const BAJADA_MASA := 1.15
# Y la del bigote: justo la de la boca, que es donde va un bigote.
const BAJADA_BIGOTE := 1.00

# Lo que sobresale de la cara. Como el pelo, tiene que pasar de una celda (1,15) o la barba sale a
# trozos entre los pixeles de la cabeza, como suciedad en vez de pelo.
const GROSOR := 1.3


# --- Contrato de capa (ver CapaJugador y el registro de JugadorSprites) ---
static func frames(modelo: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.frames(clave(modelo), pintar.bind(modelo), colores(), esc)


static func generar(modelo: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.generar(clave(modelo), pintar.bind(modelo), colores(), esc)


static func clave(modelo: String) -> String:
	return "%s_%s" % [PIEZA, modelo]


static func colores() -> Array:
	# Los mismos grises que el pelo: es el mismo material y tienen que poder llevar el mismo color
	# sin que uno salga mas apagado que el otro.
	return CapaJugador.grises(0.20, 0.38, 0.62, 0.82, 0.94)


# ============================================================
#  EL PINTOR
# ============================================================
static func pintar(esq: Dictionary, piezas: Array, modelo: String) -> void:
	# DE ESPALDAS NO HAY BARBA, exactamente igual que no hay ojos (ver CaraSprites.pintar): 3, 4 y 5
	# son NE, N y NW, o sea la nuca.
	#
	# HAY QUE DECIDIRLO AQUI, POR DIRECCION, Y NO CONFIAR EN QUE LA TAPE LA CABEZA. Esta capa va con
	# z FIJO y por encima de todo (JugadorSprites.Z_BARBA), asi que nada la oculta nunca: en la
	# primera hoja de contacto la barba se veia flotando sobre la NUCA en las tres direcciones de
	# espaldas. El pelo no tiene este problema porque el casquete cubre la cabeza entera y es
	# simetrico; una barba solo existe por delante.
	var d: int = int(esq.get("dir", 0))
	if d == 3 or d == 4 or d == 5:
		return
	var p: Dictionary = esq["puntos"]
	var cab: Vector3 = p[PoseJugador.P_CABEZA]

	match modelo:
		"bigote":
			_bigote(piezas, esq, cab, 1.0)
		"perilla":
			_bigote(piezas, esq, cab, 0.85)
			_perilla(piezas, esq, cab)
		"candado":
			_bigote(piezas, esq, cab, 0.95)
			_mandibula(piezas, esq, cab, 0.55)
			_perilla(piezas, esq, cab)
		"poblada":
			_bigote(piezas, esq, cab, 1.05)
			_mandibula(piezas, esq, cab, 1.0)
		"larga":
			_bigote(piezas, esq, cab, 1.05)
			_mandibula(piezas, esq, cab, 1.0)
			# LA PUNTA se mece con el paso, igual que la coleta: una barba larga que va tiesa mientras
			# el personaje anda se lee como una tabla colgada del menton.
			_punta(piezas, esq, cab, float((esq["pose"] as Dictionary).get("paso", 0.0)),
				float(esq.get("caida", 0.0)))
		_:
			_mandibula(piezas, esq, cab, 0.8)


# LA MASA DE LA MANDIBULA: lo que va de patilla a patilla por debajo de la cara. 'grueso' es cuanto
# baja y cuanto sobresale.
#
# VA ACHATADA EN Y Y ANCHA EN X. Redonda se lee como una bufanda o como una papada: lo que la hace
# barba es que sea ANCHA (de oreja a oreja) y POCO PROFUNDA, pegada a la cara.
static func _mandibula(piezas: Array, esq: Dictionary, cab: Vector3, grueso: float) -> void:
	var g: float = GROSOR * grueso
	var y: float = R * DELANTE
	# EL FONDO PRIMERO. No hay z-buffer dentro de una capa -- el orden de la lista es la profundidad
	# --, asi que lo que va detras se pinta antes. Es la misma regla que la nuca del pelo, y saltarsela
	# deja un manchon de sombra cruzando por encima de la barba.
	# La de sombra va solo UN PELIN mas atras (0,08), no al 68% del fondo: retrasarla de verdad la
	# obligaba a hundir la Z para mantener la bajada, y volvia a salirse de la cabeza por abajo.
	var fondo_s: float = DELANTE - 0.08
	PoseJugador.poner(piezas, esq,
		Vector3(cab.x, cab.y + R * fondo_s, cab.z + _z_de(BAJADA_MASA + 0.05, fondo_s)),
		Vector3(R * (0.34 + 0.10 * grueso), R * 0.20, R * (0.13 + 0.08 * grueso)), Tono.PELO_S)
	PoseJugador.poner(piezas, esq,
		Vector3(cab.x, cab.y + y, cab.z + _z_de(BAJADA_MASA, DELANTE)),
		Vector3(R * (0.32 + 0.12 * grueso) + g * 0.25, R * 0.22 + g * 0.18,
			R * (0.14 + 0.10 * grueso) + g * 0.18), Tono.PELO)
	# SIN PATILLAS. Se probaron dos veces y las dos se leyeron como CUERNOS: una patilla sube por el
	# lado de la cara, o sea que por fuerza llega a la altura de la mirada, y a este tamaño dos
	# manchas a los lados de los ojos no dicen "barba" -- dicen "orejeras". La mandibula sola ya sube
	# lo justo por los lados para no parecer una careta colgada del menton.
	#
	# Si algun dia hacen falta: tendrian que ir por FUERA de 0,52 de ancho (los ojos acaban en 0,49) y
	# muy pegadas a la masa, sin hueco entre medias.


# EL BIGOTE: la raya bajo la nariz. Es la pieza que mas dice a este tamaño -- una barba sin bigote se
# lee como una bufanda subida --, asi que la llevan los cuatro modelos.
#
# A LA BAJADA DE LA BOCA (1,00), que es donde va un bigote. Y FINO EN PROFUNDIDAD (ry 0,10): el borde
# de arriba es BAJADA - ry - rz, asi que engordarlo en Y lo sube en pantalla igual que subirlo en Z.
static func _bigote(piezas: Array, esq: Dictionary, cab: Vector3, ancho: float) -> void:
	var fondo: float = DELANTE + 0.14
	PoseJugador.poner(piezas, esq,
		Vector3(cab.x, cab.y + R * fondo, cab.z + _z_de(BAJADA_BIGOTE, fondo)),
		Vector3(R * 0.30 * ancho, R * 0.10, R * 0.06), Tono.PELO)


# LA PERILLA: el mechon del menton, estrecho y centrado. Lo que separa una perilla de una barba
# poblada es que NO llega a las patillas.
static func _perilla(piezas: Array, esq: Dictionary, cab: Vector3) -> void:
	# +0,18 de bajada y no +0,26: con 0,26 la z se iba a -0,82 y con su radio llegaba a -1,04, o sea
	# por debajo del borde de la cabeza. Una perilla asoma del menton, no cuelga del cuello.
	var fondo: float = DELANTE + 0.04
	PoseJugador.poner(piezas, esq,
		Vector3(cab.x, cab.y + R * fondo, cab.z + _z_de(BAJADA_MASA + 0.18, fondo)),
		Vector3(R * 0.16, R * 0.18, R * 0.20), Tono.PELO)


# LA Z QUE HACE FALTA para que una pieza caiga a la BAJADA pedida estando a ese fondo. Despeja
# z = y - bajada, que es la cuenta de la cabecera. Todo en radios de cabeza; devuelve unidades.
#
# Existe para no volver a colocar nada "por su Z": la altura a la que se ve una pieza depende de las
# DOS coordenadas, y a mano eso se falla (se fallo dos veces seguidas).
static func _z_de(bajada: float, fondo: float) -> float:
	return R * (fondo - bajada)


# LA PUNTA DE LA BARBA LARGA: cae desde el menton hacia el pecho, meciendose con el paso.
static func _punta(piezas: Array, esq: Dictionary, cab: Vector3, vaiven: float,
		caida: float) -> void:
	# Arranca donde acaba la mandibula, un poco mas abajo, y usando la misma cuenta de bajada.
	var arriba: Vector3 = Vector3(cab.x, cab.y + R * DELANTE,
		cab.z + _z_de(BAJADA_MASA + 0.18, DELANTE))
	# SE RECOGE AL CAERSE, igual que la coleta y por el mismo motivo: tiesa, con el cuerpo tumbado la
	# barba se sale del lienzo y el horno la corta en seco con una raya recta. Y ademas es lo que hace
	# el pelo de verdad: tumbado se apelmaza, no se queda apuntando al frente.
	var tumbado: float = clampf(absf(caida) / (PI * 0.5), 0.0, 1.0)
	var largo: float = lerpf(1.0, 0.45, sqrt(tumbado))
	var medio: Vector3 = arriba + Vector3(vaiven * R * 0.14, R * 0.05, -R * 0.42 * largo)
	var punta: Vector3 = arriba + Vector3(vaiven * R * 0.24, -R * 0.02, -R * 0.86 * largo)
	PoseJugador.cadena(piezas, esq, arriba, medio, R * 0.30, R * 0.22, Tono.PELO)
	PoseJugador.cadena(piezas, esq, medio, punta, R * 0.22, R * 0.10, Tono.PELO_S)
