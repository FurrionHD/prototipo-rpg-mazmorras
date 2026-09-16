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
	# 'pie' 16 y no la casilla entera: la columna CHOCA solo con su zocalo, al fondo de la casilla, asi que
	# quien se arrima por detras mete las piernas en la casilla. Con el corte en lo alto de la casilla
	# esas piernas se pintaban por encima del fuste (lo vio el usuario). El corte va en el zocalo.
	"altar_columna": {"tam": Vector2i(32, 76), "pie": 16},
	# ADORNOS DE SUELO delante de las casas: una casilla, solidos (ver PuebloPlano.ADORNOS).
	"yunque": {"tam": Vector2i(32, 56), "pie": 32},
	"troncos": {"tam": Vector2i(32, 56), "pie": 32},
	"barril": {"tam": Vector2i(32, 56), "pie": 32},
	"barriles": {"tam": Vector2i(32, 56), "pie": 32},
	"cajas": {"tam": Vector2i(32, 56), "pie": 32},
	"sacos": {"tam": Vector2i(32, 56), "pie": 32},
	"bastidor": {"tam": Vector2i(32, 56), "pie": 32},
	# LUCES DE NOCHE (ver Antorcha y LuzPueblo). Estrechas como la columna: chocan con su pie y el corte
	# va ahi, para que quien se arrima por detras no se pinte encima del palo.
	"poste_antorcha": {"tam": Vector2i(32, 72), "pie": 12},
	"brasero": {"tam": Vector2i(32, 50), "pie": 13},
}

# Las verjas son una pieza por MASCARA (hacia que lados sigue la verja: 1 N, 2 E, 4 S, 8 O).
const VERJA_TAM := Vector2i(32, 52)
# Lo mismo que la columna: la verja choca con una raya por el CENTRO de la casilla, asi que el corte va
# ahi (16 desde abajo, menos lo que abulta la raya) y no en lo alto de la casilla.
const VERJA_PIE := 13

const NEGRO := Color(0.06, 0.05, 0.05)


static func claves() -> PackedStringArray:
	var out := PackedStringArray(PIEZAS.keys())
	for m in 16:
		out.append("verja_%d" % m)
	for l in CANA_LADOS:
		out.append("cana_" + String(l))
	# Las casas las dibuja CasaSprites; aqui solo se registran con el prefijo "casa_".
	for c in CasaSprites.CASAS:
		out.append("casa_" + String(c))
	return out


static func tam(clave: String) -> Vector2i:
	if clave.begins_with("verja_"):
		return VERJA_TAM
	if clave.begins_with("cana_"):
		return CANA_TAM
	if clave.begins_with("casa_"):
		return CasaSprites.tam(clave.trim_prefix("casa_"))
	return (PIEZAS[clave] as Dictionary)["tam"]


