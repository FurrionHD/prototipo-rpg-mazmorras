# ============================================================
#  segadora_sprites.gd  (class_name SegadoraSprites)
#  La SEGADORA (pisos 10-12) dibujada por codigo, con el motor comun (SpriteLienzo) y la camara de 45
#  grados que comparten todos los bichos. Solo geometria: quien decide que a esta ficha le toca este
#  generador es SpritesEnemigo (por NOMBRE, ver GENERADORES_POR_NOMBRE).
#
#  ES UNA MANTIS: cuerpo LARGO y estrecho -- cabeza triangular, protorax alargado, abdomen -- cuatro
#  patas de marcha finas, y delante las dos GUADAÑAS, que van PLEGADAS contra el pecho.
#
#  EL PLEGADO ES EL BICHO. Su ficha lo dice entera: "Espera con los dos brazos plegados contra el
#  pecho y no se mueve ni un dedo. Lo que la delata es que no parpadea: cuando por fin se mueve, ya te
#  ha cortado." O sea que su reposo es ACECHO -- quieta, compacta, sin enseñar de lo que es capaz -- y
#  todo su ataque es que eso se abre de golpe. Ningun otro bicho del juego guarda su arma.
#
#  HASTA HOY SE DIBUJABA CON EL GENERADOR DE LA ARAÑA, y ese es justo el riesgo: las dos son insectos
#  de patas largas del mismo bloque de pisos. Se separan por cuatro sitios, y hacen falta los cuatro:
#
#    ARAÑA                              SEGADORA
#    ocho patas iguales, en jaula       CUATRO patas de marcha + DOS guadañas delante
#    dos bolas (cefalotorax + abdomen)  un cuerpo LARGO: cabeza, protorax fino y abdomen
#    racimo de seis ojos                DOS ojos grandes en una cabeza triangular
#    se agazapa; muere hecha un ovillo  acecha ERGUIDA; muere de espaldas, patas arriba
#
#  Y hay una quinta diferencia que no esta en la lista porque no es una pieza: la araña TANTEA en su
#  idle y esta esta CLAVADA. Lo unico que se le mueve en reposo es la cabeza, que gira -- una mantis
#  es el unico insecto que puede girar la cabeza, y ese detalle vale por diez patas.
# ============================================================

extends RefCounted
class_name SegadoraSprites

const FRAMES := 8

# --- La segadora mirando al SUR, en unidades de MUNDO (origen = donde toca el suelo, +Y hacia la
# cabeza, +Z hacia arriba). Es lo que mide de la punta de la cabeza al final del abdomen. ---
const LARGO_MUNDO := 40.0

# LA ALTURA A LA QUE LEVANTA EL CUERPO. Una mantis al acecho esta ERGUIDA sobre sus cuatro patas, con
# el pecho alto; la araña va pegada al suelo. Esa diferencia de altura es media separacion entre las
# dos, y en pantalla se ve porque (y - z) sube el cuerpo por encima de sus patas.
const CUERPO_Z := 6.4

# EL CUERPO, de la cabeza a la cola. No es una cadena uniforme como el ciempies: son TRES tramos con
# personalidad, y el del medio -- el protorax -- es la seña del bicho.
# VA PLANA, NO ERGUIDA, y eso se decidio con una foto cenital delante. Se probo levantarle el tercio
# delantero (la pose de amenaza) creyendo que la camara casi cenital no dejaba leer la cabeza, y no
# era eso: el problema era la PROPORCION. Una mantis vista desde arriba se lee perfectamente tumbada
# siempre que el abdomen sea grande y CLARO, el protorax largo y FINO, y las guadañas esten junto a
# la cabeza. Con eso puesto, erguirla sobraba.
const CABEZA := Vector3(0.0, 18.0, 1.0)
# TRIANGULAR: ancha por arriba (donde van los ojos) y estrecha por abajo. Se hace con dos piezas, una
# ancha detras y otra estrecha delante, en vez de con una bola.
# ANCHA Y CORTA: en la foto la cabeza es una barra horizontal con un ojo gordo en cada punta, no una
# bola. Ese ancho es lo que la hace triangular con el morro delante.
const CABEZA_R := Vector3(3.05, 1.45, 1.65)
const MORRO := Vector3(0.0, 19.3, 0.7)
const MORRO_R := Vector3(1.35, 1.15, 1.15)

# EL PROTORAX: el "cuello" largo y estrecho entre la cabeza y el torax. ES LO QUE HACE A UNA MANTIS.
# Sin el, cabeza y torax se pegan y sale un saltamontes; con el, el bicho se lee alargado y con
# alcance. Va en cadena para poder inclinarlo al acechar.
# LARGO Y FINISIMO. En la foto es casi un TERCIO del bicho y mide la cuarta parte de ancho que el
# abdomen: es un palo. El primer intento lo puso corto y grueso y la segadora salia como un
# saltamontes -- cabeza y abdomen pegados, sin cuello.
const PROTORAX_SEGMENTOS := 7
const PROTORAX_Y0 := 16.4
const PROTORAX_PASO := 1.75
const PROTORAX_R0 := Vector3(1.10, 1.25, 1.10)   # pegado a la cabeza, finisimo
const PROTORAX_R1 := Vector3(1.80, 1.45, 1.65)   # ensanchando hacia el torax

# TORAX: donde se clavan las cuatro patas y las dos guadañas.
const TORAX := Vector3(0.0, 4.0, 0.0)
const TORAX_R := Vector3(2.60, 2.00, 1.90)

# ABDOMEN: cadena que se ensancha y se afila. Va algo caido hacia atras, como en el bicho de verdad.
# ES LA PIEZA MAS GRANDE DEL BICHO: en la foto ocupa casi la mitad del largo y es lo mas ancho con
# diferencia. Un oval largo y lleno, no una cola que se afila enseguida.
const ABDOMEN_SEGMENTOS := 7
const ABDOMEN_Y0 := 2.6
const ABDOMEN_PASO := 2.75
const ABDOMEN_R0 := Vector3(2.90, 2.40, 1.95)
const ABDOMEN_R_MAX := Vector3(4.30, 2.90, 2.30)
const ABDOMEN_R1 := Vector3(1.50, 1.90, 1.15)
const ABDOMEN_CAE := 0.16           # cuanto baja el abdomen por segmento

