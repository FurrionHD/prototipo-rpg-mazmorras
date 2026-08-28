# ============================================================
#  pose_jugador.gd  (class_name PoseJugador)
#  EL ESQUELETO DEL PERSONAJE: la UNICA definicion de como se mueve. No dibuja nada.
#
#  POR QUE EXISTE, Y POR QUE ES LO PRIMERO QUE SE ESCRIBIO. El personaje no es un dibujo, son
#  MUCHOS apilados: el cuerpo, cinco piezas de armadura, el arma de cada mano y tu icono en la
#  cabeza. Hornear cada combinacion es imposible (4 categorias x 5 ranuras x 10 armas x 3 escudos
#  x 8 direcciones x 8 animaciones son millones de imagenes), asi que se hornea cada CAPA por
#  separado y se apilan en el juego.
#
#  Y eso solo funciona si todas las capas se mueven EXACTAMENTE igual. No "parecido": igual al
#  pixel. Si el peto calculara su propio balanceo y el cuerpo el suyo, en el tercer fotograma la
#  coraza iria medio pixel por delante del torso y el personaje se veria descosido -- un fallo que
#  no da error, que solo se ve en movimiento y que es dificilisimo de localizar mirando codigo.
#
#  De ahi la regla: aqui viven los PUNTOS (donde cae la cadera, el hombro, la mano en este
#  fotograma) y cada capa se limita a colgar sus elipses de ellos. La coraza no baila respecto al
#  torso porque no es que se hayan dibujado a juego: es que comparten el punto.
#
#  Y de ahi tambien lo demas que vive aqui aunque parezca de otro sitio: el LIENZO, la lista de
#  ANIMACIONES y la PROYECCION. Son las tres cosas que todas las capas tienen que hacer igual, asi
#  que tenerlas en un solo sitio no es orden, es lo que hace que apilar funcione. Una capa con otro
#  lienzo o con un fotograma de mas ya no encaja, y no habria como notarlo hasta verlo torcido.
#
#  EL SISTEMA DE COORDENADAS, que es lo que hay que tener en la cabeza para leer los numeros:
#     * origen  = el suelo, entre los dos pies.
#     * +X      = a la DERECHA DE LA PANTALLA cuando el personaje mira al sur (o sea, hacia ti).
#                 Ojo con esto: si te mira de frente, SU mano derecha te queda a la IZQUIERDA, y
#                 por eso MANO_DER tiene la x negativa. Los nombres son del personaje, no tuyos.
#     * +Y      = hacia donde mira (la profundidad).
#     * +Z      = arriba.
#  Todo en unidades de MUNDO, las mismas que usan los bichos (ver SpriteLienzo.UNIDADES_POR_CELDA).
#  Nada de pixeles hasta el ultimo paso, que es 'proyectar'.
#
#  LO QUE NO ESTA AQUI: como se dibuja cada cosa. Este archivo no sabe que es un peto ni que es una
#  espada; sabe donde esta la mano. Los tonos, las elipses y las paletas son de cada capa.
# ============================================================

extends RefCounted
class_name PoseJugador


# ============================================================
#  EL TAMAÑO
# ============================================================
# De la planta a la coronilla, en unidades de mundo. Referencias para no perder el sitio: la rata
# mide 24 de largo, el jabali 28 y el slime 34 de diametro.
#
# EMPEZO EN 37, SE DOBLO A 74, Y BAJO A 60. Los dos movimientos tienen su motivo y conviene tener
# los dos, porque el segundo parece deshacer el primero y no lo hace:
#
#   1. A 37, EL PERSONAJE NO ERA MAS GRANDE QUE UNA RATA. Una rata de 24 unidades de largo, tumbada
#      y vista a 45 grados, ocupa en pantalla casi lo mismo que una persona de 37 de pie. El bicho
#      dejaba de leerse como un bicho: parecia otro humanoide. El tamaño relativo es informacion de
#      juego -- dice si lo que se te acerca es una alimaña o un rival --, y estaba mintiendo.
#
#   2. A 37, NO CABIA EL DIBUJO. 37 unidades son 32 celdas de alto, y de ahi un brazo salia de tres
#      o cuatro pixeles de ancho: todo contorno y nada de relleno (ver cuerpo_sprites.gd). No es que
#      los brazos estuvieran mal dibujados, es que a esa resolucion no hay brazo que dibujar.
#
#   3. Y A 74 SOBRABA TRONCO. Lo que hacia falta no era un personaje grande sino una CABEZA grande:
#      es lo que se ve desde arriba en el mapa, donde va tu imagen y donde ira el casco. Al pasar a
#      proporcion cabezona (ver CABEZA_R) la cabeza se lleva el 40% del alto, asi que se puede bajar
#      el total a 60 y AUN ASI la cabeza sale mas grande que a 74:
#
#         alto total        37      74      60
#         diametro cabeza    8      18      24
#         veces una rata   1,5x    3,1x    2,5x
#
#      O sea que bajar de 74 a 60 no deshace nada de 1 ni de 2: la cara se ve mejor que nunca y el
#      personaje le sigue sacando dos cabezas y media a una rata. Lo unico que se pierde es alto de
#      tronco, que es justo lo que sobraba.
#
# EL PIXEL NO CRECE, CRECE LA REJILLA. Es la regla de todo el proyecto (ver
# SpriteLienzo.UNIDADES_POR_CELDA y la cabecera de rata_sprites.gd): un personaje mas grande se
# dibuja con MAS CELDAS, nunca con celdas mas gordas. Por eso 'escala_sprite' no se toca al mover
# esto: lo unico que cambia es el lado del lienzo (60 -> 84 celdas).
const ALTO_MUNDO := 60.0

# El lienzo es CUADRADO y del mismo lado para TODAS las capas. Cuadrado porque al girar manda la
# diagonal, y del mismo lado porque si no, no se pueden apilar.
#
# Sale de MEDIR, no de calcular: tiene que caber el personaje entero con el arma mas larga
# (el mandoble en alto), girado en diagonal, desplazado por el paso adelante del golpe y volcado en
# la caida de la muerte. El validador de recortes de hornear_sprites.gd es el que dice si se queda
# corto, y avisa por capa.
const LIENZO_FACTOR := 1.60


# ============================================================
#  LAS MEDIDAS DEL CUERPO, EN REPOSO Y MIRANDO AL SUR
# ============================================================
# Estos son los puntos que publica 'esqueleto', y por tanto el contrato con las capas: una hombrera
# se cuelga de HOMBRO y una bota de PIE. Cambiar un numero de aqui mueve el cuerpo Y todo lo que
# lleve puesto a la vez, que es justo lo que se quiere.
#
# EL REPARTO ES CABEZON, no anatomico, y esta MEDIDO de las referencias (ver dev_medir_ref.gd):
#
#     cabeza 43%   ·   tronco 22%   ·   piernas 35%
#
# LAS PIERNAS SON LA MITAD DEL CUERPO, y eso es lo que se hacia mal: estaban en el 25% con un tronco
# del 33%, o sea justo al reves, y el personaje salia rechoncho -- una cabeza enorme sobre un barril
# con dos muñones. En este estilo el tronco es CORTO y las piernas LARGAS. Es la proporcion de las referencias del
# genero, y no es un capricho de estilo -- a este tamaño de pixel la cabeza es lo unico que
# identifica al personaje desde arriba, asi que darle sitio a ella y quitarselo al tronco es repartir
# los pixeles donde se miran.

