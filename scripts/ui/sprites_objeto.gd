# ============================================================
#  sprites_objeto.gd  (se usa por preload desde IconoItem, sin class_name)
#  LOS DIBUJOS DE LOS OBJETOS SUELTOS: el mineral, el lingote, la piel, el libro, el cristal...
#  Sustituyen al cubo de color de toda la vida, que decia "aqui hay algo marron" y nada mas.
#
#  PIXEL-ART CON FACETAS, como todo el juego (lo pidio el jefe: pixel siempre). Cada objeto se
#  describe como unas pocas FACETAS -- poligonos en coordenadas 0..1, cada uno con su papel de tono
#  (brillo, luz, base, sombra...) -- y aqui se RASTERIZAN a una rejilla de pixeles:
#    1. cada celda coge el tono de la ULTIMA faceta que la cubre (el orden es la profundidad);
#    2. las lineas (vetas, grietas, costuras) se trazan despues, solo sobre lo ya pintado;
#    3. el CONTORNO sale solo, alrededor de la silueta, como en el muñeco.
#  Asi las variantes y los cristales que crecen con el tier salen de mover y escalar facetas, no de
#  redibujar cada uno letra a letra.
#
#  DOS RESOLUCIONES: 32 en la celda, el banner y la vitrina; 16 en el SUELO de la mazmorra, que es lo
#  que mide alli un objeto. Es la misma descripcion pasada a otra rejilla -- encoger la de 32 a la
#  mitad se comeria el contorno.
#
#  EL COLOR NO VA EN EL DIBUJO: los papeles de tono salen del color del propio objeto (el naranja del
#  cobre, el gris del hierro), aclarado y oscurecido. Lo que no es del material (el papel de un libro,
#  el metal de una hebilla) lleva su color fijo en FIJOS.
#
#  NO SE PINTA COMO TEXTURA: el proyecto filtra las texturas en lineal y un pixel-art ampliado saldria
#  borroso. Van rectangulos, uno por racha de pixeles iguales de cada fila, con los bordes redondeados
#  a pixel entero -- nitido a cualquier escala, sin rendijas entre vecinos.
# ============================================================
extends RefCounted

const RES_GRANDE := 32
const RES_SUELO := 16
# Por debajo de este lado en pantalla se usa la rejilla del suelo.
const LADO_SUELO := 28.0

# ---- LOS PAPELES DE TONO ----
#   o contorno · d sombra honda · s sombra · b base · l luz · h brillo · v veta (otro color)
#   c grieta (se traza con la sombra honda del propio objeto)
#   y los FIJOS de abajo. Un "." en una faceta BORRA (sirve para agujeros: una anilla, un asa).
const FIJOS := {
	"w": Color(0.93, 0.90, 0.80), "x": Color(0.72, 0.68, 0.58),   # papel y su sombra
	"m": Color(0.82, 0.81, 0.76), "z": Color(0.50, 0.50, 0.50),   # metal claro de hebillas y remaches
	"g": Color(0.95, 0.80, 0.42), "G": Color(0.70, 0.52, 0.20),   # oro de la marca de un libro
	"W": Color(1.0, 1.0, 1.0), "Y": Color(1.0, 0.95, 0.72),       # el destello del PURO
	"F": Color(0.46, 0.74, 0.30), "f": Color(0.27, 0.52, 0.20),   # la hojita del tronco y de la rama
	"L": Color(1.0, 0.50, 0.12), "K": Color(1.0, 0.86, 0.36),     # las grietas encendidas de la lava
}
# 'A' y 'N' son la CARNE CLARA de la madera cortada y sus ANILLOS. No son fijos: salen del color de
# cada madera (ver _paleta), porque el corte de un tronco negro no es del mismo tono que el de un pino.

static var _cache: Dictionary = {}   # clave de forma + resolucion -> PackedByteArray de la rejilla


# ============================================================
#  QUE SE PINTA PARA CADA OBJETO
# ============================================================
# Pinta 'item' si tiene dibujo aqui y devuelve true; false = que lo pinte IconoItem a su manera.
static func pintar_item(ci: CanvasItem, centro: Vector2, lado: float, item: Resource) -> bool:
	var e: Dictionary = _encargo(item)
	if e.is_empty():
		return false
	var res: int = RES_SUELO if lado < LADO_SUELO else RES_GRANDE
	var clave: String = "%s|%d|%d" % [e["forma"], int(e.get("grietas", 0)), res]
	var celdas: PackedByteArray = _cache.get(clave, PackedByteArray())
	if celdas.is_empty():
		celdas = _rasterizar(_facetas(String(e["forma"])), int(e.get("grietas", 0)), res)
		_cache[clave] = celdas
	_pintar(ci, centro, lado, celdas, res, _paleta(e["color"], e.get("veta", Color(0, 0, 0, 0))))
	if bool(e.get("puro", false)):
		_destello(ci, centro, lado, res)
	return true


# QUE FORMA, DE QUE COLOR Y CON QUE ESTADO. {} = sin dibujo todavia.
static func _encargo(item: Resource) -> Dictionary:
	if item is MaterialItem:
		var mi := item as MaterialItem
		var e: Dictionary = _encargo_material(mi.data)
		if e.is_empty():
			return e
		e["color"] = mi.color()
		e["grietas"] = _grietas_de(int(mi.calidad), MaterialItem.Calidad)
		e["puro"] = mi.calidad == MaterialItem.Calidad.PURO
		return e
	if item is MaterialData:
		return _encargo_material(item as MaterialData)
	if item is Cristal:
		var cr := item as Cristal
		var i: int = (maxi(cr.categoria, 1) - 1) % 10
		var e2: Dictionary = {"forma": "cristal_%d_%d" % [i, int(cr.calidad)],
			"color": color_cristal(cr.categoria, int(cr.calidad)),
			"grietas": _grietas_de(int(cr.calidad), Cristal.Calidad)}
		e2["puro"] = false
		return e2
	if item is ConsumableData and (item as ConsumableData).en_biblioteca():
		var cd := item as ConsumableData
		var marca: String = "rombo" if cd.es_grimorio() else ("chispa" if cd.es_tomo_sabio() else "nada")
		return {"forma": "libro_" + marca, "color": cd.color_suelo()}
	if item is BackpackData:
		return {"forma": "mochila", "color": Color(0.58, 0.36, 0.20)}
	return {}


