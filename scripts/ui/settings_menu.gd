# ============================================================
#  settings_menu.gd  (Control creado por codigo)
#  Los AJUSTES. Hoy son los tres volumenes -- general, efectos y musica -- y esta pensado para que
#  quepa lo que venga despues (idioma, pantalla, controles) sin mover nada de sitio.
#
#  Va SUELTO y no metido dentro del menu de pausa a proposito: el mismo panel tiene que poder
#  colgarse del menu principal el dia que se le meta ahi, y duplicarlo seria tener dos sitios donde
#  cambiar el volumen que tarde o temprano se contestan distinto.
#
#  QUIEN MANDA de verdad es Sonido: aqui solo se pinta lo que el ya sabe (Sonido.volumen) y se le
#  dice lo que toca el jugador (Sonido.fijar_volumen). En disco se escribe al SOLTAR el mando, no
#  mientras se arrastra, o seria un fichero por pixel.
#  Interfaz placeholder por codigo; el arte va al final.
# ============================================================

extends Control

signal cerrado

# Los mismos 420x56 que los botones de la pausa: con el pulgar, un mando fino es una loteria.
const ANCHO := 420.0
const ALTO_MANDO := 40.0

# COMO SE LLAMAN PARA EL JUGADOR. Las claves son las de Sonido.BUSES; el orden es el de aqui, y va
# de lo general a lo concreto porque es como se busca ("bajar el volumen" antes que "bajar la
# musica").
const MANDOS := [
	{"clave": "general", "titulo": "Volumen general"},
	{"clave": "efectos", "titulo": "Efectos de sonido"},
	{"clave": "musica", "titulo": "Música"},
]

# Lo que suena al soltar el mando, para oir como queda. La musica no tiene muestra: cuando la haya,
# se le pone aqui.
const MUESTRA := {"general": true, "efectos": true, "musica": false}

var _cifras: Dictionary = {}   # clave -> Label del porcentaje


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Con el juego en pausa los mandos tienen que seguir respondiendo (ver menus-pausan-el-juego).
	process_mode = Node.PROCESS_MODE_ALWAYS

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.10, 0.97)
	sb.border_color = Color(0.87, 0.57, 0.26, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 42
	sb.content_margin_right = 42
	sb.content_margin_top = 32
	sb.content_margin_bottom = 32
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var tit := Label.new()
	tit.text = "AJUSTES"
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tit.add_theme_font_size_override("font_size", 28)
	tit.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36))
	vb.add_child(tit)

	for m in MANDOS:
		_fila(vb, String(m["clave"]), String(m["titulo"]))

	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 8)
	vb.add_child(sep)

	var volver := Button.new()
	volver.text = "Volver"
	volver.custom_minimum_size = Vector2(ANCHO, 56)
	volver.add_theme_font_size_override("font_size", 17)
	volver.pressed.connect(cerrar)
	vb.add_child(volver)


func _fila(vb: VBoxContainer, clave: String, titulo: String) -> void:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	vb.add_child(caja)

	# El nombre y la cifra en la misma linea: el numero al lado del titulo se lee de un vistazo sin
	# tener que interpretar donde cae la barra.
	var linea := HBoxContainer.new()
	caja.add_child(linea)

	var lbl := Label.new()
	lbl.text = titulo
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.82, 0.85, 0.9))
	linea.add_child(lbl)

	var cifra := Label.new()
	cifra.add_theme_font_size_override("font_size", 15)
	cifra.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
	linea.add_child(cifra)
	_cifras[clave] = cifra

	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 100.0
	s.step = 1.0
	s.value = Sonido.volumen(clave) * 100.0
	s.custom_minimum_size = Vector2(ANCHO, ALTO_MANDO)
	caja.add_child(s)
	# Mientras se arrastra: se oye al momento pero NO se escribe en disco.
	s.value_changed.connect(_mover.bind(clave))
	# Al soltar: se guarda, y suena una muestra para oir como ha quedado.
	s.drag_ended.connect(_soltar.bind(clave))
	_pintar_cifra(clave)


func _mover(v: float, clave: String) -> void:
	Sonido.fijar_volumen(clave, v / 100.0)
	_pintar_cifra(clave)


func _soltar(cambiado: bool, clave: String) -> void:
	if not cambiado:
		return
	Sonido.guardar_ajustes()
	if bool(MUESTRA.get(clave, false)):
		Sonido.muestra()


func _pintar_cifra(clave: String) -> void:
	var lbl: Label = _cifras.get(clave)
	if lbl != null:
		var v: int = roundi(Sonido.volumen(clave) * 100.0)
		lbl.text = "Silencio" if v <= 0 else "%d %%" % v


func abrir() -> void:
	visible = true
	# Se repintan las cifras al abrir por si el volumen lo movio otro sitio (el menu principal, por
	# ejemplo) mientras este panel estaba escondido.
	for m in MANDOS:
		_pintar_cifra(String(m["clave"]))


func cerrar() -> void:
	visible = false
	# Cinturon: si alguien cambio algo con el teclado (las flechas mueven el mando sin arrastrar y
	# por tanto sin drag_ended), aqui no se pierde.
	Sonido.guardar_ajustes()
	cerrado.emit()
