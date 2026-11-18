# ============================================================
#  settings_menu.gd  (Control creado por codigo)
#  Los AJUSTES, en APARTADOS: SONIDO (los tres volumenes), GRAFICOS (modo de pantalla, vsync, limite de FPS, mostrar
#  FPS y brillo) y JUEGO (como se
#  escriben los numeros: las cifras de las fichas y los decimales; ver Preferencias; y los CIRCULOS DE ALCANCE del mapa
#  tactico, ajustes_alcance.gd). Un apartado que no cabe en el alto del panel (Juego, con los circulos) va con
#  SCROLL: el panel no crece y no se sale de la pantalla.
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
const HudEstilo = preload("res://scripts/ui/hud_estilo.gd")

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
	{"clave": "juego", "titulo": "Juego"},
]
# LOS QUE VAN CON SCROLL (su contenido es mas alto que el panel).
const CON_SCROLL := ["juego"]
# Alto fijo del cuerpo: lo que ocupa el apartado MAS ALTO (se mide al montarlos, ver _ready). Sin esto, el panel
# encoge al cambiar de pestaña y el boton de Volver salta de sitio bajo el dedo.
var _cuerpo: Control = null

var _cifras: Dictionary = {}   # clave -> Label del porcentaje
var _pantalla: OptionButton = null   # el selector de modo de ventana
var _vsync: CheckButton = null
var _limite_fps: OptionButton = null
var _resolucion: OptionButton = null
var _resoluciones: Array = []   # las de la lista, en su orden (Vector2i)
var _mostrar_fps: CheckButton = null
var _brillo: HSlider = null
var _cifra_brillo: Label = null
var _cifras_fichas: OptionButton = null   # porcentaje / numero / los dos
var _decimales: OptionButton = null       # enteros / 1 decimal / por defecto
var _ej_cifras: Label = null   # el ejemplo de debajo de cada lista: se ve lo que hace sin ir a buscarlo
var _ej_decimales: Label = null
var _alcance: VBoxContainer = null   # los circulos de alcance (ajustes_alcance.gd)
var _marcos: Dictionary = {}   # clave de apartado -> lo que se enseña/esconde (la caja, o su ScrollContainer)
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
	panel.add_theme_stylebox_override("panel", HudEstilo.a_pixel(sb, true))
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
	_cuerpo = cuerpo
	vb.add_child(cuerpo)
	for a in APARTADOS:
		var clave: String = String(a["clave"])
		var caja := VBoxContainer.new()
		caja.add_theme_constant_override("separation", 10)
		if CON_SCROLL.has(clave):
			var sc := ScrollContainer.new()
			sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sc.add_child(caja)
			cuerpo.add_child(sc)
			_marcos[clave] = sc
		else:
			caja.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			cuerpo.add_child(caja)
			_marcos[clave] = caja
		_cuerpos[clave] = caja

	for m in MANDOS:
		_fila(_cuerpos["sonido"], String(m["clave"]), String(m["titulo"]))

	_fila_pantalla(_cuerpos["graficos"])
	_fila_vsync(_cuerpos["graficos"])
	# Limite de FPS y Mostrar FPS en la misma fila: los dos son del contador de fotogramas.
	var fila_fps := _doble(_cuerpos["graficos"])
	_limite_fps = _fila_lista(fila_fps, "Límite de FPS", Ventana.LIMITES_FPS, Ventana.limite_fps,
		func(id: int) -> void: Ventana.aplicar_limite_fps(id), MEDIO)
	var caja_fps := VBoxContainer.new()
	caja_fps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja_fps.add_theme_constant_override("separation", 2)
	fila_fps.add_child(caja_fps)
	var tit_fps := Label.new()
	tit_fps.text = "Mostrar FPS"
	tit_fps.add_theme_font_size_override("font_size", 15)
	tit_fps.add_theme_color_override("font_color", Color(0.82, 0.85, 0.9))
	caja_fps.add_child(tit_fps)
	_mostrar_fps = CheckButton.new()
	_mostrar_fps.text = "También con F3"
	_mostrar_fps.custom_minimum_size = Vector2(MEDIO, ALTO_MANDO + 8)
	_mostrar_fps.add_theme_font_size_override("font_size", 15)
	_mostrar_fps.button_pressed = Ventana.mostrar_fps
	_mostrar_fps.toggled.connect(func(on: bool) -> void: Ventana.aplicar_mostrar_fps(on))
	caja_fps.add_child(_mostrar_fps)
	_fila_brillo(_cuerpos["graficos"])

	_cifras_fichas = _fila_lista(_cuerpos["juego"], "Cifras de habilidades y hechizos",
		Preferencias.MODOS_CIFRAS, AbilityData.modo_cifras, func(id: int) -> void:
			Preferencias.fijar_modo_cifras(id)
			_pintar_ejemplos())
	_ej_cifras = _pista(_cuerpos["juego"])
	_decimales = _fila_lista(_cuerpos["juego"], "Decimales de barras, registro y golpes",
		Preferencias.MODOS_DECIMALES, Preferencias.decimales, func(id: int) -> void:
			Preferencias.fijar_decimales(id)
			_pintar_ejemplos())
	_ej_decimales = _pista(_cuerpos["juego"])
	_pintar_ejemplos()
	_alcance = preload("res://scripts/ui/ajustes_alcance.gd").new()
	_cuerpos["juego"].add_child(_alcance)

	# EL ALTO del cuerpo = el del apartado mas alto (Graficos, hoy).
	var alto: float = 0.0
	# (los de scroll no cuentan: se ajustan a este alto y lo que sobra se recorre)
	for k in _marcos:
		alto = maxf(alto, (_marcos[k] as Control).get_combined_minimum_size().y)
	_cuerpo.custom_minimum_size = Vector2(ANCHO, alto)

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

	# MODO Y RESOLUCION EN LA MISMA FILA (17/11): la resolucion va al lado porque depende del modo (solo en Ventana; en
	# las otras manda el monitor). En columna, Graficos llenaba la pantalla de alto.
	var fila := _doble(caja)
	_pantalla = _fila_lista(fila, "Pantalla", Ventana.MODOS, Ventana.modo, func(id: int) -> void:
		Ventana.aplicar(id)
		_pintar_resolucion(), MEDIO)
	_resoluciones = Ventana.resoluciones_que_caben()
	var nombres: Array = []
	for i in _resoluciones.size():
		var r: Vector2i = _resoluciones[i]
		nombres.append({"id": i, "nombre": "%d × %d" % [r.x, r.y]})
	_resolucion = _fila_lista(fila, "Resolución", nombres, -1, func(id: int) -> void:
		Ventana.aplicar_resolucion(_resoluciones[id]), MEDIO)
	_pintar_resolucion()

	var pista := Label.new()
	pista.text = "La resolución solo se elige en modo Ventana; en las otras se usa la del monitor. F11: pantalla completa."
	pista.custom_minimum_size = Vector2(ANCHO, 0)
	pista.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pista.add_theme_font_size_override("font_size", 11)
	pista.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
	caja.add_child(pista)


