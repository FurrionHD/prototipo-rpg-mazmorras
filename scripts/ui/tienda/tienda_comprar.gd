# ============================================================
#  tienda_comprar.gd  --  pestaña COMPRAR de la tienda (ver shop_menu.gd, que es el armazon).
#
#  El mostrador del tendero, con la misma cara que Vender: celdas, buscador, filtros y cesta. El equipo
#  sale a calidad COMUN y al tier del mostrador; el T2 lo abre el Rey Slime y aqui es un selector T1/T2
#  en la barra de abajo (antes era una pestaña entera que repetia las mismas cinco subpestañas).
#
#  Lo que se enseña del equipo es una COPIA DE ESCAPARATE con su tier (t.vitrina): los .tres del
#  catalogo no tienen tier y la celda diria "T1" en el mostrador T2.
#
#  NO hay grimorios: la magia se gana (maestro y cofres), no se compra por ventanilla. La comida son
#  MATERIALES para cocinar, y la sal y los silvestres no estan: eso se baja a buscar.
# ============================================================
extends RefCounted

const TiendaCesta = preload("res://scripts/ui/tienda/tienda_cesta.gd")

const SUBS := ["Armas", "Armaduras", "Mochilas", "Consumibles", "Comida"]
const SUBS_ICONOS := ["espada", "coraza", "mochila", "pocion", "flor"]
const SUB_ARMAS := 0
const SUB_ARMADURAS := 1
const SUB_MOCHILAS := 2
const SUB_CONSUMIBLES := 3
const SUB_COMIDA := 4

# Armas y secundarias: la lista vive en CatalogoEquipo, porque el maestro de habilidades recorre esas
# MISMAS plantillas para saber que habilidades trae cada arma.
const CAT_ARMAS: Array[String] = CatalogoEquipo.ARMAS
const CAT_SECUNDARIAS: Array[String] = CatalogoEquipo.SECUNDARIAS
# La mochila basica: la unica que se compra hecha. Las buenas las cose el peletero.
const CAT_MOCHILAS: Array[String] = ["res://resources/backpacks/mochila_basica.tres"]
# Solo las pociones BASE: las +1/+2 te las mejora la boticaria.
const CAT_POCIONES: Array[String] = [
	"res://resources/consumables/pocion_menor.tres",
	"res://resources/consumables/pocion_mana_menor.tres",
	"res://resources/consumables/piedra_retorno.tres",
]
const CAT_POCIONES_T2: Array[String] = [
	"res://resources/consumables/pocion_media.tres",
	"res://resources/consumables/pocion_mana_media.tres",
	"res://resources/consumables/piedra_retorno_t2.tres",
]
const CAT_COMIDA: Array[String] = [
	"res://resources/materials/cebolla.tres",
	"res://resources/materials/ajo.tres",
	"res://resources/materials/tomate.tres",
	"res://resources/materials/lechuga.tres",
	"res://resources/materials/patata.tres",
	"res://resources/materials/zanahoria.tres",
	"res://resources/materials/pimiento.tres",
	"res://resources/materials/pan.tres",
	"res://resources/materials/queso.tres",
	"res://resources/materials/aceite.tres",
]
# Armaduras: los 4 tipos x los 5 slots, de la mas ligera a la mas pesada.
const ARMOR_TIPOS: Array[String] = ["cuero", "hierro", "hierro_completo", "placas"]
const ARMOR_TIPO_LABELS := ["Cuero", "Hierro", "Hierro completo", "Placas"]
const ARMOR_SLOT_LABELS := ["Casco", "Pecho", "Manos", "Pantalones", "Botas"]
# Tope de unidades por compra: el equipo de uno en uno cansa, pero cien espadas no las quiere nadie.
const TOPE_EQUIPO := 10
const TOPE_PUNADO := 99

var t = null   # el armazon (shop_menu.gd)
var cesta = TiendaCesta.new()
var _sub: int = SUB_ARMAS
var _tier: int = 1


func _init(armazon) -> void:
	t = armazon


func clave() -> String:
	return "comprar_%d" % _sub


func por_defecto() -> String:
	return ""


func rotulo_cesta() -> String:
	return "Comprar cesta"


func al_cerrar() -> void:
	cesta.vaciar()
	t.vaciar_vitrina()


# ============================================================
#  PINTAR
# ============================================================

