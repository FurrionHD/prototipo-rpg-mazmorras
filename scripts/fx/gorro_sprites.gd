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


# LA CAPUCHA
#
# ESTA COPIADA DEL CASCO ABIERTO DE CUERO (ver ArmaduraSprites._casco_abierto). No por ahorrar
# trabajo: es que es EL MISMO PROBLEMA -- una masa que envuelve el craneo y tiene que parar justo por
# encima de los ojos -- y alli ya esta resuelto y medido. De hecho el comentario de aquel fichero lo
# dice antes de que hiciera falta: el canto oscuro del casco de cuero va fino "que es lo que tiene
# una capucha".
#
# Antes de copiarlo, esta pieza se intento tres veces a mano y las tres salieron mal, cada una peor
# que la anterior:
#   1. Tres elipsoides sueltos: el muñeco con "tumores" -- dos lobulos y un cuerno.
#   2. Una copa achatada + faldones a los lados: ni un ojo visible en las ocho direcciones. Lo que
#      tapaba la cara no era la copa sino LA CAIDA, una bola de 0,86 R plantada en el centro del
#      craneo cuyo borde llegaba a BAJADA 0,95 (los ojos estan en 0,76 y la boca en 1,00).
#   3. Los mismos faldones con un arco de sombra: un moño enorme con dos orejas.
# La leccion no es sobre capuchas: cuando una pieza nueva es la misma jugada que una que ya funciona,
# se parte de aquella y se cambia lo que de verdad la distingue. Aqui son DOS cosas -- la caida de la
# nuca, que un casco no tiene, y que la tela es mas gorda que el cuero.
#
# LA CUENTA CON LA QUE SE COMPRUEBA TODO ESTO es la BAJADA = y - z (ver la memoria de la altura en
# pantalla): la camara va a 45 grados, asi que adelantarse baja lo mismo que hundirse. El borde de
# abajo de una masa central esta en 'bajada_centro + sqrt(ry^2 + rz^2)' -- NO en 'bajada + rz', que
# es el error del que salieron los tres intentos. Aqui: -(1,6 + 4,8) + sqrt(13,2^2 + 9,0^2) = 9,6,
# y los ojos en 9,7. O sea que la capucha muere en la ceja, como el casco.
#
# Y ojo con la capa: el gorro va por encima de la cara (z 2051 contra 2048), asi que no hay
# profundidad que valga. Lo que solape EN PANTALLA, tapa, este delante o detras de la cabeza.

# Los tres numeros de la cazoleta, heredados del casco abierto (ABIERTO_ATRAS / ARRIBA / ALTO).
# ARRIBA sube de 4,4 a 4,8 y no es un retoque a ojo: la tela es mas gorda que el cuero (GROSOR 1,7
# contra 1,4) y ese grosor de mas baja el borde cuatro decimas justo encima de los ojos. Al engordar
# una pieza copiada hay que devolverle la altura que el grosor le quita.
const CAP_ATRAS := 1.6
const CAP_ARRIBA := 4.8
const CAP_ALTO := 0.64
# EL CANTO: la media luna oscura del filo, que es el borde de la abertura. Se hace pintando la masa
# entera en sombra y repitiendola en tono base UN POCO MAS ARRIBA (ver ArmaduraSprites._chapa); lo
# que asoma por debajo es el filo. NO se hace con una banda plana: en esta camara el FONDO de una
# banda ancha proyecta hacia arriba y se come la pieza entera -- alli costo dos intentos y aqui otro.
const CAP_CANTO := 2.4
# CUANTO BAJA LA TELA POR EL LADO DE LA CARA. El casco lo llama CARRILLERA y lo gradua por tipo
# (cuero 0,35, hierro 0,62); una capucha tapa mas que un capacete y menos que un yelmo.
const CAP_MEJILLA := 0.55


