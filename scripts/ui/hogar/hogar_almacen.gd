# ============================================================
#  hogar_almacen.gd  --  seccion ALMACEN del menu del HOGAR (ver home_menu.gd, que es el armazon).
#
#  Todo lo que se deja en casa, en UNA pantalla con la cara del inventario y sus MISMAS secciones, para
#  que se lea igual que la mochila:
#    fila 2 (categoria):    Equipo · Consumibles · Materiales · Armas · Armaduras · Hucha
#    fila 3 (subcategoria): Mochila/Herramientas/Farolillo · tipo de arma · pieza de armadura
#  Debajo, LOS DOS LADOS A LA VEZ (lo pidio el usuario): la zona de la rejilla partida en dos, tu
#  Inventario a la izquierda y lo que hay En casa a su lado, cada uno con su scroll; y a la derecha la
#  FICHA de lo que toques, con sus botones. Se pasan cosas de un lado al otro ARRASTRANDO la celda, o
#  con los botones de la ficha (que es lo que vale en el movil, donde arrastrar se lo lleva el scroll).
#
#  DE DONDE SALE CADA COSA (en multi, lo de casa es del host):
#    - Materiales:  Game.almacen_materiales, con el CANDADO DEL TALLER cogido mientras estas en la
#                   categoria (sin el, el cliente no ve el baul de verdad; ver net_hogar.abrir_taller).
#    - Equipo, armas y armaduras: el COFRE (Net.hogar.cofre_visible()). Sus entradas son diccionarios;
#                   la celda necesita un Resource, asi que se reconstruyen con deserializar_equipo
#                   (registrar = FALSE, o se meterian en tu baul) y se guardan en _cache_cofre.
#    - Consumibles: Net.hogar.cofre_consumibles_visible() {ruta: cantidad}.
#    - Hucha:       hogar_hucha.gd.
# ============================================================
extends RefCounted

const HogarHucha = preload("res://scripts/ui/hogar/hogar_hucha.gd")

const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const GRIS := Color(0.6, 0.63, 0.7)
const LADO_CELDA := 96.0

# Las categorias, en el MISMO orden e iconos que las pestañas del inventario (sin la Bolsa, que no se
# guarda: es lo que llevas), y la hucha al final.
const CATEGORIAS := [
	{"nombre": "Equipo", "icono": "mochila"},
	{"nombre": "Consumibles", "icono": "pocion"},
	{"nombre": "Materiales", "icono": "mineral"},
	{"nombre": "Armas", "icono": "espada"},
	{"nombre": "Armaduras", "icono": "coraza"},
	{"nombre": "Hucha", "icono": "moneda"},
]
const CAT_EQUIPO := 0
const CAT_CONSUMIBLES := 1
const CAT_MATERIALES := 2
const CAT_ARMAS := 3
const CAT_ARMADURAS := 4
const CAT_HUCHA := 5

# Las subcategorias: las mismas tablas que inventory_menu (SUBS_EQUIPO, FILTROS_ARMAS,
# FILTROS_ARMADURA). Si alli se añade un tipo de arma, hay que añadirlo aqui.
const SUBS_EQUIPO := [
	{"nombre": "Mochila", "icono": "mochila"},
	{"nombre": "Herramientas", "icono": "pico"},
	{"nombre": "Farolillo", "icono": "farol"},
]
const FILTROS_ARMAS := [
	{"nombre": "Todas", "icono": "todo", "tipo": -1, "clase": ""},
	{"nombre": "Daga", "icono": "daga", "tipo": 1, "clase": ""},
	{"nombre": "Estoque", "icono": "estoque", "tipo": 5, "clase": ""},
	{"nombre": "Espada corta", "icono": "espada_corta", "tipo": 2, "clase": ""},
	{"nombre": "Maza pequeña", "icono": "maza", "tipo": 7, "clase": ""},
	{"nombre": "Espada larga", "icono": "espada_larga", "tipo": 3, "clase": ""},
	{"nombre": "Mandoble", "icono": "mandoble", "tipo": 4, "clase": ""},
	{"nombre": "Hacha grande", "icono": "hacha", "tipo": 6, "clase": ""},
	{"nombre": "Martillo grande", "icono": "martillo", "tipo": 8, "clase": ""},
	{"nombre": "Bastón", "icono": "baston", "tipo": 9, "clase": ""},
	{"nombre": "Varita", "icono": "varita", "tipo": -1, "clase": "varita"},
	{"nombre": "Escudo pequeño", "icono": "escudo_peq", "tipo": 0, "clase": "escudo"},
	{"nombre": "Escudo normal", "icono": "escudo_med", "tipo": 1, "clase": "escudo"},
	{"nombre": "Escudo grande", "icono": "escudo_gra", "tipo": 2, "clase": "escudo"},
]
const FILTROS_ARMADURA := [
	{"nombre": "Todo", "icono": "todo", "slot": -1},
	{"nombre": "Casco", "icono": "casco", "slot": 0},
	{"nombre": "Pecho", "icono": "coraza", "slot": 1},
	{"nombre": "Manos", "icono": "mano", "slot": 2},
	{"nombre": "Pantalones", "icono": "pantalon", "slot": 3},
	{"nombre": "Botas", "icono": "botas", "slot": 4},
]
const ARMOR_SLOT_LABELS := ["Casco", "Pecho", "Manos", "Pantalones", "Botas"]

