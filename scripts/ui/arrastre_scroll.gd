# ============================================================
#  arrastre_scroll.gd
#  "Deslizar con el dedo" para cualquier ScrollContainer.
#
#  El problema: Godot ya trae arrastre tactil, pero el gesto tiene que EMPEZAR sobre el propio
#  contenedor. En estos menus casi toda la superficie son botones (mira la forja: filas enteras de
#  − / 0 / +), asi que el dedo cae siempre encima de uno, el boton se queda el evento y la lista no
#  se mueve. Con un pulgar eso deja el menu utilizable solo por la barrita lateral.
#
#  La solucion: escuchar en _input, que corre ANTES que la GUI. Asi nos enteramos del gesto aunque
#  el dedo caiga sobre un boton:
#    - Al tocar NO se consume nada: si acaba siendo un toque limpio, el boton de debajo funciona.
#    - En cuanto el recorrido pasa del UMBRAL, esto pasa a ser un arrastre: se mueve el scroll y se
#      consume lo que queda del gesto. El boton ya no vera el "soltar" y no se disparara —por eso
#      los botones de este proyecto disparan AL SOLTAR y no al pulsar (ver boton_icono.gd).
#    - Al soltar queda INERCIA, que es lo que separa "una lista de movil" de "una barra de scroll".
#
#  hubo_arrastre() es para que quien tenga cosas pulsables dentro pueda preguntar "¿esto ha sido un
#  toque o me estaban deslizando?" antes de hacerle caso (lo usan las tarjetas de la tira de pisos).
# ============================================================

extends Node
class_name ArrastreScroll

# Lo que hay que mover para que deje de ser un toque y pase a ser un arrastre. Por debajo de ~10 px
# un pulgar tiembla al pulsar y cancelaria pulsaciones buenas; por encima de ~25 el gesto se siente
# pegajoso.
const UMBRAL := 16.0
# Rozamiento de la inercia: cuanto de la velocidad sobrevive cada segundo.
const FRENO := 0.06
const VEL_MINIMA := 12.0   # por debajo de esto se para del todo


var _scroll: ScrollContainer = null
var _dedo: int = -1              # indice del dedo, o -2 si manda el raton; -1 = nadie
var _origen: Vector2 = Vector2.ZERO
var _scroll_inicial: int = 0
var _arrastrando: bool = false
var _vel: float = 0.0
var _ultima_y: float = 0.0
var _hubo: bool = false          # el ultimo gesto llego a ser un arrastre
# Tragarse lo que queda de un gesto que ya fue arrastre. Ver el comentario de _input: un toque
# genera DOS eventos (el de pantalla y el click emulado detras), y si solo se consume el primero,
# el segundo le llega al boton de debajo y lo dispara al final del arrastre.
var _tragar: bool = false


# Engancha el arrastre a un ScrollContainer. Devuelve el nodo por si hace falta, pero normalmente
# se llama y ya: se cuelga del propio scroll y muere con el.
static func enganchar(scroll: ScrollContainer) -> Node:
	if scroll == null:
		return null
	var a := ArrastreScroll.new()
	a._scroll = scroll
	a.name = "ArrastreScroll"
	scroll.add_child(a)
	return a


# ¿El ultimo gesto sobre este scroll fue un arrastre? Lo preguntan los controles pulsables de
# dentro para no dispararse cuando en realidad les estaban deslizando por encima.
static func hubo_arrastre(scroll: ScrollContainer) -> bool:
	if scroll == null:
		return false
	var a: Node = scroll.get_node_or_null("ArrastreScroll")
	return a != null and a._hubo


func _ready() -> void:
	# El arbol esta PAUSADO mientras hay un menu abierto (ver Game.abrir_menu), que es justo cuando
	# esto tiene que funcionar.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if _scroll == null or not _scroll.is_visible_in_tree():
		return

	# Un gesto que YA fue arrastre no puede acabar disparando el boton de debajo. Ojo con el orden:
	# con la emulacion de raton puesta, cada toque llega DOS veces (el click emulado primero y el
	# evento de pantalla detras), y el que cierra el arrastre —el "soltar"— apaga _arrastrando antes
	# de que se decida si consumirlo. Sin esto, el boton recibia ese soltar y se pulsaba solo cada
	# vez que arrastrabas por encima. Lo caza la prueba de dev_mapa.
	var estaba: bool = _arrastrando
	var es_pulsar: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if es_pulsar:
		_tragar = false   # gesto nuevo: lo de antes ya no cuenta

	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_empezar(t.index, t.position)
		elif t.index == _dedo or _dedo == -2:
			_terminar()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		# El -2 tambien vale: si el gesto lo cogio el click emulado (que llega ANTES que el toque),
		# el dedo de verdad sigue mandando el arrastre y hay que hacerle caso. Llamar a _mover dos
		# veces no molesta: calcula contra el origen, no acumulando.
		if d.index == _dedo or _dedo == -2:
			_mover(d.position)
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.button_index != MOUSE_BUTTON_LEFT:
			return
		# -2 = "manda el raton". Se distingue del indice de un dedo (0, 1, 2...) para que el click
		# emulado que viene DETRAS de cada toque no le robe el gesto al dedo de verdad.
		if m.pressed:
			_empezar(-2, m.position)
		elif _dedo == -2:
			_terminar()
	elif event is InputEventMouseMotion and _dedo == -2:
		_mover((event as InputEventMouseMotion).position)

	# Consumir va AL FINAL: el evento que EMPIEZA el gesto tiene que seguir su camino hasta el boton
	# de debajo (si acaba siendo un toque limpio, el boton tiene que funcionar). 'estaba' y _tragar
	# cubren el final del arrastre, que es donde se colaba el disparo.
	if _arrastrando or estaba or _tragar:
		get_viewport().set_input_as_handled()


func _empezar(idx: int, pos: Vector2) -> void:
	if _dedo != -1:
		return
	if not _scroll.get_global_rect().has_point(pos):
		return
	_dedo = idx
	_origen = pos
	_ultima_y = pos.y
	_scroll_inicial = _scroll.scroll_vertical
	_arrastrando = false
	_hubo = false
	_vel = 0.0


func _mover(pos: Vector2) -> void:
	if _dedo == -1:
		return
	var recorrido: float = pos.y - _origen.y
	if not _arrastrando:
		if absf(recorrido) < UMBRAL:
			return
		_arrastrando = true
		_hubo = true
	# El scroll se calcula contra el ORIGEN y no acumulando el delta de cada frame: acumulando, los
	# redondeos a entero de scroll_vertical se van comiendo pixeles y el contenido se queda atras
	# del dedo.
	_scroll.scroll_vertical = _scroll_inicial - int(recorrido)
	_vel = (_ultima_y - pos.y) / maxf(get_process_delta_time(), 0.001)
	_ultima_y = pos.y


func _terminar() -> void:
	_dedo = -1
	if not _arrastrando:
		_vel = 0.0
	# Si esto era un arrastre, hay que tragarse tambien la copia emulada del "soltar" que viene
	# detras. Se apaga sola en cuanto empieza un gesto nuevo (ver _input).
	_tragar = _arrastrando
	_arrastrando = false


func _process(delta: float) -> void:
	# La inercia de despues de soltar. Mientras el dedo sigue puesto no corre: ahi manda el dedo.
	if _dedo != -1 or absf(_vel) < VEL_MINIMA:
		_vel = 0.0
		return
	_scroll.scroll_vertical += int(_vel * delta)
	_vel *= pow(FRENO, delta)
