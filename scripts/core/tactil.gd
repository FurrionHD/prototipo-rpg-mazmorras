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
