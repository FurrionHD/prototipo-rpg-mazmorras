# ============================================================
#  pueblo_terreno.gd  (class_name PuebloTerreno)
#  Las BALDOSAS DEL PUEBLO: hierba, calle de adoquin, madera del muelle, las patas que se hunden en el
#  agua, la muralla y el agua en calma.
#
#  POR QUE UN ATLAS APARTE Y NO CAPAS NUEVAS EN TerrenoSprites. Aquel atlas lo reparte _plano() para
#  TODAS sus capas y se hornea una vez por tramo de la mazmorra (y por cada escalon de mezcla): meter
#  aqui cinco capas de pueblo haria crecer esos cinco atlas con baldosas que la mazmorra no usa nunca,
#  y obligaria a rehornearlos todos. Lo que SI se comparte son los pintores y el ruido
#  (TerrenoSprites._campo, _pintar_agua, _pintar_muro...): el agua del pueblo es la misma agua en
#  calma que el lago de la mazmorra, solo que a la luz del dia.
#
#  Misma gramatica que TerrenoSprites: capas BASE (tapiz sin bordes) y MASCARA (autotile de 16 casos,
#  1 N / 2 E / 4 S / 8 O = por ese lado NO soy yo) y el tapiz de 'bloque' baldosas para que no se vea
#  la cuadricula.
# ============================================================

extends RefCounted
class_name PuebloTerreno

const CARPETA := "res://assets/sprites/pueblo/"
const PNG := CARPETA + "terreno_pueblo.png"

const LADO := TerrenoSprites.LADO
const COLS := 8

enum Clase { BASE, MASCARA }

# El ORDEN es tambien el orden de pintado (un TileMapLayer por capa, en este orden): el agua va sobre
# la hierba de la orilla, las patas sobre el agua y la madera encima de todo lo de abajo.
const CAPAS_ORDEN := ["hierba", "calle", "agua", "pilote", "madera", "muralla"]

const CAPAS := {
	"hierba": {"clase": Clase.BASE, "bloque": 4, "frames": 1},
	# La calle se pinta ENCIMA de la hierba y su borde es un bordillo: por eso lleva mascara.
	"calle": {"clase": Clase.MASCARA, "bloque": 4, "frames": 1},
	# El agua a bloque 2 y cuatro frames, como el lago de la mazmorra (ver TerrenoSprites.CAPAS).
	"agua": {"clase": Clase.MASCARA, "bloque": 2, "frames": 4},
	# LAS PATAS del muelle. Van en la casilla de agua que hay DEBAJO de la madera, y su mascara es la
	# de la madera de encima: asi saben si esa casilla es una esquina (pata en el canto) o el medio.
	"pilote": {"clase": Clase.MASCARA, "bloque": 1, "frames": 1},
	"madera": {"clase": Clase.MASCARA, "bloque": 2, "frames": 1},
	"muralla": {"clase": Clase.MASCARA, "bloque": 4, "frames": 1},
}

# Rampas de 5 tonos, de oscuro a claro. Es DE DIA: todo va bastante mas claro que la mazmorra, que se
# juega a oscuras. Si el pueblo usara aquellas rampas se veria de noche.
const PALETA := {
	"hierba": [
		Color(0.19, 0.31, 0.15), Color(0.25, 0.39, 0.18), Color(0.31, 0.47, 0.21),
		Color(0.38, 0.54, 0.25), Color(0.47, 0.62, 0.30),
	],
	"calle": [
		Color(0.24, 0.23, 0.23), Color(0.39, 0.37, 0.35), Color(0.49, 0.47, 0.44),
		Color(0.59, 0.57, 0.53), Color(0.70, 0.68, 0.63),
	],
	"agua": [
		Color(0.09, 0.23, 0.35), Color(0.12, 0.30, 0.43), Color(0.16, 0.38, 0.51),
		Color(0.23, 0.47, 0.59), Color(0.35, 0.58, 0.68),
	],
	"madera": [
		Color(0.24, 0.15, 0.09), Color(0.36, 0.24, 0.14), Color(0.46, 0.32, 0.19),
		Color(0.55, 0.40, 0.25), Color(0.65, 0.49, 0.32),
	],
	"muralla": [
		Color(0.25, 0.24, 0.24), Color(0.36, 0.35, 0.34), Color(0.46, 0.45, 0.43),
		Color(0.56, 0.55, 0.52), Color(0.66, 0.65, 0.61),
	],
}
const PALETA_PILOTE := "madera"

