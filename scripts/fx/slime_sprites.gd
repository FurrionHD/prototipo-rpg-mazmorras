# ============================================================
#  slime_sprites.gd  (class_name SlimeSprites)
#  Sprite del SLIME dibujado por codigo, con el motor comun (SpriteLienzo). Cubre a los 6 .tres de
#  familia SLIME: el normal, venenoso, profundo, de fuego, abisal y el Rey (variante con corona).
#
#  REWORK 2026-08-24: antes estaba en vista 3/4 mirando a camara (silueta de campana con la base
#  cortada en seco por una fila fija, ojos siempre de frente). Ahora comparte la CAMARA A 45 GRADOS
#  que estrenaron las ratas, para que los dos enemigos del mapa se vean desde el mismo sitio. Con
#  ella cambian tres cosas, y las tres las pidio el usuario:
#    * LA BASE ES UN OVALO APOYADO, no un corte recto: el borde de abajo es la base del cuerpo vista
#      en escorzo, asi que el slime se ve POSADO en el suelo en vez de recortado contra el.
#    * LOS OJOS DESAPARECEN DE ESPALDAS (y de medio lado se ve solo el de ese lado), asi se lee de
#      un vistazo si viene o si huye.
#    * LOS CUERNOS GIRAN DE VERDAD alrededor de la cabeza, como piezas 3D. En cenital eso SI es
#      correcto -- lo que salio fatal en su dia fue rotar puntos dentro de un cuerpo en 3/4, que es
#      otra cosa: alli la cara "se derretia".
#
#  LO QUE NO CAMBIA, porque costo siete iteraciones acordarlo: la bola apoyada (lo mas ancho a media
#  altura), los dos cuernos, el doble brillo especular, la panza en sombra, el contorno oscuro sobre
#  la silueta YA FUSIONADA (nunca pieza a pieza) y la corona del Rey hecha de SU PROPIO GEL con una
#  gema en cada punta -- no oro ajeno.
#
#  COMO SE DIBUJA: cada pieza vive en 3D (x a lo ancho, y a lo largo, z de altura sobre el suelo) y
#  se proyecta con la camara:
#        pantalla_x = x
#        pantalla_y = y * cos(45) - z * sin(45)
#  Ese "- z" es lo que pone la coronilla por encima de la base y hace que se le vea el costado en vez
#  de la planta. Sin altura, por mucho que se aplaste la silueta, sigue leyendose "desde arriba".
#
#  EL CUERPO NO GIRA -- es una bola, se ve igual desde los ocho lados -- y ninguna pieza necesita
#  girar sobre si misma: lo que gira son las POSICIONES de los adornos. Por eso aqui todas las
#  elipses van con angulo cero y no hace falta el 'ang' que si necesita la rata (que es alargada).
#
#  EL TAMAÑO SE DIBUJA, NO SE ESTIRA: ver SpriteLienzo.UNIDADES_POR_CELDA. El Rey Slime
#  (escala_visual 2.6) se dibuja en una rejilla mas grande, no con los pixeles mas gordos -- que es
#  como estaba antes, con la celda a 2,95 unidades contra las 0,62 de una rata.
# ============================================================

extends RefCounted
class_name SlimeSprites

const FRAMES := 8

# La camara (45 grados) vive en el motor: es UNA para todos los bichos, ver SpriteLienzo.COS_CAM.

# --- El slime mirando al SUR, en unidades de MUNDO (origen = el punto en que TOCA EL SUELO,
# +Y hacia donde mira, +Z hacia arriba). Diametro 34: es el tamaño que ya tenia en pantalla, y
# respetarlo es lo que hace que este rework no lo agrande ni lo encoja. ---
const DIAMETRO_MUNDO := 34.0
# Y lo que CHOCA, que no es lo mismo. Una celda de la mazmorra mide 32 px justos
# (DungeonGenerator.CELDA), asi que ese es el techo para cualquier bicho que tenga que pasar por un
# pasillo de una celda. El dibujo puede sobresalir de su caja -- de hecho lo hace a proposito --,
# pero la caja no puede pasarse del hueco por el que tiene que caber.
const CUERPO_COLISION := 32.0

# CUERPO: una bola apoyada. El centro esta a su propio semialto, o sea que la bola TOCA el suelo
# exactamente -- de ahi salen a la vez la coronilla redonda y la base cerrada en ovalo, sin ningun
# corte. LA PROFUNDIDAD (Y) ES MENOR QUE EL ANCHO a proposito: con la planta redonda de verdad
# (17, 17) el escorzo lo dejaba de 34x30 en pantalla, o sea un macaron; el slime de siempre mide
# 34x25 y esas son las proporciones que hay que respetar.
const CUERPO := Vector3(0.0, 0.0, 15.0)
const CUERPO_R := Vector3(17.0, 9.5, 15.0)
# EL CUERPO NO GIRA, y por eso puede permitirse tener menos fondo que ancho: es una bola, se ve
# igual desde los ocho lados, y solo giran sus adornos. Pero ENTONCES no sirve para anclarlos: un
# elipsoide achatado colocaria los cuernos a una distancia distinta segun hacia donde mire, y
# entrarian y saldrian del cuerpo al girar. Para eso esta este radio aparte, REDONDO EN PLANTA:
# el cuerpo se DIBUJA con CUERPO_R y los adornos se CLAVAN en CUERPO_ANCLA_R.
#
# El fondo corto es justo lo que hace que se lea APOYADO: con el fondo entero (17) la silueta
# sobresalia 7 unidades por debajo de la linea del suelo y el bicho se leia como una lenteja
# flotando; corto, la base apenas asoma y lo que se ve es una bola posada.
const CUERPO_ANCLA_R := Vector3(17.0, 12.0, 15.0)
# CUPULA ILUMINADA: la misma bola, un poco menor y subida. Se pinta en BASE sobre un cuerpo en
# SOMBRA, y lo que queda sin cubrir por abajo ES la panza en penumbra. Antes esa frontera era una
# linea calculada a mano con un arqueo a ojo (SOMBRA_ARQUEO); aqui se curva sola, y ademas se curva
# bien, porque es una elipse en perspectiva de verdad.
# OJO CON SUBIRLA: cuanto mas sube, mas gruesa es la banda oscura de abajo, y una banda gruesa de
# lados rectos deja de leerse como panza y se lee como un TAMBOR. Tiene que ser un filo.
const CUPULA_SUBE := 0.20          # fraccion del semialto que sube
const CUPULA_ESC := 0.97
# SOMBRA DE CONTACTO: la huella en el suelo. Asoma solo por delante, como una media luna; el resto
# lo tapa el propio cuerpo.
const SOMBRA_R := Vector3(12.0, 7.0, 0.0)
# NOTA: aqui habia un CHARCO -- una elipse aparte, mas ancha, para el labio de baba derramada. Era
# un truco de la vista en 3/4, donde la base iba cortada en seco y hacia falta algo que dijera "esto
# se apoya". Con la camara a 45 grados el borde inferior de la silueta YA es la base vista en
# escorzo, asi que el charco solo añadia una segunda banda oscura (el efecto tambor) y una elipse
# enorme mas que rellenar. Fuera.