const LADO_CASA := 0
const LADO_ENCIMA := 1

var hogar = null   # el armazon (home_menu.gd). Sin tipo: con CanvasLayer no se ven sus variables
var hucha = null

var _cat: int = CAT_EQUIPO
var _sub: Dictionary = {}       # categoria -> subcategoria elegida (se recuerda al volver)
# LO ELEGIDO: de que lado y que celda (-1 = nada). Se conserva entre repintados.
var _sel_lado: int = LADO_ENCIMA
var _sel: int = -1
# Lo que enseña cada rejilla ahora mismo, en su orden: [{modelo, cantidad, id, ruta, dueno, encargo, lado}].
var _stacks: Dictionary = {LADO_CASA: [], LADO_ENCIMA: []}
# Las dos columnas de rejilla de este repintado (las crea _montar_columnas dentro de la lista del armazon).
var _columna: Dictionary = {LADO_CASA: null, LADO_ENCIMA: null}
var _cache_cofre: Dictionary = {}   # id de entrada del cofre -> Resource reconstruido
# El candado del taller (solo Materiales en multi): 0 sin pedir, 2 pidiendolo, 1 lo tengo, -1 ocupado.
var _taller: int = 0


func _init(pantalla) -> void:
	hogar = pantalla
	hucha = HogarHucha.new(pantalla)


# ============================================================
#  LA SECCION
# ============================================================

func _build_seccion() -> void:
	MenuScaffold.subpestanas(hogar.barra_sub, _campos(CATEGORIAS, "nombre"),
		_campos(CATEGORIAS, "icono"), _cat, _on_cat)
	hogar._titulo_seccion.text = str(CATEGORIAS[_cat]["nombre"])
	if _cat == CAT_HUCHA:
		hucha.pintar()
		return

	hogar.modo_rejilla(true)
	hogar.contador("Peso  %d / %d" % [roundi(Game.peso_actual()), roundi(Game.capacidad_carga())],
		Game.esta_sobrecargado())
	_pintar_subcategorias()
	if _cat == CAT_MATERIALES and not _taller_listo():
		return
	for lado in [LADO_CASA, LADO_ENCIMA]:
		_stacks[lado] = _recoger(lado)
	if _sel >= (_stacks[_sel_lado] as Array).size():
		_sel = -1
	_pintar_barra()
	_montar_columnas()
	_pintar_lado(LADO_ENCIMA, _columna[LADO_ENCIMA])
	_pintar_lado(LADO_CASA, _columna[LADO_CASA])
	_ficha()


func _on_cat(i: int) -> void:
	if i == _cat:
		return
	if _cat == CAT_MATERIALES:
		al_cerrar()   # suelta el candado del taller al salir de materiales
	_cat = i
	_sel = -1
	hogar._aviso = ""
	hogar._rebuild()


func _on_sub(i: int) -> void:
	_sub[_cat] = i
	_sel = -1
	hogar._rebuild()


# La llaman el armazon al cerrar el hogar o cambiar de seccion, y _on_cat al salir de Materiales.
func al_cerrar() -> void:
	if _taller == 1 and Net.activo:
		Net.hogar.cerrar_taller()
	_taller = 0


func _sub_de(cat: int) -> int:
	return int(_sub.get(cat, 0))


func _campos(tabla: Array, clave: String) -> Array:
	var out: Array = []
	for f in tabla:
		out.append(f[clave])
	return out


