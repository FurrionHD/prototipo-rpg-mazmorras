# ============================================================
#  pueblo_sprites.gd  (class_name PuebloSprites)
#  Las PIEZAS del pueblo dibujadas por codigo: la escalera de caracol que baja a la mazmorra, la
#  columna del altar, las verjas del jardin (y, despues, cada casa).
#
#  LA CAMARA ES LA DE TODO EL JUEGO: el suelo se ve en planta (una casilla es un cuadrado de 32 px) y
#  lo que tiene ALTURA sube en pantalla z*sin(45). Por eso aqui cada dibujo es "que hay en el suelo" +
#  "cuanto se levanta", y no un dibujo de perfil.
#
#  Cada pieza declara, ademas de su tamaño, cuanto de ella es HUELLA ('pie' = px desde abajo que
#  ocupan su casillas). Lo que sobresale por encima de la huella es lo que tapa a quien pasa por
#  detras: ver PiezaPueblo, que parte el dibujo en dos por esa linea.
#
#  Se hornea a PNG como el resto del arte (herramientas/hornear_sprites.bat) y, si falta el horneado,
#  se dibuja al vuelo.
# ============================================================

extends RefCounted
class_name PuebloSprites

const CARPETA := "res://assets/sprites/pueblo/"
const SEN45 := 0.7071

# 'tam' = lienzo; 'pie' = px desde abajo que son la huella (el resto sobresale hacia arriba).
const PIEZAS := {
	"escalera_caracol": {"tam": Vector2i(96, 96), "pie": 96},
	"altar_columna": {"tam": Vector2i(32, 76), "pie": 32},
}

# Las verjas son una pieza por MASCARA (hacia que lados sigue la verja: 1 N, 2 E, 4 S, 8 O).
const VERJA_TAM := Vector2i(32, 52)
const VERJA_PIE := 32

const NEGRO := Color(0.06, 0.05, 0.05)


static func claves() -> PackedStringArray:
	var out := PackedStringArray(PIEZAS.keys())
	for m in 16:
		out.append("verja_%d" % m)
	# Las casas las dibuja CasaSprites; aqui solo se registran con el prefijo "casa_".
	for c in CasaSprites.CASAS:
		out.append("casa_" + String(c))
	return out


static func tam(clave: String) -> Vector2i:
	if clave.begins_with("verja_"):
		return VERJA_TAM
	if clave.begins_with("casa_"):
		return CasaSprites.tam(clave.trim_prefix("casa_"))
	return (PIEZAS[clave] as Dictionary)["tam"]


static func pie(clave: String) -> int:
	if clave.begins_with("verja_"):
		return VERJA_PIE
	if clave.begins_with("casa_"):
		return CasaSprites.pie(clave.trim_prefix("casa_"))
	return int((PIEZAS[clave] as Dictionary)["pie"])


# ============================================================
#  LIENZO: bytes RGBA, sin llamadas al motor por pixel.
# ============================================================
static func _lienzo(t: Vector2i) -> PackedByteArray:
	var d := PackedByteArray()
	d.resize(t.x * t.y * 4)
	return d


static func _px(d: PackedByteArray, w: int, h: int, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= w or y >= h:
		return
	var o: int = (y * w + x) * 4
	if c.a >= 0.999:
		d[o] = int(c.r * 255.0)
		d[o + 1] = int(c.g * 255.0)
		d[o + 2] = int(c.b * 255.0)
		d[o + 3] = 255
		return
	# Mezcla sobre lo que haya (para brillos y sombras translucidas).
	var a0: float = float(d[o + 3]) / 255.0
	var a: float = c.a + a0 * (1.0 - c.a)
	if a <= 0.0:
		return
	for k in 3:
		var bajo: float = float(d[o + k]) / 255.0
		var enc: float = [c.r, c.g, c.b][k]
		d[o + k] = int(clampf((enc * c.a + bajo * a0 * (1.0 - c.a)) / a, 0.0, 1.0) * 255.0)
	d[o + 3] = int(a * 255.0)


static func _rnd(x: int, y: int, s: int) -> float:
	var n: int = x * 374761393 + y * 668265263 + s * 1013904223
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xFFFF) / 65535.0


