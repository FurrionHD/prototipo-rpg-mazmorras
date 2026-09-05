# ============================================================
#  wall_crack_fx.gd
#  LO QUE LE PASA A LA PIEDRA que esta a punto de reventar y luego se rehace: primero se raja
#  (grietas que salen del punto de impacto, se ramifican y se afilan), luego se abre el BOQUETE por
#  donde ha salido el bicho, y luego la pared se cierra sola de fuera hacia dentro.
#
#  TODO ESTO SE DIBUJA EN PIXELES, no con lineas. Es lo primero que hay que saber para tocar aqui.
#  El juego es pixel art: celda de 32 unidades de mundo = tile de 32 px de arte (DungeonGenerator
#  .CELDA y TerrenoSprites.LADO), o sea UNA UNIDAD ES UN PIXEL, y todo se pinta con filtro NEAREST.
#  Un draw_line o un draw_colored_polygon salen suavizados, con diagonales blandas y bordes a medio
#  tono: al lado de la roca del juego cantan muchisimo. Asi que cada grieta se RASTERIZA a la
#  rejilla del arte (Bresenham + pincel cuadrado) y se pinta como cuadraditos de 1x1 alineados a
#  entero, igual que si estuviera dibujada en el tile.
#
#  LO QUE HACE QUE UNA GRIETA PAREZCA UNA GRIETA (y no un arañazo), sacado de las referencias:
#    1. SE RAMIFICA, y las hijas otra vez. Una linea sola, por quebrada que sea, se lee como un
#       rasguño; lo que dice "esto se ha partido" es el arbol.
#    2. SE AFILA. Cada rama nace mas fina que su madre y ademas adelgaza a lo largo, hasta puntas de
#       un pixel. Con grosor constante parece un rio dibujado.
#    3. NO VA RECTA NI VA SUAVE. Se quiebra a tirones: la piedra cede por donde puede.
#    4. ES ASIMETRICA. Las ramas no salen a intervalos iguales ni con el mismo largo.
#
#  TODO POR CODIGO Y CON SEMILLA: la rotura de una celda es SIEMPRE la misma. No es capricho: en
#  multijugador cada maquina la pinta por su cuenta (nadie manda un dibujo por red) y tiene que
#  salir identica, y ademas un redibujado a media aparicion no puede cambiarle la forma.
#
#  ES SOLO DIBUJO. Ni choca, ni tapa la luz, ni la IA sabe que existe: la pared nunca llega a
#  abrirse de verdad (el bicho nace en la celda de suelo de al lado).
# ============================================================

extends Node2D

# UN PIXEL DE ARTE. Ver la cabecera: la celda mide 32 unidades y su tile 32 px, asi que la rejilla a
# la que hay que pegarse es la unidad. Si algun dia el arte subiera de resolucion, esto sube con el.
const PIXEL := 1.0

# Ni negro puro ni un gris cualquiera: es el color de la roca maciza que hay DETRAS de las paredes
# (DungeonFloor.color_roca). Asi la grieta no se lee como una raya pintada encima sino como el hueco
# por el que se ve el fondo, que es lo que tiene que parecer.
const COL_GRIETA := Color(0.05, 0.05, 0.07)
const COL_HUECO := Color(0.05, 0.05, 0.07)
# El LABIO de piedra recien partida, un tono mas claro que la cara del muro: es lo que le da volumen
# al agujero. Sin el, el boquete es una silueta plana recortada.
const COL_LABIO := Color(0.42, 0.40, 0.50)
# El FILO de luz que perfila la grieta por abajo y por la derecha (ver _perfilar). Mas claro que la
# cara del muro, para que se lea igual sobre la pared que sobre el suelo oscuro.
const COL_FILO := Color(0.38, 0.36, 0.45)

# --- LA FORMA DEL ARBOL DE GRIETAS ---
const TRONCOS := 5           # grietas principales por foco
const HONDURA := 3           # cuantas veces se ramifica
const TRAMOS := 5            # en cuantos trozos se quiebra cada rama
const GIRO := 0.72           # cuanto se tuerce en cada trozo (rad)
const GROSOR := 3            # px del pincel de un tronco recien nacido
const LARGO := 1.7           # largo del tronco, en celdas: tiene que salirse de la suya