static func _capucha(piezas: Array, esq: Dictionary, cab: Vector3, caida: float) -> void:
	var g: float = GROSOR
	# LA CAIDA SE RECOGE AL TUMBARSE, igual que la coleta del pelo y la punta de la barba larga.
	# Tiesa, con el cuerpo tumbado queda extendida en horizontal y LLEGA AL BORDE del lienzo: lo caza
	# el validador de recortes del horno ('muerte_4 f4'), y lo que se ve es la capucha cortada en seco
	# por una raya recta, sin ningun error de por medio. Con raiz y no lineal: se recoge desde el
	# primer grado de caida, que es lo que hacia falta -- con lineal seguia saliendose en el fotograma
	# de en medio, justo el del cuerpo a 45 grados.
	var tumbado: float = clampf(absf(caida) / (PI * 0.5), 0.0, 1.0)
	var largo: float = lerpf(1.0, 0.40, sqrt(tumbado))

	var centro: Vector3 = cab + Vector3(0.0, -CAP_ATRAS, CAP_ARRIBA)
	var r := Vector3(R + g, R * 0.90 + g, R * CAP_ALTO + g * 0.5)

	# 1. LA CAIDA DE LA NUCA, LO PRIMERO: esta detras y dentro de una capa no hay z-buffer -- el orden
	# de la lista ES la profundidad, asi que lo de detras se pinta antes. Es lo UNICO que separa esta
	# pieza de un casco: un casco acaba en el craneo y una capucha sigue por el cuello.
	#
	# ARRANCA DENTRO DE LA CAZOLETA, no en el centro de la cabeza. Es el fallo que costo el segundo
	# intento: las dos masas tienen que compartir volumen para leerse como una sola tela, y hay dos
	# sitios donde compartirlo -- el centro del craneo, que derrama sobre la cara, y el hueco de la
	# cazoleta, que no. Y no puede sobresalir de ella: si el extremo interior asoma por arriba, deja
	# de ser una fusion y es un bulto (asi salio el moño).
	var dentro: Vector3 = cab + Vector3(0.0, -R * 0.30, R * 0.10)
	var nuca: Vector3 = cab + Vector3(0.0, -R * (0.30 + 0.34 * largo), -R * 0.34 * largo)
	PoseJugador.cadena(piezas, esq, dentro, nuca,
		R * 0.55, R * (0.26 + 0.16 * largo), Tono.TELA_S)

	# 2. LA TELA QUE BAJA POR LOS LADOS DE LA CARA, y va antes que la cazoleta para que esta le tape
	# el arranque. Son las carrilleras del casco con otro nombre.
	#
	# NO SON UN ADORNO -- la nota del casco lo explica y aqui pasa igual: la cazoleta tiene su fila
	# mas ancha por encima de la del craneo, asi que justo debajo de su borde asoman las dos mejillas
	# desnudas y el conjunto parece un sombrero apoyado en una cabeza mas gorda que el.
	#
	# Y VAN ESTRECHAS EN X (0,26 R) Y HONDAS EN Y (0,56 R). Ese reparto es lo que hace que quepan: a
	# 0,84 de ancho quedan fuera de la columna de los ojos (que llega a 0,49) y pueden colgar hasta el
	# pomulo sin estorbar. Mis faldones iban gordos en X y por eso salian como orejas.
	var p: float = CAP_MEJILLA
	for lado in [-1.0, 1.0]:
		PoseJugador.poner(piezas, esq, cab + Vector3(lado * R * 0.84, -0.8, -R * 0.14 * p),
			Vector3(R * 0.26, R * 0.56, R * (0.30 + 0.42 * p)), Tono.TELA_S)

	# 3. LA CAZOLETA con su volumen, igual que la chapa del casco: la masa en sombra, la misma masa en
	# tono base un poco mas arriba (lo que asoma por debajo es el filo de la abertura) y un parche de
	# luz pequeño y alto. En el casco eso lee "acero curvo"; con los grises mas claros del gorro y el
	# canto fino, lee "tela".
	PoseJugador.poner(piezas, esq, centro, r, Tono.TELA_S)
	PoseJugador.poner(piezas, esq, centro + Vector3(0.0, 0.0, CAP_CANTO), r, Tono.TELA,
		{"solo_sobre": [Tono.TELA_S]})
	PoseJugador.poner(piezas, esq, centro + Vector3(0.0, -r.y * 0.10, r.z * 0.46),
		Vector3(r.x * 0.58, r.y * 0.52, r.z * 0.28), Tono.TELA_L, {"solo_sobre": [Tono.TELA]})
