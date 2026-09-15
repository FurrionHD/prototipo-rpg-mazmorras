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
#  la columna izquierda, el muñeco en el centro y los numeros en la ficha de la derecha. Debajo de los
#  botones, los desarrollos y las pasivas que TIENE, con lo recien salido marcado en su sitio (lo
#  pidio el usuario: en un modal, al cerrarlo no quedaba escrito en ningun sitio lo que tenias).
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

var _root: Control = null
var _lista: VBoxContainer = null      # la columna del centro (el muñeco)
var _content: VBoxContainer = null    # la ficha de la derecha
var _side: VBoxContainer = null       # bajo el nombre, en la columna izquierda
var _titulo_nombre: Label = null
var _fila_retratos: HBoxContainer = null
var _scroll_retratos: ScrollContainer = null
var _caja_muneco: Control = null
var _pies_y: float = 0.0
var _pj_sel: int = 0                  # a quien se esta mirando (indice en _pjs())
# Antes→despues del ultimo "Actualizar" POR PERSONAJE: {PersonajeData: {stat: [antes, desp]}}.
# Por persona y no global para que cada uno enseñe SUS cambios y no los del ultimo que tocaste.
# Un antes = -1 es el reinicio por subir de nivel.
var _deltas: Dictionary = {}
# Lo que SALIO A LA LUZ en ese mismo "Actualizar", tambien por persona, para marcarlo en la lista:
var _subidas: Dictionary = {}   # {PersonajeData: {id_desarrollo: rango_antes}}
var _nuevas: Dictionary = {}    # {PersonajeData: [id_pasiva, ...]}
# La exclamacion de "hay cosas nuevas abajo" (ver _crear_aviso):
var _aviso_nuevo: Control = null
var _por_ver: Array = []        # [[clave, nodo], ...] de la ficha pintada ahora mismo, aun sin ver
var _vistas: Dictionary = {}    # {PersonajeData: [clave, ...]} lo nuevo que ya ha entrado en la vista
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
	# +16 para la BARRA del scroll: con la lista de desarrollos y pasivas la ficha desplaza, y la barra
	# se pone encima del canto derecho y se come la letra de rango.
	(_content.get_parent() as ScrollContainer).custom_minimum_size = Vector2(ANCHO_FICHA + 16.0, 0)

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
	_crear_aviso()


func abrir() -> void:
	if Game._active_layer != null or Game.debug_panel_open:
		return
	_pj_sel = 0
	_deltas = {}
	_vistas = {}
	_subidas = {}
	_nuevas = {}
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
	_ficha_arriba()


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
	_ficha_arriba()


# La ficha vuelve ARRIBA al cambiar de persona y al actualizar: el scroll es del contenedor y no de la
# ficha, asi que sin esto se quedaba donde lo dejo el anterior y las basicas del nuevo no se veian.
func _ficha_arriba() -> void:
	(_content.get_parent() as ScrollContainer).scroll_vertical = 0


