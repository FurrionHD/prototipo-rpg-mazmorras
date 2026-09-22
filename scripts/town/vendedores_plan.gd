# ============================================================
#  vendedores_plan.gd  (class_name VendedoresPlan)
#  LOS VENDEDORES DEL MERCADILLO Y SU DIA, como DATOS y CUENTAS (lo mismo que GuardiasPlan para los
#  guardias; reutiliza sus rutas y sus tramos). El nodo (vendedor_mercadillo.gd) solo lo pinta.
#
#  Pedido del usuario el 22/09/2026: los vendedores salen de su casa por la mañana, van a su puesto, se
#  meten dentro y atienden todo el dia; al atardecer recogen y vuelven a casa. De noche el mercadillo
#  esta CERRADO (no hay nadie a quien comprarle).
#
#  TODO SALE DE LA HORA (CicloDia.segundo), no se simula: sin estado y sin red, todos ven lo mismo.
#  Los tramos van en segundos del CICLO (no desde un cambio de turno como los guardias): uno por dia.
#
#  EL PASO DE LA CALLE AL PUESTO. Andando por el pueblo el vendedor es un muñeco normal; dentro del puesto
#  va pintado en la imagen del puesto (ver VendedorMercadillo). El cambio se hace en el COSTADO del
#  puesto, la casilla de su lado oeste, que aun cabe en esa imagen: ahi los dos muñecos se ven iguales.
#  Desde ahi entra de lado, ya "dentro", por detras del poste. Los tramos 'dentro' son los de la imagen.
# ============================================================
extends RefCounted
class_name VendedoresPlan

const Tipo = GuardiasPlan.Tipo

# Al amanecer (CicloDia empieza el dia en el segundo 0) salen, y en T_ATARDECER recogen. Escalonados unos
# segundos para que no salgan de casa los cuatro a la vez, como a toque de corneta.
const SALIDA := 5.0
const ESCALON := 9.0
# Lo que tardan en colocarse al llegar y en recoger antes de irse (quietos en su sitio, mirando al sur).
const ENTRAR := 2.0

# LOS CUATRO: su casa (la huella de una casa de PuebloPlano.CASAS) y su puesto (la clave del mueble en
# PuebloPlano.MUEBLES). Dos viven en el barrio norte, encima del mercadillo, y dos en la fila de casas de
# la calle alta, al sur: asi no llegan todos por el mismo camino.
#
# Y LO QUE VENDE CADA UNO ('genero', rutas de MaterialData): la comida que antes vendia la tienda,
# repartida por el usuario el 22/09/2026. El de FRUTA no vende nada todavia: en el juego no hay frutas
# (hay que decidir cuales y en que comidas entran); esta en su puesto pero no se le puede comprar.
const MAT := "res://resources/materials/%s.tres"
const VENDEDORES := [
	{"casa": Rect2i(45, 6, 3, 3), "puesto": "puesto_pan", "nombre": "Pan y queso",
		"genero": ["pan", "queso"]},
	{"casa": Rect2i(50, 24, 3, 3), "puesto": "puesto_verdura", "nombre": "Verduras",
		"genero": ["tomate", "lechuga", "patata", "zanahoria", "pimiento"]},
	{"casa": Rect2i(55, 24, 3, 3), "puesto": "puesto_fruta", "nombre": "Fruta",
		"genero": []},
	{"casa": Rect2i(60, 6, 3, 3), "puesto": "puesto_especias", "nombre": "Especias y aceite",
		"genero": ["ajo", "cebolla", "aceite"]},
]


# El genero del vendedor 'v', cargado.
static func genero(v: int) -> Array:
	var out: Array = []
	for n in VENDEDORES[v]["genero"]:
		var m: Resource = load(MAT % n)
		if m != null:
			out.append(m)
	return out


# ¿Se le puede comprar? Tiene que estar abierto y tener algo que vender.
static func vende(v: int, t: float) -> bool:
	return not (VENDEDORES[v]["genero"] as Array).is_empty() and abierto(v, t)


# El estado del vendedor 'v' en el segundo 't' del ciclo:
#   {visible, pos (px, el origen del nodo), mira, moviendose, dentro (en la imagen del puesto), abierto}
static func estado(v: int, t: float) -> Dictionary:
	var tau: float = fposmod(t, CicloDia.CICLO)
	var tramos: Array = linea(v)
	for tr in tramos:
		if tau < float(tr["t1"]):
			return _evaluar(tr, tau)
	return _evaluar(tramos[-1], float(tramos[-1]["t0"]))


