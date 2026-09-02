# ============================================================
#  arana_sprites.gd  (class_name AranaSprites)
#  La ARAÑA DE LAS SIMAS (piso 7-10) dibujada por codigo. Solo geometria: el motor y sus
#  herramientas viven en SpriteLienzo, y quien decide que a esta ficha le toca este generador es
#  SpritesEnemigo (por NOMBRE, ver GENERADORES_POR_NOMBRE: los tres insectos comparten familia y
#  no se parecen en nada).
#
#  LA SILUETA DE UNA ARAÑA SON LAS PATAS, NO EL CUERPO. Dibujada a ras del suelo es una mancha
#  ovalada como cualquier otra; lo que la hace araña son ocho patas que salen a los lados y
#  ARQUEAN POR ENCIMA DEL LOMO antes de bajar al suelo. Por eso la rodilla va mas alta que el
#  abdomen, que es lo mas alto del bicho.
#
#  Patron de dibujo: el de la RATA / el JABALI -- el cuerpo entero gira con la direccion (una araña
#  tiene morro y grupa), a diferencia del slime y el trent, que son redondos en planta.
#
#  MUERE ENCOGIENDOSE, no volcando. Una araña muerta cierra las patas sobre el vientre; no hay que
#  tumbarla de costado como al jabali, y por eso este generador no tiene 'tumba' ni el reordenado
#  de piezas que la acompaña. El cadaver es esa bola de patas dobladas, que se lee desde los ocho
#  lados sin depender de por donde cayo.
# ============================================================

extends RefCounted
class_name AranaSprites

const FRAMES := 8

# --- La araña mirando al SUR, en unidades de MUNDO (origen = donde toca el suelo, +Y hacia los
# quelieros, +Z hacia arriba). Es lo que mide CON LAS PATAS ESTIRADAS, que en este bicho es casi el
# doble que el cuerpo: sirve para el lienzo, no para la colision (ver tam_cuerpo). ---
const LARGO_MUNDO := 44.0

# CUERPO EN DOS PIEZAS, que es lo que distingue a una araña de un escarabajo: el cefalotorax
# (delante, bajo, es donde se clavan las OCHO patas y la cara) y el abdomen (detras, gordo y ALTO).
# Entre los dos un pediculo estrecho: sin el se leen como un solo bulto y se pierde la cintura.
const CEFALO := Vector3(0.0, 4.2, 5.2)
const CEFALO_R := Vector3(5.0, 5.0, 3.8)
const ABDOMEN := Vector3(0.0, -5.0, 6.4)
const ABDOMEN_R := Vector3(6.0, 6.4, 5.4)
const PEDICULO := Vector3(0.0, -0.2, 5.0)
const PEDICULO_R := Vector3(2.1, 1.8, 1.9)

# PATAS: cuatro pares clavados en los costados del CEFALOTORAX (ahi van las ocho de verdad; en el
# abdomen no va ninguna). Cada una es una cadena de bolitas en dos tramos -- femur que sube hasta la
# rodilla y tibia que baja al suelo --, como los colmillos del jabali: una elipse alargada no se
# curva, y una pata recta no se lee como pata de araña.
const PATA_ANCLA_X := 4.0
const PATA_ANCLA_Z := 5.0
# Donde se clava cada par a lo largo del cefalotorax, de delante a atras.
const PATA_ANCLA_Y := [7.4, 4.6, 1.8, -1.0]
# Cuanto ABRE cada pata hacia delante/atras (la punta, respecto de su anclaje): las delanteras van
# tendidas al frente y las traseras muy atras. Todas iguales = un peine, no una araña.
const PATA_ABRE := [8.5, 3.0, -3.0, -9.0]
# Y cuanto se aparta del cuerpo. Las de en medio son las mas largas, como en el bicho de verdad.
#
# LARGAS DE VERDAD, y esto fue lo primero que hubo que corregir mirando la hoja de contacto: con un
# alcance de 8 las puntas apenas asomaban dos unidades por fuera del abdomen y la araña salia como
# un bulto con pinchos. Una araña tiene una envergadura de dos o tres veces su cuerpo, y esa
# desproporcion ES el bicho: el cuerpo se lee pequeño y colgado en medio de una jaula de patas.
const PATA_ALCANCE := [13.0, 14.5, 14.5, 13.0]
# LA RODILLA, MAS ALTA QUE EL ABDOMEN (que sube a 11.8): es lo que hace el arco. Puesta a la altura
# del lomo, las patas salen en aspa desde el costado y el bicho se lee como una estrella plana.
const PATA_RODILLA_Z := 14.5
const PATA_RODILLA_F := 0.52       # que fraccion del alcance lleva recorrida la pata en la rodilla

# CUANTO ABOMBA CADA TRAMO. Los dos tramos no son rectos: se dibujan como una curva que se aparta
# del cuerpo y sube. Sin esto las patas salen como ALAMBRES TIESOS -- y peor, la pata que apunta a
# la camara se proyecta como una raya vertical debajo del bicho, que no se lee como pata sino como
# un hilo tirado. Una pata de araña es un arco, y el arco tiene que estar en las dos mitades.
const FEMUR_PANZA := Vector3(1.4, 0.0, 2.0)      # (hacia fuera, -, hacia arriba)
const TIBIA_PANZA := Vector3(3.0, 0.0, 2.8)

