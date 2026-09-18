# ============================================================
#  cara_sprites.gd  (class_name CaraSprites)
#  LOS OJOS. La boca va aparte (BocaSprites): se eligen por separado (lo pidio el usuario).
#
#  Es una capa normal, con su atlas y su sitio en el catalogo (JugadorSprites.CATALOGO["cara"]): hereda
#  las animaciones, el giro por direccion y el horneado. SOLO SE MONTA SI NO LLEVAS FOTO (con imagen
#  propia, tu imagen ES tu cara, ver JugadorSprites.capas_de).
#
#  SE DIBUJAN COMO SELLOS DE PIXELES, NO COMO ELIPSES (17/09/2026). Un ojo de frente mide unos 4x3
#  pixeles, y una elipse a ese tamaño sale como una mancha: el motor decide que pixeles caen dentro y
#  la forma no se controla. Con las referencias de pixel art que paso el usuario (ojos pequeños con
#  pestaña, iris y brillo) la unica forma de llegar ahi es poner cada pixel: se calcula DONDE cae el
#  ojo en este fotograma (la proyeccion de siempre, asi gira con la cabeza) y alli se estampa un dibujo
#  fijo. Ver sello().
#
#  EL IRIS VA EN SU PROPIA CAPA. La capa se tiñe multiplicando por un solo color (capa_jugador.gdshader),
#  asi que teñirla entera pondria de color tambien la pestaña y el brillo. Los modelos con iris llevan
#  "iris": true en el catalogo y se hornean DOS veces: la normal (pestaña, blanco, brillo: sin teñir) y
#  la "_iris" (solo el iris, en gris, teñida con el color de ojos que elijas).
#
#  Y TRES COSAS QUE SIGUEN VALIENDO DE ANTES:
#   1. SIN CONTORNO: CapaJugador.plantilla convierte en T_BORDE todo pixel que toque el vacio, y en un
#      ojo de uno o dos pixeles de grueso eso es el ojo entero. Los sellos lo saltan ("sin_contorno").
#   2. DE PERFIL SE DIBUJA UN SOLO OJO: los dos girando, el de la otra mitad cae sobre la mejilla.
#   3. DE ESPALDAS NO SE DIBUJA NADA (direcciones 3, 4 y 5: la nuca).
# ============================================================

extends RefCounted
class_name CaraSprites

const PIEZA := "cara"
const SUFIJO_IRIS := "_iris"

enum Tono {
	VACIO = 0, SOMBRA_SUELO = 1, BORDE = 2,
	LINEA,      # la pestaña, el parpado, la pupila de los ojos sin color: casi negro
	BLANCO,     # el blanco del ojo
	BRILLO,     # el punto de luz
	IRIS,       # gris medio: con el tinte sale EXACTAMENTE el color elegido (base 0,62 del shader)
	PUPILA,     # gris oscuro: el mismo color, mas oscuro
	BOCA,       # la raya de la boca (la usa BocaSprites, que comparte paleta)
	BOCA_DENTRO,
	LENGUA,
}

const R := PoseJugador.CABEZA_R

# DONDE CAEN LOS RASGOS en la cabeza, en fracciones de su radio. MEDIDO, no a ojo: bajo el pelo quedan
# unas pocas filas de cara, y los ojos van en medio de esa franja.
const OJO_ALTO := -0.18          # respecto al centro de la cabeza
const OJO_SEPARACION := 0.34
# Cuanto se adelantan sobre el eje del cuerpo. Dentro del fondo de la cabeza (0,90) o flotan.
const OJO_FONDO := 0.58
const BOCA_ALTO := -0.42
# Cuanto se va la boca hacia el morro de perfil.
const BOCA_PERFIL := 0.30


# ============================================================
#  LOS DIBUJOS
# ============================================================
# Cada ojo es una lista de filas de arriba abajo, dibujado para el ojo que cae a la DERECHA de la cara
# en pantalla (mirando al sur); el otro es su espejo. Letras:
#   L linea (oscuro) · W blanco · H brillo · I iris · P pupila · . nada
# El centro del dibujo cae en el sitio del ojo.
#
# NO TODOS FEMENINOS (lo pidio el usuario): solo "anime" lleva pestañas; el resto son neutros.
const OJOS := {
	# Los tres de siempre, redibujados (sus claves se quedan para no romper partidas guardadas).
	"puntos": ["LL", "LL"],
	"chibi": ["HL", "LL", "LL"],
	"linea": ["LLL"],
	# Los nuevos.
	"serios": ["LLL", ".L."],
	"cansados": ["LLL", "LPL"],
	"felices": [".L.", "L.L"],
	"enfadados": ["L..", ".LL", ".LL"],
	"grandes": [".LL.", "LHIL", ".PP."],
	"anime": ["LLLL", "WHIW", ".IP."],
}

