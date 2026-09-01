# ============================================================
#  bestia_acorazada_sprites.gd  (class_name BestiaAcorazadaSprites)
#  Sprite de la BESTIA ACORAZADA dibujada por codigo, con el motor comun (SpriteLienzo) y la camara
#  de 45 grados que comparten todos los bichos. Aparece del piso 8 en adelante.
#
#  ES UN ANIMAL, NO UN CONSTRUCTO, y eso es lo primero que hay que acertar. Su .tres dice
#  `familia = 4` (PIEDRA), la misma que el golem, la gargola y el coloso -- pero la familia es una
#  etiqueta de JUEGO (la usan las pasivas slayer), no de dibujo, y lo que suelta al morir lo deja
#  claro: CUERO endurecido, CARNE de bestia y un nucleo de BESTIA. Debajo del blindaje hay bicho.
#
#  Asi que se dibuja con el esqueleto de cuadrupedo (el del jabali y el acechador: el cuerpo ENTERO
#  gira con la direccion) y NO con el de los constructos. Lo que la separa de ellos, ademas de tener
#  cuatro patas: el VIENTRE y las patas van en un tono CALIDO -- carne a la vista -- mientras que el
#  caparazon va frio y oscuro. Un golem es del mismo barro por todas partes; esta lleva una coraza
#  ENCIMA de algo.
#
#  Y ES LA CONTRARIA DEL ACECHADOR EN LOS TRES EJES, que es como se distinguen dos cuadrupedos que
#  comparten esqueleto:
#    * el acechador es ALTO Y ESTRECHO de patas largas; esta es BAJA Y ANCHISIMA, casi tan ancha
#      como larga, con patas COLUMNARES y cortas. Es un ariete con patas.
#    * el acechador lleva la GRUPA alta y la cabeza colgando; esta va horizontal y con la cabeza A
#      RAS DE SUELO, que es desde donde embiste.
#    * el acechador esta PELADO y es casi negro; esta lleva PLACAS segmentadas y es parda rojiza.
#
#  Sus dos habilidades mandan sobre el dibujo: `bestia_carga` (CARGA, con carga_turnos = 1, o sea
#  que AVISA un turno antes) y `bestia_zarpazo`. Y `resist_aturdir` 0,4: a esto no lo mueves de un
#  mandoble, y su encaje tiene que contarlo.
#
#  El TAMAÑO se consigue con MAS CELDAS, no con celdas mas gordas: ver SpriteLienzo.UNIDADES_POR_CELDA.
# ============================================================

extends RefCounted
class_name BestiaAcorazadaSprites

const FRAMES := 8

# --- La bestia mirando al SUR, en unidades de MUNDO (origen = donde toca el suelo, +Y hacia el
# morro, +Z hacia arriba). A escala 1.0 mide unas 26 unidades del morro a la grupa. ---
const LARGO_MUNDO := 26.0

# --- EL TRONCO: bajo, ancho y de una pieza. 8,2 de semiancho contra 9,4 de semilargo -- casi tan
# ancha como larga, que es lo que la hace leer como una mole y no como un animal que corre.
#
# Y VA BAJO (z 7,6): entre el suelo y la panza cabe muy poco, justo al reves que el acechador. Lo
# que dice "esto pesa" es que no haya hueco debajo.
const TRONCO := Vector3(0.0, 0.0, 7.6)
const TRONCO_R := Vector3(8.2, 9.4, 5.2)
# Los CUARTOS: el delantero algo mas alto que la grupa (embiste con el pecho), pero muy poco. La
# linea del lomo es casi horizontal a proposito: ni la rampa que baja del jabali ni la que sube del
# acechador. Una coraza es plana.
const PECHO := Vector3(0.0, 6.6, 8.0)
const PECHO_R := Vector3(7.4, 5.2, 5.0)
const GRUPA := Vector3(0.0, -7.4, 7.2)
const GRUPA_R := Vector3(7.2, 4.8, 4.6)

# --- EL CAPARAZON: placas transversales que cruzan el lomo de lado a lado, de la nuca a la grupa.
# Van con SpriteLienzo.bloque y no con elipse: una placa es una PIEZA RECTA, y con elipses lo que
# sale es un lomo con bultos -- que es un jabali con joroba, no una coraza. (La primitiva la estreno
# el coloso para sus sillares.)
#
# Se dibujan sobre el lomo ya montado con 'solo_sobre', asi que no se derraman por los costados ni
# se comen el contorno.
const PLACAS := 6
const PLACA_Y0 := 7.4              # la de delante, sobre la nuca
const PLACA_Y1 := -8.2             # la de atras, sobre la grupa
const PLACA_R := Vector3(7.0, 1.15, 0.9)
const PLACA_CHAFLAN := 0.30
# Cuanto se estrecha la placa hacia los extremos: el caparazon sigue el contorno del bicho, y unas
# placas todas del mismo ancho salen como una escalera de mano tirada encima.
const PLACA_ESTRECHA := 0.58
# Y cuanto ASOMAN por encima del lomo. Con la camara a 45 grados hay que subir 1,41 unidades de
# mundo por cada una que se quiera ver asomar (es la nota de las cerdas del jabali).
const PLACA_ALZA := 1.5

