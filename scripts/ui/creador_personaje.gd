# ============================================================
#  creador_personaje.gd
#  La pantalla de "ponle cara a este personaje": nombre, color, brillo metalico e imagen propia
#  con su encuadre. Es una CAPA a pantalla completa que se monta sobre quien la llame.
#
#  Vivia dentro de main_menu.gd, atada a las ranuras de guardado. Ahora la usan DOS sitios:
#    - el menu principal, al crear o editar una ranura;
#    - la TABERNA, al contratar a un companero (que se crea igual que te creaste tu).
#  Por eso se saco aqui: son 300 lineas de encuadre de imagen y no se iban a escribir dos veces,
#  y ademas asi el companero se crea EXACTAMENTE con la misma pantalla que el jugador (lo que
#  ves al elegir es lo que se ve en el mapa, en los dos casos).
#
#  Quien la abre no hereda nada: llama a abrir() y recibe el resultado por el Callable.
# ============================================================

extends Control
class_name CreadorPersonaje

const AMBAR := Color(0.95, 0.72, 0.36)
const GRIS := Color(0.6, 0.63, 0.7)
# Color de salida de la creacion (uno cualquiera, ya lo cambiara).
const COLOR_INICIAL := Color(0.45, 0.72, 1.0)

# --- Estado de la IMAGEN mientras se encuadra (ver png_cuadrado) ---
# _png es lo que se va a guardar; _src es la foto ORIGINAL ya encogida, que se queda a mano para
# poder reencuadrar sin volver a leer el fichero. Son variables de la instancia (y no locales del
# montaje) porque las tocan varios lambdas: el slider de zoom, el arrastre y el boton de quitar.
var _png: PackedByteArray = PackedByteArray()
var _tex: Texture2D = null
var _src: Image = null
var _zoom: float = 1.0
var _centro: Vector2 = Vector2(0.5, 0.5)

var _on_aceptar: Callable


# Monta la pantalla sobre 'padre' y la devuelve.
#   previo      = {"nombre","color","metalico","color_alpha","imagen"} (vacio = personaje en blanco)
#   on_aceptar  = func(nombre: String, color: Color, metalico: float, tinte: float, png: PackedByteArray)
# El que acepta se encarga de cerrar la capa si quiere (aqui se cierra sola al aceptar).
static func abrir(padre: Node, titulo: String, subtitulo: String, texto_boton: String,
		previo: Dictionary, on_aceptar: Callable) -> CreadorPersonaje:
	var c := CreadorPersonaje.new()
	c._on_aceptar = on_aceptar
	padre.add_child(c)
	c._montar(titulo, subtitulo, texto_boton, previo)
	return c


