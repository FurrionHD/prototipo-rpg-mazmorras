# ============================================================
#  ajustes_circulo.gd  (VBoxContainer creado por codigo; lo monta ajustes_alcance.gd, uno por circulo o area)
#  LOS MANDOS DE UN CIRCULO del mapa tactico, atados a una clave de Preferencias.alcance:
#   - de ALCANCE ("tuyos" / "enemigos"): visibilidad (apagados / solo del turno / todos), trazo a rayas o a puntos,
#     color, opacidad, grosor, largo de la raya, separacion;
#   - de MOVIMIENTO ("mov_tuyos" / "mov_enemigos"): visible u oculto, trazo continuo / rayas / puntos, color, opacidad
#     del borde y del relleno, grosor, largo de la raya, separacion;
#   - de AREA DE ATAQUE ("area_apunte" / "area_mapa" / "area_enemigos") y de NUCLEO ("nucleo_tuyos" /
#     "nucleo_enemigos"): como el de movimiento pero sin Visibilidad (siempre se ven) y con LATIDO.
#  Con su Restablecer y una MUESTRA pintada con la misma textura que el mapa (AroPixel).
#  Quien manda es Preferencias: aqui solo se pinta lo suyo y se le dice lo que toca el jugador.
# ============================================================

extends VBoxContainer

const AroPixel = preload("res://scripts/fx/aro_pixel.gd")
const FormasPixel = preload("res://scripts/fx/formas_pixel.gd")

const ANCHO := 420.0
const HUECO := 12.0
const MEDIO := (ANCHO - HUECO) / 2.0
const ALTO_MANDO := 40.0

var clave: String = "tuyos"   # la de Preferencias.alcance
var titulo: String = ""
var movimiento: bool = false
var area: bool = false      # area de ataque o nucleo
var nucleo: bool = false
var enemigo: bool = false

var _modo: OptionButton = null
var _trazo: OptionButton = null
var _color: ColorPickerButton = null
var _latido: CheckButton = null
var _desl: Dictionary = {}    # clave -> HSlider
var _cifra: Dictionary = {}   # clave -> Label
var _caja: Dictionary = {}    # clave -> la caja del deslizador (para atenuarla)
var _muestra: Control = null


# DESLIZADORES: [clave, titulo, unidad]
func _deslizadores() -> Array:
	if movimiento or area:
		return [["opacidad", "Opacidad del borde", " %"], ["relleno", "Opacidad del relleno", " %"],
			["tam", "Grosor", " px"], ["largo", "Largo de la raya", " px"], ["hueco", "Separación", " px"]]
	return [["opacidad", "Opacidad", " %"], ["tam", "Grosor", " px"], ["largo", "Largo de la raya", " px"],
		["hueco", "Separación", " px"]]


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	movimiento = clave.begins_with("mov_")
	nucleo = clave.begins_with("nucleo_")
	area = clave.begins_with("area_") or nucleo
	enemigo = clave.ends_with("enemigos")

	var tit := Label.new()
	tit.text = titulo
	tit.add_theme_font_size_override("font_size", 14)
	tit.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36))
	add_child(tit)

	# Las piezas, de dos en dos por fila, en este orden.
	var piezas: Array = []
	if not area:   # las areas siempre se ven
		piezas.append(func(fila: Container) -> void:
			_modo = _lista(fila, "Visibilidad", Preferencias.MODOS_MOVIMIENTO if movimiento else Preferencias.MODOS_ALCANCE,
				func(id: int) -> void: Preferencias.fijar_alcance(clave, "modo", id)))
	piezas.append(func(fila: Container) -> void:
		_trazo = _lista(fila, "Trazo", Preferencias.TRAZOS_MOVIMIENTO if movimiento or area else Preferencias.TRAZOS_ALCANCE,
			func(id: int) -> void:
				Preferencias.fijar_alcance(clave, "trazo", id)
				_pintar()))
	piezas.append(func(fila: Container) -> void: _color = _boton_color(_caja_titulo(fila, "Color")))
	for d in _deslizadores():
		piezas.append(func(fila: Container) -> void: _deslizador(fila, d[0], d[1], d[2]))
	if area:
		piezas.append(func(fila: Container) -> void:
			_latido = CheckButton.new()
			_latido.text = "Latido del borde"
			_latido.custom_minimum_size = Vector2(MEDIO, ALTO_MANDO)
			_latido.size_flags_vertical = Control.SIZE_SHRINK_END
			_latido.add_theme_font_size_override("font_size", 14)
			_latido.toggled.connect(func(on: bool) -> void: Preferencias.fijar_alcance(clave, "latido", on))
			fila.add_child(_latido))
	piezas.append(func(fila: Container) -> void:
		var restab := Button.new()
		restab.text = "Restablecer"
		restab.custom_minimum_size = Vector2(MEDIO, ALTO_MANDO)
		restab.size_flags_vertical = Control.SIZE_SHRINK_END
		restab.add_theme_font_size_override("font_size", 14)
		restab.pressed.connect(func() -> void:
			Preferencias.restablecer_alcance(clave)
			_pintar())
		fila.add_child(restab))
	var fila: HBoxContainer = null
	for i in piezas.size():
		if i % 2 == 0:
			fila = HBoxContainer.new()
			fila.add_theme_constant_override("separation", int(HUECO))
			add_child(fila)
		(piezas[i] as Callable).call(fila)

	# LA MUESTRA, al doble (pixeles nitidos) sobre un suelo oscuro.
	_muestra = Control.new()
	_muestra.custom_minimum_size = Vector2(ANCHO, 74)
	_muestra.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_muestra.draw.connect(_pintar_muestra)
	add_child(_muestra)
	_pintar()


