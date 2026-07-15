# ============================================================
#  desarrollo_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  SELECTOR de habilidad de desarrollo al SUBIR DE NIVEL. Lo abre el menu del altar cuando
#  puede_subir_nivel(). Eliges 1 (obligatorio para subir); Esc = APLAZAR (sigues con el nivel
#  actual para farmear un poco mas). Elegir llama Game.subir_nivel(id).
# ============================================================

extends CanvasLayer

var _root: Control = null
var _content: VBoxContainer = null


func _ready() -> void:
	layer = 95   # por encima del menu del altar
	add_to_group("desarrollo_menu")
	var m: Dictionary = MenuScaffold.construir(self, "SUBIR DE NIVEL",
		"Elige una habilidad de desarrollo. Es permanente. (Esc: aplazar la subida)", _cerrar)
	_root = m["root"]
	_content = m["content"]
	(m["lista_scroll"] as ScrollContainer).visible = false


func abrir() -> void:
	if Game.debug_panel_open:
		return
	_root.visible = true
	Game.inventory_open = true
	_rebuild()


func _cerrar() -> void:
	_root.visible = false
	Game.inventory_open = false


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

	MenuScaffold.titulo(_content, "NIVEL %d  →  %d" % [Game.player_level, Game.player_level + 1])
	MenuScaffold.nota(_content, "Al subir, tu poder actual se graba en tu base (+10%) y las 5 habilidades vuelven a rango I para crecer sobre esa base más alta. Lo que llevas acumulado NO se pierde (sigue contando por debajo).")
	_content.add_child(HSeparator.new())

	var disp: Array = Game.desarrollos_disponibles()
	if disp.is_empty():
		MenuScaffold.nota(_content, "Ya has aprendido todas las habilidades de desarrollo disponibles.")
		return

	for d in disp:
		var b := Button.new()
		var etiqueta_tipo: String = "Oficio" if d["tipo"] == "oficio" else "Combate"
		b.text = "%s  ·  %s\n%s" % [d["nombre"], etiqueta_tipo, d["desc"]]
		b.custom_minimum_size = Vector2(0, 50)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_elegir.bind(str(d["id"])))
		_content.add_child(b)


func _elegir(id: String) -> void:
	if Game.subir_nivel(id):
		print("[desarrollo] Subes de nivel eligiendo ", id)
	_cerrar()
	# Refrescar el menu del altar si sigue vivo (para que muestre el nuevo nivel / el antes-despues).
	var altar: Node = get_tree().get_first_node_in_group("altar_menu")
	if altar != null and altar.has_method("mostrar_subida"):
		altar.mostrar_subida()
