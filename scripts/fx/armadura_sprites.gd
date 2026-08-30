# ============================================================
#  armadura_sprites.gd  (class_name ArmaduraSprites)
#  LAS PIEZAS DE ARMADURA QUE SE VEN PUESTAS.
#
#  El sistema de armadura ya existia entero menos esto: ArmorData tiene cuatro tipos y cinco ranuras,
#  las veinte piezas estan en resources/armor/, y equipar, defensa, durabilidad, forja y tienda
#  funcionan desde hace tiempo. Lo unico que faltaba era VERLAS.
#
#  LA CLAVE LLEVA LA INFORMACION DENTRO ("armadura_placas_casco") y se parsea en 'pintar', igual que
#  hacen ArmaSprites y EscudoSprites. Asi CapaJugador, el horno y el visor la tratan como una capa
#  mas y no hay que escribir un caso especial en cada sitio. El pelo y la ropa van al reves (reciben
#  el modelo y el catalogo compone la clave) porque son ASPECTO y salen de una lista cerrada; la
#  armadura es EQUIPO y sale de lo que lleves puesto.
#
#  NO SE TIÑE. El ArmorData no trae color propio -- lo que distingue un juego de otro es el material,
#  no un color que elijas --, asi que va con colores de verdad y "tinte": false en el registro, como
#  el arma y el escudo. Cada tipo tiene su paleta y es ella la que dice "esto es cuero" o "esto es
#  acero", no un tinte de fuera.
#
#  LA REGLA DE FORMA ES LA MISMA QUE LA DE LA ROPA (ver la cabecera de ropa_sprites.gd): a este tamaño
#  de pixel, UNA UNIDAD DE MAS EN EL RADIO ES UNA SILUETA DISTINTA. Un casco no se hace inflando la
#  cabeza: se hace con la PALETA (franja de luz dura arriba, sombra en el canto de abajo) y con PIEZAS
#  PROPIAS que si tienen forma -- el ala, la cresta, la ranura de la visera. Lo unico que crece es
#  GROSOR, y lo justo para tapar la cabeza que lleva debajo.
#
#  ABIERTOS Y CERRADOS. Cuero y hierro son cascos abiertos: se les ve la cara (y tu foto), y por eso
#  se dibujan por DEBAJO de ella (JugadorSprites.Z_CASCO_ABIERTO). Hierro completo y placas bajan
#  visera: van por ENCIMA de todo, tapan la cara y traen su propia ranura. Es una linea de z por tipo
#  y hace que los cuatro juegos se distingan de un vistazo.
#
#  EL PELO NO SE RECORTA AQUI, Y NO SE PUEDE. Cada capa se hornea sola y 'solo_sobre' solo ve piezas
#  de esta misma capa, asi que un casco no tiene forma de morder el pelo. La convivencia se decide
#  ARRIBA, en JugadorSprites.capas_de: con casco puesto no se pide el casquete del pelo, solo lo que
#  cuelga. Por eso este pintor puede ser tonto y limitarse a dibujar un casco.
# ============================================================

extends RefCounted
class_name ArmaduraSprites

# Los tonos. Van con nombres de MATERIAL y no de color, porque los mismos cinco valen para el cuero y
# para el acero: lo que cambia entre los cuatro juegos es la paleta, no el dibujo.
enum Tono {
	VACIO = 0, SOMBRA_SUELO = 1, BORDE = 2,
	MAT_S,      # el material en penumbra: el canto de abajo, el ala
	MAT,        # el material, tono base
	MAT_L,      # por donde da la luz
	OSCURO,     # la ranura de la visera y las juntas: lo que se lee como un hueco
	ACENTO,     # remaches y cresta
}

# Nombre de cada ArmorData.Tipo y de cada ArmorData.Slot, para las claves de capa. El indice es el
# valor del enum, igual que ArmaSprites.TIPO_NOMBRE.
const TIPO_NOMBRE := ["cuero", "hierro", "hierro_completo", "placas"]
const SLOT_NOMBRE := ["casco", "pecho", "manos", "pantalones", "botas"]

# QUE TIPOS BAJAN VISERA. Es lo que decide si la cara se ve, y lo consulta tambien JugadorSprites
# para elegir el z -- por eso vive aqui y no alla: el dato es del material, no del registro.
const CERRADOS := ["hierro_completo", "placas"]

# DE QUE RANURAS SE SABE DIBUJAR. Añadir una es meterla aqui y darle su rama en 'pintar'.
const SLOTS_HECHOS := ["casco", "pecho", "manos", "pantalones", "botas"]

