# ============================================================
#  herreria_herramientas.gd  --  FORJAR UNA HERRAMIENTA (pico, hoz, hacha, caña, farolillo, cuchillo).
#  Ver forge_menu.gd, el armazon.
#
#  Hermana de la mochila: coste FIJO, dos ingredientes (metal + tablon, o hebillas en el farolillo) y
#  la rareza como unico eje de calidad. Lo que la distingue de TODO lo demas del herrero es que aqui SI
#  cuenta la VETA del metal (en bruto, veteado, profundo): ver Game.lingotes_herramienta.
#
#  LA REJILLA SON LAS HERRAMIENTAS, y la celda pinta la que saldria con el tier y la veta elegidos.
#  Encima, dos filas: el tier y la veta de ese tier. La ficha lleva los dos ingredientes en columnas,
#  la rareza con LO QUE DA cada una (golpes ahorrados, o alcance en el farolillo) y lo que llevas ahora.
# ============================================================
extends RefCounted

const HerreriaForjar = preload("res://scripts/ui/herreria/herreria_forjar.gd")

# Las que se forjan, en el orden de la rejilla.
const TIPOS: Array = [ToolData.Tipo.PICO, ToolData.Tipo.HOZ, ToolData.Tipo.HACHA,
	ToolData.Tipo.CANA, ToolData.Tipo.LAMPARA, ToolData.Tipo.CUCHILLO]
const MAX_COLUMNAS_RAREZA := 12

var t = null   # el armazon (forge_menu.gd)
var _tier_idx: int = 0
var _veta_idx: int = 0
var _sel_met: Dictionary = {}
var _sel_tab: Dictionary = {}
var _cantidad: int = 1


func _init(armazon) -> void:
	t = armazon


func limpiar() -> void:
	_sel_met = {}
	_sel_tab = {}
	_cantidad = 1


var _vitrina: Dictionary = {}

func _vitrina_de(tipo: int, tier: int, banda: int) -> Resource:
	var clave: String = "%d|%d|%d" % [tipo, tier, banda]
	if not _vitrina.has(clave):
		_vitrina[clave] = Game.crear_item(Game.herramienta_base(tipo), tier, Upgrades.Rareza.COMUN, {},
			false, banda)
	return _vitrina[clave]


func vaciar_vitrina() -> void:
	for copia in _vitrina.values():
		Game.item_meta.erase(copia)
	_vitrina.clear()


# ============================================================
#  PINTAR
# ============================================================

func build() -> void:
	var lingote: MaterialData = _lingote(true)
	if lingote == null:
		t.stacks = []
		t.grid_detail([], func(_vb): pass, "No conoces ningún metal. Pica una veta y vuelve.")
		return
	var tier: int = Forge.tier_de_metal(lingote)
	var banda: int = int(lingote.mejora_min)
	t.stacks = TIPOS
	t.contador("%s  ·  %d unidades" % [lingote.nombre, Game.disponible_unidades_material_en_hogar(lingote)])
	var piezas: Array = []
	for tp in TIPOS:
		var b: ToolData = Game.herramienta_base(int(tp))
		piezas.append({"item": _vitrina_de(int(tp), tier, banda), "pie": "", "marca": "", "activo": true,
			"tooltip": "%s  ·  %s" % [b.tipo_texto() if b != null else "?", _para_que(int(tp))]})
	t.grid_detail(piezas, _ficha)


# El lingote elegido. Con 'filtros' pinta ademas las dos filas (tier y veta).
func _lingote(filtros: bool = false) -> MaterialData:
	var lingotes: Array = Game.lingotes_herramienta()
	var tiers: Array = MenuScaffold.tiers_de(lingotes)
	if tiers.is_empty():
		return null
	_tier_idx = clampi(_tier_idx, 0, tiers.size() - 1)
	var vetas: Array = MenuScaffold.del_tier(lingotes, int(tiers[_tier_idx]))
	if vetas.is_empty():
		return null
	_veta_idx = clampi(_veta_idx, 0, vetas.size() - 1)
	if filtros:
		if tiers.size() > 1:
			var nombres: Array = []
			var iconos: Array = []
			for tr in tiers:
				nombres.append("Tier %d" % int(tr))
				iconos.append("tier_%d" % int(tr))
			MenuScaffold.subpestanas(t.barra_sub, nombres, iconos, _tier_idx, _on_tier)
		if vetas.size() > 1:
			var nombres2: Array = []
			var iconos2: Array = []
			for i in vetas.size():
				nombres2.append((vetas[i] as MaterialData).nombre)
				iconos2.append("veta_%d" % (i + 1))
			MenuScaffold.subpestanas(t.barra_sub2, nombres2, iconos2, _veta_idx, _on_veta)
	return vetas[_veta_idx] as MaterialData


