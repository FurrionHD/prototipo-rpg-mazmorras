# ============================================================
#  inventory_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  INVENTARIO a pantalla completa (tecla I), con pestañas verticales:
#    1) BOLSA       - lo que llevas de la expedicion (cristales + materiales). Es lo que
#                     PESA. Seleccionas un stack y puedes SOLTARLO al suelo (modal de
#                     cantidad si hay mas de 1); lo soltado se recoge de nuevo con F.
#    2) EQUIPO      - lo del GRUPO que no es de combate, en dos subpestañas: la MOCHILA (sube la
#                     carga) y las HERRAMIENTAS (pico/hoz/hacha). Aqui SI se equipa, a diferencia
#                     de armas y armaduras, que se cambian en el menu [C].
#    3) CONSUMIBLES - pociones: seleccionas una y le das a "Usar".
#    4) MATERIALES  - los ya guardados en el HOGAR (no pesan). Solo consulta.
#    5) ARMAS       - armas/escudos/varitas de tu baul. Solo consulta (equipar: menu C).
#    6) ARMADURAS   - piezas de armadura de tu baul. Solo consulta.
#
#  PAUSA el juego mientras esta abierto (Game.abrir_menu / cerrar_menu), como el menu de
#  personaje: antes solo se congelaba al jugador y los bichos seguian a lo suyo, asi que abrir la
#  bolsa era invitar a que te emboscaran. UI por codigo.
# ============================================================

extends CanvasLayer

const TABS := ["Bolsa", "Equipo", "Consumibles", "Materiales", "Armas", "Armaduras"]

# --- LA REJILLA ---
# Lado de una celda. 96 en unidades logicas de 1280 es lo que deja 8-9 columnas con la ficha al
# lado, y ademas es el minimo con el que la banda del pie sigue teniendo sitio para un "x1234".
const LADO_CELDA := 96.0
# Lo que se le reserva a la ficha de la derecha. Suficiente para una fila "etiqueta: valor" sin que
# el valor se parta, y no mas: todo lo que sobre ahi se lo lleva la rejilla.
const ANCHO_FICHA := 360.0
# Minimo de la rejilla antes de que empiece a comerse a la ficha. Cuatro columnas: por debajo de eso
# la cuadricula deja de leerse como cuadricula.
const ANCHO_REJILLA_MIN := 420.0
const WEAPON_TIPO_LABELS := ["Puños", "Daga", "Espada corta", "Espada larga", "Mandoble",
	"Estoque", "Hacha grande", "Maza pequeña", "Martillo grande", "Bastón"]
const ARMOR_TIPO_LABELS := ["Cuero", "Hierro", "Hierro completo", "Placas"]
const ARMOR_SLOT_LABELS := ["Casco", "Pecho", "Manos", "Pantalones", "Botas"]

var _root: Control = null
var _header: VBoxContainer = null   # cabecera FIJA (titulo de la pestaña, peso, avisos)
var _lista: VBoxContainer = null    # cuadricula de stacks, con su propio scroll
var _content: VBoxContainer = null  # ficha del item elegido, con el suyo
var _dinero_lbl: Label = null       # monedas, arriba a la derecha
var _tab_buttons: Array = []
var _modal: Control = null          # modal de cantidad (null = cerrado)
var _modal_spin: SpinBox = null     # selector de cantidad del modal
var _pending_modelo: Resource = null # stack que se va a soltar (espera al modal)

var _tab: int = 0
var _sel: int = 0                   # indice seleccionado en la cuadricula de la pestaña
var _stacks: Array = []             # stacks visibles de la pestaña actual


