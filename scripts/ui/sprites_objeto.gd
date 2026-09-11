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
	"P": Color(0.88, 0.60, 0.62), "p": Color(0.64, 0.38, 0.42),   # la carne rosa de colas y orejas
	"R": Color(0.92, 0.18, 0.16), "E": Color(1.0, 0.84, 0.24),    # ojos: rojo de araña, amarillo de fiera
	"I": Color(0.95, 0.92, 0.82), "i": Color(0.70, 0.64, 0.52),   # marfil de cuernos y colmillos
	# la MADERA de los mangos y su cuerda de atar: son de madera sea cual sea el metal de la cabeza
	"u": Color(0.56, 0.37, 0.20), "U": Color(0.36, 0.22, 0.12), "j": Color(0.72, 0.52, 0.30),
	"k": Color(0.82, 0.68, 0.42),
	# el VIDRIO de los frascos y su sombra
	"T": Color(0.80, 0.87, 0.92), "t": Color(0.56, 0.64, 0.72),
	# el CRISTAL AZUL del farolillo de tier 3
	"Q": Color(0.82, 0.96, 1.0), "C": Color(0.44, 0.78, 1.0), "q": Color(0.20, 0.42, 0.82),
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
	if e.has("planta") or e.has("pez"):
		var img: Image = _imagen_pez(e["pez"], e["color"], int(e.get("grietas", 0))) if e.has("pez") \
			else _imagen_planta(int(e["planta"]), e["color"], int(e.get("grietas", 0)))
		_pintar_imagen(ci, centro, lado, img)
		if bool(e.get("puro", false)):
			_destello(ci, centro, lado, RES_SUELO if lado < LADO_SUELO else RES_GRANDE)
		return true
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
	if item is ConsumableData and (item as ConsumableData).es_vuelta_pueblo():
		# LA PIEDRA DE RETORNO: un monolito con la runa encendida, y la runa lleva el simbolo del JEFE
		# del tramo de pisos que cubre (lo pidio el jefe): la de 1-6 la corona del Rey Slime, la de
		# 1-12 los cuernos del Minotauro. Se decide por su ALCANCE, no por su nombre.
		var hasta: int = int((item as ConsumableData).piso_max_vuelta)
		return {"forma": "piedra_" + RUNA_DE_TRAMO.get(hasta, "corona"),
			"color": Color(0.56, 0.58, 0.63)}
	if item is ConsumableData and (item as ConsumableData).es_cebo():
		# LOS CEBOS, literalmente lo que son: un gusano y una sanguijuela.
		var sang: bool = String((item as ConsumableData).resource_path).contains("sanguijuela")
		return {"forma": "cebo_sanguijuela" if sang else "cebo_gusano",
			"color": Color(0.42, 0.22, 0.28) if sang else Color(0.86, 0.56, 0.56)}
	if item is ConsumableData and _se_bebe(item as ConsumableData):
		# LA POCION: la FORMA del frasco la dice el TIER (una por tier, como la cuadricula de
		# referencia del jefe) y el +N la hace un poco mas GRANDE dentro del mismo tier. El color, lo
		# que lleva dentro.
		var cp := item as ConsumableData
		var n: int = clampi(cp.plus(), 0, 3)
		# Y EL +N TAMBIEN SE VE EN EL COLOR (lo pidio el jefe): la base es PALIDA -- mas lavada y mas
		# clara -- y la del tope INTENSA. La de vida va de un rosa desvaido a un rojo vivo. El tope es
		# el de SU escala: el antidoto solo llega a +1 (ver IconoItem.techo_pocion), y ahi ya es intenso.
		var base: Color = cp.color_suelo()
		var f: float = clampf(float(n) / (1.0 if cp.es_brebaje_de_estado() else 3.0), 0.0, 1.0)
		var col: Color = Color.from_hsv(base.h, base.s * lerpf(0.45, 1.0, f),
			lerpf(minf(1.0, base.v + 0.22), base.v, f))
		return {"forma": "pocion_%d_%d" % [(maxi(cp.tier, 1) - 1) % 9, n], "color": col}
	if item is ConsumableData and (item as ConsumableData).en_biblioteca():
		var cd := item as ConsumableData
		var marca: String = "rombo" if cd.es_grimorio() else ("chispa" if cd.es_tomo_sabio() else "nada")
		return {"forma": "libro_" + marca, "color": cd.color_suelo()}
	if item is ToolData:
		var td := item as ToolData
		var meta: Dictionary = Game.meta_de(item)
		var tier: int = maxi(int(meta.get("tier", 1)), 1)
		if td.es_lampara():
			# EL FAROLILLO CAMBIA DE ASPECTO CON EL TIER (las tres referencias del jefe): farol cuadrado,
			# candil con asa y farol labrado de luz azul. Pasado el T3 se queda con el ultimo.
			var ft: int = clampi(tier, 1, 3)
			return {"forma": "farol_%d" % ft, "color": FAROL_COLOR[ft - 1]}
		var forma_h: String = ["pico", "hoz", "hacha", "cana", "farol_1"][int(td.tipo)]
		# La cabeza, del METAL de su tier y su mejora -- el mismo que una espada (PaletaEquipo).
		return {"forma": forma_h, "color": PaletaEquipo.base(PaletaEquipo.METAL, tier,
			Game.mejoras_actuales(item))}
	if item is BackpackData:
		# EL CUERO DE SU TIER Y SU MEJORA, el mismo que lleva una armadura de cuero (PaletaEquipo): antes
		# todas las mochilas salian del mismo marron y una T3 no se distinguia de la basica.
		var m: Dictionary = Game.meta_de(item)
		var mej: int = Game.mejoras_actuales(item)
		return {"forma": "mochila",
			"color": PaletaEquipo.base(PaletaEquipo.FIBRA, maxi(int(m.get("tier", 1)), 1), mej)}
	return {}


# Lo que se BEBE (pociones y antidotos). El mismo criterio que IconoItem.es_pocion.
static func _se_bebe(cd: ConsumableData) -> bool:
	return not cd.en_biblioteca() and not cd.es_plato() and not cd.es_cebo() \
		and not cd.es_vuelta_pueblo()


static func _encargo_material(d: MaterialData) -> Dictionary:
	if d == null:
		return {}
	var id: String = String(d.id)
	var forma: String = ""
	# LAS PLANTAS QUE SE RECOGEN salen con SU dibujo del suelo (el del nodo del mapa, lo pidio el jefe):
	# la misma hierba que arrancas es la que ves en la bolsa. El indice es el de resource_node.
	if d.tipo == MaterialData.Tipo.PLANTA and PLANTAS_DEL_SUELO.has(id):
		return {"planta": (clampi(d.tier, 1, 3) - 1) * 3 + d.forma_recolectable(), "color": d.color}
	if SUELTOS.has(id):
		return {"forma": SUELTOS[id], "color": d.color}
	# EL PESCADO, con su sprite del minijuego de pesca (lo pidio el jefe: reutilizarlo).
	if d.tipo == MaterialData.Tipo.PESCADO:
		return {"pez": d, "color": d.color}
	if d.tipo == MaterialData.Tipo.CARNE:
		return {"forma": id, "color": d.color}
	if d.tipo == MaterialData.Tipo.DESPENSA and DESPENSA.has(id):
		return {"forma": id, "color": d.color}
	match d.tipo:
		MaterialData.Tipo.BABA:
			# Las babas de SLIME, como gelatina (la referencia del jefe); la de fuego, de lava. El icor y
			# el veneno de insecto no son de slime: esperan su dibujo.
			if id == "baba_fuego":
				forma = "baba_lava"
			elif id.begins_with("baba_"):
				forma = "baba"
		MaterialData.Tipo.COMBUSTIBLE:
			var de_madera: bool = false
			for m in ["vegetal", "anillado", "calcinada", "latente", "petrificado"]:
				if id.contains(m):
					de_madera = true
			forma = "carbon_vegetal" if de_madera else "carbon"
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
			forma = "nucleo_" + id.trim_prefix("nucleo_")
		MaterialData.Tipo.CUERO:
			if id.begins_with("curtido_") or id == "cuero_curtido":
				forma = "cuero"   # cuero_curtido se llama "Cuero simple": ya esta trabajado, no es pellejo
			elif id.begins_with("correa_"):
				forma = "correa"
			elif PIEL_DE.has(id):
				forma = PIEL_DE[id]
	if forma == "":
		return {}
	# La VETA es otro color, no el mismo mas claro (la leccion de las vetas del mapa): se tuerce el tono
	# hacia el oro y se aclara mucho, y asi una veta de cobre sale dorada y una de hierro plateada.
	var veta: Color = Color.from_hsv(fposmod(d.color.h + 0.05, 1.0), d.color.s * 0.55,
		minf(1.0, d.color.v + 0.42))
	return {"forma": forma, "color": d.color, "veta": veta}


# El cuerpo de cada farolillo: bronce, laton y hierro oscuro (el azul lo pone su cristal).
const FAROL_COLOR := [Color(0.70, 0.44, 0.22), Color(0.78, 0.56, 0.26), Color(0.30, 0.31, 0.38)]

# LOS SUELTOS que no son de ninguna familia (lo acordado con el jefe): el polvo en un saquito, las
# esporas como una nube de bolitas y los liquidos en un frasquito, cada uno de su color.
const SUELTOS := {"polvo_de_alas": "saquito", "esporas_densas": "esporas", "icor": "frasquito",
	"veneno_insecto": "frasquito", "humor_ciego": "frasquito"}

# EL SIMBOLO DE LA RUNA de cada piedra de retorno, por el ULTIMO piso que cubre = el jefe que cierra
# ese tramo. Un tramo nuevo (13-18...) se añade aqui con el simbolo de SU jefe, y su dibujo en _piedra.
const RUNA_DE_TRAMO := {6: "corona", 12: "cuernos"}

# LA DESPENSA que tiene dibujo propio (el resto de la tanda de comida va aparte, uno a uno).
const DESPENSA := ["tomate", "pimiento", "zanahoria", "patata", "cebolla", "ajo", "lechuga",
	"puerro_gruta", "tuberculo_palido", "seta_simas", "hongo_azufre", "pan", "queso", "aceite",
	"piedra_sal"]

const PLANTAS_DEL_SUELO := ["hierba_palida", "raiz_amarga", "sanguinaria", "moho_simas",
	"raiz_umbria", "liquen_abisal", "musgo_ciego", "zarza_retorcida", "flor_de_sima"]


# DE QUE BICHO ES CADA PIEL, sacado de los drops de scenes/actors/enemy/. Cada una lleva el pellejo
# de SU bicho (lo pidio el jefe: la rata con su cola, el jabali con sus cerdas...). Si una piel nueva
# no esta aqui, sale el cubo: mejor eso que el pellejo de otro.
const PIEL_DE := {
	"cuero_simple": "piel_rata", "cuero_curado": "piel_rey_rata", "cuero_brunido": "piel_jabali",
	"cuero_placado": "piel_acechador", "cuero_endurecido": "piel_chupasimas",
	"cuero_reforzado": "piel_arana", "cuero_acorazado": "piel_bestia", "cuero_t3": "piel_minotauro",
	"quitina": "quitina", "quitina_segada": "quitina_segada",
}


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
	if DESPENSA.has(forma):
		return _despensa(forma)
	if forma.begins_with("pocion_"):
		var pp: PackedStringArray = forma.split("_")
		return _pocion(int(pp[1]), int(pp[2]))
	match forma:
		"tronco": return _tronco()
		"piedra_corona": return _piedra("corona")
		"piedra_cuernos": return _piedra("cuernos")
		"cebo_gusano": return _gusano()
		"cebo_sanguijuela": return _sanguijuela()
		"carne_rata": return _muslo()
		"carne_jabali": return _jamon()
		"carne_bestia": return _chuleton()
		"carne_insecto": return _pata_insecto()
		"pico": return _pico()
		"hacha": return _hacha()
		"hoz": return _hoz()
		"cana": return _cana()
		"cuchillo": return _cuchillo()
		"farol_1": return _farol_1()
		"farol_2": return _farol_2()
		"farol_3": return _farol_3()
		"saquito": return _saquito()
		"esporas": return _esporas()
		"frasquito": return _frasquito()
		"baba": return _baba(false)
		"baba_lava": return _baba(true)
		"carbon": return _carbon()
		"carbon_vegetal": return _carbon_vegetal()
		"quitina": return _quitina(false)
		"quitina_segada": return _quitina(true)
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