const PIE_X := 3.0                                  # separacion de cada pie respecto al eje
const PIE := Vector3(PIE_X, 1.2, 2.4)
const RODILLA := Vector3(PIE_X, 0.0, 12.0)
const CADERA := Vector3(0.0, 0.0, 24.0)             # el pivote de todo el tronco
const TORSO := Vector3(0.0, 0.0, 28.5)
# LOS HOMBROS VAN JUSTO POR FUERA DEL ANCHO DEL PECHO, y esto ESTUVO AL REVES.
#
# La version anterior los metia DENTRO (4.9 de hombro contra 5.1 de medio pecho) para que los brazos
# no salieran como dos apendices pegados de canto. Lo que conseguia de verdad era que el brazo del
# fondo quedara ENTERRADO en la elipse del tronco: en reposo no se veia, y al andar iba asomando un
# trozo distinto en cada fotograma. El sintoma no se parecia a la causa -- se leia como "el brazo de
# atras cambia de largo", cuando lo que cambiaba era cuanto se lo tragaba el pecho.
#
# Con el hombro un pelin por fuera del pecho (9.8 contra 8.8 de CuerpoSprites.R_TORSO.x), el brazo
# asoma SIEMPRE por el costado y su longitud visible deja de depender de la pose. Lo que hacia falta
# para poder permitirselo era el tamaño: a 37 unidades ese margen medio era medio pixel y no separaba
# nada.
const HOMBRO := Vector3(9.8, 0.0, 32.5)
const CODO := Vector3(10.2, 0.8, 26.5)
# La mano en reposo cae por delante del cuerpo, no pegada al muslo: es de donde cuelga el arma, y
# pegada al costado el arma se metia DENTRO de la pierna en cuanto el personaje se giraba de lado.
#
# PERO EL BRAZO TIENE QUE ROZAR EL CUERPO. Una persona lleva los brazos con un dedo de aire entre el
# codo y el costado, y eso, dibujado, es UN PIXEL de fondo entre el brazo y el tronco -- o sea un
# brazo suelto flotando al lado del personaje. No hay termino medio a esta escala: o toca o esta
# despegado. Asi que la mano va mas metida de lo que estaria en una persona de verdad.
#
# Y "casi toca" ES ESTAR DESPEGADO, con un sintoma que no se parece a la causa: la mano cae a la
# altura de la CADERA, que es la parte estrecha del tronco, asi que quedaba un hueco de menos de un
# pixel entre las dos. Lo que se veia no era un hueco sino UNA MOTA OSCURA en cada cadera -- porque
# 'contornear' rodea de borde todo agujero, y un agujero de un pixel es un punto negro. Parecian dos
# lunares simetricos y eran dos manos sin agarrar.
const MANO := Vector3(8.6, 2.6, 21.5)
# EL CUELLO ES CASI TODO INTERIOR: solo asoman dos unidades entre el pecho y la barbilla.
#
# ASOMABA SEIS Y ERA UN CUELLO DE JIRAFA. Los hombros estaban en 33 y la barbilla en 39,4, o sea que
# entre los dos quedaba una columna de 5,6 de ancho por 6,4 de alto: sobre un cuerpo de 60, eso es la
# mitad del tronco. En este estilo la cabeza se apoya CASI ENCIMA de los hombros -- basta con que se
# vea la juntura para que no parezca clavada.
#
# Ojo con pasarse al otro lado: puesto donde estaria en una persona, el cuello se quedaba a seis
# centesimas del pecho -- solidos en el papel, un pixel de aire en la pantalla --, y al correr, con
# el tronco inclinado, ese pixel se abria y la cabeza se iba flotando. Sale en el validador de islas
# del horno como un trozo suelto, que es la cabeza entera. Tiene que SOLAPAR, no rozar.
const CUELLO := Vector3(0.0, 0.0, 34.0)
const CABEZA := Vector3(0.0, 0.5, 47.2)
# LA CABEZA SE LLEVA EL 43% DEL ALTO. Una persona de verdad es un septimo; esto son DOS CABEZAS Y
# MEDIA de cuerpo, o sea proporcion de muñeco. Es deliberado y por tres motivos que apuntan al mismo
# sitio:
#   * es lo que IDENTIFICA al personaje en el mapa, donde de un vistazo solo se ve la coronilla;
#   * es donde va TU IMAGEN (ver MunecoJugador.poner_cara), y en un circulo pequeño no se ve nada;
#   * es donde ira el pelo y el casco, que es de donde sacan su silueta los personajes de este
#     estilo -- en las referencias, el volumen de la cabeza es sobre todo PELO.
#
# EL 43% NO ES A OJO: ESTA MEDIDO. Se pasaron cuatro hojas de referencia del estilo que se busca
# (cuerpos base desnudos, sin pelo ni ropa) y se midieron una a una:
#
#     vista        alto    ancho   cabeza
#     3/4          60 px   25 px    42%
#     de frente    63 px   31 px    43%
#     de perfil    54 px   24 px    43%
#     de frente    51 px   28 px    47%
#
# Antes esto estaba en el 35%, con el razonamiento de que las referencias llegan al 40% "porque
# incluyen el PELO" y aqui el pelo no existe todavia. Era falso, y medirlo lo dejo claro: esas
# referencias son cuerpos DESNUDOS y aun asi van al 43%. El pelo suma volumen por encima, no
# sustituye a la cabeza.
#
# Moraleja para la proxima: una referencia se MIDE (ver dev_medir_ref.gd), no se estima mirandola.
#
# Y es lo que permite que el cuerpo entero sea mas pequeño sin perder nada (ver ALTO_MUNDO): la
# cabeza a 12 de radio sobre 60 es MAS grande en pixeles que la de 9.2 sobre 74.
const CABEZA_R := 12.8                              # 47.2 + 12.8 = 60.0, o sea ALTO_MUNDO

# Nombres de los puntos que publica 'esqueleto'. Van como StringName y no como texto suelto para
# que una errata sea un fallo al momento y no un punto en el (0,0,0) -- que es lo que se ve cuando
# una hombrera aparece flotando a los pies del personaje.
const P_PIE_IZQ := &"pie_izq"
const P_PIE_DER := &"pie_der"
const P_RODILLA_IZQ := &"rodilla_izq"
const P_RODILLA_DER := &"rodilla_der"
const P_CADERA := &"cadera"
const P_TORSO := &"torso"
const P_HOMBRO_IZQ := &"hombro_izq"
const P_HOMBRO_DER := &"hombro_der"
const P_CODO_IZQ := &"codo_izq"
const P_CODO_DER := &"codo_der"
const P_MANO_IZQ := &"mano_izq"
const P_MANO_DER := &"mano_der"
const P_CUELLO := &"cuello"
const P_CABEZA := &"cabeza"
# LA NUCA: la cabeza, pero por DETRAS. No es una parte del cuerpo que dibuje nadie -- es un punto de
# ANCLAJE, y existe por una razon muy concreta.
#
# Una capa se ordena delante o detras del cuerpo por la profundidad de su ancla (ver
# MunecoJugador._ordenar), y la cabeza esta en x=0, y=0.5: su profundidad es casi cero en las ocho
# direcciones, asi que quien cuelgue de ella se ordena por el redondeo. Eso vale para lo que va
# PEGADO al craneo (el casquete del pelo, y manda su z a mano), pero no para lo que CUELGA: una
# melena tiene que irse por la espalda cuando miras de frente y verse encima cuando miras de espaldas.
# Colgandola de aqui, esa regla sale sola y sin un caso por direccion.
#
# La querran tambien la capucha y el casco con cola, y por eso vive en el esqueleto y no calculada a
# ojo dentro de una capa: el esqueleto es el contrato.
const P_NUCA := &"nuca"

# LOS PUNTOS DEL ARMA. Solo anclaje, como la nuca: aqui no se dibuja ninguna espada -- eso es la
# capa ArmaSprites. Lo que vive aqui es DONDE se agarra el arma y HACIA DONDE apunta en este
# fotograma, para que la capa cuelgue su hoja de ahi sin recalcular la pose.
#
#   EMPUNADURA / PUNTA  el arma EMPUÑADA: la empuñadura cae dentro del puño y la "punta" es un
#                       punto de referencia en la direccion del antebrazo (la hoja apunta por ahi).
#   CADERA_DER/IZQ      el arma ENVAINADA al costado (las de una mano). La derecha del personaje
#                       es -X, ojo con el signo.
#   ESPALDA / ESPALDA_PUNTA   el arma colgada a la ESPALDA (las de dos manos): un punto detras del
#                       torso y su extremo lejano, para la direccion.
const P_EMPUNADURA_DER := &"empunadura_der"
const P_EMPUNADURA_IZQ := &"empunadura_izq"
const P_PUNTA_DER := &"punta_der"
const P_PUNTA_IZQ := &"punta_izq"
const P_CADERA_DER := &"cadera_der"
const P_CADERA_IZQ := &"cadera_izq"
const P_ESPALDA := &"espalda"
const P_ESPALDA_PUNTA := &"espalda_punta"


# ============================================================
#  LAS OCHO DIRECCIONES
# ============================================================
# Mismo orden y mismos vectores que los bichos: 0=S 1=SE 2=E 3=NE 4=N 5=NW 6=W 7=SW. No es una
# copia por comodidad -- el jugador y el enemigo se cruzan en el mapa y tienen que mirarse a la
# cara, asi que la convencion es del JUEGO. Quien traduzca un Vector2 a un indice debe usar
# SpriteLienzo.dir8, que es la unica funcion que lo hace.
const DIR_VECS := [
	Vector2(0, 1), Vector2(0.7, 0.7), Vector2(1, 0), Vector2(0.7, -0.7),
	Vector2(0, -1), Vector2(-0.7, -0.7), Vector2(-1, 0), Vector2(-0.7, 0.7),
]


