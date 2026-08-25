# ============================================================
#  rata_sprites.gd  (class_name RataSprites)
#  Sprite de la RATA dibujado por codigo, con el motor comun (SpriteLienzo). Cubre a los dos ROEDOR
#  del juego: la rata de mazmorra y el Rey rata (variante &"rey": cola anudada, oreja rasgada y
#  cicatriz).
#
#  DOS COSAS LA SEPARAN DEL SLIME:
#
#  1. LA RATA ES UN CUERPO CON ALTURA, NO UNA PLANTA APLASTADA. Cada pieza vive en 3D (x a lo
#     ancho, y a lo largo, z de altura sobre el suelo) y se proyecta con la camara a 45 grados:
#         pantalla_x = x
#         pantalla_y = y * cos(45) - z * sin(45)
#     Ese "- z" es lo que hace que las orejas y el lomo queden POR ENCIMA de las patas en pantalla,
#     y por tanto que de perfil se le vea el COSTADO. El primer intento no tenia z -- solo aplastaba
#     la silueta vista en planta -- y por eso, por mucho que se aplastara, seguia leyendose "visto
#     desde arriba": sin altura no hay costado que ver.
#
#  2. EL CUERPO ENTERO GIRA con la direccion. En el slime (que esta en 3/4 mirando a camara) rotar
#     salio fatal porque alli solo giraban los detalles sobre un cuerpo que no giraba; aqui gira la
#     figura completa, que es lo que hace un animal al cambiar de rumbo.
#
#  El TAMAÑO se consigue con MAS CELDAS, no con celdas mas gordas: ver SpriteLienzo.UNIDADES_POR_CELDA.
#  El Rey rata (escala_visual 1.2) se dibuja en una rejilla mayor que la rata (0.85) y los dos tienen
#  el pixel del mismo tamaño en pantalla.
#
#  Su identidad, sacada de sus habilidades (mordisco sangrante, frenesi de dentelladas, a la
#  yugular): DIENTES, SANGRE y VELOCIDAD. Nada de veneno. Es menuda y rapida (anda a 45-75, el
#  slime a 30-55), asi que su ciclo de paso va mas vivo.
# ============================================================

extends RefCounted
class_name RataSprites

const FRAMES := 8

# --- Camara. 45 grados: ni cenital pura (que se lee como un mapa y queda rara) ni de perfil. ---
const CAMARA_GRADOS := 45.0
const COS_CAM := cos(deg_to_rad(CAMARA_GRADOS))   # cuanto se encoge la PROFUNDIDAD
const SIN_CAM := sin(deg_to_rad(CAMARA_GRADOS))   # cuanto sube en pantalla la ALTURA

# --- La rata mirando al SUR, en unidades de MUNDO (origen = centro del cuerpo a ras de suelo,
# +Y hacia el morro, +Z hacia arriba). Es un bicho de ~19 unidades de largo a escala 1.0. ---
const CUERPO := Vector3(0.0, 0.0, 2.4)            # centro (z = a que altura flota su eje)
const CUERPO_R := Vector3(4.2, 5.9, 2.9)          # ancho, largo, alto
const CABEZA := Vector3(0.0, 6.2, 2.5)
const CABEZA_R := Vector3(2.9, 2.8, 2.5)
const HOCICO := Vector3(0.0, 8.8, 1.9)
const HOCICO_R := Vector3(1.5, 1.7, 1.4)
const OREJA := Vector3(2.9, 6.6, 4.3)             # x = separacion; van ARRIBA de la cabeza
# Redondas en los tres ejes A PROPOSITO. De verdad son dos discos finos, y dibujandolas asi, de
# perfil se veian DE CANTO: una rayita negra en vez de una oreja. Las orejas son la marca de la
# rata y tienen que leerse desde cualquier lado, aunque sea hacer un poco de trampa.
const OREJA_R := Vector3(1.8, 1.5, 1.8)
const OJO := Vector3(1.9, 7.2, 3.1)
const OJO_R := Vector3(0.75, 0.75, 0.75)
const PATA_X := 3.6
const PATA_Y := [3.1, -2.8]                       # delanteras y traseras
const PATA_R := Vector3(1.2, 1.5, 0.9)            # bajas y aplastadas: van pegadas al suelo
const PATA_Z := 0.7
# COLA: cadena de segmentos que sale por DETRAS (-Y), casi a ras de suelo, y se va afinando.
# EL PASO TIENE QUE SER MENOR QUE EL GROSOR o la cola sale a TROZOS SUELTOS flotando detras del
# bicho. Y ojo: al serpear, dos segmentos seguidos se separan ademas de lado, asi que el paso
# efectivo es mayor que COLA_PASO -- por eso va holgado.
# Y con el pixel mas gordo hay que ser MAS generoso todavia: 0,85 de paso contra 0,66 de radio de
# punta daba un diametro de poco mas de una celda, y al serpear la punta se soltaba en el idle. El
# paso baja y la punta engorda.
const COLA_SEGMENTOS := 14
const COLA_PASO := 0.72
const COLA_R0 := 1.25
const COLA_R1 := 0.82
# La cola SALE A LA ALTURA DEL CUERPO y va CAYENDO hasta el suelo. No es un adorno: naciendo ya a
# ras de suelo se DESPEGABA del cuerpo en cuanto se veia de perfil, porque al proyectar, lo que
# esta alto sube en pantalla y lo que esta bajo no -- y entre la grupa (elevada) y el arranque de
# la cola (por el suelo) se abria un hueco.
const COLA_Z0 := 2.2                   # altura donde nace, la de la grupa
const COLA_Z1 := 0.55                  # altura de la punta, arrastrando
const COLA_DESFASE := 0.75

