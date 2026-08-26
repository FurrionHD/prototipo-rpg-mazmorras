# ============================================================
#  creador_personaje.gd
#  La pantalla de "ponle cara a este personaje": nombre, imagen propia con su encuadre, pelo y ropa.
#  Es una CAPA a pantalla completa que se monta sobre quien la llame.
#
#  Vivia dentro de main_menu.gd, atada a las ranuras de guardado. Ahora la usan TRES sitios:
#    - el menu principal, al crear una ranura;
#    - la TABERNA, al contratar a un companero (que se crea igual que te creaste tu);
#    - el HOGAR, para cambiarle el aspecto a cualquiera del grupo.
#  Por eso se saco aqui, y ademas asi el companero se crea EXACTAMENTE con la misma pantalla que el
#  jugador: lo que ves al elegir es lo que se ve en el mapa, en los dos casos.
#
#  VA POR FASES, Y SE SALTA ENTRE ELLAS EN CUALQUIER ORDEN. No es un asistente de "siguiente,
#  siguiente": son cuatro pestañas y se pincha la que sea. El motivo es de sitio -- desde que cada
#  pieza lleva su propio color hacen falta varios ColorPicker, y en esta pantalla no cabia ni el
#  primero (ya se le quitaron el cuadrado HSV, el cuentagotas, el hex y las paletas para que
#  entrara). Partirla en fases es lo que deja sitio para la VISTA PREVIA, que es lo que de verdad
#  cambia esta pantalla: antes elegias mirando un cuadrado de color.
#
#  DOS MODOS. Con 'previo["personaje"] = false' sale la pantalla simple de siempre (nombre, color e
#  imagen, sin fases ni muñeco): la usa multi_menu para bautizar un MUNDO compartido, donde un
#  personaje girando no significaria nada.
#
#  LOS DOS MANDOS VIEJOS SON DE LA CARA. 'brillo metalico' y 'color sobre la imagen' nacieron cuando
#  el cuerpo era un ColorRect y teñirlo pintaba al personaje entero; desde que hay capas, cada pieza
#  trae su color y su acabado, y estos dos se quedan con lo unico que no es una capa horneada: el
#  PNG que te pones de cara. Por eso viven en la fase "Cara" y en ninguna otra.
#
#  Quien la abre no hereda nada: llama a abrir() y recibe el resultado por el Callable.
# ============================================================

extends Control
class_name CreadorPersonaje

const AMBAR := Color(0.95, 0.72, 0.36)
const GRIS := Color(0.6, 0.63, 0.7)
# Color de salida de la creacion (uno cualquiera, ya lo cambiara).
const COLOR_INICIAL := Color(0.45, 0.72, 1.0)
const PELO_INICIAL := Color(0.24, 0.15, 0.10)

# --- Estado de la IMAGEN mientras se encuadra (ver png_cuadrado) ---
# _png es lo que se va a guardar; _src es la foto ORIGINAL ya encogida, que se queda a mano para
# poder reencuadrar sin volver a leer el fichero. Son variables de la instancia (y no locales del
# montaje) porque las tocan varios lambdas: el slider de zoom, el arrastre y el boton de quitar.
var _png: PackedByteArray = PackedByteArray()
var _tex: Texture2D = null
var _src: Image = null
var _zoom: float = 1.0
var _centro: Vector2 = Vector2(0.5, 0.5)

# --- El aspecto que se esta montando ---
var _metal: float = 0.0
var _tinte: float = 0.0
# Las piezas, en el formato de PersonajeData.aspecto: {"pelo": {"modelo","color","metal"}, ...}
var _piezas: Dictionary = {}
# El personaje de mentira que se le enseña a la vista previa. Es un PersonajeData de verdad para que
# la vista no tenga que saber nada de esta pantalla: se le pasa una persona, como en el juego.
var _pj: PersonajeData = null
var _vista: VistaMuneco = null
var _nombre: LineEdit = null

var _on_aceptar: Callable


