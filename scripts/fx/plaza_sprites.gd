# ============================================================
#  plaza_sprites.gd  (class_name PlazaSprites)
#  LO NUEVO DE LOS DOS PRADOS DEL NORTE (pedido del usuario el 22/09/2026): la PLAZA DE LA FUENTE al
#  oeste del hogar (fuente, bancos, arbolitos, parterres) y el MERCADILLO al este (puestos).
#
#  TODO CON LA CAMARA A 45 GRADOS (lo recalco el usuario: "nuestra vista es en 45, hazlos todos bien").
#  La primera version mezclaba camaras -- el pilon de la fuente visto desde arriba del todo y su taza
#  desde abajo, los puestos de frente como una fachada -- y no se leia. Aqui hay UNA sola proyeccion
#  para todo (ver _sy):
#    - lo HORIZONTAL (tapas, asientos, el agua, el toldo) se ve con el fondo encogido a K = cos 45;
#    - lo VERTICAL sube tal cual en pantalla;
#    - un circulo en el suelo es una elipse de alto K veces su ancho.
#  Coordenadas de cada pieza: x en px, 'p' = fondo contado desde el borde SUR de su huella hacia el
#  norte, 'z' = altura. Todo se apoya en el borde de abajo del lienzo, que es el borde sur de la huella.
#
#  LOS PUESTOS siguen la referencia que paso el usuario (toldo crema a rayas con festón, armazon de
#  madera, estante al fondo, cajas de genero en el mostrador y cestos debajo), pero CON FONDO: el
#  mostrador delante, el hueco del vendedor detras y el toldo por encima, visto desde arriba.
# ============================================================

extends RefCounted
class_name PlazaSprites

const K := 0.7071

const PIEZAS := {
	"fuente": {"tam": Vector2i(96, 104), "pie": 64},
	# Bancos: el sufijo es hacia donde MIRA quien se sienta (s = hacia la camara).
	"banco_s": {"tam": Vector2i(32, 48), "pie": 32},
	"banco_n": {"tam": Vector2i(32, 48), "pie": 32},
	"banco_e": {"tam": Vector2i(32, 48), "pie": 32},
	"banco_o": {"tam": Vector2i(32, 48), "pie": 32},
	"arbolito": {"tam": Vector2i(32, 80), "pie": 12},
	"parterre": {"tam": Vector2i(32, 40), "pie": 32},
	"puesto_pan": {"tam": Vector2i(96, 140), "pie": 64},
	"puesto_verdura": {"tam": Vector2i(96, 140), "pie": 64},
	"puesto_fruta": {"tam": Vector2i(96, 140), "pie": 64},
	"puesto_especias": {"tam": Vector2i(96, 140), "pie": 64},
}

const NEGRO := Color(0.06, 0.05, 0.05)
const PIEDRA := PuebloSprites.PIEDRA
const MADERA := [Color(0.20, 0.12, 0.07), Color(0.33, 0.21, 0.12), Color(0.46, 0.31, 0.18), Color(0.58, 0.41, 0.25), Color(0.70, 0.53, 0.34)]
const AGUA := [Color(0.09, 0.22, 0.36), Color(0.14, 0.34, 0.52), Color(0.30, 0.56, 0.72), Color(0.78, 0.91, 0.98)]
const HOJA := [Color(0.10, 0.22, 0.10), Color(0.16, 0.34, 0.14), Color(0.25, 0.47, 0.19), Color(0.38, 0.60, 0.25), Color(0.52, 0.72, 0.32)]
const TOLDO := [Color(0.60, 0.50, 0.36), Color(0.77, 0.67, 0.49), Color(0.89, 0.81, 0.63), Color(0.97, 0.92, 0.78)]


static func _px(d: PackedByteArray, w: int, h: int, x: int, y: int, c: Color) -> void:
	PuebloSprites._px(d, w, h, x, y, c)


static func _rnd(x: int, y: int, s: int) -> float:
	return PuebloSprites._rnd(x, y, s)


static func generar(clave: String) -> PackedByteArray:
	match clave:
		"fuente":
			return _fuente()
		"banco_s", "banco_n", "banco_e", "banco_o":
			return _banco(clave.trim_prefix("banco_"))
		"arbolito":
			return _arbolito()
		"parterre":
			return _parterre()
		_:
			return _puesto(clave.trim_prefix("puesto_"))


# ============================================================
#  LA PROYECCION Y SUS AYUDAS
# ============================================================
# La y de pantalla de un punto de fondo 'p' y altura 'z', en un lienzo de alto 'h'.
static func _sy(h: int, p: float, z: float) -> float:
	return float(h) - p * K - z


# Una cara HORIZONTAL: el rectangulo x0..x1 (incluidos) entre los fondos p0 y p1, a la altura z.
# 'color' recibe (x, fila desde el fondo de atras) y devuelve el color.
static func _tapa(d: PackedByteArray, w: int, h: int, x0: int, x1: int, p0: float, p1: float, z: float, color: Callable) -> void:
	var y0: int = int(round(_sy(h, p1, z)))
	var y1: int = int(round(_sy(h, p0, z)))
	for y in range(y0, y1):
		for x in range(x0, x1 + 1):
			_px(d, w, h, x, y, color.call(x, y - y0))


# Una cara VERTICAL de frente (mirando al sur): x0..x1 en el fondo p, de z0 a z1.
static func _frente(d: PackedByteArray, w: int, h: int, x0: int, x1: int, p: float, z0: float, z1: float, color: Callable) -> void:
	var y0: int = int(round(_sy(h, p, z1)))
	var y1: int = int(round(_sy(h, p, z0)))
	for y in range(y0, y1):
		for x in range(x0, x1 + 1):
			_px(d, w, h, x, y, color.call(x, y - y0))