func _montar(titulo: String, subtitulo: String, texto_boton: String, previo: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Los menus del juego pausan el arbol: sin esto, la pantalla se abriria congelada.
	process_mode = Node.PROCESS_MODE_ALWAYS

	var color_previo: Color = previo.get("color", COLOR_INICIAL)
	_png = previo.get("imagen", PackedByteArray())
	_tex = Game.textura_de_png(_png)
	# Lo guardado ya es un cuadrado, asi que entra de fuente tal cual (zoom 1, centrada). Se puede
	# reencuadrar, pero sobre lo ya recortado: la foto original no viaja en la partida.
	_src = _imagen_de_png(_png)
	_zoom = 1.0
	_centro = Vector2(0.5, 0.5)

	var fondo := ColorRect.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.04, 0.04, 0.06, 0.96)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP   # no dejar pasar clics a lo de debajo
	add_child(fondo)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# El ColorPicker entero es MUY alto: en vertical se salia de la pantalla. Va en DOS
	# COLUMNAS (nombre y muestra a la izquierda, el selector a la derecha) para que todo
	# quepa de una sin scroll.
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	center.add_child(vb)

	var tit := Label.new()
	tit.text = titulo
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tit.add_theme_font_size_override("font_size", 24)
	tit.add_theme_color_override("font_color", AMBAR)
	vb.add_child(tit)

	if subtitulo != "":
		var sub := Label.new()
		sub.text = subtitulo
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 12)
		sub.add_theme_color_override("font_color", GRIS)
		vb.add_child(sub)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	vb.add_child(cols)

	# --- Columna izquierda: nombre + muestra + la imagen y su encuadre ---
	var izq := VBoxContainer.new()
	izq.add_theme_constant_override("separation", 8)
	cols.add_child(izq)

	var lbl := Label.new()
	lbl.text = "¿Cómo se llama?"
	izq.add_child(lbl)

	var nombre := LineEdit.new()
	nombre.placeholder_text = Game.NOMBRE_POR_DEFECTO   # si lo dejas vacio, se llama asi
	nombre.max_length = 16
	nombre.custom_minimum_size = Vector2(280, 0)
	nombre.text = str(previo.get("nombre", ""))
	izq.add_child(nombre)

	var lbl2 := Label.new()
	lbl2.text = "Así se verá"
	izq.add_child(lbl2)

	# Muestra: mismo nodo (ColorRect) y mismo material que el cuerpo de verdad, asi que lo que
	# ves aqui es EXACTAMENTE lo que se lleva al mapa, imagen y brillo incluidos.
	#
	# CUADRADA porque el cuerpo del mapa lo es (ColorRect de 32x32) y el shader estira la imagen al
	# rect por UV: con una muestra a 2:1, aqui verias la foto aplastada y en el mapa no.
	#
	# OJO con el SHRINK_CENTER: un Control dentro de un VBoxContainer se estira a lo ANCHO de la
	# columna (280 px, que los fija el LineEdit), y custom_minimum_size solo pone un minimo -> sin
	# esto la muestra sale de 280x180, o sea rectangular otra vez por mucho que pidas un cuadrado.
	var muestra := ColorRect.new()
	muestra.custom_minimum_size = Vector2(180, 180)
	muestra.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	muestra.color = color_previo
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
	zoom.editable = _src != null   # sin imagen no hay nada que encuadrar
	izq.add_child(zoom)

	# --- Columna derecha: el selector de color y los dos mandos de acabado ---
	# El brillo y el tinte van AQUI y no debajo de la muestra porque la columna izquierda (nombre +
	# muestra cuadrada + encuadre + botones) se salia por abajo de la pantalla, y a la derecha
	# sobraba hueco bajo el selector. Ademas los dos tiñen/barnizan el color: su sitio es este.
	var der := VBoxContainer.new()
	der.add_theme_constant_override("separation", 8)
	cols.add_child(der)

	var lbl3 := Label.new()
	lbl3.text = "Su color"
	der.add_child(lbl3)

	# El ColorPicker de serie trae MUCHO de mas (cuadrado HSV, cuentagotas, hex, paletas) y con
	# todo eso NO CABE en pantalla. Aqui solo hacen falta las tres barras R/G/B.
	var picker := ColorPicker.new()
	picker.color_mode = ColorPicker.MODE_RGB   # barras R/G/B
	picker.edit_alpha = false                  # translucido no: eres un cuerpo, no un fantasma
	picker.picker_shape = ColorPicker.SHAPE_NONE   # fuera el cuadrado HSV (lo mas alto)
	picker.sampler_visible = false             # fuera el cuentagotas de pantalla
	picker.hex_visible = false                 # fuera el campo Hex
	picker.presets_visible = false             # fuera las paletas / "Swatches"
	picker.can_add_swatches = false
	picker.color = color_previo
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
	metal.value = float(previo.get("metalico", 0.0))   # de serie mate: el brillo se elige
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
	tinte.value = float(previo.get("color_alpha", 0.0))   # con imagen, de serie se ve limpia
	tinte.custom_minimum_size = Vector2(280, 0)
	tinte.editable = _tex != null   # sin imagen no hay nada que teñir
	der.add_child(tinte)

	# Repinta la muestra con lo que haya AHORA en los mandos.
	#
	# El RECORTE se rehace aqui, en cada toque: la muestra enseña el _png que se va a guardar,
	# no una aproximacion suya. Es un recorte de 128 px, no cuesta nada, y a cambio no existe la
	# posibilidad de que el preview y lo guardado se separen.
	var refrescar := func() -> void:
		if _src != null:
			_png = Game.png_cuadrado(_src, _zoom, _centro)
			_tex = Game.textura_de_png(_png)
		muestra.material = Game.material_cuerpo(metal.value, _tex, tinte.value)
		tinte.editable = _tex != null
		zoom.editable = _src != null
		lbl_tinte.modulate = Color(1, 1, 1) if _tex != null else Color(1, 1, 1, 0.4)
		lbl_zoom.modulate = Color(1, 1, 1) if _src != null else Color(1, 1, 1, 0.4)

	metal.value_changed.connect(func(_v: float): refrescar.call())
	tinte.value_changed.connect(func(_v: float): refrescar.call())
	picker.color_changed.connect(func(c: Color): muestra.color = c)
	zoom.value_changed.connect(func(v: float):
		_zoom = v
		refrescar.call())

	# MOVER el encuadre arrastrando. El desplazamiento va en fraccion de la imagen: se divide por
	# el zoom porque cuanto mas cerca estas, menos original abarca la muestra (y el mismo gesto
	# tiene que mover menos foto, o al ampliar se iria de las manos). El signo es negativo porque
	# arrastras la IMAGEN, no la ventana: llevar el raton a la derecha trae lo de la izquierda.
	# Game.png_cuadrado ya clampea el rect; el clamp de aqui es para que el centro no se escape a
	# valores absurdos y luego haya que arrastrar de vuelta en seco.
	muestra.gui_input.connect(func(event: InputEvent):
		if _src == null:
			return
		if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
			var rel: Vector2 = (event as InputEventMouseMotion).relative / muestra.size / _zoom
			_centro = Vector2(clampf(_centro.x - rel.x, 0.0, 1.0),
				clampf(_centro.y - rel.y, 0.0, 1.0))
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
	quitar.disabled = _tex == null   # editando puede que YA traiga imagen
	fila_img.add_child(quitar)

	var aviso_img := Label.new()
	aviso_img.add_theme_font_size_override("font_size", 11)
	aviso_img.add_theme_color_override("font_color", GRIS)
	aviso_img.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso_img.custom_minimum_size = Vector2(280, 0)
	aviso_img.text = ("Ya tiene imagen. Ajústala con «Acercar» y arrastrando la muestra." if _tex != null
		else "Opcional. Se guarda dentro de la partida (encogida), así que puedes mover o borrar el archivo original.")
	izq.add_child(aviso_img)

	quitar.pressed.connect(func():
		_png = PackedByteArray()
		_tex = null
		_src = null
		quitar.disabled = true
		tinte.value = 0.0
		zoom.value = 1.0        # deja el encuadre listo para la siguiente imagen
		_zoom = 1.0
		_centro = Vector2(0.5, 0.5)
		aviso_img.text = "Sin imagen: su cuerpo es el color de al lado."
		refrescar.call())

	poner.pressed.connect(func():
		var fd := FileDialog.new()
		fd.access = FileDialog.ACCESS_FILESYSTEM   # el disco del jugador, no res://
		fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		fd.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp,*.bmp ; Imágenes"])
		fd.use_native_dialog = true
		fd.title = "Elige la imagen del personaje"
		add_child(fd)
		# El dialogo es de usar y tirar: sin esto se irian apilando uno por cada clic en el boton.
		fd.canceled.connect(fd.queue_free)
		fd.file_selected.connect(func(ruta: String):
			fd.queue_free()
			var src: Image = Game.imagen_de_archivo(ruta)
			if src == null:
				aviso_img.text = "Esa imagen no se ha podido leer. Prueba con un PNG o un JPG."
				return
			# Entra centrada y del todo: el recorte de partida es el cuadrado mas grande que quepa.
			_src = src
			_zoom = 1.0
			_centro = Vector2(0.5, 0.5)
			zoom.set_value_no_signal(1.0)   # sin señal: ya refrescamos abajo, no hace falta dos veces
			quitar.disabled = false
			aviso_img.text = "Imagen puesta. Ajusta el encuadre con «Acercar» y arrastrando la muestra."
			refrescar.call())
		fd.popup_centered_ratio(0.7))

	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 8)
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(botones)

	var aceptar := Button.new()
	aceptar.text = texto_boton
	aceptar.pressed.connect(func():
		if _on_aceptar.is_valid():
			_on_aceptar.call(nombre.text, picker.color, float(metal.value), float(tinte.value), _png)
		queue_free())
	botones.add_child(aceptar)

	var cancelar := Button.new()
	cancelar.text = "Cancelar"
	cancelar.pressed.connect(queue_free)
	botones.add_child(cancelar)

	# Una pasada al montar: es lo que pone el material en la muestra. Sin esto, EDITANDO abririas la
	# pantalla sin la imagen ni el brillo hasta que tocaras un mando.
	refrescar.call()

	nombre.grab_focus()


# Los bytes de un PNG guardado, de vuelta a Image para poder reencuadrarlo. null si no hay imagen
# o si el PNG no se lee (una ficha con la imagen corrupta se edita igual, sin foto: que no se
# pueda tocar el aspecto seria peor que perder la imagen).
static func _imagen_de_png(png: PackedByteArray) -> Image:
	if png.is_empty():
		return null
	var img := Image.new()
	if img.load_png_from_buffer(png) != OK:
		return null
	return img