# CABEZA: ANCHA, CHATA y A RAS DE SUELO -- mas baja que el lomo. Es su ariete, y va donde va un
# ariete: abajo y delante.
const CABEZA := Vector3(0.0, 13.2, 5.8)
const CABEZA_R := Vector3(4.8, 4.0, 3.4)
# EL TESTUZ: la placa frontal con la que embiste. Es la pieza que cuenta que su Carga hace 2,2 de
# daño en area. Va por delante y por debajo del eje de la cabeza: se embiste con la frente agachada.
const TESTUZ := Vector3(0.0, 16.6, 5.0)
const TESTUZ_R := Vector3(4.2, 1.5, 2.6)
const TESTUZ_CHAFLAN := 0.22
# PUAS del testuz: dos cortas y romas a los lados. No son cuernos de embestir (para eso esta la
# placa entera): son lo que hace que la placa se lea como parte del bicho y no como una tabla.
# Van POR FUERA del testuz (4,8 contra sus 4,2 de semiancho): dentro no eran puas, eran dos bultos
# del mismo color perdidos en la placa. Lo que hace una pua es romper la SILUETA.
const PUA := Vector3(4.8, 15.8, 6.6)
const PUA_R := Vector3(1.1, 1.5, 1.1)
# OJOS: pequeños y hundidos bajo el borde del testuz. En un bicho acorazado los ojos son una rendija,
# y ademas asi no compiten con las placas, que es lo que tiene que leerse primero.
# POR ENCIMA del testuz (z 8,2 contra el 7,6 al que llega la placa), no dentro. Puestos a 6,9 caian
# sobre la placa y de frente el bicho parecia una caja metalica con dos pilotos encendidos. Un ojo
# tiene que estar en la CARA, y la placa es lo que la cubre.
const OJO := Vector3(2.7, 14.8, 8.2)
const OJO_R := Vector3(0.7, 0.7, 0.6)

# --- LAS PATAS: COLUMNARES y cortas, de dos piezas nada mas (muslo y pezuña). Aqui no hay caña fina
# ni corvejon: eso es de un animal que corre, y este no corre, empuja.
#
# PATA_X (5,6) MUY POR DENTRO DEL SEMIANCHO DEL TRONCO (8,2): es la leccion que costo tres vueltas
# en el acechador -- una pata que nace en el borde de la elipse del cuerpo nace donde el cuerpo tiene
# grosor CERO, y flota por mucho que se engorde. Aqui el tronco conserva el 73% de su altura.
const PATA_X := 5.6
const PATA_Y := [5.8, -6.6]                     # delanteras y traseras
const MUSLO_R := Vector3(2.3, 2.6, 4.2)
const MUSLO_Z := 4.2
const PEZUNA_R := Vector3(2.5, 2.8, 1.1)
const PEZUNA_Z := 0.9
# Paso CORTO: agilidad 15 y velocidad 3,6. Anda como un buey.
const PASO_LARGO := 1.5

# COLA: un muñon acorazado, mas corto todavia que el del jabali. Un bicho con coraza no tiene de
# donde colgar una cola larga, y ademas competiria con las placas.
const COLA := Vector3(0.0, -11.4, 7.6)
const COLA_R := Vector3(1.6, 2.4, 1.5)

# LA CARGA: viaja poco para lo que pesa, pero avisa mucho. Su habilidad tiene carga_turnos = 1.
const LUNGE_DIST := 8.0
# ENCAJAR UN GOLPE: FRACCION de su carga que lo empuja hacia atras el impacto. LA MAS BAJA DEL JUEGO
# -- por debajo del 0,20 del jabali y del 0,16 del coloso --, porque su .tres dice resist_aturdir
# 0,4 y 55 de resistencia. Lo que se sacude es la CABEZA, no el cuerpo.
const ENCAJE_RETRO := 0.13

# Lienzo CUADRADO y holgado: el bicho gira, asi que lo que manda es su DIAGONAL, y ademas la carga lo
# desplaza. NO VUELCA al morir (ver _pose_muerte), asi que no necesita la holgura enorme que si
# necesitan el jabali o el acechador para tumbarse de largo.
const LIENZO_FACTOR := 2.05

