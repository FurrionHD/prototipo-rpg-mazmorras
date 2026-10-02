# ============================================================
#  golem3d_sprites.gd  (class_name Golem3DSprites)
#  EL GOLEM DE ARCILLA EN 3D (03/10/2026; la prueba le parecio "peak"). Como el Minotauro: se modela con formas que se
#  funden y huesos (tools/sprites_sdf/golem_sdf.py, motor en sdf_comun.py) y se pinta desde la camara del juego a unas
#  HOJAS (assets/sprites/enemigos/golem_sdf/<anim>.png: filas = direcciones, columnas = fotogramas). Aqui solo se CARGAN
#  y se pasan al formato del motor (plantillas de tonos + paleta), asi que para el juego es un generador mas.
#
#  EL COLOR DE CADA PISO: las hojas van en el barro de la ficha (BASE); el de cada variante (EnemyData.color_visual) se
#  saca TIÑENDO la paleta canal a canal. Los ojos y la brasa (lo que brilla) no se tiñen.
#  El viejo (GolemSprites, por codigo) se queda de referencia; SpritesEnemigo ya apunta aqui.
# ============================================================

extends RefCounted
class_name Golem3DSprites

const CARPETA := "res://assets/sprites/enemigos/golem_sdf/"
# El lienzo del generador viejo a escala 2,8 (y el del script de python): el juego lo coloca igual.
const LIENZO := Vector2i(162, 176)
# El barro en que estan pintadas las hojas (el color de golem_arcilla.tres).
const BASE := Color(0.6, 0.45, 0.3)

# Las animaciones que pide el juego -> la hoja de donde salen. 8 direcciones todas (en el tactico se ven todas).
const ANIMS := {
	"idle": {"hoja": "idle", "dirs": 8, "marcos": 8, "fps": 3.0, "loop": true},
	"walk": {"hoja": "walk", "dirs": 8, "marcos": 8, "fps": 5.0, "loop": true},
	# EL PUÑETAZO (su basico, anim_basico 'golem_golpe'): un puño arriba y cae; toca en el 6o de 8 a 10 fps.
	"basico": {"hoja": "basico", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	# LA MACHACA (fx_anim 'golem_machaca'): los dos puños arriba y caen como un yunque; tambien toca en el 6o.
	"golem_machaca": {"hoja": "golem_machaca", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	# Y como 'embestida', por si algo la pide por el nombre de siempre.
	"embestida": {"hoja": "golem_machaca", "dirs": 8, "marcos": 8, "fps": 10.0, "loop": false},
	"endurecerse": {"hoja": "endurecerse", "dirs": 8, "marcos": 8, "fps": 9.0, "loop": false},
	"encaje": {"hoja": "encaje", "dirs": 8, "marcos": 4, "fps": 18.0, "loop": false},
	# MORIR: se derrumba hundiendose en su propio barro. El CADAVER es su ultimo fotograma.
	"muerte": {"hoja": "muerte", "dirs": 8, "marcos": 8, "fps": 9.0, "loop": false},
	"cadaver": {"hoja": "muerte", "dirs": 8, "marcos": 1, "desde": 7, "fps": 1.0, "loop": false},
}

static var _cache: Dictionary = {}
static var _hojas: Dictionary = {}


# --- Contrato de SpritesEnemigo ---
static func generar_de(ed: EnemyData, t: float) -> SpriteFrames:
	return generar(ed.color_visual(t))


# 'golem3d_' y no 'golem_': con la clave vieja, SpritesEnemigo cargaria el horneado VIEJO de disco.
static func clave_de(ed: EnemyData, t: float) -> String:
	return "golem3d_%s" % SpriteLienzo.cuantizar_hsv(ed.color_visual(t), GolemSprites.COLOR_PASOS).to_html(false)


static func escala_base() -> float:
	return SpriteLienzo.UNIDADES_POR_CELDA


static func ancho_px(_escala: float = 1.0) -> int:
	return LIENZO.x


static func dimensiona_por_escala() -> bool:
	return true


# La colision, la del viejo: el bulto es el mismo.
static func tam_cuerpo(escala: float = 1.0) -> Vector2:
	return GolemSprites.tam_cuerpo(escala)


static func generar(color: Color = BASE) -> SpriteFrames:
	var col: Color = SpriteLienzo.cuantizar_hsv(color, GolemSprites.COLOR_PASOS)
	var clave: String = col.to_html(false)
	if _cache.has(clave):
		return _cache[clave]
	var paleta: Array = [Color(0, 0, 0, 0)]       # el 0 es VACIO
	var indice: Dictionary = {}                    # color (rgba8 como entero) -> tono
	var anims: Array = []
	for nombre in ANIMS:
		var a: Dictionary = ANIMS[nombre]
		var img: Image = _hoja(String(a["hoja"]))
		if img == null:
			push_error("[golem3d] falta la hoja %s" % a["hoja"])
			continue
		for dir in int(a["dirs"]):
			var plantillas: Array = []
			for i in int(a["marcos"]):
				plantillas.append(_plantilla(img, int(a.get("desde", 0)) + i, dir, paleta, indice))
			anims.append({"nombre": "%s_%d" % [nombre, dir], "loop": a["loop"], "fps": a["fps"],
				"plantillas": plantillas})
	# EL TINTE DEL PISO: canal a canal, lo de barro (lo que brilla se queda).
	var k := Vector3(col.r / BASE.r, col.g / BASE.g, col.b / BASE.b)
	for i in range(1, paleta.size()):
		var c: Color = paleta[i]
		if c.v > 0.88 and c.s > 0.2:
			continue
		paleta[i] = Color(clampf(c.r * k.x, 0.0, 1.0), clampf(c.g * k.y, 0.0, 1.0), clampf(c.b * k.z, 0.0, 1.0), 1.0)
	var sf: SpriteFrames = SpriteLienzo.montar_frames(anims, SpriteLienzo.paleta(paleta), LIENZO.x, LIENZO.y)
	_cache[clave] = sf
	return sf


static func _hoja(nombre: String) -> Image:
	if _hojas.has(nombre):
		return _hojas[nombre]
	var tex: Texture2D = load(CARPETA + nombre + ".png") if ResourceLoader.exists(CARPETA + nombre + ".png") else null
	var im: Image = tex.get_image() if tex != null else null
	if im != null:
		if im.is_compressed():
			im.decompress()
		im.convert(Image.FORMAT_RGBA8)
	_hojas[nombre] = im
	return im


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
			var kk: int = c.to_rgba32()
			var t: int = indice.get(kk, -1)
			if t < 0:
				t = paleta.size()
				if t > 255:
					t = 1
				else:
					paleta.append(Color(c.r, c.g, c.b, 1.0))
					indice[kk] = t
			plant[y * LIENZO.x + x] = t
	return plant
