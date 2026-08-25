# ============================================================
#  cuerpo_sprites.gd  (class_name CuerpoSprites)
#  LA CAPA DE ABAJO DEL TODO: el personaje desnudo. Piernas, tronco, brazos y cabeza.
#
#  Lo que dibuja es lo que se ve cuando NO llevas nada puesto, y ademas es lo que asoma por los
#  huecos de lo que si llevas: si tienes peto pero no guanteletes, los brazos que se ven son estos.
#  Por eso el cuerpo se dibuja ENTERO aunque casi siempre vaya tapado -- recortarlo "porque total,
#  el peto lo cubre" obliga a saber que peto llevas, y una capa no sabe que hay encima.
#
#  DONDE cae cada cosa NO SE DECIDE AQUI: lo dice PoseJugador. Este archivo solo sabe que la cadera
#  es un ovalo y que del hombro a la mano hay un brazo. Esa separacion es lo que hace que la
#  armadura no baile respecto al cuerpo, asi que no se le pone ni un seno propio.
#
#  SE HORNEA EN GRIS. El color entra en el juego, multiplicando (ver capa_jugador.gdshader). Y como
#  el tinte es UNO para toda la capa, la piel y la ropa comparten tono y se distinguen por el
#  VALOR -- la piel va clara, la ropa oscura. Es exactamente lo que ya hacia el ColorRect de antes
#  (un personaje de un color), pero ahora con silueta. Si algun dia se quiere piel de su propio
#  color, no hay que rehacer nada: es otra capa con su tinte, que es justo para lo que esta montado
#  todo esto.
# ============================================================

extends RefCounted
class_name CuerpoSprites

# Los tonos de ESTA capa, a partir del primer indice libre (los tres de abajo son fijos para todas,
# ver CapaJugador). El orden es el contrato con la paleta.
#
# EL ORDEN DE LOS VALORES IMPORTA MAS QUE LOS COLORES: la ropa va oscura y la piel clara, y entre
# medias no puede colarse nada. El primer intento puso el realce del pecho MAS CLARO que la cara, y
# el resultado fue que el pecho se leia como lo mas iluminado del personaje y la cabeza desaparecia
# encima de el -- de lejos parecia un muñeco decapitado. La escala de valores es la que dice donde
# esta cada cosa; los colores solo la tiñen.
enum Tono {
	VACIO = 0, SOMBRA_SUELO = 1, BORDE = 2,
	ROPA_S,      # la tela en penumbra: brazos, piernas y el costado
	ROPA,        # la tela: el tronco
	ROPA_L,      # el realce del pecho, donde da la luz. POR DEBAJO de la piel a proposito
	PIEL_S,      # la carne en penumbra: cuello y antebrazos
	PIEL,        # la carne: manos y cara
	LUZ,         # la coronilla, lo mas alto y lo unico que se ve desde arriba
}

const CLAVE := "cuerpo"

# --- Los gruesos, en unidades de mundo. Salen de PoseJugador.ALTO_MUNDO (37) ---
# El fondo (la Y) es bastante menor que el ancho a proposito: una persona es plana vista de lado, y
# es esa diferencia la que hace que el personaje se vea GIRAR en vez de rodar como un barril. Con el
# fondo parecido al ancho, todas las direcciones salen iguales por mucho que los brazos se muevan.
#
# PERO EL FONDO NO PUEDE SER EL DE UNA PERSONA DE VERDAD. Una persona mide de fondo poco mas de la
# mitad de lo que mide de ancho, y con esa proporcion exacta el personaje de perfil se quedaba en un
# palo de cuatro pixeles -- y encima el brazo, que en esa vista cae justo por delante del pecho, lo
# tapaba entero: lo que se veia era la manga oscura y ni rastro de tronco. El fondo va exagerado para
# que el pecho ASOME por detras del brazo. Es la misma trampa que se permitieron las orejas de la
# rata (redondas en los tres ejes para que no se vieran de canto) y por el mismo motivo: a este
# tamaño de pixel, lo fiel se lee peor que lo legible.
const R_CUELLO := 1.75
const R_CABEZA := PoseJugador.CABEZA_R
const R_TORSO := Vector3(5.1, 3.7, 4.7)      # el pecho: ancho, de fondo, de alto
const R_CADERA := Vector3(4.4, 3.1, 3.0)
#
# Y LOS MIEMBROS TIENEN UN GROSOR MINIMO QUE NO ES ANATOMICO, ES DE PIXELES. Una celda mide 1,15
# unidades de mundo, asi que un brazo de radio 1,15 se dibuja con DOS pixeles de ancho: no se lee
# como un brazo sino como un alambre, y en cuanto se estira al correr se ve un palo saliendo del
# hombro. Peor aun, la mano (que va mas clara) quedaba como un puntito suelto al lado del cuerpo,
# porque lo que deberia unirla se dibujaba con la anchura justa para desaparecer entre dos celdas.
# Por debajo de kilo y medio de radio no hay miembro que valga.
const R_MUSLO := 2.2
const R_PANTORRILLA := 1.75
const R_PIE := Vector3(1.7, 2.6, 1.15)
const R_BRAZO := 1.9
const R_ANTEBRAZO := 1.6
const R_MANO := 1.7


