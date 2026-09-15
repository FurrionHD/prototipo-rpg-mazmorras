# ============================================================
#  combat_montaje.gd  (tema de la pantalla de combate: combat.montaje)
#  EL MONTAJE DE LA PANTALLA, lo que se construye una vez: el fondo, la columna, las filas de tarjetas,
#  el registro, la botonera de acciones, la linea de tiempo y el boton de velocidad, y el reparto de
#  anchos cuando cambia la ventana. Lo que se usa en cada turno sigue en la pantalla.
# ============================================================
extends RefCounted

# La pantalla de la que es este tema: todo lo que no es del tema se le pide a ella. Tipada con su
# script para que Godot deduzca los tipos (los := sobre ella); los NOMBRES no los comprueba al compilar:
# de eso se encarga tools/verificar_pantalla.py.
const Pantalla = preload("res://scripts/ui/combat.gd")
var _pantalla: Pantalla = null


func _init(pantalla: Pantalla) -> void:
	_pantalla = pantalla


# La COLUMNA del combate ($VBox de la escena, a pantalla completa).
var _col: VBoxContainer = null
# Fila de los TUYOS: un bloque por miembro del grupo, con el mismo formato y el mismo ancho que
# los de enfrente. Son combatientes como los demas.
var _aliados_box: HBoxContainer = null
# ANCHO FIJO de un bloque de combatiente, tuyo o del enemigo. Es la clave del combate en grupo:
# si la barra de vida se estirase (como hacia en el 1v1, ocupando el ancho entero), cinco
# enemigos serian cinco franjas apiladas y la pelea se leeria como una lista. Con un ancho fijo
# caben los cinco EN FILA, y esa fila es la que numera la barra de accion: el nº2 de abajo es
# el 2º empezando por la izquierda. Tiene que caber el CASO PEOR: MAX_ENEMIGOS (5) bloques + sus
# separaciones dentro del viewport base (1152). 216 x 5 + 8 x 4 = 1112 < 1152: entra con un pelin
# de margen a cada lado (antes era 260, sizeado para 4, y con 5 se cortaba por los lados).
#
# Tu bloque mide LO MISMO que uno enemigo, aunque hoy este solo y le sobre sitio a los lados: es
# un combatiente como los demas, y en cuanto haya companeros seran varios repartiendose la fila.
# Que ya tenga su tamaño definitivo evita que el dia que entre el primer aliado se recoloque
# todo de golpe.
const ANCHO_BLOQUE := 216.0
# ...pero eso ya NO es el ancho de la pantalla. Las tarjetas viven en lo que queda entre la barra
# de accion y la columna de la derecha (ver _ancho_bloque), y ahi 5 x 216 no entran: la banda esta
# CENTRADA, asi que lo que sobraba se salia por los dos lados y el bicho nº1 se quedaba medio fuera
# de la pantalla. Cuando no caben a su ancho preferido se encogen a partes iguales, hasta este
# minimo (donde todavia se leen el numero y la barra de vida).
#
# Encogerlos y no partirlos en dos filas: la fila ES la numeracion que usa la barra de accion (el
# nº2 es el 2º empezando por la izquierda), y en dos filas eso deja de leerse de un vistazo.
const ANCHO_BLOQUE_MIN := 118.0
const SEP_BLOQUES := 8.0
# La pelea se lee en tres franjas verticales:
#
#   [barra de accion] [       EL ESCENARIO       ] [registro + botones]
#
# El ESCENARIO es el hueco del medio, y es lo que manda: ahi es donde van los combatientes y donde
# caen los golpes, los numeros y los efectos. Cada combatiente es una COLUMNA con su tarjeta y su
# sitio de sprite pegados, los de enfrente colgando de arriba y los tuyos apoyados abajo, asi que
# la ficha de cada uno esta siempre junto a QUIEN es y no en una fila aparte que hay que cruzar
# con la vista.
const ANCHO_COL_DER := 460.0      # la columna de la derecha: registro arriba, botones abajo
const ANCHO_TIMELINE := 88.0      # la barra de accion, de pie y pegada al lateral izquierdo
const ALTO_BANDA_ENE := _pantalla.ALTO_TARJETA_ENE + _pantalla.SEP_COLUMNA + _pantalla.ALTO_ACTOR
const ALTO_BANDA_ALI := _pantalla.ALTO_TARJETA_ALI + _pantalla.SEP_COLUMNA + _pantalla.ALTO_ACTOR
var _capa_numeros: Control = null   # donde vuelan los numeros de daño, por encima de todo


