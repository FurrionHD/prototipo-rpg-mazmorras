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
const YO := 2

# La tarjeta de un mundo. Alta y en dos lineas como las ranuras del menu de inicio: esto es un
# selector de partidas y con 34 px de alto no se acierta con el pulgar.
const ANCHO_MUNDO := 300.0
const ALTO_MUNDO := 62.0

# Como se llama un mundo al que no le pones nombre.
const MUNDO_POR_DEFECTO := "Mundo nuevo"

var _capa: CanvasLayer = null
# Capa para lo que se abre ENCIMA (el creador de personaje, los dialogos). Tiene que ser otra
# CanvasLayer con layer mas alto: el esqueleto del menu vive dentro de una CanvasLayer, y una
# CanvasLayer se dibuja SIEMPRE por encima de los hijos normales del Control. Colgar el creador de
# `self` lo deja detras del fondo opaco del menu: existe, recibe todo, y no se ve nada.
var _encima: CanvasLayer = null
var _piezas: Dictionary = {}
var _pestana: int = MIOS
var _sel: String = ""          # clave del mundo seleccionado
var _trabajando := false       # una operacion de red/disco en marcha: no dejar pulsar dos veces


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_capa = CanvasLayer.new()
	add_child(_capa)
	_encima = CanvasLayer.new()
	_encima.layer = _capa.layer + 1
	add_child(_encima)
	# Sin lateral: aqui se elige PARTIDA, no se hojea un catalogo, asi que la columna izquierda se
	# quedaba vacia comiendose 230 px. El titulo y el ✕ se van a una barra arriba (ver
	# MenuScaffold.construir) y las pestañas siguen en la cabecera, donde ya estaban.
	_piezas = MenuScaffold.construir(_capa, "MULTIJUGADOR", "Mundos compartidos", _volver,
		false, false)
	# LA PANTALLA A MEDIAS. El scaffold le da a la lista un ancho FIJO (ANCHO_LISTA, pensado para
	# una cuadricula de items de 150), y aqui dentro no hay items: hay TARJETAS DE MUNDO con el
	# nombre, el personaje, el piso y el dinero. En 330 px eso se cortaba a media palabra.
	# Las dos columnas pasan a repartirse el sitio al 50%, que es justo lo que pedia esta pantalla:
	# la mitad para elegir mundo y la mitad para su ficha.
	var lista_scroll: ScrollContainer = _piezas["lista_scroll"]
	lista_scroll.custom_minimum_size = Vector2(0, 0)
	lista_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(_piezas["root"] as Control).visible = true
	Mundos.aviso.connect(func(t: String): MenuScaffold.decir(_piezas["aviso"], t, true))
	Nube.cerrojo_perdido.connect(func(m: String): MenuScaffold.decir(_piezas["aviso"], m, false))
	# Unirse a un mundo pasa por aqui: la red avisa y la pantalla responde. Abrir el creador de
	# personaje NO es cosa de la capa de red, y menos dentro de un RPC.
	Net.estado_cambiado.connect(func(t: String): MenuScaffold.decir(_piezas["aviso"], t, true))
	Net.pedir_personaje.connect(_crear_mi_personaje_en_mundo_ajeno)
	Net.entrada_lista.connect(_entrar_al_mundo_ajeno)
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
	MenuScaffold.vaciar(header)
	MenuScaffold.vaciar(lista)

	MenuScaffold.pestanas(header, ["MIS MUNDOS", "DE OTRAS PERSONAS", "TÚ Y TU CONEXIÓN"],
		_pestana, _on_pestana, 150)

	# Quien soy: hace falta que se vea, porque es la llave de tus personajes en todos los mundos.
	var quien := Label.new()
	quien.text = "Eres «%s»  ·  id %s" % [Identidad.nombre, Identidad.id]
	quien.add_theme_font_size_override("font_size", 11)
	quien.add_theme_color_override("font_color", MenuScaffold.GRIS)
	header.add_child(quien)

	if _pestana == YO:
		_pintar_direcciones(lista)
		_pintar_yo()
		return

	var mundos: Array = Mundos.catalogo().filter(func(e):
		return bool(e.get("mio", false)) == (_pestana == MIOS))

	if mundos.is_empty():
		MenuScaffold.nota(lista, "Todavía no hay nada aquí." if _pestana == MIOS \
			else "Aquí aparecerán los mundos de tus compañeros cuando los añadas.")
	for e in mundos:
		_fila_mundo(lista, e)

	var nuevo := Button.new()
	nuevo.custom_minimum_size = Vector2(0, 48)
	nuevo.text = "+ Crear un mundo nuevo" if _pestana == MIOS else "+ Añadir el mundo de otra persona"
	nuevo.pressed.connect(_crear_mundo if _pestana == MIOS else _anadir_ajeno)
	lista.add_child(nuevo)

	_pintar_detalle()


