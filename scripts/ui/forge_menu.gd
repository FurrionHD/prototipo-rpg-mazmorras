# ============================================================
#  forge_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  Menu del HERRERO. Lo abre el herrero del pueblo (herrero.gd -> abrir()). Congela al
#  jugador via Game.inventory_open mientras esta abierto.
#
#  Cuatro pestañas:
#   1) FUNDIR  - mineral en bruto -> LINGOTES.
#   2) CHAPAS  - lingotes -> CHAPAS (lo que pide la armadura; el arma se golpea del lingote).
#      Las dos refinan igual: NO se mezclan calidades (N piezas de la MISMA calidad dan una de
#      esa calidad) y suben el contador de Metalurgia, que algun dia dara la habilidad de
#      subirlo un escalon (hasta el PURO).
#   3) FORJAR  - eliges la pieza, el METAL (lingote para armas, chapa para armaduras: fija el
#      TIER) y cuanto metes de cada calidad, mas el cuero curtido del peletero. Aqui SI se
#      mezcla. La RAREZA es una tirada y su tabla se pinta EN VIVO con el score real. Sube el
#      contador de Herreria.
#   4) MEJORAR - eliges una pieza de tu baul, un NUCLEO y una categoria. Cada mejora cuesta
#      mas nucleos que la anterior, y el nucleo marca hasta donde te deja llegar.
#
#  Toda la MATH vive en Game/Forge; aqui solo se pinta y se derivan los numeros de los campos.
# ============================================================

extends CanvasLayer

const TABS := ["Fundir", "Chapas", "Hebillas", "Forjar", "Mejorar"]
# Los tres refinados de metal comparten pantalla (_build_refinar): solo cambian de que salen,
# en que se convierten y cuantos hacen falta.
enum Refinado { LINGOTE, CHAPA, HEBILLAS }
const SUBS_FORJA := ["Armas", "Secundarias", "Armaduras"]
# Dentro de Armaduras, un submenu por juego (si no, son 20 piezas de golpe en la cuadricula).
const ARMOR_LABELS := ["Cuero", "Hierro", "Hierro completo", "Placas"]

const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const ROJO := Color(0.9, 0.5, 0.5)
const GRIS := Color(0.6, 0.63, 0.7)

const ARMOR_SLOT_LABELS := ["Casco", "Pecho", "Manos", "Pantalones", "Botas"]
# De mejor a peor (el enum NO esta ordenado: PURO se añadio al final para no romper partidas).
const CALIDADES := [MaterialItem.Calidad.PURO, MaterialItem.Calidad.INTACTO,
	MaterialItem.Calidad.NORMAL, MaterialItem.Calidad.DANADO]

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
const ARMOR_TIPOS: Array[String] = ["cuero", "hierro", "hierro_completo", "placas"]

var _root: Control = null
var _header: VBoxContainer = null       # cabecera FIJA (titulo + pestañas)
var _lista: VBoxContainer = null        # cuadricula de piezas, con su propio scroll
var _scroll_lista: ScrollContainer = null
var _content: VBoxContainer = null      # panel de detalle, con el suyo
var _aviso_lbl: Label = null            # linea de aviso, de altura fija (no empuja el titulo)
var _tab_buttons: Array = []

var _tab: int = 0
var _sub: int = 0
var _sel: int = 0                  # pieza seleccionada (catalogo o baul)
var _stacks: Array = []
var _aviso: String = ""
var _aviso_ok: bool = true

# --- FUNDIR / CHAPAS ---
var _metal_idx: int = 0            # cual de Game.metales_forja()

# --- FORJAR ---
var _armor_idx: int = 0            # juego de armadura (submenu de la subpestaña Armaduras)
var _lingote_idx: int = 0          # metal elegido (indice en lingotes o chapas, misma lista)
var _sel_metal: Dictionary = {}    # {calidad: cantidad}
var _sel_cuero: Dictionary = {}

# --- MEJORAR ---
var _nucleo_idx: int = 0
var _cat_idx: int = 0


