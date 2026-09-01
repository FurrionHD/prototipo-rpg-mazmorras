# ============================================================
#  minotauro_sprites.gd  (class_name MinotauroSprites)
#  Sprite del MINOTAURO dibujado por codigo, con el motor comun (SpriteLienzo) y la camara de 45
#  grados que comparten todos los bichos. Es el JEFE DEL PISO 12 (scenes/actors/enemy/guardian_rango.tres,
#  enganchado en game.gd BOSSES): 1200 de vida, otorga rango 2 y reaparece cada 15 minutos.
#
#  ES EL PRIMER HUMANOIDE DEL JUEGO -- familia 6, HUMANOIDE, y esta el solo en ella -- y el tercer
#  bipedo con brazos despues del golem y el coloso. Pero aquellos son ESTATUAS: piezas de piedra
#  apiladas que se mueven a trompicones. Este es de CARNE, y eso cambia lo que hay que dibujar:
#    * TORSO EN V: hombros anchisimos y cintura estrecha. Es lo que separa a un humanoide musculado
#      de un monigote, y de un pegote de barro.
#    * PIERNAS DIGITIGRADAS, o sea que apoya en la PEZUÑA y lleva el corvejon a media altura, hacia
#      atras. Un minotauro con piernas humanas es un tio con casco.
#    * CABEZA BOVINA con el testuz bajado, CUERNOS curvos y ANILLA en el hocico. Los cuernos son su
#      silueta: si se le quitan, no hay minotauro.
#
#  Sus tres habilidades mandan sobre las animaciones, y cada una pide una cosa distinta:
#    * `minotauro_cornada` (x1.9 + sangrado) -> embiste con la cabeza LADEADA, clavando un cuerno.
#      Es su golpe iconico, asi que es el que se dibuja como 'embestida'.
#    * `minotauro_pisoton` (x1.7, area_max 99) -> levanta una pierna y la deja caer.
#    * `minotauro_bramido` (dano_mult 0, furia sobre si mismo) -> puro gesto: se yergue, echa la
#      cabeza atras y abre los brazos.
#
#  ESCALA 2,4 -> 3,1 (ver el .tres). A 2,4 el jefe del piso 12 se leia mas pequeño que el golem de
#  arcilla del piso 7, que es de las cosas que mas rompen una sala de jefe. A 3,1 sus 40 unidades de
#  alto dan 124 px en pantalla: por encima de los 102 del golem y del trent, y por debajo de los 185
#  del coloso -- que sigue siendo el mas alto del juego a proposito. Un jefe no tiene que ser lo mas
#  grande, tiene que ser lo mas grande DE SU SITIO.
#
#  El TAMAÑO se consigue con MAS CELDAS, no con celdas mas gordas: ver SpriteLienzo.UNIDADES_POR_CELDA.
# ============================================================

extends RefCounted
class_name MinotauroSprites

const FRAMES := 8

# --- El minotauro mirando al SUR, en unidades de MUNDO (origen = donde pisa, +Y hacia donde mira,
# +Z hacia arriba). A escala 1.0 mide unas 40 unidades del suelo a la coronilla. ---
#
# LAS MEDIDAS DE MUNDO SE QUEDAN CONTENIDAS Y EL TAMAÑO LO PONE LA ESCALA: el lienzo sale de
# (unidades x escala), asi que dibujarlo con medidas enormes Y escala grande seria multiplicar dos
# veces. Es la nota del coloso.
const ALTO_MUNDO := 40.0

# --- LAS PIERNAS, DIGITIGRADAS: pezuña en el suelo, caña larga, corvejon a media altura y hacia
# ATRAS, y muslo grueso. Es la pierna de un toro, no la de una persona.
#
# PIERNA_X (4,0) muy por dentro del semiancho de la cadera (5,6): una pieza que nace en el borde de
# la elipse de otra nace donde aquella tiene grosor CERO, y flota. Es la leccion que costo tres
# vueltas con las patas del acechador y que aqui va puesta de entrada.
const PIERNA_X := 4.0
const PEZUNA := Vector3(0.0, 1.2, 1.5)
const PEZUNA_R := Vector3(2.1, 2.9, 1.5)
const CANA := Vector3(0.0, 0.2, 6.4)
const CANA_R := Vector3(1.8, 2.0, 4.6)
# EL CORVEJON VA HACIA ATRAS: es lo que dibuja la Z de la pata trasera de un toro. Sin el, la pierna
# es un tubo recto y el bicho vuelve a ser un humano con cabeza de vaca.
const CORVEJON := Vector3(0.0, -2.2, 12.0)
const CORVEJON_R := Vector3(2.4, 2.8, 3.0)
const MUSLO := Vector3(0.0, 0.4, 16.4)
const MUSLO_R := Vector3(3.0, 3.6, 4.4)
const PASO_LARGO := 2.6
const PASO_ALZA := 1.8

# CADERA: ancha y baja. Es la base del torso en V.
const CADERA := Vector3(0.0, 0.0, 20.2)
const CADERA_R := Vector3(5.6, 4.2, 3.2)
# CINTURA: LO ESTRECHO del bicho. Sin este estrangulamiento no hay V, y sin V el torso es un barril.
const CINTURA := Vector3(0.0, 0.2, 24.0)
const CINTURA_R := Vector3(4.4, 3.6, 2.8)
# PECHO: lo ANCHO. 8,6 de semiancho contra los 4,4 de la cintura -- casi el doble, y esa proporcion
# es todo el personaje.
const PECHO := Vector3(0.0, 0.4, 28.4)
const PECHO_R := Vector3(8.6, 5.0, 5.2)
# Los PECTORALES, dos bultos por delante: son lo que hace que el pecho se lea como carne y no como
# una caja. Van 'solo_sobre' el cuerpo para no derramarse.
const PECTORAL := Vector3(3.6, 3.4, 29.2)
const PECTORAL_R := Vector3(3.4, 2.6, 2.6)

# HOMBROS: anchos y redondos. Y ADELANTADOS (HOMBRO_Y positivo), que NO es cosa del dibujo:
# la prueba que decide que brazo va delante es la Y del hombro YA GIRADA, y con la Y en CERO exacto
# da falso para los DOS -- el bicho de frente dibujaria sus dos brazos como "el de detras",
# escorzados y pegados al cuerpo. Es la trampa que ya mordieron el golem y el coloso.
const HOMBRO_X := 8.2
const HOMBRO_Y := 0.9
const HOMBRO_Z := 29.0
const HOMBRO_R := Vector3(3.6, 3.4, 3.4)
# Y LA DE DETRAS SE BAJA A MANO: de perfil, la que se va al fondo SUBE en pantalla 0,707 unidades por
# cada una de profundidad, asi que se plantaba a la altura de la cabeza y el bicho enseñaba una bola
# flotando sobre el hombro. Otra del coloso.
const HOMBRO_BAJA_DETRAS := 2.2