# La llama el selector de desarrollo tras subir de nivel: refresca y enseña el reset. El nivel es
# del LIDER, asi que la subida se muestra en SU ficha.
#
# 'aprendido' = el id del desarrollo elegido ("" = ninguno): sale marcado como recien salido ("— → I").
# Lo que se marco en el Actualizar de antes de subir se borra: ya no es de esta visita al estado.
func mostrar_subida(aprendido: String = "") -> void:
	if not _root.visible:
		return
	_pj_sel = maxi(0, _pjs().find(Game.lider()))
	var d: Dictionary = {}
	for s in STATS:
		d[s] = [-1, 0]
	_deltas[Game.lider()] = d
	_nuevas[Game.lider()] = []
	_subidas[Game.lider()] = {aprendido: 0} if aprendido != "" else {}
	_vistas[Game.lider()] = []
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
	_por_ver = []   # los nodos de la ficha anterior se van con el vaciado; _pintar_perks apunta los nuevos
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
	_pintar_perks(pj)


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

	# EL LIDER: los dos requisitos, marcados, y dichos SIN desvelar el como (ni que es un guardian, ni
	# que es un 600): el jugador tiene que intuirlo. El rango se mira en lo VISIBLE, igual que
	# Game.puede_subir_nivel, asi que hasta que no actualizas el estado no se marca.
	MenuScaffold.titulo(_side, "Requisitos para ascender", 13, GRIS)
	var guardian: bool = bool(Game.guardianes_vencidos.get(pj.level + 1, false))
	var rango_c: bool = Game.tiene_rango_c(pj)
	_requisito("He logrado una hazaña digna de ascender" if guardian
		else "Lograr una hazaña digna de ascender", guardian)
	_requisito("Ya me siento lo bastante fuerte" if rango_c
		else "Creo que aún me falta ser más fuerte", rango_c)


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
	# Con AUTOWRAP y expandido: sin el, una frase larga pide su ancho entero y la columna crece y
	# empuja los retratos de arriba.
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
#  DESARROLLO Y PASIVAS: lo que TIENE esta persona, debajo de los botones
#  Siempre a la vista, no solo al actualizar: es donde se viene a mirar como va cada uno. Lo que acaba
#  de salir a la luz en el ultimo "Actualizar" va MARCADO en su sitio (rombos verdes, "Nueva"), y la
#  ficha baja sola hasta aqui. Antes iba en un modal, que tapaba la pantalla y al cerrarlo no quedaba
#  escrito en ningun sitio lo que tenias.
# ============================================================

func _pintar_perks(pj: PersonajeData) -> void:
	var subidas: Dictionary = _subidas.get(pj, {})     # {id: rango_antes}
	var nuevas: Array = _nuevas.get(pj, [])             # ids de pasivas recien despertadas

	var hay_des: bool = false
	for d in Game.DESARROLLOS:
		if Game.desarrollo_rango(str(d["id"]), pj) > 0:
			hay_des = true
	var hay_pas: bool = false
	for p in Game.PASIVAS_RNG:
		if Game.tiene_pasiva(str(p["id"]), pj):
			hay_pas = true

	var hueco := Control.new()
	hueco.custom_minimum_size = Vector2(0, 18)
	_content.add_child(hueco)

	MenuScaffold.titulo(_content, "Habilidades de desarrollo", 13, GRIS)
	_content.add_child(HSeparator.new())
	if not hay_des:
		MenuScaffold.nota(_content, "Ninguna todavía. Se elige una al subir de nivel.")
	for d in Game.DESARROLLOS:
		var id: String = str(d["id"])
		var r: int = Game.desarrollo_rango(id, pj)
		if r <= 0:
			continue
		_fila_desarrollo(str(d["nombre"]), int(subidas.get(id, r)), r)
		if subidas.has(id):
			_por_ver_si_nuevo(pj, "des:" + id)

	var hueco2 := Control.new()
	hueco2.custom_minimum_size = Vector2(0, 12)
	_content.add_child(hueco2)
	MenuScaffold.titulo(_content, "Pasivas", 13, GRIS)
	_content.add_child(HSeparator.new())
	if not hay_pas:
		MenuScaffold.nota(_content, "Ninguna. Aparecen solas, muy de vez en cuando, al actualizar el estado.")
	# Las NUEVAS primero: son lo que se viene a ver.
	var orden: Array = []
	for p in Game.PASIVAS_RNG:
		if nuevas.has(str(p["id"])):
			orden.append(p)
	for p in Game.PASIVAS_RNG:
		if Game.tiene_pasiva(str(p["id"]), pj) and not nuevas.has(str(p["id"])):
			orden.append(p)
	for p in orden:
		if nuevas.has(str(p["id"])):
			MenuScaffold.titulo(_content, "★ ¡Nueva!", 11, VERDE)
		# Amarillo legendario y centelleando: es lo mas raro que te puede pasar en una partida (la
		# tirada cayo en silencio y este es el unico sitio donde aparece por primera vez).
		MenuScaffold.titulo_item(_content, str(p.get("nombre", "")), Upgrades.rareza_color(4), 1.0, 15)
		MenuScaffold.nota(_content, Game.pasiva_desc(p))
		if nuevas.has(str(p["id"])):
			_por_ver_si_nuevo(pj, "pas:" + str(p["id"]))


