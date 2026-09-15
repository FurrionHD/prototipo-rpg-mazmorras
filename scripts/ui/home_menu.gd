# ============================================================
#  home_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  Menu del HOGAR. Dos cosas, que son las dos que se hacen en casa:
#    1) EQUIPO   - quien de tu plantilla baja hoy a la mazmorra (como mucho Game.PARTY_MAX) y en
#                  que orden. La plantilla no tiene tope: aqui se montan equipos distintos sin
#                  perder a nadie (nadie se despide nunca).
#    2) ALMACEN  - guardar en casa los materiales que traigas en la bolsa (lo que antes hacia la
#                  tecla F a secas). Se consulta en la pestaña "Materiales" del inventario (I).
#
#  El ORDEN del equipo importa: el de arriba es el que va EN CABEZA (el cuerpo que mueves por el
#  mapa, el que mina y el que gasta aguante). Se puede cambiar tambien sobre la marcha con las
#  teclas 1/2/3, pero aqui es donde se decide con quien sales de casa.
# ============================================================

extends CanvasLayer

# Almacen del hogar. Bote y Cofre son tu almacen personal (persiste en la partida); en multi
# pasan a ser los del host (compartidos). Siempre visibles.
const TABS := ["Equipo", "Encargos", "Almacén", "Cofre"]


const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const GRIS := Color(0.6, 0.63, 0.7)

var _root: Control = null
var _header: VBoxContainer = null
var _content: VBoxContainer = null
var _lista: VBoxContainer = null
# La COLUMNA de la lista, para poder esconderla en las pestañas que no la usan: si se queda ahi
# vacia, se lleva 330 px de ancho y el contenido de al lado se apretuja contra el borde.
var _lista_scroll: ScrollContainer = null
var _aviso_lbl: Label = null
var _tab_buttons: Array = []
var _side: VBoxContainer = null
var _aviso: String = ""
var _aviso_ok: bool = true
var _tab: int = 0

# Las SECCIONES, cada una en su archivo (scripts/ui/hogar/). Pintan en las zonas de aqui arriba.
const HogarEquipo = preload("res://scripts/ui/hogar/hogar_equipo.gd")
const HogarEncargos = preload("res://scripts/ui/hogar/hogar_encargos.gd")
const HogarAlmacen = preload("res://scripts/ui/hogar/hogar_almacen.gd")
var equipo = null
var encargos = null
var almacen = null



func _ready() -> void:
	equipo = HogarEquipo.new(self)
	encargos = HogarEncargos.new(self)
	almacen = HogarAlmacen.new(self)
	layer = 91
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para: hay que seguir respondiendo
	add_to_group("home_menu")

	var m: Dictionary = MenuScaffold.construir(self, "HOGAR",
		"Tu casa: aquí se decide con quién bajas y aquí se guarda lo que traes.",
		_cerrar)
	_root = m["root"]
	_header = m["header"]
	_content = m["content"]
	_lista = m["lista"]
	_lista_scroll = m["lista_scroll"]
	_aviso_lbl = m["aviso"]
	_side = m["side"]
	# Las pestañas se rehacen en cada _rebuild: en sesion multi aparecen Bote y Cofre.
	if Net.has_signal("hogar_cambiado"):
		Net.hogar_cambiado.connect(_on_hogar_cambiado)


# El OTRO jugador cambio el estado compartido: si tengo el hogar abierto, me re-dibujo.
func _on_hogar_cambiado() -> void:
	if _root != null and _root.visible:
		_rebuild()


func _tabs() -> Array:
	return TABS


func _rehacer_tabs() -> void:
	for b in _tab_buttons:
		(b as Button).queue_free()
	_tab_buttons.clear()
	var etiquetas: Array = _tabs()
	_tab = clampi(_tab, 0, etiquetas.size() - 1)
	for i in etiquetas.size():
		var b := Button.new()
		b.text = etiquetas[i]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)
		b.pressed.connect(_on_tab.bind(i))
		_side.add_child(b)
		_tab_buttons.append(b)


func abrir() -> void:
	if Game._active_layer != null or Game.debug_panel_open:
		return
	_tab = 0
	_aviso = ""
	_root.visible = true
	Game.abrir_menu(self)
	_rebuild()


