# ============================================================
#  fishing_book_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  EL PESCADOR. Dos pestañas:
#
#   LIBRO  - una ficha por especie: su foto, su rareza, cuantas has sacado, tu mayor y tu menor, sus
#            coronas y de que va el bicho.
#   CEBOS  - su mostrador. Lo unico que vende, y lo unico que hace falta comprar para pescar mejor
#            (la caña se forja en la herreria). El de T2 no se enseña hasta que cae el Rey Slime,
#            igual que el mostrador T2 de la tienda.
#
#  REHECHO el 16/09/2026 con la cara del inventario, sobre la base de los talleres (taller_menu.gd):
#  los peces y los cebos en celdas, la ficha al lado y el boton de comprar en el pie. Fue el ultimo
#  menu del pueblo en migrar.
#
#  Lo que enseña el libro sale ENTERO de Game.registro_pesca, que se apunta al cobrar cada pieza. NO
#  se recalcula desde la bolsa a proposito: el pez se vende, se cocina y se pierde, y el record de la
#  lubina de 61 cm tiene que sobrevivir a todo eso.
#
#  La RAREZA tampoco se escribe: se deriva del peso de la especie en la tabla (Game.rareza_pez), y la
#  FOTO es la misma hoja que nada en el charco. Los numeros salen de los campos, no del texto.
#
#  Una especie que aun no has pescado sale en NEGRO y sin nombre: el libro es tambien la lista de lo
#  que te falta.
# ============================================================

extends "res://scripts/ui/taller_menu.gd"

const TABS := ["Libro", "Cebos"]
const TAB_ICONOS := ["libro", "cana"]
const TAB_LIBRO := 0
const TAB_CEBOS := 1

# Los cinco peldaños de rareza, con los MISMOS nombres que usa el equipo (Upgrades): un "raro"
# tiene que querer decir lo mismo en un pez que en una espada.
const RAREZAS := ["Común", "Poco común", "Raro", "Épico", "Legendario"]

# Alto de la "foto" del pez en la ficha (el ancho es el de la ficha).
const ALTO_FOTO := 150.0
# El aumento de la hoja del pez en la foto: el ancho que se busca y el tope (ver _foto).
const ANCHO_PEZ_FOTO := 220.0
const AUMENTO_FOTO := 6.0
const ANCHO_FICHA_PESCADOR := 700.0

# EL MOSTRADOR. El T2 va aparte porque lo gatea el Rey Slime (Game.tienda_t2_abierta).
const CAT_CEBOS: Array[String] = [
	"res://resources/consumables/cebo_gusano.tres",
]
const CAT_CEBOS_T2: Array[String] = [
	"res://resources/consumables/cebo_sanguijuela.tres",
]

# CUANTOS cebos vas a comprar. Es un CAMPO y no un local: las lambdas capturan los locales POR VALOR,
# y el boton de comprar leia el 1 de siempre (comprabas cuatro y te llevabas uno).
var _cuantas: int = 1


func _ready() -> void:
	add_to_group("fishing_book_menu")
	montar("Pescador", TABS, TAB_ICONOS, ANCHO_REJILLA_MIN, ANCHO_FICHA_PESCADOR)


func abrir() -> void:
	_tab = TAB_LIBRO
	abrir_taller()


func _al_cambiar_pantalla() -> void:
	_cuantas = 1


func _al_elegir_otra() -> void:
	_cuantas = 1


func _pintar() -> void:
	_titulo_seccion.text = TABS[_tab]
	contador("%d monedas" % Game.money)
	# Aqui no trabaja nadie: el pescador es un mostrador.
	pintar_artesanos("", "", "")
	if _tab == TAB_CEBOS:
		_build_cebos()
	else:
		_build_libro()


# ------------------------------------------------------------
#  PESTAÑA: LIBRO
# ------------------------------------------------------------
func _build_libro() -> void:
	stacks = Game.peces()
	var vistas: int = 0
	var piezas: Array = []
	for d in stacks:
		var md: MaterialData = d
		var f: Dictionary = Game.ficha_pesca(md.id)
		var capturas: int = int(f["capturas"])
		if capturas > 0:
			vistas += 1
		piezas.append({"item": MaterialItem.crear(md, MaterialItem.Calidad.NORMAL),
			"pie": "x%d" % capturas if capturas > 0 else "", "marca": "", "activo": true,
			"tooltip": md.nombre if capturas > 0 else "Especie sin pescar"})
	titulo_seccion("Libro  ·  %d de %d especies" % [vistas, stacks.size()])
	grid_detail(piezas, _ficha_pez, "No hay peces en el libro.")
	_ensombrecer_desconocidos()


# Las especies SIN PESCAR, en negro: la silueta se ve (el libro es la lista de lo que te falta) pero
# ni el color ni el nombre. Se hace sobre la celda ya creada, como la decoracion del pack de la tienda.
func _ensombrecer_desconocidos() -> void:
	for g in _lista.get_children():
		if not (g is GridContainer):
			continue
		var i: int = 0
		for celda in g.get_children():
			if celda is CeldaObjeto and i < stacks.size():
				var capturas: int = int(Game.ficha_pesca((stacks[i] as MaterialData).id)["capturas"])
				(celda as Control).modulate = Color.WHITE if capturas > 0 else Color(0.18, 0.2, 0.26)
			i += 1


