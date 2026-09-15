# ============================================================
#  hogar_editor_equipo.gd  --  el EDITOR DE EQUIPO del hogar (lo abre hogar_equipo.gd).
#
#  A la izquierda "Mis personajes": tocar uno lo AÑADE al equipo o lo ENVIA A CASA. A la derecha la
#  FORMACION en circulos, con los de los demas jugadores tambien (con su P2): arrastrando a uno de los
#  tuyos se cambia el orden, que es el de la fila del combate.
#
#  TODO ES UN BORRADOR hasta Confirmar, y Confirmar aplica el equipo DE GOLPE (Game.aplicar_equipo).
#  Asi se puede quedar uno solo aunque haya cupo para mas, y cambiar a uno por otro con el cupo lleno:
#  antes, en compañia, enviar a casa al ultimo dejaba el equipo vacio un frame y el juego metia solo al
#  personaje original, que ocupaba el hueco.
#
#  Si el orden nuevo desplaza a personajes de otro jugador, al confirmar se le PIDE (Net.formacion).
# ============================================================
extends RefCounted

const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const GRIS := Color(0.6, 0.63, 0.7)
const LADO_CIRCULO := 104.0
const RETRATOS_POR_FILA := 5

var hogar = null
var vista = null   # hogar_equipo.gd
var abierto: bool = false
var _borrador: Array = []    # uids de la formacion que se esta montando, de izquierda a derecha
var _puestos: Dictionary = {}   # uid -> el puesto tal como lo da la vista (nombre, nivel, jugador...)


func _init(pantalla, la_vista) -> void:
	hogar = pantalla
	vista = la_vista


func abrir() -> void:
	abierto = true
	_borrador = []
	_puestos = {}
	for p in vista._puestos():
		_borrador.append(String(p["uid"]))
		_puestos[String(p["uid"])] = p


func cancelar() -> void:
	abierto = false
	hogar._aviso = ""
	hogar._rebuild()


# ============================================================
#  PINTAR
# ============================================================

func pintar() -> void:
	hogar._lista_scroll.visible = true
	hogar._lista_scroll.custom_minimum_size = Vector2(RETRATOS_POR_FILA * (MenuScaffold.LADO_RETRATO + 10.0) + 20.0, 0)
	hogar._titulo_seccion.text = "Editar equipo"
	hogar.contador("Tuyos  %d / %d" % [_mios().size(), vista._cupo()])
	_pintar_lista()
	_pintar_formacion()


func _mios() -> Array:
	var out: Array = []
	for u in _borrador:
		if Game.pj_por_uid(String(u)) != null:
			out.append(u)
	return out


# --- IZQUIERDA: MIS PERSONAJES ---
func _pintar_lista() -> void:
	MenuScaffold.titulo(hogar._lista, "Mis personajes", 15)
	MenuScaffold.nota(hogar._lista, "Toca a uno para añadirlo al equipo o enviarlo a casa.")
	var fila: HBoxContainer = null
	var n: int = 0
	for pj in Game.plantilla:
		if String(pj.uid).is_empty():
			continue
		if n % RETRATOS_POR_FILA == 0:
			fila = HBoxContainer.new()
			fila.add_theme_constant_override("separation", 10)
			hogar._lista.add_child(fila)
		n += 1
		var uid: String = String(pj.uid)
		var pos: int = _borrador.find(uid)
		var de_encargo: bool = Game.esta_de_encargo(pj)
		MenuScaffold._retrato(fila, pj, 0, pos >= 0, pos >= 0, func(_i): _alternar(pj))
		var b: Button = fila.get_child(fila.get_child_count() - 1)
		if de_encargo:
			b.disabled = true
			b.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
			b.tooltip_text = "%s está de encargo: vuelve cuando lo recojas." % pj.nombre
		else:
			b.tooltip_text = ("%s  ·  puesto %d. Tócalo para enviarlo a casa." % [pj.nombre, pos + 1]) if pos >= 0 \
				else "%s  ·  en casa. Tócalo para añadirlo al equipo." % pj.nombre
		_marca_retrato(b, pos, de_encargo)

	# RECOGER EL EQUIPO de los que se quedan en casa: libera sus piezas para otros.
	var con_piezas: Array = []
	for pj in Game.en_el_banquillo():
		if not _borrador.has(String(pj.uid)) and _piezas_puestas(pj) > 0:
			con_piezas.append(pj)
	if not con_piezas.is_empty():
		var hueco := Control.new()
		hueco.custom_minimum_size = Vector2(0, 10)
		hogar._lista.add_child(hueco)
		MenuScaffold.pastilla(hogar._lista, "Recoger el equipo de los de casa", func():
			var total: int = 0
			for pj in con_piezas:
				total += Game.desequipar_todo(pj)
			hogar._aviso = "Dejan %d pieza%s en el baúl." % [total, "" if total == 1 else "s"]
			hogar._aviso_ok = true
			hogar._rebuild(), false)


