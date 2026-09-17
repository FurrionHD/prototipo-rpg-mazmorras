# ============================================================
#  casa_sprites.gd  (class_name CasaSprites)
#  LAS CASAS DEL PUEBLO, dibujadas por codigo. Cada oficio tiene la suya y tiene que reconocerse de un
#  vistazo (lo pidio el usuario): no es la misma casa con otro color, cada una lleva sus MATERIALES,
#  su TEJADO, su CARTEL con el simbolo del oficio y un DETALLE de fuera (el yunque de la herreria, los
#  troncos de la carpinteria, las pieles tendidas de la peleteria...).
#
#  LA GEOMETRIA ES LA MISMA PARA TODAS, y sale de la camara del juego (suelo en planta, altura hacia
#  arriba en pantalla). Una casa de huella W x D px con paredes de altura A se ve asi, de abajo arriba:
#    - la PARED DELANTERA: un rectangulo de A px apoyado en el borde sur de la huella;
#    - el TEJADO: la huella entera subida A px. Con la cumbrera de este a oeste, se ve la vertiente
#      que mira al sur (la grande, iluminada) y un poco de la de atras (estrecha y en sombra).
#  No se ven las paredes de los lados: la camara mira de frente desde el sur.
#
#  El lienzo mide W x (D + A + ARRIBA). 'pie' = D: la huella. Lo que queda por encima (el tejado que
#  sobresale y la chimenea) es lo que tapa a quien pasa por detras (ver PiezaPueblo).
#
#  Todo lo que se cuelga de la casa (cartel, pieles, redes, toldo, barriles) va PEGADO A LA PARED, o
#  sea dentro de la huella: si saliera fuera, se podria pisar por encima.
# ============================================================

extends RefCounted
class_name CasaSprites

const CELDA := 32
const ARRIBA := 26          # margen por encima del tejado para chimeneas y humo
const NEGRO := Color(0.07, 0.05, 0.05)

# ------------------------------------------------------------
#  MATERIALES (rampas de oscuro a claro)
# ------------------------------------------------------------
const RAMPAS := {
	"piedra": [Color(0.27, 0.25, 0.24), Color(0.42, 0.40, 0.37), Color(0.53, 0.51, 0.47), Color(0.63, 0.61, 0.56), Color(0.74, 0.72, 0.66)],
	"piedra_osc": [Color(0.16, 0.15, 0.17), Color(0.26, 0.25, 0.28), Color(0.34, 0.33, 0.36), Color(0.42, 0.41, 0.44), Color(0.52, 0.51, 0.54)],
	"piedra_clara": [Color(0.44, 0.42, 0.40), Color(0.60, 0.58, 0.54), Color(0.70, 0.68, 0.63), Color(0.80, 0.78, 0.72), Color(0.89, 0.87, 0.81)],
	"madera": [Color(0.27, 0.17, 0.10), Color(0.40, 0.27, 0.16), Color(0.50, 0.35, 0.21), Color(0.60, 0.44, 0.28), Color(0.70, 0.54, 0.36)],
	"madera_clara": [Color(0.42, 0.30, 0.18), Color(0.58, 0.43, 0.27), Color(0.68, 0.53, 0.35), Color(0.77, 0.62, 0.43), Color(0.85, 0.72, 0.52)],
	"madera_osc": [Color(0.16, 0.10, 0.07), Color(0.25, 0.16, 0.11), Color(0.33, 0.22, 0.15), Color(0.41, 0.29, 0.20), Color(0.50, 0.37, 0.26)],
	"madera_azul": [Color(0.16, 0.22, 0.28), Color(0.24, 0.33, 0.40), Color(0.32, 0.43, 0.50), Color(0.42, 0.53, 0.59), Color(0.54, 0.64, 0.68)],
	"enlucido": [Color(0.62, 0.56, 0.46), Color(0.74, 0.68, 0.57), Color(0.82, 0.77, 0.66), Color(0.88, 0.84, 0.74), Color(0.93, 0.90, 0.81)],
	"enlucido_ocre": [Color(0.56, 0.44, 0.28), Color(0.68, 0.55, 0.36), Color(0.77, 0.64, 0.43), Color(0.84, 0.72, 0.50), Color(0.90, 0.80, 0.59)],
	"teja": [Color(0.36, 0.14, 0.09), Color(0.52, 0.22, 0.13), Color(0.64, 0.30, 0.17), Color(0.74, 0.39, 0.23), Color(0.83, 0.50, 0.31)],
	"teja_verde": [Color(0.12, 0.24, 0.18), Color(0.18, 0.34, 0.24), Color(0.25, 0.44, 0.30), Color(0.33, 0.53, 0.36), Color(0.44, 0.63, 0.44)],
	"teja_osc": [Color(0.24, 0.10, 0.10), Color(0.35, 0.15, 0.14), Color(0.45, 0.20, 0.18), Color(0.54, 0.26, 0.22), Color(0.63, 0.33, 0.27)],
	"pizarra": [Color(0.13, 0.15, 0.20), Color(0.21, 0.24, 0.31), Color(0.29, 0.32, 0.40), Color(0.37, 0.41, 0.49), Color(0.47, 0.51, 0.59)],
	"pizarra_azul": [Color(0.10, 0.16, 0.28), Color(0.16, 0.24, 0.40), Color(0.22, 0.32, 0.50), Color(0.30, 0.41, 0.59), Color(0.40, 0.51, 0.68)],
	"paja": [Color(0.40, 0.30, 0.13), Color(0.55, 0.43, 0.20), Color(0.67, 0.54, 0.27), Color(0.77, 0.65, 0.35), Color(0.87, 0.76, 0.45)],
	"tablilla": [Color(0.22, 0.15, 0.10), Color(0.33, 0.23, 0.15), Color(0.43, 0.31, 0.20), Color(0.52, 0.39, 0.26), Color(0.61, 0.48, 0.33)],
}

