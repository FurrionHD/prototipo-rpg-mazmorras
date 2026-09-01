# ============================================================
#  coloso_sprites.gd  (class_name ColosoSprites)
#  El COLOSO (piso 10+) dibujado por codigo. Solo geometria: el motor esta en SpriteLienzo y quien
#  reparte los generadores es SpritesEnemigo (por NOMBRE, no por familia: los tres constructos y la
#  Bestia acorazada son los cuatro familia PIEDRA).
#
#  ES EL ENEMIGO MAS ALTO DEL JUEGO, con diferencia: 43 unidades de mundo a escala 4,0 son 172 en
#  pantalla, contra las 102 del golem y las 110 del trent. Y eso SALE GRATIS: 'tam_cuerpo' devuelve
#  solo la HUELLA EN PLANTA, asi que un bicho no choca con nada por ser alto. Lo unico que hay que
#  vigilar es lo ANCHO -- 12 unidades = 48 px, la mitad del vano de 96 de un pasillo -- y que el
#  cadaver quepa en el lienzo.
#
#  ESTA LABRADO, Y ESO ES TODO LO QUE LO SEPARA DEL GOLEM. Comparten bloque, piso y silueta general
#  (bipedo con brazos largos), asi que la diferencia tiene que verse a la primera:
#     GOLEM                          COLOSO
#     barro, ocre                    granito, gris azulado
#     bultos redondos                SILLARES con aristas
#     ancho y bajo                   estrecho y altisimo
#     cabezota sin cuello            cabeza PEQUEÑA hundida entre dos hombreras cubicas
#  Por eso este es el primer bicho que usa 'SpriteLienzo.bloque' -- la primitiva rectangular, que se
#  añadio al motor para el: con elipses no hay forma de dibujar un sillar.
#
#  SUS DOS HABILIDADES ESTAN DIBUJADAS:
#  - "Pisoton sismico": levanta un pie del tamaño de una lapida y lo estampa. Es la embestida, y el
#    pie se queda ARRIBA un buen rato antes de bajar -- es una mole, no puede ser rapida.
#  - "Muralla": las RUNAS frias de las juntas, que es lo que lo mantiene de una pieza. Es lo unico
#    encendido de un bicho gris, y se apaga al morir.
#
#  MUERE DE RODILLAS Y SE DESMORONA. Le revienta una rodilla, se hinca, le cede la otra, se desploma
#  hacia delante con la cabeza gacha -- y ahi se le van las runas y SE DESHACE EN ESCOMBROS: cada
#  sillar se suelta y cae, y lo que queda en el mapa es un MONTON DE PIEDRAS. Es lo unico que puede
#  quedar de algo que solo se sostenia por magia.
#
#  NO SE VA DE LADO, y eso es una decision medida: se
#  probo volcandolo como el escarabajo y la gargola y NO HAY QUIEN LO LEA -- un bloque de 43
#  unidades tumbado a 45 grados es un amasijo de sillares repartidos por la pantalla, y en ocho
#  fotogramas no da tiempo a entender que ha pasado. De rodillas se entiende al primer fotograma, es
#  la estampa clasica del coloso caido, y ademas le da su propia muerte frente a las otras dos del
#  bloque: el golem se derrumba en un monton y la gargola cae de lado como una estatua.
# ============================================================

extends RefCounted
class_name ColosoSprites

const FRAMES := 8

# --- El coloso mirando al SUR, en unidades de MUNDO (origen = donde toca el suelo, +Y hacia donde
# mira, +Z hacia arriba). A escala 1.0 mide unas 20 unidades de ancho de hombreras. ---
#
# LAS MEDIDAS DE MUNDO SE QUEDAN CONTENIDAS Y EL TAMAÑO LO PONE LA ESCALA. Es lo que hace que un
# bicho de 4,0 no cueste mas que uno de 2,8: el lienzo sale de (unidades_de_mundo x escala), asi que
# 20 x 4,0 da el mismo orden que las 22 x 2,8 del golem. Dibujarlo con medidas de mundo enormes Y
# escala grande seria multiplicar dos veces.
const ANCHO_MUNDO := 20.0

# --- LAS PIERNAS: dos columnas de sillares. Un coloso no tiene musculo, tiene pilares.
const PIERNA_X := 3.7
# Los cuatro sillares de cada pierna, de abajo arriba. El PIE es una losa ancha y plana -- "un pie
# del tamaño de una lapida", que es literalmente lo que dice su Pisoton.
#
# CADA SILLAR SE METE VARIAS UNIDADES DENTRO DEL DE ABAJO. No es holgura de sobra: al levantar el
# pie y al partirse la rodilla los bloques se separan, y si el solape en reposo es de una unidad
# (dos o tres celdas) se despegan en cuanto la pierna hace algo. El test de islas canto 31
# fotogramas rotos por esto. Aqui van >= 1,4 unidades, o sea 5 celdas a escala 4,0.
const PIE := Vector3(0.0, 0.8, 1.6)
const PIE_R := Vector3(3.1, 3.8, 1.7)
const ESPINILLA := Vector3(0.0, 0.0, 7.6)
const ESPINILLA_R := Vector3(2.3, 2.3, 6.2)
const RODILLA := Vector3(0.0, 0.3, 14.2)
const RODILLA_R := Vector3(2.7, 2.6, 2.4)
const MUSLO := Vector3(0.0, 0.0, 19.0)
const MUSLO_R := Vector3(2.9, 2.8, 4.6)
# Corto y lentisimo: tiene Agilidad 8, la mas baja del juego.
const PASO_LARGO := 2.8
const PASO_ALZA := 1.4

# CADERA: el sillar que une las dos piernas. Ancho y bajo.
const CADERA := Vector3(0.0, 0.0, 24.6)
const CADERA_R := Vector3(6.0, 4.2, 3.0)
# TORSO: el bloque grande. ESTRECHO PARA LO ALTO QUE ES -- 12 unidades de ancho contra 43 de alto --,
# que es lo que le da la proporcion de torre y lo que le permite pasar por un pasillo.
const TORSO := Vector3(0.0, 0.4, 32.4)
const TORSO_R := Vector3(6.0, 4.6, 6.2)
const TORSO_ANCLA_R := Vector3(4.6, 4.6, 6.2)

