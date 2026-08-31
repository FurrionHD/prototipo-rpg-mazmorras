# ============================================================
#  ciempies_sprites.gd  (class_name CiempiesSprites)
#  El CIEMPIES CARMESI (piso 7-11) dibujado por codigo. Solo geometria: el motor esta en
#  SpriteLienzo y quien reparte los generadores es SpritesEnemigo (por NOMBRE: los tres insectos
#  comparten familia y no se parecen en nada).
#
#  ESTE NO TIENE CUERPO: TIENE UNA CADENA. La araña y el escarabajo son un bulto con adornos
#  colgando, y su geometria sale de colocar piezas alrededor de un centro. Aqui no hay centro --
#  el bicho ES una fila de anillos que serpentea, y TODO (las patas, las placas del lomo, la
#  cabeza) cuelga de la posicion que ocupe su anillo en cada fotograma. Por eso aqui hay una
#  funcion '_traza' que no tienen los otros dos: dice donde esta el anillo i.
#
#  Y POR ESO EL ORDEN DE PINTADO NO PUEDE IR CABLEADO. En los otros dos el orden de las piezas se
#  escribe a mano de lo mas bajo a lo mas alto y ya esta. Un cuerpo que serpentea se cruza CONSIGO
#  MISMO: en media onda el anillo 4 esta delante del 5 y en la otra media, detras. Los anillos se
#  ordenan por su altura EN PANTALLA, en cada fotograma (ver el final de _piezas).
#
#  LAS PATAS SON AMARILLAS sobre un cuerpo rojo oscuro, como el bicho de verdad. No es un capricho:
#  del mismo tono que el cuerpo se pierden, y lo que tiene que leerse de un ciempies a la primera es
#  que tiene MUCHAS patas.
#
#  MUERE ENROSCADO. La araña se hace un ovillo y el escarabajo vuelca patas arriba; este se enrolla
#  en espiral, que es lo que hace un ciempies muerto. Tres bichos del mismo piso, tres muertes.
# ============================================================

extends RefCounted
class_name CiempiesSprites

const FRAMES := 8

# --- El ciempies mirando al SUR, en unidades de MUNDO (origen = donde toca el suelo, +Y hacia la
# cabeza, +Z hacia arriba). ---
const LARGO_MUNDO := 34.0

# LA CADENA: cuantos anillos y cuanto hay de uno al siguiente. El anillo 0 es la CABEZA.
#
# EL PASO ES CORTO A PROPOSITO (1,55 contra un grosor de 4,8): los anillos se solapan mucho y el
# cuerpo sale como un tubo liso, sin costuras. La segmentacion NO la hacen los huecos entre anillos
# -- la hacen las PLACAS del lomo, que si van separadas (ver PLACA_R). Al reves, con anillos
# separados, el bicho sale como un collar de cuentas.
const SEGMENTOS := 15
const PASO := 1.55
const CUERPO_Y0 := 8.6              # donde cae el anillo 0 (la cabeza)
const CUERPO_Z := 2.0               # va PEGADO al suelo: es un bicho plano
# El grosor de cada anillo, de la cabeza a la cola: gordo delante y afilandose al final.
const ANILLO_R0 := Vector3(2.90, 2.40, 2.10)
const ANILLO_R1 := Vector3(1.35, 1.20, 1.05)
# LAS PLACAS del lomo, una por anillo. CORTAS, para que entre una y otra quede hueco: ese hueco ES
# la segmentacion del bicho.
# Y CORTAS DE VERDAD: con 0,70 de largo el hueco contra el paso de 1,55 era de 0,15 unidades, o sea
# ni un pixel, y las once placas salian como una tira continua mas clara -- un lomo pintado, no un
# bicho segmentado. A 0,45 el hueco es de un pixel largo y se cuentan los anillos.
const PLACA_R := Vector3(1.90, 0.45, 0.60)

