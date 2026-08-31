# ============================================================
#  golem_sprites.gd  (class_name GolemSprites)
#  El GOLEM DE ARCILLA (pisos 7-11) dibujado por codigo. Solo geometria: el motor esta en
#  SpriteLienzo y quien reparte los generadores es SpritesEnemigo.
#
#  VA POR NOMBRE Y NO POR FAMILIA. Los tres constructos son familia PIEDRA -- y tambien lo es la
#  Bestia acorazada --, asi que despachar por familia les daria a los cuatro el MISMO dibujo. Es el
#  mismo caso de los tres insectos.
#
#  ES EL PRIMER BIPEDO CON BRAZOS DEL JUEGO. Va por el PATRON DEL TRENT: un torso de barro es casi
#  redondo en planta, o sea que se ve igual desde los ocho lados -- girarlo no cambiaria nada y solo
#  costaria. Lo que SI gira son los BRAZOS, la CABEZA y las GRIETAS, clavados por direccion.
#
#  BURDO Y ANCHO, que es lo que lo separa del COLOSO (labrado, recto y altisimo) con el que comparte
#  bloque y piso. Aqui no hay una sola linea recta: es un pegote de barro con SIN CUELLO -- la cabeza
#  va hundida entre los hombros -- piernas cortas y MANAZAS DESIGUALES colgando hasta las rodillas.
#
#  SUS DOS HABILIDADES ESTAN DIBUJADAS:
#  - "Machaca": alza los dos puños por encima de la cabeza y los deja caer como un yunque. Es la
#    embestida, y se telegrafia sola porque los puños suben MUCHO antes de bajar.
#  - "Endurecerse": la arcilla se le cuece por dentro. De ahi las GRIETAS con el barro cocido al
#    rojo asomando por dentro -- es lo unico caliente en un bicho de barro apagado.
#
#  MUERE DERRUMBANDOSE EN UN MONTON. Ni vuelca como el escarabajo ni cae entero como el trent: se le
#  van las piernas, se viene abajo sobre si mismo y se DESPARRAMA a lo ancho. Es lo que hace el barro.
# ============================================================

extends RefCounted
class_name GolemSprites

const FRAMES := 8

# --- El golem mirando al SUR, en unidades de MUNDO (origen = donde toca el suelo, +Y hacia donde
# mira, +Z hacia arriba). A escala 1.0 mide unas 22 unidades de ancho de hombros. ---
const ANCHO_MUNDO := 22.0

# PIERNAS: CORTAS Y GRUESAS, muy separadas. Un golem no tiene piernas, tiene dos pilones. Van bien
# abiertas (mas que el radio del torso) para que asomen por debajo en vez de quedarse dentro.
#
# LARGAS DE MAS A PROPOSITO (llegan a z 14,6 y el torso arranca en 12,6). El primer intento las dejo
# en 9,9 contra un torso que empezaba en 8,1: solo asomaban 1,8 unidades, o sea CUATRO CELDAS, y el
# golem salia sin piernas -- un pegote apoyado en el suelo. Lo que se ve de una pierna es lo que
# sobresale por debajo del bulto, no lo que mide.
const PIERNA_X := 4.6
const PIERNA_R := Vector3(3.4, 3.4, 7.4)
const PIERNA_Z := 7.2              # centro: la pierna va de z 0 a z 14,6
# Corto y bajo: tiene Agilidad 10 y arrastra los pies, no trota.
const PASO_LARGO := 2.6
const PASO_ALZA := 1.1
# PIES: una torta de barro aplastada bajo cada pierna. Lo que hace que no acabe en un muñon.
const PIE_R := Vector3(4.2, 4.6, 1.8)

# TORSO: el pegote. ANCHO -- mas ancho que hondo -- y con la masa BAJA, que es lo que da la
# impresion de peso. Se mete varias celdas dentro de las piernas (su base cae en z 12,6 contra los
# 14,6 que llegan ellas): un solape de una celda no es un solape.
# Y CASI REDONDO EN PLANTA (8,0 x 7,2), que es lo que le permite no girar. Con 8,4 x 6,6 la
# diferencia era del 27% y de perfil se dibujaba con su ANCHO en vez de con su FONDO: el bicho
# media lo mismo de canto que de frente, y eso ya no es un pegote, es un muro.
const TORSO := Vector3(0.0, 0.4, 21.0)
const TORSO_R := Vector3(8.0, 7.2, 8.4)
# Y el radio REDONDO EN PLANTA con el que se clavan los adornos. Si se usara el del dibujo (que
# tiene mas ancho que fondo), los hombros y las grietas caerian a distinta distancia segun hacia
# donde mire y entrarian y saldrian del cuerpo al girar. Mismo apaño que el trent y el slime.
const TORSO_ANCLA_R := Vector3(7.2, 7.2, 8.4)

# CABEZA: SIN CUELLO. Va hundida entre los hombros -- su base (z 28,6) queda por debajo de la
# cumbre de los hombros (30,9) --, que es justo lo que hace que se lea como un pegote y no como una
# persona de barro. Subirla tres unidades y aparece un cuello, y con el cuello se va el golem.
#
# PERO TIENE QUE ESTAR MAS ALTA QUE LOS HOMBROS EN PANTALLA, y ese es un numero distinto: con la
# camara a 45 grados lo que separa dos piezas en pantalla es (y - z), no su altura a secas. En el
# primer intento la cabeza (z 23,4) y los hombros (z 20,2) caian a DOS CELDAS de distancia y el
# golem salia con TRES BOLAS EN FILA arriba, sin cara. La separacion en pantalla tiene que ser
# MAYOR QUE EL RADIO DE LA CABEZA o los tres bultos se leen como una fila: 6,5 unidades de altura
# son 11 celdas contra las 10,7 que mide el radio, y ahi la cabeza ya se despega.
const CABEZA := Vector3(0.0, 1.0, 32.0)
const CABEZA_R := Vector3(4.8, 4.3, 4.4)
const CABEZA_ANCLA_R := Vector3(4.3, 4.3, 4.4)

# HOMBROS: dos bultos a los lados. NO son hombreras: son el ensanche del propio pegote, asi que van
# METIDOS en el torso (25,5 mas menos 3,6 = de 21,9 a 29,1, todo dentro de los 29,4 que sube el
# torso) y solo asoman por los costados. Salidos por arriba se leian como dos platos.
const HOMBRO_X := 7.2
const HOMBRO_Z := 25.5
const HOMBRO_R := Vector3(4.2, 4.0, 3.6)
# Y ADELANTADOS UN PELIN. No es un ajuste de dibujo: es lo que hace que la prueba de profundidad
# funcione DE FRENTE. Cual de los dos brazos va delante sale de su Y ya girada (`.y > 0`), y con la
# Y del hombro en CERO exacto la prueba da FALSO para los dos mirando al sur -- o sea que el golem
# de frente dibujaba sus dos brazos como "el de detras": escorzados y en el tono oscuro, pegados al
# cuerpo, sin que se leyeran. Un bipedo que te mira de frente tiene los DOS brazos delante, y para
# que la cuenta lo diga hace falta que el hombro este delante del eje.
const HOMBRO_Y := 0.9