func _cerrar() -> void:
	# Si has mandado a TODOS a casa, alguien tiene que llevar el cuerpo: baja tu original.
	# Va aqui porque _cerrar es el embudo de los TRES caminos de cierre -- la tecla Esc (_input de
	# abajo), el boton del scaffold, y el cierre a la fuerza cuando te embiste un bicho
	# (Game.cerrar_menus_abiertos). Game.lider() ya rellena con el original el solo; esto solo lo
	# adelanta para que sea determinista y para poder avisar.
	if Game.party.is_empty():
		var solo: PersonajeData = Game.lider()
		var p: Node = get_tree().get_first_node_in_group("player")
		if p != null and p.has_method("refrescar_lider"):
			p.refrescar_lider()
		var hud: Node = get_tree().get_first_node_in_group("hud")
		if hud != null and hud.has_method("mostrar_toast"):
			hud.mostrar_toast("No dejaste a nadie en el equipo: %s baja contigo." % solo.nombre)
	_root.visible = false
	Game.cerrar_menu(self)


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_cerrar()
			get_viewport().set_input_as_handled()


func _on_tab(i: int) -> void:
	_tab = i
	_aviso = ""
	_rebuild()


# Guardia de REENTRADA. Un _rebuild puede entrar mientras otro esta a medias (el focus_exited de un
# stepper al liberarlo, las señales de red, un _on_* que espera en un await), y entonces el de dentro
# pinta su panel y el de fuera apila el suyo debajo: el menu salia DUPLICADO. Es el mismo guardia que
# lleva el herrero desde que se cazo alli.
var _reconstruyendo := false
# Y lo que llego MIENTRAS. Salir en seco perdia la señal: un hogar_cambiado que entra a mitad de un
# rebuild (los RPC llegan con el arbol pausado y este menu es PROCESS_MODE_ALWAYS) dejaba la pestaña
# mintiendo hasta que el jugador la tocara -- justo lo que no puede pasar con el roster en vivo.
var _rebuild_pendiente := false

func _rebuild() -> void:
	if _reconstruyendo:
		_rebuild_pendiente = true
		return
	_reconstruyendo = true
	_rebuild_real()
	_reconstruyendo = false
	if _rebuild_pendiente:
		_rebuild_pendiente = false
		_rebuild()


func _rebuild_real() -> void:
	_rehacer_tabs()
	for zona in [_header, _content, _lista]:
		MenuScaffold.vaciar(zona)
	for i in _tab_buttons.size():
		(_tab_buttons[i] as Button).button_pressed = (i == _tab)
	MenuScaffold.decir(_aviso_lbl, _aviso, _aviso_ok)

	# La columna de la lista solo la usan el Cofre (sus dos columnas: lo tuyo / lo que hay dentro) y
	# los Encargos. En las demas se esconde: vacia se quedaba con 330 px y el contenido de al lado se
	# apretujaba en lo que sobraba (los tres botones del baul no cabian en una fila por esto).
	var con_lista: bool = _tabs()[_tab] in ["Cofre", "Encargos", "Equipo"]
	if _lista_scroll != null:
		_lista_scroll.visible = con_lista

	match _tabs()[_tab]:
		"Equipo": equipo._build_equipo()
		"Encargos": encargos._build_encargos()
		"Almacén": almacen._build_almacen()
		# La HUCHA ya no tiene pestaña propia: es un apartado dentro del cofre (ver COFRE_SUBS).
		"Cofre": almacen._build_cofre()



# ============================================================
#  PIEZAS COMPARTIDAS por Equipo y Encargos
# ============================================================
# TARJETA de una persona: los datos en una linea y los botones en OTRA, dentro de un panelito.
#
# Antes era todo una fila sola y no cabia: con tres botones detras del nombre, el ultimo se salia de
# la pantalla y no habia forma de pulsarlo. Poniendo los botones debajo cabe cualquier combinacion
# sin depender de lo largo que sea un nombre ni de cuantos botones lleve esa fila.
func _tarjeta(padre: VBoxContainer) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _fondo_tarjeta())
	padre.add_child(panel)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 3)
	panel.add_child(caja)
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	caja.add_child(info)
	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 4)
	caja.add_child(botones)
	# `caja` es el VBox entero: quien quiera colgar mas filas debajo de los botones (las ordenes de un
	# encargo, por ejemplo) las mete ahi.
	return {"info": info, "botones": botones, "caja": caja}


func _fondo_tarjeta() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.14, 0.85)
	sb.border_color = Color(0.30, 0.33, 0.40, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb


# El cuerpo del personaje, del tamaño de un icono: mismo color y mismo material que por el mapa.
func _punto(pj: PersonajeData) -> ColorRect:
	var punto := ColorRect.new()
	punto.custom_minimum_size = Vector2(18, 18)
	punto.color = pj.color
	punto.material = Game.material_de(pj)
	return punto


# El mismo punto pero SOLO con el color, para las filas que salen del roster: de un personaje de tu
# compañero no tienes el PersonajeData (ni su imagen), solo lo que el host publica.
func _punto_color(c: Variant) -> ColorRect:
	var punto := ColorRect.new()
	punto.custom_minimum_size = Vector2(18, 18)
	punto.color = c if c is Color else Color.WHITE
	return punto
