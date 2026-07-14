# ============================================================
#  map_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  MAPA del piso (tecla M). Es una LIBRETA que solo se pone al dia al VOLVER A CASA: nada de
#  GPS en vivo. Mientras estas abajo enseña lo que sabias la ultima vez que subiste al pueblo;
#  lo que exploras esta expedicion no aparece hasta que vuelves (Game.capturar_mapa, la llaman
#  las salidas al pueblo). Por eso tampoco pinta TU posicion: no es un radar, es un plano.
#
#  Dibuja el snapshot congelado (Game.mapa_snapshot[piso]): las zonas cartografiadas, los nodos
#  que estaban vivos (con el color de su material) y los agotados (apagados, con la cuenta atras
#  hasta su respawn). La geometria (celdas de cada zona) sale de la semilla del piso vivo.
# ============================================================

extends CanvasLayer

const MARGEN := 60.0        # px de borde alrededor del mapa
const COLOR_FONDO := Color(0.04, 0.04, 0.06, 0.94)
const COLOR_SUELO := Color(0.24, 0.24, 0.30)      # zona explorada

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
	# La LIBRETA (congelada al ultimo regreso a casa), NO el estado en vivo: lo que exploras esta
	# expedicion no aparece hasta que vuelves al pueblo. La geometria (celdas de cada zona) sale
	# de la semilla del piso vivo, que es la misma de siempre.
	var snap: Dictionary = Game.mapa_snapshot.get(Game.current_floor, {})
	if snap.is_empty():
		var f0: Font = ThemeDB.fallback_font
		_lienzo.draw_string(f0, Vector2(MARGEN, 90.0),
			"Aún no has cartografiado este piso. Explóralo y vuelve a casa.",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.7, 0.7, 0.75))
		return
	var vistas: Dictionary = snap["zonas"]
	var agotados: Dictionary = snap["agotados"]

	# Escala: que el mapa entero quepa en la pantalla con margen, manteniendo proporcion.
	var area := get_viewport().get_visible_rect().size - Vector2(MARGEN, MARGEN) * 2.0
	var celda_px: float = minf(area.x / float(gen.ancho), area.y / float(gen.alto))
	var offset := Vector2(MARGEN, MARGEN) \
		+ (area - Vector2(gen.ancho, gen.alto) * celda_px) * 0.5

	# 1) SUELO de las zonas cartografiadas (la niebla es no dibujar el resto).
	for i in range(gen.zonas.size()):
		if not vistas.has(i):
			continue
		for c in (gen.zonas[i]["celdas"] as Array):
			var p: Vector2 = offset + Vector2(c) * celda_px
			_lienzo.draw_rect(Rect2(p, Vector2(celda_px, celda_px)), COLOR_SUELO)

	# 2) NODOS que estaban VIVOS al cartografiar: color del material (congelado en la libreta).
	for n in (snap["vivos"] as Array):
		_punto(offset, celda_px, n["cell"], n["color"], 0.42)

	# 3) NODOS AGOTADOS al cartografiar: apagados + cuenta atras hasta el respawn.
	var font: Font = ThemeDB.fallback_font
	for celda in agotados:
		var falta: float = RESPAWN() - (Game.tiempo_mazmorra - float(agotados[celda]))
		if falta <= 0.0:
			continue   # ya le toca volver
		var p: Vector2 = offset + (Vector2(celda) + Vector2(0.5, 0.5)) * celda_px
		_lienzo.draw_circle(p, celda_px * 0.30, Color(0.4, 0.4, 0.42, 0.7))
		_lienzo.draw_string(font, p + Vector2(celda_px * 0.4, -celda_px * 0.4),
			"%dm" % int(ceil(falta / 60.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(0.7, 0.7, 0.75))


func _punto(offset: Vector2, celda_px: float, celda: Vector2i, color: Color, radio_frac: float) -> void:
	var p: Vector2 = offset + (Vector2(celda) + Vector2(0.5, 0.5)) * celda_px
	_lienzo.draw_circle(p, celda_px * radio_frac, color)


# El respawn vive en DungeonFloor; se lee de alli para no duplicar la constante.
func RESPAWN() -> float:
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	return piso.RESPAWN_SEGUNDOS if piso != null else 600.0