func _ready() -> void:
	layer = 91   # encima del HUD, debajo del menu de personaje (92) y del combate (100)
	process_mode = Node.PROCESS_MODE_ALWAYS   # abrirlo para el arbol: hay que seguir respondiendo
	# Para que el boton de la barra tactil lo encuentre. Un boton de pantalla no puede "pulsar la I":
	# Input.action_press no genera un evento de tecla y este menu escucha eventos, asi que el camino
	# es llamarle a _toggle() directamente.
	add_to_group("menu_inventario")

	# con_lateral = FALSE: las pestañas van en una FILA ARRIBA, no en una columna a la izquierda. Es
	# la forma que tiene el menu en escritorio, y ademas devuelve a la rejilla los 230 px que se
	# comia la columna -- con celdas de 96 eso es una columna entera de objetos mas.
	# En movil la pantalla es la misma: lo unico que cambia entre las dos es donde van las pestañas.
	var m: Dictionary = MenuScaffold.construir(self, "INVENTARIO", "", _cerrar, true, false)
	_root = m["root"]
	_header = m["header"]
	_lista = m["lista"]
	_content = m["content"]
	_dinero_lbl = m["dinero"]

	# EL REPARTO SE INVIERTE. Por defecto el esqueleto le da a la lista un ancho FIJO (330) y el
	# resto al detalle, que es lo que quiere un menu de fichas largas. Aqui manda la REJILLA: es
	# donde buscas, y cuantas mas columnas quepan menos hay que desplazarse. La ficha se queda con
	# un ancho fijo, el justo para leer sin barrer la vista de un lado a otro.
	var scroll: ScrollContainer = m["lista_scroll"]
	scroll.custom_minimum_size = Vector2(ANCHO_REJILLA_MIN, 0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_horizontal = Control.SIZE_FILL
	_content.custom_minimum_size = Vector2(ANCHO_FICHA, 0)
	(_content.get_parent() as ScrollContainer).size_flags_horizontal = Control.SIZE_FILL
	(_content.get_parent() as ScrollContainer).custom_minimum_size = Vector2(ANCHO_FICHA, 0)
	scroll.resized.connect(_on_lista_redimensionada)

	var barra_tabs: HBoxContainer = m["side"]
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.toggle_mode = true
		_estilo_pestana(b)
		b.pressed.connect(_on_tab.bind(i))
		barra_tabs.add_child(b)
		_tab_buttons.append(b)

	# LAS MONEDAS, A LA BARRA DE ARRIBA. El esqueleto las cuelga ANCLADAS bajo la esquina de la ✕,
	# que es donde van cuando la ✕ flota sobre la pantalla; pero con la barra superior la ✕ vive
	# dentro de la barra, asi que las monedas se quedaban solas flotando en mitad de la cabecera y en
	# cuerpo 22, gritando. Aqui pasan a ser una pieza mas de la barra, al lado de la ✕.
	var barra: Node = barra_tabs.get_parent()
	_dinero_lbl.get_parent().remove_child(_dinero_lbl)
	_dinero_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_dinero_lbl.custom_minimum_size = Vector2.ZERO
	_dinero_lbl.add_theme_font_size_override("font_size", 15)
	barra.add_child(_dinero_lbl)
	# Justo ANTES de la ✕, que es el ultimo hijo de la barra.
	barra.move_child(_dinero_lbl, barra.get_child_count() - 2)


# ESC va en _input y CONSUME el evento: _input corre SIEMPRE antes que _unhandled_input, asi que el
# menu de PAUSA (que escucha ahi) no llega a ver la tecla y no se abre por detras al cerrar la bolsa.
func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if not event.is_action_pressed(&"cancelar"):
		return
	if _modal != null:
		_cerrar_modal()   # primero el modal de dentro (cantidad), luego la bolsa
	else:
		_cerrar()
	get_viewport().set_input_as_handled()


# La I va en _unhandled_key_input y NO en _input, por lo mismo que las teclas de dev (ver la cabecera
# de Game._unhandled_key_input): un LineEdit con el foco CONSUME la tecla y aqui no llega, asi que
# escribir ya no abre la bolsa por encima. Game.escribiendo() es el cinturon explicito encima de eso.
# No lo devuelvas a _input.
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if Game.escribiendo():
		return   # con el foco en un campo de texto, una tecla es una LETRA y no un atajo
	if event.is_action_pressed(&"inventario"):
		_toggle()


func _toggle() -> void:
	if not _root.visible:
		# No abrir sobre un combate/extraccion, ni con el panel DEBUG, ni encima de OTRO MENU. Lo del
		# otro menu antes lo tapaba la pausa del arbol ("con el menu de personaje abierto esto ni
		# corre"), pero en MULTI nada pausa: la bolsa se abria encima de la tienda. hay_modal() cubre
		# la pila entera.
		if Game._active_layer != null or Game.debug_panel_open or Game.hay_modal():
			return
		_set_open(true)
	else:
		_set_open(false)


func _cerrar() -> void:
	_set_open(false)


func _set_open(open: bool) -> void:
	_root.visible = open
	if open:
		Game.abrir_menu(self)    # para el mundo entero: nada de que te embosquen con la bolsa abierta
	else:
		Game.cerrar_menu(self)
	if not open:
		_cerrar_modal()
		return
	_tab = 0
	_sel = 0
	_rebuild()


func _on_tab(i: int) -> void:
	_tab = i
	_sel = 0
	_rebuild()


# Guardia de REENTRADA. Un _rebuild puede entrar mientras otro esta a medias (el focus_exited de un
# stepper al liberarlo, las señales de red, un _on_* que espera en un await), y entonces el de dentro
# pinta su panel y el de fuera apila el suyo debajo: el menu salia DUPLICADO. Es el mismo guardia que
# lleva el herrero desde que se cazo alli.
var _reconstruyendo := false

func _rebuild() -> void:
	if _reconstruyendo:
		return
	_reconstruyendo = true
	_rebuild_real()
	_reconstruyendo = false


func _rebuild_real() -> void:
	_dinero_lbl.text = "%d monedas" % Game.money
	for zona in [_header, _lista, _content]:
		MenuScaffold.vaciar(zona)
	for i in _tab_buttons.size():
		(_tab_buttons[i] as Button).button_pressed = (i == _tab)
	match _tab:
		0: _build_bolsa()
		1: _build_equipo()
		2: _build_consumibles()
		3: _build_materiales()
		4: _build_armas()
		5: _build_armaduras()


# ============================================================
#  Helpers de UI
# ============================================================

# AMBAR: el color de titulo de siempre, para lo que no tiene rareza (un stack de materiales, el
# nombre de la pestaña...).
const AMBAR := Color(0.95, 0.72, 0.36)

# Devuelve el Label para poder colgarle cosas encima (ver _titulo_rareza).
func _title(vb: VBoxContainer, txt: String, color: Color = AMBAR) -> Label:
	return MenuScaffold.titulo(vb, txt, 16, color)


# Titulo de una pieza de EQUIPO: su NOMBRE con el color de su rareza y los destellos centelleando
# SOBRE el propio nombre. Es lo mismo dicho de tres maneras (el escalon escrito, el color y el
# brillo) en el mismo sitio, que es donde miras primero.
#
# Los destellos son HIJOS del Label, no una banda debajo: los hijos de un CanvasItem se dibujan
# DESPUES del padre, asi que caen por encima del texto. Y al ser hijos heredan su colocacion, que es
# lo unico que hace que sigan al nombre cuando el contenedor lo mueve.
#
# Aqui NO va una fila "Tier / rareza": Game.item_display_name YA termina en "· T1 Obra maestra", asi
# que esa fila repetia el titulo palabra por palabra.
#
# Las particulas van en la ficha (= UN objeto protagonista) y NO en la cuadricula de la izquierda:
# alli hay 20-40 botones a la vez y serian ruido y coste por nada.
func _titulo_rareza(vb: VBoxContainer, item: Resource, sufijo: String = "") -> void:
	MenuScaffold.titulo_item(vb, Game.item_display_name(item) + sufijo,
		Game.color_rareza_de(item), Game.intensidad_rareza_de(item))


# EL BANNER de la ficha: el objeto en grande justo debajo de su nombre. Va SIEMPRE, en las ocho
# pestañas, y es lo que hace de puente entre las dos mitades de la pantalla: la celda que acabas de
# pulsar reaparece aqui a lo grande, asi que no hay que ir a comprobar a la rejilla si le has dado a
# la que querias. La etiqueta de arriba dice de QUE tipo de cosa se trata, como en la referencia.
func _banner(vb: VBoxContainer, item: Resource, cantidad: int, etiqueta: String) -> void:
	MenuScaffold.banner_item(vb, item, ("× %d" % cantidad) if cantidad > 0 else "", etiqueta)


# Lo mismo para un MATERIAL, con su color de RANGO en vez de rareza (ver MaterialData.rango_color):
# gris/verde/azul para lo que se recolecta, hasta morado en las babas y amarillo en los nucleos.
# Un cristal no entra: tiene su propia escala de categoria/calidad.
func _titulo_material(vb: VBoxContainer, modelo: Resource, texto: String) -> void:
	var data: MaterialData = (modelo as MaterialItem).data if modelo is MaterialItem else null
	if data == null:
		_title(vb, texto)
		return
	MenuScaffold.titulo_item(vb, texto, data.color_rango(), data.rango_intensidad())


func _row(vb: VBoxContainer, etiqueta: String, valor: String, color_valor: Variant = null) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = etiqueta
	k.custom_minimum_size = Vector2(150, 0)
	k.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	row.add_child(k)
	var v := Label.new()
	v.text = valor
	if color_valor is Color:
		v.add_theme_color_override("font_color", color_valor)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Sin esto una linea larga (p.ej. el resumen() del material) se sale del ancho y, como
	# el scroll horizontal esta apagado, se recorta en el borde y arrastra a toda la columna.
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(v)
	vb.add_child(row)

func _note(vb: VBoxContainer, txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
	l.add_theme_font_size_override("font_size", 11)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Sin ancho MINIMO: en el panel de detalle (estrecho) empujaria la columna fuera de la
	# pantalla. Que se ajuste al hueco y parta las lineas.
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(l)


# PESTAÑA DE ARRIBA: sin caja, solo el texto, y un SUBRAYADO en la activa. El boton del tema es un
# ladrillo de 44 px con borde, y seis de esos en fila parecen seis botones de accion en vez de seis
# solapas de un archivador. Lo que dice cual esta abierta es la linea de abajo, como en un navegador.
func _estilo_pestana(b: Button) -> void:
	b.custom_minimum_size = Vector2(0, 36)
	b.add_theme_font_size_override("font_size", 15)
	for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74))
	b.add_theme_color_override("font_hover_color", Color(0.92, 0.94, 0.98))
	# La activa (que es la que esta 'pressed', porque son toggle) en ambar y con su linea.
	b.add_theme_color_override("font_pressed_color", AMBAR)
	b.add_theme_color_override("font_hover_pressed_color", AMBAR)
	b.add_theme_color_override("font_focus_color", Color(0.92, 0.94, 0.98))
	b.draw.connect(func() -> void:
		if not b.button_pressed:
			return
		var y: float = b.size.y - 2.0
		b.draw_rect(Rect2(Vector2(6, y), Vector2(b.size.x - 12.0, 2.0)), AMBAR))
	# Un Button no se repinta al marcarse/desmarcarse, y aqui lo unico que cambia es lo que dibuja
	# ese draw: sin esto, el subrayado se quedaba en la pestaña anterior.
	b.toggled.connect(func(_on): b.queue_redraw())


