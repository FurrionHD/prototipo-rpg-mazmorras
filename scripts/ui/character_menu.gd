# ============================================================
#  character_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  Menu de PERSONAJE a pantalla completa, tecla C. Rehecho con la misma forma que el inventario
#  (ver inventory_menu.gd y las capturas de referencia):
#
#    [Personaje]        ( ⚔ ✦ ◈ 🛡 ✳ )        (◍)(◍)(◍)(◍)   ✕
#    [ NOMBRE ]          las 5 secciones        el grupo
#    ──────────────────────────────────────────────────────────
#              ( subpestañas )        ┌──────────────────────┐
#               el MUÑECO / la        │ la FICHA de lo que   │
#               rejilla de la         │ tengas elegido       │
#               seccion               └──────────────────────┘
#
#  LAS CINCO SECCIONES:
#    1) DETALLES  - el muñeco y sus barras; a la derecha, [Atributos | Habilidades]. Los atributos
#                   cambian segun el arma (con baston salen los MAGICOS), y la lupa abre el detalle
#                   entero, fisico y magico, lleves lo que lleves.
#    2) ARMA      - principal y secundaria. "Cambiar" abre la rejilla del baul.
#    3) TRAZOS    - las habilidades que llevas equipadas por el arma. Con hechizos, subpestañas
#                   [Habilidades | Magias]; sin ellos la fila no aparece.
#    4) ARMADURA  - las 5 piezas. Igual que las armas: celda -> ficha -> Cambiar.
#    5) EIDOLON   - desarrollos y pasivas. Subpestañas solo si tienes de las dos clases; sin nada,
#                   sale Desarrollo vacio con su explicacion.
#
#  Cambiar de equipo, SOLO EN EL PUEBLO. Pausa el juego mientras esta abierto.
#
#  DONDE ESTAN LOS NUMEROS: en ningun sitio de aqui. Todo sale de Game.crear_player_combatant y de
#  las filas_* de MenuScaffold, que es la MISMA fuente que la ficha de detalle del combate
#  (combate_detalle.gd). Dos pantallas, un solo juego de formulas: si se reescribiera una cuenta
#  aqui, las dos empezarian a decir cosas distintas del mismo personaje sin dar ningun error.
# ============================================================

extends CanvasLayer

# --- LAS SECCIONES (la columna de la izquierda) ---
#
# LOS NOMBRES SON LOS DEL JUEGO, no los de la pantalla en la que nos fijamos para la FORMA. De ahi
# se copia el reparto (columna de secciones a la izquierda, gente arriba, ficha a la derecha) y nada
# mas: "Trazos" y "Eidolon" no significan nada aqui, y estuvieron puestos por copiarlos sin pensar.
#
# OJO con "Habilidades": aqui son las del ARMA (las que enseña el maestro). Las cinco de DanMachi
# —Fuerza, Resistencia, Destreza, Agilidad, Magia— se llaman en todo el juego "habilidades BASICAS",
# y asi se llama tambien su pagina dentro de Ficha. Dos cosas parecidas con el mismo nombre a secas
# no las distingue nadie.
const SECCIONES := ["Ficha", "Armas", "Habilidades", "Armadura", "Desarrollo"]
const SECCION_ICONOS := ["persona", "espada", "trazos", "coraza", "eidolon"]
const SEC_FICHA := 0
const SEC_ARMAS := 1
const SEC_HABILIDADES := 2
const SEC_ARMADURA := 3
const SEC_DESARROLLO := 4

const ARMOR_SLOTS := ["casco", "pecho", "manos", "pantalones", "botas"]
const ARMOR_SLOT_LABELS := {
	"casco": "Casco", "pecho": "Pecho", "manos": "Manos",
	"pantalones": "Pantalones", "botas": "Botas"}
const WEAPON_TIPO_LABELS := ["Puños", "Daga", "Espada corta", "Espada larga", "Mandoble",
	"Estoque", "Hacha grande", "Maza pequeña", "Martillo grande", "Bastón"]

# --- MEDIDAS ---
# Las mismas que el inventario, y por el mismo motivo: estan calibradas a las unidades logicas de
# 1280x720 (ver project.godot) y las dos pantallas tienen que verse hermanas.
const LADO_CELDA := 96.0
const ANCHO_FICHA := 360.0
const ANCHO_REJILLA_MIN := 420.0
# Alto reservado al muñeco. Va FIJO y no expansivo: la columna vive dentro de un ScrollContainer, y
# ahi un size_flags_vertical EXPAND no estira nada (no hay alto que repartir, lo pone el contenido).
const ALTO_MUNECO := 430.0
# TOPE de aumento del muñeco. El cuerpo se dibuja a PoseJugador.ALTO_MUNDO px (60), asi que sin tope
# se estira a lo que mida la caja. Se sube hasta donde el sprite aguanta sin verse reventado: es el
# protagonista de esta columna y a x3 se quedaba en un monigote en medio de un descampado.
const ESCALA_MUNECO := 6.0
# El aire que se le deja al muñeco por arriba y por abajo dentro de su caja.
const MARGEN_MUNECO := 20.0
# EL RETRATO de la fila de arriba: el cuadro donde se ve la cara, y el alto total contando el nombre
# de debajo. Grande a proposito -- son la forma de elegir a quien miras, y a 52 px no se distinguia
# uno de otro.
const LADO_RETRATO := 74.0
const ALTO_RETRATO := LADO_RETRATO + 20.0

const AMBAR := Color(0.95, 0.72, 0.36)
const GRIS := Color(0.6, 0.63, 0.7)

var _root: Control = null
var _header: VBoxContainer = null
var _lista: VBoxContainer = null      # la columna del centro (rejilla / muñeco)
var _content: VBoxContainer = null    # la ficha de la derecha
var _barra_sub: HBoxContainer = null  # la fila de subpestañas (vacia = no se ve)
var _titulo_seccion: Label = null     # el NOMBRE de quien estas mirando, arriba de la columna
var _fila_retratos: HBoxContainer = null
var _scroll_retratos: ScrollContainer = null   # con toda la plantilla no cabe en una fila
var _tab_buttons: Array = []
var _modal: Control = null            # el modal de la lupa / de robo (null = ninguno)
# La caja del muñeco, para poder ESCONDERLA mientras hay un modal abierto. Hace falta porque el
# muñeco va con z_as_relative = false (ver muneco_jugador.gd: sus capas se ordenan entre si con
# z_index absoluto, que es lo que las mantiene bien apiladas), y un z absoluto no se entera de que
# hay un panel de UI por encima: la figura se dibujaba ENCIMA del modal de la lupa. Taparlo con un
# velo mas opaco no serviria — el z manda sobre el orden del arbol.
var _caja_muneco: Control = null
# A que altura han quedado los PIES del muñeco dentro de su caja. Lo escribe la colocacion y lo lee
# el dibujo de la sombra: son dos lambdas distintas y con dos cuentas parecidas la sombra acababa
# flotando por debajo de los talones.
var _pies_y: float = 0.0

var _sec: int = SEC_FICHA
# A QUIEN le estas mirando la ficha (indice en Game.party). Con companeros este menu deja de ser "tu
# ficha" y pasa a ser la de cualquiera de los tuyos: la fila de retratos elige, y todo lo que se
# pinta debajo sale de _pj().
var _pj_sel: int = 0
var _pagina: int = 0    # Detalles: 0 = atributos, 1 = habilidades
var _sub: int = 0       # subpestaña de la seccion (Trazos: hab/magias; Eidolon: desarrollo/pasivas)
var _sel: int = 0       # lo elegido en la rejilla del centro
var _cambiando: bool = false   # Arma/Armadura: estas eligiendo pieza del baul
var _cand: int = 0      # el candidato dentro de ese catalogo