static func pie(clave: String) -> int:
	if clave.begins_with("verja_"):
		return VERJA_PIE
	if clave.begins_with("cana_"):
		return CANA_TAM.y
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
			#
			# Va OSCURA y con las hiladas CURVAS, siguiendo el borde del pozo. La primera version era
			# piedra clara con juntas rectas y el usuario la leyo como el adoquin de la calle "viendose a
			# traves" del pozo.
			var ry: float = dy + 14.0
			if dy < 0.0 and sqrt(dx * dx + ry * ry) > POZO_R:
				var borde_y: float = -sqrt(maxf(0.0, POZO_R * POZO_R - dx * dx))   # el labio del pozo en esta x
				var bajo: float = clampf(dy - borde_y, 0.0, 14.0)                  # cuanto por debajo del labio
				var hil: int = int(floor(bajo / 3.5))
				var junta: bool = fposmod(bajo, 3.5) < 0.9 or posmod(x + hil * 4, 8) == 0
				var col: Color = PIEDRA[1].lerp(NEGRO, clampf(bajo / 14.0, 0.0, 1.0) * 0.85)
				if junta:
					col = col.darkened(0.45)
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
			var r0: float = sqrt(dx * dx + dy * dy)
			# LA CARA INTERIOR DEL PRETIL. La coronacion va subida, asi que en el lado norte queda una media
			# luna entre ella y la boca del pozo: ahi se veia la tarima "a traves" del pretil (lo vio el
			# usuario). Es la pared del pretil bajando hacia el pozo: se pinta como la pared del pozo.
			if dy < 0.0 and rt < POZO_R and r0 >= POZO_R - 0.5 and not boca.call(at):
				var baja: float = clampf((POZO_R - rt) / PRETIL_ALTO, 0.0, 1.0)
				var col_i: Color = PIEDRA[2].lerp(PIEDRA[1], baja)
				if fposmod(dy, 3.5) < 0.9 or posmod(x, 7) == 0:
					col_i = col_i.darkened(0.35)
				_px(d, w, h, x, y, col_i)
				continue
			if rt >= POZO_R and rt <= PRETIL_R and not boca.call(at):
				var col: Color = PIEDRA[4] if rt < PRETIL_R - 1.5 else PIEDRA[3]
				if rt < POZO_R + 1.0 or rt > PRETIL_R - 0.8:
					col = NEGRO
				elif int(rad_to_deg(at) + 360.0) % 30 < 2:
					col = PIEDRA[2]               # junta entre sillares de la coronacion
				_px(d, w, h, x, y, col)
				continue
			# CARA EXTERIOR del pretil: entre la base (dy) y la coronacion, solo en la mitad sur.
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
	# Las BRASAS en el cuenco. La LLAMA ya no se pinta: es fuego de verdad, grande y blanco, con
	# particulas (ver LlamaAltar), que el usuario queria "que parezca fuego de verdad".
	for x in range(10, 23):
		var c: Color = Color(1.0, 0.95, 0.85) if posmod(x, 3) == 0 else Color(0.85, 0.88, 0.95)
		_px(d, w, h, x, fuste_top - 11, c)
	return d


# Donde nace la llama del altar, en px del lienzo de la columna.
static func boca_altar() -> Vector2:
	return Vector2(16, 20 - 12)


# ============================================================
#  LAS LUCES DEL PUEBLO: el poste de antorcha y el brasero. Solo el soporte: el fuego es Antorcha,
#  que se engancha en su boca (boca_poste / boca_brasero) y se enciende al anochecer. De dia se ven
#  las brasas apagadas, negras.
# ============================================================
const MADERA_POSTE := [Color(0.20, 0.13, 0.08), Color(0.33, 0.22, 0.13), Color(0.45, 0.31, 0.19), Color(0.56, 0.40, 0.25)]
const HIERRO_RAMPA := [Color(0.11, 0.11, 0.13), Color(0.21, 0.21, 0.24), Color(0.33, 0.33, 0.37), Color(0.48, 0.48, 0.52)]
const CARBON := [Color(0.08, 0.07, 0.07), Color(0.16, 0.14, 0.13), Color(0.28, 0.14, 0.09)]

static func _poste_antorcha() -> PackedByteArray:
	var t: Vector2i = PIEZAS["poste_antorcha"]["tam"]
	var w: int = t.x
	var h: int = t.y
	var d := _lienzo(t)
	var suelo_y: int = h - 6
	_sombra_suelo(d, w, h, 16, suelo_y + 1, 8, 3)
	# Un zocalo de piedra pequeño donde se clava el palo.
	_caja(d, w, h, 11, suelo_y - 5, 10, 3, 3, [PIEDRA[1], PIEDRA[2], PIEDRA[3], PIEDRA[4]])
	# El palo: 4 px de madera, con luz a la izquierda y vetas.
	var cazo_y: int = 12
	for y in range(cazo_y + 7, suelo_y - 4):
		for x in range(14, 18):
			var col: Color = MADERA_POSTE[2] if x == 15 else MADERA_POSTE[1]
			if x == 14 or x == 17:
				col = NEGRO
			elif posmod(y * 3 + x, 11) == 0:
				col = MADERA_POSTE[0]
			_px(d, w, h, x, y, col)
	# Las abrazaderas de hierro que sujetan el cazo.
	for y in [cazo_y + 9, cazo_y + 14]:
		for x in range(13, 19):
			_px(d, w, h, x, y, HIERRO_RAMPA[2] if x > 13 and x < 18 else NEGRO)
	# El CAZO: un cesto de hierro abierto arriba, mas ancho en la boca.
	for y in range(cazo_y, cazo_y + 8):
		var semi: float = 6.0 - float(y - cazo_y) * 0.45
		for x in w:
			var dx: float = float(x) + 0.5 - 16.0
			if absf(dx) > semi:
				continue
			var col: Color = HIERRO_RAMPA[1]
			if absf(dx) > semi - 1.0:
				col = NEGRO
			elif posmod(x, 3) == 0:
				col = HIERRO_RAMPA[2]                 # las varillas del cesto
			if y == cazo_y + 3:
				col = HIERRO_RAMPA[3] if absf(dx) <= semi - 1.0 else NEGRO     # el aro
			_px(d, w, h, x, y, col)
	# Boca: el carbon de dentro (visto desde arriba) y el borde.
	for x in range(10, 23):
		var c: Color = CARBON[int(_rnd(x, 1, 51) * 2.99)]
		_px(d, w, h, x, cazo_y, c)
		_px(d, w, h, x, cazo_y - 1, NEGRO if x == 10 or x == 22 else HIERRO_RAMPA[3])
	return d