func _ficha_pez(vb: VBoxContainer) -> void:
	var d: MaterialData = stacks[sel]
	var f: Dictionary = Game.ficha_pesca(d.id)
	var capturas: int = int(f["capturas"])
	var conocido: bool = capturas > 0
	var rareza: int = Game.rareza_pez(d)

	MenuScaffold.titulo_item(vb, d.nombre if conocido else "Especie sin pescar",
		Upgrades.rareza_color(rareza) if conocido else GRIS)
	vb.add_child(_foto(d, conocido))
	vb.add_child(HSeparator.new())
	row(vb, "Rareza", RAREZAS[clampi(rareza, 0, RAREZAS.size() - 1)], Upgrades.rareza_color(rareza))
	row(vb, "Capturas", str(capturas) if conocido else "—")
	# El GLIFO de la corona va pegado a la talla: si tu mayor es un ejemplar de corona, se ve ahi mismo.
	_fila_talla(vb, "El más grande", d, float(f["cm_max"]), conocido)
	_fila_talla(vb, "El más pequeño", d, float(f["cm_min"]), conocido)
	if conocido:
		# La horquilla de la ESPECIE, para que sepas cuanto te queda hasta el ejemplar de museo.
		row(vb, "Talla de la especie", "%.1f - %.1f cm" % [d.cm_min, d.cm_max])
		row(vb, "Valor base", "%d monedas" % d.valor_base)
		_coronas(vb, d)
	vb.add_child(HSeparator.new())
	if conocido:
		note(vb, d.descripcion)
		note(vb, "Los ejemplares grandes se pagan mejor: uno en el máximo de su especie vale el cuádruple que uno en el mínimo.")
	else:
		note(vb, "Todavía no has sacado ninguno. Búscalo en los estanques de la mazmorra.")


# Una linea de talla con SU corona al lado, si esa talla la merece (del color de su metal).
func _fila_talla(vb: VBoxContainer, etiqueta: String, d: MaterialData, cm: float, conocido: bool) -> void:
	if not conocido or cm <= 0.0:
		row(vb, etiqueta, "—")
		return
	var c: int = d.corona_de(cm)
	var g: String = MaterialData.corona_glifo(c)
	row(vb, etiqueta, "%.1f cm%s" % [cm, ("   " + g + " " + MaterialData.corona_texto(c)) if g != "" else ""],
		MaterialData.corona_color(c) if c != MaterialData.Corona.NINGUNA else AMBAR)


# LAS CUATRO CORONAS de la especie. El corte NO se enseña hasta que la corona es tuya: si el libro te
# dijera "desde 53.8 cm", la corona dejaria de ser un hallazgo y seria una lista de la compra.
func _coronas(vb: VBoxContainer, d: MaterialData) -> void:
	vb.add_child(HSeparator.new())
	MenuScaffold.titulo(vb, "CORONAS", 13)
	for c in [MaterialData.Corona.ORO, MaterialData.Corona.PLATA,
			MaterialData.Corona.MINI_PLATA, MaterialData.Corona.MINI_ORO]:
		var tengo: bool = Game.tiene_corona(d.id, c)
		row(vb, "%s %s" % [MaterialData.corona_glifo(c), MaterialData.corona_texto(c)],
			"✓  conseguida" if tengo else "—  ???", MaterialData.corona_color(c) if tengo else GRIS, 240.0)


