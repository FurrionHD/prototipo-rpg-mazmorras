# ============================================================
#  ropa_sprites.gd  (class_name RopaSprites)
#  LA ROPA DE DEBAJO: lo que llevas puesto cuando no llevas armadura.
#
#  Son DOS piezas del aspecto (torso y piernas) y un solo generador, porque comparten todo el
#  andamiaje y lo unico que cambia es que elipses mete cada modelo. El nombre del modelo es unico
#  entre las dos piezas ("camisa" no puede ser tambien un pantalon), asi que el despacho va por
#  nombre -- igual que SpritesEnemigo deja que el nombre gane a la familia.
#
#  ES LA CAPA QUE HACE QUE TU COLOR SE VEA. La piel no se tiñe (la carne tiene su color, ver la
#  cabecera de cuerpo_sprites.gd), asi que desde que el cuerpo va en color de carne el color que
#  eliges al crear la partida no se veia en ninguna parte. Es el de la ropa, y siempre lo fue.
#
#  DOS COSAS QUE HAY QUE SABER PARA AÑADIR UN MODELO:
#
#  1. LA ROPA SE DIBUJA SOBRE EL CUERPO PERO NO PUEDE MIRARLO. Cada capa se hornea SOLA, asi que
#     'solo_sobre' aqui solo ve lo que haya pintado esta misma capa. Lo que sujeta la manga no es el
#     brazo de debajo: es la propia elipse del pecho, dibujada despues.
#
#  2. Y POR ESO EL ORDEN INTERNO ES EL MISMO QUE EL DEL CUERPO: manga del fondo, tronco, manga de
#     delante. Con la manga del fondo pintada al final, la capa entera va por encima del cuerpo y lo
#     que se veria es una manga cruzando el pecho -- exactamente el fallo que ya se arreglo una vez
#     en el cuerpo (ver la nota de 'izq_al_fondo' en cuerpo_sprites.gd).
# ============================================================

extends RefCounted
class_name RopaSprites

# Los tonos, en el orden de CapaJugador.grises.
enum Tono {
	VACIO = 0, SOMBRA_SUELO = 1, BORDE = 2,
	TELA_S,     # los pliegues y lo que queda de fondo
	TELA,       # el tono base
	TELA_L,     # por donde da la luz
}

# CUANTO SOBRESALE LA TELA del cuerpo que viste, en unidades de mundo. Tiene que pasar de una celda
# (1,15) o la ropa se queda POR DENTRO del cuerpo en la mitad de los fotogramas y lo que se ve es la
# piel asomando a trozos, como si la camisa parpadeara.
const TELA := 1.3

# ============================================================
#  LA REGLA QUE MAS IMPORTA AQUI: LA ROPA NO PUEDE INVADIR LA CABEZA
# ============================================================
# La tela crece HACIA ABAJO Y A LOS LADOS, nunca hacia arriba: cada elipse que engorda baja su centro
# lo mismo que crece su radio, asi que su borde de arriba se queda donde lo tiene el cuerpo y lo que
# gana se lo lleva la cintura -- que es hacia donde cae una camisa.
#
# POR QUE NO ES UN DETALLE: la cabeza vive en la capa del CUERPO, que va DEBAJO de la ropa, asi que
# no tiene forma de taparla. Creciendo en los tres ejes, el pecho de la camisa llegaba a 35,3 y la
# cabeza empieza a 34,9 -- la camisa se metia unidad y media dentro de la cara y se le comia la
# barbilla. En el cuerpo eso no pasa porque alli la cabeza se pinta DESPUES del pecho, en la misma
# capa; entre capas no hay ese arreglo.
#
# Vale igual para la armadura que viene: un peto que suba de aqui tapara la cara, y no dara ningun
# error. Las medidas de referencia (con ALTO_MUNDO = 60):
#     pecho del cuerpo 34,0   ·   cabeza (borde de abajo) 34,9   ·   hombro con manga 34,8
# CUANTO BAJA LA PRENDA por debajo de donde le tocaria, para dejar el cuello al aire. Es el numero a
# mover si la camisa vuelve a comerse la barbilla (subirlo) o si se le ve demasiado pecho (bajarlo).
const ESCOTE_BAJA := 1.5

