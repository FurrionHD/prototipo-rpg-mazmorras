# ============================================================
#  maestro_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  Menu del MAESTRO DE HABILIDADES: donde se APRENDEN las habilidades de arma y se elige
#  cuales lleva puestas cada personaje.
#
#  Dos pestañas, que son las dos mitades del sistema:
#    EQUIPAR  -> el arma que lleva PUESTA ese personaje, y sus Game.MAX_HABILIDADES huecos.
#    APRENDER -> el catalogo entero, arma por arma, con lo que cuesta cada una.
#
#  El aprendizaje es POR PERSONAJE (cada compañero paga las suyas), asi que lo primero de todo
#  es a quien estas mirando: el selector de arriba manda sobre las dos pestañas.
#
#  El set equipado se guarda POR TIPO DE ARMA (ver Game.habilidades_equipadas), asi que aqui no
#  hay nada que "aplicar": tocas un boton y ya esta puesto para la proxima pelea.
# ============================================================

extends CanvasLayer

const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const ROJO := Color(0.9, 0.5, 0.5)
const GRIS := Color(0.6, 0.63, 0.7)

var _root: Control = null
var _side: VBoxContainer = null
var _header: VBoxContainer = null
var _content: VBoxContainer = null
var _lista: VBoxContainer = null
var _aviso_lbl: Label = null
var _dinero_lbl: Label = null
var _aviso: String = ""
var _aviso_ok: bool = true

var _tab: int = 0        # 0 = equipar, 1 = aprender
var _pj_idx: int = 0     # a quien estamos mirando, dentro de Game.plantilla_con_lider()
var _arma_idx: int = 0   # en la pestaña APRENDER: que arma del catalogo


func _ready() -> void:
	layer = 91
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para: hay que seguir respondiendo
	add_to_group("maestro_menu")

	var m: Dictionary = MenuScaffold.construir(self, "MAESTRO DE HABILIDADES",
		"Las técnicas de cada arma se aprenden aquí, y sólo caben cuatro a la vez. Cambia de arma y llevarás las suyas; vuelve a ésta y te esperan las que dejaste.",
		_cerrar, true)
	_root = m["root"]
	_side = m["side"]
	_header = m["header"]
	_content = m["content"]
	_lista = m["lista"]
	_aviso_lbl = m["aviso"]
	_dinero_lbl = m["dinero"]


func abrir() -> void:
	if Game._active_layer != null or Game.debug_panel_open:
		return
	_aviso = ""
	_pj_idx = 0
	_root.visible = true
	Game.abrir_menu(self)   # para el mundo entero mientras el menu esta abierto
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


# Todo el que puede aprender algo: el que va en cabeza mas la plantilla. El lider NO esta en
# Game.plantilla (vive en los campos planos), asi que hay que ponerlo delante a mano.
func _gente() -> Array:
	var todos: Array = [Game.lider()]
	for pj in Game.plantilla:
		if pj != Game.lider():
			todos.append(pj)
	return todos


func _pj() -> PersonajeData:
	var todos: Array = _gente()
	_pj_idx = clampi(_pj_idx, 0, todos.size() - 1)
	return todos[_pj_idx]


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
	for zona in [_side, _header, _content, _lista]:
		MenuScaffold.vaciar(zona)
	MenuScaffold.decir(_aviso_lbl, _aviso, _aviso_ok)
	_dinero_lbl.text = "%d monedas" % Game.money

	MenuScaffold.pestanas(_side, ["Equipar", "Aprender"], _tab, func(i: int):
		_tab = i
		_aviso = ""
		_rebuild())

	# El selector de PERSONA va en la cabecera y no en el lateral: manda sobre las dos pestañas,
	# asi que tiene que verse siempre y por encima de todo lo demas.
	var pj: PersonajeData = _pj()
	var nombres: Array = []
	for p in _gente():
		nombres.append("%s  Nv.%d" % [p.nombre, p.level])
	MenuScaffold.titulo(_header, "¿QUIÉN APRENDE?", 14)
	MenuScaffold.cuadricula(_header, nombres, _pj_idx, func(i: int):
		_pj_idx = i
		_aviso = ""
		_rebuild(), 4, Vector2(120, MenuScaffold.ALTO_BOTON))
	_header.add_child(HSeparator.new())

	if _tab == 0:
		_pintar_equipar(pj)
	else:
		_pintar_aprender(pj)


