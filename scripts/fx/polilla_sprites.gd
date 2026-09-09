# ============================================================
#  polilla_sprites.gd  (class_name PolillaSprites)
#  La POLILLA DE ESPORAS (pisos 9-12) dibujada por codigo, con el motor comun (SpriteLienzo) y la
#  camara de 45 grados que comparten todos los bichos. Solo geometria: quien decide que a esta ficha
#  le toca este generador es SpritesEnemigo (por NOMBRE, ver GENERADORES_POR_NOMBRE).
#
#  ES EL UNICO BICHO DEL JUEGO QUE VUELA, y ahi esta media lectura: el cuerpo va despegado del suelo
#  y su sombra se queda abajo, pequeña y aparte. Esa separacion es lo que se lee como altura -- no el
#  dibujo estando mas arriba, que solo se leeria como que esta mas lejos. La gargola ya lo dejo
#  escrito en su 'vuela' y aqui es permanente: esta no se posa nunca, ni siquiera muerta hasta el
#  ultimo fotograma.
#
#  LA SILUETA SON LAS ALAS, no el cuerpo. Vista desde arriba una polilla es dos paletas anchas con un
#  bulto peludo en medio, y el cuerpo apenas asoma. Por eso las alas van GRANDES: a igualdad de
#  numeros salen siempre mas pequeñas de lo que parece, porque su envergadura va por la X (que no se
#  comprime) pero su cuerda va por la Y (que se comprime a cos45).
#
#  ------------------------------------------------------------
#  LA GARGOLA YA DEJO ESCRITO COMO SE HACE ESTE BICHO -- sin querer, contando sus propios fallos:
#
#    "el ala tenia y-z = -21,2 y la cabeza -22,3 [...] las dos alas brotaban justo al lado de la cara
#     y la gargola salia como una POLILLA -- cabezota redonda entre dos alas y cuerpo diminuto
#     debajo"
#    "LOS DEDOS [...] son LA SEÑA de un ala de murcielago, y sin ellos la membrana es una paleta
#     lisa -- que es exactamente el ala de una POLILLA"
#
#  O sea: alas ALTAS y pegadas a la cabeza (lo que alli era el fallo, aqui es el objetivo), y
#  membrana LISA, sin huesos ni dedos. Y al reves que ella, aqui el borde de ataque NO se arquea: un
#  ala de polilla es una paleta recta y ancha.
#
#  Y por eso ademas NO SE PARECEN pese a las alas: la gargola es de piedra, bipeda, agazapada y con
#  las alas plegadas casi siempre; esta es peluda, sin patas que se vean, siempre en el aire y con
#  las alas BATIENDO. El bateo es la mitad de su animacion y ella no lo tiene.
#  ------------------------------------------------------------
#
#  Hasta hoy se dibujaba con el generador de la ABERRACION, o sea que una polilla salia como un
#  pegote de tentaculos arrastrandose por el suelo.
# ============================================================

extends RefCounted
class_name PolillaSprites

const FRAMES := 8

# --- La polilla mirando al SUR, en unidades de MUNDO (origen = el punto del SUELO sobre el que
# vuela, +Y hacia la cabeza, +Z hacia arriba). ---
const ANCHO_MUNDO := 30.0

# A QUE ALTURA VUELA. Alto de verdad: es lo que separa el bicho de su sombra, y esa separacion es
# TODO lo que se lee como volar.
const VUELO_Z := 10.5
const CABECEO := 1.1                # cuanto sube y baja al batir

# EL CUERPO: una cadena corta de bultos peludos. Torax gordo delante, abdomen afilandose atras.
# Va casi todo tapado por las alas -- en una polilla de verdad tambien --, asi que lo que tiene que
# leerse de el es el bulto peludo entre las dos paletas.
const CUERPO_SEGMENTOS := 5
const CUERPO_Y0 := 4.2              # donde cae el segmento 0 (el mas adelantado, tras la cabeza)
const CUERPO_PASO := 2.05
const TORAX_R := Vector3(2.35, 2.20, 2.05)
const COLA_R := Vector3(0.95, 1.20, 0.90)
const TORAX_EN := 0.18              # que fraccion del cuerpo es el torax gordo

# CABEZA: pequeña y redonda, delante del torax.
const CABEZA := Vector3(0.0, 6.6, 0.0)
const CABEZA_R := Vector3(1.70, 1.55, 1.60)
# OJOS: dos bolas OSCURAS y grandes para la cabeza que tiene. Una polilla es casi todo ojo, y ademas
# son lo unico que dice hacia donde mira -- las alas son simetricas y no dicen nada.
const OJO_DIR := Vector3(0.62, 0.66, 0.22)
const OJO_R := Vector3(0.95, 0.95, 0.95)
const OJO_HUNDE := 0.55
const OJO_VISIBLE := -0.20          # de espaldas no se le ven (mismo criterio que el trent)

# ANTENAS: LA SEÑA DE LA POLILLA. Van PLUMOSAS -- un eje con barbas a los lados -- porque una antena
# lisa se lee como la de un escarabajo. Salen de la cabeza hacia delante y ARRIBA, y se abren.
# GRANDES Y CURVADAS. En las fotos son la mitad de largas que el bicho y se abren en arco hacia
# fuera, como dos helechos; cortas y rectas se leen como dos pelillos y la polilla pierde su seña.
# PERO NO TAN LARGAS COMO PARECE. A 7,6 con 0,78 de apertura las puntas llegaban a x = 10, casi lo
# mismo que las alas (12), y las dos antenas con sus barbas salian como un FLECO cremoso cruzando el
# bicho de lado a lado. Tienen que leerse como dos plumas delante de la cabeza, no como una tercera
# ala. Y van ALTAS, para que no se fundan con el borde de las alas.
const ANTENA_SEGMENTOS := 6
const ANTENA_LARGO := 5.6
const ANTENA_ABRE := 0.45           # cuanto se separan una de otra
const ANTENA_SUBE := 0.62
const ANTENA_CURVA := 0.30          # cuanto se doblan hacia fuera al final (el arco)
const ANTENA_R0 := 0.80
const ANTENA_R1 := 0.52
# Las BARBAS del peine, a los lados del eje. Cortas y gordas: a menos de tres celdas el contorno se
# las come enteras (la leccion de las manos del miconido y del cordon de micelio).
const BARBA_R := 0.70
const BARBA_LARGO := 1.55

