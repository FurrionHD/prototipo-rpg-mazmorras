# ============================================================
#  pez_sprites.gd  (class_name PezSprites)
#  Los PECES que se ven nadando en el charco. Quinto generador por codigo, detras de los bichos
#  (SpritesEnemigo), el terreno (TerrenoSprites), lo recolectable (RecolectableSprites) y los
#  cacharros (PropSprites).
#
#  Antes cada pez era un ColorRect: un rectangulo alargado y oscuro, del mismo color para las cinco
#  especies, cuyo unico rasgo era el tamaño. Nadaban manchas.
#
#  ------------------------------------------------------------
#  VISTA CENITAL PURA, y es LA EXCEPCION del proyecto
#  ------------------------------------------------------------
#  Todo lo demas se dibuja con la camara a 45 grados (SpriteLienzo.CAMARA_GRADOS): se ve el lomo y
#  se le intuye la cara al bicho. Un pez NO, por dos razones y la primera basta:
#
#    1. EL SPRITE ROTA 360 GRADOS con el rumbo (fishing_spot._nadar hace rotation = vel.angle()).
#       Un dibujo con volumen de 45 grados tiene un arriba y un abajo -- lomo arriba, panza abajo --
#       y al girarlo media vuelta enseña la panza hacia arriba. Canta a la primera.
#    2. Se le mira literalmente desde arriba, a traves de la superficie del agua.
#
#  O sea: todas las elipses con persp = 1.0, ni una llamada a persp_de().
#
#  Y desde arriba se ve MENOS de lo que uno dibujaria de memoria. Se ve la silueta fusiforme, la
#  cabeza, los pectorales abiertos hacia atras, la cola, el lomo iluminado a lo largo del espinazo y
#  el contorno. NO se ve la panza, ni el perfil del vientre, ni la aleta anal, ni el ojo como forma
#  (son dos puntos, uno a cada lado), ni los dibujos del FLANCO. Y la aleta dorsal no es un
#  triangulo: desde arriba es una LINEA de uno o dos pixeles sobre la cresta.
#  La esbeltez de la especie se lee como ANCHURA, no como altura.
#
#  ------------------------------------------------------------
#  LA SILUETA ES PARAMETRICA, no cinco dibujos
#  ------------------------------------------------------------
#  El cuerpo se pinta POR COLUMNAS con un perfil de anchura, no con una elipse. Una elipse tiene su
#  punto mas ancho justo en la mitad y ningun pez lo tiene ahi: la anchura maxima cae sobre el
#  tercio delantero, y eso es la mitad de lo que hace que una silueta se lea como pez y no como
#  hoja. Con el perfil por tramos se elige donde esta.
#
#  `esbeltez` ya es un campo del .tres y ya gobernaba la forma; lo que va en RASGOS es lo que NO
#  cabe en un numero: los barbillones del bagre, la cola de lanceta de la anguila, el cuerpo de
#  plato del espejo abisal. Una especie nueva es una fila de datos, no un dibujo.
#
#  ------------------------------------------------------------
#  TALLAS DISCRETAS, NUNCA `scale`
#  ------------------------------------------------------------
#  Un sprite escalado rompe la rejilla de pixeles, que es lo que el proyecto entero evita (un bicho
#  mas grande se dibuja con MAS CELDAS, no con celdas mas gordas). Asi que el largo se redondea a un
#  escalon de PASO_TALLA px y se hornea un dibujo por escalon. `talla_de` es PURA y la llaman el
#  dueño y el espejo de red: misma talla en las dos maquinas sin que viaje nada.
#
#  Se pierde la variacion continua de tamaño (antes un pez de 41 cm y otro de 43 se veian distintos
#  por un pixel). A cambio, la diferencia entre tallas se lee MEJOR, porque ahora lo que crece es
#  una silueta y no la longitud de un rectangulo.
#
#  ------------------------------------------------------------
#  EL COLOR VA EN LA HOJA; EL AGUA LO APAGA CON MODULATE
#  ------------------------------------------------------------
#  Se hornea a TODO COLOR, una hoja por especie con la paleta derivada de su `color`. Bajo el agua
#  el charco le pone un modulate azulado (FishingSpot.TONO_SUMERGIDO): multiplicar conserva la
#  silueta entera -- contorno, cola, barbillones -- y a la vez lo vira al azul apagado, asi que
#  sigue leyendose "esta sumergido" pero ya tiene forma. El libro de pesca usa LA MISMA hoja sin
#  modulate. Un dibujo, tres lecturas.
#
#  NO se usa el patron CUERPO+TINTE de RecolectableSprites: alli existe porque la roca no se puede
#  teñir y solo la veta lleva el color del material. Un pez ES su color de arriba abajo, asi que la
#  capa neutra seria un pez gris y la de tinte otro pez entero: dos texturas para no ganar nada. Y
#  no hay presion de cache -- son CINCO colores fijos escritos en cinco .tres, no un randf por bicho.
# ============================================================

