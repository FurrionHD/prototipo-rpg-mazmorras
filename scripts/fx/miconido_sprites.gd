# ============================================================
#  miconido_sprites.gd  (class_name MiconidoSprites)
#  El MICONIDO (pisos 7-12) dibujado por codigo, con el motor comun (SpriteLienzo) y la camara de 45
#  grados que comparten todos los bichos. Solo geometria: quien decide que a esta ficha le toca este
#  generador es SpritesEnemigo (por NOMBRE, ver GENERADORES_POR_NOMBRE).
#
#  ES UNA SETA CON CUERPO DE HOMBRE, y esa es la lectura entera: un TORSO gordo y PALIDO, casi tan
#  ancho como alto, con un SOMBRERO oscuro y muy ancho encima cuya ala CAE por los lados, dos BRAZOS
#  finos colgando y unas patas cortas. Dibujado a partir de la referencia que paso el autor.
#
#  ES BAJO. Mide unas 23 unidades de mundo de alto contra las 44,5 del trent, y a sus escalas
#  respectivas eso son 46 pixeles contra 111: menos de la mitad. El trent es el bicho ALTO del juego;
#  este tiene proporcion de hombre y hay que verlo de un vistazo. Lo ancho lo pone el sombrero (22
#  unidades), que mide casi el doble que el cuerpo -- por eso se lee como una seta y no como un
#  muñeco con gorro.
#
#  VA POR EL PATRON DEL TRENT, NO POR EL DE LA RATA: un cuerpo de hongo es redondo en planta, o sea
#  que se ve igual desde los ocho lados. El cuerpo no gira (girarlo no cambiaria nada y costaria); lo
#  que SI gira son el SOMBRERO -- porque va ladeado --, las LAMINAS y los BRAZOS.
#
#  HASTA HOY SE DIBUJABA CON EL GENERADOR DEL TRENT, o sea que un hongo salia con forma de arbol. Y
#  la ironia es que el trent ya avisaba de este bicho sin saberlo: en su cabecera esta escrito que al
#  subirle el radio de la copa "salia un CHAMPIÑON -- una seta con patas". Lo que alli era el fallo,
#  aqui es el objetivo. Se separan solos de todas formas: aquel es alto, marron y verde, con fronda
#  desgreñada y flecos; este es bajo, palido de cuerpo y oscuro de sombrero, y liso.
#
#  ------------------------------------------------------------
#  EL PROBLEMA DE ESTE BICHO: NO TIENE CARA
#  ------------------------------------------------------------
#  Su ficha lo dice: "No tiene ojos ni boca". Y todos los demas resuelven las ocho direcciones con la
#  MIRADA -- los ojos del trent, el racimo de la araña, la cara de la rata. Aqui no hay mirada, asi
#  que sin hacer nada mas saldria una seta simetrica y NO SE SABRIA HACIA DONDE VA, que no es un
#  problema estetico sino de juego: en la mazmorra hay que leer de un vistazo si un bicho viene o se
#  aleja. Se gana de cuatro maneras a la vez, y hacen falta las cuatro:
#
#    1. EL SOMBRERO VA LADEADO hacia donde mira, y gira con la direccion. Lo dice la propia ficha --
#       "el sombrero se orienta hacia donde nota el aire moverse" --, o sea que su cara es el
#       sombrero.
#    2. LAS LAMINAS SOLO SE VEN POR DELANTE. Son la mancha mas fuerte del bicho (rayas OSCURAS que
#       cuelgan del ala y bajan por los hombros palidos), asi que de frente el pecho esta rayado y de
#       espaldas esta liso. Ese contraste es lo que dice si viene o si huye.
#    3. LOS BRAZOS se reparten delante y detras del cuerpo segun donde caigan en pantalla.
#    4. LAS PATAS DAN EL PASO, una adelantada y la otra atras, y la adelantada va en tono mas claro.
#
#  Tiene Agilidad 10 (empatado con el trent, lo mas lento del juego) y Resistencia 55 (lo mas duro),
#  y eso manda en sus animaciones igual que en las del trent: nada de nervio, todo peso -- y encajar
#  un golpe SIN retroceder.
# ============================================================

extends RefCounted
class_name MiconidoSprites

const FRAMES := 8

# --- El miconido mirando al SUR, en unidades de MUNDO (origen = donde toca el suelo, +Y hacia donde
# mira, +Z hacia arriba). ANCHO_MUNDO es el ANCHO DEL SOMBRERO, que es su medida mas grande. ---
const ANCHO_MUNDO := 22.0

# EL CUERPO: un torso gordo y palido, redondeado, MAS ANCHO QUE UN TALLO. Esto es lo que mas separa
# a este bicho de un champiñon de decoracion -- y de la primera version, que le puso un pie estrecho
# de 3,8 y salia una seta de libro en vez del bicho de la referencia.
const CUERPO := Vector3(0.0, 0.0, 12.0)
const CUERPO_R := Vector3(6.6, 5.6, 11.0)      # llega de z 1 a z 23
# Para CLAVAR los brazos hace falta un radio REDONDO en planta: con el del dibujo (que tiene mas
# ancho que fondo) los brazos quedarian a distinta distancia segun hacia donde mire y entrarian y
# saldrian del cuerpo al girar. Mismo apaño que el TRONCO_ANCLA_R del trent, y por lo mismo.
const CUERPO_ANCLA_R := Vector3(5.6, 5.6, 11.0)

# SOMBRERO: la cupula, ANCHA Y APLASTADA -- casi el doble que el cuerpo. Se le mete al cuerpo tres
# unidades (el cuerpo acaba en 20 y la base del ala esta en 20,3), o sea cinco celdas de solape a
# escala 2: suficiente para que no se despegue (ver la leccion de los cuernos del trent).
#
# VA ALTO A PROPOSITO, Y COSTO UNA VUELTA. La primera version lo puso a z 18,2 sobre un cuerpo bajo y
# gordo, y con la camara a 45 grados EL SOMBRERO SE COMIA AL BICHO ENTERO: la profundidad se proyecta
# a cos(45), asi que un disco de 22 unidades de ancho sale en pantalla casi tan ALTO como ancho -- no
# es una raya, es un ovalo enorme --, y debajo no asomaba mas que una franja de cuerpo. Con el
# sombrero arriba y el cuerpo alargado, la mitad de abajo del torso queda por fuera de la cupula, que
# es lo que hace que se lea "seta con cuerpo" y no "champiñon".
#
# Y NO ES MUCHO MAS ANCHO QUE EL CUERPO -- 16,8 contra 13,2. En la referencia el bicho es sobre todo
# CUERPO y el sombrero es su remate; puesto al doble de ancho (que fue el primer numero) lo que se
# veia era un sombrero enorme con un pegote debajo.
#
# LO QUE MANDA EN SU ALTURA EN PANTALLA NO ES SU GROSOR, ES SU FONDO. Un disco visto a 45 grados
# proyecta un semieje vertical de sqrt(fondo²·cos² + grosor²·sin²), asi que el sombrero ocupa a lo
# alto casi lo que mide de fondo -- no lo que mide de canto. Por eso adelgazarlo NO sirve de nada y
# lo unico que baja su peso en la silueta es ESTRECHARLO. Con 8,2 de fondo se comia 12,7 unidades de
# pantalla; con 7,4 se queda en 11,5, y esa unidad y pico es la que gana el cuerpo.
const SOMBRERO := Vector3(0.0, 0.0, 24.2)
const SOMBRERO_R := Vector3(8.4, 7.4, 3.4)
# EL ALA CAIDA: el reborde del sombrero, mas ancho, mas plano y MAS BAJO que la cupula. Es lo que le
# da la silueta de paraguas de la referencia -- sin el, la cupula es un casquete pegado a la cabeza y
# el bicho se lee como un muñeco con gorra.
const ALA := Vector3(0.0, 0.0, 22.6)
const ALA_R := Vector3(9.0, 8.0, 1.4)
# CUANTO SE LADEA hacia donde mira, en unidades de mundo. ES SU CARA: junto con las laminas, es lo
# que dice la direccion. Corto se pierde (a 1,5 no se distingue el norte del sur) y largo se le cae
# de la cabeza; 2,4 son casi cinco celdas de desplazamiento a escala 2, que se ven.
const LADEO := 2.4
# Y el radio REDONDO EN PLANTA con el que se clavan las verrugas: el MENOR de los dos del sombrero a
# proposito, para que el adorno caiga DENTRO de la cupula mire hacia donde mire.
const SOMBRERO_ANCLA_R := Vector3(7.4, 7.4, 3.4)
const SOMBRERO_SUBE := 0.34                    # la masa iluminada, subida sobre la de sombra
const SOMBRERO_ESC := 0.88

