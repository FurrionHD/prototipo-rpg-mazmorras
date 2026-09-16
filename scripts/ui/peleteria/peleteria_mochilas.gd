# ============================================================
#  peleteria_mochilas.gd  --  pestaña MOCHILAS de la peleteria (ver tannery_menu.gd, el armazon).
#
#  Hebillas (de la herreria) + correas + cuero curtido -> MOCHILA. Es lo unico que sube tu capacidad
#  de carga. A diferencia del refinado de al lado, aqui SI se mezclan calidades: la media tira la
#  RAREZA, que es lo unico que diferencia una mochila (no lleva mejoras). El TIER lo ponen las
#  hebillas, y la correa y el cuero son los de ESE tier: las hebillas mandan y la cadena las sigue.
#
#  LA REJILLA SON LOS METALES de hebilla, uno por celda con su tier. La ficha, ANCHA (ver
#  ANCHO_FICHA_MOCHILA), lleva los tres ingredientes con su celda, sus unidades y una fila por
#  calidad; la tabla de rarezas; y en el pie fijo la cantidad, los dos Autos y Coser.
#
#  Lo que se cose de verdad sale de la SELECCION (Game.piezas_de_coste), no de la cantidad: si
#  pides 5 y solo da para 4, salen 4. La cantidad es solo para los Autos.
# ============================================================
extends RefCounted

# Tope de columnas de la rejilla de rareza de una tanda (ver MenuScaffold.tramos_por_calidad).
const MAX_COLUMNAS_RAREZA := 12
# El lado de la celdita que acompaña a cada ingrediente. Mas pequeña que la de la rejilla (96): aqui
# no se pulsa, solo dice DE QUE material estamos hablando sin tener que leerlo.
const LADO_CELDA_ING := 48.0

var t = null   # el armazon (tannery_menu.gd)
var _sel_heb: Dictionary = {}
var _sel_cor: Dictionary = {}
var _sel_cue: Dictionary = {}
# CUANTAS mochilas quieres que rellene el Auto (ver la cabecera).
var _cantidad: int = 1


func _init(armazon) -> void:
	t = armazon


func limpiar() -> void:
	_sel_heb = {}
	_sel_cor = {}
	_sel_cue = {}


# ============================================================
#  LAS COPIAS DE ESCAPARATE
#  La mochila que se enseña en la celda y en el banner es una COPIA con el tier puesto, no el .tres
#  del catalogo: Game.meta_de le crearia meta T1 al .tres COMPARTIDO y la mochila T2 saldria diciendo
#  T1 (pasa igual en la tienda, ver shop_menu.vitrina). Se crean sin registrar -- si no, irian a
#  parar a tu baul -- y sus metas se borran al cerrar, o quedarian colgando para siempre.
# ============================================================

var _vitrina_tier: Dictionary = {}

func _vitrina(tier: int) -> Resource:
	if not _vitrina_tier.has(tier):
		_vitrina_tier[tier] = Game.crear_item(Game.mochila_base(), tier, Upgrades.Rareza.COMUN, {}, false)
	return _vitrina_tier[tier]


func vaciar_vitrina() -> void:
	for copia in _vitrina_tier.values():
		Game.item_meta.erase(copia)
	_vitrina_tier.clear()


# ============================================================
#  PINTAR
# ============================================================

func build() -> void:
	# Solo los metales que conoces (mismo criterio que la herreria: ver Game.materiales_vistos).
	var hebillas: Array = Game.hebillas_conocidas()
	t.stacks = hebillas
	t.contador("Llevas %d de capacidad" % roundi(Game.capacidad_carga()))
	var piezas: Array = []
	for h in hebillas:
		var heb: MaterialData = h as MaterialData
		var uds: int = Game.disponible_unidades_material_en_hogar(heb)
		var tier: int = Forge.tier_de_metal(heb)
		# EL DIBUJO ES LA MOCHILA QUE SALE, no las hebillas que metes (lo pidio el usuario). Va con
		# una COPIA DE ESCAPARATE para que la muesca diga su tier de verdad: el .tres del catalogo no
		# tiene tier y las dos celdas dirian T1 (la misma trampa que la vitrina de la tienda).
		piezas.append({"item": _vitrina(tier), "pie": "T%d" % tier, "marca": "",
			"tooltip": "Mochila T%d  ·  hebillas de %s  ·  tienes %d unidades" % [
				tier, heb.nombre.to_lower(), uds], "activo": true})
	t.grid_detail(piezas, _ficha,
		"No conoces ningún metal, y sin hebillas no hay mochila que valga. Pica una veta y pásate por la herrería.")


