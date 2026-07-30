# ============================================================
#  fishing_book_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  EL LIBRO DEL PESCADOR. Una ficha por especie: su silueta, su rareza, cuantas has sacado, tu
#  mayor y tu menor, y de que va el bicho.
#
#  Lo que enseña sale ENTERO de Game.registro_pesca, que se apunta al cobrar cada pieza. NO se
#  recalcula desde la bolsa a proposito: el pez se vende, se cocina y se pierde, y el record de la
#  lubina de 61 cm tiene que sobrevivir a todo eso.
#
#  La RAREZA tampoco se escribe: se deriva del peso de la especie en la tabla (Game.rareza_pez), y
#  la SILUETA se dibuja con las mismas proporciones (esbeltez) con las que nada en el charco. Los
#  dos son la misma norma de siempre: los numeros salen de los campos, no del texto.
#
#  Una especie que aun no has pescado sale en NEGRO y con guiones: el libro es tambien la lista de
#  lo que te falta.
# ============================================================

extends CanvasLayer

var _root: Control = null
var _header: VBoxContainer = null
var _content: VBoxContainer = null
var _lista: VBoxContainer = null
var _sel: int = 0
var _peces: Array = []

const AMBAR := Color(0.95, 0.72, 0.36)
const GRIS := Color(0.6, 0.63, 0.7)
# Los cinco peldaños de rareza, con los MISMOS nombres que usa el equipo (Upgrades): un "raro"
# tiene que querer decir lo mismo en un pez que en una espada.
const RAREZAS := ["Común", "Poco común", "Raro", "Épico", "Legendario"]

# Tamaño del recuadro de la "foto" y cuanto de el ocupa el pez mas largo de la especie.
const FOTO := Vector2(260, 120)


func _ready() -> void:
	layer = 91
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para con el menu abierto
	add_to_group("fishing_book_menu")

	var m: Dictionary = MenuScaffold.construir(self, "PESCADOR",
		"Lleva la cuenta de lo que sacas de los estanques de ahí abajo. No compra ni vende: apunta.",
		_cerrar)
	_root = m["root"]
	_header = m["header"]
	_content = m["content"]
	_lista = m["lista"]


func abrir() -> void:
	if Game._active_layer != null or Game.debug_panel_open:
		return
	_sel = 0
	_root.visible = true
	Game.abrir_menu(self)
	_rebuild()


func _cerrar() -> void:
	_root.visible = false
	Game.cerrar_menu(self)


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_cerrar()
			get_viewport().set_input_as_handled()


func _rebuild() -> void:
	for zona in [_header, _content, _lista]:
		MenuScaffold.vaciar(zona)
	_peces = Game.peces()

	var vistas: int = 0
	for d in _peces:
		if int(Game.ficha_pesca((d as MaterialData).id)["capturas"]) > 0:
			vistas += 1
	MenuScaffold.titulo(_header, "LIBRO DE PECES")
	MenuScaffold.nota(_header, "Especies conocidas: %d de %d" % [vistas, _peces.size()])
	_header.add_child(HSeparator.new())

	for i in _peces.size():
		var d: MaterialData = _peces[i]
		var f: Dictionary = Game.ficha_pesca(d.id)
		var conocido: bool = int(f["capturas"]) > 0
		var b := Button.new()
		b.text = d.nombre if conocido else "??????"
		b.toggle_mode = true
		b.button_pressed = (i == _sel)
		b.custom_minimum_size = Vector2(0, 34)
		if not conocido:
			b.add_theme_color_override("font_color", GRIS)
		b.pressed.connect(_on_sel.bind(i))
		_lista.add_child(b)

	if _peces.is_empty():
		return
	_ficha(_peces[clampi(_sel, 0, _peces.size() - 1)])


func _on_sel(i: int) -> void:
	_sel = i
	_rebuild()


