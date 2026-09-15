# ============================================================
#  tienda_vender.gd  --  pestaña VENDER de la tienda (ver shop_menu.gd, que es el armazon).
#
#  Cuatro subpestañas, y en ellas TODO lo que tienes y se puede vender. Antes se quedaban fuera las
#  herramientas y el carbon (olvido: la logica de venta ya los admitia) y el cofre del hogar:
#    - BOTIN:        cristales, materiales de la bolsa y el carbon.
#    - EQUIPO:       armas, escudos, varitas, armaduras, mochilas y herramientas. Lo que lleva puesto
#                    alguien del grupo NO sale (enseñar lo que no puedes tocar es peor que no enseñarlo).
#    - CONSUMIBLES:  pociones, grimorios, tochos, platos, cebos...
#    - HOGAR:        el baul de materiales Y el cofre (equipo y consumibles). Lo prestado a un encargo
#                    no sale. En multi el baul pide el candado del taller y el cofre lo concede el host
#                    (y lo vendido se cobra cuando llega, ver Net.venta_cofre).
#
#  Cada MONTON: {modelo, cantidad, origen, clave, id, ruta}. 'origen' dice de donde sale (bolsa, hogar,
#  equipo, consumible, cofre, cofre_c) y por tanto como se vende; 'clave' lo identifica en la cesta.
# ============================================================
extends RefCounted

const TiendaCesta = preload("res://scripts/ui/tienda/tienda_cesta.gd")

const SUBS := ["Botín", "Equipo", "Consumibles", "Hogar"]
const SUBS_ICONOS := ["mineral", "espada", "pocion", "cofre"]
const SUB_BOTIN := 0
const SUB_EQUIPO := 1
const SUB_CONSUMIBLES := 2
const SUB_HOGAR := 3
const ARMOR_SLOT_LABELS := ["Casco", "Pecho", "Manos", "Pantalones", "Botas"]

var t = null   # el armazon (shop_menu.gd)
var cesta = TiendaCesta.new()
var _sub: int = SUB_BOTIN
var _cache_cofre: Dictionary = {}   # id de entrada del cofre -> pieza reconstruida (sin registrar)
# El candado del taller (baul de materiales en multi): 0 sin pedir, 2 pidiendolo, 1 lo tengo, -1 ocupado.
var _taller: int = 0


func _init(armazon) -> void:
	t = armazon


func clave() -> String:
	return "vender_%d" % _sub


func por_defecto() -> String:
	return "valor"


func rotulo_cesta() -> String:
	return "Vender cesta"


func al_cerrar() -> void:
	_soltar_taller()
	cesta.vaciar()
	_cache_cofre.clear()


# ============================================================
#  PINTAR
# ============================================================

func build() -> void:
	MenuScaffold.subpestanas(t.barra_sub, SUBS, SUBS_ICONOS, _sub, _on_sub)
	t.titulo_seccion(SUBS[_sub])
	if _sub == SUB_HOGAR and Net.activo:
		_taller_listo()
	var todos: Array = _recoger()
	t.stacks = t.orden.aplicar(clave(), todos, self, por_defecto())
	match _sub:
		SUB_BOTIN:
			t.contador("Peso  %d / %d" % [roundi(Game.peso_actual()), roundi(Game.capacidad_carga())],
				Game.esta_sobrecargado())
		_:
			t.contador("%d de %d" % [t.stacks.size(), todos.size()])
	var piezas: Array = []
	for s in t.stacks:
		piezas.append(_pieza(s))
	var vacio: String = "No hay nada que coincida." if t.orden.texto(clave()) != "" or t.orden.hay_filtro(clave()) \
		else _vacio()
	t.grid_detail(piezas, _ficha, vacio)


func _vacio() -> String:
	match _sub:
		SUB_BOTIN: return "No llevas botín en la bolsa. Baja a la mazmorra a por cristales y materiales."
		SUB_EQUIPO: return "No tienes equipo suelto. Lo que lleva puesto alguien del grupo no sale aquí: quítaselo antes en el menú de personaje [C]."
		SUB_CONSUMIBLES: return "No llevas consumibles."
	return "No hay nada guardado en el hogar."


