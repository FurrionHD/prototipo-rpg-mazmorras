# ============================================================
#  retorno_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  LA OFERTA DE SUBIRSE al viaje de la piedra de retorno de otro (solo multijugador).
#
#  Un compañero gasta su piedra y se va al pueblo; a los que estaban dentro y a tiro de esa piedra
#  les llega la oferta de subirse GRATIS (ver Game.oferta_retorno y Net.anunciar_retorno). Este
#  nodo es el que decide CUANDO se enseña y en que forma. Tiene dos caras:
#
#   - MODAL: quien la uso y tres salidas (volver / luego / me quedo). Mientras esta abierto no
#     corre ningun reloj -- puedes estar en el baño.
#   - MINIMIZADO: una pildora pequeña con la cuenta atras. AQUI es donde corre el minuto, y es lo
#     que le da tiempo al jugador a extraer el cadaver que acaba de dejar antes de subir.
#
#  El reloj corre SOLO mientras puedes usarlo: aparcada y con el mundo por delante. Con el modal
#  abierto no corre (puedes estar en el baño) y con un combate o un minijuego delante tampoco (una
#  pelea de dos minutos se comeria el margen entero sin que pudieras hacer nada). Nada de eso es
#  explotable: en los tres casos no puedes moverte ni recoger nada, asi que congelar el contador
#  cuesta exactamente lo que da.
# ============================================================

extends CanvasLayer

# Lo que dura la oferta una vez la aparcas. Decision del usuario: un minuto da para rematar una
# extraccion y recoger lo que hay por el suelo, y no tanto como para olvidarse de que existe.
const SEGUNDOS := 60.0

var _root: Control = null          # el modal
var _content: VBoxContainer = null
var _pildora: PanelContainer = null   # la cara minimizada
var _pildora_lbl: Label = null
var _restante: float = SEGUNDOS
var _minimizado: bool = false


func _ready() -> void:
	layer = 94   # encima de los menus del pueblo (93), debajo del combate (100)
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para en solitario: hay que seguir vivo
	add_to_group("retorno_menu")

	var m: Dictionary = MenuScaffold.construir(self, "VUELTA AL PUEBLO",
		"Alguien de tu grupo ha gastado una piedra de retorno. El viaje admite compañía.", _minimizar)
	_root = m["root"]
	_content = m["content"]
	(m["lista_scroll"] as ScrollContainer).visible = false

	_crear_pildora()


# La cara minimizada: una pildora en el centro-derecha, del mismo estilo que las de recogida del
# HUD. Va en ESTA capa y no dentro del HUD porque su vida la manda la oferta, no el HUD.
func _crear_pildora() -> void:
	_pildora = PanelContainer.new()
	_pildora.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_pildora.offset_left = -240
	_pildora.offset_right = -16
	_pildora.offset_top = -18
	_pildora.offset_bottom = 18
	_pildora.visible = false
	_pildora.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.85)
	sb.border_color = Color(0.87, 0.57, 0.26, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 12
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	_pildora.add_theme_stylebox_override("panel", sb)
	add_child(_pildora)

	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Volver a abrir la oferta de vuelta al pueblo"
	b.pressed.connect(_abrir_desde_pildora)
	_pildora.add_child(b)

	_pildora_lbl = Label.new()
	_pildora_lbl.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36))
	_pildora_lbl.add_theme_font_size_override("font_size", 14)
	_pildora_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_pildora_lbl.add_theme_constant_override("outline_size", 3)
	_pildora_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(_pildora_lbl)


# El aviso NO se engancha al final del combate, se SONDEA. Con una sola condicion queda cubierto
# todo lo que puede tener ocupado al jugador -- combate, extraccion, mineria, tala, cualquier menu
# -- en vez de tener que acordarse de llamar a algo desde cinco sitios distintos.
#
# Y ademas esquiva una trampa: Game.cerrar_menus_abiertos() cierra a la fuerza los menus abiertos
# justo antes de montar un combate, asi que si te embisten con esto delante se cerrara solo. Como
# cerrar aqui significa MINIMIZAR (nunca descartar), la oferta sobrevive y vuelve a salir sola en
# cuanto acaba la pelea.
func _process(delta: float) -> void:
	# Sin oferta, o sin sesion: fuera. Lo segundo cubre que se caiga la conexion con la oferta
	# delante -- sin esto te quedarias con un modal que ya no puede llevarte a ninguna parte.
	if not Game.hay_oferta_retorno() or not Net.activo:
		if _root.visible or _pildora.visible:
			_ocultar_todo()
		Game.descartar_oferta_retorno()
		return
	if _root.visible:
		return   # con el modal delante no corre el reloj: la decision no tiene prisa
	var libre: bool = _jugador_libre()
	if _minimizado:
		# El reloj SOLO corre cuando puedes usar el minuto. Si te embisten mientras esta aparcada,
		# la pildora se queda congelada hasta que salgas de la pelea: el minuto es para rematar lo
		# que estabas haciendo, y una pelea de dos minutos se lo comeria entero sin que tu pudieras
		# hacer nada. Es la misma condicion con la que se decide enseñarla, a proposito.
		if libre:
			_restante -= delta
			if _restante <= 0.0:
				_expirar()
				return
		_pildora_lbl.text = "  ↑ Volver al pueblo   ·   %d s" % ceili(_restante)
		_pildora.modulate.a = 1.0 if libre else 0.55   # apagada = el tiempo no corre
		return
	# Ni abierto ni minimizado: es una oferta recien llegada. Se enseña en cuanto estes libre.
	if libre:
		_abrir()