# ============================================================
#  EL CUELLO DE LA PRENDA NO SE PINTA: SE RECORTA
# ============================================================
# Antes era una elipse de TELA_S pegada al canto de arriba de la camisa, o sea una BANDA MACIZA
# cruzando el pecho. Mirando de frente (y en SE/SW, que es donde mas se ve) eso no tiene sentido
# fisico: por el cuello de una camiseta pasa el CUELLO DE CARNE, y lo que hay detras es la cabeza.
# Pintar tela ahi es dibujar el agujero tapado, y ademas se comia la franja de piel entre la prenda y
# la barbilla -- con lo que la cara se quedaba en una linea.
#
# Ahora se hace al reves y sale gratis, porque el motor ya da las dos mitades:
#   * pintar con Tono.VACIO BORRA (SpriteLienzo.elipse escribe el tono sin excepciones), y la ropa va
#     en su propia capa POR ENCIMA del cuerpo -- asi que lo que aqui se borra enseña la carne;
#   * el contorno se calcula AL FINAL sobre la silueta ya fusionada (ver CapaJugador.plantilla), asi
#     que el agujero se rodea solo de borde oscuro: ESE BORDE ES EL CUELLO DE LA PRENDA.
#
# Y va anclado en P_CUELLO, no en el torso: asi el escote sigue al cuello en las OCHO direcciones sin
# un solo caso por direccion (de espaldas asoma la nuca, que es lo correcto y ademas lo tapa el pelo).
#
# LO QUE NO ES OBVIO Y HAY QUE MEDIR ANTES DE TOCAR ESTO: DE FRENTE, EL CUELLO NO SE VE. Con esta
# camara (45 grados, una celda = 1,15) la cabeza baja en pantalla hasta 18,6 celdas y el cuello de
# carne entero cae entre 18,4 y 23,4 -- o sea que LA CABEZA LO TAPA. Por el agujero de una camiseta
# no asoma carne: asoma la barbilla, que es lo que hay justo detras.
#
# De ahi sale la calibracion: el recorte tiene que quedarse DENTRO de la silueta de la cabeza. Si
# baja de la barbilla no enseña cuello -- enseña EL FONDO, un boquete negro en mitad del pecho, que
# es peor que la banda que veniamos a quitar. Lo que se ve al final es la camisa acabando en un arco
# limpio bajo la barbilla, que es como acaba una camiseta mirandola de frente.
#
# El ancho no puede acercarse al del pecho (10,1) o parte la camisa en dos islas, y el alto tampoco
# importa mucho: lo que manda es SUBE.
const ESCOTE_R := 1.55
const ESCOTE_ALTO := 2.6
# CUANTO SUBE EL RECORTE por encima del cuello para meterse detras de la cabeza. ES EL NUMERO A
# MOVER: si aparece un hueco oscuro bajo la barbilla, subirlo.
const ESCOTE_SUBE := 4.2
# La manga corta acaba a esta fraccion del tramo hombro->codo.
const MANGA_CORTA := 0.62
# El bajo de una tunica, en fraccion del tramo cadera->rodilla.
const BAJO_TUNICA := 0.55