func _crear_acciones() -> void:
	# ABAJO A LA DERECHA, en la columna que comparte con el registro: el registro arriba (es lo que
	# se lee) y los botones abajo (es lo que se toca, al alcance del pulgar). El centro de la
	# pantalla se queda libre para la pelea.
	_pantalla._panel_acciones = VBoxContainer.new()
	_pantalla._panel_acciones.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_pantalla._panel_acciones.offset_left = -ANCHO_COL_DER - _pantalla.MARGEN_UI - Tactil.borde.x
	_pantalla._panel_acciones.offset_right = -_pantalla.MARGEN_UI - Tactil.borde.x
	_pantalla._panel_acciones.offset_bottom = -_pantalla.MARGEN_UI - Tactil.borde.y
	_pantalla._panel_acciones.offset_top = _pantalla._panel_acciones.offset_bottom - _pantalla.ALTO_BOTON_ACCION * _pantalla.FILAS_ACCION - 20.0
	_pantalla._panel_acciones.alignment = BoxContainer.ALIGNMENT_END
	_pantalla._panel_acciones.add_theme_constant_override("separation", 8)
	_pantalla._panel_acciones.mouse_filter = Control.MOUSE_FILTER_PASS
	_pantalla.add_child(_pantalla._panel_acciones)

	# Los seis, en rejilla de 2x3 y repartiendose el ancho.
	_pantalla._actions_box = GridContainer.new()
	(_pantalla._actions_box as GridContainer).columns = _pantalla.COLUMNAS_ACCION
	_pantalla._actions_box.add_theme_constant_override("h_separation", 10)
	_pantalla._actions_box.add_theme_constant_override("v_separation", 10)
	_pantalla._actions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pantalla._panel_acciones.add_child(_pantalla._actions_box)
	var defs := [
		[_pantalla.Action.ATTACK, "Atacar"],
		[_pantalla.Action.HABILIDAD, "Habilidad"],
		[_pantalla.Action.MAGIC, "Magia"],
		[_pantalla.Action.DEFEND, "Defender"],
		[_pantalla.Action.OBJETO, "Objeto"],
		[_pantalla.Action.FLEE, "Huir"],
	]
	for d in defs:
		var b := TooltipButton.new()   # tooltip con ancho maximo (ver tooltip_button.gd)
		b.text = d[1]
		b.custom_minimum_size = Vector2(_pantalla.ANCHO_BOTON_ACCION, _pantalla.ALTO_BOTON_ACCION)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # se reparten la franja a partes iguales
		b.add_theme_font_size_override("font_size", 18)
		var id: int = d[0]
		b.pressed.connect(_pantalla._on_action.bind(id))
		_pantalla._actions_box.add_child(b)
		_pantalla._action_buttons[id] = b
	# Cajas de magia (KAN-56): submenu de hechizos y caja del recitado/disparo.
	_pantalla._spell_box = VBoxContainer.new()
	_pantalla._panel_acciones.add_child(_pantalla._spell_box)
	_pantalla._cast_box = VBoxContainer.new()
	_pantalla._panel_acciones.add_child(_pantalla._cast_box)
	# Submenu de habilidades (KAN-57).
	_pantalla._ability_box = VBoxContainer.new()
	_pantalla._panel_acciones.add_child(_pantalla._ability_box)
	# Submenu de objetos/pociones (KAN-57).
	_pantalla._objeto_box = VBoxContainer.new()
	_pantalla._panel_acciones.add_child(_pantalla._objeto_box)

	# CONTINUAR (el del final del combate) se muda aqui abajo con los demas. Vivia arriba, pegado a
	# las barras: justo donde NO esta el pulgar despues de haber estado pulsando en esta franja toda
	# la pelea. Va el ultimo del VBox para que salga en el mismo sitio que la rejilla, que a esas
	# alturas ya esta escondida.
	_pantalla._continue_button.get_parent().remove_child(_pantalla._continue_button)
	_pantalla._panel_acciones.add_child(_pantalla._continue_button)
	_pantalla._continue_button.custom_minimum_size = Vector2(0, _pantalla.ALTO_BOTON_ACCION)
	_pantalla._continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pantalla._continue_button.add_theme_font_size_override("font_size", 20)

	_pantalla._ocultar_cajas()