static func _encargo_material(d: MaterialData) -> Dictionary:
	if d == null:
		return {}
	var id: String = String(d.id)
	var forma: String = ""
	match d.tipo:
		MaterialData.Tipo.MINERAL:
			forma = ["mineral", "mineral_veteado", "mineral_profundo"][clampi(d.forma_recolectable(), 0, 2)]
		MaterialData.Tipo.LINGOTE:
			if id.begins_with("chapa_"):
				forma = "chapa"
			elif id.begins_with("hebillas_"):
				forma = "hebillas"
			else:
				forma = "lingote"
		MaterialData.Tipo.MADERA:
			forma = "tronco"
		MaterialData.Tipo.TABLON:
			forma = "tablon"
		MaterialData.Tipo.NUCLEO:
			forma = "nucleo_" + _estilo_nucleo(id)
		MaterialData.Tipo.CUERO:
			if id.begins_with("curtido_"):
				forma = "cuero"
			elif id.begins_with("correa_"):
				forma = "correa"
			elif id.begins_with("quitina"):
				forma = "quitina"
			elif id.begins_with("cuero_"):
				# LAS PIELES NO SON TODAS IGUALES: salen de bichos distintos, asi que unas van lisas, otras
				# con manchas y otras con rayas (como la hoja de referencia del jefe). Se elige por el id,
				# para que la misma piel salga siempre igual.
				forma = ["piel_lisa", "piel_manchas", "piel_rayas"][absi(hash(id)) % 3]
	if forma == "":
		return {}
	# La VETA es otro color, no el mismo mas claro (la leccion de las vetas del mapa): se tuerce el tono
	# hacia el oro y se aclara mucho, y asi una veta de cobre sale dorada y una de hierro plateada.
	var veta: Color = Color.from_hsv(fposmod(d.color.h + 0.05, 1.0), d.color.s * 0.55,
		minf(1.0, d.color.v + 0.42))
	return {"forma": forma, "color": d.color, "veta": veta}


# Cuantas grietas lleva cada estado. Mismo criterio para todo lo que tiene calidad (lo pidio el jefe:
# el desgaste se ve en TODOS los objetos, no solo en el mineral).
static func _grietas_de(cal: int, enum_cal: Dictionary) -> int:
	if cal == int(enum_cal["INTACTO"]):
		return 0
	if cal == int(enum_cal["NORMAL"]):
		return 1
	if cal == int(enum_cal["DANADO"]):
		return 3
	if cal == int(enum_cal["ROTO"]):
		return 4
	return 0


# ============================================================
#  EL COLOR DE UN CRISTAL
# ============================================================
# De un cristalito PALIDO en el T1 a uno INTENSO en el T10. Del T11 en adelante, las mismas formas con
# otro color: cada tanda de diez tiers tiene su tono (morado, rojo, azul...). El estado lo retoca: el
# intacto un punto mas vivo, el dañado apagado.
const CRISTAL_TONOS := [0.78, 0.99, 0.60, 0.33, 0.13]   # morado, rojo, azul, verde, oro

static func color_cristal(categoria: int, calidad: int) -> Color:
	var t: int = maxi(categoria, 1) - 1
	var f: float = float(t % 10) / 9.0
	var tono: float = CRISTAL_TONOS[(t / 10) % CRISTAL_TONOS.size()]
	var sat: float = lerpf(0.20, 0.88, f)
	var val: float = lerpf(0.96, 0.80, f)
	match calidad:
		Cristal.Calidad.INTACTO:
			sat = minf(1.0, sat + 0.06)
			val = minf(1.0, val + 0.06)
		Cristal.Calidad.DANADO, Cristal.Calidad.ROTO:
			sat *= 0.6
			val *= 0.72
	return Color.from_hsv(tono, sat, val)


# ============================================================
#  LAS FACETAS DE CADA FORMA
# ============================================================
# Una forma es una lista de pasos: {"p": poligono, "t": tono} rellena; {"l": polilinea, "t": tono}
# traza una linea de un pixel SOLO SOBRE lo ya pintado. Coordenadas 0..1, con la y hacia abajo.
static func _facetas(forma: String) -> Array:
	if forma.begins_with("cristal_"):
		var partes: PackedStringArray = forma.split("_")
		return _cristal(int(partes[1]), int(partes[2]))
	if forma.begins_with("libro_"):
		return _libro(forma.trim_prefix("libro_"))
	if forma.begins_with("piel_"):
		return _piel(forma.trim_prefix("piel_"))
	if forma.begins_with("nucleo_"):
		return _nucleo(forma.trim_prefix("nucleo_"))
	match forma:
		"tronco": return _tronco()
		"quitina": return _quitina()
		"mineral": return _mineral(0)
		"mineral_veteado": return _mineral(1)
		"mineral_profundo": return _mineral(2)
		"lingote": return _lingote()
		"chapa": return _chapa()
		"hebillas": return _hebillas()
		"tablon": return _tablon()
		"cuero": return _cuero()
		"correa": return _correa()
		"mochila": return _mochila()
	return []


static func P(v: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, v.size() - 1, 2):
		out.append(Vector2(float(v[i]), float(v[i + 1])))
	return out


static func _pol(t: String, v: Array) -> Dictionary:
	return {"p": P(v), "t": t}


static func _lin(t: String, v: Array) -> Dictionary:
	return {"l": P(v), "t": t}


# Una elipse como poligono (para lo redondo: anillas, ruedas de correa).
static func _elipse(t: String, cx: float, cy: float, rx: float, ry: float, n: int = 20) -> Dictionary:
	var out := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		out.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return {"p": out, "t": t}


# EL MINERAL: todo de mineral, sin trozos de roca (asi lo pidio el jefe: sobre el material entero se
# dibujan bien las grietas del estado). Un pedrusco tallado en caras, con la luz de arriba a la
# izquierda. Las tres variantes NO son "lo mismo mas oscuro":
#   0 bruto    -> el pedrusco y un par de esquirlas sueltas al pie
#   1 veteado  -> el mismo pedrusco cruzado por vetas de otro color
#   2 profundo -> ya no es un pedrusco: un racimo de puntas talladas, mas brillante
static func _mineral(variante: int) -> Array:
	if variante == 2:
		return [
			_pol("d", [0.14, 0.86, 0.22, 0.72, 0.80, 0.72, 0.88, 0.86, 0.76, 0.93, 0.24, 0.93]),
			# las dos puntas de atras
			_pol("l", [0.16, 0.76, 0.20, 0.44, 0.30, 0.34, 0.31, 0.76]),
			_pol("s", [0.30, 0.34, 0.40, 0.46, 0.40, 0.76, 0.31, 0.76]),
			_pol("l", [0.60, 0.76, 0.64, 0.38, 0.74, 0.26, 0.74, 0.76]),
			_pol("s", [0.74, 0.26, 0.86, 0.42, 0.84, 0.76, 0.74, 0.76]),
			# la grande del centro
			_pol("h", [0.33, 0.82, 0.37, 0.28, 0.50, 0.07, 0.50, 0.82]),
			_pol("b", [0.50, 0.07, 0.63, 0.28, 0.66, 0.82, 0.50, 0.82]),
			_lin("W", [0.43, 0.26, 0.49, 0.13]),
			# y una chica delante
			_pol("l", [0.22, 0.90, 0.26, 0.68, 0.34, 0.60, 0.36, 0.90]),
			_pol("s", [0.34, 0.60, 0.45, 0.70, 0.43, 0.90, 0.36, 0.90]),
			_pol("l", [0.62, 0.90, 0.66, 0.74, 0.72, 0.68, 0.73, 0.90]),
			_pol("d", [0.72, 0.68, 0.80, 0.76, 0.79, 0.90, 0.73, 0.90]),
		]
	var f: Array = [
		_pol("h", [0.14, 0.60, 0.26, 0.34, 0.46, 0.13, 0.50, 0.50]),
		_pol("l", [0.46, 0.13, 0.64, 0.19, 0.82, 0.42, 0.50, 0.50]),
		_pol("s", [0.82, 0.42, 0.88, 0.70, 0.64, 0.72, 0.50, 0.50]),
		_pol("b", [0.14, 0.60, 0.50, 0.50, 0.64, 0.72, 0.72, 0.86, 0.24, 0.86]),
		_pol("d", [0.64, 0.72, 0.88, 0.70, 0.72, 0.86]),
		# las esquirlas del pie
		_pol("l", [0.04, 0.82, 0.10, 0.70, 0.20, 0.70, 0.17, 0.81]),
		_pol("s", [0.04, 0.82, 0.17, 0.81, 0.22, 0.93, 0.06, 0.93]),
		_pol("l", [0.70, 0.85, 0.80, 0.76, 0.90, 0.80, 0.83, 0.87]),
		_pol("d", [0.70, 0.85, 0.83, 0.87, 0.90, 0.80, 0.93, 0.93, 0.72, 0.94]),
	]
	if variante == 1:
		f.append(_lin("v", [0.18, 0.56, 0.34, 0.54, 0.50, 0.60, 0.66, 0.56, 0.86, 0.62]))
		f.append(_lin("v", [0.34, 0.26, 0.42, 0.36, 0.38, 0.47]))
		f.append(_lin("v", [0.58, 0.26, 0.66, 0.38, 0.74, 0.44]))
		f.append(_lin("v", [0.30, 0.74, 0.44, 0.70, 0.56, 0.80]))
	return f