# --- LO QUE VA CLAVADO EN EL CUERPO (cuernos, puntas de la corona, ojos) ---
#
# NO se colocan con coordenadas a mano: se declaran por una DIRECCION desde el centro del cuerpo, y
# _en_el_cuerpo() las lleva a la superficie del elipsoide y las HUNDE un poco. Es la unica forma de
# que no se despeguen: puestos a ojo, se salian "en todas las de hacia arriba" -- y no es raro, la
# superficie de un elipsoide esta a una distancia distinta en cada direccion, asi que un punto que
# encaja mirando al sur flota mirando al norte. Anclandolos por direccion eso no puede pasar.

# CUERNOS: dos pinchos de gel denso, arriba y un poco adelantados.
const CUERNO_DIR := Vector3(0.50, 0.12, 0.86)
const CUERNO_R := Vector3(3.8, 3.8, 5.0)
# La base BIEN metida: rozando la superficie, el cuerno se despegaba en el frame de mas estiron de
# la embestida (el cuerpo se alarga y el adorno se queda). Un solape de una celda no aguanta nada.
const CUERNO_HUNDE := 2.2          # cuanto se mete la BASE del pincho bajo la superficie
# OJOS: en la CARA, o sea bien adelantados en Y y no muy arriba.
# LA SEPARACION ANGULAR ES LO QUE MANDA, no la que se ve de frente. Con la primera version
# (0.35, 0.53) cada ojo caia a 45 grados del morro, o sea 90 grados el uno del otro: en pantalla se
# veian juntos, pero al girar solo 45 grados uno ya se habia ido al otro lado del cuerpo y
# desaparecia de golpe -- "parece que tienen un kilometro de distancia entre uno y otro". Ahora estan
# a 18 grados del morro cada uno, asi que aguantan juntos y se pierden poco a poco.
const OJO_DIR := Vector3(0.28, 0.72, 0.62)
const OJO_R := Vector3(2.5, 2.5, 3.6)
const OJO_HUNDE := 1.4
# Hasta donde puede irse un ojo hacia atras y seguir viendose (en la Y de su direccion, ya girada).
# Un pelin negativo: el ojo sigue viendose cuando queda justo en el filo, pero no despues. La
# progresion que da es: de frente y de medio lado los DOS, de perfil UNO, y en cuanto empieza a
# darse la vuelta -- las cuatro direcciones de hacia arriba -- NINGUNO. Un bicho que se aleja enseña
# la nuca; verle la cara mientras huye rompe la perspectiva entera.
const OJO_VISIBLE := -0.15

# CORONA del Rey Slime: 5 puntas en ANILLO alrededor de la coronilla, una justo al frente. En 3/4
# eran 5 picos en fila porque solo se veia la mitad de delante; con la camara a 45 grados una fila
# recta se leeria como una cresta de dinosaurio, y lo que se lee como corona es el aro.
const CORONA_PUNTAS := 5
const CORONA_ANILLO := 0.72        # cuanto se abre el aro (fraccion del radio del cuerpo)
const CORONA_ALTO := 0.70          # y a que altura lo corta
const CORONA_PUNTA_R := Vector3(2.3, 2.3, 6.5)
const CORONA_HUNDE := 0.5
const GEMA_R := Vector3(1.15, 1.15, 1.15)

# Lo que esta DETRAS se dibuja mas pequeño: sin esto los dos cuernos asoman casi iguales por la
# coronilla y parecen gemelos, que es justo lo contrario de lo que tienen que contar.
const ORNAMENTO_DETRAS_ESC := 0.75
# Cuanto se comprime el escorzo de los ornamentos y de los ojos (ver 'escorzo' en _piezas).
const ORNAMENTO_ESCORZO := 0.35
const OJO_ESCORZO := 0.60

# BRILLOS especulares. Van en coordenadas de PANTALLA y NO giran con el bicho: la luz esta clavada
# en el mundo, asi que un reflejo no se mueve porque el slime se de la vuelta. Se miden en
# fracciones del cuerpo (x, y sobre el centro de la bola proyectado) para que escalen solos.
const BRILLO_A := Vector3(-0.36, -0.42, 0.28)     # x, y, radio (fracciones del semiancho)
const BRILLO_B := Vector3(0.30, -0.46, 0.14)

const LUNGE_DIST := 8.0            # cuanto viaja el cuerpo en la embestida, en unidades de mundo
const BOTE := 3.1                  # cuanto se despega del suelo en el punto alto del walk
# ENCAJAR UN GOLPE: cuanto lo empuja hacia atras el impacto (unidades de mundo, eje local -Y). Poco
# a proposito: el encaje tiene que leerse como una SACUDIDA, no como un desplazamiento, porque en
# combate la figura entera ya se mueve por su cuenta y dos desplazamientos a la vez se pelean.
const ENCAJE_RETRO := 3.4
# MORIRSE: cuanto se le quita del ensanchado al charco. El cuerpo aplastado quiere abrirse 1,54
# veces y el lienzo solo da 1,66 contando el contorno y la sombra, asi que sin esto los frames
# finales salen cortados por los dos lados. Ver 'ancho' en _piezas.
const ENCAJE_CHARCO_ANCHO := 0.80

# --- EL LIENZO, en multiplos del diametro del cuerpo. Los tres numeros salen de MEDIR la caja real
# de los 192 frames (ver dev_test_slime.gd) y dejar el minimo que no recorta ni uno; calcular a mano
# cuanto sobresale cada cosa es facil de errar por un termino, y ya paso una vez con las orejas.
#
# NO es cuadrado ni esta centrado, y eso NO es un capricho: el origen es el punto donde el bicho
# TOCA EL SUELO, asi que todo el cuerpo queda por encima y por debajo solo hay la mediluna de la
# sombra. Con un lienzo cuadrado y centrado -- como el de la rata, que es un bicho bajito -- sobraban
# 76 celdas por abajo en el Rey Slime mientras el walk se salia por arriba. Y aqui la memoria pesa:
# el lienzo crece con el AREA, y el Rey va a escala 2.6.
const LIENZO_ANCHO := 1.66
const LIENZO_ARRIBA := 1.12        # del suelo (el origen) hacia arriba
const LIENZO_ABAJO := 0.40

# --- Vectores de las 8 direcciones (pantalla: +Y es hacia ABAJO). Mismo orden que RataSprites y que
# el _dir8 de enemy.gd: 0=S 1=SE 2=E 3=NE 4=N 5=NW 6=W 7=SW. ---
const DIR_VECS := [
	Vector2(0, 1), Vector2(0.7, 0.7), Vector2(1, 0), Vector2(0.7, -0.7),
	Vector2(0, -1), Vector2(-0.7, -0.7), Vector2(-1, 0), Vector2(-0.7, 0.7),
]