# Monta la pantalla sobre 'padre' y la devuelve.
#   previo      = {"nombre","color","metalico","color_alpha","imagen","piezas"}
#                 (vacio = personaje en blanco). Ademas:
#                 "personaje": false  -> pantalla simple, sin fases ni muñeco (bautizar un mundo)
#                 "etiqueta_nombre" / "nombre_defecto" / "extras"
#   on_aceptar  = func(nombre: String, aspecto: Dictionary)
#                 'aspecto' es el de PersonajeData.aspecto_completo: color, metalico, imagen,
#                 color_alpha y piezas. UN dict y no cinco argumentos, porque cada pieza nueva
#                 obligaba a tocar las siete firmas por las que pasa esto.
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

	var es_personaje: bool = bool(previo.get("personaje", true))
	_png = previo.get("imagen", PackedByteArray())
	_tex = Game.textura_de_png(_png)
	# Lo guardado ya es un cuadrado, asi que entra de fuente tal cual (zoom 1, centrada). Se puede
	# reencuadrar, pero sobre lo ya recortado: la foto original no viaja en la partida.
	_src = _imagen_de_png(_png)
	_zoom = 1.0
	_centro = Vector2(0.5, 0.5)
	_metal = float(previo.get("metalico", 0.0))
	_tinte = float(previo.get("color_alpha", 0.0))

	# El personaje de la vista previa, con lo que traiga el previo. Se monta SIEMPRE (aunque no haya
	# muñeco) porque es tambien donde vive el aspecto mientras se toquetea.
	_pj = PersonajeData.new()
	_pj.color = previo.get("color", COLOR_INICIAL)
	_pj.aspecto = PersonajeData.aspecto_nuevo(_pj.color)
	if not (previo.get("piezas", {}) as Dictionary).is_empty():
		_pj.aplicar_aspecto({"piezas": previo["piezas"]})
	elif not previo.has("color"):
		_pj.poner_pieza("pelo", "corto", PELO_INICIAL)
	_piezas = _pj.aspecto

	var fondo := ColorRect.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.04, 0.04, 0.06, 0.96)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP   # no dejar pasar clics a lo de debajo
	add_child(fondo)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

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

	# --- Columna izquierda: la vista previa, FIJA en todas las fases ---
	# Es la razon de partir la pantalla: se elige una silueta, y una silueta no se juzga quieta.
	if es_personaje:
		var izq := VBoxContainer.new()
		izq.add_theme_constant_override("separation", 6)
		cols.add_child(izq)
		var lbl_v := Label.new()
		lbl_v.text = "Así se verá"
		izq.add_child(lbl_v)
		_vista = VistaMuneco.new()
		izq.add_child(_vista)

	# --- Columna derecha: las pestañas y el contenido de la fase abierta ---
	var der := VBoxContainer.new()
	der.add_theme_constant_override("separation", 8)
	der.custom_minimum_size = Vector2(320, 0)
	cols.add_child(der)

	var fases: Array = []
	if es_personaje:
		fases = [
			{"n": "Quién es", "c": _fase_quien(previo)},
			{"n": "Cara", "c": _fase_cara()},
			{"n": "Pelo", "c": _fase_pieza("pelo")},
			{"n": "Ropa", "c": _fase_ropa()},
		]
	else:
		fases = [{"n": "", "c": _fase_simple(previo)}]

	if fases.size() > 1:
		var pest := HBoxContainer.new()
		pest.add_theme_constant_override("separation", 4)
		der.add_child(pest)
		var botones: Array[Button] = []
		for i in fases.size():
			var b := Button.new()
			b.text = String(fases[i]["n"])
			b.toggle_mode = true
			b.button_pressed = i == 0
			botones.append(b)
			pest.add_child(b)
		for i in fases.size():
			var idx: int = i
			botones[i].pressed.connect(func():
				for j in fases.size():
					botones[j].button_pressed = j == idx
					(fases[j]["c"] as Control).visible = j == idx)

	for i in fases.size():
		var c: Control = fases[i]["c"]
		c.visible = i == 0
		der.add_child(c)

	var botonera := HBoxContainer.new()
	botonera.add_theme_constant_override("separation", 8)
	botonera.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(botonera)

	var aceptar := Button.new()
	aceptar.text = texto_boton
	aceptar.pressed.connect(func():
		if _on_aceptar.is_valid():
			_on_aceptar.call(_nombre.text, _aspecto())
		queue_free())
	botonera.add_child(aceptar)

	# BOTONES DE MAS que pone quien abre la pantalla. Nacio para el "Importar personaje" de los mundos
	# compartidos: alli crear uno nuevo y traerse uno hecho son la misma decision, asi que el boton
	# tiene que estar AQUI y no en un panel previo que te obligue a elegir antes de ver nada.
	#   previo["extras"] = [{"texto": String, "fn": Callable}]
	# A la funcion se le pasa ESTA pantalla, para que decida ella si cerrarla: si lo que abre se puede
	# cancelar (como la lista de partidas), el creador tiene que seguir vivo detras.
	for ex in previo.get("extras", []):
		var b2 := Button.new()
		b2.text = String((ex as Dictionary).get("texto", "..."))
		var fn: Callable = (ex as Dictionary).get("fn", Callable())
		if fn.is_valid():
			b2.pressed.connect(func(): fn.call(self))
		botonera.add_child(b2)

	var cancelar := Button.new()
	cancelar.text = "Cancelar"
	cancelar.pressed.connect(queue_free)
	botonera.add_child(cancelar)

	_refrescar()
	_nombre.grab_focus()


