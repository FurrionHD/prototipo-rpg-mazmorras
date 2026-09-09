# ============================================================
#  gorro_sprites.gd  (class_name GorroSprites)
#  EL GORRO: lo que se lleva puesto en la cabeza.
#
#  Es la pieza que mas cambia la silueta desde arriba, que es como se ve el personaje en el mapa. Un
#  sombrero de mago en punta se reconoce de un vistazo aunque el muñeco mida cuarenta pixeles, y por
#  eso es el que abre la lista: el MAESTRO de la Meditacion es exactamente eso, un viejo con sombrero
#  picudo y barba (ver BarbaSprites).
#
#  VA POR ENCIMA DE TODO LO DE LA CABEZA (z 2051, ver JugadorSprites.Z_GORRO): por encima del pelo,
#  de la cara y de tu foto. Un sombrero tapa la frente y aplasta el flequillo; puesto por debajo, el
#  pelo se le dibujaba encima y parecia que el pelo atravesaba el ala.
#
#  UN SOLO PINTOR PARA TODOS LOS MODELOS: la copa y el ala son las mismas piezas en casi todos, y lo
#  que cambia es la forma de la copa (picuda, redonda, plana) y si lleva ala o no.
#
#  SE TIÑE, asi que se hornea en gris (ver CapaJugador.grises).
# ============================================================

extends RefCounted
class_name GorroSprites

const PIEZA := "gorro"

# Los tonos, en el orden de CapaJugador.grises: contorno, sombra, base, luz.
enum Tono {
	VACIO = 0, SOMBRA_SUELO = 1, BORDE = 2,
	TELA_S,     # la parte de fondo (el ala por detras, el lado en sombra)
	TELA,       # el tono base
	TELA_L,     # el brillo de arriba
}

const R := PoseJugador.CABEZA_R

# DONDE SE APOYA EL GORRO. Va por encima de la coronilla y un poco hacia atras, igual que el casquete
# del pelo (ver PeloSprites.ARRIBA/ATRAS) y por el mismo motivo: en esta camara "hacia atras" sube en
# pantalla mirando al sur y baja mirando al norte, asi que con un solo par de numeros el ala destapa
# la cara de frente y baja por la nuca de espaldas. Sin un caso por direccion.
const ATRAS := 1.2
const POSA := 4.6

# Lo que la copa sobresale de la cabeza. Igual que el pelo, tiene que pasar de una celda (1,15) o
# aparece a trozos entre los pixeles del craneo.
const GROSOR := 1.7

# LA PUNTA DEL SOMBRERO DE MAGO. Cuanto sube por encima de la copa, en radios de cabeza.
#
# 3,2 Y NO MAS: el lienzo del muñeco tiene un techo (ver el validador de recortes del horno), y una
# punta mas larga se sale por arriba en las poses en las que el cuerpo se estira. Ademas a partir de
# ahi deja de leerse como sombrero y parece una antena.
const PUNTA_ALTO := 3.2
# CUANTO SE INCLINA LA PUNTA HACIA ATRAS. Recta se lee como un cucurucho; caida da el aire de
# sombrero de mago de verdad, que es lo que se ha pedido.
const PUNTA_CAE := 0.55


