# ============================================================
#  character_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  Menu de PERSONAJE a PANTALLA COMPLETA (estilo Genshin/Honkai), tecla C.
#  Barra de pestañas VERTICAL a la izquierda + contenido a la derecha:
#    1) PERSONAJE - stats de combate calculadas; el boton ⇄ alterna con las 5
#                   habilidades DanMachi.
#    2) ARMAS     - arma principal/secundaria equipadas y sus stats. Boton
#                   "Cambiar" -> CUADRICULA de armas + panel de stats a la derecha
#                   + "Equipar". Solo en el pueblo.
#    3) ARMADURA  - 5 slots; entras en uno, ves stats/mejoras y "Cambiar" abre la
#                   misma cuadricula con los materiales. Solo en el pueblo.
#  Al entrar en "Cambiar", viene preseleccionado lo equipado (siempre hay stats).
#  Pausa el juego mientras esta abierto. UI por codigo (placeholder).
# ============================================================

extends CanvasLayer

# Solo ARMADURA. La mochila estuvo aqui de prestado (se equipa parecido y era donde se iba a
# buscar), pero es del GRUPO y no de un personaje: verla en una ficha personal, al lado de cinco
# slots que si son de esa persona, hacia creer que cada uno llevaba la suya. Se mudo al inventario [I].
const ARMOR_SLOTS := ["casco", "pecho", "manos", "pantalones", "botas"]
const ARMOR_SLOT_LABELS := {
	"casco": "Casco", "pecho": "Pecho", "manos": "Manos",
	"pantalones": "Pantalones", "botas": "Botas"}
const WEAPON_TIPO_LABELS := ["Puños", "Daga", "Espada corta", "Espada larga", "Mandoble",
	"Estoque", "Hacha grande", "Maza pequeña", "Martillo grande", "Bastón"]

var _root: Control = null
var _content: VBoxContainer = null        # cuerpo (derecha) que se reconstruye
var _tab_buttons: Array = []              # botones de pestaña (izquierda)

var _tab_box: VBoxContainer = null        # contenedor de los botones de pestaña
var _tab: int = 0                         # 0 personaje, 1 armas, 2 armadura, 3 hechizos
# A QUIEN del equipo le estas mirando la ficha (indice en Game.party). 0 = el que va en cabeza.
# Con companeros, este menu deja de ser "tu ficha" y pasa a ser la de cualquiera de los tuyos:
# la fila de botones de arriba elige, y todo lo que se pinta debajo sale de _pj().
var _pj_sel: int = 0
var _titulo_lbl: Label = null              # el nombre del personaje, arriba a la izquierda
var _spell_sel: int = 0                   # hechizo seleccionado en la pestaña Hechizos
var _char_page: int = 0                   # 0 stats, 1 habilidades
var _arma_change: String = ""             # "" | "main" | "off"
var _arma_cand: int = 0                   # indice del candidato en el catalogo
var _armor_slot_sel: String = ""          # "" = lista de slots | slot abierto en cuadricula
var _armor_cand: int = 0                  # indice de la pieza candidata en el catalogo del slot


func _ready() -> void:
	layer = 92
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

	# Fondo opaco a pantalla completa.
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.06, 0.08, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(bg)

	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 16
	hb.offset_top = 16
	hb.offset_right = -16
	hb.offset_bottom = -16
	hb.add_theme_constant_override("separation", 18)
	_root.add_child(hb)

	# --- Barra de pestañas VERTICAL a la izquierda ---
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(190, 0)
	side.add_theme_constant_override("separation", 6)
	hb.add_child(side)

	# El titulo es el NOMBRE de quien estas mirando, no la palabra "PERSONAJE": con un grupo,
	# saber de quien es la ficha que tienes delante importa mas que saber que es una ficha.
	_titulo_lbl = Label.new()
	_titulo_lbl.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36))
	_titulo_lbl.add_theme_font_size_override("font_size", 18)
	_titulo_lbl.clip_text = true
	side.add_child(_titulo_lbl)
	side.add_child(HSeparator.new())

	# Las pestañas se reconstruyen al ABRIR el menu (_rebuild_tabs): la de Hechizos solo
	# aparece si el personaje conoce alguno.
	_tab_box = VBoxContainer.new()
	_tab_box.add_theme_constant_override("separation", 6)
	side.add_child(_tab_box)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)
	var cerrar := Button.new()
	cerrar.text = "✕ Cerrar  (C)"
	cerrar.custom_minimum_size = Vector2(0, 34)
	cerrar.pressed.connect(_cerrar)
	side.add_child(cerrar)

	# --- Contenido (derecha) ---
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 8)
	hb.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 4)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)


# El personaje cuya ficha se esta viendo. Con el equipo vacio (imposible en la practica) cae al
# lider, que Game garantiza que existe siempre.
func _pj() -> PersonajeData:
	if _pj_sel < 0 or _pj_sel >= Game.party.size():
		_pj_sel = 0
	return Game.party[_pj_sel] if not Game.party.is_empty() else Game.lider()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var code: int = (event as InputEventKey).keycode
	if code == KEY_C:
		_toggle()
	elif code == KEY_ESCAPE and _root.visible:
		_cerrar()


func _toggle() -> void:
	if not _root.visible:
		if Game._active_layer != null or Game.inventory_open or Game.debug_panel_open:
			return
		_set_open(true)
	else:
		_set_open(false)


func _cerrar() -> void:
	_set_open(false)


func _set_open(open: bool) -> void:
	_root.visible = open
	get_tree().paused = open
	if open:
		_tab = 0
		_pj_sel = 0   # se abre siempre por el que va en cabeza
		_char_page = 0
		_arma_change = ""
		_armor_slot_sel = ""
		_spell_sel = 0
		_rebuild_tabs()   # la pestaña de Hechizos aparece/desaparece segun lo que sepas
		_rebuild()


# Reconstruye la barra de pestañas. "Hechizos" SOLO si el personaje conoce alguno.
func _rebuild_tabs() -> void:
	for c in _tab_box.get_children():
		c.queue_free()
	_tab_buttons.clear()
	var nombres: Array = ["Personaje", "Armas", "Armadura"]
	if Game.tiene_hechizos(_pj()):
		nombres.append("Hechizos")
	for i in nombres.size():
		var b := Button.new()
		b.text = str(nombres[i])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 34)
		b.pressed.connect(_on_tab.bind(i))
		_tab_box.add_child(b)
		_tab_buttons.append(b)


func _on_tab(i: int) -> void:
	_tab = i
	_arma_change = ""
	_armor_slot_sel = ""
	_rebuild()


func _rebuild() -> void:
	for c in _content.get_children():
		c.queue_free()
	for i in _tab_buttons.size():
		(_tab_buttons[i] as Button).button_pressed = (i == _tab)
	if _titulo_lbl != null:
		_titulo_lbl.text = _pj().nombre.to_upper()
	_selector_personaje()
	match _tab:
		0: _build_personaje()
		1: _build_armas()
		2: _build_armadura()
		3: _build_hechizos()


# La fila de arriba para elegir DE QUIEN es la ficha, con el mismo aspecto que los selectores de
# los oficios. Con una sola persona no se pinta: seria un boton solo que no elige nada.
#
# El numero delante del nombre es el MISMO que la tecla que lo pone en cabeza (1/2/3), para que
# las dos cosas se lean igual: el 2 de aqui es el 2 de alla.
func _selector_personaje() -> void:
	if Game.party.size() <= 1:
		return
	var labels: Array = []
	for i in Game.party.size():
		var corona: String = "👑 " if Game.party[i] == Game.lider() else ""
		labels.append("%d. %s%s" % [i + 1, corona, Game.party[i].nombre])
	MenuScaffold.cuadricula(_content, labels, _pj_sel, _pick_personaje,
		Game.PARTY_MAX, Vector2(150, 32))
	_content.add_child(HSeparator.new())