func _on_sub(i: int) -> void:
	if i == _sub:
		return
	if _sub == SUB_HOGAR:
		_soltar_taller()
	_sub = i
	t.cambiar_pantalla()


func _pieza(s: Dictionary) -> Dictionary:
	var m: Resource = s["modelo"]
	var n: int = int(s["cantidad"])
	var pie: String = ""
	if m is ArmorData:
		pie = ARMOR_SLOT_LABELS[clampi(int((m as ArmorData).slot), 0, 4)]
	elif m is ToolData:
		pie = (m as ToolData).tipo_texto()
	elif not _es_equipo(m):
		pie = "x%d" % n
	var marca: String = ""
	var apuntado: int = cesta.cantidad_de(String(s["clave"]))
	if apuntado > 0:
		marca = "Cesta %d" % apuntado if n > 1 else "Cesta"
	elif m is ConsumableData and Game.cebo_activo == m:
		marca = "PUESTO"
	return t.pieza(m, pie, "%s  x%d" % [nombre_de(s), n] if n > 1 else nombre_de(s), marca)


# Una pieza de equipo (cualquiera de las seis clases).
static func _es_equipo(m: Resource) -> bool:
	return m is WeaponData or m is ShieldData or m is WandData or m is ArmorData \
		or m is BackpackData or m is ToolData


func _ficha(vb: VBoxContainer) -> void:
	var s: Dictionary = t.stacks[t.sel]
	var m: Resource = s["modelo"]
	var n: int = int(s["cantidad"])
	var precio: int = precio_unidad(s)
	t.ficha_objeto(vb, m, n)
	vb.add_child(HSeparator.new())
	if n > 1:
		t.row(vb, "Tienes", str(n))
	t.row(vb, "Te pagan", "%d por unidad" % precio, t.AMBAR)
	match String(s["origen"]):
		"cofre", "cofre_c":
			t.note(vb, "Sale del cofre del hogar." + (" Lo concede el anfitrión: se cobra al llegar." if Net._soy_cliente() else ""))
		"hogar":
			t.note(vb, "Sale del baúl del hogar. Lo que vendas hoy te tocará farmearlo mañana para craftear.")
		"equipo":
			t.note(vb, "Si te arrepientes, lo recompras por lo mismo en la pestaña Recomprar (guarda los últimos %d)." % Game.RECOMPRA_MAX)
	if m is ConsumableData and (m as ConsumableData).es_grimorio():
		t.note(vb, "Ojo: el tendero no vende grimorios. Uno que sueltes aquí no se recupera.")
	t.fila_accion(n, precio, "Vender",
		func(cuantas: int): _vender_uno(s, cuantas),
		func(cuantas: int):
			cesta.poner(s, cuantas)
			t.rebuild(),
		cesta.cantidad_de(String(s["clave"])))


# ============================================================
#  QUE HAY PARA VENDER
# ============================================================

func _recoger() -> Array:
	var out: Array = []
	match _sub:
		SUB_BOTIN:
			var items: Array = []
			items.append_array(Game.crystals)
			items.append_array(Game.materiales)
			# El carbon vive en su propio saco (no pesa y no va al almacen) y por eso se quedaba fuera.
			items.append_array(Game.carbon)
			for g in _agrupar(items):
				out.append(_monton(g["modelo"], int(g["cantidad"]), "bolsa", "b|" + _clave_item(g["modelo"])))
		SUB_EQUIPO:
			# SIN TIPAR: se juntan arrays de clases distintas (ver arrays-tipados-por-clase).
			var todo: Array = []
			todo.append_array(Game.owned_weapons)
			todo.append_array(Game.owned_armor)
			todo.append_array(Game.owned_mochilas)
			# Las herramientas FORJADAS (las basicas de serie no estan en owned_tools: no son del jugador).
			todo.append_array(Game.owned_tools)
			for it in todo:
				if it != null and not Game.item_equipado(it):
					out.append(_monton(it, 1, "equipo", "e|%d" % it.get_instance_id()))
		SUB_CONSUMIBLES:
			for c in Game.consumables.keys():
				var n: int = int(Game.consumables[c])
				if n > 0:
					out.append(_monton(c, n, "consumible", "k|" + (c as Resource).resource_path))
		SUB_HOGAR:
			if not Net.activo or _taller == 1:
				for g in _agrupar(Game.almacen_materiales):
					out.append(_monton(g["modelo"], int(g["cantidad"]), "hogar", "h|" + _clave_item(g["modelo"])))
			out.append_array(_del_cofre())
			var consum: Dictionary = Net.hogar.cofre_consumibles_visible()
			for ruta in consum:
				if int(consum[ruta]) > 0 and ResourceLoader.exists(str(ruta)):
					var c2: Resource = load(str(ruta))
					if c2 is ConsumableData:
						var e: Dictionary = _monton(c2, int(consum[ruta]), "cofre_c", "fc|" + str(ruta))
						e["ruta"] = str(ruta)
						out.append(e)
	return out


