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

const AMBAR := Color(0.95, 0.72, 0.36)
const ROJO := Color(0.9, 0.5, 0.5)

var _lista: VBoxContainer = null
var _aviso: Label = null

# Ranura pendiente de confirmar sobrescritura (0 = nada pendiente).
var _confirmar_nueva: int = 0

# IMAGEN elegida en la pantalla de creacion (vacia = ninguna). Son VARIABLES MIEMBRO y no locales
# de _crear_personaje porque las lambdas de GDScript capturan los locales POR VALOR: una lambda
# que capturase el PackedByteArray se quedaria con la foto del momento en que se creo y no veria
# la imagen que eliges despues.
var _crear_png: PackedByteArray = PackedByteArray()
var _crear_tex: Texture2D = null

# ENCUADRE: la imagen tal cual entro del disco (sin recortar) mas el zoom y el centro que ha
# elegido el jugador. De aqui sale _crear_png en cada toque (Game.png_cuadrado). La fuente NO se
# guarda en la partida: solo vive mientras esta abierta esta pantalla.
var _crear_img_src: Image = null
var _crear_zoom: float = 1.0
var _crear_centro: Vector2 = Vector2(0.5, 0.5)


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

	var salir := Button.new()
	salir.text = "Salir del juego"
	salir.pressed.connect(get_tree().quit)
	vb.add_child(salir)

	_pintar()


