# ============================================================
#  terreno_sprites.gd  (class_name TerrenoSprites)
#  Las BALDOSAS del mapa, dibujadas por codigo. Hermano de SpritesEnemigo: aquel decide quien
#  dibuja a cada bicho, este dibuja el suelo, las paredes y lo que crece encima.
#
#  POR QUE NO REUSA SpriteLienzo.montar_frames. El motor de los bichos empaqueta por ESTANTES
#  (cada frame recortado a su caja real) porque alli el 70% de cada frame es aire. Una baldosa es
#  un cuadrado de 32x32 y ademas tiene que entrar en un TileSetAtlasSource, que exige rejilla
#  REGULAR. Asi que aqui el atlas es una rejilla. Lo que si se comparte es la idea: dibujar por
#  codigo, hornear a PNG y cargar el PNG en el juego.
#
#  POR QUE UN TileMapLayer Y NO Sprite2D CON texture_repeat. Un AtlasTexture no se puede repetir
#  (texture_repeat repetiria el atlas ENTERO, no la region), y ademas hace falta variante POR
#  CELDA para que una pared larga no se lea como un patron. El TileMapLayer hace las dos cosas,
#  batchea el dibujado el solo y ademas sabe animar baldosas de serie.
#
# ------------------------------------------------------------
#  EL CONCEPTO: CAPAS, NO CASOS SUELTOS
# ------------------------------------------------------------
#  Aqui no hay "la funcion del musgo" y "la funcion del agua". Hay CAPAS, y una capa es una receta
#  con cuatro datos: de que CLASE es, cuantos FRAMES tiene, si es SUPERPOSICION y con que paleta
#  se pinta. Con eso, meter un riachuelo, una veta de musgo, ceniza, hielo o setas es añadir una
#  entrada a CAPAS y su pintor -- no tocar el mapa ni el TileSet ni el horno.
#
#  Dos clases de capa:
#    BASE     -> N variantes sueltas, sin bordes. Es el relleno (el suelo de roca).
#    MASCARA  -> las 16 combinaciones de "por que lados NO soy yo mismo" (1 N, 2 E, 4 S, 8 O).
#                Es el AUTOTILE: sirve igual para la pared (donde el borde es la cara vista) que
#                para una mancha de musgo o un riachuelo (donde el borde es la orilla).
#
#  COMO CONECTAN CON TODO LO DEMAS. Una capa de superposicion se pinta en SU PROPIO TileMapLayer,
#  por encima del suelo, y sus baldosas de borde se desvanecen a alfa. Por eso el musgo casa con
#  cualquier suelo que le pongas debajo y el riachuelo puede desembocar en el estanque sin que
#  nadie tenga que dibujar la pieza "riachuelo-que-toca-lago": la orilla es transparente y lo de
#  abajo se ve. Conectan consigo mismas por el autotile y con el resto por el alfa.
#
#  ANIMACION. 'frames' > 1 reserva ese numero de celdas CONTIGUAS en el atlas por baldosa y
#  Godot las pasa solo (set_tile_animation_frames_count). El agua corre de verdad, no es un
#  degradado quieto.
#
#  SE HORNEA con herramientas/hornear_sprites.bat, igual que los bichos. Si el horneado no esta, se dibuja al
#  vuelo: son unas pocas decenas de baldosas y cuesta milisegundos, asi que tocar los colores no
#  rompe el desarrollo.
# ============================================================

extends RefCounted
class_name TerrenoSprites

const CARPETA := "res://assets/sprites/terreno/"

# El lado de la baldosa es EL de la rejilla del mapa. No es negociable: si no coinciden, el
# TileMapLayer estira y se pierde el pixel-art.
const LADO := 32

# Ancho del atlas en celdas. Tiene que ser multiplo del mayor 'frames' de CAPAS para que los
# frames de una baldosa animada quepan seguidos en la misma fila.
const COLS := 8

enum Clase { BASE, MASCARA }


# ============================================================
#  LAS CAPAS
# ============================================================
# El orden de CAPAS_ORDEN fija el reparto del atlas. Añadir una capa AL FINAL no mueve a las de
# arriba, o sea que un horneado viejo de otra capa sigue valiendo mientras se desarrolla.
const CAPAS_ORDEN := ["suelo", "muro", "musgo", "agua", "sumidero"]

