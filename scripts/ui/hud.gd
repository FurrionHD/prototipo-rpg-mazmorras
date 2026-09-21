# ============================================================
#  hud.gd  (CanvasLayer creada por codigo desde el jugador)
#  HUD de exploracion (siempre visible):
#   - Cuadrado de PESO a la derecha de las barras (placeholder de la bolsa/mochila),
#     con el numero encima y color gris -> amarillo -> rojo segun la carga.
#   - Linea de ayudas de tecla bajo las barras (en el movil no: alli no hay teclas).
#   - Con los dedos, la BOTONERA de la esquina superior derecha (personaje, bolsa, mapa, pausa).
#  El PISO y el DINERO ya no se pintan aqui: el piso se lee en el titulo del mapa (que se abre
#  siempre por el piso en el que estas) y el dinero, arriba en la bolsa. Tenerlos ademas clavados
#  en pantalla era repetir dos numeros que ya viven en su sitio.
#  El INVENTARIO vive ahora en inventory_menu.gd (tecla I) y las stats en
#  character_menu.gd (tecla C). Las barras de vida/energia/mana las pinta player.gd.
# ============================================================

extends CanvasLayer
# Con nombre de clase para que las medidas de la botonera (ICONO_LADO, ICONO_MARGEN) se puedan leer
# desde fuera: el panel de debug se abre justo debajo de ella y tiene que cuadrar con la fila.
class_name Hud

var _counts: Label = null
var _peso_box: CuadroCarga = null # la mochila (deposito con agua) a la derecha de las barras
var _peso_lbl: Label = null       # numero de peso encima del deposito
# El FAROLILLO, a la derecha de la mochila: la llama que se consume, y al lado "xN" (trozos) y la
# luz total que te queda. Ver cuadro_farol.gd.
var _farol_box: CuadroFarol = null
var _farol_lbl: Label = null       # "xN" y la luz restante, a la derecha del cuadro
# Lo que ocupa ese texto a lo ancho. Es una ESTIMACION generosa, no una medida: se necesita en
# player.escala_fila ANTES de que la etiqueta tenga texto (y la fuente no esta cargada todavia al
# arrancar). Pasarse un poco solo encoge la fila un pelin de mas; quedarse corto la deja solapada,
# que es lo que no vale.
const ANCHO_TEXTO_FAROL := 62.0
# El deposito es CUADRADO, y su lado NO se escribe aqui: se lo pide a player.ALTO_EQUIPO, que es el
# alto de los cuadros de equipo (del nombre al fondo de la barra de mana). Asi la mochila y los
# cuadros comparten LA MISMA linea de abajo por construccion, y no por que alguien haya cuadrado dos
# numeros a mano que mañana se separan. Esta constante es solo el respaldo de por si no hay jugador.
const LADO_MOCHILA := 64.0
const ALTO_MOCHILA := LADO_MOCHILA
# Hueco entre la mochila y el farolillo. Pequeño a proposito: son dos cuadros de la misma fila, no
# dos elementos sueltos del HUD.
const SEPARACION_FAROL := 6.0
# La caja de ayudas de teclas. Va debajo de las barras y no se mueve, pero se guarda por si algun
# dia hay que recolocarla como al cuadrado del peso.
var _caja_ayudas: PanelContainer = null
# Feed de RECOGIDA: la columna de pildoras a la izquierda ("Nombre ×N") estilo gacha. Cada aviso
# aparece unos segundos y se desvanece solo; se apilan varios y se limita el numero a la vista.
var _recogidas: VBoxContainer = null
const RECOGIDAS_MAX := 5
# Avisos de ESQUINA: la columna discreta de abajo a la derecha ("Guardando...", "Partida guardada").
# No son noticias, son acuses de recibo: no deben robarte la vista en mitad de la pantalla.
var _avisos_esquina: VBoxContainer = null
const AVISOS_ESQUINA_MAX := 3
# TOASTS: la columna de noticias en grande, arriba en el centro. Antes cada uno era un Label suelto
# con el mismo offset_top clavado, asi que dos avisos seguidos se pintaban UNO ENCIMA DEL OTRO y no
# se leia ninguno (la pesca suelta varios en cadena y ahi se veia clarisimo). Con contenedor se
# apilan solos, como sus dos hermanos de este mismo archivo.
var _toasts: VBoxContainer = null
const TOASTS_MAX := 3