# ============================================================
#  Pestaña EQUIPAR: los cuatro huecos del arma que lleva PUESTA
# ============================================================
func _pintar_equipar(pj: PersonajeData) -> void:
	# CON LOS HUECOS: esta pantalla numera "1. / 2. / 3. / 4." y esos numeros TIENEN que ser los del
	# gestor. Con la lista compactada, dejar el hueco 1 vacio hacia que lo del 2 saliera aqui como "1."
	# y los dos menus se contradecian.
	var puestas: Array = Game.habilidades_con_huecos(pj)
	var pool: Array = Game.pool_habilidades(pj)
	MenuScaffold.titulo(_header, "%s  ·  %s" % [pj.nombre, _arma_puesta(pj)], 16)

	# --- Izquierda: los huecos, ocupados y libres ---
	var cuantas: int = Game.habilidades_equipadas(pj).size()   # para el rotulo: cuantas LLEVA
	MenuScaffold.titulo(_lista, "Equipadas (%d de %d)" % [cuantas, Game.MAX_HABILIDADES], 14)
	for i in Game.MAX_HABILIDADES:
		if i < puestas.size() and puestas[i] != null:
			var ab: AbilityData = puestas[i]
			var b := TooltipButton.new()
			b.text = "%d.  %s   ✕" % [i + 1, ab.nombre]
			b.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)
			b.clip_text = true
			b.tooltip_text = "Pulsa para quitarla del hueco.\n\n" + ab.resumen(Game.manos_de(ab, pj))
			b.pressed.connect(func():
				Game.desequipar_habilidad(ab, pj)
				_aviso = "%s deja de llevar %s." % [pj.nombre, ab.nombre]
				_aviso_ok = true
				_rebuild())
			_lista.add_child(b)
		else:
			var vacio := Label.new()
			vacio.text = "%d.  — hueco libre —" % (i + 1)
			vacio.add_theme_color_override("font_color", GRIS)
			vacio.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)
			_lista.add_child(vacio)

	# --- Derecha: todo lo que su equipo le permite usar ---
	if pool.is_empty():
		MenuScaffold.nota(_content, "Lo que lleva en las manos no aporta ninguna técnica. "
			+ "Los puños no tienen; cómprale un arma en la tienda.")
		return
	MenuScaffold.titulo(_content, "SU EQUIPO LE PERMITE", 14)
	MenuScaffold.nota(_content, "Sale del arma y del escudo que lleva puestos. Cambiar a otra arma "
		+ "le pone las de ésa; la misma arma de otro tier o mejorada le conserva estas.")
	_content.add_child(HSeparator.new())
	for ab in pool:
		_fila_pool(pj, ab, puestas)


# Una linea por habilidad del pool: nombre, de donde sale, y el boton que la mete o la saca.
func _fila_pool(pj: PersonajeData, ab: AbilityData, puestas: Array) -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	_content.add_child(fila)

	var nom := Label.new()
	nom.text = ab.nombre
	nom.custom_minimum_size = Vector2(180, 0)
	if puestas.has(ab):
		nom.add_theme_color_override("font_color", VERDE)
	elif not Game.habilidad_desbloqueada(ab, pj):
		nom.add_theme_color_override("font_color", GRIS)
	fila.add_child(nom)

	var b := TooltipButton.new()   # tooltip multilinea: el de Godot no parte lineas (ver tooltip_button.gd)
	b.custom_minimum_size = Vector2(130, MenuScaffold.ALTO_BOTON)
	b.tooltip_text = ab.resumen(Game.manos_de(ab, pj))
	if ab.descripcion != "":
		b.tooltip_text += "\n\n" + ab.descripcion
	if puestas.has(ab):
		b.text = "Quitar"
		b.pressed.connect(func():
			Game.desequipar_habilidad(ab, pj)
			_aviso = "%s deja de llevar %s." % [pj.nombre, ab.nombre]
			_aviso_ok = true
			_rebuild())
	elif not Game.habilidad_desbloqueada(ab, pj):
		b.text = "No la sabe"
		b.disabled = true
		b.tooltip_text = "⛔ %s todavía no sabe esta técnica: enséñasela en la pestaña Aprender (%d monedas).\n\n%s" % [
			pj.nombre, ab.precio, b.tooltip_text]
	elif puestas.size() >= Game.MAX_HABILIDADES:
		b.text = "Sin hueco"
		b.disabled = true
		b.tooltip_text = "⛔ Ya lleva %d: quítale una para meter ésta.\n\n%s" % [
			Game.MAX_HABILIDADES, b.tooltip_text]
	else:
		b.text = "Equipar"
		b.pressed.connect(func():
			if Game.equipar_habilidad(ab, pj):
				_aviso = "%s se prepara %s." % [pj.nombre, ab.nombre]
				_aviso_ok = true
			_rebuild())
	fila.add_child(b)
	# Con los dedos no hay "pasar el raton por encima", asi que la ficha de la habilidad no se podia
	# leer de ninguna manera. Ver MenuScaffold.info.
	MenuScaffold.info(fila, b, ab.nombre)