func _ready() -> void:
	layer = 92   # encima del inventario (91), debajo del combate (100)
	process_mode = Node.PROCESS_MODE_ALWAYS   # abrirlo pausa el arbol: hay que seguir respondiendo
	add_to_group("menu_personaje")   # lo busca el boton de la barra tactil (ver hud.gd)

	# con_lateral = TRUE: las secciones van en COLUMNA A LA IZQUIERDA, con su icono y su NOMBRE
	# escrito. Es el reparto de la pantalla de referencia, y aqui hace mas falta todavia que alli:
	# cinco iconos pelados en fila no dicen cual es cual, y esta pantalla no es un catalogo que se
	# hojea (donde el icono basta), sino cinco sitios distintos a los que se va a buscar algo
	# concreto. Lo que va ARRIBA es la GENTE, que es la otra cosa que se elige.
	var m: Dictionary = MenuScaffold.construir(self, "PERSONAJE", "", _cerrar, false, true)
	_root = m["root"]
	_header = m["header"]
	_lista = m["lista"]
	_content = m["content"]

	# LA LINEA DE AVISO, FUERA: el esqueleto le reserva 22 px aunque este vacia (para que los menus de
	# oficio no peguen un salto cada vez que dicen algo), y esta pantalla no dice nada por ahi.
	(m["aviso"] as Control).visible = false

	# EL REPARTO SE INVIERTE, igual que en el inventario: manda el centro (el muñeco, la rejilla) y la
	# ficha se queda con un ancho fijo, el justo para leer una fila "etiqueta: valor" sin barrer la
	# vista de un lado a otro.
	var scroll: ScrollContainer = m["lista_scroll"]
	scroll.custom_minimum_size = Vector2(ANCHO_REJILLA_MIN, 0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_horizontal = Control.SIZE_FILL
	_content.custom_minimum_size = Vector2(ANCHO_FICHA, 0)
	(_content.get_parent() as ScrollContainer).size_flags_horizontal = Control.SIZE_FILL
	(_content.get_parent() as ScrollContainer).custom_minimum_size = Vector2(ANCHO_FICHA, 0)
	scroll.resized.connect(_on_centro_redimensionado)

	# LA COLUMNA DEL CENTRO: la fila de subpestañas ENCIMA y FUERA del scroll (hermana suya, no hija),
	# para que no se vaya con el contenido al desplazarse. Un selector que desaparece al bajar es un
	# selector que hay que ir a buscar.
	var split: BoxContainer = scroll.get_parent()
	split.remove_child(scroll)
	var col_centro := VBoxContainer.new()
	col_centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_centro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_centro.add_theme_constant_override("separation", 4)
	split.add_child(col_centro)
	split.move_child(col_centro, 0)
	_barra_sub = HBoxContainer.new()
	_barra_sub.alignment = BoxContainer.ALIGNMENT_CENTER
	_barra_sub.add_theme_constant_override("separation", 14)
	col_centro.add_child(_barra_sub)
	col_centro.add_child(scroll)

	# --- LA COLUMNA DE SECCIONES (izquierda) ---
	var col_tabs: VBoxContainer = m["side"]
	col_tabs.add_theme_constant_override("separation", 2)
	for i in SECCIONES.size():
		var b: Button = _pestana_lateral(SECCION_ICONOS[i], SECCIONES[i])
		b.pressed.connect(_on_seccion.bind(i))
		col_tabs.add_child(b)
		_tab_buttons.append(b)

	# EL TITULO DE LA COLUMNA, en dos lineas: "Personaje" pequeño y gris sobre el NOMBRE de quien
	# tienes delante. El nombre y no la palabra "PERSONAJE": con un grupo, saber de quien es la ficha
	# importa mas que saber que es una ficha. En que seccion estas ya lo dice la pestaña marcada.
	# La etiqueta del esqueleto se esconde en vez de borrarse: un Control oculto no ocupa sitio en un
	# contenedor, asi que basta con eso y no hay que tocar construir().
	var lateral: BoxContainer = col_tabs.get_parent()
	(lateral.get_child(0) as Control).visible = false
	var titulo := VBoxContainer.new()
	titulo.add_theme_constant_override("separation", 0)
	var chico := Label.new()
	chico.text = "Personaje"
	chico.add_theme_font_size_override("font_size", 11)
	chico.add_theme_color_override("font_color", GRIS)
	titulo.add_child(chico)
	_titulo_seccion = Label.new()
	_titulo_seccion.add_theme_font_size_override("font_size", 20)
	_titulo_seccion.add_theme_color_override("font_color", AMBAR)
	# SIN clip_text: un Label con clip_text tiene tamaño MINIMO cero, asi que el contenedor le da lo
	# que sobra y le corta el nombre a media letra ("CAMBIAR ARMA" se quedaba en "CAME").
	titulo.add_child(_titulo_seccion)
	lateral.add_child(titulo)
	lateral.move_child(titulo, 0)

	# --- LA GENTE, ARRIBA ---
	# Va en el header (la banda que cruza por encima del centro y la ficha) y DENTRO DE UN SCROLL
	# horizontal: aqui no sale solo el equipo, sale TODA la plantilla —los del hogar tambien—, para
	# poder tocarle el equipo a cualquiera sin tener que rehacer el grupo antes. Con doce fichados no
	# caben en una fila, asi que se desliza.
	_scroll_retratos = ScrollContainer.new()
	_scroll_retratos.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll_retratos.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll_retratos.custom_minimum_size = Vector2(0, ALTO_RETRATO)
	_scroll_retratos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Un poco de aire por arriba: la linea de aviso del esqueleto va oculta en esta pantalla, asi que
	# sin esto los retratos quedan pegados al canto de la ventana.
	var hueco_arriba := MarginContainer.new()
	hueco_arriba.add_theme_constant_override("margin_top", 8)
	hueco_arriba.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(hueco_arriba)
	hueco_arriba.add_child(_scroll_retratos)
	_fila_retratos = HBoxContainer.new()
	_fila_retratos.add_theme_constant_override("separation", 10)
	_scroll_retratos.add_child(_fila_retratos)
	# Deslizar con el dedo, igual que las dos columnas del esqueleto (ver MenuScaffold.construir).
	if Tactil.activo:
		ArrastreScroll.enganchar(_scroll_retratos)


# ESC va en _input y CONSUME el evento: _input corre SIEMPRE antes que _unhandled_input, asi que el
# menu de PAUSA (que escucha ahi) no llega a ver la tecla y no se abre por detras al cerrar la ficha.
func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if not event.is_action_pressed(&"cancelar"):
		return
	# Se sale de dentro a fuera: primero el modal que haya encima, luego la rejilla de cambiar equipo
	# (que es una pantalla dentro de la seccion) y solo al final la ficha. Si no, el primer Esc
	# cerraria el menu entero por debajo de lo que estas mirando.
	if _modal != null:
		_cerrar_modal()
	elif _cambiando:
		_cancelar_cambio()
	else:
		_cerrar()
	get_viewport().set_input_as_handled()


# La C va en _unhandled_key_input y NO en _input, por lo mismo que las teclas de dev (ver la cabecera
# de Game._unhandled_key_input): un LineEdit con el foco CONSUME la tecla y aqui no llega, asi que
# escribir el nombre al reclutar ya no abre la ficha por encima. Game.escribiendo() es el cinturon
# explicito encima de eso. No lo devuelvas a _input.
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if Game.escribiendo():
		return   # con el foco en un campo de texto, una tecla es una LETRA y no un atajo
	if event.is_action_pressed(&"personaje"):
		_toggle()


func _toggle() -> void:
	if not _root.visible:
		# hay_modal() en vez de solo inventory_open: cubre la pila ENTERA de menus (tienda, taberna,
		# herrero, mapa...). En solitario lo tapaba la pausa del arbol; en MULTI nada pausa y la ficha
		# se abria encima de cualquier menu.
		if Game._active_layer != null or Game.debug_panel_open or Game.hay_modal():
			return
		_set_open(true)
	else:
		_set_open(false)


func _cerrar() -> void:
	_set_open(false)


func _set_open(open: bool) -> void:
	_root.visible = open
	Game.fijar_modal(Game.Modal.PERSONAJE, self, open)
	if open:
		_cerrar_modal()
		_sec = SEC_FICHA
		_pj_sel = 0   # se abre siempre por el que va en cabeza
		_pagina = 0
		_reset_seccion()
		_rebuild()


# Todo lo que es "lo que estabas haciendo" y no sobrevive a cambiar de seccion ni de persona: el slot
# abierto, el candidato a medio elegir, la subpestaña. Son de SU catalogo, no del nuevo.
func _reset_seccion() -> void:
	_sub = 0
	_sel = 0
	_cand = 0
	_cambiando = false


# TODA la gente que tienes fichada: primero los que bajan hoy y detras los que se quedan en el hogar.
#
# Los del BANQUILLO salen aqui a proposito: si no, para cambiarle el arma a uno que hoy no baja
# habia que meterlo en el equipo, cambiarsela y sacarlo otra vez. El equipo dice quien pelea, no a
# quien puedes mirarle la ficha.
#
# El orden es fijo (Game.party y luego Game.en_el_banquillo(), que ya lo son) porque _pj_sel es un
# INDICE en esta lista: si el orden bailara, cambiar de seccion te cambiaria de persona.
func _gente() -> Array:
	var out: Array = []
	for p in Game.party:
		out.append(p)
	for p in Game.en_el_banquillo():
		out.append(p)
	if out.is_empty():
		out.append(Game.lider())   # imposible en la practica; Game garantiza que el lider existe
	return out


# El personaje cuya ficha se esta viendo.
func _pj() -> PersonajeData:
	var todos: Array = _gente()
	if _pj_sel < 0 or _pj_sel >= todos.size():
		_pj_sel = 0
	return todos[_pj_sel]


# ============================================================
#  LA PESTAÑA LATERAL: icono + NOMBRE
#  Con texto y no solo con el icono (como las del inventario): alli son seis secciones de un
#  catalogo que se hojea y la silueta basta, aqui son cinco sitios distintos a los que vas a buscar
#  algo concreto, y un icono pelado no dice a cual.
#
#  Sin caja, como las del inventario: lo que dice cual esta abierta es la BARRA de la izquierda y el
#  color ambar, no un recuadro. Cinco botones con borde en columna parecen cinco acciones.
# ============================================================

const ALTO_TAB := 42.0
const LADO_ICONO_TAB := 26.0

func _pestana_lateral(icono: String, nombre: String) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, ALTO_TAB)
	b.text = nombre
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.tooltip_text = nombre
	# EL HUECO DEL ICONO se reserva con el margen del stylebox, NO metiendo espacios delante del
	# texto: los espacios miden lo que mida el espacio de la fuente y el icono acababa pintado ENCIMA
	# de la primera letra ("Ficha" se leia con el monigote sobre la F).
	for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxEmpty.new()
		sb.content_margin_left = LADO_ICONO_TAB + 20.0
		b.add_theme_stylebox_override(estado, sb)
	var dibujo := Callable(Iconos, icono)
	b.draw.connect(func() -> void:
		var col: Color = AMBAR if b.button_pressed else MenuScaffold.TAB_APAGADA
		# La BARRA de la izquierda marca la activa: es lo que en la fila de arriba del inventario hace
		# el subrayado, puesto de canto porque aqui la fila es una columna.
		if b.button_pressed:
			b.draw_rect(Rect2(Vector2(0, 6), Vector2(3, b.size.y - 12)), AMBAR)
		dibujo.call(b, Vector2(10, (b.size.y - LADO_ICONO_TAB) * 0.5), LADO_ICONO_TAB, col))
	# Un Button no se repinta al marcarse, y aqui lo unico que cambia es lo que dibuja ese draw.
	b.toggled.connect(func(_on):
		b.add_theme_color_override("font_color",
			AMBAR if b.button_pressed else Color(0.82, 0.85, 0.90))
		b.queue_redraw())
	b.add_theme_color_override("font_color", Color(0.82, 0.85, 0.90))
	b.add_theme_color_override("font_hover_color", Color(0.97, 0.98, 1.0))
	b.add_theme_font_size_override("font_size", 15)
	return b


# Repinta el cuerpo del jugador en el mapa: al cambiar de arma o armadura, la pila de capas del
# muñeco cambia y hay que remontarla (MunecoJugador.montar se salta el trabajo si no ha cambiado).
func _refrescar_mundo() -> void:
	var pl: Node = get_tree().get_first_node_in_group("player")
	if pl != null and pl.has_method("refrescar_grupo"):
		pl.refrescar_grupo()


func _on_seccion(i: int) -> void:
	if i == _sec:
		return
	_sec = i
	_reset_seccion()
	_rebuild()


func _on_sub(i: int) -> void:
	if i == _sub:
		return
	_sub = i
	_sel = 0
	_rebuild()


func _pick(i: int) -> void:
	_sel = i
	_rebuild()


func _pick_persona(i: int) -> void:
	if i == _pj_sel:
		return
	_pj_sel = i
	# Cambiar de persona invalida lo que estuvieras haciendo con la anterior. Y la seccion se queda:
	# lo normal es mirar lo mismo de otro, no volver al principio.
	_reset_seccion()
	_pagina = 0
	_rebuild()


# Cuando la ventana cambia de ancho, la cuenta de columnas de la rejilla cambia con ella. Se
# reconstruye SOLO si el numero ha cambiado de verdad: 'resized' salta en cada pixel de un arrastre
# de ventana, y reconstruir el menu entero 60 veces por segundo se nota.
var _cols_pintadas: int = 0

func _on_centro_redimensionado() -> void:
	if not _root.visible:
		return
	if _columnas() == _cols_pintadas:
		return
	_rebuild()


# Cuantas celdas caben en el ancho que tenga el centro AHORA MISMO. Se mide en vez de fijarla porque
# depende de la ventana (y en movil, de la orientacion). El 6.0 es la separacion de rejilla_objetos:
# se cuenta una celda de mas y se resta, que es la cuenta de "n celdas y n-1 huecos" del derecho.
func _columnas() -> int:
	var ancho: float = _lista.size.x
	if ancho <= 1.0:
		ancho = ANCHO_REJILLA_MIN   # primera pasada: aun no lo ha colocado el contenedor
	return maxi(2, int(floorf((ancho + 6.0) / (LADO_CELDA + 6.0))))


# ============================================================
#  EL CICLO DE REPINTADO
# ============================================================

# Guardia de REENTRADA. Un _rebuild puede entrar mientras otro esta a medias (el focus_exited de un
# campo al liberarlo, las señales de red, un _on_* que espera en un await), y entonces el de dentro
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
	_caja_muneco = null   # se va con el vaciado de abajo; la seccion que toque lo volvera a montar
	# El HEADER no se vacia: ahi vive la fila de retratos, que es de la PANTALLA y no de la seccion.
	# Vaciarlo liberaba el scroll y su HBox, y el _pintar_retratos de dos lineas mas abajo se
	# encontraba con nodos ya muertos. Los retratos se repintan solos (_pintar_retratos vacia SU fila).
	MenuScaffold.vaciar(_lista)
	MenuScaffold.vaciar(_content)
	MenuScaffold.subpestanas(_barra_sub, [], [], 0, Callable())
	for i in _tab_buttons.size():
		(_tab_buttons[i] as Button).button_pressed = (i == _sec)
	_cols_pintadas = _columnas()
	# EL NOMBRE de quien estas mirando, arriba de la columna de secciones. En que seccion estas ya lo
	# dice la pestaña marcada, asi que este rotulo es solo para el "de quien". Las pantallas de dentro
	# (Cambiar) lo pisan con lo que estan haciendo.
	_titulo_seccion.text = _pj().nombre.to_upper()
	_pintar_retratos()

	match _sec:
		SEC_FICHA: _sec_detalles()
		SEC_ARMAS: _sec_arma()
		SEC_HABILIDADES: _sec_trazos()
		SEC_ARMADURA: _sec_armadura()
		SEC_DESARROLLO: _sec_eidolon()


# LA FILA DE RETRATOS: TODA la plantilla, el equipo primero y el hogar detras, con una raya que
# separa los dos grupos. Con una sola persona no se pinta: seria un boton solo que no elige nada.
func _pintar_retratos() -> void:
	MenuScaffold.vaciar(_fila_retratos)
	var todos: Array = _gente()
	if todos.size() <= 1:
		return
	var en_equipo: int = Game.party.size()
	for i in todos.size():
		# LA RAYA entre el equipo y el hogar. Sin ella los doce se leen como una lista sola y no hay
		# forma de saber cual de ellos baja hoy contigo.
		if i == en_equipo and i > 0:
			var sep := VSeparator.new()
			sep.add_theme_constant_override("separation", 14)
			_fila_retratos.add_child(sep)
		_retrato(todos[i], i, i < en_equipo)