extends RefCounted
class_name PezSprites

const CARPETA := "res://assets/sprites/peces/"

# --- TALLAS ---
# 6 px por escalon: por debajo, dos tallas seguidas se diferencian en menos que el grosor del
# contorno y el escalon no compra nada.
const PASO_TALLA := 6.0
const TALLA_MIN := 2      # 12 px. Por debajo no hay sitio para cabeza, cola y aleta a la vez.
const TALLA_MAX := 10     # 60 px

# --- FRAMES DEL COLETEO ---
# Cuatro y solo la cola. El problema de la mancha no era solo la forma: era que se TRASLADABA
# rigida, y una silueta bonita deslizandose sigue pareciendo una calcomania. El cuerpo no cambia
# entre frames, asi que lo unico que se repinta es de la cintura para atras.
const FRAMES := 4
# Cuanto se va la cola de lado, en fraccion del semiancho del cuerpo. Mas de esto y el pez parece
# que se rompe por la mitad en vez de batir.
const COLETEO := 0.85
# Desde donde empieza a doblarse (0 = morro, 1 = punta de la cola). Un pez flexa por el tercio
# trasero; doblando desde la mitad se movia la cabeza y parecia un renacuajo.
const COLETEO_DESDE := 0.62

enum Tono {
	VACIO = 0,
	BORDE,          # la linea oscura del contorno: lo que lo hace legible bajo el velo del agua
	FLANCO,         # el costado, en penumbra
	CUERPO,
	LOMO,           # la franja del espinazo, lo unico que de verdad se ve desde arriba
	ALETA,          # pectorales, dorsal y cola: mas translucidas y mas palidas que el cuerpo
	OJO,
}

# Lo que no cabe en `esbeltez` ni en `color`. Una especie sin entrada se dibuja con POR_DEFECTO en
# vez de reventar: mas vale un pez generico en el agua que un crash al bajar al piso 13.
const RASGOS := {
	"gobio_palido":    {"cuerpo": "fusiforme", "cola": "horquilla", "dorsal": 1.0, "barbillones": 0},
	"lubina_mazmorra": {"cuerpo": "fusiforme", "cola": "horquilla", "dorsal": 1.4, "barbillones": 0},
	"bagre_legamo":    {"cuerpo": "cabezon",   "cola": "abanico",   "dorsal": 0.6, "barbillones": 4},
	"anguila_pozo":    {"cuerpo": "serpiente", "cola": "lanceta",   "dorsal": 0.3, "barbillones": 0},
	"espejo_abisal":   {"cuerpo": "disco",     "cola": "horquilla", "dorsal": 1.8, "barbillones": 0},
}
const POR_DEFECTO := {"cuerpo": "fusiforme", "cola": "horquilla", "dorsal": 1.0, "barbillones": 0}

# EL PERFIL DE ANCHURA, como puntos [u, factor] de morro (0) a nacimiento de la cola (1). El factor
# es fraccion del semiancho maximo. Aqui es donde vive la personalidad de cada silueta:
#
#   fusiforme  el huso de manual: cabeza estrecha, maximo sobre el 35%, se afina hacia el pedunculo.
#   cabezon    el bagre: la cabeza YA es lo mas ancho (maximo al 22%) y el cuerpo se cae en seguida.
#              Vista desde arriba, un bagre es una cabeza con un rabo.
#   serpiente  la anguila: practicamente constante. Lo que la hace anguila es que NO se afina.
#   disco      el espejo abisal: casi un circulo, entra y sale de golpe.
const PERFILES := {
	"fusiforme": [[0.00, 0.00], [0.08, 0.46], [0.20, 0.82], [0.35, 1.00], [0.55, 0.88],
		[0.75, 0.58], [0.90, 0.34], [1.00, 0.22]],
	"cabezon": [[0.00, 0.10], [0.06, 0.72], [0.14, 0.95], [0.22, 1.00], [0.34, 0.86],
		[0.55, 0.60], [0.78, 0.36], [1.00, 0.20]],
	"serpiente": [[0.00, 0.30], [0.06, 0.80], [0.14, 0.96], [0.35, 1.00], [0.65, 0.96],
		[0.85, 0.82], [1.00, 0.62]],
	"disco": [[0.00, 0.00], [0.05, 0.52], [0.14, 0.86], [0.30, 1.00], [0.52, 1.00],
		[0.72, 0.82], [0.88, 0.52], [1.00, 0.26]],
}

