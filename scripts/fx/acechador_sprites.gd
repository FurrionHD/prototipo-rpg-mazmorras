# ============================================================
#  acechador_sprites.gd  (class_name AcechadorSprites)
#  Sprite del ACECHADOR DE LAS SIMAS dibujado por codigo, con el motor comun (SpriteLienzo) y la
#  camara de 45 grados que comparten todos los bichos. Aparece del piso 10 en adelante.
#
#  ES UN CUADRUPEDO, asi que va por el patron del JABALI y de la RATA: el cuerpo ENTERO gira con la
#  direccion, que es lo que hace un animal al cambiar de rumbo.
#
#  PERO SE DIBUJA COMO LA LECTURA CONTRARIA DEL JABALI, y eso es todo el encargo: comparten familia
#  (BESTIA) y comparten esqueleto, asi que si no se separan a proposito salen el mismo bicho dos
#  veces. Punto por punto:
#    * EL JABALI ES BAJO Y ANCHO; este es ALTO Y ESTRECHO. Las patas son LARGAS -- el cuerpo va un
#      palmo por encima del suelo, no arrastrando -- y de dos piezas, con su caña fina: eso es lo que
#      dice "corre" en vez de "pesa".
#    * EL JABALI TIENE LA CRUZ ALTA DELANTE y el lomo cae hacia la grupa. Este lo tiene AL REVES: la
#      GRUPA alta, los hombros hundidos y la cabeza BAJA Y ADELANTADA, por debajo de la linea del
#      lomo. Es la postura de acecho, y se lee de un vistazo desde cualquiera de los ocho lados.
#    * MORRO LARGO CON MANDIBULA en vez de hocico romo con colmillos hacia arriba. Tiene dentellada
#      (COLMILLAZO), no cornada.
#    * COLA LARGA Y BAJA, de las que barren el suelo. El jabali lleva un muñon.
#    * NI UNA CERDA. Lo unico erizado es una crin corta en la nuca.
#
#  SU COLOR ES EL PROBLEMA DE DIBUJO: Color(0.3, 0.27, 0.24), un marron casi negro sin apenas
#  saturacion -- que es lo que lo hace un acechador y no se le puede quitar. Un bicho de un solo tono
#  oscuro se lee como una mancha, asi que TODO lo que se distingue en el son las tres cosas CLARAS
#  que lleva encima: los OJOS (amarillo palido), los COLMILLOS (hueso) y la rampa de LOMO iluminada.
#  Es la misma solucion que la cicatriz roja del Rey rata: sobre un bicho oscuro, un tono mas oscuro
#  todavia no es un detalle, es nada.
#
#  El TAMAÑO se consigue con MAS CELDAS, no con celdas mas gordas: ver SpriteLienzo.UNIDADES_POR_CELDA.
# ============================================================

extends RefCounted
class_name AcechadorSprites

const FRAMES := 8

# --- El acechador mirando al SUR, en unidades de MUNDO (origen = donde toca el suelo, +Y hacia el
# morro, +Z hacia arriba). A escala 1.0 mide unas 30 unidades del morro a la punta de la grupa. ---
const LARGO_MUNDO := 30.0

# --- EL TRONCO, en tres piezas. Estrecho: 5 de semiancho contra los 7,6 del jabali. Doscientos kilos
# de jabali son un barril; esto es un galgo con dientes.
#
# LA LINEA DEL LOMO SUBE HACIA ATRAS -- pecho z 12.6, tronco 13.4, grupa 15.2 --, que es justo lo
# contrario del jabali. Un depredador que acecha lleva los cuartos traseros cargados y listos para
# saltar, y los hombros hundidos.
# LA RAMPA HAY QUE EXAGERARLA. Con pecho 12,6 y grupa 15,2 la diferencia se comia el aplastado de la
# camara y el bicho salia como un tubo horizontal: un saco, no un depredador. Separados 5 unidades
# (11,6 contra 16,6) la linea del lomo se ve subir desde cualquiera de los ocho lados.
#
# Y EL TRONCO VA ALTO Y FINO. Al primer intento estaba a z 13 y con 4,2-5,0 de semialtura, y en la
# tira de perfil salia un PERRO SALCHICHA: un tronco gordo casi tocando el suelo con cuatro tacos
# oscuros debajo. Lo que hace largas a unas patas no es dibujarlas largas, es que haya SITIO entre el
# suelo y la panza -- y lo que hace fino a un galgo es que el tronco sea mas bajo de lo que es largo.
const PECHO := Vector3(0.0, 5.2, 13.2)
const PECHO_R := Vector3(4.5, 5.4, 3.9)
const TRONCO := Vector3(0.0, -1.4, 15.2)
const TRONCO_R := Vector3(4.2, 7.6, 3.5)
# LA GRUPA BAJA Y ENSANCHA para alcanzar a las patas traseras. Estaba en z 18,0 con 4,7 de semiancho,
# y a la altura del muslo (x = 3,2) la elipse ya solo bajaba hasta z 14,85 contra un muslo que llega
# a 16,4: **1,5 unidades de solape, dos celdas**. El test de islas daba 0 porque TOCAN -- pero dos
# celdas no se leen como una pata pegada al cuerpo, se leen como una pata volando, y eso lo canto el
# usuario en el visor. A 17,0 con 5,0 de semiancho el solape sube a 3,1 unidades y la grupa sigue muy
# por encima del pecho (13,2), que es lo que dibuja la postura de acecho.
#
# MORALEJA: el test de islas es un suelo, no un techo. Contesta "¿se toca?" y la pregunta de verdad
# es "¿se lee pegado?" -- y esa solo la contesta mirar el bicho.
const GRUPA := Vector3(0.0, -9.0, 17.0)
const GRUPA_R := Vector3(5.0, 5.0, 4.8)

# ESCAPULAS: los omoplatos, a los lados del pecho. Un cuadrupedo de patas largas los saca por encima
# de la linea del lomo al andar, y ese sube-y-baja alternado es la mitad de lo que se lee como
# "anda". Van en tono LOMO -- son lo mas alto del cuarto delantero, o sea donde da la luz.
const ESCAPULA := Vector3(4.1, 5.6, 16.2)
const ESCAPULA_R := Vector3(1.7, 2.9, 2.6)
const ESCAPULA_SUBE := 1.5

# CUELLO: una cadena corta que baja del pecho a la cabeza. EN CADENA y no una pieza alargada porque
# tiene que CURVARSE (la cabeza sube en el bramido del salto y baja en el acecho), y una elipse
# estirada no se curva. Paso 2,0 contra un radio de 2,4-2,0: el diametro SOBRA sobre el paso, que es
# la regla que se paga cara cada vez que se olvida.
# FINO, y eso es la mitad de la silueta: con 2,4-2,0 de radio el cuello rellenaba el hueco entre el
# pecho y el craneo y el bicho salia como un TUBO del morro a la cola, sin cabeza que se distinguiera.
# Lo que hace que una cabeza se lea como cabeza es que haya un estrechamiento antes.
const CUELLO_SEGMENTOS := 3
const CUELLO_A := Vector3(0.0, 8.6, 12.6)
const CUELLO_B := Vector3(0.0, 13.2, 11.0)
const CUELLO_R0 := 1.95
const CUELLO_R1 := 1.65

