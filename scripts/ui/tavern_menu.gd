# ============================================================
#  tavern_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  Menu de la TABERNA: donde se contrata gente para el grupo.
#
#  Contratar es CREAR un personaje: se abre la MISMA pantalla con la que te creaste tu
#  (CreadorPersonaje: nombre, color, brillo e imagen propia). No hay lista de candidatos que
#  rotan ni tiradas: eliges tu quien se une y que cara tiene.
#
#  El que llega viene A CERO y DESNUDO: nivel 1, las cinco habilidades a 0 y sin equipo. Lo que
#  valga sale de bajarlo a la mazmorra y de lo que le pongas encima, igual que contigo.
#
#  Aqui NO se despide a nadie: quien ficha se queda para siempre en la PLANTILLA. Quien BAJA
#  contigo (como mucho Game.PARTY_MAX) se decide en el Hogar, en el gestor de equipo.
# ============================================================

extends CanvasLayer

const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const ROJO := Color(0.9, 0.5, 0.5)
const GRIS := Color(0.6, 0.63, 0.7)

var _root: Control = null
var _header: VBoxContainer = null
var _content: VBoxContainer = null
var _lista: VBoxContainer = null
var _aviso_lbl: Label = null
var _dinero_lbl: Label = null
var _aviso: String = ""
var _aviso_ok: bool = true


func _ready() -> void:
	layer = 91
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para: hay que seguir respondiendo
	add_to_group("tavern_menu")

	var m: Dictionary = MenuScaffold.construir(self, "TABERNA",
		"Aquí se junta gente buscando con quién bajar. Contrata a quien quieras: llega sin nada y sin experiencia, lo demás lo pondrás tú.",
		_cerrar, true)
	_root = m["root"]
	_header = m["header"]
	_content = m["content"]
	_lista = m["lista"]
	_aviso_lbl = m["aviso"]
	_dinero_lbl = m["dinero"]


func abrir() -> void:
	if Game._active_layer != null or Game.debug_panel_open:
		return
	_aviso = ""
	_root.visible = true
	Game.abrir_menu()   # para el mundo entero mientras el menu esta abierto
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


func _rebuild() -> void:
	for zona in [_header, _content, _lista]:
		for c in zona.get_children():
			c.queue_free()
	MenuScaffold.decir(_aviso_lbl, _aviso, _aviso_ok)
	_dinero_lbl.text = "%d monedas" % Game.money

	var precio: int = Game.precio_fichar()
	MenuScaffold.titulo(_header, "CONTRATAR", 18)

	# --- Izquierda: quien tienes ya ---
	MenuScaffold.titulo(_lista, "Tu gente (%d)" % Game.plantilla.size(), 14)
	for pj in Game.plantilla:
		_ficha_lista(pj)

	# --- Derecha: el trato ---
	MenuScaffold.fila(_content, "Cuesta", "%d monedas" % precio)
	MenuScaffold.fila(_content, "Tienes", "%d monedas" % Game.money)
	MenuScaffold.fila(_content, "En plantilla", "%d" % Game.plantilla.size())
	MenuScaffold.fila(_content, "Bajan contigo", "%d de %d" % [Game.party.size(), Game.PARTY_MAX])
	MenuScaffold.nota(_content, "Cada contrato cuesta el doble que el anterior. Se paga UNA vez: "
		+ "no hay sueldos ni cuotas, pero armar y reparar a tres cuesta lo que cuesta.")
	MenuScaffold.nota(_content, "Llega a nivel 1, con las cinco habilidades a 0 y sin nada equipado. "
		+ "Se le pone equipo desde el menú de personaje (C) y sube sus habilidades peleando, como tú.")
	if Game.party.size() >= Game.PARTY_MAX:
		MenuScaffold.nota(_content, "Tu equipo ya va lleno: quien contrates ahora se queda en el "
			+ "Hogar hasta que lo metas en el equipo desde allí.")

	_content.add_child(HSeparator.new())

	var b := Button.new()
	b.text = "Contratar por %d" % precio
	b.custom_minimum_size = Vector2(0, 38)
	b.disabled = not Game.puede_pagar(precio)
	b.pressed.connect(_abrir_creador)
	_content.add_child(b)
	if b.disabled:
		var falta := Label.new()
		falta.text = "Te faltan %d monedas." % (precio - Game.money)
		falta.add_theme_color_override("font_color", ROJO)
		falta.add_theme_font_size_override("font_size", 12)
		_content.add_child(falta)


# Una linea por persona de la plantilla, con su color de cuerpo delante para reconocerla de un
# vistazo (es lo mismo que se ve andando por el mapa).
func _ficha_lista(pj: PersonajeData) -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	_lista.add_child(fila)

	var punto := ColorRect.new()
	punto.custom_minimum_size = Vector2(18, 18)
	punto.color = pj.color
	punto.material = Game.material_de(pj)
	fila.add_child(punto)

	var l := Label.new()
	l.text = "%s  ·  Nv.%d" % [pj.nombre, pj.level]
	fila.add_child(l)

	var estado := Label.new()
	if pj == Game.lider():
		estado.text = "  (en cabeza)"
		estado.add_theme_color_override("font_color", AMBAR)
	elif Game.party.has(pj):
		estado.text = "  (en el equipo)"
		estado.add_theme_color_override("font_color", VERDE)
	else:
		estado.text = "  (en el Hogar)"
		estado.add_theme_color_override("font_color", GRIS)
	estado.add_theme_font_size_override("font_size", 12)
	fila.add_child(estado)


func _abrir_creador() -> void:
	var precio: int = Game.precio_fichar()
	CreadorPersonaje.abrir(self, "CONTRATAR  ·  %d monedas" % precio,
		"Llega a nivel 1, sin habilidades y sin equipo. Lo demás lo pones tú.",
		"Contratar", {"color": CreadorPersonaje.COLOR_INICIAL},
		func(nombre: String, color: Color, metalico: float, tinte: float, png: PackedByteArray):
			var pj: PersonajeData = Game.fichar_en_taberna(nombre, color, metalico, png, tinte)
			if pj == null:
				_aviso = "No te llega el dinero."
				_aviso_ok = false
			elif Game.party.has(pj):
				_aviso = "%s se une al grupo. Baja contigo desde ya." % pj.nombre
				_aviso_ok = true
			else:
				_aviso = "%s se une, pero tu equipo va lleno: te espera en el Hogar." % pj.nombre
				_aviso_ok = true
			_rebuild())