# Que fraccion del largo total se lleva la COLA (el resto es cuerpo). La lanceta de la anguila es
# larga y estrecha; el abanico del bagre, corto y redondo.
const COLA_LARGO := {"horquilla": 0.22, "abanico": 0.16, "lanceta": 0.26}


static func rasgos_de(id: String) -> Dictionary:
	return RASGOS.get(id, POR_DEFECTO)


# ============================================================
#  TALLAS
# ============================================================
# PURA a proposito: la llaman _nacer_pez (el dueño) y _nacer_pez_espejo (el invitado) con el mismo
# largo calculado igual, asi que sacan la misma talla sin que viaje un byte.
static func talla_de(largo_px: float) -> int:
	return clampi(int(round(largo_px / PASO_TALLA)), TALLA_MIN, TALLA_MAX)


static func largo_de(talla: int) -> int:
	return talla * int(PASO_TALLA)


# El lienzo de una talla. Cuadrado y no ajustado al pez: el sprite GIRA, y aunque Godot no recorte
# al rotar, un lienzo cuadrado deja el centro de giro donde tiene que estar (el centro del pez) sin
# tener que andar corrigiendo offsets por especie.
#
# EL 1.5 ES POR EL COLETEO, y sale de una cuenta, no de probar hasta que el validador callara. Lo
# que mas se aleja del eje es LA PUNTA DE LA COLA en el frame de coleteo maximo, y son tres cosas
# que se suman: el semiancho del pez, el desvio del coleteo y lo que la cola abre por su cuenta.
# Para el espejo abisal (esbeltez 1.7, el mas ancho) eso es 0.29 + 0.25 + 0.19 = 0.73 del largo por
# cada lado, o sea 1.46 de lado. Con el lienzo justo (largo + 2) se salia, y el validador de
# recortes lo canto en el bagre y en el espejo.
static func lienzo(talla: int) -> Vector2i:
	var l: int = int(float(largo_de(talla)) * 1.5) + 4
	return Vector2i(l, l)


# Las tallas que esta especie puede sacar de verdad, de sus centimetros. Solo se hornean esas: el
# gobio (7-14 cm) usa dos, y hornearle las diez seria hoja para nada.
static func tallas_de(d: MaterialData, px_por_cm: float, largo_min: float,
		largo_max: float) -> Array[int]:
	var t: Array[int] = []
	var a: int = talla_de(clampf(d.cm_min * px_por_cm, largo_min, largo_max))
	var b: int = talla_de(clampf(d.cm_max * px_por_cm, largo_min, largo_max))
	for i in range(mini(a, b), maxi(a, b) + 1):
		t.append(i)
	return t


# ============================================================
#  PALETA
# ============================================================
# Derivada del `color` del .tres, como hace RataSprites con el suyo. El pez no se ve plano desde
# arriba: el lomo coge la luz, los costados caen en penumbra y el contorno los cierra.
static func paleta(base: Color) -> PackedByteArray:
	var c: Color = SpriteLienzo.cuantizar_hsv(base, 8.0)
	return SpriteLienzo.paleta([
		Color(0, 0, 0, 0),
		c.darkened(0.72),                      # BORDE
		c.darkened(0.34),                      # FLANCO
		c,                                     # CUERPO
		c.lightened(0.30),                     # LOMO
		# Las aletas son de piel fina: mas palidas, algo desaturadas y translucidas. El alfa las
		# separa del cuerpo sin necesidad de un contorno propio, que a este tamaño las taparia.
		#
		# POCO mas palidas. Con el primer valor (un 35% hacia el blanco azulado) las aletas ganaban
		# al cuerpo y el bagre -- que tiene la cola mas grande de las cinco -- se leia como un pez
		# gris claro en vez de como el bicho pardo de fondo que es. Una aleta es de su mismo color,
		# solo que fina y translucida.
		c.lightened(0.10).lerp(Color(0.80, 0.86, 0.90), 0.18) * Color(1, 1, 1, 0.80),
		Color(0.06, 0.05, 0.07),               # OJO
	])


