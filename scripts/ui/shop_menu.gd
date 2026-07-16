# ============================================================
#  shop_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  Menu de la TIENDA. Lo abre el tendero del pueblo (shop.gd -> abrir()); no tiene tecla
#  propia. Congela al jugador via Game.inventory_open mientras esta abierto.
#
#  Cuatro pestañas:
#   1) VENDER       - subpestañas Bolsa (cristales+materiales) / Hogar (materiales del baul)
#                     / Equipo (armas y armaduras). Cantidad por modal, igual que "soltar" en
#                     el inventario. Boton de "vender todos los cristales" de un clic.
#   2) RECOMPRAR    - lo que le has vendido al tendero (hasta 7), al mismo precio que te pago.
#   3) TIENDA       - armas/escudos/varita/bastón a T1 comun, pociones y grimorios.
#   4) PACK INICIAL - una vez por partida: un arma gratis (ni bastón ni varita) + 3 pociones.
#
#  Toda la MATH vive en Game (precio_compra_tier / vender_item / comprar_equipo_tier / recomprar...);
#  aqui solo se pinta.
# ============================================================

extends CanvasLayer

# Recomprar va DEBAJO de Tienda (y solo aparece si le has vendido algo al tendero); el pack
# inicial desaparece al reclamarlo. Un menu vacio no merece su boton.
const TABS := ["Vender", "Tienda", "Tienda T2", "Recomprar", "Pack inicial"]
const SUBS_VENDER := ["Bolsa", "Hogar", "Equipo", "Consumibles"]
# El grimorio es un consumible en el inventario, pero en el mostrador va aparte: buscar un
# libro de 2200 entre las pociones es incomodo.
const SUBS_TIENDA := ["Armas", "Armaduras", "Mochilas", "Consumibles", "Grimorios"]

const ARMOR_TIPO_LABELS := ["Cuero", "Hierro", "Hierro completo", "Placas"]
const ARMOR_SLOT_LABELS := ["Casco", "Pecho", "Manos", "Pantalones", "Botas"]

const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const ROJO := Color(0.9, 0.5, 0.5)
const GRIS := Color(0.6, 0.63, 0.7)

# Catalogo de la tienda: lo que hay a la venta, por bloques.
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
# La mochila basica: la unica que se compra hecha. Las buenas las cose el peletero.
const CAT_MOCHILAS: Array[String] = [
	"res://resources/backpacks/mochila_basica.tres",
]
const CAT_POCIONES: Array[String] = [
	"res://resources/consumables/pocion_menor.tres",
	"res://resources/consumables/pocion_menor_1.tres",
	"res://resources/consumables/pocion_menor_2.tres",
	"res://resources/consumables/pocion_mana_menor.tres",
	"res://resources/consumables/pocion_mana_menor_1.tres",
	"res://resources/consumables/pocion_mana_menor_2.tres",
	"res://resources/consumables/piedra_retorno.tres",
]
const CAT_GRIMORIOS: Array[String] = [
	"res://resources/consumables/grimorio_descarga.tres",
	"res://resources/consumables/grimorio_brasa.tres",
	"res://resources/consumables/grimorio_rocio.tres",
]

# --- Catalogo del mostrador T2 (el que abre el Rey Slime) ---
# El EQUIPO no tiene lista propia: son las mismas plantillas, que se venden a T2 (el tier no vive en
# el .tres, lo pone la compra). Los consumibles y los grimorios SI son recursos distintos.
const CAT_POCIONES_T2: Array[String] = [
	"res://resources/consumables/pocion_media.tres",
	"res://resources/consumables/pocion_media_1.tres",
	"res://resources/consumables/pocion_media_2.tres",
	"res://resources/consumables/pocion_mana_media.tres",
	"res://resources/consumables/pocion_mana_media_1.tres",
	"res://resources/consumables/pocion_mana_media_2.tres",
	"res://resources/consumables/piedra_retorno_t2.tres",
]
# Los de 2 frases: ataque medio de los tres elementos, potenciacion, debuff e imbuiciones. Los de 1
# frase se quedan en el mostrador T1; los de 3 (Tormenta) no se venden.
const CAT_GRIMORIOS_T2: Array[String] = [
	"res://resources/consumables/grimorio_chorro_agua.tres",
	"res://resources/consumables/grimorio_bola_fuego.tres",
	"res://resources/consumables/grimorio_rayo.tres",
	"res://resources/consumables/grimorio_fortaleza.tres",
	"res://resources/consumables/grimorio_debilidad.tres",
	"res://resources/consumables/grimorio_filo_ardiente.tres",
	"res://resources/consumables/grimorio_filo_fulgurante.tres",
	"res://resources/consumables/grimorio_filo_torrente.tres",
	"res://resources/consumables/grimorio_manto_brasas.tres",
	"res://resources/consumables/grimorio_manto_centellas.tres",
	"res://resources/consumables/grimorio_manto_marea.tres",
]
# Armaduras: los 4 tipos x los 5 slots, en orden de cobertura (Game.ARMOR_SLOT_ORDEN).
const ARMOR_TIPOS: Array[String] = ["cuero", "hierro", "hierro_completo", "placas"]

