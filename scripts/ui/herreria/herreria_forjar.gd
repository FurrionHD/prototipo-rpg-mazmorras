# ============================================================
#  herreria_forjar.gd  --  FORJAR una pieza del catalogo. La usan TRES talleres, cada uno con su parte
#  del catalogo (ver Catalogo):
#    - la HERRERIA:   armas, secundarias y las armaduras de metal (hierro, hierro completo, placas);
#    - la CARPINTERIA: las armas magicas (baston y varita);
#    - la PELETERIA:  la armadura de CUERO, que se cose con hebillas y cuero (decision del usuario,
#                     16/09/2026: no se golpea metal, se cose piel).
#  El armazon (t) es el de cada taller; esta pantalla solo le pide lo que tiene la base de los talleres
#  (taller_menu.gd): grid_detail, barra_sub/barra_sub2, acciones, contador, decir, reservar...
#
#  LA REJILLA SON LAS PIEZAS, y la celda pinta la pieza que sale CON SU TIER: una copia de escaparate
#  (como la mochila de la peleteria), porque el .tres del catalogo no tiene tier y todas dirian T1.
#  Encima, dos filas de filtros: que pieza (armas, secundarias, cada juego de armadura) y de que tier.
#  El tier lo pone el metal, asi que elegir tier ES elegir el metal.
#
#  LA FICHA: los ingredientes en columnas con su celda y una fila por calidad, la rareza que puede
#  salir con el score REAL, y en el pie la cantidad (para los Autos), los dos Autos, Limpiar y Forjar.
#  Lo que se forja de verdad sale de la SELECCION (Game.piezas_de_seleccion_forja), no de la cantidad.
# ============================================================
extends RefCounted

enum Catalogo { HERRERIA, CARPINTERIA, CUERO }

const CAT_ARMAS: Array[String] = [
	"res://resources/weapons/daga.tres",
	"res://resources/weapons/estoque.tres",
	"res://resources/weapons/espada_corta.tres",
	"res://resources/weapons/espada_larga.tres",
	"res://resources/weapons/maza_peq.tres",
	"res://resources/weapons/mandobles.tres",
	"res://resources/weapons/hacha_grande.tres",
	"res://resources/weapons/martillo_grande.tres",
	"res://resources/weapons/baston.tres",
]
const CAT_SECUNDARIAS: Array[String] = [
	"res://resources/shields/escudo_pequeno.tres",
	"res://resources/shields/escudo_normal.tres",
	"res://resources/shields/escudo_grande.tres",
	"res://resources/wands/varita.tres",
]
# Los filtros de la herreria: armas, secundarias y un juego de armadura por filtro (las quince piezas
# de golpe no se leen). El CUERO no esta: se cose en la peleteria.
const FILTROS_HERRERIA := [
	{"nombre": "Armas", "icono": "espada"},
	{"nombre": "Secundarias", "icono": "escudo_med"},
	{"nombre": "Armadura de hierro", "icono": "coraza_1", "juego": "hierro"},
	{"nombre": "Armadura de hierro completo", "icono": "coraza_2", "juego": "hierro_completo"},
	{"nombre": "Armadura de placas", "icono": "coraza_3", "juego": "placas"},
]
const NOMBRE_RANURA := {"casco": "Casco", "pecho": "Pecho", "manos": "Manos",
	"pantalones": "Pantalones", "botas": "Botas"}

# Cuantas columnas admite la rejilla de rareza de una tanda (ver MenuScaffold.tramos_por_calidad).
const MAX_COLUMNAS_RAREZA := 12
const LADO_CELDA_ING := 48.0

var t = null   # el armazon del taller
var catalogo: int = Catalogo.HERRERIA
# Las columnas de ingredientes: depende del ancho que le de cada taller a la ficha.
var columnas_ing: int = 2

var _filtro: int = 0
var _tier: int = 1   # el tier elegido (el de verdad, no un indice)
# Una seleccion {calidad: cantidad} por INGREDIENTE, en paralelo a Game.ingredientes_forja.
var _sel: Array = []
# CUANTAS piezas quieres que rellene el Auto. Arranca en 1 y vuelve a 1 al cambiar de pieza.
var _cantidad: int = 1