func _pick_personaje(i: int) -> void:
	if i == _pj_sel:
		return
	_pj_sel = i
	# Cambiar de persona invalida lo que estuvieras haciendo con la anterior (a medio elegir un
	# arma, con un slot de armadura abierto...): esas selecciones son de SU catalogo, no del nuevo.
	_arma_change = ""
	_armor_slot_sel = ""
	_spell_sel = 0
	_char_page = 0
	_rebuild_tabs()   # la pestaña de Hechizos depende de si ESTE sabe alguno
	if _tab >= _tab_buttons.size():
		_tab = 0
	_rebuild()


# ============================================================
#  ¿QUIEN LLEVA ESTO?
#  El baul es COMUN a todo el grupo, asi que la misma espada aparece en el catalogo de los tres.
#  Equiparsela a uno se la quita al otro (Game._quitar_a_los_demas): es lo que se quiere, pero
#  tiene que VERSE antes de pulsar, o le dejas a alguien en pelotas sin enterarte.
# ============================================================

# El companero que lleva PUESTO este objeto, o null si no lo lleva nadie mas. Nunca devuelve al
# personaje que estas mirando: que lo lleve el no es un conflicto, es el estado normal.
func _quien_lleva(item: Resource) -> PersonajeData:
	var otro: PersonajeData = Game.quien_lleva(item)
	return null if otro == _pj() else otro


# El nombre del item para la cuadricula, con una marca de quien lo lleva. El candado dice de un
# vistazo "esto se lo estas quitando a alguien" sin tener que leer el nombre entero.
func _etiqueta_con_dueno(item: Resource, base: String) -> String:
	var otro: PersonajeData = _quien_lleva(item)
	return base if otro == null else "%s\n🔒 %s" % [base, otro.nombre]


# Linea de aviso en la FICHA del objeto (arriba del todo, en rojo): quien lo lleva puesto. Va en
# la ficha ademas de en la cuadricula porque la cuadricula solo tiene sitio para el candado, y
# aqui es donde el jugador se para a mirar antes de pulsar Equipar.
func _aviso_dueno(vb: VBoxContainer, item: Resource) -> void:
	var otro: PersonajeData = _quien_lleva(item)
	if otro == null:
		return
	var l := Label.new()
	l.text = "🔒 Lo lleva puesto %s. Si lo equipas, se lo quitas." % otro.nombre
	l.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))
	l.add_theme_font_size_override("font_size", 12)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(l)


# Modal de "esto lo lleva puesto Fulano, ¿se lo quito?". Es un si/no y no un aviso pasivo a
# proposito: desnudar a un companero por un clic de mas es justo el error que hay que evitar, y
# al volver a la mazmorra ya no hay forma de deshacerlo.
func _confirmar_robo(item: Resource, al_aceptar: Callable) -> void:
	var otro: PersonajeData = _quien_lleva(item)
	if otro == null:
		al_aceptar.call()   # no lo lleva nadie: no hay nada que preguntar
		return

	var capa := Control.new()
	capa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.add_child(capa)

	var fondo := ColorRect.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.03, 0.03, 0.05, 0.85)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	capa.add_child(fondo)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.custom_minimum_size = Vector2(420, 0)
	panel.add_child(vb)

	var t := Label.new()
	t.text = "Lo lleva puesto %s" % otro.nombre
	t.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36))
	t.add_theme_font_size_override("font_size", 18)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)

	var d := Label.new()
	d.text = "%s se lo quitará a %s, que se quedará con ese hueco vacío." % [
		_pj().nombre, otro.nombre]
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
	d.add_theme_font_size_override("font_size", 12)
	vb.add_child(d)

	var it := Label.new()
	it.text = Game.item_display_name(item)
	it.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(it)

	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 8)
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(botones)

	var si := Button.new()
	si.text = "Sí, quitárselo"
	si.custom_minimum_size = Vector2(0, 36)
	si.pressed.connect(func():
		capa.queue_free()
		al_aceptar.call())
	botones.add_child(si)

	var no := Button.new()
	no.text = "Cancelar"
	no.custom_minimum_size = Vector2(0, 36)
	no.pressed.connect(capa.queue_free)
	botones.add_child(no)


# ============================================================
#  Helpers de UI
# ============================================================

func _title(vb: VBoxContainer, txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36))
	l.add_theme_font_size_override("font_size", 16)
	vb.add_child(l)

func _row(vb: VBoxContainer, etiqueta: String, valor: String, color_valor: Variant = null) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = etiqueta
	k.custom_minimum_size = Vector2(170, 0)
	k.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	row.add_child(k)
	var v := Label.new()
	v.text = valor
	if color_valor is Color:
		v.add_theme_color_override("font_color", color_valor)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Sin esto, un valor largo (la lista de mejoras, el desglose del ataque) se sale por el
	# borde derecho en vez de partirse en dos lineas.
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(v)
	vb.add_child(row)

func _note(vb: VBoxContainer, txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
	l.add_theme_font_size_override("font_size", 11)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Sin ancho MINIMO: en las columnas estrechas (el panel del candidato) empujaria el texto
	# fuera de la pantalla en vez de partirlo.
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(l)

func _fmt_pct(x: float) -> String:
	return "%.0f%%" % (x * 100.0)


# ============================================================
#  Pestaña PERSONAJE
# ============================================================

func _build_personaje() -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var t := Label.new()
	t.text = "%s  (Nv. %d)   —   %s" % [_pj().nombre,
		_pj().level, "Estadísticas" if _char_page == 0 else "Habilidades"]
	t.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36))
	t.add_theme_font_size_override("font_size", 16)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	# Icono de intercambio ⇄: alterna stats <-> habilidades.
	var swap := Button.new()
	swap.text = "⇄"
	swap.tooltip_text = "Cambiar vista (estadísticas / habilidades)"
	swap.custom_minimum_size = Vector2(44, 34)
	swap.pressed.connect(_flip_char_page)
	head.add_child(swap)
	_content.add_child(head)
	_content.add_child(HSeparator.new())

	if _char_page == 0:
		_build_stats_page()
	else:
		_build_habilidades_page()


func _flip_char_page() -> void:
	_char_page = 1 - _char_page
	_rebuild()


func _build_stats_page() -> void:
	# crear_player_combatant() concreta el -1 (= "lleno") de vida/maná. Como aquí solo
	# LEEMOS stats, guardamos y restauramos el sentinel para no mutar el estado persistente.
	var hp_was: float = _pj().current_hp
	var mp_was: float = _pj().current_mp
	var c: Combatant = Game.crear_player_combatant(_pj())
	_pj().current_hp = hp_was
	_pj().current_mp = mp_was
	_row(_content, "Ataque total", "%.1f" % _ataque_total(c))
	_row(_content, "Velocidad", "%.1f" % c.spd())
	# Critico contra un enemigo ESPEJO (tus mismas stats): tu Destreza vs tu Agilidad.
	var crit_p: float = clampf(StatsMath.crit_chance(float(c.abilities.destreza),
		float(c.abilities.agilidad)) + _crit_bonus_promedio(c), 0.0, 1.0)
	_row(_content, "Prob. crítico", _fmt_pct(crit_p))
	# Daño critico REAL: base + el crit_dmg del arma (base × rareza + Precision), no la constante.
	var crit_mult: float = StatsMath.CRIT_MULT + c.crit_dmg
	_row(_content, "Daño crítico", "×%.2f (+%d%%)" % [
		crit_mult, roundi((crit_mult - 1.0) * 100.0)])
	# Esquiva contra el mismo espejo: tu Agilidad vs tu Destreza, menos el penal (escudos) y mas
	# el bonus de esquiva (daga/estoque + armaduras ligeras). Con bonus, el tope sube (EVADE_MAX_BUFF).
	var evade_cap: float = StatsMath.EVADE_MAX_BUFF if c.evasion_bonus > 0.0 else StatsMath.EVADE_MAX
	var evade_p: float = clampf(StatsMath.evade_chance(float(c.abilities.agilidad),
		float(c.abilities.destreza)) - c.evasion_penal + c.evasion_bonus, 0.0, evade_cap)
	_row(_content, "Prob. esquiva", _fmt_pct(evade_p))
	# Desglose del EQUIPO: la esquiva de daga/estoque/armadura ligera va en evasion_penal (negativo
	# = bonus); un escudo la resta (penal positivo). Sin esta línea el aporte del equipo quedaba
	# invisible (se fundía en el total y, con Agilidad alta, el tope lo escondía). + suma, − estorba.
	var esquiva_equipo: float = -c.evasion_penal
	if absf(esquiva_equipo) > 0.001:
		_row(_content, "   · del equipo", "%+.0f%%" % (esquiva_equipo * 100.0))
	if c.evasion_bonus > 0.001:
		_row(_content, "   · postura/buff", "+%.0f%%" % (c.evasion_bonus * 100.0))
	_content.add_child(HSeparator.new())
	_row(_content, "Vida máx.", "%.1f" % c.max_hp)
	_row(_content, "Defensa", "%.1f" % c.def_value())
	# La defensa MAGICA va aqui, con la fisica y la vida, y para TODO el mundo: no es una stat de
	# mago, es lo que te protege cuando el que lanza el hechizo es el otro. Estuvo un rato colgando
	# del bloque de Magia y por tanto invisible justo para quien mas le importa: el que no lleva
	# arma magica y no se entera de por que un hechizo le arrea mas o menos.
	_row(_content, "Defensa mágica", "%.1f" % StatsMath.magic_jugador(c.abilities, c.base_magic))
	if c.max_mp > 0.0:
		_row(_content, "Maná máx.", "%.2f" % c.max_mp)
	_bloque_magia(c)
	# OJO con esta nota: el critico es un CONTEST (tu Destreza contra la Agilidad del que recibe
	# el golpe). Como aqui no hay enemigo, se enseña contra un espejo de ti mismo, y por eso TU
	# Agilidad sale en la cuenta... haciendo de la del rival. Tu Agilidad NO te baja el critico:
	# te sube la esquiva. Decirlo mal era sembrar la duda de que la Agilidad te perjudica.
	_note(_content, "Ataque total = raw (base + arma) × Fuerza, ANTES del motion value (cada golpe aplica su %). El crítico es tu Destreza contra la Agilidad del que recibe el golpe: aquí se muestra contra un maniquí con TUS mismas stats, así que un rival más ágil que tú te dará menos crítico, y uno más torpe, más. Tu Agilidad es la que te hace esquivar a ti.")