func refrescar() -> void:
	_pintar()


func _pintar() -> void:
	var a: Dictionary = Preferencias.alcance[clave]
	if _modo != null:
		_modo.select(_modo.get_item_index(int(a["modo"])))
	if _latido != null:
		_latido.set_pressed_no_signal(bool(a.get("latido", false)))
	_trazo.select(_trazo.get_item_index(int(a["trazo"])))
	_color.color = a["color"]
	for k in _desl:
		(_desl[k] as HSlider).set_value_no_signal(float(a[k]))
		_pintar_cifra(k)
	# Sin rayas no hay raya que medir; con trazo continuo, tampoco separacion.
	_atenuar("largo", int(a["trazo"]) == AroPixel.Trazo.RAYAS)
	_atenuar("hueco", int(a["trazo"]) != AroPixel.Trazo.CONTINUO)
	_muestra.queue_redraw()


func _atenuar(k: String, activo: bool) -> void:
	(_caja[k] as Control).modulate.a = 1.0 if activo else 0.35
	(_desl[k] as HSlider).editable = activo


func _pintar_cifra(k: String) -> void:
	var unidad: String = ""
	for d in _deslizadores():
		if d[0] == k:
			unidad = d[2]
	(_cifra[k] as Label).text = "%d%s" % [int(Preferencias.alcance[clave][k]), unidad]


func _pintar_muestra() -> void:
	var r := Rect2(Vector2.ZERO, _muestra.size)
	_muestra.draw_rect(r, Color(0.10, 0.10, 0.12))
	_muestra.draw_rect(r, Color(0.3, 0.32, 0.38), false, 1.0)
	if area:
		_muestra_area()
		return
	var a: Dictionary = Preferencias.alcance[clave]
	const ESCALA := 2.0
	var tex: Texture2D = AroPixel.textura(12.0, int(a["trazo"]), int(a["tam"]), int(a["largo"]), int(a["hueco"]))
	var lado: Vector2 = Vector2(tex.get_width(), tex.get_height()) * ESCALA
	var fuente: Font = get_theme_default_font()
	# El de alcance: el normal y el del turno o el apuntado. El de movimiento: uno, con su relleno.
	var cuantos: int = 1 if movimiento else 2
	for i in cuantos:
		var cx: float = _muestra.size.x * (0.5 if cuantos == 1 else 0.27 + 0.46 * float(i))
		var centro := Vector2(cx, 6.0 + lado.y * 0.5)   # el aro arriba y su nombre debajo, sin pisarse
		var rect := Rect2((centro - lado * 0.5).round(), lado)
		if movimiento:
			_muestra.draw_texture_rect(AroPixel.disco(12.0), rect, false, Preferencias.color_movimiento(enemigo, true))
			_muestra.draw_texture_rect(tex, rect, false, Preferencias.color_movimiento(enemigo))
		else:
			_muestra.draw_texture_rect(tex, rect, false, Preferencias.color_alcance(enemigo, i == 1))
		_muestra.draw_rect(Rect2(centro - Vector2(2, 2), Vector2(4, 4)), Color(0.8, 0.8, 0.85))
		var txt: String = "Círculo de movimiento" if movimiento else \
			("Círculo normal" if i == 0 else "Círculo del turno o del apuntado")
		var w: float = fuente.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		_muestra.draw_string(fuente, Vector2(cx - w * 0.5, _muestra.size.y - 4.0), txt, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 11, Color(0.6, 0.63, 0.7))


