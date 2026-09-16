# ============================================================
#  dev_pescador.gd  --  HERRAMIENTA, no parte del juego.
#
#  Abre el PESCADOR de verdad (scripts/ui/fishing_book_menu.gd, rehecho el 16/09/2026 con la cara del
#  inventario) y comprueba:
#    - el LIBRO son todas las especies en celdas, y las que no has pescado salen en negro;
#    - la ficha de una pescada dice sus capturas y su talla;
#    - los CEBOS son el mostrador, la cantidad arranca en 1 y comprar cobra lo que dice.
#
#  --headless solo comprueba; con ventana (herramientas/ver_pescador.bat) saca capturas en
#  tools/salida/pescador_*.png. Devuelve codigo != 0 si algo falla.
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
	Game.registro_pesca.clear()
	var peces: Array = Game.peces()
	# Las dos primeras especies pescadas, las demas no.
	for i in mini(2, peces.size()):
		var d: MaterialData = peces[i]
		for cm in [d.cm_min + 1.0, (d.cm_min + d.cm_max) * 0.5, d.cm_max - 0.5]:
			Game.apuntar_pesca(d.id, cm)

	var men: CanvasLayer = preload("res://scripts/ui/fishing_book_menu.gd").new()
	add_child(men)
	men.abrir()
	await get_tree().process_frame

	print("=== LIBRO ===")
	_ok("son todas las especies", men.stacks.size() == peces.size())
	var celdas: Array = men._lista.get_child(0).get_children()
	_ok("una celda por especie", celdas.size() == peces.size())
	_ok("la pescada se ve en color", (celdas[0] as Control).modulate == Color.WHITE)
	_ok("la que no, en negro", peces.size() < 3 or (celdas[2] as Control).modulate != Color.WHITE)
	_ok("la ficha dice sus capturas", int(Game.ficha_pesca((peces[0] as MaterialData).id)["capturas"]) == 3)
	await _captura(men, "libro")
	if peces.size() >= 3:
		men._pick(2)
		await get_tree().process_frame
		_ok("elegir otra no le quita el negro", (men._lista.get_child(0).get_child(2) as Control).modulate != Color.WHITE)
		await _captura(men, "libro_sin_pescar")

	print("\n=== CEBOS ===")
	men._tab = men.TAB_CEBOS
	men.cambiar_pantalla()
	await get_tree().process_frame
	_ok("hay cebos a la venta", not men.stacks.is_empty())
	_ok("la cantidad arranca en 1", men._cuantas == 1)
	await _captura(men, "cebos")
	var c: ConsumableData = men.stacks[0]
	Game.money = 10000
	var precio: int = Game.precio_compra(c)
	var antes: int = int(Game.consumables.get(c, 0))
	men._cuantas = 3
	men._comprar(c)
	await get_tree().process_frame
	_ok("comprar 3 da 3", int(Game.consumables.get(c, 0)) == antes + 3)
	_ok("y cobra 3", Game.money == 10000 - precio * 3)
	_ok("y la cantidad vuelve a 1", men._cuantas == 1)

	men._cerrar()
	if _fallos == 0:
		print("\nOK: las %d comprobaciones pasan." % _hechas)
	else:
		printerr("\nFALLAN %d de %d comprobaciones." % [_fallos, _hechas])
	get_tree().quit(1 if _fallos > 0 else 0)


func _ok(que: String, cond: bool) -> void:
	_hechas += 1
	if cond:
		print("  ok   %s" % que)
	else:
		_fallos += 1
		printerr("  FALLA %s" % que)


func _captura(men: Node, nombre: String) -> void:
	if not _con_ventana:
		return
	men.rebuild()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%spescador_%s.png" % [SALIDA, nombre])