func _ready() -> void:
	layer = 5  # por encima de la mazmorra, por debajo del combate (100)
	add_to_group("hud")   # para que Game le pida toasts (pasivas RNG, etc.)

	# Un HUD recien creado SIEMPRE arranca sin menus. Reiniciamos el estado global por si veniamos
	# de una escena con uno abierto (p.ej. pulsar R para recargar teniendolo abierto): si no, el
	# jugador nuevo se quedaria congelado creyendo que el menu sigue abierto. Ahora ademas hay que
	# DESPAUSAR el arbol, o la escena nueva nace muerta; cerrar_menu respeta el combate en curso.
	Game.cerrar_menu()

	# Ayudas de tecla, debajo de las barras de aguante/vida/mana del jugador. En DOS filas (en
	# una sola ya no cabian) y dentro de un panel negro semitransparente: el texto blanco sobre
	# una pared clara no habia quien lo leyera.
	_caja_ayudas = PanelContainer.new()
	var caja := _caja_ayudas
	caja.add_theme_stylebox_override("panel", _fondo_negro())
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# En el movil no hay teclas que recordar, y esa caja se come una esquina de pantalla que ahi
	# vale mucho mas (ver touch_controls.gd).
	caja.visible = not Tactil.activo
	add_child(caja)

	_counts = Label.new()
	_counts.add_theme_font_size_override("font_size", 12)
	_counts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(_counts)

	# La esquina superior derecha es AHORA la botonera, y solo eso. El "Piso: N" y las monedas que
	# vivian aqui se han ido: los dos numeros ya estan donde toca mirarlos —el piso, en el titulo del
	# mapa (que ademas se abre siempre por el piso en el que estas); el dinero, arriba en la bolsa—,
	# y tenerlos ademas pegados en pantalla era repetirlos por repetirlos.
	_montar_botonera()

	# LA MOCHILA, a la derecha de las barras: un deposito que se llena de abajo arriba con el agua
	# meciendose, y el numero encima. Era un cuadrado plano que solo cambiaba de color, o sea que
	# decia "vas cargado" pero no cuanto. Ver cuadro_carga.gd.
	_peso_box = CuadroCarga.new()
	_peso_box.position = Vector2(200, 16)
	_peso_box.size = Vector2(LADO_MOCHILA, ALTO_MOCHILA)
	add_child(_peso_box)

	_peso_lbl = Label.new()
	_peso_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_peso_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# ARRIBA y no centrado: el agua sube desde abajo, y un numero en mitad del vaso acaba tapado por
	# ella justo cuando mas importa (cargado hasta arriba).
	_peso_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_peso_lbl.add_theme_font_size_override("font_size", 13)
	_peso_lbl.add_theme_color_override("font_color", Color.WHITE)
	_peso_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_peso_lbl.add_theme_constant_override("outline_size", 4)
	_peso_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_peso_box.add_child(_peso_lbl)

	# EL FAROLILLO, al lado de la mochila: la llama que se apaga, y a su derecha cuantos carbones
	# llevas y cuanta luz te queda EN TOTAL. Antes eso solo se sabia abriendo el inventario, y encima
	# en dos numeros separados que tenias que sumar tu. Ver cuadro_farol.gd.
	_farol_box = CuadroFarol.new()
	_farol_box.position = Vector2(270, 16)
	_farol_box.size = Vector2(LADO_MOCHILA, ALTO_MOCHILA)
	add_child(_farol_box)

	# Los dos numeros van A LA DERECHA del cuadro: los trozos arriba y la luz que queda debajo. Dentro
	# del cuadro se probo y no vale -- en 64 px las dos lineas se comen el farol y la llama, que es
	# justo lo que hay que ver de un vistazo, se queda en nada.
	#
	# Lo que ocupan SE CUENTA en player.escala_fila (ANCHO_TEXTO_FAROL): esa cuenta es la que decide
	# cuanto encoge la fila del grupo, y como no los contaba, el farol y su texto se salian por la
	# derecha y se metian debajo de la botonera.
	_farol_lbl = Label.new()
	_farol_lbl.add_theme_font_size_override("font_size", 13)
	_farol_lbl.add_theme_color_override("font_color", Color.WHITE)
	_farol_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_farol_lbl.add_theme_constant_override("outline_size", 4)
	_farol_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_farol_lbl)

	# Feed de recogida, anclado a la izquierda a media altura (crece hacia abajo desde el centro).
	_recogidas = VBoxContainer.new()
	_recogidas.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_recogidas.offset_left = 16
	_recogidas.add_theme_constant_override("separation", 6)
	_recogidas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_recogidas)

	# Avisos de esquina, abajo a la DERECHA (creciendo hacia arriba). La otra esquina de abajo no
	# vale: ahi cae la caja de ayudas de tecla, cuya altura se mueve con ALTO_BLOQUE del jugador.
	_avisos_esquina = VBoxContainer.new()
	_avisos_esquina.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_avisos_esquina.offset_right = -16
	_avisos_esquina.offset_bottom = -16
	_avisos_esquina.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_avisos_esquina.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_avisos_esquina.alignment = BoxContainer.ALIGNMENT_END
	_avisos_esquina.add_theme_constant_override("separation", 4)
	_avisos_esquina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_avisos_esquina)

	# Toasts, arriba en el centro y creciendo hacia abajo. El 130 es el sitio de siempre; por encima
	# (en el 90) esta el aviso de muerte, asi que la columna NO puede subir.
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toasts.offset_top = 130
	_toasts.offset_left = -420
	_toasts.offset_right = 420
	_toasts.add_theme_constant_override("separation", 6)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)

	_montar_boton_interaccion()

	recolocar()
	_avisar_muerte()


