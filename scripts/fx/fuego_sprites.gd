# ============================================================
#  fuego_sprites.gd  (class_name FuegoSprites)
#  LOS FUEGOS DEL PUEBLO (antorchas y braseros), dibujados por codigo y fotograma a fotograma.
#
#  Parte de la llama del altar (LlamaAltar._fotograma), que al usuario le encanto: UNA silueta de
#  pixel-art que cambia poco de un fotograma a otro, base quieta y punta que se mece. Pero pidio que
#  no fueran todas iguales: "tipo 8 modelos de fuego diferente, que ondule diferente, que
#  chisporrotee de vez en cuando". Asi que aqui la llama es la UNION DE VARIAS LENGUAS, y cada
#  perfil las combina a su manera: una gota alta y tranquila, dos puntas que se turnan, una llama baja
#  y nerviosa, un brasero ancho de cinco lenguas...
#
#  Cada lengua: 'x' desplazamiento de su base (px), 'alto' (0..1 del alto del perfil), 'semi' media
#  anchura maxima (px), 'fase' (rad) con la que va desfasada, 'meneo' cuanto se mece la punta,
#  'respira' cuanto sube y baja, 'vueltas' cuantas veces se mece por ciclo (entero: el bucle empalma).
#
#  El chisporroteo y el encendido no van aqui (esto son solo imagenes): ver Antorcha.
# ============================================================
extends RefCounted
class_name FuegoSprites

# Los 5 primeros son de antorcha (estrechos); los 3 ultimos, de brasero (anchos).
const ANTORCHAS := [0, 1, 2, 3, 4]
const BRASEROS := [5, 6, 7]

const PERFILES := [
	# 0 - GOTA TRANQUILA: una lengua alta, se mece despacio.
	{"ancho": 16, "alto": 26, "frames": 8, "fps": 6.0, "ruido": 0.8, "lenguas": [
		{"x": 0.0, "alto": 1.0, "semi": 5.5, "fase": 0.0, "meneo": 1.6, "respira": 0.05, "vueltas": 1},
	]},
	# 1 - DOS PUNTAS que se turnan la altura.
	{"ancho": 16, "alto": 26, "frames": 8, "fps": 7.0, "ruido": 1.0, "lenguas": [
		{"x": -1.5, "alto": 0.95, "semi": 4.5, "fase": 0.0, "meneo": 1.4, "respira": 0.10, "vueltas": 1},
		{"x": 2.0, "alto": 0.80, "semi": 3.5, "fase": PI, "meneo": 1.8, "respira": 0.12, "vueltas": 1},
	]},
	# 2 - NERVIOSA: baja, rapida, con el borde muy roto.
	{"ancho": 16, "alto": 22, "frames": 6, "fps": 10.0, "ruido": 1.6, "lenguas": [
		{"x": 0.0, "alto": 1.0, "semi": 6.0, "fase": 0.0, "meneo": 1.2, "respira": 0.08, "vueltas": 2},
		{"x": 3.0, "alto": 0.55, "semi": 2.5, "fase": 1.7, "meneo": 1.5, "respira": 0.15, "vueltas": 1},
	]},
	# 3 - ESBELTA: alta y fina, con una lengua pequeña que asoma a la izquierda.
	{"ancho": 16, "alto": 30, "frames": 10, "fps": 7.0, "ruido": 0.9, "lenguas": [
		{"x": 0.5, "alto": 1.0, "semi": 4.5, "fase": 0.0, "meneo": 2.2, "respira": 0.07, "vueltas": 1},
		{"x": -3.0, "alto": 0.45, "semi": 2.2, "fase": 2.4, "meneo": 1.0, "respira": 0.20, "vueltas": 2},
	]},
	# 4 - TRES LENGUAS: ancha para ser antorcha, la del centro manda.
	{"ancho": 18, "alto": 25, "frames": 8, "fps": 8.0, "ruido": 1.1, "lenguas": [
		{"x": 0.0, "alto": 1.0, "semi": 5.0, "fase": 0.0, "meneo": 1.5, "respira": 0.06, "vueltas": 1},
		{"x": -3.5, "alto": 0.62, "semi": 2.8, "fase": 2.1, "meneo": 1.3, "respira": 0.14, "vueltas": 1},
		{"x": 3.5, "alto": 0.58, "semi": 2.8, "fase": 4.2, "meneo": 1.3, "respira": 0.14, "vueltas": 1},
	]},
	# 5 - BRASERO TRANQUILO: cuatro lenguas anchas y lentas.
	{"ancho": 34, "alto": 30, "frames": 8, "fps": 6.0, "ruido": 1.0, "lenguas": [
		{"x": -6.0, "alto": 0.80, "semi": 6.0, "fase": 0.0, "meneo": 1.6, "respira": 0.10, "vueltas": 1},
		{"x": 1.0, "alto": 1.0, "semi": 7.0, "fase": 1.6, "meneo": 1.8, "respira": 0.07, "vueltas": 1},
		{"x": 7.0, "alto": 0.72, "semi": 5.5, "fase": 3.3, "meneo": 1.6, "respira": 0.12, "vueltas": 1},
		{"x": -1.0, "alto": 0.45, "semi": 10.0, "fase": 4.8, "meneo": 0.6, "respira": 0.05, "vueltas": 1},
	]},
	# 6 - BRASERO VIVO: cinco lenguas que se turnan deprisa.
	{"ancho": 34, "alto": 32, "frames": 8, "fps": 9.0, "ruido": 1.4, "lenguas": [
		{"x": -8.0, "alto": 0.62, "semi": 4.5, "fase": 0.0, "meneo": 1.4, "respira": 0.16, "vueltas": 2},
		{"x": -3.0, "alto": 0.90, "semi": 5.5, "fase": 1.3, "meneo": 1.8, "respira": 0.12, "vueltas": 1},
		{"x": 2.0, "alto": 1.0, "semi": 5.5, "fase": 2.6, "meneo": 2.0, "respira": 0.10, "vueltas": 1},
		{"x": 7.0, "alto": 0.70, "semi": 4.5, "fase": 3.9, "meneo": 1.5, "respira": 0.15, "vueltas": 2},
		{"x": 0.0, "alto": 0.42, "semi": 11.0, "fase": 5.2, "meneo": 0.5, "respira": 0.06, "vueltas": 1},
	]},
	# 7 - BRASERO DE PUNTA: una llama grande en medio y brasas bajas a los lados.
	{"ancho": 34, "alto": 36, "frames": 10, "fps": 7.0, "ruido": 1.1, "lenguas": [
		{"x": 0.0, "alto": 1.0, "semi": 7.5, "fase": 0.0, "meneo": 2.4, "respira": 0.08, "vueltas": 1},
		{"x": -8.0, "alto": 0.40, "semi": 4.5, "fase": 2.0, "meneo": 1.0, "respira": 0.20, "vueltas": 2},
		{"x": 8.0, "alto": 0.44, "semi": 4.5, "fase": 4.1, "meneo": 1.0, "respira": 0.20, "vueltas": 2},
	]},
]