# LA MUESTRA DE UN AREA: un cono de verdad (con sus cuñas) o, el nucleo, su aro con relleno; al doble, en pixel.
func _muestra_area() -> void:
	var a: Dictionary = Preferencias.alcance[clave]
	var cols: Array = Preferencias.colores_area(clave)
	const ESCALA := 2.0
	var c := Vector2(_muestra.size.x * 0.5, 32.0)
	_muestra.draw_set_transform((c - Vector2(0, 0)).round(), 0.0, Vector2(ESCALA, ESCALA))
	if nucleo:
		_muestra.draw_circle(Vector2.ZERO, 10.0, cols[1])
		FormasPixel.arco(_muestra, Vector2.ZERO, 10.0, 0.0, TAU, cols[0], a)
	else:
		var f = CombatFormas.cono(Vector2(-14, 0), Vector2.RIGHT, 30.0, 50.0)   # de lado: cabe entero en la muestra
		f.cunas = 3
		FormasPixel.dibujar(f, _muestra, cols[0], cols[1], a)
	_muestra.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var fuente: Font = get_theme_default_font()
	var txt: String = "Núcleo" if nucleo else "Área de ataque"
	var w: float = fuente.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	_muestra.draw_string(fuente, Vector2(c.x - w * 0.5, _muestra.size.y - 4.0), txt, HORIZONTAL_ALIGNMENT_LEFT,
		-1, 11, Color(0.6, 0.63, 0.7))


# ------------------------------------------------------------
#  PIEZAS
# ------------------------------------------------------------
func _caja_titulo(fila: Container, texto: String) -> VBoxContainer:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(caja)
	var lbl := Label.new()
	lbl.text = texto
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.82, 0.85, 0.9))
	caja.add_child(lbl)
	return caja


func _lista(fila: Container, texto: String, modos: Array, al_elegir: Callable) -> OptionButton:
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(MEDIO, ALTO_MANDO)
	ob.add_theme_font_size_override("font_size", 14)
	for m in modos:
		ob.add_item(String(m["nombre"]), int(m["id"]))
	ob.item_selected.connect(func(i: int) -> void: al_elegir.call(ob.get_item_id(i)))
	_caja_titulo(fila, texto).add_child(ob)
	return ob


func _boton_color(caja: Container) -> ColorPickerButton:
	var b := ColorPickerButton.new()
	b.edit_alpha = false   # la opacidad tiene su mando
	b.custom_minimum_size = Vector2(MEDIO, ALTO_MANDO)
	b.color_changed.connect(func(c: Color) -> void:
		Preferencias.fijar_alcance(clave, "color", c, false)
		_muestra.queue_redraw())
	b.popup_closed.connect(func() -> void: Preferencias.guardar_ajustes())
	caja.add_child(b)
	return b


func _deslizador(fila: Container, k: String, texto: String, _unidad: String) -> void:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(caja)
	_caja[k] = caja
	# La cifra a la derecha del titulo, como los volumenes.
	var h := HBoxContainer.new()
	caja.add_child(h)
	var lbl := Label.new()
	lbl.text = texto
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.82, 0.85, 0.9))
	h.add_child(lbl)
	var cifra := Label.new()
	cifra.add_theme_font_size_override("font_size", 14)
	cifra.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
	h.add_child(cifra)
	_cifra[k] = cifra
	var s := HSlider.new()
	s.min_value = float(Preferencias.ALCANCE_TOPES[k][0])
	s.max_value = float(Preferencias.ALCANCE_TOPES[k][1])
	s.step = 5.0 if k == "opacidad" else 1.0
	s.scrollable = false   # la rueda del raton baja la pagina (Juego va con scroll), no mueve el mando
	s.custom_minimum_size = Vector2(MEDIO, ALTO_MANDO - 8)
	# Mientras se arrastra se ve al momento (muestra y mapa) pero NO se escribe en disco; al soltar, si.
	s.value_changed.connect(func(v: float) -> void:
		Preferencias.fijar_alcance(clave, k, roundi(v), false)
		_pintar_cifra(k)
		_muestra.queue_redraw())
	s.drag_ended.connect(func(cambiado: bool) -> void:
		if cambiado:
			Preferencias.guardar_ajustes())
	caja.add_child(s)
	_desl[k] = s
