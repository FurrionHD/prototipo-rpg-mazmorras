# ============================================================
#  touch_controls.gd  (CanvasLayer creada por codigo desde el jugador, solo si Tactil.activo)
#  Los mandos del movil para el MAPA. En pantalla:
#
#    - Mitad izquierda: joystick DINAMICO. No se dibuja hasta que pones el dedo; nace donde lo
#      pones y el circulito lo sigue. Publica Tactil.eje, que es lo que lee player.gd.
#    - Abajo a la derecha: el boton GRANDE de actuar. Hace la F y el ESPACIO en uno, y enseña
#      CUAL de las dos va a hacer (ver player.accion_de_contexto).
#    - Pegado a el, el circulito azul de curacion optima (la Q).
#    - Encima, dos botones pequeños de FIJAR: correr y sigilo. Se quedan hundidos hasta que los
#      vuelves a pulsar; con el teclado siguen siendo de mantener, que ahi es lo comodo.
#
#  Los botones de arriba (personaje, inventario) los pone el HUD, junto al dinero y el piso, y las
#  tarjetas del grupo son pulsables para cambiar de lider: las dos cosas viven donde ya estaban
#  pintadas (hud.gd y player.gd) en vez de repintarse aqui.
#
#  Esta capa se ESCONDE con cualquier modal delante (menu, combate, recoleccion): ahi manda la UI
#  de esa pantalla, que ya se maneja a toques por si sola. Al esconderse suelta todo lo que
#  tuviera pulsado, o saldrias de la pelea corriendo sin haberlo pedido.
# ============================================================

extends CanvasLayer

const RADIO_BASE := 68.0      # lo que se abre el joystick: a esa distancia del centro, velocidad tope
const RADIO_MUERTO := 14.0    # por debajo de esto, quieto: un pulgar apoyado no es una direccion
const RADIO_DEDO := 26.0      # el circulito que sigue al dedo

const R_ACTUAR := 52.0
const R_PEQUENO := 30.0
const MARGEN := 28.0

var _joystick: Control = null
var _centro: Vector2 = Vector2.ZERO
var _dedo_joystick: int = -1

var _actuar: Control = null
var _actuar_lbl: Label = null
var _curar: Control = null
var _correr: Control = null
var _sigilo: Control = null

var _jugador: Node = null
var _desde_refresco: int = 0


func _ready() -> void:
	layer = 6   # encima del HUD (5), muy por debajo del combate (100)
	# Los menus pausan el arbol (ver Game.abrir_menu): sin esto la capa se congela y, si un boton
	# de fijar se quedo hundido, no habria quien lo soltara.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("touch_controls")

	_joystick = _crear_joystick()
	add_child(_joystick)

	# La zona del joystick: la MITAD IZQUIERDA de la pantalla, entera. No un circulo fijo: en un
	# movil no miras el pulgar izquierdo, lo pones donde te cae, y el joystick nace ahi.
	var zona := Control.new()
	zona.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	zona.anchor_right = 0.5
	zona.mouse_filter = Control.MOUSE_FILTER_STOP
	zona.gui_input.connect(_on_zona_input)
	add_child(zona)
	# El joystick se dibuja ENCIMA de su zona: se añade despues para quedar por delante.
	move_child(_joystick, get_child_count() - 1)

	_montar_botones()
	_joystick.visible = false


func _process(_delta: float) -> void:
	# Con una pantalla delante, fuera: el combate, la bolsa y los minijuegos traen sus propios
	# botones y este overlay solo estorbaria (y el joystick moveria al jugador por detras).
	var estorba: bool = Game.hay_modal() or Game.inventory_open or Game.debug_panel_open
	if estorba == visible:
		visible = not estorba
		if estorba:
			_soltar_todo()
	if not visible:
		return
	# Saber que haria el boton cuesta un barrido de cuatro grupos del mapa (ver accion_de_contexto),
	# y a 60 fps en un movil eso es tirar bateria: a ~8 veces por segundo el icono cambia igual de
	# rapido de lo que uno se acerca a las cosas.
	_desde_refresco += 1
	if _desde_refresco >= 8:
		_desde_refresco = 0
		_refrescar_actuar()
	_refrescar_fijos()


func _exit_tree() -> void:
	_soltar_todo()


func _soltar_todo() -> void:
	_dedo_joystick = -1
	_joystick.visible = false
	Tactil.soltar_todo()


# ------------------------------------------------------------
#  JOYSTICK
# ------------------------------------------------------------
func _crear_joystick() -> Control:
	var raiz := Control.new()
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.draw.connect(_dibujar_joystick.bind(raiz))
	return raiz