static func _liso(c: Color) -> Callable:
	return func(_x: int, _f: int) -> Color: return c


# Un cilindro de pie. 'cy' = y de pantalla del CENTRO de su base; la tapa es una elipse de r x r*K.
static func _cilindro(d: PackedByteArray, w: int, h: int, cx: float, cy: float, r: float, alto: float,
		rampa: Array, tapa: Color) -> void:
	var ry: float = r * K
	var arriba: float = cy - alto
	for y in range(int(arriba - ry) - 1, int(cy + ry) + 2):
		for x in range(int(cx - r) - 1, int(cx + r) + 2):
			var dx: float = float(x) + 0.5 - cx
			if absf(dx) > r:
				continue
			var q: float = sqrt(maxf(0.0, 1.0 - pow(dx / r, 2.0)))
			var fy: float = float(y) + 0.5
			var col: Color
			if pow(dx / r, 2.0) + pow((fy - arriba) / ry, 2.0) <= 1.0:
				col = tapa
			elif fy >= arriba and fy <= cy + ry * q:
				var u: float = (dx + r) / (2.0 * r)
				col = rampa[2] if u < 0.35 else (rampa[1] if u < 0.72 else rampa[0])
			else:
				continue
			_px(d, w, h, x, y, col)


# Una elipse rellena en el plano (el agua, una sombra): centro en pantalla y radio en el suelo.
static func _elipse(d: PackedByteArray, w: int, h: int, cx: float, cy: float, r: float, c: Color) -> void:
	var ry: float = r * K
	for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for x in range(int(cx - r) - 1, int(cx + r) + 2):
			if pow((float(x) + 0.5 - cx) / r, 2.0) + pow((float(y) + 0.5 - cy) / ry, 2.0) <= 1.0:
				_px(d, w, h, x, y, c)


# ============================================================
#  LA FUENTE (3x2)
# ============================================================
# Un pilon redondo de piedra, con el agua un poco por debajo del borde, y en medio un pedestal con una
# taza arriba. Visto a 45 el circulo del pilon es una elipse de 88 x 62: por eso la huella es de 3x2.
# El agua que cae y las ondas van aparte (agua_fotograma / AguaFuente), para que se muevan.
const F_R := 44.0        # radio de fuera
const F_RIN := 37.0      # radio de dentro (lo que queda es la corona del borde)
const F_ALTO := 14.0     # lo que sube el pilon
const F_AGUA := 10.0     # a que altura esta el agua
const F_COLUMNA := 26.0  # lo que sube la columna desde su zocalo
const F_TAZA_R := 14.0

static func _centro_fuente() -> Vector2:
	var h: int = PIEZAS["fuente"]["tam"].y
	return Vector2(48.0, float(h) - 2.0 - F_R * K)


# El centro de la BOCA de la taza, en px del lienzo (de ahi sale el chorro).
static func taza_boca() -> Vector2:
	var c: Vector2 = _centro_fuente()
	return Vector2(c.x, c.y - F_AGUA - 5.0 - F_COLUMNA - 5.0)


static func _fuente() -> PackedByteArray:
	var t: Vector2i = PIEZAS["fuente"]["tam"]
	var w: int = t.x
	var h: int = t.y
	var d := PuebloSprites._lienzo(t)
	var c: Vector2 = _centro_fuente()
	var cx: float = c.x
	var cy: float = c.y
	PuebloSprites._sombra_suelo(d, w, h, int(cx) + 3, int(cy) + 3, int(F_R) + 1, int(F_R * K) + 1)
	for y in h:
		for x in w:
			var px: float = float(x) + 0.5 - cx
			if absf(px) > F_R:
				continue
			var fy: float = float(y) + 0.5
			var col := Color(0, 0, 0, 0)
			var hay: bool = false
			# LA CARA de fuera: la mitad de delante del cilindro, del suelo al borde. Sillares curvos.
			var ys: float = cy + F_R * K * sqrt(1.0 - pow(px / F_R, 2.0))
			if fy <= ys and fy >= ys - F_ALTO:
				var sube: float = ys - fy
				var hilada: int = int(sube / 4.5)
				var arco: float = asin(clampf(px / F_R, -1.0, 1.0)) * F_R
				var u: float = fposmod(arco + float(hilada) * 5.0, 11.0)
				var luz: float = 0.60 - px / F_R * 0.22 + (_rnd(int(arco / 11.0), hilada, 91) - 0.5) * 0.12
				col = PuebloSprites._escalon(clampf(luz, 0.0, 0.99), PIEDRA)
				if u < 1.0 or fposmod(sube, 4.5) < 1.0:
					col = PIEDRA[1]
				hay = true
			# LO DE ARRIBA, a la altura del borde: la corona de losas y, dentro, el agua hundida.
			var py: float = (fy - (cy - F_ALTO)) / K
			var r: float = sqrt(px * px + py * py)
			if r <= F_R:
				hay = true
				if r >= F_RIN:
					var ang: float = (atan2(py, px) + PI) / TAU * 20.0
					col = PIEDRA[4] if r > F_RIN + 1.5 else PIEDRA[2]
					if fposmod(ang, 1.0) < 0.08:
						col = PIEDRA[2]
					if py > 0.0 and r > F_R - 1.5:
						col = PIEDRA[3]
				else:
					var pw: float = (fy - (cy - F_AGUA)) / K
					var rw: float = sqrt(px * px + pw * pw)
					if rw < F_RIN - 0.5:
						col = AGUA[1]
						# La sombra del borde sobre el agua, al fondo.
						if pw < -(F_RIN - 8.0):
							col = AGUA[0]
						elif _rnd(x, y, 17) > 0.975:
							col = AGUA[2]
					else:
						col = PIEDRA[1]       # la pared de dentro, que asoma al fondo
			if hay:
				_px(d, w, h, x, y, col)
	# EL PEDESTAL: zocalo en el agua, columna y la taza con su agua.
	var base: float = cy - F_AGUA
	_cilindro(d, w, h, cx, base, 8.0, 5.0, [PIEDRA[1], PIEDRA[2], PIEDRA[3]], PIEDRA[4])
	_cilindro(d, w, h, cx, base - 5.0, 4.0, F_COLUMNA, [PIEDRA[2], PIEDRA[3], PIEDRA[4]], PIEDRA[4])
	var taza: float = base - 5.0 - F_COLUMNA
	_cilindro(d, w, h, cx, taza + 3.0, 7.0, 3.0, [PIEDRA[1], PIEDRA[2], PIEDRA[3]], PIEDRA[3])
	_cilindro(d, w, h, cx, taza, F_TAZA_R, 5.0, [PIEDRA[1], PIEDRA[2], PIEDRA[3]], PIEDRA[4])
	_elipse(d, w, h, cx, taza - 5.0, F_TAZA_R - 3.0, AGUA[2])
	PuebloSprites._contorno(d, w, h)
	return d


