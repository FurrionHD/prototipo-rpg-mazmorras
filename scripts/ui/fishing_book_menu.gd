# ============================================================
#  fishing_book_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  EL PESCADOR. Dos pestañas:
#
#   LIBRO  - una ficha por especie: su silueta, su rareza, cuantas has sacado, tu mayor y tu menor,
#            y de que va el bicho.
#   CEBOS  - su mostrador. Lo unico que vende, y lo unico que hace falta comprar para pescar mejor
#            (la caña te la forja el herrero). El de T2 no se enseña hasta que cae el Rey Slime,
#            igual que el mostrador T2 del tendero.
#
#  Lo que enseña el libro sale ENTERO de Game.registro_pesca, que se apunta al cobrar cada pieza. NO
#  se recalcula desde la bolsa a proposito: el pez se vende, se cocina y se pierde, y el record de la
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
var _side: VBoxContainer = null       # donde van las pestañas
var _dinero: Label = null
var _aviso: Label = null
var _tab: int = 0                     # 0 = Libro, 1 = Cebos
var _sel: int = 0
var _peces: Array = []
var _stacks: Array = []               # lo que hay a la venta en la pestaña de cebos
# CUANTOS cebos vas a comprar (el numero del stepper). Es un CAMPO y no una variable local de
# _ficha_cebo a proposito: las lambdas de GDScript capturan los locales POR VALOR, asi que el
# `func(n): cuantas = n` del stepper escribia en su propia copia y el boton de comprar leia el 1 de
# siempre. Comprabas cuatro y te llevabas uno (cobrandote uno, eso si). Los campos del nodo se leen
# en vivo desde la lambda y no tienen ese problema.
var _cuantas: int = 1

const TABS := ["Libro", "Cebos"]
const AMBAR := Color(0.95, 0.72, 0.36)
const GRIS := Color(0.6, 0.63, 0.7)
const VERDE := Color(0.55, 0.85, 0.55)
const ROJO := Color(0.9, 0.5, 0.5)
# Los cinco peldaños de rareza, con los MISMOS nombres que usa el equipo (Upgrades): un "raro"
# tiene que querer decir lo mismo en un pez que en una espada.
const RAREZAS := ["Común", "Poco común", "Raro", "Épico", "Legendario"]

# Tamaño del recuadro de la "foto" y cuanto de el ocupa el pez mas largo de la especie.
const FOTO := Vector2(260, 120)

# EL MOSTRADOR. El T2 va aparte porque lo gatea el Rey Slime (Game.tienda_t2_abierta), igual que el
# de la tienda del pueblo: no es que valga mas, es que hasta ahi no lo ves.
const CAT_CEBOS: Array[String] = [
	"res://resources/consumables/cebo_gusano.tres",
]
const CAT_CEBOS_T2: Array[String] = [
	"res://resources/consumables/cebo_sanguijuela.tres",
]


func _ready() -> void:
	layer = 91
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para con el menu abierto
	add_to_group("fishing_book_menu")

	var m: Dictionary = MenuScaffold.construir(self, "PESCADOR",
		"Lleva la cuenta de lo que sacas de los estanques de ahí abajo, y vende el cebo con el que "
		+ "sacarlo.", _cerrar, true)
	_root = m["root"]
	_header = m["header"]
	_content = m["content"]
	_lista = m["lista"]
	_side = m["side"]
	_dinero = m["dinero"]
	_aviso = m["aviso"]


func abrir() -> void:
	if Game._active_layer != null or Game.debug_panel_open:
		return
	_tab = 0
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


func _decir(txt: String, ok: bool = true) -> void:
	MenuScaffold.decir(_aviso, txt, ok)


func _on_tab(i: int) -> void:
	_tab = i
	_sel = 0
	MenuScaffold.decir(_aviso, "")
	_rebuild()


# Guardia de REENTRADA. Un _rebuild puede entrar mientras otro esta a medias (el focus_exited de un
# stepper al liberarlo, las señales de red, un _on_* que espera en un await), y entonces el de dentro
# pinta su panel y el de fuera apila el suyo debajo: el menu salia DUPLICADO. Es el mismo guardia que
# lleva el herrero desde que se cazo alli.
var _reconstruyendo := false

func _rebuild() -> void:
	if _reconstruyendo:
		return
	_reconstruyendo = true
	_rebuild_real()
	_reconstruyendo = false


func _rebuild_real() -> void:
	for zona in [_header, _content, _lista, _side]:
		MenuScaffold.vaciar(zona)
	if _dinero != null:
		_dinero.text = "%d monedas" % Game.money
	MenuScaffold.pestanas(_side, TABS, _tab, _on_tab, 0)
	if _tab == 1:
		_build_cebos()
	else:
		_build_libro()


