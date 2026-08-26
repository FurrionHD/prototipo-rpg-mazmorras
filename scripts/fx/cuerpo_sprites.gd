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
#  ESTA CAPA VA EN COLOR DE PIEL Y NO SE TIÑE. Es la unica del personaje que no lo hace, y por eso
#  lleva "tinte": false en JugadorSprites.CAPAS (que es lo que hace que MunecoJugador.tenir se la
#  salte).
#
#  Antes se horneaba en gris y se multiplicaba por el color que elegiste, con la piel y la ropa
#  distinguiendose SOLO por lo claras que eran. Sobre el papel era elegante -- un dibujo, todos los
#  colores --; en pantalla salia un muñeco monocromo, porque un cuerpo teñido de azul entero no se
#  lee como una persona vestida de azul, se lee como una estatua azul. La carne tiene un color y no
#  es negociable.
#
#  Y lo que se pierde no se pierde: el color del personaje sigue existiendo y sigue entrando por
#  'tenir' -- lo que pasa es que a partir de ahora tiñe LA ROPA, cuando existan las capas de
#  armadura. Que es lo que se queria decir desde el principio.
#
#  El dia que se quiera elegir el color de piel, es cambiar los cuatro colores de 'colores()' por
#  unos que vengan del personaje. No hay nada mas que tocar: para eso esta montado esto por capas.
# ============================================================

extends RefCounted
class_name CuerpoSprites

