# ============================================================
#  minotauro_sprites.gd  (class_name MinotauroSprites)
#  Sprite del MINOTAURO dibujado por codigo, con el motor comun (SpriteLienzo) y la camara de 45
#  grados que comparten todos los bichos. Es el JEFE DEL PISO 12 (scenes/actors/enemy/guardian_rango.tres,
#  enganchado en game.gd BOSSES): 1200 de vida, otorga rango 2 y reaparece cada 15 minutos.
#
#  ES EL PRIMER HUMANOIDE DEL JUEGO -- familia 6, HUMANOIDE, y esta el solo en ella -- y el tercer
#  bipedo con brazos despues del golem y el coloso. Pero aquellos son ESTATUAS: piezas de piedra
#  apiladas que se mueven a trompicones. Este es de CARNE, y eso cambia lo que hay que dibujar:
#    * TORSO EN V: hombros anchisimos y cintura estrecha. Es lo que separa a un humanoide musculado
#      de un monigote, y de un pegote de barro.
#    * PIERNAS DIGITIGRADAS, o sea que apoya en la PEZUÑA y lleva el corvejon a media altura, hacia
#      atras. Un minotauro con piernas humanas es un tio con casco.
#    * CABEZA BOVINA con el testuz bajado, CUERNOS curvos y ANILLA en el hocico. Los cuernos son su
#      silueta: si se le quitan, no hay minotauro.
#
#  Sus tres habilidades mandan sobre las animaciones, y cada una pide una cosa distinta:
#    * `minotauro_cornada` (x1.9 + sangrado) -> embiste con la cabeza LADEADA, clavando un cuerno.
#      Es su golpe iconico, asi que es el que se dibuja como 'embestida'.
#    * `minotauro_pisoton` (x1.7, area_max 99) -> levanta una pierna y la deja caer.
#    * `minotauro_bramido` (dano_mult 0, furia sobre si mismo) -> puro gesto: se yergue, echa la
#      cabeza atras y abre los brazos.
#
#  ESCALA 2,4 -> 3,1 (ver el .tres). A 2,4 el jefe del piso 12 se leia mas pequeño que el golem de
#  arcilla del piso 7, que es de las cosas que mas rompen una sala de jefe. A 3,1 sus 40 unidades de
#  alto dan 124 px en pantalla: por encima de los 102 del golem y del trent, y por debajo de los 185
#  del coloso -- que sigue siendo el mas alto del juego a proposito. Un jefe no tiene que ser lo mas
#  grande, tiene que ser lo mas grande DE SU SITIO.
#
#  El TAMAÑO se consigue con MAS CELDAS, no con celdas mas gordas: ver SpriteLienzo.UNIDADES_POR_CELDA.
# ============================================================

extends RefCounted
class_name MinotauroSprites

const FRAMES := 8

# --- El minotauro mirando al SUR, en unidades de MUNDO (origen = donde pisa, +Y hacia donde mira,
# +Z hacia arriba). A escala 1.0 mide unas 40 unidades del suelo a la coronilla. ---
#
# LAS MEDIDAS DE MUNDO SE QUEDAN CONTENIDAS Y EL TAMAÑO LO PONE LA ESCALA: el lienzo sale de
# (unidades x escala), asi que dibujarlo con medidas enormes Y escala grande seria multiplicar dos
# veces. Es la nota del coloso.
const ALTO_MUNDO := 40.0

# --- LAS PIERNAS, DIGITIGRADAS: pezuña en el suelo, caña larga, corvejon a media altura y hacia
# ATRAS, y muslo grueso. Es la pierna de un toro, no la de una persona.
#
# PIERNA_X (4,0) muy por dentro del semiancho de la cadera (5,6): una pieza que nace en el borde de
# la elipse de otra nace donde aquella tiene grosor CERO, y flota. Es la leccion que costo tres
# vueltas con las patas del acechador y que aqui va puesta de entrada.
const PIERNA_X := 4.0
const PEZUNA := Vector3(0.0, 1.2, 1.5)
const PEZUNA_R := Vector3(2.1, 2.9, 1.5)
const CANA := Vector3(0.0, 0.2, 6.4)
const CANA_R := Vector3(1.8, 2.0, 4.6)
# EL CORVEJON VA HACIA ATRAS: es lo que dibuja la Z de la pata trasera de un toro. Sin el, la pierna
# es un tubo recto y el bicho vuelve a ser un humano con cabeza de vaca.
const CORVEJON := Vector3(0.0, -2.2, 12.0)
const CORVEJON_R := Vector3(2.4, 2.8, 3.0)
const MUSLO := Vector3(0.0, 0.4, 16.4)
const MUSLO_R := Vector3(3.0, 3.6, 4.4)
const PASO_LARGO := 2.6
const PASO_ALZA := 1.8

# CADERA: ancha y baja. Es la base del torso en V.
const CADERA := Vector3(0.0, 0.0, 20.2)
const CADERA_R := Vector3(5.6, 4.2, 3.2)
# CINTURA: LO ESTRECHO del bicho. Sin este estrangulamiento no hay V, y sin V el torso es un barril.
const CINTURA := Vector3(0.0, 0.2, 24.0)
const CINTURA_R := Vector3(4.4, 3.6, 2.8)
# PECHO: lo ANCHO. 8,6 de semiancho contra los 4,4 de la cintura -- casi el doble, y esa proporcion
# es todo el personaje.
const PECHO := Vector3(0.0, 0.4, 28.4)
const PECHO_R := Vector3(8.6, 5.0, 5.2)
# Los PECTORALES, dos bultos por delante: son lo que hace que el pecho se lea como carne y no como
# una caja. Van 'solo_sobre' el cuerpo para no derramarse.
const PECTORAL := Vector3(3.6, 3.4, 29.2)
const PECTORAL_R := Vector3(3.4, 2.6, 2.6)

# HOMBROS: anchos y redondos. Y ADELANTADOS (HOMBRO_Y positivo), que NO es cosa del dibujo:
# la prueba que decide que brazo va delante es la Y del hombro YA GIRADA, y con la Y en CERO exacto
# da falso para los DOS -- el bicho de frente dibujaria sus dos brazos como "el de detras",
# escorzados y pegados al cuerpo. Es la trampa que ya mordieron el golem y el coloso.
#
# Y VAN POR FUERA DEL ANCHO DEL PECHO, QUE ESTUVO AL REVES. Estaban en 8,2 contra los 8,6 de
# PECHO_R.x, o sea METIDOS: el brazo nacia DENTRO de la elipse del torso y de frente se lo tragaba
# entero -- lo que se veia no era un bicho con los brazos pegados, era un bicho SIN BRAZOS, un bulto
# con cuernos. Y como lo que asomaba dependia de la pose, el puñetazo no se leia por ningun lado.
# Es literalmente la misma leccion que ya esta escrita en PoseJugador (hombro 9,8 contra medio pecho
# 8,8): con el hombro un pelin por fuera, el brazo asoma SIEMPRE por el costado y su silueta deja de
# depender de lo que haga el torso.
const HOMBRO_X := 9.4
const HOMBRO_Y := 0.9
const HOMBRO_Z := 29.0
const HOMBRO_R := Vector3(3.6, 3.4, 3.4)
# Y LA DE DETRAS SE BAJA A MANO: de perfil, la que se va al fondo SUBE en pantalla 0,707 unidades por
# cada una de profundidad, asi que se plantaba a la altura de la cabeza y el bicho enseñaba una bola
# flotando sobre el hombro. Otra del coloso.
const HOMBRO_BAJA_DETRAS := 2.2

# --- LOS BRAZOS: cadenas de piezas con CODO, largas y gruesas, rematadas en un puño.
#
# EL PASO TIENE QUE SOBRAR, NO CUADRAR: 2,4 de paso contra un radio de 2,2 en la muñeca (4,4 de
# diametro). Un paso que "cuadra justo" con el diametro deja las piezas TANGENTES, se rozan en una
# linea y el puño se despega en cuanto el brazo se mueve. Al coloso le costo 31 fotogramas rotos.
#
# Y HACE FALTA EL CODO: de perfil los dos brazos caen sobre el eje de la pantalla -- lo que los
# separa a lo ancho pasa a ser PROFUNDIDAD -- asi que un brazo recto se pinta encima del torso y de
# las piernas y tapa el bicho entero.
const BRAZO_SEGMENTOS := 6
const BRAZO_PASO := 2.4
const BRAZO_R0 := 2.9              # en el hombro
const BRAZO_R1 := 2.2              # en la muñeca
const BRAZO_BAJA := 2.0            # nace por debajo del centro del hombro, o lo tapa entero
# EL ARCO DEL BRAZO VA EN EL PLANO DE DELANTE (0 = a plomo, PI/2 = hacia delante, 2,6 = sobre la
# cabeza) y NO en el de los costados: interpolando por los costados, el camino de "colgando" a "en
# alto" pasa por la HORIZONTAL y el bicho se queda EN CRUZ, ocupando el doble de ancho.
const BRAZO_ANG_REPOSO := 0.12
const BRAZO_ANG_ALTO := 2.35
# --- POR QUE COLGABA COMO UN PALO ABIERTO, Y COMO SE ARREGLA.
#
# EL BRAZO SE ABRIA EN TODOS LOS SEGMENTOS. 'abre' estaba en 0,55 por paso y siempre hacia FUERA: a
# los seis segmentos el puño acababa 5,8 unidades mas afuera que el hombro y, con los hombros ya a
# 8,2, se plantaba a 14 del eje -- fuera del cuerpo. Por eso los brazos salian tiesos y en jarra en
# vez de colgando: no era el codo, era que el brazo no BAJABA, se ALEJABA.
#
# LA FORMA BUENA ESTA EN EL PERSONAJE DEL JUGADOR, que es lo que pidio el usuario: mirando
# PoseJugador, el hombro esta en x 9,8, el CODO en 10,2 y la MANO en 8,6. O sea que el brazo sale un
# PELIN hacia fuera y el ANTEBRAZO SE VUELVE HACIA DENTRO, bastante mas de lo que salio -- la mano
# acaba mas metida que el hombro, rozando la cadera. Eso es un brazo colgando; una linea que se abre
# sin parar es un aspa.
#
# Aqui va lo mismo dicho en el idioma de la cadena: el desvio a lo ancho CAMBIA DE SIGNO en el codo.
# Con estos dos numeros el puño acaba en x 6,4 -- por dentro del hombro y justo por fuera de la
# cadera (5,6) --, que es el "roza el cuerpo" del jugador.
const BRAZO_ABRE := 0.14           # el brazo, hacia FUERA
# El antebrazo vuelve hacia dentro, pero SIN PASARSE: con 0,52 el puño acababa en x 6,4 y de frente
# se metia detras de la cadera. Con 0,38 cae en 7,5 -- por fuera del taparrabos (5,9) y por dentro
# del hombro --, que es el "roza el cuerpo" del jugador sin llegar a esconderse en el.
const BRAZO_METE := 0.38
# Cuanto tira el brazo hacia DELANTE por cada paso. Va DENTRO de la direccion, que se normaliza antes
# de avanzar: asi BRAZO_PASO es una distancia de verdad y el presupuesto de solape de aqui abajo es
# exacto. Antes el desvio a lo ancho se sumaba ENCIMA de un paso ya completo, o sea que el paso real
# no era 2,4 sino 2,46 -- poco, pero era un numero que nadie controlaba.
#
# Y TIENE QUE LLEGAR: es el eje por el que el antebrazo se echa al frente en la pose armada (la 'L'
# del puñetazo) y por el que sale el brazo entero al extenderlo. Corto, el codo se dobla pero el
# antebrazo no va a ningun sitio y la L no se lee.
const BRAZO_ADELANTA := 0.85
const PUNO_R := Vector3(3.0, 2.9, 2.9)

