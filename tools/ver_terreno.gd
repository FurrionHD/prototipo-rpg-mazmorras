# ============================================================
#  ver_terreno.gd  --  HERRAMIENTA, no parte del juego.
#
#  Dibuja un trozo de mazmorra de mentira con TODAS las capas puestas (suelo, muro, musgo,
#  riachuelo) y los recolectables encima, y lo deja como PNG para poder MIRARLO. Los sprites no se
#  juzgan con "no ha dado error": se juzgan viendolos.
#
#  Se lanza con ver_terreno.bat. No toca nada del juego: solo escribe en tools/salida/.
# ============================================================
extends SceneTree

const SALIDA := "res://tools/salida/"
const ZOOM := 3           # el pixel-art a tamaño real no se puede juzgar en un PNG
const ANCHO := 30         # celdas del trozo de prueba
const ALTO := 18
# El lago va a MAS zoom que el resto, y no es capricho: a ZOOM 3 la junta del riachuelo con el lago
# son 96 px de una imagen de 2880 y no se puede juzgar si hay costura o no. Lo que se aprueba ahi
# es un puñado de pixeles, asi que hay que verlos.
const ZOOM_LAGO := 6
const LAGO_TAM := Vector2i(5, 4)     # = DungeonFloor.ESTANQUE_CELDAS
const SEM_LAGO := 20260905


# Dibujar un atlas cuesta lo suyo (cientos de miles de pixeles con tres octavas de ruido cada
# uno), asi que se dibuja UNA VEZ y se reparte. La primera version llamaba a generar() dentro del
# bucle que coloca los nodos -- o sea, rehacia la hoja entera de la familia por cada arbol -- y la
# herramienta se quedaba colgada varios minutos.
var _hojas: Dictionary = {}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA)
	var t0: int = Time.get_ticks_msec()

	# --- 1. Hornear (si no, el PNG de disco se queda viejo y el TileSet pide baldosas que ya no
	#        caben en el) y guardar las hojas tal cual, para ver baldosa a baldosa ---
	# UN JUEGO DE PNG POR TRAMO, no solo el de "roca". Con el tramo fijado a mano no habia forma de
	# mirar la cueva de los pisos 7+, que es justo lo que hay que juzgar cuando se dibuja un tramo
	# nuevo: si se lee como otro sitio o como el de siempre con un filtro de color encima.
	var atlas_por_tramo: Dictionary = {}
	for clave_h in TerrenoSprites.claves_a_hornear():
		TerrenoSprites.hornear(clave_h)
	for t in TerrenoSprites.TRAMOS:
		var clave: String = String(t["clave"])
		atlas_por_tramo[clave] = TerrenoSprites.generar(clave)
		_guardar(atlas_por_tramo[clave], "atlas_terreno_%s" % clave)
	for fam in RecolectableSprites.FAMILIAS:
		RecolectableSprites.hornear(String(fam))
		_hojas[fam] = RecolectableSprites.generar(String(fam))
		_guardar(_hojas[fam], "atlas_%s" % fam)
	for prop in PropSprites.PROPS:
		PropSprites.hornear(String(prop))
		_guardar(PropSprites.generar(String(prop)), "prop_%s" % prop)

	# --- 2. El trozo de mazmorra montado, uno por tramo ---
	for clave in atlas_por_tramo:
		_guardar(_escena(atlas_por_tramo[clave], TerrenoSprites.estilo_de(String(clave))),
			"escena_%s" % clave)

	# --- 2b. EL LAGO: la union con el riachuelo, y la forma con dieciseis semillas ---
	var atlas_roca: Image = atlas_por_tramo["roca"]
	_guardar(_lago_zoom(atlas_roca), "lago_zoom", ZOOM_LAGO)
	_guardar(_lago_formas(atlas_roca), "lago_formas")
	_guardar(_lago_real(atlas_roca), "lago_real", ZOOM_LAGO)
	_guardar(_frames_agua(atlas_roca), "lago_frames", 4)
	_barrer_lagos()

	# --- 3. LA TRANSICION: el mismo trozo, con la frontera entre dos tramos ---
	# Es lo que hay que MIRAR de un piso de corte: si el borde se lee como un cambio de terreno o
	# como un circulo de compas, y si el musgo y el agua lo cruzan sin cortarse en seco.
	if TerrenoSprites.TRAMOS.size() >= 2:
		_guardar(_escena_transicion(atlas_por_tramo), "escena_transicion")

	print("Listo en %.1f s. Mira los PNG en %s" % [(Time.get_ticks_msec() - t0) / 1000.0, SALIDA])
	quit()


