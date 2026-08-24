# ============================================================
#  prop_sprites.gd  (class_name PropSprites)
#  Los CACHARROS FIJOS del mundo: las escaleras entre pisos (y lo que venga: la puerta, el altar).
#  Cuarto generador por codigo, detras de los bichos (SpritesEnemigo), el terreno (TerrenoSprites)
#  y lo recolectable (RecolectableSprites).
#
#  Va aparte de RecolectableSprites aunque el motor sea el mismo, porque no comparte NADA de su
#  contrato: un prop no tiene familia, ni modelos por celda, ni capa de tinte por material. Es un
#  dibujo y ya.
#
#  LAS ESCALERAS SE LEEN POR EL DEGRADADO, no por la forma. Vistas desde arriba, subir y bajar son
#  el mismo rectangulo con peldaños; lo que las distingue es a donde va la luz:
#     BAJAR -> los peldaños se hunden hacia la oscuridad (arriba, que es el fondo del hueco).
#     SUBIR -> los peldaños suben hacia la luz de la boca del piso de arriba.
#  Es la convencion de toda la vida en los juegos cenitales y no necesita explicacion.
# ============================================================

extends RefCounted
class_name PropSprites

const CARPETA := "res://assets/sprites/props/"

# 48 y no 32 en la escalera: tiene que leerse como un hueco en el suelo, y a una celda justa los
# peldaños salen de 3 px y se emborronan. Cada prop lleva SU lienzo: una puerta es alta y estrecha
# y una escalera es un cuadrado, forzarlas al mismo tamaño solo deja aire alrededor.
const LADO := 48

const TAM := {
	"escalera_baja": Vector2i(48, 48),
	"escalera_sube": Vector2i(48, 48),
	"puerta_pueblo": Vector2i(40, 52),
}

const PROPS := ["escalera_baja", "escalera_sube", "puerta_pueblo"]

const PELDANOS := 6

enum {
	VACIO = 0,
	BORDE,
	HUECO,          # el negro del fondo del hueco
	PIEDRA_OSC, PIEDRA, PIEDRA_CLARA, PIEDRA_LUZ,
	MADERA_OSC, MADERA, MADERA_CLARA,
	HIERRO,
	LUZ,            # la luz calida que se cuela por debajo de la puerta
}

const PAL := [
	Color(0, 0, 0, 0),
	Color(0.02, 0.02, 0.03),
	Color(0.03, 0.04, 0.06),
	Color(0.17, 0.16, 0.20),
	Color(0.28, 0.27, 0.33),
	Color(0.40, 0.38, 0.46),
	Color(0.56, 0.54, 0.62),
	Color(0.20, 0.12, 0.07),
	Color(0.33, 0.20, 0.11),
	Color(0.45, 0.29, 0.16),
	Color(0.16, 0.15, 0.17),
	Color(1.00, 0.84, 0.52),
]


static func tam(clave: String) -> Vector2i:
	return TAM.get(clave, Vector2i(LADO, LADO))


static func _rnd(x: int, y: int, s: int) -> float:
	var n: int = x * 374761393 + y * 668265263 + s * 1013904223
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xFFFF) / 65535.0


static func _dibujar(clave: String) -> PackedByteArray:
	if clave == "puerta_pueblo":
		return _puerta()
	return _escalera(clave == "escalera_baja")


# ============================================================
#  LA PUERTA DEL PUEBLO
# ============================================================
# Un arco de sillares con su puerta de tablones. Lo que la convierte en un FARO -- y mas ahora que
# la mazmorra se va a jugar a oscuras -- es la luz calida que se cuela por las rendijas: es el
# unico sitio del piso con luz de dia, asi que el ojo la busca sola desde el otro lado de la sala.
static func _puerta() -> PackedByteArray:
	var t: Vector2i = TAM["puerta_pueblo"]
	var w: int = t.x
	var h: int = t.y
	var p := PackedByteArray()
	p.resize(w * h)
	var cx: float = float(w) * 0.5
	var arranque: float = 20.0        # altura a la que el arco deja de ser recto y curva
	var grosor: float = 5.0           # sillares del marco
	for y in h:
		for x in w:
			var i: int = y * w + x
			# --- silueta del arco: rectangulo abajo, semicirculo arriba ---
			var dx: float = absf(float(x) + 0.5 - cx)
			var limite: float = float(w) * 0.5 - 1.0
			if float(y) < arranque:
				var dy: float = arranque - float(y)
				var r: float = limite * limite - dy * dy
				limite = sqrt(r) if r > 0.0 else -1.0
			if limite < 0.0 or dx > limite:
				continue
			# --- marco o vano ---
			if dx > limite - grosor or y >= h - 2:
				# SILLARES: juntas horizontales cada 7 px y verticales alternadas, para que se lea
				# como piedra puesta a mano y no como un tubo.
				var junta: bool = (y % 7 == 0) or (int((float(x) + float(y / 7) * 4.0) / 9.0) \
					!= int((float(x) + float(y / 7) * 4.0 + 1.0) / 9.0))
				var v: float = 0.55 + _rnd(x, y, 13) * 0.3
				p[i] = PIEDRA_OSC if junta else (PIEDRA_CLARA if v > 0.70 else PIEDRA)
				continue
			# --- la hoja de la puerta: tablones verticales ---
			var col: int = MADERA
			if (x + 1) % 7 == 0:
				col = MADERA_OSC                       # junta entre tablones
			elif _rnd(x, y, 29) > 0.72:
				col = MADERA_CLARA                     # veta
			# herrajes
			if y == 24 or y == 25 or y == 38 or y == 39:
				col = HIERRO
			# el aro de la manilla
			var mx: float = float(x) - (cx + 6.0)
			var my: float = float(y) - 32.0
			var d: float = sqrt(mx * mx + my * my)
			if d > 2.2 and d < 4.0:
				col = HIERRO
			# LA RENDIJA: la luz del pueblo por debajo y por los lados de la hoja
			if y >= h - 5 or dx > limite - grosor - 1.0:
				col = LUZ
			p[i] = col
	SpriteLienzo.contornear(p, Rect2i(1, 1, w - 2, h - 2), w, h, BORDE, VACIO, VACIO)
	return p