# El NUMERO DE PUESTO en la esquina del retrato de los que van (o la marca de encargo), en una capa con
# z 4096 para que la cara del muñeco (z absoluto) no lo tape.
func _marca_retrato(b: Button, pos: int, de_encargo: bool) -> void:
	if pos < 0 and not de_encargo:
		return
	var capa := Control.new()
	capa.size = Vector2(MenuScaffold.LADO_RETRATO, MenuScaffold.LADO_RETRATO)
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.z_index = 4096
	b.add_child(capa)
	capa.draw.connect(func() -> void:
		var f: Font = capa.get_theme_font(&"font")
		var c := Vector2(13.0, 13.0)
		capa.draw_circle(c, 11.0, Color(0.03, 0.04, 0.06, 0.92))
		if de_encargo:
			capa.draw_arc(c, 10.0, 0.0, TAU, 20, GRIS, 1.5, true)
			capa.draw_line(c + Vector2(-5, -5), c + Vector2(5, 5), GRIS, 2.0, true)
			return
		capa.draw_arc(c, 10.0, 0.0, TAU, 20, AMBAR, 1.5, true)
		var t: String = "%d" % (pos + 1)
		capa.draw_string(f, c + Vector2(-f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x * 0.5, 5),
			t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, AMBAR))


# --- DERECHA: LA FORMACION ---
func _pintar_formacion() -> void:
	MenuScaffold.titulo(hogar._content, "Formación", 15)
	MenuScaffold.nota(hogar._content, "De izquierda a derecha es como os colocáis en el combate. "
		+ "Arrastra a los tuyos para cambiar el orden." + ("  Si mueves a los de otro jugador, se le pedirá." if Net.activo else ""))
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 16)
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hogar._content.add_child(fila)
	for i in Game.PARTY_MAX:
		var h := Hueco.new()
		h.editor = self
		h.idx = i
		h.custom_minimum_size = Vector2(LADO_CIRCULO + 24.0, LADO_CIRCULO + 58.0)
		fila.add_child(h)
		_pintar_hueco(h, i)

	var hueco := Control.new()
	hueco.custom_minimum_size = Vector2(0, 16)
	hogar._content.add_child(hueco)
	var acc := HBoxContainer.new()
	acc.alignment = BoxContainer.ALIGNMENT_CENTER
	acc.add_theme_constant_override("separation", 12)
	hogar._content.add_child(acc)
	var c: Button = MenuScaffold.pastilla(acc, "Cancelar", cancelar, false)
	c.custom_minimum_size = Vector2(170, MenuScaffold.ALTO_BOTON)
	var ok: Button = MenuScaffold.pastilla(acc, "Confirmar", confirmar)
	ok.custom_minimum_size = Vector2(170, MenuScaffold.ALTO_BOTON)


func _pintar_hueco(h: Control, i: int) -> void:
	var uid: String = String(_borrador[i]) if i < _borrador.size() else ""
	var p: Dictionary = _datos(uid)
	var vacio: bool = p.is_empty()
	var mio: bool = not vacio and bool(p["mio"])
	h.arrastrable = mio
	h.mouse_default_cursor_shape = Control.CURSOR_DRAG if mio else Control.CURSOR_ARROW
	if not vacio:
		h.tooltip_text = String(p["nombre"]) if mio else "%s  ·  del jugador %d" % [p["nombre"], int(p["jugador"])]
	var centro := Vector2((LADO_CIRCULO + 24.0) * 0.5, 12.0 + LADO_CIRCULO * 0.5)
	h.draw.connect(func() -> void:
		var f: Font = h.get_theme_font(&"font")
		var r: float = LADO_CIRCULO * 0.5
		h.draw_circle(centro, r, Color(0.08, 0.09, 0.12))
		h.draw_arc(centro, r, 0.0, TAU, 48, AMBAR if mio else Color(1, 1, 1, 0.22), 2.0, true)
		var num: String = "%d" % (i + 1)
		h.draw_string(f, Vector2(4, 12), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GRIS)
		if vacio:
			h.draw_line(centro + Vector2(-12, 0), centro + Vector2(12, 0), Color(0.6, 0.65, 0.78), 3.0, true)
			h.draw_line(centro + Vector2(0, -12), centro + Vector2(0, 12), Color(0.6, 0.65, 0.78), 3.0, true)
			return
		var w: float = h.size.x
		var nom: String = String(p["nombre"])
		h.draw_string(f, Vector2((w - f.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x) * 0.5,
			LADO_CIRCULO + 34.0), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, AMBAR if mio else Color(0.92, 0.93, 0.97))
		var niv: String = "Nv. %d" % int(p["level"])
		h.draw_string(f, Vector2((w - f.get_string_size(niv, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x) * 0.5,
			LADO_CIRCULO + 50.0), niv, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GRIS))
	if vacio:
		return
	# LA CARA en el circulo: el mismo encuadre que los retratos (cabeza y hombros).
	var marco := Control.new()
	var lado: float = LADO_CIRCULO - 8.0
	marco.position = centro - Vector2(lado, lado) * 0.5
	marco.size = Vector2(lado, lado)
	marco.clip_contents = true
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(marco)
	var pj: PersonajeData = p["pj"]
	var mu := MunecoJugador.new()
	mu.montar(pj)
	mu.tenir(pj.color, 0.0)
	mu.poner_cara(pj.textura())
	if mu.hay_dibujo():
		var esc: float = lado * 2.1 / PoseJugador.ALTO_MUNDO
		mu.scale = Vector2.ONE * esc
		mu.position = Vector2(lado * 0.5, lado * 1.02)
		mu.animar("idle_0")
		if not mio:
			mu.modulate = Color(0.78, 0.78, 0.82)
		marco.add_child(mu)
	else:
		mu.queue_free()
	if not mio:
		_insignia_jugador(h, centro + Vector2(LADO_CIRCULO * 0.36, -LADO_CIRCULO * 0.36), int(p["jugador"]))


func _insignia_jugador(h: Control, c: Vector2, jugador: int) -> void:
	var capa := Control.new()
	capa.size = h.custom_minimum_size
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.z_index = 4096
	h.add_child(capa)
	capa.draw.connect(func() -> void:
		var f: Font = capa.get_theme_font(&"font")
		capa.draw_circle(c + Vector2(0, 2), 14.0, Color(0, 0, 0, 0.45))
		capa.draw_circle(c, 14.0, Color(0.45, 0.72, 0.95))
		capa.draw_arc(c, 14.0, 0.0, TAU, 28, Color(0.85, 0.93, 1.0), 1.5, true)
		var t: String = "P%d" % jugador
		capa.draw_string(f, c + Vector2(-f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x * 0.5, 5),
			t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.06, 0.08, 0.12)))