# CABEZA: BAJA -- z 9,0 contra los 15,2 de la grupa -- y muy adelantada. Es la postura, no un adorno.
const CABEZA := Vector3(0.0, 15.9, 10.4)
const CABEZA_R := Vector3(3.0, 3.3, 2.9)
# MORRO LARGO Y ESTRECHO, y por DEBAJO del eje de la cabeza: un canido lleva la caña de la nariz
# bajando desde la frente. Puesto a la misma altura salia un morro de oso.
const MORRO := Vector3(0.0, 19.7, 9.4)
const MORRO_R := Vector3(1.8, 2.7, 1.6)
# MANDIBULA: debajo del morro y algo mas corta. Es lo que convierte un cono en una boca.
const MANDIBULA := Vector3(0.0, 18.9, 7.9)
const MANDIBULA_R := Vector3(1.6, 2.2, 1.1)
# OREJAS: PUNTIAGUDAS y hacia atras. Se dibujan altas y estrechas, al reves que los discos de la rata.
const OREJA := Vector3(2.1, 14.3, 13.6)
const OREJA_R := Vector3(1.1, 0.9, 2.2)
# OJOS: lo unico claro de la cara. Grandes para lo pequeña que es la cabeza, a proposito.
const OJO := Vector3(1.9, 17.6, 11.1)
const OJO_R := Vector3(0.85, 0.85, 0.85)
# COLMILLOS: cuatro, cortos y hacia ABAJO (los del jabali suben curvandose; los de este muerden).
const COLMILLO := Vector3(1.25, 20.4, 8.3)
const COLMILLO_R := Vector3(0.5, 0.5, 0.95)
const COLMILLO_SEPARA := 1.9      # cuanto se separan el de delante y el de atras

# CRIN: la unica pieza erizada, corta y en la nuca. Con la camara a 45 grados hay que subirla 1,41
# unidades de mundo por cada una que se quiera ver asomar (es la nota de las cerdas del jabali).
const CRIN := Vector3(0.0, 10.4, 14.0)
const CRIN_R := Vector3(1.9, 3.2, 1.9)

# --- LAS PATAS: LARGAS y de DOS PIEZAS (muslo grueso arriba, caña fina abajo) mas la zarpa. Es la
# diferencia de silueta mas grande con el jabali, que las lleva cortas y de una sola pieza.
#
# EL SOLAPE ENTRE MUSLO Y CAÑA SE MIDE EN Z Y TIENE QUE SOBRAR, no cuadrar: muslo de 3,4 a 13,4 y
# caña de -0,2 a 6,6, o sea 3,2 unidades comunes = 5 celdas a escala 1,8. El primer intento les dejo
# 2,2 y el test de islas canto 141 fotogramas con una pata suelta: en cuanto la pata se balancea o se
# encoge, un solape justo deja de serlo. Es la misma regla que se pago con los sillares del coloso.
#
# Y las tres piezas de una pata se mueven JUNTAS con el balanceo, porque el swing va en Y y el solape
# esta en Z: separandolas, la caña se descuelga en cuanto la pata se adelanta.
# PATA_X TIENE QUE SER BASTANTE MENOR QUE EL SEMIANCHO DEL TRONCO, y esta es LA causa de que la pata
# flotara -- lo canto el usuario mirando el visor y el test de islas llevaba tres vueltas señalandola
# sin que yo viera por que. Estaba en 4,2 contra un TRONCO_R.x de 4,2 EXACTAMENTE: la pata nacia
# justo en el borde de la elipse del cuerpo, y en el borde de una elipse el cuerpo tiene grosor CERO.
# Daba igual cuanto engordara el muslo o cuanto solaparan las alturas: por ahi no habia nada a lo que
# agarrarse. A 3,2 el tronco todavia conserva el 65% de su altura, y la pata entra en carne.
#
# Es la version en planta de la regla de siempre (un solape tiene que sobrar, no cuadrar), y pica mas
# porque los numeros que se comparan estan en constantes distintas y ni se parecen entre si.
const PATA_X := 3.2
const PATA_Y := [6.4, -8.6]                     # delanteras y traseras
# EL MUSLO ES LA PIEZA QUE COSE LA PATA AL CUERPO, y por eso es gorda en las TRES medidas. El fallo
# se repitio con las medidas afinadas del segundo intento: el test cantaba islas de 5x15 px, que es
# EXACTAMENTE la pata entera de arriba abajo -- no se descosia por dentro, es que se soltaba del
# tronco. Un muslo estrecho en profundidad (r.y 2,2) aguanta de pie y se sale en cuanto el trote lo
# adelanta, porque lo que solapa con el cuerpo es justo ese radio.
const MUSLO_R := Vector3(1.6, 2.9, 5.4)
const MUSLO_Z := 11.0
const CANA_R := Vector3(0.9, 1.15, 3.9)
const CANA_Z := 5.2
const ZARPA_R := Vector3(1.45, 2.0, 1.05)
const ZARPA_Z := 0.9
# EL CORVEJON: cuanto se va la caña hacia ATRAS respecto al muslo. Solo en las traseras, y es lo que
# dibuja la Z de la pata de un canido. En las delanteras la caña cae a plomo. CORTO a proposito: cada
# unidad que se desplaza es solape que se pierde, y la pieza que se descuelga es siempre la de abajo.
const CORVEJON := 1.0
# CUANTO SE ABRE LA PATA AL BAJAR. El muslo tiene que nacer METIDO en el cuerpo (ver PATA_X) y eso
# tiene un precio: metido, de frente queda tapado por el tronco entero y el bicho se lee como un
# POSTE sin patas -- que es justo como salia en la tira de idle mirando al sur. Abriendo solo la caña
# y la zarpa se arregla sin descoser nada, porque lo que cose la pata al cuerpo es el muslo y ese no
# se mueve. Y ademas es lo que hace un cuadrupedo: el cuerpo es ancho arriba y las patas caen por
# fuera de la panza.
#
# Y ES CORTO (0,55). A 1,1 la caña se salia del muslo: desplazar en X cuesta solape igual que
# desplazar en Z, y las dos cosas se suman en la misma junta. Aqui se gana lectura de frente sin
# tocar la junta que aguanta la pata.
const PATA_ABRE := 0.55
# Cuanto adelanta y atrasa la pata el trote. Tambien corto por lo mismo: con 2,6 la pata trasera se
# salia de la grupa por detras en la mitad del ciclo.
const PASO_LARGO := 1.9
# Y cuanto se encoge la pata al recogerla en el aire (sube la caña hacia el muslo, o sea AUMENTA el
# solape: encoger una pata nunca puede descoserla).
const PATA_ENCOGE := 1.8