# ============================================================
#  EL DIBUJO
# ============================================================
# El pez se dibuja apuntando a la DERECHA (+x), porque el angulo 0 de Godot es +x y el charco le
# pone al sprite `rotation = vel.angle()` tal cual.
static func _plantilla(d: MaterialData, talla: int, frame: int) -> PackedByteArray:
	var t: Vector2i = lienzo(talla)
	var plant := PackedByteArray()
	plant.resize(t.x * t.y)
	var r: Dictionary = rasgos_de(d.id)

	var largo: float = float(largo_de(talla))
	# La ESBELTEZ es largo/ancho, o sea que el ancho sale de dividir. El tope de 1.2 es el que ya
	# tenia fishing_spot: por debajo el pez seria mas ancho que largo.
	var ancho: float = largo / maxf(1.2, d.esbeltez)
	var semi: float = maxf(1.0, ancho * 0.5)
	var cola_frac: float = float(COLA_LARGO.get(String(r["cola"]), 0.22))
	var cuerpo_largo: float = largo * (1.0 - cola_frac)
	# El morro. CENTRADO en el lienzo, que ahora es mas ancho que el pez para dejarle sitio al
	# coleteo: pegado al borde izquierdo, el centro de giro del sprite no seria el centro del pez y
	# al rotar describiria un arco en vez de girar sobre si mismo.
	var x0: float = (float(t.x) - largo) * 0.5
	var eje: float = float(t.y) * 0.5                    # el espinazo, en y

	# DEGRADADO POR TAMAÑO. Por debajo de cierto tamaño no hay sitio y hay que dejar de dibujar
	# cosas, no dibujarlas mas pequeñas: un pectoral de medio pixel no es un pectoral pequeño, es
	# una mota de ruido pegada al costado. Y con la anguila (esbeltez 7) el que se queda sin sitio
	# es el ANCHO, no el largo, asi que las dos condiciones son distintas.
	var hay_aletas: bool = semi >= 2.5 and largo >= 16.0
	var hay_ojos: bool = largo >= 14.0
	var hay_dorsal: bool = largo >= 12.0

	# El coleteo: de COLETEO_DESDE en adelante, el eje se va de lado siguiendo una onda.
	var fase: float = TAU * float(frame) / float(FRAMES)

	var perfil: Array = PERFILES.get(String(r["cuerpo"]), PERFILES["fusiforme"])

	# --- CUERPO, columna a columna ---
	for ix in range(int(x0), int(x0 + cuerpo_largo) + 1):
		var u: float = clampf((float(ix) - x0) / maxf(1.0, cuerpo_largo), 0.0, 1.0)
		var h: float = SpriteLienzo.tramos(u, perfil) * semi
		# El umbral estaba en 0.5 y ABRIA UN HUECO ENTRE EL CUERPO Y LA COLA en los peces chicos: el
		# perfil fusiforme acaba en 0.22 del semiancho, y en un gobio (semi 2.3) eso son 0.5 justos,
		# asi que la ultima columna del cuerpo no se pintaba y la cola quedaba suelta. Lo cazo el
		# validador de trozos sueltos. Donde el perfil dice que hay pez, hay al menos un pixel.
		if h < 0.15:
			continue
		var cy: float = eje + _desvio(u, fase, semi)
		_columna(plant, t, ix, cy, maxf(h, 0.5))

	# --- COLA ---
	# ARRANCA DENTRO DEL CUERPO, no a continuacion. Al final del cuerpo el perfil deja una columna de
	# un pixel de alto, y ahi el coleteo mueve el eje mas de lo que ese pixel mide: la cola se
	# despegaba y el pez salia en dos trozos (lo canto el validador en el gobio, que es el mas
	# pequeño y por tanto donde un pixel es proporcionalmente mas). Metiendola un poco, cuerpo y cola
	# comparten columnas y no pueden separarse por mucho que batan.
	var solape: float = maxf(1.0, semi * 0.6)
	_cola(plant, t, String(r["cola"]), x0 + cuerpo_largo - solape,
		eje + _desvio(1.0 - solape / maxf(1.0, cuerpo_largo), fase, semi),
		largo * cola_frac + solape, semi, fase)

	# --- ALETAS ---
	if hay_aletas:
		# PECTORALES al 30% y abiertos hacia atras; PELVICAS al 55% y mas cortas. Desde arriba son
		# dos parejas de alerones asimetricos respecto al eje, y son lo que impide que la silueta se
		# lea como una hoja.
		# PEQUEÑAS y pegadas al cuerpo. Con las aletas grandes (1.3 y 0.85 del semiancho) el bagre
		# salia con dos pares de palas asomando a los lados y se leia como un ESQUELETO de pez, con
		# las aletas haciendo de costillas. Una aleta pectoral vista desde arriba asoma poco: es un
		# remo corto pegado al costado, no un ala.
		_par_aletas(plant, t, x0 + cuerpo_largo * 0.30, eje, semi, semi * 0.80, 0.70)
		_par_aletas(plant, t, x0 + cuerpo_largo * 0.60, eje, semi, semi * 0.52, 0.55)
	if hay_dorsal:
		# LA DORSAL ES UNA LINEA. Desde arriba se ve el CANTO de la aleta, no su cara: dibujarla
		# como un triangulo la convertiria en un ala.
		var d_alto: float = float(r["dorsal"])
		var desde: float = x0 + cuerpo_largo * 0.30
		var hasta: float = x0 + cuerpo_largo * (0.92 if String(r["cuerpo"]) == "serpiente" else 0.72)
		for ix in range(int(desde), int(hasta) + 1):
			var u: float = clampf((float(ix) - x0) / maxf(1.0, cuerpo_largo), 0.0, 1.0)
			var cy: float = eje + _desvio(u, fase, semi)
			var g: int = maxi(1, int(round(d_alto)))
			for k in g:
				_poner(plant, t, ix, int(round(cy - float(g) * 0.5 + float(k))), Tono.ALETA,
					[Tono.CUERPO, Tono.LOMO, Tono.FLANCO])

	# --- LOMO: la franja iluminada del espinazo. Solo SOBRE el cuerpo, para que no se derrame ---
	for ix in range(int(x0), int(x0 + cuerpo_largo) + 1):
		var u: float = clampf((float(ix) - x0) / maxf(1.0, cuerpo_largo), 0.0, 1.0)
		var h: float = SpriteLienzo.tramos(u, perfil) * semi
		if h < 1.2:
			continue
		var cy: float = eje + _desvio(u, fase, semi)
		# Mas brillante y mas ancho en el tercio delantero: es donde el lomo es mas alto, o sea
		# donde mas luz recoge.
		var g: float = maxf(1.0, h * lerpf(0.62, 0.30, u))
		for iy in range(int(round(cy - g * 0.5)), int(round(cy + g * 0.5)) + 1):
			_poner(plant, t, ix, iy, Tono.LOMO, [Tono.CUERPO])

	# --- BARBILLONES: EL rasgo del bagre, y desde arriba casi lo unico que se le ve ---
	if int(r["barbillones"]) > 0 and largo >= 20.0:
		_barbillones(plant, t, x0, eje + _desvio(0.0, fase, semi), semi,
			int(r["barbillones"]), largo)

	# EL CONTORNO, sobre la silueta YA FUSIONADA y no pieza a pieza (regla de SpriteLienzo): pieza a
	# pieza saldrian lineas negras por dentro del pez, en las juntas del cuerpo con cada aleta.
	SpriteLienzo.contornear(plant, Rect2i(0, 0, t.x, t.y), t.x, t.y, Tono.BORDE, Tono.VACIO,
		Tono.VACIO)

	# LOS OJOS VAN DESPUES DEL CONTORNO. Si van antes se los come: a esta escala son un pixel, y el
	# contornear los toma por borde de la cabeza.
	if hay_ojos:
		var ox: float = x0 + cuerpo_largo * 0.11
		var oy: float = eje + _desvio(0.09, fase, semi)
		var sep: float = maxf(1.0, SpriteLienzo.tramos(0.11, perfil) * semi * 0.62)
		_poner(plant, t, int(round(ox)), int(round(oy - sep)), Tono.OJO, [])
		_poner(plant, t, int(round(ox)), int(round(oy + sep)), Tono.OJO, [])
	return plant