# ------------------------------------------------------------
#  LAS CASAS
#  huella    = casillas (tiene que coincidir con PuebloPlano.CASAS: lo comprueba el visor)
#  pared     = material (y "entramado": enlucido con vigas de madera oscura)
#  tejado    = material del tejado
#  alto      = px de pared
#  chimeneas = x (px) de cada chimenea; "fragua" enciende la boca
#  cartel    = simbolo del oficio (ver ICONOS); "" = sin cartel
#  luz       = ventanas encendidas
#  extras    = los detalles COLGADOS de la pared (ver _extra). Lo que se apoya en el SUELO (yunque,
#              troncos, barriles, cajas, sacos) NO va aqui: es una pieza aparte con su casilla, su
#              volumen y su sombra (PuebloPlano.ADORNOS). Pintado en la pared se leia como una pegatina
#              ("parece un png encima de la pared", dijo el usuario).
# ------------------------------------------------------------
const CASAS := {
	"herreria": {"huella": Vector2i(4, 3), "pared": "piedra_osc", "tejado": "pizarra", "alto": 44,
		"chimeneas": [20], "fragua": true, "cartel": "martillo", "luz": "fragua",
		"extras": []},
	"carpinteria": {"huella": Vector2i(4, 3), "pared": "madera_clara", "tejado": "tablilla", "alto": 44,
		"chimeneas": [], "cartel": "serrucho", "luz": "",
		"extras": []},
	"peleteria": {"huella": Vector2i(4, 3), "pared": "madera_osc", "tejado": "paja", "alto": 42,
		"chimeneas": [], "cartel": "piel", "luz": "",
		"extras": []},
	"boticaria": {"huella": Vector2i(4, 3), "pared": "entramado", "tejado": "teja_verde", "alto": 44,
		"chimeneas": [104], "cartel": "frasco", "luz": "verde",
		"extras": ["macetas", "hierbas"]},
	"cocina": {"huella": Vector2i(4, 3), "pared": "enlucido_ocre", "tejado": "teja", "alto": 44,
		"chimeneas": [22], "humo": true, "cartel": "olla", "luz": "calida",
		"extras": ["ristras"]},
	"tienda": {"huella": Vector2i(5, 4), "pared": "entramado", "tejado": "teja", "alto": 48,
		"chimeneas": [], "cartel": "bolsa", "luz": "calida",
		"extras": ["toldo"]},
	"taberna": {"huella": Vector2i(5, 4), "pared": "taberna", "tejado": "teja_osc", "alto": 66,
		"chimeneas": [26, 136], "humo": true, "cartel": "jarra", "luz": "calida",
		"extras": []},
	"maestro": {"huella": Vector2i(3, 3), "pared": "piedra_clara", "tejado": "pizarra_azul", "alto": 46,
		"chimeneas": [], "cartel": "espadas", "luz": "",
		"extras": ["estandarte"]},
	"pescador": {"huella": Vector2i(3, 3), "pared": "madera_azul", "tejado": "tablilla", "alto": 40,
		"chimeneas": [], "cartel": "pez", "luz": "",
		"extras": ["redes"]},
	"hogar": {"huella": Vector2i(5, 4), "pared": "entramado", "tejado": "teja", "alto": 50,
		"chimeneas": [30, 130], "humo": true, "cartel": "", "luz": "calida",
		"extras": ["macetas", "farol"]},
	"vacia_0": {"huella": Vector2i(3, 3), "pared": "enlucido", "tejado": "teja", "alto": 40,
		"chimeneas": [74], "cartel": "", "luz": "", "extras": ["postigos"]},
	"vacia_1": {"huella": Vector2i(3, 3), "pared": "madera", "tejado": "paja", "alto": 38,
		"chimeneas": [], "cartel": "", "luz": "", "extras": ["postigos"]},
	"vacia_2": {"huella": Vector2i(3, 3), "pared": "piedra", "tejado": "pizarra", "alto": 40,
		"chimeneas": [22], "cartel": "", "luz": "", "extras": ["postigos"]},
}

const VARIANTES_VACIA := 3


static func tam(clave: String) -> Vector2i:
	var e: Dictionary = CASAS[clave]
	var hu: Vector2i = e["huella"]
	return Vector2i(hu.x * CELDA, hu.y * CELDA + int(e["alto"]) + ARRIBA)


static func pie(clave: String) -> int:
	return (CASAS[clave]["huella"] as Vector2i).y * CELDA


# ============================================================
#  PIXELES
# ============================================================
static func _px(d: PackedByteArray, w: int, h: int, x: int, y: int, c: Color) -> void:
	PuebloSprites._px(d, w, h, x, y, c)


static func _rnd(x: int, y: int, s: int) -> float:
	return PuebloSprites._rnd(x, y, s)


static func _esc(v: float, r: Array) -> Color:
	return r[clampi(int(v * float(r.size())), 0, r.size() - 1)]


static func _rect(d: PackedByteArray, w: int, h: int, x0: int, y0: int, rw: int, rh: int, c: Color) -> void:
	for y in range(y0, y0 + rh):
		for x in range(x0, x0 + rw):
			_px(d, w, h, x, y, c)


# LA SOMBRA DE LO COLGADO: lo mismo desplazado abajo a la derecha, oscureciendo la pared. Es lo que
# despega el cartel o la piel de la pared; sin ella parecen pintados encima.
static func _sombra(d: PackedByteArray, w: int, h: int, x0: int, y0: int, rw: int, rh: int) -> void:
	_rect(d, w, h, x0 + 2, y0 + 2, rw, rh, Color(0, 0, 0, 0.32))


static func _marco(d: PackedByteArray, w: int, h: int, x0: int, y0: int, rw: int, rh: int, c: Color) -> void:
	for x in range(x0, x0 + rw):
		_px(d, w, h, x, y0, c)
		_px(d, w, h, x, y0 + rh - 1, c)
	for y in range(y0, y0 + rh):
		_px(d, w, h, x0, y, c)
		_px(d, w, h, x0 + rw - 1, y, c)