func _guardar(img: Image, nombre: String, zoom: int = ZOOM) -> void:
	var g := img.duplicate() as Image
	g.resize(g.get_width() * zoom, g.get_height() * zoom, Image.INTERPOLATE_NEAREST)
	var ruta: String = SALIDA + nombre + ".png"
	g.save_png(ProjectSettings.globalize_path(ruta))
	print("  %-28s %dx%d" % [nombre + ".png", img.get_width(), img.get_height()])


# Un mapa de juguete: una sala con un pasillo, una mancha de musgo en la pared del fondo y un
# riachuelo que la cruza y desemboca en un charco. Es el caso que hay que saber dibujar.
func _escena(atlas: Image, estilo: String = "picada") -> Image:
	var L: int = TerrenoSprites.LADO
	var solido := []
	var agua := []
	var musgo := []
	for y in ALTO:
		solido.append([])
		agua.append([])
		musgo.append([])
		for x in ANCHO:
			# Marco de roca + un tabique interior para ver esquinas de verdad.
			var roca: bool = x < 2 or y < 2 or x >= ANCHO - 2 or y >= ALTO - 2
			if y >= 4 and y <= 9 and x >= 11 and x <= 14:
				roca = true
			solido[y].append(roca)
			agua[y].append(false)
			musgo[y].append(false)

	# COLUMNAS SUELTAS de la cueva. NO se marcan como solido: en el juego lo son (chocas y tapan la
	# luz) pero se DIBUJAN como suelo con una estalagmita encima, que es justo lo que hay que mirar
	# aqui -- pintadas de muro salian como un azulejo plano.
	var columnas := [Vector2i(19, 5), Vector2i(22, 12), Vector2i(26, 8), Vector2i(20, 13)]

	# Riachuelo: baja por una columna y se abre en un charco al final.
	for y in range(2, ALTO - 2):
		if not solido[y][7]:
			agua[y][7] = true
	for y in range(ALTO - 7, ALTO - 2):
		for x in range(5, 11):
			if not solido[y][x]:
				agua[y][x] = true

	# Musgo: en la roca del tabique y en el marco de arriba, o sea pegado a la humedad.
	for y in ALTO:
		for x in ANCHO:
			if not solido[y][x]:
				continue
			if (x >= 10 and x <= 15 and y >= 3 and y <= 10) or (y < 2 and x > 16 and x < 26):
				musgo[y][x] = true

	var img := Image.create(ANCHO * L, ALTO * L, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.03, 0.03, 0.04))

	# --- suelo, muro, musgo, agua: en ese orden, que es el de los TileMapLayer del juego ---
	const SEM := 20260824
	for y in ALTO:
		for x in ANCHO:
			var c := Vector2i(x, y)
			# En la cueva, SUELO TAMBIEN DEBAJO DEL MURO: su borde ondula y no llena la celda, asi
			# que si no, por los huecos se ve el fondo. Es lo mismo que hace el juego (ver
			# DungeonFloor._construir_geometria), y si aqui no se replicara, el render enseñaria
			# unos agujeros negros que en la partida no existen.
			if not solido[y][x] or estilo == "cueva":
				_baldosa(img, atlas, TerrenoSprites.celda_para("suelo", c, 0, SEM), c)
			if solido[y][x]:
				var m: int = TerrenoSprites.mascara(c, func(v: Vector2i) -> bool:
					return _dentro(v) and solido[v.y][v.x])
				_baldosa(img, atlas, TerrenoSprites.celda_para("muro", c, m, SEM), c)
	for y in ALTO:
		for x in ANCHO:
			var c := Vector2i(x, y)
			if musgo[y][x]:
				var m: int = TerrenoSprites.mascara(c, func(v: Vector2i) -> bool:
					return _dentro(v) and musgo[v.y][v.x])
				_baldosa(img, atlas, TerrenoSprites.celda_para("musgo", c, m, SEM), c)
			if agua[y][x]:
				var m2: int = TerrenoSprites.mascara(c, func(v: Vector2i) -> bool:
					return _dentro(v) and agua[v.y][v.x])
				_baldosa(img, atlas, TerrenoSprites.celda_para("agua", c, m2, SEM), c)
	# Las columnas, encima del suelo (su capa va despues en CAPAS_ORDEN).
	for col in columnas:
		_baldosa(img, atlas, TerrenoSprites.celda_para("columna", col, 0, SEM), col)
	# El sumidero: donde muere el riachuelo si no hay lago. Aqui se pone a mano para verlo.
	_baldosa(img, atlas, TerrenoSprites.celda_para("sumidero", Vector2i(7, 3), 0, SEM),
		Vector2i(24, 4))

	# --- recolectables: uno de cada familia y de cada modelo, en fila sobre el suelo ---
	var fx: int = 17
	var fy: int = 13
	for fam in RecolectableSprites.FAMILIAS:
		for f in RecolectableSprites.formas_de(String(fam)):
			for m in RecolectableSprites.MODELOS:
				_nodo(img, String(fam), f, m, Vector2i(fx, fy))
				fx += 1
				if fx >= ANCHO - 2:
					fx = 17
					fy -= 4
	return img


