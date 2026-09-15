# ============================================================
#  desarrollo_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  SELECTOR de habilidad de desarrollo al SUBIR DE NIVEL. Lo abre el menu del altar cuando
#  puede_subir_nivel(). Eliges 1 (o ninguna); Esc = APLAZAR (sigues con el nivel actual para farmear
#  un poco mas). Elegir llama Game.subir_nivel(id).
#
#  EL REPARTO es el de los menus nuevos: el nivel en la columna izquierda, las disponibles en una
#  rejilla de tarjetas en el centro (con su scroll) y la elegida en la ficha de la derecha, con los
#  dos botones.
#
#  Antes eran Buttons con el texto de dos lineas y autowrap. Un Button con autowrap NO le pide al
#  contenedor el alto que ocupa su texto, asi que con muchas disponibles los botones se pisaban, se
#  salian por arriba y por abajo, y el scroll no se enteraba de que habia algo que desplazar. Por eso
#  la tarjeta tiene ahora un ALTO FIJO y el texto largo se va a la ficha.
# ============================================================

extends CanvasLayer

const AMBAR := Color(0.95, 0.72, 0.36)
const GRIS := Color(0.6, 0.63, 0.7)
const ANCHO_FICHA := 360.0
const ALTO_TARJETA := 78.0
const LADO_ICONO := 30.0

var _root: Control = null
var _lista: VBoxContainer = null
var _content: VBoxContainer = null
var _side: VBoxContainer = null
var _titulo_nivel: Label = null
var _sel: int = 0


func _ready() -> void:
	layer = 95   # por encima del menu del altar
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para: hay que seguir respondiendo
	add_to_group("desarrollo_menu")
	var m: Dictionary = MenuScaffold.construir(self, "SUBIR DE NIVEL", "", _cerrar, false, true)
	_root = m["root"]
	_lista = m["lista"]
	_content = m["content"]
	_side = m["side"]
	(m["aviso"] as Control).visible = false

	var scroll: ScrollContainer = m["lista_scroll"]
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_horizontal = Control.SIZE_FILL
	_content.custom_minimum_size = Vector2(ANCHO_FICHA, 0)
	(_content.get_parent() as ScrollContainer).size_flags_horizontal = Control.SIZE_FILL
	(_content.get_parent() as ScrollContainer).custom_minimum_size = Vector2(ANCHO_FICHA, 0)

	var lateral: BoxContainer = _side.get_parent()
	(lateral.get_child(0) as Control).visible = false
	var titulo := VBoxContainer.new()
	titulo.add_theme_constant_override("separation", 0)
	var chico := Label.new()
	chico.text = "Subir de nivel"
	chico.add_theme_font_size_override("font_size", 11)
	chico.add_theme_color_override("font_color", GRIS)
	titulo.add_child(chico)
	_titulo_nivel = Label.new()
	_titulo_nivel.add_theme_font_size_override("font_size", 20)
	_titulo_nivel.add_theme_color_override("font_color", AMBAR)
	titulo.add_child(_titulo_nivel)
	lateral.add_child(titulo)
	lateral.move_child(titulo, 0)


# 'desde_altar' = al cerrar (elijas o aplaces) se vuelve al altar en vez de al mapa: vienes de ahi, y
# soltarte en el mundo te obligaba a darle otra vez a la F para ver como te habia quedado.
var _desde_altar := false

func abrir(desde_altar: bool = false) -> void:
	if Game.debug_panel_open:
		return
	_sel = 0
	_desde_altar = desde_altar
	_root.visible = true
	Game.abrir_menu(self)   # para el mundo entero mientras el menu esta abierto
	_rebuild()


func _cerrar() -> void:
	_root.visible = false
	Game.cerrar_menu(self)
	if _desde_altar:
		_desde_altar = false
		var altar: Node = get_tree().get_first_node_in_group("altar_menu")
		if altar != null and altar.has_method("volver"):
			altar.volver()


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_cerrar()
			get_viewport().set_input_as_handled()


# Guardia de REENTRADA. Un _rebuild puede entrar mientras otro esta a medias (el focus_exited de un
# stepper al liberarlo, las señales de red, un _on_* que espera en un await), y entonces el de dentro
# pinta su panel y el de fuera apila el suyo debajo: el menu salia DUPLICADO. Es el mismo guardia que
# lleva el herrero desde que se cazo alli.
var _reconstruyendo := false

func _rebuild() -> void:
	if _reconstruyendo:
		return
	_reconstruyendo = true
	_rebuild_real()
	_reconstruyendo = false