# Una TIRA con grosor a lo largo de una polilinea: colas, patas, tentaculos, antenas. El grosor va de
# 'a0' en la punta de salida a 'a1' en la de llegada, asi una cola nace gorda y acaba en punta.
static func _tira(t: String, v: Array, a0: float, a1: float) -> Dictionary:
	var pts: PackedVector2Array = P(v)
	var izq := PackedVector2Array()
	var der := PackedVector2Array()
	for i in pts.size():
		var dir: Vector2 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var nn := Vector2(-dir.y, dir.x)
		var a: float = lerpf(a0, a1, float(i) / float(maxi(pts.size() - 1, 1))) * 0.5
		izq.append(pts[i] + nn * a)
		der.append(pts[i] - nn * a)
	der.reverse()
	izq.append_array(der)
	return {"p": izq, "t": t}


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


# LA PIEL EN BRUTO: el pellejo abierto de SU bicho, visto desde arriba, con la cabeza arriba (la hoja
# de referencia del jefe). Cada una se reconoce por lo que tenia el animal: la cola rosa de la rata,
# las cerdas del jabali, las ocho patas de la araña... El color es el del .tres de la piel.
static func _piel(bicho: String) -> Array:
	var out: Array = []
	match bicho:
		"rata", "rey_rata":
			var rey: bool = bicho == "rey_rata"
			var k: float = 1.15 if rey else 1.0
			# la cola rosa, larga y enroscada, y las orejas: es lo que dice "rata" de un vistazo
			out.append(_tira("P", [0.50, 0.74, 0.54, 0.86, 0.66, 0.92, 0.80, 0.86, 0.84, 0.76], 0.07 * k, 0.02))
			out.append(_elipse("p", 0.40, 0.14, 0.06 * k, 0.06 * k, 10))
			out.append(_elipse("p", 0.60, 0.14, 0.06 * k, 0.06 * k, 10))
			out.append_array(_patas4(0.5, 0.46, 0.14 * k, 0.24 * k, 0.12, "b"))
			out.append(_elipse("b", 0.5, 0.46, 0.17 * k, 0.28 * k, 22))
			out.append(_pol("b", [0.42, 0.22, 0.50, 0.08, 0.58, 0.22]))
			out.append({"p": _elipse("l", 0.47, 0.44, 0.08 * k, 0.18 * k, 14)["p"], "t": "l", "dentro": true})
			out.append(_lin("s", [0.40, 0.40, 0.42, 0.48]))
			out.append(_lin("s", [0.58, 0.52, 0.60, 0.60]))
			if rey:
				# EL REY: mas grande, rasgado y con cicatrices -- ha vivido mucho mas que una rata
				out.append(_pol(".", [0.66, 0.36, 0.72, 0.40, 0.66, 0.44]))
				out.append(_lin("d", [0.38, 0.56, 0.46, 0.64]))
				out.append(_lin("d", [0.54, 0.30, 0.62, 0.36]))
				out.append({"p": _elipse("d", 0.5, 0.46, 0.04, 0.24, 10)["p"], "t": "d", "dentro": true})
		"jabali":
			# ANCHO Y CORTO, con la CRESTA de cerdas oscuras por el lomo y las pezuñas en las patas
			out.append_array(_patas4(0.5, 0.50, 0.22, 0.24, 0.11, "s"))
			for pz in [[0.22, 0.26], [0.78, 0.26], [0.22, 0.76], [0.78, 0.76]]:
				out.append(_elipse("d", pz[0], pz[1], 0.035, 0.035, 8))
			out.append(_tira("s", [0.50, 0.78, 0.54, 0.86, 0.50, 0.90], 0.04, 0.02))
			out.append(_elipse("b", 0.5, 0.50, 0.26, 0.28, 24))
			out.append(_pol("b", [0.40, 0.26, 0.44, 0.10, 0.50, 0.16, 0.56, 0.10, 0.60, 0.26]))
			out.append({"p": _elipse("l", 0.44, 0.48, 0.12, 0.18, 14)["p"], "t": "l", "dentro": true})
			out.append(_pol("d", [0.47, 0.18, 0.53, 0.18, 0.56, 0.30, 0.52, 0.42, 0.56, 0.56, 0.52, 0.70,
				0.50, 0.78, 0.48, 0.70, 0.44, 0.56, 0.48, 0.42, 0.44, 0.30]))
			for i in 5:
				var y: float = 0.30 + 0.09 * float(i)
				out.append(_lin("s", [0.36, y, 0.42, y + 0.03]))
				out.append(_lin("s", [0.64, y, 0.58, y + 0.03]))
		"acechador":
			# ESBELTO y MOTEADO, con las patas largas y una cola larguisima: un felino, lo contrario del jabali
			out.append(_tira("s", [0.52, 0.80, 0.58, 0.90, 0.72, 0.94, 0.86, 0.88, 0.90, 0.78], 0.06, 0.03))
			out.append_array(_patas4(0.5, 0.48, 0.13, 0.24, 0.07, "b", 1.5))
			out.append(_elipse("b", 0.5, 0.48, 0.15, 0.32, 22))
			out.append(_pol("b", [0.40, 0.18, 0.44, 0.08, 0.50, 0.12, 0.56, 0.08, 0.60, 0.18]))
			out.append({"p": _elipse("s", 0.56, 0.52, 0.06, 0.26, 12)["p"], "t": "s", "dentro": true})
			for m in [[0.46, 0.30], [0.54, 0.40], [0.44, 0.50], [0.56, 0.60], [0.48, 0.70], [0.42, 0.40],
					[0.58, 0.28]]:
				var e: Dictionary = _elipse("d", m[0], m[1], 0.03, 0.025, 8)
				e["dentro"] = true
				out.append(e)
		"chupasimas":
			# PIEL DE SANGUIJUELA: sin patas, larga como una babosa, anillada y brillante, con una ventosa
			# en cada punta.
			out.append(_pol("b", [0.40, 0.12, 0.60, 0.12, 0.66, 0.30, 0.68, 0.50, 0.66, 0.70, 0.60, 0.88,
				0.40, 0.88, 0.34, 0.70, 0.32, 0.50, 0.34, 0.30]))
			out.append({"p": P([0.40, 0.12, 0.48, 0.12, 0.42, 0.30, 0.40, 0.50, 0.42, 0.70, 0.46, 0.88,
				0.40, 0.88, 0.34, 0.70, 0.32, 0.50, 0.34, 0.30]), "t": "l", "dentro": true})
			for i in 7:
				var y2: float = 0.20 + 0.10 * float(i)
				out.append(_lin("d", [0.34, y2, 0.50, y2 + 0.02, 0.66, y2]))
			out.append(_elipse("s", 0.5, 0.14, 0.07, 0.04, 10))
			out.append(_elipse("s", 0.5, 0.86, 0.08, 0.05, 10))
			out.append(_lin("h", [0.40, 0.24, 0.39, 0.40]))
		"arana":
			# OCHO PATAS finas y dobladas alrededor de un cuerpo redondo y peludo.
			for lado in [-1.0, 1.0]:
				for i in 4:
					var y3: float = 0.36 + 0.08 * float(i)
					var x0: float = 0.5 + lado * 0.14
					var x1: float = 0.5 + lado * 0.36
					var x2: float = 0.5 + lado * 0.44
					out.append(_tira("d", [x0, y3, x1, y3 - 0.10 + 0.05 * float(i), x2,
						y3 + 0.06 + 0.05 * float(i)], 0.05, 0.025))
			out.append(_elipse("b", 0.5, 0.56, 0.18, 0.22, 20))
			out.append(_elipse("b", 0.5, 0.30, 0.10, 0.09, 14))
			out.append({"p": _elipse("l", 0.46, 0.52, 0.08, 0.10, 12)["p"], "t": "l", "dentro": true})
			out.append(_pol("R", [0.50, 0.50, 0.54, 0.56, 0.50, 0.66, 0.46, 0.56]))
			for m in [[0.42, 0.64], [0.58, 0.46], [0.60, 0.62]]:
				out.append(_lin("s", [m[0], m[1], m[0] + 0.02, m[1] + 0.04]))
		"bestia":
			# PELLEJO ANCHO CON BANDAS DE PLACAS, como un armadillo: es la piel de un animal blindado.
			out.append_array(_patas4(0.5, 0.50, 0.24, 0.22, 0.12, "s"))
			out.append(_elipse("b", 0.5, 0.50, 0.28, 0.30, 24))
			out.append(_pol("s", [0.42, 0.24, 0.46, 0.12, 0.54, 0.12, 0.58, 0.24]))
			for i in 6:
				var y4: float = 0.28 + 0.08 * float(i)
				out.append({"p": P([0.20, y4, 0.80, y4, 0.80, y4 + 0.035, 0.20, y4 + 0.035]), "t": "l",
					"dentro": true})
				out.append(_lin("d", [0.22, y4 + 0.05, 0.78, y4 + 0.05]))
		"minotauro":
			# LA PIEL DE TORO: ancha, las cuatro patas abiertas, manchas oscuras y los CUERNOS en la
			# cabeza, que es lo que la separa de cualquier otra piel grande.
			out.append_array(_patas4(0.5, 0.52, 0.22, 0.26, 0.12, "b"))
			out.append(_tira("s", [0.50, 0.80, 0.52, 0.92], 0.04, 0.03))
			out.append(_elipse("b", 0.5, 0.52, 0.24, 0.30, 24))
			out.append(_pol("b", [0.40, 0.28, 0.44, 0.14, 0.56, 0.14, 0.60, 0.28]))
			out.append(_tira("I", [0.44, 0.16, 0.34, 0.12, 0.30, 0.04], 0.05, 0.02))
			out.append(_tira("I", [0.56, 0.16, 0.66, 0.12, 0.70, 0.04], 0.05, 0.02))
			for m in [[0.40, 0.44, 0.08], [0.60, 0.58, 0.07], [0.46, 0.70, 0.05]]:
				var e2: Dictionary = _elipse("d", m[0], m[1], m[2], m[2] * 0.8, 10)
				e2["dentro"] = true
				out.append(e2)
			out.append({"p": _elipse("l", 0.46, 0.34, 0.06, 0.06, 10)["p"], "t": "l", "dentro": true})
	return out


# LAS CUATRO PATAS de un pellejo, abiertas en aspa desde el cuerpo (centro cx,cy; semiejes rx,ry).
# 'largo' es cuanto sobresalen; 'estira' las hace mas largas y finas (el acechador).
static func _patas4(cx: float, cy: float, rx: float, ry: float, largo: float, t: String,
		estira: float = 1.0) -> Array:
	var out: Array = []
	for s in [[-1.0, -1.0], [1.0, -1.0], [-1.0, 1.0], [1.0, 1.0]]:
		var bx: float = cx + s[0] * rx * 0.6
		var by: float = cy + s[1] * ry * 0.55
		var px: float = bx + s[0] * largo * estira
		var py: float = by + s[1] * largo * 0.6 * estira
		out.append(_tira(t, [bx, by, px, py], 0.10 / estira, 0.06 / estira))
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


# ============================================================
#  LAS HERRAMIENTAS (la referencia del jefe: en diagonal, mango abajo a la izquierda)
# ============================================================
# El MANGO es de madera siempre; la CABEZA, del metal de su tier (el color que llega).
const MANGO_A := Vector2(0.12, 0.90)   # el pie del mango
const MANGO_B := Vector2(0.66, 0.34)   # donde se encaja la cabeza