# Cuantas columnas caben en el ancho que tenga la rejilla AHORA MISMO. Se mide en vez de fijarla
# porque el ancho depende de la ventana (y en movil, de la orientacion): con un numero fijo, o
# sobraba media columna de hueco o la ultima se salia por el borde -- y el scroll horizontal esta
# apagado, asi que salirse significa que no hay forma de llegar a esa columna.
#
# El 6.0 es la separacion entre celdas de rejilla_objetos. Se cuenta una de mas y se resta, que es
# la cuenta de "n celdas y n-1 huecos" puesta del derecho.
func _columnas() -> int:
	var ancho: float = _lista.size.x
	if ancho <= 1.0:
		ancho = ANCHO_REJILLA_MIN   # primera pasada: aun no lo ha colocado el contenedor
	return maxi(2, int(floorf((ancho + 6.0) / (LADO_CELDA + 6.0))))


# Cuando la ventana cambia de ancho, la cuenta de columnas cambia con ella y hay que rehacer la
# rejilla. Se reconstruye SOLO si el numero de columnas ha cambiado de verdad: 'resized' salta en
# cada pixel de un arrastre de ventana, y reconstruir el menu entero 60 veces por segundo se nota.
var _cols_pintadas: int = 0

func _on_lista_redimensionada() -> void:
	if not _root.visible:
		return
	if _columnas() == _cols_pintadas:
		return
	_rebuild()


# La cuadricula va a la columna de la LISTA (con su scroll: la bolsa se llena) y la ficha al
# panel de DETALLE (con el suyo). La cabecera se queda quieta arriba.
#
# 'piezas' son los diccionarios que pide MenuScaffold.rejilla_objetos, y salen SIEMPRE de _stacks en
# el mismo orden: es lo que garantiza que la celda que pulsas y la ficha que sale sean la misma cosa.
func _grid_detail(piezas: Array, preview: Callable) -> void:
	if piezas.is_empty():
		_note(_content, "(vacío)")
		return
	_sel = clampi(_sel, 0, piezas.size() - 1)
	_cols_pintadas = _columnas()
	MenuScaffold.rejilla_objetos(_lista, piezas, _sel, _pick, _cols_pintadas, LADO_CELDA)
	preview.call(_content)


# Una celda: el objeto, lo que va en su banda y el texto largo del tooltip. 'marca' es la etiqueta
# de esquina (PUESTA, la que lleva un compañero...).
func _pieza(modelo: Resource, pie: String, tooltip: String, marca: String = "") -> Dictionary:
	return {"item": modelo, "pie": pie, "tooltip": tooltip, "marca": marca, "activo": true}


# Las celdas de una lista de stacks {modelo, cantidad}: la banda lleva el "xN" y el tooltip el
# nombre entero (que en la celda no cabe y en la rejilla vieja era lo unico que habia).
func _piezas_stacks(stacks: Array) -> Array:
	var out: Array = []
	for s in stacks:
		var n: int = int(s["cantidad"])
		out.append(_pieza(s["modelo"], "x%d" % n,
			"%s  x%d" % [_nombre_item(s["modelo"]).replace("\n", " "), n]))
	return out


func _pick(i: int) -> void:
	_sel = i
	_rebuild()


# ============================================================
#  Stacks (agrupacion de items iguales)
# ============================================================

# Agrupa una lista de Cristal/MaterialItem en stacks {modelo, cantidad}.
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
		# El TAMAÑO entra en la clave: dos peces de la misma especie con tallas distintas NO son el
		# mismo item y no pueden apilarse en un solo monton. Si se apilaran, el de 61 cm y el de 12
		# se venderian al mismo precio y la corona no sabria a cual pegarse.
		return "m|%s|%d|%d" % [m.nombre(), int(m.calidad), roundi(m.cm)]
	return "?"


func _nombre_item(it: Resource) -> String:
	if it is Cristal:
		var c := it as Cristal
		return "Cristal Cat %d\n(%s)" % [c.categoria, c.calidad_texto()]
	if it is MaterialItem:
		var m := it as MaterialItem
		# nombre_mostrado() lleva ya la talla y la corona del record; en todo lo que no es pescado
		# devuelve el nombre a secas.
		return "%s\n(%s)" % [m.nombre_mostrado(), m.calidad_texto()]
	if it is ConsumableData:
		return (it as ConsumableData).nombre
	return "?"


# ============================================================
#  Pestaña BOLSA
# ============================================================

func _build_bolsa() -> void:
	_title(_header, "BOLSA  (expedición)")
	var peso: float = Game.peso_actual()
	var cap: float = Game.capacidad_carga()
	var cab := Label.new()
	cab.text = "Peso: %d / %d%s" % [roundi(peso), roundi(cap),
		"    ¡SOBRECARGADO!" if Game.esta_sobrecargado() else ""]
	cab.add_theme_color_override("font_color",
		Color(1.0, 0.5, 0.5) if Game.esta_sobrecargado() else Color(0.85, 0.88, 0.92))
	_header.add_child(cab)
	_note(_header, "Lo que llevas encima. Los cristales solo salen vendiéndolos en la tienda; los materiales puedes guardarlos en el Hogar.")
	_header.add_child(HSeparator.new())

	var items: Array = []
	for c in Game.crystals:
		items.append(c)
	for m in Game.materiales:
		items.append(m)
	_stacks = _agrupar(items)
	_grid_detail(_piezas_stacks(_stacks), _preview_bolsa)


