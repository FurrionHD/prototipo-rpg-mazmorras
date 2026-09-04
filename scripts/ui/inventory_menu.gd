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
# El icono de cada pestaña, en el mismo orden que TABS. Van con icono y SIN texto, como en los
# menus de referencia: seis palabras en fila se leen una a una, seis siluetas se abarcan de un
# vistazo. El nombre no se pierde -- sale escrito arriba a la izquierda, bajo "INVENTARIO", y en el
# tooltip de cada una.
const TAB_ICONOS := ["bolsa", "mochila", "pocion", "mineral", "espada", "coraza"]

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
var _contador_lbl: Label = null     # el "N / M" de la pestaña (peso, luz), al lado del dinero
var _titulo_seccion: Label = null   # el nombre de la pestaña, bajo "Inventario"
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

	# LA LINEA DE AVISO, FUERA. El esqueleto la reserva con 22 px de alto AUNQUE ESTE VACIA, a
	# proposito: en los menus de oficio aparece y desaparece con cada mensaje ("Sacas 3 lingotes"),
	# y si no ocupara sitio siempre, el menu entero pegaria un salto cada vez. Este menu no dice
	# nada por ahi -- no llama a MenuScaffold.decir ni una vez --, asi que esos 22 px eran hueco
	# muerto entre las pestañas de arriba y la rejilla.
	(m["aviso"] as Control).visible = false

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

	# LA COLUMNA IZQUIERDA: la fila de subpestañas ENCIMA de la rejilla, dentro de su misma columna.
	#
	# Antes la fila iba en el header, que cruza la pantalla ENTERA por encima de las dos columnas.
	# Eso tenia dos defectos: empujaba hacia abajo tambien a la ficha de la derecha (que se quedaba
	# una linea por debajo del borde de arriba, con un palmo de nada encima), y la fila quedaba
	# centrada respecto a rejilla + ficha, o sea corrida a la derecha respecto a la rejilla que
	# filtra.
	#
	# Metiendola en la columna, la ficha sube hasta arriba del todo y la fila se centra sobre LO QUE
	# FILTRA. Va FUERA del scroll (hermana suya, no hija) para que no se vaya con la rejilla al
	# desplazarse: un filtro que desaparece al bajar es un filtro que hay que ir a buscar.
	var split: BoxContainer = scroll.get_parent()
	split.remove_child(scroll)
	var col_izq := VBoxContainer.new()
	col_izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_izq.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_izq.add_theme_constant_override("separation", 4)
	split.add_child(col_izq)
	split.move_child(col_izq, 0)
	_barra_sub = HBoxContainer.new()
	_barra_sub.alignment = BoxContainer.ALIGNMENT_CENTER
	_barra_sub.add_theme_constant_override("separation", 14)
	col_izq.add_child(_barra_sub)
	col_izq.add_child(scroll)
	# LA BARRA DE ABAJO (orden y filtros) va en esta columna y no cruzando la pantalla: manda sobre
	# la REJILLA, no sobre la ficha, y ponerla debajo de las dos la desconectaria de lo que cambia.
	_barra_pie = HBoxContainer.new()
	_barra_pie.add_theme_constant_override("separation", 10)
	col_izq.add_child(_barra_pie)

	var barra_tabs: HBoxContainer = m["side"]
	barra_tabs.add_theme_constant_override("separation", 14)
	for i in TABS.size():
		var b: Button = _pestana_icono(TAB_ICONOS[i], TABS[i])
		b.pressed.connect(_on_tab.bind(i))
		barra_tabs.add_child(b)
		_tab_buttons.append(b)

	var barra: BoxContainer = barra_tabs.get_parent()

	# EL TITULO EN DOS LINEAS: "Inventario" pequeño y gris encima del nombre de la seccion, grande.
	# Es lo que sustituye a la cabecera que habia debajo de las pestañas -- alli el titulo de la
	# pestaña ocupaba una linea entera de la pantalla para decir lo mismo. Y hace falta: con las
	# pestañas en icono, este es el sitio donde pone en que seccion estas.
	# La etiqueta que trae el esqueleto se esconde en vez de borrarse: un Control oculto no ocupa
	# sitio en un contenedor, asi que basta con eso y no hay que tocar construir().
	(barra.get_child(0) as Control).visible = false
	var titulo := VBoxContainer.new()
	titulo.add_theme_constant_override("separation", 0)
	_titulo_seccion = Label.new()
	var chico := Label.new()
	chico.text = "Inventario"
	chico.add_theme_font_size_override("font_size", 11)
	chico.add_theme_color_override("font_color", MenuScaffold.GRIS)
	titulo.add_child(chico)
	_titulo_seccion.add_theme_font_size_override("font_size", 20)
	_titulo_seccion.add_theme_color_override("font_color", AMBAR)
	titulo.add_child(_titulo_seccion)
	barra.add_child(titulo)
	barra.move_child(titulo, 1)

	# PESTAÑAS CENTRADAS DE VERDAD, EN LA MITAD DE LA PANTALLA.
	#
	# Dentro de la barra no se puede: la barra es [titulo][tabs][hueco][contador][dinero][✕], asi que
	# "centrar" ahi dentro es centrar en el hueco que sobra entre el titulo y el dinero -- y como esos
	# dos no miden lo mismo, la fila quedaba corrida a la izquierda. Y encima se movia sola: el
	# contador cambia de ancho al cambiar de pestaña, asi que las pestañas BAILABAN de sitio al
	# pulsarlas.
	#
	# Se sacan de la barra y se cuelgan de la raiz, en un CenterContainer que ocupa todo el ancho.
	# Asi el centro es el de la pantalla, es el MISMO que el de las subpestañas de abajo (que ya
	# estaban centradas a todo lo ancho: por eso las dos filas no coincidian), y no depende de lo
	# que midan sus vecinos.
	barra.remove_child(barra_tabs)
	var centrador := CenterContainer.new()
	centrador.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	centrador.offset_top = 16.0
	centrador.offset_bottom = 16.0 + MenuScaffold.LADO_ICONO
	# Que no robe los clics de lo que hay debajo (el CenterContainer ocupa todo el ancho): los
	# botones de dentro los siguen recibiendo, porque un hijo con MOUSE_FILTER_STOP manda sobre el
	# IGNORE del padre.
	centrador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(centrador)
	centrador.add_child(barra_tabs)

	# EL CONTADOR de la pestaña (peso de la bolsa, luz que queda). NO es informacion del objeto -- es
	# del estado del grupo -- asi que no cabe en la ficha de la derecha; va arriba con el dinero,
	# que es justo donde la referencia pone su "Cantidad de artefactos: 229/3000".
	_contador_lbl = Label.new()
	_contador_lbl.add_theme_font_size_override("font_size", 15)
	_contador_lbl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.90))

	# LAS MONEDAS, A LA BARRA DE ARRIBA. El esqueleto las cuelga ANCLADAS bajo la esquina de la ✕,
	# que es donde van cuando la ✕ flota sobre la pantalla; pero con la barra superior la ✕ vive
	# dentro de la barra, asi que las monedas se quedaban solas flotando en mitad de la cabecera y en
	# cuerpo 22, gritando. Aqui pasan a ser una pieza mas de la barra, al lado de la ✕.
	_dinero_lbl.get_parent().remove_child(_dinero_lbl)
	_dinero_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_dinero_lbl.custom_minimum_size = Vector2.ZERO
	_dinero_lbl.add_theme_font_size_override("font_size", 15)
	# Los dos, justo ANTES de la ✕, que es el ultimo hijo de la barra.
	for l in [_contador_lbl, _dinero_lbl]:
		barra.add_child(l)
		barra.move_child(l, barra.get_child_count() - 2)


