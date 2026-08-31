# ============================================================
#  escarabajo_sprites.gd  (class_name EscarabajoSprites)
#  El ESCARABAJO DE HIERRO (piso 7-10) dibujado por codigo. Solo geometria: el motor esta en
#  SpriteLienzo y quien reparte los generadores es SpritesEnemigo (por NOMBRE: los tres insectos
#  comparten familia y no se parecen en nada).
#
#  ES LO CONTRARIO DE LA ARAÑA, y a proposito: donde ella es patas largas y cuerpo pequeño, este es
#  UN DOMO BAJO Y ANCHO con seis patas cortas que casi no se ven. Uno se lee por lo que le sobresale
#  y el otro por su bulto. Comparten piso, asi que tienen que distinguirse de un vistazo.
#
#  LO DE "HIERRO" SE HACE CON EL SOMBREADO, NO CON EL COLOR. Su ficha es un verde oliva apagado, y
#  pintado plano se lee como una rana. Lo que lo vuelve metalico es un BRILLO estrecho y muy claro
#  sobre el lomo -- un reflejo duro, no un degradado -- con el resto del caparazon en penumbra.
#
#  MUERE PATAS ARRIBA. Es la postura de escarabajo muerto y no la tiene ningun otro bicho del juego:
#  vuelca sobre su eje largo (como el jabali, con el mismo 'rumbo' para que la vuelta se vea de
#  frente) y acaba con el vientre al aire y las seis patas dobladas hacia el cielo.
# ============================================================

extends RefCounted
class_name EscarabajoSprites

const FRAMES := 8

# --- El escarabajo mirando al SUR, en unidades de MUNDO (origen = donde toca el suelo, +Y hacia la
# pala, +Z hacia arriba). ---
const LARGO_MUNDO := 30.0

# ELITROS: el caparazon. ANCHO y BAJO -- mas ancho que largo de lo que parece, y con poca altura.
# Es la pieza que define al bicho: si sube demasiado se convierte en un escarabajo pelotero.
const ELITROS := Vector3(0.0, -1.6, 4.6)
const ELITROS_R := Vector3(8.2, 7.4, 4.4)
# PRONOTO: la placa del cuello, entre el caparazon y la cabeza. Mas estrecha que los elitros, y es
# lo que hace que el bicho tenga DOS piezas y no una sola pastilla.
const PRONOTO := Vector3(0.0, 5.4, 4.2)
const PRONOTO_R := Vector3(5.8, 3.2, 3.4)
const CABEZA := Vector3(0.0, 9.2, 3.2)
const CABEZA_R := Vector3(3.2, 2.6, 2.2)
# LA PALA: la placa frontal con la que escarba y embiste. PLANA y ANCHA (mirar su radio: 4.0 de
# ancho por 0.9 de alto), que es lo que la separa del cuerno de un jabali -- esto no pincha, empuja.
#
# Y GRANDE: la pala es la SEÑA del bicho (lo que dice que esto escarba y embiste), y a la primera
# salio del tamaño de la cabeza -- se leia como un morro, no como una herramienta. Tiene que
# sobresalir por delante y por los lados de la cabeza para que se entienda que es una placa aparte.
const PALA := Vector3(0.0, 12.0, 3.0)
const PALA_R := Vector3(4.9, 2.5, 1.1)
# Y los dos PICOS de las esquinas de la pala, que le dan la silueta dentada de frente.
const PICO_X := 4.3
const PICO := Vector3(0.0, 13.6, 3.4)
const PICO_R := Vector3(1.1, 1.4, 0.9)

# LA COSTURA de los elitros: la raya oscura del centro que los parte en dos. Sin ella el caparazon
# es un pegote liso; con ella se lee que son DOS placas, que es lo que hace un escarabajo.
const COSTURA_R := Vector3(0.55, 6.6, 1.0)
# EL BRILLO: el reflejo metalico. ESTRECHO (1.9 de ancho contra los 8.2 del caparazon) y muy claro.
# Ancho y suave seria un lomo iluminado normal, y entonces esto es un bicho verde; estrecho y duro
# es un reflejo, y entonces es hierro.
const BRILLO_R := Vector3(1.9, 5.2, 1.4)

