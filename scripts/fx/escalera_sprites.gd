# ============================================================
#  escalera_sprites.gd  (class_name EscaleraSprites)
#  LAS ESCALERAS DE LA MAZMORRA, integradas en el suelo:
#    - "baja":    un HUECO abierto en el propio suelo, con los peldaños hundiendose hacia lo negro.
#    - "sube":    un tramo de peldaños que SALE del suelo y sube hasta un arco con luz de dia.
#    - "caracol": la salida al pueblo, gemela de la escalera de caracol de la plaza pero HACIA ARRIBA:
#                 el pretil abierto al sur y dentro los peldaños subiendo en espiral alrededor del eje,
#                 con la luz de dia cayendo desde arriba.
#
#  LO QUE LAS INTEGRA EN EL PISO (lo pidio el usuario: "que no parezca un png pegado"): no llevan marco ni
#  baldosa propia. Fuera de la pieza el lienzo es TRANSPARENTE, asi que se ve el suelo del tier que toque,
#  el borde se funde con una SOMBRA translucida que oscurece ese mismo suelo, y la piedra va en tonos
#  OSCUROS de la misma gama que el suelo (la primera version, clara, se leia como una caja encima).
#
#  Y SUBIR NO PUEDE LEERSE COMO BAJAR (tambien lo vio el usuario: eran la misma caja con la luz al reves).
#  La diferencia es fisica, no de color. Con la camara mirando al norte desde arriba:
#    - un tramo que BAJA hacia el norte esconde sus contrahuellas (miran al norte): se ve un agujero con
#      los peldaños cada vez mas hondos y oscuros, y la pared del fondo;
#    - un tramo que SUBE hacia el norte las enseña (miran al sur, a la camara): caras de escalon apiladas,
#      cada una mas alta en pantalla. Es un bloque, no un agujero.
#
#  COMO SE DIBUJA: un lienzo con Z-BUFFER. Cada superficie se muestrea en el mundo (x, y, z) y se proyecta
#  como en el pueblo (suelo en planta, la altura sube z*sin45); gana lo que este mas cerca de la camara
#  (y + z mayor). Asi los peldaños, el pretil y el eje se tapan bien entre si sin ordenar nada a mano.
# ============================================================
extends RefCounted
class_name EscaleraSprites

const CARPETA := "res://assets/sprites/props/"
const SEN45 := 0.7071

const TAM := {
	"baja": Vector2i(48, 48),
	"sube": Vector2i(48, 92),
	"caracol": Vector2i(96, 150),
}
# Px desde abajo que son la HUELLA (lo de encima tapa a quien pasa por detras, ver PiezaPueblo).
const PIE := {"baja": 48, "sube": 40, "caracol": 96}

const NEGRO := Color(0.02, 0.02, 0.03)
# De la gama del suelo: el mas claro apenas pasa del suelo iluminado. Mas claro = caja pegada.
const PIEDRA := [
	Color(0.06, 0.06, 0.08), Color(0.10, 0.10, 0.12), Color(0.15, 0.15, 0.17), Color(0.20, 0.20, 0.23),
	Color(0.26, 0.26, 0.29), Color(0.33, 0.33, 0.36), Color(0.41, 0.41, 0.44), Color(0.50, 0.50, 0.53),
]
const LUZ_DIA := Color(1.00, 0.88, 0.58)


static func tam(clave: String) -> Vector2i:
	return TAM[clave]


static func pie(clave: String) -> int:
	return PIE[clave]


static func _rnd(x: int, y: int, s: int) -> float:
	return PuebloSprites._rnd(x, y, s)


static func _piedra(v: float) -> Color:
	return PIEDRA[clampi(int(v * float(PIEDRA.size())), 0, PIEDRA.size() - 1)]