# EL LINGOTE: dos barras apiladas, la de atras en sombra. Cara de arriba en luz con su filo de
# brillo, frontal a su color y el labio de abajo en sombra.
static func _lingote() -> Array:
	var out: Array = []
	for n in 2:
		var dx: float = 0.07 if n == 0 else 0.0
		var dy: float = -0.16 if n == 0 else 0.06
		var top: String = "b" if n == 0 else "l"
		var fr: String = "s" if n == 0 else "b"
		out.append(_pol(top, [0.30 + dx, 0.34 + dy, 0.72 + dx, 0.34 + dy, 0.82 + dx, 0.48 + dy, 0.20 + dx, 0.48 + dy]))
		out.append(_pol(fr, [0.20 + dx, 0.48 + dy, 0.82 + dx, 0.48 + dy, 0.90 + dx, 0.66 + dy, 0.12 + dx, 0.66 + dy]))
		out.append(_pol("d", [0.12 + dx, 0.66 + dy, 0.90 + dx, 0.66 + dy, 0.88 + dx, 0.71 + dy, 0.14 + dx, 0.71 + dy]))
		out.append(_lin("h" if n == 1 else "l", [0.33 + dx, 0.38 + dy, 0.68 + dx, 0.38 + dy]))
		out.append(_lin("l" if n == 1 else "b", [0.24 + dx, 0.52 + dy, 0.18 + dx, 0.63 + dy]))
	return out


# LA CHAPA: dos planchas finas en perspectiva, con los remaches en las esquinas. Plana y ancha contra
# el lingote, que es gordo: a 16 px lo que las separa es la silueta.
static func _chapa() -> Array:
	var out: Array = []
	for n in 2:
		var dy: float = -0.12 if n == 0 else 0.06
		out.append(_pol("l" if n == 1 else "b", [0.10, 0.50 + dy, 0.48, 0.28 + dy, 0.90, 0.40 + dy, 0.52, 0.64 + dy]))
		out.append(_pol("s", [0.10, 0.50 + dy, 0.52, 0.64 + dy, 0.52, 0.70 + dy, 0.10, 0.56 + dy]))
		out.append(_pol("d", [0.52, 0.64 + dy, 0.90, 0.40 + dy, 0.90, 0.46 + dy, 0.52, 0.70 + dy]))
		if n == 1:
			out.append(_lin("h", [0.18, 0.49 + dy, 0.47, 0.32 + dy]))
			for r in [[0.22, 0.50], [0.48, 0.35], [0.76, 0.42], [0.52, 0.58]]:
				out.append(_elipse("m", r[0], r[1] + dy, 0.025, 0.025, 6))
	return out


# LAS HEBILLAS: dos anillas rectangulares con su pasador de metal claro.
static func _hebillas() -> Array:
	var out: Array = []
	for c in [[0.32, 0.40], [0.64, 0.62]]:
		var x: float = c[0]
		var y: float = c[1]
		out.append(_pol("b", [x - 0.20, y - 0.17, x + 0.20, y - 0.17, x + 0.20, y + 0.17, x - 0.20, y + 0.17]))
		out.append(_pol("l", [x - 0.20, y - 0.17, x + 0.20, y - 0.17, x + 0.20, y - 0.11, x - 0.20, y - 0.11]))
		out.append(_pol("s", [x - 0.20, y + 0.11, x + 0.20, y + 0.11, x + 0.20, y + 0.17, x - 0.20, y + 0.17]))
		out.append(_pol(".", [x - 0.12, y - 0.09, x + 0.12, y - 0.09, x + 0.12, y + 0.09, x - 0.12, y + 0.09]))
		out.append(_pol("m", [x - 0.02, y - 0.12, x + 0.02, y - 0.12, x + 0.02, y + 0.12, x - 0.02, y + 0.12]))
	return out


# EL TABLON: tres tablas apiladas en perspectiva, con la veta a lo largo y el canto de cada una. Como
# la referencia del jefe. La madera ya refinada va sin corteza: es lo que la separa del tronco.
static func _tablon() -> Array:
	var out: Array = []
	for n in 3:
		var dy: float = 0.24 - 0.12 * float(n)
		var dx: float = [0.02, -0.03, 0.0][n]
		out.append(_pol("b", [0.10 + dx, 0.46 + dy, 0.36 + dx, 0.22 + dy, 0.90 + dx, 0.32 + dy, 0.64 + dx, 0.56 + dy]))
		out.append(_pol("s", [0.10 + dx, 0.46 + dy, 0.64 + dx, 0.56 + dy, 0.64 + dx, 0.63 + dy, 0.10 + dx, 0.53 + dy]))
		out.append(_pol("d", [0.64 + dx, 0.56 + dy, 0.90 + dx, 0.32 + dy, 0.90 + dx, 0.39 + dy, 0.64 + dx, 0.63 + dy]))
		# la veta, a lo largo de la tabla, y el filo de luz del borde de delante
		out.append(_lin("s", [0.30 + dx, 0.30 + dy, 0.78 + dx, 0.39 + dy]))
		out.append(_lin("s", [0.22 + dx, 0.40 + dy, 0.50 + dx, 0.45 + dy, 0.66 + dx, 0.47 + dy]))
		out.append(_lin("l", [0.12 + dx, 0.46 + dy, 0.62 + dx, 0.55 + dy]))
		out.append(_lin("l", [0.36 + dx, 0.23 + dy, 0.88 + dx, 0.32 + dy]))
	return out