# ============================================================
#  EL BOTON FLOTANTE DE INTERACTUAR: al lado del personaje, dice QUE hace la F con lo que tienes a
#  mano ("[F] Entrar en la tienda", "[F] Talar", "[F] Recoger Jabalí"), y se puede pulsar con el raton
#  o el dedo. Lo pidio el usuario (con una captura de otro juego de referencia). Sustituye a los "[F]"
#  sueltos que flotaban encima de cada veta, escalera y estanque.
#
#  Lo que se enseña lo decide el JUGADOR (player.objetivo_interaccion + texto_interaccion), que es
#  tambien quien resuelve la F: asi el boton no puede decir una cosa y la tecla hacer otra.
#
#  Se refresca desde process_frame y no desde _process: los menus y los minijuegos PAUSAN el arbol (ver
#  Game.abrir_menu), el _process del HUD se para con ellos y el boton se quedaba clavado encima del menu.
# ============================================================
const INTERACCION_DESPLAZ := Vector2(34.0, -46.0)   # desde el origen del personaje en pantalla
const INTER_ALTO := 30.0                              # alto de la tecla y de la pastilla
var _inter: HBoxContainer = null        # la fila entera: [F] + pastilla
var _inter_tecla: PanelContainer = null
var _inter_pastilla: PanelContainer = null
var _inter_icono: Control = null
var _inter_texto: Label = null
var _inter_icono_nombre: String = ""
var _inter_sb: StyleBoxFlat = null
var _inter_sb_hover: StyleBoxFlat = null


# Como el de la captura de referencia: la TECLA en su cuadrito aparte a la izquierda y, al lado, la
# PASTILLA con el icono de lo que vas a hacer (el pico, el hacha, la mano...) y el texto. La pastilla
# lleva el MISMO margen a los dos lados: la primera version tenia 5 px a la izquierda y 14 a la
# derecha, y con la tecla escondida quedaba un hueco vacio delante del texto (lo vio el usuario).
func _montar_boton_interaccion() -> void:
	_inter = HBoxContainer.new()
	_inter.add_theme_constant_override("separation", 6)
	_inter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inter.visible = false
	add_child(_inter)

	# LA TECLA. Con los dedos no hay tecla que enseñar: la pastilla ya es el boton.
	_inter_tecla = PanelContainer.new()
	var sb_t := StyleBoxFlat.new()
	sb_t.bg_color = Color(0.06, 0.07, 0.10, 0.88)
	sb_t.border_color = Color(0.92, 0.90, 0.84, 0.9)
	sb_t.set_border_width_all(1)
	sb_t.set_corner_radius_all(6)
	_inter_tecla.add_theme_stylebox_override("panel", sb_t)
	_inter_tecla.custom_minimum_size = Vector2(INTER_ALTO, INTER_ALTO)
	_inter_tecla.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_inter_tecla.visible = not Tactil.activo
	var tecla := Label.new()
	tecla.text = "F"
	tecla.add_theme_font_size_override("font_size", 14)
	tecla.add_theme_color_override("font_color", Color(0.96, 0.95, 0.92))
	tecla.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tecla.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tecla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inter_tecla.add_child(tecla)
	_inter.add_child(_inter_tecla)

	# LA PASTILLA.
	_inter_pastilla = PanelContainer.new()
	_inter_sb = StyleBoxFlat.new()
	_inter_sb.bg_color = Color(0.06, 0.07, 0.10, 0.82)
	_inter_sb.border_color = Color(0.95, 0.72, 0.36, 0.45)
	_inter_sb.set_border_width_all(1)
	_inter_sb.set_corner_radius_all(int(INTER_ALTO * 0.5))
	for lado in ["left", "right"]:
		_inter_sb.set("content_margin_" + lado, 12.0)
	for lado in ["top", "bottom"]:
		_inter_sb.set("content_margin_" + lado, 3.0)
	_inter_sb_hover = _inter_sb.duplicate() as StyleBoxFlat
	_inter_sb_hover.bg_color = Color(0.14, 0.15, 0.20, 0.92)
	_inter_sb_hover.border_color = Color(0.95, 0.72, 0.36, 0.95)
	_inter_pastilla.add_theme_stylebox_override("panel", _inter_sb)
	_inter_pastilla.custom_minimum_size = Vector2(0, INTER_ALTO)
	_inter_pastilla.mouse_filter = Control.MOUSE_FILTER_STOP
	_inter_pastilla.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_inter_pastilla.gui_input.connect(_on_inter_input)
	_inter_pastilla.mouse_entered.connect(func() -> void:
		_inter_pastilla.add_theme_stylebox_override("panel", _inter_sb_hover))
	_inter_pastilla.mouse_exited.connect(func() -> void:
		_inter_pastilla.add_theme_stylebox_override("panel", _inter_sb))
	_inter.add_child(_inter_pastilla)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 7)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inter_pastilla.add_child(fila)

	_inter_icono = Control.new()
	_inter_icono.custom_minimum_size = Vector2(18, 18)
	_inter_icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_inter_icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inter_icono.draw.connect(func() -> void:
		if _inter_icono_nombre != "":
			Callable(Iconos, _inter_icono_nombre).call(_inter_icono, Vector2.ZERO, 18.0, Color(0.96, 0.95, 0.92)))
	fila.add_child(_inter_icono)

	_inter_texto = Label.new()
	_inter_texto.add_theme_font_size_override("font_size", 15)
	_inter_texto.add_theme_color_override("font_color", Color(0.96, 0.95, 0.92))
	_inter_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_inter_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(_inter_texto)

	get_tree().process_frame.connect(_refrescar_interaccion)