static func _mango(out: Array, a: Vector2 = MANGO_A, b: Vector2 = MANGO_B, grosor: float = 0.09) -> void:
	out.append(_tira("u", [a.x, a.y, b.x, b.y], grosor, grosor * 0.9))
	out.append(_tira("j", [a.x - 0.01, a.y - 0.03, b.x - 0.02, b.y - 0.02], grosor * 0.3, grosor * 0.25))
	out.append(_lin("U", [a.x + 0.03, a.y + 0.01, b.x + 0.02, b.y + 0.03]))


# EL PICO: dos brazos curvos cruzados al mango, afilados en las puntas, y la cuerda que los ata.
static func _pico() -> Array:
	var out: Array = []
	_mango(out)
	var h: Vector2 = MANGO_B + Vector2(0.03, -0.03)
	var p := Vector2(0.707, 0.707)     # a lo ancho de la cabeza
	var baja := Vector2(-0.707, 0.707) # hacia el pie del mango: los brazos se curvan hacia alli
	for s in [-1.0, 1.0]:
		var m: Vector2 = h + p * (s * 0.18) - baja * 0.03
		var fin: Vector2 = h + p * (s * 0.36) + baja * 0.10
		out.append(_tira("b", [h.x, h.y, m.x, m.y, fin.x, fin.y], 0.10, 0.02))
		out.append(_tira("l", [h.x - 0.01, h.y - 0.03, m.x - 0.01, m.y - 0.03], 0.03, 0.02))
	out.append(_elipse("s", h.x, h.y, 0.06, 0.06, 10))
	out.append(_lin("k", [h.x - 0.05, h.y + 0.02, h.x + 0.02, h.y + 0.06]))
	out.append(_lin("k", [h.x - 0.03, h.y - 0.02, h.x + 0.04, h.y + 0.02]))
	return out


# EL HACHA: la hoja ancha a un lado, con el filo en luz, y el talon corto al otro.
static func _hacha() -> Array:
	var out: Array = []
	_mango(out)
	var h: Vector2 = MANGO_B + Vector2(0.02, -0.02)
	var eje := Vector2(0.707, -0.707)   # a lo largo del mango, hacia arriba
	var p := Vector2(0.707, 0.707)      # hacia el filo
	var pts: Array = []
	for q in [h - p * 0.07 - eje * 0.08, h - p * 0.07 + eje * 0.08, h + p * 0.10 + eje * 0.09,
			h + p * 0.26 + eje * 0.16, h + p * 0.30 + eje * 0.02, h + p * 0.26 - eje * 0.14,
			h + p * 0.10 - eje * 0.08]:
		pts.append(q.x)
		pts.append(q.y)
	out.append(_pol("b", pts))
	var f0: Vector2 = h + p * 0.24 + eje * 0.13
	var f1: Vector2 = h + p * 0.27 - eje * 0.11
	out.append(_tira("h", [f0.x, f0.y, (h + p * 0.29).x, (h + p * 0.29).y, f1.x, f1.y], 0.04, 0.04))
	var l0: Vector2 = h - p * 0.04 + eje * 0.06
	out.append(_lin("l", [l0.x, l0.y, (h + p * 0.12 + eje * 0.08).x, (h + p * 0.12 + eje * 0.08).y]))
	out.append(_lin("s", [(h - p * 0.05 - eje * 0.06).x, (h - p * 0.05 - eje * 0.06).y,
		(h + p * 0.10 - eje * 0.07).x, (h + p * 0.10 - eje * 0.07).y]))
	return out


# LA HOZ: el mango corto y la hoja en media luna, afilada por dentro.
static func _hoz() -> Array:
	var out: Array = []
	_mango(out, Vector2(0.20, 0.90), Vector2(0.44, 0.60), 0.09)
	var c := Vector2(0.54, 0.40)
	var arco: Array = []
	var filo: Array = []
	for i in 9:
		var a: float = lerpf(PI * 0.80, PI * 2.05, float(i) / 8.0)
		var r: float = 0.28
		arco.append(c.x + cos(a) * r)
		arco.append(c.y + sin(a) * r * 0.9)
		filo.append(c.x + cos(a) * (r - 0.03))
		filo.append(c.y + sin(a) * (r - 0.03) * 0.9)
	out.append(_tira("b", arco, 0.10, 0.02))
	out.append(_lin("h", filo.slice(0, 14)))
	out.append(_elipse("s", 0.44, 0.60, 0.045, 0.045, 8))
	return out


# LA CAÑA: la vara larga y fina, el puño de corcho, el carrete y el sedal colgando con su corcho de
# pesca rojo. La vara es madera; el carrete y la anilla, del metal de su tier.
static func _cana() -> Array:
	return [
		_tira("u", [0.10, 0.92, 0.84, 0.10], 0.06, 0.025),
		_tira("j", [0.09, 0.90, 0.82, 0.10], 0.02, 0.01),
		_tira("k", [0.10, 0.92, 0.26, 0.74], 0.08, 0.075),
		_elipse("b", 0.30, 0.74, 0.06, 0.06, 12),
		_elipse("s", 0.30, 0.74, 0.03, 0.03, 8),
		{"l": P([0.84, 0.10, 0.85, 0.40, 0.84, 0.62]), "t": "x", "libre": true},
		_elipse("R", 0.84, 0.66, 0.035, 0.035, 8),
		_elipse("W", 0.84, 0.70, 0.03, 0.02, 8),
	]


# EL CUCHILLO DE DESOLLAR: hoja corta y curva, de un solo filo. Dibujado ya para cuando entre la
# herramienta (lo pidio el jefe: servira para sacar los cristales de los enemigos).
static func _cuchillo() -> Array:
	var out: Array = []
	_mango(out, Vector2(0.20, 0.86), Vector2(0.42, 0.62), 0.11)
	out.append(_pol("b", [0.40, 0.58, 0.50, 0.46, 0.66, 0.30, 0.86, 0.14, 0.78, 0.34, 0.62, 0.52, 0.48, 0.66]))
	out.append(_lin("h", [0.52, 0.48, 0.66, 0.32, 0.84, 0.16]))
	out.append(_lin("s", [0.50, 0.62, 0.64, 0.50, 0.78, 0.34]))
	out.append(_pol("s", [0.36, 0.56, 0.42, 0.52, 0.52, 0.62, 0.46, 0.68]))
	return out


# ============================================================
#  LOS FAROLILLOS, UNO POR TIER (las tres referencias del jefe)
# ============================================================
# T1: el farol CUADRADO de siempre, con el tejadillo en punta y la luz calida por los cristales.
static func _farol_1() -> Array:
	return [
		_tira("s", [0.50, 0.04, 0.50, 0.14], 0.05, 0.05),
		_pol("s", [0.24, 0.30, 0.50, 0.12, 0.76, 0.30]),
		_pol("l", [0.24, 0.30, 0.50, 0.12, 0.50, 0.30]),
		_pol("d", [0.22, 0.30, 0.78, 0.30, 0.78, 0.36, 0.22, 0.36]),
		_pol("b", [0.24, 0.36, 0.76, 0.36, 0.76, 0.80, 0.24, 0.80]),
		# los dos cristales encendidos, con su llama
		_pol("L", [0.30, 0.40, 0.48, 0.40, 0.48, 0.76, 0.30, 0.76]),
		_pol("L", [0.52, 0.40, 0.70, 0.40, 0.70, 0.76, 0.52, 0.76]),
		_pol("K", [0.33, 0.48, 0.46, 0.48, 0.46, 0.72, 0.33, 0.72]),
		_pol("K", [0.54, 0.48, 0.67, 0.48, 0.67, 0.72, 0.54, 0.72]),
		_elipse("Y", 0.40, 0.62, 0.035, 0.06, 8),
		_elipse("Y", 0.60, 0.62, 0.035, 0.06, 8),
		_pol("d", [0.20, 0.80, 0.80, 0.80, 0.76, 0.88, 0.24, 0.88]),
		_lin("h", [0.26, 0.38, 0.26, 0.78]),
	]


# T2: el CANDIL: la tapa, el asa en arco, el globo de cristal con la luz dentro y el pie.
static func _farol_2() -> Array:
	var asa: Array = []
	for i in 9:
		var a: float = lerpf(PI * 1.05, PI * 1.95, float(i) / 8.0)
		asa.append(0.50 + cos(a) * 0.30)
		asa.append(0.50 + sin(a) * 0.40)
	return [
		_tira("s", asa, 0.04, 0.04),
		_elipse("d", 0.50, 0.20, 0.14, 0.05, 12),
		_pol("b", [0.38, 0.20, 0.62, 0.20, 0.66, 0.30, 0.34, 0.30]),
		_lin("l", [0.40, 0.22, 0.60, 0.22]),
		_elipse("L", 0.50, 0.54, 0.22, 0.20, 20),
		_elipse("K", 0.49, 0.53, 0.16, 0.14, 18),
		_elipse("Y", 0.48, 0.55, 0.06, 0.07, 10),
		# las varillas que protegen el cristal
		_lin("s", [0.36, 0.34, 0.30, 0.54, 0.36, 0.74]),
		_lin("s", [0.64, 0.34, 0.70, 0.54, 0.64, 0.74]),
		_lin("s", [0.50, 0.34, 0.50, 0.74]),
		_pol("b", [0.32, 0.72, 0.68, 0.72, 0.72, 0.80, 0.28, 0.80]),
		_pol("d", [0.26, 0.80, 0.74, 0.80, 0.70, 0.88, 0.30, 0.88]),
		_lin("l", [0.34, 0.74, 0.66, 0.74]),
	]


# T3: el farol LABRADO de luz azul: la anilla, el tejado con los aleros vueltos y el cristal azul con
# un destello por fuera.
static func _farol_3() -> Array:
	return [
		_elipse("b", 0.50, 0.06, 0.05, 0.045, 10),
		_elipse(".", 0.50, 0.06, 0.02, 0.02, 6),
		_tira("b", [0.50, 0.10, 0.50, 0.18], 0.04, 0.04),
		_pol("s", [0.14, 0.34, 0.26, 0.28, 0.36, 0.18, 0.64, 0.18, 0.74, 0.28, 0.86, 0.34, 0.74, 0.34]),
		_pol("l", [0.26, 0.28, 0.36, 0.20, 0.64, 0.20, 0.50, 0.26]),
		_pol("b", [0.28, 0.34, 0.72, 0.34, 0.72, 0.78, 0.28, 0.78]),
		_pol("q", [0.32, 0.38, 0.68, 0.38, 0.68, 0.74, 0.32, 0.74]),
		_pol("C", [0.34, 0.44, 0.66, 0.44, 0.66, 0.72, 0.34, 0.72]),
		_elipse("Q", 0.46, 0.58, 0.07, 0.09, 10),
		_lin("b", [0.50, 0.38, 0.50, 0.74]),
		_lin("q", [0.34, 0.44, 0.50, 0.40, 0.66, 0.44]),
		_pol("s", [0.24, 0.78, 0.76, 0.78, 0.76, 0.84, 0.24, 0.84]),
		_pol("d", [0.20, 0.84, 0.80, 0.84, 0.80, 0.90, 0.20, 0.90]),
		{"l": P([0.14, 0.52, 0.14, 0.52]), "t": "Q", "libre": true},
		{"l": P([0.86, 0.60, 0.86, 0.60]), "t": "C", "libre": true},
	]


# ============================================================
#  LOS SUELTOS
# ============================================================
# EL POLVO DE ALAS: un saquito atado, del color del polvo, con brillos saliendo por la boca.
static func _saquito() -> Array:
	return [
		_pol("b", [0.26, 0.46, 0.36, 0.34, 0.64, 0.34, 0.74, 0.46, 0.80, 0.66, 0.74, 0.84, 0.26, 0.84,
			0.20, 0.66]),
		_sobre(_pol("s", [0.60, 0.40, 0.74, 0.46, 0.80, 0.66, 0.74, 0.84, 0.56, 0.84])),
		_sobre(_elipse("l", 0.38, 0.56, 0.08, 0.10, 12)),
		_pol("b", [0.38, 0.34, 0.44, 0.24, 0.56, 0.24, 0.62, 0.34]),
		_tira("k", [0.34, 0.36, 0.66, 0.36], 0.04, 0.04),
		_elipse("W", 0.50, 0.14, 0.02, 0.02, 4),
		_elipse("h", 0.40, 0.10, 0.015, 0.015, 4),
		_elipse("h", 0.60, 0.16, 0.015, 0.015, 4),
		_elipse("W", 0.66, 0.06, 0.015, 0.015, 4),
	]


