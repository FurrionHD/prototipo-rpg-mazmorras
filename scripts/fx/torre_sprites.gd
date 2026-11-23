# ============================================================
#  torre_sprites.gd
#  LA TORRE DEL MAGO (22/11, el jefe: "hazlo mas epico"). No es una casa con su pared y su tejado (CasaSprites): es una
#  TORRE REDONDA y alta, con ventanas en arco que brillan, un anillo de runas encendidas, un sello sobre la puerta, el
#  tejado en cono con su remate dorado y un CRISTAL flotando en la punta. La pinta CasaSprites.generar cuando la ficha
#  de la casa lleva "torre" (la paleta), en el mismo lienzo que una casa de su huella.
#
#  EN LA VISTA DEL PUEBLO (desde arriba, en diagonal; lo pidio el jefe: "no tiene perspectiva, parece un png pegado"):
#  cada circulo de la torre se ve como un OVALO de alto RY_F veces su ancho. Por eso la base es un disco con la cara de
#  arriba a la vista, cada fila de ladrillos, el anillo de runas y las cornisas se curvan hacia abajo por delante, y el
#  tejado es un cono visto desde arriba (su alero, otro ovalo). Un punto de la pared a la altura 'alto' y en la columna
#  t (-1 izquierda, +1 derecha) cae en  y = base - alto + RY * sqrt(1 - t^2): lo de delante, mas abajo.
#  La torre va en el CENTRO de su huella, no pegada al borde: asi se lee plantada en sus casillas.
#  Sin sombra en el suelo (memoria sombras-fuera-del-sprite).
#  Tres PALETAS para que elija el jefe (ver PALETAS); la que va en el juego la dice CasaSprites.CASAS["mago"]["torre"].
# ============================================================
extends RefCounted

const NEGRO := Color(0.06, 0.04, 0.07)

# piedra: de oscura a clara; tejado: de oscuro a claro; brillo: la luz magica (oscura, media, clara, blanca);
# oro: el remate (sombra, medio, luz).
const PALETAS := {
	"A": {"nombre": "arcana",
		"piedra": [Color(0.20, 0.17, 0.27), Color(0.30, 0.26, 0.38), Color(0.40, 0.35, 0.50), Color(0.52, 0.47, 0.62)],
		"tejado": [Color(0.12, 0.10, 0.30), Color(0.20, 0.17, 0.46), Color(0.30, 0.26, 0.62), Color(0.42, 0.38, 0.78)],
		"brillo": [Color(0.42, 0.20, 0.75), Color(0.66, 0.42, 1.0), Color(0.84, 0.70, 1.0), Color(0.97, 0.94, 1.0)],
		"oro": [Color(0.55, 0.36, 0.10), Color(0.86, 0.64, 0.22), Color(1.0, 0.88, 0.48)]},
	"B": {"nombre": "astral",
		"piedra": [Color(0.48, 0.50, 0.58), Color(0.64, 0.66, 0.74), Color(0.80, 0.82, 0.88), Color(0.93, 0.94, 0.97)],
		"tejado": [Color(0.08, 0.14, 0.36), Color(0.12, 0.24, 0.56), Color(0.20, 0.36, 0.74), Color(0.34, 0.52, 0.90)],
		"brillo": [Color(0.75, 0.52, 0.12), Color(1.0, 0.78, 0.30), Color(1.0, 0.92, 0.62), Color(1.0, 0.99, 0.90)],
		"oro": [Color(0.55, 0.36, 0.10), Color(0.86, 0.64, 0.22), Color(1.0, 0.88, 0.48)]},
	"C": {"nombre": "sombria",
		"piedra": [Color(0.09, 0.09, 0.11), Color(0.15, 0.15, 0.18), Color(0.22, 0.22, 0.26), Color(0.31, 0.31, 0.36)],
		"tejado": [Color(0.09, 0.05, 0.13), Color(0.16, 0.09, 0.23), Color(0.24, 0.14, 0.33), Color(0.34, 0.21, 0.45)],
		"brillo": [Color(0.10, 0.50, 0.38), Color(0.24, 0.86, 0.62), Color(0.62, 1.0, 0.82), Color(0.92, 1.0, 0.96)],
		"oro": [Color(0.40, 0.30, 0.16), Color(0.66, 0.54, 0.30), Color(0.86, 0.76, 0.50)]},
}