# HOMBRERAS: dos sillares CUBICOS que sobresalen por los lados. Aqui SI son hombreras -- placas
# puestas encima -- al reves que en el golem, donde el hombro tenia que fundirse con el pegote. Son
# lo que hace que la cabeza se lea como pequeña.
# Y ARRIBA DEL TODO, a la altura de la cumbre del torso: una hombrera se APOYA en el hombro y
# sobresale por encima. Mas baja se leia como un bulto en el costado, no como una placa.
const HOMBRO_X := 6.3
const HOMBRO_Z := 38.6
const HOMBRO_R := Vector3(3.4, 3.2, 2.9)
# Y ADELANTADAS UN PELIN. No es dibujo: la prueba de profundidad que decide que brazo va delante es
# `.y > 0` ya girada, y con la Y en CERO exacto da falso para los dos -- el coloso de frente
# dibujaria sus dos brazos como "el de detras". Es la trampa que ya mordio el golem.
const HOMBRO_Y := 0.9
# CUANTO SE BAJA LA HOMBRERA DE DETRAS. Es un apaño de DIBUJO, no de geometria, y hace falta por lo
# de siempre: de perfil, la que se va al fondo sube en pantalla 0,707 unidades por cada una de
# profundidad, asi que se le plantaba a la altura de la cabeza y el coloso enseñaba una placa
# flotando por encima del hombro. Bajandola, la silueta se cierra y sigue leyendose como la hombrera
# del otro lado asomando por detras -- que es lo que es.
const HOMBRO_BAJA_DETRAS := 3.0

# CABEZA: PEQUEÑA y hundida entre las hombreras. Es la proporcion que dice "esto no es una persona
# de piedra, es un edificio": una cabeza a escala humana sobre unos hombros de dos metros.
#
# LA SEPARACION SE MIDE EN (y - z), NO EN ALTURA. Con la camara a 45 grados la altura en pantalla
# sale de (y - z), y el margen tiene que superar el RADIO EN PANTALLA de la cabeza o los tres bultos
# de arriba (hombrera, cabeza, hombrera) se leen como una fila. Aqui: cabeza y-z = -44,0 y hombrera
# -38,7, o sea 5,3 unidades = 13 celdas, contra 9,7 de radio. Es la leccion del golem y de la
# gargola, las dos veces por lo mismo.
#
# Y LLEVA CUELLO, que no es un adorno: la cabeza solo se metia 0,3 unidades en las hombreras -- UNA
# celda -- y mirando al NORTE, donde las hombreras suben en pantalla y la cabeza baja, ese solape
# desaparecia y la cabeza salia FLOTANDO. Es la vieja regla: un solape de una celda no es un solape.
# Un sillar entre medias lo cose y ademas le da estructura al cuello.
const CUELLO := Vector3(0.0, 0.7, 39.6)
const CUELLO_R := Vector3(1.9, 1.9, 2.6)
const CABEZA := Vector3(0.0, 1.0, 43.4)
const CABEZA_R := Vector3(2.8, 2.6, 2.9)
const CABEZA_ANCLA_R := Vector3(2.6, 2.6, 2.9)
# EL VISOR: la ranura hundida de la cara, donde viven las runas de los ojos. Sin el, los dos puntos
# claros flotan en un cubo gris y no hay mirada.
const VISOR := Vector3(0.0, 2.0, 43.6)
const VISOR_R := Vector3(2.3, 1.0, 0.9)
const OJO_X := 1.15
const OJO_R := Vector3(0.75, 0.7, 0.7)

# --- LOS BRAZOS: cadenas de sillares, LARGOS (llegan por debajo de la cadera) y rematados en un
# puño-mazo. Se construyen por PASOS UNITARIOS y con CODO, igual que los del golem: es la unica
# forma de curvarlos sin que la cadena se descosa, y sin codo, de perfil el brazo se pinta encima
# del torso y de las piernas y tapa el bicho entero.
#
# EL PASO, MENOR QUE EL GROSOR -- Y CON MARGEN. Estaba en 4,0 contra un sillar de 2,0 de radio en la
# muñeca, o sea 4,0 de diametro: TANGENTES, no solapados. Los bloques se rozaban en una linea y el
# puño, que se cuelga del ultimo, salia DESPEGADO en el pisoton, al andar y al morir. La regla es la
# de siempre (la cola de la rata, los brazos del trent, las patas del ciempies), pero aqui pica mas
# facil porque un paso que "cuadra justo" parece correcto: tiene que SOBRAR.
const BRAZO_SEGMENTOS := 7
const BRAZO_PASO := 3.0
const BRAZO_R0 := 2.6              # en el hombro
const BRAZO_R1 := 2.2              # en la muñeca -- 4,4 de diametro contra 3,0 de paso
const BRAZO_BAJA := 2.6            # nace por debajo del centro de la hombrera, o la tapa entera
# EL ARCO DEL BRAZO VA EN EL PLANO DE DELANTE (0 = a plomo, PI/2 = hacia delante, 2,6 = sobre la
# cabeza) y NO en el de los costados: interpolando por los costados, el camino de "colgando" a "en
# alto" pasa por la HORIZONTAL y el bicho se queda en CRUZ.
const BRAZO_ANG_REPOSO := 0.10
const BRAZO_ANG_ALTO := 2.60
const BRAZO_CODO := 0.85
const BRAZO_ADELANTA := 0.85
const BRAZO_ABRE := 0.11
const BRAZO_SEPARA := 0.6
const PUNO_R := Vector3(3.1, 3.0, 3.0)

# LAS RUNAS: las lineas frias que corren por las juntas y lo mantienen de una pieza. Son su
# "Muralla" dibujada, y lo unico encendido de un bicho gris. Van en el PECHO, y como el torso no
# gira hay que compensarles la altura al girar (ver el anclaje en _piezas).
const RUNA_DIR := Vector3(0.0, 0.94, 0.34)
const RUNA_HUNDE := 1.1
const RUNA_TRAMOS := 3
const RUNA_R := Vector3(2.4, 0.55, 0.55)
const RUNA_BAJA := 2.4

# EL DESMORONAMIENTO: donde acaba cada sillar cuando el coloso se deshace.
#
# EL MONTON TIENE QUE QUEDAR DE UNA PIEZA. Repartiendo los escombros por un radio grande salen
# piedras sueltas por el suelo -- que ademas el test de islas canta como "trozos sueltos", y con
# razon: un cadaver desperdigado no se lee como un cadaver, se lee como un fallo de dibujo. Con un
# radio corto los bloques se solapan entre ellos y queda un tumulo compacto, que es lo que se busca.
const ESCOMBRO_RADIO := 5.8         # cuanto se reparten a lo ancho
const ESCOMBRO_ALTO := 5.6          # lo alto que queda el monton en su centro
const ESCOMBRO_ENCOGE := 0.74       # y cuanto encoge cada sillar: un cascote es menor que la pieza

# El chaflan de los sillares: lo justo para que la esquina no sea un pico de una celda. 0 seria
# arista viva y 1 un rombo.
const CHAFLAN := 0.22

const DETRAS_ESC := 0.90
const LUNGE_DIST := 6.0
# Encaja MENOS que nadie: es lo mas pesado del juego. Se hunde sobre las piernas y ya.
const ENCAJE_RETRO := 0.16

