# ============================================================
#  sprites_3d.gd  (class_name Sprites3D)
#  LO COMUN DE LOS ENEMIGOS EN 3D (03/10/2026): sus hojas salen de tools/sprites_sdf (<enemigo>_sdf.py, motor en
#  sdf_comun.py) a assets/sprites/enemigos/<enemigo>_sdf/<anim>.png (filas = direcciones, columnas = fotogramas). Aqui
#  se CARGAN y se pasan al formato del motor (plantillas de tonos + paleta, SpriteLienzo.montar_frames), asi que para
#  el juego cada uno es un generador mas. Lo usan Golem3DSprites y Jabali3DSprites (el Minotauro va aparte: fue el
#  primero y tiene su variante rota).
#
#  EL COLOR DE CADA PISO: las hojas van pintadas en un color BASE; el de cada variante (EnemyData.color_visual) se saca
#  TIÑENDO la paleta canal a canal. Lo muy claro (ojos, brasa, colmillos) no se tiñe.
# ============================================================

extends RefCounted
class_name Sprites3D

static var _cache: Dictionary = {}
static var _hojas: Dictionary = {}


# 'anims' = {nombre: {hoja, dirs, marcos, fps, loop, [desde]}}; 'lienzo' = el de las hojas.
# 'sufijo' = "_parpado" monta la hoja de los PARPADOS (05/10, los slimes: solo los ojos cerrados, ver Parpadeo). Las
# animaciones que no la tengan se saltan sin error; null si no hay ninguna.
static func montar(carpeta: String, anims_tabla: Dictionary, lienzo: Vector2i, base: Color, color: Color,
		sufijo: String = "") -> SpriteFrames:
	var clave: String = carpeta + color.to_html(false) + sufijo
	if _cache.has(clave):
		return _cache[clave]
	var est: Dictionary = _estructura(carpeta, anims_tabla, lienzo, sufijo)
	var anims: Array = est["anims"]
	if anims.is_empty():
		_cache[clave] = null
		return null
	# EL TINTE DEL PISO, canal a canal (lo muy claro se queda). Sobre una COPIA de la paleta: la de la estructura es de
	# todos los colores.
	var paleta: Array = (est["paleta"] as Array).duplicate()
	var k := Vector3(color.r / maxf(base.r, 0.01), color.g / maxf(base.g, 0.01), color.b / maxf(base.b, 0.01))
	for i in range(1, paleta.size()):
		var c: Color = paleta[i]
		if c.v > 0.85:
			continue
		paleta[i] = Color(clampf(c.r * k.x, 0.0, 1.0), clampf(c.g * k.y, 0.0, 1.0), clampf(c.b * k.z, 0.0, 1.0), c.a)
	var sf: SpriteFrames = SpriteLienzo.montar_frames_con_plan(anims, SpriteLienzo.paleta(paleta), lienzo.x, lienzo.y, est["plan"])
	_cache[clave] = sf
	return sf


# LO QUE NO DEPENDE DEL COLOR, una sola vez por hoja (08/10, playtest: "cada vez que un enemigo se transforma da un lagazo
# brutal"). El tinte sale de la 't' de cada enemigo, asi que casi cada slime que mutaba pedia un color nuevo, y por cada
# color se volvian a leer las hojas pixel a pixel (los parpados del mutante no van horneados: 0,2-1,4 s, y 6 s el de mil
# ojos). Las plantillas de tonos y la paleta BASE son las mismas para todos los colores: se guardan aqui y un color nuevo
# solo tiñe la paleta y repinta. {"anims": [...], "paleta": [Color], "plan": el de SpriteLienzo.montar_frames_con_plan};
# anims vacio = esa hoja no existe.
static var _estructuras: Dictionary = {}