# ESC va en _input y CONSUME el evento: _input corre SIEMPRE antes que _unhandled_input, asi que el
# menu de PAUSA (que escucha ahi) no llega a ver la tecla y no se abre por detras al cerrar la bolsa.
func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if not event.is_action_pressed(&"cancelar"):
		return
	# Primero el modal que haya encima (cantidad, orden, filtros) y solo despues la bolsa: si no,
	# el primer Esc cerraria el menu entero por debajo del modal.
	if _modal != null:
		_cerrar_modal()
	elif _modal_capa != null:
		_cerrar_modal_barra()
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
		_cerrar_modal_barra()
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
	# El contador arranca VACIO en cada pasada: cada pestaña pone el suyo (o ninguno) llamando a
	# _contador(). Si no se limpiara aqui, el peso de la bolsa se quedaria pegado arriba al pasarse
	# a la pestaña de armas.
	_contador("")
	# El nombre de la seccion, arriba a la izquierda bajo "Inventario". Las subpestañas lo afinan
	# despues (Equipo -> "Farolillo"), que es la unica forma de saber donde estas con las pestañas
	# en icono.
	_titulo_seccion.text = TABS[clampi(_tab, 0, TABS.size() - 1)]
	# La fila de subpestañas vive fuera del header, asi que vaciar() no se la lleva: si no se vacia
	# aqui, las tres de Equipo se quedaban encima de la rejilla de la Bolsa. La pestaña que tenga
	# subpestañas la vuelve a poner en su _build.
	_subpestanas([], [], -1, Callable())
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
	# AL FINAL: los recuentos del embudo salen de _stacks_sin_filtrar, que lo deja _aplicar() dentro
	# del _build de la pestaña. Pintada antes, saldrian todos a cero.
	_pintar_barra_pie()


# El contador de arriba a la derecha: el estado del GRUPO en esta pestaña (peso de la bolsa, luz
# que queda), que no es de ningun objeto y por eso no cabe en la ficha. Texto vacio = no se enseña.
# 'alerta' lo pinta en rojo (sobrecargado, sin caña, sin luz).
func _contador(txt: String, alerta: bool = false) -> void:
	_contador_lbl.text = txt
	_contador_lbl.visible = txt != ""
	_contador_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.52, 0.52) if alerta else Color(0.78, 0.82, 0.90))


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
	k.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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


# ============================================================
#  LAS PESTAÑAS
#  Sin caja: solo el contenido y un SUBRAYADO en la activa. El boton del tema es un ladrillo de
#  44 px con borde, y seis de esos en fila parecen seis botones de accion en vez de seis solapas de
#  un archivador. Lo que dice cual esta abierta es la linea de abajo, como en un navegador.
# ============================================================

const TAB_APAGADA := Color(0.55, 0.59, 0.67)
const LADO_TAB := 34.0
# La fila de subpestañas: vive en la columna IZQUIERDA, encima de la rejilla y fuera de su scroll
# (ver el montaje en _ready). Se construye una vez y cada pestaña la rellena o la deja vacia.
var _barra_sub: HBoxContainer = null

# El armazon comun de las dos clases de pestaña (la de arriba, con icono; la de dentro, con texto).
func _pestana_base(b: Button, alto: float) -> void:
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, alto)
	for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
	b.draw.connect(func() -> void:
		if not b.button_pressed:
			return
		var y: float = b.size.y - 2.0
		b.draw_rect(Rect2(Vector2(4, y), Vector2(b.size.x - 8.0, 2.0)), AMBAR))
	# Un Button no se repinta al marcarse/desmarcarse, y aqui lo unico que cambia es lo que dibuja
	# ese draw: sin esto, el subrayado se quedaba en la pestaña anterior.
	b.toggled.connect(func(_on): b.queue_redraw())


# PESTAÑA CON ICONO (la fila de arriba). El icono se dibuja encima del boton, no como textura: los
# iconos del proyecto son funciones de dibujo (ver iconos.gd) para que se vean igual en Windows y en
# el movil, sin depender de que el aparato tenga una fuente con emoji.
#
# El NOMBRE va en el tooltip y, sobre todo, escrito arriba a la izquierda bajo "Inventario": una
# fila de seis iconos pelados sin ningun sitio donde leer que es cada uno seria un acertijo.
func _pestana_icono(icono: String, nombre: String) -> Button:
	var b := Button.new()
	_pestana_base(b, LADO_TAB + 10.0)
	b.custom_minimum_size.x = LADO_TAB + 14.0
	b.tooltip_text = nombre
	var dibujo := Callable(Iconos, icono)
	b.draw.connect(func() -> void:
		var pad: float = (b.size.x - LADO_TAB) * 0.5
		dibujo.call(b, Vector2(pad, 3.0), LADO_TAB,
			AMBAR if b.button_pressed else TAB_APAGADA))
	return b


# La fila de SUBpestañas, con icono igual que la de arriba y centrada en el mismo eje (las dos van
# al centro de la pantalla entera, asi que caen una debajo de la otra). Va en el header, que es lo
# unico que queda ahi dentro: el resto de la cabecera se fue a la ficha o al contador de arriba.
#
# El nombre de la subpestaña activa se lee arriba a la izquierda, donde el de la seccion: con las
# dos filas en icono, ese rotulo es el unico sitio donde pone donde estas, y por eso lo pisa la
# subpestaña (en Equipo, saber que estas en "Farolillo" dice mas que saber que estas en "Equipo").
# Monta la fila de subpestañas de la columna izquierda. La vacia siempre, asi que una pestaña sin
# subpestañas (la bolsa, los consumibles) simplemente no la llama y la fila desaparece: su
# contenedor se queda a cero de alto y la rejilla sube.
func _subpestanas(nombres: Array, iconos: Array, activa: int, pulsado: Callable) -> void:
	for b in _barra_sub.get_children():
		_barra_sub.remove_child(b)
		b.queue_free()
	for i in nombres.size():
		var b: Button = _pestana_icono(String(iconos[i]), String(nombres[i]))
		b.button_pressed = (i == activa)
		b.pressed.connect(pulsado.bind(i))
		_barra_sub.add_child(b)


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
	# El PESO va arriba, con el dinero: es el estado de la bolsa, no de ningun objeto, y ahi esta
	# siempre a la vista en vez de comerse una linea de la pantalla.
	# Sin la palabra "SOBRECARGADO": los propios numeros ya lo dicen (el de la izquierda pasa al de
	# la derecha) y ademas se pinta en rojo. La palabra doblaba el ancho del contador.
	_contador("Peso  %d / %d" % [roundi(Game.peso_actual()), roundi(Game.capacidad_carga())],
		Game.esta_sobrecargado())

	var items: Array = []
	for c in Game.crystals:
		items.append(c)
	for m in Game.materiales:
		items.append(m)
	_stacks = _aplicar(_agrupar(items))
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
# Sus iconos, en el mismo orden (ver TAB_ICONOS para el porque de que vayan sin texto).
const SUBS_EQUIPO_ICONOS := ["mochila", "pico", "farol"]
var _sub_equipo: int = 0

func _build_equipo() -> void:
	_subpestanas(SUBS_EQUIPO, SUBS_EQUIPO_ICONOS, _sub_equipo, _on_sub_equipo)
	_titulo_seccion.text = SUBS_EQUIPO[clampi(_sub_equipo, 0, SUBS_EQUIPO.size() - 1)]
	match _sub_equipo:
		0: _build_mochila()
		2: _build_farolillo()
		_: _build_herramientas()


func _on_sub_equipo(i: int) -> void:
	_sub_equipo = i
	_sel = 0
	_rebuild()


func _build_mochila() -> void:
	_contador("Peso  %d / %d" % [roundi(Game.peso_actual()), roundi(Game.capacidad_carga())])

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
	if not Game.en_pueblo():
		_note(vb, "Cambios de equipo solo en el pueblo.")
	if puesta:
		_note(vb, "Al quitarla os quedáis con el zurrón de serie (25 de carga).")


