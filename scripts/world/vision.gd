# ============================================================
#  vision.gd  (class_name Vision)
#  QUE se ve y que no. Datos puros, como Decorado y DungeonGenerator: aqui no hay nodos ni
#  shaders, solo una rejilla de bytes que dice cuanta luz llega a cada trozo del piso.
#
# ------------------------------------------------------------
#  LA REGLA (la dio el usuario con un dibujo, y es la que manda)
# ------------------------------------------------------------
#      VISIBLE(p) =  hay_linea_recta(TU_OJO, p)
#                AND existe un farolillo L con  dist(L,p) <= radio(L)
#                                          AND  hay_linea_recta(L, p)
#
#  O sea, DOS condiciones: que este ILUMINADO por alguien y que TU lo puedas ver desde donde
#  estas. No basta con una.
#
#  POR QUE NO VALEN LAS LUCES 2D DE GODOT. Una PointLight2D con sombras calcula la sombra DESDE
#  LA LUZ, no desde tu ojo. Con eso, un jugador que esta al otro lado de un muro con su propio
#  farolillo se te veria a traves de la roca: su luz le ilumina y a Godot le da igual que tu no
#  tengas linea con el. El caso del dibujo -- "al de arriba no lo verias porque hay un muro; al de
#  abajo si, aunque tu luz no llegue, porque su luz esta dentro de tu campo de vision" -- solo
#  sale con las dos condiciones separadas. De ahi esta rejilla.
#
#  EL CAMPO DE VISION NO TIENE TOPE DE DISTANCIA (decidido con el usuario): si hay linea recta y
#  algo esta iluminado, lo ves, este a las casillas que este. Lo que tiene alcance es la LUZ.
#
# ------------------------------------------------------------
#  POR QUE EN CPU Y POR CELDAS
# ------------------------------------------------------------
#  Un shader a pantalla completa tendria que trazar un rayo POR PIXEL (1280x720) y ademas uno por
#  cada farolillo. La rejilla del piso, en cambio, son 100x60 celdas: cabe entera en un pañuelo.
#  Se calcula a SUBCELDAS (2 por celda) unas quince veces por segundo, se sube como una textura
#  R8 minuscula y el shader solo la lee. El difuminado de la niebla sale gratis del filtrado
#  bilineal al ampliarla.
#
#  Y hay una segunda razon, mas importante que el rendimiento: teniendo la mascara en CPU se puede
#  preguntar "¿se ve esta celda?" para APAGAR nodos (enemigos, jugadores remotos, vetas). Una capa
#  negra por encima tapa el terreno, pero los Label de nombre y las particulas viven en el mundo y
#  se seguirian viendo a traves de la roca.
# ============================================================

extends RefCounted
class_name Vision

# Subdivisiones por celda de mapa. 2 es el punto dulce: a 1 la niebla se mueve a saltos de 32 px y
# se nota el escalon; a 4 son cuatro veces mas rayos para una mejora que no se ve una vez el
# shader difumina.
const SUB := 2

# El SUELO DURO del radio de luz, en celdas. Pase lo que pase -- sin farolillo, apagado, sin
# carbon o con el requisito del piso por las nubes -- SIEMPRE ves este corro a tu alrededor. Es
# una promesa al jugador: la oscuridad puede dejarte casi ciego, nunca ciego del todo.
#
# 3 celdas = 96 px, o sea tres veces tu propio cuerpo. A ojo parece poquisimo escrito aqui, pero
# en pantalla (zoom 1.8) es un corro de unos 350 px de ancho: ves donde pisas y poco mas. Estaba
# en 4.5 y con eso el corro se comia media sala, con lo que el farolillo no habria hecho falta
# para nada -- y el farolillo es justo el sistema que esto viene a sostener.
const RADIO_MINIMO := 3.0

# Lo ultimo del radio se apaga en degradado en vez de cortarse en seco: es el "difuminado tipo
# niebla" del dibujo. 0.35 = el 35% final del alcance. Cuanto mas corto es el radio, mas
# proporcion tiene que ocupar el desvanecido, o el corro se lee como un circulo recortado.
const DESVANECIDO := 0.35

var ancho: int = 0          # en subceldas
var alto: int = 0
var mascara := PackedByteArray()

