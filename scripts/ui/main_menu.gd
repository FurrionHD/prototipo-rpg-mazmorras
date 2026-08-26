# ============================================================
#  main_menu.gd
#  Pantalla de INICIO: la primera que ve el jugador. Lista las ranuras de guardado con su
#  cabecera (nivel, donde estabas, dinero, fecha) y deja Continuar, Cargar, empezar una
#  partida NUEVA (cada una con su propio mundo) o borrar una ranura.
#
#  Existe para que un tester pueda empezar de cero SIN ir a borrar ficheros a mano.
#  Interfaz placeholder por codigo; el arte va al final.
# ============================================================

extends Control

const PUEBLO := "res://scenes/levels/town.tscn"
const MAZMORRA := "res://scenes/levels/main.tscn"
const MULTIJUGADOR := "res://scenes/ui/multi_menu.tscn"

const AMBAR := Color(0.95, 0.72, 0.36)
const ROJO := Color(0.9, 0.5, 0.5)
const GRIS := Color(0.62, 0.64, 0.70)

# Medidas de una fila de ranura. Antes eran 520x31 con tres botones al lado, o sea una tira de ~764
# de ancho por 31 de alto: con un pulgar eso no se acierta. Ahora la fila es mas ESTRECHA y mucho mas
# ALTA, y la ficha de la partida se reparte en dos lineas para que quepa.
const ANCHO_RANURA := 460.0
const ANCHO_BORRAR := 96.0
const ALTO_FILA := 76.0
const SEP_FILA := 8.0
# Lo que mide una fila entera. Lo usan multijugador y salir para que la columna sea un bloque y no
# tres anchos distintos.
const ANCHO_TOTAL := ANCHO_RANURA + SEP_FILA + ANCHO_BORRAR

var _lista: VBoxContainer = null
var _aviso: Label = null

# Ranura pendiente de confirmar sobrescritura (0 = nada pendiente).
var _confirmar_nueva: int = 0
# Ranura pendiente de confirmar borrado A CIEGAS (una que no se puede leer; ver _borrar_a_ciegas).
var _confirmar_borrado: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var fondo := ColorRect.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.06, 0.06, 0.08)
	add_child(fondo)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Numero de version, discreto en la esquina inferior derecha (sale de Game.VERSION, no
	# escrito a mano, para que no se desincronice con el resto del juego).
	var ver := Label.new()
	ver.text = "v%s" % Game.VERSION
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -110.0
	ver.offset_top = -28.0
	ver.offset_right = -10.0
	ver.offset_bottom = -8.0
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.add_theme_font_size_override("font_size", 13)
	ver.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	ver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ver)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	center.add_child(vb)

	var tit := Label.new()
	tit.text = "DUNGEON ORATORIA"
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tit.add_theme_font_size_override("font_size", 34)
	tit.add_theme_color_override("font_color", AMBAR)
	vb.add_child(tit)

	_aviso = Label.new()
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.add_theme_font_size_override("font_size", 13)
	_aviso.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	vb.add_child(_aviso)

	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 6)
	vb.add_child(_lista)

	# MULTIJUGADOR: otra coleccion de partidas, con sus propios mundos. Las tres ranuras de arriba
	# son de UN JUGADOR y se quedan como estan (con su LAN de siempre desde el menu de pausa); un
	# MUNDO COMPARTIDO lleva dentro a todos los que juegan en el, cada personaje a nombre de su
	# jugador, y lo puede abrir cualquiera de ellos (uno a la vez). Ver multi_menu.gd.
	var multi := Button.new()
	multi.custom_minimum_size = Vector2(ANCHO_TOTAL, 52.0)
	multi.text = "MULTIJUGADOR  ·  mundos compartidos"
	multi.add_theme_color_override("font_color", Color(0.55, 0.75, 0.98))
	multi.pressed.connect(func(): get_tree().change_scene_to_file(MULTIJUGADOR))
	vb.add_child(multi)

	var salir := Button.new()
	salir.custom_minimum_size = Vector2(ANCHO_TOTAL, 52.0)
	salir.text = "Salir del juego"
	salir.pressed.connect(get_tree().quit)
	vb.add_child(salir)

	# En el menu principal NO puede quedar ningun mundo compartido abierto. Si llegamos aqui con uno
	# (algun camino anomalo que no paso por "guardar y salir"), hay que soltarlo: si no, el siguiente
	# guardado de una partida de UN JUGADOR se escribiria dentro del fichero del mundo y su ranura no
	# se guardaria nunca. Ver Mundos.abandonar().
	var colgado: String = Mundos.abandonar()
	if colgado != "":
		_aviso.text = "El mundo compartido se cerró sin guardar. Sigue reservado a tu nombre unos minutos."

	_pintar()