# ============================================================
#  LA TABLA DE ANIMACIONES
# ============================================================
# La lista es UNA para todas las capas. Que el peto tenga las mismas animaciones que el cuerpo no
# se comprueba: es que las dos las sacan de aqui.
#
# 'dirs' y 'marcos' no son iguales en todas, y el reparto es el mismo que ya tienen los bichos por
# los mismos motivos:
#   * 'encaje' y 'muerte' van en UNA sola direccion. Solo se ven en la pantalla de combate, y ahi
#     al personaje se le mira siempre de frente; las otras siete serian imagenes que no mira nadie.
#   * 'cadaver' es justo lo contrario -- UN marco por cada una de las ocho -- porque en el mapa no
#     se te ve morir, pero puedes haber caido mirando a cualquier lado.
#   * 'encaje' a 18 fps NO ES NEGOCIABLE: es lo que espera CombatFX.T_ENCAJE (0,22 s x 4 marcos).
#     Con cualquier otro numero el golpe se reproduce estirado o comprimido.
const ANIMS := [
	{"n": "idle", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "sigilo", "loop": true, "fps": 5.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "walk", "loop": true, "fps": 8.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "correr", "loop": true, "fps": 11.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "golpe", "loop": false, "fps": 12.0, "dirs": 8, "marcos": 8, "ultimo": true},
	# CON EL ARMA FUERA (cerca de un enemigo). 'guardia*' son idle/andar/correr con el arma en alto,
	# NO se bifurca idle/walk/correr para no doblar el atlas del cuerpo y la ropa. 'desenvainar' es
	# la transicion (envaina -> mano). 'golpe_izq' es el golpe con la mano mala (dual), 'golpe_2m'
	# el tajo con las dos manos (hacha/martillo/mandoble).
	{"n": "guardia", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_and", "loop": true, "fps": 8.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_cor", "loop": true, "fps": 11.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "desenvainar", "loop": false, "fps": 14.0, "dirs": 8, "marcos": 5, "ultimo": true},
	{"n": "golpe_izq", "loop": false, "fps": 12.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "golpe_2m", "loop": false, "fps": 10.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "encaje", "loop": false, "fps": 18.0, "dirs": 1, "marcos": 4, "ultimo": true},
	{"n": "muerte", "loop": false, "fps": 10.0, "dirs": 1, "marcos": 8, "ultimo": true},
	{"n": "cadaver", "loop": false, "fps": 1.0, "dirs": 8, "marcos": 1, "ultimo": false},
]


# El nombre de animacion que le toca a un estado del mapa. Vive aqui, y no en player.gd, por lo
# mismo que SpritesEnemigo.animacion no vive en enemy.gd: la necesitan el jugador, el compañero, el
# jugador remoto y el visor, y cuatro copias de la misma regla acaban divergiendo -- en una
# pantalla el personaje corre y en la otra pasea.
#
# 'modo' es el movement_mode de player.gd: 0 sigilo, 1 andar, 2 correr.
# 'desenvainado' = lleva el arma FUERA (hay un enemigo cerca). 'golpe_variante': 0 mano derecha,
# 1 mano izquierda (dual), 2 a dos manos.
static func animacion(mirada: Vector2, modo: int, moviendose: bool, golpeando: bool = false,
		desenvainado: bool = false, golpe_variante: int = 0) -> String:
	var d: int = SpriteLienzo.dir8(mirada)
	if golpeando:
		return "%s_%d" % [["golpe", "golpe_izq", "golpe_2m"][clampi(golpe_variante, 0, 2)], d]
	# Agachado manda sobre todo lo demas: en sigilo el arma se queda envainada (no delatas la
	# silueta de guardia) y la pose es la de siempre. Poner el idle de pie al pararte delataba el
	# sigilo: se te veia levantarte cada vez que soltabas la tecla.
	if modo == 0:
		return "sigilo_%d" % d
	if desenvainado:
		if not moviendose:
			return "guardia_%d" % d
		return "guardia_cor_%d" % d if modo == 2 else "guardia_and_%d" % d
	if not moviendose:
		return "idle_%d" % d
	return "correr_%d" % d if modo == 2 else "walk_%d" % d


# La pose de estar tirado en el suelo, hermana de la de arriba. Un marco por direccion.
static func cadaver(mirada: Vector2) -> String:
	return "cadaver_%d" % SpriteLienzo.dir8(mirada)


# ============================================================
#  EL LIENZO Y LA PROYECCION
# ============================================================

# Cuantas celdas de lado. Par, para que el centro caiga limpio entre dos pixeles y no medio dentro
# de uno (si no, el personaje cojea medio pixel al girar).
static func celdas(esc: float = 1.0) -> int:
	var lado: int = int(ceil(ALTO_MUNDO * esc * LIENZO_FACTOR / SpriteLienzo.UNIDADES_POR_CELDA))
	return lado + (lado % 2)


static func lienzo(esc: float = 1.0) -> Vector2i:
	var l: int = celdas(esc)
	return Vector2i(l, l)


# El origen (los pies) dentro del lienzo. Centrado a lo ancho y BAJO a lo alto: por debajo de los
# pies solo hace falta sitio para la sombra y para lo que asome al caerse, mientras que por arriba
# tiene que caber el personaje entero con el arma levantada.
static func origen(esc: float = 1.0) -> Vector2:
	var l: float = float(celdas(esc))
	return Vector2(l * 0.5, l * 0.80)


# A que altura del NODO caen los pies, en pixeles de mundo.
#
# El nodo del personaje esta en el centro de su caja de colision de 32x32, y esa caja es el sitio
# que ocupa EN EL SUELO. Los pies no van en el centro de esa caja sino cerca de su borde de abajo:
# asi el cuerpo queda por encima del hueco que ocupa, que es como se lee la profundidad en una vista
# a 45 grados. Puestos en el centro, el personaje parece hundido hasta las rodillas en su propia
# casilla; puestos en el borde justo, flota.
#
# Los bichos hacen lo mismo, solo que a la callada: cada generador lo mete en la proporcion de su
# lienzo (el slime deja un 40% de aire por debajo del origen). Aqui va como un numero con nombre
# porque lo comparten las ~35 capas y una capa que lo entienda distinto se dibuja desplazada.
const PIES_BAJO_NODO := 14.0


# ============================================================
#  LOS DOS CUERPOS: la huella y el bulto
# ============================================================
# El personaje tiene DOS tamaños de colision y no uno, porque en una vista a 45 grados chocar con
# una pared y recibir un golpe no son el mismo problema:
#
#   * LA HUELLA es lo que ocupa EN EL SUELO: con eso se choca contra los muros. Va baja y pegada a
#     los pies, asi que la cabeza y el tronco pueden solaparse con lo que hay detras -- que es
#     justo lo que se lee como profundidad. Si la huella fuera el cuerpo entero, el personaje se
#     quedaria clavado un palmo antes de tocar la pared y todo pareceria de goma.
#   * EL BULTO es el cuerpo entero: contra eso te pegan. Ojo, NO ES UN NODO -- en todo el proyecto
#     no hay un solo Area2D, y el contacto se resuelve con una caja calculada desde el centro (ver
#     Enemy.hueco_hasta). Este es el numero del que sale esa caja.
#
# Viven aqui, y no en player.gd, porque los comparten los TRES cuerpos que hay de una persona: el
# que llevas, los compañeros del sequito y el otro humano en multijugador. Con una copia en cada
# uno, el mismo pasillo se pasaria o no segun quien lo intentase, y a un compañero le pegarian
# desde mas lejos que a ti.
#
# LA HUELLA NO SE PUEDE DOBLAR AUNQUE EL DIBUJO CREZCA, y es un tope duro del mapa: los pasillos
# miden 3 celdas (96 px, ver DungeonFloor.ancho_pasillo) y existen para que "quepais tu y un bicho,
# y puedas esquivarlo". Con 64 px de huella quedan 32 libres, o sea que un enemigo normal tapona el
# pasillo -- y el Rey Slime, que mide 83, lo hace intransitable.
#
# VA BAJA Y PEGADA A LOS PIES: con HUELLA_Y = 11 y 14 de alto, ocupa de +4 a +18 respecto al nodo, y
# los pies del dibujo caen en +14 (ver PIES_BAJO_NODO). Asi solo los pies chocan contra el muro y la
# cabeza y el tronco pueden pasar por delante de lo que hay detras, que es lo que se lee como
# profundidad en una vista a 45 grados.
const HUELLA := Vector2(26.0, 14.0)
const HUELLA_Y := 11.0

# EL BULTO CON EL QUE SE PELEA, en coordenadas RELATIVAS AL NODO. No es cuadrado ni esta centrado, y
# las dos cosas son el punto.
#
# ESTABA CENTRADO EN EL NODO Y EL DIBUJO NO LO ESTA: los pies caen en +14 y la coronilla en -46, o
# sea que el personaje esta casi entero POR ENCIMA de su nodo. Una caja centrada cubria las piernas
# y un palmo de suelo vacio, y no cubria ni el pecho ni la cabeza. Ahora va de -24 a +18: de los
# pies a un pelo por encima de los hombros (que estan en -19).
#
# NO LLEGA A LA CORONILLA A PROPOSITO. En una vista a 45 grados "mas alto en pantalla" es "mas lejos
# en profundidad", asi que una caja que subiera hasta -46 dejaria que te pegaran desde casi dos
# casillas por encima. El borde de arriba es el numero a mover si al jugar los bichos conectan antes
# o despues de lo que se ve.
#
# Y ES ESTRECHA (22 de ancho, como el dibujo) SIN QUE ESO TE QUITE ALCANCE: attack_range se mide de
# CENTRO A CENTRO y el filtro lo convierte a hueco restando los dos medios cuerpos, asi que al
# estrechar la caja el hueco permitido crece lo mismo y llegas igual de lejos. Ver
# Player._enemigos_a_tiro.
const CAJA_CUERPO := Rect2(-11.0, -24.0, 22.0, 42.0)


