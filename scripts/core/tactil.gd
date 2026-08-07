# ============================================================
#  tactil.gd  (autoload "Tactil")
#  El unico sitio que sabe si estamos jugando con los dedos.
#
#  El juego lee las teclas por ACCIONES del InputMap (ver [input] en project.godot). Un boton
#  de la pantalla no puede pulsar una tecla fisica, pero SI puede empujar la accion: eso hace
#  pulsar()/soltar(). Por eso los ~15 sitios que leen "correr", "interactuar", etc. no se enteran
#  de si el que manda es un Shift o un pulgar, y no hay que tocarlos.
#
#  El JOYSTICK es la excepcion, y a proposito: las acciones de movimiento son digitales
#  (dentro/fuera) y un stick es analogico. Por eso publica un Vector2 (eje) que player.gd lee
#  directamente, en vez de fingir cuatro pulsaciones.
# ============================================================

extends Node

# ¿Estamos en un aparato tactil? Se calcula UNA vez al arrancar: no cambia a mitad de partida y
# lo consultan sitios que corren cada frame.
var activo: bool = false

# La direccion que publica el joystick virtual, ya normalizada al rango de Input.get_vector
# (largo 0..1). Vector2.ZERO = no hay dedo puesto.
var eje: Vector2 = Vector2.ZERO

# EL BORDE QUE NO SE VE. Muchos moviles tienen la pantalla redondeada por las esquinas, o con una
# muesca, o curvada por los lados: lo que se pinta pegado al borde se PIERDE. Medido en un aparato
# de verdad, las tarjetas del grupo y los botones aparecian cortados.
#
# Esto es cuanto hay que apartarse de cada lado, en pixeles del juego (no de la pantalla: se
# convierte con la escala del stretch, o en un movil de 1080 de alto el margen saldria del doble de
# lo que toca). Lo consultan el HUD, las barras del grupo y los mandos.
var borde: Vector2 = Vector2.ZERO

# Suelo del borde en un aparato tactil, por si el sistema no declara zona segura (muchos no lo
# hacen) pero la pantalla si esta redondeada. Mas vale un dedo de aire de sobra que un boton cortado.
const BORDE_MINIMO := 18.0

# Las acciones que hemos dejado pulsadas nosotros (los botones de fijar: correr, sigilo). Se
# guardan para poder soltarlas TODAS de golpe: si un boton se queda hundido al cambiar de escena
# o al abrir un menu, el personaje se queda corriendo solo para siempre.
var _pulsadas: Dictionary = {}


func _ready() -> void:
	# La bandera de desarrollo va PRIMERO para poder probar el overlay en el PC sin generar un
	# APK en cada retoque de tamaño o posicion. En el juego de verdad nadie la pasa.
	if OS.get_cmdline_args().has("--tactil") or OS.get_cmdline_user_args().has("--tactil"):
		activo = true
		print("[tactil] mandos de movil FORZADOS por --tactil")
	else:
		activo = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	_medir_borde()
	# La zona segura cambia al girar el aparato, asi que hay que volver a medirla.
	get_tree().get_root().size_changed.connect(_medir_borde)


# Calcula cuanto hay que apartarse de los bordes. La zona segura viene en pixeles DE PANTALLA y el
# juego dibuja en los 1280x720 de referencia (stretch canvas_items), asi que hay que pasarla por la
# escala o el margen saldria el doble de gordo de lo que toca.
func _medir_borde() -> void:
	if not activo:
		borde = Vector2.ZERO
		return
	var pantalla: Vector2 = Vector2(DisplayServer.window_get_size())
	var segura: Rect2i = DisplayServer.get_display_safe_area()
	var izq: float = 0.0
	var arr: float = 0.0
	if pantalla.x > 0.0 and segura.size.x > 0 and segura.size.x < int(pantalla.x):
		izq = float(segura.position.x)
	if pantalla.y > 0.0 and segura.size.y > 0 and segura.size.y < int(pantalla.y):
		arr = float(segura.position.y)
	var lienzo: Vector2 = get_viewport().get_visible_rect().size
	var escala: Vector2 = Vector2.ONE
	if pantalla.x > 0.0 and pantalla.y > 0.0:
		escala = lienzo / pantalla
	borde = Vector2(maxf(izq * escala.x, BORDE_MINIMO), maxf(arr * escala.y, BORDE_MINIMO))
	print("[tactil] borde seguro: %.0f x %.0f px de juego" % [borde.x, borde.y])


# Empuja una accion del InputMap como si se hubiera pulsado la tecla.
func pulsar(accion: StringName) -> void:
	if not InputMap.has_action(accion):
		push_warning("Tactil.pulsar: accion desconocida '%s'" % accion)
		return
	_pulsadas[accion] = true
	Input.action_press(accion)


func soltar(accion: StringName) -> void:
	if not InputMap.has_action(accion):
		return
	_pulsadas.erase(accion)
	Input.action_release(accion)


func esta_pulsada(accion: StringName) -> bool:
	return _pulsadas.has(accion)


# Pulsar y soltar en el mismo frame no vale: el codigo que lee la accion mira
# Input.is_action_pressed() dentro de _physics_process, y si la soltamos antes de que corra, no
# la ve nunca. Asi que se suelta al frame SIGUIENTE.
func toque(accion: StringName) -> void:
	pulsar(accion)
	await get_tree().process_frame
	await get_tree().physics_frame
	soltar(accion)


# Suelta todo lo que hayamos dejado hundido. Lo llama el overlay al esconderse (menu, combate,
# cambio de escena): un boton de fijar que sobrevive a una pantalla es un personaje que sale de
# ella corriendo o agachado sin haberlo pedido.
func soltar_todo() -> void:
	for accion in _pulsadas.keys():
		Input.action_release(accion)
	_pulsadas.clear()
	eje = Vector2.ZERO