# EL CUERO CURTIDO: una hoja de cuero doblada, vista desde arriba en diagonal, con el doblez de debajo
# asomando por dos lados y las marcas del curtido en la cara. Como la referencia del jefe.
static func _cuero() -> Array:
	return [
		# la capa de debajo y el doblez, que asoma por abajo a la izquierda y por la derecha
		_pol("d", [0.12, 0.58, 0.20, 0.50, 0.58, 0.64, 0.60, 0.84, 0.52, 0.86, 0.14, 0.66]),
		_pol("s", [0.12, 0.56, 0.20, 0.48, 0.58, 0.60, 0.58, 0.74, 0.50, 0.76, 0.14, 0.62]),
		_pol("s", [0.78, 0.26, 0.88, 0.32, 0.86, 0.46, 0.64, 0.80, 0.58, 0.72]),
		# la cara de arriba
		_pol("b", [0.18, 0.50, 0.42, 0.16, 0.80, 0.26, 0.58, 0.64]),
		_lin("l", [0.20, 0.50, 0.42, 0.18]),
		_lin("l", [0.44, 0.17, 0.78, 0.27]),
		_lin("d", [0.20, 0.53, 0.56, 0.66]),
		# las marcas del curtido: crucecitas sueltas en la cara
		_lin("s", [0.40, 0.30, 0.46, 0.36]), _lin("s", [0.46, 0.30, 0.40, 0.36]),
		_lin("s", [0.58, 0.36, 0.64, 0.42]), _lin("s", [0.64, 0.36, 0.58, 0.42]),
		_lin("s", [0.40, 0.46, 0.46, 0.52]), _lin("s", [0.46, 0.46, 0.40, 0.52]),
		_lin("l", [0.30, 0.40, 0.34, 0.36]),
	]


# LA CORREA: una tira de cuero enrollada en rueda, con el cabo suelto y su hebilla de metal.
static func _correa() -> Array:
	return [
		_elipse("b", 0.40, 0.44, 0.30, 0.28),
		_elipse("s", 0.42, 0.47, 0.22, 0.20),
		_elipse("b", 0.40, 0.44, 0.17, 0.15),
		_elipse(".", 0.40, 0.44, 0.09, 0.08),
		_lin("l", [0.16, 0.40, 0.22, 0.26, 0.34, 0.18, 0.48, 0.17]),
		# el cabo suelto y la hebilla
		_pol("b", [0.56, 0.62, 0.64, 0.56, 0.86, 0.76, 0.80, 0.84]),
		_pol("s", [0.60, 0.68, 0.64, 0.64, 0.84, 0.80, 0.80, 0.84]),
		_pol("m", [0.70, 0.64, 0.80, 0.58, 0.94, 0.74, 0.84, 0.82]),
		_pol(".", [0.75, 0.66, 0.80, 0.63, 0.88, 0.73, 0.83, 0.77]),
	]


# LA PIEL EN BRUTO: el pellejo abierto, con sus cuatro patas, la cabeza arriba y la cola abajo. Como
# la hoja de referencia del jefe, y como alli, no todas iguales: lisas, con manchas o con rayas.
static func _piel(dibujo: String) -> Array:
	var out: Array = [
		# patas
		_pol("b", [0.34, 0.30, 0.16, 0.18, 0.10, 0.24, 0.28, 0.42]),
		_pol("b", [0.66, 0.30, 0.84, 0.18, 0.90, 0.24, 0.72, 0.42]),
		_pol("s", [0.32, 0.66, 0.10, 0.76, 0.14, 0.84, 0.36, 0.76]),
		_pol("s", [0.68, 0.66, 0.90, 0.76, 0.86, 0.84, 0.64, 0.76]),
		# la cola
		_pol("s", [0.46, 0.82, 0.54, 0.82, 0.60, 0.96, 0.54, 0.97]),
		# el cuerpo, con el borde mordido de un pellejo (no un ovalo limpio)
		_pol("b", [0.36, 0.18, 0.42, 0.14, 0.50, 0.10, 0.58, 0.14, 0.64, 0.18, 0.70, 0.30, 0.73, 0.40,
			0.71, 0.50, 0.74, 0.60, 0.70, 0.72, 0.62, 0.82, 0.50, 0.87, 0.38, 0.82, 0.30, 0.72, 0.26, 0.60,
			0.29, 0.50, 0.27, 0.40, 0.30, 0.30]),
		# la cabeza
		_pol("s", [0.42, 0.16, 0.50, 0.04, 0.58, 0.16, 0.50, 0.22]),
		# la barriga clara y el costado en sombra
		_pol("l", [0.42, 0.28, 0.58, 0.28, 0.62, 0.52, 0.50, 0.70, 0.38, 0.52]),
		_pol("s", [0.66, 0.30, 0.73, 0.40, 0.71, 0.50, 0.74, 0.60, 0.70, 0.72, 0.64, 0.66, 0.66, 0.48]),
		# el pelo: trazos cortos
		_lin("s", [0.36, 0.34, 0.38, 0.40]), _lin("s", [0.60, 0.60, 0.62, 0.66]),
		_lin("h", [0.46, 0.34, 0.48, 0.40]),
	]
	match dibujo:
		"manchas":
			for m in [[0.40, 0.44, 0.06], [0.58, 0.36, 0.05], [0.50, 0.62, 0.06], [0.64, 0.56, 0.04],
					[0.34, 0.62, 0.04]]:
				out.append(_elipse("d", m[0], m[1], m[2], m[2] * 0.8, 8))
		"rayas":
			for yy in [0.30, 0.42, 0.54, 0.66, 0.76]:
				out.append(_lin("d", [0.30, yy, 0.40, yy + 0.03]))
				out.append(_lin("d", [0.70, yy, 0.60, yy + 0.03]))
	return out


# EL LIBRO: la tapa de su color con luz en los bordes de arriba, el lomo oscuro con sus nervios de oro,
# el canto de las hojas en papel y las cantoneras de metal. La MARCA de la tapa dice la familia:
# ROMBO = grimorio, CHISPA = tomo de sabiduria, NADA = curiosidad (el mismo idioma que el gacha).
static func _libro(marca: String) -> Array:
	var out: Array = [
		# el canto de las hojas, a la derecha y abajo
		_pol("w", [0.74, 0.14, 0.84, 0.18, 0.84, 0.88, 0.74, 0.86]),
		_lin("x", [0.79, 0.22, 0.79, 0.82]),
		_pol("w", [0.26, 0.82, 0.74, 0.82, 0.84, 0.88, 0.30, 0.90]),
		# la tapa
		_pol("b", [0.24, 0.10, 0.76, 0.10, 0.76, 0.84, 0.24, 0.84]),
		_pol("l", [0.24, 0.10, 0.76, 0.10, 0.76, 0.14, 0.24, 0.14]),
		_pol("s", [0.24, 0.80, 0.76, 0.80, 0.76, 0.84, 0.24, 0.84]),
		# el lomo
		_pol("d", [0.14, 0.12, 0.26, 0.08, 0.26, 0.86, 0.14, 0.90]),
		_lin("g", [0.15, 0.24, 0.25, 0.21]),
		_lin("g", [0.15, 0.74, 0.25, 0.71]),
		# las cantoneras
		_pol("G", [0.64, 0.10, 0.76, 0.10, 0.76, 0.22]),
		_pol("G", [0.76, 0.72, 0.76, 0.84, 0.64, 0.84]),
		# un marco fino en la tapa
		_lin("s", [0.32, 0.18, 0.68, 0.18, 0.68, 0.76, 0.32, 0.76, 0.32, 0.18]),
	]
	match marca:
		"rombo":
			out.append(_pol("G", [0.50, 0.28, 0.63, 0.47, 0.50, 0.66, 0.37, 0.47]))
			out.append(_pol("g", [0.50, 0.32, 0.60, 0.47, 0.50, 0.62, 0.40, 0.47]))
			out.append(_pol("W", [0.50, 0.38, 0.54, 0.45, 0.50, 0.50, 0.46, 0.45]))
		"chispa":
			out.append(_pol("g", [0.50, 0.28, 0.54, 0.43, 0.50, 0.66, 0.46, 0.43]))
			out.append(_pol("g", [0.34, 0.47, 0.50, 0.43, 0.66, 0.47, 0.50, 0.51]))
			out.append(_pol("W", [0.50, 0.42, 0.52, 0.47, 0.50, 0.52, 0.48, 0.47]))
	return out