# Donde nace la llama del poste, en px de su lienzo.
static func boca_poste() -> Vector2:
	return Vector2(16, 13)


static func _brasero() -> PackedByteArray:
	var t: Vector2i = PIEZAS["brasero"]["tam"]
	var w: int = t.x
	var h: int = t.y
	var d := _lienzo(t)
	var suelo_y: int = h - 6
	_sombra_suelo(d, w, h, 16, suelo_y + 1, 13, 4)
	var cuenco_y: int = suelo_y - 22       # la boca del cuenco
	var fondo_cuenco: int = cuenco_y + 11
	# Tres patas de hierro, abiertas hacia abajo (la del centro, detras, mas corta).
	for pata in [[9.0, 5.0], [23.0, 27.0]]:
		for y in range(fondo_cuenco - 2, suelo_y + 1):
			var u: float = float(y - fondo_cuenco + 2) / float(suelo_y - fondo_cuenco + 2)
			var x: int = int(lerpf(pata[0], pata[1], u))
			_px(d, w, h, x, y, NEGRO)
			_px(d, w, h, x + 1, y, HIERRO_RAMPA[2])
			_px(d, w, h, x + 2, y, NEGRO)
		_px(d, w, h, int(pata[1]), suelo_y + 1, NEGRO)
		_px(d, w, h, int(pata[1]) + 2, suelo_y + 1, NEGRO)
	for y in range(fondo_cuenco, suelo_y - 3):
		_px(d, w, h, 15, y, NEGRO)
		_px(d, w, h, 16, y, HIERRO_RAMPA[1])
		_px(d, w, h, 17, y, NEGRO)
	# El cuenco: media esfera de hierro vista desde el sur, con un aro claro en la boca.
	for y in range(cuenco_y, fondo_cuenco + 1):
		var u: float = float(y - cuenco_y) / float(fondo_cuenco - cuenco_y)
		var semi: float = 13.0 * sqrt(maxf(0.0, 1.0 - u * u * 0.8))
		for x in w:
			var dx: float = float(x) + 0.5 - 16.0
			if absf(dx) > semi:
				continue
			var v: float = 0.55 - dx / 26.0 * 0.5 - u * 0.25
			var col: Color = HIERRO_RAMPA[clampi(int(v * 4.0), 0, 3)]
			if absf(dx) > semi - 1.0 or y == fondo_cuenco:
				col = NEGRO
			elif y == cuenco_y + 4:
				col = HIERRO_RAMPA[0]               # una banda remachada
			elif y == cuenco_y + 3 and posmod(x, 4) == 0:
				col = HIERRO_RAMPA[3]
			_px(d, w, h, x, y, col)
	# La boca vista desde arriba: una elipse de carbon con el aro alrededor.
	for y in range(cuenco_y - 4, cuenco_y + 2):
		for x in w:
			var e: float = pow((float(x) + 0.5 - 16.0) / 13.0, 2.0) + pow((float(y) + 0.5 - float(cuenco_y) + 1.0) / 3.5, 2.0)
			if e > 1.0:
				continue
			var col: Color = CARBON[int(_rnd(x, y, 53) * 2.99)]
			if e > 0.70:
				col = HIERRO_RAMPA[3] if y < cuenco_y - 1 else HIERRO_RAMPA[2]
			if e > 0.90:
				col = NEGRO
			_px(d, w, h, x, y, col)
	return d