var _root: Control = null
var _header: VBoxContainer = null    # cabecera FIJA (titulo + subpestañas)
var _lista: VBoxContainer = null     # cuadricula, con su scroll
var _scroll_lista: ScrollContainer = null
var _content: VBoxContainer = null   # detalle, con el suyo
var _dinero_top: Label = null        # monedas arriba a la derecha
var _aviso_lbl: Label = null         # linea de aviso, de altura fija (no empuja el titulo)
var _tab_buttons: Array = []

var _tab: int = 0
var _sub: int = 0                    # subpestaña de VENDER (Bolsa / Hogar / Equipo)
var _sel: int = 0                    # seleccion dentro de la cuadricula actual
# TIER del mostrador que se esta pintando (1 = el de siempre, 2 = el del Rey Slime). Lo fija
# _build_tienda y lo leen la ficha y el boton de comprar, que no reciben parametros.
var _tienda_tier: int = 1
var _stacks: Array = []              # lo que hay pintado en la cuadricula actual
var _aviso: String = ""              # mensaje de la ultima accion (compra fallida, etc.)
var _aviso_ok: bool = true

var _modal: Control = null
var _modal_spin: SpinBox = null
var _pending_modelo: Resource = null  # stack que se va a vender (espera al modal)
var _pending_base: Resource = null    # consumible que se va a comprar (espera al modal)


func _ready() -> void:
	layer = 91
	add_to_group("shop_menu")

	var m: Dictionary = MenuScaffold.construir(self, "TIENDA", "", _cerrar, true)
	_root = m["root"]
	_header = m["header"]
	_lista = m["lista"]
	_scroll_lista = m["lista_scroll"]
	_content = m["content"]
	_dinero_top = m["dinero"]
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
	# No abrir sobre un combate/extraccion ni con el panel DEBUG abierto.
	if Game._active_layer != null or Game.debug_panel_open:
		return
	_tab = 0
	_sub = 0
	_sel = 0
	_aviso = ""
	_root.visible = true
	Game.inventory_open = true   # congela al jugador
	_rebuild()


func _cerrar() -> void:
	_cerrar_modal()
	_root.visible = false
	Game.inventory_open = false


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			if _modal != null:
				_cerrar_modal()
			else:
				_cerrar()
			get_viewport().set_input_as_handled()


func _on_tab(i: int) -> void:
	_tab = i
	_sub = 0   # Vender y Tienda tienen subpestañas distintas: no arrastres la del otro
	_sel = 0
	_aviso = ""
	_rebuild()


func _on_sub(i: int) -> void:
	_sub = i
	_sel = 0
	_aviso = ""
	_rebuild()


func _rebuild() -> void:
	for zona in [_header, _lista, _content]:
		for c in zona.get_children():
			c.queue_free()
	# Pestañas que solo existen cuando tienen algo dentro: el mostrador T2 (2), que lo abre el Rey
	# Slime, el de recompra (3) y el pack inicial (4), que es de usar y tirar.
	var visible_tab := {2: Game.tienda_t2_abierta(), 3: not Game.recompra.is_empty(),
		4: not Game.pack_inicial_reclamado}
	if not bool(visible_tab.get(_tab, true)):
		_tab = 0
	for i in _tab_buttons.size():
		var b := _tab_buttons[i] as Button
		b.visible = bool(visible_tab.get(i, true))
		b.button_pressed = (i == _tab)
	_dinero_top.text = "%d monedas" % Game.money
	MenuScaffold.decir(_aviso_lbl, _aviso, _aviso_ok)

	match _tab:
		0: _build_vender()
		1: _build_tienda(1)
		2: _build_tienda(2)
		3: _build_recomprar()
		4: _build_pack()


func _decir(txt: String, ok: bool = true) -> void:
	_aviso = txt
	_aviso_ok = ok