func _fila_mundo(lista: VBoxContainer, e: Dictionary) -> void:
	var clave: String = String(e["clave"])
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_child(caja)

	# El ICONO del mundo (el jugador elige una imagen suya, como con los personajes): es lo que hace
	# que dos mundos se distingan de un vistazo.
	var icono := TextureRect.new()
	icono.custom_minimum_size = Vector2(ALTO_MUNDO, ALTO_MUNDO)
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var tex: Texture2D = _textura(e.get("icono", PackedByteArray()))
	if tex != null:
		icono.texture = tex
	else:
		var col := ColorRect.new()
		col.custom_minimum_size = Vector2(ALTO_MUNDO, ALTO_MUNDO)
		col.color = e.get("color", AZUL)
		caja.add_child(col)
	if tex != null:
		caja.add_child(icono)

	# TARJETA ALTA de dos lineas, como las ranuras del menu de inicio: arriba el nombre del mundo,
	# debajo en gris de quien es la partida que hay dentro. El boton va sin texto y con las lineas
	# de hijos, que es la unica forma de tener dos tamaños de letra dentro de un Button.
	var b := Button.new()
	# El ancho es un MINIMO: la tarjeta se estira con su media pantalla, que es lo que hace que el
	# "· 22519 monedas" del final quepa en vez de cortarse.
	b.custom_minimum_size = Vector2(ANCHO_MUNDO, ALTO_MUNDO)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.toggle_mode = true
	b.button_pressed = (clave == _sel)
	b.pressed.connect(func():
		_sel = clave
		_pintar())
	caja.add_child(b)

	var col2 := VBoxContainer.new()
	col2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col2.offset_left = 12
	col2.offset_right = -12
	col2.alignment = BoxContainer.ALIGNMENT_CENTER
	col2.add_theme_constant_override("separation", 1)
	col2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col2)

	var nombre := String(e.get("nombre", "?"))
	if int(e.get("estado", SaveIO.VACIA)) not in [SaveIO.VACIA, SaveIO.OK]:
		nombre += "  ⚠"
	if bool(e.get("pendiente", false)):
		nombre += "  ⬆"
	var l1 := Label.new()
	l1.text = nombre
	l1.add_theme_font_size_override("font_size", 16)
	l1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col2.add_child(l1)

	var l2 := Label.new()
	l2.text = String(e.get("cab", "sin abrir todavía"))
	l2.add_theme_font_size_override("font_size", 11)
	l2.add_theme_color_override("font_color", MenuScaffold.GRIS)
	l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col2.add_child(l2)


func _textura(bytes) -> Texture2D:
	if not (bytes is PackedByteArray) or (bytes as PackedByteArray).is_empty():
		return null
	var img := Image.new()
	if img.load_png_from_buffer(bytes as PackedByteArray) != OK:
		return null
	return ImageTexture.create_from_image(img)