# Lo que hay que ponerle de 'offset' al nodo del sprite (con centered = false) para que los pies
# caigan donde tienen que caer. En celdas, que es en lo que trabaja el offset antes de escalar.
static func offset_sprite(esc: float = 1.0) -> Vector2:
	var o: Vector2 = origen(esc)
	return Vector2(-o.x, -o.y + PIES_BAJO_NODO / SpriteLienzo.UNIDADES_POR_CELDA)


# Cuanto hay que escalar la textura para que una celda mida lo que debe. Es el mismo numero para
# todo el juego (ver SpriteLienzo.UNIDADES_POR_CELDA): un personaje mas grande se dibujaria con mas
# celdas, nunca con celdas mas gordas.
static func escala_sprite() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


# Unidades de mundo -> celdas. El tamaño del pixel es el mismo para todo el juego: un personaje mas
# grande se dibuja con MAS CELDAS, nunca con celdas mas gordas.
static func u(esc: float = 1.0) -> float:
	return esc / SpriteLienzo.UNIDADES_POR_CELDA


# ============================================================
#  EL ESQUELETO DE UN FOTOGRAMA
# ============================================================
# Devuelve los puntos del cuerpo YA DEFORMADOS por la pose, pero AUN SIN GIRAR por la direccion.
#
# Esto ultimo es a proposito y conviene entenderlo antes de usarlo: dejando los puntos en el
# sistema del CUERPO, una capa puede decir "la hombrera va dos unidades por fuera del hombro" y eso
# significa lo mismo mire el personaje adonde mire. Si se devolvieran ya girados, cada capa tendria
# que deshacer el giro para colocar sus adornos, y ahi es donde se cuela el error de signo que deja
# el escudo en la mano equivocada cuando miras al noroeste.
#
# El giro y la proyeccion los hace 'poner', que es por donde pasan todas las capas.
static func esqueleto(anim: String, marco: int, dir: int, esc: float = 1.0) -> Dictionary:
	var fila: Dictionary = _anim(anim)
	var marcos: int = int(fila["marcos"])
	var divisor: float = float(marcos - 1) if bool(fila["ultimo"]) else float(marcos)
	var t: float = 0.0 if divisor <= 0.0 else float(marco) / divisor
	var pose: Dictionary = _pose(anim, t)
	var d: Dictionary = montar(pose, dir, esc)
	# El NOMBRE BASE de la animacion ("idle", "golpe_2m"), para las capas que dibujan distinto
	# segun la anim -- hoy solo el arma (ArmaSprites): envainada en 'idle', en mano en 'guardia'.
	# 'montar' no lo recibe (el visor le pasa poses sueltas sin anim), asi que se pone aqui.
	d["anim"] = anim
	return d


# El esqueleto a partir de una pose ya calculada. Separado de 'esqueleto' para que el visor pueda
# pedir poses a medias (con la 't' en un valor cualquiera) sin pasar por la rejilla de fotogramas.
static func montar(pose: Dictionary, dir: int, esc: float = 1.0) -> Dictionary:
	var agacha: float = float(pose.get("agacha", 0.0))
	# LOS MIEMBROS SE MUEVEN EN ANGULO, EN RADIANES, Y NO EN DISTANCIA.
	#
	# El primer intento balanceaba los brazos moviendo la MANO hacia delante y hacia atras. Parece lo
	# mismo y no lo es: el hombro se queda donde esta, asi que adelantar la mano cuatro unidades
	# ALARGA el brazo y atrasarla lo encoge. Andando de lado se veia clarisimo -- un brazo un 16% mas
	# largo que el otro, y el adelantado casi tan largo como una pierna. Girando sobre el hombro la
	# longitud se conserva sola, no hay nada que compensar, y de propina la mano describe un arco y
	# sube un poco al final del recorrido, que es lo que hace de verdad un brazo.
	#
	# Positivo = hacia DELANTE, igual que 'inclina' y 'caida'. Las piernas, lo mismo sobre la cadera.
	var paso: float = float(pose.get("paso", 0.0))
	var brazo: float = float(pose.get("brazo", 0.0))
	var brazo_der: float = float(pose.get("brazo_der", brazo))
	var brazo_izq: float = float(pose.get("brazo_izq", -brazo))
	var bote: float = float(pose.get("bote", 0.0))
	var avance: float = float(pose.get("avance", 0.0))
	var inclina: float = float(pose.get("inclina", 0.0))
	var caida: float = float(pose.get("caida", 0.0))
	var apoyo: float = float(pose.get("apoyo", 0.0))

	# AGACHARSE encoge en vertical y ensancha, como cualquier cuerpo que se comprime. El tope de 1.0
	# es duro a proposito: por encima la altura se vuelve negativa y las piezas dejan de pintarse SIN
	# DAR ERROR -- el personaje desaparece a trozos. Es el mismo agujero que ya se documento en la
	# rata, y aqui se cierra en vez de dejarlo a la buena fe de quien escriba una pose.
	agacha = clampf(agacha, 0.0, 1.0)
	var alto: float = 1.0 - 0.34 * agacha
	var ancho: float = 1.0 + 0.10 * agacha

	# --- Los puntos en reposo, ya con el balanceo de brazos y piernas ---
	# Las piernas van en contrafase entre si, y los brazos en contrafase con las piernas: es lo que
	# hace que andar se lea como andar y no como un muñeco deslizandose.
	var p: Dictionary = {}
	p[P_CADERA] = CADERA
	p[P_TORSO] = TORSO
	p[P_CUELLO] = CUELLO
	p[P_CABEZA] = CABEZA
	# Detras de la cabeza, a ocho decimos de su radio: lo justo para que su profundidad tenga SIGNO
	# claro en las ocho direcciones (ver P_NUCA). No se dibuja nada ahi.
	p[P_NUCA] = CABEZA - Vector3(0.0, CABEZA_R * 0.8, 0.0)

	# LOS BRAZOS: giran RIGIDOS sobre su hombro. Rigidos (codo y mano giran lo mismo) y no articulados
	# porque a este tamaño de pixel un codo doblado son dos celdas de diferencia que nadie ve, y a
	# cambio la longitud queda garantizada por construccion en vez de depender de que los numeros
	# cuadren. Un brazo que cambia de largo es lo primero que se nota, y no hay forma de no verlo una
	# vez visto.
	for lado in 2:
		var s: float = 1.0 if lado == 0 else -1.0          # 0 = izquierdo (+x), 1 = derecho (-x)
		var a: float = brazo_izq if lado == 0 else brazo_der
		var hombro := Vector3(s * HOMBRO.x, HOMBRO.y, HOMBRO.z)
		p[P_HOMBRO_IZQ if lado == 0 else P_HOMBRO_DER] = hombro
		p[P_CODO_IZQ if lado == 0 else P_CODO_DER] = _girar_miembro(
			Vector3(s * CODO.x, CODO.y, CODO.z), hombro, a)
		p[P_MANO_IZQ if lado == 0 else P_MANO_DER] = _girar_miembro(
			Vector3(s * MANO.x, MANO.y, MANO.z), hombro, a)

	# LAS PIERNAS: lo mismo sobre la cadera de su lado. Y aqui la rotacion trae de regalo algo que
	# antes habia que falsear a mano: el pie SUBE al final de la zancada, porque va por un arco y no
	# por una linea recta. Estaba puesto con un 'maxf(0, paso) * 1.5' que era justo eso, aproximado.
	for lado in 2:
		var s2: float = 1.0 if lado == 0 else -1.0
		var a2: float = paso if lado == 0 else -paso
		var cad := Vector3(s2 * PIE_X, 0.0, CADERA.z)
		p[P_RODILLA_IZQ if lado == 0 else P_RODILLA_DER] = _girar_miembro(
			Vector3(s2 * RODILLA.x, RODILLA.y, RODILLA.z), cad, a2)
		p[P_PIE_IZQ if lado == 0 else P_PIE_DER] = _girar_miembro(
			Vector3(s2 * PIE.x, PIE.y, PIE.z), cad, a2)

	# --- Puntos de anclaje del ARMA ---
	# Van AQUI, antes del bucle de deformaciones de abajo, para que hereden inclina / caida /
	# ancho / alto / avance como cualquier otro punto: una espada envainada tiene que tumbarse con
	# el cadaver, no quedarse flotando de pie. La empuñadura cae dentro del puño (un pelo adelante y
	# abajo); la "punta" es un punto en la direccion del antebrazo -> de ahi saca la capa hacia
	# donde mira la hoja. Envainadas: a la cadera de su lado y a la espalda para las de dos manos.
	p[P_EMPUNADURA_IZQ] = p[P_MANO_IZQ] + Vector3(0.0, 1.0, -0.6)
	p[P_EMPUNADURA_DER] = p[P_MANO_DER] + Vector3(0.0, 1.0, -0.6)
	var _d_izq: Vector3 = (p[P_MANO_IZQ] - p[P_CODO_IZQ])
	var _d_der: Vector3 = (p[P_MANO_DER] - p[P_CODO_DER])
	_d_izq = _d_izq.normalized() if _d_izq.length() > 0.01 else Vector3(0.0, 1.0, -0.3)
	_d_der = _d_der.normalized() if _d_der.length() > 0.01 else Vector3(0.0, 1.0, -0.3)
	p[P_PUNTA_IZQ] = p[P_EMPUNADURA_IZQ] + _d_izq * 4.0
	p[P_PUNTA_DER] = p[P_EMPUNADURA_DER] + _d_der * 4.0
	p[P_CADERA_DER] = Vector3(-(PIE_X + 3.0), 1.5, CADERA.z + 1.0)
	p[P_CADERA_IZQ] = Vector3(PIE_X + 3.0, 1.5, CADERA.z + 1.0)
	# A LA ESPALDA: la empuñadura asoma por encima del hombro derecho y la hoja cruza en diagonal
	# hacia la cadera izquierda. Recta y centrada quedaba escondida entre el cuerpo (delante) y el
	# pelo (mas delante todavia): no se veia por ningun lado.
	p[P_ESPALDA] = Vector3(-4.0, -4.0, 34.0)
	p[P_ESPALDA_PUNTA] = p[P_ESPALDA] + Vector3(9.0, 0.0, -22.0)

	# --- Deformaciones que afectan al cuerpo entero ---
	# INCLINARSE es una vuelta del TRONCO sobre la cadera; CAERSE es una vuelta de TODO sobre los
	# pies. Son dos cosas distintas y por eso son dos parametros: al correr se echa el pecho adelante
	# pero los pies siguen en el suelo, y al morir se desploma el conjunto.
	#
	# Que el jugador se caiga girando sobre el eje IZQUIERDA-DERECHA (o sea, hacia delante o hacia
	# atras) y no sobre el eje morro-cola como la rata no es un capricho: una persona se desploma, no
	# rueda de costado. Y encima sale mas barato -- no hace falta intercambiar los radios de las
	# elipses, que es de donde salen la mitad de los fallos raros de la rata patas arriba.
	for k in p.keys():
		var v: Vector3 = p[k]
		if not is_zero_approx(inclina) and v.z > CADERA.z:
			v = _girar_yz(v, CADERA, inclina)
		if not is_zero_approx(caida):
			v = _girar_yz(v, Vector3.ZERO, caida)
		# El estirado y el achatado van DESPUES de las vueltas. Al reves, agacharse mientras caes
		# aplastaba el cuerpo en el eje equivocado y el cadaver salia con las piernas mas cortas que
		# los brazos.
		v = Vector3(v.x * ancho, v.y, v.z * alto)
		v.y += avance
		v.z += bote + apoyo
		p[k] = v

	# El giro en planta: la direccion, mas el rumbo extra que pide la muerte (ver _pose_muerte).
	var ang: float = DIR_VECS[dir].angle() - DIR_VECS[0].angle() + float(pose.get("rumbo", 0.0))

	# EL CADAVER SE PONE ATRAVESADO A LA CAMARA, SIEMPRE.
	#
	# Un cuerpo tumbado es una figura LARGA, y una figura larga que apunta a la camara desaparece: se
	# proyecta sobre si misma y queda un monton corto y vertical. Con el cadaver eso no es que se vea
	# feo, es que MIENTE -- se leia como un personaje de pie, agachado. En dos de las ocho direcciones
	# el muerto parecia estar vivo.
	#
	# No hay ningun rumbo fijo que lo evite: gires lo que gires, con ocho direcciones a 45 grados
	# siempre hay dos que caen sobre el eje de la camara. Asi que el cadaver no hereda el giro de la
	# direccion: se le pone el angulo atravesado MAS CERCANO al que le tocaria, que conserva hacia que
	# lado tiene la cabeza (que es lo unico que se distingue de un cuerpo tirado) y garantiza que se
	# vea tumbado en las ocho.
	#
	# Ojo: esto NO se le aplica a 'muerte', que se ve caer entera en combate y necesita su rumbo
	# propio para que la caida se aprecie. Son la misma pose y dos problemas distintos.
	# El eje de delante del cuerpo, girado, es horizontal en pantalla cuando cos(ang) = 0, o sea con
	# ang = +90 o -90. Se coge el de los dos que caiga mas cerca del natural.
	if bool(pose.get("atravesado", false)):
		ang = PI * 0.5 if fposmod(ang, TAU) < PI else -PI * 0.5
	return {
		"puntos": p, "ang": ang, "dir": dir, "esc": esc, "pose": pose,
		"ancho": ancho, "alto": alto, "caida": caida,
		"origen": origen(esc), "u": u(esc), "lienzo": lienzo(esc),
	}


