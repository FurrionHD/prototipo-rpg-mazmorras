# ============================================================
#  muralla_sprites.gd  (class_name MurallaSprites)
#  LA MURALLA DEL PUEBLO: una muralla de castillo (sillares, almenas, torres, saeteras) con sus
#  PORTONES de madera cerrados. El usuario paso la referencia: una muralla gris de piedra con torres
#  que sobresalen y un porton de dos hojas con herrajes bajo un arco de dovelas.
#
#  Antes el pueblo usaba el muro de la mazmorra (el autotile de TerrenoSprites) y "no parecia una
#  muralla". Aqui es una imagen por tramo, porque una muralla no es un tapiz: las torres y el porton
#  van en sitios concretos.
#
#  LA CAMARA MIRA DESDE EL SUR, asi que los tramos no se ven igual:
#    - NORTE: de frente. Se ve su CARA (sillares, saeteras), las almenas del parapeto y un poco del
#      adarve por encima. Las torres sobresalen y el porton va entre dos de ellas.
#    - OESTE / ESTE: de canto. Se ve el ADARVE desde arriba con almenas a los dos lados, las torres
#      como bloques con su cara sur, y el porton como las hojas cerradas dentro del arco.
#
#  Todo cabe en la huella de la muralla (2 casillas de grueso), asi que va entero por debajo de los
#  personajes: quien se arrima a la muralla esta siempre DELANTE de ella.
# ============================================================

extends RefCounted
class_name MurallaSprites

const CARPETA := "res://assets/sprites/pueblo/"
const CELDA := 32
const NEGRO := Color(0.07, 0.07, 0.08)

const PIEDRA := [
	Color(0.17, 0.17, 0.19), Color(0.31, 0.31, 0.33), Color(0.42, 0.42, 0.44),
	Color(0.52, 0.52, 0.54), Color(0.62, 0.62, 0.64), Color(0.74, 0.74, 0.76),
]
const MADERA := [Color(0.30, 0.17, 0.08), Color(0.48, 0.29, 0.13), Color(0.62, 0.40, 0.19), Color(0.74, 0.51, 0.26)]
const HIERRO := [Color(0.20, 0.20, 0.22), Color(0.44, 0.44, 0.48), Color(0.64, 0.64, 0.68)]

# Cada cuantas casillas va una torre en los tramos largos.
const TORRE_CADA := 12


static func _px(d: PackedByteArray, w: int, h: int, x: int, y: int, c: Color) -> void:
	PuebloSprites._px(d, w, h, x, y, c)


static func _rnd(x: int, y: int, s: int) -> float:
	return PuebloSprites._rnd(x, y, s)


static func _esc(v: float) -> Color:
	return PIEDRA[clampi(int(v * float(PIEDRA.size())), 0, PIEDRA.size() - 1)]


# Sillares a soga: hiladas de 'alto' px y piedras de 'largo', a matajunta, cada una con su tono y su
# canto de arriba mas claro.
static func _sillar(x: int, y: int, largo: int, alto: int, sem: int, base: float) -> Color:
	var hil: int = int(floor(float(y) / float(alto)))
	var off: int = (posmod(hil, 2)) * (largo / 2)
	var u: int = posmod(x + off, largo)
	var v: int = posmod(y, alto)
	if v == 0 or u == 0:
		return PIEDRA[0]
	var t: float = base + (_rnd(int(floor(float(x + off) / float(largo))), hil, sem) - 0.5) * 0.22
	if v == 1:
		t += 0.12
	if u == largo - 1 or v == alto - 1:
		t -= 0.08
	return _esc(clampf(t, 0.0, 0.999))


# ============================================================
#  TRAMO NORTE (de frente)
# ============================================================
# Alto 64 (las dos casillas de la huella). De arriba abajo: el adarve (lo que asoma por encima), las
# almenas del parapeto, la cara con sus saeteras y el zocalo.
const N_ADARVE := 10
const N_ALMENA := 10         # alto de la cara de una almena
const N_CARA0 := 20          # y donde empieza la cara de la muralla

