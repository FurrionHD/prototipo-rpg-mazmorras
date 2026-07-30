# ============================================================
#  fishing.gd
#  Minijuego de PESCA (caña -> RESISTENCIA). El de aguantar, no el de acertar.
#
#  MANTIENES ESPACIO: tu tramo verde SUBE. SUELTAS: BAJA. Con inercia, no con velocidad plana —
#  el tramo acelera mientras pulsas y frena al soltar, y esa demora es todo el juego: la mano se
#  te adelanta o se te queda corta y hay que corregir antes, no cuando ya ha pasado.
#  El PEZ se mueve arriba y abajo por su cuenta. Mientras esta DENTRO de tu tramo, la barra de
#  TENSION sube; mientras esta fuera, baja.
#    Tension llena  -> lo tienes.
#    Tension vacia  -> se suelta y se va.
#  No hay reloj: la pelea dura lo que dure. Un pez facil se saca en unos segundos y uno grande te
#  tiene un rato con el pulso apretado, que es de donde sale la RESISTENCIA.
#
#  Y LO QUE NO HACE, que es lo importante: NO tapa el mundo. Los otros tres minijuegos abren una
#  pantalla a pantalla completa y esconden la mazmorra (Game.esconder_mundo); este se pega a un
#  lado y deja ver el agua, el hilo y al pez forcejeando. Ver Game.start_pesca.
#
#  Se crea por codigo (sin .tscn), como sus tres hermanos.
# ============================================================

extends Control

signal pesca_finished(logrado: bool, progreso: float)

enum { READY, RUNNING, FINISHED }

var _data: MaterialData = null
var _cm: float = 0.0

# --- Parametros que pone Game.start_pesca desde la dificultad ---
var _alto_tramo: float = 0.22   # alto de TU tramo, en fraccion de la barra
var _vel_pez: float = 0.5       # lo rapido que se mueve el pez (barras/seg)
var _erratico: float = 1.0      # cada cuanto cambia de destino (mas alto = mas nervioso)
var _sube: float = 0.42         # cuanto sube la tension por segundo con el pez dentro
var _baja: float = 0.30         # cuanto baja por segundo con el pez fuera

# --- Estado ---
var _y: float = 0.5             # centro de TU tramo (0 abajo .. 1 arriba)
var _v: float = 0.0             # su velocidad (la inercia)
var _pez_y: float = 0.5
var _pez_destino: float = 0.5
var _t_destino: float = 0.0
var _tension: float = 0.35      # empiezas con algo hecho: el tiron ya conto
var _dentro: bool = false
var _state: int = READY
var _logrado: bool = false
var _press_was: bool = false

# GRAVEDAD y EMPUJE del tramo, en fracciones de barra por segundo^2. El empuje es mayor que la
# gravedad porque el tramo tiene que poder subir contra ella; la diferencia es la aceleracion neta.
const GRAVEDAD := 1.5
const EMPUJE := 3.1
# Rozamiento: sin el, el tramo rebota eternamente entre los topes y la barra se vuelve un pinball.
const ROCE := 0.86
# Con lo que arranca la pelea. No es 0 a proposito: el tiron ya lo has clavado, empiezas con ventaja.
const TENSION_INICIAL := 0.35


func setup(data: MaterialData, cm: float, alto_tramo: float, vel_pez: float,
		erratico: float, sube: float, baja: float) -> void:
	_data = data
	_cm = cm
	_alto_tramo = alto_tramo
	_vel_pez = vel_pez
	_erratico = erratico
	_sube = sube
	_baja = baja


func _ready() -> void:
	# A UN LADO, no a pantalla completa: el mundo tiene que seguir viendose. Es LA diferencia con
	# mining/harvest/talado, que se ponen en PRESET_FULL_RECT y pintan el fondo entero de negro.
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE)
	custom_minimum_size = Vector2(ANCHO, ALTO)
	size = Vector2(ANCHO, ALTO)
	position = Vector2(position.x - ANCHO - MARGEN, position.y - ALTO * 0.5)
	_tension = TENSION_INICIAL
	_pez_y = 0.5
	_pez_destino = 0.5
	_y = 0.5

const ANCHO := 150.0
const ALTO := 300.0
const MARGEN := 40.0


func _process(delta: float) -> void:
	var pressed: bool = Input.is_key_pressed(KEY_SPACE)

	if _state == FINISHED:
		# Se sale con una pulsacion NUEVA, no con la que acabo de sacar el pez.
		if pressed and not _press_was:
			pesca_finished.emit(_logrado, progreso_frac())
			queue_free()
		_press_was = pressed
		return

	# Arranca al SOLTAR el ESPACIO con el que clavaste el tiron: si arrancase al pulsar, ese mismo
	# espacio ya estaria empujando el tramo hacia arriba antes de que hayas visto la barra.
	if _state == READY:
		if _press_was and not pressed:
			_state = RUNNING
		_press_was = pressed
		queue_redraw()
		return

	_mover_tramo(delta, pressed)
	_mover_pez(delta)
	_tensar(delta)

	_press_was = pressed
	queue_redraw()