func _ficha(d: MaterialData) -> void:
	var f: Dictionary = Game.ficha_pesca(d.id)
	var capturas: int = int(f["capturas"])
	var conocido: bool = capturas > 0

	MenuScaffold.titulo(_content, d.nombre if conocido else "Especie sin pescar", 16,
		Upgrades.rareza_color(Game.rareza_pez(d)) if conocido else GRIS)
	_content.add_child(_foto(d, conocido))

	MenuScaffold.fila(_content, "Rareza", RAREZAS[clampi(Game.rareza_pez(d), 0, RAREZAS.size() - 1)],
		140, Upgrades.rareza_color(Game.rareza_pez(d)))
	MenuScaffold.fila(_content, "Capturas", str(capturas) if conocido else "—", 140)
	# El GLIFO de la corona va pegado a la talla: si tu mayor es un ejemplar de corona, se ve ahi
	# mismo sin tener que bajar a la lista de coronas.
	_fila_talla("El más grande", d, float(f["cm_max"]), conocido)
	_fila_talla("El más pequeño", d, float(f["cm_min"]), conocido)
	if conocido:
		# La horquilla de la ESPECIE, para que sepas cuanto te queda hasta el ejemplar de museo.
		MenuScaffold.fila(_content, "Talla de la especie",
			"%d - %d cm" % [roundi(d.cm_min), roundi(d.cm_max)], 140)
		MenuScaffold.fila(_content, "Valor base", str(d.valor_base), 140)
		_coronas(d)

	_content.add_child(HSeparator.new())
	if conocido:
		MenuScaffold.nota(_content, d.descripcion)
		MenuScaffold.nota(_content, "Los ejemplares grandes se pagan mejor: uno en el máximo de su "
			+ "especie vale el cuádruple que uno en el mínimo.")
	else:
		MenuScaffold.nota(_content, "Todavía no has sacado ninguno. Búscalo en los estanques de la mazmorra.")


# Una linea de talla con SU corona al lado, si esa talla la merece. El icono se pinta del color de
# su metal (oro/plata), asi que se distingue de un vistazo cual de los cuatro premios es.
func _fila_talla(etiqueta: String, d: MaterialData, cm: float, conocido: bool) -> void:
	if not conocido or cm <= 0.0:
		MenuScaffold.fila(_content, etiqueta, "—", 140)
		return
	var c: int = d.corona_de(cm)
	var g: String = MaterialData.corona_glifo(c)
	MenuScaffold.fila(_content, etiqueta,
		"%d cm%s" % [roundi(cm), ("   " + g + " " + MaterialData.corona_texto(c)) if g != "" else ""],
		140, MaterialData.corona_color(c) if c != MaterialData.Corona.NINGUNA else AMBAR)


# LAS CUATRO CORONAS de la especie, con el corte EN CENTIMETROS que hay que batir (o no llegar) para
# cada una. Los umbrales salen de MaterialData.corona_umbral, o sea de los campos: el libro nunca
# escribe un numero a mano. Se listan de la mas grande a la mas pequeña, que es como se lee la
# horquilla de un vistazo.
func _coronas(d: MaterialData) -> void:
	_content.add_child(HSeparator.new())
	MenuScaffold.titulo(_content, "Coronas", 13)
	for c in [MaterialData.Corona.ORO, MaterialData.Corona.PLATA,
			MaterialData.Corona.MINI_PLATA, MaterialData.Corona.MINI_ORO]:
		var tengo: bool = Game.tiene_corona(d.id, c)
		var umbral: int = roundi(d.corona_umbral(c))
		var grande: bool = c == MaterialData.Corona.ORO or c == MaterialData.Corona.PLATA
		var meta: String = ("desde %d cm" % umbral) if grande else ("hasta %d cm" % umbral)
		MenuScaffold.fila(_content,
			"%s %s" % [MaterialData.corona_glifo(c), MaterialData.corona_texto(c)],
			("✓  conseguida" if tengo else "—  %s" % meta),
			200, MaterialData.corona_color(c) if tengo else GRIS)


# La "foto": la MISMA silueta que nada en el charco (un rectangulo alargado con la esbeltez de su
# especie), a lo grande y quieta. Placeholder honesto hasta que llegue el arte, y coherente con lo
# que ves bajo el agua: si en el libro es largo y fino, en el charco tambien.
func _foto(d: MaterialData, conocido: bool) -> Control:
	var marco := ColorRect.new()
	marco.custom_minimum_size = FOTO
	marco.color = Color(0.09, 0.14, 0.21)

	var largo: float = FOTO.x * 0.72
	var alto: float = maxf(6.0, largo / maxf(1.2, d.esbeltez))
	var pez := ColorRect.new()
	pez.size = Vector2(largo, alto)
	pez.position = (FOTO - pez.size) * 0.5
	# Sin pescar: silueta en negro. Pescado: el color del material.
	pez.color = d.color if conocido else Color(0.03, 0.05, 0.08)
	marco.add_child(pez)
	return marco
