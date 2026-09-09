# ============================================================
#  chillon_sprites.gd  (class_name ChillonSprites)
#  El CHILLON DE LAS SIMAS (pisos 8-12) dibujado por codigo. Solo geometria: el motor esta en
#  SpriteLienzo y quien reparte los generadores es SpritesEnemigo (por NOMBRE).
#
#  Hasta hoy se dibujaba con el generador de la GARGOLA, o sea que un murcielago salia como una
#  estatua de basalto agazapada. Y no era un despiste: la gargola era lo unico con alas membranosas
#  que habia para prestarle.
#
#  DE LA GARGOLA SE COPIA EL ALA Y NADA MAS -- la rejilla de platos, el hueso arqueado del borde de
#  ataque, los dedos que salen de la muñeca --, y ahi hay una ironia util: sus propios comentarios
#  dicen que ESO es justo lo que hace que un ala se lea como de murcielago y no de polilla. Lo que
#  alli era un adorno para que la estatua no pareciera una mariposa, aqui es el bicho entero.
#
#  Y SE TIRA TODO LO DEMAS:
#  - NO SE POSA NUNCA. Vuela siempre, como la polilla: el cuerpo va despegado del suelo y la sombra
#    se queda abajo, y esa separacion es lo unico que se lee como altura. La gargola tiene patas de
#    rapaz y esta las lleva encogidas atras, que es lo que hacen en el aire.
#  - EL ALA NO SE PLIEGA, BATE. Asi que aqui no existe el eje ciego de la camara que a la gargola le
#    convertia el ala en un palo a mitad del despliegue: no hay dos poses que interpolar, hay una
#    sola que sube y baja.
#  - ES CIEGO Y NO TIENE OJOS QUE DIBUJAR. Toda la cara la cuentan otras tres cosas: las OREJAS
#    ENORMES, la HOJA NASAL y los PALETOS. Ver el bloque de LA CARA mas abajo, que es la decision de
#    diseño de este bicho.
#
#  SUS DOS HABILIDADES ESTAN DIBUJADAS:
#  - "Picado": sube, se queda un instante arriba y se deja caer con la boca por delante. Es la
#    embestida.
#  - "Chillido": se para en el aire, se yergue y abre la boca de par en par. La QUIETUD es el gesto,
#    igual que la mirada de la gargola: todo lo demas de este bicho se agita sin parar.
#
#  MUERE CAYENDO, y es el unico del juego que lo hace: los demas ya estan en el suelo cuando les
#  toca. Se le apagan las alas, pierde altura acelerando y se estampa hecho un guiñapo.
# ============================================================

extends RefCounted
class_name ChillonSprites

const FRAMES := 8

# --- El chillon mirando al SUR, en unidades de MUNDO (origen = el punto del SUELO sobre el que
# vuela, +Y hacia donde mira, +Z hacia arriba). A escala 1.0 mide unas 26 unidades de punta a punta
# de ala. ---
const ANCHO_MUNDO := 26.0

# A QUE ALTURA VUELA. Alto de verdad: es lo que lo separa de su sombra, y esa separacion es TODO lo
# que se lee como volar (subir el dibujo sin mas se lee como que el bicho ha crecido).
const VUELO_Z := 12.0
const CABECEO := 0.95              # cuanto sube y baja en cada bateo

# EL CUERPO: una cadena corta de bultos peludos, del pecho a la grupa. Va casi todo tapado por las
# alas -- en un murcielago de verdad tambien --, asi que de el solo tiene que leerse el bulto que
# cuelga entre las dos membranas.
#
# Y VA COLGADO POR DEBAJO DEL PLANO DE LAS ALAS, tres unidades mas abajo que la raiz del ala. Eso NO
# es un detalle anatomico, es lo que hace legible al bicho entero: con la camara a 45 grados un
# murcielago volando es una cosa PLANA Y HORIZONTAL, o sea que todo el -- alas, cuerpo, cola -- se
# proyecta sobre la misma banda de pixeles y el dibujo sale amontonado. Separandolos en altura, las
# alas ocupan una franja y el cuerpo cuelga en la de abajo, que es ademas lo que se ve en las fotos.
const CUERPO_SEGMENTOS := 5
const CUERPO_Y0 := 2.9             # el segmento mas adelantado, pegado a la cabeza
const CUERPO_PASO := 1.75
const CUERPO_CAE := 0.25           # cuanto baja cada segmento hacia la grupa
const CUERPO_Z := VUELO_Z - 1.5
const PECHO_R := Vector3(3.40, 2.90, 2.90)
const GRUPA_R := Vector3(1.60, 1.70, 1.60)
const TORAX_EN := 0.30             # que fraccion del cuerpo es el torax gordo

# CABEZA. Va ADELANTADA Y ALGO MAS BAJA que el lomo, que es como la lleva un murcielago en el aire.
#
# Y ESO ULTIMO NO ES DIBUJO, ES LA CUENTA DE LA CAMARA: a 45 grados la altura en pantalla sale de
# (y - z), asi que adelantar la cabeza la BAJA y subirla la SUBE. Con la cabeza a la altura del lomo
# las dos cosas se anulan y se dibuja DENTRO del pecho -- el fallo que la gargola dejo escrito. Aqui
# la diferencia es (5.5 - 11.3) contra (2.9 - 12.0), o sea 3,3 unidades = 2,3 de pantalla, y el
# morro añade otras 2,4 por delante.
#
# LA CUENTA, HECHA Y NO TANTEADA: hace falta que (y - z) de la cabeza y del pecho se separen MAS que
# el radio de la cabeza en pantalla. Al primer intento eran -5,8 y -9,1, o sea 3,3 unidades = 2,8
# celdas contra 2,5 de radio: la cabeza se dibujaba pegada al pecho y no habia cara que ver. Ahora
# son -3,2 y -9,1, o sea 5,9 unidades = 5,1 celdas, y asoma entera por delante.
const CABEZA := Vector3(0.0, 6.2, VUELO_Z - 3.0)
const CABEZA_R := Vector3(2.60, 2.40, 2.30)
const CABEZA_ANCLA_R := Vector3(2.40, 2.40, 2.30)
# EL MORRO: corto y romo, no un hocico. Sobresale por delante y por debajo, y es donde se cuelgan la
# hoja nasal y la boca.
const MORRO := Vector3(0.0, 7.7, VUELO_Z - 4.3)
const MORRO_R := Vector3(1.35, 1.40, 1.20)

# ============================================================
#  LA CARA DE UN BICHO SIN OJOS
# ============================================================
# ES CIEGO: no hay ojos que dibujar, y los ojos son lo que en todos los demas bichos dice donde esta
# la cara y hacia donde mira. Aqui ese trabajo lo reparten tres piezas, y por eso las tres van
# GRANDES y con tono propio -- si alguna se queda discreta, la cabeza vuelve a ser una bola de pelo.
#
# 1. LAS OREJAS, lo primero que se ve. Enormes de verdad (6,8 unidades, mas de la mitad del largo
#    del cuerpo) y hacia ARRIBA Y ATRAS. Y ojo con eso ultimo: atras SUBE en pantalla igual que
#    arriba, asi que las dos contribuciones se suman y las orejas se disparan por encima de la
#    cabeza. Aqui eso va A FAVOR (es lo que se quiere que cante), pero es la misma cuenta que a la
#    gargola le convirtio la cola en una antena.
#    Y VAN CASI VERTICALES, apenas echadas hacia atras. En las fotos de un orejudo las palas salen
#    de lo alto de la cabeza hacia ARRIBA y se abren un poco hacia fuera; inclinarlas hacia atras las
#    dispara el doble en pantalla (atras sube tanto como arriba) y acaban leyendose como dos cuernos
#    de ciervo por encima del bicho.
#    Y CUIDADO CON EL LARGO, QUE EN PANTALLA SE DISPARA: una oreja que sube 6,8 unidades y ademas se
#    va hacia atras recorre MAS que eso en pantalla (las dos cosas suman en (y - z)). A 6,8 las dos
#    orejas eran la mancha mas grande del dibujo -- mas que las alas -- y el bicho se leia como una
#    V clara con dos trapos oscuros a los lados. 4,6 sigue siendo "enormes" para una cabeza de 4 de
#    ancho, que es lo que se pidio, sin comerse la silueta.
#    Y SEPARADAS: dos manchas claras que se tocan se leen como UNA (la leccion de los ojos de la
#    araña y del golem, aqui con las orejas). Naciendo a 1,15 del eje y midiendo 2,05 de ancho se
#    solapaban en el centro y las dos juntas salian como un escudo claro encima de la cabeza -- la
#    mancha mas grande del bicho, y ni siquiera se leia como dos cosas.
const OREJA_BASE := Vector3(1.70, 5.7, VUELO_Z - 1.8)
const OREJA_SEGMENTOS := 8
const OREJA_LARGO := 3.6
const OREJA_DIR := Vector3(0.30, -0.18, 0.94)   # afuera, algo atras y ARRIBA (la X va por lado)
const OREJA_ABRE := 0.14           # cuanto se separan una de otra hacia la punta
# LARGAS Y ESTRECHAS, no palas. A 1,60 de ancho por 4,6 de largo las dos orejas se leian como un
# babero claro alrededor de la cabeza; una oreja de orejudo es casi el doble de larga que de ancha.
const OREJA_RX0 := 1.30            # ancha en la base
const OREJA_RX1 := 1.25            # y NO MENOS de 1,25: por debajo el contorno se come la punta
const OREJA_FINO := 0.85           # el eje fino (es una pala, no un cuerno)
const OREJA_RZ0 := 1.35
const OREJA_RZ1 := 1.00
# LAS OREJAS SE MUEVEN, y es lo unico que le queda para "mirar": las orienta hacia delante cuando
# chilla y las echa atras cuando pica. Un ciego apunta con las orejas.
const OREJA_GIRA := 0.55

