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

const TABS := ["Equipo", "Almacén"]

const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const GRIS := Color(0.6, 0.63, 0.7)

var _root: Control = null
var _header: VBoxContainer = null
var _content: VBoxContainer = null
var _lista: VBoxContainer = null
var _aviso_lbl: Label = null
var _tab_buttons: Array = []
var _aviso: String = ""
var _aviso_ok: bool = true
var _tab: int = 0


func _ready() -> void:
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
	_aviso = ""
	_root.visible = true
	Game.abrir_menu()
	_rebuild()


func _cerrar() -> void:
	_root.visible = false
	Game.cerrar_menu()


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


func _rebuild() -> void:
	for zona in [_header, _content, _lista]:
		for c in zona.get_children():
			c.queue_free()
	for i in _tab_buttons.size():
		(_tab_buttons[i] as Button).button_pressed = (i == _tab)
	MenuScaffold.decir(_aviso_lbl, _aviso, _aviso_ok)

	match _tab:
		0: _build_equipo()
		1: _build_almacen()


# ============================================================
#  EQUIPO: los que bajan (izquierda) y el banquillo (derecha)
# ============================================================

func _build_equipo() -> void:
	MenuScaffold.titulo(_header, "QUIÉN BAJA CONTIGO", 18)

	MenuScaffold.titulo(_lista, "El equipo (%d de %d)" % [Game.party.size(), Game.PARTY_MAX], 14)
	for i in Game.party.size():
		_fila_equipo(i)
	MenuScaffold.nota(_lista, "El primero va EN CABEZA: es el cuerpo que mueves por el mapa, el "
		+ "que recolecta y el que gasta aguante. También se cambia con las teclas 1/2/3.")

	MenuScaffold.titulo(_content, "En casa (%d)" % Game.en_el_banquillo().size(), 14)
	var banquillo: Array = Game.en_el_banquillo()
	if banquillo.is_empty():
		MenuScaffold.nota(_content, "No hay nadie esperando en casa. Se contrata gente en la taberna.")
	for pj in banquillo:
		_fila_banquillo(pj)


func _fila_equipo(i: int) -> void:
	var pj: PersonajeData = Game.party[i]
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	_lista.add_child(fila)

	fila.add_child(_punto(pj))

	var l := Label.new()
	l.text = "%d. %s  ·  Nv.%d" % [i + 1, pj.nombre, pj.level]
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if i == 0:
		l.add_theme_color_override("font_color", AMBAR)
	fila.add_child(l)

	# Subir: el de la posicion i pasa a ir delante del i-1. Con i == 1 esto es exactamente
	# "ponlo en cabeza", que es lo mismo que hace la tecla 2.
	var arriba := Button.new()
	arriba.text = "▲"
	arriba.custom_minimum_size = Vector2(30, 0)
	arriba.disabled = i == 0
	arriba.tooltip_text = "Adelantarlo una posición"
	arriba.pressed.connect(func():
		var tmp: PersonajeData = Game.party[i - 1]
		Game.party[i - 1] = Game.party[i]
		Game.party[i] = tmp
		_avisar_cambio_lider()
		_rebuild())
	fila.add_child(arriba)

	var fuera := Button.new()
	fuera.text = "A casa"
	fuera.disabled = Game.party.size() <= 1   # alguien tiene que llevar el cuerpo
	fuera.tooltip_text = "Lo deja en el Hogar. No se despide a nadie: sigue en tu plantilla."
	fuera.pressed.connect(func():
		if Game.sacar_del_equipo(pj):
			_aviso = "%s se queda en casa." % pj.nombre
			_aviso_ok = true
			_avisar_cambio_lider()
			_rebuild())
	fila.add_child(fuera)


func _fila_banquillo(pj: PersonajeData) -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	_content.add_child(fila)

	fila.add_child(_punto(pj))

	var l := Label.new()
	l.text = "%s  ·  Nv.%d" % [pj.nombre, pj.level]
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(l)

	var dentro := Button.new()
	dentro.text = "Que baje"
	dentro.disabled = Game.party.size() >= Game.PARTY_MAX
	dentro.pressed.connect(func():
		if Game.meter_en_equipo(pj):
			_aviso = "%s se une al equipo." % pj.nombre
			_aviso_ok = true
			_rebuild()
		else:
			_aviso = "El equipo ya va lleno (%d)." % Game.PARTY_MAX
			_aviso_ok = false
			_rebuild())
	fila.add_child(dentro)


# El cuerpo del personaje, del tamaño de un icono: mismo color y mismo material que por el mapa.
func _punto(pj: PersonajeData) -> ColorRect:
	var punto := ColorRect.new()
	punto.custom_minimum_size = Vector2(18, 18)
	punto.color = pj.color
	punto.material = Game.material_de(pj)
	return punto


# Tocar el orden del equipo puede cambiar QUIEN va en cabeza, y de eso dependen el cuerpo que se
# ve por el mapa, el aguante y la velocidad. Se le avisa al jugador para que se repinte solo.
func _avisar_cambio_lider() -> void:
	var p: Node = get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("refrescar_lider"):
		p.refrescar_lider()


# ============================================================
#  ALMACEN: guardar en casa lo que traes en la bolsa
# ============================================================

func _build_almacen() -> void:
	MenuScaffold.titulo(_header, "EL BAÚL DE CASA", 18)
	MenuScaffold.fila(_content, "En la bolsa", "%d materiales" % Game.materiales.size())
	MenuScaffold.fila(_content, "Guardado en casa", "%d materiales" % Game.almacen_materiales.size())
	MenuScaffold.nota(_content, "Los cristales NO se guardan: esos hay que venderlos en la tienda.")

	var b := Button.new()
	b.text = "Guardar todo lo que traigo"
	b.custom_minimum_size = Vector2(0, 36)
	b.disabled = Game.materiales.is_empty()
	b.pressed.connect(func():
		var n: int = Game.guardar_materiales_en_hogar()
		_aviso = "Guardas %d materiales en casa." % n
		_aviso_ok = true
		_rebuild())
	_content.add_child(b)