# Los datos de un puesto del borrador: los de la vista si ya estaba, o uno tuyo recien añadido.
func _datos(uid: String) -> Dictionary:
	if uid.is_empty():
		return {}
	if _puestos.has(uid):
		return _puestos[uid]
	var pj: PersonajeData = Game.pj_por_uid(uid)
	if pj == null:
		return {}
	return {"uid": uid, "pj": pj, "mio": true, "jugador": Net.formacion.num_jugador(Identidad.id),
		"nombre": pj.nombre, "level": pj.level}


func _piezas_puestas(pj: PersonajeData) -> int:
	var n: int = 0
	for slot in Game.EQUIP_SLOTS:
		if pj.get("equipped_" + slot) != null:
			n += 1
	return n


# ============================================================
#  EDITAR EL BORRADOR
# ============================================================

func _alternar(pj: PersonajeData) -> void:
	var uid: String = String(pj.uid)
	if _borrador.has(uid):
		if _mios().size() <= 1:
			_decir("Tiene que ir al menos uno de los tuyos.", false)
			return
		_borrador.erase(uid)
		_decir("%s se queda en casa." % pj.nombre, true)
		return
	if Game.esta_de_encargo(pj):
		_decir("%s está de encargo." % pj.nombre, false)
		return
	if _mios().size() >= vista._cupo():
		_decir("Solo caben %d de los tuyos: envía a casa a otro primero." % vista._cupo(), false)
		return
	if _borrador.size() >= Game.PARTY_MAX:
		_decir("El equipo está lleno.", false)
		return
	_borrador.append(uid)
	_decir("%s se une al equipo." % pj.nombre, true)


# Arrastrar de un puesto a otro: el de 'desde' pasa a 'hasta' y los de en medio se corren.
func soltar(desde: int, hasta: int) -> void:
	if desde < 0 or desde >= _borrador.size() or desde == hasta:
		return
	var uid: String = String(_borrador[desde])
	_borrador.remove_at(desde)
	_borrador.insert(clampi(hasta, 0, _borrador.size()), uid)
	hogar._rebuild()


func confirmar() -> void:
	var mios: Array = _mios()
	var error: String = Game.aplicar_equipo(mios)
	if error != "":
		_decir(error, false)
		return
	abierto = false
	vista._avisar_cambio_lider()
	if Net.activo:
		# El ORDEN entre jugadores lo decide el host: se le pide cuando la formacion ya incluya a los
		# que acabas de añadir (llega por red, ver hogar_equipo._orden_pendiente).
		vista.pedir_orden_cuando_llegue(_borrador.duplicate())
	hogar._aviso = "Equipo actualizado."
	hogar._aviso_ok = true
	hogar._rebuild()


func _decir(txt: String, ok: bool) -> void:
	hogar._aviso = txt
	hogar._aviso_ok = ok
	hogar._rebuild()


# ============================================================
#  UN HUECO DE LA FORMACION: se arrastra (si es tuyo) y se suelta encima de otro
# ============================================================
class Hueco extends Control:
	var editor = null
	var idx: int = 0
	var arrastrable: bool = false

	func _get_drag_data(_pos: Vector2) -> Variant:
		if not arrastrable:
			return null
		var l := Label.new()
		l.text = "  Puesto %d  " % (idx + 1)
		l.add_theme_font_size_override("font_size", 14)
		set_drag_preview(l)
		return {"hueco_formacion": idx}

	func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
		return data is Dictionary and (data as Dictionary).has("hueco_formacion")

	func _drop_data(_pos: Vector2, data: Variant) -> void:
		editor.soltar(int((data as Dictionary)["hueco_formacion"]), idx)