func _ficha(vb: VBoxContainer) -> void:
	var heb: MaterialData = t.stacks[t.sel] as MaterialData
	var tier: int = Forge.tier_de_metal(heb)
	# La CORREA y el CUERO son los de ESE tier, no los de T1. Si a ese tier aun no le existe su
	# correa (o su curtido), no hay mochila que coser y se dice, en vez de dejarte pelear con
	# contadores vacios.
	var cor: MaterialData = Game.correa_de_mochila(heb)
	var cue: MaterialData = Game.cuero_de_mochila(heb)

	MenuScaffold.titulo_item(vb, "Mochila  ·  T%d" % tier, IconoItem.color_tier(tier))
	# El nombre del material YA dice "Hebillas de cobre": ponerle delante otro "Hebillas de" dejaba
	# un "Hebillas de hebillas de cobre" (el mismo error que se cazo en la forja).
	MenuScaffold.banner_item(vb, _vitrina(tier), "", heb.nombre)
	if cor == null or cue == null:
		t.note(vb, "Todavía no hay correas ni cuero a la altura del T%d: esa mochila no se puede coser aún." % tier)
		return

	# MULTI: capar cada seleccion a lo disponible (por si el compañero reservó de lo mismo)...
	_capar(heb, _sel_heb)
	_capar(cor, _sel_cor)
	_capar(cue, _sel_cue)
	# ... y publicar las tres como MI reserva, para que el otro las vea apartadas en vivo.
	if Net.activo:
		var claim: Dictionary = {}
		_sumar_claim(claim, heb, _sel_heb)
		_sumar_claim(claim, cor, _sel_cor)
		_sumar_claim(claim, cue, _sel_cue)
		Net.hogar.reservar(claim)

	# CUANTAS mochilas salen con lo elegido: los contadores cuentan la TANDA entera, no una pieza.
	var coste: Dictionary = Game.MOCHILA_COSTE
	var mats: Array = [heb, cor, cue]
	var sels: Array = [_sel_heb, _sel_cor, _sel_cue]
	var uds: Array = [int(coste["hebillas"]), int(coste["correa"]), int(coste["cuero"])]
	var piezas: int = Game.piezas_de_coste(mats, sels, uds)
	var cuantas: int = maxi(1, piezas)

	vb.add_child(HSeparator.new())
	MenuScaffold.titulo(vb, "LO QUE LLEVA", 13)
	# LOS TRES INGREDIENTES, UNO POR COLUMNA. En vertical eran doce renglones (tres materiales por
	# hasta cuatro calidades) y la ficha salia con scroll, con la tabla de rarezas fuera de la vista
	# y medio monitor en blanco al lado. Los tres caben de sobra en el ancho de esta pestaña.
	var cols := GridContainer.new()
	cols.columns = mats.size()
	# Justo: cada columna pide etiqueta (95) + el − n + (168), asi que con 18 de separacion las tres
	# se pasaban del ancho de la ficha y el "+" de la ultima se salia de la pantalla (visto en
	# captura). Con 12 caben con sitio de sobra.
	cols.add_theme_constant_override("h_separation", 12)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(cols)
	for i in mats.size():
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		cols.add_child(col)
		_ingrediente(col, mats[i], sels[i], int(uds[i]) * cuantas)
	t.note(vb, "Puro = 4 unidades · intacto = 3 · normal = 2 · dañado = 1. Meter buen material no abarata la mochila: mejora la RAREZA, y con ella lo que te cabe dentro.")

	_rarezas(vb, heb, tier, mats, sels, uds, piezas)
	_pie(heb, piezas)


# ============================================================
#  UN INGREDIENTE: su celda, lo que llevas puesto y una fila por calidad
# ============================================================

