# ============================================================
#  menu_scaffold.gd
#  El ESQUELETO que comparten todos los menus a pantalla completa (inventario, tienda,
#  herrero, peletero, boticaria). Antes cada uno se construia su propio armazon a mano, con
#  el mismo codigo copiado cinco veces; ahora sale de aqui.
#
#  La forma, y el porque:
#
#    +----------+--------------------------------------------------+
#    |  LATERAL |  CABECERA   (titulo, pestañas)   <- NUNCA scroll  |
#    |  (tabs,  +---------------------+----------------------------+
#    |  cerrar) |  LISTA  (scroll ↕)  |  DETALLE  (scroll ↕)       |
#    |          |  la cuadricula      |  la ficha de lo elegido    |
#    +----------+---------------------+----------------------------+
#
#  La CABECERA se queda fija: es la brujula del menu, y si se va con el scroll dejas de saber
#  donde estas. La LISTA y el DETALLE se desplazan POR SEPARADO: una ficha larga no tiene por
#  que empujar la cuadricula, ni cien objetos de un tipo tienen por que mover la ficha.
#
#  Es estatico (como StatsMath / Upgrades): solo construye nodos y te devuelve las referencias.
# ============================================================

extends RefCounted
class_name MenuScaffold

const AMBAR := Color(0.95, 0.72, 0.36)
const GRIS := Color(0.6, 0.63, 0.7)
const FONDO := Color(0.05, 0.06, 0.08, 1.0)

# Ancho de la columna de la lista (la cuadricula de items cabe en dos columnas de 150).
const ANCHO_LISTA := 330.0

# ALTO DE UN BOTON DE MENU. 44 es el minimo que se acierta con un pulgar, y ya era la medida de las
# pestañas y de las celdas de la cuadricula; lo que pasaba es que cada menu se inventaba la suya para
# los botones sueltos (32 en la tienda, 34 en el pescador, 36 en el crafteo) y quedaban finos justo
# donde hay que pulsar. Va tambien en escritorio: dos medidas del mismo menu no las quiere nadie.
const ALTO_BOTON := 44.0
# Lado de los botones de ICONO (la ✕ de cerrar). Mismo criterio.
const LADO_ICONO := 44.0


# ============================================================
#  EL TEMA DE LOS BOTONES
#  El tema por defecto de Godot pinta el boton como un gris plano SIN BORDE, y sobre el fondo casi
#  negro de los menus (FONDO, ahi arriba) no se distinguia del hueco: habia que adivinar donde se
#  podia pulsar. Con un borde, cada boton se ve como lo que es.
#
#  Se construye UNA vez (esta cacheado) y se cuelga de la RAIZ del arbol, no de cada menu: ver
#  Game._ready. Asi entra tambien en lo que no sale de este esqueleto -- el combate, la pausa, el HUD,
#  el menu de personaje --, que es lo que se pidio: TODOS los botones.
#
#  El lenguaje visual es el mismo que ya usaba la ✕ (ver boton_icono.gd): fondo oscuro translucido,
#  borde blanco flojo y esquinas redondeadas. Alli el radio es 12 porque es un cuadrado; aqui 6, que
#  en un boton alargado un radio grande le hace forma de pastilla.
#
#  Nada de esto pisa a quien tenga su propio estilo: un add_theme_stylebox_override (los chips de
#  estado, los mandos tactiles) manda sobre el tema. Y tintar() solo toca colores de FUENTE, asi que
#  las celdas teñidas por rareza conservan su color y ademas ganan el borde.
# ============================================================

static var _tema: Theme = null

static func tema() -> Theme:
	if _tema != null:
		return _tema
	_tema = Theme.new()
	# normal / hover / pressed / disabled / focus: los cinco estados que pinta un Button. Si falta
	# alguno, Godot lo rellena con SU gris y el boton cambia de aspecto al tocarlo.
	# El alfa del borde va ALTO (0.45 y subiendo). Con el 0.28 de la ✕ el boton se quedaba en una
	# mancha oscura: ese valor funciona en un cuadro pequeño y aislado, no en una fila de botones
	# alargados sobre el fondo del menu. Medido en captura antes de subirlo.
	_tema.set_stylebox("normal", "Button", _caja(Color(0.16, 0.17, 0.22, 0.95), 0.45))
	_tema.set_stylebox("hover", "Button", _caja(Color(0.22, 0.24, 0.30, 0.97), 0.70))
	_tema.set_stylebox("pressed", "Button", _caja(Color(0.30, 0.32, 0.40, 0.95), 0.85))
	_tema.set_stylebox("focus", "Button", _caja(Color(0.16, 0.17, 0.22, 0.95), 0.65))
	# Apagado: el borde casi desaparece y el fondo se hunde en el del menu. Un boton que no se puede
	# pulsar tiene que NOTARSE que no se puede, no solo tener la letra mas gris.
	_tema.set_stylebox("disabled", "Button", _caja(Color(0.09, 0.10, 0.13, 0.75), 0.14))
	# El campo del stepper con la MISMA caja: asi el − [ n ] + se lee como un solo control y no como
	# dos botones con un hueco en medio.
	_tema.set_stylebox("normal", "LineEdit", _caja(Color(0.10, 0.11, 0.14, 0.95), 0.45))
	_tema.set_stylebox("focus", "LineEdit", _caja(Color(0.10, 0.11, 0.14, 0.95), 0.75))
	_tema.set_stylebox("read_only", "LineEdit", _caja(Color(0.09, 0.10, 0.13, 0.75), 0.14))
	return _tema


