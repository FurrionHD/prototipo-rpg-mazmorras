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
const MARCO_HOLGURA := 3.0   # cuanto asoma el marco de objetivo alrededor del marcador
const FLECHA_LARGO := 14.0   # cuanto sobresale por el costado el triangulo que señala al objetivo
const MARCO_ENCENDIDO := Color(1, 1, 1, 0.95)   # el mismo blanco que el borde de las tarjetas
const MARCO_APAGADO := Color(0, 0, 0, 0)

# DE PIE en vez de tumbada. Lo pone quien la monta (ver combat._crear_timeline), antes de dar de
# alta a nadie. En vertical el ratio 0 esta ABAJO y el punto de accion ARRIBA: se lee como una
# cuenta atras que sube, y deja el ancho de la pantalla libre para el escenario.
var vertical: bool = false

# Combatant -> {marco: ColorRect, flecha: Control, ratio: float}. Se guarda el MARCO y no el
# marcador de color, porque el marcador cuelga de el: moviendo el marco se mueve todo. La clave
# es el propio Combatant (el mismo dominio que el _gauge del combate): evita inventarse un
# segundo sistema de indices.
var _marcadores: Dictionary = {}

# A quien apunta el jugador ahora mismo (o null si no hay objetivo, p.ej. en el turno de un
# enemigo). Lo pone combat.gd via marcar_objetivo() cada vez que cambia _target_idx.
var _objetivo: Combatant = null


# Da de alta un marcador. 'material' puede ser null (color plano, como el cuerpo sin imagen);
# 'texto' es lo que va escrito encima (el numero del enemigo; vacio para el jugador, que ya
# se reconoce por su aspecto).
func anadir(c: Combatant, color: Color, material: ShaderMaterial, texto: String) -> void:
	if c == null or _marcadores.has(c):
		return
	# MARCO: el borde blanco de "este es tu objetivo". Es mayor que el marcador y va DETRAS -el
	# marcador cuelga centrado dentro suyo-, asi que alrededor asoma un borde de MARCO_HOLGURA px
	# por cada lado, igual que el borde de seleccion de las tarjetas de enemigo en combat.gd
	# (_sb_bloque). Sin marcar se pone TRANSPARENTE, no oculto: ocultarlo se llevaba por delante
	# al marcador de dentro (la visibilidad se hereda) y desaparecian todos menos el objetivo.
	var marco := ColorRect.new()
	marco.size = Vector2(RADIO * 2.0 + MARCO_HOLGURA * 2.0, RADIO * 2.0 + MARCO_HOLGURA * 2.0)
	marco.color = MARCO_APAGADO
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(marco)

	var r := ColorRect.new()
	# CUADRADO obligatorio: el shader del cuerpo mapea la imagen por UV del rect, y uno no
	# cuadrado deformaria la foto del personaje.
	r.size = Vector2(RADIO * 2.0, RADIO * 2.0)
	r.position = Vector2(MARCO_HOLGURA, MARCO_HOLGURA)
	r.color = color
	r.material = material
	# IGNORE en el marcador y en su texto: el mouse_filter del Control padre NO se hereda, asi
	# que sin esto los marcadores robarian clics a lo que quede debajo.
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marco.add_child(r)
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

	# FLECHA: señala al marcador desde su COSTADO DERECHO cuando es tu objetivo. Mismo triangulo
	# blanco semitransparente que el 'cursor' de combat.gd sobre la figura del enemigo, pero de
	# lado y no por arriba: colgada arriba se metia sobre el marcador que va justo delante en la
	# cola. Cuelga del marco para moverse con el sin mas.
	var flecha := Control.new()
	flecha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flecha.visible = false
	flecha.position = Vector2(marco.size.x, 0.0)
	flecha.size = Vector2(FLECHA_LARGO, marco.size.y)
	flecha.draw.connect(func() -> void:
		var h: float = flecha.size.y
		flecha.draw_colored_polygon(PackedVector2Array([
			Vector2(0.0, h * 0.5), Vector2(FLECHA_LARGO, h * 0.5 - 9.0),
			Vector2(FLECHA_LARGO, h * 0.5 + 9.0)]), Color(1, 1, 1, 0.9)))
	marco.add_child(flecha)

	_marcadores[c] = {"marco": marco, "flecha": flecha, "ratio": 0.0}


# Saca un marcador de la barra (al morir su dueño: ya no espera turno).
func quitar(c: Combatant) -> void:
	if not _marcadores.has(c):
		return
	_marcadores[c]["marco"].queue_free()   # se lleva por delante al marcador y a la flecha: son sus hijos
	_marcadores.erase(c)
	if _objetivo == c:
		_objetivo = null


# A quien apuntas ahora. La llama combat.gd cada vez que cambia el objetivo (clic en una
# tarjeta, salto automatico al caer el actual, o el objetivo inicial al empezar el combate):
# apaga el marco y la flecha del anterior y enciende los del nuevo. 'c' puede ser null (fuera
# de tu turno no hay a quien señalar).
func marcar_objetivo(c: Combatant) -> void:
	if _objetivo != null and _marcadores.has(_objetivo):
		var anterior: Dictionary = _marcadores[_objetivo]
		anterior["marco"].color = MARCO_APAGADO
		anterior["flecha"].visible = false
	_objetivo = c
	if c != null and _marcadores.has(c):
		var actual: Dictionary = _marcadores[c]
		actual["marco"].color = MARCO_ENCENDIDO
		actual["flecha"].visible = true


# EL PUNTO de la linea para un avance 'r' (0 = salida, 1 = le toca). Es lo UNICO que sabe en que
# orientacion estamos: colocar marcadores y dibujar la barra salen los dos de aqui, asi que no
# pueden acabar diciendo cosas distintas.
func _punto_de(r: float) -> Vector2:
	if vertical:
		# r=0 abajo, r=1 arriba: la cuenta SUBE hacia el punto de accion.
		return Vector2(size.x * 0.5, (size.y - MARGEN) - r * (size.y - MARGEN * 2.0))
	return Vector2(MARGEN + r * (size.x - MARGEN * 2.0), size.y * 0.5)


# ratios: Combatant -> 0..1 (cuanto lleno tiene su turno). Coloca cada marcador y ordena la
# profundidad por avance, para que el que va en cabeza se vea encima de los que le pisan -salvo
# el objetivo marcado, que siempre gana esa pelea (z_index 1000, por encima del maximo normal de
# ~100): si esta tapado por otro, tiene que poder verse igual.
func set_ratios(ratios: Dictionary) -> void:
	for c in _marcadores:
		var r: float = clampf(float(ratios.get(c, 0.0)), 0.0, 1.0)
		var m: Dictionary = _marcadores[c]
		m["ratio"] = r
		var marco: ColorRect = m["marco"]
		marco.position = _punto_de(r) - marco.size * 0.5
		marco.z_index = 1000 if c == _objetivo else int(r * 100.0)
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