# Vuelta de un punto en el plano PROFUNDIDAD-ALTURA (los ejes Y y Z) alrededor de un pivote. Es
# "echarse hacia delante": el eje del giro es la linea que une los dos hombros.
#
# ANGULO POSITIVO = HACIA DELANTE, o sea hacia donde mira. El primer intento lo tenia al reves --
# la cuenta salio de copiar una rotacion estandar sin pensar que aqui +Y es "hacia donde mira" -- y
# el resultado fue que el personaje corria echado hacia ATRAS, con el pecho sacado. Se ve enseguida
# cuando lo sabes y no se ve en absoluto cuando no: parece una postura rara y no un signo cambiado.
# Lo mismo, pero para un MIEMBRO QUE CUELGA, y con el signo puesto del derecho.
#
# Existe por una trampa de signos que garantiza un fallo si no se le pone nombre: 'girar_yz' gira el
# cuerpo rigido alrededor del pivote, asi que un angulo positivo lleva hacia delante lo que esta
# ARRIBA del pivote (el tronco sobre la cadera, que es para lo que nacio). Un brazo cuelga POR
# DEBAJO del hombro, asi que ese mismo angulo positivo le manda la mano hacia ATRAS. Es correcto y
# es lo contrario de lo que espera quien escribe una pose.
#
# Aqui positivo = la mano o el pie van HACIA DELANTE, que es lo unico que se quiere pensar al
# escribir un ciclo de andar.
static func _girar_miembro(v: Vector3, pivote: Vector3, ang: float) -> Vector3:
	return _girar_yz(v, pivote, -ang)


static func _girar_yz(v: Vector3, pivote: Vector3, ang: float) -> Vector3:
	var dy: float = v.y - pivote.y
	var dz: float = v.z - pivote.z
	var c: float = cos(ang)
	var s: float = sin(ang)
	return Vector3(v.x, pivote.y + dy * c + dz * s, pivote.z + dz * c - dy * s)


# ============================================================
#  COLOCAR UNA PIEZA (lo que usan TODAS las capas)
# ============================================================
# Coge un punto en el sistema del cuerpo, lo gira por la direccion y lo proyecta a la celda que le
# toca. Es el unico sitio donde se aplica la camara, asi que ninguna capa puede verse desde otro
# angulo que las demas.
#
#     pantalla_x = origen.x + x * u
#     pantalla_y = origen.y + (y * cos(45) - z * sin(45)) * u
#
# Ese "- z" es lo que pone la cabeza por encima de los pies y hace que de perfil se vea el COSTADO y
# no la planta. Es la misma proyeccion que los bichos, y tiene que serlo: comparten suelo.
#
# 'r' son los semiejes en unidades de mundo (x a lo ancho, y de FONDO, z de alto).
#
# LA FORMA GIRA, NO SOLO LA POSICION. Esto es lo que costo el primer intento entero: colocando la
# pieza en su sitio girado pero dibujandola siempre con los mismos radios, el pecho medida su ancho
# de frente TAMBIEN visto de perfil. Y como todas las piezas hacian lo mismo, el personaje salia
# igual de gordo mirara adonde mirara -- un bulto que no acababa de girar nunca, por mucho que los
# brazos y las piernas si se movieran.
#
# Se resuelve proyectando los TRES semiejes en vez de dos, que es lo que de verdad hace la camara:
#     horizontal = |(rx·cos, ry·sen)|          lo que la pieza ocupa a lo ancho de la pantalla
#     fondo      = |(rx·sen, ry·cos)|          lo que le queda de profundidad tras girar
#     vertical   = |(fondo·cos45, rz·sen45)|   profundidad aplastada + altura levantada
# De frente el pecho sale ancho, de perfil estrecho, y una esfera sale redonda mire por donde mire,
# que es la comprobacion de que la cuenta esta bien.
#
# Y sale ademas la elipse SIN GIRAR (los ejes son los de la rejilla), asi que entra por la ruta
# rapida por filas de SpriteLienzo.elipse. No es un detalle: la rata dejo medido que la ruta general
# multiplica por diez el tiempo de generar, y aqui hay ~35 capas que hornear.
#
# La sombra del suelo (rz = 0) sale correcta sola por la misma formula -- vertical = fondo·cos45 --,
# asi que no necesita ni un caso aparte ni una constante a ojo.
static func poner(piezas: Array, esq: Dictionary, local: Vector3, r: Vector3, tono: int,
		opts: Dictionary = {}) -> void:
	var pr: Dictionary = proyectar(esq, local, r, opts)
	piezas.append({
		"pos": pr["pos"], "radio": pr["radio"],
		"persp": 1.0, "tono": tono, "ang": 0.0, "gira_forma": false,
		"solo_sobre": opts.get("solo_sobre", []),
	})