# La TERCERA fila: la subcategoria, en las categorias que la tienen.
func _pintar_subcategorias() -> void:
	var tabla: Array = []
	match _cat:
		CAT_EQUIPO: tabla = SUBS_EQUIPO
		CAT_ARMAS: tabla = FILTROS_ARMAS
		CAT_ARMADURAS: tabla = FILTROS_ARMADURA
	if tabla.is_empty():
		return
	var s: int = clampi(_sub_de(_cat), 0, tabla.size() - 1)
	_sub[_cat] = s
	MenuScaffold.subpestanas(hogar.barra_sub2, _campos(tabla, "nombre"), _campos(tabla, "icono"),
		s, _on_sub)
	# El nombre de la subcategoria manda arriba (como en el inventario): "Farolillo" dice mas que
	# "Equipo". En los filtros "Todas/Todo" se queda el de la categoria.
	if _cat == CAT_EQUIPO or s > 0:
		hogar._titulo_seccion.text = str(tabla[s]["nombre"])


# ============================================================
#  EL CANDADO DEL TALLER (materiales en multi)
# ============================================================

func _taller_listo() -> bool:
	if not Net.activo:
		return true
	match _taller:
		1:
			return true
		0:
			_taller = 2
			_pedir_taller()
			MenuScaffold.nota(hogar._lista, "Abriendo el baúl…")
		2:
			MenuScaffold.nota(hogar._lista, "Abriendo el baúl…")
		-1:
			MenuScaffold.nota(hogar._lista, "Tu compañero está usando el baúl de materiales en el taller.")
			MenuScaffold.pastilla(hogar._lista, "Volver a intentarlo", func():
				_taller = 0
				hogar._rebuild(), false)
	return false


func _pedir_taller() -> void:
	var ok: bool = await Net.hogar.abrir_taller()
	# Si mientras tanto se ha ido de materiales (o ha cerrado el hogar), el candado no le sirve: fuera.
	if _cat != CAT_MATERIALES or not hogar._root.visible:
		if ok:
			Net.hogar.cerrar_taller()
		_taller = 0
		return
	_taller = 1 if ok else -1
	hogar._rebuild()


# ============================================================
#  QUE HAY EN CADA LADO
# ============================================================

# Los montones de un lado, ya filtrados por la subcategoria.
func _recoger(lado: int) -> Array:
	var out: Array = []
	match _cat:
		CAT_MATERIALES:
			var lista: Array = Game.almacen_materiales if lado == LADO_CASA else Game.materiales
			for s in _agrupar(lista):
				out.append(_entrada(s["modelo"], int(s["cantidad"]), lado))
		CAT_CONSUMIBLES:
			if lado == LADO_CASA:
				var consum: Dictionary = Net.hogar.cofre_consumibles_visible()
				for ruta in consum:
					var c: Resource = load(str(ruta)) if ResourceLoader.exists(str(ruta)) else null
					if c != null and int(consum[ruta]) > 0:
						var e: Dictionary = _entrada(c, int(consum[ruta]), lado)
						e["ruta"] = str(ruta)
						out.append(e)
			else:
				for c in Game.consumables:
					if int(Game.consumables[c]) > 0:
						var e2: Dictionary = _entrada(c, int(Game.consumables[c]), lado)
						e2["ruta"] = (c as Resource).resource_path
						out.append(e2)
		_:
			if lado == LADO_CASA:
				out = _del_cofre()
			else:
				for it in _encima():
					# LO EQUIPADO NO SALE (lo pidio el usuario): ni el arma que lleva alguien, ni la mochila
					# puesta, ni la herramienta equipada. Asi no hay nada que avisar: lo que ves, se guarda.
					if Game.item_equipado(it):
						continue
					if _pasa_filtro(it):
						var e3: Dictionary = _entrada(it, 1, lado)
						var dueno: PersonajeData = Game.quien_lleva(it)
						e3["dueno"] = "" if dueno == null else dueno.nombre
						out.append(e3)
	return out


func _entrada(modelo: Resource, cantidad: int, lado: int) -> Dictionary:
	return {"modelo": modelo, "cantidad": cantidad, "id": -1, "ruta": "", "dueno": "", "encargo": false,
		"lado": lado}