# ============================================================
#  LA EXCLAMACION de "hay cosas nuevas mas abajo"
#  Una burbuja ambar con "!" flotando abajo en la ficha, como en los juegos. Cada cosa nueva cuenta
#  como VISTA en cuanto entra entera en la vista del scroll; cuando no queda ninguna por ver, la
#  burbuja se va. Lo visto se apunta POR PERSONA y por clave, asi que cambiar de persona y volver no
#  lo resucita. Pulsarla baja hasta la siguiente por ver.
# ============================================================

const LADO_AVISO := 30.0

# El ULTIMO nodo añadido a la ficha es el que tiene que verse para dar la cosa por vista (la fila del
# desarrollo, o la descripcion de la pasiva: hasta leer eso no la has visto).
func _por_ver_si_nuevo(pj: PersonajeData, clave: String) -> void:
	var vistas: Array = _vistas.get(pj, [])
	if vistas.has(clave):
		return
	_por_ver.append([clave, _content.get_child(_content.get_child_count() - 1)])


func _crear_aviso() -> void:
	_aviso_nuevo = Control.new()
	_aviso_nuevo.size = Vector2(LADO_AVISO, LADO_AVISO)
	_aviso_nuevo.visible = false
	_aviso_nuevo.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_aviso_nuevo.tooltip_text = "Hay cosas nuevas más abajo"
	_root.add_child(_aviso_nuevo)
	_aviso_nuevo.draw.connect(func() -> void:
		var c := Vector2(LADO_AVISO, LADO_AVISO) * 0.5
		# Late: crece y mengua un poco, lo justo para que llame la vista sin marear.
		var r: float = LADO_AVISO * 0.5 * (0.92 + 0.08 * sin(Time.get_ticks_msec() * 0.006))
		_aviso_nuevo.draw_circle(c + Vector2(0, 2), r, Color(0, 0, 0, 0.45))   # sombra
		_aviso_nuevo.draw_circle(c, r, AMBAR)
		_aviso_nuevo.draw_arc(c, r, 0.0, TAU, 32, Color(1, 0.93, 0.75), 1.5, true)
		# La "!" a mano (palo y punto): con la fuente sale fina y descentrada.
		var col := Color(0.10, 0.07, 0.03)
		_aviso_nuevo.draw_line(c + Vector2(0, -r * 0.52), c + Vector2(0, r * 0.14), col, 3.2, true)
		_aviso_nuevo.draw_circle(c + Vector2(0, r * 0.46), 2.0, col))
	_aviso_nuevo.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_ir_al_siguiente_por_ver())


func _process(_delta: float) -> void:
	if _aviso_nuevo == null:
		return
	if not _root.visible or _por_ver.is_empty():
		_aviso_nuevo.visible = false
		return
	var scroll := _content.get_parent() as ScrollContainer
	var vista: Rect2 = scroll.get_global_rect()
	var pj: PersonajeData = _pj()
	var vistas: Array = _vistas.get(pj, [])
	var quedan: Array = []
	for e in _por_ver:
		var n: Control = e[1]
		if not is_instance_valid(n):
			continue
		var r: Rect2 = n.get_global_rect()
		# Cuenta cuando ha entrado ENTERA (y el layout ya la ha colocado: tamaño > 0).
		if r.size.y > 0.0 and r.position.y >= vista.position.y - 1.0 and r.end.y <= vista.end.y + 1.0:
			if not vistas.has(e[0]):
				vistas.append(e[0])
		else:
			quedan.append(e)
	_vistas[pj] = vistas
	_por_ver = quedan
	_aviso_nuevo.visible = not _por_ver.is_empty()
	if _aviso_nuevo.visible:
		# Abajo en el centro de la ficha, flotando sobre el contenido.
		_aviso_nuevo.global_position = Vector2(vista.get_center().x - LADO_AVISO * 0.5,
			vista.end.y - LADO_AVISO - 14.0)
		_aviso_nuevo.queue_redraw()