# LAS TEGMINAS: las alas plegadas sobre el abdomen, en tono mas claro. Es una placa fina y larga, y
# lo que hace es romper el abdomen liso -- sin ella, la cola es un churro del mismo tono. Como es
# MUY achatada en un eje, hereda la perspectiva del abdomen (ver la nota de 'poner').
# GRANDES Y CLARAS: en la foto las alas plegadas TAPAN el abdomen entero y son lo mas luminoso del
# bicho. Lo de dejarlas discretas fue un error de la vuelta anterior -- oscureciendolas, el abdomen se
# leia como una mancha de sombra debajo del bicho en vez de como su mitad trasera.
const TEGMINA_Y := -4.6
const TEGMINA_R := Vector3(3.55, 8.40, 0.85)
# LA MANCHA DEL ABDOMEN: el par de ocelos rosados que tiene la mantis de la foto sobre las alas. Es
# un detalle pequeño que hace mucho -- sin el, el abdomen es un oval liso del mismo tono.
#
# ATRAS Y DISCRETA. Puesta a -1,4 y en rosa vivo caia en lo ALTO del abdomen, que con la camara a 45
# grados es la parte de arriba del dibujo, y los dos ocelos se leian como DOS OJOS: la segadora
# parecia tener la cara en el culo. Es el mismo fallo que ya dio la tegmina clara -- todo lo que
# cante en el abdomen compite con la cabeza, y la cabeza tiene que ganar.
const MANCHA := Vector3(1.35, -7.2, 0.0)
const MANCHA_R := Vector3(1.05, 1.30, 0.50)

# OJOS: dos, GRANDES y en los picos de la cabeza triangular. Son lo que dice hacia donde mira, y en
# una mantis son enormes respecto a la cabeza. Nada de racimo: eso es de araña.
const OJO_DIR := Vector3(0.86, 0.42, 0.28)
const OJO_R := Vector3(1.60, 1.35, 1.50)
const OJO_HUNDE := 0.60
const OJO_VISIBLE := -0.18          # de espaldas no se le ven (mismo criterio que el trent)
# La PUPILA: el punto oscuro. Una mantis tiene una mancha falsa en el ojo que parece seguirte, y es
# justo lo que su ficha describe ("lo que la delata es que no parpadea").
const PUPILA_R := 0.68

# ANTENAS: dos hilos finos hacia delante. Cortas y sin barbas -- las plumosas son de polilla.
const ANTENA_SEGMENTOS := 4
const ANTENA_LARGO := 5.2
const ANTENA_ABRE := 0.30
const ANTENA_R0 := 0.72
const ANTENA_R1 := 0.52

# ============================================================
#  LAS GUADAÑAS
# ============================================================
# Cada una son dos tramos: el FEMUR (grueso, con espinas por dentro) y la TIBIA (la hoja, mas fina y
# curva), y la tibia se pliega hacia atras SOBRE el femur. Con 'abre' = 0 estan recogidas contra el
# pecho -- la pose de acecho -- y con 'abre' = 1 estiradas del todo hacia delante.
#
# LAS DIRECCIONES VAN INTERPOLADAS, no las puntas: es la tecnica del ala de la gargola. Interpolando
# los puntos finales, el brazo se ESTIRA y se ENCOGE (los eslabones se separan y la cadena se
# descose); interpolando las direcciones y avanzando siempre un paso unitario, el brazo mide lo mismo
# en toda la animacion y no hay forma de que se rompa.
# EL ANCLA VA DELANTE DEL TORAX, en la base del protorax: es de donde salen de verdad, y ademas es
# lo que las deja por delante del cuerpo en vez de sobre el.
# JUNTO A LA CABEZA, no en el torax. En la foto las dos guadañas nacen al final del protorax, a la
# altura del cuello, y quedan a los lados de la cabeza. Ancladas atras parecian dos brazos saliendo
# de la barriga.
const GUADANA_ANCLA := Vector3(1.70, 15.4, 1.9)
const FEMUR_SEGMENTOS := 6
const FEMUR_LARGO := 7.6
const FEMUR_R0 := 1.55
const FEMUR_R1 := 1.15
const TIBIA_SEGMENTOS := 7
const TIBIA_LARGO := 8.4
const TIBIA_R0 := 1.10
const TIBIA_R1 := 0.72
# PLEGADA el femur se echa ADELANTE (mucha Y) y sube poco, y la tibia vuelve hacia el cuerpo (Y
# negativa): las dos juntas forman la Z apretada contra el pecho, POR DELANTE del bicho.
#
# LA Y MANDA MAS QUE LA Z, y esto hubo que corregirlo mirando. Con (0.26, 0.62, 0.74) el femur tenia
# mas altura que avance, y con la camara a 45 grados la pantalla es (y·cos - z·sin): subir y avanzar
# tiran en sentidos CONTRARIOS, asi que el brazo se quedaba clavado en el sitio y la tibia -- que
# ademas vuelve hacia atras -- se iba disparada hacia arriba. Las dos guadañas acababan sobre el
# abdomen, o sea en la punta contraria del bicho.
const FEMUR_DIR_PLEGADO := Vector3(0.30, 0.88, 0.36)
const TIBIA_DIR_PLEGADO := Vector3(0.14, -0.70, 0.70)
# ABIERTA las dos se van hacia delante y hacia fuera, la tibia cayendo.
const FEMUR_DIR_ABIERTO := Vector3(0.60, 0.76, 0.25)
const TIBIA_DIR_ABIERTO := Vector3(0.30, 0.92, -0.25)
# LAS ESPINAS del femur: la fila de puas por la cara de dentro. Son LA SEÑA de una guadaña -- sin
# ellas es un brazo doblado cualquiera. Cortas y GORDAS: a menos de tres celdas el contorno se las
# come enteras (la leccion de las manos del miconido).
const ESPINAS := 4
const ESPINA_R := 0.62
const ESPINA_LARGO := 1.35