# Lo que LLEVAS de la categoria de equipo actual (sin filtrar todavia). SIN TIPAR: se juntan arrays de
# clases distintas, y un .has() con la clase equivocada revienta (ver arrays-tipados-por-clase).
func _encima() -> Array:
	var out: Array = []
	match _cat:
		CAT_ARMAS:
			out.append_array(Game.owned_weapons)
		CAT_ARMADURAS:
			out.append_array(Game.owned_armor)
		CAT_EQUIPO:
			if _sub_de(CAT_EQUIPO) == 0:
				out.append_array(Game.owned_mochilas)
			else:
				out.append_array(Game.owned_tools)
	return out


# Lo que hay en el COFRE de la categoria de equipo actual, reconstruido y filtrado.
func _del_cofre() -> Array:
	var out: Array = []
	var vivos: Dictionary = {}
	for entrada in Net.hogar.cofre_visible():
		var id: int = int(entrada.get("id", -1))
		vivos[id] = true
		var clase: String = str(entrada.get("clase", ""))
		if not _clase_encaja(clase):
			continue
		if not _cache_cofre.has(id):
			_cache_cofre[id] = Game.deserializar_equipo(entrada.get("dict", {}), false)
		var item: Resource = _cache_cofre[id]
		if item == null or not _pasa_filtro(item):
			continue
		var e: Dictionary = _entrada(item, 1, LADO_CASA)
		e["id"] = id
		e["encargo"] = int(entrada.get("encargo", 0)) != 0
		out.append(e)
	# Lo que ya no esta en el cofre (lo saco alguien) se olvida.
	for id in _cache_cofre.keys():
		if not vivos.has(id):
			_cache_cofre.erase(id)
	return out


func _clase_encaja(clase: String) -> bool:
	match _cat:
		CAT_ARMAS: return clase == "arma"
		CAT_ARMADURAS: return clase == "armadura"
		CAT_EQUIPO: return clase == ("mochila" if _sub_de(CAT_EQUIPO) == 0 else "herramienta")
	return false


func _pasa_filtro(item: Resource) -> bool:
	match _cat:
		CAT_ARMAS:
			var f: Dictionary = FILTROS_ARMAS[clampi(_sub_de(CAT_ARMAS), 0, FILTROS_ARMAS.size() - 1)]
			var clase: String = str(f["clase"])
			if clase == "escudo":
				return item is ShieldData and int((item as ShieldData).tamano) == int(f["tipo"])
			if clase == "varita":
				return item is WandData
			if int(f["tipo"]) < 0:
				return true
			return item is WeaponData and int((item as WeaponData).tipo) == int(f["tipo"])
		CAT_ARMADURAS:
			var slot: int = int(FILTROS_ARMADURA[clampi(_sub_de(CAT_ARMADURAS), 0, FILTROS_ARMADURA.size() - 1)]["slot"])
			return item is ArmorData and (slot < 0 or int((item as ArmorData).slot) == slot)
		CAT_EQUIPO:
			match _sub_de(CAT_EQUIPO):
				0: return item is BackpackData
				1: return item is ToolData and not (item as ToolData).es_lampara()
				2: return item is ToolData and (item as ToolData).es_lampara()
	return true


# Agrupa materiales iguales en montones {modelo, cantidad}, con la clave de Game.clave_monton.
func _agrupar(items: Array) -> Array:
	var claves: Array = []
	var mapa: Dictionary = {}
	for it in items:
		if not (it is MaterialItem):
			continue
		var k: String = Game.clave_monton(it)
		if not mapa.has(k):
			mapa[k] = {"modelo": it, "cantidad": 0}
			claves.append(k)
		mapa[k]["cantidad"] += 1
	var res: Array = []
	for k in claves:
		res.append(mapa[k])
	return res


# ============================================================
#  LA BARRA DE ARRIBA: lo elegido con sus botones, y las acciones en bloque de materiales
# ============================================================

func _pintar_barra() -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	fila.custom_minimum_size = Vector2(0, 38)
	hogar._header.add_child(fila)

	var l := Label.new()
	l.text = "Arrastra un objeto de un lado al otro, o tócalo para ver su ficha."
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", GRIS)
	fila.add_child(l)

	if _cat != CAT_MATERIALES:
		return
	# MATERIALES EN BLOQUE: son cientos de piezas sueltas y de uno en uno no se acaba nunca. Tres
	# botoncitos con icono (lo pidio asi el usuario): abajo = guardar, arriba = recoger sin
	# sobrecargarte, doble = recoger todo. Cada uno pregunta antes en un modal que dice que va a pasar.
	var hueco := Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(hueco)
	_boton_bloque(fila, "flecha_abajo", "Guardar todos los materiales", _confirmar_bloque.bind("guardar"))
	_boton_bloque(fila, "flecha_arriba", "Recoger sin sobrecargarte", _confirmar_bloque.bind("recoger"))
	_boton_bloque(fila, "flecha_doble_arriba", "Recoger todo", _confirmar_bloque.bind("todo"))