# LOS GUANTELETES SON DOS CAPAS, UNA POR MANO, y no una sola con las dos manos dentro. Es el mismo
# reparto que ya hacen las armas (ver JugadorSprites._arma_de) y por el mismo motivo: una capa tiene
# UN z, y las dos manos no estan a la misma profundidad casi nunca. Con una sola capa a z fijo, el
# guantelete de la mano que va por detras se pintaba por encima del pecho.
#
# Separadas, cada una se ancla a SU mano y MunecoJugador._ordenar las coloca por profundidad, que es
# exactamente lo que hace con el arma en mano.
const SLOTS_POR_MANO := ["manos"]

const R := PoseJugador.CABEZA_R

# CUANTO MAS GORDO QUE LA CABEZA. Tiene que pasar de una celda (1,15) o el casco sale a trozos entre
# los pixeles de la cabeza -- el mismo motivo por el que el pelo tiene su GROSOR, y esta medido igual.
# Va un pelo por debajo del pelo (1,6): un casco se ciñe al craneo mas que una mata de pelo, y esa
# diferencia es la que hace que un casco se lea duro y el pelo blando.
const GROSOR := 1.4

# --- El casquete de un casco ABIERTO ---
# Mismo truco que el casquete del pelo (ver PeloSprites.ATRAS/ARRIBA): desplazado hacia atras y hacia
# arriba, que en esta camara es lo unico que deja la cara libre sin escribir un caso por direccion.
#
# BAJA MAS QUE EL PELO (4,4 contra 5,6), y a proposito: un casco tapa mas frente que un flequillo.
# Ese es el numero a mover si el casco parece un gorrito puesto en lo alto (bajarlo) o si se come los
# ojos (subirlo).
const ABIERTO_ATRAS := 1.6
const ABIERTO_ARRIBA := 4.4
# Lo plano que es, en fraccion del radio. Con el alto entero vuelve a bajar hasta la barbilla por
# mucho que se suba -- exactamente lo que le pasaba al pelo.
const ABIERTO_ALTO := 0.64
# CUANTO BAJAN LAS CARRILLERAS por el lado de la cara, en fraccion del radio. Es lo unico que separa
# la silueta de un capacete de cuero de la de un casco de hierro, asi que va por tipo: el cuero es un
# gorro con orejeras cortas y el hierro ya baja hasta el pomulo.
const CARRILLERA := {"cuero": 0.35, "hierro": 0.62}
# EL GROSOR DEL CANTO OSCURO de abajo, en unidades de mundo (una celda = 1,15). Es lo que hace de ala
# sin ser una pieza: en el hierro va gordo y se lee como el borde de una chapa doblada; en el cuero
# va fino, que es lo que tiene una capucha. Ver la nota larga de _chapa.
const CANTO := {"cuero": 2.2, "hierro": 3.0, "hierro_completo": 2.4, "placas": 2.6}

# --- Lo que cambia de un juego a otro en las otras cuatro ranuras ---
# LA SILUETA TIENE QUE SEPARARLOS, no solo el color: teñidos de gris los cuatro petos, si solo
# cambiara la paleta serian el mismo dibujo cuatro veces. La hombrera y el faldar son lo que hace que
# unas placas se lean como placas de lejos.
#
# HOMBRERA: cuanto sobresale, escalando R_BRAZO. 0 = sin hombrera (el cuero no lleva).
const HOMBRERA := {"cuero": 0.0, "hierro": 0.55, "hierro_completo": 0.85, "placas": 1.15}
# FALDAR: las escamas que cuelgan de la cintura, en fraccion del tramo cadera->rodilla. Solo las
# pesadas; el que no esta en la tabla no lo lleva.
const FALDAR := {"hierro_completo": 0.42, "placas": 0.52}
# GUANTELETE: hasta donde sube por el antebrazo, en fraccion del tramo mano->codo.
const GUANTE_LARGO := {"cuero": 0.35, "hierro": 0.55, "hierro_completo": 0.75, "placas": 0.85}
# BOTA: hasta donde sube la caña, en fraccion del tramo tobillo->rodilla.
const BOTA_ALTO := {"cuero": 0.32, "hierro": 0.48, "hierro_completo": 0.62, "placas": 0.70}

# --- El casquete de un casco CERRADO ---
# Aqui NO hay que dejar hueco a nada, asi que es la cabeza entera: mismos semiejes que le pone
# CuerpoSprites a la cabeza, mas el grosor. Un yelmo cerrado ES una cabeza de metal.
const CERRADO_ARRIBA := 0.8

# En que direcciones se ve la cara, y por tanto donde tiene sentido dibujar la ranura de la visera.
# Son las mismas que las de CaraSprites (que se corta en seco en 3/4/5, la nuca), y tienen que serlo:
# una ranura en el cogote no es una ranura, es una raya.
const _DIRS_CARA := [0, 1, 2, 6, 7]


