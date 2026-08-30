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

# DE QUE RANURAS SE SABE DIBUJAR HOY. Las otras cuatro estan en ArmorData desde el principio y su
# hueco esta hecho en JugadorSprites, pero sin pintor: pedirlas no rompe nada, simplemente no sale
# nada. Añadir una es meterla aqui y darle su rama en 'pintar'.
const SLOTS_HECHOS := ["casco"]

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
		out.append(clave(tipo, slot))
	return out


static func todas_las_claves() -> Array:
	var out: Array = []
	for tipo in TIPO_NOMBRE:
		out.append_array(claves_de(tipo))
	return out


# ============================================================
#  EL PARSEO DE LA CLAVE
# ============================================================
# El tipo puede llevar guion bajo dentro ("hierro_completo"), asi que NO vale partir por "_" y coger
# trozos: se busca el slot por el final, que es la parte que no tiene ambiguedad.
static func _parse(clave: String) -> Dictionary:
	var s: String = clave.trim_prefix("armadura_")
	for slot in SLOT_NOMBRE:
		if s.ends_with("_" + slot):
			return {"tipo": s.trim_suffix("_" + slot), "slot": slot}
	return {}


# ============================================================
#  EL PINTOR
# ============================================================
static func pintar(esq: Dictionary, piezas: Array, clave: String) -> void:
	var info: Dictionary = _parse(clave)
	if info.is_empty():
		return
	match String(info["slot"]):
		"casco": _casco(piezas, esq, String(info["tipo"]), int(esq.get("dir", 0)))


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
