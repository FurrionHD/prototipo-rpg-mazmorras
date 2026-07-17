# ============================================================
#  turn_timeline.gd  (Control)
#  Linea de ORDEN DE TURNOS estilo Epic Seven: una barra horizontal con los
#  "iconos" de los combatientes, que avanzan segun su velocidad hacia el
#  punto de accion (derecha). Al llegar, ese actua y su icono vuelve al principio.
#
#  Los marcadores son NODOS HIJO (ColorRect), no dibujos del _draw(). Tiene que ser asi:
#  el marcador del jugador lleva SU aspecto (color, imagen y shader de metal del cuerpo), y
#  un material es propiedad del CanvasItem entero -> puesto en este Control teñiria tambien
#  la linea, el texto y los marcadores enemigos, y ademas el shader mapea por UV del Control
#  (una barra larga y baja), asi que la imagen del cubo saldria estirada de lado a lado.
#  Con un ColorRect cuadrado por marcador, cada uno lleva lo suyo y sale igual que en el mapa.
#  El _draw() se queda solo para lo estatico: la linea, el punto de accion y su texto.
# ============================================================

extends Control

const MARGEN := 40.0    # margen a los lados de la linea
const RADIO := 16.0     # medio lado del marcador (cuadrado de 32x32)

# Combatant -> {rect: ColorRect, ratio: float}. La clave es el propio Combatant (el mismo
# dominio que el _gauge del combate): evita inventarse un segundo sistema de indices.
var _marcadores: Dictionary = {}


# Da de alta un marcador. 'material' puede ser null (color plano, como el cuerpo sin imagen);
# 'texto' es lo que va escrito encima (el numero del enemigo; vacio para el jugador, que ya
# se reconoce por su aspecto).
func anadir(c: Combatant, color: Color, material: ShaderMaterial, texto: String) -> void:
	if c == null or _marcadores.has(c):
		return
	var r := ColorRect.new()
	# CUADRADO obligatorio: el shader del cuerpo mapea la imagen por UV del rect, y uno no
	# cuadrado deformaria la foto del personaje.
	r.size = Vector2(RADIO * 2.0, RADIO * 2.0)
	r.color = color
	r.material = material
	# IGNORE en el marcador y en su texto: el mouse_filter del Control padre NO se hereda, asi
	# que sin esto los marcadores robarian clics a lo que quede debajo.
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	if texto != "":
		var l := Label.new()
		l.text = texto
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 16)
		l.add_theme_color_override("font_color", Color.BLACK)
		l.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.7))
		l.add_theme_constant_override("outline_size", 3)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(l)
	_marcadores[c] = {"rect": r, "ratio": 0.0}


# Saca un marcador de la barra (al morir su dueño: ya no espera turno).
func quitar(c: Combatant) -> void:
	if not _marcadores.has(c):
		return
	_marcadores[c]["rect"].queue_free()
	_marcadores.erase(c)


# ratios: Combatant -> 0..1 (cuanto lleno tiene su turno). Coloca cada marcador y ordena la
# profundidad por avance, para que el que va en cabeza se vea encima de los que le pisan.
func set_ratios(ratios: Dictionary) -> void:
	for c in _marcadores:
		var r: float = clampf(float(ratios.get(c, 0.0)), 0.0, 1.0)
		var m: Dictionary = _marcadores[c]
		m["ratio"] = r
		var rect: ColorRect = m["rect"]
		var x0: float = MARGEN
		var x1: float = size.x - MARGEN
		rect.position = Vector2(x0 + r * (x1 - x0) - RADIO, size.y * 0.5 - RADIO)
		rect.z_index = int(r * 100.0)
	queue_redraw()


func _draw() -> void:
	var y: float = size.y * 0.5
	var x0: float = MARGEN
	var x1: float = size.x - MARGEN

	# Linea de la barra.
	draw_line(Vector2(x0, y), Vector2(x1, y), Color(0.45, 0.45, 0.5), 3.0)
	# Punto de accion (derecha).
	draw_line(Vector2(x1, y - 16.0), Vector2(x1, y + 16.0), Color(1, 1, 1), 2.0)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(x1 - 30.0, y - 22.0), "ACCION", HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