# ============================================================
#  LAS ALAS
# ============================================================
# Un ala es una MEMBRANA: ancha en dos ejes y finisima en el tercero, y se dibuja como una rejilla de
# platos aplastados (la tecnica es la de la gargola). Pero la de aqui es MUCHO mas simple que la
# suya, y a proposito:
#
#   * NO SE PLIEGA. Una polilla no guarda las alas: las tiene siempre desplegadas y lo unico que hace
#     es BATIRLAS. Asi que no hay interpolacion entre dos poses ni el eje ciego de la camara que a la
#     gargola le convertia el ala en un palo a mitad del despliegue.
#   * NO TIENE HUESO NI DEDOS. Es una paleta lisa; el hueso arqueado y los dedos son justo lo que
#     hace que un ala se lea como de MURCIELAGO, y aqui sobran.
#   * SON DOS PARES. Las delanteras grandes y las traseras mas cortas y detras. Con un solo par se
#     lee como una mariposa o como un pajaro; el segundo par es lo que dice "polilla".
#
# EL BATEO: la envergadura gira en el plano ancho-alto alrededor de la raiz. Con 'bate' = 0 el ala
# esta plana (y en pantalla se ve entera y ancha) y con 'bate' = 1 esta vertical (y se ve de canto,
# estrechisima). Ese cambio de ancho ES el aleteo -- no hace falta mover nada mas.
const ALA_SPAN := 6                 # platos a lo largo de la envergadura
const ALA_CUERDA := 5               # platos de delante a atras
# LA DELANTERA: larga y ancha. La envergadura va por la X, que NO se comprime en pantalla; la cuerda
# va por la Y, que se comprime a cos45. Por eso la cuerda va generosa: a 6 salia una paleta fina.
#
# ABIERTAS DE PAR EN PAR, NO EN TRIANGULO. Una polilla se lee de dos maneras muy distintas y hay que
# elegir la que toca: EN REPOSO pliega las alas en tejadillo y su silueta es un TRIANGULO (que es lo
# que enseñan las fichas de museo); VOLANDO las lleva extendidas, anchas y redondas, en aspa -- la
# Luna, la Io, la emperador. Esta no se posa nunca, asi que le toca la segunda.
#
# El primer intento le puso una flecha de 0,62 y salio la silueta de reposo: dos triangulos barridos
# hacia atras. Con las alas abiertas la flecha es POCA y lo que manda es lo anchas y redondas que
# son.
const ALA1_RAIZ := Vector3(1.35, 2.8, 0.35)
const ALA1_LARGO := 12.0
const ALA1_CUERDA := 8.8
const ALA1_FLECHA := -0.16
# Y LAS DELANTERAS SE VAN ALGO HACIA DELANTE al abrirse, no salen rectas de lado: es lo que abre el
# aspa por arriba y lo que deja hueco para que las traseras se vean por debajo.
const ALA1_ADELANTA := 0.26
# LA TRASERA: casi tan grande como la delantera (en una polilla de verdad lo es), REDONDA y tirando
# hacia atras. Es la que lleva el ocelo gordo en las fotos.
const ALA2_RAIZ := Vector3(1.20, -1.6, -0.35)
const ALA2_LARGO := 9.4
const ALA2_CUERDA := 8.2
const ALA2_FLECHA := -0.10
const ALA2_ADELANTA := -0.30
# El barrido se reparte casi lineal: con las alas abiertas no hay punta que se dispare hacia atras.
const ALA_FLECHA_CURVA := 1.10
# EL EJE FINO DE LA MEMBRANA TIENE UN MINIMO, y no es de gusto. Con 0,62 el ala puesta de canto medía
# UNA CELDA de grosor, y 'contornear' convierte en borde toda celda que toque el vacio: los treinta
# platos del ala se quedaban en contorno puro y de perfil la polilla se deshacia en CRUCES sueltas.
# Es la misma leccion que las manos del miconido y el cordon de micelio, pero en una superficie.
const ALA_GRUESO := 1.15            # el eje fino de la membrana
# Y EL BATIDO NO LLEGA A LA VERTICAL por lo mismo: a 1,15 radianes (66 grados) el ala se ponia casi
# de canto y no quedaba nada que dibujar. A 0,95 (54 grados) el aleteo se lee igual de bien -- lo que
# lo cuenta es el CAMBIO de anchura, no llegar al extremo -- y el ala nunca desaparece.
const BATE_MAX := 0.95              # radianes que sube el ala a bate = 1

# LA MANCHA DEL ALA: el ocelo. Una mancha clara con el centro oscuro en cada ala delantera. Sin ella
# las cuatro alas son cuatro paletas lisas del mismo tono y el bicho se lee como una mancha; con
# ella se leen como ALAS. Va en la mitad de fuera, que es la parte que siempre se ve.
const OCELO_EN := Vector3(0.58, 0.10, 0.0)   # (fraccion del span, fraccion de la cuerda, -)
const OCELO_R := 2.05
const OCELO_NUCLEO := 0.46