const RY_F := 0.5        # el alto del ovalo de un circulo de la torre, respecto a su ancho (la vista del pueblo)
# (22/11, el jefe: "mas ancha, mas como las otras casas y mas baja, pero con esa forma") el cuerpo casi llena el ancho
# de sus 3 casillas (96 px) y el disco llega al borde.
const R := 37            # radio del cuerpo
const R_ZOCALO := 46     # radio del disco de piedra de abajo
const ZOCALO_ALTO := 6   # el canto del disco
const ALERO := 8         # lo que vuela el tejado por fuera del cuerpo
const CONO := 60         # lo alto del cono (de su base a la punta, en pantalla)
const LADRILLO_ALTO := 6
const LADRILLO_ANCHO := 11


static func _px(d: PackedByteArray, w: int, h: int, x: int, y: int, c: Color) -> void:
	PuebloSprites._px(d, w, h, x, y, c)


static func _rnd(x: int, y: int, s: int) -> float:
	return PuebloSprites._rnd(x, y, s)


static func _tono(r: Array, v: float) -> Color:
	return r[clampi(int(v * float(r.size())), 0, r.size() - 1)]


# La luz de una columna del cilindro: de la izquierda y un poco de frente (t = -1 borde izquierdo, +1 el derecho).
static func _luz(t: float) -> float:
	var frente: float = sqrt(maxf(0.0, 1.0 - t * t))
	return clampf(0.30 + 0.62 * frente - 0.38 * t, 0.0, 0.999)


# Lo que baja por delante un circulo de radio 'r' en la columna t (el ovalo).
static func _baja(r: float, t: float) -> float:
	return r * RY_F * sqrt(maxf(0.0, 1.0 - t * t))


# EL DIBUJO ENTERO en un lienzo de w x h.
static func generar(w: int, h: int, paleta: String) -> Image:
	var p: Dictionary = PALETAS.get(paleta, PALETAS["A"])
	var d := PackedByteArray()
	d.resize(w * h * 4)
	var cx: int = w / 2
	# EL CENTRO DE LA BASE: con el disco DELANTE, tocando el borde de la huella (donde las casas tienen la fachada y
	# llega el camino de la puerta). En el centro de sus casillas quedaba una franja de hierba hasta el camino.
	var base: int = h - int(R_ZOCALO * RY_F) - ZOCALO_ALTO - 2
	var alero: int = CONO + 30     # el centro del ovalo del alero (donde el tejado se apoya): el cono y su cristal encima
	_zocalo(d, w, h, cx, base, p)
	_cuerpo(d, w, h, cx, base, alero, p)
	_cornisa(d, w, h, cx, base, 70, p)          # la que parte la torre en dos pisos (70 px sobre la base)
	_anillo_runas(d, w, h, cx, base, 78, p)     # a 78 px sobre la base
	_ventanas(d, w, h, cx, base, p)
	_sello(d, w, h, cx, base, p)
	_puerta(d, w, h, cx, base, p)
	_tejado(d, w, h, cx, alero, p)
	_cristal(d, w, h, cx, alero - CONO, p)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, d)


# EL ZOCALO: un disco de sillares con su cara de ARRIBA a la vista (el anillo claro alrededor de la torre) y su canto.
static func _zocalo(d: PackedByteArray, w: int, h: int, cx: int, base: int, p: Dictionary) -> void:
	var ry: float = R_ZOCALO * RY_F
	var arriba: int = base - ZOCALO_ALTO / 2    # el centro del ovalo de su cara de arriba
	for x in range(cx - R_ZOCALO, cx + R_ZOCALO + 1):
		var t: float = float(x - cx) / float(R_ZOCALO)
		var c: float = sqrt(maxf(0.0, 1.0 - t * t))
		var y_atras: int = arriba - int(ry * c)
		var y_delante: int = arriba + int(ry * c)
		# LA CARA DE ARRIBA (losas en anillos), de atras a delante.
		for y in range(y_atras, y_delante + 1):
			var dy: float = float(y - arriba) / ry
			var rr: float = sqrt(t * t + dy * dy)   # lo lejos del centro, en radios
			var junta: bool = absf(fposmod(rr * 3.0, 1.0)) < 0.12 or absf(fposmod(atan2(dy, t) * 2.5, 1.0)) < 0.06
			var v: float = 0.78 - rr * 0.22 - (0.25 if junta else 0.0) + (_rnd(x / 3, y / 3, 3) - 0.5) * 0.08
			_px(d, w, h, x, y, _tono(p["piedra"], v))
		_px(d, w, h, x, y_atras - 1, NEGRO)
		# EL CANTO por delante.
		for k in ZOCALO_ALTO:
			var y2: int = y_delante + 1 + k
			var junta2: bool = k == ZOCALO_ALTO - 1 or int(floor(asin(clampf(t, -1, 1)) * R_ZOCALO / 14.0)) != int(floor(asin(clampf(t + 1.0 / R_ZOCALO, -1, 1)) * R_ZOCALO / 14.0))
			_px(d, w, h, x, y2, _tono(p["piedra"], _luz(t) * 0.8 - (0.2 if junta2 else 0.0)))
		_px(d, w, h, x, y_delante + 1 + ZOCALO_ALTO, NEGRO)
	for y in range(arriba, arriba + ZOCALO_ALTO + 1):
		_px(d, w, h, cx - R_ZOCALO - 1, y, NEGRO)
		_px(d, w, h, cx + R_ZOCALO + 1, y, NEGRO)