# --- HERRAMIENTAS: pico, hoz, hacha y caña. Del grupo, como la mochila. ---
func _build_herramientas() -> void:
	# La lista de "que llevas puesto de cada tipo" ya no hace falta escrita: la rejilla marca las
	# puestas con su etiqueta de esquina, que es el mismo dato en el sitio donde se actua sobre el.
	# La CAÑA es la unica que puede faltar del todo (sin caña forjada no se pesca, no hay una de
	# serie a la que volver), asi que ESO si se avisa, porque no se deduce mirando la rejilla.
	if Game.herramienta_de_tipo(int(ToolData.Tipo.CANA)) == null:
		_contador("Sin caña", true)

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
	# LA LUZ TOTAL arriba, con el dinero: es el numero que decide si bajas otro piso o te vuelves, y
	# no es de ningun objeto -- suma la llama que arde ahora y todos los trozos que llevas. El
	# alcance y la llama de UN farolillo si son suyos, y por eso viven en su ficha.
	if Game.equipped_lampara == null:
		_contador("Sin farolillo", true)
	else:
		var luz: float = Game.luz_total_restante()
		_contador("Luz  %s" % _mmss(luz), luz <= 0.0)

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
	if not Game.en_pueblo():
		_note(vb, "Cambios de equipo solo en el pueblo.")
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

	var todos: Array = []
	for c in Game.consumables.keys():
		var n: int = int(Game.consumables[c])
		if n > 0:
			todos.append({"modelo": c, "cantidad": n})
	_stacks = _aplicar(todos)
	_contador("%d de %d" % [_stacks.size(), todos.size()])
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

	if cons.es_grimorio():
		# La cuenta de hechizos que se enseña aqui es la del LIDER, solo como referencia: quien lo
		# aprende de verdad lo eliges en el modal, y alli cada tarjeta lleva la suya.
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
	# UN CONSUMIBLE SE LE DA A ALGUIEN, y con grupo eso es una pregunta: la poción se la bebe quien
	# tu digas, el grimorio se GASTA al estudiarlo (si iba siempre al lider, el que querias que lo
	# aprendiera se quedaba sin el) y el plato se lo queda SOLO quien se lo come.
	#
	# Esa pregunta se hace en un modal con las tarjetas del grupo (ver _abrir_modal_usar), no con
	# una pila de botones aqui dentro: con cuatro en el equipo eran cuatro lineas larguisimas que
	# empujaban el resto de la ficha fuera de pantalla, y encima obligaban a LEER cuatro estados
	# para contestar algo que es visual (quien esta mas tocado).
	#
	# Con UNO SOLO en el grupo no hay nada que preguntar: boton directo, y el motivo por el que no
	# se puede -si no se puede- debajo. Sale de la MISMA funcion que usa el modal, asi que los dos
	# caminos no pueden acabar diciendo cosas distintas.
	var a_alguien: bool = cons.cura_hp() or cons.da_mana() or cons.es_grimorio() or cons.es_plato()
	if cons.es_cebo():
		# Un cebo NO se usa desde la bolsa: se pone en el anzuelo, y eso solo significa algo con el
		# agua delante. En vez de un boton que no haria nada, se dice donde se pone.
		_note(vb, "Los cebos se ponen en el estanque: ponte en la orilla y pulsa [F].")
	elif a_alguien and Game.party.size() > 1:
		MenuScaffold.pastilla(vb, _verbo_usar(cons), _abrir_modal_usar.bind(cons))
	else:
		var solo: PersonajeData = Game.lider()
		var motivo: String = _motivo_bloqueo(cons, solo) if a_alguien else ""
		MenuScaffold.pastilla(vb, _verbo_usar(cons), _on_usar.bind(cons), true, motivo == "")
		if motivo != "":
			_note(vb, motivo)
		else:
			var aviso: String = _aviso_uso(cons, solo)
			if aviso != "":
				_note(vb, aviso)

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
	# El HOGAR no pesa, asi que aqui no hay contador de carga; lo que si dice algo es CUANTO hay
	# guardado, que es lo que se viene a mirar antes de bajar a por mas.
	var todos_m: Array = _agrupar(Game.almacen_materiales)
	_stacks = _aplicar(todos_m)
	_contador("%d de %d montones" % [_stacks.size(), todos_m.size()])
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

# ============================================================
#  LOS FILTROS DE ARMAS Y ARMADURAS
#
#  ARMAS va de LIGERA a PESADA y con los escudos al final. El orden no es un criterio inventado:
#  sale de la velocidad real de cada tipo (velocidad_mult en su .tres -- daga 1.35, estoque 1.20,
#  espada corta 1.10, ... martillo 0.68), que es la pregunta que uno se hace mirando un arma.
#
#  BASTON y VARITA van detras de todo lo fisico aunque el baston sea de los rapidos: lo que los
#  separa del resto no es el peso, es que son de mago, y nadie los va a buscar entre las espadas
#  por su velocidad.
#
#  PUÑOS no esta, y no es un olvido: pelear a puño limpio es NO llevar arma, asi que nunca hay una
#  en el baul y esa pestaña no encontraria nada jamas.
#
#  Los ESCUDOS se parten por TAMAÑO porque es como los parte el juego (ShieldData.Tamano) y es lo
#  unico que los diferencia de verdad.
# ============================================================

# 'tipo' = WeaponData.Tipo, 'clase' = otra cosa que no es un arma de mano. -1 / "" = no filtra.
const FILTROS_ARMAS := [
	{"nombre": "Todas", "icono": "todo", "tipo": -1, "clase": ""},
	{"nombre": "Daga", "icono": "daga", "tipo": 1, "clase": ""},
	{"nombre": "Estoque", "icono": "estoque", "tipo": 5, "clase": ""},
	{"nombre": "Espada corta", "icono": "espada_corta", "tipo": 2, "clase": ""},
	{"nombre": "Maza pequeña", "icono": "maza", "tipo": 7, "clase": ""},
	{"nombre": "Espada larga", "icono": "espada_larga", "tipo": 3, "clase": ""},
	{"nombre": "Mandoble", "icono": "mandoble", "tipo": 4, "clase": ""},
	{"nombre": "Hacha grande", "icono": "hacha", "tipo": 6, "clase": ""},
	{"nombre": "Martillo grande", "icono": "martillo", "tipo": 8, "clase": ""},
	{"nombre": "Bastón", "icono": "baston", "tipo": 9, "clase": ""},
	{"nombre": "Varita", "icono": "varita", "tipo": -1, "clase": "varita"},
	{"nombre": "Escudo pequeño", "icono": "escudo_peq", "tipo": 0, "clase": "escudo"},
	{"nombre": "Escudo normal", "icono": "escudo_med", "tipo": 1, "clase": "escudo"},
	{"nombre": "Escudo grande", "icono": "escudo_gra", "tipo": 2, "clase": "escudo"},
]

# 'slot' = ArmorData.Slot, en el mismo orden que ARMOR_SLOT_LABELS. -1 = no filtra.
const FILTROS_ARMADURA := [
	{"nombre": "Todo", "icono": "todo", "slot": -1},
	{"nombre": "Casco", "icono": "casco", "slot": 0},
	{"nombre": "Pecho", "icono": "coraza", "slot": 1},
	# MANOS reusa el icono de mano que ya existia (el del boton de interactuar). El guantelete
	# dibujado a proposito salia como una cupula con una raya, o sea IGUAL que el casco, que esta
	# dos posiciones antes en la misma fila. Una mano con dedos no se confunde con nada.
	{"nombre": "Manos", "icono": "mano", "slot": 2},
	{"nombre": "Pantalones", "icono": "pantalon", "slot": 3},
	{"nombre": "Botas", "icono": "botas", "slot": 4},
]

# Uno por pestaña y NO uno solo compartido: el filtro que dejaste puesto en armas tiene que seguir
# ahi al volver de armaduras, igual que la subpestaña de Equipo.
var _filtro_armas: int = 0
var _filtro_armadura: int = 0


