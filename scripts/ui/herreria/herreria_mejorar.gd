# ============================================================
#  herreria_mejorar.gd  --  MEJORAR una pieza del baul (ver forge_menu.gd, el armazon).
#
#  LA REJILLA ES TU EQUIPO, como en el inventario: cada pieza con su tier, rareza y +N en la celda, y
#  quien la lleva puesta en la esquina. Encima, el filtro por ranura en dos filas (son ocho).
#  Aqui SI salen las piezas equipadas: mejorar el arma que llevas en la mano la mejora de verdad.
#
#  LA FICHA: lo que cuesta (el nucleo, que lo elige el sistema por el +N, y el material de su banda)
#  en celdas con lo que tienes, las categorias como chips, los atributos con lo que sube la elegida y
#  la durabilidad. El farolillo va aparte: una sola categoria y cuesta un nucleo de cada rama.
#
#  Mejorar TODO el equipo se queda en la herreria, tambien la armadura de cuero (decision del usuario,
#  16/09/2026): mandar a alguien de un taller a otro para mejorar lo suyo no se aguanta.
# ============================================================
extends RefCounted

const LADO_CELDA_COSTE := 48.0

# Las ranuras del filtro, con su icono. Las mochilas y las herramientas solo en Deshacer: no se mejoran.
const RANURAS := [
	{"slot": "", "nombre": "Todo", "icono": "todo"},
	{"slot": "main", "nombre": "Arma principal", "icono": "espada"},
	{"slot": "off", "nombre": "Secundaria", "icono": "escudo_med"},
	{"slot": "farolillo", "nombre": "Farolillo", "icono": "farol"},
	{"slot": "casco", "nombre": "Casco", "icono": "casco"},
	{"slot": "pecho", "nombre": "Pecho", "icono": "coraza"},
	{"slot": "manos", "nombre": "Manos", "icono": "mano"},
	{"slot": "pantalones", "nombre": "Pantalones", "icono": "pantalon"},
	{"slot": "botas", "nombre": "Botas", "icono": "botas"},
]
const RANURAS_DESHACER := [
	{"slot": "mochila", "nombre": "Mochila", "icono": "mochila"},
	{"slot": "herramienta", "nombre": "Herramientas", "icono": "pico"},
]
# Cuantas van en la fila de arriba (el resto, las armaduras, en la de abajo).
const CORTE_FILTROS := 4

var t = null   # el armazon (forge_menu.gd)
var _filtro: int = 0
var _cat_idx: int = 0


func _init(armazon) -> void:
	t = armazon


# ============================================================
#  LA REJILLA DEL BAUL (la comparten Mejorar y Deshacer)
# ============================================================

# 'deshacer' = sin lo equipado y con mochilas y herramientas. Devuelve las piezas ya filtradas y pinta
# el filtro con 'al_filtrar'.
static func piezas_del_baul(armazon, deshacer: bool, filtro: int, al_filtrar: Callable) -> Array:
	var ranuras: Array = RANURAS.duplicate()
	if deshacer:
		for r in RANURAS_DESHACER:
			ranuras.insert(CORTE_FILTROS, r)
	var nombres: Array = []
	var iconos: Array = []
	for r in ranuras:
		nombres.append(r["nombre"])
		iconos.append(r["icono"])
	filtro = clampi(filtro, 0, ranuras.size() - 1)
	armazon.filtros_dos_filas(nombres, iconos, filtro, al_filtrar,
		CORTE_FILTROS + (RANURAS_DESHACER.size() if deshacer else 0))
	var slot: String = String(ranuras[filtro]["slot"])
	var todo: Array = []
	todo.append_array(Game.owned_weapons)
	todo.append_array(Game.owned_armor)
	if deshacer:
		todo.append_array(Game.owned_mochilas)
		todo.append_array(Game.owned_tools)
	else:
		# El farolillo es la unica herramienta que se mejora.
		for tl in Game.owned_tools:
			if Game.es_lampara_item(tl):
				todo.append(tl)
	var out: Array = []
	for item in todo:
		if deshacer and Game.item_equipado(item):
			continue
		if slot != "" and slot_de(item) != slot:
			continue
		out.append(item)
	return out


