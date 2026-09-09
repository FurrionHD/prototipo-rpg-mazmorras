# ============================================================
#  barba_sprites.gd  (class_name BarbaSprites)
#  LA BARBA: la mitad de abajo de la cabeza.
#
#  Hermana del pelo, y con el mismo reparto de trabajo: UN SOLO PINTOR para todos los modelos, porque
#  la masa de la mandibula es la misma en los cuatro y lo unico que cambia es cuanto baja y si lleva
#  bigote. Cuatro funciones separadas serian cuatro sitios donde arreglar la misma mandibula.
#
#  VA POR ENCIMA DE LA CARA Y DE TU FOTO (z 2050, ver JugadorSprites.Z_BARBA), al reves que el pelo.
#  El pelo va DEBAJO de la foto para enmarcarla; una barba no enmarca nada, TAPA -- cubre la
#  mandibula y la boca, y por debajo de la foto lo unico que se veria seria el borde que asoma por
#  fuera del circulo de la cara, o sea casi nada.
#
#  SE TIÑE (se hornea en gris, ver CapaJugador.grises): el color lo elige el jugador, y va APARTE del
#  color del pelo a proposito -- un viejo con el pelo blanco y la barba castaña no existe, pero el
#  maestro de la Meditacion es justo el caso de "barba mas blanca que el pelo".
# ============================================================

extends RefCounted
class_name BarbaSprites

const PIEZA := "barba"

# Los tonos, en el orden de CapaJugador.grises: contorno, sombra, base, luz.
enum Tono {
	VACIO = 0, SOMBRA_SUELO = 1, BORDE = 2,
	PELO_S,     # la parte de fondo (bajo el menton, y el lado que queda en sombra)
	PELO,       # el tono base
	PELO_L,     # el brillo, por donde da la luz
}

const R := PoseJugador.CABEZA_R

# HACIA DONDE MIRA LA BARBA. En esta proyeccion +Y es "hacia la cara" y +Z es "arriba" (ver
# PeloSprites: el flequillo va a +Y y la nuca a -Y). Asi que la barba vive en +Y y -Z, y con un solo
# par de numeros queda bien en las ocho direcciones: de frente se ve entera y de espaldas la tapa la
# propia cabeza, que es exactamente lo que pasa de verdad.
#
# LOS DOS VAN MUY POR DELANTE Y MUY ABAJO, y la primera version se quedo MUY corta (0,30 y 0,42):
# con eso la barba se plantaba a MEDIA CABEZA y lo que salia en la hoja de contacto era un casco gris
# que tapaba la cara entera. Una barba ocupa el TERCIO DE ABAJO y nada mas; la referencia es la cara,
# que es un circulo del 80% de la cabeza, asi que para quedar por debajo de los ojos hay que bajar
# mas de medio radio.
const DELANTE := 0.46
const BAJA := 0.78

# Lo que sobresale de la cara. Como el pelo, tiene que pasar de una celda (1,15) o la barba sale a
# trozos entre los pixeles de la cabeza, como suciedad en vez de pelo.
const GROSOR := 1.3


