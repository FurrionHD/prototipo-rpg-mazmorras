# ============================================================
#  minotauro_sprites.gd  (class_name MinotauroSprites)
#  El MINOTAURO, jefe del piso 12 (scenes/actors/enemy/guardian_rango.tres).
#
#  YA NO SE DIBUJA AQUI (01/10). Con bolas en 2D no habia forma de que pareciera un cuerpo, asi que se modela en 3D con
#  formas que se funden y huesos (tools/sprites_sdf/minotauro_sdf.py) y se pinta desde la camara del juego a unas HOJAS
#  (assets/sprites/enemigos/minotauro_sdf/<anim>.png: filas = direcciones, columnas = fotogramas). Este generador solo
#  las CARGA y las pasa al formato del motor (plantillas de tonos + paleta, SpriteLienzo.montar_frames), asi que para el
#  resto del juego es un generador mas: mismas animaciones, mismo lienzo y los pies en el mismo sitio que el de antes.
#
#  Para cambiar el dibujo: tocar el script de python y volver a sacar las hojas (herramientas: ver su cabecera).
# ============================================================

extends RefCounted
class_name MinotauroSprites

const CARPETA := "res://assets/sprites/enemigos/minotauro_sdf/"

# EL LIENZO, el mismo que salia del generador viejo (y el que usa el script de python): 40 unidades de alto a escala
# 3,1 son 107,8 celdas; de ancho 1,46 de eso, de alto 1,62 y los pies a 1,28 desde arriba.
# EL ANCHO crece a 2,2 (238): con el brazo estirado y el hacha (el barrido) se salia. Crece igual a los dos lados, asi
# que el centro (donde el juego pone el nodo) y los pies siguen en el mismo sitio. Y el alto, 58 mas por arriba y por
# abajo (el hachazo se salia), por lo mismo.
const LIENZO := Vector2i(238, 292)

