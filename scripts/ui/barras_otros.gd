class_name BarrasOtros
extends Control
# LAS BARRAS DEL OTRO JUGADOR (10/10, playtest 09/10: "los personajes de Arian en la barra de arriba"). Detras de tu
# mochila y tu farol, mas pequeñas y atenuadas: el nombre del jugador encima y una columna por cada uno de su grupo
# (vida, aguante, mana). Solo se miran: no se pulsan ni llevan cuadro de equipo ni estados.
# Los numeros llegan por Net.jugadores.mis_barras (lo que ve SU barra, en pelea lo de su combatiente). Lo monta y lo
# coloca player._rehacer_barras; player._refrescar_barras lo refresca cada fotograma.

signal ancho_cambiado

const ANCHO_COL := 92.0
const SEP_COL := 6.0
const SEP_JUGADOR := 14.0
const ATENUADO := Color(1, 1, 1, 0.78)

# Las alturas de las columnas de player.gd (Y_NOMBRE, Y_HP, ALTO_HP...), para ir a la par de las tuyas. Las pone el.
var medidas: Dictionary = {}

var _firma: String = ""
var _cols: Dictionary = {}   # uid -> {hp, hp_lbl, en, en_lbl, mp, mp_lbl, nombre}
var _ancho: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = ATENUADO


func ancho() -> float:
	return _ancho


func refrescar() -> void:
	var grupos: Array = Net.jugadores.barras_de_otros() if Net.activo else []
	# Quien hay (jugadores y sus personajes, en orden): si cambia, se rehace; si no, solo los numeros.
	var firma: String = ""
	for g in grupos:
		firma += String(g[0]) + ":"
		for f in (g[1] as Array):
			firma += String(f[0]) + ","
		firma += ";"
	if firma != _firma:
		_firma = firma
		_rehacer(grupos)
	for g in grupos:
		for f in (g[1] as Array):
			var col: Dictionary = _cols.get(String(f[0]), {})
			if col.is_empty():
				continue
			(col["nombre"] as Label).text = ("👑 " if bool(f[9]) else "") + String(f[1])
			_poner(col["hp"], col["hp_lbl"], float(f[3]), float(f[4]), "%.0f/%.0f")
			_poner(col["en"], col["en_lbl"], float(f[5]), float(f[6]), "%.0f/%.0f")
			_poner(col["mp"], col["mp_lbl"], float(f[7]), float(f[8]), "%.1f/%.1f")


func _poner(bar: ProgressBar, lbl: Label, v: float, m: float, fmt: String) -> void:
	bar.max_value = maxf(1.0, m)
	bar.value = v
	lbl.text = fmt % [v, m]


func _rehacer(grupos: Array) -> void:
	for n in get_children():
		n.queue_free()
	_cols.clear()
	var x: float = 0.0
	for g in grupos:
		var filas: Array = g[1]
		# El NOMBRE DEL JUGADOR, delante de sus columnas y a la altura de la vida ("Arian: [..][..]").
		var jug := _label(String(g[0]) + ":", 10, Color(1.0, 0.85, 0.45))
		jug.position = Vector2(x, float(medidas["Y_HP"]))
		add_child(jug)
		x += jug.get_combined_minimum_size().x + 6.0
		for f in filas:
			var punto := ColorRect.new()
			punto.size = Vector2(7, 7)
			punto.position = Vector2(x, float(medidas["Y_NOMBRE"]) + 1.0)
			punto.color = f[2] as Color
			punto.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(punto)
			var nombre := _label("", 9, Color.WHITE)
			nombre.position = Vector2(x + 9.0, float(medidas["Y_NOMBRE"]) - 4.0)
			nombre.size = Vector2(ANCHO_COL - 9.0, 14.0)
			nombre.clip_text = true
			add_child(nombre)
			var col: Dictionary = {"nombre": nombre}
			for b in [["hp", medidas["Y_HP"], medidas["ALTO_HP"], Color(1.0, 0.4, 0.4)],
					["en", medidas["Y_EN"], medidas["ALTO_EN"], Color(0.4, 1.0, 0.5)],
					["mp", medidas["Y_MP"], medidas["ALTO_MP"], Color(0.4, 0.6, 1.0)]]:
				var bar := ProgressBar.new()
				bar.show_percentage = false
				bar.custom_minimum_size = Vector2(ANCHO_COL, float(b[2]))
				bar.size = Vector2(ANCHO_COL, float(b[2]))
				bar.position = Vector2(x, float(b[1]))
				bar.self_modulate = b[3] as Color
				bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
				add_child(bar)
				var lbl := _label("", 9, Color.WHITE)
				lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				bar.add_child(lbl)
				col[b[0]] = bar
				col[String(b[0]) + "_lbl"] = lbl
			_cols[String(f[0])] = col
			x += ANCHO_COL + SEP_COL
		x += SEP_JUGADOR - SEP_COL
	var nuevo: float = maxf(0.0, x - SEP_JUGADOR) if not grupos.is_empty() else 0.0
	if not is_equal_approx(nuevo, _ancho):
		_ancho = nuevo
		ancho_cambiado.emit()


func _label(txt: String, tam: int, color: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