func _dibujar_joystick(c: Control) -> void:
	var dedo: Vector2 = _centro + Tactil.eje * RADIO_BASE
	c.draw_circle(_centro, RADIO_BASE, Color(1, 1, 1, 0.10))
	c.draw_arc(_centro, RADIO_BASE, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 2.0, true)
	c.draw_circle(dedo, RADIO_DEDO, Color(1, 1, 1, 0.30))
	c.draw_arc(dedo, RADIO_DEDO, 0.0, TAU, 32, Color(1, 1, 1, 0.55), 2.0, true)


func _on_zona_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_agarrar(t.index, t.position)
		elif t.index == _dedo_joystick:
			_soltar_joystick()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _dedo_joystick:
			_mover_joystick(d.position)
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.button_index != MOUSE_BUTTON_LEFT:
			return
		# -2 = "lo lleva el raton". Se distingue del indice de un dedo (0, 1, 2...) para que el
		# click emulado que viene DETRAS de cada toque no le robe el mando al dedo de verdad.
		if m.pressed:
			_agarrar(-2, m.position)
		elif _dedo_joystick == -2:
			_soltar_joystick()
	elif event is InputEventMouseMotion and _dedo_joystick == -2:
		_mover_joystick((event as InputEventMouseMotion).position)


func _agarrar(idx: int, pos: Vector2) -> void:
	if _dedo_joystick != -1:
		return   # ya hay un pulgar mandando (o es el click emulado detras del dedo)
	_dedo_joystick = idx
	_centro = pos
	_joystick.visible = true
	_mover_joystick(pos)


func _mover_joystick(pos: Vector2) -> void:
	var v: Vector2 = pos - _centro
	var largo: float = v.length()
	if largo <= RADIO_MUERTO:
		Tactil.eje = Vector2.ZERO
	else:
		# El tramo util empieza DONDE ACABA la zona muerta, no en el centro: si no, el primer
		# milimetro fuera de la zona muerta ya iba al 20% de velocidad y se notaba un escalon.
		var fuerza: float = clampf((largo - RADIO_MUERTO) / (RADIO_BASE - RADIO_MUERTO), 0.0, 1.0)
		Tactil.eje = v.normalized() * fuerza
	_joystick.queue_redraw()


func _soltar_joystick() -> void:
	_dedo_joystick = -1
	Tactil.eje = Vector2.ZERO
	_joystick.visible = false


# ------------------------------------------------------------
#  BOTONES
# ------------------------------------------------------------
func _montar_botones() -> void:
	# El grande de actuar, en la esquina de abajo a la derecha: es el que mas se usa y el que mejor
	# le cae al pulgar.
	_actuar = _crear_boton(R_ACTUAR, Color(0.86, 0.80, 0.42), "·")
	_actuar_lbl = _actuar.get_child(0) as Label
	_colocar(_actuar, MARGEN, MARGEN)
	add_child(_actuar)

	# El azul de curacion, pegado a su izquierda (es el circulito del boceto).
	_curar = _crear_boton(R_PEQUENO, Color(0.38, 0.62, 0.92), "+")
	_colocar(_curar, MARGEN + R_ACTUAR * 2.0 + 18.0, MARGEN)
	add_child(_curar)

	# Los dos de FIJAR, encima del grande y mas pequeños: no son de pulsar a cada paso.
	_correr = _crear_boton(R_PEQUENO, Color(0.45, 0.75, 0.45), "»")
	_colocar(_correr, MARGEN + R_ACTUAR - R_PEQUENO, MARGEN + R_ACTUAR * 2.0 + 16.0)
	add_child(_correr)

	_sigilo = _crear_boton(R_PEQUENO, Color(0.55, 0.50, 0.75), "~")
	_colocar(_sigilo, MARGEN + R_ACTUAR - R_PEQUENO + R_PEQUENO * 2.0 + 16.0,
		MARGEN + R_ACTUAR * 2.0 + 16.0)
	add_child(_sigilo)

	_conectar_pulso(_actuar, _on_actuar)
	_conectar_pulso(_curar, _on_curar)
	_conectar_pulso(_correr, _on_correr)
	_conectar_pulso(_sigilo, _on_sigilo)


# Un boton REDONDO: un Control anclado a la esquina de abajo a la derecha que se pinta solo. No es
# un Button porque los botones de Godot son rectangulos y aqui el area de toque tiene que ser el
# circulo: en un movil, dos rectangulos pegados se pisan las esquinas y pulsas el que no querias.
func _crear_boton(radio: float, color: Color, texto: String) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.set_meta("radio", radio)
	c.set_meta("color", color)
	c.set_meta("activo", true)
	c.set_meta("hundido", false)
	c.draw.connect(_dibujar_boton.bind(c))

	var lbl := Label.new()
	lbl.text = texto
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", int(radio * 0.7))
	lbl.add_theme_color_override("font_color", Color(0.06, 0.06, 0.08))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(lbl)
	return c


