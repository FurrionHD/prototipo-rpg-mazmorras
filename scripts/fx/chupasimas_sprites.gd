# ============================================================
#  chupasimas_sprites.gd  (class_name ChupasimasSprites)
#  El CHUPASIMAS (pisos 7-12) dibujado por codigo, con el motor comun (SpriteLienzo) y la camara de
#  45 grados que comparten todos los bichos. Solo geometria: quien decide que a esta ficha le toca
#  este generador es SpritesEnemigo (por NOMBRE, ver GENERADORES_POR_NOMBRE).
#
#  ES UNA SANGUIJUELA: un tubo blando y anillado, sin una sola pata, gordo por detras y afilandose
#  hacia una BOCA REDONDA -- una ventosa con el anillo de dientes hacia dentro. Y otra ventosa en la
#  cola, que es de donde se agarra.
#
#  VA POR EL PATRON DEL CIEMPIES (la CADENA): no tiene centro, ES una fila de anillos, y todo cuelga
#  de donde caiga su anillo en cada fotograma. De ahi la funcion '_traza'. Y por eso el orden de
#  pintado tampoco puede ir cableado: un cuerpo que se arquea se cruza CONSIGO MISMO, asi que los
#  anillos se ordenan por su altura EN PANTALLA en cada frame.
#
#  HASTA HOY SE DIBUJABA CON EL GENERADOR DEL CIEMPIES, o sea que una sanguijuela salia con veinte
#  patas amarillas. Y ese es justo el riesgo de este bicho: comparte con el ciempies el esqueleto de
#  cadena, asi que hay que separarlos A PROPOSITO. Se separan por cinco sitios, y hacen falta los
#  cinco:
#
#    CIEMPIES                          CHUPASIMAS
#    onda lateral, serpentea           BUCLE DE ORUGA: se arquea y se encoge
#    diez patas amarillas              ninguna
#    gordo delante, afila atras        gordo en el TERCIO TRASERO, afila hacia la boca
#    placas separadas en el lomo       anillacion fina, muchos aros, todo alrededor
#    antenas, forcipulas y ojillos     una VENTOSA delante y otra detras; ni ojos ni antenas
#
#  Y ADEMAS VA MOJADA -- lo dice su ficha ("se deja caer del techo mojada") y lo dice su efecto, que
#  aplica Mojado --, asi que lleva un brillo especular a lo largo del lomo que no tiene ningun otro
#  bicho del juego. Es lo que se ve primero de lejos.
#
#  EL BUCLE DE ORUGA ES LA MITAD DEL BICHO. Una sanguijuela no repta: junta los dos extremos, se
#  encorva hacia arriba y se estira. Ese gesto -- arquearse y acortarse a la vez -- es lo unico que
#  no se puede confundir con un ciempies ni con una serpiente, y es lo que hace 'arco' aqui.
# ============================================================

extends RefCounted
class_name ChupasimasSprites

const FRAMES := 8

# --- El chupasimas mirando al SUR, en unidades de MUNDO (origen = donde toca el suelo, +Y hacia la
# boca, +Z hacia arriba). "Del largo de un brazo", dice su ficha. ---
const LARGO_MUNDO := 42.0

# LA CADENA. El anillo 0 es la CABEZA (la boca) y el ultimo es la cola.
#
# EL PASO ES CORTO CONTRA EL GROSOR (2,6 contra 4,2 de radio en la panza), y eso es lo que hace que
# el cuerpo salga como un TUBO LISO en vez de un collar de cuentas. La segmentacion no la hacen los
# huecos entre anillos -- la hace la anillacion, que se pinta encima.
#
# Y EL PASO LO MANDA LA ANILLACION, no el largo que quieras. Para que se vea un aro Y el hueco entre
# dos, a escala 1,6 (donde una celda son 0,72 unidades de mundo) hacen falta lo menos dos celdas de
# aro y una y pico de hueco: eso son 2,6 de paso. Con 1,75 el aro media medio pixel y los trece
# salian como un tinte continuo -- el cuerpo era un palo liso.
const SEGMENTOS := 13
const PASO := 2.60
const CUERPO_Y0 := 16.0             # donde cae el anillo 0 (la boca)
const CUERPO_Z := 1.9               # va PEGADO al suelo: es un bicho blando y aplastado

# EL PERFIL DEL CUERPO, que es lo contrario del ciempies: aquel es gordo de cabeza y se afila hacia
# la cola; una sanguijuela es lo mas gordo en el TERCIO TRASERO -- ahi es donde le cabe la sangre --
# y se estrecha hacia la boca. Puestos al reves los dos bichos se leen igual de lejos.
# Y GORDA DE VERDAD, que fue el primer fallo: con 2,70 de panza el bicho medía 8,6 pixeles de ancho
# contra 28 de alto y salia como un PALO. Ojo con la trampa de la camara, que ya mordio en el
# miconido: el largo va por la Y y la Y se comprime a cos(45), asi que 25 unidades de mundo son 18
# pixeles; el ANCHO va por la X y no se comprime NADA. O sea que a igualdad de numeros el bicho
# siempre sale mas estrecho de lo que parece en las constantes.
const CUELLO_R := Vector3(2.00, 1.70, 1.40)     # el anillo 0, estrecho
const PANZA_R := Vector3(4.20, 3.40, 2.90)      # lo mas gordo
const COLA_R := Vector3(2.60, 2.20, 1.90)       # el ultimo, algo mas que el cuello
# DONDE cae la panza a lo largo del bicho (0 = boca, 1 = cola). Dos tercios hacia atras.
const PANZA_EN := 0.66