func _color_de(m: Resource) -> Color:
	if m is MaterialItem:
		return (m as MaterialItem).data.color_rango()
	if m is ConsumableData:
		return Color(0.94, 0.95, 0.98)
	return Game.color_rareza_de(m)


func _boton_bloque(fila: Control, icono: String, pista: String, al_pulsar: Callable) -> void:
	var b: Control = BotonIcono.crear(Callable(Iconos, icono), al_pulsar, 36.0, true)
	b.tooltip_text = pista
	fila.add_child(b)


var _modal: Control = null

# El modal de las acciones en bloque: que va a pasar, con cuantos, y Cancelar / Confirmar.
func _confirmar_bloque(que: String) -> void:
	cerrar_modal()
	var en_bolsa: int = Game.materiales.size()
	var en_casa: int = Game.almacen_materiales.size()
	var titulo: String = ""
	var texto: String = ""
	var accion: Callable
	match que:
		"guardar":
			titulo = "Guardar todos los materiales"
			texto = "Dejas en casa los %d materiales de tu inventario. Los cristales no: esos se venden en la tienda." % en_bolsa
			accion = func():
				var n: int = Game.guardar_materiales_en_hogar()
				_decir("Guardas %d material%s en casa." % [n, "" if n == 1 else "es"] if n > 0
					else "No tienes materiales en el inventario.", n > 0)
		"recoger":
			titulo = "Recoger sin sobrecargarte"
			texto = "Te llevas de casa todo lo que puedas cargar sin empezar a ir lento. Lo que no quepa se queda guardado."
			accion = func():
				var n: int = Game.recoger_materiales_del_hogar(false)
				_decir("Te llevas %d material%s." % [n, "" if n == 1 else "es"] if n > 0
					else "Ya vas cargado: llevar más te dejaría lento.", n > 0)
		_:
			titulo = "Recoger todo"
			texto = "Te llevas los %d materiales que hay en casa, aunque vayas sobrecargado y te muevas lento." % en_casa
			accion = func():
				var n: int = Game.recoger_materiales_del_hogar(true)
				var txt: String = "Te llevas %d material%s." % [n, "" if n == 1 else "es"] if n > 0 \
					else "No hay materiales en casa."
				if n > 0 and Game.esta_sobrecargado():
					txt += "  Vas sobrecargado: te moverás lento."
				_decir(txt, n > 0)
	var m: Dictionary = MenuScaffold.modal(hogar._root, titulo, 460.0)
	_modal = m["capa"]
	_modal.z_index = 4096   # por encima de cualquier muñeco (ver retratos-pisan-los-modales)
	MenuScaffold.nota(m["cuerpo"], texto)
	MenuScaffold.pastilla(m["acciones"], "Cancelar", cerrar_modal, false)
	MenuScaffold.pastilla(m["acciones"], "Confirmar", func():
		cerrar_modal()
		accion.call())


# true si habia un modal abierto (el armazon lo pregunta antes de cerrar el hogar con Esc).
func cerrar_modal() -> bool:
	if _modal == null or not is_instance_valid(_modal):
		_modal = null
		return false
	_modal.get_parent().remove_child(_modal)
	_modal.queue_free()
	_modal = null
	return true


func _contar(stacks: Array) -> int:
	var n: int = 0
	for s in stacks:
		n += int(s["cantidad"])
	return n


# ============================================================
#  LOS DOS LADOS: una rejilla cada uno, y se arrastra de uno al otro
# ============================================================

# El meta con el que una celda dice de que lado y que montón es, para el arrastre.
const META_ARRASTRE := "cofre_arrastre"

