# ============================================================
#  creador_personaje.gd
#  La pantalla de "ponle cara a este personaje": nombre, imagen propia con su encuadre, ojos, boca,
#  pelo y ropa. Es una CAPA a pantalla completa que se monta sobre quien la llame.
#
#  La usan CUATRO sitios y con la misma pantalla en los cuatro:
#    - el menu principal, al crear una ranura;
#    - la TABERNA, al contratar a un companero (que se crea igual que te creaste tu);
#    - el HOGAR, para cambiarle el aspecto a cualquiera del grupo;
#    - el MULTIJUGADOR, para tu personaje dentro de un mundo y para bautizar el mundo (modo simple).
#
#  REHECHA EL 18/09/2026 CON LA CARA DE LOS DEMAS MENUS (MenuScaffold), y por dos motivos:
#
#   1. NO SE PODIA TERMINAR DE USAR. No habia ni un ScrollContainer: la pantalla se montaba en un
#      CenterContainer y lo que no cabia en los 720 px logicos se quedaba FUERA -- en la seccion de
#      la cara, el bloque de la imagen y los botones de Crear y Cancelar. Los comentarios de la
#      version anterior son la historia de esa pelea: el ColorPicker recortado hasta quedarse sin
#      cuadrado HSV, la muestra de imagen bajada a 128, la pantalla simple partida en dos columnas
#      y las piezas metidas de dos en dos para no pasar de cuatro pestañas. Con la columna de
#      opciones dentro de un scroll, ese problema deja de existir: se puede crecer hacia abajo.
#   2. Era la ultima pantalla con la cara vieja.
#
#  EL REPARTO (el del menu de personaje, decidido por el usuario): secciones en COLUMNA A LA
#  IZQUIERDA con su nombre escrito, el MUÑECO grande en el centro y las opciones a la derecha, con
#  scroll y con el pie de botones FIJO debajo (nunca se va de la pantalla).
#
#  LOS COLORES VAN EN MUESTRAS, no en un selector siempre abierto: se elige de un toque entre las de
#  la fila y, para uno cualquiera, "Más colores" abre el selector entero en un modal. Asi el trasto
#  mas alto de la pantalla solo ocupa sitio cuando se le pide.
#
#  DOS MODOS. Con 'previo["personaje"] = false' sale la pantalla simple (nombre, color e imagen, sin
#  muñeco): la usa multi_menu para bautizar un MUNDO compartido, donde un personaje girando no
#  significaria nada.
#
#  LOS DOS MANDOS VIEJOS SON DE LA CARA. 'brillo metalico' y 'color sobre la imagen' nacieron cuando
#  el cuerpo era un ColorRect y teñirlo pintaba al personaje entero; desde que hay capas, cada pieza
#  trae su color y su acabado, y estos dos se quedan con lo unico que no es una capa horneada: el
#  PNG que te pones de cara. Por eso viven en la seccion "Cara" y en ninguna otra.
#
#  Quien la abre no hereda nada: llama a abrir() y recibe el resultado por el Callable.
# ============================================================

extends CanvasLayer
class_name CreadorPersonaje

const AMBAR := Color(0.95, 0.72, 0.36)
const GRIS := Color(0.6, 0.63, 0.7)
# Color de salida de la creacion (uno cualquiera, ya lo cambiara).
const COLOR_INICIAL := Color(0.45, 0.72, 1.0)
const PELO_INICIAL := Color(0.24, 0.15, 0.10)

# --- LAS SECCIONES (la columna de la izquierda) ---
# Cuatro, y cada una se llama como lo que hay dentro. "Cara" lleva los ojos, la boca y tu imagen;
# "Ropa" lleva las tres prendas (camisa, pantalon y gorro), que ya no tienen que apretujarse en una
# sola fila de color: con scroll, cada una lleva la suya.
const SECCIONES := ["Quién es", "Cara", "Pelo", "Ropa"]
const SECCION_ICONOS := ["pergamino", "persona", "pelo", "ropa"]
const SEC_QUIEN := 0
const SEC_CARA := 1
const SEC_PELO := 2
const SEC_ROPA := 3

# Las piezas de cada seccion, en orden. Salen del CATALOGO de JugadorSprites, asi que el dia que se
# añada un peinado o una prenda aparece sola.
const PIEZAS_SECCION := {
	SEC_CARA: ["cara", "boca"],
	SEC_PELO: ["pelo"],
	SEC_ROPA: ["torso", "piernas", "gorro"],
}

const ANCHO_OPCIONES := 430.0
# Lo que mide la columna cuando es lo unico que hay (la pantalla simple, sin muñeco).
const ANCHO_SOLO := 560.0
const ALTO_TAB := 44.0
const LADO_ICONO_TAB := 22.0
const LADO_MUESTRA := 30.0

