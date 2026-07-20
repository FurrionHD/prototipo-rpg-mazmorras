# ============================================================
#  altar_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  MENU DEL ALTAR. Lo abre altar.gd (F sobre el altar). Dos cosas, SEPARADAS a proposito:
#
#   - CURAR: pasa solo con INTERACTUAR. Al abrir el altar, todo el grupo queda con la vida, el
#     maná, el aguante y los cooldowns a tope. No hay que pulsar nada: descansar en el altar cura.
#
#   - ACTUALIZAR ESTADO (consolidar): es INDIVIDUAL, uno cada vez, en SU pestaña. Consolidar es
#     lo que pasa la excelia ganada de "pendiente" a "visible" (la stat que se ve y usa el
#     combate). Va por cabeza: solo entrena/consolida/sube el que controlas, asi que para
#     consolidar a un companero se abre SU pestaña.
#
#   - SUBIR DE NIVEL (solo el LIDER, si puede): abre el selector de desarrollo. El nivel sigue
#     siendo del que llevas en cabeza; a un companero se le sube poniendolo delante (teclas 1/2/3).
# ============================================================

extends CanvasLayer

const STATS := ["fuerza", "resistencia", "destreza", "agilidad", "magia"]
const NOMBRES := {"fuerza": "Fuerza", "resistencia": "Resistencia", "destreza": "Destreza",
	"agilidad": "Agilidad", "magia": "Magia"}

var _root: Control = null
var _content: VBoxContainer = null
var _side: VBoxContainer = null            # barra lateral: aqui van las pestañas de personaje
var _tab_buttons: Array = []
var _pj_sel: int = 0                       # a quien le estas mirando la pestaña (indice en Game.party)
# Antes→despues del ultimo "Actualizar" POR PERSONAJE: {PersonajeData: [[nombre, antes, desp]...]}.
# Por persona y no global para que cada pestaña enseñe SUS cambios y no los del ultimo que tocaste.
var _deltas: Dictionary = {}
var _aviso: String = ""


func _ready() -> void:
	layer = 93
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para: hay que seguir respondiendo
	add_to_group("altar_menu")
	var m: Dictionary = MenuScaffold.construir(self, "ALTAR",
		"Descansar cura a todo el grupo. Cada uno consolida su estado en su pestaña.", _cerrar)
	_root = m["root"]
	_content = m["content"]
	_side = m["side"]
	(m["lista_scroll"] as ScrollContainer).visible = false


func abrir() -> void:
	if Game._active_layer != null or Game.debug_panel_open:
		return
	_pj_sel = 0
	_deltas = {}
	# CURAR al interactuar: todo el grupo, sin pulsar nada. -1 = "a tope" (se concreta al crear el
	# combatiente / al refrescar las barras). Los cooldowns tambien: descansar es descansar.
	for pj in Game.party:
		pj.current_hp = -1.0
		pj.current_mp = -1.0
		pj.stamina = -1.0
	Game.ability_cooldowns_persist.clear()
	_aviso = ("Descansas: vida, maná y aguante a tope." if Game.party.size() == 1
		else "Descansa el grupo (%d): vida, maná y aguante a tope." % Game.party.size())
	_root.visible = true
	Game.abrir_menu()   # para el mundo entero mientras el menu esta abierto
	_rebuild_tabs()
	_rebuild()


func _cerrar() -> void:
	_root.visible = false
	Game.cerrar_menu()


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_cerrar()
			get_viewport().set_input_as_handled()


# El personaje cuya pestaña se esta viendo. Con el party vacio (imposible en la practica) cae al
# lider, que Game garantiza que existe siempre.
func _pj() -> PersonajeData:
	if _pj_sel < 0 or _pj_sel >= Game.party.size():
		_pj_sel = 0
	return Game.party[_pj_sel] if not Game.party.is_empty() else Game.lider()


# Una pestaña por miembro del grupo, con el numero que lo pone en cabeza (1/2/3) delante para que
# se lea igual que la tecla. Con una sola persona no se pintan: un boton solo no elige nada.
func _rebuild_tabs() -> void:
	for c in _side.get_children():
		c.queue_free()
	_tab_buttons.clear()
	if Game.party.size() <= 1:
		return
	for i in Game.party.size():
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, Game.party[i].nombre]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 34)
		b.pressed.connect(_on_tab.bind(i))
		_side.add_child(b)
		_tab_buttons.append(b)


