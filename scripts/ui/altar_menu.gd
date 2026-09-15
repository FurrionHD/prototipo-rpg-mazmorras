# ============================================================
#  altar_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  MENU DEL ALTAR. Lo abre altar.gd (F sobre el altar). Tres cosas, SEPARADAS a proposito:
#
#   - CURAR: pasa solo con INTERACTUAR. Al abrir el altar, todo el grupo queda con la vida, el
#     maná, el aguante y los cooldowns a tope. No hay que pulsar nada: descansar en el altar cura.
#
#   - ACTUALIZAR ESTADO (consolidar): es INDIVIDUAL, uno cada vez. Consolidar es lo que pasa la
#     excelia ganada de "pendiente" a "visible" (la stat que se ve y usa el combate). Se elige a
#     quien en la fila de retratos de arriba.
#
#   - SUBIR DE NIVEL (solo el LIDER, si puede): abre el selector de desarrollo. El nivel sigue
#     siendo del que llevas en cabeza; a un companero se le sube poniendolo delante (teclas 1/2/3).
#
#  EL REPARTO es el de la ficha de personaje (ver character_menu.gd): la gente ARRIBA, el nombre en
#  la columna izquierda, el muñeco en el centro y los numeros en la ficha de la derecha. Lo que sale a
#  la luz al actualizar (pasivas, desarrollos que suben) va en un MODAL: es el momento de la visita, y
#  como lista debajo de los botones se salia de la pantalla en cuanto habia mas de cuatro cosas.
# ============================================================

extends CanvasLayer

const STATS := ["fuerza", "resistencia", "destreza", "agilidad", "magia"]
const NOMBRES := {"fuerza": "Fuerza", "resistencia": "Resistencia", "destreza": "Destreza",
	"agilidad": "Agilidad", "magia": "Magia"}

const AMBAR := Color(0.95, 0.72, 0.36)
const GRIS := Color(0.6, 0.63, 0.7)
const VERDE := Color(0.55, 0.85, 0.55)
const ANCHO_FICHA := 360.0
const ALTO_MUNECO := 430.0
const ESCALA_MUNECO := 6.0
const MARGEN_MUNECO := 20.0
const ALTO_MODAL_MAX := 440.0   # el scroll del modal de lo revelado no crece de aqui

var _root: Control = null
var _lista: VBoxContainer = null      # la columna del centro (el muñeco)
var _content: VBoxContainer = null    # la ficha de la derecha
var _side: VBoxContainer = null       # bajo el nombre, en la columna izquierda
var _titulo_nombre: Label = null
var _fila_retratos: HBoxContainer = null
var _scroll_retratos: ScrollContainer = null
var _caja_muneco: Control = null
var _pies_y: float = 0.0
var _modal: Control = null
var _pj_sel: int = 0                  # a quien se esta mirando (indice en _pjs())
# Antes→despues del ultimo "Actualizar" POR PERSONAJE: {PersonajeData: {stat: [antes, desp]}}.
# Por persona y no global para que cada uno enseñe SUS cambios y no los del ultimo que tocaste.
# Un antes = -1 es el reinicio por subir de nivel.
var _deltas: Dictionary = {}
var _aviso: String = ""