# UN RETRATO: la CARA de la persona en un cuadro, con su nombre debajo. Es un Button con el estilo
# quitado y el dibujo a mano, igual que CeldaObjeto.
func _retrato(pj: PersonajeData, i: int, en_equipo: bool) -> void:
	var elegido: bool = (i == _pj_sel)

	var b := Button.new()
	b.custom_minimum_size = Vector2(LADO_RETRATO, ALTO_RETRATO)
	b.clip_contents = true
	b.tooltip_text = "%s%s  ·  %s" % ["👑 " if pj == Game.lider() else "", pj.nombre,
		"en el equipo" if en_equipo else "en el hogar"]
	for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
	b.pressed.connect(_pick_persona.bind(i))
	_fila_retratos.add_child(b)

	b.draw.connect(func() -> void:
		var w: float = b.size.x
		var lado: float = LADO_RETRATO
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.13, 0.14, 0.19, 1.0) if elegido else Color(0.08, 0.09, 0.12, 1.0)
		sb.border_color = AMBAR if elegido else Color(1, 1, 1, 0.14)
		sb.set_border_width_all(2 if elegido else 1)
		# Esquinas SUAVES y no un circulo: el recorte del marco es cuadrado (un Control no recorta en
		# redondo), asi que con el cuadro redondo las esquinas del muñeco se salian por fuera y el
		# circulo dejaba de leerse. Ademas es la misma forma que las celdas del inventario.
		sb.set_corner_radius_all(10)
		b.draw_style_box(sb, Rect2(Vector2.ZERO, Vector2(w, lado)))
		var f: Font = b.get_theme_font(&"font")
		# EL NOMBRE DEBAJO, recortado si no cabe. Es lo que de verdad distingue a uno de otro: con
		# cuatro muñecos del mismo tamaño y la misma pose, el color del pelo no llega.
		var nom: String = pj.nombre
		var an: float = f.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		while an > w and nom.length() > 2:
			nom = nom.substr(0, nom.length() - 1)
			an = f.get_string_size(nom + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		if nom != pj.nombre:
			nom += "…"
		b.draw_string(f, Vector2((w - an) * 0.5, lado + 14.0), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			AMBAR if elegido else Color(0.82, 0.85, 0.90))
		# La CORONA del que va en cabeza, arriba a la derecha del cuadro.
		if pj == Game.lider():
			b.draw_circle(Vector2(w - 11.0, 11.0), 7.0, Color(0.03, 0.04, 0.06, 0.9))
			b.draw_string(f, Vector2(w - 14.0, 15.0), "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, AMBAR)
		# Los del HOGAR, atenuados: siguen siendo tuyos y se les puede tocar el equipo, pero hoy no
		# bajan. El velo lo dice sin quitarles el nombre ni apagar el boton.
		if not en_equipo:
			b.draw_rect(Rect2(Vector2.ZERO, Vector2(w, lado)), Color(0.05, 0.05, 0.07, 0.38)))

	# EL MUÑECO va en SU PROPIO recuadro recortador, no colgado del boton: el boton mide mas que el
	# cuadro (lleva el nombre debajo), asi que recortando con el la figura invadia el nombre y lo
	# tapaba -- los hijos de un CanvasItem se dibujan DESPUES del padre.
	var marco := Control.new()
	marco.custom_minimum_size = Vector2(LADO_RETRATO, LADO_RETRATO)
	marco.size = Vector2(LADO_RETRATO, LADO_RETRATO)
	marco.clip_contents = true
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(marco)

	var mu := MunecoJugador.new()
	mu.montar(pj)
	mu.tenir(pj.color, 0.0)
	mu.poner_cara(pj.textura())
	if mu.hay_dibujo():
		# LA CARA, encuadrada. Mirando al SUR ("idle_0"): es la unica direccion en la que se te ve la
		# cara de frente (ver MunecoJugador.CARA_DIRS, donde 0 = S y 4 = N). Un retrato de espaldas no
		# es un retrato, y de espaldas es justo como estaba.
		#
		# Se escala grande y se baja el origen para que el recorte deje SOLO la cabeza y los hombros:
		# el cuerpo entero en 74 px es un monigote en el que no se distingue quien es.
		# EL ENCUADRE VA MEDIDO, no calculado con ALTO_MUNDO: el dibujo real no ocupa esos 60 px por
		# encima del origen (el lienzo horneado tiene sus propios margenes), asi que la cuenta "teorica"
		# dejaba fuera justo la cara. Estos dos numeros salen de mirar la captura: con esta escala, la
		# cara cae en el centro del cuadro y se ven cabeza y hombros.
		var esc: float = LADO_RETRATO * 2.1 / PoseJugador.ALTO_MUNDO
		mu.scale = Vector2.ONE * esc
		mu.position = Vector2(LADO_RETRATO * 0.5, LADO_RETRATO * 1.02)
		mu.animar("idle_0")
		marco.add_child(mu)
	else:
		mu.queue_free()


# ============================================================
#  1 · DETALLES
# ============================================================

func _sec_detalles() -> void:
	var pj: PersonajeData = _pj()
	var c: Combatant = _combatiente()

	# --- CENTRO: el muñeco y sus barras ---
	# EL MUÑECO SOLO. Sin barras debajo: son NUMEROS, y los numeros van todos juntos en la ficha de la
	# derecha (la vida y el maná estan ahi, con el resto). Aqui lo unico que se mira es a la persona,
	# asi que se le deja la columna entera y se pinta lo mas grande que quepa.
	_muneco_grande(pj)

	# --- DERECHA: nombre, nivel y las dos paginas ---
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 8)
	var n := Label.new()
	n.text = pj.nombre
	n.add_theme_font_size_override("font_size", 20)
	n.add_theme_color_override("font_color", Color(0.94, 0.95, 0.98))
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(n)
	var nv := Label.new()
	nv.text = "Nv. %d" % pj.level
	nv.add_theme_font_size_override("font_size", 15)
	nv.add_theme_color_override("font_color", AMBAR)
	cab.add_child(nv)
	_content.add_child(cab)

	# Las dos pastillas, como en la referencia: la activa blanca y la otra hueca.
	var paginas := HBoxContainer.new()
	paginas.add_theme_constant_override("separation", 8)
	paginas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(paginas)
	for i in 2:
		# "Básicas" y no "Habilidades" a secas: en la columna de la izquierda hay una seccion que se
		# llama asi (las del ARMA), y dos cosas distintas con el mismo nombre en la misma pantalla no
		# las distingue nadie. Las cinco de DanMachi son las "habilidades basicas" en todo el juego.
		var txt: String = "Atributos" if i == 0 else "Básicas"
		var p: Button = MenuScaffold.pastilla(paginas, txt, _pagina_a.bind(i), i == _pagina)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(HSeparator.new())

	if _pagina == 0:
		_pagina_atributos(c)
	else:
		_pagina_habilidades(c)


func _pagina_a(i: int) -> void:
	if i == _pagina:
		return
	_pagina = i
	_rebuild()


# LOS ATRIBUTOS PRINCIPALES, SEGUN EL ARMA. Con baston o varita no se enseña el ataque fisico ni el
# critico fisico, sino sus gemelos MAGICOS: son los numeros con los que de verdad peleas, y el
# "Ataque total" de un baston (motion value 0.4) no dice nada de lo que haces con el.
#
# Lo que NO se esconde nunca: vida, defensa y defensa magica. La defensa magica no es una stat de
# mago -- es lo que te protege cuando el que lanza el hechizo es el otro.
#
# El resto (las cuatro filas de la otra mitad, la esquiva, los estados) sale en la LUPA, que las
# enseña todas lleves lo que lleves: es el sitio donde el mago mira sus numeros fisicos.
#
# Cada cuenta es la MISMA llamada que hace combate_detalle._rejilla_stats. Ninguna se reescribe aqui.
func _pagina_atributos(c: Combatant) -> void:
	var pj: PersonajeData = _pj()
	var magico: bool = Game.lleva_arma_magica(pj)
	_row("Vida máx.", "%.0f" % c.max_hp)
	# MANA Y ENERGIA aqui, con el resto de numeros: son atributos como los demas y las barras de
	# debajo del muñeco se fueron (ver _sec_detalles). El maná solo si lo tiene.
	if c.max_mp > 0.0:
		_row("Maná máx.", "%.0f" % c.max_mp)
	_row("Energía máx.", "%.0f" % _energia_max(pj))
	if magico:
		_row("Ataque mágico", "%.0f" % MenuScaffold.dano_magico(pj))
	else:
		_row("Ataque", "%.0f" % _ataque_total(c))
	_row("Defensa", "%.0f" % c.def_value())
	_row("Defensa mágica", "%.0f" % StatsMath.magic_jugador(c.abilities_eff(), c.base_magic))
	if magico:
		_row("Vel. recitado", "%.1f" % c.cast_spd())
		_row("Prob. crít. mágico", _fmt_pct(_crit_magico(c)))
		_row("Daño crít. mágico", _crit_dmg_txt(c.crit_dmg_magico))
	else:
		_row("Velocidad", "%.0f" % c.spd())
		_row("Prob. crítico", _fmt_pct(_crit_fisico(c)))
		_row("Daño crítico", _crit_dmg_txt(c.crit_dmg))
	if c.mp_regen_turno > 0.0:
		_row("Regen maná", "%.2f/turno" % c.mp_regen_turno)

	# LA LUPA. Nada puede quedar por debajo: es el final de la lista. Y sin coletilla debajo: lo que
	# hace el boton se entiende pulsandolo, y un parrafo explicando el critico en cada apertura de la
	# ficha es texto que se lee una vez y estorba las otras cien.
	var lupa := HBoxContainer.new()
	lupa.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(HSeparator.new())
	_content.add_child(lupa)
	var b: Button = MenuScaffold.pastilla(lupa, "⌕  Información", _abrir_modal_atributos, false)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL


# LA ENERGIA MAXIMA no sale del Combatant: crear_player_combatant la deja a CERO y se la inyecta
# start_combat leyendo el aguante del mapa (ver game.gd, donde se hace lo mismo para quien se une a
# mitad de pelea). Por eso la lupa ponia siempre "0". Aqui se pide por la misma via.
func _energia_max(pj: PersonajeData) -> float:
	var pl: Node = get_tree().get_first_node_in_group("player")
	if pl == null or not pl.has_method("aguante_de_grupo"):
		return 0.0
	return maxf(0.0, (pl.aguante_de_grupo(pj) as Vector2).y)


# LAS 5 HABILIDADES, con su rango por letra y lo que aporta cada una AHORA MISMO.
#
# Los aportes salen por DIFERENCIA (ver _sin_habilidad) y no reescribiendo formulas, que es de donde
# venia el desfase viejo: la pagina calculaba con las formulas ADITIVAS (las de los enemigos) y el
# jugador usa las MULTIPLICATIVAS. Por diferencia da igual cual sea la formula: sale la de verdad.
#
# Las EFECTIVAS (con los platos puestos) y no las crudas: es lo que el juego usa de verdad, asi que
# si aqui se leyeran las crudas la ficha diria un numero y el combate haria otro.
func _pagina_habilidades(c: Combatant) -> void:
	var ab: Abilities = c.abilities_eff()

	# FUERZA -> ataque fisico. Como fuerza_factor(0) == 1, lo que aporta es todo lo que el ataque
	# total tiene por encima del raw pelado (base + arma).
	_fila_habilidad("Fuerza", "fuerza", ab)
	var atk_sin: float = (c.base_attack + c.ataque_arma) * c.status_atk_mult()
	_aporte("+%.1f ataque" % (_ataque_total(c) - atk_sin))

	# RESISTENCIA -> vida y defensa.
	_fila_habilidad("Resistencia", "resistencia", ab)
	var ab_sin_res: Abilities = _sin_habilidad(ab, "resistencia")
	var hp_de_res: float = c.max_hp - StatsMath.max_hp_jugador(ab_sin_res, _pj().base_hp)
	var def_base: float = c.base_defense + c.extra_defense
	var def_de_res: float = (StatsMath.defense_jugador(ab, def_base)
		- StatsMath.defense_jugador(ab_sin_res, def_base)) * c.status_def_mult()
	_aporte("+%.1f vida  ·  +%.1f defensa" % [hp_de_res, def_de_res])

	# DESTREZA -> critico. Es un DUELO (tu Destreza contra la Agilidad del que recibe el golpe), asi
	# que sin rival delante se mide contra un maniqui con tus mismas stats.
	_fila_habilidad("Destreza", "destreza", ab)
	_aporte("~%s de crítico" % _fmt_pct(StatsMath.crit_chance(float(ab.destreza),
		float(ab.agilidad))))

	# AGILIDAD -> esquiva (el duelo espejo del critico) y velocidad de turno.
	_fila_habilidad("Agilidad", "agilidad", ab)
	var evade_espejo: float = StatsMath.evade_chance(float(ab.agilidad), float(ab.destreza))
	# Lo que aporta a la VELOCIDAD, no la velocidad total. Todo lo que multiplica detras de
	# _spd_base() (arma, armadura, estados, guardia) es comun a las dos ramas, asi que basta la
	# proporcion entre la velocidad cruda con y sin Agilidad.
	var spd_con: float = StatsMath.speed_jugador(ab, c.base_speed)
	var spd_sin: float = StatsMath.speed_jugador(_sin_habilidad(ab, "agilidad"), c.base_speed)
	var vel_de_agi: float = c.spd() * (1.0 - (spd_sin / spd_con if spd_con > 0.0 else 1.0))
	_aporte("~%s de esquiva  ·  +%.1f velocidad" % [_fmt_pct(evade_espejo), vel_de_agi])

	# MAGIA -> daño de hechizos, maná y defensa magica.
	_fila_habilidad("Magia", "magia", ab)
	var ab_sin_mag: Abilities = _sin_habilidad(ab, "magia")
	var mp_de_mag: float = c.max_mp - StatsMath.max_mp_jugador(ab_sin_mag, _pj().base_mp)
	var mdef_de_mag: float = StatsMath.magic_jugador(ab, c.base_magic) \
		- StatsMath.magic_jugador(ab_sin_mag, c.base_magic)
	_aporte("×%.2f a los hechizos  ·  +%.1f maná  ·  +%.1f def. mágica" % [
		StatsMath.magia_factor(float(ab.magia)), mp_de_mag, mdef_de_mag])