# ------------------------------------------------------------
#  'bloque': POR QUE LA TEXTURA NO SE VE A CUADROS
# ------------------------------------------------------------
# El primer intento fue "varias variantes por mascara, elegidas por hash de la celda". No basta, y
# el motivo es de fondo: el ruido de una baldosa es PERIODICO DENTRO DE ELLA (tiene que serlo,
# para que su borde derecho case con su propio borde izquierdo). Eso hace que dos baldosas
# IGUALES casen perfectamente... y que dos DISTINTAS no casen en absoluto. Con variantes al azar,
# casi todas las juntas son entre baldosas distintas, asi que el dibujo se corta en seco cada 32
# px y sale una rejilla marcada -- justo lo que las variantes venian a evitar.
#
# La solucion es dejar de pensar en baldosas sueltas y pensar en un TAPIZ: se dibuja una textura
# continua de 'bloque' x 'bloque' baldosas (4x4 = 128 px), periodica en ese tamaño, y se trocea.
# Cada trozo va SIEMPRE en la misma posicion del tapiz -- la celda (x,y) usa el trozo
# (x mod 4, y mod 4) -- asi que las juntas son las que ya tenia el tapiz por dentro: ninguna.
# Y de propina la repeticion pasa de notarse cada 32 px a cada 128, que ya no se ve.
#
# Consecuencia: 'variantes' NO se elige, sale de bloque² (16 trozos por mascara). Y la variante
# deja de ser aleatoria: es la POSICION en el tapiz. Sigue siendo estable y sigue saliendo igual
# en la maquina del invitado, ahora sin depender ni del hash.
const CAPAS := {
	# El relleno pisable. Sin bordes: lo que dibuja la silueta de una sala es el MURO.
	"suelo": {"clase": Clase.BASE, "bloque": 4, "frames": 1, "overlay": false},
	# La roca. Su 'mascara' no es una orilla: es por donde el bloque esta EXPUESTO al suelo, y de
	# ahi salen la cara vista y el filo de la coronacion.
	"muro": {"clase": Clase.MASCARA, "bloque": 4, "frames": 1, "overlay": false},
	# Superposiciones. Se pintan encima y sus bordes mueren en alfa.
	"musgo": {"clase": Clase.MASCARA, "bloque": 4, "frames": 1, "overlay": true},
	# El agua va a bloque 2 y no 4: son CUATRO frames por baldosa, asi que subirla a 16 trozos
	# multiplicaria el atlas por cuatro. Y se le nota menos: la corriente ya esta moviendose.
	"agua": {"clase": Clase.MASCARA, "bloque": 2, "frames": 4, "overlay": true},
	# EL DESAGUE. Existe por una regla de diseño: el agua NUNCA puede terminar en seco. Un
	# riachuelo sale de una pared y tiene que acabar en el lago, meterse en otra pared o colarse
	# por un sumidero. Sin esta pieza, la tercera salida no existe y el trazado se queda sin
	# manera de cerrar el recorrido cuando no hay lago cerca. Ver dungeon_floor._trazar_agua.
	#
	# Bloque 1: es una pieza SUELTA (hay uno por piso como mucho), no un tapiz. No tiene vecinos
	# con los que casar, asi que no necesita el tratamiento de los demas.
	"sumidero": {"clase": Clase.BASE, "bloque": 1, "frames": 1, "overlay": true},
}


static func es_overlay(capa: String) -> bool:
	return bool((CAPAS[capa] as Dictionary)["overlay"])


static func frames_de(capa: String) -> int:
	return int((CAPAS[capa] as Dictionary)["frames"])


static func bloque_de(capa: String) -> int:
	return int((CAPAS[capa] as Dictionary)["bloque"])


# Trozos del tapiz. NO se elige: es bloque al cuadrado (ver la nota de 'bloque' arriba).
static func variantes_de(capa: String) -> int:
	var b: int = bloque_de(capa)
	return b * b


# Cuantas baldosas distintas tiene la capa en total.
static func _cuantas(capa: String) -> int:
	var v: int = variantes_de(capa)
	return v if int((CAPAS[capa] as Dictionary)["clase"]) == Clase.BASE else 16 * v


# ============================================================
#  TRAMOS DE PISOS
# ============================================================
# Cada tramo de la mazmorra tiene su propio juego de baldosas, y el corte cae donde cambia lo que
# te encuentras: los pisos 1-6 son la mazmorra de piedra de siempre y del 7 en adelante es una
# CUEVA VIVA -- gruta humeda y fria, donde ya viven los insectos.
#
# Los tramos de mas abajo caen en el ultimo hasta que se dibujen, asi que el juego se ve entero
# desde el primer dia y meter el siguiente es añadir una entrada aqui con su paleta.
const TRAMOS := [
	{"desde": 1, "clave": "roca"},
	{"desde": 7, "clave": "cueva"},
]


static func tramo_de(piso: int) -> String:
	var clave: String = TRAMOS[0]["clave"]
	for t in TRAMOS:
		if piso >= int(t["desde"]):
			clave = String(t["clave"])
	return clave