# LAS LAMINAS: la mancha fuerte del bicho. Rayas OSCURAS que cuelgan del bajo del ala y BAJAN POR LOS
# HOMBROS del cuerpo palido, como en la referencia. Van pintadas 'solo_sobre' el sombrero y el
# cuerpo, asi que no pueden salirse de la silueta pase lo que pase.
#
# OSCURAS SOBRE PALIDO, y no al reves: es lo que enseña la referencia y ademas es lo que funciona.
# Unas laminas claras sobre la sombra del ala solo se verian dentro de esa sombra, que es una franja
# estrecha; asi se derraman sobre el pecho, que es la superficie mas grande y clara que tiene, y la
# mancha se ve desde el otro lado de la sala.
# LO QUE SE VE NO ES LA LAMINA, ES EL HUECO ENTRE DOS. Con 9 laminas de 0,80 de ancho se tocaban
# unas con otras y todo el hombro salia como UNA MANCHA OSCURA en forma de capucha -- el bicho
# parecia encapuchado, no laminado. Y con 11 finas tampoco: a 7,2 de radio y 144 grados de abanico
# caben 18,1 unidades de arco, o sea 1,65 por lamina, y una lamina de 1,1 de ancho deja un hueco de
# media unidad -- UNA CELDA, que el contorno se come. Con OCHO el hueco es de dos celdas y se ve.
#
# La regla, para el proximo bicho rayado: hay que hacer la cuenta del arco, no poner "unas cuantas".
const LAMINAS := 8
# OCHO TROZOS: la tira baja 8 unidades, asi que el paso es de 1,14 contra un grosor que arranca en
# 1,4 -- aguanta. Con seis el paso seria de 1,6 y la lamina saldria PUNTEADA. Misma cuenta que la de
# las patas de la araña, y HAY QUE REHACERLA CADA VEZ QUE SE TOQUE LAMINA_CAE.
const LAMINA_SEGMENTOS := 8                    # cada lamina es una tira, no un punto
const LAMINA_R := Vector3(0.55, 1.4, 1.4)
const LAMINA_RADIO := 6.4                      # a que distancia del eje cuelgan
# EL ABANICO NO LLEGA A LOS 180 GRADOS, y esto se corrigio mirando: repartidas en media vuelta, las
# de los dos extremos caen en el FILO de la silueta -- ahi se ven de canto y se amontonan --, y las
# once acababan como dos alas oscuras a los lados con un claro en medio. Es exactamente el mismo
# fallo que tuvo el racimo de ojos de la araña dando la vuelta al costado de la cabeza. Recogido a
# 144 grados, las once se ven de frente y se leen como once.
const LAMINA_ARCO := 0.80                      # fraccion de PI que abarca el abanico

# EL HIMENIO: la franja en sombra del bajo del ala. Cuanto se baja en pantalla respecto del centro
# del sombrero y cuanto fondo tiene. Se dibuja SIEMPRE hacia la camara (ver el paso 10 de _piezas),
# que es donde esta el bajo de un sombrero se mire desde donde se mire.
const HIMENIO_Y := 4.2
const HIMENIO_FONDO := 3.0
const LAMINA_ARRIBA := 0.4                     # z de arranque, respecto del ala
# CUANTO BAJAN. Es el numero que decide si esto son LAMINAS o son DIENTES: a 5 se quedaban en una
# franja corta pegada al ala y el bicho parecia tener una boca con dentera. Tienen que RECORRER el
# pecho para que se lean como algo que cuelga del sombrero y se derrama por el cuerpo.
#
# Y HAY QUE PEDIR MAS DE LO QUE PARECE: la altura se proyecta a sin(45), asi que bajar 8 unidades de
# mundo son 5,7 en pantalla.
#
# PERO NO PUEDEN LLEGAR ABAJO. A 10 recorrian el torso ENTERO y el bicho salia rayado de arriba
# abajo: la carne palida desaparecia y con ella la mitad clara de la silueta, que es justo lo que lo
# separa del trent a distancia. Tienen que cubrir el pecho y dejar la panza limpia.
const LAMINA_CAE := 7.5
# Y ADELGAZAN AL BAJAR, que es como acaba una lamina de verdad. Cortadas en seco, las ocho terminaban
# a la misma altura y dejaban una RAYA HORIZONTAL cruzando el bicho, que se lee como un borde.
const LAMINA_PUNTA := 0.35                     # a que fraccion de su grosor llega la punta
# CUANTO SE ACERCAN AL EJE AL BAJAR. El cuerpo es mucho mas estrecho que el sombrero (4,8 contra
# 8,6), asi que una lamina que bajara recta se saldria del torso a media caida y el 'solo_sobre' se
# la comeria: se veria colgando del ala y desapareciendo en el aire. Pero CERRANDO DEMASIADO las once
# convergen en un punto y vuelven a ser una mancha, asi que esto es un equilibrio de los dos lados.
const LAMINA_CIERRA := 0.72
# Hasta donde puede irse una lamina hacia atras y seguir dibujandose (Y de su direccion, ya girada).
# Mismo criterio que los ojos del trent: de frente casi todas, de medio lado la mitad, de espaldas
# ninguna -- y ahi es cuando el bicho se lee como que se aleja.
const LAMINA_VISIBLE := -0.05

# BRAZOS: dos, finos, PALIDOS y colgando a los lados, con una mano de dedos largos al final. En la
# referencia son lo unico que dice que esto anda y agarra, y ademas rompen la silueta de bola.
#
# En cadena de segmentos (como la cola de la rata y las ramas del trent): una sola pieza alargada no
# se curva, y un brazo recto parece un palo clavado. EL PASO TIENE QUE SER MENOR QUE EL GROSOR o el
# brazo sale a TROZOS SUELTOS -- 1,45 de paso contra un grosor que va de 3,2 a 2,1: aguanta.
#
# CUELGAN CASI RECTOS Y PEGADOS AL CUERPO, y esto hubo que corregirlo mirando la tira: abiertos a
# 0,42 salian en aspa hacia fuera y hacia abajo, y con 1,15 de radio eran DOS ALAMBRES cruzando por
# delante de un bicho que por lo demas es todo masa. En la referencia los brazos caen pegados al
# costado y lo que se abre son los dedos. Gordos y verticales, se leen como brazos; finos y en aspa,
# como patas de araña mal puestas.
# SALEN A MEDIA ALTURA DEL TORSO (la z casi a cero), no del hombro: mas arriba nacian DENTRO de la
# zona de laminas y los dos brazos cruzaban las rayas en diagonal, con lo que el pecho salia como una
# equis. Un hongo no tiene hombros; el brazo le sale del costado.
const BRAZO_DIR := Vector3(0.94, 0.12, 0.05)   # de donde SALEN del cuerpo
const BRAZO_SEGMENTOS := 6
const BRAZO_PASO := 1.30
const BRAZO_R0 := 1.60
const BRAZO_R1 := 1.05
# CUANTO SE SEPARA DEL CUERPO cada segmento. Tiene un MINIMO que no es de gusto: el torso es un
# elipsoide de 5,6 de radio, asi que un brazo que se abra menos que eso cae DENTRO de la silueta y no
# existe -- a 0,22 no habia brazos, solo un poco de sombra en el costado. A 0,38 la mano asoma dos
# unidades y media por fuera de la panza, que se ven.
const BRAZO_ABRE := 0.32
const BRAZO_CAIDA := 1.00                      # y cuanto baja: CUELGA, no sale en horizontal
# LA MANO: dedos abiertos en abanico al final del brazo. Son cuatro motas, no una bola: una bola al
# final de un brazo se lee como un muñon.
# GORDOS Y SOLAPANDO ENTRE ELLOS Y CON LA PUNTA DEL BRAZO. Finos y separados no salian dedos: salian
# CRUCECITAS NEGRAS sueltas al lado del bicho, porque a ese tamaño el contorno se come la mota entera
# y lo unico que queda es el borde. Una mano en pixel-art es UN bulto con el filo mellado, no cuatro
# dedos dibujados de uno en uno.
const DEDOS := 4
const DEDO_LARGO := 1.0
const DEDO_R := Vector3(0.95, 0.95, 0.95)