func _ready() -> void:
	layer = 93
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para: hay que seguir respondiendo
	add_to_group("altar_menu")
	var m: Dictionary = MenuScaffold.construir(self, "ALTAR", "", _cerrar, false, true)
	_root = m["root"]
	_lista = m["lista"]
	_content = m["content"]
	_side = m["side"]
	(m["aviso"] as Control).visible = false

	# El centro manda (el muñeco) y la ficha se queda con su ancho fijo, como en la de personaje.
	var scroll: ScrollContainer = m["lista_scroll"]
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.size_flags_horizontal = Control.SIZE_FILL
	_content.custom_minimum_size = Vector2(ANCHO_FICHA, 0)
	(_content.get_parent() as ScrollContainer).size_flags_horizontal = Control.SIZE_FILL
	(_content.get_parent() as ScrollContainer).custom_minimum_size = Vector2(ANCHO_FICHA, 0)

	# EL TITULO DE LA COLUMNA: "Altar" pequeño y gris sobre el NOMBRE de quien tienes delante. La
	# etiqueta del esqueleto se esconde (un Control oculto no ocupa sitio en un contenedor).
	var lateral: BoxContainer = _side.get_parent()
	(lateral.get_child(0) as Control).visible = false
	var titulo := VBoxContainer.new()
	titulo.add_theme_constant_override("separation", 0)
	var chico := Label.new()
	chico.text = "Altar"
	chico.add_theme_font_size_override("font_size", 11)
	chico.add_theme_color_override("font_color", GRIS)
	titulo.add_child(chico)
	_titulo_nombre = Label.new()
	_titulo_nombre.add_theme_font_size_override("font_size", 20)
	_titulo_nombre.add_theme_color_override("font_color", AMBAR)
	# SIN clip_text: con el, el Label mide cero de minimo y el contenedor le corta el nombre.
	titulo.add_child(_titulo_nombre)
	lateral.add_child(titulo)
	lateral.move_child(titulo, 0)

	_fila_retratos = MenuScaffold.fila_retratos(m["header"])
	_scroll_retratos = _fila_retratos.get_parent() as ScrollContainer


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
	Game.abrir_menu(self)   # para el mundo entero mientras el menu esta abierto
	_rebuild()


func _cerrar() -> void:
	_cerrar_modal()
	_root.visible = false
	Game.cerrar_menu(self)


# Esc cierra de dentro a fuera: primero el modal y solo despues el altar.
func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			if _modal != null:
				_cerrar_modal()
			else:
				_cerrar()
			get_viewport().set_input_as_handled()


# TODOS a los que se puede consolidar: los que bajan contigo Y los que esperan en el hogar.
#
# El banquillo esta aqui porque los ENCARGOS les dan excelia sin que bajen a ningun sitio, y
# `ganar()` escribe en ability_internal SIN consolidar (a proposito: consolidar gratis se cargaria
# el altar). Si el altar solo enseñara el party, esa excelia no habria forma de verla ni de cobrarla.
func _pjs() -> Array:
	var out: Array = []
	for pj in Game.party:
		out.append(pj)
	for pj in Game.en_el_banquillo():
		out.append(pj)
	return out


# El personaje que se esta mirando. Con el party vacio (transitorio, con el Hogar abierto) cae al
# lider, que Game garantiza que existe siempre.
func _pj() -> PersonajeData:
	var todos: Array = _pjs()
	if _pj_sel < 0 or _pj_sel >= todos.size():
		_pj_sel = 0
	return todos[_pj_sel] if not todos.is_empty() else Game.lider()


func _pick_persona(i: int) -> void:
	if i == _pj_sel:
		return
	_pj_sel = i
	_rebuild()


# La llama el selector de desarrollo tras subir de nivel: refresca y enseña el reset. El nivel es
# del LIDER, asi que la subida se muestra en SU ficha.
func mostrar_subida() -> void:
	if not _root.visible:
		return
	_pj_sel = maxi(0, _pjs().find(Game.lider()))
	var d: Dictionary = {}
	for s in STATS:
		d[s] = [-1, 0]
	_deltas[Game.lider()] = d
	_aviso = "¡%s sube a nivel %d! Su poder queda grabado en su base y sus básicas vuelven a rango I." % [
		Game.lider().nombre, Game.player_level]
	_rebuild()


# Guardia de REENTRADA. Un _rebuild puede entrar mientras otro esta a medias (el focus_exited de un
# campo al liberarlo, las señales de red, un _on_* que espera en un await), y entonces el de dentro
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
	_caja_muneco = null
	MenuScaffold.vaciar(_lista)
	MenuScaffold.vaciar(_content)
	MenuScaffold.vaciar(_side)

	var todos: Array = _pjs()
	var pj: PersonajeData = _pj()
	_titulo_nombre.text = pj.nombre.to_upper()

	# LA GENTE, con el punto ambar en quien tiene excelia sin consolidar: es lo que dice a quien
	# hay que venir a actualizar sin tener que ir tocandolos uno a uno.
	var marcas: Array = []
	for i in todos.size():
		if Game.tiene_pendiente(todos[i]):
			marcas.append(i)
	MenuScaffold.retratos(_fila_retratos, todos, _pj_sel, Game.party.size(), _pick_persona, marcas)

	_pintar_lateral(pj)
	_muneco_grande(pj)
	_pintar_ficha(pj)
	_ver_muneco(_modal == null)


