# ============================================================
#  extraction.gd
#  Minijuego de EXTRACCION del cristal (Fase 5). Barra horizontal con una
#  ZONA verde en posicion ALEATORIA; un marcador la recorre y pulsas ESPACIO
#  cuando esta dentro. Pulsas un TOTAL fijo de veces (N); cada pulsacion es
#  acierto o fallo, y cada ACIERTO acelera un poco el marcador.
#  La calidad sale de la PROPORCION de fallos (asi vale para 2, 3, 4, 5...):
#    0 fallos = INTACTO, <=1/3 = NORMAL, <=2/3 = DAÑADO, mas = ROTO.
#  El CUCHILLO de rareza alta perdona los primeros fallos (ver _perdones): no cuentan para nada.
#  Se crea por codigo (sin .tscn). Devuelve el Cristal por la señal.
# ============================================================

extends Control

signal extraction_finished(cristal: Cristal, progreso: float)
# Para la FAENA (ver scripts/world/faena.gd): cada corte, con como ha salido. SALVADO es el fallo que
# perdona el cuchillo: se ve como un fallo, pero el cristal no se entera.
enum Golpe { FALLO, ACIERTO, SALVADO }
signal golpe(tipo: int)

enum { READY, RUNNING, FINISHED }

var _categoria: int = 1
var _presses: int = 3          # pulsaciones TOTALES (aciertes o falles)
var _zone_ratio: float = 0.13  # ancho de la zona (fraccion de la barra)
var _marker_speed: float = 0.8 # recorrido por segundo (0..1)
var _speed_step: float = 0.3   # cuanto acelera por cada acierto

# TECHO de la velocidad del marcador. Sin el, los aciertos lo aceleran sin fin (_speed_step
# por acierto) y en las extracciones largas el marcador acaba yendo tan rapido que se ve
# BORROSO: salta decenas de pixeles por frame aunque el juego vaya a 144 fps clavados. El
# reto tiene que estar en la ZONA (que se estrecha con la dificultad), no en perseguir con la
# vista algo que ya no se puede seguir. Game lo cape tambien de entrada (EXTRACTION_MARKER_MAX).
const VEL_MAX := 1.4

var _done: int = 0
var _misses: int = 0
# Fallos que el CUCHILLO aun te perdona (Upgrades.CUCHILLO_PERDONA: Epico+ uno, Obra maestra y
# Pristino dos). Un fallo perdonado NO cuenta en _misses: ni baja la calidad ni rompe el cristal,
# ni acelera el marcador (eso solo lo hacen los aciertos). Solo se ve en el texto.
var _perdones: int = 0
var _salvados: int = 0
var _aviso_salvado: float = 0.0   # segundos que queda en pantalla el "¡el cuchillo lo salva!"
var _marker: float = 0.0
var _marker_dir: float = 1.0
var _zone_start: float = 0.0
var _state: int = READY   # empieza en espera: no arranca hasta que pulsas ESPACIO
var _result: Cristal = null
var _press_was: bool = true   # true al abrir: exige una pulsacion NUEVA para empezar (no la de abrir)
# El CADAVER del que extraigo. SIN tipar a proposito (misma trampa que net.gd): esta pantalla cuelga
# de get_tree().root, asi que SOBREVIVE al cambio de escena, pero el cuerpo se libera con el piso
# viejo. Si otro me saca del piso a media extraccion, hay que auto-cancelar (ver _process) o el
# minijuego seguiria corriendo sobre una instancia liberada y reventaria al emitir su señal.
var _corpse = null
var _tiene_corpse := false   # ¿me pasaron cadaver? (distingue "no habia" de "lo liberaron")


func setup(categoria: int, presses: int, zone_ratio: float,
		marker_speed: float, speed_step: float, corpse = null, perdones: int = 0) -> void:
	_categoria = categoria
	_perdones = maxi(0, perdones)
	_presses = presses
	_zone_ratio = zone_ratio
	_marker_speed = marker_speed
	_speed_step = speed_step
	_corpse = corpse
	_tiene_corpse = corpse != null


const _TOUCH_PAD := preload("res://scripts/ui/touch_pad.gd")


func _ready() -> void:
	size = Vector2(MedidorFaena.ANCHO, MedidorFaena.ALTO)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_randomize_zone()
	if Tactil.activo:
		# La pantalla entera es el cuchillo (ver touch_pad.gd) y el boton es la puerta de salida, que
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


# Dejar el cuerpo a medias lo CONSUME, igual que si el cristal se hubiera partido: sale por el mismo
# camino que la auto-cancelacion de arriba (cristal null), que en multijugador es ademas el unico que
# suelta bien el candado del cadaver.
func _abandonar() -> void:
	extraction_finished.emit(_result if _state == FINISHED else null, progreso_frac())
	queue_free()