# PATAS: SEIS, tres por lado, cortas y gruesas. Apenas asoman por debajo del caparazon -- es un
# bicho que va pegado al suelo -- y por eso no hace falta repartirlas por delante y por detras del
# cuerpo como en la araña: el domo las tapa casi siempre y van todas debajo.
const PATA_ANCLA_X := 5.4
const PATA_ANCLA_Z := 3.0
const PATA_ANCLA_Y := [5.0, 0.0, -5.0]
const PATA_ABRE := [4.0, 0.0, -4.4]
# CORTAS Y GRUESAS: apenas asoman. Al primer intento median 5,2 y arqueaban hasta 5,4 de alto, y de
# frente el bicho salia con patas de CANGREJO -- un escarabajo no se sostiene sobre arcos, va casi
# arrastrando el caparazon.
const PATA_ALCANCE := 4.3
const PATA_RODILLA_Z := 4.6
const PATA_RODILLA_F := 0.55
# Cortas, asi que con pocas bolitas basta: el tramo mide ~4,5 y con 4 el paso es 1,5 contra un
# grosor de 2,8. (Ver la regla del paso menor que el grosor en la araña y en la cola de la rata.)
const FEMUR_SEGMENTOS := 4
const TIBIA_SEGMENTOS := 5
const FEMUR_R0 := 1.70
const FEMUR_R1 := 1.40
const TIBIA_R0 := 1.40
const TIBIA_R1 := 1.15
const PASO_LARGO := 2.4
const PASO_ALTO := 1.4

# ANTENAS: cortas y con la punta en maza, hacia delante y afuera. Son la unica cosa fina del bicho y
# lo que impide que se lea como una piedra con patas.
const ANTENA := Vector3(1.9, 10.6, 4.4)
const ANTENA_SEGMENTOS := 4
const ANTENA_R0 := 0.75
const ANTENA_R1 := 1.15        # crece hacia la punta: es una maza, no un pelo

const OJO := Vector3(2.7, 10.2, 4.2)
const OJO_R := Vector3(0.95, 0.95, 0.95)

const LUNGE_DIST := 9.5
# Encaja poco: pesa y va blindado, como el jabali. Un escarabajo de hierro que sale despedido de un
# mandoble no daria ningun miedo.
const ENCAJE_RETRO := 0.22

# Lienzo CUADRADO y holgado: gira, embiste y ademas VUELCA (y volcado sobresale por abajo). Ajustado
# contra los avisos del horno, no calculado.
const LIENZO_FACTOR := 2.00

# TONOS propios (el motor no sabe que es cada uno; solo mapea indice -> color, ver _colores).
enum Tono { VACIO, SOMBRA_SUELO, BORDE, PATA, SOMBRA, BASE, LOMO, BRILLO, COSTURA, PALA_T, OJO_T }

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
	return "escarabajo_%s_%.2f" % [col.to_html(false), esc]


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(escala: float = 1.0) -> int:
	return _celdas(escala)


static func dimensiona_por_escala() -> bool:
	return true


# El CUERPO en planta (ancho, largo). Aqui SI manda el caparazon: a diferencia de la araña, este
# bicho es todo bulto y lo que estorba es justo lo que se ve. Fuera quedan la PALA y las ANTENAS,
# que sobresalen por delante y no son cuerpo -- con la pala se pasaba de las 32 unidades de vano de
# un pasillo y se quedaba trabado, que es la leccion del trent.
#
# Sale casi cuadrado (24,6 x 31,2 a su escala), o sea por debajo del 1.3 de proporcion que hace que
# enemy.gd gire la colision. Es lo correcto: un escarabajo estorba lo mismo se ponga como se ponga.
static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	var ancho: float = maxf(ELITROS_R.x, PATA_ANCLA_X + FEMUR_R0) * 2.0
	var largo: float = (CABEZA.y + CABEZA_R.y) - (ELITROS.y - ELITROS_R.y)
	return Vector2(ancho, largo) * escala


static func _celdas(escala: float) -> int:
	var lado: int = int(ceil(LARGO_MUNDO * escala * LIENZO_FACTOR / SpriteLienzo.UNIDADES_POR_CELDA))
	return lado + (lado % 2)      # par, para que el centro caiga limpio