# El desvio lateral del eje en `u` para este frame del coleteo. Cero de la cabeza hasta
# COLETEO_DESDE y luego crece al cuadrado: asi la cabeza no se mueve y la cola manda, que es como
# nada un pez. Lineal desde el mismo sitio salia un meneo de serpiente.
static func _desvio(u: float, fase: float, semi: float) -> float:
	if u <= COLETEO_DESDE:
		return 0.0
	var k: float = (u - COLETEO_DESDE) / (1.0 - COLETEO_DESDE)
	return sin(fase) * k * k * semi * COLETEO


# Una columna del cuerpo: el centro en CUERPO y las dos bandas de fuera en FLANCO. Es lo que da
# volumen sin sombrear pixel a pixel -- desde arriba, un pez es un tubo, y un tubo tiene el lomo
# claro y los costados en penumbra.
static func _columna(plant: PackedByteArray, t: Vector2i, ix: int, cy: float, h: float) -> void:
	var y0: int = int(round(cy - h))
	var y1: int = int(round(cy + h))
	for iy in range(y0, y1 + 1):
		var d: float = absf(float(iy) + 0.5 - cy) / maxf(0.5, h)
		_poner(plant, t, ix, iy, Tono.FLANCO if d > 0.62 else Tono.CUERPO, [])