# --- EL CODO. Es UN SALTO DE ANGULO EN UNA JUNTA, no una curvatura repartida entre los seis
# segmentos: repartida lo que sale es un ARCO, y un arco no dobla -- el brazo se comba entero y sigue
# leyendose como un tubo tieso, que es justo de lo que se quejaba el bicho.
#
# SE PUEDE DOBLAR MUCHISIMO PORQUE EL PASO NO CAMBIA. Un salto de angulo D en una junta separa el
# centro siguiente 2*PASO*sin(D/2): con D = 1,75 son 2*2,4*0,77 = 3,7 unidades, contra los 4,9 que
# suman los radios de las dos piezas de esa junta (2,5 y 2,4). SOBRA, y sobraria igual con el codo
# cerrado del todo. Esa es toda la ventaja de la cadena por pasos unitarios: doblarla por un sitio no
# la descose mientras el paso siga siendo el mismo.
const BRAZO_CODO_SEG := 3          # en que junta se dobla: mitad brazo, mitad antebrazo
const BRAZO_CODO := 1.75           # cuanto se pliega con 'codo' = 1
# Y VA DOBLADO DE PARTIDA. Un brazo colgando recto del todo es un palo; el codo suelto de algo que
# pesa se queda siempre un poco cerrado, y esas dos decimas son la mitad de la sensacion de carne.
const BRAZO_CODO_REPOSO := 0.22

# --- EL PUÑETAZO (su golpe basico, fx_basico = GOLPETAZO). Pega SIEMPRE EL MISMO BRAZO del cuerpo y
# no "el de delante": si cambiara de mano segun por donde se le mire, al girar el bicho el golpe
# saltaria de un lado a otro. Es la misma razon por la que el hacha iba en un lado fijo.
#
# SON TRES POSES, Y LAS DIBUJO EL USUARIO: una raya vertical, una L, y una raya horizontal.
#
#   1. COLGANDO      brazo a plomo, codo casi suelto.        |
#   2. ARMADO        el HOMBRO NO SE MUEVE: se dobla el       L    (codo a ~90, antebrazo al frente)
#                    codo y el antebrazo se echa al frente.
#   3. EXTENDIDO     ahora si sube el hombro, y el codo      ---   (todo el brazo al frente)
#                    se estira: el brazo entero al frente.
#
# LO QUE LO HACE NATURAL ES QUE EL HOMBRO NO ENTRE HASTA EL FINAL. Moviendo hombro y codo a la vez
# desde el principio, el brazo BARRE un arco y parece que empuja; doblando primero solo el codo y
# estirando despues, primero se ARMA y luego SALE, que es como se tira un puñetazo.
const GOLPE_LADO := 1.0
# El hombro sube MUY POCO al armar -- lo que dobla es el codo, como en el dibujo --, pero algo sube:
# a plomo del todo, la 'L' se forma a la altura de la cadera y de frente queda tapada por el
# taparrabos. En 0,55 el antebrazo sale a la altura del pecho, que es donde se ve.
const BRAZO_ANG_ARMADO := 0.55
const BRAZO_ANG_GOLPE := 1.57      # extendido: el brazo entero horizontal hacia delante

# CUELLO: corto y GRUESO. En un toro el cuello es mas ancho que la cabeza, y ese es medio bicho.
# LA SEPARACION CABEZA-HOMBROS SE MIDE EN (y - z), NO EN ALTURA. Con la camara a 45 grados la altura
# en pantalla sale de (y - z), y el margen tiene que superar el RADIO EN PANTALLA de la cabeza o los
# tres bultos de arriba (hombro, cabeza, hombro) se leen como una fila -- la cabeza sale HUNDIDA
# entre los hombros, que es como salio al primer intento. Aqui: hombros a 29,0 y cabeza a 39,0, o sea
# 10 unidades, que en pantalla son 5,9 descontando lo que la cabeza va adelantada: 15,8 celdas contra
# los 10,8 de su radio. Es la leccion del golem y del coloso, las dos veces por lo mismo.
const CUELLO := Vector3(0.0, 1.4, 34.2)
const CUELLO_R := Vector3(3.4, 3.0, 3.2)
# CABEZA: GRANDE -- casi tan ancha como el pecho -- y alargada hacia delante (es un craneo bovino, no
# una bola), con el testuz BAJADO. El tamaño sale de la referencia que paso el usuario: ahi la cabeza
# domina al bicho y el cuello casi no existe. Con una cabeza a escala humana sobre esos hombros lo
# que sale es un tio disfrazado.
const CABEZA := Vector3(0.0, 2.6, 39.0)
const CABEZA_R := Vector3(4.2, 4.4, 3.9)
const HOCICO := Vector3(0.0, 7.0, 37.0)
const HOCICO_R := Vector3(3.0, 3.0, 2.6)
# JUSTO ENCIMA DEL MORRO, no en la frente: a 40,4 caian a la altura de la raiz de los cuernos y
# parecian dos remaches del craneo. Una cara se ordena de abajo arriba -- morro, ojos, cuernos -- y
# los ojos tienen que quedar pegados a la mancha clara del hocico para leerse como ojos.
const OJO := Vector3(2.5, 5.4, 39.5)
const OJO_R := Vector3(0.85, 0.85, 0.85)
const OREJA := Vector3(4.4, 2.0, 39.6)
const OREJA_R := Vector3(2.0, 1.1, 1.2)

# --- LOS CUERNOS: SU SILUETA. Salen de lo alto de los lados de la cabeza, van hacia FUERA, suben y
# se curvan hacia DELANTE. En cadena, como los colmillos del jabali: una sola pieza alargada no se
# curva, y un cuerno recto no se lee como un cuerno.
#
# Van en HUESO, bien claro. Sobre un bicho pardo rojizo, un cuerno de su mismo tono desaparece -- y
# lo que no puede pasar es que no se le vean los cuernos.
# SON ENORMES Y MUY ABIERTOS, en lira: en la referencia del usuario los cuernos son casi tan anchos
# como los hombros y es LO PRIMERO que se ve del bicho. Unos cuernos discretos convierten a un
# minotauro en un hombre-toro cualquiera.
const CUERNO_SEGMENTOS := 8
const CUERNO_BASE := Vector3(3.4, 2.2, 41.6)
const CUERNO_PASO := 1.5           # contra un radio final de 0,9 (1,8 de diametro): SOBRA
const CUERNO_R0 := 1.5
const CUERNO_R1 := 0.9
const CUERNO_ABRE := 0.88          # cuanto se va hacia fuera al empezar
const CUERNO_GIRO := 0.27          # y cuanto se cierra hacia delante y arriba en cada paso

# LA ANILLA del hocico: el detalle que lo remata. Un arco de piezas colgando de la nariz.
const ANILLA_SEGMENTOS := 7
const ANILLA := Vector3(0.0, 7.8, 35.8)
const ANILLA_R := 1.9
const ANILLA_GROSOR := 0.52

# --- EL CINTO: taparrabos y brazaletes, los dos en cuero oscuro. Salen de la referencia, y no son
# adorno: son lo que le da ESCALA al bicho. Un cuerpo desnudo del mismo tono de arriba abajo no dice
# lo grande que es; en cuanto lleva encima algo hecho por alguien, se lee el tamaño.
# CORTO. Al primer intento bajaba tres unidades mas y era una mancha negra desde la cintura hasta
# medio muslo: se comia las piernas enteras y el bicho salia con las patas cortisimas. Una prenda
# oscura sobre un cuerpo claro pesa mucho mas de lo que mide.
const TAPARRABOS := Vector3(0.0, 0.0, 19.8)
const TAPARRABOS_R := Vector3(5.9, 4.4, 2.1)
const FALDON := Vector3(0.0, 3.2, 18.4)
const FALDON_R := Vector3(2.6, 1.8, 2.4)
# El brazalete va en el segmento del antebrazo, cerca del puño.
const BRAZALETE_SEG := 4
const BRAZALETE_R := Vector3(2.7, 2.6, 2.6)

# EL HACHA SE FUE, y no por sitio: NO LA USABA. Ninguna de sus tres habilidades es un hachazo -- son
# cornada, pisoton y bramido -- y un arma que el bicho no levanta nunca no cuenta lo que hace, solo
# ocupa una mano y obliga a un lienzo mas ancho del que necesita. Lo que le da escala al bicho ya lo
# hacen el taparrabos y los brazaletes (ver CUERO_T), que ademas no mienten sobre como pelea.

# LA CORNADA: viaja lo suyo, pero menos que una carga de bestia -- es un jefe pesado.
const LUNGE_DIST := 9.0
# ENCAJAR UN GOLPE: tiene 45 de resistencia y 1200 de vida. Acusa poco, pero mas que la bestia
# acorazada (que es lo que menos se mueve): es carne, no coraza.
const ENCAJE_RETRO := 0.22