# ============================================================
#  LA COLUMNA IZQUIERDA: el descanso y lo que falta para ascender
# ============================================================

func _pintar_lateral(pj: PersonajeData) -> void:
	if _aviso != "":
		MenuScaffold.nota(_side, _aviso)
	_side.add_child(HSeparator.new())

	var es_lider: bool = pj == Game.lider()
	if not Game.party.has(pj):
		# Los de casa SI pueden consolidar (es como se cobra lo que ganan en los encargos), pero ni
		# descansan ni suben de nivel: para eso hay que bajarlos a la mazmorra.
		var fuera: bool = Game.esta_de_encargo(pj)
		MenuScaffold.titulo(_side, "De encargo" if fuera else "En el Hogar", 13, GRIS)
		MenuScaffold.nota(_side, "Consolida aquí lo que ha aprendido. Para descansar o subir de "
			+ "nivel tiene que bajar contigo.")
		return
	if not es_lider:
		MenuScaffold.titulo(_side, "Subir de nivel", 13, GRIS)
		MenuScaffold.nota(_side, "Sube el que va en cabeza. Ponlo delante con la tecla %d."
			% (_pj_sel + 1))
		return

	# EL LIDER: los dos requisitos, marcados. Es lo que antes era una frase suelta que solo salia
	# cuando ya tenias uno de los dos.
	MenuScaffold.titulo(_side, "Para subir a nivel %d" % (pj.level + 1), 13, GRIS)
	var guardian: bool = bool(Game.guardianes_vencidos.get(pj.level + 1, false))
	var rango_c: bool = false
	for s in STATS:
		if Game.stat_total(s, pj) >= Game.RANGO_C_MIN:
			rango_c = true
	_requisito("Vencer al guardián", guardian)
	_requisito("Rango C en una básica", rango_c)


func _requisito(txt: String, hecho: bool) -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	var marca := Label.new()
	marca.text = "✓" if hecho else "✗"
	marca.add_theme_color_override("font_color", VERDE if hecho else Color(0.9, 0.5, 0.5))
	marca.add_theme_font_size_override("font_size", 14)
	fila.add_child(marca)
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.82, 0.85, 0.90) if hecho else GRIS)
	fila.add_child(l)
	_side.add_child(fila)


# ============================================================
#  EL CENTRO: el muñeco
#  La misma receta que _muneco_grande de la ficha de personaje (ver sus notas: la escala sale del
#  dibujo ENTERO, pies incluidos, y mirando al SUR con idle_0).
# ============================================================

func _muneco_grande(pj: PersonajeData) -> void:
	var caja := Control.new()
	caja.custom_minimum_size = Vector2(0, ALTO_MUNECO)
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.clip_contents = true
	_lista.add_child(caja)

	caja.draw.connect(func() -> void:
		var w: float = caja.size.x
		var h: float = caja.size.y
		if w <= 1.0:
			return
		var pies: float = _pies_y if _pies_y > 0.0 else h - MARGEN_MUNECO
		for i in 3:
			var t: float = 1.0 - float(i) / 3.0
			caja.draw_set_transform(Vector2(w * 0.5, pies), 0.0, Vector2(1.0, 0.22))
			caja.draw_circle(Vector2.ZERO, w * 0.20 * (0.6 + t * 0.6), Color(0.55, 0.62, 0.80, 0.05))
		caja.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE))
	caja.resized.connect(caja.queue_redraw)

	var mu := MunecoJugador.new()
	mu.montar(pj)
	mu.tenir(pj.color, 0.0)
	mu.poner_cara(pj.textura())
	if not mu.hay_dibujo():
		mu.queue_free()
		return
	caja.add_child(mu)
	mu.animar("idle_0")
	_caja_muneco = caja
	var colocar := func() -> void:
		var alto_dibujo: float = PoseJugador.ALTO_MUNDO + PoseJugador.PIES_BAJO_NODO
		var esc: float = minf(maxf(caja.size.y - MARGEN_MUNECO * 2.0, 120.0) / alto_dibujo,
			ESCALA_MUNECO)
		mu.scale = Vector2.ONE * esc
		_pies_y = MARGEN_MUNECO + PoseJugador.ALTO_MUNDO * esc
		mu.position = Vector2(caja.size.x * 0.5, _pies_y)
		caja.queue_redraw()
	caja.resized.connect(colocar)
	colocar.call()