func _setup_ui() -> void:
	# Una columna por enemigo, EN FILA y en el orden de _enemies -> ese orden es la numeracion que
	# se ve (el 1º empezando por la izquierda = marcador "1" en la barra de accion).
	# Ya no hace falta separador entre las dos bandas: estan en extremos opuestos de la pantalla.
	for i in _pantalla._enemies.size():
		var b: Dictionary = _pantalla.figuras._crear_bloque(_pantalla._enemies[i], i + 1, i)
		_pantalla._bloques.append(b)
		_pantalla._bloques_box.add_child(b["columna"])
	# LOS TUYOS: una columna por miembro del grupo, construidas igual que las de enfrente (numero
	# 0 = sin numerar y sin clic: a los tuyos no hace falta apuntarles). Cada uno lleva sus tres
	# barras (vida, energia y maná), porque cada uno gasta las suyas.
	for i in _pantalla._aliados.size():
		_pantalla.altas._anadir_bloque_aliado(_pantalla._aliados[i])
	_pantalla.figuras._seleccionar(0)
	# Ya estan todos: ahora se sabe cual es el mas grande y se puede repartir el tamaño.
	_pantalla.figuras._ajustar_zoom_sprites()
	_pantalla._update_hp()
	_pantalla._continue_button.visible = false
	_pantalla._ocultar_cajas()


func _crear_timeline() -> void:
	_pantalla._timeline = preload("res://scripts/ui/turn_timeline.gd").new()
	# DE PIE y pegada al lateral izquierdo, de arriba abajo entera: los turnos suben hacia el punto
	# de accion. Tumbada abajo se comia una franja del ancho de la pantalla que ahora es del
	# escenario, y ahi es donde tienen que caber los combatientes.
	_pantalla._timeline.vertical = true
	_pantalla._timeline.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_pantalla._timeline.offset_left = Tactil.borde.x
	_pantalla._timeline.offset_right = Tactil.borde.x + ANCHO_TIMELINE
	_pantalla._timeline.offset_top = Tactil.borde.y
	_pantalla._timeline.offset_bottom = -Tactil.borde.y
	# Solo dibuja -> IGNORE (que no robe clics a lo que quede por encima).
	_pantalla._timeline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pantalla.add_child(_pantalla._timeline)
	# Un marcador por cada uno de los tuyos, con el aspecto de SU cubo: el mismo color, la misma
	# imagen y el mismo metal que en el mapa (material_de() puede devolver null, y es correcto: un
	# cuerpo mate sin imagen se pinta solo con su color). Sin texto: se reconocen por la pinta,
	# que es la misma con la que los llevas por la mazmorra.
	for c in _pantalla._aliados:
		_pantalla._timeline.anadir(c, _pantalla._color_de(c), _pantalla._material_de(c), "")
	# Cada enemigo con su color del mapa y su NUMERO, el mismo que lleva su bloque arriba.
	for i in _pantalla._enemies.size():
		_pantalla._timeline.anadir(_pantalla._enemies[i], _pantalla._enemies[i].color_visual, null, str(i + 1))


# EL BOTON DE VELOCIDAD, arriba a la derecha. Un triangulo de "play" para x1 y DOS solapados (el
# avance rapido de toda la vida) para x2. Se dibuja a mano en vez de poner texto porque es un icono
# que todo el mundo reconoce sin leerlo.
#
# En la pelea de OTRO sale apagado: la velocidad la manda su dueño (ver _vel_pelea).
func _crear_boton_velocidad() -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(48, 28)
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = _pantalla._espejo
	b.tooltip_text = ("La velocidad la marca quien lleva esta pelea" if _pantalla._espejo
		else "Velocidad del combate: toda la pelea, barra de acción incluida")
	# El dibujo va en un hijo que solo pinta: asi el Button conserva su hover y su pulsacion.
	var icono := Control.new()
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icono.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icono.draw.connect(func() -> void: _pintar_icono_velocidad(icono))
	b.add_child(icono)
	b.pressed.connect(func() -> void:
		# Solo el dueño: x1 <-> x2 y se recuerda para las proximas peleas.
		Game.velocidad_combate = 2.0 if Game.velocidad_combate < 1.5 else 1.0
		_pantalla._aplicar_velocidad(Game.velocidad_combate)
		icono.queue_redraw()
		# Que le llegue YA al compañero, sin esperar al proximo cambio de vida.
		_pantalla.espejo._difundir())
	# Al lado del boton del registro, arriba de la columna derecha. Suelto en la esquina se
	# quedaba ENCIMA del registro, que ahora vive justo ahi.
	if _log_fila != null and is_instance_valid(_log_fila):
		_log_fila.add_child(b)
	else:
		_pantalla.add_child(b)
	_pantalla._boton_vel = icono