# ¿Se le puede comprar ahora? Solo quieto dentro de su puesto.
static func abierto(v: int, t: float) -> bool:
	return bool(estado(v, t)["abierto"])


static func _evaluar(tr: Dictionary, tau: float) -> Dictionary:
	var out: Dictionary = GuardiasPlan._evaluar(tr, tau)
	out["dentro"] = bool(tr.get("dentro", false))
	out["abierto"] = bool(tr.get("abierto", false))
	return out


# ============================================================
#  LOS TRAMOS DEL DIA
# ============================================================
static var _lineas: Dictionary = {}

static func linea(v: int) -> Array:
	if not _lineas.has(v):
		_lineas[v] = _linea(v)
	return _lineas[v]


static func _linea(v: int) -> Array:
	var casa: Vector2i = puerta_casa(v)
	var costado: Vector2i = costado_de(v)
	var hueco: Vector2 = pos_hueco(v)
	var borde: Vector2 = pos_borde(v)
	var sale: float = SALIDA + ESCALON * float(v)
	var recoge: float = CicloDia.T_ATARDECER + ESCALON * float(v)
	var out: Array = []
	# De noche, en casa.
	out.append({"t0": 0.0, "t1": sale, "tipo": Tipo.OCULTO, "armado": false})
	var t: float = GuardiasPlan._anda(out, sale, GuardiasPlan.ruta(casa, costado), false)
	# Del costado al borde del puesto, aun en la calle, y del borde a su sitio ya dentro.
	t = _anda_dentro(out, t, PackedVector2Array([GuardiasPlan.pos_de(costado), borde, hueco]))
	# Se coloca, y abierto hasta el atardecer.
	out.append({"t0": t, "t1": t + ENTRAR, "tipo": Tipo.QUIETO, "armado": false, "dentro": true,
		"pos": hueco, "mira": Vector2.DOWN})
	out.append({"t0": t + ENTRAR, "t1": recoge, "tipo": Tipo.QUIETO, "armado": false, "dentro": true,
		"abierto": true, "pos": hueco, "mira": Vector2.DOWN})
	out.append({"t0": recoge, "t1": recoge + ENTRAR, "tipo": Tipo.QUIETO, "armado": false, "dentro": true,
		"pos": hueco, "mira": Vector2.DOWN})
	# Y el camino de vuelta, al reves.
	t = _anda_dentro(out, recoge + ENTRAR, PackedVector2Array([hueco, borde, GuardiasPlan.pos_de(costado)]))
	t = GuardiasPlan._anda(out, t, GuardiasPlan.ruta(costado, casa), false)
	out.append({"t0": t, "t1": GuardiasPlan.INF, "tipo": Tipo.OCULTO, "armado": false})
	return out


static func _anda_dentro(out: Array, t: float, r: PackedVector2Array) -> float:
	var t1: float = GuardiasPlan._anda(out, t, r, false)
	out[-1]["dentro"] = true
	return t1


# ============================================================
#  SITIOS
# ============================================================
static func puerta_casa(v: int) -> Vector2i:
	return PuebloPlano.puerta_de({"rect": VENDEDORES[v]["casa"]})


static func huella(v: int) -> Rect2i:
	var clave: String = VENDEDORES[v]["puesto"]
	for m in PuebloPlano.MUEBLES:
		if String(m[0]) == clave:
			return m[1]
	return Rect2i()


# La casilla de calle pegada al lado OESTE del puesto, en su fila de delante.
static func costado_de(v: int) -> Vector2i:
	var r: Rect2i = huella(v)
	return Vector2i(r.position.x - 1, r.end.y - 1)


# Donde atiende: de pie en el hueco, entre el mostrador y el estante.
static func pos_hueco(v: int) -> Vector2:
	return VendedorMercadillo.origen_en_puesto(huella(v))


# El paso por el lado oeste del puesto, ya a la altura del hueco: justo detras del poste de delante (x 2-4
# del lienzo del puesto), para que desde el costado entre en diagonal por detras de el.
const DETRAS_DEL_POSTE := 6.0

static func pos_borde(v: int) -> Vector2:
	var esquina: Vector2 = VendedorMercadillo.esquina_puesto(huella(v))
	return Vector2(esquina.x + DETRAS_DEL_POSTE, pos_hueco(v).y)