# EL CUERPO: un cilindro de ladrillo sombreado por columnas; las filas se curvan como ovalos (lo de delante, mas abajo)
# y los ladrillos se reparten por el angulo (los de los lados salen estrechos).
static func _cuerpo(d: PackedByteArray, w: int, h: int, cx: int, base: int, alero: int, p: Dictionary) -> void:
	var suelo_z: int = base - ZOCALO_ALTO / 2   # donde la torre entra en el disco
	for x in range(cx - R, cx + R + 1):
		var t: float = float(x - cx) / float(R)
		var baja: float = _baja(R, t)
		var ang: float = asin(clampf(t, -1.0, 1.0)) * float(R)
		var ang2: float = asin(clampf(t + 1.0 / R, -1.0, 1.0)) * float(R)
		for y in range(alero - 10, suelo_z + int(baja) + 1):
			var alto: float = float(suelo_z) + baja - float(y)   # la altura sobre el disco de este punto de la pared
			var fila: int = int(floor(alto / LADRILLO_ALTO))
			var desfase: float = 0.0 if fila % 2 == 0 else LADRILLO_ANCHO * 0.5
			var junta: bool = fposmod(alto, LADRILLO_ALTO) < 1.0 \
				or int(floor((ang + desfase) / LADRILLO_ANCHO)) != int(floor((ang2 + desfase) / LADRILLO_ANCHO))
			var v: float = _luz(t) + (_rnd(int(floor((ang + desfase) / LADRILLO_ANCHO)) + 50, fila, 11) - 0.5) * 0.12
			if junta:
				v -= 0.25
			_px(d, w, h, x, y, _tono(p["piedra"], v))
	for y in range(alero - 10, suelo_z + 1):
		_px(d, w, h, cx - R - 1, y, NEGRO)
		_px(d, w, h, cx + R + 1, y, NEGRO)


# Una CORNISA: una franja de piedra clara que vuela un poco, curvada como la torre, con su sombra debajo.
static func _cornisa(d: PackedByteArray, w: int, h: int, cx: int, base: int, alto: int, p: Dictionary) -> void:
	var y0: int = base - ZOCALO_ALTO / 2 - alto
	for x in range(cx - R - 2, cx + R + 3):
		var t: float = float(x - cx) / float(R + 2)
		var y: int = y0 + int(_baja(R + 2, t))
		_px(d, w, h, x, y - 1, _tono(p["piedra"], _luz(t) + 0.3))
		_px(d, w, h, x, y, _tono(p["piedra"], _luz(t) + 0.15))
		_px(d, w, h, x, y + 1, _tono(p["piedra"], _luz(t) - 0.1))
		_px(d, w, h, x, y + 2, Color(0, 0, 0, 0.4))