func _ready() -> void:
	layer = 91
	add_to_group("forge_menu")

	var m: Dictionary = MenuScaffold.construir(self, "HERRERO",
		"Primero se funde el metal, después se golpea. Todo sale de lo que tengas guardado en el Hogar.",
		_cerrar)
	_root = m["root"]
	_header = m["header"]
	_lista = m["lista"]
	_scroll_lista = m["lista_scroll"]
	_content = m["content"]
	_aviso_lbl = m["aviso"]

	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 34)
		b.pressed.connect(_on_tab.bind(i))
		(m["side"] as VBoxContainer).add_child(b)
		_tab_buttons.append(b)


func abrir() -> void:
	if Game._active_layer != null or Game.debug_panel_open:
		return
	_tab = 0
	_sub = 0
	_sel = 0
	_aviso = ""
	_limpiar_seleccion()
	_root.visible = true
	Game.inventory_open = true
	_rebuild()


func _cerrar() -> void:
	_root.visible = false
	Game.inventory_open = false


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_cerrar()
			get_viewport().set_input_as_handled()


func _limpiar_seleccion() -> void:
	_sel_metal = {}
	_sel_cuero = {}


func _on_tab(i: int) -> void:
	_tab = i
	_sub = 0
	_sel = 0
	_aviso = ""
	_limpiar_seleccion()
	_rebuild()


func _on_sub(i: int) -> void:
	_sub = i
	_sel = 0
	_limpiar_seleccion()
	_rebuild()


func _pick(i: int) -> void:
	_sel = i
	_limpiar_seleccion()   # otra pieza = otro coste: lo elegido antes ya no vale
	_rebuild()


func _rebuild() -> void:
	for zona in [_header, _lista, _content]:
		for c in zona.get_children():
			c.queue_free()
	for i in _tab_buttons.size():
		(_tab_buttons[i] as Button).button_pressed = (i == _tab)
	# Los refinados (Fundir / Chapas / Hebillas) no tienen cuadricula: ancho entero para ellos.
	_scroll_lista.visible = _tab >= 3
	MenuScaffold.decir(_aviso_lbl, _aviso, _aviso_ok)

	match _tab:
		0: _build_refinar(Refinado.LINGOTE)    # mineral -> lingote
		1: _build_refinar(Refinado.CHAPA)      # lingote -> chapa (armaduras)
		2: _build_refinar(Refinado.HEBILLAS)   # lingote -> hebillas (mochilas)
		3: _build_forjar()
		4: _build_mejorar()


func _decir(txt: String, ok: bool = true) -> void:
	_aviso = txt
	_aviso_ok = ok


# ============================================================
#  Helpers de UI
# ============================================================

