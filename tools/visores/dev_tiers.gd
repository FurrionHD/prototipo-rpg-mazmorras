# ============================================================
#  dev_tiers.gd  --  HERRAMIENTA, no parte del juego.
#
#  La ESCALERA DEL TIER puesta a prueba: pinta celdas de verdad (CeldaObjeto) del T1 al T24 para
#  ver si el sistema aguanta lo que se le pide -- que dos tiers seguidos no se confundan, que la
#  segunda vuelta no se parezca a la primera, y que en el T20 siga diciendo algo.
#
#  Hoy el juego llega al T3. Esto existe porque la escalera se diseño para NO tener que tocarse
#  nunca mas (ver IconoItem.color_tier), y eso no se puede comprobar con los tres que hay: hay que
#  mirar los que vendran.
#
#  La fila de abajo son las MISMAS celdas sobre los ocho fondos de rareza, que es donde la muesca
#  tiene que seguir leyendose: es pequeña y va encima de un fondo de color, asi que un tono mal
#  elegido desaparece justo sobre las rarezas altas.
#
#  Doble clic en herramientas/ver_tiers.bat, o:
#    godot --path . res://tools/visores/dev_tiers.tscn
#  Guarda tools/salida/tiers.png y se cierra solo.
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
const LADO := 84.0
const TIERS := 24


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1280, 720))

	var fondo := ColorRect.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.color = MenuScaffold.FONDO
	add_child(fondo)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 20
	col.offset_top = 16
	col.add_theme_constant_override("separation", 10)
	add_child(col)

	MenuScaffold.titulo(col, "LA ESCALERA DEL TIER  ·  T1 a T%d" % TIERS, 18)
	MenuScaffold.nota(col, "El tono da la vuelta cada %d y los puntos cuentan las vueltas: el tono "
		% IconoItem.TIER_POR_VUELTA + "es la unidad y los puntos la decena.")

	# Cuatro filas de seis: cada fila es UNA vuelta entera, asi que las vueltas se comparan de un
	# vistazo mirando de arriba abajo por la misma columna (T2 sobre T8 sobre T14 sobre T20).
	for vuelta in int(ceil(float(TIERS) / float(IconoItem.TIER_POR_VUELTA))):
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 8)
		col.add_child(fila)
		for i in IconoItem.TIER_POR_VUELTA:
			var tier: int = vuelta * IconoItem.TIER_POR_VUELTA + i + 1
			if tier > TIERS:
				break
			fila.add_child(_celda(tier, 0))

	MenuScaffold.titulo(col, "LA MISMA MUESCA SOBRE LOS OCHO FONDOS DE RAREZA", 15)
	MenuScaffold.nota(col, "La muesca es pequeña y va ENCIMA del fondo de rareza: si un tono se "
		+ "pierde, se pierde aquí.")
	for tier in [1, 3, 9]:
		var fila2 := HBoxContainer.new()
		fila2.add_theme_constant_override("separation", 8)
		col.add_child(fila2)
		for rareza in Upgrades.RAREZA_COLOR.size():
			fila2.add_child(_celda(tier, rareza))

	DirAccess.make_dir_recursive_absolute(SALIDA)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ruta: String = SALIDA + "tiers.png"
	get_viewport().get_texture().get_image().save_png(ruta)
	print("[tiers] ", ProjectSettings.globalize_path(ruta))
	get_tree().quit()


# Una celda con un arma de verdad, forzada a ese tier y esa rareza. Se usa CeldaObjeto y no un
# rectangulo pintado a mano a proposito: lo que hay que juzgar es la celda REAL, con su degradado,
# sus marcas y su banda, no una maqueta que se parezca.
func _celda(tier: int, rareza: int) -> Control:
	var w: WeaponData = load("res://resources/weapons/espada_larga.tres") as WeaponData
	var copia: WeaponData = w.duplicate() as WeaponData
	Game.item_meta[copia] = {"tier": tier, "rareza": rareza, "mejoras": {},
		"durabilidad": 1.0, "banda": 0}
	var c := CeldaObjeto.new()
	c.custom_minimum_size = Vector2(LADO, LADO)
	add_child(c)          # antes de configurar: _draw necesita tamaño (ver el guardia de CeldaObjeto)
	remove_child(c)
	c.configurar(copia, "T%d" % tier, "")
	return c
