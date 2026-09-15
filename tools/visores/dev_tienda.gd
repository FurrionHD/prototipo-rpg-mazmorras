# ============================================================
#  dev_tienda.gd  --  HERRAMIENTA, no parte del juego.
#
#  Abre la TIENDA de verdad (scripts/ui/shop_menu.gd, rehecha el 16/09/2026 con la cara del inventario)
#  con la partida de prueba y la recorre ENTERA, comprobando lo que el rework prometio:
#    - que se vende TODO lo que tienes: el carbon y las herramientas (antes se quedaban fuera) y el
#      cofre del hogar, pero NO lo equipado ni lo prestado a un encargo;
#    - que lo que se cobra es lo anunciado (el pez de la talla que pone, la cesta entera);
#    - que el mostrador T2 enseña el equipo a T2 y lo vende a T2, sin grimorios en ninguna planta;
#    - que el buscador y los filtros dejan lo que tienen que dejar;
#    - que la cesta de la compra es todo o nada.
#
#  DOS MODOS:
#    - SIN VENTANA (--headless): solo las comprobaciones. Rapido y sin abrir nada.
#    - CON VENTANA (doble clic en herramientas/ver_tienda.bat): ademas, las capturas en
#      tools/salida/tienda_*.png. Headless no dibuja UI, por eso ahi se saltan.
#  Con process_mode = ALWAYS, porque el menu PAUSA el arbol al abrirse.
#  Devuelve codigo != 0 si algo falla.
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
const PartidaDePrueba = preload("res://tools/visores/partida_de_prueba.gd")