# ============================================================
#  PALETAS
# ============================================================
# Una rampa de 5 tonos por capa, ordenada de oscuro a claro. Que sean escalones y no un degradado
# continuo es lo que hace que se lea como pixel-art: el ruido elige ESCALON, no color, igual que
# los bichos eligen tono y no RGB (ver SpriteLienzo).
const PALETAS := {
	"roca": {
		"suelo": [
			Color(0.085, 0.080, 0.100), Color(0.115, 0.110, 0.135),
			Color(0.145, 0.140, 0.170), Color(0.175, 0.168, 0.205),
			Color(0.205, 0.196, 0.240),
		],
		"muro": [
			Color(0.150, 0.145, 0.180), Color(0.225, 0.215, 0.265),
			Color(0.300, 0.288, 0.350), Color(0.370, 0.352, 0.430),
			Color(0.445, 0.425, 0.515),
		],
		"musgo": [
			Color(0.090, 0.170, 0.110), Color(0.120, 0.225, 0.135),
			Color(0.160, 0.290, 0.165), Color(0.205, 0.355, 0.195),
			Color(0.260, 0.430, 0.230),
		],
		"agua": [
			Color(0.055, 0.115, 0.190), Color(0.075, 0.165, 0.265),
			Color(0.100, 0.225, 0.340), Color(0.145, 0.300, 0.420),
			Color(0.230, 0.420, 0.530),
		],
	},
	# CUEVA VIVA (pisos 7+). La de arriba es una mazmorra de piedra picada, gris y seca; esta es
	# roca natural, humeda y FRIA. Tres decisiones deliberadas:
	#
	#  - Todo vira al AZUL VERDOSO. No es un filtro encima: la rampa entera esta corrida hacia el
	#    cian, asi que el escalon mas claro de un muro de cueva sigue siendo mas frio que el mas
	#    oscuro de uno de roca. Es lo que hace que al cruzar la frontera del piso 7 se note que has
	#    cambiado de sitio y no de iluminacion.
	#  - El SUELO es aun mas oscuro que arriba, por lo mismo que ya lo era alli (ver _pintar_suelo):
	#    es el fondo sobre el que destaca todo lo demas, y esto se juega a oscuras.
	#  - El MURO abre mas su rampa (del 0.09 al 0.52 frente al 0.15-0.44 de la roca). Una cueva es
	#    irregular: con el recorrido corto salia una pared plana, y lo que la hace parecer roca
	#    natural es que haya sombras hondas y cantos claros en la misma pared.
	"cueva": {
		"suelo": [
			Color(0.048, 0.066, 0.088), Color(0.068, 0.094, 0.122),
			Color(0.092, 0.126, 0.160), Color(0.118, 0.158, 0.198),
			Color(0.148, 0.194, 0.238),
		],
		"muro": [
			Color(0.088, 0.122, 0.156), Color(0.140, 0.186, 0.230),
			Color(0.200, 0.256, 0.310), Color(0.264, 0.328, 0.390),
			Color(0.336, 0.408, 0.476),
		],
		# El musgo de aqui abajo tira a turquesa, no al verde hierba de arriba: prepara el ojo para
		# el musgo que brilla, que es de esta misma familia de color.
		#
		# Y va MAS CLARO Y MAS SATURADO que el de la roca, aunque parezca al reves de lo que pide
		# una cueva mas oscura. El motivo salio de mirarlo: sobre la pared GRIS de arriba, un verde
		# apagado destaca solo; sobre la pared AZUL de aqui, un turquesa apagado comparte tono con
		# ella y el musgo desaparecia -- se veia una mancha algo mas oscura y ya. El contraste que
		# alli daba el color, aqui hay que darlo con el brillo.
		"musgo": [
			Color(0.075, 0.190, 0.170), Color(0.110, 0.270, 0.235),
			Color(0.155, 0.360, 0.305), Color(0.205, 0.450, 0.375),
			Color(0.270, 0.560, 0.455),
		],
		# El agua, mas clara y mas viva que arriba: en una gruta es lo unico que refleja algo.
		"agua": [
			Color(0.042, 0.102, 0.148), Color(0.058, 0.145, 0.205),
			Color(0.080, 0.196, 0.268), Color(0.115, 0.258, 0.342),
			Color(0.180, 0.360, 0.455),
		],
	},
}


static func _rampa(tramo: String, capa: String) -> Array:
	var p: Dictionary = PALETAS.get(tramo, PALETAS["roca"])
	return p.get(capa, p["suelo"]) as Array


# ============================================================
#  REPARTO DEL ATLAS
# ============================================================
# Cada baldosa ocupa 'frames' celdas SEGUIDAS de una fila (Godot pone los frames de una animacion
# a partir de la celda de la baldosa, hacia la derecha). Cuando no caben en lo que queda de fila,
# se salta a la siguiente. El reparto es funcion PURA de la tabla CAPAS, asi que el que dibuja y
# el que consulta llegan al mismo sitio sin ponerse de acuerdo.
static var _plano_cache: Dictionary = {}