# ============================================================
#  Helpers de UI (mismos que el inventario)
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
	k.custom_minimum_size = Vector2(150, 0)
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
	# Sin ancho MINIMO: en el panel de detalle (estrecho) un minimo de 420 px empuja la columna
	# fuera de la pantalla. Que se ajuste a lo que haya y parta las lineas.
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(l)


# La cuadricula va a la columna de la LISTA (con su scroll) y la ficha al DETALLE (con el
# suyo). La cabecera se queda quieta arriba.
func _grid_detail(labels: Array, preview: Callable) -> void:
	if labels.is_empty():
		_note(_content, "(nada por aquí)")
		return
	_sel = clampi(_sel, 0, labels.size() - 1)
	MenuScaffold.cuadricula(_lista, labels, _sel, _pick)
	preview.call(_content)


func _pick(i: int) -> void:
	_sel = i
	_rebuild()


# Fila de subpestañas (la usan Vender y Tienda).
# Las subpestañas van a la CABECERA: no se van con el scroll.
func _subpestanas(nombres: Array) -> void:
	MenuScaffold.pestanas(_header, nombres, _sub, _on_sub, 110)
	_header.add_child(HSeparator.new())


func _boton(vb: VBoxContainer, txt: String, cb: Callable, activo: bool = true) -> void:
	var b := Button.new()
	b.text = txt
	b.disabled = not activo
	b.custom_minimum_size = Vector2(0, 32)
	b.pressed.connect(cb)
	vb.add_child(b)


# Agrupa Cristal/MaterialItem en stacks {modelo, cantidad} (igual que el inventario).
func _agrupar(items: Array) -> Array:
	var claves: Array = []
	var mapa: Dictionary = {}
	for it in items:
		var k: String = _clave_item(it)
		if not mapa.has(k):
			mapa[k] = {"modelo": it, "cantidad": 0}
			claves.append(k)
		mapa[k]["cantidad"] += 1
	var res: Array = []
	for k in claves:
		res.append(mapa[k])
	return res


func _clave_item(it: Resource) -> String:
	if it is Cristal:
		var c := it as Cristal
		return "c|%d|%d" % [c.categoria, int(c.calidad)]
	if it is MaterialItem:
		var m := it as MaterialItem
		return "m|%s|%d" % [m.nombre(), int(m.calidad)]
	return "?"


func _nombre_item(it: Resource) -> String:
	if it is Cristal:
		var c := it as Cristal
		return "Cristal Cat %d\n(%s)" % [c.categoria, c.calidad_texto()]
	if it is MaterialItem:
		var m := it as MaterialItem
		return "%s\n(%s)" % [m.nombre(), m.calidad_texto()]
	return "?"


func _labels_stacks(stacks: Array) -> Array:
	var labels: Array = []
	for s in stacks:
		labels.append("%s  x%d" % [_nombre_item(s["modelo"]), int(s["cantidad"])])
	return labels


# ============================================================
#  Pestaña VENDER
# ============================================================

func _build_vender() -> void:
	_title(_header, "VENDER")
	_note(_header, "Te pagan el valor estimado que ya ves en el inventario: sin regateo ni sorpresas. Los cristales solo se sacan de encima aquí.")

	_subpestanas(SUBS_VENDER)
	match _sub:
		0: _build_vender_bolsa()
		1: _build_vender_hogar()
		2: _build_vender_equipo()
		3: _build_vender_consumibles()


func _build_vender_bolsa() -> void:
	var cristales: int = Game.crystals.size()
	if cristales > 0:
		var total: int = 0
		for c in Game.crystals:
			total += Game.precio_venta_item(c)
		_boton(_header, "Vender TODOS los cristales  (%d → %d monedas)" % [cristales, total],
			_on_vender_todos)
		_header.add_child(HSeparator.new())

	var items: Array = []
	for c in Game.crystals:
		items.append(c)
	for m in Game.materiales:
		items.append(m)
	_stacks = _agrupar(items)
	_grid_detail(_labels_stacks(_stacks), _preview_venta_bolsa)


func _build_vender_hogar() -> void:
	_note(_header, "Los materiales que tienes guardados en el Hogar. Piénsatelo: lo que vendas hoy te tocará farmearlo mañana para craftear.")
	_stacks = _agrupar(Game.almacen_materiales)
	_grid_detail(_labels_stacks(_stacks), _preview_venta_bolsa)


