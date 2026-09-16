# ============================================================
#  tannery_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  Menu de la PELETERIA. Tres pestañas:
#    1) CURTIR   - cuero crudo -> CUERO CURTIDO (lo unico que admite la forja).
#    2) CORREAS  - cuero curtido -> CORREAS (los tirantes de la mochila).
#    3) MOCHILAS - hebillas (del herrero) + correas + cuero curtido -> MOCHILA.
#
#  Curtir y hacer correas son REFINADOS: NO se mezclan calidades (N piezas de la MISMA calidad
#  dan una de esa calidad); solo la Peleteria puede regalarte un escalon. Coser la mochila, en
#  cambio, SI mezcla: la calidad media tira su RAREZA, que es lo unico que la diferencia (no
#  lleva mejoras). El TIER lo ponen las hebillas.
#
#  REHECHO el 16/09/2026 con la cara del inventario (referencia Honkai Star Rail), detras de la
#  tienda. La queja: era una sola columna de "etiqueta: valor" con medio monitor vacio al lado, y
#  los materiales habia que LEERLOS uno a uno en botones de texto. Ahora: rejilla de celdas a la
#  izquierda (el color dice la calidad y la banda cuantas hay, igual que en el baul), ficha a la
#  derecha y los botones en un pie fijo debajo de ella.
#
#  Este archivo es el ARMAZON: montaje, pestañas, rejilla, ficha comun y pie de acciones. Cada
#  pestaña vive en scripts/ui/peleteria/. Toda la MATH sigue en Game/Forge, sin tocar.
#
#  ⚠️ El montaje de esta pantalla es el MISMO que el de la tienda (ver shop_menu._ready). Esta
#  copiado y no compartido a proposito: la regla del rework es un menu cada vez, sin tocar lo que
#  usan los que aun no estan migrados. Cuando le toque a forge_menu (herreria y carpinteria), que
#  sera la tercera con esta forma, ese montaje sube a MenuScaffold y las tres lo llaman.
# ============================================================

extends CanvasLayer

const PeleteriaRefinar = preload("res://scripts/ui/peleteria/peleteria_refinar.gd")
const PeleteriaMochilas = preload("res://scripts/ui/peleteria/peleteria_mochilas.gd")

const TABS := ["Curtir", "Correas", "Mochilas"]
# Los iconos, en el mismo orden. Van con icono y SIN texto, como el inventario y la tienda: el
# nombre de la seccion se lee arriba a la izquierda, bajo "Peleteria".
const TAB_ICONOS := ["cuero", "correa", "mochila"]
const TAB_CURTIR := 0
const TAB_CORREAS := 1
const TAB_MOCHILAS := 2

const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const ROJO := Color(0.9, 0.5, 0.5)
const GRIS := Color(0.6, 0.63, 0.7)

# De mejor a peor (el enum de calidad NO esta ordenado: PURO se añadio al final).
const CALIDADES := [MaterialItem.Calidad.PURO, MaterialItem.Calidad.INTACTO,
	MaterialItem.Calidad.NORMAL, MaterialItem.Calidad.DANADO]

# Las mismas medidas que el inventario y la tienda: 96 de celda y la ficha a 360.
const LADO_CELDA := 96.0
const ANCHO_FICHA := 360.0
# MOCHILAS pide mucho mas: en su ficha caben los tres ingredientes con una fila por calidad y la
# tabla de rarezas. Con 360 la ficha salia con scroll y cortada a media linea mientras a la izquierda
# sobraban setecientos pixeles en blanco -- alli solo hay DOS celdas, una por metal. Aqui la rejilla
# se queda con lo justo y todo lo demas es para la ficha, que es donde esta el trabajo.
const ANCHO_FICHA_MOCHILA := 900.0
# Y con ella la rejilla se encoge, pero SIGUE siendo la que se estira: asi el sobrante se lo come
# ella y no queda un palmo muerto a la derecha de la ficha.
const ANCHO_REJILLA_MOCHILA := 300.0
const ANCHO_REJILLA_MIN := 420.0

