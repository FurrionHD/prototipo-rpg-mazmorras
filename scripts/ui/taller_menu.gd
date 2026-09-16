# ============================================================
#  taller_menu.gd  --  la BASE de las pantallas de oficio con la cara del inventario.
#
#  La peleteria, la boticaria/cocina y la herreria/carpinteria tienen la MISMA forma: pestañas con
#  icono arriba, a la izquierda QUIÉN TRABAJA + una fila de filtros + la rejilla de celdas, y a la
#  derecha la ficha con su scroll, la linea de aviso y el pie fijo de botones. Estaba copiada en cada
#  una (la regla del rework era un menu cada vez); con la herreria, la cuarta, sube aqui.
#
#  Cada taller EXTIENDE este archivo y pone lo suyo:
#    - en _ready: montar(sitio, nombres, iconos, ancho_rejilla, ancho_ficha)
#    - _pintar(): lo que se pinta en cada repintado (llamando a grid_detail, anchos, pintar_artesanos...)
#    - opcionales: _al_cerrar(), _al_cambiar_pantalla(), _al_elegir_otra()
#
#  El repintado cuenta el baul UNA vez (Game.abrir_recuento_hogar): con el mundo lleno del usuario
#  (19.000 materiales) contarlo en cada pregunta costaba mas de un segundo por pestaña.
# ============================================================
extends CanvasLayer

const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const ROJO := Color(0.9, 0.5, 0.5)
const GRIS := Color(0.6, 0.63, 0.7)

# De mejor a peor (el enum de calidad NO esta ordenado: PURO se añadio al final).
const CALIDADES := [MaterialItem.Calidad.PURO, MaterialItem.Calidad.INTACTO,
	MaterialItem.Calidad.NORMAL, MaterialItem.Calidad.DANADO]

# Las mismas medidas que el inventario y la tienda.
const LADO_CELDA := 96.0
const ANCHO_FICHA := 360.0
const ANCHO_REJILLA_MIN := 420.0

var _root: Control = null
var _header: VBoxContainer = null
var _lista: VBoxContainer = null      # la rejilla de celdas (columna izquierda)
var _scroll_lista: ScrollContainer = null
var _content: VBoxContainer = null    # la ficha (columna derecha)
var _scroll_det: ScrollContainer = null
var _col_der: VBoxContainer = null
var _acciones: VBoxContainer = null   # bajo la ficha y FUERA de su scroll: siempre a la vista
var _contador_lbl: Label = null
var _aviso_lbl: Label = null
var _titulo_seccion: Label = null
var _tab_buttons: Array = []
# La fila de FILTROS encima de la rejilla. La rellena cada pantalla; vacia, desaparece.
var barra_sub: HBoxContainer = null
# QUIÉN TRABAJA: la fila de retratos (ver Game.artesano).
var _fila_artesano: HBoxContainer = null
var _fila_artesano_rotulo: Label = null

var _tab: int = 0
var sel: int = 0             # celda elegida en la rejilla
var stacks: Array = []       # lo pintado en la rejilla, en el mismo orden que las celdas
var _aviso: String = ""
var _aviso_ok: bool = true
# El oficio de quien se esta eligiendo en la fila de retratos ("" = la fila no elige artesano).
var _oficio_artesano: String = ""


# ============================================================
#  MONTAJE
# ============================================================

