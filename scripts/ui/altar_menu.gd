# ============================================================
#  altar_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  MENU DEL ALTAR. Lo abre altar.gd (F sobre el altar). Permite:
#   - "Actualizar estado" (descansar): consolida lo interno en lo visible, cura vida/maná y
#     reinicia cooldowns, y muestra el ANTES→DESPUÉS de cada habilidad (más gráfico).
#   - "Subir de nivel" (solo si Game.puede_subir_nivel()): abre el selector de desarrollo.
# ============================================================

extends CanvasLayer

const STATS := ["fuerza", "resistencia", "destreza", "agilidad", "magia"]
const NOMBRES := {"fuerza": "Fuerza", "resistencia": "Resistencia", "destreza": "Destreza",
	"agilidad": "Agilidad", "magia": "Magia"}

var _root: Control = null
var _content: VBoxContainer = null
var _ultimo_delta: Array = []   # [[nombre, antes, despues]...] del ultimo "actualizar" / subida
var _aviso: String = ""


func _ready() -> void:
	layer = 93
	add_to_group("altar_menu")
	var m: Dictionary = MenuScaffold.construir(self, "ALTAR",
		"Descansa: consolidas tu estado, curas vida y maná, y reinicias los cooldowns.", _cerrar)
	_root = m["root"]
	_content = m["content"]
	(m["lista_scroll"] as ScrollContainer).visible = false


func abrir() -> void:
	if Game._active_layer != null or Game.debug_panel_open:
		return
	_ultimo_delta = []
	_aviso = ""
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


# La llama el selector de desarrollo tras subir de nivel: refresca y enseña el reset.
func mostrar_subida() -> void:
	if not _root.visible:
		return
	# Tras subir, el visible es 0 en todas: mostramos el reset explicito (-1 = "reset por subida").
	_ultimo_delta = []
	for s in STATS:
		_ultimo_delta.append([NOMBRES[s], -1, 0])
	_aviso = "¡Has subido a nivel %d! Tu poder quedó grabado en tu base; tus habilidades vuelven a rango I." % Game.player_level
	_rebuild()


func _rebuild() -> void:
	for c in _content.get_children():
		c.queue_free()

	MenuScaffold.titulo(_content, "ALTAR  ·  Nivel %d" % Game.player_level)
	if _aviso != "":
		MenuScaffold.nota(_content, _aviso)
	_content.add_child(HSeparator.new())

	# Habilidades VISIBLES actuales (rango de este nivel).
	for s in STATS:
		var v: int = int(Game.get("player_" + s))
		MenuScaffold.fila(_content, NOMBRES[s], "%d  (%s)" % [v, Abilities.rank_letter(v)])

	_content.add_child(HSeparator.new())

	var b_act := Button.new()
	b_act.text = "Actualizar estado (descansar)"
	b_act.custom_minimum_size = Vector2(0, 38)
	b_act.pressed.connect(_actualizar)
	_content.add_child(b_act)

	if Game.puede_subir_nivel():
		var b_lvl := Button.new()
		b_lvl.text = "★ Subir de nivel  (Nv %d → %d)" % [Game.player_level, Game.player_level + 1]
		b_lvl.custom_minimum_size = Vector2(0, 40)
		b_lvl.pressed.connect(_subir)
		_content.add_child(b_lvl)
	elif Game.guardianes_vencidos.get(Game.player_level + 1, false):
		MenuScaffold.nota(_content, "Venciste al guardián del rango, pero aún te falta llegar a rango C en alguna habilidad para ascender.")

	# Antes→después del ultimo "Actualizar" (o el reset de la subida).
	if not _ultimo_delta.is_empty():
		_content.add_child(HSeparator.new())
		MenuScaffold.titulo(_content, "Cambios:", 14)
		for d in _ultimo_delta:
			var antes: int = int(d[1])
			var desp: int = int(d[2])
			var txt: String
			if antes < 0:
				txt = "→ %d  (reinicio por subir de nivel)" % desp
			else:
				txt = "%d → %d" % [antes, desp]
				if desp > antes:
					txt += "  (+%d)" % (desp - antes)
			MenuScaffold.fila(_content, str(d[0]), txt)


func _actualizar() -> void:
	var antes: Dictionary = {}
	for s in STATS:
		antes[s] = int(Game.get("player_" + s))
	Game.actualizar_estado()
	Game.player_current_hp = -1.0
	Game.player_current_mp = -1.0
	Game.ability_cooldowns_persist.clear()
	_ultimo_delta = []
	for s in STATS:
		_ultimo_delta.append([NOMBRES[s], antes[s], int(Game.get("player_" + s))])
	_aviso = "Estado consolidado. Vida, maná y cooldowns a tope."
	_rebuild()


func _subir() -> void:
	var menu: Node = get_tree().get_first_node_in_group("desarrollo_menu")
	if menu != null and menu.has_method("abrir"):
		_cerrar()          # el selector toma el control (evita dos menus con inventory_open)
		menu.abrir()
