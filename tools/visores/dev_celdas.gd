# ============================================================
#  dev_celdas.gd  --  HERRAMIENTA, no parte del juego.
#
#  Enseña la CELDA del inventario (CeldaObjeto) con un objeto de cada clase y de cada peldaño de
#  cada escala, todos juntos y al mismo tamaño. Es la unica forma de juzgar lo que hay que juzgar:
#  si mirando la rejilla llena se distingue lo bueno de lo corriente SIN leer nada.
#
#  Las cuatro preguntas que responde:
#    1. ¿se distinguen los 8 peldaños de rareza entre si, o los de en medio se confunden?
#    2. ¿se lee la FORMA del icono (cubo / frasco / libro / cuenco) a este tamaño?
#    3. ¿las marcas de peldaño se cuentan de un vistazo con 5 y con 8?
#    4. ¿la seleccionada canta por encima de las demas aunque todas tengan color?
#
#  Va como ESCENA y CON VENTANA (nada de --headless): los .tres dependen del autoload Game, y
#  ademas un Control no se coloca ni se dibuja sin superficie de render -- en headless la captura
#  sale en negro.
#
#  Doble clic en herramientas/ver_celdas.bat, o:
#    godot --path . res://tools/visores/dev_celdas.tscn
#  Guarda la captura en tools/salida/celdas.png y se cierra sola.
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
const LADO := 96.0      # el tamaño al que se piensa usar en el inventario
const COLUMNAS := 9     # las mismas que la rejilla de verdad

# Un material por peldaño de rango (gris -> amarillo), para ver la escala entera de un tiron.
const MATERIALES := [
	"cobre", "cobre_veteado", "cobre_profundo", "baba_venenosa", "nucleo_minotauro",
	"acero", "madera_negra", "cuero_curtido", "carbon_negro",
]
# Las tres FORMAS de consumible (frasco / libro / cuenco) y los tres tiers de frasco, que es lo que
# hay que poder distinguir sin leer: el bulto dice el tier y el color dice de que es.
const CONSUMIBLES := [
	"pocion_menor", "pocion_media", "pocion_mana_menor", "pocion_mana_media",
	"grimorio_bola_fuego", "plato_kebab_bestia", "piedra_retorno",
]


func _ready() -> void:
	# Alta a proposito: con 720 las filas de iconos de arma se salian por abajo y la captura las
	# cortaba, que es justo lo que hay que mirar.
	DisplayServer.window_set_size(Vector2i(1280, 1080))
	var fondo := ColorRect.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.color = MenuScaffold.FONDO
	add_child(fondo)

	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 18)
	add_child(margen)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margen.add_child(col)

	var piezas: Array = []
	piezas.append_array(_materiales())
	piezas.append_array(_consumibles())
	piezas.append_array(_cristales())
	piezas.append_array(_equipo())

	_rejilla(col, piezas)
	_tira_suelo(col, piezas)
	_tira_iconos(col)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(SALIDA)
	var ruta: String = SALIDA + "celdas.png"
	get_viewport().get_texture().get_image().save_png(ruta)
	print("[celdas] %d celdas -> %s" % [piezas.size(), ProjectSettings.globalize_path(ruta)])
	get_tree().quit()