# LA MOCHILA: una cartera de cuero con su asa, la solapa, dos bolsillos y las hebillas grises. Como la
# referencia del jefe.
static func _mochila() -> Array:
	return [
		# el asa
		_pol("d", [0.36, 0.08, 0.64, 0.08, 0.66, 0.30, 0.34, 0.30]),
		_pol(".", [0.42, 0.14, 0.58, 0.14, 0.58, 0.30, 0.42, 0.30]),
		# el cuerpo
		_pol("b", [0.10, 0.34, 0.20, 0.26, 0.80, 0.26, 0.90, 0.34, 0.90, 0.84, 0.84, 0.90, 0.16, 0.90, 0.10, 0.84]),
		_pol("s", [0.80, 0.30, 0.90, 0.34, 0.90, 0.84, 0.84, 0.90, 0.80, 0.90]),
		_pol("d", [0.10, 0.84, 0.90, 0.84, 0.84, 0.90, 0.16, 0.90]),
		# la solapa
		_pol("l", [0.18, 0.28, 0.82, 0.28, 0.82, 0.48, 0.70, 0.54, 0.30, 0.54, 0.18, 0.48]),
		_lin("h", [0.22, 0.31, 0.78, 0.31]),
		_lin("s", [0.20, 0.49, 0.30, 0.54, 0.70, 0.54, 0.80, 0.49]),
		# los bolsillos, con su solapita
		_pol("s", [0.18, 0.60, 0.40, 0.60, 0.40, 0.82, 0.18, 0.82]),
		_pol("b", [0.18, 0.60, 0.40, 0.60, 0.40, 0.68, 0.18, 0.68]),
		_pol("s", [0.60, 0.60, 0.82, 0.60, 0.82, 0.82, 0.60, 0.82]),
		_pol("b", [0.60, 0.60, 0.82, 0.60, 0.82, 0.68, 0.60, 0.68]),
		# las hebillas
		_pol("m", [0.26, 0.46, 0.34, 0.46, 0.34, 0.56, 0.26, 0.56]),
		_pol("m", [0.66, 0.46, 0.74, 0.46, 0.74, 0.56, 0.66, 0.56]),
		_pol("m", [0.26, 0.66, 0.32, 0.66, 0.32, 0.72, 0.26, 0.72]),
		_pol("m", [0.68, 0.66, 0.74, 0.66, 0.74, 0.72, 0.68, 0.72]),
		_pol("m", [0.04, 0.44, 0.10, 0.44, 0.10, 0.60, 0.04, 0.60]),
		_pol("m", [0.90, 0.44, 0.96, 0.44, 0.96, 0.60, 0.90, 0.60]),
	]


# EL TRONCO: tumbado en diagonal, con el CORTE delante enseñando la carne clara y sus anillos, la
# corteza del color de cada madera y una hojita brotando -- la referencia del jefe. El corte sale del
# propio color (A/N en la paleta): un tronco negro no tiene la carne de un pino.
static func _tronco() -> Array:
	var a := Vector2(0.33, 0.62)            # el centro del corte
	var b := Vector2(0.72, 0.40)            # el del otro extremo
	var u: Vector2 = (b - a).normalized()   # a lo largo del tronco
	var n := Vector2(-u.y, u.x)             # de través (hacia abajo a la derecha)
	var r: float = 0.24
	var cara := func(t: String, esc: float, rel: bool = false) -> Dictionary:
		var pts := PackedVector2Array()
		for i in 24:
			var ang: float = TAU * float(i) / 24.0
			pts.append(a + n * (r * esc * sin(ang)) + u * (r * 0.62 * esc * cos(ang)))
		if rel:
			pts.append(pts[0])
			return {"l": pts, "t": t}
		return {"p": pts, "t": t}
	var cuerpo := func(t: String, d0: float, d1: float) -> Dictionary:
		return {"p": PackedVector2Array([a + n * (r * d0), b + n * (r * d0), b + n * (r * d1),
			a + n * (r * d1)]), "t": t}
	var fondo := PackedVector2Array()   # el otro extremo, redondo, detras de todo
	for i in 16:
		var ang: float = TAU * float(i) / 16.0
		fondo.append(b + n * (r * sin(ang)) + u * (r * 0.5 * cos(ang)))
	return [
		# la hoja y su tallo, detras del tronco
		_lin("f", [0.50, 0.36, 0.46, 0.22]),
		_pol("F", [0.46, 0.24, 0.34, 0.14, 0.30, 0.04, 0.42, 0.10, 0.48, 0.20]),
		_pol("f", [0.46, 0.24, 0.34, 0.14, 0.40, 0.18]),
		{"p": fondo, "t": "s"},
		cuerpo.call("b", -1.0, 1.0),
		cuerpo.call("l", -1.0, -0.45),
		cuerpo.call("s", 0.40, 1.0),
		cuerpo.call("d", 0.78, 1.0),
		# la corteza: surcos a lo largo
		{"l": PackedVector2Array([a + n * (r * -0.2) + u * 0.08, b + n * (r * -0.2)]), "t": "s"},
		{"l": PackedVector2Array([a + n * (r * 0.25) + u * 0.12, b + n * (r * 0.25) - u * 0.05]), "t": "d"},
		{"l": PackedVector2Array([a + n * (r * -0.65) + u * 0.15, a + n * (r * -0.65) + u * 0.30]), "t": "h"},
		# el corte: el reborde de corteza, la carne clara, los anillos y el corazon
		cara.call("d", 1.05),
		cara.call("A", 0.90),
		cara.call("N", 0.62, true),
		cara.call("N", 0.30, true),
		{"p": PackedVector2Array([a - Vector2(0.015, 0.015), a + Vector2(0.015, -0.015),
			a + Vector2(0.015, 0.015), a + Vector2(-0.015, 0.015)]), "t": "N"},
	]


