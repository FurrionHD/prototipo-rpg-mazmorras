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

# ============================================================
#  COMO VA LA BARBA
# ============================================================
# REHECHA el 17/09/2026 con las capturas del usuario. La version anterior era un BULTO delante de la
# cara (una masa de mandibula adelantada) colocado para que DE FRENTE cayera en su sitio, y fallaba en
# todo lo demas: de frente colgaba hacia abajo, de medio lado era un manchon sobre la mejilla y de
# perfil, al girar, el bulto adelantado subia en pantalla y TAPABA EL OJO. (Adelantarse solo baja en
# pantalla mirando al sur; de perfil ese adelanto va de lado.)
#
# AHORA SON TROZOS PEGADOS A LA PIEL, en puntos de la superficie de la cabeza (la forma que dibuja
# CuerpoSprites: semiejes 1 / 0,90 / 0,96) dados por LONGITUD (grados alrededor, 0 = de frente) y
# LATITUD (grados bajo el ecuador). Como la capa va con z fijo por encima de la cabeza y nada la tapa,
# cada trozo se pinta SOLO SI MIRA A CAMARA (su fondo girado, ver _anadir): de frente se ve entera, de
# medio lado el lado que da a la camara y de perfil un poco, abajo y delante.
#
# LA CARA QUE SE VE ES DIMINUTA: bajo el pelo quedan unos 8 px de ancho y 3 de alto, con los ojos en
# una fila y la boca en la de debajo. No hay sitio para una barba "debajo de la boca", asi que se hace
# pegada a la forma de la cara por abajo: una fila en la BARBILLA de lado a lado, los LADOS de la
# mandibula por fuera de los ojos y un bigote pequeño. Patillas y carrillos a la altura de la boca se
# probaron y quedaban pegados a los ojos (gafas de sol).
#
# Medidas de la cara (CaraSprites): ojos a z -0,18 y de 0,19 a 0,49 de ancho; boca a z -0,42.

# Cuanto se mete hacia dentro en fondo. La cara no esta en la superficie de la bola sino mas adentro
# (los ojos a 0,58, ver CaraSprites.OJO_FONDO): en la superficie de verdad asomaria por la silueta.
const FONDO_SUPERFICIE := 0.80
# Un trozo cuenta como "de cara a la camara" si su fondo girado pasa de esto (en radios).
const UMBRAL_VISIBLE := 0.20
# El tamaño de un trozo, en radios. Tiene que pasar de una celda o sale a pixeles sueltos.
const TROZO := Vector3(0.14, 0.10, 0.12)

# Donde va cada parte: [longitud, latitud, cuanto CUELGA]. MEDIDO en pantalla, no a ojo: de frente
# los ojos caen en la fila 44,5, la boca en la 46,4 y el borde de la barbilla en la 48,8 (celdas del
# lienzo). Lo que quede por encima de ~47 se pega a los ojos y se lee como GAFAS DE SOL (paso dos
# veces). Y la superficie metida hacia dentro no baja nunca de la 47,9, asi que lo de la barbilla
# CUELGA un poco en altura real ('cuelga', en radios): bajar en Z baja igual en pantalla mire hacia
# donde mire, al reves que adelantarse, y por eso de perfil no vuelve a subirse al ojo.
# La barbilla, de lado a lado por debajo de la boca.
const BARBILLA := [[0.0, 56.0, 0.12], [15.0, 56.0, 0.12], [30.0, 56.0, 0.11]]
# Los lados de la mandibula, por FUERA de los ojos (acaban en 0,49 de ancho) y bajos.
const LADOS := [[45.0, 56.0, 0.07], [60.0, 58.0, 0.03]]


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
	# DE ESPALDAS NO HAY BARBA: 3, 4 y 5 son NE, N y NW.
	var d: int = int(esq.get("dir", 0))
	if d == 3 or d == 4 or d == 5:
		return
	var cab: Vector3 = esq["puntos"][PoseJugador.P_CABEZA]
	var cand: Array = []   # [fondo girado, local, radio, tono]: se ordenan antes de pintar

	match modelo:
		"bigote":
			_bigote(cand, esq, cab)
		"perilla":
			_bigote(cand, esq, cab)
			_perilla(cand, esq, cab)
		"candado":
			# Bigote y la barbilla estrecha: sin los lados de la mandibula.
			_bigote(cand, esq, cab)
			_parte(cand, esq, cab, BARBILLA.slice(0, 2), Tono.PELO)
		"poblada":
			_poblada(cand, esq, cab)
		"larga":
			_poblada(cand, esq, cab)
			_punta(cand, esq, cab, float((esq["pose"] as Dictionary).get("paso", 0.0)),
				float(esq.get("caida", 0.0)))
		_:
			_poblada(cand, esq, cab)

	# LO DE DETRAS PRIMERO: no hay z-buffer dentro de una capa, el orden de la lista es la profundidad.
	cand.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	for c in cand:
		PoseJugador.poner(piezas, esq, c[1], c[2], int(c[3]))