# Los tonos de ESTA capa, a partir del primer indice libre (los tres de abajo son fijos para todas,
# ver CapaJugador). El orden es el contrato con la paleta.
#
# EL ORDEN DE LOS VALORES SIGUE IMPORTANDO aunque ya no haya tinte: de PIEL_S a PIEL_L el brillo sube
# monotono, y ahi no puede colarse nada. El primer intento puso el realce del pecho MAS CLARO que la
# cara, y el resultado fue que el pecho se leia como lo mas iluminado del personaje y la cabeza
# desaparecia encima de el -- de lejos parecia un muñeco decapitado.
#
# El CALZADO se sale de esa escala aposta: es lo unico que no es carne, y va oscuro para que la
# silueta se APOYE en el suelo en vez de flotar.
enum Tono {
	VACIO = 0, SOMBRA_SUELO = 1, BORDE = 2,
	CALZADO,     # los pies. Lo unico que no es piel, y lo unico que se ve entero desde arriba
	SOMBRA,      # la LINEA INTERIOR: donde una pieza se apoya en otra (ver '_linea')
	PIEL_S,      # la carne en penumbra: la extremidad del fondo, el cuello, la cadera
	PIEL,        # la carne: tronco, pierna de delante
	PIEL_L,      # el realce del pecho y el brazo de delante
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
const R_CUELLO := 2.8
const R_CABEZA := PoseJugador.CABEZA_R
# EL PECHO ES MAS ESTRECHO QUE LOS HOMBROS (6.8 contra los 8.8 de PoseJugador.HOMBRO.x), y eso es
# deliberado, y por DOS unidades enteras y no por un pelo: con el hombro justo en el filo del pecho
# el brazo se quedaba medio enterrado dentro del tronco y lo que se veia era un bulto con manchas a
# los lados. Tiene que COLGAR por fuera, como en las referencias.
# Ver la nota de HOMBRO en pose_jugador.gd -- el brazo tiene que asomar por el costado SIEMPRE, y su
# largo visible no puede depender de cuanto se lo trague el pecho en esta pose.
#
# Y MAS ESTRECHO QUE LA CABEZA (13,6 de ancho contra 21). Es lo que hace que la proporcion se lea como
# cabezona en vez de como un saco: la cabeza manda y el cuerpo cuelga de ella. Un intento anterior
# puso el pecho practicamente del ancho de la cabeza y el resultado era un bulto uniforme del que
# salian cuatro cosas.
const R_TORSO := Vector3(6.8, 5.0, 6.2)      # el pecho: ancho, de fondo, de alto
# LA CADERA VA CLARAMENTE MAS ESTRECHA QUE EL PECHO, y hace falta decirlo porque un intento la puso
# casi igual y el resultado era un personaje SIN CINTURA: las dos elipses se solapaban en un unico
# bulto que iba del cuello a los muslos, y de lejos se leia como un saco. Que se estreche por en
# medio es lo que dice que eso es un torso y no un tonel.
const R_CADERA := Vector3(5.8, 4.2, 4.6)
#
# Y LOS MIEMBROS TIENEN UN GROSOR MINIMO QUE NO ES ANATOMICO, ES DE PIXELES. Una celda mide 1,15
# unidades de mundo, asi que un brazo de radio 1,15 se dibuja con DOS pixeles de ancho: no se lee
# como un brazo sino como un alambre, y en cuanto se estira al correr se ve un palo saliendo del
# hombro. Peor aun, la mano (que va mas clara) quedaba como un puntito suelto al lado del cuerpo,
# porque lo que deberia unirla se dibujaba con la anchura justa para desaparecer entre dos celdas.
#
# Y el minimo real es MAS ALTO de lo que parece por el contorno: un miembro de tres pixeles de ancho
# es TODO CONTORNO Y NADA DE RELLENO (ver 'colores'), asi que ademas de leerse fino se lee del color
# del borde. Ese es el motivo de fondo por el que el personaje crecio: a 37 unidades de alto no
# habia numero que arreglara esto. Con R_BRAZO = 3.6 el brazo mide seis celdas de ancho, o sea dos
# de contorno y CUATRO de carne. Menos que eso y la linea interior se come el relleno.
const R_MUSLO := 3.2
const R_PANTORRILLA := 2.6
const R_PIE := Vector3(2.0, 3.2, 1.5)
const R_BRAZO := 3.6
const R_ANTEBRAZO := 3.0
const R_MANO := 3.1

# Cuanta diferencia de profundidad tiene que haber entre los dos hombros para dar por hecho que UNO
# ESTA DELANTE DEL OTRO y pintarlos de tonos distintos. En unidades de mundo.
#
# Existe porque de frente y de espaldas los dos hombros estan a la MISMA distancia de la camara, y
# ahi cualquier regla que elija "el de delante" elige por el redondeo: sale un brazo claro y otro
# oscuro sin ningun motivo, que es justo lo que se veia mal. En las seis direcciones restantes la
# diferencia es de diez unidades o mas, asi que este numero solo tiene que separar el cero del resto
# -- no es un ajuste fino y no hay que buscarle el valor bueno.
const SEPARACION_BRAZOS := 2.0

# CUANTO CRECE UNA PIEZA PARA DIBUJAR SU LINEA INTERIOR, en unidades de mundo.
#
# La linea es el anillo que queda entre la pieza crecida y la pieza de verdad, asi que esto es
# literalmente su grosor. TIENE QUE PASAR DE UNA CELDA (1,15): con 0,9 el anillo mide menos de un
# pixel y la rejilla lo dibuja A TROZOS -- el brazo salia con un borde dentado, como una cremallera.
const LINEA := 1.2
# La mano crece MENOS que el resto del brazo. Es lo mas gordo de la cadena y cae justo a la altura
# de la cadera, que es la parte estrecha del cuerpo: con el crecimiento entero, su anillo se leia
# como un manchurron en cada cadera en vez de como el canto de una mano.
const LINEA_MANO := 0.8


# --- Contrato de capa (ver CapaJugador y el registro de JugadorSprites) ---
static func frames(esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.frames(CLAVE, pintar, colores(), esc)


static func generar(esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.generar(CLAVE, pintar, colores(), esc)


static func clave() -> String:
	return CLAVE


# El color de cada tono, EN EL ORDEN DEL ENUM. Estos son los colores DEFINITIVOS: esta capa no se
# tiñe (ver la cabecera), asi que lo que se hornea aqui es lo que se ve en pantalla.
static func colores() -> Array:
	# EL CONTORNO NO PUEDE SER NEGRO, y eso solo se ve en el juego. 'contornear' marca toda celda que
	# toque el vacio, asi que en una pieza GRUESA -- un slime -- el contorno es una linea alrededor de
	# mucho relleno, pero en un miembro fino son dos celdas de contorno y una de relleno: el brazo
	# entero se vuelve del color del contorno. Con el contorno en casi negro, el personaje salia como
	# un tronco con cuatro palos negros colgando.
	#
	# Va MARRON CALIDO y no gris por lo mismo que en cualquier dibujo de piel: un contorno neutro al
	# lado de la carne se lee sucio, como si el personaje estuviera manchado de hollin. Es el mismo
	# color de la piel llevado a oscuro, no un negro rebajado.
	# LA LINEA INTERIOR (SOMBRA) VA CERCA DEL CONTORNO, NO CERCA DE LA PIEL. En las referencias del
	# genero la raya que separa el brazo del pecho es claramente oscura: es una linea de dibujo, no un
	# sombreado. Puesta suave no separa nada y sobra; puesta en el tono del BORDE se lee como un
	# garabato negro cruzando el cuerpo (ya paso). Este es el primer numero a mover si sale dura.
	return [
		Color(0, 0, 0, 0),                # VACIO
		Color(0, 0, 0, 0.20),             # SOMBRA_SUELO
		Color(0.42, 0.24, 0.22),          # BORDE
		Color(0.45, 0.28, 0.22),          # CALZADO
		Color(0.62, 0.36, 0.32),          # SOMBRA
		Color(0.87, 0.62, 0.55),          # PIEL_S
		Color(0.96, 0.75, 0.67),          # PIEL
		Color(1.00, 0.85, 0.78),          # PIEL_L
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
	#
	# EL ORDEN ESTUVO INVERTIDO, y el sintoma no se parecia en nada a la causa: se veia un brazo
	# larguisimo cruzando el cuerpo por delante y el otro CORTADO POR EL CODO. Lo que pasaba es que el
	# brazo de delante se pintaba primero (o sea, debajo del tronco, y de el solo asomaba el antebrazo
	# por fuera de la silueta = el "cortado") y el del fondo se pintaba encima de todo, tapando el
	# pecho de lado a lado = el "larguisimo". Ninguno de los dos brazos estaba mal dibujado.
	#
	# 'izq_al_fondo' se llama asi y no 'brazo_fondo' por eso mismo: el nombre anterior no decia si era
	# un lado o una profundidad, y leyendolo se colaba la negacion sin que cantara.
	var izq_al_fondo: bool = brazo_izq_prof < brazo_der_prof
	# Y EL TONO DE CADA BRAZO SE DECIDE AQUI, con la misma pregunta, porque necesita saber de los DOS.
	# El del fondo va oscuro y el de delante claro, PERO SOLO CUANDO DE VERDAD HAY UNO DELANTE Y OTRO
	# DETRAS.
	#
	# Mirando al sur (o al norte) los dos hombros estan a la misma distancia de la camara -- los brazos
	# cuelgan uno a cada lado, ninguno tapa al otro --, y ahi pintar uno claro y otro oscuro seria el
	# fallo que ya se arreglo una vez: el personaje con un brazo distinto del otro sin ningun motivo.
	# Asi que los DOS van a PIEL_S, un escalon por debajo del tronco: simetricos y separados.
	#
	# (Lo que NO vale es dejarlos en PIEL, el tono del tronco. Se probo con el razonamiento "de frente
	# lo que los separa es que ASOMAN por fuera", y era falso: asoman tres pixeles, y de frente el
	# brazo desaparecia dentro del pecho.)
	var de_lado: bool = absf(brazo_izq_prof - brazo_der_prof) > SEPARACION_BRAZOS
	var tono_fondo: int = Tono.PIEL_S
	var tono_frente: int = Tono.PIEL_L if de_lado else Tono.PIEL_S

	# 1. EL BRAZO DEL FONDO, cuando de verdad hay uno al fondo. Va antes que todo porque lo tapa hasta
	#    el tronco, y por eso NO lleva linea interior: no se le ve el borde contra nada.
	if de_lado:
		_brazo(piezas, esq, izq_al_fondo, tono_fondo, false)

	# 2. Las piernas, la del fondo primero. La de DELANTE lleva linea, y contra la de atras: es lo
	#    unico que las separa cuando se cruzan al andar (van juntas, ver PoseJugador.PIE_X).
	var izq_pierna_al_fondo: bool = pierna_izq_prof < pierna_der_prof
	_pierna(piezas, esq, izq_pierna_al_fondo, Tono.PIEL_S, [])
	_pierna(piezas, esq, not izq_pierna_al_fondo, Tono.PIEL, [Tono.PIEL_S])

	# 3. El tronco. La cadera antes que el pecho: asi el pecho tapa la junta y no se ve el corte.
	PoseJugador.poner(piezas, esq, p[PoseJugador.P_CADERA], R_CADERA, Tono.PIEL_S)
	PoseJugador.poner(piezas, esq, p[PoseJugador.P_TORSO], R_TORSO, Tono.PIEL)
	# El realce del pecho va MAS ALTO que su eje (la luz viene de arriba), asi que en pantalla queda
	# desplazado hacia arriba y la mitad de abajo se queda en tono base = el costado en penumbra.
	# Solo sobre PIEL, para no pisar el contorno ni aclarar la cadera.
	var alto_pecho: Vector3 = p[PoseJugador.P_TORSO] + Vector3(0.0, 0.0, R_TORSO.z * 0.62)
	PoseJugador.poner(piezas, esq, alto_pecho,
		Vector3(R_TORSO.x * 0.68, R_TORSO.y * 0.85, R_TORSO.z * 0.55), Tono.PIEL_L,
		{"solo_sobre": [Tono.PIEL]})

	# 4. Cuello y cabeza.
	# El cuello va LARGO a proposito (ver PoseJugador.CUELLO): tiene que solapar de verdad con el
	# pecho por abajo y con la cabeza por arriba, no rozarlos.
	PoseJugador.poner(piezas, esq, p[PoseJugador.P_CUELLO],
		Vector3(R_CUELLO, R_CUELLO, 3.0), Tono.PIEL_S)
	PoseJugador.poner(piezas, esq, p[PoseJugador.P_CABEZA],
		Vector3(R_CABEZA, R_CABEZA * 0.90, R_CABEZA * 0.96), Tono.PIEL)
	# NO LLEVA REALCE EN LA CORONILLA, y esto se probo y se quito.
	#
	# Habia una elipse clara en lo alto de la cabeza, heredada de cuando el personaje se miraba casi
	# desde arriba y una cabeza plana se leia como un cuadrado. Con la proporcion cabezona la cabeza
	# es lo mas grande del dibujo, y ese realce la convertia en UNA BOLA BRILLANTE: se leia como una
	# pelota, no como una cabeza.
	#
	# Y ademas es lo que hacen las referencias del genero: en ellas la cabeza desnuda va PLANA, y el
	# volumen de arriba lo pone el PELO. O sea que esto no es una pieza que falte, es una pieza que le
	# toca a otra capa.

	# 5. LOS BRAZOS QUE VAN POR DELANTE DEL TRONCO, al final y CON LINEA.
	#
	# Tienen que ir despues del tronco por dos motivos que se refuerzan: porque lo tapan (es lo que
	# les toca) y porque la linea interior se dibuja con 'solo_sobre', que mira lo que YA hay pintado
	# -- un brazo dibujado antes que el pecho no tendria contra que hacer su linea.
	#
	# Y DE FRENTE Y DE ESPALDAS VAN LOS DOS AQUI, no uno. Es la diferencia que arregla la queja: con
	# uno solo al final, solo uno podia llevar linea, o sea otra vez un brazo distinto del otro.
	# Ninguno de los dos tapa al otro (cuelgan uno a cada lado), asi que dibujarlos los dos al final
	# no cambia nada salvo que ahora los dos pueden marcarse.
	var sobre_el_cuerpo := [Tono.PIEL_S, Tono.PIEL, Tono.PIEL_L]
	if de_lado:
		_brazo(piezas, esq, not izq_al_fondo, tono_frente, true, sobre_el_cuerpo)
	else:
		_brazo(piezas, esq, true, tono_frente, true, sobre_el_cuerpo)
		_brazo(piezas, esq, false, tono_frente, true, sobre_el_cuerpo)


# Una pierna: muslo, pantorrilla y pie. La cadena de elipses la hace PoseJugador, que ya sabe que el
# paso tiene que ser menor que el grosor -- si no, la pierna sale a trozos sueltos flotando.
#
# 'sobre' es contra que tonos se dibuja su LINEA INTERIOR (vacio = sin linea). La de delante la lleva
# contra la de atras, y no es un adorno: con las piernas juntas (ver PoseJugador.PIE_X) se solapan de
# verdad al andar, y sin la linea la zancada se lee como un solo bulto que se ensancha.
static func _pierna(piezas: Array, esq: Dictionary, izq: bool, tono: int, sobre: Array) -> void:
	var p: Dictionary = esq["puntos"]
	var rodilla: Vector3 = p[PoseJugador.P_RODILLA_IZQ if izq else PoseJugador.P_RODILLA_DER]
	var pie: Vector3 = p[PoseJugador.P_PIE_IZQ if izq else PoseJugador.P_PIE_DER]
	var cadera: Vector3 = p[PoseJugador.P_CADERA]
	# El muslo arranca del LATERAL de la cadera, no de su centro: naciendo en el centro las dos
	# piernas salian del mismo punto y de frente se veia un solo tronco que se bifurcaba muy abajo.
	var arranque := Vector3((1.0 if izq else -1.0) * PoseJugador.PIE_X * 0.82,
		cadera.y, cadera.z - 2.0)
	var tobillo: Vector3 = pie + Vector3(0.0, 0.0, R_PIE.z)
	if not sobre.is_empty():
		var o := {"solo_sobre": sobre}
		PoseJugador.cadena(piezas, esq, arranque, rodilla,
			R_MUSLO + LINEA, R_PANTORRILLA + LINEA, Tono.SOMBRA, o)
		PoseJugador.cadena(piezas, esq, rodilla, tobillo,
			R_PANTORRILLA + LINEA, R_PANTORRILLA * 0.85 + LINEA, Tono.SOMBRA, o)
	PoseJugador.cadena(piezas, esq, arranque, rodilla, R_MUSLO, R_PANTORRILLA, tono)
	PoseJugador.cadena(piezas, esq, rodilla, tobillo,
		R_PANTORRILLA, R_PANTORRILLA * 0.85, tono)
	# El pie es una pieza aparte y ALARGADA hacia donde se mira: sin el, la pierna acaba en un
	# muñon redondo y el personaje parece de puntillas.
	# Va OSCURO (y con tono propio, no con el del contorno como antes): unas botas oscuras son lo que
	# separa la pierna del suelo, y al quedar casi del color de la linea de contorno la silueta se
	# apoya en vez de flotar. Es tambien la unica pieza del cuerpo que se ve entera desde arriba.
	PoseJugador.poner(piezas, esq, pie, R_PIE, Tono.CALZADO)


# Un brazo: hombro, antebrazo y mano. LOS DOS BRAZOS SE DIBUJAN EXACTAMENTE IGUAL DE GORDOS. Lo que
# los distingue es el TONO y su LINEA INTERIOR, nunca el tamaño.
#
# EL TAMAÑO FUE LA QUEJA NUMERO UNO -- "un brazo mas gordo que el otro" -- y su causa era esta misma
# linea, mal hecha: se dibujaba una cadena mas gorda alrededor del brazo de delante SIN LIMITARLA AL
# CUERPO, asi que tambien se pintaba contra el aire y le engordaba la silueta. Como cual de los dos
# va delante cambia con la direccion, al girar el personaje parecia cambiar de brazo gordo.
#
# LA LINEA VUELVE, PERO CON 'solo_sobre'. Es un ANILLO: se dibuja la cadena crecida en Tono.SOMBRA
# limitada a los tonos del cuerpo, y encima el brazo de verdad. El anillo solo aparece DONDE HAY
# CUERPO DEBAJO, nunca contra el aire, asi que la silueta exterior de los dos brazos es identica
# hasta la ultima celda.
#
# Y TIENE QUE SER UN ANILLO, NO UNA SOMBRA A UN LADO. Segun la direccion el contacto cae en un sitio
# distinto: de frente el brazo toca el tronco por el costado, y de perfil cae ENCIMA del pecho y lo
# toca por los cuatro lados. Una sombra desplazada serviria de frente y no de perfil, que es la
# mitad del problema.
#
# LOS DOS INTENTOS QUE SE VIERON MAL, para que nadie los repita:
#   * Anillo en Tono.BORDE (casi negro) con el brazo del MISMO tono que el pecho: del brazo solo
#     quedaba la raya, y se leia como un garabato cruzando el cuerpo. Un contorno dice donde ACABA
#     algo, no que hay dentro -- hace falta que el brazo tenga ademas su escalon de valor.
#   * Anillo de 0,9: menos de una celda, asi que la rejilla lo dibujaba a trozos y el brazo salia
#     con el borde dentado, como una cremallera. Ver LINEA.
static func _brazo(piezas: Array, esq: Dictionary, izq: bool, tono: int,
		linea: bool = false, sobre: Array = []) -> void:
	var p: Dictionary = esq["puntos"]
	var hombro: Vector3 = p[PoseJugador.P_HOMBRO_IZQ if izq else PoseJugador.P_HOMBRO_DER]
	var codo: Vector3 = p[PoseJugador.P_CODO_IZQ if izq else PoseJugador.P_CODO_DER]
	var mano: Vector3 = p[PoseJugador.P_MANO_IZQ if izq else PoseJugador.P_MANO_DER]
	# EL BRAZO ARRANCA UN POCO POR DENTRO DEL PECHO, no en el punto del hombro exacto.
	#
	# El hombro cae justo en el BORDE de la elipse del torso, y ahi la elipse ya casi no tiene altura
	# -- se esta cerrando --, asi que el brazo se agarraba al cuerpo por medio pixel. En la mayoria de
	# las poses colaba; al correr, con el brazo estirado, se soltaba y quedaba un brazo entero
	# flotando al lado del personaje. Lo caza el validador de islas del horno, y el arreglo es el
	# mismo que ya tenian los muslos: meter el arranque dentro de la pieza que lo sujeta.
	#
	# PERO LO JUSTO. Iba a 0,72 del hombro y 1,6 por debajo, y eso metia el arranque tan adentro que
	# el pecho se tragaba media manga: el brazo del fondo asomaba un trozo distinto en cada
	# fotograma, que es la otra mitad de "el de atras o es muy corto o muy largo". Con los hombros ya
	# por fuera del pecho (ver PoseJugador.HOMBRO), 0,88 basta para agarrarse.
	var arranque := Vector3(hombro.x * 0.88, hombro.y, hombro.z - 2.0)
	if linea and not sobre.is_empty():
		var o := {"solo_sobre": sobre}
		PoseJugador.cadena(piezas, esq, arranque, codo,
			R_BRAZO + LINEA, R_ANTEBRAZO + LINEA, Tono.SOMBRA, o)
		PoseJugador.cadena(piezas, esq, codo, mano,
			R_ANTEBRAZO + LINEA, R_ANTEBRAZO * 0.92 + LINEA, Tono.SOMBRA, o)
		var m: float = R_MANO + LINEA_MANO
		PoseJugador.poner(piezas, esq, mano, Vector3(m, m, m), Tono.SOMBRA, o)
	# TODO EL BRAZO ES PIEL, incluida la mano. Antes el brazo iba en tono de tela y solo la mano en
	# carne (era una manga), y con la capa del cuerpo teñida tenia sentido; ahora el cuerpo va
	# desnudo y una manga aqui seria ropa que no llevas puesta. La ropa la traeran sus capas.
	PoseJugador.cadena(piezas, esq, arranque, codo, R_BRAZO, R_ANTEBRAZO, tono)
	PoseJugador.cadena(piezas, esq, codo, mano, R_ANTEBRAZO, R_ANTEBRAZO * 0.92, tono)
	PoseJugador.poner(piezas, esq, mano, Vector3(R_MANO, R_MANO, R_MANO), tono)