func _preview_venta_bolsa(vb: VBoxContainer) -> void:
	var s: Dictionary = _stacks[_sel]
	var modelo: Resource = s["modelo"]
	var n: int = int(s["cantidad"])
	var precio: int = Game.precio_venta_item(modelo)
	_title(vb, _nombre_item(modelo).replace("\n", " "))
	_row(vb, "Cantidad", str(n))
	if modelo is Cristal:
		_row(vb, "Categoría", str((modelo as Cristal).categoria))
	elif modelo is MaterialItem and (modelo as MaterialItem).data != null:
		_row(vb, "Material", (modelo as MaterialItem).data.resumen())
	_row(vb, "Te pagan", "%d por unidad  (todo: %d)" % [precio, precio * n])
	vb.add_child(HSeparator.new())
	_boton(vb, "Vender", _on_vender_stack)


func _on_vender_stack() -> void:
	var s: Dictionary = _stacks[_sel]
	var n: int = int(s["cantidad"])
	_pending_modelo = s["modelo"]
	if n <= 1:
		_confirmar_venta(1)
	else:
		_abrir_modal_cantidad("¿Cuántas quieres vender?", n, _confirmar_venta)


func _confirmar_venta(cant: int) -> void:
	if _pending_modelo != null:
		var cobrado: int = Game.vender_item(_pending_modelo, cant, _sub == 1)
		_decir("Vendes %d x %s por %d monedas." % [
			cant, _nombre_item(_pending_modelo).replace("\n", " "), cobrado])
		_pending_modelo = null
	_rebuild()


func _on_vender_todos() -> void:
	var n: int = Game.crystals.size()
	var total: int = Game.vender_todos_cristales()
	_decir("Vendes %d cristales por %d monedas." % [n, total])
	_rebuild()


# --- Vender EQUIPO (con derecho a recompra) ---

func _build_vender_equipo() -> void:
	_note(_header, "Lo que le vendas al tendero se queda en su mostrador: puedes recomprarlo (pestaña Recomprar) por lo mismo que te pagó, hasta que se le acumulen más de %d trastos. Lo que llevas puesto ni sale aquí: desequípalo antes [C]." % Game.RECOMPRA_MAX)
	# Lo EQUIPADO no se lista. Antes salia y el aviso te decia que no se podia vender: enseñar
	# una fila que no puedes tocar es peor que no enseñarla.
	_stacks = []
	for w in Game.owned_weapons:
		if not Game.item_equipado(w):
			_stacks.append({"modelo": w, "cantidad": 1})
	for a in Game.owned_armor:
		if not Game.item_equipado(a):
			_stacks.append({"modelo": a, "cantidad": 1})
	var labels: Array = []
	for s in _stacks:
		var item: Resource = s["modelo"]
		labels.append("%s%s\n%d monedas" % [
			str(item.get("nombre")), Game.item_plus(item), Game.precio_venta_equipo(item)])
	_grid_detail(labels, _preview_venta_equipo)


func _equipado(item: Resource) -> bool:
	if item == Game.equipped_main or item == Game.equipped_off:
		return true
	for slot in Game.ARMOR_SLOT_ORDEN:
		if Game.get("equipped_" + slot) == item:
			return true
	return false


func _preview_venta_equipo(vb: VBoxContainer) -> void:
	var item: Resource = _stacks[_sel]["modelo"]
	var puesto: bool = _equipado(item)
	_title(vb, Game.item_display_name(item) + ("   [equipado]" if puesto else ""))
	_row(vb, "Precio de tienda", "%d (a T1 común)" % Game.precio_compra(item))
	_row(vb, "Te pagan", "%d monedas" % Game.precio_venta_equipo(item))
	vb.add_child(HSeparator.new())
	_boton(vb, "Vender", _on_vender_equipo, not puesto)
	if puesto:
		_note(vb, "Lo llevas puesto. Desequípalo en el menú de personaje [C] antes de venderlo.")


func _on_vender_equipo() -> void:
	var item: Resource = _stacks[_sel]["modelo"]
	var nombre: String = Game.item_display_name(item)
	var cobrado: int = Game.vender_equipo(item)
	if cobrado > 0:
		_decir("Vendes %s por %d monedas." % [nombre, cobrado])
	else:
		_decir("No puedes vender eso.", false)
	_sel = 0
	_rebuild()


# --- Vender CONSUMIBLES (pociones y grimorios) ---

func _build_vender_consumibles() -> void:
	_note(_header, "Pociones y grimorios de tu inventario. No van al mostrador de recompra: el tendero ya los vende de serie, así que si te arrepientes los compras otra vez en la Tienda.")
	_stacks = []
	for c in Game.consumables.keys():
		var n: int = int(Game.consumables[c])
		if n > 0:
			_stacks.append({"modelo": c, "cantidad": n})
	var labels: Array = []
	for s in _stacks:
		var c: ConsumableData = s["modelo"]
		labels.append("%s x%d\n%d monedas" % [c.nombre, int(s["cantidad"]),
			Game.precio_venta_consumible(c)])
	_grid_detail(labels, _preview_venta_consumible)