# BRAZOS: LARGOS, hasta por debajo de la rodilla. Cadena de segmentos (como los del trent) porque
# una pieza alargada no se curva y un brazo recto parece un palo clavado.
#
# EL PASO MENOR QUE EL GROSOR, o la cadena sale a trozos sueltos. Aqui el paso es 3,2 contra un
# grosor de 5,2 en el hombro y 4,6 en la muñeca: sobra de largo, y hace falta que sobre porque
# 'alza' estira la cadena al levantar los puños.
const BRAZO_SEGMENTOS := 6
const BRAZO_PASO := 3.0
const BRAZO_R0 := 2.6              # en el hombro
const BRAZO_R1 := 2.1              # en la muñeca
# EL CODO: cuanto se abre el brazo hacia DELANTE segun baja del hombro a la muñeca (en radianes).
#
# Es lo que salva el PERFIL, que fue lo que mas costo. De canto, los dos brazos caen sobre el eje de
# la pantalla -- girados 90 grados, lo que los separa a lo ancho pasa a ser PROFUNDIDAD -- asi que un
# brazo recto de 15 unidades se pintaba ENCIMA del torso y de las piernas: el golem de perfil era un
# borron pale con una barra oscura por el medio, sin piernas. Doblado, el antebrazo sale por delante
# del pecho y por detras vuelven a verse las piernas.
#
# Se ANULA al alzar los puños (multiplica por 1-alza): un machacazo se descarga con el brazo
# estirado, no doblado.
const BRAZO_CODO := 1.05
# EL BRAZO NACE POR DEBAJO DEL CENTRO DEL HOMBRO. Naciendo en el centro, la primera bola del brazo
# --- que es oscura y mide lo mismo que el bulto --- tapaba el hombro ENTERO y el golem se quedaba
# sin la curva de arriba: dos barras oscuras de la cabeza al suelo. Bajandolo un par de unidades, el
# hombro asoma por encima y el brazo CUELGA de el, que es lo que tiene que parecer.
const BRAZO_BAJA := 2.4
# EL BRAZO GIRA EN EL PLANO DE DELANTE, NO EN EL DE LOS COSTADOS. Es el angulo desde "colgando a
# plomo" (0) hacia delante y arriba, y ESA ELECCION ES TODA LA ANIMACION DE LA MACHACA.
#
# El primer intento lo hizo girar en el plano ancho-altura (de colgando, por fuera, hasta arriba), y
# el camino de un sitio al otro pasa por la HORIZONTAL: en dos de los ocho fotogramas del machacazo
# el golem se quedaba en CRUZ, con los dos brazos tiesos en cruz de un lado al otro de la pantalla,
# ocupando el doble de ancho que el bicho. Un golpe de yunque se prepara subiendo los puños POR
# DELANTE de la cara, no abriendo los brazos.
#
# 0 = colgando; PI/2 = estirado hacia delante; 2,75 = por encima de la cabeza y un pelin adelantado.
# Y EN REPOSO NO CUELGA A PLOMO, cuelga un poco ADELANTADO. De perfil los dos brazos caen sobre el
# eje de la pantalla -- girados 90 grados, su separacion a lo ancho pasa a ser PROFUNDIDAD -- y a
# plomo el brazo de delante quedaba pintado ENCIMA del torso, como una raya oscura sobre el pecho en
# vez de como un brazo por delante. Adelantandolo, en el perfil se despega hacia el lado al que mira.
const BRAZO_ANG_REPOSO := 0.12
const BRAZO_ANG_ALTO := 2.75
# Cuanto avanza el brazo hacia delante en lo alto de su arco (a 1.0 la mano acabaria en el suelo,
# delante de los pies). Es lo que hace que el arco pase por delante del pecho y no por el costado.
const BRAZO_ADELANTA := 0.85
# Y cuanto se abre del costado, que aqui es CONSTANTE y pequeño: el brazo baja pegado al cuerpo mire
# a donde mire, y por eso no hay cruz posible.
const BRAZO_ABRE := 0.14
# Cuanto se separa del costado, aparte de lo anterior: los brazos no rozan el torso.
const BRAZO_SEPARA := 0.7

# LAS MANAZAS: LA SEÑA DEL BICHO, y por eso son enormes -- mas gordas que la cabeza. Y DESIGUALES:
# una notablemente mayor que la otra, que es lo que dice que esto lo amasaron a manotazos y no lo
# tallo nadie. La grande va siempre en el mismo lado del CUERPO (no de la pantalla), asi que al
# girar cambia de lado en pantalla y se nota que es el mismo bicho.
#
# GRANDES, PERO NO EL DOBLE QUE EL BRAZO. A radio 4,3 contra un brazo de 2,7 el puño doblaba en
# ancho a lo que colgaba de el, y con un tono muy claro encima se despegaba: parecian dos TORTITAS
# flotando a los lados. La manaza tiene que ser lo bastante mayor para leerse y lo bastante parecida
# para seguir siendo la punta de ese brazo.
const PUNO_R := Vector3(3.7, 3.6, 3.7)
const PUNO_GRANDE := 1.24
const PUNO_PEQUENO := 0.88
# Los NUDILLOS: tres bolitas en el dorso de cada puño. Sin ellas el puño es una bola y podria ser
# cualquier cosa; con ellas se lee que es una mano cerrada.
#
# VAN EN SOMBRA Y CONTENIDOS DENTRO DEL PUÑO ('solo_sobre'). A la primera se pintaron del tono
# OSCURO del brazo y sueltas: las tres se fundian en una sola mancha que asomaba por el filo, y el
# puño parecia MORDIDO. Contenidas, lo que se ve son tres hendiduras en la mano y no un boquete.
const NUDILLOS := 3
const NUDILLO_R := 1.05

# GRIETAS: por donde se le cuece la arcilla. Cada una es una CADENA de trozos cada vez menores,
# bajando en diagonal por el frente del torso -- una raya recta no parece una grieta, parece una
# junta. Y dentro va el barro COCIDO, que es lo unico caliente del bicho.
#
# ARRANCAN ARRIBA Y BAJAN. Puestas en mitad del torso las dos, se juntaban en el ombligo y el naranja
# salia como una FLOR en la barriga -- lo primero que se le veia al bicho, y lo que menos importa.
# Una grieta nace en el pecho y corre hacia abajo.
#
# FINAS Y LARGAS. A radio 1,9 median NUEVE CELDAS de ancho -- mas que el brazo -- y las dos juntas
# salian como dos pegotes oscuros pegados a la barriga, con el naranja dentro como dos bayas. Una
# grieta es un TAJO: tiene que ser lo mas fina que aguante y compensarlo alargandose.
#
# Y aqui SI se puede bajar de las 3 celdas de la regla del contorno, porque estas piezas van DENTRO
# del cuerpo: 'contornear' solo perfila lo que toca el vacio, o sea la silueta de fuera.
const GRIETA_DIR := Vector3(0.34, 0.84, 0.58)
const GRIETA_HUNDE := 1.4
const GRIETA_TROZOS := 4
const GRIETA_R0 := 1.15
const GRIETA_R1 := 0.80
const GRIETA_BAJA := 2.1           # cuanto cae cada trozo respecto al anterior
const GRIETA_ABRE := 1.0           # y cuanto se desvia de lado: la grieta serpentea

