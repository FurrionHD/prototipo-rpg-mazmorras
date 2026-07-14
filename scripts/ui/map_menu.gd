# ============================================================
#  map_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  MAPA del piso (tecla M). Solo dibuja lo que has EXPLORADO: cada sala/pasillo por el que
#  has pasado queda visto para siempre (Game.mazmorra_persistente[piso]["zonas_vistas"]), y
#  con el, sus nodos de recoleccion.
#
#  Los nodos VIVOS (los que hay ahora mismo en el piso) salen con el color de su material.
#  Los AGOTADOS (picados, esperando su respawn) salen apagados con los segundos que les faltan
#  para volver. Asi el mapa sirve para planear la ruta, que es para lo que se pidio.
#
#  No re-deriva el piso: lee la geometria del DungeonFloor vivo (grupo "dungeon_floor") y los
#  nodos del grupo "recolectable". Todo por codigo, como el resto de menus.
# ============================================================

extends CanvasLayer

const MARGEN := 60.0        # px de borde alrededor del mapa
const COLOR_FONDO := Color(0.04, 0.04, 0.06, 0.94)
const COLOR_SUELO := Color(0.24, 0.24, 0.30)      # zona explorada
const COLOR_JUGADOR := Color(0.35, 0.85, 1.0)

var _root: Control = null
var _lienzo: Control = null


func _ready() -> void:
	layer = 92   # como el menu de personaje: por encima del HUD
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

	var fondo := ColorRect.new()
	fondo.color = COLOR_FONDO
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(fondo)

	_lienzo = Control.new()
	_lienzo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lienzo.draw.connect(_dibujar)
	_root.add_child(_lienzo)

	var titulo := Label.new()
	titulo.text = "MAPA  ·  [M] para cerrar"
	titulo.add_theme_font_size_override("font_size", 18)
	titulo.position = Vector2(MARGEN, 20.0)
	_root.add_child(titulo)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var code: int = (event as InputEventKey).keycode
	if code == KEY_M:
		_toggle()
	elif code == KEY_ESCAPE and _root.visible:
		_cerrar()


func _toggle() -> void:
	if _root.visible:
		_cerrar()
		return
	# El mapa es de la MAZMORRA: sin un piso vivo (estas en el pueblo) no hay nada que enseñar.
	# Tampoco sobre un combate/extraccion ni con el DEBUG abierto.
	if Game._active_layer != null or Game.debug_panel_open:
		return
	if get_tree().get_first_node_in_group("dungeon_floor") == null:
		return
	_root.visible = true
	Game.inventory_open = true   # congela al jugador mientras miras el mapa
	_lienzo.queue_redraw()


func _cerrar() -> void:
	_root.visible = false
	Game.inventory_open = false


# El DungeonGenerator del piso vivo (tiene la geometria: zonas, celdas, tamaño).
func _gen():
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	return piso.gen if piso != null else null


func _dibujar() -> void:
	var gen = _gen()
	if gen == null:
		return
	var vistas: Dictionary = Game.persistente_piso(Game.current_floor)["zonas_vistas"]
	var agotados: Dictionary = Game.persistente_piso(Game.current_floor)["agotados"]

	# Escala: que el mapa entero quepa en la pantalla con margen, manteniendo proporcion.
	var area := get_viewport().get_visible_rect().size - Vector2(MARGEN, MARGEN) * 2.0
	var celda_px: float = minf(area.x / float(gen.ancho), area.y / float(gen.alto))
	var offset := Vector2(MARGEN, MARGEN) \
		+ (area - Vector2(gen.ancho, gen.alto) * celda_px) * 0.5

	# 1) SUELO de las zonas exploradas (la niebla es no dibujar el resto).
	for i in range(gen.zonas.size()):
		if not vistas.has(i):
			continue
		for c in (gen.zonas[i]["celdas"] as Array):
			var p: Vector2 = offset + Vector2(c) * celda_px
			_lienzo.draw_rect(Rect2(p, Vector2(celda_px, celda_px)), COLOR_SUELO)

	# 2) NODOS VIVOS (los que hay ahora), solo en zonas exploradas: color del material.
	for nodo in get_tree().get_nodes_in_group("recolectable"):
		if not is_instance_valid(nodo) or nodo.material_data == null:
			continue
		if not vistas.has(gen.zona_en(nodo.celda)):
			continue
		_punto(offset, celda_px, nodo.celda, nodo.material_data.color, 0.42)

	# 3) NODOS AGOTADOS (picados, esperando respawn): apagados + cuenta atras.
	var font: Font = ThemeDB.fallback_font
	for celda in agotados:
		if not vistas.has(gen.zona_en(celda)):
			continue
		var falta: float = RESPAWN() - (Game.tiempo_mazmorra - float(agotados[celda]))
		if falta <= 0.0:
			continue   # ya le toca volver; nacera al recargar el piso
		var p: Vector2 = offset + (Vector2(celda) + Vector2(0.5, 0.5)) * celda_px
		_lienzo.draw_circle(p, celda_px * 0.30, Color(0.4, 0.4, 0.42, 0.7))
		_lienzo.draw_string(font, p + Vector2(celda_px * 0.4, -celda_px * 0.4),
			"%dm" % int(ceil(falta / 60.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(0.7, 0.7, 0.75))

	# 4) JUGADOR.
	var player := get_tree().get_first_node_in_group("player")
	if player is Node2D:
		var celda_j := Vector2i(((player as Node2D).global_position / DungeonGenerator.CELDA).floor())
		_punto(offset, celda_px, celda_j, COLOR_JUGADOR, 0.6)


func _punto(offset: Vector2, celda_px: float, celda: Vector2i, color: Color, radio_frac: float) -> void:
	var p: Vector2 = offset + (Vector2(celda) + Vector2(0.5, 0.5)) * celda_px
	_lienzo.draw_circle(p, celda_px * radio_frac, color)


# El respawn vive en DungeonFloor; se lee de alli para no duplicar la constante.
func RESPAWN() -> float:
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	return piso.RESPAWN_SEGUNDOS if piso != null else 600.0
