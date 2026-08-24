# ============================================================
#  sprite_lienzo.gd  (class_name SpriteLienzo)
#  El MOTOR que comparten los generadores de sprites por codigo (SlimeSprites, RataSprites...).
#  No sabe dibujar ningun bicho: sabe manejar una PLANTILLA -- una rejilla de bytes donde cada
#  celda guarda a que "tono" pertenece -- y convertirla en textura con una paleta.
#
#  POR QUE LA PLANTILLA GUARDA TONOS Y NO COLORES: es lo que separa la parte CARA (geometria:
#  elipses, raices, contornos) de la BARATA (pintar). La geometria no depende del color, asi que se
#  calcula una vez y sirve para todas las variantes de color del mismo bicho. Sin esta separacion,
#  cada tono de slime regeneraba sus 192 texturas y entrar a un piso congelaba el juego varios
#  segundos (ver el historial de slime_sprites.gd).
#
#  EL ENUM DE TONOS LO DECLARA CADA GENERADOR, no este archivo: aqui un tono es solo un indice, y
#  la paleta es un array de colores en ese mismo orden. Asi el slime puede tener CORONA/GEMA y la
#  rata COLA/DIENTE sin que ninguno arrastre las ranuras del otro.
#
#  LO QUE NO ESTA AQUI, A PROPOSITO: los bucles que recorren celda por celda (silueta, sombreado,
#  contorno). Son el codigo CALIENTE -- miles de iteraciones por frame -- y viven dentro de cada
#  generador con las cuentas puestas en linea. Sacarlos aqui costaria una llamada a funcion por
#  celda, que es justo lo que se quito para que esto fuera rapido.
# ============================================================

extends RefCounted
class_name SpriteLienzo

# Tono 0 = fuera de la figura. Lo unico que este motor da por supuesto de los enums ajenos.
const VACIO := 0

# ============================================================
#  EL TAMAÑO DEL PIXEL ES UNO PARA TODO EL JUEGO
# ============================================================
# Cuantas unidades de mundo mide UNA celda de cualquier sprite generado. Es EL numero que mantiene
# coherente el pixel-art: un enemigo mas grande se dibuja con MAS CELDAS, nunca con celdas mas
# gordas.
#
# Antes se hacia justo al reves -- se generaba una textura del mismo tamaño para todos y se estiraba
# el nodo con 'escala_visual' -- y por eso el Rey Slime (escala 2.6) tenia unos pixelotes casi el
# triple de grandes que un slime normal, y el Rey Rata lo mismo. Se ve enseguida y canta: en un
# juego de pixel-art la rejilla tiene que ser la misma para todo lo que aparece en pantalla.
#
# CONSECUENCIA para quien escriba un generador: 'escala_base()' devuelve SIEMPRE esto (no depende
# del bicho), y es la GEOMETRIA la que se multiplica por escala_visual, junto con el tamaño del
# lienzo. Y enemy.gd NO debe volver a escalar el sprite: eso solo vale para la caja de colision.
const UNIDADES_POR_CELDA := 0.62


# ------------------------------------------------------------
#  Color y paleta
# ------------------------------------------------------------

# REDONDEA el color a unos pocos escalones. Es lo que hace que la cache de un generador ACIERTE:
# el color de un bicho sale de EnemyData.color_visual(current_t) y 'current_t' es un randf() POR
# BICHO, asi que sin cuantizar hay tantas variantes como bichos y no se reutiliza ni una.
static func cuantizar(c: Color, pasos: float = 6.0) -> Color:
	return Color(round(c.r * pasos) / pasos, round(c.g * pasos) / pasos,
		round(c.b * pasos) / pasos, c.a)


# Lo mismo, pero SIN TOCAR EL TONO: escalona solo saturacion y brillo.
#
# Hace falta para los bichos de color apagado. Redondeando canal a canal, dos canales parecidos se
# igualan y el color CAMBIA DE TONO: el leonado del Rey rata (0.71, 0.61, 0.46) salia (0.67, 0.67,
# 0.50), o sea verde oliva, porque el rojo y el verde caian en el mismo escalon. Con un rojo puro
# como el del slime eso no pasa (su canal rojo esta clavado en 1), por eso alli no se vio.
#
# El tono es justo lo que NO debe moverse -- 'color_visual' solo aclara al bicho segun su fuerza --
# asi que se conserva exacto y se redondea el resto.
static func cuantizar_hsv(c: Color, pasos: float = 6.0) -> Color:
	var out := Color.from_hsv(c.h, round(c.s * pasos) / pasos, round(c.v * pasos) / pasos)
	out.a = c.a
	return out


# Colores (en el orden del enum de tonos del generador) -> bytes RGBA listos para el pintado.
static func paleta(cols: Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(cols.size() * 4)
	for i in cols.size():
		var c: Color = cols[i]
		out[i * 4] = int(round(c.r * 255.0))
		out[i * 4 + 1] = int(round(c.g * 255.0))
		out[i * 4 + 2] = int(round(c.b * 255.0))
		out[i * 4 + 3] = int(round(c.a * 255.0))
	return out


# Plantilla + paleta -> textura. Es la parte BARATA: ni una elipse, solo copiar 4 bytes por celda.
# Por eso la segunda variante de color de un mismo bicho sale casi gratis.
static func a_textura(celdas: PackedByteArray, pal: PackedByteArray, w: int, h: int) -> ImageTexture:
	var datos := PackedByteArray()
	datos.resize(w * h * 4)
	for i in celdas.size():
		var o: int = i * 4
		var p: int = int(celdas[i]) * 4
		datos[o] = pal[p]
		datos[o + 1] = pal[p + 1]
		datos[o + 2] = pal[p + 2]
		datos[o + 3] = pal[p + 3]
	return ImageTexture.create_from_image(
		Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, datos))