var _gen: DungeonGenerator = null
# Cache de solidez POR SUBCELDA. Se rellena una vez por piso: preguntarselo al generador dentro
# del bucle de rayos es la diferencia entre esto y una presentacion de diapositivas.
var _solido := PackedByteArray()

# Memoria de "¿tengo linea con esta subcelda?" DENTRO de una pasada. 0 = sin mirar, 1 = si, 2 = no.
#
# Es LA optimizacion que hace viable la regla. El rayo del OJO a una subcelda no depende de que
# farolillo la ilumine, asi que sin esto una subcelda alumbrada por tres farolillos lanzaba tres
# rayos identicos. Y el caso caro es justo el que importa: el corro de un jugador remoto al otro
# extremo del piso, donde cada una de sus ~800 subceldas tiraria un rayo de 100 pasos hasta ti.
# Con la memoria, cada subcelda paga su rayo UNA vez por pasada.
var _visto := PackedByteArray()

# Buffer de trabajo del sombreado por octantes: que subceldas alcanza el barrido que se esta
# haciendo (255 = si). Se reutiliza para el ojo y para cada foco, uno detras de otro.
var _campo := PackedByteArray()

# La imagen del volcado, reusada entre pasadas (ver volcar).
var _img: Image = null


func preparar(gen: DungeonGenerator) -> void:
	_gen = gen
	ancho = gen.ancho * SUB
	alto = gen.alto * SUB
	mascara.resize(ancho * alto)
	_solido.resize(ancho * alto)
	_visto.resize(ancho * alto)
	_campo.resize(ancho * alto)
	for y in alto:
		var fila: int = y * ancho
		for x in ancho:
			_solido[fila + x] = 1 if gen.es_solido(Vector2i(x / SUB, y / SUB)) else 0