# --- EL LIENZO, en multiplos de la altura. RECTANGULAR y con el origen BAJO, como el coloso: el
# origen es el punto que pisa y el bicho crece hacia ARRIBA.
# ANCHO lo manda la envergadura de brazos y cuernos; ARRIBA, los cuernos con el brazo en alto del
# bramido; ABAJO, que al hincarse de rodillas se desparrama tambien en PROFUNDIDAD -- y la
# profundidad BAJA en pantalla. Es la leccion del cadaver del golem.
# SIN EL HACHA, EL ANCHO LO MANDA LA CORNADA: es la que VIAJA (9 unidades), y en las diagonales ese
# viaje se va entero a lo ancho -- 6,4 unidades de puro desplazamiento antes de contar el bicho. Con
# el hacha hacian falta 1,58 porque colgaba por fuera del puño de un brazo ya abierto y el avance se
# la llevaba todavia mas lejos.
#
# EL NUMERO ESTA MEDIDO, NO PUESTO A OJO: el horno avisa de que fotogramas TOCAN EL BORDE de su
# lienzo, y a 1,34 se salian tres de la cornada (dirs 1 y 5, que son justo las diagonales). 1,46 los
# mete todos con margen. Ver herramientas/hornear_sprites.bat.
const LIENZO_ANCHO := 1.46
const LIENZO_ARRIBA := 1.28
const LIENZO_ABAJO := 0.34

# TONOS propios (el motor no sabe que es cada uno; solo mapea indice -> color, ver _colores).
enum Tono { VACIO, SOMBRA_SUELO, BORDE, PEZUNA_T, PIERNA_OSC, SOMBRA, BASE, CLARO, HOCICO_T,
	CUERNO_T, ANILLA_T, OJO_T, CUERO_T }

# --- LA PIERNA, PIEZA A PIEZA, con el reparto de CADA movimiento en columnas. Antes las cuatro
# llamadas llevaban sus coeficientes escritos a mano en medio del dibujo (0,5 / 0,7 / 1 / 1 para la
# zancada y nada para lo demas), y por eso la pierna era un BLOQUE: se desplazaba entera y no se
# doblaba por ningun sitio. Es el patron del coloso (_pierna), donde cada sillar lleva su 'dobla' y
# su 'alza'.
#
#   paso      -> cuanto le toca de la ZANCADA (adelante y atras al andar)
#   alza      -> cuanto le toca de LEVANTAR EL PIE al andar
#   alza_pisa -> y cuanto de levantar LA PIERNA ENTERA en el pisoton. Es una columna aparte y CASI
#     UNIFORME a proposito, y ahi esta el truco del pisoton: lo que ata cuanto puede subir un pie no
#     es el motor, es la DIFERENCIA de reparto entre dos piezas vecinas. Con el perfil de andar
#     (0,10 a 1,00) la diferencia mayor es 0,40 y el pie no puede subir de 2,6 unidades -- siete
#     pixeles, que en pantalla no es un pisoton, es un tropiezo. Subiendo la pierna casi RIGIDA
#     desde la cadera la diferencia mayor baja a 0,45 contra la junta mas holgada y el pie sube 5,0.
#     Y ademas es lo que hace de verdad un bicho que va a pisar fuerte: no dobla la rodilla, alza el
#     muslo.
#   dobla_y -> cuanto se va hacia ATRAS al doblarse la rodilla
#   dobla_z -> y cuanto BAJA. Ojo: NO es monotono. Al hincarse, quien baja de verdad es el CORVEJON
#     (-5,4); la pezuña casi no se mueve (-0,6) porque se queda apoyada en el suelo. Una escalera
#     creciente aqui hundiria el pie bajo tierra, que es lo contrario de arrodillarse.
#
# LA JUNTA QUE MANDA ES CORVEJON-CAÑA y es la que ata todos estos numeros: sus centros estan a
# sqrt(2,4² + 5,6²) = 6,09 y sus radios en Z suman 3,0 + 4,6 = 7,6, o sea SOLAPE 1,5. Cualquier
# movimiento nuevo tiene que cumplir (diferencia de reparto) x amplitud <= 1,5 o la pierna se abre
# por ahi. Ya se partio una vez por esto (ver el comentario del plegado, mas abajo).
const PIERNA_PIEZAS := [
	{"c": MUSLO, "r": MUSLO_R, "paso": 0.45, "alza": 0.10, "alza_pisa": 0.35,
		"dobla_y": -0.6, "dobla_z": -4.2, "tono": -1},
	{"c": CORVEJON, "r": CORVEJON_R, "paso": 0.70, "alza": 0.45, "alza_pisa": 0.80,
		"dobla_y": -1.5, "dobla_z": -5.4, "tono": Tono.PIERNA_OSC},
	{"c": CANA, "r": CANA_R, "paso": 1.00, "alza": 0.85, "alza_pisa": 0.95,
		"dobla_y": -2.6, "dobla_z": -3.4, "tono": Tono.PIERNA_OSC},
	{"c": PEZUNA, "r": PEZUNA_R, "paso": 1.00, "alza": 1.00, "alza_pisa": 1.00,
		"dobla_y": -3.4, "dobla_z": -0.6, "tono": Tono.PEZUNA_T},
]

# EL PISOTON levanta UNA pierna sola, fuera del ciclo de andar, y SIEMPRE LA MISMA (por lo mismo que
# el puñetazo: si cambiara de pata al girar, el bicho pisaria con una u otra segun por donde se le
# mire).
#
# 5,0 Y NO MAS, y el numero sale de la columna 'alza_pisa': la diferencia mayor entre dos piezas
# vecinas es 0,45 (muslo-corvejon) contra los 2,3 de solape de esa junta, o sea 0,45 x 5,0 = 2,25.
# Entra justo. Y por arriba manda la CADERA, que no sube: el muslo se le despega si se aleja mas de
# 3,8 unidades, y 0,35 x 5,0 = 1,75 deja margen de sobra.
const PISA_LADO := 1.0
const PISA_ALZA := 5.0

# --- LA CABEZA GIRA SOBRE EL CUELLO. Hasta ahora 'cabeza' solo la SUBIA Y LA BAJABA en Z, y con eso
# no hay bramido: para que el morro apunte al cielo la cabeza tiene que ROTAR, no ascender.
#
# EL PIVOTE ES LA BASE DEL CUELLO, no su centro: girando alrededor de su propio centro el cuello no
# se movería y la junta con la cabeza se abriria el doble.
#
# Y EL GIRO SE REPARTE, como todo lo demas: el cuello se lleva TESTUZ_CUELLO y la cabeza va entera.
# Sin reparto, el radio cuello-cabeza (4,95) contra el solape de esa junta (3,2 + 3,9 - 4,95 = 2,15)
# limita el giro a 0,43 radianes, o sea 25 grados, que no es un bramido -- es mirar hacia arriba.
# Repartiendo se llega a los 0,8 (46 grados) del bramido con 1,65 de margen todavia libre.
const TESTUZ_PIVOTE := Vector3(0.0, 0.8, 31.0)
const TESTUZ_CUELLO := 0.40
const TESTUZ_MAX := 0.80

# --- Vectores de las 8 direcciones (pantalla: +Y es hacia ABAJO). Mismo orden que los demas
# generadores y que el _dir8 de enemy.gd: 0=S 1=SE 2=E 3=NE 4=N 5=NW 6=W 7=SW. ---
const DIR_VECS := [
	Vector2(0, 1), Vector2(0.7, 0.7), Vector2(1, 0), Vector2(0.7, -0.7),
	Vector2(0, -1), Vector2(-0.7, -0.7), Vector2(-1, 0), Vector2(-0.7, 0.7),
]

const COLOR_PASOS := 6.0
static var _cache: Dictionary = {}
static var _cache_plantillas: Dictionary = {}


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t), ed.escala_visual)


# La CLAVE de esta variante: la del cache y la del fichero horneado (ver SpriteLienzo.hornear).
static func clave_de(ed: EnemyData, t: float) -> String:
	return _clave(SpriteLienzo.cuantizar_hsv(ed.color_visual(t), COLOR_PASOS),
		snappedf(ed.escala_visual, 0.05))


static func _clave(col: Color, esc: float) -> String:
	return "minotauro_%s_%.2f" % [col.to_html(false), esc]


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(escala: float = 1.0) -> int:
	return _lienzo(escala).x


static func dimensiona_por_escala() -> bool:
	return true


# El CUERPO en planta (ancho, largo) para la colision: LO MARCAN LAS PEZUÑAS, que es lo que pisa el
# suelo. Los BRAZOS y los CUERNOS se quedan FUERA a proposito, igual que las alas de la gargola: un
# jefe que no cupiera por su propia sala porque abre los brazos seria absurdo, y ademas su ancho de
# hombros (17,2) no cabe por un vano de 96 px a escala 3,1.
#
# Sale en 12,2 x 13,6 unidades = unos 40 px de huella a escala 3,1: el mismo orden que los 44,8 del
# golem (47% del vano) y los 48 del coloso (la mitad). Un jefe ocupa media sala, no la sala.
static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	var ancho: float = (PIERNA_X + PEZUNA_R.x) * 2.0
	var largo: float = (PEZUNA.y + PEZUNA_R.y) - (CORVEJON.y - CORVEJON_R.y) + PASO_LARGO
	return Vector2(ancho, largo) * escala


# El lienzo, RECTANGULAR: ancho x alto en celdas.
static func _lienzo(escala: float) -> Vector2i:
	var alto_celdas: float = ALTO_MUNDO * escala / SpriteLienzo.UNIDADES_POR_CELDA
	var w: int = int(ceil(alto_celdas * LIENZO_ANCHO))
	var h: int = int(ceil(alto_celdas * (LIENZO_ARRIBA + LIENZO_ABAJO)))
	return Vector2i(w + (w % 2), h + (h % 2))


# Donde cae el ORIGEN (el punto que pisa el suelo) dentro del lienzo.
static func _origen(escala: float) -> Vector2:
	var lz: Vector2i = _lienzo(escala)
	var alto_celdas: float = ALTO_MUNDO * escala / SpriteLienzo.UNIDADES_POR_CELDA
	return Vector2(float(lz.x) * 0.5, alto_celdas * LIENZO_ARRIBA)


static func generar(color: Color = Color(0.55, 0.34, 0.2), escala: float = 1.0) -> SpriteFrames:
	# cuantizar_hsv y no cuantizar a secas: el pardo rojizo es un color apagado y redondear canal a
	# canal le cambiaria el TONO -- dos canales parecidos caen en el mismo escalon y sale un oliva.
	# Le paso lo mismo al Rey rata en su dia.
	var col: Color = SpriteLienzo.cuantizar_hsv(color, COLOR_PASOS)
	var esc: float = snappedf(escala, 0.05)      # se cuantiza tambien, o el cache no acierta
	var clave: String = _clave(col, esc)
	if _cache.has(clave):
		return _cache[clave]
	var anims: Array = []
	_montar_idle(anims, esc)
	_montar_walk(anims, esc)
	_montar_embestida(anims, esc)
	_montar_cornada(anims, esc)
	_montar_pisoton(anims, esc)
	_montar_bramido(anims, esc)
	_montar_encaje(anims, esc)
	_montar_muerte(anims, esc)
	_montar_cadaver(anims, esc)
	var lz: Vector2i = _lienzo(esc)
	var sf: SpriteFrames = SpriteLienzo.montar_frames(
		anims, SpriteLienzo.paleta(_colores(col)), lz.x, lz.y)
	_cache[clave] = sf
	return sf


