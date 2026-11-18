# ============================================================
#  ajustes_alcance.gd  (VBoxContainer creado por codigo; Ajustes > Juego > «Personalizar ›»)
#  LOS CIRCULOS DE ALCANCE (18/11, su decision): APAGADOS DE SERIE; quien los quiera elige, por separado para sus
#  personajes y para los enemigos, cuando se ven (apagados / solo del turno / todos), el trazo (a rayas o a puntos, en
#  pixel), el color (libre) y su opacidad, el grosor, el largo de la raya y la separacion. Una MUESTRA pinta el aro
#  con la misma textura que el mapa (AroPixel): lo que se ve aqui es lo que sale en la pelea.
#  Quien manda es Preferencias: aqui solo se pinta lo suyo y se le dice lo que toca el jugador.
# ============================================================

extends VBoxContainer

const AroPixel = preload("res://scripts/fx/aro_pixel.gd")

const ANCHO := 420.0
const HUECO := 12.0
const MEDIO := (ANCHO - HUECO) / 2.0
const ALTO_MANDO := 40.0
const GRUPOS := [
	{"clave": "tuyos", "titulo": "Tus personajes"},
	{"clave": "enemigos", "titulo": "Enemigos"},
]
const DESLIZADORES := [
	{"clave": "opacidad", "titulo": "Opacidad", "unidad": " %"},
	{"clave": "tam", "titulo": "Grosor", "unidad": " px"},
	{"clave": "largo", "titulo": "Largo de la raya", "unidad": " px"},
	{"clave": "hueco", "titulo": "Separación", "unidad": " px"},
]

var grupo: String = "tuyos"
var _botones_grupo: Dictionary = {}
var _modo: OptionButton = null
var _trazo: OptionButton = null
var _color: ColorPickerButton = null
var _desl: Dictionary = {}    # clave -> HSlider
var _cifra: Dictionary = {}   # clave -> Label
var _caja_largo: Control = null
var _muestra: Control = null


func _ready() -> void:
	add_theme_constant_override("separation", 6)

	var tit := Label.new()
	tit.text = "Círculos de alcance"
	tit.add_theme_font_size_override("font_size", 15)
	tit.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36))
	add_child(tit)

	var fila_g := _doble()
	for g in GRUPOS:
		var b := Button.new()
		b.text = String(g["titulo"])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(MEDIO, 34)
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_elegir_grupo.bind(String(g["clave"])))
		fila_g.add_child(b)
		_botones_grupo[String(g["clave"])] = b

	var fila1 := _doble()
	_modo = _lista(fila1, "Visibilidad", Preferencias.MODOS_ALCANCE, func(id: int) -> void:
		Preferencias.fijar_alcance(grupo, "modo", id))
	_trazo = _lista(fila1, "Trazo", Preferencias.TRAZOS_ALCANCE, func(id: int) -> void:
		Preferencias.fijar_alcance(grupo, "trazo", id)
		_pintar())

	# COLOR y OPACIDAD juntos: son lo mismo visto de dos maneras.
	var fila2 := _doble()
	var caja_c := _caja(fila2, "Color")
	_color = ColorPickerButton.new()
	_color.edit_alpha = false   # la opacidad tiene su mando
	_color.custom_minimum_size = Vector2(MEDIO, ALTO_MANDO)
	_color.color_changed.connect(func(c: Color) -> void:
		Preferencias.fijar_alcance(grupo, "color", c, false)
		_muestra.queue_redraw())
	_color.popup_closed.connect(func() -> void: Preferencias.guardar_ajustes())
	caja_c.add_child(_color)
	_deslizador(fila2, DESLIZADORES[0])

	var fila3 := _doble()
	_deslizador(fila3, DESLIZADORES[1])
	_caja_largo = _deslizador(fila3, DESLIZADORES[2])
	var fila4 := _doble()
	_deslizador(fila4, DESLIZADORES[3])
	var restab := Button.new()
	restab.text = "Restablecer"
	restab.custom_minimum_size = Vector2(MEDIO, ALTO_MANDO)
	restab.size_flags_vertical = Control.SIZE_SHRINK_END
	restab.add_theme_font_size_override("font_size", 14)
	restab.pressed.connect(func() -> void:
		Preferencias.restablecer_alcance(grupo)
		_pintar())
	fila4.add_child(restab)

	# LA MUESTRA: el aro normal y el del turno, al doble (pixeles nitidos) sobre un suelo oscuro.
	_muestra = Control.new()
	_muestra.custom_minimum_size = Vector2(ANCHO, 74)
	_muestra.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_muestra.draw.connect(_pintar_muestra)
	add_child(_muestra)

	_elegir_grupo(grupo)


# Lo repinta todo con lo que tiene Preferencias (al abrir Ajustes y al cambiar de grupo).
func refrescar() -> void:
	_pintar()


func _elegir_grupo(g: String) -> void:
	grupo = g
	for k in _botones_grupo:
		var b: Button = _botones_grupo[k]
		b.set_pressed_no_signal(k == g)
		b.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36) if k == g else Color(0.62, 0.64, 0.70))
	_pintar()


