# ============================================================
#  hud.gd  (CanvasLayer creada por codigo desde el jugador)
#  HUD de exploracion (siempre visible):
#   - Cuadrado de PESO a la derecha de las barras (placeholder de la bolsa/mochila),
#     con el numero encima y color gris -> amarillo -> rojo segun la carga.
#   - "Piso: N" en la esquina superior derecha.
#   - Linea de ayudas de tecla bajo las barras.
#  El INVENTARIO vive ahora en inventory_menu.gd (tecla I) y las stats en
#  character_menu.gd (tecla C). Las barras de vida/energia/mana las pinta player.gd.
# ============================================================

extends CanvasLayer

var _counts: Label = null
var _floor_lbl: Label = null    # "Piso: N" en la esquina superior derecha
var _money_lbl: Label = null    # monedas, debajo del piso
var _peso_box: ColorRect = null # cuadrado (placeholder de bolsa) a la derecha de las barras
var _peso_lbl: Label = null     # numero de peso encima del cuadrado
# La caja de ayudas de teclas. Va debajo de las barras y no se mueve, pero se guarda por si algun
# dia hay que recolocarla como al cuadrado del peso.
var _caja_ayudas: PanelContainer = null


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
	add_child(caja)

	_counts = Label.new()
	_counts.add_theme_font_size_override("font_size", 12)
	_counts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(_counts)

	# "Piso: N" y las MONEDAS en la esquina superior derecha, en el mismo panel negro
	# semitransparente (sobre una pared clara, el texto a pelo no se leia).
	var esq := PanelContainer.new()
	esq.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	esq.offset_left = -170
	esq.offset_right = -12
	esq.offset_top = 8
	esq.add_theme_stylebox_override("panel", _fondo_negro())
	esq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(esq)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	esq.add_child(col)

	_floor_lbl = Label.new()
	_floor_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_floor_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_floor_lbl)

	# Monedas, justo debajo del piso: ahora que la tienda cobra, hay que ver lo que llevas.
	_money_lbl = Label.new()
	_money_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_money_lbl.add_theme_color_override("font_color", Color(0.95, 0.86, 0.5))
	_money_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_money_lbl)

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


func _process(_delta: float) -> void:
	# Ayudas de tecla (el resto de datos viven en las barras / cuadrado de peso / menus).
	_counts.text = "[I] Inventario   [C] Personaje   [Q] Curación óptima\n[F1] Ayuda   [F3] FPS   [Esc] Pausa"

	# Piso arriba a la derecha, y el dinero debajo.
	_floor_lbl.text = "Piso: %d" % Game.current_floor
	_money_lbl.text = "%d monedas" % Game.money

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