# OJOS: dos puntos claros hundidos en la sombra de la cabeza. Son LO QUE LO HACE CRIATURA.
#
# BIEN SEPARADOS Y PEQUEÑOS. Al 0,34 de antes caian a cuatro celdas uno del otro y con radio 1,30 se
# tocaban: la cara era UNA mancha clara, no dos ojos. Es la misma leccion que la araña (dos amarillos
# iguales juntos no se distinguen) y que los ojos de perfil del trent.
const OJO_DIR := Vector3(0.56, 0.82, 0.14)
const OJO_R := Vector3(1.15, 1.15, 1.10)
const OJO_HUNDE := 1.2
# Hasta donde puede irse un ojo hacia atras y seguir viendose (Y de su direccion, ya girada). Mismo
# criterio que el trent y el slime: de frente y de medio lado los dos, de perfil uno, de espaldas
# ninguno.
const OJO_VISIBLE := -0.15

# Cuanto se encoge lo que queda DETRAS del cuerpo. Es escorzo barato y ademas ayuda a leer cual de
# los dos brazos esta delante.
const DETRAS_ESC := 0.90

const LUNGE_DIST := 4.6
# Encaja poco: es una mole. Se hunde sobre las piernas y vuelve.
const ENCAJE_RETRO := 0.30

# --- EL LIENZO, en multiplos del ancho de hombros. RECTANGULAR y con el origen BAJO, como el del
# trent: el origen es el punto que toca el suelo y el bicho entero crece hacia arriba.
# ARRIBA tiene que dar para los PUÑOS ALZADOS, que es la pose mas alta con diferencia (el puño sube
# a z 49 contra los 37 de la coronilla). ANCHO, para los brazos colgando (que se van a 19,6 del eje)
# MAS el desparrame de la muerte, que multiplica por 1,42: 27,8 unidades a cada lado.
#
# Y ABAJO HACE FALTA MAS DE LO QUE PARECE, aunque el golem no se tumbe. Al derrumbarse se DESPARRAMA
# (x1,42) tambien en PROFUNDIDAD, y con la camara a 45 grados la profundidad baja en pantalla: la
# falda del monton se iba 35 celdas por debajo del suelo contra las 32 que habia, y el horno cantaba
# los tres primeros 'cadaver' cortados en seco. Lo que se sale de un lienzo no siempre es lo alto.
#
# Y EL QUE MANDA ES EL CADAVER, NO EL BICHO DE PIE, aunque este no se tumbe. Medido sobre el
# horneado: de pie ocupa 41 celdas a cada lado del eje y el cadaver 66 -- y solo hacia UN lado. Se
# vuelca hacia delante ('mece' 1,9) y ademas lleva los brazos doblados hacia delante, asi que todo
# el monton se va en la direccion a la que mira; en las ocho direcciones eso son 66 celdas en
# cualquiera de ellas. Ampliar un lienzo es casi gratis (el horno recorta cada fotograma a su dibujo
# y guarda el hueco como margen), asi que se le da de sobra y no se vuelve a mirar.
const LIENZO_ANCHO := 3.00
const LIENZO_ARRIBA := 2.20
const LIENZO_ABAJO := 1.05

# TONOS propios (el motor no sabe que es cada uno; solo mapea indice -> color, ver _colores).
enum Tono { VACIO, SOMBRA_SUELO, BORDE, PIE_T, PIERNA_OSC, PIERNA_T, BRAZO_OSC, BRAZO_T, BARRO_OSC,
	BARRO, BARRO_CLARO, PUNO_OSC, PUNO_T, GRIETA_T, COCIDO, OJO_T, APAGADO }

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
	return "golem_%s_%.2f" % [col.to_html(false), esc]


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(escala: float = 1.0) -> int:
	return _lienzo(escala).x


static func dimensiona_por_escala() -> bool:
	return true


# El CUERPO en planta (ancho, largo). SOLO TORSO Y PIERNAS: los BRAZOS quedan fuera, igual que las
# patas de la araña y la pala del escarabajo. Lo que estorba de un golem es su bulto; los brazos
# cuelgan a los lados y meterlos daria una huella de 34 unidades donde el cuerpo mide 17.
#
# Sale REDONDO (17,2 de lado), o sea por debajo del 1.3 de proporcion con el que enemy.gd gira la
# colision: es lo correcto, un pegote estorba lo mismo se ponga como se ponga.
static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	var lado: float = maxf(TORSO_R.x, PIERNA_X + PIERNA_R.x) * 2.0
	return Vector2(lado, lado) * escala


static func _lienzo(escala: float) -> Vector2i:
	var u: float = ANCHO_MUNDO * escala / SpriteLienzo.UNIDADES_POR_CELDA
	var w: int = int(ceil(u * LIENZO_ANCHO))
	var h: int = int(ceil(u * (LIENZO_ARRIBA + LIENZO_ABAJO)))
	return Vector2i(w + (w % 2), h + (h % 2))


# Donde cae el ORIGEN (el punto que toca el suelo) dentro del lienzo: centrado a lo ancho y BAJO a
# lo alto, porque el bicho crece hacia arriba desde ahi.
static func _origen(escala: float) -> Vector2:
	var l: Vector2i = _lienzo(escala)
	return Vector2(float(l.x) * 0.5, float(l.y) * LIENZO_ARRIBA / (LIENZO_ARRIBA + LIENZO_ABAJO))


static func generar(color: Color = Color(0.6, 0.45, 0.3), escala: float = 1.0) -> SpriteFrames:
	# cuantizar_hsv y no cuantizar a secas: el ocre del barro es de los colores apagados a los que el
	# redondeo canal a canal les cambia el TONO (al Rey rata lo dejo verde oliva y al jabali gris).
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


# La pose de siempre, con todo a cero. Existe para que cada animacion solo escriba lo suyo y no haya
# que repetir doce claves en cada una (y para que añadir una clave nueva no obligue a tocarlas todas).
static func _reposo() -> Dictionary:
	return {"avance": 0.0, "mece": 0.0, "balanceo": 0.0, "brazos": 0.0, "alza": 0.0,
		"patas": 0.0, "agacha": 0.0, "cabeza": 0.0, "derrumbe": 0.0, "apoyo": 0.0}