func _build_habilidades_page() -> void:
	# Combatant real para DERIVAR el aporte de cada stat (nada hardcodeado). Guardamos/
	# restauramos los sentinels de HP/MP: crear_player_combatant() concreta el -1 (= "lleno").
	var hp_was: float = _pj().current_hp
	var mp_was: float = _pj().current_mp
	var c: Combatant = Game.crear_player_combatant(_pj())
	_pj().current_hp = hp_was
	_pj().current_mp = mp_was

	# Cada "Ahora:" dice lo que aporta ESA habilidad, no el total de la stat (que es lo que se
	# enseñaba en velocidad y maná: el numero no se movia al mirar una habilidad u otra) y no un
	# multiplicador abstracto (que es lo que se enseñaba en Fuerza: un "×1.01" no dice si eso son
	# dos puntos de daño o veinte). Los numeros salen por DIFERENCIA; ver _sin_habilidad().
	var ab: Abilities = c.abilities

	# FUERZA -> ataque fisico. Como fuerza_factor(0) == 1, lo que aporta es todo lo que el ataque
	# total tiene por encima del raw pelado (base + arma).
	_row(_content, "Fuerza", str(_pj().fuerza))
	var atk_sin: float = (c.base_attack + c.ataque_arma) * c.status_atk_mult()
	_note(_content, "Multiplica el daño físico (base + arma), así que cuanto mejor sea el arma más "
		+ "vale cada punto. Ahora: +%.1f de ataque." % (_ataque_total(c) - atk_sin))

	# RESISTENCIA -> vida y defensa.
	_row(_content, "Resistencia", str(_pj().resistencia))
	var ab_sin_res: Abilities = _sin_habilidad(ab, "resistencia")
	var hp_de_res: float = c.max_hp - StatsMath.max_hp_jugador(ab_sin_res, _pj().base_hp)
	var def_base: float = c.base_defense + c.extra_defense
	var def_de_res: float = (StatsMath.defense_jugador(ab, def_base)
		- StatsMath.defense_jugador(ab_sin_res, def_base)) * c.status_def_mult()
	_note(_content, "Aguante: sube vida máxima y defensa. Ahora: +%.1f vida y +%.1f defensa." % [
		hp_de_res, def_de_res])

	# DESTREZA -> critico (y afina la recoleccion). El critico es un DUELO: tu Destreza contra la
	# AGILIDAD del que recibe el golpe. Por eso se enseña contra un maniqui con tus mismas stats (no
	# hay enemigo delante), y por eso hay que decir de QUIEN es cada stat: la frase de antes hablaba
	# de "un rival igual de ágil" dentro de la linea de Destreza y parecia que la Destreza tuviera
	# algo que ver con ser agil.
	_row(_content, "Destreza", str(_pj().destreza))
	var crit_espejo: float = StatsMath.crit_chance(float(_pj().destreza), float(_pj().agilidad))
	_note(_content, "Precisión: tu Destreza pelea contra la Agilidad del rival para critear (y te "
		+ "da mano firme al recolectar). Contra un maniquí con tus mismas stats: ~%s de crítico."
		% _fmt_pct(crit_espejo))

	# AGILIDAD -> esquiva (el duelo espejo del critico) y velocidad de turno.
	_row(_content, "Agilidad", str(_pj().agilidad))
	var evade_espejo: float = StatsMath.evade_chance(float(_pj().agilidad), float(_pj().destreza))
	# Lo que aporta a la VELOCIDAD, no la velocidad total. Todo lo que multiplica detras de
	# _spd_base() (arma, armadura, estados, guardia) es comun a las dos ramas, asi que basta la
	# proporcion entre la velocidad cruda con y sin Agilidad.
	var spd_con: float = StatsMath.speed_jugador(ab, c.base_speed)
	var spd_sin: float = StatsMath.speed_jugador(_sin_habilidad(ab, "agilidad"), c.base_speed)
	var vel_de_agi: float = c.spd() * (1.0 - (spd_sin / spd_con if spd_con > 0.0 else 1.0))
	_note(_content, "Reflejos: tu Agilidad esquiva la Destreza del rival y marca tu velocidad de "
		+ "turno. Contra el mismo maniquí: ~%s de esquiva. Y ahora: +%.1f de velocidad."
		% [_fmt_pct(evade_espejo), vel_de_agi])

	# MAGIA -> daño de hechizos, maná y defensa magica (las tres cosas, que la ultima acaba de salir
	# a la ficha de Estadisticas y tambien sale de aqui).
	_row(_content, "Magia", str(_pj().magia))
	var ab_sin_mag: Abilities = _sin_habilidad(ab, "magia")
	var mp_de_mag: float = c.max_mp - StatsMath.max_mp_jugador(ab_sin_mag, _pj().base_mp)
	var mdef_de_mag: float = StatsMath.magic_jugador(ab, c.base_magic) \
		- StatsMath.magic_jugador(ab_sin_mag, c.base_magic)
	_note(_content, "Poder arcano: multiplica el daño de los hechizos, y sube el maná y la defensa "
		+ "mágica. Ahora: ×%.2f a los hechizos, +%.1f de maná y +%.1f de defensa mágica." % [
		StatsMath.magia_factor(float(_pj().magia)), mp_de_mag, mdef_de_mag])

	_note(_content, "Las 5 habilidades (0–999). Suben con el uso y se aplican en el hogar. Cada "
		+ "«Ahora» es lo que te está dando ESA habilidad, no tu total.")