# --- EL BOQUETE ---
# UNA MANCHA POR CELDA, no una sola grande desde el centro del destrozo: se probo asi y estaba mal,
# porque nada impedia que el contorno se saliera de las celdas que de verdad reventaron -- un brote
# grande se comia la esquina de la sala y se derramaba sobre el suelo. Por celda no puede pasar, POR
# CONSTRUCCION: cada mancha se recorta a su celda y solo se estira hacia los lados donde la vecina
# TAMBIEN esta rota. Ahi las dos se solapan y el conjunto se lee como un unico agujero irregular.
const HUECO_VERTICES := 24    # muestras del contorno; entre ellas se interpola
const HUECO_MORDIDA := 0.24   # cuanto ondula el borde (mordida gruesa)
const HUECO_ASTILLA := 0.10   # y la mordida fina, la que lo astilla (ver _mancha)
# CONTENIDO: no pasa del borde de su celda y deja el marco de piedra que la sujeta (a 0,5 se comeria
# la celda entera y volveria la cuadricula). ABIERTO: hacia una vecina rota se pasa de largo.
const HUECO_CONTENIDO := 0.42
const HUECO_ABIERTO := 0.76

# --- COMO SE CIERRA ---
# NO de golpe y a la vez. La piedra se rehace DE FUERA HACIA DENTRO: las celdas del borde -- que
# tienen roca sana pegada -- se cierran primero, y el centro del boquete es lo ultimo que queda. Un
# brote de cuatro se ve cerrarse por las esquinas hacia el medio, que es como se repara un agujero de
# verdad; cerrandolas todas a la vez se leia como si alguien bajara un regulador de opacidad. Y
# DENTRO de cada celda, cada pixel lleva ademas su propio desfase, que es lo que hace que parezca
# regenerarse a trozos en vez de una imagen encogiendose.
const RETARDO_CELDA := 0.5
const RETARDO_PIXEL := 0.45

# Los pixeles ya resueltos. Cada uno lleva su posicion (ya cuadriculada) y su momento: 't' para las
# grietas (cuando aparece) y 'r' para el hueco (cuanto tarda en cerrarse). Se calculan UNA vez y
# _draw solo pinta los que tocan, asi que la forma no cambia a media animacion.
var _px_grieta: Array = []    # [{p: Vector2, t: float}]
var _px_hueco: Array = []     # [{p: Vector2, r: float, labio: bool}]
var _avance: float = 0.0      # cuanta grieta se ve (0..1)
var _cierre: float = 0.0      # cuanto queda del boquete (1 = recien roto, 0 = pared entera)
var _roto: bool = false
var _zona: Dictionary = {}    # por donde puede correr la grieta
var _lado: float = 32.0
# El foco del arbol que se esta rasterizando y hasta donde puede llegar: con eso, cada pixel sabe a
# que distancia del centro esta y de ahi sale su momento (ver _trazar).
var _foco := Vector2.ZERO
var _alcance: float = 1.0


# ------------------------------------------------------------
#  LAS GRIETAS
# ------------------------------------------------------------
# 'focos' son los puntos (en mundo) de donde sale cada grieta; 'permitidas' las celdas por las que
# puede correr -- una pared que revienta se raja tambien hacia el suelo de delante y hacia las
# paredes de al lado, asi que no se le puede atar a las celdas que estallan; lo unico prohibido es
# dibujar sobre el vacio, que ahi no hay nada que partir.
func preparar(focos: Array, permitidas: Array, lado: float, sem: int) -> void:
	_px_grieta.clear()
	_lado = lado
	_zona.clear()
	for c in permitidas:
		_zona[c as Vector2i] = true
	var vistos: Dictionary = {}   # un pixel pintado dos veces no se nota, pero se paga
	for f in focos:
		_arbol(f as Vector2, lado, sem, vistos)
	_perfilar(vistos)
	# Por MOMENTO DE APARICION, para que _draw pueda cortar por el primero que aun no toca en vez de
	# recorrerlos todos comparando.
	_px_grieta.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	queue_redraw()


