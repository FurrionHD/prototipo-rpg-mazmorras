# ============================================================
#  aberracion_sprites.gd  (class_name AberracionSprites)
#  Sprite de la ABERRACION DE LA SIMA dibujada por codigo, con el motor comun (SpriteLienzo) y la
#  camara de 45 grados que comparten todos los bichos. Aparece en los pisos 8-12.
#
#  NO TIENE ESQUELETO. Es el primer bicho del juego que no es ni cuadrupedo (jabali, acechador,
#  bestia) ni bipedo (golem, gargola, coloso) ni un caparazon con patas (los insectos): es una MASA
#  que se arrastra, sin patas, con seis TENTACULOS y UN OJO. Su familia es NINGUNA -- la comparte con
#  el Trent -- y eso aqui es literal: no se parece a nada de lo que hay.
#
#  LAS TRES PIEZAS QUE LA CUENTAN, y cada una viene de una de sus habilidades:
#    * EL OJO, grande y unico. Sin el no hay `aberracion_mirada` (el ataque que da MIEDO): un bicho
#      que da miedo con la mirada tiene que tener con que mirar, y tiene que verse desde lejos.
#    * LAS FAUCES, debajo del ojo y ABRIENDOSE. Son el `aberracion_alarido`, que no hace daño
#      (dano_mult = 0) y solo reparte debilidad y vulnerable en area: es puro grito, asi que el grito
#      hay que dibujarlo.
#    * LOS TENTACULOS, que barren el suelo y azotan hacia delante. Son su `aberracion_latigazo` (2-3
#      golpes) y ademas su golpe basico, que en su .tres es fx_basico = 34, o sea LATIGAZO.
#
#  TODO GIRA CON LA DIRECCION, como en los cuadrupedos, y NO se deja el cuerpo quieto girando solo
#  los adornos (que es lo que hace el slime, por ser una bola). Girar el cuerpo entero no se nota --
#  es una masa casi redonda en planta -- y a cambio evita de raiz la trampa de la marca que se
#  DESLIZA: un ojo pegado a un cuerpo que no gira se desplaza solo por la cara del bicho al cambiar
#  de rumbo, y eso ya costo una vuelta en el golem.
#
#  El TAMAÑO se consigue con MAS CELDAS, no con celdas mas gordas: ver SpriteLienzo.UNIDADES_POR_CELDA.
# ============================================================

extends RefCounted
class_name AberracionSprites

const FRAMES := 8

# --- La aberracion mirando al SUR, en unidades de MUNDO (origen = donde toca el suelo, +Y hacia
# donde mira, +Z hacia arriba). A escala 1.0 mide unas 30 unidades contando los tentaculos. ---
const LARGO_MUNDO := 30.0

# --- EL BULBO: la masa central. Ancha abajo y algo mas estrecha arriba, como algo que se ha
# DERRAMADO y se ha quedado ahi. Va baja: se arrastra, no camina.
const BULBO := Vector3(0.0, 0.0, 6.2)
const BULBO_R := Vector3(7.4, 6.8, 5.8)
# LOBULOS: dos bultos secundarios, uno a cada lado y a distinta altura. Son lo que la salva de ser
# una BOLA -- que es lo unico que no puede parecer, porque una bola morada ya existe en el juego y
# se llama slime. Van descolocados a proposito: la simetria es de los animales, no de esto.
const LOBULO_A := Vector3(4.6, -3.2, 8.6)
const LOBULO_A_R := Vector3(4.0, 4.2, 3.8)
const LOBULO_B := Vector3(-5.0, 1.8, 7.2)
const LOBULO_B_R := Vector3(3.6, 3.8, 3.4)
# LA JOROBA alta y trasera, que le da un perfil de cosa encorvada sobre si misma.
const JOROBA := Vector3(-0.8, -2.6, 11.2)
const JOROBA_R := Vector3(4.4, 4.0, 3.2)

# EL OJO: enorme para el tamaño del bicho y en la parte ALTA Y DELANTERA, que es donde se ve desde
# los ocho lados. Tres piezas -- globo, iris y pupila -- porque con dos no hay MIRADA: hace falta que
# se note adonde mira.
const OJO := Vector3(0.0, 4.4, 10.2)
const OJO_R := Vector3(3.0, 2.6, 2.9)
const IRIS_R := Vector3(1.7, 1.4, 1.65)
const PUPILA_R := Vector3(0.85, 0.7, 0.8)
# Cuanto sobresalen el iris y la pupila hacia delante. Van POR DELANTE del globo, no dentro: si se
# dibujan a la misma profundidad, de perfil el iris se queda en el centro del ojo y el bicho parece
# mirar siempre de frente aunque este de lado.
const OJO_SALE := 1.9
# El PARPADEO: cuanto se cierra el ojo (0 = abierto). Se hace bajando un parpado del color del
# cuerpo desde arriba, que es mas barato y se lee mejor que deformar el globo.
const PARPADO_R := Vector3(3.2, 2.8, 3.0)

