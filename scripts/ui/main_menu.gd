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
# EL MISMO panel de ajustes que el menu de pausa, no una copia: el volumen y el modo de pantalla se
# tienen que poder tocar ANTES de entrar a jugar (que es donde se tocan en cualquier juego), y dos
# pantallas distintas para lo mismo acaban contestando distinto.
const AJUSTES := preload("res://scripts/ui/settings_menu.gd")

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
# Los AJUSTES, montados de entrada y escondidos (como en el menu de pausa): la capa es el telon que
# tapa la lista de ranuras, y dentro va el panel de verdad.
var _ajustes_capa: Control = null
var _ajustes: Control = null

# Cuantas partidas se ven sin hacer scroll (sin tope desde la fase 3 de la BD: las demas, bajando).
const FILAS_A_LA_VISTA := 3
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

	# AJUSTES desde el TITULO, no solo con ESC dentro de la partida: el volumen y el modo de pantalla
	# (ventana / sin bordes / completa) son lo primero que se toca al abrir un juego, y hasta ahora
	# para llegar a ellos habia que cargar una partida.
	var ajustes := Button.new()
	ajustes.custom_minimum_size = Vector2(ANCHO_TOTAL, 52.0)
	ajustes.text = "Ajustes"
	ajustes.pressed.connect(_abrir_ajustes)
	vb.add_child(ajustes)

	var salir := Button.new()
	salir.custom_minimum_size = Vector2(ANCHO_TOTAL, 52.0)
	salir.text = "Salir del juego"
	salir.pressed.connect(get_tree().quit)
	vb.add_child(salir)

	_montar_ajustes()

	# En el menu principal NO puede quedar ningun mundo compartido abierto. Si llegamos aqui con uno
	# (algun camino anomalo que no paso por "guardar y salir"), hay que soltarlo: si no, el siguiente
	# guardado de una partida de UN JUGADOR se escribiria dentro del fichero del mundo y su ranura no
	# se guardaria nunca. Ver Mundos.abandonar().
	var colgado: String = Mundos.abandonar()
	if colgado != "":
		_aviso.text = "El mundo compartido se cerró sin guardar. Sigue reservado a tu nombre unos minutos."

	# La primera vez con la BASE DE DATOS, las partidas viejas se pasan a ella (ver Perfil): con un
	# baul grande son unos segundos, asi que con la capa de Cargando delante y no con el menu congelado.
	if Perfil.hay_por_migrar():
		await Cargando.mostrar("Actualizando tus partidas...
(solo esta vez)")
		Perfil.migrar_todas()
		Cargando.ocultar()

	_pintar()
	# Tus partidas en la nube (las de otros PCs, y si a alguna le queda algo por subir). Sin red no pasa
	# nada: la lista ya esta pintada con lo de este PC.
	if await Perfil.mirar_nube() and is_inside_tree():
		_pintar()
	elif Perfil.sin_conexion and _aviso.text == "":
		_aviso.text = "Sin conexión: juegas con lo de este PC y se subirá luego."


# ============================================================
#  AJUSTES
# ============================================================

# Se monta UNA vez y se esconde, igual que en el menu de pausa: asi no hay que preguntarse si existe
# cada vez que se pulsa el boton. El telon lleva su propio fondo oscuro y se come el raton: sin el,
# los botones de las ranuras seguian pulsandose por debajo del panel.
func _montar_ajustes() -> void:
	_ajustes_capa = Control.new()
	_ajustes_capa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ajustes_capa.visible = false
	add_child(_ajustes_capa)

	var telon := ColorRect.new()
	telon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	telon.color = Color(0.0, 0.0, 0.0, 0.75)
	telon.mouse_filter = Control.MOUSE_FILTER_STOP
	_ajustes_capa.add_child(telon)

	_ajustes = AJUSTES.new()
	_ajustes.cerrado.connect(_cerrar_ajustes)
	_ajustes_capa.add_child(_ajustes)


func _abrir_ajustes() -> void:
	_ajustes_capa.visible = true
	_ajustes.abrir()


func _cerrar_ajustes() -> void:
	_ajustes_capa.visible = false


# ESC cierra los ajustes (no hay nada mas de lo que salir en el titulo). Va por _unhandled_input,
# asi que si algun dia el panel se come la tecla, aqui ya no llega y no se cierran dos veces.
func _unhandled_input(event: InputEvent) -> void:
	if _ajustes_capa != null and _ajustes_capa.visible and event.is_action_pressed(&"cancelar"):
		_ajustes.cerrar()
		get_viewport().set_input_as_handled()


# Una fila por partida: [la partida] [Borrar], dentro de un scroll (se ven FILAS_A_LA_VISTA). Arriba,
# "Nueva partida"; abajo, las que solo estan en la NUBE (de otro PC): tocarlas las trae a este. Ya NO hay
# "Editar" (el nombre y el aspecto se cambian desde el Hogar) ni "Nueva" sobre una partida: sin tope de
# partidas, una nueva siempre va a un hueco nuevo.
func _pintar() -> void:
	MenuScaffold.vaciar(_lista)

	var nueva := Button.new()
	nueva.custom_minimum_size = Vector2(ANCHO_TOTAL, 52.0)
	nueva.text = "+  Nueva partida"
	nueva.add_theme_color_override("font_color", AMBAR)
	nueva.pressed.connect(_nueva)
	_lista.add_child(nueva)

	var ranuras: Array = Perfil.ranuras()
	var nube: Array = Perfil.solo_en_nube()
	if ranuras.is_empty() and nube.is_empty():
		return
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var n_filas: int = mini(ranuras.size() + nube.size(), FILAS_A_LA_VISTA)
	sc.custom_minimum_size = Vector2(ANCHO_TOTAL + 14.0, n_filas * (ALTO_FILA + 6.0))
	_lista.add_child(sc)
	var filas := VBoxContainer.new()
	filas.add_theme_constant_override("separation", 6)
	sc.add_child(filas)

	var ultima: int = Perfil.ultima_ranura()
	for slot in ranuras:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", int(SEP_FILA))
		filas.add_child(fila)

		var info: Dictionary = Perfil.inspeccionar_ligera(slot)
		var datos: SaveData = info["datos"] as SaveData
		var estado: int = int(info["estado"])

		if estado == Perfil.VACIA:
			continue

		if estado != Perfil.OK:
			# Partida que este build no puede abrir. Lo que NO se puede hacer aqui es tratarla como un
			# hueco: hay una partida dentro. Se dice lo que pasa y se deja mirando.
			var rota: Button = _boton_ranura("Partida %d" % slot,
				[Perfil.motivo_texto(info)], ROJO, ROJO)
			rota.disabled = true
			fila.add_child(rota)
			# El unico boton es Borrar, y con confirmacion a dos clics: sin cabecera no hay nombre
			# que pedir, pero tampoco se borra una partida ajena de un toque.
			fila.add_child(_boton_borrar(_borrar_a_ciegas.bind(slot)))
			continue

		# La ficha va en DOS lineas: arriba lo que identifica la partida, y debajo en gris el resto.
		var titulo: String = "%s  ·  Nv.%d" % [datos.nombre, datos.cab_nivel]
		if slot == ultima:
			titulo += "   ◄"   # la mas reciente
		if Perfil.sin_subir(slot):
			titulo += "   ↑"   # le queda algo por subir a la nube (sin conexion, o a medias)
		var jugar: Button = _boton_ranura(titulo,
			["%s  ·  %d monedas" % [datos.cab_lugar, datos.cab_dinero], datos.fecha], AMBAR)
		jugar.pressed.connect(_cargar.bind(slot))
		fila.add_child(jugar)
		fila.add_child(_boton_borrar(_borrar.bind(slot)))

	# Las que estan en tu cuenta de la nube y no en este PC (jugadas en otro).
	for e in nube:
		var m: Dictionary = e["meta"]
		var b: Button = _boton_ranura("%s  ·  Nv.%d   (en la nube)" % [String(m.get("nombre", "Partida")),
			int(m.get("cab_nivel", 0))], ["Tócala para traerla a este PC  ·  %d monedas" % int(m.get("cab_dinero", 0)),
			String(m.get("fecha", ""))], Color(0.55, 0.75, 0.98))
		b.pressed.connect(_traer.bind(String(e["id"])))
		filas.add_child(b)


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
	await Cargando.mostrar("Cargando partida...")
	# Primero, al dia con la nube (si se jugo en otro PC). Sin red se carga lo de aqui.
	var prep: Dictionary = await Perfil.preparar_carga(slot)
	if bool(prep.get("conflicto", false)):
		Cargando.ocultar()
		_preguntar_conflicto(slot, prep)
		return
	if not prep.get("ok", false):
		Cargando.ocultar()
		_aviso.text = "No se pudo traer lo último de la nube. Vuelve a probar."
		return
	if not Perfil.cargar(slot):
		Cargando.ocultar()
		_aviso.text = "Esa partida no se puede cargar."
		return
	# Vuelves EXACTAMENTE donde guardaste: si fue dentro de la mazmorra, a tu piso y tu sitio
	# (el DungeonFloor lee Game.pos_cargada y restaura los bichos de Game.memoria_pisos).
	#
	# SALVO que el piso que pisabas se rehaga con este build (ver Game._rehacer_pisos_de_otro_trazado):
	# entonces sales al pueblo. Va por la bandera de Game y no releyendo la cabecera porque el que
	# decide es quien acaba de importar la partida, y esa cabecera puede venir de la cache de Godot.
	var datos: SaveData = Perfil.cabecera_ligera(slot)
	var al_pueblo: bool = Game.forzar_pueblo_al_cargar or not datos.en_mazmorra
	Game.forzar_pueblo_al_cargar = false   # de un solo uso
	await Cargando.cambiar_escena(get_tree(), PUEBLO if al_pueblo else MAZMORRA, "Cargando partida...")


# Una partida NUEVA va siempre a un hueco nuevo (no hay tope): nunca encima de otra.
func _nueva() -> void:
	_crear_personaje(Perfil.ranura_libre())


# Traer a este PC una partida que solo esta en la nube, y jugarla.
func _traer(pid: String) -> void:
	await Cargando.mostrar("Trayendo tu partida de la nube...")
	var slot: int = await Perfil.bajar_de_nube(pid)
	if slot <= 0:
		Cargando.ocultar()
		_aviso.text = "No se pudo traer la partida de la nube. Mira tu conexión."
		return
	_pintar()
	_cargar(slot)


# ============================================================
#  CONFLICTO: la partida cambio AQUI y EN LA NUBE (se jugo en dos PCs sin subir). Se enseñan las dos y
#  eliges; la otra no se pierde (la de la nube va a su historial, la de aqui a respaldos/conflictos).
# ------------------------------------------------------------
func _preguntar_conflicto(slot: int, prep: Dictionary) -> void:
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
	tit.text = "ESTA PARTIDA CAMBIÓ EN DOS SITIOS"
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tit.add_theme_font_size_override("font_size", 24)
	tit.add_theme_color_override("font_color", AMBAR)
	vb.add_child(tit)
	var expl := Label.new()
	expl.text = "Se jugó en este PC y en otro sin llegar a subirse. ¿Con cuál sigues?
La otra no se pierde: queda guardada aparte."
	expl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(expl)

	var resumen := func(m: Dictionary) -> Array:
		return ["%s  ·  Nv.%d  ·  %d monedas" % [String(m.get("nombre", "?")), int(m.get("cab_nivel", 0)),
			int(m.get("cab_dinero", 0))], "%s  ·  %s" % [String(m.get("cab_lugar", "")), String(m.get("fecha", ""))]]
	var aqui: Button = _boton_ranura("La de ESTE PC", resumen.call(prep.get("aqui", {})), AMBAR)
	aqui.custom_minimum_size.x = ANCHO_TOTAL
	vb.add_child(aqui)
	var nube: Button = _boton_ranura("La de la NUBE", resumen.call(prep.get("nube", {})), Color(0.55, 0.75, 0.98))
	nube.custom_minimum_size.x = ANCHO_TOTAL
	vb.add_child(nube)
	var cancelar := Button.new()
	cancelar.text = "Ahora no"
	cancelar.pressed.connect(capa.queue_free)
	vb.add_child(cancelar)

	var elegir := func(gana: String):
		capa.queue_free()
		await Cargando.mostrar("Poniendo tu partida al día...")
		if await Perfil.resolver_conflicto(slot, gana, int(prep.get("rev_nube", 0))):
			_cargar(slot)
		else:
			Cargando.ocultar()
			_aviso.text = "No se pudo hablar con la nube. Vuelve a probar."
	aqui.pressed.connect(elegir.bind("aqui"))
	nube.pressed.connect(elegir.bind("nube"))


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
		"NUEVO PERSONAJE",
		"",
		"Empezar la aventura",
		{"color": COLOR_INICIAL},
		func(nombre: String, asp: Dictionary):
			_empezar(slot, nombre, asp))