# LAS PATAS DE MARCHA: cuatro, finas y largas, dos pares. Nada de ocho: eso es la araña.
const PATA_PARES := 2
const PATA_ANCLA_X := 2.15
const PATA_ANCLA_Y := [3.2, 0.8]    # donde se clava cada par: las dos EN EL TORAX
const PATA_ABRE := [2.6, -3.6]      # cuanto abre cada par hacia delante/atras
const PATA_ALCANCE := [11.0, 12.0]
# LA RODILLA VA BAJA. En la foto cenital las cuatro patas salen del torax hacia FUERA y quedan casi
# planas: no forman la jaula arqueada por encima del lomo que hace la araña. Ese arco alto era lo que
# mas las acercaba, y era justo de lo que habia que separarlas.
const PATA_RODILLA_Z := 4.2
const PATA_RODILLA_F := 0.48
const FEMUR_P_SEGMENTOS := 6
const TIBIA_P_SEGMENTOS := 9
const PATA_R0 := 1.25
const PATA_R1 := 0.92
const PASO_LARGO := 3.4
const PASO_ALTO := 2.4

# ACECHAR: el balanceo lentisimo de lado a lado que hace una mantis quieta. Es lo unico que se mueve
# en su idle, junto con la cabeza.
const CABEZA_GIRO := 0.42           # radianes que gira la cabeza sola

# MORIRSE: SE VUELCA DE ESPALDAS con las patas encogidas hacia arriba, que es como muere un insecto y
# como NO muere ninguno de los otros tres del bloque (la araña se hace un ovillo, el escarabajo
# vuelca y el ciempies se enrosca).
const VUELCO_MAX := 1.15            # radianes de giro sobre el eje largo

const LUNGE_DIST := 9.5
# Encaja bastante: es rapida y agresiva pero no pesa (74 de vida, Resistencia 30).
const ENCAJE_RETRO := 0.44

# Lienzo CUADRADO y holgado: gira, y girada en diagonal el largo va por la diagonal del cuadro.
#
# EL CASO PEOR ES MIRANDO AL ESTE, y hay que hacer la cuenta en vez de tantear (se subio dos veces a
# ojo, a 1,62 y a 1,90, y el horno siguio cantando las dos). En el fotograma 5 de la embestida la
# punta de la guadaña llega a 37,5 unidades del origen: 15,4 del ancla, mas 5,8 de femur, mas 7,7 de
# tibia, mas 8,6 que ha viajado el bicho.
#
# Mirando al SUR eso va por la Y, que se comprime a cos(45) y se queda en 26,5. Pero mirando al ESTE
# va entero por la X, Y LA X NO SE COMPRIME NADA -- son las 37,5 completas. O sea que el lienzo lo
# manda una direccion en la que ni se piensa al dibujar el bicho de frente.
#
# 37,5 + el grosor de la pieza y algo de margen = 43 a cada lado, o sea 86 de lado contra los 40 de
# LARGO_MUNDO: factor 2,15. Ampliarlo es casi gratis (el horno recorta cada fotograma y guarda el
# hueco como margen), asi que se peca de largo antes que quedarse corto.
const LIENZO_FACTOR := 2.15

# TONOS propios (el motor no sabe que es cada uno; solo mapea indice -> color, ver _colores).
enum Tono { VACIO, SOMBRA_SUELO, BORDE, PATA, SOMBRA, BASE, LOMO, TEGMINA_T, MANCHA_T,
	GUADANA_T, HOJA, ESPINA_T, OJO_T, PUPILA_T }

# --- Vectores de las 8 direcciones (pantalla: +Y es hacia ABAJO). 0=S 1=SE 2=E 3=NE 4=N 5=NW 6=W 7=SW.
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


static func clave_de(ed: EnemyData, t: float) -> String:
	return _clave(SpriteLienzo.cuantizar_hsv(ed.color_visual(t), COLOR_PASOS),
		snappedf(ed.escala_visual, 0.05))


static func _clave(col: Color, esc: float) -> String:
	return "segadora_%s_%.2f" % [col.to_html(false), esc]


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(escala: float = 1.0) -> int:
	return _celdas(escala)


static func dimensiona_por_escala() -> bool:
	return true


# El CUERPO en planta (ancho, largo) para la colision. NI LAS PATAS NI LAS GUADAÑAS CUENTAN, igual
# que no cuentan las patas de la araña ni la copa del trent: son apendices finos que pasan por encima
# de las cosas, y con ellos el bicho mediria mas que el vano de un pasillo y se quedaria trabado.
static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	var largo: float = (MORRO.y + MORRO_R.y) \
		- (ABDOMEN_Y0 - float(ABDOMEN_SEGMENTOS - 1) * ABDOMEN_PASO - ABDOMEN_R1.y)
	return Vector2(ABDOMEN_R_MAX.x * 2.0, largo) * escala


static func _celdas(escala: float) -> int:
	var lado: int = int(ceil(LARGO_MUNDO * escala * LIENZO_FACTOR / SpriteLienzo.UNIDADES_POR_CELDA))
	return lado + (lado % 2)      # par, para que el centro caiga limpio


static func generar(color: Color = Color(0.50, 0.44, 0.28), escala: float = 1.0) -> SpriteFrames:
	# cuantizar_hsv y no cuantizar a secas: el ocre de la segadora es apagado y redondear canal a
	# canal le cambia el TONO -- dos canales parecidos caen en el mismo escalon y sale un gris.
	var col: Color = SpriteLienzo.cuantizar_hsv(color, COLOR_PASOS)
	var esc: float = snappedf(escala, 0.05)      # se cuantiza tambien, o el cache no acierta
	var clave: String = _clave(col, esc)
	if _cache.has(clave):
		return _cache[clave]
	var anims: Array = []
	_montar_idle(anims, esc)
	_montar_walk(anims, esc)
	_montar_embestida(anims, esc)
	_montar_guadanas(anims, esc)
	_montar_ensarte(anims, esc)
	_montar_encaje(anims, esc)
	_montar_muerte(anims, esc)
	_montar_cadaver(anims, esc)
	var lado: int = _celdas(esc)
	var sf: SpriteFrames = SpriteLienzo.montar_frames(
		anims, SpriteLienzo.paleta(_colores(col)), lado, lado)
	_cache[clave] = sf
	return sf


# La pose en reposo. Cada animacion escribe SOLO lo que cambia.
static func _pose(campos: Dictionary = {}) -> Dictionary:
	var p := {"avance": 0.0, "abre": 0.0, "abre_izq": -1.0, "fase": 0.0, "paso": 0.0,
		"cabeza": 0.0, "agacha": 0.0, "alza": 0.0, "vuelca": 0.0, "encoge": 0.0}
	for k in campos:
		p[k] = campos[k]
	return p