# COLA: larga, baja y en cadena, como la de la rata -- una sola elipse no se curva. Nace en la grupa
# y CAE: mandada solo hacia atras subiria en pantalla (con la camara a 45 grados, alejarse y elevarse
# son el mismo eje) y saldria una antena por encima del lomo, que es exactamente lo que le paso a la
# rata en su dia. Se manda atras Y abajo, que se cancelan.
#
# SE CONSTRUYE POR PASOS UNITARIOS Y NO COMO PUNTOS DE UNA CURVA, que es la leccion de los brazos
# del golem y del coloso y aqui se volvio a pagar entera: al primer intento la cola eran ocho puntos
# de una parabola (y lineal, z al cuadrado), y en una parabola los puntos se ABREN segun avanza --
# entre los dos ultimos habia 3,1 unidades de hueco contra 1,4 de diametro. Resultado: 141 fotogramas
# con la punta de la cola suelta, y en el test se veian como una escalerita de motas de 3-6 px.
#
# Con pasos unitarios el paso es el MISMO siempre, se curve lo que se curve: se avanza una distancia
# fija en la direccion actual y luego se gira la direccion. Asi el solape esta garantizado por
# construccion en vez de por suerte.
#
# Y HAY QUE CONTAR CUANTA COLA SALE FUERA DEL CUERPO, no cuanta cola se dibuja. Al primer intento
# nacia en y -12,4 con la grupa llegando hasta -14,2: los dos primeros segmentos iban DENTRO de la
# grupa y, con lo que cae, de los ocho solo asomaban cinco unidades. En la tira de perfil el bicho
# sencillamente NO TENIA COLA. Nace mas atras, cae menos al principio y lleva dos piezas mas.
# Y NACE POR DEBAJO DE LA GRUPA, no a su altura: puesta en z 16,4 salia por encima del lomo y lo que
# se veia detras del bicho no se leia como una cola, se leia como que la grupa acababa en punta.
#
# Y LA BASE VA METIDA EN LA GRUPA, no pegada a su borde: en y -14,2 contra una grupa que acaba en
# -14,0, la primera pieza de la cola quedaba FUERA del cuerpo y solo se cosia por su propio radio.
# De pie aguantaba y al tumbarse se soltaba -- las 8 islas que quedaban eran todas de muerte y
# cadaver. Es exactamente el mismo error que el de PATA_X, cometido dos veces en el mismo bicho.
const COLA_SEGMENTOS := 11
const COLA_BASE := Vector3(0.0, -12.8, 15.4)
const COLA_PASO := 1.2             # menor que el diametro mas fino (2 x 0,8 = 1,6): SOBRA
# SALE YA CAYENDO (0,55 rad y no 0,15), y esto es lo que se vio mirando la tira: casi horizontal, la
# cola se iba hacia atras, o sea hacia ARRIBA en pantalla, y salia como una ANTENA fina por encima
# del lomo. Es literalmente el fallo que ya tuvo la cola de la rata, y la regla es la misma: lo que
# va hacia atras hay que mandarlo tambien hacia abajo, porque en pantalla los dos son el mismo eje.
const COLA_ANG0 := 0.62            # inclinacion de salida (0 = horizontal hacia atras)
const COLA_GIRO := 0.10            # cuanto baja el morro de la cola en cada paso
const COLA_R0 := 1.25
const COLA_R1 := 0.8
const COLA_BARRE := 2.6            # cuanto la mueve de lado a lado
# Y ademas se le COMPRIME el escorzo, igual que a las cerdas del jabali y por lo mismo: es una fila
# de piezas a lo largo del eje de profundidad, asi que mirando al norte o al sur la de mas atras sube
# en pantalla mucho mas que la de delante y las ocho se apilan en una raya vertical. Comprimido, la
# cola se lee como una cola desde los ocho lados.
#
# Y VALE 1,0, o sea NO SE COMPRIME. Se probo a 0,80 y el usuario lo caza en el visor mirando al NW:
# la cola salia despegada de la grupa. Es el mismo fallo que ya obligo a soltar el escorzo al volcar,
# solo que este se ve tambien de pie -- comprimir la profundidad de UNA pieza y no la del cuerpo del
# que cuelga las desplaza en pantalla por formulas distintas, y la junta se abre. El escorzo sirve
# para una fila de piezas SUELTAS (las cerdas del jabali, que no cuelgan de nada); una cola nace de
# un sitio concreto y tiene que quedarse ahi.
#
# Lo que evita que salga como una antena no es el escorzo: es que CAIGA de verdad (ver COLA_ANG0).
const COLA_ESCORZO := 1.0

# EL SALTO: su embestida NO es una carga escarbando como la del jabali -- es un salto. Tiene agilidad
# 45 y chase_speed_mult 3,2, el mas rapido del juego, y eso hay que verlo.
const LUNGE_DIST := 13.0
const SALTO_ALTO := 5.2            # cuanto se despega del suelo en el aire
# ENCAJAR UN GOLPE: FRACCION de su salto que lo empuja hacia atras el impacto. ALTO, al reves que el
# jabali: este pesa poco y sale despedido, que es lo que dice "ligero".
const ENCAJE_RETRO := 0.34

# Lienzo CUADRADO y holgado: el bicho gira, asi que lo que manda es su DIAGONAL, y ademas el salto lo
# desplaza y el cadaver se tumba. El numero sale de MEDIR la caja real de los frames, no de calcularla:
# con 2,10 el horno canto que la embestida hacia el este se salia en tres fotogramas. Es el bicho mas
# largo del juego (42 unidades del morro a la punta de la cola) y ademas el que mas se desplaza al
# atacar (13 unidades de salto), y las dos cosas se suman en el mismo eje.
const LIENZO_FACTOR := 2.75

# TONOS propios (el motor no sabe que es cada uno; solo mapea indice -> color, ver _colores).
enum Tono { VACIO, SOMBRA_SUELO, BORDE, PATA, SOMBRA, BASE, LOMO, CRIN_T, MORRO_T, COLMILLO_T, OJO_T }

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
	return "acechador_%s_%.2f" % [col.to_html(false), esc]


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(escala: float = 1.0) -> int:
	return _celdas(escala)


static func dimensiona_por_escala() -> bool:
	return true


# El CUERPO en planta (ancho, largo) para la colision. Lo ancho lo marcan las PATAS; lo largo, del
# morro a la grupa. LA COLA NO CUENTA: es un hilo, y la leccion de la rata fue justo esa -- medir el
# bicho de morro a punta de cola lo dejaba dibujado pequeñito dentro de su caja.
#
# Sale ESTRECHO Y LARGO (ratio > 1.3), asi que enemy.gd le gira la colision con la direccion: de
# costado ocupa el doble que de frente, y con una caja fija chocaria justo por donde cabe.
static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	# Lo ancho lo marcan las ZARPAS y no los muslos: las patas se abren al bajar (ver PATA_ABRE), asi
	# que la parte mas ancha del bicho esta abajo, que es ademas donde toca el suelo.
	var ancho: float = (PATA_X + PATA_ABRE + ZARPA_R.x) * 2.0
	var largo: float = (MORRO.y + MORRO_R.y) - (GRUPA.y - GRUPA_R.y)
	return Vector2(ancho, largo) * escala


static func _celdas(escala: float) -> int:
	var lado: int = int(ceil(LARGO_MUNDO * escala * LIENZO_FACTOR / SpriteLienzo.UNIDADES_POR_CELDA))
	return lado + (lado % 2)      # par, para que el centro caiga limpio