static func _cola(plant: PackedByteArray, t: Vector2i, tipo: String, x: float, cy: float,
		largo: float, semi: float, fase: float) -> void:
	if largo < 1.0:
		return
	# La cola sigue al cuerpo y ademas se abre MAS que el: es la punta del latigo.
	var extra: float = sin(fase) * semi * COLETEO * 0.55
	for k in range(0, int(largo) + 1):
		var u: float = float(k) / maxf(1.0, largo)
		var yc: float = cy + extra * u
		var h: float = 0.0
		match tipo:
			# HORQUILLA: se estrecha en el pedunculo y se abre en dos lobulos. El estrechamiento es
			# lo que la lee como cola y no como continuacion del cuerpo.
			"horquilla":
				h = semi * lerpf(0.30, 1.15, u * u)
			# ABANICO: redonda y corta, sin escotadura.
			"abanico":
				h = semi * lerpf(0.34, 0.95, sqrt(u))
			# LANCETA: la de la anguila. Una sola punta, se afila hasta desaparecer.
			"lanceta":
				h = semi * lerpf(0.62, 0.10, u)
		if h < 0.5:
			continue
		var y0: int = int(round(yc - h))
		var y1: int = int(round(yc + h))
		for iy in range(y0, y1 + 1):
			# LA ESCOTADURA de la horquilla: el centro de la cola se vacia hacia la punta, y eso es
			# lo que la parte en dos lobulos. Sin ella sale una paleta.
			if tipo == "horquilla" and u > 0.45:
				var hueco: float = h * (u - 0.45) / 0.55 * 0.85
				if absf(float(iy) + 0.5 - yc) < hueco:
					continue
			_poner(plant, t, int(round(x)) + k, iy, Tono.ALETA, [])


# Un par de aletas, una a cada lado, ABIERTAS HACIA ATRAS: un pez nada con los pectorales echados
# hacia la cola, y puestas perpendiculares parecian alas de avion.
#
# Como ELIPSE GIRADA y no como una fila de pixeles avanzando en diagonal. El primer intento era lo
# segundo y salian ARAÑAZOS: hilos de un pixel que a este tamaño no se leen como aleta sino como
# suciedad en el sprite. Una aleta tiene cuerpo, aunque sea de tres pixeles de ancho.
static func _par_aletas(plant: PackedByteArray, t: Vector2i, x: float, eje: float, semi: float,
		largo: float, abre: float) -> void:
	for lado in [-1.0, 1.0]:
		# El centro de la aleta, a medio camino entre el costado y su punta.
		var ang: float = lado * abre
		var cx: float = x + cos(ang) * largo * 0.5
		var cy: float = eje + lado * semi * 0.55 + sin(ang) * largo * 0.5
		SpriteLienzo.elipse(plant, t.x, t.y, cx, cy, maxf(1.2, largo * 0.5),
			maxf(0.9, largo * 0.26), Tono.ALETA, ang)


