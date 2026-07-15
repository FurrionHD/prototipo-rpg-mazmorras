# ============================================================
#  map_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  MAPA (tecla M). Es una LIBRETA autonoma: dibuja el snapshot congelado
#  (Game.mapa_snapshot[piso]) que se pone al dia al ABANDONAR cada piso. Nada de GPS en vivo
#  (no pinta TU posicion): es un plano de lo ya recorrido. Como la libreta hornea la geometria,
#  el mapa se puede abrir TAMBIEN en el pueblo y HOJEAR otros pisos ya explorados (◀ ▶).
#
#  Solo aparecen los pisos REALMENTE explorados (los que tienen snapshot). Al morir, lo
#  cartografiado esa expedicion se pierde (ver Game.revertir_mapa_expedicion).
# ============================================================

extends CanvasLayer

const MARGEN := 60.0        # px de borde alrededor del mapa
const COLOR_FONDO := Color(0.04, 0.04, 0.06, 0.94)
const COLOR_SUELO := Color(0.24, 0.24, 0.30)      # zona explorada

var _root: Control = null
var _lienzo: Control = null
var _titulo: Label = null
var _piso_viendo: int = 1   # piso cuyo mapa se esta MIRANDO (independiente de Game.current_floor)


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

	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size", 18)
	_titulo.position = Vector2(MARGEN, 20.0)
	_root.add_child(_titulo)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var code: int = (event as InputEventKey).keycode
	if code == KEY_M:
		_toggle()
	elif not _root.visible:
		return
	elif code == KEY_ESCAPE:
		_cerrar()
	elif code == KEY_LEFT or code == KEY_A:
		_cambiar_viendo(-1)
	elif code == KEY_RIGHT or code == KEY_D:
		_cambiar_viendo(1)


func _toggle() -> void:
	if _root.visible:
		_cerrar()
		return
	# No sobre un combate/extraccion ni con el DEBUG abierto. Ya NO exige piso vivo: se abre
	# tambien en el pueblo (la libreta es autonoma, no necesita el DungeonFloor delante).
	if Game._active_layer != null or Game.debug_panel_open:
		return
	# Empieza mirando el piso actual si tiene mapa; si no (p.ej. en el pueblo), el mas profundo
	# ya cartografiado.
	var pisos: Array = _pisos_disponibles()
	if Game.mapa_snapshot.has(Game.current_floor):
		_piso_viendo = Game.current_floor
	elif not pisos.is_empty():
		_piso_viendo = pisos[-1]
	else:
		_piso_viendo = Game.current_floor
	_root.visible = true
	Game.inventory_open = true   # congela al jugador mientras miras el mapa
	_refrescar()


func _cerrar() -> void:
	_root.visible = false
	Game.inventory_open = false


# Pisos con mapa (los REALMENTE explorados), ordenados. Es la lista por la que se hojea.
func _pisos_disponibles() -> Array:
	var out: Array = Game.mapa_snapshot.keys()
	out.sort()
	return out


# Salta al piso cartografiado anterior/siguiente (dir = -1/+1). Solo entre los explorados.
func _cambiar_viendo(dir: int) -> void:
	var pisos: Array = _pisos_disponibles()
	var idx: int = pisos.find(_piso_viendo)
	if idx == -1:
		if pisos.is_empty():
			return
		_piso_viendo = pisos[0]
	else:
		var nuevo: int = clampi(idx + dir, 0, pisos.size() - 1)
		_piso_viendo = pisos[nuevo]
	_refrescar()


func _refrescar() -> void:
	var pisos: Array = _pisos_disponibles()
	var hay_mas: bool = pisos.size() > 1
	var flechas: String = "   ◀ ▶ pisos" if hay_mas else ""
	_titulo.text = "MAPA · Piso %d%s   ·  [M] cerrar" % [_piso_viendo, flechas]
	_lienzo.queue_redraw()


func _dibujar() -> void:
	var snap: Dictionary = Game.mapa_snapshot.get(_piso_viendo, {})
	# Sin snapshot, o uno viejo sin la geometria horneada (saves anteriores): nada que dibujar.
	if snap.is_empty() or not snap.has("suelo"):
		var f0: Font = ThemeDB.fallback_font
		_lienzo.draw_string(f0, Vector2(MARGEN, 90.0),
			"Aún no has cartografiado este piso. Explóralo y sal con vida.",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.7, 0.7, 0.75))
		return

	var ancho: int = int(snap["ancho"])
	var alto: int = int(snap["alto"])
	var agotados: Dictionary = snap["agotados"]

	# Escala: que el mapa entero quepa en la pantalla con margen, manteniendo proporcion.
	var area := get_viewport().get_visible_rect().size - Vector2(MARGEN, MARGEN) * 2.0
	var celda_px: float = minf(area.x / float(ancho), area.y / float(alto))
	var offset := Vector2(MARGEN, MARGEN) \
		+ (area - Vector2(ancho, alto) * celda_px) * 0.5

	# 1) SUELO de las zonas cartografiadas (horneado en la libreta; la niebla es no dibujar el resto).
	for c in (snap["suelo"] as Array):
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


# El respawn vive en DungeonFloor; se lee de alli si hay piso vivo (en el pueblo, la reserva).
func RESPAWN() -> float:
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	return piso.RESPAWN_SEGUNDOS if piso != null else 600.0