# La resolucion que toca en la lista: la elegida o, si nunca se eligio, la del tamaño de la ventana ahora. Apagada fuera
# del modo Ventana.
func _pintar_resolucion() -> void:
	if _resolucion == null:
		return
	var actual: Vector2i = Ventana.resolucion
	if actual.x <= 0:
		actual = DisplayServer.window_get_size()
	var idx: int = _resoluciones.find(actual)
	_resolucion.select(idx)   # -1 = ninguna marcada (un tamaño a mano que no esta en la lista)
	_resolucion.disabled = Ventana.modo != Ventana.Modo.VENTANA


# EL BRILLO: un mando como los del volumen, del 50 al 150 %. Se ve al arrastrar y se guarda al soltar.
func _fila_brillo(vb: VBoxContainer) -> void:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	vb.add_child(caja)
	var linea := HBoxContainer.new()
	caja.add_child(linea)
	var lbl := Label.new()
	lbl.text = "Brillo"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.82, 0.85, 0.9))
	linea.add_child(lbl)
	_cifra_brillo = Label.new()
	_cifra_brillo.add_theme_font_size_override("font_size", 15)
	_cifra_brillo.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
	linea.add_child(_cifra_brillo)
	_brillo = HSlider.new()
	_brillo.min_value = Ventana.BRILLO_MIN * 100.0
	_brillo.max_value = Ventana.BRILLO_MAX * 100.0
	_brillo.step = 5.0
	_brillo.value = Ventana.brillo * 100.0
	_brillo.custom_minimum_size = Vector2(ANCHO, ALTO_MANDO)
	caja.add_child(_brillo)
	_brillo.value_changed.connect(func(v: float) -> void:
		Ventana.fijar_brillo(v / 100.0)
		_pintar_brillo())
	_brillo.drag_ended.connect(func(cambiado: bool) -> void:
		if cambiado:
			Ventana.guardar_ajustes())
	_pintar_brillo()