func _preview_venta_consumible(vb: VBoxContainer) -> void:
	var c: ConsumableData = _stacks[_sel]["modelo"]
	var n: int = int(_stacks[_sel]["cantidad"])
	var precio: int = Game.precio_venta_consumible(c)
	_title(vb, c.nombre)
	_row(vb, "Cantidad", str(n))
	if c.es_grimorio():
		_row(vb, "Enseña", c.spell.nombre)
	else:
		_row(vb, "Efecto", c.resumen(Game.player_max_hp(), Game.player_max_mp()))
	_row(vb, "Te pagan", "%d por unidad  (todo: %d)" % [precio, precio * n])
	vb.add_child(HSeparator.new())
	_boton(vb, "Vender", _on_vender_consumible)


func _on_vender_consumible() -> void:
	var c: ConsumableData = _stacks[_sel]["modelo"]
	var n: int = int(_stacks[_sel]["cantidad"])
	_pending_base = c
	if n <= 1:
		_confirmar_venta_consumible(1)
	else:
		_abrir_modal_cantidad("¿Cuántas quieres vender?", n, _confirmar_venta_consumible)


func _confirmar_venta_consumible(cant: int) -> void:
	if _pending_base != null:
		var c: ConsumableData = _pending_base
		_pending_base = null
		var cobrado: int = Game.vender_consumible(c, cant)
		_decir("Vendes %d x %s por %d monedas." % [cant, c.nombre, cobrado])
	_sel = 0
	_rebuild()


# ============================================================
#  Pestaña RECOMPRAR
# ============================================================

func _build_recomprar() -> void:
	_title(_header, "RECOMPRAR")
	_note(_header, "El mostrador del tendero: lo último que le has vendido (máx. %d). Vuelve a ti tal y como estaba, con su tier y sus mejoras, por lo mismo que te pagó. Al pasarse de %d, lo más viejo se pierde." % [Game.RECOMPRA_MAX, Game.RECOMPRA_MAX])
	_header.add_child(HSeparator.new())

	_stacks = []
	for i in Game.recompra.size():
		_stacks.append({"modelo": Game.recompra[i]["item"], "idx": i,
			"precio": int(Game.recompra[i]["precio"])})
	var labels: Array = []
	for s in _stacks:
		var item: Resource = s["modelo"]
		labels.append("%s%s\n%d monedas" % [
			str(item.get("nombre")), Game.item_plus(item), int(s["precio"])])
	_grid_detail(labels, _preview_recompra)


func _preview_recompra(vb: VBoxContainer) -> void:
	var s: Dictionary = _stacks[_sel]
	var item: Resource = s["modelo"]
	var precio: int = int(s["precio"])
	var llego: bool = Game.puede_pagar(precio)
	_title(vb, Game.item_display_name(item))
	_row(vb, "Precio", "%d monedas" % precio)
	_row(vb, "Tienes", "%d monedas" % Game.money)
	vb.add_child(HSeparator.new())
	_boton(vb, "Recomprar", _on_recomprar, llego)
	if not llego:
		_note(vb, "No te llega.")


func _on_recomprar() -> void:
	var s: Dictionary = _stacks[_sel]
	var nombre: String = Game.item_display_name(s["modelo"])
	if Game.recomprar(int(s["idx"])):
		_decir("Recompras %s por %d monedas." % [nombre, int(s["precio"])])
	else:
		_decir("No te llega para recomprar %s." % nombre, false)
	_sel = 0
	_rebuild()


# ============================================================
#  Pestaña TIENDA (comprar)
# ============================================================