static func _caja(fondo: Color, borde_alpha: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.border_color = Color(1, 1, 1, borde_alpha)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	# Aire a los lados para que la letra no toque el borde nuevo.
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	return sb


# Construye el esqueleto dentro de `capa` (un CanvasLayer) y devuelve sus piezas:
#   {root, side, header, lista, content, dinero}
#  - root: el Control full-rect (empieza invisible; el menu lo enseña en abrir()).
#  - side: la columna izquierda (mete ahi tus pestañas; el titulo ya va, y cerrar es la ✕ de arriba).
#  - header / lista / content: las tres zonas de arriba.
#  - dinero: la etiqueta de monedas arriba a la derecha (null si con_dinero = false).
#
# con_lateral = false monta el titulo y las pestañas en una BARRA DE ARRIBA y pone el ✕ en la
# esquina, sin columna izquierda. Solo lo usa el menu de mundos compartidos: alli estas eligiendo
# partida y no hojeando un catalogo, asi que la columna se quedaba vacia ocupando 230 px. Los demas
# menus no lo pasan y no cambian nada.
static func construir(capa: CanvasLayer, titulo: String, nota: String,
		al_cerrar: Callable, con_dinero: bool = false, con_lateral: bool = true) -> Dictionary:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	capa.add_child(root)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = FONDO
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bg)

	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 16
	hb.offset_top = 16
	hb.offset_right = -16
	hb.offset_bottom = -16
	hb.add_theme_constant_override("separation", 18)
	root.add_child(hb)

	# LA ✕ DE CERRAR, arriba a la derecha. Va anclada al root (no al layout) para que flote sobre
	# todo, igual que en el mapa. Antes esto era un boton de texto "✕ Cerrar (Esc)" al fondo de la
	# columna izquierda: en movil hay que cruzar la pantalla entera para cerrar, y ademas no es donde
	# se busca. Con lateral o sin el, la ✕ es la misma y esta en el mismo sitio.
	# El margen respeta Tactil.borde (la zona segura del movil: muescas y barra de gestos).
	# Tactil.borde es un Vector2: x = cuanto apartarse de los LADOS, y = de ARRIBA.
	var margen_x: float = 16.0 + Tactil.borde.x
	var margen_y: float = 16.0 + Tactil.borde.y
	if con_lateral:
		var equis: Control = BotonIcono.crear(Callable(Iconos, "equis"), al_cerrar, LADO_ICONO)
		equis.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		equis.offset_left = -(margen_x + LADO_ICONO)
		equis.offset_right = -margen_x
		equis.offset_top = margen_y
		equis.offset_bottom = margen_y + LADO_ICONO
		root.add_child(equis)

	# Monedas arriba a la derecha (donde el jugador ya las busca), DEBAJO de la ✕: comparten esquina
	# y antes se pisaban. Grandes a proposito: es el numero que se mira antes de cada compra.
	var dinero: Label = null
	if con_dinero:
		dinero = Label.new()
		dinero.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		dinero.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		dinero.offset_left = -(margen_x + 300.0)
		dinero.offset_right = -margen_x
		dinero.offset_top = margen_y + LADO_ICONO + 8.0
		dinero.add_theme_color_override("font_color", Color(0.95, 0.86, 0.5))
		dinero.add_theme_font_size_override("font_size", 22)
		root.add_child(dinero)

	# --- Lateral: titulo, nota, (las pestañas las mete el menu) y cerrar ---
	# 'tabs' es lo que se le devuelve al menu como "side": es donde mete sus pestañas. Con lateral
	# es una columna a la izquierda; sin el, una fila en la barra de arriba. El menu no se entera.
	var tabs: BoxContainer
	if con_lateral:
		var side := VBoxContainer.new()
		side.custom_minimum_size = Vector2(230, 0)
		side.add_theme_constant_override("separation", 6)
		hb.add_child(side)

		var t := Label.new()
		t.text = titulo
		t.add_theme_color_override("font_color", AMBAR)
		t.add_theme_font_size_override("font_size", 18)
		side.add_child(t)

		if nota != "":
			var n := Label.new()
			n.text = nota
			n.add_theme_color_override("font_color", GRIS)
			n.add_theme_font_size_override("font_size", 11)
			n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			side.add_child(n)
		side.add_child(HSeparator.new())

		# El menu mete aqui sus pestañas. El spacer de debajo las mantiene arriba (antes servia ademas
		# para empujar el boton de cerrar al fondo; ahora cerrar es la ✕ de la esquina).
		tabs = VBoxContainer.new()
		tabs.add_theme_constant_override("separation", 6)
		side.add_child(tabs)

		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		side.add_child(spacer)
	else:
		tabs = HBoxContainer.new()
		tabs.add_theme_constant_override("separation", 8)

	# --- Derecha: cabecera fija + lista y detalle, cada uno con su scroll ---
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 16)
	hb.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)

	# SIN LATERAL: la barra de arriba se monta aqui, que es lo primero de la columna derecha —
	# titulo, las pestañas en fila, y la ✕ empujada al otro extremo.
	if not con_lateral:
		var barra := HBoxContainer.new()
		barra.add_theme_constant_override("separation", 14)
		barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(barra)

		var t2 := Label.new()
		t2.text = titulo
		t2.add_theme_color_override("font_color", AMBAR)
		t2.add_theme_font_size_override("font_size", 20)
		barra.add_child(t2)
		barra.add_child(tabs)

		var hueco := Control.new()
		hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		barra.add_child(hueco)

		barra.add_child(BotonIcono.crear(Callable(Iconos, "equis"), al_cerrar, LADO_ICONO))
		col.add_child(HSeparator.new())

	# Linea de AVISO ("Sacas 3 lingotes...", "No te llega"). Vive FUERA del header y con una
	# altura FIJA aunque este vacia: si apareciera y desapareciera con el mensaje, empujaria el
	# titulo y todo el menu bailaria cada vez que haces algo.
	var aviso := Label.new()
	aviso.custom_minimum_size = Vector2(0, 22)
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(aviso)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(header)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 20)
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(split)

	var scroll_lista := ScrollContainer.new()
	scroll_lista.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_lista.custom_minimum_size = Vector2(ANCHO_LISTA, 0)
	scroll_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(scroll_lista)
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 4)
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_lista.add_child(lista)

	var scroll_det := ScrollContainer.new()
	scroll_det.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_det.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(scroll_det)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_det.add_child(content)

	# DESLIZAR CON EL DEDO. Va aqui y no en cada menu porque este es el sitio por el que pasan los
	# veinte: la lista y el detalle de todos salen de estas dos lineas. Solo con los dedos, para no
	# cambiarle el raton a nadie en escritorio (ahi ya esta la rueda). Ver arrastre_scroll.gd para
	# por que no basta con el arrastre que trae Godot.
	if Tactil.activo:
		ArrastreScroll.enganchar(scroll_lista)
		ArrastreScroll.enganchar(scroll_det)

	return {
		"root": root, "side": tabs, "header": header, "aviso": aviso,
		"lista": lista, "lista_scroll": scroll_lista, "content": content, "dinero": dinero,
	}


# Un boton ⓘ al lado de 'dueño' que enseña SU ficha (su tooltip_text) en un panel.
#
# Solo sale con los dedos: en escritorio ya la enseña el tooltip de siempre al pasar el raton. Y en
# el movil el mantener pulsado tambien funciona en todas partes (ver ficha_tactil.gd), pero en las
# pantallas donde la ficha es imprescindible —el maestro, la tienda, la forja— no se puede depender
# de que el jugador descubra un gesto que nadie le ha contado.
#
# El texto se lee AL PULSAR y no al crear el boton a proposito: quien lo llama suele rematar el
# tooltip despues (los "⛔ te faltan N monedas" se anteponen mas abajo), y leyendolo aqui saldria la
# version a medio hacer.
static func info(fila: BoxContainer, dueno: Control, titulo: String = "") -> void:
	if not Tactil.activo or dueno == null:
		return
	var b: Control = BotonIcono.crear(Callable(Iconos, "info"), func() -> void:
		var f: Node = fila.get_tree().get_first_node_in_group("ficha_tactil")
		if f != null and f.has_method("abrir"):
			f.abrir(dueno.tooltip_text, titulo)
	, 38.0)
	fila.add_child(b)


# Pinta (o borra) el mensaje de la linea de aviso. Verde = salio bien, rojo = no.
static func decir(aviso: Label, txt: String, ok: bool = true) -> void:
	if aviso == null:
		return
	aviso.text = txt
	aviso.add_theme_color_override("font_color",
		Color(0.55, 0.85, 0.55) if ok else Color(0.9, 0.5, 0.5))


# VACIA un contenedor de la UI. Parece un detalle y es EL bug de "el menu sale duplicado": todos los
# _rebuild hacian `for c in zona.get_children(): c.queue_free()`, y queue_free NO saca el nodo del
# arbol — lo marca y el SceneTree lo borra al final del frame. Hasta entonces el VBox sigue teniendo
# a los viejos por hijos, asi que lo que se pinta a continuacion se apila DEBAJO: por eso aparecian
# dos veces el selector de materiales y el boton de Crear.
#
# Y hay tres caminos que repintan antes de ese flush, los tres en la forja:
#   - los _on_* son corrutinas: `await Net.abrir_taller()` espera frames enteros en el cliente.
#   - Net.hogar_cambiado / reservas_cambiadas estan conectadas a _rebuild y llegan por red.
#   - el focus_exited del stepper salta al liberar el LineEdit que tenia el foco -> _rebuild reentrante.
#
# remove_child() SI es inmediato, asi que quitandolo antes el orden deja de depender del frame.
# Se sigue liberando con queue_free y no con free porque el nodo puede estar en mitad de una señal
# suya (justo el caso del focus_exited) y free() ahi revienta.
#
# Y ANTES de quitar nada se marca el subarbol como MURIENDO. Es por el focus_exited del stepper: al
# sacar el LineEdit que tenia el foco, su callback salta EN MITAD de este bucle y llama al on_set del
# menu -> _rebuild reentrante -> Godot corta el vaciado de dentro ("Parent node is busy
# adding/removing children") y el panel acaba pintado DOS VECES. En ese instante el nodo aun se
# declara dentro del arbol y sin encolar (medido), asi que no hay forma de notarlo desde el propio
# nodo: hay que marcarlo aqui. Un campo que se esta destruyendo no tiene por que opinar sobre su
# valor -- ver stepper().
const META_MURIENDO := "_muriendo"

# Para los menus que NO usan la columna de la lista (el peletero, el altar, el selector de desarrollo
# y el de elegir piso): esconde la lista Y le pone al detalle un ancho de LECTURA, centrado.
#
# Sin lo segundo el detalle se quedaba solo y se desparramaba a lo ancho de la pantalla: una columna
# de filas cortas con media pantalla de nada a la derecha. Y en el movil, encima, obligaba a barrer
# la vista de un extremo al otro para leer una fila.
static func solo_detalle(piezas: Dictionary, ancho: float = 900.0) -> void:
	var lista: ScrollContainer = piezas.get("lista_scroll") as ScrollContainer
	if lista != null:
		lista.visible = false
	var content: VBoxContainer = piezas.get("content") as VBoxContainer
	if content != null:
		content.custom_minimum_size = Vector2(0, 0)
		content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.custom_minimum_size = Vector2(ancho, 0)


static func vaciar(zona: Node) -> void:
	if zona == null:
		return
	for c in zona.get_children():
		_marcar_muriendo(c)
		zona.remove_child(c)
		c.queue_free()


static func _marcar_muriendo(n: Node) -> void:
	n.set_meta(META_MURIENDO, true)
	for h in n.get_children():
		_marcar_muriendo(h)


# ¿Este nodo (o alguno de sus padres) esta siendo destruido por vaciar()?
static func muriendo(n: Node) -> bool:
	return n == null or not is_instance_valid(n) or n.get_meta(META_MURIENDO, false)