static func generar(color: Color = Color(0.3, 0.27, 0.24), escala: float = 1.0) -> SpriteFrames:
	# cuantizar_hsv y no cuantizar a secas: este es el bicho MAS apagado del juego (saturacion 0,2) y
	# redondear canal a canal le cambiaria el TONO -- tres canales tan parecidos caen en el mismo
	# escalon y sale un gris plano. Le paso lo mismo al Rey rata en su dia.
	var col: Color = SpriteLienzo.cuantizar_hsv(color, COLOR_PASOS)
	var esc: float = snappedf(escala, 0.05)      # se cuantiza tambien, o el cache no acierta
	var clave: String = _clave(col, esc)
	if _cache.has(clave):
		return _cache[clave]
	# Todo en UN atlas recortado (ver SpriteLienzo.montar_frames): el bicho es alargado y gira, asi
	# que el lienzo cuadrado que necesita su diagonal es casi todo aire transparente.
	var anims: Array = []
	_montar_idle(anims, esc)
	_montar_walk(anims, esc)
	_montar_embestida(anims, esc)
	_montar_encaje(anims, esc)
	_montar_muerte(anims, esc)
	_montar_cadaver(anims, esc)
	var lado: int = _celdas(esc)
	var sf: SpriteFrames = SpriteLienzo.montar_frames(
		anims, SpriteLienzo.paleta(_colores(col)), lado, lado)
	_cache[clave] = sf
	return sf


# La pose de reposo, con TODAS las claves a cero. Existe para que cada _montar_* escriba solo lo suyo
# y no se le olvide ninguna: una clave que falta no da error en GDScript, devuelve 0.0 por el 'get' y
# el fallo sale a la cara en el dibujo, que es donde mas cuesta encontrarlo.
static func _reposo() -> Dictionary:
	return {"avance": 0.0, "estira": 1.0, "patas": 0.0, "agacha": 0.0, "cabeza": 0.0,
		"alza": 0.0, "cola": 0.0, "recoge": 0.0}