# Las animaciones que pide el juego -> la hoja de donde salen, cuantas direcciones y fotogramas tienen, fps y si repiten.
# PROVISIONAL (01/10): estan hechas 'idle', 'walk', 'basico', 'barrido', la cornada y el pisoton; el resto repite la quieta.
const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 3.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 6.0, "loop": true},
	"embestida": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	# EL HACHAZO, su basico: toca en el 6o de 8 a 10 fps (0,5 s; CombatFX.IMPACTO_ANIM_MAPA "mino_hachazo").
	"basico": {"hoja": "basico", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	# EL BARRIDO (el cono): el hacha pasa por delante en el 5o de 8 a 10 fps (0,4 s; IMPACTO_ANIM_MAPA "mino_barrido").
	"barrido": {"hoja": "barrido", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"cornada": {"hoja": "mino_cornada", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	# LA CORNADA (01/10): mientras avisa se pone A CUATRO PATAS echandose el hacha a la espalda y se queda AGAZAPADO
	# escarbando (fx_anim_carga "mino_agacharse>mino_agazapado"); al soltar, el juego le desliza por la linea y ENGANCHA
	# en el 3o de 8 a 12 fps (0,17 s: IMPACTO_ANIM_MAPA "mino_cornada"). Nombres propios: "cornada" es la del jabali.
	"mino_agacharse": {"hoja": "mino_agacharse", "dirs": 8, "marcos": 6, "fps": 10.0, "loop": false},
	"mino_agazapado": {"hoja": "mino_agazapado", "dirs": 8, "marcos": 4, "fps": 6.0, "loop": true},
	"mino_cornada": {"hoja": "mino_cornada", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"pisoton": {"hoja": "mino_pisoton", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	# EL PISOTON (01/10): levanta la derecha con los brazos abiertos y la deja caer con todo el peso en el 5o de 8 a
	# 12 fps (0,33 s: IMPACTO_ANIM_MAPA "mino_pisoton"). Nombre propio: "pisoton" lo usan otros.
	"mino_pisoton": {"hoja": "mino_pisoton", "dirs": 8, "marcos": 8, "fps": 12.0, "loop": false},
	"bramido": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 8.0, "loop": false},
	"encaje": {"hoja": "idle", "dirs": 1, "marcos": 4, "fps": 18.0, "loop": false},
	"muerte": {"hoja": "idle", "dirs": 1, "marcos": 8, "fps": 9.0, "loop": false},
	"cadaver": {"hoja": "idle", "dirs": 8, "marcos": 1, "fps": 1.0, "loop": false},
}

static var _cache: Dictionary = {}


# --- Contrato de SpritesEnemigo ---
static func generar_de(_ed: EnemyData, _t: float) -> SpriteFrames:
	return generar(false)


# 'minotauro3d' y no 'minotauro': con la clave vieja, SpritesEnemigo cargaria el horneado VIEJO de disco.
static func clave_de(_ed: EnemyData, _t: float) -> String:
	return "minotauro3d"


# LA RABIA (el cuerno partido): la hoja '<anim>_roto' si existe; si no, la normal.
static func generar_roto_de(_ed: EnemyData, _t: float) -> SpriteFrames:
	return generar(true)


static func clave_roto_de(_ed: EnemyData, _t: float) -> String:
	return "minotauro3d_roto"


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(_escala: float = 1.0) -> int:
	return LIENZO.x


static func dimensiona_por_escala() -> bool:
	return true


# El cuerpo en planta para la colision: lo marcan las pezuñas (unas 17 x 9 unidades del modelo, a su escala).
static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return Vector2(17.0, 9.0) * escala


static func generar(roto: bool = false) -> SpriteFrames:
	var clave: String = "roto" if roto else "normal"
	if _cache.has(clave):
		return _cache[clave]
	var paleta: Array = [Color(0, 0, 0, 0)]       # el 0 es VACIO
	var indice: Dictionary = {}                    # color (rgba8 como entero) -> tono
	var hojas: Dictionary = {}
	var anims: Array = []
	for nombre in ANIMS:
		var a: Dictionary = ANIMS[nombre]
		var hoja: String = String(a["hoja"])
		if roto and ResourceLoader.exists(CARPETA + hoja + "_roto.png"):
			hoja += "_roto"
		if not hojas.has(hoja):
			var tex: Texture2D = load(CARPETA + hoja + ".png")
			var im: Image = tex.get_image() if tex != null else null
			if im != null:
				if im.is_compressed():
					im.decompress()
				im.convert(Image.FORMAT_RGBA8)
			hojas[hoja] = im
		var img: Image = hojas[hoja]
		if img == null:
			push_error("[minotauro] falta la hoja %s" % hoja)
			continue
		for dir in int(a["dirs"]):
			var plantillas: Array = []
			for i in int(a["marcos"]):
				plantillas.append(_plantilla(img, i, dir, paleta, indice))
			anims.append({"nombre": "%s_%d" % [nombre, dir], "loop": a["loop"], "fps": a["fps"],
				"plantillas": plantillas})
	var sf: SpriteFrames = SpriteLienzo.montar_frames(anims, SpriteLienzo.paleta(paleta), LIENZO.x, LIENZO.y)
	_cache[clave] = sf
	return sf


# Un fotograma de la hoja (columna 'col', fila 'fila') a plantilla de tonos, añadiendo a la paleta los colores nuevos.
static func _plantilla(img: Image, col: int, fila: int, paleta: Array, indice: Dictionary) -> PackedByteArray:
	var plant := PackedByteArray()
	plant.resize(LIENZO.x * LIENZO.y)
	plant.fill(0)
	var x0: int = col * LIENZO.x
	var y0: int = fila * LIENZO.y
	if x0 + LIENZO.x > img.get_width() or y0 + LIENZO.y > img.get_height():
		return plant
	for y in LIENZO.y:
		for x in LIENZO.x:
			var c: Color = img.get_pixel(x0 + x, y0 + y)
			if c.a < 0.5:
				continue
			var k: int = c.to_rgba32()
			var t: int = indice.get(k, -1)
			if t < 0:
				t = paleta.size()
				if t > 255:
					t = 1
				else:
					paleta.append(Color(c.r, c.g, c.b, 1.0))
					indice[k] = t
			plant[y * LIENZO.x + x] = t
	return plant