# --- Contrato de capa (ver CapaJugador y el registro de JugadorSprites) ---
static func frames(esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.frames(CLAVE, pintar, colores(), esc)


static func generar(esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.generar(CLAVE, pintar, colores(), esc)


static func clave() -> String:
	return CLAVE


# Los grises de cada tono, EN EL ORDEN DEL ENUM. La piel va mas clara que la ropa: es lo unico que
# las separa cuando el tinte es el mismo para las dos.
static func colores() -> Array:
	return [
		Color(0, 0, 0, 0),                # VACIO
		Color(0, 0, 0, 0.20),             # SOMBRA_SUELO
		Color(0.16, 0.16, 0.16),          # BORDE
		Color(0.34, 0.34, 0.34),          # ROPA_S
		Color(0.48, 0.48, 0.48),          # ROPA
		Color(0.60, 0.60, 0.60),          # ROPA_L
		Color(0.74, 0.74, 0.74),          # PIEL_S
		Color(0.87, 0.87, 0.87),          # PIEL
		Color(0.97, 0.97, 0.97),          # LUZ
	]


# ============================================================
#  EL PINTOR
# ============================================================
# Contrato: recibe el esqueleto de este fotograma y va metiendo piezas. El ORDEN DE LA LISTA ES LA
# PROFUNDIDAD -- no hay z-buffer, las ultimas tapan a las primeras --, asi que se pinta de lo mas
# lejano a lo mas cercano.
#
# Y CUAL ES EL MAS LEJANO CAMBIA CON LA DIRECCION, que es lo que hace falta entender aqui: mirando
# al este, el brazo izquierdo esta detras del cuerpo; mirando al oeste, delante. Eso no se resuelve
# con una tabla de ocho casos sino preguntando la PROFUNDIDAD de cada miembro
# (PoseJugador.profundidad) y ordenando. Sale gratis y no se puede quedar desfasado.
static func pintar(esq: Dictionary, piezas: Array) -> void:
	var p: Dictionary = esq["puntos"]
	CapaJugador.sombra_suelo(piezas, esq)

	# Que lado queda mas lejos de la camara. Menos profundidad = mas al fondo.
	var pierna_izq_prof: float = PoseJugador.profundidad(esq, PoseJugador.P_PIE_IZQ)
	var pierna_der_prof: float = PoseJugador.profundidad(esq, PoseJugador.P_PIE_DER)
	var brazo_izq_prof: float = PoseJugador.profundidad(esq, PoseJugador.P_HOMBRO_IZQ)
	var brazo_der_prof: float = PoseJugador.profundidad(esq, PoseJugador.P_HOMBRO_DER)

	# 1. El brazo del fondo, lo primero de todo: lo tapa hasta el tronco.
	var brazo_fondo: bool = brazo_izq_prof < brazo_der_prof
	_brazo(piezas, esq, not brazo_fondo)

	# 2. Las piernas, la del fondo primero.
	if pierna_izq_prof < pierna_der_prof:
		_pierna(piezas, esq, true)
		_pierna(piezas, esq, false)
	else:
		_pierna(piezas, esq, false)
		_pierna(piezas, esq, true)

	# 3. El tronco. La cadera antes que el pecho: asi el pecho tapa la junta y no se ve el corte.
	PoseJugador.poner(piezas, esq, p[PoseJugador.P_CADERA], R_CADERA, Tono.ROPA_S)
	PoseJugador.poner(piezas, esq, p[PoseJugador.P_TORSO], R_TORSO, Tono.ROPA)
	# El realce del pecho va MAS ALTO que su eje (la luz viene de arriba), asi que en pantalla queda
	# desplazado hacia arriba y la mitad de abajo se queda en tono base = el costado en penumbra.
	# Solo sobre ROPA, para no aclarar la piel ni pisar el contorno.
	var alto_pecho: Vector3 = p[PoseJugador.P_TORSO] + Vector3(0.0, 0.0, R_TORSO.z * 0.62)
	PoseJugador.poner(piezas, esq, alto_pecho,
		Vector3(R_TORSO.x * 0.68, R_TORSO.y * 0.85, R_TORSO.z * 0.55), Tono.ROPA_L,
		{"solo_sobre": [Tono.ROPA]})

	# 4. Cuello y cabeza.
	# El cuello va LARGO a proposito (ver PoseJugador.CUELLO): tiene que solapar de verdad con el
	# pecho por abajo y con la cabeza por arriba, no rozarlos.
	PoseJugador.poner(piezas, esq, p[PoseJugador.P_CUELLO],
		Vector3(R_CUELLO, R_CUELLO, 3.0), Tono.PIEL_S)
	PoseJugador.poner(piezas, esq, p[PoseJugador.P_CABEZA],
		Vector3(R_CABEZA, R_CABEZA * 0.90, R_CABEZA * 0.96), Tono.PIEL)
	# La coronilla iluminada. Es lo mas alto del personaje y lo que primero se ve en el mapa, asi que
	# sin este realce la cabeza se lee como una bola plana desde arriba.
	#
	# PEQUEÑA, y ahi esta la gracia: al primer intento se comia media cabeza, y como la luz y la piel
	# solo se llevan un escalon de valor, lo que quedaba arriba era una mancha uniforme -- una cabeza
	# sin forma, que de lejos se lee como un cuadrado. Un realce solo dice "esto es redondo" si deja
	# ver el tono de debajo alrededor.
	PoseJugador.poner(piezas, esq, p[PoseJugador.P_CABEZA] + Vector3(0.0, -0.4, R_CABEZA * 0.62),
		Vector3(R_CABEZA * 0.52, R_CABEZA * 0.44, R_CABEZA * 0.34), Tono.LUZ,
		{"solo_sobre": [Tono.PIEL]})

	# 5. Y el brazo de delante, al final: tapa al tronco, que es lo que le toca.
	_brazo(piezas, esq, brazo_fondo)


# Una pierna: muslo, pantorrilla y pie. La cadena de elipses la hace PoseJugador, que ya sabe que el
# paso tiene que ser menor que el grosor -- si no, la pierna sale a trozos sueltos flotando.
static func _pierna(piezas: Array, esq: Dictionary, izq: bool) -> void:
	var p: Dictionary = esq["puntos"]
	var rodilla: Vector3 = p[PoseJugador.P_RODILLA_IZQ if izq else PoseJugador.P_RODILLA_DER]
	var pie: Vector3 = p[PoseJugador.P_PIE_IZQ if izq else PoseJugador.P_PIE_DER]
	var cadera: Vector3 = p[PoseJugador.P_CADERA]
	# El muslo arranca del LATERAL de la cadera, no de su centro: naciendo en el centro las dos
	# piernas salian del mismo punto y de frente se veia un solo tronco que se bifurcaba muy abajo.
	var arranque := Vector3((1.0 if izq else -1.0) * PoseJugador.PIE_X * 0.82,
		cadera.y, cadera.z - 1.2)
	PoseJugador.cadena(piezas, esq, arranque, rodilla, R_MUSLO, R_PANTORRILLA, Tono.ROPA_S)
	PoseJugador.cadena(piezas, esq, rodilla, pie + Vector3(0.0, 0.0, R_PIE.z),
		R_PANTORRILLA, R_PANTORRILLA * 0.85, Tono.ROPA_S)
	# El pie es una pieza aparte y ALARGADA hacia donde se mira: sin el, la pierna acaba en un
	# muñon redondo y el personaje parece de puntillas.
	# El pie va en el tono del CONTORNO, o sea casi negro. No es un atajo: unas botas oscuras son lo
	# que separa la pierna del suelo, y al fundirse con la linea de contorno la silueta se apoya en
	# vez de flotar. Es tambien la unica pieza del cuerpo que se ve entera desde arriba.
	PoseJugador.poner(piezas, esq, pie, R_PIE, Tono.BORDE)


# Un brazo: manga, antebrazo y mano.
#
# LA MANGA VA MAS OSCURA QUE EL TRONCO (ROPA_S contra ROPA) Y NO IGUAL. Con el mismo tono, el brazo
# de delante desaparecia dentro del pecho -- estaba dibujado, se fusionaba con el, y el contorno solo
# perfila la silueta de fuera, asi que no habia nada que lo separase. Lo que se veia entonces era el
# antebrazo claro flotando al lado del cuerpo, como si el brazo empezara en el codo.
static func _brazo(piezas: Array, esq: Dictionary, izq: bool) -> void:
	var p: Dictionary = esq["puntos"]
	var hombro: Vector3 = p[PoseJugador.P_HOMBRO_IZQ if izq else PoseJugador.P_HOMBRO_DER]
	var codo: Vector3 = p[PoseJugador.P_CODO_IZQ if izq else PoseJugador.P_CODO_DER]
	var mano: Vector3 = p[PoseJugador.P_MANO_IZQ if izq else PoseJugador.P_MANO_DER]
	# LA MANGA ARRANCA POR DENTRO DEL PECHO, no en el punto del hombro.
	#
	# El hombro cae justo en el BORDE de la elipse del torso, y ahi la elipse ya casi no tiene altura
	# -- se esta cerrando --, asi que el brazo se agarraba al cuerpo por medio pixel. En la mayoria de
	# las poses colaba; al correr, con el brazo estirado, se soltaba y quedaba un brazo entero
	# flotando al lado del personaje. Lo caza el validador de islas del horno, y el arreglo es el
	# mismo que ya tenian los muslos: meter el arranque dentro de la pieza que lo sujeta.
	var arranque := Vector3(hombro.x * 0.72, hombro.y, hombro.z - 1.6)
	PoseJugador.cadena(piezas, esq, arranque, codo, R_BRAZO, R_ANTEBRAZO, Tono.ROPA_S)
	PoseJugador.cadena(piezas, esq, codo, mano, R_ANTEBRAZO, R_ANTEBRAZO * 0.9, Tono.PIEL_S)
	PoseJugador.poner(piezas, esq, mano, Vector3(R_MANO, R_MANO, R_MANO), Tono.PIEL)
