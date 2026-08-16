# ============================================================
#  cuadro_equipo.gd
#  EL EQUIPO DE UNA PERSONA, a la derecha de sus tres barras. Alterna cada 5 s entre la ARMADURA
#  (el monigote de cinco piezas) y las ARMAS (las dos manos), y cada cosa va teñida por SU desgaste.
#
#  POR QUE EXISTE: en el playtest un tanque jugo media expedicion con cuatro piezas ROTAS y nadie
#  pudo verlo, porque la durabilidad solo se miraba entrando pieza a pieza en el menu. El aviso al
#  cruzar el 25% y al romperse (ver Game._avisar_durabilidad) avisa EN EL MOMENTO; esto es lo otro
#  que hacia falta: poder MIRAR como esta todo el grupo sin abrir nada.
#
#  La regla: el color lo dice todo de un vistazo, y los numeros salen SOLO al pasar el raton.
#  Blanco = entera, y de ahi a amarillo, naranja y rojo segun se rompe (Game.color_desgaste).
# ============================================================

extends Control
class_name CuadroEquipo

const SEG_POR_PAGINA := 5.0
const PAG_ARMADURA := 0
const PAG_ARMAS := 1

# Los cinco pares (slot, tabla) del monigote. En este orden se pintan, uno encima de otro, sobre la
# misma rejilla: juntos forman la figura.
const PIEZAS := [
	["casco", IconosEquipo.ARM_CASCO],
	["pecho", IconosEquipo.ARM_PECHO],
	["manos", IconosEquipo.ARM_MANOS],
	["pantalones", IconosEquipo.ARM_PANTALONES],
	["botas", IconosEquipo.ARM_BOTAS],
]

var pj: PersonajeData = null
# El raton encima CONGELA el ciclo: si no, la pagina te cambia justo mientras lees el popup.
var _raton_encima := false
# La pagina que se quedo puesta al entrar el raton (para que al congelar no salte a otra).
var _pagina_fija: int = -1
var _firma: String = ""   # lo ultimo pintado; sin esto se repintaria en cada frame para nada


func _ready() -> void:
	# Atrapa el raton para poder dar el tooltip, pero el CLIC se reenvia: la tarjeta entera del
	# personaje es el boton de cambiar de lider (ver player._rehacer_barras), y comerse ese trozo
	# dejaria un agujero muerto justo en medio de la fila.
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func():
		_raton_encima = true
		_pagina_fija = _pagina_del_reloj()
		queue_redraw())
	mouse_exited.connect(func():
		_raton_encima = false
		_pagina_fija = -1
		queue_redraw())


func _gui_input(event: InputEvent) -> void:
	# El toque/clic no es mio: que siga su camino hasta la tarjeta, que cambia de lider.
	var toque: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if toque:
		var padre := get_parent() as Control
		if padre != null:
			padre.gui_input.emit(event)


# La pagina que toca por reloj. Es el reloj DEL SISTEMA y no un contador propio, asi que todas las
# columnas del grupo cambian A LA VEZ: cada una por su cuenta se veria como un parpadeo desordenado.
func _pagina_del_reloj() -> int:
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	return int(t / SEG_POR_PAGINA) % 2


func _pagina() -> int:
	return _pagina_fija if _raton_encima and _pagina_fija >= 0 else _pagina_del_reloj()


# Corre en cada frame (lo llama el refresco de barras): solo se repinta cuando CAMBIA algo. Es el
# mismo criterio que los chips de estado, y por el mismo motivo.
func refrescar() -> void:
	if pj == null:
		return
	var f: String = "%d|" % _pagina()
	for par in PIEZAS:
		f += "%d," % roundi(Game.durabilidad_slot(String(par[0]), pj) * 100.0)
	f += "%s,%s|%d,%d" % [
		_nombre_de(pj.equipped_main), _nombre_de(pj.equipped_off),
		roundi(Game.durabilidad_slot("main", pj) * 100.0),
		roundi(Game.durabilidad_slot("off", pj) * 100.0)]
	if f == _firma:
		return
	_firma = f
	tooltip_text = _texto_tooltip()
	queue_redraw()


func _nombre_de(item: Resource) -> String:
	return "-" if item == null else String(item.get("nombre"))


# El popup: AQUI y solo aqui salen los numeros, y salen TODOS (armadura y armas), no solo los de la
# pagina que se vea en ese momento. Es lo que convierte el cuadro en algo consultable.
func _texto_tooltip() -> String:
	var L: Array = ["%s — durabilidad" % pj.nombre, ""]
	for par in PIEZAS:
		var slot: String = String(par[0])
		var it: Resource = pj.get("equipped_" + slot) as Resource
		L.append("%-11s %s" % [slot.capitalize() + ":", _linea_dur(it, slot)])
	L.append("")
	L.append("%-11s %s" % ["Principal:", _linea_dur(pj.equipped_main, "main")])
	L.append("%-11s %s" % ["Secundaria:", _linea_dur(pj.equipped_off, "off")])
	return "\n".join(L)


func _linea_dur(item: Resource, slot: String) -> String:
	if item == null:
		return "(vacío)"
	var frac: float = Game.durabilidad_slot(slot, pj)
	return "%s  %s" % [String(item.get("nombre")),
		"ROTA" if frac <= 0.0 else "%d%%" % roundi(frac * 100.0)]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.11, 0.14, 0.80), true)
	if pj != null:
		if _pagina() == PAG_ARMADURA:
			_dibujar_armadura()
		else:
			_dibujar_armas()
	# El borde, encima de todo, y mas claro con el raton puesto: es el acuse de "esto se puede mirar".
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.75, 0.78, 0.85, 0.9 if _raton_encima else 0.55),
		false, 1.0)


# Las cinco piezas, cada una en su sitio de la MISMA rejilla y con SU color: asi el monigote se lee
# de un vistazo y ademas se ve cual es la que esta rota.
func _dibujar_armadura() -> void:
	var caja := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	for par in PIEZAS:
		var slot: String = String(par[0])
		var puesta: bool = pj.get("equipped_" + slot) != null
		IconosEquipo.rejilla(self, par[1] as Array, caja,
			Game.color_desgaste(Game.durabilidad_slot(slot, pj)), not puesta)


# Las DOS manos. Un arma a dos manos es la excepcion: ocupa el cuadro entero y la secundaria se
# queda en silueta, que es lo que hace que "se note" que es un armatoste sin leer nada.
func _dibujar_armas() -> void:
	var main: Resource = pj.equipped_main
	var dos_manos: bool = main is WeaponData and (main as WeaponData).dos_manos
	if dos_manos:
		IconosEquipo.rejilla(self, IconosEquipo.tabla_de_mano(main),
			Rect2(Vector2(2, 2), size - Vector2(4, 4)),
			Game.color_desgaste(Game.durabilidad_slot("main", pj)), false)
		return
	var media: float = size.x * 0.5
	IconosEquipo.rejilla(self, IconosEquipo.tabla_de_mano(main),
		Rect2(Vector2(2, 2), Vector2(media - 3.0, size.y - 4.0)),
		Game.color_desgaste(Game.durabilidad_slot("main", pj)), main == null)
	var off: Resource = pj.equipped_off
	IconosEquipo.rejilla(self, IconosEquipo.tabla_de_mano(off),
		Rect2(Vector2(media + 1.0, 2), Vector2(media - 3.0, size.y - 4.0)),
		Game.color_desgaste(Game.durabilidad_slot("off", pj)), off == null)