static func generar(color: Color = Color(0.30, 0.40, 0.28), escala: float = 1.0) -> SpriteFrames:
	# cuantizar_hsv y no cuantizar a secas: el verde oliva es de los colores apagados a los que el
	# redondeo canal a canal les cambia el TONO (al Rey rata lo dejo verde y al jabali gris).
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
	var lado: int = _celdas(esc)
	var sf: SpriteFrames = SpriteLienzo.montar_frames(
		anims, SpriteLienzo.paleta(_colores(col)), lado, lado)
	_cache[clave] = sf
	return sf


# Quieto: respira y mueve las antenas. El cuerpo casi no se mueve -- es una placa de metal -- y lo
# unico que dice que esta vivo son las antenas tanteando.
static func _montar_idle(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return {"avance": 0.0, "estira": 1.0 + 0.015 * sin(TAU * t), "fase": t, "paso": 0.10,
			"agacha": 0.0, "antena": sin(TAU * t), "tumba": 0.0}
	_montar_animacion(anims, esc, "idle", true, 3.0, pose, false)


# Andando: TRIPODE ALTERNO, que es como anda un insecto de seis patas -- se apoya en tres (dos de un
# lado y una del otro) mientras mueve las otras tres. A 7 fps: es lento (velocidad base 3.5, de las
# mas bajas del juego) y pesado, y el caparazon apenas cabecea.
static func _montar_walk(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return {"avance": 0.0, "estira": 1.0, "fase": t, "paso": 1.0,
			"agacha": 0.04 * (1.0 - cos(TAU * t * 2.0)), "antena": 0.4 * sin(TAU * t),
			"tumba": 0.0}
	_montar_animacion(anims, esc, "walk", true, 7.0, pose, false)


# SE APLASTA CONTRA EL SUELO y sale empujando con la pala. No salta como la araña ni corre como el
# jabali: se agacha, coge sitio y ARRASTRA su peso hacia delante -- el avance arranca tarde pero no
# se para, que es lo que cuenta que lo que viene es una placa de metal.
# NO es periodica, asi que va por TRAMOS.
static func _montar_embestida(anims: Array, esc: float) -> void:
	var agacha_keys := [[0.0, 0.0], [0.26, 1.0], [0.46, 0.85], [0.74, 0.30], [1.0, 0.12]]
	var avance_keys := [[0.0, 0.0], [0.26, -1.4], [0.46, 1.6], [0.74, 8.4], [0.88, 9.5], [1.0, 6.8]]
	var pose := func(t: float) -> Dictionary:
		return {"avance": SpriteLienzo.tramos(t, avance_keys) * (LUNGE_DIST / 9.5),
			"estira": 1.0, "fase": 0.0, "paso": 0.0,
			"agacha": SpriteLienzo.tramos(t, agacha_keys), "antena": 0.0, "tumba": 0.0}
	_montar_animacion(anims, esc, "embestida", false, 10.0, pose, true)


# MORIRSE. OCHO fotogramas en UNA sola direccion: la muerte solo se ve en la pantalla de combate, y
# ahi al bicho se le mira siempre de frente. Para el mapa esta 'cadaver'.
#
# PATAS ARRIBA. Un escarabajo muerto se queda con el vientre al aire: no cae de costado como el
# jabali ni se hace un ovillo como la araña, DA LA VUELTA ENTERA. 'tumba' llega a 2.0 (dos cuartos
# de vuelta = media vuelta) y las patas se doblan hacia lo que ahora es arriba.
#
# EL 'rumbo' NO ES DECORACION: el eje sobre el que vuelca va del morro a la grupa y de frente apunta
# a la camara, asi que sin girarlo un poco hacia el perfil la vuelta se ve mucho menos. Es la misma
# cuenta que el jabali.
#
# Y va con un BOTE: al llegar arriba (0.62) se pasa y vuelve, porque un bicho blindado que cae de
# espaldas rebota. Sin eso la vuelta sale como una interpolacion y parece que se tumba a proposito.
static func _pose_muerte(t: float) -> Dictionary:
	var tumba_keys := [[0.0, 0.0], [0.16, 0.14], [0.34, 0.62], [0.50, 1.30],
		[0.62, 2.14], [0.76, 1.92], [0.88, 2.04], [1.0, 2.0]]
	var rumbo_keys := [[0.0, 0.0], [0.16, 0.10], [0.34, 0.40], [0.50, 0.68], [0.70, 0.82], [1.0, 0.85]]
	# El apoyo lo levanta mientras rueda, para que gire SOBRE el suelo y no dentro de el.
	var apoyo_keys := [[0.0, 0.0], [0.16, 0.4], [0.34, 2.2], [0.50, 4.0], [0.62, 4.8], [1.0, 4.4]]
	# Las patas ceden primero (se hunde) y luego se encogen hacia el cielo.
	var agacha_keys := [[0.0, 0.0], [0.16, 0.6], [0.34, 0.9], [0.62, 0.5], [1.0, 0.35]]
	var patas_keys := [[0.0, 0.0], [0.34, 0.35], [0.62, 0.85], [1.0, 1.0]]
	return {"avance": 0.0, "estira": 1.0, "fase": 0.0, "paso": 0.0,
		"agacha": SpriteLienzo.tramos(t, agacha_keys), "antena": 0.0,
		"tumba": SpriteLienzo.tramos(t, tumba_keys),
		"rumbo": SpriteLienzo.tramos(t, rumbo_keys) * PI * 0.5,
		"apoyo": SpriteLienzo.tramos(t, apoyo_keys),
		"encoge": SpriteLienzo.tramos(t, patas_keys)}


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


# ENCAJAR UN GOLPE. Cuatro fotogramas en UNA direccion y EMPEZANDO YA GOLPEADO: el frame 0 es el
# impacto. Un golpe no tiene anticipacion, y con cuatro marcos un fotograma de espera se comeria la
# animacion entera.
#
# APENAS SE MUEVE: se hunde sobre las patas y vuelve. Es lo mismo que hace el jabali y por lo mismo
# -- es una mole --, salvo que este ni siquiera sacude la cabeza: no tiene cuello que sacudir.
static func _montar_encaje(anims: Array, esc: float) -> void:
	var retro_keys := [[0.0, 1.0], [0.34, 0.40], [0.67, 0.10], [1.0, 0.0]]
	var agacha_keys := [[0.0, 0.85], [0.34, 0.22], [0.67, 0.06], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		return {"avance": -SpriteLienzo.tramos(t, retro_keys) * (LUNGE_DIST * ENCAJE_RETRO),
			"estira": 1.0, "fase": 0.0, "paso": 0.0,
			"agacha": SpriteLienzo.tramos(t, agacha_keys), "antena": 0.0, "tumba": 0.0}
	# LOS BICHOS ENCAJAN A 18 fps: es la duracion que espera CombatFX.T_ENCAJE.
	_montar_animacion(anims, esc, "encaje", false, 18.0, pose, true, 1, 4)


static func _montar_animacion(anims: Array, esc: float, nombre: String,
		loop: bool, fps: float,
		pose_fn: Callable, ultimo_incluido: bool, dirs: int = 8, marcos: int = FRAMES) -> void:
	var divisor: float = float(marcos - 1) if ultimo_incluido else float(marcos)
	for dir in dirs:
		var plantillas: Array = []
		for i in marcos:
			# La GEOMETRIA se cachea por (animacion, frame, direccion, escala) y NO por color: otro
			# escarabajo de otro tono reusa estas plantillas y solo repinta.
			var clave: String = "%s_%d_%d_%.2f" % [nombre, i, dir, esc]
			var plant: PackedByteArray = _cache_plantillas.get(clave, PackedByteArray())
			if plant.is_empty():
				plant = _plantilla(dir, pose_fn.call(float(i) / divisor), esc)
				_cache_plantillas[clave] = plant
			plantillas.append(plant)
		anims.append({"nombre": "%s_%d" % [nombre, dir], "loop": loop, "fps": fps,
			"plantillas": plantillas})


# METAL: lo que hace falta es OSCURECER, no desaturar. Un caparazon metalico es una superficie
# oscura que solo se ve por donde le da la luz, y ese contraste lo pone el BRILLO -- si la chapa ya
# es clara, no queda sitio para el reflejo y sale un verde de aguacate, un bicho blando.
#
# PERO LA SATURACION HAY QUE SUBIRLA, como en la araña y el jabali, y por partida doble: el color
# que llega aqui NO es el de la ficha, es 'color_visual', que ya viene aclarado hacia el blanco
# segun la 't' del bicho -- o sea desaturado de fabrica. Bajandosela ademas, el escarabajo salia
# GRIS PIEDRA y se le perdia el verde entero.
static func _metal(color: Color) -> Color:
	var out := Color.from_hsv(color.h, minf(1.0, color.s * 1.30 + 0.08), color.v * 0.80)
	out.a = color.a
	return out


# Los colores de cada Tono, EN EL ORDEN DEL ENUM (contrato con SpriteLienzo.paleta).
static func _colores(color: Color) -> Array:
	var c: Color = _metal(color)
	return [
		Color(0, 0, 0, 0),                    # VACIO
		Color(0, 0, 0, 0.22),                 # SOMBRA_SUELO
		c.darkened(0.72),                     # BORDE
		c.darkened(0.55),                     # PATA
		c.darkened(0.38),                     # SOMBRA (el faldon del caparazon, en penumbra)
		c,                                    # BASE
		# El LOMO tira a un GRIS VERDOSO FRIO y no a un verde claro: lo que se aclara en una chapa
		# pintada pierde color, no gana. Aclarandolo hacia el propio verde salia una hoja.
		c.lerp(Color(0.66, 0.72, 0.68), 0.30),                # LOMO (la curva del caparazon)
		# EL BRILLO ES LO QUE LO HACE DE HIERRO. Muy claro y FRIO (tira a azul, no a amarillo): un
		# reflejo especular no lleva el color de lo que refleja. Puesto en un verde claro salia una
		# hoja mojada.
		Color(0.90, 0.95, 0.94),                              # BRILLO
		c.darkened(0.66),                     # COSTURA (la raya que parte los elitros)
		# LA PALA en acero desnudo, mas clara y mas gris que el caparazon: es la parte con la que
		# escarba, o sea la que lleva el verde raspado.
		c.lerp(Color(0.72, 0.76, 0.74), 0.55),                # PALA_T
		Color(0.95, 0.78, 0.30),              # OJO_T (ambar; en un bicho verde el amarillo canta)
	]


# ------------------------------------------------------------
#  GEOMETRIA
# ------------------------------------------------------------

# Un punto de la curva de un tramo de pata (bezier cuadratica: arranque, codo, final).
static func _curva(a: Vector3, codo: Vector3, b: Vector3, f: float) -> Vector3:
	var g: float = 1.0 - f
	return a * (g * g) + codo * (2.0 * g * f) + b * (f * f)


# Las PIEZAS del escarabajo para una pose, ya proyectadas a pantalla. El orden ES la profundidad: de
# lo mas bajo (sombra, patas) a lo mas alto (caparazon, costura, brillo, cabeza, antenas).
static func _piezas(dir: int, pose: Dictionary, esc: float) -> Array:
	# RUMBO: un giro EXTRA en planta, encima del de la direccion. Solo lo usa la muerte, para que la
	# vuelta de campana se vea (de frente, el eje sobre el que vuelca apunta a la camara).
	var ang: float = DIR_VECS[dir].angle() - DIR_VECS[0].angle() + float(pose.get("rumbo", 0.0))
	var u: float = esc / SpriteLienzo.UNIDADES_POR_CELDA
	var centro: float = float(_celdas(esc)) * 0.5
	var estira: float = float(pose["estira"])
	var agacha: float = float(pose["agacha"])
	var avance: float = float(pose["avance"])
	var fase: float = float(pose["fase"])
	var paso: float = float(pose["paso"])
	var antena_f: float = float(pose["antena"])
	# VOLCAR, en cuartos de vuelta sobre el eje morro-grupa: 1.0 = de costado, 2.0 = patas arriba.
	# Y 'apoyo', lo que hay que subirlo despues para que ruede SOBRE el suelo y no dentro.
	var tumba: float = float(pose.get("tumba", 0.0)) * PI * 0.5
	var apoyo: float = float(pose.get("apoyo", 0.0))
	var encoge: float = float(pose.get("encoge", 0.0))
	var ct: float = cos(tumba)
	var st: float = sin(tumba)

	# Agachado = mas bajo y un pelin mas ancho: el caparazon se aplasta contra el suelo.
	var largo: float = estira
	var ancho: float = 1.0 + 0.06 * agacha
	var alto: float = 1.0 - 0.26 * agacha

	var piezas: Array = []
	# EL AVANCE SE ROTA UNA VEZ Y LO LLEVAN TODAS LAS PIEZAS POR IGUAL (ver la trampa del meceo del
	# trent): sumarlo a la Y local antes de rotar solo funciona si TODAS las piezas giran.
	var desp := Vector2(0.0, avance).rotated(ang)

	var poner := func(local: Vector3, r: Vector3, tono: int, solo_sobre: Array = [],
			en_suelo: bool = false) -> void:
		# TUMBAR, lo primero: gira el punto en el plano ANCHO-ALTURA, o sea alrededor del eje que va
		# del morro a la grupa. Lo que era el lomo acaba mirando al suelo.
		# 'en_suelo' se lo salta: es la sombra de contacto, y el suelo ni vuelca ni sube.
		var lx: float = local.x
		var lz: float = local.z
		if tumba != 0.0 and not en_suelo:
			lx = local.x * ct + local.z * st
			lz = -local.x * st + local.z * ct
		var p := Vector2(lx * ancho, local.y * largo)
		var rot: Vector2 = p.rotated(ang) + desp
		var z: float = 0.0 if en_suelo else lz * alto + apoyo
		var sx: float = centro + rot.x * u
		var sy: float = centro + (rot.y * SpriteLienzo.COS_CAM - z * SpriteLienzo.SIN_CAM) * u
		var ry: float = r.y * largo
		# EL RADIO TAMBIEN GIRA: al volcar, el semieje a lo ANCHO pasa a ser el vertical y al reves.
		# Sin esto el escarabajo patas arriba sale igual de alto que de pie, y como es un domo BAJO y
		# ANCHO se nota mucho mas que en el jabali. Con |sen| como mezcla, media vuelta deja la forma
		# como estaba -- que es justo lo correcto: boca abajo mide lo mismo que boca arriba.
		var mezcla: float = absf(st)
		var rx: float = r.x if en_suelo else lerpf(r.x, r.z, mezcla)
		var rz: float = r.z if en_suelo else lerpf(r.z, r.x, mezcla)
		piezas.append({"pos": Vector2(sx, sy), "radio": Vector2(rx * ancho * u, ry * u),
			"gira_forma": true, "tono": tono, "ang": ang,
			"persp": 1.0 if en_suelo else SpriteLienzo.persp_de(ry, rz * alto),
			"solo_sobre": solo_sobre})

	# SOMBRA DE CONTACTO, lo primero (va debajo). A ALTURA CERO: acompaña al bicho por el suelo
	# cuando embiste pero no sube con el, y esa separacion es lo que se lee como estar en el aire.
	poner.call(Vector3(0.0, ELITROS.y, 0.0),
		Vector3(ELITROS_R.x * 1.02, ELITROS_R.y * 1.06, 0.0), Tono.SOMBRA_SUELO, [], true)

	# --- LAS SEIS PATAS ---
	for s in 2:
		var lado: float = -1.0 if s == 0 else 1.0
		for k in PATA_ANCLA_Y.size():
			# TRIPODE ALTERNO: se apoya en tres patas (dos de un lado y la de en medio del otro)
			# mientras mueve las otras tres. Es como anda un insecto de seis patas, y sale solo con
			# desfasar por (k + lado): en un costado quedan las 0 y 2, y en el otro la 1.
			var desfase: float = 0.0 if (k + s) % 2 == 0 else 0.5
			var giro: float = TAU * (fase + desfase)
			var vaiven: float = sin(giro) * paso * PASO_LARGO
			var levanta: float = maxf(0.0, cos(giro)) * paso * PASO_ALTO

			var ancla := Vector3(lado * PATA_ANCLA_X, PATA_ANCLA_Y[k], PATA_ANCLA_Z)
			var punta := Vector3(lado * (PATA_ANCLA_X + PATA_ALCANCE),
				PATA_ANCLA_Y[k] + PATA_ABRE[k] + vaiven, levanta)
			var rodilla := Vector3(lado * (PATA_ANCLA_X + PATA_ALCANCE * PATA_RODILLA_F),
				lerpf(ancla.y, punta.y, 0.45), PATA_RODILLA_Z)
			# MUERTO, LAS PATAS SE DOBLAN SOBRE EL VIENTRE: hacia dentro y HACIA ABAJO (z bajo).
			#
			# HACIA ABAJO Y NO HACIA ARRIBA, que es el error que parece lo contrario de lo que se
			# quiere. El bicho acaba VOLCADO, asi que todo lo que aqui apunte hacia arriba acaba
			# apuntando al suelo: encogiendolas hacia el cielo, el escarabajo muerto salia con las
			# seis patas metidas DEBAJO del caparazon. Dobladas sobre el vientre, la propia vuelta de
			# campana ya las pone al aire -- que es justo la estampa que se busca, y sale sola.
			#
			# Escalonadas por 'k' para que se lean las tres y no una mancha (la leccion de la araña).
			if encoge > 0.0:
				punta = punta.lerp(Vector3(lado * (PATA_ANCLA_X - 0.8),
					PATA_ANCLA_Y[k] * 0.70, 0.7 + k * 0.5), encoge)
				rodilla = rodilla.lerp(Vector3(lado * (PATA_ANCLA_X + 2.6),
					PATA_ANCLA_Y[k] * 0.85, 2.2 + k * 0.6), encoge)

			var cod_f: Vector3 = ancla.lerp(rodilla, 0.5) + Vector3(lado * 0.8, 0.0, 0.9)
			var cod_t: Vector3 = rodilla.lerp(punta, 0.5) + Vector3(lado * 1.4, 0.0, 0.7)
			for j in FEMUR_SEGMENTOS:
				var f: float = float(j) / float(FEMUR_SEGMENTOS - 1)
				poner.call(_curva(ancla, cod_f, rodilla, f),
					Vector3.ONE * lerpf(FEMUR_R0, FEMUR_R1, f), Tono.PATA)
			for j in TIBIA_SEGMENTOS:
				var f: float = float(j) / float(TIBIA_SEGMENTOS - 1)
				poner.call(_curva(rodilla, cod_t, punta, f),
					Vector3.ONE * lerpf(TIBIA_R0, TIBIA_R1, f), Tono.PATA)

	# --- EL CUERPO ---
	# El FALDON: el borde bajo del caparazon, en penumbra. Va primero y un pelin mas ancho que los
	# elitros, asi que asoma por debajo como un reborde -- es lo que da grosor a la placa.
	poner.call(Vector3(ELITROS.x, ELITROS.y, ELITROS.z - 0.9),
		Vector3(ELITROS_R.x * 1.03, ELITROS_R.y * 1.02, ELITROS_R.z * 0.72), Tono.SOMBRA)
	poner.call(ELITROS, ELITROS_R, Tono.BASE)
	# LOMO: la curva iluminada del caparazon. Mas alto que su eje (la luz viene de arriba), asi que
	# en pantalla sube y la mitad de abajo se queda en tono base = el costado en penumbra.
	poner.call(Vector3(0.0, ELITROS.y + 0.6, ELITROS.z + ELITROS_R.z * 0.55),
		Vector3(ELITROS_R.x * 0.72, ELITROS_R.y * 0.78, ELITROS_R.z), Tono.LOMO, [Tono.BASE])
	# BRILLO: el reflejo duro. Solo sobre el lomo, para que no se derrame por el costado -- un
	# reflejo que llega hasta el borde deja de leerse como reflejo y parece que el bicho es blanco.
	poner.call(Vector3(0.0, ELITROS.y + 1.2, ELITROS.z + ELITROS_R.z * 0.80),
		BRILLO_R, Tono.BRILLO, [Tono.LOMO])
	# COSTURA: la raya que parte los elitros en dos placas. Encima de todo lo del caparazon, y va
	# DESPUES del brillo para que lo corte por la mitad -- un reflejo partido en dos es lo que dice
	# que ahi hay una junta y no una pintura.
	poner.call(Vector3(0.0, ELITROS.y, ELITROS.z + ELITROS_R.z * 0.88),
		COSTURA_R, Tono.COSTURA, [Tono.LOMO, Tono.BRILLO, Tono.BASE])

	poner.call(PRONOTO, PRONOTO_R, Tono.BASE)
	poner.call(Vector3(0.0, PRONOTO.y, PRONOTO.z + PRONOTO_R.z * 0.55),
		Vector3(PRONOTO_R.x * 0.66, PRONOTO_R.y * 0.72, PRONOTO_R.z), Tono.LOMO, [Tono.BASE])
	poner.call(CABEZA, CABEZA_R, Tono.SOMBRA)

	# QUIEN LE VE LA CARA: de espaldas no se le ven ni los ojos ni las antenas. Con la camara a 45
	# grados un bicho que se aleja enseña la grupa, y eso es lo que hace que se lea de un vistazo si
	# viene o si huye. LA PALA VA EN LA MISMA LISTA: es una placa clara y grande, y dibujandola
	# siempre asomaba por encima del caparazon cuando el bicho se iba -- se leia como una segunda
	# cabeza en el culo, que es el fallo que tuvo el jabali con los colmillos.
	#
	# Y muerto tampoco: patas arriba lo que se ve es el vientre.
	var frente: float = DIR_VECS[dir].y
	var de_cara: bool = frente > -0.5 and encoge < 0.5

	if de_cara:
		poner.call(PALA, PALA_R, Tono.PALA_T)
		for lado in [-1.0, 1.0]:
			poner.call(Vector3(lado * PICO_X, PICO.y, PICO.z), PICO_R, Tono.PALA_T)

		# ANTENAS: cortas, hacia delante y afuera, con la punta en MAZA (el radio crece hacia el
		# final). Se abren y se cierran un poco con 'antena', que es lo unico que se mueve cuando el
		# bicho esta parado.
		for lado in [-1.0, 1.0]:
			for j in ANTENA_SEGMENTOS:
				var f: float = float(j) / float(ANTENA_SEGMENTOS - 1)
				poner.call(Vector3(lado * (ANTENA.x + f * (2.6 + antena_f * 0.7)),
						ANTENA.y + f * 2.8,
						ANTENA.z + f * (1.9 + antena_f * 0.6)),
					Vector3.ONE * lerpf(ANTENA_R0, ANTENA_R1, f * f), Tono.PATA)

		for lado in [-1.0, 1.0]:
			poner.call(Vector3(lado * OJO.x, OJO.y, OJO.z), OJO_R, Tono.OJO_T)

	# VOLCADO, DOS GRUPOS CAMBIAN DE LADO. El orden de esta lista ES la profundidad -- no hay
	# z-buffer -- y esta escrito para un bicho DE PIE: las patas primero (el caparazon las tapa) y el
	# brillo y la costura al final (son lo mas alto). Patas arriba es justo al reves.
	#
	# SE MUEVEN SOLO ESOS DOS GRUPOS, y no se invierte la lista entera: invertir le da la vuelta
	# tambien a las piezas que se distinguen por DONDE ESTAN A LO LARGO del bicho (el jabali se
	# quedaba sin cabeza asi), y ademas rompe los 'solo_sobre' -- el lomo se pinta sobre BASE, y
	# pintado antes que el caparazon no encuentra nada sobre lo que ir.
	if tumba > PI * 0.5:
		var antes: Array = []
		var enmedio: Array = []
		var despues: Array = []
		for pz in piezas:
			var tn: int = int(pz["tono"])
			if tn == Tono.PATA:
				despues.append(pz)          # al aire: ahora van encima
			elif tn == Tono.BRILLO or tn == Tono.COSTURA:
				antes.append(pz)            # el lomo mira al suelo
			else:
				enmedio.append(pz)
		# La sombra de contacto sigue siendo la primera de todas: es una mancha en el suelo, y el
		# suelo no vuelca.
		piezas = enmedio.slice(0, 1) + antes + enmedio.slice(1) + despues

	return piezas


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