# LAS PALETAS. Son puntos de partida, no la lista de lo que se puede llevar: "Más colores" abre el
# selector entero. Van agrupadas por lo que se esta pintando porque un pelo verde lima y una camisa
# verde lima no se eligen en el mismo sitio de la rueda.
const COLORES_OJOS := [
	Color(0.36, 0.24, 0.14), Color(0.62, 0.40, 0.16), Color(0.20, 0.45, 0.85), Color(0.25, 0.65, 0.45),
	Color(0.55, 0.60, 0.65), Color(0.80, 0.25, 0.25), Color(0.62, 0.32, 0.78), Color(0.90, 0.78, 0.25),
]
const COLORES_PELO := [
	Color(0.10, 0.09, 0.10), Color(0.24, 0.15, 0.10), Color(0.42, 0.26, 0.15), Color(0.62, 0.44, 0.22),
	Color(0.85, 0.72, 0.42), Color(0.72, 0.32, 0.14), Color(0.78, 0.78, 0.82), Color(0.96, 0.96, 0.98),
	Color(0.30, 0.45, 0.80), Color(0.28, 0.60, 0.45), Color(0.70, 0.30, 0.55), Color(0.55, 0.32, 0.75),
]
const COLORES_ROPA := [
	Color(0.82, 0.84, 0.88), Color(0.55, 0.58, 0.64), Color(0.26, 0.28, 0.33), Color(0.12, 0.13, 0.16),
	Color(0.45, 0.30, 0.18), Color(0.62, 0.45, 0.25), Color(0.72, 0.24, 0.22), Color(0.85, 0.55, 0.20),
	Color(0.88, 0.78, 0.35), Color(0.30, 0.55, 0.32), Color(0.24, 0.45, 0.72), Color(0.45, 0.28, 0.62),
]

# --- Estado de la IMAGEN mientras se encuadra (ver png_cuadrado) ---
# _png es lo que se va a guardar; _src es la foto ORIGINAL ya encogida, que se queda a mano para
# poder reencuadrar sin volver a leer el fichero. Son variables de la instancia (y no locales del
# montaje) porque las tocan varios lambdas: el slider de zoom, el arrastre y el boton de quitar.
var _png: PackedByteArray = PackedByteArray()
var _tex: Texture2D = null
var _src: Image = null
var _zoom: float = 1.0
var _centro: Vector2 = Vector2(0.5, 0.5)

# --- El aspecto que se esta montando ---
var _metal: float = 0.0
var _tinte: float = 0.0
# El personaje de mentira que se le enseña a la vista previa. Es un PersonajeData de verdad para que
# la vista no tenga que saber nada de esta pantalla: se le pasa una persona, como en el juego.
var _pj: PersonajeData = null
var _vista: VistaMuneco = null
var _nombre: LineEdit = null

# --- La pantalla ---
var _root: Control = null
var _aviso: Label = null
var _content: VBoxContainer = null
var _titulo_seccion: Label = null
var _tabs: Array[Button] = []
var _paginas: Array[Control] = []
var _seccion: int = 0
# Los botones de cada fila de modelos y de cada fila de colores, por pieza: se actualizan EN EL SITIO
# al pulsar en vez de repintar la seccion entera. Repintar costaria el foco del nombre y el encuadre
# de la imagen a medio hacer.
var _chips: Dictionary = {}      # pieza -> [{"b": Button, "modelo": String}]
var _muestras: Dictionary = {}   # pieza -> [{"b": Button, "color": Color}]

var _on_aceptar: Callable


# Monta la pantalla sobre 'padre' y la devuelve.
#   previo      = {"nombre","color","metalico","color_alpha","imagen","piezas"}
#                 (vacio = personaje en blanco). Ademas:
#                 "personaje": false  -> pantalla simple, sin secciones ni muñeco (bautizar un mundo)
#                 "etiqueta_nombre" / "nombre_defecto" / "extras"
#   on_aceptar  = func(nombre: String, aspecto: Dictionary)
#                 'aspecto' es el de PersonajeData.aspecto_completo: color, metalico, imagen,
#                 color_alpha y piezas. UN dict y no cinco argumentos, porque cada pieza nueva
#                 obligaba a tocar las siete firmas por las que pasa esto.
# El que acepta se encarga de cerrar la capa si quiere (aqui se cierra sola al aceptar).
static func abrir(padre: Node, titulo: String, subtitulo: String, texto_boton: String,
		previo: Dictionary, on_aceptar: Callable) -> CreadorPersonaje:
	var c := CreadorPersonaje.new()
	c._on_aceptar = on_aceptar
	padre.add_child(c)
	c._montar(titulo, subtitulo, texto_boton, previo)
	return c