# ============================================================
#  TÚ Y TU CONEXIÓN
#  Aqui vive lo que es de la PERSONA y no de ninguna partida: como te llamas para los demas, tu id
#  (la llave de tus personajes en todos los mundos) y CUAL DE TUS DIRECCIONES publicas al abrir.
#
#  Lo de la direccion no es un ajuste de relleno: el juego no puede saber cual de las direcciones de
#  tu maquina alcanzan tus compañeros (Hamachi no se anuncia como tal, y Windows suele tener media
#  docena de adaptadores). Se ordenan por lo que PARECEN y eliges tu una vez; desde entonces se
#  publica sola en cada apertura.
# ------------------------------------------------------------
func _pintar_direcciones(lista: VBoxContainer) -> void:
	var l := Label.new()
	l.text = "Tus direcciones"
	l.add_theme_color_override("font_color", AMBAR)
	lista.add_child(l)

	var dirs: Array = Nube.direcciones_locales()
	if dirs.is_empty():
		MenuScaffold.nota(lista, "No se ve ninguna dirección utilizable. Si usas Hamachi o similar, "
			+ "enciéndelo y vuelve a entrar aquí.")
	for ip in dirs:
		var s: String = String(ip)
		var b := Button.new()
		b.custom_minimum_size = Vector2(300, MenuScaffold.ALTO_BOTON)
		var elegida: bool = (Identidad.direccion_preferida == s)
		b.text = ("● " if elegida else "○ ") + s
		b.tooltip_text = Nube.etiqueta_direccion(s)
		b.pressed.connect(func():
			Identidad.poner_direccion(s)
			_decir("Publicarás %s cuando abras un mundo." % s)
			_pintar())
		lista.add_child(b)
		MenuScaffold.nota(lista, "    " + Nube.etiqueta_direccion(s))

	if Identidad.direccion_preferida != "":
		var quitar := Button.new()
		quitar.text = "Quitar la elección (publicar todas)"
		quitar.pressed.connect(func():
			Identidad.poner_direccion("")
			_decir("Se publicarán todas y el que entre probará en orden.")
			_pintar())
		lista.add_child(quitar)


func _pintar_yo() -> void:
	var vb: VBoxContainer = _piezas["content"]
	MenuScaffold.vaciar(vb)

	MenuScaffold.titulo(vb, "QUIÉN ERES", 20, AMBAR)
	MenuScaffold.nota(vb, "Esto es de la PERSONA, no de una partida: es lo que permite que un mundo "
		+ "recuerde qué personaje es tuyo, lo abra quien lo abra.")

	var l1 := Label.new()
	l1.text = "Tu nombre (el que verán tus compañeros)"
	l1.add_theme_font_size_override("font_size", 12)
	vb.add_child(l1)
	var campo := LineEdit.new()
	campo.text = Identidad.nombre
	campo.max_length = 16
	campo.custom_minimum_size = Vector2(260, 0)
	vb.add_child(campo)
	var guardar := Button.new()
	guardar.text = "Guardar mi nombre"
	guardar.pressed.connect(func():
		Identidad.poner_nombre(campo.text)
		_decir("Ahora eres «%s»." % Identidad.nombre)
		_pintar())
	vb.add_child(guardar)
	MenuScaffold.nota(vb, "Cambiarlo NO te convierte en otra persona: tus personajes van atados a tu "
		+ "id, no a tu nombre.")

	MenuScaffold.fila(vb, "Tu id", Identidad.id, 60)
	MenuScaffold.nota(vb, "Guárdalo en algún sitio. Si pierdes este ordenador (o el fichero de "
		+ "identidad) es lo ÚNICO que te devuelve tus personajes en los mundos de otros.")
	var otro := Button.new()
	otro.text = "Pegar otro id..."
	otro.pressed.connect(func():
		_dialogo("PEGAR UN ID", "Solo si estás recuperando tu identidad de otro ordenador. "
			+ "Son 24 caracteres. Con el id de otra persona no consigues nada: sus personajes "
			+ "están en SU mundo, no aquí.",
			[{"etiqueta": "Id (24 caracteres)", "valor": ""}],
			func(v: Array):
				if Identidad.poner_id(v[0]):
					_decir("Identidad cambiada.")
				else:
					_decir("Ese id no vale (tienen que ser 24 caracteres hexadecimales).", false)
				_pintar()))
	vb.add_child(otro)

	MenuScaffold.titulo(vb, "TU DIRECCIÓN", 18, AMBAR)
	var pref: String = Identidad.direccion_preferida
	MenuScaffold.fila(vb, "Publicas", pref if pref != "" else "todas (el que entre prueba en orden)", 90,
		VERDE if pref != "" else null)
	MenuScaffold.nota(vb, "Elígela en la lista de la izquierda. Es la que tendrán que poner tus "
		+ "compañeros para entrar, junto con la contraseña del mundo.\n\n"
		+ "⚠️ El juego reparte la dirección, pero no puede hacer que se pueda llegar a ella: para "
		+ "jugar de casa a casa sigue haciendo falta Hamachi (o abrir el puerto 24567 UDP). Si usas "
		+ "Hamachi, la buena es la que empieza por 25.")


