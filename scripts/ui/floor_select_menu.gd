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
	Game.abrir_menu(self)   # para el mundo entero mientras el menu esta abierto
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


func _rebuild() -> void:
	MenuScaffold.vaciar(_content)

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

	MenuScaffold.nota(_content, "La mazmorra sigue como la dejaste: los mismos bichos y lo que se te cayó por el suelo. Sólo morir (o cerrar el juego) la reinicia.")


func _bajar(piso: int) -> void:
	# MULTIJUGADOR: mismo destino, pero el viaje lo concede el host (reparte quien simula el piso y
	# devuelve su foto si estaba congelado). Todo lo de abajo lo hace _entrar_ok en su sitio:
	# current_floor, entrada_por_atajo, olvidar_mazmorra y el cambio de escena.
	if Net.activo:
		Game.cerrar_menu(self)
		Net.solicitar_entrar(maxi(1, piso))
		return
	# Igual que entrar por la boca (door.gd). Lo unico distinto es por que piso empiezas: la mazmorra
	# NO se olvida (los pisos siguen como los dejaste; ver el comentario de door.gd).
	Game.current_floor = maxi(1, piso)
	# Al piso 1 se entra por la BOCA (ahi esta la puerta al pueblo). A un piso de boss se entra por
	# SU salida al pueblo, que esta en el fondo: apareces junto a ella y a la bajada.
	Game.entrada_por_atajo = Game.current_floor > 1
	# Baseline del mapa: lo que cartografies esta expedicion se pierde si mueres.
	Game.iniciar_expedicion_mapa()
	Game.cerrar_menu(self)
	print("[mazmorra] Entras directamente al piso %d." % Game.current_floor)
	get_tree().change_scene_to_file(DUNGEON)