func _refrescar_interaccion() -> void:
	# La señal es del arbol, no del HUD: al cambiar de escena sigue llamando con el HUD ya fuera.
	if _inter == null or not is_inside_tree():
		return
	var jugador: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var objetivo: Node = null
	# Nada que enseñar con un menu, un minijuego o una pelea delante (todos pausan el arbol o abren capa).
	if jugador != null and jugador.has_method("objetivo_interaccion") and not get_tree().paused 			and Game._active_layer == null and not Game.combate_activo():
		objetivo = jugador.objetivo_interaccion()
	if objetivo == null:
		_inter.visible = false
		return
	var texto: String = jugador.texto_interaccion(objetivo)
	var icono: String = jugador.icono_interaccion(objetivo)
	if _inter_texto.text != texto or _inter_icono_nombre != icono:
		_inter_texto.text = texto
		_inter_icono_nombre = icono
		_inter_icono.queue_redraw()
		_inter.reset_size()   # que encoja con un texto mas corto: el contenedor solo crece solo
	_inter.position = (jugador.get_global_transform_with_canvas().origin + INTERACCION_DESPLAZ).round()
	_inter.visible = true


func _on_inter_input(ev: InputEvent) -> void:
	var pulsado: bool = (ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT 		and not ev.pressed) or (ev is InputEventScreenTouch and not ev.pressed)
	if not pulsado:
		return
	_inter_pastilla.accept_event()
	var jugador: Node = get_tree().get_first_node_in_group("player")
	if jugador != null and jugador.has_method("_try_interact"):
		jugador._try_interact()


# Aparta el cuadrado del PESO para dejar sitio a las columnas de barras del grupo: la tuya y una
# por companero (las pinta player.gd, ver alli x_columna). Con esto la mochila queda SIEMPRE justo
# detras de la ultima columna, contrates a quien contrates.
#
# Las medidas se leen de player.gd para no tener el layout escrito en dos sitios y que se separen
# el dia que una columna cambie de ancho.
func recolocar() -> void:
	var jugador: Node = get_tree().get_first_node_in_group("player")
	# La fila del grupo se ENCOGE cuando no cabe (ver player.escala_fila): la mochila va detras de
	# la ultima columna, asi que tiene que encogerse y moverse con ellas o se despegaria de la fila.
	var f: float = 1.0
	if jugador != null and jugador.has_method("escala_fila"):
		f = jugador.escala_fila()
	if _peso_box != null:
		var x: float = 200.0   # sin jugador (no deberia pasar): donde estaba de siempre
		var y0: float = 16.0
		var lado: float = LADO_MOCHILA
		if jugador != null:
			x = jugador.x_columna(Game.party.size()) + 4.0
			# ARRIBA en la linea del nombre y ABAJO en la de las barras, el mismo alto que los
			# cuadros de equipo: los dos salen de player.ALTO_EQUIPO, asi que no pueden descuadrarse.
			y0 = jugador.Y_NOMBRE + Tactil.borde.y
			lado = jugador.ALTO_EQUIPO
		_peso_box.scale = Vector2(f, f)
		_peso_box.size = Vector2(lado, lado)   # cuadrada
		_peso_box.position = Vector2(x * f, y0 * f)
		# El farol va PEGADO a la mochila, con el mismo alto y la misma escala: los dos indicadores
		# son pareja y tienen que leerse como una sola fila.
		if _farol_box != null:
			var xf: float = x + lado + SEPARACION_FAROL
			_farol_box.scale = Vector2(f, f)
			_farol_box.size = Vector2(lado, lado)
			_farol_box.position = Vector2(xf * f, y0 * f)
			if _farol_lbl != null:
				_farol_lbl.scale = Vector2(f, f)
				_farol_lbl.position = Vector2((xf + lado + 5.0) * f, (y0 + lado * 0.14) * f)
	# Y la caja de ayudas, justo debajo del bloque de barras. Va aqui y no con una y fija porque
	# el bloque crecio al meterle el nombre encima: con la 64 de antes se solapaban.
	if _caja_ayudas != null:
		var y: float = 64.0
		if jugador != null:
			y = float(jugador.ALTO_BLOQUE) * f + 6.0
		_caja_ayudas.position = Vector2(8, y)


