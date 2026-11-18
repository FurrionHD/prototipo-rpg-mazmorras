# ============================================================
#  aro_pixel.gd  (sin class_name: se usa con preload)
#  LOS AROS DE ALCANCE EN PIXEL (18/11, su decision: «la de ahora me parece gorda, tendria que ser mas fina y que se
#  viese con estilo pixel, no como un dibujo»). Un aro es una TEXTURA blanca de pixeles nitidos (se tiñe al pintarla
#  con el color del ajuste), A PUNTOS o A RAYAS, recorriendo el circulo pixel a pixel como lo trazaria un dibujante de
#  pixel art. Se hace una vez por radio y estilo y se guarda: pintar un aro es un draw_texture, no cientos de lineas.
#
#  Quien lo pinta con filtro NEAREST (ArenaCombate._aros y la muestra de Ajustes), o los pixeles salen borrosos.
# ============================================================

extends RefCounted

enum Trazo { PUNTOS, RAYAS }

const MAX_CACHE := 96

static var _cache: Dictionary = {}


# La textura de un aro de radio 'radio' (en pixeles de mundo). tam = grosor del punto o de la raya (1-3 px),
# largo = lo que mide cada raya (en pixeles del recorrido), hueco = lo que hay entre punto y punto o raya y raya.
static func textura(radio: float, trazo: int, tam: int, largo: int, hueco: int) -> ImageTexture:
	var r: int = maxi(2, roundi(radio))
	tam = clampi(tam, 1, 4)
	largo = maxi(1, largo)
	hueco = maxi(1, hueco)
	var clave: String = "%d|%d|%d|%d|%d" % [r, trazo, tam, largo, hueco]
	if _cache.has(clave):
		return _cache[clave]
	if _cache.size() >= MAX_CACHE:
		_cache.clear()
	var lado: int = 2 * r + tam + 2
	var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var pix: Array = recorrido(r)
	var n: int = pix.size()
	# EL PATRON CIERRA SIN COSTURA: se cuentan cuantas veces cabe y se reparte el recorrido entre ellas, asi el ultimo
	# punto no se pega al primero.
	var periodo: int = (tam if trazo == Trazo.PUNTOS else largo) + hueco
	var veces: int = maxi(1, roundi(float(n) / float(periodo)))
	var lleno: float = float(tam if trazo == Trazo.PUNTOS else largo) / float(periodo)
	var c0: int = r + 1
	var ultimo_punto: int = -1
	for i in n:
		var fase: float = fmod(float(i) * float(veces) / float(n), 1.0)
		if trazo == Trazo.PUNTOS:
			# Un punto (cuadrado de tam x tam) al empezar cada periodo.
			var k: int = int(float(i) * float(veces) / float(n))
			if k == ultimo_punto:
				continue
			ultimo_punto = k
		elif fase >= lleno:
			continue
		var p: Vector2i = pix[i]
		var o: int = (tam - 1) / 2
		for dy in tam:
			for dx in tam:
				var x: int = c0 + p.x - o + dx
				var y: int = c0 + p.y - o + dy
				if x >= 0 and y >= 0 and x < lado and y < lado:
					img.set_pixel(x, y, Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	_cache[clave] = tex
	return tex


# EL CIRCULO PIXEL A PIXEL, en orden (empieza arriba y da la vuelta), sin repetir y sin escalones dobles: cada pixel
# toca al siguiente por un lado o una esquina, como el aro a mano de un sprite.
static func recorrido(r: int) -> Array:
	var out: Array = []
	var pasos: int = maxi(16, int(TAU * float(r) * 3.0))
	for i in pasos:
		var a: float = TAU * float(i) / float(pasos) - PI * 0.5
		var p := Vector2i(roundi(cos(a) * float(r)), roundi(sin(a) * float(r)))
		if not out.is_empty() and out[-1] == p:
			continue
		# Si el anterior y este hacen escalon (L), el del medio sobra: queda un pixel de mas en la curva.
		if out.size() >= 2:
			var q: Vector2i = out[-2]
			if absi(q.x - p.x) <= 1 and absi(q.y - p.y) <= 1:
				out[-1] = p
				continue
		out.append(p)
	if out.size() > 1 and out[-1] == out[0]:
		out.pop_back()
	return out


# Donde se pinta la textura para que su centro caiga en 'centro' (en pixeles enteros: sin medio pixel borroso).
static func esquina(centro: Vector2, tex: Texture2D) -> Vector2:
	return (centro - Vector2(tex.get_width(), tex.get_height()) * 0.5).round()
