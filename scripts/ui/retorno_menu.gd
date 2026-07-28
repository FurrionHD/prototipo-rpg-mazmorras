# ============================================================
#  retorno_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  LA OFERTA DE SUBIRSE al viaje de la piedra de retorno de otro (solo multijugador).
#
#  Un compañero gasta su piedra y se va al pueblo; a los que estaban dentro y a tiro de esa piedra
#  les llega la oferta de subirse GRATIS (ver Game.oferta_retorno y Net.anunciar_retorno). Este
#  nodo es el que decide CUANDO se enseña y en que forma. Tiene dos caras:
#
#   - TARJETA: una frase y tres botones pequeños en UNA fila. Mientras esta delante no corre
#     ningun reloj -- puedes estar en el baño.
#   - MINIMIZADO: una pildora pequeña con la cuenta atras. AQUI es donde corre el minuto, y es lo
#     que le da tiempo al jugador a extraer el cadaver que acaba de dejar antes de subir.
#
#  NO usa MenuScaffold, y es a proposito: ese monta una PANTALLA (fondo opaco a pantalla completa,
#  columna lateral, titulo, lista) y esto no es una pantalla, es una pregunta de una linea. Con el
#  scaffold tapaba la mazmorra entera para decir seis palabras. Aqui: una tarjeta centrada, negra
#  translucida, con el borde grueso y redondeado, y fuera de ella NADA -- ni velo ni oscurecido, se
#  sigue viendo el juego.
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

const AMBAR := Color(0.95, 0.72, 0.36)

var _root: Control = null             # la capa transparente que sostiene la tarjeta
var _frase: Label = null
var _pildora: PanelContainer = null   # la cara minimizada
var _pildora_lbl: Label = null
var _restante: float = SEGUNDOS
var _minimizado: bool = false


func _ready() -> void:
	layer = 94   # encima de los menus del pueblo (93), debajo del combate (100)
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para en solitario: hay que seguir vivo
	add_to_group("retorno_menu")
	_crear_tarjeta()
	_crear_pildora()


# El fondo NEGRO TRANSLUCIDO con el borde grueso y redondeado que llevan las dos caras. Una sola
# funcion para que la tarjeta y la pildora sean obviamente la misma cosa en dos tamaños.
func _fondo(radio: int, borde: int, margen_h: int, margen_v: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.border_color = Color(0, 0, 0, 0.9)
	sb.set_border_width_all(borde)
	sb.set_corner_radius_all(radio)
	sb.content_margin_left = margen_h
	sb.content_margin_right = margen_h
	sb.content_margin_top = margen_v
	sb.content_margin_bottom = margen_v
	return sb


# La TARJETA: una frase y tres botones pequeños en una fila. Nada de velo por detras — la raiz es
# un Control transparente en MOUSE_FILTER_IGNORE, asi que fuera de la tarjeta no hay literalmente
# nada: ni pixel pintado ni clic capturado.
func _crear_tarjeta() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)

	var caja := PanelContainer.new()
	caja.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	# Ancha de sobra para que la pregunta quepa en UNA linea: partida en dos, la tarjeta crece a lo
	# alto y deja de leerse de un vistazo, que es justo lo unico que tiene que hacer.
	caja.offset_left = -310
	caja.offset_right = 310
	caja.offset_top = 96      # a la altura de los avisos del HUD, no tapando al personaje
	caja.mouse_filter = Control.MOUSE_FILTER_STOP
	caja.add_theme_stylebox_override("panel", _fondo(14, 4, 18, 12))
	_root.add_child(caja)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	caja.add_child(vb)

	_frase = Label.new()
	_frase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_frase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_frase.add_theme_color_override("font_color", AMBAR)
	_frase.add_theme_font_size_override("font_size", 15)
	_frase.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_frase.add_theme_constant_override("outline_size", 3)
	vb.add_child(_frase)

	# Los tres, en UNA fila y pequeños: es una pregunta, no un menu.
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 8)
	vb.add_child(fila)
	fila.add_child(_boton("Sí, volver", _aceptar))
	fila.add_child(_boton("Esperar %ds" % int(SEGUNDOS), _minimizar))
	fila.add_child(_boton("No", _rechazar))


func _boton(txt: String, al_pulsar: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(96, 26)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(al_pulsar)
	return b


# La cara minimizada: la misma tarjeta encogida a una linea, en el centro-derecha.
func _crear_pildora() -> void:
	_pildora = PanelContainer.new()
	_pildora.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_pildora.offset_left = -230
	_pildora.offset_right = -16
	_pildora.offset_top = -20
	_pildora.offset_bottom = 20
	_pildora.visible = false
	_pildora.mouse_filter = Control.MOUSE_FILTER_STOP
	_pildora.add_theme_stylebox_override("panel", _fondo(10, 3, 8, 4))
	add_child(_pildora)

	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Volver a abrir la oferta de vuelta al pueblo"
	b.pressed.connect(_abrir_desde_pildora)
	_pildora.add_child(b)

	_pildora_lbl = Label.new()
	_pildora_lbl.add_theme_color_override("font_color", AMBAR)
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


# Solo la frase: los botones son fijos y ya estan puestos (ver _crear_tarjeta). Es una pregunta de
# una linea, no un menu que se reconstruya.
func _rebuild() -> void:
	_frase.text = "%s ha usado una piedra de retorno. ¿Quieres volver al pueblo?" % str(
		Game.oferta_retorno.get("quien", "Alguien"))
