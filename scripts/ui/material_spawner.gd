# ============================================================
#  material_spawner.gd  (CanvasLayer creada por codigo desde el jugador)
#  Herramienta de DESARROLLO para PROBAR la RECOLECCION: planta vetas, plantas y enredaderas
#  con el raton, del material que elijas, sin tener que bajar doce pisos a buscarlas.
#
#  Es el hermano de spawner.gd (que pone enemigos) y sigue su mismo patron: se autodestruye
#  fuera del sandbox, se arma con un boton y cada clic izquierdo coloca.
#
#  LO IMPORTANTE para que sirva de algo: la dificultad del minijuego depende del material Y de
#  Game.current_floor (los minijuegos suman ritmo por piso). Por eso la herramienta lleva su
#  propio selector de piso: asi se prueba "cobre profundo en el piso 6" en dos clics.
#
#  Funciona sin DungeonFloor: start_mineria/talado/herboristeria no tocan el piso, y
#  _cerrar_recoleccion busca la mazmorra defensivamente (sin ella se salta marcar_agotado).
#  Consecuencia: aqui NO hay respawn ni memoria de agotados. Es una arena, no una mazmorra.
# ============================================================

extends CanvasLayer

const _RECO := preload("res://scripts/world/resource_node.gd")

# Solo lo RECOLECTABLE. Un material de tipo MINERAL con exigencia 0 (la quitina, la runa de
# arcilla) no es una veta: es un drop de bicho, y plantarlo como nodo no tendria minijuego.
const CATEGORIAS := [
	["Minerales (pico · Fuerza)", MaterialData.Tipo.MINERAL, _RECO.Tipo.VETA],
	["Maderas (hacha · Agilidad)", MaterialData.Tipo.MADERA, _RECO.Tipo.MADERA],
	["Plantas (hoz · Destreza)", MaterialData.Tipo.PLANTA, _RECO.Tipo.PLANTA],
]

var _armed: bool = false
var _cat_idx: int = 0
var _mat_idx: int = 0
var _puestos: Array[Node] = []

var _toggle_btn: Button = null
var _cat_opt: OptionButton = null
var _mat_opt: OptionButton = null
var _piso_spin: SpinBox = null
var _info_lbl: Label = null


func _ready() -> void:
	var escena: Node = get_tree().current_scene
	if escena == null or not escena.scene_file_path.contains("sandbox"):
		queue_free()
		return

	layer = 6   # como el spawner de enemigos y el panel de debug

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_right = -8
	panel.offset_top = 150      # justo debajo del spawner de enemigos
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
	title.text = "MATERIALES (dev)"
	title.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	vb.add_child(title)

	_cat_opt = OptionButton.new()
	for i in CATEGORIAS.size():
		_cat_opt.add_item(CATEGORIAS[i][0], i)
	_cat_opt.item_selected.connect(_on_categoria)
	vb.add_child(_cat_opt)

	_mat_opt = OptionButton.new()
	_mat_opt.item_selected.connect(_on_material)
	vb.add_child(_mat_opt)

	# El PISO importa: los minijuegos suman ritmo con la profundidad, asi que probar un material
	# "en su piso" no es lo mismo que probarlo en el 1.
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 4)
	vb.add_child(prow)
	var plbl := Label.new()
	plbl.text = "Piso"
	prow.add_child(plbl)
	_piso_spin = SpinBox.new()
	_piso_spin.min_value = 1
	_piso_spin.max_value = 30
	_piso_spin.value = maxi(1, Game.current_floor)
	_piso_spin.value_changed.connect(func(v): Game.current_floor = int(v); _refrescar())
	prow.add_child(_piso_spin)

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

	_info_lbl = Label.new()
	_info_lbl.add_theme_font_size_override("font_size", 11)
	vb.add_child(_info_lbl)

	_poblar_materiales()