static func _plano() -> Dictionary:
	if not _plano_cache.is_empty():
		return _plano_cache
	var celdas: Dictionary = {}
	var col: int = 0
	var fila: int = 0
	for capa in CAPAS_ORDEN:
		var f: int = frames_de(capa)
		var propias: Dictionary = {}
		for i in _cuantas(capa):
			if col + f > COLS:
				col = 0
				fila += 1
			propias[i] = Vector2i(col, fila)
			col += f
		celdas[capa] = propias
		# Cada capa empieza en fila nueva: asi añadir una variante no descoloca a las de abajo.
		col = 0
		fila += 1
	_plano_cache = {"filas": fila, "celdas": celdas}
	return _plano_cache


# INDICE de una baldosa dentro de su capa. En una capa BASE es la variante a secas; en una de
# MASCARA las variantes van seguidas dentro de cada mascara (mascara 0 v0, mascara 0 v1, ...), que
# es lo que deja añadir una variante mas sin recolocar las mascaras.
static func indice(capa: String, mask: int, variante: int) -> int:
	var v: int = variantes_de(capa)
	if int((CAPAS[capa] as Dictionary)["clase"]) == Clase.BASE:
		return posmod(variante, v)
	return posmod(mask, 16) * v + posmod(variante, v)


# La celda del atlas. 'i' es el indice que devuelve indice().
static func celda_de(capa: String, i: int) -> Vector2i:
	return (_plano()["celdas"][capa] as Dictionary)[posmod(i, _cuantas(capa))]


# La celda del atlas que le toca a una posicion del mapa.
#
# El trozo del tapiz sale de la POSICION, no de un hash y desde luego no de un randf(): la celda
# (x,y) usa siempre el trozo (x mod bloque, y mod bloque), que es LO QUE HACE QUE NO SE VEAN LAS
# JUNTAS -- dos celdas vecinas reciben trozos vecinos del mismo dibujo continuo. De propina sale
# gratis lo de siempre: es estable entre reconstrucciones del piso y el invitado ve lo mismo que
# el host sin que viaje nada por la red. La 'semilla' ya no hace falta para elegir (el tapiz es el
# que es), pero se conserva en la firma porque el dia que haya varios tapices por tramo hara falta.
static func celda_para(capa: String, celda: Vector2i, mask: int, _semilla: int = 0) -> Vector2i:
	var b: int = bloque_de(capa)
	var v: int = posmod(celda.y, b) * b + posmod(celda.x, b)
	return celda_de(capa, indice(capa, mask, v))



# ============================================================
#  RUIDO: POR CAMPOS, NO POR PIXEL
# ============================================================
# Ruido de valor con la RETICULA PERIODICA dentro de la baldosa. El periodo es lo que hace que las
# baldosas casen entre si: sin el, el borde derecho de una no tiene nada que ver con el borde
# izquierdo de la siguiente y sale una cuadricula marcada a fuego.
#
# POR QUE UN CAMPO ENTERO Y NO UNA FUNCION POR PIXEL. La primera version era ruido(x, y): cada
# pixel calculaba sus cuatro esquinas de reticula con un hash cada una, y cada pixel pide tres
# octavas. Son doce hashes por pixel, 1024 pixeles por baldosa y un par de cientos de baldosas: el
# horno no terminaba ni en cinco minutos.
#
# La reticula de una octava solo tiene 'per x per' valores distintos (16 para la octava gorda, 256
# para la fina) y se repiten para los 1024 pixeles. Asi que se calcula la TABLA una vez y luego el
# campo entero se interpola leyendo de ella. De doce hashes por pixel se pasa a ninguno.
# La tabla de la reticula, CACHEADA. Los 16 trozos de un tapiz comparten exactamente la misma
# reticula (son ventanas distintas del mismo dibujo), asi que calcularla una vez por trozo seria
# hacer el mismo trabajo dieciseis veces.
static var _tablas: Dictionary = {}

static func _tabla(lado: int, semilla: int) -> PackedFloat32Array:
	var clave: int = lado * 1000003 + semilla
	if _tablas.has(clave):
		return _tablas[clave]
	var t := PackedFloat32Array()
	t.resize(lado * lado)
	for j in lado:
		for i in lado:
			var n: int = i * 374761393 + j * 668265263 + semilla * 1013904223
			n = (n ^ (n >> 13)) * 1274126177
			t[j * lado + i] = float((n ^ (n >> 16)) & 0xFFFF) / 65535.0
	_tablas[clave] = t
	return t