func _process(delta: float) -> void:
	# AUTO-CANCELACION: si me han sacado del piso (el cadaver murio con la escena vieja), cierro sin
	# premio. Emitir null hace que Game._on_extraction_finished no otorgue cristal y siga su cierre
	# de siempre (salir_modal, esconder_mundo) — mismo camino que un fin normal, sin puntos sueltos.
	if _tiene_corpse and not is_instance_valid(_corpse):
		_tiene_corpse = false
		extraction_finished.emit(null, 0.0)
		queue_free()
		return

	var pressed: bool = Input.is_action_pressed(&"recolectar")
	var edge: bool = pressed and not _press_was
	_press_was = pressed
	_aviso_salvado = maxf(0.0, _aviso_salvado - delta)

	if _state == FINISHED:
		if edge:
			extraction_finished.emit(_result, progreso_frac())
			queue_free()
		elif _aviso_salvado > 0.0:
			queue_redraw()   # que el aviso del cuchillo se apague aunque la pulsacion fuese la ultima
		return

	# En espera: el marcador no se mueve hasta que pulsas ESPACIO para empezar.
	if _state == READY:
		if edge:
			_state = RUNNING
		queue_redraw()
		return

	_marker += _marker_dir * _marker_speed * delta
	if _marker >= 1.0:
		_marker = 1.0
		_marker_dir = -1.0
	elif _marker <= 0.0:
		_marker = 0.0
		_marker_dir = 1.0

	if edge:
		_attempt()

	queue_redraw()


func _attempt() -> void:
	_done += 1
	if _marker >= _zone_start and _marker <= _zone_start + _zone_ratio:
		# Acierto: acelera el marcador, pero nunca por encima del techo (ver VEL_MAX).
		_marker_speed = minf(_marker_speed + _speed_step, VEL_MAX)
		golpe.emit(Golpe.ACIERTO)
	elif _perdones > 0:
		_perdones -= 1
		_salvados += 1
		_aviso_salvado = 1.2
		golpe.emit(Golpe.SALVADO)
	else:
		_misses += 1
		golpe.emit(Golpe.FALLO)
	_randomize_zone()
	# Si ya has fallado lo suficiente (roto seguro), se acaba YA.
	if _misses >= mini(3, _presses):
		_finish()
		return
	if _done >= _presses:
		_finish()



# Fraccion de la tarea que llegaste a COMPLETAR (0..1). La usa Game para pagar la excelia aunque
# falles. _done cuenta TODAS las pulsaciones (aciertes o no), asi que los aciertos son la resta.
# Ver Game.ganar_recoleccion.
func progreso_frac() -> float:
	return clampf(float(_done - _misses) / float(maxi(1, _presses)), 0.0, 1.0)


func _finish() -> void:
	_state = FINISHED
	var c := Cristal.new()
	c.categoria = _categoria
	# Calidad por NUMERO de fallos (no proporcional): 0 intacto, 1 normal,
	# 2 dañado, y ROTO a los 3 fallos (o antes si pide pocas pulsaciones:
	# roto = min(3, pulsaciones), asi con 2 pulsaciones roto a los 2, con 1 a 1).
	var roto_en: int = mini(3, _presses)
	if _misses >= roto_en:
		c.calidad = Cristal.Calidad.ROTO
	elif _misses == 0:
		c.calidad = Cristal.Calidad.INTACTO
	elif _misses == 1:
		c.calidad = Cristal.Calidad.NORMAL
	else:
		c.calidad = Cristal.Calidad.DANADO
	_result = c
	queue_redraw()


func _randomize_zone() -> void:
	_zone_start = randf() * (1.0 - _zone_ratio)


# EL MEDIDOR, al lado del personaje (ver MedidorFaena para el estilo comun): el carril vertical con la
# zona buena en el violeta de los cristales y el marcador que sube y baja. Debajo, las pulsaciones que
# llevas (azul), los fallos (rojo) y, si el cuchillo perdona, los perdones que le quedan (ambar).
const VIOLETA := Color(0.70, 0.48, 0.95)

func _draw() -> void:
	var w: float = size.x
	MedidorFaena.panel(self, Rect2(Vector2.ZERO, size))
	MedidorFaena.texto(self, 20.0, 4.0, w - 8.0, "Cristal T%d" % _categoria, 12)

	var cr := Rect2(w * 0.5 - 15.0, 32.0, 30.0, 176.0)
	MedidorFaena.carril(self, cr)
	var zona := Rect2(cr.position.x, cr.position.y + _zone_start * cr.size.y,
		cr.size.x, _zone_ratio * cr.size.y)
	draw_rect(zona, VIOLETA)
	draw_rect(Rect2(zona.position, Vector2(zona.size.x, 2.0)), Color(1, 1, 1, 0.45))
	# Marcador GRUESO y sobresaliendo del carril: en movimiento, una raya fina se lee mucho peor.
	var my: float = cr.position.y + _marker * cr.size.y
	draw_rect(Rect2(cr.position.x - 7.0, my - 2.0, cr.size.x + 14.0, 4.0), Color.WHITE)

	MedidorFaena.marcas(self, w * 0.5, 218.0, _presses, _done - _misses, MedidorFaena.AZUL)
	MedidorFaena.marcas(self, w * 0.5, 232.0, mini(3, _presses), _misses, MedidorFaena.ROJO)
	if _perdones > 0:
		MedidorFaena.marcas(self, w * 0.5, 244.0, _perdones, _perdones, MedidorFaena.AMBAR, 5.0)

	var estado: String
	var col: Color = MedidorFaena.TEXTO_SUAVE
	if _aviso_salvado > 0.0:
		estado = "¡El cuchillo salva!"
		col = MedidorFaena.AMBAR
	elif _state == READY:
		estado = "ESPACIO: empezar"
	elif _state == RUNNING:
		estado = "Pulsa en la zona"
	else:
		estado = "Roto: perdido" if _result.se_pierde() else _result.calidad_texto()
		col = MedidorFaena.ROJO if _result.se_pierde() else MedidorFaena.AMBAR
	MedidorFaena.texto(self, 260.0, 4.0, w - 8.0, estado, 12, col)