# Pinta el mostrador de un TIER. Es el mismo mostrador para los dos: cambian el catalogo de
# consumibles/grimorios y el precio, no la estructura. Parametrizado en vez de duplicado para que
# añadir una subpestaña siga siendo un solo sitio.
func _build_tienda(tier: int) -> void:
	_tienda_tier = tier
	if tier >= 2:
		_title(_header, "A LA VENTA · T2")
		_note(_header, "El género que el tendero solo saca desde que corrió la voz del Rey Slime. Sale a tier 2 y calidad común, y se paga como lo que es: cosa de los pisos hondos.")
	else:
		_title(_header, "A LA VENTA")
		_note(_header, "Todo lo de aquí sale a tier 1 y calidad común: el tendero no forja, revende. Lo bueno tendrás que fabricártelo tú.")
	_subpestanas(SUBS_TIENDA)

	var rutas: Array = []
	match _sub:
		0:
			rutas = CAT_ARMAS + CAT_SECUNDARIAS
			_note(_header, "Armas de mano principal, y escudos y varita para la secundaria.")
		1:
			rutas = _rutas_armaduras()
			_note(_header, "Cinco piezas por juego: casco, pecho, manos, pantalones y botas. Cuanto más cubre, más frena; los huecos vacíos te dejan ir ligero.")
		2:
			rutas = CAT_MOCHILAS
			_note(_header, "Lo único que sube tu capacidad de carga. Esta es la básica y la única que se compra hecha: las buenas (mejor tier y rareza, más carga) las cose el Peletero.")
		3:
			rutas = CAT_POCIONES_T2 if tier >= 2 else CAT_POCIONES
			_note(_header, "Comprarlas sale caro: si puedes, fabrícalas en la Boticaria con lo que traigas de la mazmorra.")
		4:
			rutas = CAT_GRIMORIOS_T2 if tier >= 2 else CAT_GRIMORIOS
			_note(_header, "Un libro por hechizo. Se estudia desde Consumibles, en el inventario [I]. Caben %d hechizos a la vez." % Game.MAX_HECHIZOS)

	_stacks = []
	for ruta in rutas:
		var base: Resource = load(ruta)
		if base != null:
			_stacks.append({"modelo": base})
	var labels: Array = []
	for s in _stacks:
		var base: Resource = s["modelo"]
		labels.append("%s\n%d monedas" % [str(base.get("nombre")), _precio_de(base)])
	_grid_detail(labels, _preview_tienda)


# Precio de lo que hay en el mostrador que se esta pintando. Al EQUIPO le pone el recargo del tier
# (el tier no vive en el .tres); a pociones y grimorios NO, porque el T2 ya son recursos aparte con
# su propio valor_base y multiplicarlos otra vez los cobraria dos veces.
func _precio_de(base: Resource) -> int:
	if base is ConsumableData:
		return Game.precio_compra(base)
	return Game.precio_compra_tier(base, _tienda_tier)


# Las 20 piezas de armadura: por TIPO (de la mas ligera a la mas pesada) y, dentro de cada
# tipo, por slot en el orden de siempre (Game.ARMOR_SLOT_ORDEN).
func _rutas_armaduras() -> Array:
	var out: Array = []
	for tipo in ARMOR_TIPOS:
		for slot in Game.ARMOR_SLOT_ORDEN:
			out.append("res://resources/armor/%s_%s.tres" % [tipo, slot])
	return out