# Los materiales recolectables de la categoria elegida, ordenados por exigencia (de facil a
# dificil), que es el orden en el que un jugador se los va encontrando.
func _materiales() -> Array:
	var tipo: int = CATEGORIAS[_cat_idx][1]
	var out: Array = []
	for f in DirAccess.get_files_at("res://resources/materials"):
		if not f.ends_with(".tres"):
			continue
		var m: MaterialData = load("res://resources/materials/" + f) as MaterialData
		if m != null and int(m.tipo) == tipo and m.exigencia > 0.0:
			out.append(m)
	out.sort_custom(func(a, b): return a.exigencia < b.exigencia)
	return out


func _poblar_materiales() -> void:
	_mat_opt.clear()
	var mats: Array = _materiales()
	for i in mats.size():
		var m: MaterialData = mats[i]
		_mat_opt.add_item("%s  (T%d · exig %d)" % [m.nombre, m.tier, int(m.exigencia)], i)
	_mat_idx = 0
	if not mats.is_empty():
		_mat_opt.select(0)
	_refrescar()


func _on_categoria(idx: int) -> void:
	_cat_idx = idx
	_poblar_materiales()


func _on_material(idx: int) -> void:
	_mat_idx = idx
	_refrescar()


func _on_toggle() -> void:
	_armed = _toggle_btn.button_pressed
	_refrescar()


func _refrescar() -> void:
	_toggle_btn.text = "Colocar: ON" if _armed else "Colocar: OFF"
	_purgar()
	var m: MaterialData = _material_elegido()
	if m == null:
		_info_lbl.text = "  (nada en esta categoria)"
		return
	# La dificultad que va a tener AHORA MISMO, con tus stats y el piso elegido: es el numero que
	# de verdad se quiere ver al afinar la curva.
	var stat: String = "fuerza" if m.es_veta() else ("agilidad" if m.es_madera() else "destreza")
	var d: float = Game._exigencia_material(m) / (float(Game.stat_total(stat)) * Game.RECOLECCION_STAT_PESO + 30.0)
	_info_lbl.text = "  %s %d · dificultad %.2f\n  puestos: %d" % [
		stat.substr(0, 3).to_upper(), Game.stat_total(stat), d, _puestos.size()]


func _material_elegido() -> MaterialData:
	var mats: Array = _materiales()
	return mats[_mat_idx] if _mat_idx < mats.size() else null


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


func _colocar_en_raton() -> void:
	var m: MaterialData = _material_elegido()
	if m == null:
		return
	var mundo: Node = _mundo()
	if mundo == null:
		push_warning("[materiales] No hay escena de mundo donde plantar el nodo.")
		return
	var nodo = _RECO.new()
	nodo.tipo = CATEGORIAS[_cat_idx][2]
	nodo.material_data = m
	# Sin mazmorra no hay celdas: la celda se queda a cero y nadie la mira (marcar_agotado solo
	# corre si hay DungeonFloor, y aqui no lo hay).
	mundo.add_child(nodo)
	nodo.global_position = _pos_raton_mundo(mundo)
	_puestos.append(nodo)
	_refrescar()


# El nodo del MUNDO, no un CanvasLayer: si cuelga de una capa no ve la camara y aparece en
# coordenadas de pantalla.
func _mundo() -> Node:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player):
		return player.get_parent()
	return get_tree().current_scene


func _pos_raton_mundo(mundo: Node) -> Vector2:
	if mundo is CanvasItem:
		return (mundo as CanvasItem).get_global_mouse_position()
	var player := get_tree().get_first_node_in_group("player")
	if player is Node2D:
		return (player as Node2D).get_global_mouse_position()
	return get_viewport().get_mouse_position()


func _limpiar() -> void:
	for n in _puestos:
		if is_instance_valid(n):
			n.queue_free()
	_puestos.clear()
	_refrescar()


func _purgar() -> void:
	var vivos: Array[Node] = []
	for n in _puestos:
		if is_instance_valid(n):
			vivos.append(n)
	_puestos = vivos