# LA ANILLACION: los aros finos que recorren el cuerpo. Van UNO POR ANILLO y algo mas oscuros, y
# rodean el tubo entero en vez de ser una placa en el lomo como el ciempies.
#
# LA CUENTA VA EN CELDAS, NO EN UNIDADES, y ese fue el fallo del primer intento. A escala 1,6 una
# celda son 0,72 unidades de mundo, asi que el aro de 0,34 que puse medía MEDIO PIXEL: no es que se
# viera poco, es que no existia, y el cuerpo salia como un palo liso. Con 0,70 el aro ocupa dos
# celdas y el hueco contra el paso de 2,6 son otras dos. HAY QUE REHACER ESTA CUENTA cada vez que se
# toque PASO o la escala del bicho.
const ARO_LARGO := 0.55
const ARO_ANCHO := 1.05             # respecto del radio del anillo: asoma un pelin

# EL BRILLO DE MOJADO: la banda clara del lomo. Va ALTA y ESTRECHA -- es un reflejo especular, no una
# franja de color --, y solo sobre el cuerpo, para que no se derrame por el contorno.
# ESTRECHO: un reflejo especular es una LINEA. Lo que tiene que verse es el granate, con un filo
# claro encima -- a la mitad del grosor el bicho se lee como una oruga a rayas.
const BRILLO_ANCHO := 0.30          # respecto del radio del anillo
const BRILLO_SUBE := 0.62           # respecto del semialto del anillo

# LA VENTOSA DE LA BOCA: el anillo de dientes. En el sprite se lee como un DISCO CLARO con el centro
# oscuro; los dientes de uno en uno son cosa del golpe (ver el estilo VENTOSA en CapaHechizos), donde
# hay sitio de sobra para dibujarlos.
#
# Y NO ES POR PEREZA: a escala 1,6 una celda son 0,72 unidades de mundo, asi que un diente de radio
# 0,5 mide UNA celda -- y 'contornear' convierte en borde toda celda que toque el vacio, o sea que
# un diente de una celda es contorno entero y no se ve. Es la misma leccion que las manos del
# miconido. Lo que cabe aqui es la ventosa; los dientes caben en el golpe.
const BOCA_R := Vector3(2.90, 1.10, 2.90)       # aplastada en profundidad: mira hacia delante
const BOCA_ADELANTA := 1.50         # cuanto asoma por delante del anillo 0
const GARGANTA_ESC := 0.52          # el agujero oscuro del centro
# CUANTO SE ABRE al atacar: la ventosa crece y la garganta se traga el centro.
const BOCA_ABRE := 0.55

# LA VENTOSA DE LA COLA: con la que se ancla al suelo para arquearse. Mas plana y pegada al suelo.
const ANCLA_R := Vector3(2.80, 2.20, 0.60)

# EL BUCLE DE ORUGA. 'arco' va de 0 (estirada) a 1 (encorvada del todo): el cuerpo se levanta por el
# medio y a la vez se ACORTA, que es como se mueve el bicho de verdad -- junta los extremos, hace el
# puente y se estira hacia delante.
const ARCO_ALTO := 6.2              # cuanto sube el punto mas alto del puente
const ARCO_ENCOGE := 0.30           # cuanto se acorta la cadena en lo mas alto del bucle

# ALZARSE para morder: levanta la mitad delantera, como una sanguijuela que busca donde clavarse.
const ALZA_ANILLOS := 5
const ALZA_ALTO := 6.0

# HINCHARSE al drenar: el cuerpo se llena "a tirones". Multiplica el radio de los anillos, y MAS
# atras que delante -- la sangre le va a la panza, no al cuello.
const HINCHA_MAX := 0.55

# MORIRSE: se queda LAXA. No se enrosca en espiral como el ciempies (eso es de bicho con esqueleto de
# quitina) ni se hace un ovillo como la araña: un gusano muerto pierde la tension y se queda tirado,
# aplastandose contra el suelo y desmadejado. Tres bichos de cadena, tres muertes distintas.
const LAXO_APLASTA := 0.52          # cuanto se achata contra el suelo
const LAXO_SERPEA := 3.4            # y cuanto se desmadeja de lado

const LUNGE_DIST := 7.0
# ENCAJA MUCHO: no pesa nada y es blanda. Casi tanto como la araña.
const ENCAJE_RETRO := 0.52

# Lienzo CUADRADO y holgado: gira, y girado en diagonal su largo va por la diagonal del cuadro.
# Ademas el bucle la levanta y la embestida la desplaza. Ajustado contra los avisos del horno.
const LIENZO_FACTOR := 1.75