# Un campo de ruido del tamaño de UNA baldosa, recortado del tapiz.
#   'per'    = nodos de reticula por baldosa (2 = manchas gordas, 16 = grano fino)
#   'bloque' = tamaño del tapiz en baldosas. La reticula se hace periodica en per*bloque, que es
#              lo que hace que el tapiz entero case consigo mismo y no cada baldosa por su cuenta.
#   'ox/oy'  = donde cae esta baldosa DENTRO del tapiz, en px.
static func _campo(per: int, semilla: int, ox: float = 0.0, oy: float = 0.0,
		sx: float = 1.0, bloque: int = 1) -> PackedFloat32Array:
	var lado: int = per * bloque
	var tabla: PackedFloat32Array = _tabla(lado, semilla)
	var paso: float = float(LADO) / float(per)
	var out := PackedFloat32Array()
	out.resize(LADO * LADO)
	for y in LADO:
		var fy: float = (float(y) + oy) / paso
		var y0: int = int(floor(fy))
		var ty: float = fy - float(y0)
		# smoothstep en los dos ejes: con interpolacion lineal a secas se ven los rombos de la
		# reticula
		ty = ty * ty * (3.0 - 2.0 * ty)
		var fa: int = posmod(y0, lado) * lado
		var fb: int = posmod(y0 + 1, lado) * lado
		var fila: int = y * LADO
		for x in LADO:
			var fx: float = (float(x) * sx + ox) / paso
			var x0: int = int(floor(fx))
			var tx: float = fx - float(x0)
			tx = tx * tx * (3.0 - 2.0 * tx)
			var xa: int = posmod(x0, lado)
			var xb: int = posmod(x0 + 1, lado)
			out[fila + x] = lerpf(lerpf(tabla[fa + xa], tabla[fa + xb], tx),
				lerpf(tabla[fb + xa], tabla[fb + xb], tx), ty)
	return out


# La PIEDRA: tres octavas, y la mas gorda PESA POCO a proposito. Con la reticula de 4 nodos
# mandando el resultado, cada baldosa sale con dos o tres manchas grandes de silueta muy
# reconocible; puesta cien veces en una pared, el ojo las empareja al instante y se ve la
# cuadricula por encima de lo bien dibujada que este la piedra. El grano fino no se empareja.
static func _piedra(semilla: int, ox: float, oy: float, bl: int) -> PackedFloat32Array:
	var a: PackedFloat32Array = _campo(4, semilla, ox, oy, 1.0, bl)
	var b: PackedFloat32Array = _campo(8, semilla + 77, ox, oy, 1.0, bl)
	var c: PackedFloat32Array = _campo(16, semilla + 151, ox, oy, 1.0, bl)
	var out := PackedFloat32Array()
	out.resize(LADO * LADO)
	for i in LADO * LADO:
		out[i] = a[i] * 0.30 + b[i] * 0.40 + c[i] * 0.30
	return out


# ============================================================
#  PINTAR SOBRE BYTES
# ============================================================
# Image.set_pixel cuesta una llamada al motor por pixel. Aqui se escribe directo sobre los bytes
# de la hoja y la Image se crea de una vez al final, que es lo mismo que ya hace
# SpriteLienzo.montar_frames con el atlas de los bichos.
static func _poner(d: PackedByteArray, ancho: int, x: int, y: int, c: Color) -> void:
	var o: int = (y * ancho + x) * 4
	d[o] = int(c.r * 255.0)
	d[o + 1] = int(c.g * 255.0)
	d[o + 2] = int(c.b * 255.0)
	d[o + 3] = int(c.a * 255.0)


static func _escalon(v: float, rampa: Array) -> Color:
	return rampa[clampi(int(v * float(rampa.size())), 0, rampa.size() - 1)]


# ============================================================
#  DISTANCIA AL BORDE
# ============================================================
# Cuanto de "dentro" esta un pixel, en px, segun la mascara. Es LA pieza que hace que el autotile
# de superposicion funcione: la orilla del riachuelo y el filo de la mancha de musgo salen los dos
# de aqui, y por eso una capa nueva no tiene que inventarse sus bordes.
#
# Solo cuentan los lados EXPUESTOS (bit a 1). Un lado que continua en la misma capa no es borde,
# asi que dos baldosas seguidas de agua no dibujan orilla entre ellas.
static func _dentro(x: int, y: int, mask: int) -> float:
	var d: float = 999.0
	if (mask & 1) != 0:
		d = minf(d, float(y))
	if (mask & 2) != 0:
		d = minf(d, float(LADO - 1 - x))
	if (mask & 4) != 0:
		d = minf(d, float(LADO - 1 - y))
	if (mask & 8) != 0:
		d = minf(d, float(x))
	return d


# ============================================================
#  PINTORES
# ============================================================

# SUELO: piedra picada, con alguna grieta y algun guijarro suelto. Se mantiene OSCURO a proposito
# -- es el fondo sobre el que tiene que destacar todo lo demas, y ademas la mazmorra se juega a
# oscuras, asi que un suelo claro se comeria el contraste del farolillo.
static func _pintar_suelo(d: PackedByteArray, W: int, o: Vector2i, rampa: Array,
		sem: int, ox: float, oy: float, bl: int) -> void:
	var base: PackedFloat32Array = _piedra(sem, ox, oy, bl)
	var grieta: PackedFloat32Array = _campo(4, sem + 311, ox, oy, 1.0, bl)
	var mota: PackedFloat32Array = _campo(16, sem + 909, ox, oy, 1.0, bl)
	for y in LADO:
		for x in LADO:
			var i: int = y * LADO + x
			var v: float = base[i]
			# Grietas: el ruido de manchas gordas justo en su valor medio traza lineas finas.
			# FLOJAS y ESTRECHAS a proposito. Con el umbral en 0.035 y un -0.42, cada baldosa
			# salia con una grieta gruesa en forma de C, y una C es una silueta que el ojo
			# reconoce y empareja: el suelo entero se leia como un sello repetido aunque las
			# doce variantes fueran distintas. Una grieta que apenas se ve no se empareja.
			if absf(grieta[i] - 0.5) < 0.020:
				v -= 0.26
			# Guijarros: motas claras muy sueltas.
			if mota[i] > 0.93:
				v += 0.30
			_poner(d, W, o.x + x, o.y + y, _escalon(clampf(v, 0.0, 0.999), rampa))