var _root: Control = null
var _header: VBoxContainer = null
var _lista: VBoxContainer = null      # la rejilla de celdas (columna izquierda)
var _scroll_lista: ScrollContainer = null
var _content: VBoxContainer = null    # la ficha (columna derecha)
var _acciones: VBoxContainer = null   # bajo la ficha y FUERA de su scroll: siempre a la vista
var _col_der: VBoxContainer = null
var _scroll_det: ScrollContainer = null
var _contador_lbl: Label = null
var _aviso_lbl: Label = null
var _titulo_seccion: Label = null
var _tab_buttons: Array = []
# La fila de FILTROS de la columna izquierda (el tier). La rellena cada pestaña; vacia, desaparece.
var barra_sub: HBoxContainer = null
# La fila de retratos: quien esta trabajando en la peleteria (ver Game.artesano).
var _fila_artesano: HBoxContainer = null
var _fila_artesano_rotulo: Label = null

var refinar = null    # PeleteriaRefinar (vale para Curtir y para Correas)
var mochilas = null   # PeleteriaMochilas

var _tab: int = TAB_CURTIR
var sel: int = 0             # celda elegida en la rejilla
var stacks: Array = []       # lo pintado en la rejilla, en el mismo orden que las celdas
var _aviso: String = ""
var _aviso_ok: bool = true