# --- Piezas sueltas que repiten los cinco menus ---

# EL titulo de todos los menus. Devuelve el Label para poder colgarle cosas encima (ver titulo_item):
# sin el retorno no habia forma de ponerle particulas desde fuera.
#
# OJO: esta es la UNICA implementacion. Habia CUATRO copias de esto (una por menu) y solo dos
# aceptaban color, asi que el color de rareza se podia arreglar en un menu y seguir roto en los otros
# tres -- que es exactamente lo que paso. Los _title locales delegan aqui; no volver a copiarlo.
static func titulo(vb: VBoxContainer, txt: String, tam: int = 16, color: Color = AMBAR) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", tam)
	vb.add_child(l)
	return l


# Titulo de UN OBJETO: su nombre con el color de su escalon (rareza del equipo o rango del material)
# y los destellos centelleando SOBRE el propio nombre. Es lo mismo dicho de tres maneras -- el
# escalon escrito, el color y el brillo -- en el sitio donde miras primero.
#
# Los destellos son HIJOS del Label, no una banda aparte: los hijos de un CanvasItem se dibujan
# DESPUES del padre, asi que caen por encima del texto, y al ser hijos heredan su colocacion (siguen
# al nombre cuando el contenedor lo mueve).
#
# 'intensidad' (0..1) es lo alto que esta el escalon en SU escala: un comun apenas centellea y un
# pristino centellea de verdad. La dan Upgrades.rareza_intensidad y MaterialData.rango_intensidad,
# cada una normalizada con su propio tope (8 rarezas frente a 5 rangos).
#
# Va donde hay UN objeto protagonista (una ficha, la pieza que llevas puesta) y NUNCA en una rejilla:
# alli hay 20-40 botones a la vez. Las rejillas llevan color, pero no particulas (ver cuadricula).
static func titulo_item(vb: VBoxContainer, txt: String, color: Color, intensidad: float = 1.0,
		tam: int = 16) -> void:
	brillo_en(titulo(vb, txt, tam, color), color, intensidad)


# Cuelga los destellos de UN LABEL cualquiera, ya creado. Separado de titulo_item porque el nombre de
# un objeto no siempre es un titulo: en la hoja de equipo va dentro de una fila ("Principal: Baston
# +3", "Casco: Casco de cuero") y ahi tambien tiene que brillar.
#
# El emisor es HIJO del Label a proposito: los hijos de un CanvasItem se dibujan DESPUES del padre,
# asi que caen por encima del texto, y al ser hijos heredan su colocacion (siguen al nombre cuando el
# contenedor lo mueve).
static func brillo_en(lbl: Label, color: Color, intensidad: float = 1.0) -> CPUParticles2D:
	# x2 de CANTIDAD (no de brillo): sobre un nombre entero, la cantidad de una veta se pierde.
	var fx := Particulas.destellos(lbl, color, lbl.size, intensidad, 2.0)
	# OBLIGATORIO: abrir un menu PARA el arbol (Game.abrir_menu), asi que sin esto los destellos se
	# quedarian congelados justo donde se supone que se miran.
	fx.process_mode = Node.PROCESS_MODE_ALWAYS

	# El tamaño real del Label no se sabe hasta que el contenedor lo coloca, asi que la zona de
	# emision se ajusta con el layout en vez de clavarse a un numero. Se recorta al ANCHO DEL TEXTO
	# (no al del Label, que se estira a toda la columna): los destellos tienen que estar sobre el
	# nombre, no flotando en el hueco vacio que queda a su derecha.
	var ajustar := func() -> void:
		var ancho: float = minf(lbl.size.x, lbl.get_minimum_size().x)
		fx.position = Vector2(ancho * 0.5, lbl.size.y * 0.5)
		fx.emission_rect_extents = Vector2(ancho * 0.5, lbl.size.y * 0.5)
	lbl.resized.connect(ajustar)
	ajustar.call()
	return fx


# `color_valor` (opcional) tiñe el VALOR. Se usa para el color de rareza (ver Upgrades.RAREZA_COLOR),
# que es lo que hace que una tabla de rarezas se lea de un vistazo. Es Variant y no Color para poder
# decir "sin tinte" con null, igual que los _row locales de inventory_menu y forge_menu.
static func fila(vb: VBoxContainer, etiqueta: String, valor: String, ancho: int = 170,
		color_valor: Variant = null) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = etiqueta
	k.custom_minimum_size = Vector2(ancho, 0)
	k.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	row.add_child(k)
	var v := Label.new()
	v.text = valor
	if color_valor is Color:
		v.add_theme_color_override("font_color", color_valor)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(v)
	vb.add_child(row)