# LOS FOTOGRAMAS DEL AGUA, del tamaño del lienzo de la fuente (se pintan encima): el chorro, lo que cae
# de la taza al pilon, las ondas y las salpicaduras. Misma proyeccion que la fuente.
const AGUA_FOTOGRAMAS := 6
const AGUA_FPS := 8.0

static func agua_fotograma(k: int) -> Image:
	var t: Vector2i = PIEZAS["fuente"]["tam"]
	var img := Image.create(t.x, t.y, false, Image.FORMAT_RGBA8)
	var fase: float = float(k) / float(AGUA_FOTOGRAMAS)
	var espuma: Color = AGUA[3]
	var claro := Color(AGUA[2].r, AGUA[2].g, AGUA[2].b, 0.9)
	var pon := func(x: int, y: int, c: Color) -> void:
		if x >= 0 and y >= 0 and x < t.x and y < t.y:
			img.set_pixel(x, y, c)
	var boca: Vector2 = taza_boca()
	var bx: int = int(boca.x)
	var by: int = int(boca.y)
	var c: Vector2 = _centro_fuente()
	var y_agua: float = c.y - F_AGUA
	# LAS ONDAS: dos anillos que salen del pedestal hacia el borde, en el plano del agua. Van primero:
	# lo que cae se pinta encima. Por detras de la columna no se ven.
	for anillo in 2:
		var radio: float = 11.0 + fposmod(fase + float(anillo) * 0.5, 1.0) * 23.0
		var alfa: float = 0.75 * (1.0 - (radio - 11.0) / 23.0) + 0.15
		for y in range(int(y_agua - F_RIN * K) - 1, int(y_agua + F_RIN * K) + 2):
			for x in range(int(c.x - F_RIN), int(c.x + F_RIN) + 1):
				var px: float = float(x) + 0.5 - c.x
				var pw: float = (float(y) + 0.5 - y_agua) / K
				var r: float = sqrt(px * px + pw * pw)
				if r > F_RIN - 2.0 or r < 9.5:
					continue
				if pw < 0.0 and absf(px) < 5.0:
					continue
				if absf(r - radio) < 0.6:
					pon.call(x, y, Color(AGUA[2].r, AGUA[2].g, AGUA[2].b, alfa))
	# EL CHORRO: sube de la taza y se abre en dos arcos que caen sobre su borde.
	for i in 8:
		var cc: Color = espuma if (i + k) % 3 == 0 else claro
		pon.call(bx, by - 2 - i, cc)
		if i < 6:
			pon.call(bx - 1, by - 2 - i, cc)
	for lado in [-1, 1]:
		for i in 13:
			var u: float = float(i) / 12.0
			var x: int = bx + int(round(float(lado) * u * (F_TAZA_R - 2.0)))
			var y: int = by - 9 + int(round(-3.0 * sin(u * PI) + u * 10.0))
			pon.call(x, y, espuma if (i + k * 2) % 4 == 0 else claro)
	# LO QUE CAE de la taza al pilon, por delante de la columna, a los dos lados.
	for lado in [-1, 1]:
		var x0: int = bx + lado * int(F_TAZA_R - 1.0)
		var y_cae: int = int(y_agua + 3.0)
		for y in range(by + 4, y_cae):
			var sep: int = int(float(y - by) * 0.10)
			var c2: Color = espuma if (y + k * 3) % 5 == 0 else Color(claro.r, claro.g, claro.b, 0.75)
			pon.call(x0 + lado * sep, y, c2)
		var sx: int = x0 + lado * int(float(y_cae - by) * 0.10)
		var salta: int = int(abs(sin(fase * TAU)) * 3.0)
		pon.call(sx - 2, y_cae - 1 - salta, espuma)
		pon.call(sx + 2, y_cae - 2 - (3 - salta), espuma)
		pon.call(sx, y_cae, claro)
	return img