# ============================================================
#  LA CASA
# ============================================================
static func generar(clave: String) -> Image:
	var e: Dictionary = CASAS[clave]
	var t: Vector2i = tam(clave)
	var w: int = t.x
	var h: int = t.y
	var d := PackedByteArray()
	d.resize(w * h * 4)
	var hu: Vector2i = e["huella"]
	var fondo: int = hu.y * CELDA
	var alto: int = int(e["alto"])
	var alero: int = h - alto               # y del alero delantero = lo alto de la pared
	var puerta_x: int = (hu.x / 2) * CELDA + CELDA / 2
	var sem: int = hash(clave)

	_pared(d, w, h, e, alero, sem)
	_ventanas(d, w, h, e, alero, puerta_x, hu)
	_puerta(d, w, h, e, puerta_x, hu)
	for ex in e["extras"]:
		_extra(d, w, h, String(ex), e, alero, puerta_x, hu)
	_tejado(d, w, h, e, alero, fondo, sem)
	for cx in e["chimeneas"]:
		_chimenea(d, w, h, int(cx), alero, fondo, bool(e.get("fragua", false)), bool(e.get("humo", false)))
	# El CARTEL ya no va aqui: es una pieza aparte que SOBRESALE por el lado de la fachada (ver cartel()),
	# y dentro de este lienzo no cabe nada que salga de la huella.
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, d)


# ------------------------------------------------------------
#  PARED
# ------------------------------------------------------------
const MARGEN := 2           # la pared va 2 px mas estrecha que el tejado: asi el alero vuela un poco

static func _pared(d: PackedByteArray, w: int, h: int, e: Dictionary, alero: int, sem: int) -> void:
	var mat: String = e["pared"]
	for y in range(alero, h):
		var yr: int = y - alero
		for x in range(MARGEN, w - MARGEN):
			var col: Color
			match mat:
				"entramado":
					col = _entramado(x, yr, w, h - alero, "enlucido", sem)
				"taberna":
					# Planta baja de piedra y alta de entramado: la casa mas grande del pueblo.
					col = _sillares(x, yr, RAMPAS["piedra"], sem) if yr >= (h - alero) / 2 \
						else _entramado(x, yr, w, (h - alero) / 2, "enlucido_ocre", sem)
				"madera", "madera_clara", "madera_osc":
					col = _tablones_h(x, yr, RAMPAS[mat], sem)
				"madera_azul":
					col = _tablones_v(x, yr, RAMPAS[mat], sem)
				"enlucido", "enlucido_ocre":
					col = _enlucido(x, yr, RAMPAS[mat], sem)
				_:
					col = _sillares(x, yr, RAMPAS[mat], sem)
			# El pie de la pared: un zocalo de piedra en las que no son de piedra.
			if yr >= h - alero - 5 and not mat.begins_with("piedra") and mat != "taberna":
				col = _sillares(x, yr, RAMPAS["piedra"], sem + 5)
			# La sombra del alero sobre lo alto de la pared.
			if yr < 5:
				col = col.darkened(0.35 * (1.0 - float(yr) / 5.0))
			if x == MARGEN or x == w - MARGEN - 1 or y == h - 1:
				col = NEGRO
			_px(d, w, h, x, y, col)


static func _sillares(x: int, y: int, r: Array, sem: int) -> Color:
	var hil: int = y / 8
	var off: int = (hil % 2) * 9
	var sx: int = (x + off) % 18
	if y % 8 == 0 or sx == 0:
		return r[0]
	var v: float = 0.35 + _rnd((x + off) / 18, hil, sem) * 0.45 + (_rnd(x, y, sem + 1) - 0.5) * 0.08
	if y % 8 == 1:
		v += 0.12
	return _esc(v, r)


static func _tablones_h(x: int, y: int, r: Array, sem: int) -> Color:
	var fila: int = y / 6
	if y % 6 == 0:
		return r[0]
	var corte: int = (x + fila * 13) % 44
	if corte == 0:
		return r[0]
	var v: float = 0.35 + _rnd((x + fila * 13) / 44, fila, sem) * 0.35 + (_rnd(x / 3, y, sem + 2) - 0.5) * 0.12
	if y % 6 == 1:
		v += 0.1
	return _esc(v, r)


static func _tablones_v(x: int, y: int, r: Array, sem: int) -> Color:
	if x % 7 == 0:
		return r[0]
	var v: float = 0.35 + _rnd(x / 7, 0, sem) * 0.35 + (_rnd(x, y / 3, sem + 3) - 0.5) * 0.12
	if x % 7 == 1:
		v += 0.12
	return _esc(v, r)


static func _enlucido(x: int, y: int, r: Array, sem: int) -> Color:
	var v: float = 0.55 + (_rnd(x / 2, y / 2, sem) - 0.5) * 0.20
	if _rnd(x, y, sem + 7) > 0.97:
		v -= 0.25                                     # desconchon
	return _esc(v, r)


# ENTRAMADO: enlucido entre vigas de madera oscura. Postes en los cantos y cada ~40 px, una viga
# arriba y otra abajo, y tornapuntas en diagonal en los paños de los extremos.
static func _entramado(x: int, y: int, w: int, alto: int, relleno: String, sem: int) -> Color:
	var mad: Array = RAMPAS["madera_osc"]
	var poste: bool = x < MARGEN + 4 or x >= w - MARGEN - 4 or absi(((x - MARGEN) % 40) - 20) > 18
	var viga: bool = y < 4 or (y >= alto - 9 and y < alto - 5)
	var diag: bool = false
	if x < 40 and y > 4 and y < alto - 9:
		diag = absi((x - MARGEN - 4) - (y - 4)) < 2
	elif x > w - 40 and y > 4 and y < alto - 9:
		diag = absi((w - MARGEN - 5 - x) - (y - 4)) < 2
	if poste or viga or diag:
		var v: float = 0.45 + (_rnd(x / 2, y, sem + 11) - 0.5) * 0.25
		return _esc(v, mad)
	return _enlucido(x, y, RAMPAS[relleno], sem)


# ------------------------------------------------------------
#  VENTANAS Y PUERTA
# ------------------------------------------------------------
static func _ventanas(d: PackedByteArray, w: int, h: int, e: Dictionary, alero: int, puerta_x: int, hu: Vector2i) -> void:
	for esq in _esquinas_ventanas(e, h, alero, puerta_x, hu):
		_ventana(d, w, h, (esq as Vector2i).x, (esq as Vector2i).y, String(e["luz"]), "postigos" in e["extras"])