# TONOS de la plantilla: la geometria no guarda COLORES, guarda a que "capa" pertenece cada celda.
# Asi la parte cara (elipses, contorno) se calcula UNA vez y sirve para cualquier color.
enum Tono { VACIO, SOMBRA_SUELO, BORDE, DETRAS, SOMBRA, BASE, CLARO, CLARO_TENUE,
	ORNAMENTO, OJO_T, GEMA }

const COLOR_PASOS := 6.0
static var _cache: Dictionary = {}
static var _cache_plantillas: Dictionary = {}


# --- Contrato de SpritesEnemigo (el registro que decide quien dibuja a quien) ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t), ed.corona_slime, ed.escala_visual)


# La CLAVE de esta variante: la misma que usa el cache y la que da nombre al fichero horneado (ver
# SpriteLienzo.hornear). Es publica porque el horno y el juego tienen que llegar al MISMO nombre --
# si no coincidieran, el juego generaria al vuelo un PNG que ya esta en disco y nadie se enteraria.
static func clave_de(ed: EnemyData, t: float) -> String:
	return _clave(SpriteLienzo.cuantizar_hsv(ed.color_visual(t), COLOR_PASOS),
		ed.corona_slime, snappedf(ed.escala_visual, 0.05))


static func _clave(col: Color, corona: bool, esc: float) -> String:
	return "slime_%s_%.2f%s" % [col.to_html(false), esc, "_corona" if corona else ""]


# El pixel mide lo mismo para TODOS los bichos: el tamaño sale de cuantas celdas ocupa cada uno.
static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(escala: float = 1.0) -> int:
	return _lienzo(escala).x


# true: el tamaño ya va DENTRO del dibujo (el Rey se dibuja con mas celdas que un slime normal), asi
# que nadie debe volver a estirar el sprite -- si no, sus pixeles saldrian mas gordos.
static func dimensiona_por_escala() -> bool:
	return true


# El CUERPO en planta (ancho, largo) en unidades de mundo, para que enemy.gd le haga una colision a
# su medida. El slime es REDONDO en planta, asi que los dos valen lo mismo: no importa por donde
# mire, ocupa igual. (Lo que se achata es el DIBUJO, para que no se lea como un macaron -- ver
# CUERPO_R --, pero eso es cosa de la camara, no de cuanto sitio ocupa en el suelo.)
static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	# CUERPO_COLISION y no DIAMETRO_MUNDO: el slime se DIBUJA a 34 (un pelin mas grande que su caja,
	# que es como se ve un charco asomando por los bordes de su hitbox), pero un pasillo de la
	# mazmorra mide UNA CELDA = 32 px exactos. Con 34 no cabia: los slimes se quedaban trabados en
	# las esquinas sin poder salir. Lo que se dibuja puede sobresalir; lo que CHOCA, no.
	return Vector2(CUERPO_COLISION, CUERPO_COLISION) * escala


# Cuantas celdas mide el lienzo para una escala dada.
static func _lienzo(escala: float) -> Vector2i:
	var u: float = DIAMETRO_MUNDO * escala / SpriteLienzo.UNIDADES_POR_CELDA
	var w: int = int(ceil(u * LIENZO_ANCHO))
	var h: int = int(ceil(u * (LIENZO_ARRIBA + LIENZO_ABAJO)))
	return Vector2i(w + (w % 2), h + (h % 2))   # pares, para que el origen caiga limpio


# Donde cae el ORIGEN del mundo (el punto en que el bicho toca el suelo) dentro del lienzo: centrado
# a lo ancho, pero bajo a lo alto, porque el cuerpo crece hacia arriba desde ahi.
static func _origen(escala: float) -> Vector2:
	var l: Vector2i = _lienzo(escala)
	return Vector2(float(l.x) * 0.5, float(l.y) * LIENZO_ARRIBA / (LIENZO_ARRIBA + LIENZO_ABAJO))


static func generar(color: Color = Color(1.0, 0.2, 0.2), corona: bool = false,
		escala: float = 1.0) -> SpriteFrames:
	# cuantizar_hsv y no cuantizar a secas: redondear canal a canal CAMBIA EL TONO de los colores
	# apagados. El Slime profundo (0.30, 0.40, 0.50) caia en (0.33, 0.33, 0.50) -- rojo y verde en el
	# mismo escalon -- y perdia su azul. Antes esto no se veia porque el slime de referencia era rojo
	# puro, con el canal rojo clavado en 1.
	var col: Color = SpriteLienzo.cuantizar_hsv(color, COLOR_PASOS)
	var esc: float = snappedf(escala, 0.05)      # se cuantiza tambien, o el cache no acierta
	var clave: String = _clave(col, corona, esc)
	if _cache.has(clave):
		return _cache[clave]
	# Las tres animaciones se recolectan primero y se montan de una vez: asi TODOS los frames caben
	# en un solo atlas recortado (ver SpriteLienzo.montar_frames), en vez de 192 texturas del tamaño
	# del lienzo entero -- que era casi todo aire.
	var anims: Array = []
	_montar_idle(anims, corona, esc)
	_montar_walk(anims, corona, esc)
	_montar_embestida(anims, corona, esc)
	_montar_inflar(anims, corona, esc)
	_montar_ignicion(anims, corona, esc)
	_montar_brote(anims, corona, esc)
	_montar_encaje(anims, corona, esc)
	_montar_muerte(anims, corona, esc)
	_montar_cadaver(anims, corona, esc)
	var lz: Vector2i = _lienzo(esc)
	var sf: SpriteFrames = SpriteLienzo.montar_frames(
		anims, SpriteLienzo.paleta(_colores(col, corona)), lz.x, lz.y)
	_cache[clave] = sf
	return sf