static func _escalon(v: float, rampa: Array) -> Color:
	return rampa[clampi(int(v * float(rampa.size())), 0, rampa.size() - 1)]


const PIEDRA := [
	Color(0.20, 0.19, 0.19), Color(0.33, 0.32, 0.31), Color(0.45, 0.43, 0.41),
	Color(0.56, 0.54, 0.51), Color(0.68, 0.66, 0.62), Color(0.80, 0.78, 0.73),
]


# ============================================================
#  LA ESCALERA DE CARACOL
# ============================================================
# Una tarima cuadrada de losas (la huella de 3x3) con un POZO redondo en medio: un pretil de piedra
# alrededor, abierto por el SUR (por ahi se entra), y dentro los peldaños que bajan girando alrededor
# de un eje hasta perderse en lo negro. Se lee como "baja" por lo mismo que las escaleras de la
# mazmorra: la luz se va apagando en el sentido de la bajada (ver PropSprites).
const POZO_R := 33.0        # radio del hueco
const PRETIL_R := 40.0      # radio exterior del pretil
const PRETIL_ALTO := 9.0    # px que se levanta el pretil (en pantalla ya proyectado)
const EJE_R := 7.0
const PELDANOS := 14
const BOCA_MEDIA := 0.42    # radianes a cada lado del sur que el pretil deja abiertos

static func _escalera() -> PackedByteArray:
	var t: Vector2i = PIEZAS["escalera_caracol"]["tam"]
	var w: int = t.x
	var h: int = t.y
	var d := _lienzo(t)
	var cx: float = 48.0
	var cy: float = 50.0
	# --- 1) la tarima: losas de 16 px con junta, borde biselado ---
	for y in h:
		for x in w:
			var junta: bool = x % 16 == 0 or y % 16 == 0
			var v: float = 0.45 + _rnd(x / 16, y / 16, 7) * 0.25 + (_rnd(x, y, 3) - 0.5) * 0.10
			var col: Color = _escalon(v, PIEDRA)
			if junta:
				col = PIEDRA[1]
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				col = NEGRO
			elif x == 1 or y == 1:
				col = PIEDRA[4]
			elif x == w - 2 or y == h - 2:
				col = PIEDRA[1]
			_px(d, w, h, x, y, col)
	var boca := func(ang: float) -> bool:
		# El sur de la pantalla es +y: angulo PI/2.
		return absf(wrapf(ang - PI * 0.5, -PI, PI)) < BOCA_MEDIA
	# --- 2) el pozo por dentro ---
	for y in h:
		for x in w:
			var dx: float = float(x) + 0.5 - cx
			var dy: float = float(y) + 0.5 - cy
			var r: float = sqrt(dx * dx + dy * dy)
			if r > POZO_R:
				continue
			var ang: float = atan2(dy, dx)
			# La PARED DE ENFRENTE: desde el sur se ve la cara interior del lado norte del pozo, por
			# debajo de su borde. Es lo que le da hondura: sin ella parece un disco pintado.
			var ry: float = dy + 14.0
			if dy < 0.0 and sqrt(dx * dx + ry * ry) > POZO_R:
				var hilada: int = int(floor((dy + 60.0) / 5.0))
				var jv: bool = int(floor(float(x) + float(hilada) * 5.0)) % 9 == 0 or int(dy + 60.0) % 5 == 0
				var sombra: float = clampf((POZO_R + dy) / 14.0, 0.0, 1.0)
				var col: Color = PIEDRA[2].lerp(PIEDRA[0], sombra)
				if jv:
					col = col.darkened(0.35)
				_px(d, w, h, x, y, col)
				continue
			# EL EJE, en el centro: su cabeza coge algo de luz.
			if r < EJE_R:
				_px(d, w, h, x, y, PIEDRA[3] if r < EJE_R - 1.5 else PIEDRA[1])
				continue
			# LOS PELDAÑOS. La bajada empieza en la boca (sur) y gira en sentido horario de pantalla;
			# 'bajada' es cuanto se ha bajado: 0 en la boca, 1 tras la vuelta entera.
			var bajada: float = fposmod((ang - PI * 0.5) / TAU, 1.0)
			var f: float = bajada * float(PELDANOS)
			var paso: float = f - floor(f)
			var luz: float = 1.0 - bajada * 0.92
			var v: float = 0.25 + 0.55 * luz
			if paso > 0.82:
				v -= 0.22                         # la contrahuella en sombra
			elif paso < 0.12:
				v += 0.10                         # el canto del peldaño
			# Hacia la pared exterior, un poco mas oscuro: ahi no llega la luz del centro.
			v -= clampf((r - (POZO_R - 5.0)) / 5.0, 0.0, 1.0) * 0.12
			var col2: Color = _escalon(clampf(v, 0.0, 0.999), PIEDRA).lerp(NEGRO, (1.0 - luz) * 0.75)
			_px(d, w, h, x, y, col2)
	# --- 3) el pretil: cara sur (vertical) y coronacion ---
	for y in h:
		for x in w:
			var dx: float = float(x) + 0.5 - cx
			var dy: float = float(y) + 0.5 - cy
			# CORONACION: el anillo, subido PRETIL_ALTO.
			var ty: float = dy + PRETIL_ALTO
			var rt: float = sqrt(dx * dx + ty * ty)
			var at: float = atan2(ty, dx)
			if rt >= POZO_R and rt <= PRETIL_R and not boca.call(at):
				var col: Color = PIEDRA[4] if rt < PRETIL_R - 1.5 else PIEDRA[3]
				if rt < POZO_R + 1.0 or rt > PRETIL_R - 0.8:
					col = NEGRO
				elif int(rad_to_deg(at) + 360.0) % 30 < 2:
					col = PIEDRA[2]               # junta entre sillares de la coronacion
				_px(d, w, h, x, y, col)
				continue
			# CARA EXTERIOR del pretil: entre la base (dy) y la coronacion, solo en la mitad sur.
			var r0: float = sqrt(dx * dx + dy * dy)
			if dy > -2.0 and r0 <= PRETIL_R and rt > PRETIL_R and not boca.call(atan2(dy, dx)):
				var hil: float = fposmod(dy - float(int(sqrt(PRETIL_R * PRETIL_R - dx * dx))), 4.5)
				var col3: Color = PIEDRA[3] if hil > 1.0 else PIEDRA[1]
				if r0 > PRETIL_R - 1.0:
					col3 = NEGRO
				_px(d, w, h, x, y, col3)
	return d