# La esquina de arriba a la izquierda de cada ventana (14 x 14 px) en el lienzo de la casa. Sale en su
# funcion porque la usan dos: el dibujo y las ventanas que se encienden de noche (ver ventanas()).
static func _esquinas_ventanas(e: Dictionary, h: int, alero: int, puerta_x: int, hu: Vector2i) -> Array:
	var alto: int = h - alero
	var filas: Array = [alero + 10]
	if String(e["pared"]) == "taberna":
		filas = [alero + 8, alero + alto / 2 + 8]
	var cols: Array = []
	for c in hu.x:
		var cx: int = c * CELDA + CELDA / 2
		if absi(cx - puerta_x) < CELDA:
			continue
		# En las de 5 de ancho solo los extremos (y en la taberna todas, arriba).
		if hu.x >= 5 and c != 0 and c != hu.x - 1 and String(e["pared"]) != "taberna":
			continue
		cols.append(cx)
	var out: Array = []
	for fi in filas.size():
		var y0: int = int(filas[fi])
		var xs: Array = cols
		if String(e["pared"]) == "taberna" and fi == 0:
			xs = []
			for c in hu.x:
				xs.append(c * CELDA + CELDA / 2)
		for cx in xs:
			out.append(Vector2i(int(cx) - 7, y0))
	return out


# ------------------------------------------------------------
#  LAS VENTANAS DE NOCHE (ver LuzPueblo). Encima de cada ventana se pone su VIDRIO ENCENDIDO, que aparece
#  al anochecer. Los oficios sin luz de dia (carpinteria, peleteria...) de noche SI la encienden, calida:
#  hay alguien dentro. Las casas vacias no: estan vacias.
# ------------------------------------------------------------
const TAM_VENTANA := 14

# [[esquina Vector2i en el lienzo, luz de noche String], ...]
static func ventanas(clave: String) -> Array:
	var e: Dictionary = CASAS[clave]
	if clave.begins_with("vacia"):
		return []
	var h: int = tam(clave).y
	var hu: Vector2i = e["huella"]
	var alero: int = h - int(e["alto"])
	var puerta_x: int = (hu.x / 2) * CELDA + CELDA / 2
	var luz: String = String(e["luz"])
	if luz == "":
		luz = "calida"
	var out: Array = []
	for esq in _esquinas_ventanas(e, h, alero, puerta_x, hu):
		out.append([esq, luz])
	return out


# El color de la luz que sale por cada tipo de ventana (lo que usa el shader para su corro).
static func color_luz(luz: String) -> Color:
	match luz:
		"fragua":
			return Color(1.0, 0.72, 0.45)
		"verde":
			return Color(0.80, 1.0, 0.78)
	return Color(1.0, 0.88, 0.62)


# El vidrio encendido de UNA ventana de UNA casa: solo los pixeles que en el dibujo de la casa siguen
# siendo vidrio. Lo que tapa la ventana (el cartel colgado encima, el toldo) se queda transparente y se
# ve por encima: con el vidrio entero, la luz cortaba los carteles por la mitad (lo vio el usuario).
# 'casa' = la imagen de la casa tal cual se pinta (la horneada si la hay).
static func textura_vidrio(clave: String, esq: Vector2i, luz_noche: String, casa: Image) -> ImageTexture:
	var base: Image = _vidrio_entero(luz_noche)
	var dia: Array = _vidrio_de_dia(String(CASAS[clave]["luz"]))
	var img := Image.create(TAM_VENTANA, TAM_VENTANA, false, Image.FORMAT_RGBA8)
	for y in TAM_VENTANA:
		for x in TAM_VENTANA:
			var c: Color = base.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var cx: int = esq.x + x
			var cy: int = esq.y + y
			if cx < 0 or cy < 0 or cx >= casa.get_width() or cy >= casa.get_height():
				continue
			var en_casa: Color = casa.get_pixel(cx, cy)
			var es_vidrio: bool = false
			for t in dia:
				if _parecido(en_casa, t):
					es_vidrio = true
			# El parteluz se queda si en la casa tambien esta (si no, es que lo tapa algo).
			if not es_vidrio and _parecido(en_casa, c):
				es_vidrio = true
			if es_vidrio:
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func _parecido(a: Color, b: Color) -> bool:
	return a.a > 0.9 and absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 and absf(a.b - b.b) < 0.02


static var _vidrios: Dictionary = {}

# El vidrio encendido de una ventana sin tapar: el hueco SIN el marco (transparente), con el parteluz y
# el vidrio mas claro que de dia, casi blanco en la esquina de arriba.
static func _vidrio_entero(luz: String) -> Image:
	if _vidrios.has(luz):
		return _vidrios[luz]
	var a := Color(1.0, 0.78, 0.36)
	var b := Color(1.0, 0.95, 0.70)
	match luz:
		"fragua":
			a = Color(1.0, 0.45, 0.12)
			b = Color(1.0, 0.80, 0.40)
		"verde":
			a = Color(0.50, 0.85, 0.50)
			b = Color(0.85, 1.0, 0.78)
	var img := Image.create(TAM_VENTANA, TAM_VENTANA, false, Image.FORMAT_RGBA8)
	var mad: Array = RAMPAS["madera_osc"]
	for y in TAM_VENTANA:
		for x in TAM_VENTANA:
			if x == 0 or y == 0 or x == TAM_VENTANA - 1 or y == TAM_VENTANA - 1:
				continue
			var col: Color = a if (x + y) > 13 else b
			if x == 7 or y == 7:
				col = mad[2]
			img.set_pixel(x, y, col)
	_vidrios[luz] = img
	return img


# Los dos tonos del vidrio DE DIA segun la luz de la casa. En su funcion porque el vidrio de noche
# los busca en el dibujo para saber que pixeles de la ventana siguen a la vista.
static func _vidrio_de_dia(luz: String) -> Array:
	match luz:
		"calida":
			return [Color(0.85, 0.60, 0.25), Color(1.00, 0.86, 0.50)]
		"fragua":
			return [Color(0.80, 0.30, 0.08), Color(1.00, 0.65, 0.20)]
		"verde":
			return [Color(0.35, 0.60, 0.40), Color(0.65, 0.88, 0.60)]
	return [Color(0.16, 0.22, 0.30), Color(0.30, 0.42, 0.52)]


