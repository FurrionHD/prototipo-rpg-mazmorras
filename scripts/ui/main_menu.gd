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

var _lista: VBoxContainer = null
var _aviso: Label = null

# Ranura pendiente de confirmar sobrescritura (0 = nada pendiente).
var _confirmar_nueva: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var fondo := ColorRect.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.06, 0.06, 0.08)
	add_child(fondo)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	center.add_child(vb)

	var tit := Label.new()
	tit.text = "JUEGUITO DEL DAWNSI"   # provisional, hasta que tenga nombre de verdad
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tit.add_theme_font_size_override("font_size", 34)
	tit.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36))
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
#  CREACION DE PERSONAJE: nombre + color, antes de empezar la partida
#  Los dos van al SaveData de ESA ranura (no al perfil): cada partida es un personaje
#  distinto. Interfaz placeholder por codigo, como el resto; el arte va al final.
# ------------------------------------------------------------
func _crear_personaje(slot: int) -> void:
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
	tit.text = "NUEVO PERSONAJE  ·  ranura %d" % slot
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tit.add_theme_font_size_override("font_size", 24)
	tit.add_theme_color_override("font_color", Color(0.95, 0.72, 0.36))
	vb.add_child(tit)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	vb.add_child(cols)

	# --- Columna izquierda: nombre + muestra del color ---
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
	izq.add_child(nombre)

	var lbl2 := Label.new()
	lbl2.text = "Así te verás"
	izq.add_child(lbl2)

	# Muestra: mismo nodo (ColorRect) y mismo material que el cuerpo de verdad, asi que lo que
	# ves aqui es EXACTAMENTE lo que te llevas al mapa, brillo incluido.
	var muestra := ColorRect.new()
	muestra.custom_minimum_size = Vector2(280, 140)
	muestra.color = COLOR_INICIAL
	izq.add_child(muestra)

	# ACABADO METALICO: de mate (0) a pulido (1). El brillo se ve moverse en la muestra
	# mientras lo subes, que es la unica forma de elegirlo con criterio.
	var lbl_met := Label.new()
	lbl_met.text = "Brillo metálico"
	izq.add_child(lbl_met)

	var metal := HSlider.new()
	metal.min_value = 0.0
	metal.max_value = 1.0
	metal.step = 0.05
	metal.value = 0.0        # de serie, mate: el brillo es una eleccion, no el defecto
	metal.custom_minimum_size = Vector2(280, 0)
	metal.value_changed.connect(func(v: float): muestra.material = Game.material_cuerpo(v))
	izq.add_child(metal)

	# --- Columna derecha: el selector con las barras R/G/B ---
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
	picker.color = COLOR_INICIAL
	picker.color_changed.connect(func(c: Color): muestra.color = c)
	der.add_child(picker)

	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 8)
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(botones)

	var empezar := Button.new()
	empezar.text = "Empezar la aventura"
	empezar.pressed.connect(func(): _empezar(slot, nombre.text, picker.color, metal.value))
	botones.add_child(empezar)

	var cancelar := Button.new()
	cancelar.text = "Cancelar"
	cancelar.pressed.connect(func(): capa.queue_free())
	botones.add_child(cancelar)

	nombre.grab_focus()


# Color de salida de la creacion (uno cualquiera, ya lo cambiara).
const COLOR_INICIAL := Color(0.45, 0.72, 1.0)


func _empezar(slot: int, nombre: String, color: Color, metalico: float) -> void:
	Game.nueva_partida(nombre, color, metalico)   # el nombre vacio lo resuelve Game (NOMBRE_POR_DEFECTO)
	Perfil.ranura_actual = slot
	Perfil.guardar(slot)   # la ranura queda ocupada desde el minuto uno, ya con nombre y color
	get_tree().change_scene_to_file(PUEBLO)


func _borrar(slot: int) -> void:
	Perfil.borrar(slot)
	_aviso.text = "Ranura %d borrada." % slot
	_confirmar_nueva = 0
	_pintar()
