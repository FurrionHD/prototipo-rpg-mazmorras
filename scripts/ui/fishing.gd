# ============================================================
#  fishing.gd
#  Minijuego de PESCA (caña -> RESISTENCIA). El de aguantar, no el de acertar.
#
#  QUIEN MUEVE QUE: tu manejas la LINEA BLANCA (el hilo), y el PEZ arrastra el TRAMO VERDE. No al
#  reves. Es lo que se ve desde fuera: el pez tira y tu persigues, no le pintas una caja encima.
#
#  MANTIENES ESPACIO: tu linea SUBE. SUELTAS: BAJA. Con inercia, no con velocidad plana — la linea
#  acelera mientras pulsas y frena al soltar, y esa demora es todo el juego: la mano se te adelanta
#  o se te queda corta y hay que corregir antes, no cuando ya ha pasado.
#  El TRAMO VERDE se mueve arriba y abajo por su cuenta (lo lleva el pez). Mientras tu linea esta
#  DENTRO del tramo, la barra de TENSION sube; mientras esta fuera, baja.
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
var _y: float = 0.5             # TU LINEA, la blanca (0 abajo .. 1 arriba)
var _v: float = 0.0             # su velocidad (la inercia)
var _pez_y: float = 0.5         # centro del TRAMO VERDE: lo lleva el pez
var _pez_destino: float = 0.5
# Segundos que le quedan PARADO. > 0 = esta quieto (tu ventana para alcanzarlo); 0 = va nadando
# hacia _pez_destino. Ver _mover_pez.
var _t_destino: float = 0.0
var _tension: float = 0.35      # empiezas con algo hecho: el tiron ya conto
var _dentro: bool = false
var _state: int = READY
var _logrado: bool = false
var _press_was: bool = false

# Rozamiento: sin el, la linea rebota eternamente entre los topes y la barra se vuelve un pinball.
const ROCE := 0.86

# LO RAPIDO QUE PUEDE IR TU LINEA, en veces la velocidad del pez. Tiene que ser > 1: si fuera igual
# de rapida jamas recortarias una distancia, solo mantenerla, y el pez que se va no vuelve nunca.
const VEL_LINEA_REL := 1.25

# GRAVEDAD y EMPUJE de la linea, en fracciones de barra por segundo^2. NO son constantes: se
# calculan en setup() a partir de la velocidad del pez.
#
# El porque: con el rozamiento, la velocidad de la linea no es la aceleracion, es a/k con
# k = -60·ln(ROCE) ≈ 9.05. Con los valores fijos de antes (1.5 y 3.1) eso daba 0.177 barras/s
# mientras el pez base iba a 0.42 y el dificil a 1.15: entre 2.4x y 6.5x mas rapido que tu. Perseguir
# algo que corre seis veces mas no es dificil, es imposible, y no se veia en los numeros porque el
# rozamiento se comia el 94% de la aceleracion.
#
# Ahora las dos salen de v_objetivo = vel_pez × VEL_LINEA_REL, y son SIMETRICAS (empuje = 2×gravedad)
# para que subir y bajar topen a la misma velocidad: si bajar fuera mas lento, la mitad de las
# correcciones llegarian tarde por un motivo que el jugador no puede ver.
var _gravedad: float = 1.5
var _empuje: float = 3.1
# Con lo que arranca la pelea. No es 0 a proposito: el tiron ya lo has clavado, empiezas con ventaja.
# Subido de 0.35 a 0.45 (playtest): es el COLCHON de los primeros segundos, mientras localizas el
# tramo y la linea coge inercia. Ganar no se vuelve mas facil por esto — lo que manda ahi es `sube`,
# que ya se bajo a 0.20 — pero perder en el primer segundo deja de ser posible.
const TENSION_INICIAL := 0.45


func setup(data: MaterialData, cm: float, alto_tramo: float, vel_pez: float,
		erratico: float, sube: float, baja: float) -> void:
	_data = data
	_cm = cm
	_alto_tramo = alto_tramo
	_vel_pez = vel_pez
	_erratico = erratico
	_sube = sube
	_baja = baja
	# k = coeficiente de rozamiento por segundo, el que convierte aceleracion en velocidad tope
	# (v_tope = a / k). Sale del ROCE, que se aplica como pow(ROCE, delta*60).
	var k: float = -60.0 * log(ROCE)
	_gravedad = _vel_pez * VEL_LINEA_REL * k
	_empuje = _gravedad * 2.0


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

	_mover_linea(delta, pressed)
	_mover_pez(delta)
	_tensar(delta)

	_press_was = pressed
	queue_redraw()


