# ============================================================
#  mining.gd
#  Minijuego de MINERIA (veta -> pico -> FUERZA). Nada que ver con el del cristal:
#  aqui no hay marcador que rebota, hay una CARGA que tu decides cuando soltar.
#
#  MANTIENES ESPACIO: la barra de carga sube. SUELTAS: golpeas.
#    - Sueltas dentro de la franja optima -> GOLPE BUENO: la veta cede (+1 de progreso).
#    - Te quedas corto             -> GOLPE FLOJO: el pico rebota. NO avanza nada.
#    - Te pasas (o la carga llena)  -> GOLPE BRUTO: la veta cede igual, pero AGRIETAS el
#      mineral (+1 grieta). Eso es lo que te destroza el botin.
#  Y la veta NO aguanta golpes infinitos: tienes un MARGEN de golpes por encima de los que
#  hacen falta, y al pasarte la roca se viene abajo entera (pieza rota). Sin ese margen, el
#  golpe flojo seria gratis y bastaba con dar toquecitos hasta sacar la pieza intacta.
#  La franja se re-sortea tras cada golpe: la veta no cede dos veces por el mismo sitio.
#
#  La FUERZA no golpea por ti: hace la franja mas ANCHA y mas BAJA (un brazo fuerte no
#  necesita cargar tanto) y baja los golpes necesarios. Sigues teniendo que soltar tu.
#  Se crea por codigo (sin .tscn), como extraction.gd.
#
#  YA NO ES UNA PANTALLA: es un MEDIDOR pequeño que va al lado del personaje mientras se le ve picar
#  en el mapa (ver scripts/world/faena.gd, que lo coloca y anima el muñeco con las señales de abajo).
#  La mecanica de arriba no se ha tocado: solo como se ve.
# ============================================================

extends Control

signal mineria_finished(item: MaterialItem, progreso: float)
# Para la FAENA: cada golpe (con como ha salido) y la carga, que es lo alto que va el pico.
enum Golpe { FLOJO, LIMPIO, BRUTO }
signal golpe(tipo: int)

enum { READY, RUNNING, FINISHED }

var _material: MaterialData = null
var _golpes_necesarios: int = 3
var _opt_ini: float = 0.5      # inicio de la franja optima EN ESTE GOLPE (0..1)
var _opt_base: float = 0.5     # donde la pone la dificultad; el sorteo se mueve ALREDEDOR
var _opt_ancho: float = 0.22
var _carga_vel: float = 1.0    # de 0 a 1 en 1/_carga_vel segundos

var _carga: float = 0.0
var _cargando: bool = false
var _progreso: float = 0.0
var _grietas: int = 0
var _golpes: int = 0
var _ultimo: String = ""       # texto del ultimo golpe (para el HUD)
var _ultimo_t: float = 0.0     # cuanto le queda en pantalla a ese texto
var _state: int = READY        # empieza en espera: no arranca hasta pulsar ESPACIO
var _result: MaterialItem = null
var _press_was: bool = false

# Golpes de MARGEN por encima de los necesarios: lo que la veta aguanta antes de venirse
# abajo. Es lo que le pone precio a fallar (y lo que impide sacar la pieza a toquecitos).
const GOLPES_MARGEN := 4
# Grietas a las que la pieza se parte del todo.
const GRIETAS_ROTO := 3


func setup(material: MaterialData, golpes: int, opt_ini: float, opt_ancho: float,
		carga_vel: float) -> void:
	_material = material
	_golpes_necesarios = maxi(1, golpes)
	_opt_ini = opt_ini
	_opt_base = opt_ini
	_opt_ancho = opt_ancho
	_carga_vel = carga_vel


const _TOUCH_PAD := preload("res://scripts/ui/touch_pad.gd")


func _ready() -> void:
	size = Vector2(MedidorFaena.ANCHO, MedidorFaena.ALTO)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sortear_franja()
	if Tactil.activo:
		# Con los dedos la pantalla entera es el pico (ver touch_pad.gd) y hace falta una PUERTA:
		# hasta ahora de aqui no se salia mas que picando, y sin teclado eso es una ratonera.
		# El pad va en la CAPA y no dentro del medidor: el medidor es pequeño y la zona de pulsar
		# tiene que seguir siendo la pantalla entera (lo mismo hace la pesca).
		# DIFERIDO, y el boton con el: la capa esta montando a sus hijos en este instante y no admite
		# otro, y el boton se cuelga de un contenedor que el pad crea en SU _ready (pedirselo antes
		# reventaba con "add_child on a null value" al darle a la veta).
		_montar_pad.call_deferred()