# Los nombres e iconos de una tabla de filtros, para pasarselos a _subpestanas.
func _campos(tabla: Array, clave: String) -> Array:
	var out: Array = []
	for f in tabla:
		out.append(f[clave])
	return out


# ¿Encaja esta pieza del baul de armas en el filtro elegido? La pestaña mezcla tres clases
# distintas (armas de mano, varitas y escudos), asi que la prueba mira primero DE QUE clase es.
func _pasa_filtro_arma(item: Resource, f: Dictionary) -> bool:
	var clase: String = String(f["clase"])
	if clase == "escudo":
		return item is ShieldData and int((item as ShieldData).tamano) == int(f["tipo"])
	if clase == "varita":
		return item is WandData
	if int(f["tipo"]) < 0:
		return true   # "Todas"
	return item is WeaponData and int((item as WeaponData).tipo) == int(f["tipo"])


func _on_filtro_armas(i: int) -> void:
	_filtro_armas = i
	_sel = 0   # el indice viejo apunta a otra lista: sin esto la ficha enseñaba una pieza al azar
	_rebuild()


func _on_filtro_armadura(i: int) -> void:
	_filtro_armadura = i
	_sel = 0
	_rebuild()


func _build_armas() -> void:
	_filtro_armas = clampi(_filtro_armas, 0, FILTROS_ARMAS.size() - 1)
	_subpestanas(_campos(FILTROS_ARMAS, "nombre"), _campos(FILTROS_ARMAS, "icono"),
		_filtro_armas, _on_filtro_armas)
	if _filtro_armas > 0:
		_titulo_seccion.text = String(FILTROS_ARMAS[_filtro_armas]["nombre"])
	var filtro: Dictionary = FILTROS_ARMAS[_filtro_armas]
	var todas: Array = []
	for w in Game.owned_weapons:
		if _pasa_filtro_arma(w, filtro):
			todas.append({"modelo": w, "cantidad": 1})
	# El embudo y el orden se aplican SOBRE lo que dejo la fila de iconos, no sobre el baul entero:
	# los dos filtros se suman, que es lo que espera cualquiera que ponga los dos.
	_stacks = _aplicar(todas)
	_contador("%d de %d" % [_stacks.size(), Game.owned_weapons.size()])
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
	_filtro_armadura = clampi(_filtro_armadura, 0, FILTROS_ARMADURA.size() - 1)
	_subpestanas(_campos(FILTROS_ARMADURA, "nombre"), _campos(FILTROS_ARMADURA, "icono"),
		_filtro_armadura, _on_filtro_armadura)
	if _filtro_armadura > 0:
		_titulo_seccion.text = String(FILTROS_ARMADURA[_filtro_armadura]["nombre"])
	var slot: int = int(FILTROS_ARMADURA[_filtro_armadura]["slot"])
	var todas_a: Array = []
	for p in Game.owned_armor:
		if slot < 0 or int((p as ArmorData).slot) == slot:
			todas_a.append({"modelo": p, "cantidad": 1})
	_stacks = _aplicar(todas_a)
	_contador("%d de %d" % [_stacks.size(), Game.owned_armor.size()])
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
	# Por el MISMO armazon que orden y filtros (MenuScaffold.modal). Antes se montaba su propia caja
	# a mano, con otro borde y otras esquinas, asi que en la misma pantalla habia dos clases de
	# modal segun el boton que pulsaras.
	var m: Dictionary = MenuScaffold.modal(_root, "¿Cuántas sueltas?", 420.0)
	_modal = m["capa"]
	var vb: VBoxContainer = m["cuerpo"]

	var l := Label.new()
	l.text = "Tienes %d." % maximo
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", MenuScaffold.GRIS)
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

	var acciones: HBoxContainer = m["acciones"]
	MenuScaffold.pastilla(acciones, "Cancelar", _cancelar_modal, false)
	# El caso mas comun -y el que mas cansa de uno en uno- es vaciar el monton entero.
	MenuScaffold.pastilla(acciones, "Todo (%d)" % maximo, func():
		_cerrar_modal()
		_confirmar_soltar(maximo), false)
	MenuScaffold.pastilla(acciones, "Soltar", _modal_aceptar)


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


# ============================================================
#  LA BARRA DE ABAJO: ORDEN Y FILTROS
#
#  El reparto es el de los menus de referencia y tiene su motivo:
#    - la FILA DE ICONOS de arriba se queda el eje ESTRUCTURAL (que pieza es: daga, casco...),
#      porque es el que se usa a todas horas y merece estar a un toque;
#    - la BARRA DE ABAJO se queda todo lo demas, que se usa de vez en cuando y no merece robarle
#      sitio a la rejilla.
#
#  El boton de orden lleva escrito EL ORDEN QUE HAY PUESTO ("Rareza ⇅"), no la palabra "Ordenar":
#  asi se sabe como esta ordenada la rejilla sin abrir nada. Volver a elegir el mismo criterio le da
#  la vuelta (asc/desc), que hace falta de verdad -- la durabilidad se mira de menor a mayor y el
#  ataque al reves.
#
#  El EMBUDO solo sale donde hay un segundo eje que filtrar. En Mochila y Herramientas no aparece:
#  ahi tienes cuatro piezas, y un filtro sobre cuatro cosas es un boton que estorba.
# ============================================================

# El estado va por PESTAÑA y no uno global: el orden que dejaste en armas tiene que seguir ahi al
# volver de armaduras, igual que pasa con la fila de iconos.
#   _orden[clave]   = {"campo": String, "desc": bool}
#   _filtros[clave] = {grupo: [valores marcados]}   (grupo vacio o ausente = ese eje no filtra)
var _orden: Dictionary = {}
var _filtros: Dictionary = {}
var _barra_pie: HBoxContainer = null
var _boton_orden: Button = null
var _boton_embudo: Button = null
var _modal_capa: Control = null   # el modal de orden/filtros abierto (null = ninguno)


# Que pestaña es a efectos de orden y filtros. Equipo cuenta como TRES: mochila, herramientas y
# farolillo no comparten ni criterios ni contenido.
func _clave_pestana() -> String:
	if _tab == 1:
		return "equipo_%d" % _sub_equipo
	return String(TABS[clampi(_tab, 0, TABS.size() - 1)]).to_lower()


# --- ORDEN -------------------------------------------------------------

# Los criterios de la pestaña actual: [{nombre, campo}]. El campo "" es "Predeterminado", que NO
# reordena nada: deja el orden en el que estan las cosas en la bolsa o en el baul, que es el orden
# en el que las conseguiste.
func _criterios_orden() -> Array:
	match _clave_pestana():
		"bolsa":
			return [{"nombre": "Predeterminado", "campo": ""},
				{"nombre": "Peso", "campo": "peso"},
				{"nombre": "Valor por peso", "campo": "valor_peso"},
				{"nombre": "Valor", "campo": "valor"},
				{"nombre": "Rango", "campo": "rango"},
				{"nombre": "Cantidad", "campo": "cantidad"},
				{"nombre": "Nombre", "campo": "nombre"}]
		"materiales":
			return [{"nombre": "Predeterminado", "campo": ""},
				{"nombre": "Rango", "campo": "rango"},
				{"nombre": "Valor", "campo": "valor"},
				{"nombre": "Cantidad", "campo": "cantidad"},
				{"nombre": "Tier", "campo": "tier"},
				{"nombre": "Nombre", "campo": "nombre"}]
		"consumibles":
			return [{"nombre": "Predeterminado", "campo": ""},
				{"nombre": "Tier", "campo": "tier"},
				{"nombre": "Cantidad", "campo": "cantidad"},
				{"nombre": "Nombre", "campo": "nombre"}]
		"armas":
			return [{"nombre": "Predeterminado", "campo": ""},
				{"nombre": "Rareza", "campo": "rareza"},
				{"nombre": "Tier", "campo": "tier"},
				{"nombre": "Mejoras", "campo": "mejoras"},
				{"nombre": "Ataque", "campo": "ataque"},
				{"nombre": "Velocidad", "campo": "velocidad"},
				{"nombre": "Durabilidad", "campo": "durabilidad"},
				{"nombre": "Nombre", "campo": "nombre"}]
		"armaduras":
			return [{"nombre": "Predeterminado", "campo": ""},
				{"nombre": "Rareza", "campo": "rareza"},
				{"nombre": "Tier", "campo": "tier"},
				{"nombre": "Mejoras", "campo": "mejoras"},
				{"nombre": "Defensa", "campo": "defensa"},
				{"nombre": "Reducción", "campo": "reduccion"},
				{"nombre": "Velocidad", "campo": "velocidad"},
				{"nombre": "Durabilidad", "campo": "durabilidad"},
				{"nombre": "Nombre", "campo": "nombre"}]
		_:
			# Mochila, herramientas y farolillo: cuatro o cinco piezas, con la rareza basta.
			return [{"nombre": "Predeterminado", "campo": ""},
				{"nombre": "Rareza", "campo": "rareza"},
				{"nombre": "Nombre", "campo": "nombre"}]