# La mitad MAGICA de la ficha, espejo de la fisica de arriba. Faltaba entera: podias ir con el
# baston en la mano y la ficha solo te hablaba de "Ataque total" (que con un baston es ridiculo,
# porque su motion value es 0.4), sin decir ni una palabra de lo que de verdad haces con el.
#
# Se pinta SIEMPRE, tambien sin arma magica. Al principio se ocultaba a quien no llevara baston,
# pero eso es mirarlo al reves: los hechizos se aprenden de los libros, no del arma, asi que
# cualquiera puede lanzarlos y a cualquiera le interesa saber con que fuerza. Y las filas que salen
# a cero no son ruido, son la respuesta: "no regeneras mana porque no llevas arma magica".
func _bloque_magia(c: Combatant) -> void:
	var lm: Dictionary = Game.loadout_mods(_pj())
	var amp: float = float(lm["magic_amp"])
	_content.add_child(HSeparator.new())
	_title(_content, "Magia")
	# PODER MAGICO: lo que multiplica el daño del hechizo (el que sale en SU ficha), igual que
	# "Ataque total" es el raw antes de que cada golpe le aplique su motion value.
	#
	# Es TUYO y solo tuyo: aqui NO entra StatsMath.SPELL_DAMAGE_MULT, que es un multiplicador global
	# de todos los hechizos de todo el mundo y por tanto no dice nada de este personaje. Cuando
	# entraba, un tio sin una gota de magia leia "×1.50" y parecia que tuviera un +50% arcano de la
	# nada. Ahora ese factor va donde vive, en el daño que enseña el hechizo (SpellData.dano_mostrado),
	# y un personaje pelado lee ×1.00, que es la verdad.
	#
	# Se desglosa en sus DOS mitades (tu Magia y el arma) y se enseñan LAS DOS, nunca una sola: el
	# total ya lleva el arma dentro, y con una sola linea debajo no hay forma de saber si el numero
	# de arriba la incluye o si hay que multiplicarla aparte. Viendo 1.21 y 1.70 se comprueba solo.
	var por_magia: float = StatsMath.magia_factor(float(c.abilities.magia)) * c.magia_base_factor
	_row(_content, "Poder mágico", "×%.2f" % Game.poder_magico(_pj()))
	if absf(amp - 1.0) > 0.001:
		_row(_content, "   · tu Magia", "×%.2f" % por_magia)
		_row(_content, "   · el arma", "×%.2f" % amp)
	# (La defensa MAGICA no esta aqui: va arriba con la fisica y la vida, que es donde se buscan
	# las defensas y donde la ve tambien el que no lleva arma magica.)
	# El regen a 0 se enseña igual: es la unica forma de enterarse de que el mana solo se recupera
	# con arma magica o con pociones (la economia de mana es PLANA y sin regen no se sostiene).
	_row(_content, "Regen maná", "%.2f/turno" % c.mp_regen_turno)
	# Velocidad de CASTEO: lo rapido que recitas, que no es lo rapido que blandes (un baston recita
	# mas rapido de lo que pega). Se enseña siempre, aunque coincida con la normal: si no, el mago
	# no puede comparar su recitado con el de un compañero que no lleve baston.
	_row(_content, "Vel. recitado", "%.1f" % c.cast_spd())
	if float(lm["mana_reduccion"]) > 0.0:
		_row(_content, "Coste de maná", "-%.0f%%" % (float(lm["mana_reduccion"]) * 100.0))
	# La coletilla del desglose solo si el desglose SE HA PINTADO (sin arma mágica no hay dos
	# líneas debajo a las que referirse, y la nota hablaba de unas filas que no existían).
	var nota: String = "El poder mágico multiplica el daño que pone en la ficha del hechizo (como " \
		+ "el Ataque total al golpe físico); luego lo frena la defensa mágica del que lo recibe."
	if absf(amp - 1.0) > 0.001:
		nota += " Las dos líneas de debajo son los factores que ya lleva dentro: se multiplican " \
			+ "entre sí, no se suman."
	_note(_content, nota)


# Ataque TOTAL (raw): (base + arma) × factor_fuerza × estados, SIN el motion_value
# (ese se aplica por golpe). c ya tiene activa la mano principal (0) tras crearlo.
func _ataque_total(c: Combatant) -> float:
	return (c.base_attack + c.ataque_arma) * StatsMath.fuerza_factor(float(c.abilities.fuerza)) * c.status_atk_mult()


# COPIA de las habilidades con UNA puesta a cero. Sirve para medir lo que aporta esa habilidad por
# DIFERENCIA: "lo que tienes" menos "lo que tendrias sin ella".
#
# Se hace asi y no reescribiendo cada formula en la ficha porque reescribirlas es justo de donde
# venia el desfase: la pagina de habilidades calculaba los aportes con las formulas ADITIVAS (las de
# los enemigos: HP_FROM_RES, _coef por nivel) mientras el jugador usa las MULTIPLICATIVAS
# (StatsMath.*_jugador). Coinciden a nivel 1 con las bases de inicio -y por eso colaba-, pero en
# cuanto el bakeo de subir de nivel infla las bases, cada punto vale mas de lo que decia la ficha.
# Por diferencia da igual cual sea la formula: siempre sale la de verdad.
func _sin_habilidad(ab: Abilities, cual: String) -> Abilities:
	var z := Abilities.new()
	z.fuerza = ab.fuerza
	z.resistencia = ab.resistencia
	z.destreza = ab.destreza
	z.agilidad = ab.agilidad
	z.magia = ab.magia
	z.set(cual, 0)
	return z

# Media del crit_bonus del arma sobre las manos (afinidad).
func _crit_bonus_promedio(c: Combatant) -> float:
	if c.hands.is_empty():
		return c.crit_bonus
	var total: float = 0.0
	for h in c.hands:
		total += float(h.get("crit_bonus", 0.0))
	return total / float(c.hands.size())


# ============================================================
#  Pestaña ARMAS
# ============================================================

func _build_armas() -> void:
	if _arma_change != "":
		_build_armas_cambiar()
		return

	_title(_content, "ARMAS")
	var pueblo: bool = Game.en_pueblo()
	if not pueblo:
		_note(_content, "Cambios de equipo solo en el pueblo. Aquí es solo consulta.")

	# --- Principal ---
	_content.add_child(HSeparator.new())
	_bloque_arma("Principal", _main_nombre(_pj().equipped_main), pueblo, _abrir_cambio.bind("main"))
	if _pj().equipped_main == null:
		_note(_content, "Sin arma: peleas a puños (poco daño, pero rápido y sin peso).")
	_weapon_stats(_content, _pj().equipped_main)

	# --- Secundaria ---
	_content.add_child(HSeparator.new())
	var dos_manos: bool = Game.arma_main(_pj()).dos_manos and _pj().equipped_main != null
	_bloque_arma("Secundaria", _off_nombre(_pj().equipped_off), pueblo and not dos_manos,
		_abrir_cambio.bind("off"))
	if dos_manos:
		_note(_content, "El arma principal es a dos manos: no admite secundaria.")
	else:
		_off_stats(_content, _pj().equipped_off)

	# --- El conjunto ---
	# La velocidad REAL con la que peleas, que no es la de ninguna de las dos armas por separado:
	# lleva dentro el bonus de ir a dual, lo que aporta la secundaria por su tamaño y las mejoras de
	# Rapidez de las dos manos (la de la izquierda, a mitad). Sin esta linea el jugador ve dos fichas
	# con dos numeros y ninguno es el que manda.
	_content.add_child(HSeparator.new())
	var lm: Dictionary = Game.loadout_mods(_pj())
	_row(_content, "Velocidad del conjunto", "×%.2f" % float(lm["velocidad_mult"]))
	if _pj().equipped_off is WeaponData:
		_note(_content, "Vas a dos armas: se alternan golpe a golpe, cada una con su daño y su "
			+ "crítico. La mejora de Rapidez de la secundaria cuenta la mitad que la de la principal.")


# Cabecera de un bloque de arma: nombre + boton Cambiar (si procede).
func _bloque_arma(rol: String, nombre: String, permite_cambio: bool, on_cambiar: Callable) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var t := Label.new()
	t.text = "%s:  %s" % [rol, nombre]
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_color_override("font_color", Color(0.9, 0.95, 0.8))
	head.add_child(t)
	if permite_cambio:
		var b := Button.new()
		b.text = "Cambiar"
		b.pressed.connect(on_cambiar)
		head.add_child(b)
	_content.add_child(head)


# --- Catalogos: solo lo que TIENES en el baul (Game.owned_*) ---

# Armas validas como PRINCIPAL: solo las WeaponData del baul. NO hay entrada de "nada": ir a
# manos vacias no es equipar un objeto, es DESEQUIPAR el que llevas (ver _equipar_arma).
func _catalogo_main() -> Array:
	var r: Array = []
	for it in Game.owned_weapons:
		if it is WeaponData:
			r.append(it)
	return r