# El hueco es un rectangulo con el marco de piedra. Dentro, PELDANOS bandas horizontales: la de
# mas abajo es la mas cercana al jugador. 'baja' invierte hacia donde va la luz.
static func _escalera(baja: bool) -> PackedByteArray:
	var p := PackedByteArray()
	p.resize(LADO * LADO)
	var marco: int = 4                       # px de brocal de piedra alrededor del hueco
	var dentro_alto: int = LADO - marco * 2
	var alto_esc: float = float(dentro_alto) / float(PELDANOS)
	for y in LADO:
		for x in LADO:
			var i: int = y * LADO + x
			if x < marco or y < marco or x >= LADO - marco or y >= LADO - marco:
				# EL BROCAL. Va oscuro y solo se le ilumina el canto de fuera. Cuando era tan
				# claro como los peldaños de delante, el conjunto no se leia como un agujero en
				# el suelo sino como una baldosa con rayas.
				var v: float = 0.30 + _rnd(x, y, 7) * 0.22
				if x < 2 or y < 2 or x >= LADO - 2 or y >= LADO - 2:
					v += 0.30
				p[i] = PIEDRA_CLARA if v > 0.52 else PIEDRA_OSC
				continue

			# --- dentro del hueco: los peldaños ---
			var t: float = float(y - marco) / alto_esc          # en unidades de escalon
			var escalon: int = clampi(int(t), 0, PELDANOS - 1)  # 0 = el de mas al fondo
			# A donde va la luz. Bajando, el fondo (arriba) esta a oscuras; subiendo, es la boca
			# de arriba la que esta iluminada. Es LO UNICO que distingue una escalera de la otra,
			# porque desde arriba las dos son el mismo hueco con peldaños.
			var f: float = float(escalon) / float(PELDANOS - 1)
			var luz: float = f if baja else (1.0 - f)
			# CONTRAHUELLA: el canto vertical de cada peldaño, casi negro y de 2 px. Es lo que
			# hace que se vean ESCALONES; sin ella queda un degradado liso y no se lee nada.
			var dentro_esc: float = t - float(escalon)
			if dentro_esc * alto_esc < 2.0:
				p[i] = HUECO
				continue
			# PAREDES del hueco: los dos costados van en sombra. Da profundidad y remata la
			# lectura de "esto es un agujero", no una escalera pintada en el suelo.
			var borde_lat: int = mini(x - marco, LADO - 1 - marco - x)
			if borde_lat < 3:
				luz *= 0.35 + 0.2 * float(borde_lat)
			luz += (_rnd(x, y, 31) - 0.5) * 0.10
			if luz < 0.12:
				p[i] = HUECO
			elif luz < 0.38:
				p[i] = PIEDRA_OSC
			elif luz < 0.64:
				p[i] = PIEDRA
			elif luz < 0.86:
				p[i] = PIEDRA_CLARA
			else:
				p[i] = PIEDRA_LUZ
	SpriteLienzo.contornear(p, Rect2i(1, 1, LADO - 2, LADO - 2), LADO, LADO, BORDE, VACIO, VACIO)
	return p


static func generar(clave: String) -> Image:
	var t: Vector2i = tam(clave)
	var p: PackedByteArray = _dibujar(clave)
	var datos := PackedByteArray()
	datos.resize(t.x * t.y * 4)
	for i in p.size():
		var c: Color = PAL[p[i]]
		if c.a <= 0.0:
			continue
		var o: int = i * 4
		datos[o] = int(c.r * 255.0)
		datos[o + 1] = int(c.g * 255.0)
		datos[o + 2] = int(c.b * 255.0)
		datos[o + 3] = 255
	return Image.create_from_data(t.x, t.y, false, Image.FORMAT_RGBA8, datos)


static func hornear(clave: String) -> int:
	DirAccess.make_dir_recursive_absolute(CARPETA)
	var png: String = CARPETA + clave + ".png"
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
	var png: String = CARPETA + clave + ".png"
	if ResourceLoader.exists(png):
		tex = load(png) as Texture2D
	if tex == null:
		tex = ImageTexture.create_from_image(generar(clave))
	_cache[clave] = tex
	return tex