# Lo que se devuelve al aceptar: el aspecto ENTERO en el formato de PersonajeData.
func _aspecto() -> Dictionary:
	var d: Dictionary = _pj.aspecto_completo()
	d["metalico"] = _metal
	d["color_alpha"] = _tinte
	d["imagen"] = _png
	return d


# ============================================================
#  LAS FASES
# ============================================================
func _fase_quien(previo: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	# Esta pantalla no siempre bautiza a una persona: tambien se usa para ponerle nombre e icono a un
	# MUNDO compartido (ver multi_menu.gd), y ahi "¿Como se llama?" con «Aventurero» debajo no dice
	# nada. Quien la abre puede pasar su propia etiqueta y su propio nombre por defecto.
	var lbl := Label.new()
	lbl.text = str(previo.get("etiqueta_nombre", "¿Cómo se llama?"))
	v.add_child(lbl)
	_nombre = LineEdit.new()
	_nombre.placeholder_text = str(previo.get("nombre_defecto", Game.NOMBRE_POR_DEFECTO))
	_nombre.max_length = 16
	_nombre.custom_minimum_size = Vector2(280, 0)
	_nombre.text = str(previo.get("nombre", ""))
	v.add_child(_nombre)
	return v


# LA CARA: la imagen y los dos mandos que solo le afectan a ella.
func _fase_cara() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(_bloque_imagen(true))
	return v


# UNA PIEZA que se elige: los modelos que hay y su color. Vale para el pelo y para cada prenda,
# porque los tres son la misma decision.
func _fase_pieza(pieza: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(_selector_modelo(pieza))
	v.add_child(_selector_color(pieza))
	return v


# LA ROPA son DOS piezas y por tanto dos modelos, pero UN SOLO ColorPicker: dos no caben, y ademas
# tener dos selectores de color abiertos a la vez invita a compararlos en vez de mirar al personaje.
# Se elige que prenda se esta pintando con los dos botones de arriba del picker.
func _fase_ropa() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(_selector_modelo("torso"))
	v.add_child(_selector_modelo("piernas"))

	var cual := HBoxContainer.new()
	cual.add_theme_constant_override("separation", 4)
	var lbl := Label.new()
	lbl.text = "Color de:"
	cual.add_child(lbl)
	v.add_child(cual)

	var picker := _selector_color("torso")
	v.add_child(picker)

	var b_torso := Button.new()
	b_torso.text = "la camisa"
	b_torso.toggle_mode = true
	b_torso.button_pressed = true
	var b_piernas := Button.new()
	b_piernas.text = "el pantalón"
	b_piernas.toggle_mode = true
	cual.add_child(b_torso)
	cual.add_child(b_piernas)
	b_torso.pressed.connect(func():
		b_torso.button_pressed = true
		b_piernas.button_pressed = false
		_apuntar_picker(picker, "torso"))
	b_piernas.pressed.connect(func():
		b_piernas.button_pressed = true
		b_torso.button_pressed = false
		_apuntar_picker(picker, "piernas"))
	return v


# LA PANTALLA SIMPLE: nombre, color e imagen, sin fases ni muñeco. Es la de bautizar un MUNDO.
func _fase_simple(previo: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(_fase_quien(previo))
	v.add_child(_bloque_imagen(true))
	var lbl := Label.new()
	lbl.text = "Su color"
	v.add_child(lbl)
	var picker := _picker()
	picker.color = _pj.color
	picker.color_changed.connect(func(c: Color):
		_pj.color = c
		_refrescar())
	v.add_child(picker)
	return v


# ============================================================
#  LOS LADRILLOS
# ============================================================
# Los botones de modelo de una pieza, mas el "no llevar nada". Salen del CATALOGO, no de una lista
# escrita aqui: el dia que se añada un peinado tiene que aparecer solo.
func _selector_modelo(pieza: String) -> Control:
	var cat: Dictionary = JugadorSprites.CATALOGO.get(pieza, {})
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var lbl := Label.new()
	lbl.text = String(cat.get("titulo", pieza))
	v.add_child(lbl)

	var fila := HFlowContainer.new()
	v.add_child(fila)
	var opciones: Array = []
	for m in (cat.get("modelos", {}) as Dictionary):
		opciones.append({"m": String(m), "n": String(cat["modelos"][m]["nombre"])})
	opciones.append({"m": "", "n": String(cat.get("sin_nada", "Sin nada"))})

	var botones: Array[Button] = []
	for o in opciones:
		var b := Button.new()
		b.text = String(o["n"])
		b.toggle_mode = true
		b.button_pressed = String(o["m"]) == String(_pj.pieza(pieza)["modelo"])
		fila.add_child(b)
		botones.append(b)
	for i in opciones.size():
		var modelo: String = String(opciones[i]["m"])
		botones[i].pressed.connect(func():
			for j in botones.size():
				botones[j].button_pressed = j == i
			var p: Dictionary = _pj.pieza(pieza)
			_pj.poner_pieza(pieza, modelo, p["color"], p["metal"])
			_refrescar())
	return v


# El ColorPicker de una pieza. Va SIN el cuadrado HSV ni el resto de adornos: con todo eso no cabe
# en pantalla, y aqui lo que se elige se juzga en el muñeco de al lado, no en el selector.
func _selector_color(pieza: String) -> ColorPicker:
	var p := _picker()
	p.set_meta("pieza", pieza)
	p.color = _pj.pieza(pieza)["color"]
	p.color_changed.connect(func(c: Color):
		var q: Dictionary = _pj.pieza(String(p.get_meta("pieza")))
		_pj.poner_pieza(String(p.get_meta("pieza")), String(q["modelo"]), c, float(q["metal"]))
		_refrescar())
	return p


# Apunta un picker ya montado a OTRA pieza. Es lo que hace que un solo selector valga para la camisa
# y para el pantalon: la pieza va en un meta, asi que la lambda de arriba sigue valiendo sin
# reconstruir nada.
#
# El orden importa: PRIMERO el meta y luego el color. Al reves, escribir el color mientras el picker
# todavia apunta a la prenda anterior le pintaria el pantalon del color de la camisa.
func _apuntar_picker(p: ColorPicker, pieza: String) -> void:
	p.set_meta("pieza", pieza)
	p.color = _pj.pieza(pieza)["color"]


func _picker() -> ColorPicker:
	var picker := ColorPicker.new()
	picker.color_mode = ColorPicker.MODE_RGB   # barras R/G/B
	picker.edit_alpha = false                  # translucido no: eres un cuerpo, no un fantasma
	picker.picker_shape = ColorPicker.SHAPE_NONE   # fuera el cuadrado HSV (lo mas alto)
	picker.sampler_visible = false             # fuera el cuentagotas de pantalla
	picker.hex_visible = false                 # fuera el campo Hex
	picker.presets_visible = false             # fuera las paletas / "Swatches"
	picker.can_add_swatches = false
	return picker


# LA IMAGEN y su encuadre. Es el bloque que ya existia, tal cual: la muestra cuadrada donde se
# arrastra para recolocar la foto, el zoom, y los dos mandos que barnizan y tiñen ESA imagen.
#
# LA MUESTRA SIGUE SIENDO UN ColorRect y no el muñeco: aqui se esta ENCUADRANDO una foto, y para eso
# hace falta verla entera y grande. Como se le queda en la cabeza se ve al lado, en la vista previa.
func _bloque_imagen(con_mandos: bool) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)

	var lbl2 := Label.new()
	lbl2.text = "Tu imagen"
	v.add_child(lbl2)

	# OJO con el SHRINK_CENTER: un Control dentro de un VBoxContainer se estira a lo ANCHO de la
	# columna, y custom_minimum_size solo pone un minimo -> sin esto la muestra sale rectangular por
	# mucho que pidas un cuadrado.
	var muestra := ColorRect.new()
	muestra.custom_minimum_size = Vector2(160, 160)
	muestra.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	muestra.color = _pj.color
	v.add_child(muestra)

	# ENCUADRE: cuanto se acerca el recorte. Mover se hace ARRASTRANDO sobre la muestra (el aviso de
	# abajo lo dice): dos sliders mas de X/Y en una pantalla que ya va justa de alto seria peor, y
	# arrastrar la propia imagen es lo que espera cualquiera.
	var lbl_zoom := Label.new()
	lbl_zoom.text = "Acercar la imagen"
	v.add_child(lbl_zoom)

	var zoom := HSlider.new()
	zoom.min_value = 1.0    # 1 = el cuadrado mas grande que quepa en la foto
	zoom.max_value = 3.0
	zoom.step = 0.05
	zoom.value = 1.0
	zoom.custom_minimum_size = Vector2(280, 0)
	zoom.editable = _src != null   # sin imagen no hay nada que encuadrar
	v.add_child(zoom)

	var metal: HSlider = null
	var tinte: HSlider = null
	var lbl_tinte: Label = null
	if con_mandos:
		# ACABADO METALICO de TU IMAGEN: de mate (0) a pulido (1). El brillo se ve moverse en la
		# muestra mientras lo subes, que es la unica forma de elegirlo con criterio.
		var lbl_met := Label.new()
		lbl_met.text = "Brillo metálico"
		v.add_child(lbl_met)
		metal = HSlider.new()
		metal.min_value = 0.0
		metal.max_value = 1.0
		metal.step = 0.05
		metal.value = _metal
		metal.custom_minimum_size = Vector2(280, 0)
		v.add_child(metal)

		# TINTE: cuanto se ve el color POR ENCIMA de la imagen. Solo tiene sentido con imagen, asi
		# que se enseña apagado hasta que pongas una.
		lbl_tinte = Label.new()
		lbl_tinte.text = "Color sobre la imagen"
		v.add_child(lbl_tinte)
		tinte = HSlider.new()
		tinte.min_value = 0.0
		tinte.max_value = 1.0
		tinte.step = 0.05
		tinte.value = _tinte
		tinte.custom_minimum_size = Vector2(280, 0)
		tinte.editable = _tex != null
		v.add_child(tinte)

	var aviso_img := Label.new()
	aviso_img.add_theme_font_size_override("font_size", 11)
	aviso_img.add_theme_color_override("font_color", GRIS)
	aviso_img.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso_img.custom_minimum_size = Vector2(280, 0)
	aviso_img.text = ("Ya tiene imagen. Ajústala con «Acercar» y arrastrando la muestra." if _tex != null
		else "Opcional. Se guarda dentro de la partida (encogida), así que puedes mover o borrar el archivo original.")

	# Repinta la muestra con lo que haya AHORA en los mandos.
	#
	# El RECORTE se rehace aqui, en cada toque: la muestra enseña el _png que se va a guardar, no una
	# aproximacion suya. Es un recorte de 128 px, no cuesta nada, y a cambio no existe la posibilidad
	# de que el preview y lo guardado se separen.
	var refrescar := func() -> void:
		if _src != null:
			_png = Game.png_cuadrado(_src, _zoom, _centro)
			_tex = Game.textura_de_png(_png)
		if metal != null:
			_metal = float(metal.value)
		if tinte != null:
			_tinte = float(tinte.value)
			tinte.editable = _tex != null
			lbl_tinte.modulate = Color(1, 1, 1) if _tex != null else Color(1, 1, 1, 0.4)
		# material_aspecto y NO material_cuerpo: aqui _tex null significa "este todavia no tiene
		# imagen", y material_cuerpo lo interpretaria como "usa la del lider" -- que es justo lo que
		# hacia que al contratar a alguien nuevo la muestra saliera con la cara del anterior.
		muestra.material = Game.material_aspecto(_metal, _tex, _tinte)
		muestra.color = _pj.color
		zoom.editable = _src != null
		lbl_zoom.modulate = Color(1, 1, 1) if _src != null else Color(1, 1, 1, 0.4)
		_refrescar()

	if metal != null:
		metal.value_changed.connect(func(_x: float): refrescar.call())
	if tinte != null:
		tinte.value_changed.connect(func(_x: float): refrescar.call())
	zoom.value_changed.connect(func(x: float):
		_zoom = x
		refrescar.call())

	# MOVER el encuadre arrastrando. El desplazamiento va en fraccion de la imagen: se divide por el
	# zoom porque cuanto mas cerca estas, menos original abarca la muestra (y el mismo gesto tiene que
	# mover menos foto, o al ampliar se iria de las manos). El signo es negativo porque arrastras la
	# IMAGEN, no la ventana: llevar el raton a la derecha trae lo de la izquierda.
	muestra.gui_input.connect(func(event: InputEvent):
		if _src == null:
			return
		if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
			var rel: Vector2 = (event as InputEventMouseMotion).relative / muestra.size / _zoom
			_centro = Vector2(clampf(_centro.x - rel.x, 0.0, 1.0),
				clampf(_centro.y - rel.y, 0.0, 1.0))
			refrescar.call())

	var fila_img := HBoxContainer.new()
	fila_img.add_theme_constant_override("separation", 8)
	v.add_child(fila_img)

	var poner := Button.new()
	poner.text = "Poner una imagen..."
	fila_img.add_child(poner)

	var quitar := Button.new()
	quitar.text = "Quitar"
	quitar.disabled = _tex == null   # editando puede que YA traiga imagen
	fila_img.add_child(quitar)

	v.add_child(aviso_img)

	quitar.pressed.connect(func():
		_png = PackedByteArray()
		_tex = null
		_src = null
		quitar.disabled = true
		if tinte != null:
			tinte.value = 0.0
		zoom.value = 1.0        # deja el encuadre listo para la siguiente imagen
		_zoom = 1.0
		_centro = Vector2(0.5, 0.5)
		aviso_img.text = "Sin imagen: se le ve la cara del color de su piel."
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

	refrescar.call()
	return v


# Pasa a la vista previa lo que hay ahora. Se llama en cada toque: si solo ha cambiado un color, el
# muñeco no reconstruye nada (ver MunecoJugador.montar).
func _refrescar() -> void:
	if _pj == null:
		return
	# TU COLOR ES EL DE LA CAMISA. Se elegia aparte, en un selector propio, y desde que la ropa lleva
	# el suyo ese selector estaba eligiendo un color que no se veia en ninguna parte -- la piel no se
	# tiñe. Sigue haciendo falta (es el cuerpo de respaldo si el dibujo no carga, y el color con el
	# que te ve el compañero en su mapa), asi que se deriva en vez de preguntarse.
	var torso: Dictionary = _pj.pieza("torso")
	if String(torso["modelo"]) != "":
		_pj.color = torso["color"]
	_pj.set_imagen(_png)
	if _vista != null:
		_vista.mostrar(_pj)


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