static func _ventana(d: PackedByteArray, w: int, h: int, x0: int, y0: int, luz: String, postigos: bool) -> void:
	var tonos: Array = _vidrio_de_dia(luz)
	var vidrio_a: Color = tonos[0]
	var vidrio_b: Color = tonos[1]
	var mad: Array = RAMPAS["madera_osc"]
	for y in 14:
		for x in 14:
			var col: Color = vidrio_a if (x + y) > 13 else vidrio_b
			if x == 0 or y == 0 or x == 13 or y == 13:
				col = mad[1]
			elif x == 7 or y == 7:
				col = mad[2]                        # el parteluz
			_px(d, w, h, x0 + x, y0 + y, col)
	# Alfeizar.
	_rect(d, w, h, x0 - 1, y0 + 14, 16, 2, RAMPAS["piedra_clara"][2])
	_rect(d, w, h, x0 - 1, y0 + 16, 16, 1, NEGRO)
	if postigos:
		for lado in [-6, 14]:
			for y in 14:
				for x in 6:
					var col: Color = mad[2] if y % 3 != 0 else mad[1]
					if x == 0 or x == 5:
						col = NEGRO
					_px(d, w, h, x0 + lado + x, y0 + y, col)


static func _puerta(d: PackedByteArray, w: int, h: int, e: Dictionary, puerta_x: int, hu: Vector2i) -> void:
	var ancho: int = 20 if hu.x >= 5 else 16
	var alto: int = 28 if int(e["alto"]) >= 44 else 25
	var x0: int = puerta_x - ancho / 2
	var y0: int = h - 1 - alto
	var mad: Array = RAMPAS["madera"]
	var mco: Array = RAMPAS["madera_osc"]
	for y in alto:
		for x in range(-2, ancho + 2):
			var col: Color
			# Arco de medio punto arriba.
			var dx: float = float(x) + 0.5 - float(ancho) * 0.5
			var r: float = float(ancho) * 0.5 + 2.0
			if y < int(r) and dx * dx + pow(r - float(y), 2.0) > r * r:
				continue
			if x < 0 or x >= ancho or (y < int(r) and dx * dx + pow(r - float(y), 2.0) > pow(r - 2.0, 2.0)):
				col = mco[1]                            # el marco
			else:
				col = mad[1] if x % 5 == 0 else mad[2 + int(_rnd(x / 5, 0, 91) * 2.0)]
				if ancho >= 20 and x == ancho / 2:
					col = mco[0]                        # puerta de dos hojas
				if y == alto / 2 and x % 5 != 0:
					col = mco[2]                        # herraje
			_px(d, w, h, x0 + x, y0 + y, col)
	# Picaporte.
	_px(d, w, h, x0 + ancho - 4, y0 + alto / 2 + 3, Color(0.85, 0.72, 0.30))
	# Escalon.
	_rect(d, w, h, x0 - 3, h - 2, ancho + 6, 2, RAMPAS["piedra"][3])


# ------------------------------------------------------------
#  TEJADO
# ------------------------------------------------------------
# La huella entera subida 'alto' px. De 'alero' hacia arriba 'fondo' px: la vertiente delantera (la
# grande) hasta la cumbrera, y la trasera (en sombra y apretada) desde ahi hasta el alero de atras.
const VERTIENTE_ATRAS := 22

static func _tejado(d: PackedByteArray, w: int, h: int, e: Dictionary, alero: int, fondo: int, sem: int) -> void:
	var r: Array = RAMPAS[e["tejado"]]
	var mat: String = e["tejado"]
	var cumbre: int = alero - fondo + VERTIENTE_ATRAS
	var arriba: int = alero - fondo
	for y in range(arriba, alero + 3):
		for x in w:
			var col: Color
			if y < cumbre:
				# Trasera: el mismo material, filas mas apretadas y mas oscuro.
				col = _material_tejado(mat, x, (y - arriba) * 2, r, sem).darkened(0.30)
			else:
				col = _material_tejado(mat, x, y - cumbre, r, sem)
				# LA LUZ DE LA VERTIENTE: clara junto a la cumbrera y apagandose hacia el alero. Con las
				# filas iguales de arriba abajo el tejado se leia como una pared plana (visto en la hoja).
				var t: float = float(y - cumbre) / float(maxi(1, alero - cumbre))
				if t < 0.45:
					col = col.lightened(0.14 * (1.0 - t / 0.45))
				elif t > 0.70:
					col = col.darkened(0.28 * (t - 0.70) / 0.30)
			if y >= cumbre - 1 and y <= cumbre + 1:
				col = r[4] if y == cumbre else r[1]      # la cumbrera
			if x == 0 or x == w - 1 or y == arriba or y == alero + 2:
				col = NEGRO
			_px(d, w, h, x, y, col)
	# La sombra que el alero echa sobre la pared (unos px mas abajo del borde).
	for x in range(MARGEN, w - MARGEN):
		_px(d, w, h, x, alero + 3, Color(0, 0, 0, 0.35))


