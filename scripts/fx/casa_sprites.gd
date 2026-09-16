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
	if String(e["cartel"]) != "":
		_cartel(d, w, h, String(e["cartel"]), puerta_x, alero, clave == "tienda")
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
	var alto: int = h - alero
	var filas: Array = [alero + 10]
	if String(e["pared"]) == "taberna":
		filas = [alero + 8, alero + alto / 2 + 8]
	var luz: String = e["luz"]
	var cols: Array = []
	for c in hu.x:
		var cx: int = c * CELDA + CELDA / 2
		if absi(cx - puerta_x) < CELDA:
			continue
		# En las de 5 de ancho solo los extremos (y en la taberna todas, arriba).
		if hu.x >= 5 and c != 0 and c != hu.x - 1 and String(e["pared"]) != "taberna":
			continue
		cols.append(cx)
	for fi in filas.size():
		var y0: int = int(filas[fi])
		var xs: Array = cols
		if String(e["pared"]) == "taberna" and fi == 0:
			xs = []
			for c in hu.x:
				xs.append(c * CELDA + CELDA / 2)
		for cx in xs:
			_ventana(d, w, h, int(cx) - 7, y0, luz, "postigos" in e["extras"])


static func _ventana(d: PackedByteArray, w: int, h: int, x0: int, y0: int, luz: String, postigos: bool) -> void:
	var vidrio_a := Color(0.16, 0.22, 0.30)
	var vidrio_b := Color(0.30, 0.42, 0.52)
	match luz:
		"calida":
			vidrio_a = Color(0.85, 0.60, 0.25)
			vidrio_b = Color(1.00, 0.86, 0.50)
		"fragua":
			vidrio_a = Color(0.80, 0.30, 0.08)
			vidrio_b = Color(1.00, 0.65, 0.20)
		"verde":
			vidrio_a = Color(0.35, 0.60, 0.40)
			vidrio_b = Color(0.65, 0.88, 0.60)
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
	if humo or fragua:
		var bocanadas := [Vector3(0, -8, 4.5), Vector3(4, -15, 5.5), Vector3(1, -22, 4.0)]
		for b in bocanadas:
			var gris := Color(0.80, 0.80, 0.82, 0.55) if not fragua else Color(0.40, 0.38, 0.40, 0.55)
			for yy in range(-6, 7):
				for xx in range(-6, 7):
					if float(xx * xx + yy * yy) <= b.z * b.z:
						_px(d, w, h, cx + int(b.x) + xx, tope - 3 + int(b.y) + yy, gris)


# ------------------------------------------------------------
#  EL CARTEL: una tabla colgada de un brazo de hierro, a la derecha de la puerta, con el simbolo.
# ------------------------------------------------------------
const ICONOS := {
	"martillo": ["########", "########", "...##...", "...##...", "...##...", "...##..."],
	"serrucho": ["##......", "#######.", "########", "#.#.#.#.", "........", "........"],
	"piel": ["#......#", "########", ".######.", ".######.", "########", "#......#"],
	"frasco": ["...##...", "...##...", "..####..", ".######.", ".######.", "..####.."],
	"olla": ["..####..", "########", ".######.", ".######.", "..####..", "........"],
	"bolsa": ["..#..#..", "...##...", ".######.", "########", "########", ".######."],
	"jarra": ["######..", "######.#", "######.#", "######.#", "#######.", "######.."],
	"espadas": ["#......#", ".#....#.", "..#..#..", "...##...", "..#..#..", "##....##"],
	"pez": ["........", ".####..#", "######.#", "######.#", ".####..#", "........"],
}

static func _cartel(d: PackedByteArray, w: int, h: int, icono: String, puerta_x: int, alero: int, a_la_izq: bool) -> void:
	var x0: int = puerta_x + 14 if not a_la_izq else puerta_x - 32
	var y0: int = alero + 12
	var hierro := Color(0.15, 0.14, 0.15)
	# Brazo y cadenas.
	_rect(d, w, h, x0 - 1, y0 - 4, 18, 1, hierro)
	_px(d, w, h, x0 + 2, y0 - 2, hierro)
	_px(d, w, h, x0 + 13, y0 - 2, hierro)
	_px(d, w, h, x0 + 2, y0 - 3, hierro)
	_px(d, w, h, x0 + 13, y0 - 3, hierro)
	# Tabla.
	_sombra(d, w, h, x0, y0 - 1, 16, 12)
	var mad: Array = RAMPAS["madera_clara"]
	for y in 12:
		for x in 16:
			var col: Color = mad[3] if y % 4 != 3 else mad[2]
			if x == 0 or y == 0 or x == 15 or y == 11:
				col = NEGRO
			_px(d, w, h, x0 + x, y0 - 1 + y, col)
	var ic: Array = ICONOS.get(icono, [])
	for j in ic.size():
		var fila: String = ic[j]
		for i in fila.length():
			if fila[i] == "#":
				_px(d, w, h, x0 + 4 + i, y0 + 2 + j, Color(0.18, 0.12, 0.09))


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
