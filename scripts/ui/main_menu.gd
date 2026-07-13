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
	tit.text = "LA MAZMORRA"
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

	Game.nueva_partida()
	Perfil.ranura_actual = slot
	Perfil.guardar(slot)   # la ranura queda ocupada desde el minuto uno
	get_tree().change_scene_to_file(PUEBLO)


func _borrar(slot: int) -> void:
	Perfil.borrar(slot)
	_aviso.text = "Ranura %d borrada." % slot
	_confirmar_nueva = 0
	_pintar()