# LAS ESPORAS DENSAS: una nube de bolitas apretadas, con alguna suelta flotando.
static func _esporas() -> Array:
	var out: Array = []
	for b in [[0.36, 0.60, 0.13], [0.60, 0.62, 0.14], [0.48, 0.44, 0.15], [0.30, 0.44, 0.09],
			[0.68, 0.44, 0.10], [0.50, 0.72, 0.10]]:
		out.append(_elipse("s", b[0], b[1], b[2], b[2], 14))
		out.append(_sobre(_elipse("b", b[0] - 0.02, b[1] - 0.02, b[2] * 0.8, b[2] * 0.8, 12)))
		out.append(_sobre(_elipse("l", b[0] - 0.04, b[1] - 0.04, b[2] * 0.35, b[2] * 0.35, 8)))
	for m in [[0.20, 0.26], [0.78, 0.24], [0.84, 0.66], [0.16, 0.72]]:
		out.append(_elipse("b", m[0], m[1], 0.025, 0.025, 6))
	return out


# EL FRASQUITO: tapon de corcho, cuello, y la panza de cristal con el liquido de su color dentro.
static func _frasquito() -> Array:
	return [
		_pol("u", [0.42, 0.10, 0.58, 0.10, 0.58, 0.20, 0.42, 0.20]),
		_lin("j", [0.44, 0.12, 0.56, 0.12]),
		_pol("x", [0.42, 0.20, 0.58, 0.20, 0.58, 0.32, 0.42, 0.32]),
		_elipse("x", 0.50, 0.60, 0.27, 0.28, 24),
		_sobre(_elipse("b", 0.50, 0.63, 0.23, 0.23, 22)),
		_sobre(_pol("w", [0.20, 0.30, 0.80, 0.30, 0.80, 0.46, 0.20, 0.46])),
		_sobre(_pol("s", [0.20, 0.70, 0.80, 0.70, 0.80, 0.92, 0.20, 0.92])),
		_sobre(_pol("l", [0.26, 0.46, 0.74, 0.46, 0.74, 0.50, 0.26, 0.50])),
		_lin("W", [0.34, 0.52, 0.32, 0.66]),
	]


# ============================================================
#  LAS POCIONES: un frasco por tier
# ============================================================
# Nueve frascos, como la cuadricula de referencia del jefe: probeta, lagrima, matraz, cuello largo,
# gema, hexagonal, bola grande, cuenco y cuadrado. El TIER elige el frasco (del T10 vuelve a empezar);
# el +N lo agranda un poco (+0 al 80 %, +3 entero), asi dos pociones del mismo tier se distinguen
# tambien por el bulto. Van un poco inclinadas, como en la referencia.
#
# Cada frasco es: el VIDRIO (la silueta), el LIQUIDO dentro hasta su nivel, el tapon de corcho, el
# reflejo del cristal y un par de burbujas.
const POCION_GIRO := -0.38

static func _pocion(forma: int, plus: int) -> Array:
	var cuerpo: Array = []    # la panza de vidrio (poligono o elipse)
	var cuello: Array = [0.45, 0.20, 0.55, 0.20, 0.55, 0.38, 0.45, 0.38]
	var nivel: float = 0.50   # por donde va el liquido
	match forma:
		0:   # probeta
			cuerpo = [_elipse("T", 0.50, 0.74, 0.10, 0.10, 14), _pol("T", [0.40, 0.24, 0.60, 0.24, 0.60, 0.74, 0.40, 0.74])]
			cuello = [0.40, 0.20, 0.60, 0.20, 0.60, 0.26, 0.40, 0.26]
			nivel = 0.40
		1:   # lagrima
			cuerpo = [_elipse("T", 0.50, 0.66, 0.21, 0.21, 20), _pol("T", [0.44, 0.36, 0.56, 0.36, 0.70, 0.60, 0.30, 0.60])]
			nivel = 0.54
		2:   # matraz redondo
			cuerpo = [_elipse("T", 0.50, 0.64, 0.25, 0.25, 22)]
		3:   # cuello largo
			cuerpo = [_elipse("T", 0.50, 0.68, 0.22, 0.22, 22)]
			cuello = [0.46, 0.14, 0.54, 0.14, 0.54, 0.48, 0.46, 0.48]
			nivel = 0.58
		4:   # gema
			cuerpo = [_pol("T", [0.50, 0.36, 0.72, 0.50, 0.66, 0.78, 0.50, 0.88, 0.34, 0.78, 0.28, 0.50])]
			nivel = 0.56
		5:   # hexagonal
			cuerpo = [_pol("T", [0.38, 0.38, 0.62, 0.38, 0.76, 0.58, 0.64, 0.84, 0.36, 0.84, 0.24, 0.58])]
			nivel = 0.54
		6:   # bola grande
			cuerpo = [_elipse("T", 0.50, 0.62, 0.30, 0.29, 24)]
			cuello = [0.45, 0.16, 0.55, 0.16, 0.55, 0.34, 0.45, 0.34]
			nivel = 0.48
		7:   # cuenco ancho
			cuerpo = [_elipse("T", 0.50, 0.68, 0.32, 0.22, 24)]
			cuello = [0.45, 0.24, 0.55, 0.24, 0.55, 0.48, 0.45, 0.48]
			nivel = 0.60
		_:   # cuadrado
			cuerpo = [_pol("T", [0.26, 0.40, 0.74, 0.40, 0.76, 0.86, 0.24, 0.86])]
			nivel = 0.52
	var out: Array = []
	out.append(_pol("T", cuello))
	out.append_array(cuerpo)
	# el liquido hasta su nivel, con la sombra abajo y la superficie en luz
	out.append(_sobre(_pol("b", [0.0, nivel, 1.0, nivel, 1.0, 1.0, 0.0, 1.0])))
	out.append(_sobre(_pol("s", [0.0, nivel + 0.22, 1.0, nivel + 0.22, 1.0, 1.0, 0.0, 1.0])))
	out.append(_sobre(_pol("l", [0.0, nivel, 1.0, nivel, 1.0, nivel + 0.03, 0.0, nivel + 0.03])))
	out.append(_sobre(_elipse("h", 0.58, nivel + 0.12, 0.025, 0.025, 6)))
	out.append(_sobre(_elipse("h", 0.46, nivel + 0.20, 0.018, 0.018, 6)))
	# el reflejo del cristal, a la izquierda, de arriba abajo de la panza
	out.append(_lin("W", [0.36, nivel - 0.06, 0.34, nivel + 0.14]))
	# el tapon
	var c0: float = cuello[1] - 0.08
	out.append(_pol("u", [0.43, c0, 0.57, c0, 0.58, cuello[1] + 0.02, 0.42, cuello[1] + 0.02]))
	out.append(_lin("j", [0.45, c0 + 0.02, 0.55, c0 + 0.02]))
	# EL +N AGRANDA Y TODO SE INCLINA: se escala y se gira cada punto alrededor del centro del frasco.
	return _transformar(out, 0.80 + 0.066 * float(plus), POCION_GIRO, Vector2(0.5, 0.56))


# Escala y gira una forma entera alrededor de 'c' (sirve para inclinar y agrandar sin redibujar).
static func _transformar(pasos: Array, esc: float, ang: float, c: Vector2) -> Array:
	var out: Array = []
	for paso in pasos:
		var nuevo: Dictionary = paso.duplicate()
		var clave: String = "p" if paso.has("p") else "l"
		var pts := PackedVector2Array()
		for q in paso[clave]:
			pts.append(c + ((q as Vector2) - c).rotated(ang) * esc)
		nuevo[clave] = pts
		out.append(nuevo)
	return out


# LA PIEDRA DE RETORNO: un monolito de piedra agrietada sobre su losa, con la RUNA encendida en azul
# (la referencia del jefe). El simbolo de la runa es el del jefe del tramo (ver RUNA_DE_TRAMO).
static func _piedra(simbolo: String) -> Array:
	var out: Array = [
		# la losa y las piedras del pie
		_pol("d", [0.10, 0.84, 0.18, 0.78, 0.82, 0.78, 0.90, 0.84, 0.84, 0.92, 0.16, 0.92]),
		_lin("s", [0.16, 0.80, 0.84, 0.80]),
		_elipse("s", 0.24, 0.78, 0.07, 0.04, 10), _elipse("s", 0.76, 0.79, 0.08, 0.04, 10),
		# el monolito, en caras
		_pol("s", [0.26, 0.78, 0.22, 0.44, 0.30, 0.16, 0.50, 0.08, 0.70, 0.14, 0.78, 0.40, 0.74, 0.78]),
		_pol("l", [0.26, 0.78, 0.22, 0.44, 0.30, 0.16, 0.50, 0.08, 0.46, 0.40, 0.40, 0.78]),
		_pol("h", [0.30, 0.16, 0.50, 0.08, 0.70, 0.14, 0.48, 0.20]),
		_lin("o", [0.46, 0.20, 0.44, 0.40, 0.48, 0.60]),
		_lin("o", [0.66, 0.22, 0.62, 0.36]),
		_lin("o", [0.30, 0.56, 0.36, 0.66]),
	]
	# LA RUNA: primero el halo, luego el trazo encendido
	var trazos: Array = []
	match simbolo:
		"corona":
			trazos = [[0.36, 0.54, 0.36, 0.34, 0.44, 0.44, 0.52, 0.28, 0.60, 0.44, 0.66, 0.34, 0.66, 0.54],
				[0.36, 0.56, 0.66, 0.56], [0.38, 0.62, 0.64, 0.62]]
		"cuernos":
			trazos = [[0.44, 0.44, 0.34, 0.38, 0.30, 0.26, 0.34, 0.22],
				[0.60, 0.44, 0.70, 0.38, 0.74, 0.26, 0.70, 0.22],
				[0.44, 0.44, 0.46, 0.60, 0.52, 0.66, 0.58, 0.60, 0.60, 0.44, 0.44, 0.44],
				[0.50, 0.52, 0.54, 0.52]]
	for tz in trazos:
		out.append(_tira("C", tz, 0.07, 0.07))
	for tz in trazos:
		out.append(_lin("Q", tz))
	out.append({"l": P([0.16, 0.30, 0.16, 0.30]), "t": "Q", "libre": true})
	out.append({"l": P([0.86, 0.54, 0.86, 0.54]), "t": "C", "libre": true})
	return out


# EL CEBO DE GUSANO: una lombriz rosa enroscada, a anillos.
static func _gusano() -> Array:
	var cuerpo: Array = [0.16, 0.66, 0.26, 0.48, 0.44, 0.44, 0.56, 0.58, 0.70, 0.66, 0.82, 0.54, 0.84, 0.38]
	var out: Array = [_tira("b", cuerpo, 0.12, 0.09), _tira("l", [0.18, 0.62, 0.27, 0.46, 0.44, 0.41,
		0.56, 0.55, 0.70, 0.62, 0.80, 0.52], 0.03, 0.02)]
	for a in [[0.24, 0.52, 0.30, 0.54], [0.38, 0.44, 0.40, 0.50], [0.52, 0.52, 0.56, 0.56],
			[0.66, 0.62, 0.68, 0.68], [0.78, 0.56, 0.84, 0.58]]:
		out.append(_lin("s", a))
	out.append(_elipse("s", 0.84, 0.36, 0.035, 0.035, 8))
	return out