# 'sitio' = el nombre del taller ("Peletería"), que va en pequeño encima de la seccion. 'nombres' e
# 'iconos' = las pestañas de arriba, en paralelo.
func montar(sitio: String, nombres: Array, iconos: Array, ancho_rejilla: float = ANCHO_REJILLA_MIN,
		ancho_ficha: float = ANCHO_FICHA) -> void:
	layer = 91
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para: hay que seguir respondiendo

	# MULTI: refresco en vivo cuando el compañero toca el baul o su reserva.
	if Net.has_signal("hogar_cambiado"):
		Net.hogar_cambiado.connect(_on_cambio_externo)
	if Net.has_signal("reservas_cambiadas"):
		Net.reservas_cambiadas.connect(_on_cambio_externo)

	# El SITIO, no la persona: aqui no hay nadie trabajando por ti, lo haces tu con tus personajes.
	var m: Dictionary = MenuScaffold.construir(self, sitio.to_upper(), "", _cerrar, false, false)
	_root = m["root"]
	_header = m["header"]
	_lista = m["lista"]
	_content = m["content"]
	# FUERA la cabecera entera (linea de aviso + header): aunque vacias reservaban su alto y dejaban
	# un palmo muerto entre la barra de arriba y la rejilla. El aviso se muda a la columna de la ficha.
	((m["aviso"] as Control).get_parent().get_parent() as Control).visible = false

	var scroll: ScrollContainer = m["lista_scroll"]
	_scroll_lista = scroll
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_horizontal = Control.SIZE_FILL
	var scroll_det: ScrollContainer = _content.get_parent() as ScrollContainer
	scroll_det.size_flags_horizontal = Control.SIZE_FILL
	scroll.resized.connect(_on_lista_redimensionada)
	# Y la LISTA de dentro, que se coloca DESPUES que su scroll: mirando solo el scroll, al abrir se
	# media la lista aun sin ancho y salian 4 columnas estiradas que ya no se corregian.
	_lista.resized.connect(_on_lista_redimensionada)

	# LA COLUMNA DERECHA: la ficha con su scroll y, DEBAJO Y FUERA DEL SCROLL, las acciones.
	var split_der: BoxContainer = scroll_det.get_parent()
	split_der.remove_child(scroll_det)
	_col_der = VBoxContainer.new()
	_col_der.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_col_der.add_theme_constant_override("separation", 6)
	split_der.add_child(_col_der)
	_scroll_det = scroll_det
	_col_der.add_child(scroll_det)
	scroll_det.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_aviso_lbl = Label.new()
	_aviso_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aviso_lbl.add_theme_font_size_override("font_size", 13)
	_col_der.add_child(_aviso_lbl)
	_acciones = VBoxContainer.new()
	_acciones.add_theme_constant_override("separation", 4)
	_col_der.add_child(_acciones)

	# LA COLUMNA IZQUIERDA: quien trabaja, la fila de filtros y la rejilla.
	var split: BoxContainer = scroll.get_parent()
	split.remove_child(scroll)
	var col_izq := VBoxContainer.new()
	col_izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_izq.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_izq.add_theme_constant_override("separation", 6)
	split.add_child(col_izq)
	split.move_child(col_izq, 0)
	# QUIÉN TRABAJA: la misma pieza que el menu de personaje y el altar (MenuScaffold.fila_retratos).
	# Va aqui y no en la cabecera porque la cabecera esta oculta, y aqui queda al lado de lo que se elige.
	var rotulo := Label.new()
	rotulo.text = "QUIÉN TRABAJA"
	rotulo.add_theme_font_size_override("font_size", 11)
	rotulo.add_theme_color_override("font_color", MenuScaffold.GRIS)
	_fila_artesano_rotulo = rotulo
	col_izq.add_child(rotulo)
	_fila_artesano = MenuScaffold.fila_retratos(col_izq)

	barra_sub = HBoxContainer.new()
	barra_sub.alignment = BoxContainer.ALIGNMENT_CENTER
	barra_sub.add_theme_constant_override("separation", 14)
	col_izq.add_child(barra_sub)
	col_izq.add_child(scroll)

	# LAS PESTAÑAS, con icono y centradas en la pantalla.
	var barra_tabs: HBoxContainer = m["side"]
	barra_tabs.add_theme_constant_override("separation", 14)
	for i in nombres.size():
		var b: Button = MenuScaffold.pestana_icono(String(iconos[i]), String(nombres[i]))
		b.pressed.connect(_on_tab.bind(i))
		barra_tabs.add_child(b)
		_tab_buttons.append(b)

	var barra: BoxContainer = barra_tabs.get_parent()
	(barra.get_child(0) as Control).visible = false
	# EL TITULO EN DOS LINEAS: el taller pequeño y gris encima del nombre de la seccion, grande.
	var titulo := VBoxContainer.new()
	titulo.add_theme_constant_override("separation", 0)
	var chico := Label.new()
	chico.text = sitio
	chico.add_theme_font_size_override("font_size", 11)
	chico.add_theme_color_override("font_color", MenuScaffold.GRIS)
	titulo.add_child(chico)
	_titulo_seccion = Label.new()
	_titulo_seccion.add_theme_font_size_override("font_size", 20)
	_titulo_seccion.add_theme_color_override("font_color", AMBAR)
	titulo.add_child(_titulo_seccion)
	barra.add_child(titulo)
	barra.move_child(titulo, 1)

	barra.remove_child(barra_tabs)
	var centrador := CenterContainer.new()
	centrador.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	centrador.offset_top = 16.0
	centrador.offset_bottom = 16.0 + MenuScaffold.LADO_ICONO
	centrador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(centrador)
	centrador.add_child(barra_tabs)

	# EL CONTADOR, arriba a la derecha (lo que tienes guardado, la carga que llevas, el dinero).
	_contador_lbl = Label.new()
	_contador_lbl.add_theme_font_size_override("font_size", 15)
	_contador_lbl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.90))
	barra.add_child(_contador_lbl)
	barra.move_child(_contador_lbl, barra.get_child_count() - 2)

	anchos(ancho_rejilla, ancho_ficha)


