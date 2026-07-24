# ============================================================
#  home_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  Menu del HOGAR. Dos cosas, que son las dos que se hacen en casa:
#    1) EQUIPO   - quien de tu plantilla baja hoy a la mazmorra (como mucho Game.PARTY_MAX) y en
#                  que orden. La plantilla no tiene tope: aqui se montan equipos distintos sin
#                  perder a nadie (nadie se despide nunca).
#    2) ALMACEN  - guardar en casa los materiales que traigas en la bolsa (lo que antes hacia la
#                  tecla F a secas). Se consulta en la pestaña "Materiales" del inventario (I).
#
#  El ORDEN del equipo importa: el de arriba es el que va EN CABEZA (el cuerpo que mueves por el
#  mapa, el que mina y el que gasta aguante). Se puede cambiar tambien sobre la marcha con las
#  teclas 1/2/3, pero aqui es donde se decide con quien sales de casa.
# ============================================================

extends CanvasLayer

# Almacen del hogar. Bote y Cofre son tu almacen personal (persiste en la partida); en multi
# pasan a ser los del host (compartidos). Siempre visibles.
const TABS := ["Equipo", "Almacén", "Bote", "Cofre"]

const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const GRIS := Color(0.6, 0.63, 0.7)

var _root: Control = null
var _header: VBoxContainer = null
var _content: VBoxContainer = null
var _lista: VBoxContainer = null
var _aviso_lbl: Label = null
var _tab_buttons: Array = []
var _side: VBoxContainer = null
var _aviso: String = ""
var _aviso_ok: bool = true
var _tab: int = 0
var _cofre_sub: int = 0   # 0 = Armas, 1 = Armaduras (submenus del cofre)
var _bote_input: String = ""   # cantidad escrita en el bote (se conserva entre re-dibujos)


func _ready() -> void:
	layer = 91
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para: hay que seguir respondiendo
	add_to_group("home_menu")

	var m: Dictionary = MenuScaffold.construir(self, "HOGAR",
		"Tu casa: aquí se decide con quién bajas y aquí se guarda lo que traes.",
		_cerrar)
	_root = m["root"]
	_header = m["header"]
	_content = m["content"]
	_lista = m["lista"]
	_aviso_lbl = m["aviso"]
	_side = m["side"]
	# Las pestañas se rehacen en cada _rebuild: en sesion multi aparecen Bote y Cofre.
	if Net.has_signal("hogar_cambiado"):
		Net.hogar_cambiado.connect(_on_hogar_cambiado)


# El OTRO jugador cambio el estado compartido: si tengo el hogar abierto, me re-dibujo.
func _on_hogar_cambiado() -> void:
	if _root != null and _root.visible:
		_rebuild()


func _tabs() -> Array:
	return TABS


func _rehacer_tabs() -> void:
	for b in _tab_buttons:
		(b as Button).queue_free()
	_tab_buttons.clear()
	var etiquetas: Array = _tabs()
	_tab = clampi(_tab, 0, etiquetas.size() - 1)
	for i in etiquetas.size():
		var b := Button.new()
		b.text = etiquetas[i]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 34)
		b.pressed.connect(_on_tab.bind(i))
		_side.add_child(b)
		_tab_buttons.append(b)


func abrir() -> void:
	if Game._active_layer != null or Game.debug_panel_open:
		return
	_tab = 0
	_aviso = ""
	_root.visible = true
	Game.abrir_menu(self)
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


func _on_tab(i: int) -> void:
	_tab = i
	_aviso = ""
	_rebuild()


func _rebuild() -> void:
	_rehacer_tabs()
	for zona in [_header, _content, _lista]:
		for c in zona.get_children():
			c.queue_free()
	for i in _tab_buttons.size():
		(_tab_buttons[i] as Button).button_pressed = (i == _tab)
	MenuScaffold.decir(_aviso_lbl, _aviso, _aviso_ok)

	match _tabs()[_tab]:
		"Equipo": _build_equipo()
		"Almacén": _build_almacen()
		"Bote": _build_bote()
		"Cofre": _build_cofre()


# ============================================================
#  EQUIPO: los que bajan (izquierda) y el banquillo (derecha)
# ============================================================