func _on_tier(i: int) -> void:
	if i == _tier_idx:
		return
	_tier_idx = i
	_veta_idx = 0   # al cambiar de gama se vuelve a la veta base: la de abajo ya no existe
	limpiar()
	t.rebuild()


func _on_veta(i: int) -> void:
	if i == _veta_idx:
		return
	_veta_idx = i
	limpiar()
	t.rebuild()


func _para_que(tipo: int) -> String:
	match tipo:
		ToolData.Tipo.PICO: return "Vetas de mineral  ·  entrena Fuerza"
		ToolData.Tipo.HOZ: return "Plantas  ·  entrena Destreza"
		ToolData.Tipo.CANA: return "Estanques  ·  entrena Resistencia"
		ToolData.Tipo.LAMPARA: return "Ver en la oscuridad  ·  quema carbón"
		ToolData.Tipo.CUCHILLO: return "Cristales de los cuerpos  ·  entrena Destreza"
		_: return "Madera  ·  entrena Agilidad"


# ============================================================
#  LA FICHA
# ============================================================

func _ficha(vb: VBoxContainer) -> void:
	var tipo: int = int(TIPOS[t.sel])
	var lingote: MaterialData = _lingote()
	var tier: int = Forge.tier_de_metal(lingote)
	var banda: int = int(lingote.mejora_min)
	var base_t: ToolData = Game.herramienta_base(tipo)
	MenuScaffold.titulo_item(vb, "%s  ·  T%d" % [base_t.tipo_texto(), tier], IconoItem.color_tier(tier))
	MenuScaffold.banner_item(vb, _vitrina_de(tipo, tier, banda), "", _para_que(tipo))

	var tab: MaterialData = Game.complemento_de_herramienta(tipo, lingote)
	if tab == null:
		t.note(vb, "No hay %s a juego con ese metal." % ("hebillas" if tipo == ToolData.Tipo.LAMPARA else "tablón"))
		t.reservar({})
		return
	var cst: Dictionary = Game.coste_herramienta(tipo)
	var claim: Dictionary = {}
	HerreriaForjar.capar(lingote, _sel_met, claim)
	HerreriaForjar.capar(tab, _sel_tab, claim)
	t.reservar(claim)
	var piezas: int = Game.piezas_de_seleccion_herramienta(tipo, lingote, _sel_met, _sel_tab)
	var cuantas: int = maxi(1, piezas)

	vb.add_child(HSeparator.new())
	MenuScaffold.titulo(vb, "LO QUE LLEVA", 13)
	var cols := GridContainer.new()
	cols.columns = 2
	cols.add_theme_constant_override("h_separation", 12)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(cols)
	for par in [[lingote, _sel_met, int(cst["metal"])], [tab, _sel_tab, int(cst["tablon"])]]:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		col.add_theme_constant_override("separation", 2)
		cols.add_child(col)
		HerreriaForjar.ingrediente(t, col, par[0], par[1], int(par[2]) * cuantas, t.rebuild)
	if tipo == ToolData.Tipo.LAMPARA:
		t.note(vb, "El farolillo no lleva mango sino armazón, así que pide HEBILLAS en vez de tablón. Lo que sube no son golpes ahorrados sino el ALCANCE de la luz, que se encoge cuanto más hondo bajas.")
	else:
		t.note(vb, "Cuenta el TIER del metal y también su VETA: las dos suben lo que te ayuda, y la veta además te ahorra golpes. El mango va a juego con la veta; no se elige.")

	vb.add_child(HSeparator.new())
	_rareza(vb, tipo, lingote, tab, cst, piezas, tier, banda, base_t)
	vb.add_child(HSeparator.new())
	if tipo == ToolData.Tipo.LAMPARA:
		t.row(vb, "Llevas ahora", "alcance %.1f casillas" % Game.radio_lampara())
	else:
		t.row(vb, "Llevas ahora", MenuScaffold.texto_efecto_herramienta(base_t,
			Game.tool_mods(Game.herramienta_de_tipo(tipo))))
	_pie(tipo, lingote, piezas)