# --- Contrato de capa (ver CapaJugador y el registro de JugadorSprites) ---
static func frames(modelo: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.frames(clave(modelo), pintar.bind(modelo), colores(), esc)


static func generar(modelo: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.generar(clave(modelo), pintar.bind(modelo), colores(), esc)


static func clave(modelo: String) -> String:
	return "%s_%s" % [PIEZA, modelo]


static func colores() -> Array:
	# Un escalon mas claro que el pelo: la tela de un sombrero coge mas luz que el pelo, y con los
	# grises del pelo el sombrero se leia como una mancha oscura pegada a la cabeza.
	return CapaJugador.grises(0.20, 0.44, 0.66, 0.84, 0.96)


# ============================================================
#  EL PINTOR
# ============================================================
static func pintar(esq: Dictionary, piezas: Array, modelo: String) -> void:
	var p: Dictionary = esq["puntos"]
	var cab: Vector3 = p[PoseJugador.P_CABEZA]

	match modelo:
		"mago":
			_ala(piezas, esq, cab, 1.02, 0.10)
			_cono(piezas, esq, cab, PUNTA_ALTO, PUNTA_CAE)
		"chambergo":
			# El de ala ancha y copa baja: el sombrero de aventurero.
			_ala(piezas, esq, cab, 1.18, 0.12)
			_copa(piezas, esq, cab, 0.62, 0.82)
		"capucha":
			_capucha(piezas, esq, cab, float(esq.get("caida", 0.0)))
		"gorro":
			# Un gorro de lana pegado al craneo, sin ala. El mas discreto de los cuatro.
			_copa(piezas, esq, cab, 0.55, 1.05)
			_vuelta(piezas, esq, cab)
		_:
			_copa(piezas, esq, cab, 0.70, 1.0)


# EL ALA: el disco que rodea la cabeza. Va MUY achatado -- es un disco, no un cuenco -- y ese
# aplastamiento es lo unico que lo diferencia de una copa baja.
#
# EL ANCHO SE MIDE EN RADIOS DE CABEZA, Y AHI ESTUVO EL FALLO GORDO: la primera version iba a 1,55 y
# el ala salia mas ancha que los HOMBROS -- en la hoja de contacto el personaje era una seta gris con
# dos piernas. Un ala de sombrero sobresale de la cabeza, no del cuerpo: por encima de ~1,35 deja de
# leerse como sombrero.
#
# Y VA A LA ALTURA DE LA CORONILLA, no de la frente: puesta a POSA*0,62 el ala caia justo por delante
# de la cara y, con el zoom del creador, el personaje no tenia cara -- solo un ala morada con una
# barba asomando por debajo. Un sombrero se apoya ENCIMA de la cabeza.
#
# Y EL RADIO EN PROFUNDIDAD (Y) ES LA MITAD DEL DE ANCHO (X), no casi igual. Es lo que arreglo que el
# ala tapara los ojos, y el motivo es la camara: esta a 45 grados, asi que lo que se adelanta en Y
# BAJA EN PANTALLA. Con el ala casi circular en planta (Y = 0,92 del ancho) su borde delantero se
# proyectaba un radio entero hacia abajo y caia justo sobre la mirada -- de frente los ojos asomaban
# por los pelos y de perfil desaparecian.
#
# Aplastarla en Y no se nota como "ala estrecha": desde arriba sigue viendose el disco entero, porque
# lo que la camara acorta es precisamente ese eje.
static func _ala(piezas: Array, esq: Dictionary, cab: Vector3, ancho: float, alto: float) -> void:
	PoseJugador.poner(piezas, esq,
		cab + Vector3(0.0, -ATRAS * 0.5, POSA * 1.15),
		Vector3(R * ancho, R * ancho * 0.48, R * alto), Tono.TELA)


# LA COPA: la masa que cubre el craneo. 'alto' en radios de cabeza y 'ancho' como fraccion.
#
# TAMBIEN ACHATADA EN Y (0,66 del ancho), por lo mismo que el ala: lo que se adelanta en profundidad
# baja en pantalla, y una copa redonda en planta se derrama sobre la frente. Menos que el ala porque
# la copa se apoya mas arriba y tiene menos margen que ganar.
static func _copa(piezas: Array, esq: Dictionary, cab: Vector3, alto: float, ancho: float) -> void:
	var g: float = GROSOR
	PoseJugador.poner(piezas, esq,
		cab + Vector3(0.0, -ATRAS, POSA + R * alto * 0.35),
		Vector3(R * ancho + g * 0.5, R * ancho * 0.66 + g * 0.3, R * alto + g * 0.4), Tono.TELA)


# LA VUELTA del gorro de lana: la franja de abajo, mas gorda. Es lo que lo hace gorro y no calva.
static func _vuelta(piezas: Array, esq: Dictionary, cab: Vector3) -> void:
	PoseJugador.poner(piezas, esq,
		cab + Vector3(0.0, -ATRAS * 0.6, POSA * 0.55),
		Vector3(R * 1.12, R * 1.02, R * 0.22), Tono.TELA_L)


# EL CONO DEL SOMBRERO DE MAGO: de la copa a la punta, estrechandose y cayendo hacia atras.
#
# EN DOS TRAMOS Y NO EN UNO. De una sola cadena, el cono sale recto y se lee como un cucurucho de
# helado; partiendolo, el tramo de arriba cae mas que el de abajo y queda la curva que hace que se
# reconozca como sombrero de mago.
static func _cono(piezas: Array, esq: Dictionary, cab: Vector3, alto: float, cae: float) -> void:
	var base: Vector3 = cab + Vector3(0.0, -ATRAS, POSA)
	var medio: Vector3 = base + Vector3(0.0, -R * cae * 0.45, R * alto * 0.52)
	var punta: Vector3 = base + Vector3(0.0, -R * cae * 1.35, R * alto)
	# La base va del tono de fondo para que el ala, que se pinta antes y por delante, no se pierda
	# contra ella.
	PoseJugador.cadena(piezas, esq, base, medio, R * 0.62, R * 0.34, Tono.TELA)
	PoseJugador.cadena(piezas, esq, medio, punta, R * 0.34, R * 0.08, Tono.TELA_S)


# LA CAPUCHA: envuelve la cabeza por arriba y por detras, y deja la cara al aire.
#
# LA ABERTURA NO SE DIBUJA -- no hay forma de restar un agujero de una masa de elipsoides --, asi que
# se consigue de dos maneras a la vez, y hacen falta LAS DOS:
#   1. TODA masa que caiga en la vertical de la cara se queda POR ENCIMA de los ojos.
#   2. Lo que enmarca la cara se aparta EN X, a los lados, donde ya puede colgar hasta la mandibula.
#
# Y esto se mide, no se estima. La cuenta unica es la BAJADA = y - z (ver la cabecera de
# CaraSprites y la memoria de la altura en pantalla): la camara va a 45 grados, asi que adelantarse
# baja lo mismo que hundirse. En radios de cabeza, los OJOS estan en BAJADA 0,76 y ocupan de 0,19 a
# 0,49 de ancho; la boca, en BAJADA 1,00. El borde de abajo de una masa central es
# 'bajada_centro + sqrt(ry^2 + rz^2)' -- no 'bajada + rz', que es el error que se cometio aqui.
#
# LO QUE ESTABA MAL, Y NO ERA LA COPA. La copa ya libraba de sobra (borde en 0,56 R contra los ojos
# en 0,76), y aun asi en la hoja de contacto no habia UN SOLO OJO en las ocho direcciones: la que
# tapaba la cara era LA CAIDA, una bola de radio 0,86 R plantada casi en el centro del craneo, cuyo
# borde caia en BAJADA 0,95 -- por debajo de los ojos y casi en la boca. Y como la capa del gorro va
# por encima de la cara (z 2051 contra 2048), no hay profundidad que valga: lo que solape en
# PANTALLA, tapa. Estar "detras de la cabeza" no salva a nada dentro de esta capa.
static func _capucha(piezas: Array, esq: Dictionary, cab: Vector3, caida: float) -> void:
	var g: float = GROSOR
	# EL PICO SE RECOGE AL CAERSE, igual que la coleta del pelo y la punta de la barba larga. Tieso,
	# con el cuerpo tumbado el pico queda extendido en horizontal y LLEGA AL BORDE del lienzo: el
	# validador de recortes del horno lo cazo en 'muerte_4 f4', y lo que se ve cuando eso pasa es la
	# capucha cortada en seco por una raya recta, sin ningun error de por medio.
	# Con raiz y no lineal: se recoge desde el primer grado de caida, que es lo que hacia falta -- con
	# lineal seguia saliendose en el fotograma de en medio, justo el del cuerpo a 45 grados.
	var tumbado: float = clampf(absf(caida) / (PI * 0.5), 0.0, 1.0)
	var largo: float = lerpf(1.0, 0.40, sqrt(tumbado))
	# UNA SOLA SILUETA, no tres bultos. La primera version eran tres elipsoides sueltos -- la caida de
	# la nuca, la copa y un pico -- colocados cerca pero sin solaparse de verdad, y lo que salia era
	# un muñeco con DOS LOBULOS pegados y un cuerno apuntando al cielo. Textualmente: "los sombreros
	# tienen tumores".
	#
	# El arreglo es de forma, no de tamaño: la caida va con CADENA desde dentro de la copa, asi que
	# las dos masas comparten volumen y se leen como una sola tela. Y el pico se ha ido: un pico de
	# capucha cae hacia ATRAS Y ABAJO, y aquel subia -- por eso se veia como un cuerno y no como tela.
	#
	# LA CAIDA VA PRIMERO: esta detras y se pinta antes (no hay z-buffer dentro de una capa).
	# 'largo' la recoge al caerse, igual que la coleta del pelo: tiesa, con el cuerpo tumbado llegaba
	# al borde del lienzo y el horno la cortaba en seco (lo cazo en 'muerte_4 f4').
	#
	# EL EXTREMO DE ARRIBA NO VA EN EL CENTRO DE LA CABEZA, va DENTRO DE LA COPA (retrasado y alto).
	# Es lo unico que hay que entender de esta pieza: la caida y la copa tienen que compartir volumen
	# para leerse como una sola tela, y hay dos sitios donde compartirlo -- el centro del craneo, que
	# derrama sobre la cara, y el hueco de la copa, que no.
	#
	# Y ADELGAZA de 0,86 R a 0,62. Con 0,86 la bola se salia de la copa por ARRIBA y por DETRAS -- la
	# capucha se leia como un moño enorme, mas alta y mas larga que la cabeza --, y el bulto de mas no
	# aportaba nada: lo que tiene que verse de la caida es la tela bajando por la nuca, no una masa
	# asomando por encima del craneo. La regla, para cualquier pieza que se funda dentro de otra: si el
	# extremo interior sobresale de la masa que lo contiene, deja de ser una fusion y es un bulto.
	var dentro: Vector3 = cab + Vector3(0.0, -R * 0.30, R * 0.10)
	var nuca: Vector3 = cab + Vector3(0.0, -R * (0.30 + 0.34 * largo), -R * 0.34 * largo)
	PoseJugador.cadena(piezas, esq, dentro, nuca,
		R * 0.62, R * (0.28 + 0.18 * largo), Tono.TELA_S)
	# Y LA COPA. Achatada en Y por lo mismo que el ala (la capucha redonda en planta se derramaba sobre
	# la cara) y sobre todo BIEN ATRAS: retrasarla en Y la SUBE en pantalla (pantalla_y va con y - z),
	# que es el mismo truco que usa el casquete del pelo. Con ATRAS * 0,8 la capucha era un casco.
	#
	# Y ACHATADA TAMBIEN EN Z (0,62 R y no 0,80), subida a POSA * 1,15: una capucha es una CAPUCHA
	# APOYADA sobre el craneo, no una bola que lo envuelve. Con la bola el borde de abajo quedaba a dos
	# unidades de los ojos -- libraba en la cuenta y en el dibujo los ojos asomaban por los pelos --, y
	# asi se queda a cinco. Lo que deja de cubrir por los lados lo cubren los faldones.
	var c_copa: Vector3 = cab + Vector3(0.0, -ATRAS * 2.2, POSA * 1.15)
	var r_copa := Vector3(R * 1.00 + g * 0.5, R * 0.66 + g * 0.3, R * 0.62 + g * 0.4)
	PoseJugador.poner(piezas, esq, c_copa, r_copa, Tono.TELA)
	# LOS FALDONES ANTES QUE EL REBORDE, y no al reves: el filo de la abertura es un borde CONTINUO
	# que pasa por delante de todo lo que rodea la cara, faldones incluidos. Pintado antes, los
	# faldones lo repintaban con el tono claro por los dos lados y del filo solo quedaba el trozo
	# central. Dentro de una capa no hay z-buffer: el orden ES la profundidad.
	_faldones(piezas, esq, cab, largo)
	_reborde(piezas, esq, cab)


# EL REBORDE: el filo de la abertura, en sombra, justo por encima de la cara.
#
# ES LO QUE LA CONVIERTE EN UN HUECO. Con la copa lisa la capucha era una cupula gris perfecta y se
# leia como PELO -- una masa redonda apoyada en la cabeza --, por mucho que la cara asomara debajo.
# Lo que dice "esto es una abertura y no una superficie" no es la forma, es que el filo este mas
# oscuro que la tela: es la unica pista que separa un agujero de un bulto a este tamaño.
#
# ES UN FILO, NO UNA MASA ENCOGIDA. Se probo antes con la propia elipse de la copa un 14% mas
# pequeña y bajada, contando con que asomara solo la franja de abajo, y lo que salio fue una RAYA
# VERTICAL POR EL CENTRO DE LA CUPULA: los faldones repintan los lados con el tono claro, asi que de
# la elipse oscura solo quedaba a la vista la columna de en medio. La leccion vale para cualquier
# sombreado de estas capas -- una pieza "de dentro" solo se ve donde no la tape lo que se pinta
# despues, asi que hay que dibujar LA FRANJA QUE SE QUIERE VER, no un bulto del que se espera que
# asome un trozo.
#
# ES UN ARCO, NO UNA FRANJA RECTA. Primero se probo con un disco ancho tumbado en el filo de la
# copa, y lo que salia era una BANDA HORIZONTAL cruzando la cupula de lado a lado: eso no es una
# capucha, es una GORRA CON VISERA. El borde de una capucha SUBE en la frente y BAJA por los lados de
# la cara, y esa curva es justo lo que dice "aqui hay un agujero y la cabeza esta dentro".
#
# LOS DOS EXTREMOS PUEDEN BAJAR MAS QUE EL CENTRO porque estan a 0,62 de ancho, fuera de la columna
# de los ojos (que llega a 0,49). PERO LO QUE HAY QUE MIRAR NO SON LOS EXTREMOS, ES LA MITAD DE LA
# CURVA: la primera version iba de BAJADA 0,45 en la frente a 0,80 en el costado y tapaba los ojos,
# porque a media cadena -- todavia a 0,33 de ancho, o sea DENTRO de la mirada -- ya iba por 0,62 y con
# su grosor llegaba a 0,80. Una cadena interpola en linea recta, asi que la comprobacion es en el
# punto donde cruza 0,52 de ancho, no en la punta. Ahora: frente 0,30, costado 0,62, y al cruzar 0,52
# de ancho va por 0,57 + 0,18 de grosor = 0,75, justo por encima de los ojos (0,76).
#
# Y SOLO POR DELANTE (3, 4 y 5 son la nuca). Una capucha tiene UNA abertura y esta delante; pintado
# tambien de espaldas, el arco aparece como una banda oscura cruzando la coronilla. Estas capas van
# con z fijo y por encima, asi que nada las oculta al girar -- hay que apagarlas a mano.
static func _reborde(piezas: Array, esq: Dictionary, cab: Vector3) -> void:
	var d: int = int(esq.get("dir", 0))
	if d == 3 or d == 4 or d == 5:
		return
	var frente: Vector3 = cab + Vector3(0.0, R * 0.20, -R * 0.10)
	for lado in 2:
		var s: float = 1.0 if lado == 0 else -1.0
		var costado: Vector3 = cab + Vector3(s * R * 0.62, R * 0.12, -R * 0.50)
		PoseJugador.cadena(piezas, esq, frente, costado, R * 0.13, R * 0.12, Tono.TELA_S)


# LOS FALDONES: los dos lienzos que caen por los lados de la cara, de la copa a la mandibula.
#
# SON LO QUE HACE QUE SE LEA COMO CAPUCHA ABIERTA, y no un detalle. Sin ellos la copa sola es un
# GORRO: una masa apoyada encima de la cabeza y la cara al aire por completo. Lo que dice "capucha"
# es que la tela BAJE al lado de la cara, o sea que la cara este DENTRO de un hueco. Es la misma
# jugada que las patillas del pelo (ver PeloSprites._casquete), y por el mismo motivo.
#
# VAN A 0,78 R DE ANCHO, y ese numero es toda la pieza: los ojos ocupan hasta 0,49 de ancho, asi que
# a partir de ~0,52 una masa ya no estorba a la mirada y puede colgar todo lo que quiera. Puestos mas
# al centro volverian a ser el problema de la caida, solo que por duplicado.
#
# Y SE RECOGEN CON 'largo' como la caida: tiesos, con el cuerpo tumbado (muerte, encaje) se quedan
# extendidos y llegan al borde del lienzo, que es lo que caza el validador de recortes del horno.
static func _faldones(piezas: Array, esq: Dictionary, cab: Vector3, largo: float) -> void:
	for lado in 2:
		var s: float = 1.0 if lado == 0 else -1.0
		# Arriba, METIDO EN LA COPA (z alto y retrasado) para que funda con ella; abajo, a la altura
		# de la mandibula y un pelin adelantado, que es como cae una tela que rodea una cara.
		var alto: Vector3 = cab + Vector3(s * R * 0.72, -R * 0.26, R * 0.44)
		var bajo: Vector3 = cab + Vector3(s * R * 0.70, R * 0.04, -R * 0.50 * largo)
		PoseJugador.cadena(piezas, esq, alto, bajo, R * 0.38, R * 0.26, Tono.TELA)