static func _material_tejado(mat: String, x: int, y: int, r: Array, sem: int) -> Color:
	match mat:
		"teja", "teja_verde", "teja_osc":
			# Tejas curvas: filas de 7 px, cada teja de 10 con la punta redondeada.
			var fila: int = y / 7
			var u: int = (x + (fila % 2) * 5) % 10
			var yl: int = y % 7
			if yl == 6:
				return r[0]
			if yl >= 4 and (u == 0 or u == 9):
				return r[1]
			var v: float = 0.75 - float(yl) * 0.07 + (_rnd((x + (fila % 2) * 5) / 10, fila, sem) - 0.5) * 0.18
			if u == 1:
				v += 0.12
			return _esc(v, r)
		"pizarra", "pizarra_azul":
			var fila: int = y / 6
			var u: int = (x + (fila % 2) * 4) % 8
			if y % 6 == 5 or u == 0:
				return r[0]
			return _esc(0.40 + _rnd((x + (fila % 2) * 4) / 8, fila, sem) * 0.40 - float(y % 6) * 0.03, r)
		"paja":
			# Haces verticales de paja, con una banda en cada hilada.
			var v: float = 0.50 + (_rnd(x, y / 4, sem) - 0.5) * 0.40
			if y % 11 >= 9:
				v -= 0.25
			if x % 3 == 0:
				v -= 0.10
			return _esc(v, r)
		_:
			# Tablillas de madera.
			var fila: int = y / 6
			var u: int = (x + (fila % 2) * 4 + fila * 3) % 7
			if y % 6 == 5 or u == 0:
				return r[0]
			return _esc(0.45 + _rnd((x + (fila % 2) * 4 + fila * 3) / 7, fila, sem) * 0.35, r)


# Las BOCAS DE LAS CHIMENEAS que echan humo, en px del lienzo de la casa, con si es de fragua (humo
# mas oscuro). Salen de las mismas cuentas que _chimenea: si se mueve una, se mueve la otra.
static func bocas_humo(clave: String) -> Array:
	var e: Dictionary = CASAS[clave]
	var fragua: bool = bool(e.get("fragua", false))
	if not fragua and not bool(e.get("humo", false)):
		return []
	var t: Vector2i = tam(clave)
	var fondo: int = (e["huella"] as Vector2i).y * CELDA
	var alero: int = t.y - int(e["alto"])
	var out: Array = []
	for cx in e["chimeneas"]:
		out.append([Vector2(float(cx), float(alero - fondo - 8 - 3)), fragua])
	return out


static func _chimenea(d: PackedByteArray, w: int, h: int, cx: int, alero: int, fondo: int, fragua: bool, humo: bool) -> void:
	var r: Array = RAMPAS["piedra_osc"] if fragua else RAMPAS["piedra"]
	var ancho: int = 14 if fragua else 11
	var base: int = alero - fondo + VERTIENTE_ATRAS + 14
	var tope: int = alero - fondo - 8
	for y in range(tope, base):
		for x in ancho:
			var col: Color = _sillares(x + cx, y + 3, r, 71)
			if x == 0 or x == ancho - 1:
				col = NEGRO
			_px(d, w, h, cx - ancho / 2 + x, y, col)
	# Remate y boca.
	_rect(d, w, h, cx - ancho / 2 - 1, tope - 3, ancho + 2, 3, r[3])
	_marco(d, w, h, cx - ancho / 2 - 1, tope - 3, ancho + 2, 3, NEGRO)
	if fragua:
		_rect(d, w, h, cx - ancho / 2 + 2, tope - 3, ancho - 4, 2, Color(1.0, 0.55, 0.15))
		_rect(d, w, h, cx - ancho / 2 + 4, tope - 3, ancho - 8, 1, Color(1.0, 0.90, 0.55))
	# El HUMO ya no se pinta aqui: eran tres bocanadas quietas. Ahora sube de verdad, con particulas
	# que pone el pueblo en la boca de cada chimenea (ver bocas_humo y HumoChimenea).


# ------------------------------------------------------------
#  EL CARTEL: una tabla GRANDE colgada de un brazo de hierro que SOBRESALE por un lado de la fachada,
#  como los de las calles de verdad. Sustituye al rotulo de texto de debajo de la puerta (lo pidio el
#  usuario: "que sobresalgan por los lados y se vea en grande"). Antes era una tablilla de 16x12 pintada
#  dentro de la pared y no se leia.
#
#  Es una imagen APARTE y no parte del lienzo de la casa: lo que sale de la huella no cabe ahi. La pone
#  el pueblo (town.gd) con posicion_cartel(), y se ordena como la PARED de la que cuelga (ver
#  PiezaPueblo.colgar): la farola o quien pase por delante lo tapan.
#
#  Los simbolos van en 12x10 y se pintan a DOBLE tamaño (a triple quedaba demasiado grande al lado de la casa): a la escala de antes (8x6 a 1x) no se
#  distinguia un martillo de una jarra.
# ------------------------------------------------------------
const ICONOS := {
	"martillo": [".#########..", ".##########.", ".#########..", ".....##.....", ".....##.....",
		".....##.....", ".....##.....", ".....##.....", "....####....", "....####...."],
	"serrucho": ["............", "##..........", "###.........", "###########.", "############",
		"############", ".#.#.#.#.#.#", "............", "............", "............"],
	"piel": ["#..........#", ".##########.", ".##########.", "..########..", "..########..",
		"..########..", "..########..", ".##########.", ".##########.", "#..........#"],
	"frasco": ["....####....", ".....##.....", ".....##.....", "....####....", "...######...",
		"..########..", ".##########.", ".##########.", ".##########.", "..########.."],
	"olla": [".....##.....", "..########..", "############", ".##########.", ".##########.",
		".##########.", ".##########.", "..########..", "...######...", "............"],
	"bolsa": ["...##..##...", "....####....", ".....##.....", "...######...", "..########..",
		".##########.", ".##########.", ".##########.", ".##########.", "..########.."],
	"jarra": [".########...", ".########...", ".########.##", ".########..#", ".########..#",
		".########..#", ".########.##", ".########...", ".########...", "..######...."],
	"espadas": ["#..........#", ".#........#.", "..#......#..", "...#....#...", "....#..#....",
		".....##.....", "....#..#....", "..##....##..", ".##......##.", "#..........#"],
	"pez": ["............", ".....####...", "...#######.#", "..########.#", ".##########.",
		"..########.#", "...#######.#", ".....####...", "............", "............"],
}

const CARTEL_TAM := Vector2i(46, 36)   # el lienzo entero: brazo + tabla
const TABLA_TAM := Vector2i(34, 28)
const TABLA_X := 10                    # donde empieza la tabla, contado desde la pared
const TABLA_Y := 7
const ESCALA_ICONO := 2
# Negativo: el brazo sale justo bajo el tejado, y asi la tabla no llega al suelo en las casas bajas
# (las de 40 px de pared).
const CARTEL_BAJO_ALERO := -4          # px por debajo de lo alto de la pared donde va el brazo