func _title(vb: VBoxContainer, txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", AMBAR)
	l.add_theme_font_size_override("font_size", 16)
	vb.add_child(l)

func _row(vb: VBoxContainer, etiqueta: String, valor: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = etiqueta
	k.custom_minimum_size = Vector2(170, 0)
	k.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	row.add_child(k)
	var v := Label.new()
	v.text = valor
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(v)
	vb.add_child(row)

func _note(vb: VBoxContainer, txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", GRIS)
	l.add_theme_font_size_override("font_size", 11)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Sin ancho MINIMO: en el panel de detalle (que es estrecho) un minimo de 420 px empuja la
	# columna entera fuera de la pantalla. Que se ajuste a lo que haya y parta las lineas.
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(l)

func _boton(vb: VBoxContainer, txt: String, cb: Callable, activo: bool = true) -> void:
	var b := Button.new()
	b.text = txt
	b.disabled = not activo
	b.custom_minimum_size = Vector2(0, 36)
	b.pressed.connect(cb)
	vb.add_child(b)


# Solo el METAL, sin la forma: "Lingote de cobre" / "Chapa de cobre" -> "Cobre". En los
# botones estrechos del panel de detalle lo que importa es cual de los tres metales es.
func _metal_corto(m: MaterialData) -> String:
	var partes: PackedStringArray = m.nombre.split(" de ")
	return (partes[partes.size() - 1] if partes.size() > 1 else m.nombre).capitalize()


# Texto de una calidad (el enum no esta ordenado: siempre pasar por aqui).
func _cal_txt(cal: int) -> String:
	match cal:
		MaterialItem.Calidad.PURO: return "Puro"
		MaterialItem.Calidad.INTACTO: return "Intacto"
		MaterialItem.Calidad.NORMAL: return "Normal"
		MaterialItem.Calidad.DANADO: return "Dañado"
		_: return "Roto"

# Unidades de crafteo que aporta un item de esta calidad (puro 4 / intacto 3 / normal 2 / dañado 1).
func _uds(cal: int) -> int:
	return MaterialItem.crear(null, cal).unidades_crafteo()


# Las subpestañas van a la CABECERA: no se van con el scroll.
func _subpestanas(nombres: Array) -> void:
	MenuScaffold.pestanas(_header, nombres, _sub, _on_sub)
	_header.add_child(HSeparator.new())


# La cuadricula va a la columna de la LISTA y la ficha al panel de DETALLE: cada una con su
# scroll, y la cabecera quieta arriba.
func _grid_detail(labels: Array, preview: Callable) -> void:
	if labels.is_empty():
		_note(_content, "(nada por aquí)")
		return
	_sel = clampi(_sel, 0, labels.size() - 1)
	MenuScaffold.cuadricula(_lista, labels, _sel, _pick)
	preview.call(_content)


# ============================================================
#  Pestañas FUNDIR (mineral -> lingote) y CHAPAS (lingote -> chapa)
#  Son la MISMA operacion (refinar), asi que las pinta la misma funcion: solo cambian el
#  material de entrada, el de salida y cuantos hacen falta.
# ============================================================

func _build_refinar(que: int) -> void:
	var metales: Array = Game.metales_forja()
	_metal_idx = clampi(_metal_idx, 0, metales.size() - 1)
	var de_lingote: bool = que != Refinado.LINGOTE   # chapas y hebillas parten del lingote
	var origen: MaterialData = metales[_metal_idx]["lingote" if de_lingote else "mineral"]
	var destino: MaterialData = metales[_metal_idx][_clave_destino(que)]
	var por_uno: int = _por_uno(que)

	_title(_header, _titulo_refinado(que))
	_note(_header, _nota_refinado(que, por_uno))
	_header.add_child(HSeparator.new())

	var fila := GridContainer.new()
	fila.columns = 2
	fila.add_theme_constant_override("h_separation", 6)
	fila.add_theme_constant_override("v_separation", 6)
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in metales.size():
		var m: MaterialData = metales[i]["lingote" if de_lingote else "mineral"]
		var b := Button.new()
		b.text = "%s  (T%d)" % [m.nombre, m.tier]
		b.toggle_mode = true
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = (i == _metal_idx)
		b.custom_minimum_size = Vector2(0, 32)
		b.pressed.connect(_on_metal.bind(i))
		fila.add_child(b)
	_content.add_child(fila)
	_content.add_child(HSeparator.new())

	_row(_content, "Sale", "%s  ·  Tier %d" % [destino.nombre, destino.tier])

	# Una fila por calidad: lo que tienes, lo que sale y los botones.
	var hubo: bool = false
	for cal in CALIDADES:
		# El PURO solo aparece si YA lo tienes (refinado con oficio): en bruto no existe.
		var tengo: int = Game.items_calidad_en_hogar(origen, int(cal))
		if tengo <= 0:
			continue
		hubo = true
		var salen: int = Game.refinados_posibles(origen, int(cal), por_uno)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var l := Label.new()
		l.text = "%s:  %d  →  %d" % [_cal_txt(int(cal)), tengo, salen]
		l.custom_minimum_size = Vector2(240, 0)
		l.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92) if salen > 0 else GRIS)
		row.add_child(l)
		var b1 := Button.new()
		b1.text = "Hacer 1"
		b1.disabled = salen < 1
		b1.pressed.connect(_on_refinar.bind(que, int(cal), 1))
		row.add_child(b1)
		var bt := Button.new()
		bt.text = "Hacer todo (%d)" % salen
		bt.disabled = salen < 1
		bt.pressed.connect(_on_refinar.bind(que, int(cal), salen))
		row.add_child(bt)
		_content.add_child(row)
	if not hubo:
		if de_lingote:
			_note(_content, "No tienes %s. Fúndelo primero en la pestaña Fundir." % origen.nombre.to_lower())
		else:
			_note(_content, "No tienes %s guardado en el Hogar. Pica vetas en la mazmorra y guárdalo al volver." % origen.nombre.to_lower())

	# Lo que ya tienes de la salida.
	_content.add_child(HSeparator.new())
	_title(_content, "En el almacén")
	var alguno: bool = false
	for cal in CALIDADES:
		var n: int = Game.items_calidad_en_hogar(destino, int(cal))
		if n > 0:
			alguno = true
			_row(_content, "%s (%s)" % [destino.nombre, _cal_txt(int(cal))],
				"%d  ·  %d unidades de forja" % [n, n * _uds(int(cal))])
	if not alguno:
		_note(_content, "Ningún %s todavía." % destino.nombre.to_lower())

	_content.add_child(HSeparator.new())
	_estado_oficio(_content, "Metalurgia", Game.metalurgia_exp, Game.habilidad_metalurgia,
		"tirará por sacar el metal un escalón por encima de lo que metas (y con oficio de sobra, un intacto puede salir PURO).")


# --- Los tres refinados de metal, en tablas (la pantalla es la misma) ---

func _clave_destino(que: int) -> String:
	match que:
		Refinado.CHAPA: return "chapa"
		Refinado.HEBILLAS: return "hebillas"
		_: return "lingote"

func _por_uno(que: int) -> int:
	match que:
		Refinado.CHAPA: return Forge.LINGOTE_POR_CHAPA
		Refinado.HEBILLAS: return Forge.LINGOTE_POR_HEBILLAS
		_: return Forge.MINERAL_POR_LINGOTE

func _titulo_refinado(que: int) -> String:
	match que:
		Refinado.CHAPA: return "BATIR CHAPAS"
		Refinado.HEBILLAS: return "HACER HEBILLAS"
		_: return "FUNDIR"

func _nota_refinado(que: int, por_uno: int) -> String:
	match que:
		Refinado.CHAPA:
			return "%d lingote(s) = 1 chapa de la MISMA calidad. Las chapas son lo que pide la ARMADURA; el arma se golpea del lingote directamente." % por_uno
		Refinado.HEBILLAS:
			return "%d lingotes = 1 juego de hebillas de la MISMA calidad. Salen caras en metal (son muchos herrajes pequeños, y hay que hacerlos de uno en uno), y es lo que sujeta una MOCHILA: la cose el peletero." % por_uno
		_:
			return "%d minerales de la MISMA calidad = 1 lingote de esa calidad. No se mezclan: juntando dañados no sale un normal. Solo la Metalurgia puede regalarte un escalón." % por_uno


func _on_metal(i: int) -> void:
	_metal_idx = i
	_rebuild()


func _on_refinar(que: int, cal: int, veces: int) -> void:
	var metales: Array = Game.metales_forja()
	var origen: MaterialData = metales[_metal_idx]["mineral" if que == Refinado.LINGOTE else "lingote"]
	var n: int = 0
	match que:
		Refinado.CHAPA: n = Game.batir_chapa(origen, cal, veces)
		Refinado.HEBILLAS: n = Game.hacer_hebillas(origen, cal, veces)
		_: n = Game.fundir(origen, cal, veces)
	if n > 0:
		_decir("Sacas %d x %s de calidad %s." % [n,
			Game.metales_forja()[_metal_idx][_clave_destino(que)].nombre.to_lower(),
			_cal_txt(cal).to_lower()])
	else:
		_decir("No te llega el material.", false)
	_rebuild()


# Estado de una habilidad de oficio: hoy solo acumula.
func _estado_oficio(vb: VBoxContainer, nombre: String, exp_val: float, activa: bool, que_hara: String) -> void:
	_row(vb, nombre, "%s de oficio%s" % [
		str(snappedf(exp_val, 0.1)), "" if activa else "   (habilidad aún bloqueada)"])
	if not activa:
		_note(vb, "El progreso se guarda desde ya: %s" % que_hara)


# ============================================================
#  Pestaña FORJAR
# ============================================================

func _build_forjar() -> void:
	_title(_header, "FORJAR")
	_subpestanas(SUBS_FORJA)

	var rutas: Array = []
	match _sub:
		0: rutas = CAT_ARMAS
		1: rutas = CAT_SECUNDARIAS
		2:
			# Submenu por JUEGO de armadura: las 20 piezas de golpe no se leen.
			_juegos_armadura()
			rutas = _rutas_armaduras(ARMOR_TIPOS[_armor_idx])

	_stacks = []
	for ruta in rutas:
		var base: Resource = load(ruta)
		if base != null:
			_stacks.append({"modelo": base})
	var labels: Array = []
	for s in _stacks:
		labels.append(str((s["modelo"] as Resource).get("nombre")))
	_grid_detail(labels, _preview_forjar)


# Fila de botones con los cuatro juegos de armadura (tambien en la cabecera fija).
func _juegos_armadura() -> void:
	_armor_idx = clampi(_armor_idx, 0, ARMOR_TIPOS.size() - 1)
	MenuScaffold.pestanas(_header, ARMOR_LABELS, _armor_idx, _on_juego, 130)
	_header.add_child(HSeparator.new())


func _on_juego(i: int) -> void:
	_armor_idx = i
	_sel = 0
	_limpiar_seleccion()
	_rebuild()


func _rutas_armaduras(tipo: String) -> Array:
	var out: Array = []
	for slot in Game.ARMOR_SLOT_ORDEN:
		out.append("res://resources/armor/%s_%s.tres" % [tipo, slot])
	return out


func _preview_forjar(vb: VBoxContainer) -> void:
	var base: Resource = _stacks[_sel]["modelo"]
	var coste: Dictionary = Forge.coste(base)
	var usa_chapa: bool = bool(coste["usa_chapa"])
	# El metal de una ARMADURA son CHAPAS; el de un ARMA, lingotes.
	var metales: Array = Game.chapas_forja() if usa_chapa else Game.lingotes_forja()
	_lingote_idx = clampi(_lingote_idx, 0, metales.size() - 1)
	var metal: MaterialData = metales[_lingote_idx]

	_title(vb, str(base.get("nombre")))
	if base is ArmorData:
		_row(vb, "Slot", ARMOR_SLOT_LABELS[clampi(int((base as ArmorData).slot), 0, 4)])
	_row(vb, "Lleva", "%s + cuero curtido" % ("chapas" if usa_chapa else "lingotes"))

	# --- Metal: fija el TIER (y empuja la rareza) ---
	vb.add_child(HSeparator.new())
	_row(vb, "Metal", "%s  →  Tier %d  (×%.2f al daño/defensa)" % [
		metal.nombre, Forge.tier_de_metal(metal), Game.tier_mult(Forge.tier_de_metal(metal))])
	# Botones cortos, de dos en dos y repartiendose el ancho: el panel de detalle es estrecho y
	# con el nombre entero ("Lingote de adamante") la fila se salia de la pantalla.
	var fila := GridContainer.new()
	fila.columns = 2
	fila.add_theme_constant_override("h_separation", 6)
	fila.add_theme_constant_override("v_separation", 6)
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in metales.size():
		var m: MaterialData = metales[i]
		var tengo: int = Game.unidades_material_en_hogar(m)
		var b := Button.new()
		b.text = "%s T%d · %d uds" % [_metal_corto(m), m.tier, tengo]
		b.tooltip_text = m.nombre
		b.toggle_mode = true
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = (i == _lingote_idx)
		b.disabled = tengo <= 0
		b.pressed.connect(_on_lingote.bind(i))
		fila.add_child(b)
	vb.add_child(fila)

	# --- Contadores de material ---
	vb.add_child(HSeparator.new())
	_contadores(vb, metal, _sel_metal, int(coste["metal"]))
	_contadores(vb, Game.cuero_forja(), _sel_cuero, int(coste["cuero"]))
	_note(vb, "Puro = 4 unidades · intacto = 3 · normal = 2 · dañado = 1. Meter buen material no abarata la pieza: mejora la RAREZA que te va a tocar.")

	# --- Tabla de rareza EN VIVO, con el score REAL (material + metal + herrería) ---
	vb.add_child(HSeparator.new())
	var score: float = Game.score_forja(base, metal, _sel_metal, _sel_cuero)
	var t := Label.new()
	t.text = "Rareza que puede salir"
	t.add_theme_color_override("font_color", AMBAR)
	vb.add_child(t)
	# La calidad que cuenta es la de lo que se GASTA (el sobrante no entra en la media).
	var bonos: float = Forge.bonus_metal(metal) + Forge.bonus_herreria(Game.herreria_activa())
	_note(vb, "Calidad del material %d%%  +  metal %+d%%  +  herrería %+d%%" % [
		roundi((score - bonos) * 100.0),
		roundi(Forge.bonus_metal(metal) * 100.0),
		roundi(Forge.bonus_herreria(Game.herreria_activa()) * 100.0)])
	var probs: Array = Forge.probs_rareza(score)
	for i in probs.size():
		var p: float = float(probs[i])
		if p <= 0.0:
			continue
		_row(vb, Upgrades.rareza_nombre(i), "%s%%   (%d huecos de mejora)" % [
			str(snappedf(p * 100.0, 0.1)), Upgrades.rareza_slots(i)])

	vb.add_child(HSeparator.new())
	var acc := HBoxContainer.new()
	acc.add_theme_constant_override("separation", 8)
	var auto := Button.new()
	auto.text = "Auto (peor primero)"
	auto.pressed.connect(_on_auto)
	acc.add_child(auto)
	var limpiar := Button.new()
	limpiar.text = "Limpiar"
	limpiar.pressed.connect(_on_limpiar)
	acc.add_child(limpiar)
	vb.add_child(acc)

	var ok: bool = Game.forja_valida(base, metal, _sel_metal, _sel_cuero)
	_boton(vb, "Forjar" if ok else "Faltan materiales", _on_forjar, ok)

	vb.add_child(HSeparator.new())
	_estado_oficio(vb, "Herrería", Game.herreria_exp, Game.habilidad_herreria,
		"empujará la tirada de rareza a tu favor, como si el metal fuera mejor de lo que es.")


# Fila "material: −  n  +" por cada calidad que tengas en el baul.
func _contadores(vb: VBoxContainer, mat: MaterialData, sel: Dictionary, necesita: int) -> void:
	var uds: int = Game.uds_seleccion(sel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = mat.nombre
	k.custom_minimum_size = Vector2(170, 0)
	k.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	row.add_child(k)
	var v := Label.new()
	v.text = "%d / %d unidades" % [uds, necesita]
	v.add_theme_color_override("font_color", VERDE if uds >= necesita else ROJO)
	row.add_child(v)
	vb.add_child(row)

	# Si te has pasado, decir QUE se va a gastar de verdad: el sobrante se queda en el baul. Y
	# de lo que se gasta, las unidades que sobren del ultimo trozo pueden volver (el recorte).
	if uds >= necesita and necesita > 0:
		var gasto: Dictionary = Game.recortar_seleccion(sel, necesita)
		var gastadas: int = Game.uds_seleccion(gasto)
		var partes: PackedStringArray = []
		for cal in CALIDADES:
			var n: int = int(gasto.get(cal, 0))
			if n > 0:
				partes.append("%d %s" % [n, _cal_txt(int(cal)).to_lower()])
		var txt: String = "   Se gastarán %s (%d uds)" % [", ".join(partes), gastadas]
		if uds > gastadas:
			txt += "; el resto se queda en el Hogar"
		var sobra: int = gastadas - necesita
		if sobra > 0:
			txt += ".  Sobran %d uds del recorte: %d%% de recuperar una pieza" % [
				sobra, roundi(Forge.prob_devolver(sobra, Game.herreria_activa()) * 100.0)]
		_note(vb, txt + ".")

	var hubo: bool = false
	for cal in CALIDADES:
		var disp: int = Game.items_calidad_en_hogar(mat, int(cal))
		if disp <= 0:
			continue
		hubo = true
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		var lab := Label.new()
		lab.text = "   %s  (tienes %d)" % [_cal_txt(int(cal)), disp]
		lab.custom_minimum_size = Vector2(190, 0)
		r.add_child(lab)
		var minus := Button.new()
		minus.text = "−"
		minus.custom_minimum_size = Vector2(30, 0)
		minus.pressed.connect(_mat_delta.bind(sel, mat, int(cal), -1))
		r.add_child(minus)
		var cnt := Label.new()
		cnt.text = str(int(sel.get(cal, 0)))
		cnt.custom_minimum_size = Vector2(26, 0)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.add_child(cnt)
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(30, 0)
		plus.pressed.connect(_mat_delta.bind(sel, mat, int(cal), 1))
		r.add_child(plus)
		vb.add_child(r)
	if not hubo:
		_note(vb, "   No tienes %s en el Hogar." % mat.nombre.to_lower())


func _mat_delta(sel: Dictionary, mat: MaterialData, cal: int, delta: int) -> void:
	var disp: int = Game.items_calidad_en_hogar(mat, cal)
	var nuevo: int = clampi(int(sel.get(cal, 0)) + delta, 0, disp)
	if nuevo <= 0:
		sel.erase(cal)
	else:
		sel[cal] = nuevo
	_rebuild()


func _on_lingote(i: int) -> void:
	_lingote_idx = i
	_sel_metal = {}   # otro metal, otro montón
	_rebuild()


# Rellena con lo PEOR primero: gastar los dañados antes que los buenos. Si quieres rareza, lo
# limpias y metes los buenos a mano.
func _on_auto() -> void:
	var base: Resource = _stacks[_sel]["modelo"]
	var coste: Dictionary = Forge.coste(base)
	var metal: MaterialData = Game.metal_de_forja(base, _lingote_idx)
	_sel_metal = _auto_sel(metal, int(coste["metal"]))
	_sel_cuero = _auto_sel(Game.cuero_forja(), int(coste["cuero"]))
	_rebuild()


func _auto_sel(mat: MaterialData, necesita: int) -> Dictionary:
	var sel: Dictionary = {}
	var restante: int = necesita
	var peor_primero: Array = CALIDADES.duplicate()
	peor_primero.reverse()
	for cal in peor_primero:
		if restante <= 0:
			break
		var disp: int = Game.items_calidad_en_hogar(mat, int(cal))
		var uds: int = _uds(int(cal))
		if disp <= 0 or uds <= 0:
			continue
		var usar: int = mini(int(ceil(float(restante) / float(uds))), disp)
		if usar > 0:
			sel[cal] = usar
			restante -= usar * uds
	return sel


func _on_limpiar() -> void:
	_limpiar_seleccion()
	_rebuild()


func _on_forjar() -> void:
	var base: Resource = _stacks[_sel]["modelo"]
	var metal: MaterialData = Game.metal_de_forja(base, _lingote_idx)
	var item: Resource = Game.forjar(base, metal, _sel_metal, _sel_cuero)
	if item != null:
		_decir("Forjas %s. Está en tu baúl: equípalo en el menú de personaje [C]." % Game.item_display_name(item))
	else:
		_decir("Te faltan materiales.", false)
	_limpiar_seleccion()
	_rebuild()


# ============================================================
#  Pestaña MEJORAR
# ============================================================

func _build_mejorar() -> void:
	_title(_header, "MEJORAR")
	_note(_header, "Cada mejora sube el número base de la pieza (daño o defensa) y, además, lo suyo propio. El NÚCLEO manda: uno de slime no te lleva más allá de +3 por muchos huecos que tenga la pieza.")
	_header.add_child(HSeparator.new())

	_stacks = []
	for w in Game.owned_weapons:
		_stacks.append({"modelo": w})
	for a in Game.owned_armor:
		_stacks.append({"modelo": a})
	var labels: Array = []
	for s in _stacks:
		var item: Resource = s["modelo"]
		labels.append("%s%s\nT%d %s" % [str(item.get("nombre")), Game.item_plus(item),
			int(Game.meta_de(item)["tier"]), Upgrades.rareza_nombre(int(Game.meta_de(item)["rareza"]))])
	_grid_detail(labels, _preview_mejorar)


func _preview_mejorar(vb: VBoxContainer) -> void:
	var item: Resource = _stacks[_sel]["modelo"]
	var nucleos: Array = Game.nucleos_para(item)
	_title(vb, Game.item_display_name(item))

	if nucleos.is_empty():
		_note(vb, "No tienes núcleos que sirvan para esto en el Hogar. Los sueltan los monstruos, y no siempre.")
		return
	_nucleo_idx = clampi(_nucleo_idx, 0, nucleos.size() - 1)
	var nucleo: MaterialData = nucleos[_nucleo_idx]

	var actuales: int = Game.mejoras_actuales(item)
	var tope: int = Game.tope_mejoras(item, nucleo)
	var cuesta: int = Forge.nucleos_para_mejora(actuales)
	_row(vb, "Mejoras", "+%d  (tope con este núcleo: +%d)" % [actuales, tope])
	_row(vb, "Huecos por rareza", str(Upgrades.rareza_slots(int(Game.meta_de(item)["rareza"]))))

	vb.add_child(HSeparator.new())
	# Los nucleos, tambien de dos en dos y repartiendose el ancho: sus nombres son largos.
	var fila := GridContainer.new()
	fila.columns = 2
	fila.add_theme_constant_override("h_separation", 6)
	fila.add_theme_constant_override("v_separation", 6)
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in nucleos.size():
		var n: MaterialData = nucleos[i]
		var b := Button.new()
		b.text = "%s  ·  %d  (hasta +%d)" % [n.nombre, Game.nucleos_en_hogar(n), n.mejora_max]
		b.toggle_mode = true
		b.button_pressed = (i == _nucleo_idx)
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_nucleo.bind(i))
		fila.add_child(b)
	vb.add_child(fila)
	_row(vb, "Cuesta", "%d × %s  (tienes %d)" % [cuesta, nucleo.nombre, Game.nucleos_en_hogar(nucleo)])
	_note(vb, "La siguiente mejora siempre cuesta un núcleo más que la anterior.")

	vb.add_child(HSeparator.new())
	var cats: Array = _categorias(item)
	if cats.is_empty():
		_note(vb, "Esta pieza no admite mejoras.")
		return
	_cat_idx = clampi(_cat_idx, 0, cats.size() - 1)
	# DOS por fila: con tres, los nombres largos ("Resistencia (estados)") se salian del panel.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mj: Dictionary = Game.meta_de(item)["mejoras"]
	for i in cats.size():
		var cat: String = str(cats[i])
		var b := Button.new()
		b.text = "%s  (%d)" % [Upgrades.cat_nombre(cat), int(mj.get(cat, 0))]
		b.toggle_mode = true
		b.button_pressed = (i == _cat_idx)
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 30)
		b.pressed.connect(_on_cat.bind(i))
		grid.add_child(b)
	vb.add_child(grid)

	vb.add_child(HSeparator.new())
	var puede: bool = Game.puede_mejorar(item, nucleo)
	var txt: String = "Mejorar  (%d × %s)" % [cuesta, nucleo.nombre]
	if actuales >= tope:
		txt = "Al tope con este núcleo (+%d)" % tope
	elif Game.nucleos_en_hogar(nucleo) < cuesta:
		txt = "Te faltan núcleos (%d de %d)" % [Game.nucleos_en_hogar(nucleo), cuesta]
	_boton(vb, txt, _on_mejorar, puede)


# Categorias que admite la pieza (Upgrades ya sabe cuales, por tipo de arma/armadura).
func _categorias(item: Resource) -> Array:
	if item is ArmorData:
		return Upgrades.armor_categories(item as ArmorData)
	if item is WandData:
		return Upgrades.wand_categories()
	if item is WeaponData:
		return Upgrades.weapon_categories(item as WeaponData)
	return []


func _on_nucleo(i: int) -> void:
	_nucleo_idx = i
	_rebuild()


func _on_cat(i: int) -> void:
	_cat_idx = i
	_rebuild()


func _on_mejorar() -> void:
	var item: Resource = _stacks[_sel]["modelo"]
	var nucleo: MaterialData = Game.nucleos_para(item)[_nucleo_idx]
	var cats: Array = _categorias(item)
	var cat: String = str(cats[clampi(_cat_idx, 0, cats.size() - 1)])
	if Game.mejorar_item(item, cat, nucleo):
		_decir("%s ahora es %s." % [Upgrades.cat_nombre(cat), Game.item_display_name(item)])
	else:
		_decir("No se pudo mejorar.", false)
	_rebuild()