# Quieto: respira muy despacio y los brazos se balancean un pelin. A 3 fps, como el trent -- tiene
# Agilidad 10 y tiene que LEERSE lento antes de que te fijes en su barra.
static func _montar_idle(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["mece"] = 0.35 * sin(TAU * t)
		p["brazos"] = 0.30 * sin(TAU * t + 0.7)
		# La respiracion es un agacharse minimo: el bulto sube y baja.
		p["agacha"] = 0.05 * (1.0 - cos(TAU * t))
		return p
	_montar_animacion(anims, esc, "idle", true, 3.0, pose, false)


# Andando: NADA DE BOTE. Bascula de un pilon al otro y arrastra el peso, y los brazos van en
# contrafase con las piernas. El balanceo lateral es lo que se lee como paso pesado.
static func _montar_walk(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["patas"] = sin(TAU * t)
		p["brazos"] = -0.9 * sin(TAU * t)          # contrafase: brazo contrario a la pierna
		p["balanceo"] = sin(TAU * t)
		p["mece"] = 0.30 * sin(TAU * t)
		# Se hunde en cada apoyo (dos veces por ciclo, una por pie).
		p["agacha"] = 0.10 * (1.0 - cos(TAU * t * 2.0))
		return p
	_montar_animacion(anims, esc, "walk", true, 5.0, pose, false)


# LA EMBESTIDA ES SU "MACHACA": alza los dos puños por encima de la cabeza, aguanta arriba y los
# deja caer como un yunque. No corre -- no puede -- asi que el avance es corto: es un paso adelante
# para descargar, no una carga.
#
# SE VE VENIR A PROPOSITO, que es lo que dice su propia descripcion ("se ve venir; apartate o
# aturdilo antes de que baje"). Por eso los puños suben pronto (0,20) y se quedan ARRIBA hasta bien
# pasada la mitad (0,52): esa espera es la ventana del jugador, y tiene que verse.
# NO es periodica, asi que va por TRAMOS.
static func _montar_embestida(anims: Array, esc: float) -> void:
	# LA DESCARGA NO BAJA DE 0: 'alza' 0 ya es el brazo colgando a plomo y por debajo se iria HACIA
	# ATRAS, o sea el golem tirando los puños a su espalda. El machacazo acaba con las manos abajo y
	# DELANTE (0,22), que es donde ha caido el yunque.
	var alza_keys := [[0.0, 0.0], [0.20, 0.85], [0.38, 1.0], [0.52, 0.95], [0.68, 0.22],
		[0.82, 0.14], [1.0, 0.0]]
	# Se echa atras mientras sube los brazos y se vuelca adelante al descargar.
	var mece_keys := [[0.0, 0.0], [0.20, -1.0], [0.52, -1.2], [0.68, 1.5], [0.82, 1.0], [1.0, 0.2]]
	var avance_keys := [[0.0, 0.0], [0.20, -0.8], [0.52, -1.0], [0.68, 4.2], [0.82, 4.6], [1.0, 3.0]]
	# Y se hunde sobre las piernas justo al golpear: es el peso llegando al suelo.
	var agacha_keys := [[0.0, 0.0], [0.38, -0.25], [0.52, -0.30], [0.68, 0.85], [0.82, 0.55],
		[1.0, 0.15]]
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["alza"] = SpriteLienzo.tramos(t, alza_keys)
		p["mece"] = SpriteLienzo.tramos(t, mece_keys)
		p["avance"] = SpriteLienzo.tramos(t, avance_keys) * (LUNGE_DIST / 4.6)
		p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
		# Mira el golpe: al descargar baja la cabeza.
		p["cabeza"] = maxf(0.0, SpriteLienzo.tramos(t, alza_keys) * -0.6)
		return p
	_montar_animacion(anims, esc, "embestida", false, 10.0, pose, true)


# ENCAJAR UN GOLPE. Cuatro fotogramas en UNA direccion y EMPEZANDO YA GOLPEADO: el frame 0 es el
# impacto. Un golpe no tiene anticipacion, y con cuatro marcos un fotograma de espera se comeria la
# animacion entera.
#
# SE HUNDE Y VUELVE. Retrocede poco -- es una mole de barro --, pero la cabeza SI se le va: es lo
# unico que tiene suelto encima del cuerpo y sin ese latigazo el golpe no se lee.
static func _montar_encaje(anims: Array, esc: float) -> void:
	var retro_keys := [[0.0, 1.0], [0.34, 0.42], [0.67, 0.12], [1.0, 0.0]]
	var agacha_keys := [[0.0, 0.90], [0.34, 0.28], [0.67, 0.08], [1.0, 0.0]]
	# La cabeza se pasa hacia el otro lado y vuelve: sin el rebote parece que se esta inclinando.
	var mece_keys := [[0.0, -1.6], [0.34, 0.8], [0.67, -0.3], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["avance"] = -SpriteLienzo.tramos(t, retro_keys) * (LUNGE_DIST * ENCAJE_RETRO)
		p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
		p["mece"] = SpriteLienzo.tramos(t, mece_keys)
		p["cabeza"] = SpriteLienzo.tramos(t, mece_keys) * 0.5
		p["brazos"] = SpriteLienzo.tramos(t, mece_keys) * 0.4
		return p
	# LOS BICHOS ENCAJAN A 18 fps: es la duracion que espera CombatFX.T_ENCAJE.
	_montar_animacion(anims, esc, "encaje", false, 18.0, pose, true, 1, 4)


# MORIRSE. OCHO fotogramas en UNA sola direccion: la muerte solo se ve en la pantalla de combate, y
# ahi al bicho se le mira siempre de frente. Para el mapa esta 'cadaver'.
#
# SE DERRUMBA EN UN MONTON. Ni vuelca (escarabajo) ni cae de una pieza (trent): a un cuerpo de barro
# se le van las piernas y se viene abajo SOBRE SI MISMO, desparramandose a lo ancho. El truco es
# bajar y ENSANCHAR a la vez -- bajando sin ensanchar sale el mismo golem mas pequeño, o sea un
# golem enano, no uno derrumbado. Es lo mismo que aprendio el trent.
#
# Y ARRANCA CON UN TEMBLOR: se le va una pierna, se tambalea y ahi ya no hay vuelta. Sin ese aviso
# el derrumbe se lee como una interpolacion.
static func _pose_muerte(t: float) -> Dictionary:
	var derr_keys := [[0.0, 0.0], [0.16, 0.05], [0.32, 0.18], [0.50, 0.46],
		[0.68, 0.78], [0.84, 0.95], [1.0, 1.0]]
	# El tambaleo del principio, y luego se vuelca hacia delante mientras se deshace.
	var mece_keys := [[0.0, 0.0], [0.16, -1.1], [0.32, 0.6], [0.50, 1.4], [0.68, 1.8], [1.0, 1.9]]
	var balan_keys := [[0.0, 0.0], [0.16, 0.9], [0.32, -0.7], [0.50, 0.3], [1.0, 0.0]]
	# Los brazos se descuelgan y quedan tirados por delante del monton, PERO MUY POCO. Nada de 'alza'
	# negativo (por debajo de 0 el brazo se va hacia ATRAS, y un golem que se desploma no echa los
	# brazos a la espalda), y nada de pasarse por arriba: a 0,50 el angulo se va a 1,44 radianes, o
	# sea el brazo casi HORIZONTAL hacia delante -- el cadaver hacia el zombi, con las dos manos
	# estiradas 21 unidades por delante del monton. Ademas de feo salia carisimo: obligaba a un
	# lienzo de 180 celdas de ancho para que cupiera esa pose en las ocho direcciones.
	var alza_keys := [[0.0, 0.0], [0.16, 0.06], [0.32, 0.12], [0.68, 0.16], [1.0, 0.18]]
	# La cabeza cae hacia delante antes que el resto: es lo que tiene mas suelto.
	var cab_keys := [[0.0, 0.0], [0.16, 0.3], [0.32, 1.0], [0.68, 1.7], [1.0, 1.9]]
	# Las piernas ceden desde el primer momento.
	var agacha_keys := [[0.0, 0.0], [0.16, 0.35], [0.32, 0.70], [0.68, 1.0], [1.0, 1.0]]
	var p: Dictionary = _reposo()
	p["derrumbe"] = SpriteLienzo.tramos(t, derr_keys)
	p["mece"] = SpriteLienzo.tramos(t, mece_keys)
	p["balanceo"] = SpriteLienzo.tramos(t, balan_keys)
	p["alza"] = SpriteLienzo.tramos(t, alza_keys)
	p["cabeza"] = SpriteLienzo.tramos(t, cab_keys)
	p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
	return p


static func _montar_muerte(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return _pose_muerte(t)
	_montar_animacion(anims, esc, "muerte", false, 10.0, pose, true, 1, 8)


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
			# golem de otro tono reusa estas plantillas y solo repinta.
			var clave: String = "%s_%d_%d_%.2f" % [nombre, i, dir, esc]
			var plant: PackedByteArray = _cache_plantillas.get(clave, PackedByteArray())
			if plant.is_empty():
				plant = _plantilla(dir, pose_fn.call(float(i) / divisor), esc)
				_cache_plantillas[clave] = plant
			plantillas.append(plant)
		anims.append({"nombre": "%s_%d" % [nombre, dir], "loop": loop, "fps": fps,
			"plantillas": plantillas})


# EL BARRO ES MATE, y eso es justo lo contrario del escarabajo de hierro: alli habia que OSCURECER
# para dejar sitio a un reflejo duro. Aqui no hay reflejo -- la arcilla no brilla --, asi que el
# color se queda casi donde esta y el volumen lo pone un degradado suave de tres tonos.
#
# LA SATURACION SI SE SUBE, como en todos: el color que llega no es el de la ficha, es
# 'color_visual', que ya viene aclarado hacia el blanco segun la 't' del bicho, o sea desaturado de
# fabrica. Sin subirla, el ocre se queda en un beige de yeso.
static func _barro(color: Color) -> Color:
	var out := Color.from_hsv(color.h, minf(1.0, color.s * 1.22 + 0.06), color.v * 0.94)
	out.a = color.a
	return out


# Los colores de cada Tono, EN EL ORDEN DEL ENUM (contrato con SpriteLienzo.paleta).
static func _colores(color: Color) -> Array:
	var c: Color = _barro(color)
	return [
		Color(0, 0, 0, 0),                    # VACIO
		Color(0, 0, 0, 0.24),                 # SOMBRA_SUELO
		c.darkened(0.70),                     # BORDE
		# EL PIE VA SUCIO: es lo que arrastra por el suelo. Y oscuro, que es lo que separa al bicho
		# de su propia sombra.
		c.darkened(0.56),                     # PIE_T
		# LAS PIERNAS LLEVAN TONO PROPIO, y no es capricho de paleta: con el mismo del torso, la luz
		# del torso se pinta 'solo_sobre' ese tono y se las REPINTABA -- todo el bajo del bicho se
		# quedaba en una masa sin piernas. Es el fallo que ya tuvo el trent.
		# Y la adelantada mas clara que la de atras: es lo que hace legible el paso.
		c.darkened(0.46),                     # PIERNA_OSC (la de detras)
		c.darkened(0.32),                     # PIERNA_T (la adelantada)
		# LOS BRAZOS VAN EN SOMBRA, Y ES LO UNICO QUE LOS SEPARA DEL TORSO.
		#
		# Cuelgan pegados al costado, asi que entre brazo y cuerpo NO HAY HUECO -- y sin hueco no hay
		# contorno, porque 'contornear' solo perfila lo que toca el vacio, o sea la silueta de fuera.
		# Con el tono del torso el golem salia como UN SOLO BULTO con dos muñones. Separarlos
		# abriendo los brazos tampoco vale: a poco que se abren, el bicho sale en cruz y ocupa el
		# doble. La palanca que queda es el TONO, que es la misma que usa el trent con sus dos ramas.
		#
		# Y en SOMBRA y no a la luz porque ademas es lo que toca: un brazo colgando por delante del
		# cuerpo esta a la sombra del propio cuerpo.
		c.darkened(0.56),                     # BRAZO_OSC (el brazo de detras, ademas escorzado)
		c.darkened(0.42),                     # BRAZO_T (el de delante)
		c.darkened(0.26),                     # BARRO_OSC (el costado del torso, en penumbra)
		c,                                    # BARRO
		# Lo alto del torso y de la cabeza, a la luz. Se aclara HACIA UN OCRE MAS CLARO y no hacia el
		# blanco: 'lightened' desatura, y un barro desaturado es yeso. Misma leccion que el lomo del
		# jabali.
		c.lerp(Color(0.86, 0.72, 0.50), 0.34),                # BARRO_CLARO
		# LAS MANAZAS: UN escalon por encima de su brazo, no dos. Puestas en un ocre claro se leian
		# como dos piezas pegadas al final de dos palos -- el salto de tono era mayor que el que hay
		# entre el brazo y el torso, asi que la mano parecia de otro material. Un escalon basta para
		# que se vea donde acaba el brazo y empieza el puño.
		c.darkened(0.42),                     # PUNO_OSC (la mano del brazo de detras)
		c.darkened(0.28),                     # PUNO_T
		c.darkened(0.66),                     # GRIETA_T (el tajo en la arcilla)
		# EL BARRO COCIDO que asoma por la grieta: naranja rojizo y CALIENTE. Es su habilidad
		# "Endurecerse" dibujada, y lo unico caliente de un bicho apagado -- si no canta, no se ve.
		Color(0.85, 0.38, 0.14),              # COCIDO
		Color(0.96, 0.88, 0.58),              # OJO_T (dos puntos claros en la sombra de la cara)
		# SE LE APAGA EL HORNO. Lo usan los ojos Y el barro cocido cuando el golem se derrumba: eran
		# lo unico encendido del bicho, y un cadaver que sigue mirando con los ojos amarillos y con la
		# arcilla al rojo no esta muerto, esta tumbado. Un solo tono para los dos porque es una sola
		# cosa la que se apaga.
		c.darkened(0.60),                     # APAGADO
	]


# ------------------------------------------------------------
#  GEOMETRIA
# ------------------------------------------------------------

# Una direccion desde el centro de una pieza -> el punto de su superficie en esa direccion, metido
# 'hunde' hacia dentro. Es lo que garantiza que ningun adorno flote: la superficie esta a distinta
# distancia en cada direccion, asi que un punto puesto a mano encaja mirando a un lado y se despega
# mirando al otro. Calcado del trent.
static func _en_la_pieza(dir: Vector3, hunde: float, centro: Vector3, radio: Vector3) -> Vector3:
	var d: Vector3 = dir.normalized()
	return centro + Vector3(radio.x * d.x, radio.y * d.y, radio.z * d.z) - d * hunde


# Las PIEZAS del golem para una pose, ya proyectadas a pantalla. El orden ES la profundidad: de lo
# mas bajo y lejano (sombra, pies, el brazo de detras) a lo mas alto y cercano (cabeza, ojos, el
# brazo de delante).
static func _piezas(dir: int, pose: Dictionary, esc: float) -> Array:
	var ang: float = DIR_VECS[dir].angle() - DIR_VECS[0].angle()
	var u: float = esc / SpriteLienzo.UNIDADES_POR_CELDA
	var origen: Vector2 = _origen(esc)
	var mece: float = float(pose["mece"])
	var balanceo: float = float(pose["balanceo"])
	var fase_brazos: float = float(pose["brazos"])
	var alza: float = float(pose["alza"])
	var avance: float = float(pose["avance"])
	var agacha: float = float(pose["agacha"])
	var cabeza_cae: float = float(pose["cabeza"])
	var fase_patas: float = float(pose["patas"])
	# DERRUMBARSE (0..1). Con default 0, o sea que las poses de siempre no lo notan.
	var derrumbe: float = clampf(float(pose.get("derrumbe", 0.0)), 0.0, 1.0)

	# Bajar y ENSANCHAR a la vez: eso es un monton de barro. Solo bajando saldria un golem enano.
	var baja: float = 1.0 - 0.78 * derrumbe
	var derrama: float = 1.0 + 0.42 * derrumbe
	# Agachado = mas bajo y un pelin mas ancho, como el escarabajo. Cuenta aparte del derrumbe
	# porque lo usan las cuatro animaciones de andar y pelear.
	var alto_f: float = (1.0 - 0.16 * agacha) * baja
	var ancho_f: float = (1.0 + 0.05 * agacha) * derrama

	var piezas: Array = []
	# EL AVANCE SE ROTA UNA VEZ Y LO LLEVAN TODAS LAS PIEZAS POR IGUAL. Sumarlo a la Y local antes de
	# rotar solo funcionaria si TODAS las piezas giraran, y aqui el torso y la cabeza NO giran (son
	# redondos en planta): el bicho se partiria en dos mitades yendose a sitios distintos. Es la
	# trampa del meceo del trent, que fue el peor bug que ha tenido este motor.
	var desp := Vector2(0.0, avance).rotated(ang)
	# EL MECEO, IGUAL: en pantalla y despues de rotar. Y se dobla POR LA ALTURA, o sea que la cabeza
	# va y viene y los pies no se despegan del suelo.
	var mece_v := Vector2(balanceo * 1.7, mece * 1.6)

	# 'gira' = false para lo que se ve igual desde los ocho lados (torso, cabeza, la sombra): son
	# redondos en planta y estan centrados en el eje, asi que rotarlos no los moveria -- y ademas
	# ahorra el rotated().
	var poner := func(local: Vector3, r: Vector3, tono: int, solo_sobre: Array = [],
			gira: bool = true) -> void:
		var lz: float = local.z * alto_f
		var p := Vector2(local.x * ancho_f, local.y * derrama)
		# El meceo se dobla por la altura ORIGINAL (no la de despues de derrumbarse): es la cizalla
		# del cuerpo, y un cuerpo ya caido no se mece.
		var alto: float = clampf(local.z / CABEZA.z, 0.0, 1.4)
		var rot: Vector2 = (p.rotated(ang) if gira else p) + desp + mece_v * alto
		var sx: float = origen.x + rot.x * u
		var sy: float = origen.y + (rot.y * SpriteLienzo.COS_CAM - lz * SpriteLienzo.SIN_CAM) * u
		var rz: float = r.z * alto_f
		var ry: float = r.y * derrama
		piezas.append({"pos": Vector2(sx, sy),
			"radio": Vector2(r.x * ancho_f * u, ry * u),
			"persp": SpriteLienzo.persp_de(ry, rz),
			"tono": tono, "solo_sobre": solo_sobre})

	# 1. SOMBRA DE CONTACTO, lo primero (va debajo de todo). A ALTURA CERO y sin derrumbe en la
	#    altura: es una mancha en el suelo y el suelo no se hunde.
	poner.call(Vector3(0.0, 0.0, 0.0),
		Vector3(TORSO_R.x * 1.10, TORSO_R.y * 1.10, 0.0), Tono.SOMBRA_SUELO, [], false)

	# LOS PIES, calculados una vez porque los usan los pies y las piernas. GIRAN CON EL BICHO (al
	# contrario que el torso) y DAN EL PASO: uno adelante y otro atras, en contrafase. El adelantado
	# se levanta un poco -- poco, que esto arrastra mas que pisa.
	var pies: Array = []
	for lado in [-1.0, 1.0]:
		var swing: float = fase_patas * lado
		pies.append(Vector3(lado * PIERNA_X, swing * PASO_LARGO,
			PIERNA_Z + maxf(0.0, swing) * PASO_ALZA))

	# 2. LOS PIES: una torta de barro aplastada bajo cada pierna.
	for pie in pies:
		poner.call(Vector3(pie.x, pie.y, pie.z - PIERNA_Z + PIE_R.z), PIE_R, Tono.PIE_T)

	# 3. LOS BRAZOS: primero hay que saber cual esta DETRAS, y sale de su Y YA GIRADA -- una prueba
	#    de profundidad de verdad, no una tabla por direccion que haya que mantener.
	#    LA MANO GRANDE VA SIEMPRE EN EL MISMO LADO DEL CUERPO (lado -1), no de la pantalla: asi al
	#    girar cambia de lado en pantalla y se lee que es el mismo bicho dandose la vuelta.
	var brazos: Array = []
	for lado in [-1.0, 1.0]:
		var hombro := Vector3(lado * HOMBRO_X, HOMBRO_Y, HOMBRO_Z)
		brazos.append({"lado": lado, "hombro": hombro,
			"puno": PUNO_GRANDE if lado < 0.0 else PUNO_PEQUENO,
			"delante": Vector2(hombro.x, hombro.y).rotated(ang).y > 0.0})
	for b in brazos:
		if not bool(b["delante"]):
			_brazo(poner, b, fase_brazos, alza, DETRAS_ESC, Tono.BRAZO_OSC, Tono.PUNO_OSC)

	# 4. PIERNAS: cada una sobre su pie. La ADELANTADA en tono mas claro, que es lo que deja ver de
	#    un vistazo cual de las dos ha dado el paso.
	for k in pies.size():
		poner.call(pies[k], PIERNA_R,
			Tono.PIERNA_T if pies[k].y >= pies[1 - k].y else Tono.PIERNA_OSC)

	# 5. EL TORSO, entero en penumbra...
	poner.call(TORSO, TORSO_R, Tono.BARRO_OSC, [], false)

	# 6. HOMBROS: dos bultos que ensanchan la silueta por arriba. Sin ellos el torso se estrecha
	#    hacia la cabeza y el golem parece un huevo.
	#
	#    GIRAN, como todo lo que esta a un lado del cuerpo, y VAN JUSTO ANTES DE LA CABEZA. Las dos
	#    cosas juntas, porque cada una arregla el problema que crea la otra:
	#
	#    - Girando, de perfil uno se va hacia la camara y el otro al fondo, o sea uno ABAJO y otro
	#      ARRIBA en pantalla (7,2 unidades de profundidad son 12 celdas de altura con la camara a
	#      45). El de arriba cae justo a la altura de la cabeza, y los tres bultos en columna salian
	#      como un MUÑECO DE NIEVE.
	#    - Pero la CABEZA se pinta despues y mide 10,7 celdas de radio: TAPA al hombro del fondo casi
	#      entero. Lo que queda es el hombro de delante, bajo y adelantado, que es exactamente donde
	#      tiene que estar visto de canto.
	#
	#    Sin girar tampoco vale, aunque de frente quede igual: de perfil se quedan los dos clavados a
	#    los lados y el golem enseña dos hombros donde deberia enseñar uno. El usuario lo caza a ojo.
	poner.call(Vector3(TORSO.x, TORSO.y, TORSO.z + TORSO_R.z * 0.20), TORSO_R * 0.98,
		Tono.BARRO, [Tono.BARRO_OSC], false)
	poner.call(Vector3(TORSO.x, TORSO.y - TORSO_R.y * 0.20, TORSO.z + TORSO_R.z * 0.50),
		TORSO_R * 0.52, Tono.BARRO_CLARO, [Tono.BARRO], false)
	for b in brazos:
		var h: Vector3 = b["hombro"]
		poner.call(h, HOMBRO_R, Tono.BARRO_OSC)
		# La luz del hombro: PEGADA a su centro. Subida (0,35 del semialto) dejaba un canto
		# horizontal limpio cruzando el bulto y los hombros se leian como dos PLATOS de canto, o sea
		# hombreras de armadura -- justo lo del coloso y justo lo que este no es.
		poner.call(Vector3(h.x, h.y, h.z + HOMBRO_R.z * 0.16), HOMBRO_R * 0.78,
			Tono.BARRO, [Tono.BARRO_OSC])

	# 7. LAS GRIETAS: cadenas de trozos bajando por el frente del torso, con el barro cocido dentro.
	#    GIRAN, o un golem visto de espaldas seguiria enseñandolas por la grupa.
	# SE LE APAGA EL HORNO AL MORIR. Los ojos y el barro cocido son lo unico encendido del bicho, y
	# un monton de barro que sigue mirando con los ojos amarillos no esta muerto, esta tumbado. Se
	# van los dos a la vez y de golpe (no es un degradado: son tonos de paleta, no colores), a mitad
	# del derrumbe, que es cuando ya no hay vuelta atras.
	var encendido: bool = derrumbe < 0.45
	# LA GRIETA SE QUEDA EN EL PECHO AUNQUE EL GOLEM GIRE, y eso hay que hacerlo a mano.
	#
	# El torso NO gira (es redondo en planta, se ve igual desde los ocho lados) pero la grieta SI --
	# tiene que hacerlo, o de espaldas se le seguiria viendo por la grupa. El problema es lo que pasa
	# entre medias: con la camara a 45 grados la altura en pantalla sale de (y - z), asi que al girar
	# cambia la Y de la grieta y la grieta SE DESLIZA hacia abajo por un cuerpo que no se ha movido.
	# Del sur al norte son 18 celdas de recorrido: la grieta baja del pecho a la barriga ella sola.
	#
	# La cuenta: como COS_CAM y SIN_CAM son iguales a 45 grados, la altura en pantalla es
	# proporcional a (y - z) A SECAS. Basta con corregir la z en lo mismo que ha cambiado la y para
	# que (y - z) no se mueva, y entonces la grieta solo se desplaza a lo ANCHO -- que es justo lo
	# que hace una marca en el costado de una pieza redonda al darse la vuelta.
	#
	# Por eso el anclaje se rota AQUI y se le pasa a 'poner' con gira = false: ya viene girado.
	var anclar := func(d: Vector3) -> Array:
		var a: Vector3 = _en_la_pieza(d, GRIETA_HUNDE, TORSO, TORSO_ANCLA_R)
		var r: Vector2 = Vector2(a.x, a.y).rotated(ang)
		return [Vector3(r.x, r.y, a.z + (r.y - a.y)), r.y]
	var g1: Array = anclar.call(GRIETA_DIR)
	if float(g1[1]) > 0.0:
		_grieta(poner, g1[0], 1.0, encendido)
	# La segunda, al otro lado y MAS BAJA (z negativo en la direccion = por debajo del ecuador del
	# torso), para que las dos no salgan gemelas ni se junten en el mismo sitio.
	var g2: Array = anclar.call(Vector3(-GRIETA_DIR.x * 1.4, GRIETA_DIR.y, -GRIETA_DIR.z * 0.5))
	if float(g2[1]) > 0.0:
		_grieta(poner, g2[0], -0.8, encendido)

	# 8. LA CABEZA, hundida entre los hombros. Cae hacia delante con 'cabeza' (al descargar el
	#    machacazo, y sobre todo al morirse). No gira: es un pegote redondo.
	var cab := Vector3(CABEZA.x, CABEZA.y + cabeza_cae * 1.5, CABEZA.z - cabeza_cae * 1.1)
	poner.call(cab, CABEZA_R, Tono.BARRO_OSC, [], false)
	poner.call(Vector3(cab.x, cab.y, cab.z + CABEZA_R.z * 0.28), CABEZA_R * 0.88,
		Tono.BARRO, [Tono.BARRO_OSC], false)
	poner.call(Vector3(cab.x, cab.y - CABEZA_R.y * 0.25, cab.z + CABEZA_R.z * 0.55),
		CABEZA_R * 0.50, Tono.BARRO_CLARO, [Tono.BARRO], false)

	# 9. OJOS: dos puntos claros hundidos en la sombra de la cara. De espaldas NO se le ven -- un
	#    bicho que se aleja enseña la nuca, y eso es lo que hace que se lea de un vistazo si viene o
	#    si huye.
	#
	#    SE CLAVAN EN 'CABEZA', LA DE REPOSO, y luego se les suma lo que la cabeza se ha movido. Es
	#    la leccion del trent: anclar sobre la pieza YA movida y volver a moverla la inclina DOS
	#    veces, y los ojos salen volando justo en los frames del ataque, que es cuando se miran.
	var ojos: Array = []
	for l in [-1.0, 1.0]:
		var d := Vector3(l * OJO_DIR.x, OJO_DIR.y, OJO_DIR.z)
		var fondo: float = Vector2(d.x, d.y).rotated(ang).y
		if fondo > OJO_VISIBLE:
			var o: Vector3 = _en_la_pieza(d, OJO_HUNDE, CABEZA, CABEZA_ANCLA_R)
			ojos.append({"pos": Vector3(o.x, o.y + cabeza_cae * 1.5, o.z - cabeza_cae * 1.1),
				"fondo": fondo})
	# DE PERFIL PURO, UNO SOLO: ahi los dos caen en la misma X de pantalla y se separan solo en
	# vertical, y dos ojos uno encima del otro se leen como un borron, no como una cara.
	if absf(DIR_VECS[dir].x) >= 0.9 and ojos.size() == 2:
		ojos = [ojos[0] if float(ojos[0]["fondo"]) > float(ojos[1]["fondo"]) else ojos[1]]
	for o in ojos:
		poner.call(o["pos"], OJO_R, Tono.OJO_T if encendido else Tono.APAGADO)

	# 10. EL BRAZO DE DELANTE, ya sobre el cuerpo.
	for b in brazos:
		if bool(b["delante"]):
			_brazo(poner, b, fase_brazos, alza, 1.0, Tono.BRAZO_T, Tono.PUNO_T)

	return piezas


# UN BRAZO: cadena de segmentos que sale del hombro y acaba en la manaza.
#
# EL ANGULO ES LO QUE MANDA, no un desplazamiento. Un brazo que tiene que llegar desde colgando a
# POR ENCIMA DE LA CABEZA no se puede mover empujando la punta -- la cadena se estira y se rompe en
# bolitas sueltas justo durante el ataque, que es cuando se mira. Girando el brazo entero alrededor
# del hombro, los segmentos mantienen SIEMPRE la misma separacion, mire donde mire.
#
# 'fase' es el balanceo de andar (adelante y atras) y 'alza' va de 0 (colgando) a 1 (por encima de
# la cabeza); negativo lo descuelga aun mas, que es lo que hace al morirse.
static func _brazo(poner: Callable, b: Dictionary, fase: float, alza: float,
		esc_detras: float, tono: int, tono_puno: int) -> void:
	var lado: float = float(b["lado"])
	var h0: Vector3 = b["hombro"]
	# Nace por DEBAJO del centro del hombro, para que el bulto asome por encima (ver BRAZO_BAJA).
	var hombro := Vector3(h0.x, h0.y, h0.z - BRAZO_BAJA)
	var th: float = lerpf(BRAZO_ANG_REPOSO, BRAZO_ANG_ALTO, clampf(alza, -0.25, 1.0))
	# EL CODO: cuanto se va abriendo el brazo hacia delante segun baja. Se ANULA al alzar los puños
	# (un machacazo se descarga con el brazo estirado, no doblado), y por eso multiplica por (1-alza).
	var codo: float = BRAZO_CODO * clampf(1.0 - alza, 0.0, 1.0)

	# LA CADENA SE CONSTRUYE PASO A PASO, cada tramo en la direccion que le toca, y NO como puntos de
	# una circunferencia alrededor del hombro. Es la unica forma de CURVAR el brazo sin romperlo: con
	# puntos sobre un arco, cambiar la curvatura cambia la distancia entre puntos y la cadena se
	# descose (la vieja regla del paso menor que el grosor, disparada por un cambio que no parece
	# tocar longitudes -- ver el ciempies). Avanzando un paso UNITARIO cada vez, la separacion es
	# exactamente BRAZO_PASO se doble el brazo como se doble.
	var eje: Vector3 = hombro          # el hueso, sin el ensanche ni el balanceo
	var ultimo: Vector3 = hombro       # y las dos ultimas bolas DIBUJADAS, para orientar la mano
	var penultimo: Vector3 = hombro
	for k in BRAZO_SEGMENTOS:
		var f: float = float(k) / float(BRAZO_SEGMENTOS - 1)
		if k > 0:
			# El angulo del tramo: 'th' en el hombro y abriendose hacia delante hacia la muñeca.
			# 0 = a plomo, PI/2 = hacia delante, 2,75 = por encima de la cabeza.
			var a: float = th + codo * pow(f, 1.3)
			var d := Vector3(lado * BRAZO_ABRE, sin(a) * BRAZO_ADELANTA, -cos(a)).normalized()
			eje += d * BRAZO_PASO
		# El balanceo de andar mueve la punta hacia delante y atras, y crece hacia la mano: el hombro
		# apenas se mueve, como en un brazo de verdad.
		var p := Vector3(eje.x + lado * BRAZO_SEPARA * f, eje.y + fase * f * 2.2, eje.z)
		var r: float = lerpf(BRAZO_R0, BRAZO_R1, f) * esc_detras
		poner.call(p, Vector3(r, r, r), tono)
		penultimo = ultimo
		ultimo = p

	# LA MANAZA, al final de la cadena y en SU MISMA DIRECCION, metida varias celdas dentro del
	# ultimo segmento (un solape de una celda no es un solape).
	#
	# La direccion sale del ultimo tramo YA DIBUJADO y no de 'th': asi la mano sigue al brazo aunque
	# el balanceo de andar lo haya desviado, y no hay dos cuentas que puedan desincronizarse.
	var pr: Vector3 = PUNO_R * float(b["puno"]) * esc_detras
	var d: Vector3 = ultimo - penultimo
	d = d.normalized() if d.length() > 0.01 else Vector3(0, 0, -1)
	var mano: Vector3 = ultimo + d * (pr.z * 0.42)
	poner.call(mano, pr, tono_puno)
	# NUDILLOS: tres hendiduras en el DORSO del puño, o sea en el lado hacia el que apunta el brazo.
	# Sin ellas el puño es una bola y podria ser cualquier cosa.
	#
	# 'solo_sobre' EL PROPIO PUÑO: es lo que las convierte en hendiduras en vez de en un boquete. Sin
	# contenerlas asomaban por el filo de la mano y las tres se fundian en una mancha -- el puño
	# parecia mordido. Es el mismo recurso con el que el escarabajo mete su brillo en el lomo sin que
	# se derrame por el costado.
	#
	# Van en ARCO y no en fila recta: una fila de piezas alineada con un eje se apila vista de frente
	# y sale como UNA RAYA, que es lo que le paso a las cerdas del jabali.
	# Se reparten a lo ANCHO del puño (eje X) y con una CEJA en altura, no en linea recta: en las
	# direcciones de perfil el eje X apunta a la camara y tres piezas en fila sobre el se apilarian
	# en una sola mancha. Es la leccion de las cerdas del jabali.
	for k in NUDILLOS:
		var t: float = -1.0 + 2.0 * float(k) / float(NUDILLOS - 1)
		poner.call(mano + d * (pr.z * 0.26)
				+ Vector3(lado * pr.x * 0.44 * t, 0.0, pr.z * (0.24 - 0.30 * t * t)),
			Vector3.ONE * NUDILLO_R * esc_detras, tono, [tono_puno])


# UNA GRIETA: cadena de trozos cada vez menores bajando en diagonal, con el barro cocido dentro.
# Una raya recta parece una junta; serpenteando y adelgazando parece que la arcilla se ha partido.
#
# 'arriba' YA VIENE GIRADO Y COMPENSADO por quien llama (ver el anclaje en _piezas), asi que todo lo
# de aqui va con gira = false: volver a girarlo desharia la compensacion que mantiene la grieta a la
# altura del pecho.
#
# 'sentido' es hacia que lado se desvia (y su magnitud, para que las dos grietas no sean gemelas).
static func _grieta(poner: Callable, arriba: Vector3, sentido: float, encendido: bool) -> void:
	for k in GRIETA_TROZOS:
		var f: float = float(k) / float(GRIETA_TROZOS - 1)
		var r: float = lerpf(GRIETA_R0, GRIETA_R1, f)
		var p := Vector3(
			arriba.x + sentido * GRIETA_ABRE * sin(f * 3.1),
			arriba.y,
			arriba.z - GRIETA_BAJA * float(k))
		poner.call(p, Vector3(r, r, r), Tono.GRIETA_T, [], false)
		# EL COCIDO VA DESPUES Y MAS PEQUEÑO: se pinta DENTRO del tajo, asi que la grieta le queda
		# como un reborde oscuro por los cuatro lados. Pintado antes, el tajo lo taparia entero.
		# Y solo en los dos primeros trozos: hacia la punta la grieta es demasiado fina para que
		# quepa nada dentro (regla de los tres pixeles) y el naranja saldria como una mota suelta.
		if k < 2:
			poner.call(Vector3(p.x, p.y - r * 0.35, p.z), Vector3(r, r, r) * 0.48,
				Tono.COCIDO if encendido else Tono.APAGADO, [Tono.GRIETA_T], false)


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
		# ang = 0: ninguna pieza del golem gira su FORMA (son todas redondas en planta); lo que gira
		# es DONDE se ponen. Y sin giro, 'elipse' coge su ruta rapida por filas.
		SpriteLienzo.elipse(plant, lz.x, lz.y, pos.x, pos.y, r.x, r.y, int(p["tono"]),
			0.0, p["solo_sobre"], float(p["persp"]))

	# CONTORNO al final, sobre la silueta ya completa (ver SpriteLienzo.contornear).
	SpriteLienzo.contornear(plant, SpriteLienzo.caja_de_piezas(piezas, lz.x, lz.y), lz.x, lz.y,
		Tono.BORDE, Tono.VACIO, Tono.SOMBRA_SUELO)
	return plant