# VERRUGAS: motas apenas mas claras por la cupula, los restos del velo. Discretas a proposito -- el
# sombrero de la referencia es liso y aterciopelado --, pero le dan ALGO a la vista de espaldas, que
# si no seria una mancha marron sin un solo detalle. Van 'solo_sobre' el sombrero iluminado, o sea
# que solo salen arriba, que es donde estan en un hongo de verdad.
const VERRUGAS := [
	Vector3(0.0, 0.34, 0.94), Vector3(-0.60, -0.34, 0.72), Vector3(0.56, -0.46, 0.68),
	Vector3(-0.32, 0.70, 0.62), Vector3(0.42, 0.64, 0.64),
]
const VERRUGA_R := Vector3(1.4, 1.4, 0.8)
const VERRUGA_HUNDE := 1.4

# PATAS: dos, cortas, gruesas y JUNTAS -- en la referencia apenas se le ve un pie asomando bajo la
# panza. Tienen que ASOMAR POR DEBAJO, que es por donde se ven: el cuerpo es un elipsoide y a la
# altura de las patas ya se ha estrechado a 3,2 de radio, asi que unas patas a 2,6 con radio 2,3
# sobresalen por los lados ademas de por abajo.
const PATA_X := 2.6
const PATA_R := Vector3(2.3, 2.3, 2.8)
const PATA_Z := 2.4
# CUANTO ADELANTA Y LEVANTA cada pata al dar el paso. Corto y bajo: Agilidad 10. Arrastra, no trota.
const PASO_LARGO := 1.9
const PASO_ALZA := 0.9

# EL CORDON DE MICELIO: el hilo palido que le sale del pie en su habilidad ("del pie le sale un
# cordon blanco, fino como un hilo y duro como un alambre"). En cadena, por lo mismo que los brazos.
# Con 18 unidades en 14 segmentos el paso es 1,29 y el grosor va de 1,5 a 1,0: aguanta.
const CORDON_SEGMENTOS := 14
const CORDON_LARGO := 18.0
# GORDO, aunque en la ficha ponga "fino como un hilo". A 0,75 de radio el cordon medía celda y media
# de ancho, y a ese grosor CONTORNEAR SE LO COME ENTERO: lo que se veia no era un hilo blanco, era la
# linea de borde -- verde oscuro -- serpenteando por el suelo. Es la misma leccion que las manos: en
# pixel-art, por debajo de tres o cuatro celdas de ancho una pieza es solo su contorno.
const CORDON_R0 := 1.15
const CORDON_R1 := 0.85
const CORDON_COMBA := 2.0                      # cuanto se arquea antes de bajar

# LA BOCANADA de esporas del sprite (el gesto; la nube que cubre a la victima la pinta CapaHechizos,
# ver el estilo NUBE_ESPORAS). Motas palidas saliendo en anillo del borde del sombrero.
const ESPORAS := 10
const ESPORA_R := Vector3(1.3, 1.3, 1.3)

const LUNGE_DIST := 4.0            # se mueve poquisimo: es lentisimo

# --- EL LIENZO, en multiplos del ancho del sombrero. Rectangular y con el origen BAJO, porque el
# origen es el punto que toca el suelo y el bicho crece hacia arriba desde ahi.
#
# ES BARATO SER GENEROSO: el horno RECORTA cada fotograma a su dibujo real y guarda el hueco como un
# margen (ver SpriteLienzo.montar_frames), asi que un lienzo grande NO engorda los fotogramas que no
# lo aprovechan. Y no tiene NADA que ver con la colision, que sale de tam_cuerpo().
#
# Lo ancho lo mandan el derrumbe de la muerte (el sombrero se desparrama a 1,45) y los brazos; lo de
# abajo, el cordon de micelio, que sale hacia delante y en pantalla eso es hacia abajo.
const LIENZO_ANCHO := 2.30
const LIENZO_ARRIBA := 1.55
const LIENZO_ABAJO := 1.20

# TONOS propios. El motor no sabe que es cada uno; solo mapea indice -> color (ver _colores).
enum Tono { VACIO, SOMBRA_SUELO, BORDE, PATA_OSC, PATA, BRAZO_OSC, BRAZO, CUERPO_OSC, CUERPO_T,
	CUERPO_CLARO, SOMBRERO_OSC, SOMBRERO_T, SOMBRERO_CLARO, LAMINA_T, HIMENIO_T, VERRUGA_T,
	ESPORA_T }

# --- Vectores de las 8 direcciones (pantalla: +Y es hacia ABAJO). Mismo orden que los demas
# generadores y que el dir8 de SpriteLienzo: 0=S 1=SE 2=E 3=NE 4=N 5=NW 6=W 7=SW. ---
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
	return "miconido_%s_%.2f" % [col.to_html(false), esc]


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(escala: float = 1.0) -> int:
	return _lienzo(escala).x


static func dimensiona_por_escala() -> bool:
	return true


# El CUERPO en planta (ancho, largo) para la colision: SOLO EL TORSO. EL SOMBRERO NO CUENTA, igual
# que no cuenta la copa del trent ni la cola de la rata: mide 22 unidades de ancho -- 44 en pantalla
# a su escala, o sea mas que el vano de una celda de 32 -- y con el metido el bicho no cabria por un
# pasillo y se quedaria trabado nada mas girar. Lo que estorba de una seta con cuerpo es el cuerpo.
# LOS BRAZOS TAMPOCO: son dos hilos que cuelgan y pasan por encima de las cosas.
# Redondo, asi que su colision no necesita girar.
static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	var lado: float = CUERPO_R.x * 2.0
	return Vector2(lado, lado) * escala


static func _lienzo(escala: float) -> Vector2i:
	var u: float = ANCHO_MUNDO * escala / SpriteLienzo.UNIDADES_POR_CELDA
	var w: int = int(ceil(u * LIENZO_ANCHO))
	var h: int = int(ceil(u * (LIENZO_ARRIBA + LIENZO_ABAJO)))
	return Vector2i(w + (w % 2), h + (h % 2))


# Donde cae el ORIGEN (el punto que toca el suelo) dentro del lienzo: centrado a lo ancho y BAJO a lo
# alto, porque el bicho crece hacia arriba desde ahi.
static func _origen(escala: float) -> Vector2:
	var l: Vector2i = _lienzo(escala)
	return Vector2(float(l.x) * 0.5, float(l.y) * LIENZO_ARRIBA / (LIENZO_ARRIBA + LIENZO_ABAJO))


static func generar(color: Color = Color(0.52, 0.46, 0.30), escala: float = 1.0) -> SpriteFrames:
	# cuantizar_hsv y no cuantizar a secas: el ocre del miconido es un color apagado y redondear canal
	# a canal le cambia el TONO -- dos canales parecidos caen en el mismo escalon y sale un gris.
	var col: Color = SpriteLienzo.cuantizar_hsv(color, COLOR_PASOS)
	var esc: float = snappedf(escala, 0.05)      # se cuantiza tambien, o el cache no acierta
	var clave: String = _clave(col, esc)
	if _cache.has(clave):
		return _cache[clave]
	var anims: Array = []
	_montar_idle(anims, esc)
	_montar_walk(anims, esc)
	_montar_embestida(anims, esc)
	_montar_esporas(anims, esc)
	_montar_micelio(anims, esc)
	_montar_encaje(anims, esc)
	_montar_muerte(anims, esc)
	_montar_cadaver(anims, esc)
	var lz: Vector2i = _lienzo(esc)
	var sf: SpriteFrames = SpriteLienzo.montar_frames(
		anims, SpriteLienzo.paleta(_colores(col)), lz.x, lz.y)
	_cache[clave] = sf
	return sf