# Nombre de una candidata a mano PRINCIPAL (null = manos vacias).
func _main_nombre(item: Resource) -> String:
	return "— (sin arma)" if item == null else Game.item_display_name(item)

# Manos SECUNDARIAS posibles: todo el baul (la validez la filtra _secundaria_valida, que ya
# descarta la que llevas en la principal). Sin entrada de "nada": se DESEQUIPA la que llevas.
func _catalogo_off() -> Array:
	var r: Array = []
	for it in Game.owned_weapons:
		r.append(it)
	return r

# Piezas del baul que encajan en el slot. Sin entrada de "nada": para ir sin pieza se
# DESEQUIPA la que llevas puesta (el boton cambia solo).
func _catalogo_armor(slot: String) -> Array:
	var r: Array = []
	for p in Game.owned_armor_de_slot(slot):
		r.append(p)
	return r


func _abrir_cambio(slot: String) -> void:
	_arma_change = slot
	if slot == "main":
		_arma_cand = _index_of_main()
	else:
		_arma_cand = _off_current_index(_catalogo_off())
	_rebuild()


func _build_armas_cambiar() -> void:
	var es_main: bool = _arma_change == "main"
	_title(_content, "Cambiar %s" % ("arma principal" if es_main else "mano secundaria"))
	_content.add_child(HSeparator.new())

	var catalogo: Array = _catalogo_main() if es_main else _catalogo_off()
	if catalogo.is_empty():
		_note(_content, "No tienes armas en el baúl.")
		return
	var labels: Array = []
	var disabled: Array = []
	for i in catalogo.size():
		var item: Resource = catalogo[i]
		if es_main:
			labels.append(_etiqueta_con_dueno(item, _main_nombre(item)))
		else:
			labels.append(_etiqueta_con_dueno(item, _off_nombre(item)))
			# Deshabilita las secundarias incompatibles con la principal actual.
			if not Game._secundaria_valida(_pj().equipped_main, item):
				disabled.append(i)

	# Si el candidato es JUSTO lo que ya llevas puesto, el boton no equipa: DESEQUIPA. Asi
	# quedarse sin arma (peleas a puños) o sin secundaria no necesita una entrada falsa de
	# "nada" en la rejilla: es el mismo boton, que se da la vuelta.
	_build_cambiar_layout(labels, _arma_cand, disabled, _pick_arma,
		_preview_arma, _equipar_arma, _cancelar_arma,
		"Desequipar" if _arma_cand_equipada() else "Equipar")


# True si el arma marcada ahora mismo es la que ya llevas en esa mano.
func _arma_cand_equipada() -> bool:
	var es_main: bool = _arma_change == "main"
	var cat: Array = _catalogo_main() if es_main else _catalogo_off()
	if _arma_cand >= cat.size():
		return false
	return cat[_arma_cand] == (_pj().equipped_main if es_main else _pj().equipped_off)


func _pick_arma(i: int) -> void:
	_arma_cand = i
	_rebuild()

func _cancelar_arma() -> void:
	_arma_change = ""
	_rebuild()

# Equipar el candidato... o DESEQUIPAR, si el candidato es lo que ya llevas puesto.
func _equipar_arma() -> void:
	var quitar: bool = _arma_cand_equipada()
	var es_main: bool = _arma_change == "main"
	var cat: Array = _catalogo_main() if es_main else _catalogo_off()
	if _arma_cand >= cat.size():
		return
	var item: Resource = null if quitar else cat[_arma_cand]
	# Si la lleva otro, se pregunta antes: el modal llama a esto solo si dices que si.
	_confirmar_robo(item, func():
		if es_main:
			Game.equipar_arma(item as WeaponData, _pj())
		else:
			Game.equipar_secundaria(item, _pj())
		_arma_change = ""
		_rebuild())


# Construye el panel de stats del candidato de arma (derecha de la cuadricula).
func _preview_arma(vb: VBoxContainer) -> void:
	if _arma_change == "main":
		var cat: Array = _catalogo_main()
		if _arma_cand >= cat.size():
			return
		var w: WeaponData = cat[_arma_cand]
		_title(vb, _main_nombre(w))
		_aviso_dueno(vb, w)
		_weapon_stats(vb, w)
		if w == _pj().equipped_main:
			_note(vb, "Ya la llevas puesta: al desequiparla pelearás a puños.")
	else:
		var cat_off: Array = _catalogo_off()
		if _arma_cand >= cat_off.size():
			return
		var item: Resource = cat_off[_arma_cand]
		_title(vb, _off_nombre(item))
		_aviso_dueno(vb, item)
		_off_stats(vb, item)
		if item != null and item == _pj().equipped_off:
			_note(vb, "Ya la llevas puesta: al desequiparla te quedas con la mano libre.")
		elif item != null and item == _pj().equipped_main:
			_note(vb, "Ya la llevas en la mano principal: necesitas otra igual para el dual.")
		elif item != null and not Game._secundaria_valida(_pj().equipped_main, item):
			_note(vb, "No compatible con el arma principal actual.")


func _index_of_main() -> int:
	var cat: Array = _catalogo_main()
	for i in cat.size():
		if cat[i] == _pj().equipped_main:
			return i
	return 0


func _off_current_index(list: Array) -> int:
	for i in list.size():
		if list[i] == _pj().equipped_off:
			return i
	return 0


# --- Fichas de stats (reutilizadas por la vista normal y la preview) ---

# Tier/rareza/mejoras salen del PROPIO objeto (Game.meta_de), no del slot: asi el panel del
# candidato muestra sus datos aunque no lo lleves puesto.
#
# Y lo que se pinta son los numeros REALES (los mismos que usa el combate: Upgrades.*_mods con
# el tier/rareza/mejoras del objeto), no los del .tres. Una daga T3 +3 NO pega lo que dice su
# plantilla; entre parentesis va el valor de fabrica, para ver cuanto ha subido.
func _weapon_stats(vb: VBoxContainer, w: WeaponData) -> void:
	if w == null:
		return
	var m: Dictionary = Game.meta_de(w)
	var tier: int = int(m["tier"])
	var rareza: int = int(m["rareza"])
	var mejoras: Dictionary = m["mejoras"]
	var tmult: float = Game.tier_mult(tier)
	var mods: Dictionary = Upgrades.weapon_mods(w, tmult, rareza, mejoras)
	# El BASE de ESTA arma no es el del .tres: es el suyo con su tier y su rareza, sin las
	# mejoras. Lo sacamos pidiendo los mismos mods con la lista de mejoras vacia.
	var base: Dictionary = Upgrades.weapon_mods(w, tmult, rareza, {})

	var tipo: String = WEAPON_TIPO_LABELS[clampi(int(w.tipo), 0, WEAPON_TIPO_LABELS.size() - 1)]
	_row(vb, "  Tipo", tipo + ("  (magia)" if w.es_magica else ""))
	_row(vb, "  Ataque", _con_mejoras("%.1f", float(base["raw"]), float(mods["raw"])))
	_row(vb, "  Motion value", "×%.2f" % w.motion_value)
	_row(vb, "  Velocidad", _con_mejoras("×%.2f",
		w.velocidad_mult * float(base["vel_mult"]), w.velocidad_mult * float(mods["vel_mult"])))
	# crit/aturdir/evasion ya vienen RESUELTOS de weapon_mods (base × rareza + mejoras). El
	# "base" (sin mejoras) es el mismo item con la lista de mejoras vacia -> lo que ponen las
	# mejoras se ve entre parentesis.
	var crit: float = float(mods["crit"])
	if crit != 0.0:
		_row(vb, "  Crítico", _con_mejoras_pct(float(base["crit"]), crit))
	if float(mods["precision"]) > 0.0:
		_row(vb, "  Precisión", "+%s" % _fmt_pct(float(mods["precision"])))
	var evasion: float = float(mods["evasion"])
	if evasion > 0.0:
		_row(vb, "  Evasión", "+%s" % _fmt_pct(evasion))
	var aturdir: float = float(mods["aturdir"])
	if aturdir > 0.0:
		_row(vb, "  Aturdir", _con_mejoras_pct(float(base["aturdir"]), aturdir))
	if w.es_magica:
		var mg: Dictionary = Upgrades.magic_mods(w.magic_amp, tmult, rareza, mejoras)
		var mgb: Dictionary = Upgrades.magic_mods(w.magic_amp, tmult, rareza, {})
		_magic_stats(vb, mg, mgb, w.mp_regen_turno, w.cast_vel_mult)
	_row(vb, "  Tier / rareza", "T%d · %s" % [tier, Upgrades.rareza_nombre(rareza)])
	_row(vb, "  Mejoras", "%d / %d" % [Upgrades.total_mejoras(mejoras), Upgrades.rareza_slots(rareza)])
	# DESGASTE: gastada pega menos y ROTA se va a los suelos. Se repara en el herrero.
	_row(vb, "  Durabilidad", Game.durabilidad_txt_item(w), Game.durabilidad_color(w))
	# En QUE se gastaron, en su propia linea: con 12 huecos (obra maestra) la lista no cabe
	# nunca al lado del contador.
	if not mejoras.is_empty():
		_note(vb, "    " + _lista_mejoras(mejoras))