func _ingrediente(vb: VBoxContainer, mat: MaterialData, sel: Dictionary, necesita: int) -> void:
	var puestas: int = Game.uds_seleccion(sel)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	# LA CELDA del material, del mismo dibujo que la rejilla: se ve de que estamos hablando sin
	# leerlo. Antes esto era el nombre escrito y nada mas, y "cuero curtido" y "cuero reforzado" son
	# dos lineas casi iguales.
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
	val.add_theme_color_override("font_color", t.VERDE if puestas >= necesita else t.ROJO)
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
			t.note(vb, "   " + "; ".join(partes) + ".")

	var hubo: bool = false
	for cal in t.CALIDADES:
		var disp: int = Game.disponible_calidad_en_hogar(mat, int(cal))   # resta lo reservado
		if disp <= 0:
			continue
		hubo = true
		var ci: int = int(cal)
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		var lab := Label.new()
		lab.text = "%s (%d)" % [t.cal_txt(ci), disp]
		lab.custom_minimum_size = Vector2(95, 0)
		lab.add_theme_color_override("font_color", MaterialItem.crear(mat, ci).color())
		r.add_child(lab)
		MenuScaffold.stepper(r, int(sel.get(cal, 0)), 0, disp,
			func(n: int) -> void: _set_sel(sel, ci, disp, n),
			func(n: int) -> void: _set_sel(sel, ci, disp, n, false))
		vb.add_child(r)
	if not hubo:
		t.note(vb, "   No tienes %s en el Hogar." % mat.nombre.to_lower())


# ============================================================
#  LA RAREZA QUE PUEDE SALIR
# ============================================================

func _rarezas(vb: VBoxContainer, heb: MaterialData, tier: int, mats: Array, sels: Array,
		uds: Array, piezas: int) -> void:
	vb.add_child(HSeparator.new())
	# Con una TANDA, cada mochila se cose con SU lote de material (el mejor va a las primeras, ver
	# Game.lotes_de_seleccion) y por tanto tira su propia rareza: eso va en rejilla de columnas.
	var materiales: Array = []
	if piezas > 1:
		var gastos: Array = []
		for i in mats.size():
			gastos.append(Game.recortar_seleccion(sels[i], int(uds[i]) * piezas))
		for lote in Game.lotes_de_seleccion(gastos, uds, piezas):
			materiales.append(Game.score_uds(lote))
	var tramos: Array = MenuScaffold.tramos_por_calidad(materiales, MAX_COLUMNAS_RAREZA)
	if piezas > 1 and tramos.size() > 1:
		MenuScaffold.titulo(vb, "RAREZA QUE PUEDE SALIR  ·  %d mochilas, cada una con su material" % piezas, 13)
		# La carga de cada rareza va en la ULTIMA columna de la misma rejilla, no en una tabla aparte
		# debajo: separada, la lista de rarezas salia dos veces en la misma pantalla.
		var cargas: Array = []
		for i in Upgrades.RAREZA_NOMBRE.size():
			cargas.append("+%.0f de carga" % _carga_de(tier, i))
		_rejilla(vb, materiales, tramos, heb, cargas)
		return
	var score: float = Game.score_mochila(heb, _sel_heb, _sel_cor, _sel_cue)
	MenuScaffold.titulo(vb, "RAREZA QUE PUEDE SALIR%s" % (
		"" if piezas <= 1 else "  ·  %d mochilas con el mismo material" % piezas), 13)
	var probs: Array = Forge.probs_rareza(score)
	for i in probs.size():
		var p: float = float(probs[i])
		if p <= 0.0:
			continue
		t.row(vb, Upgrades.rareza_nombre(i), "%s%%   →  +%.0f de carga" % [
			str(snappedf(p * 100.0, 0.1)), _carga_de(tier, i)], Upgrades.rareza_color(i))