# ============================================================
#  Pestaña APRENDER: el catalogo, arma por arma
# ============================================================
func _pintar_aprender(pj: PersonajeData) -> void:
	var plantillas: Array = _plantillas()
	MenuScaffold.titulo(_header, "%s  ·  %d monedas" % [pj.nombre, Game.money], 16)

	# --- Izquierda: las armas, con cuanto le queda por aprender de cada una ---
	MenuScaffold.titulo(_lista, "Por arma", 14)
	_arma_idx = clampi(_arma_idx, 0, plantillas.size() - 1)
	for i in plantillas.size():
		var it: Resource = plantillas[i]
		var quedan: int = 0
		for ab in it.habilidades:
			if ab != null and not Game.habilidad_desbloqueada(ab, pj):
				quedan += 1
		var b := Button.new()
		b.text = "%s%s" % [it.nombre, "   (%d)" % quedan if quedan > 0 else ""]
		b.toggle_mode = true
		b.button_pressed = (i == _arma_idx)
		b.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)
		b.clip_text = true
		if quedan > 0:
			b.tooltip_text = "Le quedan %d técnicas por aprender de esta arma." % quedan
		var idx: int = i
		b.pressed.connect(func():
			_arma_idx = idx
			_aviso = ""
			_rebuild())
		_lista.add_child(b)

	# --- Derecha: las tecnicas del arma elegida ---
	var arma: Resource = plantillas[_arma_idx]
	MenuScaffold.titulo(_content, arma.nombre.to_upper(), 16)
	if arma.habilidades.is_empty():
		MenuScaffold.nota(_content, "Esta arma no tiene técnicas propias.")
		return
	MenuScaffold.nota(_content, "No hace falta llevar el arma puesta para aprender sus técnicas, "
		+ "pero sí para equiparlas.")
	_content.add_child(HSeparator.new())
	for ab in arma.habilidades:
		if ab != null:
			_fila_aprender(pj, ab)


func _fila_aprender(pj: PersonajeData, ab: AbilityData) -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	_content.add_child(fila)

	var nom := Label.new()
	nom.text = ab.nombre
	nom.custom_minimum_size = Vector2(180, 0)
	fila.add_child(nom)

	var b := TooltipButton.new()   # idem: la ficha de la habilidad necesita varias lineas
	b.custom_minimum_size = Vector2(150, MenuScaffold.ALTO_BOTON)
	# El resumen se pide a UNA mano: aqui no se sabe con que arma acabara peleando, y el numero
	# de manos solo cambia el dual (que es del loadout, no de la habilidad).
	b.tooltip_text = ab.resumen(1)
	if ab.descripcion != "":
		b.tooltip_text += "\n\n" + ab.descripcion
	if ab.inicial:
		nom.add_theme_color_override("font_color", VERDE)
		b.text = "Viene con el arma"
		b.disabled = true
	elif Game.habilidad_desbloqueada(ab, pj):
		nom.add_theme_color_override("font_color", VERDE)
		b.text = "Ya la sabe"
		b.disabled = true
	elif not Game.puede_pagar(ab.precio):
		b.text = "%d monedas" % ab.precio
		b.disabled = true
		b.tooltip_text = "⛔ Te faltan %d monedas.\n\n%s" % [ab.precio - Game.money, b.tooltip_text]
	else:
		b.text = "Aprender por %d" % ab.precio
		b.pressed.connect(func():
			if Game.aprender_habilidad(ab, pj):
				_aviso = "%s aprende %s por %d monedas." % [pj.nombre, ab.nombre, ab.precio]
				_aviso_ok = true
			else:
				_aviso = "No te llega el dinero."
				_aviso_ok = false
			_rebuild())
	fila.add_child(b)
	MenuScaffold.info(fila, b, ab.nombre)   # la ficha, para el que juega con los dedos


# Las plantillas base de todo lo que aporta habilidades: las armas y las secundarias
# (escudos y varita tambien traen las suyas, y compiten por los mismos cuatro huecos).
func _plantillas() -> Array:
	var out: Array = []
	for ruta in CatalogoEquipo.ARMAS + CatalogoEquipo.SECUNDARIAS:
		var it: Resource = load(ruta)
		if it != null and not it.habilidades.is_empty():
			out.append(it)
	return out


# Como se llama lo que lleva en las manos, para el titulo de la pestaña Equipar.
func _arma_puesta(pj: PersonajeData) -> String:
	var partes: Array = []
	partes.append(pj.equipped_main.nombre if pj.equipped_main != null else "Puños")
	if pj.equipped_off != null:
		partes.append(pj.equipped_off.nombre)
	return "  +  ".join(partes)