func _ready() -> void:
	layer = 91
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para: hay que seguir respondiendo
	add_to_group("tannery_menu")
	refinar = PeleteriaRefinar.new(self)
	mochilas = PeleteriaMochilas.new(self)

	# MULTI: refresco en vivo cuando el compañero toca el baul o su reserva (ver forge_menu).
	if Net.has_signal("hogar_cambiado"):
		Net.hogar_cambiado.connect(_on_cambio_externo)
	if Net.has_signal("reservas_cambiadas"):
		Net.reservas_cambiadas.connect(_on_cambio_externo)

	# El SITIO, no la persona: aqui no hay nadie curtiendo por ti, lo haces tu con tus personajes
	# (decision del usuario, 16/09). Igual en la herreria y la carpinteria.
	var m: Dictionary = MenuScaffold.construir(self, "PELETERÍA", "", _cerrar, false, false)
	_root = m["root"]
	_header = m["header"]
	_lista = m["lista"]
	_content = m["content"]
	# FUERA la cabecera entera (linea de aviso + header): aunque vacias reservaban su alto y dejaban
	# un palmo muerto entre la barra de arriba y la rejilla. El aviso se muda a la columna de la
	# ficha, justo encima de los botones que lo provocan.
	((m["aviso"] as Control).get_parent().get_parent() as Control).visible = false

	var scroll: ScrollContainer = m["lista_scroll"]
	_scroll_lista = scroll
	scroll.custom_minimum_size = Vector2(ANCHO_REJILLA_MIN, 0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_horizontal = Control.SIZE_FILL
	_content.custom_minimum_size = Vector2(ANCHO_FICHA, 0)
	var scroll_det: ScrollContainer = _content.get_parent() as ScrollContainer
	scroll_det.size_flags_horizontal = Control.SIZE_FILL
	scroll_det.custom_minimum_size = Vector2(ANCHO_FICHA, 0)
	scroll.resized.connect(_on_lista_redimensionada)
	# Y la LISTA de dentro, que se coloca DESPUES que su scroll: mirando solo el scroll, al abrir se
	# media la lista aun sin ancho y salian 4 columnas estiradas que ya no se corregian.
	_lista.resized.connect(_on_lista_redimensionada)

	# LA COLUMNA DERECHA: la ficha con su scroll y, DEBAJO Y FUERA DEL SCROLL, las acciones.
	var split_der: BoxContainer = scroll_det.get_parent()
	split_der.remove_child(scroll_det)
	_col_der = VBoxContainer.new()
	_col_der.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_col_der.custom_minimum_size = Vector2(ANCHO_FICHA, 0)
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

	# LA COLUMNA IZQUIERDA: la fila de filtros y la rejilla. No hay buscador: aqui se busca con el
	# ojo entre unos pocos montones, no entre cuatrocientos como en el baul.
	var split: BoxContainer = scroll.get_parent()
	split.remove_child(scroll)
	var col_izq := VBoxContainer.new()
	col_izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_izq.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_izq.add_theme_constant_override("separation", 6)
	split.add_child(col_izq)
	split.move_child(col_izq, 0)
	# QUIÉN TRABAJA: la fila de retratos, arriba de la columna izquierda. Es la misma pieza que el
	# menú de personaje y el altar (MenuScaffold.fila_retratos), con su raya entre los que bajan hoy
	# y los que se quedan en casa. Va aquí y no en la cabecera porque la cabecera está oculta (deja
	# un palmo muerto), y aquí queda al lado de lo que se elige.
	var rotulo := Label.new()
	rotulo.text = "QUIÉN TRABAJA"
	rotulo.add_theme_font_size_override("font_size", 11)
	rotulo.add_theme_color_override("font_color", MenuScaffold.GRIS)
	_fila_artesano_rotulo = rotulo
	col_izq.add_child(rotulo)
	_fila_artesano = MenuScaffold.fila_retratos(col_izq)

	# EL FILTRO POR TIER, encima de la rejilla y dentro de su columna (igual que en el inventario y
	# el hogar). Con la partida llena son dieciseis montones de piel de tres tiers distintos, y sin
	# esto hay que barrer la rejilla entera para encontrar la del tier que vas a curtir.
	barra_sub = HBoxContainer.new()
	barra_sub.alignment = BoxContainer.ALIGNMENT_CENTER
	barra_sub.add_theme_constant_override("separation", 14)
	col_izq.add_child(barra_sub)
	col_izq.add_child(scroll)

	# LAS PESTAÑAS, con icono y centradas en la pantalla.
	var barra_tabs: HBoxContainer = m["side"]
	barra_tabs.add_theme_constant_override("separation", 14)
	for i in TABS.size():
		var b: Button = MenuScaffold.pestana_icono(TAB_ICONOS[i], TABS[i])
		b.pressed.connect(_on_tab.bind(i))
		barra_tabs.add_child(b)
		_tab_buttons.append(b)

	var barra: BoxContainer = barra_tabs.get_parent()
	(barra.get_child(0) as Control).visible = false
	# EL TITULO EN DOS LINEAS: "Peleteria" pequeño y gris encima del nombre de la seccion, grande.
	var titulo := VBoxContainer.new()
	titulo.add_theme_constant_override("separation", 0)
	var chico := Label.new()
	chico.text = "Peletería"
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

	# EL CONTADOR de la seccion, arriba a la derecha (lo que tienes guardado, la carga que llevas).
	_contador_lbl = Label.new()
	_contador_lbl.add_theme_font_size_override("font_size", 15)
	_contador_lbl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.90))
	barra.add_child(_contador_lbl)
	barra.move_child(_contador_lbl, barra.get_child_count() - 2)


func abrir() -> void:
	if Game._active_layer != null or Game.debug_panel_open:
		return
	# MULTI: ya no se coge el candado al abrir (los dos a la vez). Se coge solo al crear, y lo
	# seleccionado en Mochilas se RESERVA para el otro. Ver forge_menu.
	_tab = TAB_CURTIR
	sel = 0
	_aviso = ""
	mochilas.limpiar()
	_root.visible = true
	Game.abrir_menu(self)   # para el mundo entero mientras el menu esta abierto
	_rebuild()


func _cerrar() -> void:
	_root.visible = false
	# Las copias de escaparate dejan meta en Game.item_meta: sin esto se quedan colgando para siempre
	# (la misma limpieza que hace la tienda al cerrar).
	mochilas.vaciar_vitrina()
	Game.cerrar_menu(self)
	if Net.activo:
		Net.hogar.liberar_mis_reservas()