static func _estructura(carpeta: String, anims_tabla: Dictionary, lienzo: Vector2i, sufijo: String) -> Dictionary:
	var clave: String = "%s|%s|%s|%s" % [carpeta, sufijo, lienzo, anims_tabla.keys()]
	if _estructuras.has(clave):
		return _estructuras[clave]
	var paleta: Array = [Color(0, 0, 0, 0)]       # el 0 es VACIO
	var indice: Dictionary = {}                    # color (rgba8 como entero) -> tono
	var anims: Array = []
	for nombre in anims_tabla:
		var a: Dictionary = anims_tabla[nombre]
		var ruta: String = carpeta + String(a["hoja"]) + sufijo + ".png"
		var img: Image = _hoja(ruta) if ResourceLoader.exists(ruta) else null
		# Las OPCIONALES (comer, 05/10: solo la llevan algunas variantes) se saltan sin error si su hoja no esta.
		if img == null and bool(a.get("opcional", false)):
			continue
		if img == null:
			if sufijo.is_empty():
				push_error("[sprites3d] falta la hoja %s%s" % [carpeta, a["hoja"]])
			continue
		for dir in int(a["dirs"]):
			var plantillas: Array = []
			for i in int(a["marcos"]):
				plantillas.append(_plantilla(img, lienzo, int(a.get("desde", 0)) + i, dir, paleta, indice))
			anims.append({"nombre": "%s_%d" % [nombre, dir], "loop": a["loop"], "fps": a["fps"],
				"plantillas": plantillas})
	var est: Dictionary = {"anims": anims, "paleta": paleta, "plan": {}}   # plan: lo rellena montar_frames_con_plan la 1a vez
	_estructuras[clave] = est
	return est


static func _hoja(ruta: String) -> Image:
	if _hojas.has(ruta):
		return _hojas[ruta]
	var tex: Texture2D = load(ruta) if ResourceLoader.exists(ruta) else null
	var im: Image = tex.get_image() if tex != null else null
	if im != null:
		if im.is_compressed():
			im.decompress()
		im.convert(Image.FORMAT_RGBA8)
	_hojas[ruta] = im
	return im


# Un fotograma de la hoja (columna 'col', fila 'fila') a plantilla de tonos, añadiendo a la paleta los colores nuevos.
static func _plantilla(img: Image, lienzo: Vector2i, col: int, fila: int, paleta: Array, indice: Dictionary) -> PackedByteArray:
	var plant := PackedByteArray()
	plant.resize(lienzo.x * lienzo.y)
	plant.fill(0)
	var x0: int = col * lienzo.x
	var y0: int = fila * lienzo.y
	if x0 + lienzo.x > img.get_width() or y0 + lienzo.y > img.get_height():
		return plant
	# SOLO LO PINTADO, Y A BYTES (08/10, playtest: "cada vez que un enemigo se transforma da un lagazo brutal"). Se leia
	# el lienzo entero con get_pixel, y las hojas de PARPADOS son casi todo aire: montar las del mutante (que no van
	# horneadas, se montan al transformarse) costaba de 0,2 a 1,4 s y 6,4 s el slime de mil ojos. Ahora se recorta al
	# rectangulo usado del fotograma (get_used_rect, nativo) y se leen los bytes RGBA8 directamente. Mismo resultado
	# pixel a pixel: la misma paleta en el mismo orden (fila a fila, de izquierda a derecha).
	var trozo: Image = img.get_region(Rect2i(x0, y0, lienzo.x, lienzo.y))
	var usado: Rect2i = trozo.get_used_rect()
	if not usado.has_area():
		return plant
	var bytes: PackedByteArray = trozo.get_data()
	var paso: int = lienzo.x * 4
	for y in range(usado.position.y, usado.end.y):
		var i: int = y * paso + usado.position.x * 4
		for x in range(usado.position.x, usado.end.x):
			var a8: int = bytes[i + 3]
			# LO SEMITRANSPARENTE SE QUEDA (05/10, el gel de los slimes): antes, lo de menos de media opacidad se borraba y
			# lo demas salia opaco. Solo se salta lo vacio (a < 0,02, o sea a8 <= 5).
			if a8 > 5:
				var r8: int = bytes[i]
				var g8: int = bytes[i + 1]
				var b8: int = bytes[i + 2]
				var kk: int = (r8 << 24) | (g8 << 16) | (b8 << 8) | a8
				var t: int = indice.get(kk, -1)
				if t < 0:
					t = paleta.size()
					if t > 255:
						t = 1
					else:
						paleta.append(Color8(r8, g8, b8, a8))
						indice[kk] = t
				plant[y * lienzo.x + x] = t
			i += 4
	return plant
	for y in lienzo.y:
		for x in lienzo.x:
			var c: Color = img.get_pixel(x0 + x, y0 + y)
			# LO SEMITRANSPARENTE SE QUEDA (05/10, el gel de los slimes): antes, lo de menos de media opacidad se borraba y
			# lo demas salia opaco. Solo se salta lo vacio.
			if c.a < 0.02:
				continue
			var kk: int = c.to_rgba32()
			var t: int = indice.get(kk, -1)
			if t < 0:
				t = paleta.size()
				if t > 255:
					t = 1
				else:
					paleta.append(Color(c.r, c.g, c.b, c.a))
					indice[kk] = t
			plant[y * lienzo.x + x] = t
	return plant