func _preview_bolsa(vb: VBoxContainer) -> void:
	var s: Dictionary = _stacks[_sel]
	var modelo: Resource = s["modelo"]
	var n: int = int(s["cantidad"])
	_titulo_material(vb, modelo, _nombre_item(modelo).replace("\n", " "))
	_banner(vb, modelo, n, "Cristal" if modelo is Cristal else "Material")
	_row(vb, "Cantidad", str(n))
	if modelo is Cristal:
		var c := modelo as Cristal
		_row(vb, "Categoría", str(c.categoria))
		_row(vb, "Calidad", c.calidad_texto())
		_row(vb, "Valor estimado", "%d  (total %d)" % [c.valor_estimado(), c.valor_estimado() * n])
		_row(vb, "Peso", "%.1f  (total %.1f)" % [c.peso(), c.peso() * n])
	elif modelo is MaterialItem:
		var m := modelo as MaterialItem
		if m.data != null:
			_row(vb, "Material", m.data.resumen())
		_row(vb, "Calidad", m.calidad_texto())
		_row(vb, "Valor estimado", "%d  (total %d)" % [m.valor_estimado(), m.valor_estimado() * n])
		_row(vb, "Peso", "%.1f  (total %.1f)" % [m.peso(), m.peso() * n])
		if m.data != null and m.data.descripcion != "":
			_note(vb, m.data.descripcion)

	vb.add_child(HSeparator.new())
	MenuScaffold.pastilla(vb, "Soltar al suelo", _on_soltar, false)
	_note(vb, "Lo que sueltes queda en el suelo a tus pies; puedes recogerlo otra vez con [F].")


func _on_soltar() -> void:
	var s: Dictionary = _stacks[_sel]
	var n: int = int(s["cantidad"])
	_pending_modelo = s["modelo"]
	if n <= 1:
		_confirmar_soltar(1)   # una sola unidad: sin modal
	else:
		_abrir_modal_cantidad(n)


func _confirmar_soltar(cant: int) -> void:
	if _pending_modelo != null:
		Game.soltar_item(_pending_modelo, cant)
		_pending_modelo = null
	_rebuild()


# ============================================================
#  Pestaña MOCHILA
#  La mochila es del EQUIPO, no de un personaje: la bolsa que llena tambien es una sola. Por eso
#  vive aqui, al lado del peso que modifica, y no en la ficha de nadie (estaba en la pestaña
#  Armadura del menu [C], entre cinco slots que si son personales, y eso hacia pensar que cada uno
#  llevaba la suya y que el peso se contaba por cabeza).
# ============================================================

# La pestaña EQUIPO. Tiene DOS subpestañas (mochila y herramientas) en vez de dos pestañas propias
# porque _rebuild() despacha por INDICE contra TABS: meter una pestaña nueva en medio desordena el
# match entero. Y ademas las dos cosas son lo mismo conceptualmente — equipo del GRUPO que no es de
# combate: no lo lleva un personaje, no pesa y no entra en el loadout.
# El FAROLILLO tiene hueco propio y no va con las otras cuatro herramientas: no comparte NADA con
# ellas -- no tiene minijuego, no ahorra golpes, y ademas gasta un consumible. Su pantalla enseña
# el farolillo Y el carbon juntos, porque son una sola cosa: la luz.
const SUBS_EQUIPO := ["Mochila", "Herramientas", "Farolillo"]
var _sub_equipo: int = 0

func _build_equipo() -> void:
	MenuScaffold.pestanas(_header, SUBS_EQUIPO, _sub_equipo, _on_sub_equipo)
	_header.add_child(HSeparator.new())
	match _sub_equipo:
		0: _build_mochila()
		2: _build_farolillo()
		_: _build_herramientas()


func _on_sub_equipo(i: int) -> void:
	_sub_equipo = i
	_sel = 0
	_rebuild()


func _build_mochila() -> void:
	_title(_header, "MOCHILA  (del equipo)")
	var m: BackpackData = Game.mochila_equipo
	_note(_header, "Una sola para todo el grupo: es lo único que sube la capacidad de carga. "
		+ "Llevas puesta: %s" % (Game.item_display_name(m) if m != null else "ninguna (solo el zurrón de serie)"))
	var cab := Label.new()
	cab.text = "Peso: %d / %d" % [roundi(Game.peso_actual()), roundi(Game.capacidad_carga())]
	cab.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	_header.add_child(cab)
	if not Game.en_pueblo():
		_note(_header, "Cambios de equipo solo en el pueblo. Aquí es solo consulta.")
	_header.add_child(HSeparator.new())

	_stacks = []
	for mo in Game.owned_mochilas:
		_stacks.append({"modelo": mo, "cantidad": 1})
	var piezas: Array = []
	for s in _stacks:
		var mo: BackpackData = s["modelo"]
		piezas.append(_pieza(mo, "", Game.item_display_name(mo),
			"PUESTA" if mo == Game.mochila_equipo else ""))
	_grid_detail(piezas, _preview_mochila)


# Ficha de una MOCHILA: lo unico que hace es subir la carga, asi que se enseña lo que SUMA y lo que
# llevarias con ella puesta (la Fuerza del grupo multiplica el conjunto, asi que el numero final no
# es una suma a pelo).
func _preview_mochila(vb: VBoxContainer) -> void:
	var m: BackpackData = _stacks[_sel]["modelo"]
	var puesta: bool = m == Game.mochila_equipo
	var meta: Dictionary = Game.meta_de(m)
	_titulo_rareza(vb, m, "   [puesta]" if puesta else "")
	_banner(vb, m, 0, "Mochila del equipo")
	_row(vb, "Capacidad", "+%.0f de carga" % Game.capacidad_mochila(m))
	_row(vb, "Llevaríais", "%.0f  (ahora: %.0f)" % [
		Game.capacidad_con_mochila(m), Game.capacidad_carga()])
	if m.descripcion != "":
		_note(vb, m.descripcion)

	vb.add_child(HSeparator.new())
	MenuScaffold.pastilla(vb, "Quitar" if puesta else "Equipar", func():
		Game.equipar_mochila(null if puesta else m)
		_rebuild(), not puesta, Game.en_pueblo())
	if puesta:
		_note(vb, "Al quitarla os quedáis con el zurrón de serie (25 de carga).")