# --- Contrato de capa (ver CapaJugador y el registro de JugadorSprites) ---
static func frames(clave: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.frames(clave, pintar.bind(clave), colores(clave), esc)


static func generar(clave: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.generar(clave, pintar.bind(clave), colores(clave), esc)


static func clave(tipo: String, slot: String) -> String:
	return "armadura_%s_%s" % [tipo, slot]


static func cerrado(tipo: String) -> bool:
	return CERRADOS.has(tipo)


# ============================================================
#  LAS PALETAS
# ============================================================
# Una por tipo, y son lo unico que separa un juego de otro: el dibujo de los cuatro cascos comparte
# casi todo. La escalera de luminancia importa mas que el color -- de cuero a placas sube el brillo y
# baja la saturacion, que es como se lee "esto es mas caro" sin ponerle un cartel.
#
# El BORDE es casi negro en los cuatro, como en el resto del personaje: es lo que hace que la silueta
# se lea contra el fondo de la mazmorra.
static func colores(clave: String) -> Array:
	var tipo: String = String(_parse(clave).get("tipo", "hierro"))
	match tipo:
		"cuero":
			return [
				Color(0, 0, 0, 0), Color(0, 0, 0, 0.20),
				Color(0.10, 0.06, 0.04),           # BORDE
				Color(0.30, 0.19, 0.11),           # MAT_S
				Color(0.44, 0.29, 0.17),           # MAT
				Color(0.58, 0.41, 0.25),           # MAT_L
				Color(0.16, 0.10, 0.06),           # OSCURO
				Color(0.68, 0.52, 0.32),           # ACENTO
			]
		"hierro_completo":
			return [
				Color(0, 0, 0, 0), Color(0, 0, 0, 0.20),
				Color(0.07, 0.07, 0.09),           # BORDE
				Color(0.33, 0.35, 0.40),           # MAT_S
				Color(0.50, 0.53, 0.59),           # MAT
				Color(0.72, 0.76, 0.83),           # MAT_L
				Color(0.10, 0.10, 0.13),           # OSCURO
				Color(0.60, 0.55, 0.38),           # ACENTO (laton en las juntas)
			]
		"placas":
			return [
				Color(0, 0, 0, 0), Color(0, 0, 0, 0.20),
				Color(0.08, 0.08, 0.11),           # BORDE
				Color(0.46, 0.49, 0.56),           # MAT_S
				Color(0.68, 0.72, 0.78),           # MAT
				Color(0.92, 0.95, 0.99),           # MAT_L
				Color(0.11, 0.11, 0.15),           # OSCURO
				Color(0.78, 0.66, 0.36),           # ACENTO (el oro de la cresta)
			]
		_:
			# hierro, y tambien el que se pida mal: mejor un casco de hierro que ninguno.
			return [
				Color(0, 0, 0, 0), Color(0, 0, 0, 0.20),
				Color(0.08, 0.08, 0.10),           # BORDE
				Color(0.36, 0.37, 0.41),           # MAT_S
				Color(0.55, 0.57, 0.62),           # MAT
				Color(0.76, 0.79, 0.84),           # MAT_L
				Color(0.11, 0.11, 0.14),           # OSCURO
				Color(0.64, 0.66, 0.70),           # ACENTO
			]


# ============================================================
#  QUE CLAVES EXISTEN
# ============================================================
static func claves_de(tipo: String) -> Array:
	var out: Array = []
	for slot in SLOTS_HECHOS:
		if SLOTS_POR_MANO.has(slot):
			out.append(clave(tipo, slot) + "_der")
			out.append(clave(tipo, slot) + "_izq")
		else:
			out.append(clave(tipo, slot))
	return out


static func todas_las_claves() -> Array:
	var out: Array = []
	for tipo in TIPO_NOMBRE:
		out.append_array(claves_de(tipo))
	return out


# DE CUANTOS TROZOS CONSTA CADA CAPA, para el validador de islas del horno. Es un TOPE que se admite
# sin avisar, no una cuenta exacta: lo que caza el validador es que se despegue algo, y para eso hace
# falta saber cuantos trozos son correctos-por-diseño.
static func trozos_de(clave: String) -> int:
	match String(_parse(clave).get("slot", "")):
		# Dos perneras / dos botas: son dos de verdad y se separan al andar.
		"pantalones", "botas": return 2
		# TRES: el peto y sus DOS HOMBRERAS, que son placas aparte de verdad. En la mayoria de las
		# poses se solapan con el peto y cuentan como una sola masa, pero en el fotograma 5 del golpe
		# el brazo se estira y la hombrera se queda sola -- 14 px, la hombrera entera, no una esquirla.
		# Mirado antes de subir el numero, que es la regla de este validador.
		"pecho": return 3
		_: return 1


# ============================================================
#  EL PARSEO DE LA CLAVE
# ============================================================
# El tipo puede llevar guion bajo dentro ("hierro_completo"), asi que NO vale partir por "_" y coger
# trozos: se busca el slot por el final, que es la parte que no tiene ambiguedad.
static func _parse(clave: String) -> Dictionary:
	var s: String = clave.trim_prefix("armadura_")
	# La mano va al final del todo ("armadura_placas_manos_der"), asi que se quita primero o el slot
	# no encaja por el final.
	var mano := ""
	for m in ["_der", "_izq"]:
		if s.ends_with(m):
			mano = m.trim_prefix("_")
			s = s.trim_suffix(m)
			break
	for slot in SLOT_NOMBRE:
		if s.ends_with("_" + slot):
			return {"tipo": s.trim_suffix("_" + slot), "slot": slot, "mano": mano}
	return {}


# ============================================================
#  EL PINTOR
# ============================================================
static func pintar(esq: Dictionary, piezas: Array, clave: String) -> void:
	var info: Dictionary = _parse(clave)
	if info.is_empty():
		return
	var tipo: String = String(info["tipo"])
	match String(info["slot"]):
		"casco": _casco(piezas, esq, tipo, int(esq.get("dir", 0)))
		"pecho": _peto(piezas, esq, tipo)
		"manos": _guantelete(piezas, esq, tipo, String(info.get("mano", "der")) == "izq")
		"pantalones": _grebas(piezas, esq, tipo)
		"botas": _botas(piezas, esq, tipo)


# ============================================================
#  EL CASCO
# ============================================================
static func _casco(piezas: Array, esq: Dictionary, tipo: String, dir: int) -> void:
	var cab: Vector3 = esq["puntos"][PoseJugador.P_CABEZA]
	if cerrado(tipo):
		_casco_cerrado(piezas, esq, cab, tipo, dir)
	else:
		_casco_abierto(piezas, esq, cab, tipo)


# UN CASCO ABIERTO: la cazoleta que cubre el craneo hasta por encima de los ojos, y ya. La cara la
# pone la capa de debajo.
static func _casco_abierto(piezas: Array, esq: Dictionary, cab: Vector3, tipo: String) -> void:
	var g := GROSOR
	var centro: Vector3 = cab + Vector3(0.0, -ABIERTO_ATRAS, ABIERTO_ARRIBA)
	var r := Vector3(R + g, R * 0.90 + g, R * ABIERTO_ALTO + g * 0.5)

	# LAS CARRILLERAS, Y VAN PRIMERO para que la cazoleta les tape el arranque.
	#
	# NO SON UN ADORNO: sin ellas el casco se lee como UNA SETA. La cazoleta tiene su fila mas ancha
	# por encima de la del craneo, asi que justo debajo de su borde asomaban las dos mejillas
	# desnudas y el conjunto parecia un sombrero apoyado en una cabeza mas gorda que el. Es el mismo
	# problema que resuelven las PATILLAS del pelo (PeloSprites._casquete), y se resuelve igual:
	# bajando algo por los lados hasta la altura del pomulo.
	var p: float = float(CARRILLERA.get(tipo, 0.5))
	for lado in [-1.0, 1.0]:
		PoseJugador.poner(piezas, esq, cab + Vector3(lado * R * 0.84, -0.8, -R * 0.14 * p),
			Vector3(R * 0.26, R * 0.56, R * (0.30 + 0.42 * p)), Tono.MAT_S)

	_chapa(piezas, esq, centro, r, float(CANTO.get(tipo, 1.7)))


# UN CASCO CERRADO: la cabeza entera de metal. Aqui no hay que dejarle hueco a la cara -- se la come a
# proposito --, asi que son los MISMOS SEMIEJES que le pone CuerpoSprites a la cabeza (L286) mas el
# grosor. Si algun dia cambia la forma de la cabeza, el yelmo la sigue solo.
static func _casco_cerrado(piezas: Array, esq: Dictionary, cab: Vector3, tipo: String,
		dir: int) -> void:
	var g := GROSOR
	var centro: Vector3 = cab + Vector3(0.0, 0.0, CERRADO_ARRIBA)
	var r := Vector3(R + g, R * 0.90 + g, R * 0.96 + g)

	_chapa(piezas, esq, centro, r, float(CANTO.get(tipo, 2.4)))

	# LA CRESTA, solo en las placas: una quilla estrecha y LARGA DE DELANTE A ATRAS. Al ser rx != ry
	# gira con la direccion sola (ver PoseJugador.proyectar), asi que de frente se ve de canto -- una
	# raya fina -- y de perfil entera. Que es lo que hace una cresta de verdad.
	if tipo == "placas":
		PoseJugador.poner(piezas, esq, centro + Vector3(0.0, -1.0, r.z * 0.62),
			Vector3(1.5, r.y * 0.80, 2.2), Tono.ACENTO)

	# LA RANURA. Solo donde se ve la cara: en la nuca (dirs 3/4/5) una ranura no es una ranura, es una
	# raya cruzando el cogote. Mismo corte que hace CaraSprites, y tiene que ser el mismo.
	if not _DIRS_CARA.has(dir):
		return
	# LA RANURA VA FINA DE FONDO, no de alto, y es otra vez lo mismo: en esta camara el alto de pantalla
	# sale del FONDO de la pieza (ver _chapa). Con R*0,34 de fondo la ranura proyectaba seis pixeles y
	# las dos juntas se leian como un BORRON negro en mitad de la cara, no como una cruz. Aplastandola
	# en Y baja a dos, que es lo que mide una ranura.
	var ojos: Vector3 = centro + Vector3(0.0, R * 0.62, -R * 0.16)
	var solo := {"solo_sobre": [Tono.MAT, Tono.MAT_L, Tono.MAT_S]}
	PoseJugador.poner(piezas, esq, ojos, Vector3(R * 0.58, 1.3, 1.0), Tono.OSCURO, solo)
	# Las placas la llevan EN CRUZ: la barra vertical baja por la nariz. Es el detalle que separa de un
	# vistazo el yelmo caro del barato, y cuesta una elipse.
	if tipo == "placas":
		PoseJugador.poner(piezas, esq, ojos - Vector3(0.0, 0.0, R * 0.22),
			Vector3(1.3, 1.3, R * 0.30), Tono.OSCURO, solo)


# ============================================================
#  EL PETO
# ============================================================
# ES LA CAMISA CON OTRA PALETA, y eso no es una manera de hablar: usa los mismos puntos y los mismos
# radios del cuerpo que RopaSprites._torso, porque la regla de que la ropa no engorda vale igual para
# el acero. Lo que le sobra a la camisa -- las hombreras, el faldar -- son piezas PROPIAS con forma,
# que es donde si esta permitido salirse.
#
# SUSTITUYE A LA CAMISA, no se apila encima: con el peto puesto JugadorSprites no pide la capa del
# torso. Por eso el peto tiene que resolverse solo el hueco del brazo y el de la cabeza -- no hay una
# camisa debajo que los tenga hechos.
static func _peto(piezas: Array, esq: Dictionary, tipo: String) -> void:
	var p: Dictionary = esq["puntos"]
	var izq_prof: float = PoseJugador.profundidad(esq, PoseJugador.P_HOMBRO_IZQ)
	var der_prof: float = PoseJugador.profundidad(esq, PoseJugador.P_HOMBRO_DER)
	var de_lado: bool = absf(izq_prof - der_prof) > CuerpoSprites.SEPARACION_BRAZOS
	var izq_al_fondo: bool = izq_prof < der_prof
	var canto: float = float(CANTO.get(tipo, 2.0))
	var hom: float = float(HOMBRERA.get(tipo, 1.0))

	# 1. La hombrera del fondo, si de verdad hay una al fondo: la tapa el propio peto. Mismo orden que
	#    la manga de la camisa, y por el mismo motivo (ver la cabecera de ropa_sprites.gd).
	if de_lado and hom > 0.0:
		_hombrera(piezas, esq, izq_al_fondo, hom, Tono.MAT_S)

	# 2. El faldar: las escamas que cuelgan de la cintura. Solo las armaduras pesadas, y es lo que las
	#    separa de un chaleco a este tamaño.
	if FALDAR.has(tipo):
		var cadera: Vector3 = p[PoseJugador.P_CADERA]
		var rod: Vector3 = p[PoseJugador.P_RODILLA_IZQ].lerp(p[PoseJugador.P_RODILLA_DER], 0.5)
		PoseJugador.cadena(piezas, esq, cadera, cadera.lerp(rod, float(FALDAR[tipo])),
			CuerpoSprites.R_CADERA.x * 0.94, CuerpoSprites.R_CADERA.x * 1.10, Tono.MAT_S)

	# 3. El tronco, con los radios EXACTOS del cuerpo.
	PoseJugador.poner(piezas, esq, p[PoseJugador.P_CADERA], CuerpoSprites.R_CADERA, Tono.MAT_S)
	_chapa(piezas, esq, p[PoseJugador.P_TORSO], CuerpoSprites.R_TORSO, canto)

	# 4. EL HUECO DEL BRAZO VA ANTES QUE LAS HOMBRERAS DE DELANTE, y el orden costo entenderlo: una
	#    HOMBRERA VA ENCIMA DEL BRAZO. Pintandola antes, el recorte le pegaba un mordisco por el medio
	#    y le dejaba la punta suelta -- 433 fotogramas con un trozo de mas en el validador de islas del
	#    horno, y a la vista una hombrera partida en dos justo al correr.
	#
	#    Y ADEMAS EMPIEZA MAS ABAJO cuando hay hombrera ('desde'): pintar la hombrera despues del
	#    recorte no basta, porque el recorte le corta el ENGANCHE con el peto y la deja flotando --
	#    un trozo suelto igual, solo que ahora entero en vez de partido. El recorte tiene que parar
	#    donde acaba la hombrera.
	var tonos := [Tono.MAT, Tono.MAT_L, Tono.MAT_S]
	#    Con hombrera el recorte empieza EN EL CODO (0,9) y no a media manga: la hombrera baja hasta
	#    ahi, asi que cualquier corte por encima la parte. Y no se pierde nada -- lo que tapa el brazo
	#    por arriba es la propia hombrera, que es lo que hace una hombrera.
	var desde: float = 0.0 if hom <= 0.0 else 0.9
	CapaJugador.hueco_brazo(piezas, esq, true, tonos, 1.06, desde)
	CapaJugador.hueco_brazo(piezas, esq, false, tonos, 1.06, desde)

	# 5. Las hombreras de delante, ya a salvo del recorte.
	if hom > 0.0:
		if de_lado:
			_hombrera(piezas, esq, not izq_al_fondo, hom, Tono.MAT)
		else:
			_hombrera(piezas, esq, true, hom, Tono.MAT)
			_hombrera(piezas, esq, false, hom, Tono.MAT)

	# 6. Y LA CABEZA LA ULTIMA DE TODAS, despues de las hombreras: la de placas sube bastante y en
	#    diagonal se proyecta sobre la mandibula. Es el mismo motivo por el que en la camisa este
	#    recorte va detras de las mangas.
	CapaJugador.hueco_cabeza(piezas, esq, tonos)


# UNA HOMBRERA: una pieza propia, de las pocas que si pueden salirse de la silueta del cuerpo, porque
# una hombrera de verdad sobresale. 'grande' la escala.
#
# VA BAJA, Y ESO ES CULPA DE LA PROPORCION CABEZONA. El primer intento la puso en el hombro exacto
# (x 1.02, z -1.2) y el resultado fue de manual: EL PUNTO DEL HOMBRO ESTA METIDO DEBAJO DE LA CABEZA.
# El hombro cae a 9,8 de X y a 32,5 de alto, y la cabeza mide 12,8 de radio y empieza a 34,9 -- o sea
# que una hombrera ahi la tapa la cabeza entera menos la punta, y lo que se veia eran DOS ALETAS
# grises asomando al lado de las orejas, sin tocar el peto. Parecian pendientes.
#
# Bajandola al brazo (z -3,2) se apoya en el tronco, se solapa con el de verdad y se lee como lo que
# es. El sitio anatomico del hombro NO es el sitio donde se dibuja una hombrera en este cuerpo.
static func _hombrera(piezas: Array, esq: Dictionary, izq: bool, grande: float, tono: int) -> void:
	var hombro: Vector3 = esq["puntos"][PoseJugador.P_HOMBRO_IZQ if izq else PoseJugador.P_HOMBRO_DER]
	var c := Vector3(hombro.x * 0.92, hombro.y, hombro.z - 3.2)
	var r := CuerpoSprites.R_BRAZO * (0.95 + 0.35 * grande)
	PoseJugador.poner(piezas, esq, c, Vector3(r, r * 0.86, r * 0.72), tono)
	# El canto de luz de la hombrera: solo sobre ella misma, para que no aclare el pecho.
	PoseJugador.poner(piezas, esq, c + Vector3(0.0, 0.0, r * 0.34),
		Vector3(r * 0.66, r * 0.56, r * 0.30), Tono.MAT_L, {"solo_sobre": [tono]})


# ============================================================
#  LOS GUANTELETES
# ============================================================
# UNO POR CAPA (ver SLOTS_POR_MANO). Cubren antebrazo y mano, no el brazo entero: por encima del codo
# empieza a ser la hombrera, y ademas un guantelete que suba hasta el hombro tapa la hombrera del
# peto y las dos se pelean por el mismo sitio.
#
# NO NECESITA RECORTAR NADA: va anclado a la mano y MunecoJugador lo ordena por profundidad, asi que
# cuando la mano esta detras del cuerpo, la capa entera se va detras. Es la ventaja de no llevar z
# fijo, y por eso son dos capas y no una.
static func _guantelete(piezas: Array, esq: Dictionary, tipo: String, izq: bool) -> void:
	var p: Dictionary = esq["puntos"]
	var codo: Vector3 = p[PoseJugador.P_CODO_IZQ if izq else PoseJugador.P_CODO_DER]
	var mano: Vector3 = p[PoseJugador.P_MANO_IZQ if izq else PoseJugador.P_MANO_DER]
	var largo: float = float(GUANTE_LARGO.get(tipo, 0.5))
	var desde: Vector3 = mano.lerp(codo, largo)
	var ra: float = CuerpoSprites.R_ANTEBRAZO
	PoseJugador.cadena(piezas, esq, desde, mano, ra * 1.02, ra * 0.98, Tono.MAT_S)
	var m: float = CuerpoSprites.R_MANO
	PoseJugador.poner(piezas, esq, mano, Vector3(m, m, m), Tono.MAT_S)
	# El dorso, que es lo unico que se ve de un guantelete a este tamaño: un realce sobre la mano.
	PoseJugador.poner(piezas, esq, mano + Vector3(0.0, 0.0, m * 0.42),
		Vector3(m * 0.72, m * 0.66, m * 0.34), Tono.MAT, {"solo_sobre": [Tono.MAT_S]})


# ============================================================
#  LAS GREBAS Y LAS BOTAS
# ============================================================
# LAS GREBAS SUSTITUYEN AL PANTALON, asi que llevan su misma estructura: dos perneras con los radios
# exactos de la pierna y una cintura cortada por arriba. El corte de la cintura es EL MISMO PROBLEMA
# que el del pantalon (ver RopaSprites.CINTURA_CORTE): sin el, la cadera proyecta cuatro celdas hacia
# arriba y las grebas suben hasta el pecho.
const CINTURA_CORTE := -1.0
const CINTURA_R_CORTE := 11.0
const CINTURA_ALTO_CORTE := 6.0

static func _grebas(piezas: Array, esq: Dictionary, tipo: String) -> void:
	var p: Dictionary = esq["puntos"]
	var izq_al_fondo: bool = PoseJugador.profundidad(esq, PoseJugador.P_PIE_IZQ) \
		< PoseJugador.profundidad(esq, PoseJugador.P_PIE_DER)
	var brazo_izq: float = PoseJugador.profundidad(esq, PoseJugador.P_HOMBRO_IZQ)
	var brazo_der: float = PoseJugador.profundidad(esq, PoseJugador.P_HOMBRO_DER)
	var de_lado: bool = absf(brazo_izq - brazo_der) > CuerpoSprites.SEPARACION_BRAZOS
	_pernera(piezas, esq, izq_al_fondo, Tono.MAT_S if de_lado else Tono.MAT)
	_pernera(piezas, esq, not izq_al_fondo, Tono.MAT)

	# La cintura, y su corte de arriba: las dos elipses del pantalon, con los mismos numeros.
	var cadera: Vector3 = p[PoseJugador.P_CADERA]
	PoseJugador.poner(piezas, esq, cadera, CuerpoSprites.R_CADERA, Tono.MAT)
	var sube: float = CINTURA_CORTE / SpriteLienzo.SIN_CAM \
		+ sqrt(CINTURA_R_CORTE * CINTURA_R_CORTE + CINTURA_ALTO_CORTE * CINTURA_ALTO_CORTE)
	PoseJugador.poner(piezas, esq, cadera + Vector3(0.0, 0.0, sube),
		Vector3(CINTURA_R_CORTE, CINTURA_R_CORTE, CINTURA_ALTO_CORTE), Tono.VACIO,
		{"solo_sobre": [Tono.MAT, Tono.MAT_L, Tono.MAT_S]})
	# El cinturon: un canto claro en el borde de arriba, que es lo que dice que eso es una pieza y no
	# la pierna pintada. Solo sobre si mismo, o se sale.
	PoseJugador.poner(piezas, esq, cadera + Vector3(0.0, 0.0, sube - 1.6),
		Vector3(CINTURA_R_CORTE, CINTURA_R_CORTE, CINTURA_ALTO_CORTE), Tono.MAT_L,
		{"solo_sobre": [Tono.MAT, Tono.MAT_S]})
	# Y las manos, que caen a la altura de la cinturilla: el mismo recorte que necesita el pantalon.
	var tonos := [Tono.MAT, Tono.MAT_L, Tono.MAT_S]
	CapaJugador.hueco_brazo(piezas, esq, true, tonos, 1.3)
	CapaJugador.hueco_brazo(piezas, esq, false, tonos, 1.3)


static func _pernera(piezas: Array, esq: Dictionary, izq: bool, tono: int) -> void:
	var p: Dictionary = esq["puntos"]
	var cadera: Vector3 = p[PoseJugador.P_CADERA]
	var rodilla: Vector3 = p[PoseJugador.P_RODILLA_IZQ if izq else PoseJugador.P_RODILLA_DER]
	var pie: Vector3 = p[PoseJugador.P_PIE_IZQ if izq else PoseJugador.P_PIE_DER]
	var arranque := Vector3((1.0 if izq else -1.0) * PoseJugador.PIE_X * 0.82,
		cadera.y, cadera.z - 2.0)
	var tobillo: Vector3 = pie + Vector3(0.0, 0.0, CuerpoSprites.R_PIE.z)
	PoseJugador.cadena(piezas, esq, arranque, rodilla,
		CuerpoSprites.R_MUSLO, CuerpoSprites.R_PANTORRILLA, tono)
	PoseJugador.cadena(piezas, esq, rodilla, tobillo,
		CuerpoSprites.R_PANTORRILLA, CuerpoSprites.R_PANTORRILLA * 0.85, tono)
	# La rodillera: lo unico que distingue unas grebas de un pantalon a este tamaño.
	PoseJugador.poner(piezas, esq, rodilla,
		Vector3(CuerpoSprites.R_PANTORRILLA * 1.12, CuerpoSprites.R_PANTORRILLA * 1.02,
			CuerpoSprites.R_PANTORRILLA * 0.72), Tono.MAT_L, {"solo_sobre": [tono]})


# LAS BOTAS: el pie y la caña. El pie del cuerpo ya va oscuro (Tono.CALZADO), asi que lo que aporta
# la bota es la CAÑA y el material -- por eso sube por la pantorrilla en vez de quedarse en el pie.
static func _botas(piezas: Array, esq: Dictionary, tipo: String) -> void:
	var p: Dictionary = esq["puntos"]
	var alto: float = float(BOTA_ALTO.get(tipo, 0.45))
	for izq in [true, false]:
		var rodilla: Vector3 = p[PoseJugador.P_RODILLA_IZQ if izq else PoseJugador.P_RODILLA_DER]
		var pie: Vector3 = p[PoseJugador.P_PIE_IZQ if izq else PoseJugador.P_PIE_DER]
		var tobillo: Vector3 = pie + Vector3(0.0, 0.0, CuerpoSprites.R_PIE.z)
		var arriba: Vector3 = tobillo.lerp(rodilla, alto)
		PoseJugador.cadena(piezas, esq, arriba, tobillo,
			CuerpoSprites.R_PANTORRILLA * 0.92, CuerpoSprites.R_PANTORRILLA * 0.88, Tono.MAT_S)
		PoseJugador.poner(piezas, esq, pie, CuerpoSprites.R_PIE * 1.04, Tono.MAT)
		# El canto de la caña, arriba: dice donde acaba la bota y empieza la pierna.
		PoseJugador.poner(piezas, esq, arriba,
			Vector3(CuerpoSprites.R_PANTORRILLA * 0.96, CuerpoSprites.R_PANTORRILLA * 0.90, 1.0),
			Tono.MAT_L, {"solo_sobre": [Tono.MAT_S]})


# UNA CHAPA: la masa del casco con su volumen. ES DONDE VIVE TODO EL VOLUMEN, porque la regla de la
# ropa vale igual aqui -- la armadura no engorda el cuerpo, lo recolorea --, asi que lo que dice
# "esto es acero curvo y duro" no puede ser el radio: tiene que ser la luz apretada arriba y un canto
# oscuro fino abajo.
#
# EL CANTO SE HACE CON DOS ELIPSES DESPLAZADAS, Y NO CON UNA BANDA. Es LA leccion de este fichero y
# ya ha costado dos intentos: en esta camara COS_CAM y SIN_CAM valen los dos 0,7071, o sea que
#     ey = 0,7071 x raiz(fondo² + alto²)
# y el FONDO manda. Una "banda ancha y plana" de 1 de alto pero 13 de fondo proyecta NUEVE unidades
# hacia arriba y se come el casco entero -- que es exactamente lo que hizo, dos veces: primero como
# ala solida (se comio la cara) y luego como franja con 'solo_sobre' (se comio la cazoleta). En esta
# camara "ancho y plano" NO EXISTE.
#
# Lo que si funciona: pintar la masa entera en sombra y volver a pintarla en tono base UN POCO MAS
# ARRIBA. Lo que asoma por debajo es una media luna del grosor que se quiera, medido en unidades de
# verdad, y funciona igual en las ocho direcciones porque las dos elipses son la misma.
static func _chapa(piezas: Array, esq: Dictionary, centro: Vector3, r: Vector3,
		canto: float) -> void:
	PoseJugador.poner(piezas, esq, centro, r, Tono.MAT_S)
	PoseJugador.poner(piezas, esq, centro + Vector3(0.0, 0.0, canto), r, Tono.MAT,
		{"solo_sobre": [Tono.MAT_S]})
	# La luz: un parche ALTO Y PEQUEÑO, no una capa mas. Repartida en suave la chapa se lee como
	# plastico; apretada arriba se lee como metal. Mismo criterio que el realce del pecho del cuerpo.
	PoseJugador.poner(piezas, esq, centro + Vector3(0.0, -r.y * 0.10, r.z * 0.46),
		Vector3(r.x * 0.58, r.y * 0.52, r.z * 0.28), Tono.MAT_L, {"solo_sobre": [Tono.MAT]})