# EL ANILLO DE RUNAS: una banda oscura alrededor con glifos que brillan, mas encendidos por delante.
static func _anillo_runas(d: PackedByteArray, w: int, h: int, cx: int, base: int, alto: int, p: Dictionary) -> void:
	var y0: int = base - ZOCALO_ALTO / 2 - alto
	for x in range(cx - R, cx + R + 1):
		var t: float = float(x - cx) / float(R)
		var y_b: int = y0 + int(_baja(R, t))
		for k in 8:
			_px(d, w, h, x, y_b + k, _tono(p["piedra"], _luz(t) * 0.35))
		var ang: float = asin(clampf(t, -1.0, 1.0)) * float(R)
		var celda: int = int(floor(ang / 7.0))
		var dentro: float = fposmod(ang, 7.0)
		var frente: float = sqrt(maxf(0.0, 1.0 - t * t))
		if frente < 0.3 or dentro < 1.5 or dentro > 5.5:
			continue
		for k in range(1, 7):
			if _rnd(celda, k, 23) > 0.45:
				_px(d, w, h, x, y_b + k, p["brillo"][2] if frente > 0.7 else p["brillo"][1])


# EL SITIO DE UNA COSA en la pared: a 'alto' sobre el disco y en la columna x (su arriba-izquierda en pantalla).
static func _en_pared(cx: int, base: int, x: int, alto: int, vh: int) -> int:
	var t: float = float(x - cx) / float(R)
	return base - ZOCALO_ALTO / 2 - alto - vh + int(_baja(R, t))


# LAS VENTANAS: una grande en arco por piso en el centro y estrechas a los lados (de perfil), encendidas con su halo.
static func _ventanas(d: PackedByteArray, w: int, h: int, cx: int, base: int, p: Dictionary) -> void:
	# [columna respecto al centro, ancho, alto, altura sobre el disco]
	for v in [[0, 10, 14, 92], [-24, 5, 11, 94], [24, 5, 11, 94], [-15, 6, 12, 98], [15, 6, 12, 98],
			[0, 8, 12, 52], [-25, 5, 12, 46], [25, 5, 12, 46]]:
		var x0: int = cx + int(v[0]) - int(v[1]) / 2
		_ventana_arco(d, w, h, x0, _en_pared(cx, base, cx + int(v[0]), int(v[3]), int(v[2])), int(v[1]), int(v[2]), p)


static func _ventana_arco(d: PackedByteArray, w: int, h: int, x0: int, y0: int, vw: int, vh: int, p: Dictionary) -> void:
	var r: float = vw * 0.5
	for y in range(y0 - 2, y0 + vh + 2):
		for x in range(x0 - 2, x0 + vw + 2):
			if _dentro_arco(x - x0, y - y0, vw, vh, r):
				continue
			if _dentro_arco(x - x0 + 2, y - y0 + 2, vw + 4, vh + 4, r + 2.0) and _rnd(x, y, 5) > 0.35:
				_px(d, w, h, x, y, Color(p["brillo"][0], 0.55))
	for y in range(y0, y0 + vh):
		for x in range(x0, x0 + vw):
			if not _dentro_arco(x - x0, y - y0, vw, vh, r):
				continue
			var borde: bool = not _dentro_arco(x - x0 - 1, y - y0, vw, vh, r) or not _dentro_arco(x - x0 + 1, y - y0, vw, vh, r) \
				or not _dentro_arco(x - x0, y - y0 - 1, vw, vh, r)
			if borde:
				_px(d, w, h, x, y, NEGRO)
				continue
			var v: float = float(y - y0) / float(vh)
			var c: Color = p["brillo"][1] if v < 0.45 else p["brillo"][2]
			if vw >= 8 and x == x0 + vw / 2:
				c = p["brillo"][0]
			if v > 0.8 and absi(x - (x0 + vw / 2)) <= 1:
				c = p["brillo"][3]
			_px(d, w, h, x, y, c)
	for x in range(x0 - 1, x0 + vw + 1):
		_px(d, w, h, x, y0 + vh, p["oro"][1])


static func _dentro_arco(x: int, y: int, vw: int, vh: int, r: float) -> bool:
	if x < 0 or x >= vw or y < 0 or y >= vh:
		return false
	if float(y) >= r:
		return true
	var dx: float = float(x) + 0.5 - r
	var dy: float = r - float(y) - 0.5
	return dx * dx + dy * dy <= r * r