func _pintar_detalle() -> void:
	var vb: VBoxContainer = _piezas["content"]
	MenuScaffold.vaciar(vb)

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
		# QUE TIENEN QUE PONER ELLOS. Es la pregunta practica y no estaba en ningun sitio.
		var pref: String = Identidad.direccion_preferida
		var pub: String = String(e.get("publicada", ""))
		var dirs: Array = Nube.direcciones_locales()
		var va_a_publicar: String = pref if pref != "" else (String(dirs[0]) if not dirs.is_empty() else "")
		MenuScaffold.fila(vb, "Tus compañeros ponen", "%s + la contraseña" % \
			(va_a_publicar if va_a_publicar != "" else "(no tienes dirección utilizable)"), 110,
			VERDE if va_a_publicar != "" else ROJO)
		if pub != "" and pub != va_a_publicar:
			MenuScaffold.fila(vb, "La última vez", pub, 110)
		MenuScaffold.nota(vb, "La dirección se elige en la pestaña «TÚ Y TU CONEXIÓN» y se publica "
			+ "sola cada vez que abres. El código de mundo y la contraseña son lo que tienen que "
			+ "meter una vez para añadirlo a su lista.")
	else:
		MenuScaffold.fila(vb, "Su dirección", String(e.get("direccion", "—")), 110)

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
	# A lo ancho de la columna y con la misma altura que los botones de debajo: un campo de texto es
	# tambien un objetivo que hay que acertar para escribir en el.
	campo.custom_minimum_size = Vector2(0, ALTO_BOTON_FICHA)
	campo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(campo)

	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 10)
	botones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(botones)

	if bool(e.get("mio", false)):
		_boton(botones, "Abrir y jugar", func(): _abrir(_sel, campo.text))
		if bool(e.get("pendiente", false)):
			_boton(botones, "Reintentar subida", func(): _reintentar(_sel))
	else:
		_boton(botones, "Unirse", func(): _unirse(_sel, campo.text))
		MenuScaffold.nota(vb, "Tu personaje de ese mundo lo guarda quien lo tiene abierto: la primera "
			+ "vez lo creas, y a partir de ahí entras con él. Esa persona tiene que tener el mundo "
			+ "abierto en ese momento.")

	_boton(botones, "Borrar de mi lista", func(): _borrar(_sel))


# Los botones de la ficha del mundo ("Abrir y jugar", "Borrar de mi lista"...). Se REPARTEN el
# ancho de su columna a partes iguales y son altos: eran del tamaño de su texto, o sea dos objetivos
# pequeños y de distinto tamaño pegados el uno al otro, que con el pulgar es la receta para darle al
# que no era.
const ALTO_BOTON_FICHA := 52.0


