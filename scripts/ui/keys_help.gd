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
	["P", "Tirar 200 veces la tabla de spawns y contar (consola)"],
	["B", "Forzar un brote en la zona más cercana"],
	["DEBUG", "Botón abajo-izq: panel (stats, enemigo, armas,"],
	["", "armadura, piso, MUÑECO DPS/pegador, mejoras)"],
	["Spawner", "En la sandbox: clic izq coloca enemigo / der quita"],
]
const CONTROLS := [
	["WASD / flechas", "Mover"],
	["Shift", "Correr"],
	["Ctrl", "Sigilo (andar despacio)"],
	["ESPACIO", "Atacar al enemigo que tengas enfrente (entra en combate)"],
	["F", "Interactuar (puertas, escaleras, altar, tienda, cadáveres, loot)"],
	["ESC", "Pausa: guardar / guardar y salir"],
	["I", "Inventario"],
	["C", "Menú de personaje (stats / armas / armadura)"],
]

var _root: Control = null       # backdrop + panel; se muestra/oculta como un todo
var _panel: PanelContainer = null


func _ready() -> void:
	layer = 90   # por debajo del combate (100) pero encima del mundo
	# El panel debe seguir procesando (input, boton de cerrar) aunque pausemos el juego.
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Raiz a pantalla completa: un fondo oscuro modal + el panel centrado. Arranca
	# OCULTA para no interrumpir el juego; se abre con F1 (y entonces pausa).
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

	# Fondo oscuro que atenua el juego y bloquea los clics al mundo de detras.
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(backdrop)

	# Centrador a pantalla completa: coloca el panel en el centro exacto.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	_panel = PanelContainer.new()
	center.add_child(_panel)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.95)
	sb.border_color = Color(0.87, 0.57, 0.26, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	_panel.add_child(vb)

	# Cabecera: titulo a la izquierda y boton de cerrar (X) a la derecha.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	var htit := Label.new()
	htit.text = "TECLAS DE DEBUG  (build de prueba)"
	htit.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36))
	htit.add_theme_font_size_override("font_size", 13)
	htit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(htit)
	var cerrar := Button.new()
	cerrar.text = "✕ Cerrar"
	cerrar.pressed.connect(_cerrar)
	header.add_child(cerrar)
	vb.add_child(header)
	_sep(vb)

	for par in DEBUG_KEYS:
		_linea(vb, par[0], par[1])
	_sep(vb)
	_titulo(vb, "CONTROLES")
	for par in CONTROLS:
		_linea(vb, par[0], par[1])
	_sep(vb)
	_hint(vb, "F1 / ✕ Cerrar — cerrar y reanudar el juego")

	# Al ARRANCAR el juego se abre sola (una vez): el tester ve de entrada que teclas tiene.
	# A partir de ahi, solo con F1. La marca vive en Game porque este panel se reconstruye en
	# cada escena y si no volveria a saltar al cruzar cada puerta.
	if not Game.ayuda_mostrada:
		Game.ayuda_mostrada = true
		_set_open(true)


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
		_set_open(not _root.visible)


func _cerrar() -> void:
	_set_open(false)


# Abre/cierra la ayuda. Mientras esta abierta, el juego queda PAUSADO.
func _set_open(open: bool) -> void:
	_root.visible = open
	get_tree().paused = open