# TONOS propios (el motor no sabe que es cada uno; solo mapea indice -> color, ver _colores).
enum Tono { VACIO, SOMBRA_SUELO, BORDE, PATA, CARNE, SOMBRA, BASE, PLACA_OSC, PLACA, PLACA_CLARA,
	PUA_T, OJO_T }

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
	return "bestia_acorazada_%s_%.2f" % [col.to_html(false), esc]


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(escala: float = 1.0) -> int:
	return _celdas(escala)


static func dimensiona_por_escala() -> bool:
	return true


# El CUERPO en planta (ancho, largo) para la colision. Aqui lo ancho NO lo marcan las patas como en
# los otros cuadrupedos: lo marca el TRONCO, que es mas ancho que ellas -- es un bicho que desborda
# sus propias patas. Sale casi cuadrado en planta (16,4 x 21,4), asi que enemy.gd NO le gira la
# colision: da igual por donde se le mire, ocupa lo mismo.
static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	var ancho: float = TRONCO_R.x * 2.0
	var largo: float = (TESTUZ.y + TESTUZ_R.y) - (GRUPA.y - GRUPA_R.y)
	return Vector2(ancho, largo) * escala


static func _celdas(escala: float) -> int:
	var lado: int = int(ceil(LARGO_MUNDO * escala * LIENZO_FACTOR / SpriteLienzo.UNIDADES_POR_CELDA))
	return lado + (lado % 2)      # par, para que el centro caiga limpio


static func generar(color: Color = Color(0.5, 0.3, 0.25), escala: float = 1.0) -> SpriteFrames:
	# cuantizar_hsv y no cuantizar a secas: redondear canal a canal le cambiaria el TONO a un color
	# apagado como este -- dos canales parecidos caen en el mismo escalon y sale un gris. Le paso lo
	# mismo al Rey rata en su dia.
	var col: Color = SpriteLienzo.cuantizar_hsv(color, COLOR_PASOS)
	var esc: float = snappedf(escala, 0.05)      # se cuantiza tambien, o el cache no acierta
	var clave: String = _clave(col, esc)
	if _cache.has(clave):
		return _cache[clave]
	# Todo en UN atlas recortado (ver SpriteLienzo.montar_frames).
	var anims: Array = []
	_montar_idle(anims, esc)
	_montar_walk(anims, esc)
	_montar_embestida(anims, esc)
	_montar_encaje(anims, esc)
	_montar_muerte(anims, esc)
	_montar_cadaver(anims, esc)
	var lado: int = _celdas(esc)
	var sf: SpriteFrames = SpriteLienzo.montar_frames(
		anims, SpriteLienzo.paleta(_colores(col)), lado, lado)
	_cache[clave] = sf
	return sf


# La pose de reposo, con TODAS las claves a cero. Existe para que cada _montar_* escriba solo lo suyo
# y no se le olvide ninguna: una clave que falta no da error en GDScript, se lee como 0.0 y el fallo
# sale a la cara en el dibujo, que es donde mas cuesta encontrarlo.
static func _reposo() -> Dictionary:
	return {"avance": 0.0, "estira": 1.0, "patas": 0.0, "agacha": 0.0, "cabeza": 0.0,
		"hunde": 0.0, "escarba": 0.0}