func _orden_actual() -> Dictionary:
	var k: String = _clave_pestana()
	if not _orden.has(k):
		_orden[k] = {"campo": "", "desc": true}
	return _orden[k]


# El valor por el que se ordena un monton. Devuelve float SIEMPRE (los nombres se comparan aparte,
# ver _ordenar): mezclar tipos en un sort_custom es la forma mas rapida de que Godot reviente.
func _valor_orden(s: Dictionary, campo: String) -> float:
	var m: Resource = s["modelo"]
	var n: int = int(s["cantidad"])
	match campo:
		"cantidad":
			return float(n)
		"peso":
			# EL PESO DEL MONTON ENTERO, no el de una unidad: lo que decide si sueltas algo es lo que
			# te quitas de encima, y 40 piedras de 1 pesan mas que un lingote de 8.
			if m is Cristal:
				return (m as Cristal).peso() * float(n)
			if m is MaterialItem:
				return (m as MaterialItem).peso() * float(n)
			return 0.0
		"valor":
			return float(_valor_unidad(m)) * float(n)
		"valor_peso":
			# LO QUE RENTA CADA KILO. Es la pregunta de verdad cuando vas sobrecargado: no "que vale
			# mas" ni "que pesa mas", sino "que estoy cargando para nada". Ninguno de los otros dos
			# la contesta -- lo caro puede pesar una barbaridad y lo barato ocupar sitio por nada.
			# Peso 0 (el carbon no pesa) se manda arriba del todo: renta infinito, literalmente.
			var p: float = _valor_orden(s, "peso")
			if p <= 0.001:
				return 1e9
			return float(_valor_unidad(m)) * float(n) / p
		"rango":
			return float(IconoItem.escalon(m))
		"tier":
			if m is MaterialItem:
				var d: MaterialData = (m as MaterialItem).data
				return float(d.tier) if d != null else 0.0
			if m is ConsumableData:
				return float((m as ConsumableData).tier)
			return float(Game.meta_de(m)["tier"])
		"rareza":
			return float(Game.meta_de(m)["rareza"])
		"mejoras":
			return float(Upgrades.total_mejoras(Game.meta_de(m)["mejoras"]))
		"durabilidad":
			return Game.durabilidad_item(m)
		"ataque":
			return (m as WeaponData).ataque_base * (m as WeaponData).motion_value if m is WeaponData else 0.0
		"velocidad":
			if m is WeaponData:
				return (m as WeaponData).velocidad_mult
			if m is ArmorData:
				return (m as ArmorData).velocidad_mult
			return 0.0
		"defensa":
			return (m as ArmorData).defensa_base * (m as ArmorData).motion_def if m is ArmorData else 0.0
		"reduccion":
			return (m as ArmorData).reduccion if m is ArmorData else 0.0
	return 0.0


func _valor_unidad(m: Resource) -> int:
	if m is Cristal:
		return (m as Cristal).valor_estimado()
	if m is MaterialItem:
		return (m as MaterialItem).valor_estimado()
	return 0


# El nombre por el que ordena "Nombre". Sale del mismo sitio que el tooltip de la celda, asi que
# ordenar por nombre deja la rejilla en el orden en el que se leen los tooltips.
func _nombre_orden(s: Dictionary) -> String:
	var m: Resource = s["modelo"]
	if m is MaterialItem or m is Cristal:
		return _nombre_item(m).replace("\n", " ")
	if m is ConsumableData:
		return (m as ConsumableData).nombre
	return Game.item_display_name(m)


func _ordenar(stacks: Array) -> Array:
	var o: Dictionary = _orden_actual()
	var campo: String = String(o["campo"])
	if campo == "":
		return stacks   # Predeterminado: el orden en el que lo conseguiste. No se toca.
	var desc: bool = bool(o["desc"])
	var out: Array = stacks.duplicate()
	if campo == "nombre":
		out.sort_custom(func(a, b):
			var na: String = _nombre_orden(a)
			var nb: String = _nombre_orden(b)
			return (na > nb) if desc else (na < nb))
		return out
	out.sort_custom(func(a, b):
		var va: float = _valor_orden(a, campo)
		var vb: float = _valor_orden(b, campo)
		return (va > vb) if desc else (va < vb))
	return out


func _pulsa_criterio(i: int) -> void:
	var crit: Array = _criterios_orden()
	if i < 0 or i >= crit.size():
		return
	var o: Dictionary = _orden_actual()
	var campo: String = String(crit[i]["campo"])
	# EL MISMO criterio otra vez = darle la vuelta. Uno nuevo empieza siempre de mayor a menor, que
	# es lo que se quiere el 90% de las veces (la rareza mas alta, el valor mas alto); para la
	# durabilidad, que se mira al reves, esta el segundo toque.
	if String(o["campo"]) == campo and campo != "":
		o["desc"] = not bool(o["desc"])
	else:
		o["campo"] = campo
		o["desc"] = true
	_cerrar_modal_barra()
	_rebuild()


# --- FILTROS -----------------------------------------------------------

# Los grupos de filtro de la pestaña actual: [{titulo, clave, opciones: [{nombre, valor}]}].
# Vacio = esta pestaña no lleva embudo.
func _grupos_filtro() -> Array:
	match _clave_pestana():
		"bolsa":
			return [
				{"titulo": "Clase", "clave": "clase", "opciones": [
					{"nombre": "Cristales", "valor": 0}, {"nombre": "Materiales", "valor": 1}]},
				{"titulo": "Rango", "clave": "rango", "opciones": _ops_rango()},
				{"titulo": "Calidad", "clave": "calidad", "opciones": _ops_calidad()},
			]
		"materiales":
			return [
				{"titulo": "Tipo", "clave": "tipo_material", "opciones": _ops_tipo_material()},
				{"titulo": "Rango", "clave": "rango", "opciones": _ops_rango()},
				{"titulo": "Calidad", "clave": "calidad", "opciones": _ops_calidad()},
			]
		"consumibles":
			return [{"titulo": "Clase", "clave": "clase_consumible", "opciones": [
				{"nombre": "Poción de vida", "valor": 0}, {"nombre": "Poción de maná", "valor": 1},
				{"nombre": "Grimorio", "valor": 2}, {"nombre": "Plato de cocina", "valor": 3},
				{"nombre": "Cebo de pesca", "valor": 4}, {"nombre": "Otros", "valor": 5}]}]
		"armas":
			return [
				{"titulo": "Rareza", "clave": "rareza", "opciones": _ops_rareza()},
				{"titulo": "Tier", "clave": "tier", "opciones": _ops_tier()},
				{"titulo": "Estado", "clave": "estado", "opciones": _ops_estado()},
			]
		"armaduras":
			return [
				{"titulo": "Material", "clave": "material", "opciones": _ops_material_armadura()},
				{"titulo": "Rareza", "clave": "rareza", "opciones": _ops_rareza()},
				{"titulo": "Tier", "clave": "tier", "opciones": _ops_tier()},
				{"titulo": "Estado", "clave": "estado", "opciones": _ops_estado()},
			]
	return []


