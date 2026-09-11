# ============================================================
#  harvest.gd
#  Minijuego de HERBORISTERIA (planta -> hoz -> DESTREZA). Ni carga ni marcador que
#  rebota: aqui hay PULSO. Cada tallo pasa UNA vez y no vuelve.
#
#  Por cada tallo, un marcador cruza la banda de un lado al otro, UNA SOLA pasada. En
#  medio hay una linea de corte con dos anillos:
#    - NUCLEO (fino)  -> CORTE LIMPIO: la pieza sale entera.
#    - BORDE          -> corte sucio: magullas la planta (+1 destrozo).
#    - Fuera, o dejar pasar el marcador sin pulsar -> TALLO DESTROZADO (+2) y la planta
#      se agita: los tallos que quedan pasan mas rapido.
#  No hay segunda oportunidad por tallo: si fallas, fallaste. Eso es lo que lo hace fino
#  y no un machaque de espacio como el del cristal.
#
#  La DESTREZA ensancha el nucleo y frena la pasada. Se crea por codigo (sin .tscn).
#
#  YA NO ES UNA PANTALLA: es un MEDIDOR vertical al lado del personaje mientras se le ve segar en el
#  mapa (ver scripts/world/faena.gd). El marcador BAJA por el carril hacia la raya de corte; la
#  mecanica de arriba es la misma, solo girada.
# ============================================================

extends Control

signal recoleccion_finished(item: MaterialItem, progreso: float)
# Para la FAENA: cada tajo que se da. Dejar pasar el tallo sin pulsar NO lo emite (no hay tajo).
enum Golpe { FALLO, LIMPIO, SUCIO }
signal golpe(tipo: int)

enum { READY, RUNNING, FINISHED }

var _material: MaterialData = null
var _cortes: int = 3
var _nucleo: float = 0.06   # semiancho del corte limpio (fraccion de la banda)
var _borde: float = 0.13    # semiancho del corte sucio
var _vel: float = 0.7       # pasadas por segundo

var _corte_actual: int = 0
var _limpios: int = 0   # cortes que han salido BIEN (para la excelia parcial, ver progreso_frac)
var _destrozo: int = 0
var _marker: float = 0.0
var _linea: float = 0.5     # donde esta el corte en esta pasada
var _ultimo: String = ""
var _ultimo_t: float = 0.0   # cuanto le queda en pantalla a ese texto
var _state: int = READY   # empieza en espera: no arranca hasta pulsar ESPACIO
var _result: MaterialItem = null
var _press_was: bool = true   # true al abrir: exige una pulsacion NUEVA para empezar

# Cuanto se acelera la planta por cada tallo que destrozas (se pone nerviosa).
const AGITACION := 1.15
# Destrozo al que la pieza ya no vale nada.
const DESTROZO_ROTO := 5


func setup(material: MaterialData, cortes: int, nucleo: float, borde: float, vel: float) -> void:
	_material = material
	_cortes = maxi(1, cortes)
	_nucleo = nucleo
	_borde = borde
	_vel = vel


const _TOUCH_PAD := preload("res://scripts/ui/touch_pad.gd")


func _ready() -> void:
	size = Vector2(MedidorFaena.ANCHO, MedidorFaena.ALTO)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nuevo_tallo()
	if Tactil.activo:
		# La pantalla entera es la hoz (ver touch_pad.gd) y el boton es la puerta de salida, que
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


# Irse a medias ABANDONA la planta: sales sin nada, igual que si hubiera quedado hecha jirones. Si
# no, bastaria con largarse en cuanto se fallara un corte y repetir hasta cortarlos todos limpios.
func _abandonar() -> void:
	recoleccion_finished.emit(_result if _state == FINISHED else null, progreso_frac())
	queue_free()


func _process(delta: float) -> void:
	var pressed: bool = Input.is_action_pressed(&"recolectar")
	var edge: bool = pressed and not _press_was
	_press_was = pressed
	_ultimo_t = maxf(0.0, _ultimo_t - delta)

	if _state == FINISHED:
		if edge:
			recoleccion_finished.emit(_result, progreso_frac())
			queue_free()
		return

	# En espera: el marcador no empieza a pasar hasta que pulsas ESPACIO.
	if _state == READY:
		if edge:
			_state = RUNNING
		queue_redraw()
		return

	_marker += _vel * delta
	if _marker >= 1.0:
		# El marcador ha cruzado entero y no has pulsado: el tallo se pierde.
		_resolver(-1.0)
		return

	if edge:
		_resolver(_marker)

	queue_redraw()