# LO QUE ESA HABILIDAD TE ESTA DANDO AHORA MISMO, en una linea y sin explicar de donde sale. La
# version larga (un parrafo por habilidad contando que hace cada una) se leia una vez y estorbaba
# las otras cien: lo que se viene a mirar aqui es el numero.
func _aporte(txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", Color(0.55, 0.78, 0.6))
	l.add_theme_font_size_override("font_size", 12)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(l)


# Una fila de habilidad: el valor, su LETRA de rango y, si hay platos puestos, lo que suman entre
# parentesis ("180 (+18)  ·  H").
#
# El parentesis existe porque no habia forma de saber si un plato hacia algo: te lo comias, la ficha
# seguia diciendo el mismo numero y solo cambiaba el peso que podias cargar. Sale por DIFERENCIA
# contra la stat cruda para que no haya dos formulas que puedan discrepar. Y en rojo si es negativa,
# porque por aqui pasan tambien los debuffs.
func _fila_habilidad(nombre: String, clave: String, ab_eff: Abilities) -> void:
	var crudo: int = int(_pj().get(clave))
	var eff: int = int(ab_eff.get(clave))
	var rango: String = Abilities.rank_letter(eff)
	if eff == crudo:
		_row(nombre, "%d   ·   %s" % [crudo, rango])
		return
	var delta: int = eff - crudo
	_row(nombre, "%d (%+d)   ·   %s" % [crudo, delta, rango],
		Color(0.5, 0.9, 0.5) if delta > 0 else Color(0.95, 0.45, 0.45))


# EL MUÑECO EN GRANDE, con su sombra. Es lo mismo que hacen las tarjetas del modal de "a quien se lo
# das" del inventario, en grande: escala contra PoseJugador.ALTO_MUNDO y se apoya por los pies, que
# son su propio origen.
func _muneco_grande(pj: PersonajeData) -> void:
	var caja := Control.new()
	caja.custom_minimum_size = Vector2(0, ALTO_MUNECO)
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.clip_contents = true
	_lista.add_child(caja)

	# El SUELO: una elipse tenue bajo los pies. Sin ella la figura flota en un rectangulo vacio y no
	# hay forma de saber a que altura esta apoyada.
	caja.draw.connect(func() -> void:
		var w: float = caja.size.x
		var h: float = caja.size.y
		if w <= 1.0:
			return
		var pies: float = _pies_y if _pies_y > 0.0 else h - MARGEN_MUNECO
		for i in 3:
			var t: float = 1.0 - float(i) / 3.0
			caja.draw_set_transform(Vector2(w * 0.5, pies), 0.0, Vector2(1.0, 0.22))
			caja.draw_circle(Vector2.ZERO, w * 0.20 * (0.6 + t * 0.6), Color(0.55, 0.62, 0.80, 0.05))
		caja.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE))
	caja.resized.connect(caja.queue_redraw)

	var mu := MunecoJugador.new()
	mu.montar(pj)
	mu.tenir(pj.color, 0.0)
	mu.poner_cara(pj.textura())
	if not mu.hay_dibujo():
		mu.queue_free()
		return
	caja.add_child(mu)
	# MIRANDO AL SUR ("idle_0"). Es la unica dirección en la que se te ve la cara de frente: ver
	# MunecoJugador.CARA_DIRS, donde 0 = S y 4 = N. Estaba puesto el 4, o sea de espaldas.
	mu.animar("idle_0")
	_caja_muneco = caja
	# El tamaño real de la caja no se sabe hasta que el contenedor la coloca (mismo motivo por el que
	# brillo_en se reajusta en resized), asi que la colocacion se rehace con el layout.
	var colocar := func() -> void:
		# LA ESCALA SALE DE LO QUE MIDE EL DIBUJO ENTERO, no solo del cuerpo. El muñeco ocupa
		# ALTO_MUNDO por encima de su origen y PIES_BAJO_NODO por debajo (ver pose_jugador.gd: lo
		# comparten sus ~35 capas), asi que lo que tiene que caber son las dos cosas. Midiendo solo
		# con ALTO_MUNDO, los pies se salian de la caja -- que recorta -- y la figura quedaba cortada
		# por los tobillos.
		var alto_dibujo: float = PoseJugador.ALTO_MUNDO + PoseJugador.PIES_BAJO_NODO
		var esc: float = minf(maxf(caja.size.y - MARGEN_MUNECO * 2.0, 120.0) / alto_dibujo,
			ESCALA_MUNECO)
		mu.scale = Vector2.ONE * esc
		# El ORIGEN (los pies) queda justo debajo del cuerpo: margen + lo que mide de origen hacia
		# arriba. Asi la cabeza cae en el margen de arriba y los pies, con su cola, en el de abajo.
		_pies_y = MARGEN_MUNECO + PoseJugador.ALTO_MUNDO * esc
		mu.position = Vector2(caja.size.x * 0.5, _pies_y)
		caja.queue_redraw()   # la sombra se pinta a la altura de los pies, que acaba de cambiar
	caja.resized.connect(colocar)
	colocar.call()


# ============================================================
#  LA LUPA: informacion de los atributos
#  Aqui sale TODO -- fisico y magico --, lleves baston o no. La pagina de fuera enseña la mitad que
#  te toca; esta es la otra respuesta: la del mago que quiere ver sus numeros fisicos y la del
#  guerrero que quiere saber cuanto le entra un hechizo.
#
#  Es hermana de combate_detalle._abrir_modal_atributos y dice los MISMOS numeros con las MISMAS
#  llamadas. Si se toca una cuenta, hay que tocar las dos.
# ============================================================

func _abrir_modal_atributos() -> void:
	_cerrar_modal()
	var pj: PersonajeData = _pj()
	var c: Combatant = _combatiente()
	var m: Dictionary = MenuScaffold.modal(_root, "Información de los atributos", 640.0)
	_modal = m["capa"]
	_ver_muneco(false)

	# Con scroll: son mas de veinte filas y en una ventana baja no caben. El alto se acota para que
	# el modal no crezca hasta comerse la pantalla entera.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 420)
	(m["cuerpo"] as VBoxContainer).add_child(scroll)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vb)

	MenuScaffold.titulo(vb, "Atributos base", 13, GRIS)
	MenuScaffold.fila(vb, "  Vida máxima", "%.0f" % c.max_hp, 200)
	MenuScaffold.fila(vb, "  Ataque", "%.0f" % _ataque_total(c), 200)
	MenuScaffold.fila(vb, "  Ataque mágico", "%.0f" % MenuScaffold.dano_magico(pj), 200)
	MenuScaffold.fila(vb, "  Defensa", "%.0f" % c.def_value(), 200)
	MenuScaffold.fila(vb, "  Defensa mágica",
		"%.0f" % StatsMath.magic_jugador(c.abilities_eff(), c.base_magic), 200)
	MenuScaffold.fila(vb, "  Velocidad", "%.0f" % c.spd(), 200)
	MenuScaffold.fila(vb, "  Vel. recitado", "%.1f" % c.cast_spd(), 200)
	if c.max_mp > 0.0:
		MenuScaffold.fila(vb, "  Maná máximo", "%.0f" % c.max_mp, 200)
	# Por _energia_max y NO por c.max_energy: el combatiente recien creado la trae a cero (se la
	# inyecta start_combat), asi que esta fila ponia "0" siempre.
	MenuScaffold.fila(vb, "  Energía máxima", "%.0f" % _energia_max(pj), 200)

	vb.add_child(HSeparator.new())
	MenuScaffold.titulo(vb, "Atributos avanzados", 13, GRIS)
	MenuScaffold.fila(vb, "  Prob. crítico", _fmt_pct(_crit_fisico(c)), 200)
	MenuScaffold.fila(vb, "  Daño crítico", _crit_dmg_txt(c.crit_dmg), 200)
	MenuScaffold.fila(vb, "  Prob. crít. mágico", _fmt_pct(_crit_magico(c)), 200)
	MenuScaffold.fila(vb, "  Daño crít. mágico", _crit_dmg_txt(c.crit_dmg_magico), 200)
	# La esquiva contra el mismo espejo, con su tope: con bonus de esquiva el techo sube
	# (StatsMath.EVADE_MAX_BUFF), y sin decirlo el numero parecia clavado.
	var cap: float = StatsMath.EVADE_MAX_BUFF if c.evasion_bonus > 0.0 else StatsMath.EVADE_MAX
	var evade: float = clampf(StatsMath.evade_chance(float(c.abilities.agilidad),
		float(c.abilities.destreza)) - c.evasion_penal + c.evasion_bonus, 0.0, cap)
	MenuScaffold.fila(vb, "  Prob. esquiva", _fmt_pct(evade), 200)
	# El aporte del EQUIPO a la esquiva: va en evasion_penal (negativo = bonus de daga/estoque o de
	# armadura ligera; positivo = lo que estorba un escudo). Sin esta linea se fundia en el total.
	if absf(c.evasion_penal) > 0.001:
		MenuScaffold.fila(vb, "     · del equipo", "%+.0f%%" % (-c.evasion_penal * 100.0), 200)
	MenuScaffold.fila(vb, "  Reducción de daño", _fmt_pct(c.armor_reduction), 200)
	if c.crit_resist > 0.001:
		MenuScaffold.fila(vb, "  Resist. crítico", _fmt_pct(c.crit_resist), 200)
	# OJO con la unidad: NO es "el % de veces que resistes". La formula es un cociente (ver
	# StatusEffects.prob_final), asi que 100% quiere decir "me entran a la mitad" y puede pasar del
	# 100% sin volverte inmune nunca. Por eso va el "×" al lado: es lo que multiplica.
	MenuScaffold.fila(vb, "  Resist. estados", "%s   (los recibes ×%.2f)" % [
		_fmt_pct(c.resist_estados()), 1.0 / (1.0 + c.resist_estados())], 200)
	MenuScaffold.fila(vb, "  Eficacia (estados)", "%s   (los aplicas ×%.2f)" % [
		_fmt_pct(c.eficacia_estados()), 1.0 + c.eficacia_estados()], 200)
	MenuScaffold.fila(vb, "  Regen maná", "%.2f/turno" % c.mp_regen_turno, 200)
	# El COSTE DE MANA se queda (es un numero que te cambia lo que puedes lanzar), pero el bloque de
	# "Poder mágico" y su desglose se fueron: el ataque mágico ya sale arriba en la misma moneda que
	# el físico, y el multiplicador en crudo solo servia para explicar de donde salia ese numero.
	var lm: Dictionary = Game.loadout_mods(pj)
	if float(lm["mana_reduccion"]) > 0.0:
		MenuScaffold.fila(vb, "  Coste de maná",
			"-%.0f%%" % (float(lm["mana_reduccion"]) * 100.0), 200)

	MenuScaffold.pastilla(m["acciones"], "Cerrar", _cerrar_modal)


func _cerrar_modal() -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null
	_ver_muneco(true)


# Esconde o enseña TODOS los muñecos de la pantalla: el grande y los de los retratos. Ver
# _caja_muneco: su z_index es absoluto y se cuela por delante de cualquier modal, asi que la unica
# forma de que no tapen es no dibujarlos. Los retratos entran por lo mismo -- se dibujaban encima de
# la cabecera del modal de la lupa.
func _ver_muneco(visible_: bool) -> void:
	if _caja_muneco != null and is_instance_valid(_caja_muneco):
		_caja_muneco.visible = visible_
	if _scroll_retratos != null and is_instance_valid(_scroll_retratos):
		_scroll_retratos.visible = visible_


# ============================================================
#  2 · ARMA   (las dos manos)
# ============================================================