# LA ONDA: cuanto se desvia lateralmente cada anillo y cuanto va desfasado del anterior. El desfase
# reparte algo menos de dos ondas completas a lo largo del bicho -- con una sola el ciempies parece
# un gusano, y con cuatro parece un muelle.
const AMPLITUD := 2.2
const DESFASE_ONDA := 0.16

# PATAS: un par por anillo (menos la cabeza). Cortas, finas y MUCHAS.
const PATA_X := 1.5                 # donde se clavan, a los lados del anillo
const PATA_Z := 2.0
# LARGO DE VERDAD. Con 3,2 la punta quedaba a 4,7 del eje contra un cuerpo de 2,9 de ancho: solo
# asomaban 1,8 unidades de pata, y el bicho salia como un chorizo rojo con manchas amarillas en el
# borde. Una pata tiene que verse ENTERA por fuera de la silueta o no es una pata, es un pixel.
const PATA_ALCANCE := 4.6
const PATA_SEGMENTOS := 4
# GRUESAS, Y ESTO ES UNA REGLA DEL MOTOR, no del gusto: 'contornear' convierte en BORDE toda celda
# que toque el vacio, asi que a una pieza de menos de TRES CELDAS de ancho no le queda ni un pixel
# de relleno -- se vuelve contorno entera. Con radio 0,80 (2 celdas) las veinte patas amarillas
# salieron como puntitos ROJO OSCURO desperdigados alrededor del bicho. Radio 1,25 = 3 celdas = un
# pixel de amarillo dentro, que es todo lo que hace falta.
const PATA_R0 := 1.15
const PATA_R1 := 0.90
const PATA_PANZA := 0.9             # cuanto abomba la pata hacia fuera y arriba
# ONDA METACRONAL: cada par de patas va un poco por detras del anterior, y el resultado es la ola
# que recorre al bicho de la cabeza a la cola. Es LO QUE HACE QUE PAREZCA UN CIEMPIES andando: con
# todas las patas a la vez es un ciempies de juguete.
const DESFASE_PATAS := 0.30
const PASO_LARGO := 1.5
const PASO_ALTO := 1.1

# CABEZA: antenas largas delante, forcipulas (los ganchos del veneno) debajo, y dos ojillos.
const ANTENA_X := 1.1
const ANTENA_SEGMENTOS := 5
const ANTENA_R0 := 1.05
const ANTENA_R1 := 0.72
const FORCIPULA_X := 1.5
const FORCIPULA_SEGMENTOS := 4
const FORCIPULA_R0 := 1.20
const FORCIPULA_R1 := 0.85
const OJO_X := 1.6
const OJO_R := 0.85

# CERCOS: los dos filamentos de la cola. Son lo que dice cual es el culo del bicho -- sin ellos, un
# ciempies visto de lejos tiene dos cabezas.
const CERCO_X := 0.8
const CERCO_SEGMENTOS := 4
const CERCO_R0 := 0.95
const CERCO_R1 := 0.68

# ALZARSE para atacar: levanta los primeros anillos, como hace un ciempies antes de picar.
const ALZA_ANILLOS := 4
const ALZA_ALTO := 5.5

# ENROSCARSE al morir: la espiral. El radio se cierra de fuera adentro y el paso angular reparte
# algo mas de una vuelta completa entre los once anillos.
const ESPIRAL_R := 7.6
const ESPIRAL_PASO_ANG := 0.48
const ESPIRAL_ANG0 := 0.5

const LUNGE_DIST := 8.5
# Encaja mucho: es largo pero no pesa nada, y un golpe lo manda de lado.
const ENCAJE_RETRO := 0.50

# Lienzo CUADRADO y holgado: gira, y girado en diagonal su largo va por la diagonal del cuadro.
# Ajustado contra los avisos del horno, no calculado.
const LIENZO_FACTOR := 1.70