func _monton(modelo: Resource, cantidad: int, origen: String, clave_: String) -> Dictionary:
	return {"modelo": modelo, "cantidad": cantidad, "origen": origen, "clave": clave_, "id": -1, "ruta": ""}


# El cofre de equipo: sus entradas son diccionarios, y la celda necesita la pieza. Se reconstruye SIN
# registrar (o se meteria en tu baul) y se guarda, igual que hace el almacen del hogar.
func _del_cofre() -> Array:
	var out: Array = []
	var vivos: Dictionary = {}
	for entrada in Net.hogar.cofre_visible():
		var id: int = int(entrada.get("id", -1))
		vivos[id] = true
		# Prestada a un encargo: no sale de casa, ni para venderla.
		if int(entrada.get("encargo", 0)) != 0:
			continue
		if not _cache_cofre.has(id):
			_cache_cofre[id] = Game.deserializar_equipo(entrada.get("dict", {}), false)
		var item: Resource = _cache_cofre[id]
		if item == null:
			continue
		var e: Dictionary = _monton(item, 1, "cofre", "f|%d" % id)
		e["id"] = id
		out.append(e)
	for id in _cache_cofre.keys():
		if not vivos.has(id):
			Game.item_meta.erase(_cache_cofre[id])
			_cache_cofre.erase(id)
	return out


# Agrupa cristales y materiales en montones iguales. La TALLA entra en la clave (dos peces de la misma
# especie con tallas distintas valen distinto), y Game._sacar_de_bolsa saca por la misma regla.
func _agrupar(items: Array) -> Array:
	var claves: Array = []
	var mapa: Dictionary = {}
	for it in items:
		var k: String = _clave_item(it)
		if not mapa.has(k):
			mapa[k] = {"modelo": it, "cantidad": 0}
			claves.append(k)
		mapa[k]["cantidad"] += 1
	var res: Array = []
	for k in claves:
		res.append(mapa[k])
	return res


static func _clave_item(it: Resource) -> String:
	if it is Cristal:
		var c := it as Cristal
		return "c|%d|%d" % [c.categoria, int(c.calidad)]
	if it is MaterialItem:
		var m := it as MaterialItem
		var id: String = String(m.data.id) if m.data != null else "?"
		return "m|%s|%d|%d" % [id, int(m.calidad), roundi(m.cm)]
	return "?"


# ============================================================
#  LO QUE LA TIENDA LE PREGUNTA A LA SECCION
# ============================================================

func precio_unidad(s: Dictionary) -> int:
	var m: Resource = s["modelo"]
	match String(s.get("origen", "")):
		"bolsa", "hogar":
			return Game.precio_venta_item(m)
		"equipo", "cofre":
			return Game.precio_venta_equipo(m)
		"consumible", "cofre_c":
			return Game.precio_venta_consumible(m as ConsumableData)
	return 0


func nombre_de(s: Dictionary) -> String:
	var m: Resource = s["modelo"]
	if m is Cristal:
		var c := m as Cristal
		return "Cristal Cat %d (%s)" % [c.categoria, c.calidad_texto()]
	if m is MaterialItem:
		var mi := m as MaterialItem
		return "%s (%s)" % [mi.nombre_mostrado(), mi.calidad_texto()]
	if m is ConsumableData:
		return (m as ConsumableData).nombre
	return Game.item_display_name(m)