# DONDE CAE EN PANTALLA un punto del cuerpo, y CUANTO OCUPA ahi. Devuelve {pos, radio} en CELDAS.
#
# Es la cuenta de arriba, sacada de 'poner' para poder preguntarla sin dibujar nada. La necesita
# MunecoJugador para pegar tu imagen a la cabeza: la cara no es una elipse horneada sino un PNG que
# se recoloca en el juego, asi que tiene que saber donde esta la cabeza en ESTE fotograma.
#
# Y esta separada en vez de copiada porque copiar la proyeccion es exactamente el fallo que la
# cabecera de este archivo dice que hay que evitar: dos versiones de la camara se separan en cuanto
# alguien toque una, y el sintoma seria que tu cara flota medio pixel por delante de tu cabeza en
# algunas direcciones y no en otras.
static func proyectar(esq: Dictionary, local: Vector3, r: Vector3,
		opts: Dictionary = {}) -> Dictionary:
	var org: Vector2 = esq["origen"]
	var uu: float = esq["u"]
	var ang: float = esq["ang"]
	var an: float = esq["ancho"]
	var al: float = esq["alto"]
	# 'en_suelo' se salta la altura: es para la sombra de contacto, que es una mancha en el suelo y
	# el suelo no se levanta cuando el personaje bota. Esa separacion entre el cuerpo que sube y la
	# sombra que se queda es justo lo que se lee como un salto.
	var en_suelo: bool = bool(opts.get("en_suelo", false))
	var gira: bool = bool(opts.get("gira", true))

	var plano := Vector2(local.x, local.y)
	var rot: Vector2 = plano.rotated(ang) if gira else plano
	var z: float = 0.0 if en_suelo else local.z

	var rx: float = r.x * an
	var ry: float = r.y
	var rz: float = r.z * al

	# AL CAERSE, EL RADIO TAMBIEN GIRA. Es la trampa que ya mordio en la rata y que aqui salio con el
	# cadaver partido en dos: los PUNTOS se tumban -- la cabeza se va al suelo, el cuello detras --,
	# pero si las elipses conservan el grosor que tenian de pie, el cuello sigue siendo una pieza
	# fina en el eje equivocado y deja de llegar de la cabeza al torso. Lo que se ve es un cuerpo
	# tirado y una cabeza suelta a un palmo, y no da ningun error: lo caza el validador de islas del
	# horno, que fue exactamente como aparecio.
	#
	# Lo que era ALTO pasa a ser FONDO y al reves, mezclado por el angulo de la caida. La inclinacion
	# del tronco NO entra aqui a proposito: como mucho son 15 grados y a esa escala no mueve ni un
	# pixel, mientras que meterla obligaria a saber que puntos giraron sobre la cadera y cuales no.
	var caida: float = float(esq.get("caida", 0.0))
	if not is_zero_approx(caida) and not en_suelo:
		var cc: float = cos(caida)
		var ss: float = sin(caida)
		var ry2: float = sqrt(ry * ry * cc * cc + rz * rz * ss * ss)
		var rz2: float = sqrt(ry * ry * ss * ss + rz * rz * cc * cc)
		ry = ry2
		rz = rz2

	var ca: float = cos(ang) if gira else 1.0
	var sa: float = sin(ang) if gira else 0.0
	var ex: float = sqrt(rx * rx * ca * ca + ry * ry * sa * sa)
	var fondo: float = sqrt(rx * rx * sa * sa + ry * ry * ca * ca)
	var ey: float = sqrt(fondo * fondo * SpriteLienzo.COS_CAM * SpriteLienzo.COS_CAM
		+ rz * rz * SpriteLienzo.SIN_CAM * SpriteLienzo.SIN_CAM)

	var sx: float = org.x + rot.x * uu
	var sy: float = org.y + (rot.y * SpriteLienzo.COS_CAM - z * SpriteLienzo.SIN_CAM) * uu
	return {
		"pos": Vector2(sx, sy),
		"radio": Vector2(maxf(0.02, ex * uu), maxf(0.02, ey * uu)),
	}


# Une dos puntos con una cadena de elipses. Es lo que dibuja un brazo, una pierna o la hoja de una
# espada, y esta aqui porque lo necesitan casi todas las capas.
#
# EL PASO TIENE QUE SER MENOR QUE EL GROSOR o la cadena sale a TROZOS SUELTOS flotando. Es la misma
# trampa que ya mordio en la cola de la rata, y el validador de islas de hornear_sprites.gd la caza,
# pero solo si alguien mira el aviso: mejor no meterla.
static func cadena(piezas: Array, esq: Dictionary, a: Vector3, b: Vector3, r0: float, r1: float,
		tono: int, opts: Dictionary = {}) -> void:
	var largo: float = a.distance_to(b)
	var pasos: int = maxi(2, int(ceil(largo / maxf(0.35, minf(r0, r1) * 0.85))))
	for i in pasos + 1:
		var f: float = float(i) / float(pasos)
		var r: float = lerpf(r0, r1, f)
		poner(piezas, esq, a.lerp(b, f), Vector3(r, r, r), tono, opts)


# La PROFUNDIDAD de un punto del cuerpo una vez girado: cuanto se aleja de la camara.
#
# ES LA RESPUESTA A LO DEL CASCO, y sale gratis. El compositor coge el punto del que cuelga cada
# capa, pregunta aqui y ordena. Lo que queda detras del torso se dibuja detras, sin una sola tabla
# de casos: de espaldas tu icono de la cara tiene profundidad negativa y no se dibuja; de frente la
# tiene positiva y se ve. Mirando al este, la mano izquierda (y el escudo con ella) se va detras del
# cuerpo sola.
static func profundidad(esq: Dictionary, punto: StringName) -> float:
	var p: Vector3 = esq["puntos"].get(punto, Vector3.ZERO)
	return Vector2(p.x, p.y).rotated(float(esq["ang"])).y


# ============================================================
#  DONDE VA EL ARMA (lo unico que sabe de armas este archivo)
# ============================================================
# Devuelve donde se agarra el arma y hacia donde apunta, EN EL SISTEMA DEL CUERPO (sin girar por la
# direccion -- de eso se encarga 'poner' cuando la capa del arma coloca sus elipses).
#
#   mano:   0 = derecha, 1 = izquierda, 2 = las dos (arma a dos manos)
#   estado: "mano" (empuñada), "cadera" (envainada al costado), "espalda" (colgada a la espalda)
#
# 'atras' dice si el agarre queda por detras del cuerpo (para que la capa se ordene detras). La
# capa ArmaSprites es la unica que llama aqui.
static func agarre_arma(esq: Dictionary, mano: int, estado: String) -> Dictionary:
	var p: Dictionary = esq["puntos"]
	match estado:
		"cadera":
			var emp: Vector3 = p[P_CADERA_DER] if mano == 0 else p[P_CADERA_IZQ]
			# Empuñadura arriba, hoja cayendo por el muslo y un pelo hacia delante.
			return {"empunadura": emp, "eje": Vector3(0.0, 0.35, -1.0).normalized(), "atras": false}
		"espalda":
			return {"empunadura": p[P_ESPALDA],
				"eje": (p[P_ESPALDA_PUNTA] - p[P_ESPALDA]).normalized(), "atras": true}
		_:
			# "mano": empuñada. A dos manos el agarre es el punto medio de las dos manos y el eje
			# sale del brazo derecho (los brazos giran cada uno sobre SU hombro, asi que las dos
			# manos no caen exactamente sobre el mismo punto del astil -- se coge una referencia).
			if mano == 2:
				var medio: Vector3 = p[P_EMPUNADURA_DER].lerp(p[P_EMPUNADURA_IZQ], 0.5)
				return {"empunadura": medio,
					"eje": (p[P_PUNTA_DER] - p[P_EMPUNADURA_DER]).normalized(), "atras": false}
			var e: Vector3 = p[P_EMPUNADURA_DER] if mano == 0 else p[P_EMPUNADURA_IZQ]
			var pu: Vector3 = p[P_PUNTA_DER] if mano == 0 else p[P_PUNTA_IZQ]
			return {"empunadura": e, "eje": (pu - e).normalized(), "atras": false}