func _pintar() -> void:
	var a: Dictionary = Preferencias.alcance[grupo]
	_modo.select(_modo.get_item_index(int(a["modo"])))
	_trazo.select(_trazo.get_item_index(int(a["trazo"])))
	_color.color = a["color"]
	for k in _desl:
		(_desl[k] as HSlider).set_value_no_signal(float(a[k]))
		_pintar_cifra(k)
	# A puntos no hay raya que medir.
	_caja_largo.modulate.a = 1.0 if int(a["trazo"]) == AroPixel.Trazo.RAYAS else 0.35
	(_desl["largo"] as HSlider).editable = int(a["trazo"]) == AroPixel.Trazo.RAYAS
	_muestra.queue_redraw()


func _pintar_cifra(k: String) -> void:
	var d: Dictionary = {}
	for x in DESLIZADORES:
		if x["clave"] == k:
			d = x
	(_cifra[k] as Label).text = "%d%s" % [int(Preferencias.alcance[grupo][k]), String(d.get("unidad", ""))]


func _pintar_muestra() -> void:
	var r := Rect2(Vector2.ZERO, _muestra.size)
	_muestra.draw_rect(r, Color(0.10, 0.10, 0.12))
	_muestra.draw_rect(r, Color(0.3, 0.32, 0.38), false, 1.0)
	var a: Dictionary = Preferencias.alcance[grupo]
	var enemigo: bool = grupo == "enemigos"
	const ESCALA := 2.0
	var tex: Texture2D = AroPixel.textura(12.0, int(a["trazo"]), int(a["tam"]), int(a["largo"]), int(a["hueco"]))
	var lado: Vector2 = Vector2(tex.get_width(), tex.get_height()) * ESCALA
	var fuente: Font = get_theme_default_font()
	for i in 2:
		var cx: float = _muestra.size.x * (0.27 + 0.46 * float(i))
		var centro := Vector2(cx, 6.0 + lado.y * 0.5)   # el aro arriba y su nombre debajo, sin pisarse
		_muestra.draw_texture_rect(tex, Rect2((centro - lado * 0.5).round(), lado), false,
			Preferencias.color_alcance(enemigo, i == 1))
		_muestra.draw_rect(Rect2(centro - Vector2(2, 2), Vector2(4, 4)), Color(0.8, 0.8, 0.85))
		var txt: String = "Normal" if i == 0 else "Del turno o apuntado"
		var w: float = fuente.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		_muestra.draw_string(fuente, Vector2(cx - w * 0.5, _muestra.size.y - 4.0), txt, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 11, Color(0.6, 0.63, 0.7))


# ------------------------------------------------------------
#  PIEZAS
# ------------------------------------------------------------
func _doble() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(HUECO))
	add_child(h)
	return h


func _caja(fila: Container, titulo: String) -> VBoxContainer:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(caja)
	var lbl := Label.new()
	lbl.text = titulo
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.82, 0.85, 0.9))
	caja.add_child(lbl)
	return caja


func _lista(fila: Container, titulo: String, modos: Array, al_elegir: Callable) -> OptionButton:
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(MEDIO, ALTO_MANDO)
	ob.add_theme_font_size_override("font_size", 14)
	for m in modos:
		ob.add_item(String(m["nombre"]), int(m["id"]))
	ob.item_selected.connect(func(i: int) -> void: al_elegir.call(ob.get_item_id(i)))
	_caja(fila, titulo).add_child(ob)
	return ob


func _deslizador(fila: Container, d: Dictionary) -> VBoxContainer:
	var k: String = String(d["clave"])
	var caja := _caja(fila, String(d["titulo"]))
	var linea := caja.get_child(0) as Label
	# La cifra a la derecha del titulo, como los volumenes.
	var h := HBoxContainer.new()
	caja.remove_child(linea)
	linea.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(linea)
	var cifra := Label.new()
	cifra.add_theme_font_size_override("font_size", 14)
	cifra.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
	h.add_child(cifra)
	caja.add_child(h)
	_cifra[k] = cifra
	var s := HSlider.new()
	s.min_value = float(Preferencias.ALCANCE_TOPES[k][0])
	s.max_value = float(Preferencias.ALCANCE_TOPES[k][1])
	s.step = 5.0 if k == "opacidad" else 1.0
	s.scrollable = false   # la rueda del raton baja la pagina (Juego va con scroll), no mueve el mando
	s.custom_minimum_size = Vector2(MEDIO, ALTO_MANDO - 8)
	# Mientras se arrastra se ve al momento (muestra y mapa) pero NO se escribe en disco; al soltar, si.
	s.value_changed.connect(func(v: float) -> void:
		Preferencias.fijar_alcance(grupo, k, roundi(v), false)
		_pintar_cifra(k)
		_muestra.queue_redraw())
	s.drag_ended.connect(func(cambiado: bool) -> void:
		if cambiado:
			Preferencias.guardar_ajustes())
	caja.add_child(s)
	_desl[k] = s
	return caja