# d = distancia del marcador a la linea de corte; d < 0 -> ni lo has intentado.
func _resolver(pos: float) -> void:
	if pos < 0.0:
		_fallo("Se te pasa")
	else:
		var d: float = absf(pos - _linea)
		if d <= _nucleo:
			_limpios += 1
			_ultimo = "¡Limpio!"
			_ultimo_t = 1.4
			golpe.emit(Golpe.LIMPIO)
		elif d <= _borde:
			_destrozo += 1
			_ultimo = "Sucio: magulla"
			_ultimo_t = 1.4
			golpe.emit(Golpe.SUCIO)
		else:
			golpe.emit(Golpe.FALLO)
			_fallo("En falso")

	_siguiente()


func _fallo(txt: String) -> void:
	_destrozo += 2
	_ultimo = txt
	_ultimo_t = 1.4
	_vel *= AGITACION   # la planta se agita: lo que queda va mas rapido


func _siguiente() -> void:
	_corte_actual += 1
	if _destrozo >= DESTROZO_ROTO or _corte_actual >= _cortes:
		_terminar()
		return
	_nuevo_tallo()


func _nuevo_tallo() -> void:
	_marker = 0.0
	# La linea nunca cae pegada al borde de la banda: siempre te da tiempo a reaccionar.
	_linea = randf_range(0.25, 0.85)



# Fraccion de la tarea que llegaste a COMPLETAR (0..1). La usa Game para pagar la excelia aunque
# falles: hasta el 29/07 la ganancia no miraba tus aciertos en absoluto, asi que abandonar a la
# primera pagaba lo mismo que terminarlo. Ver Game.ganar_recoleccion.
func progreso_frac() -> float:
	return clampf(float(_limpios) / float(maxi(1, _cortes)), 0.0, 1.0)


func _terminar() -> void:
	_state = FINISHED
	var item := MaterialItem.new()
	item.data = _material
	if _destrozo >= DESTROZO_ROTO:
		item.calidad = MaterialItem.Calidad.ROTO
	elif _destrozo == 0:
		item.calidad = MaterialItem.Calidad.INTACTO
	elif _destrozo <= 2:
		item.calidad = MaterialItem.Calidad.NORMAL
	else:
		item.calidad = MaterialItem.Calidad.DANADO
	_result = item
	queue_redraw()


# EL MEDIDOR, al lado del personaje (ver MedidorFaena para el estilo comun): el carril vertical con la
# raya de corte y sus dos franjas (el nucleo del corte limpio en verde vivo, el borde del sucio mas
# apagado), y el marcador que BAJA de una pasada. Debajo, los tallos (azul) y el destrozo (rojo).
const VERDE_VIVO := Color(0.62, 0.95, 0.42)
const VERDE_BORDE := Color(0.42, 0.66, 0.30, 0.65)

func _draw() -> void:
	var w: float = size.x
	MedidorFaena.panel(self, Rect2(Vector2.ZERO, size))
	var nombre: String = _material.nombre if _material != null else "Planta"
	MedidorFaena.texto(self, 20.0, 4.0, w - 8.0, nombre, 12)

	var cr := Rect2(w * 0.5 - 15.0, 32.0, 30.0, 176.0)
	MedidorFaena.carril(self, cr)
	if _state == RUNNING:
		var yb: float = cr.position.y + (_linea - _borde) * cr.size.y
		draw_rect(Rect2(cr.position.x, yb, cr.size.x, 2.0 * _borde * cr.size.y), VERDE_BORDE)
		var yn: float = cr.position.y + (_linea - _nucleo) * cr.size.y
		draw_rect(Rect2(cr.position.x, yn, cr.size.x, 2.0 * _nucleo * cr.size.y), VERDE_VIVO)
		# La raya de corte, fina, en el centro exacto.
		var yl: float = cr.position.y + _linea * cr.size.y
		draw_rect(Rect2(cr.position.x - 3.0, yl - 1.0, cr.size.x + 6.0, 2.0), Color(1, 1, 1, 0.55))
		# El marcador: la hoja de la hoz que baja por el tallo, sobresaliendo del carril.
		var ym: float = cr.position.y + _marker * cr.size.y
		draw_rect(Rect2(cr.position.x - 7.0, ym - 2.0, cr.size.x + 14.0, 4.0), Color.WHITE)

	MedidorFaena.marcas(self, w * 0.5, 218.0, _cortes, _corte_actual, MedidorFaena.AZUL)
	MedidorFaena.marcas(self, w * 0.5, 232.0, DESTROZO_ROTO, _destrozo, MedidorFaena.ROJO)

	var estado: String
	var col: Color = MedidorFaena.TEXTO_SUAVE
	if _state == READY:
		estado = "ESPACIO: empezar"
	elif _state == RUNNING:
		estado = _ultimo if _ultimo_t > 0.0 else "Pulsa en la raya"
		if _ultimo_t > 0.0:
			col = MedidorFaena.TEXTO
	else:
		estado = "Hecha jirones" if _result.se_pierde() else _result.calidad_texto()
		col = MedidorFaena.ROJO if _result.se_pierde() else MedidorFaena.AMBAR
	MedidorFaena.texto(self, 258.0, 4.0, w - 8.0, estado, 12, col)