# La "foto": LA MISMA HOJA que nada en el charco, a su talla mayor y quieta. Si aqui es un bagre con
# bigotes, bajo el agua es esa misma silueta mas oscura. Sin pescar, en silueta: el mismo dibujo
# multiplicado hasta casi negro, asi que la forma que ves antes de pescarlo es EXACTA.
func _foto(d: MaterialData, conocido: bool) -> Control:
	var marco := Panel.new()
	marco.custom_minimum_size = Vector2(0, ALTO_FOTO)
	marco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.14, 0.21)
	sb.set_corner_radius_all(8)
	marco.add_theme_stylebox_override("panel", sb)
	# Los mismos numeros con los que el charco calcula el largo (ver FishingSpot), para que las tallas
	# horneadas sean las mismas y no haya que hornear una hoja mas solo para el libro.
	var techo: float = 128.0 * 0.42
	var tallas: Array[int] = PezSprites.tallas_de(d, 0.6, 10.0, techo)
	var celda: Vector2i = PezSprites.lienzo(tallas.back())
	var pez := TextureRect.new()
	var atlas: Texture2D = PezSprites.textura(d, 0.6, 10.0, techo)
	var region := Rect2(Vector2(0.0, float(PezSprites.fila_de(d, tallas.back(), 0.6, 10.0, techo) * celda.y)),
		Vector2(celda))
	# RECORTADA AL DIBUJO: la celda de la hoja deja sitio para que el pez nade y gire, asi que a tamaño
	# de foto el pez era una raya pequeña en medio de un recuadro vacio (visto en captura).
	var img: Image = atlas.get_image()
	if img != null:
		var usado: Rect2i = img.get_region(Rect2i(region)).get_used_rect()
		if usado.size.x > 0 and usado.size.y > 0:
			region = Rect2(region.position + Vector2(usado.position), Vector2(usado.size))
	pez.texture = AtlasTexture.new()
	(pez.texture as AtlasTexture).atlas = atlas
	(pez.texture as AtlasTexture).region = region
	# AUMENTO ENTERO (pixel-art limpio), y un termino medio entre los dos extremos vistos en captura:
	# estirado a llenar el recuadro, el gobio salia hecho cuadritos del tamaño del espejo abisal; con el
	# mismo aumento para todos, el gobio era una mota. Se busca que el pez ocupe ANCHO_PEZ_FOTO y nunca se
	# pase del alto, con un tope para que el pequeño no se deshaga en cuadros. Asi el grande sigue
	# viendose mas grande, pero el pequeño se lee.
	var escala: float = minf(floorf(ANCHO_PEZ_FOTO / maxf(1.0, region.size.x)),
		floorf((ALTO_FOTO - 40.0) / maxf(1.0, region.size.y)))
	escala = clampf(escala, 1.0, AUMENTO_FOTO)
	pez.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pez.stretch_mode = TextureRect.STRETCH_SCALE
	pez.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pez.custom_minimum_size = region.size * escala
	pez.modulate = Color.WHITE if conocido else Color(0.06, 0.09, 0.14)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marco.add_child(centro)
	centro.add_child(pez)
	return marco


# ------------------------------------------------------------
#  PESTAÑA: CEBOS (el mostrador)
# ------------------------------------------------------------
func _build_cebos() -> void:
	stacks = []
	var rutas: Array[String] = CAT_CEBOS.duplicate()
	if Game.tienda_t2_abierta():
		rutas.append_array(CAT_CEBOS_T2)
	var piezas: Array = []
	for ruta in rutas:
		var base: Resource = load(ruta)
		if base == null:
			continue
		stacks.append(base)
		var c: ConsumableData = base
		var llevas: int = int(Game.consumables.get(c, 0))
		piezas.append({"item": c, "pie": "%d" % Game.precio_compra(c), "marca": "", "activo": true,
			"tooltip": "%s  ·  %d monedas%s" % [c.nombre, Game.precio_compra(c),
				"  ·  llevas %d" % llevas if llevas > 0 else ""]})
	grid_detail(piezas, _ficha_cebo, "Hoy no tiene nada en el mostrador.")


func _ficha_cebo(vb: VBoxContainer) -> void:
	var c: ConsumableData = stacks[sel]
	var precio: int = Game.precio_compra(c)
	MenuScaffold.titulo_item(vb, c.nombre, AMBAR)
	MenuScaffold.banner_item(vb, c, "", "Se pone en el estanque, con [F] sobre el agua")
	vb.add_child(HSeparator.new())
	# Igual que en el libro: el numero sale del CAMPO (resumen()), no de la descripcion.
	row(vb, "Atracción", c.resumen(0.0, 0.0), VERDE)
	row(vb, "Precio", "%d monedas" % precio, AMBAR if Game.puede_pagar(precio) else ROJO)
	row(vb, "Llevas", str(int(Game.consumables.get(c, 0))))
	vb.add_child(HSeparator.new())
	note(vb, c.descripcion)
	note(vb, "Se gasta el %d%% de las veces que cobras una pieza. Si el pez se escapa o recoges el sedal, no pagas nada."
		% int(round(Game.CEBO_GASTO * 100.0)))

	# EL PIE: cantidad (arranca en 1; el maximo es lo que te llega) y comprar.
	var pie: VBoxContainer = acciones()
	pie.add_child(HSeparator.new())
	var maximo: int = 99 if precio <= 0 else maxi(1, Game.money / precio)
	_cuantas = clampi(_cuantas, 1, maximo)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = "Cantidad"
	k.custom_minimum_size = Vector2(90, 0)
	k.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	fila.add_child(k)
	var total := Label.new()
	total.add_theme_color_override("font_color", AMBAR)
	var refrescar := func(n: int) -> void:
		total.text = "  %d monedas" % (n * precio)
	MenuScaffold.stepper(fila, _cuantas, 1, maximo,
		func(n: int) -> void:
			_cuantas = n
			refrescar.call(n))
	fila.add_child(total)
	refrescar.call(_cuantas)
	pie.add_child(fila)
	MenuScaffold.pastilla(pie, "Comprar" if Game.puede_pagar(precio) else "No te llega",
		func() -> void: _comprar(c), true, Game.puede_pagar(precio))


func _comprar(c: ConsumableData) -> void:
	var n: int = _cuantas
	if Game.comprar_consumible(c, n):
		decir("Compras %d × %s. Se pone en el estanque, con [F] sobre el agua." % [n, c.nombre])
	else:
		decir("No te llega para %d × %s." % [n, c.nombre], false)
	_cuantas = 1
	rebuild()