func _on_tab(i: int) -> void:
	_pj_sel = i
	_rebuild()


# La llama el selector de desarrollo tras subir de nivel: refresca y enseña el reset. El nivel es
# del LIDER, asi que la subida se muestra en SU pestaña.
func mostrar_subida() -> void:
	if not _root.visible:
		return
	_pj_sel = maxi(0, Game.party.find(Game.lider()))
	# Tras subir, el visible es 0 en todas: mostramos el reset explicito (-1 = "reset por subida").
	var d: Array = []
	for s in STATS:
		d.append([NOMBRES[s], -1, 0])
	_deltas[Game.lider()] = d
	_aviso = "¡%s sube a nivel %d! Su poder quedó grabado en su base; sus habilidades vuelven a rango I." % [
		Game.lider().nombre, Game.player_level]
	_rebuild()


func _rebuild() -> void:
	for c in _content.get_children():
		c.queue_free()
	for i in _tab_buttons.size():
		(_tab_buttons[i] as Button).button_pressed = (i == _pj_sel)

	var pj: PersonajeData = _pj()
	var es_lider: bool = pj == Game.lider()

	MenuScaffold.titulo(_content, "%s  ·  Nivel %d" % [pj.nombre, pj.level])
	if _aviso != "":
		MenuScaffold.nota(_content, _aviso)
	_content.add_child(HSeparator.new())

	# Habilidades VISIBLES actuales (rango de este nivel) de ESTE personaje.
	for s in STATS:
		var v: int = int(pj.get(s))
		MenuScaffold.fila(_content, NOMBRES[s], "%d  (%s)" % [v, Abilities.rank_letter(v)])

	_content.add_child(HSeparator.new())

	var b_act := Button.new()
	b_act.text = "Actualizar estado (consolidar)"
	b_act.custom_minimum_size = Vector2(0, 38)
	b_act.pressed.connect(_actualizar.bind(pj))
	_content.add_child(b_act)

	# SUBIR DE NIVEL: solo el que va en cabeza. A un companero se le sube poniendolo delante.
	if es_lider and Game.puede_subir_nivel():
		var b_lvl := Button.new()
		b_lvl.text = "★ Subir de nivel  (Nv %d → %d)" % [pj.level, pj.level + 1]
		b_lvl.custom_minimum_size = Vector2(0, 40)
		b_lvl.pressed.connect(_subir)
		_content.add_child(b_lvl)
	elif es_lider and Game.guardianes_vencidos.get(pj.level + 1, false):
		MenuScaffold.nota(_content, "Venciste al guardián del rango, pero aún te falta llegar a rango C en alguna habilidad para ascender.")
	elif not es_lider:
		MenuScaffold.nota(_content, "Subir de nivel es del que va en cabeza. Para subir a %s, ponlo delante con la tecla %d." % [
			pj.nombre, _pj_sel + 1])

	# Antes→después del ultimo "Actualizar" de ESTE personaje (o el reset de su subida).
	var delta: Array = _deltas.get(pj, [])
	if not delta.is_empty():
		_content.add_child(HSeparator.new())
		MenuScaffold.titulo(_content, "Cambios:", 14)
		for d in delta:
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


# Consolida SOLO a este personaje: pasa su excelia pendiente a visible. Ya NO cura (eso pasa al
# abrir el altar, y a todo el grupo).
func _actualizar(pj: PersonajeData) -> void:
	var antes: Dictionary = {}
	for s in STATS:
		antes[s] = int(pj.get(s))
	Game.actualizar_estado(pj)
	var d: Array = []
	for s in STATS:
		d.append([NOMBRES[s], antes[s], int(pj.get(s))])
	_deltas[pj] = d
	_aviso = "%s consolida su estado." % pj.nombre
	_rebuild()


func _subir() -> void:
	var menu: Node = get_tree().get_first_node_in_group("desarrollo_menu")
	if menu != null and menu.has_method("abrir"):
		_cerrar()          # el selector toma el control (evita dos menus con inventory_open)
		menu.abrir()
