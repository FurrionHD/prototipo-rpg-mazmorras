# ============================================================
#  multi_menu.gd
#  EL APARTADO DE MULTIJUGADOR del menu principal: la lista de MUNDOS COMPARTIDOS.
#
#  Un mundo no es una ranura: es una partida que lleva DENTRO a todos los que juegan en ella, cada
#  personaje a nombre de su jugador (ver jugador_data.gd), y que puede abrir cualquiera de ellos --
#  pero uno a la vez, porque abrirlo coge el CERROJO (ver cloud.gd). Las 3 ranuras del menu de
#  inicio siguen siendo de un jugador y no se tocan.
#
#  Dos listas, y son distintas a proposito:
#    MIS MUNDOS          los que yo he creado. Los abro yo (me llevo el cerrojo y soy el anfitrion).
#    DE OTRAS PERSONAS   los de mis compañeros. A esos me UNO, no los abro.
#
#  REGLA DE ESTE FICHERO: aqui NO hay logica de negocio. Todo lo que decide algo vive en el
#  autoload Mundos (que se puede probar en headless sin abrir una ventana); esto solo pinta y llama.
#  Interfaz placeholder por codigo, como el resto; el arte va al final.
# ============================================================

extends Control

const MENU_PRINCIPAL := "res://scenes/ui/main_menu.tscn"
const PUEBLO := "res://scenes/levels/town.tscn"
const MAZMORRA := "res://scenes/levels/main.tscn"

const AMBAR := Color(0.95, 0.72, 0.36)
const AZUL := Color(0.55, 0.75, 0.98)
const ROJO := Color(0.9, 0.5, 0.5)
const VERDE := Color(0.6, 0.9, 0.6)

const MIOS := 0
const AJENOS := 1

var _capa: CanvasLayer = null
var _piezas: Dictionary = {}
var _pestana: int = MIOS
var _sel: String = ""          # clave del mundo seleccionado
var _trabajando := false       # una operacion de red/disco en marcha: no dejar pulsar dos veces


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_capa = CanvasLayer.new()
	add_child(_capa)
	_piezas = MenuScaffold.construir(_capa, "MULTIJUGADOR", "Mundos compartidos", _volver)
	(_piezas["root"] as Control).visible = true
	Mundos.aviso.connect(func(t: String): MenuScaffold.decir(_piezas["aviso"], t, true))
	Nube.cerrojo_perdido.connect(func(m: String): MenuScaffold.decir(_piezas["aviso"], m, false))
	_pintar()


func _volver() -> void:
	get_tree().change_scene_to_file(MENU_PRINCIPAL)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		_volver()
		get_viewport().set_input_as_handled()


# ============================================================
#  PINTAR
# ------------------------------------------------------------
func _pintar() -> void:
	var header: VBoxContainer = _piezas["header"]
	var lista: VBoxContainer = _piezas["lista"]
	for c in header.get_children():
		c.queue_free()
	for c in lista.get_children():
		c.queue_free()

	MenuScaffold.pestanas(header, ["MIS MUNDOS", "DE OTRAS PERSONAS"], _pestana, _on_pestana, 150)

	# Quien soy: hace falta que se vea, porque es la llave de tus personajes en todos los mundos.
	var quien := Label.new()
	quien.text = "Eres «%s»  ·  id %s" % [Identidad.nombre, Identidad.id]
	quien.add_theme_font_size_override("font_size", 11)
	quien.add_theme_color_override("font_color", MenuScaffold.GRIS)
	header.add_child(quien)

	var mundos: Array = Mundos.catalogo().filter(func(e):
		return bool(e.get("mio", false)) == (_pestana == MIOS))

	if mundos.is_empty():
		MenuScaffold.nota(lista, "Todavía no hay nada aquí." if _pestana == MIOS \
			else "Aquí aparecerán los mundos de tus compañeros cuando los añadas.")
	for e in mundos:
		_fila_mundo(lista, e)

	var nuevo := Button.new()
	nuevo.custom_minimum_size = Vector2(0, 34)
	nuevo.text = "+ Crear un mundo nuevo" if _pestana == MIOS else "+ Añadir el mundo de otra persona"
	nuevo.pressed.connect(_crear_mundo if _pestana == MIOS else _anadir_ajeno)
	lista.add_child(nuevo)

	_pintar_detalle()