# EL FILO DE LUZ: un pixel claro pegado por abajo y por la derecha de cada grieta, como si la luz
# entrara por arriba a la izquierda y el borde de la rotura la cogiera. Es la tecnica de toda la vida
# del pixel art para dar profundidad a un hueco, y aqui resuelve ademas un problema de verdad: la
# grieta es casi negra y sobre el SUELO -- que ya es oscuro -- no se veia. Con el filo se lee sobre
# cualquier superficie sin tener que cambiarle el color a la grieta.
#
# Hereda el momento de aparicion de su pixel, asi que sale con el y no antes.
func _perfilar(vistos: Dictionary) -> void:
	var por_px: Dictionary = {}
	var gordos: Dictionary = {}
	for g in _px_grieta:
		var k0 := Vector2i((g["p"] as Vector2) / PIXEL)
		por_px[k0] = float(g["t"])
		# SOLO LAS GORDAS LLEVAN FILO. Sobre el suelo -- que ya es oscuro -- el negro de la grieta casi
		# no contrasta y lo unico que se veia era el filo claro: los hilos de un pixel salian como
		# rayas BLANCAS por el suelo, que no parece una grieta sino un arañazo de tiza. Perfilando solo
		# lo que tiene cuerpo, la rama gorda gana volumen y el hilo fino se queda como lo que es.
		if int(g.get("w", 1)) >= 2:
			gordos[k0] = float(g["t"])
	var filo: Dictionary = {}
	for k in gordos:
		for d in [Vector2i(0, 1), Vector2i(1, 0)]:
			var v: Vector2i = (k as Vector2i) + d
			if por_px.has(v):
				continue   # ahi sigue habiendo grieta: no es borde
			# El mas TEMPRANO de los vecinos: si dos grietas comparten filo, sale con la primera.
			var t: float = float(gordos[k])
			if filo.has(v):
				t = minf(t, float(filo[v]))
			filo[v] = t
	for k in filo:
		_px_grieta.append({"p": Vector2(k as Vector2i) * PIXEL, "t": float(filo[k]), "filo": true})


func _dentro(p: Vector2) -> bool:
	if _zona.is_empty():
		return true
	return _zona.has(Vector2i(int(floor(p.x / _lado)), int(floor(p.y / _lado))))