func _sec_arma() -> void:
	if _cambiando:
		_cambiar_arma()
		return
	var pj: PersonajeData = _pj()
	_sel = clampi(_sel, 0, 1)

	# CENTRO: una celda por mano. Un hueco vacio se pinta igual (celda gris con su rotulo): es lo que
	# dice que ahi CABE algo, que es justo lo que hay que ver para ir a ponerlo.
	var piezas: Array = [
		_celda_equipo(pj.equipped_main, "Principal", _main_nombre(pj.equipped_main)),
		_celda_equipo(pj.equipped_off, "Secundaria", _off_nombre(pj.equipped_off)),
	]
	MenuScaffold.rejilla_objetos(_lista, piezas, _sel, _pick, _columnas(), LADO_CELDA)

	# LA VELOCIDAD DEL CONJUNTO, que no es la de ninguna de las dos armas por separado: lleva dentro
	# el bonus de ir a dual, lo que aporta la secundaria por su tamaño y las mejoras de Rapidez de las
	# dos manos (la de la izquierda, a mitad). Sin esta linea el jugador ve dos fichas con dos numeros
	# y ninguno es el que manda.
	var lm: Dictionary = Game.loadout_mods(pj)
	MenuScaffold.fila(_lista, "Velocidad del conjunto", "×%.2f" % float(lm["velocidad_mult"]))
	if pj.equipped_off is WeaponData:
		MenuScaffold.nota(_lista, "Vas a dos armas: se alternan golpe a golpe, cada una con su daño "
			+ "y su crítico. La mejora de Rapidez de la secundaria cuenta la mitad que la de la "
			+ "principal.")

	# DERECHA: la ficha de la mano elegida.
	var es_main: bool = (_sel == 0)
	var item: Resource = pj.equipped_main if es_main else pj.equipped_off
	if item == null:
		_title("Principal" if es_main else "Secundaria")
		_note("Sin arma: peleas a puños (poco daño, pero rápido y sin peso)." if es_main
			else "Sin mano secundaria. Ahí caben otra arma, un escudo o una varita.")
	else:
		MenuScaffold.titulo_item(_content, Game.item_display_name(item),
			Game.color_rareza_de(item), Game.intensidad_rareza_de(item), 17)
		MenuScaffold.banner_item(_content, item, Game.item_plus(item),
			"Principal" if es_main else "Secundaria")
		if es_main:
			_weapon_stats(_content, item as WeaponData)
		else:
			_off_stats(_content, item)

	# El boton de cambiar. Con el arma principal a dos manos NO hay secundaria que cambiar: se dice y
	# se apaga, en vez de dejar entrar a una rejilla donde nada se puede equipar.
	var dos_manos: bool = Game.arma_main(pj).dos_manos and pj.equipped_main != null
	var pueblo: bool = Game.en_pueblo()
	_content.add_child(HSeparator.new())
	if not es_main and dos_manos:
		_note("El arma principal es a dos manos: no admite secundaria.")
		return
	if not pueblo:
		_note("Cambios de equipo solo en el pueblo. Aquí es solo consulta.")
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(fila)
	var b: Button = MenuScaffold.pastilla(fila, "Cambiar", _abrir_cambio, true, pueblo)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _abrir_cambio() -> void:
	_cambiando = true
	_cand = _indice_equipado()
	_rebuild()


func _cancelar_cambio() -> void:
	_cambiando = false
	_rebuild()


func _pick_cand(i: int) -> void:
	_cand = i
	_rebuild()


# El catalogo del que se elige AHORA: el del arma de la mano elegida, o el del slot de armadura. Es
# UNA sola funcion para las dos secciones a proposito -- la mecanica (rejilla del baul, ficha,
# equipar o desequipar) es identica, y tenerla dos veces es tenerla desincronizada.
func _catalogo() -> Array:
	if _sec == SEC_ARMADURA:
		return Game.owned_armor_de_slot(ARMOR_SLOTS[clampi(_sel, 0, 4)])
	if _sel == 0:
		# Armas validas como PRINCIPAL: solo las WeaponData del baul.
		var r: Array = []
		for it in Game.owned_weapons:
			if it is WeaponData:
				r.append(it)
		return r
	# Manos SECUNDARIAS: todo el baul (la validez la filtra _secundaria_valida).
	var todo: Array = []
	for it in Game.owned_weapons:
		todo.append(it)
	return todo


# Lo que llevas puesto AHORA en la mano / el slot elegido.
func _equipado() -> Resource:
	var pj: PersonajeData = _pj()
	if _sec == SEC_ARMADURA:
		return pj.get("equipped_" + ARMOR_SLOTS[clampi(_sel, 0, 4)]) as Resource
	return (pj.equipped_main if _sel == 0 else pj.equipped_off) as Resource


# Deja el candidato en lo que ya llevas puesto (o en lo primero del baul si no llevas nada), para que
# la rejilla abra siempre con stats a la vista.
func _indice_equipado() -> int:
	var puesto: Resource = _equipado()
	var cat: Array = _catalogo()
	for i in cat.size():
		if cat[i] == puesto:
			return i
	return 0


# True si el candidato marcado ahora mismo es justo lo que ya llevas. Entonces el boton no equipa:
# DESEQUIPA. Asi quedarse a puños (o sin pieza) no necesita una entrada falsa de "nada" en la
# rejilla: es el mismo boton, que se da la vuelta.
func _cand_equipado() -> bool:
	var cat: Array = _catalogo()
	if _cand < 0 or _cand >= cat.size():
		return false
	return cat[_cand] == _equipado()


# LA PANTALLA DE CAMBIAR, comun a armas y armadura: la rejilla del baul a la izquierda y la ficha del
# candidato con Equipar/Cancelar a la derecha. Es la forma de la captura "Cambiar cono de luz".
func _cambiar_arma() -> void:
	var pj: PersonajeData = _pj()
	var es_armadura: bool = (_sec == SEC_ARMADURA)
	var cat: Array = _catalogo()
	var rotulo: String = ""
	if es_armadura:
		rotulo = ARMOR_SLOT_LABELS[ARMOR_SLOTS[clampi(_sel, 0, 4)]]
	else:
		rotulo = "Arma principal" if _sel == 0 else "Mano secundaria"
	_titulo_seccion.text = "CAMBIAR: %s" % rotulo.to_upper()

	if cat.is_empty():
		_note_en(_lista, "No tienes nada de esto en el baúl.")
		var f0 := HBoxContainer.new()
		f0.alignment = BoxContainer.ALIGNMENT_CENTER
		_content.add_child(f0)
		MenuScaffold.pastilla(f0, "Volver", _cancelar_cambio, false)
		return
	_cand = clampi(_cand, 0, cat.size() - 1)

	# La rejilla. El candado de la esquina dice "esto se lo estas quitando a alguien" sin tener que
	# leer el nombre entero (ver _quien_lleva): desnudar a un companero por un clic de mas es el error
	# que hay que evitar, y al volver a la mazmorra ya no hay forma de deshacerlo.
	var piezas: Array = []
	for i in cat.size():
		var it: Resource = cat[i]
		var otro: PersonajeData = Game.quien_lleva(it)
		var activo: bool = true
		# Las secundarias incompatibles con la principal se dejan VER pero no elegir.
		if not es_armadura and _sel == 1 and not Game._secundaria_valida(pj.equipped_main, it):
			activo = false
		piezas.append({
			"item": it, "pie": Game.item_plus(it),
			"tooltip": _etiqueta_con_dueno(it, Game.item_display_name(it)),
			"marca": "" if otro == null else otro.nombre, "activo": activo,
		})
	MenuScaffold.rejilla_objetos(_lista, piezas, _cand, _pick_cand, _columnas(), LADO_CELDA)

	# La ficha del candidato.
	var item: Resource = cat[_cand]
	MenuScaffold.titulo_item(_content, Game.item_display_name(item),
		Game.color_rareza_de(item), Game.intensidad_rareza_de(item), 17)
	MenuScaffold.banner_item(_content, item, Game.item_plus(item), rotulo)
	_aviso_dueno(item)
	if es_armadura:
		_armor_stats(_content, item as ArmorData)
	elif _sel == 0:
		_weapon_stats(_content, item as WeaponData)
	else:
		_off_stats(_content, item)

	# Los avisos de "esto ya lo llevas" / "esto no encaja", que es lo que explica el boton de abajo.
	if item == _equipado():
		if es_armadura:
			_note("Ya la llevas puesta: al quitarla vas ligero (+velocidad, 0 defensa).")
		elif _sel == 0:
			_note("Ya la llevas puesta: al desequiparla pelearás a puños.")
		else:
			_note("Ya la llevas puesta: al desequiparla te quedas con la mano libre.")
	elif not es_armadura and _sel == 1:
		if item == pj.equipped_main:
			_note("Ya la llevas en la mano principal: necesitas otra igual para el dual.")
		elif not Game._secundaria_valida(pj.equipped_main, item):
			_note("No compatible con el arma principal actual.")

	var pueblo: bool = Game.en_pueblo()
	if not pueblo:
		_note("Cambios de equipo solo en el pueblo. Aquí es solo consulta.")
	_content.add_child(HSeparator.new())
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	_content.add_child(fila)
	var puede: bool = pueblo and (es_armadura or _sel == 0
		or Game._secundaria_valida(pj.equipped_main, item) or item == _equipado())
	var eq: Button = MenuScaffold.pastilla(fila,
		"Desequipar" if _cand_equipado() else "Equipar", _equipar, true, puede)
	eq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ca: Button = MenuScaffold.pastilla(fila, "Cancelar", _cancelar_cambio, false)
	ca.size_flags_horizontal = Control.SIZE_EXPAND_FILL


# Equipar el candidato... o DESEQUIPAR, si es justo lo que ya llevas puesto.
func _equipar() -> void:
	var cat: Array = _catalogo()
	if _cand < 0 or _cand >= cat.size():
		return
	var elegido: Resource = null if _cand_equipado() else cat[_cand]
	var es_armadura: bool = (_sec == SEC_ARMADURA)
	var slot: String = ARMOR_SLOTS[clampi(_sel, 0, 4)]
	var es_main: bool = (_sel == 0)
	# Si lo lleva otro, se pregunta antes: el modal llama a esto solo si dices que si.
	_confirmar_robo(elegido, func():
		if es_armadura:
			Game.equipar_armadura(slot, elegido as ArmorData, _pj())
		elif es_main:
			Game.equipar_arma(elegido as WeaponData, _pj())
		else:
			Game.equipar_secundaria(elegido, _pj())
		_cambiando = false
		_rebuild()
		_refrescar_mundo())


# ============================================================
#  3 · TRAZOS   (las habilidades que llevas equipadas)
# ============================================================

func _sec_trazos() -> void:
	var pj: PersonajeData = _pj()
	# LAS SUBPESTAÑAS SOLO SI HAY MAGIAS. Con una sola lista, una fila de un icono solo no elige
	# nada: la fila entera desaparece y el kit del arma ocupa la pantalla.
	var con_magia: bool = Game.tiene_hechizos(pj)
	if con_magia:
		MenuScaffold.subpestanas(_barra_sub, ["Habilidades", "Magias"], ["espada", "varita"],
			_sub, _on_sub)
	else:
		_sub = 0
	if con_magia and _sub == 1:
		_trazos_magias(pj)
		return
	_trazos_habilidades(pj)


# ============================================================
#  EL KIT: los huecos arriba y lo que puedes meter en ellos abajo
#
#  Las dos subpestañas (habilidades de arma y magias) son LA MISMA pantalla con dos listas
#  distintas, y por eso comparten codigo: arriba las ranuras —vacias incluidas, que son las que
#  dicen cuantas te faltan por poner— y debajo todo lo que puedes colocar. Pulsas una, la ficha
#  sale a la derecha, y el boton de abajo la mete o la saca.
#
#  SOLO EN EL PUEBLO, como el resto del equipo: fuera se ve pero no se toca.
#
#  '_kit' es lo que hay pintado AHORA, en el mismo orden en que se pinto, y '_sel' es un indice
#  suyo. Van juntos a proposito: es lo que garantiza que la celda que pulsas y la ficha que sale
#  sean la misma cosa (misma regla que _stacks en el inventario).
# ============================================================

var _kit: Array = []

func _trazos_habilidades(pj: PersonajeData) -> void:
	var puestas: Array = Game.habilidades_equipadas(pj)
	var arma: WeaponData = Game.arma_main(pj)
	var tipo: String = WEAPON_TIPO_LABELS[clampi(int(arma.tipo), 0,
		WEAPON_TIPO_LABELS.size() - 1)]
	# El rotulo dice con QUE arma es este kit porque el set se guarda por TIPO de arma (ver
	# Game.clave_loadout): cambiar de espada a hacha cambia lo que sale aqui, y es a proposito.
	MenuScaffold.titulo(_lista, "Kit de %s" % tipo.to_lower(), 15)
	_pista_arrastre()

	# Lo que su equipo le PERMITE y ademas se sabe. El pool sale del arma y del escudo; el filtro de
	# "desbloqueada" es lo que le ha enseñado el maestro (las `inicial` se saben siempre).
	var disponibles: Array = []
	for ab in Game.pool_habilidades(pj):
		if not puestas.has(ab) and Game.habilidad_desbloqueada(ab, pj):
			disponibles.append(ab)
	_pintar_kit(puestas, disponibles, Game.MAX_HABILIDADES, "hueco",
		"Lo que su equipo le permite", "Su arma no aporta ninguna técnica que sepa usar. "
		+ "El maestro de armas enseña las que faltan.")

	# LA FICHA. El ataque basico va SIEMPRE arriba: no ocupa hueco y es lo que haces cuando no haces
	# nada, asi que callarlo dejaba la pantalla sin la mitad de lo que puedes hacer.
	_title("Ataque básico")
	_note("Golpe con lo que lleves en las manos. No cuesta energía: la recupera.")
	_content.add_child(HSeparator.new())
	_ficha_kit(pj, false)