func _init(armazon, que: int, cols: int = 2) -> void:
	t = armazon
	catalogo = que
	columnas_ing = cols


func limpiar() -> void:
	_sel = []
	_cantidad = 1


# ============================================================
#  LAS COPIAS DE ESCAPARATE (ver peleteria_mochilas): la pieza con SU tier, sin registrar, y sus
#  metas se borran al cerrar o quedarian colgando para siempre.
# ============================================================

var _vitrina: Dictionary = {}

func vitrina(base: Resource, tier: int) -> Resource:
	var clave: String = "%s|%d" % [base.resource_path, tier]
	if not _vitrina.has(clave):
		_vitrina[clave] = Game.crear_item(base, tier, Upgrades.Rareza.COMUN, {}, false)
	return _vitrina[clave]


func vaciar_vitrina() -> void:
	for copia in _vitrina.values():
		Game.item_meta.erase(copia)
	_vitrina.clear()


# ============================================================
#  PINTAR
# ============================================================

func build() -> void:
	var bases: Array = _bases()
	# EL TIER, de los metales que conoces para estas piezas (lingote, chapa o hebillas: ver
	# Game.metales_conocidos_de). Sin ninguno no hay nada que forjar.
	var metales: Array = [] if bases.is_empty() else Game.metales_conocidos_de(bases[0])
	var tiers: Array = MenuScaffold.tiers_de(metales)
	if tiers.is_empty():
		t.stacks = []
		t.grid_detail([], func(_vb): pass,
			"No conoces ningún metal todavía. Pica una veta en la mazmorra y vuelve.")
		return
	if not tiers.has(_tier):
		_tier = int(tiers[0])
	if tiers.size() > 1:
		var nombres: Array = []
		var iconos: Array = []
		for tr in tiers:
			nombres.append("Tier %d" % int(tr))
			iconos.append("tier_%d" % int(tr))
		MenuScaffold.subpestanas(t.barra_sub2, nombres, iconos, tiers.find(_tier),
			func(i: int) -> void: _on_tier(int(tiers[i])))
	t.stacks = bases
	var metal: MaterialData = _metal(bases[0])
	t.contador("%s  ·  %d unidades" % [metal.nombre, Game.disponible_unidades_material_en_hogar(metal)]
		if metal != null else "")
	var piezas: Array = []
	for b in bases:
		var base: Resource = b
		# Sin pie: el tier ya lo dice la muesca de la esquina.
		piezas.append({"item": vitrina(base, _tier), "pie": "", "marca": "", "activo": true,
			"tooltip": "%s  ·  T%d" % [str(base.get("nombre")), _tier]})
	t.grid_detail(piezas, _ficha)


# Las piezas del filtro elegido, ya cargadas.
func _bases() -> Array:
	var rutas: Array = []
	match catalogo:
		Catalogo.CARPINTERIA:
			for r in CAT_ARMAS + CAT_SECUNDARIAS:
				var b: Resource = load(r)
				if b != null and Game._es_arma_magica(b):
					rutas.append(r)
		Catalogo.CUERO:
			for slot in Game.ARMOR_SLOT_ORDEN:
				rutas.append("res://resources/armor/cuero_%s.tres" % slot)
		_:
			var nombres: Array = []
			var iconos: Array = []
			for f in FILTROS_HERRERIA:
				nombres.append(f["nombre"])
				iconos.append(f["icono"])
			_filtro = clampi(_filtro, 0, FILTROS_HERRERIA.size() - 1)
			MenuScaffold.subpestanas(t.barra_sub, nombres, iconos, _filtro, _on_filtro)
			var f: Dictionary = FILTROS_HERRERIA[_filtro]
			if f.has("juego"):
				for slot in Game.ARMOR_SLOT_ORDEN:
					rutas.append("res://resources/armor/%s_%s.tres" % [f["juego"], slot])
			else:
				# Las magicas se forjan en la carpinteria.
				for r in (CAT_ARMAS if _filtro == 0 else CAT_SECUNDARIAS):
					var b2: Resource = load(r)
					if b2 != null and not Game._es_arma_magica(b2):
						rutas.append(r)
			t.titulo_seccion("Forjar  ·  %s" % f["nombre"])
	var out: Array = []
	for r in rutas:
		var base: Resource = load(r)
		if base != null:
			out.append(base)
	return out