func _dentro(v: Vector2i) -> bool:
	return v.x >= 0 and v.y >= 0 and v.x < ANCHO and v.y < ALTO


func _baldosa(img: Image, atlas: Image, celda: Vector2i, en: Vector2i) -> void:
	var L: int = TerrenoSprites.LADO
	img.blend_rect(atlas, Rect2i(celda * L, Vector2i(L, L)), en * L)


# El nodo se apoya con el PIE en la celda y centrado, que es como lo coloca resource_node.
func _nodo(img: Image, familia: String, forma: int, modelo: int, celda: Vector2i) -> void:
	var L: int = TerrenoSprites.LADO
	var t: Vector2i = RecolectableSprites.lienzo(familia)
	var hoja: Image = _hojas[familia]
	var col: int = RecolectableSprites._columna(familia, forma, modelo)
	var en := Vector2i(celda.x * L + L / 2 - t.x / 2, celda.y * L + L - t.y)
	# cuerpo
	img.blend_rect(hoja, Rect2i(Vector2i(col * t.x, 0), t), en)
	# tinte, modulado a mano con un color de material cualquiera para ver que el tinte funciona
	var tint := Color.from_hsv(fmod(float(modelo) * 0.17 + float(hash(familia) % 100) * 0.01, 1.0),
		0.65, 0.95)
	var capa: Image = hoja.get_region(Rect2i(Vector2i(col * t.x, t.y), t))
	for y in t.y:
		for x in t.x:
			var c: Color = capa.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			capa.set_pixel(x, y, Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a))
	img.blend_rect(capa, Rect2i(Vector2i.ZERO, t), en)


# ============================================================
#  EL LAGO
# ============================================================
# Las dos preguntas del lago son distintas y por eso son dos PNG:
#   lago_zoom    -> ¿se ve la junta con el riachuelo? Se contesta con UN lago muy de cerca.
#   lago_formas  -> ¿la forma es organica o siempre la misma elipse? Se contesta con DIECISEIS.
#
# Los dos llaman a Decorado.forma_lago, o sea al generador DE VERDAD. Un visor que dibujara la
# forma por su cuenta no verificaria nada: enseñaria un lago bonito calculado por el visor mientras
# el juego pinta otro.