# Quieto: respira. El aplastado oscila muy poco y no se mueve del sitio.
static func _montar_idle(anims: Array, corona: bool, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return {"squash": 1.0 + 0.03 * sin(TAU * t), "avance": 0.0, "bote": 0.0}
	_montar_animacion(anims, corona, esc, "idle", true, 4.0, pose, false)


# Andando: aplastado al tocar suelo (t=0), estirado en el aire (t=0.5). El bote vertical usa la
# MISMA fase, asi que el cuerpo esta mas alto justo cuando esta mas estirado -- es lo que lo hace
# leer como un salto y no como un cuadrado respirando. Y como la sombra de contacto se queda en el
# suelo, la separacion entre las dos vende el salto sola.
static func _montar_walk(anims: Array, corona: bool, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return {"squash": 1.0 - 0.17 * cos(TAU * t), "avance": 0.0,
			"bote": BOTE * sin(PI * t)}
	_montar_animacion(anims, corona, esc, "walk", true, 8.0, pose, false)


# Agazapar -> lanzar -> impacto -> recuperar. NO es periodica (no vuelve al punto de partida), asi
# que va por TRAMOS en vez de una formula trigonometrica. El avance va en el eje LOCAL +Y, o sea
# hacia donde mira: al proyectar, ir hacia el norte sube menos en pantalla que ir hacia el este se
# desplaza de lado, y eso es justo lo correcto.
static func _montar_embestida(anims: Array, corona: bool, esc: float) -> void:
	var squash_keys := [[0.0, 1.0], [0.25, 0.60], [0.55, 1.25], [0.75, 0.70], [1.0, 0.95]]
	var avance_keys := [[0.0, 0.0], [0.25, 0.0], [0.55, 0.90], [0.75, 0.95], [1.0, 0.70]]
	var bote_keys := [[0.0, 0.0], [0.25, 0.0], [0.55, 1.0], [0.75, 0.15], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		return {"squash": SpriteLienzo.tramos(t, squash_keys),
			"avance": SpriteLienzo.tramos(t, avance_keys) * LUNGE_DIST,
			"bote": SpriteLienzo.tramos(t, bote_keys) * BOTE * 1.4}
	_montar_animacion(anims, corona, esc, "embestida", false, 10.0, pose, true)


# COGER AIRE E HINCHARSE: lo que hace antes de dejarse caer encima de todo el grupo. Se agacha
# aplastandose contra el suelo -que es como se lee "tomando impulso"-, se estira hacia arriba
# tragando aire y se queda hinchado y a punto de saltar.
#
# LO QUE CRECE DE VERDAD NO ES ESTO. Aqui solo va la deformacion: el tamaño al que llega -que
# depende de a cuantos tenga que cubrir- se lo pone el combate escalando la figura entera (ver
# CombatFX, gesto SALTO). Dibujarlo aqui obligaria a una animacion por cada numero de objetivos.
#
# El ultimo frame se queda HINCHADO a proposito (no vuelve al reposo): es la pose con la que sale
# disparado hacia arriba, y el salto empalma justo ahi.
static func _montar_inflar(anims: Array, corona: bool, esc: float) -> void:
	var squash_keys := [[0.0, 1.0], [0.30, 0.68], [0.62, 1.32], [0.82, 1.16], [1.0, 1.24]]
	var bote_keys := [[0.0, 0.0], [0.30, -0.25], [0.62, 0.35], [0.82, 0.20], [1.0, 0.55]]
	var pose := func(t: float) -> Dictionary:
		return {"squash": SpriteLienzo.tramos(t, squash_keys),
			"avance": 0.0,   # no se mueve: coge aire en el sitio
			"bote": SpriteLienzo.tramos(t, bote_keys) * BOTE}
	_montar_animacion(anims, corona, esc, "inflar", false, 9.0, pose, true)


# LA IGNICION del slime de fuego: se pone al rojo. No toca a nadie -- es un buff sobre si mismo --
# asi que el cuerpo no puede ir a ningun sitio.
#
# HASTA AHORA REPRODUCIA LA EMBESTIDA, o sea que el slime se abalanzaba sobre ti para PRENDERSE
# FUEGO A SI MISMO. Su efecto (el aura, que se queda en su tarjeta latiendo) se mantiene: eso es lo
# que dice que se ha encendido. Lo que sobraba era el placaje.
#
# UN SLIME TIENE DOS PALANCAS Y NADA MAS -- 'squash' y 'bote' --, asi que el gesto no puede salir de
# la forma: sale del RITMO. Aqui late DEPRISA y sin descanso (cambia de sentido en cada fotograma) y
# eso, al lado del vaiven lento y limpio del idle, se lee como algo que hierve. Y va CRECIENDO: cada
# pico es mas alto que el anterior, que es lo que lo separa de un temblor y lo convierte en algo que
# se esta cargando.
static func _montar_ignicion(anims: Array, corona: bool, esc: float) -> void:
	# Alterna en CADA fotograma, que es la unica manera de que ocho marcos parezcan deprisa. Un seno
	# de tres ciclos daria lo mismo sobre el papel y en la rejilla de ocho sale un solape feo (ver la
	# regla de las claves en los tiempos de los fotogramas).
	var squash_keys := [[0.0, 1.0], [0.143, 0.90], [0.286, 1.14], [0.429, 0.88], [0.571, 1.20],
		[0.714, 0.90], [0.857, 1.16], [1.0, 1.06]]
	var bote_keys := [[0.0, 0.0], [0.143, -0.10], [0.286, 0.16], [0.429, -0.08], [0.571, 0.22],
		[0.714, 0.0], [0.857, 0.18], [1.0, 0.08]]
	var pose := func(t: float) -> Dictionary:
		return {"squash": SpriteLienzo.tramos(t, squash_keys),
			"avance": 0.0,
			"bote": SpriteLienzo.tramos(t, bote_keys) * BOTE}
	# UNA SOLA DIRECCION: solo se ve en combate, y ahi se le mira de frente. Y ademas esto lo monta
	# TODO slime (el generador es comun), asi que ocho direcciones serian ocho veces el coste para
	# seis bichos que ni siquiera tienen la habilidad.
	_montar_animacion(anims, corona, esc, "ignicion", false, 12.0, pose, true, 1, 8)


# EL BROTE del Rey Slime: se estira hacia arriba y SE DESPLOMA, expulsando a las crias.
#
# HASTA AHORA NO TENIA NI EFECTO NI ANIMACION: su .tres es el unico del juego sin 'fx_estilo', asi
# que caia al fx_basico del Rey Slime, que es PLACAJE -- o sea que el jefe hacia un placaje entero,
# con su dibujo y todo, para invocar. Aqui se le da la animacion; el efecto se le pone en el .tres.
#
# ES EL REVES DE 'inflar', y esa es toda la idea. El Aplastamiento coge aire hacia ABAJO (squash a
# 0,68: se achata para saltar) y aqui se estira hacia ARRIBA y se deja caer. Las dos usan las mismas
# dos palancas, asi que si el reparto no fuera opuesto se leerian igual.
#
# EL TOPE LO PONE EL LIENZO DEL REY, y esta MEDIDO: 'squash' 1,40 con 'bote' 0,60 sacaba el fotograma
# 3 fuera del lienzo -- pero SOLO en la variante con corona, porque el Rey es el mas grande de los
# seis y el lienzo se le queda mas justo. El aviso del horno lo canta ("se sale del lienzo"), y por
# eso los numeros de aqui no pasan de los del 'inflar' (1,32 de estiron y 0,35 de bote), que es la
# pose mas alta que ya se sabe que cabe.
#
# Y ademas conviene por dibujo: el cuerpo se ensancha como 1/sqrt(squash), asi que estirarse lo
# ADELGAZA, y pasado ese punto el Rey Slime se convierte en un huso y deja de leerse como una gota.
static func _montar_brote(anims: Array, corona: bool, esc: float) -> void:
	var squash_keys := [[0.0, 1.0], [0.143, 0.90], [0.286, 1.22], [0.429, 1.32], [0.571, 0.74],
		[0.714, 0.90], [0.857, 1.08], [1.0, 1.0]]
	# Se eleva con el estiron y toca fondo al expulsar: el golpe contra el suelo es lo que echa fuera
	# a las crias.
	var bote_keys := [[0.0, 0.0], [0.143, -0.20], [0.286, 0.24], [0.429, 0.35], [0.571, -0.15],
		[0.714, 0.05], [0.857, 0.12], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		return {"squash": SpriteLienzo.tramos(t, squash_keys),
			"avance": 0.0,
			"bote": SpriteLienzo.tramos(t, bote_keys) * BOTE}
	_montar_animacion(anims, corona, esc, "brote", false, 10.0, pose, true, 1, 8)


# MORIRSE: SE DERRITE EN UN CHARCO. Ocho fotogramas en UNA sola direccion -- la muerte solo se ve
# en la pantalla de combate, y ahi al bicho se le mira siempre de frente. Para el mapa esta
# 'cadaver', que es al reves (un marco, ocho direcciones).
#
# No hace falta tumbarlo como a la rata o al jabali: una bola de gel no se cae de lado, se DESHACE.
# Coge un ultimo respingo (se hincha), y a partir de ahi se va escurriendo hasta quedar en una
# mancha con dos brillos.
#
# EL TOPE ES 0.42 DE SQUASH Y NO ES NEGOCIABLE: el cuerpo se ensancha como 1/sqrt(squash), asi que
# a 0.42 mide ya 1,54 veces lo suyo, y el lienzo solo da para 1,66. Por debajo de ~0.38 el charco
# sale CORTADO EN SECO por los lados -- y en el Rey Slime igual, porque su lienzo crece con el.
static func _pose_muerte(t: float) -> Dictionary:
	var squash_keys := [[0.0, 1.0], [0.14, 1.16], [0.28, 0.92], [0.45, 0.72],
		[0.62, 0.58], [0.78, 0.48], [0.90, 0.43], [1.0, 0.42]]
	# El derretido va POR DETRAS del aplastado a proposito: primero se desinfla (sigue siendo un
	# bicho aplastado, con sus cuernos) y solo despues pierde la forma. Yendo a la vez parecia que se
	# le caian los cuernos antes de empezar a morirse.
	var derr_keys := [[0.0, 0.0], [0.14, 0.0], [0.28, 0.12], [0.45, 0.38],
		[0.62, 0.64], [0.78, 0.86], [0.90, 0.97], [1.0, 1.0]]
	# Un ultimo bote al recibir el golpe, y ya nada mas: lo que queda no se despega del suelo.
	var bote_keys := [[0.0, 0.0], [0.14, 0.45], [0.28, 0.0], [1.0, 0.0]]
	return {"squash": SpriteLienzo.tramos(t, squash_keys),
		"avance": 0.0,   # no se va a ninguna parte: se deshace donde esta
		"bote": SpriteLienzo.tramos(t, bote_keys) * BOTE,
		"derretido": SpriteLienzo.tramos(t, derr_keys)}


static func _montar_muerte(anims: Array, corona: bool, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return _pose_muerte(t)
	_montar_animacion(anims, corona, esc, "muerte", false, 10.0, pose, true, 1, 8)


# EL CADAVER DEL MAPA: UN fotograma por CADA UNA de las ocho direcciones, que es justo al reves que
# 'muerte' (ocho fotogramas en una sola). No es un capricho de reparto, es lo que pide cada sitio:
# en combate al bicho se le ve morir de frente y una vez; en el mapa no se le ve morir -- se entra a
# la sala y ya esta tirado --, pero puede haber caido mirando a cualquier lado.
#
# Es EXACTAMENTE la pose final de la muerte, sacada de la misma funcion: escribir los numeros otra
# vez aqui es garantizar que el dia que se retoque la muerte el cadaver se quede como estaba, y que
# el bicho pegue un salto al pasar de una a otro.
static func _montar_cadaver(anims: Array, corona: bool, esc: float) -> void:
	var pose := func(_t: float) -> Dictionary:
		return _pose_muerte(1.0)
	# ultimo_incluido = false y NO true: con un solo marco, el divisor de _montar_animacion
	# seria (1 - 1) = 0 y el reparto de t saldria NaN. La pose se pide fija, asi que da igual.
	_montar_animacion(anims, corona, esc, "cadaver", false, 1.0, pose, false, 8, 1)


# ENCAJAR UN GOLPE. Cuatro fotogramas en UNA sola direccion: en la pantalla de combate al enemigo
# se le ve siempre de frente, asi que las otras siete serian 28 imagenes que no mira nadie. Pedida
# desde otra direccion degrada sola a la embestida (ver _on_gesto_iniciado en CombatFX).
#
# EMPIEZA YA GOLPEADO -- el frame 0 es el aplaston, no la pose de reposo. Un impacto no tiene
# anticipacion: si el primer fotograma es el slime quieto, lo que se ve es un retardo, y con cuatro
# marcos el retardo se come la animacion entera. De ahi sale por rebote (se estira pasandose), un
# temblor corto de vuelta, y el ultimo frame ya en reposo.
#
# El empujon va en -Y LOCAL, o sea hacia atras de donde mira: en combate el que pega esta enfrente.
static func _montar_encaje(anims: Array, corona: bool, esc: float) -> void:
	# Nada baja de 0.38 de squash: por debajo el cuerpo se ensancha como 1/sqrt(squash) y el charco
	# sale CORTADO EN SECO por los lados del lienzo (y en el Rey Slime igual, que va a escala 2.6).
	var squash_keys := [[0.0, 0.64], [0.34, 1.18], [0.67, 0.93], [1.0, 1.0]]
	var retro_keys := [[0.0, 1.0], [0.34, 0.55], [0.67, 0.18], [1.0, 0.0]]
	var bote_keys := [[0.0, 0.0], [0.34, 0.45], [0.67, 0.0], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		return {"squash": SpriteLienzo.tramos(t, squash_keys),
			"avance": -SpriteLienzo.tramos(t, retro_keys) * ENCAJE_RETRO,
			"bote": SpriteLienzo.tramos(t, bote_keys) * BOTE}
	# 18 fps para 4 marcos = 0,22 s. Tiene que caber DENTRO de un golpe: una rafaga de seis mordiscos
	# se ha de leer como seis sacudidas, no como un temblor continuo.
	_montar_animacion(anims, corona, esc, "encaje", false, 18.0, pose, true, 1, 4)


static func _montar_animacion(anims: Array, corona: bool, esc: float,
		nombre: String, loop: bool, fps: float,
		pose_fn: Callable, ultimo_incluido: bool, dirs: int = 8, marcos: int = FRAMES) -> void:
	# 'dirs' y 'marcos' van al final y con el valor de siempre a proposito: las animaciones que ya
	# existen no se enteran. Estan para las que NO necesitan las ocho direcciones ni los ocho
	# fotogramas -- en la pantalla de combate al bicho solo se le ve de frente, asi que morir son 8
	# marcos en UNA direccion; y el cadaver del mapa es UN marco por direccion, porque ahi solo tiene
	# que aparecer ya tirado en el suelo mirando adonde estaba.
	#
	# La clave de la cache de plantillas no cambia: ya lleva el nombre de la animacion, y cuantos
	# marcos tiene es cosa del nombre, asi que dos animaciones distintas no pueden pisarse.
	var divisor: float = float(marcos - 1) if ultimo_incluido else float(marcos)
	for dir in dirs:
		var plantillas: Array = []
		for i in marcos:
			# La GEOMETRIA se cachea por (animacion, frame, direccion, corona, escala) y NO por color:
			# otro slime de otro tono reusa estas plantillas y solo repinta. Es lo que evita que
			# entrar a un piso lleno de slimes congele el juego.
			var clave: String = "%s_%d_%d_%d_%.2f" % [nombre, i, dir, 1 if corona else 0, esc]
			var plant: PackedByteArray = _cache_plantillas.get(clave, PackedByteArray())
			if plant.is_empty():
				plant = _plantilla(dir, pose_fn.call(float(i) / divisor), corona, esc)
				_cache_plantillas[clave] = plant
			plantillas.append(plant)
		anims.append({"nombre": "%s_%d" % [nombre, dir], "loop": loop, "fps": fps,
			"plantillas": plantillas})


# Los colores de cada Tono, EN EL ORDEN DEL ENUM (contrato con SpriteLienzo.paleta).
static func _colores(color: Color, corona: bool) -> Array:
	return [
		Color(0, 0, 0, 0),                  # VACIO
		Color(0, 0, 0, 0.22),               # SOMBRA_SUELO
		color.darkened(0.55),               # BORDE
		# DETRAS: el ornamento que queda al otro lado de la cabeza. Ranura PROPIA y no reusar SOMBRA,
		# porque la cupula iluminada se pinta 'solo_sobre' SOMBRA e iria a aclarar justo la punta que
		# tiene que quedarse apagada.
		# Se APAGA mezclandolo con la penumbra del cuerpo, no oscureciendolo a secas: oscurecer el gel
		# claro de la corona la dejaba GRIS, y dos puntas grises asomando por la coronilla parecen unas
		# antenas pegadas, no una joya. Mezclado, lo de detras se hunde en el cuerpo sin cambiar de tono.
		_gel_ornamento(color, corona).lerp(color.darkened(0.28), 0.45),   # DETRAS
		color.darkened(0.28),               # SOMBRA (la panza, en penumbra)
		color,                              # BASE
		color.lightened(0.30),              # CLARO
		color.lightened(0.16),              # CLARO_TENUE
		_gel_ornamento(color, corona),      # ORNAMENTO (cuernos o corona)
		Color(0.95, 0.97, 0.85),            # OJO_T
		Color(1.0, 0.95, 0.72),             # GEMA
	]


# El gel de los ornamentos. Siempre SU PROPIO gel -- ni oro ni hueso ajeno -- pero tiene que
# DESTACAR contra el cuerpo, y ahi los dos casos tiran para lados contrarios:
#   * La CORONA del Rey va mas CLARA, que es como estaba y como se lee una joya.
#   * Los CUERNOS del slime normal iban del mismo color exacto que el cuerpo, y en 3/4 se salvaban
#     por el contorno; con la camara a 45 grados se comen la coronilla y "no se notan casi nada".
#     Van en gel DENSO: mas oscuro y mas saturado, como baba condensada. Oscurecer a secas no basta
#     -- se confundiria con la panza en sombra --, la saturacion es la que los separa.
static func _gel_ornamento(color: Color, corona: bool) -> Color:
	if corona:
		return color.lightened(0.40)
	var out := Color.from_hsv(color.h, minf(1.0, color.s * 1.30 + 0.10), color.v * 0.60)
	out.a = color.a
	return out


# ------------------------------------------------------------
#  GEOMETRIA
# ------------------------------------------------------------

# Las PIEZAS del slime para una pose, ya proyectadas a pantalla. Cada una es {pos, radio, persp,
# tono, solo_sobre}. El orden ES la profundidad: se pintan en ese orden y las ultimas tapan a las
# primeras, asi que va de lo mas lejano/bajo (la sombra del suelo, lo que queda detras de la cabeza)
# a lo mas cercano/alto (la cupula iluminada, los cuernos de delante, los brillos, los ojos).
static func _piezas(dir: int, pose: Dictionary, corona: bool, esc: float) -> Array:
	var ang: float = DIR_VECS[dir].angle() - DIR_VECS[0].angle()
	var u: float = esc / SpriteLienzo.UNIDADES_POR_CELDA    # unidades de mundo -> celdas
	var origen: Vector2 = _origen(esc)
	var squash: float = float(pose["squash"])
	var avance: float = float(pose["avance"])
	var bote: float = float(pose["bote"])
	# DERRETIRSE (0..1). Con default, o sea que las cuatro poses de siempre no lo notan.
	#
	# Es el UNICO campo que hacia falta para que el slime pueda morirse, y hacia falta porque
	# aplastarlo a secas NO da un charco: _piezas dibuja siempre los ornamentos, asi que salia una
	# torta con los dos cuernos y los dos ojos encima, tan tiesos como en vida. Lo que hace este
	# campo es lo otro: encoge cuernos y ojos hasta quitarlos, ensancha la mancha del suelo y aplana
	# la cupula iluminada, que es lo que borra el filo de panza en sombra. Lo demas -- que se
	# extienda a lo ancho -- ya lo da el squash solo.
	var derretido: float = clampf(float(pose.get("derretido", 0.0)), 0.0, 1.0)

	# Aplastado/estirado conservando el volumen a ojo: lo que se pierde de alto se gana de ancho.
	var alto: float = squash
	var ancho: float = 1.0 / sqrt(maxf(0.2, squash))
	# PERO UN CHARCO NO CONSERVA EL VOLUMEN: la baba se escurre y se mete entre las piedras. Al
	# derretirse se le quita parte de ese ensanchado, y no es un apaño estetico -- es lo unico que
	# hace que quepa. El aplastado de morirse (0.42) pide 1,54 veces el ancho, y el lienzo da 1,66
	# contando el contorno: el charco salia CORTADO EN SECO por los dos lados y por abajo, en las 19
	# variantes de slime. Y por abajo tambien, porque este 'ancho' se aplica igual a la PROFUNDIDAD,
	# asi que hincharlo baja el borde de la silueta ademas de abrirla.
	ancho *= lerpf(1.0, ENCAJE_CHARCO_ANCHO, derretido)

	var piezas: Array = []
	# local (x ancho, y largo, z altura, en unidades de mundo) -> celda de pantalla.
	#
	# 'gira' = false para lo que NO debe seguir al bicho al cambiar de rumbo: los brillos, que son un
	# reflejo de una luz clavada en el mundo, y la sombra del suelo.
	# 'sube' = false para lo que se queda pegado al suelo cuando el cuerpo bota o salta. Esa
	# separacion entre el bicho y su sombra es exactamente lo que se lee como "esta en el aire".
	# 'escorzo' < 1 comprime lo que la PROFUNDIDAD sube o baja esa pieza en pantalla. Es una trampa a
	# conciencia, y hace falta: dos cuernos simetricos, vistos de perfil, quedan uno delante y otro
	# detras, y con el escorzo entero el de detras subia el DOBLE de lo que asomaba el de delante --
	# se veia una antena solitaria saliendo de la coronilla en vez de un par de cuernos. Comprimido,
	# el par se lee junto desde los ocho lados. Es la misma licencia que ya se tomo con las orejas de
	# la rata, que se redondean para que no salgan de canto.
	# EL AVANCE DE LA EMBESTIDA SE ROTA UNA VEZ, APARTE, Y SE SUMA A TODAS LAS PIEZAS POR IGUAL.
	# Iba sumado a la Y local ANTES de rotar, y eso solo funcionaba para las piezas que giran: el
	# cuerpo, la cupula y los brillos no giran, asi que su avance se quedaba sin rotar y salian
	# disparados SIEMPRE hacia el sur de la pantalla mientras los cuernos y los ojos se lanzaban hacia
	# donde de verdad miraba el bicho. En las embestidas hacia arriba la cara se despegaba del cuerpo y
	# se iba volando. El desplazamiento es del BICHO ENTERO: se calcula una vez y lo llevan todos.
	var desp := Vector2(0.0, avance).rotated(ang)
	var poner := func(local: Vector3, r: Vector3, tono: int, solo_sobre: Array = [],
			gira: bool = true, sube: bool = true, escorzo: float = 1.0) -> void:
		var p := Vector2(local.x * ancho, local.y * ancho)
		var rot: Vector2 = (p.rotated(ang) if gira else p) + desp
		var z: float = local.z * alto + (bote if sube else 0.0)
		# LA PROYECCION: la profundidad se encoge por cos(45) y la altura SUBE por sin(45). Ese "- z"
		# es lo que pone la coronilla por encima de la base y hace que se le vea el costado.
		var sx: float = origen.x + rot.x * u
		var sy: float = origen.y + (rot.y * escorzo * SpriteLienzo.COS_CAM - z * SpriteLienzo.SIN_CAM) * u
		# El aplastado en pantalla sale de la geometria, no de un numero a ojo: ver persp_de.
		var ry: float = r.y * ancho
		piezas.append({"pos": Vector2(sx, sy), "radio": Vector2(r.x * ancho * u, ry * u),
			"persp": SpriteLienzo.persp_de(ry, r.z * alto), "tono": tono, "solo_sobre": solo_sobre})

	# 1. SOMBRA DE CONTACTO. Acompaña al bicho por el suelo cuando se lanza (pasa por 'avance') pero
	#    NO sube con el: z = 0 y 'sube' = false.
	# Al derretirse se ensancha un poco: es la baba escurriendose. Con 1.9 se salia del lienzo -- la
	# mancha es lo que MAS asoma cuando el cuerpo ya esta plano, asi que es la primera en cortarse.
	poner.call(Vector3.ZERO, SOMBRA_R * (1.0 + 0.45 * derretido), Tono.SOMBRA_SUELO, [], false, false)

	# 2 y 5. ORNAMENTOS. Los que quedan DETRAS van antes del cuerpo (que los tapa) y en tono apagado;
	#    los de delante, despues. Cual es cual sale de su Y YA GIRADA -- una prueba de profundidad de
	#    verdad, no una tabla por direccion que haya que mantener a mano.
	# DERRETIDO, LOS ORNAMENTOS SE VAN. Un charco no tiene cuernos tiesos ni corona en pie: se hunden
	# con el resto del gel. Por debajo de un pelin ya no se dibujan, en vez de quedarse como dos
	# chinchetas clavadas en la mancha.
	var orn_esc: float = 1.0 - derretido
	var ornamentos: Array = ([] if orn_esc < 0.12 else _ornamentos(corona))
	var delante: Array = []
	for orn in ornamentos:
		var base: Vector3 = orn["base"]
		if Vector2(base.x, base.y).rotated(ang).y > 0.0:
			delante.append(orn)
			continue
		# El de detras, mas pequeño: sin eso los dos asoman iguales por la coronilla y parecen gemelos.
		_pincho(poner, orn, ORNAMENTO_DETRAS_ESC * orn_esc, Tono.DETRAS, Tono.DETRAS)

	# 3. EL CUERPO, entero en SOMBRA...
	poner.call(CUERPO, CUERPO_R, Tono.SOMBRA, [], false)
	# 4. ...y encima la misma bola algo menor y SUBIDA, en BASE. Lo que se queda sin cubrir por abajo
	#    es la panza en penumbra, y la frontera entre las dos sale curvada sola.
	# Al derretirse la cupula BAJA hasta centrarse: el filo de panza en penumbra se cierra y lo que
	# queda es una mancha de un solo tono, que es como se lee un charco. Con la cupula en su sitio,
	# el charco seguia teniendo una banda oscura debajo y parecia un cuerpo aplastado, no baba.
	poner.call(Vector3(CUERPO.x, CUERPO.y, CUERPO.z + CUERPO_R.z * CUPULA_SUBE * (1.0 - derretido)),
		CUERPO_R * lerpf(CUPULA_ESC, 1.0, derretido), Tono.BASE, [Tono.SOMBRA], false)

	# 5. Los ornamentos de DELANTE, ya sobre el cuerpo. Sin contorno propio contra el: se probo para
	#    "recortarlos" y queda peor -- como el cuerno nace justo en el filo de la cabeza, esa linea lo
	#    convierte en una pastilla suelta pegada al costado. El contorno va SOLO contra el vacio.
	for orn in delante:
		_pincho(poner, orn, orn_esc, Tono.ORNAMENTO, Tono.GEMA)

	# 6. BRILLOS especulares: dos manchas claras en la cresta. NO giran (la luz esta clavada en el
	#    mundo, no en el bicho) y van 'solo_sobre' BASE para no derramarse sobre los cuernos ni el
	#    contorno. Se colocan en fracciones del cuerpo, asi que escalan solos con el squash.
	_brillo(poner, BRILLO_A, Tono.CLARO)
	_brillo(poner, BRILLO_B, Tono.CLARO_TENUE)

	# 7. OJOS. Van adelantados en Y, asi que al girar se van solos al otro lado del cuerpo: basta con
	#    no dibujar los que quedan detras. De espaldas no se le ve ninguno -- se lee de un vistazo si
	#    viene o si huye -- y de perfil, uno.
	# Y LOS OJOS SE APAGAN CON EL RESTO. Dos ojos abiertos flotando sobre un charco es la imagen mas
	# rara de todo esto: parece que el bicho sigue mirandote desde dentro del suelo.
	var ojos: Array = []
	for l in ([] if derretido > 0.55 else [-1.0, 1.0]):
		var d := Vector3(l * OJO_DIR.x, OJO_DIR.y, OJO_DIR.z)
		var fondo: float = Vector2(d.x, d.y).rotated(ang).y
		if fondo > OJO_VISIBLE:
			ojos.append({"pos": _en_el_cuerpo(d, OJO_HUNDE), "fondo": fondo})
	# DE PERFIL PURO, UNO SOLO. Ahi los dos caen en la MISMA X de pantalla y se separan solo en
	# vertical: dos ojos uno encima del otro no se leen como una cara, se leen como un borron. Es la
	# misma regla que ya tenia la version en 3/4, y por el mismo motivo.
	if absf(DIR_VECS[dir].x) >= 0.9 and ojos.size() == 2:
		ojos = [ojos[0] if float(ojos[0]["fondo"]) > float(ojos[1]["fondo"]) else ojos[1]]
	for o in ojos:
		poner.call(o["pos"], OJO_R * (1.0 - derretido * 1.6), Tono.OJO_T, [], true, true, OJO_ESCORZO)

	return piezas


# Un pincho (cuerno o punta de corona) y, si la lleva, su gema. Se coloca desde la BASE, que es la
# que esta anclada al cuerpo, y crece hacia arriba su propio semialto.
#
# ESTO ERA UN BUG: el de detras se dibujaba encogiendole el radio pero dejandole el centro donde
# estaba, asi que la base se le subia sola y el pincho salia DESPEGADO, flotando sobre la cabeza.
# Con la base como ancla, encoger no lo puede despegar.
static func _pincho(poner: Callable, orn: Dictionary, esc: float, tono: int, tono_gema: int) -> void:
	var base: Vector3 = orn["base"]
	var r: Vector3 = Vector3(orn["radio"]) * esc
	var centro: Vector3 = base + Vector3(0, 0, r.z)
	poner.call(centro, r, tono, [], true, true, ORNAMENTO_ESCORZO)
	if bool(orn["gema"]):
		poner.call(centro + Vector3(0, 0, r.z * 0.72), Vector3(GEMA_R) * esc, tono_gema,
			[], true, true, ORNAMENTO_ESCORZO)


# Un brillo, en fracciones del CUERPO proyectado (x, y sobre el centro de la bola; z = radio). Se
# expresa asi -- y no en unidades de mundo -- para que siga la silueta al aplastarse o estirarse.
static func _brillo(poner: Callable, f: Vector3, tono: int) -> void:
	var rx: float = CUERPO_R.x * f.z
	poner.call(Vector3(CUERPO_R.x * f.x, 0.0, CUERPO.z - CUERPO_R.z * f.y * 1.6),
		Vector3(rx, rx, rx), tono, [Tono.BASE], false)


# Una direccion desde el centro del cuerpo -> el punto de la SUPERFICIE del elipsoide en esa
# direccion, metido 'hunde' unidades hacia dentro. Es lo que garantiza que nada flote: la superficie
# esta a una distancia distinta en cada direccion (el cuerpo tiene menos fondo que ancho), asi que
# un punto puesto a mano encaja mirando a un lado y se despega mirando al otro.
static func _en_el_cuerpo(dir: Vector3, hunde: float) -> Vector3:
	var d: Vector3 = dir.normalized()
	var p := Vector3(CUERPO_ANCLA_R.x * d.x, CUERPO_ANCLA_R.y * d.y, CUERPO_ANCLA_R.z * d.z)
	return CUERPO + p - d * hunde


# Los ornamentos de la cabeza en coordenadas LOCALES (mirando al sur): los dos cuernos del slime
# normal, o las 5 puntas de la corona del Rey. La corona SUSTITUYE a los cuernos, no se suma.
# Cada uno se ancla al cuerpo por su direccion: 'base' es el punto (ya hundido) del que NACE, y de
# ahi crece hacia arriba en _pincho. Se guarda la base y no el centro justamente para que encogerlo
# no lo despegue.
static func _ornamentos(corona: bool) -> Array:
	var out: Array = []
	if not corona:
		for l in [-1.0, 1.0]:
			var base: Vector3 = _en_el_cuerpo(
				Vector3(l * CUERNO_DIR.x, CUERNO_DIR.y, CUERNO_DIR.z), CUERNO_HUNDE)
			out.append({"base": base, "radio": CUERNO_R, "gema": false})
		return out
	for k in CORONA_PUNTAS:
		# k = 0 cae justo al frente (+Y), que es donde estaba el pico central de la version en 3/4.
		var a: float = PI * 0.5 + TAU * float(k) / float(CORONA_PUNTAS)
		var base: Vector3 = _en_el_cuerpo(
			Vector3(cos(a) * CORONA_ANILLO, sin(a) * CORONA_ANILLO, CORONA_ALTO), CORONA_HUNDE)
		out.append({"base": base, "radio": CORONA_PUNTA_R, "gema": true})
	return out


# La plantilla de un frame: que tono le toca a cada celda.
static func _plantilla(dir: int, pose: Dictionary, corona: bool, esc: float) -> PackedByteArray:
	var lz: Vector2i = _lienzo(esc)
	var plant := PackedByteArray()
	plant.resize(lz.x * lz.y)
	var piezas: Array = _piezas(dir, pose, corona, esc)

	# TODO EL SLIME son piezas, en orden. Ojos, brillos y cuernos ESTAN ENTRE ELLAS a proposito: si se
	# dibujaran aparte no pasarian por la misma transformacion, y en la embestida el cuerpo saldria
	# disparado dejandoselos clavados en el sitio.
	for p in piezas:
		var pos: Vector2 = p["pos"]
		var r: Vector2 = p["radio"]
		SpriteLienzo.elipse(plant, lz.x, lz.y, pos.x, pos.y, r.x, r.y, int(p["tono"]),
			0.0, p["solo_sobre"], float(p["persp"]))

	# CONTORNO al final, sobre la silueta ya completa (ver SpriteLienzo.contornear). La sombra del
	# suelo cuenta como hueco: es una mancha translucida, no parte del bicho, y perfilarla la
	# convertiria en un charco con borde.
	SpriteLienzo.contornear(plant, SpriteLienzo.caja_de_piezas(piezas, lz.x, lz.y), lz.x, lz.y,
		Tono.BORDE, Tono.VACIO, Tono.SOMBRA_SUELO)
	return plant