func _montar(titulo: String, subtitulo: String, texto_boton: String, previo: Dictionary) -> void:
	# Los menus del juego pausan el arbol: sin esto, la pantalla se abriria congelada. Y la capa va
	# por encima de todo lo que haya debajo (el menu principal, el hogar, la lista de mundos).
	process_mode = Node.PROCESS_MODE_ALWAYS
	# ENCIMA DE TODOS LOS MENUS (91-95) y de la ficha tactil (96), por debajo del combate (100): esta
	# pantalla se abre SOBRE el hogar y sobre la lista de mundos, que ya son capas. Con 90 se quedaba
	# por DEBAJO del hogar (91) y al tocar "Aspecto" no se veia nada.
	layer = 97

	var es_personaje: bool = bool(previo.get("personaje", true))
	_png = previo.get("imagen", PackedByteArray())
	_tex = Game.textura_de_png(_png)
	# Lo guardado ya es un cuadrado, asi que entra de fuente tal cual (zoom 1, centrada). Se puede
	# reencuadrar, pero sobre lo ya recortado: la foto original no viaja en la partida.
	_src = _imagen_de_png(_png)
	_zoom = 1.0
	_centro = Vector2(0.5, 0.5)
	_metal = float(previo.get("metalico", 0.0))
	_tinte = float(previo.get("color_alpha", 0.0))

	# El personaje de la vista previa, con lo que traiga el previo. Se monta SIEMPRE (aunque no haya
	# muñeco) porque es tambien donde vive el aspecto mientras se toquetea.
	_pj = PersonajeData.new()
	_pj.color = previo.get("color", COLOR_INICIAL)
	_pj.aspecto = PersonajeData.aspecto_nuevo(_pj.color)
	if not (previo.get("piezas", {}) as Dictionary).is_empty():
		_pj.aplicar_aspecto({"piezas": previo["piezas"]})
	elif not previo.has("color"):
		_pj.poner_pieza("pelo", "corto", PELO_INICIAL)

	# EL ESQUELETO DE LOS MENUS: fondo, ✕ de cerrar, columna lateral, los dos scrolls y el deslizar
	# con el dedo. La ✕ cancela, igual que el boton de abajo.
	var m: Dictionary = MenuScaffold.construir(self, "", subtitulo, _cancelar, false, true)
	_root = m["root"]
	_aviso = m["aviso"]
	_content = m["content"]

	_montar_lateral(m, titulo, es_personaje)
	var split: BoxContainer = _montar_centro(m, es_personaje)
	_montar_derecha(split, texto_boton, previo, es_personaje)

	# Las secciones se construyen TODAS y se enseña la que toque: asi lo elegido en cada una sigue
	# montado (el nombre escrito, el encuadre de la foto) al ir y volver.
	if es_personaje:
		_paginas = [_pagina_quien(previo), _pagina_piezas(SEC_CARA), _pagina_piezas(SEC_PELO),
			_pagina_piezas(SEC_ROPA)]
	else:
		_paginas = [_pagina_simple(previo)]
	for p in _paginas:
		_content.add_child(p)
	_ir_a(0)

	_refrescar()
	_root.visible = true
	_nombre.grab_focus()


# LA COLUMNA DE LA IZQUIERDA: el titulo en dos lineas (de donde vienes arriba, en pequeño, y la
# seccion abierta en grande) y debajo las secciones. Es el reparto del menu de personaje.
func _montar_lateral(m: Dictionary, titulo: String, es_personaje: bool) -> void:
	var col_tabs: VBoxContainer = m["side"]
	var lateral: BoxContainer = col_tabs.get_parent()
	# La etiqueta de titulo del esqueleto se esconde en vez de borrarse: un Control oculto no ocupa
	# sitio en un contenedor, asi que basta con eso y no hay que tocar construir().
	(lateral.get_child(0) as Control).visible = false

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 0)
	var chico := Label.new()
	chico.text = titulo
	chico.add_theme_font_size_override("font_size", 11)
	chico.add_theme_color_override("font_color", GRIS)
	chico.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(chico)
	_titulo_seccion = Label.new()
	_titulo_seccion.add_theme_font_size_override("font_size", 20)
	_titulo_seccion.add_theme_color_override("font_color", AMBAR)
	caja.add_child(_titulo_seccion)
	lateral.add_child(caja)
	lateral.move_child(caja, 0)

	if not es_personaje:
		return
	for i in SECCIONES.size():
		var b: Button = _pestana_lateral(SECCION_ICONOS[i], SECCIONES[i])
		b.pressed.connect(_ir_a.bind(i))
		col_tabs.add_child(b)
		_tabs.append(b)


# LA COLUMNA DEL CENTRO: la vista previa, grande y SIN scroll. Es la razon de que esta pantalla
# exista tal cual: se elige una silueta, y una silueta no se juzga quieta.
#
# El scroll de la lista del esqueleto se tira: aqui no hay lista que desplazar, y dejarlo dentro le
# daria al muñeco solo su alto minimo en vez de toda la columna.
func _montar_centro(m: Dictionary, es_personaje: bool) -> BoxContainer:
	var scroll_lista: ScrollContainer = m["lista_scroll"]
	var split: BoxContainer = scroll_lista.get_parent()
	split.remove_child(scroll_lista)
	scroll_lista.queue_free()
	if not es_personaje:
		return split

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(col)
	split.move_child(col, 0)

	var lbl := Label.new()
	lbl.text = "Así se verá"
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", GRIS)
	col.add_child(lbl)

	_vista = VistaMuneco.new()
	_vista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_vista)
	return split


