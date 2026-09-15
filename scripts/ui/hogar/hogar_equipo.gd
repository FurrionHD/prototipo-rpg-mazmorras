# ============================================================
#  hogar_equipo.gd  --  seccion EQUIPO del menu del HOGAR (ver home_menu.gd, que es el armazon).
#
#  LA FORMACION, de frente y de cuerpo entero: los cuatro puestos del equipo de izquierda a derecha, que
#  es tambien como se colocan en la fila del combate (ver net_formacion.gd). Salen los tuyos Y los de
#  los demas jugadores del mundo; los de otro llevan su insignia P2/P3/P4 y no se tocan desde aqui.
#  Un puesto libre es un "+".
#
#  Pulsar uno TUYO lo elige (para "Llevar en cabeza" o "Aspecto"); pulsar un "+" o "Editar equipo" abre
#  el editor (hogar_editor_equipo.gd), que ocupa el sitio de esta vista mientras dura.
# ============================================================
extends RefCounted

const HogarEditorEquipo = preload("res://scripts/ui/hogar/hogar_editor_equipo.gd")

const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const GRIS := Color(0.6, 0.63, 0.7)

const ANCHO_PUESTO := 250.0
const ALTO_PUESTO := 440.0
const ALTO_MUNECO := 340.0
const LADO_INSIGNIA := 30.0

var hogar = null   # el armazon (home_menu.gd). Sin tipo: con CanvasLayer no se ven sus variables
var editor = null
var _sel_uid: String = ""   # el tuyo elegido en la vista
# El ORDEN que se confirmo en el editor y aun no se ha podido pedir: en compañia hay que esperar a que la
# formacion del host incluya a los que acabas de añadir (llega por red). Vacio = nada pendiente.
var _orden_pendiente: Array = []
var _orden_pendiente_t: int = 0


func _init(pantalla) -> void:
	hogar = pantalla
	editor = HogarEditorEquipo.new(pantalla, self)


func _build_equipo() -> void:
	_mirar_orden_pendiente()
	if editor.abierto:
		editor.pintar()
		return
	hogar._lista_scroll.visible = false
	hogar.contador("En el equipo  %d / %d" % [_mios_en_formacion().size(), _cupo()])

	var puestos: Array = _puestos()
	if _sel_uid.is_empty() or not _mios_en_formacion().has(_sel_uid):
		_sel_uid = String(Game.lider().uid)

	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 18)
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hogar._content.add_child(fila)
	for i in Game.PARTY_MAX:
		_puesto(fila, i, puestos[i] if i < puestos.size() else {})

	_acciones()


# Lo que va en cada puesto: [{uid, pj, mio, jugador, nombre, level}], en el orden de la formacion.
func _puestos() -> Array:
	var filas: Dictionary = {}
	for f in Net.hogar.roster_hogar():
		filas[String(f.get("uid", ""))] = f
	var out: Array = []
	for u in Net.formacion.formacion():
		var uid: String = String(u)
		var mio: PersonajeData = Game.pj_por_uid(uid)
		if mio != null:
			out.append({"uid": uid, "pj": mio, "mio": true, "jugador": 1 if not Net.activo
				else Net.formacion.num_jugador(Identidad.id), "nombre": mio.nombre, "level": mio.level})
			continue
		var f: Dictionary = filas.get(uid, {})
		if f.is_empty():
			continue
		var pj: PersonajeData = Game.pj_de_dict(f.get("aspecto", {}))
		out.append({"uid": uid, "pj": pj, "mio": false,
			"jugador": Net.formacion.num_jugador(String(f.get("dueno", ""))),
			"nombre": String(f.get("nombre", "?")), "level": int(f.get("level", 1))})
	# RESPALDO: en compañia la formacion la difunde el host, y entre que cambias tu equipo y llega la
	# nueva hay un momento en que no te incluye. Los tuyos salen igual, al final, en vez de desaparecer.
	var ya: Array = []
	for p in out:
		ya.append(String(p["uid"]))
	for pj in Game.party:
		if not ya.has(String(pj.uid)) and out.size() < Game.PARTY_MAX:
			out.append({"uid": String(pj.uid), "pj": pj, "mio": true,
				"jugador": Net.formacion.num_jugador(Identidad.id), "nombre": pj.nombre, "level": pj.level})
	return out


func _mios_en_formacion() -> Array:
	var out: Array = []
	for pj in Game.party:
		out.append(String(pj.uid))
	return out


func _cupo() -> int:
	return mini(Game.PARTY_MAX, Net.cupo_party())


# ============================================================
#  UN PUESTO
# ============================================================