func _boton(caja: BoxContainer, txt: String, fn: Callable) -> void:
	var b := Button.new()
	b.text = txt
	b.disabled = _trabajando
	b.custom_minimum_size = Vector2(0, ALTO_BOTON_FICHA)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 16)
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
	CreadorPersonaje.abrir(_encima, "NUEVO MUNDO COMPARTIDO",
		"Ponle nombre e imagen para reconocerlo en tu lista. Después crearás tu personaje.",
		"Siguiente: tu personaje",
		# 'personaje': false -> la pantalla SIMPLE, sin fases ni muñeco. Aqui no se esta creando a
		# nadie: se le pone nombre y color a un MUNDO, y un personaje girando no diria nada.
		{"nombre": "", "color": AZUL, "personaje": false,
			"etiqueta_nombre": "Nombre del mundo", "nombre_defecto": MUNDO_POR_DEFECTO},
		func(nombre: String, asp: Dictionary):
			# Si lo deja en blanco vale el del hueco: lo prometia el placeholder.
			var n: String = nombre.strip_edges()
			_pedir_contrasena(n if n != "" else MUNDO_POR_DEFECTO, asp.get("color", AZUL),
				asp.get("imagen", PackedByteArray())))


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
	_avisar_direccion(a)
	# Aqui tambien se puede IMPORTAR: estrenar tu mundo con el personaje que ya tienes es igual de
	# valido que estrenarlo con uno nuevo, y era la primera pantalla en la que se echaba de menos.
	var previo: Dictionary = {"color": Color(0.45, 0.72, 1.0)}
	if not _ranuras_importables().is_empty():
		previo["extras"] = [{
			"texto": "Importar personaje…",
			"fn": func(creador): _elegir_ranura_a_importar(creador,
				func(slot: int, capa: Control, cr: Node): _estrenar_con_importado(slot, capa, cr, clave)),
		}]
	CreadorPersonaje.abrir(_encima, "TU PERSONAJE EN «%s»" % nombre,
		"Este personaje vive DENTRO del mundo, a tu nombre: te lo encontrarás igual quien lo abra.\n"
		+ "O puedes IMPORTAR uno de tus partidas, con sus acompañantes y lo que lleve en la bolsa.",
		"Empezar la aventura", previo,
		func(n: String, asp: Dictionary):
			Game.nueva_partida(n, asp)
			if not Mundos.estrenar(clave):
				_decir("No se pudo guardar el mundo.", false)
				return
			get_tree().change_scene_to_file(PUEBLO))


# ESTRENAR MI PROPIO MUNDO con un personaje traido de una de mis ranuras.
#
# Aqui NO hay red: el mundo es mio y lo acabo de crear, asi que no hay anfitrion al que mandarle
# nada (ese es el otro camino, _mudar_personaje). Pero SI se hace el mismo viaje de ida y vuelta por
# jd_a_dict/jd_de_dict, y no por capricho: es lo que vuelve a REGISTRAR el equipo de los personajes
# en el baul de este mundo, que nace vacio. Sin ese rodeo, sus armas quedarian puestas pero sin
# existir en el baul ni en item_meta, y el juego las trataria como piezas T1 comunes.
#
# El orden es el que es: empaquetar ANTES de nueva_partida() (que borra item_meta, de donde sale la
# identidad de cada pieza) y reconstruir DESPUES (sobre el mundo ya limpio y con su semilla nueva).
func _estrenar_con_importado(slot: int, capa: Control, creador: Node, clave: String) -> void:
	var jd: JugadorData = Game.jugador_data_desde_ranura(slot)
	if jd == null:
		_decir("Esa partida no se puede leer: no se ha traído nada.", false)
		return
	var congelado: Dictionary = Net.jd_a_dict(jd)

	capa.queue_free()
	if is_instance_valid(creador):
		creador.queue_free()

	# Mundo NUEVO: semilla nueva, baul vacio, almacen vacio, herramientas de serie. Lo de la persona
	# entra despues y por encima.
	Game.nueva_partida()
	var llegado: JugadorData = Net.jd_de_dict(congelado)
	Game.aplicar_jugador_mundo(llegado, 0)   # 0 = no toques la semilla que acaba de salir

	if not Mundos.estrenar(clave):
		_decir("No se pudo guardar el mundo.", false)
		return
	print("[mudanza] mundo estrenado con %s" % llegado.resumen())
	get_tree().change_scene_to_file(PUEBLO)


