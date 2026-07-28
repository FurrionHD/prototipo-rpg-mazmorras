# ============================================================
#  pause_menu.gd  (CanvasLayer creada por codigo desde el jugador, como el HUD)
#  Menu de PAUSA (ESC): Reanudar / Guardar / Guardar y salir / Salir sin guardar.
#  Se puede guardar en CUALQUIER sitio, tambien en mitad de la mazmorra: la partida recuerda
#  el piso, tu posicion exacta y los bichos que hubiera (ver Game.exportar_partida).
#
#  NO se abre durante un COMBATE ni durante la EXTRACCION: esas pantallas ya tienen el arbol
#  en pausa y su propio flujo, y guardar a mitad de un combate seria guardar un estado que
#  luego no se puede reconstruir (media pelea, un enemigo a medio matar...).
#  Interfaz placeholder por codigo; el arte va al final.
# ============================================================

extends CanvasLayer

const MENU_PRINCIPAL := "res://scenes/ui/main_menu.tscn"

var _root: Control = null
var _aviso: Label = null


func _ready() -> void:
	layer = 95   # por encima del HUD, por debajo del combate (100)
	process_mode = Node.PROCESS_MODE_ALWAYS   # tiene que funcionar con el juego en pausa

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.65)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.10, 0.97)
	sb.border_color = Color(0.87, 0.57, 0.26, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var tit := Label.new()
	tit.text = "PAUSA"
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tit.add_theme_font_size_override("font_size", 20)
	tit.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36))
	vb.add_child(tit)

	_aviso = Label.new()
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.add_theme_font_size_override("font_size", 12)
	_aviso.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	vb.add_child(_aviso)

	_boton(vb, "Reanudar", _cerrar)
	_boton(vb, "Multijugador (LAN)", _abrir_multi)
	_boton(vb, "Guardar", _guardar)
	_boton(vb, "Guardar y salir al menú", _guardar_y_salir)
	# SALIR SIN GUARDAR no existe en un MUNDO COMPARTIDO, y no es por gusto: el mundo es de varios y
	# lo que juegas no es solo tuyo. Salir sin guardar tiraria tu rato Y dejaria el mundo bloqueado a
	# tu nombre hasta que caducara el arrendamiento del cerrojo, o sea que tu compañero no podria
	# abrirlo en un buen rato. En las 3 ranuras de un jugador sigue donde estaba.
	if Mundos.abierto == "":
		_boton(vb, "Salir SIN guardar", _salir_sin_guardar)
	else:
		var n := Label.new()
		n.text = "En un mundo compartido siempre se guarda al salir."
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.custom_minimum_size = Vector2(260, 0)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.add_theme_font_size_override("font_size", 11)
		n.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
		vb.add_child(n)


func _boton(vb: VBoxContainer, txt: String, fn: Callable) -> void:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(260, 0)
	b.pressed.connect(fn)
	vb.add_child(b)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if (event as InputEventKey).keycode != KEY_ESCAPE:
		return
	# ESC dentro de OTRO menu lo CIERRA y no abre esto. La primera linea de defensa es que cada menu
	# consume la ESC en su _input (que corre antes que este _unhandled_input), asi que normalmente aqui
	# no llega nada; hay_modal() es el cinturon por si algun menu se olvida de consumirla. Y con un
	# combate o una extraccion delante, ESC no hace nada: ahi no se guarda.
	if not _root.visible and (Game.hay_pantalla_abierta() or Game.hay_modal()):
		return
	_set_open(not _root.visible)
	get_viewport().set_input_as_handled()


func _set_open(abierto: bool) -> void:
	_root.visible = abierto
	Game.fijar_modal(Game.Modal.SISTEMA, self, abierto)
	if abierto:
		_aviso.text = ""


func _cerrar() -> void:
	_set_open(false)


# Abre el panel de conexion LAN (multiplayer_panel.gd, hermano nuestro colgado del jugador).
# Cerramos la pausa primero: el panel trae su propio modal y su propio ESC.
func _abrir_multi() -> void:
	var panel: Node = get_tree().get_first_node_in_group("multiplayer_panel")
	if panel == null:
		_aviso.text = "No esta el panel de multijugador."
		return
	_set_open(false)
	panel.abrir()