static func boca_brasero() -> Vector2:
	return Vector2(16, 50 - 6 - 22)


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
	var suelo: int = h - 32 + 16               # el centro de la casilla, en el lienzo (la casilla, NO el corte)
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
	# Tramos norte-sur: se ven DE CANTO. Cada barrote va un poco mas arriba que el de delante (esta mas
	# lejos), asi que juntos forman una banda de hierro con las puntas asomando por la izquierda y dos
	# travesaños claros que la recorren entera. La primera version era una raya de 2 px y en el juego
	# se leia como una linea discontinua, no como una verja.
	var y0: int = 0 if (mask & 1) != 0 else 16
	var y1: int = 32 if (mask & 4) != 0 else 16
	if y1 > y0:
		for yy in range(y0, y1 + 1):
			var base: int = suelo - 16 + yy
			for y in range(base - VERJA_ALTO, base + 1):
				_px(d, w, h, 15, y, HIERRO)
				_px(d, w, h, 16, y, HIERRO)
			if yy % 4 == 0:
				_px(d, w, h, 14, base - VERJA_ALTO - 1, HIERRO)
				_px(d, w, h, 15, base - VERJA_ALTO - 2, HIERRO_LUZ)
			_px(d, w, h, 17, base - 4, HIERRO_LUZ)
			_px(d, w, h, 17, base - VERJA_ALTO + 3, HIERRO_LUZ)
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
#  ADORNOS DE SUELO
# ============================================================
# Lo que se apoya delante de una casa. La primera version los pintaba EN la pared y el usuario lo
# canto enseguida: "parece un png encima de la pared". Lo que les faltaba es lo que tiene cualquier
# cosa que esta en el suelo con esta camara: SOMBRA en el suelo, una TAPA (lo de arriba, clara) y una
# CARA (lo vertical, mas oscura), con su contorno. Y una casilla propia que choca.
#
# El lienzo es la casilla (32x32, abajo) mas 24 px por encima para lo que sube.
const ADORNO_SUELO := 44       # y del lienzo donde se apoyan (un poco por debajo del centro de la casilla)
const ADORNOS_CLAVES := ["yunque", "troncos", "barril", "barriles", "cajas", "sacos", "bastidor"]