# LA ZONA DE LA REJILLA PARTIDA EN DOS: dos columnas lado a lado dentro de la lista del armazon, cada una
# con su propio scroll (el de la lista se apaga: un scroll comun moveria las dos a la vez).
func _montar_columnas() -> void:
	hogar._lista_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hogar._lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 18)
	fila.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hogar._lista.add_child(fila)
	for lado in [LADO_ENCIMA, LADO_CASA]:
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		fila.add_child(sc)
		if Tactil.activo:
			ArrastreScroll.enganchar(sc)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 4)
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.add_child(vb)
		_columna[lado] = vb

func _pintar_lado(lado: int, vb: VBoxContainer) -> void:
	var stacks: Array = _stacks[lado]
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 8)
	vb.add_child(cab)
	var t := Label.new()
	t.text = "En casa" if lado == LADO_CASA else "Inventario"
	t.add_theme_font_size_override("font_size", 16)
	t.add_theme_color_override("font_color", AMBAR)
	cab.add_child(t)
	var n := Label.new()
	n.text = "%d" % _contar(stacks)
	n.add_theme_font_size_override("font_size", 16)
	n.add_theme_color_override("font_color", GRIS)
	cab.add_child(n)

	# SOLTAR AQUI: la columna entera (su scroll y lo de dentro) acepta lo que venga del OTRO lado.
	_aceptar_soltar(vb, lado)
	_aceptar_soltar(vb.get_parent() as Control, lado)

	if stacks.is_empty():
		MenuScaffold.nota(vb, "No hay nada de esto guardado en casa." if lado == LADO_CASA
			else "No tienes nada de esto en el inventario.")
		return
	var piezas: Array = []
	for s in stacks:
		var marca: String = str(s["dueno"])
		if bool(s["encargo"]):
			marca = "ENCARGO"
		var k: int = int(s["cantidad"])
		piezas.append({"item": s["modelo"], "pie": ("x%d" % k) if k > 1 else "",
			"tooltip": _nombre(s["modelo"]), "marca": marca, "activo": true})
	var sel: int = _sel if _sel_lado == lado else -1
	MenuScaffold.rejilla_objetos(vb, piezas, sel, _pick.bind(lado), _columnas(vb), LADO_CELDA, false)
	# Las celdas se crean a tandas (ver rejilla_objetos): el arrastre se engancha a las que ya estan y,
	# para las que vienen, al añadirse a la rejilla.
	for h in vb.get_children():
		if h is GridContainer:
			_aceptar_soltar(h, lado)
			for i in h.get_child_count():
				_hacer_arrastrable(h.get_child(i), lado, i)
			h.child_entered_tree.connect(func(c: Node):
				_hacer_arrastrable(c, lado, c.get_index()))


func _hacer_arrastrable(c: Node, lado: int, i: int) -> void:
	if not (c is Control) or (c as Control).has_meta(META_ARRASTRE):
		return
	var celda := c as Control
	celda.set_meta(META_ARRASTRE, [lado, i])
	# En el movil el deslizamiento de la lista se lleva el gesto salvo que la celda lo pida para si.
	if Tactil.activo:
		celda.set_meta(ArrastreScroll.META_ARRASTRE_PROPIO, true)
	celda.set_drag_forwarding(
		func(_pos: Vector2) -> Variant:
			var st: Array = _stacks[lado]
			if i >= st.size():
				return null
			var vista := CeldaObjeto.new()
			vista.custom_minimum_size = Vector2(LADO_CELDA, LADO_CELDA) * 0.8
			vista.size = vista.custom_minimum_size
			vista.modulate = Color(1, 1, 1, 0.85)
			celda.set_drag_preview(vista)
			vista.configurar(st[i]["modelo"] as Resource, "", "", -1)
			return {"cofre_lado": lado, "cofre_idx": i},
		func(_pos: Vector2, data: Variant) -> bool:
			return _puede_soltar(data, lado),
		func(_pos: Vector2, data: Variant) -> void:
			_soltar(data, lado))


func _aceptar_soltar(zona: Control, lado: int) -> void:
	if zona == null:
		return
	zona.set_drag_forwarding(
		func(_pos: Vector2) -> Variant: return null,
		func(_pos: Vector2, data: Variant) -> bool: return _puede_soltar(data, lado),
		func(_pos: Vector2, data: Variant) -> void: _soltar(data, lado))


func _puede_soltar(data: Variant, destino: int) -> bool:
	return data is Dictionary and (data as Dictionary).has("cofre_lado") \
		and int(data["cofre_lado"]) != destino


