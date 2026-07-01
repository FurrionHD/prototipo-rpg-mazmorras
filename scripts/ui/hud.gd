# ============================================================
#  hud.gd  (CanvasLayer creada por codigo desde el jugador)
#  HUD de exploracion:
#   - Contador SIEMPRE visible (arriba-izquierda): cristales y drops.
#   - Panel de INVENTARIO que se abre/cierra con la tecla I: lista de
#     cristales y drops (categoria/calidad) y el valor total estimado.
#  Lee los datos del autoload Game (Game.crystals / Game.drops).
# ============================================================

extends CanvasLayer

var _counts: Label = null
var _panel: ColorRect = null
var _list: Label = null
var _panel_open: bool = false
var _toggle_was: bool = false


func _ready() -> void:
	layer = 5  # por encima de la mazmorra, por debajo del combate (100)

	# Contador siempre visible (debajo de la barra de aguante).
	_counts = Label.new()
	_counts.position = Vector2(12, 34)
	add_child(_counts)

	# Panel de inventario (oculto por defecto), a pantalla completa oscura.
	_panel = ColorRect.new()
	_panel.color = Color(0.05, 0.05, 0.08, 0.9)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	add_child(_panel)

	_list = Label.new()
	_list.position = Vector2(60, 50)
	_panel.add_child(_list)


func _process(_delta: float) -> void:
	# Actualiza el contador (con peso/capacidad).
	_counts.text = "Cristales: %d   Drops: %d   Peso: %d/%d   [I] Inventario" % [
		Game.crystals.size(), Game.drops.size(),
		roundi(Game.peso_actual()), roundi(Game.capacidad_carga())]
	if Game.esta_sobrecargado():
		_counts.text += "   (SOBRECARGADO)"
		_counts.modulate = Color(1.0, 0.5, 0.5)
	else:
		_counts.modulate = Color.WHITE

	# Alterna el panel con la tecla I.
	var t: bool = Input.is_key_pressed(KEY_I)
	if t and not _toggle_was:
		_panel_open = not _panel_open
		_panel.visible = _panel_open
		Game.inventory_open = _panel_open  # bloquea/desbloquea al jugador
	_toggle_was = t

	# Refresca la lista en vivo mientras esta abierto.
	if _panel_open:
		_refrescar_lista()


func _refrescar_lista() -> void:
	var total: int = 0
	var s: String = "INVENTARIO   ( [I] para cerrar )\n\n"

	s += "CRISTALES (%d):\n" % Game.crystals.size()
	if Game.crystals.is_empty():
		s += "  (vacio)\n"
	for c in Game.crystals:
		s += "  - Categoria %d  (%s)   ~%d\n" % [c.categoria, c.calidad_texto(), c.valor_estimado()]
		total += c.valor_estimado()

	s += "\nDROPS (%d):\n" % Game.drops.size()
	if Game.drops.is_empty():
		s += "  (vacio)\n"
	for d in Game.drops:
		s += "  - %s  (%s)   ~%d\n" % [d.nombre, d.calidad_texto(), d.valor_estimado()]
		total += d.valor_estimado()

	s += "\nVALOR TOTAL ESTIMADO: %d" % total
	s += "\nPESO: %d / %d" % [roundi(Game.peso_actual()), roundi(Game.capacidad_carga())]
	if Game.esta_sobrecargado():
		s += "   (SOBRECARGADO: vas mas lento)"

	# Habilidades: valor VISIBLE (en combate) / INTERNO (acumulado por uso).
	var ai: Dictionary = Game.ability_internal
	s += "\n\nHABILIDADES (visible / interno):\n"
	s += "  Fuerza:     %d / %.1f\n" % [Game.player_fuerza, ai["fuerza"]]
	s += "  Resistencia:%d / %.1f\n" % [Game.player_resistencia, ai["resistencia"]]
	s += "  Destreza:   %d / %.1f\n" % [Game.player_destreza, ai["destreza"]]
	s += "  Agilidad:   %d / %.1f\n" % [Game.player_agilidad, ai["agilidad"]]
	s += "  Magia:      %d / %.1f\n" % [Game.player_magia, ai["magia"]]
	s += "\n[U] actualizar estado (hogar)   [H] curar 100%   [R] respawn"

	_list.text = s