# La ficha del ESCUDO, hermana de _weapon_stats: mismos numeros REALES (Upgrades.shield_mods,
# la math del combate) y el mismo desglose "base + (lo que ponen las mejoras) = total". Antes
# tiraba de MenuScaffold.filas_escudo, que da el numero pelado: veias "Bloqueo 15%" y no habia
# forma de saber que 5 de esos puntos los ponia el Refuerzo que acababas de forjar. El arma si
# lo desglosaba, asi que mejorar un escudo era el unico sitio donde no veias lo que comprabas.
func _shield_stats(vb: VBoxContainer, sh: ShieldData, tier: int, rareza: int, mejoras: Dictionary) -> void:
	var tmult: float = Game.tier_mult(tier)
	var mods: Dictionary = Upgrades.shield_mods(sh, tmult, rareza, mejoras)
	# El BASE de ESTE escudo: el mismo, con su tier y su rareza, pero sin mejoras.
	var base: Dictionary = Upgrades.shield_mods(sh, tmult, rareza, {})

	var tamanos: Array = MenuScaffold.SHIELD_TAMANO_LABELS
	_row(vb, "  Tipo", "Escudo %s  ·  mano secundaria"
		% String(tamanos[clampi(int(sh.tamano), 0, tamanos.size() - 1)]).to_lower())
	# Lo primero, la DEFENSA: es lo que crece con tier, rareza y mejoras. Y solo cuenta al Defender.
	_row(vb, "  Defensa al bloquear", _con_mejoras("%.1f", float(base["def"]), float(mods["def"])))
	# El bloqueo NO lleva tier ni rareza (es del tamaño): lo unico que lo sube es el Refuerzo, y
	# eso es justo lo que enseña el parentesis.
	_row(vb, "  Bloqueo", _con_mejoras_pct(float(base["bloqueo"]), float(mods["bloqueo"])))
	if float(mods["resist_estados"]) > 0.0:
		_row(vb, "  Resist. estados",
			_con_mejoras_pct(float(base["resist_estados"]), float(mods["resist_estados"])))
	# Velocidad y penalizacion de esquiva salen del TAMAÑO y no las toca nada: sin desglose,
	# porque no hay nada que desglosar (ver shield_mods).
	_row(vb, "  Velocidad", "×%.2f" % float(mods["vel_mult"]))
	_row(vb, "  Penal. esquiva", "-%s" % _fmt_pct(float(mods["evasion_penal"])))


# Las lineas magicas (baston y varita comparten math: Upgrades.magic_mods). 'mg' = con mejoras,
# 'mgb' = el mismo item SIN ellas (su base con tier y rareza).
func _magic_stats(vb: VBoxContainer, mg: Dictionary, mgb: Dictionary, regen_base: float, cast_base: float) -> void:
	_row(vb, "  Amplif. magia", _con_mejoras("×%.2f",
		float(mgb["magic_amp"]), float(mg["magic_amp"])))
	# Regen PLANO por turno. El "base" ya lleva el tier y la rareza de ESTE item; el parentesis es
	# lo que ponen las mejoras. La nota dice lo que significa el numero, que es lo que se pregunta
	# el jugador: un hechizo corto cuesta 6 y tarda 2 turnos en salir.
	var regen_b: float = regen_base * float(mgb["regen_mult"])
	var regen_t: float = regen_base * float(mg["regen_mult"])
	_row(vb, "  Regen maná", _con_mejoras("%.2f", regen_b, regen_t) + " /turno")
	_note(vb, "    Gotea también mientras recitas: un conjuro corto tarda 2 turnos, así que se paga %.2f de su maná él solo." % (regen_t * 2.0))
	_row(vb, "  Vel. casteo", _con_mejoras("×%.2f",
		cast_base + float(mgb["cast_vel_add"]), cast_base + float(mg["cast_vel_add"])))
	if float(mg["mana_reduccion"]) > 0.0:
		_row(vb, "  Coste de maná", "-%s" % _fmt_pct(float(mg["mana_reduccion"])))


# "14.5 + (6.1) = 20.6". El BASE ya lleva dentro el tier y la rareza de ESTE objeto (no es el
# numero del .tres); lo que va ENTRE PARENTESIS es lo que ponen las mejoras, para que se sepa
# de donde sale. Sin mejoras, el numero a secas.
func _con_mejoras(fmt: String, base: float, total: float) -> String:
	if absf(total - base) < 0.005:
		return fmt % total
	return "%s + (%s) = %s" % [fmt % base, fmt % (total - base), fmt % total]


# Igual pero en porcentaje (critico, aturdir).
func _con_mejoras_pct(base: float, total: float) -> String:
	if absf(total - base) < 0.0005:
		return "+%s" % _fmt_pct(total)
	return "%s + (%s) = %s" % [_fmt_pct(base), _fmt_pct(total - base), _fmt_pct(total)]


# "Agudeza 2, Precision 1": en QUE se gastaron las mejoras (dos armas con el mismo +N pueden
# ser cosas muy distintas).
func _lista_mejoras(mejoras: Dictionary) -> String:
	var partes: PackedStringArray = []
	for cat in mejoras:
		partes.append("%s %d" % [Upgrades.cat_nombre(str(cat)), int(mejoras[cat])])
	return ", ".join(partes)


func _off_stats(vb: VBoxContainer, item: Resource) -> void:
	if item == null:
		_note(vb, "  (sin mano secundaria)")
		return
	if item is WeaponData:
		_weapon_stats(vb, item as WeaponData)
		return
	# Escudo y varita tambien tienen su tier/rareza/mejoras: hasta ahora se pintaban a pelo.
	var m: Dictionary = Game.meta_de(item)
	var tier: int = int(m["tier"])
	var rareza: int = int(m["rareza"])
	var mejoras: Dictionary = m["mejoras"]
	if item is ShieldData:
		_shield_stats(vb, item as ShieldData, tier, rareza, mejoras)
	elif item is WandData:
		var wd := item as WandData
		var tm: float = Game.tier_mult(tier)
		var mg: Dictionary = Upgrades.magic_mods(wd.magic_amp, tm, rareza, mejoras)
		var mgb: Dictionary = Upgrades.magic_mods(wd.magic_amp, tm, rareza, {})
		_magic_stats(vb, mg, mgb, wd.mp_regen_turno, wd.cast_vel_mult)
	_row(vb, "  Tier / rareza", "T%d · %s" % [tier, Upgrades.rareza_nombre(rareza)])
	_row(vb, "  Mejoras", "%d / %d" % [Upgrades.total_mejoras(mejoras), Upgrades.rareza_slots(rareza)])
	_row(vb, "  Durabilidad", Game.durabilidad_txt_item(item), Game.durabilidad_color(item))
	# En QUE se gastaron, en su propia linea: con 12 huecos (obra maestra) la lista no cabe
	# nunca al lado del contador.
	if not mejoras.is_empty():
		_note(vb, "    " + _lista_mejoras(mejoras))