# De dentro afuera: corazon casi blanco, amarillo, naranja y el contorno rojo oscuro.
const BLANCO := Color(1.0, 0.98, 0.80)
const AMARILLO := Color(1.0, 0.84, 0.32)
const NARANJA := Color(0.98, 0.54, 0.14)
const CONTORNO := Color(0.70, 0.20, 0.07)

static var _frames: Dictionary = {}


static func cuantos() -> int:
	return PERFILES.size()


static func fotogramas(perfil: int) -> SpriteFrames:
	if _frames.has(perfil):
		return _frames[perfil]
	var p: Dictionary = PERFILES[perfil]
	var sf := SpriteFrames.new()
	sf.add_animation("arde")
	sf.set_animation_loop("arde", true)
	sf.set_animation_speed("arde", float(p["fps"]))
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for k in int(p["frames"]):
		sf.add_frame("arde", ImageTexture.create_from_image(fotograma(perfil, k)))
	_frames[perfil] = sf
	return sf


static func fotograma(perfil: int, k: int) -> Image:
	var p: Dictionary = PERFILES[perfil]
	var w: int = int(p["ancho"])
	var h: int = int(p["alto"])
	var nf: int = int(p["frames"])
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var mascara := PackedByteArray()
	mascara.resize(w * h)
	var base_y: float = float(h - 1)
	var cx: float = float(w) * 0.5
	var ciclo: float = float(k) / float(nf) * TAU
	for lengua in p["lenguas"]:
		var fase: float = ciclo * float(lengua["vueltas"]) + float(lengua["fase"])
		var resp: float = float(lengua["respira"])
		var alto_l: float = float(h - 2) * float(lengua["alto"]) \
			* (1.0 - resp + resp * sin(fase) + 0.03 * sin(fase * 2.0 + 1.0))
		if alto_l < 3.0:
			continue
		var semi_max: float = float(lengua["semi"])
		var lx: float = cx + float(lengua["x"])
		for y in h:
			# t: 0 en la punta, 1 en la base.
			var t: float = (float(y) + 0.5 - (base_y - alto_l)) / alto_l
			if t < 0.0 or t > 1.0:
				continue
			var semi: float
			if t < 0.70:
				semi = semi_max * pow(t / 0.70, 0.8)
			else:
				var u: float = (t - 0.70) / 0.30
				semi = semi_max * sqrt(maxf(0.0, 1.0 - u * u * 0.85))
			var meneo: float = (sin(fase + t * 3.0) * float(lengua["meneo"])
				+ sin(fase * 2.0 + t * 5.0 + 0.7) * float(lengua["meneo"]) * 0.35) * pow(1.0 - t, 1.6)
			# El borde roto, distinto por perfil y fotograma (ver LlamaAltar). SUAVE entre filas (se
			# interpola cada dos): fila a fila al azar salian pinchos de un pixel, "pelos" y no fuego.
			var ruido: float = (_ruido_suave(float(y) * 0.5, k * 7 + perfil) - 0.5) * 2.0 \
				* float(p["ruido"]) * (1.0 - t * 0.7)
			var lim: float = maxf(0.0, semi + ruido)
			for x in w:
				var dx: float = float(x) + 0.5 - lx - meneo
				if absf(dx) <= lim:
					mascara[y * w + x] = 1
	_quitar_sueltos(mascara, w, h)
	# EL COLOR POR PROFUNDIDAD: cuantas capas hay que pelar desde el borde de la silueta ENTERA hasta
	# llegar a cada pixel. Con el "centro" de cada lengua por separado, un brasero salia a rayas (una
	# columna blanca por lengua); asi el corazon es uno solo y sigue la forma de todo el fuego.
	var prof: PackedByteArray = _profundidad(mascara, w, h)
	var punta: int = h
	for i in w * h:
		if mascara[i] != 0:
			punta = i / w
			break
	var alto_fuego: float = maxf(1.0, float(h - punta))
	var hondo: int = 1
	for i in w * h:
		hondo = maxi(hondo, int(prof[i]))
	for y in h:
		# Arriba, menos calor: las puntas se quedan en naranja/amarillo; la base, algo mas blanca.
		var alto_rel: float = float(y - punta) / alto_fuego      # 0 punta, 1 base
		var calor: float = lerpf(-0.30, 0.10, alto_rel)
		for x in w:
			var i: int = y * w + x
			if mascara[i] == 0:
				continue
			var c: Color = CONTORNO
			if prof[i] > 1:
				# Las bandas van RELATIVAS a lo hondo que es este fuego: una antorcha estrecha (4-5 capas)
				# y un brasero ancho (8) salen con el mismo reparto de naranja, amarillo y blanco.
				var r: float = float(prof[i] - 1) / maxf(1.0, float(hondo - 1)) + calor
				if r >= 0.70:
					c = BLANCO
				elif r >= 0.36:
					c = AMARILLO
				else:
					c = NARANJA
			img.set_pixel(x, y, c)
	return img