func _rebuild_real() -> void:
	MenuScaffold.vaciar(_lista)
	MenuScaffold.vaciar(_content)
	MenuScaffold.vaciar(_side)

	_titulo_nivel.text = "NIVEL %d → %d" % [Game.player_level, Game.player_level + 1]
	MenuScaffold.nota(_side, "Tu poder se graba en tu base (+%d%%) y las básicas vuelven a rango I."
		% roundi(Game.NIVEL_SPIKE * 100.0))
	MenuScaffold.nota(_side, "Esc: volver al altar sin subir." if _desde_altar
		else "Esc: aplazar la subida.")

	var disp: Array = Game.desarrollos_disponibles()
	if disp.is_empty():
		MenuScaffold.titulo(_lista, "Nada que aprender todavía", 15)
		MenuScaffold.nota(_lista, "Las que ya tienes siguen subiendo de rango solas. Puedes ascender igual.")
		MenuScaffold.titulo(_content, "Sin habilidad nueva", 18)
		_botones("")
		return

	_sel = clampi(_sel, 0, disp.size() - 1)
	MenuScaffold.titulo(_lista, "Elige una habilidad de desarrollo", 15)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_child(g)
	for i in disp.size():
		g.add_child(_tarjeta(disp[i], i == _sel, i))

	# LA FICHA de la elegida: aqui si cabe el texto entero.
	var d: Dictionary = disp[_sel]
	MenuScaffold.titulo(_content, str(d["nombre"]), 20)
	MenuScaffold.titulo(_content, _tipo(d), 12, GRIS)
	_content.add_child(HSeparator.new())
	var desc := Label.new()
	desc.text = str(d["desc"])
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.86, 0.88, 0.93))
	_content.add_child(desc)
	MenuScaffold.nota(_content, "Empieza en rango I y sube sola (I → S) haciendo lo suyo. Es permanente.")
	_botones(str(d["id"]))


func _tipo(d: Dictionary) -> String:
	return "Oficio" if str(d["tipo"]) == "oficio" else "Combate"


# Los dos botones de la ficha: aprender la elegida y ascender, o ascender sin aprender nada (no te
# quedas atascado si ninguna te convence o ninguna esta lista).
func _botones(id: String) -> void:
	var hueco := Control.new()
	hueco.custom_minimum_size = Vector2(0, 14)
	_content.add_child(hueco)
	var acc := VBoxContainer.new()
	acc.add_theme_constant_override("separation", 8)
	_content.add_child(acc)
	if id != "":
		var b: Button = MenuScaffold.pastilla(acc, "Aprender y subir de nivel", _elegir.bind(id))
		b.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)
	var b2: Button = MenuScaffold.pastilla(acc, "Subir sin habilidad nueva", _elegir.bind(""),
		id == "")
	b2.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)
	# APLAZAR a la vista, y no solo con Esc o la ✕: sin un boton, lo unico que se ve para salir es la
	# ✕ de la esquina, y esa parece "cerrar todo" aunque te devuelva al altar.
	var hueco2 := Control.new()
	hueco2.custom_minimum_size = Vector2(0, 6)
	acc.add_child(hueco2)
	var b3 := Button.new()
	b3.text = "← Volver al altar sin subir" if _desde_altar else "← Aplazar la subida"
	b3.flat = true
	b3.add_theme_color_override("font_color", GRIS)
	b3.add_theme_color_override("font_hover_color", Color(0.94, 0.95, 0.98))
	b3.add_theme_font_size_override("font_size", 13)
	b3.pressed.connect(_cerrar)
	acc.add_child(b3)


# UNA TARJETA: icono del tipo, nombre, tipo y la descripcion recortada a una linea. Alto FIJO (ver la
# cabecera): el texto entero esta en la ficha de la derecha.
func _tarjeta(d: Dictionary, elegida: bool, i: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, ALTO_TARJETA)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_contents = true
	b.tooltip_text = str(d["desc"])
	for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
	b.pressed.connect(_pick.bind(i))
	var oficio: bool = str(d["tipo"]) == "oficio"
	var dibujo := Callable(Iconos, "engranaje" if oficio else "espada")
	b.draw.connect(func() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.13, 0.14, 0.19) if elegida else Color(0.08, 0.09, 0.12)
		if b.is_hovered() and not elegida:
			sb.bg_color = Color(0.11, 0.12, 0.16)
		sb.border_color = AMBAR if elegida else Color(1, 1, 1, 0.12)
		sb.set_border_width_all(2 if elegida else 1)
		sb.set_corner_radius_all(10)
		b.draw_style_box(sb, Rect2(Vector2.ZERO, b.size))
		dibujo.call(b, Vector2(14, (b.size.y - LADO_ICONO) * 0.5), LADO_ICONO,
			AMBAR if elegida else MenuScaffold.TAB_APAGADA))
	b.mouse_entered.connect(b.queue_redraw)
	b.mouse_exited.connect(b.queue_redraw)

	# El texto en Labels (que se recortan con puntos suspensivos) colgados de un contenedor anclado
	# al boton. Ignoran el raton para que el clic llegue al boton.
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 14.0 + LADO_ICONO + 14.0
	vb.offset_right = -10.0
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 0)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(vb)
	vb.add_child(_etiqueta(str(d["nombre"]), 15, AMBAR if elegida else Color(0.92, 0.93, 0.97)))
	vb.add_child(_etiqueta(_tipo(d), 11, GRIS))
	vb.add_child(_etiqueta(str(d["desc"]), 12, Color(0.72, 0.75, 0.82)))
	return b


func _etiqueta(txt: String, tam: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", col)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _pick(i: int) -> void:
	if i == _sel:
		return
	_sel = i
	_rebuild()


func _elegir(id: String) -> void:
	var subio: bool = Game.subir_nivel(id)
	if subio:
		print("[desarrollo] Subes de nivel eligiendo ", id)
	_cerrar()   # si venias del altar, esto ya lo ha vuelto a abrir
	# Refrescar el menu del altar si sigue vivo (para que muestre el nuevo nivel / el antes-despues).
	var altar: Node = get_tree().get_first_node_in_group("altar_menu")
	if subio and altar != null and altar.has_method("mostrar_subida"):
		altar.mostrar_subida(id)