func nombre_corto(s: Dictionary) -> String:
	var m: Resource = s["modelo"]
	if m is MaterialItem and (m as MaterialItem).data != null:
		return (m as MaterialItem).nombre_mostrado()
	if m is Cristal:
		return "Cristal Cat %d" % (m as Cristal).categoria
	var n: Variant = m.get("nombre")
	return str(n) + Game.item_plus(m) if n != null else nombre_de(s)


# Cuanto queda AHORA de un monton apuntado (para sanear la cesta).
func disponible(s: Dictionary) -> int:
	var m: Resource = s["modelo"]
	match String(s.get("origen", "")):
		"bolsa":
			return _cuenta_iguales(m, Game.crystals) + _cuenta_iguales(m, Game.materiales) + _cuenta_iguales(m, Game.carbon)
		"hogar":
			return _cuenta_iguales(m, Game.almacen_materiales)
		"equipo":
			# Cada array esta TIPADO: .has() con la clase equivocada revienta, asi que cada clase al suyo.
			var mio: bool
			if m is ArmorData:
				mio = Game.owned_armor.has(m)
			elif m is BackpackData:
				mio = Game.owned_mochilas.has(m)
			elif m is ToolData:
				mio = Game.owned_tools.has(m)
			else:
				mio = Game.owned_weapons.has(m)
			return 1 if mio and not Game.item_equipado(m) else 0
		"consumible":
			return int(Game.consumables.get(m, 0))
		"cofre":
			for entrada in Net.hogar.cofre_visible():
				if int(entrada.get("id", -1)) == int(s["id"]):
					return 1 if int(entrada.get("encargo", 0)) == 0 else 0
			return 0
		"cofre_c":
			return int(Net.hogar.cofre_consumibles_visible().get(String(s["ruta"]), 0))
	return 0


func _cuenta_iguales(modelo: Resource, lista: Array) -> int:
	var k: String = _clave_item(modelo)
	var n: int = 0
	for it in lista:
		if it != null and _clave_item(it) == k:
			n += 1
	return n


func criterios() -> Array:
	var pred := {"nombre": "Predeterminado", "campo": ""}
	match _sub:
		SUB_BOTIN:
			return [{"nombre": "Valor", "campo": "valor"}, {"nombre": "Valor por peso", "campo": "valor_peso"},
				{"nombre": "Peso", "campo": "peso"}, {"nombre": "Cantidad", "campo": "cantidad"},
				{"nombre": "Rango", "campo": "rango"}, {"nombre": "Nombre", "campo": "nombre"}, pred]
		SUB_EQUIPO:
			return [{"nombre": "Valor", "campo": "valor"}, {"nombre": "Rareza", "campo": "rareza"},
				{"nombre": "Tier", "campo": "tier"}, {"nombre": "Mejoras", "campo": "mejoras"},
				{"nombre": "Durabilidad", "campo": "durabilidad"}, {"nombre": "Nombre", "campo": "nombre"}, pred]
		SUB_CONSUMIBLES:
			return [{"nombre": "Valor", "campo": "valor"}, {"nombre": "Cantidad", "campo": "cantidad"},
				{"nombre": "Tier", "campo": "tier"}, {"nombre": "Nombre", "campo": "nombre"}, pred]
	return [{"nombre": "Valor", "campo": "valor"}, {"nombre": "Cantidad", "campo": "cantidad"},
		{"nombre": "Rango", "campo": "rango"}, {"nombre": "Nombre", "campo": "nombre"}, pred]


