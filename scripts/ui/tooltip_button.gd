# ============================================================
#  tooltip_button.gd
#  Boton con un TOOLTIP decente: ancho maximo y varias lineas.
#
#  El tooltip por DEFECTO de Godot no tiene ninguna propiedad de ancho: pinta el texto en
#  una sola linea, asi que el resumen de una habilidad (que es largo) salia como una tira
#  horizontal que se iba de la pantalla. La unica via limpia es dar el nuestro,
#  sobrescribiendo _make_custom_tooltip.
#
#  Se usa igual que un Button normal: le pones tooltip_text y ya.
# ============================================================

extends Button
class_name TooltipButton

# Ancho al que se parte el texto. Los resumenes de habilidad/hechizo caben en 3-6 lineas.
const ANCHO := 560.0
const TAM_LETRA := 15


# Panel del tooltip. Se CENTRA sobre el raton: Godot lo pega abajo-derecha del cursor y no
# hay ninguna propiedad para cambiarlo, asi que hay que recolocar la ventanita del tooltip
# una vez creada (cuando ya sabe cuanto mide).
class PanelTooltip extends PanelContainer:
	# El viewport del JUEGO (el del boton que abre el tooltip). Se lo pasamos hecho, y no lo
	# buscamos desde aqui, por dos razones:
	#   - get_viewport() DENTRO del tooltip devuelve el viewport del PROPIO tooltip: una
	#     "pantalla" del tamaño del popup (604 px) y un raton relativo a el. Con eso, el
	#     calculo salia absurdo y el popup acababa estampado contra el borde izquierdo.
	#   - Window.get_parent_viewport() no existe en esta version de Godot (revienta).
	var vp_juego: Viewport = null

	func _ready() -> void:
		# Diferido: en _ready el panel aun no tiene tamaño final (lo da el Label al ajustarse).
		call_deferred("_centrar")

	func _centrar() -> void:
		var w := get_parent() as Window
		if w == null or vp_juego == null:
			return
		# w.position (popup embebido) se mide en el espacio del viewport del juego: es ahi
		# donde hay que preguntar por el raton y por el ancho de pantalla.
		var raton: Vector2 = vp_juego.get_mouse_position()
		var limite: float = vp_juego.get_visible_rect().size.x

		# Centrado sobre el cursor y acotado a la pantalla: si un tooltip ancho no cabe
		# centrado (boton pegado a un borde), se arrima al borde. Mejor descentrado que cortado.
		var ancho: float = float(w.size.x)
		var x: float = clampf(raton.x - ancho * 0.5, 8.0, maxf(8.0, limite - ancho - 8.0))
		w.position = Vector2i(int(x), w.position.y)


func _make_custom_tooltip(for_text: String) -> Object:
	var panel := PanelTooltip.new()
	panel.vp_juego = get_viewport()   # AQUI si es el del juego: lo llama el BOTON, no el tooltip

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.97)
	sb.border_color = Color(0.87, 0.57, 0.26, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)

	var l := Label.new()
	l.text = for_text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(ANCHO, 0.0)
	l.add_theme_color_override("font_color", Color(0.88, 0.90, 0.94))
	l.add_theme_font_size_override("font_size", TAM_LETRA)
	l.add_theme_constant_override("line_spacing", 4)
	panel.add_child(l)

	return panel
