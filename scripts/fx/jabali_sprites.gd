# ============================================================
#  jabali_sprites.gd  (class_name JabaliSprites)
#  Sprite del JABALI dibujado por codigo, con el motor comun (SpriteLienzo) y la camara de 45 grados
#  que comparten todos los bichos. Aparece en los pisos 3-6.
#
#  ES UN CUADRUPEDO ALARGADO, asi que va por el patron de la RATA y no por el del slime: el cuerpo
#  ENTERO gira con la direccion, que es lo que hace un animal al cambiar de rumbo. (El slime, que es
#  una bola, no gira: solo giran sus adornos.)
#
#  SU SILUETA, que es lo que hay que acertar: un jabali NO es un cerdo. Lo que lo distingue es
#    * LA CRUZ -- la joroba de los hombros --, que hace que el lomo BAJE de delante hacia atras. Un
#      lomo horizontal se lee como cerdo por mucho colmillo que le pongas.
#    * LAS CERDAS del espinazo, erizadas y oscuras.
#    * LAS PATAS CORTAS Y NEGRAS: el cuerpo casi arrastra por el suelo.
#    * LOS COLMILLOS, curvos hacia arriba.
#
#  Su identidad sale de sus habilidades: "baja la cabeza, ESCARBA una vez y se te viene encima"
#  (embestida), "mete el COLMILLO por debajo del escudo y levanta" (cornada), "se revuelve sobre las
#  PATAS DELANTERAS y machaca" (pisoton). O sea COLMILLOS, MASA y PATAS -- y por eso su embestida
#  empieza escarbando, no agazapandose como la de la rata.
#
#  El TAMAÑO se consigue con MAS CELDAS, no con celdas mas gordas: ver SpriteLienzo.UNIDADES_POR_CELDA.
# ============================================================

extends RefCounted
class_name JabaliSprites

const FRAMES := 8

# --- El jabali mirando al SUR, en unidades de MUNDO (origen = donde toca el suelo, +Y hacia el
# morro, +Z hacia arriba). A escala 1.0 mide unas 28 unidades del morro a la grupa. ---
const LARGO_MUNDO := 28.0

# CUERPO: un barril. Mucho mas ancho que el de la rata -- son doscientos kilos, y eso se dibuja.
const CUERPO := Vector3(0.0, -1.6, 6.6)
const CUERPO_R := Vector3(7.6, 9.6, 6.2)
# LA CRUZ (la joroba de los hombros). Va ADELANTADA y mas ALTA que el cuerpo, y es la pieza que le
# da su silueta: con ella el lomo cae en rampa hacia la grupa. Sin ella es un cerdo.
const CRUZ := Vector3(0.0, 4.0, 10.6)
const CRUZ_R := Vector3(6.9, 6.2, 6.2)
# CABEZA: BAJA y adelantada, nunca alineada con el lomo -- el jabali lleva la cabeza colgando por
# debajo de la cruz, y es la mitad de su estampa.
const CABEZA := Vector3(0.0, 11.4, 5.6)
const CABEZA_R := Vector3(4.2, 5.0, 3.9)
const HOCICO := Vector3(0.0, 15.6, 3.9)
const HOCICO_R := Vector3(2.7, 2.9, 2.3)
const OREJA := Vector3(3.7, 10.2, 9.0)
const OREJA_R := Vector3(1.7, 1.3, 2.0)
const OJO := Vector3(3.1, 12.9, 6.9)
const OJO_R := Vector3(0.8, 0.8, 0.8)

# COLMILLOS: nacen a los lados del hocico y suben CURVANDOSE hacia atras. Se hacen con una cadena
# corta de bolitas, como la cola de la rata: una sola pieza alargada no se curva.
const COLMILLO_BASE := Vector3(2.5, 14.6, 3.6)
const COLMILLO_SEGMENTOS := 5
const COLMILLO_R0 := 1.05
const COLMILLO_R1 := 0.72

