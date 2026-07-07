# ============================================================
#  spawner.gd  (CanvasLayer creada por codigo desde el jugador)
#  Herramienta de DESARROLLO para PROBAR combate/estados: coloca enemigos con
#  el raton en cualquier sala.
#   - Boton "Colocar" -> arma el modo colocacion; cada clic IZQUIERDO en el mapa
#     spawnea un enemigo del tipo elegido en esa posicion (clic derecho = desarma).
#   - Selector de TIPO de enemigo (de momento solo Slime; preparado para mas).
#   - Boton "Limpiar" -> borra todos los enemigos/cadaveres spawneados.
#  Todo por codigo (UI placeholder). Pensado para la arena vacia (sandbox.tscn).
# ============================================================

extends CanvasLayer

# Tipos de enemigo colocables: [etiqueta, ruta EnemyData]. Todos usan la misma
# escena enemy.tscn; solo cambia el .tres de datos. Ampliar cuando haya mas bichos.
const ENEMY_TYPES := [
	["Slime", "res://scenes/actors/enemy/slime.tres"],
	["Slime venenoso", "res://scenes/actors/enemy/slime_veneno.tres"],
	["Slime de fuego", "res://scenes/actors/enemy/slime_fuego.tres"],
]

var _enemy_scene: PackedScene = preload("res://scenes/actors/enemy/enemy.tscn")

var _armed: bool = false
var _type_idx: int = 0
var _spawned: Array[Node] = []   # enemigos colocados por esta herramienta

var _toggle_btn: Button = null
var _type_opt: OptionButton = null
var _count_lbl: Label = null


func _ready() -> void:
	# Herramienta de dev solo para la ARENA de pruebas: en el resto de salas
	# (pueblo/mazmorra) se autodestruye para no ensuciar la interfaz.
	var escena: Node = get_tree().current_scene
	if escena == null or not escena.scene_file_path.contains("sandbox"):
		queue_free()
		return

	layer = 6  # como el panel de debug

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_right = -8
	panel.offset_top = 8
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "SPAWNER (dev)"
	title.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	vb.add_child(title)

	# Fila: selector de tipo.
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 4)
	vb.add_child(trow)
	var tlbl := Label.new()
	tlbl.text = "Tipo"
	trow.add_child(tlbl)
	_type_opt = OptionButton.new()
	for i in ENEMY_TYPES.size():
		_type_opt.add_item(ENEMY_TYPES[i][0], i)
	_type_opt.item_selected.connect(func(idx): _type_idx = idx)
	trow.add_child(_type_opt)

	# Fila: colocar / limpiar.
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 4)
	vb.add_child(brow)
	_toggle_btn = Button.new()
	_toggle_btn.toggle_mode = true
	_toggle_btn.pressed.connect(_on_toggle)
	brow.add_child(_toggle_btn)
	var clear_btn := Button.new()
	clear_btn.text = "Limpiar"
	clear_btn.pressed.connect(_limpiar)
	brow.add_child(clear_btn)

	_count_lbl = Label.new()
	vb.add_child(_count_lbl)

	_refrescar()


func _on_toggle() -> void:
	_armed = _toggle_btn.button_pressed
	_refrescar()


func _refrescar() -> void:
	_toggle_btn.text = "Colocar: ON" if _armed else "Colocar: OFF"
	_purgar()  # descarta referencias invalidas antes de contar
	_count_lbl.text = "  Enemigos: %d" % _spawned.size()


# Clic en el MUNDO (no sobre la UI: los botones consumen su propio clic antes de
# llegar aqui). Izquierdo = colocar; derecho = desarmar.
func _unhandled_input(event: InputEvent) -> void:
	if not _armed:
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		_toggle_btn.button_pressed = false
		_armed = false
		_refrescar()
		get_viewport().set_input_as_handled()
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_colocar_en_raton()
		get_viewport().set_input_as_handled()


# Spawnea un enemigo en la posicion del raton (en coordenadas de MUNDO, teniendo
# en cuenta la camara del jugador).
func _colocar_en_raton() -> void:
	var mundo: Node = _mundo()
	if mundo == null:
		push_warning("[spawner] No hay escena de mundo donde colocar el enemigo.")
		return
	var pos: Vector2 = _pos_raton_mundo(mundo)

	var enemy: Node2D = _enemy_scene.instantiate()
	enemy.data = load(ENEMY_TYPES[_type_idx][1])
	mundo.add_child(enemy)
	# recolocar tras add_child: _ready ya fijo el "hogar" del bicho, hay que
	# moverlo Y re-hogarlo aqui (si no, deambula/regresa hacia (0,0)).
	enemy.recolocar(pos)
	_spawned.append(enemy)
	_refrescar()


# Nodo raiz del mundo (donde cuelgan player/enemigos). Usamos el padre del player.
func _mundo() -> Node:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player):
		return player.get_parent()
	return get_tree().current_scene


# Posicion del raton en coordenadas de mundo (via un CanvasItem del mundo, que si
# conoce la transformada de la camara; un CanvasLayer no).
func _pos_raton_mundo(mundo: Node) -> Vector2:
	if mundo is CanvasItem:
		return (mundo as CanvasItem).get_global_mouse_position()
	var player := get_tree().get_first_node_in_group("player")
	if player is Node2D:
		return (player as Node2D).get_global_mouse_position()
	return get_viewport().get_mouse_position()


# Borra todos los enemigos/cadaveres colocados por esta herramienta.
func _limpiar() -> void:
	for e in _spawned:
		if is_instance_valid(e):
			e.queue_free()
	_spawned.clear()
	_refrescar()


# Quita del registro las referencias ya liberadas (enemigos muertos y limpiados).
func _purgar() -> void:
	var vivos: Array[Node] = []
	for e in _spawned:
		if is_instance_valid(e):
			vivos.append(e)
	_spawned = vivos