# El muñeco (y los retratos) llevan z ABSOLUTO y se dibujan encima de cualquier modal: la unica
# forma de que no tapen es esconderlos mientras haya uno abierto.
func _ver_muneco(visible_: bool) -> void:
	if _caja_muneco != null and is_instance_valid(_caja_muneco):
		_caja_muneco.visible = visible_
	if _scroll_retratos != null and is_instance_valid(_scroll_retratos):
		_scroll_retratos.visible = visible_


# ============================================================
#  LA FICHA DE LA DERECHA: el nivel, las cinco basicas y los botones
# ============================================================

func _pintar_ficha(pj: PersonajeData) -> void:
	MenuScaffold.titulo(_content, "Nivel %d" % pj.level, 20, Color(0.94, 0.95, 0.98))
	if Game.tiene_pendiente(pj):
		MenuScaffold.titulo(_content, "● Tiene experiencia sin consolidar", 12, AMBAR)
	_content.add_child(HSeparator.new())

	# LAS BASICAS, cada una con su barra de 0 a 999. Tras "Actualizar", el tramo ganado va en verde.
	# ANTES de actualizar no se enseña ninguna cifra de lo pendiente: eso es justo lo que se viene a
	# descubrir aqui.
	var delta: Dictionary = _deltas.get(pj, {})
	for s in STATS:
		_fila_basica(NOMBRES[s], int(pj.get(s)), delta.get(s, []))
	if not delta.is_empty():
		var algo: bool = false
		for s in delta:
			if int(delta[s][1]) != int(delta[s][0]):
				algo = true
		if not algo:
			MenuScaffold.nota(_content, "Sin cambios desde la última vez.")

	var hueco := Control.new()
	hueco.custom_minimum_size = Vector2(0, 14)
	_content.add_child(hueco)

	# Actualizar va SIEMPRE activo, haya excelia pendiente o no: si se apagara sin ella, pulsarlo
	# encendido delataria una pasiva escondida (que tambien se revela aqui).
	var acc := VBoxContainer.new()
	acc.add_theme_constant_override("separation", 8)
	_content.add_child(acc)
	var b_act: Button = MenuScaffold.pastilla(acc, "Actualizar estado", _actualizar.bind(pj))
	b_act.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)
	if pj == Game.lider() and Game.puede_subir_nivel():
		var b_lvl: Button = MenuScaffold.pastilla(acc, "★ Subir de nivel  (%d → %d)" % [
			pj.level, pj.level + 1], _subir, false)
		b_lvl.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)