# TU LINEA. Va de borde a borde de la barra: es un hilo, no una caja, asi que no tiene que dejar
# hueco para ningun alto propio.
func _mover_linea(delta: float, pressed: bool) -> void:
	_v += (_empuje - _gravedad if pressed else -_gravedad) * delta
	_v *= pow(ROCE, delta * 60.0)
	_y += _v * delta
	# Topes DUROS con la velocidad a cero: rebotar contra el borde seria un regalo (te devuelve al
	# centro gratis) y ademas se siente a bug.
	if _y <= 0.0:
		_y = 0.0
		_v = maxf(_v, 0.0)
	elif _y >= 1.0:
		_y = 1.0
		_v = minf(_v, 0.0)


# EL PEZ, que es quien arrastra el TRAMO VERDE. Su centro se queda a media altura de tramo de los
# bordes para que el tramo nunca salga medio fuera de la barra (si no, pegado al borde el tramo
# valdria la mitad y el pez seria mas dificil por un accidente de dibujo).
#
# EL RITMO ES: TIRON -> PARADA -> TIRON. La parada no es lo que sobra de un cronometro, es una fase
# con su propia duracion, y es LA VENTANA en la que puedes alcanzarlo y tensar. Antes el pez elegia
# destino cada X segundos y solo descansaba si llegaba antes de tiempo: contra un pez rapido y
# nervioso no paraba nunca y no habia nada que pudieras hacer para mantenerte dentro.
#
# El nerviosismo (_erratico) ACORTA la parada, pero NUNCA por debajo de PAUSA_MINIMA, y ese suelo es
# el numero que de verdad importa de todo este archivo: es el tiempo que tienes GARANTIZADO para
# alcanzarlo y tensar, con el peor pez posible y sin cumplir su requisito. Con 0.30 s no daba tiempo
# a nada (la linea tiene inercia: arrancar y frenar ya se come esas decimas), asi que el pez de
# arriba era ingobernable no por rapido, sino por no parar nunca de verdad.
#
# 0.75 s a 0.30 de tension por segundo son ~0.22 de barra por parada aunque vayas pelado.
const PAUSA_MIN := 0.75
const PAUSA_MAX := 1.40
const PAUSA_MINIMA := 0.75

func _mover_pez(delta: float) -> void:
	var media: float = _alto_tramo * 0.5
	if _t_destino > 0.0:
		_t_destino -= delta   # PARADO: es tu turno de alcanzarlo
		return
	_pez_y = clampf(move_toward(_pez_y, _pez_destino, _vel_pez * delta), media, 1.0 - media)
	if absf(_pez_y - _pez_destino) < 0.001:
		# Ha llegado: se queda quieto un momento y de paso ya elige a donde ira despues.
		_t_destino = maxf(PAUSA_MINIMA, randf_range(PAUSA_MIN, PAUSA_MAX) / maxf(0.3, _erratico))
		_pez_destino = clampf(randf(), media, 1.0 - media)


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

	# EL TRAMO DEL PEZ. Verde cuando tienes la linea dentro, ambar cuando se te escapa: el color es
	# el unico aviso que puedes leer sin apartar la vista de la barra.
	var th: float = bh * _alto_tramo
	var ty: float = by + bh * (1.0 - _pez_y) - th * 0.5
	draw_rect(Rect2(bx, ty, bw, th),
		Color(0.35, 0.75, 0.40, 0.75) if _dentro else Color(0.85, 0.65, 0.22, 0.55))

	# EL PEZ dentro de su tramo: el mismo rectangulo alargado que ves en el agua, de canto. Va del
	# color del pez para que se lea de que bicho es la pelea.
	var pw: float = bw * 0.55
	var ph: float = 9.0
	var py: float = by + bh * (1.0 - _pez_y) - ph * 0.5
	draw_rect(Rect2(bx + (bw - pw) * 0.5, py, pw, ph),
		_data.color if _data != null else Color(0.8, 0.8, 0.8))

	# TU LINEA: el hilo. Blanca, fina y de lado a lado de la barra, para que se distinga de un
	# vistazo del tramo (que es una banda de color) — es lo unico que mueves tu.
	var ly: float = by + bh * (1.0 - _y) - 1.5
	draw_rect(Rect2(bx - 4.0, ly, bw + 8.0, 3.0), Color(1.0, 1.0, 1.0, 0.95))

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