# Texto en gris pequeño. SIN ancho minimo: en el panel de detalle (estrecho) un minimo empuja
# la columna entera fuera de la pantalla.
static func nota(vb: VBoxContainer, txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", GRIS)
	l.add_theme_font_size_override("font_size", 11)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(l)


# BOTON ESTANDAR de menu (Vender, Comprar, Fabricar...). Existe para que la medida sea UNA: cada
# menu tenia su propio helper con su propio alto y todos se quedaban por debajo de los 44 tactiles.
static func boton(parent: Node, texto: String, al_pulsar: Callable, activo: bool = true) -> Button:
	var b := Button.new()
	b.text = texto
	b.disabled = not activo
	b.custom_minimum_size = Vector2(0, ALTO_BOTON)
	if al_pulsar.is_valid():
		b.pressed.connect(al_pulsar)
	parent.add_child(b)
	return b


# Fila de botones-pestaña (los de arriba de la cabecera). `pulsado` recibe el indice.
static func pestanas(vb: BoxContainer, nombres: Array, activa: int, pulsado: Callable,
		ancho: int = 120) -> void:
	var fila_tabs := HBoxContainer.new()
	fila_tabs.add_theme_constant_override("separation", 6)
	for i in nombres.size():
		var b := Button.new()
		b.text = str(nombres[i])
		b.toggle_mode = true
		b.button_pressed = (i == activa)
		# 44 y no 30: una pestaña de 30 px de alto no se acierta con un pulgar. Va tambien en
		# escritorio, que ahi no molesta y evita tener dos medidas del mismo menu.
		b.custom_minimum_size = Vector2(ancho, 44)
		b.pressed.connect(pulsado.bind(i))
		fila_tabs.add_child(b)
	vb.add_child(fila_tabs)


# ============================================================
#  FICHA DE ARMA compartida
#  Una SOLA fuente de verdad para las stats de un arma. La tienda, el pack, el inventario y el
#  menu de personaje la pintaban cada uno por su cuenta, y al añadir una stat (la evasion) habia
#  que acordarse de tocar los cuatro sitios -> siempre se olvidaba uno. Ahora sale de aqui:
#  devuelve pares [etiqueta, valor] y cada menu los pinta con su propio _row. Todo se deriva de
#  Upgrades.weapon_mods, la misma math que usa el combate, asi que lo que ves es lo que tienes.
# ============================================================
const WEAPON_TIPO_LABELS := ["Puños", "Daga", "Espada corta", "Espada larga", "Mandoble",
	"Estoque", "Hacha grande", "Maza pequeña", "Martillo grande", "Bastón"]

static func filas_arma(w: WeaponData, tier: int, rareza: int, mejoras: Dictionary) -> Array:
	var m: Dictionary = Upgrades.weapon_mods(w, Game.tier_mult(tier), rareza, mejoras)
	var filas: Array = [
		["Tipo", WEAPON_TIPO_LABELS[clampi(int(w.tipo), 0, WEAPON_TIPO_LABELS.size() - 1)]
			+ ("  ·  magia" if w.es_magica else "")],
		["Manejo", "Dos manos" if w.dos_manos else "Una mano"],
		["Ataque", "%.1f" % float(m["raw"])],
		["Motion value", "×%.2f" % w.motion_value],
		["Velocidad", "×%.2f" % (w.velocidad_mult * float(m["vel_mult"]))],
	]
	if float(m["crit"]) != 0.0:
		filas.append(["Crítico", "%+.0f%%" % (float(m["crit"]) * 100.0)])
	# Daño critico: el multiplicador REAL de esta arma (base + su crit_dmg, que ya lleva rareza y
	# Precision dentro). Se enseña siempre: toda arma critica por algo, y es lo que sube Precision.
	filas.append(["Daño crítico", "×%.2f" % (StatsMath.CRIT_MULT + float(m["crit_dmg"]))])
	if float(m["precision"]) > 0.0:
		filas.append(["Precisión", "+%.0f%%" % (float(m["precision"]) * 100.0)])
	if float(m["evasion"]) > 0.0:
		filas.append(["Evasión", "+%.0f%%" % (float(m["evasion"]) * 100.0)])
	if float(m["aturdir"]) > 0.0:
		filas.append(["Aturdir", "%.0f%%" % (float(m["aturdir"]) * 100.0)])
	if float(m["bloqueo"]) > 0.0:
		filas.append(["Bloqueo", "+%.2f" % float(m["bloqueo"])])
	if w.es_magica:
		# Lo MAGICO tambien pasa por su math (Upgrades.magic_mods): antes se pintaba el magic_amp
		# CRUDO del .tres (1.70) y se callaban regen/coste/casteo, asi que el inventario enseñaba
		# un baston T3 legendario como uno de madera. Ahora sale lo REAL, igual que el menu C.
		var mg: Dictionary = Upgrades.magic_mods(w.magic_amp, Game.tier_mult(tier), rareza, mejoras)
		filas.append(["Amplif. magia", "×%.2f" % float(mg["magic_amp"])])
		filas.append(["Regen maná", "%.2f/turno" % (w.mp_regen_turno * float(mg["regen_mult"]))])
		filas.append(["Vel. casteo", "×%.2f" % (w.cast_vel_mult + float(mg["cast_vel_add"]))])
		if float(mg["mana_reduccion"]) > 0.0:
			filas.append(["Coste de maná", "-%.0f%%" % (float(mg["mana_reduccion"]) * 100.0)])
		filas += filas_critico_magico(mg, w.crit_bonus)
	return filas


# CRITICO MAGICO de un arma magica (baston o varita): lo que aporta ELLA, aparte del contest de tu
# Destreza. Va en su propia funcion porque lo pintan cuatro sitios (ficha de arma, inventario,
# tienda y menu de personaje) y la varita no pasa por filas_arma. `crit_base` = el crit_bonus propio
# del .tres, que hoy es 0 en todas.
static func filas_critico_magico(mg: Dictionary, crit_base: float = 0.0) -> Array:
	var filas: Array = []
	var crit: float = crit_base + float(mg["crit_magico"])
	if crit != 0.0:
		filas.append(["Crítico mágico", "%+.0f%%" % (crit * 100.0)])
	filas.append(["Daño crít. mágico", "×%.2f" % (StatsMath.CRIT_MULT + float(mg["crit_dmg_magico"]))])
	return filas


# La ficha de una HERRAMIENTA. Sale de Game.tool_mods, o sea de la MISMA math que arma el minijuego:
# lo que lees aqui es exactamente lo que vas a jugar. Los numeros nunca en la descripcion del .tres.
#
# Se enseñan las DOS cosas que la herramienta hace: la AFINIDAD (lo que te abre la ventana del
# minijuego) y el AHORRO de golpes. Las dos suben con la rareza y la veta; la afinidad ademas con el
# tier. Decirlo importa: mientras la afinidad fue plana por tier, un comun de metal en bruto rendia
# igual que un pristino de profundo y no habia motivo para gastar material bueno.
static func filas_herramienta(t: ToolData) -> Array:
	if t == null:
		return []
	var m: Dictionary = Game.tool_mods(t)
	var meta: Dictionary = Game.item_meta.get(t, {})
	var filas: Array = [["Tipo", t.tipo_texto()], ["Sirve para", TOOL_PARA[int(t.tipo)]]]
	if not Game.es_herramienta_forjada(t):
		filas.append(["Ayuda", "ninguna: es la de serie"])
		return filas
	filas.append(["Metal", "T%d  ·  %s" % [int(meta.get("tier", 1)),
		TOOL_VETA[Upgrades.banda_columna(int(meta.get("banda", 0)))]]])
	filas.append(["Afinidad", "+%.0f  (tier, rareza y veta)" % float(m["afinidad"])])
	var n: int = int(m["golpes_menos"])
	# La CAÑA gasta ese mismo numero en OTRA moneda: no quita tirones, alarga la ventana en la que
	# puedes clavar el tiron. Se enseña en segundos porque es lo que se juega.
	if t.es_cana():
		filas.append(["Ventana del tirón", "sin margen extra" if n <= 0
			else "+%.2f s  (rareza y veta)" % (float(n) * VENTANA_TIRON_POR_PUNTO)])
	else:
		filas.append(["Ahorro", "sin ahorro" if n <= 0 else "-%d %s  (rareza y veta)" % [
			n, t.unidad_golpes(n)]])
	return filas

# Lo que alarga la ventana del tiron cada punto de 'golpes_menos' de la caña. Copia del mismo numero
# en fishing_spot.gd (que es quien lo aplica) para que la ficha no mienta.
const VENTANA_TIRON_POR_PUNTO := 0.15

const TOOL_PARA := ["Vetas de mineral  ·  Fuerza", "Plantas  ·  Destreza", "Madera  ·  Agilidad",
	"Estanques  ·  Resistencia"]
const TOOL_VETA := ["en bruto", "veteado", "profundo"]


const SHIELD_TAMANO_LABELS := ["Pequeño", "Normal", "Grande"]

# La ficha del ESCUDO, por la misma via que la del arma (Upgrades -> la math del combate). Estaba
# copiada a pelo en el menu de personaje, el inventario y la tienda, y las tres leian el .tres
# CRUDO: enseñaban el mismo bloqueo para un T1 comun que para un T3 pristino. Ahora sale de aqui.
static func filas_escudo(sh: ShieldData, tier: int, rareza: int, mejoras: Dictionary) -> Array:
	var m: Dictionary = Upgrades.shield_mods(sh, Game.tier_mult(tier), rareza, mejoras)
	var filas: Array = [
		["Tipo", "Escudo %s  ·  mano secundaria"
			% SHIELD_TAMANO_LABELS[clampi(int(sh.tamano), 0, SHIELD_TAMANO_LABELS.size() - 1)].to_lower()],
		# Lo primero es la DEFENSA: es el numero que crece con tier, rareza y mejoras, o sea lo que
		# distingue a este escudo de otro igual peor. Y solo cuenta al Defender: hay que decirlo.
		["Defensa al bloquear", "+%.1f" % float(m["def"])],
		["Bloqueo", "%.0f%%" % (float(m["bloqueo"]) * 100.0)],
	]
	if float(m["resist_estados"]) > 0.0:
		filas.append(["Resist. estados", "+%.0f%%" % (float(m["resist_estados"]) * 100.0)])
	filas.append(["Velocidad", "×%.2f" % float(m["vel_mult"])])
	filas.append(["Penal. esquiva", "-%.0f%%" % (float(m["evasion_penal"]) * 100.0)])
	return filas


# Filas de ATRIBUTO para el PREVIEW de mejora (pestaña Mejorar del herrero): la MISMA math del
# combate (Upgrades.*_mods) calculada dos veces —con las mejoras actuales y con la categoria `cat`
# subida una vez— para enseñar el valor de ahora y, en verde, cuanto sube. Devuelve una lista de
# [etiqueta, valor, delta]; delta = "" cuando ese stat no cambia con esa mejora. Solo se listan los
# stats que una mejora PUEDE tocar (la reduccion/velocidad de tipo/tamaño no salen: son crudas).
static func filas_mejora(item: Resource, tier: int, rareza: int, mejoras: Dictionary, cat: String) -> Array:
	var despues: Dictionary = mejoras.duplicate(true)
	despues[cat] = int(despues.get(cat, 0)) + 1
	var tm: float = Game.tier_mult(tier)
	var filas: Array = []
	if item is WeaponData:
		var w := item as WeaponData
		var a := Upgrades.weapon_mods(w, tm, rareza, mejoras)
		var b := Upgrades.weapon_mods(w, tm, rareza, despues)
		_attr(filas, "Ataque", "%.1f" % float(a["raw"]), _d(float(a["raw"]), float(b["raw"]), "+%.1f"))
		_attr(filas, "Velocidad", "×%.2f" % (w.velocidad_mult * float(a["vel_mult"])),
			_d(w.velocidad_mult * float(a["vel_mult"]), w.velocidad_mult * float(b["vel_mult"]), "+%.2f"))
		if float(a["crit"]) != 0.0 or float(b["crit"]) != 0.0:
			_attr(filas, "Crítico", "%+.0f%%" % (float(a["crit"]) * 100.0),
				_d(float(a["crit"]) * 100.0, float(b["crit"]) * 100.0, "+%.0f%%"))
		_attr(filas, "Daño crítico", "×%.2f" % (StatsMath.CRIT_MULT + float(a["crit_dmg"])),
			_d(StatsMath.CRIT_MULT + float(a["crit_dmg"]), StatsMath.CRIT_MULT + float(b["crit_dmg"]), "+%.2f"))
		if float(a["precision"]) > 0.0 or float(b["precision"]) > 0.0:
			_attr(filas, "Precisión", "+%.0f%%" % (float(a["precision"]) * 100.0),
				_d(float(a["precision"]) * 100.0, float(b["precision"]) * 100.0, "+%.0f%%"))
		if float(a["aturdir"]) > 0.0 or float(b["aturdir"]) > 0.0:
			_attr(filas, "Aturdir", "%.0f%%" % (float(a["aturdir"]) * 100.0),
				_d(float(a["aturdir"]) * 100.0, float(b["aturdir"]) * 100.0, "+%.0f%%"))
		if w.es_magica:
			_filas_mejora_magia(filas, w.magic_amp, w.mp_regen_turno, w.cast_vel_mult, tm, rareza, mejoras, despues)
	elif item is WandData:
		var wd := item as WandData
		_filas_mejora_magia(filas, wd.magic_amp, wd.mp_regen_turno, wd.cast_vel_mult, tm, rareza, mejoras, despues)
	elif item is ShieldData:
		var sh := item as ShieldData
		var a := Upgrades.shield_mods(sh, tm, rareza, mejoras)
		var b := Upgrades.shield_mods(sh, tm, rareza, despues)
		_attr(filas, "Defensa al bloquear", "+%.1f" % float(a["def"]), _d(float(a["def"]), float(b["def"]), "+%.1f"))
		_attr(filas, "Bloqueo", "%.0f%%" % (float(a["bloqueo"]) * 100.0),
			_d(float(a["bloqueo"]) * 100.0, float(b["bloqueo"]) * 100.0, "+%.0f%%"))
		if float(a["resist_estados"]) > 0.0 or float(b["resist_estados"]) > 0.0:
			_attr(filas, "Resist. estados", "+%.0f%%" % (float(a["resist_estados"]) * 100.0),
				_d(float(a["resist_estados"]) * 100.0, float(b["resist_estados"]) * 100.0, "+%.0f%%"))
	elif item is ArmorData:
		var ar := item as ArmorData
		var a := Upgrades.armor_piece_mods(ar, tm, rareza, mejoras)
		var b := Upgrades.armor_piece_mods(ar, tm, rareza, despues)
		_attr(filas, "Defensa", "%.1f" % float(a["def"]), _d(float(a["def"]), float(b["def"]), "+%.1f"))
		if float(a["evasion"]) > 0.0 or float(b["evasion"]) > 0.0:
			_attr(filas, "Evasión", "+%.0f%%" % (float(a["evasion"]) * 100.0),
				_d(float(a["evasion"]) * 100.0, float(b["evasion"]) * 100.0, "+%.0f%%"))
		if float(a["crit_resist"]) > 0.0 or float(b["crit_resist"]) > 0.0:
			_attr(filas, "Resist. crítico", "+%.0f%%" % (float(a["crit_resist"]) * 100.0),
				_d(float(a["crit_resist"]) * 100.0, float(b["crit_resist"]) * 100.0, "+%.0f%%"))
		if float(a["resist_estados"]) > 0.0 or float(b["resist_estados"]) > 0.0:
			_attr(filas, "Resist. estados", "+%.0f%%" % (float(a["resist_estados"]) * 100.0),
				_d(float(a["resist_estados"]) * 100.0, float(b["resist_estados"]) * 100.0, "+%.0f%%"))
	return filas

# La parte magica (baston y varita comparten): amplificacion, regen, casteo y coste de maná.
static func _filas_mejora_magia(filas: Array, base_amp: float, mp_regen: float, cast_base: float,
		tm: float, rareza: int, mejoras: Dictionary, despues: Dictionary) -> void:
	var a := Upgrades.magic_mods(base_amp, tm, rareza, mejoras)
	var b := Upgrades.magic_mods(base_amp, tm, rareza, despues)
	_attr(filas, "Amplif. magia", "×%.2f" % float(a["magic_amp"]), _d(float(a["magic_amp"]), float(b["magic_amp"]), "+%.2f"))
	_attr(filas, "Regen maná", "%.2f/turno" % (mp_regen * float(a["regen_mult"])),
		_d(mp_regen * float(a["regen_mult"]), mp_regen * float(b["regen_mult"]), "+%.2f"))
	_attr(filas, "Vel. casteo", "×%.2f" % (cast_base + float(a["cast_vel_add"])),
		_d(cast_base + float(a["cast_vel_add"]), cast_base + float(b["cast_vel_add"]), "+%.2f"))
	if float(a["mana_reduccion"]) > 0.0 or float(b["mana_reduccion"]) > 0.0:
		_attr(filas, "Coste de maná", "-%.0f%%" % (float(a["mana_reduccion"]) * 100.0),
			_d(float(a["mana_reduccion"]) * 100.0, float(b["mana_reduccion"]) * 100.0, "+%.0f%%"))
	# CRITICO MAGICO: es lo que sube la mejora de Precision en un arma magica, asi que tiene que
	# verse en el preview o la mejora parece que no hace nada.
	if float(a["crit_magico"]) > 0.0 or float(b["crit_magico"]) > 0.0:
		_attr(filas, "Crítico mágico", "%+.0f%%" % (float(a["crit_magico"]) * 100.0),
			_d(float(a["crit_magico"]) * 100.0, float(b["crit_magico"]) * 100.0, "+%.0f%%"))
	_attr(filas, "Daño crít. mágico", "×%.2f" % (StatsMath.CRIT_MULT + float(a["crit_dmg_magico"])),
		_d(StatsMath.CRIT_MULT + float(a["crit_dmg_magico"]),
			StatsMath.CRIT_MULT + float(b["crit_dmg_magico"]), "+%.2f"))

static func _attr(filas: Array, etiqueta: String, valor: String, delta: String) -> void:
	filas.append([etiqueta, valor, delta])

# Delta formateado entre parentesis (o "" si no cambia). `fmt` lleva un unico marcador para el
# numero de la DIFERENCIA (ej. "+%.1f"). El umbral evita pintar "(+0.00)" por ruido de redondeo.
static func _d(antes: float, despues: float, fmt: String) -> String:
	if absf(despues - antes) < 0.005:
		return ""
	return "(" + (fmt % (despues - antes)) + ")"


# Cuadricula de botones. Por defecto 2 columnas de 150x44 (la columna de la LISTA de items, que
# lleva nombres largos). Los selectores de material pasan mas columnas y botones mas bajos: sus
# etiquetas son cortas y con 2 por fila la lista se iba a lo alto sin necesidad.
#
# `colores` es OPCIONAL y va en paralelo a `labels`: si trae un Color en la posicion i, ese boton
# escribe su texto con el. Es para el color de rareza / de rango del material, y aqui importa mas que
# en la ficha: la rejilla es donde ELIGES la pieza, asi que el color tiene que llegar ANTES de pulsar
# y no solo despues. Vacio (o con un no-Color) = como siempre.
#
# Aqui NO van particulas, solo color: son 20-40 botones a la vez. Las particulas son de la ficha
# (ver titulo_item).
# `deshabilitados` = indices que se pintan apagados y no responden (no tienes material, la pieza no
# encaja...). Va aqui para que las rejillas de los oficios no tengan que hacerse a mano solo por eso.
# `tooltips` = texto largo por boton, para cuando la etiqueta va recortada al nombre corto.
static func cuadricula(vb: VBoxContainer, labels: Array, sel: int, pulsado: Callable,
		columnas: int = 2, tam: Vector2 = Vector2(150, 44), colores: Array = [],
		deshabilitados: Array = [], tooltips: Array = []) -> void:
	var grid := GridContainer.new()
	grid.columns = maxi(1, columnas)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in labels.size():
		var b := Button.new()
		b.text = str(labels[i])
		b.toggle_mode = true
		b.button_pressed = (i == sel)
		b.clip_text = true
		b.custom_minimum_size = tam
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i < tooltips.size() and str(tooltips[i]) != "":
			b.tooltip_text = str(tooltips[i])
		if deshabilitados.has(i):
			b.disabled = true
		else:
			b.pressed.connect(pulsado.bind(i))
		tintar(b, colores[i] if i < colores.size() else null)
		grid.add_child(b)
	vb.add_child(grid)


# ============================================================
#  TEXTO QUE NO CABE: CARRUSEL
#  Un boton de rejilla mide 120-160 px y un nombre de equipo es "Daga +4  ·  T1 Comun" (y si la
#  lleva otro del grupo, ademas un "🔒 Fulano" en otra linea). Con clip_text se cortaba en seco y no
#  habia forma de leer el resto.
#
#  Las tres reglas, y son las tres a la vez:
#
#   1. MISMA VELOCIDAD SIEMPRE (VELOCIDAD_CARRUSEL px/s), mida lo que mida el texto. La duracion
#      sale de dividir lo que sobra entre esa velocidad -- nunca al reves. Un nombre el doble de
#      largo tarda el doble, no corre el doble.
#   2. CADA LINEA VA POR SU CUENTA. Si el nombre del objeto no cabe pero el de quien lo lleva si,
#      se mueve SOLO el nombre; el otro se queda quieto. Por eso cada linea es su propio Label
#      dentro de su propia ventanita, y no un unico Label de dos lineas.
#   3. CARRUSEL, no vaiven: avanza hasta que ha entrado el final del texto y ahi VUELVE AL PRINCIPIO
#      y empieza otra vez. Nada de ir y volver.
#
#  Va como Label DENTRO del boton (y el boton con clip_contents) y no como text del propio Button:
#  un Button no deja mover su texto, y ademas las particulas de rareza necesitan un Label para
#  colgarse (ver brillo_en). Dos pajaros.
# ============================================================

# Margen que se le deja al texto dentro de la caja (el borde del tema se come 2 px por lado).
const MARGEN_TEXTO := 8.0
# Pixeles por segundo del carrusel. UNO para todo el juego: es lo que hace que dos celdas distintas
# se lean al mismo ritmo.
const VELOCIDAD_CARRUSEL := 40.0

# Monta el texto dentro de 'caja' (una linea por cada \n) y devuelve el Label de la PRIMERA, que es
# el nombre del objeto: es al que se le cuelgan los destellos de la rareza.
static func texto_deslizante(caja: Control, texto: String, color: Variant = null) -> Label:
	caja.clip_contents = true
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(col)
	var primera: Label = null
	for linea in texto.split("\n"):
		var l: Label = _linea_carrusel(col, String(linea), color)
		if primera == null:
			primera = l
	return primera


# UNA linea: su ventanita (que recorta) y su Label dentro (que es lo que se mueve).
static func _linea_carrusel(col: VBoxContainer, texto: String, color: Variant) -> Label:
	var marco := Control.new()
	marco.clip_contents = true
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(marco)

	var lbl := Label.new()
	lbl.text = texto
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE   # el que se pulsa es el boton de debajo
	# OBLIGATORIO: abrir un menu PARA el arbol (Game.abrir_menu), y un Tween se para con el nodo al
	# que pertenece. Sin esto el carrusel se quedaria congelado justo cuando se supone que se lee. Es
	# el mismo aviso que lleva brillo_en para sus destellos.
	lbl.process_mode = Node.PROCESS_MODE_ALWAYS
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if color is Color:
		lbl.add_theme_color_override("font_color", color)
	marco.add_child(lbl)
	marco.custom_minimum_size = Vector2(0, lbl.get_minimum_size().y)

	# El ancho de verdad no se sabe hasta que el contenedor coloca la celda, asi que la decision de
	# rodar o no se toma con el layout (mismo motivo por el que brillo_en se reajusta en resized).
	var tween: Tween = null
	var colocar := func() -> void:
		var texto_ancho: float = lbl.get_minimum_size().x
		var hueco: float = marco.size.x - MARGEN_TEXTO
		var sobra: float = texto_ancho - hueco
		lbl.size = Vector2(maxf(texto_ancho, hueco), marco.size.y)
		if sobra <= 1.0:
			# CABE: quieto y centrado. Si venia rodando (la celda ha crecido), se corta.
			if tween != null and tween.is_valid():
				tween.kill()
				tween = null
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.position = Vector2(MARGEN_TEXTO * 0.5, 0)
			lbl.set_meta("pasea", false)
			return
		if tween != null and tween.is_valid():
			return   # ya esta rodando: no reiniciarlo en cada resize
		# Rodando se lee de izquierda a derecha: centrarlo ademas lo descuadraria al arrancar.
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var inicio: float = MARGEN_TEXTO * 0.5
		# Se apunta en el Label si esta rodando o no: por fuera no hay forma de preguntarle a un nodo
		# por sus tweens, y esto es lo que deja comprobarlo (y verlo de un vistazo al depurar).
		lbl.set_meta("pasea", true)
		# UN solo tramo en bucle: al acabar vuelve de golpe al principio (el .from lo garantiza) y
		# arranca otra vez. Eso es el carrusel; un segundo tramo de vuelta seria un vaiven.
		tween = lbl.create_tween().set_loops()
		tween.tween_property(lbl, "position:x", inicio - sobra, sobra / VELOCIDAD_CARRUSEL).from(inicio)
	marco.resized.connect(colocar)
	colocar.call()
	return lbl


# LA CELDA DE UNA REJILLA DE OBJETOS: el boton, su texto paseante y los destellos de la rareza.
#
# Las particulas aqui SI, al reves que en cuadricula(): esta celda es para rejillas de UNAS POCAS
# piezas (las armas que tienes, las cinco de un slot), no para las 20-40 de la tienda o el baul. Y
# solo las lleva lo que TIENE rareza: una pieza comun llega con color null y no gasta ni un emisor.
static func celda_item(grid: Node, texto: String, tam: Vector2, sel: bool, on_pick: Callable,
		color: Variant = null, intensidad: float = 0.0, activo: bool = true) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = sel
	b.custom_minimum_size = tam
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# El texto completo, siempre, en el tooltip: la marquesina se lee sola pero hay que esperarla, y
	# con el raton encima es mas rapido leerlo de golpe.
	b.tooltip_text = texto
	if activo and on_pick.is_valid():
		b.pressed.connect(on_pick)
	else:
		b.disabled = not activo
	grid.add_child(b)
	# DESPUES de meterlo en el arbol: el Label necesita el tamaño ya resuelto y el tween un nodo vivo.
	var lbl: Label = texto_deslizante(b, texto, color)
	if color is Color and intensidad > 0.0:
		brillo_en(lbl, color as Color, intensidad)
	return b


# El color que le toca a un item en una lista, o null si no tiene escala:
#   equipo (arma/escudo/varita/armadura/mochila) -> su RAREZA
#   material                                     -> su RANGO (banda / fase de pocion / nucleo)
#   cristal, pocion, o nada                      -> null (el cristal tiene su propia escala de
#                                                   categoria y calidad, que no es esta)
# Las clases se miran una a una a proposito: Game.meta_de solo entiende de equipo, asi que
# preguntarle por una pocion seria buscarse un problema.
static func color_de_item(m: Resource) -> Variant:
	if m == null:
		return null
	if m is MaterialItem:
		var d: MaterialData = (m as MaterialItem).data
		return d.color_rango() if d != null else null
	if m is MaterialData:
		return (m as MaterialData).color_rango()
	if m is WeaponData or m is ShieldData or m is WandData or m is ArmorData \
			or m is BackpackData or m is ToolData:
		return Game.color_rareza_de(m)
	return null


# Colores de una lista de stacks (`[{modelo: Resource, ...}, ...]`, que es como los guardan los tres
# menus con rejilla) o de Resources a pelo.
#
# Se derivan de los STACKS y no se pasan a mano junto a las etiquetas a proposito: las etiquetas
# salen de la misma lista y en el mismo orden, asi que asi es IMPOSIBLE que los colores se
# desalineen de los nombres. Un array paralelo construido aparte se habria descolgado en cuanto
# alguien filtrase una de las dos listas.
static func colores_de(stacks: Array) -> Array:
	var out: Array = []
	for s in stacks:
		if s is Dictionary:
			out.append(color_de_item((s as Dictionary).get("modelo") as Resource))
		else:
			out.append(color_de_item(s as Resource))
	return out


# El nombre CORTO de un material refinado, para las rejillas donde lo que eliges es el METAL y no la
# pieza: "Lingote de cobre" -> "Cobre", "Hebillas de hierro" -> "Hierro".
#
# En una rejilla de tres botones que dicen "Hebillas de cobre / Hebillas de hierro / Hebillas de
# acero", la palabra que repiten es la unica que NO estas eligiendo. Y en la pantalla de coser una
# mochila era peor: hacia que la rejilla pareciera la fila de ingredientes repetida.
static func metal_corto(m: MaterialData) -> String:
	if m == null:
		return "?"
	var partes: PackedStringArray = m.nombre.split(" de ")
	return (partes[partes.size() - 1] if partes.size() > 1 else m.nombre).capitalize()


# Pone el color de texto de un boton en sus cuatro estados. Hace falta los cuatro porque el tema por
# defecto de Godot tiene un font_color propio para hover/pressed/disabled: sin ellos el color de
# rareza se PERDIA al pasar el raton por encima o al quedarse el boton pulsado (y en estas rejillas el
# seleccionado esta pulsado siempre, o sea que era justo el que no se veia).
#
# Acepta Variant para poder decir "sin tinte" con null, igual que fila().
static func tintar(b: Button, color: Variant) -> void:
	if not (color is Color):
		return
	for estado in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(estado, color)


# ------------------------------------------------------------
#  SELECTOR DE MATERIAL EN DOS NIVELES (tier -> sub-tier)
#  Lo usan los tres oficios que refinan: herrero (fundir/chapas/hebillas), carpintero (aserrar)
#  y peletero (curtir). Va aqui y no en cada menu porque son tres sitios con la MISMA lista y el
#  mismo problema.
#
#  Con los sub-tiers, una fila plana se iba a siete botones repitiendo el tier en cada uno
#  ("Madera comun (T1)", "Madera de veta (T1)", "Madera anillada (T1)", "Madera dura (T2)"...):
#  ilegible, y encima escondia que el tier es el eje gordo y el sub-tier el pequeño. En dos
#  niveles cada fila responde a UNA pregunta: primero de que gama, luego cual de ella.
#
#  La fila de arriba lleva el tier ("Madera T1"); la de abajo ya NO lo repite, que para eso
#  acabas de elegirlo.
# ------------------------------------------------------------

# 4 por fila: las etiquetas ya no repiten el tier, asi que son cortas y caben. Con 2 por fila la
# lista se iba a lo alto sin necesidad y empujaba fuera las filas de calidad, que es lo que de
# verdad vienes a pulsar.
const COLUMNAS_SELECTOR := 4
const TAM_SELECTOR := Vector2(120, ALTO_BOTON)


# Los tiers presentes en una lista de MaterialData, ordenados. Es lo que pinta la fila de arriba.
static func tiers_de(mats: Array) -> Array:
	var vistos: Dictionary = {}
	for m in mats:
		if m != null:
			vistos[int((m as MaterialData).tier)] = true
	var out: Array = vistos.keys()
	out.sort()
	return out


# Los materiales de UN tier, ordenados por banda (base primero). Es la fila de abajo.
static func del_tier(mats: Array, tier: int) -> Array:
	var out: Array = []
	for m in mats:
		if m != null and int((m as MaterialData).tier) == tier:
			out.append(m)
	out.sort_custom(func(a, b): return int(a.mejora_min) < int(b.mejora_min))
	return out


# Pinta las DOS filas y devuelve el material elegido (null si la lista viene vacia).
# `nombre_gama` = como se llama la familia en la fila de arriba ("Madera", "Metal", "Piel").
# `tier_sel` / `sub_sel` = lo que hay elegido ahora; `on_tier` / `on_sub` reciben el indice nuevo.
#
# `sub_por_numero` cambia la fila de abajo de nombres ("Lingote de cobre veteado") a NUMEROS de
# sub-tier ("T1.2"), con el nombre en el tooltip. Es para las pantallas donde el material no es lo
# que eliges sino la VETA de una misma cosa (las herramientas): ahi los tres botones repetian
# "Lingote de cobre" y la palabra que cambiaba iba al final. En las de REFINAR se deja el nombre,
# porque ahi lo que eliges ES el material que va a salir.
static func selector_material(vb: VBoxContainer, mats: Array, nombre_gama: String,
		tier_sel: int, sub_sel: int, on_tier: Callable, on_sub: Callable,
		sub_por_numero: bool = false) -> MaterialData:
	if mats.is_empty():
		return null
	var tiers: Array = tiers_de(mats)
	var t: int = int(tiers[clampi(tier_sel, 0, tiers.size() - 1)])

	# Con nombre_gama vacio, el boton dice solo "T1". Es lo que se quiere cuando el titulo de encima
	# ya dice de que va la fila ("Metal · el tier pone la afinidad..."): repetir la palabra en los
	# tres botones es la tercera vez que se lee y ademas alarga lo unico que hay que comparar.
	var etiquetas_tier: Array = []
	for x in tiers:
		etiquetas_tier.append("T%d" % int(x) if nombre_gama == "" else "%s  T%d" % [nombre_gama, int(x)])
	cuadricula(vb, etiquetas_tier, clampi(tier_sel, 0, tiers.size() - 1), on_tier,
		COLUMNAS_SELECTOR, TAM_SELECTOR)

	# La fila de abajo solo se pinta si ese tier tiene MAS DE UNO: con un solo sub-tier (hoy el
	# acero, o cualquier tier que aun no se haya desdoblado) una fila de un boton solo estorba.
	var subs: Array = del_tier(mats, t)
	if subs.size() > 1:
		# Esta es la rejilla que MAS gana con el color: elegir sub-tier es elegir hasta que +N vas a
		# poder mejorar la pieza (ver MaterialData.cubre_mejora), y los tres cobres son marrones a 0.06
		# de distancia. Con el rango pintado, gris/verde/azul se lee sin abrir nada.
		var etiquetas_sub: Array = []
		var pistas_sub: Array = []
		for i in subs.size():
			var m: MaterialData = subs[i] as MaterialData
			# del_tier ordena por mejora_min, asi que .1 es la banda base y el ultimo la mejor veta.
			etiquetas_sub.append("T%d.%d" % [t, i + 1] if sub_por_numero else m.nombre)
			pistas_sub.append(m.nombre if sub_por_numero else "")
		cuadricula(vb, etiquetas_sub, clampi(sub_sel, 0, subs.size() - 1), on_sub,
			COLUMNAS_SELECTOR, TAM_SELECTOR, colores_de(subs), [], pistas_sub)
	return subs[clampi(sub_sel, 0, subs.size() - 1)] as MaterialData


# Stepper editable: −  [ n ]  +  con el numero ESCRIBIBLE (no solo con los botones). −/+ y escribir +
# Enter (o salir del campo) actualizan el numero, CAPADO a [minv, maxv]. Si `on_set` es valido, se
# llama con el nuevo valor en cada cambio (para guardar en la seleccion y rebuildear: OJO, que ese
# on_set NO rebuildee si el valor no cambia, o focus_exited durante el rebuild se realimenta).
# Si maxv <= minv no hay nada que elegir: todo va disabled (gris). DEVUELVE el LineEdit, para los
# casos (refinar) que leen la cantidad en el momento de pulsar "Crear" en vez de guardarla.
static func stepper(parent: Node, valor: int, minv: int, maxv: int, on_set: Callable = Callable()) -> LineEdit:
	var vacio: bool = maxv <= minv
	var v: int = clampi(valor, minv, maxv) if not vacio else minv
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)

	var campo := LineEdit.new()
	var menos := Button.new()
	var mas := Button.new()

	var aplicar := func(nuevo: int) -> void:
		# Si el campo se esta destruyendo, callar. Su focus_exited salta EN MITAD del vaciado del
		# panel (al sacarlo del arbol pierde el foco), y avisar entonces reconstruye el menu por
		# dentro de su propia reconstruccion: el panel salia pintado dos veces. Ademas escribiria el
		# valor viejo encima de la seleccion que acabas de elegir con el Auto. Ver vaciar().
		if muriendo(campo):
			return
		var c: int = clampi(nuevo, minv, maxv)
		campo.text = str(c)
		menos.disabled = vacio or c <= minv
		mas.disabled = vacio or c >= maxv
		if on_set.is_valid():
			on_set.call(c)

	# −, el numero y + a tamaño de DEDO (44). Eran de 30 de ancho y sin alto minimo: en movil se
	# fallaba mas de lo que se acertaba, y este es el control que mas se repite del juego (comprar,
	# vender, fabricar, refinar, depositar).
	menos.text = "−"
	menos.custom_minimum_size = Vector2(ALTO_BOTON, ALTO_BOTON)
	menos.disabled = vacio or v <= minv
	menos.focus_mode = Control.FOCUS_NONE
	menos.pressed.connect(func() -> void: aplicar.call(int(campo.text) - 1))
	caja.add_child(menos)

	campo.text = str(v)
	campo.alignment = HORIZONTAL_ALIGNMENT_CENTER
	campo.custom_minimum_size = Vector2(72, ALTO_BOTON)
	campo.add_theme_font_size_override("font_size", 18)
	campo.editable = not vacio
	campo.select_all_on_focus = true
	campo.max_length = 6
	campo.text_submitted.connect(func(t: String) -> void: aplicar.call(int(t)))
	campo.focus_exited.connect(func() -> void: aplicar.call(int(campo.text)))
	caja.add_child(campo)

	mas.text = "+"
	mas.custom_minimum_size = Vector2(ALTO_BOTON, ALTO_BOTON)
	mas.disabled = vacio or v >= maxv
	mas.focus_mode = Control.FOCUS_NONE
	mas.pressed.connect(func() -> void: aplicar.call(int(campo.text) + 1))
	caja.add_child(mas)

	parent.add_child(caja)
	return campo