# TONOS propios (el motor no sabe que es cada uno; solo mapea indice -> color, ver _colores).
enum Tono { VACIO, SOMBRA_SUELO, BORDE, PATA, SOMBRA, BASE, PLACA, FORCIPULA_T, PONZONA, OJO_T }

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
	return "ciempies_%s_%.2f" % [col.to_html(false), esc]


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(escala: float = 1.0) -> int:
	return _celdas(escala)


static func dimensiona_por_escala() -> bool:
	return true


# El CUERPO en planta (ancho, largo). Sale ALARGADO -- proporcion muy por encima del 1.3 --, asi que
# enemy.gd le hara GIRAR la colision con el bicho: de lado ocupa el triple que de frente, igual que
# la rata. Es lo correcto para algo que es basicamente una linea.
#
# El ANCHO lo marcan las PATAS y no el cuerpo, al reves que en la araña: las suyas son cuatro hilos
# larguisimos que pasan por encima de las cosas, y estas son diez patas cortas que van clavadas en
# el suelo a los lados -- eso si es sitio ocupado. Fuera quedan las ANTENAS y los CERCOS, que son
# pelos.
#
# EL LARGO NO LO CAPA EL PASILLO, y esto se creyo al reves durante todo el primer intento: se cablo
# el bicho a 31,5 unidades para no pasar de "las 32 de vano de un pasillo", que es lo que decia la
# nota del trent. Pero los pasillos se cavan con ancho_pasillo = 3 CELDAS (ver
# DungeonGenerator._cavar_h): son 96 px, no 32. El ciempies salio corto -- y por tanto con pocos
# anillos y poco detalle -- por un techo que no existia.
#
# Con 96 de vano hay sitio de sobra hasta girando en un cruce, asi que lo que fija el largo es el
# DIBUJO: cuantos anillos hacen falta para que se lea como un ciempies y no como un gusano.
static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	var ancho: float = maxf(ANILLO_R0.x, PATA_X + PATA_ALCANCE) * 2.0
	var largo: float = ANILLO_R0.y * 2.0 + float(SEGMENTOS - 1) * PASO
	return Vector2(ancho, largo) * escala


static func _celdas(escala: float) -> int:
	var lado: int = int(ceil(LARGO_MUNDO * escala * LIENZO_FACTOR / SpriteLienzo.UNIDADES_POR_CELDA))
	return lado + (lado % 2)      # par, para que el centro caiga limpio


static func generar(color: Color = Color(0.60, 0.15, 0.12), escala: float = 1.0) -> SpriteFrames:
	# cuantizar_hsv y no cuantizar a secas: aunque el carmesi tiene el canal rojo alto (como el
	# slime, que no lo nota), los tonos claros de su paleta si se van de tono con el redondeo RGB.
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