# Nombre completo del item de la secundaria, con su tier/rareza/+N (Game.item_display_name),
# que es lo que de verdad lo distingue de otra copia igual.
func _off_nombre(item: Resource) -> String:
	if item == null:
		return "— (sin secundaria)"
	return Game.item_display_name(item)


# ============================================================
#  Pestaña ARMADURA
# ============================================================

func _build_armadura() -> void:
	if _armor_slot_sel == "":
		_build_armadura_lista()
	else:
		_build_armadura_slot(_armor_slot_sel)


func _build_armadura_lista() -> void:
	_title(_content, "ARMADURA")
	if not Game.en_pueblo():
		_note(_content, "Cambios de equipo solo en el pueblo. Aquí es solo consulta.")
	_content.add_child(HSeparator.new())
	for slot in ARMOR_SLOTS:
		var pieza = _pj().get("equipped_" + slot)
		var nombre: String = "(sin pieza)"
		if pieza is ArmorData or pieza is BackpackData:
			nombre = Game.item_display_name(pieza)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var l := Label.new()
		l.text = "%s:  %s" % [ARMOR_SLOT_LABELS[slot], nombre]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var ver := Button.new()
		ver.text = "Ver ▶"
		ver.pressed.connect(_abrir_slot.bind(slot))
		row.add_child(ver)
		_content.add_child(row)


func _abrir_slot(slot: String) -> void:
	_armor_slot_sel = slot
	_preseleccionar_equipada(slot)
	_rebuild()

func _cerrar_slot() -> void:
	_armor_slot_sel = ""
	_rebuild()

# Salta al slot anterior/siguiente (Casco <-> Botas envuelve) sin volver a la lista.
func _ciclar_slot(dir: int) -> void:
	var i: int = ARMOR_SLOTS.find(_armor_slot_sel)
	var slot: String = ARMOR_SLOTS[wrapi(i + dir, 0, ARMOR_SLOTS.size())]
	_armor_slot_sel = slot
	_preseleccionar_equipada(slot)
	_rebuild()

# Deja _armor_cand en la pieza equipada del slot (o en la primera del baul si no llevas
# ninguna), para que la cuadricula abra siempre con stats a la vista.
func _preseleccionar_equipada(slot: String) -> void:
	var pieza = _pj().get("equipped_" + slot)
	_armor_cand = 0
	var cat: Array = _catalogo_armor(slot)
	for i in cat.size():
		if cat[i] == pieza:
			_armor_cand = i
			break


# Vista de un slot: cabecera con flechas para cambiar de slot + cuadricula de piezas
# del baul (equipada preseleccionada) + panel de stats y "Equipar". Solo en el pueblo.
func _build_armadura_slot(slot: String) -> void:
	# Cabecera: ◀  [Slot]  ▶ ......... Volver
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var prev := Button.new()
	prev.text = "◀"
	prev.custom_minimum_size = Vector2(40, 0)
	prev.pressed.connect(_ciclar_slot.bind(-1))
	head.add_child(prev)
	var t := Label.new()
	t.text = ARMOR_SLOT_LABELS[slot]
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36))
	t.add_theme_font_size_override("font_size", 16)
	head.add_child(t)
	var next := Button.new()
	next.text = "▶"
	next.custom_minimum_size = Vector2(40, 0)
	next.pressed.connect(_ciclar_slot.bind(1))
	head.add_child(next)
	var volver := Button.new()
	volver.text = "Volver"
	volver.pressed.connect(_cerrar_slot)
	head.add_child(volver)
	_content.add_child(head)

	var pueblo: bool = Game.en_pueblo()
	if not pueblo:
		_note(_content, "Cambios de equipo solo en el pueblo. Aquí es solo consulta.")
	_content.add_child(HSeparator.new())

	var cat: Array = _catalogo_armor(slot)
	var labels: Array = []
	for p in cat:
		labels.append(_etiqueta_con_dueno(p, Game.item_display_name(p)))
	if cat.is_empty():
		_note(_content, "No tienes piezas de este slot en el baúl.")
		return
	# Fuera del pueblo: apagar solo "Equipar" (marcando el candidato como disabled, que es
	# lo que mira _build_cambiar_layout). El resto de la cuadricula sigue navegable/consultable.
	var disabled: Array = [_armor_cand] if not pueblo else []
	_build_cambiar_layout(labels, _armor_cand, disabled, _pick_armor,
		_preview_armor, _equipar_armor, _cerrar_slot,
		"Desequipar" if _armor_cand_equipada() else "Equipar")


# True si la pieza marcada ahora mismo es la que ya llevas puesta en ese slot.
func _armor_cand_equipada() -> bool:
	var cat: Array = _catalogo_armor(_armor_slot_sel)
	if _armor_cand >= cat.size():
		return false
	return cat[_armor_cand] == _pj().get("equipped_" + _armor_slot_sel)


func _pick_armor(i: int) -> void:
	_armor_cand = i
	_rebuild()

# Equipar la pieza marcada... o QUITARLA, si es justo la que ya llevas puesta.
func _equipar_armor() -> void:
	var slot: String = _armor_slot_sel
	var cat: Array = _catalogo_armor(slot)
	if _armor_cand >= cat.size():
		return
	var elegido: Resource = null if _armor_cand_equipada() else cat[_armor_cand]
	# Si la pieza la lleva otro, se pregunta antes (mismo criterio que con las armas).
	_confirmar_robo(elegido, func():
		Game.equipar_armadura(slot, elegido as ArmorData, _pj())
		_rebuild())   # se queda en el slot; la recien equipada queda marcada


# Panel de stats de la pieza candidata (derecha de la cuadricula).
func _preview_armor(vb: VBoxContainer) -> void:
	var slot: String = _armor_slot_sel
	var cat: Array = _catalogo_armor(slot)
	if _armor_cand >= cat.size() or cat[_armor_cand] == null:
		return
	var a: ArmorData = cat[_armor_cand]
	_title(vb, Game.item_display_name(a))
	_aviso_dueno(vb, a)
	if a == _pj().get("equipped_" + slot):
		_note(vb, "Ya la llevas puesta: al quitarla vas ligero (+velocidad, 0 defensa).")
	_armor_stats(vb, a)


# Ficha de una pieza de armadura. Como en las armas: los numeros son los REALES (con su tier,
# rareza y mejoras) y la DEFENSA se desglosa en "base + lo que suman las mejoras", donde el
# base ya lleva dentro el tier y la rareza de ESTA pieza.
func _armor_stats(vb: VBoxContainer, a: ArmorData) -> void:
	if a == null:
		return
	var am: Dictionary = Game.meta_de(a)
	var tier: int = int(am["tier"])
	var rareza: int = int(am["rareza"])
	var mejoras: Dictionary = am["mejoras"]
	var tm: float = Game.tier_mult(tier)
	var mods: Dictionary = Upgrades.armor_piece_mods(a, tm, rareza, mejoras)
	var base: Dictionary = Upgrades.armor_piece_mods(a, tm, rareza, {})

	# DOS decimales: la DEF de una pieza es un numero pequeño (un peto de cuero son 0.25), y con
	# uno solo se redondea a "0.3" y parece otra cosa.
	_row(vb, "  Defensa", _con_mejoras("%.2f", float(base["def"]), float(mods["def"])))
	_row(vb, "  Reducción", _fmt_pct(float(mods["reduccion"])))
	_row(vb, "  Velocidad", "×%.2f" % float(mods["vel_mult"]))
	if float(mods["evasion"]) > 0.0:
		_row(vb, "  Evasión", "+%s" % _fmt_pct(float(mods["evasion"])))
	if float(mods["crit_resist"]) > 0.0:
		_row(vb, "  Resist. crítico", "+%s" % _fmt_pct(float(mods["crit_resist"])))
	if float(mods["resist_estados"]) > 0.0:
		_row(vb, "  Resist. estados", "+%s" % _fmt_pct(float(mods["resist_estados"])))
	_row(vb, "  Tier / rareza", "T%d · %s" % [tier, Upgrades.rareza_nombre(rareza)])
	_row(vb, "  Mejoras", "%d / %d" % [Upgrades.total_mejoras(mejoras), Upgrades.rareza_slots(rareza)])
	_row(vb, "  Durabilidad", Game.durabilidad_txt_item(a), Game.durabilidad_color(a))
	if not mejoras.is_empty():
		_note(vb, "    " + _lista_mejoras(mejoras))


