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
var _peso_box: ColorRect = null # cuadrado (placeholder de bolsa) a la derecha de las barras
var _peso_lbl: Label = null     # numero de peso encima del cuadrado


func _ready() -> void:
	layer = 5  # por encima de la mazmorra, por debajo del combate (100)

	# Un HUD recien creado SIEMPRE arranca con el inventario cerrado. Reiniciamos
	# el flag global por si veniamos de una escena con el inventario abierto (p.ej.
	# pulsar R para recargar teniendolo abierto): si no, el jugador nuevo se
	# quedaria congelado creyendo que el inventario sigue abierto.
	Game.inventory_open = false

	# Ayudas de tecla, debajo de las barras de aguante/vida/mana del jugador.
	_counts = Label.new()
	_counts.position = Vector2(12, 66)
	add_child(_counts)

	# "Piso: N" en la esquina superior derecha.
	_floor_lbl = Label.new()
	_floor_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_floor_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_floor_lbl.offset_left = -160
	_floor_lbl.offset_right = -12
	_floor_lbl.offset_top = 10
	add_child(_floor_lbl)

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

	_avisar_muerte()


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


func _process(_delta: float) -> void:
	# Ayudas de tecla (el resto de datos viven en las barras / cuadrado de peso / menus).
	_counts.text = "[I] Inventario   [C] Personaje   [Q] Curación óptima   [F1] Info"

	# Piso arriba a la derecha.
	_floor_lbl.text = "Piso: %d" % Game.current_floor

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