# Quieto: la onda sigue recorriendolo, pero floja, y las patas apenas tantean. Un ciempies parado no
# se queda rigido -- nunca deja de ondular del todo --, y esa inquietud es su caracter.
static func _montar_idle(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return {"avance": 0.0, "fase": t, "onda": 0.42, "paso": 0.20,
			"alza": 0.0, "enrosca": 0.0}
	_montar_animacion(anims, esc, "idle", true, 4.0, pose, false)


# Andando: A 12 fps, EL MAS RAPIDO DEL JUEGO. Es lo que hace un ciempies -- un bicho que se te viene
# encima a una velocidad que no esperas de algo tan bajo --, y la onda va a tope.
static func _montar_walk(anims: Array, esc: float) -> void:
	var pose := func(t: float) -> Dictionary:
		return {"avance": 0.0, "fase": t, "onda": 1.0, "paso": 1.0,
			"alza": 0.0, "enrosca": 0.0}
	_montar_animacion(anims, esc, "walk", true, 12.0, pose, false)


# LEVANTA LA MITAD DELANTERA, se queda un instante en alto y se deja caer con las forcipulas por
# delante. Es lo que hace de verdad, y ademas es el aviso mas claro de los tres bichos del piso: la
# araña se encoge, el escarabajo se agacha, y este se ALZA -- se le ve venir desde lejos.
# NO es periodica, asi que va por TRAMOS.
static func _montar_embestida(anims: Array, esc: float) -> void:
	var alza_keys := [[0.0, 0.0], [0.30, 1.0], [0.50, 0.94], [0.70, 0.12], [1.0, 0.0]]
	var avance_keys := [[0.0, 0.0], [0.30, -1.0], [0.50, 0.6], [0.70, 7.4], [0.86, 8.5], [1.0, 6.0]]
	var pose := func(t: float) -> Dictionary:
		return {"avance": SpriteLienzo.tramos(t, avance_keys) * (LUNGE_DIST / 8.5),
			"fase": 0.0, "onda": 0.55, "paso": 0.0,
			"alza": SpriteLienzo.tramos(t, alza_keys), "enrosca": 0.0}
	_montar_animacion(anims, esc, "embestida", false, 12.0, pose, true)


# MORIRSE. OCHO fotogramas en UNA sola direccion: la muerte solo se ve en la pantalla de combate, y
# ahi al bicho se le mira siempre de frente. Para el mapa esta 'cadaver'.
#
# SE ENROSCA EN ESPIRAL. Un ciempies muerto se enrolla sobre si mismo, y como su cuerpo ES la cadena,
# la muerte no se hace moviendo piezas: se hace cambiando la TRAZA por la que se colocan los anillos
# (ver _traza). La onda se apaga a la vez que la espiral se cierra.
#
# Con un ULTIMO LATIGAZO en el 0.66: la onda repunta antes de apagarse del todo. Sin el, enroscarse
# sale como una interpolacion limpia y parece que se acurruca a gusto en vez de morirse.
static func _pose_muerte(t: float) -> Dictionary:
	var enrosca_keys := [[0.0, 0.0], [0.18, 0.16], [0.40, 0.55], [0.66, 0.74],
		[0.84, 0.96], [1.0, 1.0]]
	var onda_keys := [[0.0, 1.0], [0.18, 0.85], [0.40, 0.45], [0.66, 0.62], [0.84, 0.12], [1.0, 0.0]]
	# Y un tiron hacia arriba de la cabeza al principio: el ultimo intento de picar.
	var alza_keys := [[0.0, 0.0], [0.18, 0.45], [0.40, 0.10], [1.0, 0.0]]
	return {"avance": 0.0, "fase": t * 1.6, "onda": SpriteLienzo.tramos(t, onda_keys),
		"paso": SpriteLienzo.tramos(t, onda_keys) * 0.5,
		"alza": SpriteLienzo.tramos(t, alza_keys),
		"enrosca": SpriteLienzo.tramos(t, enrosca_keys)}


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
# SE RETUERCE: sale despedido hacia atras Y la onda se dispara. En un bicho cuyo cuerpo es una
# cadena, la sacudida se cuenta con la onda, no moviendo el bulto -- que es lo que hacen los otros.
static func _montar_encaje(anims: Array, esc: float) -> void:
	var retro_keys := [[0.0, 1.0], [0.34, 0.44], [0.67, 0.12], [1.0, 0.0]]
	var onda_keys := [[0.0, 2.1], [0.34, 1.5], [0.67, 1.1], [1.0, 1.0]]
	var pose := func(t: float) -> Dictionary:
		return {"avance": -SpriteLienzo.tramos(t, retro_keys) * (LUNGE_DIST * ENCAJE_RETRO),
			"fase": 0.35 * t, "onda": SpriteLienzo.tramos(t, onda_keys), "paso": 0.3,
			"alza": 0.0, "enrosca": 0.0}
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
			# ciempies de otro tono reusa estas plantillas y solo repinta.
			var clave: String = "%s_%d_%d_%.2f" % [nombre, i, dir, esc]
			var plant: PackedByteArray = _cache_plantillas.get(clave, PackedByteArray())
			if plant.is_empty():
				plant = _plantilla(dir, pose_fn.call(float(i) / divisor), esc)
				_cache_plantillas[clave] = plant
			plantillas.append(plant)
		anims.append({"nombre": "%s_%d" % [nombre, dir], "loop": loop, "fps": fps,
			"plantillas": plantillas})


# Le sube la saturacion, como a la araña y al jabali: el color que llega no es el de la ficha sino
# 'color_visual', ya aclarado hacia el blanco segun la 't' del bicho, y un carmesi lavado se queda
# en rosa palo.
static func _saturado(color: Color) -> Color:
	var out := Color.from_hsv(color.h, minf(1.0, color.s * 1.20 + 0.12), color.v)
	out.a = color.a
	return out


# Los colores de cada Tono, EN EL ORDEN DEL ENUM (contrato con SpriteLienzo.paleta).
static func _colores(color: Color) -> Array:
	var c: Color = _saturado(color)
	return [
		Color(0, 0, 0, 0),                    # VACIO
		Color(0, 0, 0, 0.22),                 # SOMBRA_SUELO
		c.darkened(0.68),                     # BORDE
		# LAS PATAS, EN AMARILLO. Es el contraste del ciempies de verdad, y aqui ademas hace un
		# trabajo: del color del cuerpo se fundirian con el y el bicho seria un chorizo rojo. Amarillas
		# se cuentan una a una, que es lo que hay que ver de un ciempies.
		Color(0.93, 0.72, 0.24),              # PATA
		c.darkened(0.34),                     # SOMBRA (el costado de los anillos, en penumbra)
		c,                                    # BASE
		# LAS PLACAS del lomo, mas claras y hacia el naranja: el rojo aclarado sin girar hacia el
		# calido se va al rosa (es el mismo aviso que el ocre del jabali y el lila de la araña).
		c.lerp(Color(0.98, 0.62, 0.30), 0.45),                # PLACA
		c.darkened(0.52),                     # FORCIPULA_T (quitina oscura)
		Color(0.86, 0.90, 0.60),              # PONZONA (la punta de la forcipula)
		Color(0.98, 0.94, 0.80),              # OJO_T
	]


# ------------------------------------------------------------
#  GEOMETRIA
# ------------------------------------------------------------

# DONDE ESTA EL ANILLO 'i'. Es el corazon de este bicho: no hay un cuerpo al que pegar cosas, hay
# una traza, y todo lo demas (patas, placas, cabeza, cola) cuelga de aqui.
#
# Dos trazas y una mezcla entre ellas:
#   - VIVO: una recta hacia atras con una onda lateral que viaja del morro a la cola.
#   - MUERTO: una espiral que se cierra hacia dentro.
# 'enrosca' pasa de una a la otra. Interpolar las dos POSICIONES (y no intentar deformar la recta
# hasta que sea espiral) es lo que hace que esto quepa en cinco lineas.
static func _traza(i: int, fase: float, onda: float, enrosca: float) -> Vector2:
	var f: float = float(i)
	var recta := Vector2(onda * AMPLITUD * sin(TAU * (fase + f * DESFASE_ONDA)),
		CUERPO_Y0 - f * PASO)
	if enrosca <= 0.0:
		return recta
	var a: float = ESPIRAL_ANG0 + f * ESPIRAL_PASO_ANG
	var r: float = ESPIRAL_R * (1.0 - f / float(SEGMENTOS - 1) * 0.72)
	# El -0.35 recentra la espiral: sin el, el bicho enroscado se va hacia el norte de su lienzo
	# porque la cabeza arranca en el borde de fuera.
	var espiral := Vector2(r * sin(a), r * cos(a) - ESPIRAL_R * 0.35)
	return recta.lerp(espiral, enrosca)


# Un punto de la curva de una pata (bezier cuadratica: arranque, codo, final).
static func _curva(a: Vector3, codo: Vector3, b: Vector3, f: float) -> Vector3:
	var g: float = 1.0 - f
	return a * (g * g) + codo * (2.0 * g * f) + b * (f * f)


# Las PIEZAS del ciempies para una pose, ya proyectadas a pantalla.
static func _piezas(dir: int, pose: Dictionary, esc: float) -> Array:
	var ang: float = DIR_VECS[dir].angle() - DIR_VECS[0].angle()
	var u: float = esc / SpriteLienzo.UNIDADES_POR_CELDA
	var centro: float = float(_celdas(esc)) * 0.5
	var avance: float = float(pose["avance"])
	var fase: float = float(pose["fase"])
	var onda: float = float(pose["onda"])
	var paso: float = float(pose["paso"])
	var alza: float = float(pose["alza"])
	var enrosca: float = float(pose["enrosca"])

	# EL AVANCE SE ROTA UNA VEZ Y LO LLEVAN TODAS LAS PIEZAS POR IGUAL (la trampa del meceo del
	# trent): sumarlo a la Y local antes de rotar solo funciona si TODAS las piezas giran.
	var desp := Vector2(0.0, avance).rotated(ang)

	# TRES CUBOS, Y SOLO UNO SE ORDENA. Esto fue el arreglo gordo del bicho: al principio cada anillo
	# tenia UN grupo con su sombra, sus patas y su cuerpo, y se ordenaban los grupos enteros por
	# profundidad. El resultado era un garabato, y la razon es que asi la SOMBRA del anillo 7 se
	# pintaba ENCIMA del cuerpo del anillo 3 -- manchas oscuras por todo el lomo -- y las patas de un
	# tramo cruzaban por delante de otro.
	#
	#   - suelo: TODAS las sombras. Estan en el suelo, o sea debajo de todo. No se ordenan.
	#   - patas: TODAS las patas. Son una franja que rodea al bicho por debajo; ninguna pata pasa
	#     nunca por delante del cuerpo, y eso es lo correcto en un bicho tan plano.
	#   - grupos: solo los ANILLOS (con su placa y los adornos de cabeza y cola). ESTOS SI se ordenan,
	#     porque son los unicos que se cruzan entre si de verdad.
	var suelo: Array = []
	var patas: Array = []
	var grupos: Array = []
	for _i in SEGMENTOS:
		grupos.append({"sy": 0.0, "piezas": []})

	var poner := func(dest: Array, local: Vector3, r: Vector3, tono: int,
			solo_sobre: Array = [], en_suelo: bool = false) -> void:
		var rot: Vector2 = Vector2(local.x, local.y).rotated(ang) + desp
		var z: float = 0.0 if en_suelo else local.z
		var sx: float = centro + rot.x * u
		var sy: float = centro + (rot.y * SpriteLienzo.COS_CAM - z * SpriteLienzo.SIN_CAM) * u
		# El aplastado va DESPUES de girar: lo hace SpriteLienzo.elipse con 'persp', y el valor lo da
		# persp_de a partir de los semiejes.
		dest.append({"pos": Vector2(sx, sy), "radio": Vector2(r.x * u, r.y * u),
			"gira_forma": true, "tono": tono, "ang": ang,
			"persp": 1.0 if en_suelo else SpriteLienzo.persp_de(r.y, r.z),
			"solo_sobre": solo_sobre})

	for i in SEGMENTOS:
		var f: float = float(i) / float(SEGMENTOS - 1)
		var p: Vector2 = _traza(i, fase, onda, enrosca)
		# ALZARSE: solo los primeros anillos, y cada vez menos hacia atras -- lo que se levanta es la
		# mitad delantera, no el bicho entero. Y al subir, el anillo se echa un poco hacia atras
		# (el cuerpo no se estira: lo que sube deja de avanzar).
		var sube: float = 0.0
		if alza > 0.0 and i < ALZA_ANILLOS:
			var g: float = 1.0 - float(i) / float(ALZA_ANILLOS)
			sube = alza * ALZA_ALTO * g * g
			p.y -= sube * 0.42
		var z: float = CUERPO_Z + sube
		var r: Vector3 = ANILLO_R0.lerp(ANILLO_R1, f)
		var grupo: Array = grupos[i]["piezas"]
		# La altura EN PANTALLA de este anillo: es con lo que se ordena la profundidad al final.
		var rot_i: Vector2 = p.rotated(ang) + desp
		grupos[i]["sy"] = rot_i.y * SpriteLienzo.COS_CAM - z * SpriteLienzo.SIN_CAM

		# SOMBRA DE CONTACTO de este anillo, a altura cero. Va por anillo y no una sola para todo el
		# bicho: un cuerpo que serpentea no proyecta un ovalo, proyecta su propia culebra. Al cubo del
		# SUELO, que va debajo de todo.
		poner.call(suelo, Vector3(p.x, p.y, 0.0), Vector3(r.x * 0.85, r.y * 0.95, 0.0),
			Tono.SOMBRA_SUELO, [], true)

		# LAS PATAS, un par CADA DOS ANILLOS. Al cubo de las PATAS: todas debajo de todos los anillos,
		# asi el cuerpo les tapa el nacimiento y ninguna cruza por delante del bicho.
		#
		# CADA DOS Y NO UNA POR ANILLO, y las dos cosas que lo obligan tiran en sentidos contrarios:
		# la pata tiene que ser GRUESA (>= 3 celdas) o el contorno se la come entera, y a la vez tiene
		# que haber mas HUECO entre pata y pata que grosor tiene, o se fusionan. Con un par por anillo
		# el hueco es el paso de la cadena (1,55) contra un grosor de 2,3: las veinte patas se pegaban
		# en una FALDA AMARILLA continua que se tragaba el cuerpo. Cada dos anillos el hueco es 3,1 y
		# se cuentan una a una -- diez patas que se ven son mas 'ciempies' que veinte que no.
		if i > 0 and i % 2 == 1:
			for s in 2:
				var lado: float = -1.0 if s == 0 else 1.0
				# ONDA METACRONAL: cada par va por detras del anterior. Los dos lados van ademas en
				# contrafase (el +0.5), o el bicho remaria con las veinte patas a la vez.
				var giro: float = TAU * (fase + float(i) * DESFASE_PATAS + (0.0 if s == 0 else 0.5))
				var vaiven: float = sin(giro) * paso * PASO_LARGO
				var levanta: float = maxf(0.0, cos(giro)) * paso * PASO_ALTO
				var ancla := Vector3(p.x + lado * PATA_X * (r.x / ANILLO_R0.x), p.y, PATA_Z)
				var punta := Vector3(p.x + lado * (PATA_X + PATA_ALCANCE),
					p.y + vaiven, levanta)
				var codo: Vector3 = ancla.lerp(punta, 0.5) + Vector3(
					lado * PATA_PANZA, 0.0, PATA_PANZA * 1.3)
				for j in PATA_SEGMENTOS:
					var g2: float = float(j) / float(PATA_SEGMENTOS - 1)
					poner.call(patas, _curva(ancla, codo, punta, g2),
						Vector3.ONE * lerpf(PATA_R0, PATA_R1, g2), Tono.PATA)

		# EL ANILLO, y encima su PLACA del lomo. La placa es corta y deja hueco con la siguiente: ese
		# hueco es lo que se lee como la juntura entre segmentos.
		poner.call(grupo, Vector3(p.x, p.y, z), r, Tono.BASE)
		poner.call(grupo, Vector3(p.x, p.y, z + r.z * 0.52),
			Vector3(PLACA_R.x * (r.x / ANILLO_R0.x), PLACA_R.y, PLACA_R.z), Tono.PLACA, [Tono.BASE])

		# --- LA CABEZA (anillo 0) ---
		if i == 0:
			# QUIEN LE VE LA CARA: de espaldas no se le ven ni ojos ni forcipulas. Con la camara a 45
			# grados, un bicho que se aleja enseña la cola, y eso es lo que dice de un vistazo si
			# viene o si huye. Las ANTENAS si se dibujan siempre: son largas y asoman por delante de
			# la cabeza incluso cuando el bicho se va, y ademas son la otra mitad de lo que distingue
			# la cabeza de la cola. (No es el caso de los colmillos del jabali, que asomaban por
			# ENCIMA de la grupa y parecian otra cara.)
			var de_cara: bool = DIR_VECS[dir].y > -0.5 and enrosca < 0.6

			for s in 2:
				var lado: float = -1.0 if s == 0 else 1.0
				for j in ANTENA_SEGMENTOS:
					var g3: float = float(j) / float(ANTENA_SEGMENTOS - 1)
					poner.call(grupo, Vector3(p.x + lado * (ANTENA_X + g3 * 3.4),
							p.y + g3 * 4.2, z + 0.4 + g3 * 1.5),
						Vector3.ONE * lerpf(ANTENA_R0, ANTENA_R1, g3), Tono.FORCIPULA_T)

			if de_cara:
				# FORCIPULAS: los ganchos del veneno, bajo la cabeza, curvandose hacia DENTRO (por eso
				# la x se acerca al eje segun bajan). La punta en tono ponzoña.
				for s in 2:
					var lado: float = -1.0 if s == 0 else 1.0
					for j in FORCIPULA_SEGMENTOS:
						var g4: float = float(j) / float(FORCIPULA_SEGMENTOS - 1)
						poner.call(grupo, Vector3(p.x + lado * (FORCIPULA_X - g4 * 0.7),
								p.y + 1.0 + g4 * 1.8, z - 0.5 - g4 * 1.3),
							Vector3.ONE * lerpf(FORCIPULA_R0, FORCIPULA_R1, g4),
							Tono.PONZONA if j == FORCIPULA_SEGMENTOS - 1 else Tono.FORCIPULA_T)
				for s in 2:
					var lado: float = -1.0 if s == 0 else 1.0
					poner.call(grupo, Vector3(p.x + lado * OJO_X, p.y + 0.9, z + r.z * 0.55),
						Vector3.ONE * OJO_R, Tono.OJO_T)

		# --- LOS CERCOS DE LA COLA (ultimo anillo) ---
		if i == SEGMENTOS - 1:
			for s in 2:
				var lado: float = -1.0 if s == 0 else 1.0
				for j in CERCO_SEGMENTOS:
					var g5: float = float(j) / float(CERCO_SEGMENTOS - 1)
					poner.call(grupo, Vector3(p.x + lado * (0.4 + g5 * CERCO_X * 2.2),
							p.y - g5 * 3.0, z * (1.0 - g5 * 0.35)),
						Vector3.ONE * lerpf(CERCO_R0, CERCO_R1, g5), Tono.FORCIPULA_T)

	# LA PROFUNDIDAD SE CALCULA, NO SE ESCRIBE. En la araña y el escarabajo el orden de pintado va
	# cableado de lo mas bajo a lo mas alto, porque su cuerpo es un bulto y ese orden no cambia
	# nunca. Aqui el cuerpo SE CRUZA CONSIGO MISMO: en media onda el anillo 4 esta por delante del 5
	# y en la otra media, por detras; y enroscado, la espiral se monta sobre si misma. Ordenando los
	# anillos por su altura en pantalla (los de arriba primero, o sea los mas lejanos), los cruces
	# salen bien solos en los 8 x 8 fotogramas sin un solo caso especial.
	grupos.sort_custom(func(a, b): return float(a["sy"]) < float(b["sy"]))

	var piezas: Array = suelo + patas
	for g in grupos:
		piezas.append_array(g["piezas"])
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