# Cuanto se aplasta cada tipo de pieza en el eje VERTICAL DE PANTALLA (ver 'chato' en _piezas).
# Una cosa PLANA tumbada en el suelo se ve con todo el escorzo de la camara -> cos(45) = 0.707.
# Una ESFERA se proyecta como un circulo mire por donde se mire -> casi 1.
# El cuerpo esta en medio: es alargado y tumbado, pero tiene lomo, asi que se queda entre los dos.
#
# Estan A OJO, y se quedan asi: el motor tiene SpriteLienzo.persp_de(), que saca el valor EXACTO de
# los semiejes de la pieza, pero cambiarlos ahora le moveria pixeles a una rata que ya esta dada por
# buena. Los bichos nuevos si usan persp_de.
const CHATO_TUMBADO := SpriteLienzo.COS_CAM
const CHATO_CUERPO := 0.88
const CHATO_REDONDO := 0.95
const CHATO_OREJA := 0.92

# Largo total del bicho a escala 1.0 (de la punta del morro a la punta de la cola), en unidades de
# mundo. Sirve para dimensionar el lienzo.
const LARGO_MUNDO := 24.0

# ENCAJAR UN GOLPE: cuanto la empuja hacia atras el impacto (unidades de mundo, eje local -Y). Su
# embestida se lanza 5.8 hacia delante, asi que esto es como un tercio: la sacudida tiene que
# leerse como un golpe encajado, no como una segunda embestida al reves.
const ENCAJE_RETRO := 1.9

# TONOS propios (el motor no sabe que es cada uno; solo mapea indice -> color, ver _colores).
enum Tono { VACIO, SOMBRA_SUELO, BORDE, SOMBRA, BASE, LOMO, OREJA_INT, OJO_T, COLA, CICATRIZ }

# --- Vectores de las 8 direcciones (pantalla: +Y es hacia ABAJO). Mismo orden que SlimeSprites y
# que el _dir8 de enemy.gd: 0=S 1=SE 2=E 3=NE 4=N 5=NW 6=W 7=SW. ---
const DIR_VECS := [
	Vector2(0, 1), Vector2(0.7, 0.7), Vector2(1, 0), Vector2(0.7, -0.7),
	Vector2(0, -1), Vector2(-0.7, -0.7), Vector2(-1, 0), Vector2(-0.7, 0.7),
]

const COLOR_PASOS := 6.0
static var _cache: Dictionary = {}
static var _cache_plantillas: Dictionary = {}


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t), ed.sprite_variante == &"rey", ed.escala_visual)


# La CLAVE de esta variante: la del cache y la del fichero horneado (ver SpriteLienzo.hornear).
static func clave_de(ed: EnemyData, t: float) -> String:
	return _clave(SpriteLienzo.cuantizar_hsv(ed.color_visual(t), COLOR_PASOS),
		ed.sprite_variante == &"rey", snappedf(ed.escala_visual, 0.05))


static func _clave(col: Color, rey: bool, esc: float) -> String:
	return "rata_%s_%.2f%s" % [col.to_html(false), esc, "_rey" if rey else ""]


# El pixel mide lo mismo para TODOS los bichos: el tamaño sale de cuantas celdas ocupa cada uno.
static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(escala: float = 1.0) -> int:
	return _celdas(escala)


# true: el tamaño ya va DENTRO del dibujo (el Rey rata se dibuja con mas celdas que la rata), asi
# que nadie debe volver a estirar el sprite -- si no, sus pixeles saldrian mas gordos.
static func dimensiona_por_escala() -> bool:
	return true


# El CUERPO en planta (ancho, largo) en unidades de mundo: con esto enemy.gd le hace una colision a
# su medida en vez de la caja de 32x32 de siempre. Es la MEDIDA DEL BICHO, no la del dibujo:
#   * LA COLA NO CUENTA. Es un hilo que se menea, y meterla en la colision haria que la rata chocara
#     con las paredes por algo que ni se ve. Por eso tampoco vale LARGO_MUNDO, que si la incluye.
#   * El ancho lo marcan las PATAS (van mas abiertas que el cuerpo), no el lomo.
# Sale rectangular y alargada a proposito: una rata es un bicho estrecho y largo, y asi es como
# tiene que estorbar en un pasillo -- de lado ocupa, de frente casi no.
static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	var ancho: float = (PATA_X + PATA_R.x) * 2.0
	var largo: float = (HOCICO.y + HOCICO_R.y) + CUERPO_R.y
	return Vector2(ancho, largo) * escala