# Parte una lista de valores (uno por PIEZA de una tanda) en tramos de piezas consecutivas que
# valen lo mismo. Con lotes por pieza, una tanda de 8 platos puede tener 8 probabilidades distintas
# y pintarlas una a una llena el panel; casi siempre son dos o tres tramos ("las 3 primeras al 25%,
# las 4 siguientes al 12%"), que es como se lee de un vistazo.
# Devuelve [{desde, hasta, i}] en base 1 (`i` = indice del primero del tramo, base 0).
static func tramos_iguales(claves: Array) -> Array:
	var out: Array = []
	for i in claves.size():
		if not out.is_empty() and str(claves[i]) == str(claves[int(out[out.size() - 1]["i"])]):
			out[out.size() - 1]["hasta"] = i + 1
		else:
			out.append({"desde": i + 1, "hasta": i + 1, "i": i})
	return out


# "Pieza 3" o "Piezas 1-3", segun el tramo. `nombre` para decir plato/poción/pieza en su oficio.
static func etiqueta_tramo(tramo: Dictionary, nombre: String = "Pieza", plural: String = "Piezas") -> String:
	var d: int = int(tramo["desde"])
	var h: int = int(tramo["hasta"])
	return "%s %d" % [nombre, d] if d == h else "%s %d-%d" % [plural, d, h]