const LETRAS := {
	"L": Tono.LINEA, "W": Tono.BLANCO, "H": Tono.BRILLO, "I": Tono.IRIS, "P": Tono.PUPILA,
	"B": Tono.BOCA, "D": Tono.BOCA_DENTRO, "T": Tono.LENGUA,
}
# Los tonos que van en la capa teñida (la "_iris"). Todo lo demas va en la capa sin teñir.
const TONOS_IRIS := [Tono.IRIS, Tono.PUPILA]


# --- Contrato de capa (ver CapaJugador y el registro de JugadorSprites) ---
static func frames(modelo: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.frames(clave(modelo), pintar.bind(modelo), colores(), esc)


static func generar(modelo: String, esc: float = 1.0) -> SpriteFrames:
	return CapaJugador.generar(clave(modelo), pintar.bind(modelo), colores(), esc)


static func clave(modelo: String) -> String:
	return "%s_%s" % [PIEZA, modelo]


# ¿Este modelo tiene iris de color (y por tanto su segunda capa)?
static func tiene_iris(modelo: String) -> bool:
	for fila in OJOS.get(modelo, []):
		if String(fila).contains("I") or String(fila).contains("P"):
			return true
	return false


# LA PALETA, compartida con BocaSprites. El iris va en gris: lo colorea el tinte (ver la cabecera). En
# la capa sin teñir no se pinta ningun pixel de iris, asi que su gris no se ve nunca sin color.
static func colores() -> Array:
	return [
		Color(0, 0, 0, 0),           # VACIO
		Color(0, 0, 0, 0.20),        # SOMBRA_SUELO (no se usa)
		Color(0, 0, 0, 0),           # BORDE: transparente (ver el punto 1 de la cabecera)
		Color(0.13, 0.09, 0.11),     # LINEA
		Color(0.96, 0.96, 0.98),     # BLANCO
		Color(1.0, 1.0, 1.0),        # BRILLO
		Color(0.62, 0.62, 0.62),     # IRIS
		Color(0.30, 0.30, 0.30),     # PUPILA
		Color(0.40, 0.18, 0.18),     # BOCA
		Color(0.45, 0.10, 0.14),     # BOCA_DENTRO
		Color(0.90, 0.48, 0.52),     # LENGUA
	]


# ============================================================
#  DONDE VA CADA RASGO: MEDIDO SOBRE LA PIEL QUE SE VE
# ============================================================
# Primero se colocaban proyectando un punto de la cabeza, como el resto del muñeco, y fallaba fuera
# del sur (lo vio el usuario): el pelo (z 2047, debajo de la cara) TAPA casi toda la cabeza y la piel
# que queda a la vista no es la que diria la geometria. Medido con un mapa de pixeles de cuerpo + pelo:
#   - de frente, la cara es la franja de abajo, centrada;
#   - en diagonal, solo la ESQUINA de abajo del lado al que mira (el ojo de atras caia sobre el pelo);
#   - de perfil, una TIRA de 2-3 px en el borde de delante (el ojo y la boca metidos hacia dentro
#     acababan encima del pelo).
# Asi que van en pixeles medidos, RELATIVOS al centro de la cabeza en ESTE fotograma (redondeado): siguen
# el bote al andar y el golpe igual que antes. Corto y largo tapan igual esta zona.
#
# Se miden para S (0), SE (1) y E (2); W (6) y SW (7) son su espejo. Numeros en pixeles del lienzo:
#   'ojo' = centro del ojo de la DERECHA de la pantalla (el otro es su espejo de frente, y en diagonal
#          lleva su propio sitio: 'ojo_atras'); en perfil, 'borde' = la columna de delante del ojo.
#   'boca' = centro de la boca; en perfil, 'boca_borde' = su columna de delante.
#
# Los numeros salen del MODELO 3D (herramientas/ver_modelo_3d.bat → modelo3d_cara.json, 18/09/2026),
# llevados a nuestra cabeza y CORREGIDOS contra la piel que se ve:
#   - se pasa la medida del modelo a fraccion de SU radio de cabeza (12,21 px) y se multiplica por el
#     nuestro (11,13 px): el factor es 0,91;
#   - lo que cae fuera de nuestra silueta se arrima al borde de la piel. Copiarlo en crudo fue el fallo
#     del 17/09: la cabeza del modelo es mas grande y con la cara mas adelantada, asi que en diagonal
#     y de perfil el ojo de atras se quedaba FUERA de la cara.
#   - y el modelo va CALVO: en diagonal y de perfil pone los ojos donde nuestro pelo tapa. Los rasgos se
#     bajan a la franja de piel que queda libre CON CUALQUIER PEINADO (medido con un mapa de la piel
#     contra los seis peinados horneados), que es lo unico que se ve de verdad.
# Respecto a lo que habia: los ojos van mas separados y una fila mas abajo, y la boca baja dos filas.
const SITIOS := {
	0: {"ojo": Vector2(3.5, 7.0), "boca": Vector2(0.0, 10.0)},
	1: {"ojo": Vector2(7.5, 7.0), "ojo_atras": Vector2(2.5, 8.5), "boca": Vector2(5.0, 10.5)},
	2: {"borde": 9, "ojo_y": 4.0, "boca_borde": 8, "boca_y": 6.5},
}


# ============================================================
#  EL PINTOR
# ============================================================
static func pintar(esq: Dictionary, piezas: Array, modelo: String) -> void:
	var d: int = int(esq.get("dir", 0))
	if d == 3 or d == 4 or d == 5:
		return
	var iris: bool = modelo.ends_with(SUFIJO_IRIS)
	var base: String = modelo.trim_suffix(SUFIJO_IRIS) if iris else modelo
	var dibujo: Array = OJOS.get(base, [])
	if dibujo.is_empty():
		return
	var c: Vector2i = centro_cabeza(esq)
	var espejar: bool = d == 6 or d == 7
	var dm: int = {0: 0, 1: 1, 7: 1, 2: 2, 6: 2}[d]
	var sitio: Dictionary = SITIOS[dm]
	var ancho: int = String(dibujo[0]).length()
	var alto: int = dibujo.size()
	if dm == 2:
		# De perfil, UN ojo, con su columna de delante en el borde medido.
		var x0: int = c.x + int(sitio["borde"]) - ancho + 1
		var y0: int = int(floor(float(c.y) + float(sitio["ojo_y"]) - float(alto - 1) * 0.5))
		# La tira de piel de perfil mide 3 px: de un ojo ancho solo caben sus 3 columnas de delante.
		var cols: Array = []
		for i in ancho:
			if i >= ancho - 3:
				cols.append(i)
		sello_en(piezas, x0, y0, dibujo, false, iris, cols, c.x, espejar)
		return
	var derecha: Vector2 = sitio["ojo"]
	var izquierda: Vector2 = sitio.get("ojo_atras", Vector2(-derecha.x - 1.0, derecha.y))
	if dm == 0:
		izquierda = Vector2(-derecha.x - 1.0, derecha.y)
	for lado in [[derecha, false], [izquierda, true]]:
		var cen: Vector2 = lado[0]
		var x0b: int = int(floor(float(c.x) + cen.x - float(ancho - 1) * 0.5))
		var y0b: int = int(floor(float(c.y) + cen.y - float(alto - 1) * 0.5))
		sello_en(piezas, x0b, y0b, dibujo, bool(lado[1]), iris, [], c.x, espejar)


# El centro de la cabeza en este fotograma, en pixeles enteros del lienzo.
static func centro_cabeza(esq: Dictionary) -> Vector2i:
	var cab: Vector3 = esq["puntos"][PoseJugador.P_CABEZA]
	var pos: Vector2 = PoseJugador.proyectar(esq, cab, Vector3(R, R, R))["pos"]
	return Vector2i(int(floor(pos.x)), int(floor(pos.y)))


# ESTAMPA UN DIBUJO de pixeles con su esquina de arriba a la izquierda en (x0, y0). 'espejo' da la vuelta
# al dibujo; 'espejar_sitio' refleja la POSICION respecto al centro de la cabeza (cx), que es como las
# direcciones W y SW salen de E y SE. 'solo_iris': true pinta SOLO iris y pupila (la capa teñida).
# 'columnas' recorta a esas columnas del dibujo (vacio = todas).
#
# Cada pixel es una elipse de medio pixel de radio en el centro de su celda: SpriteLienzo.elipse la
# rellena exactamente a UNA celda. Y van con "sin_contorno" (ver la cabecera).
static func sello_en(piezas: Array, x0: int, y0: int, dibujo: Array, espejo: bool, solo_iris: bool,
		columnas: Array, cx: int, espejar_sitio: bool) -> void:
	var alto: int = dibujo.size()
	var ancho: int = String(dibujo[0]).length()
	for j in alto:
		var fila: String = dibujo[j]
		for i in ancho:
			var letra: String = fila[ancho - 1 - i] if espejo != espejar_sitio else fila[i]
			if not LETRAS.has(letra):
				continue
			if not columnas.is_empty() and not columnas.has(i):
				continue
			var tono: int = int(LETRAS[letra])
			if (tono in TONOS_IRIS) != solo_iris:
				continue
			var x: int = x0 + i
			if espejar_sitio:
				x = 2 * cx - 1 - x   # el eje es el borde entre la columna cx-1 y la cx
			piezas.append({
				"pos": Vector2(float(x) + 0.5, float(y0 + j) + 0.5), "radio": Vector2(0.5, 0.5),
				"persp": 1.0, "tono": tono, "ang": 0.0, "gira_forma": false, "solo_sobre": [],
				"sin_contorno": true,
			})