func build() -> void:
	if not Game.tienda_t2_abierta():
		_tier = 1
	MenuScaffold.subpestanas(t.barra_sub, SUBS, SUBS_ICONOS, _sub, _on_sub)
	t.titulo_seccion(SUBS[_sub] + ("  ·  T2" if _tier >= 2 and _sub != SUB_COMIDA else ""))
	var todos: Array = _recoger()
	t.stacks = t.orden.aplicar(clave(), todos, self, por_defecto())
	var piezas: Array = []
	for s in t.stacks:
		var apuntado: int = cesta.cantidad_de(String(s["clave"]))
		piezas.append(t.pieza(s["modelo"], "%d" % precio_unidad(s), nombre_de(s),
			("Cesta %d" % apuntado) if apuntado > 0 else ""))
	t.grid_detail(piezas, _ficha, "No hay nada que coincida.")


func _on_sub(i: int) -> void:
	if i == _sub:
		return
	_sub = i
	t.cambiar_pantalla()


func _recoger() -> Array:
	var rutas: Array = []
	match _sub:
		SUB_ARMAS: rutas = CAT_ARMAS + CAT_SECUNDARIAS
		SUB_ARMADURAS:
			for tipo in ARMOR_TIPOS:
				for slot in Game.ARMOR_SLOT_ORDEN:
					rutas.append("res://resources/armor/%s_%s.tres" % [tipo, slot])
		SUB_MOCHILAS: rutas = CAT_MOCHILAS
		SUB_CONSUMIBLES: rutas = CAT_POCIONES_T2 if _tier >= 2 else CAT_POCIONES
		SUB_COMIDA: rutas = CAT_COMIDA
	var out: Array = []
	for ruta in rutas:
		var base: Resource = load(ruta)
		if base == null:
			continue
		# La comida y las pociones no tienen tier en la compra: su "T2" son recursos aparte.
		var tier: int = _tier if not (base is ConsumableData or base is MaterialData) else 1
		var modelo: Resource = base if (base is ConsumableData or base is MaterialData) else t.vitrina(base, tier)
		out.append({"modelo": modelo, "base": base, "tier": tier, "cantidad": 1, "origen": "tienda",
			"clave": "t|%d|%s" % [tier, ruta]})
	return out


func _ficha(vb: VBoxContainer) -> void:
	var s: Dictionary = t.stacks[t.sel]
	var base: Resource = s["base"]
	var precio: int = precio_unidad(s)
	t.ficha_objeto(vb, s["modelo"])
	vb.add_child(HSeparator.new())
	t.row(vb, "Precio", "%d monedas" % precio, t.AMBAR)
	t.row(vb, "Tienes", "%d monedas" % Game.money)
	match _sub:
		SUB_ARMAS, SUB_ARMADURAS:
			t.note(vb, "Sale a calidad común: el tendero no forja, revende. Lo bueno tendrás que fabricártelo tú." if _tier < 2
				else "Género de los pisos hondos, a tier 2 y calidad común. Se paga como lo que es.")
		SUB_MOCHILAS:
			t.note(vb, "La única que se compra hecha: las buenas (más carga) las cose el Peletero.")
		SUB_CONSUMIBLES:
			t.note(vb, "Comprarlas sale caro: si puedes, fabrícalas en la Boticaria con lo que traigas de la mazmorra.")
		SUB_COMIDA:
			t.note(vb, "Género de la superficie, para cocinar: crudo no hace nada. La sal y lo que crece abajo no se venden aquí.")
	var tope: int = TOPE_PUNADO if (base is ConsumableData or base is MaterialData) else TOPE_EQUIPO
	t.fila_accion(vb, tope, precio, "Comprar",
		func(n: int): _comprar([{"base": base, "tier": int(s["tier"]), "n": n}], n, nombre_de(s)),
		func(n: int):
			cesta.poner(s, n)
			t.rebuild(),
		cesta.cantidad_de(String(s["clave"])))
	if not Game.puede_pagar(precio):
		t.note(vb, "No te llega. Baja a por más cristales.")


# ============================================================
#  LO QUE LA TIENDA LE PREGUNTA A LA SECCION
# ============================================================

func precio_unidad(s: Dictionary) -> int:
	return Game.precio_mostrador(s["base"], int(s["tier"]))


func nombre_de(s: Dictionary) -> String:
	var n: String = str((s["base"] as Resource).get("nombre"))
	return n + ("  T2" if int(s["tier"]) >= 2 else "")