# LA QUITINA: una placa de caparazon curvada, como el ala dura de un escarabajo, con sus segmentos y un
# brillo duro. Es cuero en el juego (se trabaja igual), pero no es un pellejo: es concha.
static func _quitina() -> Array:
	return [
		_pol("s", [0.14, 0.62, 0.20, 0.36, 0.36, 0.18, 0.58, 0.14, 0.78, 0.22, 0.88, 0.40, 0.86, 0.62,
			0.72, 0.80, 0.50, 0.86, 0.28, 0.80]),
		{"p": P([0.18, 0.56, 0.24, 0.36, 0.38, 0.22, 0.58, 0.18, 0.76, 0.26, 0.82, 0.42, 0.78, 0.58,
			0.62, 0.70, 0.40, 0.72]), "t": "b", "dentro": true},
		{"p": P([0.26, 0.44, 0.36, 0.28, 0.52, 0.22, 0.62, 0.26, 0.48, 0.34, 0.36, 0.48]), "t": "l",
			"dentro": true},
		_lin("d", [0.20, 0.60, 0.40, 0.66, 0.62, 0.64, 0.82, 0.52]),
		_lin("d", [0.30, 0.74, 0.50, 0.80, 0.72, 0.74]),
		_lin("d", [0.50, 0.20, 0.52, 0.64]),
		_lin("h", [0.34, 0.34, 0.44, 0.26]),
		_lin("h", [0.64, 0.30, 0.70, 0.36]),
	]


# EL NUCLEO: una ESFERA con la textura del bicho del que sale (las referencias del jefe: pelo, baba,
# piedra, lava, corteza, escamas...). El color es el del .tres del nucleo; el ESTILO sale del bicho.
static func _estilo_nucleo(id: String) -> String:
	for par in [
		["pelo", ["rata", "jabali", "bestia", "minotauro", "chillon", "polilla"]],
		["baba", ["slime", "venenoso", "sanguijuela"]],
		["piedra", ["gargola", "golem", "coloso"]],
		["madera", ["trent"]],
		["lava", ["fuego"]],
		["escamas", ["arana", "escarabajo", "ciempies", "segadora"]],
		["hongo", ["miconido"]],
		["gema", ["profundo", "acechador", "aberracion"]]]:
		for clave in par[1]:
			if id.contains(clave):
				return par[0]
	return "baba"


static func _nucleo(estilo: String) -> Array:
	var c := Vector2(0.5, 0.50)
	var r: float = 0.36
	var bola := func(t: String, dx: float, dy: float, rr: float, dentro: bool = true) -> Dictionary:
		var e: Dictionary = _elipse(t, c.x + dx, c.y + dy, rr, rr, 28)
		e["dentro"] = dentro
		return e
	if estilo == "gema":
		# LA GEMA no es una bola: un cristal tallado (la roja de la referencia), cara por cara.
		return [
			_pol("s", [0.50, 0.12, 0.84, 0.32, 0.84, 0.68, 0.50, 0.90, 0.16, 0.68, 0.16, 0.32]),
			_pol("l", [0.50, 0.12, 0.16, 0.32, 0.36, 0.40, 0.50, 0.30]),
			_pol("h", [0.50, 0.12, 0.50, 0.30, 0.64, 0.40, 0.84, 0.32]),
			_pol("b", [0.36, 0.40, 0.50, 0.30, 0.64, 0.40, 0.64, 0.60, 0.50, 0.70, 0.36, 0.60]),
			_pol("l", [0.16, 0.32, 0.36, 0.40, 0.36, 0.60, 0.16, 0.68]),
			_pol("d", [0.16, 0.68, 0.36, 0.60, 0.50, 0.70, 0.50, 0.90]),
			_pol("s", [0.64, 0.60, 0.84, 0.68, 0.50, 0.90, 0.50, 0.70]),
			_lin("W", [0.42, 0.36, 0.48, 0.32]),
		]
	var out: Array = []
	# LO QUE CUELGA POR DEBAJO va antes que la bola (asi la bola lo tapa por arriba y asoma solo abajo).
	if estilo == "pelo":
		# el flequillo del pelo, colgando por debajo de la bola (el "hair" de la referencia)
		out.append(_pol("d", [0.16, 0.56, 0.84, 0.56, 0.86, 0.70, 0.80, 0.78, 0.76, 0.72, 0.70, 0.88,
			0.64, 0.80, 0.58, 0.92, 0.50, 0.82, 0.42, 0.92, 0.36, 0.80, 0.30, 0.88, 0.24, 0.72, 0.20, 0.78,
			0.14, 0.70]))
	elif estilo == "baba":
		# las gotas que chorrean
		out.append(_pol("s", [0.30, 0.74, 0.40, 0.74, 0.39, 0.90, 0.35, 0.94, 0.31, 0.90]))
		out.append(_pol("s", [0.56, 0.78, 0.66, 0.76, 0.64, 0.86, 0.61, 0.89, 0.58, 0.86]))
	elif estilo == "madera":
		# la rama con su hoja, asomando por la derecha
		out.append(_pol("s", [0.74, 0.40, 0.90, 0.26, 0.94, 0.30, 0.80, 0.46]))
		out.append(_pol("F", [0.88, 0.26, 0.86, 0.12, 0.96, 0.08, 0.96, 0.22]))
	# LA BOLA con su volumen: sombra honda, sombra, base, luz y brillo, cada una un poco hacia la luz.
	out.append(_elipse("d" if estilo != "lava" else "o", c.x, c.y, r, r, 32))
	if estilo == "lava":
		# LA LAVA es la bola apagada y oscura, y lo que brilla son las GRIETAS, no la superficie.
		out.append(bola.call("d", -0.03, -0.03, r * 0.9))
		out.append(bola.call("s", -0.10, -0.10, r * 0.45))
		for g in [[0.28, 0.40, 0.40, 0.46, 0.46, 0.38, 0.58, 0.44, 0.70, 0.36],
				[0.40, 0.46, 0.36, 0.60, 0.46, 0.70, 0.60, 0.66, 0.68, 0.74],
				[0.58, 0.44, 0.62, 0.56, 0.76, 0.58],
				[0.24, 0.58, 0.36, 0.60],
				[0.50, 0.24, 0.46, 0.38]]:
			out.append(_lin("L", g))
		out.append(_lin("K", [0.40, 0.46, 0.46, 0.38, 0.58, 0.44]))
		out.append(_lin("K", [0.36, 0.60, 0.46, 0.70]))
		return out
	out.append(bola.call("s", -0.03, -0.03, r * 0.94))
	out.append(bola.call("b", -0.06, -0.07, r * 0.78))
	out.append(bola.call("l", -0.12, -0.13, r * 0.44))
	match estilo:
		"pelo":
			# mechones: trazos cortos a favor del pelo, y sin brillo (el pelo es mate)
			for m in [[0.30, 0.34, 0.34, 0.44], [0.42, 0.26, 0.44, 0.36], [0.56, 0.28, 0.58, 0.38],
					[0.66, 0.40, 0.70, 0.50], [0.36, 0.54, 0.40, 0.64], [0.52, 0.50, 0.54, 0.60],
					[0.62, 0.60, 0.64, 0.70]]:
				out.append(_lin("d", m))
			for m in [[0.36, 0.30, 0.38, 0.38], [0.48, 0.24, 0.50, 0.32]]:
				out.append(_lin("h", m))
		"baba":
			# brillo grande de cosa mojada, y burbujas por dentro
			out.append(bola.call("h", -0.14, -0.15, r * 0.20))
			out.append(bola.call("W", -0.16, -0.17, r * 0.08))
			out.append(bola.call("l", 0.10, 0.08, r * 0.10))
			out.append(bola.call("l", 0.02, 0.18, r * 0.06))
		"piedra":
			# las juntas de las piedras (la bola de "stones" de la referencia), con luz en cada cara
			for g in [[0.18, 0.44, 0.34, 0.46, 0.44, 0.36, 0.44, 0.18],
					[0.44, 0.36, 0.60, 0.44, 0.74, 0.30],
					[0.34, 0.46, 0.36, 0.62, 0.22, 0.70],
					[0.36, 0.62, 0.54, 0.64, 0.60, 0.44],
					[0.54, 0.64, 0.60, 0.82],
					[0.60, 0.44, 0.84, 0.56]]:
				out.append(_lin("o", g))
			for g in [[0.26, 0.40, 0.32, 0.38], [0.50, 0.30, 0.56, 0.32], [0.42, 0.52, 0.48, 0.52]]:
				out.append(_lin("h", g))
		"madera":
			# la corteza: surcos de arriba abajo, curvados con la bola
			for g in [[0.30, 0.22, 0.24, 0.50, 0.30, 0.78], [0.44, 0.16, 0.40, 0.50, 0.44, 0.86],
					[0.58, 0.16, 0.60, 0.50, 0.56, 0.86], [0.72, 0.24, 0.76, 0.50, 0.70, 0.78]]:
				out.append(_lin("d", g))
			out.append(_lin("l", [0.36, 0.24, 0.33, 0.44]))
		"escamas":
			# filas de escamas: arquitos, y un brillo duro de caparazon
			for fila in [0.30, 0.44, 0.58, 0.72]:
				var x: float = 0.18 + (0.07 if int(fila * 100) % 28 == 2 else 0.0)
				while x < 0.82:
					out.append(_lin("d", [x, fila, x + 0.05, fila + 0.05, x + 0.10, fila]))
					x += 0.12
			out.append(bola.call("h", -0.14, -0.15, r * 0.12))
		"hongo":
			# un sombrero con motas claras (el micónido)
			for m in [[0.36, 0.34, 0.07], [0.58, 0.30, 0.05], [0.66, 0.52, 0.06], [0.44, 0.60, 0.05],
					[0.28, 0.54, 0.04]]:
				var e: Dictionary = _elipse("m", m[0], m[1], m[2], m[2] * 0.85, 10)
				e["dentro"] = true
				out.append(e)
	return out