static func norte(ancho_celdas: int, porton_x: Array) -> Image:
	var w: int = ancho_celdas * CELDA
	var h: int = 2 * CELDA
	var d := PackedByteArray()
	d.resize(w * h * 4)
	# Las torres: en las esquinas, cada TORRE_CADA casillas y a los lados de cada porton.
	var torres: Array = [0, w - 40]
	var tx: int = TORRE_CADA * CELDA
	while tx < w - 64:
		torres.append(tx - 20)
		tx += TORRE_CADA * CELDA
	for px_ in porton_x:
		torres.append(int(px_) - 48 - 36)
		torres.append(int(px_) + 48 - 4)
	# Quitar torres que se pisen (la de cada TORRE_CADA puede caer encima de las del porton).
	torres.sort()
	var limpias: Array = []
	for t in torres:
		if limpias.is_empty() or int(t) - int(limpias[-1]) >= 60:
			limpias.append(t)
	torres = limpias

	# 1) adarve + almenas + cara del lienzo entero
	for y in h:
		for x in w:
			var col: Color
			if y < N_ADARVE:
				# El adarve: losas vistas desde arriba, en sombra hacia el fondo.
				col = _sillar(x, y, 22, 6, 11, 0.42 - float(N_ADARVE - y) * 0.015)
			elif y < N_CARA0:
				# Las ALMENAS: bloques de 14 con huecos de 10. En el hueco se ve el adarve.
				var u: int = posmod(x, 24)
				if u < 14:
					col = PIEDRA[4] if y < N_ADARVE + 3 else _sillar(x, y, 14, 5, 23, 0.52)
					if u == 0 or u == 13:
						col = NEGRO
					if y == N_ADARVE:
						col = NEGRO
				else:
					col = _sillar(x, y, 22, 6, 11, 0.36)
			else:
				col = _sillar(x, y, 20, 8, 37, 0.50)
				# Sombra del parapeto sobre lo alto de la cara.
				if y < N_CARA0 + 4:
					col = col.darkened(0.30 * (1.0 - float(y - N_CARA0) / 4.0))
				if y == N_CARA0:
					col = NEGRO
				# Zocalo.
				if y >= h - 6:
					col = col.darkened(0.25)
				if y == h - 1:
					col = NEGRO
			_px(d, w, h, x, y, col)
	# 2) saeteras, lejos de torres y portones
	var sx: int = 64
	while sx < w - 64:
		var libre: bool = true
		for t in torres:
			if absi(sx - int(t) - 20) < 48:
				libre = false
		for p in porton_x:
			if absi(sx - int(p)) < 90:
				libre = false
		if libre:
			_saetera(d, w, h, sx, N_CARA0 + 10)
		sx += 96
	# 3) portones
	for p in porton_x:
		_porton_frente(d, w, h, int(p), h)
	# 4) torres (encima de todo: sobresalen)
	for t in torres:
		_torre_frente(d, w, h, int(t), 40)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, d)


static func _saetera(d: PackedByteArray, w: int, h: int, cx: int, y0: int) -> void:
	for y in range(y0 - 2, y0 + 14):
		for x in range(cx - 5, cx + 5):
			var dx: int = absi(x - cx)
			var arco: bool = y < y0 + 2 and dx * dx + (y0 + 2 - y) * (y0 + 2 - y) * 2 > 20
			if arco:
				continue
			var col: Color = PIEDRA[4]
			if dx <= 1 and y > y0 and y < y0 + 12:
				col = Color(0.05, 0.05, 0.06)
			elif dx <= 2 and y > y0 - 1 and y < y0 + 13:
				col = PIEDRA[1]
			_px(d, w, h, x, y, col)
	for x in range(cx - 5, cx + 5):
		_px(d, w, h, x, y0 + 13, PIEDRA[1])


# Torre vista de frente: mas clara que el lienzo (esta mas cerca), piedras grandes irregulares, sus
# propias almenas arriba, el canto derecho en sombra y contorno negro.
static func _torre_frente(d: PackedByteArray, w: int, h: int, x0: int, ancho: int) -> void:
	for y in h:
		for x in range(x0, x0 + ancho):
			var lx: int = x - x0
			var col: Color
			if y < 8:
				var u: int = posmod(lx - 2, 12)
				if u >= 8 and y < 5:
					continue                      # hueco entre almenas de la torre
				col = PIEDRA[5] if y < 2 else PIEDRA[4]
			else:
				col = _sillar(x, y + 3, 13, 11, 59, 0.58)
				if lx >= ancho - 4:
					col = col.darkened(0.25)
			if lx == 0 or lx == ancho - 1 or y == h - 1 or (y == 8 and true):
				col = NEGRO
			_px(d, w, h, x, y, col)


# Porton de frente: arco de dovelas y dos hojas de tablones con tres bandas de hierro y remaches.
const PORTON_ANCHO := 60
const PORTON_ALTO := 40