# --- HERRAMIENTAS: pico, hoz, hacha y caña. Del grupo, como la mochila. ---
func _build_herramientas() -> void:
	_title(_header, "HERRAMIENTAS  (del equipo)")
	_note(_header, "No te entrenan más rápido: hacen la recolección menos hostil y sacas más material por rato. "
		+ "Una por tipo, para todo el grupo. Las forja el herrero.")
	var puestas: PackedStringArray = []
	for tipo in [ToolData.Tipo.PICO, ToolData.Tipo.HOZ, ToolData.Tipo.HACHA, ToolData.Tipo.CANA]:
		var t: ToolData = Game.herramienta_de_tipo(int(tipo))
		# La CAÑA es la unica que puede venir NULL: sin caña forjada no se pesca, no hay "de serie".
		if t == null:
			puestas.append("Caña: ninguna (sin ella no se pesca)")
			continue
		puestas.append("%s: %s" % [t.tipo_texto(),
			Game.item_display_name(t) if Game.es_herramienta_forjada(t) else "la de serie"])
	_note(_header, "   ·   ".join(puestas))
	if not Game.en_pueblo():
		_note(_header, "Cambios de equipo solo en el pueblo. Aquí es solo consulta.")
	_header.add_child(HSeparator.new())

	_stacks = []
	for t in Game.owned_tools:
		# Los farolillos tienen su propia pestaña: aqui estorbarian y su ficha no habla de nada de
		# lo que esta pantalla promete (afinidad y golpes ahorrados).
		if (t as ToolData).es_lampara():
			continue
		_stacks.append({"modelo": t, "cantidad": 1})
	if _stacks.is_empty():
		_note(_content, "Todavía no has forjado ninguna. El herrero las hace con metal y un tablón; "
			+ "el metal veteado o profundo da mejores herramientas que el cobre en bruto.")
		return
	var piezas: Array = []
	for s in _stacks:
		var t: ToolData = s["modelo"]
		piezas.append(_pieza(t, t.tipo_texto(), Game.item_display_name(t),
			"PUESTA" if Game.herramienta_equipada(t) else ""))
	_grid_detail(piezas, _preview_herramienta)


# --- FAROLILLO: la luz y su combustible, juntos ---
func _build_farolillo() -> void:
	_title(_header, "FAROLILLO  (del equipo)")
	_note(_header, "La mazmorra está a oscuras: solo ves lo que alumbra tu farolillo (o el de un "
		+ "compañero) y a lo que tengas línea recta. Cuanto más hondo bajas, menos alumbra el mismo "
		+ "farolillo. Sin él, o sin carbón, te queda el mínimo y nada más.")
	var puesto: ToolData = Game.equipped_lampara
	var cab := Label.new()
	if puesto == null:
		cab.text = "Sin farolillo  ·  alcance %.1f casillas (el mínimo)" % Vision.RADIO_MINIMO
	else:
		# LA LUZ TOTAL es el numero que decide si bajas otro piso o te vuelves, y antes no estaba en
		# ningun sitio: habia que sumar a ojo la llama actual y los trozos que llevabas.
		cab.text = "%s  ·  alcance %.1f casillas  ·  llama %s  ·  %s de luz en total" % [
			Game.item_display_name(puesto), Game.radio_lampara(),
			_mmss(Game.lampara_llama), _mmss(Game.luz_total_restante())]
	cab.add_theme_color_override("font_color", Color(0.98, 0.85, 0.55))
	_header.add_child(cab)
	if not Game.en_pueblo():
		_note(_header, "Cambios de equipo solo en el pueblo. Aquí es solo consulta.")
	_header.add_child(HSeparator.new())

	# EL CARBON, EN LA REJILLA junto a los farolillos y no en una linea de texto del cabecero. Dos
	# motivos: la linea AGRUPABA SOLO POR MATERIAL y cogia un trozo cualquiera de muestra para dar los
	# minutos, asi que con calidades mezcladas mentia en dos de cada tres (un vegetal Intacto dura un
	# tercio mas que uno Normal); y ademas asi se puede SELECCIONAR uno y soltarlo para pasarselo a un
	# companero, que antes no habia forma.
	#
	# Va aqui y no en la bolsa a proposito: no pesa y no se mezcla con el material de oficio al
	# guardar en casa (ver Game.carbon).
	_stacks = []
	for t in Game.owned_tools:
		if (t as ToolData).es_lampara():
			_stacks.append({"modelo": t, "cantidad": 1})
	var carbones: Array = _agrupar(Game.carbon)   # por material Y calidad (ver _clave_item)
	_stacks.append_array(carbones)
	if _stacks.is_empty():
		_note(_content, "No tienes ningún farolillo. Los forja el herrero, en Herramientas, "
			+ "con metal y unas hebillas.")
		return
	if carbones.is_empty():
		_note(_header, "No te queda carbón. Se pica en las vetas negras de la mazmorra, y el "
			+ "carpintero hace carbón vegetal con madera.")
	var piezas: Array = []
	for s in _stacks:
		var modelo: Resource = s["modelo"]
		if modelo is ToolData:
			piezas.append(_pieza(modelo, "", Game.item_display_name(modelo),
				"PUESTO" if Game.herramienta_equipada(modelo) else ""))
		else:
			# El CARBON lleva en la banda lo que dura UNO, que es el numero con el que se comparan
			# entre si; la cantidad se va al tooltip. Al reves (la cantidad en la banda) la rejilla
			# diria cuanto tienes pero no cual es mejor, que es a lo que se viene aqui.
			var m := modelo as MaterialItem
			piezas.append(_pieza(m, _mmss(Lampara.duracion(m)),
				"%s  x%d  (%s · %s cada uno)" % [m.data.nombre, int(s["cantidad"]),
					m.calidad_texto(), _mmss(Lampara.duracion(m))]))
	_grid_detail(piezas, _preview_farolillo)


# Segundos como "m:ss". Los escalones del carbon son de 30 s (2:00, 2:30, 3:00...), asi que
# redondeando a minutos -que es lo que se hacia- tres carbones distintos salian con el mismo numero.
func _mmss(seg: float) -> String:
	var s: int = int(round(maxf(seg, 0.0)))
	return "%d:%02d" % [s / 60, s % 60]


# La rejilla del farolillo lleva DOS clases de cosa (lamparas y trozos de carbon), asi que la ficha
# se reparte aqui en vez de tener dos rejillas separadas por una linea.
func _preview_farolillo(vb: VBoxContainer) -> void:
	if _stacks[_sel]["modelo"] is ToolData:
		_preview_herramienta(vb)
	else:
		_preview_carbon(vb)


func _preview_carbon(vb: VBoxContainer) -> void:
	var s: Dictionary = _stacks[_sel]
	var m: MaterialItem = s["modelo"]
	var n: int = int(s["cantidad"])
	_titulo_material(vb, m, m.data.nombre)
	_banner(vb, m, n, "Combustible")
	_row(vb, "Cantidad", str(n))
	_row(vb, "Calidad", m.calidad_texto())
	# Los DOS numeros: lo que dura uno y lo que dan todos juntos. El de arriba es el que compara
	# carbones entre si; el de abajo, el que te dice cuanto aguantas con este monton.
	_row(vb, "Llama", "%s cada uno" % _mmss(Lampara.duracion(m)))
	_row(vb, "En total", _mmss(Lampara.duracion(m) * float(n)))
	if m.data != null and m.data.descripcion != "":
		_note(vb, m.data.descripcion)
	vb.add_child(HSeparator.new())
	MenuScaffold.pastilla(vb, "Soltar al suelo", _on_soltar, false)
	_note(vb, "Lo que sueltes queda en el suelo a tus pies: es la forma de pasarle carbón a un "
		+ "compañero. Se recoge otra vez con [F].")


