# ============================================================
#  dev_tienda.gd  --  HERRAMIENTA, no parte del juego.
#
#  Abre la TIENDA de verdad (scripts/ui/shop_menu.gd) con la partida de prueba y recorre TODAS las
#  subpestañas de los dos mostradores (T1 y el T2 del Rey Slime), una a una, comprobando que cada
#  una pinta LO SUYO.
#
#  Por que esta comprobacion y no otra: _build_tienda despacha las subpestañas por INDICE
#  (`match _sub`), asi que quitar una del medio le corre el contenido a todas las de detras y el
#  fallo NO da error -- simplemente pulsas "Comida" y te sale otra cosa. Al sacar los GRIMORIOS del
#  mostrador, comida pasa del 5 al 4, y esto es lo que verifica que se renumero bien.
#
#  Ademas comprueba que NO queda ni un grimorio a la venta en ninguna de las dos plantas (la magia
#  se gana, no se compra) y que, en cambio, los que YA tengas se siguen pudiendo VENDER.
#
#  Va CON VENTANA (nada de --headless): un Control no se coloca ni se dibuja sin superficie de
#  render, y en headless la captura sale en negro. Y con process_mode = ALWAYS, porque el menu
#  PAUSA el arbol al abrirse y sin esto el visor se congela en el primer await.
#
#  Doble clic en herramientas/ver_tienda.bat, o:
#    godot --path . res://tools/visores/dev_tienda.tscn
#  Guarda tools/salida/tienda_*.png, escribe el resultado por consola y devuelve codigo != 0 si
#  algo falla.
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
const PartidaDePrueba = preload("res://tools/visores/partida_de_prueba.gd")

# Lo que tiene que salir en cada subpestaña del mostrador, POR INDICE. Es la tabla que se rompe
# sola cuando alguien quita una pestaña del medio.
const ESPERADO := [
	{"sub": "Armas", "clases": ["WeaponData", "ShieldData", "WandData"]},
	{"sub": "Armaduras", "clases": ["ArmorData"]},
	{"sub": "Mochilas", "clases": ["BackpackData"]},
	{"sub": "Consumibles", "clases": ["ConsumableData"]},
	{"sub": "Comida", "clases": ["MaterialData"]},
]

var _fallos: int = 0
var _hechas: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1280, 720))
	PartidaDePrueba.llenar()
	# El mostrador T2 solo existe si cayo el Rey Slime: sin esto la pestaña ni se pinta y media
	# prueba se salta en silencio.
	Game.bosses_derrotados[Game.PISO_TIENDA_T2] = true
	# UNOS GRIMORIOS EN LA BOLSA: no para comprarlos (ya no se venden) sino para la otra mitad de la
	# prueba -- que los que traigas de la mazmorra se sigan pudiendo VENDER.
	_meter_grimorios()

	var men: CanvasLayer = preload("res://scripts/ui/shop_menu.gd").new()
	add_child(men)
	men.abrir()
	DirAccess.make_dir_recursive_absolute(SALIDA)

	print("=== TIENDA: cada subpestaña pinta lo suyo ===")
	_ok("el mostrador ya no tiene pestaña de grimorios",
		not men.SUBS_TIENDA.has("Grimorios"))
	_ok("y le quedan %d subpestañas" % ESPERADO.size(),
		men.SUBS_TIENDA.size() == ESPERADO.size())

	for tier in [1, 2]:
		print("\n-- Mostrador T%d --" % tier)
		men._tab = tier   # 1 = Tienda, 2 = Tienda T2 (ver shop_menu._rebuild_real)
		for i in ESPERADO.size():
			await _mirar_sub(men, tier, i)

	print("\n-- Vender > Consumibles (los grimorios que ya tienes) --")
	men._tab = 0
	men._sub = 3
	men._sel = 0
	men._rebuild()
	_ok("en la bolsa siguen apareciendo grimorios que vender",
		_hay_grimorio(men._stacks))
	# El preview del grimorio VENDIDO sigue teniendo su rama (dice que hechizo enseña): se llega a
	# el poniendo la seleccion encima de uno, que es justo lo que peta si se borro de mas.
	men._sel = maxi(0, _idx_grimorio(men._stacks))
	men._rebuild()
	await _captura("vender_grimorio")

	if _fallos == 0:
		print("\nOK: las %d comprobaciones pasan." % _hechas)
	else:
		printerr("\nFALLAN %d de %d comprobaciones." % [_fallos, _hechas])
	get_tree().quit(1 if _fallos > 0 else 0)


# Una subpestaña: la pinta, saca la foto y comprueba que lo que hay dentro es de la clase que toca.
func _mirar_sub(men: Node, tier: int, i: int) -> void:
	var esp: Dictionary = ESPERADO[i]
	men._sub = i
	men._sel = 0
	men._cant = 1
	men._rebuild()
	await _captura("t%d_%d_%s" % [tier, i, String(esp["sub"]).to_lower()])

	var nombre: String = String(men.SUBS_TIENDA[i])
	_ok("T%d sub %d se llama '%s'" % [tier, i, esp["sub"]], nombre == esp["sub"])

	var malas: Array = []
	var grimorios: Array = []
	for s in men._stacks:
		var base: Resource = s["modelo"]
		var cls: String = _clase_de(base)
		if not (esp["clases"] as Array).has(cls):
			malas.append("%s (%s)" % [str(base.get("nombre")), cls])
		if base is ConsumableData and (base as ConsumableData).es_grimorio():
			grimorios.append(str(base.get("nombre")))

	_ok("T%d '%s' no esta vacia" % [tier, nombre], not men._stacks.is_empty())
	if malas.is_empty():
		_ok("T%d '%s' pinta %d cosas, todas de lo suyo" % [tier, nombre, men._stacks.size()], true)
	else:
		_ok("T%d '%s' pinta cosas de otra pestaña: %s" % [tier, nombre, ", ".join(malas)], false)
	_ok("T%d '%s' no vende magia" % [tier, nombre], grimorios.is_empty())


# La clase de un recurso del mostrador. Se compara por CADENA y no con 'is' en un bucle porque
# WandData y ShieldData no comparten arbol con WeaponData y hacia falta un caso por cada uno.
func _clase_de(base: Resource) -> String:
	if base is ShieldData:
		return "ShieldData"
	if base is WandData:
		return "WandData"
	if base is WeaponData:
		return "WeaponData"
	if base is ArmorData:
		return "ArmorData"
	if base is BackpackData:
		return "BackpackData"
	if base is ConsumableData:
		return "ConsumableData"
	if base is MaterialData:
		return "MaterialData"
	return "?"


func _meter_grimorios() -> void:
	var d := DirAccess.open("res://resources/consumables/")
	if d == null:
		return
	var n: int = 0
	for f in d.get_files():
		if not f.begins_with("grimorio_") or not f.ends_with(".tres"):
			continue
		var c: ConsumableData = load("res://resources/consumables/" + f) as ConsumableData
		if c != null and c.es_grimorio():
			Game.consumables[c] = 2
			n += 1
		if n >= 3:
			return


func _hay_grimorio(stacks: Array) -> bool:
	return _idx_grimorio(stacks) >= 0


func _idx_grimorio(stacks: Array) -> int:
	for i in stacks.size():
		var c: Resource = stacks[i]["modelo"]
		if c is ConsumableData and (c as ConsumableData).es_grimorio():
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
	# DOS frames: el primero coloca los contenedores (hasta entonces los botones miden 0) y el
	# segundo ya dibuja lo colocado.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ruta: String = "%stienda_%s.png" % [SALIDA, nombre]
	get_viewport().get_texture().get_image().save_png(ruta)