# Una fila por ranura: [Continuar/Jugar] [Nueva partida] [Borrar].
func _pintar() -> void:
	for c in _lista.get_children():
		c.queue_free()

	var ultima: int = Perfil.ultima_ranura()
	for slot in range(1, Perfil.RANURAS + 1):
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 8)
		_lista.add_child(fila)

		var datos: SaveData = Perfil.cabecera(slot)

		var jugar := Button.new()
		jugar.custom_minimum_size = Vector2(520, 0)
		if datos == null:
			jugar.text = "Ranura %d — vacía  ·  Nueva partida" % slot
			jugar.pressed.connect(_nueva.bind(slot))
		else:
			var marca: String = "  ◄ la más reciente" if slot == ultima else ""
			jugar.text = "Ranura %d — %s%s" % [slot, datos.resumen(), marca]
			jugar.pressed.connect(_cargar.bind(slot))
		fila.add_child(jugar)

		if datos != null:
			# Editar: cambiarte el color o ponerte una imagen sin empezar de cero.
			var editar := Button.new()
			editar.text = "Editar"
			editar.pressed.connect(_crear_personaje.bind(slot, true))
			fila.add_child(editar)

			var nueva := Button.new()
			nueva.text = "Nueva"
			nueva.pressed.connect(_nueva.bind(slot))
			fila.add_child(nueva)

			var borrar := Button.new()
			borrar.text = "Borrar"
			borrar.pressed.connect(_borrar.bind(slot))
			fila.add_child(borrar)


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
#  PERSONAJE: nombre + aspecto. La MISMA pantalla hace dos cosas segun 'editando':
#    - CREAR  (Nueva partida): al aceptar arranca una partida de cero.
#    - EDITAR (boton Editar):  al aceptar solo reescribe el aspecto de esa ranura y vuelve al
#      menu. NO toca el progreso: ver Perfil.editar_aspecto, que explica por que no se puede
#      guardar por la via normal desde aqui.
#  El aspecto son cuatro cosas, y las cuatro van al SaveData de ESA ranura (no al perfil): cada
#  partida es un personaje distinto.
#    - COLOR:   el cuerpo, si no pones imagen.
#    - IMAGEN:  opcional, tuya, del disco. La encuadras en un CUADRADO (zoom + arrastre) y se
#      guarda ya recortada DENTRO de la partida (ver Game.png_cuadrado).
#    - TINTE:   cuanto se ve el color por encima de esa imagen. Sin imagen no pinta nada.
#    - METAL:   el brillo, que va SIEMPRE lo ultimo: barniza tambien tu imagen.
#  Interfaz placeholder por codigo, como el resto; el arte va al final.
# ------------------------------------------------------------
func _crear_personaje(slot: int, editando: bool = false) -> void:
	# Editando se arranca con lo que ya tenias; creando, en blanco.
	var previo: SaveData = Perfil.cabecera(slot) if editando else null
	if previo == null:
		editando = false   # si la ranura no se puede leer, esto es una creacion y punto
	_crear_png = previo.imagen if previo != null else PackedByteArray()
	_crear_tex = Game.textura_de_png(_crear_png)
	# EDITANDO con imagen: lo guardado ya es un cuadrado, asi que entra de fuente tal cual (zoom 1,
	# centrada). Se puede reencuadrar, pero sobre lo ya recortado: la foto original no viaja en la
	# partida (solo sus 128x128), y no vamos a pedirle al jugador que la busque otra vez.
	_crear_img_src = _imagen_de_png(_crear_png)
	_crear_zoom = 1.0
	_crear_centro = Vector2(0.5, 0.5)

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

	# El ColorPicker entero es MUY alto: en vertical se salia de la pantalla. Va en DOS
	# COLUMNAS (nombre y muestra a la izquierda, el selector a la derecha) para que todo
	# quepa de una sin scroll.
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	center.add_child(vb)

	var tit := Label.new()
	tit.text = ("EDITAR PERSONAJE  ·  ranura %d" if editando else "NUEVO PERSONAJE  ·  ranura %d") % slot
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tit.add_theme_font_size_override("font_size", 24)
	tit.add_theme_color_override("font_color", AMBAR)
	vb.add_child(tit)

	if editando:
		var sub := Label.new()
		sub.text = "Solo cambia cómo te ves. Tu progreso no se toca."
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 12)
		sub.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
		vb.add_child(sub)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	vb.add_child(cols)

	# --- Columna izquierda: nombre + muestra + la imagen y su encuadre ---
	var izq := VBoxContainer.new()
	izq.add_theme_constant_override("separation", 8)
	cols.add_child(izq)

	var lbl := Label.new()
	lbl.text = "¿Cómo te llamas?"
	izq.add_child(lbl)

	var nombre := LineEdit.new()
	nombre.placeholder_text = Game.NOMBRE_POR_DEFECTO   # si lo dejas vacio, te llamas asi
	nombre.max_length = 16
	nombre.custom_minimum_size = Vector2(280, 0)
	if previo != null:
		nombre.text = previo.nombre
	izq.add_child(nombre)

	var lbl2 := Label.new()
	lbl2.text = "Así te verás"
	izq.add_child(lbl2)

	# Muestra: mismo nodo (ColorRect) y mismo material que el cuerpo de verdad, asi que lo que
	# ves aqui es EXACTAMENTE lo que te llevas al mapa, imagen y brillo incluidos.
	#
	# CUADRADA porque el cuerpo del mapa lo es (ColorRect de 32x32) y el shader estira la imagen al
	# rect por UV: con la muestra a 2:1 de antes, aqui veias la foto aplastada y en el mapa no, que
	# es justo lo contrario de lo que promete el parrafo de arriba.
	#
	# OJO con el SHRINK_CENTER: un Control dentro de un VBoxContainer se estira a lo ANCHO de la
	# columna (280 px, que los fija el LineEdit), y custom_minimum_size solo pone un minimo -> sin
	# esto la muestra sale de 280x180, o sea rectangular otra vez por mucho que pidas un cuadrado.
	var muestra := ColorRect.new()
	muestra.custom_minimum_size = Vector2(180, 180)
	muestra.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	muestra.color = previo.color if previo != null else COLOR_INICIAL
	izq.add_child(muestra)

	# ENCUADRE: cuanto se acerca el recorte. Mover se hace ARRASTRANDO sobre la muestra (el aviso de
	# abajo lo dice): dos sliders mas de X/Y en una pantalla que ya va justa de alto seria peor, y
	# arrastrar la propia imagen es lo que espera cualquiera.
	var lbl_zoom := Label.new()
	lbl_zoom.text = "Acercar la imagen"
	izq.add_child(lbl_zoom)

	var zoom := HSlider.new()
	zoom.min_value = 1.0    # 1 = el cuadrado mas grande que quepa en la foto
	zoom.max_value = 3.0
	zoom.step = 0.05
	zoom.value = 1.0
	zoom.custom_minimum_size = Vector2(280, 0)
	zoom.editable = _crear_img_src != null   # sin imagen no hay nada que encuadrar
	izq.add_child(zoom)

	# --- Columna derecha: el selector de color y los dos mandos de acabado ---
	# El brillo y el tinte van AQUI y no debajo de la muestra porque la columna izquierda (nombre +
	# muestra cuadrada + encuadre + botones) se salia por abajo de la pantalla, y a la derecha
	# sobraba hueco bajo el selector. Ademas los dos tiñen/barnizan el color: su sitio es este.
	var der := VBoxContainer.new()
	der.add_theme_constant_override("separation", 8)
	cols.add_child(der)

	var lbl3 := Label.new()
	lbl3.text = "Tu color"
	der.add_child(lbl3)

	# El ColorPicker de serie trae MUCHO de mas (cuadrado HSV, cuentagotas, hex, paletas) y con
	# todo eso NO CABE en pantalla. Aqui solo hacen falta las tres barras R/G/B: se apaga el
	# resto para que la pantalla entre entera y no haya que hacer scroll.
	var picker := ColorPicker.new()
	picker.color_mode = ColorPicker.MODE_RGB   # barras R/G/B
	picker.edit_alpha = false                  # translucido no: eres un cuerpo, no un fantasma
	picker.picker_shape = ColorPicker.SHAPE_NONE   # fuera el cuadrado HSV (lo mas alto)
	picker.sampler_visible = false             # fuera el cuentagotas de pantalla
	picker.hex_visible = false                 # fuera el campo Hex
	picker.presets_visible = false             # fuera las paletas / "Swatches"
	picker.can_add_swatches = false
	picker.color = previo.color if previo != null else COLOR_INICIAL
	der.add_child(picker)

	# ACABADO METALICO: de mate (0) a pulido (1). El brillo se ve moverse en la muestra
	# mientras lo subes, que es la unica forma de elegirlo con criterio.
	var lbl_met := Label.new()
	lbl_met.text = "Brillo metálico"
	der.add_child(lbl_met)

	var metal := HSlider.new()
	metal.min_value = 0.0
	metal.max_value = 1.0
	metal.step = 0.05
	metal.value = previo.metalico if previo != null else 0.0   # de serie mate: el brillo se elige
	metal.custom_minimum_size = Vector2(280, 0)
	der.add_child(metal)

	# TINTE: cuanto se ve el color POR ENCIMA de la imagen. Solo tiene sentido con imagen (sin
	# ella, el cuerpo YA es el color), asi que se enseña apagado hasta que pongas una.
	var lbl_tinte := Label.new()
	lbl_tinte.text = "Color sobre la imagen"
	der.add_child(lbl_tinte)

	var tinte := HSlider.new()
	tinte.min_value = 0.0
	tinte.max_value = 1.0
	tinte.step = 0.05
	tinte.value = previo.color_alpha if previo != null else 0.0   # con imagen, de serie se ve limpia
	tinte.custom_minimum_size = Vector2(280, 0)
	tinte.editable = _crear_tex != null   # sin imagen no hay nada que teñir
	der.add_child(tinte)

	# Repinta la muestra con lo que haya AHORA en los mandos. _crear_tex es variable miembro
	# justamente para que esto vea la imagen nueva (ver el comentario de su declaracion).
	#
	# El RECORTE se rehace aqui, en cada toque: la muestra enseña el _crear_png que se va a guardar,
	# no una aproximacion suya. Es un recorte de 128 px, no cuesta nada, y a cambio no existe la
	# posibilidad de que el preview y lo guardado se separen.
	var refrescar := func() -> void:
		if _crear_img_src != null:
			_crear_png = Game.png_cuadrado(_crear_img_src, _crear_zoom, _crear_centro)
			_crear_tex = Game.textura_de_png(_crear_png)
		muestra.material = Game.material_cuerpo(metal.value, _crear_tex, tinte.value)
		tinte.editable = _crear_tex != null
		zoom.editable = _crear_img_src != null
		lbl_tinte.modulate = Color(1, 1, 1) if _crear_tex != null else Color(1, 1, 1, 0.4)
		lbl_zoom.modulate = Color(1, 1, 1) if _crear_img_src != null else Color(1, 1, 1, 0.4)

	metal.value_changed.connect(func(_v: float): refrescar.call())
	tinte.value_changed.connect(func(_v: float): refrescar.call())
	picker.color_changed.connect(func(c: Color): muestra.color = c)
	zoom.value_changed.connect(func(v: float):
		_crear_zoom = v
		refrescar.call())

	# MOVER el encuadre arrastrando. El desplazamiento va en fraccion de la imagen: se divide por
	# el zoom porque cuanto mas cerca estas, menos original abarca la muestra (y el mismo gesto
	# tiene que mover menos foto, o al ampliar se iria de las manos). El signo es negativo porque
	# arrastras la IMAGEN, no la ventana: llevar el raton a la derecha trae lo de la izquierda.
	# Game.png_cuadrado ya clampea el rect; el clamp de aqui es para que el centro no se escape a
	# valores absurdos y luego haya que arrastrar de vuelta en seco.
	muestra.gui_input.connect(func(event: InputEvent):
		if _crear_img_src == null:
			return
		if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
			var rel: Vector2 = (event as InputEventMouseMotion).relative / muestra.size / _crear_zoom
			_crear_centro = Vector2(clampf(_crear_centro.x - rel.x, 0.0, 1.0),
				clampf(_crear_centro.y - rel.y, 0.0, 1.0))
			refrescar.call())

	# --- IMAGEN propia ---
	var fila_img := HBoxContainer.new()
	fila_img.add_theme_constant_override("separation", 8)
	izq.add_child(fila_img)

	var poner := Button.new()
	poner.text = "Poner una imagen..."
	fila_img.add_child(poner)

	var quitar := Button.new()
	quitar.text = "Quitar"
	quitar.disabled = _crear_tex == null   # editando puede que YA traigas imagen
	fila_img.add_child(quitar)

	var aviso_img := Label.new()
	aviso_img.add_theme_font_size_override("font_size", 11)
	aviso_img.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
	aviso_img.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso_img.custom_minimum_size = Vector2(280, 0)
	aviso_img.text = ("Ya tienes imagen. Ajústala con «Acercar» y arrastrando la muestra." if _crear_tex != null
		else "Opcional. Se guarda dentro de la partida (encogida), así que puedes mover o borrar el archivo original.")
	izq.add_child(aviso_img)

	quitar.pressed.connect(func():
		_crear_png = PackedByteArray()
		_crear_tex = null
		_crear_img_src = null
		quitar.disabled = true
		tinte.value = 0.0
		zoom.value = 1.0        # deja el encuadre listo para la siguiente imagen
		_crear_zoom = 1.0
		_crear_centro = Vector2(0.5, 0.5)
		aviso_img.text = "Sin imagen: tu cuerpo es el color de al lado."
		refrescar.call())

	poner.pressed.connect(func():
		var fd := FileDialog.new()
		fd.access = FileDialog.ACCESS_FILESYSTEM   # el disco del jugador, no res://
		fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		fd.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp,*.bmp ; Imágenes"])
		fd.use_native_dialog = true
		fd.title = "Elige la imagen de tu personaje"
		capa.add_child(fd)
		# El dialogo es de usar y tirar: sin esto se irian apilando uno por cada clic en el boton.
		fd.canceled.connect(fd.queue_free)
		fd.file_selected.connect(func(ruta: String):
			fd.queue_free()
			var src: Image = Game.imagen_de_archivo(ruta)
			if src == null:
				aviso_img.text = "Esa imagen no se ha podido leer. Prueba con un PNG o un JPG."
				return
			# Entra centrada y del todo: el recorte de partida es el cuadrado mas grande que quepa.
			_crear_img_src = src
			_crear_zoom = 1.0
			_crear_centro = Vector2(0.5, 0.5)
			zoom.set_value_no_signal(1.0)   # sin señal: ya refrescamos abajo, no hace falta dos veces
			quitar.disabled = false
			aviso_img.text = "Imagen puesta. Ajusta el encuadre con «Acercar» y arrastrando la muestra."
			refrescar.call())
		fd.popup_centered_ratio(0.7))

	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 8)
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(botones)

	var empezar := Button.new()
	empezar.text = "Guardar cambios" if editando else "Empezar la aventura"
	if editando:
		empezar.pressed.connect(func():
			_guardar_aspecto(slot, nombre.text, picker.color, metal.value, tinte.value)
			capa.queue_free())
	else:
		empezar.pressed.connect(func(): _empezar(slot, nombre.text, picker.color, metal.value, tinte.value))
	botones.add_child(empezar)

	var cancelar := Button.new()
	cancelar.text = "Cancelar"
	cancelar.pressed.connect(func(): capa.queue_free())
	botones.add_child(cancelar)

	# Una pasada al montar: es lo que pone el material en la muestra. Sin esto, EDITANDO abririas la
	# pantalla sin tu imagen ni tu brillo hasta que tocaras un mando.
	refrescar.call()

	nombre.grab_focus()