# EL REPARTO DEL ANCHO entre la rejilla (que se estira) y la ficha. Puede cambiar con la pestaña.
func anchos(rejilla: float, ficha: float) -> void:
	for c in [_col_der, _scroll_det, _content]:
		(c as Control).custom_minimum_size.x = ficha
	_scroll_lista.custom_minimum_size.x = rejilla


# ============================================================
#  ABRIR / CERRAR
# ============================================================

# Deja el menu abierto y pintado. Devuelve false si no se puede abrir ahora (combate, panel de debug).
func abrir_taller() -> bool:
	if Game._active_layer != null or Game.debug_panel_open:
		return false
	sel = 0
	_aviso = ""
	_root.visible = true
	Game.abrir_menu(self)   # para el mundo entero mientras el menu esta abierto
	_rebuild()
	return true


func _cerrar() -> void:
	_root.visible = false
	_al_cerrar()
	Game.cerrar_menu(self)
	if Net.activo:
		Net.hogar.liberar_mis_reservas()


func _al_cerrar() -> void:
	pass


func _on_cambio_externo() -> void:
	if _root != null and _root.visible:
		_rebuild()


func ocupado() -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_toast"):
		hud.mostrar_toast("Un momento: tu compañero está creando algo justo ahora.")


func _input(event: InputEvent) -> void:
	if _root == null or not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_cerrar()
			get_viewport().set_input_as_handled()


func _on_tab(i: int) -> void:
	if i == _tab:
		return
	_tab = i
	cambiar_pantalla()


# Lo que se enseña ha cambiado (pestaña, filtro): la celda elegida ya no vale.
func cambiar_pantalla() -> void:
	sel = 0
	_aviso = ""
	_al_cambiar_pantalla()
	_rebuild()


func _al_cambiar_pantalla() -> void:
	pass


# ============================================================
#  RECONSTRUIR
# ============================================================

# Guardia de REENTRADA. Un _rebuild puede entrar mientras otro esta a medias (el focus_exited de un
# stepper al liberarlo, las señales de red, un _on_* que espera en un await), y entonces el de dentro
# pinta su panel y el de fuera apila el suyo debajo: el menu salia DUPLICADO.
var _reconstruyendo := false
# Solo ha cambiado la celda elegida: la rejilla se marca en sitio y no se rehace (ver grid_detail).
var _solo_seleccion := false

func _rebuild() -> void:
	if _reconstruyendo:
		return
	_reconstruyendo = true
	Game.abrir_recuento_hogar()
	_rebuild_real()
	Game.cerrar_recuento_hogar()
	_reconstruyendo = false


# Para las pantallas de cada pestaña (un nombre sin guion bajo que se pueda llamar desde fuera).
func rebuild() -> void:
	_rebuild()


func _rebuild_real() -> void:
	contador("")
	MenuScaffold.subpestanas(barra_sub, [], [], -1, Callable())
	for zona in ([_content, _acciones] if _solo_seleccion else [_header, _lista, _content, _acciones]):
		MenuScaffold.vaciar(zona)
	for i in _tab_buttons.size():
		(_tab_buttons[i] as Button).button_pressed = (i == _tab)
	_pintar()
	_partir_lineas(_content)
	MenuScaffold.decir(_aviso_lbl, _aviso, _aviso_ok)
	_aviso_lbl.visible = _aviso != ""


# Lo pinta cada taller.
func _pintar() -> void:
	pass