func _mover_tramo(delta: float, pressed: bool) -> void:
	_v += (EMPUJE - GRAVEDAD if pressed else -GRAVEDAD) * delta
	_v *= pow(ROCE, delta * 60.0)
	_y += _v * delta
	# Topes DUROS con la velocidad a cero: rebotar contra el borde seria un regalo (te devuelve al
	# centro gratis) y ademas se siente a bug.
	var media: float = _alto_tramo * 0.5
	if _y <= media:
		_y = media
		_v = maxf(_v, 0.0)
	elif _y >= 1.0 - media:
		_y = 1.0 - media
		_v = minf(_v, 0.0)


func _mover_pez(delta: float) -> void:
	_t_destino -= delta
	if _t_destino <= 0.0:
		# El pez elige un punto NUEVO de la barra y va a por el. Cuanto mas erratico, mas seguido
		# cambia de idea y mas lejos se va: es lo que hace que la anguila sea la anguila.
		_pez_destino = clampf(randf(), 0.05, 0.95)
		_t_destino = randf_range(0.35, 1.4) / maxf(0.3, _erratico)
	_pez_y = move_toward(_pez_y, _pez_destino, _vel_pez * delta)


func _tensar(delta: float) -> void:
	var media: float = _alto_tramo * 0.5
	_dentro = absf(_pez_y - _y) <= media
	_tension = clampf(_tension + (_sube if _dentro else -_baja) * delta, 0.0, 1.0)
	if _tension >= 1.0:
		_terminar(true)
	elif _tension <= 0.0:
		_terminar(false)


func _terminar(logrado: bool) -> void:
	_state = FINISHED
	_logrado = logrado
	queue_redraw()


# Lo que llegaste a hacer, 0..1. Paga la excelia aunque el pez se escape (mismo criterio que los
# otros tres minijuegos, ver Game.ganar_recoleccion): pelear diez segundos y perderlo entrena;
# soltar la caña a la primera, no.
func progreso_frac() -> float:
	return clampf(_tension, 0.0, 1.0)


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	# Fondo SEMITRANSPARENTE, no opaco: por detras se tiene que seguir viendo el charco.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.07, 0.10, 0.78))

	var bx: float = 26.0
	var bw: float = 46.0
	var by: float = 34.0
	var bh: float = size.y - 64.0

	# La barra: el agua vista de canto.
	draw_rect(Rect2(bx, by, bw, bh), Color(0.10, 0.17, 0.26))

	# TU TRAMO. Verde cuando tienes al pez dentro, ambar cuando se te escapa: el color es el
	# unico aviso que puedes leer sin apartar la vista de la barra.
	var th: float = bh * _alto_tramo
	var ty: float = by + bh * (1.0 - _y) - th * 0.5
	draw_rect(Rect2(bx, ty, bw, th),
		Color(0.35, 0.75, 0.40, 0.75) if _dentro else Color(0.85, 0.65, 0.22, 0.55))

	# EL PEZ: el mismo rectangulo alargado que ves en el agua, de canto.
	var pw: float = bw * 0.55
	var ph: float = 9.0
	var py: float = by + bh * (1.0 - _pez_y) - ph * 0.5
	draw_rect(Rect2(bx + (bw - pw) * 0.5, py, pw, ph),
		_data.color if _data != null else Color(0.8, 0.8, 0.8))

	# TENSION, en su propia barra al lado. Se llena de abajo a arriba, como la de tu tramo: dos
	# barras que se leen al reves serian una trampa de lectura.
	var tx: float = bx + bw + 12.0
	var tw: float = 16.0
	draw_rect(Rect2(tx, by, tw, bh), Color(0.22, 0.20, 0.19))
	var lleno: float = bh * _tension
	# Rojo cuando esta a punto de romperse: el jugador tiene que notar el peligro sin contar pixeles.
	var col: Color = Color(0.85, 0.25, 0.20) if _tension < 0.22 else Color(0.40, 0.75, 0.95)
	draw_rect(Rect2(tx, by + bh - lleno, tw, lleno), col)

	var nombre: String = _data.nombre if _data != null else "algo"
	draw_string(font, Vector2(8.0, 20.0), nombre, HORIZONTAL_ALIGNMENT_CENTER, size.x - 16.0, 13)
	if _state == READY:
		draw_string(font, Vector2(8.0, size.y - 12.0), "SUELTA para empezar",
			HORIZONTAL_ALIGNMENT_CENTER, size.x - 16.0, 11)
	elif _state == RUNNING:
		draw_string(font, Vector2(8.0, size.y - 12.0), "MANTÉN ESPACIO",
			HORIZONTAL_ALIGNMENT_CENTER, size.x - 16.0, 11)
	else:
		draw_string(font, Vector2(8.0, size.y - 12.0),
			"¡LO TIENES!" if _logrado else "Se ha soltado",
			HORIZONTAL_ALIGNMENT_CENTER, size.x - 16.0, 11)