# ------------------------------------------------------------
#  PESTAÑA: LIBRO
# ------------------------------------------------------------
func _build_libro() -> void:
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
		b.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)
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
			"%.1f - %.1f cm" % [d.cm_min, d.cm_max], 140)
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
		"%.1f cm%s" % [cm, ("   " + g + " " + MaterialData.corona_texto(c)) if g != "" else ""],
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
		# El corte NO se enseña hasta que la corona es tuya: si el libro te dice "desde 53.8 cm", la
		# corona deja de ser un hallazgo y se convierte en una lista de la compra. Con ??? sacas peces
		# hasta que uno salta y ENTONCES te enteras de donde estaba la raya.
		MenuScaffold.fila(_content,
			"%s %s" % [MaterialData.corona_glifo(c), MaterialData.corona_texto(c)],
			("✓  conseguida" if tengo else "—  ???"),
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


# ------------------------------------------------------------
#  PESTAÑA: CEBOS (el mostrador)
# ------------------------------------------------------------
func _build_cebos() -> void:
	MenuScaffold.titulo(_header, "CEBOS")
	MenuScaffold.nota(_header, "El cebo se pone en el estanque, no aquí: baja, ponte a la orilla y "
		+ "pulsa [F].")
	_header.add_child(HSeparator.new())

	_stacks = []
	var rutas: Array[String] = CAT_CEBOS.duplicate()
	if Game.tienda_t2_abierta():
		rutas.append_array(CAT_CEBOS_T2)
	for ruta in rutas:
		var base: Resource = load(ruta)
		if base != null:
			_stacks.append(base)

	for i in _stacks.size():
		var c: ConsumableData = _stacks[i]
		var b := Button.new()
		b.text = "%s   ·   %d" % [c.nombre, Game.precio_compra(c)]
		b.toggle_mode = true
		b.button_pressed = (i == _sel)
		b.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)
		b.pressed.connect(_on_sel_cebo.bind(i))
		_lista.add_child(b)

	if _stacks.is_empty():
		MenuScaffold.nota(_content, "Hoy no tiene nada en el mostrador.")
		return
	_ficha_cebo(_stacks[clampi(_sel, 0, _stacks.size() - 1)])


func _on_sel_cebo(i: int) -> void:
	_sel = i
	_rebuild()


func _ficha_cebo(c: ConsumableData) -> void:
	var precio: int = Game.precio_compra(c)
	MenuScaffold.titulo(_content, c.nombre, 16, AMBAR)
	# Igual que en el libro: el numero sale del CAMPO (resumen()), no de la descripcion.
	MenuScaffold.fila(_content, "Atracción", c.resumen(0.0, 0.0), 140, VERDE)
	MenuScaffold.fila(_content, "Precio", str(precio), 140,
		AMBAR if Game.money >= precio else ROJO)
	MenuScaffold.fila(_content, "Tienes", str(int(Game.consumables.get(c, 0))), 140)
	_content.add_child(HSeparator.new())
	MenuScaffold.nota(_content, c.descripcion)
	MenuScaffold.nota(_content, "Se gasta el %d%% de las veces que cobras una pieza. Si el pez se "
		% int(round(Game.CEBO_GASTO * 100.0))
		+ "escapa o recoges el sedal, no pagas nada.")
	_content.add_child(HSeparator.new())

	# Cantidad + comprar. El maximo es lo que te llega: no tiene sentido ofrecer un stepper que
	# sube hasta 99 cuando la tercera unidad ya te deja sin monedas.
	var maximo: int = 99 if precio <= 0 else maxi(1, Game.money / precio)
	# La ficha se repinta entera al cambiar de cebo o al comprar, y el stepper vuelve a nacer en 1:
	# el campo tiene que arrancar de acuerdo con el, o el boton compraria una cantidad que no se ve.
	_cuantas = 1
	MenuScaffold.fila(_content, "Cantidad", "", 140)
	MenuScaffold.stepper(_content, 1, 1, maximo, func(n: int) -> void: _cuantas = n)
	var comprar := Button.new()
	comprar.text = "Comprar"
	comprar.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)
	comprar.pressed.connect(func() -> void: _on_comprar(c, _cuantas))
	_content.add_child(comprar)


func _on_comprar(c: ConsumableData, n: int) -> void:
	if Game.comprar_consumible(c, n):
		_decir("Compras %d x %s. Se pone en el estanque, con [F] sobre el agua." % [n, c.nombre])
	else:
		_decir("No te llega para %d x %s." % [n, c.nombre], false)
	_rebuild()