static func _adorno(clave: String) -> PackedByteArray:
	var t: Vector2i = PIEZAS[clave]["tam"]
	var w: int = t.x
	var h: int = t.y
	var d := _lienzo(t)
	var s: int = ADORNO_SUELO
	match clave:
		"yunque":
			_sombra_suelo(d, w, h, 16, s, 14, 5)
			var tajo: Array = [Color(0.18, 0.11, 0.07), Color(0.32, 0.21, 0.13), Color(0.45, 0.31, 0.19), Color(0.62, 0.47, 0.30), Color(0.74, 0.60, 0.40)]
			_cilindro(d, w, h, 16, s, 9, 10, tajo, true)
			# El yunque encima del tajo: tapa (clara) + cara (oscura), con el pico hacia la izquierda.
			var hierro: Array = [Color(0.09, 0.09, 0.11), Color(0.22, 0.22, 0.25), Color(0.36, 0.36, 0.40), Color(0.52, 0.52, 0.57), Color(0.70, 0.70, 0.75)]
			var top: int = s - 10 - 14
			_rect(d, w, h, 12, top + 8, 8, 5, hierro[1])            # cintura
			for y in 5:
				for x in range(7, 27):
					_px(d, w, h, x, top + y, hierro[4] if y < 2 else hierro[3])   # tapa
			for x in range(1, 7):
				for y in range(2 - (x - 1) / 2, 3 + (x - 1) / 3):
					_px(d, w, h, x, top + y + 1, hierro[3])            # pico
			for y in 4:
				for x in range(7, 27):
					_px(d, w, h, x, top + 5 + y, hierro[2] if x < 12 or x > 20 else hierro[1])  # cara
			_contorno(d, w, h)
			_rect(d, w, h, 13, top, 9, 2, Color(1.0, 0.50, 0.12))    # la pieza al rojo
			_rect(d, w, h, 15, top, 5, 1, Color(1.0, 0.90, 0.55))
		"barril":
			_sombra_suelo(d, w, h, 16, s, 11, 4)
			_barril(d, w, h, 16, s, 8, 20)
			_contorno(d, w, h)
		"barriles":
			_sombra_suelo(d, w, h, 16, s + 1, 15, 5)
			_barril(d, w, h, 9, s - 3, 6, 16)
			_barril(d, w, h, 22, s + 1, 7, 18)
			_contorno(d, w, h)
		"troncos":
			# Pila de troncos tumbados de norte a sur: se les ven las TESTAS (con sus anillos) y, por
			# encima de cada una, la corteza que se aleja hacia el fondo.
			_sombra_suelo(d, w, h, 16, s, 16, 6)
			var corteza: Array = [Color(0.16, 0.10, 0.06), Color(0.28, 0.18, 0.10), Color(0.38, 0.26, 0.15)]
			var testa: Array = [Color(0.55, 0.40, 0.24), Color(0.72, 0.56, 0.36), Color(0.82, 0.68, 0.46)]
			var filas := [[5, s - 5, 3], [10, s - 14, 2], [15, s - 23, 1]]
			for f in filas:
				for k in int(f[2]):
					var cx: int = int(f[0]) + k * 11
					var cy: int = int(f[1])
					for y in range(cy - 12, cy):
						for x in range(cx - 5, cx + 6):
							var col: Color = corteza[2] if x < cx - 1 else (corteza[1] if x < cx + 3 else corteza[0])
							if (y + x * 3) % 7 == 0:
								col = corteza[0]
							_px(d, w, h, x, y, col)
					for yy in range(-5, 6):
						for xx in range(-5, 6):
							var rr: float = sqrt(float(xx * xx) + float(yy * yy) * 1.3)
							if rr > 5.3:
								continue
							var col2: Color = testa[1]
							if rr > 4.3:
								col2 = corteza[1]
							elif int(rr * 1.2) % 2 == 1:
								col2 = testa[0]
							elif rr < 1.2:
								col2 = testa[2]
							_px(d, w, h, cx + xx, cy + yy, col2)
			_contorno(d, w, h)
		"cajas":
			_sombra_suelo(d, w, h, 16, s, 15, 5)
			var mad: Array = [Color(0.30, 0.20, 0.11), Color(0.48, 0.34, 0.20), Color(0.62, 0.47, 0.29), Color(0.74, 0.60, 0.40), Color(0.84, 0.72, 0.52)]
			_caja_madera(d, w, h, 3, s, 22, 8, 13, mad)
			_caja_madera(d, w, h, 12, s - 13 - 4, 14, 6, 10, mad)
			_contorno(d, w, h)
		"bastidor":
			# EL BASTIDOR DE LA PELETERIA: dos postes con travesaño y una piel estirada con cuerdas,
			# mirando a la calle. Antes las pieles iban colgadas en la pared y tapaban las ventanas.
			_sombra_suelo(d, w, h, 16, s, 15, 4)
			var palo: Array = [Color(0.20, 0.13, 0.08), Color(0.36, 0.24, 0.14), Color(0.52, 0.37, 0.22)]
			var alto_b: int = 30
			for px_ in [3, 27]:
				for y in range(s - alto_b, s + 1):
					_px(d, w, h, px_, y, palo[2])
					_px(d, w, h, px_ + 1, y, palo[1])
			for x in range(2, 30):
				_px(d, w, h, x, s - alto_b, palo[2])
				_px(d, w, h, x, s - alto_b + 1, palo[1])
			for x in range(3, 29):
				_px(d, w, h, x, s - 4, palo[1])
			# La piel: silueta de cuero curtido, con las patas estiradas hacia las esquinas.
			var cuero: Array = [Color(0.38, 0.25, 0.14), Color(0.56, 0.40, 0.25), Color(0.68, 0.52, 0.34)]
			var cy: int = s - alto_b / 2 - 2
			for yy in range(-10, 11):
				var semi: float = 7.5 - absf(float(yy)) * 0.22
				for xx in range(-11, 12):
					var lim: float = semi
					if absi(yy) >= 8:
						lim = 3.0 + (absf(float(xx)) > 6.0 as int) * 0.0
						if absf(float(xx)) >= 6.0 and absf(float(xx)) <= 10.0 and absi(yy) <= 10:
							lim = 10.0
					if absf(float(xx)) > lim:
						continue
					var col: Color = cuero[2] if absf(float(xx)) < lim - 3.0 and absi(yy) < 8 else cuero[1]
					if absf(float(xx)) >= lim - 0.8:
						col = cuero[0]
					_px(d, w, h, 16 + xx, cy + yy, col)
			# Las cuerdas de las esquinas de la piel a los postes.
			for k in 4:
				var ex: int = 16 + (-10 if k % 2 == 0 else 10)
				var ey: int = cy + (-10 if k < 2 else 10)
				var px2: int = 5 if k % 2 == 0 else 26
				var paso: int = 1 if px2 > ex else -1
				for x in range(ex, px2, paso):
					_px(d, w, h, x, ey, Color(0.80, 0.74, 0.58))
			_contorno(d, w, h)
		"sacos":
			_sombra_suelo(d, w, h, 16, s, 15, 5)
			_saco(d, w, h, 16, s - 8, 7, 11)
			_saco(d, w, h, 9, s, 8, 14)
			_saco(d, w, h, 23, s + 1, 7, 12)
			_contorno(d, w, h)
	return d