func _pintar_icono_velocidad(c: Control) -> void:
	var col := Color(0.85, 0.87, 0.95, 0.45 if _pantalla._espejo else 1.0)
	var alto: float = 16.0
	var ancho: float = 13.0
	var cy: float = c.size.y * 0.5
	# A x1 un solo triangulo centrado; a x2 dos SOLAPADOS un poco, que es como se lee "mas rapido".
	var doble: bool = _pantalla._vel_pelea >= 1.5
	var cx: float = c.size.x * 0.5 - (ancho * 0.42 if doble else 0.0)
	for i in (2 if doble else 1):
		var x: float = cx + float(i) * ancho * 0.84
		c.draw_colored_polygon(PackedVector2Array([
			Vector2(x - ancho * 0.5, cy - alto * 0.5),
			Vector2(x + ancho * 0.5, cy),
			Vector2(x - ancho * 0.5, cy + alto * 0.5),
		]), col)


# Crea un fondo opaco a pantalla completa, por DETRAS de la interfaz.
func _anadir_fondo() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.13, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE  # que no robe los clics al boton
	_pantalla.add_child(bg)
	_pantalla.move_child(bg, 0)  # al fondo (los hermanos siguientes se dibujan encima)


# Prepara las dos BANDAS de combatientes: los de enfrente colgando del techo, los tuyos apoyados
# en el suelo, y el escenario entre medias.
#
# Ya NO hay una columna que lo envuelva todo. El $VBox de la escena existia para apilar
# enemigos-separador-aliados cuando las dos filas iban seguidas; ahora estan en extremos opuestos
# de la pantalla y un contenedor de por medio solo estorbaria (y su offset_right, calculado a
# mano, era justo lo que habia que dejar de hacer). Se queda vacio y sin pintar.
func _montar_columna() -> void:
	_col = _pantalla.get_node("VBox")
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.visible = false

	# ELLOS ARRIBA. Cada hijo es la COLUMNA de un enemigo (tarjeta + su sitio de sprite debajo),
	# ver _crear_bloque. Centradas: con uno o dos, la banda queda en medio de la pantalla en vez
	# de pegada a la izquierda con un hueco raro al lado.
	_pantalla._bloques_box = _crear_fila_bloques(true)
	# LOS TUYOS ABAJO, en espejo: su sprite arriba y la tarjeta apoyada en el suelo.
	_aliados_box = _crear_fila_bloques(false)

	_montar_log()

	# LOS NUMEROS DE DAÑO van en su propia capa, por encima de todo (se añade la ULTIMA). No pueden
	# colgar de la tarjeta: la zona de chips va con clip_contents y el numero tiene que poder
	# salirse de la caja hacia arriba, que es justo lo que hace.
	#
	# "AÑADIRSE LA ULTIMA" YA NO BASTA desde que el jugador es un MunecoJugador: sus capas llevan
	# z_index ABSOLUTO (heredado del mapa, donde compiten con otros cuerpos a distinta profundidad;
	# ver la cabecera de muneco_jugador.gd) y llegan hasta ~2560 (el arma forzada delante en
	# golpe_2m). El orden por arbol solo desempata entre nodos del MISMO z_index -- con esta capa a
	# 0 y el muñeco por encima de 2000, un golpe que te encajaban salia dibujado DETRAS de tu propio
	# personaje: se veia el destello y el numero tapados por tu cuerpo. Con z_index bien por encima
	# de lo maximo que hornea el muñeco (y lejos del tope de Godot, +-4096) los ataques y los
	# numeros vuelven a verse SIEMPRE, sea cual sea el z que traiga la capa que dibuje debajo.
	_capa_numeros = Control.new()
	_capa_numeros.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_capa_numeros.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa_numeros.clip_contents = false
	_capa_numeros.process_mode = Node.PROCESS_MODE_ALWAYS
	_capa_numeros.z_index = 4000
	_pantalla.add_child(_capa_numeros)
	if _pantalla._fx != null:
		_pantalla._fx.capa_numeros = _capa_numeros