# ------------------------------------------------------------
#  REJILLA DE PROBABILIDADES POR PIEZA (tandas)
#  La usan los tres oficios que fabrican de varias en varias: forjar (armas/armaduras), forjar
#  herramientas y coser mochilas. Una COLUMNA por tramo de piezas que salen iguales y una FILA por
#  rareza; apiladas en tablas sueltas, una tanda de catorce piezas eran catorce tablas.
# ------------------------------------------------------------

# `cabeceras` = lo que va encima de cada columna (los numeros de pieza: "1-3", "4"...).
# `filas` = [{etiqueta, color (Variant), valores: Array[String], extra: String}], una por rareza (o
# por lo que sea). Las celdas con GUION se pintan apagadas: es "esto no puede salir", no un cero.
#
# `extra` es la ULTIMA columna, la que dice QUE DA esa rareza ("afinidad +13, -1 golpe", "+29 de
# carga"). Va aqui dentro y no en una tabla aparte debajo: separada, la lista de rarezas salia dos
# veces en la misma pantalla. Si ninguna fila trae extra, esa columna es el hueco que empuja las
# demas a la izquierda.
#
# La letra se encoge con el numero de columnas porque el panel de detalle NO tiene scroll horizontal
# (ver construir): esto tiene que caber si o si. Medido a su ancho real (498 px): 14 columnas a
# letra 9 son 460 px, y 20 ya se salen -- por eso quien llama agrupa antes de pasarse de doce.
const GUION := "—"