# 2. LA HOJA NASAL: la lamina de piel vertical sobre el morro. Es LA seña de un murcielago de nariz
#    foliacea y ademas es lo que le pone un centro a la cara donde no hay ojos. Va en el tono mas
#    claro del bicho a proposito.
#    Es una RODAJA FINA (0,60 en Y contra 1,55 en Z), asi que HEREDA LA PERSPECTIVA DEL MORRO: su
#    propia cuenta saldria disparada y de perfil se dibujaria varias veces mas alta de lo que mide
#    (ver la nota de 'poner').
const NARIZ := Vector3(0.0, 8.4, VUELO_Z - 4.0)
const NARIZ_R := Vector3(1.30, 0.60, 1.55)

# 3. LOS PALETOS. El "Picado" pide MORDISCO (fx_estilo 14), que son dos hileras de dientes de
#    roedor, y el bicho tiene que enseñar de donde salen. La boca se abre en el chillido y en el
#    momento del mordisco.
const BOCA := Vector3(0.0, 8.0, VUELO_Z - 5.4)
const BOCA_R := Vector3(1.15, 0.85, 0.55)
const BOCA_ABRE := 1.45            # cuanto crece hacia abajo con la boca abierta
# Los dientes van 'solo_sobre' la boca -- se pintan DENTRO de ella --, y por eso pueden bajar de las
# tres celdas de la regla: el contorno no los toca. Es el mismo recurso que los dedos del ala.
const DIENTE_X := 0.52
const DIENTE_R := 0.45

# DE ESPALDAS NO SE LE VE LA CARA. Un bicho que se aleja enseña la nuca, y eso es lo que hace que se
# lea de un vistazo si viene o si huye.
const CARA_VISIBLE := -0.35

# LAS PATAS: ESTIRADAS HACIA ATRAS, no encogidas. Es lo que enseñan las fotos de uno volando -- las
# lleva tendidas en linea con el cuerpo, y las garras asoman por FUERA del borde de la membrana --,
# y ademas es lo que hace que la silueta acabe en punta por detras en vez de en un muñon.
const CADERA := Vector3(1.35, -3.6, VUELO_Z - 2.1)
const PATA_SEGMENTOS := 5
const PATA_LARGO := 4.2
const PATA_DIR := Vector3(0.34, -0.90, -0.28)
const PATA_R0 := 1.45
const PATA_R1 := 1.25          # >= 1,25 unidades: por debajo el contorno se come la pata entera
# EL PIE va de una pieza y en el tono de las garras. NO se dibujan los dedos uno a uno: a este
# tamaño una garra suelta no llega a tres celdas de ancho y el contorno se la come entera.
const PIE_R := 1.30

# EL UROPATAGIO: la membrana entre las patas. Es la tercera seña del bicho (con las orejas y la
# nariz) y ademas cierra la silueta por detras, que si no se queda en dos alas y un bulto. LLEGA
# HASTA LOS TOBILLOS: en las fotos la membrana va tensada entre las dos patas estiradas, asi que su
# largo tiene que dar para alcanzarlas.
const UROPATAGIO := Vector3(0.0, -5.8, VUELO_Z - 5.0)
const UROPATAGIO_R := Vector3(2.60, 3.00, 0.55)

# ============================================================
#  LAS ALAS
# ============================================================
# La tecnica es la de la gargola y esta explicada alli: una membrana es ancha en dos ejes y finisima
# en el tercero, asi que se dibuja como una rejilla de platos aplastados -- 'span' a lo largo del
# hueso y 'cuerda' de delante a atras -- y no como bolas, que darian un churro.
#
# LO QUE CAMBIA ES QUE AQUI EL ALA NO SE PLIEGA, BATE. Y eso quita de un plumazo la trampa mas gorda
# de la gargola: alli el ala pasaba de plano vertical a plano casi horizontal, y a mitad de camino
# la cuerda quedaba con (y - z) = 0, o sea justo en el eje ciego de la camara, y la membrana entera
# colapsaba sobre el borde de ataque. Aqui la cuerda apunta SIEMPRE hacia atras y algo abajo, asi que
# su (y - z) se mueve entre -0,59 y -0,89 y no pasa por cero en ningun momento del bateo.
#
# EL BATEO va en 'bate' (-1 abajo del todo, 0 plano, +1 arriba del todo) y mueve tres cosas a la vez:
# la direccion del hueso, la caida de la membrana y CUAL de los radios es el fino (arriba el ala se
# pone casi vertical y pasa a verse de canto). Ese cambio de ancho en pantalla ES el aleteo.
#
# LA RAIZ VA EN EL COSTADO, NO EN EL LOMO. En las fotos el ala sale del flanco, a la altura del
# hombro, y la membrana baja pegada al cuerpo hasta el tobillo; naciendo del lomo el bicho sale con
# las alas puestas encima como una mochila.
const ALA_RAIZ := Vector3(2.2, 1.6, VUELO_Z + 0.8)
const ALA_SPAN := 7                # platos a lo largo del hueso
const ALA_CUERDA := 5              # platos de delante a atras
const ALA_LARGO := 14.0            # envergadura de UN ala
# LO ANCHA QUE ES LA MEMBRANA, y va GENEROSA porque la camara se la come: la cuerda avanza por la Y,
# que se comprime a cos45, mientras que la envergadura va por la X, que no se comprime nada. Con 7,6
# el ala salia como una cinta -- 5,4 unidades de pantalla contra 28,8 de envergadura -- y en las
# fotos es justo al reves, la membrana es lo ancho del bicho.
const ALA_CUERDA_MAX := 11.0
# DONDE CAE EL CENTRO DE LA MEMBRANA respecto a la raiz, en Y. NO es dibujo: es lo que decide si el
# ala se pinta ANTES o DESPUES del cuerpo.
#
# La prueba de profundidad se hacia sobre la RAIZ, que va adelantada (1,6) para que el ala nazca del
# hombro -- y con eso las dos alas daban "delante" mirando al sur y le tapaban al bicho la cabeza,
# las orejas y la nariz. O sea justo la cara, que en un bicho ciego es toda la decision de diseño.
# La membrana no esta donde nace: pesa hacia ATRAS (la cuerda va en -Y), asi que su centro cae detras
# del cuerpo y el ala tiene que pintarse por debajo de el. De espaldas la cuenta se da la vuelta sola
# y las alas vuelven a taparlo, que es lo que se ve de verdad por detras.
const ALA_CENTRO_Y := -4.0
const ALA_GRUESO := 0.62           # el eje fino: piel, no la piedra de la gargola
# CUANTO SE ENCOGE EL ALA al desmadejarse (solo la muerte). Un ala muerta no se queda extendida.
const ALA_ENCOGE := 0.30

# LOS DEDOS: los radios que van de la muñeca al borde de salida. Son LA SEÑA de un ala de
# murcielago, y sin ellos la membrana es una paleta lisa -- que es exactamente el ala de una
# polilla. Aqui van CUATRO (los cuatro dedos alares) y no tres como en la gargola.
const ALA_DEDOS := 3
const ALA_MUNECA := 0.45           # de donde salen, en fraccion del hueso
# EL PASO MENOR QUE EL GROSOR, LA REGLA DE SIEMPRE, Y AQUI SE ROMPIO POR LO LARGO QUE ES EL DEDO: con
# 6 segmentos para recorrer 10 unidades el paso salia a 2,0 contra un radio de 0,58, o sea que los
# dedos no eran lineas sino PUNTOS SUELTOS salpicados por la membrana -- el ala se veia como un
# damero. Son muchos segmentos porque el dedo es largo, no porque haga falta detalle.
const DEDO_SEGMENTOS := 14
# FINOS: son nervios dentro de la membrana, no varillas. A 0,58 (1,4 celdas de grueso) los cuatro
# dedos se comian la mitad del ala y lo que quedaba claro eran retales sueltos entre ellos.
const DEDO_R := 0.42
# EL HUESO DEL BORDE DE ATAQUE VA APARTE Y FINO. Antes era el primer plato de la cuerda pintado en
# oscuro, y como ese plato mide lo mismo que los de la membrana (3,3 unidades a lo ancho), el borde
# de ataque salia como una BANDA NEGRA de ocho celdas que se comia el ala por delante. Un hueso es
# fino: una cadena propia con su radio.
const HUESO_R := 0.85
const HUESO_SUBPASOS := 3          # puntos intermedios entre plato y plato, o la cadena se descose
# EL PULGAR: el garfio de la muñeca, con el que se cuelga del techo. Es lo que impide que el codo del
# ala sea un recodo liso.
const PULGAR_R := 1.05