func _on_filtro(i: int) -> void:
	if i == _filtro:
		return
	_filtro = i
	limpiar()
	t.cambiar_pantalla()


func _on_tier(tier: int) -> void:
	if tier == _tier:
		return
	_tier = tier
	limpiar()   # otro metal, otras existencias: lo elegido ya no vale
	t.rebuild()


# El metal del tier elegido para esta pieza (el de banda base: forjar no pide sub-tier).
func _metal(base: Resource) -> MaterialData:
	for m in Game.metales_conocidos_de(base):
		if Forge.tier_de_metal(m as MaterialData) == _tier:
			return m
	return null


# ============================================================
#  LA FICHA
# ============================================================

func _ficha(vb: VBoxContainer) -> void:
	var base: Resource = t.stacks[t.sel]
	var metal: MaterialData = _metal(base)
	MenuScaffold.titulo_item(vb, "%s  ·  T%d" % [str(base.get("nombre")), _tier], IconoItem.color_tier(_tier))
	var etiqueta: String = NOMBRE_RANURA.get(Game.ARMOR_SLOT_ORDEN[clampi(int((base as ArmorData).slot), 0, 4)], "") \
		if base is ArmorData else ""
	MenuScaffold.banner_item(vb, vitrina(base, _tier), "", etiqueta)
	if metal == null:
		t.note(vb, "No conoces el metal de este tier.")
		return

	var ings: Array = Game.ingredientes_forja(base, metal)
	if _sel.size() != ings.size():
		_sel = []
		for _i in ings.size():
			_sel.append({})
	for ing in ings:
		if ing["material"] == null:
			vb.add_child(HSeparator.new())
			t.note(vb, "No hay con qué rematar una pieza de este tier: le falta un material a su altura (el cuero o el tablón de este tier aún no existe). De momento este tier no se forja.")
			t.reservar({})
			return
	_capar_y_reservar(ings)

	var piezas: int = Game.piezas_de_seleccion_forja(base, metal, _sel)
	var cuantas: int = maxi(1, piezas)
	vb.add_child(HSeparator.new())
	MenuScaffold.titulo(vb, "LO QUE LLEVA", 13)
	var cols := GridContainer.new()
	cols.columns = mini(columnas_ing, ings.size())
	cols.add_theme_constant_override("h_separation", 12)
	cols.add_theme_constant_override("v_separation", 12)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(cols)
	for i in ings.size():
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		col.add_theme_constant_override("separation", 2)
		cols.add_child(col)
		ingrediente(t, col, ings[i]["material"], _sel[i], int(ings[i]["uds"]) * cuantas, t.rebuild)
	t.note(vb, "Puro = 4 unidades · intacto = 3 · normal = 2 · dañado = 1. Meter buen material no abarata la pieza: mejora la RAREZA que te va a tocar.")

	vb.add_child(HSeparator.new())
	_rareza(vb, base, metal, piezas)
	_pie(base, metal, piezas)


# El empujon de oficio de esta pieza: Carpinteria (magicas), Peleteria (cuero) o Herreria.
func _oficio(base: Resource) -> float:
	return Forge.bonus_herreria(Game._oficio_forja_activo(base))


func _rareza(vb: VBoxContainer, base: Resource, metal: MaterialData, piezas: int) -> void:
	var oficio: float = _oficio(base)
	var bono_metal: float = Forge.bonus_metal(metal)
	if piezas > 1:
		var materiales: Array = []
		for lote in Game.lotes_forja(base, metal, _sel, piezas):
			materiales.append(Game.score_uds(lote))
		var tramos: Array = MenuScaffold.tramos_por_calidad(materiales, MAX_COLUMNAS_RAREZA)
		if tramos.size() > 1:
			MenuScaffold.titulo(vb, "RAREZA QUE PUEDE SALIR  ·  %d piezas, cada una con su material" % piezas, 13)
			rejilla_rareza(t, vb, materiales, tramos, oficio, bono_metal)
			return
	var material: float = Game.score_material_forja(base, metal, _sel)
	MenuScaffold.titulo(vb, "RAREZA QUE PUEDE SALIR%s" % (
		"" if piezas <= 1 else "  ·  %d piezas con el mismo material" % piezas), 13)
	var score: float = Forge.score_final(material, oficio, bono_metal)
	# Lo que aporta el TIER solo se dice cuando aporta: casi siempre es cero (ver Forge.score_final).
	var tier_pct: int = roundi((score - Forge.score_final(material, oficio, 0.0)) * 100.0)
	t.note(vb, "Calidad del material %d%%%s" % [roundi(material * 100.0),
		"" if tier_pct == 0 else "  +  categoría %+d%%" % tier_pct])
	var probs: Array = Forge.probs_rareza(score)
	for i in probs.size():
		var p: float = float(probs[i])
		if p <= 0.0:
			continue
		t.row(vb, Upgrades.rareza_nombre(i), "%s%%   ·  %d huecos de mejora" % [
			str(snappedf(p * 100.0, 0.1)), Upgrades.rareza_slots(i)], Upgrades.rareza_color(i))