# ¿Puede el jugador atender a esto AHORA? Sin pantalla de combate/minijuego delante y sin ningun
# menu abierto. Manda las dos cosas: cuando se enseña la oferta y cuando corre su cuenta atras.
func _jugador_libre() -> bool:
	return Game._active_layer == null and not Game.hay_modal() and not Game.debug_panel_open


func _abrir() -> void:
	_minimizado = false
	_pildora.visible = false
	_root.visible = true
	Game.abrir_menu(self)
	_rebuild()


# Reabrir desde la pildora: el contador se PARA y conserva lo que quedaba (no se reinicia). Volver
# a minimizar sigue por donde iba.
func _abrir_desde_pildora() -> void:
	if not Game.hay_oferta_retorno():
		return
	_abrir()


# La ✕ del scaffold y el Esc van aqui: el default seguro es aparcar, no perder el viaje.
func _minimizar() -> void:
	if _root.visible:
		_root.visible = false
		Game.cerrar_menu(self)
	_minimizado = true
	_pildora.visible = Game.hay_oferta_retorno()
	_pildora_lbl.text = "  ↑ Volver al pueblo   ·   %d s" % ceili(_restante)


func _rechazar() -> void:
	Game.descartar_oferta_retorno()
	_ocultar_todo()
	print("[retorno] Rechazas el viaje: te quedas abajo.")


func _expirar() -> void:
	Game.descartar_oferta_retorno()
	_ocultar_todo()
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_toast"):
		hud.mostrar_toast("Se te fue el viaje: la piedra de retorno ya no te espera.")


func _ocultar_todo() -> void:
	if _root.visible:
		_root.visible = false
		Game.cerrar_menu(self)
	_pildora.visible = false
	_minimizado = false
	_restante = SEGUNDOS


func _aceptar() -> void:
	# aceptar_oferta_retorno hace el viaje entero (y se planta si has bajado por debajo del alcance
	# de esa piedra desde que llego la oferta).
	if _root.visible:
		_root.visible = false
		Game.cerrar_menu(self)
	_pildora.visible = false
	_minimizado = false
	if not Game.aceptar_oferta_retorno():
		var hud: Node = get_tree().get_first_node_in_group("hud")
		if hud != null and hud.has_method("mostrar_toast"):
			hud.mostrar_toast("Esa piedra no llega hasta este piso.")


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_minimizar()
			get_viewport().set_input_as_handled()


func _rebuild() -> void:
	for c in _content.get_children():
		c.queue_free()

	var quien: String = str(Game.oferta_retorno.get("quien", "Alguien"))
	var piso_max: int = int(Game.oferta_retorno.get("piso_max", 1))
	MenuScaffold.titulo(_content, "%s VUELVE AL PUEBLO" % quien.to_upper())
	MenuScaffold.nota(_content, "Ha gastado su piedra de retorno. Puedes subir con él sin gastar la tuya.")
	_content.add_child(HSeparator.new())
	MenuScaffold.fila(_content, "Estás en", "Piso %d" % Game.current_floor)
	MenuScaffold.fila(_content, "Esa piedra alcanza", "hasta el piso %d" % piso_max)
	_content.add_child(HSeparator.new())

	var b_si := Button.new()
	b_si.text = "Volver al pueblo con él"
	b_si.custom_minimum_size = Vector2(0, 40)
	b_si.pressed.connect(_aceptar)
	_content.add_child(b_si)

	var b_luego := Button.new()
	b_luego.text = "Ahora no — dame %d s  (minimizar)" % int(SEGUNDOS)
	b_luego.custom_minimum_size = Vector2(0, 38)
	b_luego.pressed.connect(_minimizar)
	_content.add_child(b_luego)

	var b_no := Button.new()
	b_no.text = "Me quedo abajo"
	b_no.custom_minimum_size = Vector2(0, 34)
	b_no.pressed.connect(_rechazar)
	_content.add_child(b_no)

	MenuScaffold.nota(_content, "Si lo minimizas te queda un minuto para rematar lo que estés haciendo —extraer un cuerpo, recoger lo que hay por el suelo— y decidir. Con esta ventana abierta el tiempo no corre.")