# EL PASO DE LA CADENA TIENE QUE SER MENOR QUE SU GROSOR o la pata sale a trozos sueltos (le paso a
# la cola de la rata y a los brazos del trent). AL TOCAR LAS LONGITUDES HAY QUE REHACER LA CUENTA, y
# aqui se rehizo DOS VECES: al alargar las patas (5 y 9 segmentos daban pasos de 3,07 y 2,13) y otra
# vez AL CURVARLAS -- una curva es mas larga que la recta que une sus extremos, asi que el mismo
# numero de bolitas se estira, y las patas salieron punteadas en perfil.
#
# OJO: EL HORNO NO AVISA DE ESTO. Su comprobacion de trozos sueltos solo mira 'muerte' y 'cadaver'
# (ANIMS_DE_UNA_PIEZA), asi que una pata rota andando no la canta nadie -- se ve mirando la hoja de
# contacto y de ninguna otra manera.
const FEMUR_SEGMENTOS := 9
const TIBIA_SEGMENTOS := 15
const FEMUR_R0 := 1.50
const FEMUR_R1 := 1.20
const TIBIA_R0 := 1.20
const TIBIA_R1 := 1.00

# ANDAR: cuanto barre la punta hacia delante y atras, y cuanto la levanta del suelo en el aire.
const PASO_LARGO := 4.6
const PASO_ALTO := 3.0

# QUELICEROS: los dos ganchos del veneno, colgando bajo la cara y curvandose hacia dentro. Cadena
# corta, y la punta en tono claro -- es lo que dice que este bicho envenena.
const QUELICERO := Vector3(1.9, 8.4, 4.6)
const QUELICERO_SEGMENTOS := 4
const QUELICERO_R0 := 1.25
const QUELICERO_R1 := 0.70

# OJOS: tres pares en la frente del cefalotorax, la fila de arriba mas pequeña. No son dos: una
# araña se reconoce por el RACIMO de ojos, y con dos se lee como un roedor.
#
# VAN ARRIBA DEL TODO, por encima del techo del cefalotorax (que llega a 9.0), y esto hubo que
# corregirlo mirando: puestos a media altura, con la camara a 45 grados caian en pantalla
# EXACTAMENTE encima de los quelieros -- (y - z) sale casi igual para los dos -- y las dos cosas se
# fundian en una sola mancha amarilla. La araña no tenia ojos, tenia boca.
const OJO_Z := 9.8
# Y APRETADOS: los tres de un lado tienen que formar UN grupo compacto, con el hueco del centro
# separando el de la izquierda del de la derecha. Repartidos a lo ancho de la frente, el racimo daba
# la vuelta al costado de la cabeza y de perfil se leia como una banda, no como una mirada.
const OJOS := [
	Vector3(1.5, 7.4, 0.3),        # x, y, desplazamiento en z respecto de OJO_Z
	Vector3(2.7, 7.0, -0.4),
	Vector3(2.0, 7.2, -1.5),
]
const OJO_R := [1.00, 0.85, 0.70]

# LA MARCA DEL LOMO: la mancha clara del abdomen. Un abdomen liso de un solo tono se lee como una
# piedra; la marca es lo que dice "bicho". Va en el eje y en dos trozos, como un reloj de arena.
const MARCA_A := Vector3(0.0, -3.0, 10.6)
const MARCA_A_R := Vector3(1.9, 2.2, 1.4)
const MARCA_B := Vector3(0.0, -7.6, 10.2)
const MARCA_B_R := Vector3(2.6, 2.6, 1.4)

# ALZARSE sobre las traseras para atacar: giro del cuerpo entero en el plano largo-alto, alrededor
# de un pivote metido en el abdomen (que es lo que se queda apoyado).
const ALZA_MAX := 0.62             # radianes a alza = 1.0
const PIVOTE_Y := -5.0
const PIVOTE_Z := 4.0

const LUNGE_DIST := 8.0            # cuanto viaja en la embestida, en unidades de mundo
# ENCAJAR UN GOLPE: que FRACCION de su embestida la empuja hacia atras el impacto. ALTA -- al reves
# que el jabali: una araña pesa poco y de un mandoble sale despedida, y eso es informacion (dice que
# es un bicho que se mata rapido si le llegas).
const ENCAJE_RETRO := 0.55

# Lienzo CUADRADO y holgado: el bicho gira, asi que manda su DIAGONAL (que con las patas abiertas es
# casi todo lo que mide), y ademas la embestida lo desplaza. Un lienzo generoso no engorda el atlas
# (montar_frames recorta cada fotograma), asi que se empieza por arriba.
#
# El factor esta MEDIDO, no calculado, contra los avisos del horno: al girar en diagonal la
# envergadura de las patas va por la diagonal del cuadro, y encima el salto de la embestida la
# desplaza ocho unidades mas. Es bajo porque LARGO_MUNDO ya cuenta las patas abiertas.
const LIENZO_FACTOR := 1.55

