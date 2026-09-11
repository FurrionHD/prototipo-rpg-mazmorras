# ============================================================
#  talado.gd
#  Minijuego de TALADO (enredadera -> hacha -> AGILIDAD). Los otros dos van de PUNTERIA:
#  en el cristal persigues un marcador, en la veta cargas y sueltas. Aqui va de COMPAS.
#
#  El tronco es un punto FIJO en el centro de la banda. Lo que se mueve es la VENTANA, que
#  da vueltas: entra por la izquierda, cruza el tronco y sale por la derecha. Cada vuelta es
#  un TIEMPO del compas, y en cada tiempo tienes que dar UN hachazo:
#    - ESPACIO con la ventana ENCIMA del tronco -> hachazo limpio (+1) y el ritmo ACELERA.
#    - ESPACIO fuera (te adelantas o te retrasas) -> pierdes el compas: +1 astilla.
#    - Dejar pasar la ventana SIN pulsar -> tambien pierdes el compas: +1 astilla.
#  Y cada astilla ENCOGE la ventana: fallar no solo te penaliza, te deja el siguiente tiempo
#  mas dificil. Es una bola de nieve, y de ahi sale la tension.
#
#  A las 3 astillas el tronco se raja y no sacas nada. Un solo hachazo por tiempo: machacar
#  espacio no sirve de nada (el primer toque resuelve el tiempo, acierte o falle).
#
#  La AGILIDAD ensancha la ventana y frena el compas. Se crea por codigo (sin .tscn).
#
#  YA NO ES UNA PANTALLA: es un MEDIDOR vertical que va al lado del personaje mientras se le ve talar
#  en el mapa (ver scripts/world/faena.gd). La franja BAJA por el carril y la raya del tronco esta a
#  media altura; la mecanica de arriba es la misma, solo girada.
# ============================================================

extends Control

signal talado_finished(item: MaterialItem, progreso: float)
# Para la FAENA: cada hachazo que se da (limpio o a destiempo). Dejar pasar la franja sin pulsar NO
# lo emite: ahi no se ha dado ningun golpe, solo se ha perdido el compas.
enum Golpe { FALLO, LIMPIO }
signal golpe(tipo: int)

enum { READY, RUNNING, FINISHED }

# Donde esta el tronco en la banda. Fijo y en el centro: el reto es el ritmo, no adivinar
# donde hay que pegar.
const TRONCO := 0.5
# Astillas a las que el tronco se raja del todo.
const ASTILLAS_ROTO := 3
# Lo que ACELERA el compas por cada hachazo limpio (le coges el ritmo y vas a mas).
const TEMPO_SUBE := 1.08
# Lo que ENCOGE la ventana por cada astilla (pierdes el pulso y te cuesta recuperarlo).
const VENTANA_ENCOGE := 0.78
# Suelo de la ventana: por muy mal que lo hagas, nunca es literalmente imposible acertar.
const VENTANA_MIN := 0.03

var _material: MaterialData = null
var _hachazos: int = 4      # hachazos limpios que hacen falta para tumbarlo
var _ancho: float = 0.20    # ancho de la ventana (fraccion de la banda)
var _vel: float = 0.7       # vueltas por segundo

var _pos: float = 0.0       # borde IZQUIERDO de la ventana
var _progreso: int = 0
var _astillas: int = 0
var _tiempo_resuelto: bool = false   # ¿ya has dado (o fallado) el hachazo de esta vuelta?
var _ultimo: String = ""
var _ultimo_t: float = 0.0   # cuanto le queda en pantalla a ese texto
var _state: int = READY   # empieza en espera: no arranca hasta pulsar ESPACIO
var _result: MaterialItem = null
var _press_was: bool = true   # true al abrir: exige una pulsacion NUEVA para empezar


func setup(material: MaterialData, hachazos: int, ancho: float, vel: float) -> void:
	_material = material
	_hachazos = maxi(1, hachazos)
	_ancho = ancho
	_vel = vel


const _TOUCH_PAD := preload("res://scripts/ui/touch_pad.gd")


func _ready() -> void:
	size = Vector2(MedidorFaena.ANCHO, MedidorFaena.ALTO)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nueva_vuelta()
	if Tactil.activo:
		# La pantalla entera es el hacha (ver touch_pad.gd) y el boton es la puerta de salida, que
		# hasta ahora no existia: sin teclado, esto era una ratonera. Diferido y en la capa, como en
		# mining.gd: el medidor es pequeño y la zona de pulsar tiene que seguir siendo la pantalla.
		_montar_pad.call_deferred()


func _montar_pad() -> void:
	var capa: Node = get_parent()
	if capa == null:
		return
	var pad: Control = _TOUCH_PAD.new()
	capa.add_child(pad)
	pad.anadir_boton("Salir", Color(0.42, 0.20, 0.22)).pressed.connect(_abandonar)


func terminado() -> bool:
	return _state == FINISHED


# Irse a medias ABANDONA el tronco: sales sin la madera, igual que si se hubiera rajado. Si no,
# bastaria con largarse cada vez que se fallara un hachazo y volver a entrar hasta clavarlos todos.
func _abandonar() -> void:
	talado_finished.emit(_result if _state == FINISHED else null, progreso_frac())
	queue_free()