# ============================================================
#  BANCOS (1 casilla)
# ============================================================
# Asiento de tablas a media altura y respaldo de dos listones. 'mira' es hacia donde queda uno sentado:
# s = de cara a la camara (respaldo detras), n = de espaldas (el respaldo tapa el asiento), e/o = de
# lado. De lado el respaldo se ve de canto, asi que lleva GROSOR (3 px) y la cara de arriba de cada
# liston clara: una raya de 1 px se leia como un palo.
const B_ASIENTO := 8.0    # altura del asiento
const B_LISTONES := [[11.0, 13.5], [15.5, 18.0]]   # los dos listones del respaldo [z0, z1]

static func _banco(mira: String) -> PackedByteArray:
	var t: Vector2i = PIEZAS["banco_s"]["tam"]
	var w: int = t.x
	var h: int = t.y
	var d := PuebloSprites._lienzo(t)
	if mira == "s" or mira == "n":
		# Asiento de este a oeste, de fondo 10 a 18. Respaldo detras (s) o delante (n).
		var p0: float = 10.0
		var p1: float = 18.0
		PuebloSprites._sombra_suelo(d, w, h, 17, int(_sy(h, 13.0, 0.0)) + 1, 13, 4)
		var p_resp: float = p1 if mira == "s" else p0
		if mira == "s":
			_respaldo_frente(d, w, h, 4, 27, p_resp)
		# Patas de atras (asoman un poco por debajo del asiento) y el asiento.
		for x in [5, 26]:
			_frente(d, w, h, x, x, p1 - 1.0, 0.0, B_ASIENTO - 2.0, _liso(MADERA[0]))
		_tapa(d, w, h, 4, 27, p0, p1, B_ASIENTO, func(_x: int, f: int) -> Color:
			return MADERA[4] if f % 3 != 2 else MADERA[3])
		_frente(d, w, h, 4, 27, p0, B_ASIENTO - 2.0, B_ASIENTO, _liso(MADERA[1]))
		for x in [5, 6, 25, 26]:
			_frente(d, w, h, x, x, p0, 0.0, B_ASIENTO - 2.0, _liso(MADERA[1] if x == 5 or x == 25 else MADERA[0]))
		if mira == "n":
			_respaldo_frente(d, w, h, 4, 27, p_resp)
	else:
		# De lado: asiento de norte a sur (fondo 4 a 28), x 13..19, respaldo al lado de la espalda.
		var x0: int = 13
		var x1: int = 19
		var pa: float = 4.0
		var pb: float = 28.0
		PuebloSprites._sombra_suelo(d, w, h, 17, int(_sy(h, 16.0, 0.0)), 7, 10)
		var xr: int = x0 - 3 if mira == "e" else x1 + 1     # el respaldo, 3 px de grueso
		# Patas del extremo de atras, que asoman por el lado.
		_frente(d, w, h, x0, x0 + 1, pb - 1.0, 0.0, B_ASIENTO - 2.0, _liso(MADERA[0]))
		_frente(d, w, h, x1 - 1, x1, pb - 1.0, 0.0, B_ASIENTO - 2.0, _liso(MADERA[0]))
		# El asiento: tablas a lo largo (juntas en x).
		_tapa(d, w, h, x0, x1, pa, pb, B_ASIENTO, func(x: int, _f: int) -> Color:
			return MADERA[2] if (x - x0) % 3 == 2 else (MADERA[4] if x < x0 + 3 else MADERA[3]))
		_frente(d, w, h, x0, x1, pa, B_ASIENTO - 2.0, B_ASIENTO, _liso(MADERA[1]))
		for x in [x0, x0 + 1, x1 - 1, x1]:
			_frente(d, w, h, x, x, pa, 0.0, B_ASIENTO - 2.0, _liso(MADERA[1] if x == x0 or x == x1 - 1 else MADERA[0]))
		# El respaldo de canto: los dos postes y los listones, cada uno con su cara de arriba clara.
		for pp in [pa, pb - 1.0]:
			_frente(d, w, h, xr, xr + 2, pp, 0.0, B_LISTONES[1][1], _liso(MADERA[1]))
		for l in B_LISTONES:
			var z0: float = float(l[0])
			var z1: float = float(l[1])
			var p := pb
			while p >= pa:
				var ya: int = int(round(_sy(h, p, z1)))
				var yb: int = int(round(_sy(h, p, z0)))
				for y in range(ya, yb):
					for x in range(xr, xr + 3):
						var col: Color = MADERA[3] if y == ya else MADERA[2]
						if (mira == "e" and x == xr + 2) or (mira == "o" and x == xr):
							col = MADERA[1] if y != ya else MADERA[3]
						_px(d, w, h, x, y, col)
				p -= 0.5
	PuebloSprites._contorno(d, w, h)
	return d


# El respaldo visto de frente (o de espaldas): dos postes y dos listones en el fondo p.
static func _respaldo_frente(d: PackedByteArray, w: int, h: int, x0: int, x1: int, p: float) -> void:
	for x in [x0, x0 + 1, x1 - 1, x1]:
		_frente(d, w, h, x, x, p, 0.0, float(B_LISTONES[1][1]) + 1.0, _liso(MADERA[2] if x == x0 or x == x1 - 1 else MADERA[1]))
	for l in B_LISTONES:
		_frente(d, w, h, x0, x1, p, float(l[0]), float(l[1]), func(_x: int, f: int) -> Color:
			return MADERA[4] if f == 0 else MADERA[3])


