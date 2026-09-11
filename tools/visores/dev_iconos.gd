# ============================================================
#  dev_iconos.gd  --  HERRAMIENTA, no parte del juego.
#
#  Enseña los DIBUJOS DE LOS OBJETOS (scripts/ui/sprites_objeto.gd) todos juntos: cada material en su
#  celda de verdad (CeldaObjeto), los estados de calidad uno al lado del otro, la escala de cristales
#  T1..T10 (y un T11 y un T21 para ver que el color da la vuelta), y abajo los mismos al tamaño del
#  SUELO (16 px, ampliados x3), porque el dibujo es el mismo en los dos sitios.
#
#  Va como ESCENA y CON VENTANA: los .tres dependen del autoload Game (un script suelto cuelga sin
#  decir nada) y en headless la captura sale en negro.
#
#  Doble clic en herramientas/ver_iconos.bat. Guarda tools/salida/iconos.png y se cierra sola.
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
const LADO := 68.0
const COLUMNAS := 17
const MATS := "res://resources/materials/"


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 1080))
	var fondo := ColorRect.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.color = MenuScaffold.FONDO
	add_child(fondo)
	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for l in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + l, 12)
	add_child(margen)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margen.add_child(col)

	var items: Array = []
	items.append_array(_por_tipo(MaterialData.Tipo.MINERAL))
	# LOS ESTADOS, en fila: intacto, normal, dañado, roto y puro, de un mineral y de un lingote.
	for id in ["cobre", "lingote_hierro_negro", "cuero_simple"]:
		for c in [MaterialItem.Calidad.INTACTO, MaterialItem.Calidad.NORMAL,
				MaterialItem.Calidad.DANADO, MaterialItem.Calidad.ROTO, MaterialItem.Calidad.PURO]:
			items.append(MaterialItem.crear(load(MATS + id + ".tres"), c))
	items.append_array(_por_tipo(MaterialData.Tipo.LINGOTE))
	items.append_array(_por_tipo(MaterialData.Tipo.MADERA))
	items.append_array(_por_tipo(MaterialData.Tipo.TABLON))
	items.append_array(_por_tipo(MaterialData.Tipo.CUERO))
	items.append_array(_por_tipo(MaterialData.Tipo.NUCLEO))
	items.append_array(_por_tipo(MaterialData.Tipo.BABA))
	items.append_array(_por_tipo(MaterialData.Tipo.PLANTA))
	items.append_array(_por_tipo(MaterialData.Tipo.COMBUSTIBLE))
	items.append_array(_por_tipo(MaterialData.Tipo.CARNE))
	items.append_array(_por_tipo(MaterialData.Tipo.PESCADO))
	items.append_array(_por_tipo(MaterialData.Tipo.DESPENSA))
	for r in ["res://resources/consumables/grimorio_bola_fuego.tres",
			"res://resources/consumables/grimorio_tormenta.tres"]:
		items.append(load(r))
	for f in _ficheros("res://resources/consumables/tochos/").slice(0, 4):
		items.append(load(f))
	items.append(load("res://resources/backpacks/mochila_basica.tres"))
	# LAS POCIONES: T1 y T2 de vida y mana en sus cuatro +N, y los NUEVE frascos (tiers futuros).
	for base in ["pocion_menor", "pocion_media", "pocion_mana_menor", "pocion_mana_media"]:
		for n in ["", "_1", "_2", "_3"]:
			items.append(load("res://resources/consumables/%s%s.tres" % [base, n]))
	for t in range(3, 10):
		var pf: ConsumableData = (load("res://resources/consumables/pocion_media_3.tres") as ConsumableData).duplicate()
		pf.tier = t
		items.append(pf)
	items.append(load("res://resources/consumables/antidoto.tres"))
	for r in ["piedra_retorno", "piedra_retorno_t2", "cebo_gusano", "cebo_sanguijuela"]:
		items.append(load("res://resources/consumables/%s.tres" % r))
	# LAS HERRAMIENTAS, y el farolillo en sus tres tiers (cada uno con su aspecto).
	for f in _ficheros("res://resources/tools/"):
		items.append(load(f))
	for t in [2, 3]:
		var far: Resource = (load("res://resources/tools/farolillo_basico.tres") as Resource).duplicate()
		Game.meta_de(far)["tier"] = t
		items.append(far)
	# LOS CRISTALES: T1..T10 normales, luego los estados de T1, T5 y T10, y un T11 y un T21.
	for t in range(1, 11):
		items.append(_cristal(t, Cristal.Calidad.NORMAL))
	for t in [1, 5, 10]:
		for c in [Cristal.Calidad.INTACTO, Cristal.Calidad.DANADO, Cristal.Calidad.ROTO]:
			items.append(_cristal(t, c))
	items.append(_cristal(11, Cristal.Calidad.NORMAL))
	items.append(_cristal(15, Cristal.Calidad.NORMAL))
	items.append(_cristal(21, Cristal.Calidad.NORMAL))

	var grid := GridContainer.new()
	grid.columns = COLUMNAS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	col.add_child(grid)
	for it in items:
		var c := CeldaObjeto.new()
		c.custom_minimum_size = Vector2(LADO, LADO)
		c.tooltip_text = str(it)
		grid.add_child(c)
		c.configurar(it, "", "", 0)

	# EL SUELO: los mismos a 16 px, ampliados x3 (un Node2D escalado: el dibujo son rectangulos y
	# ampliarlos asi no los emborrona).
	var tira := Control.new()
	tira.custom_minimum_size = Vector2(0, 16 * 3 * 3 + 20)
	col.add_child(tira)
	var suelo := Node2D.new()
	suelo.scale = Vector2(3, 3)
	suelo.position = Vector2(4, 4)
	tira.add_child(suelo)
	suelo.draw.connect(func() -> void:
		for i in items.size():
			var x: int = i % 26
			var y: int = i / 26
			suelo.draw_rect(Rect2(x * 16.5, y * 18.0, 16, 16), Color(0.16, 0.15, 0.14))
			IconoItem.pintar(suelo, Vector2(x * 16.5 + 8.0, y * 18.0 + 8.0), 16.0, items[i]))
	suelo.queue_redraw()

	var fallos: int = 0
	for it in items:
		if it == null:
			fallos += 1
	print("[iconos] %d objetos (%d sin cargar)" % [items.size(), fallos])
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(SALIDA)
	var ruta: String = SALIDA + "iconos.png"
	get_viewport().get_texture().get_image().save_png(ruta)
	print("[iconos] -> %s" % ProjectSettings.globalize_path(ruta))
	get_tree().quit()


func _por_tipo(tipo: int) -> Array:
	var out: Array = []
	for f in _ficheros(MATS):
		var d := load(f) as MaterialData
		if d != null and int(d.tipo) == tipo:
			out.append(MaterialItem.crear(d, MaterialItem.Calidad.INTACTO))
	return out


func _ficheros(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".tres"):
			out.append(dir + f)
	out.sort()
	return out


func _cristal(cat: int, cal: int) -> Cristal:
	var c := Cristal.new()
	c.categoria = cat
	c.calidad = cal
	return c