# EL POLVO: las motas que suelta de las alas. Solo en sus animaciones de ataque -- en 'muerte' y
# 'cadaver' NO, porque el horno cuenta trozos sueltos justo en esas dos y unas motas separadas del
# cuerpo son exactamente lo que canta como isla (la leccion del miconido).
const POLVO := 9
const POLVO_R := 0.85

const LUNGE_DIST := 9.0
# ENCAJA MUCHISIMO: 58 de vida y Resistencia 25, lo mas fragil del bloque, y ademas esta en el aire y
# no tiene donde agarrarse. Un golpe la manda de lado como a un papel.
const ENCAJE_RETRO := 0.62

# Lienzo CUADRADO y holgado: gira, y girada en diagonal la envergadura va por la diagonal del cuadro.
# Ademas la muerte la tira al suelo desde 10 unidades de alto. Ajustado contra los avisos del horno.
#
# SUBIDO DE 1,55 A 1,80 porque el horno canto que se salia en 'embestida_3', 'embestida_5' y
# 'walk_3': en las diagonales la envergadura va por la diagonal del cuadro Y ADEMAS la embestida la
# desplaza nueve unidades, y las dos cosas se suman en el mismo sitio. Ampliar el lienzo es casi
# gratis -- el horno recorta cada fotograma a su dibujo y guarda el hueco como margen --, asi que en
# la duda se peca de largo.
const LIENZO_FACTOR := 1.80

# TONOS propios (el motor no sabe que es cada uno; solo mapea indice -> color, ver _colores).
enum Tono { VACIO, SOMBRA_SUELO, BORDE, ALA_OSC, ALA_T, ALA_CLARA, OCELO_T, OCELO_OJO,
	PELO_OSC, PELO, ANTENA_T, OJO_T, POLVO_T }

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
	return "polilla_%s_%.2f" % [col.to_html(false), esc]


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(escala: float = 1.0) -> int:
	return _celdas(escala)


static func dimensiona_por_escala() -> bool:
	return true


# El CUERPO en planta para la colision: SOLO EL CUERPO. LAS ALAS NO CUENTAN -- miden 27 unidades de
# punta a punta, mas que el vano de 32 de un pasillo a su escala, y con ellas la polilla se quedaria
# trabada en cuanto girase. Es la misma decision que la copa del trent, las patas de la araña y las
# alas de la gargola: lo que estorba es el cuerpo, lo demas pasa por encima de las cosas.
static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return Vector2(TORAX_R.x * 2.0,
		(CABEZA.y + CABEZA_R.y) - (CUERPO_Y0 - float(CUERPO_SEGMENTOS - 1) * CUERPO_PASO)) * escala


static func _celdas(escala: float) -> int:
	var lado: int = int(ceil(ANCHO_MUNDO * escala * LIENZO_FACTOR / SpriteLienzo.UNIDADES_POR_CELDA))
	return lado + (lado % 2)      # par, para que el centro caiga limpio


static func generar(color: Color = Color(0.58, 0.50, 0.60), escala: float = 1.0) -> SpriteFrames:
	# cuantizar_hsv y no cuantizar a secas: el lila ceniza es un color apagado y redondear canal a
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
	_montar_aletear(anims, esc)
	_montar_nube(anims, esc)
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
	var p := {"avance": 0.0, "bate": 0.0, "altura": 1.0, "cabeceo": 0.0, "ladea": 0.0,
		"polvo": 0.0, "cae": 0.0, "abre": 0.0}
	for k in campos:
		p[k] = campos[k]
	return p


# EL BATEO, que lo comparten el idle y el andar: sube y baja las alas, y el cuerpo cabecea al reves
# que ellas (cuando las alas bajan, el cuerpo sube). Ese desfase es lo que hace que se lea como que
# el bicho se SOSTIENE en el aire en vez de agitar dos paletas.
static func _bateo(t: float, fuerza: float) -> Dictionary:
	var b: float = sin(TAU * t)
	return {"bate": b * fuerza, "cabeceo": -b * 0.85}


