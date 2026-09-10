# ============================================================
#  dev_ritual.gd  -- EL VISOR DE LA ANIMACION PREVIA DE LA MEDITACION
#
#  La reproduce A VELOCIDAD REAL, en bucle y en una ventana. Existe porque las capturas del visor del
#  maestro no valen para juzgar esto: una animacion de seis segundos con cinco fases encadenadas se
#  juzga por el RITMO -- si el paseo se hace largo, si el giro llega tarde, si el brillo entra de
#  golpe --, y eso no sale en cinco fotos. Es la misma razon por la que los gestos de combate tienen
#  ver_gestos.bat aparte de sus hojas de contacto.
#
#  Se lanza con:
#    herramientas/ver_ritual.bat            (o dev_ritual.tscn con F6)
#
#  NECESITA VENTANA: con --headless no se dibuja nada (misma nota que ver_creador.gd).
#
#  TECLAS
#    ESPACIO   repetir desde el principio
#    ← / →     rareza del brillo: es LO UNICO que la animacion comunica, asi que hay que poder
#              compararlas seguidas. Se ve el nombre y el color arriba a la izquierda.
#    P         pausa / seguir
#    , / .     un pasito atras / adelante con la pausa puesta (para mirar un fotograma concreto)
#    + / -     mas lento / mas rapido
#    ESC       salir
# ============================================================
extends Control

const GachaRitual = preload("res://scripts/ui/gacha_ritual.gd")

# Las ocho bandas, con su nombre. Salen de Upgrades para que el visor enseñe LOS COLORES DE VERDAD:
# escribirlos aqui a mano seria juzgar el brillo contra una paleta que no es la del juego.
const RAREZAS := ["Común", "Poco común", "Raro", "Épico", "Legendario", "Mítico", "Obra maestra",
	"Prístino"]

var _rareza: int = 5
var _vel: float = 1.0
var _pausa: bool = false
var _ritual: Control = null
var _hud: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# El visor NO se pausa a si mismo, pero la capa que prueba se usa en un menu que SI para el arbol
	# (maestro_menu va en PROCESS_MODE_ALWAYS por eso). Aqui se deja en ALWAYS para que las dos corran
	# igual que en el juego y el ritmo que se ve sea el de verdad.
	process_mode = Node.PROCESS_MODE_ALWAYS

	var fondo := ColorRect.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.02, 0.02, 0.03)
	add_child(fondo)

	_hud = Label.new()
	_hud.position = Vector2(16, 12)
	_hud.add_theme_font_size_override("font_size", 14)
	# POR ENCIMA DEL RITUAL, que se dibuja hasta z 2600 (el tomo y su luz). Sin esto el fogonazo del
	# final se come el cartel justo cuando hace falta leer que rareza se esta mirando.
	_hud.z_index = 3000
	add_child(_hud)

	_lanzar()


func _lanzar() -> void:
	if _ritual != null and is_instance_valid(_ritual):
		# remove_child ADEMAS de queue_free: queue_free no saca del arbol hasta el final del frame, y
		# dos pases seguidos se dibujarian superpuestos. Misma trampa que en el menu.
		if _ritual.get_parent() != null:
			_ritual.get_parent().remove_child(_ritual)
		_ritual.queue_free()
	_ritual = GachaRitual.new()
	# AL ACABAR, VUELVE A EMPEZAR. En el juego aqui entra el revelado de las cartas; aqui el bucle es
	# lo que permite mirarla cinco veces seguidas, que es como se decide si el ritmo esta bien.
	# SIN AMAGO: el amago del gacha NO vive aqui, vive en la carta (ver ver_amagos.bat). Esta capa
	# solo sabe pintar el color que le den.
	_ritual.montar(self, Upgrades.rareza_color(_rareza), _lanzar)
	# SU RELOJ, APAGADO: lo lleva este visor (ver _process). Con los dos corriendo la animacion iba al
	# doble de velocidad, que en un visor de RITMO es el peor fallo posible -- no da error y lo que se
	# juzga es una mentira.
	_ritual.set_process(false)
	_pintar_hud()


func _pintar_hud() -> void:
	var col: Color = Upgrades.rareza_color(_rareza)
	_hud.text = "%s     ·  x%.2f%s     ·  ESPACIO repite  ←/→ rareza  P pausa  ,/. paso  +/- velocidad" % [
		RAREZAS[_rareza], _vel, "  (EN PAUSA)" if _pausa else ""]
	_hud.add_theme_color_override("font_color", col)


func _process(delta: float) -> void:
	if _ritual == null or not is_instance_valid(_ritual):
		return
	# EL RELOJ LO LLEVA EL VISOR, no la capa: es lo que deja cambiar la velocidad y dar pasos sueltos.
	# La capa ya sabe pararse (set_process(false) al terminar) y clavarse en un instante (plantar),
	# asi que aqui basta con decirle DONDE esta -- no hace falta ni una linea de animacion duplicada,
	# que es justo lo que haria que el visor y el juego se separaran.
	if _pausa:
		return
	_ritual.plantar(_ritual.reloj() + delta * _vel)


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo):
		return
	var k: int = (e as InputEventKey).keycode
	match k:
		KEY_ESCAPE:
			get_tree().quit()
		KEY_SPACE:
			_lanzar()
		KEY_RIGHT:
			_rareza = mini(_rareza + 1, RAREZAS.size() - 1)
			_lanzar()
		KEY_LEFT:
			_rareza = maxi(_rareza - 1, 0)
			_lanzar()
		KEY_P:
			_pausa = not _pausa
		KEY_COMMA:
			_ritual.plantar(_ritual.reloj() - 0.05)
		KEY_PERIOD:
			_ritual.plantar(_ritual.reloj() + 0.05)
		KEY_EQUAL, KEY_KP_ADD:
			_vel = minf(_vel * 1.25, 4.0)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_vel = maxf(_vel / 1.25, 0.15)
	_pintar_hud()