# Un lago con su riachuelo cayendo dentro, recortado justo alrededor de la junta.
func _lago_zoom(atlas: Image) -> Image:
	var w: int = 13
	var h: int = 11
	var centro := Vector2i(6, 7)
	var suelo := func(_c: Vector2i) -> bool: return true
	var lago: Dictionary = Decorado.forma_lago(centro, LAGO_TAM, SEM_LAGO, suelo)
	# El riachuelo: baja recto desde arriba hasta que se mete en el lago. La junta queda en medio
	# del encuadre, que es lo unico que este PNG viene a enseñar.
	var rio: Dictionary = {}
	for y in range(0, h):
		var c := Vector2i(centro.x, y)
		if lago.has(c):
			break
		rio[c] = true
	return _pintar_agua_suelta(atlas, w, h, lago, Decorado.nucleo_lago(lago), rio)


# Dieciseis semillas seguidas, en rejilla de 4x4. Un lago bonito no demuestra nada.
func _lago_formas(atlas: Image) -> Image:
	var celda_w: int = LAGO_TAM.x + 4
	var celda_h: int = LAGO_TAM.y + 4
	var L: int = TerrenoSprites.LADO
	var img := Image.create(celda_w * 4 * L, celda_h * 4 * L, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.03, 0.03, 0.04))
	var suelo := func(_c: Vector2i) -> bool: return true
	for i in 16:
		var centro := Vector2i(celda_w / 2, celda_h / 2)
		var lago: Dictionary = Decorado.forma_lago(centro, LAGO_TAM, SEM_LAGO + i, suelo)
		var trozo: Image = _pintar_agua_suelta(atlas, celda_w, celda_h, lago,
			Decorado.nucleo_lago(lago))
		img.blend_rect(trozo, Rect2i(Vector2i.ZERO, trozo.get_size()),
			Vector2i((i % 4) * celda_w * L, (i / 4) * celda_h * L))
	return img


# Suelo + agua + hondo, sin muros: aqui lo que se juzga es la lamina de agua, y un marco de roca
# alrededor solo robaria sitio.
func _pintar_agua_suelta(atlas: Image, w: int, h: int, lago: Dictionary,
		hondo: Dictionary, rio: Dictionary = {}) -> Image:
	var L: int = TerrenoSprites.LADO
	var img := Image.create(w * L, h * L, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.03, 0.03, 0.04))
	for y in h:
		for x in w:
			_baldosa(img, atlas, TerrenoSprites.celda_para("suelo", Vector2i(x, y), 0, SEM_LAGO),
				Vector2i(x, y))
	# El riachuelo va en la capa "agua" (corre) y el lago en la capa "lago" (esta en calma), pero
	# LAS DOS MASCARAS SE CALCULAN CONTRA LA UNION, que es como lo hace el juego. Eso es lo que
	# borra la junta: en la celda donde el rio toca el lago ninguna de las dos pone bit, asi que no
	# se dibuja ni orilla ni espuma en medio del agua.
	var lamina: Dictionary = lago.duplicate()
	for c in rio:
		lamina[c] = true
	var union := func(v: Vector2i) -> bool: return lamina.has(v)
	for c in rio:
		_baldosa(img, atlas, TerrenoSprites.celda_para("agua", c,
			TerrenoSprites.mascara(c, union), SEM_LAGO), c)
	for c in lago:
		_baldosa(img, atlas, TerrenoSprites.celda_para("lago", c,
			TerrenoSprites.mascara(c, union), SEM_LAGO), c)
	for c in hondo:
		var m2: int = TerrenoSprites.mascara(c, func(v: Vector2i) -> bool: return hondo.has(v))
		_baldosa(img, atlas, TerrenoSprites.celda_para("hondo", c, m2, SEM_LAGO), c)
	return img