func _ir_al_siguiente_por_ver() -> void:
	if _por_ver.is_empty():
		return
	var n: Control = _por_ver[0][1]
	if is_instance_valid(n):
		(_content.get_parent() as ScrollContainer).ensure_control_visible(n)


# Un desarrollo: el nombre, los diez rombos de rango y la letra. Si acaba de subir, los rombos
# ganados van en verde y la letra dice de donde viene ("I → III").
func _fila_desarrollo(nombre: String, r_antes: int, r_hoy: int) -> void:
	var caja := Control.new()
	caja.custom_minimum_size = Vector2(0, 24)
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(caja)
	var sube: bool = r_hoy > r_antes
	caja.draw.connect(func() -> void:
		var w: float = caja.size.x
		var f: Font = caja.get_theme_font(&"font")
		var y: float = caja.size.y * 0.5
		caja.draw_string(f, Vector2(0, y + 5), nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			VERDE if sube else Color(0.82, 0.85, 0.90))
		# La columna de la letra tiene ANCHO FIJO (el de la mas ancha posible), para que los rombos
		# caigan en el mismo sitio en todas las filas.
		var txt: String = Game.letra_rango(r_hoy)
		if sube:
			txt = "%s → %s" % [Game.letra_rango(r_antes) if r_antes > 0 else "—", txt]
		var col_letra: float = f.get_string_size("— → W", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var an: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		caja.draw_string(f, Vector2(w - an, y + 5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, AMBAR)
		var lado: float = 4.0
		var paso: float = 10.0
		var x0: float = w - col_letra - 10.0 - paso * float(Game.RANGO_MAX)
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


# ============================================================
#  ACTUALIZAR
# ============================================================

# Consolida SOLO a este personaje: pasa su excelia pendiente a visible. Ya NO cura (eso pasa al
# abrir el altar, y a todo el grupo).
func _actualizar(pj: PersonajeData) -> void:
	var antes: Dictionary = {}
	for s in STATS:
		antes[s] = int(pj.get(s))
	var rangos_antes: Dictionary = pj.desarrollos_rango.duplicate()
	# Lo que devuelve es lo que ha salido a la luz al leer el estado: pasivas que te habian tocado
	# sin saberlo y desarrollos que han subido de rango.
	var revelado: Dictionary = Game.actualizar_estado(pj)
	var d: Dictionary = {}
	for s in STATS:
		d[s] = [antes[s], int(pj.get(s))]
	_deltas[pj] = d
	_vistas[pj] = []   # lo de este Actualizar es nuevo aunque la misma clave ya se viera otra vez
	# Se apunta POR ID con el rango de antes: la lista de desarrollos que devuelve Game va por nombre.
	var sub: Dictionary = {}
	for dd in Game.DESARROLLOS:
		var id: String = str(dd["id"])
		var r_hoy: int = Game.desarrollo_rango(id, pj)
		var r_ant: int = int(rangos_antes.get(id, 0))
		if r_hoy > r_ant:
			sub[id] = r_ant
	_subidas[pj] = sub
	var nuevas: Array = []
	for p in revelado.get("pasivas", []):
		nuevas.append(str(p.get("id", "")))
	_nuevas[pj] = nuevas
	# La ficha NO baja sola hasta lo nuevo: se dejaria de ver como han quedado las basicas, que es lo
	# primero que se mira al actualizar. Lo nuevo esta marcado en verde; se baja a verlo con la rueda.
	_rebuild()
	_ficha_arriba()


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