# Quieto: acecha. Respira poco y despacio -- un depredador al acecho se queda MUY quieto, y eso hay
# que dibujarlo con quietud, no con nervio. Lo unico que se mueve de verdad es la punta de la cola,
# que es justo lo que delata a un gato agazapado.
static func _montar_idle(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["estira"] = 1.0 + 0.015 * sin(TAU * t)
		p["cabeza"] = -0.25 + 0.2 * sin(TAU * t)     # la lleva BAJA, y apenas la mueve
		p["cola"] = sin(TAU * t)                     # la cola sí: barre de lado a lado
		return p
	_montar_animacion(anims, esc, "idle", true, 6.0, pose, false)


# Andando: trote LARGO y suelto. A 10 fps, como la rata y por encima de los 8 del jabali: corre a
# 55-69 y persigue a 3,2x, o sea que es lo mas rapido que hay. El lomo ondula un poco y las escapulas
# suben y bajan alternadas -- eso ultimo es lo que hace que un cuadrupedo de patas largas "ande" en
# vez de deslizarse.
static func _montar_walk(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["estira"] = 1.0 + 0.025 * sin(TAU * t * 2.0)
		p["patas"] = sin(TAU * t)
		p["agacha"] = 0.05 * (1.0 - cos(TAU * t * 2.0))
		p["cabeza"] = -0.3 + 0.55 * sin(TAU * t)
		p["cola"] = sin(TAU * t * 0.5)
		return p
	_montar_animacion(anims, esc, "walk", true, 10.0, pose, false)


# AGAZAPARSE -> SALTAR -> caer encima -> recuperar. NO es periodica, asi que va por TRAMOS.
#
# ES UN SALTO Y NO UNA CARGA, y esa es la diferencia con el jabali (que escarba y embiste a ras de
# suelo). Se hunde sobre los cuartos traseros, se despega del suelo -- 'alza', que sube el bicho
# entero MENOS la sombra de contacto -- y cae con las zarpas por delante. La separacion entre el
# bicho y su sombra es lo unico que se lee como "esta en el aire".
static func _montar_embestida(anims: Array, esc: float) -> void:
	# Retrocede un pelin al agazaparse (el -1,4): coger impulso se dibuja yendo hacia atras primero.
	var avance_keys := [[0.0, 0.0], [0.26, -1.4], [0.50, 4.6], [0.70, 8.6], [0.86, 9.4], [1.0, 7.0]]
	var alza_keys := [[0.0, 0.0], [0.26, 0.0], [0.42, 0.75], [0.58, 1.0], [0.74, 0.35], [0.86, 0.0],
		[1.0, 0.0]]
	# Se ENCOGE al agazaparse y se ESTIRA en el aire: un felino en vuelo es una linea larga.
	#
	# PERO EL ESTIRON TIENE TECHO. Con 1,18 el test cantaba una pata suelta en el pico del salto, y es
	# por como funciona 'estira': alarga el bicho en Y y lo ESTRECHA en X a la vez (ancho = 1/estira),
	# asi que en el fotograma mas estirado las patas tienen el minimo de cuerpo con el que agarrarse
	# justo cuando ademas estan recogidas. 1,10 sigue leyendose como un felino en vuelo y aguanta.
	var estira_keys := [[0.0, 1.0], [0.26, 0.92], [0.50, 1.08], [0.70, 1.10], [0.86, 0.95], [1.0, 1.0]]
	var agacha_keys := [[0.0, 0.0], [0.26, 0.80], [0.50, 0.20], [0.70, 0.0], [0.86, 0.55], [1.0, 0.1]]
	# La cabeza se hunde en el acecho y se ADELANTA en la mordida del final.
	var cabeza_keys := [[0.0, -0.3], [0.26, -1.5], [0.50, -0.2], [0.70, 0.4], [0.86, -1.2], [1.0, -0.3]]
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["avance"] = SpriteLienzo.tramos(t, avance_keys) * (LUNGE_DIST / 9.4)
		p["alza"] = SpriteLienzo.tramos(t, alza_keys) * SALTO_ALTO
		p["estira"] = SpriteLienzo.tramos(t, estira_keys)
		p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
		p["cabeza"] = SpriteLienzo.tramos(t, cabeza_keys)
		# Las cuatro patas RECOGIDAS en el aire y extendidas al caer. Va con el alza, que es
		# exactamente cuando estan encogidas, y por su propia clave: 'patas' es el trote y aqui no
		# esta trotando.
		p["recoge"] = SpriteLienzo.tramos(t, alza_keys)
		p["cola"] = 0.4
		return p
	_montar_animacion(anims, esc, "embestida", false, 12.0, pose, true)


# ENCAJAR UN GOLPE. Cuatro fotogramas en UNA sola direccion (en combate se le ve siempre de frente)
# y EMPEZANDO YA GOLPEADO: el frame 0 es el impacto, no la pose de reposo. Un golpe no tiene
# anticipacion, y con cuatro marcos un fotograma de espera se comeria la animacion entera.
#
# ESTE SALE DESPEDIDO, al reves que el jabali (que es una mole y apenas acusa). Pesa 70 de vida y
# tiene agilidad 45: retrocede lo suyo, se le doblan las patas y levanta la cabeza de golpe.
static func _montar_encaje(anims: Array, esc: float) -> void:
	# 'agacha' no pasa de 0,80: por encima de 1,0 la altura se vuelve negativa y las piezas dejan de
	# pintarse SIN DAR ERROR.
	var agacha_keys := [[0.0, 0.80], [0.34, 0.30], [0.67, 0.08], [1.0, 0.0]]
	var estira_keys := [[0.0, 0.84], [0.34, 1.10], [0.67, 0.96], [1.0, 1.0]]
	var retro_keys := [[0.0, 1.0], [0.34, 0.48], [0.67, 0.14], [1.0, 0.0]]
	# La cabeza SUBE de golpe: en el salto la lleva hundida, y aqui se la levantan de un tortazo.
	var cabeza_keys := [[0.0, 2.2], [0.34, -0.9], [0.67, 0.2], [1.0, -0.3]]
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["avance"] = -SpriteLienzo.tramos(t, retro_keys) * (LUNGE_DIST * ENCAJE_RETRO)
		p["estira"] = SpriteLienzo.tramos(t, estira_keys)
		p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
		p["cabeza"] = SpriteLienzo.tramos(t, cabeza_keys)
		p["cola"] = -0.8
		return p
	# TODOS LOS BICHOS ENCAJAN A 18 fps: es la duracion que espera CombatFX.T_ENCAJE, y cuadrando las
	# dos el sprite va a su velocidad natural en vez de estirado por _pose_ajustar.
	_montar_animacion(anims, esc, "encaje", false, 18.0, pose, true, 1, 4)


# MORIRSE. OCHO fotogramas en UNA sola direccion: la muerte solo se ve en la pantalla de combate, y
# ahi al bicho se le mira siempre de frente. Para el mapa esta 'cadaver', que es lo contrario.
#
# SE DESPLOMA DE COSTADO, como el jabali, pero NO de golpe: a este las patas le fallan y se va
# doblando: no son doscientos kilos que pierden el equilibrio, es un animal ligero que se queda sin
# fuerzas. Por eso el volcado arranca antes y sube casi recto en vez de acelerarse al final.
#
# Y CAE UN PELIN MAS ALLA DEL COSTADO (1.12 y no 1.0): con el costado exacto no se sabe si esta
# tumbado o agachado. Pasado un poco, el lomo mira al suelo, las patas quedan al aire hacia la camara
# y se lee de un vistazo. Ademas es lo que activa el reordenado del dibujo (ver el final de _piezas),
# sin el cual las patas de arriba salen tapadas por el tronco.
static func _pose_muerte(t: float) -> Dictionary:
	var tumba_keys := [[0.0, 0.0], [0.14, 0.12], [0.28, 0.34], [0.45, 0.62],
		[0.62, 0.88], [0.78, 1.06], [0.90, 1.14], [1.0, 1.12]]
	# El apoyo acompaña a la vuelta: sin el, el bicho se gira DENTRO del suelo en vez de sobre el. Los
	# numeros salen de mirar la tira -- lo que sobresale por abajo cambia de pieza segun el angulo.
	var apoyo_keys := [[0.0, 0.0], [0.14, 0.4], [0.28, 1.6], [0.45, 3.0],
		[0.62, 4.2], [0.78, 4.9], [0.90, 5.1], [1.0, 5.0]]
	# Las patas ceden PRIMERO y del todo: es lo que cuenta que se queda sin fuerzas.
	var agacha_keys := [[0.0, 0.15], [0.14, 0.62], [0.28, 0.88], [0.45, 0.80], [1.0, 0.62]]
	# Y la cabeza se descuelga hasta el suelo. En vida ya la lleva baja; muerta, del todo.
	var cabeza_keys := [[0.0, -0.3], [0.14, -1.1], [0.45, -2.2], [1.0, -2.6]]
	# La cola se queda tendida y quieta.
	var cola_keys := [[0.0, 0.6], [0.28, 0.3], [1.0, 0.0]]
	# GIRA A PERFIL MIENTRAS CAE. Sin esto no se ve NADA: de frente, el eje sobre el que vuelca apunta
	# a la camara (ver 'rumbo' en _piezas), y girar alrededor de la linea de vision no cambia nada.
	var rumbo_keys := [[0.0, 0.0], [0.14, 0.10], [0.28, 0.40], [0.45, 0.76], [0.62, 0.95], [1.0, 1.0]]
	var p: Dictionary = _reposo()
	p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
	p["cabeza"] = SpriteLienzo.tramos(t, cabeza_keys)
	p["cola"] = SpriteLienzo.tramos(t, cola_keys)
	p["tumba"] = SpriteLienzo.tramos(t, tumba_keys)
	p["rumbo"] = SpriteLienzo.tramos(t, rumbo_keys) * PI * 0.5
	p["apoyo"] = SpriteLienzo.tramos(t, apoyo_keys)
	return p


static func _montar_muerte(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return _pose_muerte(t)
	_montar_animacion(anims, esc, "muerte", false, 10.0, pose, true, 1, 8)


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
			# La GEOMETRIA se cachea por (animacion, frame, direccion, escala) y NO por color: otro
			# acechador de otro tono reusa estas plantillas y solo repinta. Es lo que evita que entrar
			# a un piso lleno de bichos congele el juego.
			var clave: String = "%s_%d_%d_%.2f" % [nombre, i, dir, esc]
			var plant: PackedByteArray = _cache_plantillas.get(clave, PackedByteArray())
			if plant.is_empty():
				plant = _plantilla(dir, pose_fn.call(float(i) / divisor), esc)
				_cache_plantillas[clave] = plant
			plantillas.append(plant)
		anims.append({"nombre": "%s_%d" % [nombre, dir], "loop": loop, "fps": fps,
			"plantillas": plantillas})


# El marron del acechador es tan apagado que, cuantizado, se le va el tono y sale un gris de asfalto.
# Se le sube un poco la saturacion para devolverle lo terroso sin cambiarle el color de la ficha (que
# lo usa el resto del juego: particulas, tinte por fuerza, marcador de la barra de accion).
static func _calido(color: Color) -> Color:
	var out := Color.from_hsv(color.h, minf(1.0, color.s * 1.30 + 0.12), color.v)
	out.a = color.a
	return out


# Los colores de cada Tono, EN EL ORDEN DEL ENUM (contrato con SpriteLienzo.paleta).
static func _colores(color: Color) -> Array:
	var base: Color = _calido(color)
	return [
		Color(0, 0, 0, 0),                    # VACIO
		Color(0, 0, 0, 0.22),                 # SOMBRA_SUELO
		base.darkened(0.72),                  # BORDE
		# PATA: casi negra, como los calcetines de un lobo. Y ademas hace que las patas largas se
		# lean como patas y no como una prolongacion del tronco.
		base.darkened(0.60),                  # PATA
		base.darkened(0.32),                  # SOMBRA (el costado, en penumbra)
		base,                                 # BASE
		# EL LOMO se aclara hacia un PARDO CENIZA y no hacia el blanco: 'lightened' desatura, y sobre
		# un marron ya apagado deja un gris sucio. Este es el unico modelado que tiene el bicho: sin
		# el, con su color, es una silueta negra y ya.
		base.lerp(Color(0.62, 0.56, 0.47), 0.42),   # LOMO (la rampa que sube hacia la grupa)
		base.darkened(0.50),                  # CRIN_T (la crin corta de la nuca)
		base.darkened(0.24),                  # MORRO_T (la caña de la nariz, algo mas clara)
		Color(0.92, 0.89, 0.80),              # COLMILLO_T (hueso, bien claro: muerde)
		# LOS OJOS AMARILLOS son la marca del bicho. Es lo unico saturado que lleva encima y lo que
		# lo hace legible de lejos en un piso oscuro -- un acechador se ve por los ojos.
		Color(0.95, 0.82, 0.28),              # OJO_T
	]


# ------------------------------------------------------------
#  GEOMETRIA
# ------------------------------------------------------------

# Las PIEZAS del acechador para una pose, ya proyectadas a pantalla. El orden ES la profundidad: se
# pintan en ese orden y las ultimas tapan a las primeras, asi que va de lo mas bajo (sombra, patas,
# cola) a lo mas alto y cercano (lomo, cabeza, colmillos, ojos).
static func _piezas(dir: int, pose: Dictionary, esc: float) -> Array:
	# RUMBO: un giro EXTRA en planta, encima del de la direccion (default 0.0, o sea que las poses de
	# siempre no lo notan). Hace falta para morir: el eje sobre el que un bicho se tumba es el que va
	# del morro a la grupa, y de frente ese eje apunta justo a la camara -- girar alrededor de la
	# linea de vision no cambia la silueta. Hay que ponerlo antes de perfil para que la vuelta se vea.
	var ang: float = DIR_VECS[dir].angle() - DIR_VECS[0].angle() + float(pose.get("rumbo", 0.0))
	var u: float = esc / SpriteLienzo.UNIDADES_POR_CELDA    # unidades de mundo -> celdas
	var centro: float = float(_celdas(esc)) * 0.5
	var estira: float = float(pose["estira"])
	var agacha: float = float(pose["agacha"])
	var avance: float = float(pose["avance"])
	var fase_patas: float = float(pose["patas"])
	var cabeza_y: float = float(pose["cabeza"])
	var alza: float = float(pose["alza"])
	var cola_fase: float = float(pose["cola"])
	var recoge: float = float(pose["recoge"])
	# TUMBARSE, en cuartos de vuelta sobre el eje que va del morro a la grupa: 1.0 = de costado. Y
	# 'apoyo', lo que hay que subirlo despues para que acabe SOBRE el suelo y no medio enterrado. Los
	# dos con default, para que las poses de siempre no paguen ni una operacion.
	var tumba: float = float(pose.get("tumba", 0.0)) * PI * 0.5
	var apoyo: float = float(pose.get("apoyo", 0.0))
	var ct: float = cos(tumba)
	var st: float = sin(tumba)

	# Agazapado = mas bajo y algo mas largo (se estira hacia delante al bajar el cuarto delantero).
	var largo: float = estira * (1.0 + 0.07 * agacha)
	var ancho: float = 1.0 / maxf(0.5, estira)
	var alto: float = 1.0 - 0.26 * agacha

	var piezas: Array = []
	# EL AVANCE SE ROTA UNA VEZ Y LO LLEVAN TODAS LAS PIEZAS POR IGUAL. Sumarlo a la Y local antes de
	# rotar solo funciona si TODAS giran; en cuanto una no lo hace, se va disparada hacia el sur de la
	# pantalla mientras el resto del bicho sale hacia donde de verdad mira.
	var desp := Vector2(0.0, avance).rotated(ang)
	# local (x ancho, y largo, z altura, en unidades de mundo) -> celda de pantalla.
	# El aplastado va DESPUES de girar: lo hace SpriteLienzo.elipse con 'persp', y el valor exacto lo
	# da persp_de a partir de los semiejes. Calcularlo antes -- deformando el radio aqui y dejando que
	# el motor rotara una elipse ya achatada -- hacia que de perfil el cuerpo saliera mas CORTO de lo
	# que mide.
	# 'escorzo' < 1 comprime lo que la PROFUNDIDAD sube o baja esa pieza en pantalla.
	# 'en_suelo' deja la pieza pegada al suelo: ni se tumba, ni se apoya, ni SALTA. Es lo que hace que
	# la sombra se quede abajo mientras el bicho esta en el aire, y esa separacion es lo unico que se
	# lee como "esta saltando".
	var poner := func(local: Vector3, r: Vector3, tono: int, solo_sobre: Array = [],
			escorzo: float = 1.0, en_suelo: bool = false) -> void:
		# TUMBAR, lo primero: gira el punto alrededor del eje morro-grupa, o sea en el plano
		# ANCHO-ALTURA. Lo que era el costado pasa a mirar al cielo.
		var lx: float = local.x
		var lz: float = local.z
		if tumba != 0.0 and not en_suelo:
			lx = local.x * ct + local.z * st
			lz = -local.x * st + local.z * ct
		var p := Vector2(lx * ancho, local.y * largo)
		var rot: Vector2 = p.rotated(ang) + desp
		var z: float = lz * alto + (0.0 if en_suelo else apoyo + alza)
		var sx: float = centro + rot.x * u
		var sy: float = centro + (rot.y * escorzo * SpriteLienzo.COS_CAM
			- z * SpriteLienzo.SIN_CAM) * u
		var ry: float = r.y * largo
		# EL RADIO TAMBIEN GIRA: al tumbarse, el semieje a lo ANCHO pasa a ser el vertical y al reves.
		# Sin esto un bicho de costado sale igual de gordo que de pie, que es lo que delata el truco.
		# Con |sen| como mezcla, media vuelta no cambia la forma -- que es justo lo correcto.
		var mezcla: float = absf(st)
		var rx: float = r.x if en_suelo else lerpf(r.x, r.z, mezcla)
		var rz: float = r.z if en_suelo else lerpf(r.z, r.x, mezcla)
		# LA PERSPECTIVA SE MIDE SOBRE EL RADIO YA ROTADO, y esto es lo que arreglo las patas traseras.
		#
		# El motor aplasta el eje VERTICAL DE PANTALLA por 'persp' DESPUES de girar la elipse, pero
		# 'persp_de' recibe 'ry' -- el radio a lo LARGO del bicho. Las dos cosas solo coinciden cuando
		# el bicho mira al SUR: girado 90 grados, el que cae en vertical es el radio a lo ANCHO, no el
		# largo. Con el muslo (1,6 de ancho, 2,9 de largo, 5,4 de alto) mirando al este le tocaban 2,39
		# de semialtura donde le corresponden 3,98: **perdia el 40%**, se quedaba corto y se soltaba de
		# la grupa. Por eso el usuario lo veia "mal en todas las posiciones MENOS en S" -- que es
		# exactamente la firma de un fallo que depende del giro, y lo que lo delato.
		#
		# El radio que de verdad cae en vertical tras girar es sqrt(rx²sen² + ry²cos²), que es la misma
		# expresion que usa 'elipse' para su caja envolvente. Pasandole ESE a persp_de, el sur no se
		# mueve ni un pixel y las otras siete quedan bien.
		#
		# OJO: el sesgo esta en el MOTOR y lo tienen todos los bichos; se corrige aqui y no alli porque
		# tocar 'persp_de' cambiaria los diez sprites ya aprobados y horneados. Solo se nota en piezas
		# MUY asimetricas entre ancho y largo, que es justo lo que son estas patas.
		var rxm: float = rx * ancho
		var s_a: float = sin(ang)
		var c_a: float = cos(ang)
		var ry_rot: float = sqrt(rxm * rxm * s_a * s_a + ry * ry * c_a * c_a)
		piezas.append({"pos": Vector2(sx, sy), "radio": Vector2(rxm * u, ry * u),
			"gira_forma": true, "tono": tono, "ang": ang,
			"persp": SpriteLienzo.persp_de(ry_rot, rz * alto), "solo_sobre": solo_sobre})

	# SOMBRA DE CONTACTO, lo primero (va debajo). A ALTURA CERO y con 'en_suelo': acompaña al bicho
	# por el suelo cuando salta, pero NO sube con el. Y se encoge un poco con el alza, que es lo que
	# hace una sombra de verdad al despegarse su dueño.
	# Y ES ESTRECHA, no del ancho del bicho: sus patas son largas y casi negras, y con una sombra
	# ancha por debajo se fundian con ella -- todo el bajo del bicho salia como una mancha oscura
	# sin patas. En el jabali no pasa porque las lleva cortas y el barril las tapa casi enteras.
	var sombra_r: float = 1.0 - 0.22 * (alza / maxf(0.001, SALTO_ALTO))
	poner.call(Vector3(0.0, TRONCO.y, 0.0),
		Vector3(TRONCO_R.x * 0.72 * sombra_r, TRONCO_R.y * 0.92 * sombra_r, 0.0),
		Tono.SOMBRA_SUELO, [], 1.0, true)

	# COLA: en cadena, hacia atras Y hacia abajo (que se cancelan en pantalla) y barriendo de lado.
	# Va lo primero de todo lo solido: nace en la grupa y queda POR DETRAS del bicho, asi que si se
	# pintara al final se subiria encima del tronco cuando el bicho mira al norte.
	# POR PASOS UNITARIOS: se avanza COLA_PASO en la direccion actual y DESPUES se gira. El paso no
	# cambia nunca, asi que dos piezas seguidas se solapan igual al principio que en la punta.
	#
	# Y EL ESCORZO SE SUELTA AL TUMBARSE. Comprimir la profundidad es un apaño para el bicho DE PIE
	# (evita que la fila de piezas se apile en una raya al mirarlo de frente), pero el cuerpo no lo
	# lleva -- va a 1,0 --, asi que mientras el bicho vuelca la cola se desplazaba en pantalla por una
	# formula distinta que la grupa de la que cuelga y las dos se separaban. Era la ultima isla que
	# quedaba, y solo en 'muerte'. Tumbado ya no hay fila que apilar, asi que el apaño sobra.
	var cola_p: Vector3 = COLA_BASE
	var cola_ang: float = COLA_ANG0
	var cola_esc: float = lerpf(COLA_ESCORZO, 1.0, minf(1.0, tumba / (PI * 0.5)))
	for k in COLA_SEGMENTOS:
		var f: float = float(k) / float(COLA_SEGMENTOS - 1)
		# El barrido se abre hacia la punta: la base casi no se mueve, como una cola de verdad. Va
		# sumado al dibujar y NO acumulado en la cadena, o el barrido tambien separaria las piezas.
		var barre: float = cola_fase * COLA_BARRE * f * f
		poner.call(Vector3(cola_p.x + barre, cola_p.y, cola_p.z),
			Vector3.ONE * lerpf(COLA_R0, COLA_R1, f), Tono.SOMBRA, [], cola_esc)
		cola_p.y -= cos(cola_ang) * COLA_PASO
		cola_p.z -= sin(cola_ang) * COLA_PASO
		cola_ang += COLA_GIRO

	# PATAS: LARGAS y de tres piezas (muslo, caña y zarpa) que se mueven JUNTAS con el balanceo. Al
	# trotar, delanteras y traseras van en contrafase, y los dos lados tambien: es el paso cruzado.
	#
	# En el salto 'fase_patas' llega negativo y grande: ahi no es el trote, es RECOGER las cuatro
	# patas bajo el cuerpo, asi que se usa el mismo balanceo pero tirando de las cuatro hacia dentro.
	for lado in [-1.0, 1.0]:
		for k in PATA_Y.size():
			var delantera: bool = k == 0
			# El trote: delanteras contra traseras, y un lado contra el otro. Es el paso cruzado.
			var swing: float = fase_patas * (1.0 if delantera else -1.0) * lado
			# RECOGER es OTRA cosa que el trote y va en su propia clave. Mezcladas en una sola (el
			# primer intento) las cuatro patas seguian yendo alternadas en el aire -- dos hacia
			# delante y dos hacia atras --, o sea trotando en el vacio, que es justo lo que no hace un
			# felino saltando. Recogiendo, las CUATRO se meten bajo el cuerpo a la vez.
			var mete: float = recoge * (1.0 if delantera else -1.0) * 1.6
			var base_y: float = PATA_Y[k] + swing * PASO_LARGO - mete
			var corvejon: float = 0.0 if delantera else -CORVEJON
			# Y la pata se ENCOGE al recoger: la caña y la zarpa suben HACIA el muslo, que es
			# aumentar el solape. Encoger una pata no puede descoserla nunca.
			var encoge: float = recoge * PATA_ENCOGE
			poner.call(Vector3(lado * PATA_X, base_y, MUSLO_Z), MUSLO_R, Tono.PATA)
			poner.call(Vector3(lado * (PATA_X + PATA_ABRE * 0.7), base_y + corvejon,
				CANA_Z + encoge), CANA_R, Tono.PATA)
			poner.call(Vector3(lado * (PATA_X + PATA_ABRE), base_y + corvejon * 0.4,
				ZARPA_Z + encoge * 1.5), ZARPA_R, Tono.PATA)

	# EL TRONCO, en tres piezas y de atras hacia delante. La GRUPA va primero y el PECHO al final:
	# asi el cuarto delantero, que es lo que mira a la camara cuando el bicho viene hacia ti, se
	# recorta sobre el resto.
	poner.call(GRUPA, GRUPA_R, Tono.BASE)
	poner.call(TRONCO, TRONCO_R, Tono.BASE)
	poner.call(PECHO, PECHO_R, Tono.BASE)

	# LOMO iluminado: la rampa que SUBE del pecho a la grupa (al reves que la del jabali). Va MAS ALTO
	# que el eje del cuerpo -- la luz viene de arriba --, asi que en pantalla queda desplazado hacia
	# arriba y la mitad de abajo se queda en tono base = el costado en penumbra. Solo sobre BASE, para
	# no aclarar ni las patas ni el contorno.
	#
	# Y ES ESTRECHA A LO LARGO (0,72 y no 1,02) Y CORRIDA HACIA LA GRUPA. Cubriendo el tronco entero
	# se comia el modelado: el bicho salia como un bulto claro uniforme del cuello a la cola, sin
	# costado en penumbra y por tanto sin volumen ninguno. Una banda de luz tiene que dejar ver el
	# tono base a los dos lados, o no es una banda de luz -- es repintar el bicho.
	poner.call(Vector3(0.0, TRONCO.y - 2.8, TRONCO.z + TRONCO_R.z * 0.72),
		Vector3(TRONCO_R.x * 0.52, TRONCO_R.y * 0.72, TRONCO_R.z), Tono.LOMO, [Tono.BASE])

	# ESCAPULAS: suben y bajan alternadas al andar. En tono LOMO, que es donde da la luz.
	for lado in [-1.0, 1.0]:
		var sube: float = fase_patas * lado * ESCAPULA_SUBE
		poner.call(Vector3(lado * ESCAPULA.x, ESCAPULA.y, ESCAPULA.z + maxf(0.0, sube)),
			ESCAPULA_R, Tono.LOMO, [Tono.BASE, Tono.LOMO])

	# CRIN: corta y erizada, en la nuca. Lo unico que tiene de puas.
	poner.call(Vector3(CRIN.x, CRIN.y, CRIN.z + CRIN_R.z * 0.5), CRIN_R, Tono.CRIN_T)

	# CUELLO: la cadena que baja del pecho a la cabeza. 'cabeza_y' la mueve entera, repartida a lo
	# largo de la cadena (la base casi no se entera, la punta sigue a la cabeza), o el cuello se
	# quedaria clavado mientras la cabeza sube y baja y se descoseria del craneo.
	for k in CUELLO_SEGMENTOS:
		var f: float = float(k) / float(CUELLO_SEGMENTOS - 1)
		var c: Vector3 = CUELLO_A.lerp(CUELLO_B, f)
		poner.call(Vector3(c.x, c.y, c.z + cabeza_y * f), Vector3.ONE * lerpf(CUELLO_R0, CUELLO_R1, f),
			Tono.BASE)

	# QUIEN LE VE LA CARA: de ESPALDAS no se le ven ni los ojos ni los colmillos -- con la camara a 45
	# grados un bicho que se aleja enseña la grupa, y eso es lo que hace que se lea de un vistazo si
	# viene o si huye.
	#
	# Y aqui pesa el DOBLE que en el jabali: los ojos amarillos son lo unico brillante que lleva
	# encima, asi que dibujados siempre serian dos faroles mirandote desde la nuca. Lo mismo con los
	# colmillos, que ademas van bajos y no los tapa nada.
	var frente: float = DIR_VECS[dir].y
	var lados: Array = [-1.0, 1.0]
	if frente <= -0.5:
		lados = []
	elif frente < -0.2:
		lados = [signf(DIR_VECS[dir].x)]

	# CABEZA, MORRO y MANDIBULA. 'cabeza_y' las sube y las baja a las tres por igual.
	poner.call(Vector3(CABEZA.x, CABEZA.y, CABEZA.z + cabeza_y), CABEZA_R, Tono.BASE)
	# La caña de la nariz va en su tono solo si se le ve la cara: de espaldas lo que asoma es la nuca,
	# y una mancha clara ahi canta como un borron en mitad del lomo.
	poner.call(Vector3(MORRO.x, MORRO.y, MORRO.z + cabeza_y), MORRO_R,
		Tono.MORRO_T if not lados.is_empty() else Tono.SOMBRA)
	poner.call(Vector3(MANDIBULA.x, MANDIBULA.y, MANDIBULA.z + cabeza_y), MANDIBULA_R, Tono.SOMBRA)

	# OREJAS: puntiagudas y hacia atras. Estas SI se ven de espaldas -- es lo primero que se le ve a
	# un lobo que se aleja.
	for lado in [-1.0, 1.0]:
		poner.call(Vector3(lado * OREJA.x, OREJA.y, OREJA.z + cabeza_y), OREJA_R, Tono.CRIN_T)

	# COLMILLOS: cuatro, cortos y hacia ABAJO. Dos por lado, uno delante del otro, que es lo que
	# convierte dos puntitos en una dentadura.
	for lado in lados:
		for j in 2:
			poner.call(Vector3(lado * COLMILLO.x, COLMILLO.y - float(j) * COLMILLO_SEPARA,
					COLMILLO.z + cabeza_y), COLMILLO_R, Tono.COLMILLO_T)

	# OJOS, con la misma regla. Van los ULTIMOS de todo: son lo mas claro del bicho y no los puede
	# tapar nada.
	for l in lados:
		poner.call(Vector3(l * OJO.x, OJO.y, OJO.z + cabeza_y), OJO_R, Tono.OJO_T)

	# VOLCADO, DOS GRUPOS CAMBIAN DE LADO. El orden de esta lista ES la profundidad -- aqui no hay
	# z-buffer -- y esta cableado para un bicho DE PIE: las patas primero (el tronco las tapa) y el
	# lomo al final (es lo mas alto). Tumbado, esos dos son justo al reves: las patas quedan al aire y
	# el lomo mirando al suelo.
	#
	# SE MUEVEN SOLO ESOS DOS, y no se invierte la lista entera, que fue el primer intento en el
	# jabali: invertir tambien le da la vuelta al orden de piezas que se distinguen por DONDE ESTAN A
	# LO LARGO del bicho y no por su altura, y el animal se quedaba SIN CABEZA en los ultimos
	# fotogramas -- el tronco pintado encima del morro. Ademas rompe los 'solo_sobre': el lomo se
	# pinta sobre BASE, y pintado antes que el cuerpo no encuentra nada sobre lo que ir.
	if tumba > PI * 0.5:
		var antes: Array = []
		var enmedio: Array = []
		var despues: Array = []
		for pz in piezas:
			var tn: int = int(pz["tono"])
			if tn == Tono.PATA:
				despues.append(pz)          # al aire: ahora van encima
			elif tn == Tono.CRIN_T:
				antes.append(pz)            # la nuca mira al suelo
			else:
				enmedio.append(pz)
		# La sombra de contacto tiene que seguir siendo la primera de todas: es una mancha en el
		# suelo, y el suelo no se vuelca.
		piezas = enmedio.slice(0, 1) + antes + enmedio.slice(1) + despues

	return piezas


# La plantilla de un frame: que tono le toca a cada celda.
static func _plantilla(dir: int, pose: Dictionary, esc: float) -> PackedByteArray:
	var lado: int = _celdas(esc)
	var plant := PackedByteArray()
	plant.resize(lado * lado)
	plant.fill(0)
	var piezas: Array = _piezas(dir, pose, esc)
	for p in piezas:
		var pos: Vector2 = p["pos"]
		var r: Vector2 = p["radio"]
		SpriteLienzo.elipse(plant, lado, lado, pos.x, pos.y, r.x, r.y, int(p["tono"]),
			float(p["ang"]), p["solo_sobre"], float(p["persp"]))

	# CONTORNO al final, sobre la silueta ya completa (ver SpriteLienzo.contornear).
	SpriteLienzo.contornear(plant, SpriteLienzo.caja_de_piezas(piezas, lado, lado), lado, lado,
		Tono.BORDE, Tono.VACIO, Tono.SOMBRA_SUELO)
	return plant