static func frames_de(capa: String) -> int:
	return int((CAPAS[capa] as Dictionary)["frames"])


static func bloque_de(capa: String) -> int:
	return int((CAPAS[capa] as Dictionary)["bloque"])


static func variantes_de(capa: String) -> int:
	var b: int = bloque_de(capa)
	return b * b


static func _cuantas(capa: String) -> int:
	var v: int = variantes_de(capa)
	return v if int((CAPAS[capa] as Dictionary)["clase"]) == Clase.BASE else 16 * v


static func _rampa(capa: String) -> Array:
	return PALETA.get(PALETA_PILOTE if capa == "pilote" else capa, PALETA["hierba"]) as Array


# ============================================================
#  REPARTO DEL ATLAS (el mismo algoritmo que TerrenoSprites._plano, con SUS capas)
# ============================================================
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
		col = 0
		fila += 1
	_plano_cache = {"filas": fila, "celdas": celdas}
	return _plano_cache


static func celda_de(capa: String, i: int) -> Vector2i:
	return (_plano()["celdas"][capa] as Dictionary)[posmod(i, _cuantas(capa))]


# La baldosa que toca a una casilla del mapa: el trozo del tapiz sale de la POSICION (ver la nota de
# 'bloque' en TerrenoSprites), asi que dos vecinas casan y el invitado ve lo mismo que el host.
static func celda_para(capa: String, c: Vector2i, mask: int) -> Vector2i:
	var b: int = bloque_de(capa)
	var v: int = posmod(c.y, b) * b + posmod(c.x, b)
	var nv: int = variantes_de(capa)
	var i: int = v if int((CAPAS[capa] as Dictionary)["clase"]) == Clase.BASE else posmod(mask, 16) * nv + v
	return celda_de(capa, i)


# ============================================================
#  PINTORES
# ============================================================
static func _px(d: PackedByteArray, W: int, x: int, y: int, c: Color) -> void:
	TerrenoSprites._poner(d, W, x, y, c)


# HIERBA: el tapiz de fondo. Manchas suaves de tono (sin ellas es un tapete) y briznas: trazos
# verticales de dos o tres pixeles, mas claros por arriba, que son lo que la lee como hierba y no
# como musgo. Y alguna flor suelta, muy pocas: el pueblo no es un prado.
static func _pintar_hierba(d: PackedByteArray, W: int, o: Vector2i, rampa: Array, sem: int,
		ox: float, oy: float, bl: int) -> void:
	var mancha: PackedFloat32Array = TerrenoSprites._campo(3, sem, ox, oy, 1.0, bl)
	var grano: PackedFloat32Array = TerrenoSprites._campo(16, sem + 31, ox, oy, 1.0, bl)
	var brizna: PackedFloat32Array = TerrenoSprites._campo(16, sem + 97, ox, oy, 1.0, bl)
	var flor: PackedFloat32Array = TerrenoSprites._campo(16, sem + 211, ox, oy, 1.0, bl)
	var flores := [Color(0.93, 0.88, 0.55), Color(0.90, 0.92, 0.95), Color(0.80, 0.55, 0.75)]
	for y in LADO:
		for x in LADO:
			var i: int = y * LADO + x
			var v: float = 0.30 + mancha[i] * 0.35 + (grano[i] - 0.5) * 0.18
			# La brizna: el pixel de ENCIMA de una punta clara sale claro tambien, y el de debajo
			# oscuro. Se lee el ruido de la fila de abajo para que el trazo sea vertical.
			var abajo: int = mini(y + 1, LADO - 1) * LADO + x
			if brizna[i] > 0.80:
				v += 0.28
			elif brizna[abajo] > 0.80:
				v += 0.14
			elif y > 0 and brizna[(y - 1) * LADO + x] > 0.80:
				v -= 0.16
			var col: Color = TerrenoSprites._escalon(clampf(v, 0.0, 0.999), rampa)
			if flor[i] > 0.965:
				col = flores[int(flor[i] * 1000.0) % flores.size()]
			_px(d, W, o.x + x, o.y + y, col)


# CALLE: adoquines. Es un Voronoi PERIODICO sobre el tapiz entero (bl x bl baldosas): cada pixel
# mira de que piedra es y a que distancia esta de la junta. Se calcula UNA vez para el tapiz y cada
# baldosa solo lee su ventana, porque hacerlo por baldosa y por mascara serian dieciseis veces el
# mismo trabajo.
const ADOQUIN_CELDAS := 12      # piedras por lado del tapiz (128 px / 12 = ~10,7 px la piedra)
const BORDILLO := 4             # px del bordillo donde la calle acaba en hierba