func _trazos_magias(pj: PersonajeData) -> void:
	MenuScaffold.titulo(_lista, "Magias", 15)
	MenuScaffold.nota(_lista, "Se lanzan RECITANDO su encantamiento: una frase por turno. Si fallas "
		+ "una, el hechizo se te vuelve en contra.")
	_pista_arrastre()
	var puestas: Array = pj.equipped_spells
	var disponibles: Array = []
	for s in Game.hechizos_sabidos(pj):
		if not puestas.has(s):
			disponibles.append(s)
	_pintar_kit(puestas, disponibles, Game.MAX_HECHIZOS, "ranura",
		"Se las sabe, pero no las lleva",
		"Se sabe todas las que lleva puestas. Los grimorios enseñan más.")
	_ficha_kit(pj, true)


# Pinta las dos rejillas y deja '_kit' con lo que hay, en orden. 'puestas' son las que lleva,
# 'disponibles' las que puede meter, 'topes' cuantas ranuras hay.
#
# Las celdas son CeldaKit y no botones normales: se pueden ARRASTRAR de un sitio a otro, que es la
# unica forma comoda de decidir en que hueco va cada cosa (ver celda_kit.gd). El boton de la ficha
# sigue estando para quien no descubra el gesto.
func _pintar_kit(puestas: Array, disponibles: Array, topes: int, palabra: String,
		titulo_pool: String, vacio_pool: String) -> void:
	_kit = []
	var grid := _rejilla_kit()
	for i in topes:
		var it: Resource = puestas[i] if i < puestas.size() else null
		_kit.append({"item": it, "puesto": true})
		_celda_kit(grid, it, i, true,
			_nombre_kit(it) if it != null else "— %s %d —" % [palabra, i + 1])

	_lista.add_child(HSeparator.new())
	MenuScaffold.titulo(_lista, titulo_pool.to_upper(), 14)
	if disponibles.is_empty():
		MenuScaffold.nota(_lista, vacio_pool)
	else:
		var grid2 := _rejilla_kit()
		for j in disponibles.size():
			var it2: Resource = disponibles[j]
			_kit.append({"item": it2, "puesto": false})
			_celda_kit(grid2, it2, j, false, _nombre_kit(it2))
	_sel = clampi(_sel, 0, maxi(_kit.size() - 1, 0))


# El gesto hay que CONTARLO: arrastrar no se ve, y quien no lo sepa se queda con el boton de la
# ficha —que funciona, pero mete siempre en el primer hueco libre y no deja ordenar—. Solo en el
# pueblo, que es donde se puede tocar algo.
func _pista_arrastre() -> void:
	if Game.en_pueblo():
		MenuScaffold.nota(_lista, "Arrastra para colocarlas donde quieras: una encima de otra las "
			+ "cambia de sitio, y sacarla de su ranura la quita.")


func _rejilla_kit() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_child(g)
	return g


# UNA celda del kit. 'pos' es su sitio dentro de SU bloque (el hueco si es ranura, el orden si es
# del pool); el indice de _kit se calcula desde ahi para no llevar dos numeraciones a la vez.
func _celda_kit(grid: GridContainer, it: Resource, pos: int, es_ranura: bool, txt: String) -> void:
	var idx: int = pos if es_ranura else _topes_kit() + pos
	var c := CeldaKit.new()
	c.item = it
	c.indice = pos
	c.es_ranura = es_ranura
	c.arrastrable = (it != null)   # de una ranura vacia no hay nada que coger
	c.text = txt
	c.clip_text = true
	c.custom_minimum_size = Vector2(0, 62)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.toggle_mode = true
	c.button_pressed = (idx == _sel)
	c.tooltip_text = txt if it != null else "Ranura libre  ·  arrastra una aquí"
	c.pressed.connect(_pick.bind(idx))
	c.al_soltar = _soltar_kit.bind(pos, es_ranura)
	grid.add_child(c)


# Cuantas RANURAS tiene la subpestaña abierta. Sale de la seccion y no de un parametro porque lo
# preguntan tres sitios distintos y con tres copias acaban discrepando.
func _topes_kit() -> int:
	return Game.MAX_HECHIZOS if _es_magia() else Game.MAX_HABILIDADES


func _es_magia() -> bool:
	return _sec == SEC_HABILIDADES and _sub == 1


# SE HA SOLTADO algo encima de la celda (destino_pos, destino_ranura). 'it' es lo que venia y
# 'origen_ranura' dice de donde salio. Los cuatro casos:
#
#   pool  -> ranura : se coloca AHI (no en el primer hueco libre): el sitio lo eliges tu.
#   ranura-> ranura : se cruzan, que es lo que espera quien arrastra una encima de otra.
#   ranura-> pool   : se quita de las manos (sigue sabida).
#   pool  -> pool   : nada. El monton de abajo no tiene orden que defender.
func _soltar_kit(it: Resource, _origen_pos: int, origen_ranura: bool,
		destino_pos: int, destino_ranura: bool) -> void:
	if it == null or not Game.en_pueblo():
		return
	var pj: PersonajeData = _pj()
	if destino_ranura:
		if _es_magia():
			Game.colocar_hechizo(it as SpellData, destino_pos, pj)
		else:
			Game.colocar_habilidad(it as AbilityData, destino_pos, pj)
	elif origen_ranura:
		if _es_magia():
			Game.quitar_hechizo(it as SpellData, pj)
		else:
			Game.desequipar_habilidad(it as AbilityData, pj)
	else:
		return   # de abajo a abajo: no hay nada que cambiar
	_rebuild()


# El nombre corto de lo que va en una celda del kit: un hechizo lleva ademas su coste, que es lo
# que decide si lo puedes lanzar hoy.
func _nombre_kit(it: Resource) -> String:
	if it == null:
		return ""
	if it is SpellData:
		return "%s\n%d MP" % [it.nombre, (it as SpellData).coste_mana]
	return str(it.get("nombre"))


# LA FICHA de lo elegido en el kit, con su boton de poner o quitar.
func _ficha_kit(pj: PersonajeData, es_magia: bool) -> void:
	if _sel < 0 or _sel >= _kit.size():
		return
	var e: Dictionary = _kit[_sel]
	var it: Resource = e["item"] as Resource
	var puesto: bool = bool(e["puesto"])

	if it == null:
		_title("Ranura libre")
		_note("Elige abajo una de las que se sabe y ponla aquí." if es_magia
			else "Elige abajo una de las que su equipo le permite.")
		return

	if es_magia:
		_ficha_hechizo(it as SpellData)
	else:
		_title(str(it.get("nombre")))
		if it.has_method("es_area"):
			_row("Alcance", "Área" if it.es_area() else "Individual")
		var l := Label.new()
		l.text = it.resumen(Game.manos_de(it, pj)) if it.has_method("resumen") \
			else str(it.get("descripcion"))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(l)

	# EL BOTON. Solo en el pueblo, como el resto del equipo.
	var pueblo: bool = Game.en_pueblo()
	var lleno: bool = (pj.equipped_spells.size() >= Game.MAX_HECHIZOS) if es_magia \
		else Game.habilidades_llenas(pj)
	_content.add_child(HSeparator.new())
	if not pueblo:
		_note("Solo se cambia en el pueblo. Aquí es solo consulta.")
	elif not puesto and lleno:
		# El motivo, no un boton apagado a secas: con las ranuras llenas hay que decir QUE hacer.
		_note("No le quedan ranuras libres: quítale una de arriba para poder poner ésta.")
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(fila)
	var puede: bool = pueblo and (puesto or not lleno)
	var b: Button = MenuScaffold.pastilla(fila, "Quitar" if puesto else "Poner",
		_alternar_kit.bind(it, puesto, es_magia), true, puede)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL


# Mete o saca lo elegido. Al hacerlo la lista cambia de tamaño, asi que la seleccion se lleva a la
# ranura donde ha acabado (o a la primera): dejarla en el indice viejo apuntaba a otra cosa.
func _alternar_kit(it: Resource, puesto: bool, es_magia: bool) -> void:
	if it == null or not Game.en_pueblo():
		return
	var pj: PersonajeData = _pj()
	if es_magia:
		if puesto:
			Game.quitar_hechizo(it as SpellData, pj)
		else:
			Game.equipar_hechizo(it as SpellData, pj)
	else:
		if puesto:
			Game.desequipar_habilidad(it as AbilityData, pj)
		else:
			Game.equipar_habilidad(it as AbilityData, pj)
	_sel = 0
	_rebuild()


# Ficha de un hechizo. TODO sale de sus campos: si tocas un numero en el .tres, esto se actualiza
# solo (la 'descripcion' es solo SABOR y no repite ninguna cifra).
func _ficha_hechizo(s: SpellData) -> void:
	_title(str(s.nombre))
	_row("Encantamiento", "%s (%d frase%s)" % [
		s.longitud_texto(), s.longitud(), "" if s.longitud() == 1 else "s"])
	_row("Coste", "%d de maná" % s.coste_mana)
	if s.elemento != Elementos.Elemento.NINGUNO:
		_row("Elemento", Elementos.nombre(s.elemento))

	# DAÑO: el de ESTE personaje, ya multiplicado por su poder magico. Es el numero que va a salir en
	# el combate, no una cifra de catalogo. La etiqueta lleva el "(100%)" porque este numero es la
	# REFERENCIA de la que salen todos los porcentajes de la frase de abajo, y NO el daño total que
	# reparte el hechizo (la Andanada pone 43 y luego dice 150% + 75%, que suman bastante mas).
	var ref: float = s.dano_mostrado() * Game.poder_magico(_pj())
	if s.tipo == SpellData.TipoEfecto.ATAQUE and s.dano_base > 0.0:
		_row("Daño (100%)", "%.0f" % ref)

	var mecanica: String = s.descripcion_mecanica(ref)
	if mecanica != "":
		_content.add_child(HSeparator.new())
		var l := Label.new()
		l.text = mecanica
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(l)
	# (Sin coletilla de "el daño es el tuyo, con tu Magia y el arma": el numero de arriba YA es el
	# suyo, y explicar de donde sale es lo que sobra.)
	# La AFINIDAD de un imbue de cuerpo sigue en tabla: son varios elementos con su multiplicador
	# cada uno, y eso es una lista de verdad, no una frase.
	if s.es_imbuicion() and s.imbue_tipo == 2:
		_afinidad_hechizo(s)

	_content.add_child(HSeparator.new())
	_title("Encantamiento")
	for i in s.frases.size():
		var f := Label.new()
		f.text = "  %d. «%s»" % [i + 1, s.frases[i]]
		f.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95))
		f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(f)

	if s.descripcion != "":
		_content.add_child(HSeparator.new())
		_note(s.descripcion)


# Lo que te da y lo que te cuesta la afinidad de un imbue de CUERPO. Los % se DERIVAN de la tabla y
# de la franja de intensidad del hechizo, asi que nunca mienten.
func _afinidad_hechizo(s: SpellData) -> void:
	var resiste: Array = []
	var debil: Array = []
	for e in Elementos.PERFIL_DEFECTO.get(s.elemento, {}):
		var puro: float = float(Elementos.PERFIL_DEFECTO[s.elemento][e])
		var m: float = Elementos.escalar_intensidad(puro, s.imbue_intensidad)
		# En positivo y sin restas mentales: "20% de resistencia" / "+20% de daño".
		if m < 0.99:
			resiste.append("%s (%d%% de resistencia)" % [Elementos.nombre(e), roundi((1.0 - m) * 100.0)])
		elif m > 1.01:
			debil.append("%s (+%d%% de daño)" % [Elementos.nombre(e), roundi((m - 1.0) * 100.0)])
	if not resiste.is_empty():
		_row("🛡 Resistes", ", ".join(resiste))
	var inm: Array = []
	for id in Elementos.inmunidades_de(s.elemento):
		inm.append(String(StatusEffects.def(id).get("nombre", "?")))
	if not inm.is_empty():
		_row("Inmune a", ", ".join(inm))
	var st: float = Elementos.stun_taken_por_afinidad(s.elemento)
	if st < 0.99:
		_row("Aturdimiento", "te aturden un %d%% menos" % roundi((1.0 - st) * 100.0))
	if not debil.is_empty():
		_row("⚠ Débil a", ", ".join(debil))


# ============================================================
#  4 · ARMADURA   (las cinco piezas)
# ============================================================

func _sec_armadura() -> void:
	if _cambiando:
		_cambiar_arma()   # la misma pantalla de cambiar que las armas
		return
	var pj: PersonajeData = _pj()
	_sel = clampi(_sel, 0, ARMOR_SLOTS.size() - 1)

	# CENTRO: una celda por slot. El baul es COMUN a todo el grupo, asi que la misma pieza aparece en
	# el catalogo de los tres: por eso las celdas del cambio llevan el nombre de quien la lleva.
	var piezas: Array = []
	for slot in ARMOR_SLOTS:
		var pieza: Resource = pj.get("equipped_" + slot) as Resource
		piezas.append(_celda_equipo(pieza, ARMOR_SLOT_LABELS[slot],
			Game.item_display_name(pieza) if pieza != null else "(sin pieza)"))
	MenuScaffold.rejilla_objetos(_lista, piezas, _sel, _pick, _columnas(), LADO_CELDA)

	# DERECHA: la pieza elegida.
	var slot_sel: String = ARMOR_SLOTS[_sel]
	var actual: Resource = pj.get("equipped_" + slot_sel) as Resource
	if actual == null:
		_title(ARMOR_SLOT_LABELS[slot_sel])
		_note("Sin pieza. Vas ligero: más velocidad y ninguna defensa en esta ranura.")
	else:
		MenuScaffold.titulo_item(_content, Game.item_display_name(actual),
			Game.color_rareza_de(actual), Game.intensidad_rareza_de(actual), 17)
		MenuScaffold.banner_item(_content, actual, Game.item_plus(actual),
			ARMOR_SLOT_LABELS[slot_sel])
		_armor_stats(_content, actual as ArmorData)

	var pueblo: bool = Game.en_pueblo()
	_content.add_child(HSeparator.new())
	if not pueblo:
		_note("Cambios de equipo solo en el pueblo. Aquí es solo consulta.")
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(fila)
	var b: Button = MenuScaffold.pastilla(fila, "Cambiar", _abrir_cambio, true, pueblo)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL


# ============================================================
#  5 · EIDOLON   (desarrollos y pasivas)
#
#  Las dos capas de perks de este personaje, cada una con su regla:
#    - DESARROLLO: lo eliges tu al subir de nivel, y sube de rango (I..S) solo, con su contador
#      OCULTO. Lo que NO se enseña nunca es cuanto te falta para desbloquear uno (ver el comentario
#      de Game.DESARROLLOS): el contador es secreto a proposito.
#    - PASIVAS: no se eligen. Caen solas, rarisimo, y solo aparecen al actualizar el estado en el
#      altar. Aqui se ven las que YA tienes; las pendientes no salen, que para eso son pendientes.
# ============================================================

func _sec_eidolon() -> void:
	var pj: PersonajeData = _pj()
	var desarrollos: Array = _mis_desarrollos(pj)
	var pasivas: Array = _mis_pasivas(pj)

	# Las subpestañas SOLO si tienes de las dos clases. Con una sola, se ve esa; SIN NINGUNA sale
	# Desarrollo vacio con su explicacion, que es lo que se pidio: el hueco tiene que decir que ahi
	# va a haber algo algun dia.
	var las_dos: bool = not desarrollos.is_empty() and not pasivas.is_empty()
	if las_dos:
		MenuScaffold.subpestanas(_barra_sub, ["Desarrollo", "Pasivas"], ["engranaje", "eidolon"],
			_sub, _on_sub)
	elif pasivas.is_empty():
		_sub = 0
	else:
		_sub = 1   # solo pasivas: se enseñan sin preguntar

	if _sub == 1:
		_eidolon_lista(pasivas, "HABILIDADES PASIVAS",
			"No se eligen: aparecen solas al actualizar tu estado en el altar.",
			"Ninguna. Caen por sí solas, muy de vez en cuando, haciendo lo que sea que las despierta.")
		return
	_eidolon_lista(desarrollos, "HABILIDADES DE DESARROLLO",
		"Eliges una al subir de nivel. Suben de rango (I → S) haciendo lo suyo.",
		"Ninguna todavía. Se elige una al subir de nivel, en el altar.",
		"Sin nada elegido")


# Los desarrollos que este personaje TIENE (rango > 0), cada uno ya con su rango leido.
func _mis_desarrollos(pj: PersonajeData) -> Array:
	var out: Array = []
	for d in Game.DESARROLLOS:
		var rango: int = Game.desarrollo_rango(str(d["id"]), pj)
		if rango <= 0:
			continue
		out.append({"nombre": str(d["nombre"]), "desc": str(d["desc"]),
			"pie": "rango %s" % Game.letra_rango(rango), "color": AMBAR, "brillo": 0.0})
	return out


func _mis_pasivas(pj: PersonajeData) -> Array:
	var out: Array = []
	for p in Game.PASIVAS_RNG:
		if not Game.tiene_pasiva(str(p["id"]), pj):
			continue
		# Amarillo legendario y centelleando, igual que cuando aparecio en el altar: es lo mas raro
		# que hay en el juego y tiene que seguir cantando cada vez que abres la ficha.
		out.append({"nombre": str(p["nombre"]), "desc": Game.pasiva_desc(p),
			"pie": "pasiva", "color": Upgrades.rareza_color(4), "brillo": 1.0})
	return out


# 'vacio' es la explicacion de por que no hay nada, y va SOLO en la columna del centro: repetirla en
# la ficha de la derecha era decir dos veces la misma frase en la misma pantalla. La derecha se queda
# con 'titulo_vacio', que dice OTRA cosa (que no hay nada elegido, no por que).
func _eidolon_lista(nodos: Array, titulo: String, nota: String, vacio: String,
		titulo_vacio: String = "Nada todavía") -> void:
	MenuScaffold.titulo(_lista, titulo, 15)
	MenuScaffold.nota(_lista, nota)
	if nodos.is_empty():
		MenuScaffold.nota(_lista, vacio)
		_title(titulo_vacio)
		return
	_sel = clampi(_sel, 0, nodos.size() - 1)
	var labels: Array = []
	var colores: Array = []
	var intens: Array = []
	for n in nodos:
		labels.append("%s\n%s" % [n["nombre"], n["pie"]])
		colores.append(n["color"])
		intens.append(float(n["brillo"]))
	var grid := VBoxContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_child(grid)
	# Con celda_item y no con cuadricula: estas llevan COLOR y BRILLO (una pasiva legendaria tiene
	# que cantar), y eso es justo lo que celda_item añade encima de un boton normal.
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(g)
	for i in labels.size():
		MenuScaffold.celda_item(g, String(labels[i]), Vector2(0, 66), i == _sel, _pick.bind(i),
			colores[i], float(intens[i]))

	var nodo: Dictionary = nodos[_sel]
	MenuScaffold.titulo_item(_content, String(nodo["nombre"]), nodo["color"],
		float(nodo["brillo"]), 17)
	# El rango NO se repite aqui: ya lo pone la celda que acabas de pulsar, y una fila "Estado: rango
	# I" al lado de un boton que dice "rango I" es decir dos veces lo mismo en dos palmos.
	_content.add_child(HSeparator.new())
	var l := Label.new()
	l.text = String(nodo["desc"])
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(l)


# ============================================================
#  ¿QUIEN LLEVA ESTO?
#  El baul es COMUN a todo el grupo, asi que la misma espada aparece en el catalogo de los tres.
#  Equiparsela a uno se la quita al otro (Game._quitar_a_los_demas): es lo que se quiere, pero tiene
#  que VERSE antes de pulsar, o le dejas a alguien en pelotas sin enterarte.
# ============================================================

# El companero que lleva PUESTO este objeto, o null si no lo lleva nadie mas. Nunca devuelve al
# personaje que estas mirando: que lo lleve el no es un conflicto, es el estado normal.
func _quien_lleva(item: Resource) -> PersonajeData:
	var otro: PersonajeData = Game.quien_lleva(item)
	return null if otro == _pj() else otro


func _etiqueta_con_dueno(item: Resource, base: String) -> String:
	var otro: PersonajeData = _quien_lleva(item)
	return base if otro == null else "%s\n🔒 %s" % [base, otro.nombre]


# Linea de aviso en la FICHA (en rojo): quien lo lleva puesto. Va en la ficha ademas de en la celda
# porque la celda solo tiene sitio para el nombre, y aqui es donde el jugador se para a mirar antes
# de pulsar Equipar.
func _aviso_dueno(item: Resource) -> void:
	var otro: PersonajeData = _quien_lleva(item)
	if otro == null:
		return
	var l := Label.new()
	l.text = "🔒 Lo lleva puesto %s. Si lo equipas, se lo quitas." % otro.nombre
	l.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))
	l.add_theme_font_size_override("font_size", 12)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(l)


# Modal de "esto lo lleva puesto Fulano, ¿se lo quito?". Es un si/no y no un aviso pasivo a
# proposito: desnudar a un companero por un clic de mas es justo el error que hay que evitar, y al
# volver a la mazmorra ya no hay forma de deshacerlo.
func _confirmar_robo(item: Resource, al_aceptar: Callable) -> void:
	var otro: PersonajeData = _quien_lleva(item)
	if otro == null:
		al_aceptar.call()   # no lo lleva nadie: no hay nada que preguntar
		return
	_cerrar_modal()
	var m: Dictionary = MenuScaffold.modal(_root, "Lo lleva puesto %s" % otro.nombre)
	_modal = m["capa"]
	_ver_muneco(false)
	var cuerpo: VBoxContainer = m["cuerpo"]
	var d := Label.new()
	d.text = "%s se lo quitará a %s, que se quedará con ese hueco vacío." % [_pj().nombre, otro.nombre]
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.add_theme_color_override("font_color", GRIS)
	cuerpo.add_child(d)
	MenuScaffold.titulo_item(cuerpo, Game.item_display_name(item), Game.color_rareza_de(item),
		Game.intensidad_rareza_de(item), 16)
	MenuScaffold.pastilla(m["acciones"], "Cancelar", _cerrar_modal, false)
	MenuScaffold.pastilla(m["acciones"], "Sí, quitárselo", func():
		_cerrar_modal()
		al_aceptar.call())


# ============================================================
#  FICHAS DE EQUIPO
#  Los numeros REALES (los mismos que usa el combate: Upgrades.*_mods con el tier/rareza/mejoras del
#  objeto), no los del .tres. Una daga T3 +3 NO pega lo que dice su plantilla; entre parentesis va lo
#  que ponen las mejoras, para ver cuanto ha subido.
# ============================================================

func _weapon_stats(vb: VBoxContainer, w: WeaponData) -> void:
	if w == null:
		return
	var m: Dictionary = Game.meta_de(w)
	var tier: int = int(m["tier"])
	var rareza: int = int(m["rareza"])
	var mejoras: Dictionary = m["mejoras"]
	var tmult: float = Game.tier_mult(tier)
	var mods: Dictionary = Upgrades.weapon_mods(w, tmult, rareza, mejoras)
	# El BASE de ESTA arma no es el del .tres: es el suyo con su tier y su rareza, sin las mejoras.
	var base: Dictionary = Upgrades.weapon_mods(w, tmult, rareza, {})

	var tipo: String = WEAPON_TIPO_LABELS[clampi(int(w.tipo), 0, WEAPON_TIPO_LABELS.size() - 1)]
	_row_en(vb, "Tipo", tipo + ("  ·  magia" if w.es_magica else ""))
	_row_en(vb, "Manejo", "Dos manos" if w.dos_manos else "Una mano")
	# EL DAÑO APLICADO POR GOLPE, no el raw: el raw ya lo multiplican tu Fuerza y el motion value
	# antes de llegar al enemigo. El motion value no tiene fila propia porque va dentro de este
	# numero. El DESGASTE de ESTA pieza entra en la cuenta: decir "20 de ataque" con la fila de abajo
	# marcando un 60% es contar dos cosas que no casan (el combate ya le aplica el ×0.90).
	var dur: float = Game.durabilidad_item(w)
	_row_en(vb, "Ataque", _con_mejoras("%.1f",
		MenuScaffold.dano_arma(w, float(base["raw"]), _pj(), dur),
		MenuScaffold.dano_arma(w, float(mods["raw"]), _pj(), dur)))
	_row_en(vb, "Velocidad", _con_mejoras("×%.2f",
		w.velocidad_mult * float(base["vel_mult"]), w.velocidad_mult * float(mods["vel_mult"])))
	var crit: float = float(mods["crit"])
	if crit != 0.0:
		_row_en(vb, "Crítico", _con_mejoras_pct(float(base["crit"]), crit))
	_row_en(vb, "Daño crítico", _con_mejoras("×%.2f",
		StatsMath.CRIT_MULT + float(base["crit_dmg"]), StatsMath.CRIT_MULT + float(mods["crit_dmg"])))
	if float(mods["precision"]) > 0.0:
		_row_en(vb, "Precisión", "+%s" % _fmt_pct(float(mods["precision"])))
	if float(mods["evasion"]) > 0.0:
		_row_en(vb, "Evasión", "+%s" % _fmt_pct(float(mods["evasion"])))
	if float(mods["aturdir"]) > 0.0:
		_row_en(vb, "Aturdir", _con_mejoras_pct(float(base["aturdir"]), float(mods["aturdir"])))
	if w.es_magica:
		var mg: Dictionary = Upgrades.magic_mods(w.magic_amp, tmult, rareza, mejoras)
		var mgb: Dictionary = Upgrades.magic_mods(w.magic_amp, tmult, rareza, {})
		_magic_stats(vb, mg, mgb, w.mp_regen_turno, w.cast_vel_mult)
	_pie_pieza(vb, w, mejoras, rareza)