# Quieta: flotando en el sitio. Bate despacio (6 fps) y con poco recorrido, lo justo para sostenerse.
# Aun asi es de las animaciones mas rapidas del juego: una polilla parada sigue moviendo las alas.
static func _montar_idle(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return _pose(_bateo(t, 0.55))
	_montar_animacion(anims, esc, "idle", true, 6.0, pose, false)


# Volando: a 12 fps, de lo mas rapido del juego -- tiene Agilidad 50 y velocidad 5,2, y ademas una
# polilla bate rapidisimo. Recorrido completo y ademas se LADEA de un lado a otro, que es como vuela
# de verdad: a tirones y sin ir recta.
static func _montar_walk(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _bateo(t, 1.0)
		p["ladea"] = 0.55 * sin(TAU * t * 0.5)
		p["altura"] = 1.0 + 0.10 * sin(TAU * t)
		return _pose(p)
	_montar_animacion(anims, esc, "walk", true, 12.0, pose, false)


# EMBESTIDA: se echa atras y SE TIRA de cabeza, con las alas plegadas hacia atras para no frenar.
# No es un lance de bicho pesado: es rapida y ligera, asi que viaja mucho (9 unidades) y vuelve.
static func _montar_embestida(anims: Array, esc: float) -> void:
	var avance_keys := [[0.0, 0.0], [0.30, -1.6], [0.48, 3.2], [0.68, 8.4], [0.84, 9.0], [1.0, 6.0]]
	# Las alas ARRIBA al armar (coge aire) y abajo del todo al lanzarse: es el golpe de ala que la
	# dispara hacia delante.
	var bate_keys := [[0.0, 0.0], [0.30, 1.0], [0.48, -1.0], [0.68, -0.55], [0.84, 0.2], [1.0, 0.0]]
	var cab_keys := [[0.0, 0.0], [0.30, -0.9], [0.48, 1.1], [0.68, 0.6], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		return _pose({"avance": SpriteLienzo.tramos(t, avance_keys) * (LUNGE_DIST / 9.0),
			"bate": SpriteLienzo.tramos(t, bate_keys),
			"cabeceo": SpriteLienzo.tramos(t, cab_keys)})
	_montar_animacion(anims, esc, "embestida", false, 12.0, pose, true)


# ALETEO CEGADOR (fx_anim = "aletear"). "Se te viene a la cara y bate. No pega: te llena los ojos de
# polvo."
#
# TRES BATIDOS SEGUIDOS Y RAPIDOS, sin moverse del sitio, soltando polvo en cada uno. Lo que lo
# separa de la embestida es justo eso: alli el ala bate UNA vez para impulsarse y aqui bate tres para
# echarte el polvo encima. El cuerpo se queda quieto y lo unico que se mueve son las alas.
#
# UNA SOLA DIRECCION: solo se ve en combate, y ahi se le mira de frente (el combate degrada solo a
# "aletear_0", ver combat.gd::_on_gesto_iniciado).
static func _montar_aletear(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		# Tres ciclos completos en los ocho fotogramas.
		var p: Dictionary = _bateo(t * 3.0, 1.0)
		# El polvo entra con el primer batido y ya no para.
		p["polvo"] = clampf(t * 2.4, 0.0, 1.0)
		# Y se echa un pelin hacia delante: "se te viene a la cara".
		p["avance"] = 2.2 * smoothstep(0.0, 0.5, t)
		return _pose(p)
	_montar_animacion(anims, esc, "aletear", false, 14.0, pose, true, 1, FRAMES)


# NUBE DE ESPORAS (fx_anim = "nube"). "Bate las alas una sola vez y el polvo lo tapa todo."
#
# ES LO CONTRARIO DEL ALETEO, y por eso son dos animaciones y no una: alli son tres batidos rapidos y
# aqui es UNO SOLO, enorme y lento. Las alas suben del todo, se quedan arriba un fotograma -- ese
# aguante es lo que hace que se vea venir -- y bajan de golpe soltandolo todo.
#
# Y ADEMAS SE ABREN: 'abre' estira las alas a lo ancho, asi que en el fotograma del golpe la polilla
# es lo mas grande que llega a verse. Es su ataque marca y tiene que ocupar.
static func _montar_nube(anims: Array, esc: float) -> void:
	var bate_keys := [[0.0, 0.0], [0.143, 0.75], [0.286, 1.0], [0.429, 1.0],
		[0.571, -1.0], [0.714, -0.7], [0.857, -0.2], [1.0, 0.0]]
	var abre_keys := [[0.0, 0.0], [0.286, 0.35], [0.429, 0.45], [0.571, 1.0], [0.714, 0.8],
		[1.0, 0.3]]
	# El polvo sale JUSTO en el batido hacia abajo (el 0,571), no antes.
	var polvo_keys := [[0.0, 0.0], [0.429, 0.0], [0.571, 0.55], [0.714, 0.85], [1.0, 1.0]]
	var cab_keys := [[0.0, 0.0], [0.286, -1.1], [0.429, -1.2], [0.571, 1.3], [0.714, 0.6],
		[1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		return _pose({"bate": SpriteLienzo.tramos(t, bate_keys),
			"abre": SpriteLienzo.tramos(t, abre_keys),
			"polvo": SpriteLienzo.tramos(t, polvo_keys),
			"cabeceo": SpriteLienzo.tramos(t, cab_keys)})
	_montar_animacion(anims, esc, "nube", false, 10.0, pose, true, 1, FRAMES)


# ENCAJAR UN GOLPE. Cuatro fotogramas en UNA sola direccion y EMPEZANDO YA GOLPEADA: el frame 0 es el
# impacto, no la pose de reposo.
#
# SALE DESPEDIDA Y SE LADEA, que es lo que le pasa a algo que pesa nada y esta EN EL AIRE: no tiene
# donde agarrarse. Es el encaje mas exagerado del bloque -- el miconido casi no se mueve
# (Resistencia 55) y esta sale volando de lado (Resistencia 25). Esa diferencia dice de un vistazo a
# cual hay que insistirle.
static func _montar_encaje(anims: Array, esc: float) -> void:
	var retro_keys := [[0.0, 1.0], [0.34, 0.45], [0.67, 0.12], [1.0, 0.0]]
	var ladea_keys := [[0.0, 1.6], [0.34, -0.9], [0.67, 0.35], [1.0, 0.0]]
	# Y PIERDE ALTURA con el golpe: se hunde y se recupera. Volando, eso es lo que mas se nota.
	var alt_keys := [[0.0, 0.55], [0.34, 0.80], [0.67, 0.95], [1.0, 1.0]]
	var bate_keys := [[0.0, -0.9], [0.34, 0.9], [0.67, -0.3], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		return _pose({"avance": -SpriteLienzo.tramos(t, retro_keys) * (LUNGE_DIST * ENCAJE_RETRO),
			"ladea": SpriteLienzo.tramos(t, ladea_keys),
			"altura": SpriteLienzo.tramos(t, alt_keys),
			"bate": SpriteLienzo.tramos(t, bate_keys)})
	# LOS BICHOS ENCAJAN A 18 fps: es la duracion que espera CombatFX.T_ENCAJE.
	_montar_animacion(anims, esc, "encaje", false, 18.0, pose, true, 1, 4)


# MORIRSE: SE CAE DEL AIRE. Ocho fotogramas en UNA sola direccion.
#
# ES LA UNICA MUERTE DEL JUEGO QUE ES UNA CAIDA, y se la gana por ser el unico bicho que vuela: las
# alas dan dos aletazos desesperados que ya no la sostienen, pierde altura a tirones y se estrella.
# El ultimo fotograma es lo unico que toca el suelo en toda su vida.
#
# AQUI NO SUELTA POLVO, y da pena pero es a proposito: el horno comprueba trozos sueltos SOLO en
# 'muerte' y 'cadaver', y unas motas separadas del cuerpo son exactamente lo que canta como isla. Es
# la misma renuncia que la bocanada del miconido.
static func _pose_muerte(t: float) -> Dictionary:
	# LA CAIDA ACELERA y va A TIRONES: dos intentos de remontar (el 0,28 y el 0,52) que no sirven de
	# nada. Repartida por igual parecia que se posaba.
	var cae_keys := [[0.0, 0.0], [0.14, 0.10], [0.28, 0.06], [0.45, 0.34],
		[0.62, 0.28], [0.78, 0.72], [0.90, 0.95], [1.0, 1.0]]
	# Los dos aletazos desesperados, cada vez mas flojos, y al final las alas caidas del todo.
	var bate_keys := [[0.0, 0.9], [0.14, -0.8], [0.28, 0.55], [0.45, -0.6], [0.62, 0.25],
		[0.78, -0.9], [1.0, -1.0]]
	# Y se va de lado segun cae: nada que se cae del aire baja recto.
	var ladea_keys := [[0.0, 0.0], [0.28, 0.6], [0.62, 1.2], [0.90, 1.7], [1.0, 1.8]]
	var cab_keys := [[0.0, 0.0], [0.28, 0.8], [0.62, 1.4], [1.0, 1.8]]
	return _pose({"cae": SpriteLienzo.tramos(t, cae_keys),
		"bate": SpriteLienzo.tramos(t, bate_keys),
		"ladea": SpriteLienzo.tramos(t, ladea_keys),
		"cabeceo": SpriteLienzo.tramos(t, cab_keys)})


static func _montar_muerte(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return _pose_muerte(t)
	_montar_animacion(anims, esc, "muerte", false, 11.0, pose, true, 1, 8)


# EL CADAVER DEL MAPA: UN fotograma por CADA UNA de las ocho direcciones, al reves que 'muerte'. En
# el mapa no se ve morir a nadie -- se entra a la sala y la polilla ya esta en el suelo --, pero pudo
# caer mirando a cualquier lado. Es EXACTAMENTE la pose final de la muerte, sacada de la MISMA
# funcion.
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
#
# DOS MATERIALES, como el trent es corteza y fronda: el ALA (lisa, del color de la ficha) y el PELO
# del cuerpo (mas oscuro y calido, que es lo que hace que el bulto de en medio se lea como peludo y
# no como otro trozo de ala).
static func _colores(color: Color) -> Array:
	var c: Color = color
	# El pelo se DERIVA del color y tira a pardo: una polilla tiene el cuerpo mas oscuro y mas terroso
	# que las alas. Derivado y no puesto a pelo, para que una polilla aclarada por su 't' lleve
	# tambien el cuerpo aclarado y no se despareje.
	# EL TONO DEL PELO VA FIJO, no derivado del de las alas, y esto hubo que corregirlo mirando: con
	# 'c.h * 0.35 + 0.06' el lila de la ficha (h 0,83) se mapeaba a h 0,35, que es VERDE. El cuerpo
	# salia con pelusa verde. Un tono no se puede escalar como si fuera un numero: es un angulo, y
	# multiplicarlo lo manda a cualquier parte de la rueda.
	#
	# Se hace como la madera del trent: hue FIJO (pardo) y del color de la ficha se hereda solo el
	# BRILLO, para que una polilla aclarada por su 't' lleve tambien el cuerpo aclarado.
	var pelo: Color = Color.from_hsv(0.07, 0.46, clampf(c.v * 0.72, 0.14, 0.52))
	return [
		Color(0, 0, 0, 0),                        # VACIO
		Color(0, 0, 0, 0.22),                     # SOMBRA_SUELO
		c.darkened(0.74),                         # BORDE
		c.darkened(0.34),                         # ALA_OSC (la mitad de atras, en penumbra)
		c,                                        # ALA_T
		# El ala se aclara HACIA UN LILA FRIO, no hacia el blanco: 'lightened' desatura, y sobre un
		# lila ya apagado el resultado es un gris. Misma leccion que el jabali y la araña.
		c.lerp(Color(0.88, 0.84, 0.92), 0.46),    # ALA_CLARA (el borde de fuera, a la luz)
		# EL OCELO tiene que CANTAR contra el ala o no sirve de nada: es lo unico que rompe la paleta
		# lisa de las cuatro paletas.
		c.lerp(Color(0.96, 0.90, 0.72), 0.62),    # OCELO_T (el anillo claro)
		c.darkened(0.80),                         # OCELO_OJO (el nucleo oscuro del ocelo)
		pelo.darkened(0.32),                      # PELO_OSC
		pelo,                                     # PELO
		pelo.lerp(Color(0.90, 0.86, 0.80), 0.40), # ANTENA_T (las antenas plumosas, claras)
		# LOS OJOS, MUY OSCUROS: son dos bolas negras sobre una cabeza peluda, y ademas son lo unico
		# que dice hacia donde mira -- las cuatro alas son simetricas y no dicen nada.
		Color(0.10, 0.07, 0.11),                  # OJO_T
		Color(0.95, 0.93, 0.88),                  # POLVO_T (casi blanco: las esporas)
	]


# ------------------------------------------------------------
#  GEOMETRIA
# ------------------------------------------------------------

# Una direccion desde el centro de una pieza -> el punto de su superficie, metido 'hunde' hacia
# dentro. Garantiza que ningun adorno flote.
static func _en_la_pieza(dir: Vector3, hunde: float, centro: Vector3, radio: Vector3) -> Vector3:
	var d: Vector3 = dir.normalized()
	return centro + Vector3(radio.x * d.x, radio.y * d.y, radio.z * d.z) - d * hunde


# Las PIEZAS de la polilla para una pose, ya proyectadas a pantalla.
static func _piezas(dir: int, pose: Dictionary, esc: float) -> Array:
	var ang: float = DIR_VECS[dir].angle() - DIR_VECS[0].angle()
	var u: float = esc / SpriteLienzo.UNIDADES_POR_CELDA
	var centro: float = float(_celdas(esc)) * 0.5
	var avance: float = float(pose["avance"])
	var bate: float = float(pose["bate"])
	var ladea: float = float(pose["ladea"])
	var polvo: float = clampf(float(pose["polvo"]), 0.0, 1.0)
	var abre: float = float(pose["abre"])
	var cae: float = clampf(float(pose["cae"]), 0.0, 1.0)

	# LA ALTURA A LA QUE VUELA. 'cae' la lleva a cero (la muerte) y ahi es cuando toca el suelo.
	var alto: float = VUELO_Z * float(pose["altura"]) * (1.0 - cae) + float(pose["cabeceo"]) * CABECEO

	var desp := Vector2(0.0, avance).rotated(ang)

	# TRES CUBOS. La SOMBRA va aparte y debajo de todo; las alas se reparten en las que quedan DETRAS
	# del cuerpo y las que quedan DELANTE, segun donde caiga su raiz en pantalla. Sin ese reparto, de
	# frente las alas de delante desaparecian tras el cuerpo justo cuando mas se ven, y de espaldas se
	# le cruzaban por encima.
	var suelo: Array = []
	var detras: Array = []
	var cuerpo: Array = []
	var delante: Array = []

	# EL ARRAY DESTINO VA COMO PARAMETRO y no capturado: una lambda de GDScript captura por VALOR, asi
	# que reasignar 'destino' fuera de ella no cambiaria a donde escribe y las cuatro alas acabarian
	# en el mismo saco sin dar ningun error.
	var poner := func(dest: Array, local: Vector3, r: Vector3, tono: int,
			solo_sobre: Array = [], en_suelo: bool = false, persp_ov: float = -1.0) -> void:
		var p := Vector2(local.x, local.y)
		var rot: Vector2 = p.rotated(ang) + desp
		var z: float = 0.0 if en_suelo else local.z + alto
		var sx: float = centro + rot.x * u
		var sy: float = centro + (rot.y * SpriteLienzo.COS_CAM - z * SpriteLienzo.SIN_CAM) * u
		dest.append({"pos": Vector2(sx, sy), "radio": Vector2(r.x * u, r.y * u),
			"gira_forma": true, "tono": tono, "ang": ang,
			"persp": 1.0 if en_suelo else (persp_ov if persp_ov > 0.0
				else SpriteLienzo.persp_de(r.y, r.z)),
			"solo_sobre": solo_sobre})

	# 1. LA SOMBRA, EN EL SUELO Y APARTE. Es la pieza mas importante del bicho: la separacion entre
	#    ella y el cuerpo es lo unico que se lee como ALTURA. Y ENCOGE con la altura -- cuanto mas
	#    alto vuela, mas pequeña y mas difusa --, que es lo que convierte esa separacion en distancia
	#    en vez de en "hay dos cosas dibujadas".
	var f_alt: float = clampf(alto / VUELO_Z, 0.0, 1.4)
	var s_esc: float = 1.15 - 0.42 * f_alt
	poner.call(suelo, Vector3.ZERO,
		Vector3(TORAX_R.x * 2.6 * s_esc, TORAX_R.y * 2.2 * s_esc, 0.0),
		Tono.SOMBRA_SUELO, [], true)

	# 2. LAS CUATRO ALAS. Se reparten delante/detras por donde caiga su raiz en PANTALLA una vez
	#    girada -- una prueba de profundidad de verdad, no una tabla por direccion que mantener.
	for s in 2:
		var lado: float = -1.0 if s == 0 else 1.0
		for k in 2:
			var raiz_l: Vector3 = ALA1_RAIZ if k == 0 else ALA2_RAIZ
			var raiz := Vector3(lado * raiz_l.x, raiz_l.y, raiz_l.z)
			# LAS CUATRO ALAS VAN SIEMPRE DETRAS DEL CUERPO, y esto se corrigio mirando: repartidas por
			# profundidad como en los demas bichos, las delanteras se pintaban DESPUES del cuerpo y le
			# tapaban la cabeza, las antenas y el abdomen -- salia una mancha lila con cuatro ocelos y
			# ni rastro del bicho. Una polilla vista desde arriba lleva el cuerpo POR ENCIMA de las
			# alas siempre; no hay ninguna pose en la que un ala le cruce por delante.
			#
			# Lo que si se reparte es el TONO: la que queda al fondo va mas oscura, y eso es lo que
			# separa los dos pares cuando se solapan.
			var det: bool = Vector2(raiz.x, raiz.y).rotated(ang).y <= 0.0
			_ala(poner, detras, raiz, lado, k, bate, abre, ladea,
				Tono.ALA_OSC if det else Tono.ALA_T, det)

	# 3. EL CUERPO: la cadena de bultos peludos, del torax a la cola.
	for i in CUERPO_SEGMENTOS:
		var f: float = float(i) / float(CUERPO_SEGMENTOS - 1)
		var r: Vector3 = TORAX_R.lerp(COLA_R, smoothstep(TORAX_EN, 1.0, f))
		var y: float = CUERPO_Y0 - float(i) * CUERPO_PASO
		var p := Vector3(ladea * 0.30 * f, y, -ladea * 0.20 * f)
		poner.call(cuerpo, p, r, Tono.PELO_OSC)
		# La cresta iluminada de arriba: sin ella el cuerpo es una mancha plana entre dos alas.
		poner.call(cuerpo, Vector3(p.x, p.y, p.z + r.z * 0.34), r * 0.72, Tono.PELO,
			[Tono.PELO_OSC])

	# 4. LA CABEZA y sus ojos.
	var cab := Vector3(ladea * 0.10, CABEZA.y, CABEZA.z)
	poner.call(cuerpo, cab, CABEZA_R, Tono.PELO_OSC)
	poner.call(cuerpo, Vector3(cab.x, cab.y, cab.z + CABEZA_R.z * 0.30), CABEZA_R * 0.74,
		Tono.PELO, [Tono.PELO_OSC])
	# QUIEN LE VE LA CARA: de espaldas no se le ven los ojos -- un bicho que se aleja enseña la nuca,
	# y eso es lo que hace que se lea de un vistazo si viene o si huye. Mismo criterio que el trent.
	for l in [-1.0, 1.0]:
		var d := Vector3(l * OJO_DIR.x, OJO_DIR.y, OJO_DIR.z)
		if Vector2(d.x, d.y).rotated(ang).y > OJO_VISIBLE:
			poner.call(delante, _en_la_pieza(d, OJO_HUNDE, cab, CABEZA_R), OJO_R, Tono.OJO_T)

	# 5. LAS ANTENAS PLUMOSAS, delante y arriba. Son la seña del bicho, asi que van DELANTE de todo.
	#    De espaldas tampoco se ven: salen de la cara.
	if DIR_VECS[dir].y > OJO_VISIBLE:
		for l in [-1.0, 1.0]:
			_antena(poner, delante, cab, l)

	# 6. EL POLVO que sueltan las alas, solo en los ataques (en la muerte no: ver _pose_muerte).
	if polvo > 0.0:
		var g: float = 0.0
		for i in POLVO:
			g = float(i)
			# Sale del borde de las alas y CAE: es polvo, pesa. Repartido por las cuatro puntas.
			var lado2: float = -1.0 if i % 2 == 0 else 1.0
			var f2: float = float(i) / float(POLVO - 1)
			var px: float = lado2 * (ALA1_RAIZ.x + ALA1_LARGO * (0.45 + 0.55 * f2))
			var py: float = ALA1_RAIZ.y - ALA1_CUERDA * (0.20 + 0.55 * sin(g * 2.1))
			var pz: float = -polvo * (2.0 + 5.5 * f2) + sin(g * 1.7) * 1.2
			poner.call(delante, Vector3(px, py, pz),
				Vector3.ONE * POLVO_R * (1.0 - 0.35 * f2), Tono.POLVO_T)

	return suelo + detras + cuerpo + delante


# UN ALA: una membrana rectangular de ALA_SPAN x ALA_CUERDA platos, sin hueso y sin dedos -- una
# paleta lisa, que es exactamente lo que distingue un ala de polilla de una de murcielago.
#
# EL BATEO gira la envergadura en el plano ANCHO-ALTO alrededor de la raiz. Plana (bate = 0) el ala
# se ve entera y ancha; vertical (bate = 1) se ve de canto y estrechisima. Ese cambio de anchura en
# pantalla ES el aleteo: no hace falta mover nada mas.
#
# Y AQUI NO PASA LO DE LA GARGOLA. A ella el ala se le quedaba en el eje ciego de la camara a mitad
# del despliegue, porque interpolaba entre una pose vertical y otra horizontal y la cuerda pasaba por
# (y - z) = 0. Aqui la CUERDA no se mueve nunca: va siempre a lo largo del cuerpo (el eje Y), asi que
# el ala tiene fondo en pantalla en todo momento y lo unico que cambia es su altura.
static func _ala(poner: Callable, dest: Array, raiz: Vector3, lado: float, cual: int,
		bate: float, abre: float, ladea: float, tono: int, detras: bool) -> void:
	var largo: float = (ALA1_LARGO if cual == 0 else ALA2_LARGO) * (1.0 + 0.16 * abre)
	var cuerda: float = (ALA1_CUERDA if cual == 0 else ALA2_CUERDA) * (1.0 + 0.10 * abre)
	var flecha: float = ALA1_FLECHA if cual == 0 else ALA2_FLECHA

	# El angulo del bateo. 'ladea' inclina las dos alas al mismo lado (el bicho se escora); 'bate' las
	# sube o baja en espejo.
	var a: float = bate * BATE_MAX + ladea * 0.22 * lado
	# LA ENVERGADURA NO SALE RECTA DE LADO: la delantera tira hacia delante y la trasera hacia atras,
	# y eso es lo que abre el ASPA de una polilla en vuelo. Rectas las cuatro, el bicho sale como un
	# avion de papel.
	var adelanta: float = ALA1_ADELANTA if cual == 0 else ALA2_ADELANTA
	var span_d := Vector3(lado * cos(a), adelanta, sin(a)).normalized()
	# LA CUERDA VA SIEMPRE POR EL EJE DEL CUERPO. Es lo que evita el eje ciego (ver la cabecera).
	var cuerda_d := Vector3(0.0, -1.0, 0.0)

	var paso_s: float = largo / float(ALA_SPAN - 1)
	var paso_c: float = cuerda / float(ALA_CUERDA - 1)
	# EL PLATO tiene que ser MAS GORDO que el paso de la rejilla o la membrana sale a cuadros: es la
	# misma regla del paso menor que el grosor de las cadenas, pero en dos ejes.
	# Y CON MARGEN: el plato tiene que medir bastante MAS que medio paso o la rejilla se descose. A
	# 0,62 los platos se tocaban justos y al girar el ala aparecian los huecos entre ellos.
	var r_s: float = paso_s * 0.80
	var r_c: float = paso_c * 0.80

	for i in ALA_SPAN:
		var fs: float = float(i) / float(ALA_SPAN - 1)
		# EL PERFIL DEL ALA, que es lo que la referencia corrigio. Un ala de polilla NO se estrecha
		# desde la raiz: es mas ESTRECHA pegada al cuerpo, se ensancha en el primer tercio -- ahi esta
		# su punto mas ancho -- y de ahi se va afilando a la punta. Ese vientre es lo que le da la
		# silueta de triangulo redondeado en vez de la de un remo.
		# ANCHAS Y REDONDAS DE PUNTA A PUNTA. Con las alas abiertas el ala no se afila: mantiene casi
		# toda su cuerda hasta el ultimo cuarto y ahi se redondea. Afilandola desde la mitad salian dos
		# hojas de cuchillo, que es la silueta de una polilla EN REPOSO y no la de una volando.
		var perfil: float = 0.78 + 0.22 * sin(PI * pow(fs, 0.80))
		var ancho_aqui: float = cuerda * perfil * (1.0 - 0.30 * pow(fs, 3.0))
		# Y LA FLECHA, CRECIENDO HACIA LA PUNTA (ver ALA_FLECHA_CURVA).
		var atras: float = flecha * largo * pow(fs, ALA_FLECHA_CURVA)
		for j in ALA_CUERDA:
			var fc: float = float(j) / float(ALA_CUERDA - 1) - 0.5
			var p: Vector3 = raiz + span_d * (paso_s * float(i)) \
				+ cuerda_d * (fc * ancho_aqui) + Vector3(0.0, atras, 0.0)
			# El eje FINO es la normal del ala: plana es fina en ALTURA y vertical es fina a lo ANCHO.
			var fino: float = ALA_GRUESO
			var rx: float = maxf(fino, r_s * absf(cos(a)) + fino * absf(sin(a)))
			var rz: float = maxf(fino, r_s * absf(sin(a)) + fino * absf(cos(a)))
			# EL BORDE DE FUERA, MAS CLARO. Es lo que separa las cuatro paletas unas de otras cuando se
			# solapan, que es casi siempre.
			var t2: int = tono
			if not detras and fs > 0.72:
				t2 = Tono.ALA_CLARA
			poner.call(dest, p, Vector3(rx, r_c, rz), t2)

	# EL OCELO: la mancha del ala delantera. Solo en las grandes y solo si el ala se ve de plano --
	# de canto no hay superficie donde pintarla.
	# EL OCELO VA EN LAS DOS ALAS, no solo en la delantera: en las fotos el gordo esta justo en la
	# TRASERA (la Io, la emperador). Y va grande -- es la mancha que hace que cuatro paletas del mismo
	# tono se lean como alas.
	if absf(cos(a)) > 0.35:
		var fs2: float = OCELO_EN.x
		var oc: Vector3 = raiz + span_d * (largo * fs2) \
			+ cuerda_d * (OCELO_EN.y * cuerda) + Vector3(0.0, flecha * largo * fs2, 0.0)
		var esc_o: float = OCELO_R * absf(cos(a))
		poner.call(dest, oc, Vector3(esc_o, OCELO_R * 0.85, esc_o * 0.5), Tono.OCELO_T,
			[tono, Tono.ALA_CLARA])
		poner.call(dest, oc, Vector3(esc_o * OCELO_NUCLEO, OCELO_R * 0.85 * OCELO_NUCLEO,
			esc_o * 0.5 * OCELO_NUCLEO), Tono.OCELO_OJO, [Tono.OCELO_T])


# UNA ANTENA PLUMOSA: un eje en cadena con barbas cortas a los dos lados. Las barbas son la seña --
# una antena lisa es de escarabajo, no de polilla.
static func _antena(poner: Callable, dest: Array, cab: Vector3, lado: float) -> void:
	for i in ANTENA_SEGMENTOS:
		var f: float = float(i) / float(ANTENA_SEGMENTOS - 1)
		# EN ARCO, no en linea recta: se abren hacia fuera segun suben (el f*f del ancho) y el avance
		# se frena al final. Rectas salian como dos palillos en uve.
		var p := Vector3(
			cab.x + lado * ANTENA_LARGO * (ANTENA_ABRE * f + ANTENA_CURVA * f * f),
			cab.y + ANTENA_LARGO * f * (0.86 - 0.30 * f),
			cab.z + ANTENA_SUBE * ANTENA_LARGO * f - 1.1 * f * f)
		var r: float = lerpf(ANTENA_R0, ANTENA_R1, f)
		poner.call(dest, p, Vector3.ONE * r, Tono.ANTENA_T)
		# Las BARBAS, a partir del primer tramo (de la base no salen).
		if i > 0:
			for l2 in [-1.0, 1.0]:
				poner.call(dest, Vector3(p.x + l2 * BARBA_LARGO * 0.75, p.y - BARBA_LARGO * 0.35,
					p.z + BARBA_LARGO * 0.30), Vector3.ONE * BARBA_R, Tono.ANTENA_T)


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