func grupos() -> Array:
	var O = t.orden
	match _sub:
		SUB_BOTIN:
			return [
				{"titulo": "Clase", "clave": "clase_botin", "opciones": [{"nombre": "Cristales", "valor": 0},
					{"nombre": "Materiales", "valor": 1}, {"nombre": "Combustible", "valor": 2}]},
				{"titulo": "Rango", "clave": "rango", "opciones": O.ops_rango()},
				{"titulo": "Calidad", "clave": "calidad", "opciones": O.ops_calidad()},
			]
		SUB_EQUIPO:
			return [
				{"titulo": "Clase", "clave": "clase_equipo", "opciones": [{"nombre": "Armas", "valor": 0},
					{"nombre": "Escudos", "valor": 1}, {"nombre": "Varitas", "valor": 2},
					{"nombre": "Armaduras", "valor": 3}, {"nombre": "Mochilas", "valor": 4},
					{"nombre": "Herramientas", "valor": 5}]},
				{"titulo": "Rareza", "clave": "rareza", "opciones": O.ops_rareza()},
				{"titulo": "Tier", "clave": "tier", "opciones": O.ops_tier()},
				{"titulo": "Estado", "clave": "estado", "opciones": [{"nombre": "Rota o casi", "valor": 0},
					{"nombre": "En buen estado", "valor": 1}]},
			]
		SUB_CONSUMIBLES:
			return [{"titulo": "Clase", "clave": "clase_consumible", "opciones": [
				{"nombre": "Poción de vida", "valor": 0}, {"nombre": "Poción de maná", "valor": 1},
				{"nombre": "Grimorio", "valor": 2}, {"nombre": "Plato de cocina", "valor": 3},
				{"nombre": "Cebo de pesca", "valor": 4}, {"nombre": "Tocho", "valor": 5},
				{"nombre": "Otros", "valor": 6}]}]
	return [
		{"titulo": "De dónde", "clave": "origen", "opciones": [{"nombre": "Baúl de materiales", "valor": 0},
			{"nombre": "Cofre: equipo", "valor": 1}, {"nombre": "Cofre: consumibles", "valor": 2}]},
		{"titulo": "Rango", "clave": "rango", "opciones": O.ops_rango()},
		{"titulo": "Calidad", "clave": "calidad", "opciones": O.ops_calidad()},
	]


# El boton de siempre: vaciar la bolsa de cristales de un toque, en la barra del Botin.
func pie_extra(barra: HBoxContainer) -> void:
	if _sub != SUB_BOTIN or Game.crystals.is_empty():
		return
	var total: int = 0
	for c in Game.crystals:
		total += Game.precio_venta_item(c)
	MenuScaffold.pastilla(barra, "Vender cristales (%d → %d)" % [Game.crystals.size(), total], func():
		var n: int = Game.crystals.size()
		var cobrado: int = Game.vender_todos_cristales()
		t.decir("Vendes %d cristales por %d monedas." % [n, cobrado])
		t.cant = -1
		t.rebuild(), false)


# ============================================================
#  VENDER
# ============================================================

func _vender_uno(s: Dictionary, n: int) -> void:
	var nombre: String = nombre_de(s)
	var cobrado: int = await _vender(s, n)
	if cobrado > 0:
		t.decir("Vendes %d x %s por %d monedas." % [n, nombre, cobrado] if n > 1 else "Vendes %s por %d monedas." % [nombre, cobrado])
	elif cobrado == 0:
		t.decir("No se ha podido vender %s." % nombre, false)
	t.cant = -1
	t.rebuild()


# Vende n de un monton por el camino de su origen. Devuelve lo cobrado; -1 = va por el host (el cofre en
# multi) y se cobra al llegar.
func _vender(s: Dictionary, n: int) -> int:
	if disponible(s) <= 0:
		return 0
	n = mini(n, disponible(s))
	var m: Resource = s["modelo"]
	match String(s["origen"]):
		"bolsa":
			return Game.vender_item(m, n)
		"hogar":
			# El baul es COMPARTIDO en multi: sin candado, Game.vender_item no hace nada.
			if Net.activo and not Net.hogar.tengo_taller():
				if not await Net.hogar.abrir_taller():
					t.decir("El hogar está ocupado: tu compañero está en el taller.", false)
					return 0
				var c: int = Game.vender_item(m, n, true)
				Net.hogar.cerrar_taller()
				return c
			return Game.vender_item(m, n, true)
		"equipo":
			return Game.vender_equipo(m)
		"consumible":
			return Game.vender_consumible(m as ConsumableData, n)
		"cofre":
			var antes: int = Game.money
			Net.hogar.sacar_de_cofre(int(s["id"]), true)
			_cache_cofre.erase(int(s["id"]))
			return -1 if Net._soy_cliente() else Game.money - antes
		"cofre_c":
			var antes2: int = Game.money
			Net.hogar.sacar_consumible_cofre(String(s["ruta"]), n, true)
			return -1 if Net._soy_cliente() else Game.money - antes2
	return 0