func _puesto(fila: HBoxContainer, i: int, p: Dictionary) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(ANCHO_PUESTO, ALTO_PUESTO)
	b.clip_contents = true
	for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
	fila.add_child(b)

	var vacio: bool = p.is_empty()
	var mio: bool = not vacio and bool(p["mio"])
	var elegido: bool = mio and String(p["uid"]) == _sel_uid
	if vacio:
		b.tooltip_text = "Puesto libre: añade a alguien al equipo"
		b.pressed.connect(abrir_editor)
	elif mio:
		b.tooltip_text = String(p["nombre"])
		b.pressed.connect(func():
			_sel_uid = String(p["uid"])
			hogar._rebuild())
	else:
		b.tooltip_text = "%s  ·  del jugador %d" % [p["nombre"], int(p["jugador"])]

	b.draw.connect(func() -> void:
		var w: float = b.size.x
		var f: Font = b.get_theme_font(&"font")
		# El SUELO: un halo bajo los pies, ambar en el elegido.
		var pies: float = 60.0 + ALTO_MUNECO
		b.draw_set_transform(Vector2(w * 0.5, pies), 0.0, Vector2(1.0, 0.22))
		b.draw_circle(Vector2.ZERO, w * 0.36, (AMBAR if elegido else Color(0.55, 0.62, 0.80)) * Color(1, 1, 1, 0.14))
		b.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# EL NUMERO DE PUESTO arriba, pequeño: es el orden del combate.
		var num: String = "%d" % (i + 1)
		b.draw_string(f, Vector2((w - f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x) * 0.5, 14),
			num, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GRIS)
		if vacio:
			var c := Vector2(w * 0.5, 60.0 + ALTO_MUNECO * 0.55)
			b.draw_arc(c, 34.0, 0.0, TAU, 40, Color(0.55, 0.62, 0.80, 0.8), 2.0, true)
			b.draw_line(c + Vector2(-14, 0), c + Vector2(14, 0), Color(0.75, 0.80, 0.92), 3.0, true)
			b.draw_line(c + Vector2(0, -14), c + Vector2(0, 14), Color(0.75, 0.80, 0.92), 3.0, true)
			return
		# NOMBRE y NIVEL encima de la cabeza.
		var nom: String = String(p["nombre"])
		var col_nom: Color = AMBAR if elegido else Color(0.92, 0.93, 0.97)
		b.draw_string(f, Vector2((w - f.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x) * 0.5, 38),
			nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col_nom)
		var niv: String = "Nv. %d" % int(p["level"])
		b.draw_string(f, Vector2((w - f.get_string_size(niv, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x) * 0.5, 56),
			niv, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GRIS))

	if vacio:
		return
	_muneco(b, p["pj"], not mio)
	_insignias(b, p)


# El muñeco de cuerpo entero, de frente (idle_0), con la receta del altar.
func _muneco(b: Button, pj: PersonajeData, atenuado: bool) -> void:
	var caja := Control.new()
	caja.position = Vector2(0, 60)
	caja.size = Vector2(ANCHO_PUESTO, ALTO_MUNECO + 10)
	caja.clip_contents = true
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(caja)
	var mu := MunecoJugador.new()
	mu.montar(pj)
	mu.tenir(pj.color, 0.0)
	mu.poner_cara(pj.textura())
	if not mu.hay_dibujo():
		mu.queue_free()
		return
	var alto_dibujo: float = PoseJugador.ALTO_MUNDO + PoseJugador.PIES_BAJO_NODO
	var esc: float = (ALTO_MUNECO - 20.0) / alto_dibujo
	mu.scale = Vector2.ONE * esc
	mu.position = Vector2(ANCHO_PUESTO * 0.5, 10.0 + PoseJugador.ALTO_MUNDO * esc)
	mu.animar("idle_0")
	if atenuado:
		mu.modulate = Color(0.78, 0.78, 0.82)
	caja.add_child(mu)


# LAS INSIGNIAS, en una capa con z 4096 para que el muñeco (z absoluto) no las tape: P2/P3/P4 en los
# de otro jugador y la estrella en el tuyo que va en cabeza.
func _insignias(b: Button, p: Dictionary) -> void:
	var mio: bool = bool(p["mio"])
	var lider: bool = mio and String(p["uid"]) == String(Game.lider().uid)
	if mio and not lider:
		return
	var capa := Control.new()
	capa.size = b.custom_minimum_size
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.z_index = 4096
	b.add_child(capa)
	var jugador: int = int(p["jugador"])
	capa.draw.connect(func() -> void:
		var f: Font = capa.get_theme_font(&"font")
		var c := Vector2(ANCHO_PUESTO - 34.0, 34.0)
		var r: float = LADO_INSIGNIA * 0.5
		capa.draw_circle(c + Vector2(0, 2), r, Color(0, 0, 0, 0.45))
		if lider:
			capa.draw_circle(c, r, Color(0.10, 0.11, 0.15))
			capa.draw_arc(c, r, 0.0, TAU, 28, AMBAR, 1.5, true)
			var e: String = "★"
			capa.draw_string(f, c + Vector2(-f.get_string_size(e, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x * 0.5, 6),
				e, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, AMBAR)
		else:
			capa.draw_circle(c, r, Color(0.45, 0.72, 0.95))
			capa.draw_arc(c, r, 0.0, TAU, 28, Color(0.85, 0.93, 1.0), 1.5, true)
			var t: String = "P%d" % jugador
			capa.draw_string(f, c + Vector2(-f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x * 0.5, 5),
				t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.06, 0.08, 0.12)))


# ============================================================
#  LOS BOTONES DE ABAJO
# ============================================================

func _acciones() -> void:
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 12)
	hogar._content.add_child(fila)
	var ed: Button = MenuScaffold.pastilla(fila, "Editar equipo", abrir_editor)
	ed.custom_minimum_size = Vector2(200, MenuScaffold.ALTO_BOTON)

	var pj: PersonajeData = Game.pj_por_uid(_sel_uid)
	if pj == null:
		return
	var es_lider: bool = pj == Game.lider()
	var cab: Button = MenuScaffold.pastilla(fila, "Va en cabeza" if es_lider else "Llevar en cabeza",
		func():
			Game.cambiar_lider(Game.party.find(pj))
			_avisar_cambio_lider()
			hogar._aviso = "%s va en cabeza." % pj.nombre
			hogar._aviso_ok = true
			hogar._rebuild(), false, not es_lider)
	cab.custom_minimum_size = Vector2(200, MenuScaffold.ALTO_BOTON)
	cab.tooltip_text = "El que va en cabeza es el cuerpo que mueves por el mapa. También se cambia con las teclas 1, 2, 3 y 4."
	var asp: Button = MenuScaffold.pastilla(fila, "Aspecto", func(): _editar_aspecto(pj), false)
	asp.custom_minimum_size = Vector2(160, MenuScaffold.ALTO_BOTON)