func _preview_herramienta(vb: VBoxContainer) -> void:
	var t: ToolData = _stacks[_sel]["modelo"]
	var puesta: bool = Game.herramienta_equipada(t)
	_titulo_rareza(vb, t, "   [puesta]" if puesta else "")
	_banner(vb, t, 0, t.tipo_texto())
	# Las filas salen de MenuScaffold, que las deriva de la MISMA math que usa el minijuego: lo que
	# lees aqui es exactamente lo que vas a jugar.
	for fila in MenuScaffold.filas_herramienta(t):
		_row(vb, fila[0], fila[1])
	if t.descripcion != "":
		_note(vb, t.descripcion)

	vb.add_child(HSeparator.new())
	MenuScaffold.pastilla(vb, "Quitar" if puesta else "Equipar", func():
		if puesta:
			Game.desequipar_herramienta(int(t.tipo))
		else:
			Game.equipar_herramienta(t)
		_rebuild(), not puesta, Game.en_pueblo())
	if puesta:
		if t.es_cana():
			_note(vb, "Sin caña no puedes pescar: no hay una de serie a la que volver.")
		else:
			_note(vb, "Al quitarla vuelves a la %s de serie, que no ayuda en nada."
				% t.tipo_texto().to_lower())


# ============================================================
#  Pestaña CONSUMIBLES
# ============================================================

func _build_consumibles() -> void:
	_title(_header, "CONSUMIBLES")
	_note(_header, "Selecciona una poción y elige a quién se la das. Cura por el tiempo (no de golpe).")
	_header.add_child(HSeparator.new())

	_stacks = []
	for c in Game.consumables.keys():
		var n: int = int(Game.consumables[c])
		if n > 0:
			_stacks.append({"modelo": c, "cantidad": n})
	var piezas: Array = []
	for s in _stacks:
		var cd := s["modelo"] as ConsumableData
		var n: int = int(s["cantidad"])
		piezas.append(_pieza(cd, "x%d" % n, "%s  x%d" % [cd.nombre, n],
			"PUESTO" if Game.cebo_activo == cd else ""))
	_grid_detail(piezas, _preview_consumible)


# De QUE clase es un consumible, para la etiqueta del banner. La pestaña mezcla cinco cosas que no
# se usan igual (una se bebe, otro se estudia, otro se come, otro se pone en el anzuelo), y el
# nombre solo no siempre lo dice: "Rocío" puede ser una poción o un grimorio.
func _clase_consumible(c: ConsumableData) -> String:
	if c.es_grimorio():
		return "Grimorio"
	if c.es_plato():
		return "Plato de cocina"
	if c.es_cebo():
		return "Cebo de pesca"
	if c.da_mana() and not c.cura_hp():
		return "Poción de maná"
	if c.cura_hp():
		return "Poción de vida"
	return "Consumible"


func _preview_consumible(vb: VBoxContainer) -> void:
	var cons: ConsumableData = _stacks[_sel]["modelo"]
	var n: int = int(_stacks[_sel]["cantidad"])
	_title(vb, cons.nombre)
	_banner(vb, cons, n, _clase_consumible(cons))
	_row(vb, "Cantidad", str(n))

	var sabido: bool = false
	if cons.es_grimorio():
		# Con grupo, el estado se mira contra el LIDER solo para la cabecera; abajo cada boton dice
		# lo suyo, porque quien lo aprende lo eliges tu.
		sabido = Game.lider().equipped_spells.has(cons.spell)
		_row(vb, "Enseña", cons.spell.nombre)
		_row(vb, "Coste", "%d de maná" % cons.spell.coste_mana)
		_row(vb, "Hechizos", "%d / %d aprendidos" % [Game.lider().equipped_spells.size(), Game.MAX_HECHIZOS])
	elif cons.es_plato():
		# La ficha del plato ya trae QUE hace y CUANTO dura, todo derivado de sus efectos: aqui no se
		# escribe ni un numero (ver ConsumableData.resumen_plato).
		_note(vb, cons.resumen_plato())
	elif cons.es_cebo():
		_row(vb, "Atracción", cons.resumen(0.0, 0.0))
		_row(vb, "Puesto", "sí" if Game.cebo_activo == cons else "no")
	else:
		_row(vb, "Efecto", cons.resumen(Game.player_max_hp(), Game.player_max_mp()))
		_row(vb, "Duración", "%.0f s (fuera de combate)" % cons.segundos)
		_row(vb, "En combate", "%d turnos" % cons.turnos)
	if cons.descripcion != "":
		_note(vb, cons.descripcion)

	vb.add_child(HSeparator.new())
	# Una poción se le puede dar a CUALQUIERA del grupo, no solo al que va en cabeza: con varios
	# en el equipo sale un boton por persona (con su vida/maná, para ver quien la necesita).
	# Un GRIMORIO igual, y ademas es lo importante: el libro se GASTA al estudiarlo, asi que si iba
	# siempre al lider y el que querias que lo aprendiera no era el lider, perdias el hechizo y el
	# libro. Con uno solo en el grupo, el boton de siempre.
	# Un PLATO de cocina, lo mismo y por el mismo motivo que el grimorio: se gasta al comerlo y el
	# buff se lo queda SOLO quien lo come, asi que mandarlo siempre al lider seria perder el plato.
	var por_persona: bool = (cons.cura_hp() or cons.da_mana() or cons.es_grimorio() or cons.es_plato()) \
		and Game.party.size() > 1
	if por_persona:
		_note(vb, "¿Quién lo estudia?" if cons.es_grimorio() else (
			"¿Quién se lo come?" if cons.es_plato() else "¿A quién se la das?"))
		for pj in Game.party:
			var b := Button.new()
			var corona: String = "👑 " if pj == Game.lider() else ""
			if cons.es_grimorio():
				# Cada uno con SU cuenta de hechizos: uno puede tenerlo ya sabido y otro no, y uno
				# puede tener el hueco lleno y otro libre. Se dice cual es el motivo en el boton.
				var suyos: Array = pj.equipped_spells
				var lo_sabe: bool = suyos.has(cons.spell)
				var lleno: bool = suyos.size() >= Game.MAX_HECHIZOS
				var estado: String = "ya lo sabe" if lo_sabe else (
					"sin hueco" if lleno else "%d/%d hechizos" % [suyos.size(), Game.MAX_HECHIZOS])
				b.text = "%s%s  (%s)" % [corona, pj.nombre, estado]
				b.disabled = lo_sabe or lleno
			elif cons.es_plato():
				# Lo util aqui no es su vida: es SI YA VA COMIDO, porque el plato nuevo se lleva por
				# delante al que llevara puesto y eso conviene saberlo ANTES de gastarlo.
				var puesto: String = Game.plato_puesto(pj)
				b.text = "%s%s  (%s)" % [corona, pj.nombre,
					("lleva %s" % puesto) if puesto != "" else "sin comer"]
			else:
				var partes: Array = ["%.0f/%.0f ♥" % [Game.player_hp(pj), Game.player_max_hp(pj)]]
				if cons.da_mana():
					partes.append("%.0f/%.0f 🔷" % [Game.player_mp(pj), Game.player_max_mp(pj)])
				b.text = "%s%s  (%s)" % [corona, pj.nombre, "  ".join(partes)]
			b.pressed.connect(_on_usar.bind(cons, pj))
			vb.add_child(b)
	elif cons.es_cebo():
		# Un cebo NO se usa desde la bolsa: se pone en el anzuelo, y eso solo significa algo con el
		# agua delante. En vez de un boton que no haria nada, se dice donde se pone.
		_note(vb, "Los cebos se ponen en el estanque: ponte en la orilla y pulsa [F].")
	else:
		MenuScaffold.pastilla(vb,
			"Estudiar" if cons.es_grimorio() else ("Comer" if cons.es_plato() else "Usar"),
			_on_usar.bind(cons), true,
			not (cons.es_grimorio() and (sabido or Game.hechizos_llenos())))
	if cons.es_grimorio() and not por_persona:
		if sabido:
			_note(vb, "Ya te sabes este hechizo: el libro no te dice nada nuevo.")
		elif Game.hechizos_llenos():
			_note(vb, "No te caben más de %d hechizos a la vez: tendrás que olvidar uno antes." % Game.MAX_HECHIZOS)

	# SOLTAR. En un jugador es tirarla al suelo y volver a cogerla, poco mas; lo que arregla de
	# verdad es el MULTIJUGADOR, donde hasta ahora no habia NINGUNA forma de pasarle una poción a
	# otro: el que las llevaba encima se las quedaba aunque el que se estuviera muriendo fuera el
	# otro. Vale para toda la pestaña (grimorios y platos incluidos) por lo mismo.
	vb.add_child(HSeparator.new())
	MenuScaffold.pastilla(vb, "Soltar al suelo", _on_soltar, false)
	_note(vb, "Lo que sueltes queda a tus pies; lo puede recoger con [F] cualquiera del grupo.")