static var _adoquin: Dictionary = {}

static func _tapiz_adoquin(sem: int, bl: int) -> Dictionary:
	var clave: int = sem * 31 + bl
	if _adoquin.has(clave):
		return _adoquin[clave]
	var lado: int = LADO * bl
	var n: int = ADOQUIN_CELDAS
	var paso: float = float(lado) / float(n)
	var pts := PackedVector2Array()
	pts.resize(n * n)
	for j in n:
		for i in n:
			var h: int = i * 374761393 + j * 668265263 + sem * 1013904223
			h = (h ^ (h >> 13)) * 1274126177
			var a: float = float((h ^ (h >> 16)) & 0xFFFF) / 65535.0
			var b: float = float(((h >> 8) ^ (h >> 20)) & 0xFFFF) / 65535.0
			# Hileras un poco desplazadas en x: los adoquines se ponen a matajunta.
			var desfase: float = 0.5 if (j % 2) == 1 else 0.0
			pts[j * n + i] = Vector2((float(i) + desfase + 0.25 + a * 0.5) * paso,
				(float(j) + 0.3 + b * 0.4) * paso)
	var id := PackedInt32Array()
	var junta := PackedFloat32Array()
	id.resize(lado * lado)
	junta.resize(lado * lado)
	for y in lado:
		var cj: int = int(float(y) / paso)
		for x in lado:
			var ci: int = int(float(x) / paso)
			var d1: float = 1e9
			var d2: float = 1e9
			var mejor: int = 0
			for dj in range(-1, 2):
				for di in range(-2, 2):
					var ii: int = ci + di
					var jj: int = cj + dj
					var p: Vector2 = pts[posmod(jj, n) * n + posmod(ii, n)]
					# Periodico: el punto se traslada al "cuadro" que toca.
					p.x += float(floori(float(ii) / float(n)) * lado)
					p.y += float(floori(float(jj) / float(n)) * lado)
					var dd: float = Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(p)
					if dd < d1:
						d2 = d1
						d1 = dd
						mejor = posmod(jj, n) * n + posmod(ii, n)
					elif dd < d2:
						d2 = dd
			id[y * lado + x] = mejor
			junta[y * lado + x] = d2 - d1
	var out := {"id": id, "junta": junta, "lado": lado}
	_adoquin[clave] = out
	return out


static func _pintar_calle(d: PackedByteArray, W: int, o: Vector2i, rampa: Array, mask: int,
		sem: int, ox: float, oy: float, bl: int) -> void:
	var t: Dictionary = _tapiz_adoquin(sem, bl)
	var ids: PackedInt32Array = t["id"]
	var jun: PackedFloat32Array = t["junta"]
	var lado: int = int(t["lado"])
	var grano: PackedFloat32Array = TerrenoSprites._campo(16, sem + 5, ox, oy, 1.0, bl)
	var negro := Color(0.10, 0.10, 0.10)
	for y in LADO:
		for x in LADO:
			var i: int = y * LADO + x
			var ti: int = (int(oy) + y) % lado * lado + (int(ox) + x) % lado
			var borde: float = TerrenoSprites._dentro(x, y, mask)
			var col: Color
			if borde < 1.0:
				col = negro                              # el canto donde empieza la hierba
			elif borde < float(BORDILLO):
				# BORDILLO: piedras alargadas a lo largo del canto, un tono mas claras que la calle.
				# La junta entre piedras del bordillo corta el canto cada 12 px, se mire por donde se mire.
				var gx: int = int(ox) + x
				var gy: int = int(oy) + y
				var en_horizontal: bool = (((mask & 1) != 0 and y < BORDILLO) or ((mask & 4) != 0 and y >= LADO - BORDILLO))
				var a_lo_largo: int = gx if en_horizontal else gy
				col = rampa[1] if a_lo_largo % 12 == 0 else rampa[3]
				if borde >= float(BORDILLO) - 1.0:
					col = rampa[1]
			else:
				var h: int = absi(ids[ti] * 2654435761) % 1000
				var tono: float = 0.35 + float(h) / 1000.0 * 0.40 + (grano[i] - 0.5) * 0.14
				var j: float = jun[ti]
				if j < 1.1:
					col = rampa[0] if j < 0.6 else rampa[1]   # la junta, hundida
				else:
					# Cada adoquin con un poco de relieve: mas claro hacia su junta de arriba-izquierda.
					col = TerrenoSprites._escalon(clampf(tono + (0.08 if j < 2.2 else 0.0), 0.0, 0.999), rampa)
			_px(d, W, o.x + x, o.y + y, col)