# ============================================================
#  LA COLUMNA DEL ALTAR
# ============================================================
# Una columna de piedra clara sobre un zocalo cuadrado, con un cuenco en lo alto donde arde una llama
# dorada: es el sitio de la luz del hogar, y el dorado es el color que ya tenia el altar. Ocupa una
# casilla de huella y sube casi dos y media: se pasa por detras y la tapa (ver PiezaPueblo).
static func _columna() -> PackedByteArray:
	var t: Vector2i = PIEZAS["altar_columna"]["tam"]
	var w: int = t.x
	var h: int = t.y
	var d := _lienzo(t)
	var suelo_y: int = h - 7        # donde el zocalo toca el suelo (centro de la casilla, un poco abajo)
	var claro := [Color(0.42, 0.40, 0.44), Color(0.58, 0.56, 0.60), Color(0.72, 0.70, 0.74), Color(0.86, 0.85, 0.88)]
	# Sombra en el suelo.
	for y in range(suelo_y - 3, suelo_y + 5):
		for x in range(3, w - 3):
			var e: float = pow((float(x) + 0.5 - 16.0) / 13.0, 2.0) + pow((float(y) + 0.5 - float(suelo_y) - 1.0) / 4.0, 2.0)
			if e <= 1.0:
				_px(d, w, h, x, y, Color(0, 0, 0, 0.35))
	# Zocalo: tapa (planta) y cara sur.
	_caja(d, w, h, 5, suelo_y - 8, 22, 5, 6, claro)
	# Fuste: cilindro con estrias.
	var fuste_top: int = 20
	# Hasta la TAPA del zocalo (suelo_y - 8): terminaba 5 px antes y la columna flotaba sobre su base.
	for y in range(fuste_top, suelo_y - 7):
		for x in range(10, 22):
			var u: float = (float(x) + 0.5 - 16.0) / 6.0
			var v: float = 0.9 - absf(u + 0.35) * 0.9
			var col: Color = claro[clampi(int(v * 4.0), 0, 3)]
			if (x - 10) % 3 == 2:
				col = col.darkened(0.18)          # estria
			if x == 10 or x == 21:
				col = NEGRO
			_px(d, w, h, x, y, col)
	# Capitel y cuenco.
	_caja(d, w, h, 7, fuste_top - 4, 18, 4, 3, claro)
	for y in range(fuste_top - 11, fuste_top - 4):
		var semi: float = 9.0 - float(fuste_top - 4 - y) * 0.2
		for x in w:
			var dx: float = absf(float(x) + 0.5 - 16.0)
			if dx <= semi:
				var col: Color = Color(0.55, 0.42, 0.12) if y > fuste_top - 8 else Color(0.78, 0.62, 0.20)
				if dx > semi - 1.0 or y == fuste_top - 11:
					col = NEGRO if y != fuste_top - 11 else Color(0.95, 0.80, 0.35)
				_px(d, w, h, x, y, col)
	# La llama: dorada con el corazon casi blanco.
	for y in range(0, fuste_top - 10):
		for x in w:
			var dx: float = float(x) + 0.5 - 16.0
			var alto: float = float(fuste_top - 10 - y)
			var semi: float = 5.5 * (1.0 - pow(alto / 10.0, 1.4)) + sin(alto * 0.9) * 0.6
			if alto > 10.0 or absf(dx) > semi:
				continue
			var nucleo: float = absf(dx) / maxf(semi, 0.5)
			var col: Color = Color(1.0, 0.97, 0.80) if nucleo < 0.35 and alto < 6.0 else \
				(Color(1.0, 0.80, 0.30) if nucleo < 0.75 else Color(0.90, 0.50, 0.12))
			_px(d, w, h, x, y, col)
	return d