static func _sombra_suelo(d: PackedByteArray, w: int, h: int, cx: int, cy: int, rx: int, ry: int) -> void:
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			var e: float = pow(float(x - cx) / float(rx), 2.0) + pow(float(y - cy) / float(ry), 2.0)
			if e <= 1.0:
				_px(d, w, h, x, y, Color(0, 0, 0, 0.30))


# Un cilindro de pie: cuerpo con luz por la izquierda y la TAPA en elipse arriba.
static func _cilindro(d: PackedByteArray, w: int, h: int, cx: int, suelo: int, r: int, alto: int, rampa: Array, anillos: bool) -> void:
	var ry: float = float(r) * 0.5
	var arriba_cuerpo: float = float(suelo - alto)
	for y in range(suelo - alto - int(ry) - 1, suelo + int(ry) + 1):
		for x in range(cx - r, cx + r + 1):
			var dx: float = float(x - cx) + 0.5
			var q: float = 1.0 - pow(dx / float(r), 2.0)
			if q < 0.0:
				continue
			var abajo: float = float(suelo) + ry * sqrt(q)
			var en_tapa: bool = pow(dx / float(r), 2.0) + pow((float(y) + 0.5 - arriba_cuerpo) / ry, 2.0) <= 1.0
			var col: Color
			if en_tapa:
				col = rampa[3]
				if anillos and int(sqrt(dx * dx + pow((float(y) + 0.5 - arriba_cuerpo) * 2.0, 2.0))) % 3 == 0:
					col = rampa[2]
			elif float(y) >= arriba_cuerpo and float(y) <= abajo:
				var u: float = (dx + float(r)) / float(2 * r)
				col = rampa[2] if u < 0.35 else (rampa[1] if u < 0.75 else rampa[0])
			else:
				continue
			_px(d, w, h, x, y, col)