# Una de las dos bandas de combatientes, anclada al techo o al suelo y ocupando lo que queda entre
# la barra de accion y la columna de la derecha.
func _crear_fila_bloques(arriba: bool) -> HBoxContainer:
	var banda := HBoxContainer.new()
	banda.add_theme_constant_override("separation", SEP_BLOQUES)
	banda.alignment = BoxContainer.ALIGNMENT_CENTER
	banda.mouse_filter = Control.MOUSE_FILTER_PASS
	# Cada banda se ancla a SU borde y con una ALTURA FIJA (ver ALTO_BANDA_*). Nada de dejar que la
	# marque el contenido: un Container anclado por un solo lado se queda a altura cero, y asi la
	# banda de abajo se salia entera de la pantalla sin dar el menor error.
	banda.set_anchors_preset(Control.PRESET_TOP_WIDE if arriba else Control.PRESET_BOTTOM_WIDE)
	banda.offset_left = ANCHO_TIMELINE + _pantalla.MARGEN_UI + Tactil.borde.x
	banda.offset_right = -ANCHO_COL_DER - _pantalla.MARGEN_UI * 2.0 - Tactil.borde.x
	if arriba:
		banda.offset_top = _pantalla.MARGEN_UI + Tactil.borde.y
		banda.offset_bottom = banda.offset_top + ALTO_BANDA_ENE
	else:
		banda.offset_bottom = -_pantalla.MARGEN_UI - Tactil.borde.y
		banda.offset_top = banda.offset_bottom - ALTO_BANDA_ALI
	_pantalla.add_child(banda)
	return banda


# EL REGISTRO, arriba de la columna derecha y SIEMPRE a la vista.
#
# Antes era un Label pegado al suelo de su caja, creciendo hacia arriba y recortado por el techo
# con clip_contents: lo viejo no se ocultaba, se PERDIA. Se hacia asi porque un Label con autowrap
# calcula su alto a partir de su ancho, y con los anclajes de abajo el ancho no estaba resuelto
# cuando Godot pedia la altura (salia un alto absurdo, medido: 22907 px con ocho frases).
#
# Un ScrollContainer resuelve eso de raiz -es el quien mide y el quien recorta- y ademas trae lo
# que faltaba: poder VOLVER atras y leer lo que se fue. Se ve a ALTO_LOG_LINEAS de alto, con el
# boton de al lado para estirarlo cuando quieres leer la pelea entera.
const ALTO_LINEA_LOG := 24.0    # lo que ocupa una linea a tamaño 18
const LOG_LINEAS := 6           # las que se ven de un vistazo, sin estirar
var _log_caja: PanelContainer = null
var _log_scroll: ScrollContainer = null
var _log_fila: HBoxContainer = null
var _log_boton: Button = null
var _log_abierto: bool = false