func _ops_rareza() -> Array:
	var out: Array = []
	for r in Upgrades.RAREZA_NOMBRE.size():
		out.append({"nombre": Upgrades.RAREZA_NOMBRE[r], "valor": r})
	return out


func _ops_tier() -> Array:
	return [{"nombre": "T1", "valor": 1}, {"nombre": "T2", "valor": 2}, {"nombre": "T3", "valor": 3}]


func _ops_estado() -> Array:
	return [{"nombre": "La lleva alguien", "valor": 0}, {"nombre": "En el baúl", "valor": 1},
		{"nombre": "Rota o casi", "valor": 2}]


func _ops_material_armadura() -> Array:
	var out: Array = []
	for i in ARMOR_TIPO_LABELS.size():
		out.append({"nombre": ARMOR_TIPO_LABELS[i], "valor": i})
	return out


func _ops_rango() -> Array:
	var out: Array = []
	for r in 5:
		out.append({"nombre": Upgrades.RAREZA_NOMBRE[r], "valor": r})
	return out


func _ops_calidad() -> Array:
	return [{"nombre": "Puro", "valor": int(MaterialItem.Calidad.PURO)},
		{"nombre": "Intacto", "valor": int(MaterialItem.Calidad.INTACTO)},
		{"nombre": "Normal", "valor": int(MaterialItem.Calidad.NORMAL)},
		{"nombre": "Dañado", "valor": int(MaterialItem.Calidad.DANADO)}]


const TIPO_MATERIAL_NOMBRE := ["Babas", "Plantas", "Minerales", "Cueros", "Núcleos", "Lingotes",
	"Maderas", "Tablones", "Carnes", "Pescados", "Despensa", "Combustible"]

func _ops_tipo_material() -> Array:
	var out: Array = []
	for i in TIPO_MATERIAL_NOMBRE.size():
		out.append({"nombre": TIPO_MATERIAL_NOMBRE[i], "valor": i})
	return out


# El valor de este monton en el eje 'clave'. -9999 = "no aplica", y entonces el filtro de ese eje
# no lo deja pasar nunca (un cristal no tiene tipo de material, asi que filtrar por tipo lo saca).
func _valor_filtro(s: Dictionary, clave: String) -> int:
	var m: Resource = s["modelo"]
	match clave:
		"clase":
			return 0 if m is Cristal else (1 if m is MaterialItem else -9999)
		"rango":
			return IconoItem.escalon(m) if (m is MaterialItem) else -9999
		"calidad":
			return int((m as MaterialItem).calidad) if m is MaterialItem else -9999
		"tipo_material":
			var d: MaterialData = (m as MaterialItem).data if m is MaterialItem else null
			return int(d.tipo) if d != null else -9999
		"rareza":
			return int(Game.meta_de(m)["rareza"])
		"tier":
			return int(Game.meta_de(m)["tier"])
		"material":
			return int((m as ArmorData).tipo) if m is ArmorData else -9999
		"estado":
			# ROTA O CASI manda sobre las otras dos: si te queda un 15% de durabilidad, lo que
			# quieres saber es eso y no si la lleva puesta alguien.
			if Game.durabilidad_item(m) <= UMBRAL_ROTA:
				return 2
			return 0 if Game.quien_lleva(m) != null else 1
		"clase_consumible":
			var c := m as ConsumableData
			if c == null:
				return -9999
			if c.es_grimorio():
				return 2
			if c.es_plato():
				return 3
			if c.es_cebo():
				return 4
			if c.da_mana() and not c.cura_hp():
				return 1
			if c.cura_hp():
				return 0
			return 5
	return -9999

# Por debajo de esto una pieza se considera "rota o casi". Es el mismo escalon en el que
# Game.durabilidad_color ya la pinta en rojo, para que el filtro y el color digan lo mismo.
const UMBRAL_ROTA := 0.25


func _filtros_actuales() -> Dictionary:
	var k: String = _clave_pestana()
	if not _filtros.has(k):
		_filtros[k] = {}
	return _filtros[k]


func _hay_filtro() -> bool:
	for g in _filtros_actuales().values():
		if not (g as Array).is_empty():
			return true
	return false


func _filtrar(stacks: Array) -> Array:
	var f: Dictionary = _filtros_actuales()
	if not _hay_filtro():
		return stacks
	var out: Array = []
	for s in stacks:
		var pasa: bool = true
		for clave in f.keys():
			var marcados: Array = f[clave]
			if marcados.is_empty():
				continue   # ese eje no filtra
			# DENTRO de un grupo es "o" (cuero O placas) y ENTRE grupos es "y" (cuero Y del tier 2).
			# Es lo que espera cualquiera que haya usado un filtro, y lo contrario no serviria: marcar
			# dos rarezas para no ver ninguna no tendria sentido.
			if not marcados.has(_valor_filtro(s, String(clave))):
				pasa = false
				break
		if pasa:
			out.append(s)
	return out


func _alterna_filtro(clave: String, valor: int) -> void:
	var f: Dictionary = _filtros_actuales()
	var lista: Array = f.get(clave, [])
	if lista.has(valor):
		lista.erase(valor)
	else:
		lista.append(valor)
	f[clave] = lista
	_sel = 0   # la lista cambia de largo: el indice viejo apunta a otra cosa
	_refrescar_modal_filtros()
	_rebuild()


func _limpiar_filtros() -> void:
	_filtros[_clave_pestana()] = {}
	_sel = 0
	_refrescar_modal_filtros()
	_rebuild()


# --- APLICAR -----------------------------------------------------------

# Lo que llama cada pestaña justo despues de montar sus stacks. Filtra primero y ordena despues:
# al reves se ordenaria una lista de la que luego se tira la mitad, que es trabajo tirado.
#
# Se guarda ademas la lista SIN FILTRAR, porque es contra la que se cuentan las opciones del embudo
# ("Placas 4"): contra la filtrada, marcar un filtro pondria a cero todos los demas y no habria
# forma de cambiar de idea.
var _stacks_sin_filtrar: Array = []

func _aplicar(stacks: Array) -> Array:
	_stacks_sin_filtrar = stacks
	return _ordenar(_filtrar(stacks))


# --- LA BARRA ----------------------------------------------------------

func _pintar_barra_pie() -> void:
	MenuScaffold.vaciar(_barra_pie)
	_boton_embudo = null
	var grupos: Array = _grupos_filtro()
	if not grupos.is_empty():
		# El embudo se pinta AMBAR cuando hay algo filtrado. Sin eso, una rejilla a medias parece una
		# rejilla vacia y no hay forma de saber que sobra un filtro puesto de hace dos pantallas.
		_boton_embudo = MenuScaffold.pastilla(_barra_pie, "Filtros", _abrir_modal_filtros, false)
		if _hay_filtro():
			MenuScaffold.estilo_chip(_boton_embudo, true)
			_boton_embudo.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_PASTILLA)

	var o: Dictionary = _orden_actual()
	var nombre: String = "Predeterminado"
	for c in _criterios_orden():
		if String(c["campo"]) == String(o["campo"]):
			nombre = String(c["nombre"])
	# La flecha dice el SENTIDO, y solo cuando hay criterio: en "Predeterminado" no hay nada que
	# invertir, asi que una flecha ahi seria mentira.
	var flecha: String = "" if String(o["campo"]) == "" else ("  ↓" if bool(o["desc"]) else "  ↑")
	_boton_orden = MenuScaffold.pastilla(_barra_pie, nombre + flecha, _abrir_modal_orden, false)

	var hueco := Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_barra_pie.add_child(hueco)