static func _barril(d: PackedByteArray, w: int, h: int, cx: int, suelo: int, r: int, alto: int) -> void:
	var mad: Array = [Color(0.22, 0.13, 0.07), Color(0.38, 0.25, 0.14), Color(0.52, 0.36, 0.21), Color(0.66, 0.49, 0.30), Color(0.78, 0.62, 0.40)]
	_cilindro(d, w, h, cx, suelo, r, alto, mad, false)
	var ry: float = float(r) * 0.5
	for x in range(cx - r + 1, cx + r):
		var dx: float = float(x - cx) + 0.5
		var curva: int = int(ry * sqrt(maxf(0.0, 1.0 - pow(dx / float(r), 2.0))))
		if (x - cx + r) % 4 == 0:
			for y in range(suelo - alto + curva + 1, suelo + curva):
				_px(d, w, h, x, y, mad[0])            # junta entre duelas
		for aro in [3, alto - 4]:
			_px(d, w, h, x, suelo - aro + curva, Color(0.18, 0.18, 0.20))
			_px(d, w, h, x, suelo - aro + curva - 1, Color(0.46, 0.46, 0.50))
	for x in range(cx - r + 2, cx + r - 1):
		_px(d, w, h, x, suelo - alto, mad[2])          # la tabla del medio de la tapa


static func _caja_madera(d: PackedByteArray, w: int, h: int, x0: int, suelo: int, ancho: int, fondo: int, alto: int, mad: Array) -> void:
	for y in range(suelo - alto - fondo, suelo - alto):
		for x in range(x0, x0 + ancho):
			_px(d, w, h, x, y, mad[4] if (y - (suelo - alto - fondo)) % 4 != 3 else mad[3])    # tapa
	for y in range(suelo - alto, suelo):
		for x in range(x0, x0 + ancho):
			var col: Color = mad[2] if (y - (suelo - alto)) % 4 != 3 else mad[1]
			if x < x0 + 2 or x >= x0 + ancho - 2:
				col = mad[1]                          # listones de las esquinas
			_px(d, w, h, x, y, col)
	for x in range(x0, x0 + ancho):
		_px(d, w, h, x, suelo - alto, mad[0])         # la arista entre tapa y cara


static func _saco(d: PackedByteArray, w: int, h: int, cx: int, suelo: int, rx: int, alto: int) -> void:
	var tela: Array = [Color(0.36, 0.28, 0.17), Color(0.56, 0.46, 0.30), Color(0.72, 0.62, 0.44), Color(0.84, 0.76, 0.58)]
	for y in range(suelo - alto, suelo + 1):
		var t: float = float(suelo - y) / float(alto)
		var semi: float = float(rx) * (1.0 - pow(maxf(0.0, t - 0.25) / 0.75, 2.0) * 0.75)
		for x in range(cx - rx, cx + rx + 1):
			var dx: float = float(x - cx) + 0.5
			if absf(dx) > semi:
				continue
			var u: float = (dx + semi) / maxf(1.0, 2.0 * semi)
			var col: Color = tela[3] if u < 0.3 and t > 0.3 else (tela[2] if u < 0.65 else tela[1])
			if t < 0.15:
				col = tela[1]
			_px(d, w, h, x, y, col)
	_rect(d, w, h, cx - 2, suelo - alto - 2, 4, 3, tela[1])     # el nudo
	_px(d, w, h, cx, suelo - alto - 3, tela[0])


static func _rect(d: PackedByteArray, w: int, h: int, x0: int, y0: int, rw: int, rh: int, c: Color) -> void:
	for y in range(y0, y0 + rh):
		for x in range(x0, x0 + rw):
			_px(d, w, h, x, y, c)


# Contorno negro de un pixel alrededor de lo opaco (la sombra del suelo, translucida, no cuenta).
static func _contorno(d: PackedByteArray, w: int, h: int) -> void:
	var borde := PackedInt32Array()
	for y in h:
		for x in w:
			if d[(y * w + x) * 4 + 3] > 200:
				continue
			for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + v.x
				var ny: int = y + v.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and d[(ny * w + nx) * 4 + 3] > 200:
					borde.append(y * w + x)
					break
	for i in borde:
		_px(d, w, h, i % w, i / w, NEGRO)