func _on_cambio_externo() -> void:
	if _root != null and _root.visible:
		_rebuild()


func ocupado() -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_toast"):
		hud.mostrar_toast("Un momento: tu compañero está creando algo justo ahora.")


func _input(event: InputEvent) -> void:
	if not _root.visible:
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


# La llaman las pestañas al cambiar de lo que enseñan: la celda elegida ya no vale.
func cambiar_pantalla() -> void:
	sel = 0
	_aviso = ""
	_rebuild()


# ============================================================
#  RECONSTRUIR
# ============================================================

# Guardia de REENTRADA. Un _rebuild puede entrar mientras otro esta a medias (el focus_exited de un
# stepper al liberarlo, las señales de red, un _on_* que espera en un await), y entonces el de dentro
# pinta su panel y el de fuera apila el suyo debajo: el menu salia DUPLICADO. Es el mismo guardia que
# lleva la forja desde que se cazo alli.
var _reconstruyendo := false
# Solo ha cambiado la celda elegida: la rejilla se marca en sitio y no se rehace (ver grid_detail).
var _solo_seleccion := false

func _rebuild() -> void:
	if _reconstruyendo:
		return
	_reconstruyendo = true
	_rebuild_real()
	_reconstruyendo = false


# Para las pestañas (un nombre sin guion bajo que se pueda llamar desde fuera).
func rebuild() -> void:
	_rebuild()


func _rebuild_real() -> void:
	contador("")
	MenuScaffold.subpestanas(barra_sub, [], [], -1, Callable())
	for zona in ([_content, _acciones] if _solo_seleccion else [_header, _lista, _content, _acciones]):
		MenuScaffold.vaciar(zona)
	for i in _tab_buttons.size():
		(_tab_buttons[i] as Button).button_pressed = (i == _tab)
	_titulo_seccion.text = TABS[_tab]
	# EL REPARTO DEL ANCHO, que cambia con la pestaña (ver ANCHO_FICHA_MOCHILA): en Mochilas la
	# rejilla son dos celdas y el trabajo esta todo en la ficha, asi que se le da la vuelta al
	# reparto de las otras dos.
	var ancho: float = ANCHO_FICHA_MOCHILA if _tab == TAB_MOCHILAS else ANCHO_FICHA
	for c in [_col_der, _scroll_det, _content]:
		(c as Control).custom_minimum_size.x = ancho
	_scroll_lista.custom_minimum_size.x = ANCHO_REJILLA_MOCHILA if _tab == TAB_MOCHILAS \
		else ANCHO_REJILLA_MIN
	# Solo MOCHILAS reserva (seleccion persistente); curtir y correas son instantaneas.
	if Net.activo and _tab != TAB_MOCHILAS:
		Net.hogar.reservar({})

	_pintar_artesanos()
	match _tab:
		TAB_MOCHILAS: mochilas.build()
		_: refinar.build(_tab == TAB_CORREAS)
	_partir_lineas(_content)
	MenuScaffold.decir(_aviso_lbl, _aviso, _aviso_ok)
	_aviso_lbl.visible = _aviso != ""


# ============================================================
#  QUIEN TRABAJA
#  Toda tu plantilla: primero los que bajan hoy y detras los que se quedan en el Hogar, con la raya
#  entre medias que pinta MenuScaffold.retratos. No se filtra por "tiene Peleteria": mandar a uno que
#  no la tiene es justo como la aprende (ver Game.artesano).
# ============================================================

func _gente() -> Array:
	var out: Array = []
	out.append_array(Game.party)
	out.append_array(Game.en_el_banquillo())
	return out