static func rejilla_probs(vb: VBoxContainer, etiqueta_izq: String, cabeceras: Array,
		filas: Array, cabecera_extra: String = "", ancho_disp: float = 0.0) -> void:
	var n: int = cabeceras.size()
	if n <= 0:
		return
	# El tamaño MAS GRANDE que quepa, no uno fijo por numero de columnas: la pestaña de forjar tiene
	# el panel a 498 px (comparte fila con la cuadricula de piezas) pero herramientas y mochilas lo
	# tienen entero, 848, y ahi encoger la letra por tener siete columnas no venia a cuento.
	# Sin ancho (primer pintado, aun sin layout) se asume el panel estrecho, que es el que aprieta.
	var libre: float = ancho_disp if ancho_disp > 100.0 else 498.0
	if cabecera_extra != "":
		libre -= 150.0   # la columna de "aporta"
	var tam: int = 10
	var ancho_nombre: int = 88
	var ancho_col: int = 38
	# Ancho de columna FIJO y corto a proposito: las columnas van pegadas entre si y a la izquierda,
	# no repartidas por todo el panel (con tres, media pantalla se iba en huecos y no se comparaban).
	for opcion in [[14, 110, 52], [12, 96, 46]]:
		if float(int(opcion[1]) + n * (int(opcion[2]) + 4)) <= libre:
			tam = int(opcion[0])
			ancho_nombre = int(opcion[1])
			ancho_col = int(opcion[2])
			break

	var grid := GridContainer.new()
	# Una columna de mas al final: un hueco vacio que se come el ancho sobrante y empuja el resto a
	# la izquierda. Sin ella, el grid reparte el sobrante entre las columnas de datos.
	grid.columns = 2 + n
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 2)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_celda(grid, etiqueta_izq, ancho_nombre, tam, GRIS, false)
	for c in cabeceras:
		_celda(grid, str(c), ancho_col, tam, Color(0.7, 0.8, 0.95), true)
	_ultima(grid, cabecera_extra, tam, GRIS)
	for f in filas:
		var fila: Dictionary = f
		_celda(grid, str(fila.get("etiqueta", "")), ancho_nombre, tam, fila.get("color"), false)
		for v in (fila.get("valores", []) as Array):
			var txt: String = str(v)
			_celda(grid, txt, ancho_col, tam, GRIS if txt == GUION else fila.get("color"), true)
		_ultima(grid, str(fila.get("extra", "")), tam, fila.get("color"))
	vb.add_child(grid)