# --- LOS BRAZOS: cadenas de piezas con CODO, largas y gruesas, rematadas en un puño.
#
# EL PASO TIENE QUE SOBRAR, NO CUADRAR: 2,4 de paso contra un radio de 2,2 en la muñeca (4,4 de
# diametro). Un paso que "cuadra justo" con el diametro deja las piezas TANGENTES, se rozan en una
# linea y el puño se despega en cuanto el brazo se mueve. Al coloso le costo 31 fotogramas rotos.
#
# Y HACE FALTA EL CODO: de perfil los dos brazos caen sobre el eje de la pantalla -- lo que los
# separa a lo ancho pasa a ser PROFUNDIDAD -- asi que un brazo recto se pinta encima del torso y de
# las piernas y tapa el bicho entero.
const BRAZO_SEGMENTOS := 6
const BRAZO_PASO := 2.4
const BRAZO_R0 := 2.9              # en el hombro
const BRAZO_R1 := 2.2              # en la muñeca
const BRAZO_BAJA := 2.0            # nace por debajo del centro del hombro, o lo tapa entero
# EL ARCO DEL BRAZO VA EN EL PLANO DE DELANTE (0 = a plomo, PI/2 = hacia delante, 2,6 = sobre la
# cabeza) y NO en el de los costados: interpolando por los costados, el camino de "colgando" a "en
# alto" pasa por la HORIZONTAL y el bicho se queda EN CRUZ, ocupando el doble de ancho.
const BRAZO_ANG_REPOSO := 0.12
const BRAZO_ANG_ALTO := 2.35
const BRAZO_CODO := 0.80
const BRAZO_ABRE := 0.55           # cuanto se separa del cuerpo por cada segmento
const PUNO_R := Vector3(3.0, 2.9, 2.9)

# CUELLO: corto y GRUESO. En un toro el cuello es mas ancho que la cabeza, y ese es medio bicho.
# LA SEPARACION CABEZA-HOMBROS SE MIDE EN (y - z), NO EN ALTURA. Con la camara a 45 grados la altura
# en pantalla sale de (y - z), y el margen tiene que superar el RADIO EN PANTALLA de la cabeza o los
# tres bultos de arriba (hombro, cabeza, hombro) se leen como una fila -- la cabeza sale HUNDIDA
# entre los hombros, que es como salio al primer intento. Aqui: hombros a 29,0 y cabeza a 39,0, o sea
# 10 unidades, que en pantalla son 5,9 descontando lo que la cabeza va adelantada: 15,8 celdas contra
# los 10,8 de su radio. Es la leccion del golem y del coloso, las dos veces por lo mismo.
const CUELLO := Vector3(0.0, 1.4, 34.2)
const CUELLO_R := Vector3(3.4, 3.0, 3.2)
# CABEZA: GRANDE -- casi tan ancha como el pecho -- y alargada hacia delante (es un craneo bovino, no
# una bola), con el testuz BAJADO. El tamaño sale de la referencia que paso el usuario: ahi la cabeza
# domina al bicho y el cuello casi no existe. Con una cabeza a escala humana sobre esos hombros lo
# que sale es un tio disfrazado.
const CABEZA := Vector3(0.0, 2.6, 39.0)
const CABEZA_R := Vector3(4.2, 4.4, 3.9)
const HOCICO := Vector3(0.0, 7.0, 37.0)
const HOCICO_R := Vector3(3.0, 3.0, 2.6)
# JUSTO ENCIMA DEL MORRO, no en la frente: a 40,4 caian a la altura de la raiz de los cuernos y
# parecian dos remaches del craneo. Una cara se ordena de abajo arriba -- morro, ojos, cuernos -- y
# los ojos tienen que quedar pegados a la mancha clara del hocico para leerse como ojos.
const OJO := Vector3(2.5, 5.4, 39.5)
const OJO_R := Vector3(0.85, 0.85, 0.85)
const OREJA := Vector3(4.4, 2.0, 39.6)
const OREJA_R := Vector3(2.0, 1.1, 1.2)

# --- LOS CUERNOS: SU SILUETA. Salen de lo alto de los lados de la cabeza, van hacia FUERA, suben y
# se curvan hacia DELANTE. En cadena, como los colmillos del jabali: una sola pieza alargada no se
# curva, y un cuerno recto no se lee como un cuerno.
#
# Van en HUESO, bien claro. Sobre un bicho pardo rojizo, un cuerno de su mismo tono desaparece -- y
# lo que no puede pasar es que no se le vean los cuernos.
# SON ENORMES Y MUY ABIERTOS, en lira: en la referencia del usuario los cuernos son casi tan anchos
# como los hombros y es LO PRIMERO que se ve del bicho. Unos cuernos discretos convierten a un
# minotauro en un hombre-toro cualquiera.
const CUERNO_SEGMENTOS := 8
const CUERNO_BASE := Vector3(3.4, 2.2, 41.6)
const CUERNO_PASO := 1.5           # contra un radio final de 0,9 (1,8 de diametro): SOBRA
const CUERNO_R0 := 1.5
const CUERNO_R1 := 0.9
const CUERNO_ABRE := 0.88          # cuanto se va hacia fuera al empezar
const CUERNO_GIRO := 0.27          # y cuanto se cierra hacia delante y arriba en cada paso

# LA ANILLA del hocico: el detalle que lo remata. Un arco de piezas colgando de la nariz.
const ANILLA_SEGMENTOS := 7
const ANILLA := Vector3(0.0, 7.8, 35.8)
const ANILLA_R := 1.9
const ANILLA_GROSOR := 0.52

# --- EL CINTO: taparrabos y brazaletes, los dos en cuero oscuro. Salen de la referencia, y no son
# adorno: son lo que le da ESCALA al bicho. Un cuerpo desnudo del mismo tono de arriba abajo no dice
# lo grande que es; en cuanto lleva encima algo hecho por alguien, se lee el tamaño.
# CORTO. Al primer intento bajaba tres unidades mas y era una mancha negra desde la cintura hasta
# medio muslo: se comia las piernas enteras y el bicho salia con las patas cortisimas. Una prenda
# oscura sobre un cuerpo claro pesa mucho mas de lo que mide.
const TAPARRABOS := Vector3(0.0, 0.0, 19.8)
const TAPARRABOS_R := Vector3(5.9, 4.4, 2.1)
const FALDON := Vector3(0.0, 3.2, 18.4)
const FALDON_R := Vector3(2.6, 1.8, 2.4)
# El brazalete va en el segmento del antebrazo, cerca del puño.
const BRAZALETE_SEG := 4
const BRAZALETE_R := Vector3(2.7, 2.6, 2.6)