# EL CRISTAL: un racimo que CRECE con el tier. 'i' = 0..9 (la posicion dentro de su tanda de diez) y
# 'cal' el estado. El T1 es un cristalito suelto y pequeño; cada tier suma tamaño, y cada dos una
# punta mas al racimo. El intacto sale un punto mas grande, el dañado un punto mas chico.
static func _cristal(i: int, cal: int) -> Array:
	# PEQUEÑO PERO LEGIBLE: el T1 empezaba en 0,40 y en la celda era una astilla que no se veia. Ahora
	# arranca en algo mas de la mitad de la caja y es lo GORDO (y las puntas de alrededor) lo que crece.
	var esc: float = 0.60 + 0.04 * float(i)
	match cal:
		Cristal.Calidad.INTACTO: esc *= 1.05
		Cristal.Calidad.DANADO, Cristal.Calidad.ROTO: esc *= 0.90
	var ancho: float = 0.26 + 0.012 * float(i)
	var n: int = 1 + i / 2   # 1..5 puntas
	# CENTRADO EN VERTICAL: el pie baja lo justo para que el racimo quede en medio de la caja, sea del
	# tamaño que sea (pegado abajo, el T1 flotaba en un hueco vacio).
	var pie: float = 0.5 + 0.80 * esc * 0.5
	var out: Array = []
	# Las de los LADOS primero (van detras), cada vez mas abiertas y mas bajas; la grande al final.
	var lados: Array = []
	for k in range(1, n):
		var paso: int = (k + 1) / 2
		var s: float = -1.0 if k % 2 == 1 else 1.0
		lados.append({"x": 0.5 + s * 0.12 * float(paso) * esc / 0.7, "ang": s * 0.38 * float(paso),
			"alto": 0.62 - 0.12 * float(paso), "ancho": ancho * 0.8})
	lados.reverse()
	for p in lados:
		out.append_array(_punta(p["x"], pie, p["ancho"] * esc, p["alto"] * esc, p["ang"]))
	out.append_array(_punta(0.5, pie, ancho * esc, 0.80 * esc, 0.0))
	return out


# Una punta de cristal: prisma de seis caras visto de lado -- cara izquierda en luz, derecha en
# sombra, y el pico partido en brillo y base. 'x,y' es el pie; 'ang' la inclina desde ahi.
static func _punta(x: float, y: float, ancho: float, alto: float, ang: float) -> Array:
	var gira := func(px: float, py: float) -> Vector2:
		return Vector2(x, y) + Vector2(px, py).rotated(ang)
	var a: float = ancho * 0.5
	var bi: Vector2 = gira.call(-a, 0.0)
	var bd: Vector2 = gira.call(a, 0.0)
	var bc: Vector2 = gira.call(0.0, 0.0)
	var hi: Vector2 = gira.call(-a, -alto * 0.70)
	var hd: Vector2 = gira.call(a, -alto * 0.70)
	var hc: Vector2 = gira.call(0.0, -alto * 0.74)
	var pico: Vector2 = gira.call(0.0, -alto)
	return [
		{"p": PackedVector2Array([bi, hi, hc, bc]), "t": "l"},
		{"p": PackedVector2Array([bc, hc, hd, bd]), "t": "s"},
		{"p": PackedVector2Array([hi, pico, hc]), "t": "h"},
		{"p": PackedVector2Array([hc, pico, hd]), "t": "b"},
		{"l": PackedVector2Array([gira.call(-a * 0.45, -alto * 0.10), gira.call(-a * 0.45, -alto * 0.62)]), "t": "h"},
	]


# LAS GRIETAS del estado. Las mismas para todos los objetos: se trazan solo sobre lo pintado, asi que
# cada una cae donde haya objeto debajo. Mas estado malo, mas grietas.
const GRIETAS := [
	[0.60, 0.34, 0.55, 0.44, 0.61, 0.50],
	[0.40, 0.40, 0.46, 0.50, 0.41, 0.58, 0.47, 0.66],
	[0.28, 0.60, 0.37, 0.64, 0.35, 0.73],
	[0.56, 0.62, 0.66, 0.70, 0.64, 0.78],
]


