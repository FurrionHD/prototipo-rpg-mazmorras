# ============================================================
#  keys_help.gd  (CanvasLayer creada por el jugador, como el HUD/debug)
#  Muestra en pantalla TODAS las teclas de debug + los controles basicos,
#  para builds de PRUEBA que reparte el usuario a testers. Se oculta/muestra
#  con F1 (para que no estorbe al grabar o hacer capturas).
# ============================================================

extends CanvasLayer

const DEBUG_KEYS := [
	["U", "Recalcular stats visibles"],
	["H", "Curar vida y maná al 100%"],
	["R", "Respawn (recargar la sala)"],
	["T", "Arena de pruebas (sandbox vacío + spawner)"],
	["K", "Cambiar arma principal"],
	["L", "Cambiar mano secundaria (arma/escudo/varita)"],
	["J", "Cambiar armadura (categoría)"],
	["DEBUG", "Botón abajo-izq: panel (stats, enemigo, armas,"],
	["", "armadura, piso, MUÑECO DPS/pegador, mejoras)"],
	["Spawner", "En la sandbox: clic izq coloca enemigo / der quita"],
]
const CONTROLS := [
	["WASD / flechas", "Mover"],
	["Shift", "Correr"],
	["Ctrl", "Sigilo (andar despacio)"],
	["Espacio", "Atacar"],
	["F", "Interactuar (puertas, altar, loot)"],
	["I", "Inventario"],
]

var _panel: PanelContainer = null


func _ready() -> void:
	layer = 90   # por debajo del combate (100) pero encima del mundo
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_panel.offset_left = 8
	_panel.offset_top = 8
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.82)
	sb.border_color = Color(0.87, 0.57, 0.26, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	_panel.add_child(vb)

	_titulo(vb, "TECLAS DE DEBUG  (build de prueba)")
	for par in DEBUG_KEYS:
		_linea(vb, par[0], par[1])
	_sep(vb)
	_titulo(vb, "CONTROLES")
	for par in CONTROLS:
		_linea(vb, par[0], par[1])
	_sep(vb)
	_hint(vb, "F1 — ocultar / mostrar esta ayuda")

	add_child(_panel)


func _titulo(vb: VBoxContainer, txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36))
	l.add_theme_font_size_override("font_size", 13)
	vb.add_child(l)


func _linea(vb: VBoxContainer, tecla: String, desc: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = tecla
	k.custom_minimum_size = Vector2(110, 0)
	k.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	k.add_theme_font_size_override("font_size", 12)
	row.add_child(k)
	var d := Label.new()
	d.text = desc
	d.add_theme_color_override("font_color", Color(0.86, 0.88, 0.92))
	d.add_theme_font_size_override("font_size", 12)
	row.add_child(d)
	vb.add_child(row)


func _sep(vb: VBoxContainer) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, 6)
	vb.add_child(s)


func _hint(vb: VBoxContainer, txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
	l.add_theme_font_size_override("font_size", 11)
	vb.add_child(l)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_F1:
		_panel.visible = not _panel.visible
