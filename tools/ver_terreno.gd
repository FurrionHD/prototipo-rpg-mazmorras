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
	for t in TerrenoSprites.TRAMOS:
		var clave: String = String(t["clave"])
		TerrenoSprites.hornear(clave)
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
		_guardar(_escena(atlas_por_tramo[clave]), "escena_%s" % clave)

	print("Listo en %.1f s. Mira los PNG en %s" % [(Time.get_ticks_msec() - t0) / 1000.0, SALIDA])
	quit()


func _guardar(img: Image, nombre: String) -> void:
	var g := img.duplicate() as Image
	g.resize(g.get_width() * ZOOM, g.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
	var ruta: String = SALIDA + nombre + ".png"
	g.save_png(ProjectSettings.globalize_path(ruta))
	print("  %-28s %dx%d" % [nombre + ".png", img.get_width(), img.get_height()])


# Un mapa de juguete: una sala con un pasillo, una mancha de musgo en la pared del fondo y un
# riachuelo que la cruza y desemboca en un charco. Es el caso que hay que saber dibujar.
func _escena(atlas: Image) -> Image:
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
			if solido[y][x]:
				var m: int = TerrenoSprites.mascara(c, func(v: Vector2i) -> bool:
					return _dentro(v) and solido[v.y][v.x])
				_baldosa(img, atlas, TerrenoSprites.celda_para("muro", c, m, SEM), c)
			else:
				_baldosa(img, atlas, TerrenoSprites.celda_para("suelo", c, 0, SEM), c)
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