# ============================================================
#  AÑADIR EL MUNDO DE OTRA PERSONA
#  Con su direccion (lo que funciona hoy) o con su codigo de mundo (lo que funcionara cuando el
#  almacen sea de verdad y reparta la direccion de quien lo tenga abierto).
# ------------------------------------------------------------
func _anadir_ajeno() -> void:
	_dialogo("AÑADIR EL MUNDO DE OTRA PERSONA",
		"Los tres datos los tiene esa persona: los ve en su pantalla del mundo. La dirección es la "
		+ "suya (la de Hamachi si es lo que usáis), no la tuya. El código de mundo es opcional: "
		+ "servirá para encontrarle sin saber su dirección cuando esté el almacén de verdad.",
		[
			{"etiqueta": "Cómo quieres verlo en TU lista (p.ej. «la casa de Nacho»)", "valor": ""},
			{"etiqueta": "SU dirección (IP)", "valor": ""},
			{"etiqueta": "Contraseña del mundo", "secreto": true},
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
func _abrir(clave: String, pass_: String, forzar_build := false) -> void:
	if _trabajando:
		return
	_trabajando = true
	_decir("Abriendo el mundo...")
	var r: Dictionary = await Mundos.abrir(clave, pass_, forzar_build)
	_trabajando = false
	if not r.get("ok", false):
		_decir(String(r.get("mensaje", "No se pudo abrir.")), false)
		# BUILD DISTINTO no es una perdida de datos segura, solo un riesgo (los saves llevan rutas
		# res:// dentro): lo normal es que dos builds tengan las mismas rutas y cargue perfecto. Si se
		# rechazara a secas, subir el numero de version del juego dejaria tus mundos inaccesibles para
		# siempre -- y durante el desarrollo la version cambia constantemente. Se avisa y tu decides.
		if String(r.get("error", "")) == "build_distinto":
			_pintar()
			var vb: VBoxContainer = _piezas["content"]
			var b := Button.new()
			b.text = "Abrir de todos modos"
			b.add_theme_color_override("font_color", ROJO)
			b.pressed.connect(func(): _abrir(clave, pass_, true))
			vb.add_child(b)
			MenuScaffold.nota(vb, "Si al entrar falta algo (un arma, un material), cierra sin guardar "
				+ "y vuelve al build con el que se guardó.")
			return
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
			_avisar_direccion(r)
			CreadorPersonaje.abrir(_encima, "TU PERSONAJE",
				"Este personaje vive dentro del mundo, a tu nombre.", "Empezar la aventura",
				{"color": Color(0.45, 0.72, 1.0)},
				func(n: String, asp: Dictionary):
					Game.nueva_partida(n, asp)
					if Mundos.estrenar(clave):
						get_tree().change_scene_to_file(PUEBLO))
		_:
			if not Mundos.cargar(clave):
				_decir("No se pudo cargar ese mundo.", false)
				return
			_avisar_direccion(r)
			if bool(r.get("solo_local", false)):
				_decir("Ojo: en el almacén no había partida de este mundo, se juega con la copia de "
					+ "este ordenador. Al cerrar se sube.", false)
			# Se vuelve EXACTAMENTE donde se guardo, como en las ranuras de un jugador.
			var datos: SaveData = Mundos.datos_cabecera(clave)
			get_tree().change_scene_to_file(MAZMORRA if datos != null and datos.en_mazmorra else PUEBLO)


# Al abrir, DECIR que direccion se ha publicado. Era la pregunta que no tenia respuesta en ninguna
# pantalla: "¿como se que ha pillado mi IP?". Y si no hay ninguna utilizable, se avisa en rojo en vez
# de dejarte creyendo que tus compañeros pueden entrar.
func _avisar_direccion(r: Dictionary) -> void:
	var dirs: Array = r.get("direcciones", [])
	if dirs.is_empty():
		_decir("Mundo abierto, pero SIN dirección publicada: nadie podrá entrar. Enciende Hamachi y "
			+ "elige tu dirección en «TÚ Y TU CONEXIÓN».", false)
		return
	_decir("Mundo abierto. Tus compañeros tienen que poner %s y la contraseña." % String(dirs[0]))


# ============================================================
#  UNIRSE al mundo de otra persona
#  El baile es: conectar -> el anfitrion mira si ya tengo personaje ahi -> me lo manda, o me pide que
#  lo cree -> lo aplico -> al pueblo. Todo lo decide Mundos/Net; aqui solo se pinta y se abre el
#  creador cuando lo piden.
# ------------------------------------------------------------
func _unirse(clave: String, pass_: String) -> void:
	if _trabajando:
		return
	_trabajando = true
	_decir("Conectando...")
	var r: Dictionary = await Mundos.unirse(clave, pass_)
	_trabajando = false
	if not r.get("ok", false):
		_decir(String(r.get("mensaje", "No se pudo unir.")), false)
		return
	_decir("Conectando a %s..." % String(r.get("direccion", "")))


# El mundo no me conoce: me hago un personaje AHI. Vivira dentro de ese mundo, no en mi disco.
#
# Y en la MISMA pantalla esta el boton de IMPORTAR: crear uno nuevo o traerse uno hecho son la misma
# decision, asi que no tiene sentido preguntarlo en un panel previo antes de dejarte ver nada. El
# boton solo aparece si de verdad hay alguna partida que traer.
func _crear_mi_personaje_en_mundo_ajeno(nombre_mundo: String) -> void:
	var previo: Dictionary = {"color": Color(0.45, 0.72, 1.0)}
	if not _ranuras_importables().is_empty():
		previo["extras"] = [{
			"texto": "Importar personaje…",
			"fn": func(creador): _elegir_ranura_a_importar(creador, _mudar_personaje),
		}]
	CreadorPersonaje.abrir(_encima, "TU PERSONAJE EN EL MUNDO DE %s" % nombre_mundo.to_upper(),
		"Es tu primera vez aquí. Este personaje se queda a vivir DENTRO de este mundo, a tu nombre: "
		+ "la próxima vez que entres, entrarás con él.\n"
		+ "O puedes IMPORTAR uno de tus partidas, con sus acompañantes y lo que lleve en la bolsa.",
		"Entrar en el mundo", previo,
		func(n: String, asp: Dictionary):
			# Se arma un PersonajeData con lo elegido y se manda: el ANFITRION es quien lo guarda en
			# el mundo (es suyo mientras tenga el cerrojo) y me lo devuelve ya empaquetado.
			var pj := PersonajeData.new()
			pj.nombre = n.strip_edges() if n.strip_edges() != "" else Game.NOMBRE_POR_DEFECTO
			pj.aspecto = PersonajeData.aspecto_nuevo(asp.get("color", pj.color))
			pj.aplicar_aspecto(asp)
			# EL UID, A MANO. Este personaje no pasa por Game.fichar(), que es el unico sitio que lo
			# pone, asi que salia con uid "" y llegaba asi al mundo del host. Un uid vacio es un
			# personaje FANTASMA: no se le puede mirar si esta de encargo (uid_de_encargo("") = 0), no
			# se le encuentra por uid, y en el reparto de la excelia de un encargo aparecia como "?".
			Game.asegurar_uid(pj)
			Net.mandar_alta_personaje(pj)
			_decir("Creando tu personaje en el mundo..."))


# Las partidas que se pueden traer. Solo las que ESTE build entiende: una ranura ilegible o de otra
# version no es un hueco vacio, pero tampoco se puede importar, y traer media partida seria peor que
# no ofrecerla (ver Perfil.inspeccionar).
func _ranuras_importables() -> Array:
	var out: Array = []
	for i in range(1, Perfil.RANURAS + 1):
		var info: Dictionary = Perfil.inspeccionar(i)
		if int(info.get("estado", -1)) == Perfil.OK and info.get("datos") != null:
			out.append({"slot": i, "datos": info["datos"]})
	return out


# ¿CUAL de tus partidas te traes? Se abre ENCIMA del creador y el creador se queda vivo detras: si
# cancelas aqui, sigues donde estabas y puedes crear uno nuevo como si nada.
#
# La MISMA lista sirve para los dos sitios donde se importa (estrenar mi mundo y entrar en el de
# otro), que solo se diferencian en QUE se hace con la ranura elegida. Por eso lo que hacer viene de
# fuera: al_elegir(slot, capa, creador).
func _elegir_ranura_a_importar(creador: Node, al_elegir: Callable) -> void:
	var capa := ColorRect.new()
	capa.color = Color(0.04, 0.04, 0.06, 0.97)
	capa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa.mouse_filter = Control.MOUSE_FILTER_STOP
	# Los menus del juego pausan el arbol: sin esto la capa nace congelada y no responde.
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	_encima.add_child(capa)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa.add_child(centro)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(480, 0)
	vb.add_theme_constant_override("separation", 8)
	centro.add_child(vb)

	MenuScaffold.titulo(vb, "¿A QUIÉN TE TRAES?", 20)
	MenuScaffold.nota(vb, "Viene con sus acompañantes, el equipo que lleven PUESTO, su dinero, sus "
		+ "oficios y todo lo que tenga en la BOLSA.")

	for e in _ranuras_importables():
		var d: SaveData = e["datos"]
		var b := Button.new()
		b.text = "%s  ·  Nv.%d  ·  %d monedas" % [d.nombre, d.cab_nivel, d.cab_dinero]
		b.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)
		var s: int = int(e["slot"])
		b.pressed.connect(func(): al_elegir.call(s, capa, creador))
		vb.add_child(b)

	MenuScaffold.nota(vb, "Tu partida NO se borra: es una copia. Lo que SÍ se queda allí es el baúl "
		+ "de armas sueltas y el almacén de casa, porque aquí esas cosas son del mundo y son comunes. "
		+ "Si quieres llevarte materiales, recógelos a la bolsa ANTES de venir.")

	var volver := Button.new()
	volver.text = "Volver"
	volver.pressed.connect(capa.queue_free)
	vb.add_child(volver)


# Empaqueta la ranura elegida y la manda. El anfitrion la valida y la guarda en el mundo.
func _mudar_personaje(slot: int, capa: Control, creador: Node) -> void:
	var jd: JugadorData = Game.jugador_data_desde_ranura(slot)
	if jd == null:
		# La lista se queda abierta a proposito: asi se puede probar con otra.
		_decir("Esa partida no se puede leer: no se ha traído nada.", false)
		return
	capa.queue_free()
	if is_instance_valid(creador):
		creador.queue_free()   # ya no hay nada que crear
	Net.mandar_alta_jugador(jd)
	_decir("Trayendo a %s al mundo..." % jd.resumen())


# Ya tengo mi personaje del mundo: al pueblo. El anuncio del lugar va DESPUES del cambio de escena
# (es el patron de todo el proyecto): es lo que reconstruye avatares y suelo en la escena nueva.
func _entrar_al_mundo_ajeno() -> void:
	# El arbol se coge ANTES del cambio: este nodo ES la escena que se va, y en cuanto se cambia ya no
	# esta dentro, asi que su get_tree() devuelve null. Con el await sobre ese null la funcion se
	# cortaba aqui EN CADA entrada al mundo de otro y anunciar_lugar no llegaba a correr: el host no se
	# enteraba de que estabas en el pueblo, y sin eso tu avatar no aparece para el resto.
	var arbol := get_tree()
	arbol.change_scene_to_file(PUEBLO)
	await arbol.process_frame
	Net.anunciar_lugar("pueblo")


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
	_encima.add_child(capa)   # en la capa de encima, o se queda detras del fondo del menu

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
