# ============================================================
#  gargola_sprites.gd  (class_name GargolaSprites)
#  La GARGOLA DE BASALTO (piso 10+) dibujada por codigo. Solo geometria: el motor esta en
#  SpriteLienzo y quien reparte los generadores es SpritesEnemigo (por NOMBRE, no por familia: los
#  tres constructos y la Bestia acorazada son los cuatro familia PIEDRA).
#
#  ES LA UNICA DE LAS TRES QUE NO ES UNA MOLE. El golem es un pegote ancho y el coloso una torre;
#  esta es BIPEDA, AGAZAPADA y con ALAS -- lo unico del bloque que se lee como un animal. Tiene
#  Destreza 30 y Agilidad 20 (el doble que sus dos hermanos) y se le tiene que notar en la postura:
#  encogida sobre las patas, echada hacia delante, lista para saltar.
#
#  LAS ALAS SE SALEN DEL PASILLO, Y ES A PROPOSITO. 'tam_cuerpo' devuelve solo el CUERPO -- las alas
#  no entran, igual que no entran las patas de la araña ni la pala del escarabajo --, asi que en un
#  pasillo de 96 px las puntas asoman por las esquinas de la roca. Es la ventaja visual del volador:
#  ocupa mucho mas de lo que estorba.
#
#  SUS DOS HABILIDADES ESTAN DIBUJADAS:
#  - "Picado": extiende las alas, se eleva un instante y se deja caer. Es la embestida, y el momento
#    de arriba -- con las alas ABIERTAS del todo y la sombra quedandose en el suelo -- es la ventana
#    que su descripcion promete. Es ADEMAS el unico momento en que se le ven las alas enteras.
#  - "Mirada petrea": ojos VACIOS y claros, hundidos bajo el ceño.
#
#  MUERE COMO UNA ESTATUA: no se derrumba (eso es el golem) ni se enrosca. Se le cierran las alas de
#  golpe, se queda TIESA y se va de lado de una pieza, sin doblarse por ningun sitio y sin asentarse
#  al llegar al suelo. Una gargola muerta es una gargola caida.
# ============================================================

extends RefCounted
class_name GargolaSprites

const FRAMES := 8

# --- La gargola mirando al SUR, en unidades de MUNDO (origen = donde toca el suelo, +Y hacia donde
# mira, +Z hacia arriba). A escala 1.0 mide unas 18 unidades de ancho de cuerpo. ---
const ANCHO_MUNDO := 18.0

# --- PATAS: DIGITIGRADAS Y DOBLADAS, como las de un ave rapaz posada. Es lo que dice "agazapada" y
# lo que la separa de los pilones del golem. Cadena de tres puntos (cadera, corvejon, pie) por
# bezier, igual que las patas de la araña y el escarabajo.
const CADERA := Vector3(3.5, -1.4, 11.6)
const CORVEJON := Vector3(4.4, -3.8, 5.6)     # la rodilla invertida, HACIA ATRAS: es lo digitigrado
const PIE := Vector3(3.6, 1.6, 1.5)
const MUSLO_SEGMENTOS := 4
const CANA_SEGMENTOS := 4
const MUSLO_R0 := 2.5
const MUSLO_R1 := 1.7
const CANA_R0 := 1.6
const CANA_R1 := 1.35          # >= 1,15 celdas tras escalar: por debajo el contorno se come la pieza
# GARRAS: tres dedos por pie, abiertos hacia delante. Son lo que la posa en la piedra.
const GARRAS := 3
const GARRA_LARGO := 2.6
const GARRA_R := 1.15
const PASO_LARGO := 2.2
const PASO_ALZA := 1.6         # levanta mas el pie que el golem: no arrastra, PISA

# TORSO: compacto y ECHADO HACIA DELANTE (su centro cae adelantado respecto a las caderas). Casi
# redondo en planta para poder no girar, como el tronco del trent y el pegote del golem.
const TORSO := Vector3(0.0, 1.2, 16.2)
const TORSO_R := Vector3(5.8, 5.5, 6.0)
const TORSO_ANCLA_R := Vector3(5.5, 5.5, 6.0)

# HOMBROS: pequeños, y con la Y ADELANTADA. Esa Y no es dibujo: es lo que hace que la prueba de
# profundidad (`.y > 0` ya girada) diga que DE FRENTE los dos brazos van delante. Con la Y en cero
# exacto la prueba da falso para los dos y el bicho se dibuja de frente con los dos brazos "detras".
const HOMBRO_X := 4.5
const HOMBRO_Z := 19.4
const HOMBRO_R := Vector3(2.9, 2.8, 2.6)
const HOMBRO_Y := 0.8

# BRAZOS: CORTOS, doblados y pegados al pecho. Una gargola no golpea con las manos, se deja caer
# encima: los brazos son de rapaz, para agarrarse, no manazas de golem.
const BRAZO_SEGMENTOS := 4
const BRAZO_PASO := 2.3
const BRAZO_R0 := 1.9
const BRAZO_R1 := 1.35
const BRAZO_ANG_REPOSO := 0.55     # 0 = a plomo, PI/2 = hacia delante
const BRAZO_ANG_ALTO := 2.30       # recogidos hacia el pecho en el picado
const BRAZO_CODO := 1.15
const BRAZO_ADELANTA := 0.85
const BRAZO_ABRE := 0.16
const ZARPA_R := Vector3(1.7, 1.6, 1.6)

# CUELLO Y CABEZA. Va ADELANTADA -- es un bicho agazapado, no una persona -- pero SOBRE TODO va
# ALTA, y eso costo un rediseño entero.
#
# ADELANTAR NO SEPARA: LO QUE SEPARA ES (y - z). Con la camara a 45 grados la altura en pantalla es
# proporcional a (y - z), y adelantar la cabeza sube su Y, o sea la BAJA en pantalla justo lo que la
# habia subido el estar mas alta. Al primer intento la cabeza tenia y-z = -14,2 y el torso -13,8:
# medio unidad de diferencia, o sea que la cabeza se dibujaba DENTRO del torso y los ojos aparecian
# en mitad del pecho. La cuenta que hay que hacer es esta, y el margen tiene que superar el RADIO de
# la cabeza en pantalla: ahora son 7 unidades de diferencia = 10 celdas contra 6,7 de radio.
const CUELLO := Vector3(0.0, 2.8, 21.6)
const CUELLO_R := Vector3(2.3, 2.3, 2.4)
const CABEZA := Vector3(0.0, 4.2, 26.5)
const CABEZA_R := Vector3(2.9, 3.1, 2.7)
const CABEZA_ANCLA_R := Vector3(2.9, 2.9, 2.7)
# HOCICO: chato y ancho, no un pico. Sobresale por delante y es lo que hace que la cabeza tenga cara
# y no sea una bola.
const HOCICO := Vector3(0.0, 7.4, 25.4)
const HOCICO_R := Vector3(2.0, 2.3, 1.5)
# CEJA: la visera de piedra sobre los ojos. Es lo que le da el gesto -- sin ella los ojos claros
# flotan en una bola gris y no hay mirada que valga.
const CEJA := Vector3(0.0, 6.0, 28.2)
const CEJA_R := Vector3(2.9, 1.5, 1.1)
# CUERNOS: dos, hacia ATRAS Y ARRIBA desde lo alto de la cabeza. Rompen la silueta redonda.
const CUERNO_SEGMENTOS := 3
const CUERNO_PASO := 1.35
const CUERNO_R0 := 1.75
const CUERNO_R1 := 1.25
const CUERNO_X := 2.6
const CUERNO_Z := 2.2

# OJOS: VACIOS, que es lo que pide la "Mirada petrea". Van claros y hundidos bajo la ceja.
# BIEN SEPARADOS: dos puntos claros pegados se leen como UNA mancha, no como una cara (leccion de la
# araña y del golem).
const OJO_DIR := Vector3(0.62, 0.76, 0.20)
const OJO_R := Vector3(0.85, 0.85, 0.82)
const OJO_HUNDE := 1.0
# Hasta donde puede irse un ojo hacia atras y seguir viendose (Y ya girada): de frente y de medio
# lado los dos, de perfil uno, de espaldas ninguno.
const OJO_VISIBLE := -0.15