# ============================================================
#  EL PIE FIJO
# ============================================================

func _pie(base: Resource, metal: MaterialData, piezas: int) -> void:
	var vb: VBoxContainer = t.acciones()
	vb.add_child(HSeparator.new())
	fila_autos(vb, _cantidad, func(v: int) -> void: _cantidad = v,
		func(mejor: bool) -> void: _on_auto(base, metal, mejor),
		func() -> void:
			limpiar()
			t.rebuild())
	var verbo: String = "Coser" if catalogo == Catalogo.CUERO else "Forjar"
	var txt: String = "Faltan materiales"
	if piezas == 1:
		txt = verbo
	elif piezas > 1:
		txt = "%s (%d piezas)" % [verbo, piezas]
	MenuScaffold.pastilla(vb, txt, func() -> void: _forjar(base, metal), true, piezas >= 1)


func _on_auto(base: Resource, metal: MaterialData, mejor_primero: bool) -> void:
	var ings: Array = Game.ingredientes_forja(base, metal)
	var cant: int = _cantidad
	_sel = []
	for ing in ings:
		var mat: MaterialData = ing["material"]
		_sel.append({} if mat == null else auto_sel(t, mat, int(ing["uds"]) * maxi(1, cant), mejor_primero))
	t.rebuild()


func _forjar(base: Resource, metal: MaterialData) -> void:
	if Net.activo and not await Net.hogar.abrir_taller():
		t.ocupado()
		t.rebuild()
		return
	# TANDA: cada pieza con su lote de material y su tirada (ver Game.forjar_tanda).
	var items: Array = Game.forjar_tanda(base, metal, _sel, Game.piezas_de_seleccion_forja(base, metal, _sel))
	if Net.activo:
		Net.hogar.cerrar_taller()
		Net.hogar.liberar_mis_reservas()
	var verbo: String = "Coses" if catalogo == Catalogo.CUERO else "Forjas"
	if items.size() == 1:
		t.decir("%s %s. Está en tu baúl: equípalo en el menú de personaje [C]." % [verbo, Game.item_display_name(items[0])])
	elif items.size() > 1:
		var nombres: PackedStringArray = []
		for it in items:
			nombres.append(Game.item_display_name(it as Resource))
		t.decir("%s %d piezas: %s. Están en tu baúl [C]." % [verbo, items.size(), ", ".join(nombres)])
	else:
		t.decir("Te faltan materiales.", false)
	limpiar()
	t.rebuild()


# MULTI: capa la seleccion a lo DISPONIBLE (por si el compañero reservó de lo mismo) y la reserva.
func _capar_y_reservar(ings: Array) -> void:
	var claim: Dictionary = {}
	for i in mini(ings.size(), _sel.size()):
		capar(ings[i]["material"], _sel[i], claim)
	t.reservar(claim)


# ============================================================
#  PIEZAS QUE COMPARTEN LAS PANTALLAS DE LA FORJA (forjar y herramientas)
# ============================================================

# Capa 'sel' a lo disponible de 'mat' y suma lo que queda a 'claim' {"mat_id|cal": n}.
static func capar(mat: MaterialData, sel: Dictionary, claim: Dictionary) -> void:
	if mat == null:
		return
	for cal in sel.keys():
		var disp: int = Game.disponible_calidad_en_hogar(mat, int(cal))
		var n: int = clampi(int(sel[cal]), 0, disp)
		if n <= 0:
			sel.erase(cal)
		else:
			sel[cal] = n
			var clave: String = "%s|%d" % [mat.id, int(cal)]
			claim[clave] = int(claim.get(clave, 0)) + n