# LAS FAUCES: una hendidura vertical DEBAJO del ojo. Cerradas son una linea oscura; abiertas, un
# hueco rojo con dientes. El alarido las abre del todo.
const BOCA := Vector3(0.0, 5.6, 4.4)
const BOCA_R := Vector3(2.7, 1.6, 1.5)
const BOCA_ABRE := 2.6             # cuanto crece de alto al abrirse
const DIENTES := 5
const DIENTE_R := Vector3(0.42, 0.5, 0.62)

# --- LOS TENTACULOS: seis, repartidos alrededor, que salen del bajo del bulbo, CAEN y se arrastran
# por el suelo. Son cadenas construidas POR PASOS UNITARIOS -- se avanza una distancia FIJA en la
# direccion actual y luego se gira --, que es la unica forma de curvar una cadena sin que se descosa.
# Como puntos de una curva se abren segun avanzan y la punta se suelta: costo 141 fotogramas rotos en
# la cola del acechador y no se va a repetir.
const TENTACULOS := 6
# GRUESOS Y LARGOS. Al primer intento median 1,55 de radio en la base y ocho segmentos, y en la tira
# salian como PELILLOS -- patas de araña, o antenas. Un tentaculo es un miembro: tiene que tener el
# grosor de un brazo, o el bicho no se lee como algo que te agarra. Y son su arma principal (su golpe
# basico es fx_estilo 34, LATIGAZO), asi que tienen que ser lo segundo que se ve despues del ojo.
const TENT_SEGMENTOS := 10
const TENT_PASO := 1.15            # menor que el diametro mas fino (2 x 1,05 = 2,1): SOBRA
const TENT_R0 := 2.2
const TENT_R1 := 1.05
# NACEN METIDOS EN EL BULBO (4,4 contra sus 7,4 de semiancho), no pegados a su borde: en el borde de
# una elipse el cuerpo tiene grosor CERO y lo que cuelgue de ahi flota. Es la leccion que costo tres
# vueltas con las patas del acechador.
const TENT_NACE_R := 4.4
const TENT_NACE_Z := 4.8
# La caida: empieza bajando fuerte y se va APLANANDO, asi que la punta acaba tendida en el suelo en
# vez de clavada en el. Un tentaculo que se arrastra es eso: una curva que muere en horizontal.
const TENT_ANG0 := 0.95
const TENT_GIRO := 0.16
# Cuanto ondulan en reposo y cuanto se abren y azotan al atacar.
const TENT_ONDA := 1.5
const TENT_AZOTA := 5.5

# EL LATIGAZO: viaja poco -- no embiste, azota -- pero el cuerpo se echa atras y luego adelante.
const LUNGE_DIST := 5.0
# ENCAJAR UN GOLPE: es BLANDA, asi que se aplasta mucho y retrocede mucho. Al reves que la bestia
# acorazada, y ese contraste es lo que hace que las dos se lean distinto en combate.
const ENCAJE_RETRO := 0.42

# Lienzo CUADRADO y holgado: los tentaculos se despliegan en todas direcciones y al azotar se
# estiran; y el cadaver los deja tendidos en abanico, que es cuando mas ocupa.
const LIENZO_FACTOR := 2.15

# TONOS propios (el motor no sabe que es cada uno; solo mapea indice -> color, ver _colores).
enum Tono { VACIO, SOMBRA_SUELO, BORDE, TENT_OSC, TENT, SOMBRA, BASE, CLARO, BOCA_T, DIENTE_T,
	GLOBO, IRIS, PUPILA }

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
	return "aberracion_%s_%.2f" % [col.to_html(false), esc]


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(escala: float = 1.0) -> int:
	return _celdas(escala)


static func dimensiona_por_escala() -> bool:
	return true


# El CUERPO en planta (ancho, largo) para la colision: SOLO EL BULBO. Los tentaculos NO cuentan --
# son hilos que barren el suelo, y hacerle chocar con las paredes por un tentaculo seria tan absurdo
# como hacerlo con la cola de la rata o con un colmillo del jabali. Sale casi redondo, asi que
# enemy.gd no le gira la colision.
static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return Vector2(BULBO_R.x * 2.0, BULBO_R.y * 2.0) * escala