# LA COLUMNA DE LA DERECHA: las opciones DENTRO del scroll y el pie de botones FUERA, debajo. Es lo
# que arregla el fallo que traia esta pantalla -- por larga que sea la seccion, Crear y Cancelar
# siguen estando donde estaban. Mismo reparto que el pie de acciones de los talleres.
func _montar_derecha(split: BoxContainer, texto_boton: String, previo: Dictionary,
		es_personaje: bool) -> void:
	var scroll: ScrollContainer = _content.get_parent() as ScrollContainer
	split.remove_child(scroll)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	# Sin muñeco (la pantalla de bautizar un mundo) la columna se queda SOLA: se centra y se ensancha,
	# que si no se pega al borde izquierdo con media pantalla vacia al lado.
	col.custom_minimum_size = Vector2(ANCHO_OPCIONES if es_personaje else ANCHO_SOLO, 0)
	col.size_flags_horizontal = Control.SIZE_FILL if es_personaje else Control.SIZE_SHRINK_CENTER
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(col)

	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)

	var pie := HBoxContainer.new()
	pie.alignment = BoxContainer.ALIGNMENT_END
	pie.add_theme_constant_override("separation", 10)
	col.add_child(pie)

	MenuScaffold.pastilla(pie, "Cancelar", _cancelar, false)
	# BOTONES DE MAS que pone quien abre la pantalla. Nacio para el "Importar personaje" de los mundos
	# compartidos: alli crear uno nuevo y traerse uno hecho son la misma decision, asi que el boton
	# tiene que estar AQUI y no en un panel previo que te obligue a elegir antes de ver nada.
	#   previo["extras"] = [{"texto": String, "fn": Callable}]
	# A la funcion se le pasa ESTA pantalla, para que decida ella si cerrarla: si lo que abre se puede
	# cancelar (como la lista de partidas), el creador tiene que seguir vivo detras.
	for ex in previo.get("extras", []):
		var fn: Callable = (ex as Dictionary).get("fn", Callable())
		MenuScaffold.pastilla(pie, String((ex as Dictionary).get("texto", "...")),
			func() -> void:
				if fn.is_valid():
					fn.call(self), false)
	MenuScaffold.pastilla(pie, texto_boton, _aceptar)


func _pestana_lateral(icono: String, nombre: String) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, ALTO_TAB)
	b.text = nombre
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.tooltip_text = nombre
	# EL HUECO DEL ICONO se reserva con el margen del stylebox, NO metiendo espacios delante del
	# texto: los espacios miden lo que mida el espacio de la fuente y el icono acaba pintado ENCIMA
	# de la primera letra.
	for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxEmpty.new()
		sb.content_margin_left = LADO_ICONO_TAB + 20.0
		b.add_theme_stylebox_override(estado, sb)
	var dibujo := Callable(Iconos, icono)
	b.draw.connect(func() -> void:
		var col: Color = AMBAR if b.button_pressed else MenuScaffold.TAB_APAGADA
		b.add_theme_color_override("font_color", col)
		dibujo.call(b, Vector2(8.0, (b.size.y - LADO_ICONO_TAB) * 0.5), LADO_ICONO_TAB, col)
		if b.button_pressed:
			b.draw_rect(Rect2(Vector2(0, 4), Vector2(3, b.size.y - 8)), AMBAR))
	b.toggled.connect(func(_on: bool) -> void: b.queue_redraw())
	return b


func _ir_a(i: int) -> void:
	_seccion = clampi(i, 0, _paginas.size() - 1)
	for j in _paginas.size():
		_paginas[j].visible = (j == _seccion)
	for j in _tabs.size():
		_tabs[j].button_pressed = (j == _seccion)
	if _titulo_seccion != null:
		_titulo_seccion.text = SECCIONES[_seccion] if _tabs.size() > 0 else "Nombre"