func _build_equipo() -> void:
	MenuScaffold.titulo(_header, "QUIÉN BAJA CONTIGO", 18)

	MenuScaffold.titulo(_lista, "El equipo (%d de %d)" % [Game.party.size(), Game.PARTY_MAX], 14)
	for i in Game.party.size():
		_fila_equipo(i)
	MenuScaffold.nota(_lista, "El de la 👑 va EN CABEZA: es el cuerpo que mueves por el mapa, el "
		+ "que recolecta y el que gasta aguante. Cada uno tiene su hueco fijo (su número); cambiar "
		+ "de cabeza con «Al frente» o las teclas 1/2/3 no los mueve de sitio.")

	MenuScaffold.titulo(_content, "En casa (%d)" % Game.en_el_banquillo().size(), 14)
	var banquillo: Array = Game.en_el_banquillo()
	if banquillo.is_empty():
		MenuScaffold.nota(_content, "No hay nadie esperando en casa. Se contrata gente en la taberna.")
	for pj in banquillo:
		_fila_banquillo(pj)


func _fila_equipo(i: int) -> void:
	var pj: PersonajeData = Game.party[i]
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	_lista.add_child(fila)

	fila.add_child(_punto(pj))

	var es_lider: bool = pj == Game.lider()
	var l := Label.new()
	# El numero es el de la tecla que lo pone en cabeza (1/2/3), y es FIJO: cada uno tiene su hueco.
	l.text = "%d. %s%s  ·  Nv.%d" % [i + 1, "👑 " if es_lider else "", pj.nombre, pj.level]
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if es_lider:
		l.add_theme_color_override("font_color", AMBAR)
	fila.add_child(l)

	# Ponerlo EN CABEZA. Ya no reordena el equipo (las posiciones son fijas): solo mueve la corona,
	# lo mismo que hace su tecla. Deshabilitado si ya va delante.
	var frente := Button.new()
	frente.text = "👑 Al frente"
	frente.disabled = es_lider
	frente.tooltip_text = "Ponlo en cabeza (tecla %d). El cuerpo que mueves pasa a ser el suyo." % (i + 1)
	frente.pressed.connect(func():
		if Game.cambiar_lider(i):
			_aviso = "%s va en cabeza." % pj.nombre
			_aviso_ok = true
			_avisar_cambio_lider()
			_rebuild())
	fila.add_child(frente)

	var fuera := Button.new()
	fuera.text = "A casa"
	# Alguien tiene que llevar el cuerpo, y el ORIGINAL (el que creaste) es intocable: nunca sale.
	fuera.disabled = Game.party.size() <= 1 or pj.es_original
	fuera.tooltip_text = "Es tu personaje original: no se puede dejar en casa." if pj.es_original \
		else "Lo deja en el Hogar. No se despide a nadie: sigue en tu plantilla."
	fuera.pressed.connect(func():
		if Game.sacar_del_equipo(pj):
			_aviso = "%s se queda en casa." % pj.nombre
			_aviso_ok = true
			_avisar_cambio_lider()
			_rebuild())
	fila.add_child(fuera)

	fila.add_child(_boton_aspecto(pj))