func pedir_orden_cuando_llegue(orden: Array) -> void:
	_orden_pendiente = orden
	_orden_pendiente_t = Time.get_ticks_msec()
	_mirar_orden_pendiente()


# Cuando la formacion del host ya tiene a los mismos que el orden confirmado, se pide ese orden (si es
# otro). Si en 10 s no llega a coincidir (el cupo te quito a alguien, por ejemplo), se olvida.
func _mirar_orden_pendiente() -> void:
	if _orden_pendiente.is_empty():
		return
	if Time.get_ticks_msec() - _orden_pendiente_t > 10000:
		_orden_pendiente = []
		return
	var actual: Array = Net.formacion.formacion()
	if actual.size() != _orden_pendiente.size():
		return
	for u in _orden_pendiente:
		if not actual.has(u):
			return
	var orden: Array = _orden_pendiente
	_orden_pendiente = []
	if orden != actual:
		Net.formacion.pedir_orden(orden)


func abrir_editor() -> void:
	editor.abrir()
	hogar._rebuild()


# Editar la CARA de cualquiera de los tuyos (el editor la usa tambien para los de casa).
func _editar_aspecto(pj: PersonajeData) -> void:
	CreadorPersonaje.abrir(hogar, "ASPECTO  ·  %s" % pj.nombre,
		"Solo cambia cómo se ve. Su progreso y su equipo no se tocan.",
		"Guardar cambios",
		{"nombre": pj.nombre, "color": pj.color, "metalico": pj.metalico,
			"color_alpha": pj.color_alpha, "imagen": pj.imagen,
			"piezas": pj.aspecto_completo()["piezas"]},
		func(nombre: String, asp: Dictionary):
			var limpio: String = nombre.strip_edges()
			pj.nombre = limpio if limpio != "" else pj.nombre
			pj.aplicar_aspecto(asp)
			# Repintar el cuerpo y el sequito: si no, el cambio no se ve hasta cambiar de escena.
			var jugador: Node = hogar.get_tree().get_first_node_in_group("player")
			if jugador != null and jugador.has_method("refrescar_grupo"):
				jugador.refrescar_grupo()
			# MULTI: y re-difundirlo, o el compañero no lo veria hasta cambiar de escena.
			if Net.activo:
				Net.pisos.anunciar_aspecto()
				Net.jugadores.anunciar_grupo()
				Net.hogar.marcar_hogar_sucio()
			hogar._aviso = "%s cambia de aspecto." % pj.nombre
			hogar._aviso_ok = true
			hogar._rebuild())


# Tocar quien va en cabeza cambia el cuerpo que se ve por el mapa, el aguante y la velocidad.
func _avisar_cambio_lider() -> void:
	var p: Node = hogar.get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("refrescar_lider"):
		p.refrescar_lider()