func _fila_mundo(lista: VBoxContainer, e: Dictionary) -> void:
	var clave: String = String(e["clave"])
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	lista.add_child(caja)

	# El ICONO del mundo (el jugador elige una imagen suya, como con los personajes): es lo que hace
	# que dos mundos se distingan de un vistazo.
	var icono := TextureRect.new()
	icono.custom_minimum_size = Vector2(34, 34)
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var tex: Texture2D = _textura(e.get("icono", PackedByteArray()))
	if tex != null:
		icono.texture = tex
	else:
		var col := ColorRect.new()
		col.custom_minimum_size = Vector2(34, 34)
		col.color = e.get("color", AZUL)
		caja.add_child(col)
	if tex != null:
		caja.add_child(icono)

	var b := Button.new()
	b.custom_minimum_size = Vector2(240, 34)
	b.text = String(e.get("nombre", "?"))
	if int(e.get("estado", SaveIO.VACIA)) not in [SaveIO.VACIA, SaveIO.OK]:
		b.text += "  ⚠"
	if bool(e.get("pendiente", false)):
		b.text += "  ⬆"
	b.toggle_mode = true
	b.button_pressed = (clave == _sel)
	b.pressed.connect(func():
		_sel = clave
		_pintar())
	caja.add_child(b)


func _textura(bytes) -> Texture2D:
	if not (bytes is PackedByteArray) or (bytes as PackedByteArray).is_empty():
		return null
	var img := Image.new()
	if img.load_png_from_buffer(bytes as PackedByteArray) != OK:
		return null
	return ImageTexture.create_from_image(img)


func _pintar_detalle() -> void:
	var vb: VBoxContainer = _piezas["content"]
	for c in vb.get_children():
		c.queue_free()

	if _sel == "":
		MenuScaffold.nota(vb, "Elige un mundo de la lista, o crea uno nuevo.\n\n"
			+ "Un mundo compartido guarda dentro a todos los que juegan en él: tu personaje vive en "
			+ "el mundo, no en tu disco, y te lo encuentras igual lo abra quien lo abra. "
			+ "Solo puede tenerlo abierto uno a la vez.")
		return

	var e: Dictionary = Mundos.entrada(_sel)
	if e.is_empty():
		_sel = ""
		return

	MenuScaffold.titulo(vb, String(e.get("nombre", "?")), 20, AMBAR)
	MenuScaffold.fila(vb, "Partida", String(e.get("cab", "—")), 110)
	MenuScaffold.fila(vb, "Última vez", String(e.get("fecha", "—")), 110)
	if bool(e.get("mio", false)):
		MenuScaffold.fila(vb, "Código del mundo", String(e.get("id_nube", "—")), 110)
		MenuScaffold.nota(vb, "Ese código y la contraseña son lo que necesitan tus compañeros para "
			+ "añadir este mundo a su lista.")
	else:
		MenuScaffold.fila(vb, "Dirección", String(e.get("direccion", "—")), 110)

	var motivo: String = String(e.get("motivo", ""))
	if motivo != "":
		MenuScaffold.fila(vb, "Ojo", motivo, 110, ROJO)

	# La contraseña: SIEMPRE se pide, tanto para abrir como para unirse. Si la marcaste como
	# recordada sale ya puesta.
	var lbl := Label.new()
	lbl.text = "Contraseña del mundo"
	lbl.add_theme_font_size_override("font_size", 12)
	vb.add_child(lbl)
	var campo := LineEdit.new()
	campo.text = String(e.get("contrasena", ""))
	campo.secret = true
	campo.custom_minimum_size = Vector2(260, 0)
	vb.add_child(campo)

	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 8)
	vb.add_child(botones)

	if bool(e.get("mio", false)):
		_boton(botones, "Abrir y jugar", func(): _abrir(_sel, campo.text))
		if bool(e.get("pendiente", false)):
			_boton(botones, "Reintentar subida", func(): _reintentar(_sel))
	else:
		# UNIRSE todavia no: hace falta el handshake con identidad para que el anfitrion le entregue
		# a este jugador SU personaje del mundo. Se dice, en vez de dejar un boton que no hace nada.
		var u := Button.new()
		u.text = "Unirse"
		u.disabled = true
		botones.add_child(u)
		MenuScaffold.nota(vb, "Unirse llega en el siguiente paso: falta que el anfitrión te entregue "
			+ "tu personaje de ese mundo (hoy tu personaje seguiría viniendo de tu disco, que es "
			+ "justo lo que estamos quitando).")

	_boton(botones, "Borrar de mi lista", func(): _borrar(_sel))


func _boton(caja: BoxContainer, txt: String, fn: Callable) -> void:
	var b := Button.new()
	b.text = txt
	b.disabled = _trabajando
	b.pressed.connect(fn)
	caja.add_child(b)


