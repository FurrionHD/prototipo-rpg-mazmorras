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
# Donde quedan las manos con 'junta' = 1: juntas en el mango, a un pelo del centro.
const JUNTA_X := 1.4
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
	# El de MARTILLO y MANDOBLE (24/09): acaba EXACTO en su guardia (guardia_2m), o el arma saltaba al pasar
	# de una a otra. 8 marcos a 22 fps = lo mismo que el de siempre (player._DESENVAINAR_DUR, 5/14 s).
	{"n": "desenvainar_2m", "loop": false, "fps": 22.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "golpe_izq", "loop": false, "fps": 12.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "golpe_2m", "loop": false, "fps": 15.0, "dirs": 8, "marcos": 12, "ultimo": true},
	# LAS HABILIDADES A DOS MANOS en el combate del mapa (24/09, pedidas por el jefe). Ocho direcciones:
	# en el mapa se golpea hacia donde se apunta. 'en_alto' es la CARGA (Martillo de guerra, Tajo del
	# verdugo: el arma arriba hasta soltarla) y 'tajo_2m' lo que la suelta (y el Tajo devastador);
	# 'clavar' el Temblor; 'molinete' la espada extendida (el GIRO no esta aqui: lo da el juego cambiando
	# de direccion, ver CombatTactico._girar_molinete); 'barrido_2m' el Segar; 'grito' el Grito de guerra.
	{"n": "guardia_2m", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_2m_and", "loop": true, "fps": 8.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_2m_cor", "loop": true, "fps": 11.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "en_alto", "loop": true, "fps": 3.0, "dirs": 8, "marcos": 4, "ultimo": false},
	{"n": "tajo_2m", "loop": false, "fps": 20.0, "dirs": 8, "marcos": 12, "ultimo": true},
	{"n": "clavar", "loop": false, "fps": 18.0, "dirs": 8, "marcos": 12, "ultimo": true},
	{"n": "molinete", "loop": true, "fps": 2.0, "dirs": 8, "marcos": 1, "ultimo": false},
	# 17,5 fps: los dos barridos acaban a 0,2 s uno del otro, como sus dos golpes (CombatFX.T_ENCADENADO).
	{"n": "barrido_2m", "loop": false, "fps": 17.5, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "grito", "loop": false, "fps": 12.0, "dirs": 8, "marcos": 8, "ultimo": true},
	# EL HACHA GRANDE (24/09). 'hendedura_2m' el hachazo vertical desde la guardia (sin carga); 'hachazo_2m'
	# el Hachazo brutal (un barrido enorme que se clava); 'carniceria_2m' sus tres barridos a 0,2 s uno de
	# otro (20 fps x 16 marcos); 'gancho_2m' el Desgarro (estira y tira hacia ti); 'mirada' la Sed de sangre.
	# Sus impactos, en CombatFX.IMPACTO_ANIM_MAPA: retocar una = retocar su impacto.
	{"n": "hendedura_2m", "loop": false, "fps": 18.0, "dirs": 8, "marcos": 12, "ultimo": true},
	{"n": "hachazo_2m", "loop": false, "fps": 18.0, "dirs": 8, "marcos": 12, "ultimo": true},
	{"n": "carniceria_2m", "loop": false, "fps": 20.0, "dirs": 8, "marcos": 16, "ultimo": true},
	{"n": "gancho_2m", "loop": false, "fps": 18.0, "dirs": 8, "marcos": 12, "ultimo": true},
	{"n": "mirada", "loop": false, "fps": 12.0, "dirs": 8, "marcos": 12, "ultimo": true},
	# LA DAGA (24/09): su guardia (la de su referencia: brazo estirado al frente y la daga AL REVES) y el
	# desenvainar que acaba en ella (mismo ritmo que el de dos manos).
	{"n": "guardia_daga", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_daga_and", "loop": true, "fps": 8.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_daga_cor", "loop": true, "fps": 11.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "desenvainar_daga", "loop": false, "fps": 22.0, "dirs": 8, "marcos": 8, "ultimo": true},
	# Sus golpes (24/09). 'tajo_daga' se REPITE en cada puñalada (Rafaga, basico), alternando manos con
	# dos dagas; 'tajo_daga_solo' es el de Desaparecer, con la otra daga envainada; 'lanzar_humo' tira la
	# bomba; 'punalada_daga' la estocada (Puñalada, Oportunista); 'afilar_veneno' el Filo emponzoñado.
	# Sus impactos, en CombatFX.IMPACTO_ANIM_MAPA: retocar una = retocar su impacto.
	{"n": "tajo_daga", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 7, "ultimo": true},
	{"n": "tajo_daga_izq", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 7, "ultimo": true},
	{"n": "tajo_daga_solo", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 7, "ultimo": true},
	{"n": "punalada_daga", "loop": false, "fps": 22.0, "dirs": 8, "marcos": 9, "ultimo": true},
	{"n": "punalada_daga_izq", "loop": false, "fps": 22.0, "dirs": 8, "marcos": 9, "ultimo": true},
	{"n": "lanzar_humo", "loop": false, "fps": 16.0, "dirs": 8, "marcos": 12, "ultimo": true},
	{"n": "afilar_veneno", "loop": false, "fps": 12.0, "dirs": 8, "marcos": 10, "ultimo": true},
	# EL ESTOQUE (24/09). Sus DOS guardias (su referencia de esgrima): la de siempre, en garde de ataque, y
	# la DEFENSIVA mientras dura En guardia ('guardia_estoque_def', mas baja y con la hoja pegada). Sus
	# golpes: 'estocada_estoque' el fondo (basico, Paso ligero, Punzada al nervio), 'estocada_honda' la
	# Penetrante, 'finta_estoque' amago + fondo (Fintas, una por golpe), 'pinchazo_estoque' el pinchazo corto
	# sin fondo de la Danza (uno por golpe, avanzando) y 'ponerse_en_guardia' el gesto de En guardia.
	# Sus impactos, en CombatFX.IMPACTO_ANIM_MAPA: retocar una = retocar su impacto.
	{"n": "guardia_estoque", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_estoque_and", "loop": true, "fps": 8.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_estoque_cor", "loop": true, "fps": 11.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_estoque_def", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "desenvainar_estoque", "loop": false, "fps": 22.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "estocada_estoque", "loop": false, "fps": 22.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "estocada_honda", "loop": false, "fps": 20.0, "dirs": 8, "marcos": 12, "ultimo": true},
	{"n": "finta_estoque", "loop": false, "fps": 22.0, "dirs": 8, "marcos": 12, "ultimo": true},
	{"n": "pinchazo_estoque", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 7, "ultimo": true},
	{"n": "ponerse_en_guardia", "loop": false, "fps": 12.0, "dirs": 8, "marcos": 8, "ultimo": true},
	# LA ESPADA CORTA (25/09): con una ('_espada'), con dos ('_espada2', y '_izq' si pega la izquierda) y con
	# escudo ('_esc'). Sus impactos, en CombatFX.IMPACTO_ANIM_MAPA: retocar una = retocar su impacto.
	{"n": "guardia_espada", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_espada_and", "loop": true, "fps": 8.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_espada_cor", "loop": true, "fps": 11.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "desenvainar_espada", "loop": false, "fps": 22.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "tajo_espada", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "reves_espada", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "barrido_espada", "loop": false, "fps": 20.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "tajo_bajo_espada", "loop": false, "fps": 20.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "tajo_paso_espada", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 7, "ultimo": true},
	{"n": "defensa_espada", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_espada2", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_espada2_and", "loop": true, "fps": 8.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_espada2_cor", "loop": true, "fps": 11.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "desenvainar_espada2", "loop": false, "fps": 22.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "tajo_espada2", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "tajo_espada2_izq", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "reves_espada2", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "reves_espada2_izq", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "barrido_espada2", "loop": false, "fps": 20.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "barrido_espada2_izq", "loop": false, "fps": 20.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "tajo_bajo_espada2", "loop": false, "fps": 20.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "tajo_bajo_espada2_izq", "loop": false, "fps": 20.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "tajo_paso_espada2", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 7, "ultimo": true},
	{"n": "tajo_paso_espada2_izq", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 7, "ultimo": true},
	{"n": "defensa_espada2", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_espada_esc", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_espada_and_esc", "loop": true, "fps": 8.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_espada_cor_esc", "loop": true, "fps": 11.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "desenvainar_espada_esc", "loop": false, "fps": 22.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "tajo_espada_esc", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "reves_espada_esc", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "barrido_espada_esc", "loop": false, "fps": 20.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "tajo_bajo_espada_esc", "loop": false, "fps": 20.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "tajo_paso_espada_esc", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 7, "ultimo": true},
	# LA MAZA PEQUEÑA (26/09): con una ('_maza'), con dos ('_maza2', y '_izq' si pega la izquierda) y con escudo
	# ('_maza_esc'). Todas en _pose_maza. El Aplastamiento solo va con escudo; con dos no hay.
	{"n": "guardia_maza", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_maza_and", "loop": true, "fps": 8.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_maza_cor", "loop": true, "fps": 11.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "desenvainar_maza", "loop": false, "fps": 22.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "mazazo_maza", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "rompe_maza", "loop": false, "fps": 20.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "culatazo_maza", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 7, "ultimo": true},
	{"n": "demoledor_maza", "loop": false, "fps": 18.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "aliento_maza", "loop": false, "fps": 12.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "muro_maza", "loop": false, "fps": 16.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "defensa_maza", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "aplasta_maza", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "guardia_maza2", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_maza2_and", "loop": true, "fps": 8.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_maza2_cor", "loop": true, "fps": 11.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "desenvainar_maza2", "loop": false, "fps": 22.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "mazazo_maza2", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "mazazo_maza2_izq", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "rompe_maza2", "loop": false, "fps": 20.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "rompe_maza2_izq", "loop": false, "fps": 20.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "culatazo_maza2", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 7, "ultimo": true},
	{"n": "culatazo_maza2_izq", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 7, "ultimo": true},
	{"n": "demoledor_maza2", "loop": false, "fps": 18.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "aliento_maza2", "loop": false, "fps": 12.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "muro_maza2", "loop": false, "fps": 16.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "defensa_maza2", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_maza_esc", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_maza_and_esc", "loop": true, "fps": 8.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_maza_cor_esc", "loop": true, "fps": 11.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "desenvainar_maza_esc", "loop": false, "fps": 22.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "mazazo_maza_esc", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "rompe_maza_esc", "loop": false, "fps": 20.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "culatazo_maza_esc", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 7, "ultimo": true},
	{"n": "demoledor_maza_esc", "loop": false, "fps": 18.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "aplasta_maza_esc", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "aliento_maza_esc", "loop": false, "fps": 12.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "muro_maza_esc", "loop": false, "fps": 16.0, "dirs": 8, "marcos": 8, "ultimo": true},
	# LA ESPADA LARGA (25/09, PoseLarga): sin escudo ('_larga') y con el ('_larga_esc').
	# EL BASTON (26/09, PoseBaston): cruzado en diagonal a dos manos, y sus habilidades.
	{"n": "guardia_baston", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_baston_and", "loop": true, "fps": 8.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_baston_cor", "loop": true, "fps": 11.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "desenvainar_baston", "loop": false, "fps": 22.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "defensa_baston", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "golpe_baston", "loop": false, "fps": 20.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "bastonazo_baston", "loop": false, "fps": 20.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "sello_baston", "loop": false, "fps": 16.0, "dirs": 8, "marcos": 12, "ultimo": true},
	{"n": "viento_baston", "loop": false, "fps": 16.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "foco_baston", "loop": false, "fps": 12.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "velo_baston", "loop": false, "fps": 12.0, "dirs": 8, "marcos": 10, "ultimo": true},
	# LA FLORITURA DE LA VARITA (26/09, PoseBaston): la izquierda con la varita; la derecha en la guardia de lo que lleve.
	{"n": "floritura", "loop": false, "fps": 16.0, "dirs": 8, "marcos": 12, "ultimo": true},
	{"n": "floritura_daga", "loop": false, "fps": 16.0, "dirs": 8, "marcos": 12, "ultimo": true},
	{"n": "floritura_estoque", "loop": false, "fps": 16.0, "dirs": 8, "marcos": 12, "ultimo": true},
	{"n": "floritura_espada", "loop": false, "fps": 16.0, "dirs": 8, "marcos": 12, "ultimo": true},
	{"n": "floritura_larga", "loop": false, "fps": 16.0, "dirs": 8, "marcos": 12, "ultimo": true},
	{"n": "floritura_maza", "loop": false, "fps": 16.0, "dirs": 8, "marcos": 12, "ultimo": true},
	{"n": "guardia_larga", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_larga_and", "loop": true, "fps": 8.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_larga_cor", "loop": true, "fps": 11.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "desenvainar_larga", "loop": false, "fps": 22.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "tajo_larga", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "rota_larga", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "pesado_larga", "loop": false, "fps": 20.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "desarme_larga", "loop": false, "fps": 20.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "estocada_larga", "loop": false, "fps": 22.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "voto_larga", "loop": false, "fps": 14.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "voz_larga", "loop": false, "fps": 12.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "defensa_larga", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_larga_esc", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_larga_and_esc", "loop": true, "fps": 8.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_larga_cor_esc", "loop": true, "fps": 11.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "desenvainar_larga_esc", "loop": false, "fps": 22.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "tajo_larga_esc", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "rota_larga_esc", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "pesado_larga_esc", "loop": false, "fps": 20.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "desarme_larga_esc", "loop": false, "fps": 20.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "estocada_larga_esc", "loop": false, "fps": 22.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "voto_larga_esc", "loop": false, "fps": 14.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "voz_larga_esc", "loop": false, "fps": 12.0, "dirs": 8, "marcos": 8, "ultimo": true},
	# LAS DE ESCUDO (25/09, PoseLarga), con cualquier arma de una mano.
	{"n": "golpe_escudo", "loop": false, "fps": 22.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "embestida_escudo", "loop": false, "fps": 20.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "provoca_escudo", "loop": false, "fps": 14.0, "dirs": 8, "marcos": 12, "ultimo": true},
	{"n": "amparo_escudo", "loop": false, "fps": 14.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "rodela_escudo", "loop": false, "fps": 14.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "carne_escudo", "loop": false, "fps": 12.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "escolta_escudo", "loop": false, "fps": 16.0, "dirs": 8, "marcos": 8, "ultimo": true},
	# LA POSTURA DE DEFENSA (el Defender, 24/09: "se nos olvido en todas las armas"). Una por combinacion;
	# MunecoJugador elige cual ('defensa_N' -> la suya) y se queda en ella hasta su turno.
	{"n": "defensa_1m", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "defensa_escudo", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "defensa_2m", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "defensa_daga", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "defensa_estoque", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	# Y las mismas CON ESCUDO (el escudo delante, ver _pose): MunecoJugador las pone si lleva escudo.
	{"n": "guardia_estoque_esc", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_estoque_and_esc", "loop": true, "fps": 8.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_estoque_cor_esc", "loop": true, "fps": 11.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "guardia_estoque_def_esc", "loop": true, "fps": 4.0, "dirs": 8, "marcos": 8, "ultimo": false},
	{"n": "desenvainar_estoque_esc", "loop": false, "fps": 22.0, "dirs": 8, "marcos": 8, "ultimo": true},
	{"n": "estocada_estoque_esc", "loop": false, "fps": 22.0, "dirs": 8, "marcos": 10, "ultimo": true},
	{"n": "estocada_honda_esc", "loop": false, "fps": 20.0, "dirs": 8, "marcos": 12, "ultimo": true},
	{"n": "finta_estoque_esc", "loop": false, "fps": 22.0, "dirs": 8, "marcos": 12, "ultimo": true},
	{"n": "pinchazo_estoque_esc", "loop": false, "fps": 24.0, "dirs": 8, "marcos": 7, "ultimo": true},
	{"n": "ponerse_en_guardia_esc", "loop": false, "fps": 12.0, "dirs": 8, "marcos": 8, "ultimo": true},
	# 'ancla': la unica direccion que se hornea de una anim de 'dirs': 1. Encaje y muerte van al
	# NORTE (4, de espaldas): en combate el jugador mira a los enemigos, no a la camara. Sin 'ancla'
	# la de una direccion es la 0 (sur), que es lo que valia cuando "se te veia de frente".
	{"n": "encaje", "loop": false, "fps": 18.0, "dirs": 1, "ancla": 4, "marcos": 4, "ultimo": true},
	{"n": "muerte", "loop": false, "fps": 10.0, "dirs": 1, "ancla": 4, "marcos": 8, "ultimo": true},
	{"n": "cadaver", "loop": false, "fps": 1.0, "dirs": 8, "marcos": 1, "ultimo": false},
	# LAS FAENAS de recolectar (ver scripts/world/faena.gd). UNA sola direccion, el ESTE (2): el
	# personaje se coloca siempre a un lado del recurso, y el otro lado es este mismo dibujo VOLTEADO
	# (idea del jefe: asi no se dibujan ocho direcciones de cada faena). De lado es ademas donde mejor
	# se lee un golpe de arriba abajo: el arco entero cae en el plano de la pantalla.
	# 'picar': 0 guardia, 1-3 alzar (los fija la CARGA del minijuego), 4-7 descarga (impacto en el 6).
	{"n": "picar", "loop": false, "fps": 14.0, "dirs": 1, "ancla": 2, "marcos": 8, "ultimo": true},
	# 'talar': 0 remate (= el 7, para que empalme), 1-3 armar el hachazo a la derecha, 4-7 el barrido
	# lateral hasta el tronco (impacto en el 6). Ver _pose_talar.
	{"n": "talar", "loop": false, "fps": 14.0, "dirs": 1, "ancla": 2, "marcos": 8, "ultimo": true},
	# 'segar': agachado, la mano izquierda sujeta la mata y la derecha da el tajo corto con la hoz.
	# Mismo reparto que talar (0 = 7 remate, 1-3 armar, 4-7 tajo con el corte en el 6).
	{"n": "segar", "loop": false, "fps": 16.0, "dirs": 1, "ancla": 2, "marcos": 8, "ultimo": true},
	# 'extraer': de rodillas junto al cadaver, la izquierda apoyada en el cuerpo y la derecha metiendo
	# el cuchillo de arriba abajo. Mismo reparto (0 = 7 remate, 1-3 alzar, 4-7 el corte en el 6).
	{"n": "extraer", "loop": false, "fps": 16.0, "dirs": 1, "ancla": 2, "marcos": 8, "ultimo": true},
]

# Las faenas, por su nombre base. Las capas que se ven "envainadas" (la espada a la cadera) tambien
# salen en ellas, y cada herramienta en la mano sale SOLO en la suya (ver ArmaSprites.HERRAMIENTA_ANIM).
const FAENAS := ["picar", "talar", "segar", "extraer"]
# En que fotograma de cada faena empieza la DESCARGA y en cual pega. La faena arranca la animacion
# desde el primero al soltar el golpe, y del segundo sale cuando saltan las esquirlas.
const FAENA_DESCARGA := {"picar": 4, "talar": 4, "segar": 4, "extraer": 4}
const FAENA_IMPACTO := {"picar": 6, "talar": 6, "segar": 6, "extraer": 6}
# Las que se ARMAN CON LA CARGA del minijuego (el pico sube mientras mantienes). Las demas van de
# COMPAS: tras cada golpe se vuelven a armar solas y esperan armadas al siguiente.
const FAENA_CARGA := ["picar"]


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
	# LAS DOS MANOS EN EL MANGO (24/09). Los brazos son rigidos y solo giran adelante-atras, asi que cada
	# mano se queda delante de SU hombro, a un palmo de la otra: el arma a dos manos, colgada del punto
	# medio, flotaba en el aire entre las dos ("las armas vuelan", el jefe). 'junta' (0..1) lleva las
	# manos (y medio codo) hacia el centro, hasta agarrar el mismo mango.
	var junta: float = clampf(float(pose.get("junta", 0.0)), 0.0, 1.0)

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
		# 'abre_izq' / 'abre_der' (25/09): el brazo gira TAMBIEN en horizontal sobre el hombro (positivo = la
		# mano hacia FUERA de su lado, negativo = cruza por delante del cuerpo). Sin esto la unica forma de
		# llevar la mano de lado era la torsion del tronco, y un tajo de 120 grados se quedaba en 40: la mano
		# de delante no barria nada ("el brazo se mueve a lo mucho 40 y el ataque es de ciento y pico").
		var ab: float = float(pose.get("abre_izq" if lado == 0 else "abre_der", 0.0))
		if not is_zero_approx(ab):
			for pk in [P_CODO_IZQ if lado == 0 else P_CODO_DER, P_MANO_IZQ if lado == 0 else P_MANO_DER]:
				p[pk] = _girar_xy(p[pk], hombro, -s * ab)
		# 'junta_izq' / 'junta_der': lo mismo pero de UNA mano (la guardia de la daga recoge la izquierda
		# junto al pecho y deja la derecha estirada).
		var jn: float = clampf(float(pose.get("junta_izq" if lado == 0 else "junta_der", junta)), 0.0, 1.0)
		if jn > 0.0:
			var mn: Vector3 = p[P_MANO_IZQ if lado == 0 else P_MANO_DER]
			var cd: Vector3 = p[P_CODO_IZQ if lado == 0 else P_CODO_DER]
			mn.x = lerpf(mn.x, s * JUNTA_X, jn)
			cd.x = lerpf(cd.x, s * HOMBRO.x * 0.55, jn * 0.6)
			p[P_MANO_IZQ if lado == 0 else P_MANO_DER] = mn
			p[P_CODO_IZQ if lado == 0 else P_CODO_DER] = cd

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
		"torsion": float(pose.get("torsion", 0.0)),
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


# Vuelta en PLANTA (los ejes X e Y) alrededor de un pivote: la del brazo que barre en horizontal ('abre_*').
static func _girar_xy(v: Vector3, pivote: Vector3, ang: float) -> Vector3:
	var dx: float = v.x - pivote.x
	var dy: float = v.y - pivote.y
	var c: float = cos(ang)
	var s: float = sin(ang)
	return Vector3(pivote.x + dx * c - dy * s, pivote.y + dx * s + dy * c, v.z)


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
	# 'z_torsion': la altura con la que se decide cuanto gira la pieza con la torsion. Por defecto la
	# suya; el ARMA EN LA MANO pasa la de las manos para girar ENTERA -- si no, el trozo del astil que
	# baja de la cadera giraba menos que el que agarras y el hacha salia doblada como un sable.
	var ang: float = ang_en(esq, float(opts.get("z_torsion", local.z)))
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
	return profundidad_de(esq, p)


# Lo mismo para un punto suelto (p. ej. el MEDIO de un arma a dos manos, que no es un punto del esqueleto).
static func profundidad_de(esq: Dictionary, p: Vector3) -> float:
	return Vector2(p.x, p.y).rotated(ang_en(esq, p.z)).y


# EL GIRO EN PLANTA DE UNA PIEZA, contando la TORSION (girar el tronco sobre la cadera con los pies
# plantados: el hachazo lateral de 'talar').
#
# POR QUE AQUI Y NO GIRANDO LOS PUNTOS en 'montar', como 'inclina'. Porque el pecho es una ELIPSE ancha
# de hombro a hombro (CuerpoSprites.R_TORSO: 8,8 de ancho y 5,6 de fondo): girando solo los puntos, al
# torcer el tronco tres cuartos de vuelta los hombros se quedaban FUERA del pecho, que seguia de frente.
# Girando la pieza entera al proyectarla -- posicion Y forma --, el pecho, los brazos, la cabeza, el
# pelo, la armadura y el arma giran juntos, y sin tocar ni una capa: todas pasan por aqui.
#
# Cuanto gira cada pieza sale de su ALTURA: nada por debajo de la cadera (las piernas se quedan
# plantadas), todo por encima del pecho, y un tramo corto entre medias para que la cintura no se parta.
const TORSION_TRAMO := 4.5   # de la cadera (z 24) al pecho (z 28,5)

static func ang_en(esq: Dictionary, z: float) -> float:
	var ang: float = float(esq["ang"])
	var tor: float = float(esq.get("torsion", 0.0))
	if is_zero_approx(tor):
		return ang
	var base: float = CADERA.z * float(esq.get("alto", 1.0))
	return ang + tor * clampf((z - base) / TORSION_TRAMO, 0.0, 1.0)


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
			# "mano": empuñada. A dos manos el agarre es el punto medio de las dos manos, y el eje va
			# del HOMBRO derecho a la mano: la palanca larga (hombro->mano) barre un arco mucho mas
			# amplio que el antebrazo (codo->mano), asi el hachazo se lee de arriba abajo y no como un
			# meneo corto. Como brazo_izq == brazo_der en el golpe_2m, esa recta sigue pasando por los
			# dos puños, no se despega del astil.
			var pose_a: Dictionary = esq.get("pose", {})
			if mano == 2:
				# CON 'junta' en la pose (las anims hechas para dos manos y las guardias): el agarre va en
				# las manos de verdad -- juntas, su punto medio; separadas (guardia, 0), la DERECHA -- y el
				# eje sale del medio de los hombros, que es de donde tiran los dos brazos. 'eje_2m' lo fija
				# a mano (la guardia: el arma APOYADA EN EL HOMBRO, su boceto del 24/09). Sin 'junta' (las
				# faenas, ya aprobadas asi) se queda como estaba.
				# EL BASTON (26/09): las manos SEPARADAS en el palo. Va de la derecha hacia la izquierda (y la
				# cabeza, mas alla), y 'palo' es lo que asoma por detras de la derecha: asi pasa por las dos manos.
				if pose_a.has("palo"):
					var d_palo: Vector3 = p[P_EMPUNADURA_IZQ] - p[P_EMPUNADURA_DER]
					if d_palo.length() < 0.5:
						d_palo = Vector3(0.0, 0.3, 1.0)
					d_palo = d_palo.normalized()
					# En los golpes el palo va a donde diga 'eje_2m', por el MEDIO de las manos; 'eje_k' (0..1) mezcla
					# desde el de la guardia (el de las manos) para que no salte al empezar ni al acabar.
					var base_palo: Vector3 = p[P_EMPUNADURA_DER]
					var k_palo: float = clampf(float(pose_a.get("eje_k", 0.0)), 0.0, 1.0)
					if pose_a.has("eje_2m") and k_palo > 0.0:
						d_palo = d_palo.lerp((pose_a["eje_2m"] as Vector3).normalized(), k_palo).normalized()
						base_palo = base_palo.lerp(p[P_EMPUNADURA_DER].lerp(p[P_EMPUNADURA_IZQ], 0.5), k_palo)
					return {"empunadura": base_palo - d_palo * float(pose_a["palo"]), "eje": d_palo,
						"atras": false}
				var jun: float = float(pose_a.get("junta", -1.0))
				if jun >= 0.0:
					var agarre: Vector3 = p[P_EMPUNADURA_DER].lerp(p[P_EMPUNADURA_IZQ], 0.5 * jun)
					var hombros: Vector3 = (p[P_HOMBRO_DER] + p[P_HOMBRO_IZQ]) * 0.5
					var eje2: Vector3 = agarre - hombros
					if pose_a.has("eje_2m"):
						eje2 = pose_a["eje_2m"]
					return {"empunadura": agarre, "eje": eje2.normalized(), "atras": false}
				var medio: Vector3 = p[P_EMPUNADURA_DER].lerp(p[P_EMPUNADURA_IZQ], 0.5)
				return {"empunadura": medio,
					"eje": (p[P_MANO_DER] - p[P_HOMBRO_DER]).normalized(), "atras": false}
			var e: Vector3 = p[P_EMPUNADURA_DER] if mano == 0 else p[P_EMPUNADURA_IZQ]
			var pu: Vector3 = p[P_PUNTA_DER] if mano == 0 else p[P_PUNTA_IZQ]
			var eje1: Vector3 = (pu - e).normalized()
			# LA MUÑECA (24/09): el arma iba siempre en la linea del antebrazo, asi que con la mano a la
			# cintura la hoja apuntaba al suelo. 'muneca' la levanta hacia arriba (radianes): la guardia
			# de su boceto, la hoja en diagonal hacia arriba y hacia delante.
			# EL AGARRE AL REVES (la daga, 24/09): 'eje_der' / 'eje_izq' fijan hacia donde va la hoja de esa
			# mano, en el sistema del cuerpo (como 'eje_2m'). Hoja hacia abajo = la daga agarrada al reves.
			var clave_eje: String = "eje_der" if mano == 0 else "eje_izq"
			if pose_a.has(clave_eje):
				return {"empunadura": e, "eje": (pose_a[clave_eje] as Vector3).normalized(), "atras": false}
			var mu: float = float(pose_a.get("muneca", 0.0))
			if not is_zero_approx(mu):
				eje1 = Vector3(eje1.x, eje1.y * cos(mu) - eje1.z * sin(mu),
					eje1.z * cos(mu) + eje1.y * sin(mu)).normalized()
			return {"empunadura": e, "eje": eje1, "atras": false}


# Donde va el ESCUDO. Mismo espiritu que agarre_arma (mismas claves 'empunadura'/'eje', para poder
# reusar tal cual su interpolacion de 'sac' al desenvainar), pero mas simple: el escudo solo tiene
# dos sitios -- "espalda" (envainado, comparte P_ESPALDA con las armas a dos manos: nunca chocan,
# equipped_off es null si el arma principal es a dos manos) y "mano" (el antebrazo izquierdo,
# SIEMPRE -- un escudo nunca va en la mano principal). La capa EscudoSprites es la unica que llama
# aqui.
static func agarre_escudo(esq: Dictionary, estado: String) -> Dictionary:
	var p: Dictionary = esq["puntos"]
	if estado == "espalda":
		return {"empunadura": p[P_ESPALDA], "eje": (p[P_ESPALDA_PUNTA] - p[P_ESPALDA]).normalized()}
	# "mano": en el antebrazo, de pie sobre el (eje casi vertical, un pelo hacia delante).
	return {"empunadura": p[P_EMPUNADURA_IZQ], "eje": Vector3(0.0, 0.15, 1.0).normalized()}


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


# La direccion en la que se hornea una anim de una sola direccion (0 = sur salvo que la fila diga
# otra). La usan el horno (CapaJugador.generar), el fallback de MunecoJugador y el visor.
static func ancla_de(base: String) -> int:
	return int(_anim(base).get("ancla", 0))


# Los fotogramas por segundo de una animacion. La faena lo necesita para saber cuanto tarda el pico en
# llegar desde que sueltas (ver FAENA_IMPACTO).
static func fps_de(base: String) -> float:
	return float(_anim(base).get("fps", 12.0))


static func _pose(anim: String, t: float) -> Dictionary:
	# EL BASTON y LA FLORITURA DE LA VARITA (PoseBaston): antes que nada ('floritura_espada' lleva "espada").
	if anim.contains("baston") or anim.begins_with("floritura"):
		var pb: Dictionary = PoseBaston.pose(anim, t)
		if not pb.is_empty():
			return pb
	# LA ESPADA LARGA y LAS DE ESCUDO (PoseLarga): antes que el '_esc' de abajo, que su guardia con escudo es otra.
	if anim.contains("_larga") or anim.ends_with("_escudo"):
		var pl: Dictionary = PoseLarga.pose(anim, t)
		if not pl.is_empty():
			return pl
	# EL ESTOQUE CON ESCUDO ('<anim>_esc'): la misma pose, pero la izquierda lleva el escudo DELANTE en vez
	# de ir alzada detras de la cabeza (con el escudo ahi arriba no se veia ni tenia sentido).
	if anim.ends_with("_esc"):
		var p: Dictionary = _pose(anim.trim_suffix("_esc"), t)
		p["brazo_izq"] = 1.0
		p["junta_izq"] = 0.3
		return p
	# LA MAZA PEQUEÑA: todas sus variantes salen de una funcion (ver _pose_maza).
	if anim.contains("_maza"):
		var pm: Dictionary = _pose_maza(anim, t)
		if not pm.is_empty():
			return pm
	# LA ESPADA CORTA: todas sus variantes salen de una funcion (ver _pose_espada).
	if anim.contains("espada"):
		var pe: Dictionary = _pose_espada(anim, t)
		if not pe.is_empty():
			return pe
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
		"guardia_2m": return _pose_guardia_2m(t)
		"guardia_2m_and": return _pose_guardia_2m_and(t)
		"guardia_2m_cor": return _pose_guardia_2m_cor(t)
		"desenvainar": return _pose_desenvainar(t)
		"desenvainar_2m": return _pose_desenvainar_2m(t)
		"encaje": return _pose_encaje(t)
		"muerte": return _pose_muerte(t)
		"picar": return _pose_picar(t)
		"talar": return _pose_talar(t)
		"segar": return _pose_segar(t)
		"extraer": return _pose_extraer(t)
		"en_alto": return _pose_en_alto(t)
		"tajo_2m": return _pose_tajo_2m(t)
		"clavar": return _pose_clavar(t)
		"molinete": return _pose_molinete(t)
		"barrido_2m": return _pose_barrido_2m(t)
		"grito": return _pose_grito(t)
		"hendedura_2m": return _pose_hendedura_2m(t)
		"hachazo_2m": return _pose_hachazo_2m(t)
		"carniceria_2m": return _pose_carniceria_2m(t)
		"gancho_2m": return _pose_gancho_2m(t)
		"mirada": return _pose_mirada(t)
		"guardia_daga": return _pose_guardia_daga(t)
		"guardia_daga_and": return _pose_guardia_daga_and(t)
		"guardia_daga_cor": return _pose_guardia_daga_cor(t)
		"desenvainar_daga": return _pose_desenvainar_daga(t)
		"tajo_daga": return _pose_tajo_daga(t, false)
		"tajo_daga_izq": return _pose_tajo_daga(t, true)
		"tajo_daga_solo": return _pose_tajo_daga_solo(t)
		"punalada_daga": return _pose_punalada_daga(t, false)
		"punalada_daga_izq": return _pose_punalada_daga(t, true)
		"lanzar_humo": return _pose_lanzar_humo(t)
		"afilar_veneno": return _pose_afilar_veneno(t)
		"guardia_estoque": return _pose_guardia_estoque(t)
		"guardia_estoque_and": return _pose_guardia_estoque_and(t)
		"guardia_estoque_cor": return _pose_guardia_estoque_cor(t)
		"guardia_estoque_def": return _pose_guardia_estoque_def(t)
		"desenvainar_estoque": return _pose_desenvainar_estoque(t)
		"estocada_estoque": return _pose_estocada_estoque(t)
		"estocada_honda": return _pose_estocada_honda(t)
		"finta_estoque": return _pose_finta_estoque(t)
		"pinchazo_estoque": return _pose_pinchazo_estoque(t)
		"ponerse_en_guardia": return _pose_ponerse_en_guardia(t)
		"defensa_1m": return _pose_defensa_1m(t)
		"defensa_escudo": return _pose_defensa_escudo(t)
		"defensa_2m": return _pose_defensa_2m(t)
		"defensa_daga": return _pose_defensa_daga(t)
		"defensa_estoque": return _pose_defensa_estoque(t)
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


# EL GOLPE CON LA MANO IZQUIERDA. Espejo de _pose_golpe: el arco grande se lo lleva el brazo
# izquierdo y el derecho hace de acompañante. Es la mano "mala" del dual -- se alterna con la
# principal golpe a golpe (ver player.gd._elegir_golpe y AbilityData.plan_golpes).
#
# Y CON 'rumbo': el brazo malo es el que queda en el lado LEJANO a la camara (mirando al este, el
# costado izquierdo mira al norte), asi que el tajo pasaba por detras del tronco y la daga -- que es
# corta -- se escorzaba a nada. Un cuarto de radian de torsion lleva el hombro que golpea hacia la
# camara y el arma se ve. Rampado (0 en las puntas) para empalmar con la guardia.
static func _pose_golpe_izq(t: float) -> Dictionary:
	var brazo_keys := [[0.0, 0.0], [0.30, -2.35], [0.45, -2.15], [0.62, 0.95], [0.80, 0.55], [1.0, 0.0]]
	var avance_keys := [[0.0, 0.0], [0.30, -1.3], [0.45, -1.0], [0.62, 3.6], [0.80, 2.3], [1.0, 0.0]]
	var inclina_keys := [[0.0, 0.05], [0.30, -0.16], [0.45, -0.12], [0.62, 0.34], [0.80, 0.22], [1.0, 0.05]]
	var rumbo_keys := [[0.0, 0.0], [0.30, 0.20], [0.62, 0.34], [1.0, 0.0]]
	return {"brazo_izq": SpriteLienzo.tramos(t, brazo_keys),
		"brazo_der": -0.08 * SpriteLienzo.tramos(t, brazo_keys),
		"avance": SpriteLienzo.tramos(t, avance_keys),
		"inclina": SpriteLienzo.tramos(t, inclina_keys),
		"rumbo": SpriteLienzo.tramos(t, rumbo_keys),
		"agacha": 0.10}


# EL TAJO A DOS MANOS (hacha grande / martillo grande / mandoble). Los DOS brazos van juntos, con
# las manos en el astil, y el golpe cae de arriba abajo: se arma alto y se descarga.
#
# EL PICO DEL WINDUP SE QUEDA EN -1.90 y no en el -2.35 del golpe a una mano: un arma a dos manos es
# la mas larga del juego y, levantada del todo en diagonal, se salia del lienzo (lo canta
# hornear_sprites._avisar_recortes). El 'avance' tambien va mas corto por lo mismo.
#
# LA DESCARGA, EN CAMBIO, BAJA HASTA CASI VERTICAL (+1.45): el hachazo tiene que LEERSE de arriba
# abajo. Con el +0.75 de antes el brazo se quedaba a mitad y el arco salia "de reves" (arma detras,
# por el z de _ordenar, + brazo que no acaba de bajar). Abajo-delante el arma NO recorta (compacto);
# el limite del horno es el extremo ATRAS-ARRIBA.
#
# Y UN 'rumbo' PEQUEÑO, RAMPADO: mirando al sur el plano del tajo queda de canto a la camara y se
# escorza a nada (misma trampa que _pose_muerte). Un cuarto de radian largo lo saca de ahi. Rampado
# (0 en las puntas) para no dar un tiron al entrar/salir desde guardia.
static func _pose_golpe_2m(t: float) -> Dictionary:
	# EL ARCO VA POR ENCIMA DE LA CABEZA (su abanico del 24/09): atras-arriba, arriba, delante, abajo. Se
	# escribia de -1.90 a +1.45, y eso pasa por el 0 -- el brazo COLGANDO --: el arma cruzaba por abajo,
	# entre las piernas. Pasado de pi (4.0 = -2.28) el mismo giro sube por detras y baja por delante.
	var brazo_keys := [[0.0, 0.40], [0.25, 3.9], [0.38, 4.0], [0.5, 3.3], [0.6, 2.6], [0.7, 1.9],
		[0.8, 1.4], [0.9, 1.1], [1.0, 0.40]]
	var avance_keys := [[0.0, 0.0], [0.32, -0.8], [0.50, -0.5], [0.68, 2.0], [0.85, 1.2], [1.0, 0.0]]
	var inclina_keys := [[0.0, 0.06], [0.32, -0.12], [0.50, -0.08], [0.68, 0.30], [0.85, 0.20], [1.0, 0.06]]
	# El golpe cae a TU DERECHA (rumbo mas grande en la descarga): mirando al norte, delante de los pies es
	# detras del cuerpo para la camara, y el arma desaparecia (antes se forzaba por encima de todo, y
	# entonces se veia pintada ENCIMA del personaje).
	var rumbo_keys := [[0.0, 0.0], [0.32, 0.22], [0.68, 0.85], [0.85, 0.7], [1.0, 0.0]]
	var b: float = SpriteLienzo.tramos(t, brazo_keys)
	return {"brazo_der": b, "brazo_izq": b,
		"avance": SpriteLienzo.tramos(t, avance_keys),
		"inclina": SpriteLienzo.tramos(t, inclina_keys),
		"rumbo": SpriteLienzo.tramos(t, rumbo_keys),
		"agacha": 0.12, "junta": 1.0}


# PICAR UNA VETA. A dos manos, de arriba abajo, siempre mirando al este (ver ANIMS). Sus ocho
# fotogramas NO se reproducen de corrido: la faena FIJA el 0-3 segun lo que llevas cargado (el pico
# sube mientras mantienes ESPACIO) y al soltar arranca desde el 4, que es la descarga.
#
# EL GOLPE ACABA ABAJO Y DELANTE (+0.95): la veta esta al pie de la pared, a ras de suelo, y el pico
# tiene que llegarle ahi. Con +1.15 (y no digamos el +1.45 del hachazo de combate) bajaba tan
# empinado que se clavaba en el suelo delante de los pies, a medio camino de la veta.
# 'rumbo' FIJO y hacia la camara (+0.28): de perfil puro el brazo lejano queda escondido detras del
# cercano y el mango parece salir de una sola mano.
static func _pose_picar(t: float) -> Dictionary:
	# EN ALTO DE VERDAD (-2.75, las manos por encima de la coronilla). Con -2.10 el pico se quedaba a la
	# altura de la cabeza y, con la camara a 45 grados y la cabeza tan grande, el pelo lo tapaba entero:
	# no se leia que lo levantara. Y en reposo va por DELANTE (+0.5), en guardia, no colgando a los pies.
	var brazo_keys := [[0.0, 0.50], [0.143, -0.70], [0.286, -1.90], [0.429, -2.75],
		[0.571, -2.10], [0.714, -0.10], [0.857, 0.95], [1.0, 0.80]]
	var inclina_keys := [[0.0, 0.10], [0.429, -0.18], [0.571, -0.10], [0.857, 0.34], [1.0, 0.28]]
	var avance_keys := [[0.0, 0.0], [0.429, -0.8], [0.571, -0.4], [0.857, 1.6], [1.0, 1.2]]
	var agacha_keys := [[0.0, 0.10], [0.429, 0.04], [0.857, 0.22], [1.0, 0.18]]
	var b: float = SpriteLienzo.tramos(t, brazo_keys)
	return {"brazo_der": b, "brazo_izq": b,
		"inclina": SpriteLienzo.tramos(t, inclina_keys),
		"avance": SpriteLienzo.tramos(t, avance_keys),
		"agacha": SpriteLienzo.tramos(t, agacha_keys),
		# Pies abiertos, el de delante adelantado: se planta para dar el golpe.
		"paso": 0.18, "rumbo": 0.28}


# TALAR. El hachazo es LATERAL y a dos manos, "desde la derecha hacia el arbol" (el jefe): los brazos
# van al frente, casi en horizontal, y lo que barre es el TRONCO girando sobre la cadera ('torsion',
# ver ang_en) con los pies plantados. Los brazos solos no pueden: son rigidos y solo giran hacia
# delante y hacia atras.
#
# Se arma a la DERECHA (+torsion) y no a la izquierda: mirando al este, el costado derecho es el que
# da a la camara, asi que el hacha armada queda a la vista en vez de escondida detras del cuerpo.
# El fotograma 0 y el 7 son la misma pose (el remate) para que el compas empalme: tras cada hachazo la
# faena vuelve a armar del 0 al 3 y espera ahi.
static func _pose_talar(t: float) -> Dictionary:
	# ARMADA, EL HACHA APUNTA A LA CAMARA Y ALGO HACIA ABAJO. Es cuestion de proyeccion y costo tres
	# intentos: con la camara a 45 grados, "hacia la camara" baja en pantalla y "hacia arriba" sube, asi
	# que un hacha armada a la altura del hombro (o mas alta) apuntando a la camara se ANULA y queda en
	# un muñon pegado a la cara. Por debajo de la horizontal las dos cosas suman y el hacha se ve
	# entera, apuntando abajo; el barrido la lleva en un cuarto de vuelta hasta el tronco.
	# Tampoco se arma pasado el cuarto de vuelta: de espaldas a la camara el cuerpo la tapa.
	var tor_keys := [[0.0, -0.30], [0.143, 0.45], [0.286, 1.10], [0.429, 1.45],
		[0.571, 1.40], [0.714, 0.65], [0.857, -0.15], [1.0, -0.30]]
	# El golpe a la altura de la CINTURA y con el astil algo caido: en horizontal puro y a la altura del
	# pecho, el hacha al frente se leia como alguien apuntando con un FUSIL.
	var brazo_keys := [[0.0, 1.05], [0.143, 1.10], [0.286, 1.15], [0.429, 1.15],
		[0.571, 1.15], [0.714, 1.15], [0.857, 1.12], [1.0, 1.05]]
	var b: float = SpriteLienzo.tramos(t, brazo_keys)
	return {"brazo_der": b, "brazo_izq": b,
		"torsion": SpriteLienzo.tramos(t, tor_keys),
		"inclina": 0.12, "agacha": 0.12, "paso": 0.22}


# SEGAR. Agachado de verdad junto a la mata: la mano IZQUIERDA la agarra (quieta, al frente y abajo) y
# la DERECHA da tajos cortos y bajos con la hoz, de su lado hacia el centro. El barrido lo hace una
# torsion PEQUEÑA del tronco, como el hachazo pero en corto: una hoz no se lanza, se tira.
#
# Mucho mas agachado que el sigilo (0,78 frente a 0,44) porque la hierba esta a ras de suelo, pero con
# la inclinacion CONTENIDA: echar mucho el tronco adelante saca la cabeza por delante del pecho y la
# silueta pasa a leerse como un ganso (ver _pose_sigilo).
static func _pose_segar(t: float) -> Dictionary:
	var tor_keys := [[0.0, -0.40], [0.143, 0.05], [0.286, 0.40], [0.429, 0.60],
		[0.571, 0.55], [0.714, 0.15], [0.857, -0.30], [1.0, -0.40]]
	var der_keys := [[0.0, 0.85], [0.143, 0.95], [0.286, 1.05], [0.429, 1.10],
		[0.571, 1.08], [0.714, 0.95], [0.857, 0.82], [1.0, 0.85]]
	# LOS PIES JUNTOS (paso 0,10). Las piernas son rigidas, no hay rodilla que doblar: lo unico que dice
	# "agachado" es la silueta aplastada, y con las piernas abiertas (0,34) eso se leia como una ZANCADA,
	# alguien corriendo. Juntas y bien aplastado (0,78) es una sentadilla.
	return {"brazo_der": SpriteLienzo.tramos(t, der_keys), "brazo_izq": 0.80,
		"torsion": SpriteLienzo.tramos(t, tor_keys),
		"agacha": 0.78, "inclina": 0.20, "paso": 0.10}


# ------------------------------------------------------------
#  LAS HABILIDADES A DOS MANOS (martillo y mandoble en el mapa, 24/09)
# ------------------------------------------------------------
# EL ARMA EN ALTO, cargando (Martillo de guerra, Tajo del verdugo: "que mantenga el martillo en alto
# hasta que golpea el suelo"). Los dos brazos arriba y un poco atras, el pecho abierto y los pies
# plantados; respira despacio para que se vea vivo mientras espera su turno. Un pelo de 'rumbo' para
# que el arma no quede de canto mirando al sur.
static func _pose_en_alto(t: float) -> Dictionary:
	return {"brazo_der": 4.03 + 0.04 * sin(TAU * t), "brazo_izq": 4.03 + 0.04 * sin(TAU * t),
		"inclina": -0.06, "agacha": 0.14, "bote": 0.25 * sin(TAU * t), "paso": 0.18, "rumbo": 0.35,
		"junta": 1.0}


# EL TAJO QUE BAJA DE ARRIBA: sale de 'en_alto' (su fotograma 0 es esa pose), coge un pelo mas de aire
# y lo baja todo de golpe hasta el suelo, "pum". Se queda ABAJO, cargado: no se recompone (eso lo hace
# la guardia al acabar el gesto), porque un golpe asi no rebota.
static func _pose_tajo_2m(t: float) -> Dictionary:
	# La bajada repartida en VARIOS fotogramas (de lado se veia arriba-detras y al siguiente ya en el
	# suelo), y cayendo a TU DERECHA (rumbo) para que al norte no se esconda detras del cuerpo.
	# Por ENCIMA de la cabeza (ver _pose_golpe_2m): de 4.03 (= en_alto) baja pasando por pi.
	var brazo_keys := [[0.0, 4.03], [0.15, 4.25], [0.32, 3.6], [0.45, 3.0], [0.57, 2.4],
		[0.68, 1.8], [0.78, 1.5], [1.0, 1.45]]
	var incl_keys := [[0.0, -0.06], [0.15, -0.14], [0.62, 0.36], [1.0, 0.32]]
	var agacha_keys := [[0.0, 0.14], [0.15, 0.10], [0.62, 0.34], [1.0, 0.30]]
	var avance_keys := [[0.0, 0.0], [0.15, -0.6], [0.62, 2.6], [1.0, 2.2]]
	var rumbo_keys := [[0.0, 0.35], [0.6, 0.85], [1.0, 0.8]]
	var b: float = SpriteLienzo.tramos(t, brazo_keys)
	return {"brazo_der": b, "brazo_izq": b,
		"inclina": SpriteLienzo.tramos(t, incl_keys),
		"agacha": SpriteLienzo.tramos(t, agacha_keys),
		"avance": SpriteLienzo.tramos(t, avance_keys),
		"rumbo": SpriteLienzo.tramos(t, rumbo_keys), "paso": 0.2, "junta": 1.0}


# CLAVAR EL MARTILLO A TUS PIES (el Temblor, su dibujo del 23/09: el mango vertical y la cabeza en el
# suelo). Lo sube y lo hunde de canto delante de los pies, agachandose con el: los brazos acaban casi
# colgando, asi que el eje del arma (hombro -> mano) apunta al suelo.
static func _pose_clavar(t: float) -> Dictionary:
	# Lo SUBE POR DELANTE hasta arriba y lo hunde otra vez por delante (nunca por abajo-atras).
	var brazo_keys := [[0.0, 0.40], [0.25, 2.6], [0.4, 2.9], [0.52, 2.2], [0.62, 1.4],
		[0.72, 0.5], [0.8, 0.22], [1.0, 0.2]]
	var agacha_keys := [[0.0, 0.10], [0.4, 0.05], [0.72, 0.40], [1.0, 0.38]]
	var incl_keys := [[0.0, 0.06], [0.25, -0.12], [0.72, 0.30], [1.0, 0.28]]
	var b: float = SpriteLienzo.tramos(t, brazo_keys)
	# Clavado a TU DERECHA (rumbo): delante de los pies, mirando al norte, quedaba escondido detras.
	return {"brazo_der": b, "brazo_izq": b,
		"agacha": SpriteLienzo.tramos(t, agacha_keys),
		"inclina": SpriteLienzo.tramos(t, incl_keys), "paso": 0.22, "rumbo": 0.8, "junta": 1.0}


# EL MOLINETE: la espada EXTENDIDA DELANTE, a dos manos y un pelo por debajo de la horizontal, las
# piernas abiertas. Solo la postura: el giro (dos vueltas) lo da el juego pasando por las ocho
# direcciones, asi la cara y el orden de las piezas estan bien en cada una.
static func _pose_molinete(_t: float) -> Dictionary:
	return {"brazo_der": 1.3, "brazo_izq": 1.3, "agacha": 0.18, "inclina": 0.10, "paso": 0.24,
		"junta": 1.0}


# EL SEGAR: el arma extendida al frente y baja, y el TRONCO la barre (torsion, como talar): primero
# hacia TU derecha y luego de vuelta a la izquierda. Dos barridos, uno por golpe.
static func _pose_barrido_2m(t: float) -> Dictionary:
	var tor_keys := [[0.0, -1.0], [0.4, 1.0], [0.5, 1.05], [0.9, -1.0], [1.0, -1.0]]
	return {"brazo_der": 1.25, "brazo_izq": 1.25,
		"torsion": SpriteLienzo.tramos(t, tor_keys),
		"agacha": 0.24, "inclina": 0.14, "paso": 0.24, "junta": 1.0}


# EL GRITO DE GUERRA: levanta el arma a dos manos, echa el pecho atras y aguanta TEMBLANDO mientras
# grita.
static func _pose_grito(t: float) -> Dictionary:
	var brazo_keys := [[0.0, 0.40], [0.35, 2.9], [1.0, 2.9]]
	var incl_keys := [[0.0, 0.08], [0.35, -0.22], [1.0, -0.20]]
	var tiembla: float = 0.0 if t < 0.35 else 0.35 * sin(t * 40.0)
	var b: float = SpriteLienzo.tramos(t, brazo_keys)
	return {"brazo_der": b, "brazo_izq": b,
		"inclina": SpriteLienzo.tramos(t, incl_keys),
		"bote": tiembla, "agacha": 0.10, "paso": 0.25, "junta": 1.0}


# ------------------------------------------------------------
#  EL HACHA GRANDE (24/09): "el hacha hace golpes LATERALES" (el jefe). Parten todas de la guardia a dos
#  manos (guardia_2m: brazos a 0.40, junta) y los barridos los da el TRONCO (torsion), como el Segar.
# ------------------------------------------------------------
# LA HENDEDURA: sube el hacha por encima de la cabeza desde la guardia y la baja de golpe al suelo
# delante, y ahi se queda, hundida (como el tajo_2m, pero sin venir de la carga).
static func _pose_hendedura_2m(t: float) -> Dictionary:
	var brazo_keys := [[0.0, 0.40], [0.3, 3.9], [0.42, 4.1], [0.52, 3.3], [0.6, 2.2], [0.66, 1.6],
		[0.75, 1.42], [1.0, 1.45]]
	var incl_keys := [[0.0, 0.10], [0.42, -0.14], [0.66, 0.38], [1.0, 0.34]]
	var agacha_keys := [[0.0, 0.22], [0.42, 0.10], [0.66, 0.36], [1.0, 0.32]]
	var avance_keys := [[0.0, 0.0], [0.42, -0.8], [0.66, 2.4], [1.0, 2.0]]
	var rumbo_keys := [[0.0, 0.0], [0.42, 0.3], [0.66, 0.85], [1.0, 0.8]]
	var b: float = SpriteLienzo.tramos(t, brazo_keys)
	return {"brazo_der": b, "brazo_izq": b,
		"inclina": SpriteLienzo.tramos(t, incl_keys),
		"agacha": SpriteLienzo.tramos(t, agacha_keys),
		"avance": SpriteLienzo.tramos(t, avance_keys),
		"rumbo": SpriteLienzo.tramos(t, rumbo_keys), "paso": 0.26, "junta": 1.0}


# EL HACHAZO BRUTAL: se arma a la IZQUIERDA con todo el tronco torcido y el hacha un pelo alzada, y la
# suelta de lado a lado: lenta al arrancar, rapidisima al final (como su media luna, que va a s^2), y
# SE CLAVA al otro lado, quieta, antes de recomponerse. El barrido empieza en 0,45 (su impacto: el
# efecto sale en el golpe y le llega a cada uno al pasar).
static func _pose_hachazo_2m(t: float) -> Dictionary:
	var tor_keys := [[0.0, 0.0], [0.35, -1.3], [0.45, -1.35], [0.55, -0.95], [0.62, -0.1], [0.70, 1.25],
		[0.88, 1.25], [1.0, 1.0]]
	var brazo_keys := [[0.0, 0.40], [0.35, 1.7], [0.45, 1.75], [0.70, 1.3], [0.88, 1.25], [1.0, 1.2]]
	var incl_keys := [[0.0, 0.10], [0.45, -0.04], [0.70, 0.30], [1.0, 0.24]]
	var agacha_keys := [[0.0, 0.22], [0.45, 0.20], [0.70, 0.34], [1.0, 0.30]]
	var b: float = SpriteLienzo.tramos(t, brazo_keys)
	return {"brazo_der": b, "brazo_izq": b,
		"torsion": SpriteLienzo.tramos(t, tor_keys),
		"inclina": SpriteLienzo.tramos(t, incl_keys),
		"agacha": SpriteLienzo.tramos(t, agacha_keys), "paso": 0.32, "junta": 1.0}


# LA CARNICERIA: tres barridos (dcha, izda, dcha) y ninguno limpio: cada uno a una altura (como sus tres
# medias lunas, que van a 4, 11 y 6,5 de alto) y el cuerpo dando tumbos entre ellos. Cada golpe cae al
# ACABAR su barrido, a 0,2 s uno de otro (CombatFX.T_ENCADENADO): en 0,3 / 0,55 / 0,8 de la animacion.
static func _pose_carniceria_2m(t: float) -> Dictionary:
	var tor_keys := [[0.0, 0.0], [0.19, -1.05], [0.30, 1.05], [0.44, 1.0], [0.55, -1.05], [0.69, -1.0],
		[0.80, 1.05], [0.9, 0.9], [1.0, 0.5]]
	var brazo_keys := [[0.0, 0.40], [0.19, 1.2], [0.30, 1.15], [0.44, 1.65], [0.55, 1.55], [0.69, 1.3],
		[0.80, 1.35], [1.0, 1.1]]
	var incl_keys := [[0.0, 0.10], [0.30, 0.28], [0.44, 0.10], [0.55, 0.30], [0.69, 0.14], [0.80, 0.32],
		[1.0, 0.24]]
	var avance_keys := [[0.0, 0.0], [0.30, 1.2], [0.44, 0.4], [0.55, 1.6], [0.69, 0.8], [0.80, 2.0],
		[1.0, 1.4]]
	var b: float = SpriteLienzo.tramos(t, brazo_keys)
	return {"brazo_der": b, "brazo_izq": b,
		"torsion": SpriteLienzo.tramos(t, tor_keys),
		"inclina": SpriteLienzo.tramos(t, incl_keys),
		"avance": SpriteLienzo.tramos(t, avance_keys),
		"agacha": 0.26, "paso": 0.30, "junta": 1.0}


# EL DESGARRO: "extender hacia delante y luego tirar hacia nosotros" (el jefe). Echa el hacha atras un
# momento, la LANZA al frente estirandose entero (el cuerpo se va detras del arma) y, enganchado, TIRA:
# se echa hacia atras, el hacha baja y se recoge hacia el. El golpe (y el tiron) en 0,5: con el brazo
# estirado del todo, justo cuando engancha.
static func _pose_gancho_2m(t: float) -> Dictionary:
	var brazo_keys := [[0.0, 0.40], [0.2, 0.9], [0.38, 1.45], [0.5, 1.5], [0.68, 0.95], [0.82, 0.7],
		[1.0, 0.6]]
	var avance_keys := [[0.0, 0.0], [0.2, -1.0], [0.38, 3.4], [0.5, 3.8], [0.68, -1.4], [0.82, -1.8],
		[1.0, -1.2]]
	var incl_keys := [[0.0, 0.10], [0.2, -0.04], [0.45, 0.40], [0.5, 0.42], [0.68, -0.20], [0.82, -0.24],
		[1.0, -0.10]]
	var agacha_keys := [[0.0, 0.22], [0.45, 0.14], [0.68, 0.36], [1.0, 0.30]]
	var tor_keys := [[0.0, 0.0], [0.2, 0.25], [0.5, -0.1], [0.75, 0.35], [1.0, 0.2]]
	var b: float = SpriteLienzo.tramos(t, brazo_keys)
	return {"brazo_der": b, "brazo_izq": b,
		"avance": SpriteLienzo.tramos(t, avance_keys),
		"inclina": SpriteLienzo.tramos(t, incl_keys),
		"agacha": SpriteLienzo.tramos(t, agacha_keys),
		"torsion": SpriteLienzo.tramos(t, tor_keys), "paso": 0.34, "junta": 1.0}


# LA MIRADA ASESINA (Sed de sangre): no ataca. Baja la cabeza y se ENCORVA hacia delante como quien va a
# embestir, da medio paso, aprieta el hacha (la baja y la recoge) y RESPIRA fuerte, con un temblor de
# rabia contenida. Que no se quede tieso mirando (lo pidio el jefe). En guardia de dos manos todo el rato.
static func _pose_mirada(t: float) -> Dictionary:
	# Encorvado LO JUSTO: mas, y la cabeza (que es enorme) baja y tapa el hacha de la guardia.
	var incl_keys := [[0.0, 0.10], [0.3, 0.22], [0.85, 0.21], [1.0, 0.12]]
	var agacha_keys := [[0.0, 0.22], [0.3, 0.32], [0.85, 0.31], [1.0, 0.24]]
	var avance_keys := [[0.0, 0.0], [0.3, 1.3], [0.85, 1.2], [1.0, 0.2]]
	# A la altura de la guardia: mas abajo el hacha se escondia detras de las piernas.
	var brazo_keys := [[0.0, 0.40], [0.3, 0.46], [0.85, 0.46], [1.0, 0.40]]
	# La respiracion (dos golpes de aire) y el temblor, solo mientras aguanta encorvado.
	var dentro: float = clampf((t - 0.25) / 0.1, 0.0, 1.0) * clampf((0.95 - t) / 0.1, 0.0, 1.0)
	var respira: float = 0.5 * absf(sin(TAU * t * 2.0))
	var tiembla: float = 0.18 * sin(t * 55.0)
	var b: float = SpriteLienzo.tramos(t, brazo_keys) + 0.03 * sin(t * 55.0) * dentro
	return {"brazo_der": b, "brazo_izq": b,
		"inclina": SpriteLienzo.tramos(t, incl_keys) + 0.03 * respira * dentro,
		"agacha": SpriteLienzo.tramos(t, agacha_keys),
		"avance": SpriteLienzo.tramos(t, avance_keys),
		"bote": (respira + tiembla) * dentro, "paso": 0.36, "junta": 1.0,
		"eje_2m": GUARDIA_EJE_FRENTE}


# EXTRAER EL CRISTAL. De rodillas (mas bajo que segar: el cuerpo esta tirado en el suelo), el tronco
# echado sobre el cadaver y la izquierda apoyada en el. La derecha sube el cuchillo y lo mete de arriba
# abajo, en corto: es trabajo fino, no una puñalada. Un pelo de 'rumbo' hacia la camara para que la
# mano del cuchillo no quede tapada detras de la cabeza.
static func _pose_extraer(t: float) -> Dictionary:
	# RECORRIDO GRANDE (de 2,15 a 0,55): el cuchillo va en la linea del antebrazo -- no hay muñeca que
	# doblar --, asi que lo unico que lo hace bajar a cortar es el brazo entero bajando. Con un vaiven
	# corto (0,7-1,4) el cuchillo se quedaba casi en horizontal y parecia que APUNTABA al cadaver.
	var der_keys := [[0.0, 0.62], [0.143, 1.15], [0.286, 1.75], [0.429, 2.15],
		[0.571, 2.05], [0.714, 1.30], [0.857, 0.55], [1.0, 0.62]]
	var incl_keys := [[0.0, 0.28], [0.429, 0.20], [0.857, 0.32], [1.0, 0.28]]
	return {"brazo_der": SpriteLienzo.tramos(t, der_keys), "brazo_izq": 0.95,
		"inclina": SpriteLienzo.tramos(t, incl_keys),
		"agacha": 0.86, "paso": 0.08, "rumbo": 0.30}


# EN GUARDIA: con el arma fuera pero sin atacar. Como el idle (respira) pero con los dos brazos
# recogidos en alto -- el derecho lleva el arma o es la mano principal del dual, el izquierdo
# equilibra o empuña la segunda. Un pelo agachado: peso repartido, listo para soltar el golpe.
#
# (Las de una mano siguen asi, sin tocar. La de las armas a dos manos hechas es _pose_guardia_2m. OJO al
# retocar un eje de arma: "hacia tu derecha" al ir al este es hacia la camara, que baja en pantalla lo
# que "hacia arriba" sube -- se anulan y el arma se queda en un muñon.)

static func _pose_guardia(t: float) -> Dictionary:
	return {"bote": 0.30 * sin(TAU * t),
		"brazo_der": -0.55 + 0.05 * sin(TAU * t),
		"brazo_izq": -0.30 + 0.05 * sin(TAU * t),
		"inclina": 0.08, "agacha": 0.10}


# LA GUARDIA DEL MANDOBLE (24/09, su referencia: un espadachin en guardia baja): PIERNAS ABIERTAS, las
# DOS MANOS JUNTAS en el mango delante de la cadera y la hoja en DIAGONAL hacia delante y hacia arriba,
# apuntando al rival. La MISMA para el martillo ("lo mismo exactamente pero con un martillo").
# MunecoJugador cambia 'guardia*' por 'guardia_2m*' cuando se lleva uno de los dos.
const GUARDIA_EJE_FRENTE := Vector3(0.35, 0.55, 0.85)

static func _pose_guardia_2m(t: float) -> Dictionary:
	return {"bote": 0.25 * sin(TAU * t), "brazo_der": 0.40 + 0.03 * sin(TAU * t),
		"brazo_izq": 0.40 + 0.03 * sin(TAU * t), "inclina": 0.10, "agacha": 0.22, "paso": 0.30,
		"junta": 1.0, "eje_2m": GUARDIA_EJE_FRENTE}


static func _pose_guardia_2m_and(t: float) -> Dictionary:
	return {"paso": 0.10 + 0.40 * sin(TAU * t), "bote": 0.45 * absf(sin(TAU * t)),
		"brazo_der": 0.40 + 0.04 * sin(TAU * t), "brazo_izq": 0.40 + 0.04 * sin(TAU * t),
		"inclina": 0.12, "agacha": 0.18, "junta": 1.0, "eje_2m": GUARDIA_EJE_FRENTE}


static func _pose_guardia_2m_cor(t: float) -> Dictionary:
	return {"paso": 0.55 * sin(TAU * t), "bote": 0.95 * absf(sin(TAU * t)),
		"brazo_der": 0.40 + 0.06 * sin(TAU * t), "brazo_izq": 0.40 + 0.06 * sin(TAU * t),
		"inclina": 0.24, "agacha": 0.12, "junta": 1.0, "eje_2m": GUARDIA_EJE_FRENTE}


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
# SACAR EL MARTILLO O EL MANDOBLE DE LA ESPALDA y quedarse en guardia. La derecha sube por delante hasta
# por encima del hombro (4.0 = atras-arriba, ver el arco de _pose_golpe_2m), agarra el mango, y lo trae
# por encima y por delante hasta la guardia; la izquierda se une al mango al final (junta). El ultimo
# fotograma ES _pose_guardia_2m(0): sin eso el arma daba un salto al pasar a la guardia.
static func _pose_desenvainar_2m(t: float) -> Dictionary:
	var fin: Dictionary = _pose_guardia_2m(0.0)
	var der_keys := [[0.0, 0.15], [0.3, 3.3], [0.45, 3.5], [0.75, 1.3], [1.0, float(fin["brazo_der"])]]
	var izq_keys := [[0.0, 0.10], [0.6, 0.25], [1.0, float(fin["brazo_izq"])]]
	var junta_keys := [[0.0, 0.0], [0.7, 0.0], [1.0, 1.0]]
	var agacha_keys := [[0.0, 0.08], [1.0, float(fin["agacha"])]]
	var paso_keys := [[0.0, 0.0], [1.0, float(fin["paso"])]]
	var incl_keys := [[0.0, 0.04], [0.45, -0.06], [1.0, float(fin["inclina"])]]
	return {"brazo_der": SpriteLienzo.tramos(t, der_keys),
		"brazo_izq": SpriteLienzo.tramos(t, izq_keys),
		"junta": SpriteLienzo.tramos(t, junta_keys),
		"agacha": SpriteLienzo.tramos(t, agacha_keys),
		"paso": SpriteLienzo.tramos(t, paso_keys),
		"inclina": SpriteLienzo.tramos(t, incl_keys),
		"bote": float(fin.get("bote", 0.0)) * t,
		"eje_2m": fin["eje_2m"],
		# El arma se queda en la espalda hasta que la mano llega (t ~ 0.4) y de ahi viaja a la guardia.
		# Hasta entonces -1 = envainada de verdad: solo se ve de espaldas (con 0 se pintaba siempre, y
		# mirando al sur salia cruzada por DELANTE del pecho).
		"sacando": -1.0 if t < 0.4 else clampf((t - 0.4) / 0.6, 0.0, 1.0)}


static func _pose_desenvainar(t: float) -> Dictionary:
	var brazo_keys := [[0.0, 0.15], [0.35, 0.55], [0.60, -0.20], [1.0, -0.55]]
	var izq_keys := [[0.0, 0.0], [0.50, 0.10], [1.0, -0.30]]
	var incl_keys := [[0.0, 0.0], [0.40, 1.0], [1.0, 0.4]]
	return {"brazo_der": SpriteLienzo.tramos(t, brazo_keys),
		"brazo_izq": SpriteLienzo.tramos(t, izq_keys),
		"inclina": 0.06 + 0.06 * SpriteLienzo.tramos(t, incl_keys),
		"agacha": 0.10, "sacando": t}


# ------------------------------------------------------------
#  LA DAGA (24/09). Su guardia es la de SU REFERENCIA: el brazo del arma ESTIRADO al frente a la altura del
#  pecho, puño cerrado, y la daga agarrada AL REVES (la hoja sale por debajo del puño, hacia abajo y hacia
#  dentro, cruzando por delante del cuerpo). La otra mano, recogida junto al pecho; con dos dagas lleva la
#  segunda IGUAL, al reves. MunecoJugador cambia 'guardia*' por 'guardia_daga*' si llevas daga.
# ------------------------------------------------------------
const DAGA_EJE_DER := Vector3(0.55, 0.30, -0.78)    # al reves: abajo, hacia dentro y un pelo al frente
const DAGA_EJE_IZQ := Vector3(-0.50, 0.35, -0.80)

static func _pose_guardia_daga(t: float) -> Dictionary:
	return {"bote": 0.25 * sin(TAU * t),
		"brazo_der": 1.30 + 0.04 * sin(TAU * t), "brazo_izq": 0.85 + 0.04 * sin(TAU * t),
		"junta_izq": 0.75, "inclina": 0.12, "agacha": 0.20, "paso": 0.32, "torsion": 0.20,
		"eje_der": DAGA_EJE_DER, "eje_izq": DAGA_EJE_IZQ}


static func _pose_guardia_daga_and(t: float) -> Dictionary:
	return {"paso": 0.10 + 0.40 * sin(TAU * t), "bote": 0.45 * absf(sin(TAU * t)),
		"brazo_der": 1.30 + 0.05 * sin(TAU * t), "brazo_izq": 0.85 + 0.05 * sin(TAU * t),
		"junta_izq": 0.75, "inclina": 0.14, "agacha": 0.16, "torsion": 0.20,
		"eje_der": DAGA_EJE_DER, "eje_izq": DAGA_EJE_IZQ}


static func _pose_guardia_daga_cor(t: float) -> Dictionary:
	return {"paso": 0.58 * sin(TAU * t), "bote": 0.95 * absf(sin(TAU * t)),
		"brazo_der": 1.20 + 0.08 * sin(TAU * t), "brazo_izq": 0.85 + 0.08 * sin(TAU * t),
		"junta_izq": 0.75, "inclina": 0.26, "agacha": 0.10, "torsion": 0.15,
		"eje_der": DAGA_EJE_DER, "eje_izq": DAGA_EJE_IZQ}


# SACAR LA DAGA de la cadera y quedarse en su guardia: la mano baja al costado, agarra y la saca de un tiron
# llevandola al frente. El ultimo fotograma ES _pose_guardia_daga(0) (sin salto al pasar a la guardia).
static func _pose_desenvainar_daga(t: float) -> Dictionary:
	var fin: Dictionary = _pose_guardia_daga(0.0)
	var der_keys := [[0.0, 0.15], [0.35, -0.10], [0.55, 0.30], [1.0, float(fin["brazo_der"])]]
	var izq_keys := [[0.0, 0.10], [0.35, -0.10], [0.6, 0.40], [1.0, float(fin["brazo_izq"])]]
	var jun_keys := [[0.0, 0.0], [0.6, 0.2], [1.0, float(fin["junta_izq"])]]
	var agacha_keys := [[0.0, 0.08], [0.35, 0.14], [1.0, float(fin["agacha"])]]
	var paso_keys := [[0.0, 0.0], [1.0, float(fin["paso"])]]
	var tor_keys := [[0.0, 0.0], [1.0, float(fin["torsion"])]]
	var incl_keys := [[0.0, 0.04], [0.35, 0.14], [1.0, float(fin["inclina"])]]
	return {"brazo_der": SpriteLienzo.tramos(t, der_keys),
		"brazo_izq": SpriteLienzo.tramos(t, izq_keys),
		"junta_izq": SpriteLienzo.tramos(t, jun_keys),
		"agacha": SpriteLienzo.tramos(t, agacha_keys),
		"paso": SpriteLienzo.tramos(t, paso_keys),
		"torsion": SpriteLienzo.tramos(t, tor_keys),
		"inclina": SpriteLienzo.tramos(t, incl_keys),
		"bote": float(fin.get("bote", 0.0)) * t,
		# En la cadera hasta que la mano llega (0,35); de ahi viaja al puño, ya al reves.
		"eje_der": DAGA_EJE_DER, "eje_izq": DAGA_EJE_IZQ,
		"sacando": -1.0 if t < 0.35 else clampf((t - 0.35) / 0.65, 0.0, 1.0)}


# EL TAJO DE LA DAGA: corto, de revés, desde la guardia. Se arma cruzando el brazo hacia dentro (el
# tronco se tuerce) y lo suelta de lado a lado con el cuerpo detras. Golpe en 0,45. Con la IZQUIERDA es
# el espejo: el brazo recogido se estira al soltar (junta_izq baja) y el tronco va al otro lado.
static func _pose_tajo_daga(t: float, izq: bool) -> Dictionary:
	var g: Dictionary = _pose_guardia_daga(0.0)
	var s: float = -1.0 if izq else 1.0
	var tor_keys := [[0.0, 0.20], [0.3, 0.20 - 0.9 * s], [0.45, 0.20 + 0.25 * s], [0.62, 0.20 + 0.8 * s],
		[1.0, 0.20]]
	var brazo_keys := [[0.0, 1.30], [0.3, 1.05], [0.45, 1.55], [0.62, 1.45], [1.0, 1.30]]
	var izq_keys := [[0.0, 0.85], [0.3, 0.70], [0.45, 1.50], [0.62, 1.40], [1.0, 0.85]]
	var jun_keys := [[0.0, 0.75], [0.3, 0.85], [0.45, 0.25], [0.62, 0.30], [1.0, 0.75]]
	var av_keys := [[0.0, 0.0], [0.3, -0.6], [0.45, 2.0], [0.62, 1.4], [1.0, 0.0]]
	var incl_keys := [[0.0, 0.12], [0.3, 0.06], [0.45, 0.26], [1.0, 0.12]]
	var p: Dictionary = g.duplicate()
	p["torsion"] = SpriteLienzo.tramos(t, tor_keys)
	p["avance"] = SpriteLienzo.tramos(t, av_keys)
	p["inclina"] = SpriteLienzo.tramos(t, incl_keys)
	p["bote"] = 0.0
	if izq:
		p["brazo_izq"] = SpriteLienzo.tramos(t, izq_keys)
		p["junta_izq"] = SpriteLienzo.tramos(t, jun_keys)
	else:
		p["brazo_der"] = SpriteLienzo.tramos(t, brazo_keys)
	return p


# EL TAJO DE DESAPARECER: el mismo, pero la otra mano esta LIBRE (su daga, envainada: ver
# ArmaSprites._ANIM_SOLO_DER) y cuelga suelta, agachado dentro del humo.
static func _pose_tajo_daga_solo(t: float) -> Dictionary:
	var p: Dictionary = _pose_tajo_daga(t, false)
	p["brazo_izq"] = 0.25
	p["junta_izq"] = 0.0
	p["agacha"] = 0.34
	return p


# LA ESTOCADA: echa el brazo atras recogiendo la daga y la LANZA al frente con todo el cuerpo detras. La
# hoja gira del agarre al reves a apuntar al frente justo al estirarse (una puñalada no se da de revés).
# Golpe en 0,5, con el brazo estirado del todo.
const DAGA_EJE_FRENTE_DER := Vector3(0.12, 1.0, 0.05)
const DAGA_EJE_FRENTE_IZQ := Vector3(-0.12, 1.0, 0.05)

static func _pose_punalada_daga(t: float, izq: bool) -> Dictionary:
	var g: Dictionary = _pose_guardia_daga(0.0)
	var s: float = -1.0 if izq else 1.0
	var brazo_keys := [[0.0, 1.30], [0.35, 0.80], [0.5, 1.62], [0.7, 1.55], [1.0, 1.30]]
	var izq_keys := [[0.0, 0.85], [0.35, 0.55], [0.5, 1.62], [0.7, 1.55], [1.0, 0.85]]
	var jun_keys := [[0.0, 0.75], [0.35, 0.60], [0.5, 0.35], [0.7, 0.35], [1.0, 0.75]]
	var av_keys := [[0.0, 0.0], [0.35, -1.6], [0.5, 4.2], [0.7, 3.6], [1.0, 0.0]]
	var incl_keys := [[0.0, 0.12], [0.35, -0.02], [0.5, 0.38], [0.7, 0.32], [1.0, 0.12]]
	var tor_keys := [[0.0, 0.20], [0.35, 0.20 - 0.5 * s], [0.5, 0.20 + 0.35 * s], [1.0, 0.20]]
	# Cuanto apunta al frente la hoja: nada en la guardia, entera en la estocada.
	var giro: float = SpriteLienzo.tramos(t, [[0.0, 0.0], [0.35, 0.3], [0.45, 1.0], [0.72, 1.0], [1.0, 0.0]])
	var p: Dictionary = g.duplicate()
	p["avance"] = SpriteLienzo.tramos(t, av_keys)
	p["inclina"] = SpriteLienzo.tramos(t, incl_keys)
	p["torsion"] = SpriteLienzo.tramos(t, tor_keys)
	p["bote"] = 0.0
	if izq:
		p["brazo_izq"] = SpriteLienzo.tramos(t, izq_keys)
		p["junta_izq"] = SpriteLienzo.tramos(t, jun_keys)
		p["eje_izq"] = DAGA_EJE_IZQ.lerp(DAGA_EJE_FRENTE_IZQ, giro)
	else:
		p["brazo_der"] = SpriteLienzo.tramos(t, brazo_keys)
		p["eje_der"] = DAGA_EJE_DER.lerp(DAGA_EJE_FRENTE_DER, giro)
	return p


# LA BOMBA DE HUMO (Desaparecer): la izquierda va al cinto (con dos dagas, la suya se queda envainada:
# ArmaSprites._ANIM_SOLO_DER), coge la bomba, la echa atras y la estrella contra el suelo a tus pies,
# agachandose. El golpe (la bomba toca el suelo y revienta) en 0,62; de ahi se queda agachado, que es
# cuando empiezan las puñaladas.
static func _pose_lanzar_humo(t: float) -> Dictionary:
	var g: Dictionary = _pose_guardia_daga(0.0)
	var izq_keys := [[0.0, 0.85], [0.2, -0.05], [0.42, -0.75], [0.55, 0.55], [0.62, 0.95], [0.8, 0.5],
		[1.0, 0.25]]
	var jun_keys := [[0.0, 0.75], [0.2, 0.0], [1.0, 0.0]]
	var agacha_keys := [[0.0, 0.20], [0.42, 0.18], [0.62, 0.38], [1.0, 0.34]]
	var incl_keys := [[0.0, 0.12], [0.42, 0.02], [0.62, 0.34], [1.0, 0.26]]
	var tor_keys := [[0.0, 0.20], [0.42, 0.45], [0.62, -0.15], [1.0, 0.0]]
	var p: Dictionary = g.duplicate()
	p["brazo_izq"] = SpriteLienzo.tramos(t, izq_keys)
	p["junta_izq"] = SpriteLienzo.tramos(t, jun_keys)
	p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
	p["inclina"] = SpriteLienzo.tramos(t, incl_keys)
	p["torsion"] = SpriteLienzo.tramos(t, tor_keys)
	p["bote"] = 0.0
	return p


# EL FILO EMPONZOÑADO: sube la daga delante del pecho con la hoja cruzada y la otra mano pasa DOS veces
# por el filo (el frasco). Sin golpe: el veneno sale en 0,3 (ver IMPACTO_ANIM_MAPA).
static func _pose_afilar_veneno(t: float) -> Dictionary:
	var g: Dictionary = _pose_guardia_daga(0.0)
	var der_keys := [[0.0, 1.30], [0.2, 1.05], [0.85, 1.05], [1.0, 1.30]]
	var pasa: float = sin(clampf((t - 0.2) / 0.65, 0.0, 1.0) * TAU * 2.0)
	var p: Dictionary = g.duplicate()
	p["brazo_der"] = SpriteLienzo.tramos(t, der_keys)
	p["eje_der"] = DAGA_EJE_DER.lerp(Vector3(0.9, 0.35, 0.1), SpriteLienzo.tramos(t,
		[[0.0, 0.0], [0.2, 1.0], [0.85, 1.0], [1.0, 0.0]]))
	var dentro: float = SpriteLienzo.tramos(t, [[0.0, 0.0], [0.2, 1.0], [0.85, 1.0], [1.0, 0.0]])
	p["brazo_izq"] = lerpf(0.85, 1.0 + 0.18 * pasa, dentro)
	p["junta_izq"] = lerpf(0.75, 0.95 - 0.25 * absf(pasa), dentro)
	p["inclina"] = 0.16
	p["bote"] = 0.0
	return p


# ------------------------------------------------------------
#  EL ESTOQUE (24/09). SU REFERENCIA (esgrima): la guardia de ataque es el EN GARDE -- de perfil, rodillas
#  flexionadas y piernas abiertas, el brazo del arma ESTIRADO al frente con la punta ADELANTE y un pelo
#  arriba, y la otra mano ALZADA DETRAS de la cabeza. La estocada es el FONDO: la pierna de delante sale,
#  la de atras se estira, el brazo llega entero y la mano de atras cae hacia atras. La DEFENSIVA (En
#  guardia) es mas BAJA y con el estoque PEGADO al cuerpo, la hoja en diagonal delante del pecho.
#  El estoque no va a dos manos: la izquierda va libre (o con escudo/varita).
# ------------------------------------------------------------
const ESTOQUE_EJE := Vector3(0.0, 1.0, 0.22)           # la punta al frente y un pelo arriba
const ESTOQUE_EJE_DEF := Vector3(0.10, 0.70, 0.70)     # pegada: en diagonal, adelante y arriba
const ESTOQUE_EJE_ALTO := Vector3(0.05, 0.15, 1.0)     # en vertical delante de la cara (el saludo)

static func _pose_guardia_estoque(t: float) -> Dictionary:
	return {"bote": 0.2 * sin(TAU * t),
		"brazo_der": 1.35 + 0.03 * sin(TAU * t), "brazo_izq": 3.7 + 0.04 * sin(TAU * t),
		"inclina": 0.05, "agacha": 0.26, "paso": 0.45, "torsion": 0.55,
		"eje_der": ESTOQUE_EJE}


static func _pose_guardia_estoque_and(t: float) -> Dictionary:
	return {"paso": 0.10 + 0.40 * sin(TAU * t), "bote": 0.35 * absf(sin(TAU * t)),
		"brazo_der": 1.35 + 0.04 * sin(TAU * t), "brazo_izq": 3.7 + 0.05 * sin(TAU * t),
		"inclina": 0.07, "agacha": 0.22, "torsion": 0.55, "eje_der": ESTOQUE_EJE}


static func _pose_guardia_estoque_cor(t: float) -> Dictionary:
	return {"paso": 0.58 * sin(TAU * t), "bote": 0.9 * absf(sin(TAU * t)),
		"brazo_der": 1.25 + 0.06 * sin(TAU * t), "brazo_izq": 3.5 + 0.08 * sin(TAU * t),
		"inclina": 0.22, "agacha": 0.10, "torsion": 0.4, "eje_der": ESTOQUE_EJE}


# LA DEFENSIVA (mientras dura En guardia): mas baja y mas abierta, el peso atras, y el estoque recogido
# delante del cuerpo con la hoja en diagonal. Respira mas despacio: esta esperando.
static func _pose_guardia_estoque_def(t: float) -> Dictionary:
	return {"bote": 0.15 * sin(TAU * t),
		"brazo_der": 0.80 + 0.03 * sin(TAU * t), "brazo_izq": 3.4 + 0.03 * sin(TAU * t),
		"inclina": -0.04, "agacha": 0.42, "paso": 0.55, "torsion": 0.5,
		"eje_der": ESTOQUE_EJE_DEF}


# SACAR EL ESTOQUE: como la daga, de la cadera a la guardia (el ultimo fotograma ES la guardia).
static func _pose_desenvainar_estoque(t: float) -> Dictionary:
	var fin: Dictionary = _pose_guardia_estoque(0.0)
	var der_keys := [[0.0, 0.15], [0.35, -0.10], [0.6, 0.6], [1.0, float(fin["brazo_der"])]]
	var izq_keys := [[0.0, 0.10], [0.45, 0.4], [1.0, float(fin["brazo_izq"])]]
	var agacha_keys := [[0.0, 0.08], [0.35, 0.14], [1.0, float(fin["agacha"])]]
	var paso_keys := [[0.0, 0.0], [1.0, float(fin["paso"])]]
	var tor_keys := [[0.0, 0.0], [1.0, float(fin["torsion"])]]
	var incl_keys := [[0.0, 0.04], [0.35, 0.12], [1.0, float(fin["inclina"])]]
	var giro: float = clampf((t - 0.35) / 0.65, 0.0, 1.0)
	return {"brazo_der": SpriteLienzo.tramos(t, der_keys),
		"brazo_izq": SpriteLienzo.tramos(t, izq_keys),
		"agacha": SpriteLienzo.tramos(t, agacha_keys),
		"paso": SpriteLienzo.tramos(t, paso_keys),
		"torsion": SpriteLienzo.tramos(t, tor_keys),
		"inclina": SpriteLienzo.tramos(t, incl_keys),
		"bote": float(fin.get("bote", 0.0)) * t,
		# Sale colgando (la linea del brazo) y acaba apuntando al frente.
		"eje_der": Vector3(0.0, 0.35, -1.0).normalized().lerp(ESTOQUE_EJE, giro),
		"sacando": -1.0 if t < 0.35 else giro}


# EL FONDO (la estocada de siempre): recoge un pelo, y la pierna de delante SALE con el brazo llegando
# entero; la de atras se estira, el tronco se echa encima y la mano de atras cae hacia atras. Aguanta un
# instante y vuelve a la guardia. Golpe en 0,5 (brazo estirado del todo).
static func _fondo(t: float, t_rec: float, t_imp: float, t_aguanta: float, hondo: float) -> Dictionary:
	var g: Dictionary = _pose_guardia_estoque(0.0)
	var p: Dictionary = g.duplicate()
	var av_keys := [[0.0, 0.0], [t_rec, -1.5 * hondo], [t_imp, 7.0 * hondo], [t_aguanta, 6.4 * hondo], [1.0, 0.0]]
	var paso_keys := [[0.0, 0.45], [t_rec, 0.40], [t_imp, 0.95 + 0.15 * (hondo - 1.0)], [t_aguanta, 0.9], [1.0, 0.45]]
	var agacha_keys := [[0.0, 0.26], [t_rec, 0.22], [t_imp, 0.36], [t_aguanta, 0.36], [1.0, 0.26]]
	var incl_keys := [[0.0, 0.05], [t_rec, -0.04], [t_imp, 0.30], [t_aguanta, 0.28], [1.0, 0.05]]
	var brazo_keys := [[0.0, 1.35], [t_rec, 1.15 - 0.15 * (hondo - 1.0)], [t_imp, 1.57], [t_aguanta, 1.55], [1.0, 1.35]]
	var izq_keys := [[0.0, 3.7], [t_rec, 3.8], [t_imp, -0.9], [t_aguanta, -0.85], [1.0, 3.7]]
	var tor_keys := [[0.0, 0.55], [t_rec, 0.55 + 0.3 * hondo], [t_imp, 0.75], [t_aguanta, 0.72], [1.0, 0.55]]
	p["avance"] = SpriteLienzo.tramos(t, av_keys)
	p["paso"] = SpriteLienzo.tramos(t, paso_keys)
	p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
	p["inclina"] = SpriteLienzo.tramos(t, incl_keys)
	p["brazo_der"] = SpriteLienzo.tramos(t, brazo_keys)
	p["brazo_izq"] = SpriteLienzo.tramos(t, izq_keys)
	p["torsion"] = SpriteLienzo.tramos(t, tor_keys)
	p["bote"] = 0.0
	# En el fondo la hoja va recta, en la linea del brazo estirado.
	p["eje_der"] = ESTOQUE_EJE.lerp(Vector3(0.0, 1.0, 0.0), SpriteLienzo.tramos(t,
		[[0.0, 0.0], [t_imp, 1.0], [t_aguanta, 1.0], [1.0, 0.0]]))
	return p


static func _pose_estocada_estoque(t: float) -> Dictionary:
	return _fondo(t, 0.3, 0.5, 0.7, 1.0)


# LA PENETRANTE: el mismo fondo pero HONDO -- se recoge mas (el tronco se enrosca) y llega mas lejos. Golpe
# en 0,55, y aguanta estirado mas rato (la hoja atraviesa).
static func _pose_estocada_honda(t: float) -> Dictionary:
	return _fondo(t, 0.35, 0.55, 0.82, 1.3)


# LAS FINTAS: el AMAGO (medio fondo que se queda a medias y vuelve) y el fondo de verdad. Amago en 0,2,
# golpe en 0,62. Una por golpe (se repite, ver CombatTactico._REPITE_POR_GOLPE).
static func _pose_finta_estoque(t: float) -> Dictionary:
	if t < 0.38:
		# Medio fondo: sale hasta la mitad y se recoge.
		var u: float = t / 0.38
		var p: Dictionary = _fondo(0.5 * sin(PI * u) * 0.9, 0.3, 0.5, 0.7, 0.55)
		p["brazo_izq"] = 3.7
		return p
	return _fondo(0.3 + (t - 0.38) / 0.62 * 0.7, 0.3, 0.5, 0.7, 1.0)


# EL PINCHAZO de la Danza: sin fondo (las piernas ya van avanzando por la linea), solo el brazo que entra y
# sale rapido con el tronco detras. Golpe en 0,45.
static func _pose_pinchazo_estoque(t: float) -> Dictionary:
	var g: Dictionary = _pose_guardia_estoque(0.0)
	var p: Dictionary = g.duplicate()
	p["brazo_der"] = SpriteLienzo.tramos(t, [[0.0, 1.35], [0.25, 1.15], [0.45, 1.6], [0.65, 1.55], [1.0, 1.35]])
	p["avance"] = SpriteLienzo.tramos(t, [[0.0, 0.0], [0.25, -0.6], [0.45, 2.4], [1.0, 0.0]])
	p["inclina"] = SpriteLienzo.tramos(t, [[0.0, 0.05], [0.45, 0.2], [1.0, 0.05]])
	p["torsion"] = SpriteLienzo.tramos(t, [[0.0, 0.55], [0.25, 0.75], [0.45, 0.6], [1.0, 0.55]])
	p["eje_der"] = ESTOQUE_EJE.lerp(Vector3(0.0, 1.0, 0.0), SpriteLienzo.tramos(t,
		[[0.0, 0.0], [0.45, 1.0], [0.65, 1.0], [1.0, 0.0]]))
	p["bote"] = 0.0
	return p


# PONERSE EN GUARDIA: sube la hoja en vertical delante de la cara (el saludo, el destello corre por ella en
# 0,4) y baja a la guardia DEFENSIVA, asentandose mas bajo. El ultimo fotograma ES la defensiva.
static func _pose_ponerse_en_guardia(t: float) -> Dictionary:
	var g: Dictionary = _pose_guardia_estoque(0.0)
	var d: Dictionary = _pose_guardia_estoque_def(0.0)
	var p: Dictionary = g.duplicate()
	p["brazo_der"] = SpriteLienzo.tramos(t, [[0.0, float(g["brazo_der"])], [0.4, 1.25], [0.6, 1.2],
		[1.0, float(d["brazo_der"])]])
	p["agacha"] = SpriteLienzo.tramos(t, [[0.0, float(g["agacha"])], [0.4, 0.2], [1.0, float(d["agacha"])]])
	p["paso"] = SpriteLienzo.tramos(t, [[0.0, float(g["paso"])], [0.6, 0.4], [1.0, float(d["paso"])]])
	p["inclina"] = SpriteLienzo.tramos(t, [[0.0, float(g["inclina"])], [0.4, 0.0], [1.0, float(d["inclina"])]])
	p["brazo_izq"] = SpriteLienzo.tramos(t, [[0.0, float(g["brazo_izq"])], [1.0, float(d["brazo_izq"])]])
	p["torsion"] = SpriteLienzo.tramos(t, [[0.0, float(g["torsion"])], [0.4, 0.3], [1.0, float(d["torsion"])]])
	var alto: float = SpriteLienzo.tramos(t, [[0.0, 0.0], [0.4, 1.0], [0.6, 1.0], [1.0, 0.0]])
	var fin: float = clampf((t - 0.6) / 0.4, 0.0, 1.0)
	p["eje_der"] = ESTOQUE_EJE.lerp(ESTOQUE_EJE_ALTO, alto) if t < 0.6 else ESTOQUE_EJE_ALTO.lerp(ESTOQUE_EJE_DEF, fin)
	p["bote"] = 0.0
	return p


# ------------------------------------------------------------
#  LA POSTURA DE DEFENSA (el Defender, 24/09). Todas BAJAS y cerradas, respirando despacio: esperan el
#  golpe. Una por combinacion de manos (la elige MunecoJugador._variante_defensa).
# ------------------------------------------------------------
# UNA MANO (espada, maza, puños...): el arma atravesada delante del pecho y la otra mano apoyando.
static func _pose_defensa_1m(t: float) -> Dictionary:
	return {"bote": 0.12 * sin(TAU * t), "agacha": 0.32, "paso": 0.42, "inclina": -0.04, "torsion": 0.3,
		"brazo_der": 1.45 + 0.02 * sin(TAU * t), "brazo_izq": 1.25, "junta_izq": 0.55,
		"eje_der": Vector3(-1.0, 0.25, 0.35)}


# CON ESCUDO: el escudo ARRIBA delante (a la altura de la cara), el hombro del escudo adelantado, agachado
# detras de el, y el arma recogida atras, lista.
static func _pose_defensa_escudo(t: float) -> Dictionary:
	return {"bote": 0.12 * sin(TAU * t), "agacha": 0.38, "paso": 0.5, "inclina": 0.08, "torsion": -0.25,
		"brazo_izq": 1.35 + 0.02 * sin(TAU * t), "junta_izq": 0.3,
		"brazo_der": 0.35, "eje_der": Vector3(0.0, 0.5, 0.85)}


# A DOS MANOS: el arma ATRAVESADA en horizontal delante del pecho, con las dos manos (parar con el astil
# o la hoja plana).
static func _pose_defensa_2m(t: float) -> Dictionary:
	return {"bote": 0.12 * sin(TAU * t), "agacha": 0.3, "paso": 0.45, "inclina": -0.03,
		"brazo_der": 1.5 + 0.02 * sin(TAU * t), "brazo_izq": 1.5 + 0.02 * sin(TAU * t), "junta": 1.0,
		"eje_2m": Vector3(-1.0, 0.15, 0.3)}


# LA DAGA (sola o dos): los brazos CRUZADOS delante del pecho con las hojas hacia fuera y arriba, en X.
static func _pose_defensa_daga(t: float) -> Dictionary:
	return {"bote": 0.12 * sin(TAU * t), "agacha": 0.36, "paso": 0.4, "inclina": 0.02, "torsion": 0.1,
		"brazo_der": 1.35 + 0.02 * sin(TAU * t), "brazo_izq": 1.35 + 0.02 * sin(TAU * t),
		"junta_der": 0.9, "junta_izq": 0.9,
		"eje_der": Vector3(-0.6, 0.3, 0.75), "eje_izq": Vector3(0.6, 0.3, 0.75)}


# EL ESTOQUE solo: parando con la hoja en VERTICAL delante (la mano a la altura del pecho, la punta
# arriba), de perfil y la mano de atras alzada, como en su guardia.
static func _pose_defensa_estoque(t: float) -> Dictionary:
	return {"bote": 0.12 * sin(TAU * t), "agacha": 0.34, "paso": 0.5, "inclina": -0.02, "torsion": 0.55,
		"brazo_der": 1.1 + 0.02 * sin(TAU * t), "junta_der": 0.4, "brazo_izq": 3.6,
		"eje_der": Vector3(0.15, 0.3, 1.0)}


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


# ------------------------------------------------------------
#  LA ESPADA CORTA (25/09). SUS REFERENCIAS: con UNA, piernas muy abiertas y de tres cuartos, el puño del
#  arma BAJO y adelantado (a la altura de la cadera) con la hoja en diagonal hacia arriba y hacia FUERA, y la
#  otra mano abierta echada atras (el equilibrio). Con DOS (el espadachin de dos espadas): de frente, los dos
#  puños bajos junto a la cadera, una espada TUMBADA hacia fuera y la otra VERTICAL. El Defender: la hoja
#  atravesada delante del pecho; con dos, cruzadas como las dagas.
#  Los nombres: '<anim>_espada' con una, '<anim>_espada2' con dos (y '_izq' si pega la izquierda). Los pide
#  MunecoJugador (_GUARDIA_DE / _con_su_guardia_base): quien anima pide 'tajo_espada' sin saber si hay dos.
#  El eje de la hoja va en el sistema del cuerpo: x = hacia la izquierda del personaje (la derecha es -x),
#  y = al frente, z = arriba.
# ------------------------------------------------------------
const ESPADA_EJE := Vector3(-0.45, 0.55, 0.75)        # con una: arriba, adelante y hacia fuera
const ESPADA2_EJE_DER := Vector3(-0.95, 0.25, -0.12)  # con dos: la derecha TUMBADA hacia fuera
const ESPADA2_EJE_IZQ := Vector3(0.05, 0.22, 1.0)     # y la izquierda VERTICAL
const ESPADA_ABRE := 1.05   # lo que el brazo abre/cruza en horizontal en los golpes (rad, con x = +-1)

static func _pose_espada(anim: String, t: float) -> Dictionary:
	var dual: bool = anim.contains("espada2")
	var izq: bool = anim.ends_with("_izq")
	var base: String = anim.replace("espada2", "espada").trim_suffix("_izq")
	match base:
		"guardia_espada": return _guardia_espada(t, dual, 0)
		"guardia_espada_and": return _guardia_espada(t, dual, 1)
		"guardia_espada_cor": return _guardia_espada(t, dual, 2)
		"desenvainar_espada": return _desenvainar_espada(t, dual)
		"defensa_espada": return _defensa_espada(t, dual)
		"tajo_espada", "reves_espada", "barrido_espada", "tajo_bajo_espada", "tajo_paso_espada":
			return _golpe_espada(t, base, dual, izq)
	return {}


# 'm': 0 quieta, 1 andando, 2 corriendo.
static func _guardia_espada(t: float, dual: bool, m: int) -> Dictionary:
	var s: float = sin(TAU * t)
	var p: Dictionary
	if not dual:
		p = {"brazo_der": 0.85 + 0.03 * s, "brazo_izq": -1.25 + 0.04 * s, "torsion": 0.4, "eje_der": ESPADA_EJE,
			"bote": 0.25 * s, "inclina": 0.06, "agacha": 0.30, "paso": 0.50}
	else:
		p = {"brazo_der": 0.5 + 0.03 * s, "brazo_izq": 0.5 + 0.03 * s, "torsion": 0.05,
			"eje_der": ESPADA2_EJE_DER, "eje_izq": ESPADA2_EJE_IZQ,
			"bote": 0.25 * s, "inclina": 0.05, "agacha": 0.28, "paso": 0.42}
	if m == 1:
		# Las piernas se CRUZAN (antes 'guardia + 0.12 * s': la zancada de la guardia fija con un temblor, y se
		# deslizaba "andando sin animacion").
		p["paso"] = 0.10 + 0.40 * s
		p["bote"] = 0.4 * absf(s)
		p["agacha"] = float(p["agacha"]) - 0.06
		p["inclina"] = float(p["inclina"]) + 0.04
	elif m == 2:
		p["paso"] = 0.58 * s
		p["bote"] = 0.95 * absf(s)
		p["agacha"] = 0.10
		p["inclina"] = 0.22
		p["torsion"] = float(p["torsion"]) * 0.6
	return p


# SACARLA de la cadera y quedarse en su guardia (el ultimo fotograma ES la guardia, sin salto). Con dos, las
# dos manos a la vez.
static func _desenvainar_espada(t: float, dual: bool) -> Dictionary:
	var fin: Dictionary = _guardia_espada(0.0, dual, 0)
	var der_keys := [[0.0, 0.15], [0.35, -0.10], [0.6, 0.5], [1.0, float(fin["brazo_der"])]]
	var izq_keys := [[0.0, 0.10], [0.35, -0.10 if dual else 0.0], [0.6, 0.45 if dual else -0.6],
		[1.0, float(fin["brazo_izq"])]]
	var giro: float = clampf((t - 0.35) / 0.65, 0.0, 1.0)
	var colgando := Vector3(0.0, 0.35, -1.0).normalized()
	var p: Dictionary = {"brazo_der": SpriteLienzo.tramos(t, der_keys),
		"brazo_izq": SpriteLienzo.tramos(t, izq_keys),
		"agacha": SpriteLienzo.tramos(t, [[0.0, 0.08], [0.35, 0.14], [1.0, float(fin["agacha"])]]),
		"paso": SpriteLienzo.tramos(t, [[0.0, 0.0], [1.0, float(fin["paso"])]]),
		"torsion": SpriteLienzo.tramos(t, [[0.0, 0.0], [1.0, float(fin["torsion"])]]),
		"inclina": SpriteLienzo.tramos(t, [[0.0, 0.04], [0.35, 0.12], [1.0, float(fin["inclina"])]]),
		"bote": 0.0,
		"eje_der": colgando.lerp(fin["eje_der"], giro),
		"sacando": -1.0 if t < 0.35 else giro}
	if dual:
		p["eje_izq"] = colgando.lerp(fin["eje_izq"], giro)
	return p


# EL DEFENDER: la hoja ATRAVESADA delante del pecho (hacia tu izquierda) y la otra mano apoyada en ella para
# aguantar. Con dos, cruzadas como las dagas.
static func _defensa_espada(t: float, dual: bool) -> Dictionary:
	var s: float = sin(TAU * t)
	if dual:
		return {"bote": 0.12 * s, "agacha": 0.36, "paso": 0.4, "inclina": 0.02, "torsion": 0.1,
			"brazo_der": 1.35 + 0.02 * s, "brazo_izq": 1.35 + 0.02 * s, "junta_der": 0.9, "junta_izq": 0.9,
			"eje_der": Vector3(-0.6, 0.3, 0.75), "eje_izq": Vector3(0.6, 0.3, 0.75)}
	return {"bote": 0.12 * s, "agacha": 0.34, "paso": 0.45, "inclina": 0.0, "torsion": 0.25,
		"brazo_der": 1.4 + 0.02 * s, "brazo_izq": 1.3, "junta_izq": 0.6,
		"eje_der": Vector3(1.0, 0.25, 0.3)}


# LOS GOLPES. Todos salen de la guardia y vuelven a ella (primer y ultimo fotograma = la guardia), y el brazo
# que NO pega se queda como estaba. Arcos POR ENCIMA (el brazo pasa por pi, no por abajo: ver la revision de
# poses). 'x' = cuanto va la hoja hacia FUERA (+) o hacia dentro (-) del lado de la mano que pega.
#   tajo      el de siempre: se arma alto y fuera y baja en diagonal hacia dentro (golpe en 0,42)
#   reves     el de vuelta: de abajo-dentro sube hacia fuera (golpe en 0,42). El segundo del Doble tajo
#   barrido   el Quebrantador: el brazo al frente y la hoja TUMBADA barre de fuera a dentro con todo el
#             tronco (golpe en 0,45)
#   tajo_bajo los Tendones: agachado a fondo, la hoja tumbada a ras de las piernas (golpe en 0,45)
#   tajo_paso Cambio de ritmo: un tajo corto sin plantarse, las piernas corriendo (golpe en 0,45)
# Sus impactos, en CombatFX.IMPACTO_ANIM_MAPA: retocar uno = retocar su impacto.
static func _golpe_espada(t: float, base: String, dual: bool, izq: bool) -> Dictionary:
	var g: Dictionary = _guardia_espada(0.0, dual, 0)
	var p: Dictionary = g.duplicate()
	var k_brazo: String = "brazo_izq" if izq else "brazo_der"
	var k_eje: String = "eje_izq" if izq else "eje_der"
	var fuera: float = 1.0 if izq else -1.0     # hacia fuera de la mano que pega, en x del cuerpo
	var sg: float = -1.0 if izq else 1.0         # el tronco gira al reves con la izquierda
	var a0: float = float(g[k_brazo])
	var e0: Vector3 = g[k_eje] if g.has(k_eje) else Vector3(0.0, 0.35, -1.0)
	var t0: float = float(g["torsion"])
	var i0: float = float(g["inclina"])
	var ag0: float = float(g["agacha"])
	var a_keys: Array
	var x_keys: Array
	var tor: Array
	var av: Array
	var incl: Array
	var hoja_tumbada: bool = false
	var z_hoja: float = 0.0
	match base:
		"tajo_espada":
			a_keys = [[0.0, a0], [0.28, 3.55], [0.42, 1.75], [0.55, 0.5], [0.78, 0.6], [1.0, a0]]
			x_keys = [[0.0, 0.0], [0.28, 0.55], [0.55, -0.7], [1.0, 0.0]]
			tor = [[0.0, 0.0], [0.28, 0.45], [0.45, -0.35], [1.0, 0.0]]
			av = [[0.0, 0.0], [0.28, -1.0], [0.45, 3.2], [0.7, 2.0], [1.0, 0.0]]
			incl = [[0.0, 0.0], [0.28, -0.16], [0.45, 0.24], [1.0, 0.0]]
		"reves_espada":
			a_keys = [[0.0, a0], [0.25, 0.15], [0.42, 1.7], [0.55, 2.6], [0.78, 2.2], [1.0, a0]]
			x_keys = [[0.0, 0.0], [0.25, -0.7], [0.55, 0.6], [1.0, 0.0]]
			tor = [[0.0, 0.0], [0.25, -0.35], [0.45, 0.4], [1.0, 0.0]]
			av = [[0.0, 0.0], [0.25, -0.6], [0.45, 2.6], [0.7, 1.6], [1.0, 0.0]]
			incl = [[0.0, 0.0], [0.25, 0.14], [0.45, -0.06], [1.0, 0.0]]
		"barrido_espada":
			hoja_tumbada = true
			z_hoja = 0.1
			a_keys = [[0.0, a0], [0.3, 1.35], [0.45, 1.45], [0.62, 1.4], [1.0, a0]]
			x_keys = [[0.0, 0.0], [0.3, 1.0], [0.45, 0.0], [0.62, -1.0], [1.0, 0.0]]
			tor = [[0.0, 0.0], [0.3, 0.9], [0.45, 0.0], [0.62, -0.8], [1.0, 0.0]]
			av = [[0.0, 0.0], [0.3, -0.6], [0.45, 2.6], [0.62, 2.2], [1.0, 0.0]]
			incl = [[0.0, 0.0], [0.3, -0.04], [0.45, 0.16], [1.0, 0.0]]
			p["agacha"] = SpriteLienzo.tramos(t, [[0.0, ag0], [0.3, ag0 + 0.04], [0.45, ag0 + 0.08], [1.0, ag0]])
		"tajo_bajo_espada":
			hoja_tumbada = true
			z_hoja = -0.3
			a_keys = [[0.0, a0], [0.3, 0.95], [0.45, 0.62], [0.62, 0.55], [1.0, a0]]
			x_keys = [[0.0, 0.0], [0.3, 1.0], [0.45, 0.0], [0.62, -1.0], [1.0, 0.0]]
			tor = [[0.0, 0.0], [0.3, 0.7], [0.45, 0.0], [0.62, -0.6], [1.0, 0.0]]
			av = [[0.0, 0.0], [0.3, -0.4], [0.45, 2.2], [0.62, 1.8], [1.0, 0.0]]
			incl = [[0.0, 0.0], [0.3, 0.1], [0.45, 0.3], [0.7, 0.26], [1.0, 0.0]]
			p["agacha"] = SpriteLienzo.tramos(t, [[0.0, ag0], [0.3, 0.5], [0.45, 0.6], [0.7, 0.55], [1.0, ag0]])
			p["paso"] = SpriteLienzo.tramos(t, [[0.0, float(g["paso"])], [0.45, 0.72], [0.7, 0.7], [1.0, float(g["paso"])]])
		_:   # tajo_paso_espada
			a_keys = [[0.0, a0], [0.25, 2.6], [0.45, 1.3], [0.62, 0.6], [1.0, a0]]
			x_keys = [[0.0, 0.0], [0.25, 0.5], [0.62, -0.6], [1.0, 0.0]]
			tor = [[0.0, 0.0], [0.25, 0.3], [0.45, -0.25], [1.0, 0.0]]
			av = [[0.0, 0.0], [0.45, 2.0], [1.0, 0.0]]
			incl = [[0.0, 0.14], [0.45, 0.26], [1.0, 0.14]]
			p["paso"] = 0.55 * sin(TAU * t)
			p["bote"] = 0.8 * absf(sin(TAU * t))
	var a: float = SpriteLienzo.tramos(t, a_keys)
	var x: float = SpriteLienzo.tramos(t, x_keys)
	p[k_brazo] = a
	# La mano BARRE en horizontal con la hoja (x: + fuera, - dentro): el arco del efecto es de ciento y pico
	# grados, y con solo la torsion la mano de delante se quedaba quieta.
	p["abre_izq" if izq else "abre_der"] = ESPADA_ABRE * x
	p["torsion"] = t0 + sg * SpriteLienzo.tramos(t, tor)
	p["avance"] = SpriteLienzo.tramos(t, av)
	p["inclina"] = i0 + SpriteLienzo.tramos(t, incl)
	if base != "tajo_paso_espada":
		p["bote"] = 0.0
	# La hoja: en la linea del brazo (colgando = (0,0,-1), al frente = (0,1,0), arriba = (0,0,1)) con lo que
	# vaya hacia fuera o hacia dentro; o TUMBADA (barrido, tajo bajo), barriendo de fuera a dentro.
	var ek: Vector3
	if hoja_tumbada:
		ek = Vector3(x * fuera, 0.55 + 0.5 * (1.0 - absf(x)), z_hoja)
	else:
		ek = Vector3(x * fuera, sin(a), -cos(a))
	var k: float = SpriteLienzo.tramos(t, [[0.0, 0.0], [0.15, 1.0], [0.85, 1.0], [1.0, 0.0]])
	p[k_eje] = e0.lerp(ek.normalized(), k)
	# La izquierda pega por el lado LEJANO a la camara: un pelo de rumbo la saca (como golpe_izq).
	if izq:
		p["rumbo"] = SpriteLienzo.tramos(t, [[0.0, 0.0], [0.3, 0.2], [0.62, 0.3], [1.0, 0.0]])
	return p


# ------------------------------------------------------------
#  LA MAZA PEQUEÑA (26/09). Sin referencia suya: la propuesta es la de "maza y escudo" de siempre.
#  GUARDIA (su indicacion, 26/09: "las mazas delante apuntadas hacia arriba, en vez de un brazo hacia el lado";
#  no se agarran como la espada). Los brazos HACIA DELANTE (no abiertos: asi salia en T, "decia hacia alante"),
#  los puños delante a la altura del pecho y las mazas EN VERTICAL, la bola arriba. Con UNA, asi la derecha y
#  la otra mano delante, mas baja. Con DOS: las dos asi, una junto a la otra. Con ESCUDO: el '_esc' de siempre (el escudo delante; ver _pose).
#  Los nombres: '<anim>_maza' con una, '<anim>_maza2' con dos (y '_izq' si pega la izquierda). Los pide
#  MunecoJugador (_GUARDIA_DE / _con_su_guardia_base): quien anima pide 'mazazo_maza' sin saber si hay dos.
#  El eje del arma: del puño a la bola, en el sistema del cuerpo (x = izquierda, y = al frente, z = arriba).
# ------------------------------------------------------------
const MAZA_EJE := Vector3(-0.15, 0.2, 0.97)           # hacia ARRIBA, un pelo al frente y hacia fuera
const MAZA2_EJE_IZQ := Vector3(0.15, 0.2, 0.97)       # con dos, la izquierda igual, en espejo
const MAZA_ABRE_GUARDIA := 0.2   # los puños apenas separados: delante, no a los lados
const MAZA_ABRE := 0.7   # lo que el brazo abre/cruza en horizontal en los golpes (rad, con x = +-1)

static func _pose_maza(anim: String, t: float) -> Dictionary:
	var dual: bool = anim.contains("maza2")
	var izq: bool = anim.ends_with("_izq")
	var base: String = anim.replace("maza2", "maza").trim_suffix("_izq")
	match base:
		"guardia_maza": return _guardia_maza(t, dual, 0)
		"guardia_maza_and": return _guardia_maza(t, dual, 1)
		"guardia_maza_cor": return _guardia_maza(t, dual, 2)
		"desenvainar_maza": return _desenvainar_maza(t, dual)
		"defensa_maza": return _defensa_maza(t, dual)
		"mazazo_maza", "rompe_maza", "culatazo_maza", "demoledor_maza", "aplasta_maza", "aliento_maza", "muro_maza":
			return _golpe_maza(t, base, dual, izq)
	return {}


# 'm': 0 quieta, 1 andando, 2 corriendo.
static func _guardia_maza(t: float, dual: bool, m: int) -> Dictionary:
	var s: float = sin(TAU * t)
	var p: Dictionary = {"brazo_der": 1.2 + 0.04 * s, "abre_der": MAZA_ABRE_GUARDIA, "brazo_izq": 0.85 + 0.04 * s,
		"junta_izq": 0.25, "torsion": 0.1, "eje_der": MAZA_EJE, "bote": 0.25 * s, "inclina": 0.08, "agacha": 0.28,
		"paso": 0.42}
	if dual:
		p["brazo_izq"] = 1.2 + 0.04 * s
		p["abre_izq"] = MAZA_ABRE_GUARDIA
		p["eje_izq"] = MAZA2_EJE_IZQ
		p.erase("junta_izq")
		p["torsion"] = 0.05
	if m == 1:
		# Las piernas se CRUZAN (la regla de la receta: nunca 'guardia + 0.12 * s').
		p["paso"] = 0.10 + 0.40 * s
		p["bote"] = 0.4 * absf(s)
		p["agacha"] = float(p["agacha"]) - 0.06
		p["inclina"] = float(p["inclina"]) + 0.04
	elif m == 2:
		p["paso"] = 0.58 * s
		p["bote"] = 0.95 * absf(s)
		p["agacha"] = 0.10
		p["inclina"] = 0.22
		p["torsion"] = float(p["torsion"]) * 0.6
	return p


# SACARLA de la cadera y quedarse en su guardia (el ultimo fotograma ES la guardia). Con dos, las dos a la vez.
static func _desenvainar_maza(t: float, dual: bool) -> Dictionary:
	var fin: Dictionary = _guardia_maza(0.0, dual, 0)
	var der_keys := [[0.0, 0.15], [0.35, -0.10], [0.65, 1.4], [1.0, float(fin["brazo_der"])]]
	var izq_keys := [[0.0, 0.10], [0.35, -0.10 if dual else 0.0], [0.65, 0.7], [1.0, float(fin["brazo_izq"])]]
	var giro: float = clampf((t - 0.35) / 0.65, 0.0, 1.0)
	var colgando := Vector3(0.0, 0.35, -1.0).normalized()
	var p: Dictionary = {"brazo_der": SpriteLienzo.tramos(t, der_keys),
		"brazo_izq": SpriteLienzo.tramos(t, izq_keys),
		"agacha": SpriteLienzo.tramos(t, [[0.0, 0.08], [0.35, 0.14], [1.0, float(fin["agacha"])]]),
		"paso": SpriteLienzo.tramos(t, [[0.0, 0.0], [1.0, float(fin["paso"])]]),
		"torsion": SpriteLienzo.tramos(t, [[0.0, 0.0], [1.0, float(fin["torsion"])]]),
		"inclina": SpriteLienzo.tramos(t, [[0.0, 0.04], [0.35, 0.12], [1.0, float(fin["inclina"])]]),
		"bote": 0.0,
		"abre_der": float(fin["abre_der"]) * giro,
		"eje_der": colgando.lerp(fin["eje_der"], giro).normalized(),
		"sacando": -1.0 if t < 0.35 else giro}
	if dual:
		p["abre_izq"] = float(fin["abre_izq"]) * giro
		p["eje_izq"] = colgando.lerp(fin["eje_izq"], giro).normalized()
	return p


# EL DEFENDER: el mango ATRAVESADO delante del pecho, la bola hacia tu izquierda y arriba, y la otra mano
# apoyando. Con dos, cruzadas en X como las dagas.
static func _defensa_maza(t: float, dual: bool) -> Dictionary:
	var s: float = sin(TAU * t)
	if dual:
		return {"bote": 0.12 * s, "agacha": 0.36, "paso": 0.4, "inclina": 0.02, "torsion": 0.1,
			"brazo_der": 1.35 + 0.02 * s, "brazo_izq": 1.35 + 0.02 * s, "junta_der": 0.9, "junta_izq": 0.9,
			"eje_der": Vector3(-0.6, 0.3, 0.75), "eje_izq": Vector3(0.6, 0.3, 0.75)}
	return {"bote": 0.12 * s, "agacha": 0.34, "paso": 0.45, "inclina": 0.0, "torsion": 0.25,
		"brazo_der": 1.45 + 0.02 * s, "brazo_izq": 1.3, "junta_izq": 0.6,
		"eje_der": Vector3(1.0, 0.25, 0.45)}


# LOS GOLPES. Salen de la guardia y vuelven a ella (primer y ultimo fotograma = la guardia); el brazo que no
# pega se queda como estaba, salvo en las de LAS DOS A LA VEZ con dos mazas. Arcos POR ENCIMA (el brazo pasa
# por pi). 'x' = cuanto va la bola hacia FUERA (+) o hacia dentro (-) del lado de la mano que pega.
#   mazazo     el basico: arriba y atras, y cae en diagonal corta, con todo el tronco (golpe en 0,45)
#   rompe      el Rompepiernas: agachado a fondo, la bola barre a la altura de las rodillas (golpe en 0,45)
#   culatazo   con el MANGO: el brazo se recoge y sale recto al frente a la altura de la cara con la bola
#              hacia atras, el pomo por delante (golpe en 0,45)
#   demoledor  el Golpe demoledor: se alza a lo mas alto y cae VERTICAL hasta el suelo, doblado (golpe en 0,55).
#              Con dos, LAS DOS A LA VEZ, cada una por su lado
#   aplasta    el mazazo del Aplastamiento: de arriba abajo, corto (golpe en 0,42); sigue el golpe de escudo
#   aliento    el Grito: la maza ARRIBA del todo, el pecho fuera (en 0,3). Con dos, se entrechocan en alto
#   muro       el Muro: la maza (o las dos) contra el suelo a tus pies, "aqui me planto" (golpe en 0,45)
# Sus impactos, en CombatFX.IMPACTO_ANIM_MAPA: retocar uno = retocar su impacto.
static func _golpe_maza(t: float, base: String, dual: bool, izq: bool) -> Dictionary:
	var g: Dictionary = _guardia_maza(0.0, dual, 0)
	var p: Dictionary = g.duplicate()
	var k_brazo: String = "brazo_izq" if izq else "brazo_der"
	var k_eje: String = "eje_izq" if izq else "eje_der"
	var fuera: float = 1.0 if izq else -1.0
	var sg: float = -1.0 if izq else 1.0
	var a0: float = float(g[k_brazo])
	var e0: Vector3 = g[k_eje] if g.has(k_eje) else Vector3(0.0, 0.35, -1.0)
	var t0: float = float(g["torsion"])
	var i0: float = float(g["inclina"])
	var ag0: float = float(g["agacha"])
	var a_keys: Array
	var x_keys: Array = [[0.0, 0.0], [1.0, 0.0]]
	var tor: Array = [[0.0, 0.0], [1.0, 0.0]]
	var av: Array = [[0.0, 0.0], [1.0, 0.0]]
	var incl: Array = [[0.0, 0.0], [1.0, 0.0]]
	var ag: Array = [[0.0, ag0], [1.0, ag0]]
	var las_dos: bool = false      # con dos mazas, las dos a la vez (la izquierda, en espejo)
	var tumbada: bool = false      # la bola barre de lado (Rompepiernas)
	var mango_delante: bool = false   # el pomo por delante (Culatazo)
	match base:
		"mazazo_maza":
			a_keys = [[0.0, a0], [0.28, 3.35], [0.45, 1.35], [0.6, 0.75], [0.8, 0.95], [1.0, a0]]
			x_keys = [[0.0, 0.0], [0.28, 0.35], [0.55, -0.45], [1.0, 0.0]]
			tor = [[0.0, 0.0], [0.28, 0.35], [0.45, -0.35], [1.0, 0.0]]
			av = [[0.0, 0.0], [0.28, -0.8], [0.45, 3.0], [0.7, 1.8], [1.0, 0.0]]
			incl = [[0.0, 0.0], [0.28, -0.14], [0.45, 0.26], [1.0, 0.0]]
			ag = [[0.0, ag0], [0.45, ag0 + 0.1], [1.0, ag0]]
		"rompe_maza":
			tumbada = true
			a_keys = [[0.0, a0], [0.3, 1.0], [0.45, 0.62], [0.62, 0.55], [1.0, a0]]
			x_keys = [[0.0, 0.0], [0.3, 1.0], [0.45, 0.0], [0.62, -1.0], [1.0, 0.0]]
			tor = [[0.0, 0.0], [0.3, 0.8], [0.45, 0.0], [0.62, -0.7], [1.0, 0.0]]
			av = [[0.0, 0.0], [0.3, -0.4], [0.45, 2.2], [0.62, 1.8], [1.0, 0.0]]
			incl = [[0.0, 0.0], [0.3, 0.1], [0.45, 0.32], [0.7, 0.26], [1.0, 0.0]]
			ag = [[0.0, ag0], [0.3, 0.5], [0.45, 0.62], [0.7, 0.55], [1.0, ag0]]
			p["paso"] = SpriteLienzo.tramos(t, [[0.0, float(g["paso"])], [0.45, 0.72], [0.7, 0.7], [1.0, float(g["paso"])]])
		"culatazo_maza":
			mango_delante = true
			a_keys = [[0.0, a0], [0.3, 1.25], [0.45, 1.7], [0.62, 1.65], [1.0, a0]]
			x_keys = [[0.0, 0.0], [0.3, 0.25], [0.45, -0.1], [1.0, 0.0]]
			tor = [[0.0, 0.0], [0.3, 0.45], [0.45, -0.4], [0.62, -0.35], [1.0, 0.0]]
			av = [[0.0, 0.0], [0.3, -0.8], [0.45, 3.4], [0.62, 3.0], [1.0, 0.0]]
			incl = [[0.0, 0.0], [0.3, -0.06], [0.45, 0.14], [1.0, 0.0]]
		"demoledor_maza":
			las_dos = dual
			a_keys = [[0.0, a0], [0.35, 3.45], [0.55, 0.85], [0.62, 0.55], [0.8, 0.6], [1.0, a0]]
			tor = [[0.0, 0.0], [0.35, 0.15], [0.55, -0.1], [1.0, 0.0]]
			av = [[0.0, 0.0], [0.35, -1.0], [0.55, 3.0], [0.8, 2.4], [1.0, 0.0]]
			incl = [[0.0, 0.0], [0.35, -0.22], [0.55, 0.42], [0.8, 0.36], [1.0, 0.0]]
			ag = [[0.0, ag0], [0.35, ag0 - 0.1], [0.55, 0.6], [0.8, 0.55], [1.0, ag0]]
		"aplasta_maza":
			a_keys = [[0.0, a0], [0.25, 3.3], [0.42, 1.1], [0.58, 0.7], [0.8, 0.9], [1.0, a0]]
			x_keys = [[0.0, 0.0], [0.25, 0.15], [0.5, -0.2], [1.0, 0.0]]
			tor = [[0.0, 0.0], [0.25, 0.25], [0.42, -0.25], [1.0, 0.0]]
			av = [[0.0, 0.0], [0.25, -0.6], [0.42, 2.6], [0.7, 1.6], [1.0, 0.0]]
			incl = [[0.0, 0.0], [0.25, -0.12], [0.42, 0.3], [1.0, 0.0]]
			ag = [[0.0, ag0], [0.42, ag0 + 0.14], [1.0, ag0]]
		"aliento_maza":
			las_dos = dual
			# Con dos, las bolas se juntan arriba: cada brazo cruza un poco hacia el otro.
			a_keys = [[0.0, a0], [0.3, 3.05], [0.75, 3.0], [1.0, a0]]
			x_keys = [[0.0, 0.0], [0.3, -0.35 if dual else 0.1], [0.75, -0.3 if dual else 0.1], [1.0, 0.0]]
			tor = [[0.0, 0.0], [0.3, -0.25 if not dual else -0.2], [1.0, 0.0]]
			incl = [[0.0, 0.0], [0.3, -0.2], [0.75, -0.18], [1.0, 0.0]]
			ag = [[0.0, ag0], [0.3, 0.12], [0.75, 0.12], [1.0, ag0]]
		_:   # muro_maza
			las_dos = dual
			a_keys = [[0.0, a0], [0.25, 2.9], [0.45, 0.75], [0.7, 0.75], [1.0, a0]]
			tor = [[0.0, 0.0], [0.25, 0.1], [0.45, -0.1], [1.0, 0.0]]
			av = [[0.0, 0.0], [0.45, 1.2], [1.0, 0.0]]
			incl = [[0.0, 0.0], [0.25, -0.1], [0.45, 0.3], [0.7, 0.26], [1.0, 0.0]]
			ag = [[0.0, ag0], [0.25, ag0 - 0.06], [0.45, 0.5], [0.7, 0.48], [1.0, ag0]]
	var a: float = SpriteLienzo.tramos(t, a_keys)
	var x: float = SpriteLienzo.tramos(t, x_keys)
	p[k_brazo] = a
	var k_abre: String = "abre_izq" if izq else "abre_der"
	p[k_abre] = float(g.get(k_abre, 0.0)) + MAZA_ABRE * x
	p["torsion"] = t0 + sg * SpriteLienzo.tramos(t, tor)
	p["avance"] = SpriteLienzo.tramos(t, av)
	p["inclina"] = i0 + SpriteLienzo.tramos(t, incl)
	p["agacha"] = SpriteLienzo.tramos(t, ag)
	p["bote"] = 0.0
	# El eje: del puño a la bola en la linea del brazo (colgando = (0,0,-1), al frente = (0,1,0), arriba =
	# (0,0,1)); TUMBADA barriendo de fuera a dentro; o al reves (el pomo por delante) en el Culatazo.
	var ek: Vector3
	if tumbada:
		ek = Vector3(x * fuera, 0.55 + 0.5 * (1.0 - absf(x)), -0.3)
	elif mango_delante:
		ek = Vector3(x * fuera * 0.4, -sin(a) * 0.6, 0.8)
	else:
		ek = Vector3(x * fuera, sin(a), -cos(a))
	var k: float = SpriteLienzo.tramos(t, [[0.0, 0.0], [0.15, 1.0], [0.85, 1.0], [1.0, 0.0]])
	p[k_eje] = e0.lerp(ek.normalized(), k).normalized()
	# LAS DOS A LA VEZ: la izquierda hace lo mismo en espejo (el arco con su x hacia su fuera).
	if las_dos and not izq:
		var ei: Vector3 = g["eje_izq"] if g.has("eje_izq") else Vector3(0.0, 0.35, -1.0)
		p["brazo_izq"] = a
		p["abre_izq"] = float(g.get("abre_izq", 0.0)) + MAZA_ABRE * x
		p["eje_izq"] = ei.lerp(Vector3(-x * fuera, sin(a), -cos(a)).normalized(), k).normalized()
		p["torsion"] = SpriteLienzo.tramos(t, [[0.0, t0], [0.3, 0.0], [0.7, 0.0], [1.0, t0]])
	# La izquierda pega por el lado LEJANO a la camara: un pelo de rumbo la saca (como golpe_izq).
	if izq:
		p["rumbo"] = SpriteLienzo.tramos(t, [[0.0, 0.0], [0.3, 0.2], [0.62, 0.3], [1.0, 0.0]])
	return p