# --- EL LIENZO, en multiplos del ancho de hombreras. RECTANGULAR y con el origen BAJO: el origen es
# el punto que toca el suelo y el bicho crece hacia arriba, MUCHO.
# ANCHO y ABAJO los manda el CADAVER, no el bicho de pie: tumbado, sus 43 unidades de alto pasan a
# ser 43 de LARGO, y ademas se va hacia el lado al que cae. Es la leccion del golem, donde de pie
# ocupaba 41 celdas por lado y el cadaver 66.
const LIENZO_ANCHO := 3.20
const LIENZO_ARRIBA := 2.30
const LIENZO_ABAJO := 1.10

# TONOS propios (el motor no sabe que es cada uno; solo mapea indice -> color, ver _colores).
enum Tono { VACIO, SOMBRA_SUELO, BORDE, JUNTA, PIERNA_OSC, PIERNA, BRAZO_OSC, BRAZO, PIEDRA_OSC,
	PIEDRA, PIEDRA_CLARA, RUNA, APAGADO }

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
	return "coloso_%s_%.2f" % [col.to_html(false), esc]


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(escala: float = 1.0) -> int:
	return _lienzo(escala).x


static func dimensiona_por_escala() -> bool:
	return true


# El CUERPO en planta (ancho, largo). SOLO TORSO, CADERA Y PIERNAS: los BRAZOS quedan fuera, igual
# que las patas de la araña, la pala del escarabajo y las alas de la gargola.
#
# ESTO ES LO QUE HACE QUE UN BICHO DE 43 UNIDADES DE ALTO QUEPA POR UN PASILLO. La altura no entra
# en la colision -- 'tam_cuerpo' es la HUELLA --, asi que el coloso puede ser todo lo alto que haga
# falta y solo hay que cuidar lo ancho: 12 unidades a escala 4,0 son 48 px, la MITAD del vano de 96.
static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	var ancho: float = maxf(TORSO_R.x, PIERNA_X + MUSLO_R.x) * 2.0
	var largo: float = maxf(TORSO_R.y, PIE_R.y + PASO_LARGO) * 2.0
	return Vector2(ancho, largo) * escala


static func _lienzo(escala: float) -> Vector2i:
	var u: float = ANCHO_MUNDO * escala / SpriteLienzo.UNIDADES_POR_CELDA
	var w: int = int(ceil(u * LIENZO_ANCHO))
	var h: int = int(ceil(u * (LIENZO_ARRIBA + LIENZO_ABAJO)))
	return Vector2i(w + (w % 2), h + (h % 2))


static func _origen(escala: float) -> Vector2:
	var l: Vector2i = _lienzo(escala)
	return Vector2(float(l.x) * 0.5, float(l.y) * LIENZO_ARRIBA / (LIENZO_ARRIBA + LIENZO_ABAJO))


static func generar(color: Color = Color(0.45, 0.45, 0.5), escala: float = 1.0) -> SpriteFrames:
	# cuantizar_hsv y no cuantizar a secas: el gris azulado del granito es un color apagado, y a esos
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
	return {"avance": 0.0, "mece": 0.0, "balanceo": 0.0, "brazos": 0.0, "alza": 0.0,
		"patas": 0.0, "agacha": 0.0, "pisa": 0.0, "cabeza": 0.0,
		# Las dos rodillas por separado: al morir le cede UNA y luego la otra, y ese desfase es lo
		# que hace que se lea como que se parte y no como que se agacha.
		"rodilla": 0.0, "rodilla2": 0.0, "desmorona": 0.0}