# Cuantas celdas de lado necesita el lienzo para una escala dada. CUADRADO y holgado: al girar, lo
# que manda es la DIAGONAL de la figura (cuerpo + cola), y ademas la embestida la desplaza.
static func _celdas(escala: float) -> int:
	# El 1.85 no es a ojo: el bicho tiene que caber girado en diagonal Y desplazado por el salto de
	# la embestida, y ademas la cola sale muy por detras. Ajustado a que no se recorte ni un frame.
	var lado: int = int(ceil(LARGO_MUNDO * escala * 1.85 / SpriteLienzo.UNIDADES_POR_CELDA))
	return lado + (lado % 2)      # par, para que el centro caiga limpio


static func generar(color: Color = Color(0.5, 0.42, 0.34), rey: bool = false,
		escala: float = 1.0) -> SpriteFrames:
	# cuantizar_hsv y no cuantizar a secas: la rata es de color apagado (marron leonado) y
	# redondear canal a canal le igualaba el rojo con el verde -> el Rey salia VERDE OLIVA.
	var col: Color = SpriteLienzo.cuantizar_hsv(color, COLOR_PASOS)
	var esc: float = snappedf(escala, 0.05)      # se cuantiza tambien, o el cache no acierta
	var clave: String = _clave(col, rey, esc)
	if _cache.has(clave):
		return _cache[clave]
	# Todo en UN atlas recortado (ver SpriteLienzo.montar_frames): 192 texturas del tamaño del
	# lienzo entero eran casi todo aire -- en la rata, un 86%.
	var anims: Array = []
	_montar_idle(anims, rey, esc)
	_montar_walk(anims, rey, esc)
	_montar_embestida(anims, rey, esc)
	_montar_encaje(anims, rey, esc)
	_montar_muerte(anims, rey, esc)
	_montar_cadaver(anims, rey, esc)
	var lado: int = _celdas(esc)
	var sf: SpriteFrames = SpriteLienzo.montar_frames(
		anims, SpriteLienzo.paleta(_colores(col, rey)), lado, lado)
	_cache[clave] = sf
	return sf