func _on_usar(cons: ConsumableData, pj: PersonajeData = null) -> void:
	Game.usar_consumible(cons, pj)   # poción -> se la bebe 'pj'; grimorio -> se estudia
	_rebuild()


# ============================================================
#  Pestaña MATERIALES (baul del hogar)
# ============================================================

func _build_materiales() -> void:
	_title(_header, "MATERIALES  (guardados en el Hogar)")
	_note(_header, "Los materiales que has depositado en el Hogar del pueblo. No pesan. Los cristales no se guardan aquí: hay que venderlos en la tienda.")
	_header.add_child(HSeparator.new())
	_stacks = _agrupar(Game.almacen_materiales)
	_grid_detail(_piezas_stacks(_stacks), _preview_material)


func _preview_material(vb: VBoxContainer) -> void:
	var m: MaterialItem = _stacks[_sel]["modelo"]
	var n: int = int(_stacks[_sel]["cantidad"])
	_titulo_material(vb, m, m.nombre())
	_banner(vb, m, n, "Material")
	_row(vb, "Cantidad", str(n))
	if m.data != null:
		_row(vb, "Material", m.data.resumen())
	_row(vb, "Calidad", m.calidad_texto())
	_row(vb, "Valor estimado", "%d  (total %d)" % [m.valor_estimado(), m.valor_estimado() * n])
	if m.data != null and m.data.descripcion != "":
		_note(vb, m.data.descripcion)


# ============================================================
#  Pestaña ARMAS (baul)
# ============================================================

func _build_armas() -> void:
	_title(_header, "ARMAS  (tu baúl)")
	_note(_header, "Lo que posees. Para equiparlo, abre el menú de personaje [C] en el pueblo.")
	_header.add_child(HSeparator.new())
	_stacks = []
	for w in Game.owned_weapons:
		_stacks.append({"modelo": w, "cantidad": 1})
	var piezas: Array = []
	for s in _stacks:
		var w: Resource = s["modelo"]
		# La marca de esquina es QUIEN LA LLEVA, no un "[equipada]" a secas: con grupo, la misma
		# espada puede estar puesta en cualquiera de los tuyos (ver _marca_dueno).
		var dueno: PersonajeData = Game.quien_lleva(w)
		piezas.append(_pieza(w, Game.item_plus(w), _nombre_equipo(w).replace("\n", " "),
			"" if dueno == null else dueno.nombre))
	_grid_detail(piezas, _preview_arma)


func _nombre_equipo(item: Resource) -> String:
	if item is WeaponData:
		return (item as WeaponData).nombre + Game.item_plus(item)
	if item is ShieldData:
		return (item as ShieldData).nombre + Game.item_plus(item) + "\n(escudo)"
	if item is WandData:
		return (item as WandData).nombre + Game.item_plus(item) + "\n(varita)"
	return "?"


# "Lo lleva Fulano", o "" si no lo lleva nadie. Con grupo, un [equipada] a secas no vale: la misma
# espada puede estar puesta en cualquiera de los tuyos, y mirando solo al lider (que es lo que se
# hacia) la de un compañero salia como si estuviera en el baul, suelta.
func _marca_dueno(item: Resource) -> String:
	var dueno: PersonajeData = Game.quien_lleva(item)
	return "" if dueno == null else "   [la lleva %s]" % dueno.nombre