# MURO. La camara del juego mira desde el sur y desde arriba (SpriteLienzo.CAMARA_GRADOS = 45),
# asi que los cuatro lados NO se dibujan igual:
#   SUR   -> la CARA del muro: la franja alta e iluminada que hace que la roca se lea levantada.
#   NORTE -> el filo de la coronacion: una linea oscura, porque ahi el bloque se va hacia atras.
#   ESTE / OESTE -> chaflan intermedio.
# Y todo lado expuesto lleva su linea negra de contorno, por lo mismo que la llevan los bichos
# (SpriteLienzo.contornear): sin ella la roca y el suelo se funden.
const CARA_ALTO := 13     # px de la cara sur
const CRESTA_ALTO := 3    # px del filo norte
const CHAFLAN := 3        # px de los chaflanes este/oeste

static func _pintar_muro(d: PackedByteArray, W: int, o: Vector2i, rampa: Array, mask: int,
		sem: int, ox: float, oy: float, bl: int) -> void:
	var n: bool = (mask & 1) != 0
	var e: bool = (mask & 2) != 0
	var s: bool = (mask & 4) != 0
	var w: bool = (mask & 8) != 0
	var negro := Color(0.02, 0.02, 0.03)
	var base: PackedFloat32Array = _piedra(sem, ox, oy, bl)
	var veta: PackedFloat32Array = _campo(6, sem + 41, ox, oy, 1.0, bl)
	for y in LADO:
		for x in LADO:
			var i: int = y * LADO + x
			var v: float = base[i] * 0.55 + 0.22
			if s and y >= LADO - CARA_ALTO:
				var t: float = float(y - (LADO - CARA_ALTO)) / float(CARA_ALTO)
				# se apaga hacia abajo: el pie del muro recibe menos luz que el canto de arriba
				v += 0.42 * (1.0 - t * 0.75)
				v += (veta[i] - 0.5) * 0.22
			if n and y < CRESTA_ALTO:
				v -= 0.30
			if w and x < CHAFLAN:
				v -= 0.16
			if e and x >= LADO - CHAFLAN:
				v -= 0.16
			var col: Color = _escalon(clampf(v, 0.0, 0.999), rampa)
			if (n and y == 0) or (s and y == LADO - 1) or (w and x == 0) or (e and x == LADO - 1):
				col = negro
			_poner(d, W, o.x + x, o.y + y, col)


# MUSGO: superposicion. NUNCA cubre la baldosa entera, ni siquiera en su corazon -- se agarra a
# manchas y deja ver la roca entre medias, que es lo que hace que parezca crecido y no una mano de
# pintura verde. La primera version tapaba casi el 100% y el muro perdia todo su relieve: se veia
# un rectangulo verde liso pegado encima de la pared.
#
# Hacia el borde se deshilacha: el umbral sube segun te acercas al filo, asi que la mancha se va
# quedando en motas sueltas en vez de cortarse en seco.
const MUSGO_ORILLA := 11.0

static func _pintar_musgo(d: PackedByteArray, W: int, o: Vector2i, rampa: Array, mask: int,
		sem: int, ox: float, oy: float, bl: int) -> void:
	var gordo: PackedFloat32Array = _campo(5, sem, ox, oy, 1.0, bl)
	var fino: PackedFloat32Array = _campo(11, sem + 55, ox, oy, 1.0, bl)
	for y in LADO:
		for x in LADO:
			var i: int = y * LADO + x
			var borde: float = clampf(_dentro(x, y, mask) / MUSGO_ORILLA, 0.0, 1.0)
			var mota: float = gordo[i] * 0.6 + fino[i] * 0.4
			# Umbral: 0.52 en el corazon de la mancha (o sea que ni ahi cubre ni la mitad), 1.05
			# en el filo (o sea nada).
			if mota < lerpf(1.05, 0.52, borde):
				_poner(d, W, o.x + x, o.y + y, Color(0, 0, 0, 0))
				continue
			var col: Color = _escalon(clampf(fino[i] * 0.55 + gordo[i] * 0.45, 0.0, 0.999), rampa)
			# El musgo es translucido: deja asomar el tono de la roca de debajo, y por eso el
			# mismo musgo se ve distinto sobre pared que sobre suelo.
			col.a = lerpf(0.45, 0.88, clampf((mota - 0.52) / 0.35, 0.0, 1.0)) * borde
			_poner(d, W, o.x + x, o.y + y, col)