# ------------------------------------------------------------
#  EL LIENZO CON Z-BUFFER
# ------------------------------------------------------------
static func _nuevo(clave: String) -> Dictionary:
	var t: Vector2i = TAM[clave]
	var d := PackedByteArray()
	d.resize(t.x * t.y * 4)
	var z: Array = []
	z.resize(t.x * t.y)
	z.fill(-1e9)
	return {"t": t, "d": d, "z": z}


# Un punto del mundo. 'origen' es donde cae en el lienzo el (0,0,0) del mundo. 'clip': solo se pinta
# dentro de ese rectangulo de pantalla (lo que se ve A TRAVES del hueco del suelo).
static func _pon(l: Dictionary, wx: float, wy: float, wz: float, col: Color, clip: Rect2 = Rect2()) -> void:
	var t: Vector2i = l["t"]
	var sx: int = int(floor(wx))
	var sy: int = int(floor(wy - wz * SEN45))
	if sx < 0 or sy < 0 or sx >= t.x or sy >= t.y:
		return
	if clip.size != Vector2.ZERO and not clip.has_point(Vector2(float(sx) + 0.5, float(sy) + 0.5)):
		return
	var i: int = sy * t.x + sx
	var prof: float = wy + wz
	# El z-buffer es un Array normal y no un PackedFloat32Array A PROPOSITO: el Packed dentro del
	# diccionario se escribia en una COPIA ("(l["z"] as PackedFloat32Array)[i] = ..."), el buffer no
	# recordaba nada y ganaba siempre lo ultimo pintado: los peldaños altos tapaban a los bajos.
	var zb: Array = l["z"]
	if prof < float(zb[i]):
		return
	zb[i] = prof
	PuebloSprites._px(l["d"], t.x, t.y, sx, sy, col)


# Una CAJA: su cara de arriba y su cara sur (las unicas que ve esta camara). 'color' recibe
# (x, y_o_h, "arriba"/"frente") y devuelve el color de ese punto.
static func _caja(l: Dictionary, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float,
		color: Callable, clip: Rect2 = Rect2()) -> void:
	var x: float = x0
	while x < x1:
		var y: float = y0
		while y < y1:
			_pon(l, x, y, z1, color.call(x, y, "arriba"), clip)
			y += 0.5
		var h: float = z0
		while h < z1:
			_pon(l, x, y1 - 0.01, h, color.call(x, h, "frente"), clip)
			h += 0.5
		x += 0.5


# Oscurece el suelo alrededor de la pieza: 'dist' = distancia al borde (negativa fuera).
static func _sombra(l: Dictionary, dist: Callable, ancho: float, fuerza: float) -> void:
	var t: Vector2i = l["t"]
	for y in t.y:
		for x in t.x:
			var s: float = dist.call(float(x) + 0.5, float(y) + 0.5)
			if s >= 0.0 or s < -ancho:
				continue
			PuebloSprites._px(l["d"], t.x, t.y, x, y, Color(0, 0, 0, fuerza * pow(1.0 + s / ancho, 1.6)))


# Luz translucida (sin z-buffer: es luz, no un objeto). Elipse centrada en 'c' con radios 'r'.
static func _halo(l: Dictionary, c: Vector2, r: Vector2, fuerza: float) -> void:
	var t: Vector2i = l["t"]
	for y in t.y:
		for x in t.x:
			var e: float = Vector2((float(x) + 0.5 - c.x) / r.x, (float(y) + 0.5 - c.y) / r.y).length()
			var a: float = clampf(1.0 - e, 0.0, 1.0)
			if a > 0.0:
				PuebloSprites._px(l["d"], t.x, t.y, x, y, Color(LUZ_DIA.r, LUZ_DIA.g, LUZ_DIA.b, a * a * fuerza))


# ============================================================
#  BAJAR: el hueco en el suelo
# ============================================================
const B_PELDANOS := 6
const B_ALTO := 3.0