func _montar_log() -> void:
	_log_caja = PanelContainer.new()
	_log_caja.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_log_caja.offset_left = -ANCHO_COL_DER - _pantalla.MARGEN_UI - Tactil.borde.x
	_log_caja.offset_right = -_pantalla.MARGEN_UI - Tactil.borde.x
	_log_caja.offset_top = _pantalla.MARGEN_UI + Tactil.borde.y
	# FONDO OPACO: el registro ya no vive sobre el negro del fondo, se superpone al escenario.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.11, 0.92)
	sb.set_corner_radius_all(4)
	for lado in ["left", "right", "top", "bottom"]:
		sb.set("content_margin_" + lado, 8.0)
	_log_caja.add_theme_stylebox_override("panel", sb)
	_pantalla.add_child(_log_caja)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_log_caja.add_child(vb)

	# La fila de arriba: el boton de estirar y, a su lado, el de velocidad (lo mete despues
	# _crear_boton_velocidad). Los dos son comodidades, no acciones de la pelea, asi que van
	# pequeños y juntos en vez de competir en tamaño con los seis botones de abajo.
	_log_fila = HBoxContainer.new()
	_log_fila.add_theme_constant_override("separation", 6)
	vb.add_child(_log_fila)

	_log_boton = Button.new()
	_log_boton.text = "📜 Registro  ▼"
	_log_boton.custom_minimum_size = Vector2(0, 28)
	_log_boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_boton.add_theme_font_size_override("font_size", 14)
	_log_boton.focus_mode = Control.FOCUS_NONE   # o se queda con el foco y el teclado deja de ir al combate
	_log_boton.pressed.connect(_pantalla._alternar_log)
	_log_fila.add_child(_log_boton)

	# BOTON "i": abre la ficha de detalle en el primer personaje de tu formacion. Comodidad, como
	# el de velocidad, asi que va aqui y pequeño. Solo activo en tu turno (_refresh_actions lo
	# vuelve a evaluar); el mantener pulsado sobre un combatiente hace lo mismo pero directo a el.
	_pantalla._boton_detalle = Button.new()
	_pantalla._boton_detalle.text = "ⓘ"
	_pantalla._boton_detalle.custom_minimum_size = Vector2(34, 28)
	_pantalla._boton_detalle.flat = true
	_pantalla._boton_detalle.focus_mode = Control.FOCUS_NONE
	_pantalla._boton_detalle.tooltip_text = "Detalles de los combatientes (en tu turno)"
	_pantalla._boton_detalle.pressed.connect(_pantalla.figuras._abrir_detalle.bind(null))
	_log_fila.add_child(_pantalla._boton_detalle)

	_log_scroll = ScrollContainer.new()
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log_scroll.custom_minimum_size = Vector2(0, ALTO_LINEA_LOG * float(LOG_LINEAS))
	vb.add_child(_log_scroll)

	_pantalla._log.get_parent().remove_child(_pantalla._log)
	_log_scroll.add_child(_pantalla._log)
	# El texto ocupa el ancho del scroll y crece hacia abajo lo que haga falta: de medirlo se
	# encarga el ScrollContainer, que para eso esta. Es un RichTextLabel (ver combat._set_log) con
	# fit_content para que mida su alto y SIN su propio scroll: el scroll es el del contenedor.
	_pantalla._log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pantalla._log.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_pantalla._log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pantalla._log.fit_content = true
	_pantalla._log.scroll_active = false
	_pantalla._log.bbcode_enabled = false
	_pantalla._log.add_theme_font_size_override("normal_font_size", 18)
	_pantalla._log.mouse_filter = Control.MOUSE_FILTER_IGNORE


# Lo que ocupa la zona de botones de abajo, para no meterse debajo de ella al estirar el registro.
func _alto_zona_botones() -> float:
	if _pantalla._panel_acciones == null:
		return _pantalla.ALTO_BOTON_ACCION * _pantalla.FILAS_ACCION
	return _pantalla._panel_acciones.size.y


# Lo que mide cada tarjeta cuando hay 'n' en su banda. A su ancho preferido mientras quepan, y
# encogiendose a partes iguales cuando no. El sitio disponible es el mismo que el de las bandas
# (ver _crear_fila_bloques): la pantalla menos la barra de accion, la columna derecha y los margenes.
func _ancho_bloque(n: int) -> float:
	if n <= 1:
		return ANCHO_BLOQUE
	var disponible: float = _pantalla.get_viewport_rect().size.x - ANCHO_COL_DER - ANCHO_TIMELINE \
		- _pantalla.MARGEN_UI * 3.0 - Tactil.borde.x * 2.0
	return clampf((disponible - SEP_BLOQUES * float(n - 1)) / float(n),
		ANCHO_BLOQUE_MIN, ANCHO_BLOQUE)


# Reajusta el ancho de las tarjetas de una banda. Hace falta porque la banda CRECE a mitad de
# pelea: entran refuerzos, se une el compañero... y lo que cabia con tres deja de caber con cinco.
func _reajustar_anchos(bloques: Array, n: int) -> void:
	var ancho: float = _ancho_bloque(n)
	for b in bloques:
		# El ancho lo lleva el ENVOLTORIO, que es el que esta dentro de la columna; el panel se
		# limita a copiarle el tamaño (ver _crear_bloque).
		var wrap: Control = b.get("wrap")
		if wrap != null and is_instance_valid(wrap):
			wrap.custom_minimum_size.x = ancho