const DETRAS_ESC := 0.88
const LUNGE_DIST := 12.0
# Encaja MUCHISIMO: 48 de vida y Agilidad 60. Es un trapo, y el retroceso es lo que lo dice.
const ENCAJE_RETRO := 0.55

# --- EL LIENZO, en multiplos del ancho del cuerpo. RECTANGULAR y con el origen ALTO: el bicho vive
# muy por encima de su origen (que es el punto del SUELO sobre el que vuela).
#
# EL ANCHO ES EL CASO PEOR Y HAY QUE HACERLE LA CUENTA, NO TANTEARLA: la envergadura son 2 x (1,9 +
# 12,5) = 28,8 unidades, y la X NO se comprime nada con la camara a 45 grados (la Y si, a cos45). O
# sea que mirando al SUR el dibujo pide 28,8 unidades de ancho a pelo, mas lo que se desplaza en la
# embestida (12) y lo que se va hacia el lado al caer muerto.
# Ampliar un lienzo es casi gratis: el horno recorta cada fotograma a su dibujo y guarda el hueco
# como margen.
#
# Y EL QUE MANDA ES EL CADAVER, no el bicho volando: al caer al suelo y volcar de costado, la
# envergadura -- que es su medida mas grande con diferencia -- pasa a contarse en VERTICAL, y ademas
# el cuerpo entero baja las doce unidades que estaba volando. Con 0,70 por debajo, el horno cantaba
# que 'cadaver_0', 'cadaver_1' y 'cadaver_7' se salian.
const LIENZO_ANCHO := 2.50
const LIENZO_ARRIBA := 1.35
const LIENZO_ABAJO := 1.15

# TONOS propios (el motor no sabe que es cada uno; solo mapea indice -> color, ver _colores).
enum Tono { VACIO, SOMBRA_SUELO, BORDE, MEMBRANA_OSC, MEMBRANA, DEDO_OSC, DEDO,
	PELO_OSC, PELO, PELO_CLARO, OREJA_OSC, OREJA, NARIZ_T, BOCA_OSC, DIENTE_T, GARRA_T, APAGADO }

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
	return "chillon_%s_%.2f" % [col.to_html(false), esc]


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(escala: float = 1.0) -> int:
	return _lienzo(escala).x


static func dimensiona_por_escala() -> bool:
	return true


# El CUERPO en planta (ancho, largo). LAS ALAS NO CUENTAN, igual que en la gargola y por lo mismo:
# abiertas miden 28,8 unidades de punta a punta y con ellas dentro el bicho se quedaria trabado en
# cualquier esquina. Fuera, las puntas asoman por encima de la roca y ocupa mucho mas de lo que
# estorba, que es lo que tiene que parecer un volador.
static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	var ancho: float = maxf(PECHO_R.x, CADERA.x + PATA_R0) * 2.0
	var largo: float = (MORRO.y + MORRO_R.y) - (UROPATAGIO.y - UROPATAGIO_R.y)
	return Vector2(ancho, largo) * escala


static func _lienzo(escala: float) -> Vector2i:
	var u: float = ANCHO_MUNDO * escala / SpriteLienzo.UNIDADES_POR_CELDA
	var w: int = int(ceil(u * LIENZO_ANCHO))
	var h: int = int(ceil(u * (LIENZO_ARRIBA + LIENZO_ABAJO)))
	return Vector2i(w + (w % 2), h + (h % 2))


static func _origen(escala: float) -> Vector2:
	var l: Vector2i = _lienzo(escala)
	return Vector2(float(l.x) * 0.5, float(l.y) * LIENZO_ARRIBA / (LIENZO_ARRIBA + LIENZO_ABAJO))


static func generar(color: Color = Color(0.42, 0.48, 0.55), escala: float = 1.0) -> SpriteFrames:
	# cuantizar_hsv y no cuantizar a secas: el gris azulado de la ficha es un color apagado, y a esos
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
	_montar_chillido(anims, esc)
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
	return {"bate": 0.0, "vuela": 0.0, "avance": 0.0, "mece": 0.0, "balanceo": 0.0,
		"cabeza": 0.0, "boca": 0.0, "orejas": 0.0, "patas": 0.0, "encara": 0.0,
		"cae": 0.0, "tumba": 0.0, "apoyo": 0.0, "rumbo": 0.0}