# MULTIJUGADOR (hito 6 preventivo): guarda el HOST, y guarda POR LOS DOS. El invitado esta jugando en
# el mundo del host, asi que su partida no se puede volcar tal cual: Game.exportar_partida_invitado le
# devuelve lo del mundo (baul, mapa, bosses) a como estaba al entrar y le deja en SU pueblo. Solo lo
# dispara el host: dos saves autoritativos a la vez es justo el lio que el hito 6 viene a resolver.
func _guardar() -> void:
	# EL INVITADO TAMBIEN PUEDE. No guarda por su cuenta -- el mundo donde estais jugando es el del
	# host y hay que volcarlo tambien -- asi que se lo PIDE, y el host hace lo mismo que si hubiera
	# pulsado el boton el: se guarda, y de ahi salen los guardados de TODOS los invitados.
	if Net.activo and not Net.es_host:
		Net.pedir_guardar_todos()
		_aviso.text = "Guardando: se lo pides al anfitrión y quedáis todos a salvo."
		return
	# MUNDO COMPARTIDO: se guarda en el mundo, no en una ranura, y ademas se SUBE (sin soltar el
	# cerrojo) para que un cuelgue no se lleve la sesion.
	if Mundos.abierto != "":
		var subido: bool = await Mundos.autoguardar()
		_aviso.text = "Mundo guardado y al día." if subido \
			else "Guardado en tu disco, pero sin subir todavía."
		return
	var ok: bool = Perfil.guardar_actual()
	if ok and Net.activo:
		Net.guardar_todos()
		_aviso.text = "Partida guardada (y tus compañeros, a salvo en su pueblo)."
		return
	_aviso.text = "Partida guardada." if ok else "No se pudo guardar."


func _guardar_y_salir() -> void:
	# El invitado lo pide igual, pero con cerrando=true: el host guarda, cierra, y a cada invitado se
	# le devuelve a su mundo con lo recien guardado (el camino de _guardar_ahora ya estaba escrito).
	if Net.activo and not Net.es_host:
		# INVITADO EN UN MUNDO COMPARTIDO: mi personaje vive en ese mundo, asi que "salir" es dejarlo
		# guardado y volver al menu de multijugador -- no tengo pueblo propio al que ir. Se le pide al
		# anfitrion que guarde y se le da un respiro para que mi estado llegue antes de cortar.
		if Net.mundo_compartido:
			_aviso.text = "Guardando tu personaje en el mundo..."
			Net.pedir_guardar_todos()
			await get_tree().create_timer(1.0).timeout
			Game.limpiar_modales()
			Net.desconectar()
			get_tree().change_scene_to_file("res://scenes/ui/multi_menu.tscn")
			return
		Net.pedir_guardar_todos(true)
		_aviso.text = "Guardando y cerrando: se lo pides al anfitrión."
		return
	# MUNDO COMPARTIDO: guardar, subir y SOLTAR EL CERROJO, en ese orden. Si la subida falla el mundo
	# sigue reservado a mi nombre y queda marcado como pendiente: no se sale como si nada.
	# (cerrar_y_subir recoge antes el estado de los invitados y les avisa de que se cierra.)
	if Mundos.abierto != "":
		var r: Dictionary = await Mundos.cerrar_y_subir()
		if not r.get("ok", false):
			_aviso.text = "%s\nSe sale, pero el mundo queda pendiente de subir." % String(r.get("mensaje", ""))
			await get_tree().create_timer(1.5).timeout
		_salir()
		return
	if not Perfil.guardar_actual():
		_aviso.text = "No se pudo guardar (no se sale)."
		return
	# Cerrando la sesion: al invitado se le pide que guarde Y que se vuelva a su mundo con lo guardado
	# (si no, se comeria un "el host ha cerrado" a secas). Se ESPERA a que el aviso salga de verdad:
	# _salir() desconecta, y cortar en el mismo frame tiraria el paquete sin enviarlo.
	if Net.activo:
		await Net.guardar_todos(true)
	_salir()


func _salir_sin_guardar() -> void:
	_salir()


func _salir() -> void:
	# Despausar ANTES de cambiar de escena: si no, el menu principal nace con el arbol en
	# pausa y no responde a nada. Vaciamos la pila entera: el singleton Game persiste entre
	# escenas y no debe quedar ningun modal residual.
	Game.limpiar_modales()
	# Y si habia sesion de red, se cierra: el menu principal no es sitio para seguir conectado.
	if Net.activo:
		Net.desconectar()
	get_tree().change_scene_to_file(MENU_PRINCIPAL)