# Rellena una seleccion con `necesita` unidades de `mat`, de mejor a peor (o al reves). Lee lo
# DISPONIBLE: en multijugador no se pide lo que el compañero tiene reservado.
static func auto_sel(armazon, mat: MaterialData, necesita: int, mejor_primero: bool) -> Dictionary:
	var sel: Dictionary = {}
	var restante: int = necesita
	var orden: Array = (armazon.CALIDADES as Array).duplicate()
	if not mejor_primero:
		orden.reverse()
	for cal in orden:
		if restante <= 0:
			break
		var disp: int = Game.disponible_calidad_en_hogar(mat, int(cal))
		var uds: int = MaterialItem.crear(null, int(cal)).unidades_crafteo()
		if disp <= 0 or uds <= 0:
			continue
		var usar: int = mini(int(ceil(float(restante) / float(uds))), disp)
		if usar > 0:
			sel[cal] = usar
			restante -= usar * uds
	return sel


# UN INGREDIENTE en su columna: su celda, "puestas / necesita" y una fila de contador por calidad.
# 'repintar' se llama al cambiar un contador (no a cada tecla: ver MenuScaffold.stepper).
static func ingrediente(armazon, vb: VBoxContainer, mat: MaterialData, sel: Dictionary, necesita: int,
		repintar: Callable) -> void:
	var puestas: int = Game.uds_seleccion(sel)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	MenuScaffold.celda_suelta(fila, mat, LADO_CELDA_ING, "T%d" % int(mat.tier))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nom := Label.new()
	nom.text = mat.nombre
	nom.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	col.add_child(nom)
	var val := Label.new()
	val.text = "%d / %d unidades" % [puestas, necesita]
	val.add_theme_color_override("font_color", armazon.VERDE if puestas >= necesita else armazon.ROJO)
	col.add_child(val)
	fila.add_child(col)
	vb.add_child(fila)

	# Si te pasas, decir lo que se gasta DE VERDAD (el resto se queda en el Hogar).
	if puestas >= necesita and necesita > 0:
		var gasto: Dictionary = Game.recortar_seleccion(sel, necesita)
		var gastadas: int = Game.uds_seleccion(gasto)
		var sobra: int = gastadas - necesita
		var partes: PackedStringArray = []
		if puestas > gastadas:
			partes.append("se gastan %d uds y el resto se queda en el Hogar" % gastadas)
		if sobra > 0:
			partes.append("sobran %d uds del recorte: vuelven como %d dañado(s)" % [sobra, sobra])
		if not partes.is_empty():
			armazon.note(vb, "; ".join(partes) + ".")

	var hubo: bool = false
	for cal in armazon.CALIDADES:
		var disp: int = Game.disponible_calidad_en_hogar(mat, int(cal))
		if disp <= 0:
			continue
		hubo = true
		var ci: int = int(cal)
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		var lab := Label.new()
		lab.text = "%s (%d)" % [armazon.cal_txt(ci), disp]
		lab.custom_minimum_size = Vector2(110, 0)
		lab.add_theme_color_override("font_color", MaterialItem.crear(mat, ci).color())
		r.add_child(lab)
		MenuScaffold.stepper(r, int(sel.get(cal, 0)), 0, disp,
			func(n: int) -> void: _poner(sel, ci, disp, n, repintar),
			func(n: int) -> void: _poner(sel, ci, disp, n, Callable()))
		vb.add_child(r)
	if not hubo:
		armazon.note(vb, "No tienes %s en el Hogar." % mat.nombre.to_lower())


# Fija la cantidad de 'cal' en 'sel'. Con 'repintar' vacio se esta ESCRIBIENDO: se guarda y ya (el
# campo sigue vivo); el repintado llega al salir del campo, desde el on_set.
#
# NO repinta si nada ha cambiado: el focus_exited del campo, al liberarse en el propio repintado,
# vuelve a llamar aqui, y repintar otra vez era un bucle.
static var _escrito_sin_repintar := false