func _rareza(vb: VBoxContainer, tipo: int, lingote: MaterialData, tab: MaterialData, cst: Dictionary,
		piezas: int, tier: int, banda: int, base_t: ToolData) -> void:
	var efectos: Array = []
	for i in Upgrades.RAREZA_NOMBRE.size():
		efectos.append(_efecto(tipo, tier, banda, i, base_t))
	if piezas > 1:
		var materiales: Array = []
		for lote in Game.lotes_de_seleccion([
				Game.recortar_seleccion(_sel_met, int(cst["metal"]) * piezas),
				Game.recortar_seleccion(_sel_tab, int(cst["tablon"]) * piezas)],
				[int(cst["metal"]), int(cst["tablon"])], piezas):
			materiales.append(Game.score_uds(lote))
		var tramos: Array = MenuScaffold.tramos_por_calidad(materiales, MAX_COLUMNAS_RAREZA)
		if tramos.size() > 1:
			MenuScaffold.titulo(vb, "RAREZA QUE PUEDE SALIR  ·  %d herramientas" % piezas, 13)
			HerreriaForjar.rejilla_rareza(t, vb, materiales, tramos,
				Forge.bonus_herreria(Game.herreria_activa()), Forge.bonus_metal_veta(lingote),
				efectos, "aporta")
			return
	MenuScaffold.titulo(vb, "RAREZA QUE PUEDE SALIR  ·  %s" % lingote.nombre, 13)
	var probs: Array = Forge.probs_rareza(Game.score_herramienta(lingote, _sel_met, _sel_tab))
	# Cada rareza con lo que DA: con eso se ve para que sirve gastar metal bueno.
	for i in probs.size():
		var p: float = float(probs[i])
		if p <= 0.0:
			continue
		t.row(vb, Upgrades.rareza_nombre(i), "%s%%   →  %s" % [str(snappedf(p * 100.0, 0.1)), efectos[i]],
			Upgrades.rareza_color(i))


# EL FAROLILLO no mide en golpes ahorrados sino en CASILLAS de luz, en el piso donde estas.
func _efecto(tipo: int, tier: int, banda: int, rareza: int, base_t: ToolData) -> String:
	if tipo == ToolData.Tipo.LAMPARA:
		var piso: int = maxi(1, Game.current_floor)
		return "alcance %.1f casillas (piso %d)" % [
			Lampara.radio(Lampara.potencia(tier, rareza, banda, 0), piso), piso]
	return MenuScaffold.texto_efecto_herramienta(base_t, Upgrades.tool_mods(tipo, tier, rareza, banda))


# ============================================================
#  EL PIE FIJO
# ============================================================

func _pie(tipo: int, lingote: MaterialData, piezas: int) -> void:
	var vb: VBoxContainer = t.acciones()
	vb.add_child(HSeparator.new())
	HerreriaForjar.fila_autos(vb, _cantidad, func(v: int) -> void: _cantidad = v,
		func(mejor: bool) -> void: _on_auto(tipo, lingote, mejor),
		func() -> void:
			_sel_met = {}
			_sel_tab = {}
			t.rebuild())
	var txt: String = "Faltan materiales"
	if piezas == 1:
		txt = "Forjar"
	elif piezas > 1:
		txt = "Forjar (%d herramientas)" % piezas
	MenuScaffold.pastilla(vb, txt, func() -> void: _forjar(tipo, lingote), true, piezas >= 1)


func _on_auto(tipo: int, lingote: MaterialData, mejor_primero: bool) -> void:
	# EL MISMO complemento que pinta y consume la receta: el farolillo lleva HEBILLAS, no tablon.
	var tab: MaterialData = Game.complemento_de_herramienta(tipo, lingote)
	if tab == null:
		return
	var veces: int = maxi(1, _cantidad)
	var cst: Dictionary = Game.coste_herramienta(tipo)
	_sel_met = HerreriaForjar.auto_sel(t, lingote, int(cst["metal"]) * veces, mejor_primero)
	_sel_tab = HerreriaForjar.auto_sel(t, tab, int(cst["tablon"]) * veces, mejor_primero)
	t.rebuild()


func _forjar(tipo: int, lingote: MaterialData) -> void:
	if Net.activo and not await Net.hogar.abrir_taller():
		t.ocupado()
		t.rebuild()
		return
	var items: Array = Game.fabricar_herramienta_tanda(tipo, lingote, _sel_met, _sel_tab,
		Game.piezas_de_seleccion_herramienta(tipo, lingote, _sel_met, _sel_tab))
	if Net.activo:
		Net.hogar.cerrar_taller()
		Net.hogar.liberar_mis_reservas()
	if items.size() == 1:
		t.decir("Forjas %s. Equípala en el inventario [I], pestaña Equipo." % Game.item_display_name(items[0]))
	elif items.size() > 1:
		var nombres: PackedStringArray = []
		for it in items:
			nombres.append(Game.item_display_name(it as Resource))
		t.decir("Forjas %d herramientas: %s. Están en el inventario [I]." % [items.size(), ", ".join(nombres)])
	else:
		t.decir("Te faltan materiales.", false)
	_sel_met = {}
	_sel_tab = {}
	t.rebuild()