# La pose en reposo, con todo a cero. Existe para que cada animacion escriba SOLO lo que cambia: con
# diez claves en el diccionario, repetirlas enteras en ocho sitios garantiza que un dia se olvide una
# y esa animacion se comporte distinto sin que nadie sepa por que.
static func _pose(campos: Dictionary = {}) -> Dictionary:
	var p := {"avance": 0.0, "mece": 0.0, "balanceo": 0.0, "patas": 0.0, "brazos": 0.0,
		"sacude": 0.0, "hincha": 0.0, "hunde": 0.0, "derrumbe": 0.0, "cordon": 0.0, "puff": 0.0}
	for k in campos:
		p[k] = campos[k]
	return p


# Quieto: RESPIRA. El sombrero sube y baja lentisimo y el cuerpo se mece un pelin. A 3 fps -- lo
# mismo que el trent, y por el mismo motivo: tiene Agilidad 10 y tiene que LEERSE lento antes de que
# te des cuenta mirando su barra.
#
# Y el sombrero TANTEA EL AIRE: un vaiven lateral muy corto y desacompasado del cuerpo. Es lo unico
# que hace en reposo, y es literalmente lo que su ficha dice que hace.
static func _montar_idle(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return _pose({"mece": 0.35 * sin(TAU * t),
			"sacude": 0.45 * sin(TAU * t + 1.9),
			"brazos": 0.22 * sin(TAU * t + 0.7),
			"hincha": 0.035 * (1.0 - cos(TAU * t))})
	_montar_animacion(anims, esc, "idle", true, 3.0, pose, false)


# Andando: NADA DE BOTE. Un hongo con patas cortas ARRASTRA, y lo que lo cuenta es que el sombrero va
# CON RETRASO respecto del cuerpo: el bicho se echa a un lado y la cupula llega despues, como un
# sombrero mal puesto. Ese desfase (el -1.1 del seno) es todo el peso que tiene la animacion. Los
# brazos van a su aire, medio tiempo por detras.
static func _montar_walk(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return _pose({"mece": 0.55 * sin(TAU * t * 2.0), "balanceo": sin(TAU * t),
			"sacude": 1.0 * sin(TAU * t - 1.1), "brazos": 0.8 * sin(TAU * t - 0.5),
			"patas": sin(TAU * t)})
	_montar_animacion(anims, esc, "walk", true, 5.0, pose, false)


# EMBESTIDA: se echa atras y DEJA CAER EL SOMBRERO ENCIMA, como quien vuelca. No es una carrera (su
# fx_basico es GOLPETAZO, un porrazo romo) ni un ramazo: el golpe es la masa de la cupula bajando.
# Viaja poquisimo -- LUNGE_DIST 4 contra los 8 de la araña --, y eso es informacion: dice que a este
# se le ve venir.
static func _montar_embestida(anims: Array, esc: float) -> void:
	var mece_keys := [[0.0, 0.0], [0.35, -1.5], [0.55, 2.2], [0.75, 1.5], [1.0, 0.4]]
	var avance_keys := [[0.0, 0.0], [0.35, -1.0], [0.55, 3.2], [0.75, 3.8], [1.0, 2.6]]
	# El sombrero se levanta al armar y se HUNDE sobre el cuerpo al descargar: es el peso llegando
	# abajo. 'hunde' negativo lo sube.
	var hunde_keys := [[0.0, 0.0], [0.35, -0.35], [0.55, 0.75], [0.75, 0.45], [1.0, 0.1]]
	# Y los brazos se echan atras y luego adelante, arrastrados por el cuerpo.
	var brazos_keys := [[0.0, 0.0], [0.35, -0.9], [0.55, 1.2], [0.75, 0.6], [1.0, 0.1]]
	var pose := func(t: float) -> Dictionary:
		return _pose({"avance": SpriteLienzo.tramos(t, avance_keys) * (LUNGE_DIST / 3.8),
			"mece": SpriteLienzo.tramos(t, mece_keys),
			"brazos": SpriteLienzo.tramos(t, brazos_keys),
			"hunde": SpriteLienzo.tramos(t, hunde_keys)})
	_montar_animacion(anims, esc, "embestida", false, 8.0, pose, true)


# BOCANADA DE ESPORAS (fx_anim = "esporas"). EL SOMBRERO SE HINCHA -- crece y se tensa --, aguanta, y
# SUELTA DE GOLPE. El cuerpo no se mueve del sitio: lo que sale disparado son las esporas, no el
# bicho.
#
# EL DISPARO ES EL SALTO DE TAMAÑO ENTRE DOS FOTOGRAMAS, igual que el bombeo del abdomen de la araña
# al tejer: de 0,26 de hinchado se pasa a -0,12 en un solo marco. Interpolado suave se leeria como
# que respira hondo; de golpe se lee como que ha reventado.
#
# UNA SOLA DIRECCION: solo se ve en combate, y ahi se le mira de frente (el combate degrada solo a
# "esporas_0", ver combat.gd::_on_gesto_iniciado).
static func _montar_esporas(anims: Array, esc: float) -> void:
	var hincha_keys := [[0.0, 0.0], [0.143, 0.12], [0.286, 0.22], [0.429, 0.26],
		[0.571, -0.12], [0.714, -0.04], [0.857, 0.0], [1.0, 0.0]]
	# Se agacha un poco al soltar: es el empujon.
	var hunde_keys := [[0.0, 0.0], [0.286, -0.20], [0.429, -0.25], [0.571, 0.55], [0.714, 0.30],
		[1.0, 0.05]]
	# Y la nube sale JUSTO en el marco del reventon, no antes.
	var puff_keys := [[0.0, 0.0], [0.429, 0.0], [0.571, 0.35], [0.714, 0.68], [0.857, 0.88],
		[1.0, 1.0]]
	var pose := func(t: float) -> Dictionary:
		return _pose({"hincha": SpriteLienzo.tramos(t, hincha_keys),
			"hunde": SpriteLienzo.tramos(t, hunde_keys),
			"puff": SpriteLienzo.tramos(t, puff_keys)})
	_montar_animacion(anims, esc, "esporas", false, 12.0, pose, true, 1, FRAMES)


# LATIGAZO DE MICELIO (fx_anim = "micelio"). ES LO CONTRARIO DE HINCHARSE: aqui BAJA el cuerpo y SE
# AGARRA al suelo -- de donde si no iba a tirar --, y lo que se mueve es el cordon que le sale del
# pie. El sombrero se echa atras para hacer contrapeso, que es como se tira de algo, y los brazos se
# abren buscando equilibrio.
#
# El cordon sale RAPIDO (llega al 0,286) y luego SE QUEDA: no vuelve. Esa permanencia es lo que dice
# que se ha enganchado -- que es justo lo que hace la habilidad, que aplica Enraizado.
static func _montar_micelio(anims: Array, esc: float) -> void:
	var cordon_keys := [[0.0, 0.0], [0.143, 0.45], [0.286, 1.0], [0.429, 0.96], [0.571, 1.0],
		[0.714, 0.98], [1.0, 1.0]]
	# Se hunde sobre las patas y ahi se queda, agarrado.
	var hunde_keys := [[0.0, 0.0], [0.143, 0.30], [0.286, 0.62], [0.429, 0.55], [1.0, 0.48]]
	# Y se echa hacia atras tirando del hilo.
	var mece_keys := [[0.0, 0.0], [0.143, 0.6], [0.286, -1.3], [0.429, -1.6], [0.714, -1.2],
		[1.0, -1.0]]
	var brazos_keys := [[0.0, 0.0], [0.143, 0.5], [0.286, 1.1], [0.571, 0.9], [1.0, 0.8]]
	var pose := func(t: float) -> Dictionary:
		return _pose({"cordon": SpriteLienzo.tramos(t, cordon_keys),
			"hunde": SpriteLienzo.tramos(t, hunde_keys),
			"brazos": SpriteLienzo.tramos(t, brazos_keys),
			"mece": SpriteLienzo.tramos(t, mece_keys)})
	_montar_animacion(anims, esc, "micelio", false, 12.0, pose, true, 1, FRAMES)


# ENCAJAR UN GOLPE. Cuatro fotogramas en UNA sola direccion (en combate se le ve siempre de frente) y
# EMPEZANDO YA GOLPEADO: el frame 0 es el impacto, no la pose de reposo. Un golpe no tiene
# anticipacion, y con cuatro marcos un fotograma de espera se comeria la animacion entera.
#
# ESTE NO RETROCEDE, Y ESO ES INFORMACION DE JUEGO. La araña sale despedida media embestida
# (ENCAJE_RETRO 0.55) porque pesa poco y se mata rapido; este tiene Resistencia 55, la mas alta del
# bloque, y lo que hace es COMPRIMIRSE -- el sombrero se hunde sobre el cuerpo y vuelve, como un
# tapon de corcho al que le arreas. Quien lo mire dos veces aprende que a este hay que insistirle.
static func _montar_encaje(anims: Array, esc: float) -> void:
	# 'hunde' alto en el impacto y con REBOTE (se pasa al otro lado en el tercer marco): sin ese
	# rebote seria un hongo agachandose, que se lee como que se prepara, no como que ha encajado algo.
	var hunde_keys := [[0.0, 1.0], [0.34, 0.15], [0.67, -0.30], [1.0, 0.0]]
	# Y la cupula acusa el golpe de lado medio tiempo por detras: es lo que le da el peso.
	var sacude_keys := [[0.0, 1.4], [0.34, -0.9], [0.67, 0.35], [1.0, 0.0]]
	var brazos_keys := [[0.0, -1.1], [0.34, 0.7], [0.67, -0.2], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		return _pose({"hunde": SpriteLienzo.tramos(t, hunde_keys),
			"brazos": SpriteLienzo.tramos(t, brazos_keys),
			"sacude": SpriteLienzo.tramos(t, sacude_keys)})
	# LOS BICHOS ENCAJAN A 18 fps: es la duracion que espera CombatFX.T_ENCAJE, y cuadrando las dos el
	# sprite va a su velocidad natural en vez de estirado por _pose_ajustar.
	_montar_animacion(anims, esc, "encaje", false, 18.0, pose, true, 1, 4)


# MORIRSE: SE DESHINCHA. Ocho fotogramas en UNA sola direccion -- la muerte solo se ve en la pantalla
# de combate, y ahi al bicho se le mira siempre de frente. Para el mapa esta 'cadaver'.
#
# NO VUELCA (eso es el jabali) NI SE HACE UN OVILLO (eso es la araña) NI SE CAE COMO UN ARBOL (eso es
# el trent). Un hongo muerto PIERDE LA TENSION: el cuerpo cede, el sombrero baja sobre si mismo y se
# abarquilla hacia fuera hasta quedar un monton bajo y desparramado en el suelo, con los brazos
# vencidos. Es lo que le pasa a una seta pasada de verdad, y ademas se lee IGUAL DESDE LOS OCHO LADOS
# -- que es justo lo que hace que el cadaver del mapa no dependa de por donde cayo.
#
# AQUI NO HAY BOCANADA DE ESPORAS, y da pena pero es a proposito: el horno comprueba trozos sueltos
# SOLO en 'muerte' y 'cadaver' (ANIMS_DE_UNA_PIEZA en tools/hornear_sprites.gd), y unas motas
# separadas del cuerpo son exactamente lo que canta como isla. La bocanada se queda en su animacion.
static func _pose_muerte(t: float) -> Dictionary:
	# EL DERRUMBE ACELERA: cruje y aguanta en el primer tercio, y luego se viene abajo de golpe.
	# Repartido por igual parecia un globo desinflandose despacio.
	var derr_keys := [[0.0, 0.0], [0.14, 0.08], [0.28, 0.24], [0.45, 0.58],
		[0.62, 0.86], [0.78, 1.02], [0.90, 0.96], [1.0, 1.0]]
	# El sombrero se hunde sobre el cuerpo al mismo ritmo: es lo que se traga al bicho.
	var hunde_keys := [[0.0, 0.0], [0.14, 0.20], [0.45, 0.70], [0.78, 1.0], [1.0, 1.0]]
	# Un ultimo estiron hacia arriba antes de ceder, que es el aviso de que se muere.
	var hincha_keys := [[0.0, 0.0], [0.14, 0.16], [0.28, 0.06], [0.62, -0.10], [1.0, -0.14]]
	# Y se ladea un poco al final: un monton derrumbado no queda simetrico.
	var mece_keys := [[0.0, 0.0], [0.14, -0.6], [0.45, 0.4], [1.0, 0.7]]
	# LOS BRAZOS SE VENCEN, pero POCO: 'brazos' muy negativo los estira hacia abajo y la cadena se
	# despega en trozos sueltos -- que es exactamente lo que el horno canta en 'muerte'. Es la misma
	# trampa que ya mordio el trent con sus ramas, y por eso el suyo tampoco pasa de -0,5.
	var brazos_keys := [[0.0, 0.0], [0.14, 0.4], [0.28, -0.2], [0.62, -0.45], [1.0, -0.5]]
	return _pose({"derrumbe": SpriteLienzo.tramos(t, derr_keys),
		"hunde": SpriteLienzo.tramos(t, hunde_keys),
		"hincha": SpriteLienzo.tramos(t, hincha_keys),
		"brazos": SpriteLienzo.tramos(t, brazos_keys),
		"mece": SpriteLienzo.tramos(t, mece_keys)})


static func _montar_muerte(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return _pose_muerte(t)
	_montar_animacion(anims, esc, "muerte", false, 10.0, pose, true, 1, 8)


# EL CADAVER DEL MAPA: UN fotograma por CADA UNA de las ocho direcciones, que es justo al reves que
# 'muerte' (ocho fotogramas en una sola). En el mapa no se ve morir a nadie -- se entra a la sala y el
# hongo ya esta reventado en el suelo --, pero pudo caer mirando a cualquier lado.
#
# Es EXACTAMENTE la pose final de la muerte, sacada de la MISMA funcion: reescribir los numeros aqui
# garantiza que el dia que se retoque el derrumbe el cadaver se quede como estaba y el bicho pegue un
# salto al pasar de una cosa a la otra.
static func _montar_cadaver(anims: Array, esc: float) -> void:
	var pose := func(_t: float) -> Dictionary:
		return _pose_muerte(1.0)
	# ultimo_incluido = false y NO true: con un solo marco, el divisor de _montar_animacion seria
	# (1 - 1) = 0 y el reparto de t saldria NaN. La pose se pide fija, asi que da igual.
	_montar_animacion(anims, esc, "cadaver", false, 1.0, pose, false, 8, 1)


static func _montar_animacion(anims: Array, esc: float, nombre: String,
		loop: bool, fps: float,
		pose_fn: Callable, ultimo_incluido: bool, dirs: int = 8, marcos: int = FRAMES) -> void:
	# 'dirs' y 'marcos' al final y con el valor de siempre: las animaciones normales no se enteran.
	# Estan para las que NO necesitan las ocho direcciones ni los ocho fotogramas -- morir son 8
	# marcos en UNA direccion, y el cadaver del mapa UN marco por direccion.
	var divisor: float = float(marcos - 1) if ultimo_incluido else float(marcos)
	for dir in dirs:
		var plantillas: Array = []
		for i in marcos:
			# La GEOMETRIA se cachea por (animacion, frame, direccion, escala) y NO por color: otro
			# miconido de otro tono reusa estas plantillas y solo repinta. Es lo que evita que entrar a
			# un piso lleno de bichos congele el juego.
			var clave: String = "%s_%d_%d_%.2f" % [nombre, i, dir, esc]
			var plant: PackedByteArray = _cache_plantillas.get(clave, PackedByteArray())
			if plant.is_empty():
				plant = _plantilla(dir, pose_fn.call(float(i) / divisor), esc)
				_cache_plantillas[clave] = plant
			plantillas.append(plant)
		anims.append({"nombre": "%s_%d" % [nombre, dir], "loop": loop, "fps": fps,
			"plantillas": plantillas})


# Los colores de cada Tono, EN EL ORDEN DEL ENUM (contrato con SpriteLienzo.paleta).
#
# UN HONGO SON DOS MATERIALES Y HAY QUE VERLO, igual que el trent es corteza y fronda: el SOMBRERO va
# del color de la ficha (ocre apagado) y el CUERPO va en CARNE PALIDA. Ese contraste -- claro abajo,
# oscuro arriba -- es media silueta del bicho, y ademas es lo que impide que se confunda con el trent
# a distancia, que es marron y verde de arriba abajo.
#
# La carne se DERIVA del color de la ficha (mismo tono, casi sin saturacion y mucho mas clara) y no
# se pone a pelo: asi un miconido aclarado por su 't' tiene tambien el cuerpo aclarado y no se
# despareja.
static func _colores(color: Color) -> Array:
	var c: Color = color
	# OJO CON EL TECHO DE LA CARNE. Con 1,55 + 0,20 el ocre de la ficha (v 0,52) se iba al tope de 0,92
	# y el torso salia CASI BLANCO -- una mancha plana sin volumen, y encima lo mas luminoso de toda la
	# pantalla. Es carne de hongo, o sea crema sucia, no papel.
	var carne: Color = Color.from_hsv(c.h, c.s * 0.26, clampf(c.v * 1.15 + 0.14, 0.52, 0.80))
	return [
		Color(0, 0, 0, 0),                        # VACIO
		Color(0, 0, 0, 0.24),                     # SOMBRA_SUELO
		c.darkened(0.74),                         # BORDE
		# LAS PATAS Y LOS BRAZOS CON TONO PROPIO, y no es capricho de paleta: si llevaran el del cuerpo,
		# la luz del cuerpo se pinta 'solo_sobre' ese tono y los REPINTARIA -- todo el bajo del bicho
		# seria una masa palida sin patas, que es el fallo que ya tuvo el trent. Van mas oscuros (estan
		# a la sombra del sombrero) y el/la que va delante mas claro que el de atras: eso hace legible
		# el paso y separa los dos brazos.
		carne.darkened(0.48),                     # PATA_OSC (la de detras)
		carne.darkened(0.32),                     # PATA (la adelantada, le da mas luz)
		# LOS BRAZOS, BASTANTE MAS OSCUROS QUE EL TORSO. Al tono del cuerpo se fundian con el de frente y
		# CANTABAN como dos rayas blancas contra el fondo de la mazmorra por los lados: eran lo mas
		# claro del bicho, o sea que la vista se iba a ellos en vez de al sombrero.
		carne.darkened(0.52),                     # BRAZO_OSC (el de detras del cuerpo)
		carne.darkened(0.34),                     # BRAZO (el de delante)
		carne.darkened(0.26),                     # CUERPO_OSC (el costado del torso, en penumbra)
		carne,                                    # CUERPO_T
		carne.lightened(0.14),                    # CUERPO_CLARO (la cresta iluminada del torso)
		c.darkened(0.40),                         # SOMBRERO_OSC (el ala y el borde, en penumbra)
		c,                                        # SOMBRERO_T
		# La cupula se aclara HACIA UN OCRE CALIDO, no hacia el blanco: 'lightened' desatura, y sobre un
		# ocre ya apagado el resultado es un gris. Misma leccion que el jabali y la araña.
		c.lerp(Color(0.88, 0.80, 0.58), 0.44),    # SOMBRERO_CLARO
		# LAS LAMINAS SON LA MITAD DE SU DIRECCION, asi que van MUY OSCURAS: cuelgan del ala y bajan por
		# el pecho palido, y ahi es donde tienen que cantar. Este bicho no tiene ojos -- si las laminas
		# no se ven contra la carne, no hay forma de saber si viene o si se va.
		c.darkened(0.70),                         # LAMINA_T
		# EL HIMENIO: el hueco de debajo del ala. Entre el ala iluminada y las laminas, para que las
		# laminas sigan cantando encima de el.
		c.darkened(0.54),                         # HIMENIO_T
		c.lerp(Color(0.86, 0.80, 0.62), 0.42),    # VERRUGA_T (motas discretas sobre la cupula)
		Color(0.93, 0.91, 0.84),                  # ESPORA_T (casi blanco: la bocanada)
	]


# ------------------------------------------------------------
#  GEOMETRIA
# ------------------------------------------------------------

# Una direccion desde el centro de una pieza -> el punto de su superficie en esa direccion, metido
# 'hunde' hacia dentro. Es lo que garantiza que ningun adorno flote: la superficie esta a distinta
# distancia en cada direccion, asi que un punto puesto a mano encaja mirando a un lado y se despega
# mirando al otro.
static func _en_la_pieza(dir: Vector3, hunde: float, centro: Vector3, radio: Vector3) -> Vector3:
	var d: Vector3 = dir.normalized()
	return centro + Vector3(radio.x * d.x, radio.y * d.y, radio.z * d.z) - d * hunde


# Las PIEZAS del miconido para una pose, ya proyectadas a pantalla. El orden ES la profundidad: se
# pintan en ese orden y las ultimas tapan a las primeras -- de lo mas bajo y lejano (sombra, cordon,
# patas, el brazo de detras) a lo mas alto y cercano (sombrero, laminas, el brazo de delante).
static func _piezas(dir: int, pose: Dictionary, esc: float) -> Array:
	var ang: float = DIR_VECS[dir].angle() - DIR_VECS[0].angle()
	var u: float = esc / SpriteLienzo.UNIDADES_POR_CELDA    # unidades de mundo -> celdas
	var origen: Vector2 = _origen(esc)
	var mece: float = float(pose["mece"])
	var balanceo: float = float(pose["balanceo"])
	var sacude: float = float(pose["sacude"])
	var fase_brazos: float = float(pose["brazos"])
	var avance: float = float(pose["avance"])
	var hincha: float = float(pose["hincha"])
	var hunde: float = float(pose["hunde"])
	var derrumbe: float = clampf(float(pose["derrumbe"]), 0.0, 1.0)
	var cordon: float = clampf(float(pose["cordon"]), 0.0, 1.0)
	var puff: float = clampf(float(pose["puff"]), 0.0, 1.0)

	# EL DERRUMBE: todo baja hacia el suelo y todo se abre a lo ancho, que es lo que convierte una
	# seta en un monton. Bajando sin ensanchar saldria la MISMA seta mas pequeña, que se lee como que
	# se aleja, no como que se muere.
	var baja: float = 1.0 - 0.72 * derrumbe
	var derrama: float = 1.0 + 0.45 * derrumbe

	var detras: Array = []
	var cuerpo: Array = []
	var delante: Array = []

	# EL AVANCE SE ROTA UNA VEZ Y LO LLEVAN TODAS LAS PIEZAS POR IGUAL. Sumarlo a la Y local antes de
	# rotar solo funciona si TODAS giran; el cuerpo va sin girar (es redondo), asi que se quedaria
	# saliendo siempre hacia el sur de la pantalla mientras el sombrero se va hacia donde de verdad
	# mira, y el bicho se partiria en dos.
	var desp := Vector2(0.0, avance).rotated(ang)
	# EL MECEO VA AQUI, DESPUES DE ROTAR, Y NO EN LAS COORDENADAS LOCALES DE CADA PIEZA. Es la leccion
	# que dejo escrita el trent: el cuerpo NO gira y los adornos SI, asi que el mismo meceo movia la
	# cupula en vertical y a lo que va clavado en ella en horizontal, y se separaban justo en los
	# frames de mas meceo -- los del medio del ataque, que es cuando se mira. Todo lo que desplace al
	# bicho ENTERO se aplica en pantalla, igual para las piezas que giran y para las que no.
	#
	# Y se dobla POR LA ALTURA: cuanto mas alta la pieza mas se mueve, asi que el sombrero va y viene
	# y las patas no se despegan del suelo.
	var mece_v := Vector2(balanceo * 1.5, mece * 1.4)

	# EL ARRAY DESTINO VA COMO PARAMETRO y no como variable capturada: una lambda de GDScript captura
	# por VALOR, asi que reasignar 'destino' fuera de ella no cambiaria a donde escribe, y los dos
	# brazos acabarian en el mismo saco sin dar ningun error.
	var poner := func(dest: Array, local: Vector3, r: Vector3, tono: int,
			solo_sobre: Array = [], gira: bool = true) -> void:
		var lz: float = local.z * baja
		var p := Vector2(local.x * derrama, local.y * derrama)
		var alto: float = clampf(local.z / SOMBRERO.z, 0.0, 1.4)
		var rot: Vector2 = (p.rotated(ang) if gira else p) + desp + mece_v * alto
		var sx: float = origen.x + rot.x * u
		var sy: float = origen.y + (rot.y * SpriteLienzo.COS_CAM - lz * SpriteLienzo.SIN_CAM) * u
		var ry: float = r.y * derrama
		# El aplastado va DESPUES de proyectar: lo hace SpriteLienzo.elipse con 'persp', y el valor lo
		# da persp_de a partir de los semiejes.
		dest.append({"pos": Vector2(sx, sy),
			"radio": Vector2(r.x * derrama * u, ry * u),
			"persp": SpriteLienzo.persp_de(ry, r.z * baja),
			"tono": tono, "solo_sobre": solo_sobre})

	# 1. SOMBRA DE CONTACTO, a ras de suelo y lo primero de todo (va debajo).
	poner.call(detras, Vector3(0.0, 0.0, 0.0), Vector3(CUERPO_R.x * 1.2, CUERPO_R.y * 1.2, 0.0),
		Tono.SOMBRA_SUELO, [], false)

	# 2. EL CORDON DE MICELIO, por el SUELO: sale de la base del cuerpo y se va hacia donde mira. Va
	#    antes que el cuerpo para que su arranque quede tapado -- pintado encima, se veria el hilo
	#    cruzando por delante de la panza en vez de saliendo de debajo.
	if cordon > 0.0:
		for k in CORDON_SEGMENTOS:
			var f: float = float(k) / float(CORDON_SEGMENTOS - 1)
			if f > cordon:
				break
			# Arranca metido en el cuerpo (por eso el 1.5 de partida y no 0), se arquea y baja al suelo.
			var largo: float = 1.5 + f * (CORDON_LARGO - 1.5)
			var alza: float = sin(f * PI) * CORDON_COMBA
			poner.call(detras, Vector3(sin(f * 4.2) * 1.3, largo, 1.3 + alza),
				Vector3.ONE * lerpf(CORDON_R0, CORDON_R1, f), Tono.ESPORA_T)

	# 3. LAS PATAS. GIRAN con el bicho y DAN EL PASO: una adelante y otra atras, en contrafase. La que
	#    va adelantada, en tono mas claro -- es lo que deja ver de un vistazo cual ha dado el paso, y
	#    es la cuarta pata del truco de la direccion (ver la cabecera).
	var fase_patas: float = float(pose["patas"])
	var pies: Array = []
	for lado in [-1.0, 1.0]:
		var swing: float = fase_patas * lado
		pies.append(Vector3(lado * PATA_X, swing * PASO_LARGO,
			PATA_Z + maxf(0.0, swing) * PASO_ALZA))
	for k in pies.size():
		poner.call(detras, pies[k], PATA_R,
			Tono.PATA if float(pies[k].y) >= float(pies[1 - k].y) else Tono.PATA_OSC)

	# 4. LOS BRAZOS, repartidos a los dos lados del cuerpo segun a donde caigan EN PANTALLA: el que va
	#    hacia la camara se pinta DESPUES del cuerpo y el de detras ANTES. Cual es cual sale de su Y ya
	#    girada -- una prueba de profundidad de verdad, no una tabla por direccion que haya que
	#    mantener a mano.
	var brazos: Array = []
	for lado in [-1.0, 1.0]:
		var raiz: Vector3 = _en_la_pieza(
			Vector3(lado * BRAZO_DIR.x, BRAZO_DIR.y, BRAZO_DIR.z), 1.0, CUERPO, CUERPO_ANCLA_R)
		brazos.append({"lado": lado, "raiz": raiz,
			"delante": Vector2(raiz.x, raiz.y).rotated(ang).y > 0.0})
	for b in brazos:
		if not bool(b["delante"]):
			_brazo(poner, detras, b, fase_brazos, Tono.BRAZO_OSC)

	# 5. EL CUERPO. No gira: es redondo en planta y esta centrado en el eje, asi que rotarlo no lo
	#    moveria ni un pixel y solo costaria.
	poner.call(cuerpo, CUERPO, CUERPO_R, Tono.CUERPO_OSC, [], false)
	# ...y encima el mismo, algo mas estrecho y desplazado hacia la luz, a pleno tono. Lo que queda sin
	# cubrir a un lado es el costado en penumbra, y la frontera sale curvada sola.
	poner.call(cuerpo, Vector3(CUERPO.x - CUERPO_R.x * 0.16, CUERPO.y, CUERPO.z), CUERPO_R * 0.90,
		Tono.CUERPO_T, [Tono.CUERPO_OSC], false)
	# Y la cresta iluminada de arriba, justo bajo el sombrero: es lo que le da bulto al torso en vez
	# de dejarlo como una mancha plana.
	poner.call(cuerpo, Vector3(CUERPO.x - CUERPO_R.x * 0.24, CUERPO.y, CUERPO.z + CUERPO_R.z * 0.34),
		CUERPO_R * 0.52, Tono.CUERPO_CLARO, [Tono.CUERPO_T], false)

	# --- EL SOMBRERO ---
	# LADEADO HACIA DONDE MIRA, Y GIRANDO CON LA DIRECCION: es su cara (ver la cabecera). 'sacude' lo
	# ladea ademas de lado, que es el retraso con el que le sigue al cuerpo al andar.
	#
	# HINCHA lo escala entero (la bocanada) y HUNDE lo baja sobre el cuerpo aplastandolo (el encaje y
	# la muerte). Los dos tienen que tocar el radio Y la altura: creciendo sin bajar el centro, la
	# cupula se despega del cuerpo y se queda flotando.
	var infla: float = 1.0 + hincha
	var chafa: float = 1.0 + 0.12 * hunde
	var cap := Vector3(sacude * 1.1, LADEO, SOMBRERO.z - hunde * 2.6)
	var cap_r := Vector3(SOMBRERO_R.x * infla * chafa, SOMBRERO_R.y * infla * chafa,
		SOMBRERO_R.z * infla * (1.0 - 0.26 * hunde))
	var ala := Vector3(cap.x, cap.y, ALA.z - hunde * 2.6)
	var ala_r := Vector3(ALA_R.x * infla * chafa, ALA_R.y * infla * chafa, ALA_R.z * infla)

	# 6. EL ALA primero, entera en penumbra: es el reborde ancho y bajo del paraguas.
	poner.call(delante, ala, ala_r, Tono.SOMBRERO_OSC)
	# 7. La cupula sobre ella, tambien en penumbra...
	poner.call(delante, cap, cap_r, Tono.SOMBRERO_OSC)
	# 8. ...y encima la masa iluminada, algo menor y subida. Lo que queda por debajo es el borde del
	#    ala en sombra, que es lo que hace que el ala se lea CAIDA y no como un disco plano.
	poner.call(delante, Vector3(cap.x, cap.y, cap.z + cap_r.z * SOMBRERO_SUBE),
		cap_r * SOMBRERO_ESC, Tono.SOMBRERO_T, [Tono.SOMBRERO_OSC])
	poner.call(delante, Vector3(cap.x, cap.y - cap_r.y * 0.22, cap.z + cap_r.z * 0.52),
		cap_r * 0.52, Tono.SOMBRERO_CLARO, [Tono.SOMBRERO_T])

	# 9. LAS VERRUGAS: motas discretas por la cupula. Van 'solo_sobre' el sombrero iluminado, o sea que
	#    solo salen arriba -- que es donde estan en un hongo -- y NO PUEDEN salirse de la silueta pase
	#    lo que pase. Es casi todo lo que se ve por detras.
	for v in VERRUGAS:
		var vp: Vector3 = _en_la_pieza(v, VERRUGA_HUNDE, cap, Vector3(
			SOMBRERO_ANCLA_R.x * infla, SOMBRERO_ANCLA_R.y * infla, cap_r.z))
		poner.call(delante, vp, VERRUGA_R, Tono.VERRUGA_T,
			[Tono.SOMBRERO_T, Tono.SOMBRERO_CLARO])

	# 10. EL HIMENIO: la sombra del bajo del ala. VA SIEMPRE DEL LADO DE LA CAMARA -- por eso se pone con
	#     'gira = false' y desplazado en pantalla al sitio donde ha quedado el sombrero. Un sombrero
	#     visto desde cualquier lado enseña su borde de abajo, y ese borde esta en sombra; sin esto, de
	#     perfil el bicho no tenia NADA oscuro bajo la cupula (las laminas se apilan de canto y solo
	#     dejan una raya), y se leia como un plato apoyado sobre un huevo.
	var cap_pant: Vector2 = Vector2(cap.x, cap.y).rotated(ang)
	poner.call(delante, Vector3(cap_pant.x, cap_pant.y + HIMENIO_Y, ala.z - 0.5),
		Vector3(ala_r.x * 0.94, HIMENIO_FONDO, 1.5), Tono.HIMENIO_T,
		[Tono.SOMBRERO_OSC, Tono.SOMBRERO_T, Tono.SOMBRERO_CLARO, Tono.VERRUGA_T], false)

	# 11. LAS LAMINAS: las rayas oscuras que cuelgan del ala y BAJAN POR LOS HOMBROS, y SOLO POR
	#     DELANTE. Es la pieza que mas trabaja de todo el bicho -- sin ojos, esto es lo que dice hacia
	#     donde mira. Van 'solo_sobre' el sombrero, el himenio y el cuerpo, o sea que no pueden
	#     derramarse fuera de la silueta ni pintar sobre el contorno.
	var sobre_laminas: Array = [Tono.SOMBRERO_OSC, Tono.SOMBRERO_T, Tono.SOMBRERO_CLARO,
		Tono.VERRUGA_T, Tono.HIMENIO_T, Tono.CUERPO_OSC, Tono.CUERPO_T, Tono.CUERPO_CLARO]
	for k in LAMINAS:
		# En abanico POR DELANTE del eje, no en circulo entero: las de detras no se verian nunca y solo
		# costarian. 'a' va de -72 a +72 grados con el 0 al frente (ver LAMINA_ARCO).
		var a: float = LAMINA_ARCO * PI * ((float(k) + 0.5) / float(LAMINAS) - 0.5)
		var d := Vector2(sin(a), cos(a))
		# ¿SE VE? Por donde cae la lamina en PANTALLA una vez girada, mismo criterio que los ojos del
		# trent: de frente casi todas, de medio lado la mitad, de espaldas ninguna.
		if d.rotated(ang).y <= LAMINA_VISIBLE:
			continue
		# CADA LAMINA ES UNA TIRA de varios trozos, no un punto: tiene que colgar del ala y bajar por
		# el pecho, y eso son cinco o seis unidades de recorrido. Y SE CIÑE AL EJE al bajar, porque el
		# cuerpo es mucho mas estrecho que el sombrero -- yendo recta hacia abajo, la mitad de la tira
		# caeria fuera del torso y el 'solo_sobre' se la comeria.
		for j in LAMINA_SEGMENTOS:
			var f: float = float(j) / float(LAMINA_SEGMENTOS - 1)
			var rad: float = LAMINA_RADIO * infla * lerpf(1.0, LAMINA_CIERRA, f)
			# LA PROFUNDIDAD VA ENTERA, NO COMPRIMIDA, y esto hubo que corregirlo mirando el PERFIL. Con
			# la Y a un 0,55 del radio las ocho laminas caian en una banda de 2,4 unidades de fondo: de
			# frente daba igual (ahi lo que se ve es la X), pero DE PERFIL la Y es la que recorre la
			# pantalla, asi que las ocho se amontonaban en un dedo de ancho y salia UNA sola raya. Es el
			# mismo fallo que el racimo de ojos de la araña leyendose como una banda de perfil.
			#
			# Y es ademas lo que manda el trent en su cabecera: el escorzo de una pieza tiene que ser el
			# MISMO que el de la pieza a la que va pegada. El sombrero se dibuja con la Y entera, asi que
			# lo que cuelga de el tambien.
			poner.call(delante, Vector3(cap.x + d.x * rad, d.y * rad,
					ala.z + LAMINA_ARRIBA - f * LAMINA_CAE),
				LAMINA_R * lerpf(1.0, LAMINA_PUNTA, f), Tono.LAMINA_T, sobre_laminas)

	# 12. EL BRAZO DE DELANTE, ya sobre el cuerpo.
	for b in brazos:
		if bool(b["delante"]):
			_brazo(poner, delante, b, fase_brazos, Tono.BRAZO)

	# 13. LA BOCANADA: motas casi blancas saliendo en anillo del borde del sombrero. Solo aparece en
	#     'esporas' (en la muerte no, ver el comentario de _pose_muerte), y crece con 'puff'.
	if puff > 0.0:
		for k in ESPORAS:
			var a2: float = TAU * float(k) / float(ESPORAS)
			var dist: float = cap_r.x * (0.55 + 1.05 * puff)
			poner.call(delante, Vector3(cap.x + cos(a2) * dist,
					cap.y + sin(a2) * dist * 0.85,
					ala.z + puff * 3.0),
				ESPORA_R * (1.0 - 0.45 * puff), Tono.ESPORA_T)

	return detras + cuerpo + delante


# Un BRAZO: cadena de segmentos que sale del cuerpo, se abre y CAE, con una mano de dedos al final.
# En cadena y no de una pieza porque un brazo recto parece un palo clavado; encadenado se curva.
# 'fase' lo mece hacia delante y atras (el paso, el golpe); negativo lo descuelga.
static func _brazo(poner: Callable, dest: Array, b: Dictionary, fase: float, tono: int) -> void:
	var lado: float = float(b["lado"])
	var raiz: Vector3 = b["raiz"]
	var punta := raiz
	for k in BRAZO_SEGMENTOS:
		var f: float = float(k) / float(BRAZO_SEGMENTOS - 1)
		# Se abre hacia fuera y va CAYENDO. El meneo crece hacia la punta: el hombro apenas se mueve,
		# como en un brazo de verdad.
		var abre: float = BRAZO_PASO * float(k)
		punta = Vector3(
			raiz.x + lado * abre * BRAZO_ABRE + lado * fase * f * 0.9,
			raiz.y + abre * 0.14 + fase * f * 2.2,
			# OJO al tocar esto: 'fase' no puede estirar mucho la cadena o los segmentos se separan y
			# el brazo sale a trozos sueltos justo durante el ataque, que es cuando se mira.
			raiz.z - abre * BRAZO_CAIDA + fase * f * 0.7)
		poner.call(dest, punta, Vector3.ONE * lerpf(BRAZO_R0, BRAZO_R1, f), tono)
	# LA MANO: los dedos en abanico desde la punta. Cuatro motas y no una bola -- una bola al final de
	# un brazo se lee como un muñon, y en la referencia los dedos son largos y abiertos.
	for j in DEDOS:
		var a: float = PI * (0.20 + 0.60 * float(j) / float(DEDOS - 1))
		poner.call(dest, punta + Vector3(lado * cos(a) * DEDO_LARGO * 0.8,
			sin(a) * DEDO_LARGO * 0.5, -DEDO_LARGO * 0.75), DEDO_R, tono)


# La plantilla de un frame: que tono le toca a cada celda.
static func _plantilla(dir: int, pose: Dictionary, esc: float) -> PackedByteArray:
	var lz: Vector2i = _lienzo(esc)
	var plant := PackedByteArray()
	plant.resize(lz.x * lz.y)
	var piezas: Array = _piezas(dir, pose, esc)
	for p in piezas:
		var pos: Vector2 = p["pos"]
		var r: Vector2 = p["radio"]
		SpriteLienzo.elipse(plant, lz.x, lz.y, pos.x, pos.y, r.x, r.y, int(p["tono"]),
			0.0, p["solo_sobre"], float(p["persp"]))

	# CONTORNO al final, sobre la silueta ya completa (ver SpriteLienzo.contornear).
	SpriteLienzo.contornear(plant, SpriteLienzo.caja_de_piezas(piezas, lz.x, lz.y), lz.x, lz.y,
		Tono.BORDE, Tono.VACIO, Tono.SOMBRA_SUELO)
	return plant