# SOLTAR en el otro lado = mover el montón ENTERO (una pieza de equipo es un montón de uno).
func _soltar(data: Variant, destino: int) -> void:
	if not _puede_soltar(data, destino):
		return
	var st: Array = _stacks[int(data["cofre_lado"])]
	var i: int = int(data["cofre_idx"])
	if i < 0 or i >= st.size():
		return
	var s: Dictionary = st[i]
	if bool(s["encargo"]):
		_decir("Está prestado a un encargo: vuelve cuando lo recojas.", false)
		return
	if int(s["lado"]) == LADO_ENCIMA and str(s["dueno"]) != "":
		_decir("Lo lleva %s: quítaselo antes de guardarlo." % s["dueno"], false)
		return
	_sel = -1
	_mover(s, int(s["cantidad"]))


# Elegir una celda: se marca en SU rejilla, se desmarca la del otro lado y se repinta solo la ficha
# (rehacer las rejillas las devolveria arriba del todo, ver marcar_en_rejilla).
func _pick(i: int, lado: int) -> void:
	_sel = i
	_sel_lado = lado
	var vb_elegido: VBoxContainer = _columna[lado]
	var vb_otro: VBoxContainer = _columna[LADO_CASA if lado == LADO_ENCIMA else LADO_ENCIMA]
	if vb_elegido != null and is_instance_valid(vb_elegido) and MenuScaffold.marcar_en_rejilla(vb_elegido, i):
		if vb_otro != null and is_instance_valid(vb_otro):
			MenuScaffold.marcar_en_rejilla(vb_otro, -1)
		MenuScaffold.vaciar(hogar._content)
		_ficha()
	else:
		hogar._rebuild()


func _columnas(vb: Control) -> int:
	var ancho: float = vb.size.x
	if ancho <= 1.0:
		ancho = 300.0
	return maxi(2, int(floorf((ancho + 6.0) / (LADO_CELDA + 6.0))))


func _nombre(it: Resource) -> String:
	if it is MaterialItem:
		return (it as MaterialItem).nombre_mostrado()
	if it is ConsumableData:
		return (it as ConsumableData).nombre
	return Game.item_display_name(it)


# ============================================================
#  LA FICHA DE LA DERECHA: lo elegido de cualquiera de los dos lados, con sus botones
# ============================================================

func _ficha() -> void:
	var vb: VBoxContainer = hogar._content
	if _sel < 0 or _sel >= (_stacks[_sel_lado] as Array).size():
		MenuScaffold.nota(vb, "Toca un objeto de cualquiera de los dos lados para ver su ficha.")
		return
	var s: Dictionary = (_stacks[_sel_lado] as Array)[_sel]
	var m: Resource = s["modelo"]
	var n: int = int(s["cantidad"])
	# EL TITULO con su color: rango en los materiales, rareza en el equipo.
	if m is MaterialItem:
		var mi := m as MaterialItem
		MenuScaffold.titulo_item(vb, mi.nombre_mostrado(), mi.data.color_rango(), mi.data.rango_intensidad())
	elif m is ConsumableData:
		MenuScaffold.titulo(vb, (m as ConsumableData).nombre, 16, Color(0.94, 0.95, 0.98))
	else:
		MenuScaffold.titulo_item(vb, Game.item_display_name(m), Game.color_rareza_de(m),
			Game.intensidad_rareza_de(m))
	MenuScaffold.banner_item(vb, m, ("× %d" % n) if n > 1 else "",
		"En casa" if int(s["lado"]) == LADO_CASA else "Inventario")
	for fila in _filas(m):
		MenuScaffold.fila(vb, str(fila[0]), str(fila[1]), 150)
	# Lo que HACE un consumible es un parrafo, no un "etiqueta: valor": va a todo lo ancho.
	if m is ConsumableData and m.get("descripcion") != null and str(m.get("descripcion")) != "":
		MenuScaffold.nota(vb, str(m.get("descripcion")))
	vb.add_child(HSeparator.new())
	_acciones(vb, s)