# Si vienes de MORIR, el aviso se enseña AQUI (ya en el pueblo) y no en la pantalla de
# combate: alli el jugador acaba de pulsar "Continuar" para largarse y no lo leeria.
func _avisar_muerte() -> void:
	if Game.mensaje_muerte == "":
		return
	var aviso := Label.new()
	aviso.text = Game.mensaje_muerte
	Game.mensaje_muerte = ""   # ya avisado: que no vuelva a saltar al cambiar de escena
	aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	aviso.offset_top = 90
	aviso.offset_left = -420
	aviso.offset_right = 420
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.add_theme_font_size_override("font_size", 18)
	aviso.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	aviso.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	aviso.add_theme_constant_override("outline_size", 5)
	add_child(aviso)

	# Se queda un rato y se desvanece: no es un menu, es una noticia.
	var t := create_tween()
	t.tween_interval(6.0)
	t.tween_property(aviso, "modulate:a", 0.0, 1.5)
	t.tween_callback(aviso.queue_free)


# TOAST no bloqueante (el juego NO se para): un cartel dorado que aparece arriba y se desvanece.
# Lo usa Game para avisar de cosas raras (una pasiva RNG que acabas de conseguir). Se le puede
# llamar desde cualquier parte via el grupo "hud".
#
# SE APILAN: cuelgan de _toasts (un VBox), asi que el segundo cae DEBAJO del primero en vez de
# encima. Mismas tres reglas que mostrar_aviso_esquina, y por los mismos motivos:
#   - dedupe: repetir el mismo texto reinicia la cuenta, no apila dos carteles iguales;
#   - tope TOASTS_MAX, tirando el mas viejo;
#   - el tween se crea DESDE EL CARTEL y este se marca ALWAYS. El HUD es PAUSABLE y todos los menus
#     de este proyecto paran el arbol: un tween creado con create_tween() del HUD se congela con
#     cualquier menu abierto y el cartel se queda clavado en pantalla.
func mostrar_toast(texto: String) -> void:
	if _toasts == null:
		return

	for hijo in _toasts.get_children():
		if hijo.has_meta("texto") and String(hijo.get_meta("texto")) == texto:
			(hijo as Control).modulate.a = 1.0
			_temporizar_toast(hijo as Control)
			return

	while _toasts.get_child_count() >= TOASTS_MAX:
		var viejo := _toasts.get_child(0)
		_toasts.remove_child(viejo)
		viejo.queue_free()

	var aviso := Label.new()
	aviso.text = texto
	aviso.set_meta("texto", texto)
	aviso.process_mode = Node.PROCESS_MODE_ALWAYS
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aviso.add_theme_font_size_override("font_size", 18)
	aviso.add_theme_color_override("font_color", Color(0.98, 0.82, 0.35))
	aviso.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	aviso.add_theme_constant_override("outline_size", 5)
	_toasts.add_child(aviso)
	_temporizar_toast(aviso)


# UNA PREGUNTA DE SI O NO que no para el juego: "«Nacho» quiere entrar en el mundo: Aceptar / Rechazar".
# Va en su propia capa por ENCIMA del combate (100) y de los menus: quien espera en la puerta no puede
# quedarse colgado porque el que decide este en una pelea. Si nadie contesta en `plazo` segundos, cuenta
# como NO. al_responder(si: bool) se llama una sola vez.
func pedir_permiso(texto: String, al_responder: Callable, plazo: float = 60.0) -> void:
	var capa := CanvasLayer.new()
	capa.layer = 120
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(capa)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_top = 70
	panel.offset_left = -260
	panel.offset_right = 260
	capa.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var l := Label.new()
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 16)
	vb.add_child(l)
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 12)
	vb.add_child(fila)
	var hecho: Array = [false]   # Array y no bool: la lambda captura por valor
	var responder := func(si: bool):
		if hecho[0]:
			return
		hecho[0] = true
		capa.queue_free()
		al_responder.call(si)
	for op in [["Aceptar", true], ["Rechazar", false]]:
		var b := Button.new()
		b.text = op[0]
		b.custom_minimum_size = Vector2(150, 44)
		var si: bool = op[1]
		b.pressed.connect(func(): responder.call(si))
		fila.add_child(b)
	await get_tree().create_timer(plazo, true).timeout
	responder.call(false)