# --- EL HACHA. Es SOLO VISUAL: no es un arma equipada ni sale de su EnemyData -- el Minotauro pega
# con la cornada y el pisoton --, pero en la referencia la lleva y sin ella el bicho se lee mas
# desarmado de lo que es. Cuelga de una mano, apuntando al suelo.
#
# Va SIEMPRE EN EL MISMO LADO del cuerpo (el derecho), y no en "el brazo de delante": si cambiara de
# mano segun por donde se le mire, al girar el bicho el hacha saltaria de un lado a otro.
const HACHA_LADO := 1.0
# TRES SEGMENTOS Y NO CINCO: con cinco el mango medía 10 unidades y la hoja acababa rozando el
# SUELO, como si arrastrara el hacha. Cuelga de la mano, que ya esta baja de por si.
const MANGO_SEGMENTOS := 3
const MANGO_PASO := 2.0            # contra un radio de 0,85 (1,7): aqui NO sobra por grosor...
const MANGO_R := 0.85
# ...asi que el mango se cose con un SOLAPE POR SEPARADO: sus piezas son finas y muy juntas no se
# leerian como un palo. Se compensa alargandolas en la direccion del mango (ver _piezas): una pieza
# ALARGADA cubre el hueco que una redonda del mismo grosor no cubriria.
const MANGO_LARGO := 1.5
# GRANDE. Al primer intento medias 3,4 x 2,6 y en la tira era una CHINCHETA gris colgando de la
# mano. El hacha de la referencia es casi tan alta como el torso del bicho: si no se lee como un
# hacha desde lejos, no vale la pena dibujarla.
const HOJA_ALTO := 5.2             # media altura de la hoja
const HOJA_ANCHO := 4.0            # cuanto sobresale hacia fuera
const HOJA_GRUESO := 1.1

# LA CORNADA: viaja lo suyo, pero menos que una carga de bestia -- es un jefe pesado.
const LUNGE_DIST := 9.0
# ENCAJAR UN GOLPE: tiene 45 de resistencia y 1200 de vida. Acusa poco, pero mas que la bestia
# acorazada (que es lo que menos se mueve): es carne, no coraza.
const ENCAJE_RETRO := 0.22

# --- EL LIENZO, en multiplos de la altura. RECTANGULAR y con el origen BAJO, como el coloso: el
# origen es el punto que pisa y el bicho crece hacia ARRIBA.
# ANCHO lo manda la envergadura de brazos y cuernos; ARRIBA, los cuernos con el brazo en alto del
# bramido; ABAJO, que al hincarse de rodillas se desparrama tambien en PROFUNDIDAD -- y la
# profundidad BAJA en pantalla. Es la leccion del cadaver del golem.
# El ANCHO lo manda el HACHA, no el bicho: cuelga por fuera del puño de un brazo ya abierto, y en la
# cornada el avance la lleva todavia mas lejos del centro. Con 1,30 se salia en tres fotogramas.
const LIENZO_ANCHO := 1.58
const LIENZO_ARRIBA := 1.28
const LIENZO_ABAJO := 0.34

# TONOS propios (el motor no sabe que es cada uno; solo mapea indice -> color, ver _colores).
enum Tono { VACIO, SOMBRA_SUELO, BORDE, PEZUNA_T, PIERNA_OSC, SOMBRA, BASE, CLARO, HOCICO_T,
	CUERNO_T, ANILLA_T, OJO_T, CUERO_T, MANGO_T, HOJA_T, HOJA_CLARA }

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
	return "minotauro_%s_%.2f" % [col.to_html(false), esc]


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(escala: float = 1.0) -> int:
	return _lienzo(escala).x


static func dimensiona_por_escala() -> bool:
	return true


# El CUERPO en planta (ancho, largo) para la colision: LO MARCAN LAS PEZUÑAS, que es lo que pisa el
# suelo. Los BRAZOS y los CUERNOS se quedan FUERA a proposito, igual que las alas de la gargola: un
# jefe que no cupiera por su propia sala porque abre los brazos seria absurdo, y ademas su ancho de
# hombros (17,2) no cabe por un vano de 96 px a escala 3,1.
#
# Sale en 12,2 x 13,6 unidades = unos 40 px de huella a escala 3,1: el mismo orden que los 44,8 del
# golem (47% del vano) y los 48 del coloso (la mitad). Un jefe ocupa media sala, no la sala.
static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	var ancho: float = (PIERNA_X + PEZUNA_R.x) * 2.0
	var largo: float = (PEZUNA.y + PEZUNA_R.y) - (CORVEJON.y - CORVEJON_R.y) + PASO_LARGO
	return Vector2(ancho, largo) * escala


# El lienzo, RECTANGULAR: ancho x alto en celdas.
static func _lienzo(escala: float) -> Vector2i:
	var alto_celdas: float = ALTO_MUNDO * escala / SpriteLienzo.UNIDADES_POR_CELDA
	var w: int = int(ceil(alto_celdas * LIENZO_ANCHO))
	var h: int = int(ceil(alto_celdas * (LIENZO_ARRIBA + LIENZO_ABAJO)))
	return Vector2i(w + (w % 2), h + (h % 2))


# Donde cae el ORIGEN (el punto que pisa el suelo) dentro del lienzo.
static func _origen(escala: float) -> Vector2:
	var lz: Vector2i = _lienzo(escala)
	var alto_celdas: float = ALTO_MUNDO * escala / SpriteLienzo.UNIDADES_POR_CELDA
	return Vector2(float(lz.x) * 0.5, alto_celdas * LIENZO_ARRIBA)


static func generar(color: Color = Color(0.55, 0.34, 0.2), escala: float = 1.0) -> SpriteFrames:
	# cuantizar_hsv y no cuantizar a secas: el pardo rojizo es un color apagado y redondear canal a
	# canal le cambiaria el TONO -- dos canales parecidos caen en el mismo escalon y sale un oliva.
	# Le paso lo mismo al Rey rata en su dia.
	var col: Color = SpriteLienzo.cuantizar_hsv(color, COLOR_PASOS)
	var esc: float = snappedf(escala, 0.05)      # se cuantiza tambien, o el cache no acierta
	var clave: String = _clave(col, esc)
	if _cache.has(clave):
		return _cache[clave]
	var anims: Array = []
	_montar_idle(anims, esc)
	_montar_walk(anims, esc)
	_montar_embestida(anims, esc)
	_montar_encaje(anims, esc)
	_montar_muerte(anims, esc)
	_montar_cadaver(anims, esc)
	var lz: Vector2i = _lienzo(esc)
	var sf: SpriteFrames = SpriteLienzo.montar_frames(
		anims, SpriteLienzo.paleta(_colores(col)), lz.x, lz.y)
	_cache[clave] = sf
	return sf


# La pose de reposo, con TODAS las claves a cero. Existe para que cada _montar_* escriba solo lo suyo
# y no se le olvide ninguna: una clave que falta no da error en GDScript, se lee como 0.0 y el fallo
# sale a la cara en el dibujo, que es donde mas cuesta encontrarlo.
static func _reposo() -> Dictionary:
	return {"avance": 0.0, "resopla": 0.0, "patas": 0.0, "agacha": 0.0, "cabeza": 0.0,
		"brazos": 0.0, "ladea": 0.0, "pisa": 0.0, "rodilla": 0.0, "vuelca": 0.0}