# MADERA: tablones que cruzan el muelle de lado a lado (el muelle va de norte a sur). Cada tablon con
# su tono y sus clavos en los extremos. El canto SUR que da al agua lleva la cara de la viga: es el
# grosor de la plataforma, lo que la separa del agua y dice que esta levantada.
const TABLON := 6
const VIGA := 9

static func _pintar_madera(d: PackedByteArray, W: int, o: Vector2i, rampa: Array, mask: int,
		sem: int, ox: float, oy: float, bl: int) -> void:
	var veta: PackedFloat32Array = TerrenoSprites._campo(12, sem + 13, ox, oy, 0.35, bl)
	var negro := Color(0.08, 0.05, 0.03)
	var s: bool = (mask & 4) != 0
	for y in LADO:
		for x in LADO:
			var i: int = y * LADO + x
			var gy: int = int(oy) + y
			var gx: int = int(ox) + x
			var col: Color
			if s and y >= LADO - VIGA:
				# LA CARA DE LA VIGA, en sombra (mira al sur pero esta debajo del borde del tablero).
				var tv: float = float(y - (LADO - VIGA)) / float(VIGA)
				col = rampa[1] if tv < 0.5 else rampa[0]
				if y == LADO - VIGA:
					col = rampa[3]                          # el canto del tablero, que coge luz
			else:
				var fila: int = gy / TABLON
				# El tablon se corta cada 'largo' px, y la junta cambia de sitio en cada hilera.
				var largo: int = 40
				var desfase: int = (fila * 17) % largo
				var junta_v: bool = (gx + desfase) % largo == 0
				var h: int = (fila * 92821 + ((gx + desfase) / largo) * 68917 + sem) % 1000
				var v: float = 0.35 + float(absi(h)) / 1000.0 * 0.35 + (veta[i] - 0.5) * 0.30
				if gy % TABLON == 0:
					v = 0.05                                 # la rendija entre tablones
				elif junta_v:
					v = 0.12
				elif (gx + desfase) % largo == 2 and gy % TABLON == 2:
					v = 0.95                                 # el clavo
				col = TerrenoSprites._escalon(clampf(v, 0.0, 0.999), rampa)
			if ((mask & 8) != 0 and x == 0) or ((mask & 2) != 0 and x == LADO - 1) \
					or ((mask & 1) != 0 and y == 0) or (s and y == LADO - 1):
				col = negro
			_px(d, W, o.x + x, o.y + y, col)


# LAS PATAS. Se dibujan en la casilla de agua de DEBAJO del canto sur de la madera, sobre el agua ya
# pintada. Lo que pidio el usuario: segun bajan hacia el fondo se DEFORMAN (la refraccion las
# ondula) y se vuelven TRANSPARENTES, hasta fundirse con el agua y dejar de verse.
#
# Pata en cada canto expuesto de la madera de encima (esquinas) y una en medio de cada casilla. Y
# pegada al tablero, una franja de sombra: la plataforma tapa la luz del agua que tiene justo debajo.
# Medido en la captura: a 4 px de ancho, 26 de hondo y alfa (1-t)^1.6 la pata se veia de DOS pixeles
# y parecia un rasguño en el agua. Tiene que leerse como un poste que entra en el agua.
const PATA_ANCHO := 6
const PATA_HONDO := 30.0

static func _pintar_pilote(d: PackedByteArray, W: int, o: Vector2i, rampa: Array, mask: int) -> void:
	var xs: Array = [LADO / 2 - PATA_ANCHO / 2]
	if (mask & 8) != 0:
		xs.append(1)
	if (mask & 2) != 0:
		xs.append(LADO - 1 - PATA_ANCHO)
	for y in LADO:
		for x in LADO:
			_px(d, W, o.x + x, o.y + y, Color(0, 0, 0, 0))
	for y in LADO:
		# La sombra del tablero sobre el agua.
		if y < 9:
			for x in LADO:
				_px(d, W, o.x + x, o.y + y, Color(0.02, 0.06, 0.10, 0.50 * (1.0 - float(y) / 9.0)))
		var t: float = float(y) / PATA_HONDO
		if t >= 1.0:
			continue
		# Arriba, fuera del agua (las primeras filas), la pata es OPACA y recta; a partir de ahi se
		# hunde: se desvanece despacio al principio y deprisa al final.
		var hundido: float = clampf((t - 0.12) / 0.88, 0.0, 1.0)
		var alfa: float = 1.0 - hundido * hundido * (3.0 - 2.0 * hundido)
		# La deformacion crece con la profundidad: arriba la pata es recta, abajo culebrea.
		var onda: float = (sin(float(y) * 0.8) * 1.8 + sin(float(y) * 0.33 + 1.3) * 1.3) * hundido
		# Y se deshilacha: bajo el agua pierde un pixel de ancho por cada tercio.
		var ancho: int = PATA_ANCHO - int(hundido * 3.0)
		for x0 in xs:
			for k in ancho:
				var x: int = int(x0) + k + int(round(onda * (1.0 + float(k) * 0.08)))
				if x < 0 or x >= LADO:
					continue
				var col: Color = rampa[3] if k == 0 else (rampa[0] if k == ancho - 1 else rampa[1])
				# Lo hundido tira al color del agua antes de desaparecer.
				col = col.lerp(Color(0.12, 0.30, 0.43), hundido * 0.75)
				col.a = alfa
				_px(d, W, o.x + x, o.y + y, col)