# Un tween por cartel (igual que _temporizar_esquina): al reiniciar la cuenta de un toast repetido
# hay que MATAR el anterior, o los dos tirarian del modulate a la vez.
func _temporizar_toast(aviso: Control) -> void:
	if aviso.has_meta("tween"):
		var viejo = aviso.get_meta("tween")
		if viejo is Tween and (viejo as Tween).is_valid():
			(viejo as Tween).kill()
	var t := aviso.create_tween()
	aviso.set_meta("tween", t)
	t.tween_interval(5.0)
	t.tween_property(aviso, "modulate:a", 0.0, 1.5)
	t.tween_callback(aviso.queue_free)


# AVISO DE ESQUINA: una pildora pequeña abajo a la derecha, del estilo "Guardando..." de toda la
# vida. Es para acuses de recibo, NO para noticias: lo que el jugador tiene que leer si o si va por
# mostrar_toast, que sale en grande en el centro.
#
# OJO A LA PAUSA: el HUD hereda PAUSABLE y todos los menus de este proyecto paran el arbol, asi que
# un tween creado desde el HUD se CONGELA con el menu abierto y el cartel se queda clavado en
# pantalla. Por eso la pildora se marca ALWAYS y su tween se crea DESDE ELLA (create_tween se ata al
# nodo que lo crea). Al HUD entero no se le pone ALWAYS: su _process reescribe labels cada frame y
# estaria corriendo durante todos los menus para nada.
func mostrar_aviso_esquina(texto: String, dur: float = 2.0) -> void:
	if _avisos_esquina == null:
		return

	# El autoguardado repite el mismo texto cada minuto: si el anterior sigue vivo, se le reinicia
	# la cuenta en vez de apilar dos pildoras identicas.
	for hijo in _avisos_esquina.get_children():
		if hijo.has_meta("texto") and String(hijo.get_meta("texto")) == texto:
			hijo.modulate.a = 1.0
			_temporizar_esquina(hijo as Control, dur)
			return

	while _avisos_esquina.get_child_count() >= AVISOS_ESQUINA_MAX:
		var vieja := _avisos_esquina.get_child(0)
		_avisos_esquina.remove_child(vieja)
		vieja.queue_free()

	var pildora := PanelContainer.new()
	pildora.add_theme_stylebox_override("panel", _fondo_pildora())
	pildora.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pildora.process_mode = Node.PROCESS_MODE_ALWAYS
	pildora.set_meta("texto", texto)
	pildora.size_flags_horizontal = Control.SIZE_SHRINK_END

	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.78, 0.80, 0.85))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 3)
	pildora.add_child(l)

	_avisos_esquina.add_child(pildora)
	_temporizar_esquina(pildora, dur)


func _temporizar_esquina(pildora: Control, dur: float) -> void:
	# Un tween por pildora: al crear uno nuevo sobre el mismo nodo, Godot descarta el anterior si lo
	# guardamos y lo matamos a mano (si no, los dos tirarian del modulate a la vez).
	if pildora.has_meta("tween"):
		var viejo = pildora.get_meta("tween")
		if viejo is Tween and (viejo as Tween).is_valid():
			(viejo as Tween).kill()
	var t := pildora.create_tween()
	pildora.set_meta("tween", t)
	t.tween_interval(dur)
	t.tween_property(pildora, "modulate:a", 0.0, 0.6)
	t.tween_callback(pildora.queue_free)


# Aviso de RECOGIDA (no bloqueante): una pildora a la izquierda con el material que acabas de
# coger, estilo gacha. Se apila con los anteriores y se desvanece sola. La llama Game desde los
# _on_*_finished y drop_pickup via el grupo "hud", igual que mostrar_toast.
func mostrar_recogida(nombre: String, cantidad: int = 1, calidad_txt: String = "") -> void:
	if _recogidas == null:
		return
	# Si ya hay demasiadas a la vista, tira la mas antigua (la de arriba) para que no crezca sin fin.
	while _recogidas.get_child_count() >= RECOGIDAS_MAX:
		var vieja := _recogidas.get_child(0)
		_recogidas.remove_child(vieja)
		vieja.queue_free()

	var pildora := PanelContainer.new()
	pildora.add_theme_stylebox_override("panel", _fondo_pildora())
	pildora.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 8)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pildora.add_child(caja)

	# Placeholder de icono (el arte va al final del proyecto): un cuadradito.
	var icono := ColorRect.new()
	icono.custom_minimum_size = Vector2(18, 18)
	icono.color = Color(0.55, 0.45, 0.75)
	icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caja.add_child(icono)

	var l := Label.new()
	l.text = nombre if cantidad <= 1 else "%s ×%d" % [nombre, cantidad]
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.95, 0.93, 0.98))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 3)
	caja.add_child(l)

	# CALIDAD (intacto/normal/dañado/puro): lo que de verdad importa del botín. Va en su propia
	# etiqueta, coloreada por calidad, para leerla de un vistazo sin confundirla con el nombre.
	if calidad_txt != "":
		var cal := Label.new()
		cal.text = calidad_txt
		cal.add_theme_font_size_override("font_size", 14)
		cal.add_theme_color_override("font_color", _color_calidad(calidad_txt))
		cal.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		cal.add_theme_constant_override("outline_size", 3)
		caja.add_child(cal)

	_recogidas.add_child(pildora)

	# Unos segundos a la vista y se desvanece (como mostrar_toast / el aviso de muerte).
	var t := create_tween()
	t.tween_interval(2.5)
	t.tween_property(pildora, "modulate:a", 0.0, 0.6)
	t.tween_callback(pildora.queue_free)


