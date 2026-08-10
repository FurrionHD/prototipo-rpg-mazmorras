# ============================================================
#  touch_controls.gd  (CanvasLayer creada por codigo desde el jugador, solo si Tactil.activo)
#  Los mandos del movil para el MAPA. En pantalla:
#
#    - Mitad izquierda: joystick DINAMICO. No se dibuja hasta que pones el dedo; nace donde lo
#      pones y el circulito lo sigue. Publica Tactil.eje, que es lo que lee player.gd.
#    - Abajo a la derecha: el boton GRANDE de actuar. Hace la F y el ESPACIO en uno, y enseña
#      la F, y a su lado el de ATACAR, que hace el ESPACIO. Cada uno se apaga cuando no tiene nada
#      que hacer (ver player.hay_algo_que_tocar / hay_enemigo_a_tiro).
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

# El joystick era claramente pequeño en el aparato: se vio jugando. Todo sube en proporcion para
# que la zona muerta siga siendo la misma parte del recorrido y no cambie el tacto.
const RADIO_BASE := 100.0     # lo que se abre el joystick: a esa distancia del centro, velocidad tope
const RADIO_MUERTO := 20.0    # por debajo de esto, quieto: un pulgar apoyado no es una direccion
const RADIO_DEDO := 38.0      # el circulito que sigue al dedo

const R_ACTUAR := 52.0
const R_ATACAR := 44.0
const R_PEQUENO := 30.0
const MARGEN := 28.0

var _joystick: Control = null
var _centro: Vector2 = Vector2.ZERO
var _dedo_joystick: int = -1

var _actuar: Control = null
var _atacar: Control = null
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
	# Saber si hay algo a mano cuesta un barrido de cuatro grupos del mapa (ver hay_algo_que_tocar),
	# y a 60 fps en un movil eso es tirar bateria: a ~8 veces por segundo los botones se encienden
	# igual de rapido de lo que uno se acerca a las cosas.
	_desde_refresco += 1
	if _desde_refresco >= 8:
		_desde_refresco = 0
		_refrescar_botones()
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
#  Mismo aspecto que la botonera de arriba (fondo oscuro, borde claro, icono dibujado) pero
#  REDONDOS. Y con iconos de iconos.gd, no emoji: un emoji sale segun la fuente que tenga el
#  aparato, y eso no se descubre hasta tener el APK en la mano.
# ------------------------------------------------------------
func _montar_botones() -> void:
	# INTERACTUAR, en la esquina: es el que mas se usa y el que mejor le cae al pulgar.
	_actuar = _crear_boton(R_ACTUAR, Callable(Iconos, "mano"))
	_colocar(_actuar, MARGEN, MARGEN)
	add_child(_actuar)

	# ATACAR, en diagonal. Antes NO existia: el grande decidia solo (tocar si habia algo, pegar si
	# no), y con un cadaver o una veta al lado nunca llegaba a atacar — por eso costaba tanto entrar
	# en combate. Con dos botones se acaba la adivinanza: el grande toca, este pega, siempre.
	_atacar = _crear_boton(R_ATACAR, Callable(Iconos, "espada"))
	_colocar(_atacar, MARGEN + R_ACTUAR * 2.0 + 14.0, MARGEN + 30.0)
	add_child(_atacar)

	_curar = _crear_boton(R_PEQUENO, Callable(Iconos, "pocion"))
	_colocar(_curar, MARGEN + R_ACTUAR * 2.0 + 14.0 + R_ATACAR * 2.0 + 14.0, MARGEN)
	add_child(_curar)

	# Los dos de FIJAR, encima y mas pequeños: no son de pulsar a cada paso.
	_correr = _crear_boton(R_PEQUENO, Callable(Iconos, "correr"))
	_colocar(_correr, MARGEN + R_ACTUAR - R_PEQUENO, MARGEN + R_ACTUAR * 2.0 + 16.0)
	add_child(_correr)

	_sigilo = _crear_boton(R_PEQUENO, Callable(Iconos, "sigilo"))
	_colocar(_sigilo, MARGEN + R_ACTUAR - R_PEQUENO + R_PEQUENO * 2.0 + 16.0,
		MARGEN + R_ACTUAR * 2.0 + 16.0)
	add_child(_sigilo)

	_conectar_pulso(_actuar, _on_actuar)
	# ATACAR va de MANTENER, no de tocar: un toque corto es el ataque de siempre y mantenerlo saca
	# los hechizos (ver player._tick_ataque). Con Tactil.toque -pulsar y soltar al frame siguiente-
	# mantener el dedo era imposible en el movil: siempre se leia como un toque corto.
	_conectar_mantener(_atacar, &"atacar")
	_conectar_pulso(_curar, _on_curar)
	_conectar_pulso(_correr, _on_correr)
	_conectar_pulso(_sigilo, _on_sigilo)


# Un boton REDONDO que se pinta solo. No es un Button porque los de Godot son rectangulos y aqui el
# area de toque tiene que ser el CIRCULO: en un movil, dos rectangulos pegados se pisan las esquinas
# y acabas pulsando el que no querias.
func _crear_boton(radio: float, dibujo: Callable) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.set_meta("radio", radio)
	c.set_meta("activo", true)
	c.set_meta("hundido", false)
	c.draw.connect(func() -> void:
		var r: float = float(c.get_meta("radio"))
		var encendido: bool = bool(c.get_meta("activo"))
		var fondo := Color(0.10, 0.11, 0.14, 0.86)
		var tinta := Color(0.90, 0.90, 0.94)
		var borde := Color(1, 1, 1, 0.30)
		if not encendido:
			fondo = Color(0.10, 0.11, 0.14, 0.45)
			tinta = Color(0.45, 0.46, 0.52, 0.7)
			borde = Color(1, 1, 1, 0.12)
		elif bool(c.get_meta("hundido")):
			fondo = Color(0.30, 0.32, 0.40, 0.94)
		var centro := Vector2(r, r)
		c.draw_circle(centro, r, fondo)
		c.draw_arc(centro, r, 0.0, TAU, 48, borde, 2.5, true)
		var lado: float = r * 1.15
		dibujo.call(c, centro - Vector2(lado, lado) * 0.5, lado, tinta)
	)
	return c


