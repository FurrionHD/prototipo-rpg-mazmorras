# ============================================================
#  fishing_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  EL MENU DEL ESTANQUE. Lo abre la F sobre el charco (FishingSpot.interactuar) y es el paso previo
#  a echar el sedal: eliges CEBO y le das a tirar la caña.
#
#  Existe por el cebo. Poner cebo no es "usar un objeto" (no hace nada en la bolsa: mira
#  Game.usar_consumible, que se planta con los cebos a proposito), es una decision que solo
#  significa algo con el agua delante — y este es el unico sitio del juego donde la tienes delante.
#  De paso, meter una pantalla entre la F y el lanzamiento le da a la pesca el arranque pausado que
#  el resto de oficios sacan de su minijuego a pantalla completa.
#
#  Lo que NO hace: no vende cebos (eso es del Pescador, en el pueblo) ni enseña el libro. Aqui abajo
#  solo se pesca con lo que hayas traido.
# ============================================================

extends CanvasLayer

var _root: Control = null
var _header: VBoxContainer = null
var _content: VBoxContainer = null
var _lista: VBoxContainer = null
# El charco que lo abrio: a el vuelve el "Tirar la caña". Se guarda porque el menu es UNO solo
# (cuelga del jugador) y viaja con el de un piso a otro.
var _spot: Node = null
# Que hay marcado en la lista: -1 = "Sin cebo", 0..n = indice en Game.cebos().
var _sel: int = -1

const AMBAR := Color(0.95, 0.72, 0.36)
const GRIS := Color(0.6, 0.63, 0.7)
const VERDE := Color(0.55, 0.85, 0.55)


func _ready() -> void:
	layer = 91
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para con el menu abierto
	add_to_group("fishing_menu")

	var m: Dictionary = MenuScaffold.construir(self, "ESTANQUE",
		"Pon cebo si lo llevas y echa el sedal. Los peces que estén ahí abajo son los que hay.",
		_cerrar)
	_root = m["root"]
	_header = m["header"]
	_content = m["content"]
	_lista = m["lista"]


func abrir(spot: Node) -> void:
	if Game._active_layer != null or Game.debug_panel_open:
		return
	_spot = spot
	# Se abre marcando lo que ya llevas puesto: el caso normal es tirar otra vez con el mismo cebo,
	# y en ese caso no hay que tocar nada.
	_sel = Game.cebos().find(Game.cebo_activo) if Game.cebo_activo != null else -1
	_root.visible = true
	Game.abrir_menu(self)
	_rebuild()


func _cerrar() -> void:
	_root.visible = false
	Game.cerrar_menu(self)


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_cerrar()
			get_viewport().set_input_as_handled()


# Guardia de REENTRADA. Un _rebuild puede entrar mientras otro esta a medias (el focus_exited de un
# stepper al liberarlo, las señales de red, un _on_* que espera en un await), y entonces el de dentro
# pinta su panel y el de fuera apila el suyo debajo: el menu salia DUPLICADO. Es el mismo guardia que
# lleva el herrero desde que se cazo alli.
var _reconstruyendo := false

func _rebuild() -> void:
	if _reconstruyendo:
		return
	_reconstruyendo = true
	_rebuild_real()
	_reconstruyendo = false


func _rebuild_real() -> void:
	for zona in [_header, _content, _lista]:
		MenuScaffold.vaciar(zona)

	MenuScaffold.titulo(_header, "PESCAR")
	var puesto: String = Game.cebo_activo.nombre if Game.cebo_activo != null else "sin cebo"
	MenuScaffold.nota(_header, "En el anzuelo: %s" % puesto)
	_header.add_child(HSeparator.new())

	var cebos: Array = Game.cebos()
	_lista.add_child(_boton_cebo("Sin cebo", "", -1))
	for i in cebos.size():
		var c: ConsumableData = cebos[i]
		_lista.add_child(_boton_cebo(c.nombre, "x%d" % int(Game.consumables.get(c, 0)), i))

	# El boton gordo, abajo del todo y separado de la lista: es la accion, no una opcion mas.
	_lista.add_child(HSeparator.new())
	var tirar := Button.new()
	tirar.text = "🎣  Tirar la caña"
	tirar.custom_minimum_size = Vector2(0, 40)
	tirar.pressed.connect(_on_tirar)
	_lista.add_child(tirar)

	_ficha(cebos)


func _boton_cebo(txt: String, extra: String, idx: int) -> Button:
	var b := Button.new()
	b.text = txt if extra == "" else "%s   %s" % [txt, extra]
	b.toggle_mode = true
	b.button_pressed = (idx == _sel)
	b.custom_minimum_size = Vector2(0, 32)
	b.pressed.connect(_on_sel.bind(idx))
	return b


func _on_sel(i: int) -> void:
	_sel = i
	# Marcarlo YA lo pone: no hay un boton de "confirmar cebo" porque no hay nada que confirmar
	# (ponerlo y quitarlo es gratis, lo que cuesta es pescar con el).
	var cebos: Array = Game.cebos()
	Game.poner_cebo(cebos[i] if i >= 0 and i < cebos.size() else null)
	_rebuild()


func _on_tirar() -> void:
	var spot: Node = _spot
	_cerrar()
	if spot != null and is_instance_valid(spot) and spot.has_method("empezar_apuntado"):
		spot.empezar_apuntado()


func _ficha(cebos: Array) -> void:
	if _sel < 0 or _sel >= cebos.size():
		MenuScaffold.titulo(_content, "Sin cebo", 16, GRIS)
		_content.add_child(HSeparator.new())
		MenuScaffold.nota(_content, "El anzuelo desnudo no llama a nadie: pican los peces que se "
			+ "cruzan con él. Elige bien dónde cae el corcho.")
		if cebos.is_empty():
			MenuScaffold.nota(_content, "Los cebos los vende el Pescador, en el pueblo.")
		return

	var c: ConsumableData = cebos[_sel]
	MenuScaffold.titulo(_content, c.nombre, 16, AMBAR)
	# El radio sale del CAMPO (resumen()), nunca escrito a mano: retocar el .tres no puede dejar
	# este texto mintiendo.
	MenuScaffold.fila(_content, "Atracción", c.resumen(0.0, 0.0), 140, VERDE)
	MenuScaffold.fila(_content, "Te quedan", str(int(Game.consumables.get(c, 0))), 140)
	MenuScaffold.fila(_content, "Se gasta", "%d%% de las piezas que cobres"
		% int(round(Game.CEBO_GASTO * 100.0)), 140)
	_content.add_child(HSeparator.new())
	MenuScaffold.nota(_content, c.descripcion)
	MenuScaffold.nota(_content, "Los peces que entren en su radio virarán hacia el corcho. Si el pez "
		+ "se te escapa o recoges el sedal, el cebo no se gasta.")