func _preview_tienda(vb: VBoxContainer) -> void:
	var base: Resource = _stacks[_sel]["modelo"]
	var precio: int = _precio_de(base)
	var llego: bool = Game.puede_pagar(precio)
	_title(vb, str(base.get("nombre")))
	_row(vb, "Precio", "%d monedas" % precio)
	_row(vb, "Tienes", "%d monedas" % Game.money)

	if base is ConsumableData:
		var c := base as ConsumableData
		if c.es_grimorio():
			_row(vb, "Enseña", c.spell.nombre)
			_row(vb, "Coste del hechizo", "%d de maná" % c.spell.coste_mana)
			_row(vb, "Hechizos", "%d / %d aprendidos" % [Game.equipped_spells.size(), Game.MAX_HECHIZOS])
		else:
			_row(vb, "Efecto", c.resumen(Game.player_max_hp(), Game.player_max_mp()))
			_row(vb, "Tienes", "%d en la bolsa" % int(Game.consumables.get(c, 0)))
	elif base is BackpackData:
		var mo := base as BackpackData
		# La carga de la mochila sale de una TABLA por tier (15/25/40), no de tier_mult.
		_row(vb, "Capacidad", "+%.0f de carga" % (mo.capacidad * Game.mochila_tier_factor(_tienda_tier)))
		_row(vb, "Llevas ahora", "%d" % roundi(Game.capacidad_carga()))
	elif base is ArmorData:
		var a := base as ArmorData
		# La DEF sale de la MISMA funcion que usa el combate: lo que ves es lo que te pones. La
		# reduccion y la velocidad NO escalan con el tier (son de tipo/tamaño), por eso van crudas.
		var pm := Upgrades.armor_piece_mods(a, Game.tier_mult(_tienda_tier), Upgrades.Rareza.COMUN, {})
		_row(vb, "Slot", ARMOR_SLOT_LABELS[clampi(int(a.slot), 0, 4)])
		_row(vb, "Tipo", ARMOR_TIPO_LABELS[clampi(int(a.tipo), 0, 3)])
		_row(vb, "Defensa", "%.2f" % float(pm["def"]))
		_row(vb, "Reducción", "%.0f%%" % (a.reduccion * 100.0))
		_row(vb, "Velocidad", "×%.2f" % a.velocidad_mult)
	elif base is WeaponData:
		_stats_arma_base(vb, base as WeaponData, _tienda_tier)
	elif base is ShieldData:
		var sh := base as ShieldData
		_row(vb, "Tipo", "Escudo (mano secundaria)")
		# CRUDO a proposito: hoy el combate lee sh.bloqueo tal cual, sin tier ni rareza (a
		# diferencia del arma en la secundaria). Enseñar aqui un bloqueo escalado seria MENTIR.
		# Cuando se haga el rework del escudo, esto pasa por Upgrades como los demas.
		_row(vb, "Bloqueo", "+%.2f" % sh.bloqueo)
		_row(vb, "Velocidad", "×%.2f" % sh.velocidad_mult)
		if _tienda_tier >= 2:
			_note(vb, "Aviso: el escudo aún no aprovecha el tier. Este rinde igual que el de la tienda normal; lo que cambia es lo que cuesta.")
	elif base is WandData:
		var wd := base as WandData
		var mm := Upgrades.magic_mods(wd.magic_amp, Game.tier_mult(_tienda_tier), Upgrades.Rareza.COMUN, {})
		_row(vb, "Tipo", "Varita (mano secundaria, magia)")
		_row(vb, "Amplif. magia", "×%.2f" % float(mm["magic_amp"]))
		_row(vb, "Vel. casteo", "×%.2f" % wd.cast_vel_mult)
	else:
		_row(vb, "Tipo", _tipo_equipo(base))
	# OJO: WeaponData no tiene campo 'descripcion', asi que base.get() devuelve null y str(null)
	# pintaba un "<null>" de nota. Se comprueba que no sea null ANTES de convertir a texto.
	var desc: Variant = base.get("descripcion")
	if desc != null and str(desc) != "":
		_note(vb, str(desc))

	vb.add_child(HSeparator.new())
	if base is ConsumableData:
		_boton(vb, "Comprar 1", _on_comprar_consumible.bind(1), llego)
		if not (base as ConsumableData).es_grimorio():
			_boton(vb, "Comprar varias...", _on_comprar_varias, llego)
	else:
		_boton(vb, "Comprar", _on_comprar_equipo, llego)
	if not llego:
		_note(vb, "No te llega. Baja a por más cristales.")


# Ficha de un arma del CATALOGO, al tier con el que se vende y calidad comun (la rareza no se
# compra: sale de la forja). Tira de la ficha COMPARTIDA (MenuScaffold.filas_arma), la misma del
# inventario y el menu de personaje: una sola fuente, y añadir una stat se hace en un solo sitio.
# El tier por DEFECTO es 1 porque el pack inicial tambien la usa y siempre regala a T1.
func _stats_arma_base(vb: VBoxContainer, w: WeaponData, tier: int = 1) -> void:
	for fila in MenuScaffold.filas_arma(w, tier, Upgrades.Rareza.COMUN, {}):
		_row(vb, fila[0], fila[1])


func _tipo_equipo(base: Resource) -> String:
	if base is ShieldData:
		return "Escudo (mano secundaria)"
	if base is WandData:
		return "Varita (mano secundaria, magia)"
	if base is WeaponData:
		var w := base as WeaponData
		var t: String = "Arma a dos manos" if w.dos_manos else "Arma a una mano"
		return t + ("  ·  mágica" if w.es_magica else "")
	return "?"


func _on_comprar_equipo() -> void:
	var base: Resource = _stacks[_sel]["modelo"]
	var item: Resource = Game.comprar_equipo_tier(base, _tienda_tier)
	if item != null:
		_decir("Compras %s. Está en tu baúl: equípalo en el menú de personaje [C]." % Game.item_display_name(item))
	else:
		_decir("No te llega para %s." % str(base.get("nombre")), false)
	_rebuild()


func _on_comprar_consumible(n: int) -> void:
	var base: ConsumableData = _stacks[_sel]["modelo"]
	if Game.comprar_consumible(base, n):
		if base.es_grimorio():
			_decir("Compras %s. Úsalo desde Consumibles en el inventario [I] para aprender %s." % [
				base.nombre, base.spell.nombre])
		else:
			_decir("Compras %d x %s." % [n, base.nombre])
	else:
		_decir("No te llega para %d x %s." % [n, base.nombre], false)
	_rebuild()