# Quieto: resuella. Muy lento -- tiene agilidad 15, la segunda mas baja del juego despues del coloso.
# Lo unico que se mueve es el fuelle del costado y la cabeza, un poco.
static func _montar_idle(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["estira"] = 1.0 + 0.018 * sin(TAU * t)
		p["cabeza"] = 0.30 * sin(TAU * t)
		return p
	_montar_animacion(anims, esc, "idle", true, 3.0, pose, false)


# Andando: paso corto y pesado, a 5 fps. Se BAMBOLEA -- 'hunde' baja un costado y luego el otro --,
# que es lo que hace un cuadrupedo ancho y bajo al andar y lo que mas lo diferencia del trote del
# acechador. Un bicho de este ancho no trota: se contonea.
static func _montar_walk(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["patas"] = sin(TAU * t)
		p["hunde"] = sin(TAU * t)
		p["agacha"] = 0.05 * (1.0 - cos(TAU * t * 2.0))
		p["cabeza"] = 0.5 * sin(TAU * t)
		return p
	_montar_animacion(anims, esc, "walk", true, 5.0, pose, false)


# PLANTARSE -> arrancar -> impacto -> frenar. NO es periodica, asi que va por TRAMOS.
#
# AVISA MUCHO Y ARRANCA TARDE, y eso es fiel a su habilidad: `bestia_carga` tiene carga_turnos = 1,
# o sea que el jugador la ve venir un turno entero antes. En el dibujo eso es una anticipacion larga:
# se hunde sobre las cuatro patas, baja el testuz, ESCARBA -- y solo entonces sale. Lo contrario del
# salto del acechador, que es un fogonazo.
static func _montar_embestida(anims: Array, esc: float) -> void:
	var avance_keys := [[0.0, 0.0], [0.38, -1.2], [0.66, 4.8], [0.82, 8.0], [1.0, 6.0]]
	var estira_keys := [[0.0, 1.0], [0.38, 0.94], [0.66, 1.06], [0.82, 0.96], [1.0, 1.0]]
	# 'agacha' baja el cuerpo Y la cabeza. En el tramo de carga va a tope: embiste con el testuz.
	var agacha_keys := [[0.0, 0.0], [0.38, 0.62], [0.66, 0.88], [0.82, 0.50], [1.0, 0.08]]
	# 'escarba': las patas delanteras raspan el suelo, solo durante el aviso.
	var escarba_keys := [[0.0, 0.0], [0.20, 1.0], [0.38, 0.25], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["avance"] = SpriteLienzo.tramos(t, avance_keys) * (LUNGE_DIST / 8.0)
		p["estira"] = SpriteLienzo.tramos(t, estira_keys)
		p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
		p["cabeza"] = -1.9 * SpriteLienzo.tramos(t, agacha_keys)
		p["escarba"] = SpriteLienzo.tramos(t, escarba_keys)
		return p
	_montar_animacion(anims, esc, "embestida", false, 9.0, pose, true)


# ENCAJAR UN GOLPE. Cuatro fotogramas en UNA sola direccion (en combate se le ve siempre de frente)
# y EMPEZANDO YA GOLPEADO: el frame 0 es el impacto, no la pose de reposo. Un golpe no tiene
# anticipacion, y con cuatro marcos un fotograma de espera se comeria la animacion entera.
#
# ES LA QUE MENOS SE MUEVE DE TODO EL JUEGO. Su .tres dice resist_aturdir 0,4 y resistencia 55: el
# cuerpo apenas acusa y lo unico que se sacude es la cabeza. Si esto encajara como el acechador, el
# dibujo estaria contradiciendo a sus numeros.
static func _montar_encaje(anims: Array, esc: float) -> void:
	# 'agacha' no pasa de 0,55: por encima de 1,0 la altura se vuelve negativa y las piezas dejan de
	# pintarse SIN DAR ERROR.
	var agacha_keys := [[0.0, 0.55], [0.34, 0.14], [0.67, 0.04], [1.0, 0.0]]
	var estira_keys := [[0.0, 0.92], [0.34, 1.05], [0.67, 0.98], [1.0, 1.0]]
	var retro_keys := [[0.0, 1.0], [0.34, 0.40], [0.67, 0.10], [1.0, 0.0]]
	# La cabeza SUBE de golpe: en la carga va hundida, y aqui es al reves -- se la levantan de un
	# tortazo. Es practicamente lo unico que se mueve.
	var cabeza_keys := [[0.0, 2.6], [0.34, -0.8], [0.67, 0.3], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["avance"] = -SpriteLienzo.tramos(t, retro_keys) * (LUNGE_DIST * ENCAJE_RETRO)
		p["estira"] = SpriteLienzo.tramos(t, estira_keys)
		p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
		p["cabeza"] = SpriteLienzo.tramos(t, cabeza_keys)
		return p
	# TODOS LOS BICHOS ENCAJAN A 18 fps: es la duracion que espera CombatFX.T_ENCAJE, y cuadrando las
	# dos el sprite va a su velocidad natural en vez de estirado por _pose_ajustar.
	_montar_animacion(anims, esc, "encaje", false, 18.0, pose, true, 1, 4)


# MORIRSE. OCHO fotogramas en UNA sola direccion: la muerte solo se ve en la pantalla de combate, y
# ahi al bicho se le mira siempre de frente. Para el mapa esta 'cadaver', que es lo contrario.
#
# SE DESPLOMA SOBRE EL VIENTRE, Y NO VUELCA DE COSTADO como el jabali y el acechador. No es pereza:
# es que no se leeria. Volcar cuenta algo cuando el bicho es mas alto que ancho -- entonces el
# costado que aparece es una silueta nueva --, y esta mide 16,4 de ancho por 10,4 de alto: tumbada
# se veria casi igual que de pie, solo que torcida. Es la misma razon por la que el coloso se hinca
# en vez de caer a lo largo.
#
# Lo que cuenta su muerte es que LAS PATAS CEDEN HACIA FUERA y la coraza baja hasta tocar el suelo:
# el blindaje que no la salvo, tirado en el barro. Y la cabeza se descuelga del todo.
static func _pose_muerte(t: float) -> Dictionary:
	# 'agacha' llega a 0,95 y no a 1,0: en 1,0 la altura se anula y las piezas dejan de pintarse.
	var agacha_keys := [[0.0, 0.10], [0.16, 0.45], [0.34, 0.72], [0.55, 0.88], [0.78, 0.95],
		[1.0, 0.95]]
	# Las patas se abren a los lados segun cede. 'patas' aqui no es el paso: es el despatarre.
	var abre_keys := [[0.0, 0.0], [0.16, 0.3], [0.34, 0.7], [0.55, 1.0], [1.0, 1.0]]
	var cabeza_keys := [[0.0, 0.0], [0.16, -0.8], [0.34, -1.8], [0.55, -2.6], [1.0, -3.0]]
	# Un ultimo estertor hacia delante antes de quedarse quieta.
	var avance_keys := [[0.0, 0.0], [0.16, 0.8], [0.34, 1.2], [0.55, 1.0], [1.0, 0.9]]
	var p: Dictionary = _reposo()
	p["agacha"] = SpriteLienzo.tramos(t, agacha_keys)
	p["cabeza"] = SpriteLienzo.tramos(t, cabeza_keys)
	p["avance"] = SpriteLienzo.tramos(t, avance_keys)
	p["abre"] = SpriteLienzo.tramos(t, abre_keys)
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
			# La GEOMETRIA se cachea por (animacion, frame, direccion, escala) y NO por color: otra
			# bestia de otro tono reusa estas plantillas y solo repinta. Es lo que evita que entrar a
			# un piso lleno de bichos congele el juego.
			var clave: String = "%s_%d_%d_%.2f" % [nombre, i, dir, esc]
			var plant: PackedByteArray = _cache_plantillas.get(clave, PackedByteArray())
			if plant.is_empty():
				plant = _plantilla(dir, pose_fn.call(float(i) / divisor), esc)
				_cache_plantillas[clave] = plant
			plantillas.append(plant)
		anims.append({"nombre": "%s_%d" % [nombre, dir], "loop": loop, "fps": fps,
			"plantillas": plantillas})


# Le sube un poco la saturacion para devolverle lo terroso sin cambiarle el color de la ficha (que lo
# usa el resto del juego: particulas, tinte por fuerza, marcador de la barra de accion).
static func _calido(color: Color) -> Color:
	var out := Color.from_hsv(color.h, minf(1.0, color.s * 1.20 + 0.08), color.v)
	out.a = color.a
	return out


# Los colores de cada Tono, EN EL ORDEN DEL ENUM (contrato con SpriteLienzo.paleta).
#
# AQUI ESTA LO QUE LA SEPARA DE LOS CONSTRUCTOS. El golem, la gargola y el coloso son de UN material
# de arriba abajo. Esta lleva DOS: una coraza FRIA y oscura por encima, y CARNE calida debajo. Que
# se vean los dos a la vez es lo que dice "animal blindado" en vez de "estatua".
static func _colores(color: Color) -> Array:
	var base: Color = _calido(color)
	# LA CORAZA VA MAS OSCURA QUE LA CARNE, y esto se vio mirando la tira: al primer intento estaba
	# mas CLARA y el bicho salia como un cerdo rosa con una reja blanca encima -- las placas se leian
	# como metal pulido, que es justo lo que no es. Un caparazon es cuerno curtido: oscuro, mate y
	# terroso. Con la coraza oscura y la carne clara, la lectura se ordena sola -- se ve primero la
	# silueta blindada y despues, por debajo, el bicho que hay dentro.
	#
	# Y NO SE PONE GRIS DEL TODO a proposito: gris es piedra, y piedra es justo lo que NO es (comparte
	# familia con el golem y el coloso, ver el comentario de sprites_enemigo.gd). Se queda en pardo
	# oscuro, con un puntito de frio nada mas.
	var coraza: Color = base.darkened(0.46).lerp(Color(0.30, 0.28, 0.29), 0.30)
	return [
		Color(0, 0, 0, 0),                    # VACIO
		Color(0, 0, 0, 0.22),                 # SOMBRA_SUELO
		coraza.darkened(0.55),                # BORDE
		base.darkened(0.42),                  # PATA (carne en penumbra, no coraza)
		# CARNE: el vientre y las patas. Es el tono MAS CALIDO de la paleta y el unico que no esta
		# apagado: es la pista de que debajo del blindaje hay bicho.
		base.lerp(Color(0.80, 0.48, 0.40), 0.38),   # CARNE
		base.darkened(0.30),                  # SOMBRA (el costado de la CARNE, en penumbra)
		base,                                 # BASE
		coraza.darkened(0.32),                # PLACA_OSC (la junta entre placas)
		coraza,                               # PLACA
		# El canto que da a la luz: SOLO UN PASO mas claro que la placa. Con mas contraste cada placa
		# se lee como una pieza suelta y el lomo sale como una escalera, no como un caparazon.
		coraza.lightened(0.20),               # PLACA_CLARA
		coraza.lightened(0.14),               # PUA_T
		Color(0.95, 0.80, 0.30),              # OJO_T (ambar, y pequeño: es una rendija)
	]


# ------------------------------------------------------------
#  GEOMETRIA
# ------------------------------------------------------------

# Las PIEZAS de la bestia para una pose, ya proyectadas a pantalla. El orden ES la profundidad: se
# pintan en ese orden y las ultimas tapan a las primeras, asi que va de lo mas bajo (sombra, patas)
# a lo mas alto y cercano (placas, testuz, ojos).
static func _piezas(dir: int, pose: Dictionary, esc: float) -> Array:
	var ang: float = DIR_VECS[dir].angle() - DIR_VECS[0].angle()
	var u: float = esc / SpriteLienzo.UNIDADES_POR_CELDA    # unidades de mundo -> celdas
	var centro: float = float(_celdas(esc)) * 0.5
	var estira: float = float(pose["estira"])
	var agacha: float = float(pose["agacha"])
	var avance: float = float(pose["avance"])
	var fase_patas: float = float(pose["patas"])
	var cabeza_y: float = float(pose["cabeza"])
	var hunde: float = float(pose["hunde"])
	var escarba: float = float(pose["escarba"])
	# 'abre' solo existe en la muerte (las patas cediendo hacia fuera), con default para que las
	# poses de siempre no paguen ni una operacion.
	var abre: float = float(pose.get("abre", 0.0))

	# Agazapada = mas baja y algo mas larga (se estira hacia delante al bajar el testuz).
	var largo: float = estira * (1.0 + 0.05 * agacha)
	var ancho: float = 1.0 / maxf(0.5, estira)
	var alto: float = 1.0 - 0.42 * agacha

	var piezas: Array = []
	# EL AVANCE SE ROTA UNA VEZ Y LO LLEVAN TODAS LAS PIEZAS POR IGUAL. Sumarlo a la Y local antes de
	# rotar solo funciona si TODAS giran; en cuanto una no lo hace, se va disparada hacia el sur de la
	# pantalla mientras el resto del bicho sale hacia donde de verdad mira.
	var desp := Vector2(0.0, avance).rotated(ang)
	var s_a: float = sin(ang)
	var c_a: float = cos(ang)

	# local (x ancho, y largo, z altura, en unidades de mundo) -> celda de pantalla.
	# 'caja' pinta la pieza con SpriteLienzo.bloque (rectangular, para las placas) en vez de elipse.
	# 'escorzo' < 1 comprime lo que la PROFUNDIDAD sube o baja esa pieza en pantalla.
	var poner := func(local: Vector3, r: Vector3, tono: int, solo_sobre: Array = [],
			caja: bool = false, chaflan: float = 0.0, en_suelo: bool = false) -> void:
		# EL BAMBOLEO: hunde un costado y levanta el otro. Va aqui y no en la altura de cada pieza
		# porque tiene que inclinar el bicho ENTERO alrededor de su eje largo -- si se aplicara solo
		# al tronco, las patas y la cabeza se quedarian a nivel y el bicho se partiria por la mitad.
		var lz: float = local.z + (0.0 if en_suelo else local.x * hunde * 0.055)
		var p := Vector2(local.x * ancho, local.y * largo)
		var rot: Vector2 = p.rotated(ang) + desp
		var z: float = lz * alto
		var sx: float = centro + rot.x * u
		var sy: float = centro + (rot.y * SpriteLienzo.COS_CAM - z * SpriteLienzo.SIN_CAM) * u
		var ry: float = r.y * largo
		var rxm: float = r.x * ancho
		# LA PERSPECTIVA SE MIDE SOBRE EL RADIO YA ROTADO. El motor aplasta el eje VERTICAL DE
		# PANTALLA por 'persp' DESPUES de girar la pieza, pero 'persp_de' recibe el radio a lo LARGO,
		# y los dos solo coinciden mirando al SUR: girado 90 grados, el que cae en vertical es el
		# radio a lo ANCHO. Sin esto las piezas pierden altura al girar y se sueltan del cuerpo en
		# siete de las ocho direcciones -- que es lo que le paso a las patas del acechador, y la
		# firma era justamente "mal en todas menos en S".
		var ry_rot: float = sqrt(rxm * rxm * s_a * s_a + ry * ry * c_a * c_a)
		# 'gira_forma' lo necesita SpriteLienzo.caja_de_piezas: sin el da por hecho que la pieza no
		# gira y calcula la caja del contorno con el radio equivocado, asi que el perfilado se cortaria
		# por donde la pieza girada sobresale.
		piezas.append({"pos": Vector2(sx, sy), "radio": Vector2(rxm * u, ry * u),
			"gira_forma": true, "tono": tono, "ang": ang, "caja": caja, "chaflan": chaflan,
			"persp": SpriteLienzo.persp_de(ry_rot, r.z * alto), "solo_sobre": solo_sobre})

	# SOMBRA DE CONTACTO, lo primero (va debajo). ANCHA: esta es de las pocas a las que le pega,
	# porque el bicho desborda sus propias patas y lo que proyecta sombra es el tronco entero.
	poner.call(Vector3(0.0, TRONCO.y, 0.0),
		Vector3(TRONCO_R.x * 0.94, TRONCO_R.y * 0.94, 0.0), Tono.SOMBRA_SUELO, [], false, 0.0, true)

	# PATAS: columnares, dos piezas, y se mueven JUNTAS con el balanceo. Al andar, delanteras y
	# traseras van en contrafase, y los dos lados tambien: es el paso cruzado.
	# En la muerte 'abre' las despatarra hacia los lados y las tumba.
	for lado in [-1.0, 1.0]:
		for k in PATA_Y.size():
			var delantera: bool = k == 0
			var swing: float = fase_patas * (1.0 if delantera else -1.0) * lado
			var base_y: float = PATA_Y[k] + swing * PASO_LARGO
			if delantera:
				base_y -= escarba * 2.2          # las delanteras raspan hacia atras al escarbar
			var px: float = lado * (PATA_X + abre * 2.6)
			# Al despatarrarse la pata BAJA (se tumba hacia fuera), y por eso el cuerpo acaba en el
			# suelo: son las dos caras del mismo movimiento.
			poner.call(Vector3(px, base_y, MUSLO_Z - abre * 1.6 - escarba * 0.5), MUSLO_R, Tono.PATA)
			poner.call(Vector3(lado * (PATA_X + abre * 3.4), base_y, PEZUNA_Z), PEZUNA_R, Tono.PATA)

	# COLA: un muñon corto.
	poner.call(COLA, COLA_R, Tono.SOMBRA)

	# EL VIENTRE, antes que el tronco: asoma por debajo y por los costados, y es la carne que hace
	# que el bicho no se lea como una piedra. Va en tono CARNE y algo mas bajo y estrecho que el
	# tronco, para que solo se le vea el borde de abajo.
	poner.call(Vector3(0.0, TRONCO.y, TRONCO.z - 2.2),
		Vector3(TRONCO_R.x * 0.90, TRONCO_R.y * 0.92, TRONCO_R.z * 0.6), Tono.CARNE)

	# EL TRONCO y los dos cuartos. La GRUPA primero y el PECHO al final, para que el cuarto delantero
	# -- que es lo que mira a la camara cuando la bestia viene hacia ti -- se recorte sobre el resto.
	poner.call(GRUPA, GRUPA_R, Tono.BASE)
	poner.call(TRONCO, TRONCO_R, Tono.BASE)
	poner.call(PECHO, PECHO_R, Tono.BASE)

	# EL CAPARAZON: las placas transversales, de la nuca a la grupa. Van con 'bloque' (rectangulares)
	# y SOLO SOBRE el cuerpo, para que no se derramen por fuera de la silueta ni pisen el contorno.
	#
	# Cada placa lleva su JUNTA oscura justo detras: sin ella las seis se funden en una sola mancha y
	# el lomo vuelve a ser liso. La junta es lo que hace que se cuenten seis placas y no una.
	# PRIMERO LA CORAZA ENTERA, como una masa continua, y solo DESPUES las placas encima. Al primer
	# intento las placas iban sueltas sobre el cuerpo y salia una REJA -- seis barras claras flotando
	# sobre carne rosa -- porque entre placa y placa se veia el cuerpo y no habia caparazon ninguno,
	# solo sus costillas. Un caparazon es una superficie: lo que hacen las placas es SEGMENTARLA.
	#
	# Va MAS ALTA que el eje del tronco, asi que cubre el lomo y los costados de arriba y deja asomar
	# la carne por abajo. Esas tres bandas -- coraza oscura, carne, patas -- son toda la lectura del
	# bicho.
	poner.call(Vector3(0.0, TRONCO.y, TRONCO.z + TRONCO_R.z * 0.42),
		Vector3(TRONCO_R.x * 0.97, TRONCO_R.y * 0.99, TRONCO_R.z), Tono.PLACA, [Tono.BASE])
	var sobre_cuerpo: Array = [Tono.BASE, Tono.PLACA, Tono.PLACA_OSC, Tono.PLACA_CLARA]
	for k in PLACAS:
		var f: float = float(k) / float(PLACAS - 1)
		var y: float = lerpf(PLACA_Y0, PLACA_Y1, f)
		# El caparazon sigue el contorno: las placas de los extremos son mas estrechas que las del
		# centro. 'seno' vale 1 en el medio del bicho y baja hacia las puntas.
		var seno: float = sin(PI * (0.14 + 0.72 * f))
		var w: float = PLACA_R.x * lerpf(PLACA_ESTRECHA, 1.0, seno)
		# Y el lomo es abombado: la placa del centro va mas alta que las de las puntas.
		var z: float = TRONCO.z + TRONCO_R.z * (0.52 + 0.30 * seno) + PLACA_ALZA
		poner.call(Vector3(0.0, y - PLACA_R.y * 1.15, z - 0.35),
			Vector3(w * 0.98, PLACA_R.y * 0.55, PLACA_R.z), Tono.PLACA_OSC, sobre_cuerpo,
			true, PLACA_CHAFLAN)
		poner.call(Vector3(0.0, y, z), Vector3(w, PLACA_R.y, PLACA_R.z), Tono.PLACA, sobre_cuerpo,
			true, PLACA_CHAFLAN)
		# El CANTO que da a la luz: una tira clara en el borde de delante de cada placa. Es lo que
		# convierte una franja plana en una placa con grosor.
		poner.call(Vector3(0.0, y + PLACA_R.y * 0.42, z + PLACA_R.z * 0.5),
			Vector3(w * 0.90, PLACA_R.y * 0.34, PLACA_R.z * 0.5), Tono.PLACA_CLARA,
			[Tono.PLACA], true, PLACA_CHAFLAN)

	# QUIEN LE VE LA CARA: de ESPALDAS no se le ven los ojos -- con la camara a 45 grados un bicho que
	# se aleja enseña la grupa, y eso es lo que hace que se lea de un vistazo si viene o si huye.
	var frente: float = DIR_VECS[dir].y
	var lados: Array = [-1.0, 1.0]
	if frente <= -0.5:
		lados = []
	elif frente < -0.2:
		lados = [signf(DIR_VECS[dir].x)]

	# CABEZA y TESTUZ. 'cabeza_y' los sube y los baja: al andar cabecea, y en la carga se hunde.
	poner.call(Vector3(CABEZA.x, CABEZA.y, CABEZA.z + cabeza_y), CABEZA_R, Tono.BASE)
	# El testuz es una PLACA: va con 'bloque', como las del lomo, porque es la misma coraza.
	poner.call(Vector3(TESTUZ.x, TESTUZ.y, TESTUZ.z + cabeza_y), TESTUZ_R, Tono.PLACA, [],
		true, TESTUZ_CHAFLAN)
	# El canto superior del testuz: UNA TIRA FINA, no media placa. Con `TESTUZ_R.y * 0.9` se comia el
	# testuz entero y de frente el bicho salia con una chapa gris claro por cara -- una caja metalica
	# con dos luces amarillas, no un animal. Un canto iluminado tiene que ser un filo.
	poner.call(Vector3(TESTUZ.x, TESTUZ.y, TESTUZ.z + cabeza_y + TESTUZ_R.z * 0.74),
		Vector3(TESTUZ_R.x * 0.88, TESTUZ_R.y * 0.30, TESTUZ_R.z * 0.22), Tono.PLACA_CLARA,
		[Tono.PLACA], true, TESTUZ_CHAFLAN)

	# PUAS a los lados del testuz. Estas SI se ven de espaldas: sobresalen del contorno y son parte
	# de la silueta desde cualquier lado.
	for lado in [-1.0, 1.0]:
		poner.call(Vector3(lado * PUA.x, PUA.y, PUA.z + cabeza_y), PUA_R, Tono.PUA_T)

	# OJOS: los ULTIMOS, y solo si se le ve la cara. Pequeños, que es lo suyo en un bicho acorazado.
	for l in lados:
		poner.call(Vector3(l * OJO.x, OJO.y, OJO.z + cabeza_y), OJO_R, Tono.OJO_T)

	return piezas


# La plantilla de un frame: que tono le toca a cada celda.
static func _plantilla(dir: int, pose: Dictionary, esc: float) -> PackedByteArray:
	var lado: int = _celdas(esc)
	var plant := PackedByteArray()
	plant.resize(lado * lado)
	plant.fill(0)
	var piezas: Array = _piezas(dir, pose, esc)
	for p in piezas:
		var pos: Vector2 = p["pos"]
		var r: Vector2 = p["radio"]
		if bool(p["caja"]):
			SpriteLienzo.bloque(plant, lado, lado, pos.x, pos.y, r.x, r.y, int(p["tono"]),
				float(p["ang"]), p["solo_sobre"], float(p["persp"]), float(p["chaflan"]))
		else:
			SpriteLienzo.elipse(plant, lado, lado, pos.x, pos.y, r.x, r.y, int(p["tono"]),
				float(p["ang"]), p["solo_sobre"], float(p["persp"]))

	# CONTORNO al final, sobre la silueta ya completa (ver SpriteLienzo.contornear).
	SpriteLienzo.contornear(plant, SpriteLienzo.caja_de_piezas(piezas, lado, lado), lado, lado,
		Tono.BORDE, Tono.VACIO, Tono.SOMBRA_SUELO)
	return plant