# ------------------------------------------------------------
#  Formas
# ------------------------------------------------------------

static func en_elipse(gx: int, gy: int, cx: float, cy: float, rx: float, ry: float) -> bool:
	if rx <= 0.01 or ry <= 0.01:
		return false
	var dx: float = (float(gx) + 0.5 - cx) / rx
	var dy: float = (float(gy) + 0.5 - cy) / ry
	return dx * dx + dy * dy <= 1.0


# Elipse GIRADA (y opcionalmente vista EN PERSPECTIVA): el punto de pantalla se lleva al sistema de
# la elipse -- primero deshaciendo el aplastado, luego el giro -- y ahi se compara como siempre.
# Se le pasan el coseno y el seno ya calculados porque esto se llama por celda.
#
# 'persp' < 1 aplasta el eje vertical, que es lo que convierte una vista CENITAL PURA (camara justo
# encima, se ve solo el lomo) en la vista inclinada de un acion-RPG top-down, donde ademas de la
# espalda se le intuye la cara al bicho. Deshacerlo aqui, en el test, es exacto y gratis: una
# elipse aplastada sigue siendo una elipse.
static func en_elipse_rot(gx: int, gy: int, cx: float, cy: float, rx: float, ry: float,
		cos_a: float, sin_a: float, persp: float = 1.0) -> bool:
	if rx <= 0.01 or ry <= 0.01:
		return false
	var px: float = float(gx) + 0.5 - cx
	var py: float = (float(gy) + 0.5 - cy) / maxf(0.05, persp)
	var dx: float = (px * cos_a + py * sin_a) / rx
	var dy: float = (-px * sin_a + py * cos_a) / ry
	return dx * dx + dy * dy <= 1.0


# Marca una elipse en la plantilla recorriendo SOLO su caja envolvente: por cada ojo o cada mota de
# 3 celdas, recorrer la rejilla entera era casi todo el coste de un frame.
# 'ang' la gira (0 = sin giro, y ahi coge la rama rapida sin senos ni cosenos).
# 'solo_sobre' limita el pintado a celdas que ya tengan uno de esos tonos: es lo que permite echar
# un brillo encima del cuerpo sin que se derrame sobre las orejas o el contorno.
static func elipse(plant: PackedByteArray, w: int, h: int, cx: float, cy: float,
		rx: float, ry: float, tono: int, ang: float = 0.0, solo_sobre: Array = [],
		persp: float = 1.0) -> void:
	if rx <= 0.01 or ry <= 0.01:
		return
	var deformada: bool = not is_zero_approx(ang) or not is_equal_approx(persp, 1.0)
	var cos_a: float = cos(ang)
	var sin_a: float = sin(ang)
	# Caja envolvente EXACTA de la elipse girada (y aplastada): las proyecciones de sus semiejes.
	# Usar el radio mayor por los dos lados es lo facil, pero para una pieza alargada -- el cuerpo
	# del bicho -- pinta un cuadrado donde cabria un rectangulo, y se recorre hueco de mas en la
	# parte mas cara del generador.
	var ex: float = rx
	var ey: float = ry
	if deformada:
		var cs: float = cos_a * cos_a
		var sn: float = sin_a * sin_a
		ex = sqrt(rx * rx * cs + ry * ry * sn)
		ey = sqrt(rx * rx * sn + ry * ry * cs) * persp
	var x0: int = maxi(0, int(floor(cx - ex)))
	var x1: int = mini(w - 1, int(ceil(cx + ex)))
	var y0: int = maxi(0, int(floor(cy - ey)))
	var y1: int = mini(h - 1, int(ceil(cy + ey)))
	var filtra: bool = not solo_sobre.is_empty()
	for gy in range(y0, y1 + 1):
		var fila: int = gy * w
		for gx in range(x0, x1 + 1):
			var dentro: bool = en_elipse_rot(gx, gy, cx, cy, rx, ry, cos_a, sin_a, persp) if deformada \
				else en_elipse(gx, gy, cx, cy, rx, ry)
			if not dentro:
				continue
			var idx: int = fila + gx
			if filtra and not (int(plant[idx]) in solo_sobre):
				continue
			plant[idx] = tono


# Caja de trabajo recortada al lienzo, con una celda de aire alrededor (el contorno mira a los
# vecinos, asi que hace falta sitio para ese vecino vacio).
static func caja(x0: float, y0: float, x1: float, y1: float, w: int, h: int) -> Rect2i:
	var ix0: int = clampi(int(floor(x0)) - 1, 0, w - 1)
	var ix1: int = clampi(int(ceil(x1)) + 2, 0, w)
	var iy0: int = clampi(int(floor(y0)) - 1, 0, h - 1)
	var iy1: int = clampi(int(ceil(y1)) + 2, 0, h)
	return Rect2i(ix0, iy0, maxi(0, ix1 - ix0), maxi(0, iy1 - iy0))


# ------------------------------------------------------------
#  Animacion
# ------------------------------------------------------------

# Interpolacion lineal entre puntos clave [t, valor] ordenados por t. Fuera del rango se queda con
# el extremo mas cercano (no extrapola). Para movimientos que NO son periodicos -- una embestida es
# agazaparse, lanzarse, chocar y recuperarse, no una onda.
static func tramos(t: float, claves: Array) -> float:
	if t <= claves[0][0]:
		return claves[0][1]
	for i in range(claves.size() - 1):
		var a: Array = claves[i]
		var b: Array = claves[i + 1]
		if t <= b[0]:
			var f: float = clampf((t - a[0]) / maxf(0.0001, b[0] - a[0]), 0.0, 1.0)
			return lerpf(a[1], b[1], f)
	return claves[-1][1]