# La ultima columna: el texto de "que da" esta rareza, o (si viene vacio) el hueco que se lleva el
# ancho sobrante para que las columnas de numeros queden juntas y a la izquierda.
static func _ultima(grid: GridContainer, txt: String, tam: int, color: Variant) -> void:
	if txt == "":
		_relleno(grid)
		return
	var l := Label.new()
	l.text = "   " + txt
	l.add_theme_font_size_override("font_size", tam)
	if color is Color:
		l.add_theme_color_override("font_color", color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	grid.add_child(l)


# Una celda de la rejilla. `derecha` = las cifras, alineadas a la derecha para que las columnas se
# lean como una tabla; el resto (nombres) a la izquierda con su ancho minimo. Las cifras NO expanden:
# con expand, tres columnas se repartian el panel entero y quedaban a media pantalla unas de otras.
static func _celda(grid: GridContainer, txt: String, ancho: int, tam: int, color: Variant,
		derecha: bool) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", tam)
	if color is Color:
		l.add_theme_color_override("font_color", color)
	if ancho > 0:
		l.custom_minimum_size = Vector2(ancho, 0)
	if derecha:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.clip_text = true
	grid.add_child(l)


# La celda vacia del final de cada fila: se lleva el ancho que sobra.
static func _relleno(grid: GridContainer) -> void:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(c)


# Parte una tanda de `piezas` en tramos por su calidad de material, agrupando las que darian la MISMA
# columna. Si aun asi salen mas de `tope` columnas, redondea mas grueso (de 1 en 1 por ciento a 5,
# 10, 20...) hasta que quepan: mas alla de una docena ni encogiendo la letra entra, y comparar veinte
# columnas de tres digitos tampoco se lee.
static func tramos_por_calidad(materiales: Array, tope: int) -> Array:
	var tramos: Array = []
	for paso in [1, 2, 5, 10, 20, 50]:
		var claves: Array = []
		for m in materiales:
			claves.append(roundi(float(m) * 100.0 / float(paso)))
		tramos = tramos_iguales(claves)
		if tramos.size() <= tope:
			break
	return tramos


# La cabecera de una columna: solo los NUMEROS de pieza ("1-3", "14"). La palabra "pieza" se dice una
# vez, en la esquina de la izquierda.
static func numeros_tramo(tramo: Dictionary) -> String:
	var d: int = int(tramo["desde"])
	var h: int = int(tramo["hasta"])
	return str(d) if d == h else "%d-%d" % [d, h]


# Fila de un refinado: etiqueta + stepper editable + boton "Crear". `salen` = maximo que puedes hacer
# (0 = en gris, no se puede). Al pulsar Crear se lee la cantidad del stepper y se llama a `crear(n)`.
# Reemplaza el viejo "Hacer 1 / Hacer todo": ahora eliges cuantos (escribiendo o con −/+) y creas.
static func fila_refino(parent: Node, etiqueta: String, salen: int, crear: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = etiqueta
	l.custom_minimum_size = Vector2(240, 0)
	l.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92) if salen > 0 else Color(0.6, 0.63, 0.7))
	row.add_child(l)
	# Arranca en 0 (no en 1): nada "reservado" solo por abrir. Fijas la cantidad y luego Crear.
	var campo: LineEdit = stepper(row, 0, 0, salen)
	var b := Button.new()
	b.text = "Crear"
	b.custom_minimum_size = Vector2(0, ALTO_BOTON)
	b.disabled = salen < 1
	b.pressed.connect(func() -> void:
		var n: int = clampi(int(campo.text), 1, salen)
		if n >= 1:
			crear.call(n))
	row.add_child(b)
	parent.add_child(row)