static func _celdas(escala: float) -> int:
	var lado: int = int(ceil(LARGO_MUNDO * escala * LIENZO_FACTOR / SpriteLienzo.UNIDADES_POR_CELDA))
	return lado + (lado % 2)      # par, para que el centro caiga limpio


static func generar(color: Color = Color(0.45, 0.2, 0.5), escala: float = 1.0) -> SpriteFrames:
	# cuantizar_hsv y no cuantizar a secas: redondear canal a canal le cambiaria el TONO, y aqui el
	# tono ES el bicho -- si el morado se va a azul o a marron deja de leerse como algo enfermo.
	var col: Color = SpriteLienzo.cuantizar_hsv(color, COLOR_PASOS)
	var esc: float = snappedf(escala, 0.05)      # se cuantiza tambien, o el cache no acierta
	var clave: String = _clave(col, esc)
	if _cache.has(clave):
		return _cache[clave]
	var anims: Array = []
	_montar_idle(anims, esc)
	_montar_walk(anims, esc)
	_montar_embestida(anims, esc)
	_montar_alarido(anims, esc)
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
	return {"avance": 0.0, "palpita": 0.0, "aplasta": 0.0, "onda": 0.0, "azota": 0.0,
		"boca": 0.0, "parpado": 0.0, "desinfla": 0.0}