# La pose de reposo, con TODAS las claves a cero. Existe para que cada _montar_* escriba solo lo suyo
# y no se le olvide ninguna: una clave que falta no da error en GDScript, se lee como 0.0 y el fallo
# sale a la cara en el dibujo, que es donde mas cuesta encontrarlo.
static func _reposo() -> Dictionary:
	return {"avance": 0.0, "resopla": 0.0, "patas": 0.0, "agacha": 0.0, "cabeza": 0.0,
		"brazos": 0.0, "codo": 0.0, "punetazo": 0.0, "ladea": 0.0, "pisa": 0.0, "rodilla": 0.0,
		"rodilla_paso": 0.0, "testuz": 0.0, "vuelca": 0.0}


# Quieto: RESUELLA. Un jefe parado tiene que dar la sensacion de que esta conteniendose, no de que
# esta esperando: respira hondo, los hombros suben y bajan y la cabeza se mueve poco -- la lleva
# baja, mirandote. A 3 fps, que es lento y pesado.
static func _montar_idle(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["resopla"] = sin(TAU * t)
		p["cabeza"] = -0.25 + 0.3 * sin(TAU * t)
		p["brazos"] = 0.03 * sin(TAU * t)
		# El codo tambien respira. Un brazo que solo sube y baja desde el hombro se lee como un pendulo
		# colgado; abriendo y cerrando un poco el codo a la vez, se lee como un brazo.
		p["codo"] = 0.10 + 0.07 * sin(TAU * t)
		return p
	_montar_animacion(anims, esc, "idle", true, 3.0, pose, false)


# Andando: zancada larga y pesada, a 5 fps. Los brazos balancean en contrafase con las piernas, que
# es lo que hace que un bipedo ande en vez de deslizarse. Y se BAMBOLEA de un lado a otro: pesa.
static func _montar_walk(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["patas"] = sin(TAU * t)
		p["brazos"] = -0.13 * sin(TAU * t)
		p["agacha"] = 0.05 * (1.0 - cos(TAU * t * 2.0))
		p["ladea"] = 0.10 * sin(TAU * t)
		p["cabeza"] = -0.2 + 0.35 * sin(TAU * t * 2.0)
		# LOS CODOS EN CONTRAFASE CON SU PROPIO HOMBRO: el brazo que va hacia atras se cierra y el que
		# va hacia delante se abre. Es lo que separa un brazo que ANDA de un brazo que oscila entero.
		p["codo"] = 0.22 + 0.20 * sin(TAU * t)
		# Y LA RODILLA DE LA PATA DE ATRAS SE DOBLA. Va por 'rodilla_paso' y no por 'rodilla' a
		# proposito: 'rodilla' hunde el bicho entero (multiplica 'alto'), y aqui no se agacha -- se le
		# dobla una pata mientras la otra empuja.
		p["rodilla_paso"] = 0.22
		return p
	_montar_animacion(anims, esc, "walk", true, 5.0, pose, false)


# EL PUÑETAZO: su ataque BASICO (fx_basico = GOLPETAZO), y la animacion 'embestida' -- que es el
# nombre que el combate reproduce cuando nadie pide otra cosa (ver AbilityData.fx_anim).
#
# ANTES AQUI ESTABA LA CORNADA, y ese era el problema: como 'embestida' es el comodin, el bicho hacia
# la cornada para TODO -- el golpe normal y sus tres habilidades --, asi que su ataque corriente
# golpeaba de lado en vez de al frente. La cornada sigue estando, pero ahora con su nombre y solo
# para su habilidad.
#
# PEGA UN BRAZO SOLO Y EL OTRO SE QUEDA EN GUARDIA, y el golpe sale del CODO tanto como del hombro:
# se arma atras con el codo cerrado y lo suelta extendiendo los dos a la vez. Un brazo que solo rota
# desde el hombro es una barrera girando, no un puñetazo.
#
# LOS PUNTOS CLAVE VAN EN LOS TIEMPOS DE LOS FOTOGRAMAS, Y ESTO NO ES UN DETALLE. Con ocho marcos y
# 'ultimo_incluido', los unicos instantes que se DIBUJAN son 0, 1/7, 2/7 ... 1 -- o sea 0, 0,143,
# 0,286, 0,429, 0,571, 0,714, 0,857 y 1. Un pico puesto en 0,78 cae ENTRE el sexto y el septimo y no
# se dibuja jamas: lo unico que se ve son los dos valores interpolados de al lado, mas flojos. Asi
# estaban las tres animaciones nuevas al primer intento, y por eso el golpe "no se notaba" aunque los
# numeros fueran grandes. Los tramos siguen sirviendo para que el movimiento no sea lineal; lo que no
# puede es tener el momento importante fuera de la rejilla.
static func _montar_embestida(anims: Array, esc: float) -> void:
	# 'punetazo' negativo = armado con el codo cerrado; positivo = extendido al frente.
	var puno_keys := [[0.0, 0.0], [0.143, -0.60], [0.286, -1.0], [0.429, 0.20], [0.571, 1.0],
		[0.714, 0.85], [0.857, 0.35], [1.0, 0.0]]
	# Acompaña con el cuerpo: un paso corto al frente y se hunde sobre las piernas en el impacto. NO
	# viaja como la cornada -- esto es un golpe, no una carga.
	var avance_keys := [[0.0, 0.0], [0.143, -0.6], [0.286, -1.0], [0.429, 1.2], [0.571, 3.0],
		[0.714, 2.6], [0.857, 1.8], [1.0, 1.2]]
	var agacha_keys := [[0.0, 0.0], [0.143, 0.06], [0.286, 0.10], [0.429, 0.16], [0.571, 0.38],
		[0.714, 0.30], [0.857, 0.16], [1.0, 0.06]]
	# El torso rota un pelin CON el golpe (es de donde sale la fuerza), pero mucho menos que en la
	# cornada: pasado de aqui vuelve a leerse como un golpe de costado.
	# EL LADEO ES LO QUE SALVA EL PUÑETAZO DE FRENTE. En combate al bicho se le ve siempre desde el sur
	# (dir 0) y ahi el brazo saliendo hacia el jugador esta escorzado: se mueve, pero en pantalla casi
	# no recorre nada. Lo que si se ve desde ahi es lo que va DE LADO A LADO, asi que el torso rota con
	# el golpe -- que ademas es de donde sale la fuerza de un puñetazo de verdad. Es el mismo truco por
	# el que la cornada se lee: por el ladeo, no por el avance.
	var ladea_keys := [[0.0, 0.0], [0.143, -0.25], [0.286, -0.38], [0.429, 0.05], [0.571, 0.45],
		[0.714, 0.40], [0.857, 0.20], [1.0, 0.05]]
	var cabeza_keys := [[0.0, -0.2], [0.143, 0.2], [0.286, 0.3], [0.429, -0.4], [0.571, -1.1],
		[0.714, -0.9], [0.857, -0.5], [1.0, -0.25]]
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["punetazo"] = SpriteLienzo.tramos(t, puno_keys)
		p["avance"] = SpriteLienzo.tramos(t, avance_keys)
		p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
		p["ladea"] = SpriteLienzo.tramos(t, ladea_keys)
		p["cabeza"] = SpriteLienzo.tramos(t, cabeza_keys)
		# El brazo que NO pega se queda recogido, pero POCO: cerrandolo mucho se queda con el puño
		# a la altura del pecho y de frente eso ya no es una guardia, es un brazo cortado.
		p["codo"] = 0.30
		return p
	_montar_animacion(anims, esc, "embestida", false, 10.0, pose, true)


# LA CORNADA: escarba -> baja el testuz -> embiste LADEADO -> engancha hacia arriba.
# NO es periodica, asi que va por TRAMOS.
#
# LO QUE LA HACE UNA CORNADA ES EL LADEO. Embistiendo de frente con la cabeza baja, lo que se ve es
# un tio agachado corriendo; ladeando el torso y la cabeza, el cuerno de ese lado se adelanta y
# apunta -- y al final del golpe el cuello ENGANCHA HACIA ARRIBA, que es lo que hace un toro de
# verdad y lo que cuenta el sangrado de su habilidad.
static func _montar_cornada(anims: Array, esc: float) -> void:
	var avance_keys := [[0.0, 0.0], [0.30, -1.8], [0.60, 5.4], [0.78, 9.0], [1.0, 6.4]]
	var agacha_keys := [[0.0, 0.0], [0.30, 0.55], [0.60, 0.80], [0.78, 0.35], [1.0, 0.08]]
	# El ladeo entra en el aviso y se mantiene durante el viaje: es la puntería del cuerno.
	var ladea_keys := [[0.0, 0.0], [0.30, 0.65], [0.60, 0.85], [0.78, 0.55], [1.0, 0.0]]
	# Y EL ENGANCHE: la cabeza baja durante toda la carrera y sube DE GOLPE en el impacto.
	var cabeza_keys := [[0.0, -0.2], [0.30, -1.9], [0.60, -2.4], [0.78, 1.9], [1.0, 0.2]]
	# Los brazos se echan atras al correr, como los de algo que embiste con la cabeza.
	var brazos_keys := [[0.0, 0.0], [0.30, -0.22], [0.60, -0.34], [0.78, -0.10], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["avance"] = SpriteLienzo.tramos(t, avance_keys) * (LUNGE_DIST / 9.0)
		p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
		p["ladea"] = SpriteLienzo.tramos(t, ladea_keys)
		p["cabeza"] = SpriteLienzo.tramos(t, cabeza_keys)
		p["brazos"] = SpriteLienzo.tramos(t, brazos_keys)
		# Corriendo se lleva los codos recogidos, no los brazos estirados hacia atras.
		p["codo"] = 0.30 + 0.45 * clampf(t * 2.0, 0.0, 1.0)
		return p
	_montar_animacion(anims, esc, "cornada", false, 10.0, pose, true)


# EL PISOTON ATRONADOR (x1,7, area_max 99). SE ACERCA Y PISA: da un paso corto hacia el objetivo,
# levanta una pierna y la deja caer con todo el peso encima.
#
# UNA SOLA DIRECCION (el sur), como 'encaje' y 'muerte': las habilidades solo se ven en la pantalla
# de combate, y ahi el bicho encara siempre al jugador. El escalon de degradacion de combat.gd se
# encarga del resto.
#
# LO QUE LO HACE ALTO NO ES LA PATA, ES EL BICHO. La pezuña solo puede subir 2,6 unidades sin
# descoser la pierna (ver PISA_ALZA), asi que el alzado se cuenta con 'agacha' NEGATIVO -- el
# minotauro entero se estira antes de dejarse caer -- y con el hundimiento de golpe al pisar.
static func _montar_pisoton(anims: Array, esc: float) -> void:
	var avance_keys := [[0.0, 0.0], [0.143, 0.8], [0.286, 2.0], [0.429, 3.0], [0.571, 3.4],
		[0.714, 3.4], [0.857, 3.4], [1.0, 3.4]]
	# SE ENCOGE, SE ESTIRA Y SE DESPLOMA, y ese vaiven de altura es lo unico que de verdad se ve del
	# pisoton desde el sur: la pata subiendo son trece pixeles, pero el bicho entero pasa del 109% de
	# su altura al 83%, o sea treinta. El fotograma 4 es el impacto y va SOLO -- sin el valle previo
	# del 3, un hundimiento no se lee como un golpe, se lee como agacharse.
	var agacha_keys := [[0.0, 0.0], [0.143, 0.18], [0.286, -0.14], [0.429, -0.30], [0.571, 0.55],
		[0.714, 0.34], [0.857, 0.18], [1.0, 0.08]]
	var pisa_keys := [[0.0, 0.0], [0.143, 0.15], [0.286, 0.60], [0.429, 1.0], [0.571, 0.0],
		[0.714, 0.0], [1.0, 0.0]]
	# Los brazos se abren para hacer sitio y caen con el pisoton: es de donde sale el peso.
	var brazos_keys := [[0.0, 0.0], [0.143, 0.10], [0.286, 0.30], [0.429, 0.44], [0.571, -0.16],
		[0.714, -0.06], [1.0, 0.0]]
	var codo_keys := [[0.0, 0.20], [0.143, 0.35], [0.286, 0.60], [0.429, 0.75], [0.571, 0.20],
		[0.714, 0.26], [1.0, 0.30]]
	var cabeza_keys := [[0.0, -0.2], [0.143, 0.3], [0.286, 0.8], [0.429, 1.1], [0.571, -1.8],
		[0.714, -1.0], [0.857, -0.6], [1.0, -0.35]]
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["avance"] = SpriteLienzo.tramos(t, avance_keys)
		p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
		p["pisa"] = SpriteLienzo.tramos(t, pisa_keys)
		p["brazos"] = SpriteLienzo.tramos(t, brazos_keys)
		p["codo"] = SpriteLienzo.tramos(t, codo_keys)
		p["cabeza"] = SpriteLienzo.tramos(t, cabeza_keys)
		return p
	_montar_animacion(anims, esc, "pisoton", false, 12.0, pose, true, 1, FRAMES)


# EL BRAMIDO EMBRAVECIDO (dano 0, furia sobre si mismo): PURO GESTO. Se yergue, echa la cabeza atras
# hasta que el morro apunta al cielo y abre los brazos.
#
# LO QUE LO HACE UN BRAMIDO ES EL 'testuz', no la altura. Subiendo la cabeza en Z lo que sale es un
# bicho mirando hacia arriba; lo que hace un toro que brama es GIRAR el craneo sobre el cuello hasta
# que los cuernos se le van a la espalda y el hocico queda en alto. Eso es lo que se ve en la
# referencia que paso el usuario, y es lo unico que hay que acertar aqui.
#
# Y VA LENTO -- 8 fps, lo mas lento del bicho -- porque no pega: si pasara rapido no se leeria como
# un gesto, se leeria como un tic.
static func _montar_bramido(anims: Array, esc: float) -> void:
	# Coge aire (se encoge un poco) y ENTONCES se yergue. Sin ese hundimiento previo el estiramiento
	# no tiene de donde salir.
	var agacha_keys := [[0.0, 0.0], [0.143, 0.24], [0.286, -0.10], [0.429, -0.22], [0.571, -0.28],
		[0.714, -0.26], [0.857, -0.10], [1.0, 0.0]]
	# EL TOPE DEL BRAMIDO NO ES EL TOPE DE LA JUNTA. TESTUZ_MAX (0,80) es lo que aguanta el cuello sin
	# descoserse, pero a 0,80 el craneo gira tanto que DE FRENTE LA CARA DESAPARECE: se ve la garganta
	# y dos cuernos saliendo de los hombros, y eso no se lee como un bramido, se lee como un bicho sin
	# cabeza. A 0,64 el morro ya apunta al cielo y los ojos siguen ahi, que es lo que hace falta ver.
	# Lo que ata este numero es la CAMARA, no la geometria.
	var testuz_keys := [[0.0, 0.0], [0.143, -0.14], [0.286, 0.32], [0.429, 0.55],
		[0.571, 0.64], [0.714, 0.62], [0.857, 0.42], [1.0, 0.18]]
	var cabeza_keys := [[0.0, -0.25], [0.143, -0.9], [0.286, 0.4], [0.429, 1.0], [0.571, 1.5],
		[0.714, 1.4], [0.857, 0.8], [1.0, 0.2]]
	# Brazos abiertos y en alto, pero CON EL CODO CERRADO: extendidos del todo se queda en cruz y
	# ocupa el doble de ancho (ver el aviso de BRAZO_ANG_*). En jarra ocupa menos y amenaza mas.
	var brazos_keys := [[0.0, 0.0], [0.143, -0.10], [0.286, 0.24], [0.429, 0.44], [0.571, 0.60],
		[0.714, 0.58], [0.857, 0.36], [1.0, 0.14]]
	var codo_keys := [[0.0, 0.25], [0.143, 0.45], [0.286, 0.68], [0.429, 0.82], [0.571, 0.90],
		[0.714, 0.86], [0.857, 0.62], [1.0, 0.35]]
	# Y TIEMBLA al bramar: el 'resopla' a tope y rapido, que es el que hincha y deshincha el cuerpo.
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
		p["testuz"] = SpriteLienzo.tramos(t, testuz_keys)
		p["cabeza"] = SpriteLienzo.tramos(t, cabeza_keys)
		p["brazos"] = SpriteLienzo.tramos(t, brazos_keys)
		p["codo"] = SpriteLienzo.tramos(t, codo_keys)
		p["resopla"] = sin(TAU * t * 3.0) * clampf((t - 0.35) * 3.0, 0.0, 1.0)
		return p
	_montar_animacion(anims, esc, "bramido", false, 8.0, pose, true, 1, FRAMES)


# ENCAJAR UN GOLPE. Cuatro fotogramas en UNA sola direccion (en combate se le ve siempre de frente)
# y EMPEZANDO YA GOLPEADO: el frame 0 es el impacto, no la pose de reposo. Un golpe no tiene
# anticipacion, y con cuatro marcos un fotograma de espera se comeria la animacion entera.
#
# ACUSA POCO PERO SE REVUELVE. Tiene 1200 de vida y 45 de resistencia, asi que no sale despedido
# como el acechador -- pero es CARNE, no coraza, asi que tampoco se queda clavado como la bestia
# acorazada. Se hunde sobre las piernas, echa la cabeza atras y vuelve a bajarla: no retrocede, se
# encara.
static func _montar_encaje(anims: Array, esc: float) -> void:
	# 'agacha' no pasa de 0,62: por encima de 1,0 la altura se vuelve negativa y las piezas dejan de
	# pintarse SIN DAR ERROR.
	var agacha_keys := [[0.0, 0.62], [0.34, 0.20], [0.67, 0.06], [1.0, 0.0]]
	var retro_keys := [[0.0, 1.0], [0.34, 0.42], [0.67, 0.12], [1.0, 0.0]]
	var cabeza_keys := [[0.0, 2.4], [0.34, -0.9], [0.67, 0.2], [1.0, -0.25]]
	var brazos_keys := [[0.0, 0.30], [0.34, 0.10], [0.67, 0.02], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["avance"] = -SpriteLienzo.tramos(t, retro_keys) * (LUNGE_DIST * ENCAJE_RETRO)
		p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
		p["cabeza"] = SpriteLienzo.tramos(t, cabeza_keys)
		p["brazos"] = SpriteLienzo.tramos(t, brazos_keys)
		p["ladea"] = 0.22 * SpriteLienzo.tramos(t, retro_keys)
		return p
	# TODOS LOS BICHOS ENCAJAN A 18 fps: es la duracion que espera CombatFX.T_ENCAJE, y cuadrando las
	# dos el sprite va a su velocidad natural en vez de estirado por _pose_ajustar.
	_montar_animacion(anims, esc, "encaje", false, 18.0, pose, true, 1, 4)


# MORIRSE. OCHO fotogramas en UNA sola direccion: la muerte solo se ve en la pantalla de combate, y
# ahi al bicho se le mira siempre de frente. Para el mapa esta 'cadaver', que es lo contrario.
#
# SE HINCA DE RODILLAS Y SE VENCE HACIA DELANTE, apoyando una mano. NO vuelca de costado como el
# jabali ni se desmorona como el coloso: los dos son muertes de cosas que pierden su forma, y este es
# un guerrero. Un jefe que otorga rango tiene que caer como cae un rival: de rodillas primero,
# aguantandose con un brazo, y solo despues abajo.
#
# Y ES LA MUERTE MAS LARGA DEL JUEGO A PROPOSITO -- 9 fps sobre ocho marcos --, porque es la unica
# que el jugador ha estado quince minutos esperando.
static func _pose_muerte(t: float) -> Dictionary:
	# Las rodillas ceden primero, y no a la vez: primero una, luego las dos.
	var rodilla_keys := [[0.0, 0.0], [0.16, 0.25], [0.34, 0.70], [0.55, 1.0], [1.0, 1.0]]
	# 'vuelca' lo echa hacia delante sobre la mano de apoyo. Llega a 1,0 y no mas: doblado del todo
	# se lee como un ovillo y deja de reconocerse.
	var vuelca_keys := [[0.0, 0.0], [0.16, 0.08], [0.34, 0.28], [0.55, 0.62], [0.78, 0.90],
		[1.0, 1.0]]
	var agacha_keys := [[0.0, 0.10], [0.16, 0.40], [0.34, 0.70], [0.55, 0.88], [1.0, 0.92]]
	# La cabeza se descuelga del todo: es lo ultimo que cae y lo que remata la lectura.
	var cabeza_keys := [[0.0, 0.6], [0.16, -1.2], [0.34, -2.4], [0.55, -3.4], [1.0, -4.0]]
	# Un brazo se adelanta a apoyarse (el otro cuelga): 'brazos' negativo lo lleva hacia delante.
	var brazos_keys := [[0.0, 0.0], [0.16, 0.30], [0.34, 0.62], [0.55, 0.80], [1.0, 0.85]]
	var p: Dictionary = _reposo()
	p["rodilla"] = SpriteLienzo.tramos(t, rodilla_keys)
	p["vuelca"] = SpriteLienzo.tramos(t, vuelca_keys)
	p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
	p["cabeza"] = SpriteLienzo.tramos(t, cabeza_keys)
	p["brazos"] = SpriteLienzo.tramos(t, brazos_keys)
	return p


static func _montar_muerte(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return _pose_muerte(t)
	_montar_animacion(anims, esc, "muerte", false, 9.0, pose, true, 1, 8)


# EL CADAVER DEL MAPA: UN fotograma por CADA UNA de las ocho direcciones, que es justo al reves que
# 'muerte' (ocho fotogramas en una sola). No es un capricho de reparto, es lo que pide cada sitio: en
# combate al bicho se le ve morir de frente y una vez; en el mapa no se le ve morir -- se entra a la
# sala y ya esta tirado --, pero puede haber caido mirando a cualquier lado.
#
# Es EXACTAMENTE la pose final de la muerte, sacada de la misma funcion: escribir los numeros otra
# vez aqui es garantizar que el dia que se retoque la muerte el cadaver se quede como estaba, y que
# el bicho pegue un salto al pasar de una a otro.
static func _montar_cadaver(anims: Array, esc: float) -> void:
	var pose := func(_t: float) -> Dictionary:
		return _pose_muerte(1.0)
	# ultimo_incluido = false y NO true: con un solo marco, el divisor de _montar_animacion seria
	# (1 - 1) = 0 y el reparto de t saldria NaN. La pose se pide fija, asi que da igual.
	_montar_animacion(anims, esc, "cadaver", false, 1.0, pose, false, 8, 1)


static func _montar_animacion(anims: Array, esc: float, nombre: String,
		loop: bool, fps: float,
		pose_fn: Callable, ultimo_incluido: bool, dirs: int = 8, marcos: int = FRAMES) -> void:
	var divisor: float = float(marcos - 1) if ultimo_incluido else float(marcos)
	for dir in dirs:
		var plantillas: Array = []
		for i in marcos:
			# La GEOMETRIA se cachea por (animacion, frame, direccion, escala) y NO por color: es lo
			# que evita que entrar a un piso lleno de bichos congele el juego.
			var clave: String = "%s_%d_%d_%.2f" % [nombre, i, dir, esc]
			var plant: PackedByteArray = _cache_plantillas.get(clave, PackedByteArray())
			if plant.is_empty():
				plant = _plantilla(dir, pose_fn.call(float(i) / divisor), esc)
				_cache_plantillas[clave] = plant
			plantillas.append(plant)
		anims.append({"nombre": "%s_%d" % [nombre, dir], "loop": loop, "fps": fps,
			"plantillas": plantillas})


# Le sube la saturacion para devolverle lo rojizo: cuantizado, el pardo se va a un marron de raton.
static func _calido(color: Color) -> Color:
	var out := Color.from_hsv(color.h, minf(1.0, color.s * 1.22 + 0.10), color.v)
	out.a = color.a
	return out


# Los colores de cada Tono, EN EL ORDEN DEL ENUM (contrato con SpriteLienzo.paleta).
static func _colores(color: Color) -> Array:
	var base: Color = _calido(color)
	return [
		Color(0, 0, 0, 0),                    # VACIO
		Color(0, 0, 0, 0.22),                 # SOMBRA_SUELO
		base.darkened(0.70),                  # BORDE
		# LAS PEZUÑAS, casi negras. Son el remate oscuro de abajo, igual que las patas del jabali, y
		# lo que hace que las piernas se lean como de toro y no como botas.
		base.darkened(0.66),                  # PEZUNA_T
		base.darkened(0.42),                  # PIERNA_OSC (el pelo largo de las cañas)
		# LA PENUMBRA VA FUERTE (0,38 y no 0,26). Es el tono del brazo y la pierna del FONDO, y de
		# perfil es lo unico que los separa del torso -- alli las tres piezas caen sobre el mismo eje
		# de pantalla. Con una penumbra suave la diferencia no llegaba a leerse y el bicho de lado
		# seguia siendo un bulto.
		base.darkened(0.38),                  # SOMBRA (el costado y lo que va al fondo)
		base,                                 # BASE
		# El PELO iluminado del lomo y los hombros. Se aclara HACIA UN OCRE ROJIZO y no hacia el
		# blanco: 'lightened' desatura, y sobre un pardo ya apagado deja un gris de raton.
		base.lerp(Color(0.85, 0.62, 0.38), 0.40),   # CLARO
		# EL MORRO VA CLARO Y ROSADO, no oscuro. Con un morro mas oscuro que la cara, la cabeza salia
		# como una masa parda sin rasgos: lo unico que se le veia eran dos puntos ambar. En la
		# referencia del usuario -- y en un toro de verdad -- el hocico es la mancha CLARA de la cara,
		# y es lo que la organiza. Mismo truco que el hocico del jabali.
		base.lerp(Color(0.88, 0.66, 0.60), 0.52),   # HOCICO_T
		# LOS CUERNOS en HUESO, bien claros: son su silueta y tienen que ganarle al cuerpo.
		Color(0.90, 0.86, 0.74),              # CUERNO_T
		Color(0.72, 0.68, 0.44),              # ANILLA_T (laton viejo)
		Color(0.95, 0.72, 0.18),              # OJO_T (ambar encendido)
		# EL CUERO del taparrabos y los brazaletes: pardo MUY oscuro, casi el tono del borde. Tiene
		# que leerse como una cosa puesta encima, asi que no puede ser una variacion de su piel.
		Color(0.20, 0.13, 0.09),              # CUERO_T
	]


# ------------------------------------------------------------
#  GEOMETRIA
# ------------------------------------------------------------

# Las PIEZAS del minotauro para una pose, ya proyectadas a pantalla. El orden ES la profundidad: se
# pintan en ese orden y las ultimas tapan a las primeras.
static func _piezas(dir: int, pose: Dictionary, esc: float) -> Array:
	var ang: float = DIR_VECS[dir].angle() - DIR_VECS[0].angle()
	var u: float = esc / SpriteLienzo.UNIDADES_POR_CELDA    # unidades de mundo -> celdas
	var org: Vector2 = _origen(esc)
	var avance: float = float(pose["avance"])
	var resopla: float = float(pose["resopla"])
	var fase_patas: float = float(pose["patas"])
	var agacha: float = float(pose["agacha"])
	var cabeza_y: float = float(pose["cabeza"])
	var brazos: float = float(pose["brazos"])
	var codo: float = float(pose["codo"])
	var punetazo: float = float(pose["punetazo"])
	var ladea: float = float(pose["ladea"])
	var pisa: float = float(pose["pisa"])
	var rodilla: float = float(pose["rodilla"])
	var rodilla_paso: float = float(pose["rodilla_paso"])
	var testuz: float = clampf(float(pose["testuz"]), -0.35, TESTUZ_MAX)
	var vuelca: float = float(pose["vuelca"])

	# Agazapado = mas bajo. 'alto' multiplica TODAS las alturas, asi que agacharse hunde el bicho
	# entero sobre las piernas, que es lo que hace un bipedo pesado.
	var alto: float = 1.0 - 0.30 * agacha - 0.34 * rodilla
	var hincha: float = 1.0 + 0.022 * resopla

	var piezas: Array = []
	var desp := Vector2(0.0, avance).rotated(ang)
	var s_a: float = sin(ang)
	var c_a: float = cos(ang)

	# local (x ancho, y largo, z altura, en unidades de mundo) -> celda de pantalla.
	# 'gira' a false deja la pieza SIN rotar su forma (para las que ya vienen orientadas a mano).
	var poner := func(local: Vector3, r: Vector3, tono: int, solo_sobre: Array = [],
			en_suelo: bool = false) -> void:
		# EL LADEO Y EL VUELCO, los dos en el plano de delante: 'ladea' inclina el bicho de costado
		# (la cornada) y 'vuelca' lo echa hacia delante sobre la mano (la muerte). Se aplican aqui y
		# no pieza a pieza porque tienen que inclinar el cuerpo ENTERO alrededor de los pies: si solo
		# se aplicaran al torso, las piernas se quedarian de pie y el bicho se partiria por la
		# cintura.
		var lx: float = local.x + local.z * ladea * 0.14
		# El coeficiente del vuelco es CORTO (0,18) por la misma razon que el plegado de la rodilla:
		# inclinar alrededor de los pies mueve las piezas altas mas que las bajas, asi que cada junta
		# vertical de la pierna se ABRE en proporcion a lo separadas que esten sus piezas en altura.
		# Con 0,30 la junta muslo-corvejon se abria 5,8 unidades contra 5,5 de suma de radios y la
		# pierna se partia en dos en el cadaver.
		var ly: float = local.y + local.z * vuelca * 0.18
		var p := Vector2(lx, ly)
		var rot: Vector2 = p.rotated(ang) + desp
		var z: float = 0.0 if en_suelo else local.z * alto * hincha
		var sx: float = org.x + rot.x * u
		var sy: float = org.y + (rot.y * SpriteLienzo.COS_CAM - z * SpriteLienzo.SIN_CAM) * u
		var ry: float = r.y
		var rxm: float = r.x
		# LA PERSPECTIVA SE MIDE SOBRE EL RADIO YA ROTADO. El motor aplasta el eje VERTICAL DE
		# PANTALLA por 'persp' DESPUES de girar la pieza, pero 'persp_de' recibe el radio a lo LARGO,
		# y los dos solo coinciden mirando al SUR: girado 90 grados, el que cae en vertical es el
		# radio a lo ANCHO. Sin esto las piezas pierden altura al girar y se sueltan del cuerpo en
		# siete de las ocho direcciones -- lo que le paso a las patas del acechador, cuya firma era
		# justamente "mal en todas menos en S".
		var ry_rot: float = sqrt(rxm * rxm * s_a * s_a + ry * ry * c_a * c_a)
		piezas.append({"pos": Vector2(sx, sy), "radio": Vector2(rxm * u, ry * u),
			"gira_forma": true, "tono": tono, "ang": ang,
			"persp": SpriteLienzo.persp_de(ry_rot, r.z * alto), "solo_sobre": solo_sobre})

	# SOMBRA DE CONTACTO, lo primero (va debajo). A ALTURA CERO: no sube con el bicho.
	poner.call(Vector3(0.0, 0.0, 0.0), Vector3(PIERNA_X + PEZUNA_R.x, PEZUNA_R.y * 1.5, 0.0),
		Tono.SOMBRA_SUELO, [], true)

	# --- LAS PIERNAS. Las cuatro piezas de cada una se mueven JUNTAS con el paso, y al hincarse de
	# rodillas la pierna se pliega: el muslo baja, el corvejon se va hacia atras y la caña se tumba.
	#
	# SE DIBUJA PRIMERO LA DEL FONDO. El orden de esta lista ES la profundidad -- aqui no hay z-buffer
	# --, asi que con el orden fijo [-1, 1] la pierna del fondo se pintaba ENCIMA de la de delante en
	# la mitad de las direcciones.
	var lados_pierna: Array = [-1.0, 1.0]
	if Vector2(-PIERNA_X, 0.0).rotated(ang).y > 0.0:
		lados_pierna = [1.0, -1.0]
	for lado in lados_pierna:
		var swing: float = fase_patas * lado
		var y_off: float = swing * PASO_LARGO
		# Al andar, la pierna adelantada tambien SE LEVANTA. Sin esto los pies patinan por el suelo.
		var z_off: float = maxf(0.0, swing) * PASO_ALZA
		# EL PISOTON: esta pata sube ENTERA -- por su propia columna de reparto, no por la del paso --,
		# fuera del ciclo de andar y siempre la misma (PISA_LADO). Ver 'alza_pisa'.
		var z_pisa: float = pisa * PISA_ALZA if is_equal_approx(lado, PISA_LADO) else 0.0
		# De rodillas: esta pierna se pliega hacia atras y baja.
		#
		# 'rodilla' es el hincarse ENTERO (la muerte) y va para las dos patas con un desfase, que es lo
		# que separa "se le parte una pierna" de "se sienta". 'rodilla_paso' es la flexion de UNA sola
		# pata -- la de atras al andar, la que sube en el pisoton -- y NO toca 'alto': doblar una
		# rodilla no puede hundir el bicho entero.
		#
		# LOS DOS TERMINOS SON EXCLUYENTES EN LA PRACTICA y por eso se suman sin mas: en el pisoton
		# 'patas' vale cero (no anda mientras pisa) y al andar 'pisa' vale cero. Escribirlo con un
		# if/else haria que la pata del pisoton no se doblara nunca al andar.
		var rod: float = rodilla * (1.0 if lado > 0.0 else 0.82)
		if is_equal_approx(lado, PISA_LADO):
			rod += rodilla_paso * pisa
		rod += rodilla_paso * maxf(0.0, -swing)
		# EL PLEGADO DE LA RODILLA VA CORTO EN Y. Al primer intento el corvejon se iba 3,0 unidades
		# hacia atras y la caña 4,6, y con el muslo casi quieto la distancia entre sus centros (5,6)
		# superaba la SUMA DE SUS RADIOS (5,5): la pierna se partia en dos en el cadaver. Y encima
		# 'vuelca' lo empeoraba, porque mueve mas las piezas altas que las bajas -- es una inclinacion
		# alrededor de los pies -- asi que le sumaba otras 1,7 justo en la misma junta.
		#
		# Doblar una cadena cuesta solape igual que estirarla. Aqui se pliega la mitad y se lee igual.
		# Y LA PIERNA DEL FONDO TAMBIEN VA EN PENUMBRA, por lo mismo que el brazo: de perfil las dos
		# caen sobre el mismo eje de pantalla y en el mismo tono se leen como una sola pata gorda.
		var pierna_fondo: bool = Vector2(lado * PIERNA_X, 0.0).rotated(ang).y <= 0.0
		var tono_muslo: int = Tono.SOMBRA if pierna_fondo else Tono.BASE
		# CADA PIEZA CON SU REPARTO (ver PIERNA_PIEZAS). Antes los coeficientes iban escritos a mano
		# aqui mismo y solo existian para la zancada, asi que la pierna se movia como un bloque; ahora
		# cada una se lleva su parte de la zancada, del alzado del pie y del plegado de la rodilla, que
		# es lo que hace que la pierna se DOBLE en vez de desplazarse entera.
		for pz in PIERNA_PIEZAS:
			var c: Vector3 = pz["c"]
			var tono_pz: int = int(pz["tono"])
			if tono_pz < 0:
				tono_pz = tono_muslo
			poner.call(Vector3(lado * PIERNA_X,
					c.y + y_off * float(pz["paso"]) + rod * float(pz["dobla_y"]),
					c.z + z_off * float(pz["alza"]) + z_pisa * float(pz["alza_pisa"])
						+ rod * float(pz["dobla_z"])),
				pz["r"], tono_pz)

	# QUE BRAZO VA DELANTE sale de la Y del hombro YA GIRADA. Con HOMBRO_Y en cero exacto la prueba
	# daria falso para los DOS y el bicho de frente dibujaria sus dos brazos como "el de detras".
	var lados_brazo: Array = [-1.0, 1.0]
	var detras: Array = []
	var delante: Array = []
	for lado in lados_brazo:
		if Vector2(lado * HOMBRO_X, HOMBRO_Y).rotated(ang).y > 0.0:
			delante.append(lado)
		else:
			detras.append(lado)

	# Dibuja un brazo entero: cadena de piezas por PASOS UNITARIOS, con un CODO de verdad -- un salto
	# de angulo EN UNA JUNTA -- en el plano Y-Z.
	var brazo := func(lado: float) -> void:
		# 'brazos' > 0 lo sube por DELANTE (bramido, apoyo al morir); < 0 lo echa atras (correr).
		var a: float = lerpf(BRAZO_ANG_REPOSO, BRAZO_ANG_ALTO, maxf(0.0, brazos)) \
			+ minf(0.0, brazos) * 1.2
		var flex: float = BRAZO_CODO_REPOSO + BRAZO_CODO * clampf(codo, 0.0, 1.0)
		# EL PUÑETAZO, solo en el brazo que pega: 'punetazo' negativo lo arma por detras cerrando el
		# codo, positivo lo extiende al frente abriendolo. El hombro y el codo van A LA VEZ, que es lo
		# que convierte un brazo que rota en un brazo que GOLPEA.
		if is_equal_approx(lado, GOLPE_LADO) and not is_zero_approx(punetazo):
			# -1..1 -> 0..1 (armado arriba -> descargado abajo), y se MEZCLA con la pose normal por el
			# valor absoluto: asi en 'punetazo' = 0 el brazo esta exactamente donde estaria sin golpe y
			# no pega un salto al entrar y salir de la animacion.
			var u01: float = punetazo * 0.5 + 0.5
			var mez: float = absf(punetazo)
			a = lerpf(a, lerpf(BRAZO_ANG_ARMADO, BRAZO_ANG_GOLPE, u01), mez)
			flex = lerpf(flex, lerpf(BRAZO_CODO, BRAZO_CODO * 0.08, u01), mez)
		var hz: float = HOMBRO_Z - BRAZO_BAJA
		var al_fondo: bool = lado in detras
		if al_fondo:
			hz -= HOMBRO_BAJA_DETRAS
		# EL BRAZO DEL FONDO VA EN PENUMBRA, y esto es lo que salva el PERFIL. De lado, los dos brazos,
		# el torso y las piernas caen sobre el mismo eje de pantalla -- lo que los separa a lo ancho
		# pasa a ser PROFUNDIDAD, que no se ve -- asi que, todos en el mismo tono, el bicho salia como
		# un BULTO sin lectura interna: no se distinguian ni brazos ni piernas.
		#
		# El codo ayuda pero no basta. Lo que de verdad los separa es que el de atras este mas oscuro,
		# que ademas es lo que pasa de verdad: la luz viene de arriba y delante. Y no contradice la
		# regla del golem ("una pieza con su propia LUZ se lee como una pieza aparte"): alli eso era
		# malo porque el hombro TENIA que fundirse con el cuerpo; aqui es justo lo que se busca.
		var tono_brazo: int = Tono.SOMBRA if al_fondo else Tono.BASE
		var p3 := Vector3(lado * HOMBRO_X, HOMBRO_Y, hz)
		for k in BRAZO_SEGMENTOS:
			var f: float = float(k) / float(BRAZO_SEGMENTOS - 1)
			poner.call(p3, Vector3.ONE * lerpf(BRAZO_R0, BRAZO_R1, f), tono_brazo)
			# EL BRAZALETE: va sobre el antebrazo y por ENCIMA del segmento, no en vez de el, asi que
			# si algun dia se mueve la cadena el brazalete la sigue solo.
			if k == BRAZALETE_SEG:
				poner.call(p3, BRAZALETE_R, Tono.CUERO_T, [Tono.BASE])
			# EL CODO, TODO DE GOLPE Y EN UNA SOLA JUNTA. Repartido entre los seis segmentos -- que es
			# como estaba -- el brazo no dobla: se COMBA, y un brazo combado se sigue leyendo tieso.
			if k == BRAZO_CODO_SEG - 1:
				a += flex
			# EL DESVIO A LO ANCHO CAMBIA DE SIGNO EN EL CODO: el brazo sale hacia fuera y el antebrazo
			# se vuelve hacia dentro, como el del jugador (ver BRAZO_ABRE / BRAZO_METE). Es lo que hace
			# que el brazo CUELGUE en vez de abrirse en aspa.
			var lat: float = -BRAZO_METE if k >= BRAZO_CODO_SEG - 1 else BRAZO_ABRE
			# POR PASOS UNITARIOS: se avanza BRAZO_PASO en la direccion actual, que va NORMALIZADA. El
			# paso no cambia nunca, asi que dos piezas seguidas se solapan igual venga como venga el
			# brazo -- que es lo unico que permite doblar la cadena sin descoserla.
			#
			# Y lo que se separa del cuerpo va DENTRO de la direccion, no sumado encima: sumandolo
			# aparte el paso real era 2,46 y no 2,4, o sea que el presupuesto de solape del codo estaba
			# calculado sobre un numero que no era el de verdad.
			p3 += Vector3(lado * lat, sin(a) * BRAZO_ADELANTA, -cos(a)).normalized() * BRAZO_PASO
		# EL PUÑO, colgando del ultimo segmento.
		poner.call(p3, PUNO_R, tono_brazo)

	# EL BRAZO DE DETRAS, antes que el torso: el cuerpo tiene que taparlo.
	for lado in detras:
		brazo.call(lado)

	# --- EL TORSO EN V, de abajo arriba.
	poner.call(CADERA, CADERA_R, Tono.BASE)
	# EL TAPARRABOS, justo despues de la cadera para que se recorte sobre ella, y el FALDON que cuelga
	# por delante. Van en cuero oscuro: lo que le da escala al bicho es llevar encima algo hecho por
	# alguien (ver CUERO_T).
	poner.call(TAPARRABOS, TAPARRABOS_R, Tono.CUERO_T, [Tono.BASE])
	poner.call(FALDON, FALDON_R, Tono.CUERO_T)
	poner.call(CINTURA, CINTURA_R, Tono.BASE)
	poner.call(PECHO, PECHO_R, Tono.BASE)
	# El PELO ILUMINADO de lo alto de la espalda. Solo sobre BASE, para no aclarar ni pezuñas ni
	# contorno.
	poner.call(Vector3(0.0, PECHO.y - 2.4, PECHO.z + PECHO_R.z * 0.58),
		Vector3(PECHO_R.x * 0.66, PECHO_R.y * 0.72, PECHO_R.z), Tono.CLARO, [Tono.BASE])
	# PECTORALES, por delante.
	for lado in [-1.0, 1.0]:
		poner.call(Vector3(lado * PECTORAL.x, PECTORAL.y, PECTORAL.z), PECTORAL_R, Tono.SOMBRA,
			[Tono.BASE])

	# LOS HOMBROS GIRAN Y VAN JUSTO ANTES DE LA CABEZA. Girando, de perfil uno se va hacia la camara
	# y otro al fondo, y con la cabeza en medio saldrian tres bolas apiladas (muñeco de nieve); pero
	# sin girar, de perfil el bicho enseña DOS hombros donde deberia enseñar uno. Dibujandolos ANTES
	# de la cabeza, la cabeza tapa al del fondo y queda solo el de delante.
	#
	# Y VAN EN TONO BASE, compartiendo el degradado del cuerpo: una pieza con su propia LUZ se lee
	# como una pieza APARTE, o sea como una hombrera de armadura. Eso es del coloso; este tiene
	# hombros, no hombreras.
	for lado in [-1.0, 1.0]:
		var hz2: float = HOMBRO_Z
		if lado in detras:
			hz2 -= HOMBRO_BAJA_DETRAS
		poner.call(Vector3(lado * HOMBRO_X, HOMBRO_Y, hz2), HOMBRO_R, Tono.BASE)

	# QUIEN LE VE LA CARA: de ESPALDAS no se le ven ni los ojos ni la anilla ni el hocico. Un bicho
	# que se aleja enseña la nuca, y eso es lo que hace que se lea de un vistazo si viene o si huye.
	var frente: float = DIR_VECS[dir].y
	var lados: Array = [-1.0, 1.0]
	if frente <= -0.5:
		lados = []
	elif frente < -0.2:
		lados = [signf(DIR_VECS[dir].x)]

	# EL GIRO DEL TESTUZ: rota una pieza del grupo de la cabeza alrededor de la BASE DEL CUELLO, en el
	# plano Y-Z. 'peso' es cuanto le toca del giro -- el cuello se lleva TESTUZ_CUELLO y todo lo que va
	# montado en el craneo va entero.
	#
	# ES LO QUE HACE EL BRAMIDO. Subiendo la cabeza en Z sale un bicho MIRANDO hacia arriba; lo que
	# hace un toro que brama es girar el craneo hasta que los cuernos se le van a la espalda y el
	# morro queda apuntando al cielo. Lo mismo, en pequeño, le da al enganche de la cornada el gesto
	# de levantar por debajo en vez de subir a plomo.
	var testa := func(local: Vector3, peso: float) -> Vector3:
		var th: float = testuz * peso
		if is_zero_approx(th):
			return local
		var dy: float = local.y - TESTUZ_PIVOTE.y
		var dz: float = local.z - TESTUZ_PIVOTE.z
		var ct: float = cos(th)
		var st: float = sin(th)
		return Vector3(local.x, TESTUZ_PIVOTE.y + dy * ct - dz * st,
			TESTUZ_PIVOTE.z + dy * st + dz * ct)

	# --- LOS CUERNOS: cadena por pasos unitarios que sale hacia FUERA, sube y se curva hacia DELANTE.
	# Se dibujan SIEMPRE, tambien de espaldas: son su silueta, y un minotauro de espaldas sigue
	# teniendo cuernos.
	var cuerno := func(lado: float) -> void:
		var cp := Vector3(lado * CUERNO_BASE.x, CUERNO_BASE.y, CUERNO_BASE.z + cabeza_y)
		# 'cv' es la inclinacion en el plano vertical: empieza abierto hacia fuera y se va cerrando
		# hacia arriba y delante.
		var cv: float = 0.0
		for k in CUERNO_SEGMENTOS:
			var f: float = float(k) / float(CUERNO_SEGMENTOS - 1)
			# El cuerno se construye en local y se gira AL PONERLO, no antes: si se girase la base y se
			# siguiera creciendo desde ahi, la cadena saldria del craneo en la direccion vieja.
			poner.call(testa.call(cp, 1.0), Vector3.ONE * lerpf(CUERNO_R0, CUERNO_R1, f),
				Tono.CUERNO_T)
			cp.x += lado * cos(cv) * CUERNO_ABRE * CUERNO_PASO
			cp.z += sin(cv + 0.55) * CUERNO_PASO
			cp.y += (1.0 - cos(cv)) * CUERNO_PASO * 0.55
			cv += CUERNO_GIRO

	# Que cuerno va al fondo, con la misma prueba que los brazos: la X de su base YA GIRADA.
	var detras_cuerno: Array = []
	var delante_cuerno: Array = []
	for lado in [-1.0, 1.0]:
		if Vector2(lado * CUERNO_BASE.x, CUERNO_BASE.y).rotated(ang).y > 0.0:
			delante_cuerno.append(lado)
		else:
			detras_cuerno.append(lado)

	# EL CUERNO DEL FONDO, ANTES DE LA CABEZA: asi el craneo lo tapa y solo asoma la punta por detras,
	# que es lo que se ve de verdad. Pintado despues, se subia por encima de la cabeza y el bicho
	# parecia llevar el cuerno clavado en la frente.
	for lado in detras_cuerno:
		cuerno.call(lado)

	# CUELLO y CABEZA. 'cabeza_y' las sube y las baja: al andar cabecea, en la cornada se hunde y en
	# el enganche sube de golpe.
	poner.call(testa.call(Vector3(CUELLO.x, CUELLO.y, CUELLO.z + cabeza_y * 0.45), TESTUZ_CUELLO),
		CUELLO_R, Tono.BASE)
	poner.call(testa.call(Vector3(CABEZA.x, CABEZA.y, CABEZA.z + cabeza_y), 1.0), CABEZA_R, Tono.BASE)
	# El HOCICO en su tono solo si se le ve la cara: de espaldas lo que asoma es la nuca, y una mancha
	# oscura ahi canta como un borron en mitad del cogote.
	poner.call(testa.call(Vector3(HOCICO.x, HOCICO.y, HOCICO.z + cabeza_y), 1.0), HOCICO_R,
		Tono.HOCICO_T if not lados.is_empty() else Tono.SOMBRA)

	# OREJAS, a los lados y hacia fuera. Estas SI se ven de espaldas: son parte de la silueta.
	for lado in [-1.0, 1.0]:
		poner.call(testa.call(Vector3(lado * OREJA.x, OREJA.y, OREJA.z + cabeza_y), 1.0), OREJA_R,
			Tono.SOMBRA)

	# EL CUERNO DE DELANTE, al final. El del fondo ya se dibujo antes de la cabeza (ver mas arriba):
	# pintados los dos aqui, el del fondo se subia ENCIMA del craneo en vez de asomar por detras.
	for lado in delante_cuerno:
		cuerno.call(lado)

	if not lados.is_empty():
		# LA ANILLA: un arco de piezas colgando del hocico. Es el detalle que remata al bicho, y va
		# en laton para que no se confunda con los cuernos (que son hueso).
		for k in ANILLA_SEGMENTOS:
			var fa: float = float(k) / float(ANILLA_SEGMENTOS - 1)
			var aa: float = PI * (0.12 + 0.76 * fa)      # medio arco, colgando hacia abajo
			poner.call(testa.call(Vector3(ANILLA.x + cos(aa) * ANILLA_R, ANILLA.y,
					ANILLA.z + cabeza_y - sin(aa) * ANILLA_R), 1.0),
				Vector3.ONE * ANILLA_GROSOR, Tono.ANILLA_T)

	# OJOS, los ULTIMOS de la cara.
	for l in lados:
		poner.call(testa.call(Vector3(l * OJO.x, OJO.y, OJO.z + cabeza_y), 1.0), OJO_R, Tono.OJO_T)

	# EL BRAZO DE DELANTE, al final del todo: va por encima del torso y de la cabeza.
	for lado in delante:
		brazo.call(lado)

	return piezas


# La plantilla de un frame: que tono le toca a cada celda.
static func _plantilla(dir: int, pose: Dictionary, esc: float) -> PackedByteArray:
	var lz: Vector2i = _lienzo(esc)
	var plant := PackedByteArray()
	plant.resize(lz.x * lz.y)
	plant.fill(0)
	var piezas: Array = _piezas(dir, pose, esc)
	for p in piezas:
		var pos: Vector2 = p["pos"]
		var r: Vector2 = p["radio"]
		SpriteLienzo.elipse(plant, lz.x, lz.y, pos.x, pos.y, r.x, r.y, int(p["tono"]),
			float(p["ang"]), p["solo_sobre"], float(p["persp"]))

	# CONTORNO al final, sobre la silueta ya completa (ver SpriteLienzo.contornear).
	SpriteLienzo.contornear(plant, SpriteLienzo.caja_de_piezas(piezas, lz.x, lz.y), lz.x, lz.y,
		Tono.BORDE, Tono.VACIO, Tono.SOMBRA_SUELO)
	return plant