static func _baja() -> PackedByteArray:
	var l: Dictionary = _nuevo("baja")
	var hx0: float = 5.0
	var hx1: float = 43.0
	var hy0: float = 5.0
	var hy1: float = 44.0
	var hueco := Rect2(hx0, hy0, hx1 - hx0, hy1 - hy0)
	var borde := func(fx: float, fy: float) -> float:
		var mella: float = (_rnd(int(fx) / 3, int(fy) / 3, 41) - 0.5) * 1.6
		return minf(minf(fx - hx0, hx1 - fx), minf(fy - hy0, hy1 - fy)) + mella
	_sombra(l, borde, 5.0, 0.6)
	var hondo: float = B_ALTO * float(B_PELDANOS) + 20.0
	# LA PARED DEL FONDO: la cara sur de la roca que queda al norte del hueco, bajando hacia lo negro.
	_caja(l, hx0, hx1, hy0 - 6.0, hy0, -hondo, 0.0, func(x: float, h: float, cara: String) -> Color:
		var baja: float = clampf(-h / 12.0, 0.0, 1.0)
		var c: Color = PIEDRA[3].lerp(NEGRO, baja)
		if fposmod(h, 4.0) > 3.2 or posmod(int(x) + int(floor(h / 4.0)) * 4, 8) == 0:
			c = c.darkened(0.5)
		return c, hueco)
	# LOS PELDAÑOS: el de mas al sur esta a un escalon del suelo; cada uno hacia el norte, B_ALTO mas hondo.
	var fondo: float = (hy1 - hy0) / float(B_PELDANOS)
	for k in B_PELDANOS:
		var y1: float = hy1 - fondo * float(k)
		var z1: float = -B_ALTO * float(k + 1)
		var luz: float = 1.0 - float(k) / float(B_PELDANOS)
		_caja(l, hx0, hx1, y1 - fondo, y1, -hondo, z1, func(x: float, yy: float, cara: String) -> Color:
			# Solo se ve la mitad de ATRAS de cada peldaño (la de delante la tapa el anterior, que esta mas
			# alto): la luz va ahi. Oscura pegada a la contrahuella del de detras y clara hacia delante.
			var fr: float = clampf((yy - (y1 - fondo)) / (fondo - B_ALTO * SEN45), 0.0, 1.0)
			var v: float = 0.40 + 0.40 * fr + (_rnd(int(x), int(yy * 2.0), 17 + k) - 0.5) * 0.08
			if cara == "arriba" and yy < y1 - fondo + 1.0:
				v = 0.08                                  # la sombra que deja el escalon de detras
			# Las paredes de los lados, en sombra.
			var lado: float = minf(x - hx0, hx1 - x)
			if lado < 4.0:
				v -= (4.0 - lado) * 0.08
			return _piedra(clampf(v, 0.0, 0.999)).lerp(NEGRO, (1.0 - luz) * 0.75), hueco)
	# El LABIO del suelo: una raya fina de luz en el borde sur (el canto cortado) y oscura en el norte.
	var t: Vector2i = l["t"]
	for x in range(int(hx0), int(hx1)):
		PuebloSprites._px(l["d"], t.x, t.y, x, int(hy1) - 1, Color(PIEDRA[4].r, PIEDRA[4].g, PIEDRA[4].b, 0.8))
		PuebloSprites._px(l["d"], t.x, t.y, x, int(hy0), Color(0, 0, 0, 0.7))
	return l["d"]


# ============================================================
#  SUBIR: el tramo que sale del suelo hasta un arco con luz
# ============================================================
const S_PELDANOS := 5
const S_ALTO := 6.0