func _fila_banquillo(pj: PersonajeData) -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	_content.add_child(fila)

	fila.add_child(_punto(pj))

	var l := Label.new()
	l.text = "%s  ·  Nv.%d" % [pj.nombre, pj.level]
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(l)

	var dentro := Button.new()
	dentro.text = "Que baje"
	# En sesion multi el cupo puede ser menor que PARTY_MAX (Net.cupo_party; en solitario es 4).
	var cupo: int = mini(Game.PARTY_MAX, Net.cupo_party())
	dentro.disabled = Game.party.size() >= cupo
	dentro.pressed.connect(func():
		if Game.meter_en_equipo(pj):
			_aviso = "%s se une al equipo." % pj.nombre
			_aviso_ok = true
			_rebuild()
		else:
			_aviso = "El equipo ya va lleno (%d)." % mini(Game.PARTY_MAX, Net.cupo_party())
			_aviso_ok = false
			_rebuild())
	fila.add_child(dentro)

	# Quedarse en casa NO le desequipa: lo suyo sigue siendo suyo y al volver a bajar sigue vestido.
	# Pero entonces su espada no se puede vender ni fundir ni ponersela a otro sin robarsela, asi que
	# hace falta una forma de reclamarla sin tener que meterlo otra vez en el equipo.
	var lleva: int = _piezas_puestas(pj)
	var quitar := Button.new()
	quitar.text = "Recoger su equipo"
	quitar.disabled = lleva == 0
	quitar.tooltip_text = "Le quita lo que lleve puesto y lo devuelve al baúl, para dárselo a otro, " \
		+ "venderlo o fundirlo." if lleva > 0 else "No lleva nada puesto."
	quitar.pressed.connect(func():
		var n: int = Game.desequipar_todo(pj)
		_aviso = "%s deja %d pieza%s en el baúl." % [pj.nombre, n, "" if n == 1 else "s"]
		_aviso_ok = true
		_rebuild())
	fila.add_child(quitar)

	fila.add_child(_boton_aspecto(pj))


# Editar la CARA de cualquiera de los tuyos, esten en el equipo o en el banquillo. Antes solo el
# personaje de la ranura se podia retocar (desde el menu principal) y los companeros se quedaban
# con el aspecto del dia que los contrataste para siempre.
func _boton_aspecto(pj: PersonajeData) -> Button:
	var b := Button.new()
	b.text = "Aspecto"
	b.tooltip_text = "Cambia su cara, su color y su brillo. Ni su progreso ni su equipo se tocan."
	b.pressed.connect(func(): _editar_aspecto(pj))
	return b


func _editar_aspecto(pj: PersonajeData) -> void:
	CreadorPersonaje.abrir(self, "ASPECTO  ·  %s" % pj.nombre,
		"Solo cambia cómo se ve. Su progreso y su equipo no se tocan.",
		"Guardar cambios",
		{"nombre": pj.nombre, "color": pj.color, "metalico": pj.metalico,
			"color_alpha": pj.color_alpha, "imagen": pj.imagen},
		func(nombre: String, color: Color, metalico: float, tinte: float, png: PackedByteArray):
			var limpio: String = nombre.strip_edges()
			pj.nombre = limpio if limpio != "" else pj.nombre
			pj.color = color
			pj.metalico = clampf(metalico, 0.0, 1.0)
			pj.color_alpha = clampf(tinte, 0.0, 1.0)
			pj.set_imagen(png)
			# Repintar el cuerpo y el sequito: si no, el cambio no se ve hasta cambiar de escena.
			var jugador: Node = get_tree().get_first_node_in_group("player")
			if jugador != null and jugador.has_method("refrescar_grupo"):
				jugador.refrescar_grupo()
			_aviso = "%s cambia de aspecto." % pj.nombre
			_aviso_ok = true
			_rebuild())


# Cuantas piezas lleva puestas (para no ofrecer "recoger" a quien va desnudo).
func _piezas_puestas(pj: PersonajeData) -> int:
	var n: int = 0
	for slot in Game.EQUIP_SLOTS:
		if pj.get("equipped_" + slot) != null:
			n += 1
	return n


# El cuerpo del personaje, del tamaño de un icono: mismo color y mismo material que por el mapa.
func _punto(pj: PersonajeData) -> ColorRect:
	var punto := ColorRect.new()
	punto.custom_minimum_size = Vector2(18, 18)
	punto.color = pj.color
	punto.material = Game.material_de(pj)
	return punto


# Tocar el orden del equipo puede cambiar QUIEN va en cabeza, y de eso dependen el cuerpo que se
# ve por el mapa, el aguante y la velocidad. Se le avisa al jugador para que se repinte solo.
func _avisar_cambio_lider() -> void:
	var p: Node = get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("refrescar_lider"):
		p.refrescar_lider()


# ============================================================
#  ALMACEN: guardar en casa lo que traes en la bolsa
# ============================================================