func _abrir_modal_orden() -> void:
	_cerrar_modal_barra()
	var m: Dictionary = MenuScaffold.modal(_root, "Orden")
	_modal_capa = m["capa"]
	var crit: Array = _criterios_orden()
	var o: Dictionary = _orden_actual()
	var marcadas: Array = []
	for i in crit.size():
		if String(crit[i]["campo"]) == String(o["campo"]):
			marcadas.append(i)
	MenuScaffold.chips(m["cuerpo"], "", crit, marcadas, _pulsa_criterio, 3)
	var pista := Label.new()
	pista.text = "Vuelve a pulsar el mismo criterio para invertirlo."
	pista.add_theme_font_size_override("font_size", 11)
	pista.add_theme_color_override("font_color", MenuScaffold.GRIS)
	(m["cuerpo"] as VBoxContainer).add_child(pista)
	MenuScaffold.pastilla(m["acciones"], "Cerrar", _cerrar_modal_barra, false)


func _abrir_modal_filtros() -> void:
	_cerrar_modal_barra()
	var m: Dictionary = MenuScaffold.modal(_root, "Filtros")
	_modal_capa = m["capa"]
	_modal_cuerpo = m["cuerpo"]
	_refrescar_modal_filtros()
	MenuScaffold.pastilla(m["acciones"], "Quitar todo", _limpiar_filtros, false)
	MenuScaffold.pastilla(m["acciones"], "Listo", _cerrar_modal_barra)


var _modal_cuerpo: VBoxContainer = null

# Repinta las opciones del modal de filtros con los RECUENTOS al dia. Se llama al abrirlo y cada vez
# que se marca algo: los recuentos no cambian (van contra la lista sin filtrar) pero si cambia que
# chips estan encendidos, y el modal se queda abierto mientras marcas.
func _refrescar_modal_filtros() -> void:
	if _modal_cuerpo == null or not is_instance_valid(_modal_cuerpo):
		return
	MenuScaffold.vaciar(_modal_cuerpo)
	var f: Dictionary = _filtros_actuales()
	for g in _grupos_filtro():
		var clave: String = String(g["clave"])
		var marcados: Array = f.get(clave, [])
		var opciones: Array = []
		var marcadas: Array = []
		var i: int = 0
		for op in g["opciones"]:
			var valor: int = int(op["valor"])
			opciones.append({"nombre": String(op["nombre"]),
				"cuantos": _cuantos_con(clave, valor)})
			if marcados.has(valor):
				marcadas.append(i)
			i += 1
		var vals: Array = g["opciones"]
		MenuScaffold.chips(_modal_cuerpo, String(g["titulo"]), opciones, marcadas,
			func(idx: int): _alterna_filtro(clave, int(vals[idx]["valor"])), 4)


# Cuantos montones de la pestaña tienen este valor en este eje. Va contra la lista SIN filtrar a
# proposito (ver _aplicar).
func _cuantos_con(clave: String, valor: int) -> int:
	var n: int = 0
	for s in _stacks_sin_filtrar:
		if _valor_filtro(s, clave) == valor:
			n += 1
	return n


func _cerrar_modal_barra() -> void:
	if _modal_capa != null and is_instance_valid(_modal_capa):
		_modal_capa.queue_free()
	_modal_capa = null
	_modal_cuerpo = null


# ============================================================
#  EL MODAL DE "¿A QUIEN SE LO DAS?"
#
#  Antes esto era una pila de botones dentro de la ficha, uno por compañero, con el estado metido
#  en el propio texto del boton ("Fulano  (45/90 ♥  12/40 🔷)"). Con cuatro en el grupo eran cuatro
#  botones larguisimos que empujaban al resto de la ficha fuera de pantalla, y ademas obligaban a
#  LEER cuatro lineas para contestar una pregunta que es visual: quien esta mas tocado.
#
#  Ahora son tarjetas con el muñeco de cada uno y su barra de vida. La barra se compara de un
#  vistazo; el numero sigue estando, pero ya no hace falta leerlo para decidir.
#
#  Y lo importante, que es lo que hace la referencia y aqui no habia: cuando NO se puede usar, se
#  dice POR QUE en una franja roja sobre los botones y el de confirmar se apaga. Antes el boton
#  salia en gris sin mas y no habia forma de saber si era porque estaba a tope de vida, porque ya
#  se sabia el hechizo o porque no le cabian mas.
# ============================================================

var _usar_cons: ConsumableData = null   # el consumible del modal abierto
var _usar_sel: int = 0                  # a quien apunta (indice en Game.party)


# POR QUE no se le puede dar esto a esta persona. "" = si se puede.
#
# Es una sola funcion y no una rama por cada sitio a proposito: el motivo lo pintan el modal Y el
# boton directo del grupo de uno, y si cada uno lo dedujera por su cuenta acabarian discrepando.
func _motivo_bloqueo(c: ConsumableData, pj: PersonajeData) -> String:
	if c.es_grimorio():
		if pj.equipped_spells.has(c.spell):
			return "%s ya se sabe este hechizo." % pj.nombre
		if pj.equipped_spells.size() >= Game.MAX_HECHIZOS:
			return "%s no puede aprender mas de %d hechizos." % [pj.nombre, Game.MAX_HECHIZOS]
		return ""
	if c.es_plato():
		return ""   # un plato nuevo pisa al que llevara puesto: se avisa, pero no se prohibe
	# POCIONES. Se bloquea solo si NO PUEDE HACER NADA: una que cura vida y da maná sigue valiendo
	# con la vida llena si le falta maná, asi que se miran las dos y basta con que una sirva.
	var sirve: bool = false
	if c.cura_hp() and Game.player_hp(pj) < Game.player_max_hp(pj):
		sirve = true
	if c.da_mana() and Game.player_mp(pj) < Game.player_max_mp(pj):
		sirve = true
	if sirve or not (c.cura_hp() or c.da_mana()):
		return ""
	if c.cura_hp() and c.da_mana():
		return "%s está a tope de vida y de maná." % pj.nombre
	return "%s está a tope de %s." % [pj.nombre, "vida" if c.cura_hp() else "maná"]


# Lo que conviene saber aunque NO bloquee (el plato que va a pisar al que lleva puesto).
func _aviso_uso(c: ConsumableData, pj: PersonajeData) -> String:
	if not c.es_plato():
		return ""
	var puesto: String = Game.plato_puesto(pj)
	return "" if puesto == "" else "%s lleva %s: se le quitará." % [pj.nombre, puesto]


func _verbo_usar(c: ConsumableData) -> String:
	return "Estudiar" if c.es_grimorio() else ("Comer" if c.es_plato() else "Usar")


func _abrir_modal_usar(c: ConsumableData) -> void:
	_cerrar_modal_barra()
	_usar_cons = c
	# Arranca apuntando a quien MAS LO NECESITA, no al lider: con cuatro en el grupo, la respuesta
	# correcta casi siempre es "el que esta peor", y dejarla ya elegida ahorra el paso mas comun.
	_usar_sel = _mejor_objetivo(c)
	_pintar_modal_usar()


# A quien apunta el modal al abrirse. Para una poción, el que tenga la fraccion de vida (o de maná)
# mas baja de los que PUEDEN recibirla; para un grimorio o un plato, el primero que pueda.
func _mejor_objetivo(c: ConsumableData) -> int:
	var mejor: int = 0
	var peor_frac: float = 2.0
	for i in Game.party.size():
		var pj: PersonajeData = Game.party[i]
		if _motivo_bloqueo(c, pj) != "":
			continue
		var frac: float = 1.0
		if c.cura_hp():
			frac = Game.player_hp(pj) / maxf(Game.player_max_hp(pj), 1.0)
		elif c.da_mana():
			frac = Game.player_mp(pj) / maxf(Game.player_max_mp(pj), 1.0)
		if frac < peor_frac:
			peor_frac = frac
			mejor = i
	return mejor