# EN QUE RANURA va esta pieza (owned_weapons lleva armas, escudos y varitas mezclados).
static func slot_de(item: Resource) -> String:
	if item is ArmorData:
		var i: int = int((item as ArmorData).slot)
		return String(Game.ARMOR_SLOT_ORDEN[i]) if i >= 0 and i < Game.ARMOR_SLOT_ORDEN.size() else "pecho"
	if item is BackpackData:
		return "mochila"
	if item is ToolData:
		return "farolillo" if (item as ToolData).es_lampara() else "herramienta"
	if item is ShieldData or item is WandData:
		return "off"
	return "main"


# Las celdas: la pieza tal cual (la celda ya pinta tier, rareza y +N) y QUIEN la lleva en la esquina.
static func celdas(items: Array, con_portador: bool) -> Array:
	var out: Array = []
	for item in items:
		var duenno: PersonajeData = Game.quien_lleva(item) if con_portador else null
		out.append({"item": item, "pie": "", "activo": true,
			"marca": duenno.nombre if duenno != null else "",
			"tooltip": "%s%s" % [Game.item_display_name(item),
				"  ·  la lleva %s" % duenno.nombre if duenno != null else ""]})
	return out


# ============================================================
#  PINTAR
# ============================================================

func build() -> void:
	var items: Array = piezas_del_baul(t, false, _filtro, _on_filtro)
	t.stacks = items
	t.contador("%d monedas" % Game.money)
	t.grid_detail(celdas(items, true), _ficha, "No tienes nada de esto que mejorar.")


func _on_filtro(i: int) -> void:
	if i == _filtro:
		return
	_filtro = i
	t.cambiar_pantalla()