func _build_almacen() -> void:
	MenuScaffold.titulo(_header, "EL BAÚL DE CASA", 18)
	MenuScaffold.fila(_content, "En la bolsa", "%d materiales" % Game.materiales.size())
	MenuScaffold.fila(_content, "Guardado en casa", "%d materiales" % Game.almacen_materiales.size())
	MenuScaffold.nota(_content, "Los cristales NO se guardan: esos hay que venderlos en la tienda.")

	var b := Button.new()
	b.text = "Guardar todo lo que traigo"
	b.custom_minimum_size = Vector2(0, 36)
	b.disabled = Game.materiales.is_empty()
	b.pressed.connect(_on_guardar)
	_content.add_child(b)


func _on_guardar() -> void:
	# MULTIJUGADOR: depositar toca el baul compartido -> coger el candado un momento, guardar y
	# soltarlo. Si tu companero esta en el taller, "ocupado".
	if Net.activo:
		if not await Net.abrir_taller():
			_aviso = "El hogar está ocupado (tu compañero está en el taller)."
			_aviso_ok = false
			_rebuild()
			return
		var n: int = Game.guardar_materiales_en_hogar()
		Net.cerrar_taller()
		_aviso = "Guardas %d materiales en casa." % n
		_aviso_ok = true
		_rebuild()
		return
	var n: int = Game.guardar_materiales_en_hogar()
	_aviso = "Guardas %d materiales en casa." % n
	_aviso_ok = true
	_rebuild()


# ============================================================
#  BOTE del hogar (multi): dinero comun. Tu dinero de bolsillo sigue siendo tuyo.
# ============================================================

func _build_bote() -> void:
	MenuScaffold.titulo(_header, "HUCHA DEL HOGAR", 18)
	MenuScaffold.fila(_content, "En la hucha", "%d monedas" % Net.bote_visible())
	MenuScaffold.fila(_content, "En tu bolsillo", "%d monedas" % Game.money)
	var nota: String = "Guarda dinero en casa. " + ("En multijugador es común: deposita para que "
		+ "tu compañero pueda cogerlo." if Net.activo else "Se guarda con tu partida.")
	MenuScaffold.nota(_content, nota)

	# Cantidad escrita a mano; los dos botones siempre disponibles.
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	_content.add_child(caja)

	var etq := Label.new()
	etq.text = "Cantidad:"
	caja.add_child(etq)

	var le := LineEdit.new()
	le.text = _bote_input
	le.placeholder_text = "0"
	le.custom_minimum_size = Vector2(120, 0)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_changed.connect(func(t: String): _bote_input = t)   # se conserva al re-dibujar
	caja.add_child(le)

	var dep := Button.new()
	dep.text = "Depositar"
	dep.pressed.connect(func():
		var n: int = _cantidad_bote()
		if n <= 0:
			_aviso = "Escribe una cantidad."; _aviso_ok = false
		elif Net.depositar_bote(n):
			_aviso = "Depositas %d en el bote." % n; _aviso_ok = true
		else:
			_aviso = "No tienes tanto en el bolsillo."; _aviso_ok = false
		_rebuild())
	caja.add_child(dep)

	var ret := Button.new()
	ret.text = "Retirar"
	ret.pressed.connect(func():
		var n: int = _cantidad_bote()
		if n <= 0:
			_aviso = "Escribe una cantidad."; _aviso_ok = false
		else:
			Net.retirar_bote(n)   # el host valida que hay tanto (si no, avisa por toast)
			_aviso = "Pides retirar %d del bote." % n; _aviso_ok = true
		_rebuild())
	caja.add_child(ret)


# Lee la cantidad escrita como entero (0 si no es un numero valido).
func _cantidad_bote() -> int:
	var t: String = _bote_input.strip_edges()
	return int(t) if t.is_valid_int() else 0


# ============================================================
#  COFRE del hogar (multi): armas y armaduras para traspasar. Ver paso 3.
# ============================================================