# COLA: cadena que sale de la grupa, baja y se levanta al final, rematada en una PALA de piedra.
# El paso menor que el grosor, o la cadena sale a trozos sueltos.
const COLA_RAIZ := Vector3(0.0, -4.2, 13.0)
const COLA_SEGMENTOS := 5
const COLA_PASO := 2.3
const COLA_R0 := 1.9
const COLA_R1 := 1.20
# LA COLA VA HACIA ATRAS Y HACIA ABAJO, y eso NO es una decision de gusto.
#
# Con la camara a 45 grados, lo que se aleja SUBE en pantalla al mismo ritmo que lo que se eleva
# (las dos cosas entran en (y - z) con el mismo peso). Una cola horizontal detras del bicho sube
# 0,707 unidades de pantalla por cada unidad de largo, asi que la primera version -- que ademas se
# LEVANTABA hacia la punta -- salia como una ANTENA VERTICAL por encima de la cabeza mirando al sur.
#
# Bajandola a la vez que se va hacia atras, las dos contribuciones se CANCELAN y la cola se queda a
# su altura de pantalla: detras del cuerpo, tapada de frente y visible de perfil, que es justo lo
# que tiene que hacer. 'COLA_ANG' es el angulo del primer tramo (negativo = hacia abajo) y
# COLA_CURVA cuanto se endereza hacia la punta.
const COLA_ANG := -0.85
const COLA_CURVA := 0.75
const PALA_R := Vector3(1.3, 2.4, 1.9)

# ============================================================
#  LAS ALAS
# ============================================================
# Un ala es una MEMBRANA: ancha en dos ejes y FINISIMA en el tercero. Se dibuja como una rejilla de
# piezas -- 'span' a lo largo del hueso y 'cuerda' de delante a atras -- y cada pieza es un plato
# aplastado en la direccion normal al ala. Es la unica forma de que una superficie plana se lea como
# plana en un motor que solo sabe pintar elipsoides.
#
# Y EL EJE FINO CAMBIA AL ABRIRSE, que es todo el truco de la animacion: PLEGADA el ala es un plano
# vertical pegado al lomo (fina a lo ANCHO), ABIERTA es un plano casi horizontal (fina en ALTURA).
# Interpolando a la vez la direccion del hueso y cual de los radios es el fino, el ala se despliega
# sola sin una sola pieza que se despegue.
# LA RAIZ VA EN LA ESPALDA, Y ESO SE MIDE EN (y - z), NO EN ALTURA. Puesta en (3,9 / -1,4 / 19,8)
# el ala tenia y-z = -21,2 y la cabeza -22,3: UNA unidad de diferencia, o sea que las dos alas
# brotaban justo al lado de la cara y la gargola salia como una POLILLA -- cabezota redonda entre
# dos alas y cuerpo diminuto debajo. Estar mas baja no basta si ademas esta mas atras: atras sube en
# pantalla igual que arriba.
const ALA_RAIZ := Vector3(3.6, 0.2, 17.2)
const ALA_SPAN := 6                # piezas a lo largo del hueso
const ALA_CUERDA := 4              # piezas de delante a atras
const ALA_LARGO := 13.0            # envergadura de UN ala, abierta
const ALA_LARGO_PLEGADA := 0.52    # plegada mide poco mas de la mitad: esta doblada sobre si misma
const ALA_CUERDA_MAX := 7.0        # lo ancha que es la membrana en su punto mas ancho
const ALA_GRUESO := 0.95           # el eje fino: una membrana de piedra, pero piedra
# CUANTO SE BARRE LA MEMBRANA HACIA FUERA a mitad del despliegue, para que el ala no se quede en el
# eje ciego de la camara (ver la explicacion larga en _ala). Vale cero plegada y abierta del todo.
const ALA_BARRE := 0.80
# El HUESO del borde de ataque, un pelin mas gordo y en tono oscuro. Sin el, el ala es una mancha.
const ALA_HUESO_R := 1.30
# LOS DEDOS: los radios que van de la muñeca del ala al borde de salida. Son LA SEÑA de un ala de
# murcielago, y sin ellos la membrana es una paleta lisa -- que es exactamente el ala de una
# POLILLA. Con ellos, la misma silueta se lee al instante como otra cosa.
#
# Salen de la MUÑECA (el 40% del hueso) y no de la raiz: es de donde salen de verdad, y ademas asi
# no cruzan la parte del ala pegada al lomo.
const ALA_DEDOS := 3
const ALA_MUNECA := 0.40
const DEDO_SEGMENTOS := 5
const DEDO_R := 0.60
# GARFIO: el dedo que remata el ala. Es la seña de un ala de murcielago.
const GARFIO_R := 1.15

const DETRAS_ESC := 0.88
const LUNGE_DIST := 11.0
# Encaja MUCHO mas que el golem: es de piedra pero es ligera, y el retroceso es lo que dice que no
# es una mole.
const ENCAJE_RETRO := 0.42

# --- EL LIENZO, en multiplos del ancho del cuerpo. RECTANGULAR y con el origen BAJO: el origen es
# el punto que toca el suelo y el bicho crece hacia arriba.
# ANCHO tiene que dar para las dos alas abiertas, PERO EL QUE MANDA ES EL CADAVER: al caer de lado
# lo que era altura pasa a ser ancho, y ademas todo el bicho se va hacia el lado al que se desploma.
# Medido sobre el horneado, el cadaver pedia 53 celdas a un lado contra las 49 que habia y 42 por
# debajo del suelo contra 38. ARRIBA da para el picado (se eleva Y abre las alas hacia arriba).
# Ampliar un lienzo es casi gratis: el horno recorta cada fotograma a su dibujo y guarda el hueco
# como margen.
const LIENZO_ANCHO := 3.05
const LIENZO_ARRIBA := 1.75
const LIENZO_ABAJO := 1.30

# TONOS propios (el motor no sabe que es cada uno; solo mapea indice -> color, ver _colores).
enum Tono { VACIO, SOMBRA_SUELO, BORDE, GARRA_T, PATA_OSC, PATA_T, BRAZO_OSC, BRAZO_T,
	MEMBRANA_OSC, MEMBRANA, HUESO_OSC, HUESO, PIEDRA_OSC, PIEDRA, PIEDRA_CLARA, OJO_T, APAGADO }

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
	return "gargola_%s_%.2f" % [col.to_html(false), esc]


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(escala: float = 1.0) -> int:
	return _lienzo(escala).x


static func dimensiona_por_escala() -> bool:
	return true


# El CUERPO en planta (ancho, largo). LAS ALAS NO CUENTAN, y es la decision de diseño de este bicho:
# abiertas miden 36 unidades de punta a punta -- el 90% del vano de 96 px de un pasillo -- y con
# ellas dentro la gargola se quedaria trabada en cualquier esquina. Fuera, las puntas asoman por
# encima de la roca y ocupa MUCHO mas de lo que estorba, que es justo lo que tiene que parecer un
# volador. Precedente exacto: las patas de la araña y la pala del escarabajo.
#
# Sale casi cuadrado (11,6 de lado a su escala = 28 px, el 29% del vano), o sea por debajo del 1.3
# de proporcion con el que enemy.gd gira la colision.
static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	var ancho: float = maxf(TORSO_R.x, CADERA.x + MUSLO_R0) * 2.0
	var largo: float = (CABEZA.y + CABEZA_R.y) - (TORSO.y - TORSO_R.y)
	return Vector2(ancho, largo) * escala


static func _lienzo(escala: float) -> Vector2i:
	var u: float = ANCHO_MUNDO * escala / SpriteLienzo.UNIDADES_POR_CELDA
	var w: int = int(ceil(u * LIENZO_ANCHO))
	var h: int = int(ceil(u * (LIENZO_ARRIBA + LIENZO_ABAJO)))
	return Vector2i(w + (w % 2), h + (h % 2))


static func _origen(escala: float) -> Vector2:
	var l: Vector2i = _lienzo(escala)
	return Vector2(float(l.x) * 0.5, float(l.y) * LIENZO_ARRIBA / (LIENZO_ARRIBA + LIENZO_ABAJO))


static func generar(color: Color = Color(0.4, 0.42, 0.45), escala: float = 1.0) -> SpriteFrames:
	# cuantizar_hsv y no cuantizar a secas: el gris azulado del basalto es un color apagado, y a esos
	# el redondeo canal a canal les cambia el TONO (al Rey rata lo dejo verde oliva).
	var col: Color = SpriteLienzo.cuantizar_hsv(color, COLOR_PASOS)
	var esc: float = snappedf(escala, 0.05)
	var clave: String = _clave(col, esc)
	if _cache.has(clave):
		return _cache[clave]
	var anims: Array = []
	_montar_idle(anims, esc)
	_montar_walk(anims, esc)
	_montar_embestida(anims, esc)
	_montar_mirada(anims, esc)
	_montar_encaje(anims, esc)
	_montar_muerte(anims, esc)
	_montar_cadaver(anims, esc)
	var lz: Vector2i = _lienzo(esc)
	var sf: SpriteFrames = SpriteLienzo.montar_frames(
		anims, SpriteLienzo.paleta(_colores(col)), lz.x, lz.y)
	_cache[clave] = sf
	return sf