# LOS BOTONES de la ficha: pasar lo elegido al otro lado. Lo que no se puede mover lo dice en vez de
# esconder el boton (una pieza puesta, una herramienta prestada a un encargo).
func _acciones(vb: VBoxContainer, s: Dictionary) -> void:
	var n: int = int(s["cantidad"])
	var a_casa: bool = int(s["lado"]) == LADO_ENCIMA
	if bool(s["encargo"]):
		MenuScaffold.nota(vb, "Está prestado a un encargo: vuelve a casa cuando lo recojas.")
		return
	if a_casa and str(s["dueno"]) != "":
		MenuScaffold.nota(vb, "Lo lleva %s. Quítaselo en su ficha antes de guardarlo." % s["dueno"])
		return
	var acc := VBoxContainer.new()
	acc.add_theme_constant_override("separation", 8)
	vb.add_child(acc)
	var verbo: String = "Guardar" if a_casa else "Sacar"
	if n > 1:
		_boton(acc, "%s todo (%d)" % [verbo, n], _mover.bind(s, n), true)
		_boton(acc, "%s uno" % verbo, _mover.bind(s, 1), false)
	else:
		_boton(acc, "Guardar en casa" if a_casa else "Sacar al inventario", _mover.bind(s, 1), true)


# Las filas de datos de cada clase de cosa. Las de equipo salen de las fichas COMPARTIDAS de
# MenuScaffold, con el tier, la rareza y las mejoras reales de ESTA pieza.
func _filas(m: Resource) -> Array:
	var out: Array = []
	if m is MaterialItem:
		var mi := m as MaterialItem
		out.append(["Calidad", mi.calidad_texto()])
		out.append(["Peso", "%.1f cada uno" % mi.peso()])
		return out
	if m is ConsumableData:
		return out   # su descripcion va aparte, a todo lo ancho (ver _ficha)
	var meta: Dictionary = Game.meta_de(m)
	if m is WeaponData:
		out.append_array(MenuScaffold.filas_arma(m, int(meta["tier"]), int(meta["rareza"]),
			meta["mejoras"], null, Game.durabilidad_item(m)))
	elif m is ShieldData:
		out.append_array(MenuScaffold.filas_escudo(m, int(meta["tier"]), int(meta["rareza"]), meta["mejoras"]))
	elif m is ArmorData:
		out.append(["Pieza", ARMOR_SLOT_LABELS[clampi(int((m as ArmorData).slot), 0, 4)]])
		out.append_array(MenuScaffold.filas_armadura(m, int(meta["tier"]), int(meta["rareza"]),
			meta["mejoras"], Game.durabilidad_item(m)))
	elif m is ToolData:
		out.append_array(MenuScaffold.filas_herramienta(m))
	elif m is BackpackData:
		out.append(["Capacidad", "+%.0f de carga" % Game.capacidad_mochila(m)])
	if not (m is BackpackData):
		out.append(["Durabilidad", Game.durabilidad_txt_item(m)])
	return out


func _boton(padre: Control, txt: String, al_pulsar: Callable, principal: bool) -> void:
	var b: Button = MenuScaffold.pastilla(padre, txt, al_pulsar, principal)
	b.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)


# Pasa 'cuantos' de lo elegido al otro lado, por la via de red de cada cosa.
func _mover(s: Dictionary, cuantos: int) -> void:
	var m: Resource = s["modelo"]
	var a_casa: bool = int(s["lado"]) == LADO_ENCIMA
	var nombre: String = _nombre(m)
	match _cat:
		CAT_MATERIALES:
			var movidos: int = Game.mover_monton_material(m, a_casa, cuantos)
			if movidos <= 0:
				_decir("No se ha podido mover.", false)
				return
			_decir("%s %d × %s." % ["Guardas" if a_casa else "Sacas", movidos, nombre], true)
		CAT_CONSUMIBLES:
			if a_casa:
				Net.hogar.meter_consumible_cofre(str(s["ruta"]), cuantos)
			else:
				Net.hogar.sacar_consumible_cofre(str(s["ruta"]), cuantos)
			_decir("%s %d × %s." % ["Guardas" if a_casa else "Sacas", cuantos, nombre], true)
		_:
			if a_casa:
				if Game.item_equipado(m):
					_decir("Está puesto: quítaselo antes de guardarlo.", false)
					return
				if not Net.hogar.meter_en_cofre(m):
					_decir("No se ha podido guardar.", false)
					return
				_decir("Guardas %s en casa." % nombre, true)
			else:
				Net.hogar.sacar_de_cofre(int(s["id"]))
				_cache_cofre.erase(int(s["id"]))
				_decir("Sacas %s al inventario." % nombre, true)


func _decir(txt: String, ok: bool) -> void:
	hogar._aviso = txt
	hogar._aviso_ok = ok
	hogar._rebuild()