# EL SELLO encima de la puerta: un circulo magico que brilla (aro, aro de dentro y una estrella).
static func _sello(d: PackedByteArray, w: int, h: int, cx: int, base: int, p: Dictionary) -> void:
	var cy: int = _en_pared(cx, base, cx, 38, 0)
	for y in range(cy - 10, cy + 11):
		for x in range(cx - 10, cx + 11):
			var dd: float = Vector2(x - cx, y - cy).length()
			if dd > 9.5 and dd < 11.0 and _rnd(x, y, 41) > 0.4:
				_px(d, w, h, x, y, Color(p["brillo"][0], 0.6))
			elif dd >= 8.0 and dd < 9.5:
				_px(d, w, h, x, y, p["brillo"][1])
			elif dd >= 5.0 and dd < 6.0:
				_px(d, w, h, x, y, p["brillo"][0])
			elif dd < 5.0:
				_px(d, w, h, x, y, Color(p["piedra"][0]).darkened(0.3))
	for k in range(-7, 8):
		_px(d, w, h, cx + k, cy, p["brillo"][2] if absi(k) < 4 else p["brillo"][1])
		_px(d, w, h, cx, cy + k, p["brillo"][2] if absi(k) < 4 else p["brillo"][1])
	for k in range(-3, 4):
		_px(d, w, h, cx + k, cy + k, p["brillo"][1])
		_px(d, w, h, cx + k, cy - k, p["brillo"][1])
	_px(d, w, h, cx, cy, p["brillo"][3])


# LA PUERTA: alta, en arco, de madera oscura con herrajes de oro, la luz por la rendija y el escalon sobre el disco.
static func _puerta(d: PackedByteArray, w: int, h: int, cx: int, base: int, p: Dictionary) -> void:
	var pw: int = 16
	var ph: int = 26
	var x0: int = cx - pw / 2
	var y0: int = _en_pared(cx, base, cx, 0, ph)
	var r: float = pw * 0.5
	for y in range(y0 - 2, y0 + ph):
		for x in range(x0 - 2, x0 + pw + 2):
			var dentro: bool = _dentro_arco(x - x0, y - y0, pw, ph, r)
			var marco: bool = _dentro_arco(x - x0 + 2, y - y0 + 2, pw + 4, ph + 2, r + 2.0) and not dentro
			if marco:
				_px(d, w, h, x, y, p["oro"][0] if (x + y) % 5 != 0 else p["oro"][1])
			elif dentro:
				var c: Color = Color(0.22, 0.13, 0.08) if (x - x0) % 4 != 0 else Color(0.14, 0.08, 0.05)
				if (y - y0) == ph / 2 or (y - y0) == ph - 6:
					c = p["oro"][1]
				_px(d, w, h, x, y, c)
	for x in range(x0, x0 + pw):
		_px(d, w, h, x, y0 + ph - 1, p["brillo"][2])
	# El escalon: un medio ovalo claro delante de la puerta, sobre el disco.
	for x in range(x0 - 4, x0 + pw + 4):
		var t: float = float(x - cx) / float(pw / 2 + 4)
		var ext: int = int(sqrt(maxf(0.0, 1.0 - t * t)) * 4.0)
		for k in range(0, ext + 1):
			_px(d, w, h, x, y0 + ph + k, p["piedra"][3] if k == 0 else p["piedra"][2])
		_px(d, w, h, x, y0 + ph + ext + 1, p["piedra"][0])