# ------------------------------------------------------------
#  EL CALCULO
# ------------------------------------------------------------
# 'focos' = [{pos: Vector2 (px de mundo), radio: float (celdas)}, ...]  -- todos los farolillos
#           que hay en el piso, el tuyo y los de los demas.
# 'ojo'   = tu posicion en px de mundo. Es el UNICO punto de vista: la mascara es TUYA.
# 'vista'  = el rectangulo del mundo que se esta viendo (en px), con margen. Lo de fuera no se
#            calcula: no se dibuja y no hay nodo que apagar ahi. Es EL recorte que hace esto
#            barato -- sin el, el corro de un jugador remoto al otro extremo del piso se calculaba
#            entero (y cada una de sus subceldas tira un rayo largo hasta tu ojo) para acabar en
#            un trozo de mascara que nadie mira. Medido: de 4-6 ms por pasada a menos de 1.
#            Un rectangulo vacio = sin recorte (lo que quieren las pruebas).
func calcular(focos: Array, ojo: Vector2, vista: Rect2 = Rect2()) -> void:
	if ancho <= 0:
		return
	# Empezar a cero: lo que no toque nadie se queda a oscuras. Y olvidar los rayos de la pasada
	# anterior, que valian para el sitio donde estabas entonces.
	mascara.fill(0)
	_visto.fill(0)
	if focos.is_empty():
		return

	var px_sub: float = float(DungeonGenerator.CELDA) / float(SUB)
	var ojo_s := Vector2(ojo.x / px_sub, ojo.y / px_sub)

	# Ventana de trabajo en subceldas.
	var vx0: int = 0
	var vy0: int = 0
	var vx1: int = ancho
	var vy1: int = alto
	if vista.size.x > 0.0:
		vx0 = maxi(0, int(floor(vista.position.x / px_sub)))
		vy0 = maxi(0, int(floor(vista.position.y / px_sub)))
		vx1 = mini(ancho, int(ceil(vista.end.x / px_sub)))
		vy1 = mini(alto, int(ceil(vista.end.y / px_sub)))

	# 1) ¿QUE VES TU desde donde estas? Un solo barrido desde el ojo sobre la ventana, en vez de un
	#    rayo por subcelda. Sin tope de distancia (solo estorba la roca), asi que el alcance es lo
	#    que quepa en la ventana: por eso el radio sale de su esquina mas lejana.
	# Va directo a `_visto`, que es su sitio: asi no hace falta duplicar un array del tamaño del
	# piso en cada pasada solo para guardarlo mientras `_campo` se reutiliza con los focos.
	var alcance: int = int(ceil(maxf(
		maxf(absf(ojo_s.x - float(vx0)), absf(ojo_s.x - float(vx1))),
		maxf(absf(ojo_s.y - float(vy0)), absf(ojo_s.y - float(vy1)))) * 1.5)) + 2
	_campo_del_ojo(int(ojo_s.x), int(ojo_s.y), alcance, vx0, vy0, vx1, vy1)

	# 2) LA LUZ de cada farolillo, con su propio barrido. Una subcelda se ilumina si le llega la luz
	#    Y la ves tu: las dos condiciones de la regla, ahora sin un solo rayo suelto.
	for f in focos:
		var pos: Vector2 = f["pos"]
		# El SUELO DURO solo vale para los farolillos de la gente. Un foco del mundo (el musgo que
		# brilla) pide el radio que pide, y elevarselo a tres celdas lo convertiria en otro farol.
		var radio_c: float = float(f["radio"])
		if bool(f.get("personaje", true)):
			radio_c = maxf(RADIO_MINIMO, radio_c)
		var radio_sub: float = radio_c * float(SUB)
		# Cuanto alumbra este foco como mucho (1.0 = un farolillo). Ver niebla.MUSGO_INTENSIDAD.
		var intensidad: float = clampf(float(f.get("intensidad", 1.0)), 0.0, 1.0)
		var centro := Vector2(pos.x / px_sub, pos.y / px_sub)
		var r: int = int(ceil(radio_sub))
		var cx: int = int(centro.x)
		var cy: int = int(centro.y)
		var x0: int = maxi(vx0, cx - r)
		var x1: int = mini(vx1, cx + r + 1)
		var y0: int = maxi(vy0, cy - r)
		var y1: int = mini(vy1, cy + r + 1)
		if x0 >= x1 or y0 >= y1:
			continue      # este foco no toca la ventana: no hay nada que pintar
		# OJO: `_campo` NO se limpia entero aqui. Vaciar un array del piso por cada foco cuesta lo
		# mismo lleve el foco un radio de 14 celdas o de 2, y con varios focos pequeños (el musgo
		# que brilla, que son muchos y diminutos) esa limpieza pasaba a ser el gasto principal:
		# medido, 12 focos de radio 2 costaban casi tanto como cuatro farolillos a tope. Como el
		# barrido solo marca DENTRO de la ventana que se le da, basta con borrar esa ventana, y se
		# hace en el mismo recorrido que ya la lee, justo debajo.
		_campo_de_vision(cx, cy, r, x0, y0, x1, y1)
		var tope: int = clampi(int(intensidad * 255.0), 0, 255)
		var desde: float = radio_sub * (1.0 - DESVANECIDO)
		for y in range(y0, y1):
			var fila: int = y * ancho
			for x in range(x0, x1):
				var idx: int = fila + x
				var alcanzada: bool = _campo[idx] != 0
				_campo[idx] = 0      # limpieza para el foco siguiente
				if not alcanzada or _visto[idx] == 0:
					continue
				if mascara[idx] >= tope:
					continue      # ya lo da otro foco igual o mejor
				var d: float = Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(centro)
				if d > radio_sub:
					continue      # el barrido va por cuadrado; el alcance es redondo
				# Caida suave en el ultimo tramo del alcance.
				var t: float = 1.0
				if d > desde:
					t = 1.0 - (d - desde) / maxf(0.001, radio_sub - desde)
				var v: int = clampi(int(t * float(tope)), 0, 255)
				if v > mascara[idx]:
					mascara[idx] = v


