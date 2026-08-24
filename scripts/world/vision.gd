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


func preparar(gen: DungeonGenerator) -> void:
	_gen = gen
	ancho = gen.ancho * SUB
	alto = gen.alto * SUB
	mascara.resize(ancho * alto)
	_solido.resize(ancho * alto)
	_visto.resize(ancho * alto)
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

	for f in focos:
		var pos: Vector2 = f["pos"]
		var radio_sub: float = maxf(RADIO_MINIMO, float(f["radio"])) * float(SUB)
		var centro := Vector2(pos.x / px_sub, pos.y / px_sub)
		var r: int = int(ceil(radio_sub))
		var cx: int = int(centro.x)
		var cy: int = int(centro.y)
		for y in range(maxi(vy0, cy - r), mini(vy1, cy + r + 1)):
			var fila: int = y * ancho
			for x in range(maxi(vx0, cx - r), mini(vx1, cx + r + 1)):
				var idx: int = fila + x
				# Ya iluminada por otro foco y a tope: no hay nada que ganar.
				if mascara[idx] >= 255:
					continue
				var punto := Vector2(float(x) + 0.5, float(y) + 0.5)
				var d: float = punto.distance_to(centro)
				if d > radio_sub:
					continue
				# 1) ¿le llega la luz de ESTE farolillo?
				if not _linea(centro, punto):
					continue
				# 2) ¿la ves TU desde donde estas? Sin tope de distancia: solo estorba la roca.
				#    Memorizado: el rayo del ojo no depende del farolillo (ver _visto).
				var m: int = _visto[idx]
				if m == 0:
					m = 1 if _linea(ojo_s, punto) else 2
					_visto[idx] = m
				if m == 2:
					continue
				# Caida suave en el ultimo tramo del alcance.
				var t: float = 1.0
				var desde: float = radio_sub * (1.0 - DESVANECIDO)
				if d > desde:
					t = 1.0 - (d - desde) / maxf(0.001, radio_sub - desde)
				var v: int = clampi(int(t * 255.0), 0, 255)
				if v > mascara[idx]:
					mascara[idx] = v


# ------------------------------------------------------------
#  LINEA DE VISION
# ------------------------------------------------------------
# Rayo por DDA sobre la rejilla de subceldas. Devuelve false si hay roca por medio.
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
	var img := Image.create_from_data(ancho, alto, false, Image.FORMAT_R8, mascara)
	if tex == null:
		return ImageTexture.create_from_image(img)
	tex.update(img)
	return tex