static func _sube() -> PackedByteArray:
	var l: Dictionary = _nuevo("sube")
	var x0: float = 9.0
	var x1: float = 39.0
	var y_sur: float = 88.0
	var fondo: float = 6.0
	var y_norte: float = y_sur - fondo * float(S_PELDANOS)
	var z_muro: float = S_ALTO * float(S_PELDANOS) + 20.0
	_sombra(l, func(fx: float, fy: float) -> float:
		return minf(minf(fx - (x0 - 4.0), (x1 + 4.0) - fx), minf(fy - (y_norte - 7.0), y_sur - fy)), 4.0, 0.6)
	# EL MURO del fondo con su ARCO: el tramo acaba contra la roca y sigue por un hueco hacia arriba.
	var arco_z0: float = S_ALTO * float(S_PELDANOS)
	_caja(l, x0 - 5.0, x1 + 5.0, y_norte - 7.0, y_norte, 0.0, z_muro, func(x: float, h: float, cara: String) -> Color:
		if cara == "arriba":
			return PIEDRA[2]
		var cx: float = (x0 + x1) * 0.5
		var dx: float = absf(x - cx)
		var ancho: float = 10.0
		var tope: float = arco_z0 + 12.0 + sqrt(maxf(0.0, ancho * ancho - dx * dx)) * 0.6
		if dx < ancho and h >= arco_z0 and h < tope:
			# EL VANO: oscuro abajo y con la luz de dia entrando por arriba.
			var sube: float = clampf((h - arco_z0) / (tope - arco_z0), 0.0, 1.0)
			return NEGRO.lerp(LUZ_DIA.darkened(0.25), sube * sube)
		var c: Color = PIEDRA[2]
		if fposmod(h, 5.0) > 4.0 or posmod(int(x) + int(floor(h / 5.0)) * 5, 10) == 0:
			c = PIEDRA[1]
		if dx < ancho + 1.5 and h >= arco_z0 - 1.0 and h < tope + 1.5:
			c = PIEDRA[4]                                  # el marco del arco
		return c)
	# LOS PELDAÑOS: bloques macizos, cada uno S_ALTO mas alto que el de delante.
	for k in S_PELDANOS:
		var y1: float = y_sur - fondo * float(k)
		var z1: float = S_ALTO * float(k + 1)
		var luz: float = 0.75 + 0.25 * float(k) / float(S_PELDANOS - 1)
		_caja(l, x0, x1, y1 - fondo, y1, 0.0, z1, func(x: float, yh: float, cara: String) -> Color:
			var v: float
			if cara == "arriba":
				v = 0.78 + (_rnd(int(x), int(yh * 2.0), 23 + k) - 0.5) * 0.10
				if yh > y1 - 1.0:
					v = 0.99                                   # el canto
			else:
				v = 0.28 + (_rnd(int(x), int(yh * 2.0), 29 + k) - 0.5) * 0.08
				if yh < z1 - S_ALTO + 1.0:
					v = 0.12                                   # donde apoya en el de delante
			return _piedra(clampf(v * luz, 0.0, 0.999)))
		# Los MURETES de los lados, escalonados con el tramo.
		for lx in [x0 - 4.0, x1]:
			_caja(l, lx, lx + 4.0, y1 - fondo, y1, 0.0, z1 + 5.0, func(x: float, yh: float, cara: String) -> Color:
				return PIEDRA[5] if cara == "arriba" else PIEDRA[2])
	# La luz que baja por el arco y se derrama sobre los peldaños de arriba.
	_halo(l, Vector2((x0 + x1) * 0.5, y_norte - arco_z0 * SEN45 + 2.0), Vector2(16.0, 14.0), 0.45)
	return l["d"]


# ============================================================
#  LA CARACOL HACIA ARRIBA (salida al pueblo)
# ============================================================
const C_POZO_R := 33.0
const C_PRETIL_R := 40.0
const C_PRETIL_ALTO := 6.0
const C_EJE_R := 6.0
const C_PELDANOS := 12
const C_VUELTA := 1.5 * PI      # tres cuartos de vuelta: asi queda a la vista el hueco de delante
const C_ALTO := 5.0
const C_GROSOR := 4.0
const C_BOCA := 0.42