func _on_pestana(i: int) -> void:
	_pestana = i
	_sel = ""
	_pintar()


func _decir(txt: String, ok := true) -> void:
	MenuScaffold.decir(_piezas["aviso"], txt, ok)


# ============================================================
#  CREAR UN MUNDO
#  Dos pasos con la MISMA pantalla (creador_personaje.gd), que ya sabe pedir nombre, color e imagen
#  recortada: primero EL MUNDO (para reconocerlo en la lista) y luego TU PERSONAJE, que es el que va
#  a vivir dentro del mundo a tu nombre.
# ------------------------------------------------------------
func _crear_mundo() -> void:
	CreadorPersonaje.abrir(self, "NUEVO MUNDO COMPARTIDO",
		"Ponle nombre e imagen para reconocerlo en tu lista. Después crearás tu personaje.",
		"Siguiente: tu personaje", {"nombre": "", "color": AZUL},
		func(nombre: String, color: Color, _metalico: float, _tinte: float, png: PackedByteArray):
			_pedir_contrasena(nombre, color, png))


func _pedir_contrasena(nombre: String, color: Color, png: PackedByteArray) -> void:
	_dialogo("CONTRASEÑA DE «%s»" % nombre,
		"Se la pedirá a quien entre, y también a ti para abrir el mundo cuando esté cerrado. "
		+ "Sin ella, cualquiera que diera con el mundo podría abrirlo estando vosotros fuera.",
		[{"etiqueta": "Contraseña", "secreto": true}],
		func(valores: Array):
			await _crear_de_verdad(nombre, color, png, valores[0]))


func _crear_de_verdad(nombre: String, color: Color, png: PackedByteArray, pass_: String) -> void:
	var r: Dictionary = await Mundos.alta_propio(nombre, pass_, png, color)
	if not r.get("ok", false):
		_decir(String(r.get("mensaje", "No se pudo crear el mundo.")), false)
		return
	var clave: String = String(r["clave"])
	# Se abre YA (coger el cerrojo antes de crear personaje: si no se puede, mejor saberlo ahora).
	var a: Dictionary = await Mundos.abrir(clave, pass_)
	if not a.get("ok", false):
		_decir(String(a.get("mensaje", "No se pudo abrir el mundo recién creado.")), false)
		_pintar()
		return
	_sel = clave
	_pintar()
	CreadorPersonaje.abrir(self, "TU PERSONAJE EN «%s»" % nombre,
		"Este personaje vive DENTRO del mundo, a tu nombre: te lo encontrarás igual quien lo abra.",
		"Empezar la aventura", {"color": Color(0.45, 0.72, 1.0)},
		func(n: String, c: Color, m: float, tinte: float, imagen: PackedByteArray):
			Game.nueva_partida(n, c, m, imagen, tinte)
			if not Mundos.estrenar(clave):
				_decir("No se pudo guardar el mundo.", false)
				return
			get_tree().change_scene_to_file(PUEBLO))


# ============================================================
#  AÑADIR EL MUNDO DE OTRA PERSONA
#  Con su direccion (lo que funciona hoy) o con su codigo de mundo (lo que funcionara cuando el
#  almacen sea de verdad y reparta la direccion de quien lo tenga abierto).
# ------------------------------------------------------------
func _anadir_ajeno() -> void:
	_dialogo("AÑADIR EL MUNDO DE OTRA PERSONA",
		"Pídele su dirección (la de Hamachi o la que uséis) y la contraseña del mundo. El código de "
		+ "mundo es opcional: servirá para encontrarle sin saber su dirección.",
		[
			{"etiqueta": "Nombre para tu lista", "valor": ""},
			{"etiqueta": "Dirección (IP)", "valor": ""},
			{"etiqueta": "Contraseña", "secreto": true},
			{"etiqueta": "Código del mundo (opcional)", "valor": ""},
		],
		func(v: Array):
			var r: Dictionary = await Mundos.alta_ajeno(v[0], v[3], v[2], v[1])
			if not r.get("ok", false):
				_decir(String(r.get("mensaje", "No se pudo añadir.")), false)
				return
			_sel = String(r["clave"])
			_decir("Añadido «%s» a tu lista." % v[0])
			_pintar())