# ¿ESTA EL LAGO EN CALMA? Un PNG es una foto, y el movimiento no sale en una foto: hay que poner
# los CUATRO FRAMES uno al lado del otro y mirarlos como una tira.
#
# Arriba el riachuelo, abajo el lago, un parche de 3x3 celdas de agua sin orilla para que solo se
# vea la textura. Lo que hay que leer:
#   RIACHUELO -> el dibujo BAJA. Del primer frame al ultimo ha recorrido una baldosa entera, y por
#                eso el ciclo cierra sin tiron.
#   LAGO      -> el dibujo se queda DONDE ESTA. Cambia (cabrillea), pero no va a ninguna parte, y
#                el cuarto frame vuelve a parecerse al primero.
# Ademas imprime cuanto se mueve cada uno en pixeles: si el numero del lago no es mucho menor que
# el del riachuelo, la calma no esta funcionando por mucho que la foto parezca bien.
func _frames_agua(atlas: Image) -> Image:
	var L: int = TerrenoSprites.LADO
	var n: int = 3
	var img := Image.create(L * n * TerrenoSprites.frames_de("agua"), L * n * 2, false,
		Image.FORMAT_RGBA8)
	img.fill(Color(0.03, 0.03, 0.04))
	var capas := ["agua", "lago"]
	for fila in capas.size():
		var capa: String = capas[fila]
		for f in TerrenoSprites.frames_de(capa):
			for y in n:
				for x in n:
					var c := Vector2i(x, y)
					# Mascara 0 = agua rodeada de agua, o sea sin orilla: aqui se juzga la TEXTURA,
					# y una espuma en el borde solo distraeria.
					var base: Vector2i = TerrenoSprites.celda_para(capa, c, 0, SEM_LAGO)
					img.blend_rect(atlas, Rect2i((base + Vector2i(f, 0)) * L, Vector2i(L, L)),
						Vector2i((f * n + x) * L, (fila * n + y) * L))
		print("  %-5s se mueve %.1f px entre el primer frame y el ultimo" %
			[capa, _recorrido(atlas, capa)])
	return img


# Cuanto se ha desplazado la textura del primer al ultimo frame, medido de verdad: se prueban todos
# los corrimientos verticales y se dice cual es el que mejor casa. Es el numero que separa "corre"
# de "esta quieta", y no la impresion de mirar dos PNG parecidos.
func _recorrido(atlas: Image, capa: String) -> float:
	var L: int = TerrenoSprites.LADO
	var base: Vector2i = TerrenoSprites.celda_para(capa, Vector2i.ZERO, 0, SEM_LAGO)
	var f0: Image = atlas.get_region(Rect2i(base * L, Vector2i(L, L)))
	var ult: int = TerrenoSprites.frames_de(capa) - 1
	var fn: Image = atlas.get_region(Rect2i((base + Vector2i(ult, 0)) * L, Vector2i(L, L)))
	var mejor: float = 0.0
	var mejor_d: float = INF
	for dy in range(0, L):
		var e: float = 0.0
		for y in L:
			for x in L:
				e += absf(f0.get_pixel(x, (y + dy) % L).r - fn.get_pixel(x, y).r)
		if e < mejor_d:
			mejor_d = e
			mejor = float(dy)
	# El desplazamiento es circular: 30 px hacia abajo son 2 hacia arriba.
	return minf(mejor, float(L) - mejor)