# Se repinta ENTERO en cada toque (elegir a otro) en vez de retocar la tarjeta que cambia: son
# cuatro tarjetas y se reconstruyen en nada, y asi no hay dos caminos que mantener sincronizados
# -- el mismo error que ya se pago en la rejilla del herrero.
func _pintar_modal_usar() -> void:
	_cerrar_modal_barra()
	var c: ConsumableData = _usar_cons
	if c == null:
		return
	var quedan: int = int(Game.consumables.get(c, 0))
	var m: Dictionary = MenuScaffold.modal(_root, c.nombre, 640.0)
	_modal_capa = m["capa"]
	var vb: VBoxContainer = m["cuerpo"]

	var restantes := Label.new()
	restantes.text = "Restantes:  %d" % quedan
	restantes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restantes.add_theme_font_size_override("font_size", 12)
	restantes.add_theme_color_override("font_color", AMBAR)
	vb.add_child(restantes)

	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 10)
	vb.add_child(fila)
	for i in Game.party.size():
		_tarjeta_persona(fila, c, i)

	# QUE HACE, una vez y en el centro, en vez de repetido en cada boton como antes.
	var efecto := Label.new()
	efecto.text = _texto_efecto(c)
	efecto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	efecto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	efecto.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	vb.add_child(efecto)

	var pj: PersonajeData = Game.party[clampi(_usar_sel, 0, Game.party.size() - 1)]
	var motivo: String = _motivo_bloqueo(c, pj)
	var aviso: String = _aviso_uso(c, pj)
	if motivo != "" or aviso != "":
		_franja(vb, motivo if motivo != "" else aviso, motivo != "")

	MenuScaffold.pastilla(m["acciones"], "Cancelar", _cerrar_modal_barra, false)
	MenuScaffold.pastilla(m["acciones"], _verbo_usar(c), func():
		_cerrar_modal_barra()
		_on_usar(c, pj), true, motivo == "" and quedan > 0)


# LA FRANJA DE MOTIVO, sobre los botones. Roja si impide usarlo, ambar si solo avisa. Va pegada al
# pie del modal a proposito: es lo ultimo que se lee antes de pulsar Confirmar.
func _franja(vb: VBoxContainer, texto: String, bloquea: bool) -> void:
	var caja := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.20, 0.22, 0.92) if bloquea else Color(0.45, 0.34, 0.12, 0.92)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	caja.add_theme_stylebox_override("panel", sb)
	vb.add_child(caja)
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Color(1, 0.96, 0.94))
	caja.add_child(l)


func _texto_efecto(c: ConsumableData) -> String:
	if c.es_grimorio():
		return "Enseña %s  ·  %d de maná por lanzamiento." % [c.spell.nombre, c.spell.coste_mana]
	if c.es_plato():
		return c.resumen_plato()
	return c.resumen(Game.player_max_hp(), Game.player_max_mp())


const ANCHO_TARJETA := 116.0
const ALTO_TARJETA := 182.0

# UNA TARJETA: el muñeco del personaje, su nombre y sus barras. Es un Button para no reescribir el
# foco ni el hover, con el estilo quitado y el dibujo a mano, igual que CeldaObjeto.
func _tarjeta_persona(fila: HBoxContainer, c: ConsumableData, i: int) -> void:
	var pj: PersonajeData = Game.party[i]
	var motivo: String = _motivo_bloqueo(c, pj)
	var elegida: bool = (i == _usar_sel)

	var b := Button.new()
	b.custom_minimum_size = Vector2(ANCHO_TARJETA, ALTO_TARJETA)
	b.clip_contents = true
	for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
	# Una persona a la que NO se le puede dar se deja PULSABLE igual: al elegirla sale la franja
	# roja diciendo por que. Apagarla dejaria la pregunta sin respuesta, que es justo lo que pasaba
	# con el boton en gris de antes.
	b.pressed.connect(func():
		_usar_sel = i
		_pintar_modal_usar())
	fila.add_child(b)

	b.draw.connect(func() -> void:
		var w: float = b.size.x
		var h: float = b.size.y
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.13, 0.14, 0.19, 1.0) if elegida else Color(0.08, 0.09, 0.12, 1.0)
		sb.border_color = AMBAR if elegida else Color(1, 1, 1, 0.12)
		sb.set_border_width_all(2 if elegida else 1)
		sb.set_corner_radius_all(8)
		b.draw_style_box(sb, Rect2(Vector2.ZERO, Vector2(w, h)))
		var f: Font = b.get_theme_font(&"font")
		# El nombre arriba, con la corona si es quien va en cabeza.
		var nombre: String = ("* " if pj == Game.lider() else "") + pj.nombre
		var an: float = f.get_string_size(nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		b.draw_string(f, Vector2((w - an) * 0.5, 18.0), nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			AMBAR if elegida else Color(0.86, 0.89, 0.94))
		# Las barras del pie.
		var dos: bool = c.da_mana() or c.es_grimorio()
		var y: float = h - (46.0 if dos else 26.0)
		_barra(b, Rect2(10.0, y, w - 20.0, 8.0), Game.player_hp(pj), Game.player_max_hp(pj),
			Color(0.85, 0.30, 0.32), f)
		if dos:
			_barra(b, Rect2(10.0, y + 22.0, w - 20.0, 8.0), Game.player_mp(pj),
				Game.player_max_mp(pj), Color(0.32, 0.55, 0.92), f)
		# Y el velo de "a este no": encima de todo, para que se vea que la tarjeta esta apagada sin
		# dejar de poder pulsarla.
		if motivo != "":
			b.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0.05, 0.05, 0.07, 0.55)))

	# EL MUÑECO, hijo del boton (asi se recorta con el y se mueve con el). Va DESPUES de conectar el
	# draw: los hijos de un CanvasItem se dibujan despues del padre, o sea por encima del fondo de
	# la tarjeta y por debajo de nada -- por eso el nombre y las barras se pintan en el draw del
	# padre y quedarian TAPADOS. Se colocan fuera de la silueta a proposito (arriba del todo y en el
	# pie), donde el muñeco no llega.
	var m := MunecoJugador.new()
	m.montar(pj)
	m.tenir(pj.color, 0.0)
	m.poner_cara(pj.textura())
	if m.hay_dibujo():
		# Escala para que quepa entre el nombre y las barras. Los pies del muñeco son su propio
		# origen, asi que se apoya donde empiezan las barras.
		var alto_util: float = ALTO_TARJETA - 84.0
		m.scale = Vector2.ONE * (alto_util / PoseJugador.ALTO_MUNDO)
		m.position = Vector2(ANCHO_TARJETA * 0.5, ALTO_TARJETA - 54.0)
		m.animar("idle_4")
		b.add_child(m)
	else:
		m.queue_free()


# Una barra de N/M con su numero encima. Devuelve nada: se dibuja en el CanvasItem que se le pasa.
func _barra(ci: CanvasItem, r: Rect2, valor: float, tope: float, col: Color, f: Font) -> void:
	ci.draw_rect(r, Color(0.04, 0.05, 0.07, 0.95))
	var frac: float = clampf(valor / maxf(tope, 1.0), 0.0, 1.0)
	if frac > 0.0:
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), col)
	# El numero ENCIMA de la barra, con sombra. A cuerpo 9 y sin sombra no se leia: media cifra caia
	# sobre el relleno rojo y la otra media sobre el hueco oscuro, y el ojo no separaba ninguna de
	# las dos. La sombra lo despega de los dos fondos a la vez, que es lo que hacia falta.
	var tam: int = 10
	var txt: String = "%d/%d" % [roundi(valor), roundi(tope)]
	var an: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var p := Vector2(r.position.x + (r.size.x - an) * 0.5, r.position.y + r.size.y + float(tam) + 1.0)
	ci.draw_string(f, p + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam,
		Color(0, 0, 0, 0.85))
	ci.draw_string(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(0.95, 0.96, 0.98))