# TONOS propios (el motor no sabe que es cada uno; solo mapea indice -> color, ver _colores).
enum Tono { VACIO, SOMBRA_SUELO, BORDE, PATA, SOMBRA, BASE, LOMO, MARCA, QUELICERO, PONZONA, OJO_T }

# --- Vectores de las 8 direcciones (pantalla: +Y es hacia ABAJO). Mismo orden que los demas
# generadores y que el dir8 de SpriteLienzo: 0=S 1=SE 2=E 3=NE 4=N 5=NW 6=W 7=SW. ---
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
	return "arana_%s_%.2f" % [col.to_html(false), esc]


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(escala: float = 1.0) -> int:
	return _celdas(escala)


static func dimensiona_por_escala() -> bool:
	return true


# El CUERPO en planta (ancho, largo) para la colision. LAS PATAS NO CUENTAN, igual que no cuenta la
# cola de la rata: son ocho hilos que se mueven, y con ellas la araña mediria 39 unidades de lado --
# mas que el vano de 32 de un pasillo -- y se quedaria trabada en cuanto girase. Lo que estorba de
# una araña es el bulto del cuerpo; lo demas pasa por encima de las cosas.
static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	var ancho: float = maxf(ABDOMEN_R.x, PATA_ANCLA_X + FEMUR_R0) * 2.0
	var largo: float = (CEFALO.y + CEFALO_R.y) - (ABDOMEN.y - ABDOMEN_R.y)
	return Vector2(ancho, largo) * escala


static func _celdas(escala: float) -> int:
	var lado: int = int(ceil(LARGO_MUNDO * escala * LIENZO_FACTOR / SpriteLienzo.UNIDADES_POR_CELDA))
	return lado + (lado % 2)      # par, para que el centro caiga limpio


static func generar(color: Color = Color(0.30, 0.25, 0.40), escala: float = 1.0) -> SpriteFrames:
	# cuantizar_hsv y no cuantizar a secas: el morado ceniza es un color apagado y redondear canal a
	# canal le cambia el TONO -- dos canales parecidos caen en el mismo escalon y sale un gris. Le
	# paso al Rey rata (verde oliva) y al jabali (gris de raton).
	var col: Color = SpriteLienzo.cuantizar_hsv(color, COLOR_PASOS)
	var esc: float = snappedf(escala, 0.05)      # se cuantiza tambien, o el cache no acierta
	var clave: String = _clave(col, esc)
	if _cache.has(clave):
		return _cache[clave]
	var anims: Array = []
	_montar_idle(anims, esc)
	_montar_walk(anims, esc)
	_montar_embestida(anims, esc)
	_montar_telarana(anims, esc)
	_montar_encaje(anims, esc)
	_montar_muerte(anims, esc)
	_montar_cadaver(anims, esc)
	var lado: int = _celdas(esc)
	var sf: SpriteFrames = SpriteLienzo.montar_frames(
		anims, SpriteLienzo.paleta(_colores(col)), lado, lado)
	_cache[clave] = sf
	return sf