func _montar_pad() -> void:
	var capa: Node = get_parent()
	if capa == null:
		return
	var pad: Control = _TOUCH_PAD.new()
	capa.add_child(pad)
	pad.anadir_boton("Salir", Color(0.42, 0.20, 0.22)).pressed.connect(_abandonar)


# Lo que lee la faena para alzar el pico mientras cargas.
func carga() -> float:
	return _carga if _cargando else 0.0


func terminado() -> bool:
	return _state == FINISHED


# Largarse a medias ABANDONA la veta: sales sin la pieza, igual que si se hubiera roto. Sin ese
# precio bastaria con salirse cada vez que la franja cayera mal y volver a entrar hasta sacarla
# perfecta. Si la veta ya estaba resuelta, el boton solo recoge lo que hubiera.
func _abandonar() -> void:
	mineria_finished.emit(_result if _state == FINISHED else null, progreso_frac())
	queue_free()


func _process(delta: float) -> void:
	var pressed: bool = Input.is_action_pressed(&"recolectar")
	_ultimo_t = maxf(0.0, _ultimo_t - delta)

	if _state == FINISHED:
		# Se sale con una pulsacion NUEVA (no con la que acabo de romper la veta).
		if pressed and not _press_was:
			mineria_finished.emit(_result, progreso_frac())
			queue_free()
		_press_was = pressed
		return

	# En espera: arranca al SOLTAR el primer ESPACIO (pulsar-y-soltar). Empezar al soltar evita
	# que el toque de arranque cuente como un golpe flojo por accidente (la mineria carga MIENTRAS
	# pulsas). Tras arrancar, ya cargas normal con la siguiente pulsacion.
	if _state == READY:
		if _press_was and not pressed:
			_state = RUNNING
		_press_was = pressed
		queue_redraw()
		return

	if pressed:
		_cargando = true
		_carga += _carga_vel * delta
		if _carga >= 1.0:
			# Cargar hasta reventar es una decision, y se paga: golpe bruto forzado.
			_carga = 1.0
			_golpear()
	elif _cargando:
		_golpear()   # has soltado: ahi va el golpe

	_press_was = pressed
	queue_redraw()


func _golpear() -> void:
	_cargando = false
	_golpes += 1
	var tipo: int = Golpe.LIMPIO
	if _carga < _opt_ini:
		_ultimo = "Flojo: rebota"   # no avanza: has gastado un golpe y ya
		tipo = Golpe.FLOJO
	elif _carga <= _opt_ini + _opt_ancho:
		_progreso += 1.0
		_ultimo = "¡Limpio!"
	else:
		_progreso += 1.0
		_grietas += 1
		_ultimo = "Bruto: se agrieta"
		tipo = Golpe.BRUTO
	_ultimo_t = 1.4
	golpe.emit(tipo)

	_carga = 0.0
	_sortear_franja()

	# ¿Ya la tienes? (esto va PRIMERO: el golpe que la abre cuenta aunque sea el ultimo)
	if _progreso >= float(_golpes_necesarios):
		_terminar()
		return
	# Ya esta agrietada del todo, o la has machacado tanto que se viene abajo: escombro.
	if _grietas >= GRIETAS_ROTO or _golpes >= _golpes_max():
		_grietas = GRIETAS_ROTO   # se derrumba: no hay pieza que sacar
		_terminar()


# Golpes que aguanta la veta antes de derrumbarse.
func _golpes_max() -> int:
	return _golpes_necesarios + GOLPES_MARGEN



# Fraccion de la tarea que llegaste a COMPLETAR (0..1). La usa Game para pagar la excelia aunque
# falles: hasta el 29/07 la ganancia no miraba tus aciertos en absoluto, asi que abandonar a la
# primera pagaba lo mismo que terminarlo. Ver Game.ganar_recoleccion.
func progreso_frac() -> float:
	return clampf(_progreso / float(maxi(1, _golpes_necesarios)), 0.0, 1.0)