func _pintar_brillo() -> void:
	if _cifra_brillo != null:
		_cifra_brillo.text = "%d %%" % roundi(Ventana.brillo * 100.0)


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
	pista.text = "Evita el desgarro de pantalla. Desactívala si el juego va a tirones."
	pista.custom_minimum_size = Vector2(ANCHO, 0)
	pista.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pista.add_theme_font_size_override("font_size", 11)
	pista.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
	vb.add_child(pista)


# UNA LISTA DE OPCIONES con su titulo (los ajustes de Juego). 'modos' = [{id, nombre}]; al elegir se llama a
# 'al_elegir' con el id, que es lo que se guarda.
# 'ancho' = MEDIO cuando va en una fila doble (_doble).
func _fila_lista(vb: Container, titulo: String, modos: Array, actual: int, al_elegir: Callable,
		ancho: float = ANCHO) -> OptionButton:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # en una fila doble, las dos medias llegan al borde
	vb.add_child(caja)

	var lbl := Label.new()
	lbl.text = titulo
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.82, 0.85, 0.9))
	caja.add_child(lbl)

	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(ancho, ALTO_MANDO + 8)
	ob.add_theme_font_size_override("font_size", 15)
	for m in modos:
		ob.add_item(String(m["nombre"]), int(m["id"]))
	ob.select(ob.get_item_index(actual))
	ob.item_selected.connect(func(i: int) -> void: al_elegir.call(ob.get_item_id(i)))
	caja.add_child(ob)
	return ob


# UNA FILA DE DOS MEDIAS (Graficos): dos ajustes cortos lado a lado.
const HUECO_DOBLE := 12.0
const MEDIO := (ANCHO - HUECO_DOBLE) / 2.0

func _doble(vb: Container) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(HUECO_DOBLE))
	vb.add_child(h)
	return h


func _pista(vb: VBoxContainer) -> Label:
	var l := Label.new()
	l.custom_minimum_size = Vector2(ANCHO, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
	vb.add_child(l)
	return l


# LOS EJEMPLOS de la pestaña Juego, con las mismas funciones que pintan de verdad: si el ejemplo dice una cosa, la
# ficha y la barra dicen esa misma.
func _pintar_ejemplos() -> void:
	if _ej_cifras != null:
		_ej_cifras.text = "Ej.: «Inflige %s.»" % AbilityData.cuanto_txt(2.0, 24.0,
			"del Ataque de quien la usa", "como Daño Físico")
	if _ej_decimales != null:
		_ej_decimales.text = "Ej.: vida %s · golpe de %s" % [Preferencias.barra("%.2f / %.2f", 198.84, 199.9),
			Preferencias.fijo(34.62, 2)]


# Cambia de apartado: se enseña su caja y su pestaña se enciende.
func _ir_a(clave: String) -> void:
	_apartado = clave
	for k in _marcos:
		(_marcos[k] as Control).visible = (k == clave)
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
	_pintar_resolucion()
	if _vsync != null:
		_vsync.set_pressed_no_signal(Ventana.vsync)
	if _limite_fps != null:
		_limite_fps.select(_limite_fps.get_item_index(Ventana.limite_fps))
	if _mostrar_fps != null:
		_mostrar_fps.set_pressed_no_signal(Ventana.mostrar_fps)   # F3 lo puede haber cambiado por fuera
	if _brillo != null:
		_brillo.set_value_no_signal(Ventana.brillo * 100.0)
		_pintar_brillo()
	if _cifras_fichas != null:
		_cifras_fichas.select(_cifras_fichas.get_item_index(AbilityData.modo_cifras))
	if _decimales != null:
		_decimales.select(_decimales.get_item_index(Preferencias.decimales))
	_pintar_ejemplos()
	if _alcance != null:
		_alcance.refrescar()


func cerrar() -> void:
	visible = false
	# Cinturon: si alguien cambio algo con el teclado (las flechas mueven el mando sin arrastrar y
	# por tanto sin drag_ended), aqui no se pierde.
	Sonido.guardar_ajustes()
	Ventana.guardar_ajustes()   # el brillo movido con el teclado, igual que los volumenes
	Preferencias.guardar_ajustes()   # y los mandos de los circulos de alcance
	cerrado.emit()