# Quieta: acecha. Casi no se mueve -- una araña al acecho esta CLAVADA, y ese quietismo es su
# caracter -- pero las patas tantean un poco y el abdomen sube y baja. Lento (3 fps) a proposito.
static func _montar_idle(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return {"avance": 0.0, "estira": 1.0, "fase": t, "paso": 0.16,
			"agacha": 0.04 * (1.0 - cos(TAU * t)), "alza": 0.0, "encoge": 0.0}
	_montar_animacion(anims, esc, "idle", true, 3.0, pose, false)


# Andando: a 11 fps, el mas rapido del juego. Una araña no trota, va a TIRONES -- y el cuerpo apenas
# sube y baja porque lo que se mueve son las patas, no el bicho. Las cuatro de un tetrapodo van a la
# vez y las otras cuatro en contrafase (ver el desfase por pata en _piezas).
static func _montar_walk(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return {"avance": 0.0, "estira": 1.0, "fase": t, "paso": 1.0,
			"agacha": 0.05 * (1.0 - cos(TAU * t * 2.0)), "alza": 0.0, "encoge": 0.0}
	_montar_animacion(anims, esc, "walk", true, 11.0, pose, false)


# SE ALZA sobre las traseras enseñando los quelieros -> se deja caer encima. Es lo que hace una
# araña y no se parece en nada a la carrera del jabali: no coge impulso, se ECHA ENCIMA. El avance
# llega tarde y de golpe, y el alzarse es todo el aviso.
# NO es periodica, asi que va por TRAMOS.
static func _montar_embestida(anims: Array, esc: float) -> void:
	var alza_keys := [[0.0, 0.0], [0.34, 1.0], [0.52, 0.95], [0.72, 0.10], [1.0, 0.0]]
	var avance_keys := [[0.0, 0.0], [0.34, -1.2], [0.52, 0.4], [0.72, 7.6], [0.86, 8.0], [1.0, 5.4]]
	var agacha_keys := [[0.0, 0.0], [0.34, 0.0], [0.72, 0.30], [1.0, 0.10]]
	var pose := func(t: float) -> Dictionary:
		return {"avance": SpriteLienzo.tramos(t, avance_keys) * (LUNGE_DIST / 8.0),
			"estira": 1.0, "fase": 0.0, "paso": 0.0,
			"agacha": SpriteLienzo.tramos(t, agacha_keys),
			"alza": SpriteLienzo.tramos(t, alza_keys), "encoge": 0.0}
	_montar_animacion(anims, esc, "embestida", false, 11.0, pose, true)


# LA TELARAÑA: se planta, bombea el abdomen y dispara. No pica -- teje.
#
# HASTA AHORA REPRODUCIA SU EMBESTIDA, que es "se ALZA sobre las traseras enseñando los queliceros y
# se echa encima": el gesto de MORDER, o sea justo el otro que tiene. Y ademas viajaba ocho unidades
# para lanzar algo que sale disparado solo.
#
# ES LO CONTRARIO DE ALZARSE: aqui BAJA el cuerpo (se agarra al suelo para tener de donde tirar) y lo
# que se mueve es el vientre. 'estira' escala el cuerpo a lo largo, asi que un tiron corto -- se
# comprime y se suelta en un fotograma -- se lee como el abdomen bombeando. Las patas delanteras
# levantan un pelin al final, que es como una araña remata el lance.
static func _montar_telarana(anims: Array, esc: float) -> void:
	# Se agacha y AHI SE QUEDA: el disparo no la mueve del sitio.
	var agacha_keys := [[0.0, 0.0], [0.143, 0.35], [0.286, 0.60], [0.429, 0.55], [0.571, 0.40],
		[0.714, 0.30], [0.857, 0.20], [1.0, 0.10]]
	# EL BOMBEO. Se comprime a lo largo y se suelta de golpe en el 0,429: ese salto es el disparo.
	var estira_keys := [[0.0, 1.0], [0.143, 0.94], [0.286, 0.86], [0.429, 1.14], [0.571, 1.06],
		[0.714, 0.98], [0.857, 1.0], [1.0, 1.0]]
	# Un tironcito de las delanteras al soltar, nada de alzarse (eso es el mordisco).
	var alza_keys := [[0.0, 0.0], [0.143, 0.0], [0.286, 0.08], [0.429, 0.30], [0.571, 0.22],
		[0.714, 0.10], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		return {"avance": 0.0,
			"estira": SpriteLienzo.tramos(t, estira_keys), "fase": 0.0, "paso": 0.0,
			"agacha": SpriteLienzo.tramos(t, agacha_keys),
			"alza": SpriteLienzo.tramos(t, alza_keys), "encoge": 0.0}
	# UNA SOLA DIRECCION: solo se ve en combate, y ahi se le mira de frente.
	_montar_animacion(anims, esc, "telarana", false, 12.0, pose, true, 1, FRAMES)


# MORIRSE. OCHO fotogramas en UNA sola direccion: la muerte solo se ve en la pantalla de combate, y
# ahi al bicho se le mira siempre de frente. Para el mapa esta 'cadaver', que es lo contrario.
#
# SE ENCOGE. Una araña muerta no se desploma de costado como el jabali: pierde la tension y las ocho
# patas se cierran sobre el vientre hasta quedar hecha un ovillo. Es la muerte mas reconocible que
# tiene un bicho en todo el juego, y ademas se lee igual desde los ocho lados -- por eso el cadaver
# del mapa no necesita saber por donde cayo.
#
# Va con un ULTIMO ESPASMO (el 0.72 vuelve a abrir un poco) antes de cerrarse del todo: sin el, el
# encogerse sale como una interpolacion suave y parece que se guarda las patas a proposito.
static func _pose_muerte(t: float) -> Dictionary:
	var encoge_keys := [[0.0, 0.0], [0.16, 0.28], [0.38, 0.66], [0.56, 0.88],
		[0.72, 0.74], [0.86, 1.0], [1.0, 1.0]]
	# El cuerpo se viene abajo antes que las patas: primero cede, luego se cierra.
	var agacha_keys := [[0.0, 0.0], [0.16, 0.45], [0.38, 0.85], [0.56, 1.0], [1.0, 1.0]]
	# Y da un tiron hacia arriba al empezar, que es el ultimo intento de sostenerse.
	var alza_keys := [[0.0, 0.0], [0.16, 0.34], [0.38, 0.06], [1.0, 0.0]]
	return {"avance": 0.0, "estira": 1.0, "fase": 0.0, "paso": 0.0,
		"agacha": SpriteLienzo.tramos(t, agacha_keys),
		"alza": SpriteLienzo.tramos(t, alza_keys),
		"encoge": SpriteLienzo.tramos(t, encoge_keys)}


static func _montar_muerte(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return _pose_muerte(t)
	_montar_animacion(anims, esc, "muerte", false, 10.0, pose, true, 1, 8)


# EL CADAVER DEL MAPA: UN fotograma por CADA UNA de las ocho direcciones, que es justo al reves que
# 'muerte' (ocho fotogramas en una sola). En combate al bicho se le ve morir de frente y una vez; en
# el mapa no se le ve morir -- se entra a la sala y ya esta tirado --, pero puede haber caido
# mirando a cualquier lado.
#
# Es EXACTAMENTE la pose final de la muerte, sacada de la misma funcion: reescribir los numeros aqui
# es garantizar que el dia que se retoque la muerte el cadaver se quede como estaba y el bicho pegue
# un salto al pasar de una a otro.
static func _montar_cadaver(anims: Array, esc: float) -> void:
	var pose := func(_t: float) -> Dictionary:
		return _pose_muerte(1.0)
	# ultimo_incluido = false y NO true: con un solo marco, el divisor de _montar_animacion seria
	# (1 - 1) = 0 y el reparto de t saldria NaN. La pose se pide fija, asi que da igual.
	_montar_animacion(anims, esc, "cadaver", false, 1.0, pose, false, 8, 1)


# ENCAJAR UN GOLPE. Cuatro fotogramas en UNA sola direccion (en combate se le ve siempre de frente)
# y EMPEZANDO YA GOLPEADA: el frame 0 es el impacto, no la pose de reposo. Un golpe no tiene
# anticipacion, y con cuatro marcos un fotograma de espera se comeria la animacion entera.
#
# SALE DESPEDIDA, al reves que el jabali: pesa poco. Y las patas se recogen a medias en el momento
# del impacto (un cuarto de 'encoge'), que es el respingo de un bicho de patas largas.
static func _montar_encaje(anims: Array, esc: float) -> void:
	var retro_keys := [[0.0, 1.0], [0.34, 0.42], [0.67, 0.10], [1.0, 0.0]]
	var agacha_keys := [[0.0, 0.70], [0.34, 0.10], [0.67, 0.02], [1.0, 0.0]]
	var encoge_keys := [[0.0, 0.26], [0.34, 0.12], [0.67, 0.03], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		return {"avance": -SpriteLienzo.tramos(t, retro_keys) * (LUNGE_DIST * ENCAJE_RETRO),
			"estira": 1.0, "fase": 0.0, "paso": 0.0,
			"agacha": SpriteLienzo.tramos(t, agacha_keys), "alza": 0.0,
			"encoge": SpriteLienzo.tramos(t, encoge_keys)}
	# LOS BICHOS ENCAJAN A 18 fps: es la duracion que espera CombatFX.T_ENCAJE, y cuadrando las dos
	# el sprite va a su velocidad natural en vez de estirado por _pose_ajustar.
	_montar_animacion(anims, esc, "encaje", false, 18.0, pose, true, 1, 4)


static func _montar_animacion(anims: Array, esc: float, nombre: String,
		loop: bool, fps: float,
		pose_fn: Callable, ultimo_incluido: bool, dirs: int = 8, marcos: int = FRAMES) -> void:
	# 'dirs' y 'marcos' al final y con el valor de siempre: las animaciones normales no se enteran.
	# Estan para las que NO necesitan las ocho direcciones ni los ocho fotogramas -- morir son 8
	# marcos en UNA direccion, y el cadaver del mapa UN marco por direccion.
	var divisor: float = float(marcos - 1) if ultimo_incluido else float(marcos)
	for dir in dirs:
		var plantillas: Array = []
		for i in marcos:
			# La GEOMETRIA se cachea por (animacion, frame, direccion, escala) y NO por color: otra
			# araña de otro tono reusa estas plantillas y solo repinta. Es lo que evita que entrar a
			# un piso lleno de bichos congele el juego.
			var clave: String = "%s_%d_%d_%.2f" % [nombre, i, dir, esc]
			var plant: PackedByteArray = _cache_plantillas.get(clave, PackedByteArray())
			if plant.is_empty():
				plant = _plantilla(dir, pose_fn.call(float(i) / divisor), esc)
				_cache_plantillas[clave] = plant
			plantillas.append(plant)
		anims.append({"nombre": "%s_%d" % [nombre, dir], "loop": loop, "fps": fps,
			"plantillas": plantillas})


# El morado de la ficha es tan apagado que, cuantizado, se le va lo violeta y queda un gris azulado.
# Se le sube la saturacion para devolverle el tono sin tocar el color de la ficha (que lo usa el
# resto del juego: particulas, marcador de la barra de accion, tinte del mapa).
static func _saturado(color: Color) -> Color:
	var out := Color.from_hsv(color.h, minf(1.0, color.s * 1.30 + 0.12), color.v)
	out.a = color.a
	return out


# Los colores de cada Tono, EN EL ORDEN DEL ENUM (contrato con SpriteLienzo.paleta).
static func _colores(color: Color) -> Array:
	var c: Color = _saturado(color)
	return [
		Color(0, 0, 0, 0),                    # VACIO
		Color(0, 0, 0, 0.22),                 # SOMBRA_SUELO
		c.darkened(0.70),                     # BORDE
		# PATA: bastante mas oscura que el cuerpo. Ocho hilos del mismo tono que el bulto se
		# confunden con el sobre un suelo oscuro; oscuras, se leen como una jaula alrededor.
		c.darkened(0.52),                     # PATA
		c.darkened(0.28),                     # SOMBRA (el costado, en penumbra)
		c,                                    # BASE
		# El LOMO se aclara HACIA UN LILA FRIO, no hacia el blanco: 'lightened' desatura, y sobre un
		# morado ya apagado el resultado es un gris. Misma leccion que el ocre del jabali.
		c.lerp(Color(0.72, 0.66, 0.86), 0.42),                # LOMO
		c.lerp(Color(0.86, 0.82, 0.70), 0.62),                # MARCA (la mancha clara del abdomen)
		c.darkened(0.60),                     # QUELICERO (quitina oscura)
		# PONZONA y OJO_T tienen que ser DOS COSAS DISTINTAS a ojo. Con los dos en amarillo (y aun
		# separados en pantalla) la cara se leia como cuatro puntos iguales y no habia forma de saber
		# cual era la mirada. La punta del quelicero va en hueso apagado y los ojos en amarillo vivo:
		# gana la mirada, que es lo que tiene que decir hacia donde va el bicho.
		Color(0.80, 0.84, 0.68),              # PONZONA (la punta del quelicero)
		Color(0.98, 0.92, 0.42),              # OJO_T (el racimo de ojos, claro y bien visible)
	]


# ------------------------------------------------------------
#  GEOMETRIA
# ------------------------------------------------------------

# Un punto de la curva de un tramo de pata (bezier cuadratica: arranque, codo, final). El codo NO es
# un punto por el que pase la pata, es hacia donde tira -- la curva se queda a medio camino de el, y
# por eso las panzas de arriba parecen mas suaves de lo que dicen sus numeros.
static func _curva(a: Vector3, codo: Vector3, b: Vector3, f: float) -> Vector3:
	var g: float = 1.0 - f
	return a * (g * g) + codo * (2.0 * g * f) + b * (f * f)


# ALZARSE: gira un punto en el plano largo-alto alrededor del pivote del abdomen. Se aplica al
# cuerpo Y a los anclajes de las patas (van clavadas en el cefalotorax, asi que suben con el), pero
# NO a las puntas de las traseras: son las que se quedan en el suelo sosteniendola.
static func _alzar(local: Vector3, a: float) -> Vector3:
	if a == 0.0:
		return local
	var dy: float = local.y - PIVOTE_Y
	var dz: float = local.z - PIVOTE_Z
	var ca: float = cos(a)
	var sa: float = sin(a)
	return Vector3(local.x, PIVOTE_Y + dy * ca - dz * sa, PIVOTE_Z + dy * sa + dz * ca)


# Las PIEZAS de la araña para una pose, ya proyectadas a pantalla. El orden ES la profundidad: se
# pintan en ese orden y las ultimas tapan a las primeras.
#
# LAS PATAS SE REPARTEN A LOS DOS LADOS DEL CUERPO segun a donde apunten en PANTALLA: las que caen
# hacia la camara van DESPUES del cuerpo y las de detras ANTES. Pintandolas todas antes, de frente
# las cuatro delanteras desaparecian tras el cefalotorax justo cuando mas se ven; pintandolas todas
# despues, de espaldas se le cruzaban por encima del abdomen. Son ocho comprobaciones por frame, no
# ocho por celda: sale gratis.
static func _piezas(dir: int, pose: Dictionary, esc: float) -> Array:
	var ang: float = DIR_VECS[dir].angle() - DIR_VECS[0].angle()
	var u: float = esc / SpriteLienzo.UNIDADES_POR_CELDA    # unidades de mundo -> celdas
	var centro: float = float(_celdas(esc)) * 0.5
	var estira: float = float(pose["estira"])
	var agacha: float = float(pose["agacha"])
	var avance: float = float(pose["avance"])
	var fase: float = float(pose["fase"])
	var paso: float = float(pose["paso"])
	var alza: float = float(pose["alza"]) * ALZA_MAX
	var encoge: float = float(pose["encoge"])

	# Agachada = mas baja y un pelin mas ancha (se aplasta contra el suelo).
	var largo: float = estira
	var ancho: float = 1.0 + 0.05 * agacha
	var alto: float = 1.0 - 0.30 * agacha

	var detras: Array = []
	var cuerpo: Array = []
	var delante: Array = []

	# EL AVANCE SE ROTA UNA VEZ Y LO LLEVAN TODAS LAS PIEZAS POR IGUAL. Sumarlo a la Y local antes de
	# rotar solo funciona si TODAS giran; en cuanto una no lo hace se va disparada hacia el sur de la
	# pantalla mientras el resto del bicho sale hacia donde de verdad mira.
	var desp := Vector2(0.0, avance).rotated(ang)

	# local (x ancho, y largo, z altura, en unidades de mundo) -> celda de pantalla.
	#
	# EL ARRAY DESTINO VA COMO PARAMETRO y no como variable capturada: una lambda de GDScript captura
	# por VALOR, asi que reasignar 'destino' fuera de ella no cambiaria a donde escribe, y las patas
	# de delante acabarian todas en el mismo saco sin dar ningun error.
	var poner := func(dest: Array, local: Vector3, r: Vector3, tono: int,
			solo_sobre: Array = [], en_suelo: bool = false) -> void:
		var p := Vector2(local.x * ancho, local.y * largo)
		var rot: Vector2 = p.rotated(ang) + desp
		var z: float = 0.0 if en_suelo else local.z * alto
		var sx: float = centro + rot.x * u
		var sy: float = centro + (rot.y * SpriteLienzo.COS_CAM - z * SpriteLienzo.SIN_CAM) * u
		var ry: float = r.y * largo
		# El aplastado va DESPUES de girar: lo hace SpriteLienzo.elipse con 'persp', y el valor lo da
		# persp_de a partir de los semiejes. Deformar el radio aqui y dejar que el motor rotara una
		# elipse ya achatada hacia que de perfil el cuerpo saliera mas CORTO de lo que mide.
		dest.append({"pos": Vector2(sx, sy), "radio": Vector2(r.x * ancho * u, ry * u),
			"gira_forma": true, "tono": tono, "ang": ang,
			"persp": 1.0 if en_suelo else SpriteLienzo.persp_de(ry, r.z * alto),
			"solo_sobre": solo_sobre})

	# SOMBRA DE CONTACTO, lo primero (va debajo). A ALTURA CERO: acompaña al bicho por el suelo
	# cuando se lanza, pero no sube con el, y esa separacion es lo que se lee como estar en el aire.
	poner.call(detras, Vector3(0.0, ABDOMEN.y * 0.4, 0.0),
		Vector3(ABDOMEN_R.x * 1.02, (ABDOMEN_R.y + CEFALO_R.y) * 0.92, 0.0),
		Tono.SOMBRA_SUELO, [], true)

	# --- LAS OCHO PATAS ---
	for s in 2:
		var lado: float = -1.0 if s == 0 else 1.0
		for k in PATA_ANCLA_Y.size():
			# TETRAPODO ALTERNO: las patas 0 y 2 de un costado van con las 1 y 3 del otro. Es como
			# anda el bicho de verdad, y ademas es lo unico que impide que las ocho toquen el suelo a
			# la vez y la araña parezca patinar.
			var desfase: float = 0.0 if (k + s) % 2 == 0 else 0.5
			var giro: float = TAU * (fase + desfase)
			var vaiven: float = sin(giro) * paso * PASO_LARGO
			var levanta: float = maxf(0.0, cos(giro)) * paso * PASO_ALTO

			var ancla := _alzar(Vector3(lado * PATA_ANCLA_X, PATA_ANCLA_Y[k], PATA_ANCLA_Z), alza)
			var alcance: float = PATA_ALCANCE[k]
			var punta := Vector3(lado * (PATA_ANCLA_X + alcance),
				PATA_ANCLA_Y[k] + PATA_ABRE[k] + vaiven, levanta)
			var rodilla := Vector3(lado * (PATA_ANCLA_X + alcance * PATA_RODILLA_F),
				lerpf(ancla.y, punta.y, 0.45), PATA_RODILLA_Z)
			# LAS DOS DELANTERAS SE DESPEGAN DEL SUELO AL ALZARSE; las traseras la sostienen y por eso
			# su punta no lleva '_alzar' ni sube. Si suben las ocho, la araña levita.
			if alza != 0.0 and k <= 1:
				punta = _alzar(punta, alza)
				punta.z += alza * 6.0
			rodilla = _alzar(rodilla, alza)

			# ENCOGERSE AL MORIR: las patas se doblan y se cierran POR ENCIMA del cuerpo. Es la pose
			# de bicho muerto que se reconoce de un vistazo -- la rodilla arriba y la punta caida
			# hacia dentro, como un puño cerrado.
			#
			# TIENEN QUE QUEDAR POR FUERA DE LA SILUETA DEL CUERPO. El primer intento las recogia
			# sobre el vientre (punta a 2,4 de ancho y 9,4 de alto) y ahi se metian ENTERAS dentro
			# del abdomen, que mide 6 de radio: la araña muerta salia como un bulto liso, sin una
			# sola pata a la vista. Muerta tiene que seguir pareciendo una araña.
			#
			# Y CADA UNA A SU SITIO, ESCALONADAS POR 'k'. Recogidas las cuatro al mismo punto (que fue
			# el segundo intento) se solapan en UNA mancha oscura a cada lado, y la araña muerta parece
			# envuelta en una capa. Separandolas en anchura, en altura y en el eje largo se leen las
			# cuatro patas dobladas, que es lo que tiene que verse.
			if encoge > 0.0:
				punta = punta.lerp(Vector3(lado * (2.6 + k * 0.6),
					PATA_ANCLA_Y[k] * 0.35 + PATA_ABRE[k] * 0.30, 11.6 + k * 1.0), encoge)
				rodilla = rodilla.lerp(Vector3(lado * (5.8 + k * 1.2),
					PATA_ANCLA_Y[k] * 0.60 + PATA_ABRE[k] * 0.45, 15.2 + k * 1.1), encoge)

			# ¿VA DELANTE O DETRAS DEL CUERPO? Por donde cae la rodilla en PANTALLA una vez girada.
			# Encogida, las ocho quedan sobre el lomo, asi que van todas delante.
			var prof: float = Vector2(rodilla.x, rodilla.y).rotated(ang).y
			var dest: Array = delante if (prof > 0.0 or encoge > 0.5) else detras

			# Cada tramo, en curva. La panza se aparta HACIA EL LADO EN QUE ESTA LA PATA (por eso va
			# multiplicada por 'lado'): abombada siempre hacia el mismo sitio, las cuatro de un
			# costado se doblarian hacia dentro y la araña saldria con las patas cruzadas.
			var cod_f: Vector3 = ancla.lerp(rodilla, 0.5) + Vector3(
				lado * FEMUR_PANZA.x, 0.0, FEMUR_PANZA.z)
			var cod_t: Vector3 = rodilla.lerp(punta, 0.5) + Vector3(
				lado * TIBIA_PANZA.x, 0.0, TIBIA_PANZA.z)
			for j in FEMUR_SEGMENTOS:
				var f: float = float(j) / float(FEMUR_SEGMENTOS - 1)
				poner.call(dest, _curva(ancla, cod_f, rodilla, f),
					Vector3.ONE * lerpf(FEMUR_R0, FEMUR_R1, f), Tono.PATA)
			for j in TIBIA_SEGMENTOS:
				var f: float = float(j) / float(TIBIA_SEGMENTOS - 1)
				poner.call(dest, _curva(rodilla, cod_t, punta, f),
					Vector3.ONE * lerpf(TIBIA_R0, TIBIA_R1, f), Tono.PATA)

	# --- EL CUERPO ---
	# ABDOMEN primero (es lo de atras), luego el pediculo y el cefalotorax por encima.
	var abd: Vector3 = _alzar(ABDOMEN, alza)
	poner.call(cuerpo, abd, ABDOMEN_R, Tono.BASE)
	# LOMO iluminado del abdomen: mas alto que su eje (la luz viene de arriba), asi que en pantalla
	# queda desplazado hacia arriba y la mitad de abajo se queda en tono base = el costado en
	# penumbra. Solo sobre BASE, para no aclarar patas ni contorno.
	poner.call(cuerpo, _alzar(Vector3(0.0, ABDOMEN.y + 0.8, ABDOMEN.z + ABDOMEN_R.z * 0.60), alza),
		Vector3(ABDOMEN_R.x * 0.66, ABDOMEN_R.y * 0.72, ABDOMEN_R.z), Tono.LOMO, [Tono.BASE])
	# LA MARCA: dos manchas claras en el eje del abdomen, la de atras mas ancha. Va sobre el lomo Y
	# sobre la base, porque a media vuelta cae medio dentro y medio fuera de la zona iluminada.
	poner.call(cuerpo, _alzar(MARCA_A, alza), MARCA_A_R, Tono.MARCA, [Tono.BASE, Tono.LOMO])
	poner.call(cuerpo, _alzar(MARCA_B, alza), MARCA_B_R, Tono.MARCA, [Tono.BASE, Tono.LOMO])

	poner.call(cuerpo, _alzar(PEDICULO, alza), PEDICULO_R, Tono.SOMBRA)

	var cef: Vector3 = _alzar(CEFALO, alza)
	poner.call(cuerpo, cef, CEFALO_R, Tono.BASE)
	poner.call(cuerpo, _alzar(Vector3(0.0, CEFALO.y + 0.4, CEFALO.z + CEFALO_R.z * 0.62), alza),
		Vector3(CEFALO_R.x * 0.62, CEFALO_R.y * 0.70, CEFALO_R.z), Tono.LOMO, [Tono.BASE])

	# QUIEN LE VE LA CARA: de espaldas no se le ven ni los ojos ni los quelieros -- con la camara a
	# 45 grados un bicho que se aleja enseña la grupa, y eso es lo que hace que se lea de un vistazo
	# si viene o si huye. LOS DOS VAN EN LA MISMA LISTA: al jabali, dibujarle los colmillos siempre
	# le ponia dos puntos claros sobre la grupa que se leian como otra cara mirandote desde detras.
	# Muerta tampoco: el ovillo tapa la cara.
	var frente: float = DIR_VECS[dir].y
	var lados: Array = [-1.0, 1.0]
	if frente <= -0.5 or encoge > 0.5:
		lados = []
	elif frente < -0.2:
		lados = [signf(DIR_VECS[dir].x)]

	# QUELICEROS: cuelgan bajo la cara y se curvan hacia dentro y hacia delante. En cadena, como los
	# colmillos del jabali: una elipse alargada no se curva. La ULTIMA bolita va en tono ponzoña.
	for lado in lados:
		for j in QUELICERO_SEGMENTOS:
			var f: float = float(j) / float(QUELICERO_SEGMENTOS - 1)
			var q := _alzar(Vector3(lado * (QUELICERO.x - f * 0.9),
				QUELICERO.y + f * f * 1.6,          # se adelanta al bajar
				QUELICERO.z - f * 3.2), alza)       # y baja
			poner.call(delante, q, Vector3.ONE * lerpf(QUELICERO_R0, QUELICERO_R1, f),
				Tono.PONZONA if j == QUELICERO_SEGMENTOS - 1 else Tono.QUELICERO)

	# EL RACIMO DE OJOS: tres pares en la frente. Claros y grandecitos a proposito -- son lo unico
	# que dice hacia donde mira, y en la mazmorra el bicho se ve pequeño.
	for lado in lados:
		for j in OJOS.size():
			var o: Vector3 = OJOS[j]
			poner.call(delante, _alzar(Vector3(lado * o.x, o.y, OJO_Z + o.z), alza),
				Vector3.ONE * OJO_R[j], Tono.OJO_T)

	return detras + cuerpo + delante


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