# Los bigotes del bagre: salen del morro y se curvan hacia atras. Van en BORDE y no en ALETA porque
# son hilos de un pixel y con el tono palido de las aletas se perdian contra el agua.
#
# CUIDADO: un barbillon separado del cuerpo lo caza _avisar_islas del horno como trozo suelto. Por
# eso arrancan PEGADOS al morro (k desde 0) y no a un pixel de distancia.
static func _barbillones(plant: PackedByteArray, t: Vector2i, x: float, cy: float, semi: float,
		n: int, largo: float) -> void:
	var l: float = largo * 0.20
	for i in n:
		# Repartidos a los dos lados, mas abiertos los de fuera.
		var lado: float = -1.0 if i % 2 == 0 else 1.0
		var fila: int = i / 2
		var abre: float = 0.35 + 0.45 * float(fila)
		for k in range(0, int(l) + 1):
			var u: float = float(k) / maxf(1.0, l)
			var bx: float = x + u * l * 0.55
			var by: float = cy + lado * (semi * 0.25 + u * l * abre)
			_poner(plant, t, int(round(bx)), int(round(by)), Tono.BORDE, [])


# Pone un pixel si cae dentro y si lo de debajo esta en `solo_sobre` (vacio = siempre).
static func _poner(plant: PackedByteArray, t: Vector2i, x: int, y: int, tono: int,
		solo_sobre: Array) -> void:
	if x < 0 or y < 0 or x >= t.x or y >= t.y:
		return
	var i: int = y * t.x + x
	if not solo_sobre.is_empty() and not solo_sobre.has(plant[i]):
		return
	plant[i] = tono


# ============================================================
#  HOJA, HORNEADO Y CONSULTA
# ============================================================
# Una hoja por especie: rejilla de [talla] filas x [frame] columnas, con la celda del tamaño de la
# talla mayor. Se desperdicia algo de alfa en las filas de arriba y da igual: son hojas de unos
# pocos KB y a cambio la cuenta de la region es una multiplicacion.
static func hoja(d: MaterialData, px_por_cm: float, largo_min: float, largo_max: float) -> Image:
	var tallas: Array[int] = tallas_de(d, px_por_cm, largo_min, largo_max)
	var celda: Vector2i = lienzo(tallas.back())
	var img := Image.create(celda.x * FRAMES, celda.y * tallas.size(), false, Image.FORMAT_RGBA8)
	var pal: PackedByteArray = paleta(d.color)
	for fila in tallas.size():
		var talla: int = tallas[fila]
		var t: Vector2i = lienzo(talla)
		for f in FRAMES:
			var tex: ImageTexture = SpriteLienzo.a_textura(_plantilla(d, talla, f), pal, t.x, t.y)
			# Centrada en su celda: asi el centro del pez es el centro de la region pase lo que
			# pase con la talla, que es lo que necesita el giro.
			img.blend_rect(tex.get_image(), Rect2i(Vector2i.ZERO, t),
				Vector2i(f * celda.x + (celda.x - t.x) / 2,
					fila * celda.y + (celda.y - t.y) / 2))
	return img


static func fila_de(d: MaterialData, talla: int, px_por_cm: float, largo_min: float,
		largo_max: float) -> int:
	var tallas: Array[int] = tallas_de(d, px_por_cm, largo_min, largo_max)
	return clampi(tallas.find(talla) if tallas.has(talla) else tallas.size() - 1,
		0, tallas.size() - 1)


static func ruta(id: String) -> String:
	return CARPETA + "pez_" + id + ".png"


static func hornear(d: MaterialData, px_por_cm: float, largo_min: float, largo_max: float) -> int:
	DirAccess.make_dir_recursive_absolute(CARPETA)
	var png: String = ruta(d.id)
	if hoja(d, px_por_cm, largo_min, largo_max).save_png(
			ProjectSettings.globalize_path(png)) != OK:
		return 0
	var f := FileAccess.open(png, FileAccess.READ)
	var n: int = f.get_length() if f != null else 0
	if f != null:
		f.close()
	return n


static var _cache: Dictionary = {}

# La hoja de una especie. Si el horneado no esta en disco se genera al vuelo, como hacen los demas
# generadores: olvidarse de hornear no puede dejar peces invisibles en la partida de nadie.
static func textura(d: MaterialData, px_por_cm: float, largo_min: float,
		largo_max: float) -> Texture2D:
	if _cache.has(d.id):
		return _cache[d.id]
	var tex: Texture2D = null
	var png: String = ruta(d.id)
	if ResourceLoader.exists(png):
		tex = load(png) as Texture2D
	if tex == null:
		tex = ImageTexture.create_from_image(hoja(d, px_por_cm, largo_min, largo_max))
	_cache[d.id] = tex
	return tex