func _preview_arma(vb: VBoxContainer) -> void:
	var item: Resource = _stacks[_sel]["modelo"]
	var equipada: String = _marca_dueno(item)
	if item is WeaponData:
		var w := item as WeaponData
		_titulo_rareza(vb, w, equipada)
		_banner(vb, w, 0, WEAPON_TIPO_LABELS[clampi(int(w.tipo), 0, WEAPON_TIPO_LABELS.size() - 1)])
		# Ficha COMPARTIDA (MenuScaffold.filas_arma): las mismas stats resueltas que ve la tienda
		# y el menu de personaje, con el tier/rareza/mejoras REALES de esta pieza (antes se
		# enseñaban los valores base a secas, ignorando las mejoras y sin la evasion).
		var meta: Dictionary = Game.meta_de(w)
		# La DURABILIDAD de ESTA arma entra en la cuenta: aqui se mira una pieza concreta del baul,
		# no un modelo de catalogo, y decir "20 de ataque" con la fila de abajo marcando un 60% de
		# desgaste es contar dos cosas que no casan (el combate ya le aplica el ×0.90).
		for fila in MenuScaffold.filas_arma(w, int(meta["tier"]), int(meta["rareza"]),
				meta["mejoras"], null, Game.durabilidad_item(w)):
			_row(vb, fila[0], fila[1])
		_row(vb, "Durabilidad", Game.durabilidad_txt_item(w), Game.durabilidad_color(w))
	elif item is ShieldData:
		var s := item as ShieldData
		_titulo_rareza(vb, s, equipada)
		_banner(vb, s, 0, "Escudo")
		# Ficha COMPARTIDA, igual que el arma de arriba: antes se pintaba el .tres crudo y un T3
		# pristino enseñaba (y rendia) exactamente lo mismo que uno comun.
		var meta_s: Dictionary = Game.meta_de(s)
		for fila in MenuScaffold.filas_escudo(s, int(meta_s["tier"]), int(meta_s["rareza"]), meta_s["mejoras"]):
			_row(vb, fila[0], fila[1])
		_row(vb, "Durabilidad", Game.durabilidad_txt_item(s), Game.durabilidad_color(s))
	elif item is WandData:
		var wd := item as WandData
		_titulo_rareza(vb, wd, equipada)
		_banner(vb, wd, 0, "Varita")
		# Por su math (Upgrades.magic_mods) con el tier/rareza/mejoras REALES de esta varita, como
		# el baston y el resto de equipo: antes se pintaba el .tres crudo (una varita T3 pristina
		# amplificaba y regeneraba lo mismo que una comun).
		var meta_w: Dictionary = Game.meta_de(wd)
		var mg: Dictionary = Upgrades.magic_mods(wd.magic_amp, Game.tier_mult(int(meta_w["tier"])),
			int(meta_w["rareza"]), meta_w["mejoras"])
		_row(vb, "Amplif. magia", "×%.2f" % float(mg["magic_amp"]))
		_row(vb, "Regen maná", "%.2f/turno" % (wd.mp_regen_turno * float(mg["regen_mult"])))
		_row(vb, "Vel. casteo", "×%.2f" % (wd.cast_vel_mult + float(mg["cast_vel_add"])))
		if float(mg["mana_reduccion"]) > 0.0:
			_row(vb, "Coste de maná", "-%.0f%%" % (float(mg["mana_reduccion"]) * 100.0))
		for fila in MenuScaffold.filas_critico_magico(mg, wd.crit_bonus):
			_row(vb, fila[0], fila[1])
		_row(vb, "Durabilidad", Game.durabilidad_txt_item(wd), Game.durabilidad_color(wd))


# ============================================================
#  Pestaña ARMADURAS (baul)
# ============================================================

func _build_armaduras() -> void:
	_title(_header, "ARMADURAS  (tu baúl)")
	_note(_header, "Lo que posees. Para equiparlo, abre el menú de personaje [C] en el pueblo.")
	_header.add_child(HSeparator.new())
	_stacks = []
	for p in Game.owned_armor:
		_stacks.append({"modelo": p, "cantidad": 1})
	var piezas: Array = []
	for s in _stacks:
		var a: ArmorData = s["modelo"]
		var dueno_a: PersonajeData = Game.quien_lleva(a)
		piezas.append(_pieza(a, ARMOR_SLOT_LABELS[clampi(int(a.slot), 0, 4)],
			"%s%s" % [a.nombre, Game.item_plus(a)],
			"" if dueno_a == null else dueno_a.nombre))
	_grid_detail(piezas, _preview_armadura)


func _preview_armadura(vb: VBoxContainer) -> void:
	var a: ArmorData = _stacks[_sel]["modelo"]
	_titulo_rareza(vb, a, _marca_dueno(a))
	_banner(vb, a, 0, ARMOR_SLOT_LABELS[clampi(int(a.slot), 0, 4)])
	_row(vb, "Slot", ARMOR_SLOT_LABELS[clampi(int(a.slot), 0, 4)])
	_row(vb, "Tipo", ARMOR_TIPO_LABELS[clampi(int(a.tipo), 0, 3)])
	_row(vb, "Defensa base", "%.2f" % (a.defensa_base * a.motion_def))
	_row(vb, "Reducción", "%.0f%%" % (a.reduccion * 100.0))
	_row(vb, "Velocidad", "×%.2f" % a.velocidad_mult)
	_row(vb, "Durabilidad", Game.durabilidad_txt_item(a), Game.durabilidad_color(a))


# ============================================================
#  Modal de CANTIDAD (para soltar varias unidades de un stack)
# ============================================================

func _abrir_modal_cantidad(maximo: int) -> void:
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
	l.text = "¿Cuántas quieres soltar?  (máx. %d)" % maximo
	vb.add_child(l)

	_modal_spin = SpinBox.new()
	_modal_spin.min_value = 1
	_modal_spin.max_value = maximo
	_modal_spin.step = 1
	_modal_spin.value = 1
	vb.add_child(_modal_spin)
	# ENTER confirma, sin tener que ir a buscar el boton con el raton. Y el foco entra ya en la
	# caja: se abre el modal, se teclea el numero y se pulsa Enter.
	_modal_spin.get_line_edit().text_submitted.connect(func(_t): _modal_aceptar())
	_modal_spin.get_line_edit().call_deferred("grab_focus")

	var acciones := HBoxContainer.new()
	acciones.add_theme_constant_override("separation", 8)
	var ok := Button.new()
	ok.text = "Soltar"
	ok.pressed.connect(_modal_aceptar)
	acciones.add_child(ok)
	# El caso mas comun -y el que mas cansa de uno en uno- es vaciar el monton entero.
	var todo := Button.new()
	todo.text = "Todo (%d)" % maximo
	todo.pressed.connect(func():
		_cerrar_modal()
		_confirmar_soltar(maximo))
	acciones.add_child(todo)
	var ca := Button.new()
	ca.text = "Cancelar"
	ca.pressed.connect(_cancelar_modal)
	acciones.add_child(ca)
	vb.add_child(acciones)


# OJO CON EL SpinBox: lo que TECLEAS no llega a .value hasta que se confirma el texto (Enter o
# perder el foco), y pulsar el boton con el raton no lo confirmaba. O sea que escribias 10, dabas a
# "Soltar" y se soltaba UNA: .value seguia siendo el 1 de partida. apply() vuelca el texto de la
# caja al valor, y por eso va ANTES de leerlo. Medido con dev_soltar.gd (16/08/2026).
func _modal_aceptar() -> void:
	var cant: int = 1
	if _modal_spin != null:
		_modal_spin.apply()
		cant = int(_modal_spin.value)
	_cerrar_modal()
	_confirmar_soltar(cant)


func _cancelar_modal() -> void:
	_pending_modelo = null
	_cerrar_modal()


func _cerrar_modal() -> void:
	if _modal != null:
		_modal.queue_free()
		_modal = null
	_modal_spin = null