# EL CEBO DE SANGUIJUELA: una sanguijuela gorda y oscura, brillante, con su ventosa.
static func _sanguijuela() -> Array:
	return [
		_tira("b", [0.14, 0.70, 0.30, 0.50, 0.52, 0.44, 0.72, 0.50, 0.86, 0.36], 0.16, 0.10),
		_tira("l", [0.18, 0.64, 0.31, 0.46, 0.52, 0.40, 0.70, 0.44], 0.04, 0.03),
		_lin("d", [0.26, 0.60, 0.32, 0.62]), _lin("d", [0.42, 0.50, 0.44, 0.56]),
		_lin("d", [0.58, 0.48, 0.60, 0.54]), _lin("d", [0.72, 0.46, 0.76, 0.50]),
		_elipse("d", 0.14, 0.72, 0.07, 0.06, 10),
		_elipse("R", 0.14, 0.72, 0.03, 0.03, 6),
		_lin("W", [0.44, 0.42, 0.50, 0.40]),
	]


# ============================================================
#  LA CARNE (las referencias del jefe)
# ============================================================
# LA DE RATA: un muslito, la carne gorda arriba y el hueso con su nudo abajo.
static func _muslo() -> Array:
	return [
		_tira("I", [0.46, 0.54, 0.22, 0.80], 0.09, 0.08),
		_elipse("I", 0.17, 0.80, 0.05, 0.05, 8), _elipse("I", 0.22, 0.86, 0.05, 0.05, 8),
		_lin("i", [0.40, 0.62, 0.24, 0.80]),
		_elipse("b", 0.60, 0.40, 0.26, 0.24, 22),
		_sobre(_elipse("s", 0.64, 0.46, 0.22, 0.20, 18)),
		_sobre(_elipse("b", 0.58, 0.38, 0.19, 0.17, 18)),
		_sobre(_elipse("l", 0.54, 0.32, 0.10, 0.07, 12)),
		_lin("h", [0.50, 0.28, 0.58, 0.26]),
	]


# LA DE JABALI: un jamon con su piel, el corte rojo con la veta de grasa y el hueso asomando.
static func _jamon() -> Array:
	return [
		_tira("I", [0.30, 0.66, 0.12, 0.86], 0.08, 0.07),
		_elipse("I", 0.10, 0.88, 0.05, 0.05, 8),
		_pol("s", [0.24, 0.62, 0.34, 0.36, 0.52, 0.18, 0.72, 0.14, 0.88, 0.26, 0.90, 0.46, 0.76, 0.64,
			0.52, 0.74, 0.34, 0.74]),
		_sobre(_pol("d", [0.30, 0.70, 0.52, 0.72, 0.76, 0.62, 0.90, 0.46, 0.90, 0.60, 0.74, 0.76, 0.40, 0.80])),
		_elipse("P", 0.70, 0.32, 0.18, 0.15, 18),
		_sobre(_elipse("b", 0.70, 0.32, 0.14, 0.11, 16)),
		_sobre(_elipse("l", 0.66, 0.29, 0.06, 0.04, 10)),
		_elipse("I", 0.72, 0.34, 0.03, 0.03, 6),
		_lin("l", [0.38, 0.40, 0.50, 0.26]),
	]


# LA DE BESTIA: un chuleton gordo en perspectiva, veteado de grasa, con el hueso en T y el canto.
static func _chuleton() -> Array:
	return [
		_pol("d", [0.12, 0.54, 0.20, 0.34, 0.40, 0.20, 0.66, 0.18, 0.86, 0.30, 0.90, 0.52, 0.74, 0.72,
			0.44, 0.78, 0.20, 0.72]),
		_pol("b", [0.12, 0.48, 0.20, 0.28, 0.40, 0.14, 0.66, 0.12, 0.86, 0.24, 0.90, 0.44, 0.74, 0.62,
			0.44, 0.68, 0.20, 0.64]),
		_lin("P", [0.14, 0.48, 0.22, 0.30, 0.40, 0.16]),
		_lin("P", [0.22, 0.64, 0.44, 0.68, 0.72, 0.62]),
		_lin("l", [0.30, 0.34, 0.44, 0.40, 0.52, 0.34]),
		_lin("l", [0.58, 0.46, 0.70, 0.40, 0.78, 0.44]),
		_lin("l", [0.34, 0.52, 0.42, 0.56]),
		_lin("I", [0.50, 0.16, 0.54, 0.40, 0.46, 0.62]),
		_lin("I", [0.36, 0.40, 0.54, 0.40, 0.70, 0.36]),
		_lin("h", [0.62, 0.20, 0.72, 0.22]),
	]


# LA DE INSECTO (sin referencia: la carne de insecto no la tiene nadie): una pata de caparazon, a
# segmentos, abierta por la punta con la carne clara asomando -- como una pata de cangrejo.
static func _pata_insecto() -> Array:
	return [
		_tira("s", [0.14, 0.86, 0.34, 0.62], 0.16, 0.14),
		_tira("s", [0.36, 0.60, 0.58, 0.40], 0.15, 0.13),
		_tira("s", [0.60, 0.38, 0.78, 0.22], 0.14, 0.12),
		_elipse("d", 0.35, 0.61, 0.06, 0.06, 10),
		_elipse("d", 0.59, 0.39, 0.055, 0.055, 10),
		_lin("l", [0.14, 0.80, 0.30, 0.60]),
		_lin("l", [0.38, 0.54, 0.54, 0.38]),
		_lin("l", [0.62, 0.32, 0.74, 0.20]),
		_elipse("b", 0.80, 0.20, 0.09, 0.08, 12),
		_elipse("W", 0.79, 0.18, 0.03, 0.03, 6),
	]


# ============================================================
#  LA DESPENSA (la referencia de verduras del jefe, y el resto de la alacena)
# ============================================================
static func _despensa(id: String) -> Array:
	match id:
		"tomate":
			return [
				_elipse("b", 0.50, 0.56, 0.32, 0.28, 24),
				_sobre(_elipse("s", 0.55, 0.62, 0.28, 0.24, 22)),
				_sobre(_elipse("b", 0.47, 0.52, 0.24, 0.20, 20)),
				_sobre(_elipse("h", 0.36, 0.46, 0.05, 0.04, 8)),
				_pol("F", [0.34, 0.30, 0.44, 0.32, 0.50, 0.22, 0.56, 0.32, 0.66, 0.30, 0.58, 0.38, 0.50, 0.36, 0.42, 0.38]),
				_tira("f", [0.50, 0.30, 0.52, 0.18], 0.04, 0.03),
			]
		"pimiento":
			return [
				_pol("b", [0.26, 0.34, 0.40, 0.28, 0.50, 0.32, 0.60, 0.28, 0.74, 0.34, 0.76, 0.60, 0.70, 0.84,
					0.58, 0.90, 0.50, 0.84, 0.42, 0.90, 0.30, 0.84, 0.24, 0.60]),
				_sobre(_pol("s", [0.58, 0.30, 0.76, 0.34, 0.78, 0.60, 0.70, 0.86, 0.56, 0.90])),
				_lin("d", [0.50, 0.36, 0.50, 0.80]),
				_sobre(_pol("h", [0.32, 0.40, 0.36, 0.38, 0.38, 0.62, 0.34, 0.64])),
				_tira("f", [0.50, 0.30, 0.54, 0.14, 0.62, 0.10], 0.06, 0.04),
				_pol("F", [0.40, 0.30, 0.60, 0.30, 0.56, 0.34, 0.44, 0.34]),
			]
		"zanahoria":
			return [
				_pol("F", [0.66, 0.30, 0.70, 0.08, 0.76, 0.26]),
				_pol("F", [0.70, 0.32, 0.88, 0.12, 0.84, 0.30]),
				_pol("f", [0.72, 0.34, 0.92, 0.30, 0.82, 0.38]),
				_tira("b", [0.72, 0.34, 0.16, 0.88], 0.20, 0.03),
				_tira("l", [0.66, 0.34, 0.20, 0.82], 0.05, 0.01),
				_lin("s", [0.54, 0.44, 0.60, 0.50]),
				_lin("s", [0.42, 0.56, 0.48, 0.62]),
				_lin("s", [0.30, 0.68, 0.35, 0.72]),
			]
		"patata":
			return [
				_pol("b", [0.16, 0.50, 0.24, 0.32, 0.44, 0.24, 0.66, 0.26, 0.84, 0.38, 0.86, 0.58, 0.72, 0.74,
					0.48, 0.78, 0.26, 0.72]),
				_sobre(_pol("s", [0.20, 0.64, 0.50, 0.70, 0.80, 0.60, 0.86, 0.60, 0.72, 0.76, 0.48, 0.80, 0.24, 0.74])),
				_sobre(_elipse("l", 0.40, 0.36, 0.14, 0.06, 12)),
				_elipse("d", 0.36, 0.50, 0.02, 0.02, 4), _elipse("d", 0.60, 0.44, 0.02, 0.02, 4),
				_elipse("d", 0.66, 0.62, 0.02, 0.02, 4), _elipse("d", 0.44, 0.64, 0.015, 0.015, 4),
			]
		"cebolla", "ajo":
			var ajo: bool = id == "ajo"
			var out: Array = [
				_tira("f" if not ajo else "s", [0.50, 0.30, 0.48, 0.10], 0.06, 0.02),
				_pol("b", [0.50, 0.26, 0.70, 0.40, 0.78, 0.60, 0.70, 0.80, 0.50, 0.86, 0.30, 0.80, 0.22, 0.60, 0.30, 0.40]),
				_sobre(_pol("s", [0.56, 0.30, 0.74, 0.44, 0.78, 0.62, 0.70, 0.82, 0.56, 0.86])),
				_sobre(_pol("l", [0.34, 0.44, 0.40, 0.38, 0.42, 0.66, 0.36, 0.70])),
				_lin("s", [0.50, 0.30, 0.46, 0.60, 0.50, 0.84]),
				_lin("s", [0.40, 0.40, 0.34, 0.62, 0.40, 0.80]),
				_lin("s", [0.62, 0.40, 0.66, 0.62, 0.60, 0.80]),
				_lin("x", [0.44, 0.88, 0.50, 0.92, 0.56, 0.88]),
			]
			return out
		"lechuga":
			return [
				_elipse("s", 0.50, 0.56, 0.34, 0.30, 24),
				_sobre(_elipse("b", 0.47, 0.52, 0.30, 0.26, 22)),
				_elipse("s", 0.28, 0.46, 0.12, 0.12, 12), _elipse("s", 0.72, 0.46, 0.12, 0.12, 12),
				_elipse("b", 0.50, 0.40, 0.18, 0.14, 16),
				_sobre(_elipse("l", 0.46, 0.36, 0.10, 0.07, 12)),
				_lin("l", [0.50, 0.46, 0.50, 0.78]),
				_lin("l", [0.50, 0.60, 0.34, 0.50]),
				_lin("l", [0.50, 0.62, 0.66, 0.52]),
			]
		"puerro_gruta":
			return [
				_tira("w", [0.20, 0.86, 0.50, 0.50], 0.16, 0.15),
				_tira("x", [0.24, 0.88, 0.52, 0.54], 0.05, 0.05),
				_lin("x", [0.16, 0.90, 0.22, 0.94]),
				_pol("b", [0.44, 0.52, 0.56, 0.44, 0.84, 0.08, 0.86, 0.18, 0.62, 0.50]),
				_pol("s", [0.48, 0.50, 0.58, 0.42, 0.70, 0.10, 0.74, 0.16, 0.60, 0.48]),
				_pol("l", [0.52, 0.48, 0.60, 0.44, 0.92, 0.30, 0.90, 0.38, 0.62, 0.52]),
			]
		"tuberculo_palido":
			return [
				_pol("F", [0.40, 0.28, 0.34, 0.08, 0.46, 0.24]),
				_pol("F", [0.50, 0.26, 0.50, 0.04, 0.56, 0.22]),
				_pol("f", [0.58, 0.28, 0.68, 0.10, 0.62, 0.30]),
				_elipse("b", 0.50, 0.52, 0.28, 0.26, 22),
				_sobre(_pol("P", [0.0, 0.0, 1.0, 0.0, 1.0, 0.40, 0.0, 0.40])),
				_sobre(_elipse("s", 0.56, 0.58, 0.22, 0.20, 18)),
				_sobre(_elipse("b", 0.48, 0.52, 0.18, 0.16, 16)),
				_tira("s", [0.50, 0.76, 0.52, 0.94], 0.05, 0.01),
			]
		"seta_simas":
			return [
				_pol("w", [0.42, 0.50, 0.58, 0.50, 0.62, 0.86, 0.38, 0.86]),
				_pol("x", [0.52, 0.50, 0.58, 0.50, 0.62, 0.86, 0.52, 0.86]),
				_pol("b", [0.14, 0.54, 0.18, 0.36, 0.32, 0.20, 0.50, 0.14, 0.68, 0.20, 0.82, 0.36, 0.86, 0.54]),
				_sobre(_pol("s", [0.60, 0.18, 0.82, 0.36, 0.86, 0.54, 0.62, 0.54])),
				_sobre(_elipse("l", 0.38, 0.30, 0.10, 0.06, 12)),
				_lin("d", [0.16, 0.54, 0.84, 0.54]),
			]
		"hongo_azufre":
			var h_out: Array = []
			for rep in [[0.50, 0.30, 0.24], [0.44, 0.52, 0.30], [0.54, 0.74, 0.26]]:
				h_out.append(_elipse("s", rep[0], rep[1] + 0.03, rep[2], rep[2] * 0.40, 18))
				h_out.append(_elipse("b", rep[0] - 0.02, rep[1], rep[2] * 0.92, rep[2] * 0.34, 18))
				h_out.append(_lin("h", [rep[0] - rep[2] * 0.6, rep[1] - 0.02, rep[0] + rep[2] * 0.2, rep[1] - 0.05]))
				h_out.append(_lin("d", [rep[0] - rep[2] * 0.8, rep[1] + 0.05, rep[0] + rep[2] * 0.8, rep[1] + 0.05]))
			return h_out
		"pan":
			return [
				_elipse("s", 0.50, 0.58, 0.38, 0.24, 24),
				_sobre(_elipse("b", 0.48, 0.54, 0.34, 0.20, 22)),
				_sobre(_elipse("l", 0.44, 0.48, 0.24, 0.10, 18)),
				_lin("h", [0.30, 0.48, 0.38, 0.40]),
				_lin("h", [0.44, 0.50, 0.52, 0.40]),
				_lin("h", [0.58, 0.52, 0.66, 0.42]),
				_lin("d", [0.18, 0.66, 0.50, 0.78, 0.82, 0.66]),
			]
		"queso":
			return [
				_pol("s", [0.14, 0.60, 0.86, 0.46, 0.86, 0.74, 0.14, 0.86]),
				_pol("b", [0.14, 0.60, 0.62, 0.22, 0.86, 0.46]),
				_sobre(_pol("l", [0.20, 0.58, 0.60, 0.26, 0.64, 0.30, 0.26, 0.60])),
				_sobre(_elipse("d", 0.40, 0.68, 0.04, 0.035, 8)),
				_sobre(_elipse("d", 0.64, 0.64, 0.05, 0.04, 8)),
				_sobre(_elipse("d", 0.26, 0.78, 0.03, 0.03, 6)),
				_sobre(_elipse("s", 0.56, 0.40, 0.04, 0.03, 8)),
				_sobre(_elipse("s", 0.72, 0.46, 0.03, 0.025, 6)),
			]
		"aceite":
			return [
				_pol("u", [0.43, 0.08, 0.57, 0.08, 0.58, 0.18, 0.42, 0.18]),
				_pol("T", [0.44, 0.18, 0.56, 0.18, 0.56, 0.30, 0.44, 0.30]),
				_pol("T", [0.36, 0.30, 0.64, 0.30, 0.74, 0.46, 0.72, 0.84, 0.28, 0.84, 0.26, 0.46]),
				_sobre(_pol("b", [0.0, 0.46, 1.0, 0.46, 1.0, 1.0, 0.0, 1.0])),
				_sobre(_pol("s", [0.0, 0.70, 1.0, 0.70, 1.0, 1.0, 0.0, 1.0])),
				_sobre(_pol("l", [0.0, 0.46, 1.0, 0.46, 1.0, 0.49, 0.0, 0.49])),
				_lin("W", [0.34, 0.40, 0.33, 0.62]),
				_tira("k", [0.30, 0.56, 0.70, 0.56], 0.04, 0.04),
			]
		"piedra_sal":
			return [
				_pol("s", [0.14, 0.66, 0.30, 0.40, 0.56, 0.30, 0.80, 0.40, 0.88, 0.66, 0.66, 0.84, 0.34, 0.84]),
				_pol("h", [0.30, 0.40, 0.56, 0.30, 0.80, 0.40, 0.56, 0.52]),
				_pol("b", [0.14, 0.66, 0.30, 0.40, 0.56, 0.52, 0.52, 0.80, 0.34, 0.84]),
				_pol("l", [0.56, 0.52, 0.80, 0.40, 0.88, 0.66, 0.66, 0.84, 0.52, 0.80]),
				_lin("W", [0.36, 0.42, 0.50, 0.36]),
				_elipse("W", 0.24, 0.28, 0.015, 0.015, 4),
			]
	return []