# ESC cancela, como la ✕. Es la tecla con la que se sale de todos los menus del juego.
func _unhandled_key_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo \
			and (ev as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_cancelar()


func _aceptar() -> void:
	if _on_aceptar.is_valid():
		_on_aceptar.call(_nombre.text, _aspecto())
	queue_free()


func _cancelar() -> void:
	queue_free()


# Lo que se devuelve al aceptar: el aspecto ENTERO en el formato de PersonajeData.
func _aspecto() -> Dictionary:
	var d: Dictionary = _pj.aspecto_completo()
	d["metalico"] = _metal
	d["color_alpha"] = _tinte
	d["imagen"] = _png
	return d


# ============================================================
#  LAS SECCIONES
# ============================================================
func _pagina_quien(previo: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	# Esta pantalla no siempre bautiza a una persona: tambien se usa para ponerle nombre e icono a un
	# MUNDO compartido (ver multi_menu.gd), y ahi "¿Como se llama?" con «Aventurero» debajo no dice
	# nada. Quien la abre puede pasar su propia etiqueta y su propio nombre por defecto.
	MenuScaffold.titulo(v, str(previo.get("etiqueta_nombre", "¿Cómo se llama?")), 14)
	_nombre = LineEdit.new()
	_nombre.placeholder_text = str(previo.get("nombre_defecto", Game.NOMBRE_POR_DEFECTO))
	_nombre.max_length = 16
	_nombre.custom_minimum_size = Vector2(0, 40)
	_nombre.text = str(previo.get("nombre", ""))
	v.add_child(_nombre)
	MenuScaffold.nota(v, "Hasta 16 letras. Si lo dejas en blanco se queda con el de la muestra.")
	return v


# UNA SECCION DE PIEZAS: por cada pieza, sus modelos en chips y su fila de colores. La cara ademas
# lleva el bloque de la imagen, que es lo unico que no es una pieza dibujada.
func _pagina_piezas(sec: int) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	for pieza in PIEZAS_SECCION[sec]:
		_bloque_pieza(v, String(pieza))
	if sec == SEC_CARA:
		# LOS RASGOS SOLO SE VEN SIN FOTO, y hay que decirlo aqui: si no, eliges unos ojos, pones tu
		# imagen encima y parece que el selector no hace nada.
		MenuScaffold.nota(v, "Los ojos y la boca solo se ven si no pones imagen.")
		v.add_child(HSeparator.new())
		_bloque_imagen(v)
	return v


# Los modelos de una pieza y su color. Los modelos salen del CATALOGO, no de una lista escrita aqui:
# el dia que se añada un peinado tiene que aparecer solo.
func _bloque_pieza(v: VBoxContainer, pieza: String) -> void:
	var cat: Dictionary = JugadorSprites.CATALOGO.get(pieza, {})

	# La cabecera: el nombre de la pieza y, si esa pieza lleva color, el boton del selector entero a
	# la derecha. Va en la misma linea que el titulo y no al final de las muestras, donde el ancho de
	# la columna lo bajaba a un renglon para el solo.
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 8)
	v.add_child(cab)
	var t := Label.new()
	t.text = String(cat.get("titulo", pieza))
	t.add_theme_font_size_override("font_size", 14)
	t.add_theme_color_override("font_color", AMBAR)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(t)
	if _lleva_color(pieza, cat):
		MenuScaffold.pastilla(cab, "Más colores…", func() -> void: _abrir_picker(pieza), false)

	var opciones: Array = []
	for mm in (cat.get("modelos", {}) as Dictionary):
		opciones.append({"m": String(mm), "n": String(cat["modelos"][mm]["nombre"])})
	opciones.append({"m": "", "n": String(cat.get("sin_nada", "Sin nada"))})

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(grid)

	var lista: Array = []
	var puesto: String = String(_pj.pieza(pieza)["modelo"])
	for o in opciones:
		var modelo: String = String(o["m"])
		var b := Button.new()
		b.text = String(o["n"])
		b.toggle_mode = true
		b.button_pressed = modelo == puesto
		MenuScaffold.estilo_chip(b, b.button_pressed)
		b.pressed.connect(func() -> void: _elegir_modelo(pieza, modelo))
		grid.add_child(b)
		lista.append({"b": b, "modelo": modelo})
	_chips[pieza] = lista

	if _lleva_color(pieza, cat):
		_fila_colores(v, pieza)


# ¿ESTA PIEZA LLEVA COLOR? La BOCA no: su capa va sin tinte (JugadorSprites.CATALOGO) y ponerle una
# fila de muestras seria ofrecer algo que no hace nada. Los OJOS tampoco tiñen su capa, pero los
# modelos con iris llevan una segunda capa que SI se tiñe con este color, asi que cuentan.
func _lleva_color(pieza: String, cat: Dictionary) -> bool:
	if bool(cat.get("tinte", true)):
		return true
	for mm in (cat.get("modelos", {}) as Dictionary):
		if bool((cat["modelos"][mm] as Dictionary).get("iris", false)):
			return true
	return false


# LA FILA DE COLORES de una pieza: muestras redondas. Antes esto era un ColorPicker siempre abierto
# en la columna, y era la pieza que se comia el alto de la pantalla.
func _fila_colores(v: VBoxContainer, pieza: String) -> void:
	var fila := HFlowContainer.new()
	fila.add_theme_constant_override("h_separation", 6)
	fila.add_theme_constant_override("v_separation", 6)
	v.add_child(fila)

	var lista: Array = []
	for c in _paleta_de(pieza):
		var b := Button.new()
		b.custom_minimum_size = Vector2(LADO_MUESTRA, LADO_MUESTRA)
		b.focus_mode = Control.FOCUS_NONE
		var col: Color = c
		b.pressed.connect(func() -> void: _elegir_color(pieza, col))
		fila.add_child(b)
		lista.append({"b": b, "color": col})
	_muestras[pieza] = lista
	_pintar_muestras(pieza)


# El color puesto se marca con un aro blanco. Se repinta en el sitio al elegir: repintar la seccion
# entera costaria el foco del nombre y el encuadre de la foto a medias.
func _pintar_muestras(pieza: String) -> void:
	var actual: Color = _pj.pieza(pieza)["color"]
	for e in _muestras.get(pieza, []):
		var b: Button = e["b"]
		var c: Color = e["color"]
		var puesto: bool = c.is_equal_approx(actual)
		for estado in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = c
			sb.set_corner_radius_all(int(LADO_MUESTRA * 0.5))
			if puesto or estado != "normal":
				sb.border_color = Color.WHITE if puesto else Color(1, 1, 1, 0.7)
				sb.set_border_width_all(2 if puesto else 1)
			b.add_theme_stylebox_override(estado, sb)


func _paleta_de(pieza: String) -> Array:
	match pieza:
		"cara", "boca": return COLORES_OJOS
		"pelo", "barba": return COLORES_PELO
		_: return COLORES_ROPA


func _elegir_modelo(pieza: String, modelo: String) -> void:
	var p: Dictionary = _pj.pieza(pieza)
	_pj.poner_pieza(pieza, modelo, p["color"], p["metal"])
	for e in _chips.get(pieza, []):
		var b: Button = e["b"]
		var marcada: bool = String(e["modelo"]) == modelo
		b.button_pressed = marcada
		MenuScaffold.estilo_chip(b, marcada)
	_refrescar()


func _elegir_color(pieza: String, c: Color) -> void:
	var p: Dictionary = _pj.pieza(pieza)
	_pj.poner_pieza(pieza, String(p["modelo"]), c, float(p["metal"]))
	_pintar_muestras(pieza)
	_refrescar()


# EL SELECTOR ENTERO, en un modal. Aqui si cabe con su cuadrado de color: el modal es una caja
# centrada de 620 px que tapa el menu, no una columna peleando por el alto.
func _abrir_picker(pieza: String) -> void:
	var titulo: String = String(JugadorSprites.CATALOGO.get(pieza, {}).get("titulo", pieza))
	var mo: Dictionary = MenuScaffold.modal(_root, "COLOR · %s" % titulo.to_upper())
	var picker := ColorPicker.new()
	picker.edit_alpha = false   # translucido no: eres un cuerpo, no un fantasma
	picker.sampler_visible = false
	picker.can_add_swatches = false
	picker.presets_visible = false
	picker.color = _pj.pieza(pieza)["color"]
	picker.color_changed.connect(func(c: Color) -> void: _elegir_color(pieza, c))
	(mo["cuerpo"] as VBoxContainer).add_child(picker)
	MenuScaffold.pastilla(mo["acciones"], "Listo", func() -> void:
		(mo["capa"] as Node).queue_free())


# LA PANTALLA SIMPLE: nombre, color e imagen, sin secciones ni muñeco. Es la de bautizar un MUNDO.
# Ahora cabe en una sola columna porque la columna tiene scroll.
func _pagina_simple(previo: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(_pagina_quien(previo))
	MenuScaffold.titulo(v, "Su color", 14)
	var fila := HFlowContainer.new()
	fila.add_theme_constant_override("h_separation", 6)
	fila.add_theme_constant_override("v_separation", 6)
	v.add_child(fila)
	var muestras: Array = []
	for c in COLORES_ROPA:
		var b := Button.new()
		b.custom_minimum_size = Vector2(LADO_MUESTRA, LADO_MUESTRA)
		b.focus_mode = Control.FOCUS_NONE
		var col: Color = c
		b.pressed.connect(func() -> void:
			_pj.color = col
			_pintar_muestras_simple(muestras)
			_refrescar())
		fila.add_child(b)
		muestras.append({"b": b, "color": col})
	_pintar_muestras_simple(muestras)
	MenuScaffold.pastilla(fila, "Más colores…", func() -> void:
		var mo: Dictionary = MenuScaffold.modal(_root, "COLOR")
		var picker := ColorPicker.new()
		picker.edit_alpha = false
		picker.sampler_visible = false
		picker.can_add_swatches = false
		picker.presets_visible = false
		picker.color = _pj.color
		picker.color_changed.connect(func(c: Color) -> void:
			_pj.color = c
			_pintar_muestras_simple(muestras)
			_refrescar())
		(mo["cuerpo"] as VBoxContainer).add_child(picker)
		MenuScaffold.pastilla(mo["acciones"], "Listo", func() -> void:
			(mo["capa"] as Node).queue_free()), false)
	v.add_child(HSeparator.new())
	_bloque_imagen(v)
	return v


func _pintar_muestras_simple(muestras: Array) -> void:
	for e in muestras:
		var b: Button = e["b"]
		var c: Color = e["color"]
		var puesto: bool = c.is_equal_approx(_pj.color)
		for estado in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = c
			sb.set_corner_radius_all(int(LADO_MUESTRA * 0.5))
			if puesto:
				sb.border_color = Color.WHITE
				sb.set_border_width_all(2)
			b.add_theme_stylebox_override(estado, sb)


# ============================================================
#  LA IMAGEN
# ============================================================
# LA IMAGEN y su encuadre: la muestra cuadrada donde se arrastra para recolocar la foto, el zoom, y
# los dos mandos que barnizan y tiñen ESA imagen.
#
# LA MUESTRA SIGUE SIENDO UN ColorRect y no el muñeco: aqui se esta ENCUADRANDO una foto, y para eso
# hace falta verla entera y grande. Como se le queda en la cabeza se ve al lado, en la vista previa.
func _bloque_imagen(v: VBoxContainer) -> void:
	MenuScaffold.titulo(v, "Tu imagen", 14)

	# OJO con el SHRINK_CENTER: un Control dentro de un VBoxContainer se estira a lo ANCHO de la
	# columna, y custom_minimum_size solo pone un minimo -> sin esto la muestra sale rectangular por
	# mucho que pidas un cuadrado.
	var muestra := ColorRect.new()
	muestra.custom_minimum_size = Vector2(160, 160)
	muestra.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	muestra.color = _pj.color
	v.add_child(muestra)

	var fila_img := HBoxContainer.new()
	fila_img.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_img.add_theme_constant_override("separation", 8)
	v.add_child(fila_img)
	var poner: Button = MenuScaffold.pastilla(fila_img, "Poner una imagen…", Callable(), false)
	var quitar: Button = MenuScaffold.pastilla(fila_img, "Quitar", Callable(), false, _tex != null)

	# ENCUADRE: cuanto se acerca el recorte. Mover se hace ARRASTRANDO sobre la muestra (el aviso de
	# abajo lo dice): dos sliders mas de X/Y serian peor, y arrastrar la propia imagen es lo que
	# espera cualquiera.
	var lbl_zoom: Label = MenuScaffold.titulo(v, "Acercar la imagen", 12, GRIS)
	var zoom := HSlider.new()
	zoom.min_value = 1.0    # 1 = el cuadrado mas grande que quepa en la foto
	zoom.max_value = 3.0
	zoom.step = 0.05
	zoom.value = 1.0
	zoom.editable = _src != null   # sin imagen no hay nada que encuadrar
	v.add_child(zoom)

	# ACABADO METALICO de TU IMAGEN: de mate (0) a pulido (1). El brillo se ve moverse en la muestra
	# mientras lo subes, que es la unica forma de elegirlo con criterio.
	MenuScaffold.titulo(v, "Brillo metálico", 12, GRIS)
	var metal := HSlider.new()
	metal.min_value = 0.0
	metal.max_value = 1.0
	metal.step = 0.05
	metal.value = _metal
	v.add_child(metal)

	# TINTE: cuanto se ve el color POR ENCIMA de la imagen. Solo tiene sentido con imagen, asi que se
	# enseña apagado hasta que pongas una.
	var lbl_tinte: Label = MenuScaffold.titulo(v, "Color sobre la imagen", 12, GRIS)
	var tinte := HSlider.new()
	tinte.min_value = 0.0
	tinte.max_value = 1.0
	tinte.step = 0.05
	tinte.value = _tinte
	tinte.editable = _tex != null
	v.add_child(tinte)

	var aviso_img := Label.new()
	aviso_img.add_theme_font_size_override("font_size", 11)
	aviso_img.add_theme_color_override("font_color", GRIS)
	aviso_img.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso_img.text = ("Ya tiene imagen. Ajústala con «Acercar» y arrastrando la muestra."
		if _tex != null
		else "Opcional. Se guarda dentro de la partida (encogida), así que puedes mover o borrar el "
			+ "archivo original.")
	v.add_child(aviso_img)

	# Repinta la muestra con lo que haya AHORA en los mandos.
	#
	# El RECORTE se rehace aqui, en cada toque: la muestra enseña el _png que se va a guardar, no una
	# aproximacion suya. Es un recorte de 128 px, no cuesta nada, y a cambio no existe la posibilidad
	# de que el preview y lo guardado se separen.
	var refrescar := func() -> void:
		if _src != null:
			_png = Game.png_cuadrado(_src, _zoom, _centro)
			_tex = Game.textura_de_png(_png)
		_metal = float(metal.value)
		_tinte = float(tinte.value)
		tinte.editable = _tex != null
		lbl_tinte.modulate = Color(1, 1, 1) if _tex != null else Color(1, 1, 1, 0.4)
		# material_aspecto y NO material_cuerpo: aqui _tex null significa "este todavia no tiene
		# imagen", y material_cuerpo lo interpretaria como "usa la del lider" -- que es justo lo que
		# hacia que al contratar a alguien nuevo la muestra saliera con la cara del anterior.
		muestra.material = Game.material_aspecto(_metal, _tex, _tinte)
		muestra.color = _pj.color
		zoom.editable = _src != null
		lbl_zoom.modulate = Color(1, 1, 1) if _src != null else Color(1, 1, 1, 0.4)
		_refrescar()

	metal.value_changed.connect(func(_x: float) -> void: refrescar.call())
	tinte.value_changed.connect(func(_x: float) -> void: refrescar.call())
	zoom.value_changed.connect(func(x: float) -> void:
		_zoom = x
		refrescar.call())

	# MOVER el encuadre arrastrando. El desplazamiento va en fraccion de la imagen: se divide por el
	# zoom porque cuanto mas cerca estas, menos original abarca la muestra (y el mismo gesto tiene que
	# mover menos foto, o al ampliar se iria de las manos). El signo es negativo porque arrastras la
	# IMAGEN, no la ventana: llevar el raton a la derecha trae lo de la izquierda.
	#
	# Y la muestra se queda su propio arrastre (META_ARRASTRE_PROPIO): si no, en movil el gesto se lo
	# lleva el scroll de la columna y la foto no se mueve.
	muestra.set_meta(ArrastreScroll.META_ARRASTRE_PROPIO, true)
	muestra.gui_input.connect(func(event: InputEvent) -> void:
		if _src == null:
			return
		if event is InputEventMouseMotion \
				and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
			var rel: Vector2 = (event as InputEventMouseMotion).relative / muestra.size / _zoom
			_centro = Vector2(clampf(_centro.x - rel.x, 0.0, 1.0),
				clampf(_centro.y - rel.y, 0.0, 1.0))
			refrescar.call())

	quitar.pressed.connect(func() -> void:
		_png = PackedByteArray()
		_tex = null
		_src = null
		quitar.disabled = true
		tinte.value = 0.0
		zoom.value = 1.0        # deja el encuadre listo para la siguiente imagen
		_zoom = 1.0
		_centro = Vector2(0.5, 0.5)
		aviso_img.text = "Sin imagen: se le ve la cara del color de su piel."
		refrescar.call())

	poner.pressed.connect(func() -> void:
		var fd := FileDialog.new()
		fd.access = FileDialog.ACCESS_FILESYSTEM   # el disco del jugador, no res://
		fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		fd.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp,*.bmp ; Imágenes"])
		fd.use_native_dialog = true
		fd.title = "Elige la imagen del personaje"
		_root.add_child(fd)
		# El dialogo es de usar y tirar: sin esto se irian apilando uno por cada clic en el boton.
		fd.canceled.connect(fd.queue_free)
		fd.file_selected.connect(func(ruta: String) -> void:
			fd.queue_free()
			var src: Image = Game.imagen_de_archivo(ruta)
			if src == null:
				aviso_img.text = "Esa imagen no se ha podido leer. Prueba con un PNG o un JPG."
				MenuScaffold.decir(_aviso, "Esa imagen no se ha podido leer.", false)
				return
			# Entra centrada y del todo: el recorte de partida es el cuadrado mas grande que quepa.
			_src = src
			_zoom = 1.0
			_centro = Vector2(0.5, 0.5)
			zoom.set_value_no_signal(1.0)   # sin señal: ya refrescamos abajo, no hace falta dos veces
			quitar.disabled = false
			aviso_img.text = "Imagen puesta. Ajusta el encuadre con «Acercar» y arrastrando la muestra."
			refrescar.call())
		fd.popup_centered_ratio(0.7))

	refrescar.call()


# Pasa a la vista previa lo que hay ahora. Se llama en cada toque: si solo ha cambiado un color, el
# muñeco no reconstruye nada (ver MunecoJugador.montar).
func _refrescar() -> void:
	if _pj == null:
		return
	# TU COLOR ES EL DE LA CAMISA. Se elegia aparte, en un selector propio, y desde que la ropa lleva
	# el suyo ese selector estaba eligiendo un color que no se veia en ninguna parte -- la piel no se
	# tiñe. Sigue haciendo falta (es el cuerpo de respaldo si el dibujo no carga, y el color con el
	# que te ve el compañero en su mapa), asi que se deriva en vez de preguntarse.
	var torso: Dictionary = _pj.pieza("torso")
	if String(torso["modelo"]) != "":
		_pj.color = torso["color"]
	_pj.set_imagen(_png)
	if _vista != null:
		_vista.mostrar(_pj)


# Los bytes de un PNG guardado, de vuelta a Image para poder reencuadrarlo. null si no hay imagen
# o si el PNG no se lee (una ficha con la imagen corrupta se edita igual, sin foto: que no se
# pueda tocar el aspecto seria peor que perder la imagen).
static func _imagen_de_png(png: PackedByteArray) -> Image:
	if png.is_empty():
		return null
	var img := Image.new()
	if img.load_png_from_buffer(png) != OK:
		return null
	return img