static func _caracol() -> PackedByteArray:
	var l: Dictionary = _nuevo("caracol")
	var t: Vector2i = l["t"]
	var cx: float = 48.0
	var cy: float = float(t.y) - 46.0
	var en_boca := func(ang: float) -> bool:
		return absf(wrapf(ang - PI * 0.5, -PI, PI)) < C_BOCA
	_sombra(l, func(fx: float, fy: float) -> float:
		return C_PRETIL_R + 1.0 - Vector2(fx - cx, fy - cy).length(), 5.0, 0.6)
	# El SUELO DEL POZO, en sombra, con la luz de dia cayendo al centro.
	for y in t.y:
		for x in t.x:
			var r: float = Vector2(float(x) + 0.5 - cx, float(y) + 0.5 - cy).length()
			if r <= C_POZO_R:
				var v: float = 0.30 + _rnd(x / 4, y / 4, 11) * 0.2
				_pon(l, float(x) + 0.5, float(y) + 0.5, 0.0, _piedra(v))
	# LOS PELDAÑOS: losas gruesas que salen del eje, desde la boca girando por el oeste y el norte.
	var paso: float = C_VUELTA / float(C_PELDANOS)
	for i in C_PELDANOS:
		var a0: float = PI * 0.5 + C_BOCA * 0.5 + float(i) * paso
		var a1: float = a0 + paso - 0.05
		var z: float = C_ALTO * float(i + 1)
		var luz: float = 0.70 + 0.30 * float(i) / float(C_PELDANOS - 1)
		var par: float = 0.06 if i % 2 == 0 else 0.0
		var r: float = C_EJE_R
		while r <= C_POZO_R - 1.0:
			var a: float = a0
			var da: float = 0.5 / r
			while a <= a1:
				var wx: float = cx + r * cos(a)
				var wy: float = cy + r * sin(a)
				var v: float = 0.70 + par - 0.08 * cos(a) + (_rnd(int(wx), int(wy), i) - 0.5) * 0.08
				if a < a0 + da * 2.5:
					v = 0.95                            # el canto de delante del peldaño, con luz
				_pon(l, wx, wy, z, _piedra(clampf(v * luz, 0.0, 0.999)))
				# El canto exterior de la losa.
				if r > C_POZO_R - 1.6:
					var h: float = z - C_GROSOR
					while h < z:
						_pon(l, wx, wy + 0.2, h, _piedra(0.30 * luz))
						h += 0.5
				a += da
			r += 0.5
		# LA CONTRAHUELLA: la cara del final de la losa (la que mira al peldaño siguiente, mas alto no:
		# la de su borde de salida, que da la sombra). Oscura: es lo que separa un peldaño de otro.
		var rr: float = C_EJE_R
		while rr <= C_POZO_R - 1.0:
			var h2: float = z - C_GROSOR
			while h2 < z:
				_pon(l, cx + rr * cos(a1), cy + rr * sin(a1) + 0.2, h2, _piedra(0.18 * luz))
				_pon(l, cx + rr * cos(a0), cy + rr * sin(a0) + 0.2, h2, _piedra(0.26 * luz))
				h2 += 0.5
			rr += 0.5
	# EL EJE: la columna central, del suelo a por encima del ultimo peldaño.
	var z_top: float = C_ALTO * float(C_PELDANOS) + 14.0
	var hz: float = 0.0
	while hz <= z_top:
		var a2: float = 0.0
		while a2 < TAU:
			var v3: float = 0.52 - 0.22 * cos(a2) + 0.08 * sin(a2)
			if fposmod(hz, 7.0) < 0.8:
				v3 -= 0.15
			_pon(l, cx + C_EJE_R * cos(a2), cy + C_EJE_R * sin(a2), hz, _piedra(clampf(v3, 0.0, 0.999)))
			a2 += 0.07
		hz += 0.5
	# EL PRETIL, abierto al sur, como el de la plaza.
	var r3: float = C_POZO_R
	while r3 <= C_PRETIL_R:
		var a3: float = 0.0
		while a3 < TAU:
			if not en_boca.call(a3):
				var wx3: float = cx + r3 * cos(a3)
				var wy3: float = cy + r3 * sin(a3)
				var junta: bool = int(rad_to_deg(a3) + 360.0) % 30 < 2
				var col3: Color = PIEDRA[2] if junta else PIEDRA[4]
				if r3 < C_POZO_R + 1.0 or r3 > C_PRETIL_R - 0.8:
					col3 = PIEDRA[1]
				_pon(l, wx3, wy3, C_PRETIL_ALTO, col3)
				if r3 > C_PRETIL_R - 0.8:
					var h3: float = 0.0
					while h3 < C_PRETIL_ALTO:
						_pon(l, wx3, wy3, h3, PIEDRA[1] if fposmod(h3, 3.0) < 0.8 else PIEDRA[3])
						h3 += 0.5
			a3 += 0.5 / r3
		r3 += 0.5
	# LA LUZ DE DIA que baja por arriba: sobre lo alto del eje y los ultimos peldaños.
	_halo(l, Vector2(cx, cy - z_top * SEN45 + 6.0), Vector2(34.0, 30.0), 0.55)
	return l["d"]