func _on_comprar_varias() -> void:
	var base: ConsumableData = _stacks[_sel]["modelo"]
	var precio: int = Game.precio_compra(base)
	var maximo: int = 99 if precio <= 0 else maxi(1, Game.money / precio)
	_pending_base = base
	_abrir_modal_cantidad("¿Cuántas quieres comprar?  (te llega para %d)" % maximo, maximo,
		_confirmar_compra_varias)


func _confirmar_compra_varias(cant: int) -> void:
	if _pending_base != null:
		var base: ConsumableData = _pending_base
		_pending_base = null
		if Game.comprar_consumible(base, cant):
			_decir("Compras %d x %s." % [cant, base.nombre])
		else:
			_decir("No te llega para %d x %s." % [cant, base.nombre], false)
	_rebuild()


# ============================================================
#  Pestaña PACK INICIAL
# ============================================================

func _build_pack() -> void:
	_title(_header, "PACK INICIAL")
	if Game.pack_inicial_reclamado:
		_note(_header, "Ya reclamaste tu pack. Lo que quieras a partir de ahora sale de tu bolsillo: vende cristales en la pestaña Vender y compra en la Tienda.")
		return

	_note(_header, "Regalo de bienvenida, UNA sola vez: elige un arma y llévatela gratis, con %d pociones menores de propina. El bastón y la varita no entran: la magia te la pagas tú." % Game.PACK_POCIONES_N)
	_header.add_child(HSeparator.new())

	_stacks = []
	for ruta in Game.PACK_ARMAS:
		var base: Resource = load(ruta)
		if base != null:
			_stacks.append({"modelo": base})
	var labels: Array = []
	for s in _stacks:
		labels.append(str((s["modelo"] as Resource).get("nombre")))
	_grid_detail(labels, _preview_pack)


func _preview_pack(vb: VBoxContainer) -> void:
	var base: WeaponData = _stacks[_sel]["modelo"]
	_title(vb, base.nombre)
	_stats_arma_base(vb, base)   # misma ficha completa que la tienda (crit, evasion, aturdir...)
	_row(vb, "Valor", "%d monedas (gratis para ti)" % Game.precio_compra(base))
	vb.add_child(HSeparator.new())
	_boton(vb, "Reclamar el pack con esta arma", _on_reclamar_pack)


func _on_reclamar_pack() -> void:
	var base: Resource = _stacks[_sel]["modelo"]
	if Game.reclamar_pack_inicial(base):
		_decir("Te llevas %s y %d pociones menores. Equípala en el menú de personaje [C]." % [
			str(base.get("nombre")), Game.PACK_POCIONES_N])
	else:
		_decir("El pack ya estaba reclamado.", false)
	_rebuild()


# ============================================================
#  Modal de CANTIDAD (vender varias / comprar varias)
# ============================================================

func _abrir_modal_cantidad(pregunta: String, maximo: int, cb: Callable) -> void:
	_cerrar_modal()
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_modal)

	var back := ColorRect.new()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.color = Color(0, 0, 0, 0.6)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.add_child(back)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 1.0)
	sb.border_color = Color(0.87, 0.57, 0.26, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	var l := Label.new()
	l.text = "%s  (máx. %d)" % [pregunta, maximo]
	vb.add_child(l)

	_modal_spin = SpinBox.new()
	_modal_spin.min_value = 1
	_modal_spin.max_value = maxi(1, maximo)
	_modal_spin.step = 1
	_modal_spin.value = 1
	vb.add_child(_modal_spin)

	var acciones := HBoxContainer.new()
	acciones.add_theme_constant_override("separation", 8)
	var ok := Button.new()
	ok.text = "Aceptar"
	ok.pressed.connect(_modal_aceptar.bind(cb))
	acciones.add_child(ok)
	var ca := Button.new()
	ca.text = "Cancelar"
	ca.pressed.connect(_cancelar_modal)
	acciones.add_child(ca)
	vb.add_child(acciones)


func _modal_aceptar(cb: Callable) -> void:
	var cant: int = int(_modal_spin.value) if _modal_spin != null else 1
	_cerrar_modal()
	cb.call(cant)


func _cancelar_modal() -> void:
	_pending_modelo = null
	_pending_base = null
	_cerrar_modal()


func _cerrar_modal() -> void:
	if _modal != null:
		_modal.queue_free()
		_modal = null
	_modal_spin = null