static func _poner(sel: Dictionary, cal: int, disp: int, n: int, repintar: Callable) -> void:
	var nuevo: int = clampi(n, 0, disp)
	var cambia: bool = nuevo != int(sel.get(cal, 0))
	if cambia:
		if nuevo <= 0:
			sel.erase(cal)
		else:
			sel[cal] = nuevo
	if not repintar.is_valid():
		_escrito_sin_repintar = _escrito_sin_repintar or cambia
		return
	if cambia or _escrito_sin_repintar:
		_escrito_sin_repintar = false
		repintar.call()


# La fila del pie: Cantidad (solo para los Autos), Auto ▲, Auto ▼ y Limpiar.
static func fila_autos(vb: VBoxContainer, cantidad: int, poner_cantidad: Callable, auto: Callable,
		limpiar_sel: Callable) -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	var k := Label.new()
	k.text = "Cantidad"
	k.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	fila.add_child(k)
	MenuScaffold.stepper(fila, cantidad, 1, 99, poner_cantidad)
	var auto_mej := Button.new()
	auto_mej.text = "Auto ▲"
	auto_mej.tooltip_text = "Rellena empezando por el MEJOR material que tengas (puro, intacto...). Sube la rareza que puede salir."
	auto_mej.pressed.connect(auto.bind(true))
	fila.add_child(auto_mej)
	var auto_peor := Button.new()
	auto_peor.text = "Auto ▼"
	auto_peor.tooltip_text = "Rellena empezando por el PEOR material que tengas (dañado, normal...). Para gastar lo que sobra sin tocar lo bueno."
	auto_peor.pressed.connect(auto.bind(false))
	fila.add_child(auto_peor)
	var b_limpiar := Button.new()
	b_limpiar.text = "Limpiar"
	b_limpiar.pressed.connect(limpiar_sel)
	fila.add_child(b_limpiar)
	vb.add_child(fila)


# La rejilla de una TANDA: una columna por tramo de piezas iguales, una fila por rareza. 'efectos'
# (opcional) = lo que da cada rareza, en la ultima columna.
static func rejilla_rareza(armazon, vb: VBoxContainer, materiales: Array, tramos: Array, oficio: float,
		bono_metal: float, efectos: Array = [], cab_efecto: String = "") -> void:
	var corto: bool = tramos.size() > 6
	var cabeceras: Array = []
	var calidad: Array = []
	var tier_pct: Array = []
	var aporta: bool = false
	var probs_col: Array = []
	var sale: Dictionary = {}
	for tramo in tramos:
		var mat_c: float = float(materiales[int(tramo["i"])])
		cabeceras.append(MenuScaffold.numeros_tramo(tramo))
		calidad.append("%d%%" % roundi(mat_c * 100.0))
		var p_t: int = roundi((Forge.score_final(mat_c, oficio, bono_metal)
			- Forge.score_final(mat_c, oficio, 0.0)) * 100.0)
		tier_pct.append("%+d%%" % p_t)
		aporta = aporta or p_t != 0
		var probs: Array = Forge.probs_rareza(Forge.score_final(mat_c, oficio, bono_metal))
		probs_col.append(probs)
		for i in probs.size():
			if float(probs[i]) > 0.0:
				sale[i] = true
	var filas: Array = [{"etiqueta": "calidad", "color": armazon.GRIS, "valores": calidad}]
	if aporta:
		filas.append({"etiqueta": "categoría", "color": armazon.GRIS, "valores": tier_pct})
	var rarezas: Array = sale.keys()
	rarezas.sort()
	for r in rarezas:
		var valores: Array = []
		for c in probs_col.size():
			var p: float = float((probs_col[c] as Array)[int(r)])
			if p <= 0.0:
				valores.append(MenuScaffold.GUION)
			else:
				valores.append("%d%%" % roundi(p * 100.0) if corto else "%s%%" % str(snappedf(p * 100.0, 0.1)))
		filas.append({"etiqueta": Upgrades.rareza_nombre(int(r)), "color": Upgrades.rareza_color(int(r)),
			"valores": valores, "extra": str(efectos[int(r)]) if int(r) < efectos.size() else ""})
	MenuScaffold.rejilla_probs(vb, "pieza", cabeceras, filas, cab_efecto, vb.size.x)