static func _ruido_suave(v: float, semilla: int) -> float:
	var i: int = int(floor(v))
	var f: float = v - float(i)
	f = f * f * (3.0 - 2.0 * f)
	return lerpf(PuebloSprites._rnd(i, semilla, 911), PuebloSprites._rnd(i + 1, semilla, 911), f)


# Fuera los pixeles con menos de dos vecinos: son chispas pegadas a la silueta, no llama.
static func _quitar_sueltos(m: PackedByteArray, w: int, h: int) -> void:
	for _pasada in 2:
		var quitar: Array = []
		for y in h:
			for x in w:
				var i: int = y * w + x
				if m[i] == 0:
					continue
				var n: int = 0
				if x > 0 and m[i - 1] != 0: n += 1
				if x < w - 1 and m[i + 1] != 0: n += 1
				if y > 0 and m[i - w] != 0: n += 1
				if y < h - 1 and m[i + w] != 0: n += 1
				if n < 2:
					quitar.append(i)
		for i in quitar:
			m[i] = 0


# 1 = borde, 2 = la capa de dentro, ... (hasta HONDO_MAX), pelando en cruz.
const HONDO_MAX := 10

static func _profundidad(m: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var prof := PackedByteArray()
	prof.resize(w * h)
	for i in w * h:
		prof[i] = HONDO_MAX if m[i] != 0 else 0
	for capa in range(1, HONDO_MAX):
		var marcar: Array = []
		for y in h:
			for x in w:
				var i: int = y * w + x
				if prof[i] != HONDO_MAX:
					continue
				var fuera: bool = x == 0 or x == w - 1 or y == 0 or y == h - 1 \
					or prof[i - 1] < capa or prof[i + 1] < capa or prof[i - w] < capa or prof[i + w] < capa
				if fuera:
					marcar.append(i)
		for i in marcar:
			prof[i] = capa
	return prof
