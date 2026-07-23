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
	_boton(vb, "Guardar", _guardar)
	_boton(vb, "Guardar y salir al menú", _guardar_y_salir)
	_boton(vb, "Salir SIN guardar", _salir_sin_guardar)


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
	# Si hay un combate o una extraccion abiertos, ESC no hace nada: ahi no se guarda.
	if Game.hay_pantalla_abierta() and not _root.visible:
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


func _guardar() -> void:
	_aviso.text = "Partida guardada." if Perfil.guardar_actual() else "No se pudo guardar."


func _guardar_y_salir() -> void:
	if Perfil.guardar_actual():
		_salir()
	else:
		_aviso.text = "No se pudo guardar (no se sale)."


func _salir_sin_guardar() -> void:
	_salir()


func _salir() -> void:
	# Despausar ANTES de cambiar de escena: si no, el menu principal nace con el arbol en
	# pausa y no responde a nada. Vaciamos la pila entera: el singleton Game persiste entre
	# escenas y no debe quedar ningun modal residual.
	Game.limpiar_modales()
	get_tree().change_scene_to_file(MENU_PRINCIPAL)