# Color del texto de calidad en la pildora. Por TEXTO (no por enum) porque material y cristal
# comparten la escala pero son clases distintas; asi no hay que acoplar con ninguno de sus enums.
func _color_calidad(txt: String) -> Color:
	match txt:
		"Puro":    return Color(0.98, 0.82, 0.35)   # dorado (el techo, solo lingotes bien fundidos)
		"Intacto": return Color(0.55, 0.85, 0.55)   # verde: lo mejor que se recolecta
		"Dañado":  return Color(0.90, 0.45, 0.40)   # rojo apagado: rinde poco
		"Roto":    return Color(0.90, 0.45, 0.40)   # (no suele llegar: se pierde)
		_:         return Color(0.78, 0.80, 0.85)   # Normal: gris neutro


# Fondo de una pildora de recogida: oscuro semitransparente y redondeado, con un borde tenue.
func _fondo_pildora() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.85)
	sb.border_color = Color(0.87, 0.57, 0.26, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 12
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb


# Panel negro semitransparente: lo que va SOBRE el mapa (teclas, piso, monedas) tiene que
# leerse igual en un suelo oscuro que en una pared blanca.
func _fondo_negro() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


# ============================================================
#  LA BOTONERA: debug, personaje, bolsa, mapa y pausa, arriba a la derecha.
#
#  72 px de lado y no los 34 de altura que tenian antes: 34 px en la resolucion de referencia
#  (1280x720) son ~3 mm de pantalla real, la mitad de lo que un pulgar acierta. 72 salen a ~7 mm,
#  que es la talla que se recomienda para un objetivo tactil.
#
#  Sale TAMBIEN EN ESCRITORIO, no solo con los dedos. Antes iba tras un `if Tactil.activo` y en PC
#  no habia mas via que las teclas: quien no se las supiera de memoria no tenia por donde entrar a
#  su ficha o al mapa. Las teclas siguen igual, y su chuleta tambien (esa si es solo de PC).
#
#  En ESCRITORIO son mas pequeños que con los dedos: los 72 px son la talla de un objetivo tactil
#  (~7 mm, lo que acierta un pulgar de verdad), pero con raton se apunta al pixel y ahi ese tamaño
#  solo come pantalla. Con 46 la fila entera ocupa ~290 px en vez de ~390.
#
#  Y aunque ocupen menos, la fila de tarjetas del grupo NO depende de que quepan por suerte: se
#  encoge sola hasta caber en el hueco que dejan estos (ver player.escala_fila). Por eso hace falta
#  ancho_botonera(): es el contrato entre los dos, y asi no pueden solaparse en ninguna resolucion.
# ============================================================
const ICONO_LADO_TACTIL := 72.0
const ICONO_LADO_RATON := 46.0
const ICONO_SEP := 8.0
const ICONO_MARGEN := 12.0
const ICONOS_N := 5   # cuantos botones hay en la fila (debug, ficha, bolsa, mapa, pausa)

# El lado que toca en este aparato. Es funcion y no constante porque depende de Tactil; quien lo
# necesite fuera (el panel de dev se coloca justo debajo) lo pide por aqui.
static func icono_lado() -> float:
	return ICONO_LADO_TACTIL if Tactil.activo else ICONO_LADO_RATON

# Lo que ocupa la botonera de ancho, con sus huecos y su margen. Lo usa el reparto de la fila de
# arriba para saber cuanto sitio le queda al grupo (ver player.escala_fila).
static func ancho_botonera() -> float:
	return icono_lado() * float(ICONOS_N) + ICONO_SEP * float(ICONOS_N - 1) \
		+ ICONO_MARGEN * 2.0 + Tactil.borde.x


func _montar_botonera() -> void:
	var fila := HBoxContainer.new()
	fila.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	# El borde seguro va DENTRO del margen: en un movil con las esquinas redondeadas, el ultimo
	# boton de la fila salia cortado por el canto de la pantalla (ver Tactil.borde).
	fila.offset_right = -ICONO_MARGEN - Tactil.borde.x
	fila.offset_top = ICONO_MARGEN + Tactil.borde.y
	fila.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	fila.add_theme_constant_override("separation", ICONO_SEP)
	add_child(fila)
	var ICONO_LADO: float = icono_lado()

	# El DEBUG va el PRIMERO (a la izquierda del todo): asi los cuatro de siempre no se mueven de
	# sitio y el engranaje sigue siendo el de la esquina. Antes era un boton de texto suelto abajo a
	# la izquierda, con el estilo por defecto de Godot y lejos de todo lo demas.
	fila.add_child(BotonIcono.crear(Callable(Iconos, "consola"),
		_abrir_menu.bind("debug_panel", "_toggle"), ICONO_LADO))
	fila.add_child(BotonIcono.crear(Callable(Iconos, "persona"),
		_abrir_menu.bind("menu_personaje", "_toggle"), ICONO_LADO))
	fila.add_child(BotonIcono.crear(Callable(Iconos, "mochila"),
		_abrir_menu.bind("menu_inventario", "_toggle"), ICONO_LADO))
	fila.add_child(BotonIcono.crear(Callable(Iconos, "pergamino"),
		_abrir_menu.bind("menu_mapa", "_toggle"), ICONO_LADO))
	# La pausa NO va por _toggle: tiene su propia alternar(), que es donde vive la regla de cuando
	# se puede pausar (ni sobre un combate ni sobre otro menu). Ver pause_menu.gd.
	fila.add_child(BotonIcono.crear(Callable(Iconos, "engranaje"),
		_abrir_menu.bind("menu_pausa", "alternar"), ICONO_LADO))


# EL FAROLILLO: la llama la pinta el cuadro solo con la fraccion del trozo en curso; aqui van los
# dos numeros de al lado -- cuantos trozos quedan y CUANTA LUZ EN TOTAL, que es el que de verdad
# decide si bajas otro piso o te vuelves.
#
# SIN FAROLILLO PUESTO NO SE ENSEÑA NADA. Un farol apagado permanente en pantalla es ruido para el
# que aun no tiene lampara (o esta en el pueblo, donde el carbon ni siquiera arde).
func _refrescar_farol() -> void:
	if _farol_box == null:
		return
	var puesto: bool = Game.equipped_lampara != null
	_farol_box.visible = puesto
	_farol_lbl.visible = puesto
	if not puesto:
		return
	_farol_box.hay_luz = Game.lampara_llama > 0.0
	_farol_box.llama = Game.llama_fraccion()
	var total: float = Game.luz_total_restante()
	# "xN" arriba y la luz total abajo. Los minutos van SIN segundos: es una magnitud para decidir de
	# un vistazo, y un contador al segundo invita a mirarlo en vez de jugar.
	_farol_lbl.text = "x%d\n%s" % [Game.carbon_restante(), _texto_luz(total)]
	_farol_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.55, 0.45) if total < AVISO_LUZ else Color.WHITE)
	_farol_lbl.tooltip_text = "Luz restante: %s\nCarbón: %d trozo%s\nAlcance: %.1f casillas" % [
		_texto_luz(total), Game.carbon_restante(), "" if Game.carbon_restante() == 1 else "s",
		Game.radio_lampara()]