# La rejilla de una tanda: una columna por tramo de piezas iguales, una fila por rareza. Misma forma
# que la de la forja (MenuScaffold.rejilla_probs), que las dos tiran con score_final.
func _rejilla(vb: VBoxContainer, materiales: Array, tramos: Array, heb: MaterialData, cargas: Array) -> void:
	var oficio: float = Forge.bonus_herreria(Game.peleteria_activa())
	var bono_metal: float = Forge.bonus_metal(heb)
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
		# El empujon del TIER solo se enseña si empuja: con hebillas T1, o con material intacto (el
		# tope de score_final no le deja sumar), es siempre cero.
		var p_t: int = roundi((Forge.score_final(mat_c, oficio, bono_metal)
			- Forge.score_final(mat_c, oficio, 0.0)) * 100.0)
		tier_pct.append("%+d%%" % p_t)
		aporta = aporta or p_t != 0
		var probs: Array = Forge.probs_rareza(Forge.score_final(mat_c, oficio, bono_metal))
		probs_col.append(probs)
		for i in probs.size():
			if float(probs[i]) > 0.0:
				sale[i] = true
	var filas: Array = [{"etiqueta": "calidad", "color": t.GRIS, "valores": calidad}]
	if aporta:
		filas.append({"etiqueta": "categoría", "color": t.GRIS, "valores": tier_pct})
	var rarezas: Array = sale.keys()
	rarezas.sort()
	for r in rarezas:
		var valores: Array = []
		for c in probs_col.size():
			var p: float = float((probs_col[c] as Array)[int(r)])
			if p <= 0.0:
				valores.append(MenuScaffold.GUION)
			else:
				valores.append("%d%%" % roundi(p * 100.0) if corto
					else "%s%%" % str(snappedf(p * 100.0, 0.1)))
		filas.append({"etiqueta": Upgrades.rareza_nombre(int(r)),
			"color": Upgrades.rareza_color(int(r)), "valores": valores,
			"extra": str(cargas[int(r)]) if int(r) < cargas.size() else ""})
	MenuScaffold.rejilla_probs(vb, "pieza", cabeceras, filas, "aporta", vb.size.x)


# Lo que daria una mochila de este tier y esta rareza (derivado, nunca escrito a mano).
func _carga_de(tier: int, rareza: int) -> float:
	return Game.mochila_base().capacidad * Game.mochila_tier_factor(tier) \
		* Upgrades.rareza_mult_capacidad(rareza)


# ============================================================
#  EL PIE FIJO: cantidad, los dos Autos y Coser
# ============================================================

func _pie(heb: MaterialData, piezas: int) -> void:
	var vb: VBoxContainer = t.acciones()
	vb.add_child(HSeparator.new())
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	var k := Label.new()
	k.text = "Cantidad"
	k.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	fila.add_child(k)
	MenuScaffold.stepper(fila, _cantidad, 1, 99, func(v: int) -> void: _cantidad = v)
	var auto_mej := Button.new()
	auto_mej.text = "Auto ▲"
	auto_mej.tooltip_text = "Rellena empezando por el MEJOR material que tengas (puro, intacto...). Sube la rareza que puede salir."
	auto_mej.pressed.connect(_on_auto.bind(true))
	fila.add_child(auto_mej)
	var auto_peor := Button.new()
	auto_peor.text = "Auto ▼"
	auto_peor.tooltip_text = "Rellena empezando por el PEOR material que tengas (dañado, normal...). Para gastar lo que sobra sin tocar lo bueno."
	auto_peor.pressed.connect(_on_auto.bind(false))
	fila.add_child(auto_peor)
	var limpiar := Button.new()
	limpiar.text = "Limpiar"
	limpiar.pressed.connect(func() -> void:
		limpiar_seleccion())
	fila.add_child(limpiar)
	vb.add_child(fila)

	var txt: String = "Faltan materiales"
	if piezas == 1:
		txt = "Coser la mochila"
	elif piezas > 1:
		txt = "Coser (%d mochilas)" % piezas
	MenuScaffold.pastilla(vb, txt, func() -> void: _coser(heb), true, piezas >= 1)


func limpiar_seleccion() -> void:
	limpiar()
	t.rebuild()


# Los dos Autos: ▲ empieza por el mejor material, ▼ por el peor. Rellenan para `_cantidad` mochilas;
# si no llega, rellenan lo que salga (el boton de coser ya dice cuantas cubre eso).
func _on_auto(mejor_primero: bool) -> void:
	var hebillas: Array = Game.hebillas_conocidas()
	if hebillas.is_empty():
		return
	var heb: MaterialData = hebillas[clampi(t.sel, 0, hebillas.size() - 1)]
	var cor: MaterialData = Game.correa_de_mochila(heb)
	var cue: MaterialData = Game.cuero_de_mochila(heb)
	if cor == null or cue == null:
		return
	var veces: int = maxi(1, _cantidad)
	var coste: Dictionary = Game.MOCHILA_COSTE
	_sel_heb = _auto_sel(heb, int(coste["hebillas"]) * veces, mejor_primero)
	_sel_cor = _auto_sel(cor, int(coste["correa"]) * veces, mejor_primero)
	_sel_cue = _auto_sel(cue, int(coste["cuero"]) * veces, mejor_primero)
	t.rebuild()