static func _poblada(cand: Array, esq: Dictionary, cab: Vector3) -> void:
	_parte(cand, esq, cab, LADOS, Tono.PELO_S)
	_parte(cand, esq, cab, BARBILLA, Tono.PELO)
	_bigote(cand, esq, cab)


# Un punto de la superficie de la cabeza (metido hacia dentro, ver FONDO_SUPERFICIE).
static func _superficie(cab: Vector3, lon: float, lat: float) -> Vector3:
	var lo: float = deg_to_rad(lon)
	var la: float = deg_to_rad(-lat)
	return cab + Vector3(R * sin(lo) * cos(la) * 0.95,
		R * 0.90 * FONDO_SUPERFICIE * cos(lo) * cos(la),
		R * 0.96 * sin(la))


# Cuanto mira hacia la camara ese punto, en radios de cabeza: su fondo tras girar con el cuerpo.
static func _fondo(esq: Dictionary, cab: Vector3, local: Vector3) -> float:
	var rel := Vector2(local.x - cab.x, local.y - cab.y)
	return rel.rotated(PoseJugador.ang_en(esq, local.z)).y / R


# Mete el trozo SOLO si da a la camara: nada tapa esta capa, asi que lo de detras hay que no pintarlo.
static func _anadir(cand: Array, esq: Dictionary, cab: Vector3, local: Vector3, r: Vector3,
		tono: int, umbral: float = UMBRAL_VISIBLE) -> void:
	var f: float = _fondo(esq, cab, local)
	if f < umbral:
		return
	cand.append([f, local, r, tono])


# Una parte de la barba: cada [lon, lat, cuelga] de la lista, a los DOS lados (el 0 solo una vez).
static func _parte(cand: Array, esq: Dictionary, cab: Vector3, puntos: Array, tono: int,
		umbral: float = UMBRAL_VISIBLE) -> void:
	var r := Vector3(R * TROZO.x, R * TROZO.y, R * TROZO.z)
	for pt in puntos:
		var lon: float = float(pt[0])
		for lado in ([1.0] if is_zero_approx(lon) else [1.0, -1.0]):
			var cuelga: float = float(pt[2]) if pt.size() > 2 else 0.0
			_anadir(cand, esq, cab, _superficie(cab, lon * float(lado), float(pt[1]))
				+ Vector3(0.0, 0.0, -R * cuelga), r, tono, umbral)


# EL BIGOTE: a la altura de la boca, en dos trozos pequeños (uno a cada lado) para que de perfil solo
# asome el de delante. Y con un umbral MAS ALTO: en diagonal la boca cae en la misma fila que el ojo
# de delante, y el trozo del bigote del lado de atras quedaba pegado a el.
static func _bigote(cand: Array, esq: Dictionary, cab: Vector3) -> void:
	_parte(cand, esq, cab, [[11.0, 34.0, 0.0]], Tono.PELO, 0.45)


# LA PERILLA: el mechon de la barbilla, estrecho y centrado.
static func _perilla(cand: Array, esq: Dictionary, cab: Vector3) -> void:
	_parte(cand, esq, cab, [[0.0, 56.0, 0.12], [0.0, 60.0, 0.24]], Tono.PELO)


# LA PUNTA DE LA BARBA LARGA: cae desde la barbilla hacia el pecho, meciendose con el paso.
static func _punta(cand: Array, esq: Dictionary, cab: Vector3, vaiven: float, caida: float) -> void:
	var arriba: Vector3 = _superficie(cab, 0.0, 56.0) + Vector3(0.0, 0.0, -R * 0.18)
	# Colgando bajo la cabeza el fondo propio de cada trozo es casi cero: manda el de la barbilla.
	if _fondo(esq, cab, arriba) < UMBRAL_VISIBLE:
		return
	# SE RECOGE AL CAERSE, igual que la coleta: tiesa, con el cuerpo tumbado se sale del lienzo.
	var tumbado: float = clampf(absf(caida) / (PI * 0.5), 0.0, 1.0)
	var largo: float = lerpf(1.0, 0.45, sqrt(tumbado))
	var medio: Vector3 = arriba + Vector3(vaiven * R * 0.10, R * 0.02, -R * 0.26 * largo)
	var punta: Vector3 = arriba + Vector3(vaiven * R * 0.18, -R * 0.02, -R * 0.50 * largo)
	for tramo in [[arriba, medio, 0.15, 0.11, Tono.PELO], [medio, punta, 0.11, 0.06, Tono.PELO_S]]:
		var a: Vector3 = tramo[0]
		var b: Vector3 = tramo[1]
		var pasos: int = maxi(2, int(ceil(a.distance_to(b) / (R * 0.14))))
		for k in pasos + 1:
			var f: float = float(k) / float(pasos)
			var rr: float = R * lerpf(float(tramo[2]), float(tramo[3]), f)
			# +1: por delante del resto de la barba, de la que cuelga.
			cand.append([_fondo(esq, cab, a.lerp(b, f)) + 1.0, a.lerp(b, f), Vector3(rr, rr, rr),
				int(tramo[4])])
