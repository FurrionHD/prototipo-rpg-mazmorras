# ============================================================
#  turn_timeline.gd  (Control)
#  Linea de ORDEN DE TURNOS estilo Epic Seven: una barra con los "iconos" de los
#  combatientes, que avanzan segun su velocidad hacia el punto de accion. Al
#  llegar, ese actua y su icono vuelve al principio.
#
#  Va en DOS ORIENTACIONES (ver 'vertical'): tumbada, con el punto de accion a la
#  derecha, o de pie pegada al lateral, con el punto de accion ARRIBA y los
#  marcadores subiendo. Toda la diferencia esta en _punto_de(): el resto del
#  fichero -dar de alta, quitar, colocar, la profundidad por avance- no sabe en
#  que orientacion esta.
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

# DE PIE en vez de tumbada. Lo pone quien la monta (ver combat._crear_timeline), antes de dar de
# alta a nadie. En vertical el ratio 0 esta ABAJO y el punto de accion ARRIBA: se lee como una
# cuenta atras que sube, y deja el ancho de la pantalla libre para el escenario.
var vertical: bool = false

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


# EL PUNTO de la linea para un avance 'r' (0 = salida, 1 = le toca). Es lo UNICO que sabe en que
# orientacion estamos: colocar marcadores y dibujar la barra salen los dos de aqui, asi que no
# pueden acabar diciendo cosas distintas.
func _punto_de(r: float) -> Vector2:
	if vertical:
		# r=0 abajo, r=1 arriba: la cuenta SUBE hacia el punto de accion.
		return Vector2(size.x * 0.5, (size.y - MARGEN) - r * (size.y - MARGEN * 2.0))
	return Vector2(MARGEN + r * (size.x - MARGEN * 2.0), size.y * 0.5)


# ratios: Combatant -> 0..1 (cuanto lleno tiene su turno). Coloca cada marcador y ordena la
# profundidad por avance, para que el que va en cabeza se vea encima de los que le pisan.
func set_ratios(ratios: Dictionary) -> void:
	for c in _marcadores:
		var r: float = clampf(float(ratios.get(c, 0.0)), 0.0, 1.0)
		var m: Dictionary = _marcadores[c]
		m["ratio"] = r
		var rect: ColorRect = m["rect"]
		rect.position = _punto_de(r) - Vector2(RADIO, RADIO)
		rect.z_index = int(r * 100.0)
	queue_redraw()


func _draw() -> void:
	var a: Vector2 = _punto_de(0.0)
	var b: Vector2 = _punto_de(1.0)
	var font: Font = ThemeDB.fallback_font

	# Linea de la barra.
	draw_line(a, b, Color(0.45, 0.45, 0.5), 3.0)
	# Punto de accion: una marca ATRAVESADA en el extremo de llegada, y su etiqueta al lado de
	# fuera (en vertical, encima; tumbada, por encima de la linea como siempre).
	if vertical:
		draw_line(b - Vector2(16.0, 0.0), b + Vector2(16.0, 0.0), Color(1, 1, 1), 2.0)
		draw_string(font, b + Vector2(-size.x * 0.5, -10.0), "ACCION",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 12)
	else:
		draw_line(b - Vector2(0.0, 16.0), b + Vector2(0.0, 16.0), Color(1, 1, 1), 2.0)
		draw_string(font, b + Vector2(-30.0, -22.0), "ACCION", HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