# --- Contrato de capa (ver CapaJugador y el registro de JugadorSprites) ---
static func frames(modelo: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.frames(clave(modelo), pintar.bind(modelo), colores(), esc)


static func generar(modelo: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.generar(clave(modelo), pintar.bind(modelo), colores(), esc)


# La clave lleva delante la PIEZA y no solo el modelo, porque es el nombre del atlas en disco y ahi
# "camisa.png" suelto no dice de que es.
static func clave(modelo: String) -> String:
	return "%s_%s" % [pieza_de(modelo), modelo]


static func pieza_de(modelo: String) -> String:
	return "torso" if modelo in ["camisa", "tunica", "chaleco"] else "piernas"


static func colores() -> Array:
	return CapaJugador.grises()


# ============================================================
#  EL PINTOR
# ============================================================
static func pintar(esq: Dictionary, piezas: Array, modelo: String) -> void:
	match modelo:
		"camisa": _torso(piezas, esq, MANGA_CORTA, 0.0)
		"tunica": _torso(piezas, esq, 1.0, BAJO_TUNICA)
		"chaleco": _torso(piezas, esq, 0.0, 0.0)
		"pantalon": _piernas(piezas, esq, 1.0)
		"bombacho": _piernas(piezas, esq, 0.45)
		"faldon": _faldon(piezas, esq)


# EL TORSO. 'manga' es hasta donde llega por el brazo (0 = sin mangas, 1 = hasta la muñeca) y 'bajo'
# cuanto cae la falda de la prenda por debajo de la cadera.
static func _torso(piezas: Array, esq: Dictionary, manga: float, bajo: float) -> void:
	var p: Dictionary = esq["puntos"]
	var izq_prof: float = PoseJugador.profundidad(esq, PoseJugador.P_HOMBRO_IZQ)
	var der_prof: float = PoseJugador.profundidad(esq, PoseJugador.P_HOMBRO_DER)
	var de_lado: bool = absf(izq_prof - der_prof) > CuerpoSprites.SEPARACION_BRAZOS
	var izq_al_fondo: bool = izq_prof < der_prof

	# 1. La manga del fondo, si de verdad hay una al fondo: la tapa el propio tronco de la prenda.
	if de_lado and manga > 0.0:
		_manga(piezas, esq, izq_al_fondo, manga, Tono.TELA_S)

	# 2. La falda de la prenda, antes que el pecho: asi el pecho tapa la juntura de la cintura.
	if bajo > 0.0:
		_faldilla(piezas, esq, bajo)

	# 3. El tronco: cadera y pecho, un pelo mas gordos que el cuerpo, PERO SIN SUBIR (ver ARRIBA_TELA).
	PoseJugador.poner(piezas, esq, p[PoseJugador.P_CADERA] - Vector3(0.0, 0.0, TELA * 0.6),
		CuerpoSprites.R_CADERA + Vector3(TELA, TELA, TELA * 0.6), Tono.TELA_S)
	# EL PECHO BAJA 'ESCOTE_BAJA' DE MAS. Con solo el crecimiento compensado, el borde de arriba de la
	# camisa quedaba a la altura del cuello y lo tapaba entero: entre la barbilla y la prenda no se
	# veia nada de carne y la cabeza parecia apoyada sobre la camiseta. Una camisa empieza POR DEBAJO
	# del cuello.
	PoseJugador.poner(piezas, esq, p[PoseJugador.P_TORSO] - Vector3(0.0, 0.0, TELA + ESCOTE_BAJA),
		CuerpoSprites.R_TORSO + Vector3(TELA, TELA, TELA), Tono.TELA)
	# El realce del pecho: la luz viene de arriba, asi que va por encima de su eje.
	#
	# VA BAJO Y PLANO, y las dos cosas son correcciones de algo que se vio: con el ancho del cuerpo
	# (0,70 del pecho, 0,55 de alto) se leia como un BABERO.
	var alto: Vector3 = p[PoseJugador.P_TORSO] + Vector3(0.0, 0.0, CuerpoSprites.R_TORSO.z * 0.20)
	PoseJugador.poner(piezas, esq, alto,
		Vector3(CuerpoSprites.R_TORSO.x * 0.66, CuerpoSprites.R_TORSO.y * 0.74,
			CuerpoSprites.R_TORSO.z * 0.26), Tono.TELA_L, {"solo_sobre": [Tono.TELA]})
	# EL ESCOTE: se RECORTA la tela por donde pasa el cuello (ver la nota larga de ESCOTE_R). Va aqui,
	# despues del pecho y su realce pero ANTES DE LAS MANGAS: las mangas se pintan al final y, con el
	# orden al reves, volverian a rellenar el agujero.
	#
	# El 'solo_sobre' es lo que impide que el recorte muerda nada que no sea tela ya pintada.
	PoseJugador.poner(piezas, esq, p[PoseJugador.P_CUELLO] + Vector3(0.0, 0.0, ESCOTE_SUBE),
		Vector3(CuerpoSprites.R_CUELLO * ESCOTE_R, CuerpoSprites.R_CUELLO * ESCOTE_R, ESCOTE_ALTO),
		Tono.VACIO, {"solo_sobre": [Tono.TELA, Tono.TELA_L, Tono.TELA_S]})

	# 4. Las mangas que van por delante del tronco, al final.
	if manga <= 0.0:
		return
	if de_lado:
		_manga(piezas, esq, not izq_al_fondo, manga, Tono.TELA)
	else:
		_manga(piezas, esq, true, manga, Tono.TELA)
		_manga(piezas, esq, false, manga, Tono.TELA)


# Una manga. Arranca dentro del pecho (como el brazo del cuerpo, por el mismo motivo: agarrada por
# medio pixel se despega al correr) y acaba donde diga 'largo'.
static func _manga(piezas: Array, esq: Dictionary, izq: bool, largo: float, tono: int) -> void:
	var p: Dictionary = esq["puntos"]
	var hombro: Vector3 = p[PoseJugador.P_HOMBRO_IZQ if izq else PoseJugador.P_HOMBRO_DER]
	var codo: Vector3 = p[PoseJugador.P_CODO_IZQ if izq else PoseJugador.P_CODO_DER]
	var mano: Vector3 = p[PoseJugador.P_MANO_IZQ if izq else PoseJugador.P_MANO_DER]
	# BAJA MAS QUE EL BRAZO DEL CUERPO (que arranca en hombro.z - 2.0): la manga es mas gorda, y con
	# el mismo arranque su borde de arriba llegaba a 34,8, o sea contra la cabeza (ver la nota de
	# TELA). Bajarla lo que engorda deja el hombro vestido justo donde estaba el desnudo.
	var arranque := Vector3(hombro.x * 0.88, hombro.y, hombro.z - 2.0 - TELA)
	# El largo se mide sobre la cadena entera hombro->codo->mano, para que "1" sea la muñeca y no el
	# codo. Por debajo de 1 la manga acaba en el brazo; a 1 llega hasta la mano.
	if largo <= 0.62:
		var fin: Vector3 = arranque.lerp(codo, largo / 0.62)
		PoseJugador.cadena(piezas, esq, arranque, fin,
			CuerpoSprites.R_BRAZO + TELA, CuerpoSprites.R_ANTEBRAZO + TELA * 0.9, tono)
		return
	PoseJugador.cadena(piezas, esq, arranque, codo,
		CuerpoSprites.R_BRAZO + TELA, CuerpoSprites.R_ANTEBRAZO + TELA * 0.9, tono)
	var f: float = (largo - 0.62) / 0.38
	PoseJugador.cadena(piezas, esq, codo, codo.lerp(mano, f),
		CuerpoSprites.R_ANTEBRAZO + TELA * 0.9, CuerpoSprites.R_ANTEBRAZO + TELA * 0.7, tono)


# La falda de una tunica: una masa que cuelga de la cadera y se abre un poco hacia abajo.
static func _faldilla(piezas: Array, esq: Dictionary, bajo: float) -> void:
	var p: Dictionary = esq["puntos"]
	var cadera: Vector3 = p[PoseJugador.P_CADERA]
	var rod: Vector3 = p[PoseJugador.P_RODILLA_IZQ].lerp(p[PoseJugador.P_RODILLA_DER], 0.5)
	var fin: Vector3 = cadera.lerp(rod, bajo)
	PoseJugador.cadena(piezas, esq, cadera, fin,
		CuerpoSprites.R_CADERA.x * 0.92, CuerpoSprites.R_CADERA.x * 1.12, Tono.TELA_S)


# LAS PIERNAS. 'largo' es hasta donde baja el pantalon: 1 = al tobillo, 0.45 = por la rodilla.
#
# La del fondo primero y la de delante con su tono, igual que el cuerpo: con las piernas juntas (ver
# PoseJugador.PIE_X) se solapan de verdad al andar, y sin ese escalon la zancada se lee como un solo
# bulto que se ensancha.
static func _piernas(piezas: Array, esq: Dictionary, largo: float) -> void:
	var izq_al_fondo: bool = PoseJugador.profundidad(esq, PoseJugador.P_PIE_IZQ) \
		< PoseJugador.profundidad(esq, PoseJugador.P_PIE_DER)
	var brazo_izq: float = PoseJugador.profundidad(esq, PoseJugador.P_HOMBRO_IZQ)
	var brazo_der: float = PoseJugador.profundidad(esq, PoseJugador.P_HOMBRO_DER)
	var de_lado: bool = absf(brazo_izq - brazo_der) > CuerpoSprites.SEPARACION_BRAZOS
	_pernera(piezas, esq, izq_al_fondo, largo, Tono.TELA_S if de_lado else Tono.TELA)
	_pernera(piezas, esq, not izq_al_fondo, largo, Tono.TELA)
	# La cintura, al final: tapa el arranque de las dos perneras, que es donde se ve el corte.
	_cintura(piezas, esq)


static func _pernera(piezas: Array, esq: Dictionary, izq: bool, largo: float, tono: int) -> void:
	var p: Dictionary = esq["puntos"]
	var cadera: Vector3 = p[PoseJugador.P_CADERA]
	var rodilla: Vector3 = p[PoseJugador.P_RODILLA_IZQ if izq else PoseJugador.P_RODILLA_DER]
	var pie: Vector3 = p[PoseJugador.P_PIE_IZQ if izq else PoseJugador.P_PIE_DER]
	var arranque := Vector3((1.0 if izq else -1.0) * PoseJugador.PIE_X * 0.82,
		cadera.y, cadera.z - 2.0)
	var tobillo: Vector3 = pie + Vector3(0.0, 0.0, CuerpoSprites.R_PIE.z)
	if largo <= 0.5:
		var f: float = largo / 0.5
		PoseJugador.cadena(piezas, esq, arranque, arranque.lerp(rodilla, f),
			CuerpoSprites.R_MUSLO + TELA, CuerpoSprites.R_PANTORRILLA + TELA, tono)
		return
	PoseJugador.cadena(piezas, esq, arranque, rodilla,
		CuerpoSprites.R_MUSLO + TELA, CuerpoSprites.R_PANTORRILLA + TELA * 0.9, tono)
	var f2: float = (largo - 0.5) / 0.5
	PoseJugador.cadena(piezas, esq, rodilla, rodilla.lerp(tobillo, f2),
		CuerpoSprites.R_PANTORRILLA + TELA * 0.9, CuerpoSprites.R_PANTORRILLA * 0.85 + TELA * 0.8,
		tono)


static func _cintura(piezas: Array, esq: Dictionary) -> void:
	var p: Dictionary = esq["puntos"]
	PoseJugador.poner(piezas, esq, p[PoseJugador.P_CADERA],
		CuerpoSprites.R_CADERA + Vector3(TELA, TELA, TELA * 0.4), Tono.TELA)


# EL FALDON: una sola masa acampanada de la cintura a media pantorrilla, sin perneras. Es lo que lo
# distingue de un pantalon a este tamaño -- no el largo, sino que las piernas NO se separan.
static func _faldon(piezas: Array, esq: Dictionary) -> void:
	var p: Dictionary = esq["puntos"]
	var cadera: Vector3 = p[PoseJugador.P_CADERA]
	var rod: Vector3 = p[PoseJugador.P_RODILLA_IZQ].lerp(p[PoseJugador.P_RODILLA_DER], 0.5)
	# HASTA LA RODILLA Y CON POCO VUELO. La primera version bajaba a 1,15 del tramo (o sea por debajo
	# de la rodilla) y se abria a 1,35 del ancho de la cadera: lo que salia no era una falda sino una
	# BOLA que se comia las dos piernas enteras -- por debajo no asomaba nada y el personaje parecia
	# un escarabajo. Una falda se lee porque las piernas siguen ahi debajo.
	var fin: Vector3 = cadera.lerp(rod, 0.92)
	PoseJugador.cadena(piezas, esq, cadera, fin,
		CuerpoSprites.R_CADERA.x * 0.92, CuerpoSprites.R_CADERA.x * 1.12, Tono.TELA)
	# El bajo: un anillo FINO de sombra en el borde, no una tapa. Tapando el bajo entero, la falda se
	# cerraba por debajo y volvia a ser un cuerpo solido.
	PoseJugador.poner(piezas, esq, fin + Vector3(0.0, 0.0, -0.6),
		Vector3(CuerpoSprites.R_CADERA.x * 1.12, CuerpoSprites.R_CADERA.y * 1.05, 1.0),
		Tono.TELA_S, {"solo_sobre": [Tono.TELA]})
	_cintura(piezas, esq)