# Rellena una seleccion con `necesita` unidades de `mat`, de mejor a peor (o al reves). Lee lo
# DISPONIBLE, no el stock a secas: en multijugador no se pide lo que el compañero tiene reservado.
func _auto_sel(mat: MaterialData, necesita: int, mejor_primero: bool) -> Dictionary:
	var sel: Dictionary = {}
	var restante: int = necesita
	var orden: Array = (t.CALIDADES as Array).duplicate()
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


func _coser(heb: MaterialData) -> void:
	if Net.activo and not await Net.hogar.abrir_taller():
		t.ocupado()
		t.rebuild()
		return
	# TANDA: se cosen todas las que cubra lo elegido, cada una con su lote de material y su tirada.
	var coste: Dictionary = Game.MOCHILA_COSTE
	var piezas: int = Game.piezas_de_coste(
		[heb, Game.correa_de_mochila(heb), Game.cuero_de_mochila(heb)],
		[_sel_heb, _sel_cor, _sel_cue],
		[int(coste["hebillas"]), int(coste["correa"]), int(coste["cuero"])])
	var hechas: Array = Game.fabricar_mochila_tanda(heb, _sel_heb, _sel_cor, _sel_cue, piezas)
	if Net.activo:
		Net.hogar.cerrar_taller()
		Net.hogar.liberar_mis_reservas()   # consumido: suelto la reserva
	if hechas.size() == 1:
		t.decir("Coses %s: +%.0f de carga. Equípala en el menú de personaje [C]." % [
			Game.item_display_name(hechas[0]), Game.capacidad_mochila(hechas[0] as BackpackData)])
	elif hechas.size() > 1:
		var nombres: PackedStringArray = []
		for m in hechas:
			nombres.append(Game.item_display_name(m as Resource))
		t.decir("Coses %d mochilas: %s. Están en tu baúl [C]." % [hechas.size(), ", ".join(nombres)])
	else:
		t.decir("Te faltan materiales.", false)
	limpiar()
	t.rebuild()


# ============================================================
#  MULTI: capar y publicar la seleccion
# ============================================================

# Capa una seleccion {cal: count} a lo DISPONIBLE de 'mat' (resta lo reservado por el otro).
func _capar(mat: MaterialData, sel: Dictionary) -> void:
	if mat == null:
		return
	for cal in sel.keys():
		var disp: int = Game.disponible_calidad_en_hogar(mat, int(cal))
		var n: int = clampi(int(sel[cal]), 0, disp)
		if n <= 0:
			sel.erase(cal)
		else:
			sel[cal] = n


# Suma una seleccion {cal: count} de 'mat' al claim {"mat_id|cal": count}.
func _sumar_claim(claim: Dictionary, mat: MaterialData, sel: Dictionary) -> void:
	if mat == null:
		return
	for cal in sel:
		var n: int = int(sel[cal])
		if n > 0:
			var clave: String = "%s|%d" % [mat.id, int(cal)]
			claim[clave] = int(claim.get(clave, 0)) + n


# Fija (absoluto) la cantidad elegida de `cal` en `sel`, acotada a `disp`. Lo llama el stepper
# editable. No rebuildea si no cambia (evita el bucle de focus_exited al liberar el LineEdit).
# repintar=false: se esta ESCRIBIENDO; se guarda ya y se repinta al salir del campo.
var _escrito_sin_repintar := false

func _set_sel(sel: Dictionary, cal: int, disp: int, n: int, repintar: bool = true) -> void:
	var nuevo: int = clampi(n, 0, disp)
	var cambia: bool = nuevo != int(sel.get(cal, 0))
	if cambia:
		if nuevo <= 0:
			sel.erase(cal)
		else:
			sel[cal] = nuevo
	if not repintar:
		_escrito_sin_repintar = _escrito_sin_repintar or cambia
		return
	if cambia or _escrito_sin_repintar:
		_escrito_sin_repintar = false
		t.rebuild()