# La ficha va en un scroll SIN barra horizontal, y ahi una etiqueta que no parte linea impone su
# ancho a la columna entera: un nombre largo ensanchaba la ficha y la rejilla perdia columnas.
func _partir_lineas(nodo: Node) -> void:
	for h in nodo.get_children():
		if h is Label and (h as Label).autowrap_mode == TextServer.AUTOWRAP_OFF:
			(h as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_partir_lineas(h)


# ============================================================
#  QUIÉN TRABAJA
#  Toda tu plantilla: primero los que bajan hoy y detras los que se quedan en el Hogar, con la raya
#  entre medias. No se filtra por "tiene el oficio": mandar a uno que no lo tiene es justo como lo
#  aprende (ver Game.artesano). Quien lo tiene lleva su icono en la esquina del retrato.
# ============================================================

func _gente() -> Array:
	var out: Array = []
	out.append_array(Game.party)
	out.append_array(Game.en_el_banquillo())
	return out


# 'oficio' = el id del desarrollo (y la clave del artesano). 'icono' y 'pista' = la marca de quien lo
# tiene. Con 'oficio' vacio la fila se esconde (una pestaña donde no trabaja nadie).
func pintar_artesanos(oficio: String, icono: String, pista: String) -> void:
	_oficio_artesano = oficio
	_fila_artesano_rotulo.text = "QUIÉN TRABAJA"
	var gente: Array = _gente() if oficio != "" else []
	# Con una sola persona no hay nada que elegir y retratos() no pinta nada: fuera tambien el rotulo.
	_fila_artesano_rotulo.visible = gente.size() > 1
	(_fila_artesano.get_parent().get_parent() as Control).visible = gente.size() > 1
	var con_oficio: Array = []
	for i in gente.size():
		if Game.desarrollo_rango(oficio, gente[i] as PersonajeData) > 0:
			con_oficio.append(i)
	MenuScaffold.retratos(_fila_artesano, gente, gente.find(Game.artesano(oficio)), Game.party.size(),
		_on_artesano, con_oficio, icono, pista)


func _on_artesano(i: int) -> void:
	var gente: Array = _gente()
	if _oficio_artesano == "" or i < 0 or i >= gente.size():
		return
	Game.poner_artesano(_oficio_artesano, gente[i] as PersonajeData)
	# Repintar entero: con el artesano cambia el bonus del oficio y lo que puede salir. Lo elegido se
	# queda (no ha cambiado lo que quieres hacer, solo quien lo hace).
	_aviso = ""
	_rebuild()


# ============================================================
#  LA REJILLA
# ============================================================

func _columnas() -> int:
	var ancho: float = _lista.size.x
	if ancho <= 1.0:
		ancho = _scroll_lista.custom_minimum_size.x
	return maxi(2, int(floorf((ancho + 6.0) / (LADO_CELDA + 6.0))))


var _cols_pintadas: int = 0

func _on_lista_redimensionada() -> void:
	if _root.visible and _columnas() != _cols_pintadas:
		# Diferido: llega en mitad de la colocacion de los contenedores (o de otro rebuild, que el
		# guardia se tragaria sin repetirlo).
		_rebuild.call_deferred()


# Pinta la rejilla y la ficha de lo elegido. 'vacio' = lo que se dice cuando no hay nada.
func grid_detail(piezas: Array, ficha: Callable, vacio: String = "(nada por aquí)") -> void:
	if piezas.is_empty():
		# Apuntar las columnas TAMBIEN cuando no se pinta rejilla. Sin esto el resized de despues ve que
		# no coincide, pide otro rebuild, que vuelve a no pintar rejilla... y el menu se repinta sin
		# parar dentro del mismo fotograma: el juego se queda colgado sin decir nada.
		_cols_pintadas = _columnas()
		MenuScaffold.nota(_lista, vacio)
		return
	sel = clampi(sel, 0, piezas.size() - 1)
	if not (_solo_seleccion and MenuScaffold.marcar_en_rejilla(_lista, sel)):
		MenuScaffold.vaciar(_lista)
		_cols_pintadas = _columnas()
		MenuScaffold.rejilla_objetos(_lista, piezas, sel, _pick, _cols_pintadas, LADO_CELDA)
	ficha.call(_content)


func _pick(i: int) -> void:
	if i != sel:
		_aviso = ""   # cambiar de celda borra el aviso de la anterior
		_al_elegir_otra()
	sel = i
	_solo_seleccion = true
	_rebuild()
	_solo_seleccion = false


func _al_elegir_otra() -> void:
	pass


# Una celda de la rejilla (ver MenuScaffold.rejilla_objetos).
static func pieza(modelo: Resource, pie: String, tooltip: String, marca: String = "") -> Dictionary:
	return {"item": modelo, "pie": pie, "tooltip": tooltip, "marca": marca, "activo": true}


# ============================================================
#  PIEZAS DE LA FICHA
# ============================================================

func contador(txt: String, alerta: bool = false) -> void:
	_contador_lbl.text = txt
	_contador_lbl.visible = txt != ""
	_contador_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.52, 0.52) if alerta else Color(0.78, 0.82, 0.90))


func titulo_seccion(txt: String) -> void:
	_titulo_seccion.text = txt


func decir(txt: String, ok: bool = true) -> void:
	_aviso = txt
	_aviso_ok = ok


func row(vb: VBoxContainer, etiqueta: String, valor: String, color_valor: Variant = null) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = etiqueta
	k.custom_minimum_size = Vector2(150, 0)
	k.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	k.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	r.add_child(k)
	var v := Label.new()
	v.text = valor
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if color_valor is Color:
		v.add_theme_color_override("font_color", color_valor)
	r.add_child(v)
	vb.add_child(r)


func note(vb: VBoxContainer, txt: String) -> void:
	MenuScaffold.nota(vb, txt)


# El pie fijo de la ficha, donde cada pantalla pone sus botones.
func acciones() -> VBoxContainer:
	return _acciones


# El nombre de una calidad, como se lee en el baul.
static func cal_txt(cal: int) -> String:
	match cal:
		MaterialItem.Calidad.PURO: return "Puro"
		MaterialItem.Calidad.INTACTO: return "Intacto"
		MaterialItem.Calidad.NORMAL: return "Normal"
		MaterialItem.Calidad.DANADO: return "Dañado"
		_: return "Roto"
