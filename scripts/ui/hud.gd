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

var _counts: Label = null
var _peso_box: ColorRect = null # cuadrado (placeholder de bolsa) a la derecha de las barras
var _peso_lbl: Label = null     # numero de peso encima del cuadrado
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
	if Tactil.activo:
		_montar_botonera()

	# Cuadrado de PESO (placeholder de una futura bolsa/mochila) a la derecha de las
	# barras, con el numero encima. Cambia de color segun te vas cargando.
	_peso_box = ColorRect.new()
	_peso_box.position = Vector2(200, 16)
	_peso_box.size = Vector2(44, 44)
	add_child(_peso_box)

	_peso_lbl = Label.new()
	_peso_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_peso_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_peso_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_peso_lbl.add_theme_font_size_override("font_size", 11)
	_peso_lbl.add_theme_color_override("font_color", Color.WHITE)
	_peso_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_peso_lbl.add_theme_constant_override("outline_size", 4)
	_peso_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_peso_box.add_child(_peso_lbl)

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

	recolocar()
	_avisar_muerte()


# Aparta el cuadrado del PESO para dejar sitio a las columnas de barras del grupo: la tuya y una
# por companero (las pinta player.gd, ver alli x_columna). Con esto la mochila queda SIEMPRE justo
# detras de la ultima columna, contrates a quien contrates.
#
# Las medidas se leen de player.gd para no tener el layout escrito en dos sitios y que se separen
# el dia que una columna cambie de ancho.
func recolocar() -> void:
	var jugador: Node = get_tree().get_first_node_in_group("player")
	if _peso_box != null:
		var x: float = 200.0   # sin jugador (no deberia pasar): donde estaba de siempre
		if jugador != null:
			x = jugador.x_columna(Game.party.size()) + 4.0
		_peso_box.position = Vector2(x, jugador.Y_HP if jugador != null else 16.0)
	# Y la caja de ayudas, justo debajo del bloque de barras. Va aqui y no con una y fija porque
	# el bloque crecio al meterle el nombre encima: con la 64 de antes se solapaban.
	if _caja_ayudas != null:
		var y: float = 64.0
		if jugador != null:
			y = float(jugador.ALTO_BLOQUE) + 6.0
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
func mostrar_toast(texto: String) -> void:
	var aviso := Label.new()
	aviso.text = texto
	aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	aviso.offset_top = 130
	aviso.offset_left = -420
	aviso.offset_right = 420
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.add_theme_font_size_override("font_size", 18)
	aviso.add_theme_color_override("font_color", Color(0.98, 0.82, 0.35))
	aviso.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	aviso.add_theme_constant_override("outline_size", 5)
	add_child(aviso)
	var t := create_tween()
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
#  LA BOTONERA (solo con los dedos): personaje, bolsa, mapa y pausa, arriba a la derecha.
#
#  72 px de lado y no los 34 de altura que tenian antes: 34 px en la resolucion de referencia
#  (1280x720) son ~3 mm de pantalla real, la mitad de lo que un pulgar acierta. 72 salen a ~7 mm,
#  que es la talla que se recomienda para un objetivo tactil.
#
#  Los cuatro con sus huecos ocupan ~310 px de los 1280: no llegan a chocar con las tarjetas del
#  grupo, que con cuatro miembros acaban en el 764 (ver player.x_columna).
# ============================================================
const ICONO_LADO := 72.0
const ICONO_SEP := 10.0
const ICONO_MARGEN := 12.0


func _montar_botonera() -> void:
	var fila := HBoxContainer.new()
	fila.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fila.offset_right = -ICONO_MARGEN
	fila.offset_top = ICONO_MARGEN
	fila.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	fila.add_theme_constant_override("separation", ICONO_SEP)
	add_child(fila)

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
		_counts.text = "[F] Interactuar   [I] Inventario   [C] Personaje   [Q] Curación óptima\n[F1] Ayuda   [F3] FPS   [Esc] Pausa"

	# Cuadrado de PESO: numero encima y color por ratio de carga.
	# Blanco/gris cuando vas ligero -> amarillo al acercarte al limite -> rojo sobrecargado.
	_peso_lbl.text = "%d/%d" % [roundi(Game.peso_actual()), roundi(Game.capacidad_carga())]
	var ratio: float = Game.ratio_carga()
	var col: Color
	if Game.esta_sobrecargado():
		col = Color(0.85, 0.15, 0.15)  # rojo pleno
	else:
		# 0..overload_threshold -> gris a amarillo.
		var t: float = clampf(ratio / maxf(0.01, Game.overload_threshold), 0.0, 1.0)
		col = Color(0.35, 0.35, 0.38).lerp(Color(0.9, 0.8, 0.1), t)
	_peso_box.color = col