# ============================================================
#  LAS POSES
# ============================================================
# Una funcion por animacion. Las CICLICAS van con sin(TAU*t) -- se repiten y tienen que empalmar sin
# salto --, y las que NO son periodicas van por TRAMOS: un golpe es tomar impulso, descargar y
# recomponerse, no una onda.
#
# CUIDADO CON LAS UNIDADES, que aqui conviven dos y no se distinguen mirandolas:
#   * 'paso', 'brazo', 'inclina', 'caida' y 'rumbo' van en RADIANES, y 'agacha' en fraccion. Son
#     independientes del tamaño del personaje: un brazo que gira un cuarto de vuelta gira lo mismo
#     mida lo que mida.
#   * 'bote', 'avance' y 'apoyo' van en UNIDADES DE MUNDO. Esas SI escalan con ALTO_MUNDO, y hay que
#     acordarse de ellas el dia que se toque el tamaño: al doblarlo, un bote de 0,34 se queda en la
#     mitad de alto relativo y el paso deja de notarse. Los numeros de abajo estan a escala de
#     ALTO_MUNDO = 60.

static func _anim(nombre: String) -> Dictionary:
	for a in ANIMS:
		if a["n"] == nombre:
			return a
	return ANIMS[0]


static func _pose(anim: String, t: float) -> Dictionary:
	match anim:
		"idle": return _pose_idle(t)
		"sigilo": return _pose_sigilo(t)
		"walk": return _pose_walk(t)
		"correr": return _pose_correr(t)
		"golpe": return _pose_golpe(t)
		"golpe_izq": return _pose_golpe_izq(t)
		"golpe_2m": return _pose_golpe_2m(t)
		"guardia": return _pose_guardia(t)
		"guardia_and": return _pose_guardia_and(t)
		"guardia_cor": return _pose_guardia_cor(t)
		"desenvainar": return _pose_desenvainar(t)
		"encaje": return _pose_encaje(t)
		"muerte": return _pose_muerte(t)
		"cadaver":
			# La MISMA pose final de la muerte, sacada de la misma funcion. Escribir los numeros otra
			# vez aqui seria garantizar que el dia que se retoque la caida el cadaver se quede como
			# estaba, y que el cuerpo pegue un salto al pasar de una a otro.
			var fin: Dictionary = _pose_muerte(1.0)
			fin["atravesado"] = true
			return fin
	return _pose_idle(t)


# Quieto: respira. Nada mas. La tentacion es animarlo mas, y es un error -- el idle es lo que mas
# tiempo esta en pantalla y cualquier gesto llamativo cansa en diez segundos.
static func _pose_idle(t: float) -> Dictionary:
	return {"bote": 0.36 * sin(TAU * t), "brazo": 0.035 * sin(TAU * t),
		"inclina": 0.02 * sin(TAU * t)}


# Agachado. Es informacion de juego y no un adorno: de un vistazo tienes que saber si vas escondido,
# porque de eso depende que el bicho te oiga. Por eso se agacha DE VERDAD (la silueta baja un tercio)
# en vez de insinuarlo, y el paso va corto y pegado al suelo.
#
# Y se agacha MENOS de lo que pedia el cuerpo. El primer intento iba a 0,82 de agachado con el tronco
# muy echado adelante, y a este tamaño de pixel eso no es un personaje agazapado: es un bulto: la
# cabeza baja hasta la altura del pecho, el pecho tapa las piernas y la silueta pierde el cuello y
# los hombros, que son justo lo que dice que eso es una persona. Agachado tiene que seguir
# leyendose, asi que baja lo justo para que se note al lado del andar normal.
#
# Y OJO CON LA INCLINACION, que es lo que de verdad estropea esta pose: 'inclina' hace girar el
# tronco sobre la cadera, asi que cada grado saca la cabeza casi treinta centimetros hacia delante --
# la cabeza esta a veinte unidades del pivote y los pies a ninguna. Con el tronco muy echado, la
# cabeza acaba por DELANTE del pecho, sin cuello visible que las una, y el personaje deja de leerse
# como alguien agachado para leerse como un ganso. Poco agachado y poco inclinado; lo que dice
# "sigilo" es el conjunto bajando, no la postura forzada.
static func _pose_sigilo(t: float) -> Dictionary:
	return {"agacha": 0.44, "inclina": 0.18, "bote": 0.13 * sin(TAU * t),
		"paso": 0.20 * sin(TAU * t), "brazo": 0.10 * sin(TAU * t)}


# Andando. Los brazos van en contrafase con las piernas y el cuerpo sube dos veces por ciclo (una
# por pisada), no una: es lo que separa un paso de un balanceo de barca.
static func _pose_walk(t: float) -> Dictionary:
	return {"paso": 0.42 * sin(TAU * t), "brazo": 0.30 * sin(TAU * t),
		"bote": 0.55 * absf(sin(TAU * t)), "inclina": 0.05}


# Corriendo. No es "andar mas rapido": el tronco se echa adelante, la zancada se abre y el bote sube.
# Poner la animacion de andar a x1.7 se ve mal y ademas miente sobre lo que estas haciendo -- correr
# gasta aguante y hace ruido, asi que tiene que notarse.
static func _pose_correr(t: float) -> Dictionary:
	# El brazo se queda por debajo de la zancada: pasado de medio radian la mano sube por encima del
	# hombro y lo que se ve es alguien haciendo aspavientos, no corriendo. Las piernas si se abren.
	return {"paso": 0.62 * sin(TAU * t), "brazo": 0.48 * sin(TAU * t),
		"bote": 1.13 * absf(sin(TAU * t)), "inclina": 0.26,
		"agacha": 0.08 + 0.05 * sin(TAU * t * 2.0)}


# EL GOLPE DEL MAPA. Tomar impulso -> descargar -> recomponerse, por tramos.
#
# Solo se mueve el brazo DERECHO (el de la mano principal): el izquierdo se queda donde esta, que es
# lo que sujeta el escudo. Si se movieran los dos, el escudo saldria volando con el tajo y la
# Guardia dejaria de leerse.
#
# El paso adelante es corto y vuelve: el jugador no se desplaza de verdad al atacar -- lo hace el
# cono de ataque de player.gd --, asi que la animacion no puede dejarlo descolocado al acabar.
static func _pose_golpe(t: float) -> Dictionary:
	# EN RADIANES, y con un recorrido MUCHO mayor que el de andar: el brazo se va hacia atras y hacia
	# arriba (negativo, casi un cuarto de vuelta larga) y de ahi baja de golpe hacia delante. Con el
	# giro no hay que subir la mano a mano como antes: levantarla ES el mismo angulo pasado de largo.
	var brazo_keys := [[0.0, 0.0], [0.30, -2.35], [0.45, -2.15], [0.62, 0.95], [0.80, 0.55], [1.0, 0.0]]
	var avance_keys := [[0.0, 0.0], [0.30, -1.3], [0.45, -1.0], [0.62, 3.6], [0.80, 2.3], [1.0, 0.0]]
	var inclina_keys := [[0.0, 0.05], [0.30, -0.16], [0.45, -0.12], [0.62, 0.34], [0.80, 0.22], [1.0, 0.05]]
	return {"brazo_der": SpriteLienzo.tramos(t, brazo_keys),
		# El izquierdo apenas acompaña: es el que sujeta el escudo.
		"brazo_izq": -0.08 * SpriteLienzo.tramos(t, brazo_keys),
		"avance": SpriteLienzo.tramos(t, avance_keys),
		"inclina": SpriteLienzo.tramos(t, inclina_keys),
		"agacha": 0.10}


# EL GOLPE CON LA MANO IZQUIERDA. Espejo EXACTO de _pose_golpe: el arco grande se lo lleva el
# brazo izquierdo y el derecho hace de acompañante. Es la mano "mala" del dual -- se alterna con la
# principal golpe a golpe (ver player.gd._elegir_golpe y AbilityData.plan_golpes).
static func _pose_golpe_izq(t: float) -> Dictionary:
	var brazo_keys := [[0.0, 0.0], [0.30, -2.35], [0.45, -2.15], [0.62, 0.95], [0.80, 0.55], [1.0, 0.0]]
	var avance_keys := [[0.0, 0.0], [0.30, -1.3], [0.45, -1.0], [0.62, 3.6], [0.80, 2.3], [1.0, 0.0]]
	var inclina_keys := [[0.0, 0.05], [0.30, -0.16], [0.45, -0.12], [0.62, 0.34], [0.80, 0.22], [1.0, 0.05]]
	return {"brazo_izq": SpriteLienzo.tramos(t, brazo_keys),
		"brazo_der": -0.08 * SpriteLienzo.tramos(t, brazo_keys),
		"avance": SpriteLienzo.tramos(t, avance_keys),
		"inclina": SpriteLienzo.tramos(t, inclina_keys),
		"agacha": 0.10}