# PATAS: cortas, gruesas y CASI NEGRAS. En la referencia son la unica parte oscura de todo el bicho.
const PATA_X := 5.2
const PATA_Y := [5.6, -6.2]                       # delanteras y traseras
const PATA_R := Vector3(2.0, 2.3, 3.3)
const PATA_Z := 3.1

# CERDAS del espinazo: la cresta erizada. Van de la cruz a la grupa, altas delante y bajando.
# OJO CON LA Z: con la camara a 45 grados, para que algo asome N unidades en pantalla hay que
# subirlo 1.41*N en el mundo. Puestas "a la altura del lomo" no asomaba ni una.
const CERDAS := 8
const CERDA_Y0 := 6.0
const CERDA_Y1 := -8.5
const CERDA_R := Vector3(1.15, 1.15, 3.4)
# Cuanto se comprime el escorzo de la cresta (ver 'escorzo' en _piezas).
const CERDA_ESCORZO := 0.30
# Las cerdas van en ZIGZAG a los lados del espinazo, no clavadas en el eje. Puestas todas en x = 0
# se apilaban unas sobre otras vistas de frente y salia UNA RAYA vertical por la coronilla; abiertas,
# de frente se leen como un manojo erizado, que ademas es lo que es una cresta de verdad.
const CERDA_ZIGZAG := 1.35

# COLA: un muñon corto, nada del latigo de la rata.
const COLA := Vector3(0.0, -10.2, 7.4)
const COLA_R := Vector3(1.1, 2.2, 1.1)

const LUNGE_DIST := 9.0            # cuanto viaja en la embestida, en unidades de mundo

# Lienzo CUADRADO y holgado: el bicho gira, asi que lo que manda es su DIAGONAL, y ademas la
# embestida lo desplaza. El numero sale de MEDIR la caja real de los 192 frames, no de calcularla.
const LIENZO_FACTOR := 2.08

# TONOS propios (el motor no sabe que es cada uno; solo mapea indice -> color, ver _colores).
enum Tono { VACIO, SOMBRA_SUELO, BORDE, PATA, SOMBRA, BASE, LOMO, CERDA, HOCICO_T, COLMILLO, OJO_T }

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
	return "jabali_%s_%.2f" % [col.to_html(false), esc]


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(escala: float = 1.0) -> int:
	return _celdas(escala)


static func dimensiona_por_escala() -> bool:
	return true


# El CUERPO en planta (ancho, largo) para la colision. Lo ancho lo marcan las PATAS, que van mas
# abiertas que el barril; lo largo, del morro a la grupa. Los COLMILLOS y las CERDAS no cuentan: son
# adornos que sobresalen, y hacerle chocar con las paredes por un colmillo seria absurdo.
static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	var ancho: float = (PATA_X + PATA_R.x) * 2.0
	var largo: float = (HOCICO.y + HOCICO_R.y) - (CUERPO.y - CUERPO_R.y)
	return Vector2(ancho, largo) * escala


static func _celdas(escala: float) -> int:
	var lado: int = int(ceil(LARGO_MUNDO * escala * LIENZO_FACTOR / SpriteLienzo.UNIDADES_POR_CELDA))
	return lado + (lado % 2)      # par, para que el centro caiga limpio


static func generar(color: Color = Color(0.35, 0.26, 0.22), escala: float = 1.0) -> SpriteFrames:
	# cuantizar_hsv y no cuantizar a secas: el jabali es de color apagado (marron oscuro) y redondear
	# canal a canal le cambiaria el TONO -- dos canales parecidos caen en el mismo escalon y sale un
	# gris o un oliva. Le paso lo mismo al Rey rata en su dia.
	var col: Color = SpriteLienzo.cuantizar_hsv(color, COLOR_PASOS)
	var esc: float = snappedf(escala, 0.05)      # se cuantiza tambien, o el cache no acierta
	var clave: String = _clave(col, esc)
	if _cache.has(clave):
		return _cache[clave]
	# Todo en UN atlas recortado (ver SpriteLienzo.montar_frames): en el jabali, el 84% de cada frame
	# del lienzo completo era aire transparente.
	var anims: Array = []
	_montar_idle(anims, esc)
	_montar_walk(anims, esc)
	_montar_embestida(anims, esc)
	var lado: int = _celdas(esc)
	var sf: SpriteFrames = SpriteLienzo.montar_frames(
		anims, SpriteLienzo.paleta(_colores(col)), lado, lado)
	_cache[clave] = sf
	return sf


