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

# Tipos de enemigo colocables: [etiqueta, ruta EnemyData]. Todos usan la misma escena enemy.tscn;
# solo cambia el .tres de datos. La lista se MONTA SOLA desde Game.rutas_enemigos() (el manifiesto),
# con el nombre que cada bicho lleva dentro: antes eran cuatro rutas escritas a mano de los veinte
# que hay, asi que en la arena no se podia probar contra el 80% del bestiario. Al meter un enemigo
# nuevo basta con apuntarlo en el manifiesto y aparece aqui; en el editor ademas se avisa si falta.
var _enemy_types: Array = []

var _enemy_scene: PackedScene = preload("res://scenes/actors/enemy/enemy.tscn")

var _armed: bool = false
var _type_idx: int = 0
var _spawned: Array[Node] = []   # enemigos colocados por esta herramienta

var _toggle_btn: Button = null
var _type_opt: OptionButton = null
var _count_lbl: Label = null

# MODO PRUEBA (muñeco). Vivia en el panel de debug, que existe en TODAS las salas, y como el modo
# es una variable global de Game te seguia a la mazmorra de verdad dejandote invulnerable sin que
# nada lo dijera. Aqui vive donde tiene sentido -- junto al boton de poner bichos -- y, como este
# panel solo existe en la arena, al salir se apaga solo (ver _ready y _exit_tree).
var _dummy_buttons: Array = []   # [boton, modo]: Off / Saco DPS / Pegador
var _dummy_hp_edit: LineEdit = null


func _ready() -> void:
	# Herramienta de dev solo para la ARENA de pruebas: en el resto de salas
	# (pueblo/mazmorra) se autodestruye para no ensuciar la interfaz.
	var escena: Node = get_tree().current_scene
	if escena == null or not escena.scene_file_path.contains("sandbox"):
		_apagar_muneco()   # por si vienes de la arena con el saco puesto
		queue_free()
		return

	layer = MenuScaffold.CAPA_DEV
	add_to_group("panel_dev")   # para que los tres paneles de dev se ordenen entre si

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_right = -8
	panel.offset_top = 8
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	# Tocarlo lo pone delante de los otros paneles de dev.
	panel.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: MenuScaffold.al_frente(self))
	# El panel de MATERIALES se cuelga JUSTO DEBAJO de este, y para eso necesita encontrarlo y
	# saber cuanto mide. Antes se ponia a una altura fija escrita a mano, asi que en cuanto a este
	# se le añadia una fila mas (paso con la seccion del muñeco) se le comia el de abajo.
	panel.add_to_group("panel_dev_spawner")
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
	_cargar_tipos()
	for i in _enemy_types.size():
		_type_opt.add_item(_enemy_types[i][0], i)
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

	# --- MODO PRUEBA (muñeco) -------------------------------------------------
	var dtit := Label.new()
	dtit.text = "Muñeco"
	dtit.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	vb.add_child(dtit)
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 4)
	vb.add_child(drow)
	for dpreset in [["Off", 0], ["Saco DPS", 1], ["Pegador", 2]]:
		var db := Button.new()
		db.text = dpreset[0]
		db.toggle_mode = true
		db.pressed.connect(_set_dummy.bind(dpreset[1]))
		drow.add_child(db)
		_dummy_buttons.append([db, dpreset[1]])
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 4)
	vb.add_child(hrow)
	var hlbl := Label.new()
	hlbl.text = "HP"
	hrow.add_child(hlbl)
	_dummy_hp_edit = LineEdit.new()
	_dummy_hp_edit.custom_minimum_size = Vector2(60, 0)
	_dummy_hp_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dummy_hp_edit.text_submitted.connect(func(_t): _apply_dummy_hp())
	hrow.add_child(_dummy_hp_edit)
	var hap := Button.new()
	hap.text = "Aplicar"
	hap.pressed.connect(_apply_dummy_hp)
	hrow.add_child(hap)

	_refrescar()
	_sync_dummy()


# Al irse de la arena, el modo prueba se va con ella. Es lo que impide que te lleves puesta la
# invulnerabilidad a la mazmorra de verdad sin enterarte (ver Game.volver_muneco).
func _exit_tree() -> void:
	_apagar_muneco()


func _apagar_muneco() -> void:
	Game.debug_dummy_mode = 0


func _set_dummy(modo: int) -> void:
	Game.debug_dummy_mode = modo
	_sync_dummy()


func _apply_dummy_hp() -> void:
	if _dummy_hp_edit == null:
		return
	var v: float = maxf(1.0, float(_dummy_hp_edit.text.to_float()))
	Game.debug_dummy_hp = v
	_dummy_hp_edit.text = str(int(v))


func _sync_dummy() -> void:
	for pair in _dummy_buttons:
		(pair[0] as Button).button_pressed = (pair[1] == Game.debug_dummy_mode)
	if _dummy_hp_edit != null:
		_dummy_hp_edit.text = str(int(Game.debug_dummy_hp))


# Monta la lista desde el manifiesto: etiqueta = el nombre del propio EnemyData (+ su nivel si no es
# 1, que es lo que distingue a un guardian). Ordenada por nivel y luego por nombre, para que los de
# los primeros pisos queden arriba y buscar uno concreto no sea una loteria.
func _cargar_tipos() -> void:
	_enemy_types.clear()
	for ruta in Game.rutas_enemigos():
		var d: EnemyData = load(ruta) as EnemyData
		if d == null:
			continue
		var etq: String = d.enemy_name
		if int(d.level) > 1:
			etq += "  (Nv%d)" % int(d.level)
		_enemy_types.append([etq, ruta, int(d.level)])
	_enemy_types.sort_custom(func(a, b):
		if int(a[2]) != int(b[2]):
			return int(a[2]) < int(b[2])
		return str(a[0]) < str(b[0]))


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
	if _type_idx < 0 or _type_idx >= _enemy_types.size():
		return
	enemy.data = load(_enemy_types[_type_idx][1])
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
	# Y QUE EL COMBATE SE ENTERE. Barrer bichos que estaban apuntados en una pelea dejaba la lista
	# de Game llena de nodos liberados, y con eso el juego cree que sigue habiendo pelea PARA
	# SIEMPRE: a partir de ahi ningun bicho vuelve a abrir combate en ninguna sala, se te pegan y
	# te atacan sin que pase nada. Ver Game._destrabar_combate.
	Game.combate_activo()
	_refrescar()


# Quita del registro las referencias ya liberadas (enemigos muertos y limpiados).
func _purgar() -> void:
	var vivos: Array[Node] = []
	for e in _spawned:
		if is_instance_valid(e):
			vivos.append(e)
	_spawned = vivos