# El dibujo con la pared a la IZQUIERDA (x = 0) si 'a_la_izq' es false, o a la derecha si es true: el
# brazo sale siempre de la pared hacia fuera. El simbolo NO se refleja (una jarra con el asa al reves
# se lee rara); solo se recoloca la tabla.
static func cartel(icono: String, a_la_izq: bool) -> Image:
	var w: int = CARTEL_TAM.x
	var h: int = CARTEL_TAM.y
	var d := PackedByteArray()
	d.resize(w * h * 4)
	var hierro := Color(0.13, 0.12, 0.13)
	var hierro_luz := Color(0.32, 0.30, 0.31)
	var px := func(x: int, y: int, c: Color) -> void:
		_px(d, w, h, (w - 1 - x) if a_la_izq else x, y, c)
	# La placa clavada a la pared.
	for y in range(0, 12):
		for x in range(0, 3):
			px.call(x, y, hierro if x != 1 or y % 5 != 2 else hierro_luz)
	# El brazo, con su brillo arriba y un remate enroscado en la punta.
	for x in range(0, w - 1):
		px.call(x, 2, hierro_luz)
		px.call(x, 3, hierro)
	px.call(w - 2, 1, hierro)
	px.call(w - 1, 1, hierro)
	px.call(w - 1, 2, hierro)
	# La escuadra de refuerzo, en diagonal de la placa al brazo.
	for i in 8:
		px.call(2 + i, 11 - i, hierro)
		px.call(3 + i, 11 - i, hierro)
	# Las dos cadenas (eslabones alternos).
	for cx in [TABLA_X + 3, TABLA_X + TABLA_TAM.x - 4]:
		for y in range(4, TABLA_Y):
			px.call(int(cx) + (y % 2), y, hierro)
	# La tabla: tablones horizontales con bisel, marco negro y un clavo en cada esquina.
	var mad: Array = RAMPAS["madera_clara"]
	var x0: int = TABLA_X
	for y in TABLA_TAM.y:
		for x in TABLA_TAM.x:
			var col: Color = mad[3]
			if y % 7 == 6:
				col = mad[1]                       # la junta entre tablones
			elif y % 7 == 0:
				col = mad[4]                       # el canto de arriba de cada tablon, con luz
			if (x * 7 + y * 3) % 11 == 0 and col == mad[3]:
				col = mad[2]                       # la veta
			if x == 1 or y == 1:
				col = mad[4]
			if x == TABLA_TAM.x - 2 or y == TABLA_TAM.y - 2:
				col = mad[1]
			if x == 0 or y == 0 or x == TABLA_TAM.x - 1 or y == TABLA_TAM.y - 1:
				col = NEGRO
			px.call(x0 + x, TABLA_Y + y, col)
	for esq in [Vector2i(3, 3), Vector2i(TABLA_TAM.x - 4, 3), Vector2i(3, TABLA_TAM.y - 4),
			Vector2i(TABLA_TAM.x - 4, TABLA_TAM.y - 4)]:
		px.call(x0 + esq.x, TABLA_Y + esq.y, hierro)
	# El simbolo, grabado a fuego: oscuro, con una linea de luz debajo para que parezca hundido.
	var ic: Array = ICONOS.get(icono, [])
	var alto_ic: int = ic.size() * ESCALA_ICONO
	var ancho_ic: int = (String(ic[0]).length() if not ic.is_empty() else 0) * ESCALA_ICONO
	var ix0: int = (w - x0 - TABLA_TAM.x) if a_la_izq else x0   # la tabla ya reflejada
	ix0 += (TABLA_TAM.x - ancho_ic) / 2
	var iy0: int = TABLA_Y + (TABLA_TAM.y - alto_ic) / 2
	var tinta := Color(0.20, 0.12, 0.08)
	for j in ic.size():
		var fila: String = ic[j]
		for i in fila.length():
			if fila[i] != "#":
				continue
			for sy in ESCALA_ICONO:
				for sx in ESCALA_ICONO:
					_px(d, w, h, ix0 + i * ESCALA_ICONO + sx, iy0 + j * ESCALA_ICONO + sy, tinta)
			var abajo: bool = j + 1 >= ic.size() or String(ic[j + 1])[i] != "#"
			if abajo:
				for sx in ESCALA_ICONO:
					_px(d, w, h, ix0 + i * ESCALA_ICONO + sx, iy0 + (j + 1) * ESCALA_ICONO, mad[4])
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, d)


# Que lado lleva el cartel: el de la IZQUIERDA salvo que la casa diga otra cosa ("cartel_der").
static func cartel_a_la_izq(clave: String) -> bool:
	return not bool(CASAS[clave].get("cartel_der", false))


# Donde va el lienzo del cartel, en px del lienzo de la CASA (su esquina de arriba a la izquierda). La
# placa se solapa 2 px con la pared para que no quede flotando en el aire.
static func posicion_cartel(clave: String) -> Vector2i:
	var t: Vector2i = tam(clave)
	var alero: int = t.y - int(CASAS[clave]["alto"])
	var y: int = alero + CARTEL_BAJO_ALERO
	if cartel_a_la_izq(clave):
		return Vector2i(MARGEN + 2 - CARTEL_TAM.x, y)
	return Vector2i(t.x - MARGEN - 2, y)