func _process(delta: float) -> void:
	var pressed: bool = Input.is_action_pressed(&"recolectar")
	var edge: bool = pressed and not _press_was
	_press_was = pressed
	_ultimo_t = maxf(0.0, _ultimo_t - delta)

	if _state == FINISHED:
		if edge:
			talado_finished.emit(_result, progreso_frac())
			queue_free()
		return

	# En espera: la ventana no empieza a dar vueltas hasta que pulsas ESPACIO.
	if _state == READY:
		if edge:
			_state = RUNNING
		queue_redraw()
		return

	_pos += _vel * delta

	# La ventana ha REBASADO el tronco y no has pulsado: has perdido el tiempo.
	if not _tiempo_resuelto and _pos > TRONCO:
		_fallar("Se te va el compás")

	# Ha salido por la derecha: empieza la siguiente vuelta.
	if _pos >= 1.0:
		_nueva_vuelta()

	if edge and not _tiempo_resuelto:
		_hachazo()

	queue_redraw()


func _hachazo() -> void:
	if _pos <= TRONCO and _pos + _ancho >= TRONCO:
		_tiempo_resuelto = true
		_progreso += 1
		_ultimo = "¡Limpio!"
		_ultimo_t = 1.4
		_vel *= TEMPO_SUBE   # le has cogido el ritmo: el compas se acelera
		golpe.emit(Golpe.LIMPIO)
		if _progreso >= _hachazos:
			_terminar()
	else:
		golpe.emit(Golpe.FALLO)
		_fallar("A destiempo")


func _fallar(txt: String) -> void:
	_tiempo_resuelto = true
	_astillas += 1
	_ultimo = txt
	_ultimo_t = 1.4
	# Cada astilla te encoge la ventana: el siguiente tiempo es mas dificil que el anterior.
	_ancho = maxf(VENTANA_MIN, _ancho * VENTANA_ENCOGE)
	if _astillas >= ASTILLAS_ROTO:
		_terminar()


func _nueva_vuelta() -> void:
	# Entra por la izquierda del todo (fuera de la banda): asi la ves venir y puedes anticipar
	# el golpe, que es de lo que va esto.
	_pos = -_ancho
	_tiempo_resuelto = false



# Fraccion de la tarea que llegaste a COMPLETAR (0..1). La usa Game para pagar la excelia aunque
# falles: hasta el 29/07 la ganancia no miraba tus aciertos en absoluto, asi que abandonar a la
# primera pagaba lo mismo que terminarlo. Ver Game.ganar_recoleccion.
func progreso_frac() -> float:
	return clampf(float(_progreso) / float(maxi(1, _hachazos)), 0.0, 1.0)


func _terminar() -> void:
	_state = FINISHED
	var item := MaterialItem.new()
	item.data = _material
	if _astillas >= ASTILLAS_ROTO:
		item.calidad = MaterialItem.Calidad.ROTO
	elif _astillas == 0:
		item.calidad = MaterialItem.Calidad.INTACTO
	elif _astillas == 1:
		item.calidad = MaterialItem.Calidad.NORMAL
	else:
		item.calidad = MaterialItem.Calidad.DANADO
	_result = item
	queue_redraw()


# EL MEDIDOR, al lado del personaje (ver MedidorFaena para el estilo comun): el carril vertical con la
# raya del TRONCO a media altura y la franja que BAJA por el. Debajo, los hachazos (azul) y las astillas
# (rojo), y una linea de estado.
func _draw() -> void:
	var w: float = size.x
	MedidorFaena.panel(self, Rect2(Vector2.ZERO, size))
	var nombre: String = _material.nombre if _material != null else "Madera"
	MedidorFaena.texto(self, 20.0, 4.0, w - 8.0, nombre, 12)

	var cr := Rect2(w * 0.5 - 15.0, 32.0, 30.0, 176.0)
	MedidorFaena.carril(self, cr)
	if _state == RUNNING:
		# La VENTANA, recortada al carril: entra por arriba y sale por abajo.
		var y0: float = cr.position.y + maxf(_pos, 0.0) * cr.size.y
		var y1: float = cr.position.y + minf(_pos + _ancho, 1.0) * cr.size.y
		if y1 > y0:
			draw_rect(Rect2(cr.position.x, y0, cr.size.x, y1 - y0), MedidorFaena.AMBAR)
			draw_rect(Rect2(cr.position.x, y0, cr.size.x, 2.0), Color(1, 1, 1, 0.4))
	# El TRONCO: fijo, a media altura. Se dibuja SIEMPRE (es la referencia), sobresaliendo del carril.
	var ty: float = cr.position.y + TRONCO * cr.size.y
	draw_rect(Rect2(cr.position.x - 7.0, ty - 2.0, cr.size.x + 14.0, 4.0), Color.WHITE)

	MedidorFaena.marcas(self, w * 0.5, 218.0, _hachazos, _progreso, MedidorFaena.AZUL)
	MedidorFaena.marcas(self, w * 0.5, 232.0, ASTILLAS_ROTO, _astillas, MedidorFaena.ROJO)

	var estado: String
	var col: Color = MedidorFaena.TEXTO_SUAVE
	if _state == READY:
		estado = "ESPACIO: empezar"
	elif _state == RUNNING:
		estado = _ultimo if _ultimo_t > 0.0 else "Pulsa en la raya"
		if _ultimo_t > 0.0:
			col = MedidorFaena.TEXTO
	else:
		estado = "Se raja" if _result.se_pierde() else _result.calidad_texto()
		col = MedidorFaena.ROJO if _result.se_pierde() else MedidorFaena.AMBAR
	MedidorFaena.texto(self, 258.0, 4.0, w - 8.0, estado, 12, col)