# AGUA: superposicion ANIMADA. 'fase' recorre 0..1 a lo largo de los frames y desplaza el ruido,
# asi que la corriente CORRE de verdad en vez de latir en el sitio. El desplazamiento es de UNA
# baldosa entera a lo largo del ciclo: por eso el ultimo frame encaja con el primero y el bucle no
# da tirones.
#
# La orilla es lo que la conecta con lo que tenga debajo: los ultimos px se van a alfa y ademas
# llevan espuma, asi que el riachuelo desemboca en el estanque sin que exista ninguna pieza
# "riachuelo-que-toca-lago" -- por debajo se ve el agua del charco y ya esta.
const AGUA_ORILLA := 7.0

static func _pintar_agua(d: PackedByteArray, W: int, o: Vector2i, rampa: Array, mask: int,
		sem: int, fase: float, ox: float, oy: float, bl: int) -> void:
	var corre: float = fase * float(LADO)
	# Dos capas a distinta velocidad: es lo que da sensacion de profundidad y no de textura que se
	# arrastra en bloque.
	var a: PackedFloat32Array = _campo(6, sem, ox, oy - corre, 1.0, bl)
	var b: PackedFloat32Array = _campo(10, sem + 21, ox, oy - corre * 0.55, 1.3, bl)
	var espuma := Color(0.78, 0.88, 0.95)
	for y in LADO:
		for x in LADO:
			var i: int = y * LADO + x
			var borde: float = clampf(_dentro(x, y, mask) / AGUA_ORILLA, 0.0, 1.0)
			var v: float = a[i] * 0.6 + b[i] * 0.4
			var col: Color = _escalon(clampf(v * 0.75 + 0.12, 0.0, 0.999), rampa)
			# ESPUMA en la orilla: la cresta blanca solo donde el agua roza la tierra.
			if borde < 1.0 and v > lerpf(0.30, 0.95, borde):
				col = espuma
			col.a = borde
			_poner(d, W, o.x + x, o.y + y, col)


# SUMIDERO: el agujero por donde se cuela el agua cuando no hay lago al que llevarla. Existe por
# una regla de diseño -- el agua NUNCA termina en seco -- y es la tercera salida, junto al lago y
# a meterse por otra pared. Ver dungeon_floor._trazar_agua.
static func _pintar_sumidero(d: PackedByteArray, W: int, o: Vector2i, rampa: Array,
		sem: int) -> void:
	var c: float = float(LADO) * 0.5
	var tiembla: PackedFloat32Array = _campo(6, sem)
	var negro := Color(0.02, 0.03, 0.05)
	for y in LADO:
		for x in LADO:
			var i: int = y * LADO + x
			var dx: float = (float(x) + 0.5 - c) / 11.0
			var dy: float = (float(y) + 0.5 - c) / 9.5      # elipse: el suelo se ve en escorzo
			# el borde del agujero tiembla, para que no sea un ovalo de compas
			var r: float = sqrt(dx * dx + dy * dy) + (tiembla[i] - 0.5) * 0.16
			if r > 1.12:
				_poner(d, W, o.x + x, o.y + y, Color(0, 0, 0, 0))
			elif r > 0.92:
				_poner(d, W, o.x + x, o.y + y, rampa[rampa.size() - 1])   # labio mojado
			else:
				# hacia dentro se va a negro: no se ve el fondo
				var f: float = clampf(r / 0.92, 0.0, 1.0)
				_poner(d, W, o.x + x, o.y + y, negro.lerp(rampa[0], f * f))


# 'ox/oy' es DONDE CAE esta baldosa dentro del tapiz (en px) y 'bl' el tamaño del tapiz. Con eso,
# cada trozo mira su ventana del mismo dibujo continuo y las juntas desaparecen.
static func _pintar(d: PackedByteArray, W: int, capa: String, o: Vector2i, rampa: Array,
		mask: int, sem: int, fase: float, ox: float, oy: float, bl: int) -> void:
	match capa:
		"suelo":
			_pintar_suelo(d, W, o, rampa, sem, ox, oy, bl)
		"muro":
			_pintar_muro(d, W, o, rampa, mask, sem, ox, oy, bl)
		"musgo":
			_pintar_musgo(d, W, o, rampa, mask, sem, ox, oy, bl)
		"agua":
			_pintar_agua(d, W, o, rampa, mask, sem, fase, ox, oy, bl)
		"sumidero":
			_pintar_sumidero(d, W, o, rampa, sem)