var _fallos: int = 0
var _hechas: int = 0
var _con_ventana: bool = DisplayServer.get_name() != "headless"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _con_ventana:
		DisplayServer.window_set_size(Vector2i(1280, 720))
		DirAccess.make_dir_recursive_absolute(SALIDA)
	PartidaDePrueba.llenar()
	Game.bosses_derrotados[Game.PISO_TIENDA_T2] = true
	var extra: Dictionary = _llenar_tienda()

	var men: CanvasLayer = preload("res://scripts/ui/shop_menu.gd").new()
	add_child(men)
	men.abrir()
	var V = men.vender
	var C = men.comprar

	print("=== VENDER: sale todo lo que tienes ===")
	await _ir(men, men.TAB_VENDER, V, V.SUB_BOTIN)
	_ok("Botín: sale el carbón", _hay(men.stacks, func(s): return s["modelo"] is MaterialItem and s["modelo"].data == extra["carbon"]))
	_ok("Botín: salen los cristales", _hay(men.stacks, func(s): return s["modelo"] is Cristal))
	_ok("Botín: sale el pez", _hay(men.stacks, func(s): return s["modelo"] is MaterialItem and s["modelo"].cm > 0.0))
	await _captura("vender_botin")

	await _ir(men, men.TAB_VENDER, V, V.SUB_EQUIPO)
	_ok("Equipo: sale la herramienta forjada", _hay(men.stacks, func(s): return s["modelo"] == extra["herramienta"]))
	_ok("Equipo: no sale nada equipado", not _hay(men.stacks, func(s): return Game.item_equipado(s["modelo"])))
	_ok("Equipo: no está vacío", not men.stacks.is_empty())
	await _captura("vender_equipo")

	await _ir(men, men.TAB_VENDER, V, V.SUB_CONSUMIBLES)
	_ok("Consumibles: salen los grimorios que ya tienes", _hay(men.stacks, func(s): return s["modelo"] is ConsumableData and s["modelo"].es_grimorio()))

	await _ir(men, men.TAB_VENDER, V, V.SUB_HOGAR)
	_ok("Hogar: sale el baúl de materiales", _hay(men.stacks, func(s): return s["origen"] == "hogar"))
	_ok("Hogar: sale la pieza del cofre", _hay(men.stacks, func(s): return s["origen"] == "cofre" and int(s["id"]) == 901))
	_ok("Hogar: NO sale la prestada a un encargo", not _hay(men.stacks, func(s): return s["origen"] == "cofre" and int(s["id"]) == 902))
	_ok("Hogar: salen los consumibles del cofre", _hay(men.stacks, func(s): return s["origen"] == "cofre_c"))
	await _captura("vender_hogar")

	print("\n=== VENDER: se cobra lo anunciado ===")
	# El pez GRANDE, que va detras del pequeño en la bolsa: antes se vendia el primero que hubiera.
	await _ir(men, men.TAB_VENDER, V, V.SUB_BOTIN)
	var i_pez: int = _indice(men.stacks, func(s): return s["modelo"] is MaterialItem and roundi(s["modelo"].cm) == roundi(extra["pez_grande"].cm))
	_ok("el montón del pez grande está", i_pez >= 0)
	if i_pez >= 0:
		var s_pez: Dictionary = men.stacks[i_pez]
		var anunciado: int = V.precio_unidad(s_pez)
		var antes: int = Game.money
		await V._vender_uno(s_pez, 1)
		_ok("vender el pez grande cobra lo anunciado (%d)" % anunciado, Game.money - antes == anunciado)
		_ok("y el pequeño sigue en la bolsa", Game.materiales.has(extra["pez_chico"]))

	# El cofre, en solitario: sale y se cobra en el acto.
	await _ir(men, men.TAB_VENDER, V, V.SUB_HOGAR)
	var i_cofre: int = _indice(men.stacks, func(s): return s["origen"] == "cofre" and int(s["id"]) == 901)
	if i_cofre >= 0:
		var s_c: Dictionary = men.stacks[i_cofre]
		var precio_c: int = V.precio_unidad(s_c)
		var antes_c: int = Game.money
		await V._vender_uno(s_c, 1)
		_ok("vender del cofre cobra lo anunciado (%d)" % precio_c, Game.money - antes_c == precio_c)
		_ok("y la pieza ya no está en el cofre", not Game.cofre_equipo.any(func(e): return int(e["id"]) == 901))

	# LA CESTA: dos montones con cantidades a mano, NUNCA el montón entero.
	await _ir(men, men.TAB_VENDER, V, V.SUB_BOTIN)
	var montones: Array = men.stacks.filter(func(s): return int(s["cantidad"]) >= 3)
	_ok("hay dos montones de 3 o más para la cesta", montones.size() >= 2)
	if montones.size() >= 2:
		V.cesta.poner(montones[0], 2)
		V.cesta.poner(montones[1], 1)
		V.cesta.poner(montones[1], 3)   # poner otra vez REEMPLAZA, no suma
		_ok("poner otra vez reemplaza la cantidad", V.cesta.cantidad_de(String(montones[1]["clave"])) == 3)
		var total: int = V.cesta.total(V.precio_unidad)
		var quedan0: int = V.disponible(montones[0])
		men.rebuild()
		await _captura("vender_cesta")
		V.confirmar_cesta()
		await _captura("vender_cesta_confirmar")
		men.cerrar_modal()
		var antes_cesta: int = Game.money
		await V._cobrar_cesta()
		_ok("la cesta cobra su total (%d)" % total, Game.money - antes_cesta == total)
		_ok("y solo se lleva lo apuntado (quedan %d)" % (quedan0 - 2), V.disponible(montones[0]) == quedan0 - 2)
		_ok("y se vacía", V.cesta.vacia())

	print("\n=== VENDER: filtros ===")
	await _ir(men, men.TAB_VENDER, V, V.SUB_EQUIPO)
	men.orden.alternar(V.clave(), "clase_equipo", 5)   # Herramientas
	men.rebuild()
	_ok("filtro Herramientas deja solo herramientas", not men.stacks.is_empty()
		and not _hay(men.stacks, func(s): return not (s["modelo"] is ToolData)))
	men._abrir_modal_filtros()
	await _captura("modal_filtros")
	men.cerrar_modal()
	men.orden.limpiar(V.clave())

	print("\n=== COMPRAR ===")
	for tier in [1, 2]:
		C._tier = tier
		for sub in C.SUBS.size():
			await _ir(men, men.TAB_COMPRAR, C, sub)
			var nombre: String = C.SUBS[sub]
			_ok("T%d %s no está vacía" % [tier, nombre], not men.stacks.is_empty())
			_ok("T%d %s no vende magia" % [tier, nombre], not _hay(men.stacks, func(s): return s["base"] is ConsumableData and s["base"].es_grimorio()))
			if sub == C.SUB_ARMAS or sub == C.SUB_ARMADURAS:
				_ok("T%d %s: las celdas dicen T%d" % [tier, nombre, tier], not _hay(men.stacks, func(s): return IconoItem.tier_de(s["modelo"]) != tier))
			if sub == C.SUB_ARMAS or (tier == 2 and sub == C.SUB_ARMADURAS):
				await _captura("comprar_t%d_%s" % [tier, nombre.to_lower()])

	# Comprar un arma a T2: llega a tu baul a T2.
	C._tier = 2
	await _ir(men, men.TAB_COMPRAR, C, C.SUB_ARMAS)
	var s_arma: Dictionary = men.stacks[0]
	Game.money = 100000
	var armas_antes: int = Game.owned_weapons.size()
	C._comprar([{"base": s_arma["base"], "tier": 2, "n": 1}], 1, C.nombre_de(s_arma))
	var nueva: Resource = Game.owned_weapons.back()
	_ok("comprar a T2 mete un arma nueva en el baúl", Game.owned_weapons.size() == armas_antes + 1)
	_ok("y es T2", int(Game.meta_de(nueva)["tier"]) == 2)
	_ok("y no es la copia del escaparate", not men._es_vitrina(nueva))

	# La cesta de la compra es TODO O NADA.
	C._tier = 1
	await _ir(men, men.TAB_COMPRAR, C, C.SUB_CONSUMIBLES)
	C.cesta.poner(men.stacks[0], 5)
	Game.money = C.cesta.total(C.precio_unidad) - 1
	var cons_antes: int = Game.consumibles_total()
	_ok("sin dinero para la cesta no se compra nada", Game.comprar_lote([{"base": men.stacks[0]["base"], "tier": 1, "n": 5}]) == 0
		and Game.consumibles_total() == cons_antes)
	C.cesta.vaciar()
	Game.money = 4820

	print("\n=== BUSCADOR ===")
	await _ir(men, men.TAB_COMPRAR, C, C.SUB_ARMAS)
	men._buscador.text = "espada"
	men._buscador.text_changed.emit("espada")
	_ok("buscar 'espada' deja solo espadas", not men.stacks.is_empty()
		and not _hay(men.stacks, func(s): return not C.nombre_de(s).to_lower().contains("espada")))
	men._buscador.text = "POCION"
	await _ir(men, men.TAB_COMPRAR, C, C.SUB_CONSUMIBLES)
	men._buscador.text_changed.emit("POCION")
	_ok("buscar sin tilde ni mayúsculas encuentra la Poción", _hay(men.stacks, func(s): return C.nombre_de(s).contains("Poción")))
	await _captura("buscador")

	print("\n=== AL CERRAR ===")
	var copias: Array = men._vitrina.values()
	men._cerrar()
	_ok("las copias del escaparate no dejan metas colgando", not copias.any(func(c): return Game.item_meta.has(c)))

	if _fallos == 0:
		print("\nOK: las %d comprobaciones pasan." % _hechas)
	else:
		printerr("\nFALLAN %d de %d comprobaciones." % [_fallos, _hechas])
	get_tree().quit(1 if _fallos > 0 else 0)


