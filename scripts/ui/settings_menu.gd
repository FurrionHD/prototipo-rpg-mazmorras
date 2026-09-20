# ============================================================
#  settings_menu.gd  (Control creado por codigo)
#  Los AJUSTES, en APARTADOS: SONIDO (los tres volumenes) y GRAFICOS (modo de pantalla y vsync).
#  Se abren desde el menu del titulo, desde la pausa y desde el combate. Los apartados existen
#  desde que hay mas de una clase de ajuste: una lista seguida de volumenes y pantallas mezclados
#  no se lee, y ahi tiene que caber lo que venga despues (idioma, controles) sin mover nada.
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

# Lo que suena al soltar el mando, para oir como queda. La MUSICA no lleva muestra y no le hace
# falta: ya esta sonando: mover el mando se oye solo.
const MUESTRA := {"general": true, "efectos": true, "musica": false}

# LOS APARTADOS, en el orden de la fila de pestañas.
const APARTADOS := [
	{"clave": "sonido", "titulo": "Sonido"},
	{"clave": "graficos", "titulo": "Gráficos"},
]
# Alto fijo del cuerpo: lo que ocupa el apartado mas alto (los tres volumenes). Sin esto, el panel
# encoge al cambiar a Graficos y el boton de Volver salta de sitio bajo el dedo.
const ALTO_CUERPO := 236.0

var _cifras: Dictionary = {}   # clave -> Label del porcentaje
var _pantalla: OptionButton = null   # el selector de modo de ventana
var _vsync: CheckButton = null
var _cuerpos: Dictionary = {}   # clave de apartado -> VBoxContainer
var _pestanas: Dictionary = {}  # clave de apartado -> Button
var _apartado: String = "sonido"


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

	# LA FILA DE PESTAÑAS. Dos botones del mismo ancho: el del apartado abierto va en ambar y el otro
	# apagado, que es como se distinguen en el resto de menus del juego.
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	vb.add_child(fila)
	for a in APARTADOS:
		var clave: String = String(a["clave"])
		var b := Button.new()
		b.text = String(a["titulo"])
		b.custom_minimum_size = Vector2((ANCHO - 6.0) / float(APARTADOS.size()), 44.0)
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(_ir_a.bind(clave))
		fila.add_child(b)
		_pestanas[clave] = b

	# EL CUERPO: los dos apartados montados a la vez, y se enseña uno. Montarlos al vuelo obligaria a
	# rehacer los mandos cada vez que se cambia de pestaña, y con ellos el estado que ya tienen.
	var cuerpo := Control.new()
	cuerpo.custom_minimum_size = Vector2(ANCHO, ALTO_CUERPO)
	vb.add_child(cuerpo)
	for a in APARTADOS:
		var caja := VBoxContainer.new()
		caja.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		caja.add_theme_constant_override("separation", 10)
		cuerpo.add_child(caja)
		_cuerpos[String(a["clave"])] = caja

	for m in MANDOS:
		_fila(_cuerpos["sonido"], String(m["clave"]), String(m["titulo"]))

	_fila_pantalla(_cuerpos["graficos"])
	_fila_vsync(_cuerpos["graficos"])

	_ir_a(_apartado)

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


# EL MODO DE PANTALLA. No es un mando de 0 a 100 como los volumenes, asi que no cabe en _fila: es
# una lista de tres. Lo que elijas se aplica al momento y se recuerda en user://ajustes.cfg, el
# mismo sitio donde viven los volumenes (ver Ventana).
func _fila_pantalla(vb: VBoxContainer) -> void:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	vb.add_child(caja)

	var lbl := Label.new()
	lbl.text = "Pantalla"
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.82, 0.85, 0.9))
	caja.add_child(lbl)

	_pantalla = OptionButton.new()
	_pantalla.custom_minimum_size = Vector2(ANCHO, ALTO_MANDO + 8)
	_pantalla.add_theme_font_size_override("font_size", 15)
	for m in Ventana.MODOS:
		_pantalla.add_item(String(m["nombre"]), int(m["id"]))
	_pantalla.select(_pantalla.get_item_index(Ventana.modo))
	_pantalla.item_selected.connect(func(i: int) -> void:
		Ventana.aplicar(_pantalla.get_item_id(i)))
	caja.add_child(_pantalla)

	var pista := Label.new()
	pista.text = "F11 alterna pantalla completa en cualquier momento."
	pista.add_theme_font_size_override("font_size", 11)
	pista.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
	caja.add_child(pista)


# SINCRONIZACION VERTICAL. Interruptor y no lista: son dos estados y no hay termino medio.
func _fila_vsync(vb: VBoxContainer) -> void:
	_vsync = CheckButton.new()
	_vsync.text = "Sincronización vertical"
	_vsync.custom_minimum_size = Vector2(ANCHO, ALTO_MANDO + 8)
	_vsync.add_theme_font_size_override("font_size", 15)
	_vsync.button_pressed = Ventana.vsync
	_vsync.toggled.connect(func(on: bool) -> void: Ventana.aplicar_vsync(on))
	vb.add_child(_vsync)

	var pista := Label.new()
	pista.text = "Quita el desgarro de la imagen. Apágala si el juego va a tirones."
	pista.custom_minimum_size = Vector2(ANCHO, 0)
	pista.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pista.add_theme_font_size_override("font_size", 11)
	pista.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
	vb.add_child(pista)


# Cambia de apartado: se enseña su caja y su pestaña se enciende.
func _ir_a(clave: String) -> void:
	_apartado = clave
	for k in _cuerpos:
		(_cuerpos[k] as Control).visible = (k == clave)
	for k in _pestanas:
		var b: Button = _pestanas[k]
		b.add_theme_color_override("font_color",
			Color(0.95, 0.72, 0.36) if k == clave else Color(0.62, 0.64, 0.70))


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
	# Y lo de Gráficos, que se puede haber cambiado por fuera (F11) con este panel escondido.
	if _pantalla != null:
		_pantalla.select(_pantalla.get_item_index(Ventana.modo))
	if _vsync != null:
		_vsync.set_pressed_no_signal(Ventana.vsync)


func cerrar() -> void:
	visible = false
	# Cinturon: si alguien cambio algo con el teclado (las flechas mueven el mando sin arrastrar y
	# por tanto sin drag_ended), aqui no se pierde.
	Sonido.guardar_ajustes()
	cerrado.emit()