# Una fila por ranura: [la partida] [Borrar]. Ya NO hay "Editar" (el nombre y el aspecto se cambian
# desde el Hogar, y alli ademas para cualquiera del grupo) ni "Nueva" sobre una ranura ocupada: para
# empezar de cero se borra primero, que ademas cuesta mucho mas hacerlo sin querer.
func _pintar() -> void:
	MenuScaffold.vaciar(_lista)

	var ultima: int = Perfil.ultima_ranura()
	for slot in range(1, Perfil.RANURAS + 1):
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", int(SEP_FILA))
		_lista.add_child(fila)

		var info: Dictionary = Perfil.inspeccionar(slot)
		var datos: SaveData = info["datos"] as SaveData
		var estado: int = int(info["estado"])

		if estado == Perfil.VACIA:
			var vacia: Button = _boton_ranura("Ranura %d — vacía" % slot, ["Nueva partida"], GRIS)
			vacia.pressed.connect(_nueva.bind(slot))
			fila.add_child(vacia)
			continue

		if estado != Perfil.OK:
			# Ranura OCUPADA que este build no puede abrir. Lo que NO se puede hacer aqui es
			# ofrecer "Nueva partida": hay una partida dentro y el jugador la perderia por un clic
			# creyendo que la ranura estaba libre. Se dice lo que pasa y se deja mirando.
			var rota: Button = _boton_ranura("Ranura %d" % slot,
				[Perfil.motivo_texto(info)], ROJO, ROJO)
			rota.disabled = true
			fila.add_child(rota)
			# El unico boton es Borrar, y con confirmacion a dos clics: sin cabecera no hay nombre
			# que pedir, pero tampoco se borra una partida ajena de un toque.
			fila.add_child(_boton_borrar(_borrar_a_ciegas.bind(slot)))
			continue

		# Ranura con partida. La ficha va en DOS lineas porque en una sola no cabe con la fila ya
		# estrecha: arriba lo que identifica la partida, y debajo en gris el resto.
		var titulo: String = "%s  ·  Nv.%d" % [datos.nombre, datos.cab_nivel]
		if slot == ultima:
			titulo += "   ◄"   # la mas reciente. La flecha sola basta: el texto entero ya no cabe.
		var jugar: Button = _boton_ranura(titulo,
			["%s  ·  %d monedas" % [datos.cab_lugar, datos.cab_dinero], datos.fecha], AMBAR)
		jugar.pressed.connect(_cargar.bind(slot))
		fila.add_child(jugar)
		fila.add_child(_boton_borrar(_borrar.bind(slot)))


# El boton alto de una ranura. Va SIN texto y con las lineas dentro: un Button no sabe pintar varias
# lineas con tamaños y colores distintos, pero si dejarle dentro un VBox de Labels que no coman el
# raton. Asi se conservan el pulsado, el hover y el disabled que usa la ranura ilegible.
func _boton_ranura(titulo: String, lineas: Array, color_titulo: Color,
		color_lineas: Color = GRIS) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(ANCHO_RANURA, ALTO_FILA)
	if color_titulo == ROJO:
		b.add_theme_color_override("font_disabled_color", ROJO)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 14
	col.offset_right = -14
	col.add_theme_constant_override("separation", 1)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)

	var t := Label.new()
	t.text = titulo
	t.add_theme_font_size_override("font_size", 17)
	t.add_theme_color_override("font_color", color_titulo)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(t)

	for linea in lineas:
		var l := Label.new()
		l.text = str(linea)
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", color_lineas)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(l)
	return b


func _boton_borrar(al_pulsar: Callable) -> Button:
	var b := Button.new()
	b.text = "Borrar"
	b.custom_minimum_size = Vector2(ANCHO_BORRAR, ALTO_FILA)
	b.pressed.connect(al_pulsar)
	return b


func _cargar(slot: int) -> void:
	if not Perfil.cargar(slot):
		_aviso.text = "Esa partida no se puede cargar."
		return
	# Vuelves EXACTAMENTE donde guardaste: si fue dentro de la mazmorra, a tu piso y tu sitio
	# (el DungeonFloor lee Game.pos_cargada y restaura los bichos de Game.memoria_pisos).
	var datos: SaveData = Perfil.cabecera(slot)
	get_tree().change_scene_to_file(MAZMORRA if datos.en_mazmorra else PUEBLO)


func _nueva(slot: int) -> void:
	# Si la ranura tiene una partida, se pide confirmacion: borrar el progreso de alguien por
	# un clic de mas seria imperdonable.
	if Perfil.existe(slot) and _confirmar_nueva != slot:
		_confirmar_nueva = slot
		_aviso.text = "La ranura %d YA tiene una partida. Pulsa otra vez «Nueva» para sobrescribirla." % slot
		return
	_confirmar_nueva = 0
	_crear_personaje(slot)