func _ficha(vb: VBoxContainer) -> void:
	var item: Resource = t.stacks[t.sel]
	MenuScaffold.titulo_item(vb, Game.item_display_name(item), Game.color_rareza_de(item),
		Game.intensidad_rareza_de(item))
	# Quien la lleva, arriba del todo: mejorar la pieza equivocada no tiene vuelta atras.
	var duenno: PersonajeData = Game.quien_lleva(item)
	MenuScaffold.banner_item(vb, item, "", "La lleva %s" % duenno.nombre if duenno != null else "En el baúl")

	var meta: Dictionary = Game.meta_de(item)
	var rareza: int = int(meta["rareza"])
	var actuales: int = Game.mejoras_actuales(item)
	var por_rareza: int = Upgrades.rareza_slots(rareza)
	var es_farol: bool = Game.es_lampara_item(item)
	# El nucleo lo pone el sistema segun el +N; nucleo_auto devuelve el que TOCA aunque no lo tengas.
	var nucleo: MaterialData = Game.nucleo_auto(item)
	var al_tope: bool = actuales >= por_rareza or nucleo == null

	vb.add_child(HSeparator.new())
	MenuScaffold.titulo(vb, "MEJORAS  +%d de %d" % [actuales, por_rareza], 13)
	var cuesta: int = 0
	if al_tope:
		t.note(vb, "Está al máximo que permite su rareza.")
	else:
		cuesta = Forge.nucleos_para_mejora(actuales, nucleo, item)
		var fila := HFlowContainer.new()
		fila.add_theme_constant_override("h_separation", 16)
		fila.add_theme_constant_override("v_separation", 8)
		vb.add_child(fila)
		_coste(fila, nucleo, cuesta, Game.nucleos_en_hogar(nucleo), "")
		# EL FAROLILLO pide UNO DE CADA RAMA: la pareja, en rojo si falta.
		if es_farol:
			var otro: MaterialData = Game.pareja_de_nucleo(nucleo)
			if otro != null:
				_coste(fila, otro, 1, Game.nucleos_en_hogar(otro), "")
		# El MATERIAL de refuerzo, de la banda que cubre este nivel.
		var mats: Dictionary = Game.materiales_mejora(item)
		var cmat: Dictionary = Forge.material_para_mejora(actuales, item, mats["metal"], mats["fibra"])
		for clave in ["metal", "fibra"]:
			var m: MaterialData = mats[clave]
			if m == null:
				if not (es_farol and clave == "fibra"):
					t.note(vb, "No existe material a este nivel: esta pieza no se puede reforzar más.")
				continue
			var necesita: int = Game.LAMPARA_MEJORA_METAL if es_farol else int(cmat[clave])
			_coste(fila, m, necesita, Game.disponible_unidades_material_en_hogar(m), " uds")

	if es_farol:
		_farol(vb, item, nucleo, al_tope)
		return

	var cats: Array = categorias(item)
	if cats.is_empty():
		t.note(vb, "Esta pieza no admite mejoras.")
		return
	_cat_idx = clampi(_cat_idx, 0, cats.size() - 1)
	var mj: Dictionary = meta["mejoras"]
	var opciones: Array = []
	for c in cats:
		opciones.append({"nombre": Upgrades.cat_nombre(str(c)), "cuantos": int(mj.get(str(c), 0))})
	vb.add_child(HSeparator.new())
	MenuScaffold.chips(vb, "QUÉ MEJORAR", opciones, [_cat_idx], _on_cat, 3)

	# ATRIBUTOS de la pieza, con en verde lo que sube la categoria elegida.
	vb.add_child(HSeparator.new())
	var cat_sel: String = str(cats[_cat_idx])
	for f in MenuScaffold.filas_mejora(item, int(meta["tier"]), rareza, mj, cat_sel):
		_atributo(vb, str(f[0]), str(f[1]), "" if al_tope else str(f[2]))
	# DURABILIDAD en puntos: una mejora de Durabilidad sube el MAXIMO, no el %.
	var maxd: float = Game.max_durabilidad_item(item)
	var frac: float = Game.durabilidad_item(item)
	var delta: String = ""
	if cat_sel == Upgrades.DURABILIDAD and not al_tope:
		var n_dur: int = int(mj.get(Upgrades.DURABILIDAD, 0))
		var nuevo_max: float = maxd / (1.0 + float(n_dur) * Game.DURABILIDAD_MEJORA_PCT) \
			* (1.0 + float(n_dur + 1) * Game.DURABILIDAD_MEJORA_PCT)
		delta = "+%d pts máx" % round(nuevo_max - maxd)
	_atributo(vb, "Durabilidad", "%d / %d pts  (%d%%)" % [round(frac * maxd), round(maxd), round(frac * 100.0)], delta)
	t.note(vb, "El núcleo lo elige el sistema por el nivel de la pieza, y dentro de su tramo cada mejora cuesta uno más. Gasta también material de su tier, del peor que tengas: la rareza ya está echada.")

	var puede: bool = nucleo != null and Game.puede_mejorar(item, nucleo)
	var txt: String = "Al máximo que permite la rareza (+%d)" % por_rareza
	if not al_tope:
		txt = "Mejorar %s" % Upgrades.cat_nombre(cat_sel)
		if Game.nucleos_en_hogar(nucleo) < cuesta:
			txt = "Te faltan núcleos (%d de %d)" % [Game.nucleos_en_hogar(nucleo), cuesta]
		elif not puede:
			txt = "Te falta material"
	var pie: VBoxContainer = t.acciones()
	pie.add_child(HSeparator.new())
	MenuScaffold.pastilla(pie, txt, func() -> void: _mejorar(item, cat_sel), true, puede)


# Un COSTE en su celda: el material, cuanto pide y cuanto tienes (en rojo si no llega).
func _coste(fila: Container, mat: MaterialData, pide: int, tienes: int, uds: String) -> void:
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	MenuScaffold.celda_suelta(caja, mat, LADO_CELDA_COSTE, "T%d" % int(mat.tier))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	# Con ancho: sin el la columna nace a cero y el autowrap de la ficha parte el nombre letra a letra.
	col.custom_minimum_size = Vector2(160, 0)
	var nom := Label.new()
	nom.text = mat.nombre
	nom.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	col.add_child(nom)
	var v := Label.new()
	v.text = "%d%s  (tienes %d)" % [pide, uds, tienes]
	v.add_theme_color_override("font_color", t.ROJO if tienes < pide else t.VERDE)
	col.add_child(v)
	caja.add_child(col)
	fila.add_child(caja)