# Una basica: nombre a la izquierda, numero y letra a la derecha, y la barra fina debajo.
# 'd' = [antes, despues] del ultimo Actualizar ([] = no hay). antes = -1 es el reinicio por nivel.
func _fila_basica(nombre: String, valor: int, d: Array) -> void:
	var caja := Control.new()
	caja.custom_minimum_size = Vector2(0, 40)
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(caja)
	var antes: int = int(d[0]) if d.size() == 2 else valor
	var sube: int = valor - antes if antes >= 0 else 0
	caja.draw.connect(func() -> void:
		var w: float = caja.size.x
		var f: Font = caja.get_theme_font(&"font")
		caja.draw_string(f, Vector2(0, 17), nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(0.82, 0.85, 0.90))
		var letra: String = Abilities.rank_letter(valor)
		var num: String = "%d" % valor
		var extra: String = ""
		var col_extra: Color = VERDE
		if d.size() == 2:
			if antes < 0:
				extra = "reinicio"
				col_extra = GRIS
			elif sube > 0:
				extra = "+%d" % sube
		var x: float = w
		# La LETRA al canto, en ambar; el numero delante; y el +N (o "reinicio") delante del numero.
		var an_l: float = f.get_string_size(letra, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		x -= an_l
		caja.draw_string(f, Vector2(x, 17), letra, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, AMBAR)
		var an_n: float = f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		x -= an_n + 10.0
		caja.draw_string(f, Vector2(x, 17), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(0.94, 0.95, 0.98))
		if extra != "":
			var an_e: float = f.get_string_size(extra, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			x -= an_e + 8.0
			caja.draw_string(f, Vector2(x, 17), extra, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col_extra)
		# LA BARRA: fondo, lo que habia en ambar y lo ganado en verde.
		var y: float = 26.0
		var alto: float = 5.0
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(2)
		sb.bg_color = Color(1, 1, 1, 0.08)
		caja.draw_style_box(sb, Rect2(0, y, w, alto))
		var base_v: int = antes if antes >= 0 and sube > 0 else valor
		var w_base: float = w * clampf(float(base_v) / 999.0, 0.0, 1.0)
		var w_tot: float = w * clampf(float(valor) / 999.0, 0.0, 1.0)
		if w_base > 0.5:
			var sb2 := StyleBoxFlat.new()
			sb2.set_corner_radius_all(2)
			sb2.bg_color = AMBAR.darkened(0.15)
			caja.draw_style_box(sb2, Rect2(0, y, w_base, alto))
		if w_tot - w_base > 0.5:
			caja.draw_rect(Rect2(w_base, y, w_tot - w_base, alto), VERDE))
	caja.resized.connect(caja.queue_redraw)


# ============================================================
#  ACTUALIZAR, y EL MODAL de lo que ha salido a la luz
# ============================================================

# Consolida SOLO a este personaje: pasa su excelia pendiente a visible. Ya NO cura (eso pasa al
# abrir el altar, y a todo el grupo).
func _actualizar(pj: PersonajeData) -> void:
	var antes: Dictionary = {}
	for s in STATS:
		antes[s] = int(pj.get(s))
	# Lo que devuelve es lo que ha salido a la luz al leer el estado: pasivas que te habian tocado
	# sin saberlo y desarrollos que han subido de rango.
	var revelado: Dictionary = Game.actualizar_estado(pj)
	var d: Dictionary = {}
	for s in STATS:
		d[s] = [antes[s], int(pj.get(s))]
	_deltas[pj] = d
	_rebuild()
	var pasivas: Array = revelado.get("pasivas", [])
	var subidas: Array = revelado.get("desarrollos", [])
	if not pasivas.is_empty() or not subidas.is_empty():
		_abrir_revelado(pj, pasivas, subidas)


# Aqui es donde te enteras de que tienes una pasiva: la tirada cayo hace tres dias picando una veta
# y no hubo aviso ninguno (ver Game.rodar_pasiva), asi que este es literalmente el unico sitio del
# juego donde aparece por primera vez. Por eso va con el nombre en amarillo y centelleando, como un
# objeto legendario: es lo mas raro que te puede pasar en una partida.
func _abrir_revelado(pj: PersonajeData, pasivas: Array, subidas: Array) -> void:
	_cerrar_modal()
	var m: Dictionary = MenuScaffold.modal(_root, "El estado de %s" % pj.nombre, 560.0)
	_modal = m["capa"]
	_ver_muneco(false)

	# CON SCROLL y alto acotado: con todas las pasivas y todos los desarrollos no cabe en pantalla.
	# El alto se ajusta a lo que mida el contenido, para que con una sola cosa el modal no sea un
	# cajon vacio.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(m["cuerpo"] as VBoxContainer).add_child(scroll)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vb)
	var ajustar := func() -> void:
		if not is_instance_valid(scroll):
			return
		var alto_max: float = minf(ALTO_MODAL_MAX, _root.size.y - 200.0)
		scroll.custom_minimum_size = Vector2(0, minf(vb.get_combined_minimum_size().y,
			maxf(alto_max, 160.0)))
	vb.minimum_size_changed.connect(ajustar)

	if not pasivas.is_empty():
		MenuScaffold.titulo(vb, "★ Pasiva despertada" if pasivas.size() == 1
			else "★ Pasivas despertadas (%d)" % pasivas.size(), 13, GRIS)
		for p in pasivas:
			# Amarillo legendario, el tope de la paleta comun (ver Upgrades.RAREZA_COLOR).
			MenuScaffold.titulo_item(vb, str(p.get("nombre", "")), Upgrades.rareza_color(4), 1.0, 16)
			MenuScaffold.nota(vb, Game.pasiva_desc(p))
		if not subidas.is_empty():
			vb.add_child(HSeparator.new())

	if not subidas.is_empty():
		MenuScaffold.titulo(vb, "Desarrollo", 13, GRIS)
		for s in subidas:
			_fila_subida(vb, str(s[0]), int(s[1]), int(s[2]))

	ajustar.call()
	MenuScaffold.pastilla(m["acciones"], "Cerrar", _cerrar_modal)


# Un desarrollo que sube: el nombre y los diez rombos de rango, los que ya tenia en ambar y los
# ganados ahora en verde, con la letra al final ("— → III").
func _fila_subida(vb: VBoxContainer, nombre: String, r_antes: int, r_hoy: int) -> void:
	var caja := Control.new()
	caja.custom_minimum_size = Vector2(0, 26)
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(caja)
	caja.draw.connect(func() -> void:
		var w: float = caja.size.x
		var f: Font = caja.get_theme_font(&"font")
		var y: float = caja.size.y * 0.5
		caja.draw_string(f, Vector2(0, y + 5), nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(0.82, 0.85, 0.90))
		# La columna de la letra tiene ANCHO FIJO (el de la mas ancha posible), para que los rombos
		# caigan en el mismo sitio en todas las filas. Y se aparta de la derecha lo que ocupa la barra
		# del scroll, que si no se come la ultima letra.
		var txt: String = "%s → %s" % [Game.letra_rango(r_antes) if r_antes > 0 else "—",
			Game.letra_rango(r_hoy)]
		var der: float = w - 16.0
		var col_letra: float = f.get_string_size("— → W", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var an: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		caja.draw_string(f, Vector2(der - an, y + 5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, AMBAR)
		var lado: float = 5.0
		var paso: float = 13.0
		var x0: float = der - col_letra - 16.0 - paso * float(Game.RANGO_MAX)
		for i in Game.RANGO_MAX:
			var c := Vector2(x0 + paso * float(i) + lado, y)
			var pts := PackedVector2Array([c + Vector2(0, -lado), c + Vector2(lado, 0),
				c + Vector2(0, lado), c + Vector2(-lado, 0)])
			var col: Color = Color(1, 1, 1, 0.10)
			if i < r_antes:
				col = AMBAR
			elif i < r_hoy:
				col = VERDE
			caja.draw_colored_polygon(pts, col))
	caja.resized.connect(caja.queue_redraw)


func _cerrar_modal() -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null
	_ver_muneco(true)


func _subir() -> void:
	var menu: Node = get_tree().get_first_node_in_group("desarrollo_menu")
	if menu != null and menu.has_method("abrir"):
		_cerrar()          # el selector toma el control (evita dos menus con inventory_open)
		menu.abrir(true)   # true = al terminar (o aplazar) se vuelve aqui


# La llama el selector al cerrarse cuando se abrio desde aqui: se vuelve al altar SIN volver a curar
# ni borrar los cambios que estabas mirando (abrir() hace las dos cosas).
func volver() -> void:
	if Game._active_layer != null or Game.debug_panel_open:
		return
	_root.visible = true
	Game.abrir_menu(self)
	_rebuild()