func _arbol(foco: Vector2, lado: float, sem: int, vistos: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	# La semilla sale del PUNTO, no de un contador: el mismo sitio da la misma grieta en cualquier
	# maquina y en cualquier momento.
	rng.seed = hash(Vector3i(int(foco.x), int(foco.y), sem))
	_foco = foco
	# Lo mas lejos que puede llegar un tronco con todas sus hijas: el tronco entero mas la cadena de
	# hijas, cada una al 55% de su madre. Es la vara con la que se normaliza la distancia.
	_alcance = maxf(1.0, LARGO * lado * (1.0 + 0.55 + 0.3 + 0.17))
	var giro: float = rng.randf() * TAU
	for i in TRONCOS:
		# En abanico, con un bandazo por tronco: a intervalos iguales se ve una estrella de dibujo
		# animado, no una piedra partida.
		var ang: float = giro + TAU * float(i) / float(TRONCOS) + rng.randf_range(-0.45, 0.45)
		_rama(rng, foco, ang, GROSOR, LARGO * lado, HONDURA, 0.0, vistos)


# UNA RAMA, y de paso sus hijas. 'nace' es el momento en que empieza a salir; cada hija nace mas
# tarde que su madre, y por eso la grieta crece de dentro hacia fuera en vez de aparecer entera.
func _rama(rng: RandomNumberGenerator, desde: Vector2, ang: float, grosor: int, largo: float,
		hondura: int, nace: float, vistos: Dictionary) -> void:
	var p: Vector2 = desde
	var paso: float = largo / float(TRAMOS)
	# Lo que tarda ESTA rama en dibujarse entera. Las de fuera son mas cortas y salen mas deprisa, que
	# es lo que hace que el ultimo tramo del aviso se llene de hilos de golpe.
	var dura: float = 0.35 * pow(0.65, float(HONDURA - hondura))
	for t in TRAMOS:
		# Se tuerce a TIRONES, no con una curva: la piedra cede por donde puede.
		ang += rng.randf_range(-GIRO, GIRO)
		var siguiente: Vector2 = p + Vector2(cos(ang), sin(ang)) * paso * rng.randf_range(0.65, 1.35)
		# SE ACABA LA PIEDRA, se acaba la grieta. Se corta en seco y no se busca por donde seguir: una
		# rama que rodea el obstaculo se lee como un tallo, no como una rotura.
		if not _dentro(siguiente):
			return
		# Se AFILA a lo largo: el ultimo trozo de una rama es la mitad de gordo que el primero, y
		# nunca baja de un pixel -- que es lo mas fino que existe en pixel art.
		var w: int = maxi(1, int(round(float(grosor) * (1.0 - 0.5 * float(t) / float(TRAMOS)))))
		_trazar(p, siguiente, w, clampf(nace + dura * float(t) / float(TRAMOS), 0.0, 1.0), vistos)
		p = siguiente
		# Y de aqui salen las hijas. No desde la punta: una grieta se abre POR EL CAMINO, y colgando
		# todas del final salia una escoba en vez de un arbol.
		if hondura > 0 and t >= 1 and rng.randf() < 0.55:
			var hacia: float = 1.0 if rng.randf() < 0.5 else -1.0
			# Angulo seco (35-75 grados): las hijas suaves se leen como una curva, no como una rotura.
			_rama(rng, p, ang + hacia * rng.randf_range(0.6, 1.3), maxi(1, int(grosor / 2)),
				largo * 0.55, hondura - 1, nace + dura * float(t) / float(TRAMOS), vistos)


# RASTERIZA un segmento a la rejilla del arte: Bresenham para el trazo y un pincel cuadrado de 'w'
# pixeles para el grosor. Es lo que hace que la grieta se vea DIBUJADA EN EL TILE y no pintada encima
# con un rotulador vectorial.
#
# EL MOMENTO DE CADA PIXEL SALE DE SU DISTANCIA AL FOCO, no de por que rama va. Iba por rama y era
# ambiguo: una hija corta que sale pronto podia quedar mas cerca del centro que un tronco largo, y
# entonces al cerrarse desaparecian mezclados y se leia como que la grieta se cerraba de dentro hacia
# fuera. Con la distancia no hay duda posible: al aparecer CRECE hacia fuera, y al cerrarse se retira
# desde la punta hacia el centro. Las dos cosas, con el mismo numero.
func _trazar(a: Vector2, b: Vector2, w: int, t: float, vistos: Dictionary) -> void:
	var x0: int = int(round(a.x / PIXEL))
	var y0: int = int(round(a.y / PIXEL))
	var x1: int = int(round(b.x / PIXEL))
	var y1: int = int(round(b.y / PIXEL))
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	# El pincel se centra en el trazo: con 3 px va de -1 a +1.
	var r0: int = -int(w / 2)
	var r1: int = r0 + w - 1
	var guardia: int = 0
	while guardia < 4096:
		guardia += 1
		for oy in range(r0, r1 + 1):
			for ox in range(r0, r1 + 1):
				var k := Vector2i(x0 + ox, y0 + oy)
				if vistos.has(k):
					continue
				vistos[k] = true
				# Su momento: lo lejos que esta del foco. El 't' que llega por parametro ya no decide,
				# solo empuja un poco para que una rama honda no salga antes que su madre.
				var dist: float = (Vector2(k) * PIXEL).distance_to(_foco) / _alcance
				_px_grieta.append({"p": Vector2(k) * PIXEL,
					"t": clampf(dist * 0.85 + t * 0.15, 0.0, 1.0), "w": w})
		if x0 == x1 and y0 == y1:
			return
		var e2: int = err * 2
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


# CUANTA GRIETA SE VE, de 0 a 1. Lo mueve el aviso segun se acerca el parto: la pared se va rajando
# delante de ti.
func avance(v: float) -> void:
	var nuevo: float = clampf(v, 0.0, 1.0)
	if is_equal_approx(nuevo, _avance):
		return
	_avance = nuevo
	queue_redraw()


# ------------------------------------------------------------
#  EL BOQUETE
# ------------------------------------------------------------
# YA HA SALIDO. 'con_cara' dice, celda a celda, si esa pieza se ve de frente: el juego se mira desde
# 45 grados, y la pared que tienes ENFRENTE (la del norte de una sala) enseña su cara -- ahi cabe un
# agujero de verdad --, pero la de ABAJO se ve de canto y un boquete pintado ahi se lee como una
# mancha tirada en el suelo. En esas se quedan solo las grietas.
func romper(rotas: Array, con_cara: Array, sem: int) -> void:
	_px_hueco.clear()
	_roto = true
	_cierre = 1.0
	var celdas: Dictionary = {}
	for c in rotas:
		celdas[c as Vector2i] = true
	# El centro del destrozo: hacia ahi se cierra todo, las de fuera primero.
	var centro := Vector2.ZERO
	for c in rotas:
		centro += Vector2(c as Vector2i)
	centro /= maxf(1.0, float(rotas.size()))
	var radio_max: float = 0.0
	for c in rotas:
		radio_max = maxf(radio_max, Vector2(c as Vector2i).distance_to(centro))

	for i in rotas.size():
		if i < con_cara.size() and not bool(con_cara[i]):
			continue   # esa se ve de canto: sin agujero
		var cel: Vector2i = rotas[i] as Vector2i
		var d: float = 0.0 if radio_max <= 0.001 else Vector2(cel).distance_to(centro) / radio_max
		_mancha(cel, celdas, sem, RETARDO_CELDA * (1.0 - d))
	queue_redraw()


# LA MANCHA DE UNA CELDA, rasterizada pixel a pixel. Para cada pixel de su caja se mira si cae dentro
# del contorno; el contorno se muestrea en HUECO_VERTICES angulos y se interpola, y cada pixel se
# queda con SU retardo de cierre -- de ahi que la piedra vuelva a trozos y no encogiendo la figura.
func _mancha(celda: Vector2i, rotas: Dictionary, sem: int, retardo: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(celda.x, celda.y, sem + 104729))
	# El contorno: radio y retardo por angulo.
	var radios := PackedFloat32Array()
	var rets := PackedFloat32Array()
	for i in HUECO_VERTICES:
		var ang: float = TAU * float(i) / float(HUECO_VERTICES)
		var dir := Vector2(cos(ang), sin(ang))
		# Cuanto abre por esta direccion: se miran las vecinas en X y en Y por separado y se mezclan
		# con el peso de cada eje, que es lo que suaviza el paso de una a otra.
		var ax: float = absf(dir.x)
		var ay: float = absf(dir.y)
		var abx: float = 1.0 if rotas.has(celda + Vector2i(int(signf(dir.x)), 0)) else 0.0
		var aby: float = 1.0 if rotas.has(celda + Vector2i(0, int(signf(dir.y)))) else 0.0
		var abre: float = 0.0
		if ax + ay > 0.001:
			abre = (abx * ax + aby * ay) / (ax + ay)
		var r: float = lerpf(HUECO_CONTENIDO, HUECO_ABIERTO, abre) * _lado
		# DOS MORDIDAS, una gruesa y otra fina. Con una sola el contorno salia redondeado y blando --
		# una gota, no una rotura --; la segunda, de mas frecuencia y menos amplitud, es la que astilla
		# el borde y le da el aire de piedra partida de las referencias.
		var muesca: float = rng.randf_range(-HUECO_MORDIDA, HUECO_MORDIDA) 			+ sin(ang * 5.0 + float(sem % 97)) * HUECO_ASTILLA
		radios.append(r * (1.0 + muesca))
		# El punto que da a PIEDRA SANA se cierra antes: por ahi la pared tiene de donde agarrarse
		# para rehacerse. El que da al hueco es de los ultimos. Con su pizca de azar, para que el
		# borde no avance como un frente ordenado.
		rets.append(RETARDO_PIXEL * (abre * 0.7 + rng.randf() * 0.3))

	var centro: Vector2 = Vector2(celda) * _lado + Vector2(_lado, _lado) * 0.5
	var alcance: int = int(ceil(HUECO_ABIERTO * _lado)) + 2
	var cx: int = int(round(centro.x / PIXEL))
	var cy: int = int(round(centro.y / PIXEL))
	for py in range(cy - alcance, cy + alcance + 1):
		for px in range(cx - alcance, cx + alcance + 1):
			var p := Vector2(px, py) * PIXEL
			var v: Vector2 = p - centro
			var dist: float = v.length()
			if dist < 0.001:
				_px_hueco.append({"p": p, "r": retardo, "labio": false})
				continue
			# Radio y retardo del contorno EN ESE ANGULO, interpolando entre las dos muestras vecinas.
			var a: float = fposmod(v.angle(), TAU) / TAU * float(HUECO_VERTICES)
			var i0: int = int(floor(a)) % HUECO_VERTICES
			var i1: int = (i0 + 1) % HUECO_VERTICES
			var f: float = a - floor(a)
			var borde: float = lerpf(radios[i0], radios[i1], f)
			if dist > borde:
				continue
			# EL LABIO es el anillo de fuera: dos pixeles de piedra recien partida que le dan volumen.
			var es_labio: bool = dist > borde - 2.0
			# EL RETARDO DE UN PIXEL. Un pixel sigue abierto mientras su 'r' aguante por encima de lo
			# reparado, asi que el que tiene 'r' PEQUEÑO se cierra ANTES.
			#
			# Estaba escrito al reves -- multiplicando por (dist / borde) -- y por eso el borde, que es
			# el que mas lejos esta, se llevaba el retardo mayor y era LO ULTIMO en cerrarse: el agujero
			# se cerraba de dentro hacia fuera. Va con lo CONTRARIO de la distancia: pegado al borde,
			# casi cero (la piedra entra por donde tiene de que agarrarse) y en el centro, lo maximo.
			var hacia_dentro: float = 1.0 - dist / maxf(1.0, borde)
			var ret: float = retardo + lerpf(rets[i0], rets[i1], f) * hacia_dentro
			_px_hueco.append({"p": p, "r": clampf(ret, 0.0, 0.98), "labio": es_labio})


# CUANTO QUEDA DEL BOQUETE, de 1 (recien reventado) a 0 (pared entera).
func cerrar(v: float) -> void:
	var nuevo: float = clampf(v, 0.0, 1.0)
	if is_equal_approx(nuevo, _cierre):
		return
	_cierre = nuevo
	queue_redraw()


func _draw() -> void:
	# LAS GRIETAS PRIMERO, EL HUECO ENCIMA. Iba al reves y estaba mal: el boquete es un VACIO, y una
	# grieta pintada por encima del agujero es una raya flotando en el aire. Las que caen dentro tienen
	# que quedar tapadas; solo se ven las que salen de su borde hacia fuera, que es de donde salen.
	if _avance > 0.0:
		for g in _px_grieta:
			if float(g["t"]) > _avance:
				break   # vienen ordenados: a partir de aqui no ha salido ninguno
			draw_rect(Rect2(g["p"], Vector2(PIXEL, PIXEL)),
				COL_FILO if g.get("filo", false) else COL_GRIETA, true)
	if _roto and _cierre > 0.001:
		var avance_cierre: float = 1.0 - _cierre   # _cierre va de 1 a 0; lo reparado es lo contrario
		for h in _px_hueco:
			# Un pixel esta ABIERTO mientras la reparacion no le haya llegado. Sin desvanecidos: un
			# pixel esta o no esta, que es como funciona el pixel art -- un alpha a medias delata el
			# dibujo vectorial que hay debajo.
			if float(h["r"]) < avance_cierre:
				continue
			draw_rect(Rect2(h["p"], Vector2(PIXEL, PIXEL)),
				COL_LABIO if bool(h["labio"]) else COL_HUECO, true)