# Color de salida de la creacion (uno cualquiera, ya lo cambiara).
const COLOR_INICIAL := Color(0.45, 0.72, 1.0)


func _empezar(slot: int, nombre: String, asp: Dictionary) -> void:
	# el nombre vacio lo resuelve Game (NOMBRE_POR_DEFECTO)
	await Cargando.mostrar("Creando la partida...")
	Game.nueva_partida(nombre, asp)
	Perfil.ranura_actual = slot
	Perfil.guardar(slot)   # la ranura queda ocupada desde el minuto uno, ya con nombre y aspecto
	await Cargando.cambiar_escena(get_tree(), PUEBLO, "Creando la partida...")


# ============================================================
#  BORRAR una ranura: hay que ESCRIBIR el nombre del personaje
#  Antes se borraba con un solo clic, sin preguntar nada: el progreso de una partida entera se
#  iba por un dedazo. Se pide el NOMBRE y no un "¿seguro? [Sí]" a proposito: un "sí" se pulsa
#  por inercia, pero para teclear el nombre hay que leer cual estas borrando.
# ------------------------------------------------------------
func _borrar(slot: int) -> void:
	var datos: SaveData = Perfil.cabecera_ligera(slot)
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
	tit.text = "BORRAR LA PARTIDA"
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
		_aviso.text = "Esa partida no la puede leer este build. Pulsa otra vez «Borrar» para tirarla."
		return
	_confirmar_borrado = 0
	Perfil.borrar(slot)
	_aviso.text = "Partida borrada."
	_pintar()


func _hacer_borrado(slot: int, capa: Control) -> void:
	Perfil.borrar(slot)
	capa.queue_free()
	_aviso.text = "Partida borrada."
	_pintar()