# Lo que la partida de prueba no trae y la tienda tiene que enseñar.
func _llenar_tienda() -> Dictionary:
	var out: Dictionary = {}
	# Botin: cristales, un monton de materiales de sobra, el carbon y DOS peces de la misma especie con
	# tallas distintas, el PEQUEÑO primero (es el orden en el que se colaba al vender el grande).
	Game.crystals.clear()
	for i in 6:
		var c := Cristal.new()
		c.categoria = 3 + (i % 2)
		Game.crystals.append(c)
	Game.materiales.clear()
	for ruta in ["res://resources/materials/cebolla.tres", "res://resources/materials/ajo.tres"]:
		for i in 5:
			Game.materiales.append(MaterialItem.crear(load(ruta)))
	var pez: MaterialData = load("res://resources/materials/anguila_pozo.tres")
	out["pez_chico"] = MaterialItem.crear(pez)
	out["pez_chico"].cm = pez.cm_min
	out["pez_grande"] = MaterialItem.crear(pez)
	out["pez_grande"].cm = pez.cm_max
	Game.materiales.append(out["pez_chico"])
	Game.materiales.append(out["pez_grande"])
	out["carbon"] = load("res://resources/materials/carbon_duro.tres")
	Game.carbon.clear()
	for i in 3:
		Game.carbon.append(MaterialItem.crear(out["carbon"]))
	# Una herramienta FORJADA, sin equipar.
	out["herramienta"] = Game.crear_item(load("res://resources/tools/pico_basico.tres"), 1, Upgrades.Rareza.RARO, {})
	# Grimorios en la bolsa (se venden aunque el tendero no los venda).
	var d := DirAccess.open("res://resources/consumables/")
	if d != null:
		var n: int = 0
		for f in d.get_files():
			if f.begins_with("grimorio_") and f.ends_with(".tres") and n < 3:
				Game.consumables[load("res://resources/consumables/" + f)] = 2
				n += 1
	# El hogar: materiales en el baul y el cofre con una pieza libre y otra prestada a un encargo.
	Game.almacen_materiales.clear()
	for i in 4:
		Game.almacen_materiales.append(MaterialItem.crear(load("res://resources/materials/tomate.tres")))
	var espada: Resource = Game.crear_item(load("res://resources/weapons/daga.tres"), 2, Upgrades.Rareza.EPICO, {}, false)
	var d_esp: Dictionary = Game.serializar_equipo(espada)
	Game.cofre_equipo.clear()
	Game.cofre_equipo.append({"id": 901, "dict": d_esp, "clase": str(d_esp.get("clase", "arma")), "desc": "?", "encargo": 0})
	Game.cofre_equipo.append({"id": 902, "dict": d_esp.duplicate(true), "clase": str(d_esp.get("clase", "arma")), "desc": "?", "encargo": 7})
	Game.cofre_consumibles.clear()
	Game.cofre_consumibles["res://resources/consumables/pocion_menor.tres"] = 4
	return out


func _ir(men: Node, tab: int, seccion, sub: int) -> void:
	men._tab = tab
	seccion._sub = sub
	men.sel = 0
	men.cant = -1
	men.rebuild()
	await get_tree().process_frame


func _hay(lista: Array, cond: Callable) -> bool:
	return _indice(lista, cond) >= 0


func _indice(lista: Array, cond: Callable) -> int:
	for i in lista.size():
		if cond.call(lista[i]):
			return i
	return -1


func _ok(que: String, cond: bool) -> void:
	_hechas += 1
	if cond:
		print("  ok   %s" % que)
	else:
		_fallos += 1
		printerr("  FALLA %s" % que)


func _captura(nombre: String) -> void:
	if not _con_ventana:
		return
	# DOS frames: el primero coloca los contenedores y el segundo ya dibuja lo colocado.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%stienda_%s.png" % [SALIDA, nombre])