# Quieto: resopla. Respira hondo y mueve poco la cabeza -- es un bicho pesado, no uno nervioso.
static func _montar_idle(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return {"avance": 0.0, "estira": 1.0 + 0.02 * sin(TAU * t), "patas": 0.0,
			"agacha": 0.0, "cabeza": 0.35 * sin(TAU * t), "escarba": 0.0}
	_montar_animacion(anims, esc, "idle", true, 5.0, pose, false)


# Andando: trote corto y pesado. A 8 fps -- ni el paseo del slime ni el nervio de la rata (que va a
# 10): anda a 40-65, o sea rapido para lo que pesa, pero el paso es corto porque las patas lo son.
static func _montar_walk(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return {"avance": 0.0, "estira": 1.0 + 0.03 * sin(TAU * t * 2.0), "patas": sin(TAU * t),
			"agacha": 0.06 * (1.0 - cos(TAU * t)), "cabeza": 0.9 * sin(TAU * t), "escarba": 0.0}
	_montar_animacion(anims, esc, "walk", true, 8.0, pose, false)


# ESCARBAR -> lanzarse -> impacto -> recuperar. Es la unica embestida del juego que empieza
# escarbando, y es literalmente lo que dice su habilidad: "baja la cabeza, escarba una vez y se te
# viene encima". La rata se agazapa; este avisa raspando el suelo, que da mas miedo.
# NO es periodica, asi que va por TRAMOS.
static func _montar_embestida(anims: Array, esc: float) -> void:
	var avance_keys := [[0.0, 0.0], [0.30, -1.6], [0.62, 6.5], [0.80, 7.4], [1.0, 5.2]]
	var estira_keys := [[0.0, 1.0], [0.30, 0.94], [0.62, 1.14], [0.80, 0.92], [1.0, 1.0]]
	# 'agacha' baja el cuerpo Y la cabeza. En el tramo de vuelo va a tope: embiste con la testuz.
	var agacha_keys := [[0.0, 0.0], [0.30, 0.55], [0.62, 0.85], [0.80, 0.45], [1.0, 0.1]]
	# 'escarba': la pata delantera raspa el suelo hacia atras, solo en el aviso.
	var escarba_keys := [[0.0, 0.0], [0.16, 1.0], [0.30, 0.0], [1.0, 0.0]]
	var pose := func(t: float) -> Dictionary:
		return {"avance": SpriteLienzo.tramos(t, avance_keys) * (LUNGE_DIST / 7.4),
			"estira": SpriteLienzo.tramos(t, estira_keys), "patas": 0.0,
			"agacha": SpriteLienzo.tramos(t, agacha_keys),
			"cabeza": -1.8 * SpriteLienzo.tramos(t, agacha_keys),
			"escarba": SpriteLienzo.tramos(t, escarba_keys)}
	_montar_animacion(anims, esc, "embestida", false, 11.0, pose, true)


static func _montar_animacion(anims: Array, esc: float, nombre: String,
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
			# La GEOMETRIA se cachea por (animacion, frame, direccion, escala) y NO por color: otro
			# jabali de otro tono reusa estas plantillas y solo repinta. Es lo que evita que entrar a
			# un piso lleno de bichos congele el juego.
			var clave: String = "%s_%d_%d_%.2f" % [nombre, i, dir, esc]
			var plant: PackedByteArray = _cache_plantillas.get(clave, PackedByteArray())
			if plant.is_empty():
				plant = _plantilla(dir, pose_fn.call(float(i) / divisor), esc)
				_cache_plantillas[clave] = plant
			plantillas.append(plant)
		anims.append({"nombre": "%s_%d" % [nombre, dir], "loop": loop, "fps": fps,
			"plantillas": plantillas})


# El marron del jabali es tan apagado que, cuantizado, se le va el tono y sale un GRIS de raton.
# Se le sube un poco la saturacion para devolverle lo terroso sin cambiarle el color de la ficha
# (que lo usa el resto del juego: particulas, tinte por fuerza, marcador de la barra de accion).
static func _calido(color: Color) -> Color:
	var out := Color.from_hsv(color.h, minf(1.0, color.s * 1.25 + 0.10), color.v)
	out.a = color.a
	return out


# Los colores de cada Tono, EN EL ORDEN DEL ENUM (contrato con SpriteLienzo.paleta).
static func _colores(color: Color) -> Array:
	return [
		Color(0, 0, 0, 0),                    # VACIO
		Color(0, 0, 0, 0.22),                 # SOMBRA_SUELO
		_calido(color).darkened(0.68),        # BORDE
		# PATA: casi negra. En la referencia las patas son la unica parte oscura del bicho, y ese
		# contraste es lo que hace que el cuerpo se lea claro y macizo por encima.
		_calido(color).darkened(0.62),        # PATA
		_calido(color).darkened(0.30),        # SOMBRA (el costado, en penumbra)
		_calido(color),                       # BASE
		# El LOMO se aclara HACIA UN OCRE, no hacia el blanco: 'lightened' desatura, y sobre un marron
		# ya apagado el resultado era un gris pardo de raton. Un jabali tiene el pelo terroso.
		_calido(color).lerp(Color(0.78, 0.62, 0.42), 0.38),   # LOMO (la rampa de la cruz al lomo)
		_calido(color).darkened(0.52),        # CERDA (la cresta erizada del espinazo)
		_calido(color).lerp(Color(0.86, 0.60, 0.56), 0.50),   # HOCICO_T (el morro, rosado)
		Color(0.93, 0.90, 0.79),              # COLMILLO (hueso, y bien claro: es su marca)
		Color(0.10, 0.08, 0.07),              # OJO_T
	]


# ------------------------------------------------------------
#  GEOMETRIA
# ------------------------------------------------------------

# Las PIEZAS del jabali para una pose, ya proyectadas a pantalla. El orden ES la profundidad: se
# pintan en ese orden y las ultimas tapan a las primeras, asi que va de lo mas bajo (sombra, patas)
# a lo mas alto y cercano (cerdas, cabeza, colmillos, ojos).
static func _piezas(dir: int, pose: Dictionary, esc: float) -> Array:
	var ang: float = DIR_VECS[dir].angle() - DIR_VECS[0].angle()
	var u: float = esc / SpriteLienzo.UNIDADES_POR_CELDA    # unidades de mundo -> celdas
	var centro: float = float(_celdas(esc)) * 0.5
	var estira: float = float(pose["estira"])
	var agacha: float = float(pose["agacha"])
	var avance: float = float(pose["avance"])
	var fase_patas: float = float(pose["patas"])
	var cabeza_y: float = float(pose["cabeza"])
	var escarba: float = float(pose["escarba"])

	# Agazapado = mas bajo y algo mas largo (se estira hacia delante al bajar la testuz).
	var largo: float = estira * (1.0 + 0.06 * agacha)
	var ancho: float = 1.0 / maxf(0.5, estira)
	var alto: float = 1.0 - 0.22 * agacha

	var piezas: Array = []
	# EL AVANCE SE ROTA UNA VEZ Y LO LLEVAN TODAS LAS PIEZAS POR IGUAL. Sumarlo a la Y local antes de
	# rotar solo funciona si TODAS giran; en cuanto una no lo hace, se va disparada hacia el sur de
	# la pantalla mientras el resto del bicho sale hacia donde de verdad mira.
	var desp := Vector2(0.0, avance).rotated(ang)
	# local (x ancho, y largo, z altura, en unidades de mundo) -> celda de pantalla.
	# El aplastado va DESPUES de girar: lo hace SpriteLienzo.elipse con 'persp', y el valor exacto lo
	# da persp_de a partir de los semiejes. Calcularlo antes -- deformando el radio aqui y dejando
	# que el motor rotara una elipse ya achatada -- hacia que de perfil el cuerpo saliera mas CORTO
	# de lo que mide.
	# 'escorzo' < 1 comprime lo que la PROFUNDIDAD sube o baja esa pieza en pantalla. Lo necesita la
	# CRESTA: son ocho cerdas en fila a lo largo del lomo, y de frente la de atras subia tanto que
	# las ocho se apilaban en una raya vertical saliendo por encima de la cabeza -- una antena, no un
	# espinazo. Comprimido, la cresta se lee como una linea de puas desde los ocho lados.
	var poner := func(local: Vector3, r: Vector3, tono: int, solo_sobre: Array = [],
			escorzo: float = 1.0) -> void:
		var p := Vector2(local.x * ancho, local.y * largo)
		var rot: Vector2 = p.rotated(ang) + desp
		var z: float = local.z * alto
		var sx: float = centro + rot.x * u
		var sy: float = centro + (rot.y * escorzo * SpriteLienzo.COS_CAM
			- z * SpriteLienzo.SIN_CAM) * u
		var ry: float = r.y * largo
		piezas.append({"pos": Vector2(sx, sy), "radio": Vector2(r.x * ancho * u, ry * u),
			"gira_forma": true, "tono": tono, "ang": ang,
			"persp": SpriteLienzo.persp_de(ry, r.z * alto), "solo_sobre": solo_sobre})

	# SOMBRA DE CONTACTO, lo primero (va debajo). A ALTURA CERO: acompaña al bicho por el suelo
	# cuando se lanza, pero no sube con el, y esa separacion es lo que se lee como estar en el aire.
	poner.call(Vector3(0.0, CUERPO.y, 0.0),
		Vector3(CUERPO_R.x * 1.05, CUERPO_R.y * 1.05, 0.0), Tono.SOMBRA_SUELO)

	# PATAS: cortas y oscuras. Al trotar, delanteras y traseras van en contrafase. La DELANTERA
	# ademas ESCARBA en el aviso de la embestida: raspa hacia atras y se hunde un poco.
	for lado in [-1.0, 1.0]:
		for k in PATA_Y.size():
			var swing: float = fase_patas * (1.0 if k == 0 else -1.0) * lado
			var y: float = PATA_Y[k] + swing * 1.2
			var z: float = PATA_Z
			if k == 0:
				y -= escarba * 2.6           # la delantera va hacia atras al escarbar
				z -= escarba * 0.7
			poner.call(Vector3(lado * PATA_X, y, z), PATA_R, Tono.PATA)

	# COLA: un muñon.
	poner.call(COLA, COLA_R, Tono.SOMBRA)

	# CUERPO y CRUZ. La cruz va DESPUES para que su bulto se recorte sobre el lomo.
	poner.call(CUERPO, CUERPO_R, Tono.BASE)
	poner.call(CRUZ, CRUZ_R, Tono.BASE)

	# LOMO iluminado: la rampa que baja de la cruz a la grupa. Va MAS ALTO que el eje del cuerpo (la
	# luz viene de arriba), asi que en pantalla queda desplazado hacia arriba y la mitad de abajo se
	# queda en tono base = el costado en penumbra. Solo sobre BASE, para no aclarar patas ni contorno.
	poner.call(Vector3(0.0, CRUZ.y - 2.0, CRUZ.z + CRUZ_R.z * 0.62),
		Vector3(CRUZ_R.x * 0.62, CUERPO_R.y * 0.95, CRUZ_R.z), Tono.LOMO, [Tono.BASE])

	# CERDAS: la cresta del espinazo, de la cruz a la grupa y bajando. Es lo que lo separa de un
	# cerdo, junto con la cruz.
	for k in CERDAS:
		var f: float = float(k) / float(CERDAS - 1)
		var y: float = lerpf(CERDA_Y0, CERDA_Y1, f)
		# La cresta sigue la linea del lomo: alta sobre la cruz y cayendo hacia la grupa.
		var z: float = lerpf(CRUZ.z + CRUZ_R.z * 0.80, CUERPO.z + CUERPO_R.z * 0.62, f)
		var r: float = lerpf(1.0, 0.75, f)
		var zig: float = CERDA_ZIGZAG * (1.0 if k % 2 == 0 else -1.0)
		poner.call(Vector3(zig, y, z + CERDA_R.z * 0.55),
			Vector3(CERDA_R.x * r, CERDA_R.y * r, CERDA_R.z * r), Tono.CERDA, [], CERDA_ESCORZO)

	# QUIEN LE VE LA CARA: de ESPALDAS no se le ven ni los ojos, ni los colmillos, ni la trufa -- con
	# la camara a 45 grados un bicho que se aleja enseña la grupa, y eso es lo que hace que se lea de
	# un vistazo si viene o si huye.
	#
	# Los colmillos van en la MISMA lista que los ojos y no es un detalle: dibujandolos siempre, de
	# espaldas asomaban por encima de la grupa (suben mucho, asi que el cuerpo no los tapa) y se
	# leian como DOS OJOS mirandote desde el culo del bicho.
	var frente: float = DIR_VECS[dir].y
	var lados: Array = [-1.0, 1.0]
	if frente <= -0.5:
		lados = []
	elif frente < -0.2:
		lados = [signf(DIR_VECS[dir].x)]

	# CABEZA y HOCICO. 'cabeza_y' la sube y la baja: al andar cabecea, y en la embestida se hunde.
	var cab := Vector3(CABEZA.x, CABEZA.y, CABEZA.z + cabeza_y)
	poner.call(cab, CABEZA_R, Tono.BASE)
	# El morro va en su tono rosado SOLO si se le ve la cara. De espaldas lo que asoma por encima de
	# la grupa (lleva la cabeza baja, asi que asoma) es la NUCA, y una trufa rosa ahi cantaba como un
	# puntito de color en mitad del lomo.
	poner.call(Vector3(HOCICO.x, HOCICO.y, HOCICO.z + cabeza_y), HOCICO_R,
		Tono.HOCICO_T if not lados.is_empty() else Tono.SOMBRA)

	# OREJAS, pequeñas y hacia atras.
	for lado in [-1.0, 1.0]:
		poner.call(Vector3(lado * OREJA.x, OREJA.y, OREJA.z + cabeza_y), OREJA_R, Tono.SOMBRA)

	# COLMILLOS: nacen junto al hocico y suben curvandose hacia atras. En cadena, como la cola de la
	# rata: una sola elipse alargada no se curva, y un colmillo recto no se lee como colmillo.
	for lado in lados:
		for k in COLMILLO_SEGMENTOS:
			var f: float = float(k) / float(COLMILLO_SEGMENTOS - 1)
			poner.call(Vector3(lado * (COLMILLO_BASE.x + f * 0.5),
					COLMILLO_BASE.y - f * f * 1.9,          # se curva hacia ATRAS
					COLMILLO_BASE.z + cabeza_y + f * 3.4),  # y sube
				Vector3.ONE * lerpf(COLMILLO_R0, COLMILLO_R1, f), Tono.COLMILLO)

	# OJOS, con la misma regla.
	for l in lados:
		poner.call(Vector3(l * OJO.x, OJO.y, OJO.z + cabeza_y), OJO_R, Tono.OJO_T)

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