# UN PISO DE VERDAD. Los dos PNG de arriba dibujan el lago sobre un mapa de juguete: contestan como
# es la forma, pero no si el generador y el decorado se entienden. Este monta un DungeonGenerator
# real, le pasa el Decorado entero (lago + riachuelo + musgo) y recorta la sala del charco.
#
# Es lo que caza los fallos de INTEGRACION, que son de otra familia que los de dibujo: un lago
# metido en la roca, un riachuelo que no llega, una orilla comida por la pared. Ninguno de esos se
# ve en un mapa de juguete donde todo es suelo.
func _lago_real(atlas: Image) -> Image:
	var gen := DungeonGenerator.new()
	# Un piso del tamaño del 1, con su semilla. Si algun dia cambian los parametros del piso 1, este
	# visor seguira siendo representativo mientras sean del mismo orden.
	gen.generar(72, 52, SEM_LAGO, 14, Vector2i(8, 6), Vector2i(18, 12), 3)
	# La sala del charco: la primera que admita el estanque con su anillo de orilla, que es la misma
	# regla que usa DungeonFloor._elegir_estanque.
	var centro := Vector2i.MAX
	for sala in gen.salas:
		if sala.size.x >= LAGO_TAM.x + 4 and sala.size.y >= LAGO_TAM.y + 4:
			centro = sala.get_center()
			break
	if centro == Vector2i.MAX:
		print("  AVISO: el piso de prueba no tiene ninguna sala donde quepa el charco")
		return Image.create(8, 8, false, Image.FORMAT_RGBA8)

	var d := Decorado.new()
	d.generar(gen, centro, LAGO_TAM, SEM_LAGO, false)
	if d.lago.is_empty():
		print("  AVISO: el piso de prueba no ha generado lago")
	# Recorte alrededor del charco, con sitio para ver por donde le entra el riachuelo.
	var caja := Rect2i(centro - Vector2i(9, 8), Vector2i(19, 17))
	var L: int = TerrenoSprites.LADO
	var img := Image.create(caja.size.x * L, caja.size.y * L, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.03, 0.03, 0.04))
	for y in range(caja.position.y, caja.end.y):
		for x in range(caja.position.x, caja.end.x):
			var c := Vector2i(x, y)
			var en: Vector2i = c - caja.position
			if gen.es_suelo(c):
				_baldosa(img, atlas, TerrenoSprites.celda_para("suelo", c, 0, SEM_LAGO), en)
			elif Decorado.muro_visible(gen, c):
				var mm: int = TerrenoSprites.mascara(c, func(v: Vector2i) -> bool:
					return Decorado.es_roca(gen, v))
				_baldosa(img, atlas, TerrenoSprites.celda_para("muro", c, mm, SEM_LAGO), en)
	# Musgo, agua y hondo, en el orden de los TileMapLayer del juego.
	var lamina: Dictionary = d.agua.duplicate()
	for c in d.lago:
		lamina[c] = true
	for capa in [["musgo", d.musgo, d.musgo], ["agua", d.agua, lamina],
			["lago", d.lago, lamina], ["hondo", d.lago_hondo, d.lago_hondo]]:
		var celdas: Dictionary = capa[1]
		var vecinas: Dictionary = capa[2]
		for c in celdas:
			if not caja.has_point(c):
				continue
			var m: int = TerrenoSprites.mascara(c, func(v: Vector2i) -> bool: return vecinas.has(v))
			_baldosa(img, atlas, TerrenoSprites.celda_para(String(capa[0]), c, m, SEM_LAGO),
				c - caja.position)
	return img