# LA BABA: una cupula de gelatina con el pie plano, el brillo arriba a la izquierda y el borde de abajo
# en sombra, con los dos bultitos del pie a los lados (la referencia del jefe). La de FUEGO es la misma
# cupula hecha de LAVA: placas oscuras con las juntas encendidas.
static func _baba(lava: bool) -> Array:
	var cupula: Array = [0.14, 0.80, 0.15, 0.62, 0.22, 0.46, 0.34, 0.35, 0.50, 0.31, 0.66, 0.35,
		0.78, 0.46, 0.85, 0.62, 0.86, 0.80]
	var out: Array = [
		_pol("s", [0.06, 0.82, 0.12, 0.72, 0.18, 0.82]),
		_pol("s", [0.82, 0.82, 0.88, 0.72, 0.94, 0.82]),
	]
	if lava:
		out.append(_pol("L", cupula))
		for pl in [[0.24, 0.52, 0.34, 0.40, 0.46, 0.42, 0.42, 0.56, 0.28, 0.60],
				[0.50, 0.38, 0.64, 0.38, 0.72, 0.50, 0.58, 0.54],
				[0.20, 0.66, 0.36, 0.64, 0.40, 0.78, 0.18, 0.78],
				[0.46, 0.60, 0.62, 0.60, 0.66, 0.78, 0.44, 0.78],
				[0.70, 0.56, 0.82, 0.60, 0.82, 0.78, 0.72, 0.78]]:
			out.append(_sobre({"p": P(pl), "t": "d"}))
		out.append(_lin("K", [0.42, 0.58, 0.46, 0.44, 0.50, 0.40]))
		out.append(_lin("K", [0.40, 0.62, 0.44, 0.76]))
		return out
	out.append(_pol("b", cupula))
	out.append(_sobre(_pol("s", [0.10, 0.70, 0.90, 0.70, 0.90, 0.84, 0.10, 0.84])))
	out.append(_sobre(_pol("d", [0.10, 0.77, 0.90, 0.77, 0.90, 0.84, 0.10, 0.84])))
	out.append(_sobre(_elipse("l", 0.42, 0.46, 0.20, 0.10, 16)))
	out.append(_sobre(_pol("h", [0.30, 0.46, 0.34, 0.40, 0.44, 0.36, 0.46, 0.39, 0.36, 0.44])))
	out.append(_sobre(_elipse("W", 0.30, 0.52, 0.02, 0.02, 4)))
	out.append(_sobre(_elipse("h", 0.64, 0.56, 0.025, 0.025, 6)))
	return out


# EL CARBON MINERAL: como un mineral pero NEGRO y con otra forma (lo pidio el jefe): no un pedrusco
# sino un MONTON de terrones tallados, con los cantos brillantes que tiene el carbon de verdad.
static func _carbon() -> Array:
	var out: Array = []
	for t in [
			# [x, y, escala] de cada terron, de atras adelante
			[0.62, 0.40, 0.95], [0.34, 0.46, 0.90], [0.52, 0.66, 1.0], [0.24, 0.72, 0.60], [0.80, 0.72, 0.55]]:
		var x: float = t[0]
		var y: float = t[1]
		var k: float = float(t[2]) * 0.20
		out.append(_pol("s", [x - k, y + k * 0.3, x - k * 0.6, y - k * 0.8, x + k * 0.3, y - k, x + k,
			y - k * 0.2, x + k * 0.8, y + k * 0.8, x - k * 0.2, y + k]))
		out.append(_pol("l", [x - k, y + k * 0.3, x - k * 0.6, y - k * 0.8, x + k * 0.3, y - k, x, y]))
		out.append(_pol("b", [x, y, x + k * 0.3, y - k, x + k, y - k * 0.2]))
		out.append(_lin("h", [x - k * 0.55, y - k * 0.7, x + k * 0.25, y - k * 0.92]))
	return out


# EL CARBON DE MADERA: dos palos carbonizados, con el corte negro agrietado y alguna brasa: es madera
# quemada, no piedra, y a primera vista tiene que notarse la diferencia con el mineral.
static func _carbon_vegetal() -> Array:
	var out: Array = []
	for pal in [[0.20, 0.44, 0.78, 0.30], [0.16, 0.72, 0.80, 0.56]]:
		out.append(_tira("b", [pal[0], pal[1], pal[2], pal[3]], 0.20, 0.18))
		out.append(_tira("l", [pal[0] + 0.02, pal[1] - 0.06, pal[2], pal[3] - 0.06], 0.05, 0.04))
		out.append(_elipse("s", pal[0], pal[1], 0.09, 0.10, 12))
		out.append(_elipse("d", pal[0], pal[1], 0.05, 0.06, 10))
		out.append(_lin("o", [pal[0] + 0.14, pal[1] - 0.03, pal[0] + 0.30, pal[1] - 0.06]))
		out.append(_lin("o", [pal[0] + 0.30, pal[1] + 0.02, pal[0] + 0.46, pal[1] - 0.02]))
	out.append(_elipse("L", 0.62, 0.60, 0.02, 0.02, 6))
	out.append(_elipse("K", 0.40, 0.38, 0.015, 0.015, 4))
	return out


# ============================================================
#  LAS PLANTAS: el mismo dibujo que tienen en el suelo
# ============================================================
# Se juntan las dos capas del nodo del mapa (el cuerpo, con un lavado del color, y el fruto, con el
# color a saco -- exactamente como las pinta resource_node), se recorta a lo que ocupa y se le echan
# las grietas del estado. Queda una imagen de colores que se pinta por rachas como el resto.
static var _cache_imagen: Dictionary = {}

static func _imagen_planta(idx: int, col: Color, grietas: int) -> Image:
	var clave: String = "%d|%s|%d" % [idx, col.to_html(), grietas]
	if _cache_imagen.has(clave):
		return _cache_imagen[clave]
	var cuerpo: Image = RecolectableSprites.textura("planta", idx, 0, false).get_image()
	var fruto: Image = RecolectableSprites.textura("planta", idx, 0, true).get_image()
	var lavado: Color = RecolectableSprites.tinte_cuerpo(col)
	var w: int = cuerpo.get_width()
	var h: int = cuerpo.get_height()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var x0: int = w
	var y0: int = h
	var x1: int = -1
	var y1: int = -1
	for y in h:
		for x in w:
			var f: Color = fruto.get_pixel(x, y)
			var c: Color = cuerpo.get_pixel(x, y)
			var px: Color = Color(0, 0, 0, 0)
			if f.a > 0.5:
				px = f * col
				px.a = 1.0
			elif c.a > 0.5:
				px = c * lavado
				px.a = 1.0
			img.set_pixel(x, y, px)
			if px.a > 0.0:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	if x1 < 0:
		return img
	var rec: Image = img.get_region(Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1))
	_grietas_imagen(rec, grietas)
	_cache_imagen[clave] = rec
	return rec