# ============================================================
#  ARBOLITO (1 casilla)
# ============================================================
# Tronco fino y copa redonda hecha de varias bolas (una bola se ve redonda desde cualquier camara), con
# luz arriba a la izquierda. La sombra en el suelo si va aplastada. El tronco se apoya donde el palo del
# poste de antorcha: choca y se corta igual.
static func _arbolito() -> PackedByteArray:
	var t: Vector2i = PIEZAS["arbolito"]["tam"]
	var w: int = t.x
	var h: int = t.y
	var d := PuebloSprites._lienzo(t)
	var suelo: int = h - 8
	PuebloSprites._sombra_suelo(d, w, h, 18, suelo, 14, int(14.0 * K))
	_cilindro(d, w, h, 16.0, float(suelo), 2.2, 30.0, MADERA, MADERA[2])
	var bolas := [[16, suelo - 50, 9], [9, suelo - 40, 8], [23, suelo - 41, 8], [16, suelo - 38, 10], [11, suelo - 33, 6], [21, suelo - 32, 6]]
	for b in bolas:
		var bx: int = int(b[0])
		var by: int = int(b[1])
		var br: float = float(b[2])
		for y in range(by - int(br) - 1, by + int(br) + 2):
			for x in range(bx - int(br) - 1, bx + int(br) + 2):
				var dx: float = float(x) + 0.5 - float(bx)
				var dy: float = float(y) + 0.5 - float(by)
				var r: float = sqrt(dx * dx + dy * dy)
				if r > br:
					continue
				var luz: float = 0.55 - (dx + dy) / (br * 2.6) - r / br * 0.25 + (_rnd(x, y, 33) - 0.5) * 0.25
				_px(d, w, h, x, y, PuebloSprites._escalon(clampf(luz, 0.0, 0.99), HOJA))
	PuebloSprites._contorno(d, w, h)
	return d


# ============================================================
#  PARTERRE (1 casilla)
# ============================================================
# Un arriate bajo de piedra con tierra y matas con flores.
const FLORES := [Color(0.90, 0.28, 0.30), Color(0.98, 0.84, 0.30), Color(0.93, 0.55, 0.78), Color(0.97, 0.97, 0.94), Color(0.62, 0.48, 0.90)]

static func _parterre() -> PackedByteArray:
	var t: Vector2i = PIEZAS["parterre"]["tam"]
	var w: int = t.x
	var h: int = t.y
	var d := PuebloSprites._lienzo(t)
	var x0: int = 3
	var x1: int = 28
	var pa: float = 3.0
	var pb: float = 27.0
	var alto: float = 6.0
	PuebloSprites._sombra_suelo(d, w, h, 17, int(_sy(h, 15.0, 0.0)) + 2, 15, 10)
	# La cara al sur, de sillares.
	_frente(d, w, h, x0, x1, pa, 0.0, alto, func(x: int, f: int) -> Color:
		return PIEDRA[1] if posmod(x + (f / 3) * 4, 8) == 0 or f == 2 else PIEDRA[2])
	# La tapa: corona de piedra y tierra dentro.
	var fila_max: int = int(round(_sy(h, pa, alto))) - int(round(_sy(h, pb, alto)))
	_tapa(d, w, h, x0, x1, pa, pb, alto, func(x: int, f: int) -> Color:
		var borde: bool = x < x0 + 2 or x > x1 - 2 or f < 2 or f > fila_max - 3
		if borde:
			return PIEDRA[4]
		return Color(0.30, 0.21, 0.13) if _rnd(x, f, 5) > 0.8 else Color(0.24, 0.16, 0.10))
	# Matas con flores: cada una sube un poco sobre la tierra.
	for k in 9:
		var fx: int = x0 + 4 + int(_rnd(k, 1, 71) * float(x1 - x0 - 7))
		var fp: float = pa + 4.0 + _rnd(k, 2, 71) * (pb - pa - 8.0)
		var fy: int = int(round(_sy(h, fp, alto)))
		for dd in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
			_px(d, w, h, fx + dd.x, fy + dd.y, HOJA[2 + (dd.x & 1)])
		var fc: Color = FLORES[k % FLORES.size()]
		_px(d, w, h, fx, fy - 2, fc)
		_px(d, w, h, fx - 1, fy - 2, fc.darkened(0.2))
		_px(d, w, h, fx, fy - 3, fc.lightened(0.25))
	PuebloSprites._contorno(d, w, h)
	return d