# EL TAJO A DOS MANOS (hacha grande / martillo grande / mandoble). Los DOS brazos van juntos, con
# las manos en el astil, y el golpe cae de arriba abajo: se arma alto y se descarga.
#
# EL PICO SE QUEDA EN -2.15 y no en el -2.35 del golpe a una mano: un arma a dos manos es la mas
# larga del juego y, levantada del todo en diagonal, se salia del lienzo (lo canta
# hornear_sprites._avisar_recortes). El 'avance' tambien va mas corto por lo mismo.
static func _pose_golpe_2m(t: float) -> Dictionary:
	var brazo_keys := [[0.0, -0.35], [0.32, -1.90], [0.50, -1.75], [0.68, 0.75], [0.85, 0.40], [1.0, -0.35]]
	var avance_keys := [[0.0, 0.0], [0.32, -0.8], [0.50, -0.5], [0.68, 2.0], [0.85, 1.2], [1.0, 0.0]]
	var inclina_keys := [[0.0, 0.06], [0.32, -0.12], [0.50, -0.08], [0.68, 0.28], [0.85, 0.18], [1.0, 0.06]]
	var b: float = SpriteLienzo.tramos(t, brazo_keys)
	return {"brazo_der": b, "brazo_izq": b,
		"avance": SpriteLienzo.tramos(t, avance_keys),
		"inclina": SpriteLienzo.tramos(t, inclina_keys),
		"agacha": 0.12}


# EN GUARDIA: con el arma fuera pero sin atacar. Como el idle (respira) pero con los dos brazos
# recogidos en alto -- el derecho lleva el arma o es la mano principal del dual, el izquierdo
# equilibra o empuña la segunda. Un pelo agachado: peso repartido, listo para soltar el golpe.
static func _pose_guardia(t: float) -> Dictionary:
	return {"bote": 0.30 * sin(TAU * t),
		"brazo_der": -0.55 + 0.05 * sin(TAU * t),
		"brazo_izq": -0.30 + 0.05 * sin(TAU * t),
		"inclina": 0.08, "agacha": 0.10}


# ANDAR CON EL ARMA FUERA. El ciclo de piernas de andar, pero los brazos NO bracean sueltos: se
# quedan recogidos en la guardia mientras las piernas hacen su trabajo.
static func _pose_guardia_and(t: float) -> Dictionary:
	return {"paso": 0.40 * sin(TAU * t), "bote": 0.55 * absf(sin(TAU * t)),
		"brazo_der": -0.55 + 0.10 * sin(TAU * t),
		"brazo_izq": -0.30 + 0.10 * sin(TAU * t),
		"inclina": 0.10, "agacha": 0.06}


# CORRER CON EL ARMA FUERA.
static func _pose_guardia_cor(t: float) -> Dictionary:
	return {"paso": 0.60 * sin(TAU * t), "bote": 1.05 * absf(sin(TAU * t)),
		"brazo_der": -0.60 + 0.12 * sin(TAU * t),
		"brazo_izq": -0.35 + 0.12 * sin(TAU * t),
		"inclina": 0.24, "agacha": 0.10}


# SACAR EL ARMA. Cinco marcos: la mano va al costado (o por encima del hombro, para el arma a la
# espalda), agarra y tira hasta dejarla en guardia. 'sacando' (0..1) se lo pasa a la capa del arma
# para que interpole el agarre entre "envainada" y "en mano" -- el hueso no sabe de armas, solo
# publica el reloj.
static func _pose_desenvainar(t: float) -> Dictionary:
	var brazo_keys := [[0.0, 0.15], [0.35, 0.55], [0.60, -0.20], [1.0, -0.55]]
	var izq_keys := [[0.0, 0.0], [0.50, 0.10], [1.0, -0.30]]
	var incl_keys := [[0.0, 0.0], [0.40, 1.0], [1.0, 0.4]]
	return {"brazo_der": SpriteLienzo.tramos(t, brazo_keys),
		"brazo_izq": SpriteLienzo.tramos(t, izq_keys),
		"inclina": 0.06 + 0.06 * SpriteLienzo.tramos(t, incl_keys),
		"agacha": 0.10, "sacando": t}


# ENCAJAR UN GOLPE. Cuatro marcos, una direccion, y EMPEZANDO YA GOLPEADO: el frame 0 es el impacto,
# no la pose de reposo. Un golpe no tiene anticipacion, y con cuatro marcos un fotograma de espera
# se comeria la animacion entera.
#
# Se echa hacia atras y se encoge. Sin llegar a lo de la rata (que sale despedida porque pesa poco):
# el personaje encaja mucho durante un combate y una sacudida grande repetida veinte veces marea.
static func _pose_encaje(t: float) -> Dictionary:
	var retro_keys := [[0.0, 1.0], [0.34, 0.52], [0.67, 0.16], [1.0, 0.0]]
	var agacha_keys := [[0.0, 0.55], [0.34, 0.24], [0.67, 0.08], [1.0, 0.0]]
	var incl_keys := [[0.0, -0.38], [0.34, -0.16], [0.67, 0.06], [1.0, 0.0]]
	return {"avance": -SpriteLienzo.tramos(t, retro_keys) * 3.6,
		"agacha": SpriteLienzo.tramos(t, agacha_keys),
		"inclina": SpriteLienzo.tramos(t, incl_keys),
		"brazo_der": -0.35 * SpriteLienzo.tramos(t, retro_keys),
		"brazo_izq": -0.35 * SpriteLienzo.tramos(t, retro_keys)}


# MORIRSE. Ocho marcos en UNA direccion (en combate se te ve de frente).
#
# Se desploma HACIA ATRAS girando sobre los pies, no rueda de costado como la rata: una persona que
# cae se va para atras. Y con un rebote al tocar el suelo -- sin el, la vuelta se lee como el giro de
# una maquina y no como un cuerpo que se cae.
#
# Y GIRA A PERFIL MIENTRAS CAE ('rumbo'). Es la trampa de camara que descubrio la rata y que hay que
# repetir aqui: de frente, el eje sobre el que te desplomas apunta justo a la camara, asi que la
# vuelta no cambia la silueta -- el muerto salia igual que el vivo, solo que mas bajo. Puesto de
# lado, la caida se ve.
static func _pose_muerte(t: float) -> Dictionary:
	# El ultimo valor es 1.0, o sea NOVENTA GRADOS CLAVADOS: acaba tumbado de espaldas, plano. Iba a
	# 1.40 (126 grados, pasado de largo y boca abajo) y eso no se lee como un cuerpo caido sino como
	# un cuerpo doblado hacia atras. El respingo del principio y el rebote del final si se pasan a
	# proposito -- sin ellos la vuelta se lee como el giro de una maquina --, pero el reposo no.
	# EN NEGATIVO: hacia atras. Positivo seria caerse de bruces, y una persona a la que matan se va
	# para atras. El unico valor positivo es el respingo del principio (0.14), que es el ultimo
	# impulso hacia delante antes de venirse abajo.
	var caida_keys := [[0.0, 0.0], [0.14, 0.10], [0.30, -0.26], [0.48, -0.70],
		[0.66, -0.94], [0.80, -1.08], [0.90, -0.97], [1.0, -1.0]]
	# El apoyo es lo que hay que subirlo para que acabe TUMBADO SOBRE el suelo y no medio enterrado.
	# Va a mano y no calculado: lo que sobresale por abajo cambia de pieza segun el angulo.
	var apoyo_keys := [[0.0, 0.0], [0.14, 0.0], [0.30, 1.6], [0.48, 4.2],
		[0.66, 5.8], [0.80, 6.6], [0.90, 6.3], [1.0, 6.5]]
	var agacha_keys := [[0.0, 0.10], [0.14, 0.55], [0.30, 0.30], [0.48, 0.05], [1.0, 0.0]]
	var rumbo_keys := [[0.0, 0.0], [0.14, 0.12], [0.30, 0.48], [0.48, 0.82], [0.66, 0.96], [1.0, 1.0]]
	# Y SE RECOLOCA MIENTRAS CAE, que no es un adorno sino lo que hace que quepa en el lienzo.
	#
	# El giro es sobre los PIES, asi que al acabar tumbado la cabeza queda a la altura entera del
	# cuerpo -- 60 unidades, o sea 52 celdas -- de un solo lado del origen, mientras que a cada lado
	# solo hay medio lienzo. El cadaver se salia por la izquierda y se le cortaba la cabeza en seco
	# (lo caza el validador de recortes del horno, que es de donde salio esto).
	#
	# Se podia arreglar agrandando el lienzo, pero el lienzo lo pagan las ~35 capas y su coste va con
	# el CUADRADO del lado. Desplazar el cuerpo media longitud segun se tumba cuesta un numero y
	# ademas se ve mejor: un cuerpo que se desploma no se queda con los pies clavados donde estaban.
	var avance_keys := [[0.0, 0.0], [0.30, 2.4], [0.48, 9.7], [0.66, 18.6], [1.0, 26.6]]
	# Los brazos se quedan flojos: dejan de acompañar en cuanto empieza la caida.
	var flojo: float = 1.0 - clampf(t * 2.0, 0.0, 1.0)
	return {"caida": SpriteLienzo.tramos(t, caida_keys) * PI * 0.5,
		"avance": SpriteLienzo.tramos(t, avance_keys),
		"apoyo": SpriteLienzo.tramos(t, apoyo_keys),
		"agacha": SpriteLienzo.tramos(t, agacha_keys),
		"rumbo": SpriteLienzo.tramos(t, rumbo_keys) * PI * 0.5,
		"brazo_der": -0.45 * (1.0 - flojo), "brazo_izq": -0.32 * (1.0 - flojo),
		"paso": 0.22 * flojo}