# ============================================================
#  ABRIR / CERRAR / BORRAR
# ------------------------------------------------------------
func _abrir(clave: String, pass_: String) -> void:
	if _trabajando:
		return
	_trabajando = true
	_decir("Abriendo el mundo...")
	var r: Dictionary = await Mundos.abrir(clave, pass_)
	_trabajando = false
	if not r.get("ok", false):
		_decir(String(r.get("mensaje", "No se pudo abrir.")), false)
		_pintar()
		return

	match String(r.get("resultado", "")):
		"unirse":
			# Lo tiene otro AHORA MISMO. Cuando exista el handshake con identidad, aqui se entra
			# directo con la direccion que ha publicado quien lo tiene.
			var quien: String = String(r.get("quien", "alguien"))
			_decir("Ese mundo lo tiene abierto %s ahora mismo: hay que unirse, y eso llega en el "
				% quien + "siguiente paso.", false)
		"nuevo":
			# Un mundo dado de alta al que todavia no se le ha creado personaje.
			_decir("Este mundo está vacío: crea tu personaje.")
			CreadorPersonaje.abrir(self, "TU PERSONAJE",
				"Este personaje vive dentro del mundo, a tu nombre.", "Empezar la aventura",
				{"color": Color(0.45, 0.72, 1.0)},
				func(n: String, c: Color, m: float, tinte: float, imagen: PackedByteArray):
					Game.nueva_partida(n, c, m, imagen, tinte)
					if Mundos.estrenar(clave):
						get_tree().change_scene_to_file(PUEBLO))
		_:
			if not Mundos.cargar(clave):
				_decir("No se pudo cargar ese mundo.", false)
				return
			# Se vuelve EXACTAMENTE donde se guardo, como en las ranuras de un jugador.
			var datos: SaveData = Mundos.datos_cabecera(clave)
			get_tree().change_scene_to_file(MAZMORRA if datos != null and datos.en_mazmorra else PUEBLO)


func _reintentar(clave: String) -> void:
	_trabajando = true
	var r: Dictionary = await Mundos.reintentar(clave)
	_trabajando = false
	_decir("Subida completada." if r.get("ok", false) \
		else String(r.get("mensaje", "Sigue sin subir.")), r.get("ok", false))
	_pintar()


# Borrar SOLO de tu lista, y a dos clics. Lo que hay en el almacen no se toca: si el mundo es de los
# dos, tirarlo de tu disco no puede borrarselo a tu compañero.
var _confirmar_borrado := ""

func _borrar(clave: String) -> void:
	if _confirmar_borrado != clave:
		_confirmar_borrado = clave
		_decir("Pulsa otra vez «Borrar de mi lista» para quitar este mundo de ESTE ordenador.", false)
		return
	_confirmar_borrado = ""
	Mundos.borrar(clave)
	_sel = ""
	_decir("Quitado de tu lista.")
	_pintar()


# ============================================================
#  Un dialogo de campos, por codigo (placeholder, como el resto de la interfaz)
# ------------------------------------------------------------
func _dialogo(titulo: String, explica: String, campos: Array, al_aceptar: Callable) -> void:
	var capa := PanelContainer.new()
	capa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(capa)

	var fondo := ColorRect.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.04, 0.04, 0.06, 0.96)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	capa.add_child(fondo)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa.add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	center.add_child(vb)

	var tit := Label.new()
	tit.text = titulo
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tit.add_theme_font_size_override("font_size", 20)
	tit.add_theme_color_override("font_color", AZUL)
	vb.add_child(tit)

	var ex := Label.new()
	ex.text = explica
	ex.custom_minimum_size = Vector2(420, 0)
	ex.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ex.add_theme_font_size_override("font_size", 12)
	ex.add_theme_color_override("font_color", MenuScaffold.GRIS)
	vb.add_child(ex)

	var entradas: Array[LineEdit] = []
	for c in campos:
		var l := Label.new()
		l.text = String(c.get("etiqueta", ""))
		l.add_theme_font_size_override("font_size", 12)
		vb.add_child(l)
		var le := LineEdit.new()
		le.text = String(c.get("valor", ""))
		le.secret = bool(c.get("secreto", false))
		le.custom_minimum_size = Vector2(420, 0)
		vb.add_child(le)
		entradas.append(le)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(fila)

	var aceptar := Button.new()
	aceptar.text = "Aceptar"
	aceptar.pressed.connect(func():
		var valores: Array = []
		for le in entradas:
			valores.append(le.text.strip_edges())
		capa.queue_free()
		al_aceptar.call(valores))
	fila.add_child(aceptar)

	var cancelar := Button.new()
	cancelar.text = "Cancelar"
	cancelar.pressed.connect(func(): capa.queue_free())
	fila.add_child(cancelar)

	if not entradas.is_empty():
		entradas[0].grab_focus()