# Quieta: respira y menea la cola despacio. Nada de desplazamiento.
static func _montar_idle(anims: Array, rey: bool, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return {"avance": 0.0, "estira": 1.0 + 0.025 * sin(TAU * t),
			"cola": 0.45 * sin(TAU * t), "patas": 0.0, "agacha": 0.0}
	_montar_animacion(anims, rey, esc, "idle", true, 5.0, pose, false)


# Andando: las patas alternan, el cuerpo se mece y la cola serpea con ganas. A 10 fps (el slime va
# a 8): es un bicho rapido y el paso tiene que leerse nervioso, no de paseo.
static func _montar_walk(anims: Array, rey: bool, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return {"avance": 0.0, "estira": 1.0 + 0.05 * sin(TAU * t * 2.0),
			"cola": 1.0 * sin(TAU * t), "patas": sin(TAU * t), "agacha": 0.0}
	_montar_animacion(anims, rey, esc, "walk", true, 10.0, pose, false)


# Agazaparse -> lanzarse -> chocar -> recomponerse. NO es periodica, asi que va por TRAMOS.
# Encaja con su Frenesi de dentelladas, que ya tiene una pose de carga de un turno en su .tres.
static func _montar_embestida(anims: Array, rey: bool, esc: float) -> void:
	var avance_keys := [[0.0, 0.0], [0.25, -1.2], [0.55, 5.0], [0.75, 5.8], [1.0, 4.0]]
	var estira_keys := [[0.0, 1.0], [0.25, 0.82], [0.55, 1.2], [0.75, 0.9], [1.0, 1.0]]
	var agacha_keys := [[0.0, 0.0], [0.25, 1.0], [0.55, 0.0], [0.75, 0.35], [1.0, 0.1]]
	var pose := func(t: float) -> Dictionary:
		return {"avance": SpriteLienzo.tramos(t, avance_keys),
			"estira": SpriteLienzo.tramos(t, estira_keys),
			"cola": 1.4 * sin(TAU * t * 1.5), "patas": 0.0,
			"agacha": SpriteLienzo.tramos(t, agacha_keys)}
	_montar_animacion(anims, rey, esc, "embestida", false, 11.0, pose, true)


# MORIRSE. OCHO fotogramas en UNA sola direccion: la muerte solo se ve en la pantalla de combate, y
# ahi al bicho se le mira siempre de frente. Las otras siete direcciones serian 56 imagenes que no
# mira nadie -- para el mapa esta 'cadaver', que es lo contrario (un marco, ocho direcciones).
#
# LA RATA MUERE PATAS ARRIBA. Se probo tambien de costado, como el jabali, y patas arriba gana por
# dos cosas: se lee como cadaver de un vistazo y sin ambiguedad (de costado, aplastada y quieta, se
# parece demasiado a la pose de agazaparse antes de saltar), y ademas distingue a los dos bichos --
# si los dos se caen de lado, dos muertes seguidas parecen la misma animacion repetida. Cambiar de
# idea cuesta un numero: 'tumba' a 1.0 en vez de a 2.0 la deja de costado.
#
# El ultimo frame se queda quieto: es la pose en la que se la ve mientras la columna se desvanece.
static func _pose_muerte(t: float) -> Dictionary:
	# Da un ultimo respingo hacia arriba antes de volcar, y al caer REBOTA un poco (se pasa de 2.0 y
	# vuelve). Sin ese rebote la vuelta se lee como un giro de maquina, no como un cuerpo que cae.
	var tumba_keys := [[0.0, 0.0], [0.14, 0.0], [0.28, 0.45], [0.45, 1.25],
		[0.62, 1.85], [0.78, 2.12], [0.90, 1.94], [1.0, 2.0]]
	# El apoyo acompaña a la vuelta: es lo que hay que subirla para que acabe tumbada SOBRE el suelo
	# y no medio enterrada en el. Los numeros salen de mirar la tira, no de una formula: lo que
	# sobresale por abajo cambia de pieza segun el angulo.
	var apoyo_keys := [[0.0, 0.0], [0.14, 0.0], [0.28, 1.4], [0.45, 3.4],
		[0.62, 4.7], [0.78, 5.3], [0.90, 5.1], [1.0, 5.2]]
	# Se encoge de golpe (el espasmo) y se queda floja.
	var estira_keys := [[0.0, 1.0], [0.14, 0.86], [0.28, 1.05], [1.0, 1.0]]
	var agacha_keys := [[0.0, 0.15], [0.14, 0.62], [0.28, 0.30], [0.45, 0.0], [1.0, 0.0]]
	# Y GIRA A PERFIL MIENTRAS CAE. Sin esto no se ve NADA: de frente, el eje sobre el que se tumba
	# apunta a la camara, asi que la vuelta no cambia la silueta (ver 'rumbo' en _piezas). Empieza a
	# la vez que la vuelta y va un poco por delante, que es lo que hace un cuerpo al desplomarse: no
	# cae en el mismo plano en el que estaba.
	var rumbo_keys := [[0.0, 0.0], [0.14, 0.10], [0.28, 0.45], [0.45, 0.80], [0.62, 0.95], [1.0, 1.0]]
	return {"avance": 0.0,
		"estira": SpriteLienzo.tramos(t, estira_keys),
		# La cola se queda tiesa a mitad de la caida y ya no vuelve a serpear.
		"cola": 0.9 * (1.0 - clampf(t * 2.2, 0.0, 1.0)), "patas": 0.0,
		"agacha": SpriteLienzo.tramos(t, agacha_keys),
		"tumba": SpriteLienzo.tramos(t, tumba_keys),
		"rumbo": SpriteLienzo.tramos(t, rumbo_keys) * PI * 0.5,
		"apoyo": SpriteLienzo.tramos(t, apoyo_keys)}


static func _montar_muerte(anims: Array, rey: bool, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return _pose_muerte(t)
	_montar_animacion(anims, rey, esc, "muerte", false, 10.0, pose, true, 1, 8)


# EL CADAVER DEL MAPA: UN fotograma por CADA UNA de las ocho direcciones, que es justo al reves que
# 'muerte' (ocho fotogramas en una sola). No es un capricho de reparto, es lo que pide cada sitio:
# en combate al bicho se le ve morir de frente y una vez; en el mapa no se le ve morir -- se entra a
# la sala y ya esta tirado --, pero puede haber caido mirando a cualquier lado.
#
# Es EXACTAMENTE la pose final de la muerte, sacada de la misma funcion: escribir los numeros otra
# vez aqui es garantizar que el dia que se retoque la muerte el cadaver se quede como estaba, y que
# el bicho pegue un salto al pasar de una a otro.
static func _montar_cadaver(anims: Array, rey: bool, esc: float) -> void:
	var pose := func(_t: float) -> Dictionary:
		return _pose_muerte(1.0)
	# ultimo_incluido = false y NO true: con un solo marco, el divisor de _montar_animacion
	# seria (1 - 1) = 0 y el reparto de t saldria NaN. La pose se pide fija, asi que da igual.
	_montar_animacion(anims, rey, esc, "cadaver", false, 1.0, pose, false, 8, 1)


# ENCAJAR UN GOLPE. Cuatro fotogramas en UNA sola direccion (en combate al bicho se le ve siempre de
# frente) y EMPEZANDO YA GOLPEADA: el frame 0 es el impacto, no la pose de reposo. Un golpe no tiene
# anticipacion, y con cuatro marcos un fotograma de espera se comeria la animacion entera.
#
# LA RATA SALE DESPEDIDA, que es lo suyo: pesa poco. Se encoge contra el suelo, retrocede y da un
# latigazo de cola. Es la que mas se mueve de los cuatro; el jabali, que es una mole, apenas se
# inmuta.
static func _montar_encaje(anims: Array, rey: bool, esc: float) -> void:
	# 'agacha' no pasa de 1.0 en ninguna pose del juego, y no es casualidad: por encima la altura se
	# vuelve negativa y las piezas dejan de pintarse SIN DAR ERROR -- la rata desaparece a trozos.
	var agacha_keys := [[0.0, 0.85], [0.34, 0.20], [0.67, 0.06], [1.0, 0.0]]
	var estira_keys := [[0.0, 0.80], [0.34, 1.10], [0.67, 0.96], [1.0, 1.0]]
	var retro_keys := [[0.0, 1.0], [0.34, 0.52], [0.67, 0.16], [1.0, 0.0]]
	var cola_keys := [[0.0, 1.6], [0.34, -0.9], [0.67, 0.4], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		return {"avance": -SpriteLienzo.tramos(t, retro_keys) * ENCAJE_RETRO,
			"estira": SpriteLienzo.tramos(t, estira_keys),
			"cola": SpriteLienzo.tramos(t, cola_keys), "patas": 0.0,
			"agacha": SpriteLienzo.tramos(t, agacha_keys)}
	# LOS CUATRO BICHOS ENCAJAN A 18 fps, aunque sus otras animaciones vayan cada una a lo suyo. Es
	# la duracion que espera CombatFX.T_ENCAJE, y cuadrando las dos el sprite se reproduce a su
	# velocidad natural en vez de estirado o comprimido por _pose_ajustar.
	_montar_animacion(anims, rey, esc, "encaje", false, 18.0, pose, true, 1, 4)


static func _montar_animacion(anims: Array, rey: bool, esc: float, nombre: String,
		loop: bool, fps: float,
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
			# La GEOMETRIA se cachea por (animacion, frame, direccion, rey, escala) y NO por color:
			# otra rata de otro tono reusa estas plantillas y solo repinta. Es lo que evita que
			# entrar a un piso lleno de ratas congele el juego.
			var clave: String = "%s_%d_%d_%d_%.2f" % [nombre, i, dir, 1 if rey else 0, esc]
			var plant: PackedByteArray = _cache_plantillas.get(clave, PackedByteArray())
			if plant.is_empty():
				plant = _plantilla(dir, pose_fn.call(float(i) / divisor), rey, esc)
				_cache_plantillas[clave] = plant
			plantillas.append(plant)
		anims.append({"nombre": "%s_%d" % [nombre, dir], "loop": loop, "fps": fps,
			"plantillas": plantillas})


# Los colores de cada Tono, EN EL ORDEN DEL ENUM (contrato con SpriteLienzo.paleta).
static func _colores(color: Color, rey: bool) -> Array:
	return [
		Color(0, 0, 0, 0),                    # VACIO
		Color(0, 0, 0, 0.20),                 # SOMBRA_SUELO
		color.darkened(0.60),                 # BORDE
		color.darkened(0.30),                 # SOMBRA (el costado, en penumbra)
		color,                                # BASE
		color.lightened(0.26),                # LOMO (la franja iluminada del espinazo)
		color.lightened(0.05).lerp(Color(0.95, 0.7, 0.72), 0.5),   # OREJA_INT (rosada por dentro)
		Color(0.1, 0.07, 0.07),               # OJO_T (negro de roedor)
		color.darkened(0.16),                 # COLA (pelada, algo mas oscura que el pelo)
		# CICATRIZ: ROJA de sangre, no el pelaje oscurecido. Sobre un bicho marron, un marron mas
		# oscuro no se distingue de una sombra cualquiera; el rojo dice "herida" al momento y
		# ademas rima con lo suyo, que es hacer sangrar a todo lo que toca.
		Color(0.66, 0.13, 0.12) if rey else color,   # CICATRIZ (solo el rey)
	]


# ------------------------------------------------------------
#  GEOMETRIA
# ------------------------------------------------------------

# Las PIEZAS de la rata para una pose, ya proyectadas a pantalla. Cada una es {pos, radio, tono,
# ang}. El orden importa: se pintan en ese orden y las ultimas tapan a las primeras, asi que va de
# lo mas lejano/bajo (cola, patas) a lo mas cercano/alto (cabeza, orejas).
static func _piezas(dir: int, pose: Dictionary, rey: bool, esc: float) -> Array:
	# RUMBO: un giro EXTRA en planta, encima del de la direccion. Con default 0.0, o sea que las
	# poses de siempre no lo notan.
	#
	# Hace falta para morir, y por un motivo de camara que no se ve venir: el eje sobre el que un
	# bicho se tumba es el que va del morro a la cola, y cuando el bicho te mira DE FRENTE ese eje
	# apunta justo hacia la camara. Girar alrededor de la linea de vision no cambia la silueta: la
	# rata patas arriba salia exactamente igual que la rata de pie, solo que mas alta. Girandola
	# antes a PERFIL, el eje se pone de lado y la vuelta si se ve.
	var ang: float = DIR_VECS[dir].angle() - DIR_VECS[0].angle() + float(pose.get("rumbo", 0.0))
	var u: float = esc / SpriteLienzo.UNIDADES_POR_CELDA    # unidades de mundo -> celdas
	var centro: float = float(_celdas(esc)) * 0.5
	var estira: float = float(pose["estira"])
	var agacha: float = float(pose["agacha"])
	var avance: float = float(pose["avance"])
	var fase_cola: float = float(pose["cola"])
	var fase_patas: float = float(pose["patas"])
	# TUMBARSE. Una vuelta del bicho entero sobre su EJE LONGITUDINAL, en cuartos: 1.0 = de costado,
	# 2.0 = patas arriba. Se lee con default 0.0 para que las cuatro poses de siempre no se enteren
	# -- ninguna se tumba, y el que no se tumba no paga ni una operacion.
	#
	# ES LA UNICA FORMA DE QUE UN CADAVER SE LEA COMO UN CADAVER: agachar el cuerpo contra el suelo
	# ('agacha') lo deja aplastado pero DE PIE, que es la pose de agazaparse, o sea la de estar a
	# punto de saltarte encima. Justo lo contrario de lo que tiene que decir.
	var tumba: float = float(pose.get("tumba", 0.0)) * PI * 0.5
	# Y CUANTO HAY QUE SUBIRLO despues de girarlo para que apoye en el suelo en vez de quedarse medio
	# enterrado. Va a mano y no calculado: el punto mas bajo de la silueta girada depende de que
	# pieza sea la que sobresalga, y eso cambia con el angulo.
	var apoyo: float = float(pose.get("apoyo", 0.0))

	# Agazapada = mas corta, mas ancha y mas BAJA (se aplasta contra el suelo antes de saltar).
	var largo: float = estira * (1.0 - 0.18 * agacha)
	var ancho: float = (1.0 + 0.12 * agacha) / maxf(0.5, estira)
	var alto: float = 1.0 - 0.30 * agacha

	var piezas: Array = []
	# local (x ancho, y largo, z altura, en unidades de mundo) -> celda de pantalla.
	#
	# 'chato' es cuanto se aplasta la pieza en el eje vertical DE PANTALLA. Ojo con esto, que costo
	# un fallo: el aplastado va DESPUES de girar, no antes. Calculando el radio vertical aqui (con
	# la pieza aun sin girar) y dejando que el motor rotara luego esa elipse ya deformada, de perfil
	# el cuerpo salia mas CORTO de lo que mide -- y por eso se le despegaba la cola.
	# Como referencia: una pieza tumbada y plana va en cos(45) = 0.707; una esfera se proyecta como
	# circulo mire por donde se mire, asi que va cerca de 1.
	var ct: float = cos(tumba)
	var st: float = sin(tumba)
	var poner := func(local: Vector3, r: Vector3, tono: int, chato: float,
			solo_sobre: Array = [], en_suelo: bool = false) -> void:
		# TUMBAR, lo primero: gira el punto en el plano ANCHO-ALTURA, o sea alrededor del eje que va
		# del morro a la cola. Lo que era el costado pasa a mirar al cielo.
		# 'en_suelo' se salta todo esto: es para la sombra de contacto, que ni gira con el bicho ni
		# se sube con el -- es una mancha en el suelo, y el suelo no se tumba.
		var lx: float = local.x
		var lz: float = local.z
		if tumba != 0.0 and not en_suelo:
			lx = local.x * ct + local.z * st
			lz = -local.x * st + local.z * ct
		var p := Vector2(lx * ancho, local.y * largo + avance)
		var rot := p.rotated(ang)
		var z: float = lz * alto + (0.0 if en_suelo else apoyo)
		# LA PROYECCION de la posicion: la profundidad se encoge por cos(45) y la altura SUBE por
		# sin(45). Ese "- z" es lo que pone el lomo y las orejas por encima de las patas, y por
		# tanto lo que hace que de perfil se le vea el COSTADO y no la planta.
		var sx: float = centro + rot.x * u
		var sy: float = centro + (rot.y * SpriteLienzo.COS_CAM - z * SpriteLienzo.SIN_CAM) * u
		# EL RADIO TAMBIEN GIRA. Al tumbarse, lo que era el semieje a lo ANCHO pasa a ser el vertical
		# y al reves; sin esto el cuerpo se queda con su anchura de estar de pie y una rata de
		# costado sale igual de gorda que de frente, que es justo lo que delata el truco.
		# Con |sen| como mezcla sale gratis el caso de patas arriba: media vuelta no cambia la forma.
		var mezcla: float = absf(st)
		var rx: float = lerpf(r.x, r.z, mezcla) if not en_suelo else r.x
		# 'gira_forma': la ELIPSE de la rata gira sobre si misma (lleva 'ang'), asi que para encerrarla
		# hay que contar con su radio mayor en los DOS ejes -- puede caer en cualquiera de ellos.
		piezas.append({"pos": Vector2(sx, sy),
			"radio": Vector2(rx * ancho * u, r.y * largo * u), "gira_forma": true,
			"tono": tono, "ang": ang, "chato": chato, "solo_sobre": solo_sobre})

	# SOMBRA DE CONTACTO, lo primero de todo (va debajo). Se pone a ALTURA CERO: asi acompaña al
	# bicho por el suelo cuando se lanza, pero NO sube con el -- y esa separacion entre el cuerpo
	# (que se levanta) y su sombra (que se queda abajo) es justo lo que se lee como un salto.
	poner.call(Vector3(0.0, 0.0, 0.0), Vector3(CUERPO_R.x * 1.1, CUERPO_R.y * 0.95, 0.0),
		Tono.SOMBRA_SUELO, CHATO_TUMBADO, [], true)

	# COLA: va por DEBAJO del resto (sale de detras del cuerpo).
	# El nudo del rey usa LA MISMA formula siguiendo la cadena: con una propia aparecia despegado.
	var punto_cola := func(i: float) -> Vector3:
		var f: float = clampf(i / float(COLA_SEGMENTOS - 1), 0.0, 1.0)
		# Serpea: cada segmento va desfasado del anterior y la onda crece hacia la punta (la base
		# apenas se mueve, como en un animal de verdad).
		var lat: float = sin(TAU * fase_cola - i * COLA_DESFASE * 0.6) * (0.3 + 1.7 * f)
		# Arranca METIDA en la grupa (0.2, no 0.7) para que no se vea la junta, y va bajando.
		return Vector3(lat, -CUERPO_R.y - COLA_PASO * (i + 0.2), lerpf(COLA_Z0, COLA_Z1, f))
	for i in COLA_SEGMENTOS:
		var f: float = float(i) / float(COLA_SEGMENTOS - 1)
		var r: float = lerpf(COLA_R0, COLA_R1, f) * (1.35 if rey else 1.0)
		poner.call(punto_cola.call(float(i)), Vector3(r, r, r), Tono.COLA, CHATO_REDONDO)
	if rey:
		# EL NUDO del Rey rata: un enredo de bultos en la punta de su propia cola. Guiño al
		# "Rattenkoenig" del folclore -- un rey rata es literalmente una maraña de colas anudadas.
		# Se eligio esto en vez de una corona a proposito: la corona ya es la marca del Rey Slime.
		var base_n: Vector3 = punto_cola.call(float(COLA_SEGMENTOS - 1))
		for k in 4:
			var a: float = TAU * float(k) / 4.0 + fase_cola
			poner.call(base_n + Vector3(cos(a) * 0.9, sin(a) * 0.9, 0.3),
				Vector3(1.2, 1.2, 1.1), Tono.COLA, CHATO_REDONDO)

	# PATAS: bajas, a los lados. Al trotar, las delanteras y las traseras van en contrafase.
	for lado in [-1.0, 1.0]:
		for k in PATA_Y.size():
			var swing: float = fase_patas * (1.0 if k == 0 else -1.0) * lado
			poner.call(Vector3(lado * PATA_X, PATA_Y[k] + swing * 1.1, PATA_Z),
				PATA_R, Tono.SOMBRA, CHATO_TUMBADO)

	# CUERPO, cabeza y hocico.
	poner.call(CUERPO, CUERPO_R, Tono.BASE, CHATO_CUERPO)
	poner.call(CABEZA, CABEZA_R, Tono.BASE, CHATO_REDONDO)
	poner.call(HOCICO, HOCICO_R, Tono.BASE, CHATO_REDONDO)

	# LOMO iluminado: la franja del espinazo. Va MAS ALTO que el eje del cuerpo (la luz viene de
	# arriba y el espinazo es lo mas alto del bicho), asi que en pantalla queda desplazado hacia
	# arriba y la mitad de abajo se queda en tono base = el costado en penumbra. Solo sobre BASE,
	# para no aclarar la cola, ni las orejas, ni pisar el contorno.
	# BOCA ARRIBA NO HAY LOMO QUE ILUMINAR: el espinazo mira al suelo y lo que se ve es la panza.
	# Pintarlo igual dejaba una franja clara en mitad de la tripa, como si le diera el sol por dentro.
	if tumba <= PI * 0.5:
		poner.call(Vector3(CUERPO.x, CUERPO.y, CUERPO.z + CUERPO_R.z * 0.75),
			Vector3(CUERPO_R.x * 0.60, CUERPO_R.y * 0.80, CUERPO_R.z), Tono.LOMO, CHATO_CUERPO,
			[Tono.BASE])

	# OREJAS, arriba del todo. La del rey (lado izquierdo) va RASGADA: se dibuja entera y luego se
	# le muerde un trozo con una elipse de tono VACIO, que es lo que deja la muesca en el borde.
	# Y tampoco orejas: volteadas quedan DEBAJO de la cabeza, o sea tapadas por ella.
	for lado in ([-1.0, 1.0] if tumba <= PI * 0.5 else []):
		poner.call(Vector3(lado * OREJA.x, OREJA.y, OREJA.z), OREJA_R, Tono.OREJA_INT, CHATO_OREJA)
	if rey and tumba <= PI * 0.5:
		poner.call(Vector3(-OREJA.x - 1.0, OREJA.y, OREJA.z + 1.1),
			Vector3(1.0, 0.8, 1.0), Tono.VACIO, CHATO_OREJA)

	# OJOS. De ESPALDAS no se le ven: con la camara a 45 grados, una rata que se aleja enseña la
	# nuca. Ademas es lo que hace que se lea de un vistazo si viene o si huye. De medio lado se le
	# ve solo el de ese lado.
	var frente: float = DIR_VECS[dir].y
	var lados: Array = [-1.0, 1.0]
	if frente <= -0.9:
		lados = []
	elif frente < -0.4:
		lados = [signf(DIR_VECS[dir].x)]
	# TUMBADA, UN SOLO OJO. Al girar sobre su eje los dos caen casi en la misma X de pantalla, y
	# aqui no hay profundidad de verdad -- el orden de pintado es fijo --, asi que el que queda
	# debajo se dibujaria ENCIMA del cuerpo: dos puntos flotando sobre la panza. Es la misma regla
	# que ya tiene el slime visto de perfil, y por el mismo motivo.
	if tumba != 0.0 and lados.size() == 2:
		lados = [1.0]
	# Y boca arriba, ninguno: la cara mira al suelo.
	if tumba > PI * 0.5:
		lados = []
	# CICATRIZ del rey: un tajo en diagonal CENTRADO EN EL OJO -- el punto medio del trazo cae sobre
	# el y de ahi sale hacia los dos lados. Colocandola por un extremo se quedaba descolgada por
	# detras del ojo segun la direccion.
	# Va ANTES que los ojos a proposito: pintada encima, tapaba el ojo entero y se veia una barra
	# roja donde deberia haber una mirada. Debajo, el ojo se dibuja sobre ella y el tajo asoma por
	# arriba y por abajo, que es lo que se lee como una cicatriz QUE CRUZA el ojo.
	if rey and not lados.is_empty():
		for k in 5:
			var d: float = float(k) - 2.0     # -2..+2: el 0 cae justo en el ojo
			poner.call(Vector3(OJO.x + d * 0.42, OJO.y + d * 0.62, OJO.z + 0.3),
				Vector3(0.4, 0.4, 0.4), Tono.CICATRIZ, CHATO_REDONDO)

	for l in lados:
		poner.call(Vector3(l * OJO.x, OJO.y, OJO.z), OJO_R, Tono.OJO_T, CHATO_REDONDO)

	# PATAS ARRIBA, LAS PATAS SE PINTAN LAS ULTIMAS. El orden de esta lista ES la profundidad -- aqui
	# no hay z-buffer -- y esta cableado para un bicho DE PIE: las patas van primero porque el cuerpo
	# las tapa. Volteada es al reves, y ese era el motivo de que la rata SI estuviera patas arriba
	# pero no se notara: quedaban por encima del cuerpo en el mundo y por debajo en el dibujo.
	#
	# Se mueven SOLO las patas y no se invierte la lista entera, que fue el primer intento: invertir
	# le da la vuelta tambien al orden de piezas que se distinguen por donde estan A LO LARGO del
	# bicho, y ademas rompe los 'solo_sobre' (el lomo se pinta sobre BASE, y antes que el cuerpo no
	# encuentra nada). La sombra de contacto se queda la primera de todas: el suelo no se voltea.
	if tumba > PI * 0.5:
		var patas: Array = []
		var resto: Array = []
		for p in piezas:
			if int(p["tono"]) == Tono.SOMBRA:   # en la rata ese tono es SOLO de las patas
				patas.append(p)
			else:
				resto.append(p)
		piezas = resto + patas

	return piezas


# La plantilla de un frame: que tono le toca a cada celda.
static func _plantilla(dir: int, pose: Dictionary, rey: bool, esc: float) -> PackedByteArray:
	var lado: int = _celdas(esc)
	var plant := PackedByteArray()
	plant.resize(lado * lado)
	var piezas: Array = _piezas(dir, pose, rey, esc)

	# TODO EL BICHO son piezas, en orden (las ultimas tapan a las primeras). Ojos, lomo y cicatriz
	# ESTAN ENTRE ELLAS a proposito: cuando se dibujaban aparte, aqui, no pasaban por la misma
	# transformacion, asi que en la embestida el cuerpo salia disparado y ellos se quedaban clavados
	# en el sitio -- al bicho se le quedaban los ojos flotando detras. Una sola transformacion para
	# todo, y eso no puede volver a pasar.
	for p in piezas:
		var pos: Vector2 = p["pos"]
		var r: Vector2 = p["radio"]
		SpriteLienzo.elipse(plant, lado, lado, pos.x, pos.y, r.x, r.y, int(p["tono"]),
			float(p["ang"]), p["solo_sobre"], float(p["chato"]))

	# CONTORNO al final, sobre la silueta ya completa (ver SpriteLienzo.contornear). La sombra del
	# suelo cuenta como hueco: es una mancha translucida, no parte del bicho.
	SpriteLienzo.contornear(plant, SpriteLienzo.caja_de_piezas(piezas, lado, lado), lado, lado,
		Tono.BORDE, Tono.VACIO, Tono.SOMBRA_SUELO)
	return plant
