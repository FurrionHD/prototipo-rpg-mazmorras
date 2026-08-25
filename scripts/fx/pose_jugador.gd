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
# De la planta a la coronilla, en unidades de mundo. Referencias para no perder el sitio: el slime
# mide 34 de diametro y el jabali 28 de largo. Un humano de pie tiene que leerse mas ALTO que ancho
# es un slime, y ademas necesita alto de sobra para que las cinco piezas de armadura se distingan:
# a menos de esto, el peto y los pantalones se tocan y no hay quien vea donde acaba uno.
const ALTO_MUNDO := 37.0

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

const PIE_X := 3.5                                  # separacion de los pies (medio paso de ancho)
const PIE := Vector3(PIE_X, 0.6, 1.7)
const RODILLA := Vector3(PIE_X, 0.0, 8.4)
const CADERA := Vector3(0.0, 0.0, 15.4)             # el pivote de todo el tronco
const TORSO := Vector3(0.0, 0.0, 21.8)
# LOS HOMBROS VAN DENTRO DEL ANCHO DEL PECHO, no fuera. Puestos por fuera, los brazos salian como
# dos apendices pegados de canto y el personaje se leia con los codos separados del cuerpo -- que
# ademas es la silueta que menos sitio deja para una hombrera.
const HOMBRO := Vector3(4.9, 0.0, 26.9)
const CODO := Vector3(5.4, 0.5, 21.9)
# La mano en reposo cae por delante del cuerpo, no pegada al muslo: es de donde cuelga el arma, y
# pegada al costado el arma se metia DENTRO de la pierna en cuanto el personaje se giraba de lado.
#
# PERO EL BRAZO TIENE QUE ROZAR EL CUERPO. Una persona lleva los brazos con un dedo de aire entre el
# codo y el costado, y eso, dibujado, es UN PIXEL de fondo entre el brazo y el tronco -- o sea un
# brazo suelto flotando al lado del personaje. No hay termino medio a esta escala: o toca o esta
# despegado. Asi que la mano va mas metida de lo que estaria en una persona de verdad.
const MANO := Vector3(5.4, 1.9, 17.4)
# EL CUELLO VA BAJO Y LARGO, metido dentro del pecho. Puesto donde estaria en una persona, su parte
# de abajo quedaba a seis centesimas de unidad de la parte de arriba del pecho -- solidos en el
# papel, un pixel de aire en la pantalla --, y al correr, con el tronco inclinado, ese pixel se
# abria: la cabeza y el cuello se iban flotando por encima de los hombros. Sale en el validador de
# islas del horno como un trozo suelto de 34 px, que es la cabeza entera.
const CUELLO := Vector3(0.0, 0.0, 28.5)
const CABEZA := Vector3(0.0, 0.3, 32.9)
# La cabeza es GRANDE en proporcion a lo que seria una persona (4.0 de radio sobre 37 de alto es
# casi un quinto del cuerpo, y una persona es un septimo). Es deliberado: a este tamaño de pixel la
# cabeza es lo que identifica al personaje en el mapa, ademas de donde va tu icono y el casco.
# Bajarla a proporciones reales deja una bolita de tres pixeles donde no cabe nada.
const CABEZA_R := 4.0                               # 32.9 + 4.0 = 36.9, o sea ALTO_MUNDO

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
static func animacion(mirada: Vector2, modo: int, moviendose: bool, golpeando: bool = false) -> String:
	var d: int = SpriteLienzo.dir8(mirada)
	if golpeando:
		return "golpe_%d" % d
	if not moviendose:
		# Agachado quieto SIGUE agachado. Poner el idle de pie al pararte delataba el sigilo: se te
		# veia levantarte cada vez que soltabas la tecla.
		return "sigilo_%d" % d if modo == 0 else "idle_%d" % d
	if modo == 0:
		return "sigilo_%d" % d
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
	return montar(pose, dir, esc)


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
	piezas.append({
		"pos": Vector2(sx, sy), "radio": Vector2(maxf(0.02, ex * uu), maxf(0.02, ey * uu)),
		"persp": 1.0, "tono": tono, "ang": 0.0, "gira_forma": false,
		"solo_sobre": opts.get("solo_sobre", []),
	})


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
#  LAS POSES
# ============================================================
# Una funcion por animacion. Las CICLICAS van con sin(TAU*t) -- se repiten y tienen que empalmar sin
# salto --, y las que NO son periodicas van por TRAMOS: un golpe es tomar impulso, descargar y
# recomponerse, no una onda.

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
	return {"bote": 0.22 * sin(TAU * t), "brazo": 0.035 * sin(TAU * t),
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
	return {"agacha": 0.44, "inclina": 0.18, "bote": 0.08 * sin(TAU * t),
		"paso": 0.20 * sin(TAU * t), "brazo": 0.10 * sin(TAU * t)}


# Andando. Los brazos van en contrafase con las piernas y el cuerpo sube dos veces por ciclo (una
# por pisada), no una: es lo que separa un paso de un balanceo de barca.
static func _pose_walk(t: float) -> Dictionary:
	return {"paso": 0.42 * sin(TAU * t), "brazo": 0.30 * sin(TAU * t),
		"bote": 0.34 * absf(sin(TAU * t)), "inclina": 0.05}


# Corriendo. No es "andar mas rapido": el tronco se echa adelante, la zancada se abre y el bote sube.
# Poner la animacion de andar a x1.7 se ve mal y ademas miente sobre lo que estas haciendo -- correr
# gasta aguante y hace ruido, asi que tiene que notarse.
static func _pose_correr(t: float) -> Dictionary:
	# El brazo se queda por debajo de la zancada: pasado de medio radian la mano sube por encima del
	# hombro y lo que se ve es alguien haciendo aspavientos, no corriendo. Las piernas si se abren.
	return {"paso": 0.62 * sin(TAU * t), "brazo": 0.48 * sin(TAU * t),
		"bote": 0.70 * absf(sin(TAU * t)), "inclina": 0.26,
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
	var avance_keys := [[0.0, 0.0], [0.30, -0.8], [0.45, -0.6], [0.62, 2.2], [0.80, 1.4], [1.0, 0.0]]
	var inclina_keys := [[0.0, 0.05], [0.30, -0.16], [0.45, -0.12], [0.62, 0.34], [0.80, 0.22], [1.0, 0.05]]
	return {"brazo_der": SpriteLienzo.tramos(t, brazo_keys),
		# El izquierdo apenas acompaña: es el que sujeta el escudo.
		"brazo_izq": -0.08 * SpriteLienzo.tramos(t, brazo_keys),
		"avance": SpriteLienzo.tramos(t, avance_keys),
		"inclina": SpriteLienzo.tramos(t, inclina_keys),
		"agacha": 0.10}


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
	return {"avance": -SpriteLienzo.tramos(t, retro_keys) * 2.2,
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
	var apoyo_keys := [[0.0, 0.0], [0.14, 0.0], [0.30, 1.0], [0.48, 2.6],
		[0.66, 3.6], [0.80, 4.1], [0.90, 3.9], [1.0, 4.0]]
	var agacha_keys := [[0.0, 0.10], [0.14, 0.55], [0.30, 0.30], [0.48, 0.05], [1.0, 0.0]]
	var rumbo_keys := [[0.0, 0.0], [0.14, 0.12], [0.30, 0.48], [0.48, 0.82], [0.66, 0.96], [1.0, 1.0]]
	# Y SE RECOLOCA MIENTRAS CAE, que no es un adorno sino lo que hace que quepa en el lienzo.
	#
	# El giro es sobre los PIES, asi que al acabar tumbado la cabeza queda a la altura entera del
	# cuerpo -- 33 unidades, o sea 29 celdas -- de un solo lado del origen, mientras que a cada lado
	# solo hay medio lienzo. El cadaver se salia por la izquierda y se le cortaba la cabeza en seco
	# (lo caza el validador de recortes del horno, que es de donde salio esto).
	#
	# Se podia arreglar agrandando el lienzo, pero el lienzo lo pagan las ~35 capas y su coste va con
	# el CUADRADO del lado. Desplazar el cuerpo media longitud segun se tumba cuesta un numero y
	# ademas se ve mejor: un cuerpo que se desploma no se queda con los pies clavados donde estaban.
	var avance_keys := [[0.0, 0.0], [0.30, 1.5], [0.48, 6.0], [0.66, 11.5], [1.0, 16.4]]
	# Los brazos se quedan flojos: dejan de acompañar en cuanto empieza la caida.
	var flojo: float = 1.0 - clampf(t * 2.0, 0.0, 1.0)
	return {"caida": SpriteLienzo.tramos(t, caida_keys) * PI * 0.5,
		"avance": SpriteLienzo.tramos(t, avance_keys),
		"apoyo": SpriteLienzo.tramos(t, apoyo_keys),
		"agacha": SpriteLienzo.tramos(t, agacha_keys),
		"rumbo": SpriteLienzo.tramos(t, rumbo_keys) * PI * 0.5,
		"brazo_der": -0.45 * (1.0 - flojo), "brazo_izq": -0.32 * (1.0 - flojo),
		"paso": 0.22 * flojo}