# ============================================================
#  EL CAMPO DE VISION, POR OCTANTES
# ============================================================
# Lo que antes hacia el bucle de rayos: para cada subcelda de un disco, "¿tengo linea con el
# centro?". Eso es un rayo POR SUBCELDA, y cada rayo cuesta tantos pasos como radio tenga el disco,
# o sea que el coste sube con el CUBO del radio. Medido antes de cambiarlo, con un grupo de cuatro
# en el piso 12:
#
#     radio  3 (sin farol) ->  0.46 ms      radio 10 (mejorado) ->  7.16 ms
#     radio  7 (normal)    ->  3.75 ms      radio 14 (a tope)   -> 15.73 ms
#
# 15.7 ms es MAS que un frame entero a 60 fps, y eso en escritorio; en movil (que es donde el
# usuario lo noto) es un tiron cada cuatro frames. Y el culpable no era la niebla ni el tamaño del
# mapa -- que no influye, tambien medido -- sino el RADIO del farolillo: mejorarlo te penalizaba.
#
# El sombreado por octantes recorre el disco UNA vez, arrastrando el arco de sombra que proyecta
# cada roca segun avanza. Cada subcelda se visita una sola vez y no lanza ningun rayo, asi que el
# coste pasa a ser el AREA del disco: de radio³ a radio². La regla que dibuja es la misma (una
# subcelda se ve si no hay roca por medio) y la promesa de la cara del muro tambien: la roca se
# marca como vista y ES ahi donde se corta la luz, nunca antes.
#
# Se divide en ocho octantes porque el algoritmo solo sabe barrer un triangulo diagonal; los ocho
# juntos cubren el disco. La matriz (xx, xy, yx, yy) es lo que gira ese triangulo a cada uno.
const OCTANTES := [
	[1, 0, 0, 1], [0, 1, 1, 0], [0, -1, 1, 0], [-1, 0, 0, 1],
	[-1, 0, 0, -1], [0, -1, -1, 0], [0, 1, -1, 0], [1, 0, 0, -1],
]


# Marca en `_campo` (255) las subceldas visibles desde (cx, cy) hasta `radio` subceldas, sin salirse
# de la ventana [vx0,vx1) x [vy0,vy1). El centro siempre se ve.
func _campo_de_vision(cx: int, cy: int, radio: int,
		vx0: int, vy0: int, vx1: int, vy1: int) -> void:
	if cx >= vx0 and cx < vx1 and cy >= vy0 and cy < vy1:
		_campo[cy * ancho + cx] = 255
	for o in OCTANTES:
		_barrer(cx, cy, radio, 1, 1.0, 0.0, o[0], o[1], o[2], o[3], vx0, vy0, vx1, vy1)


# El campo del OJO, trasladado a `_visto`. Va en su funcion y no como parametro de la de arriba
# porque en GDScript un PackedByteArray se pasa POR VALOR: escribir en el argumento no tocaria el
# array de verdad y el ojo se quedaria a cero (todo negro) sin dar ningun error. Se copia solo la
# ventana, no el piso entero.
func _campo_del_ojo(cx: int, cy: int, radio: int,
		vx0: int, vy0: int, vx1: int, vy1: int) -> void:
	_campo_de_vision(cx, cy, radio, vx0, vy0, vx1, vy1)
	for y in range(vy0, vy1):
		var fila: int = y * ancho
		for x in range(vx0, vx1):
			var idx: int = fila + x
			_visto[idx] = _campo[idx]
			_campo[idx] = 0


# Un octante. 'fila' = a que distancia del centro vamos; 'alta'/'baja' = las pendientes que
# delimitan el arco todavia iluminado. Al topar con roca, el arco se parte: se sigue por la mitad de
# arriba en una llamada nueva y se continua por la de abajo en esta.
func _barrer(cx: int, cy: int, radio: int, fila: int, alta: float, baja: float,
		xx: int, xy: int, yx: int, yy: int,
		vx0: int, vy0: int, vx1: int, vy1: int) -> void:
	if alta < baja:
		return
	var radio2: int = radio * radio
	var tapado: bool = false
	var j: int = fila
	while j <= radio:
		var dy: int = -j
		var dx: int = -j - 1
		var nueva_alta: float = alta
		while dx <= 0:
			dx += 1
			var x: int = cx + dx * xx + dy * xy
			var y: int = cy + dx * yx + dy * yy
			# Pendientes de las dos esquinas de esta subcelda.
			var p_izq: float = (float(dx) - 0.5) / (float(dy) + 0.5)
			var p_der: float = (float(dx) + 0.5) / (float(dy) - 0.5)
			if alta < p_der:
				continue      # aun no hemos entrado en el arco
			if baja > p_izq:
				break         # ya lo hemos pasado de largo
			var fuera: bool = x < 0 or y < 0 or x >= ancho or y >= alto
			var roca: bool = true if fuera else _solido[y * ancho + x] != 0
			if not fuera and dx * dx + dy * dy <= radio2 \
					and x >= vx0 and x < vx1 and y >= vy0 and y < vy1:
				_campo[y * ancho + x] = 255
			if tapado:
				if roca:
					nueva_alta = p_der
				else:
					tapado = false
					alta = nueva_alta
			elif roca and j < radio:
				# Empieza sombra: la parte del arco por ENCIMA de esta roca sigue viva aparte.
				tapado = true
				_barrer(cx, cy, radio, j + 1, alta, p_izq, xx, xy, yx, yy, vx0, vy0, vx1, vy1)
				nueva_alta = p_der
		if tapado:
			return    # el arco se ha cerrado del todo: mas lejos ya no llega nada
		j += 1