# Quieto: casi NADA. A 2 fps -- lo mas lento del juego, mas que el trent -- y con un balanceo
# minimo. Tiene Agilidad 8: si se mueve, deja de ser una montaña.
static func _montar_idle(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["mece"] = 0.22 * sin(TAU * t)
		p["brazos"] = 0.18 * sin(TAU * t + 0.6)
		return p
	_montar_animacion(anims, esc, "idle", true, 2.0, pose, false)


# Andando: PASOS ENORMES Y LENTOS. A 4 fps, y el peso pasa de una columna a la otra con un balanceo
# lateral marcado -- lo unico que puede hacer algo tan alto para no parecer que flota. Y se hunde en
# cada apoyo: es la sacudida que te dice cuanto pesa.
static func _montar_walk(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["patas"] = sin(TAU * t)
		p["brazos"] = -0.7 * sin(TAU * t)
		p["balanceo"] = sin(TAU * t)
		p["mece"] = 0.25 * sin(TAU * t)
		p["agacha"] = 0.10 * (1.0 - cos(TAU * t * 2.0))
		return p
	_montar_animacion(anims, esc, "walk", true, 4.0, pose, false)


# LA EMBESTIDA ES SU "PISOTON SISMICO": levanta un pie del tamaño de una lapida, lo AGUANTA arriba y
# lo estampa contra el suelo.
#
# EL PIE SE QUEDA ARRIBA MUCHO RATO (de 0,26 a 0,54) y eso no es lentitud, es la lectura: algo tan
# grande no puede moverse rapido sin dejar de leerse como grande, y ademas el aviso tiene que verse.
# Es la misma idea que la Machaca del golem.
#
# Y LO QUE REMATA EL GOLPE ES EL CUERPO ENTERO BAJANDO, no el pie: al estampar, el coloso se hunde
# sobre la otra pierna ('agacha' a 1). Sin eso el pie baja solo y parece que da una patadita.
static func _montar_embestida(anims: Array, esc: float) -> void:
	var pisa_keys := [[0.0, 0.0], [0.26, 1.0], [0.54, 1.0], [0.66, 0.0], [1.0, 0.0]]
	var agacha_keys := [[0.0, 0.0], [0.26, 0.25], [0.54, 0.30], [0.66, 1.0], [0.80, 0.55],
		[1.0, 0.15]]
	var mece_keys := [[0.0, 0.0], [0.26, -0.8], [0.54, -0.9], [0.66, 1.2], [0.80, 0.7], [1.0, 0.2]]
	var avance_keys := [[0.0, 0.0], [0.26, -0.5], [0.54, -0.6], [0.66, 5.4], [0.80, 6.0], [1.0, 4.6]]
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["pisa"] = SpriteLienzo.tramos(t, pisa_keys)
		p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
		p["mece"] = SpriteLienzo.tramos(t, mece_keys)
		p["avance"] = SpriteLienzo.tramos(t, avance_keys) * (LUNGE_DIST / 6.0)
		# Los brazos se abren un poco para equilibrarse mientras esta a la pata coja.
		p["brazos"] = 0.7 * SpriteLienzo.tramos(t, pisa_keys)
		return p
	_montar_animacion(anims, esc, "embestida", false, 9.0, pose, true)


# ENCAJAR UN GOLPE. Cuatro fotogramas en UNA direccion y EMPEZANDO YA GOLPEADO: el frame 0 es el
# impacto. Un golpe no tiene anticipacion, y con cuatro marcos un fotograma de espera se comeria la
# animacion entera.
#
# APENAS SE INMUTA, y ese es su rasgo: es lo mas pesado del juego (retrocede 0,16 contra el 0,42 de
# la gargola). Se hunde sobre las piernas y vuelve. Ni siquiera mueve la cabeza -- no tiene cuello.
static func _montar_encaje(anims: Array, esc: float) -> void:
	var retro_keys := [[0.0, 1.0], [0.34, 0.38], [0.67, 0.10], [1.0, 0.0]]
	var agacha_keys := [[0.0, 0.80], [0.34, 0.24], [0.67, 0.06], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["avance"] = -SpriteLienzo.tramos(t, retro_keys) * (LUNGE_DIST * ENCAJE_RETRO)
		p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
		p["mece"] = -0.5 * SpriteLienzo.tramos(t, retro_keys)
		return p
	# LOS BICHOS ENCAJAN A 18 fps: es la duracion que espera CombatFX.T_ENCAJE.
	_montar_animacion(anims, esc, "encaje", false, 18.0, pose, true, 1, 4)


# MORIRSE. OCHO fotogramas en UNA sola direccion: la muerte solo se ve en la pantalla de combate, y
# ahi al bicho se le mira siempre de frente. Para el mapa esta 'cadaver'.
#
# SE PARTE POR UNA RODILLA Y DESPUES SE VA ENTERO. Son DOS tiempos, y ese reparto es su muerte
# propia frente a las otras dos del bloque -- el golem se derrumba en un monton (es barro) y la
# gargola cae de una pieza:
#   1. (0 a 0,40) LE REVIENTA UNA RODILLA. Medio cuerpo se desploma de golpe. Es lo mas legible que
#      puede hacer algo tan alto: una caida entera desde 43 unidades se sale de la pantalla y no se
#      entiende; una rodilla que cede se ve enseguida.
#   2. (0,40 a 1) YA DE RODILLAS, se va de lado, tieso, sin doblarse por ningun sitio.
#
# Y NO REBOTA NI SE ASIENTA al tocar el suelo. El escarabajo blindado da un bote y el trent se
# asienta; un edificio no hace ninguna de las dos.
static func _pose_muerte(t: float) -> Dictionary:
	# PRIMERO UNA RODILLA Y LUEGO LA OTRA. El desfase entre las dos es lo que separa "se le parte una
	# pierna" de "se esta agachando": si ceden a la vez, el coloso parece que se sienta.
	var rod1_keys := [[0.0, 0.0], [0.08, 0.10], [0.20, 0.60], [0.34, 1.0], [1.0, 1.0]]
	var rod2_keys := [[0.0, 0.0], [0.34, 0.05], [0.48, 0.45], [0.64, 1.0], [1.0, 1.0]]
	# Y se viene hacia DELANTE segun se hinca: un coloso no se desploma hacia atras, lo tira su propio
	# peso. El tramo final es el que lo deja vencido sobre las rodillas.
	# El meceo se apaga al desmoronarse: va doblado por la altura de cada pieza, o sea que es una
	# CIZALLA, y sobre un monton de cascotes desplazaria cada uno una cantidad distinta y lo abriria.
	var mece_keys := [[0.0, 0.0], [0.08, -0.5], [0.20, 0.8], [0.34, 1.4], [0.64, 2.4], [0.86, 1.0],
		[1.0, 0.0]]
	# La cabeza cae la ultima y es lo que remata la estampa: un coloso arrodillado con la cabeza alta
	# sigue pareciendo que va a levantarse.
	var cab_keys := [[0.0, 0.0], [0.20, 0.15], [0.34, 0.4], [0.64, 0.9], [1.0, 1.0]]
	var agacha_keys := [[0.0, 0.0], [0.20, 0.35], [0.34, 0.6], [0.64, 0.9], [1.0, 1.0]]
	# Los brazos se descuelgan hacia delante y quedan muertos a los lados.
	var brazo_keys := [[0.0, 0.0], [0.20, 0.3], [0.64, 0.8], [1.0, 0.9]]
	# Y AL FINAL SE DESHACE. Arranca justo cuando ya esta hincado (0,62) y va ACELERANDO: lo que se
	# rompe no se rompe despacio. Los dos ultimos fotogramas ya son el monton asentandose.
	var desm_keys := [[0.0, 0.0], [0.62, 0.0], [0.74, 0.22], [0.86, 0.68], [0.94, 0.94], [1.0, 1.0]]
	var p: Dictionary = _reposo()
	p["desmorona"] = SpriteLienzo.tramos(t, desm_keys)
	p["rodilla"] = SpriteLienzo.tramos(t, rod1_keys)
	p["rodilla2"] = SpriteLienzo.tramos(t, rod2_keys)
	p["mece"] = SpriteLienzo.tramos(t, mece_keys)
	p["cabeza"] = SpriteLienzo.tramos(t, cab_keys)
	p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
	p["brazos"] = SpriteLienzo.tramos(t, brazo_keys)
	return p


static func _montar_muerte(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return _pose_muerte(t)
	_montar_animacion(anims, esc, "muerte", false, 9.0, pose, true, 1, 8)


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
			# coloso de otro tono reusa estas plantillas y solo repinta.
			var clave: String = "%s_%d_%d_%.2f" % [nombre, i, dir, esc]
			var plant: PackedByteArray = _cache_plantillas.get(clave, PackedByteArray())
			if plant.is_empty():
				plant = _plantilla(dir, pose_fn.call(float(i) / divisor), esc)
				_cache_plantillas[clave] = plant
			plantillas.append(plant)
		anims.append({"nombre": "%s_%d" % [nombre, dir], "loop": loop, "fps": fps,
			"plantillas": plantillas})


# GRANITO: gris con un punto de AZUL. Como el basalto de la gargola y el hierro del escarabajo, se
# hace subiendo la SATURACION y bajando un poco el valor -- el color que llega no es el de la ficha,
# es 'color_visual', que ya viene aclarado hacia el blanco segun la 't' del bicho, o sea desaturado
# de fabrica. Sin subirla, el granito se queda en cemento.
static func _granito(color: Color) -> Color:
	var out := Color.from_hsv(color.h, minf(1.0, color.s * 1.30 + 0.06), color.v * 0.92)
	out.a = color.a
	return out


# Los colores de cada Tono, EN EL ORDEN DEL ENUM (contrato con SpriteLienzo.paleta).
static func _colores(color: Color) -> Array:
	var c: Color = _granito(color)
	return [
		Color(0, 0, 0, 0),                    # VACIO
		Color(0, 0, 0, 0.26),                 # SOMBRA_SUELO
		c.darkened(0.74),                     # BORDE
		# LA JUNTA entre sillares: casi tan oscura como el contorno. Es LO QUE HACE QUE SE LEA COMO
		# LABRADO -- sin ella el coloso es un unico bulto gris con esquinas, y con ella son piezas
		# apiladas. No hace falta dibujarla: sale sola de que cada sillar lleve su propio borde
		# oscuro, y donde dos se tocan quedan dos bordes juntos.
		c.darkened(0.60),                     # JUNTA
		# Las PIERNAS con tono propio, y no es capricho de paleta: con el del torso, la luz del torso
		# (que va 'solo_sobre' ese tono) las REPINTABA y el bajo del bicho se quedaba en una masa sin
		# piernas. Es el fallo que ya tuvieron el trent, el golem y la gargola.
		c.darkened(0.44),                     # PIERNA_OSC (la de detras)
		c.darkened(0.30),                     # PIERNA (la adelantada: hace legible el paso)
		# Los brazos, en sombra: cuelgan por delante del torso y sin un tono aparte se funden con el
		# (entre brazo y cuerpo no hay hueco, y sin hueco 'contornear' no pone linea).
		c.darkened(0.52),                     # BRAZO_OSC (el de detras)
		c.darkened(0.38),                     # BRAZO
		c.darkened(0.22),                     # PIEDRA_OSC (el costado de un sillar, en penumbra)
		c,                                    # PIEDRA
		# La cara de arriba de cada sillar, a la luz. Se aclara hacia un GRIS FRIO y no hacia el
		# blanco: 'lightened' desatura y el granito perderia su azul.
		c.lerp(Color(0.78, 0.82, 0.90), 0.36),                # PIEDRA_CLARA
		# LAS RUNAS: frias y muy claras, casi blancas con un punto de cian. Son su "Muralla" -- lo que
		# lo mantiene de una pieza -- y lo unico encendido de un bicho gris. FRIAS a proposito: el
		# naranja seria el barro cocido del golem, y los dos comparten piso.
		Color(0.62, 0.90, 0.98),              # RUNA
		# Y apagadas en el cadaver: si las runas siguen encendidas, el coloso no esta muerto.
		c.darkened(0.56),                     # APAGADO
	]


# ------------------------------------------------------------
#  GEOMETRIA
# ------------------------------------------------------------

# Una direccion desde el centro de una pieza -> el punto de su superficie en esa direccion, metido
# 'hunde' hacia dentro. Es lo que garantiza que ningun adorno flote.
static func _en_la_pieza(dir: Vector3, hunde: float, centro: Vector3, radio: Vector3) -> Vector3:
	var d: Vector3 = dir.normalized()
	return centro + Vector3(radio.x * d.x, radio.y * d.y, radio.z * d.z) - d * hunde


# Las PIEZAS del coloso para una pose, ya proyectadas a pantalla. El orden ES la profundidad: de lo
# mas bajo y lejano (sombra, brazo y pierna de detras) a lo mas alto y cercano (cabeza, runas, brazo
# de delante).
static func _piezas(dir: int, pose: Dictionary, esc: float) -> Array:
	# NO HAY 'rumbo' NI 'tumba' AQUI, al reves que en el escarabajo, el jabali y la gargola: este no
	# vuelca nunca. Su muerte es hincarse de rodillas (ver _pose_muerte), asi que toda la maquinaria
	# de volcar -- girar el punto en el plano ancho-altura, intercambiar los radios, levantarlo con
	# 'apoyo' para que ruede sobre el suelo -- sobra. Se quito a proposito en vez de dejarla apagada:
	# es la parte mas delicada de un generador y tenerla ahi sin usar solo sirve para confundir.
	var ang: float = DIR_VECS[dir].angle() - DIR_VECS[0].angle()
	var u: float = esc / SpriteLienzo.UNIDADES_POR_CELDA
	var origen: Vector2 = _origen(esc)
	var mece: float = float(pose["mece"])
	var balanceo: float = float(pose["balanceo"])
	var fase_brazos: float = float(pose["brazos"])
	var avance: float = float(pose["avance"])
	var agacha: float = float(pose["agacha"])
	var fase_patas: float = float(pose["patas"])
	# PISA: cuanto tiene levantado el pie del pisoton (0 = en el suelo, 1 = arriba del todo).
	var pisa: float = float(pose["pisa"])
	# LAS DOS RODILLAS, cada una la suya (solo la muerte). 'rodilla' es la del lado izquierdo del
	# cuerpo, que es tambien la que levanta el pisoton.
	var rodilla: float = clampf(float(pose["rodilla"]), 0.0, 1.0)
	var rodilla2: float = clampf(float(pose["rodilla2"]), 0.0, 1.0)
	var cabeza_cae: float = float(pose["cabeza"])
	var desmorona: float = clampf(float(pose["desmorona"]), 0.0, 1.0)

	# Hundirse sobre las piernas. Lo que baja el cuerpo es la rodilla que MAS ha cedido de las dos:
	# con una rota el coloso ya se ha hincado medio cuerpo, y con las dos se queda abajo del todo.
	var alto_f: float = (1.0 - 0.11 * agacha) * (1.0 - 0.44 * maxf(rodilla, rodilla2))
	var ancho_f: float = 1.0 + 0.04 * agacha

	var piezas: Array = []
	# EL AVANCE SE ROTA UNA VEZ Y LO LLEVAN TODAS LAS PIEZAS POR IGUAL. Sumarlo a la Y local antes de
	# rotar solo funcionaria si TODAS giraran, y aqui el torso NO gira: el bicho se partiria en dos
	# mitades yendose a sitios distintos. Es la trampa del meceo del trent.
	var desp := Vector2(0.0, avance).rotated(ang)
	# EL MECEO, IGUAL: en pantalla y despues de rotar, y doblado POR LA ALTURA -- la cabeza va y viene
	# y los pies no se despegan del suelo.
	var mece_v := Vector2(balanceo * 1.9, mece * 1.7)

	# 'ang_forma' GIRA EL DIBUJO DE LA PIEZA, no solo su sitio. Casi todo el coloso es simetrico y no
	# lo necesita (un sillar cuadrado se ve igual girado); lo necesitan las RUNAS, que son lineas
	# TUMBADAS SOBRE EL PECHO y tienen que seguir la perspectiva al dar la vuelta.
	var poner := func(local: Vector3, r: Vector3, tono: int, caja: bool = true,
			solo_sobre: Array = [], gira: bool = true, ang_forma: float = 0.0) -> void:
		var lz: float = local.z * alto_f
		var lx: float = local.x * ancho_f
		var ly: float = local.y
		var enc: float = 1.0

		# DESMORONARSE: cada sillar se suelta y cae a su sitio del monton.
		#
		# Donde acaba cada uno sale de un HASH DE SU PROPIA POSICION, no de un randf ni del orden en
		# que se dibuja. Las dos cosas importan: un randf haria que el monton cambiara en cada
		# fotograma (los cascotes bailarian en vez de caer) y ademas rompe la regla de que el
		# generador es determinista, que es lo que permite comprobar regresiones por huella. Y el
		# orden tampoco vale: cambia con la direccion y con que brazo va delante, asi que un mismo
		# sillar saltaria de sitio entre un fotograma y el siguiente. Con la posicion, cada pieza
		# tiene SU destino y siempre el mismo.
		if desmorona > 0.0:
			var sem: float = sin(local.x * 12.9898 + local.y * 78.233 + local.z * 37.719) * 43758.5453
			var r1: float = fposmod(sem, 1.0) * 2.0 - 1.0
			var r2: float = fposmod(sem * 1.37, 1.0) * 2.0 - 1.0
			var tx: float = r1 * ESCOMBRO_RADIO
			var ty: float = r2 * ESCOMBRO_RADIO * 0.72
			# EL MONTON ES UN MONTON: mas alto en el centro y a ras por los bordes. Repartiendo la
			# altura al azar saldria una alfombra de piedras, no un tumulo.
			var d: float = clampf(sqrt(tx * tx + ty * ty) / ESCOMBRO_RADIO, 0.0, 1.0)
			var tz: float = ESCOMBRO_ALTO * (1.0 - d * d) * (0.45 + 0.55 * fposmod(sem * 2.11, 1.0))
			# La caida acelera y el reparto a lo ancho no: la piedra se abre y luego se desploma.
			lx = lerpf(lx, tx, desmorona)
			ly = lerpf(ly, ty, desmorona)
			lz = lerpf(lz, tz, desmorona * desmorona)
			enc = lerpf(1.0, ESCOMBRO_ENCOGE, desmorona)
		var alto: float = clampf(local.z / CABEZA.z, 0.0, 1.3)
		var p := Vector2(lx, ly)
		var rot: Vector2 = (p.rotated(ang) if gira else p) + desp + mece_v * alto
		var sx: float = origen.x + rot.x * u
		var sy: float = origen.y + (rot.y * SpriteLienzo.COS_CAM - lz * SpriteLienzo.SIN_CAM) * u
		piezas.append({"pos": Vector2(sx, sy),
			"radio": Vector2(r.x * ancho_f * enc * u, r.y * enc * u),
			"persp": SpriteLienzo.persp_de(r.y * enc, r.z * enc * alto_f), "tono": tono,
			"solo_sobre": solo_sobre, "caja": caja, "ang": ang_forma,
			# Una pieza girada puede caer en cualquier eje, asi que su caja envolvente tiene que
			# contar con el radio mayor por los dos lados (ver SpriteLienzo.caja_de_piezas).
			"gira_forma": not is_zero_approx(ang_forma)})

	# UN SILLAR: el bloque en penumbra, la cara de arriba a la luz, y ya esta. Los dos pases son lo
	# que le da volumen, y el reborde oscuro que queda por abajo es LA JUNTA con el sillar de debajo
	# -- no hay que dibujarla aparte, sale de que cada bloque traiga su propia sombra.
	var sillar := func(centro: Vector3, r: Vector3, gira: bool = true) -> void:
		poner.call(centro, r, Tono.PIEDRA_OSC, true, [], gira)
		poner.call(Vector3(centro.x, centro.y, centro.z + r.z * 0.22), r * 0.90,
			Tono.PIEDRA, true, [Tono.PIEDRA_OSC], gira)
		poner.call(Vector3(centro.x, centro.y - r.y * 0.22, centro.z + r.z * 0.52), r * 0.52,
			Tono.PIEDRA_CLARA, true, [Tono.PIEDRA], gira)

	# 1. SOMBRA DE CONTACTO, lo primero (va debajo de todo). Elipse y no bloque: una sombra en el
	#    suelo no tiene aristas.
	poner.call(Vector3(0.0, 0.0, 0.0), Vector3(CADERA_R.x * 1.05, CADERA_R.y * 1.35, 0.0),
		Tono.SOMBRA_SUELO, false, [], false)

	# LAS DOS PIERNAS. Giran con el bicho y dan el paso: una adelante y otra atras, en contrafase.
	# EL PISOTON levanta SOLO UNA (la del lado izquierdo del cuerpo), y por eso 'pisa' entra aparte
	# del ciclo de andar.
	var patas: Array = []
	for lado in [-1.0, 1.0]:
		var swing: float = fase_patas * lado
		var sube: float = maxf(0.0, swing) * PASO_ALZA
		# La pierna del pisoton sube MUCHO mas que un paso: es un pie del tamaño de una lapida
		# levantado a la altura de la rodilla contraria.
		# CINCO Y NO ONCE. Con 11 el pie subia tanto que la cadena de sillares se abria: entre la
		# espinilla y la rodilla habia 4 unidades de diferencia contra 2 de solape, y la pierna del
		# pisoton salia FLOTANDO en trozos. Lo que vende el pisoton no es lo alto que sube el pie, es
		# el cuerpo entero hundiendose al estamparlo ('agacha' llega a 1).
		var alza_pisa: float = pisa * 5.0 if lado < 0.0 else 0.0
		patas.append({"lado": lado, "avanza": swing * PASO_LARGO, "sube": sube + alza_pisa,
			"detras": Vector2(lado * PIERNA_X, 0.0).rotated(ang).y <= 0.0})

	# 2. EL BRAZO DE DETRAS, debajo del cuerpo. Cual es cual sale de su Y YA GIRADA -- una prueba de
	#    profundidad de verdad, no una tabla por direccion que haya que mantener.
	var brazos: Array = []
	for lado in [-1.0, 1.0]:
		var hombro := Vector3(lado * HOMBRO_X, HOMBRO_Y, HOMBRO_Z)
		brazos.append({"lado": lado, "hombro": hombro,
			"delante": Vector2(hombro.x, hombro.y).rotated(ang).y > 0.0})
	for b in brazos:
		if not bool(b["delante"]):
			_brazo(poner, b, fase_brazos, DETRAS_ESC, Tono.BRAZO_OSC)

	# 3. LAS PIERNAS: la de DETRAS primero. La adelantada va en tono mas claro, que es lo que deja ver
	#    de un vistazo cual ha dado el paso.
	for b in patas:
		if bool(b["detras"]):
			_pierna(poner, b, rodilla, rodilla2, Tono.PIERNA_OSC)

	# 4. CADERA, TORSO y HOMBRERAS. El torso y la cadera NO giran: son casi cuadrados en planta y se
	#    ven igual desde los ocho lados.
	for b in patas:
		if not bool(b["detras"]):
			_pierna(poner, b, rodilla, rodilla2, Tono.PIERNA)
	sillar.call(CADERA, CADERA_R, false)
	sillar.call(TORSO, TORSO_R, false)
	sillar.call(Vector3(CUELLO.x, CUELLO.y + cabeza_cae * 1.1, CUELLO.z - cabeza_cae * 0.8),
		CUELLO_R, false)

	# 5. LAS RUNAS del pecho. GIRAN -- de espaldas no se le ven --, pero con la altura COMPENSADA.
	#
	#    El torso no gira y la runa si, y como la altura en pantalla sale de (y - z), al girar cambia
	#    la Y de la runa y la runa SE DESLIZA hacia abajo por un cuerpo que no se ha movido. Como
	#    COS_CAM y SIN_CAM son iguales a 45 grados, basta con corregir la z en lo mismo que ha
	#    cambiado la y para que (y - z) no se mueva. Es exactamente el apaño que necesito el golem
	#    con sus grietas, y lo cazo el usuario mirando el visor.
	var encendido: bool = maxf(rodilla, rodilla2) < 0.75
	var a_runa: Vector3 = _en_la_pieza(RUNA_DIR, RUNA_HUNDE, TORSO, TORSO_ANCLA_R)
	var r_rot: Vector2 = Vector2(a_runa.x, a_runa.y).rotated(ang)
	if r_rot.y > 0.0:
		var base := Vector3(r_rot.x, r_rot.y, a_runa.z + (r_rot.y - a_runa.y))
		# UNA RUNA ES UNA LINEA TUMBADA SOBRE EL PECHO, y tiene que SEGUIR LA PERSPECTIVA. Van a lo
		# ancho del cuerpo, y ese eje -- (1,0,0) del bicho -- al girar y proyectarse deja de ser
		# horizontal en pantalla: de frente sale horizontal, de perfil sale casi VERTICAL (el ancho
		# del cuerpo pasa a ser profundidad, que la camara comprime a 0,707 y sube en pantalla) y en
		# las diagonales sale inclinada. Dibujandolas siempre horizontales, de lado se veian tres
		# rayas planas pegadas en un costado en vez de tres lineas grabadas en el pecho.
		#
		# Se calcula UNA vez: donde cae el eje ancho del cuerpo en pantalla. Su angulo orienta la
		# runa y su longitud la acorta -- de perfil una linea de 2,4 solo mide 1,7 en pantalla.
		var eje_ancho := Vector2(cos(ang), sin(ang) * SpriteLienzo.COS_CAM)
		var ang_runa: float = eje_ancho.angle()
		var esc_runa: float = maxf(0.25, eje_ancho.length())
		for k in RUNA_TRAMOS:
			# Cada tramo mas corto que el anterior: una escalera de lineas, no tres rayas iguales.
			var f: float = float(k) / float(RUNA_TRAMOS - 1)
			poner.call(Vector3(base.x, base.y, base.z - RUNA_BAJA * float(k)),
				Vector3(RUNA_R.x * (1.0 - 0.35 * f) * esc_runa, RUNA_R.y, RUNA_R.z),
				Tono.RUNA if encendido else Tono.APAGADO, true, [], false, ang_runa)

	# 6. LAS HOMBRERAS. GIRAN, y van justo ANTES de la cabeza: girando, de perfil una se va hacia la
	#    camara y la otra al fondo, y la del fondo la TAPA la cabeza, que se pinta despues. Sin girar
	#    quedan clavadas a los lados y de canto el bicho enseña dos hombros donde deberia enseñar uno.
	#    Es la leccion del golem, que costo dos vueltas.
	#
	#    Y AQUI SI SON HOMBRERAS DE VERDAD -- placas puestas encima, con su propia luz --, al reves
	#    que en el golem, donde una pieza con luz propia se leia como algo pegado y habia que
	#    fundirla con el pegote. Este esta LABRADO: que se le noten las piezas es el objetivo.
	#
	#    PERO SOLO LA DE DETRAS VA AQUI. La otra se pinta la ULTIMA, DESPUES del brazo de delante:
	#    una hombrera es MAS GRANDE que el brazo y el brazo SALE DE ELLA, asi que tiene que taparlo
	#    por arriba -- pintada antes, era el brazo el que le pasaba por encima y la placa parecia
	#    estar detras de su propio brazo. Y no se pueden pintar las dos al final porque la de detras
	#    tiene que quedar BAJO LA CABEZA: de perfil se va hacia arriba en pantalla y sin la cabeza
	#    encima salen tres bultos apilados, que es la leccion del golem.
	for b in brazos:
		if not bool(b["delante"]):
			var hd: Vector3 = b["hombro"]
			sillar.call(Vector3(hd.x, hd.y, hd.z - HOMBRO_BAJA_DETRAS), HOMBRO_R)

	# 7. LA CABEZA, pequeña y hundida entre las hombreras, y su VISOR con las dos runas de los ojos.
	#    Al morir se INCLINA HACIA DELANTE Y ABAJO: un coloso arrodillado con la cabeza alta sigue
	#    pareciendo que va a levantarse. Es lo ultimo que cae y lo que remata la estampa.
	var cab := Vector3(CABEZA.x, CABEZA.y + cabeza_cae * 2.2, CABEZA.z - cabeza_cae * 1.6)
	var vis := Vector3(VISOR.x, VISOR.y + cabeza_cae * 2.2, VISOR.z - cabeza_cae * 1.6)
	sillar.call(cab, CABEZA_R)
	# LA CARA ENTERA COMPARTE UNA REGLA DE VISIBILIDAD, visor incluido. El visor es una ranura NEGRA
	# y grande, y dibujandolo siempre se le veia por la NUCA cuando el coloso se aleja -- una barra
	# oscura cruzando la parte de atras de la cabeza, que se lee como una segunda cara. Es el mismo
	# fallo que tuvo el jabali con los colmillos asomando por la grupa: lo de delante va TODO en la
	# misma lista, no solo los ojos.
	var frente: float = Vector2(0.0, 1.0).rotated(ang).y
	if frente > -0.35:
		poner.call(vis, VISOR_R, Tono.JUNTA)
		for lado in [-1.0, 1.0]:
			poner.call(Vector3(lado * OJO_X, vis.y + 0.2, vis.z), OJO_R,
				Tono.RUNA if encendido else Tono.APAGADO, true, [Tono.JUNTA])

	# 8. EL BRAZO DE DELANTE, ya sobre el cuerpo...
	for b in brazos:
		if bool(b["delante"]):
			_brazo(poner, b, fase_brazos, 1.0, Tono.BRAZO)

	# 9. ...y encima del todo SU hombrera, que es de donde cuelga (ver el punto 6).
	for b in brazos:
		if bool(b["delante"]):
			sillar.call(b["hombro"], HOMBRO_R)

	return piezas


# UNA PIERNA: cuatro sillares apilados (pie, espinilla, rodilla, muslo).
#
# 'rota' (0..1) es la muerte: la rodilla revienta y la pierna se DOBLA hacia atras, o sea el coloso
# se hinca. Lo que cae es medio cuerpo de golpe, que es lo unico legible en un bicho de 43 unidades
# -- una caida entera desde ahi se sale de la pantalla y no se entiende.
static func _pierna(poner: Callable, b: Dictionary, rota: float, rota2: float, tono: int) -> void:
	var lado: float = float(b["lado"])
	var av: float = float(b["avanza"])
	var sube: float = float(b["sube"])
	# CADA PIERNA TIENE SU PROPIA ROTURA, y llegan desfasadas: primero cede la del lado izquierdo del
	# cuerpo (la misma que levanta el pisoton) y despues la otra. Rotas a la vez, el coloso parece
	# que se SIENTA; una detras de otra, parece que se PARTE.
	var q: float = rota if lado < 0.0 else rota2
	var x: float = lado * PIERNA_X

	# CADA SILLAR VA EN DOS PASES: el bloque en su tono y una tapa mas clara y subida encima. Esa tapa
	# es LA JUNTA: los sillares se dibujan de arriba abajo, asi que el bloque de abajo cubre la parte
	# baja del de encima pero NO su tapa, y lo que queda entre uno y otro es una franja clara con el
	# borde oscuro del siguiente. Sin los dos pases la pierna sale como UNA COLUMNA LISA y el coloso
	# deja de leerse como piedra apilada -- que es lo unico que lo separa del golem.
	# 'alza_f' es CUANTO LE TOCA SUBIR A CADA SILLAR al levantar el pie, y no es un detalle: subiendo
	# la pierna ENTERA por igual, el muslo se despegaba de la cadera y en el pisoton la pierna salia
	# FLOTANDO, cuatro bloques sueltos al lado del cuerpo. Un pie se levanta doblando la rodilla: el
	# muslo casi no se mueve (esta clavado en la cadera), la rodilla algo, y la espinilla y el pie
	# todo. Y de paso se adelantan un poco, que es lo que hace una rodilla al subir.
	var mete := func(centro: Vector3, r: Vector3, dobla: float, alza_f: float) -> void:
		var p := Vector3(x + centro.x, centro.y + av - dobla * q * 3.4 + sube * alza_f * 0.22,
			centro.z + sube * alza_f - dobla * q * 4.2)
		poner.call(p, r, tono)
		poner.call(Vector3(p.x, p.y - r.y * 0.18, p.z + r.z * 0.44), r * 0.78,
			Tono.PIEDRA_CLARA, true, [tono])

	# El reparto entre sillares vecinos NUNCA puede pasar de su solape, ni al doblar ni al alzar: el
	# salto mas grande de aqui es 0,27, que sobre los 5,0 del pisoton son 1,35 unidades contra 1,4 de
	# solape. Esa es la cuenta que hay que rehacer si se toca cualquiera de los dos numeros.
	mete.call(MUSLO, MUSLO_R, 0.20, 0.24)
	mete.call(RODILLA, RODILLA_R, 0.45, 0.50)
	mete.call(ESPINILLA, ESPINILLA_R, 0.72, 0.76)
	mete.call(PIE, PIE_R, 0.95, 1.00)


# UN BRAZO: cadena de sillares que sale de la hombrera y acaba en un puño-mazo.
#
# LA CADENA SE CONSTRUYE PASO A PASO, cada tramo en la direccion que le toca, y NO como puntos de
# una circunferencia alrededor del hombro: es la unica forma de CURVAR el brazo (el codo) sin que
# cambie la separacion entre piezas y la cadena se descosa. Y el codo hace falta: de perfil los dos
# brazos caen sobre el eje de la pantalla -- lo que los separa a lo ancho pasa a ser PROFUNDIDAD --
# asi que un brazo recto se pinta encima del torso y de las piernas y tapa el bicho entero.
static func _brazo(poner: Callable, b: Dictionary, fase: float, esc_detras: float,
		tono: int) -> void:
	var lado: float = float(b["lado"])
	var h0: Vector3 = b["hombro"]
	# Nace por DEBAJO del centro de la hombrera, o el primer sillar del brazo la tapa entera y el
	# coloso se queda sin la esquina de arriba.
	var hombro := Vector3(h0.x, h0.y, h0.z - BRAZO_BAJA)
	var eje: Vector3 = hombro
	var ultimo: Vector3 = hombro
	var penultimo: Vector3 = hombro
	for k in BRAZO_SEGMENTOS:
		var f: float = float(k) / float(BRAZO_SEGMENTOS - 1)
		if k > 0:
			var a: float = BRAZO_ANG_REPOSO + BRAZO_CODO * pow(f, 1.3)
			var d := Vector3(lado * BRAZO_ABRE, sin(a) * BRAZO_ADELANTA, -cos(a)).normalized()
			eje += d * BRAZO_PASO
		var p := Vector3(eje.x + lado * BRAZO_SEPARA * f, eje.y + fase * f * 2.4, eje.z)
		var r: float = lerpf(BRAZO_R0, BRAZO_R1, f) * esc_detras
		poner.call(p, Vector3(r, r * 0.92, r), tono)
		# La tapa clara de cada sillar del brazo: es lo que marca las juntas (ver _pierna).
		poner.call(Vector3(p.x, p.y - r * 0.18, p.z + r * 0.42), Vector3(r, r * 0.92, r) * 0.76,
			Tono.PIEDRA_CLARA, true, [tono])
		penultimo = ultimo
		ultimo = p

	# EL PUÑO-MAZO, en la MISMA direccion del ultimo tramo y metido varias celdas dentro de el (un
	# solape de una celda no es un solape). La direccion sale del tramo ya dibujado y no del angulo:
	# asi la mano sigue al brazo aunque el balanceo lo haya desviado.
	var d2: Vector3 = ultimo - penultimo
	d2 = d2.normalized() if d2.length() > 0.01 else Vector3(0, 0, -1)
	var mano: Vector3 = ultimo + d2 * (PUNO_R.z * 0.45)
	poner.call(mano, PUNO_R * esc_detras, tono)
	poner.call(Vector3(mano.x, mano.y - PUNO_R.y * 0.18, mano.z + PUNO_R.z * 0.40),
		PUNO_R * esc_detras * 0.72, Tono.PIEDRA_CLARA, true, [tono])


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
		# Casi todas las piezas van con ang = 0 (lo que gira es DONDE se ponen, no su forma) y por ahi
		# las dos primitivas cogen su ruta rapida por filas. Las runas son la excepcion.
		var a: float = float(p["ang"])
		if bool(p["caja"]):
			SpriteLienzo.bloque(plant, lz.x, lz.y, pos.x, pos.y, r.x, r.y, int(p["tono"]),
				a, p["solo_sobre"], float(p["persp"]), CHAFLAN)
		else:
			SpriteLienzo.elipse(plant, lz.x, lz.y, pos.x, pos.y, r.x, r.y, int(p["tono"]),
				a, p["solo_sobre"], float(p["persp"]))

	# CONTORNO al final, sobre la silueta ya completa (ver SpriteLienzo.contornear).
	SpriteLienzo.contornear(plant, SpriteLienzo.caja_de_piezas(piezas, lz.x, lz.y), lz.x, lz.y,
		Tono.BORDE, Tono.VACIO, Tono.SOMBRA_SUELO)
	return plant