# QUIETO: revolotea en el sitio. Bateo CORTO Y NERVIOSO y el cuerpo medio ERGUIDO, que es como se
# sostiene un murcielago sin avanzar. Eso ultimo ('encara') es justo lo que lo separa del 'walk', que
# lleva el mismo bateo: sin ello las dos animaciones se parecerian demasiado.
static func _montar_idle(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["bate"] = 0.62 * sin(TAU * t)
		# El cuerpo sube cuando el ala BAJA (el empuje va medio ciclo por detras del ala).
		p["vuela"] = CABECEO * 0.75 * sin(TAU * t - 1.9)
		p["encara"] = 0.55
		p["cabeza"] = 0.14 * sin(TAU * t * 0.5)
		p["orejas"] = 0.10 * sin(TAU * t * 0.5 + 1.0)
		p["patas"] = 0.15 * sin(TAU * t)
		return p
	_montar_animacion(anims, esc, "idle", true, 9.0, pose, false)


# EN MARCHA: el mismo bateo pero AMPLIO y con el cuerpo tendido hacia delante ('encara' a cero).
# Tiene velocidad 6,0 y Agilidad 60 -- es el bicho mas rapido del bloque --, asi que va a 14 fps.
static func _montar_walk(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["bate"] = sin(TAU * t)
		p["vuela"] = CABECEO * sin(TAU * t - 1.9)
		p["mece"] = 0.5 * sin(TAU * t - 1.9)
		p["balanceo"] = 0.35 * sin(TAU * t * 0.5)
		p["cabeza"] = 0.10 * sin(TAU * t * 0.5)
		p["orejas"] = -0.25          # echadas atras: va lanzado
		p["patas"] = 0.30 * sin(TAU * t)
		return p
	_montar_animacion(anims, esc, "walk", true, 14.0, pose, false)


# LA EMBESTIDA ES SU "PICADO", y su descripcion manda el reparto de los ocho fotogramas: "cae desde
# el techo sin que lo oigas venir, muerde una vez y ya esta otra vez arriba".
#
# O sea TRES tiempos, y el que no puede faltar es el ULTIMO: sube (0 -> 0,30), se deja caer encima
# con la boca abierta (0,30 -> 0,62) y VUELVE A SUBIR (0,62 -> 1,0). Los demas bichos acaban su
# embestida donde la empezaron; este acaba mas alto de donde salio, que es lo que promete la ficha.
#
# Y AL PICAR NO BATE: pliega las alas y se deja caer. Un aleteo mientras cae diria justo lo
# contrario de lo que hace.
static func _montar_embestida(anims: Array, esc: float) -> void:
	var vuela_keys := [[0.0, 0.0], [0.16, 4.2], [0.30, 6.4], [0.44, 1.0], [0.62, -3.4],
		[0.78, 1.6], [1.0, 4.6]]
	var avance_keys := [[0.0, 0.0], [0.16, -1.8], [0.30, -2.4], [0.44, 4.0], [0.62, 11.0],
		[0.78, 8.0], [1.0, 5.4]]
	# Arriba las alas se levantan del todo; al caer se pliegan (bate alto y QUIETO, no oscilando).
	var bate_keys := [[0.0, 0.0], [0.16, -0.9], [0.30, 0.95], [0.44, 0.80], [0.62, 0.55],
		[0.78, -0.85], [1.0, 0.30]]
	# La boca solo se abre en el golpe. Antes y despues, cerrada.
	var boca_keys := [[0.0, 0.0], [0.30, 0.15], [0.44, 0.70], [0.62, 1.0], [0.78, 0.35], [1.0, 0.0]]
	var mece_keys := [[0.0, 0.0], [0.30, -0.8], [0.44, 0.9], [0.62, 1.7], [0.78, 0.2], [1.0, -0.4]]
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["vuela"] = SpriteLienzo.tramos(t, vuela_keys)
		p["avance"] = SpriteLienzo.tramos(t, avance_keys) * (LUNGE_DIST / 11.0)
		p["bate"] = SpriteLienzo.tramos(t, bate_keys)
		p["boca"] = SpriteLienzo.tramos(t, boca_keys)
		p["mece"] = SpriteLienzo.tramos(t, mece_keys)
		# Se yergue para subir y se tiende del todo para caer: es la misma clave que separa el idle
		# del walk, usada aqui para contar el picado.
		p["encara"] = 0.70 * clampf(1.0 - t * 3.2, 0.0, 1.0)
		p["orejas"] = -0.55 * clampf(t * 2.5, 0.0, 1.0)   # las echa atras al lanzarse
		p["patas"] = 0.55 * SpriteLienzo.tramos(t, boca_keys)
		return p
	_montar_animacion(anims, esc, "embestida", false, 12.0, pose, true)


# EL CHILLIDO: se para en el aire, se yergue del todo y abre la boca de par en par.
#
# ES LO CONTRARIO DE SU PICADO y ese contraste es todo lo que hay que acertar: alli se lanza, aqui NO
# se mueve del sitio ('avance' y 'vuela' se quedan casi a cero en toda la animacion).
#
# Y SE QUEDA QUIETO EN MEDIO (0,571 a 0,714 con los mismos valores). La quietud ES el gesto: este
# bicho no para nunca -- bate ocho veces por segundo en su propio idle --, asi que dos fotogramas
# identicos seguidos se leen como que se ha detenido en seco. Es el recurso de la "Mirada petrea" de
# la gargola, y aqui vale por lo mismo aunque los dos bichos no se parezcan en nada.
#
# LAS OREJAS SE VAN HACIA DELANTE. En un bicho sin ojos es lo unico que puede hacer de "mirada": se
# yergue, apunta las orejas hacia ti y grita.
static func _montar_chillido(anims: Array, esc: float) -> void:
	var boca_keys := [[0.0, 0.0], [0.143, 0.20], [0.286, 0.85], [0.429, 1.0], [0.571, 1.0],
		[0.714, 1.0], [0.857, 0.55], [1.0, 0.10]]
	var orejas_keys := [[0.0, 0.0], [0.143, 0.35], [0.286, 0.85], [0.429, 1.0], [0.571, 1.0],
		[0.714, 1.0], [0.857, 0.60], [1.0, 0.15]]
	# Se encoge un instante antes de erguirse: sin ese valle, estirarse no tiene de donde salir.
	var encara_keys := [[0.0, 0.35], [0.143, 0.20], [0.286, 0.80], [0.429, 0.95], [0.571, 0.95],
		[0.714, 0.95], [0.857, 0.70], [1.0, 0.45]]
	# El bateo se PARA: aletea para frenar y luego se sostiene con las alas casi inmoviles.
	var bate_keys := [[0.0, -0.70], [0.143, 0.60], [0.286, 0.30], [0.429, 0.18], [0.571, 0.18],
		[0.714, 0.18], [0.857, 0.40], [1.0, -0.30]]
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["boca"] = SpriteLienzo.tramos(t, boca_keys)
		p["orejas"] = SpriteLienzo.tramos(t, orejas_keys)
		p["encara"] = SpriteLienzo.tramos(t, encara_keys)
		p["bate"] = SpriteLienzo.tramos(t, bate_keys)
		p["vuela"] = 0.8 * SpriteLienzo.tramos(t, encara_keys)
		p["cabeza"] = -0.20 * SpriteLienzo.tramos(t, boca_keys)
		p["patas"] = 0.45 * SpriteLienzo.tramos(t, encara_keys)
		return p
	# UNA SOLA DIRECCION: solo se ve en la pantalla de combate, y ahi se le mira de frente. El combate
	# cae a "chillido_0" cuando la direccion que toca no existe (ver combat.gd:_on_gesto_iniciado).
	_montar_animacion(anims, esc, "chillido", false, 8.0, pose, true, 1, FRAMES)


# ENCAJAR UN GOLPE. Cuatro fotogramas en UNA direccion y EMPEZANDO YA GOLPEADO: el frame 0 es el
# impacto. Un golpe no tiene anticipacion, y con cuatro marcos un fotograma de espera se comeria la
# animacion entera.
#
# SALE DESPEDIDO Y SE DESCOMPONE, que es lo propio de un bicho de 48 de vida: las alas se le van a
# destiempo (una arriba y la otra bajando) y pierde altura de golpe. Un constructo encaja tieso;
# este es un trapo.
static func _montar_encaje(anims: Array, esc: float) -> void:
	var retro_keys := [[0.0, 1.0], [0.34, 0.45], [0.67, 0.14], [1.0, 0.0]]
	var mece_keys := [[0.0, -2.1], [0.34, 1.1], [0.67, -0.40], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["avance"] = -SpriteLienzo.tramos(t, retro_keys) * (LUNGE_DIST * ENCAJE_RETRO)
		p["mece"] = SpriteLienzo.tramos(t, mece_keys)
		p["balanceo"] = SpriteLienzo.tramos(t, mece_keys) * 0.5
		p["bate"] = 0.95 - 1.7 * SpriteLienzo.tramos(t, retro_keys)
		p["vuela"] = -2.6 * SpriteLienzo.tramos(t, retro_keys)
		p["cabeza"] = SpriteLienzo.tramos(t, mece_keys) * 0.35
		p["boca"] = 0.55 * SpriteLienzo.tramos(t, retro_keys)
		p["orejas"] = -0.8 * SpriteLienzo.tramos(t, retro_keys)
		p["encara"] = 0.30
		return p
	# LOS BICHOS ENCAJAN A 18 fps: es la duracion que espera CombatFX.T_ENCAJE.
	_montar_animacion(anims, esc, "encaje", false, 18.0, pose, true, 1, 4)


# MORIRSE. OCHO fotogramas en UNA sola direccion: la muerte solo se ve en la pantalla de combate, y
# ahi al bicho se le mira siempre de frente. Para el mapa esta 'cadaver'.
#
# ES EL UNICO DEL JUEGO QUE MUERE CAYENDO. Todos los demas ya estan en el suelo cuando les toca, asi
# que su muerte es doblarse, enroscarse o desplomarse en el sitio; este tiene que RECORRER las doce
# unidades que lo separan del suelo, y ese recorrido es la animacion entera.
#
# Tres cosas la hacen leerse como una caida y no como un aterrizaje:
# 1. LAS ALAS SE APAGAN LO PRIMERO. Un aleteo mas y estaria vivo.
# 2. LA CAIDA ACELERA. Apenas pierde altura en el primer tercio -- se queda colgado, sin fuerza -- y
#    luego se va de golpe, porque lo que lo tira es su propio peso.
# 3. SE ESTAMPA Y SE QUEDA. No rebota ni se asienta: llega al suelo y se para en seco, de costado y
#    con las alas desmadejadas por encima.
static func _pose_muerte(t: float) -> Dictionary:
	# La altura: de VUELO_Z al suelo, acelerando. El ultimo tramo es casi todo el recorrido.
	var caida_keys := [[0.0, 0.0], [0.14, -0.6], [0.30, -1.8], [0.48, -4.2],
		[0.66, -7.6], [0.82, -11.2], [1.0, -VUELO_Z]]
	# 'cae' desmadeja el ala: se encoge y deja de tener forma.
	var cae_keys := [[0.0, 0.15], [0.14, 0.55], [0.30, 0.80], [1.0, 1.0]]
	# Vuelca de costado, y solo cuando ya esta abajo: volcar en el aire seria una pirueta.
	var tumba_keys := [[0.0, 0.0], [0.30, 0.06], [0.48, 0.20], [0.66, 0.52], [0.82, 0.88], [1.0, 1.0]]
	var rumbo_keys := [[0.0, 0.0], [0.14, 0.10], [0.48, 0.50], [0.82, 0.78], [1.0, 0.80]]
	# El apoyo lo levanta mientras rueda, para que gire SOBRE el suelo y no dentro de el.
	var apoyo_keys := [[0.0, 0.0], [0.48, 0.6], [0.66, 1.6], [0.82, 2.6], [1.0, 2.8]]
	# Un ultimo aleteo que no llega a nada, y despues las alas caidas.
	var bate_keys := [[0.0, 0.55], [0.14, 0.20], [0.30, -0.35], [0.48, -0.70], [1.0, -0.85]]
	var p: Dictionary = _reposo()
	p["vuela"] = SpriteLienzo.tramos(t, caida_keys)
	p["cae"] = SpriteLienzo.tramos(t, cae_keys)
	p["tumba"] = SpriteLienzo.tramos(t, tumba_keys)
	p["rumbo"] = SpriteLienzo.tramos(t, rumbo_keys) * PI * 0.5
	p["apoyo"] = SpriteLienzo.tramos(t, apoyo_keys)
	p["bate"] = SpriteLienzo.tramos(t, bate_keys)
	p["boca"] = 0.45 * (1.0 - SpriteLienzo.tramos(t, cae_keys))
	p["orejas"] = -0.9 * SpriteLienzo.tramos(t, cae_keys)
	p["cabeza"] = -0.35 * SpriteLienzo.tramos(t, cae_keys)
	p["patas"] = -0.5 * SpriteLienzo.tramos(t, cae_keys)
	return p


static func _montar_muerte(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return _pose_muerte(t)
	_montar_animacion(anims, esc, "muerte", false, 11.0, pose, true, 1, 8)


# EL CADAVER DEL MAPA: UN fotograma por CADA direccion, al reves que 'muerte' (ocho fotogramas en
# una sola). En combate se le ve morir de frente y una vez; en el mapa se entra y ya esta tirado,
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
			# La GEOMETRIA se cachea por (animacion, frame, direccion, escala) y NO por color: otro
			# chillon de otro tono reusa estas plantillas y solo repinta.
			var clave: String = "%s_%d_%d_%.2f" % [nombre, i, dir, esc]
			var plant: PackedByteArray = _cache_plantillas.get(clave, PackedByteArray())
			if plant.is_empty():
				plant = _plantilla(dir, pose_fn.call(float(i) / divisor), esc)
				_cache_plantillas[clave] = plant
			plantillas.append(plant)
		anims.append({"nombre": "%s_%d" % [nombre, dir], "loop": loop, "fps": fps,
			"plantillas": plantillas})


# PELAJE: el color que llega no es el de la ficha, es 'color_visual', que ya viene aclarado hacia el
# blanco segun la 't' del bicho, o sea desaturado de fabrica. Se le devuelve saturacion y se oscurece
# un punto -- lo mismo que hacen el basalto de la gargola y el hierro del escarabajo, y por lo mismo.
static func _pelaje(color: Color) -> Color:
	var out := Color.from_hsv(color.h, minf(1.0, color.s * 1.20 + 0.04), color.v * 0.94)
	out.a = color.a
	return out


# Los colores de cada Tono, EN EL ORDEN DEL ENUM (contrato con SpriteLienzo.paleta).
static func _colores(color: Color) -> Array:
	var c: Color = _pelaje(color)
	# La piel desnuda (orejas, nariz, membrana) tira a un rosa apagado: es el unico sitio donde este
	# bicho deja de ser gris, y es lo que hace que la cara se vea a la primera.
	var piel: Color = c.lerp(Color(0.62, 0.42, 0.44), 0.42)
	return [
		Color(0, 0, 0, 0),                    # VACIO
		Color(0, 0, 0, 0.26),                 # SOMBRA_SUELO
		c.darkened(0.74),                     # BORDE
		# LA MEMBRANA ES LO CLARO DEL BICHO Y EL CUERPO LO OSCURO, y estaba al reves.
		#
		# El primer intento la puso mas oscura que el pelo con un argumento que suena bien -- asi se
		# separa del cuerpo cuando le pasa por encima al batir --, y el resultado era que el ala
		# desaparecia: una banda casi negra a la que el contorno (que tambien es negro) se comia el
		# poco dibujo que le quedaba, con un bulto claro enorme en medio. O sea justo al reves de lo
		# que se ve en cualquier foto de un murcielago volando: el cuerpo es un bulto de pelo OSCURO y
		# las membranas son piel fina que la luz atraviesa. Se separan igual de bien, pero por el lado
		# bueno -- y ademas asi lo que domina la silueta es el ala, que es lo que tiene que dominarla.
		piel.darkened(0.42),                                  # MEMBRANA_OSC (la que va al fondo)
		piel.lerp(Color(0.82, 0.74, 0.76), 0.34),             # MEMBRANA
		# LOS DEDOS y el hueso del borde de ataque, OSCUROS sobre la membrana clara: son los nervios
		# que la cruzan, y sin ellos el ala es una paleta lisa (o sea el ala de una polilla).
		c.darkened(0.62),                     # DEDO_OSC
		c.darkened(0.50),                     # DEDO
		# EL PELO DEL CUERPO, oscuro: es el bulto que cuelga entre las dos membranas.
		c.darkened(0.52),                     # PELO_OSC (el costado, en penumbra)
		c.darkened(0.34),                     # PELO
		# El lomo a la luz. Se aclara hacia un gris FRIO y no hacia el blanco: 'lightened' desatura y
		# el pelaje perderia su tono.
		c.darkened(0.10),                     # PELO_CLARO
		# LAS OREJAS son piel desnuda, no pelo: van con la membrana, o sea CLARAS, y es lo que hace que
		# canten contra la cabeza oscura en vez de leerse como dos cuernos.
		piel.lerp(Color(0.80, 0.72, 0.74), 0.28),             # OREJA_OSC (la de detras)
		piel.lerp(Color(0.86, 0.78, 0.79), 0.46),             # OREJA
		# LA HOJA NASAL, lo mas claro del bicho. En una cara sin ojos es lo unico que hace de centro,
		# asi que tiene que cantar.
		piel.lerp(Color(0.92, 0.80, 0.78), 0.55),             # NARIZ_T
		Color(0.08, 0.05, 0.06, 1.0),         # BOCA_OSC (el hueco de la boca abierta)
		Color(0.94, 0.93, 0.88),              # DIENTE_T (los paletos del MORDISCO)
		c.darkened(0.66),                     # GARRA_T
		# Y apagado en el cadaver: la nariz y los dientes de un muerto no brillan.
		c.darkened(0.52),                     # APAGADO
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


# ERGUIRSE: gira un punto del CUERPO en el plano largo-altura alrededor del hombro. Con 'enc' a 1 el
# bicho pasa de ir tendido (volando de frente) a colgar casi vertical (sosteniendose en el sitio).
#
# LO LLEVAN SOLO LAS PIEZAS DEL CUERPO -- cabeza, torso, patas, membrana de la cola --, NUNCA las
# alas: el hombro es el eje sobre el que gira todo lo demas, asi que las alas se quedan donde estan y
# es el bicho el que se yergue colgado de ellas. Girandolo todo junto lo que sale es una pirueta.
static func _erguir(p: Vector3, enc: float) -> Vector3:
	if is_zero_approx(enc):
		return p
	var a: float = enc * 0.55
	var ca: float = cos(a)
	var sa: float = sin(a)
	var dy: float = p.y - ALA_RAIZ.y
	var dz: float = p.z - ALA_RAIZ.z
	return Vector3(p.x, ALA_RAIZ.y + dy * ca - dz * sa, ALA_RAIZ.z + dy * sa + dz * ca)


# Las PIEZAS del chillon para una pose, ya proyectadas a pantalla. El orden ES la profundidad: de lo
# mas lejano (la sombra, el ala de detras, la membrana de la cola) a lo mas cercano (la cara y el ala
# de delante).
static func _piezas(dir: int, pose: Dictionary, esc: float) -> Array:
	# RUMBO: un giro EXTRA en planta, encima del de la direccion. Solo lo usa la muerte, para que la
	# caida se vea (de frente, el eje sobre el que vuelca apunta a la camara).
	var ang: float = DIR_VECS[dir].angle() - DIR_VECS[0].angle() + float(pose.get("rumbo", 0.0))
	var u: float = esc / SpriteLienzo.UNIDADES_POR_CELDA
	var origen: Vector2 = _origen(esc)
	var mece: float = float(pose["mece"])
	var balanceo: float = float(pose["balanceo"])
	var avance: float = float(pose["avance"])
	var cabeza_gira: float = float(pose["cabeza"])
	var bate: float = clampf(float(pose["bate"]), -1.0, 1.0)
	var boca: float = clampf(float(pose["boca"]), 0.0, 1.0)
	var orejas: float = float(pose["orejas"])
	var patas_f: float = float(pose["patas"])
	var enc: float = float(pose["encara"])
	var cae: float = clampf(float(pose["cae"]), 0.0, 1.0)
	# CUANTO SE HA DESPEGADO DEL SUELO, por encima (o por debajo) de su altura de vuelo. Sube el bicho
	# entero pero NO la sombra: esa separacion es lo unico que se lee como estar en el aire.
	var vuela: float = float(pose["vuela"])
	# TUMBARSE: cuartos de vuelta sobre el eje morro-grupa. 1.0 = de costado, tirado.
	var tumba: float = clampf(float(pose.get("tumba", 0.0)), 0.0, 1.2) * PI * 0.5
	var apoyo: float = float(pose.get("apoyo", 0.0))
	var ct: float = cos(tumba)
	var st: float = sin(tumba)

	var piezas: Array = []
	# EL AVANCE SE ROTA UNA VEZ Y LO LLEVAN TODAS LAS PIEZAS POR IGUAL. Sumarlo a la Y local antes de
	# rotar solo funcionaria si TODAS las piezas giraran; es la trampa del meceo del trent.
	var desp := Vector2(0.0, avance).rotated(ang)
	# EL MECEO, IGUAL: en pantalla y despues de rotar. Y se dobla POR LA ALTURA, o sea que la cabeza
	# va y viene mas que la panza.
	var mece_v := Vector2(balanceo * 1.4, mece * 1.5)

	# 'persp_ov' SOBREESCRIBE la perspectiva de la pieza, y hace falta por una trampa del motor:
	# SpriteLienzo.elipse aplasta con UN solo numero y ese numero solo vale si la pieza es REDONDA EN
	# PLANTA. Una rodaja muy achatada en un eje (aqui la HOJA NASAL y la BOCA) da un valor absurdo y de
	# perfil se dibuja varias veces mas alta de lo que mide. Hereda entonces la del bulto que la
	# sostiene, que es el morro.
	# 'gira_forma' hace que la pieza gire tambien SU FORMA con la direccion, y no solo su sitio.
	#
	# Por defecto ninguna lo hace -- es lo que permite a 'elipse' coger su ruta rapida por filas -- y a
	# los bichos de piezas redondas en planta les da igual. A LAS MEMBRANAS NO: un plato del ala mide
	# 3,3 unidades a lo ancho del ala y 1,9 en la cuerda, asi que mirando al ESTE, con el ala puesta de
	# canto hacia la camara, seguia dibujandose con sus ocho celdas de ancho. Las dos alas salian como
	# dos manchones amontonados y el perfil no se leia en absoluto.
	#
	# Girando la forma, los semiejes acompañan al bicho: de frente el ala es ancha y de perfil se pone
	# de canto, que es lo que hace un ala de verdad.
	var poner := func(local: Vector3, r: Vector3, tono: int, solo_sobre: Array = [],
			en_suelo: bool = false, persp_ov: float = -1.0, gira_forma: bool = false) -> void:
		# TUMBAR, lo primero: gira el punto en el plano ANCHO-ALTURA, o sea alrededor del eje que va
		# del morro a la grupa. 'en_suelo' se lo salta: es la sombra, y el suelo ni vuelca ni sube.
		var lx: float = local.x
		# LA ALTURA DE VUELO ENTRA AQUI, ANTES DE VOLCAR, Y NO AL FINAL.
		#
		# Sumada despues, el cadaver se hundia doce unidades por debajo del suelo con su sombra
		# flotando arriba, y el motivo es que 'tumba' convierte la altura en desplazamiento LATERAL:
		# una vez volcado, 'lz' ya no es lo alto que esta el bicho, asi que restarle ahi las doce
		# unidades que bajaba al morir no lo baja del cielo, lo mete bajo tierra. Puesta antes, el
		# bicho primero llega al suelo y despues vuelca sobre el, que es el orden en que pasan las dos
		# cosas.
		var lz: float = local.z + vuela
		if tumba != 0.0 and not en_suelo:
			var nx: float = lx * ct + lz * st
			lz = -lx * st + lz * ct
			lx = nx
		var alto: float = clampf(local.z / CABEZA.z, 0.0, 1.4)
		var p := Vector2(lx, local.y)
		var rot: Vector2 = p.rotated(ang) + desp + mece_v * alto
		var z: float = 0.0 if en_suelo else lz + apoyo
		var sx: float = origen.x + rot.x * u
		var sy: float = origen.y + (rot.y * SpriteLienzo.COS_CAM - z * SpriteLienzo.SIN_CAM) * u
		# EL RADIO TAMBIEN GIRA al volcar: el semieje a lo ANCHO pasa a ser el vertical y al reves.
		# Sin esto el bicho tirado de costado sale igual de alto que en el aire.
		var mez: float = absf(st) if not en_suelo else 0.0
		var rx: float = lerpf(r.x, r.z, mez)
		var rz: float = lerpf(r.z, r.x, mez)
		piezas.append({"pos": Vector2(sx, sy), "radio": Vector2(rx * u, r.y * u),
			"persp": (1.0 if en_suelo else (persp_ov if persp_ov > 0.0
				else SpriteLienzo.persp_de(r.y, rz))),
			"ang": ang if gira_forma else 0.0,
			"tono": tono, "solo_sobre": solo_sobre})

	# 1. SOMBRA DE CONTACTO, lo primero (va debajo de todo). A ALTURA CERO: no sube con el bicho, y
	#    esa separacion es lo que se lee como volar. Se ENCOGE con la altura, que es lo que hace una
	#    sombra de verdad cuando su dueño se aleja del suelo.
	# Y PEQUEÑA: es la sombra del CUERPO, no la de la envergadura. Empezo en 1,30 x 1,90 del pecho y
	# salia como un pegote negro mas grande que el bicho, que ademas se lleva la mirada porque es la
	# unica mancha opaca del dibujo.
	var lejos: float = clampf(1.0 - vuela / (VUELO_Z * 1.6), 0.45, 1.15)
	poner.call(Vector3(0.0, 0.0, 0.0),
		Vector3(PECHO_R.x * 0.85 * lejos, PECHO_R.y * 1.15 * lejos, 0.0),
		Tono.SOMBRA_SUELO, [], true)

	# LAS DOS ALAS. Cual va delante y cual detras sale de su Y YA GIRADA -- una prueba de profundidad
	# de verdad, no una tabla por direccion que haya que mantener.
	# EL ORDEN Y EL TONO SON DOS PREGUNTAS DISTINTAS, y juntarlas salia mal por los dos lados.
	#
	# El ORDEN (quien tapa a quien) sale de si la membrana esta delante o detras del cuerpo, y eso se
	# mide sobre su CENTRO (ver ALA_CENTRO_Y). Mirando al sur las DOS estan detras, que es lo que deja
	# la cara a la vista.
	#
	# El TONO es otra cosa: es cual de las dos esta mas al fondo. De perfil eso importa muchisimo --
	# una queda arriba en pantalla y otra abajo, y sin contraste entre ellas el bicho es un manchon
	# unico (es lo que separa las dos alas de la polilla en su vista lateral) --, pero de frente las
	# dos estan a la MISMA profundidad y ahi no hay ninguna que oscurecer: pintarlas por el mismo
	# criterio del orden las dejaba a las dos en el tono oscuro y el bicho salia de frente como una
	# mancha negra. Empatadas, las dos van claras.
	var alas: Array = []
	var prof: Array = []
	for lado in [-1.0, 1.0]:
		var raiz := Vector3(lado * ALA_RAIZ.x, ALA_RAIZ.y, ALA_RAIZ.z)
		var pr: float = Vector2(raiz.x, raiz.y + ALA_CENTRO_Y).rotated(ang).y
		prof.append(pr)
		alas.append({"lado": lado, "raiz": raiz, "prof": pr, "delante": pr > 0.0})
	# 'al_fondo' = la que va en tono oscuro, o -1 si empatan (de frente y de espaldas).
	var al_fondo: int = -1
	if absf(float(prof[0]) - float(prof[1])) > 0.5:
		al_fondo = 0 if float(prof[0]) < float(prof[1]) else 1
	for k in alas.size():
		alas[k]["fondo"] = (k == al_fondo)

	# 2. EL ALA DE DETRAS, debajo de todo el cuerpo.
	for a in alas:
		if not bool(a["delante"]):
			_ala(poner, a, bate, cae, DETRAS_ESC if bool(a["fondo"]) else 1.0,
				Tono.MEMBRANA_OSC if bool(a["fondo"]) else Tono.MEMBRANA,
				Tono.DEDO_OSC if bool(a["fondo"]) else Tono.DEDO)

	# 3. LA MEMBRANA DE LA COLA y 4. LAS PATAS, encogidas atras. Van antes del cuerpo: estan detras y
	#    debajo, o sea al fondo.
	poner.call(_erguir(UROPATAGIO, enc), UROPATAGIO_R, Tono.MEMBRANA_OSC)
	for lado in [-1.0, 1.0]:
		_pata(poner, lado, patas_f, enc)

	# 5. EL CUERPO: cadena de bultos peludos de la grupa al pecho, y encima la luz del lomo. Se pinta
	#    de atras adelante para que el pecho tape a la grupa y no al reves.
	for k in CUERPO_SEGMENTOS:
		var i: int = CUERPO_SEGMENTOS - 1 - k
		var f: float = float(i) / float(CUERPO_SEGMENTOS - 1)
		var r: Vector3 = PECHO_R.lerp(GRUPA_R, smoothstep(TORAX_EN, 1.0, f))
		var c := Vector3(0.0, CUERPO_Y0 - float(i) * CUERPO_PASO,
			CUERPO_Z - float(i) * CUERPO_CAE)
		poner.call(_erguir(c, enc), r, Tono.PELO_OSC)
		poner.call(_erguir(Vector3(c.x, c.y, c.z + r.z * 0.30), enc), r * 0.82,
			Tono.PELO, [Tono.PELO_OSC])
	# El lomo a la luz, solo en el bulto del pecho: pequeño y pegado al centro.
	var lomo := Vector3(0.0, CUERPO_Y0 - CUERPO_PASO * 0.4, CUERPO_Z + PECHO_R.z * 0.45)
	poner.call(_erguir(lomo, enc), PECHO_R * 0.50, Tono.PELO_CLARO, [Tono.PELO])

	# 6. LA CABEZA, adelantada y algo mas baja que el lomo. Gira un poco con 'cabeza'.
	var giro_cab: float = cabeza_gira * 1.6
	var cab: Vector3 = _erguir(Vector3(CABEZA.x + giro_cab, CABEZA.y, CABEZA.z), enc)
	poner.call(cab, CABEZA_R, Tono.PELO_OSC)
	poner.call(Vector3(cab.x, cab.y, cab.z + CABEZA_R.z * 0.28), CABEZA_R * 0.86,
		Tono.PELO, [Tono.PELO_OSC])

	# 7. LAS OREJAS. La de detras primero y en tono propio, para que las dos no se fundan en una
	#    mancha cuando se cruzan de medio lado.
	var ors: Array = []
	for lado in [-1.0, 1.0]:
		var base := Vector3(lado * OREJA_BASE.x, OREJA_BASE.y + giro_cab * 0.4, OREJA_BASE.z)
		ors.append({"lado": lado, "base": base,
			"delante": Vector2(base.x, base.y).rotated(ang).y > 0.0})
	for o in ors:
		if not bool(o["delante"]):
			_oreja(poner, o, orejas, enc, DETRAS_ESC, Tono.OREJA_OSC)

	# 8. EL MORRO, y colgadas de el LA HOJA NASAL y LA BOCA. Las dos son rodajas finas, asi que
	#    heredan la perspectiva del morro (ver la nota de 'poner').
	var apagado: bool = tumba >= PI * 0.25
	var persp_morro: float = SpriteLienzo.persp_de(MORRO_R.y, MORRO_R.z)
	var mor: Vector3 = _erguir(Vector3(MORRO.x + giro_cab * 1.3, MORRO.y, MORRO.z), enc)
	poner.call(mor, MORRO_R, Tono.PELO_OSC)
	# LA CARA SOLO SI SE LE VE. De espaldas es una nuca: ni nariz ni boca.
	var frente: float = Vector2(0.0, 1.0).rotated(ang).y
	if frente > CARA_VISIBLE:
		var nar: Vector3 = _erguir(Vector3(NARIZ.x + giro_cab * 1.3, NARIZ.y, NARIZ.z), enc)
		poner.call(nar, NARIZ_R, Tono.APAGADO if apagado else Tono.NARIZ_T, [], false, persp_morro,
			true)
		# LA BOCA: se abre hacia abajo y hacia dentro. Cerrada es una raja; abierta es el hueco negro
		# del que salen los paletos, que es lo que tiene que verse cuando chilla y cuando muerde.
		var abre: float = BOCA_ABRE * boca
		var bo: Vector3 = _erguir(Vector3(BOCA.x + giro_cab * 1.3, BOCA.y, BOCA.z - abre * 0.45), enc)
		var bo_r := Vector3(BOCA_R.x * (1.0 + 0.22 * boca), BOCA_R.y,
			BOCA_R.z + abre * 0.55)
		poner.call(bo, bo_r, Tono.BOCA_OSC, [], false, persp_morro, true)
		# LOS PALETOS, dentro de la boca ('solo_sobre'), asi que el contorno no los toca y pueden bajar
		# de las tres celdas de la regla. DOS HILERAS: la de arriba pegada al morro y la de abajo
		# separandose al abrirse -- que es exactamente lo que dibuja el MORDISCO del combate.
		if not apagado:
			for l in [-1.0, 1.0]:
				poner.call(Vector3(bo.x + l * DIENTE_X, bo.y, bo.z + bo_r.z * 0.55),
					Vector3.ONE * DIENTE_R, Tono.DIENTE_T, [Tono.BOCA_OSC], false, persp_morro)
				poner.call(Vector3(bo.x + l * DIENTE_X, bo.y, bo.z - bo_r.z * 0.55),
					Vector3.ONE * DIENTE_R, Tono.DIENTE_T, [Tono.BOCA_OSC], false, persp_morro)

	# 9. LA OREJA DE DELANTE y 10. EL ALA DE DELANTE, ya sobre el cuerpo.
	for o in ors:
		if bool(o["delante"]):
			_oreja(poner, o, orejas, enc, 1.0, Tono.OREJA)
	for a in alas:
		if bool(a["delante"]):
			_ala(poner, a, bate, cae, DETRAS_ESC if bool(a["fondo"]) else 1.0,
				Tono.MEMBRANA_OSC if bool(a["fondo"]) else Tono.MEMBRANA,
				Tono.DEDO_OSC if bool(a["fondo"]) else Tono.DEDO)

	return piezas


# UNA OREJA: cadena de palas que sube desde lo alto de la cabeza hacia atras y afuera, estrechandose.
#
# LA CADENA SE CONSTRUYE PASO A PASO, cada tramo en la direccion que le toca, y NO como puntos de una
# recta: asi la separacion entre piezas es exactamente el paso, se doble la oreja como se doble, y no
# hay forma de que se descosa. El paso (0,97) va por debajo del radio mas fino de la cadena (1,00),
# que es la vieja regla del paso menor que el grosor.
#
# 'gira' la orienta: hacia delante cuando chilla (apunta con las orejas, que es lo unico que puede
# hacer de mirada un bicho sin ojos) y echada hacia atras cuando pica o cuando encaja un golpe.
static func _oreja(poner: Callable, o: Dictionary, gira: float, enc: float,
		esc_detras: float, tono: int) -> void:
	var lado: float = float(o["lado"])
	var base: Vector3 = o["base"]
	var paso: float = OREJA_LARGO / float(OREJA_SEGMENTOS - 1)
	# La direccion base, con la Y movida por 'gira': +1 la echa hacia delante, -1 hacia atras.
	var d := Vector3(lado * OREJA_DIR.x, OREJA_DIR.y + gira * OREJA_GIRA, OREJA_DIR.z).normalized()
	var eje: Vector3 = base
	for k in OREJA_SEGMENTOS:
		var f: float = float(k) / float(OREJA_SEGMENTOS - 1)
		if k > 0:
			# Se van ABRIENDO hacia la punta: sin eso las dos orejas salen paralelas y se leen como un
			# par de cuernos rectos, no como las palas de un murcielago.
			var dk := Vector3(d.x + lado * OREJA_ABRE * f, d.y, d.z).normalized()
			eje += dk * paso
		var r := Vector3(lerpf(OREJA_RX0, OREJA_RX1, f) * esc_detras, OREJA_FINO,
			lerpf(OREJA_RZ0, OREJA_RZ1, f))
		poner.call(_erguir(eje, enc), r, tono, [], false, -1.0, true)


# UNA PATA: cadena corta hacia atras, afuera y abajo, rematada en el pie. Encogida, que es como las
# lleva un murcielago en el aire. 'mueve' las estira (al morder) o las recoge del todo (al morir).
static func _pata(poner: Callable, lado: float, mueve: float, enc: float) -> void:
	var cadera := Vector3(lado * CADERA.x, CADERA.y, CADERA.z)
	var d := Vector3(lado * PATA_DIR.x, PATA_DIR.y - mueve * 0.35,
		PATA_DIR.z - mueve * 0.30).normalized()
	var paso: float = PATA_LARGO / float(PATA_SEGMENTOS - 1)
	var eje: Vector3 = cadera
	for k in PATA_SEGMENTOS:
		var f: float = float(k) / float(PATA_SEGMENTOS - 1)
		if k > 0:
			eje += d * paso
		poner.call(_erguir(eje, enc), Vector3.ONE * lerpf(PATA_R0, PATA_R1, f), Tono.PELO_OSC)
	# EL PIE, metido dentro del ultimo tramo (un solape de una celda no es un solape).
	poner.call(_erguir(eje + d * (PIE_R * 0.45), enc), Vector3.ONE * PIE_R, Tono.GARRA_T)


# UN ALA. Rejilla de piezas: 'i' a lo largo del hueso (span) y 'j' de delante a atras (cuerda).
# CADA PIEZA ES UN PLATO, no una bola: la tecnica es la de la gargola y esta explicada alli.
#
# 'bate' va de -1 (ala abajo del todo) a +1 (arriba del todo) y mueve el hueso, la caida de la
# membrana y cual de los radios es el fino. 'cae' es solo para la muerte: encoge el ala y le quita la
# forma.
static func _ala(poner: Callable, a: Dictionary, bate: float, cae: float, esc_detras: float,
		tono: int, tono_dedo: int) -> void:
	var lado: float = float(a["lado"])
	var raiz: Vector3 = a["raiz"]
	var largo: float = ALA_LARGO * (1.0 - ALA_ENCOGE * cae)

	# EL BORDE DE ATAQUE TIENE UN CODO, Y ESE CODO ES LA SILUETA ENTERA DEL BICHO.
	#
	# La gargola lo resuelve como un ARCO liso (una direccion en la raiz, otra en la punta, y el
	# tramo interpolado entre las dos), y con ella cuela porque lleva las alas plegadas casi siempre.
	# Volando de par en par no cuela: en las fotos el ala es una V DOBLE -- el antebrazo sale hacia
	# DELANTE y afuera, y en la muñeca quiebra y la mano se abre hacia ATRAS y afuera --, y ese
	# quiebro es lo que se reconoce a la primera. Un arco liso da una paleta redondeada, que es otra
	# vez el ala de la polilla.
	#
	# Asi que son DOS direcciones con un corte seco en la muñeca, no una interpolacion: 'd_brazo'
	# hasta 'i_mun' y 'd_mano' a partir de ahi. Tres poses de cada una -- abajo, plano y arriba -- y
	# el bateo se mueve entre ellas.
	var arriba: bool = bate > 0.0
	var f: float = absf(bate)
	var d_brazo_0 := Vector3(lado * 0.78, 0.40, 0.10)
	var d_mano_0 := Vector3(lado * 0.88, -0.36, -0.12)
	var d_brazo_1: Vector3 = (Vector3(lado * 0.55, 0.34, 0.72) if arriba
		else Vector3(lado * 0.80, 0.38, -0.32))
	var d_mano_1: Vector3 = (Vector3(lado * 0.62, -0.30, 0.68) if arriba
		else Vector3(lado * 0.70, -0.34, -0.60))
	var d_brazo: Vector3 = d_brazo_0.lerp(d_brazo_1, f).normalized()
	var d_mano: Vector3 = d_mano_0.lerp(d_mano_1, f).normalized()
	# La direccion MEDIA, solo para orientar el grosor de los platos y el pulgar de la muñeca.
	var hueso: Vector3 = d_brazo.lerp(d_mano, 0.5).normalized()
	# DONDE ESTA LA MUÑECA, o sea donde quiebra. Se calcula aqui arriba porque ahora manda el hueso
	# entero, no solo el reparto de los dedos.
	var i_mun: int = clampi(int(round(ALA_MUNECA * float(ALA_SPAN - 1))), 1, ALA_SPAN - 2)

	# LA CUERDA de la membrana, de delante a atras. AQUI ESTABA LA TRAMPA GORDA DE LA GARGOLA: alli el
	# ala pasaba de vertical a horizontal y a mitad de camino la cuerda quedaba con (y - z) = 0, o sea
	# en el eje ciego de la camara, y la membrana entera colapsaba sobre el hueso -- el ala salia como
	# un palo. Aqui no puede pasar porque la cuerda NO cambia de cuadrante: apunta siempre hacia atras
	# y algo abajo, y su (y - z) se mueve entre -0,59 y -0,89. La cuenta esta hecha, no tanteada.
	var cuerda := Vector3(lado * 0.12 * bate, -0.95, -0.26 - 0.16 * bate).normalized()
	# Y EN LA RAIZ LA CUERDA BAJA, que es lo que cose el ala al cuerpo. La membrana de un murcielago no
	# empieza en el hombro: el tramo de dentro (el del brazo) va del COSTADO al codo, o sea que cae
	# desde el hombro hasta la cadera. Con la cuerda apuntando atras tambien ahi, el ala salia flotando
	# -- una banda de membrana arriba y el bicho colgando debajo, con un dedo de aire entre las dos --,
	# que es justo lo que se gana al separarlos en altura y hay que volver a coser.
	var cuerda_raiz := Vector3(lado * 0.10 * bate, -0.78, -0.62).normalized()

	# El eje FINO va con la normal del ala: plana es fina en ALTURA, y levantada del todo se pone casi
	# vertical y pasa a ser fina a lo ANCHO (o sea se ve de canto). Ese cambio de ancho en pantalla ES
	# el aleteo: no hace falta mover nada mas.
	var vert: float = clampf(bate, 0.0, 1.0) * 0.75
	var fino_x: float = lerpf(ALA_CUERDA_MAX * 0.30, ALA_GRUESO, vert)
	var fino_z: float = lerpf(ALA_GRUESO, ALA_CUERDA_MAX * 0.30, vert)

	var paso_span: float = largo / float(ALA_SPAN - 1)
	# EL BORDE DE ATAQUE, tramo a tramo. Se guardan los puntos y las cuerdas porque los DEDOS se
	# cuelgan de ellos despues.
	var borde: Vector3 = raiz
	var bordes: Array = []
	var anchos: Array = []
	for i in ALA_SPAN:
		var s: float = float(i) / float(ALA_SPAN - 1)
		if i > 0:
			# EL QUIEBRO: hasta la muñeca manda el brazo y a partir de ella la mano. Sin interpolar --
			# interpolar es justo lo que redondea el codo y devuelve la paleta.
			borde += (d_brazo if i <= i_mun else d_mano) * paso_span
		# La CUERDA de la membrana en este punto del hueso. Es ESTRECHA EN EL BRAZO (ahi la membrana
		# solo va del costado al codo) y se abre de golpe PASADA LA MUÑECA, que es donde estan los
		# cuatro dedos: por eso el pico va en s = 0,61 y no en el medio. Y no se cierra del todo en la
		# punta, que queda afilada. Al morir se arruga (el 'cae' le come mas de un tercio).
		# El termino base BAJA con el span, y las dos puntas de esa rampa son cosas concretas: en la raiz
		# (0,62) la membrana tiene que llegar desde el hombro hasta la CADERA -- si no, entre el ala y el
		# cuerpo queda un triangulo de aire y el bicho se ve partido en tres trozos --, y en la punta
		# (0,20) el ala tiene que acabar AFILADA, que es como acaba en las fotos.
		var ancho: float = (ALA_CUERDA_MAX
			* (lerpf(0.62, 0.20, s) + 0.55 * sin(PI * pow(s, 1.4))) * (1.0 - 0.38 * cae))
		# La cuerda de ESTE punto del hueso: cayendo al costado mientras estamos en el brazo, y hacia
		# atras a partir de la muñeca.
		var cuerda_s: Vector3 = cuerda_raiz.lerp(cuerda,
			smoothstep(0.0, ALA_MUNECA, s)).normalized()
		# EL PASO ES ENTRE PIEZAS, o sea (N - 1) huecos y no N. Dividiendo por N el paso sale corto, el
		# radio que se calcula con el tambien, y las piezas de la cuerda NO LLEGAN A TOCARSE: el ala
		# saldria como un palo, solo el hueso con la membrana en motas sueltas alrededor.
		var paso_cuerda: float = ancho / float(ALA_CUERDA - 1)
		var base: Vector3 = borde
		for j in ALA_CUERDA:
			var v: float = float(j) / float(ALA_CUERDA - 1)
			var p: Vector3 = base + cuerda_s * (ancho * v)
			# El radio de cada plato: lo justo para SOLAPAR con sus vecinas en los dos sentidos de la
			# rejilla (span y cuerda), y el eje fino aparte. Sin esto la membrana sale a lunares.
			#
			# 0,80 Y NO EL 0,62 DE LA GARGOLA, y la diferencia tiene motivo: alli la rejilla del ala cae
			# casi en cuadricula y basta con que cada plato llegue a su vecino. Aqui el hueso va en
			# diagonal por el codo, asi que la rejilla sale SESGADA y entre cuatro platos vecinos queda
			# un rombo de aire que ninguno cubre -- el ala se veia con franjas oscuras por dentro. Un
			# rombo se tapa con radio, no con mas piezas.
			var gordo: float = maxf(paso_span, paso_cuerda) * 0.80
			var r := Vector3(maxf(fino_x, gordo * absf(hueso.x) + gordo * 0.35),
				gordo, maxf(fino_z, gordo * absf(hueso.z) * 0.6))
			poner.call(p, r * esc_detras, tono, [], false, -1.0, true)
		bordes.append(base)
		anchos.append(ancho)

	# EL HUESO DEL BORDE DE ATAQUE, encima de la membrana ya pintada y con su propio grosor (ver
	# HUESO_R). Va por subpasos entre plato y plato porque el paso del span (2,33) es casi tres veces
	# su radio: puesto solo en los siete puntos del span, el hueso saldria a trozos.
	for i in ALA_SPAN - 1:
		for m in HUESO_SUBPASOS:
			var fh: float = float(m) / float(HUESO_SUBPASOS)
			poner.call((bordes[i] as Vector3).lerp(bordes[i + 1], fh),
				Vector3.ONE * HUESO_R * esc_detras, tono_dedo)
	poner.call(bordes[ALA_SPAN - 1], Vector3.ONE * HUESO_R * esc_detras, tono_dedo)

	# EL PULGAR: el garfio de la muñeca con el que se cuelga del techo. Va METIDO en el borde de
	# ataque y apuntando hacia delante y arriba, que es como lo lleva un murcielago en vuelo.
	var muneca: Vector3 = bordes[i_mun]
	poner.call(muneca + Vector3(lado * 0.35, 0.95, 0.55) * (1.0 - 0.6 * cae),
		Vector3.ONE * PULGAR_R * esc_detras, tono_dedo)

	# LOS DEDOS, encima de la membrana ya pintada. Sin ellos la membrana es una PALETA LISA, o sea el
	# ala de una polilla; con ellos la misma silueta se lee como un ala de murcielago. Es el detalle
	# que mas cambia la lectura de este bicho por lo poco que cuesta -- y aqui son CUATRO, que son los
	# que tiene.
	#
	# 'solo_sobre' LA MEMBRANA: es lo que los convierte en nervios DENTRO del ala en vez de en una
	# mancha. Sueltos y en el tono mas oscuro del bicho, los cuatro dedos se comerian la membrana
	# entera y el ala volveria a ser una paleta, esta vez negra.
	for k in ALA_DEDOS:
		var f_span: float = lerpf(0.55, 1.0, float(k) / float(ALA_DEDOS - 1))
		var idx: int = clampi(int(round(f_span * float(ALA_SPAN - 1))), 0, ALA_SPAN - 1)
		# NO LLEGAN AL BORDE DE SALIDA. Cruzando la membrana entera, tres nervios oscuros la parten en
		# retales: el ala mide catorce celdas de alto en pantalla y no da para tanto. Quedandose en el
		# 78% se leen igual como nervios y la membrana sigue siendo UNA cosa.
		var destino: Vector3 = bordes[idx] + cuerda * (anchos[idx] * 0.78)
		for m in range(1, DEDO_SEGMENTOS):
			var fd: float = float(m) / float(DEDO_SEGMENTOS - 1)
			poner.call(muneca.lerp(destino, fd), Vector3.ONE * DEDO_R * esc_detras, tono_dedo,
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
		# Casi todas van con ang = 0 -- no giran su FORMA, solo el sitio donde se ponen -- y ahi 'elipse'
		# coge su ruta rapida por filas. Las que si giran son las que no son redondas en planta: los
		# platos de la membrana, las orejas y la cara (ver 'gira_forma' en _piezas).
		SpriteLienzo.elipse(plant, lz.x, lz.y, pos.x, pos.y, r.x, r.y, int(p["tono"]),
			float(p["ang"]), p["solo_sobre"], float(p["persp"]))

	# CONTORNO al final, sobre la silueta ya completa (ver SpriteLienzo.contornear).
	SpriteLienzo.contornear(plant, SpriteLienzo.caja_de_piezas(piezas, lz.x, lz.y), lz.x, lz.y,
		Tono.BORDE, Tono.VACIO, Tono.SOMBRA_SUELO)
	return plant