# ------------------------------------------------------------
#  EXTRAS: lo que hace a cada casa SUYA
# ------------------------------------------------------------
static func _extra(d: PackedByteArray, w: int, h: int, que: String, e: Dictionary, alero: int, puerta_x: int, hu: Vector2i) -> void:
	match que:
		"pieles":
			# Dos pieles tendidas en la pared, estiradas con cuerdas.
			for k in 2:
				var cx: int = 22 + k * 22 if puerta_x > 64 else w - 44 + k * 22
				var cy: int = alero + 22
				_sombra(d, w, h, cx - 7, cy - 9, 14, 19)
				var r: Array = [Color(0.36, 0.24, 0.14), Color(0.55, 0.39, 0.24), Color(0.68, 0.51, 0.33)] if k == 0 \
					else [Color(0.30, 0.28, 0.26), Color(0.52, 0.50, 0.47), Color(0.66, 0.64, 0.60)]
				for yy in range(-10, 11):
					var semi: float = 7.0 - absf(float(yy)) * 0.25
					if absi(yy) > 7 and absi(yy) < 10:
						semi = 3.0
					for xx in range(-9, 10):
						if absf(float(xx)) > semi + (2.0 if absi(yy) >= 9 else 0.0):
							continue
						var col: Color = r[2] if absf(float(xx)) < semi - 3.0 else r[1]
						if absf(float(xx)) >= semi - 0.5:
							col = r[0]
						_px(d, w, h, cx + xx, cy + yy, col)
				_px(d, w, h, cx - 9, cy - 11, NEGRO)
				_px(d, w, h, cx + 9, cy - 11, NEGRO)
		"macetas":
			# Jardineras bajo las ventanas, con flores.
			for c in hu.x:
				var cx: int = c * CELDA + CELDA / 2
				if absi(cx - puerta_x) < CELDA:
					continue
				if hu.x >= 5 and c != 0 and c != hu.x - 1:
					continue
				var y0: int = alero + 27
				_rect(d, w, h, cx - 8, y0, 16, 4, RAMPAS["madera"][1])
				_marco(d, w, h, cx - 8, y0, 16, 4, NEGRO)
				for k in 7:
					var fx: int = cx - 7 + k * 2
					_px(d, w, h, fx, y0 - 1, Color(0.25, 0.50, 0.22))
					_px(d, w, h, fx, y0 - 2, Color(0.35, 0.60, 0.28) if k % 2 == 0 else [Color(0.90, 0.35, 0.40), Color(0.95, 0.85, 0.40), Color(0.75, 0.50, 0.85)][k % 3])
		"hierbas":
			# Manojos colgando del alero, a la izquierda de la puerta.
			for k in 3:
				var hx: int = puerta_x - 20 - k * 5
				_rect(d, w, h, hx, alero + 4, 1, 3, NEGRO)
				_rect(d, w, h, hx - 1, alero + 7, 3, 6, Color(0.30, 0.50, 0.25) if k != 1 else Color(0.55, 0.45, 0.25))
		"ristras":
			# Ristras de ajos y guindillas colgando junto a la puerta.
			for k in 2:
				var rx: int = puerta_x - 14 - k * 6
				for j in 6:
					var col: Color = Color(0.93, 0.90, 0.80) if k == 0 else Color(0.80, 0.18, 0.12)
					_px(d, w, h, rx, alero + 6 + j * 3, col)
					_px(d, w, h, rx + 1, alero + 6 + j * 3, col.darkened(0.2))
					_px(d, w, h, rx, alero + 7 + j * 3, col.darkened(0.3))
		"toldo":
			# Toldo a rayas sobre la planta baja, con el borde festoneado.
			var y0: int = alero + 6
			for y in 11:
				for x in range(MARGEN, w - MARGEN):
					var raya: bool = ((x / 8) % 2) == 0
					var col: Color = Color(0.72, 0.20, 0.18) if raya else Color(0.92, 0.88, 0.78)
					if y < 2:
						col = col.darkened(0.25)
					if y >= 9 and (x % 8) in [0, 7]:
						continue
					if y == 10 or (y == 9 and (x % 8) in [1, 6]):
						col = NEGRO
					_px(d, w, h, x, y0 + y, col)
		"estandarte":
			# Un estandarte rojo con dos espadas bordadas, colgado a la izquierda de la puerta.
			var x0: int = puerta_x - 28
			var y0: int = alero + 5
			_sombra(d, w, h, x0, y0 + 2, 10, 22)
			_rect(d, w, h, x0 - 2, y0, 14, 2, Color(0.15, 0.14, 0.15))
			for y in 24:
				for x in 10:
					if y >= 20 and absi(x - 5) < (y - 19):
						continue
					var col: Color = Color(0.62, 0.12, 0.14) if x > 1 else Color(0.45, 0.08, 0.10)
					if (x == 2 or x == 7) and y > 3 and y < 16 and absi(x - 2 - (y - 4) * 5 / 12) < 1:
						col = Color(0.95, 0.80, 0.35)
					_px(d, w, h, x0 + x, y0 + 2 + y, col)
			for y in 12:
				_px(d, w, h, x0 + 2 + y * 6 / 12, y0 + 6 + y, Color(0.95, 0.80, 0.35))
				_px(d, w, h, x0 + 7 - y * 6 / 12, y0 + 6 + y, Color(0.95, 0.80, 0.35))
		"redes":
			# Una red colgada en la pared (malla en rombos) y un pez secandose.
			var x0: int = puerta_x + 14
			var y0: int = alero + 6
			for y in 22:
				var semi: int = 8 + y / 4
				for x in range(-semi, semi):
					if (x + y) % 5 == 0 or (x - y) % 5 == 0:
						_px(d, w, h, x0 + 8 + x, y0 + y, Color(0.80, 0.76, 0.62))
			for x in 14:
				_px(d, w, h, 6 + x, alero + 16 + (1 if x > 3 and x < 10 else 0), Color(0.60, 0.66, 0.72))
				_px(d, w, h, 6 + x, alero + 17, Color(0.42, 0.48, 0.55))
			_px(d, w, h, 5, alero + 15, NEGRO)
		"farol":
			var fx: int = puerta_x + 16
			var fy: int = alero + 14
			_rect(d, w, h, fx - 2, fy - 3, 6, 1, Color(0.15, 0.14, 0.15))
			_rect(d, w, h, fx, fy - 2, 5, 8, Color(0.15, 0.14, 0.15))
			_rect(d, w, h, fx + 1, fy - 1, 3, 6, Color(1.0, 0.85, 0.45))
			for yy in range(-7, 8):
				for xx in range(-7, 8):
					var rr: float = sqrt(float(xx * xx + yy * yy))
					if rr < 7.0 and rr > 3.0:
						_px(d, w, h, fx + 2 + xx, fy + 2 + yy, Color(1.0, 0.85, 0.45, 0.12))