# --- Contrato de capa (ver CapaJugador y el registro de JugadorSprites) ---
static func frames(modelo: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.frames(clave(modelo), pintar.bind(modelo), colores(), esc)


static func generar(modelo: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.generar(clave(modelo), pintar.bind(modelo), colores(), esc)


static func clave(modelo: String) -> String:
	return "%s_%s" % [PIEZA, modelo]


static func colores() -> Array:
	# Los mismos grises que el pelo: es el mismo material y tienen que poder llevar el mismo color
	# sin que uno salga mas apagado que el otro.
	return CapaJugador.grises(0.20, 0.38, 0.62, 0.82, 0.94)


# ============================================================
#  EL PINTOR
# ============================================================
static func pintar(esq: Dictionary, piezas: Array, modelo: String) -> void:
	# DE ESPALDAS NO HAY BARBA, exactamente igual que no hay ojos (ver CaraSprites.pintar): 3, 4 y 5
	# son NE, N y NW, o sea la nuca.
	#
	# HAY QUE DECIDIRLO AQUI, POR DIRECCION, Y NO CONFIAR EN QUE LA TAPE LA CABEZA. Esta capa va con
	# z FIJO y por encima de todo (JugadorSprites.Z_BARBA), asi que nada la oculta nunca: en la
	# primera hoja de contacto la barba se veia flotando sobre la NUCA en las tres direcciones de
	# espaldas. El pelo no tiene este problema porque el casquete cubre la cabeza entera y es
	# simetrico; una barba solo existe por delante.
	var d: int = int(esq.get("dir", 0))
	if d == 3 or d == 4 or d == 5:
		return
	var p: Dictionary = esq["puntos"]
	var cab: Vector3 = p[PoseJugador.P_CABEZA]

	match modelo:
		"bigote":
			_bigote(piezas, esq, cab, 1.0)
		"perilla":
			_bigote(piezas, esq, cab, 0.85)
			_perilla(piezas, esq, cab)
		"candado":
			_bigote(piezas, esq, cab, 0.95)
			_mandibula(piezas, esq, cab, 0.55)
			_perilla(piezas, esq, cab)
		"poblada":
			_bigote(piezas, esq, cab, 1.05)
			_mandibula(piezas, esq, cab, 1.0)
		"larga":
			_bigote(piezas, esq, cab, 1.05)
			_mandibula(piezas, esq, cab, 1.0)
			# LA PUNTA se mece con el paso, igual que la coleta: una barba larga que va tiesa mientras
			# el personaje anda se lee como una tabla colgada del menton.
			_punta(piezas, esq, cab, float((esq["pose"] as Dictionary).get("paso", 0.0)),
				float(esq.get("caida", 0.0)))
		_:
			_mandibula(piezas, esq, cab, 0.8)


# LA MASA DE LA MANDIBULA: lo que va de patilla a patilla por debajo de la cara. 'grueso' es cuanto
# baja y cuanto sobresale.
#
# VA ACHATADA EN Y Y ANCHA EN X. Redonda se lee como una bufanda o como una papada: lo que la hace
# barba es que sea ANCHA (de oreja a oreja) y POCO PROFUNDA, pegada a la cara.
static func _mandibula(piezas: Array, esq: Dictionary, cab: Vector3, grueso: float) -> void:
	var g: float = GROSOR * grueso
	# EL FONDO PRIMERO. No hay z-buffer dentro de una capa -- el orden de la lista es la profundidad
	# --, asi que lo que va detras se pinta antes. Es la misma regla que la nuca del pelo, y saltarsela
	# deja un manchon de sombra cruzando por encima de la barba.
	PoseJugador.poner(piezas, esq,
		cab + Vector3(0.0, R * DELANTE * 0.70, -R * (BAJA + 0.10 * grueso)),
		Vector3(R * (0.40 + 0.12 * grueso), R * 0.30, R * (0.18 + 0.14 * grueso)), Tono.PELO_S)
	PoseJugador.poner(piezas, esq,
		cab + Vector3(0.0, R * DELANTE, -R * BAJA),
		Vector3(R * (0.36 + 0.14 * grueso) + g * 0.3, R * 0.28 + g * 0.25,
			R * (0.20 + 0.16 * grueso) + g * 0.25), Tono.PELO)
	# LAS PATILLAS: suben por delante de las orejas a enlazar con el pelo. Sin ellas la barba queda
	# colgando del menton como una careta y no parece que salga de la cara.
	#
	# ESTRECHAS Y CORTAS. En la primera version iban a 0,80 del radio de ancho y llegaban casi hasta
	# la coronilla: entre las dos rodeaban la cabeza y la barba se leia como un casco.
	if grueso < 0.7:
		return
	for lado in 2:
		var s: float = 1.0 if lado == 0 else -1.0
		PoseJugador.poner(piezas, esq,
			cab + Vector3(s * R * 0.62, R * 0.16, -R * 0.46),
			Vector3(R * 0.16, R * 0.26, R * (0.18 + 0.12 * grueso)), Tono.PELO)


# EL BIGOTE: la raya bajo la nariz. Es la pieza que mas dice a este tamaño -- una barba sin bigote se
# lee como una bufanda subida --, asi que la llevan los cuatro modelos.
static func _bigote(piezas: Array, esq: Dictionary, cab: Vector3, ancho: float) -> void:
	PoseJugador.poner(piezas, esq,
		cab + Vector3(0.0, R * (DELANTE + 0.28), -R * 0.16),
		Vector3(R * 0.40 * ancho, R * 0.24, R * 0.13), Tono.PELO)


# LA PERILLA: el mechon del menton, estrecho y centrado. Lo que separa una perilla de una barba
# poblada es que NO llega a las patillas.
static func _perilla(piezas: Array, esq: Dictionary, cab: Vector3) -> void:
	PoseJugador.poner(piezas, esq,
		cab + Vector3(0.0, R * (DELANTE + 0.10), -R * (BAJA + 0.16)),
		Vector3(R * 0.24, R * 0.30, R * 0.30), Tono.PELO)


# LA PUNTA DE LA BARBA LARGA: cae desde el menton hacia el pecho, meciendose con el paso.
static func _punta(piezas: Array, esq: Dictionary, cab: Vector3, vaiven: float,
		caida: float) -> void:
	var arriba: Vector3 = cab + Vector3(0.0, R * DELANTE, -R * (BAJA + 0.20))
	# SE RECOGE AL CAERSE, igual que la coleta y por el mismo motivo: tiesa, con el cuerpo tumbado la
	# barba se sale del lienzo y el horno la corta en seco con una raya recta. Y ademas es lo que hace
	# el pelo de verdad: tumbado se apelmaza, no se queda apuntando al frente.
	var tumbado: float = clampf(absf(caida) / (PI * 0.5), 0.0, 1.0)
	var largo: float = lerpf(1.0, 0.45, sqrt(tumbado))
	var medio: Vector3 = arriba + Vector3(vaiven * R * 0.14, R * 0.05, -R * 0.42 * largo)
	var punta: Vector3 = arriba + Vector3(vaiven * R * 0.24, -R * 0.02, -R * 0.86 * largo)
	PoseJugador.cadena(piezas, esq, arriba, medio, R * 0.30, R * 0.22, Tono.PELO)
	PoseJugador.cadena(piezas, esq, medio, punta, R * 0.22, R * 0.10, Tono.PELO_S)