# Coloca un boton midiendo desde la esquina de ABAJO A LA DERECHA (los anclajes ya estan ahi), que
# es como se piensa un mando de movil: "tantos pixeles del borde", no una coordenada absoluta. El
# borde seguro del aparato va DENTRO de la cuenta: ver Tactil.borde.
func _colocar(c: Control, desde_derecha: float, desde_abajo: float) -> void:
	var d: float = float(c.get_meta("radio")) * 2.0
	var b: Vector2 = Tactil.borde
	c.offset_right = -desde_derecha - b.x
	c.offset_left = c.offset_right - d
	c.offset_bottom = -desde_abajo - b.y
	c.offset_top = c.offset_bottom - d


# El toque cuenta solo si cae DENTRO del circulo: la esquina del rectangulo es del boton de al lado.
func _conectar_pulso(c: Control, fn: Callable) -> void:
	c.gui_input.connect(func(event: InputEvent) -> void:
		var pos: Vector2 = Vector2.ZERO
		var pulsando: bool = false
		if event is InputEventScreenTouch:
			var t := event as InputEventScreenTouch
			pos = t.position
			pulsando = t.pressed
		elif event is InputEventMouseButton:
			var m := event as InputEventMouseButton
			if m.button_index != MOUSE_BUTTON_LEFT:
				return
			pos = m.position
			pulsando = m.pressed
		else:
			return
		var r: float = float(c.get_meta("radio"))
		if not pulsando:
			if bool(c.get_meta("hundido")):
				c.set_meta("hundido", false)
				c.queue_redraw()
			return
		if pos.distance_to(Vector2(r, r)) > r:
			return
		if not bool(c.get_meta("activo")):
			return
		c.set_meta("hundido", true)
		c.queue_redraw()
		fn.call()
	)


# Boton de MANTENER: la accion se queda pulsada mientras el dedo esta encima y se suelta al
# levantarlo. Es lo que permite distinguir un toque de un mantenido (ver _conectar_pulso, que es su
# hermano de "toque suelto").
func _conectar_mantener(c: Control, accion: StringName) -> void:
	c.set_meta("accion_mantenida", accion)
	c.gui_input.connect(func(event: InputEvent) -> void:
		var pos: Vector2 = Vector2.ZERO
		var pulsando: bool = false
		if event is InputEventScreenTouch:
			var t := event as InputEventScreenTouch
			pos = t.position
			pulsando = t.pressed
		elif event is InputEventMouseButton:
			var m := event as InputEventMouseButton
			if m.button_index != MOUSE_BUTTON_LEFT:
				return
			pos = m.position
			pulsando = m.pressed
		else:
			return
		if not pulsando:
			_soltar_mantenidos()
			return
		var r: float = float(c.get_meta("radio"))
		if pos.distance_to(Vector2(r, r)) > r:
			return
		if not bool(c.get_meta("activo")):
			return
		c.set_meta("hundido", true)
		c.queue_redraw()
		Tactil.pulsar(accion)
	)


# RED DE SEGURIDAD: si el dedo se sale del boton antes de levantarlo, el "soltar" no le llega al
# Control y la accion se quedaria pulsada PARA SIEMPRE (atacando sola). Aqui se caza cualquier
# levantada que no haya consumido nadie.
func _unhandled_input(event: InputEvent) -> void:
	var soltando: bool = (event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and not (event as InputEventMouseButton).pressed)
	if soltando:
		_soltar_mantenidos()


func _soltar_mantenidos() -> void:
	for c in get_children():
		if not (c is Control) or not c.has_meta("accion_mantenida"):
			continue
		if bool(c.get_meta("hundido")):
			c.set_meta("hundido", false)
			c.queue_redraw()
		Tactil.soltar(StringName(c.get_meta("accion_mantenida")))


func _on_actuar() -> void:
	Tactil.toque(&"interactuar")


func _on_curar() -> void:
	Tactil.toque(&"curar")


# Correr y sigilo son de FIJAR: se quedan puestos hasta que los vuelvas a pulsar. Correr con el
# pulgar clavado en un boton mientras el otro lleva el joystick no es jugable.
func _on_correr() -> void:
	if Tactil.esta_pulsada(&"correr"):
		Tactil.soltar(&"correr")
	else:
		Tactil.pulsar(&"correr")
		# El sigilo tiene prioridad en player.gd: con los dos puestos, correr no haria nada y el
		# boton estaria mintiendo.
		Tactil.soltar(&"sigilo")


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


# Cada boton se apaga cuando no tiene nada que hacer, que es lo que sustituye al icono cambiante de
# antes: ya no hay que adivinar cual de las dos intenciones va a salir, se ve cual esta viva.
func _refrescar_botones() -> void:
	var p: Node = _lider_nodo()
	var tocar: bool = p != null and p.has_method("hay_algo_que_tocar") and p.hay_algo_que_tocar()
	var pegar: bool = p != null and p.has_method("hay_enemigo_a_tiro") and p.hay_enemigo_a_tiro()
	_encender(_actuar, tocar)
	_encender(_atacar, pegar)


func _encender(c: Control, si: bool) -> void:
	if bool(c.get_meta("activo")) == si:
		return
	c.set_meta("activo", si)
	c.queue_redraw()


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