# EL BARRIDO. Va ADEMAS del PNG y no en su lugar: el ojo aprueba como se ve, esto comprueba que no
# haya una semilla entre quinientas que saque un lago partido en dos o del doble de tamaño. Las dos
# cosas hacen falta -- un numero verde no dice si el lago es feo, y un PNG bonito no dice si la
# semilla 337 revienta.
func _barrer_lagos() -> void:
	var diana: int = LAGO_TAM.x * LAGO_TAM.y
	var fallos: int = 0
	var area_min: int = 9999
	var area_max: int = 0
	var suelo := func(_c: Vector2i) -> bool: return true
	for i in 500:
		var centro := Vector2i(20, 20)
		var lago: Dictionary = Decorado.forma_lago(centro, LAGO_TAM, SEM_LAGO + i, suelo)
		var area: int = lago.size()
		area_min = mini(area_min, area)
		area_max = maxi(area_max, area)
		if absi(area - diana) > Decorado.LAGO_TOLERANCIA:
			print("  FALLO semilla %d: area %d (diana %d)" % [SEM_LAGO + i, area, diana])
			fallos += 1
		if _componentes(lago) != 1:
			print("  FALLO semilla %d: el lago sale en %d trozos" % [SEM_LAGO + i,
				_componentes(lago)])
			fallos += 1
		if Decorado.nucleo_lago(lago).is_empty():
			print("  FALLO semilla %d: lago sin corazon (ni una celda rodeada de agua)" %
				[SEM_LAGO + i])
			fallos += 1
	print("  lagos: 500 semillas, area %d-%d (diana %d), %d fallos" %
		[area_min, area_max, diana, fallos])


func _componentes(celdas: Dictionary) -> int:
	var visto: Dictionary = {}
	var n: int = 0
	for inicio in celdas:
		if visto.has(inicio):
			continue
		n += 1
		var cola: Array[Vector2i] = [inicio]
		visto[inicio] = true
		var cabeza: int = 0
		while cabeza < cola.size():
			var c: Vector2i = cola[cabeza]
			cabeza += 1
			for l in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var v: Vector2i = c + l
				if celdas.has(v) and not visto.has(v):
					visto[v] = true
					cola.append(v)
	return n


# ============================================================
#  LA FRONTERA ENTRE DOS TRAMOS
# ============================================================
# El mismo mapa de juguete, pintado con DOS atlas: dentro de la burbuja de entrada, el del tramo
# viejo; fuera, el del nuevo. En el juego eso lo hace un TileSet con una fuente por tramo
# (TerrenoSprites.tileset_de_tramos); aqui, como se compone a mano sobre una Image, es literalmente
# elegir de que atlas se copia cada baldosa. La REGLA de que celda es de quien es la misma:
# Transicion.es_nuevo.
func _escena_transicion(atlas_por_tramo: Dictionary) -> Image:
	var piso: int = int(TerrenoSprites.TRAMOS[1]["desde"])
	# Un atlas por ESCALON de la transicion, en el mismo orden que las fuentes del TileSet en el
	# juego: asi el render usa exactamente el mismo reparto que la partida.
	var por_escalon: Array = []
	for clave in TerrenoSprites.tramos_de(piso):
		por_escalon.append(TerrenoSprites.generar(clave))

	# Un generador de mentira con una sola "sala" cuyo centro es el ancla, para poder usar la
	# Transicion de verdad y no una copia de su cuenta.
	var gen := DungeonGenerator.new()
	gen.ancho = ANCHO
	gen.alto = ALTO
	gen.salas = [Rect2i(9, 6, 6, 6)] as Array[Rect2i]
	var tr := Transicion.new()
	tr.preparar(piso, gen, 20260907)

	var L: int = TerrenoSprites.LADO
	var img := Image.create(ANCHO * L, ALTO * L, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.03, 0.03, 0.04))
	const SEM := 20260824
	for y in ALTO:
		for x in ANCHO:
			var c := Vector2i(x, y)
			var atlas: Image = por_escalon[clampi(tr.fuente(c), 0, por_escalon.size() - 1)]
			var roca: bool = x < 2 or y < 2 or x >= ANCHO - 2 or y >= ALTO - 2
			_baldosa(img, atlas, TerrenoSprites.celda_para("suelo", c, 0, SEM), c)
			if roca:
				var m: int = TerrenoSprites.mascara(c, func(v: Vector2i) -> bool:
					return not (v.x >= 2 and v.y >= 2 and v.x < ANCHO - 2 and v.y < ALTO - 2))
				_baldosa(img, atlas, TerrenoSprites.celda_para("muro", c, m, SEM), c)
	return img