static func _porton_frente(d: PackedByteArray, w: int, h: int, cx: int, suelo: int) -> void:
	var r: float = float(PORTON_ANCHO) * 0.5
	var arranque: int = suelo - PORTON_ALTO + int(r)     # donde empieza la curva
	for y in range(suelo - PORTON_ALTO - 8, suelo):
		for x in range(cx - int(r) - 8, cx + int(r) + 8):
			var dx: float = float(x) + 0.5 - float(cx)
			var dy: float = maxf(0.0, float(arranque) - (float(y) + 0.5))
			var dist: float = sqrt(dx * dx + dy * dy)
			var col: Color
			if dist <= r:
				# Las hojas.
				var lx: int = x - (cx - int(r))
				col = MADERA[1 + int(_rnd(lx / 6, 0, 81) * 2.0)] if posmod(lx, 6) != 0 else MADERA[0]
				if absi(x - cx) < 1:
					col = HIERRO[0]               # la junta de las dos hojas
				var ry: int = y - (suelo - PORTON_ALTO)
				for banda in [10, 22, 34]:
					if ry == banda or ry == banda + 1:
						col = HIERRO[1] if ry == banda else HIERRO[0]
						if posmod(lx, 8) == 4 and ry == banda:
							col = HIERRO[2]       # remache
				if dist > r - 1.0:
					col = NEGRO
			elif dist <= r + 7.0 and float(y) < float(suelo):
				# Las dovelas del arco (y las jambas, que son el arco estirado hasta el suelo).
				var ang: float = atan2(dy, dx)
				var dov: int = int(floor((ang + PI) / (PI / 9.0)))
				col = PIEDRA[4] if posmod(dov, 2) == 0 else PIEDRA[3]
				if dy <= 0.0:
					col = PIEDRA[4] if posmod(y / 7, 2) == 0 else PIEDRA[3]
				if dist > r + 6.0 or (dy > 0.0 and absf(fposmod((ang + PI) / (PI / 9.0), 1.0)) < 0.08):
					col = NEGRO
			else:
				continue
			_px(d, w, h, x, y, col)


# ============================================================
#  TRAMOS OESTE / ESTE (de canto)
# ============================================================
# Ancho 64 (dos casillas), alto el de la muralla. Se ve el ADARVE desde arriba entre dos filas de
# almenas; cada almena es un bloque con su tapa clara y su cara sur. Las torres son bloques mas
# claros con almenas alrededor y una buena cara sur. El porton se ve como las hojas cerradas, con
# los tablones de canto, dentro del arco que abre la muralla hacia el pueblo.
static func lateral(alto_celdas: int, porton_filas: Array, este: bool) -> Image:
	var w: int = 2 * CELDA
	var h: int = alto_celdas * CELDA
	var d := PackedByteArray()
	d.resize(w * h * 4)
	var torres: Array = []
	var ty: int = TORRE_CADA * CELDA
	while ty < h - 96:
		torres.append(ty)
		ty += TORRE_CADA * CELDA
	var huecos: Array = []           # [y0, y1] de cada porton
	for f in porton_filas:
		var y0: int = int(f) * CELDA
		huecos.append([y0, y0 + 3 * CELDA])
		torres.append(y0 - 44)
		torres.append(y0 + 3 * CELDA)
	torres.sort()
	var limpias: Array = []
	for t in torres:
		if limpias.is_empty() or int(t) - int(limpias[-1]) >= 70:
			limpias.append(t)
	torres = limpias

	for y in h:
		for x in w:
			# El lado de dentro (hacia el pueblo) es el derecho en la del oeste y el izquierdo en la del este.
			var lx: int = w - 1 - x if este else x
			# Adarve: losas de lado a lado (van a lo ancho del paso), de 10 de fondo.
			var col: Color = _sillar(y, x, 10, 23, 101, 0.46)
			# Almenas a los dos lados: bloques de 12 de largo con hueco de 8.
			var en_almena: bool = (lx < 9 or lx >= w - 9) and posmod(y, 20) < 12
			if en_almena:
				var v: int = posmod(y, 20)
				col = PIEDRA[5] if v < 5 else _sillar(x, y, 9, 4, 131, 0.48)
				if v == 11 or (lx == 0 or lx == w - 1):
					col = NEGRO
			elif lx == 9 or lx == w - 10:
				col = PIEDRA[1]                                     # el pie del parapeto
			if lx == 0 or lx == w - 1:
				col = NEGRO
			# El extremo sur (junto al agua): la cara del muro.
			if y >= h - 18:
				col = _sillar(x, y, 16, 6, 151, 0.50)
				if y == h - 18 or y == h - 1:
					col = NEGRO
			_px(d, w, h, x, y, col)
	for hu in huecos:
		_porton_lateral(d, w, h, int(hu[0]), int(hu[1]), este)
	for t in torres:
		_torre_lateral(d, w, h, int(t))
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, d)


