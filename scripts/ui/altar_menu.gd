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
# Lo que SALIO A LA LUZ en ese mismo "Actualizar", tambien por persona:
#   _nuevas_pasivas[pj]  -> Array de dicts de Game.PASIVAS_RNG
#   _subidas_des[pj]     -> Array de [nombre, rango_antes, rango_despues]
# Actualizar el estado es el momento en que te enteras de lo que ha cambiado en ti: una pasiva que
# te toco picando piedra hace tres dias se entera AQUI, no en el momento de la tirada.
var _nuevas_pasivas: Dictionary = {}
var _subidas_des: Dictionary = {}
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
	MenuScaffold.solo_detalle(m)   # sin cuadricula: el detalle solo, centrado y legible


func abrir() -> void:
	if Game._active_layer != null or Game.debug_panel_open:
		return
	_pj_sel = 0
	_deltas = {}
	_nuevas_pasivas = {}
	_subidas_des = {}
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
	Game.abrir_menu(self)   # para el mundo entero mientras el menu esta abierto
	_rebuild_tabs()
	_rebuild()


func _cerrar() -> void:
	_root.visible = false
	Game.cerrar_menu(self)


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_cerrar()
			get_viewport().set_input_as_handled()


# TODOS a los que se puede consolidar: los que bajan contigo Y los que esperan en el hogar.
#
# El banquillo esta aqui porque los ENCARGOS les dan excelia sin que bajen a ningun sitio, y
# `ganar()` escribe en ability_internal SIN consolidar (a proposito: consolidar gratis se cargaria
# el altar). Antes el altar solo pintaba pestañas del party, asi que esa excelia no habia forma de
# verla ni de cobrarla: se quedaba invisible para siempre.
func _pjs() -> Array:
	var out: Array = []
	for pj in Game.party:
		out.append(pj)
	for pj in Game.en_el_banquillo():
		out.append(pj)
	return out


# El personaje cuya pestaña se esta viendo. Con el party vacio (transitorio, con el Hogar abierto)
# cae al lider, que Game garantiza que existe siempre.
func _pj() -> PersonajeData:
	var todos: Array = _pjs()
	if _pj_sel < 0 or _pj_sel >= todos.size():
		_pj_sel = 0
	return todos[_pj_sel] if not todos.is_empty() else Game.lider()


# Una pestaña por persona. Los del EQUIPO llevan el numero que los pone en cabeza (1/2/3), para que
# se lea igual que la tecla; los de casa van detras con una casita y sin numero, porque no tienen
# tecla que pulsar. Un punto ambar marca a quien tiene algo sin consolidar.
func _rebuild_tabs() -> void:
	MenuScaffold.vaciar(_side)
	_tab_buttons.clear()
	var todos: Array = _pjs()
	if todos.size() <= 1:
		return   # un boton solo no elige nada
	var n_equipo: int = Game.party.size()
	for i in todos.size():
		var pj: PersonajeData = todos[i]
		var b := Button.new()
		var marca: String = " ·" if Game.tiene_pendiente(pj) else ""
		if i < n_equipo:
			var corona: String = "👑 " if pj == Game.lider() else ""
			b.text = "%d. %s%s%s" % [i + 1, corona, pj.nombre, marca]
		else:
			var fuera: bool = Game.esta_de_encargo(pj)
			b.text = "🏠 %s%s%s" % [pj.nombre, "  (de encargo)" if fuera else "", marca]
			b.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
		if Game.tiene_pendiente(pj):
			b.tooltip_text = "Tiene experiencia sin consolidar: ábrele la ficha y actualízale el estado."
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
	_pj_sel = maxi(0, _pjs().find(Game.lider()))
	# Tras subir, el visible es 0 en todas: mostramos el reset explicito (-1 = "reset por subida").
	var d: Array = []
	for s in STATS:
		d.append([NOMBRES[s], -1, 0])
	_deltas[Game.lider()] = d
	_aviso = "¡%s sube a nivel %d! Su poder quedó grabado en su base; sus habilidades vuelven a rango I." % [
		Game.lider().nombre, Game.player_level]
	_rebuild()


# Guardia de REENTRADA. Un _rebuild puede entrar mientras otro esta a medias (el focus_exited de un
# stepper al liberarlo, las señales de red, un _on_* que espera en un await), y entonces el de dentro
# pinta su panel y el de fuera apila el suyo debajo: el menu salia DUPLICADO. Es el mismo guardia que
# lleva el herrero desde que se cazo alli.
var _reconstruyendo := false

