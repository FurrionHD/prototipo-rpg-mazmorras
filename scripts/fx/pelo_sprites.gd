# ============================================================
#  pelo_sprites.gd  (class_name PeloSprites)
#  EL PELO: la capa que le da silueta a la cabeza.
#
#  No es un adorno. En las referencias del estilo, el volumen de la cabeza es SOBRE TODO PELO -- la
#  cabeza desnuda va plana a proposito (ver la nota de la coronilla en cuerpo_sprites.gd, donde se
#  probo un realce y se leia como una pelota). Lo que aqui se dibuja es lo que hace que el personaje
#  se reconozca desde arriba en el mapa, que es de lo poco que se ve.
#
#  UN SOLO PINTOR PARA TODOS LOS MODELOS. El casquete, el flequillo y el brillo son iguales en los
#  seis peinados; lo que cambia es lo que CUELGA (una melena, una coleta, un moño) y cuanto baja por
#  los lados. Seis funciones separadas serian seis sitios donde arreglar el mismo casquete.
#
#  SE TIÑE, asi que se hornea en GRIS (ver CapaJugador.grises): el color del pelo lo elige el jugador
#  y vive en su aspecto, aparte del color de la ropa.
#
#  Y VA POR ENCIMA DE LA CARA (z 2049, ver JugadorSprites.CATALOGO), no ordenado por profundidad: la
#  cabeza esta en x = 0 y su profundidad es casi cero en las ocho direcciones, asi que quien
#  decidiria delante/detras seria el redondeo. Es el mismo motivo por el que la cara lleva z fijo.
# ============================================================

extends RefCounted
class_name PeloSprites

const PIEZA := "pelo"

# Los tonos, en el orden de CapaJugador.grises: contorno, sombra, base, luz.
enum Tono {
	VACIO = 0, SOMBRA_SUELO = 1, BORDE = 2,
	PELO_S,     # la parte que queda de fondo (la nuca de lado, el pelo bajo la melena)
	PELO,       # el tono base
	PELO_L,     # el brillo de arriba, por donde da la luz
}

const R := PoseJugador.CABEZA_R

# --- El casquete: la masa que cubre el craneo ---
# VA DESPLAZADO HACIA ATRAS Y HACIA ARRIBA, y ese desplazamiento es lo unico que le deja la cara
# libre. En la proyeccion, "hacia atras" (-Y) sube en pantalla mirando al sur y baja mirando al
# norte, o sea que con un solo par de numeros el pelo destapa la cara de frente y tapa la nuca de
# espaldas. Sin un caso por direccion.
#
# LA PRIMERA VERSION IBA A 2,2 Y 1,4 Y ERA UNA NUBE: el pelo tapaba la cabeza ENTERA y el personaje
# se leia como un champiñon. La cuenta de por que hace falta tanto: la elipse del pelo mide en
# pantalla ~9 celdas de alto, asi que para que su borde de abajo caiga por encima del centro de la
# cara hay que subirla nueve, y en esta camara subir una celda cuesta 1,4 unidades repartidas entre
# atras y arriba (las dos entran por el coseno de 45).
# EL REPARTO ENTRE LOS DOS NO ES LIBRE, y esto se vio de perfil: 'arriba' sube el pelo en las ocho
# direcciones por igual, pero 'atras' lo desplaza HACIA LA NUCA, y de perfil eso se ve como que el
# pelo y la cara son dos cosas distintas separandose. Asi que el trabajo de destapar la cara lo hace
# sobre todo ARRIBA, y ATRAS se queda en lo justo para que la coronilla no salga plana.
const ATRAS := 1.6
const ARRIBA := 5.6
# Cuanto mas gordo que la cabeza. Tiene que pasar de una celda (1,15) o el pelo aparece a trozos
# entre los pixeles de la cabeza, como una caspa.
const GROSOR := 1.6
# LO PLANO QUE ES EL CASQUETE, en fraccion del radio de la cabeza. Es lo que lo convierte de bola en
# gorro: con el alto entero, el pelo vuelve a bajar hasta la barbilla por mucho que se suba.
const CASQUETE_ALTO := 0.60

# --- El flequillo ---
# CUANTO BAJA POR LA FRENTE, en fraccion del radio de la cabeza.
#
# VA CORTO A PROPOSITO, y el motivo es que EL PELO SE DIBUJA POR DEBAJO DE TU FOTO (z 2047, ver
# JugadorSprites.CATALOGO): la cara es un circulo del 80% de la cabeza, asi que lo que quede por
# dentro de ese circulo no se va a ver cuando el personaje lleve imagen. El flequillo es para los
# que NO llevan foto y para el borde: pasarse de aqui no tapa los ojos -- simplemente se pinta
# debajo y no se ve.
const FLEQUILLO_BAJA := 0.22