func _terminar() -> void:
	_state = FINISHED
	var item := MaterialItem.new()
	item.data = _material
	if _grietas >= GRIETAS_ROTO:
		item.calidad = MaterialItem.Calidad.ROTO
	elif _grietas == 0:
		item.calidad = MaterialItem.Calidad.INTACTO
	elif _grietas == 1:
		item.calidad = MaterialItem.Calidad.NORMAL
	else:
		item.calidad = MaterialItem.Calidad.DANADO
	_result = item
	queue_redraw()


func _sortear_franja() -> void:
	# El ancho y la altura MEDIA los fija la dificultad (Game); aqui la franja solo se mueve
	# un poco arriba y abajo de esa media. Se sortea alrededor de _opt_base y NO de la franja
	# anterior: si no, cada golpe la empujaria un poco mas y acabaria pegada a un extremo.
	var margen: float = 0.12
	var ini: float = _opt_base + randf_range(-margen, margen)
	_opt_ini = clampf(ini, 0.05, 1.0 - _opt_ancho - 0.02)


# EL MEDIDOR, al lado del personaje (ver MedidorFaena para el estilo comun):
#   arriba el nombre de la veta; en medio el CARRIL DE CARGA vertical (0 abajo), con la franja buena
#   en ambar y lo que te pasa en rojo; debajo, las marcas de lo que ha cedido la veta (azul) y de las
#   grietas (rojo), y una linea de estado.
func _draw() -> void:
	var w: float = size.x
	MedidorFaena.panel(self, Rect2(Vector2.ZERO, size))
	var nombre: String = _material.nombre if _material != null else "Veta"
	MedidorFaena.texto(self, 20.0, 4.0, w - 8.0, nombre, 12)

	var cr := Rect2(w * 0.5 - 15.0, 32.0, 30.0, 176.0)
	MedidorFaena.carril(self, cr)
	# Lo que te PASA (encima de la franja) en rojo tenue: es lo que agrieta la pieza.
	var tope_franja: float = cr.position.y + cr.size.y * (1.0 - _opt_ini - _opt_ancho)
	draw_rect(Rect2(cr.position, Vector2(cr.size.x, tope_franja - cr.position.y)),
		Color(MedidorFaena.ROJO, 0.30))
	# La franja buena.
	var franja := Rect2(cr.position.x, tope_franja, cr.size.x, cr.size.y * _opt_ancho)
	draw_rect(franja, MedidorFaena.AMBAR)
	draw_rect(Rect2(franja.position, Vector2(franja.size.x, 2.0)), Color(1, 1, 1, 0.4))
	# La carga: una columna que sube desde abajo y una raya blanca que la remata, que sobresale del
	# carril por los dos lados para que se lea aunque la columna caiga dentro de la franja.
	var c: float = carga()
	if c > 0.0:
		var cy: float = cr.position.y + cr.size.y * (1.0 - c)
		draw_rect(Rect2(cr.position.x + 5.0, cy, cr.size.x - 10.0, cr.end.y - cy), Color(0.95, 0.93, 0.86, 0.55))
		draw_rect(Rect2(cr.position.x - 7.0, cy - 2.0, cr.size.x + 14.0, 4.0), Color.WHITE)

	# Lo que ha cedido la veta y las grietas que lleva.
	MedidorFaena.marcas(self, w * 0.5, 218.0, _golpes_necesarios, int(_progreso), MedidorFaena.AZUL)
	MedidorFaena.marcas(self, w * 0.5, 232.0, GRIETAS_ROTO, _grietas, MedidorFaena.ROJO)

	var estado: String
	var col: Color = MedidorFaena.TEXTO_SUAVE
	if _state == READY:
		estado = "ESPACIO: empezar"
	elif _state == RUNNING:
		estado = _ultimo if _ultimo_t > 0.0 else "Mantén y suelta"
		if _ultimo_t > 0.0:
			col = MedidorFaena.TEXTO
	else:
		estado = "Escombro" if _result.se_pierde() else _result.calidad_texto()
		col = MedidorFaena.ROJO if _result.se_pierde() else MedidorFaena.AMBAR
	MedidorFaena.texto(self, 258.0, 4.0, w - 8.0, estado, 12, col)