# Fila de ATRIBUTO: nombre · valor actual · (+delta) en verde.
func _atributo(vb: VBoxContainer, etiqueta: String, valor: String, delta: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = etiqueta
	k.custom_minimum_size = Vector2(170, 0)
	k.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	row.add_child(k)
	# Con ANCHO fijo el valor y el delta: sin eso el autowrap de la ficha los dejaba a ancho cero y salian
	# letra a letra (visto en captura). El delta va pegado al valor, no al otro extremo de la fila.
	var v := Label.new()
	v.text = valor
	v.custom_minimum_size = Vector2(160, 0)
	row.add_child(v)
	if delta != "":
		var d := Label.new()
		d.text = delta
		d.custom_minimum_size = Vector2(160, 0)
		d.add_theme_color_override("font_color", t.VERDE)
		row.add_child(d)
	vb.add_child(row)


# EL FAROLILLO: una sola categoria (la luz). Se enseña el ALCANCE que ganaria, no un "+1".
func _farol(vb: VBoxContainer, item: Resource, nucleo: MaterialData, al_tope: bool) -> void:
	var meta: Dictionary = Game.meta_de(item)
	var mej: int = int((meta["mejoras"] as Dictionary).get(Upgrades.LUMINOSIDAD, 0))
	var piso: int = maxi(1, Game.current_floor)
	var tier: int = int(meta["tier"])
	var rar: int = int(meta["rareza"])
	var banda: int = int(meta.get("banda", 0))
	var ahora: float = Lampara.radio(Lampara.potencia(tier, rar, banda, mej), piso)
	var luego: float = Lampara.radio(Lampara.potencia(tier, rar, banda, mej + 1), piso)
	vb.add_child(HSeparator.new())
	_atributo(vb, "Luz", "%.1f casillas en el piso %d" % [ahora, piso],
		"" if al_tope else "→ %.1f" % luego)
	t.note(vb, "El farolillo se mejora A SECAS: cada mejora sube la potencia de la luz. Pide UN núcleo de cada rama de la banda que le toque, más un poco de metal, y el coste no sube con el nivel.")
	var puede: bool = nucleo != null and Game.puede_mejorar(item, nucleo)
	var txt: String = "Al máximo que permite la rareza (+%d)" % Upgrades.rareza_slots(rar)
	if not al_tope:
		txt = "Mejorar  →  %.1f casillas" % luego if puede else "Te falta material o alguno de los dos núcleos"
	var pie: VBoxContainer = t.acciones()
	pie.add_child(HSeparator.new())
	MenuScaffold.pastilla(pie, txt, func() -> void: _mejorar(item, Upgrades.LUMINOSIDAD), true, puede)


static func categorias(item: Resource) -> Array:
	if Game.es_lampara_item(item):
		return [Upgrades.LUMINOSIDAD]
	if item is ArmorData:
		return Upgrades.armor_categories(item as ArmorData)
	if item is WandData:
		return Upgrades.wand_categories()
	if item is ShieldData:
		return Upgrades.shield_categories()
	if item is WeaponData:
		return Upgrades.weapon_categories(item as WeaponData)
	return []


func _on_cat(i: int) -> void:
	_cat_idx = i
	t.rebuild()


func _mejorar(item: Resource, cat: String) -> void:
	var nucleo: MaterialData = Game.nucleo_auto(item)
	if nucleo == null:
		t.decir("No se pudo mejorar.", false)
		return
	if Net.activo and not await Net.hogar.abrir_taller():
		t.ocupado()
		t.rebuild()
		return
	var ok: bool = Game.mejorar_item(item, cat, nucleo)
	if Net.activo:
		Net.hogar.cerrar_taller()
	if ok:
		if cat == Upgrades.LUMINOSIDAD:
			t.decir("El %s alumbra más: %.1f casillas." % [str(item.get("nombre")).to_lower(), Game.radio_lampara()])
		else:
			t.decir("%s ahora es %s." % [Upgrades.cat_nombre(cat), Game.item_display_name(item)])
	else:
		t.decir("No se pudo mejorar.", false)
	t.rebuild()