# ============================================================
#  PUESTOS DEL MERCADILLO (3x2)
# ============================================================
# De delante hacia atras: los postes de delante, el MOSTRADOR (tapa vista desde arriba con tres cajas de
# genero, y en su frente tres huecos con cestos), el HUECO DEL VENDEDOR, el ESTANTE del fondo y, por
# encima de todo, el TOLDO a rayas visto desde arriba, inclinado hacia delante, con su festón.
#
# OJO PARA CUANDO LLEGUEN LOS VENDEDORES: el vendedor queda de pie DENTRO de la huella, entre el
# mostrador y el estante. Hoy el puesto es una sola pieza (PiezaPueblo), que da por hecho que nadie se
# mete en su huella; para ponerle a alguien dentro habra que partirla en capas (estante, mostrador,
# toldo) y meter al vendedor en medio. Las medidas de aqui ya dejan el hueco (P_VENDEDOR).
const GENERO := {
	# [estante, cajas del mostrador (3), cestos (3)]: cada uno una rampa [oscuro, medio, claro].
	"pan": [
		[[Color(0.45, 0.25, 0.10), Color(0.72, 0.46, 0.20), Color(0.90, 0.68, 0.36)]],
		[[Color(0.62, 0.52, 0.40), Color(0.85, 0.78, 0.64), Color(0.97, 0.93, 0.82)],
			[Color(0.45, 0.25, 0.10), Color(0.70, 0.44, 0.18), Color(0.88, 0.64, 0.32)],
			[Color(0.50, 0.30, 0.12), Color(0.78, 0.54, 0.24), Color(0.94, 0.76, 0.42)]],
		[[Color(0.55, 0.30, 0.10), Color(0.84, 0.52, 0.20), Color(0.97, 0.72, 0.36)]],
	],
	"verdura": [
		[[Color(0.55, 0.10, 0.08), Color(0.84, 0.22, 0.14), Color(0.98, 0.50, 0.36)],
			[Color(0.60, 0.28, 0.05), Color(0.90, 0.50, 0.12), Color(0.99, 0.72, 0.34)],
			[Color(0.12, 0.34, 0.10), Color(0.28, 0.58, 0.18), Color(0.52, 0.80, 0.32)]],
		[[Color(0.55, 0.10, 0.08), Color(0.82, 0.20, 0.14), Color(0.98, 0.48, 0.34)],
			[Color(0.24, 0.12, 0.30), Color(0.42, 0.24, 0.52), Color(0.64, 0.46, 0.74)],
			[Color(0.12, 0.34, 0.10), Color(0.30, 0.60, 0.20), Color(0.56, 0.82, 0.36)]],
		[[Color(0.52, 0.38, 0.18), Color(0.78, 0.62, 0.34), Color(0.93, 0.84, 0.56)],
			[Color(0.40, 0.26, 0.14), Color(0.60, 0.42, 0.24), Color(0.78, 0.60, 0.38)]],
	],
	"fruta": [
		[[Color(0.55, 0.08, 0.10), Color(0.86, 0.18, 0.18), Color(0.99, 0.46, 0.40)],
			[Color(0.62, 0.30, 0.04), Color(0.94, 0.56, 0.10), Color(0.99, 0.78, 0.36)],
			[Color(0.58, 0.50, 0.08), Color(0.90, 0.82, 0.22), Color(0.99, 0.96, 0.56)]],
		[[Color(0.22, 0.10, 0.28), Color(0.44, 0.22, 0.54), Color(0.66, 0.46, 0.78)],
			[Color(0.20, 0.40, 0.10), Color(0.44, 0.70, 0.22), Color(0.70, 0.90, 0.42)],
			[Color(0.55, 0.08, 0.10), Color(0.84, 0.18, 0.18), Color(0.99, 0.46, 0.40)]],
		[[Color(0.62, 0.30, 0.04), Color(0.94, 0.56, 0.10), Color(0.99, 0.78, 0.36)],
			[Color(0.44, 0.46, 0.10), Color(0.72, 0.76, 0.22), Color(0.90, 0.92, 0.46)]],
	],
	# Especias y aceite: en el estante, frascos de aceite (dorado), botes de especias (rojo) y de hierbas
	# (verde), que se pintan como BOTELLAS (ver _botellas); en las cajas ajos, cebollas y sal; en los
	# cestos guindillas y hierbas secas.
	"especias": [
		[[Color(0.50, 0.36, 0.06), Color(0.82, 0.66, 0.16), Color(0.98, 0.90, 0.50)],
			[Color(0.50, 0.12, 0.06), Color(0.78, 0.26, 0.10), Color(0.96, 0.52, 0.28)],
			[Color(0.18, 0.32, 0.12), Color(0.36, 0.54, 0.22), Color(0.60, 0.76, 0.40)]],
		[[Color(0.66, 0.62, 0.56), Color(0.90, 0.87, 0.80), Color(0.99, 0.98, 0.95)],
			[Color(0.42, 0.20, 0.30), Color(0.66, 0.36, 0.44), Color(0.86, 0.60, 0.62)],
			[Color(0.70, 0.70, 0.72), Color(0.88, 0.88, 0.90), Color(0.99, 0.99, 1.00)]],
		[[Color(0.52, 0.06, 0.06), Color(0.82, 0.14, 0.10), Color(0.98, 0.42, 0.30)],
			[Color(0.30, 0.34, 0.14), Color(0.50, 0.56, 0.26), Color(0.70, 0.76, 0.44)]],
	],
}

# Fondos (p) y alturas (z) del puesto.
const P_MOSTRADOR := [10.0, 24.0]     # de delante a atras
const Z_MOSTRADOR := 24.0
const P_VENDEDOR := 34.0               # donde se pondra el vendedor
const P_ESTANTE := [48.0, 58.0]
const Z_ESTANTE := 44.0
const P_POSTE_DELANTE := 11.0
const P_POSTE_DETRAS := 57.0
const TOLDO_DELANTE := [6.0, 80.0]     # [p, z] del borde de delante
const TOLDO_DETRAS := [62.0, 92.0]     # [p, z] del borde de atras