# Menos de esto y el numero se pone rojo: es lo que tarda en amargarte quedarte a oscuras hondo.
const AVISO_LUZ := 180.0


func _texto_luz(seg: float) -> String:
	if seg <= 0.0:
		return "sin luz"
	if seg < 60.0:
		return "<1 min"
	return "%d min" % int(seg / 60.0)


# Abre (o cierra) uno de los menus del jugador llamandole a su metodo. NO se finge la tecla:
# Input.action_press no genera un evento de teclado y esos menus escuchan eventos, asi que por ahi
# no se enterarian (ver inventory_menu.gd).
func _abrir_menu(grupo: String, metodo: String) -> void:
	var m: Node = get_tree().get_first_node_in_group(grupo)
	if m != null and m.has_method(metodo):
		m.call(metodo)


func _process(_delta: float) -> void:
	# Ayudas de tecla (el resto de datos viven en las barras / cuadrado de peso / menus).
	# El [F] va AQUI y no repetido en el cartel de cada edificio: la tecla es siempre la misma, asi
	# que ponerla nueve veces por el pueblo era ruido. Va la primera por ser la que mas se usa.
	if not Tactil.activo:
		_counts.text = "[F] Interactuar   [I/B] Inventario   [C] Personaje   [Q] Curación óptima\n[F1] Ayuda   [F3] FPS   [Esc] Pausa"

	# LA MOCHILA: el numero encima, y el nivel + el color del agua los pinta ella sola con el ratio
	# de carga (ver cuadro_carga.gd y Game.color_carga).
	_peso_lbl.text = "%d/%d" % [roundi(Game.peso_actual()), roundi(Game.capacidad_carga())]
	_peso_box.ratio = Game.ratio_carga()
	_peso_box.tooltip_text = "Carga %d/%d  (%d%%)%s" % [
		roundi(Game.peso_actual()), roundi(Game.capacidad_carga()),
		roundi(_peso_box.ratio * 100.0),
		"\nVas SOBRECARGADO: andas más lento." if Game.esta_sobrecargado() else ""]

	_refrescar_farol()