# ============================================================
#  Cuadricula de seleccion + panel de stats a la derecha (comun armas/armadura)
# ============================================================

# 'equipar_txt' lo pasa quien llama: si el candidato es "nada", el boton dice DESEQUIPAR
# (elegir "(nada)" en la principal = pelear a puños; en la armadura = quitarse la pieza).
func _build_cambiar_layout(labels: Array, cand: int, disabled: Array,
		on_pick: Callable, preview_builder: Callable,
		on_equipar: Callable, on_cancel: Callable,
		equipar_txt: String = "Equipar") -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(hb)

	# Izquierda: cuadricula de botones (uno por item).
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for i in labels.size():
		var b := Button.new()
		b.text = str(labels[i])
		b.toggle_mode = true
		b.button_pressed = (i == cand)
		b.clip_text = true
		b.custom_minimum_size = Vector2(120, 46)
		if disabled.has(i):
			b.disabled = true
		else:
			b.pressed.connect(on_pick.bind(i))
		grid.add_child(b)
	hb.add_child(grid)

	# Derecha: stats del candidato + acciones.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(right)
	preview_builder.call(right)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	var eq := Button.new()
	eq.text = equipar_txt
	eq.disabled = disabled.has(cand)
	eq.pressed.connect(on_equipar)
	actions.add_child(eq)
	var ca := Button.new()
	ca.text = "Cancelar"
	ca.pressed.connect(on_cancel)
	actions.add_child(ca)
	right.add_child(HSeparator.new())
	right.add_child(actions)


# ============================================================
#  Pestaña HECHIZOS (solo si conoces alguno)
#  Cuadricula de hechizos + ficha del seleccionado: que hace (todo DERIVADO de sus
#  campos, ver SpellData.resumen) y su ENCANTAMIENTO (las frases que hay que recitar).
# ============================================================

func _build_hechizos() -> void:
	_title(_content, "HECHIZOS")
	_note(_content, "Se lanzan RECITANDO su encantamiento: una frase por turno. Si fallas una, el hechizo se te vuelve en contra.")
	_content.add_child(HSeparator.new())

	var spells: Array = _pj().equipped_spells
	if spells.is_empty():
		_note(_content, "No conoces ningún hechizo.")
		return
	_spell_sel = clampi(_spell_sel, 0, spells.size() - 1)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(hb)

	# Izquierda: cuadricula de hechizos.
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for i in spells.size():
		var s: SpellData = spells[i]
		var b := Button.new()
		b.text = "%s\n%d MP" % [s.nombre, s.coste_mana]
		b.toggle_mode = true
		b.button_pressed = (i == _spell_sel)
		b.clip_text = true
		b.custom_minimum_size = Vector2(120, 46)
		b.pressed.connect(_pick_hechizo.bind(i))
		grid.add_child(b)
	hb.add_child(grid)

	# Derecha: la ficha del seleccionado.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(right)
	_ficha_hechizo(right, spells[_spell_sel])


func _pick_hechizo(i: int) -> void:
	_spell_sel = i
	_rebuild()


# Ficha de un hechizo. TODO sale de sus campos: si tocas un numero en el .tres, esto se
# actualiza solo (la 'descripcion' es solo SABOR y no repite ninguna cifra).
func _ficha_hechizo(vb: VBoxContainer, s: SpellData) -> void:
	_title(vb, s.nombre)
	_row(vb, "  Encantamiento", "%s (%d frase%s)" % [
		s.longitud_texto(), s.longitud(), "" if s.longitud() == 1 else "s"])
	_row(vb, "  Coste", "%d de maná" % s.coste_mana)
	if s.elemento != Elementos.Elemento.NINGUNO:
		_row(vb, "  Elemento", Elementos.nombre(s.elemento))

	# DAÑO: el de ESTE personaje, ya multiplicado por su poder magico (su Magia + el bastón o la
	# varita que lleve). Es el numero que va a salir en el combate, no una cifra de catalogo: antes
	# se enseñaba el daño pelado del .tres con una coletilla de "esto luego escala", y tocaba
	# multiplicar de cabeza para saber si el hechizo servia de algo.
	# La etiqueta lleva el "(100%)" porque este numero es la REFERENCIA de la que salen todos los
	# porcentajes de la frase de abajo (el papel que en Honkai hace el ATK del personaje), y NO el
	# daño total que reparte el hechizo. Con un "Daño" a secas se lee como el total y no cuadra:
	# la Andanada pone 43 y luego dice 150% + 75%, que suman bastante mas.
	var ref: float = s.dano_mostrado() * Game.poder_magico(_pj())
	if s.tipo == SpellData.TipoEfecto.ATAQUE and s.dano_base > 0.0:
		_row(vb, "  Daño (100%)", "%.0f" % ref)

	# QUE HACE. Los porcentajes son de ese daño de arriba, y llevan al lado el numero real entre
	# parentesis. Sustituye a la tabla de filas sueltas (Al objetivo / Alcance / Salpicón / Rebotes
	# / Aplica), que daba los datos pero no contaba nunca lo que pasa al lanzarlo.
	var mecanica: String = s.descripcion_mecanica(ref)
	if mecanica != "":
		vb.add_child(HSeparator.new())
		var l := Label.new()
		l.text = mecanica
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(420, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_child(l)
	if s.tipo == SpellData.TipoEfecto.ATAQUE and s.dano_base > 0.0:
		_note(vb, "El daño es el tuyo, con tu Magia y el arma que llevas ahora; luego lo frena la "
			+ "defensa mágica del que lo recibe.")
	# La AFINIDAD de un imbue de cuerpo sigue en tabla: son varios elementos con su multiplicador
	# cada uno, y eso es una lista de verdad, no una frase.
	if s.es_imbuicion() and s.imbue_tipo == 2:
		_afinidad_hechizo(vb, s)

	# EL ENCANTAMIENTO: las frases que hay que recitar, en orden.
	vb.add_child(HSeparator.new())
	_title(vb, "Encantamiento")
	for i in s.frases.size():
		var l := Label.new()
		l.text = "  %d. «%s»" % [i + 1, s.frases[i]]
		l.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(420, 0)
		vb.add_child(l)

	if s.descripcion != "":
		vb.add_child(HSeparator.new())
		_note(vb, s.descripcion)


# Lo que te da y lo que te cuesta la afinidad de un imbue de CUERPO. Los % se DERIVAN de la
# tabla y de la franja de intensidad del hechizo, asi que nunca mienten.
func _afinidad_hechizo(vb: VBoxContainer, s: SpellData) -> void:
	var resiste: Array = []
	var debil: Array = []
	for e in Elementos.PERFIL_DEFECTO.get(s.elemento, {}):
		var puro: float = float(Elementos.PERFIL_DEFECTO[s.elemento][e])
		var m: float = Elementos.escalar_intensidad(puro, s.imbue_intensidad)
		# En positivo y sin restas mentales: "20% de resistencia" / "+20% de daño".
		if m < 0.99:
			resiste.append("%s (%d%% de resistencia)" % [Elementos.nombre(e), roundi((1.0 - m) * 100.0)])
		elif m > 1.01:
			debil.append("%s (+%d%% de daño)" % [Elementos.nombre(e), roundi((m - 1.0) * 100.0)])
	if not resiste.is_empty():
		_row(vb, "  🛡 Resistes", ", ".join(resiste))
	var inm: Array = []
	for id in Elementos.inmunidades_de(s.elemento):
		inm.append(String(StatusEffects.def(id).get("nombre", "?")))
	if not inm.is_empty():
		_row(vb, "  Inmune a", ", ".join(inm))
	var st: float = Elementos.stun_taken_por_afinidad(s.elemento)
	if st < 0.99:
		_row(vb, "  Aturdimiento", "te aturden un %d%% menos" % roundi((1.0 - st) * 100.0))
	if not debil.is_empty():
		_row(vb, "  ⚠ Débil a", ", ".join(debil))