# ------------------------------------------------------------
#  LINEA DE VISION
# ------------------------------------------------------------
# Rayo por DDA sobre la rejilla de subceldas. Devuelve false si hay roca por medio.
#
# Ya no lo usa `calcular` (lo sustituyo el sombreado por octantes de arriba, que hace lo mismo para
# un disco entero y sin un rayo por subcelda). Se queda porque sigue siendo la forma barata de
# preguntar por UN punto suelto, y porque es con lo que se contrasta que el algoritmo nuevo dibuja
# lo mismo que el viejo (ver tools/probar_vision.gd).
#
# La roca del DESTINO no corta: si no, la cara del muro nunca se iluminaria y las paredes serian
# un agujero negro con el suelo brillando hasta el borde. Ves el muro, y AHI se corta la luz.
func _linea(desde: Vector2, hasta: Vector2) -> bool:
	var x0: int = int(desde.x)
	var y0: int = int(desde.y)
	var x1: int = int(hasta.x)
	var y1: int = int(hasta.y)
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	var guarda: int = 0
	while guarda < 4096:
		guarda += 1
		if x0 == x1 and y0 == y1:
			return true
		# El punto de PARTIDA tampoco corta (estas dentro de tu propia celda), por eso se
		# comprueba DESPUES de avanzar y se sale antes al llegar.
		var e2: int = err * 2
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
		if x0 < 0 or y0 < 0 or x0 >= ancho or y0 >= alto:
			return false
		if x0 == x1 and y0 == y1:
			return true
		if _solido[y0 * ancho + x0] != 0:
			return false
	return false


# ------------------------------------------------------------
#  CONSULTAS
# ------------------------------------------------------------

# Cuanta luz llega a un punto del mundo, 0..1. Es lo que usa el piso para apagar los nodos que no
# se ven (enemigos, jugadores remotos, vetas).
func luz_en(mundo: Vector2) -> float:
	if ancho <= 0:
		return 0.0
	var px_sub: float = float(DungeonGenerator.CELDA) / float(SUB)
	var x: int = int(mundo.x / px_sub)
	var y: int = int(mundo.y / px_sub)
	if x < 0 or y < 0 or x >= ancho or y >= alto:
		return 0.0
	return float(mascara[y * ancho + x]) / 255.0


# La mascara como imagen para el shader. Se REUSA la textura (update) en vez de crearla cada vez:
# a quince veces por segundo, crear una ImageTexture nueva es basura para el recolector.
func volcar(tex: ImageTexture) -> ImageTexture:
	# La IMAGEN tambien se reusa, no solo la textura: `create_from_data` reservaba un Image nuevo
	# quince veces por segundo (unos 47 KB en un piso hondo) y todos acababan en el recolector. En
	# escritorio da igual; en movil, donde este sistema ya va justo, la basura se nota.
	if _img == null or _img.get_width() != ancho or _img.get_height() != alto:
		_img = Image.create_from_data(ancho, alto, false, Image.FORMAT_R8, mascara)
	else:
		_img.set_data(ancho, alto, false, Image.FORMAT_R8, mascara)
	if tex == null:
		return ImageTexture.create_from_image(_img)
	tex.update(_img)
	return tex
