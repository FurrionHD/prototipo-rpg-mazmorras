# ============================================================
#  floor_select_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  ELEGIR PISO al entrar en la mazmorra. Lo abre la puerta del pueblo (door.gd -> abrir()).
#
#  Solo aparece si hay a donde saltar: al empezar la partida el unico destino es el piso 1, asi
#  que la puerta te mete directamente y este menu ni se abre. Cada BOSS que matas añade su piso
#  a la lista (Game.pisos_desbloqueados): ese es su premio, no volver a caminar lo ya caminado.
#
#  Saltar a un piso es EMPEZAR UNA EXPEDICION ahi: la mazmorra se repuebla igual que si
#  entraras por el piso 1.
# ============================================================

extends CanvasLayer

const DUNGEON := "res://scenes/levels/main.tscn"

var _root: Control = null
var _content: VBoxContainer = null


func _ready() -> void:
	layer = 93   # por encima del resto de menus del pueblo
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para: hay que seguir respondiendo
	add_to_group("floor_menu")

	var m: Dictionary = MenuScaffold.construir(self, "BAJAR A LA MAZMORRA",
		"Cada jefe que derrotas abre un acceso directo a su piso. Los demás hay que caminarlos.",
		_cerrar)
	_root = m["root"]
	_content = m["content"]
	(m["lista_scroll"] as ScrollContainer).visible = false


func abrir() -> void:
	if Game._active_layer != null or Game.debug_panel_open:
		return
	_root.visible = true
	Game.abrir_menu()   # para el mundo entero mientras el menu esta abierto
	_rebuild()


func _cerrar() -> void:
	_root.visible = false
	Game.cerrar_menu()


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_cerrar()
			get_viewport().set_input_as_handled()


func _rebuild() -> void:
	for c in _content.get_children():
		c.queue_free()

	MenuScaffold.titulo(_content, "¿POR DÓNDE ENTRAS?")
	_content.add_child(HSeparator.new())

	for piso in Game.pisos_desbloqueados():
		var b := Button.new()
		b.text = "Piso %d" % piso
		if piso > 1:
			b.text += "   (acceso abierto por el jefe)"
		b.custom_minimum_size = Vector2(0, 38)
		b.pressed.connect(_bajar.bind(piso))
		_content.add_child(b)

	MenuScaffold.nota(_content, "Entrar es empezar una expedición: la mazmorra se repuebla, y lo que dejaste tirado en sus pisos ya no está.")


func _bajar(piso: int) -> void:
	# Igual que entrar por la boca (door.gd): expedicion NUEVA. Lo unico distinto es por que
	# piso empiezas.
	Game.current_floor = maxi(1, piso)
	# Al piso 1 se entra por la BOCA (ahi esta la puerta al pueblo). A un piso de boss se entra por
	# SU salida al pueblo, que esta en el fondo: apareces junto a ella y a la bajada.
	Game.entrada_por_atajo = Game.current_floor > 1
	Game.olvidar_mazmorra()
	# Baseline del mapa: lo que cartografies esta expedicion se pierde si mueres.
	Game.iniciar_expedicion_mapa()
	Game.cerrar_menu()
	print("[mazmorra] Entras directamente al piso %d." % Game.current_floor)
	get_tree().change_scene_to_file(DUNGEON)