# ============================================================
#  MONTARLAS EN EL MUNDO
# ============================================================
# Donde cae el CENTRO DE LA HUELLA dentro de cada lienzo: la pieza se coloca con ese punto en el origen
# del nodo que la lleva (la escalera, la puerta).
const CENTRO := {"baja": Vector2(24, 24), "sube": Vector2(24, 73), "caracol": Vector2(48, 104)}
# La subida: quien esta encima de los peldaños (hasta el muro del arco) sigue estando "delante".
const SUBE_MARGEN := 40.0

static func montar(padre: Node2D, clave: String) -> PiezaPueblo:
	var p: PiezaPueblo = PiezaPueblo.crear_textura("escalera_" + clave, textura(clave), TAM[clave], PIE[clave],
		clave == "sube", SUBE_MARGEN)
	p.position = -CENTRO[clave]
	padre.add_child(p)
	# LA CARACOL CHOCA, como la de la plaza: no se anda por encima de un pretil. La F llega desde
	# cualquier lado con radio_extra en quien la lleve (ver door.gd).
	if clave == "caracol":
		var cuerpo := StaticBody2D.new()
		cuerpo.name = "ChoqueCaracol"
		var col := CollisionShape2D.new()
		var forma := CircleShape2D.new()
		forma.radius = C_PRETIL_R
		col.shape = forma
		cuerpo.add_child(col)
		padre.add_child(cuerpo)
	return p


# ============================================================
#  GENERAR, HORNEAR, CARGAR
# ============================================================
static func generar(clave: String) -> Image:
	var t: Vector2i = TAM[clave]
	var d: PackedByteArray
	match clave:
		"baja": d = _baja()
		"sube": d = _sube()
		_: d = _caracol()
	return Image.create_from_data(t.x, t.y, false, Image.FORMAT_RGBA8, d)


# Devuelve los bytes escritos (0 si fallo), como PropSprites.hornear.
static func hornear(clave: String) -> int:
	DirAccess.make_dir_recursive_absolute(CARPETA)
	var png: String = CARPETA + "escalera_suelo_" + clave + ".png"
	if generar(clave).save_png(ProjectSettings.globalize_path(png)) != OK:
		return 0
	var f := FileAccess.open(png, FileAccess.READ)
	var n: int = f.get_length() if f != null else 0
	if f != null:
		f.close()
	return n


static var _cache: Dictionary = {}

static func textura(clave: String) -> Texture2D:
	if _cache.has(clave):
		return _cache[clave]
	var tex: Texture2D = null
	var png: String = CARPETA + "escalera_suelo_" + clave + ".png"
	if ResourceLoader.exists(png):
		tex = load(png) as Texture2D
	if tex == null:
		tex = ImageTexture.create_from_image(generar(clave))
	_cache[clave] = tex
	return tex