# EL TEJADO: un cono VISTO DESDE ARRIBA. Su base es un ovalo (el alero, de radio R + ALERO) con centro en 'alero' y la
# punta CONO px por encima. Cada punto del cono esta en el ovalo de su altura k (0 punta, 1 alero), centro
# alero - CONO * (1 - k), radio k * rb: el de delante se ve, el de atras lo tapa el propio cono.
static func _tejado(d: PackedByteArray, w: int, h: int, cx: int, alero: int, p: Dictionary) -> void:
	var rb: float = float(R + ALERO)
	var ryb: float = rb * RY_F
	var punta: int = alero - CONO
	for y in range(punta, alero + int(ryb) + 2):
		for x in range(cx - int(rb) - 1, cx + int(rb) + 2):
			var k: float = _k_cono(float(x - cx), float(y), float(alero), rb, ryb)
			if k < 0.0:
				continue
			var t: float = float(x - cx) / maxf(k * rb, 0.5)
			var v: float = _luz(clampf(t, -1.0, 1.0)) * 0.9 + (1.0 - k) * 0.15
			# LAS ESCAMAS: filas por k (siguen el ovalo) y, dentro de cada fila, mitades redondeadas por el angulo.
			var fila_f: float = k * 13.0
			var fila: int = int(floor(fila_f))
			var dentro_f: float = fposmod(fila_f, 1.0)
			var escama: float = fposmod(asin(clampf(t, -1, 1)) * k * rb + (3.0 if fila % 2 == 0 else 0.0), 6.0)
			if dentro_f < 0.18 or (dentro_f > 0.7 and (escama < 1.0 or escama > 5.0)):
				v -= 0.3
			_px(d, w, h, x, y, _tono(p["tejado"], v + (_rnd(x / 3, y / 3, 13) - 0.5) * 0.08))
	# EL CONTORNO de los dos lados del cono.
	for y in range(punta, alero + 1):
		var k2: float = float(y - punta) / float(CONO)
		_px(d, w, h, cx - int(k2 * rb) - 1, y, NEGRO)
		_px(d, w, h, cx + int(k2 * rb) + 1, y, NEGRO)
	# EL ALERO: el borde de oro por DELANTE (medio ovalo) y la sombra que echa sobre la pared.
	for x in range(cx - int(rb), cx + int(rb) + 1):
		var t3: float = float(x - cx) / rb
		var y_b: int = alero + int(ryb * sqrt(maxf(0.0, 1.0 - t3 * t3)))
		_px(d, w, h, x, y_b, p["oro"][2] if t3 < -0.2 else p["oro"][1])
		_px(d, w, h, x, y_b + 1, p["oro"][0])
		_px(d, w, h, x, y_b + 2, NEGRO)
		if absf(t3) <= float(R) / rb:
			for k3 in range(3, 7):
				_px(d, w, h, x, y_b + k3, Color(0, 0, 0, 0.5 - k3 * 0.06))
	# Una VENTANA de buhardilla en la cara de delante del cono.
	_ventana_arco(d, w, h, cx - 3, alero - 24, 6, 10, p)


# ¿Que fila del cono (k, 0 punta y 1 alero) se ve en (dx, y)? -1 si ahi no hay cono. Se mira la cara de DELANTE:
# para cada k, el ovalo de esa altura llega por delante a centro_k + k*ryb*sqrt(1 - (dx/(k*rb))^2). Busqueda por pasos.
static func _k_cono(dx: float, y: float, alero: float, rb: float, ryb: float) -> float:
	var mejor: float = -1.0
	var pasos: int = 60
	for i in range(1, pasos + 1):
		var k: float = float(i) / float(pasos)
		var rk: float = k * rb
		if absf(dx) > rk:
			continue
		var centro: float = alero - CONO * (1.0 - k)
		var delante: float = centro + k * ryb * sqrt(maxf(0.0, 1.0 - (dx / rk) * (dx / rk)))
		# Este ovalo pasa por y si 'y' esta entre su cara de atras y la de delante; la de delante es la que se ve.
		if y <= delante + 0.5 and y >= centro - CONO * 0.02:
			if absf(y - delante) < 1.0:
				return k
			if mejor < 0.0 and y < delante:
				mejor = k
	return mejor


# EL CRISTAL FLOTANDO sobre la punta: la aguja de oro y, encima y despegado, un cristal con su halo y sus chispas.
static func _cristal(d: PackedByteArray, w: int, h: int, cx: int, punta: int, p: Dictionary) -> void:
	for y in range(punta - 6, punta + 2):
		_px(d, w, h, cx, y, p["oro"][1])
	_px(d, w, h, cx - 1, punta - 2, p["oro"][0])
	_px(d, w, h, cx + 1, punta - 2, p["oro"][0])
	var cy: int = punta - 14
	for y in range(cy - 9, cy + 10):
		for x in range(cx - 8, cx + 9):
			var dd: float = Vector2(x - cx, (y - cy) * 0.8).length()
			if dd < 8.5 and dd > 4.5 and _rnd(x, y, 31) > 0.5:
				_px(d, w, h, x, y, Color(p["brillo"][1], 0.35))
	for y in range(cy - 7, cy + 8):
		var ancho: int = 4 - absi(y - cy) * 4 / 7
		for x in range(cx - ancho, cx + ancho + 1):
			var c: Color = p["brillo"][1]
			if x < cx:
				c = p["brillo"][2]
			if x == cx - 1 and y < cy:
				c = p["brillo"][3]
			if x == cx + ancho or x == cx - ancho or absi(y - cy) == 7:
				c = p["brillo"][0]
			_px(d, w, h, x, y, c)
	for ch in [Vector2i(-7, -5), Vector2i(6, 3), Vector2i(-5, 7)]:
		_px(d, w, h, cx + ch.x, cy + ch.y, p["brillo"][3])