# ACECHANDO: CLAVADA. Es la animacion mas quieta del juego a proposito, porque su ficha es esa --
# "no se mueve ni un dedo". A 3 fps y lo unico que hace es GIRAR LA CABEZA, muy despacio, siguiendo
# algo que no ves. Una mantis es el unico insecto que puede girar la cabeza, y ese detalle solo dice
# mas del bicho que cualquier movimiento del cuerpo.
static func _montar_idle(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return _pose({"cabeza": sin(TAU * t), "abre": 0.0,
			"agacha": 0.03 * (1.0 - cos(TAU * t))})
	_montar_animacion(anims, esc, "idle", true, 3.0, pose, false)


# Andando: con las guadañas RECOGIDAS, que es como anda una mantis -- las lleva plegadas y no las usa
# para caminar. A 9 fps: es rapida (Agilidad 40, velocidad 4,8) pero no corre como la araña.
static func _montar_walk(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return _pose({"fase": t, "paso": 1.0, "abre": 0.10,
			"cabeza": 0.35 * sin(TAU * t * 0.5),
			"agacha": 0.05 * (1.0 - cos(TAU * t * 2.0))})
	_montar_animacion(anims, esc, "walk", true, 9.0, pose, false)


# EMBESTIDA: ABRE LAS GUADAÑAS Y SE ECHA ENCIMA. El gesto entero esta en el desplegado -- que es
# instantaneo, un solo fotograma del 0 al 1 -- porque eso es lo que dice su ficha: "cuando por fin se
# mueve, ya te ha cortado". Interpolado suave se leeria como que estira los brazos.
static func _montar_embestida(anims: Array, esc: float) -> void:
	# Se recoge todavia MAS antes de saltar (el -0,15 del avance y el 0,0 del abre): tomar impulso
	# desde la pose plegada es lo que hace que el desplegado se vea de golpe.
	var abre_keys := [[0.0, 0.0], [0.30, 0.0], [0.44, 1.0], [0.68, 0.95], [0.86, 0.45], [1.0, 0.15]]
	var avance_keys := [[0.0, 0.0], [0.30, -1.4], [0.44, 1.2], [0.68, 8.4], [0.86, 9.5], [1.0, 6.4]]
	var alza_keys := [[0.0, 0.0], [0.30, 0.55], [0.44, 0.85], [0.68, 0.15], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		return _pose({"avance": SpriteLienzo.tramos(t, avance_keys) * (LUNGE_DIST / 9.5),
			"abre": SpriteLienzo.tramos(t, abre_keys),
			"alza": SpriteLienzo.tramos(t, alza_keys)})
	_montar_animacion(anims, esc, "embestida", false, 12.0, pose, true)


# DOBLE GUADAÑA (fx_anim = "guadanas"). "Los dos brazos caen a la vez y desde arriba, uno por cada
# lado. No hay hueco entre los dos: donde no llega uno llega el otro."
#
# LAS DOS A LA VEZ Y DESDE ARRIBA: se alzan del todo -- el cuerpo se yergue con ellas -- y caen
# juntas. Lo que lo separa del Ensarte es justo eso: alli sale UNA recta y aqui bajan LAS DOS en
# arco. 'alza' sube el cuerpo entero y 'abre' despliega los brazos, y las dos cosas van a la vez.
#
# UNA SOLA DIRECCION: solo se ve en combate, y ahi se le mira de frente.
static func _montar_guadanas(anims: Array, esc: float) -> void:
	var alza_keys := [[0.0, 0.0], [0.143, 0.75], [0.286, 1.0], [0.429, 0.30], [0.571, -0.35],
		[0.714, -0.15], [1.0, 0.0]]
	var abre_keys := [[0.0, 0.15], [0.143, 0.55], [0.286, 0.80], [0.429, 1.0], [0.571, 1.0],
		[0.714, 0.60], [1.0, 0.25]]
	var pose := func(t: float) -> Dictionary:
		return _pose({"alza": SpriteLienzo.tramos(t, alza_keys),
			"abre": SpriteLienzo.tramos(t, abre_keys)})
	_montar_animacion(anims, esc, "guadanas", false, 13.0, pose, true, 1, FRAMES)


# ENSARTE (fx_anim = "ensarte"). "Se queda quieta, muy quieta, y de pronto ya esta dentro. Sale por
# el mismo sitio por el que entro."
#
# UNA SOLA GUADAÑA, y RECTA. Es el contrario de la Doble: alli bajan las dos en arco y aqui se
# dispara una al frente y vuelve. Por eso existe 'abre_izq': deja abrir un brazo sin el otro, y este
# es el unico sitio que lo usa.
#
# Y LA MITAD DE LA ANIMACION ES NO MOVERSE. Los tres primeros fotogramas estan CLAVADOS ("se queda
# quieta, muy quieta") y el cuarto ya esta dentro. Ese silencio es la habilidad.
static func _montar_ensarte(anims: Array, esc: float) -> void:
	var abre_keys := [[0.0, 0.0], [0.286, 0.0], [0.429, 1.0], [0.571, 1.0], [0.714, 0.20],
		[1.0, 0.05]]
	# El cuerpo se echa adelante con el brazo: el golpe sale del bicho entero, no del codo.
	var avance_keys := [[0.0, 0.0], [0.286, -0.6], [0.429, 3.2], [0.571, 3.6], [0.714, 1.0],
		[1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		return _pose({"abre": SpriteLienzo.tramos(t, abre_keys),
			# SOLO EL DERECHO: el izquierdo se queda plegado todo el rato.
			"abre_izq": 0.05,
			"avance": SpriteLienzo.tramos(t, avance_keys)})
	_montar_animacion(anims, esc, "ensarte", false, 13.0, pose, true, 1, FRAMES)


# ENCAJAR UN GOLPE. Cuatro fotogramas en UNA sola direccion y EMPEZANDO YA GOLPEADA.
#
# SE ENCOGE SOBRE LAS GUADAÑAS. No sale despedida como la araña ni aguanta como el miconido: lo que
# hace es CERRARSE -- recoge los brazos y se agazapa --, que es lo que hace una mantis cuando algo la
# toca. Y es ademas coherente con su reposo: su reflejo es plegarse.
static func _montar_encaje(anims: Array, esc: float) -> void:
	var retro_keys := [[0.0, 1.0], [0.34, 0.40], [0.67, 0.10], [1.0, 0.0]]
	var agacha_keys := [[0.0, 0.85], [0.34, 0.45], [0.67, 0.15], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		return _pose({"avance": -SpriteLienzo.tramos(t, retro_keys) * (LUNGE_DIST * ENCAJE_RETRO),
			"agacha": SpriteLienzo.tramos(t, agacha_keys),
			"abre": 0.0})
	# LOS BICHOS ENCAJAN A 18 fps: es la duracion que espera CombatFX.T_ENCAJE.
	_montar_animacion(anims, esc, "encaje", false, 18.0, pose, true, 1, 4)


# MORIRSE: SE VUELCA DE ESPALDAS. Ocho fotogramas en UNA sola direccion.
#
# Es la muerte de un insecto de verdad, y es la que le queda libre: la araña se hace un ovillo, el
# escarabajo vuelca patas arriba y el ciempies se enrosca en espiral. Esta se va de lado, cae de
# espaldas y encoge las cuatro patas y las dos guadañas sobre el vientre. Cuatro bichos del mismo
# bloque, cuatro muertes que no se confunden.
static func _pose_muerte(t: float) -> Dictionary:
	# UN ULTIMO ESPASMO: abre las guadañas de golpe en el 0,16 -- el ultimo intento de cortar algo --
	# y ahi se le acaba. Sin el, la muerte sale como una interpolacion suave y parece que se tumba.
	var abre_keys := [[0.0, 0.05], [0.16, 0.90], [0.34, 0.45], [0.56, 0.10], [1.0, 0.0]]
	var vuelca_keys := [[0.0, 0.0], [0.16, 0.10], [0.34, 0.45], [0.56, 0.85], [0.78, 1.02],
		[0.90, 0.97], [1.0, 1.0]]
	var encoge_keys := [[0.0, 0.0], [0.34, 0.25], [0.56, 0.70], [0.78, 0.95], [1.0, 1.0]]
	var agacha_keys := [[0.0, 0.0], [0.16, 0.20], [0.34, 0.60], [0.56, 0.90], [1.0, 1.0]]
	return _pose({"abre": SpriteLienzo.tramos(t, abre_keys),
		"vuelca": SpriteLienzo.tramos(t, vuelca_keys),
		"encoge": SpriteLienzo.tramos(t, encoge_keys),
		"agacha": SpriteLienzo.tramos(t, agacha_keys)})


static func _montar_muerte(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return _pose_muerte(t)
	_montar_animacion(anims, esc, "muerte", false, 10.0, pose, true, 1, 8)


# EL CADAVER DEL MAPA: UN fotograma por CADA UNA de las ocho direcciones, al reves que 'muerte'. Es
# EXACTAMENTE la pose final de la muerte, sacada de la MISMA funcion: reescribir los numeros aqui
# garantiza que el dia que se retoque el vuelco el cadaver se quede como estaba.
static func _montar_cadaver(anims: Array, esc: float) -> void:
	var pose := func(_t: float) -> Dictionary:
		return _pose_muerte(1.0)
	# ultimo_incluido = false y NO true: con un solo marco el divisor seria (1 - 1) = 0 y saldria NaN.
	_montar_animacion(anims, esc, "cadaver", false, 1.0, pose, false, 8, 1)


static func _montar_animacion(anims: Array, esc: float, nombre: String,
		loop: bool, fps: float,
		pose_fn: Callable, ultimo_incluido: bool, dirs: int = 8, marcos: int = FRAMES) -> void:
	var divisor: float = float(marcos - 1) if ultimo_incluido else float(marcos)
	for dir in dirs:
		var plantillas: Array = []
		for i in marcos:
			# La GEOMETRIA se cachea por (animacion, frame, direccion, escala) y NO por color.
			var clave: String = "%s_%d_%d_%.2f" % [nombre, i, dir, esc]
			var plant: PackedByteArray = _cache_plantillas.get(clave, PackedByteArray())
			if plant.is_empty():
				plant = _plantilla(dir, pose_fn.call(float(i) / divisor), esc)
				_cache_plantillas[clave] = plant
			plantillas.append(plant)
		anims.append({"nombre": "%s_%d" % [nombre, dir], "loop": loop, "fps": fps,
			"plantillas": plantillas})


# Los colores de cada Tono, EN EL ORDEN DEL ENUM (contrato con SpriteLienzo.paleta).
static func _colores(color: Color) -> Array:
	var c: Color = color
	return [
		Color(0, 0, 0, 0),                        # VACIO
		Color(0, 0, 0, 0.22),                     # SOMBRA_SUELO
		c.darkened(0.72),                         # BORDE
		# LAS PATAS, mas oscuras que el cuerpo: cuatro hilos del mismo tono que el bulto se pierden
		# sobre el suelo de la mazmorra. Es la misma decision que las patas de la araña.
		c.darkened(0.48),                         # PATA
		c.darkened(0.30),                         # SOMBRA (el costado, en penumbra)
		c,                                        # BASE
		# El lomo se aclara HACIA UN VERDE PAJIZO, no hacia el blanco: 'lightened' desatura y sobre un
		# ocre apagado deja un gris. Misma leccion que el jabali y la araña.
		c.lerp(Color(0.80, 0.82, 0.52), 0.42),    # LOMO
		# LAS TEGMINAS (las alas plegadas del abdomen): mas claras y algo verdosas, para que el
		# abdomen no sea un churro de un solo tono.
		# LAS TEGMINAS, CLARAS. Son lo mas luminoso del bicho junto con las guadañas, y tiene que ser
		# asi: en la foto las alas plegadas tapan el abdomen entero y es la mitad clara del animal.
		c.lerp(Color(0.78, 0.82, 0.54), 0.58),    # TEGMINA_T
		# LA MANCHA del abdomen: el par de ocelos rosados de la foto. Apagada a proposito (ver MANCHA):
		# es un detalle que rompe el oval liso, no un rasgo que deba competir con los ojos.
		c.lerp(Color(0.46, 0.24, 0.28), 0.62),    # MANCHA_T
		# LAS GUADAÑAS TIENEN TONO PROPIO Y MAS CLARO QUE EL CUERPO, al reves que las patas. Son el
		# arma del bicho y lo que hay que mirar: si fueran del tono de las patas se perderian contra
		# el cuerpo justo en el fotograma del ataque, que es cuando importan.
		c.lerp(Color(0.86, 0.84, 0.62), 0.30),    # GUADANA_T (el femur)
		c.lerp(Color(0.92, 0.90, 0.74), 0.52),    # HOJA (la tibia, la parte que corta: mas clara aun)
		Color(0.96, 0.94, 0.86),                  # ESPINA_T (las puas: hueso)
		# LOS OJOS, CLAROS Y GRANDES sobre una cabeza oscura, con la pupila casi negra. Son lo unico
		# que dice hacia donde mira, y lo que su ficha llama "no parpadea".
		Color(0.98, 0.95, 0.62),                  # OJO_T
		Color(0.10, 0.09, 0.07),                  # PUPILA_T
	]


# ------------------------------------------------------------
#  GEOMETRIA
# ------------------------------------------------------------

static func _en_la_pieza(dir: Vector3, hunde: float, centro: Vector3, radio: Vector3) -> Vector3:
	var d: Vector3 = dir.normalized()
	return centro + Vector3(radio.x * d.x, radio.y * d.y, radio.z * d.z) - d * hunde


# Un punto de la curva de un tramo de pata (bezier cuadratica: arranque, codo, final).
static func _curva(a: Vector3, codo: Vector3, b: Vector3, f: float) -> Vector3:
	var g: float = 1.0 - f
	return a * (g * g) + codo * (2.0 * g * f) + b * (f * f)


# Las PIEZAS de la segadora para una pose, ya proyectadas a pantalla.
static func _piezas(dir: int, pose: Dictionary, esc: float) -> Array:
	var ang: float = DIR_VECS[dir].angle() - DIR_VECS[0].angle()
	var u: float = esc / SpriteLienzo.UNIDADES_POR_CELDA
	var centro: float = float(_celdas(esc)) * 0.5
	var avance: float = float(pose["avance"])
	var abre_d: float = clampf(float(pose["abre"]), 0.0, 1.0)
	# 'abre_izq' negativo = el izquierdo hace lo mismo que el derecho. Solo el Ensarte lo separa.
	var abre_i: float = abre_d if float(pose["abre_izq"]) < 0.0 else float(pose["abre_izq"])
	var fase: float = float(pose["fase"])
	var paso: float = float(pose["paso"])
	var gira_cab: float = float(pose["cabeza"]) * CABEZA_GIRO
	var agacha: float = float(pose["agacha"])
	var alza: float = float(pose["alza"])
	var vuelca: float = clampf(float(pose["vuelca"]), 0.0, 1.2) * VUELCO_MAX
	var encoge: float = clampf(float(pose["encoge"]), 0.0, 1.0)

	var alto_f: float = 1.0 - 0.30 * agacha + 0.22 * alza
	var cv: float = cos(vuelca)
	var sv: float = sin(vuelca)

	var desp := Vector2(0.0, avance).rotated(ang)

	var detras: Array = []
	var cuerpo: Array = []
	var delante: Array = []

	# EL ARRAY DESTINO VA COMO PARAMETRO y no capturado: una lambda de GDScript captura por VALOR.
	#
	# 'persp_ov' SOBREESCRIBE la perspectiva de la pieza, y hace falta por una trampa del motor:
	# SpriteLienzo.elipse aplasta con UN solo numero y ese numero solo vale si la pieza es REDONDA EN
	# PLANTA. Una rodaja muy achatada en un eje (aqui la TEGMINA) da un valor absurdo y de perfil se
	# dibuja varias veces mas alta de lo que mide. Hereda entonces la del bulto que la sostiene.
	var poner := func(dest: Array, local: Vector3, r: Vector3, tono: int,
			solo_sobre: Array = [], en_suelo: bool = false, persp_ov: float = -1.0) -> void:
		var lz: float = (local.z + CUERPO_Z) * alto_f
		var p := Vector2(local.x, local.y)
		var rot: Vector2 = p.rotated(ang) + desp
		# EL VUELCO VA DESPUES DE ORIENTAR AL BICHO: gira en el plano ancho-alto de la PANTALLA, asi que
		# la segadora muerta cae siempre hacia el mismo lado se mirara como se mirara. Aplicandolo en
		# coordenadas del bicho, en dos de las ocho direcciones caeria HACIA la camara -- y ahi la
		# profundidad se comprime, asi que en vez de un bicho tumbado se veria un bulto apilado. Es la
		# misma leccion que la caida del trent.
		var sx: float = 0.0
		var sy: float = 0.0
		if en_suelo:
			sx = centro + rot.x * u
			sy = centro + rot.y * SpriteLienzo.COS_CAM * u
		else:
			var nx: float = rot.x * cv + lz * sv
			var nz: float = -rot.x * sv + lz * cv
			sx = centro + nx * u
			sy = centro + (rot.y * SpriteLienzo.COS_CAM - nz * SpriteLienzo.SIN_CAM) * u
		# EL RADIO TAMBIEN GIRA al volcar: el semieje a lo ANCHO pasa a ser el vertical y al reves.
		var mez: float = absf(sv)
		var rx: float = lerpf(r.x, r.z, mez)
		var rz: float = lerpf(r.z, r.x, mez)
		dest.append({"pos": Vector2(sx, sy), "radio": Vector2(rx * u, r.y * u),
			"gira_forma": true, "tono": tono, "ang": ang,
			"persp": 1.0 if en_suelo else (persp_ov if persp_ov > 0.0
				else SpriteLienzo.persp_de(r.y, rz)),
			"solo_sobre": solo_sobre})

	# 1. SOMBRA DE CONTACTO, a ras de suelo y lo primero (va debajo).
	poner.call(detras, Vector3(0.0, TORAX.y * 0.3, 0.0),
		Vector3(TORAX_R.x * 1.15, LARGO_MUNDO * 0.26, 0.0), Tono.SOMBRA_SUELO, [], true)

	# 2. LAS CUATRO PATAS DE MARCHA. Dos pares, cada pata en dos tramos con la rodilla POR ENCIMA del
	#    lomo -- es el arco que hace que se lean como patas de insecto y no como palos.
	for s in 2:
		var lado: float = -1.0 if s == 0 else 1.0
		for k in PATA_PARES:
			# Los dos pares en contrafase y los dos lados tambien: si no, rema con las cuatro a la vez.
			var desfase: float = 0.0 if (k + s) % 2 == 0 else 0.5
			var giro: float = TAU * (fase + desfase)
			var vaiven: float = sin(giro) * paso * PASO_LARGO
			var levanta: float = maxf(0.0, cos(giro)) * paso * PASO_ALTO
			var ancla := Vector3(lado * PATA_ANCLA_X, PATA_ANCLA_Y[k], 0.0)
			var alcance: float = PATA_ALCANCE[k]
			var punta := Vector3(lado * (PATA_ANCLA_X + alcance),
				PATA_ANCLA_Y[k] + PATA_ABRE[k] + vaiven, levanta - CUERPO_Z)
			var rodilla := Vector3(lado * (PATA_ANCLA_X + alcance * PATA_RODILLA_F),
				lerpf(ancla.y, punta.y, 0.45), PATA_RODILLA_Z - CUERPO_Z)
			# AL MORIR SE RECOGEN SOBRE EL VIENTRE, pero POR FUERA de la silueta del cuerpo: metidas
			# dentro, el cadaver sale como un bulto liso sin una sola pata a la vista. Escalonadas por
			# 'k' para que no se amontonen en una mancha (la leccion del ovillo de la araña).
			if encoge > 0.0:
				punta = punta.lerp(Vector3(lado * (3.0 + k * 0.9),
					PATA_ANCLA_Y[k] * 0.4 + PATA_ABRE[k] * 0.3, 5.0 + k * 1.2), encoge)
				rodilla = rodilla.lerp(Vector3(lado * (5.4 + k * 1.3),
					PATA_ANCLA_Y[k] * 0.6, 8.0 + k * 1.1), encoge)
			var prof: float = Vector2(rodilla.x, rodilla.y).rotated(ang).y
			var dest: Array = delante if (prof > 0.0 or encoge > 0.5) else detras
			var cod_f: Vector3 = ancla.lerp(rodilla, 0.5) + Vector3(lado * 1.1, 0.0, 1.6)
			var cod_t: Vector3 = rodilla.lerp(punta, 0.5) + Vector3(lado * 2.2, 0.0, 2.0)
			for j in FEMUR_P_SEGMENTOS:
				var f: float = float(j) / float(FEMUR_P_SEGMENTOS - 1)
				poner.call(dest, _curva(ancla, cod_f, rodilla, f),
					Vector3.ONE * lerpf(PATA_R0, PATA_R1, f), Tono.PATA)
			for j in TIBIA_P_SEGMENTOS:
				var f: float = float(j) / float(TIBIA_P_SEGMENTOS - 1)
				poner.call(dest, _curva(rodilla, cod_t, punta, f),
					Vector3.ONE * lerpf(PATA_R1, PATA_R1 * 0.8, f), Tono.PATA)

	# 3. EL ABDOMEN, de atras hacia delante (lo mas lejano primero).
	for i in range(ABDOMEN_SEGMENTOS - 1, -1, -1):
		var f: float = float(i) / float(ABDOMEN_SEGMENTOS - 1)
		var r: Vector3 = ABDOMEN_R0.lerp(ABDOMEN_R_MAX, minf(1.0, f * 3.0)) if f < 0.34 \
			else ABDOMEN_R_MAX.lerp(ABDOMEN_R1, (f - 0.34) / 0.66)
		var p := Vector3(0.0, ABDOMEN_Y0 - float(i) * ABDOMEN_PASO, -float(i) * ABDOMEN_CAE)
		poner.call(cuerpo, p, r, Tono.SOMBRA)
		poner.call(cuerpo, Vector3(p.x, p.y, p.z + r.z * 0.40), r * 0.80, Tono.BASE, [Tono.SOMBRA])

	# 4. LAS TEGMINAS: la placa de las alas plegadas sobre el abdomen. Hereda la perspectiva del
	#    abdomen (ver la nota de 'poner'): es una rodaja fina y su propia cuenta saldria disparada.
	poner.call(cuerpo, Vector3(0.0, TEGMINA_Y, ABDOMEN_R_MAX.z * 0.45), TEGMINA_R, Tono.TEGMINA_T,
		[Tono.BASE, Tono.SOMBRA], false, SpriteLienzo.persp_de(ABDOMEN_R_MAX.y, ABDOMEN_R_MAX.z))
	# Y LA MANCHA, el par de ocelos sobre las alas. Solo sobre la tegmina, para que no se derrame.
	for l3 in [-1.0, 1.0]:
		poner.call(cuerpo, Vector3(l3 * MANCHA.x, MANCHA.y, ABDOMEN_R_MAX.z * 0.52), MANCHA_R,
			Tono.MANCHA_T, [Tono.TEGMINA_T], false,
			SpriteLienzo.persp_de(ABDOMEN_R_MAX.y, ABDOMEN_R_MAX.z))

	# 5. EL TORAX.
	poner.call(cuerpo, TORAX, TORAX_R, Tono.SOMBRA)
	poner.call(cuerpo, Vector3(TORAX.x, TORAX.y, TORAX.z + TORAX_R.z * 0.42), TORAX_R * 0.80,
		Tono.BASE, [Tono.SOMBRA])

	# 6. EL PROTORAX: el cuello largo. Es la pieza que hace a la mantis.
	for i in PROTORAX_SEGMENTOS:
		var f: float = float(i) / float(PROTORAX_SEGMENTOS - 1)
		var r: Vector3 = PROTORAX_R0.lerp(PROTORAX_R1, f)
		var p := Vector3(0.0, PROTORAX_Y0 - float(i) * PROTORAX_PASO, 0.5 - f * 0.3)
		poner.call(cuerpo, p, r, Tono.SOMBRA)
		poner.call(cuerpo, Vector3(p.x, p.y, p.z + r.z * 0.42), r * 0.78, Tono.LOMO, [Tono.SOMBRA])

	# 7. LA CABEZA, que GIRA sola sobre el cuello (lo unico que se mueve en su idle).
	var gc: float = gira_cab
	var cab := Vector3(sin(gc) * 1.6, CABEZA.y, CABEZA.z)
	poner.call(cuerpo, cab, CABEZA_R, Tono.SOMBRA)
	poner.call(cuerpo, Vector3(cab.x, cab.y, cab.z + CABEZA_R.z * 0.40), CABEZA_R * 0.78,
		Tono.LOMO, [Tono.SOMBRA])
	# EL MORRO, delante: es lo que la hace TRIANGULAR en vez de redonda.
	poner.call(cuerpo, Vector3(cab.x + sin(gc) * 0.9, MORRO.y, MORRO.z), MORRO_R, Tono.SOMBRA)

	# 8. LOS OJOS, en los picos de la cabeza. De espaldas no se le ven -- un bicho que se aleja enseña
	#    la nuca, y eso es lo que hace que se lea de un vistazo si viene o si huye.
	var frente: float = DIR_VECS[dir].y
	if frente > OJO_VISIBLE and encoge < 0.5:
		for l in [-1.0, 1.0]:
			var d := Vector3(l * OJO_DIR.x, OJO_DIR.y, OJO_DIR.z)
			# De perfil puro solo se ve uno: los dos caen en la misma X de pantalla y se leen como un
			# borron. Mismo criterio que los ojos del trent.
			if absf(DIR_VECS[dir].x) >= 0.9 and Vector2(d.x, d.y).rotated(ang).y <= 0.0:
				continue
			var oj: Vector3 = _en_la_pieza(d, OJO_HUNDE, cab, CABEZA_R)
			oj.x += sin(gc) * 1.6
			poner.call(delante, oj, OJO_R, Tono.OJO_T)
			# LA PUPILA, adelantada un pelin: es la mancha falsa que "no parpadea".
			poner.call(delante, Vector3(oj.x, oj.y + 0.45, oj.z), Vector3.ONE * PUPILA_R,
				Tono.PUPILA_T, [Tono.OJO_T])
		# 9. LAS ANTENAS, dos hilos finos hacia delante.
		for l2 in [-1.0, 1.0]:
			for j in ANTENA_SEGMENTOS:
				var fa: float = float(j) / float(ANTENA_SEGMENTOS - 1)
				poner.call(delante, Vector3(cab.x + l2 * ANTENA_ABRE * ANTENA_LARGO * fa,
					MORRO.y + ANTENA_LARGO * fa * 0.9, MORRO.z + 1.0 * fa - 0.8 * fa * fa),
					Vector3.ONE * lerpf(ANTENA_R0, ANTENA_R1, fa), Tono.PATA)

	# 10. LAS GUADAÑAS, lo ultimo: van DELANTE de todo, porque las lleva sobre el pecho y porque son
	#     lo que hay que mirar.
	for s2 in 2:
		var lado2: float = -1.0 if s2 == 0 else 1.0
		_guadana(poner, delante, lado2, abre_i if s2 == 0 else abre_d, encoge)

	return detras + cuerpo + delante


# UNA GUADAÑA: femur (grueso, con espinas por dentro) + tibia (la hoja). La tibia se pliega hacia
# atras sobre el femur, y con 'abre' = 0 las dos forman la Z apretada contra el pecho.
#
# SE INTERPOLAN LAS DIRECCIONES, NO LAS PUNTAS (la tecnica del ala de la gargola): asi cada eslabon
# avanza SIEMPRE un paso unitario y el brazo mide lo mismo en toda la animacion. Interpolando los
# extremos, el brazo se estiraria y la cadena se descoseria justo en el fotograma del ataque, que es
# cuando se mira -- la vieja regla del paso menor que el grosor.
static func _guadana(poner: Callable, dest: Array, lado: float, abre: float, encoge: float) -> void:
	var ancla := Vector3(lado * GUADANA_ANCLA.x, GUADANA_ANCLA.y, GUADANA_ANCLA.z)
	# AL MORIR SE RECOGEN sobre el pecho, como las patas.
	var a: float = abre * (1.0 - encoge)

	var d_fem: Vector3 = Vector3(lado * FEMUR_DIR_PLEGADO.x, FEMUR_DIR_PLEGADO.y,
		FEMUR_DIR_PLEGADO.z).lerp(
		Vector3(lado * FEMUR_DIR_ABIERTO.x, FEMUR_DIR_ABIERTO.y, FEMUR_DIR_ABIERTO.z), a).normalized()
	var d_tib: Vector3 = Vector3(lado * TIBIA_DIR_PLEGADO.x, TIBIA_DIR_PLEGADO.y,
		TIBIA_DIR_PLEGADO.z).lerp(
		Vector3(lado * TIBIA_DIR_ABIERTO.x, TIBIA_DIR_ABIERTO.y, TIBIA_DIR_ABIERTO.z), a).normalized()

	var paso_f: float = FEMUR_LARGO / float(FEMUR_SEGMENTOS - 1)
	var codo: Vector3 = ancla + d_fem * FEMUR_LARGO
	for j in FEMUR_SEGMENTOS:
		var f: float = float(j) / float(FEMUR_SEGMENTOS - 1)
		poner.call(dest, ancla + d_fem * (paso_f * float(j)),
			Vector3.ONE * lerpf(FEMUR_R0, FEMUR_R1, f), Tono.GUADANA_T)
	# LAS ESPINAS, por la cara de DENTRO del femur (por eso van hacia -lado). Son la seña del arma.
	for j in ESPINAS:
		var f2: float = 0.25 + 0.68 * float(j) / float(ESPINAS - 1)
		var base: Vector3 = ancla + d_fem * (FEMUR_LARGO * f2)
		poner.call(dest, base + Vector3(-lado * ESPINA_LARGO * 0.55, 0.0, -ESPINA_LARGO * 0.55),
			Vector3.ONE * ESPINA_R, Tono.ESPINA_T)

	var paso_t: float = TIBIA_LARGO / float(TIBIA_SEGMENTOS - 1)
	for j in TIBIA_SEGMENTOS:
		var f3: float = float(j) / float(TIBIA_SEGMENTOS - 1)
		poner.call(dest, codo + d_tib * (paso_t * float(j)),
			Vector3.ONE * lerpf(TIBIA_R0, TIBIA_R1, f3), Tono.HOJA)


# La plantilla de un frame: que tono le toca a cada celda.
static func _plantilla(dir: int, pose: Dictionary, esc: float) -> PackedByteArray:
	var lado: int = _celdas(esc)
	var plant := PackedByteArray()
	plant.resize(lado * lado)
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
