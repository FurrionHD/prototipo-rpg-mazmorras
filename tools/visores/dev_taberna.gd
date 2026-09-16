# ============================================================
#  dev_taberna.gd  --  HERRAMIENTA, no parte del juego.
#
#  Abre la TABERNA de verdad (scripts/ui/tavern_menu.gd, rehecha el 16/09/2026) y comprueba lo nuevo:
#    - con la plantilla de uno (tu solo) el primer compañero es GRATIS y la rejilla son las armas del
#      pack para elegirle una de regalo;
#    - contratarlo no cobra y le deja el arma PUESTA (T1 Comun);
#    - el segundo cuesta el doble de la base y el tercero el doble de eso;
#    - los de pago llegan sin nada, aunque se les pase un arma.
#
#  --headless solo comprueba; con ventana (herramientas/ver_taberna.bat) saca capturas en
#  tools/salida/taberna_*.png. Devuelve codigo != 0 si algo falla.
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
	# Partida recien empezada: solo tu.
	var yo: PersonajeData = Game.lider()
	Game.party.assign([yo])
	Game.plantilla.assign([yo])
	Game.lider_idx = 0

	var men: CanvasLayer = preload("res://scripts/ui/tavern_menu.gd").new()
	add_child(men)
	men.abrir()
	await get_tree().process_frame

	print("=== EL PRIMERO ES GRATIS ===")
	_ok("con la plantilla de uno toca el fichaje gratis", Game.fichaje_gratis())
	_ok("y cuesta 0", Game.precio_fichar() == 0)
	_ok("la rejilla son las armas del pack", men.stacks.size() == Game.PACK_ARMAS.size())
	_ok("y ninguna es mágica", not men.stacks.any(func(b): return Game._es_arma_magica(b)))
	await _captura(men, "gratis")
	men._pick(3)
	await get_tree().process_frame
	await _captura(men, "gratis_otra_arma")

	var arma: Resource = men.stacks[3]
	var dinero: int = Game.money
	var pj: PersonajeData = Game.fichar_en_taberna("Sedaki", {}, arma)
	men.rebuild()
	await get_tree().process_frame
	_ok("se une", pj != null and Game.plantilla.size() == 2)
	_ok("no cobra nada", Game.money == dinero)
	_ok("y lleva el arma puesta", pj != null and pj.equipped_main != null
		and String(Game.meta_de(pj.equipped_main).get("ruta_base", "")) == arma.resource_path)
	_ok("T1 Común", pj != null and pj.equipped_main != null and int(Game.meta_de(pj.equipped_main)["tier"]) == 1
		and int(Game.meta_de(pj.equipped_main)["rareza"]) == Upgrades.Rareza.COMUN)

	print("\n=== LOS SIGUIENTES SE PAGAN ===")
	_ok("ya no es gratis", not Game.fichaje_gratis())
	var segundo: int = Game.precio_fichar()
	_ok("el segundo cuesta el doble de la base (%d)" % segundo,
		segundo == roundi(Game.PRECIO_FICHAR_BASE * Game.PRECIO_FICHAR_MULT))
	_ok("la rejilla ya no ofrece armas", men.stacks.is_empty())
	await _captura(men, "pago")
	Game.money = segundo * 10
	var pj2: PersonajeData = Game.fichar_en_taberna("Nurit", {}, arma)
	_ok("el de pago cobra", pj2 != null and Game.money == segundo * 10 - segundo)
	_ok("y llega sin arma aunque se le pase una", pj2 != null and pj2.equipped_main == null)
	_ok("el tercero cuesta el doble que el segundo", Game.precio_fichar() == segundo * 2)
	Game.money = 0
	men.rebuild()
	await get_tree().process_frame
	await _captura(men, "sin_dinero")

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
	get_viewport().get_texture().get_image().save_png("%staberna_%s.png" % [SALIDA, nombre])
