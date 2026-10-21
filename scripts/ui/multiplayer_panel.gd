# ============================================================
#  multiplayer_panel.gd  (CanvasLayer creada por codigo desde el jugador, como el pause_menu)
#  Panel de CONEXION multijugador LAN (hito 1): hostear una partida o unirse a una por IP,
#  con un codigo de sala que hace de contraseña. Se abre desde el menu de pausa (ESC).
#
#  La IP puede ser la de tu LAN de casa (192.168.x.x) o la de una LAN virtual (Hamachi/
#  Tailscale/ZeroTier): para el juego es lo mismo. Interfaz placeholder por codigo, como todas.
# ============================================================

extends CanvasLayer

var _root: Control = null
var _ip: LineEdit = null
var _codigo: LineEdit = null
var _estado: Label = null


func _ready() -> void:
	layer = 96   # por encima del menu de pausa (95): se abre DESDE el
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("multiplayer_panel")   # el pause_menu me encuentra por aqui
	Net.estado_cambiado.connect(_on_estado)

	# LA INTERFAZ SE MONTA AL ABRIRLO (_construir): el jugador crea este menu en CADA escena y montarlo eran ~1,4 ms
	# de cada cambio de escena (medido 16/10).


var _construido := false

func _construir() -> void:
	if _construido:
		return
	_construido = true
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
	sb.border_color = Color(0.45, 0.65, 0.95, 0.7)   # azul: que se distinga de la pausa
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
	tit.text = "MULTIJUGADOR (LAN)"
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tit.add_theme_font_size_override("font_size", 20)
	tit.add_theme_color_override("font_color", Color(0.55, 0.75, 0.98))
	vb.add_child(tit)

	_estado = Label.new()
	_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_estado.add_theme_font_size_override("font_size", 12)
	_estado.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	_estado.custom_minimum_size = Vector2(280, 0)
	_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_estado)

	_ip = _campo(vb, "IP del host (para unirse)", "127.0.0.1")
	_codigo = _campo(vb, "Codigo de sala", "")

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)
	_boton(hb, "Hostear", _hostear)
	_boton(hb, "Unirse", _unirse)

	_boton(vb, "Desconectar", _desconectar)
	_boton(vb, "Cerrar", cerrar)


func _campo(vb: VBoxContainer, etiqueta: String, valor: String) -> LineEdit:
	var l := Label.new()
	l.text = etiqueta
	l.add_theme_font_size_override("font_size", 12)
	vb.add_child(l)
	var le := LineEdit.new()
	le.text = valor
	le.custom_minimum_size = Vector2(260, 0)
	vb.add_child(le)
	return le


func _boton(caja: BoxContainer, txt: String, fn: Callable) -> void:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(120, 0)
	b.pressed.connect(fn)
	caja.add_child(b)


func abrir() -> void:
	_construir()
	_root.visible = true
	Game.fijar_modal(Game.Modal.SISTEMA, self, true)
	_refrescar_estado_inicial()


func cerrar() -> void:
	if _root == null:
		return   # sin montar: nunca se abrio
	_root.visible = false
	Game.fijar_modal(Game.Modal.SISTEMA, self, false)


# ¿Estoy en MI partida, que lleva mi sala? (paso 5: toda partida va por la sala.) Entonces "Hostear" es abrirla a la
# LAN y "Unirse" es salir de ella para entrar en la de otro.
func _en_mi_partida() -> bool:
	return Net.activo and not Net.es_host and Mundos.uniendome.begins_with(Mundos.PREFIJO_RANURA)


func _refrescar_estado_inicial() -> void:
	if _en_mi_partida():
		_estado.text = ("Tu partida está abierta a la LAN." if Net.lan_abierta
			else "Pon un código y pulsa Hostear para que tus amigos de casa entren en tu partida.")
	elif Net.activo:
		_estado.text = "Sesion en marcha (%s)." % ("host" if Net.es_host else "cliente")
	else:
		_estado.text = "Sin conexion. Unete a una partida por IP."


func _hostear() -> void:
	if _en_mi_partida():
		var cod: String = _codigo.text.strip_edges()
		if cod == "":
			_estado.text = "Pon un código: es la contraseña que tendrán que escribir tus amigos."
			return
		_estado.text = "Abriendo tu partida a la LAN..."
		Net.abrir_lan(cod)
		return
	# Paso 7: tu juego ya no hace de anfitrion. Solo se abre a la LAN TU partida, que la lleva tu sala.
	_estado.text = ("Ya hay una sesion en marcha. Desconecta primero." if Net.activo
		else "Para abrir a la LAN, entra en tu partida desde el menu principal.")


func _unirse() -> void:
	var ip := _ip.text.strip_edges()
	if ip.is_empty():
		_estado.text = "Pon la IP del host."
		return
	if _en_mi_partida():
		# Para entrar en la de otro hay que salir de la mia: se guarda (lo hace mi sala) y se sigue en la pantalla de
		# multijugador, que es la que sabe hacerte un personaje si ese mundo no te conoce.
		_estado.text = "Guardando tu partida..."
		await Ventana.pedir_guardado_al_anfitrion()
		await get_tree().create_timer(0.2).timeout
		Mundos.union_ip = {"ip": ip, "codigo": _codigo.text.strip_edges()}
		cerrar()
		Game.limpiar_modales()
		Net.desconectar()
		get_tree().change_scene_to_file(Mundos.MENU_MULTI)
		return
	if Net.activo:
		_estado.text = "Ya hay una sesion en marcha. Desconecta primero."
		return
	Net.unirse(ip, _codigo.text.strip_edges())


func _desconectar() -> void:
	if _en_mi_partida():
		Net.abrir_lan("")   # en mi partida no me desconecto de mi sala: se cierra la puerta a la LAN
		return
	if not Net.activo:
		_estado.text = "No hay sesion que cerrar."
		return
	Net.desconectar()
	_estado.text = "Desconectado."


func _on_estado(texto: String) -> void:
	if _estado != null:
		_estado.text = texto


func _unhandled_input(event: InputEvent) -> void:
	# ESC cierra el panel si esta abierto (y se traga el evento para no abrir la pausa debajo).
	if _root == null or not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		cerrar()
		get_viewport().set_input_as_handled()