# EL PEZ: un fotograma quieto de su sprite de pesca, de talla media, recortado a lo que ocupa.
static func _imagen_pez(d: MaterialData, col: Color, grietas: int) -> Image:
	var clave: String = "pez|%s|%s|%d" % [d.id, col.to_html(), grietas]
	if _cache_imagen.has(clave):
		return _cache_imagen[clave]
	var talla: int = PezSprites.talla_de(26.0)
	var t: Vector2i = PezSprites.lienzo(talla)
	var img: Image = SpriteLienzo.a_textura(PezSprites._plantilla(d, talla, 0), PezSprites.paleta(col),
		t.x, t.y).get_image()
	var uso: Rect2i = img.get_used_rect()
	var rec: Image = img.get_region(uso) if uso.size.x > 0 else img
	_grietas_imagen(rec, grietas)
	_cache_imagen[clave] = rec
	return rec


# LAS GRIETAS sobre una imagen, solo donde hay algo pintado (las mismas lineas que en todo lo demas).
static func _grietas_imagen(rec: Image, grietas: int) -> void:
	for g in mini(grietas, GRIETAS.size()):
		var pts: PackedVector2Array = P(GRIETAS[g])
		for i in pts.size() - 1:
			var a: Vector2 = pts[i] * Vector2(rec.get_size())
			var b: Vector2 = pts[i + 1] * Vector2(rec.get_size())
			var pasos: int = maxi(1, int(ceil(a.distance_to(b) * 2.0)))
			for k in pasos + 1:
				var p: Vector2 = a.lerp(b, float(k) / float(pasos))
				var xi: int = clampi(int(p.x), 0, rec.get_width() - 1)
				var yi: int = clampi(int(p.y), 0, rec.get_height() - 1)
				var o: Color = rec.get_pixel(xi, yi)
				if o.a > 0.0:
					rec.set_pixel(xi, yi, o.darkened(0.6))