static func _puesto(tipo: String) -> PackedByteArray:
	var t: Vector2i = PIEZAS["puesto_pan"]["tam"]
	var w: int = t.x
	var h: int = t.y
	var d := PuebloSprites._lienzo(t)
	var genero: Array = GENERO.get(tipo, GENERO["verdura"])
	# La sombra del toldo en el suelo, de todo el puesto.
	var ys0: int = int(round(_sy(h, 60.0, 0.0)))
	var ys1: int = int(round(_sy(h, 2.0, 0.0)))
	for y in range(ys0, ys1):
		for x in range(3, 94):
			_px(d, w, h, x, y, Color(0, 0, 0, 0.22))
	# LOS POSTES DE ATRAS, del suelo al toldo.
	var z_toldo_atras: float = _z_toldo(P_POSTE_DETRAS)
	for px_ in [5, 88]:
		_frente(d, w, h, px_, px_ + 2, P_POSTE_DETRAS, 0.0, z_toldo_atras, func(x: int, _f: int) -> Color:
			return MADERA[2] if x == px_ else MADERA[1])
	# EL ESTANTE DEL FONDO: un mueble de tablas con dos baldas llenas de genero.
	var e0: float = P_ESTANTE[0]
	var e1: float = P_ESTANTE[1]
	_tapa(d, w, h, 8, 87, e0, e1, Z_ESTANTE, _liso(MADERA[3]))
	_frente(d, w, h, 8, 87, e0, 0.0, Z_ESTANTE, func(x: int, _f: int) -> Color:
		return MADERA[0] if posmod(x, 8) == 0 else MADERA[1])
	var estante: Array = genero[0]
	for balda in [[16.0, 0], [32.0, 1]]:
		var zb: float = float(balda[0])
		var yb: int = int(round(_sy(h, e0, zb)))
		_frente(d, w, h, 8, 87, e0, zb - 2.0, zb, _liso(MADERA[3]))
		for i in 3:
			var rampa: Array = estante[(i + int(balda[1])) % estante.size()]
			if tipo == "pan":
				_hogazas(d, w, h, 11 + i * 26, yb - 2, 24, rampa)
			elif tipo == "especias":
				_botellas(d, w, h, 11 + i * 26, yb - 2, 24, rampa, int(balda[1]) == 0)
			else:
				_monton(d, w, h, 11 + i * 26, yb - 2, 23, 1, rampa, i + 10 + int(balda[1]) * 5)
	# EL TOLDO, por encima del hueco del vendedor y del estante.
	_toldo(d, w, h)
	# EL MOSTRADOR: frente de tablas con tres huecos y cestos, y la tapa vista desde arriba.
	var m0: float = P_MOSTRADOR[0]
	var m1: float = P_MOSTRADOR[1]
	_frente(d, w, h, 5, 90, m0, 0.0, Z_MOSTRADOR, func(_x: int, f: int) -> Color:
		return MADERA[1] if f % 5 == 4 else MADERA[2])
	var cestos: Array = genero[2]
	var y_frente_arriba: int = int(round(_sy(h, m0, Z_MOSTRADOR)))
	var y_suelo: int = int(round(_sy(h, m0, 0.0)))
	for i in 3:
		var hx: int = 9 + i * 27
		PuebloSprites._rect(d, w, h, hx, y_frente_arriba + 5, 24, y_suelo - y_frente_arriba - 6, MADERA[0])
		_cesto(d, w, h, hx + 3, y_suelo - 2, 18, cestos[i % cestos.size()], i + 30)
	for i in [0, 2]:
		var px0: int = 12 + i * 27
		PuebloSprites._rect(d, w, h, px0, y_frente_arriba + 1, 10, 4, Color(0.14, 0.13, 0.14))
		for k in 3:
			_px(d, w, h, px0 + 2 + k * 2, y_frente_arriba + 2, Color(0.86, 0.84, 0.78))
	_tapa(d, w, h, 5, 90, m0, m1, Z_MOSTRADOR, func(_x: int, f: int) -> Color:
		return MADERA[4] if f % 4 != 3 else MADERA[3])
	# LAS CAJAS DE GENERO sobre el mostrador: su frente y el monton de encima.
	var cajas: Array = genero[1]
	for i in 3:
		var cx0: int = 9 + i * 27
		var rampa2: Array = cajas[i % cajas.size()]
		var zc: float = Z_MOSTRADOR + 6.0
		_tapa(d, w, h, cx0, cx0 + 23, m0 + 2.0, m1 - 2.0, zc, _liso(rampa2[0]))
		var y_caja: int = int(round(_sy(h, m1 - 2.0, zc)))
		var y_boca: int = int(round(_sy(h, m0 + 2.0, zc)))
		_monton(d, w, h, cx0 + 1, y_boca, 22, int(float(y_boca - y_caja) / 2.0), rampa2, i + 20)
		_frente(d, w, h, cx0, cx0 + 23, m0 + 2.0, Z_MOSTRADOR, zc, func(x: int, _f: int) -> Color:
			return MADERA[1] if x == cx0 or x == cx0 + 23 else MADERA[3])
	# LOS POSTES DE DELANTE y el FESTON del toldo, delante de todo.
	var z_toldo_delante: float = _z_toldo(P_POSTE_DELANTE)
	for px_ in [2, 91]:
		_frente(d, w, h, px_, px_ + 2, P_POSTE_DELANTE, 0.0, z_toldo_delante, func(x: int, _f: int) -> Color:
			return MADERA[3] if x == px_ else MADERA[2])
	_feston(d, w, h)
	PuebloSprites._contorno(d, w, h)
	return d


# La altura del toldo sobre el fondo p (sube de delante a atras).
static func _z_toldo(p: float) -> float:
	var u: float = (p - float(TOLDO_DELANTE[0])) / (float(TOLDO_DETRAS[0]) - float(TOLDO_DELANTE[0]))
	return lerpf(float(TOLDO_DELANTE[1]), float(TOLDO_DETRAS[1]), u)


# El toldo visto desde arriba: una lona inclinada con rayas de delante a atras, el larguero de atras y
# los de los lados. Mas claro hacia delante (le da el sol) y oscuro al fondo.
static func _toldo(d: PackedByteArray, w: int, h: int) -> void:
	var pd: float = TOLDO_DELANTE[0]
	var pt: float = TOLDO_DETRAS[0]
	var y_atras: int = int(round(_sy(h, pt, _z_toldo(pt))))
	var y_delante: int = int(round(_sy(h, pd, _z_toldo(pd))))
	for y in range(y_atras, y_delante + 1):
		var u: float = float(y - y_atras) / float(maxi(1, y_delante - y_atras))
		for x in range(0, w):
			var raya: bool = posmod(x, 12) < 6
			var col: Color
			if u < 0.25:
				col = TOLDO[1] if raya else TOLDO[0]
			elif u < 0.7:
				col = TOLDO[2] if raya else TOLDO[1]
			else:
				col = TOLDO[3] if raya else TOLDO[2]
			if x < 2 or x > w - 3:
				col = MADERA[2]                 # los largueros de los lados
			_px(d, w, h, x, y, col)
	PuebloSprites._rect(d, w, h, 0, y_atras - 2, w, 2, MADERA[2])    # el larguero de atras