func _rebuild() -> void:
	if _reconstruyendo:
		return
	_reconstruyendo = true
	_rebuild_real()
	_reconstruyendo = false


func _rebuild_real() -> void:
	MenuScaffold.vaciar(_content)
	for i in _tab_buttons.size():
		(_tab_buttons[i] as Button).button_pressed = (i == _pj_sel)

	var pj: PersonajeData = _pj()
	var es_lider: bool = pj == Game.lider()

	var donde: String = ""
	if not Game.party.has(pj):
		donde = "  ·  de encargo" if Game.esta_de_encargo(pj) else "  ·  en el Hogar"
	MenuScaffold.titulo(_content, "%s  ·  Nivel %d%s" % [pj.nombre, pj.level, donde])
	if _aviso != "":
		MenuScaffold.nota(_content, _aviso)
	if Game.tiene_pendiente(pj):
		MenuScaffold.nota(_content, "Tiene experiencia sin consolidar. Actualízale el estado para "
			+ "que se le vea en las habilidades.")
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
		if Game.party.has(pj):
			MenuScaffold.nota(_content, "Subir de nivel es del que va en cabeza. Para subir a %s, ponlo delante con la tecla %d." % [
				pj.nombre, _pj_sel + 1])
		else:
			# Los de casa SI pueden consolidar (es como se cobra lo que ganan en los encargos), pero
			# ni descansan ni suben de nivel: para eso hay que bajarlos a la mazmorra.
			MenuScaffold.nota(_content, "%s espera en el Hogar. Aquí puede consolidar lo que haya "
				% pj.nombre + "aprendido, pero para descansar o subir de nivel tiene que bajar "
				+ "contigo: mételo en el equipo desde el Hogar.")

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

	_bloque_revelado(pj)


# Lo que ha SALIDO A LA LUZ al actualizar el estado, debajo de los cambios de habilidad. Aqui es
# donde te enteras de que tienes una pasiva: la tirada cayo hace tres dias picando una veta y no
# hubo aviso ninguno (ver Game.rodar_pasiva), asi que este es literalmente el unico sitio del juego
# donde aparece por primera vez. Por eso va con el nombre en amarillo y centelleando, como un
# objeto legendario: es lo mas raro que te puede pasar en una partida (1 entre 500.000 por accion).
func _bloque_revelado(pj: PersonajeData) -> void:
	var pasivas: Array = _nuevas_pasivas.get(pj, [])
	var subidas: Array = _subidas_des.get(pj, [])
	if pasivas.is_empty() and subidas.is_empty():
		return

	if not pasivas.is_empty():
		_content.add_child(HSeparator.new())
		MenuScaffold.titulo(_content, "★ HABILIDAD PASIVA DESPERTADA", 15)
		for p in pasivas:
			# Amarillo legendario, el tope de la paleta comun (ver Upgrades.RAREZA_COLOR).
			MenuScaffold.titulo_item(_content, str(p.get("nombre", "")), Upgrades.rareza_color(4), 1.0)
			MenuScaffold.nota(_content, Game.pasiva_desc(p))

	if not subidas.is_empty():
		_content.add_child(HSeparator.new())
		MenuScaffold.titulo(_content, "Desarrollo:", 14)
		for s in subidas:
			MenuScaffold.fila(_content, str(s[0]), "%s → %s" % [
				Game.letra_rango(int(s[1])) if int(s[1]) > 0 else "—",
				Game.letra_rango(int(s[2]))])


# Consolida SOLO a este personaje: pasa su excelia pendiente a visible. Ya NO cura (eso pasa al
# abrir el altar, y a todo el grupo).
func _actualizar(pj: PersonajeData) -> void:
	var antes: Dictionary = {}
	for s in STATS:
		antes[s] = int(pj.get(s))
	# Lo que devuelve es lo que ha salido a la luz al leer el estado: pasivas que te habian tocado
	# sin saberlo y desarrollos que han subido de rango.
	var revelado: Dictionary = Game.actualizar_estado(pj)
	var d: Array = []
	for s in STATS:
		d.append([NOMBRES[s], antes[s], int(pj.get(s))])
	_deltas[pj] = d
	_nuevas_pasivas[pj] = revelado.get("pasivas", [])
	_subidas_des[pj] = revelado.get("desarrollos", [])
	_aviso = "%s consolida su estado." % pj.nombre
	_rebuild()


func _subir() -> void:
	var menu: Node = get_tree().get_first_node_in_group("desarrollo_menu")
	if menu != null and menu.has_method("abrir"):
		_cerrar()          # el selector toma el control (evita dos menus con inventory_open)
		menu.abrir()
