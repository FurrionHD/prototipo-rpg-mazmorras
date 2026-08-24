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

# 48 y no 32: la escalera tiene que leerse como un hueco en el suelo, y a una celda justa los
# peldaños salen de 3 px y se emborronan.
const LADO := 48

const PROPS := ["escalera_baja", "escalera_sube"]

const PELDANOS := 6

enum {
	VACIO = 0,
	BORDE,
	HUECO,          # el negro del fondo del hueco
	PIEDRA_OSC, PIEDRA, PIEDRA_CLARA, PIEDRA_LUZ,
}

const PAL := [
	Color(0, 0, 0, 0),
	Color(0.02, 0.02, 0.03),
	Color(0.03, 0.04, 0.06),
	Color(0.17, 0.16, 0.20),
	Color(0.28, 0.27, 0.33),
	Color(0.40, 0.38, 0.46),
	Color(0.56, 0.54, 0.62),
]


static func _rnd(x: int, y: int, s: int) -> float:
	var n: int = x * 374761393 + y * 668265263 + s * 1013904223
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xFFFF) / 65535.0


# El hueco es un rectangulo con el marco de piedra. Dentro, PELDANOS bandas horizontales: la de
# mas abajo es la mas cercana al jugador. 'baja' invierte hacia donde va la luz.
static func _dibujar(baja: bool) -> PackedByteArray:
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
	var p: PackedByteArray = _dibujar(clave == "escalera_baja")
	var datos := PackedByteArray()
	datos.resize(LADO * LADO * 4)
	for i in p.size():
		var c: Color = PAL[p[i]]
		if c.a <= 0.0:
			continue
		var o: int = i * 4
		datos[o] = int(c.r * 255.0)
		datos[o + 1] = int(c.g * 255.0)
		datos[o + 2] = int(c.b * 255.0)
		datos[o + 3] = 255
	return Image.create_from_data(LADO, LADO, false, Image.FORMAT_RGBA8, datos)


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