# El borde de delante del toldo: una tira de lona que cuelga, festoneada.
static func _feston(d: PackedByteArray, w: int, h: int) -> void:
	var pd: float = TOLDO_DELANTE[0]
	var y0: int = int(round(_sy(h, pd, _z_toldo(pd))))
	PuebloSprites._rect(d, w, h, 0, y0, w, 1, MADERA[2])
	for x in range(0, w):
		var raya: bool = posmod(x, 12) < 6
		for k in 4:
			_px(d, w, h, x, y0 + 1 + k, TOLDO[3] if raya else TOLDO[2])
		var u: float = fposmod(float(x) - 0.5, 12.0) / 12.0
		var cae: int = int(round(3.0 * sin(u * PI)))
		for k in cae:
			_px(d, w, h, x, y0 + 5 + k, TOLDO[1] if k == cae - 1 else (TOLDO[3] if raya else TOLDO[2]))


# Un monton de genero redondo (tomates, manzanas, bollos...): bolitas con brillo en filas que se apilan
# hacia atras. 'y0' es la base del monton, la de delante.
static func _monton(d: PackedByteArray, w: int, h: int, x0: int, y0: int, ancho: int, filas: int, rampa: Array, sem: int) -> void:
	for f in range(maxi(filas, 0), -1, -1):
		var y: int = y0 - 2 - f * 2
		var x: int = x0 + 2 + (f % 2) * 2
		while x < x0 + ancho - 2:
			_bolita(d, w, h, x, y + int(_rnd(x, f, sem) * 1.5), rampa)
			x += 4


static func _bolita(d: PackedByteArray, w: int, h: int, cx: int, cy: int, rampa: Array) -> void:
	for dy in range(-2, 2):
		for dx in range(-2, 2):
			if (dx == -2 or dx == 1) and (dy == -2 or dy == 1):
				continue
			var col: Color = rampa[1]
			if dx >= 0 and dy >= 0:
				col = rampa[0]
			_px(d, w, h, cx + dx, cy + dy, col)
	_px(d, w, h, cx - 1, cy - 1, rampa[2])


# Hogazas alargadas para el estante del panadero, con sus cortes.
static func _hogazas(d: PackedByteArray, w: int, h: int, x0: int, y0: int, ancho: int, rampa: Array) -> void:
	var x: int = x0
	while x + 10 <= x0 + ancho:
		for dy in range(-4, 0):
			for dx in range(0, 10):
				if (dx == 0 or dx == 9) and (dy == -4 or dy == -1):
					continue
				var col: Color = rampa[1] if dy > -3 else rampa[2]
				if dy == -1:
					col = rampa[0]
				_px(d, w, h, x + dx, y0 + dy, col)
		for k in 3:
			_px(d, w, h, x + 2 + k * 3, y0 - 3, rampa[0])
		x += 12


# Frascos en fila sobre una balda: vidrio con el contenido de color, tapon de corcho y un brillo. Los
# 'altos' son botellas de aceite con cuello; los bajos, botes de especias.
static func _botellas(d: PackedByteArray, w: int, h: int, x0: int, y0: int, ancho: int, rampa: Array, altos: bool) -> void:
	var x: int = x0 + 1
	var paso: int = 5 if altos else 6
	while x + 4 <= x0 + ancho:
		var cuerpo: int = 7 if altos else 5
		for dy in range(1, cuerpo + 1):
			for dx in 4:
				var col: Color = rampa[1] if dx < 2 else rampa[0]
				if dy == cuerpo:
					col = rampa[0]
				_px(d, w, h, x + dx, y0 - dy, col)
		_px(d, w, h, x, y0 - cuerpo + 1, rampa[2])                     # el brillo del vidrio
		var boca: int = y0 - cuerpo
		if altos:
			_px(d, w, h, x + 1, boca - 1, rampa[1])                     # el cuello
			_px(d, w, h, x + 2, boca - 1, rampa[0])
			boca -= 1
		_px(d, w, h, x + 1, boca - 1, Color(0.62, 0.44, 0.26))           # el tapon
		_px(d, w, h, x + 2, boca - 1, Color(0.48, 0.32, 0.18))
		x += paso


# Un cesto de mimbre con genero asomando.
static func _cesto(d: PackedByteArray, w: int, h: int, x0: int, suelo: int, ancho: int, rampa: Array, sem: int) -> void:
	var mimbre: Array = [Color(0.36, 0.24, 0.12), Color(0.58, 0.42, 0.22), Color(0.74, 0.58, 0.34)]
	_monton(d, w, h, x0, suelo - 7, ancho, 1, rampa, sem)
	for y in range(suelo - 8, suelo + 1):
		var mete: int = 1 if y > suelo - 3 else 0
		for x in range(x0 + mete, x0 + ancho - mete):
			var col: Color = mimbre[2] if posmod(x + y, 3) == 0 else mimbre[1]
			if y == suelo - 8:
				col = mimbre[2]
			if y == suelo:
				col = mimbre[0]
			_px(d, w, h, x, y, col)