# TONOS propios (el motor no sabe que es cada uno; solo mapea indice -> color, ver _colores).
enum Tono { VACIO, SOMBRA_SUELO, BORDE, SOMBRA, BASE, ARO, BRILLO, VENTOSA, GARGANTA, DIENTE }

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
	return "chupasimas_%s_%.2f" % [col.to_html(false), esc]


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(escala: float = 1.0) -> int:
	return _celdas(escala)


static func dimensiona_por_escala() -> bool:
	return true


# El CUERPO en planta (ancho, largo) para la colision. Es un bicho ESTRECHO Y LARGO, como la rata: si
# se le diera una caja cuadrada chocaria con las paredes por un cuerpo que no tiene.
static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return Vector2(PANZA_R.x * 2.0, float(SEGMENTOS - 1) * PASO + PANZA_R.y * 2.0) * escala


static func _celdas(escala: float) -> int:
	var lado: int = int(ceil(LARGO_MUNDO * escala * LIENZO_FACTOR / SpriteLienzo.UNIDADES_POR_CELDA))
	return lado + (lado % 2)      # par, para que el centro caiga limpio


static func generar(color: Color = Color(0.42, 0.24, 0.30), escala: float = 1.0) -> SpriteFrames:
	# cuantizar_hsv y no cuantizar a secas: el granate del chupasimas es oscuro y apagado, y redondear
	# canal a canal le cambia el TONO -- dos canales parecidos caen en el mismo escalon y sale un gris.
	var col: Color = SpriteLienzo.cuantizar_hsv(color, COLOR_PASOS)
	var esc: float = snappedf(escala, 0.05)      # se cuantiza tambien, o el cache no acierta
	var clave: String = _clave(col, esc)
	if _cache.has(clave):
		return _cache[clave]
	var anims: Array = []
	_montar_idle(anims, esc)
	_montar_walk(anims, esc)
	_montar_embestida(anims, esc)
	_montar_adherirse(anims, esc)
	_montar_drenaje(anims, esc)
	_montar_encaje(anims, esc)
	_montar_muerte(anims, esc)
	_montar_cadaver(anims, esc)
	var lado: int = _celdas(esc)
	var sf: SpriteFrames = SpriteLienzo.montar_frames(
		anims, SpriteLienzo.paleta(_colores(col)), lado, lado)
	_cache[clave] = sf
	return sf


# La pose en reposo, con todo a cero. Existe para que cada animacion escriba SOLO lo que cambia: con
# ocho claves, repetirlas enteras en ocho sitios garantiza que un dia se olvide una.
static func _pose(campos: Dictionary = {}) -> Dictionary:
	var p := {"avance": 0.0, "arco": 0.0, "alza": 0.0, "boca": 0.0, "hincha": 0.0,
		"laxo": 0.0, "serpea": 0.0, "aplasta": 0.0}
	for k in campos:
		p[k] = campos[k]
	return p