# Quieto: RESUELLA. Un jefe parado tiene que dar la sensacion de que esta conteniendose, no de que
# esta esperando: respira hondo, los hombros suben y bajan y la cabeza se mueve poco -- la lleva
# baja, mirandote. A 3 fps, que es lento y pesado.
static func _montar_idle(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["resopla"] = sin(TAU * t)
		p["cabeza"] = -0.25 + 0.3 * sin(TAU * t)
		p["brazos"] = 0.03 * sin(TAU * t)
		return p
	_montar_animacion(anims, esc, "idle", true, 3.0, pose, false)


# Andando: zancada larga y pesada, a 5 fps. Los brazos balancean en contrafase con las piernas, que
# es lo que hace que un bipedo ande en vez de deslizarse. Y se BAMBOLEA de un lado a otro: pesa.
static func _montar_walk(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["patas"] = sin(TAU * t)
		p["brazos"] = -0.13 * sin(TAU * t)
		p["agacha"] = 0.05 * (1.0 - cos(TAU * t * 2.0))
		p["ladea"] = 0.10 * sin(TAU * t)
		p["cabeza"] = -0.2 + 0.35 * sin(TAU * t * 2.0)
		return p
	_montar_animacion(anims, esc, "walk", true, 5.0, pose, false)


# LA CORNADA: escarba -> baja el testuz -> embiste LADEADO -> engancha hacia arriba.
# NO es periodica, asi que va por TRAMOS.
#
# Se dibuja la CORNADA y no el pisoton ni el bramido porque es su golpe iconico (x1.9 y sangrado), y
# porque es la unica de las tres que se lee de un vistazo en ocho fotogramas.
#
# LO QUE LA HACE UNA CORNADA ES EL LADEO. Embistiendo de frente con la cabeza baja, lo que se ve es
# un tio agachado corriendo; ladeando el torso y la cabeza, el cuerno de ese lado se adelanta y
# apunta -- y al final del golpe el cuello ENGANCHA HACIA ARRIBA, que es lo que hace un toro de
# verdad y lo que cuenta el sangrado de su habilidad.
static func _montar_embestida(anims: Array, esc: float) -> void:
	var avance_keys := [[0.0, 0.0], [0.30, -1.8], [0.60, 5.4], [0.78, 9.0], [1.0, 6.4]]
	var agacha_keys := [[0.0, 0.0], [0.30, 0.55], [0.60, 0.80], [0.78, 0.35], [1.0, 0.08]]
	# El ladeo entra en el aviso y se mantiene durante el viaje: es la puntería del cuerno.
	var ladea_keys := [[0.0, 0.0], [0.30, 0.65], [0.60, 0.85], [0.78, 0.55], [1.0, 0.0]]
	# Y EL ENGANCHE: la cabeza baja durante toda la carrera y sube DE GOLPE en el impacto.
	var cabeza_keys := [[0.0, -0.2], [0.30, -1.9], [0.60, -2.4], [0.78, 1.9], [1.0, 0.2]]
	# Los brazos se echan atras al correr, como los de algo que embiste con la cabeza.
	var brazos_keys := [[0.0, 0.0], [0.30, -0.22], [0.60, -0.34], [0.78, -0.10], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["avance"] = SpriteLienzo.tramos(t, avance_keys) * (LUNGE_DIST / 9.0)
		p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
		p["ladea"] = SpriteLienzo.tramos(t, ladea_keys)
		p["cabeza"] = SpriteLienzo.tramos(t, cabeza_keys)
		p["brazos"] = SpriteLienzo.tramos(t, brazos_keys)
		return p
	_montar_animacion(anims, esc, "embestida", false, 10.0, pose, true)


# ENCAJAR UN GOLPE. Cuatro fotogramas en UNA sola direccion (en combate se le ve siempre de frente)
# y EMPEZANDO YA GOLPEADO: el frame 0 es el impacto, no la pose de reposo. Un golpe no tiene
# anticipacion, y con cuatro marcos un fotograma de espera se comeria la animacion entera.
#
# ACUSA POCO PERO SE REVUELVE. Tiene 1200 de vida y 45 de resistencia, asi que no sale despedido
# como el acechador -- pero es CARNE, no coraza, asi que tampoco se queda clavado como la bestia
# acorazada. Se hunde sobre las piernas, echa la cabeza atras y vuelve a bajarla: no retrocede, se
# encara.
static func _montar_encaje(anims: Array, esc: float) -> void:
	# 'agacha' no pasa de 0,62: por encima de 1,0 la altura se vuelve negativa y las piezas dejan de
	# pintarse SIN DAR ERROR.
	var agacha_keys := [[0.0, 0.62], [0.34, 0.20], [0.67, 0.06], [1.0, 0.0]]
	var retro_keys := [[0.0, 1.0], [0.34, 0.42], [0.67, 0.12], [1.0, 0.0]]
	var cabeza_keys := [[0.0, 2.4], [0.34, -0.9], [0.67, 0.2], [1.0, -0.25]]
	var brazos_keys := [[0.0, 0.30], [0.34, 0.10], [0.67, 0.02], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["avance"] = -SpriteLienzo.tramos(t, retro_keys) * (LUNGE_DIST * ENCAJE_RETRO)
		p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
		p["cabeza"] = SpriteLienzo.tramos(t, cabeza_keys)
		p["brazos"] = SpriteLienzo.tramos(t, brazos_keys)
		p["ladea"] = 0.22 * SpriteLienzo.tramos(t, retro_keys)
		return p
	# TODOS LOS BICHOS ENCAJAN A 18 fps: es la duracion que espera CombatFX.T_ENCAJE, y cuadrando las
	# dos el sprite va a su velocidad natural en vez de estirado por _pose_ajustar.
	_montar_animacion(anims, esc, "encaje", false, 18.0, pose, true, 1, 4)


# MORIRSE. OCHO fotogramas en UNA sola direccion: la muerte solo se ve en la pantalla de combate, y
# ahi al bicho se le mira siempre de frente. Para el mapa esta 'cadaver', que es lo contrario.
#
# SE HINCA DE RODILLAS Y SE VENCE HACIA DELANTE, apoyando una mano. NO vuelca de costado como el
# jabali ni se desmorona como el coloso: los dos son muertes de cosas que pierden su forma, y este es
# un guerrero. Un jefe que otorga rango tiene que caer como cae un rival: de rodillas primero,
# aguantandose con un brazo, y solo despues abajo.
#
# Y ES LA MUERTE MAS LARGA DEL JUEGO A PROPOSITO -- 9 fps sobre ocho marcos --, porque es la unica
# que el jugador ha estado quince minutos esperando.
static func _pose_muerte(t: float) -> Dictionary:
	# Las rodillas ceden primero, y no a la vez: primero una, luego las dos.
	var rodilla_keys := [[0.0, 0.0], [0.16, 0.25], [0.34, 0.70], [0.55, 1.0], [1.0, 1.0]]
	# 'vuelca' lo echa hacia delante sobre la mano de apoyo. Llega a 1,0 y no mas: doblado del todo
	# se lee como un ovillo y deja de reconocerse.
	var vuelca_keys := [[0.0, 0.0], [0.16, 0.08], [0.34, 0.28], [0.55, 0.62], [0.78, 0.90],
		[1.0, 1.0]]
	var agacha_keys := [[0.0, 0.10], [0.16, 0.40], [0.34, 0.70], [0.55, 0.88], [1.0, 0.92]]
	# La cabeza se descuelga del todo: es lo ultimo que cae y lo que remata la lectura.
	var cabeza_keys := [[0.0, 0.6], [0.16, -1.2], [0.34, -2.4], [0.55, -3.4], [1.0, -4.0]]
	# Un brazo se adelanta a apoyarse (el otro cuelga): 'brazos' negativo lo lleva hacia delante.
	var brazos_keys := [[0.0, 0.0], [0.16, 0.30], [0.34, 0.62], [0.55, 0.80], [1.0, 0.85]]
	var p: Dictionary = _reposo()
	p["rodilla"] = SpriteLienzo.tramos(t, rodilla_keys)
	p["vuelca"] = SpriteLienzo.tramos(t, vuelca_keys)
	p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
	p["cabeza"] = SpriteLienzo.tramos(t, cabeza_keys)
	p["brazos"] = SpriteLienzo.tramos(t, brazos_keys)
	return p


static func _montar_muerte(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return _pose_muerte(t)
	_montar_animacion(anims, esc, "muerte", false, 9.0, pose, true, 1, 8)


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
			# La GEOMETRIA se cachea por (animacion, frame, direccion, escala) y NO por color: es lo
			# que evita que entrar a un piso lleno de bichos congele el juego.
			var clave: String = "%s_%d_%d_%.2f" % [nombre, i, dir, esc]
			var plant: PackedByteArray = _cache_plantillas.get(clave, PackedByteArray())
			if plant.is_empty():
				plant = _plantilla(dir, pose_fn.call(float(i) / divisor), esc)
				_cache_plantillas[clave] = plant
			plantillas.append(plant)
		anims.append({"nombre": "%s_%d" % [nombre, dir], "loop": loop, "fps": fps,
			"plantillas": plantillas})


# Le sube la saturacion para devolverle lo rojizo: cuantizado, el pardo se va a un marron de raton.
static func _calido(color: Color) -> Color:
	var out := Color.from_hsv(color.h, minf(1.0, color.s * 1.22 + 0.10), color.v)
	out.a = color.a
	return out


# Los colores de cada Tono, EN EL ORDEN DEL ENUM (contrato con SpriteLienzo.paleta).
static func _colores(color: Color) -> Array:
	var base: Color = _calido(color)
	return [
		Color(0, 0, 0, 0),                    # VACIO
		Color(0, 0, 0, 0.22),                 # SOMBRA_SUELO
		base.darkened(0.70),                  # BORDE
		# LAS PEZUÑAS, casi negras. Son el remate oscuro de abajo, igual que las patas del jabali, y
		# lo que hace que las piernas se lean como de toro y no como botas.
		base.darkened(0.66),                  # PEZUNA_T
		base.darkened(0.42),                  # PIERNA_OSC (el pelo largo de las cañas)
		# LA PENUMBRA VA FUERTE (0,38 y no 0,26). Es el tono del brazo y la pierna del FONDO, y de
		# perfil es lo unico que los separa del torso -- alli las tres piezas caen sobre el mismo eje
		# de pantalla. Con una penumbra suave la diferencia no llegaba a leerse y el bicho de lado
		# seguia siendo un bulto.
		base.darkened(0.38),                  # SOMBRA (el costado y lo que va al fondo)
		base,                                 # BASE
		# El PELO iluminado del lomo y los hombros. Se aclara HACIA UN OCRE ROJIZO y no hacia el
		# blanco: 'lightened' desatura, y sobre un pardo ya apagado deja un gris de raton.
		base.lerp(Color(0.85, 0.62, 0.38), 0.40),   # CLARO
		# EL MORRO VA CLARO Y ROSADO, no oscuro. Con un morro mas oscuro que la cara, la cabeza salia
		# como una masa parda sin rasgos: lo unico que se le veia eran dos puntos ambar. En la
		# referencia del usuario -- y en un toro de verdad -- el hocico es la mancha CLARA de la cara,
		# y es lo que la organiza. Mismo truco que el hocico del jabali.
		base.lerp(Color(0.88, 0.66, 0.60), 0.52),   # HOCICO_T
		# LOS CUERNOS en HUESO, bien claros: son su silueta y tienen que ganarle al cuerpo.
		Color(0.90, 0.86, 0.74),              # CUERNO_T
		Color(0.72, 0.68, 0.44),              # ANILLA_T (laton viejo)
		Color(0.95, 0.72, 0.18),              # OJO_T (ambar encendido)
		# EL CUERO del taparrabos y los brazaletes: pardo MUY oscuro, casi el tono del borde. Tiene
		# que leerse como una cosa puesta encima, asi que no puede ser una variacion de su piel.
		Color(0.20, 0.13, 0.09),              # CUERO_T
		Color(0.28, 0.19, 0.12),              # MANGO_T (madera)
		# EL HACHA en GRIS FRIO, y es el unico gris del bicho: es lo que la separa del hueso de los
		# cuernos (calido) y del laton de la anilla. Un metal que comparte tono con el cuerpo se lee
		# como parte del cuerpo.
		Color(0.42, 0.44, 0.48),              # HOJA_T
		Color(0.68, 0.71, 0.75),              # HOJA_CLARA (el filo)
	]


# ------------------------------------------------------------
#  GEOMETRIA
# ------------------------------------------------------------

# Las PIEZAS del minotauro para una pose, ya proyectadas a pantalla. El orden ES la profundidad: se
# pintan en ese orden y las ultimas tapan a las primeras.
static func _piezas(dir: int, pose: Dictionary, esc: float) -> Array:
	var ang: float = DIR_VECS[dir].angle() - DIR_VECS[0].angle()
	var u: float = esc / SpriteLienzo.UNIDADES_POR_CELDA    # unidades de mundo -> celdas
	var org: Vector2 = _origen(esc)
	var avance: float = float(pose["avance"])
	var resopla: float = float(pose["resopla"])
	var fase_patas: float = float(pose["patas"])
	var agacha: float = float(pose["agacha"])
	var cabeza_y: float = float(pose["cabeza"])
	var brazos: float = float(pose["brazos"])
	var ladea: float = float(pose["ladea"])
	var rodilla: float = float(pose["rodilla"])
	var vuelca: float = float(pose["vuelca"])

	# Agazapado = mas bajo. 'alto' multiplica TODAS las alturas, asi que agacharse hunde el bicho
	# entero sobre las piernas, que es lo que hace un bipedo pesado.
	var alto: float = 1.0 - 0.30 * agacha - 0.34 * rodilla
	var hincha: float = 1.0 + 0.022 * resopla

	var piezas: Array = []
	var desp := Vector2(0.0, avance).rotated(ang)
	var s_a: float = sin(ang)
	var c_a: float = cos(ang)

	# local (x ancho, y largo, z altura, en unidades de mundo) -> celda de pantalla.
	# 'gira' a false deja la pieza SIN rotar su forma (para las que ya vienen orientadas a mano).
	var poner := func(local: Vector3, r: Vector3, tono: int, solo_sobre: Array = [],
			en_suelo: bool = false) -> void:
		# EL LADEO Y EL VUELCO, los dos en el plano de delante: 'ladea' inclina el bicho de costado
		# (la cornada) y 'vuelca' lo echa hacia delante sobre la mano (la muerte). Se aplican aqui y
		# no pieza a pieza porque tienen que inclinar el cuerpo ENTERO alrededor de los pies: si solo
		# se aplicaran al torso, las piernas se quedarian de pie y el bicho se partiria por la
		# cintura.
		var lx: float = local.x + local.z * ladea * 0.14
		# El coeficiente del vuelco es CORTO (0,18) por la misma razon que el plegado de la rodilla:
		# inclinar alrededor de los pies mueve las piezas altas mas que las bajas, asi que cada junta
		# vertical de la pierna se ABRE en proporcion a lo separadas que esten sus piezas en altura.
		# Con 0,30 la junta muslo-corvejon se abria 5,8 unidades contra 5,5 de suma de radios y la
		# pierna se partia en dos en el cadaver.
		var ly: float = local.y + local.z * vuelca * 0.18
		var p := Vector2(lx, ly)
		var rot: Vector2 = p.rotated(ang) + desp
		var z: float = 0.0 if en_suelo else local.z * alto * hincha
		var sx: float = org.x + rot.x * u
		var sy: float = org.y + (rot.y * SpriteLienzo.COS_CAM - z * SpriteLienzo.SIN_CAM) * u
		var ry: float = r.y
		var rxm: float = r.x
		# LA PERSPECTIVA SE MIDE SOBRE EL RADIO YA ROTADO. El motor aplasta el eje VERTICAL DE
		# PANTALLA por 'persp' DESPUES de girar la pieza, pero 'persp_de' recibe el radio a lo LARGO,
		# y los dos solo coinciden mirando al SUR: girado 90 grados, el que cae en vertical es el
		# radio a lo ANCHO. Sin esto las piezas pierden altura al girar y se sueltan del cuerpo en
		# siete de las ocho direcciones -- lo que le paso a las patas del acechador, cuya firma era
		# justamente "mal en todas menos en S".
		var ry_rot: float = sqrt(rxm * rxm * s_a * s_a + ry * ry * c_a * c_a)
		piezas.append({"pos": Vector2(sx, sy), "radio": Vector2(rxm * u, ry * u),
			"gira_forma": true, "tono": tono, "ang": ang,
			"persp": SpriteLienzo.persp_de(ry_rot, r.z * alto), "solo_sobre": solo_sobre})

	# SOMBRA DE CONTACTO, lo primero (va debajo). A ALTURA CERO: no sube con el bicho.
	poner.call(Vector3(0.0, 0.0, 0.0), Vector3(PIERNA_X + PEZUNA_R.x, PEZUNA_R.y * 1.5, 0.0),
		Tono.SOMBRA_SUELO, [], true)

	# --- LAS PIERNAS. Las cuatro piezas de cada una se mueven JUNTAS con el paso, y al hincarse de
	# rodillas la pierna se pliega: el muslo baja, el corvejon se va hacia atras y la caña se tumba.
	#
	# SE DIBUJA PRIMERO LA DEL FONDO. El orden de esta lista ES la profundidad -- aqui no hay z-buffer
	# --, asi que con el orden fijo [-1, 1] la pierna del fondo se pintaba ENCIMA de la de delante en
	# la mitad de las direcciones.
	var lados_pierna: Array = [-1.0, 1.0]
	if Vector2(-PIERNA_X, 0.0).rotated(ang).y > 0.0:
		lados_pierna = [1.0, -1.0]
	for lado in lados_pierna:
		var swing: float = fase_patas * lado
		var y_off: float = swing * PASO_LARGO
		# Al andar, la pierna adelantada tambien SE LEVANTA. Sin esto los pies patinan por el suelo.
		var z_off: float = maxf(0.0, swing) * PASO_ALZA
		# De rodillas: esta pierna se pliega hacia atras y baja.
		var rod: float = rodilla * (1.0 if lado > 0.0 else 0.82)
		# EL PLEGADO DE LA RODILLA VA CORTO EN Y. Al primer intento el corvejon se iba 3,0 unidades
		# hacia atras y la caña 4,6, y con el muslo casi quieto la distancia entre sus centros (5,6)
		# superaba la SUMA DE SUS RADIOS (5,5): la pierna se partia en dos en el cadaver. Y encima
		# 'vuelca' lo empeoraba, porque mueve mas las piezas altas que las bajas -- es una inclinacion
		# alrededor de los pies -- asi que le sumaba otras 1,7 justo en la misma junta.
		#
		# Doblar una cadena cuesta solape igual que estirarla. Aqui se pliega la mitad y se lee igual.
		# Y LA PIERNA DEL FONDO TAMBIEN VA EN PENUMBRA, por lo mismo que el brazo: de perfil las dos
		# caen sobre el mismo eje de pantalla y en el mismo tono se leen como una sola pata gorda.
		var pierna_fondo: bool = Vector2(lado * PIERNA_X, 0.0).rotated(ang).y <= 0.0
		var tono_muslo: int = Tono.SOMBRA if pierna_fondo else Tono.BASE
		poner.call(Vector3(lado * PIERNA_X, MUSLO.y + y_off * 0.5, MUSLO.z - rod * 4.2),
			MUSLO_R, tono_muslo)
		poner.call(Vector3(lado * PIERNA_X, CORVEJON.y + y_off * 0.7 - rod * 1.5,
				CORVEJON.z - rod * 5.4), CORVEJON_R, Tono.PIERNA_OSC)
		poner.call(Vector3(lado * PIERNA_X, CANA.y + y_off - rod * 2.6, CANA.z + z_off - rod * 3.4),
			CANA_R, Tono.PIERNA_OSC)
		poner.call(Vector3(lado * PIERNA_X, PEZUNA.y + y_off - rod * 3.4,
				PEZUNA.z + z_off - rod * 0.4), PEZUNA_R, Tono.PEZUNA_T)

	# QUE BRAZO VA DELANTE sale de la Y del hombro YA GIRADA. Con HOMBRO_Y en cero exacto la prueba
	# daria falso para los DOS y el bicho de frente dibujaria sus dos brazos como "el de detras".
	var lados_brazo: Array = [-1.0, 1.0]
	var detras: Array = []
	var delante: Array = []
	for lado in lados_brazo:
		if Vector2(lado * HOMBRO_X, HOMBRO_Y).rotated(ang).y > 0.0:
			delante.append(lado)
		else:
			detras.append(lado)

	# Dibuja un brazo entero: cadena de piezas por PASOS UNITARIOS, con CODO, en el plano Y-Z.
	var brazo := func(lado: float) -> void:
		# 'brazos' > 0 lo sube por DELANTE (bramido, apoyo al morir); < 0 lo echa atras (correr).
		var a: float = lerpf(BRAZO_ANG_REPOSO, BRAZO_ANG_ALTO, maxf(0.0, brazos)) \
			+ minf(0.0, brazos) * 1.2
		var hz: float = HOMBRO_Z - BRAZO_BAJA
		var al_fondo: bool = lado in detras
		if al_fondo:
			hz -= HOMBRO_BAJA_DETRAS
		# EL BRAZO DEL FONDO VA EN PENUMBRA, y esto es lo que salva el PERFIL. De lado, los dos brazos,
		# el torso y las piernas caen sobre el mismo eje de pantalla -- lo que los separa a lo ancho
		# pasa a ser PROFUNDIDAD, que no se ve -- asi que, todos en el mismo tono, el bicho salia como
		# un BULTO sin lectura interna: no se distinguian ni brazos ni piernas.
		#
		# El codo ayuda pero no basta. Lo que de verdad los separa es que el de atras este mas oscuro,
		# que ademas es lo que pasa de verdad: la luz viene de arriba y delante. Y no contradice la
		# regla del golem ("una pieza con su propia LUZ se lee como una pieza aparte"): alli eso era
		# malo porque el hombro TENIA que fundirse con el cuerpo; aqui es justo lo que se busca.
		var tono_brazo: int = Tono.SOMBRA if al_fondo else Tono.BASE
		var p3 := Vector3(lado * HOMBRO_X, HOMBRO_Y, hz)
		for k in BRAZO_SEGMENTOS:
			var f: float = float(k) / float(BRAZO_SEGMENTOS - 1)
			poner.call(p3, Vector3.ONE * lerpf(BRAZO_R0, BRAZO_R1, f), tono_brazo)
			# EL BRAZALETE: va sobre el antebrazo y por ENCIMA del segmento, no en vez de el, asi que
			# si algun dia se mueve la cadena el brazalete la sigue solo.
			if k == BRAZALETE_SEG:
				poner.call(p3, BRAZALETE_R, Tono.CUERO_T, [Tono.BASE])
			# POR PASOS UNITARIOS: se avanza BRAZO_PASO en la direccion actual y DESPUES se curva. El
			# paso no cambia nunca, asi que dos piezas seguidas se solapan igual arriba que abajo --
			# que es lo unico que permite curvar la cadena sin descoserla.
			p3.y += sin(a) * BRAZO_PASO
			p3.z -= cos(a) * BRAZO_PASO
			p3.x += lado * BRAZO_ABRE
			a += BRAZO_CODO / float(BRAZO_SEGMENTOS - 1)
		# EL PUÑO, colgando del ultimo segmento.
		poner.call(p3, PUNO_R, tono_brazo)

		# --- EL HACHA, colgando del puño de UNA mano. Cuelga a plomo (no sigue el arco del brazo):
		# pesa, y lo que pesa apunta al suelo. Eso ademas hace que en el bramido -- con el brazo en
		# alto -- el hacha quede levantada y siga colgando, que es exactamente lo que se quiere ver.
		if is_equal_approx(lado, HACHA_LADO):
			var mp := Vector3(p3.x + lado * 0.6, p3.y, p3.z - PUNO_R.z * 0.5)
			for k in MANGO_SEGMENTOS:
				# El mango es fino, asi que sus piezas van ALARGADAS en el eje del palo (r.z alto):
				# redondas y del mismo grosor dejarian huecos entre ellas, y un mango con huecos no
				# se lee como un palo.
				poner.call(mp, Vector3(MANGO_R, MANGO_R, MANGO_LARGO), Tono.MANGO_T)
				mp.z -= MANGO_PASO
			# LA HOJA: una media luna abierta hacia FUERA, en tres piezas de altura decreciente. El
			# filo va aparte y mas claro, en el canto de fuera: sin el, la hoja es una mancha gris.
			var hx: float = mp.x + lado * HOJA_ANCHO * 0.45
			poner.call(Vector3(hx, mp.y, mp.z + MANGO_PASO * 0.4),
				Vector3(HOJA_ANCHO * 0.55, HOJA_GRUESO, HOJA_ALTO), Tono.HOJA_T)
			poner.call(Vector3(mp.x + lado * HOJA_ANCHO, mp.y, mp.z + MANGO_PASO * 0.4),
				Vector3(HOJA_ANCHO * 0.42, HOJA_GRUESO, HOJA_ALTO * 0.78), Tono.HOJA_T)
			poner.call(Vector3(mp.x + lado * (HOJA_ANCHO + HOJA_ANCHO * 0.34), mp.y,
					mp.z + MANGO_PASO * 0.4),
				Vector3(HOJA_ANCHO * 0.20, HOJA_GRUESO * 0.8, HOJA_ALTO * 0.52), Tono.HOJA_CLARA)

	# EL BRAZO DE DETRAS, antes que el torso: el cuerpo tiene que taparlo.
	for lado in detras:
		brazo.call(lado)

	# --- EL TORSO EN V, de abajo arriba.
	poner.call(CADERA, CADERA_R, Tono.BASE)
	# EL TAPARRABOS, justo despues de la cadera para que se recorte sobre ella, y el FALDON que cuelga
	# por delante. Van en cuero oscuro: lo que le da escala al bicho es llevar encima algo hecho por
	# alguien (ver CUERO_T).
	poner.call(TAPARRABOS, TAPARRABOS_R, Tono.CUERO_T, [Tono.BASE])
	poner.call(FALDON, FALDON_R, Tono.CUERO_T)
	poner.call(CINTURA, CINTURA_R, Tono.BASE)
	poner.call(PECHO, PECHO_R, Tono.BASE)
	# El PELO ILUMINADO de lo alto de la espalda. Solo sobre BASE, para no aclarar ni pezuñas ni
	# contorno.
	poner.call(Vector3(0.0, PECHO.y - 2.4, PECHO.z + PECHO_R.z * 0.58),
		Vector3(PECHO_R.x * 0.66, PECHO_R.y * 0.72, PECHO_R.z), Tono.CLARO, [Tono.BASE])
	# PECTORALES, por delante.
	for lado in [-1.0, 1.0]:
		poner.call(Vector3(lado * PECTORAL.x, PECTORAL.y, PECTORAL.z), PECTORAL_R, Tono.SOMBRA,
			[Tono.BASE])

	# LOS HOMBROS GIRAN Y VAN JUSTO ANTES DE LA CABEZA. Girando, de perfil uno se va hacia la camara
	# y otro al fondo, y con la cabeza en medio saldrian tres bolas apiladas (muñeco de nieve); pero
	# sin girar, de perfil el bicho enseña DOS hombros donde deberia enseñar uno. Dibujandolos ANTES
	# de la cabeza, la cabeza tapa al del fondo y queda solo el de delante.
	#
	# Y VAN EN TONO BASE, compartiendo el degradado del cuerpo: una pieza con su propia LUZ se lee
	# como una pieza APARTE, o sea como una hombrera de armadura. Eso es del coloso; este tiene
	# hombros, no hombreras.
	for lado in [-1.0, 1.0]:
		var hz2: float = HOMBRO_Z
		if lado in detras:
			hz2 -= HOMBRO_BAJA_DETRAS
		poner.call(Vector3(lado * HOMBRO_X, HOMBRO_Y, hz2), HOMBRO_R, Tono.BASE)

	# QUIEN LE VE LA CARA: de ESPALDAS no se le ven ni los ojos ni la anilla ni el hocico. Un bicho
	# que se aleja enseña la nuca, y eso es lo que hace que se lea de un vistazo si viene o si huye.
	var frente: float = DIR_VECS[dir].y
	var lados: Array = [-1.0, 1.0]
	if frente <= -0.5:
		lados = []
	elif frente < -0.2:
		lados = [signf(DIR_VECS[dir].x)]

	# --- LOS CUERNOS: cadena por pasos unitarios que sale hacia FUERA, sube y se curva hacia DELANTE.
	# Se dibujan SIEMPRE, tambien de espaldas: son su silueta, y un minotauro de espaldas sigue
	# teniendo cuernos.
	var cuerno := func(lado: float) -> void:
		var cp := Vector3(lado * CUERNO_BASE.x, CUERNO_BASE.y, CUERNO_BASE.z + cabeza_y)
		# 'cv' es la inclinacion en el plano vertical: empieza abierto hacia fuera y se va cerrando
		# hacia arriba y delante.
		var cv: float = 0.0
		for k in CUERNO_SEGMENTOS:
			var f: float = float(k) / float(CUERNO_SEGMENTOS - 1)
			poner.call(cp, Vector3.ONE * lerpf(CUERNO_R0, CUERNO_R1, f), Tono.CUERNO_T)
			cp.x += lado * cos(cv) * CUERNO_ABRE * CUERNO_PASO
			cp.z += sin(cv + 0.55) * CUERNO_PASO
			cp.y += (1.0 - cos(cv)) * CUERNO_PASO * 0.55
			cv += CUERNO_GIRO

	# Que cuerno va al fondo, con la misma prueba que los brazos: la X de su base YA GIRADA.
	var detras_cuerno: Array = []
	var delante_cuerno: Array = []
	for lado in [-1.0, 1.0]:
		if Vector2(lado * CUERNO_BASE.x, CUERNO_BASE.y).rotated(ang).y > 0.0:
			delante_cuerno.append(lado)
		else:
			detras_cuerno.append(lado)

	# EL CUERNO DEL FONDO, ANTES DE LA CABEZA: asi el craneo lo tapa y solo asoma la punta por detras,
	# que es lo que se ve de verdad. Pintado despues, se subia por encima de la cabeza y el bicho
	# parecia llevar el cuerno clavado en la frente.
	for lado in detras_cuerno:
		cuerno.call(lado)

	# CUELLO y CABEZA. 'cabeza_y' las sube y las baja: al andar cabecea, en la cornada se hunde y en
	# el enganche sube de golpe.
	poner.call(Vector3(CUELLO.x, CUELLO.y, CUELLO.z + cabeza_y * 0.45), CUELLO_R, Tono.BASE)
	poner.call(Vector3(CABEZA.x, CABEZA.y, CABEZA.z + cabeza_y), CABEZA_R, Tono.BASE)
	# El HOCICO en su tono solo si se le ve la cara: de espaldas lo que asoma es la nuca, y una mancha
	# oscura ahi canta como un borron en mitad del cogote.
	poner.call(Vector3(HOCICO.x, HOCICO.y, HOCICO.z + cabeza_y), HOCICO_R,
		Tono.HOCICO_T if not lados.is_empty() else Tono.SOMBRA)

	# OREJAS, a los lados y hacia fuera. Estas SI se ven de espaldas: son parte de la silueta.
	for lado in [-1.0, 1.0]:
		poner.call(Vector3(lado * OREJA.x, OREJA.y, OREJA.z + cabeza_y), OREJA_R, Tono.SOMBRA)

	# EL CUERNO DE DELANTE, al final. El del fondo ya se dibujo antes de la cabeza (ver mas arriba):
	# pintados los dos aqui, el del fondo se subia ENCIMA del craneo en vez de asomar por detras.
	for lado in delante_cuerno:
		cuerno.call(lado)

	if not lados.is_empty():
		# LA ANILLA: un arco de piezas colgando del hocico. Es el detalle que remata al bicho, y va
		# en laton para que no se confunda con los cuernos (que son hueso).
		for k in ANILLA_SEGMENTOS:
			var fa: float = float(k) / float(ANILLA_SEGMENTOS - 1)
			var aa: float = PI * (0.12 + 0.76 * fa)      # medio arco, colgando hacia abajo
			poner.call(Vector3(ANILLA.x + cos(aa) * ANILLA_R, ANILLA.y,
					ANILLA.z + cabeza_y - sin(aa) * ANILLA_R),
				Vector3.ONE * ANILLA_GROSOR, Tono.ANILLA_T)

	# OJOS, los ULTIMOS de la cara.
	for l in lados:
		poner.call(Vector3(l * OJO.x, OJO.y, OJO.z + cabeza_y), OJO_R, Tono.OJO_T)

	# EL BRAZO DE DELANTE, al final del todo: va por encima del torso y de la cabeza.
	for lado in delante:
		brazo.call(lado)

	return piezas


# La plantilla de un frame: que tono le toca a cada celda.
static func _plantilla(dir: int, pose: Dictionary, esc: float) -> PackedByteArray:
	var lz: Vector2i = _lienzo(esc)
	var plant := PackedByteArray()
	plant.resize(lz.x * lz.y)
	plant.fill(0)
	var piezas: Array = _piezas(dir, pose, esc)
	for p in piezas:
		var pos: Vector2 = p["pos"]
		var r: Vector2 = p["radio"]
		SpriteLienzo.elipse(plant, lz.x, lz.y, pos.x, pos.y, r.x, r.y, int(p["tono"]),
			float(p["ang"]), p["solo_sobre"], float(p["persp"]))

	# CONTORNO al final, sobre la silueta ya completa (ver SpriteLienzo.contornear).
	SpriteLienzo.contornear(plant, SpriteLienzo.caja_de_piezas(piezas, lz.x, lz.y), lz.x, lz.y,
		Tono.BORDE, Tono.VACIO, Tono.SOMBRA_SUELO)
	return plant