# ============================================================
#  EL RASTERIZADOR
# ============================================================
static func _rasterizar(pasos: Array, grietas: int, res: int) -> PackedByteArray:
	var celdas := PackedByteArray()
	celdas.resize(res * res)
	celdas.fill(0)
	var lleno := func(i: int) -> bool:
		return celdas[i] != 0
	for paso in pasos:
		var t: int = String(paso["t"]).unicode_at(0)
		if paso.has("p"):
			var pts: PackedVector2Array = paso["p"]
			var caja := Rect2(pts[0], Vector2.ZERO)
			for q in pts:
				caja = caja.expand(q)
			var x0: int = maxi(0, int(floor(caja.position.x * res)))
			var x1: int = mini(res - 1, int(ceil(caja.end.x * res)))
			var y0: int = maxi(0, int(floor(caja.position.y * res)))
			var y1: int = mini(res - 1, int(ceil(caja.end.y * res)))
			for y in range(y0, y1 + 1):
				for x in range(x0, x1 + 1):
					var c := Vector2((float(x) + 0.5) / res, (float(y) + 0.5) / res)
					if Geometry2D.is_point_in_polygon(c, pts):
						# "dentro": solo sobre lo ya pintado (las luces de una esfera no se salen de ella).
						if paso.get("dentro", false) and celdas[y * res + x] == 0:
							continue
						celdas[y * res + x] = 0 if t == 46 else t   # 46 = "."
		else:
			_trazar(celdas, paso["l"], t, res, lleno)
	for g in mini(grietas, GRIETAS.size()):
		_trazar(celdas, P(GRIETAS[g]), "c".unicode_at(0), res, lleno)
	_contornear(celdas, res)
	return celdas


# Una polilinea de un pixel, SOLO sobre lo ya pintado: una veta o una grieta nunca se salen del objeto.
static func _trazar(celdas: PackedByteArray, pts: PackedVector2Array, t: int, res: int,
		lleno: Callable) -> void:
	for i in pts.size() - 1:
		var a: Vector2 = pts[i] * res
		var b: Vector2 = pts[i + 1] * res
		var pasos: int = maxi(1, int(ceil(a.distance_to(b) * 2.0)))
		for k in pasos + 1:
			var p: Vector2 = a.lerp(b, float(k) / float(pasos))
			var x: int = clampi(int(p.x), 0, res - 1)
			var y: int = clampi(int(p.y), 0, res - 1)
			if lleno.call(y * res + x):
				celdas[y * res + x] = t


# EL CONTORNO: todo hueco que toca la silueta por un lado (no por la esquina) pasa a ser borde. Por los
# lados y no por las esquinas, que es lo que deja el contorno fino y redondeado del pixel-art.
static func _contornear(celdas: PackedByteArray, res: int) -> void:
	var o: int = "o".unicode_at(0)
	var copia: PackedByteArray = celdas.duplicate()
	for y in res:
		for x in res:
			if copia[y * res + x] != 0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < res and ny < res and copia[ny * res + nx] != 0 \
						and copia[ny * res + nx] != o:
					celdas[y * res + x] = o
					break


# ============================================================
#  PINTAR
# ============================================================
static func _pintar(ci: CanvasItem, centro: Vector2, lado: float, celdas: PackedByteArray, res: int,
		pal: Dictionary) -> void:
	var k: float = lado / float(res)
	var org: Vector2 = centro - Vector2(lado, lado) * 0.5
	for y in res:
		var y0: float = round(org.y + float(y) * k)
		var y1: float = round(org.y + float(y + 1) * k)
		var x: int = 0
		while x < res:
			var c: int = celdas[y * res + x]
			var xs: int = x
			while x < res and celdas[y * res + x] == c:
				x += 1
			if c == 0:
				continue
			var col: Variant = pal.get(c, null)
			if col == null:
				continue
			var x0: float = round(org.x + float(xs) * k)
			var x1: float = round(org.x + float(x) * k)
			ci.draw_rect(Rect2(x0, y0, x1 - x0, y1 - y0), col)


# EL DESTELLO DEL PURO: una estrella de cuatro puntas arriba a la derecha, blanca en el centro y
# dorada en las puntas, con una chiquita al lado. Es el mismo gesto que el fogonazo de la puñalada
# certera, en pixel y en "brillo" en vez de en "golpe". Va sin contorno: es luz, no un objeto.
static func _destello(ci: CanvasItem, centro: Vector2, lado: float, res: int) -> void:
	var k: float = lado / float(res)
	var org: Vector2 = centro - Vector2(lado, lado) * 0.5
	var pix := func(x: int, y: int, col: Color) -> void:
		var x0: float = round(org.x + float(x) * k)
		var y0: float = round(org.y + float(y) * k)
		ci.draw_rect(Rect2(x0, y0, round(org.x + float(x + 1) * k) - x0,
			round(org.y + float(y + 1) * k) - y0), col)
	var brazo: int = 3 if res >= RES_GRANDE else 2
	var cx: int = int(res * 0.78)
	var cy: int = int(res * 0.20)
	var oro: Color = FIJOS["Y"]
	for d in range(1, brazo + 1):
		var c: Color = oro if d < brazo else Color(oro, 0.6)
		pix.call(cx + d, cy, c)
		pix.call(cx - d, cy, c)
		pix.call(cx, cy + d, c)
		pix.call(cx, cy - d, c)
	pix.call(cx + 1, cy + 1, Color(oro, 0.7))
	pix.call(cx - 1, cy - 1, Color(oro, 0.7))
	pix.call(cx + 1, cy - 1, Color(oro, 0.7))
	pix.call(cx - 1, cy + 1, Color(oro, 0.7))
	pix.call(cx, cy, FIJOS["W"])
	if res >= RES_GRANDE:
		var sx: int = int(res * 0.20)
		var sy: int = int(res * 0.72)
		pix.call(sx, sy, FIJOS["W"])
		pix.call(sx + 1, sy, Color(oro, 0.7))
		pix.call(sx - 1, sy, Color(oro, 0.7))
		pix.call(sx, sy + 1, Color(oro, 0.7))
		pix.call(sx, sy - 1, Color(oro, 0.7))


# LOS TONOS DE UN OBJETO, del codigo de su letra a su color. Salen todos de su color, aclarado y
# oscurecido -- lo que hace que el cobre siga pareciendo cobre en la sombra y en el brillo. El
# contorno no es negro: es su propio color casi negro, que lo remata sin despegarlo.
static func _paleta(col: Color, veta: Color) -> Dictionary:
	var pal: Dictionary = {}
	for k in FIJOS:
		pal[String(k).unicode_at(0)] = FIJOS[k]
	pal["o".unicode_at(0)] = col.darkened(0.78)
	pal["d".unicode_at(0)] = col.darkened(0.50)
	pal["s".unicode_at(0)] = col.darkened(0.26)
	pal["b".unicode_at(0)] = col
	pal["l".unicode_at(0)] = col.lightened(0.24)
	pal["h".unicode_at(0)] = col.lightened(0.55)
	pal["v".unicode_at(0)] = veta if veta.a > 0.0 else col.lightened(0.55)
	pal["c".unicode_at(0)] = col.darkened(0.66)
	pal["A".unicode_at(0)] = col.lightened(0.62)
	pal["N".unicode_at(0)] = col.lightened(0.34)
	return pal