# ============================================================
#  LAS CAÑAS DE PESCAR del muelle
# ============================================================
# Clavadas en el borde de la plataforma, asomando al agua, con el sedal cayendo hasta un corcho. Tres
# dibujos, uno por lado ("s", "e", "o"): la caña se inclina hacia fuera y SUBE (con esta camara, subir
# es ir hacia arriba en pantalla), y el sedal baja hasta el agua.
#
# Lienzo de 96x96 con el centro de su casilla en (48, 48): la caña sale de la casilla sobre el agua.
const CANA_TAM := Vector2i(96, 96)
const CANA_LADOS := ["s", "e", "o"]

static func _cana(lado: String) -> PackedByteArray:
	var w: int = CANA_TAM.x
	var h: int = CANA_TAM.y
	var d := _lienzo(CANA_TAM)
	var dir := Vector2(0, 1) if lado == "s" else (Vector2(1, 0) if lado == "e" else Vector2(-1, 0))
	var base := Vector2(48, 48) + dir * 11.0 + Vector2(0, 6)
	var punta := base + dir * 30.0 + Vector2(0, -22)
	var corcho := punta + dir * 3.0 + Vector2(0, 18)
	if lado == "s":
		# Hacia el sur la caña apenas avanza en pantalla (sale hacia la camara y sube a la vez) y el
		# corcho cae justo debajo. Con los numeros de los lados se salia del lienzo y no se veia.
		punta = base + Vector2(10, 12)
		corcho = punta + Vector2(2, 12)
	# La onda del agua alrededor del corcho.
	for yy in range(-3, 4):
		for xx in range(-7, 8):
			var e: float = pow(float(xx) / 6.5, 2.0) + pow(float(yy) / 2.6, 2.0)
			if e <= 1.0 and e >= 0.55:
				_px(d, w, h, int(corcho.x) + xx, int(corcho.y) + 1 + yy, Color(0.80, 0.90, 0.95, 0.45))
	# El sedal: de la punta al corcho, con una comba.
	var n: int = 40
	for i in n + 1:
		var t: float = float(i) / float(n)
		var p: Vector2 = punta.lerp(corcho, t) + Vector2(-dir.y, dir.x) * sin(t * PI) * 2.0
		_px(d, w, h, int(p.x), int(p.y), Color(0.88, 0.88, 0.85, 0.65))
	# El soporte: una estaca con una abrazadera, clavada en el tablero.
	for y in range(int(base.y) - 3, int(base.y) + 5):
		_px(d, w, h, int(base.x) - 1, y, Color(0.28, 0.18, 0.10))
		_px(d, w, h, int(base.x), y, Color(0.42, 0.28, 0.16))
		_px(d, w, h, int(base.x) + 1, y, Color(0.20, 0.12, 0.07))
	# La caña: gruesa y oscura en el mango, fina y clara hacia la punta.
	var m: int = 60
	for i in m + 1:
		var t: float = float(i) / float(m)
		var p: Vector2 = base.lerp(punta, t) + Vector2(0, -1) * sin(t * PI) * 3.0
		var col: Color = Color(0.20, 0.13, 0.08) if t < 0.25 else Color(0.66, 0.54, 0.32)
		_px(d, w, h, int(p.x), int(p.y), col)
		if t < 0.55:
			_px(d, w, h, int(p.x) + 1, int(p.y), col.darkened(0.3))
	# El carrete, pegado al mango.
	var c: Vector2 = base.lerp(punta, 0.12)
	_rect(d, w, h, int(c.x) - 1, int(c.y) - 1, 3, 3, Color(0.55, 0.55, 0.58))
	_px(d, w, h, int(c.x), int(c.y), Color(0.20, 0.20, 0.22))
	# El corcho: rojo arriba, blanco abajo.
	_rect(d, w, h, int(corcho.x) - 1, int(corcho.y) - 2, 3, 2, Color(0.85, 0.15, 0.12))
	_rect(d, w, h, int(corcho.x) - 1, int(corcho.y), 3, 1, Color(0.95, 0.95, 0.92))
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
	elif clave in ADORNOS_CLAVES:
		d = _adorno(clave)
	elif clave.begins_with("cana_"):
		d = _cana(clave.trim_prefix("cana_"))
	elif clave == "poste_antorcha":
		d = _poste_antorcha()
	elif clave == "brasero":
		d = _brasero()
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