# La pose de siempre, con todo a cero. Cada animacion escribe solo lo suyo, y añadir una clave nueva
# no obliga a tocarlas todas.
static func _reposo() -> Dictionary:
	return {"avance": 0.0, "vuela": 0.0, "mece": 0.0, "balanceo": 0.0, "brazos": 0.0,
		"alza": 0.0, "patas": 0.0, "agacha": 0.0, "abre": 0.0, "cabeza": 0.0,
		"cola": 0.0, "tumba": 0.0, "apoyo": 0.0}


# Quieta: posada. Respira, la cola se mueve despacio y las alas plegadas se ajustan un pelin. Es lo
# unico que la delata: parada del todo seria una estatua, que es lo que quiere hacerte creer.
static func _montar_idle(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["agacha"] = 0.06 * (1.0 - cos(TAU * t))
		p["cola"] = 0.45 * sin(TAU * t)
		p["abre"] = 0.05 + 0.05 * sin(TAU * t + 1.1)
		p["cabeza"] = 0.10 * sin(TAU * t)
		return p
	_montar_animacion(anims, esc, "idle", true, 4.0, pose, false)


# Andando: A SALTITOS, no arrastrando. Tiene Agilidad 20 y patas de rapaz: se impulsa, se eleva un
# poco y cae. El cuerpo BOTA (dos veces por ciclo, una por pata) y las alas se abren a medias en
# cada bote para equilibrarse -- que es lo que hace un ave que no acaba de volar.
static func _montar_walk(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["patas"] = sin(TAU * t)
		p["brazos"] = -0.5 * sin(TAU * t)
		p["balanceo"] = 0.6 * sin(TAU * t)
		p["vuela"] = 0.7 * maxf(0.0, sin(TAU * t * 2.0))
		p["agacha"] = 0.22 * maxf(0.0, -sin(TAU * t * 2.0))
		p["abre"] = 0.10 + 0.22 * maxf(0.0, sin(TAU * t * 2.0))
		p["cola"] = 0.7 * sin(TAU * t)
		return p
	_montar_animacion(anims, esc, "walk", true, 8.0, pose, false)


# LA EMBESTIDA ES SU "PICADO": abre las alas del todo, se ELEVA un instante y se deja caer encima.
#
# EL MOMENTO DE ARRIBA ES LA VENTANA DEL JUGADOR y su propia descripcion lo promete ("el momento que
# pasa arriba es tu unica ventana para pararla"), asi que tiene que VERSE: las alas llegan abiertas
# del todo en 0,30 y la gargola se queda suspendida hasta 0,52 antes de bajar.
#
# Y LO QUE DICE QUE ESTA EN EL AIRE ES LA SOMBRA, que se queda en el suelo mientras el cuerpo sube
# (ver 'vuela' en _piezas). Sin esa separacion, subir el dibujo unas celdas no se lee como volar,
# se lee como que el bicho ha crecido.
static func _montar_embestida(anims: Array, esc: float) -> void:
	var abre_keys := [[0.0, 0.10], [0.18, 0.80], [0.30, 1.0], [0.52, 1.0], [0.68, 0.55],
		[0.84, 0.30], [1.0, 0.12]]
	var vuela_keys := [[0.0, 0.0], [0.18, 1.5], [0.30, 2.4], [0.52, 2.6], [0.68, 0.2],
		[0.84, 0.0], [1.0, 0.0]]
	var avance_keys := [[0.0, 0.0], [0.18, -1.2], [0.30, -1.6], [0.52, 0.4], [0.68, 9.6],
		[0.84, 11.0], [1.0, 9.4]]
	# Se encoge en el aire y descarga el peso al llegar: el picado se acaba de golpe.
	var agacha_keys := [[0.0, 0.0], [0.18, -0.30], [0.52, -0.35], [0.68, 1.0], [0.84, 0.55],
		[1.0, 0.15]]
	var mece_keys := [[0.0, 0.0], [0.30, -0.9], [0.52, -0.7], [0.68, 1.6], [0.84, 1.0], [1.0, 0.3]]
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["abre"] = SpriteLienzo.tramos(t, abre_keys)
		p["vuela"] = SpriteLienzo.tramos(t, vuela_keys)
		p["avance"] = SpriteLienzo.tramos(t, avance_keys) * (LUNGE_DIST / 11.0)
		p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
		p["mece"] = SpriteLienzo.tramos(t, mece_keys)
		p["alza"] = 0.55 * SpriteLienzo.tramos(t, abre_keys)     # recoge las zarpas al picar
		p["cola"] = -0.8 * SpriteLienzo.tramos(t, vuela_keys) / 2.6
		return p
	_montar_animacion(anims, esc, "embestida", false, 12.0, pose, true)


# LA MIRADA PETREA: se yergue, despliega las alas y SE QUEDA CLAVADA mirandote.
#
# ES LO CONTRARIO DE SU PICADO, y ese contraste es todo lo que hay que acertar. Hasta ahora esta
# habilidad reproducia la embestida, o sea que la gargola DESPEGABA, se elevaba y se dejaba caer
# encima... para mirarte fijamente y no tocarte. Aqui NO hay 'vuela' ni 'avance': las patas no se
# despegan del suelo en ningun fotograma.
#
# LO QUE SE LEE DESDE EL SUR ES LA ENVERGADURA. De frente, un cuello que se adelanta esta escorzado y
# no recorre nada; lo que si se ve es que el bicho se ENSANCHE de golpe, asi que el gesto lo cuentan
# las alas abriendose (a lo ancho) y el cuerpo irguiendose (a lo alto). 0,70 de 'abre' y no 1,0: del
# todo es la pose del picado, y esta no puede confundirse con aquella.
#
# Y SE QUEDA QUIETA EN MEDIO (0,571 a 0,714 con los mismos valores). La quietud es el gesto: un bicho
# que te petrifica con la vista no se agita, se PARA -- y dos fotogramas identicos seguidos, en una
# tira donde todo lo demas se mueve, se leen como que se ha detenido.
static func _montar_mirada(anims: Array, esc: float) -> void:
	# Un tanteo corto de cabeza al principio y luego se centra: es "te ha encontrado".
	var cabeza_keys := [[0.0, 0.10], [0.143, 0.38], [0.286, 0.16], [0.429, 0.0], [0.571, 0.0],
		[0.714, 0.0], [0.857, 0.05], [1.0, 0.10]]
	# Se agazapa un instante antes de erguirse: sin ese valle, estirarse no tiene de donde salir.
	var agacha_keys := [[0.0, 0.0], [0.143, 0.16], [0.286, -0.10], [0.429, -0.20], [0.571, -0.24],
		[0.714, -0.22], [0.857, -0.10], [1.0, 0.0]]
	var abre_keys := [[0.0, 0.10], [0.143, 0.06], [0.286, 0.40], [0.429, 0.62], [0.571, 0.70],
		[0.714, 0.70], [0.857, 0.42], [1.0, 0.14]]
	# La cola TIESA y levantada, no ondulando: en el idle se mueve despacio, y aqui pararla es parte
	# de que el bicho entero se haya quedado rigido.
	var cola_keys := [[0.0, 0.30], [0.143, 0.10], [0.286, -0.45], [0.429, -0.70], [0.571, -0.75],
		[0.714, -0.75], [0.857, -0.40], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["cabeza"] = SpriteLienzo.tramos(t, cabeza_keys)
		p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
		p["abre"] = SpriteLienzo.tramos(t, abre_keys)
		p["cola"] = SpriteLienzo.tramos(t, cola_keys)
		return p
	# UNA SOLA DIRECCION: solo se ve en la pantalla de combate, y ahi se le mira de frente. El combate
	# cae a "mirada_0" cuando la direccion que toca no existe (ver combat.gd:_on_gesto_iniciado).
	_montar_animacion(anims, esc, "mirada", false, 8.0, pose, true, 1, FRAMES)


# ENCAJAR UN GOLPE. Cuatro fotogramas en UNA direccion y EMPEZANDO YA GOLPEADA: el frame 0 es el
# impacto. Un golpe no tiene anticipacion, y con cuatro marcos un fotograma de espera se comeria la
# animacion entera.
#
# ESTA SI SALE DESPEDIDA, al reves que el golem y el escarabajo: es de piedra pero es ligera, y ese
# retroceso es lo que dice de un vistazo cual de los tres constructos se puede empujar. Y las alas
# se le abren de golpe -- lo que hace cualquier cosa con alas cuando la sacuden.
static func _montar_encaje(anims: Array, esc: float) -> void:
	var retro_keys := [[0.0, 1.0], [0.34, 0.45], [0.67, 0.14], [1.0, 0.0]]
	var abre_keys := [[0.0, 0.62], [0.34, 0.40], [0.67, 0.18], [1.0, 0.08]]
	var mece_keys := [[0.0, -1.7], [0.34, 0.9], [0.67, -0.35], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["avance"] = -SpriteLienzo.tramos(t, retro_keys) * (LUNGE_DIST * ENCAJE_RETRO)
		p["abre"] = SpriteLienzo.tramos(t, abre_keys)
		p["mece"] = SpriteLienzo.tramos(t, mece_keys)
		p["cabeza"] = SpriteLienzo.tramos(t, mece_keys) * 0.6
		p["agacha"] = SpriteLienzo.tramos(t, retro_keys) * 0.55
		p["cola"] = SpriteLienzo.tramos(t, mece_keys) * 0.5
		return p
	# LOS BICHOS ENCAJAN A 18 fps: es la duracion que espera CombatFX.T_ENCAJE.
	_montar_animacion(anims, esc, "encaje", false, 18.0, pose, true, 1, 4)


# MORIRSE. OCHO fotogramas en UNA sola direccion: la muerte solo se ve en la pantalla de combate, y
# ahi al bicho se le mira siempre de frente. Para el mapa esta 'cadaver'.
#
# SE CAE COMO UNA ESTATUA, y esa es su muerte propia frente a las otras dos del bloque: el golem se
# derrumba en un monton (es barro) y esta se va ENTERA, de una pieza, sin doblarse por ningun sitio.
#
# Tres cosas la hacen leerse como piedra y no como carne:
# 1. LAS ALAS SE CIERRAN DE GOLPE, antes que nada. Es lo primero que se apaga.
# 2. LA CAIDA ACELERA. Apenas se mueve en el primer tercio (se queda tiesa, se inclina) y luego se
#    va de golpe, porque lo que la tira es su propio peso.
# 3. NO REBOTA NI SE ASIENTA al llegar al suelo. El escarabajo blindado da un bote y el trent se
#    asienta; una estatua que cae no hace ninguna de las dos, se para en seco donde cayo.
#
# 'tumba' son cuartos de vuelta sobre el eje que va del morro a la grupa, como el escarabajo, y el
# 'rumbo' la gira antes hacia el perfil: de frente ese eje apunta a la camara y la vuelta no se
# veria. Es la misma cuenta que el jabali y el escarabajo.
static func _pose_muerte(t: float) -> Dictionary:
	var tumba_keys := [[0.0, 0.0], [0.14, 0.05], [0.30, 0.18], [0.48, 0.48],
		[0.66, 0.80], [0.82, 0.97], [1.0, 1.0]]
	var rumbo_keys := [[0.0, 0.0], [0.14, 0.10], [0.48, 0.55], [0.82, 0.80], [1.0, 0.82]]
	# El apoyo la levanta mientras rueda, para que gire SOBRE el suelo y no dentro de el.
	var apoyo_keys := [[0.0, 0.0], [0.30, 0.5], [0.48, 1.8], [0.66, 3.2], [0.82, 4.2], [1.0, 4.3]]
	# Las alas se cierran de golpe y lo primero de todo.
	var abre_keys := [[0.0, 0.35], [0.14, 0.06], [1.0, 0.0]]
	# Las patas ceden un poco al principio; despues ya no se mueve nada, que es lo de la estatua.
	var agacha_keys := [[0.0, 0.0], [0.14, 0.45], [0.30, 0.62], [1.0, 0.62]]
	var cabeza_keys := [[0.0, 0.0], [0.14, -0.5], [0.30, -0.2], [1.0, 0.0]]
	var p: Dictionary = _reposo()
	p["tumba"] = SpriteLienzo.tramos(t, tumba_keys)
	p["rumbo"] = SpriteLienzo.tramos(t, rumbo_keys) * PI * 0.5
	p["apoyo"] = SpriteLienzo.tramos(t, apoyo_keys)
	p["abre"] = SpriteLienzo.tramos(t, abre_keys)
	p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
	p["cabeza"] = SpriteLienzo.tramos(t, cabeza_keys)
	p["cola"] = -0.4
	return p


static func _montar_muerte(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return _pose_muerte(t)
	_montar_animacion(anims, esc, "muerte", false, 11.0, pose, true, 1, 8)


# EL CADAVER DEL MAPA: UN fotograma por CADA direccion, al reves que 'muerte' (ocho fotogramas en
# una sola). En combate se le ve morir de frente y una vez; en el mapa se entra y ya esta tirada,
# pero pudo caer mirando a cualquier lado.
#
# Es EXACTAMENTE la pose final de la muerte, de la misma funcion: reescribir los numeros aqui es
# garantizar que el dia que se retoque la muerte el cadaver se quede como estaba.
static func _montar_cadaver(anims: Array, esc: float) -> void:
	var pose := func(_t: float) -> Dictionary:
		return _pose_muerte(1.0)
	# ultimo_incluido = false con UN marco, o el divisor seria (1-1) = 0 y el reparto de t saldria NaN.
	_montar_animacion(anims, esc, "cadaver", false, 1.0, pose, false, 8, 1)


static func _montar_animacion(anims: Array, esc: float, nombre: String,
		loop: bool, fps: float,
		pose_fn: Callable, ultimo_incluido: bool, dirs: int = 8, marcos: int = FRAMES) -> void:
	var divisor: float = float(marcos - 1) if ultimo_incluido else float(marcos)
	for dir in dirs:
		var plantillas: Array = []
		for i in marcos:
			# La GEOMETRIA se cachea por (animacion, frame, direccion, escala) y NO por color: otra
			# gargola de otro tono reusa estas plantillas y solo repinta.
			var clave: String = "%s_%d_%d_%.2f" % [nombre, i, dir, esc]
			var plant: PackedByteArray = _cache_plantillas.get(clave, PackedByteArray())
			if plant.is_empty():
				plant = _plantilla(dir, pose_fn.call(float(i) / divisor), esc)
				_cache_plantillas[clave] = plant
			plantillas.append(plant)
		anims.append({"nombre": "%s_%d" % [nombre, dir], "loop": loop, "fps": fps,
			"plantillas": plantillas})


# BASALTO: piedra volcanica, gris con un punto AZUL. Se hace OSCURECIENDO y subiendo la saturacion,
# igual que el escarabajo de hierro y por lo mismo -- el color que llega no es el de la ficha, es
# 'color_visual', que ya viene aclarado hacia el blanco segun la 't' del bicho, o sea desaturado de
# fabrica. Desaturarlo encima lo dejaria en cemento.
#
# Pero SIN el brillo duro del escarabajo: el basalto es mate y poroso. El volumen lo pone un
# degradado de tres tonos, no un reflejo.
static func _basalto(color: Color) -> Color:
	var out := Color.from_hsv(color.h, minf(1.0, color.s * 1.25 + 0.05), color.v * 0.96)
	out.a = color.a
	return out


# Los colores de cada Tono, EN EL ORDEN DEL ENUM (contrato con SpriteLienzo.paleta).
static func _colores(color: Color) -> Array:
	var c: Color = _basalto(color)
	return [
		Color(0, 0, 0, 0),                    # VACIO
		Color(0, 0, 0, 0.26),                 # SOMBRA_SUELO
		c.darkened(0.72),                     # BORDE
		# LAS GARRAS, casi negras: es lo unico afilado del bicho y tiene que cantar contra el gris.
		c.darkened(0.62),                     # GARRA_T
		# LAS PATAS CON TONO PROPIO, y no es capricho de paleta: con el del cuerpo, la luz del torso
		# (que se pinta 'solo_sobre' ese tono) las REPINTABA y el bajo del bicho se quedaba en una
		# masa sin patas. Es el fallo que ya tuvieron el trent y el golem.
		c.darkened(0.50),                     # PATA_OSC (la de detras)
		c.darkened(0.36),                     # PATA_T (la adelantada: hace legible el paso)
		# Los brazos, en sombra: cuelgan por delante del pecho y sin un tono aparte se funden con el
		# (entre brazo y cuerpo no hay hueco, y sin hueco 'contornear' no pone linea).
		c.darkened(0.54),                     # BRAZO_OSC (el de detras)
		c.darkened(0.40),                     # BRAZO_T (el de delante)
		# LA MEMBRANA DEL ALA, MAS OSCURA QUE EL CUERPO y no mas clara. Es lo que la separa de la
		# piedra del lomo cuando va plegada encima de el, que es su postura normal.
		c.darkened(0.46),                     # MEMBRANA_OSC (el ala de detras)
		c.darkened(0.32),                     # MEMBRANA
		# EL HUESO del borde de ataque: lo mas oscuro del ala. Sin el, el ala es una mancha sin forma
		# y no se sabe por donde corta el aire.
		c.darkened(0.66),                     # HUESO_OSC
		c.darkened(0.56),                     # HUESO
		c.darkened(0.20),                     # PIEDRA_OSC (el costado del cuerpo, en penumbra)
		c,                                    # PIEDRA
		# Lo alto del lomo y de la cabeza, a la luz. Se aclara hacia un GRIS FRIO y no hacia el
		# blanco: 'lightened' desatura, y el basalto perderia su azul.
		c.lerp(Color(0.74, 0.78, 0.84), 0.34),                # PIEDRA_CLARA
		# LOS OJOS VACIOS de la "Mirada petrea": claros, frios y sin pupila. Amarillos serian los del
		# golem, y estos dos comparten piso.
		Color(0.86, 0.92, 0.96),              # OJO_T
		# Y apagados en el cadaver: una estatua caida que sigue mirando no esta muerta.
		c.darkened(0.58),                     # APAGADO
	]


# ------------------------------------------------------------
#  GEOMETRIA
# ------------------------------------------------------------

# Un punto de la curva de un tramo (bezier cuadratica: arranque, codo, final). Igual que las patas
# del escarabajo y de la araña.
static func _curva(a: Vector3, codo: Vector3, b: Vector3, f: float) -> Vector3:
	var g: float = 1.0 - f
	return a * (g * g) + codo * (2.0 * g * f) + b * (f * f)


# Una direccion desde el centro de una pieza -> el punto de su superficie en esa direccion, metido
# 'hunde' hacia dentro. Es lo que garantiza que ningun adorno flote: la superficie esta a distinta
# distancia en cada direccion, asi que un punto puesto a mano encaja mirando a un lado y se despega
# mirando al otro.
static func _en_la_pieza(dir: Vector3, hunde: float, centro: Vector3, radio: Vector3) -> Vector3:
	var d: Vector3 = dir.normalized()
	return centro + Vector3(radio.x * d.x, radio.y * d.y, radio.z * d.z) - d * hunde


# Las PIEZAS de la gargola para una pose, ya proyectadas a pantalla. El orden ES la profundidad: de
# lo mas bajo y lejano (sombra, ala de detras, pata de detras) a lo mas alto y cercano (cabeza, ojos,
# ala de delante).
static func _piezas(dir: int, pose: Dictionary, esc: float) -> Array:
	# RUMBO: un giro EXTRA en planta, encima del de la direccion. Solo lo usa la muerte, para que la
	# caida se vea (de frente, el eje sobre el que vuelca apunta a la camara).
	var ang: float = DIR_VECS[dir].angle() - DIR_VECS[0].angle() + float(pose.get("rumbo", 0.0))
	var u: float = esc / SpriteLienzo.UNIDADES_POR_CELDA
	var origen: Vector2 = _origen(esc)
	var mece: float = float(pose["mece"])
	var balanceo: float = float(pose["balanceo"])
	var fase_brazos: float = float(pose["brazos"])
	var alza: float = float(pose["alza"])
	var avance: float = float(pose["avance"])
	var agacha: float = float(pose["agacha"])
	var cabeza_gira: float = float(pose["cabeza"])
	var fase_patas: float = float(pose["patas"])
	var abre: float = clampf(float(pose["abre"]), 0.0, 1.0)
	var cola_f: float = float(pose["cola"])
	# CUANTO SE HA DESPEGADO DEL SUELO. Sube el bicho entero, pero NO la sombra: esa separacion es lo
	# unico que se lee como estar en el aire (subirlo todo junto se lee como que ha crecido).
	var vuela: float = float(pose["vuela"])
	# TUMBARSE: cuartos de vuelta sobre el eje morro-grupa. 1.0 = de costado, tirada.
	var tumba: float = clampf(float(pose.get("tumba", 0.0)), 0.0, 1.2) * PI * 0.5
	var apoyo: float = float(pose.get("apoyo", 0.0))
	var ct: float = cos(tumba)
	var st: float = sin(tumba)

	# Agazapada = mas baja y un pelin mas ancha.
	var alto_f: float = 1.0 - 0.24 * agacha
	var ancho_f: float = 1.0 + 0.07 * agacha

	var piezas: Array = []
	# EL AVANCE SE ROTA UNA VEZ Y LO LLEVAN TODAS LAS PIEZAS POR IGUAL. Sumarlo a la Y local antes de
	# rotar solo funcionaria si TODAS las piezas giraran, y aqui el torso NO gira: el bicho se
	# partiria en dos mitades yendose a sitios distintos. Es la trampa del meceo del trent.
	var desp := Vector2(0.0, avance).rotated(ang)
	# EL MECEO, IGUAL: en pantalla y despues de rotar. Y se dobla POR LA ALTURA, o sea que la cabeza
	# va y viene y las garras no se despegan del suelo.
	var mece_v := Vector2(balanceo * 1.4, mece * 1.5)

	var poner := func(local: Vector3, r: Vector3, tono: int, solo_sobre: Array = [],
			gira: bool = true, en_suelo: bool = false) -> void:
		# TUMBAR, lo primero: gira el punto en el plano ANCHO-ALTURA, o sea alrededor del eje que va
		# del morro a la grupa. 'en_suelo' se lo salta: es la sombra, y el suelo ni vuelca ni sube.
		var lx: float = local.x
		var lz: float = local.z * alto_f
		if tumba != 0.0 and not en_suelo:
			var nx: float = lx * ct + lz * st
			lz = -lx * st + lz * ct
			lx = nx
		var alto: float = clampf(local.z / CABEZA.z, 0.0, 1.4)
		var p := Vector2(lx * ancho_f, local.y)
		# AL CAER GIRA TODO, tambien lo que normalmente no gira: la caida desplaza mucho hacia un
		# lado y ESE desplazamiento si tiene direccion. Sin rotarlo, el torso se iba siempre hacia el
		# mismo lado de la pantalla mientras las alas y las patas se iban hacia donde de verdad
		# miraba -- el cadaver partido en dos mitades, y solo en tres de las ocho direcciones.
		var gira_ya: bool = gira or tumba != 0.0
		var rot: Vector2 = (p.rotated(ang) if gira_ya else p) + desp + mece_v * alto
		var z: float = 0.0 if en_suelo else lz + apoyo + vuela
		var sx: float = origen.x + rot.x * u
		var sy: float = origen.y + (rot.y * SpriteLienzo.COS_CAM - z * SpriteLienzo.SIN_CAM) * u
		# EL RADIO TAMBIEN GIRA al volcar: el semieje a lo ANCHO pasa a ser el vertical y al reves.
		# Sin esto la gargola tirada de costado sale igual de alta que de pie.
		var mez: float = absf(st) if not en_suelo else 0.0
		var rx: float = lerpf(r.x, r.z, mez)
		var rz: float = lerpf(r.z, r.x, mez) * alto_f
		piezas.append({"pos": Vector2(sx, sy), "radio": Vector2(rx * ancho_f * u, r.y * u),
			"persp": 1.0 if en_suelo else SpriteLienzo.persp_de(r.y, rz),
			"tono": tono, "solo_sobre": solo_sobre})

	# 1. SOMBRA DE CONTACTO, lo primero (va debajo de todo). A ALTURA CERO: acompaña al bicho por el
	#    suelo cuando pica pero NO sube con el, y esa separacion es lo que se lee como volar.
	poner.call(Vector3(0.0, TORSO.y, 0.0), Vector3(TORSO_R.x * 1.15, TORSO_R.y * 1.15, 0.0),
		Tono.SOMBRA_SUELO, [], false, true)

	# LOS PIES, calculados una vez porque los usan las patas y las garras. GIRAN CON EL BICHO (al
	# contrario que el torso) y DAN EL PASO: uno adelante y otro atras, en contrafase. El adelantado
	# se LEVANTA bastante: esta pisa, no arrastra como el golem.
	var pies: Array = []
	for lado in [-1.0, 1.0]:
		var swing: float = fase_patas * lado
		pies.append(Vector3(lado * PIE.x, PIE.y + swing * PASO_LARGO,
			PIE.z + maxf(0.0, swing) * PASO_ALZA))

	# 2. EL ALA DE DETRAS. Cual es cual sale de su Y YA GIRADA -- una prueba de profundidad de
	#    verdad, no una tabla por direccion que haya que mantener. Va debajo de todo el cuerpo.
	var alas: Array = []
	for lado in [-1.0, 1.0]:
		var raiz := Vector3(lado * ALA_RAIZ.x, ALA_RAIZ.y, ALA_RAIZ.z)
		alas.append({"lado": lado, "raiz": raiz,
			"delante": Vector2(raiz.x, raiz.y).rotated(ang).y > 0.0})
	for a in alas:
		if not bool(a["delante"]):
			_ala(poner, a, abre, DETRAS_ESC, Tono.MEMBRANA_OSC, Tono.HUESO_OSC)

	# 3. LOS BRAZOS de detras, y 4. LAS PATAS de detras.
	var brazos: Array = []
	for lado in [-1.0, 1.0]:
		var hombro := Vector3(lado * HOMBRO_X, HOMBRO_Y, HOMBRO_Z)
		brazos.append({"lado": lado, "hombro": hombro,
			"delante": Vector2(hombro.x, hombro.y).rotated(ang).y > 0.0})
	for b in brazos:
		if not bool(b["delante"]):
			_brazo(poner, b, fase_brazos, alza, DETRAS_ESC, Tono.BRAZO_OSC)

	# 5. LA COLA, detras del cuerpo (sale de la grupa y se va hacia atras).
	_cola(poner, cola_f)

	# 6. LAS PATAS: la ADELANTADA en tono mas claro, que es lo que deja ver de un vistazo cual ha
	#    dado el paso.
	for k in pies.size():
		_pata(poner, pies[k], Vector3(sign(pies[k].x) * CADERA.x, CADERA.y, CADERA.z),
			Vector3(sign(pies[k].x) * CORVEJON.x, CORVEJON.y, CORVEJON.z),
			Tono.PATA_T if pies[k].y >= pies[1 - k].y else Tono.PATA_OSC)

	# 7. EL TORSO, entero en penumbra, y encima el mismo a plena luz. No gira: es casi redondo en
	#    planta y se ve igual desde los ocho lados.
	poner.call(TORSO, TORSO_R, Tono.PIEDRA_OSC, [], false)
	poner.call(Vector3(TORSO.x, TORSO.y, TORSO.z + TORSO_R.z * 0.18), TORSO_R * 0.94,
		Tono.PIEDRA, [Tono.PIEDRA_OSC], false)
	poner.call(Vector3(TORSO.x, TORSO.y + TORSO_R.y * 0.20, TORSO.z + TORSO_R.z * 0.48),
		TORSO_R * 0.50, Tono.PIEDRA_CLARA, [Tono.PIEDRA], false)

	# 7b. LOS HOMBROS, que GIRAN y van DESPUES de la luz del torso y ANTES de la cabeza. Es la
	#     leccion del golem, y las tres cosas cuentan:
	#     - Sin girar quedan clavados a los lados y de perfil el bicho enseña DOS hombros donde
	#       deberia enseñar uno.
	#     - Girando, de perfil uno se va hacia la camara y otro al fondo (o sea uno abajo y otro
	#       arriba en pantalla), y el de arriba lo TAPA la cabeza, que se pinta despues.
	#     - Y con luz propia PEQUEÑA y pegada al centro: subida deja un canto horizontal limpio y el
	#       hombro se lee como un PLATO de canto, o sea una hombrera de armadura. Aqui eso seria el
	#       coloso.
	for b in brazos:
		var h: Vector3 = b["hombro"]
		poner.call(h, HOMBRO_R, Tono.PIEDRA_OSC)
		poner.call(Vector3(h.x, h.y, h.z + HOMBRO_R.z * 0.16), HOMBRO_R * 0.78,
			Tono.PIEDRA, [Tono.PIEDRA_OSC])

	# 8. CUELLO Y CABEZA, adelantados y bajos: la postura agazapada. La cabeza gira un poco con
	#    'cabeza' (tantea al estar quieta, y se sacude al encajar un golpe).
	var giro_cab: float = cabeza_gira * 1.6
	poner.call(CUELLO, CUELLO_R, Tono.PIEDRA_OSC)
	var cab := Vector3(CABEZA.x + giro_cab, CABEZA.y, CABEZA.z)
	poner.call(cab, CABEZA_R, Tono.PIEDRA_OSC)
	poner.call(Vector3(cab.x, cab.y, cab.z + CABEZA_R.z * 0.26), CABEZA_R * 0.86,
		Tono.PIEDRA, [Tono.PIEDRA_OSC])
	# EL HOCICO va DESPUES de la luz de la cabeza y en penumbra: es lo que la separa de la bola.
	poner.call(Vector3(HOCICO.x + giro_cab * 1.3, HOCICO.y, HOCICO.z), HOCICO_R, Tono.PIEDRA_OSC)
	poner.call(Vector3(HOCICO.x + giro_cab * 1.3, HOCICO.y, HOCICO.z + HOCICO_R.z * 0.35),
		HOCICO_R * 0.72, Tono.PIEDRA, [Tono.PIEDRA_OSC])

	# 9. CUERNOS: dos, hacia atras y arriba. Rompen la silueta redonda de la cabeza.
	for lado in [-1.0, 1.0]:
		var base := Vector3(cab.x + lado * CUERNO_X, cab.y - CABEZA_R.y * 0.35, cab.z + CUERNO_Z)
		for k in CUERNO_SEGMENTOS:
			var f: float = float(k) / float(CUERNO_SEGMENTOS - 1)
			poner.call(Vector3(base.x + lado * f * 1.4,
					base.y - CUERNO_PASO * float(k) * 0.72,
					base.z + CUERNO_PASO * float(k) * 0.62),
				Vector3.ONE * lerpf(CUERNO_R0, CUERNO_R1, f), Tono.PIEDRA_OSC)

	# 10. LA CEJA, la visera sobre los ojos, y debajo LOS OJOS VACIOS.
	#     De espaldas no se le ve la cara -- un bicho que se aleja enseña la nuca, y eso es lo que
	#     hace que se lea de un vistazo si viene o si huye. Y muerta, los ojos se apagan.
	var encendido: bool = tumba < PI * 0.25
	var frente: float = Vector2(0.0, 1.0).rotated(ang).y
	if frente > -0.35:
		poner.call(Vector3(CEJA.x + giro_cab * 1.2, CEJA.y, CEJA.z), CEJA_R, Tono.PIEDRA_OSC)
		var ojos: Array = []
		for l in [-1.0, 1.0]:
			var d := Vector3(l * OJO_DIR.x, OJO_DIR.y, OJO_DIR.z)
			var fondo: float = Vector2(d.x, d.y).rotated(ang).y
			if fondo > OJO_VISIBLE:
				var o: Vector3 = _en_la_pieza(d, OJO_HUNDE, CABEZA, CABEZA_ANCLA_R)
				ojos.append({"pos": Vector3(o.x + giro_cab * 1.2, o.y, o.z), "fondo": fondo})
		# DE PERFIL PURO, UNO SOLO: ahi los dos caen en la misma X de pantalla y se separan solo en
		# vertical, y dos ojos uno encima del otro se leen como un borron, no como una cara.
		if absf(DIR_VECS[dir].x) >= 0.9 and ojos.size() == 2:
			ojos = [ojos[0] if float(ojos[0]["fondo"]) > float(ojos[1]["fondo"]) else ojos[1]]
		for o in ojos:
			poner.call(o["pos"], OJO_R, Tono.OJO_T if encendido else Tono.APAGADO)

	# 11. EL BRAZO DE DELANTE y 12. EL ALA DE DELANTE, ya sobre el cuerpo.
	for b in brazos:
		if bool(b["delante"]):
			_brazo(poner, b, fase_brazos, alza, 1.0, Tono.BRAZO_T)
	for a in alas:
		if bool(a["delante"]):
			_ala(poner, a, abre, 1.0, Tono.MEMBRANA, Tono.HUESO)

	return piezas


# UNA PATA DIGITIGRADA: muslo de la cadera al corvejon y caña del corvejon al pie, las dos por
# bezier para que se curven. El corvejon va HACIA ATRAS -- es la rodilla invertida de un ave -- y
# eso es lo que hace que se lea agazapada en vez de en cuclillas.
static func _pata(poner: Callable, pie: Vector3, cadera: Vector3, corvejon: Vector3,
		tono: int) -> void:
	var lado: float = signf(pie.x)
	# El corvejon sigue al pie: si no, el pie da el paso y la pata se queda clavada donde estaba.
	var cor := Vector3(corvejon.x, lerpf(cadera.y, pie.y, 0.35) + corvejon.y * 0.5, corvejon.z)
	var cod1: Vector3 = cadera.lerp(cor, 0.5) + Vector3(lado * 0.7, -1.1, 0.0)
	var cod2: Vector3 = cor.lerp(pie, 0.5) + Vector3(lado * 0.3, 0.9, 0.0)
	for k in MUSLO_SEGMENTOS:
		var f: float = float(k) / float(MUSLO_SEGMENTOS - 1)
		poner.call(_curva(cadera, cod1, cor, f),
			Vector3.ONE * lerpf(MUSLO_R0, MUSLO_R1, f), tono)
	for k in CANA_SEGMENTOS:
		var f: float = float(k) / float(CANA_SEGMENTOS - 1)
		poner.call(_curva(cor, cod2, pie, f),
			Vector3.ONE * lerpf(CANA_R0, CANA_R1, f), tono)
	# LAS GARRAS, abiertas hacia delante en abanico. Casi negras: es lo unico afilado que tiene y
	# tiene que cantar contra el gris. En ABANICO y no en fila: una fila de piezas alineada con un
	# eje se apila vista de frente y sale como una raya (la leccion de las cerdas del jabali).
	for k in GARRAS:
		var t: float = -1.0 + 2.0 * float(k) / float(GARRAS - 1)
		poner.call(Vector3(pie.x + lado * t * 1.5, pie.y + GARRA_LARGO * (1.0 - 0.25 * absf(t)),
				pie.z - 0.4),
			Vector3.ONE * GARRA_R, Tono.GARRA_T)


# UN BRAZO: cadena corta y doblada, rematada en zarpa. Igual que el del golem pero mas corto: esta
# no golpea con las manos, se agarra.
#
# LA CADENA SE CONSTRUYE PASO A PASO, cada tramo en la direccion que le toca, y NO como puntos de una
# circunferencia: es la unica forma de curvar el brazo sin romperlo, porque asi la separacion entre
# piezas es exactamente BRAZO_PASO se doble como se doble.
static func _brazo(poner: Callable, b: Dictionary, fase: float, alza: float,
		esc_detras: float, tono: int) -> void:
	var lado: float = float(b["lado"])
	var hombro: Vector3 = b["hombro"]
	var th: float = lerpf(BRAZO_ANG_REPOSO, BRAZO_ANG_ALTO, clampf(alza, 0.0, 1.0))
	var codo: float = BRAZO_CODO * clampf(1.0 - alza, 0.0, 1.0)
	var eje: Vector3 = hombro
	var ultimo: Vector3 = hombro
	var penultimo: Vector3 = hombro
	for k in BRAZO_SEGMENTOS:
		var f: float = float(k) / float(BRAZO_SEGMENTOS - 1)
		if k > 0:
			var a: float = th + codo * pow(f, 1.3)
			var d := Vector3(lado * BRAZO_ABRE, sin(a) * BRAZO_ADELANTA, -cos(a)).normalized()
			eje += d * BRAZO_PASO
		var p := Vector3(eje.x, eje.y + fase * f * 1.6, eje.z)
		poner.call(p, Vector3.ONE * lerpf(BRAZO_R0, BRAZO_R1, f) * esc_detras, tono)
		penultimo = ultimo
		ultimo = p
	# LA ZARPA, en la MISMA direccion del ultimo tramo y metida dentro de el varias celdas (un solape
	# de una celda no es un solape). La direccion sale del tramo ya dibujado y no del angulo, asi la
	# mano sigue al brazo aunque el balanceo lo haya desviado.
	var d2: Vector3 = ultimo - penultimo
	d2 = d2.normalized() if d2.length() > 0.01 else Vector3(0, 0, -1)
	var zarpa: Vector3 = ultimo + d2 * (ZARPA_R.z * 0.40)
	poner.call(zarpa, ZARPA_R * esc_detras, tono)
	for k in GARRAS:
		var t: float = -1.0 + 2.0 * float(k) / float(GARRAS - 1)
		poner.call(zarpa + d2 * (ZARPA_R.z * 0.55)
				+ Vector3(lado * ZARPA_R.x * 0.55 * t, 0.0, ZARPA_R.z * 0.30 * (1.0 - t * t)),
			Vector3.ONE * (GARRA_R * 0.85) * esc_detras, Tono.GARRA_T)


# LA COLA: cadena que sale de la grupa, se va hacia atras y se LEVANTA hacia la punta, rematada en
# una pala de piedra. 'mueve' la barre de lado.
static func _cola(poner: Callable, mueve: float) -> void:
	var eje: Vector3 = COLA_RAIZ
	var ultimo: Vector3 = eje
	for k in COLA_SEGMENTOS:
		var f: float = float(k) / float(COLA_SEGMENTOS - 1)
		if k > 0:
			# Se va levantando: el angulo crece con f, asi que la cola describe una curva y no un
			# palo. Paso UNITARIO, como en los brazos, para que la cadena no se descosa al curvarse.
			var a: float = COLA_ANG + COLA_CURVA * f
			var d := Vector3(mueve * 0.30 * f, -cos(a), sin(a)).normalized()
			eje += d * COLA_PASO
		poner.call(eje, Vector3.ONE * lerpf(COLA_R0, COLA_R1, f), Tono.PIEDRA_OSC)
		ultimo = eje
	# LA PALA DE LA PUNTA. Va METIDA en la ultima bola de la cola: un solape de una celda no es un
	# solape.
	poner.call(ultimo + Vector3(0.0, -PALA_R.y * 0.35, PALA_R.z * 0.25), PALA_R, Tono.PIEDRA_OSC)


# UN ALA. Rejilla de piezas: 'i' a lo largo del hueso (span) y 'j' de delante a atras (cuerda).
#
# CADA PIEZA ES UN PLATO, no una bola: una membrana es ancha en dos ejes y FINISIMA en el tercero, y
# con bolas saldria un churro. Y CUAL de los tres radios es el fino CAMBIA AL ABRIRSE, que es todo
# el truco del despliegue:
#   - PLEGADA, el ala es un plano VERTICAL pegado al lomo -> el eje fino es el ANCHO (x).
#   - ABIERTA, es un plano casi horizontal -> el eje fino es la ALTURA (z).
# Interpolando a la vez la direccion del hueso y cual radio es el fino, el ala se despliega sin que
# se despegue ni una pieza, porque las piezas nunca dejan de solaparse con sus vecinas.
static func _ala(poner: Callable, a: Dictionary, abre: float, esc_detras: float,
		tono: int, tono_hueso: int) -> void:
	var lado: float = float(a["lado"])
	var raiz: Vector3 = a["raiz"]
	var largo: float = ALA_LARGO * lerpf(ALA_LARGO_PLEGADA, 1.0, abre)

	# EL HUESO DEL BORDE DE ATAQUE SE ARQUEA, no es recto, y eso es lo que separa un ala de MURCIELAGO
	# de un ala de POLILLA. Un hueso recto saliendo del hombro hacia arriba y afuera da dos paletas
	# simetricas pegadas a la cabeza -- la gargola salia como una mariposa nocturna, cabezota entre
	# dos alas. El ala de verdad ARRANCA SUBIENDO por encima del hombro y su punta CAE hacia fuera:
	# ese arco es la silueta que se reconoce, y ademas deja la membrana colgando por debajo.
	#
	# Se hace con dos direcciones, la de la raiz y la de la punta, y el tramo 'i' va interpolado
	# entre las dos. Cada tramo avanza un paso UNITARIO, igual que las cadenas de los brazos: asi la
	# separacion entre piezas es siempre la misma se arquee el ala como se arquee, y no hay forma de
	# que la cadena se descosa (la vieja regla del paso menor que el grosor).
	var raiz_plegada := Vector3(lado * 0.18, -0.50, 0.85)
	var punta_plegada := Vector3(lado * 0.30, -0.80, 0.52)
	var raiz_abierta := Vector3(lado * 0.50, -0.26, 0.82)
	var punta_abierta := Vector3(lado * 0.86, -0.30, -0.46)
	var d_raiz: Vector3 = raiz_plegada.lerp(raiz_abierta, abre).normalized()
	var d_punta: Vector3 = punta_plegada.lerp(punta_abierta, abre).normalized()
	# La direccion MEDIA, solo para orientar el grosor de los platos y el garfio de la punta.
	var hueso: Vector3 = d_raiz.lerp(d_punta, 0.5).normalized()

	# Y la direccion de la CUERDA, de delante a atras de la membrana. AQUI ESTA LA TRAMPA GORDA.
	#
	# Plegada, la cuerda cae por el costado (hacia ABAJO); abierta, se va hacia ATRAS. Y con la
	# camara a 45 grados atras y abajo son EL MISMO EJE con signo contrario: la altura en pantalla
	# sale de (y - z), asi que a mitad de camino entre las dos poses la cuerda queda con (y - z) = 0,
	# o sea EXACTAMENTE en el eje ciego de la camara. La membrana entera colapsaba sobre el borde de
	# ataque y el ala salia como un PALO -- solo el hueso, con la membrana escondida detras de el.
	# Es el mismo efecto que la cola usa a favor para no subirse a la cabeza.
	#
	# No se puede evitar interpolando: las dos poses tienen (y - z) de signo contrario, asi que el
	# cero esta si o si por el medio. Lo que se hace es SACAR LA CUERDA HACIA FUERA justo en el
	# medio, con un bulto en X que vale cero en las dos puntas -- y ademas es lo que hace un ala de
	# verdad al desplegarse, barrer la membrana hacia el lado. Con X, el ala tiene ancho en pantalla
	# aunque (y - z) se anule.
	var cuerda_plegada := Vector3(lado * 0.30, -0.22, -0.93)
	var cuerda_abierta := Vector3(lado * -0.10, -0.97, -0.22)
	var cuerda: Vector3 = (cuerda_plegada.lerp(cuerda_abierta, abre)
		+ Vector3(lado * ALA_BARRE * sin(PI * abre), 0.0, 0.0)).normalized()

	# El eje FINO va con la normal: plegada el ala es un plano vertical (fina a lo ancho) y abierta
	# uno casi horizontal (fina en altura).
	var fino_x: float = lerpf(ALA_GRUESO, ALA_CUERDA_MAX * 0.30, abre)
	var fino_z: float = lerpf(ALA_CUERDA_MAX * 0.30, ALA_GRUESO, abre)

	var paso_span: float = largo / float(ALA_SPAN - 1)
	# EL BORDE DE ATAQUE, tramo a tramo. El hueso arranca en 'd_raiz' y acaba en 'd_punta', asi que
	# describe un ARCO: sube por encima del hombro y la punta cae hacia fuera.
	# Se guardan los puntos y las cuerdas porque los DEDOS se cuelgan de ellos despues.
	var borde: Vector3 = raiz
	var bordes: Array = []
	var anchos: Array = []
	for i in ALA_SPAN:
		var s: float = float(i) / float(ALA_SPAN - 1)
		if i > 0:
			# La direccion del tramo. 'pow(s, 0.75)' hace que el ala se enderece pronto y pase la
			# mayor parte de su largo cayendo: si se reparte lineal, el arco sale simetrico y vuelve a
			# parecer una paleta.
			borde += d_raiz.lerp(d_punta, pow(s, 0.75)).normalized() * paso_span
		# La CUERDA de la membrana en este punto del hueso: cero en la raiz seria un pico, asi que
		# arranca en 0,40 -- el ala nace pegada al lomo -- y se cierra hacia la punta.
		var ancho: float = ALA_CUERDA_MAX * (0.40 + 0.60 * sin(PI * pow(s, 0.80)))
		# EL PASO ES ENTRE PIEZAS, o sea (N - 1) huecos y no N. Dividiendo por N el paso sale un 33%
		# corto, el radio que se calcula con el tambien, y las tres piezas de la cuerda NO LLEGAN A
		# TOCARSE: el ala salia como un palo -- solo se veia el hueso del borde de ataque y la
		# membrana eran motas sueltas alrededor. Es la vieja regla del paso menor que el grosor, pero
		# rota por una cuenta de indices.
		var paso_cuerda: float = ancho / float(ALA_CUERDA - 1)
		var base: Vector3 = borde
		for j in ALA_CUERDA:
			var v: float = float(j) / float(ALA_CUERDA - 1)
			var p: Vector3 = base + cuerda * (ancho * v)
			# El radio de cada plato: lo justo para SOLAPAR con sus vecinas en los dos sentidos de la
			# rejilla (span y cuerda), y el eje fino aparte. Sin ese 0,62 la membrana sale a lunares.
			var gordo: float = maxf(paso_span, paso_cuerda) * 0.62
			var r := Vector3(maxf(fino_x, gordo * absf(hueso.x) + gordo * 0.35),
				gordo, maxf(fino_z, gordo * absf(hueso.z) * 0.6))
			poner.call(p, r * esc_detras, tono_hueso if j == 0 else tono)
		# EL GARFIO de la punta: el dedo que remata un ala de murcielago, y lo que impide que el ala
		# acabe en una punta roma.
		if i == ALA_SPAN - 1:
			poner.call(base + hueso * (paso_span * 0.55),
				Vector3.ONE * GARFIO_R * esc_detras, tono_hueso)
		bordes.append(base)
		anchos.append(ancho)

	# LOS DEDOS, encima de la membrana ya pintada. Sin ellos la membrana es una PALETA LISA, o sea el
	# ala de una polilla; con ellos la misma silueta se lee como un ala de murcielago. Es el detalle
	# que mas cambia la lectura de este bicho por lo poco que cuesta.
	#
	# Salen de la MUÑECA (el 40% del hueso) y se abren en abanico hasta el borde de salida, cada uno
	# a su punto del span. Van en el tono del hueso -- son hueso -- y finos: se pintan DENTRO de la
	# membrana, asi que el contorno no los toca y pueden bajar de las tres celdas de la regla.
	var i_mun: int = clampi(int(round(ALA_MUNECA * float(ALA_SPAN - 1))), 0, ALA_SPAN - 1)
	var muneca: Vector3 = bordes[i_mun]
	for k in ALA_DEDOS:
		# El ultimo dedo llega a la punta del ala y los otros se reparten hacia la muñeca.
		var f_span: float = lerpf(0.60, 1.0, float(k) / float(ALA_DEDOS - 1))
		var idx: int = clampi(int(round(f_span * float(ALA_SPAN - 1))), 0, ALA_SPAN - 1)
		var destino: Vector3 = bordes[idx] + cuerda * (anchos[idx] * 0.90)
		for m in range(1, DEDO_SEGMENTOS):
			var f: float = float(m) / float(DEDO_SEGMENTOS - 1)
			# 'solo_sobre' LA MEMBRANA: es lo que los convierte en nervios DENTRO del ala en vez de en
			# una mancha. Sueltos y con el tono del hueso -- que es lo mas oscuro del bicho -- los tres
			# dedos se comian la membrana entera y el ala volvia a ser una paleta, esta vez negra. Es
			# el mismo recurso que los nudillos del golem y el brillo del escarabajo.
			poner.call(muneca.lerp(destino, f), Vector3.ONE * DEDO_R * esc_detras, tono_hueso,
				[tono])


# La plantilla de un frame: que tono le toca a cada celda.
static func _plantilla(dir: int, pose: Dictionary, esc: float) -> PackedByteArray:
	var lz: Vector2i = _lienzo(esc)
	var plant := PackedByteArray()
	plant.resize(lz.x * lz.y)
	# 'resize' reserva sitio, no garantiza ceros. El cero es justo el VACIO, asi que sin esto puede
	# quedar basura de memoria alrededor del dibujo (ver la trampa 1 de motor-sprites).
	plant.fill(0)
	var piezas: Array = _piezas(dir, pose, esc)
	for p in piezas:
		var pos: Vector2 = p["pos"]
		var r: Vector2 = p["radio"]
		# ang = 0: ninguna pieza gira su FORMA; lo que gira es DONDE se ponen. Y sin giro, 'elipse'
		# coge su ruta rapida por filas.
		SpriteLienzo.elipse(plant, lz.x, lz.y, pos.x, pos.y, r.x, r.y, int(p["tono"]),
			0.0, p["solo_sobre"], float(p["persp"]))

	# CONTORNO al final, sobre la silueta ya completa (ver SpriteLienzo.contornear).
	SpriteLienzo.contornear(plant, SpriteLienzo.caja_de_piezas(piezas, lz.x, lz.y), lz.x, lz.y,
		Tono.BORDE, Tono.VACIO, Tono.SOMBRA_SUELO)
	return plant