# ============================================================
#  EL ATLAS
# ============================================================
static func generar(tramo: String) -> Image:
	var plano: Dictionary = _plano()
	var ancho: int = COLS * LADO
	var alto: int = int(plano["filas"]) * LADO
	var datos := PackedByteArray()
	datos.resize(ancho * alto * 4)     # resize deja a cero = transparente, que es lo que toca
	var base: int = hash(tramo)
	for capa in CAPAS_ORDEN:
		var f: int = frames_de(capa)
		var v: int = variantes_de(capa)
		var rampa: Array = _rampa(tramo, capa)
		var sem: int = base + hash(capa)
		var bl: int = bloque_de(capa)
		for i in _cuantas(capa):
			var c: Vector2i = celda_de(capa, i)
			# Las variantes de una misma mascara comparten SEMILLA y solo cambian de VENTANA: son
			# trozos del mismo tapiz, no dibujos distintos. (Antes cada variante llevaba su propia
			# semilla, que es justo lo que hacia que no casaran entre ellas.)
			var trozo: int = i % v
			var ox: float = float(trozo % bl) * float(LADO)
			var oy: float = float(trozo / bl) * float(LADO)
			for k in f:
				_pintar(datos, ancho, capa, Vector2i((c.x + k) * LADO, c.y * LADO), rampa,
					int(i / v), sem, float(k) / float(f), ox, oy, bl)
	return Image.create_from_data(ancho, alto, false, Image.FORMAT_RGBA8, datos)



# ============================================================
#  HORNEADO
# ============================================================
static func hornear(tramo: String) -> int:
	DirAccess.make_dir_recursive_absolute(CARPETA)
	var png: String = CARPETA + "terreno_" + tramo + ".png"
	if generar(tramo).save_png(ProjectSettings.globalize_path(png)) != OK:
		return 0
	var f := FileAccess.open(png, FileAccess.READ)
	var n: int = f.get_length() if f != null else 0
	if f != null:
		f.close()
	return n


# La textura del tramo: del disco si esta horneada, y si no dibujada al vuelo. Cacheada por tramo
# porque la piden todos los pisos del tramo y el TileSet se rehace en cada regenerar().
static var _cache: Dictionary = {}

static func atlas_de(tramo: String) -> Texture2D:
	if _cache.has(tramo):
		return _cache[tramo]
	var tex: Texture2D = null
	var png: String = CARPETA + "terreno_" + tramo + ".png"
	if ResourceLoader.exists(png):
		tex = load(png) as Texture2D
	if tex == null:
		tex = ImageTexture.create_from_image(generar(tramo))
	_cache[tramo] = tex
	return tex


# ============================================================
#  EL TileSet
# ============================================================
# Se construye en codigo y no como .tres a proposito, por lo mismo que los sprites de los bichos:
# el atlas puede venir de un PNG horneado o de una textura recien creada en memoria, y un .tres
# que apunte a una textura de runtime obliga a reimportar a media herramienta.
#
# Es UNO para todas las capas (fuente 0). Asi el suelo, el muro, el musgo y el agua comparten
# TileSet y lo unico que cambia entre TileMapLayers es QUE celdas pintan.
const VELOCIDAD_ANIM := 6.0    # frames por segundo de las capas animadas

static func tileset_de(tramo: String) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(LADO, LADO)
	var src := TileSetAtlasSource.new()
	src.texture = atlas_de(tramo)
	src.texture_region_size = Vector2i(LADO, LADO)
	for capa in CAPAS_ORDEN:
		var f: int = frames_de(capa)
		for i in _cuantas(capa):
			var c: Vector2i = celda_de(capa, i)
			src.create_tile(c)
			if f <= 1:
				continue
			# Los frames van SEGUIDOS a la derecha de la celda de la baldosa. 'columns' a 0 =
			# todos en la misma fila, que es justo como los reparte _plano().
			src.set_tile_animation_columns(c, 0)
			src.set_tile_animation_frames_count(c, f)
			for k in f:
				src.set_tile_animation_frame_duration(c, k, 1.0 / VELOCIDAD_ANIM)
	ts.add_source(src, 0)
	return ts


# ============================================================
#  MASCARA DE UNA CELDA
# ============================================================
# 1 norte, 2 este, 4 sur, 8 oeste. Bit a 1 = por ese lado NO soy yo mismo, o sea que ahi hay
# borde. 'soy' contesta si la celda vecina es de la misma capa.
#
# Esta aqui y no en cada sitio que pinta porque los cuatro bits tienen que valer lo mismo para
# todos: el muro, el musgo y el agua leen la misma mascara y por eso comparten los 16 dibujos.
static func mascara(celda: Vector2i, soy: Callable) -> int:
	var m: int = 0
	if not bool(soy.call(celda + Vector2i(0, -1))):
		m |= 1
	if not bool(soy.call(celda + Vector2i(1, 0))):
		m |= 2
	if not bool(soy.call(celda + Vector2i(0, 1))):
		m |= 4
	if not bool(soy.call(celda + Vector2i(-1, 0))):
		m |= 8
	return m