# Coloca un boton midiendo desde la esquina de ABAJO A LA DERECHA (los anclajes ya estan ahi), que
# es como se piensa un mando de movil: "tantos pixeles del borde", no una coordenada absoluta.
func _colocar(c: Control, desde_derecha: float, desde_abajo: float) -> void:
	var d: float = float(c.get_meta("radio")) * 2.0
	c.offset_right = -desde_derecha
	c.offset_left = -desde_derecha - d
	c.offset_bottom = -desde_abajo
	c.offset_top = -desde_abajo - d


func _dibujar_boton(c: Control) -> void:
	var r: float = float(c.get_meta("radio"))
	var col: Color = c.get_meta("color")
	if not bool(c.get_meta("activo")):
		col = col.darkened(0.55)
		col.a = 0.45
	elif bool(c.get_meta("hundido")):
		col = col.lightened(0.35)
	var centro := Vector2(r, r)
	c.draw_circle(centro, r, Color(col.r, col.g, col.b, col.a * 0.75))
	c.draw_arc(centro, r, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 2.5, true)


# El toque cuenta solo si cae DENTRO del circulo: la esquina del rectangulo es del boton de al lado.
func _conectar_pulso(c: Control, fn: Callable) -> void:
	c.gui_input.connect(func(event: InputEvent) -> void:
		var pos: Vector2 = Vector2.ZERO
		if event is InputEventScreenTouch:
			if not (event as InputEventScreenTouch).pressed:
				return
			pos = (event as InputEventScreenTouch).position
		elif event is InputEventMouseButton:
			var m := event as InputEventMouseButton
			if not m.pressed or m.button_index != MOUSE_BUTTON_LEFT:
				return
			pos = m.position
		else:
			return
		var r: float = float(c.get_meta("radio"))
		if pos.distance_to(Vector2(r, r)) > r:
			return
		if not bool(c.get_meta("activo")):
			return
		fn.call()
	)


func _on_actuar() -> void:
	var accion: StringName = _accion_actual()
	if accion != &"":
		Tactil.toque(accion)


func _on_curar() -> void:
	Tactil.toque(&"curar")


# Correr y sigilo son de FIJAR: se quedan puestos hasta que los vuelvas a pulsar. Correr con el
# pulgar clavado en un boton mientras el otro lleva el joystick no es jugable.
func _on_correr() -> void:
	if Tactil.esta_pulsada(&"correr"):
		Tactil.soltar(&"correr")
	else:
		Tactil.pulsar(&"correr")
		Tactil.soltar(&"sigilo")   # el sigilo tiene prioridad en player.gd: con los dos puestos,
		                           # correr no haria nada y el boton mentiria


func _on_sigilo() -> void:
	if Tactil.esta_pulsada(&"sigilo"):
		Tactil.soltar(&"sigilo")
	else:
		Tactil.pulsar(&"sigilo")
		Tactil.soltar(&"correr")


# ------------------------------------------------------------
#  REFRESCO
# ------------------------------------------------------------
func _lider_nodo() -> Node:
	if not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("player")
	return _jugador


func _accion_actual() -> StringName:
	var p: Node = _lider_nodo()
	if p == null or not p.has_method("accion_de_contexto"):
		return &""
	return p.accion_de_contexto()


# El boton grande dice QUE va a hacer antes de que lo pulses: con una sola tecla para las dos
# intenciones, adivinarlo seria lo mismo que no tener las dos.
func _refrescar_actuar() -> void:
	var accion: StringName = _accion_actual()
	var texto: String = "·"
	var color := Color(0.86, 0.80, 0.42)
	if accion == &"interactuar":
		texto = "✋"
	elif accion == &"atacar":
		texto = "⚔"
		color = Color(0.90, 0.48, 0.40)
	_actuar_lbl.text = texto
	if _actuar.get_meta("color") != color or bool(_actuar.get_meta("activo")) != (accion != &""):
		_actuar.set_meta("color", color)
		_actuar.set_meta("activo", accion != &"")
		_actuar.queue_redraw()


func _refrescar_fijos() -> void:
	# Sin fuelle no se corre (lo decide player.gd), asi que el boton se apaga Y se suelta: dejarlo
	# hundido seria un boton diciendo que corres mientras te arrastras.
	var p: Node = _lider_nodo()
	var puede_correr: bool = p == null or not p.has_method("sin_fuelle") or not p.sin_fuelle()
	if not puede_correr and Tactil.esta_pulsada(&"correr"):
		Tactil.soltar(&"correr")
	_pintar_fijo(_correr, Tactil.esta_pulsada(&"correr"), puede_correr)
	_pintar_fijo(_sigilo, Tactil.esta_pulsada(&"sigilo"), true)


func _pintar_fijo(c: Control, hundido: bool, activo: bool) -> void:
	if bool(c.get_meta("hundido")) == hundido and bool(c.get_meta("activo")) == activo:
		return
	c.set_meta("hundido", hundido)
	c.set_meta("activo", activo)
	c.queue_redraw()