# Un bloque de piedra visto desde el sur: TAPA (planta, clara) de 'fondo' px y CARA (vertical, mas
# oscura) de 'alto' px debajo. Con su contorno.
static func _caja(d: PackedByteArray, w: int, h: int, x0: int, y0: int, ancho: int, fondo: int,
		alto: int, rampa: Array) -> void:
	for y in range(y0, y0 + fondo + alto):
		for x in range(x0, x0 + ancho):
			var col: Color = rampa[3] if y < y0 + fondo else rampa[1]
			if y == y0 + fondo:
				col = rampa[2]
			if x == x0 or x == x0 + ancho - 1 or y == y0 or y == y0 + fondo + alto - 1:
				col = NEGRO
			_px(d, w, h, x, y, col)


# ============================================================
#  LA VERJA
# ============================================================
# Hierro forjado: dos travesaños y barrotes con punta de lanza. La mascara dice hacia donde sigue la
# verja, asi que la misma pieza hace tramo recto, esquina y T. Los tramos norte-sur se ven de canto
# (la camara mira desde el sur): barrotes uno detras de otro, y por eso se ven como un poste grueso con
# puntas escalonadas.
const HIERRO := Color(0.13, 0.12, 0.13)
const HIERRO_LUZ := Color(0.36, 0.34, 0.36)
const VERJA_ALTO := 18              # px que sube un barrote
const PILAR := 5