static func _pintar(d: PackedByteArray, W: int, capa: String, o: Vector2i, rampa: Array,
		mask: int, sem: int, fase: float, ox: float, oy: float, bl: int) -> void:
	match capa:
		"hierba":
			_pintar_hierba(d, W, o, rampa, sem, ox, oy, bl)
		"calle":
			_pintar_calle(d, W, o, rampa, mask, sem, ox, oy, bl)
		"agua":
			TerrenoSprites._pintar_agua(d, W, o, rampa, mask, sem, fase, ox, oy, bl, true)
		"pilote":
			_pintar_pilote(d, W, o, rampa, mask)
		"madera":
			_pintar_madera(d, W, o, rampa, mask, sem, ox, oy, bl)
		"muralla":
			TerrenoSprites._pintar_muro(d, W, o, rampa, mask, sem, ox, oy, bl)


# ============================================================
#  ATLAS, HORNO Y TileSet
# ============================================================
static func generar() -> Image:
	var plano: Dictionary = _plano()
	var ancho: int = COLS * LADO
	var alto: int = int(plano["filas"]) * LADO
	var datos := PackedByteArray()
	datos.resize(ancho * alto * 4)
	for capa in CAPAS_ORDEN:
		var f: int = frames_de(capa)
		var v: int = variantes_de(capa)
		var rampa: Array = _rampa(capa)
		var sem: int = hash("pueblo") + hash(capa)
		var bl: int = bloque_de(capa)
		var base: bool = int((CAPAS[capa] as Dictionary)["clase"]) == Clase.BASE
		for i in _cuantas(capa):
			var c: Vector2i = celda_de(capa, i)
			var trozo: int = i % v
			var ox: float = float(trozo % bl) * float(LADO)
			var oy: float = float(trozo / bl) * float(LADO)
			for k in f:
				_pintar(datos, ancho, capa, Vector2i((c.x + k) * LADO, c.y * LADO), rampa,
					0 if base else int(i / v), sem, float(k) / float(f), ox, oy, bl)
	return Image.create_from_data(ancho, alto, false, Image.FORMAT_RGBA8, datos)


static func hornear() -> int:
	DirAccess.make_dir_recursive_absolute(CARPETA)
	if generar().save_png(ProjectSettings.globalize_path(PNG)) != OK:
		return 0
	var f := FileAccess.open(PNG, FileAccess.READ)
	var n: int = f.get_length() if f != null else 0
	if f != null:
		f.close()
	return n


static var _tex: Texture2D = null

static func atlas() -> Texture2D:
	if _tex != null:
		return _tex
	if ResourceLoader.exists(PNG):
		_tex = load(PNG) as Texture2D
	if _tex == null:
		_tex = ImageTexture.create_from_image(generar())
	return _tex


static func tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(LADO, LADO)
	var src := TileSetAtlasSource.new()
	src.texture = atlas()
	src.texture_region_size = Vector2i(LADO, LADO)
	for capa in CAPAS_ORDEN:
		var f: int = frames_de(capa)
		for i in _cuantas(capa):
			var c: Vector2i = celda_de(capa, i)
			src.create_tile(c)
			if f <= 1:
				continue
			src.set_tile_animation_columns(c, 0)
			src.set_tile_animation_frames_count(c, f)
			for k in f:
				src.set_tile_animation_frame_duration(c, k, 1.0 / TerrenoSprites.VELOCIDAD_ANIM_LAGO)
	ts.add_source(src, 0)
	return ts