# Quieta: apenas respira. Un bucle muy corto -- se encoge y se estira un pelin, sin llegar a hacer el
# puente -- y la boca abriendose despacio. A 4 fps.
static func _montar_idle(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return _pose({"arco": 0.10 * (1.0 - cos(TAU * t)),
			"boca": 0.18 * (1.0 - cos(TAU * t + 1.2))})
	_montar_animacion(anims, esc, "idle", true, 4.0, pose, false)


# ANDANDO: EL BUCLE DE ORUGA, que es la firma del bicho. Se arquea por el medio y se acorta a la vez
# -- junta los extremos, hace el puente y se estira hacia delante --, y eso no se parece en nada a la
# onda lateral del ciempies.
#
# A 7 fps: no es lenta (tiene Agilidad 25 y velocidad 4,4), pero tampoco corre.
static func _montar_walk(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		# Medio ciclo arqueandose y medio estirandose: 0 en los extremos, 1 en el medio.
		return _pose({"arco": 0.5 - 0.5 * cos(TAU * t)})
	_montar_animacion(anims, esc, "walk", true, 7.0, pose, false)


# EMBESTIDA: se alza buscando donde clavarse, ABRE LA BOCA y se echa encima. Lo que llega delante es
# la ventosa, no el cuerpo -- por eso la boca se abre ANTES del avance y no a la vez.
static func _montar_embestida(anims: Array, esc: float) -> void:
	var alza_keys := [[0.0, 0.0], [0.32, 1.0], [0.50, 0.92], [0.72, 0.16], [1.0, 0.0]]
	var boca_keys := [[0.0, 0.0], [0.32, 0.85], [0.50, 1.0], [0.72, 0.45], [1.0, 0.10]]
	var avance_keys := [[0.0, 0.0], [0.32, -1.1], [0.50, 0.6], [0.72, 6.6], [0.86, 7.0], [1.0, 4.8]]
	var arco_keys := [[0.0, 0.0], [0.32, 0.55], [0.50, 0.40], [0.72, 0.0], [1.0, 0.10]]
	var pose := func(t: float) -> Dictionary:
		return _pose({"avance": SpriteLienzo.tramos(t, avance_keys) * (LUNGE_DIST / 7.0),
			"alza": SpriteLienzo.tramos(t, alza_keys),
			"arco": SpriteLienzo.tramos(t, arco_keys),
			"boca": SpriteLienzo.tramos(t, boca_keys)})
	_montar_animacion(anims, esc, "embestida", false, 10.0, pose, true)


# ADHERIRSE (fx_anim = "adherirse"). "Se pega y no la despegas. La boca es un anillo de dientes hacia
# dentro: no muerde, se enrosca en la carne y empieza a tirar."
#
# ES LO CONTRARIO DE LA EMBESTIDA: aquella es un lance y esta es un AGARRE. Se alza, planta la
# ventosa, y en vez de retirarse SE QUEDA -- el ultimo fotograma la deja pegada y encogida, tirando.
# Esa permanencia es toda la habilidad.
#
# UNA SOLA DIRECCION: solo se ve en combate, y ahi se le mira de frente (el combate degrada solo a
# "adherirse_0", ver combat.gd::_on_gesto_iniciado).
static func _montar_adherirse(anims: Array, esc: float) -> void:
	var boca_keys := [[0.0, 0.0], [0.143, 0.75], [0.286, 1.0], [0.429, 0.55], [0.571, 0.30],
		[0.714, 0.22], [1.0, 0.20]]
	var alza_keys := [[0.0, 0.0], [0.143, 0.85], [0.286, 1.0], [0.429, 0.62], [0.571, 0.45],
		[1.0, 0.40]]
	# Y AL CLAVARSE SE ENCOGE Y AHI SE QUEDA: el arco alto del final es el bicho tirando de lo que ha
	# agarrado. Volviendo a cero se leeria como que se ha soltado.
	var arco_keys := [[0.0, 0.0], [0.143, 0.30], [0.286, 0.15], [0.429, 0.62], [0.571, 0.78],
		[0.714, 0.70], [1.0, 0.74]]
	var pose := func(t: float) -> Dictionary:
		return _pose({"boca": SpriteLienzo.tramos(t, boca_keys),
			"alza": SpriteLienzo.tramos(t, alza_keys),
			"arco": SpriteLienzo.tramos(t, arco_keys)})
	_montar_animacion(anims, esc, "adherirse", false, 11.0, pose, true, 1, FRAMES)


# DRENAJE (fx_anim = "drenaje"). "Bombea. Se le ve el cuerpo llenarse a tirones mientras a ti se te
# va." Son tres o cuatro golpes seguidos, y el dibujo tiene que contar eso: el bicho ya esta pegado y
# lo unico que se mueve es SU PROPIO CUERPO llenandose.
#
# EL HINCHADO VA A TIRONES, EN ESCALONES, y ahi esta toda la animacion: 0,25 -> 0,45 -> 0,70 -> 1,0
# con una caidita entre uno y otro. Interpolado suave se leeria como un globo inflandose; a saltos se
# lee como una bomba. Es el mismo truco que el reventon del sombrero del miconido.
static func _montar_drenaje(anims: Array, esc: float) -> void:
	var hincha_keys := [[0.0, 0.0], [0.143, 0.28], [0.286, 0.22], [0.429, 0.52], [0.571, 0.46],
		[0.714, 0.78], [0.857, 0.72], [1.0, 1.0]]
	# Cada tiron le da un apreton al arco: es el bicho haciendo fuerza para chupar.
	var arco_keys := [[0.0, 0.55], [0.143, 0.72], [0.286, 0.58], [0.429, 0.76], [0.571, 0.60],
		[0.714, 0.80], [0.857, 0.62], [1.0, 0.82]]
	var pose := func(t: float) -> Dictionary:
		return _pose({"hincha": SpriteLienzo.tramos(t, hincha_keys),
			"arco": SpriteLienzo.tramos(t, arco_keys),
			"alza": 0.40, "boca": 0.20})   # sigue pegada todo el rato
	_montar_animacion(anims, esc, "drenaje", false, 11.0, pose, true, 1, FRAMES)


# ENCAJAR UN GOLPE. Cuatro fotogramas en UNA sola direccion (en combate se le ve siempre de frente) y
# EMPEZANDO YA GOLPEADA: el frame 0 es el impacto, no la pose de reposo.
#
# SE SACUDE COMO UN TRAPO. No aguanta como el miconido (Resistencia 55) ni sale despedida entera como
# la araña: es blanda, asi que lo que le pasa es que se DESMADEJA de lado -- 'serpea' -- y vuelve. Un
# cuerpo sin esqueleto no retrocede de una pieza.
static func _montar_encaje(anims: Array, esc: float) -> void:
	var retro_keys := [[0.0, 1.0], [0.34, 0.40], [0.67, 0.10], [1.0, 0.0]]
	var serpea_keys := [[0.0, 1.0], [0.34, -0.55], [0.67, 0.20], [1.0, 0.0]]
	var arco_keys := [[0.0, 0.42], [0.34, 0.14], [0.67, 0.04], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		return _pose({"avance": -SpriteLienzo.tramos(t, retro_keys) * (LUNGE_DIST * ENCAJE_RETRO),
			"serpea": SpriteLienzo.tramos(t, serpea_keys),
			"arco": SpriteLienzo.tramos(t, arco_keys)})
	# LOS BICHOS ENCAJAN A 18 fps: es la duracion que espera CombatFX.T_ENCAJE, y cuadrando las dos el
	# sprite va a su velocidad natural en vez de estirado por _pose_ajustar.
	_montar_animacion(anims, esc, "encaje", false, 18.0, pose, true, 1, 4)


# MORIRSE: SE QUEDA LAXA. Ocho fotogramas en UNA sola direccion -- la muerte solo se ve en la pantalla
# de combate, y ahi al bicho se le mira siempre de frente. Para el mapa esta 'cadaver'.
#
# NI ESPIRAL (eso es el ciempies) NI OVILLO (eso es la araña). Un gusano muerto no se recoge: pierde
# la tension y se queda TIRADO -- se aplasta contra el suelo y se desmadeja de lado, con la boca
# abierta y floja. Tres bichos de cadena en los mismos pisos, tres muertes que no se confunden.
static func _pose_muerte(t: float) -> Dictionary:
	# UN ULTIMO ESPASMO ANTES DE AFLOJARSE: se arquea de golpe (el 0,16) y ahi se le acaba. Sin el, la
	# muerte sale como una interpolacion suave y parece que se tumba a proposito.
	var arco_keys := [[0.0, 0.0], [0.16, 0.85], [0.34, 0.45], [0.56, 0.12], [1.0, 0.0]]
	# Y se desmadeja de lado, cada vez mas.
	var serpea_keys := [[0.0, 0.0], [0.16, -0.35], [0.34, 0.55], [0.56, 0.85], [0.78, 1.0], [1.0, 1.0]]
	# Aplastandose contra el suelo: es lo que la deja como un trapo.
	var aplasta_keys := [[0.0, 0.0], [0.16, 0.0], [0.34, 0.35], [0.56, 0.72], [0.78, 0.94], [1.0, 1.0]]
	# La boca se queda abierta y floja, que es lo que dice que ya no agarra nada.
	var boca_keys := [[0.0, 0.20], [0.16, 0.90], [0.34, 0.70], [1.0, 0.55]]
	return _pose({"arco": SpriteLienzo.tramos(t, arco_keys),
		"serpea": SpriteLienzo.tramos(t, serpea_keys),
		"aplasta": SpriteLienzo.tramos(t, aplasta_keys),
		"boca": SpriteLienzo.tramos(t, boca_keys),
		"laxo": SpriteLienzo.tramos(t, aplasta_keys)})


static func _montar_muerte(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return _pose_muerte(t)
	_montar_animacion(anims, esc, "muerte", false, 10.0, pose, true, 1, 8)


# EL CADAVER DEL MAPA: UN fotograma por CADA UNA de las ocho direcciones, que es justo al reves que
# 'muerte' (ocho fotogramas en una sola). En el mapa no se ve morir a nadie -- se entra a la sala y la
# sanguijuela ya esta tirada --, pero pudo caer mirando a cualquier lado.
#
# Es EXACTAMENTE la pose final de la muerte, sacada de la MISMA funcion: reescribir los numeros aqui
# garantiza que el dia que se retoque la muerte el cadaver se quede como estaba.
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
			# La GEOMETRIA se cachea por (animacion, frame, direccion, escala) y NO por color: otro
			# chupasimas de otro tono reusa estas plantillas y solo repinta.
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
		Color(0, 0, 0, 0.24),                     # SOMBRA_SUELO
		c.darkened(0.72),                         # BORDE
		# ABIERTOS DE VERDAD: el granate de la ficha es oscuro y los escalones de tono que en un bicho
		# claro se ven de sobra aqui caen todos en el mismo negro sucio.
		c.darkened(0.38),                         # SOMBRA (el costado, en penumbra)
		c,                                        # BASE
		# LOS AROS, mas oscuros que el cuerpo: son los surcos entre anillo y anillo, o sea sombra. Mas
		# claros se leerian como rayas pintadas encima de un tubo liso.
		c.darkened(0.62),                         # ARO
		# EL BRILLO DE MOJADO. Va hacia un ROSA FRIO y casi blanco, no hacia el blanco puro:
		# 'lightened' desatura, y sobre un granate ya oscuro el resultado es un gris sucio que se lee
		# como polvo. Un reflejo en piel humeda conserva algo del tono de debajo.
		# FLOJO. El brillo se pinta en la cara DE ARRIBA del tubo, y con la camara a 45 grados la cara de
		# arriba es casi todo lo que se ve de un bicho tan bajo: a 0,58 de mezcla el chupasimas salia
		# BLANCO con rayas -- una oruga --, y el granate de su ficha no aparecia por ningun lado. Un
		# reflejo en piel mojada aclara, no repinta.
		c.lerp(Color(1.00, 0.90, 0.92), 0.42),    # BRILLO
		# LA VENTOSA: el labio carnoso de la boca, mas CLARO que el cuerpo (es carne sin pigmento) y
		# tirando a rosa. Tiene que cantar contra el granate o la boca no se ve, y la boca es lo que
		# dice hacia donde mira este bicho -- no tiene ojos.
		c.lerp(Color(0.94, 0.66, 0.66), 0.62),    # VENTOSA
		# LA GARGANTA: el agujero. Casi negro, y MAS oscuro que el contorno a proposito -- es un
		# hueco, y un hueco tiene que leerse como que no hay nada ahi.
		c.darkened(0.86),                         # GARGANTA
		Color(0.94, 0.92, 0.84),                  # DIENTE (hueso, para el anillo de dientes)
	]


# ------------------------------------------------------------
#  GEOMETRIA
# ------------------------------------------------------------

# EL RADIO DEL ANILLO 'f' (0 = boca, 1 = cola). Gordo en el tercio trasero y afilandose hacia la
# boca, que es el perfil de una sanguijuela y el CONTRARIO del ciempies.
static func _radio(f: float, hincha: float) -> Vector3:
	var r: Vector3
	if f <= PANZA_EN:
		r = CUELLO_R.lerp(PANZA_R, smoothstep(0.0, 1.0, f / PANZA_EN))
	else:
		r = PANZA_R.lerp(COLA_R, smoothstep(0.0, 1.0, (f - PANZA_EN) / (1.0 - PANZA_EN)))
	if hincha > 0.0:
		# LA SANGRE LE VA A LA PANZA, NO AL CUELLO: el hinchado crece hacia atras. Repartido por igual
		# el bicho se infla como un globo y se pierde la forma de sanguijuela.
		r *= 1.0 + HINCHA_MAX * hincha * smoothstep(0.0, 1.0, f * 1.3)
	return r


# DONDE ESTA EL ANILLO 'i': la traza de la cadena, en 3D (x lateral, y a lo largo, z de altura).
#
# EL BUCLE DE ORUGA VIVE AQUI. 'arco' levanta el cuerpo por el medio (una campana de seno, cero en
# los dos extremos: los dos son ventosas y las dos se quedan en el suelo) y a la vez ACORTA la
# cadena. Las dos cosas juntas son el gesto; solo levantando sale un puente rigido y solo acortando
# sale un acordeon.
static func _traza(i: int, pose: Dictionary) -> Vector3:
	var n: float = float(SEGMENTOS - 1)
	var f: float = float(i) / n
	var arco: float = float(pose["arco"])
	var serpea: float = float(pose["serpea"])
	var alza: float = float(pose["alza"])

	var largo: float = PASO * (1.0 - ARCO_ENCOGE * arco)
	# LA COLA SE QUEDA CLAVADA Y LA BOCA SE ADELANTA. Se mide desde la COLA y no desde la cabeza: la
	# ventosa trasera es la que ancla, asi que al encogerse el bicho lo que se mueve es la boca. Al
	# reves -- midiendo desde la cabeza -- se veria a la sanguijuela tirando de su propia cola, que es
	# justo lo contrario de lo que hace.
	var cola_y: float = CUERPO_Y0 - n * PASO
	var y: float = cola_y + (n - float(i)) * largo
	# EL PUENTE: seno con los dos extremos en cero. Y elevado a 1,4 para que la campana sea algo mas
	# picuda que un seno limpio -- una sanguijuela hace un pico, no un arcoiris.
	var campana: float = pow(sin(PI * (1.0 - f)), 1.4)
	var z: float = CUERPO_Z + ARCO_ALTO * arco * campana
	# ALZARSE es otra cosa que el arco: aquello es todo el cuerpo haciendo el puente y esto es la
	# mitad DELANTERA levantandose para buscar donde clavarse, con la cola en el suelo.
	if alza > 0.0 and i < ALZA_ANILLOS:
		var g: float = 1.0 - float(i) / float(ALZA_ANILLOS)
		var sube: float = alza * ALZA_ALTO * g * g
		z += sube
		y -= sube * 0.40      # lo que sube deja de avanzar: el cuerpo no se estira
	# DESMADEJARSE de lado (el encaje y la muerte). Crece hacia la cola, que es la parte que mas
	# latiguea en un cuerpo sin esqueleto.
	var x: float = serpea * LAXO_SERPEA * sin(PI * f * 1.6) * f
	return Vector3(x, y, z)


# Las PIEZAS del chupasimas para una pose, ya proyectadas a pantalla.
static func _piezas(dir: int, pose: Dictionary, esc: float) -> Array:
	var ang: float = DIR_VECS[dir].angle() - DIR_VECS[0].angle()
	var u: float = esc / SpriteLienzo.UNIDADES_POR_CELDA
	var centro: float = float(_celdas(esc)) * 0.5
	var avance: float = float(pose["avance"])
	var boca: float = float(pose["boca"])
	var hincha: float = float(pose["hincha"])
	var aplasta: float = float(pose["aplasta"])

	# EL AVANCE SE ROTA UNA VEZ Y LO LLEVAN TODAS LAS PIEZAS POR IGUAL (la trampa del meceo del
	# trent): sumarlo a la Y local antes de rotar solo funciona si TODAS las piezas giran.
	var desp := Vector2(0.0, avance).rotated(ang)

	# DOS CUBOS, Y SOLO UNO SE ORDENA. Es el mismo reparto del ciempies y por el mismo motivo: si cada
	# anillo llevara su sombra dentro de su grupo, la sombra del anillo 9 se pintaria ENCIMA del
	# cuerpo del 3 y el lomo saldria manchado.
	#   - suelo: TODAS las sombras. Van debajo de todo y no se ordenan.
	#   - grupos: los ANILLOS con sus aros y sus ventosas. ESTOS SI se ordenan, porque un cuerpo que
	#     hace el puente se cruza consigo mismo: en lo alto del bucle el anillo 6 esta por delante
	#     del 3, y estirada ya no.
	var suelo: Array = []
	var grupos: Array = []
	for _i in SEGMENTOS:
		grupos.append({"sy": 0.0, "piezas": []})

	# 'persp_ov' SOBREESCRIBE LA PERSPECTIVA DE LA PIEZA, y hace falta por una trampa del motor que
	# costo una vuelta entera:
	#
	# SpriteLienzo.elipse aplasta con UN solo numero, y ese numero solo es correcto si la pieza es
	# REDONDA EN PLANTA (rx ~ ry). Mirando de frente usa 'ry * persp' como alto en pantalla y mirando
	# de lado usa 'rx * persp' -- o sea que si rx y ry son muy distintos, las dos vistas no pueden
	# salir bien con el mismo valor.
	#
	# El ARO es justo ese caso extremo: 4,4 de ancho por 0,55 de fondo. Su persp_de(0,55; 3,05) sale
	# 3,98 -- ESTIRA en vez de aplastar --, asi que de perfil cada aro se dibujaba 24 celdas de alto en
	# lugar de 3 y el bicho salia con barrotes. De frente, en cambio, no se veia ninguno.
	#
	# La solucion es que el aro se proyecte como el ANILLO al que pertenece, que si es redondo en
	# planta. La regla general: una pieza muy achatada en un eje tiene que heredar la perspectiva de
	# la pieza que la sostiene, no calcular la suya.
	var poner := func(dest: Array, local: Vector3, r: Vector3, tono: int,
			solo_sobre: Array = [], en_suelo: bool = false, persp_ov: float = -1.0) -> void:
		var rot: Vector2 = Vector2(local.x, local.y).rotated(ang) + desp
		var z: float = 0.0 if en_suelo else local.z
		var sx: float = centro + rot.x * u
		var sy: float = centro + (rot.y * SpriteLienzo.COS_CAM - z * SpriteLienzo.SIN_CAM) * u
		# El aplastado va DESPUES de girar: lo hace SpriteLienzo.elipse con 'persp', y el valor lo da
		# persp_de a partir de los semiejes.
		dest.append({"pos": Vector2(sx, sy), "radio": Vector2(r.x * u, r.y * u),
			"gira_forma": true, "tono": tono, "ang": ang,
			"persp": 1.0 if en_suelo else (persp_ov if persp_ov > 0.0
				else SpriteLienzo.persp_de(r.y, r.z)),
			"solo_sobre": solo_sobre})

	for i in SEGMENTOS:
		var f: float = float(i) / float(SEGMENTOS - 1)
		var p: Vector3 = _traza(i, pose)
		var r: Vector3 = _radio(f, hincha)
		# APLASTARSE contra el suelo al morir: se achata y se ensancha, que es lo que hace un cuerpo
		# blando sin tension. Bajando sin ensanchar saldria el mismo bicho mas pequeño.
		if aplasta > 0.0:
			r = Vector3(r.x * (1.0 + 0.45 * aplasta), r.y, r.z * (1.0 - LAXO_APLASTA * aplasta))
			p.z = CUERPO_Z + (p.z - CUERPO_Z) * (1.0 - 0.85 * aplasta)
		var grupo: Array = grupos[i]["piezas"]
		# La altura EN PANTALLA de este anillo: es con lo que se ordena la profundidad al final.
		var rot_i: Vector2 = Vector2(p.x, p.y).rotated(ang) + desp
		grupos[i]["sy"] = rot_i.y * SpriteLienzo.COS_CAM - p.z * SpriteLienzo.SIN_CAM

		# SOMBRA DE CONTACTO de este anillo, a altura cero. Va por anillo y no una sola para todo el
		# bicho: un cuerpo que hace el puente no proyecta un ovalo, y la separacion entre el bicho y
		# su sombra es justo lo que se lee como que esta en el aire.
		poner.call(suelo, Vector3(p.x, p.y, 0.0), Vector3(r.x * 0.88, r.y * 0.95, 0.0),
			Tono.SOMBRA_SUELO, [], true)

		# EL ANILLO, entero en penumbra...
		poner.call(grupo, p, r, Tono.SOMBRA)
		# ...y encima el mismo, MAS PEQUEÑO Y MAS SUBIDO, a pleno tono. Lo que queda por debajo es el
		# costado en sombra, y la frontera sale curvada sola.
		#
		# SUBIDO DE VERDAD (0,42 y 0,78, no 0,22 y 0,90). Con la luz apenas desplazada la sombra se
		# quedaba en un filo del 10% y el tubo salia como una MANCHA PLANA sin volumen: el bicho parecia
		# recortado en cartulina. En un cuerpo cilindrico la sombra tiene que comerse el tercio de
		# abajo, o no hay cilindro.
		poner.call(grupo, Vector3(p.x, p.y, p.z + r.z * 0.42), r * 0.78, Tono.BASE, [Tono.SOMBRA])
		# EL BRILLO DE MOJADO: la banda clara del lomo, alta y estrecha. Solo sobre el cuerpo.
		# Hereda la perspectiva del anillo por lo mismo que el aro: es una tira estrecha.
		poner.call(grupo, Vector3(p.x, p.y, p.z + r.z * BRILLO_SUBE),
			Vector3(r.x * BRILLO_ANCHO, r.y * 0.80, r.z * 0.34), Tono.BRILLO, [Tono.BASE],
			false, SpriteLienzo.persp_de(r.y, r.z))
		# EL ARO: el surco entre este anillo y el siguiente. Va MAS ANCHO que el anillo (asoma un
		# pelin) y muy corto, que es lo que deja el hueco claro entre aro y aro.
		#
		# Y CON LA PERSPECTIVA DEL ANILLO, no la suya (ver el comentario de 'poner'): es una rodaja
		# fina, o sea el caso en que la cuenta del motor falla.
		if i > 0 and i < SEGMENTOS - 1:
			poner.call(grupo, Vector3(p.x, p.y - r.y * 0.72, p.z),
				Vector3(r.x * ARO_ANCHO, ARO_LARGO, r.z * ARO_ANCHO), Tono.ARO,
				[Tono.BASE, Tono.SOMBRA, Tono.BRILLO], false,
				SpriteLienzo.persp_de(r.y, r.z))

		# LA VENTOSA DE LA COLA, con la que se ancla. Plana y pegada al suelo.
		if i == SEGMENTOS - 1:
			poner.call(grupo, Vector3(p.x, p.y - r.y * 0.55, p.z - r.z * 0.30),
				ANCLA_R, Tono.VENTOSA)

		# LA BOCA: la ventosa delantera. Se dibuja en el anillo 0 y asoma por delante de el.
		if i == 0:
			_boca(poner, grupo, p, boca)

	# Y AHORA EL ORDEN: los anillos, de mas ARRIBA en pantalla a mas abajo. El que esta mas abajo esta
	# mas cerca de la camara, asi que se pinta el ultimo y tapa a los de detras. Sin esto, en lo alto
	# del bucle la cola se pintaria por delante de la cabeza.
	grupos.sort_custom(func(a, b): return float(a["sy"]) < float(b["sy"]))
	var salida: Array = suelo
	for gr in grupos:
		salida += gr["piezas"]
	return salida


# LA BOCA REDONDA. Un disco claro (el labio de la ventosa) con la garganta oscura en el centro, y
# mirando hacia DELANTE -- por eso va aplastada en profundidad (BOCA_R.y pequeño): es un anillo visto
# de frente, no una bola.
#
# NO LLEVA LOS DIENTES DE UNO EN UNO, y no es por pereza: a escala 1,6 una celda son 0,72 unidades de
# mundo, asi que un diente de radio 0,5 mide UNA celda -- y 'contornear' convierte en borde toda
# celda que toque el vacio, o sea que un diente de una celda es contorno entero y no se ve nunca. Es
# la misma leccion que las manos del miconido y el cordon de micelio. Aqui cabe la VENTOSA; el anillo
# de dientes cabe en el golpe, que se dibuja a 96 pixeles y no a 8 (ver el estilo VENTOSA).
static func _boca(poner: Callable, grupo: Array, p: Vector3, boca: float) -> void:
	var abre: float = 1.0 + BOCA_ABRE * boca
	var c := Vector3(p.x, p.y + BOCA_ADELANTA, p.z + 0.30)
	var r := Vector3(BOCA_R.x * abre, BOCA_R.y, BOCA_R.z * abre)
	poner.call(grupo, c, r, Tono.VENTOSA)
	# LA GARGANTA se traga el centro al abrirse: de poco mas de la mitad del disco a casi todo el. Es
	# lo que hace que la boca se lea ABIERTA y no solo mas grande.
	var g: float = GARGANTA_ESC + 0.30 * boca
	poner.call(grupo, Vector3(c.x, c.y + 0.20, c.z), Vector3(r.x * g, r.y * 0.7, r.z * g),
		Tono.GARGANTA, [Tono.VENTOSA])


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