static func _verja(mask: int) -> PackedByteArray:
	var w: int = VERJA_TAM.x
	var h: int = VERJA_TAM.y
	var d := _lienzo(VERJA_TAM)
	var suelo: int = h - VERJA_PIE + 16        # el centro de la casilla, en el lienzo
	var barrote := func(x: int, base: int) -> void:
		for y in range(base - VERJA_ALTO, base + 1):
			_px(d, w, h, x, y, HIERRO)
			_px(d, w, h, x + 1, y, HIERRO_LUZ if y < base - 2 else HIERRO)
		# punta de lanza
		_px(d, w, h, x, base - VERJA_ALTO - 1, HIERRO)
		_px(d, w, h, x + 1, base - VERJA_ALTO - 1, HIERRO)
		_px(d, w, h, x, base - VERJA_ALTO - 2, HIERRO_LUZ)
	# Travesaños de DOS pixeles de hierro y uno de brillo encima: de uno solo no se veian y los barrotes
	# parecian palos sueltos clavados en la hierba (visto en la hoja de piezas).
	var travesanos := func(x0: int, x1: int, base: int) -> void:
		for x in range(x0, x1 + 1):
			for yy in [base - 3, base - VERJA_ALTO + 3]:
				_px(d, w, h, x, yy, HIERRO)
				_px(d, w, h, x, yy - 1, HIERRO)
				_px(d, w, h, x, yy - 2, HIERRO_LUZ)
	# Tramos este-oeste: de la mitad hacia el lado que siga.
	var x0: int = 0 if (mask & 8) != 0 else 16
	var x1: int = w - 1 if (mask & 2) != 0 else 16
	if x1 > x0:
		travesanos.call(x0, x1, suelo)
		var x: int = x0 + 2
		while x < x1:
			if absi(x - 16) > 2:
				barrote.call(x, suelo)
			x += 4
	# Tramos norte-sur: barrotes escalonados en profundidad (cada uno un poco mas arriba = mas lejos).
	var y0: int = 0 if (mask & 1) != 0 else 16
	var y1: int = 32 if (mask & 4) != 0 else 16
	if y1 > y0:
		var yy: int = y0 + 3
		while yy < y1:
			if absi(yy - 16) > 2:
				barrote.call(15, suelo - 16 + yy)
			yy += 5
		for y in range(suelo - 16 + y0 - VERJA_ALTO + 3, suelo - 16 + y1 - 3):
			_px(d, w, h, 15, y, HIERRO)
			_px(d, w, h, 16, y, HIERRO_LUZ)
	# El pilar de la casilla: mas gordo y con remate.
	for y in range(suelo - VERJA_ALTO - 3, suelo + 1):
		for x in range(16 - PILAR / 2, 16 + PILAR / 2 + 1):
			var col: Color = HIERRO
			if x == 16 - PILAR / 2 + 1:
				col = HIERRO_LUZ
			_px(d, w, h, x, y, col)
	for x in range(16 - 2, 16 + 3):
		_px(d, w, h, x, suelo - VERJA_ALTO - 5, HIERRO_LUZ)
	_px(d, w, h, 16, suelo - VERJA_ALTO - 6, HIERRO_LUZ)
	return d


# ============================================================
#  GENERAR, HORNEAR, CARGAR
# ============================================================
static func generar(clave: String) -> Image:
	if clave.begins_with("casa_"):
		return CasaSprites.generar(clave.trim_prefix("casa_"))
	var t: Vector2i = tam(clave)
	var d: PackedByteArray
	if clave == "escalera_caracol":
		d = _escalera()
	elif clave == "altar_columna":
		d = _columna()
	elif clave.begins_with("verja_"):
		d = _verja(int(clave.trim_prefix("verja_")))
	else:
		d = _lienzo(t)
	return Image.create_from_data(t.x, t.y, false, Image.FORMAT_RGBA8, d)


static func _png(clave: String) -> String:
	return CARPETA + clave + ".png"


static func hornear_todo() -> int:
	DirAccess.make_dir_recursive_absolute(CARPETA)
	var n: int = 0
	for c in claves():
		if generar(c).save_png(ProjectSettings.globalize_path(_png(c))) == OK:
			n += 1
	return n


static var _cache: Dictionary = {}

static func textura(clave: String) -> Texture2D:
	if _cache.has(clave):
		return _cache[clave]
	var tex: Texture2D = null
	if ResourceLoader.exists(_png(clave)):
		tex = load(_png(clave)) as Texture2D
	if tex == null:
		tex = ImageTexture.create_from_image(generar(clave))
	_cache[clave] = tex
	return tex