func _build_cofre() -> void:
	MenuScaffold.titulo(_header, "COFRE COMPARTIDO", 18)
	# Tres submenus: Armas (armas + mochilas), Armaduras y Consumibles (pociones/grimorios).
	const SUBS := ["Armas", "Armaduras", "Consumibles"]
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 8)
	_header.add_child(sub)
	for i in SUBS.size():
		var b := Button.new()
		b.text = SUBS[i]
		b.toggle_mode = true
		b.button_pressed = (_cofre_sub == i)
		b.pressed.connect(func():
			_cofre_sub = i
			_rebuild())
		sub.add_child(b)

	if _cofre_sub == 2:
		_build_cofre_consumibles()
		return

	var es_armas: bool = _cofre_sub == 0

	# TUYAS (baul propio, sin equipar): se pueden depositar.
	MenuScaffold.titulo(_lista, "Tuyas (para depositar)", 14)
	var mias: Array = []
	if es_armas:
		mias = Game.owned_weapons + Game.owned_mochilas
	else:
		mias = Game.owned_armor
	var alguna := false
	for item in mias:
		if Game.quien_lleva(item) != null:
			continue   # equipada: no se deposita
		alguna = true
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 6)
		_lista.add_child(fila)
		var l := Label.new()
		l.text = Game.item_display_name(item)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(l)
		var meter := Button.new()
		meter.text = "Al cofre"
		meter.pressed.connect(func():
			if Net.meter_en_cofre(item):
				_aviso = "Guardas %s en el cofre." % Game.item_display_name(item)
				_aviso_ok = true
			else:
				_aviso = "Esa pieza no se puede compartir (o la llevas puesta)."
				_aviso_ok = false
			_rebuild())
		fila.add_child(meter)
	if not alguna:
		MenuScaffold.nota(_lista, "No tienes piezas sueltas de este tipo para depositar.")

	# EN EL COFRE: se pueden sacar.
	MenuScaffold.titulo(_content, "En el cofre", 14)
	var clases: Array = ["arma", "mochila"] if es_armas else ["armadura"]
	var hay := false
	for entrada in Net.cofre_visible():
		if not clases.has(str(entrada.get("clase", ""))):
			continue
		hay = true
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 6)
		_content.add_child(fila)
		var l := Label.new()
		l.text = str(entrada.get("desc", "?"))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(l)
		var sacar := Button.new()
		sacar.text = "Sacar"
		var id: int = int(entrada.get("id", 0))
		sacar.pressed.connect(func():
			Net.sacar_de_cofre(id)
			_aviso = "Sacas la pieza del cofre."
			_aviso_ok = true
			_rebuild())
		fila.add_child(sacar)
	if not hay:
		MenuScaffold.nota(_content, "El cofre está vacío para este tipo.")


# Submenu de Consumibles del cofre: pociones y grimorios (stackean). Depositar/sacar de 1 en 1.
func _build_cofre_consumibles() -> void:
	MenuScaffold.titulo(_lista, "Tuyos (para depositar)", 14)
	var alguno := false
	for c in Game.consumables:
		var cant: int = int(Game.consumables[c])
		if cant <= 0:
			continue
		alguno = true
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 6)
		_lista.add_child(fila)
		var l := Label.new()
		l.text = "%s  x%d" % [str(c.get("nombre")), cant]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(l)
		var ruta: String = c.resource_path
		var meter := Button.new()
		meter.text = "Al cofre"
		meter.pressed.connect(func():
			Net.meter_consumible_cofre(ruta, 1)
			_aviso = "Guardas 1 en el cofre."
			_aviso_ok = true
			_rebuild())
		fila.add_child(meter)
	if not alguno:
		MenuScaffold.nota(_lista, "No llevas pociones ni grimorios.")

	MenuScaffold.titulo(_content, "En el cofre", 14)
	var hay := false
	var consum: Dictionary = Net.cofre_consumibles_visible()
	for ruta in consum:
		var cant: int = int(consum[ruta])
		if cant <= 0:
			continue
		hay = true
		var c: Resource = load(ruta)
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 6)
		_content.add_child(fila)
		var l := Label.new()
		l.text = "%s  x%d" % [str(c.get("nombre")) if c != null else ruta, cant]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(l)
		var sacar := Button.new()
		sacar.text = "Sacar"
		sacar.pressed.connect(func():
			Net.sacar_consumible_cofre(ruta, 1)
			_aviso = "Sacas 1 del cofre."
			_aviso_ok = true
			_rebuild())
		fila.add_child(sacar)
	if not hay:
		MenuScaffold.nota(_content, "No hay consumibles en el cofre.")