# Pinta una imagen de colores por rachas, centrada y encajada en 'lado' sin deformarla.
static func _pintar_imagen(ci: CanvasItem, centro: Vector2, lado: float, img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	if w <= 0 or h <= 0:
		return
	var k: float = lado * 0.92 / float(maxi(w, h))
	var org: Vector2 = centro - Vector2(w, h) * k * 0.5
	for y in h:
		var ya: float = round(org.y + float(y) * k)
		var yb: float = round(org.y + float(y + 1) * k)
		var x: int = 0
		while x < w:
			var c: Color = img.get_pixel(x, y)
			var xs: int = x
			while x < w and img.get_pixel(x, y) == c:
				x += 1
			if c.a <= 0.0:
				continue
			var xa: float = round(org.x + float(xs) * k)
			ci.draw_rect(Rect2(xa, ya, round(org.x + float(x) * k) - xa, yb - ya), c)


# LA QUITINA: una placa de caparazon curvada. La del ESCARABAJO es el ala dura, abombada, con su
# costura en medio y un brillo duro; la de la SEGADORA es el filo de su guadaña, una media luna con el
# canto afilado en luz. Es cuero en el juego (se trabaja igual), pero no es un pellejo: es concha.
static func _quitina(segada: bool) -> Array:
	if segada:
		return [
			_pol("s", [0.14, 0.82, 0.20, 0.52, 0.34, 0.28, 0.56, 0.14, 0.80, 0.12, 0.90, 0.18, 0.70, 0.24,
				0.52, 0.36, 0.40, 0.56, 0.34, 0.80]),
			{"p": P([0.20, 0.74, 0.24, 0.52, 0.36, 0.32, 0.56, 0.18, 0.78, 0.15, 0.66, 0.22, 0.48, 0.34,
				0.36, 0.54, 0.30, 0.76]), "t": "b", "dentro": true},
			_lin("h", [0.30, 0.44, 0.42, 0.26, 0.60, 0.16, 0.80, 0.14]),
			_lin("d", [0.30, 0.60, 0.40, 0.44, 0.54, 0.32]),
			_lin("d", [0.26, 0.72, 0.32, 0.62]),
		]
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


# ============================================================
#  LOS NUCLEOS: UNO POR MONSTRUO
# ============================================================
# Cada nucleo es una ESFERA (las referencias del jefe) con lo que identifica a SU bicho: las orejas y
# la cola de la rata, los colmillos del jabali, los cuernos del minotauro, el ojo de la aberracion...
# El color es el del .tres del nucleo. Lo pidio el jefe asi, uno a uno y no por familias: "quedan
# mas god".
#
# El orden importa: lo que va DETRAS de la bola (colas, alas, patas, tentaculos) se pinta antes; la
# bola despues; su textura "dentro" de ella; y lo que va DELANTE (coronas, cuernos, colmillos) al final.
const NUC_C := Vector2(0.5, 0.54)
const NUC_R := 0.31

# La bola con su volumen: sombra honda, sombra, base y luz, cada una un poco hacia la luz de arriba a
# la izquierda. 'brillo' añade el reflejo de algo mojado o duro (baba, caparazon, ojo).
static func _bola(out: Array, brillo: bool, r: float = NUC_R, c: Vector2 = NUC_C) -> void:
	out.append(_elipse("d", c.x, c.y, r, r, 32))
	for capa in [["s", -0.02, -0.02, 0.94], ["b", -0.05, -0.06, 0.78], ["l", -0.10, -0.11, 0.44]]:
		var e: Dictionary = _elipse(capa[0], c.x + capa[1], c.y + capa[2], r * capa[3], r * capa[3], 28)
		e["dentro"] = true
		out.append(e)
	if brillo:
		var h: Dictionary = _elipse("h", c.x - r * 0.40, c.y - r * 0.45, r * 0.20, r * 0.16, 12)
		h["dentro"] = true
		out.append(h)
		var w: Dictionary = _elipse("W", c.x - r * 0.46, c.y - r * 0.50, r * 0.07, r * 0.07, 8)
		w["dentro"] = true
		out.append(w)


# Algo pintado SOLO sobre la bola (manchas, motas, ojos pegados a ella).
static func _sobre(e: Dictionary) -> Dictionary:
	e["dentro"] = true
	return e


# Trazos de pelo sobre la bola: a favor del pelo, oscuros, y un par de luces. El pelo es MATE.
static func _pelo(out: Array) -> void:
	for m in [[0.32, 0.42, 0.35, 0.50], [0.42, 0.34, 0.44, 0.42], [0.56, 0.34, 0.58, 0.42],
			[0.66, 0.46, 0.69, 0.54], [0.38, 0.60, 0.41, 0.68], [0.52, 0.56, 0.54, 0.64],
			[0.62, 0.64, 0.64, 0.72], [0.46, 0.46, 0.47, 0.52]]:
		out.append(_lin("d", m))
	for m in [[0.36, 0.38, 0.38, 0.44], [0.48, 0.30, 0.50, 0.36]]:
		out.append(_lin("h", m))


# Una corona de oro encima de la bola: la llevan los dos reyes.
static func _corona(out: Array, y: float = 0.20) -> void:
	out.append(_pol("g", [0.34, y + 0.10, 0.34, y - 0.02, 0.40, y + 0.04, 0.45, y - 0.06, 0.50, y + 0.03,
		0.55, y - 0.06, 0.60, y + 0.04, 0.66, y - 0.02, 0.66, y + 0.10]))
	out.append(_pol("G", [0.34, y + 0.07, 0.66, y + 0.07, 0.66, y + 0.11, 0.34, y + 0.11]))
	out.append(_elipse("R", 0.50, y + 0.05, 0.02, 0.02, 6))


# Las gotas que chorrean por debajo de una bola de baba.
static func _gotas(out: Array) -> void:
	out.append(_tira("s", [0.36, 0.76, 0.36, 0.88], 0.07, 0.05))
	out.append(_elipse("s", 0.36, 0.90, 0.035, 0.035, 8))
	out.append(_tira("s", [0.60, 0.78, 0.61, 0.85], 0.06, 0.04))


static func _nucleo(bicho: String) -> Array:
	var out: Array = []
	var c: Vector2 = NUC_C
	match bicho:
		"rata", "rey_rata":
			out.append(_tira("P", [0.74, 0.70, 0.86, 0.76, 0.90, 0.88, 0.80, 0.92], 0.05, 0.02))
			for ox in [0.32, 0.68]:
				out.append(_elipse("P", ox, 0.28, 0.09, 0.09, 12))
				out.append(_elipse("p", ox, 0.29, 0.05, 0.05, 10))
			_bola(out, false)
			_pelo(out)
			if bicho == "rey_rata":
				_corona(out, 0.16)
		"slime", "rey_slime", "slime_abisal":
			# GELATINA con el NUCLEO de verdad flotando dentro: una bola mas oscura en el centro.
			_gotas(out)
			_bola(out, true)
			out.append(_sobre(_elipse("s", 0.54, 0.60, 0.10, 0.10, 14)))
			out.append(_sobre(_elipse("d", 0.55, 0.61, 0.06, 0.06, 10)))
			if bicho == "slime_abisal":
				for m in [[0.38, 0.62], [0.64, 0.46], [0.46, 0.74], [0.70, 0.64]]:
					out.append(_sobre(_elipse("W", m[0], m[1], 0.012, 0.012, 4)))
			if bicho == "rey_slime":
				_corona(out, 0.14)
		"venenoso":
			# baba toxica: burbujas que REVIENTAN por encima del borde, y gotas
			_gotas(out)
			_bola(out, true)
			for b in [[0.40, 0.25, 0.05], [0.56, 0.22, 0.04], [0.66, 0.30, 0.03]]:
				out.append(_elipse("l", b[0], b[1], b[2], b[2], 10))
			for b in [[0.60, 0.62, 0.05], [0.44, 0.68, 0.035], [0.66, 0.44, 0.03]]:
				out.append(_sobre(_elipse("h", b[0], b[1], b[2], b[2], 10)))
		"fuego":
			# ROCA DE LAVA: placas oscuras con las JUNTAS ENCENDIDAS (la referencia del jefe). La bola se
			# pinta entera de lava y las placas encima, dejando las juntas a la vista.
			out.append(_elipse("L", c.x, c.y, NUC_R + 0.04, NUC_R + 0.04, 32))
			out.append(_elipse("K", c.x - 0.02, c.y - 0.02, NUC_R * 0.7, NUC_R * 0.7, 24))
			var placas: Array = [
				[0.30, 0.34, 0.44, 0.26, 0.48, 0.40, 0.36, 0.46],
				[0.50, 0.26, 0.66, 0.30, 0.64, 0.42, 0.52, 0.40],
				[0.22, 0.52, 0.34, 0.50, 0.40, 0.62, 0.26, 0.68],
				[0.40, 0.46, 0.54, 0.46, 0.58, 0.60, 0.44, 0.62],
				[0.60, 0.46, 0.76, 0.44, 0.78, 0.60, 0.64, 0.62],
				[0.32, 0.72, 0.46, 0.68, 0.50, 0.82, 0.38, 0.84],
				[0.52, 0.68, 0.66, 0.68, 0.64, 0.80, 0.54, 0.82],
				[0.70, 0.66, 0.78, 0.64, 0.72, 0.76],
				[0.24, 0.42, 0.28, 0.36, 0.34, 0.46, 0.24, 0.48],
			]
			for pl in placas:
				out.append(_sobre({"p": P(pl), "t": "d"}))
				# la cara de arriba de cada placa, en luz: las placas son roca, no manchas planas
				var p0: Vector2 = Vector2(pl[0], pl[1])
				var p1: Vector2 = Vector2(pl[2], pl[3])
				out.append(_lin("s", [p0.x + 0.01, p0.y + 0.01, p1.x - 0.01, p1.y + 0.01]))
		"profundo":
			# AGUA: la bola azul con olas claras cruzandola y el fondo mas hondo abajo
			_bola(out, true)
			out.append(_sobre(_pol("s", [0.14, 0.64, 0.30, 0.60, 0.46, 0.64, 0.62, 0.60, 0.86, 0.64, 0.86, 0.90, 0.14, 0.90])))
			out.append(_lin("h", [0.24, 0.60, 0.32, 0.56, 0.42, 0.60]))
			out.append(_lin("l", [0.50, 0.58, 0.60, 0.54, 0.70, 0.58]))
			out.append(_lin("l", [0.30, 0.74, 0.44, 0.70, 0.56, 0.74]))
		"sanguijuela":
			# CARNE con la BOCA de la sanguijuela: un anillo de dientes
			_bola(out, true)
			out.append(_sobre(_elipse("o", 0.52, 0.58, 0.11, 0.11, 16)))
			out.append(_sobre(_elipse("R", 0.52, 0.58, 0.06, 0.06, 12)))
			for k in 8:
				var a: float = TAU * float(k) / 8.0
				out.append(_sobre(_elipse("I", 0.52 + cos(a) * 0.085, 0.58 + sin(a) * 0.085, 0.015, 0.015, 4)))
		"jabali":
			# LA CRESTA de cerdas por detras y los COLMILLOS por delante
			out.append(_pol("d", [0.30, 0.34, 0.34, 0.16, 0.40, 0.26, 0.46, 0.12, 0.52, 0.24, 0.58, 0.12,
				0.62, 0.26, 0.68, 0.18, 0.70, 0.36]))
			_bola(out, false)
			_pelo(out)
			out.append(_tira("I", [0.38, 0.74, 0.30, 0.66, 0.30, 0.54], 0.06, 0.02))
			out.append(_tira("I", [0.62, 0.74, 0.70, 0.66, 0.70, 0.54], 0.06, 0.02))
		"bestia":
			# BANDAS DE ARMADURA, como un armadillo
			_bola(out, true)
			for i in 5:
				var y: float = 0.32 + 0.09 * float(i)
				out.append(_sobre(_pol("l", [0.10, y, 0.90, y, 0.90, y + 0.025, 0.10, y + 0.025])))
				out.append(_lin("o", [0.12, y + 0.045, 0.88, y + 0.045]))
		"minotauro":
			# LOS CUERNOS y el ARO de la nariz
			_bola(out, false)
			_pelo(out)
			out.append(_tira("I", [0.30, 0.34, 0.18, 0.26, 0.14, 0.12], 0.08, 0.02))
			out.append(_tira("I", [0.70, 0.34, 0.82, 0.26, 0.86, 0.12], 0.08, 0.02))
			out.append(_lin("i", [0.28, 0.32, 0.18, 0.24]))
			out.append(_lin("i", [0.72, 0.32, 0.82, 0.24]))
			out.append(_lin("g", [0.46, 0.74, 0.46, 0.80, 0.50, 0.83, 0.54, 0.80, 0.54, 0.74]))
		"trent":
			out.append(_pol("s", [0.72, 0.42, 0.88, 0.28, 0.92, 0.32, 0.78, 0.48]))
			out.append(_pol("F", [0.86, 0.28, 0.84, 0.14, 0.94, 0.10, 0.94, 0.24]))
			_bola(out, false)
			for g in [[0.30, 0.30, 0.25, 0.54, 0.30, 0.78], [0.44, 0.24, 0.40, 0.54, 0.44, 0.86],
					[0.58, 0.24, 0.60, 0.54, 0.56, 0.86], [0.70, 0.32, 0.74, 0.54, 0.68, 0.78]]:
				out.append(_lin("d", g))
			out.append(_lin("l", [0.36, 0.30, 0.33, 0.48]))
		"gargola":
			# PIEDRA con dos ALAS de piedra asomando por los lados
			for s in [-1.0, 1.0]:
				out.append(_pol("s", [0.5 + s * 0.22, 0.40, 0.5 + s * 0.46, 0.22, 0.5 + s * 0.44, 0.36,
					0.5 + s * 0.48, 0.46, 0.5 + s * 0.40, 0.50, 0.5 + s * 0.42, 0.60, 0.5 + s * 0.26, 0.60]))
			_bola(out, false)
			_juntas(out, false)
		"golem":
			# ARCILLA agrietada con una RUNA encendida en el centro: lo que lo mueve
			_bola(out, false)
			out.append(_lin("d", [0.30, 0.40, 0.38, 0.46, 0.36, 0.56]))
			out.append(_lin("d", [0.64, 0.36, 0.62, 0.46, 0.70, 0.52]))
			out.append(_lin("K", [0.50, 0.44, 0.50, 0.66]))
			out.append(_lin("K", [0.44, 0.50, 0.50, 0.44, 0.56, 0.50]))
			out.append(_lin("K", [0.44, 0.62, 0.56, 0.62]))
		"coloso":
			# BLOQUES DE PIEDRA con el CORAZON brillando por la junta del centro
			_bola(out, false)
			_juntas(out, true)
		"arana":
			# OCHO PATAS por detras y el racimo de OJOS rojos delante
			for s in [-1.0, 1.0]:
				for i in 4:
					var y2: float = 0.36 + 0.10 * float(i)
					out.append(_tira("d", [0.5 + s * 0.20, y2, 0.5 + s * 0.40, y2 - 0.10, 0.5 + s * 0.48,
						y2 + 0.06], 0.045, 0.02))
			_bola(out, true)
			for e in [[0.44, 0.40, 0.04], [0.56, 0.40, 0.04], [0.40, 0.48, 0.025], [0.60, 0.48, 0.025],
					[0.47, 0.50, 0.02], [0.53, 0.50, 0.02]]:
				out.append(_sobre(_elipse("R", e[0], e[1], e[2], e[2], 8)))
		"escarabajo":
			# LOS ELITROS: la costura del medio y un brillo duro en cada mitad
			_bola(out, true)
			out.append(_lin("o", [0.50, 0.24, 0.51, 0.84]))
			out.append(_sobre(_elipse("h", 0.62, 0.40, 0.04, 0.06, 10)))
			out.append(_lin("v", [0.30, 0.54, 0.36, 0.70]))
			out.append(_lin("v", [0.64, 0.60, 0.68, 0.72]))
		"ciempies":
			# SEGMENTOS en anillo y PATITAS por los lados
			for s in [-1.0, 1.0]:
				for i in 5:
					var y3: float = 0.34 + 0.09 * float(i)
					out.append(_tira("d", [0.5 + s * 0.28, y3, 0.5 + s * 0.42, y3 + 0.04], 0.035, 0.02))
			_bola(out, true)
			for i in 5:
				var y4: float = 0.32 + 0.09 * float(i)
				out.append(_lin("o", [0.20, y4, 0.50, y4 + 0.03, 0.80, y4]))
		"segadora":
			# el FILO de la guadaña asomando por detras
			out.append(_tira("l", [0.64, 0.40, 0.80, 0.22, 0.94, 0.20, 0.96, 0.30], 0.08, 0.02))
			out.append(_lin("h", [0.72, 0.28, 0.82, 0.20, 0.92, 0.20]))
			_bola(out, true)
			out.append(_lin("d", [0.30, 0.48, 0.50, 0.44, 0.70, 0.50]))
			out.append(_lin("d", [0.32, 0.64, 0.50, 0.62, 0.68, 0.66]))
		"polilla":
			# PELUSA con dos ANTENAS de pluma y el polvo de sus alas
			for s in [-1.0, 1.0]:
				out.append(_tira("s", [0.5 + s * 0.08, 0.26, 0.5 + s * 0.18, 0.12, 0.5 + s * 0.24, 0.06], 0.03, 0.02))
				for k in 3:
					var yy: float = 0.10 + 0.05 * float(k)
					var xx: float = 0.5 + s * (0.16 + 0.03 * float(2 - k))
					out.append(_lin("s", [xx, yy, xx + s * 0.05, yy - 0.02]))
			_bola(out, false)
			_pelo(out)
			for m in [[0.36, 0.52], [0.62, 0.40], [0.56, 0.68], [0.42, 0.34]]:
				out.append(_sobre(_elipse("h", m[0], m[1], 0.02, 0.02, 6)))
		"chillon":
			# PELO con dos ALAS de murcielago abiertas
			for s in [-1.0, 1.0]:
				out.append(_pol("d", [0.5 + s * 0.24, 0.40, 0.5 + s * 0.46, 0.26, 0.5 + s * 0.48, 0.52,
					0.5 + s * 0.42, 0.46, 0.5 + s * 0.38, 0.60, 0.5 + s * 0.32, 0.52, 0.5 + s * 0.28, 0.62]))
				out.append(_lin("s", [0.5 + s * 0.28, 0.42, 0.5 + s * 0.44, 0.30]))
			for ox in [0.38, 0.62]:
				out.append(_pol("b", [ox - 0.06, 0.30, ox, 0.14, ox + 0.06, 0.30]))
			_bola(out, false)
			_pelo(out)
		"acechador":
			# UN OJO de fiera con la PUPILA RASGADA
			_bola(out, true)
			out.append(_sobre(_elipse("E", 0.52, 0.54, 0.14, 0.08, 16)))
			out.append(_sobre(_pol("o", [0.515, 0.47, 0.53, 0.47, 0.535, 0.61, 0.51, 0.61])))
			out.append(_lin("W", [0.44, 0.52, 0.46, 0.51]))
		"aberracion":
			# TENTACULOS por debajo y UN OJO enorme
			for t in [[0.34, 0.76, 0.26, 0.86, 0.30, 0.94], [0.50, 0.80, 0.52, 0.92, 0.46, 0.97],
					[0.66, 0.76, 0.76, 0.84, 0.74, 0.94]]:
				out.append(_tira("s", t, 0.07, 0.02))
			_bola(out, true)
			out.append(_sobre(_elipse("W", 0.52, 0.52, 0.14, 0.13, 18)))
			out.append(_sobre(_elipse("R", 0.54, 0.53, 0.07, 0.07, 12)))
			out.append(_sobre(_elipse("o", 0.55, 0.54, 0.03, 0.03, 8)))
		"miconido":
			# UNA SETA: el pie claro y el sombrero con motas
			out.append(_pol("x", [0.42, 0.56, 0.58, 0.56, 0.60, 0.86, 0.40, 0.86]))
			out.append(_pol("w", [0.42, 0.56, 0.52, 0.56, 0.52, 0.86, 0.40, 0.86]))
			out.append(_pol("s", [0.14, 0.60, 0.18, 0.40, 0.30, 0.24, 0.50, 0.16, 0.70, 0.24, 0.82, 0.40,
				0.86, 0.60]))
			out.append(_sobre(_pol("b", [0.16, 0.56, 0.20, 0.40, 0.32, 0.26, 0.50, 0.18, 0.66, 0.24, 0.74,
				0.38, 0.70, 0.54])))
			out.append(_sobre(_elipse("l", 0.38, 0.32, 0.10, 0.06, 12)))
			for m in [[0.34, 0.40, 0.05], [0.54, 0.28, 0.04], [0.66, 0.46, 0.05], [0.46, 0.50, 0.03]]:
				out.append(_sobre(_elipse("m", m[0], m[1], m[2], m[2] * 0.85, 10)))
		_:
			_bola(out, true)
	return out


# Las JUNTAS de una bola de piedra (la de "stones" de la referencia), con luz en cada cara. Con
# 'corazon', la junta del centro brilla: el coloso tiene algo vivo dentro.
static func _juntas(out: Array, corazon: bool) -> void:
	for g in [[0.20, 0.50, 0.34, 0.52, 0.44, 0.42, 0.44, 0.24],
			[0.44, 0.42, 0.60, 0.50, 0.74, 0.36],
			[0.34, 0.52, 0.36, 0.68, 0.22, 0.74],
			[0.36, 0.68, 0.54, 0.70, 0.60, 0.50],
			[0.54, 0.70, 0.60, 0.86],
			[0.60, 0.50, 0.84, 0.62]]:
		out.append(_lin("o", g))
	for g in [[0.26, 0.46, 0.32, 0.44], [0.50, 0.36, 0.56, 0.38], [0.42, 0.58, 0.48, 0.58]]:
		out.append(_lin("h", g))
	if corazon:
		out.append(_lin("K", [0.44, 0.44, 0.52, 0.49, 0.60, 0.51]))
		out.append(_lin("L", [0.36, 0.54, 0.36, 0.66, 0.52, 0.69]))


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
		elif paso.get("libre", false):
			# una linea AL AIRE (el sedal de la caña): se traza aunque debajo no haya nada
			_trazar(celdas, paso["l"], t, res, func(_i: int) -> bool: return true)
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