# Cada pieza es {item, pie, nota}: el objeto, lo que va en la banda y lo que se escribe debajo para
# poder señalar en la captura cual es cual.
func _rejilla(col: VBoxContainer, piezas: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = COLUMNAS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	for i in piezas.size():
		var p: Dictionary = piezas[i]
		var caja := VBoxContainer.new()
		caja.add_theme_constant_override("separation", 2)
		grid.add_child(caja)
		var c := CeldaObjeto.new()
		c.custom_minimum_size = Vector2(LADO, LADO)
		# La CUARTA se deja seleccionada: es lo unico que enseña si el borde blanco canta rodeado de
		# celdas de color, que a solas siempre parece que si.
		c.button_pressed = (i == 3)
		caja.add_child(c)
		c.configurar(p["item"], String(p["pie"]))
		var l := Label.new()
		l.text = String(p["nota"])
		l.add_theme_font_size_override("font_size", 9)
		l.add_theme_color_override("font_color", MenuScaffold.GRIS)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(LADO, 0)
		caja.add_child(l)


# LOS MISMOS OBJETOS AL TAMAÑO DEL SUELO (16 px) y sin 'encajar', que es como los pinta
# drop_pickup. Va en la misma captura a proposito: el dibujo lo comparten los dos sitios, asi que
# cualquier retoque pensado para la celda de 96 px llega TAMBIEN a la mazmorra, y a 16 px un bisel
# que alli queda elegante puede comerse el objeto entero. Es la unica forma de no enterarse jugando.
#
# Se pintan a x4 (un ampliador, no un icono mas grande): a tamaño real no se puede juzgar nada en
# una captura, pero escalar el resultado conserva los pixeles que se veran de verdad.
func _tira_suelo(col: VBoxContainer, piezas: Array) -> void:
	var t := Label.new()
	t.text = "  los mismos, al tamaño del SUELO (16 px, ampliados x4)"
	t.add_theme_font_size_override("font_size", 11)
	t.add_theme_color_override("font_color", MenuScaffold.AMBAR)
	col.add_child(t)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	col.add_child(fila)
	for p in piezas:
		var c := Control.new()
		c.custom_minimum_size = Vector2(IconoItem.LADO_BASE * 4.0, IconoItem.LADO_BASE * 4.0)
		fila.add_child(c)
		var it: Resource = p["item"]
		c.draw.connect(func():
			c.draw_set_transform(Vector2(c.size.x * 0.5, c.size.y * 0.5), 0.0, Vector2(4.0, 4.0))
			IconoItem.pintar(c, Vector2.ZERO, IconoItem.LADO_BASE, it))


# LOS ICONOS DE LAS PESTAÑAS, en grande y en el mismo orden en que salen en el menu.
#
# En el inventario se ven a 34 px y ahi no hay forma de juzgarlos: la pregunta no es si son bonitos,
# es si se DISTINGUEN ENTRE SI puestos en fila -- que es como se usan. Los de arma son diez
# variaciones del mismo trazo diagonal, asi que es justo donde se rompe.
const ICONOS_TAB := [
	["bolsa", "mochila", "pocion", "mineral", "espada", "coraza"],
	["mochila", "pico", "farol"],
	["todo", "daga", "estoque", "espada_corta", "maza", "espada_larga", "mandoble", "hacha",
		"martillo", "baston", "varita", "escudo_peq", "escudo_med", "escudo_gra"],
	["todo", "casco", "coraza", "mano", "pantalon", "botas"],
]
# 96 y no 34 (el del menu): la pregunta aqui es si la FORMA esta bien dibujada, y un fallo de forma
# a 34 px se ve como "una mancha rara" sin saber por que. La primera version del farolillo salia
# igualita a un candado y a tamaño de menu no habia forma de darse cuenta.
const LADO_ICONO_VISOR := 96.0

func _tira_iconos(col: VBoxContainer) -> void:
	var t := Label.new()
	t.text = "  los iconos de las pestañas, a %d px (en el menu van a 34)" % int(LADO_ICONO_VISOR)
	t.add_theme_font_size_override("font_size", 11)
	t.add_theme_color_override("font_color", MenuScaffold.AMBAR)
	col.add_child(t)
	for grupo in ICONOS_TAB:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 6)
		col.add_child(fila)
		for nombre in grupo:
			var caja := Control.new()
			caja.custom_minimum_size = Vector2(LADO_ICONO_VISOR, LADO_ICONO_VISOR)
			fila.add_child(caja)
			var dibujo := Callable(Iconos, String(nombre))
			caja.draw.connect(func():
				dibujo.call(caja, Vector2.ZERO, LADO_ICONO_VISOR, Color(0.90, 0.92, 0.96)))


func _materiales() -> Array:
	var out: Array = []
	for id in MATERIALES:
		var d: MaterialData = load("res://resources/materials/%s.tres" % id) as MaterialData
		if d == null:
			continue
		var it := MaterialItem.new()
		it.data = d
		it.calidad = MaterialItem.Calidad.NORMAL
		out.append({"item": it, "pie": "x%d" % (randi() % 400 + 1),
			"nota": "%s\nrango %d" % [d.nombre, d.rango_color()]})
	return out


func _consumibles() -> Array:
	var out: Array = []
	for id in CONSUMIBLES:
		var c: ConsumableData = load("res://resources/consumables/%s.tres" % id) as ConsumableData
		if c == null:
			continue
		out.append({"item": c, "pie": "x%d" % (randi() % 20 + 1),
			"nota": "%s\ntier %d" % [c.nombre, c.tier]})
	return out


func _cristales() -> Array:
	var out: Array = []
	for cal in [Cristal.Calidad.INTACTO, Cristal.Calidad.NORMAL, Cristal.Calidad.DANADO]:
		var cr := Cristal.new()
		cr.categoria = 3
		cr.calidad = cal
		out.append({"item": cr, "pie": "x7", "nota": "cristal\n%s" % cr.calidad_texto()})
	return out


# LOS 8 PELDAÑOS DE RAREZA, que es la escala mas larga y la que peor lo tiene: si dos colores
# vecinos se confunden, es aqui. Se le escribe la meta a mano (Game.meta_de devuelve COMUN para
# cualquier pieza que no este registrada, asi que sin esto saldrian las ocho grises).
func _equipo() -> Array:
	var arma: WeaponData = load("res://resources/weapons/espada_corta.tres") as WeaponData
	if arma == null:
		return []
	var out: Array = []
	for r in Upgrades.RAREZA_COLOR.size():
		var copia: WeaponData = arma.duplicate() as WeaponData
		Game.item_meta[copia] = {"tier": 1, "rareza": r, "mejoras": {}, "durabilidad": 1.0, "banda": 0}
		out.append({"item": copia, "pie": "+%d" % r,
			"nota": "%s\n%s" % [copia.nombre, Upgrades.RAREZA_NOMBRE[r]]})
	return out