# Quieto: PALPITA. No respira -- late. Es lo unico que hace, y tiene que bastar para que se lea como
# algo vivo estando parado. Los tentaculos ondulan a la mitad de velocidad que el latido, asi los dos
# ritmos no se sincronizan y el bicho no parece un metronomo.
#
# Y PARPADEA una vez por ciclo. Un ojo enorme que nunca se cierra se lee como una canica pintada; el
# parpadeo es lo que lo convierte en un ojo que te esta mirando.
static func _montar_idle(anims: Array, esc: float) -> void:
	var parpado_keys := [[0.0, 0.0], [0.60, 0.0], [0.70, 1.0], [0.80, 0.0], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["palpita"] = sin(TAU * t)
		p["onda"] = sin(TAU * t * 0.5)
		p["parpado"] = SpriteLienzo.tramos(t, parpado_keys)
		p["boca"] = 0.12 + 0.10 * sin(TAU * t)     # las fauces nunca cierran del todo
		return p
	_montar_animacion(anims, esc, "idle", true, 4.0, pose, false)


# Andando: SE ARRASTRA. No hay paso que dibujar, asi que el movimiento es el del propio cuerpo: se
# estira hacia delante, se aplasta y tira -- como una babosa, pero a tirones. Los tentaculos ondulan
# al doble de velocidad, que es lo que se lee como que estan tirando de ella.
static func _montar_walk(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		# El tiron: se aplasta y se estira en el mismo ciclo, desfasados.
		p["aplasta"] = 0.22 * (1.0 - cos(TAU * t))
		p["palpita"] = 0.7 * sin(TAU * t + PI * 0.5)
		p["onda"] = sin(TAU * t)
		p["boca"] = 0.15
		return p
	_montar_animacion(anims, esc, "walk", true, 6.0, pose, false)


# ENCOGERSE -> AZOTAR -> recoger. NO es periodica, asi que va por TRAMOS.
#
# ES UN LATIGAZO, NO UNA EMBESTIDA, y por eso el cuerpo casi no viaja (LUNGE_DIST 5,0 contra los 13
# del salto del acechador): lo que sale disparado son los TENTACULOS. El cuerpo solo se echa atras
# para coger impulso y se abalanza un palmo al soltar.
#
# Y LAS FAUCES SE ABREN DEL TODO EN EL GOLPE. Es lo que junta sus dos ataques en un mismo gesto: el
# latigazo que pega y el alarido que no pega pero aterroriza.
static func _montar_embestida(anims: Array, esc: float) -> void:
	var avance_keys := [[0.0, 0.0], [0.30, -1.8], [0.55, 3.6], [0.75, 5.0], [1.0, 2.4]]
	# Se ENCOGE al recoger los tentaculos y se HINCHA al soltarlos: el bicho entero es el latigo.
	var palpita_keys := [[0.0, 0.0], [0.30, -1.4], [0.55, 1.6], [0.75, 0.8], [1.0, 0.0]]
	var azota_keys := [[0.0, 0.0], [0.30, -0.55], [0.55, 1.0], [0.78, 0.75], [1.0, 0.0]]
	var boca_keys := [[0.0, 0.15], [0.30, 0.45], [0.55, 1.0], [0.78, 0.85], [1.0, 0.2]]
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["avance"] = SpriteLienzo.tramos(t, avance_keys) * (LUNGE_DIST / 5.0)
		p["palpita"] = SpriteLienzo.tramos(t, palpita_keys)
		p["azota"] = SpriteLienzo.tramos(t, azota_keys)
		p["boca"] = SpriteLienzo.tramos(t, boca_keys)
		p["aplasta"] = 0.20 * maxf(0.0, -SpriteLienzo.tramos(t, azota_keys))
		return p
	_montar_animacion(anims, esc, "embestida", false, 12.0, pose, true)


# EL ALARIDO DEMENTE: abre las fauces DEL TODO, se hincha y grita. No pega a nadie -- es un estado --
# asi que el cuerpo no puede ir a ningun sitio.
#
# HASTA AHORA REPRODUCIA EL LATIGAZO, o sea que sacaba los tentaculos disparados y se abalanzaba un
# palmo... para soltar un grito que no toca. Su efecto (los anillos que barren la fila) SE MANTIENE:
# eso es el grito viajando, no es el cuerpo. Lo que sobraba era que el cuerpo atacara.
#
# LA BOCA ES TODO EL GESTO Y POR ESO SE LLEVA EL DOBLE DE RECORRIDO QUE EN EL LATIGAZO: alli sube a
# 1,0 de pasada, en el mismo fotograma que salen los tentaculos y compartiendo la atencion con ellos;
# aqui llega a 1,0 y SE QUEDA abierta tres fotogramas. Es la diferencia entre abrir la boca al pegar
# y GRITAR.
#
# Y SE HINCHA EN VEZ DE ENCOGERSE. En el latigazo 'palpita' baja a -1,4 primero (recoge para soltar);
# aqui no hay nada que soltar, asi que va directo hacia arriba y se queda inflada: lo que se ve desde
# el sur es que el bicho CRECE, que es lo unico que un cuerpo sin miembros puede hacer para gritar.
static func _montar_alarido(anims: Array, esc: float) -> void:
	# Coge aire (se encoge un poco) y se hincha del todo. El valle de 0,143 es lo que le da el impulso.
	var palpita_keys := [[0.0, 0.0], [0.143, -0.9], [0.286, 1.4], [0.429, 1.8], [0.571, 1.7],
		[0.714, 1.5], [0.857, 0.7], [1.0, 0.0]]
	# Las fauces: cerradas para coger aire y abiertas de par en par el resto.
	var boca_keys := [[0.0, 0.15], [0.143, 0.05], [0.286, 0.90], [0.429, 1.0], [0.571, 1.0],
		[0.714, 1.0], [0.857, 0.55], [1.0, 0.2]]
	# La onda del cuerpo se acelera mientras grita: es lo que dice que la masa esta vibrando.
	var onda_keys := [[0.0, 0.0], [0.143, 0.3], [0.286, -0.9], [0.429, 0.9], [0.571, -0.8],
		[0.714, 0.7], [0.857, -0.3], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["palpita"] = SpriteLienzo.tramos(t, palpita_keys)
		p["boca"] = SpriteLienzo.tramos(t, boca_keys)
		p["onda"] = SpriteLienzo.tramos(t, onda_keys)
		# El ojo ABIERTO todo el rato: 'parpado' a 0. Va escrito aunque _reposo ya lo deje en cero,
		# porque aqui es una decision -- en el idle parpadea, y algo que chilla no parpadea.
		p["parpado"] = 0.0
		return p
	# UNA SOLA DIRECCION: solo se ve en combate, y ahi se le mira de frente.
	_montar_animacion(anims, esc, "alarido", false, 9.0, pose, true, 1, FRAMES)


# ENCAJAR UN GOLPE. Cuatro fotogramas en UNA sola direccion (en combate se le ve siempre de frente) y
# EMPEZANDO YA GOLPEADO: el frame 0 es el impacto, no la pose de reposo. Un golpe no tiene
# anticipacion, y con cuatro marcos un fotograma de espera se comeria la animacion entera.
#
# ES BLANDA: SE APLASTA. Donde la bestia acorazada apenas acusa el golpe, esta se deforma entera y
# rebota -- es una masa sin huesos, y un golpe en algo asi se HUNDE. Los tentaculos se sacuden.
static func _montar_encaje(anims: Array, esc: float) -> void:
	# 'aplasta' no pasa de 0,70: por encima de 1,0 la altura se vuelve negativa y las piezas dejan de
	# pintarse SIN DAR ERROR.
	var aplasta_keys := [[0.0, 0.70], [0.34, 0.10], [0.67, 0.22], [1.0, 0.0]]
	var retro_keys := [[0.0, 1.0], [0.34, 0.45], [0.67, 0.12], [1.0, 0.0]]
	var palpita_keys := [[0.0, -1.6], [0.34, 1.1], [0.67, -0.4], [1.0, 0.0]]
	# La boca se abre de golpe: un alarido de dolor.
	var boca_keys := [[0.0, 0.9], [0.34, 0.6], [0.67, 0.3], [1.0, 0.15]]
	var pose := func(t: float) -> Dictionary:
		var p: Dictionary = _reposo()
		p["avance"] = -SpriteLienzo.tramos(t, retro_keys) * (LUNGE_DIST * ENCAJE_RETRO)
		p["aplasta"] = SpriteLienzo.tramos(t, aplasta_keys)
		p["palpita"] = SpriteLienzo.tramos(t, palpita_keys)
		p["boca"] = SpriteLienzo.tramos(t, boca_keys)
		p["azota"] = -0.35 * SpriteLienzo.tramos(t, retro_keys)
		return p
	# TODOS LOS BICHOS ENCAJAN A 18 fps: es la duracion que espera CombatFX.T_ENCAJE, y cuadrando las
	# dos el sprite va a su velocidad natural en vez de estirado por _pose_ajustar.
	_montar_animacion(anims, esc, "encaje", false, 18.0, pose, true, 1, 4)


# MORIRSE. OCHO fotogramas en UNA sola direccion: la muerte solo se ve en la pantalla de combate, y
# ahi al bicho se le mira siempre de frente. Para el mapa esta 'cadaver', que es lo contrario.
#
# SE DESINFLA. No vuelca (no tiene costado que enseñar) ni se derrumba en escombros (no tiene piezas
# sueltas): lo suyo es perder la forma. El bulbo se hunde y se ensancha -- lo que estaba dentro tiene
# que ir a alguna parte --, los tentaculos se desmadejan en abanico por el suelo y el OJO SE APAGA:
# la pupila se dilata hasta comerse el iris y el parpado cae a medias.
#
# Lo del ojo no es un adorno: es la leccion del golem, al que hubo que apagarle los ojos porque un
# cadaver que sigue mirando no esta muerto. Aqui pesa el doble, porque el ojo es TODO el bicho.
static func _pose_muerte(t: float) -> Dictionary:
	var desinfla_keys := [[0.0, 0.0], [0.18, 0.15], [0.38, 0.5], [0.60, 0.82], [0.82, 0.96],
		[1.0, 1.0]]
	# Un ultimo estertor -- se hincha una vez antes de venirse abajo -- y luego se hunde del todo.
	var palpita_keys := [[0.0, 0.0], [0.14, 1.3], [0.30, -0.6], [0.55, -1.4], [1.0, -1.8]]
	var aplasta_keys := [[0.0, 0.0], [0.18, 0.12], [0.38, 0.42], [0.60, 0.68], [1.0, 0.80]]
	# Las fauces se quedan ABIERTAS: muere gritando, que es lo que hace algo que ataca gritando.
	var boca_keys := [[0.0, 0.2], [0.14, 1.0], [0.38, 0.85], [1.0, 0.7]]
	# Y el parpado cae a medias. A medias y no del todo: un ojo entrecerrado esta muerto, uno cerrado
	# esta dormido.
	var parpado_keys := [[0.0, 0.0], [0.38, 0.1], [0.60, 0.35], [1.0, 0.55]]
	var p: Dictionary = _reposo()
	p["desinfla"] = SpriteLienzo.tramos(t, desinfla_keys)
	p["palpita"] = SpriteLienzo.tramos(t, palpita_keys)
	p["aplasta"] = SpriteLienzo.tramos(t, aplasta_keys)
	p["boca"] = SpriteLienzo.tramos(t, boca_keys)
	p["parpado"] = SpriteLienzo.tramos(t, parpado_keys)
	p["azota"] = -0.20 * SpriteLienzo.tramos(t, desinfla_keys)
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
			# aberracion de otro tono reusa estas plantillas y solo repinta. Es lo que evita que
			# entrar a un piso lleno de bichos congele el juego.
			var clave: String = "%s_%d_%d_%.2f" % [nombre, i, dir, esc]
			var plant: PackedByteArray = _cache_plantillas.get(clave, PackedByteArray())
			if plant.is_empty():
				plant = _plantilla(dir, pose_fn.call(float(i) / divisor), esc)
				_cache_plantillas[clave] = plant
			plantillas.append(plant)
		anims.append({"nombre": "%s_%d" % [nombre, dir], "loop": loop, "fps": fps,
			"plantillas": plantillas})


# Los colores de cada Tono, EN EL ORDEN DEL ENUM (contrato con SpriteLienzo.paleta).
#
# LA PALETA TIENE QUE DECIR "CARNE ENFERMA", no "piedra morada". Por eso el cuerpo lleva un BRILLO
# claro y rosado arriba (lo humedo es lo que separa la carne del mineral) y las fauces van en un rojo
# oscuro que no aparece en ningun otro sitio del bicho: un agujero tiene que leerse como un agujero.
static func _colores(color: Color) -> Array:
	var base := Color.from_hsv(color.h, minf(1.0, color.s * 1.10 + 0.05), color.v)
	base.a = color.a
	return [
		Color(0, 0, 0, 0),                    # VACIO
		Color(0, 0, 0, 0.22),                 # SOMBRA_SUELO
		base.darkened(0.68),                  # BORDE
		base.darkened(0.52),                  # TENT_OSC (el envés del tentaculo)
		base.darkened(0.28),                  # TENT
		base.darkened(0.34),                  # SOMBRA (el bajo del bulbo, en penumbra)
		base,                                 # BASE
		# El BRILLO HUMEDO: se aclara hacia un rosa lechoso, no hacia el blanco. 'lightened' desatura,
		# y un morado desaturado es gris -- o sea piedra, que es lo que no puede parecer.
		base.lerp(Color(0.92, 0.72, 0.88), 0.26),   # CLARO
		Color(0.30, 0.06, 0.12),              # BOCA_T (el hueco, rojo casi negro)
		Color(0.92, 0.88, 0.76),              # DIENTE_T (hueso)
		# EL GLOBO DEL OJO va casi blanco y AMARILLENTO: es lo unico frio-claro del bicho y tiene que
		# ganar a todo lo demas. Un ojo del color del cuerpo no se ve, y este ojo ES el bicho.
		Color(0.94, 0.92, 0.80),              # GLOBO
		Color(0.86, 0.62, 0.16),              # IRIS (ambar)
		Color(0.05, 0.03, 0.06),              # PUPILA
	]


# ------------------------------------------------------------
#  GEOMETRIA
# ------------------------------------------------------------

# Las PIEZAS de la aberracion para una pose, ya proyectadas a pantalla. El orden ES la profundidad:
# se pintan en ese orden y las ultimas tapan a las primeras, asi que va de lo mas bajo (sombra,
# tentaculos de detras) a lo mas alto y cercano (bulbo, boca, ojo).
static func _piezas(dir: int, pose: Dictionary, esc: float) -> Array:
	var ang: float = DIR_VECS[dir].angle() - DIR_VECS[0].angle()
	var u: float = esc / SpriteLienzo.UNIDADES_POR_CELDA    # unidades de mundo -> celdas
	var centro: float = float(_celdas(esc)) * 0.5
	var avance: float = float(pose["avance"])
	var palpita: float = float(pose["palpita"])
	var aplasta: float = float(pose["aplasta"])
	var onda: float = float(pose["onda"])
	var azota: float = float(pose["azota"])
	var boca_abre: float = float(pose["boca"])
	var parpado: float = float(pose["parpado"])
	var desinfla: float = float(pose["desinfla"])

	# EL LATIDO Y EL DESINFLE SON LO MISMO CON DISTINTO SIGNO, asi que se resuelven juntos: un bicho
	# sin huesos solo puede hacer dos cosas -- hincharse y venirse abajo -- y las dos son cambiar de
	# volumen. Al desinflarse se ENSANCHA mientras BAJA: lo que estaba dentro tiene que ir a alguna
	# parte, y sin eso no se lee como que se desinfla, se lee como que encoge.
	var hincha: float = 1.0 + 0.06 * palpita
	var ancho: float = hincha * (1.0 + 0.34 * desinfla)
	var alto: float = hincha * (1.0 - 0.36 * aplasta) * (1.0 - 0.62 * desinfla)

	var piezas: Array = []
	var desp := Vector2(0.0, avance).rotated(ang)
	var s_a: float = sin(ang)
	var c_a: float = cos(ang)

	# local (x ancho, y largo, z altura, en unidades de mundo) -> celda de pantalla.
	var poner := func(local: Vector3, r: Vector3, tono: int, solo_sobre: Array = [],
			en_suelo: bool = false) -> void:
		var p := Vector2(local.x * ancho, local.y * ancho)
		var rot: Vector2 = p.rotated(ang) + desp
		var z: float = 0.0 if en_suelo else local.z * alto
		var sx: float = centro + rot.x * u
		var sy: float = centro + (rot.y * SpriteLienzo.COS_CAM - z * SpriteLienzo.SIN_CAM) * u
		var ry: float = r.y * ancho
		var rxm: float = r.x * ancho
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

	# SOMBRA DE CONTACTO, lo primero (va debajo). Crece al desinflarse, que es lo mismo que le pasa
	# al cuerpo: se desparrama.
	poner.call(Vector3(0.0, 0.0, 0.0),
		Vector3(BULBO_R.x * 0.92, BULBO_R.y * 0.92, 0.0), Tono.SOMBRA_SUELO, [], true)

	# LOS TENTACULOS. Se dibujan TODOS antes del bulbo: nacen de su bajo y el bulbo tiene que taparles
	# el arranque, que es lo que hace que salgan DE dentro en vez de estar pegados por fuera.
	#
	# El reparto en planta empieza en PI (o sea hacia ATRAS) y da la vuelta entera, para que ninguno
	# nazca justo en el eje de delante: ahi esta la boca, y un tentaculo saliendo de la barbilla se
	# lee fatal.
	for k in TENTACULOS:
		var a: float = PI + TAU * (float(k) + 0.5) / float(TENTACULOS)
		var dx: float = sin(a)
		var dy: float = cos(a)
		# Cuanto mira este tentaculo hacia DELANTE (1 = al frente, -1 = atras). Los de delante son los
		# que azotan; los de atras solo ondulan y se quedan.
		var frontal: float = maxf(0.0, dy)
		var p3 := Vector3(dx * TENT_NACE_R, dy * TENT_NACE_R, TENT_NACE_Z)
		# EL AZOTE VA TODO EN EL ANGULO DE LA CADENA, no en un desplazamiento por pieza. Al primer
		# intento cada segmento se empujaba hacia fuera por `azota * f²`, y eso SEPARA: entre los dos
		# ultimos, f² crece 0,27, o sea 1,5 unidades extra de hueco sumadas al paso de 1,15 -- contra
		# un diametro de 1,7. Las puntas se soltaban en los 13 fotogramas del latigazo.
		#
		# Es el mismo error que la cola-parabola del acechador con otra cara: CUALQUIER deformacion
		# que crezca a lo largo de la cadena anade separacion entre piezas. Metida en el angulo no
		# puede: el paso sigue siendo fijo, solo cambia hacia donde apunta.
		var av: float = TENT_ANG0 - azota * frontal * 1.55
		for j in TENT_SEGMENTOS:
			var f: float = float(j) / float(TENT_SEGMENTOS - 1)
			# La ONDA abre y cierra el tentaculo de lado, mas cuanto mas cerca de la punta. Cada uno
			# va en su propia fase (el '+ a') o los seis ondularian a la vez como un ventilador.
			# Crece con f y NO con f² por lo mismo de arriba: cuanto mas despacio crezca, menos
			# separacion mete entre piezas.
			var vaiven: float = sin(TAU * onda * 0.5 + a + f * 2.2) * TENT_ONDA * f
			poner.call(Vector3(p3.x - dy * vaiven, p3.y + dx * vaiven, p3.z),
				Vector3.ONE * lerpf(TENT_R0, TENT_R1, f),
				Tono.TENT if frontal > -0.2 else Tono.TENT_OSC)
			# POR PASOS UNITARIOS: se avanza TENT_PASO en la direccion actual y DESPUES se gira. El
			# paso no cambia nunca, asi que dos piezas seguidas se solapan igual al principio que en
			# la punta -- que es lo que impide que la cadena se descosa al curvarse.
			p3.x += dx * cos(av) * TENT_PASO
			p3.y += dy * cos(av) * TENT_PASO
			p3.z -= sin(av) * TENT_PASO
			# El giro APLANA la caida (el angulo baja hacia 0 y pasa a negativo), asi que la punta
			# acaba tendida en el suelo en vez de clavada en el. Eso es un tentaculo que se arrastra.
			av -= TENT_GIRO

	# EL BULBO y sus bultos. El cuerpo va DESPUES de los tentaculos (les tapa el arranque) y los
	# lobulos despues del bulbo, para que se recorten sobre el.
	poner.call(BULBO, BULBO_R, Tono.BASE)
	poner.call(LOBULO_A, LOBULO_A_R, Tono.BASE)
	poner.call(LOBULO_B, LOBULO_B_R, Tono.BASE)
	poner.call(JOROBA, JOROBA_R, Tono.BASE)

	# EL BAJO EN PENUMBRA: una mancha oscura en la parte de abajo del cuerpo. Va antes que el brillo
	# para que entre los dos quede el tono base como transicion.
	poner.call(Vector3(0.0, 0.0, BULBO.z - BULBO_R.z * 0.66),
		Vector3(BULBO_R.x * 0.88, BULBO_R.y * 0.88, BULBO_R.z * 0.5), Tono.SOMBRA, [Tono.BASE])

	# EL BRILLO HUMEDO, arriba y descentrado. Descentrado a proposito: centrado se lee como un reflejo
	# de estudio y le quita lo irregular, que es de lo poco que tiene esta cosa.
	#
	# Y PEQUEÑO (0,34 del bulbo, no 0,46): a lo grande dejaba de ser un brillo y pasaba a ser el color
	# del bicho -- en la tira salia una masa LILA PASTEL, que no es lo que tiene que dar una cosa que
	# vive en el fondo de una sima. Un reflejo tiene que ser una mancha, no una capa.
	poner.call(Vector3(-1.8, -1.6, BULBO.z + BULBO_R.z * 0.76),
		Vector3(BULBO_R.x * 0.34, BULBO_R.y * 0.32, BULBO_R.z * 0.36), Tono.CLARO, [Tono.BASE])

	# QUIEN LE VE LA CARA: de ESPALDAS no se le ven ni el ojo ni las fauces. Con la camara a 45 grados
	# un bicho que se aleja enseña la espalda, y aqui esa regla vale doble: el ojo es lo mas claro y
	# lo mas grande que lleva, asi que dibujado siempre seria un faro mirandote desde la nuca.
	var frente: float = DIR_VECS[dir].y
	var ve_cara: bool = frente > -0.35

	if ve_cara:
		# LAS FAUCES, antes que el ojo (van debajo y el ojo no las tapa). El hueco crece hacia ABAJO
		# al abrirse: una boca que crece en las dos direcciones se traga la cara entera.
		var abre: float = boca_abre * BOCA_ABRE
		var bz: float = BOCA.z - abre * 0.5
		poner.call(Vector3(BOCA.x, BOCA.y, bz),
			Vector3(BOCA_R.x, BOCA_R.y, BOCA_R.z + abre), Tono.BOCA_T, [Tono.BASE, Tono.SOMBRA])
		# LOS DIENTES: una fila arriba y otra abajo, y solo se ven con la boca ABIERTA -- cerrada, la
		# linea de la boca ya es bastante. Van 'solo_sobre' el hueco, asi que no se salen de el.
		if boca_abre > 0.25:
			for d in DIENTES:
				var fd: float = (float(d) / float(DIENTES - 1) - 0.5) * 2.0
				var dx2: float = fd * BOCA_R.x * 0.72
				poner.call(Vector3(BOCA.x + dx2, BOCA.y, bz + BOCA_R.z + abre * 0.72),
					DIENTE_R, Tono.DIENTE_T, [Tono.BOCA_T])
				poner.call(Vector3(BOCA.x + dx2 * 0.85, BOCA.y, bz - BOCA_R.z - abre * 0.72),
					DIENTE_R, Tono.DIENTE_T, [Tono.BOCA_T])

		# EL OJO: globo, iris y pupila, cada uno mas adelantado que el anterior (OJO_SALE). Adelantar
		# el iris es lo que hace que de perfil se vea que el bicho mira HACIA DELANTE; dibujados a la
		# misma profundidad, el iris se queda clavado en el centro del globo mire donde mire.
		poner.call(OJO, OJO_R, Tono.GLOBO)
		poner.call(Vector3(OJO.x, OJO.y + OJO_SALE, OJO.z), IRIS_R, Tono.IRIS, [Tono.GLOBO])
		poner.call(Vector3(OJO.x, OJO.y + OJO_SALE * 1.35, OJO.z), PUPILA_R, Tono.PUPILA,
			[Tono.IRIS])
		# EL PARPADO: baja desde arriba tapando el globo. Es una pieza del color del CUERPO, asi que
		# se lee como piel que cae sobre el ojo y no como una sombra. Solo sobre las piezas del ojo,
		# para que al bajar no se coma la frente.
		if parpado > 0.02:
			poner.call(Vector3(OJO.x, OJO.y + OJO_SALE * 0.5,
					OJO.z + OJO_R.z * (2.0 - 1.85 * parpado)),
				PARPADO_R, Tono.BASE, [Tono.GLOBO, Tono.IRIS, Tono.PUPILA])

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
		SpriteLienzo.elipse(plant, lado, lado, pos.x, pos.y, r.x, r.y, int(p["tono"]),
			float(p["ang"]), p["solo_sobre"], float(p["persp"]))

	# CONTORNO al final, sobre la silueta ya completa (ver SpriteLienzo.contornear).
	SpriteLienzo.contornear(plant, SpriteLienzo.caja_de_piezas(piezas, lado, lado), lado, lado,
		Tono.BORDE, Tono.VACIO, Tono.SOMBRA_SUELO)
	return plant