func nombre_corto(s: Dictionary) -> String:
	return nombre_de(s)


# Del mostrador no se acaba nada: la cesta de la compra no hay que sanearla.
func disponible(_s: Dictionary) -> int:
	return TOPE_PUNADO


func criterios() -> Array:
	return [{"nombre": "Predeterminado", "campo": ""}, {"nombre": "Precio", "campo": "precio"},
		{"nombre": "Nombre", "campo": "nombre"}]


func grupos() -> Array:
	match _sub:
		SUB_ARMAS:
			return [{"titulo": "Clase", "clave": "clase_equipo", "opciones": [{"nombre": "Armas", "valor": 0},
				{"nombre": "Escudos", "valor": 1}, {"nombre": "Varitas", "valor": 2}]}]
		SUB_ARMADURAS:
			var mats: Array = []
			for i in ARMOR_TIPO_LABELS.size():
				mats.append({"nombre": ARMOR_TIPO_LABELS[i], "valor": i})
			var slots: Array = []
			for i in ARMOR_SLOT_LABELS.size():
				slots.append({"nombre": ARMOR_SLOT_LABELS[i], "valor": i})
			return [{"titulo": "Material", "clave": "material_armadura", "opciones": mats},
				{"titulo": "Pieza", "clave": "slot", "opciones": slots}]
	return []


# El selector del mostrador, solo cuando el Rey Slime ya ha caido. En la Comida no pinta nada.
func pie_extra(barra: HBoxContainer) -> void:
	if not Game.tienda_t2_abierta() or _sub == SUB_COMIDA:
		return
	for tier in [1, 2]:
		var b := Button.new()
		b.text = "Mostrador T%d" % tier
		b.toggle_mode = true
		b.button_pressed = tier == _tier
		MenuScaffold.estilo_chip(b, tier == _tier)
		b.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_PASTILLA)
		b.pressed.connect(func():
			_tier = tier
			t.cambiar_pantalla())
		barra.add_child(b)


# ============================================================
#  COMPRAR
# ============================================================

func _comprar(entradas: Array, n: int, nombre: String) -> void:
	var cobrado: int = Game.comprar_lote(entradas)
	if cobrado <= 0:
		t.decir("No te llega para %s." % nombre, false)
	else:
		var equipo: bool = not (entradas[0]["base"] is ConsumableData or entradas[0]["base"] is MaterialData)
		t.decir(("Compras %d x %s por %d monedas." % [n, nombre, cobrado] if n > 1
			else "Compras %s por %d monedas." % [nombre, cobrado])
			+ (" Está en tu baúl: equípalo en el menú de personaje [C]." if equipo else ""))
	t.cant = -1
	t.rebuild()


func confirmar_cesta() -> void:
	if cesta.vacia():
		return
	var total: int = cesta.total(precio_unidad)
	var m: Dictionary = t.abrir_modal("¿Compras la cesta?")
	var cuerpo: VBoxContainer = m["cuerpo"]
	for e in cesta.entradas:
		var s: Dictionary = e["stack"]
		t.row(cuerpo, "%s  ×%d" % [nombre_corto(s), int(e["n"])], "%d monedas" % (precio_unidad(s) * int(e["n"])))
	cuerpo.add_child(HSeparator.new())
	t.row(cuerpo, "Total", "%d monedas" % total, t.AMBAR)
	t.row(cuerpo, "Tienes", "%d monedas" % Game.money)
	var llego: bool = Game.puede_pagar(total)
	if not llego:
		t.note(cuerpo, "No te llega para toda la cesta: quita algo o baja a por más cristales.")
	MenuScaffold.pastilla(m["acciones"], "Cancelar", t.cerrar_modal, false)
	MenuScaffold.pastilla(m["acciones"], "Comprar", func():
		t.cerrar_modal()
		var entradas: Array = []
		for e in cesta.entradas:
			entradas.append({"base": e["stack"]["base"], "tier": int(e["stack"]["tier"]), "n": int(e["n"])})
		var cosas: int = entradas.size()
		var cobrado: int = Game.comprar_lote(entradas)
		if cobrado <= 0:
			t.decir("No te llega para la cesta.", false)
		else:
			t.decir("Compras la cesta: %d %s por %d monedas. El equipo va a tu baúl." % [
				cosas, "cosa" if cosas == 1 else "cosas", cobrado])
			cesta.vaciar()
		t.cant = -1
		t.rebuild(), true, llego)