func _pintar_artesanos() -> void:
	var gente: Array = _gente()
	# Con una sola persona no hay nada que elegir y retratos() no pinta nada: fuera tambien el rotulo,
	# o se queda un titulo suelto encima de la nada.
	_fila_artesano_rotulo.visible = gente.size() > 1
	var actual: PersonajeData = Game.artesano("peleteria")
	# QUIEN TIENE EL OFICIO se marca EN SU RETRATO, con el pellejo en la esquina. Estaba escrito en la
	# ficha ("Fulano no la tiene") y el usuario lo corto: eso hay que leerlo, y encima solo hablaba
	# del que estuviera elegido. En el retrato se ve de un vistazo a quien conviene mandar.
	var con_oficio: Array = []
	for i in gente.size():
		if Game.desarrollo_rango("peleteria", gente[i] as PersonajeData) > 0:
			con_oficio.append(i)
	MenuScaffold.retratos(_fila_artesano, gente, gente.find(actual), Game.party.size(),
		_on_artesano, con_oficio, "cuero", "Tiene Peletería")


func _on_artesano(i: int) -> void:
	var gente: Array = _gente()
	if i < 0 or i >= gente.size():
		return
	Game.poner_artesano("peleteria", gente[i] as PersonajeData)
	# Repintar entero y no solo la fila: con el artesano cambia el bonus del oficio, y con el la
	# linea de "Peleteria activa" y lo que puede salir.
	cambiar_pantalla()


# La ficha va en un scroll SIN barra horizontal, y ahi una etiqueta que no parte linea impone su
# ancho a la columna entera: un nombre largo ensanchaba la ficha y la rejilla perdia columnas.
func _partir_lineas(nodo: Node) -> void:
	for h in nodo.get_children():
		if h is Label and (h as Label).autowrap_mode == TextServer.AUTOWRAP_OFF:
			(h as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_partir_lineas(h)


# ============================================================
#  LA REJILLA
# ============================================================

func _columnas() -> int:
	var ancho: float = _lista.size.x
	if ancho <= 1.0:
		ancho = ANCHO_REJILLA_MIN
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
		# Apuntar las columnas TAMBIEN cuando no se pinta rejilla. Sin esto, _cols_pintadas se queda
		# con el numero que se calculo antes de que la lista tuviera ancho, el resized de despues ve
		# que no coincide, pide otro rebuild, que vuelve a no pintar rejilla... y el menu se repinta
		# sin parar dentro del mismo fotograma: el juego se queda colgado sin decir nada (cazado en
		# el visor al vaciar el baul).
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
	sel = i
	_solo_seleccion = true
	_rebuild()
	_solo_seleccion = false


# Una celda de la rejilla (ver MenuScaffold.rejilla_objetos).
static func pieza(modelo: Resource, pie: String, tooltip: String, marca: String = "") -> Dictionary:
	return {"item": modelo, "pie": pie, "tooltip": tooltip, "marca": marca, "activo": true}


# ============================================================
#  PIEZAS DE LA FICHA (las usan las dos pestañas)
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


# El pie fijo de la ficha, donde cada pestaña pone sus botones.
func acciones() -> VBoxContainer:
	return _acciones


# El nombre de un material con su calidad, como se lee en el baul.
static func cal_txt(cal: int) -> String:
	match cal:
		MaterialItem.Calidad.PURO: return "Puro"
		MaterialItem.Calidad.INTACTO: return "Intacto"
		MaterialItem.Calidad.NORMAL: return "Normal"
		MaterialItem.Calidad.DANADO: return "Dañado"
		_: return "Roto"


# Linea de sabor del oficio, SIN numeros (misma regla que en la forja, ver forge_menu._estado_oficio):
# el contador es OCULTO porque es lo que decide si la habilidad te sale al subir de nivel. Bloqueada
# -> no se pinta nada, ni el separador. Los numeros, en el panel de debug.
# El OFICIO ya no se escribe en la ficha: quien lo tiene lleva el pellejo en la esquina de su
# retrato (ver _pintar_artesanos). Lo pidio asi el usuario -- una fila que dice "Fulano no la tiene"
# hay que leerla, y encima solo hablaba del que estuviera elegido.