# --- Contrato de capa (ver CapaJugador y el registro de JugadorSprites) ---
static func frames(modelo: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.frames(clave(modelo), pintar.bind(modelo), colores(), esc)


static func generar(modelo: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.generar(clave(modelo), pintar.bind(modelo), colores(), esc)


static func clave(modelo: String) -> String:
	return "%s_%s" % [PIEZA, modelo]


static func colores() -> Array:
	# Los grises de siempre. El sombra va un pelo mas bajo que el estandar: el pelo es lo mas oscuro
	# del personaje y con el escalon corto la melena se leia plana.
	return CapaJugador.grises(0.20, 0.38, 0.62, 0.82, 0.94)


# ============================================================
#  EL PINTOR
# ============================================================
static func pintar(esq: Dictionary, piezas: Array, modelo: String) -> void:
	var p: Dictionary = esq["puntos"]
	var cab: Vector3 = p[PoseJugador.P_CABEZA]
	var hombro: Vector3 = p[PoseJugador.P_HOMBRO_IZQ]
	# EL BAMBOLEO SALE DE LA POSE, no de un reloj propio. 'paso' es el balanceo de las piernas en
	# radianes, asi que una coleta que lo siga se mueve al ritmo al que anda el personaje y se para
	# cuando el se para -- sin sincronizar nada y sin un caso por animacion.
	var vaiven: float = float((esq["pose"] as Dictionary).get("paso", 0.0))

	match modelo:
		"rapado":
			_casquete(piezas, esq, cab, 0.55, 0.0)
		"corto":
			_casquete(piezas, esq, cab, 1.0, 0.55)
			_flequillo(piezas, esq, cab, 1.0)
		"bob":
			_casquete(piezas, esq, cab, 1.0, 0.55)
			_flequillo(piezas, esq, cab, 1.15)
			_melena(piezas, esq, cab, R * 1.05, 0.9)
		"coleta":
			_casquete(piezas, esq, cab, 1.0, 0.45)
			_flequillo(piezas, esq, cab, 1.0)
			_cola(piezas, esq, cab, vaiven)
		"largo":
			_casquete(piezas, esq, cab, 1.0, 0.55)
			_flequillo(piezas, esq, cab, 1.1)
			_melena(piezas, esq, cab, cab.z - hombro.z + R * 0.55, 1.15)
		"mono":
			_casquete(piezas, esq, cab, 1.0, 0.30)
			_flequillo(piezas, esq, cab, 0.85)
			_mono(piezas, esq, cab)
		_:
			_casquete(piezas, esq, cab, 1.0, 0.55)
	_brillo(piezas, esq, cab)


# LA MASA DE ARRIBA. 'grueso' es cuanto sobresale de la cabeza (1 = GROSOR entero, 0.55 = pegado al
# craneo, que es lo que distingue un rapado de un corto) y 'patillas' cuanto baja por los lados.
static func _casquete(piezas: Array, esq: Dictionary, cab: Vector3, grueso: float,
		patillas: float) -> void:
	var g: float = GROSOR * grueso
	# LA NUCA VA LA PRIMERA, y esto costo una hoja de contacto entera: pintada DESPUES, su tono de
	# sombra se dibujaba ENCIMA del casquete y lo que se veia era un manchon oscuro cruzando la
	# cabeza de lado a lado. No hay z-buffer dentro de una capa -- el orden de la lista es la
	# profundidad --, asi que lo que va detras se pinta antes. Siempre.
	#
	# Va sin subir, porque por detras el pelo SI tiene que bajar hasta el cuello; si bajara tambien
	# por delante volveriamos al champiñon de la primera version.
	# LA NUCA ESCALA CON 'grueso', y esto es lo que separa el rapado del corto: sin ello los dos
	# llevaban exactamente la misma masa por detras y en la hoja de contacto se leian igual. Un
	# rapado es pelo PEGADO al craneo por todos lados, no solo por arriba.
	PoseJugador.poner(piezas, esq, cab + Vector3(0.0, -R * 0.28 * grueso, R * 0.10),
		Vector3(R * (0.62 + 0.18 * grueso), R * (0.44 + 0.14 * grueso),
			R * (0.48 + 0.14 * grueso)), Tono.PELO_S)
	PoseJugador.poner(piezas, esq, cab + Vector3(0.0, -ATRAS, ARRIBA),
		Vector3(R + g, R * 0.90 + g, R * CASQUETE_ALTO + g * 0.5), Tono.PELO)
	if patillas <= 0.0:
		return
	# Las patillas bajan por delante de las orejas: son lo que enmarca la cara por los lados, y sin
	# ellas el pelo se lee como un gorro apoyado encima. Del tono base (no de sombra: en sombra eran
	# dos manchas oscuras a los lados de la cabeza, que es lo que se veia en la primera hoja).
	for lado in 2:
		var s: float = 1.0 if lado == 0 else -1.0
		PoseJugador.poner(piezas, esq,
			cab + Vector3(s * R * 0.84, -0.8, -R * 0.16 * patillas),
			Vector3(R * 0.24, R * 0.56, R * (0.34 + 0.40 * patillas)), Tono.PELO)


# EL FLEQUILLO: la unica pieza que se pone POR DELANTE de la cara, y por eso es la que hay que
# vigilar. 'largo' multiplica cuanto baja (ver FLEQUILLO_BAJA).
#
# Va ACHATADO Y ANCHO: una pieza redonda en la frente no se lee como pelo sino como un gorro, y a
# este tamaño la diferencia entre las dos cosas son dos celdas de alto.
static func _flequillo(piezas: Array, esq: Dictionary, cab: Vector3, largo: float) -> void:
	var baja: float = R * FLEQUILLO_BAJA * largo
	PoseJugador.poner(piezas, esq,
		cab + Vector3(0.0, R * 0.30, R * 0.80 - baja),
		Vector3(R * 0.88, R * 0.44, R * 0.26 + baja * 0.5), Tono.PELO)


# LO QUE CUELGA POR DETRAS Y POR LOS LADOS. 'baja' es cuanto desciende desde el centro de la cabeza
# y 'ancho' cuanto se separa del craneo.
#
# La melena va en DOS cadenas laterales mas una masa central por detras, y no en una sola pieza
# ancha: una pieza ancha vista de perfil es un ladrillo pegado a la nuca, y vista de frente tapa los
# hombros enteros. Lo que se lee como melena es que ENMARQUE la cara.
static func _melena(piezas: Array, esq: Dictionary, cab: Vector3, baja: float,
		ancho: float) -> void:
	var abajo: Vector3 = cab + Vector3(0.0, -ATRAS * 1.2, -baja)
	PoseJugador.cadena(piezas, esq, cab + Vector3(0.0, -ATRAS, ARRIBA * 0.5), abajo,
		R * 0.92 * ancho, R * 0.80 * ancho, Tono.PELO_S)
	for lado in 2:
		var s: float = 1.0 if lado == 0 else -1.0
		var alto: Vector3 = cab + Vector3(s * R * 0.86, -0.8, R * 0.25)
		var bajo: Vector3 = cab + Vector3(s * R * 0.78, -0.4, -baja * 0.92)
		PoseJugador.cadena(piezas, esq, alto, bajo, R * 0.34, R * 0.30, Tono.PELO)


# LA COLETA: sale de la nuca, sube un poco y cae. 'vaiven' viene del balanceo de la pose, asi que se
# mece al andar y se queda quieta al pararse.
#
# SON DOS PIEZAS DECLARADAS (ver JugadorSprites.CATALOGO) porque el atado es fino y en algunas poses
# la cola se separa del casquete por una celda. Declararlo es lo que evita que el validador de islas
# del horno suelte un aviso por fotograma hasta que nadie lo lea.
static func _cola(piezas: Array, esq: Dictionary, cab: Vector3, vaiven: float) -> void:
	var nudo: Vector3 = cab + Vector3(0.0, -R * 0.86, R * 0.30)
	var medio: Vector3 = nudo + Vector3(vaiven * R * 0.55, -R * 0.55, -R * 0.20)
	var punta: Vector3 = nudo + Vector3(vaiven * R * 0.95, -R * 0.75, -R * 1.30)
	PoseJugador.poner(piezas, esq, nudo, Vector3(R * 0.34, R * 0.34, R * 0.34), Tono.PELO)
	PoseJugador.cadena(piezas, esq, nudo, medio, R * 0.30, R * 0.34, Tono.PELO_S)
	PoseJugador.cadena(piezas, esq, medio, punta, R * 0.34, R * 0.16, Tono.PELO_S)


# EL MOÑO: un bulto alto y hacia atras. Es el peinado que mas cambia la SILUETA vista desde arriba,
# que es como se ve al personaje andando por el mapa.
static func _mono(piezas: Array, esq: Dictionary, cab: Vector3) -> void:
	PoseJugador.poner(piezas, esq, cab + Vector3(0.0, -R * 0.55, R * 0.92),
		Vector3(R * 0.48, R * 0.46, R * 0.44), Tono.PELO)
	PoseJugador.poner(piezas, esq, cab + Vector3(0.0, -R * 0.62, R * 0.98),
		Vector3(R * 0.30, R * 0.28, R * 0.26), Tono.PELO_L)


# EL BRILLO. Va SIEMPRE, en todos los modelos: es lo que dice que eso es pelo y no un casco. Una
# franja ancha y achatada por donde da la luz (arriba y un pelo hacia delante), y solo sobre el pelo
# ya pintado, para no dibujar nada suelto en el aire.
static func _brillo(piezas: Array, esq: Dictionary, cab: Vector3) -> void:
	PoseJugador.poner(piezas, esq, cab + Vector3(0.0, -ATRAS * 0.6, ARRIBA + R * 0.18),
		Vector3(R * 0.62, R * 0.50, R * 0.18), Tono.PELO_L,
		{"solo_sobre": [Tono.PELO, Tono.PELO_S]})