static func _torre_lateral(d: PackedByteArray, w: int, h: int, y0: int) -> void:
	var alto: int = 44
	var cara: int = 14
	for y in range(y0, y0 + alto + cara):
		for x in w:
			var col: Color
			var ly: int = y - y0
			if ly < alto:
				# Tapa de la torre con su anillo de almenas.
				col = _sillar(x, y, 11, 11, 171, 0.60)
				var borde: bool = x < 7 or x >= w - 7 or ly < 7 or ly >= alto - 7
				if borde:
					# Almenas en BLOQUES a lo largo del borde (medido por el lado en que esta cada una).
					# Con (x + ly) salian rayas diagonales, como una señal de obras.
					var a: int = posmod(x, 14) if (ly < 7 or ly >= alto - 7) else posmod(ly, 14)
					col = PIEDRA[5] if a < 9 else PIEDRA[2]
					if a == 8:
						col = PIEDRA[1]
			else:
				col = _sillar(x, y, 13, 7, 191, 0.52).darkened(0.12)   # su cara sur
				if ly == alto:
					col = NEGRO
			if x == 0 or x == w - 1 or y == y0 or y == y0 + alto + cara - 1:
				col = NEGRO
			_px(d, w, h, x, y, col)


static func _porton_lateral(d: PackedByteArray, w: int, h: int, y0: int, y1: int, este: bool) -> void:
	# Un marco de piedra (dovelas alternas) y dentro las dos hojas cerradas vistas desde arriba:
	# tablones a lo largo del paso, la junta de las dos hojas en medio y bandas de hierro atravesadas.
	# La primera version intentaba un arco en planta y salia torcido, con una raya en diagonal.
	var marco: int = 6
	for y in range(y0, y1):
		for x in w:
			var lx: int = w - 1 - x if este else x
			var ly: int = y - y0
			var alto: int = y1 - y0
			var col: Color
			var en_marco: bool = ly < marco or ly >= alto - marco or lx < 4 or lx >= w - 4
			if en_marco:
				var tramo: int = (x / 7) if (ly < marco or ly >= alto - marco) else (ly / 7)
				col = PIEDRA[4] if posmod(tramo, 2) == 0 else PIEDRA[3]
				if ly == 0 or ly == alto - 1 or ly == marco - 1 or ly == alto - marco:
					col = NEGRO
			else:
				col = MADERA[1 + int(_rnd(0, ly / 6, 83) * 2.0)] if posmod(ly, 6) != 0 else MADERA[0]
				if absi(ly - alto / 2) < 1:
					col = HIERRO[0]
				for banda in [14, 30, 46]:
					if lx == banda or lx == banda + 1:
						col = HIERRO[1] if lx == banda else HIERRO[0]
						if posmod(ly, 8) == 4 and lx == banda:
							col = HIERRO[2]
			_px(d, w, h, x, y, col)


# ============================================================
#  HORNO
# ============================================================
static func claves() -> PackedStringArray:
	return PackedStringArray(["muralla_norte", "muralla_oeste", "muralla_este"])


static func generar(clave: String) -> Image:
	match clave:
		"muralla_norte":
			var pn: Array = []
			for p in PuebloPlano.PORTONES:
				if String(p["lado"]) == "norte":
					var r: Rect2i = p["rect"]
					pn.append(int((float(r.position.x) + float(r.size.x) * 0.5) * CELDA))
			return norte(PuebloPlano.ANCHO, pn)
		_:
			var este: bool = clave == "muralla_este"
			var filas: Array = []
			for p in PuebloPlano.PORTONES:
				if String(p["lado"]) == ("este" if este else "oeste"):
					filas.append((p["rect"] as Rect2i).position.y)
			return lateral(PuebloPlano.ORILLA, filas, este)


static func hornear_todo() -> int:
	var n: int = 0
	for c in claves():
		if generar(c).save_png(ProjectSettings.globalize_path(CARPETA + c + ".png")) == OK:
			n += 1
	return n


static var _cache: Dictionary = {}

static func textura(clave: String) -> Texture2D:
	if _cache.has(clave):
		return _cache[clave]
	var png: String = CARPETA + clave + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(png):
		tex = load(png) as Texture2D
	if tex == null:
		tex = ImageTexture.create_from_image(generar(clave))
	_cache[clave] = tex
	return tex
