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
const CUERNO_HUNDE := 0.5          # cuanto se mete la BASE del pincho bajo la superficie
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
	return Vector2(DIAMETRO_MUNDO, DIAMETRO_MUNDO) * escala


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
	var clave: String = "%s_%.2f%s" % [col.to_html(false), esc, "_corona" if corona else ""]
	if _cache.has(clave):
		return _cache[clave]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	_montar_idle(sf, col, corona, esc)
	_montar_walk(sf, col, corona, esc)
	_montar_embestida(sf, col, corona, esc)
	_cache[clave] = sf
	return sf


# Quieto: respira. El aplastado oscila muy poco y no se mueve del sitio.
static func _montar_idle(sf: SpriteFrames, color: Color, corona: bool, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return {"squash": 1.0 + 0.03 * sin(TAU * t), "avance": 0.0, "bote": 0.0}
	_montar_animacion(sf, color, corona, esc, "idle", true, 4.0, pose, false)


# Andando: aplastado al tocar suelo (t=0), estirado en el aire (t=0.5). El bote vertical usa la
# MISMA fase, asi que el cuerpo esta mas alto justo cuando esta mas estirado -- es lo que lo hace
# leer como un salto y no como un cuadrado respirando. Y como la sombra de contacto se queda en el
# suelo, la separacion entre las dos vende el salto sola.
static func _montar_walk(sf: SpriteFrames, color: Color, corona: bool, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return {"squash": 1.0 - 0.17 * cos(TAU * t), "avance": 0.0,
			"bote": BOTE * sin(PI * t)}
	_montar_animacion(sf, color, corona, esc, "walk", true, 8.0, pose, false)


# Agazapar -> lanzar -> impacto -> recuperar. NO es periodica (no vuelve al punto de partida), asi
# que va por TRAMOS en vez de una formula trigonometrica. El avance va en el eje LOCAL +Y, o sea
# hacia donde mira: al proyectar, ir hacia el norte sube menos en pantalla que ir hacia el este se
# desplaza de lado, y eso es justo lo correcto.
static func _montar_embestida(sf: SpriteFrames, color: Color, corona: bool, esc: float) -> void:
	var squash_keys := [[0.0, 1.0], [0.25, 0.60], [0.55, 1.25], [0.75, 0.70], [1.0, 0.95]]
	var avance_keys := [[0.0, 0.0], [0.25, 0.0], [0.55, 0.90], [0.75, 0.95], [1.0, 0.70]]
	var bote_keys := [[0.0, 0.0], [0.25, 0.0], [0.55, 1.0], [0.75, 0.15], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		return {"squash": SpriteLienzo.tramos(t, squash_keys),
			"avance": SpriteLienzo.tramos(t, avance_keys) * LUNGE_DIST,
			"bote": SpriteLienzo.tramos(t, bote_keys) * BOTE * 1.4}
	_montar_animacion(sf, color, corona, esc, "embestida", false, 10.0, pose, true)


static func _montar_animacion(sf: SpriteFrames, color: Color, corona: bool, esc: float,
		nombre: String, loop: bool, fps: float, pose_fn: Callable, ultimo_incluido: bool) -> void:
	var divisor: float = float(FRAMES - 1) if ultimo_incluido else float(FRAMES)
	var paleta: PackedByteArray = SpriteLienzo.paleta(_colores(color, corona))
	var lz: Vector2i = _lienzo(esc)
	for dir in 8:
		var anim: String = "%s_%d" % [nombre, dir]
		sf.add_animation(anim)
		sf.set_animation_loop(anim, loop)
		sf.set_animation_speed(anim, fps)
		for i in FRAMES:
			# La GEOMETRIA se cachea por (animacion, frame, direccion, corona, escala) y NO por color:
			# otro slime de otro tono reusa estas plantillas y solo repinta. Es lo que evita que
			# entrar a un piso lleno de slimes congele el juego.
			var clave: String = "%s_%d_%d_%d_%.2f" % [nombre, i, dir, 1 if corona else 0, esc]
			var plant: PackedByteArray = _cache_plantillas.get(clave, PackedByteArray())
			if plant.is_empty():
				plant = _plantilla(dir, pose_fn.call(float(i) / divisor), corona, esc)
				_cache_plantillas[clave] = plant
			sf.add_frame(anim, SpriteLienzo.a_textura(plant, paleta, lz.x, lz.y))


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

	# Aplastado/estirado conservando el volumen a ojo: lo que se pierde de alto se gana de ancho.
	var alto: float = squash
	var ancho: float = 1.0 / sqrt(maxf(0.2, squash))

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
	poner.call(Vector3.ZERO, SOMBRA_R, Tono.SOMBRA_SUELO, [], false, false)

	# 2 y 5. ORNAMENTOS. Los que quedan DETRAS van antes del cuerpo (que los tapa) y en tono apagado;
	#    los de delante, despues. Cual es cual sale de su Y YA GIRADA -- una prueba de profundidad de
	#    verdad, no una tabla por direccion que haya que mantener a mano.
	var ornamentos: Array = _ornamentos(corona)
	var delante: Array = []
	for orn in ornamentos:
		var base: Vector3 = orn["base"]
		if Vector2(base.x, base.y).rotated(ang).y > 0.0:
			delante.append(orn)
			continue
		# El de detras, mas pequeño: sin eso los dos asoman iguales por la coronilla y parecen gemelos.
		_pincho(poner, orn, ORNAMENTO_DETRAS_ESC, Tono.DETRAS, Tono.DETRAS)

	# 3. EL CUERPO, entero en SOMBRA...
	poner.call(CUERPO, CUERPO_R, Tono.SOMBRA, [], false)
	# 4. ...y encima la misma bola algo menor y SUBIDA, en BASE. Lo que se queda sin cubrir por abajo
	#    es la panza en penumbra, y la frontera entre las dos sale curvada sola.
	poner.call(Vector3(CUERPO.x, CUERPO.y, CUERPO.z + CUERPO_R.z * CUPULA_SUBE),
		CUERPO_R * CUPULA_ESC, Tono.BASE, [Tono.SOMBRA], false)

	# 5. Los ornamentos de DELANTE, ya sobre el cuerpo. Sin contorno propio contra el: se probo para
	#    "recortarlos" y queda peor -- como el cuerno nace justo en el filo de la cabeza, esa linea lo
	#    convierte en una pastilla suelta pegada al costado. El contorno va SOLO contra el vacio.
	for orn in delante:
		_pincho(poner, orn, 1.0, Tono.ORNAMENTO, Tono.GEMA)

	# 6. BRILLOS especulares: dos manchas claras en la cresta. NO giran (la luz esta clavada en el
	#    mundo, no en el bicho) y van 'solo_sobre' BASE para no derramarse sobre los cuernos ni el
	#    contorno. Se colocan en fracciones del cuerpo, asi que escalan solos con el squash.
	_brillo(poner, BRILLO_A, Tono.CLARO)
	_brillo(poner, BRILLO_B, Tono.CLARO_TENUE)

	# 7. OJOS. Van adelantados en Y, asi que al girar se van solos al otro lado del cuerpo: basta con
	#    no dibujar los que quedan detras. De espaldas no se le ve ninguno -- se lee de un vistazo si
	#    viene o si huye -- y de perfil, uno.
	var ojos: Array = []
	for l in [-1.0, 1.0]:
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
		poner.call(o["pos"], OJO_R, Tono.OJO_T, [], true, true, OJO_ESCORZO)

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