# Color de salida de la creacion (uno cualquiera, ya lo cambiara).
const COLOR_INICIAL := Color(0.45, 0.72, 1.0)


# Los bytes de un PNG guardado, de vuelta a Image para poder reencuadrarlo. null si no hay imagen
# o si el PNG no se lee (una ranura con la imagen corrupta se edita igual, sin foto: que no se
# pueda tocar el aspecto seria peor que perder la imagen).
func _imagen_de_png(png: PackedByteArray) -> Image:
	if png.is_empty():
		return null
	var img := Image.new()
	if img.load_png_from_buffer(png) != OK:
		return null
	return img


# EDITAR: solo el aspecto de esa ranura, y de vuelta al menu. El progreso ni se toca (Perfil
# reescribe los cinco campos del .tres a mano; ver alli por que no se puede guardar por la via
# normal desde el menu).
func _guardar_aspecto(slot: int, nombre: String, color: Color, metalico: float, tinte: float) -> void:
	if Perfil.editar_aspecto(slot, nombre, color, metalico, _crear_png, tinte):
		_aviso.text = "Ranura %d: aspecto actualizado." % slot
	else:
		_aviso.text = "No se pudo editar la ranura %d." % slot
	_pintar()   # el nombre sale en la fila de la ranura: hay que repintarla


func _empezar(slot: int, nombre: String, color: Color, metalico: float, tinte: float) -> void:
	# el nombre vacio lo resuelve Game (NOMBRE_POR_DEFECTO)
	Game.nueva_partida(nombre, color, metalico, _crear_png, tinte)
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
		# Ranura ilegible (p.ej. de una version vieja del save): no hay nombre que pedir, y
		# tampoco hay progreso jugable que proteger.
		Perfil.borrar(slot)
		_aviso.text = "Ranura %d borrada." % slot
		_confirmar_nueva = 0
		_pintar()
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


func _hacer_borrado(slot: int, capa: Control) -> void:
	Perfil.borrar(slot)
	capa.queue_free()
	_aviso.text = "Ranura %d borrada." % slot
	_confirmar_nueva = 0
	_pintar()