# La ficha del ESCUDO, hermana de _weapon_stats: mismos numeros REALES (Upgrades.shield_mods) y el
# mismo desglose "base + (lo que ponen las mejoras) = total". Con el numero pelado veias "Bloqueo
# 15%" y no habia forma de saber que 5 de esos puntos los ponia el Refuerzo que acababas de forjar.
func _shield_stats(vb: VBoxContainer, sh: ShieldData, tier: int, rareza: int,
		mejoras: Dictionary) -> void:
	var tmult: float = Game.tier_mult(tier)
	var mods: Dictionary = Upgrades.shield_mods(sh, tmult, rareza, mejoras)
	var base: Dictionary = Upgrades.shield_mods(sh, tmult, rareza, {})
	var tamanos: Array = MenuScaffold.SHIELD_TAMANO_LABELS
	_row_en(vb, "Tipo", "Escudo %s  ·  mano secundaria"
		% String(tamanos[clampi(int(sh.tamano), 0, tamanos.size() - 1)]).to_lower())
	# Lo primero, la DEFENSA: es lo que crece con tier, rareza y mejoras. Y solo cuenta al Defender.
	# Es PLANA (se suma DESPUES del multiplicador de Resistencia, al reves que la armadura), asi que
	# el numero YA es lo que te da: no hace falta una fila "para ti".
	_row_en(vb, "Defensa al bloquear", _con_mejoras("%.1f", float(base["def"]), float(mods["def"])))
	# El bloqueo NO lleva tier ni rareza (es del tamaño): lo unico que lo sube es el Refuerzo, y eso
	# es justo lo que enseña el parentesis.
	_row_en(vb, "Bloqueo", _con_mejoras_pct(float(base["bloqueo"]), float(mods["bloqueo"])))
	if float(mods["resist_estados"]) > 0.0:
		_row_en(vb, "Resist. estados",
			_con_mejoras_pct(float(base["resist_estados"]), float(mods["resist_estados"])))
	_row_en(vb, "Velocidad", "×%.2f" % float(mods["vel_mult"]))
	_row_en(vb, "Penal. esquiva", "-%s" % _fmt_pct(float(mods["evasion_penal"])))


# Las lineas magicas (baston y varita comparten math: Upgrades.magic_mods). 'mg' = con mejoras,
# 'mgb' = el mismo item SIN ellas (su base con tier y rareza).
func _magic_stats(vb: VBoxContainer, mg: Dictionary, mgb: Dictionary, regen_base: float,
		cast_base: float) -> void:
	# EL ATAQUE MAGICO, no la amplificacion. "×11.82" no se puede comparar con un ataque y ademas
	# rinde una cosa en un mago y otra en un guerrero (multiplica TU Magia): se convierte a daño con
	# el hechizo de referencia, que es la misma moneda que el ataque fisico de arriba.
	_row_en(vb, "Ataque mágico", _con_mejoras("%.1f",
		MenuScaffold.dano_magico(_pj(), float(mgb["magic_amp"])),
		MenuScaffold.dano_magico(_pj(), float(mg["magic_amp"]))))
	var regen_b: float = regen_base * float(mgb["regen_mult"])
	var regen_t: float = regen_base * float(mg["regen_mult"])
	_row_en(vb, "Regen maná", _con_mejoras("%.2f", regen_b, regen_t) + " /turno")
	MenuScaffold.nota(vb, "Gotea también mientras recitas: un conjuro corto tarda 2 turnos, así que "
		+ "se paga %.2f de su maná él solo." % (regen_t * 2.0))
	_row_en(vb, "Vel. casteo", _con_mejoras("×%.2f",
		cast_base + float(mgb["cast_vel_add"]), cast_base + float(mg["cast_vel_add"])))
	if float(mg["mana_reduccion"]) > 0.0:
		_row_en(vb, "Coste de maná", "-%s" % _fmt_pct(float(mg["mana_reduccion"])))
	# CRITICO MAGICO del arma (lo que aporta ELLA; la parte que pone tu Destreza va en la lupa). Es
	# lo que sube la mejora de Precision en un baston o una varita.
	if float(mg["crit_magico"]) != 0.0:
		_row_en(vb, "Crítico mágico",
			_con_mejoras_pct(float(mgb["crit_magico"]), float(mg["crit_magico"])))
	_row_en(vb, "Daño crít. mágico", _con_mejoras("×%.2f",
		StatsMath.CRIT_MULT + float(mgb["crit_dmg_magico"]),
		StatsMath.CRIT_MULT + float(mg["crit_dmg_magico"])))


func _off_stats(vb: VBoxContainer, item: Resource) -> void:
	if item == null:
		MenuScaffold.nota(vb, "(sin mano secundaria)")
		return
	if item is WeaponData:
		_weapon_stats(vb, item as WeaponData)
		return
	# Escudo y varita tambien tienen su tier/rareza/mejoras.
	var m: Dictionary = Game.meta_de(item)
	var tier: int = int(m["tier"])
	var rareza: int = int(m["rareza"])
	var mejoras: Dictionary = m["mejoras"]
	if item is ShieldData:
		_shield_stats(vb, item as ShieldData, tier, rareza, mejoras)
	elif item is WandData:
		var wd := item as WandData
		var tm: float = Game.tier_mult(tier)
		_magic_stats(vb, Upgrades.magic_mods(wd.magic_amp, tm, rareza, mejoras),
			Upgrades.magic_mods(wd.magic_amp, tm, rareza, {}), wd.mp_regen_turno, wd.cast_vel_mult)
	_pie_pieza(vb, item, mejoras, rareza)


# Ficha de una pieza de armadura. Las filas salen de MenuScaffold.filas_armadura, que es la MISMA
# fuente que usa la ficha de detalle del combate. Se le pasan la DURABILIDAD y el factor de
# Resistencia de quien la esta mirando, que es lo que convierte la defensa de la pieza en la defensa
# que de verdad te da a ti.
func _armor_stats(vb: VBoxContainer, a: ArmorData) -> void:
	if a == null:
		return
	var am: Dictionary = Game.meta_de(a)
	var mejoras: Dictionary = am["mejoras"]
	for f in MenuScaffold.filas_armadura(a, int(am["tier"]), int(am["rareza"]), mejoras,
			Game.durabilidad_item(a), MenuScaffold.factor_resistencia(_pj())):
		_row_en(vb, str(f[0]), str(f[1]))
	_row_en(vb, "Durabilidad", Game.durabilidad_txt_item(a), Game.durabilidad_color(a))
	if not mejoras.is_empty():
		MenuScaffold.nota(vb, _lista_mejoras(mejoras))


# El pie comun de toda pieza: en cuantos huecos de mejora va, cuanto le queda de vida y EN QUE se
# gastaron. La lista de mejoras va en su propia linea porque con 12 huecos (obra maestra) no cabe
# nunca al lado del contador.
func _pie_pieza(vb: VBoxContainer, item: Resource, mejoras: Dictionary, rareza: int) -> void:
	_row_en(vb, "Mejoras", "%d / %d" % [
		Upgrades.total_mejoras(mejoras), Upgrades.rareza_slots(rareza)])
	# DESGASTE: gastada pega menos y ROTA se va a los suelos. Se repara en el herrero.
	_row_en(vb, "Durabilidad", Game.durabilidad_txt_item(item), Game.durabilidad_color(item))
	if not mejoras.is_empty():
		MenuScaffold.nota(vb, _lista_mejoras(mejoras))


# "Agudeza 2, Precision 1": en QUE se gastaron las mejoras (dos armas con el mismo +N pueden ser
# cosas muy distintas).
func _lista_mejoras(mejoras: Dictionary) -> String:
	var partes: PackedStringArray = []
	for cat in mejoras:
		partes.append("%s %d" % [Upgrades.cat_nombre(str(cat)), int(mejoras[cat])])
	return ", ".join(partes)


# "14.5 + (6.1) = 20.6". El BASE ya lleva dentro el tier y la rareza de ESTE objeto (no es el numero
# del .tres); lo que va ENTRE PARENTESIS es lo que ponen las mejoras. Sin mejoras, el numero a secas.
#
# DELEGA en MenuScaffold: la ficha de armadura de alli usa la misma cuenta, y dos copias del mismo
# formato acaban discrepando en el umbral (¿0.005 o 0.05?) el dia que alguien afine una sola.
func _con_mejoras(fmt: String, base: float, total: float) -> String:
	return MenuScaffold._con_mejoras(fmt, base, total)


func _con_mejoras_pct(base: float, total: float) -> String:
	if absf(total - base) < 0.0005:
		return "+%s" % _fmt_pct(total)
	return "%s + (%s) = %s" % [_fmt_pct(base), _fmt_pct(total - base), _fmt_pct(total)]


func _main_nombre(item: Resource) -> String:
	return "— (sin arma)" if item == null else Game.item_display_name(item)


func _off_nombre(item: Resource) -> String:
	return "— (sin secundaria)" if item == null else Game.item_display_name(item)


# UNA CELDA de la rejilla de equipo: el objeto puesto en esa ranura, o la ranura vacia. El rotulo del
# pie es el de la RANURA y no el del objeto, para que la rejilla se lea igual con o sin pieza.
func _celda_equipo(item: Resource, ranura: String, nombre: String) -> Dictionary:
	return {"item": item, "pie": ranura, "tooltip": "%s: %s" % [ranura, nombre], "marca": ""}


# ============================================================
#  Cuentas y helpers
# ============================================================

# El Combatant de quien estas mirando, que es de donde salen TODAS las stats de esta pantalla.
#
# crear_player_combatant() concreta el −1 (= "lleno") de vida/maná, asi que se guardan y se
# restauran los sentinels: aqui solo se LEE, y mutar el estado persistente por abrir una ficha
# curaria al personaje sin que nadie lo pidiera.
func _combatiente() -> Combatant:
	var pj: PersonajeData = _pj()
	var hp_was: float = pj.current_hp
	var mp_was: float = pj.current_mp
	var c: Combatant = Game.crear_player_combatant(pj)
	pj.current_hp = hp_was
	pj.current_mp = mp_was
	return c


# Ataque TOTAL (raw): (base + arma) × factor_fuerza × estados, SIN el motion value (ese se aplica por
# golpe). Es la misma cuenta que combate_detalle._atk_total.
func _ataque_total(c: Combatant) -> float:
	return (c.base_attack + c.ataque_arma) \
		* StatsMath.fuerza_factor(float(c.abilities.fuerza)) * c.status_atk_mult()


# El critico es un CONTEST (tu Destreza contra la Agilidad de quien recibe el golpe); aqui no hay
# rival delante, asi que se mide contra un maniqui con TUS mismas stats.
func _crit_fisico(c: Combatant) -> float:
	return clampf(StatsMath.crit_chance(float(c.abilities.destreza),
		float(c.abilities.agilidad)) + c.crit_bonus_promedio() + c.crit_flat, 0.0, 1.0)


# El magico NO se promedia por manos: loadout_mods ya suma lo del baston y lo de la varita.
func _crit_magico(c: Combatant) -> float:
	return clampf(StatsMath.crit_chance(float(c.abilities.destreza),
		float(c.abilities.agilidad)) + c.crit_magico, 0.0, 1.0)


# UN SOLO formato para el daño critico en toda la pantalla, el mismo que la ficha de combate.
func _crit_dmg_txt(extra: float) -> String:
	var m: float = StatsMath.CRIT_MULT + extra
	return "×%.2f (+%d%%)" % [m, roundi((m - 1.0) * 100.0)]


# COPIA de las habilidades con UNA puesta a cero. Sirve para medir lo que aporta esa habilidad por
# DIFERENCIA: "lo que tienes" menos "lo que tendrias sin ella". Se hace asi y no reescribiendo cada
# formula porque reescribirlas es de donde venia el desfase (las aditivas de los enemigos frente a
# las multiplicativas del jugador). Por diferencia da igual cual sea la formula: sale la de verdad.
func _sin_habilidad(ab: Abilities, cual: String) -> Abilities:
	var z := Abilities.new()
	z.fuerza = ab.fuerza
	z.resistencia = ab.resistencia
	z.destreza = ab.destreza
	z.agilidad = ab.agilidad
	z.magia = ab.magia
	z.set(cual, 0)
	return z


func _fmt_pct(x: float) -> String:
	return "%.1f%%" % (x * 100.0)


# --- Piezas de la ficha de la derecha (la columna estrecha) ---
# El ancho de etiqueta es 150 y no los 170 de MenuScaffold.fila: la ficha mide ANCHO_FICHA, y con
# 170 un valor largo ("14.5 + (6.1) = 20.6") se partia en dos lineas en casi todas las filas.

func _title(txt: String) -> void:
	MenuScaffold.titulo(_content, txt, 16, AMBAR)


func _row(etiqueta: String, valor: String, color: Variant = null) -> void:
	MenuScaffold.fila(_content, etiqueta, valor, 150, color)


func _row_en(vb: VBoxContainer, etiqueta: String, valor: String, color: Variant = null) -> void:
	MenuScaffold.fila(vb, etiqueta, valor, 150, color)


func _note(txt: String) -> void:
	MenuScaffold.nota(_content, txt)


func _note_en(vb: VBoxContainer, txt: String) -> void:
	MenuScaffold.nota(vb, txt)