# ============================================================
#  PERSONAJE NUEVO: nombre + aspecto, y al aceptar arranca una partida de cero.
#  El aspecto entero viaja en UN dict (ver PersonajeData.aspecto_completo) y va al SaveData de ESA
#  ranura (no al perfil): cada partida es un personaje distinto.
#    - PIEZAS:  el pelo y la ropa, cada una con su modelo y su color. De ahi sale tu color.
#    - IMAGEN:  opcional, tuya, del disco. La encuadras en un CUADRADO (zoom + arrastre) y se
#      guarda ya recortada DENTRO de la partida (ver Game.png_cuadrado).
#    - TINTE y METAL: los dos son de ESA imagen, y de nada mas (ver creador_personaje.gd).
#
#  Esta pantalla tenia tambien un modo EDITAR, que llegaba desde un boton "Editar" de cada fila.
#  Ya no: cambiar el nombre y la cara se hace desde el HOGAR, que ademas deja hacerlo con
#  cualquiera del grupo y no solo con el lider (ver home_menu._editar_aspecto).
#  Interfaz placeholder por codigo, como el resto; el arte va al final.
# ------------------------------------------------------------
func _crear_personaje(slot: int) -> void:
	CreadorPersonaje.abrir(self,
		"NUEVO PERSONAJE  ·  ranura %d" % slot,
		"",
		"Empezar la aventura",
		{"color": COLOR_INICIAL},
		func(nombre: String, asp: Dictionary):
			_empezar(slot, nombre, asp))


# Color de salida de la creacion (uno cualquiera, ya lo cambiara).
const COLOR_INICIAL := Color(0.45, 0.72, 1.0)


func _empezar(slot: int, nombre: String, asp: Dictionary) -> void:
	# el nombre vacio lo resuelve Game (NOMBRE_POR_DEFECTO)
	Game.nueva_partida(nombre, asp)
	Perfil.ranura_actual = slot
	Perfil.guardar(slot)   # la ranura queda ocupada desde el minuto uno, ya con nombre y aspecto
	get_tree().change_scene_to_file(PUEBLO)


# ============================================================
#  BORRAR una ranura: hay que ESCRIBIR el nombre del personaje
#  Antes se borraba con un solo clic, sin preguntar nada: el progreso de una partida entera se
#  iba por un dedazo. Se pide el NOMBRE y no un "¿seguro? [Sí]" a proposito: un "sí" se pulsa
#  por inercia, pero para teclear el nombre hay que leer cual estas borrando.
# ------------------------------------------------------------
func _borrar(slot: int) -> void:
	var datos: SaveData = Perfil.cabecera(slot)
	if datos == null:
		_borrar_a_ciegas(slot)
		return

	var capa := PanelContainer.new()
	capa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(capa)

	var fondo := ColorRect.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.04, 0.04, 0.06, 0.96)
	capa.add_child(fondo)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa.add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	center.add_child(vb)

	var tit := Label.new()
	tit.text = "BORRAR LA RANURA %d" % slot
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tit.add_theme_font_size_override("font_size", 24)
	tit.add_theme_color_override("font_color", ROJO)
	vb.add_child(tit)

	# Que veas lo que te llevas por delante (nivel, dinero, donde estabas), no solo el numero.
	var resumen := Label.new()
	resumen.text = datos.resumen()
	resumen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(resumen)

	var av := Label.new()
	av.text = "Esto no tiene vuelta atrás."
	av.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	av.add_theme_color_override("font_color", ROJO)
	vb.add_child(av)

	var pide := Label.new()
	pide.text = "Escribe «%s» para confirmar:" % datos.nombre
	pide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(pide)

	var campo := LineEdit.new()
	campo.custom_minimum_size = Vector2(320, 0)
	vb.add_child(campo)

	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 8)
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(botones)

	var borrar := Button.new()
	borrar.text = "Borrar para siempre"
	borrar.disabled = true   # hasta que el nombre coincida no se puede ni pulsar
	botones.add_child(borrar)

	var cancelar := Button.new()
	cancelar.text = "Cancelar"
	cancelar.pressed.connect(func(): capa.queue_free())
	botones.add_child(cancelar)

	var nombre_ok := func(t: String) -> bool:
		return t.strip_edges().to_lower() == datos.nombre.strip_edges().to_lower()

	campo.text_changed.connect(func(t: String): borrar.disabled = not nombre_ok.call(t))
	# Enter tambien vale, pero SOLO si el nombre esta bien: si no, no hace nada.
	campo.text_submitted.connect(func(t: String):
		if nombre_ok.call(t):
			_hacer_borrado(slot, capa))
	borrar.pressed.connect(func(): _hacer_borrado(slot, capa))

	campo.grab_focus()


# Borrar una ranura de la que NO se puede leer la cabecera (de otra version, o dañada). No hay
# nombre que pedir, asi que la proteccion es a dos clics: el primero avisa de que hay una partida
# dentro y de que este build no sabe lo que se lleva por delante.
func _borrar_a_ciegas(slot: int) -> void:
	if _confirmar_borrado != slot:
		_confirmar_borrado = slot
		_aviso.text = "La ranura %d TIENE una partida que este build no puede leer. Pulsa otra vez «Borrar» para tirarla." % slot
		return
	_confirmar_borrado = 0
	Perfil.borrar(slot)
	_aviso.text = "Ranura %d borrada." % slot
	_confirmar_nueva = 0
	_pintar()


func _hacer_borrado(slot: int, capa: Control) -> void:
	Perfil.borrar(slot)
	capa.queue_free()
	_aviso.text = "Ranura %d borrada." % slot
	_confirmar_nueva = 0
	_pintar()