func confirmar_cesta() -> void:
	cesta.sanear(disponible)
	if cesta.vacia():
		t.rebuild()
		return
	var m: Dictionary = t.abrir_modal("¿Vendes la cesta?")
	var cuerpo: VBoxContainer = m["cuerpo"]
	var equipos: int = 0
	for e in cesta.entradas:
		var s: Dictionary = e["stack"]
		if String(s["origen"]) in ["equipo", "cofre"]:
			equipos += 1
		t.row(cuerpo, "%s  ×%d" % [nombre_corto(s), int(e["n"])], "%d monedas" % (precio_unidad(s) * int(e["n"])))
	cuerpo.add_child(HSeparator.new())
	t.row(cuerpo, "Total", "%d monedas" % cesta.total(precio_unidad), t.AMBAR)
	if equipos > Game.RECOMPRA_MAX:
		t.note(cuerpo, "Vendes %d piezas de equipo: el tendero solo guarda las últimas %d para recomprar." % [equipos, Game.RECOMPRA_MAX])
	MenuScaffold.pastilla(m["acciones"], "Cancelar", t.cerrar_modal, false)
	MenuScaffold.pastilla(m["acciones"], "Vender", func():
		t.cerrar_modal()
		_cobrar_cesta())


func _cobrar_cesta() -> void:
	cesta.sanear(disponible)
	var antes: int = Game.money
	var cosas: int = 0
	var por_llegar: bool = false
	# El candado del baul, UNA vez para toda la cesta (y solo si hace falta y no lo tienes ya).
	var candado_mio: bool = false
	var hogar_ok: bool = true
	var hay_hogar: bool = false
	for e in cesta.entradas:
		if String(e["stack"]["origen"]) == "hogar":
			hay_hogar = true
	if hay_hogar and Net.activo and not Net.hogar.tengo_taller():
		hogar_ok = await Net.hogar.abrir_taller()
		candado_mio = hogar_ok
	for e in cesta.entradas.duplicate():
		var s: Dictionary = e["stack"]
		if String(s["origen"]) == "hogar" and not hogar_ok:
			continue
		var c: int = await _vender(s, int(e["n"]))
		if c != 0:
			cosas += 1
		if c < 0:
			por_llegar = true
	if candado_mio:
		Net.hogar.cerrar_taller()
	var cobrado: int = Game.money - antes
	var txt: String = "Vendes la cesta: %d %s por %d monedas." % [cosas, "cosa" if cosas == 1 else "cosas", cobrado]
	if por_llegar:
		txt += " Lo del cofre se cobra cuando lo conceda el anfitrión."
	if not hogar_ok:
		txt += " Lo del baúl no: tu compañero está en el taller."
	t.decir(txt, hogar_ok)
	cesta.vaciar()
	t.cant = -1
	t.rebuild()


# ============================================================
#  EL CANDADO DEL TALLER (baul de materiales en multi)
#  Mientras estas en la subpestaña Hogar se tiene cogido, como en el almacen del hogar: sin el, el
#  invitado no ve el baul de verdad.
# ============================================================

func _taller_listo() -> void:
	match _taller:
		0:
			_taller = 2
			_pedir_taller()
			MenuScaffold.nota(t._header, "Abriendo el baúl de materiales…")
		2:
			MenuScaffold.nota(t._header, "Abriendo el baúl de materiales…")
		-1:
			MenuScaffold.nota(t._header, "Tu compañero está usando el baúl de materiales en el taller: por ahora solo sale lo del cofre.")


func _pedir_taller() -> void:
	var ok: bool = await Net.hogar.abrir_taller()
	if _sub != SUB_HOGAR or not t._root.visible:
		if ok:
			Net.hogar.cerrar_taller()
		_taller = 0
		return
	_taller = 1 if ok else -1
	t.rebuild()


func _soltar_taller() -> void:
	if _taller == 1 and Net.activo:
		Net.hogar.cerrar_taller()
	_taller = 0
